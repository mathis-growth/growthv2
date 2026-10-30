## v0.173
- Migração `20261126100000_pessoa_documento.sql`: `documento_normaliza`, `documento_valido`, `pessoas.documento` (dígitos, check, índice único por workspace), gatilho `pessoas_documento_t`; `_pessoas_mesclar_v088` atualizada por troca de texto (documento e correção das tags vazias), com erro se o trecho não for encontrado.
- index.html: 0.172 → 0.173. `docDig`, `docTipo`, `docFmt`, `docValido`; campo em `modalCliente` (com `temColuna`); CPF/CNPJ em `fichaPessoa` e na busca de `vClientes`; linha do tempo única em `fichaPessoa` (eventos com categoria e filtro `.tlf`). Teste `t173_pessoa_documento_linha_tempo.py`; `mockdb.js` liga `etapas_kanban` e `jornada_marcos`.

## v0.172
- index.html: 0.171 → 0.172. `vEstrategia`: aba `resumo` (padrão para estratégia publicada; rascunho abre em `mapa`), `cvResumoHtml(f, BL, L, CN, pr, vs)`, botão `#estCamp` → `formCampanha(null, { funil_id, modelo, abrir: true })`. `formCampanha`: `pre.funil_id` vira o padrão do campo Estratégia e `pre.abrir` abre a campanha criada. Teste `t172_estrategia_resumo_campanha.py`. Sem migração.

## v0.171
- Migração `20261125100000_estrategia_publicar_definer.sql`: `estrategia_publicar` com `security definer` (antes dava 403 "permission denied for function pode_operar" para authenticated) e `funis.criado_em` com padrão `now()`.
- index.html: 0.170 → 0.171. Card com `.cv-fzb[data-fz]` e menu `.cv-fzm` (`mudaFase` atualiza o bloco e as etapas); `drop` dentro de `[data-banda]` passa a fase para `cvCriaBloco`, que agora respeita a fase também nos blocos com métricas; tipo simples `passagem` (Passagem para o CS, retenção); selects de fase do Canvas com os nomes de `CV_FASE`. Teste `t171_canvas_fase_no_card.py`.

## v0.170
- index.html: 0.169 → 0.170. `vFunis`: botão `#estMapa` cria `funis` com `status = 'rascunho'`, `tipo = 'outro'` e nome `CV_RASC` e abre o mapa; `#estNova` vira "Nova a partir de modelo". `vEstrategia`: aviso `.cv-rasc`, pill de rascunho, voltar apaga rascunho vazio sem nome e sem campanha. `cvPublicar(f, { pr, nBlocos })`: no rascunho pede nome, tipo, categoria, produto e objetivo, grava e chama `estrategia_publicar`. Teste `t170_canvas_criar_no_mapa.py`. Sem migração.

## v0.169
- index.html: 0.168 → 0.169. No `cvMapa`: botão `.cv-lx[data-lx]` no cabeçalho do card (fora do arrastar), exclui etapas e bloco (as ligações saem pelo `on delete cascade`) e guarda `S.cvDesfaz` (bloco, etapas, ligações, prazo de 8 s); aviso `#cvDesf` no topo do palco com `#cvDesfBt`, que insere de volta com os mesmos ids. Teste `t169_canvas_lixeira.py`. Sem migração.

## v0.168
- index.html: 0.167 → 0.168. `#wsSel` limpa `S.estSel`, `S.cvSel` e `S.cvView`; `vEstrategia` volta para a lista se `funis.workspace_id <> S.ws`. Novos `CV_FASE` e `cvFase`; no `cvMapa`: `data-fase` e `--fc` no card, faixas `#cvBandas` (refeitas ao mover ou mudar o tamanho), legenda `.cv-legs` com `S.cvFase` e `foco()`. "Ajustar" deixa espaço para a barra e as faixas. Teste `t168_canvas_fases.py`. Sem migração.

## v0.167
- index.html: 0.166 → 0.167. Novas `cvTam`, `cvOrganiza`, `CV_GRADE` (20 px). No `cvMapa`: arrastar o card inteiro (`.cv-mov`, limiar de 4 px antes de contar como arrastar; Alt sem grade), canto `[data-rs]` muda `props.tam` (0,6 a 2, `transform: scale` com origem no canto de cima), setas e "Ajustar" usam o tamanho, botão `#cvOrg`, fundo do palco acompanha zoom e posição, e o palco volta a `scrollLeft/scrollTop = 0` se o navegador o rolar. Teste `t167_canvas_ajuste.py`. Sem migração.

