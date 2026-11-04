## v0.253
- `campanha_canais.percentual_meta_vendas`: porcentagem da meta de vendas da campanha. `percentual_meta_leads` passa a ser preenchida pelo assistente.
- `campanha_ofertas.meta_vendas`: meta de vendas da oferta. `campanhas.meta_vendas` passa a ser a soma das ofertas.
- `campanhas.extras.cenarios.ofertas`: por oferta da campanha, aceite (`a`, em %) em cada cenário, mais o que foi mexido à mão. `meta_total` e `meta_cac_total` guardam o que foi gravado em `campanhas`.
- `campanha_ofertas.oferta_id` e `oferta_versao`: preenchidas ao escolher ou criar a oferta no assistente.

## v0.252
- `v_vendas_mkt`: uma linha por venda aprovada, com `valor_bruto`, `liquido`, `comissao` (sem as canceladas e estornadas) e `saiu`.
- `v_marketing_campanha`: colunas novas `faturamento`, `faturamento_saiu` e `comissoes`. `receita` = líquido − comissões, sem quem saiu. `roas` = faturamento ÷ investimento.
- `v_marketing_canal`: coluna nova `faturamento`; `roas` sobre ela.
- `funil_analise`: `faturamento` e `faturamento_antes_churn`, por campanha e em `pos`. `funil_cohorts`: `faturamento`; `ltv` e `roas` sobre ele.

## v0.251
- `v_pessoas_saiu`: pessoas com aluno e nenhum aluno ativo.
- `v_marketing_campanha`: `investimento` (anúncios ou, sem eles, lançamentos), `cac` (÷ vendas), `roas` (receita ÷ investimento) e colunas novas `receita`, `receita_saiu`, `receita_antes_churn`, `pessoas_saiu`.
- `v_marketing_canal`: `investimento` e `cac` na mesma regra; colunas novas `receita` e `roas`.
- `funil_analise.pos` e cada campanha: `receita` sem o churn e `receita_antes_churn`. `funil_cohorts`: `vendas`.

## v0.250
- `funil_analise`: `vendas` em cada campanha e em `pos`.
- Storage: local público `avatares` (2 MB; JPG, PNG e WebP), arquivo `<id do usuário>/foto.jpg`. O endereço fica em `user_metadata.foto_url` da conta.

## v0.249
- `campanhas.extras.referencia_planejamento` ganha `filtro` (`ultimas` ou `periodo`), `ini`, `fim` e `aceites: [{papel, valor, fonte}]`.
- O aceite levado grava `campanha_ofertas.taxa_aceite` (fração de 0 a 1) nas ofertas daquele tipo.
- `campanhas.data_carrinho_abre` e `data_carrinho_fecha` podem ser usadas também no perpétuo.

## v0.248
- `campanhas.fases` aceita também `reabertura` e `downsell` (`{ini, fim}`; `fim` nulo = em aberto).
- `campanhas.extras.cenarios`: `{base, pessimista, otimista, mexido, atualizado_em}`, cada cenário com `I` (investimento), `p` (CPL), `L` (leads), `c` (conversão %), `V` (vendas), `a` (CAC), `t` (ticket), `rec` e `roas`.

## v0.247
- `campanhas.extras.referencia_planejamento` ganha `qtd` e `escolhas: [{k, l, un, valor, fonte, fonte_id, campo}]` (`fonte_id` = `media` ou o id da campanha). `metas_antes` passa a usar o nome do campo da meta nas escolhas feitas pelo assistente.
- As datas do assistente usam `campanhas.fases`, `data_carrinho_abre` e `data_carrinho_fecha`, que já existiam.

## v0.246
- `campanhas.extras.referencia_planejamento` (sem mudança de estrutura): `{em, por, valores: {cpl, cac, conv}, metas_antes: {cpl, cac, conv}, campanhas: [{id, nome, data_fim, investimento, leads, vendas, clientes, receita_bruta}], historico: [até 10 anteriores]}`.

## v0.245
- `equipe.avisar_resposta` (padrão sim).
- Gatilho adiado `pesquisa_respostas_aviso_t` (`resposta_formulario_avisar`): roda no fim da gravação da resposta, depois da pontuação, e usa `equipe_avisa`.

## v0.244
- `equipe.avisar_lead_novo` (padrão sim).
- Gatilho por comando `pessoas_lead_novo_t` (`lead_novo_avisar`), usando `equipe_avisa`.
- Função `pesquisa_trocar_link(pesquisa)`.
- `sistema_config.avisos_zernio_modelo` (opcional; padrão `aviso_growths`).

## v0.243
Sem mudança no banco.

## v0.242
Sem mudança no banco.

## v0.241
Sem mudança no banco.

## v0.240
Sem mudança no banco. A ideia falada usa `conteudos` com a tag `ideia por voz`.

## v0.239
Sem mudança no banco.

## v0.238
Sem mudança no banco.

## v0.237
Sem mudança de estrutura. Só dados: a configuração da pergunta de arquivos do Diagnóstico Mathisa.

## v0.236
- Função nova `diagnostico_formulario_reabrir(diag)`.
- `pesquisa_respostas_diag`: a resposta mais nova do mesmo link passa a ser a do diagnóstico.

## v0.235
Sem mudança no banco.

## v0.234
Sem mudança no banco.

## v0.233
- `pesquisa_perguntas.pontos` aceita `bloco` e, em cada opção, `elim`.
- `pesquisas.qualif` aceita `grupos` (`[{nome, regras: [{tag, se: {bloco|total: {min, max}}}]}]`) e `confere` (`{pediu, indicado, tag}`).
- Coluna nova `pesquisa_respostas.qualif_det` (total, blocos, eliminado, regras que bateram).
- `pesquisa_qualificar` reescrita; as regras antigas dão o mesmo resultado.

## v0.232
- `diagnostico_formulario` corrigida: insere o envio com `on conflict do nothing` (vale com a trava `pesquisa_envios_ciclo_uq`) e pega o envio de menor ciclo.

## v0.231
- `workspaces`: `inativo_em`, `inativo_por`, `inativo_motivo`, `contrato_origem_id`.
- `produtos`: `cria_workspace`, `workspace_modo` (starter ou completo), `workspace_pacote_id`.
- `contratos`: `empresa_nome`, `empresa_razao_social`, `empresa_cnpj`, `responsavel_nome`, `responsavel_email`, `pacote_id`, `cliente_workspace_id`, `cliente_workspace_erro`.
- Tabela nova `workspaces_excluidos` (só a equipe interna lê).
- Funções novas: `workspace_inativar`, `workspace_reativar`, `workspace_excluir`, `contrato_criar_workspace`, `contrato_criar_workspace_manual`; gatilho `contratos_cria_workspace_t`.
- Alteradas: `pertence_ao_workspace` (inativo só para a equipe interna) e `clientes_acesso` (situação e contrato de origem).

