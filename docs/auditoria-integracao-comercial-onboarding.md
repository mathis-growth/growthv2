# Auditoria do banco e plano de integração: comercial, contratos, financeiro, onboarding e Customer Growth

**Data:** 30/10/2026 · **Banco auditado:** produção (Supabase `yngyghlyonybvfvjcmxl`) e as migrações do repositório.
**Escopo:** só auditoria e plano. Nenhuma migração, tabela, contrato, financeiro ou workflow foi alterado.

**Resumo em uma frase:** o Growth's já tem uma única identidade de cliente por empresa (`pessoas`) e um caminho automático "venda/contrato → financeiro → matrícula → jornada → projeto". Faltam quatro coisas reais:
1. A negociação (oportunidade) não leva itens nem condições até o contrato.
2. Não existe documento de contrato nem assinatura eletrônica.
3. Não existe entrada automática de vendas de checkout nem confirmação de pagamento por gateway.
4. O onboarding não tem configuração por produto nem guarda arquivos.

Tudo isso se resolve estendendo o que existe; só três estruturas novas se justificam (modelos de contrato, documentos de contrato e arquivos).

---

## 1. Inventário das estruturas existentes

O banco tem 190 tabelas, todas com `workspace_id` e RLS. Abaixo, só as que importam para este fluxo, com o volume aproximado em produção.

### 1.1 Empresa, cliente, contatos e usuários

| Estrutura | O que é hoje | Pontos-chave |
|---|---|---|
| `workspaces` (8) | **A empresa que usa o Growth's** (o tenant). Mathisa, Escola Aurora, etc. | `pacote_id`, `acesso_liga`/`acesso_desliga`, `modo_produto` (completo/starter), `modo_financeiro`, `agencia`, `casa_de`, `content_ativo` |
| `empresa` (1 por workspace) | Dados cadastrais **da própria empresa** (razão social, CNPJ, responsável, financeiro, regime tributário) | Não é cadastro de cliente |
| `pessoas` (5.149) | **O cliente e o lead**, única identidade por workspace | e-mail e telefone únicos por workspace (`pessoas_email_uq`, `pessoas_telefone_uq`), `pessoa_resolver`, `pessoas_mesclagens`, `extras` (jsonb), UTM, `responsavel_comercial_id`, `negocio_status`, `etapa_kanban_id` (CRM) |
| `campos_personalizados` | Campos extras por entidade e workspace (vão para `pessoas.extras`) | Hoje sem uso em produção |
| `pessoa_notas`, `pessoa_historico`, `pessoa_toques` (10 mil), `responsavel_historico` | Histórico, notas, toques e trocas de responsável | Base do histórico unificado |
| `equipe`, `workspace_membros`, `funcoes` | Usuários da empresa, papel e função com permissão por módulo (`adm, mkt, vendas, revops, fin, prj, gro, cfg, cad`: nenhum/ler/editar) | `perm()`, `pode_editar()`, `nivel_modulo()`, `minhas_permissoes()` |

**Não existe hoje:**
- um cliente **pessoa jurídica** com CNPJ e razão social: a pessoa é uma só, sem tipo PF/PJ;
- um vínculo entre o cliente (`pessoas`, no workspace da Mathisa) e o **workspace que a Mathisa cria para esse cliente** (`criar_workspace_cliente`).

### 1.2 Comercial (CRM, oportunidades, produtos, preços)

| Estrutura | O que é hoje |
|---|---|
| CRM de leads | O próprio `pessoas`, com `etapa_kanban_id` (`etapas_kanban`), `negocio_status` (aberto/ganho/perdido), `negocio_motivo_id` (`motivos_resultado`) e `responsavel_comercial_id` |
| `oportunidades` (2) | Oportunidade com **um** `produto_id`, `valor_estimado`, `etapa_kanban_id`, `status` (aberta/ganha/perdida). Tipo: `nova_venda`, `renovacao`, `ajuste`, `expansao`, `retencao`. Origem: `manual`, `alerta`, `rfm`, `ascensao`, `marco`, `intervencao`. Liga em `pessoa_id`, `aluno_id` e `contrato_origem_id` (o contrato de origem, para renovação ou expansão) |
| `produtos` | Catálogo: `tipo` (digital, saas, servico, curso, assinatura, outro), `recorrente` + `periodicidade`, `preco`, `nivel_escada` (esteira), `modelo_projeto_id`, `extras` |
| `ofertas`, `oferta_itens`, `oferta_versoes` | Ofertas com preço, condições, `parcelas_max`, vigência e versão; uma oferta pode juntar vários produtos |
| `plataformas_venda`, `plataforma_formas_pagamento`, `produto_plataforma` (`id_externo`) | Hotmart e outras, com taxas e prazos de recebimento por forma de pagamento |

**Achado:** há dois jeitos de negociar convivendo. O negócio do lead fica no próprio `pessoas` (`negocio_status`); a `oportunidades` é usada para expansão, retenção e renovação (Customer Growth). Nenhum dos dois guarda vários produtos nem condições negociadas (entrada, parcelas, recorrência).

### 1.3 Contratos

