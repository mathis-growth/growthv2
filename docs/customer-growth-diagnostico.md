# Customer Growth — Jornada e Inteligência do Cliente · Diagnóstico técnico (Fase A)

Data: 29/10/2026 · Base: branch `v0.162-growth-model-nsm` (commit `6374eaa`), ainda não juntada à `main`.
Situação: **só diagnóstico**. Nada foi implementado, nenhuma migration foi rodada, nada foi commitado.

## 0. O que foi verificado e o que não foi

**Verificado (lendo o código):**
- As 132 migrations em `supabase/migrations` (lidas por inteiro as de CRM, alunos, funis, pesquisas, RevOps, contratos, ofertas, projetos, permissões, auditoria e alertas; as de conteúdo, Instagram e contabilidade só pelo índice de tabelas e funções).
- O `index.html` (17.608 linhas): menu, rotas, Kanban, Alunos, ficha da pessoa, cadastro de Produtos, Oportunidades, Pesquisas, Retenção & Expansão, Dashboard de RevOps, Alertas.
- As edge functions em `supabase/functions` (o que cada uma faz, pelo cabeçalho; a `avisos` foi lida mais a fundo).
- `docs/modelo-de-dados.md`, `docs/growths-o-sistema.md` (seção RevOps) e os testes em `tests/`.

**Não verificado:**
- **O banco de produção** (projeto `yngyghlyonybvfvjcmxl`) não pode ser acessado daqui. Tudo abaixo vale para o que está nas migrations. O próprio `modelo-de-dados.md` marca itens como "pendente em produção" (ex.: alertas da v0.132, `saldo_minimo` da v0.127), então o banco real pode estar atrás das migrations.
- Os dados reais: quantos alunos, etapas e pesquisas existem por cliente.
- Se as edge functions publicadas são as mesmas do repositório.
- Os scripts `RODAR_v*.sql` e `seed` foram listados, mas não comparados linha a linha com as migrations.

---

## 1. Inventário verificado

### 1.1 Isolamento, usuários e permissões
| Item | Onde |
|---|---|
| Cliente = `workspaces`; membros em `workspace_membros` (admin/editor/leitor) | `20261005230000_schema_inicial.sql:11-22` |
| `pertence_ao_workspace(ws)` e `pode_operar(ws)`: base de todas as políticas de acesso | `schema_inicial.sql:24-38` |
| Funções e permissões por módulo: `funcoes`, `perm(ws, req, mods)`, `nivel_modulo`, `minhas_permissoes`, `eh_admin` | `20261006370000_empresa_funcoes_acessos.sql:43, 70-117` |
| Permissão por ação (ver/editar) e lista de recursos; `alunos` e `aluno_historico` = ler em revops, vendas, adm, prj, fin, gro e editar em revops, vendas | `20261006420000_permissoes_por_acao.sql:8-71`; `empresa_funcoes_acessos.sql:171` |
| Telas liberadas por pacote: `acesso_telas` + `pacotes_acesso`. RevOps tem `ho-dash`, `ho-ascensao`, `ho-cohort`, `crm-alunos`, `ho-retencao` | `20261010230000_pacotes_acesso.sql:11, 36-39`; `index.html:9982-9986` (`telaLiberada`) |
| Equipe (quem recebe aviso, por canal): `equipe` | `20261006180000_projetos_equipe_links.sql:11` |

### 1.2 CRM: pessoas, leads, alunos, oportunidades e funis
| Item | Onde |
|---|---|
| **`pessoas`** é o cadastro único de lead e cliente (`status_funil` lead/cliente, `status_cliente`, origem, UTM, qualificação, `tags`, `negocio_status`, `responsavel_comercial_id`, `extras` jsonb, `captada`) | `schema_inicial.sql:198`; colunas em `20261006280000_crm_negocio_tags.sql:14-18`, `20261006350000…:5`, `20261007190000_campos_personalizados.sql:16`, `20261006470000…:6` |
| Histórico da pessoa (só append): `pessoa_historico` (status, qualificação, formulário) | `schema_inicial.sql:231-283` |
| Notas: `pessoa_notas` | `20261006320000_cac_grupo_e_notas_lead.sql:6` |
| Histórico de responsável comercial **e de CS** (`tipo` comercial/cs, `aluno_id`, motivo, quem alterou): `responsavel_historico` | `20261006390000_responsavel_historico_vendedor.sql:3` |
| Pontos de contato da pessoa (entrada, etapa, lista, vídeo, disparo, comercial, compra, recompra), gravados por gatilhos: `pessoa_toques` | `20261008220000_estrategias_jornada.sql:88-231` |
| Cadastros repetidos (mesclagem): `pessoas_mesclagens` | `20261011000000_fase1_confianca_dado.sql:39` |
| **`alunos`** = matrícula: uma por venda (`venda_id` único) ou por contrato (`contrato_id`), com `produto_id`, `tag`, `etapa_kanban_id`, `status` ativo/inativo/cancelado, `entrou_em`, `saiu_em`, `responsavel_cs_id`, `origem` | `schema_inicial.sql:323`; `20261006190000_heavy_ops.sql:8`; `20261006350000…:6`; `20261006470000…:23-25` |
| O aluno nasce sozinho: venda aprovada (`processar_venda`), contrato ativado, cliente antigo (`cadastrar_cliente_historico`); reembolso/estorno cancela (`registrar_estorno`) | `schema_inicial.sql:478-531, 595-639`; `20261006470000_historico_onboarding_leads.sql:32, 63-94` |
| **`aluno_historico`**: cada mudança de etapa, saída e volta (gatilho `aluno_historico_t`) | `20261006240000_funil_pos_compra.sql:5-43` |
| Etapas de Kanban: `etapas_kanban` com `quadro` leads/alunos/oportunidades, `descricao` (o que fazer), `mensagem_padrao`, `alertar_responsavel` | `schema_inicial.sql:189`; `20261006350000…:2-4`; `20261006560000_oportunidades.sql:2-3` |
| Aviso ao CS quando o aluno entra numa etapa marcada ou muda de CS: `aluno_alerta_etapa` → `equipe_avisa` → `notificacoes` | `20261006350000_etapas_responsaveis_alertas.sql:14, 75-95` |
| **`oportunidades`** com clientes: `tipo` nova_venda/renovacao/ajuste, `produto_id`, `contrato_origem_id`, valor, previsão, etapa (quadro `oportunidades`), `status`, responsável | `20261006560000_oportunidades.sql:4-29` |
| **Funis / "Jornada do funil"** (pré-compra): `funis` (com `produto_id`), `funil_etapas` (entrada/meio/compra), `funil_listas`, `pessoa_funil`, `pessoa_lista`, `pessoa_funil_historico`; venda aprovada leva à etapa de compra (`vendas_mover_jornada`) | `20261006000000…:19`; `20261006120000_jornada_trafego_contabilidade.sql:15-200` |
| Estratégias (métricas do funil por campanha): `etapas_catalogo`, `estrategia_etapas`, `campanha_etapas`, `campanha_etapa_valores` | `20261008220000_estrategias_jornada.sql:13-69` |