## v0.230
- `pesquisas.captacao` ganhou `destino` (lead ou cliente) e `etapa_cliente_id`.
- Funções novas:
  - `pesquisa_cliente_etapa(resposta)`;
  - gatilho `pesquisa_respostas_cliente`.
- `pesquisa_captar` e `pesquisa_publica` foram ajustadas com troca pontual.

## v0.229
- `diagnostico_saber_revisoes` (nova): `chave`, `estado` (confirmado, corrigido, rejeitado ou reunião), `valor`, `nota`, `autor` e `atualizado_em`.
  - Cada diagnóstico tem uma linha por informação (chave única).
  - A chave diz de onde vem a informação: `f:` pergunta do formulário, `p:` cálculo da planilha, `r:` roteiro da reunião, `c:` conflito.
- `pesquisa_arquivos_dono_ck` aceita arquivo da equipe sem diagnóstico.
- A auditoria de cada aba ganhou `soma_mes`, `n_ok` e `total_ok`; a versão passou a 2.

## v0.228
- Colunas novas:
  - `diagnosticos.contrato_id` e `diagnosticos.aluno_id`;
  - `pesquisas.padrao_diagnostico` (um por empresa).
- `diagnosticos_coerente` aceita o envio (formulário escolhido) antes da resposta, do mesmo cliente.
- Gatilho `pesquisa_respostas_diag`: a resposta entra no diagnóstico do envio.
- Funções novas:
  - `diagnostico_formulario(diag, pesquisa)`;
  - `diagnostico_formulario_enviado(diag, canal)`;
  - `diagnostico_formulario_padrao(pesquisa)`;
  - `diagnosticos_clientes(ws)`.
- `diagnostico_progresso` passa a ter 9 etapas.

## v0.227
- `pesquisa_arquivos.auditoria` (jsonb, até 300 KB):
  - `abas[]`: tipo, linhas, colunas, mapa, amostra mascarada, alertas, meses, produtos, canais, status, cobertura, sinais e qualidade;
  - `sinais`, `tipo`, `periodo`, `qualidade`, `manual` (escolhas da equipe) e `auditado_em`.
- Funções:
  - `diagnostico_arquivo_auditoria(id, aud, erro)`;
  - `diag_grupo_arquivo(grupo, classe, nome, tipo)`.
- `diagnostico_checklist` e `diagnostico_depara` passaram a usar a auditoria.

## v0.226
- Sem mudança no banco.

## v0.225
- `metricas_definicoes.requisitos` (jsonb): o que cada métrica precisa, em quatro tipos:
  - `g:` grupo de arquivo;
  - `l:` item da leitura das planilhas;
  - `c:` coluna a confirmar;
  - `x:` fonte fora dos arquivos.
- Funções novas:
  - `diagnostico_depara(diag, hoje)`;
  - `diag_metrica_rotulo(texto)`: os rótulos do formulário Entrada → código do catálogo.

## v0.224
- Funções:
  - `diagnostico_checklist(diag, hoje)`: checklist, resumo e números;
  - `diag_grupo_arquivo(grupo, classe, nome)`: o grupo do checklist de cada arquivo.
- `diagnostico_progresso` ganha a etapa `pre`.
- `diagnosticos.arquitetura.pre` guarda `mensagem`, `revisado_em` e `revisado_por`.

## v0.223
- `diagnosticos`:
  - `resposta_id` agora opcional;
  - colunas novas: `titulo`, `responsavel_id` (equipe), `periodo_ini`, `periodo_fim`, `versao`, `criado_por`;
  - `status` em `rascunho` (em coleta), `em_analise`, `em_revisao`, `validado`, `arquivado`.
- `diagnostico_decisoes` (novo): o histórico do diagnóstico.
  - `tipo` em `status`, `decisao`, `comentario`, mais `texto`, `autor` e `criado_em`.
  - Só leitura e inclusão.
- `pesquisa_arquivos` vira a Central de Evidências:
  - `envio_id` e `pesquisa_id` opcionais;
  - colunas novas: `diagnostico_id`, `origem` (cliente ou equipe), `enviado_por`, `hash`, `classe` (14 tipos), `classe_origem` (manual ou sugerida), `periodo_ini`, `periodo_fim`, `dados_pessoais`, `versao`, `processamento`, `processamento_erro`, `processado_em`, `arquivado_em`, `arquivado_por`.
- Funções:
  - `diagnostico_arquivo_registrar`, `_confirmar` (confere o arquivo no Storage), `_editar`, `_hash`, `_arquivar`, `_processamento`;
  - `diagnostico_progresso`, `diagnosticos_lista`;
  - internas: `diag_pode`, `diag_arquivo_pode`.
- Gatilhos: os arquivos do link entram no diagnóstico; histórico de status.
- Storage: a política `diagnostico_equipe_enviar` deixa a equipe enviar só para o caminho autorizado.

## v0.222
- Sem mudança no banco.

## v0.221
- `metas.metrica`: + margem, caixa, churn, retencao90, ltv, ascensao, nsm (metas de nível, granularidade ano, direção mínimo/máximo/maior/menor).
- Funções: `metas_nivel_cfg`, `metas_grava_nivel`, `metas_nivel_salvar` (tela), `metas_nivel_valor`, `metas_avaliar_nivel`, `metas_niveis`; `metas_painel` devolve `niveis`. Gatilhos de espelho: `metas_de_heavyops`, `metas_de_nsm`, `metas_de_saldo_minimo`, `metas_para_origens`. `riscos_detectar` ganhou o bloco de metas de nível.

## v0.220
- Funções de leitura: `projecao_backtest(ws, metrica, hoje, meses)` → pontos {mes, dia, realizado_no_dia, projecao, final, erro_pct} e resumo por dia {meses, erro_medio_pct, vies_pct, maior_erro_pct}; `projecao_faixa(ws, metrica, ini, fim, hoje)` → {de, ate, erro_medio_pct, vies_pct, dia_ref, meses, texto} ou {motivo}; `projecao_fotos(ws, metrica, hoje)`.

## v0.219
- Funções de leitura: `aarrr_numeros(ws, ini, fim)` (os números de um período) e `aarrr_painel(ws, ini, fim, hoje)` → etapas com métricas {codigo, nome, unidade, direção, taxa, v, v_ant, var, meta, sem_dado}, gargalo, passagem, nsm.

## v0.218
- `metas_cenarios`: workspace, métrica, escopo/ref, ini/fim, nome, hipótese, alavancas (leads_pct, invest_extra, conv_nova, ticket_novo), resultado, status (rascunho | aprovado | arquivado), versão, substitui_id, criado por/em.
- Função `metas_simular(ws, metrica, ini, fim, hoje, escopo, ref, alavancas)` → avaliação, atual, cenário, precisa_fator, premissas, avisos, incertezas.