| Estrutura | O que é hoje |
|---|---|
| `contratos` (28: 26 ativos, 2 cancelados) | `pessoa_id`, `campanha_id`, `vendedor_id`, `status` (rascunho, ativo, encerrado, cancelado), datas, `recorrente` + `periodicidade`, `num_parcelas` (1 a 120), `primeiro_vencimento`, `forma_pagamento`, `conta_bancaria_id`, `acessos`, `numero` sequencial |
| `contrato_itens` | Produtos do contrato, com `quantidade` e `valor` (do catálogo `produtos`) |
| `contrato_parcelas_plano` | Plano de parcelas próprio (permite entrada com valor diferente das demais) |
| `ativar_contrato()` | Valida itens, gera as `contas_receber` (pelo plano ou divididas por igual), lança no contábil e cria a **matrícula** (`alunos`, uma por contrato) |
| gatilho `contratos_cria_projetos` | Ao ativar, cria um projeto para cada produto que tem `modelo_projeto_id` |
| gatilho `contratos_antes` | Depois de ativo, impede mudar pessoa, datas e valores |

**Não existe:** modelo de contrato (texto e cláusulas), documento gerado, versão do documento, assinatura eletrônica, vínculo do contrato com a oportunidade que o originou, e contrato que mistura uma parte parcelada (implantação) com uma parte recorrente (mensalidade). Hoje o contrato é inteiro recorrente ou inteiro parcelado.

### 1.4 Vendas, financeiro e cobrança

| Estrutura | O que é hoje |
|---|---|
| `vendas` (512, todas `origem_dado = manual`; 123 com plataforma Hotmart) | `pessoa_id`, `produto_id`, `oferta_id`, `plataforma_id`, `campanha_id`, `vendedor_id`, `forma_pagamento` (pix, cartão de crédito, boleto, outro), `parcelas`, `status` (pendente, aprovada, cancelada, reembolsada, chargeback), valores (bruto, taxa, impostos, líquido), datas de aprovação, reembolso e cancelamento, `id_externo` + `pedido_ref`, UTM, `canal_fechamento` |
| `vendas_externo_uq` | **Trava de duplicidade:** uma venda por (workspace, plataforma, `id_externo`) |
| gatilhos de `vendas` | Ao aprovar: `processar_venda` (financeiro + contábil + **matrícula**), `vendas_cria_projeto`, `vendas_mover_jornada`, atribuição, comissão, marcos, recuperação de carrinho abandonado |
| `contas_receber` (583) | `venda_id` **ou** `contrato_id` (obrigatório um dos dois), `parcela`, `vencimento`, `status` (previsto, recebido, cancelado, estornado), desconto, `substituida_por` (renegociação), `conta_receita_id`. **Uma conta por venda** (`contas_receber_venda_id_key`) |
| `registrar_recebimento` / `_parcial` / `registrar_recebimentos_ate` / `desfazer_recebimento` | Baixa **manual** pela equipe |
| `estornos` | cancelamento, reembolso, chargeback, com lançamento |
| `checkout_abandonos` | Carrinho abandonado, com `id_externo` e recuperação |
| `lancamentos` / `partidas` / `plano_contas` / `regras_contabilizacao` | Contábil de partidas dobradas |
| `contas_pagar`, `despesas_recorrentes`, `comissoes`, `custos_cac` | O resto do financeiro |
| `pagamentos_historicos` | Pagamentos antigos lançados à mão |

**Não existe:** entrada automática de vendas por webhook (Hotmart, Kiwify, Eduzz, Asaas, Stripe), cobrança gerada no gateway (Pix e boleto do contrato) e baixa automática por confirmação do gateway. As funções Edge atuais são `leads`, `ideias`, `perguntar`, `avisos`, `zernio-sync` e as do Content; nenhuma recebe vendas.

### 1.5 Jornada do cliente e Customer Growth

| Estrutura | O que é hoje |
|---|---|
| `alunos` (522) | **A matrícula**: pessoa + produto, vinda de `venda_id` ou de `contrato_id` (uma matrícula por venda e uma por contrato), `jornada_id`, `etapa_kanban_id`, `responsavel_cs_id`, `status`, `origem` |
| `jornadas`, `etapas_kanban`, `jornada_marcos`, `aluno_marcos`, `aluno_historico` | Jornada do produto com versão, etapas, marcos (manual, automático ou com confirmação) e histórico |
| `cs_intervencoes`, `alertas` (tipo `cs`), `oportunidades` (expansão e retenção) | Acompanhamento do CS |
| `pesquisas`, `pesquisa_perguntas`, `pesquisa_envios`, `pesquisa_respostas`, `pesquisa_resposta_itens`, `pesquisa_insights` | **Construtor de formulários.** Tipos: `lead`, `onboarding`, `jornada`, `nsm`, `outra`. Gatilhos: `manual`, `cadastro`, `etapa` (etapa do CRM), `entrada_aluno` (ao matricular), `etapa_aluno`, `checkin`. Também `produto_id`, perguntas com `pontos` e `secao` (dá para fazer diagnóstico pontuado) e link aberto |
| `projetos`, `projeto_modelos`, `projeto_modelo_atividades`, `projeto_atividades` | Projetos com modelo de atividades. `projetos` liga `pessoa_id`, `contrato_id`, `venda_id` e `produto_id`; `produtos.modelo_projeto_id` faz o projeto nascer sozinho. **Hoje não há nenhum modelo de projeto cadastrado** |

### 1.6 Configuração por empresa (habilitar e desabilitar)