## v0.166
- index.html: 0.165 → 0.166. Novas `cvArte`, `cvTipoArte`, `cvLogoDe`, `CV_LOGO`, `CV_PICT`, `cvIcoPal`, `cvFotoReduz`, `cvTrocaTipo`; `blkEtapasDe` sai de dentro de `blkCria` (mesmas métricas, agora reaproveitadas na troca API ⇄ grupo). Bloco mais alto: ligações saem a 62 px do topo, organização por fase a cada 200 px. Paleta com um WhatsApp só. Teste `t166_canvas_desenhos.py`. Sem migração.

## v0.165
- index.html: 0.164 → 0.165. Novas `cvMapa`, `cvCriaBloco`, `cvPos`, `cvPublicar`, `cvVersoes`, `cvCopiaMapa`, `CV_GRUPOS`, `CV_CON`, `CV_CSS`; rota e item de menu `mkt-estrategias` (usa `vFunis`; liberada para quem vê `mkt-camp` ou `cad-funis`); `vFunis` com categoria, versão, filtros e duplicar; `estNova` com categoria e objetivo; `vEstrategia` com Mapa/Lista (`S.estVista`), Publicar versão, Versões e versão em "Campanhas que usam". Sem as colunas novas no banco, a tela fica como na v0.164.
- Migração `20261124100000_strategy_canvas.sql` (idempotente; desfazer no fim do arquivo). Teste `t165_strategy_canvas.py`; banco `canvas_s1_s3_cenarios.sql`.

## v0.164
- index.html: 0.163 → 0.164. Novo bloco `<style id="v164">`; novas `vCockpit`, `ckPeriodo`, `CK_PER`; menu com o grupo `Cockpit` (`livre`, aparece para todos), rota `cockpit`, `PAC_SEMPRE` com `cockpit`, tela inicial `cockpit` (era `adm-painel`). Teste `t164_cockpit.py`. Sem migração.

## v0.163
- index.html: 0.162 → 0.163 (editado direto, sem script de integração). Novas: `vCustomerGrowth` (+ `cgCheckins`, `cgAlertas`, `cgRetencao`, `cgIndicadores`, `modalIntervencao`), `vJornadaProduto`, `modalPublicarJornada`, `modalTransferirJornada`, `jornadasProdutos`, `marcosHtml`, `modalMarco`, `modalReceberEventos`, `fichaJornada`; trocada: `vCrmAlunos` (seletor de jornada); ajustadas: `gerirEtapas`, `modalPesquisa`, `modalOport`, `vMinhas`, `vCad`, `fichaPessoa`, menu, rotas e `telaLiberada`. Novas migrações `20261116100000` a `20261122100000` e `RODAR_v0.163_customer_growth.sql`. Testes de banco `jornada_b*_cenarios.sql` (PGlite, ver `tests/banco/LEIA.md`) e de tela `t163_*.py`.



## v0.162
- index.html: 0.161 → 0.162. Novo bloco `<style id="v162">` (fim do `<head>`) e a função `no` de `vGrowthModeloCorpo` (aba `mapa`) com `TIPO_G`, o grupo `ul.alav` e o título `.gn-lab`. Teste novo `tests/tela/t162_growth_model_nsm.py` (banco de mentira `mockdb.js`). Sem migração.

## v0.161
- index.html: 0.160 → 0.161 (`integra161.py`, que roda o `integra160.py`; novo `g161.js`): `PQ_MODELOS.must_servico`, `pqLeituraPmf` no lugar do quadro de PMF dos Resultados. Teste novo `t161_must_have.py`.

## v0.160
- index.html: 0.159 → 0.160 (`integra160.py`, que roda o `integra159.py`; novos `g160.js` e `g160.css`). Abas `linhas` e `kanban` viram principais (`tabLinhas160`, `tabProducao160`); `modalAprovaIdeia`, `modalSubtemas`, `mqOptSub`, `mqLigaSub`; `dadosConteudo` separa `subtemas`; cartão simples com subtema e formato. Novo: `20261115100000_content_segmentos.sql`, `RODAR_v0.160_content_segmentos.sql`; `t159_content_simples.py` atualizado para o fluxo novo (46 verificações).

## v0.159
- index.html: 0.158 → 0.159 (`integra159.py`, que roda o `integra158.py`; novos `g159.js` e `g159.css`). `MQ_EST` com as 5 abas novas; `vConteudo` sem a trava da configuração; abas `tabBase`, `tabIdentidade`, `tabIdeias`, `tabProducao` (+ `ctPeca`), `tabMais`. Novo: `20261114100000_content_simples.sql`, `RODAR_v0.159_content_simples.sql`; teste `t159_content_simples.py`.

## v0.158
- index.html: 0.157 → 0.158 (`integra158.py`, que roda o `integra157.py`; novos `g158.js` e `g158.css`; `gradeLiga` no `render`; `gcCascata` e `linhas` ganham a largura de desenho). Teste novo `t158_grade.py`. Backup antes da mudança: branches `backup-v0.157` e `backup-v0.156`.