## v0.217
- Funções de leitura: `investigar(ws, metrica, ini, fim, filtros)` → total, total anterior, dimensões com fatias {k, r, v, v_ant}, nomes dos filtros; `investigar_registros(ws, metrica, ini, fim, filtros, limite)`; auxiliares `investigar_linhas` (uma linha por venda ou lead, com as dimensões) e `investigar_passa` (filtro).

## v0.216
- Função `metas_trajetoria(ws, metrica, ini, fim, hoje, escopo, ref)` → `{avaliacao, pontos: [[dia, meta_acumulada, realizado_acumulado|null]]}`.
- Gatilho `riscos_qualidade_sem_impacto` em `riscos`.

## v0.215
- `riscos`: chave única por cliente, tipo (abaixo_do_esperado | risco_de_nao_atingir | oportunidade | qualidade_dados | operacional), área (empresa | marketing | vendas | cs | financeiro | growth), métrica, meta_id, escopo/ref, ini/fim, severidade (alta | média | baixa), título, evidência, dados, impacto + unidade, fonte (metas | alertas | guardrails | qualidade), ação sugerida, status (aberto | em_tratamento | resolvido | descartado), responsável, nota, detectado/visto/atualizado/resolvido em, resolvido_por (sistema | usuário).
- `riscos_eventos` (histórico de cada mudança), `riscos_rodadas` (última conferência por cliente).
- Escrita só pelas funções (`riscos_detectar`, `riscos_acao`); leitura por RLS do cliente.

## v0.214
- `metas.metrica`: faturamento, leads, vendas.
- `metas_fotos`: escopo e ref; a chave vira índice único (workspace, métrica, escopo, ref, ini, fim, dia).
- Funções: `metas_grava` (geral), `metas_serie`, `metas_realizado_dia`, `metas_recortes`, `metas_avaliar(ws, metrica, ini, fim, hoje, escopo, ref)`; `metas_no_intervalo` sai. Gatilho `metas_de_campanha` em `campanhas`.

## v0.213
- `metas`: id, workspace_id, metrica (faturamento), escopo (empresa | produto | campanha) + produto_id/campanha_id, granularidade (ano | trimestre | mes | personalizado), ini, fim, valor, valor_max, unidade, direcao (maior | menor | faixa | minimo | maximo), trajetoria (linear | sazonal | personalizada) + trajetoria_pesos, objetivo_id → plano_objetivos, plano_anual_id, origem (plano_anual | historico | manual | hibrido | migrada), premissa, versao, status (rascunho | aprovada | arquivada), aprovado_por/em. Uma meta aprovada por métrica, escopo e período.
- `metas_historico` (versões anteriores), `metas_regras` (atencao_pct, risco_pct, min_dias por cliente), `metas_fotos` (meta, esperado, realizado, projeção, método e status por dia).
- `growth_metricas`: nsm_status, nsm_versao, nsm_aprovada_em/por, nsm_nota; `nsm_historico`.
- `plano_objetivos`: ano (objetivo do ano sem o plano antigo); plano_id passa a ser opcional.
- Funções: `metas_avaliar`, `metas_painel`, `metas_consistencia`, `metas_no_intervalo`, `metas_realizado`, `metas_fotografar` (cron `growths-metas-foto`).

## v0.212
- Sem mudança no banco.

## v0.211
- Sem mudança no banco.

## v0.210
- `parceiros` (nome, papel coprodutor|afiliado|vendedor|outro, ativo) e `parceiro_comissoes` (parceiro_id, produto_id vazio = geral, percentual, base bruto|liquido, desde, ate). Sai `parceiros_comissao` (da v0.209, nunca aplicada em produção).
- O pacote "Financeiro simplificado" sai; o Go-to-Market ganha a tela `adm-financeiro`.

## v0.209
- `mkt_custos_itens.grupo` (marketing | operacional).
- `parceiros_comissao` (nome, papel coprodutor|afiliado|vendedor|outro, percentual, base bruto|liquido, produto_id, desde, ate).
- `mkt_custos_mes` devolve também `fixos_op` e `variaveis_op`; `faltam` conta os variáveis dos dois grupos.
- Função `dre_simplificado(ws, ate, meses)`: por mês, faturamento, reembolsos, taxa, impostos, comissões de parceiros e da equipe, mídia, custos de marketing e da operação, faltam e fechado.
- `acesso_telas`: `adm-financeiro`. `pacotes_acesso`: "Financeiro simplificado".

## v0.208
- Função `vendas_periodo(ws, ini, fim)`: vendas, valor, reembolsos, valor reembolsado, clientes novos (com o histórico), leads e leads que viraram cliente, clientes ativos e inativos, e os mesmos números do período anterior.

## v0.207
- Sem mudança no banco.

## v0.206
- `importacoes_historico` (lote: plataforma, arquivo, hash, linhas, vendas, pessoas_novas, ignoradas, valor_aprovado, período, pessoas_criadas[], desfeito_em).
- `vendas_historicas` (lote_id, pessoa_id, produto, plataforma, data_venda, valor, status aprovada|reembolsada|cancelada|chargeback, id_externo; único por cliente + plataforma + código).
- Visão `v_vendas_todas` (vendas + histórico: workspace_id, pessoa_id, dia, valor, status, origem).
- Funções `importar_historico_vendas(ws, plataforma, arquivo, hash, linhas, simular)`, `desfazer_importacao_historico(lote)`; `plano_anual_sugestoes` usa `v_vendas_todas` e devolve `historico_vendas`, `historico_de`, `historico_ate`.

## v0.205
- `mkt_custos_config` (workspace_id, ativo, responsavel_id → equipe).
- `mkt_custos_itens` (nome, tipo fixo|variavel, valor (fixo), desde, ate — sempre o 1º dia do mês).
- `mkt_custos_valores` (item_id, mes, valor, lancado_em, lancado_por) — trava em mês fechado.
- `mkt_custos_meses` (workspace_id, mes, fechado_em, fechado_por, atividade_id, aviso_cliente_em, aviso_equipe_em) — só muda pelas funções.
- Funções: `mkt_custos_mes` (interna), `mkt_resultado(ws, ini, fim)`, `vendas_por_plataforma(ws, ini, fim)`, `mkt_custos_fechar`, `mkt_custos_reabrir`, `mkt_custos_rodar(ref)` (rotina).
- `acesso_telas`: `mkt-custos`. `pacotes_acesso`: "Go-to-Market".

## v0.204
- Sem mudança: o título público é `pesquisas.visual.titulo`.

## v0.203
- Grupos novos de arquivo: `vendas_hotmart`, `vendas_kiwify`, `vendas_eduzz`, `vendas_hubla` (em `pesquisa_arquivos.grupo` e na resposta de documentos). Cada categoria pode ter `se` (os valores de "Onde vende?" que a mostram; `_nenhuma` = nenhuma plataforma marcada); a pergunta de documentos tem `config.onde` = id da pergunta "Onde vende?".