| Mecanismo | O que faz |
|---|---|
| `pacotes_acesso` (Disparo, Mentoria, Casa, Consultoria) + `acesso_telas` (65 telas) + `workspaces.acesso_liga`/`acesso_desliga` + `acesso_telas_ws()` / `acesso_workspace()` | Liga e desliga **telas** por empresa, com exceções por empresa |
| `funcoes.permissoes` por módulo + `funcoes.acoes` + `equipe.acoes_ind` | O que cada pessoa da empresa pode ler ou editar |
| `workspaces.modo_produto`, `modo_financeiro`, `content_ativo`, `atribuicao_padrao`; `revops_config`, `gm_config`, `alertas_config`, `sistema_config` | Comportamentos por empresa |

**Conclusão:** já existe o mecanismo para ligar e desligar CRM, Contratos, Financeiro, Customer Growth e Pesquisas por empresa. As telas novas (assinatura, onboarding) entram como linhas em `acesso_telas` e nos pacotes. Comportamentos que não são tela (por exemplo, "gerar cobrança no gateway ao ativar o contrato") precisam de configuração por empresa; o padrão já usado é uma tabela de configuração por workspace ou chaves em `sistema_config`.

### 1.7 Arquivos e documentos

Não há bucket no Storage nem tabela de arquivos. Os documentos do Content vão para o Google Drive (`content-drive`). **Lacuna real** para anexos de diagnóstico, contrato assinado e documentos do cliente.

---

## 2. Mapa de relacionamentos (como está hoje)

```
workspaces (empresa usuária, tenant) ──< workspace_membros >── auth.users
   │                                    funcoes (permissão por módulo)
   │ (tudo abaixo tem workspace_id + RLS)
   │
pessoas (cliente/lead) ──< pessoa_toques, pessoa_historico, pessoa_notas, pessoa_funil, pesquisa_respostas
   │  etapa_kanban_id ─> etapas_kanban (CRM)        responsavel_comercial_id ─> equipe
   │
   ├──< oportunidades ─> produtos (1)   ─> contratos (contrato_origem_id)   ─> alunos (aluno_id)
   │
   ├──< contratos ──< contrato_itens ─> produtos
   │       │     ──< contrato_parcelas_plano
   │       │ ativar_contrato()
   │       ├──< contas_receber (contrato_id)
   │       ├──  alunos (contrato_id, único)  ─> jornadas/etapas ─< aluno_marcos, cs_intervencoes
   │       └──< projetos (contrato_id) ─> projeto_modelos (via produtos.modelo_projeto_id)
   │
   └──< vendas ─> produtos, ofertas, plataformas_venda, campanhas      (id_externo único por plataforma)
           │ processar_venda() ao aprovar
           ├──  contas_receber (venda_id, única)
           ├──  lancamentos/partidas
           ├──  alunos (venda_id, único)
           ├──< projetos (venda_id)
           └──< estornos, venda_atribuicoes, comissoes, checkout_abandonos (recuperado_venda_id)

pesquisas (formulário) ─> produtos, etapas_kanban (CRM ou jornada) ──< perguntas, envios, respostas ─> pessoas
```

---

## 3. Fluxos atuais

**3.1 Venda de checkout (hoje manual ou por planilha):**
1. A equipe lança ou importa a venda: `pessoa_resolver` acha ou cria a pessoa e a venda é gravada com `id_externo`.
2. Status `aprovada`: entram a conta a receber única (com a data prevista pela plataforma), o lançamento contábil, a matrícula, o projeto (se o produto tiver modelo), a atribuição de origem e a comissão.
3. Reembolso ou chargeback vira `estornos`.

**3.2 Venda consultiva (contrato):**
1. O lead anda no CRM (`pessoas.etapa_kanban_id`) e o negócio vira "ganho" na pessoa.
2. A equipe cria o contrato em rascunho, com itens do catálogo e, se quiser, o plano de parcelas.
3. `ativar_contrato` gera as parcelas em `contas_receber`, a contabilização, a matrícula e os projetos.
4. A baixa é manual.
5. A oportunidade da tabela `oportunidades` não participa disso; só entra em renovação, expansão e retenção.

**3.3 Jornada:**
1. A matrícula nasce da venda ou do contrato.
2. `alunos_jornada_t` coloca o aluno na primeira etapa da jornada publicada do produto.
3. Os marcos, check-ins, alertas e intervenções acompanham a evolução.
4. A pesquisa com gatilho `entrada_aluno` dispara ao matricular. Isso **já é o onboarding automático após a compra**, mas sem configuração explícita por produto.

---

## 4. Matriz de reaproveitamento (de-para)

Classificação: **R** = já existe e reutiliza · **I** = existe, falta integrar · **A** = existe em parte, precisa adaptar · **N** = não existe.

