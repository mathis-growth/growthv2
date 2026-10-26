

## Growth's Content simplificado (v0.159)
- `g159.js`: `tabBase` (pasta do Drive via `csDrive2`, link do dossiê, ficha com versões e aprovação), `tabIdentidade` (cores com papel, fontes, prévia, pasta, referências, limites, formatos, aprovação), `tabIdeias` (aprovar ou descartar), `tabProducao` (quadro Roteiro/Peça/Aprovada/Agendada) e `ctPeca` (roteiro com aprovação; arte ou vídeo com versões, ajuste e aprovação; capa; agendamento), `tabMais` (as abas antigas). `CT_BTN_IA`: botão da Claude desligado com o motivo.
- Banco: `20261114100000_content_simples.sql` (tabelas, colunas, método simples, `conteudo_valida` com a regra nova).
- Teste `t159_content_simples.py`: 25 verificações, 0 falhas (abas, ficha e versões, identidade e prévia, ideias, produção, peça, vídeo, Mais ferramentas, regras do banco, celular).

## Telas em grade (v0.158)
- `g158.js`: `GRADE_TELAS` (plano do Dashboard e do Dashboard financeiro: ordem e colunas de cada bloco), `gradeLiga` (marca a tela no `#main` e observa as mudanças), `gradeAplica` (põe ordem e largura; `.cols` e `.gc-sec` viram parte da grade), `gradeLarg` (largura útil do bloco para desenhar o gráfico), `gradeTextos` (compensa a letra de gráficos desenhados mais largos que o bloco).
- `g158.css`: grade de 12 colunas, blocos com a mesma altura na linha, pontos de quebra em 1100 e 760 px.
- Teste `t158_grade.py`: posições lado a lado, 7 cartões numa linha, letra mínima dos gráficos ≥ 9,5 px, gráficos na largura do bloco, frases do banco nos mesmos blocos, outras telas sem grade, celular em uma coluna, tela média. 0 falhas.

## Banco de narrativas (v0.157)
- `g157.js`: `narrCarrega` (lê os modelos aprovados uma vez), `narr(codigo, campos, alternativas)` (monta a frase, põe `data-nar` e `data-nar-v`; sem modelo ou sem campo, devolve vazio); Financeiro: `finContexto` (NAR-E07), `finCascata` + `gcCascata` (NAR-D02, "sobraram/faltaram"), `finPonte` (ponte ago → set, NAR-H01 e NAR-I01), `finSaldoMin` (caixa + saldo mínimo, NAR-A01, A02, D06, D07); `vMetricas157` (Dicionário com as frases do sistema e a situação de cada uma).
- Banco: `20261113100000_narrativa_modelos.sql` gerado de `nar_modelos.py` (fonte única dos 39 modelos).
- Teste novo `t157_narrativas.py`: regras do banco (versão, histórico, aprovação, sem apagar, só leitura), montagem das frases, ponte que fecha com os dois resultados, cores, modelo não aprovado some, saldo mínimo, Dicionário, celular. 0 falhas. Bateria de regressão: ver CHANGELOG.

## Data Storytelling (v0.152 a v0.156)
- `g152.js`: `SEM` (dicionário de apresentação), `semFmt`/`semBRL`/`semEscala` (formatador único, sinal de menos verdadeiro, "—" para sem dado), `semVar` (variação com direção, tolerância, p.p. e reais), `semStatus` (regra 2a e referências), `semPerAnt` (período anterior), `semCenarioMargem`; Dashboard: `painelHero`, `painelRecVendas`, `painelSemRefs`, `saldoHero`, `compactaKpis` (escala única por linha); observações com categoria e Referência.
- `g153.js`: `marcaSinais` (só saldos; tabelas pela coluna ou linha de saldo), `kpiD`, `dgDeltaG`, `varMes` com a camada nova; `brl` com "—" e sinal de menos; ROAS com 1 casa; LTV ÷ CAC como razão; cores de status do sistema = camada semântica; sem neon nos números.
- `g154.js`: `linhas` refeito (negativos, buracos, vazio); `gcLinhas` com `ref` e pontos na cor da série; cascata neutra com resultado com sinal; séries sem verde/vermelho; saldo mínimo e cenário como linha de referência; dispersão sem sobreposição; título repetido em Mídia paga.
- `g155.js`: contexto e frase-recado no Financeiro (`finContexto`), Marketing (`mktContexto`) e Vendas; custos neutros; mês até hoje contra os mesmos dias.
- `g156.js`: `alCat` (quatro categorias nos alertas), dicionário com unidade, direção e referência.
- Testes novos t152 a t156: 0 falhas. Bateria de tela anterior (t113 a t151, 31 testes): 0 falhas depois de ajustar t121, t127 e t132 às classes e ao sinal de menos novos. Falhas que já existiam na v0.151 (conferidas rodando a v0.151): t116/t117 (o teste compara o cartão abreviado com o valor completo da árvore), t146 (custos de IA) e 6 px de sobra no celular nas tabelas do Dashboard. t111 está desatualizado (outra base de dados). Uma venda de setembro da base de teste virou reembolso durante a bateria (t120); os testes novos calculam o esperado a partir do banco.