## v0.202
- `pesquisa_perguntas.config.sem_depois` (documentos com envio): só "enviar" ou "Não tenho".

## v0.201
- Sem tabela nova. As perguntas do modelo vão para `pesquisa_perguntas`; no grupo de documentos, `config.categorias[]` ganha `cols` e `ex` (colunas e exemplo da planilha-modelo) e `config.periodo` (de, até, texto).

## v0.200
- `plano_anual_sugestoes`: novo `receita_ano_anterior_base` ('ano' ou '12m'); com '12m', `receita_ano_anterior` são as vendas aprovadas dos últimos 12 meses fechados.
- Sem mudança de tabela: cada ano é uma linha de `plano_anual` (único por cliente e ano).

## v0.199
- `plano_anual.premissas`: sai a chave `margem`; entram `custos_variaveis` (% do preço, sem impostos) e `_imposto` { regime mei|simples_auto|simples_III|simples_V|presumido|real|manual, folha, iss, manual, do_cadastro }.
- `plano_anual_sugestoes`: novos `custos_variaveis_pct` (deduções fora 5.1.02 + comissões 6.2.03, ÷ receita) e `imposto_hist_pct` (5.1.02 ÷ receita); `custos_fixos_ano` sem mídia paga e sem comissões.

## v0.198
- `plano_anual` (workspace_id, ano, caminho ambicao|realista|ambos, modo_ambicao lucro|crescimento, premissas jsonb { chave: { valor, fonte sistema|digitado|estimativa, nota, ajuda } }, pct_pessimista, pct_otimista, base_de, cenario_meta, meta_receita; único por cliente e ano).
- Função `plano_anual_sugestoes(ws, ano, hoje)`: receita do ano anterior, margem de contribuição e custos fixos (DRE), recorrência e perda (contratos), clientes, recompra e ticket (vendas), sazonalidade (12 pesos, com 6 meses ou mais) e realizado do ano mês a mês.
- A meta mês a mês continua em `planejamento_mensal.meta_receita`.

## v0.197
- `pesquisa_modelos_ocultos` (workspace_id, modelo, ocultado_em; chave workspace + modelo): modelos prontos que o cliente tirou da lista. Ver: quem é do cliente ou da equipe interna; gravar e apagar: quem edita Growth ou Marketing.

## v0.196
Sem mudança no banco. `estrategia_blocos.props.lados` = { id da ligação: { de: r|l|t|b, para: r|l|t|b } }, no bloco de onde a ligação sai.

## v0.195
Sem mudança no banco. Tipos novos de bloco (texto livre em `estrategia_blocos.tipo`): `order_bump`, `downsell`.

## v0.194
Sem mudança no banco.

## v0.193
Sem mudança no banco. `campanhas.extras.pesquisa` = { usa, pesquisa_id, captacao, obrigado, disparo, quando (cadastro | etapa | manual), etapa, canal (whatsapp | email | link), atualizado_em }. Ao salvar, a pesquisa recebe `aceita_link_aberto = true` (obrigado ou captação), `captacao.ativa = true` (captação) e `canal_envio` (disparo).

## v0.192
Sem mudança no banco.

## v0.191
Sem mudança no banco: a baixa em lote chama `registrar_pagamento` e `registrar_recebimento`, uma vez por conta.

## v0.177 — Diagnóstico 360° (G1b, G2 e G3)
- `metricas_definicoes.natureza`: `valor` (soma ou contagem) ou `taxa` (conta). Preenchida em todas as métricas do funil.
- `pesquisa_envios.rascunho` (jsonb: `{passo, campos: {chave do campo: valor}, listas: {pergunta: linhas}}`) e `rascunho_em`.
- **`pesquisa_arquivos`**:
  - empresa, envio, pesquisa, pessoa, grupo (código do grupo de documentos), nome, caminho no Storage (`empresa/envio/id.ext`), tamanho, tipo;
  - status (`pendente` até a função confirmar que o arquivo chegou, depois `enviado`), `criado_em`, `enviado_em`.
- Storage: local privado **`diagnostico`** (20 MB por arquivo).
- **`diagnosticos`**:
  - um por resposta (`resposta_id` único). Pesquisa, envio e pessoa vêm da resposta;
  - `status` (`rascunho` ou `validado`), `decide` text[] (códigos das métricas usadas para decidir);
  - `arquitetura` jsonb (`roteiro`: {texto da pergunta do modelo completo: resposta}), `notas`;
  - `leitura` jsonb (score, itens com título, status, detalhe e o que pedir, mensagem, cobertura, vendas, arquivos, `lido_em`);
  - `validado_em` e `validado_por`.
- **`diagnostico_metricas`**: diagnóstico, código, `declarado` (o que o cliente marcou), `detalhe` jsonb (numerador, denominador, janela, inclui, confere, fonte, detalhe, compara, responsavel, atualiza, decisao, objetivo, clareza, reacao, confianca, valor, tem_dados), `decide`, `observacao`. Único por (diagnóstico, código).

## v0.176 — Diagnóstico 360° (G1)
- `pesquisas.tipo` aceita `diagnostico`; `pesquisas.publico` (`lead` ou `cliente`; os antigos: lead → lead, os outros → cliente).
- `pesquisa_perguntas.tipo` aceita `numero`, `moeda`, `meses`, `metricas`, `lista` e `documentos`.
- `pesquisa_perguntas.condicao`: `{pergunta, valores[]}`.
- `pesquisa_perguntas.config`:
  - meses;
  - `etapas`, `modelo` (id da pergunta de modelo de negócio), `min_decide` e `max_decide`;
  - colunas;
  - categorias e aviso;
  - naosei.
- `pesquisa_resposta_itens.valor_json`:
  - métricas: `{codigo: {status, decide, objetivo, numerador, denominador, janela, inclui, calculo, como[], fonte, atualiza, detalhe, responsavel, clareza, decisao, reacao, confere, confianca, valor, tem_dados}}`;
  - meses: `{"AAAA-MM": valor}`;
  - lista: `[{...}]`;
  - documentos: `{grupo: sim|parte|nao|depois}`.

  Em métricas, `valor_num` é quantas o cliente tem.
- `pesquisa_envios.expira_em` (diagnóstico: 30 dias).
- `metricas_definicoes`: `etapa_aarrr` (aquisicao, ativacao, retencao, receita, recomendacao, recompra), `modelos` text[] (vazio = todos), `calcula_sozinho`, `descricao_cliente`, `ordem`.