| Funcionalidade desejada | Estrutura existente | Campos disponíveis | Relacionamentos | Lacuna | Solução proposta | Classe |
|---|---|---|---|---|---|---|
| Cliente único | `pessoas` | nome, e-mail, telefone, `extras`, UTM, responsável | toques, vendas, contratos, alunos, respostas | Nenhuma para PF | Reutilizar. Nunca criar um segundo cadastro | R |
| Cliente empresa (PJ) | `pessoas` + `campos_personalizados` | `extras` | — | Sem tipo PF/PJ, CNPJ e razão social de forma confiável (o contrato precisa) | Estender `pessoas`: `tipo_pessoa` (pf/pj), `documento` (CPF/CNPJ normalizado), `razao_social`. Os outros dados ficam em `campos_personalizados`. Documento único por workspace quando houver | A |
| Contatos da empresa cliente (decisor, financeiro) | `pessoas` | — | — | Não há "pessoa contato de pessoa PJ" | Estender: `pessoas.empresa_id` → outra `pessoas` (PJ). Os contatos continuam sendo pessoas, sem tabela nova | A |
| Empresa cliente com acesso ao Growth's | `workspaces` + `criar_workspace_cliente` | `nome` | — | Não liga com a `pessoas` do cliente no workspace da Mathisa | Estender: `workspaces.cliente_pessoa_id` + `cliente_de_ws` (quem atende), ou `pessoas.workspace_cliente_id`. Só para o modelo agência | A |
| Oportunidade de venda nova no CRM | `pessoas` (negócio) e `oportunidades` | etapa, valor, responsável | pessoa, produto, contrato de origem | Dois conceitos; a oportunidade tem um produto só | Usar `oportunidades` também para `nova_venda`, criada a partir da pessoa no CRM; `pessoas.negocio_*` vira resumo (o último resultado) | I |
| Produtos negociados (vários) e condições (entrada, parcelas, recorrência) | `contrato_itens` + `contrato_parcelas_plano` + `ofertas` | quantidade, valor, plano de parcelas | contrato e produto | A oportunidade não guarda itens nem condições | **A proposta é o contrato em rascunho.** Gerar o contrato rascunho a partir da oportunidade, com os itens do catálogo e as condições. Estender `contratos.oportunidade_id` (vários contratos por oportunidade, por exemplo implantação + mensalidade). Sem tabela de "itens da oportunidade" | A |
| Entrada + parcelas + mensalidade no mesmo fechamento | `contratos` (recorrente ou parcelado) | `contrato_parcelas_plano` | — | O contrato é inteiro recorrente ou inteiro parcelado | Dois contratos da mesma oportunidade (implantação parcelada + recorrência), ligados por `oportunidade_id`. Evita mexer na regra de `ativar_contrato` | A |
| Modelo de contrato (texto) | — | — | — | Não existe | **Nova tabela** `contrato_modelos` (workspace, nome, corpo com variáveis, versão, ativo; por produto ou tipo) | N |
| Documento do contrato gerado e versão | — | — | — | Não existe | **Nova tabela** `contrato_documentos` (contrato, modelo e versão, conteúdo renderizado, **cópia histórica** dos dados usados, hash, arquivo PDF, status de assinatura, ids do provedor) | N |
| Assinatura eletrônica | — | — | — | Não existe | Integração por Edge Function com um provedor (ZapSign, Clicksign ou D4Sign); o webhook atualiza `contrato_documentos`. Assinou → pode chamar `ativar_contrato` (configurável) | N |
| Contas a receber pelas condições aprovadas | `ativar_contrato` → `contas_receber` | parcelas, vencimentos, desconto, renegociação | contrato, venda | Nenhuma | Reutilizar; o plano vem do contrato | R |
| Cobrança Pix ou boleto no gateway | — | — | — | Sem id da cobrança no gateway | Estender `contas_receber`: `gateway`, `cobranca_id_externo` (único por gateway), `link_pagamento`, `cobranca_status`. Edge Function cria a cobrança quando a empresa liga | A |
| Baixa por pagamento confirmado | `registrar_recebimento` | — | — | Só manual | O webhook do gateway chama `registrar_recebimento` **somente** com evento de pago confirmado e idempotência por id do evento | I |
| Vendas de checkout automáticas | `vendas` + `vendas_externo_uq` + `pessoa_resolver` + `estornos` | `id_externo`, `pedido_ref`, plataforma | tudo o que a venda já dispara | Sem webhook | Edge Function `vendas` por plataforma: normaliza, resolve a pessoa e faz upsert idempotente em `vendas` (aprovada, reembolso, chargeback → `estornos`) | I |
| Origem da venda, ids externos e eventos de pagamento | `vendas` (`origem_dado`, `id_externo`, `pedido_ref`, `extras`) | — | — | Sem log de eventos do provedor | Gravar o payload resumido em `vendas.extras` e a trilha em `auditoria` (já existe). Só criar uma tabela de eventos se o volume pedir | A |
| Onboarding configurável (modelos A a E) | `pesquisas` (tipo `onboarding`, gatilhos `entrada_aluno`, `etapa`, `etapa_aluno`) + `produtos.extras` | `produto_id`, `gatilho` | pessoa, aluno, produto | Sem "modo de onboarding" por empresa e produto | Estender `produtos`: `onboarding_modo` (`nenhum`, `automatico`, `formulario`, `diagnostico`, `negociacao`) e `onboarding_pesquisa_id`. O padrão da empresa vai na configuração do workspace. Sem tabela de onboarding | A |
| Diagnóstico | `pesquisas` + perguntas com `pontos`/`secao` + `pesquisa_insights` | — | — | Sem anexos | Reutilizar a pesquisa (tipo `onboarding` ou novo tipo `diagnostico`) + arquivos | A |
| Onboarding antecipado (durante a negociação) | `pesquisas.gatilho = 'etapa'` (etapa do CRM) | — | pessoa | — | Reutilizar: dispara a pesquisa numa etapa do CRM | R |
| Respostas completam o cadastro sem sobrescrever | `pesquisa_respostas` → pessoa | — | — | Sem mapeamento pergunta → campo | Estender `pesquisa_perguntas.campo_destino` (por exemplo `pessoas.documento`, `extras.segmento`). Regra: só preenche campo vazio; o que muda vai para `pessoa_historico` | A |
| Arquivos (diagnóstico, contrato assinado, documentos) | — | — | — | Não existe | **Bucket privado no Storage** + **nova tabela** `arquivos` (workspace, entidade, entidade_id, caminho, tipo, enviado_por) com RLS por workspace | N |
| Implantação de 90 dias | `projeto_modelos` + `produtos.modelo_projeto_id` + `projeto_do_produto` | — | contrato, venda, pessoa, produto | Nenhum modelo cadastrado | Reutilizar: criar o modelo "Implantação 90 dias" (é dado, não estrutura). O projeto encontra o diagnóstico pela pessoa e pelo produto | R |
| Jornada única do cliente | `alunos` + `jornadas` + marcos + `aluno_historico` + `pessoa_toques` | — | venda, contrato | Nenhuma estrutural | Reutilizar; falta uma linha do tempo única na ficha da pessoa (só tela) | R |
| Ligar e desligar módulos por empresa | `pacotes_acesso`, `acesso_telas`, `acesso_liga`/`desliga`, `funcoes` | — | — | Telas novas e comportamentos | Novas linhas em `acesso_telas` + configuração por workspace (`revops_config` como modelo) | R |
| Isolamento entre empresas | `workspace_id` + RLS `pertence_ao_workspace` + `perm()` | — | — | Nenhuma | Um banco só, isolamento por linha. **Não** criar bancos por empresa | R |