### 1.3 Produtos
| Item | Onde |
|---|---|
| `produtos`: nome, `tag` (vai para o Kanban de alunos), tipo, recorrência, preço, `nivel_escada`, `categoria`, `modelo_projeto_id`, `extras` | `schema_inicial.sql:127`; `heavy_ops.sql:5`; `20261012100000_revops_retencao.sql:17`; `20261006340000…:6` |
| Ofertas com versões e pacote: `ofertas` (status, vigência, `versao`), `oferta_itens`, **`oferta_versoes` imutável** (gatilho `oferta_versoes_imutavel`), `oferta_salvar` | `20261008080000_ofertas_e_calculadora.sql:2`; `20261011700000_ofertas_esteira_campanha.sql:13-155` |
| Esteira da campanha (upsell/downsell): `campanha_ofertas` + `campanha_ofertas_valida` | `ofertas_esteira_campanha.sql:158-245` |
| Escada de valor: `produtos.nivel_escada` + `revops_ascensao` | `20261006400000_revops_ascensao.sql:2` |
| "Jornada entre produtos" do simulador (probabilidade de A → B): é **planejamento**, não acompanhamento | `index.html:9831` (`gpsTabJornada`) |
| Ficha de conteúdo por produto (`content_produtos`): é do Growth's Content, separada do cadastro comercial (liga por `produto_id` opcional) | `20261110100000_content_produtos_v2.sql:6` |

### 1.4 Vendas, contratos, pagamentos e abandonos
| Item | Onde |
|---|---|
| `vendas` (status aprovada/cancelada/reembolsada/chargeback, datas de cada mudança, `oferta_id`, `vendedor_id`, `pedido_ref`, UTM) | `schema_inicial.sql:287`; `fase1_confianca_dado.sql:154-162`; `20261022100000_comissoes.sql:21` |
| `contratos` + `contrato_itens` (recorrência, parcelas, ativação, cancelamento) | `20261006270000_contratos.sql:15-264` |
| `contas_receber`, `estornos`, `pagamentos_historicos` (pago antes do sistema) | `schema_inicial.sql:311, 373`; `historico_onboarding_leads.sql:42` |
| `checkout_abandonos`, `venda_atribuicoes` | `20261011100000_fase2_captacao_vendas.sql:273, 356` |
| Projeto do cliente nasce sozinho na venda/contrato quando o produto tem modelo (`projeto_do_produto`) | `20261006340000_projeto_cliente_canais.sql:1-50` |

### 1.5 Financeiro e métricas de cliente
| Item | Onde |
|---|---|
| **Regra única de compra válida e receita por cliente**: `revops_itens`, `revops_pedidos`, `revops_receitas` (vendas aprovadas + contratos) | `revops_retencao.sql:46-108` |
| Coortes, recompra, RFM, clientes de um recorte: `revops_coortes`, `revops_recompra`, `revops_rfm`, `revops_rfm_clientes`, `revops_clientes`, `revops_clientes_de`; configuração `revops_config`, visões salvas `revops_visoes` | `revops_retencao.sql:19-367` |
| Coortes por matrícula (versão antiga): `revops_cohorts` | `20261006360000_revops_cohorts.sql:6` |
| Dashboard de RevOps: `heavyops_painel` (ativos, churn, retenção, curva, LTV, ascensão, etapas) + metas `heavyops_metas` | `heavy_ops.sql:22-35` |
| Pós-compra na análise de funil: `funil_membros`, `funil_analise`, `funil_cohorts` (chaves `alunos`, `a:<etapa>`, ativos, saiu, ascensão, recompra) | `funil_pos_compra.sql:48-285` |
| Dicionário de métricas `metricas_definicoes` (inclui `churn`, `mrr`, `ticket_medio`, `cliente`) e semântica (unidade, direção) | `fase1_confianca_dado.sql:399-430`; `20261112100000_metricas_semantica.sql` |
| Árvore dos números `arvore_no` / `arvore_serie` (nós `rec.arr`, `rec.base`, `rec.nrr`, `ven.ticket`…) | `20261020100000_arvore_numeros.sql:373`; `20261024100000_arvore_serie.sql` |

