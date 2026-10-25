

## Pasta do cliente no Drive (v0.140)
- Migração `20261102100000_content_drive.sql` (aplicada em produção em 25/10/2026) + valores em `sistema_config`.
- Função `supabase/functions/content-drive` (index.ts, logica.ts, logica_test.ts), publicada sem verificação de JWT: aceita a senha do banco (`x-growths-token`) ou alguém da equipe interna logado; ação `teste` confere a ligação.
- Apps Script `integracoes/apps-script/growths-drive.gs` (publicado na conta da Rebecka como App da Web): `criar_cliente` e `teste`, com trava contra pedidos simultâneos.
- `g140.js`: `cdPainel` (quadro em Pacotes de acesso), `cdPillModulo` (link no topo do módulo), opção no "Novo cliente"; `integra140.py` renomeia o módulo para Growth's Content.
- Teste `t140_content_drive.py`; `t133` e `t135` com o nome novo.


## Insights e melhores dias (v0.139)
- `g139.js`: `igInsights(P, R, DM)` (regras acima; cada item `{cls: fato|hip|rec, tit, txt, rec, ids}`), `igPalavras` (palavras da legenda, `IG_STOP`), `igMontaInsights` (cartões; "Ver os posts" filtra a galeria por `ids`), `igLinhaCat` (linha por categoria), `igDiasCats`, `igHorasCats`, `igMontaDias`, `igDMs` (conversas novas do período). `igFiltra` aceita filtro por lista de posts.
- `integra139.py` (roda o `integra138.py`): blocos `#igIns` (antes da galeria) e `#igDias` (depois dela); os insights esperam as DMs.
- Validado também com os dados reais da conta (somente leitura, 90 dias). Teste `t134` ganhou insights e linhas.


## Cores pela média, quadros e menu em níveis (v0.138)
- `g138.js`: `IG_FAIXA` (baixo/media/alto), `igDifTxt`, `igLegendaFaixas`; `igGrafico` e `igBarrasH` redefinidos com a classe da faixa e a diferença para a média. `g137.js`: cada gráfico vira `<section class="ig-gc">` com contorno e número de grupos; legenda no topo.
- `integra138.py` (roda o `integra137.py`): `desenhaNav` envolve o conteúdo de cada grupo aberto num `<div class="lv2">` recuado; subgrupos (`.sublist`) recuam mais um nível. No celular, cada linha do gráfico empilha nome em cima e barra embaixo.
- Testes: `t134` (cores, legenda, quadros) e `t135` (menu em níveis).


## Galeria e gráficos de tema e formato (v0.137)
- `g137.js`: `igMontaGaleria` (cartões com imagem, ordem `IG_GORD`, "Mostrar mais" de 8 em 8, filtro vindo do gráfico) e `igMontaGraf` (`igGrafico` por frente, formato e tipo, `igGrupoVal` com média/total/quantidade, barras clicáveis). Cada bloco se redesenha sozinho, sem recarregar os dados. Ícones SVG em `IG_IC`.
- `integra137.py` (roda o `integra136.py`): coloca `#igGal` e `#igGraf` depois dos números dos posts e chama os dois no fim de `tabInsta`; trocar o período zera o filtro.
- Teste `t134_instagram_dashboard.py` ganhou galeria, ordenação, gráficos e filtro pela barra.


## Instagram como submenu; dashboard de canais (v0.136)
- `g136.js`: `vConteudo` novo, com a parte decidida pela rota (`mkt-cont` = Estratégia, `mkt-insta` = Instagram; `MQ_VIEW_CANAL`/`MQ_CANAL_VIEW`), abas da estratégia em `MQ_EST` (Dashboard primeiro) e do canal em `MQ_CANAL`; `mqIrCanal` abre o canal e o menu. `tabDashCanais` (eficiência por canal e melhores posts). `igConexao`/`igFonteHtml` (conta conectada, última atualização ou em qual cliente ela está). `tabInsta` sem importação: seção A conta (seguidores, novos seguidores, alcance, visitas) e Os posts, top 1, gráficos, agrupamentos e lista com "classificar". `igModalPost` salva frente e formato no post.
- `integra136.py`: corta o `vConteudo`, o `tabInsta` e o `igModalPost` antigos; menu com `subs` "Máquina de Conteúdo"; ícone novo.
- Testes atualizados: `t133`, `t134` (sem importação, classificação do post, dashboard de canais) e `t135`.