## v0.157
- index.html: 0.156 → 0.157 (`integra157.py`, que roda o `integra156.py`; novos `g157.js` e `g157.css`). Funções trocadas: `gcCascata`, `finCascata`, `finSaldoMin`, `finContexto`; novas: `narrCarrega`, `narr`, `finPonte`, `vMetricas157`. Novo: `20261113100000_narrativa_modelos.sql`, `RODAR_v0.157_narrativas.sql` (gerados por `gera_mig157.py` a partir de `nar_modelos.py`); teste `t157_narrativas.py`; `t127` ajustado aos textos novos do saldo mínimo. Banco ainda não aplicado em produção.

## v0.152 a v0.156
- index.html: 0.151 → 0.156 (`integra152.py` a `integra156.py`, encadeados; novos `g152.js` a `g156.js` e `g152.css` a `g156.css`). Funções antigas trocadas por novas: `painelHero`, `saldoHero`, `compactaKpis` (0.152), `marcaSinais`, `varMes`, `kpiD`, `dgDeltaG` (0.153), `linhas` (0.154). Novo: `20261112100000_metricas_semantica.sql`, `RODAR_v0.156_metricas_semantica.sql`; testes `t152_semantica.py`, `t153_cores_globais.py`, `t154_graficos.py`, `t155_modulos.py`, `t156_alertas_dicionario.py`. Banco aplicado em produção em 26/10/2026.

## v0.151
- index.html: 0.150 → 0.151 (`integra151.py`, que roda o `integra150.py`; novos `g151.js` e `g151.css`; passos 5 e 6 com `csPesquisa` e `csDossie`; `mdHtml`). Novo: `20261111100000_content_pesquisa.sql`, `RODAR_v0.151_content_pesquisa.sql`, função `content-pesquisa` (index.ts, logica.ts, logica_test.ts), Apps Script com a ação `ler`; testes `t151_pesquisa_dossie.py` e `tests/edge/pesquisa/teste_pesquisa.ts`; `t143` ajustado. Aplicado em produção (ficou na branch `v0.151-pendente` até o banco ser aplicado).

## v0.150
- index.html: 0.149 → 0.150 (`integra150.py`, que roda o `integra149.py`; novos `g150.js` e `g150.css`; `dadosConteudo` lê `content_produtos`; aba Produtos usa `tabProdutos2`; `PERSONA_P` e `PERSONA_BLOCOS` ganham o bloco Produtos). Novo: `20261110100000_content_produtos_v2.sql`, `RODAR_v0.150_content_produtos_v2.sql`, teste `t150_produtos_simples.py` (substitui o `t149`); `t143` com as respostas novas. Aplicado em produção.

## v0.149
- index.html: 0.148 → 0.149 (`integra149.py`, que roda o `integra148.py`; novos `g149.js` e `g149.css`; `dadosConteudo` traz produtos e fichas; `modalConteudo` com o campo Produto; aba `produtos`). Novo: `20261109100000_content_produtos.sql`, `RODAR_v0.149_content_produtos.sql`, teste `t149_produtos_conteudo.py`. Aplicado em produção.

## Regra permanente: o documento "Growths: o sistema, explicado"
- `docs/growths-o-sistema.md` explica todas as funcionalidades do Growths (sem tabelas), para a Rebecka subir no Growth's Content e usar como base de conteúdo.
- **A cada entrega**, atualizar este documento: a data e a versão no topo, a seção da área que mudou, o histórico resumido (seção 14) e, quando fizer sentido, um ângulo novo na seção 13.
- Entregar junto com os outros docs, também em .docx (abre como Google Docs no Drive).

## v0.148
- index.html: 0.147 → 0.148 (`integra148.py`, que roda o `integra147.py`; novos `g148.js` e `g148.css`; o topo do `tabKanban` passa a usar `kbPainel` e `kbLiga`). Teste novo: `t148_painel_kanban.py`. Sem migração.

## v0.147
- index.html: 0.146 → 0.147 (`integra147.py`, que roda o `integra146.py`; novos `g147.js` e `g147.css`; `csDrive2` no lugar do `csDrive`, `CS_MAT` sem "links", tela `cfg-pastas`). Novo: `20261108100000_content_pastas.sql`, `RODAR_v0.147_content_pastas.sql`, teste `t147_pastas.py`; `t143` ajustado. Aplicado em produção.

## v0.146
- index.html: 0.145 → 0.146 (`integra146.py`, que roda o `integra145.py`; novos `g146.js` e `g146.css`; menu, `TELAS_INT`, `S.verCustos`, aba Estruturas). Novo: `20261107100000_content_estruturas.sql`, `RODAR_v0.146_content_estruturas.sql`, teste `t146_estruturas_custos.py`. Aplicado em produção (pelo SQL Editor). Ficou numa branch separada (`v0.146-pendente`) até o banco ser aplicado, para a tela não ir ao ar antes.

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
