

## v0.145
- index.html: 0.144 → 0.145 (`integra145.py`, que roda o `integra144.py`; novos `g145.js` e `g145.css`). Novo: `20261106100000_content_fontes.sql`, `RODAR_v0.145_content_fontes.sql`; teste `t143_content_setup.py` refeito para 9 passos. Aplicado em produção.

## v0.144
- index.html: 0.143 → 0.144 (`integra144.py`, que roda o `integra143.py`; `g143.js` editado, novos `g144.js` e `g144.css`). Novo: `20261105100000_content_setup_v2.sql`, `RODAR_v0.144_content_setup_v2.sql`; função `content-drive` atualizada; teste `t143_content_setup.py` refeito para 8 passos. Aplicado em produção.

## v0.143
- index.html: 0.142 → 0.143 (`integra143.py`, que roda o `integra141.py`). Novo: `20261104100000_content_setup.sql`, `RODAR_v0.143_content_setup.sql`, função `content-google`, teste `t143_content_setup.py`. Aplicado em produção.


## v0.142
- index.html: 0.141 → 0.142 (mudança no `g141.js`, montado pelo `integra141.py`). Sem migração.


## v0.141
- index.html: 0.140 → 0.141 (`integra141.py`, que roda o `integra140.py`). Novo: `20261103100000_acesso_content.sql`, `RODAR_v0.141_acesso_content.sql`, teste `t141_acesso_content.py`. Aplicado em produção.


## v0.140
- index.html: 0.139 → 0.140 (`integra140.py`, que roda o `integra139.py`).
- Novo: `20261102100000_content_drive.sql`, `RODAR_v0.140_content_drive.sql`, função `content-drive`, `integracoes/apps-script/growths-drive.gs`, teste `t140_content_drive.py`. Aplicado em produção.


## v0.139
- index.html: 0.138 → 0.139 (`integra139.py`, que roda o `integra138.py`). Sem migração. Teste `t134` atualizado.


## v0.138
- index.html: 0.137 → 0.138 (`integra138.py`, que roda o `integra137.py`). Sem migração. Testes `t134` e `t135` atualizados.


## v0.137
- index.html: 0.136 → 0.137 (`integra137.py`, que roda o `integra136.py`). Sem migração. Teste `t134` atualizado.


## v0.136
- index.html: 0.135 → 0.136 (`integra136.py`, que roda o `integra135.py`; substitui `vConteudo`, `tabInsta` e `igModalPost`).
- Novo: `20261101100000_instagram_classificar.sql`, `RODAR_v0.136_instagram_classificar.sql`. Testes `t133`, `t134`, `t135` atualizados. Aplicado em produção.


## v0.135
- index.html: 0.134 → 0.135 (`integra135.py`, que roda o `integra134.py`; substitui `vConteudo`).
- Novo: `20261031100000_instagram_dms_canais.sql`, `RODAR_v0.135_dms_canais.sql`, `supabase/functions/zernio-sync/index.ts` (agora no repositório, com as DMs), cópias de `20261025022737_instagram_dm_crm.sql` e `20261025034245_conexao_zernio.sql`; teste `t135_dms_canais.py`. Aplicado em produção.

## v0.134
- index.html: 0.133 → 0.134 (`integra134.py`, que roda o `integra133.py`).
- Novo: `20261030100000_instagram_dashboard.sql`, `RODAR_v0.134_instagram.sql`; teste `t134_instagram_dashboard.py`. Pendente em produção.

## v0.133
- index.html: 0.132 → 0.133 (`integra133.py`, que roda o `integra132.py` e reescreve as telas do módulo de conteúdo).
- Novo: `20261029100000_maquina_conteudo.sql`, `RODAR_v0.133_maquina_conteudo.sql`, edge function `linha-editorial` (com `logica_test.ts`); teste `t133_maquina_conteudo.py`. Pendente em produção.

## v0.132
- index.html: 0.131 → 0.132.
- Novo: `20261028100000_assistente_alertas.sql`, `RODAR_v0.132_alertas.sql`, `RODAR_v0.132_agendador.sql`, edge function `avisos` (com `logica_test.ts`), `perguntar` alterada; teste `t132_assistente_alertas.py`. Pendente em produção.

## v0.131
- index.html: 0.130 → 0.131.
- Não muda o banco. Novo teste `t131_selo_tags_respondentes.py`.

## v0.130
- index.html: 0.129 → 0.130.
- Novo: `20261027100000_formulario_captacao.sql` e `RODAR_v0.130_formulario.sql` (aplicado em produção em 21/10/2026); teste `t130_formulario_captacao.py`.

## v0.129
- index.html: 0.128 → 0.129.
- Novo: `20261026100000_qualificacao_pontos.sql` e `RODAR_v0.129_qualificacao.sql` (aplicado em produção em 21/10/2026); teste `t129_multi_qualificacao.py`.

## v0.128
- index.html: 0.127 → 0.128.
- Não muda o banco. Novo teste `t128_painel_campanha.py`.

## v0.127
- index.html: 0.126 → 0.127.
- Novo: migração `20261025100000_saldo_minimo.sql` e `RODAR_v0.127_saldo_minimo.sql` (aplicado em produção em 21/10/2026); teste `t127_onda3.py`.

## v0.126
- index.html: 0.125 → 0.126.
- Não muda o banco. Novo teste `t126_onda2_parte2.py`.

## v0.125
- index.html: 0.124 → 0.125.
- Não muda o banco. Novo teste `t125_onda2_parte1.py`.

## v0.124
- index.html: 0.123 → 0.124.
- Não muda o banco. Novo teste `t124_graficos_onda1.py`.

## v0.123
- index.html: 0.122 → 0.123.
- Novo: migração `20261024100000_arvore_serie.sql` e `RODAR_v0.123_arvore_serie.sql` (já aplicado); teste `t123_linha_cadastros.py` (substitui o t122).