---

## 5. Lacunas reais (só estas)

1. **Negociação → contrato:** a oportunidade não gera o contrato e não há `contratos.oportunidade_id`.
2. **Cliente PJ:** não há tipo de pessoa, CPF/CNPJ nem razão social confiáveis, e não há contato ligado à empresa.
3. **Documento e assinatura do contrato:** não há nada.
4. **Cobrança e baixa automáticas** pelo gateway: não há nada.
5. **Vendas de checkout automáticas** (webhooks): não há nada; a trava contra duplicidade já existe.
6. **Onboarding por produto:** a peça existe (pesquisa), falta a configuração e o mapeamento das respostas para o cadastro.
7. **Arquivos:** não há nada.
8. **Vínculo cliente ↔ workspace do cliente:** só no modelo agência (Mathisa).

---

## 6. Riscos de duplicidade e inconsistência (já presentes ou que vão aparecer)

| Risco | Onde | Como evitar |
|---|---|---|
| **A mesma compra virar venda e contrato** (por exemplo, o checkout da entrada e também o contrato) | `alunos` é único por venda e por contrato, mas uma venda e um contrato do mesmo negócio criam **duas matrículas** e **duas receitas** | Regra: o contrato é a fonte da venda consultiva. Pagamento de parcela do contrato baixa a `contas_receber` do contrato e **não** cria `vendas`. Se o checkout for o meio de pagamento, a Edge Function procura a parcela pelo `cobranca_id_externo` antes de criar venda |
| Mesma transação vindo de duas integrações | `vendas` | `vendas_externo_uq` (já existe) + chave do evento do provedor |
| Mesma pessoa com e-mail ou telefone diferentes | `pessoas` | Já há `pessoa_resolver` e mesclagem; para PJ, documento único por workspace |
| Recebível duplicado | `contas_receber` | Única por venda (já existe); para contrato, as parcelas nascem só em `ativar_contrato`, que recusa contrato não rascunho; cobrança única por gateway |
| Baixa sem pagamento | baixa automática | Só com evento de **pago** confirmado e assinado pelo provedor; o resto fica previsto |
| Dois conceitos de negócio no CRM | `pessoas.negocio_*` × `oportunidades` | Oportunidade passa a ser a fonte; o campo da pessoa vira resumo, atualizado por gatilho |
| Resposta do onboarding apagar dado bom | `pessoas` | Preencher só vazio; diferença vai para histórico ou sugestão |
| Contrato mudar depois de assinado | `contratos` | `contratos_antes` já trava depois de ativo; o documento guarda a cópia histórica e o hash |

---

## 7. Proposta de arquitetura integrada

```
CRM (pessoas + etapas) ─> oportunidade (nova_venda) ─> contrato(s) rascunho [itens do catálogo + plano]
   │ pesquisa por etapa (onboarding antecipado)          │ documento a partir do modelo (cópia histórica)
   │                                                    │ assinatura eletrônica (webhook)
   │                                                    ▼
   │                                      ativar_contrato  ──> contas_receber ──> cobrança no gateway ──> webhook pago ──> baixa
   │                                           │
checkout (webhook) ─> vendas (id_externo único) ─> processar_venda ─┐
                                                                  ▼
                                   alunos (matrícula) ─> jornada do produto ─> marcos, check-ins, CS (Customer Growth)
                                        │ onboarding conforme o produto: nenhum | automático | formulário | diagnóstico
                                        ▼
                                   pesquisa → respostas completam pessoas (só o vazio) + arquivos
                                        ▼
                                   projeto pelo modelo do produto (Implantação 90 dias)
```

**Princípios:**
- A pessoa é o cliente.
- O contrato é a fonte da venda consultiva; a venda é a fonte da venda de checkout.
- A matrícula é a jornada; a pesquisa é o formulário e o diagnóstico; o projeto é a implantação.
- Cópia histórica só em dois lugares, com origem guardada: o documento do contrato (dados da pessoa, itens e valores na hora da assinatura) e a versão do contrato.

---

## 8. Mudanças mínimas necessárias (todas aditivas, nenhuma renomeia ou remove)