## v0.174
- `contratos.oportunidade_id` → `oportunidades` (vários contratos por oportunidade; mesma pessoa e workspace, validado por gatilho).
- `oportunidades.origem` aceita `crm`.
- Gatilhos: contrato ativado → oportunidade aberta vira ganha; oportunidade de venda nova muda → `pessoas.negocio_status` (resumo).

## v0.173
- `pessoas.documento`: CPF (11) ou CNPJ (14) só com dígitos, validado (`documento_valido`) e único por workspace quando houver (`pessoas_documento_uq`). O gatilho `pessoas_documento_t` normaliza o que foi digitado. O tipo sai do tamanho.
- `_pessoas_mesclar_v088`: documentos diferentes impedem; o da removida passa para a mantida; tags vazias nos dois viram `{}` (antes falhava).

## v0.171
- `estrategia_publicar` passa a `security definer` (mesma checagem: `pode_operar` e `perm(..., 'editar', mkt/gro)`); grava `publicada_por = auth.uid()`.
- `funis.criado_em` (timestamptz, padrão `now()`; as estratégias antigas ficam sem data).
- `estrategia_blocos.tipo = 'passagem'`: Passagem para o CS (fase retenção, sem métricas).

## v0.165 — Strategy Canvas (S1 a S3)
- `funis`: `categoria` (texto livre), `objetivo`, `criterios` (critérios de sucesso), `status` rascunho/ativa/arquivada, `versao_atual` (0 = nunca publicada). Gatilho `funis_status_t` mantém `ativo` igual a `status <> 'arquivada'` nos dois sentidos.
- `estrategia_blocos` e `campanha_blocos`: `x`, `y` (posição no mapa; vazio = organizar pela fase e ordem) e `props` jsonb (objetivo, descrição, canal, responsável, oferta, status). `campanha_blocos.status` planejado/implementado/pendente.
- `estrategia_conexoes` / `campanha_conexoes`: `de_bloco`, `para_bloco`, `tipo` segue/sim/nao/divisao, `rotulo`, `condicao`, `nota`, `peso` (% só na divisão). Única por (de, para); gatilho `conexao_valida` barra bloco ligado nele mesmo e bloco de outra estratégia ou campanha.
- `estrategia_versoes`: (funil, versao) única, `nota`, `foto` jsonb (estratégia, blocos, métricas e ligações), `publicada_em`, `publicada_por`. Não muda nem se apaga depois de gravada. `campanha_estrategias.versao_id` aponta a versão que a campanha copiou.
- Funções: `estrategia_publicar(funil, nota)` devolve o número da versão; `campanha_aplicar_estrategia` copia também posições, propriedades, blocos sem métrica e ligações, grava a versão e publica a v1 se a estratégia nunca foi publicada.
- `acesso_telas`: `mkt-estrategias` (Marketing). RLS: ler mkt/vendas/gro/adm, editar mkt/gro.

## v0.164
- Sem mudança no banco. O Cockpit lê `painel_gerencial`, `growths_serie` (série por dia), `v_dre_mensal` (receita e lucro por mês), `cg_indicadores`, `campanhas` (situação), `oportunidades` abertas, `projetos` e `projeto_atividades`, `growth_metricas` (North Star), `growth_experimentos` e `growth_metricas_auto`.

## v0.163 — Customer Growth
- `jornadas` (workspace, produto ou vazio quando é modelo, nome, `modelo`, `versao`, `status` rascunho/publicada/anterior/arquivada, `baseada_em`, publicada_em/por). Uma publicada e um rascunho por produto.
- `etapas_kanban.jornada_id`: etapa do quadro de alunos que pertence a uma jornada de produto (vazio = Jornada geral). Nome único dentro da jornada (e na geral, como antes: índices `etapas_kanban_geral_uq` e `etapas_kanban_jornada_uq` no lugar da trava antiga). Etapa de versão já publicada não muda de nome, ordem nem jornada.
- `alunos.jornada_id`: versão em que a matrícula anda. Gatilho `alunos_jornada_t`: matrícula nova nasce na primeira etapa da jornada publicada do produto; o aluno só anda pelas etapas da própria jornada.
- `aluno_historico`: tipo `jornada` (troca de versão), `jornada_id`, `jornada_de`, `por_usuario`.
- `jornada_marcos` (jornada, etapa, nome, descricao, evidencia, prazo_dias, obrigatorio, ordem, `confirmacao` manual/automatico/auto_confirmar, `regra` jsonb) e `aluno_marcos` (aluno, marco, `situacao` atingido/aguardando/recusado, `sinal` observado/declarado/validado, fonte, ref, validado_por/em, observacao).
- `pesquisas`: `etapa_aluno_id`, `produto_id`, `checkin_dias`, `checkin_max`; gatilhos novos `etapa_aluno` e `checkin`. `pesquisa_envios`: `aluno_id` e `ciclo` (trava única passa a ser pesquisa + pessoa + ciclo).
- `alertas.tipo` aceita `cs`. `cs_intervencoes` (aluno, pessoa, alerta, etapa, marco, resposta, tipo, descricao, responsavel, prazo, status aberta/feita/cancelada, resultado, efeito, concluida_em).
- `oportunidades`: `aluno_id`, `origem`; tipos `expansao` e `retencao`. `chaves_api.escopo` aceita `eventos`; `pessoa_toques.origem` aceita `integracao`.
- Funções: `jornada_rascunho`, `jornada_publicar`, `jornada_transferir`, `jornada_salvar_modelo`, `jornada_do_produto`, `jornada_primeira_etapa`, `marco_confirmar`, `marco_retroativo`, `evento_por_chave`, `pesquisa_checkins_gerar`, `cg_verificar_alertas`, `cg_rodar_agendado` (chamada por `growths_rodar_agendado`), `cg_indicadores`. Ajustadas por troca de trecho: `funil_membros`, `funil_analise`, `heavyops_painel` (ordem das etapas dentro da mesma jornada), `pesquisa_enfileira`, `pesquisa_gerar_envios`, `pesquisa_enviar_para`.
- Auditoria ligada em `alunos`, `jornadas`, `jornada_marcos`, `aluno_marcos`, `cs_intervencoes`. `acesso_telas`: `ho-cg`.



## v0.161
Sem mudança no banco: o modelo usa `pesquisas` e `pesquisa_perguntas` (papel `pmf`, `secao`).

## v0.160
- `conteudo_temas.tema_pai_id` (subtema; dois níveis, herda `linha_id` do tema; gatilho `conteudo_tema_valida`).
- `conteudos.subtema_id` (precisa ser subtema do `tema_id`).
- `conteudo_valida`: no método simples, `pauta` em diante exige `tema_id` e `data_publicacao`.