## Pesquisa e dossiê (v0.151)
- Apps Script: ação `ler` (Docs, Planilhas, Apresentações, texto, PDF em base64; limites de arquivos e de texto; pastas sem acesso listadas).
- Função `content-pesquisa` (publicada em 25/10/2026, versão 2): GET (diz se `ANTHROPIC_API_KEY`, `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` existem, nunca o valor), POST `pesquisar` e `dossie`; responde na hora e segue em segundo plano (`EdgeRuntime.waitUntil`); continua a conversa se a IA pausar (`pause_turn`); grava em `ia_uso`. `logica.ts` com as regras puras (6 testes Deno).
- Teste de ponta a ponta `tests/edge/pesquisa/teste_pesquisa.ts`: a função de verdade contra o banco local, com a Claude e o Apps Script simulados (18 verificações: permissões, o que vai para a IA, gravação, fontes, arquivos, custo com e sem preço, dossiê).
- `g151.js`: `csPesquisa` (o que a pesquisa usa, acompanhamento, relatório, fontes, arquivos), `csDossie` (seções com índice), `mdHtml` (Markdown escapado), atualização sozinha a cada 4 s enquanto roda.
- Testes de tela: `t151` (novo), `t143`, `t150`, `t148`, `t147`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Ficha de produto simples (v0.150)
- `g150.js`: bloco Produtos no questionário (`PERSONA_BLOCOS`, `PERSONA_P`), `prModal` (produto, valor, histórico, ativo), `tabProdutos2` (lista, trazer do cadastro, nova ideia sobre o produto, histórico recolhido com "Ler o histórico inteiro"). `integra150.py` troca as consultas do `dadosConteudo` e a aba.
- Migração `20261110100000_content_produtos_v2.sql` (aplicada em produção em 25/10/2026).
- Testes: `t150` (novo), `t143`, `t148`, `t147`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Ficha de conteúdo dos produtos (v0.149)
- `g149.js`: `PF_SECOES` (7 partes), `pfModal` (formulário), `pfLeitura` (ver ficha), `tabProdutos` (cartões com % preenchido e conteúdos ligados). `integra149.py`: produtos e fichas no `dadosConteudo`, campo Produto no `modalConteudo` (com score e com notas), aba Produtos.
- Links da página e do checkout aceitos sem "https://" (o sistema completa).
- Migração `20261109100000_content_produtos.sql` (aplicada em produção em 25/10/2026).
- Testes: `t149` (novo), `t148`, `t147`, `t143`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Painel da produção no Kanban (v0.148)
- `g148.js`: `kbPainel(L, D)` (total por etapa, semana atual, calendário de 6 semanas) e `kbLiga(el, C)` (ir para a coluna; abrir a semana na aba Semana). `integra148.py` troca a linha de quadrinhos do Kanban pelo painel. `g148.css` com as cores das etapas.
- Testes: `t148` (novo), `t147`, `t143`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Pastas do cliente e da Mathisa (v0.147)
- `g147.js`: `csDrive2` (só a pasta compartilhada; "Outras pastas que você já tem" com adicionar, salvar e tirar), tira "links" do `CS_MAT`, `vPastasMathisa` (tela interna). `integra147.py`: menu, `TELAS_INT`, rota `cfg-pastas`, passo 1 usando `csDrive2`.
- Migração `20261108100000_content_pastas.sql` (aplicada em produção em 25/10/2026).
- Testes: `t147` (novo), `t143` (passo 1 e 5 materiais), `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Estruturas e custos de IA (v0.146)
- `g146.js`: `vEstruturas` e `esModal` (biblioteca, etapas com subir/tirar), `tabEstruturas` (escolha do cliente por formato; aba nova e passo 7), `vCustos` (período, câmbio, por cliente e mês, por tipo de uso). `integra146.py`: menu "Growth's Content (interno)", `TELAS_INT` no lugar do `cfg-pacotes` fixo, `S.verCustos` no início, rotas e a aba. `g146.css` com `body #main` / `body #modalRoot`.
- Câmbio com `data-money="0"` para não cair na máscara de moeda.
- Migração `20261107100000_content_estruturas.sql` (aplicada em produção em 25/10/2026, pelo SQL Editor; conferida: 7 estruturas, 3 tabelas, 5 funções, `ia_uso` fechada).
- Testes: `t146` (novo), `t143`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Canais e materiais do cliente (v0.145)
- `g145.js`: reordena `CS_PASSOS` (9 passos, com `fontes` e `materiais` novos) e `CS_IR`; `csFontes` (canais, `csPerfilUrl`), `csMateriais2` (seis tipos em abas, "Pronto"/"Não tenho"/"Reabrir", links de outros Drives). `integra145.py` liga o passo `fontes` e troca o `csMateriais` pelo `csMateriais2`. `g145.css` com `body #main` para vencer o CSS anterior.
- Migração `20261106100000_content_fontes.sql` (aplicada em produção em 25/10/2026).
- Testes: `t143` (9 passos, canais, materiais, links, permissões), `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Configuração em 8 passos e pasta compartilhada (v0.144)
- `g143.js`: `CS_PASSOS` com 8 passos (`emBreve` não trava a conclusão), `CS_IR`, novo `csDrive` (compartilhar pasta, copiar e-mail, colar link, "Verificar de novo"; "Não tenho Google Drive").
- `g144.js`: `csCall` (roteiro da call por blocos, salva em 900 ms), `csMateriais` (lista e marco "material pronto"), `csEmBreve`, `csLinhaIA` (gerar, copiar, colar e aplicar a proposta). `g144.css` com seletores mais específicos (`#main ol.cs-passos`, `#main .cc-q > label`).
- Função `content-drive` (versão 5): lê `drive_script_email` e o modo; pasta compartilhada sem acesso devolve a explicação de como compartilhar.
- Migração `20261105100000_content_setup_v2.sql` (aplicada em produção em 25/10/2026). Cliente "Teste Growth's Content": árvore criada na pasta dele em 25/10/2026 (conferida no Drive).
- Testes: `t143` (8 passos), `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Configuração passo a passo e Google do cliente (v0.143)
- `g143.js`: `vConteudo` novo (configuração ou abas), `csWizard` (abertura, barra de passos, rodapé fixo com Voltar/Continuar/Concluir e o que falta), `csDrive` (conectar Google, sem Drive, completar, trocar, desconectar, espera da pasta), `csRotina`, `csRetornoGoogle`. As telas de Persona, Linha editorial e Canais são as mesmas, dentro dos passos. `integra143.py` renomeia o `vConteudo` antigo para `vConteudoAbas`.
- Função `supabase/functions/content-google` (index.ts, logica.ts, logica_test.ts), publicada sem verificação de JWT.
- Migração `20261104100000_content_setup.sql` (aplicada em produção em 25/10/2026). Testes: `t143_content_setup.py`; `t133`, `t134`, `t135`, `t140`, `t141` marcam o módulo como configurado ou seguem a regra nova.


## Correção Growth Starter (v0.142)
- `g141.js` (`ncModal`): `starter` só quando o Growth's Content não está marcado; aviso `.ac-aviso`; troca automática do tipo. Teste `t141` ganhou 3 verificações.


## Acesso em árvore (v0.141)
- `g141.js`: `acMonta`/`acArvore`/`acLiga` (árvore com setinhas, grupos e subgrupos, estado parcial, atalhos), `acGrava` (tudo / pacote igual / ligadas e desligadas), `ncModal` (Novo cliente). `integra141.py` troca o "Novo cliente" antigo e deixa no quadro do Growth's Content a caixa só para a equipe interna.
- Migração `20261103100000_acesso_content.sql` (aplicada em produção em 25/10/2026). Teste `t141_acesso_content.py`; `t140` ajustado.


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