| # | Mudança | Tipo |
|---|---|---|
| M1 | `pessoas`: `tipo_pessoa`, `documento` (+ normalizado e único por workspace quando houver), `razao_social`, `empresa_id` (contato → empresa) | colunas |
| M2 | `contratos.oportunidade_id`; `oportunidades` passa a aceitar `origem = 'crm'` | coluna + check |
| M3 | `contrato_modelos` | tabela nova |
| M4 | `contrato_documentos` (com status de assinatura e ids do provedor) | tabela nova |
| M5 | `contas_receber`: `gateway`, `cobranca_id_externo` (único), `link_pagamento`, `cobranca_status` | colunas |
| M6 | `produtos`: `onboarding_modo`, `onboarding_pesquisa_id` | colunas |
| M7 | `pesquisa_perguntas.campo_destino`; `pesquisas.tipo` aceita `diagnostico` | coluna + check |
| M8 | `arquivos` + bucket privado | tabela nova + storage |
| M9 | `workspaces.cliente_pessoa_id` (só para agência) | coluna |
| M10 | Configuração por workspace: contratos (assinatura obrigatória? ativar ao assinar?), cobrança (gateway, gerar ao ativar?), onboarding padrão | tabela de configuração no padrão de `revops_config`, ou chaves em `sistema_config` |
| M11 | Edge Functions: `vendas` (webhooks de checkout), `cobrancas` (gateway), `assinatura` (provedor) | código |
| M12 | `acesso_telas`: Contratos (documento e assinatura), Onboarding, Cobranças; incluir nos pacotes | dados |

---

## 9. Os três cenários na arquitetura proposta

**Cenário 1, Mathisa (consultiva):**
1. O lead entra (`pessoas`, PJ com CNPJ via M1) e anda no CRM.
2. Ao entrar na etapa "Proposta", nasce a oportunidade `nova_venda`.
3. "Gerar proposta" cria dois contratos rascunho ligados à oportunidade (M2): implantação com entrada + parcelas (`contrato_parcelas_plano`) e mensalidade recorrente.
4. O documento sai do modelo (M3, M4) e vai para assinatura. Assinou → `ativar_contrato` → `contas_receber` → cobrança Pix ou boleto no gateway (M5).
5. O pagamento confirmado faz a baixa sozinho.
6. A matrícula entra na jornada "Consultoria" e o onboarding do produto é diagnóstico (M6, M7). As respostas completam o cadastro, os anexos vão para `arquivos` (M8), e o projeto "Implantação 90 dias" nasce do modelo do produto.
7. Opcional: o workspace do cliente é criado e ligado à pessoa (M9).

**Cenário 2, infoprodutor com mentoria (checkout ou Pix):**
1. O webhook da plataforma chega à Edge Function `vendas` (M11): pessoa resolvida e venda idempotente.
2. `processar_venda` faz o financeiro (a conta a receber com a data prevista pela plataforma) e a matrícula.
3. A jornada da mentoria começa, e o onboarding segue o produto: `formulario` (opcional) ou `nenhum`. Reembolso vira `estornos`, e a matrícula sai (`alunos_saida`).
4. Sem contrato, sem assinatura e sem projeto, a não ser que o produto tenha modelo.

**Cenário 3, várias origens:**
1. CRM e contrato (cenário 1), checkout (cenário 2) e pagamento manual (`registrar_recebimento` ou venda manual) caem nas mesmas `vendas`, `contratos`, `contas_receber` e `alunos`, com a mesma pessoa graças a `pessoa_resolver` e às travas de e-mail, telefone e documento.
2. Os painéis (`painel_gerencial`, DRE, Customer Growth) já leem dessas tabelas.
3. A regra da seção 6 impede que parcela de contrato paga por checkout vire uma segunda venda.

---

## 10. Plano de implementação por etapas (cada uma com aprovação)

| Etapa | Entrega | Depende de |
|---|---|---|
| E1 | Cliente PF/PJ e contatos (M1) + ficha da pessoa com linha do tempo única (venda, contrato, matrícula, respostas, toques) | — |
| E2 | Oportunidade de venda nova no CRM → contratos rascunho com itens e plano (M2) | E1 |
| E3 | Modelos e documento do contrato com cópia histórica (M3, M4) + arquivos (M8) | E2 |
| E4 | Assinatura eletrônica (provedor escolhido) e ativar ao assinar (configurável, M10) | E3 |
| E5 | Webhooks de checkout (`vendas`) por plataforma, com estornos e abandono | — (pode correr em paralelo com E2) |
| E6 | Cobrança no gateway e baixa automática por pagamento confirmado (M5) | E2 |
| E7 | Onboarding por produto (M6), diagnóstico, campo de destino com "só preenche vazio" (M7) | E1, E8 |
| E8 | Modelo de projeto "Implantação 90 dias" e ligação do diagnóstico ao projeto | — (dados) |
| E9 | Workspace do cliente ligado à pessoa (M9) e telas nos pacotes (M12) | E1 |

---

## 11. Critérios de validação (sem duplicidade, sem perda)

