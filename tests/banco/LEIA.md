# Teste da junção de baixa parcial (v0.83)

Roda num Postgres local vazio, sem tocar no banco de produção:

1. Crie um banco vazio e as roles `anon`, `authenticated`, `service_role`.
2. `contas_pagar_base.sql`: tabelas mínimas, as funções contábeis de produção e a baixa parcial antiga.
3. Crie uma conta de 10.000, faça `registrar_pagamento_parcial(conta, 700, ...)`.
4. Rode `supabase/migrations/20261010220000_desfazer_parcial_junta_saldo.sql` (liga o saldo antigo pela regra de migração).
5. `desfazer_pagamento(conta, ...)` e confira com `contas_pagar_saldos.sql`: uma conta de 10.000 em aberto; 6.2.04 = 10.000 em outubro; 2.1.03 = 10.000 a pagar; banco 0.

Cenários conferidos em 10/10/2026: saldo já pago (não junta), duas baixas parciais em cadeia desfeitas de trás para frente (vira 9.300 e depois 10.000) e pagamento da conta juntada.

## v0.107 — ciclo de vida dos cenários
Sobre um banco com as migrações até a v0.105 (Growth Model, decisão e Kanban, guardrails), rode `supabase/migrations/20261012200000_cenarios_ciclo.sql` duas vezes (idempotente), depois `decisao_cenarios.sql` e `cenarios_ciclo.sql`. Deve terminar com "cenarios_ciclo: tudo OK".
Confere: descartar com motivo e reabrir; descarte que não é objeto é recusado; cenário aprovado não é descartado nem excluído; link da documentação sem http é recusado.

## v0.109 — ideias pelo ChatGPT
Sobre um banco com `workspaces`: rode `ideias_base.sql` (papéis anon/authenticated, stubs de `auth.uid()` e `perm()` controlados por `t.uid`/`t.perm`, tabela `equipe` mínima e dois workspaces), depois `supabase/migrations/20261006200000_conteudo.sql`, `20261012300000_ideias_chatgpt.sql` (2x) e `ideias_cenarios.sql`. Deve terminar com "ideias_cenarios: tudo OK" e "ideias_cenarios (anon): tudo OK".
Confere:
- gerar chave exige login e permissão;
- só o hash fica no banco;
- formato, tema e canais são normalizados e o tema de outro workspace é ignorado;
- título é obrigatório;
- o contexto devolve os temas e as últimas ideias;
- os usos são contados;
- chave errada ou revogada é recusada;
- anon não chama as funções internas.
A edge function foi testada contra este banco com um stub do supabase-js (rpc via psql): GET contexto, POST de uma e de várias ideias, sem título (400), sem chave e com chave errada (401).

## v0.163 — Customer Growth (PGlite)
Sem Postgres instalado, dá para rodar tudo num Postgres em memória (PGlite):
1. Numa pasta fora do repositório: `npm init -y` e `npm i @electric-sql/pglite@0.2.17`; copie `tests/banco/pglite_run.mjs` para lá.
2. `node pglite_run.mjs <pasta do repositório> <arquivos extras...>` cria os papéis e o `auth` do Supabase de mentira, aplica todas as migrações em ordem
   (as de Conteúdo/Instagram que precisam de pg_cron/pg_net falham e não importam aqui) e depois roda os extras.
   Com `ATE=20261116` aplica só até a v0.162 (para testar o `RODAR_v0.163_customer_growth.sql`).
3. Extras, na ordem: `jornada_b1_cenarios.sql`, `jornada_b2_cenarios.sql`, `jornada_b3_cenarios.sql`, `jornada_b5_cenarios.sql`, `jornada_b6_b9_cenarios.sql`, `jornada_b10_cenarios.sql`.
   Cada um termina com "jornada_bN: tudo OK". Conferido em 29/10/2026 com as migrações e com o RODAR aplicado duas vezes sobre um banco da v0.162.

## v0.165 — Strategy Canvas (PGlite)
Mesmo jeito da v0.163: `node pglite_run.mjs <pasta do repositório> canvas_s1_s3_cenarios.sql`. Termina com "canvas_s1_s3: tudo OK" (biblioteca, conexões com ramificação, versões imutáveis, cópia para a campanha sem misturar versões). Conferido em 29/10/2026, junto com `jornada_b2_cenarios.sql`.

## v0.173 — CPF/CNPJ na pessoa (PGlite)
`node pglite_run.mjs <pasta do repositório> pessoa_documento_cenarios.sql`. Termina com "pessoa_documento: tudo OK" (validação, só dígitos, único por workspace, mesclagem levando o documento e recusando documentos diferentes, mesclagem sem tags). Conferido em 30/10/2026.

## v0.174 — Oportunidade e contrato (PGlite)
`node pglite_run.mjs <pasta do repositório> oportunidade_contrato_cenarios.sql`. Termina com "oportunidade_contrato: tudo OK" (dois contratos por oportunidade, contrato de outra pessoa recusado, ativar ganha a oportunidade, negócio do lead ganho/perdido/aberto, expansão não mexe no lead). Conferido em 30/10/2026.

## v0.176 — Diagnóstico 360° G1 (PGlite)
`node pglite_run.mjs <pasta do repositório> diagnostico_g1_cenarios.sql`. Termina com "diagnostico_g1: tudo OK" (catálogo por etapa, link de 30 dias, público com condição, configuração e catálogo, condicional escondida não cobrada, condicional visível cobrada, métrica inválida recusada, resposta grande, link vencido). Conferido em 30/10/2026.

## v0.177 — Diagnóstico 360° G1b, G2 e G3 (PGlite)
- `node pglite_run.mjs <pasta do repositório> diagnostico_g1b_cenarios.sql`: termina com "diagnostico_g1b: tudo OK". Testa a natureza das métricas e o rascunho (salvar, voltar, formato, tamanho, depois de responder, link vencido, fora do diagnóstico).
- `diagnostico_g2_cenarios.sql`: termina com "diagnostico_g2: tudo OK". Testa:
  - autorizar, confirmar e listar;
  - nome limpo;
  - recusa de tipo, tamanho, grupo e link falso;
  - limite de 40 e limpeza dos pendentes antigos;
  - remover só do próprio link;
  - depois de responder e vencido;
  - só no diagnóstico;
  - permissões de anon e authenticated.

  O Storage não existe no PGlite: o envio de verdade é conferido no Supabase.
- `diagnostico_g3_cenarios.sql`: termina com "diagnostico_g3: tudo OK". Testa:
  - dados vindos da resposta;
  - um diagnóstico por resposta;
  - empresa coerente;
  - validar e voltar a rascunho;
  - upsert da métrica;
  - leitura;
  - cascata;
  - políticas.

Conferido em 30/10/2026.