### 1.6 Eventos, histórico e auditoria
- `auditoria` (inclusão/alteração/exclusão, antes/depois, usuário) por gatilho `auditar()` em vendas, contratos, produtos, pessoas e cadastros — **`alunos` não está na lista** (`fase1_confianca_dado.sql:193-250`).
- Históricos específicos: `pessoa_historico`, `aluno_historico`, `pessoa_funil_historico`, `responsavel_historico`, `pessoa_toques`.
- `uso_eventos` é uso da plataforma pela equipe (telas, tempo), **não** evento do cliente final (`20261006490000_uso_plataforma.sql:3`).

### 1.7 Coletas, pesquisas e formulários
- `pesquisas` (tipo lead/onboarding/**jornada**/nsm/outra; `gatilho` manual/cadastro/**etapa**/**entrada_aluno**; `funil_id`; visual e captação), `pesquisa_perguntas` (papel livre/nps/pmf/valor/alavanca/qualificacao, `pontos`, `secao`), `pesquisa_envios` (fila, token), `pesquisa_respostas`, `pesquisa_resposta_itens`, `pesquisa_insights` (`20261006230000_pesquisas.sql:5-90`; `20261026100000…`; `20261027100000…`).
- Gatilhos: `pesquisa_trg_pessoa` (cadastro), `pesquisa_trg_etapa` (**ouve `pessoa_funil_historico`, ou seja, etapas do funil**), `pesquisa_trg_aluno` (vira aluno) (`pesquisas.sql:93-131`).
- Telas: `vPesquisas`, `modalPesquisa`, `vPesquisaDet`, `vPesquisaPublica`; modelos `PQ_MODELOS` (`index.html:13950-14283`).

### 1.8 Automações
- Agendador de hora em hora (`pg_cron` `growths-alertas`, minuto 7) → `growths_rodar_agendado` → `growths_verificar_alertas` + `growths_resumo_gerar` → fila `notificacoes` → edge function `avisos` (e-mail e WhatsApp) (`20261028100000_assistente_alertas.sql:13-470`; `supabase/RODAR_v0.132_agendador.sql:12-13`; `supabase/functions/avisos`).
- Regras atuais: `queda_seguida`, `sem_vendas`, `cpl_meta`, `reembolsos`, `gasto_sem_lead`, `saldo`, `saldo_minimo`, mais variação brusca. **Nenhuma olha alunos** (zero menções a `alunos` na migration).
- Gatilhos de etapa com aviso ao responsável (leads e alunos), projeto automático por produto, toques automáticos, pesquisas por gatilho.
- Edge functions: `avisos`, `conexoes`, `leads`, `zernio-sync`, `perguntar`, `ideias`, `linha-editorial`, `content-*`. Nenhuma de CS.

### 1.9 Tarefas e projetos
- `projetos` (pode ter `pessoa_id`, `produto_id`, `venda_id`, `contrato_id`), `projeto_atividades` (responsável, status, prazo, dependências), modelos de projeto, `notificacoes` (`projetos_equipe_links.sql:11-118`; `projeto_cliente_canais.sql:1-9`). Telas `vProjetos`, `vMinhas` (`index.html:13266, 13439`).
- Atividade **só existe dentro de projeto** (`projeto_id not null`).
- Ciclo de Growth (`growth_experimentos`, `gm_decisoes`, `vGrowthCiclo`) também usa a palavra "intervenção", mas é experimento de growth, não ação de CS.

### 1.10 Telas (index.html)
| Tela | Onde |
|---|---|
| Menu RevOps: Dashboard, Retenção & Expansão, Alunos | `index.html:1181` |
| Rotas | `index.html:1584-1588` |
| Kanban genérico: `quadro()`, `ligaArrastar()` (arrasta e grava `etapa_kanban_id` ou `etapa_id`), `gerirEtapas(quadro)` | `index.html:2702-2767` |
| Alunos (Kanban único, filtro por tag do produto, CS responsável, situação) | `index.html:2883` (`vCrmAlunos`) |
| Oportunidades (Kanban) | `index.html:2818-2882` |
| Jornada do funil (pré-compra) | `index.html:3754` (`vJornada`) |
| Ficha da pessoa (modal em seções: contato, responsáveis com CS por matrícula, origem, jornada de compra, toques, compras, vídeos, projetos, negócio, notas, linha do tempo). **Não mostra `aluno_historico` nem respostas de pesquisa.** | `index.html:3803-3920` (`fichaPessoa`) |
| Clientes (lista e cadastro) | `index.html:3936, 3988` |
| Cadastro de Produtos: CRUD genérico (`vCad`, definição `produtos`) com as ofertas embaixo; **não tem abas** | `index.html:4122-4135, 4322-4325, 5952` |
| Retenção & Expansão (coortes, recompra, RFM, investigar) | `index.html:6890` (`vRetencao`) |
| Dashboard de RevOps | `index.html:13692` (`vHeavyOps`) |
| Pós-compra na análise de funil | `index.html:13871` |
| Alertas e resumo do dia | `index.html:14621` (`vAlertas`) |
| Dicionário de métricas | `index.html:17190` (`vMetricas157`) |