1. **Antes e depois de cada migração**, contar por workspace: `pessoas`, `vendas`, `contratos`, `contas_receber` (soma por status), `alunos`, `lancamentos` (soma das partidas). Os números não mudam; só colunas novas, todas com padrão vazio.
2. **Teste do mesmo evento duas vezes:** o mesmo webhook de venda, de pagamento e de assinatura enviado duas vezes produz um único registro.
3. **Teste de origem dupla:** parcela do contrato paga por checkout dá uma baixa e nenhuma venda nova; uma matrícula só.
4. **Teste do onboarding:** a resposta não sobrescreve campo preenchido, e a diferença aparece no histórico.
5. **Isolamento:** usuário de um workspace não lê nem grava `arquivos`, `contrato_documentos` e `contrato_modelos` de outro (teste de RLS como `authenticated`, não como superusuário. Foi esse tipo de teste que faltou para pegar o erro de publicar a estratégia).
6. **Baixa automática:** só com evento de pago confirmado; os eventos "aguardando", "expirado" e "recusado" deixam a conta prevista.
7. **Regressão:** as baterias `tests/banco` e `tests/tela` atuais continuam passando, e cada etapa ganha cenários próprios nos dois.
8. **Volta:** cada migração termina com o bloco "Para desfazer" e é idempotente.

---

## 12. Decisões tomadas em 30/10/2026 (valem sobre as seções 4 a 11)

| Tema | Decisão | Efeito no plano |
|---|---|---|
| Gateway de cobrança | **Nenhum.** O Growth's não gera cobrança Pix ou boleto | Sai a cobrança no gateway: M5 e E6 do jeito que estavam. A conta a receber do contrato não tem `gateway` nem link de pagamento |
| De onde vem o pagamento | Cada contrato (venda consultiva de serviço) diz **por onde é pago**: **Hotmart** (ou outra plataforma) ou **manual** | Nova regra, abaixo. Reaproveita `plataformas_venda` e `produto_plataforma` (o produto cadastrado na Hotmart, com `id_externo`) |
| Contrato × venda | **Contrato é contrato.** Vem da venda consultiva e não vira venda duplicada. Mentoria pode ser só venda de plataforma, sem contrato | A Hotmart nunca cria uma segunda matrícula nem uma segunda receita para um contrato |
| Negócio do lead | **O lead passa a ser a oportunidade** | `oportunidades` vira a fonte do negócio (`nova_venda` a partir do CRM); `pessoas.negocio_*` vira resumo |
| Cadastro do cliente | **Sempre uma pessoa só**, com **CPF ou CNPJ** no próprio cadastro, preenchido ou atualizado quando ela compra | M1 simplificado: `pessoas.documento` (CPF ou CNPJ, o tipo sai do tamanho) normalizado e único por workspace quando houver. **Sem** contato ligado a empresa (`empresa_id`) e sem razão social. O documento é **obrigatório para gerar o contrato** e é pedido na hora, se faltar |
| Assinatura | **Leitura e aceite eletrônico**; o provedor ainda não foi escolhido | Ver 12.2 |

### 12.1 Regra de pagamento do contrato (sem duplicar)

O contrato ganha **por onde é pago**: `manual` ou uma plataforma de `plataformas_venda` (por exemplo, Hotmart).

**Pagamento manual:**
- `ativar_contrato` gera as parcelas em `contas_receber` como hoje.
- A baixa é feita pela equipe (`registrar_recebimento`), ou de outro jeito, conforme 12.3.
- Não existe venda de plataforma para esse contrato, então não há o que duplicar.

**Pagamento pela Hotmart (ou outra plataforma):**
- O contrato continua gerando as parcelas previstas.
- Quando a compra chega da Hotmart (pela integração ou pela importação), o Growth's procura o **contrato ativo da mesma pessoa** (por e-mail, telefone ou documento) **com o mesmo produto** (`produto_plataforma.id_externo`) e **pago pela Hotmart**.
- Se acha:
  - a compra é registrada **ligada ao contrato** (nova coluna `vendas.contrato_id`);
  - a parcela correspondente recebe a baixa com a data e o valor da Hotmart;
  - `processar_venda` **não** cria matrícula nem conta a receber própria, porque o contrato já tem as duas.
- Se não acha, é uma venda normal de plataforma (o caso da mentoria sem contrato), com matrícula e financeiro próprios, como hoje.
- Reembolso ou chargeback de uma compra ligada a contrato estorna a parcela e avisa a equipe; o contrato não é cancelado sozinho.

**Garantias:**
- A trava `vendas_externo_uq` impede a mesma transação duas vezes.
- `alunos` continua com uma matrícula por contrato.
- `contas_receber` só nasce em `ativar_contrato` (contrato) ou em `processar_venda` (venda sem contrato).

### 12.2 Aceite eletrônico (provedor em aberto)

Há dois caminhos. Os dois usam `contrato_modelos` e `contrato_documentos` (M3, M4).
- **Aceite no próprio Growth's (sem provedor):** o cliente recebe um link, lê o contrato e aceita. O sistema grava data e hora, e-mail, IP, navegador e o hash do documento; o PDF fica em `arquivos`. Não tem custo e resolve a maior parte dos serviços.
- **Provedor de assinatura (ZapSign, Clicksign, D4Sign, DocuSign…):** dá validade com certificado e trilha do provedor. Entra depois, na mesma estrutura, quando o nome for escolhido.

Proposta: começar pelo aceite no próprio Growth's e deixar o provedor como plugável.

### 12.3 Recebimento pela plataforma: o saldo fica na Hotmart até o saque

**Decisão (30/10):** na Hotmart (e plataformas parecidas), quem recebe é a plataforma. Quando ela confirma o pagamento, a venda ou a parcela do contrato **já está recebida**, mas o dinheiro **fica na Hotmart** até ser transferido para o banco. "Baixa automática" quer dizer isto: a baixa vem da confirmação da plataforma.