## Estratégia e canais; DMs (v0.135)
- `g135.js`: `vConteudo` novo com `C.sec` ('estrategia' ou o canal) e subabas; abas antigas 'insta', 'dms' e 'rel' são levadas para a parte do canal. `tabCanais` (canais em uso, por frente, por etiqueta, aplicar sugeridos), `mqCanaisAuto` no cartão novo, `tabDMs` + `dmConversa` (chat) e `vDMsCrm` (Vendas → DMs do Instagram). As ideias do canal usam o Kanban com o canal fixo.
- `zernio-sync`: nova etapa `dms` (Inbox API do Zernio: `/inbox/conversations` e `/inbox/conversations/{id}/messages`), escolhida por `partes`.
- Teste `t135_dms_canais.py`.

## Dashboard do Instagram (v0.134)
- `g134.js`: `tabInsta` (aba 'insta' da Máquina; rota `mkt-insta`), gráficos SVG próprios de uma série e um eixo cada (`igBarrasDia`, `igLinhaDia`), barras horizontais com a média geral marcada (`igBarrasH`), `igModalPost` (post contra a média do período, posição e ligação), importação com leitor de CSV com aspas e quebra de linha (`igCsv`), mapeamento de colunas em português e inglês (`IG_COLS`/`igMapeia`), data dia/mês ou mês/dia (`igData`) e prévia.
- Testes: `t134_instagram_dashboard.py` (banco e telas).

## Máquina de Conteúdo (v0.133)
- `integra133.py` corta as versões antigas de `dadosConteudo`, `vConteudo`, `modalConteudo`, Kanban, Priorização, Plano e Linhas e injeta `g133.js` (antes de `const PQ_TOKEN`) e `g133.css`. Relatórios, métricas e importações ficaram como estavam (ganharam agrupamento por território, formato da Máquina e destino).
- Abas: Kanban, Priorização (`tabPrior` / `tabPriorNotas` no método antigo), Máquina (`tabMaquina`, matriz território × formato), Semana (`tabPlano`, dias com arrastar e soltar; metas por tipo de mídia num bloco recolhível), Fechamento (`tabFechamento`, RPC `conteudo_semana` e `conteudo_fechar_semana`), Relatórios, Persona (`tabPersona`), Linha editorial (`tabLinhas`, núcleo, método, territórios, camadas, formatos, quadros).
- Cartão (`modalConteudo`) no score V18: seções Pauta, Encontrabilidade, Radar e evidência, Score (6 × 1 a 5, total ao vivo, VALIDAR), Roteiro (estrutura com passos), Produção e publicação, Depois de publicar.
- Edge function `linha-editorial`: lê o questionário pelo cliente da pessoa logada (RLS), manda as respostas + o modelo V18 como exemplo, valida a resposta (`validaProposta`) e grava em `conteudo_linha_propostas`. Limite de 6 propostas por hora por cliente. A tela tem a mesma validação para a resposta colada (`mqValidaProposta`).
- Testes: `t133_maquina_conteudo.py` (banco e telas, 70+ conferências) e `deno test supabase/functions/linha-editorial`.

## "Como foi o meu dia?" e alertas (v0.132)
- Tela `ia-perguntar` → `vPerguntar` reescrita (a antiga saiu no `integra132.py`): botões de dia e `diaDaPergunta(texto)` reconhecem ontem/hoje/anteontem/dd/mm e mostram `cardFatos(f)` (de `growths_fatos_dia`); com chave de IA, a pergunta também vai para `perguntar`.
- Tela nova `ia-alertas` → `vAlertas`: alertas (`alertas`), configuração (`alertas_config`), canais por pessoa (`equipe.avisar_*`), status dos canais (`avisos` → `{acao:'status'}`), teste (`growths_aviso_teste` + `avisos` → `{acao:'enviar'}`), envios recentes (`notificacoes`).
- Edge function `avisos`: autentica pelo `x-growths-token` (agendador) ou login; reserva cada notificação antes de enviar (não manda duas vezes); expira fila com mais de 3 dias; `logica.ts` monta e-mail (Resend) e WhatsApp (modelo da Meta, variáveis sem quebra de linha).
- `perguntar`: junta `growths_ia_extra` ao contexto; regra 7 da IA explica hoje/ontem/série/alertas.
- Montagem: `integra132.py` (roda o `integra131.py`) com `g132.js` e `g132.css`.
- Testes: `t132_assistente_alertas.py` (banco com cliente de teste e telas), `deno test supabase/functions/avisos/logica_test.ts`.