---

## 2. Matriz de reaproveitamento

| Funcionalidade necessária | O que já existe | O que falta | Decisão |
|---|---|---|---|
| **Cadastro de clientes** | `pessoas` + `fichaPessoa` + `vClientes`/`modalCliente`; mesclagem; `extras` e campos personalizados (`index.html:3803, 3936, 3988`; `schema_inicial.sql:198`) | Nada no cadastro. Falta só a visão de evolução na ficha | **Reaproveitar.** Nenhuma tabela de cliente nova. Customer Growth lê `pessoas` |
| **Cadastro de produtos** | `produtos`, `ofertas`/`oferta_versoes`, `nivel_escada`, `categoria` (`index.html:4122`; `ofertas_esteira_campanha.sql:13-72`) | Ligação produto → jornada; tela com abas | **Reaproveitar e estender** (só a ligação nova, ver §4) |
| **Histórico de compras** | `revops_itens`/`revops_pedidos`/`revops_receitas`; seção Compras da ficha (`revops_retencao.sql:46-108`; `index.html:3867-3869`) | Nada | **Reaproveitar.** Proibido recalcular compra ou LTV fora de `revops_receitas` |
| **Kanban** | `quadro()` + `ligaArrastar()` + `gerirEtapas()`; quadro `alunos` com histórico e aviso ao CS (`index.html:2702-2767, 2883`) | Etapas são **uma lista só por cliente**, iguais para todos os produtos (não há `produto_id` em `etapas_kanban`); o filtro "por produto" é só pela tag | **Estender** `etapas_kanban` (quadro `alunos`) com produto/jornada, sem criar outro Kanban |
| **Jornadas** | Etapas do aluno (`etapas_kanban` quadro `alunos`) + `aluno_historico` + pós-compra em `funil_analise`. Jornada do funil (`funis`) é pré-compra | Jornada **por produto**, **versão**, publicação, marcos | **Criar só o "cabeçalho" da jornada** (`jornadas`, com versão) e ligar as etapas existentes a ela |
| **Métricas de clientes** | `heavyops_painel` (churn, retenção, LTV, ascensão), `revops_coortes`/`recompra`/`rfm`, `funil_cohorts`, `metricas_definicoes`, `arvore_no` | Indicadores de evolução (tempo até marco, % no prazo, ativação, adesão a check-in); **duas regras de LTV** hoje (ver riscos) | **Reaproveitar** as funções; novos indicadores em **uma** função nova que só lê, com definição no dicionário |
| **Coletas e formulários** | Módulo Pesquisas completo, com tipo `jornada` e `onboarding`, NPS, PMF, captação, qualificação (`pesquisas.sql`; `index.html:13950-14283`) | Gatilho por **etapa do aluno** (hoje só funil); repetição (check-in periódico); ligação resposta → matrícula e marco | **Estender Pesquisas.** Nada de segundo construtor de formulário |
| **Gatilhos** | Agendador de hora em hora + `alertas` + `notificacoes` + `avisos`; `aluno_alerta_etapa`; gatilhos de pesquisa (`assistente_alertas.sql`; `etapas_responsaveis_alertas.sql:75-95`) | Regras de CS (parado na etapa, marco atrasado, check-in sem resposta, NPS baixo, sem acesso) e aviso ao **CS responsável** | **Estender** `growths_verificar_alertas` (ou uma função irmã chamada pelo mesmo `growths_rodar_agendado`). Nenhum motor novo |
| **Oportunidades** | `oportunidades` + Kanban + ficha (`oportunidades.sql:4-29`; `index.html:2818-2882`); sinais de expansão em RFM e ascensão | Tipos de expansão/upsell; ligação com a matrícula e com a origem (alerta, RFM, marco) | **Estender** `oportunidades` (colunas opcionais e tipos novos) |
| **Tarefas e intervenções** | `projeto_atividades` (presa a projeto), `pessoa_notas`, `notificacoes`, `vMinhas` | Ação de CS ligada a **matrícula e alerta**, com resultado; hoje não existe tarefa fora de projeto | **Tabela própria `cs_intervencoes`** (decidido em 29/10, ver §4.6), ligada a matrícula, alerta, etapa, marco e resultado; reaproveita `equipe`, `notificacoes` e "Minhas atividades" |

---

## 3. Lacunas reais (comparadas com o que existe)

