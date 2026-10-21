# Como rodar o banco no Supabase

## Primeira vez

1. Crie uma conta e um projeto em [supabase.com](https://supabase.com). Anote a senha do banco em um gerenciador de senhas (nunca no repositório).
2. No menu lateral, abra o **SQL Editor** e crie uma consulta nova.
3. Abra o arquivo de `supabase/migrations/` (o de nome mais antigo), copie todo o conteúdo, cole no editor e clique em **Run**. Deve terminar sem erro.
4. Faça o mesmo com `supabase/seed.sql`. Isso cria o workspace "Growths — Demo" com 40 leads fictícios da campanha do Google.
5. Crie o seu login em **Authentication → Users → Add user**. Depois, no SQL Editor, rode (trocando o e-mail pelo do login):

   ```sql
   select vincular_usuario(
     (select id from workspaces where nome = 'Growths — Demo'), 'seu@email.com');
   ```

6. Opcional: rode `supabase/exemplos/simular_vendas.sql`. Ele qualifica leads, registra 6 vendas, recebe o que já venceu e faz um reembolso. No fim, mostra uma tabela de conferência (o último item deve ser 0).

## Recomeçar do zero a demonstração

```sql
delete from workspaces where nome = 'Growths — Demo';
```

Depois rode de novo o `seed.sql`.

## Mudanças futuras no banco

Nunca edite um arquivo de `migrations/` que já foi rodado. Para cada mudança, crie um arquivo novo com o nome no formato `AAAAMMDDHHMMSS_descricao.sql` (por exemplo, `20261012100000_adiciona_metas_mensais.sql`), rode-o no SQL Editor e registre no [CHANGELOG](../CHANGELOG.md). Veja [guia-de-versionamento.md](guia-de-versionamento.md).

## Migrações da v0.22 (acessos)
`20261006370000_empresa_funcoes_acessos.sql` já foi aplicada no projeto. `20261006380000_acessos_sincronizacao.sql` está pendente: abra o SQL Editor do Supabase, revise o conteúdo e execute. Em um banco novo, rode as duas em ordem. Depois, em Cadastros → Funções e permissões, use "Criar funções sugeridas" e, em Equipe e acessos, libere cada pessoa.

## Unificar o banco de demonstração (v0.23)
Apague o workspace paralelo (apaga tudo dele em cascata) no SQL Editor:

```sql
delete from workspaces where nome = 'RevOps — Simulação (dados fictícios)';
```

Os dados da escada de produtos já estão no "Growths — Demo". Em um banco novo, depois do `seed.sql`, rode `seed/revops_escada_demo.sql` (roda uma vez) e as migrações `20261006390000` e `20261006400000`.

## Migrações da v0.24
`20261006410000_rateio_custos.sql` e `20261006420000_permissoes_por_acao.sql` já estão aplicadas no projeto. Em banco novo, rode em ordem depois das anteriores. Depois, em Cadastros → Centros de custo, marque quais entram no CAC e crie as regras em Rateio de custos.

## Migrações da v0.25
Em banco novo, rode em ordem `20261006430000_painel_gerencial_no_banco.sql` e `20261006440000_dashboards_no_banco.sql`. Depois use `provisionar_workspace` para criar o workspace da operação.

## Banco por cliente (recomendação, a implantar)
1. **Projeto mestre** (seu): onde nascem e são testadas as migrações. É a única cópia da lógica de negócio com acesso humano.
2. **Um projeto Supabase por cliente**, dentro da sua organização. Cada migração do mestre é aplicada em todos, em ordem e registrada (`list_migrations`), por script/CLI (`supabase db push` por projeto) ou pipeline.
3. O cliente **não recebe acesso ao painel nem backup completo**: o Postgres não esconde o código de funções. Ele acessa só pelo app (login + RLS). Se pedir dados, entregue exportação **somente de dados** (CSV/`COPY` das tabelas), nunca `pg_dump` com funções.
4. Chaves e URL por cliente ficam numa configuração do app (o `index.html` deve apontar para o projeto do cliente).
5. Antes de replicar: testar no mestre, aplicar em um cliente piloto, depois nos demais; manter tabela de versão aplicada por cliente.
Ainda não implantado: precisa decidir custo por projeto (cada um é cobrado) e como o `index.html` escolhe o projeto.

## v0.29 — o que rodar
Já aplicada: `20261006480000_modo_financeiro_custos_cac.sql`. **Rode no SQL Editor do Supabase:** `20261006481000_modo_financeiro_bloqueio.sql` (copie o conteúdo, cole, Run). Depois, em Cadastro da empresa, escolha o modo do cliente.

## v0.30 — rodar
No SQL Editor: `20261006490000_uso_plataforma.sql`. Depois, Configurações → Uso da plataforma.

## Atualização
`20261006481000_modo_financeiro_bloqueio.sql` **não deve ser rodada** (decisão de 06/10/2026: criptografia no lugar). `20261006490000_uso_plataforma.sql` já foi rodada.

## v0.32 — rodar
`20261006500000_fornecedores_provisao_formas_pagamento.sql` e `20261006510000_despesas_recorrentes.sql` já estão aplicadas. No SQL Editor, rode apenas `20261006500100_bloqueia_pagar_estimativa.sql` (trava extra no banco). Depois confira em Cadastros → Fornecedores e Formas de pagamento.

## Workspace Demo 2 e limpeza do Demo (v0.50)
O workspace "Growths — Demo 2" (id e0584ab0-023c-4ff3-8313-83175c1bb2a0) foi criado com `provisionar_workspace` e está vazio. Para limpar o Demo antigo, rode `supabase/manutencao/limpar_demo.sql` no SQL Editor (apaga os dados de teste do Demo, mantém a estrutura, não mexe na Mathisa, não dá para desfazer; a trava dos lançamentos contábeis é desligada só durante a limpeza).

## Plano de contas de cliente novo (v0.51)
Rode `20261007130000_importar_plano_contas.sql` uma vez. Para cada cliente novo, importe o plano antes de cadastrar contas bancárias e contas a pagar, e depois use "Contas do sistema".

## v0.53
Migração `20261007140000_regras_contabeis_personalizadas.sql` (já aplicada no projeto): colunas nome e personalizada em regras_contabilizacao.

## v0.55
Migração `20261007150000_growth_starter.sql` (já aplicada): coluna modo_produto em workspaces e função criar_workspace_starter.

## v0.57
Migração `20261007160000_equipe_interna.sql` (já aplicada): coluna agencia em workspaces, funções sou_equipe_interna e criar_workspace_cliente.

## v0.58
Migração `20261007170000_dashboard_layouts.sql` (já aplicada): tabela dashboard_layouts.

## v0.59
Nenhuma migração nova. O Dashboard de mídia lê a view v_trafego_anuncio_dia.

## v0.60
Migração `20261007180000_ia_perguntas.sql` (já aplicada): tabela ia_perguntas e função ia_contexto.
Função de servidor `perguntar` (pasta supabase/functions/perguntar, já publicada com verify_jwt ligado). Segredos no Supabase (Project Settings → Edge Functions → Secrets): ANTHROPIC_API_KEY e/ou OPENAI_API_KEY. Opcionais: ANTHROPIC_MODEL (padrão claude-sonnet-5-5) e OPENAI_MODEL (padrão gpt-4o). As chaves nunca entram no código nem no front-end.

## v0.62
Nenhuma migração nova.

## v0.63
Migração `20261007190000_campos_personalizados.sql` (já aplicada): tabela `campos_personalizados` e coluna `extras` nas tabelas pessoas, produtos, fornecedores, campanhas e vendas. A tabela `dashboard_layouts` (v0.58) não é mais usada pela tela; pode ficar.

## v0.64
Migração `20261007200000_vendas_dashboard_contratos.sql` (já aplicada): vendas_dashboard passa a incluir contratos fechados.
Migração `20261007210000_growth_modelo_contrato_venda.sql` (já aplicada): growth_modelo_historico conta contrato fechado como venda (quantidade).

## v0.65
Migração `20261008080000_ofertas_e_calculadora.sql` (já aplicada): tabelas ofertas, campanha_ofertas e campanha_calculos, colunas meta_cpl e a função campanha_ofertas_resultado.

- v0.66 a v0.68 (benchmarks, fornecedor, desconto) já foram aplicadas no projeto; os arquivos estão em supabase/migrations para outros ambientes.


## v0.76
Sem migração nova.


## v0.77
Rode `supabase/migrations/20261008220000_estrategias_jornada.sql` no SQL Editor. Ela cria as tabelas, as regras de acesso, os gatilhos da jornada e as funções, e copia o histórico para `pessoa_toques`. Pode rodar mais de uma vez: as políticas são recriadas e a cópia do histórico não duplica. Continuam pendentes `20261006500100_bloqueia_pagar_estimativa.sql` e `20261007130000_importar_plano_contas.sql`.


## v0.78
Sem migração nova.


## v0.79
Sem migração nova.


## v0.80
Rode `supabase/migrations/20261008230000_seguranca_fase1.sql` no SQL Editor (a ferramenta recusou aplicar). Ela substitui `20261006500100_bloqueia_pagar_estimativa.sql`, que não precisa mais ser rodada. É idempotente. Depois, no painel do Supabase: Authentication → ligar a proteção contra senhas vazadas e conferir se o cadastro aberto de usuários ("Allow new users to sign up") está desligado e a confirmação de e-mail ligada. Workspace novo: só por `criar_workspace_cliente` (equipe interna); `provisionar_workspace` deixou de ser chamável direto.


## v0.81
Rode no SQL Editor, nesta ordem, se ainda não rodou: `20261008230000_seguranca_fase1.sql` (v0.80) e `20261010200000_blocos_e_simulador.sql`. A da v0.81 cria `estrategia_blocos`, `campanha_blocos`, as colunas `bloco_id`, `papel` e `fonte` nas etapas, `simulador_cenarios` e `simulador_snapshots`, e atualiza `campanha_aplicar_estrategia` e `campanha_funil_etapas`. É idempotente. A ferramenta recusou aplicar DDL; por isso o arquivo é rodado à mão.


## v0.82
Sem migração nova. Continuam pendentes de rodar, se ainda não rodou: 20261008230000_seguranca_fase1.sql e 20261010200000_blocos_e_simulador.sql.


## v0.83
Rode `20261010220000_desfazer_parcial_junta_saldo.sql` depois de `20261008230000_seguranca_fase1.sql` (usa `pode_editar`). Ordem completa das pendentes: segurança (v0.80), blocos e simulador (v0.81), junção da baixa parcial (v0.83).


## v0.85
Rode `20261010230000_pacotes_acesso.sql` depois de `20261008230000_seguranca_fase1.sql`. Ordem das pendentes: segurança (v0.80), blocos e simulador (v0.81), junção da baixa parcial (v0.83), pacotes de acesso (v0.85).

## v0.86
Rode `20261010240000_cartao_e_receber_avulso.sql` por último. Ordem das pendentes: segurança (v0.80), blocos e simulador (v0.81), junção da baixa parcial (v0.83), pacotes de acesso (v0.85), cartão e a receber avulsa (v0.86). Teste local: Postgres vazio + roles `anon/authenticated/service_role`, depois `tests/banco/contas_pagar_base.sql`, `cartao_base.sql`, `projetos_base.sql`, a migração (duas vezes, é idempotente) e `cartao_cenarios.sql` (avisa "todos os cenários OK").
O workspace "Casa" foi criado direto no banco em 10/10/2026 (`provisionar_workspace('Casa')` + `vincular_usuario` da Rebecka como admin + contas da casa no plano + "Conta da casa"). A migração v0.86 só cria o pacote Casa e o aplica a ele.

## v0.87
Rode `20261010250000_casa_modulo.sql` depois da v0.86. Ordem completa das pendentes: v0.80 segurança, v0.81 blocos e simulador, v0.83 junção da baixa parcial, v0.85 pacotes de acesso, v0.86 cartão e a receber avulsa, v0.87 Casa. A migração liga o workspace "Casa" ao workspace da agência (Mathisa — Operação). Teste local: além das bases da v0.86, rode a migração v0.83, `casa_base.sql`, a migração v0.87 e `casa_cenarios.sql` ("v0.87: casa OK").

## v0.88
Rode `20261011000000_fase1_confianca_dado.sql` depois da v0.87. Ordem completa das pendentes: v0.80, v0.81, v0.83, v0.85, v0.86, v0.87, v0.88. Se houver telefones repetidos no workspace, o índice único de telefone não é criado (a migração avisa): junte os cadastros em Cadastros repetidos e rode de novo. Teste local: bases `contas_pagar_base`, migração v0.83, `cartao_base`, `projetos_base`, `casa_base`, migrações v0.86 e v0.87, `fase1_base`, migração v0.88 (duas vezes) e os cenários `cartao_cenarios`, `casa_cenarios`, `fase1_cenarios`.

## v0.89
Rode `20261011100000_fase2_captacao_vendas.sql` depois da v0.88. Ordem completa das pendentes: v0.80, v0.81, v0.83, v0.85, v0.86, v0.87, v0.88, v0.89. A migração preenche as participações pela jornada existente e atribui todas as vendas aprovadas (leva alguns segundos). Teste local: depois das bases da v0.88, `fase2_base.sql`, a migração v0.89 (duas vezes) e `fase2_cenarios.sql` ("v0.89: fase 2 OK").

## v0.90
Rode `20261011200000_projetos_tags_modelos.sql` depois da v0.89. Ordem completa das pendentes: v0.80, v0.81, v0.83, v0.85, v0.86, v0.87, v0.88, v0.89, v0.90. Teste local: depois das bases da v0.89, `projetos2_base.sql`, a migração v0.90 (duas vezes) e `projetos2_cenarios.sql` ("v0.90: projetos OK").

## v0.91
Rode `20261011300000_projeto_auto_opcional.sql` depois da v0.90. Ordem completa das pendentes: v0.80, v0.81, v0.83, v0.85, v0.86, v0.87, v0.88, v0.89, v0.90, v0.91. Teste local: depois da migração v0.90, a v0.91 (duas vezes) e `projeto_auto_cenarios.sql` ("v0.91: projeto automático opcional OK").

## v0.92 — rodar tudo de uma vez
Em produção, em 11/10/2026, nenhuma migração de v0.80 a v0.91 estava aplicada. Use o arquivo único (hoje `supabase/RODAR_TUDO_v0.80_a_v0.93.sql`, ver v0.93): Supabase → SQL Editor → New query → colar o arquivo inteiro → Run. Ele roda numa transação (erro em qualquer ponto = nada gravado) e pode ser rodado de novo. No fim mostra as contas bancárias: o Cartão de Crédito deve aparecer com `tipo = cartao`. A v0.92 não tem migração própria.

## v0.93
O arquivo único passou a ser `supabase/RODAR_TUDO_v0.80_a_v0.93.sql` (inclui `20261011400000_custo_operacional.sql`, que só cadastra a tela fin-custo no catálogo de acesso). O de v0.80 a v0.91 foi removido; use só o novo. As correções de dados da Mathisa da v0.93 já foram feitas direto no banco (não precisam de script).

## v0.94
O arquivo único passou a ser `supabase/RODAR_TUDO_v0.80_a_v0.94.sql` (inclui `20261011500000_margens_indicadores.sql`); o de v0.93 foi removido. Teste local da migração: banco vazio + `tests/banco/margens_cenarios.sql` ("v0.94: margens no Planejamento OK"). Antes de rodar, a meta de 30% já funciona na tela (o indicador foi criado sem chave e a migração liga a chave).

## v0.95
O arquivo único passou a ser `supabase/RODAR_TUDO_v0.80_a_v0.95.sql` (inclui `20261011600000_cenarios_indicadores.sql`); o de v0.94 foi removido. Teste local: banco vazio + `tests/banco/margens_cenarios.sql` ("v0.94 … OK" e "v0.95: cenários ruim/ótimo OK").

## v0.96
Sem migração. O arquivo único continua `supabase/RODAR_TUDO_v0.80_a_v0.95.sql`. A meta de retirada fica nos cenários do Unit Economics (`simulador_cenarios`, criado pela v0.81); antes de rodar o arquivo, os cenários ficam salvos no navegador (modo local do simulador).

## v0.97
Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.97.sql` (inclui `20261011700000_ofertas_esteira_campanha.sql`). Teste local da migração: banco vazio + `tests/banco/ofertas_base.sql`, a migração duas vezes e `tests/banco/ofertas_cenarios.sql` ("v0.97: ofertas, esteira e campanha híbrida OK").

## v0.98
Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.98.sql` (inclui `20261011800000_growth_model_cenarios.sql`). Teste local: banco vazio + `tests/banco/gm_base.sql`, a migração duas vezes e `tests/banco/gm_cenarios.sql` ("v0.98: cenários do Growth Model OK"). A migração transforma o antigo cenário 'sim' de cada empresa em "Cenário 1" e os cenários do Unit Economics em cenários do Growth Model.

## v0.99
Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.99.sql` (inclui `20261011900000_decisao_kanban.sql`). Teste local: banco vazio + `tests/banco/gm_base.sql`, a migração v0.98, `tests/banco/decisao_base.sql`, a v0.99 duas vezes e `tests/banco/decisao_cenarios.sql` ("v0.99: decisão e Kanban OK").

## v0.100
Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.100.sql` (17 migrações, v0.80 a v0.100). Teste local da v0.100: banco vazio + `tests/banco/gm_base.sql`, v0.98, `decisao_base.sql`, v0.99, `guardrails_base.sql`, a v0.100 duas vezes e `guardrails_cenarios.sql` ("v0.100: guardrails OK").

## v0.100 — correção do arquivo único
Se o SQL Editor mostrar "registrar_recebimento: trecho não encontrado — revisar", use a versão corrigida de `supabase/RODAR_TUDO_v0.80_a_v0.100.sql` (11/10, 12h). A busca de trechos dentro de funções existentes não depende mais de quebras de linha. A tentativa que deu erro não gravou nada (transação).

## v0.101
Sem migração. Em 11/10/2026 o banco de produção já estava com v0.80 a v0.100 aplicadas.

## v0.102
Sem migração. Só muda a tela.

## v0.103
Sem migração. O cenário "para todos os meses" usa a tabela `gm_alavancas` que já existe, com `mes = 1900-01-01`.

## v0.104
Sem migração.

## v0.105 — Retenção & Expansão
1. Supabase → SQL Editor → New query → cole `supabase/RODAR_v0.105_retencao.sql` inteiro → Run. Roda numa transação e pode ser repetido.
2. A última consulta lista, por workspace, os clientes com compra válida e quantos já recompraram. A Mathisa deve mostrar 10 clientes (11 contratos válidos).
3. Enquanto não rodar, a tela mostra "Falta atualizar o banco".
4. O arquivo `RODAR_TUDO_v0.80_a_v0.105.sql` continua disponível para bancos novos.
5. Teste local: banco vazio → `tests/banco/retencao_base.sql` → a migração → `tests/banco/retencao_cenarios.sql` (deve terminar em "TUDO OK").

## v0.106
Sem migração.

## v0.107
Rode `supabase/RODAR_v0.107_cenarios.sql` no SQL Editor (Supabase → SQL Editor → New query → colar → Run). Pode rodar de novo sem problema. A conferência no fim deve listar `gm_cenarios.descarte`, `growth_experimentos.link_doc` e a tela "Cenários".
Sem rodar: a tela Cenários abre e mostra um aviso, mas descartar com motivo e guardar o link da documentação só funcionam depois da migração.

## v0.108
Sem migração. As telas `gro-lucro` (Unit Economics) e `gro-analise` (Análise de funil) continuam no catálogo `acesso_telas` do banco, mas o sistema não as mostra mais no menu nem nos pacotes.

## v0.109
1. Rode `supabase/RODAR_v0.109_ideias_chatgpt.sql` no SQL Editor. A conferência no fim lista a tabela `chaves_api` e as 4 funções.
2. A edge function `ideias` já foi publicada no projeto, sem verificação de JWT. Para publicar de novo: `supabase functions deploy ideias --no-verify-jwt`. Ela não usa segredo; a chave é validada no banco.
3. Endereço que o GPT chama: `https://yngyghlyonybvfvjcmxl.supabase.co/functions/v1/ideias`.

## v0.110
Não precisa rodar nada em produção. As duas migrações novas só copiam para o repositório o que já existe no banco. A partir desta versão, o banco pode ser montado do zero a partir do repositório: veja `tests/auditoria/LEIA.md`.

## v0.111
1. Rode `supabase/RODAR_v0.111_consistencia.sql` no SQL Editor. A conferência no fim lista as 3 colunas novas de `empresa` e a função `dre_resumo`.
2. Depois, em Administrativo → Cadastro da empresa, preencha o regime tributário (e o anexo, se for Simples). Sem isso, as projeções usam MEI.
3. Antes de rodar o arquivo, a v0.111 funciona como a v0.109 nessas telas (regime no navegador, Custos e margens pelas contas a receber).

## v0.112 — Escola Aurora (dados de teste)
1. Rode no SQL Editor, nesta ordem e cada um numa query nova: `RODAR_escola_aurora_1_dados.sql` (65 KB) e depois `_2_imagens`, `_3_imagens` e `_4_imagens`, com as imagens dos criativos. A parte 1 termina mostrando o workspace, 31 anúncios, cerca de R$ 11 mil investidos, cerca de 3 mil leads e partidas D − C = 0. A parte 4 termina com 35 de 35 anúncios com imagem.
2. No Growths, troque para o workspace **Escola Aurora**.
3. Para apagar depois: um `delete` simples do workspace não funciona, porque os contratos ativos bloqueiam a exclusão em cascata (`contrato_itens_antes`). Se precisar, gere um script de remoção. Pendente: apagar workspace de teste.

## v0.113 — Receber leads
1. Banco: `supabase/RODAR_v0.113_leads.sql`. Em produção já foi aplicado em 17/10/2026. Rode antes a v0.109 (Ideias pelo ChatGPT), que criou `chaves_api`.
2. Edge function: `supabase functions deploy leads --no-verify-jwt`. A pasta tem `index.ts` e `campos.ts`. Em produção já está publicada.
3. Segredo opcional `META_ACCESS_TOKEN`: token de página com `leads_retrieval`, só para o webhook nativo da Meta. Configure em Edge Functions → Secrets.
4. Teste local:
   - `deno run --allow-env tests/edge/leads_teste.ts` testa a leitura dos campos;
   - com a função no ar pelo stub (`PGDB=escp`, porta 8788), use `CHAVE=gw_... BASE=http://127.0.0.1:8788` (ver `tests/edge/LEIA.md`);
   - para a tela: `tests/auditoria/t113_leads.py`, com o banco `fa` e o PostgREST.

## v0.114 — Meta de leads
1. Banco: `supabase/RODAR_v0.114_meta_leads.sql`. Em produção já foi aplicado em 19/10/2026. Sem ele, o Dashboard da campanha mostra um aviso no lugar do ritmo da meta, e o resto funciona.
2. Teste local: `tests/auditoria/t114_meta_leads.py`, com 21 verificações. Usa o banco `escp` (Escola Aurora) e o PostgREST da porta 3301 (`tests/auditoria/pgrst_escola.conf`).

## v0.115 — Detalhe da campanha
1. Banco: `supabase/RODAR_v0.115_detalhe_campanha.sql`. Em produção já foi aplicado em 19/10/2026. Sem ele, clicar no card avisa que falta essa atualização.
2. Teste local: `tests/auditoria/t115_detalhe.py`, com 18 verificações. Usa o banco `escp` e o PostgREST da porta 3301.

## v0.116 — Árvore dos números
1. Banco: `supabase/RODAR_v0.116_arvore_numeros.sql`. Em produção já foi aplicado em 20/10/2026. Sem ele, o painel avisa que falta essa atualização.
2. Teste local: `tests/auditoria/t116_arvore.py`, com 80 verificações. Usa os bancos `fa` (PostgREST 3300) e `escp` (PostgREST 3301).

## v0.120 — Comissões e conexões
1. Banco: rode `supabase/RODAR_v0.120_comissoes_conexoes.sql` no SQL Editor, depois do da v0.119. Pode rodar de novo.
2. Publique a edge function `conexoes` (pasta `supabase/functions/conexoes`, com os arquivos index.ts, rotas.ts, util.ts, meta.ts e google.ts) **sem verificação de JWT**:
   `supabase functions deploy conexoes --no-verify-jwt`
3. Cadastre os segredos e o agendamento diário: `docs/conectar-meta-e-google.md`, itens 4 e 5.
4. Testes locais:
   - `psql -d fa -f tests/auditoria/t120_comissoes_banco.sql` (roda numa transação e desfaz);
   - `PGDB=fa deno run --allow-all --import-map=tests/edge/import_map_papeis.json tests/edge/conexoes_teste.ts` (29 verificações);
   - `tests/auditoria/t120_comissoes_conexoes.py` (33 verificações, PostgREST 3300).

## v0.119 — Árvore, parte 4
1. Banco: `supabase/RODAR_v0.119_arvore_numeros_4.sql`, depois do da v0.118. Em produção já foi aplicado em 20/10/2026. Pode rodar de novo.
2. Teste local: `tests/auditoria/t119_arvore4.py` (27 verificações, banco `fa`, PostgREST 3300).
3. Os RODAR v0.118 e v0.119 podem ser colados de novo no editor do Supabase sem problema: se a troca já foi feita, o script pula. Se aparecer "Trecho não encontrado em …", a função foi mudada por fora desde a versão anterior. Nesse caso, não force: confira qual versão da função está no banco.

## v0.118 — Árvore, parte 3
1. Banco: `supabase/RODAR_v0.118_arvore_numeros_3.sql`, depois do da v0.117. Em produção já foi aplicado em 20/10/2026. Pode rodar de novo: cada troca de trecho confere se já foi feita.
2. Teste local: `tests/auditoria/t118_arvore3.py` (44 verificações, banco `fa`, PostgREST 3300).

## v0.117 — Árvore, parte 2
1. Banco: `supabase/RODAR_v0.117_arvore_numeros_2.sql`, depois do da v0.116. Em produção já foi aplicado em 20/10/2026.
2. Teste local: `tests/auditoria/t117_arvore2.py` (54 verificações, banco `fa`).

## v0.121 — Árvore: vendedor
1. Rode `supabase/RODAR_v0.121_arvore_vendedor.sql` no SQL Editor, depois do da v0.120. Pode rodar de novo.
2. A tela (`index.html` 0.121) funciona com ou sem esse script; sem ele, "Por vendedor" continua mostrando "Sem vendedor".