## v0.159
- `content_fichas` (workspace, versão, status rascunho/aprovada, dossie_url, secoes jsonb: narrativa, persona, tom, produtos, diferencial, pilares, nunca; aprovado_por, aprovado_em).
- `content_identidade` (uma por workspace: cores [{nome, hex, papel}], fonte_titulo, fonte_texto, pasta_url, referencias, nunca_fazer, formatos, aprovado_por, aprovado_em).
- `content_versoes` (conteúdo, n, tipo arte/capa/video, arquivo_url, nota, ajuste pedido, status nova/ajuste_pedido/aprovada/substituida, criado_por).
- `conteudos` ganhou `roteiro`, `roteiro_aprovado_por/em`, `peca_aprovada_por/em`, `video_bruto_url`.
- `conteudo_config.metodo` aceita `simples` (padrão). As três tabelas novas: vê quem é do cliente ou da equipe interna; grava quem configura o Growth's Content.

## v0.158
Sem mudança no banco.

## v0.157
- `narrativa_modelos` (codigo NAR-X00 chave, versao, status proposto/aprovado/descontinuado, categoria, evidencia F/C/A/H/R, modelo, campos tirados do texto, ativa_quando, precisa, cor, nao_usar, telas, investigar, observacao, aprovado_por, aprovado_em, criado_em, atualizado_em). Gatilho `narrativa_modelos_regras`: versão, volta para proposto, histórico, sem apagar, código fixo, marcação válida, aprovação com responsável.
- `narrativa_modelos_historico` (codigo, versao, status, modelo, ativa_quando, precisa, cor, nao_usar, aprovado_por, aprovado_em, substituido_em).
- As duas: leitura para usuário logado; escrita só pelo painel (service role).

## v0.156
- `metricas_definicoes` ganhou `unidade` (brl, pct, x, razao, numero, dias, texto), `casas`, `direcao` (maior, menor, faixa, neutra), `zero_limite` (o zero é limite: negativo vermelho, positivo verde) e `referencia` (onde está a meta ou o limite que dá a cor). Linhas novas: `lucro`, `margem`, `roi`, `caixa_projetado`, `ctr`.
- A tela lê o dicionário e usa a direção, as casas e o zero como limite (`semDoDicionario`).

## v0.151
- `content_pesquisas`: workspace, status (fila, lendo, pesquisando, pronto, erro), etapa, erro, relatório (Markdown), fontes da web, arquivos (lidos e não lidos com o motivo, sem o conteúdo), modelo, tokens, buscas, quem pediu, datas.
- `content_dossies`: workspace, pesquisa, versão, status (gerando, rascunho, aprovado, erro), seções [{titulo, texto}], modelo, tokens.
- Os dois: o cliente lê os dele; só o servidor grava.
- `sistema_config`: `ia_modelo_pesquisa`, `content_pesquisa_buscas`, `ia_precos`, `content_dossie_secoes`.
- Marcos usados: `leitura` (relatório lido) e `dossie` (dossiê ok).

## v0.150
- `content_produtos` (id, workspace_id, nome, valor, historico, ativo, ordem, produto_id opcional do cadastro comercial). Lê quem é do cliente ou da equipe interna; grava quem configura o Growth's Content.
- `conteudos.produto_id` passa a apontar para `content_produtos`.
- Saem `content_produto_fichas` e `content_produto_ficha_salvar` (v0.149).
- Respostas novas do questionário em `conteudo_personas.respostas`: `produtos_lista`, `esteira`, `carro_chefe`, `como_vende`, `historico_produtos`.

## v0.149
- `content_produto_fichas` (produto_id, workspace_id, ficha jsonb, atualizado_em, atualizado_por): ficha de conteúdo por produto; o cliente lê a dele; grava só por `content_produto_ficha_salvar(produto, ficha)` (28 campos conhecidos, até 4000 caracteres; momento, papel na escada e nível de consciência validados).
- `conteudos.produto_id` (opcional): a ideia ou pauta é sobre aquele produto.

## v0.148
- Sem mudança no banco. O painel usa `conteudos.status`, `conteudos.data_publicacao` e `conteudo_config.meta_semanal`.

## v0.147
- `content_pastas_mathisa` (padrões da Mathisa): workspace_id (nulo = todos os clientes), nome, pasta_id, url, ativo, criado_por. Só a equipe interna lê e grava.
- Funções: `drive_pasta_id(link)` (id da pasta a partir do link), `content_pasta_mathisa_add(ws, nome, link)`; `content_material_marcar` com 5 tipos (sem "links"); `content_drive_sem_google` sem permissão para a tela.
- As outras pastas do cliente continuam em `workspaces.content_fontes.links` [{url, desc}].

## v0.146
- `content_estruturas` (biblioteca interna): nome (único), para_que, formatos (reels, carrossel, post, stories, video, email), etapas [{nome, instrucao}], instrucoes, ativo, ordem. Só a equipe interna lê e grava.
- `content_estruturas_ws` (escolhas do cliente): workspace, estrutura, formato. O cliente lê as dele; grava só por `content_estruturas_escolher`.
- `ia_uso` (uso de IA): workspace, funcao, modelo, tokens de entrada, saída e cache, buscas, custo_usd, detalhe. Ninguém lê direto.
- `sistema_config`: `custos_emails`, `cambio_usd_brl`.
- Funções: `content_estruturas_opcoes(ws)` (sem etapas nem instruções), `content_estruturas_escolher(ws, escolhas)`, `posso_ver_custos()`, `ia_custos(ini, fim)`, `ia_cambio_salvar(valor)`.

## v0.145
- `workspaces.content_fontes` (jsonb): `canais` {plataforma: @ ou endereço}, `sem_canais`, `materiais` {tipo: {estado ok|nao_tem, em}}, `links` [{url, desc}].
- `sistema_config.content_drive_arvore`: subpastas Documentos, Reuniões gravadas, Aulas e cursos, Depoimentos e provas em "02 Materiais do cliente".
- Funções: `content_fontes_salvar(ws, canais, sem_canais, links)` (plataformas conhecidas, até 300 caracteres, até 30 links http/https), `content_material_marcar(ws, item, estado)` (marca/desmarca o marco `materiais` sozinho); `content_setup_estado` devolve `fontes`.

## v0.144
- `workspaces.content_drive_modo` aceita também `compartilhada` (pasta do Drive do cliente compartilhada com a Mathisa).
- `workspaces.content_setup_marcos` (jsonb): marcos da configuração com data (`materiais`, `leitura`, `tese`, `dossie`).
- `sistema_config`: `drive_script_email` (com quem compartilhar) e `content_drive_arvore` preenchida com a árvore padrão.
- Respostas da call ficam em `conteudo_personas.respostas` (mais `_call_data` e `_call_notas`).
- Funções: `content_drive_compartilhar(ws, link)` (aceita link `/folders/ID`, `?id=` ou só o ID), `content_setup_marcar(ws, marco, feito)`; `content_drive_tentar` mantém o modo da pasta; `content_setup_estado` devolve `marcos` e `drive.compartilhar_com`.