| Item pedido | Já existe | Lacuna real |
|---|---|---|
| Funil do aluno por produto | Etapas do aluno e pós-compra do funil; filtro por tag | Etapas por produto. Hoje todos os produtos dividem as mesmas etapas |
| Versionamento de jornadas | Padrão pronto em `oferta_versoes` (foto imutável) e `narrativa_modelos_historico` | Não há versão de etapas. Editar uma etapa muda o passado de todo mundo |
| Etapas e marcos | Etapas (`etapas_kanban`) com "o que fazer" e alerta | **Marcos** (resultado esperado, evidência, prazo) não existem |
| Matrículas ligadas à jornada | `alunos` já é a matrícula (uma por venda/contrato) | Só falta `alunos.jornada_id` (versão em que a pessoa entrou) |
| Coletas | Pesquisas | Ligação da resposta com matrícula, etapa e marco |
| Check-ins | Pesquisa de jornada manual/por etapa do funil | (a) gatilho por etapa do aluno; (b) repetição: `pesquisa_envios` tem `unique (pesquisa_id, pessoa_id)`, então a mesma pessoa só recebe uma vez |
| Sinais observados / declarados / validados | Observados soltos: `pessoa_toques`, `presencas_video`, compras. Declarados: respostas de pesquisa | Um lugar que diga "este marco foi atingido", de onde veio (observado, declarado) e quem validou |
| Histórico de progressão | `aluno_historico` (etapa, saída, volta) | Não guarda **quem** moveu nem marcos; `alunos` está fora da `auditoria` |
| Gatilhos de acompanhamento | Agendador + alertas + aviso de etapa | Regras de CS (nenhuma regra atual olha alunos) |
| Intervenções de CS | Notas, projetos, avisos | Registro da ação com motivo, responsável, prazo e resultado |
| Indicadores de evolução | Churn, retenção, LTV, ascensão, coortes | Tempo até cada marco, % no prazo, adesão a check-in, NPS por etapa ligado ao produto |

**Bug/inconsistência encontrada:** o modelo "Jornada: NPS da etapa" diz para trocar o gatilho para "Quando entra em uma etapa" (`index.html:13962`), mas esse gatilho só ouve as **etapas do funil** (`pesquisa_trg_etapa` em `pessoa_funil_historico`, `pesquisas.sql:115-123`; a tela lista `funil_etapas`, `index.html:14037`). Uma pesquisa de jornada do aluno por etapa **nunca dispara sozinha** hoje.

---

## 4. Relacionamentos propostos (tudo aditivo e reversível)

Princípio: a matrícula continua sendo `alunos`, as etapas continuam em `etapas_kanban`, a movimentação continua em `aluno_historico`, a coleta continua em Pesquisas, o alerta continua em `alertas`/`notificacoes`, a oportunidade continua em `oportunidades`. Só entram as peças que não existem.

```
produtos ──1:N── jornadas (versão, status) ──1:N── etapas_kanban (quadro='alunos', + jornada_id, produto_id)
                     │                                  └─1:N── jornada_marcos (novo)
                     └─1:N── alunos (+ jornada_id) ──1:N── aluno_historico (existe; + por quem)
                                   │                   └─1:N── aluno_marcos (novo: sinais)
                                   ├── pesquisa_envios (+ aluno_id, ciclo) ── pesquisa_respostas
                                   ├── alertas (regras de CS; dados.aluno_id)
                                   ├── cs_intervencoes (novo: alerta, etapa, marco, resultado)
                                   └── oportunidades (+ aluno_id, origem)
```

### 4.1 Jornada por produto e versão
- **Nova tabela `jornadas`**: `workspace_id`, `produto_id` (vazio quando é modelo), `nome`, `modelo` (sim/não), `versao`, `status` (rascunho, publicada, arquivada), `publicada_em`, `publicada_por`, `baseada_em` (versão anterior ou modelo de origem). Uma publicada por produto.
- **`etapas_kanban` + `jornada_id` e `produto_id`** (nulos). Etapa sem jornada = "jornada geral" de hoje, que continua funcionando igual.
- Publicar = congelar as etapas daquela versão (mesmo padrão de `oferta_versoes_imutavel`). Mudar depois = nova versão.
- **Alunos que já estão dentro (decidido em 29/10):** ao publicar uma versão nova, a tela pergunta o que fazer com quem já está matriculado:
  - **Continuar na versão atual:** ninguém muda; só quem entrar daqui para a frente usa a nova.
  - **Transferir para a nova:** a tela mostra cada etapa antiga ao lado de uma lista para escolher a etapa equivalente na nova (já sugere pelo nome). Dá para transferir todos ou só alguns (por etapa ou marcando os alunos). Cada transferência entra no histórico do aluno (`aluno_historico`, tipo novo `jornada`, com versão de origem e de destino), e o tempo na etapa recomeça só se a etapa mudar de fato.
  - A mesma opção fica disponível depois, num botão **Transferir alunos** na aba da jornada, para quem escolheu "continuar" e mudou de ideia.
- **Jornada geral (decidido em 29/10):** produto sem jornada própria usa as etapas que existem hoje (quadro `alunos`), agora com o nome "Jornada geral". Nada muda para quem já usa.
- **Modelos de jornada (decidido em 29/10):** dá para salvar uma jornada como modelo (ex.: "Mentoria", "Curso online") e criar a jornada de um produto a partir dele. Sem tabela nova: é uma linha de `jornadas` sem `produto_id` e com `modelo = true`; usar um modelo copia as etapas e os marcos para o produto, e a cópia passa a ser só dele. O Growths pode vir com dois ou três modelos prontos para começar.
- Alternativa descartada: copiar etapas para uma tabela nova `jornada_etapas`. Duplicaria Kanban, `aluno_historico`, `aluno_alerta_etapa`, `funil_membros` (chave `a:<etapa>`) e `heavyops_painel`.