## Selo, tags coloridas e quem respondeu (v0.131)
- `seloQual(p)` (usa `qualificacao` e `pontuacao_qualificacao`) no `crmCardTopo`, no topo da `fichaPessoa` e na lista de clientes; `tagCor(t)` / `tagPill(t)` no `chipsTags` (CRM) e no topo da ficha; `fmtPts`.
- Pesquisa: aba `quem` em `vPesquisaDet` → `pqRespondentes(el, p, perg)` (estado `S.pqRv`: todas, filtro, ordem; CSV com BOM e `;`).
- Montagem: `integra131.py` (roda o `integra130.py`) com `g131.js` (antes de `const PQ_TOKEN`) e `g131.css`.
- Teste: `t131_selo_tags_respondentes.py`.

## Formulário de captação (v0.130)
- Página pública: `vPesquisaPublica(token)` → `pfDesenha(el, d, token, {previa})`; passos por `pfPassos(d)`; campos por `pfCampo`; aparência saneada por `pfVis` (fonte, cor, logo) e aplicada como variáveis CSS (`pfEstilo`); fontes carregadas por `pfCarregaFontes` (dois links por família, um sem pesos que sempre existe).
- Editor: aba `form` em `vPesquisaDet` → `pqForm(el, p, perg)` (configuração em `C`/`V`, pré-visualização com `pfDesenha(..., {previa: true})`, temas `PF_TEMAS`, contraste por `pfContraste`). `modalPergunta` ganhou `secao` (se a coluna existir: `S.pqSecao`).
- Modelo `PQ_MODELOS.captacao_mathisa` com `extra` (visual, captação, qualif) e perguntas com passo e pontos; `criarDeModelo` grava esses campos.
- Banco: `pesquisa_registrar` concentra a gravação (antes dentro de `pesquisa_responder`); `pesquisa_captar` valida, deduplica, cria/atualiza a pessoa e chama `pesquisa_registrar`.
- Montagem: `integra130.py` (roda o `integra129.py`) com `g130.js` e `g130.css`; o `g130.js` substitui a página pública antiga e fica no fim do script (depois de `PQ_MODELOS`).
- Teste: `t130_formulario_captacao.py` (41 verificações: editor, página pública no celular, CRM, deduplicação, bloqueios e o fluxo antigo).

## Gráfico único e qualificação por pontos (v0.129)
- `gcMulti(el, {rotulos, metricas, sel, parcial, metas})` e o novo `cpLinhas` (a versão da v0.128 saiu); seleção em `S.cp128.selM`. `CP_MET` lista as métricas e cores.
- Pesquisa: aba `qual` em `vPesquisaDet` → `pqQualif(el, p, perg)`; `pqPontua(cfg, perg, itens)` repete a conta do banco para o simulador.
- Banco: `pesquisa_qualificar(p_resposta)` (interna, sem permissão para o cliente), `pesquisa_requalificar(p_pesquisa)` (autenticado, confere o workspace), `pesquisa_responder` chama a qualificação no fim (alterada por substituição no texto da função, sem reescrever o resto).
- Montagem: `integra129.py` (roda o `integra128.py`) com `g129.js` e `g129.css`.
- Teste: `t129_multi_qualificacao.py`.

## Painel da campanha (v0.128)
- `campPainel128(el, c)` na aba Dashboard da campanha (depois de `vMktDashCampanha`): `cpGrade`, `cpQueda`, `cpLinhas`, `cpCriativos`, `cpVendas`; estado em `S.cp128` (período).
- `gcLinhas`: rótulos de data pela largura; escala com folga quando a variação é muito pequena. `GC.fmtK`: mais casas em valores pequenos e porcentagens abaixo de 5%. `gcDivergente` aceita a legenda.
- Montagem: `integra128.py` (roda o `integra127.py`) com `g128.js` e `g128.css`.
- Teste: `t128_painel_campanha.py`.

## Onda 3 (v0.127)
- `vendasOfertas127` (Vendas), `planoV127` (fim do `vPlano`), `saldoMinLer`/`saldoMinGrava`/`finSaldoMin` (Financeiro); `painelObs` ganhou a regra do saldo mínimo.
- Importação: campo `oferta_id` (ref `ofertas`) em `IMP_ALVOS.vendas`; `impCarregaRefs` carrega as ofertas pelo nome; a mensagem de "não encontrado" usa o nome da referência quando ela não é um alvo de importação.
- Montagem: `integra127.py` (roda o `integra126.py`) com `g127.js`.
- Teste: `t127_onda3.py` (cria e apaga dados de teste; roda o RODAR na base de teste e remove a coluna no fim).