## v0.143
- `workspaces`: `content_setup_etapa`, `content_setup_em` (configuração concluída), `content_drive_modo` (cliente | mathisa), `content_drive_email`.
- `content_google` (conta Google do cliente: e-mail, token de acesso contínuo, escopos; só o servidor lê) e `content_google_estados` (logins em andamento, 15 min).
- `conteudo_backups` (cópia de segurança de configurações removidas; só o servidor lê).
- Funções: `content_pode_configurar`, `content_setup_estado`, `content_setup_salvar(ws, etapa, concluir, reabrir)`, `content_drive_sem_google`; `content_drive_tentar` passa a valer para quem configura (modo Mathisa). O gatilho que criava a pasta ao ligar o módulo foi removido.


## v0.142
- Sem mudança no banco. Dado corrigido: cliente "Teste Growth's Content" (modo completo e acesso ao Growth's Content).


## v0.141
- `acesso_telas`: `mkt-cont` (Estratégia de conteúdo) e `mkt-insta` (Instagram) no grupo "Marketing / Growth's Content"; `crm-dms` (DMs do Instagram) em Vendas.
- Funções: `content_no_acesso(pacote, liga, desliga)`; gatilho `content_acesso_t` (antes de gravar o cliente) liga ou desliga `content_ativo` pelo acesso; `content_ws_t` passa a disparar em qualquer alteração do cliente.


## v0.140
- `workspaces`: `content_ativo` (usa o Growth's Content), `content_drive_id`, `content_drive_url`, `content_drive_status` (criando | ok | erro), `content_drive_erro`, `content_drive_em`.
- `sistema_config`: `content_drive_raiz` (pasta "Mathisa Growth's Content"), `content_drive_arvore` (JSON com os caminhos das subpastas), `content_drive_url` e `content_drive_token` (função), `drive_script_url` e `drive_script_senha` (Apps Script).
- Funções: `content_definir(ws, ativo)`, `content_drive_tentar(ws)`, `content_clientes()` (equipe interna); `content_minha_pasta(ws)` (quem pertence ao cliente); `content_drive_pedir(ws)` e o gatilho `content_ws_t` (internos).


## v0.139
- Sem mudança no banco. A tela passa a ler `social_conversas.primeira_em` do período (até 2 dias depois do fim) para o insight de DMs.


## v0.138
- Sem mudança no banco.


## v0.137
- Sem mudança no banco. A galeria usa `social_posts.miniatura` (já trazida pelo `zernio-sync` e devolvida por `instagram_dashboard`).


## v0.136
- `social_posts.tema_id` (frente, `conteudo_temas`) e `social_posts.formato_id` (`conteudo_formatos`, grupo formato): classificação do post sem conteúdo da Máquina. Pela tela, quem edita Marketing altera só essas duas e `conteudo_id`/`vinculo`. O gatilho `social_posts_valida` confere que frente e formato são do mesmo cliente.
- `instagram_dashboard(ws, ini, fim)`: cada post traz `post_tema` e `post_formato`; frente, território e formato saem do conteúdo da Máquina e, sem ele, da classificação do post. `seguidores` ganhou `ganhos`, `ganhos_antes` e `alcance_conta_antes` (período anterior).


## v0.135
- `social_conversas` (1 por conversa do Instagram): `conta_id`, `id_externo`, participante (`participante_id`, `participante_nome`, `participante_usuario`), `url`, `ultima_mensagem`, `ultima_em`, `nao_lidas`, `primeira_em`, contagens (`mensagens`, `recebidas`, `enviadas`), `anuncio` (conversa iniciada por anúncio), `pessoa_id` (lead no CRM), `ignorada` ("não é lead"). Leitura: Marketing, Vendas e Administrativo; pela tela só se altera `ignorada`.
- `social_mensagens`: `conversa_id`, `id_externo`, `direcao` (recebida/enviada), `texto`, `anexos`, `em`.
- Funções: `social_gravar_dms(conta, conversas)` e `social_conversas_conhecidas(conta)` (só a chave de serviço), `instagram_dms_resumo(ws, ini, fim)`.
- `conteudo_temas.canais_padrao text[]`; `conteudo_config.canais_por_tag jsonb` ({etiqueta: [canais]}) e `canais_ativos text[]` (padrão instagram).

## v0.134
- `social_posts`: `conta_id` passa a aceitar vazio (post importado); novas colunas `origem` ('api' | 'importado'), `rede` (padrão 'instagram'), `conteudo_id` (ligação com a Máquina), `vinculo` ('manual' | 'automatico'), `seguidores_ganhos`. Índice único (cliente, rede, id_externo) para os importados. Pela tela só se altera `conteudo_id` e `vinculo` (quem edita Marketing); gatilho confere que o conteúdo é do mesmo cliente.
- Funções: `social_importar_posts(ws, itens jsonb)` (tudo ou nada, até 2.000), `social_vincular_auto(ws)`, `instagram_dashboard(ws, ini, fim)` → `periodo`, `fontes`, `totais`, `anterior`, `seguidores` (fim, início, antes, alcance e visitas da conta), `serie` por dia e `posts` (métricas, engajamento, conteúdo ligado com território, frente, formato, quadro, destino, etiquetas e score).
- Dados da conta por dia: `social_perfis_dia` (Meta) e, sem ela, `conteudo_conta_dia` canal instagram (importado na tela).

## v0.133
- `conteudo_config` +: `metodo` ('notas5' | 'score6'), `criterios_score text[6]`, `destinos text[]`, `meta_semanal`, `dia_fechamento` (1 = segunda … 7 = domingo; padrão 6, sábado), `tags text[]` (sugestões), `linha jsonb` (núcleo da marca: papel, tese, síntese, visão, inimigo, frase-guia, estruturas, lentes, frases), `modelo`.
- `conteudo_linhas` (= territórios) +: `pergunta_central`, `funcao`, `papel_funil`, `entra`, `nao_entra`, `cor`. `conteudo_temas` (= frentes) +: `descricao`, `transversal` (camada transversal).
- `conteudo_formatos` (nova): `grupo` ('formato' | 'quadro'), `nome`, `funcao`, `execucao`, `melhor_uso`, `estrutura`, `tipo_midia`, `vezes_semana`, `dias_semana`, `cor`, `ordem`, `ativo`. Único por cliente, grupo e nome.
- `conteudos` +: `formato_id`, `quadro_id`, `destino`, `palavra_chave`, `palavras_relacionadas[]`, `perguntas_busca[]`, `intencao`, `entidade`, `problema`, `achado`, `classificacao` (evidência/tendência/discussão/hype), `fundamento`, `evidencia`, `s1`…`s6` (1 a 5), `score_total` (gerada, 6 a 30), `score_notas`, `tags[]`, `dia_semana`, `validado`, `validado_em`, `hook`, `tese`, `cta`, `objetivo`, `estrutura`, `estrutura_notas jsonb`, `obs_producao`, `decisao` (manter/aprofundar/testar/descartar), `aprendizado`.
- `conteudo_fechamentos` (nova, 1 por cliente e semana): `semana_ini` (segunda), `resumo jsonb` (foto de `conteudo_semana`), `retro jsonb`, `objetivo_proxima`, `pre_pauta`, `fechado_por`.
- `conteudo_personas` (nova): `respostas jsonb` do questionário. `conteudo_linha_propostas` (nova): `origem` (ia/colada/modelo), `modelo_ia`, `proposta jsonb` (mesmo formato do modelo V18), `status` (proposta/aplicada/descartada).
- Funções: `conteudo_valida` (gatilho, agora por método), `conteudo_modelo_v18()`, `conteudo_aplicar_linha(ws, jsonb, modelo)`, `conteudo_instalar_v18(ws)`, `conteudo_aplicar_proposta(id)`, `conteudo_semana(ws, segunda)`, `conteudo_fechar_semana(ws, segunda, retro, objetivo, pre_pauta)`. Tabelas novas com RLS do cliente + regra de módulo (Marketing edita; Marketing e Administrativo leem).

## v0.132
- `alertas_config` (1 por cliente): `ligado`, `resumo_diario`, `resumo_hora`, `regras jsonb` (`variacao_pct`, `desvios`, `dias_seguidos`, `gasto_sem_lead`, `desligadas[]`), `destinatarios uuid[]` (vazio = equipe com acesso).
- `alertas`: `chave` única por cliente (não repete), `tipo` (brusco/repetido/operacional), `regra`, `severidade` (alta/media/info), `titulo`, `mensagem`, `dados`, `dia`, `visto_em`, `resolvido_em`.
- `resumos_diarios` (cliente + dia): `fatos jsonb`, `texto`, `avisado_em`.
- `sistema_config` (sem acesso pelo sistema): `avisos_token`, `avisos_url` para o agendador chamar a função `avisos`.
- `notificacoes`: novos tipos `alerta`, `resumo`, `teste` (mesma fila e canais).
- Funções: `growths_serie(ws, ini, fim)`, `growths_fatos_dia(ws, dia)`, `growths_verificar_alertas(ws, ref, avisar)`, `growths_resumo_gerar(ws, dia, avisar)`, `growths_resumo_texto(fatos)`, `growths_ia_extra(ws, ini, fim)`, `growths_aviso_teste(ws)`, `growths_avisar` (interna), `growths_rodar_agendado(ref)` (só o banco). **Pendente em produção.**

## v0.131
- Sem mudança no banco. Leituras novas: `pesquisa_respostas` (com `contato`) + `pesquisa_resposta_itens` + `pessoas` (qualificação, pontuação, tags) na aba Quem respondeu.

## v0.130
- `pesquisas.visual jsonb`: `{marca, titulo, logo_url, fonte_titulo, fonte_texto, cor_primaria, cor_fundo, cor_cartao, cor_texto, raio, botao, enviar}`.
- `pesquisas.captacao jsonb`: `{ativa, campos: {telefone: {mostrar, obrig, rotulo}, instagram: {...}}, etapa_id, tags, responsavel_id, passo_contato, passo_final, aviso_titulo, aviso_texto, consentimentos: [{texto, obrig}], nota_final, sucesso_titulo, sucesso_texto}`.
- `pesquisa_perguntas.secao text`: passo do formulário.
- `pesquisa_respostas.contato jsonb`, `consentimentos jsonb` (`[{texto, aceito}]`), `utm jsonb`, `novo_contato boolean`.
- Funções: `pesquisa_captar(token, respostas, contato, extra)` (anon e autenticado), `pesquisa_registrar(...)` (interna); `pesquisa_responder` e `pesquisa_publica` reescritas (a pública devolve `visual`, `captacao` sem etapa/tags/responsável e a `secao` de cada pergunta).
- Grava em `pessoas` (colunas que já existiam): nome, email, telefone, utm_*, pagina_origem, referrer, canal_origem, etapa_kanban_id, tags, responsavel_comercial_id, `extras.instagram/formulario/consentimentos/consentimento_em`; e uma linha em `pessoa_historico` (campo "formulario"). Aplicado em produção em 21/10/2026.

## v0.129
- `pesquisas.qualif jsonb`: `{ativa, modo: "soma"|"media", corte, faixas: [{min, tag}]}`.
- `pesquisa_perguntas.pontos jsonb`: `{opcoes: {"<opção>": {p, tag}}}` ou `{peso}`.
- Funções `pesquisa_qualificar(uuid)`, `pesquisa_requalificar(uuid)`; `pesquisa_responder` chama a primeira.
- Grava em `pessoas.pontuacao_qualificacao`, `pessoas.qualificacao` e `pessoas.tags` (colunas que já existiam). Aplicado em produção em 21/10/2026.

## v0.128
- Sem mudança no banco. Leituras: `v_trafego_anuncio_dia` da campanha, `vendas` da campanha com `produtos` e `ofertas`, `campanha_meta_leads`.

## v0.127
- Nova coluna (pendente em produção): `empresa.saldo_minimo numeric` (≥ 0 ou vazio). Migração `20261025100000_saldo_minimo.sql`.
- Leituras novas: `ofertas` (papel) com `vendas.oferta_id`; `planos` + `planejamento_mensal` + `vendas`/`pessoas` (plano no tempo); `gm_cenarios` aprovados (`resultados`).

## v0.126
- Sem mudança no banco. Leituras novas: `checkout_abandonos` (abandono no tempo); `growth_experimentos` (impacto, confiança, facilidade, valor_base, valor_resultado); `vendas` por campanha (burn-up) e de todo o workspace com `contratos.ativado_em` (novos × existentes); `arvore_serie` dos nós `mkt.ads`, `mkt.cpl` e `mkt.cac`.

## v0.125
- Sem mudança no banco. Leituras novas: `movimentacoes_bancarias` + `contas_bancarias.tipo` (resultado × banco); `contas_receber`/`contas_pagar` em aberto (vencimentos); `contratos` + `contrato_itens` (MRR mês a mês); `painel_gerencial` do período anterior (observações); `funil_cohorts` por campanha e `campanhas.meta_cac` (dispersão).

## v0.124
- Sem mudança no banco. Leituras novas: `planejamento_mensal` (metas do mês) no Dashboard; `arvore_no` com `ven.soma` (quebras por produto e campanha) e `fin.lucro` (fórmula) para os gráficos.

## v0.123
- `arvore_serie(p_ws uuid, p_no text, p_par jsonb, p_gran text)` → lista de pontos `{ini, fim, valor, un, parcial}`. Usa `arvore_no` para cada ponto (mesmas permissões; segurança do chamador).