### 4.2 Marcos
- **`jornada_marcos`**: `jornada_id`, `etapa_kanban_id` (opcional), `nome`, `descricao`, `evidencia` (o que prova), `prazo_dias` (desde `alunos.entrou_em`), `obrigatorio`, `ordem`, `confirmacao` e `regra`.
- **Como o marco é confirmado (decidido em 29/10: depende do marco).** Cada marco escolhe um destes três jeitos (`confirmacao`):
  - **Manual:** só alguém da equipe confirma (ex.: "apresentou o plano na mentoria").
  - **Automático:** o sistema marca sozinho quando acontece o que está na `regra`.
  - **Automático com confirmação:** o sistema percebe e deixa o marco como "aguardando confirmação"; alguém da equipe confirma ou recusa.
- **O que o sistema já consegue perceber sozinho** (`regra`, com dados que o Growths já guarda):
  - comprou um produto (vendas e contratos válidos, pela regra de `revops_itens`);
  - assistiu a uma aula ou vídeo, ou um tempo mínimo (`presencas_video`);
  - respondeu uma pesquisa, ou deu uma resposta específica (ex.: "já faturei com o método" = Sim) (`pesquisa_respostas`);
  - chegou a uma etapa da jornada (`aluno_historico`);
  - entrou numa lista ou grupo (`pessoa_lista`).
- **O que precisa vir de fora** (ex.: "entrou na plataforma do curso", "entregou o trabalho XPTO"): o Growths não enxerga a área de membros hoje. Proposta: um endereço para receber eventos, no mesmo esquema do que já recebe leads e vendas (edge function `leads` com chave de escopo próprio em `chaves_api`, que hoje aceita `ideias`, `leads` e `vendas` — `20261018100000_leads_por_chave.sql:11-18`). A plataforma do curso (ou um Zapier/Make no meio) manda "e-mail da pessoa + nome do evento", e o evento entra em `pessoa_toques` (tipo `outro`, com `chave` = nome do evento). No marco, a regra fica "quando chegar o evento `trabalho_xpto`". Enquanto a integração não existir, o mesmo marco funciona como manual.

### 4.3 Matrícula
- **`alunos` + `jornada_id`** (nulo). Nasce preenchido com a jornada publicada do produto em `processar_venda`, `ativar_contrato` e `cadastrar_cliente_historico`. Preenchimento das matrículas antigas: só quando o cliente publicar a primeira jornada do produto (com botão "levar matrículas ativas para esta versão").
- Nascer na primeira etapa **da jornada do produto** (hoje é a primeira etapa geral). Sem jornada publicada, continua igual.

### 4.4 Sinais e progressão
- **`aluno_marcos`**: `aluno_id`, `marco_id`, `sinal` (observado, declarado, validado), `fonte` (pesquisa, toque, vídeo, compra, manual), `ref_tabela`/`ref_id` (mesmo padrão de `pessoa_toques`), `valor`, `em`, `validado_por`, `validado_em`, `situacao` (atingido, aguardando confirmação, recusado). Marco manual: atingido quando alguém confirma. Automático: atingido quando a regra acontece. Automático com confirmação: fica aguardando até alguém da equipe confirmar.
- **`aluno_historico` + `por_usuario`** (nulo) e incluir `alunos` na lista da `auditoria`.

### 4.5 Check-ins (dentro de Pesquisas)
- `pesquisas` + `jornada_id`/`produto_id` (nulos), gatilho novo **`etapa_aluno`** (etapa do Kanban de alunos) e opção **`recorrente`** (a cada N dias enquanto a matrícula estiver ativa, rodada pelo agendador).
- `pesquisa_envios` + `aluno_id` e `ciclo` (padrão 0). A trava única passa de `(pesquisa_id, pessoa_id)` para `(pesquisa_id, pessoa_id, ciclo)`. **É a mudança de maior risco** (ver §5): todos os `on conflict (pesquisa_id, pessoa_id)` precisam mudar na mesma migration.
- Pergunta com papel novo `marco` (aponta para um `jornada_marcos`): a resposta grava um sinal **declarado** em `aluno_marcos`.

### 4.6 Gatilhos e intervenções
- Regras de CS no mesmo agendador: parado na etapa há mais de X dias, marco obrigatório vencido, check-in sem resposta, NPS ≤ 6, matrícula sem CS. Gravadas em `alertas` com `tipo` novo `cs` e `dados.aluno_id`; aviso ao `responsavel_cs_id` por `equipe_avisa` (já existe). Limites em `alertas_config.regras` (já é jsonb).
- **Intervenções = tabela própria `cs_intervencoes`** (decidido pela Rebecka em 29/10, no lugar de atividade de projeto). Ela não depende de existir projeto do cliente e não mistura acompanhamento com entrega.
  - **Com o que ela se relaciona:**
    - `aluno_id`: a matrícula (pessoa + produto). É a ligação principal; é por ela que a intervenção aparece na ficha, filtrada pelo produto.
    - `alerta_id`: o alerta de CS que pediu a ação (parado na etapa, marco atrasado, check-in sem resposta, NPS baixo). Vazio quando o CS cria na mão.
    - `etapa_kanban_id` e `marco_id`: em que etapa da jornada do produto o aluno estava e qual marco a ação tenta destravar.
    - `pesquisa_resposta_id`: a resposta de check-in que motivou a ação, quando houver.
    - `responsavel_id` → `equipe` (padrão: o `responsavel_cs_id` da matrícula), `tipo` (ligação, mensagem, reunião, conteúdo de apoio, outro), `descricao`, `prazo`, `status` (aberta, feita, cancelada), `criado_por`, `concluida_em`.
    - `resultado` (texto) e `efeito` (resolveu, em andamento, não resolveu): o que aconteceu depois. É isso que deixa medir se as intervenções funcionam.
  - **O que ela reaproveita:** o aviso ao responsável vai pela fila de sempre (`notificacoes`, tipo novo `intervencao`, e-mail e WhatsApp pela edge function `avisos`); ela aparece também em "Minhas atividades" (`vMinhas`), ao lado das atividades de projeto, com um selo "CS". Concluir a intervenção resolve o alerta ligado (`alertas.resolvido_em`). Acesso igual ao de `alunos` (ler em revops, vendas, adm, prj, fin, gro; editar em revops e vendas) e auditoria ligada.