## Fim da Onda 2 e da Onda 1 (v0.126)
- Componentes: `gcPilha`, `gcTornado`, `gcMatriz2x2`, `gcHalteres`, `gcDivergente`, `gcFunil`; `gcLinhas` ganhou `W` (largura) e `GC` o formato `n2`. Agrupamento: `gcGranDe`, `gcBaldes`, `gcChave`, `gcSemana`.
- Telas: `abandonoV126`, `rxLtvPainel` (em `rxCoortes`), `gmTornado` (fim do `gpDesenha`), `cicloV126`, `resultadosV126`, `debriefDesvio` e `gcFunil` (em `htmlComparativo`), `campBurnup` (aba Dashboard da campanha), `midiaV126` (Mídia paga), `mktSerie126` (Dashboard de marketing), `painelNovosExist` (Dashboard).
- Montagem: `integra126.py` (roda o `integra125.py`) com `g126.js` e `g126.css`.
- Teste: `t126_onda2_parte2.py`.

## Onda 2, parte 1 (v0.125)
- Componentes: `gcBarrasV`, `gcEmpilhada`, `gcDispersao`, `gcTodos` (paginação de 1.000 linhas); `gcBarrasH` ganhou `fixo` (mantém ordem e zeros).
- Telas: `painelObs` (Dashboard), `finResBanco` (Financeiro), `finVencimentos(m, 'receber'|'pagar')`, `mrrEm` e `contratosV125` (Contratos), `vendasV125` (Vendas), `mktV125` (Dashboard de marketing), `origemV125` (Leads por origem).
- Montagem: `integra125.py` (roda o `integra124.py`) com `g125.js` e `g125.css`.
- Teste: `t125_onda2_parte1.py`.

## Gráficos da onda 1 (v0.124)
- Componente: `gcLinhas`, `gcBarrasH`, `gcCascata`, `gcBullet`, `gcRitmo`, `gcLiga` (cliques que abrem a árvore) e o objeto `GC` (formatos, vazio, fonte). CSS com prefixo `gc-`. (O prefixo `gx` já era usado pelo Growth Model.)
- Dashboard: `painelV124(m, ctx)` chamado no fim do `vPainel`; DRE e fluxo em `<details class="gc-det">`.
- Financeiro: `finCascata(m, PER)` no fim do `vFinDash`; filtro de meses ≤ mês atual em "Resultado por mês".
- Custos e margens: `custoV124(m, ctx)` no fim do `vCustoOp`.
- Mídia: `midiaRelatorio(el, R, de, ate, cs, cp)` no fim do `vTrafego`; `irMidiaCampanha(c)` no botão `#cMidia` da campanha. Rotas: `adm-dash` → `vPainel` (troca a view para `adm-painel`), `st-dash` → `vPainel`, `mkt-midia` → `vTrafego` (fora do Starter troca para `mkt-trafego`). `vMidia` e `vDashGrowth` ficaram no código, sem rota.
- Montagem: `integra124.py` (roda o `integra123.py`) com `g124.js` e `g124.css`.
- Teste: `t124_graficos_onda1.py`.

## Linha no período e cadastros na campanha (v0.123)
- `arvLinha(top, N, root)` (no `arvDesenha`): caixa com os botões de agrupamento, chama `arvore_serie` e guarda por agrupamento em `top.series`. `arvGranAuto`, `arvRotPonto`.
- `estNova(pr, dup, aoCriar)`: com `aoCriar` abre em `#modalRoot2` (o `modal()` ganhou o parâmetro `raiz` e só redesenha a tela quando é o modal principal). Etapas: `estPickHtml`, `estPickModelo`, `estPickLer`.
- Nova campanha (`abrirWizard`): produto com `data-novo="produtos"` (`ligarNovo`), estratégia com "＋ Nova estratégia…" e prévia das etapas (`#wzEt`), canal com `cadastroRapido(ENT.canais…)`.
- Montagem: `integra123.py` (roda o `integra122.py`), com `g123.js` e `est123.js`; remove o bloco da v0.122.
- Teste: `t123_linha_cadastros.py`.