**Como está hoje:**
- `processar_venda` cria a conta a receber **prevista**, com vencimento em `data_prevista_recebimento` (a data em que a Hotmart libera o dinheiro), e alguém precisa marcar como recebida depois. Em produção, das 496 contas a receber de vendas, **412 estão previstas**.
- `contas_bancarias.tipo` só aceita `conta` e `cartao`; não há conta que represente o saldo na plataforma.
- Não há transferência entre contas próprias; só existe `transferir_para_casa`.

**Proposta, reaproveitando o financeiro:**
1. **Conta "Saldo Hotmart"**: `contas_bancarias.tipo` passa a aceitar `plataforma`, e `plataformas_venda.conta_bancaria_id` diz qual conta guarda o saldo de cada plataforma. É uma conta de verdade, com saldo, extrato e conta contábil.
2. **Pagamento confirmado pela plataforma**: a conta a receber (da venda ou da parcela do contrato pago pela Hotmart) recebe a baixa **na hora**, na conta "Saldo Hotmart", na data da aprovação. Isso fica separado em dois números:
   - **a liberar**: aprovado, mas antes de `data_prevista_recebimento`;
   - **disponível para saque**: depois dessa data.
3. **Saque**: uma transferência entre contas próprias, "Saldo Hotmart → banco" (nova função `transferir_entre_contas`, com lançamento contábil e uma movimentação em cada conta). Não é receita de novo, só troca de lugar. As taxas da Hotmart já saem em `taxa_plataforma` na venda.
4. **Reembolso ou chargeback** depois da baixa: o estorno sai do Saldo Hotmart (`estornos`, que já existe).
5. **Pagamento manual** (contrato pago fora de plataforma): a equipe dá a baixa, como hoje. Conferir com o extrato importado (`movimentacoes_bancarias`) é opcional e fica para depois.

**Dados antigos:** as 412 contas previstas de vendas da Hotmart **não mudam sozinhas**. Depois, com a sua aprovação, uma rotina pode dar a baixa das que a Hotmart já confirmou, na conta Saldo Hotmart, sem apagar nada.

**Mudanças:** `contas_bancarias.tipo` + `plataforma`; `plataformas_venda.conta_bancaria_id`; função `transferir_entre_contas`; `processar_venda` e a integração passam a dar baixa na conta da plataforma quando a venda vem confirmada. Entra na **E4** (pagamento do contrato e Hotmart).

### 12.3.1 Em aberto

- **"Baixa automática" no pagamento manual:** resolvido acima. Manual = a equipe dá a baixa; plataforma = a baixa vem da confirmação dela. Sem gateway, não há confirmação externa de pagamento. Há três jeitos possíveis:
  - (a) a equipe dá a baixa, como hoje;
  - (b) a parcela recebe baixa sozinha no vencimento, a não ser que alguém marque que não pagou;
  - (c) a baixa vem do extrato bancário importado (`movimentacoes_bancarias` já existe).

  A diretriz original pede para não dar baixa sem confirmação válida; a opção (b) contraria isso.
- **Nome do provedor de assinatura**, se não for o aceite no próprio Growth's.

### 12.4 Mudanças mínimas revisadas

| # | Mudança | Antes | Agora |
|---|---|---|---|
| M1 | `pessoas.documento` (CPF/CNPJ normalizado, único por workspace quando houver) | também tipo, razão social e `empresa_id` | só o documento |
| M2 | `contratos.oportunidade_id` + oportunidade `nova_venda` vinda do CRM | igual | igual |
| M3/M4 | `contrato_modelos`, `contrato_documentos` (aceite: data, e-mail, IP, hash) | com provedor | aceite próprio; provedor depois |
| M5 | `contratos.pagamento_por` (`manual` ou `plataforma_id`) + `vendas.contrato_id` + `contas_receber.venda_id` da baixa vinda da plataforma | gateway em `contas_receber` | sem gateway |
| M6/M7 | onboarding por produto e `campo_destino` | igual | igual |
| M8 | `arquivos` + bucket privado | igual | igual (guarda o PDF aceito) |
| M9 | `workspaces.cliente_pessoa_id` | igual | igual |
| M11 | Edge Function `vendas` (Hotmart primeiro) com a regra 12.1 | `vendas`, `cobrancas` e `assinatura` | só `vendas`; `assinatura` quando houver provedor |

**Etapas revisadas:**
- E1: documento da pessoa e linha do tempo única.
- E2: oportunidade → contrato rascunho.
- E3: modelo, documento e aceite eletrônico, com arquivos.
- E4: pagamento do contrato (manual ou Hotmart) com a regra 12.1, a integração da Hotmart e a importação ligando ao contrato.
- E5: onboarding por produto e diagnóstico.
- E6: modelo de projeto "Implantação 90 dias".
- E7: workspace do cliente ligado à pessoa e telas nos pacotes.

## 13. Decisões que dependiam de você (perguntas originais)

1. **Provedor de assinatura:** ZapSign, Clicksign, D4Sign ou outro.
2. **Gateway de cobrança** para Pix e boleto dos contratos: Asaas, Iugu, Pagar.me, Mercado Pago ou outro. E se a baixa automática fica ligada por padrão.
3. **Quais plataformas de checkout entram primeiro:** Hotmart (já usada), Kiwify, Eduzz ou outras.
4. **Mensalidade + implantação:** dois contratos por oportunidade (recomendado, não mexe na regra atual) ou um contrato com itens recorrentes (exige reescrever `ativar_contrato`).
5. **O negócio do lead** passa a ser a `oportunidade` (recomendado) ou continua na pessoa.