### 4.7 Oportunidades de retenção e expansão
- `oportunidades` + `aluno_id`, `origem` (manual, alerta, rfm, ascensao, marco) e tipos `expansao` e `retencao` na lista de `tipo`. Mesmo Kanban, mesma tela; Customer Growth só filtra.

### 4.8 Indicadores
- Uma função só de leitura (ex.: `cg_indicadores(ws, produto, ini, fim)`) que usa `alunos`, `aluno_historico`, `aluno_marcos`, `pesquisa_*` e, para dinheiro, **chama `revops_receitas`**. Cada indicador novo ganha linha em `metricas_definicoes`.

---

## 5. Riscos

**Duplicação**
1. **LTV com duas regras:** `heavyops_painel` soma só vendas aprovadas (`heavy_ops.sql:69-71`); `revops_receitas` soma vendas e contratos (`revops_retencao.sql:79`). Customer Growth tem que usar `revops_receitas` e não criar a terceira. Vale decidir se o Dashboard de RevOps também passa a usá-la (fora deste escopo).
2. Duas "jornadas" com o mesmo nome: a do funil (pré-compra, `funis`) e a de depois da compra. **Decidido pela Rebecka (29/10):** a de depois da compra se chama **"Jornada do produto"**, porque é no produto que se cadastram as etapas dele. Na tela: "Jornada do funil" (antes da compra) e "Jornada do produto" (depois da compra).
3. "Intervenção" já é palavra do Ciclo de Growth (experimento). Na tela de CS, usar "Ação de CS" ou "Intervenção de CS".
4. "Jornada entre produtos" do simulador (`gpsTabJornada`) é previsão; não confundir com a ascensão real (`revops_ascensao`).

**Regressão**
1. `pesquisa_envios` única: mexer na trava afeta `pesquisa_enfileira`, `pesquisa_gerar_envios`, `pesquisa_enviar_para`, `pesquisa_captar`/`pesquisa_registrar` e a tela. Fazer numa etapa só, com testes de banco antes e depois.
2. Etapas de aluno são usadas por `funil_membros`/`funil_analise` (chave `a:<etapa>`, ordem das etapas), `heavyops_painel` (`r_etapas`) e `pesquisa`. Etapas por produto mudam a "ordem" — as funções têm que comparar ordem **dentro da mesma jornada**.
3. `processar_venda` e `ativar_contrato` são o coração do financeiro; a mudança deve ser só no `insert into alunos` (qual etapa e `jornada_id`), com teste das vendas atuais.
4. `ligaArrastar` só deixa soltar no mesmo quadro; com etapas por produto, precisa impedir soltar um aluno numa etapa de outro produto (checar no banco por gatilho, não só na tela).
5. Produção pode estar atrás das migrations (alertas v0.132 "pendente em produção"). As regras de CS dependem do agendador estar rodando lá.
6. A v0.162 ainda não está na `main`; a Fase B começa depois que ela entrar (decidido em 29/10), para não brigar com `index.html`.
7. Marcos automáticos rodam em gatilhos de vendas, vídeos e pesquisas. Precisam seguir a regra de `toque_trg_*`: nunca bloquear a operação de origem (erro no marco não pode impedir uma venda).

---

## 6. Onde fica cada parte na tela

- **Produto → "Jornada do produto"** (nome decidido em 29/10; é a jornada de depois da compra). Hoje o cadastro de Produtos é uma lista com formulário, sem abas (`index.html:4122`, `vCad`). Proposta: botão **Jornada** em cada linha, que abre a página do produto com as abas *Dados* (formulário de hoje) e *Jornada do produto* (etapas daquele produto, marcos, check-ins ligados, versões, publicar). Não muda o formulário atual.
- **Aluno com mais de um produto.** Cada compra já gera uma matrícula própria em `alunos` (uma por venda ou contrato), cada uma com o seu produto. Então quem comprou dois produtos tem duas jornadas, uma em cada produto, sem nada novo no banco além do §4.
  - **Ficha da pessoa → "Jornada e Evolução"** (a ficha é um modal em seções, `fichaPessoa`): seção nova logo depois de "Responsáveis", com um seletor de produto no topo (um botão por produto comprado, já marcado o mais recente ou o único). Escolhido o produto, aparece a jornada dele: as etapas do produto em linha, com a atual destacada e as já passadas marcadas; os marcos (atingido, declarado, validado, atrasado); check-ins e respostas; ações de CS; e a linha do tempo daquela matrícula (`aluno_historico`). Transformar a ficha em abas fica para depois (mexe em muita coisa).
  - **Kanban de alunos / aba Evolução:** como cada produto tem as suas etapas, o quadro pede um produto escolhido (filtro no topo, lembrando o último usado). As colunas são as etapas daquele produto e cada cartão é uma matrícula, então a mesma pessoa aparece no quadro de cada produto que comprou. Em "Todos os produtos" o quadro vira uma lista agrupada por produto (produto, etapa atual, há quantos dias, CS), porque etapas de produtos diferentes não cabem nas mesmas colunas.
- **RevOps → "Customer Growth"** (tela nova `ho-cg`, módulo `revops`, linha nova em `acesso_telas`), com abas:
  1. *Evolução*: Kanban por produto (o mesmo `quadro()`/`ligaArrastar()` de `vCrmAlunos`, filtrado pela jornada).
  2. *Check-ins*: fila e respostas das pesquisas de jornada (lê Pesquisas).
  3. *Alertas e intervenções*: alertas `tipo = cs` e ações de CS.
  4. *Retenção e expansão*: oportunidades com origem CS + atalhos para RFM e ascensão (`vRetencao`).
  5. *Indicadores*: `cg_indicadores` + números já existentes do Dashboard de RevOps.
  A tela "Alunos" atual continua até a aba Evolução cobrir tudo; depois vira atalho para ela.

---

## 7. Plano em etapas pequenas (cada uma é uma versão, com teste de banco e de tela)

| Etapa | O que entra | Banco | Risco |
|---|---|---|---|
| B1 | Gatilho de pesquisa **por etapa do aluno** (`etapa_aluno`) + correção do texto do modelo "Jornada" | gatilho novo em `aluno_historico`; valor novo no `check` de `gatilho` | baixo |
| B2 | Jornada por produto com versão; Kanban de alunos filtrado por produto; etapas antigas = jornada geral | `jornadas`; `etapas_kanban.jornada_id/produto_id`; `alunos.jornada_id` | médio |
| B3 | Aba Jornada do produto (etapas, publicar versão, botão "continuar ou transferir" alunos, modelos de jornada) | `aluno_historico.tipo` `jornada`; função de transferência | médio |
| B4 | Matrícula nasce na jornada do produto (`processar_venda`, `ativar_contrato`, cliente antigo) | ajuste nas três funções | médio-alto |
| B5 | Marcos + sinais (manual, automático, automático com confirmação); seção "Jornada e Evolução" na ficha; `alunos` na auditoria; `aluno_historico.por_usuario` | `jornada_marcos`, `aluno_marcos`; gatilhos que leem compras, vídeos, pesquisas e eventos | médio |
| B5b | Receber eventos de fora (área de membros, plataforma do curso) para marcos automáticos | escopo `eventos` em `chaves_api`; endpoint na edge function `leads` (ou função irmã) gravando em `pessoa_toques` | médio |
| B6 | Check-in recorrente e ligação resposta → matrícula/marco | `pesquisa_envios.aluno_id/ciclo` + troca da trava única | **alto** |
| B7 | Regras de CS no agendador + aviso ao CS | `growths_verificar_alertas` (ou função irmã); `alertas.tipo` `cs` | médio |
| B8 | Intervenções de CS ligadas à matrícula e ao alerta; aparecem em "Minhas atividades" | `cs_intervencoes`; tipo `intervencao` em `notificacoes` | baixo |
| B9 | Oportunidades de retenção/expansão ligadas à matrícula | `oportunidades.aluno_id/origem`, tipos novos | baixo |
| B10 | Tela Customer Growth em RevOps + `cg_indicadores` + dicionário | `acesso_telas` `ho-cg`; função de leitura; `metricas_definicoes` | baixo |

Cada migration: `add column if not exists` / `create table if not exists`, com o bloco de desfazer comentado no fim (drop das colunas e tabelas novas), RLS por `pertence_ao_workspace` + `perm(..., array['revops','vendas'])` igual a `alunos`, e cenários em `tests/banco` e `tests/tela` (mockdb).

## 8. Decisões da Rebecka (29/10)
1. **Jornada do produto:** cada produto tem a sua, com as próprias etapas e versão. O aluno com mais de um produto é visto por produto (filtro na ficha e no Kanban, §6).
2. **Versão nova:** ao publicar, um botão pergunta se quem já está dentro continua na versão atual ou é transferido para a nova (todos ou alguns, com a etapa equivalente escolhida). §4.1.
3. **Jornada geral:** produto sem jornada própria usa as etapas de hoje. Depois, modelos de jornada (mentoria, curso online…) para criar a de cada produto. §4.1.
4. **Intervenções:** tabela própria `cs_intervencoes`. §4.6.
5. **Marco atingido:** depende do marco: manual, automático ou automático com confirmação. O que vem de fora (plataforma do curso) precisa do endereço de eventos (etapa B5b). §4.2.
6. **Quando e onde:** a Fase B começa depois que a v0.162 entrar na `main`, e a Rebecka quer tudo aplicado assim que der o ok.

### Como fica "aplicar tudo"
- Faço as etapas B1 a B10 em sequência, cada uma com teste de banco e de tela, numa branch própria.
- **Banco de produção:** daqui não tenho acesso. Cada etapa sai com o seu `supabase/RODAR_v0.1xx_*.sql`, na ordem, para rodar no SQL Editor do Supabase (como em `docs/como-rodar-o-banco.md`) ou pelo conector, se for autorizado.
- **Entrada na `main`:** tudo que entra na `main` vai direto para o ar. Junto na `main` só depois do ok final, e o SQL tem que estar rodado antes (ou junto), senão as telas novas mostram "falta a atualização do banco".
