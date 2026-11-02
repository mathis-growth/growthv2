## v0.240
Sem mudança no banco.

## v0.239
Sem mudança no banco.

## v0.238
Sem mudança no banco.

## v0.237
Rodar `supabase/RODAR_v0.237_anexos_diagnostico_mathisa.sql`. Só muda a configuração da pergunta de arquivos do "Diagnóstico Mathisa (pré-diagnóstico)"; pode rodar de novo.

## v0.236
Rodar `supabase/RODAR_v0.236_diagnostico_reabrir.sql`. Cria `diagnostico_formulario_reabrir` e troca o gatilho que liga a resposta ao diagnóstico (a mais nova passa a valer).

## v0.235
Sem mudança no banco. Mudou a configuração do site (`_headers` e `_redirects`): o Cloudflare Pages aplica ao publicar.

## v0.234
Sem mudança no banco.

## v0.233
1. `supabase/RODAR_v0.233_qualificacao_blocos.sql`: troca a função que pontua (as regras antigas funcionam igual) e cria `pesquisa_respostas.qualif_det`.
2. `supabase/RODAR_v0.233b_formulario_qualificacao_mathisa.sql`: monta o formulário "Lead: qualificação" da Mathisa. Troca as perguntas, por isso só roda se o formulário ainda não tiver respostas (hoje não tem).

## v0.232
Rodar `supabase/RODAR_v0.232_corrige_link_formulario.sql`. Só troca a função `diagnostico_formulario`; pode rodar logo, antes da 0.231 se quiser: é o que destrava o link do formulário.
O `RODAR_v0.228` também foi corrigido (para instalações novas).

## v0.231
Rodar `supabase/RODAR_v0.231_clientes_contrato.sql` depois do `RODAR_v0.230`. Nenhum produto vem marcado "inclui o Growths": marque em Produtos os que incluem. Nenhum cliente é inativado.
Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 → 0.227 → 0.228 → 0.229 → 0.230 → 0.231 (e os antigos 0.197 e 0.209).

## v0.230
Rodar `supabase/RODAR_v0.230_formulario_cliente.sql` depois do `RODAR_v0.229`. Os formulários que já existem continuam como "lead".
Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 → 0.227 → 0.228 → 0.229 → 0.230 (e os antigos 0.197 e 0.209).

## v0.229
Rodar `supabase/RODAR_v0.229_diagnostico_saber.sql` depois do `RODAR_v0.228`.
Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 → 0.227 → 0.228 → 0.229 (e os antigos 0.197 e 0.209).

## v0.228
Rodar `supabase/RODAR_v0.228_diagnostico_processo.sql` depois do `RODAR_v0.227`.
Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 → 0.227 → 0.228 (e os antigos 0.197 e 0.209).
Depois, em Pesquisas, crie o formulário a partir do modelo "Diagnóstico Mathisa (pré-diagnóstico)", ative e marque como padrão (na aba Formulário do diagnóstico).

## v0.227
Rodar `supabase/RODAR_v0.227_diagnostico_planilhas.sql` depois do `RODAR_v0.225`. Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 → 0.227 (e os antigos 0.197 e 0.209).

## v0.226
Nada para rodar no banco. Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 (e os antigos 0.197, 0.209).

## v0.225
Rodar `supabase/RODAR_v0.225_diagnostico_depara.sql` depois do `RODAR_v0.224`. Muda só o catálogo de métricas (coluna `requisitos`) e cria funções.
Ordem pendente: 0.221 → 0.223 → 0.224 → 0.225 (e os antigos 0.197, 0.209).

## v0.224
Rodar `supabase/RODAR_v0.224_diagnostico_pre.sql` depois do `RODAR_v0.223`. Só funções; nenhum dado muda.
Ordem pendente: 0.221 → 0.223 → 0.224 (e os antigos 0.197, 0.209).

## v0.223
Rodar `supabase/RODAR_v0.223_diagnostico_evidencias.sql` no SQL Editor do Supabase (depois do `RODAR_v0.221`). Aditivo: nada é apagado. O diagnóstico que já existe ganha o título "Diagnóstico de <cliente>".
Continua pendente: `RODAR_v0.221` (e os antigos `RODAR_v0.197`, `RODAR_v0.209`).

## v0.222
Nada para rodar no banco. Pendente em produção: `RODAR_v0.221` (e os antigos `RODAR_v0.197`, `RODAR_v0.209`).

## v0.221 — Growth's Brain: metas das áreas
1. `supabase/RODAR_v0.221_brain_metas_areas.sql`: métricas de nível no registro (margem, caixa, churn, retenção 90 dias, LTV, ascensão, North Star), `metas_avaliar_nivel`, `metas_niveis`, `metas_nivel_salvar`, espelhos e o Risk Engine com metas de nível.
2. **Mexe em dados de produção (sem apagar):** copia para o registro as metas do Customer Success (`heavyops_metas`), o saldo mínimo (`empresa.saldo_minimo`) e a meta da North Star (`growth_metricas.meta`), como metas de 2026.
3. Conferido em 01/11: v0.213 a v0.220 já estão em produção. Pendentes: `RODAR_v0.221` (e os antigos `RODAR_v0.197`, `RODAR_v0.209`).

## v0.220 — Growth's Brain: acerto da projeção
1. `supabase/RODAR_v0.220_brain_calibracao.sql`: funções de leitura `projecao_backtest`, `projecao_faixa`, `projecao_fotos`. Não mexe em dados.
2. Pendentes em produção, nesta ordem: `RODAR_v0.216`, `0.217`, `0.218`, `0.219`, `0.220` (e os antigos `RODAR_v0.197`, `RODAR_v0.209`).

## v0.219 — Growth's Brain: funil AARRR
1. `supabase/RODAR_v0.219_brain_aarrr.sql`: funções de leitura `aarrr_numeros` e `aarrr_painel`. Não mexe em dados.
2. Pendentes em produção, nesta ordem: `RODAR_v0.216`, `RODAR_v0.217`, `RODAR_v0.218`, `RODAR_v0.219` (e os antigos `RODAR_v0.197`, `RODAR_v0.209`).

## v0.218 — Growth's Brain: cenários ligados à meta
1. `supabase/RODAR_v0.218_brain_cenarios.sql`: tabela `metas_cenarios` e função `metas_simular` (só leitura). Não mexe em dados existentes.
2. Pendentes em produção: `RODAR_v0.197`, `RODAR_v0.209` (versão da v0.210), `RODAR_v0.216`, `RODAR_v0.217`, `RODAR_v0.218`, nesta ordem.

## v0.217 — Growth's Brain: investigação
1. `supabase/RODAR_v0.217_brain_investigar.sql`: funções de leitura `investigar`, `investigar_registros` (e as auxiliares `investigar_linhas`, `investigar_passa`). Não mexe em dados.
2. Pendentes em produção: `RODAR_v0.197`, `RODAR_v0.209` (versão da v0.210), `RODAR_v0.216`, `RODAR_v0.217`.

## v0.216 — Growth's Brain: trajetória das metas
1. `supabase/RODAR_v0.216_brain_trajetoria.sql`: função `metas_trajetoria` (só leitura) e correção do impacto dos riscos de qualidade (gatilho `riscos_qualidade_sem_impacto`).
2. Conferido em 01/11: v0.213, v0.214 e v0.215 já estão em produção. Pendentes: `RODAR_v0.197`, `RODAR_v0.209` (versão da v0.210) e `RODAR_v0.216`.

## v0.215 — Growth's Brain: Risk Engine
1. `supabase/RODAR_v0.215_brain_riscos.sql`: tabelas `riscos`, `riscos_eventos` (histórico) e `riscos_rodadas`; funções `riscos_detectar`, `riscos_painel`, `riscos_acao`, `riscos_rodar`; cron `growths-riscos` (08:17).
2. Não mexe em dados existentes. A primeira conferência acontece quando alguém abre o Cockpit (ou às 08:17).
3. Pode rodar de novo sem erro. Pendentes em produção: `RODAR_v0.197`, `RODAR_v0.209` (versão da v0.210), `RODAR_v0.214`, `RODAR_v0.215`.

## v0.214 — Growth's Brain: leads, vendas, campanhas e produtos nas metas
1. `supabase/RODAR_v0.214_brain_metas_2.sql`: leads e vendas no registro de metas; metas das campanhas no registro (espelho de mão única: a campanha continua sendo o lugar de editar); metas por produto; avaliação por séries diárias (`metas_serie`, `metas_realizado_dia`), `metas_recortes`; `metas_painel` devolve faturamento, leads, vendas e os recortes; foto diária com escopo.
2. **Mexe em dados de produção (sem apagar nada):** copia para `metas` as metas de leads e vendas do planejamento mensal (hoje vazio) e as metas de leads, vendas e receita das campanhas que têm meta. Em `metas_fotos`, a chave primária vira um índice único com o escopo (as fotos antigas ficam).
3. Pode rodar de novo sem erro. Pendentes em produção: `RODAR_v0.197`, `RODAR_v0.209` (versão da v0.210), `RODAR_v0.214`.

## v0.213 — Growth's Brain: metas num lugar só (faturamento)
1. `supabase/RODAR_v0.213_brain_metas.sql`: cria o registro central `metas` (com histórico de versões), `metas_regras`, `metas_fotos`, as funções `metas_avaliar`, `metas_painel`, `metas_consistencia`, `metas_fotografar`, o status da NSM (`growth_metricas.nsm_status` + `nsm_historico`) e os objetivos do ano (`plano_objetivos.ano`). Agenda a foto diária (`growths-metas-foto`, 23:53).
2. **Mexe em dados de produção (sem apagar nada):** copia para `metas` a meta do ano que já existe (`plano_anual`) e as metas de receita dos meses (`planejamento_mensal`, hoje vazio); marca como "provisória" as North Stars que existem; inclui "faturamento" no dicionário.
3. Pode rodar de novo sem erro. Sem ele, o Cockpit e o Planejamento anual continuam como antes (a faixa de meta e os objetivos só aparecem depois).
4. Pendentes em produção, nesta ordem: `RODAR_v0.197`, `RODAR_v0.208`, `RODAR_v0.209` (versão da v0.210), `RODAR_v0.213`.

## v0.212
Nada para rodar no banco. Continuam pendentes em produção: `RODAR_v0.197`, `RODAR_v0.208`, `RODAR_v0.209` (versão da v0.210).

## v0.211
Nada para rodar no banco.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.210
1. `supabase/RODAR_v0.209_financeiro_simplificado.sql` foi **atualizado** (parceiros e comissões por produto; Financeiro simplificado dentro do Go-to-Market, sem pacote à parte). Ainda não tinha sido aplicado em produção: rode a versão desta entrega. Pode rodar de novo sem erro.
2. Ordem dos pendentes: `RODAR_v0.197`, `v0.198`, `v0.205`, `v0.206`, `v0.208`, `v0.209`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.209 — Financeiro simplificado
1. `supabase/RODAR_v0.209_financeiro_simplificado.sql`: grupo nos custos (marketing ou operacional), `parceiros_comissao`, `mkt_custos_mes` com os dois grupos, `dre_simplificado`, a tela `adm-financeiro` e o pacote **Financeiro simplificado**. **Depende do v0.205 e do v0.206.** Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Ordem dos pendentes: `RODAR_v0.197`, `v0.198`, `v0.205`, `v0.206`, `v0.208`, `v0.209`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.208 — Dashboard de vendas
1. `supabase/RODAR_v0.208_vendas_periodo.sql`: função `vendas_periodo` (números do período e do período anterior). **Depende do RODAR_v0.206.** Sem ele, o dashboard avisa e mostra os números de sempre. **Ainda não aplicado em produção.**
2. Ordem dos pendentes: `RODAR_v0.197`, `v0.198`, `v0.205`, `v0.206`, `v0.208`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.207
Nada para rodar no banco. Lembrete: o pacote Go-to-Market só aparece no cadastro do cliente depois de rodar `RODAR_v0.205_go_to_market.sql` (hoje, em produção, os pacotes são Disparo, Mentoria, Casa e Consultoria).

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.206 — Histórico de vendas
1. `supabase/RODAR_v0.206_historico_vendas.sql`: tabelas `importacoes_historico` e `vendas_historicas`, a visão `v_vendas_todas`, as funções `importar_historico_vendas` e `desfazer_importacao_historico`, e refaz `plano_anual_sugestoes` para somar o histórico. **Depende do RODAR_v0.198.** Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Ordem dos pendentes: `RODAR_v0.197`, `RODAR_v0.198`, `RODAR_v0.205`, `RODAR_v0.206`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.205 — Pacote Go-to-Market e Custos de marketing
1. `supabase/RODAR_v0.205_go_to_market.sql`: tela "Custos de marketing" no catálogo, o pacote **Go-to-Market**, as tabelas `mkt_custos_*`, as funções `mkt_resultado`, `vendas_por_plataforma`, `mkt_custos_fechar`, `mkt_custos_reabrir`, `mkt_custos_rodar` e a rotina diária `growths-custos-marketing` (pg_cron, 08:07 de Brasília). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`, `RODAR_v0.205_go_to_market.sql`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.204
Nada para rodar no banco (usa `pesquisas.visual`, que já existe desde a v0.130).

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.203
Nada para rodar no banco.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.202
Nada para rodar no banco.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.201 — Entrada do cliente
Nada para rodar no banco: usa as tabelas e o envio de arquivos do Diagnóstico 360° (v0.176/0.177), já em produção. Pendentes continuam: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.200 — Planejar outro ano
1. `supabase/RODAR_v0.198_plano_anual.sql` foi **atualizado de novo**: ao planejar o ano que vem com o ano anterior ainda aberto, a receita sugerida é a dos últimos 12 meses fechados. Sem tabela nova; pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.199 — Impostos e custos variáveis na meta do ano
1. `supabase/RODAR_v0.198_plano_anual.sql` foi **atualizado**: a função `plano_anual_sugestoes` agora devolve `custos_variaveis_pct` e `imposto_hist_pct`, e os custos fixos não contam mais as comissões. Não há tabela nova. Pode rodar de novo sem erro. **Ainda não aplicado em produção** (rode este arquivo, já com a mudança).
2. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.198 — Planejamento anual (meta do ano)
1. `supabase/RODAR_v0.198_plano_anual.sql`: cria `plano_anual` (caminho, premissas com a origem, cenários, meta escolhida) e a função `plano_anual_sugestoes` (o que o Growths já sabe do cliente). Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, a tela Planejamento anual avisa e as metas mês a mês continuam funcionando.
3. Ordem dos pendentes: `RODAR_v0.197_pesquisa_modelos.sql`, `RODAR_v0.198_plano_anual.sql`.

## v0.197 — Modelos de pesquisa fora da lista
1. `supabase/RODAR_v0.197_pesquisa_modelos.sql`: cria `pesquisa_modelos_ocultos` (cliente + modelo) com acesso por cliente. Pode rodar de novo sem erro. **Ainda não aplicado em produção.**
2. Sem ele, tirar um modelo da lista vale só no navegador de quem tirou (a tela avisa).

## v0.196
Nada a rodar no banco (só tela). O lado de cada ligação fica em `estrategia_blocos.props.lados` do bloco de origem.

## v0.195
Nada a rodar no banco (só tela). Os blocos novos usam `estrategia_blocos.tipo` = `order_bump` e `downsell` (o campo aceita qualquer texto).

## v0.194
Nada a rodar no banco (só tela).

## v0.193
Nada a rodar no banco (só tela). A escolha da pesquisa fica em `campanhas.extras` (coluna que já existe).

## v0.192
Nada a rodar no banco (só tela).

## v0.191
Nada a rodar no banco (só tela). Continuam pendentes os SQL da v0.157, v0.159 e v0.160.

## v0.179 — Instagram OAuth direto (pendente de publicação)
1. Aplicar `supabase/migrations/20261031020000_instagram_oauth_direto.sql` após v0.178; conferir `conexoes.zernio_profile_id` e a existência de `privado.conexao_estados`.
2. Publicar a nova Edge Function `instagram-oauth` **sem verificação automática de JWT** para permitir o callback GET. A função valida o JWT explicitamente no POST de início.
3. Usar o Secret já existente `ZERNIO_API_KEY`. Não acrescentar chave no workspace e não substituir a Edge `atendimento`.
4. Publicar `assets/atendimento.js`, abrir Cliente → Configurações → Integrações → **Conectar Instagram** e autorizar uma conta profissional. Verificar vínculos nas tabelas `conexoes`, `conexao_contas` e `atd_canais` do mesmo workspace.
5. Testar: cliente sem permissão, estado expirado/reutilizado, cancelamento OAuth, conta em outro workspace, retorno de perfil divergente e reconexão da conta Mathisa. Os botões de Atendimento permanecem para sincronização de conversas e ativação de webhook.

## v0.178 — Conexão Zernio por cliente (ainda não publicada)
1. Exige a Central de Atendimento v0.175 no banco.
2. Aplicar `supabase/migrations/20261030220000_zernio_cliente.sql` no banco correto.
3. Publicar a Edge Function `atendimento` e a interface atualizada, mantendo `ZERNIO_API_KEY` em Secrets.
4. Selecionar cliente → Configurações → Integrações → Zernio → Vincular conta. Depois Atendimento → Canais e conexões → Adicionar conta.
5. Testar isolamento entre clientes, conta já vinculada, credenciais ausentes e WhatsApp oficial.



## v0.163 — Customer Growth
**Situação em 29/10/2026:** as migrações 20261116100000 a 20261123100000 foram aplicadas em produção pelo conector (registradas como `v0163_1` a `v0163_8`). A última (`RODAR_v0.163_contencao_alertas.sql`) desliga os alertas de CS (`sistema_config.cg_alertas = 'nao'`), apaga esse acúmulo e tira os alertas de CS do resumo e do "Pergunte ao Growths".
Quando a tela RevOps → Customer Growth estiver no ar: `select cg_ligar_alertas();` (registra o que já acontece sem avisar ninguém e liga). **Feito em 29/10/2026**, com a v0.163 no ar: 824 alertas abertos (340 parados, 484 sem CS) em Escola Aurora, Growths — Demo e Mathisa — Operação, sem aviso enviado.
1. Confira antes que a v0.132 (alertas e agendador) está aplicada: o arquivo verifica e para com uma mensagem se faltar algo, sem gravar nada.
2. `supabase/RODAR_v0.163_customer_growth.sql` no SQL Editor do Supabase: é tudo ou nada e pode ser rodado de novo. **Ainda não aplicado em produção.**
3. Publicar de novo a edge function `leads` (sem verificação de JWT) para receber eventos da plataforma do curso: `supabase functions deploy leads --no-verify-jwt`. **Feito em 29/10/2026** (versão 6, pelo conector).
4. Sem o SQL, as telas novas avisam que falta a atualização do banco e o resto do Growths continua igual.

## v0.161
Nada a rodar no banco (só tela). Continuam pendentes os SQL da v0.157, v0.159 e v0.160.

## v0.160 — Subtemas e datas no Kanban
1. `supabase/RODAR_v0.160_content_segmentos.sql` (depois do da v0.159): subtemas (`conteudo_temas.tema_pai_id`), `conteudos.subtema_id`, gatilho `conteudo_tema_valida` e a regra nova em `conteudo_valida` (no método simples, aprovar a ideia exige tema e data de publicação). **Ainda não aplicado em produção.**
2. Ordem para rodar: `RODAR_v0.157_narrativas.sql`, `RODAR_v0.159_content_simples.sql`, `RODAR_v0.160_content_segmentos.sql`.

## v0.159 — Growth's Content simplificado
1. `supabase/RODAR_v0.159_content_simples.sql`: cria `content_fichas`, `content_identidade`, `content_versoes`; colunas de roteiro, aprovação da peça e vídeo bruto em `conteudos`; método "simples" em `conteudo_config` (vira o padrão e é aplicado às configurações existentes); regra nova em `conteudo_valida`. **Ainda não aplicado em produção.** Em 26/10/2026 a produção tinha 1 configuração (score6) e nenhum conteúdo.
2. Sem ele, as abas novas avisam que falta a atualização do banco; Mais ferramentas continua funcionando.

## v0.158
Nada a rodar no banco (só tela). Continua pendente o `RODAR_v0.157_narrativas.sql`.

## v0.157 — Banco de narrativas
1. `supabase/RODAR_v0.157_narrativas.sql`: cria `narrativa_modelos` e `narrativa_modelos_historico`, a regra de versão (gatilho `narrativa_modelos_regras`) e os 39 modelos (9 aprovados). **Ainda não aplicado em produção**: a aplicação pelo conector foi cancelada em 26/10/2026. Rodar no SQL Editor do Supabase ou autorizar de novo.
2. Sem a tabela, a tela continua funcionando: as frases do piloto não aparecem e o Dicionário avisa que falta a atualização.
3. Para mudar um texto: editar a linha em `narrativa_modelos` (Table Editor ou SQL). A versão sobe sozinha, a anterior vai para o histórico e o modelo volta para "proposto"; para aprovar, `status = 'aprovado'` e `aprovado_por` preenchido.

## v0.152 a v0.156 — Data Storytelling
1. `supabase/RODAR_v0.156_metricas_semantica.sql` (aplicado em produção em 26/10/2026): colunas `unidade`, `casas`, `direcao`, `zero_limite` e `referencia` em `metricas_definicoes` e as linhas novas Lucro, Margem, ROI, Caixa projetado e CTR.
2. As versões 0.152 a 0.155 são só tela.

## v0.151 — Pesquisa e dossiê
1. `supabase/RODAR_v0.151_content_pesquisa.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-pesquisa --no-verify-jwt` (publicada em 25/10/2026, versão 2; o GET diz só se os segredos existem).
3. Segredo `ANTHROPIC_API_KEY` (Supabase → Edge Functions → Secrets), com a chave criada em console.anthropic.com. Sem ele, a tela avisa e o botão fica desligado.
4. Apps Script: colar o código novo de `integracoes/apps-script/growths-drive.gs` (com a senha real) e reimplantar como nova versão. Ele pede de novo a autorização da conta (agora lê Documentos, Planilhas e Apresentações).
5. Opcional: `sistema_config.ia_precos` com o preço por milhão de tokens do modelo e por mil buscas, para o custo ser calculado; vazio = "sem custo calculado".

## v0.150 — Ficha de produto simples
1. `supabase/RODAR_v0.150_content_produtos_v2.sql` (aplicado em produção em 25/10/2026). Tira a ficha longa da v0.149 (sem nenhum dado) e cria `content_produtos`.

## v0.149 — Ficha de conteúdo dos produtos
1. `supabase/RODAR_v0.149_content_produtos.sql` (aplicado em produção em 25/10/2026).

## v0.148
Nada a rodar no banco.

## v0.147 — Só a pasta do cliente; pastas da Mathisa
1. `supabase/RODAR_v0.147_content_pastas.sql` (aplicado em produção em 25/10/2026).
2. As pastas da Mathisa precisam estar no Drive de rebecka@rebeckacappello.com.br (a conta que roda o Apps Script) ou compartilhadas com ela.

## v0.146 — Estruturas de roteiro e copy; custos de IA
1. `supabase/RODAR_v0.146_content_estruturas.sql` (aplicado em produção em 25/10/2026 pela Rebecka, no SQL Editor; a ferramenta de migração estava sem permissão de escrita).
2. Quem vê os custos: `sistema_config.custos_emails` (e-mails separados por vírgula; hoje só rebecka@rebeckacappello.com.br). Precisa também ser da equipe interna.
3. Câmbio: na própria tela Custos de IA (fica em `sistema_config.cambio_usd_brl`; vazio = só em dólar).

## v0.145 — Canais e materiais do cliente
1. `supabase/RODAR_v0.145_content_fontes.sql` (aplicado em produção em 25/10/2026).
2. Nada a publicar nas funções. A árvore nova vale para as próximas pastas; nas que já existem, "Completar as pastas" cria as subpastas que faltam.

## v0.144 — Configuração em 8 passos e pasta compartilhada
1. `supabase/RODAR_v0.144_content_setup_v2.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-drive --no-verify-jwt` (publicada em 25/10/2026, versão 5).
3. Nada mais a configurar: a pasta compartilhada usa o Apps Script da v0.140 (gratuito). `sistema_config.drive_script_email` é o e-mail com quem o cliente compartilha a pasta.

## v0.143 — Configuração passo a passo
1. `supabase/RODAR_v0.143_content_setup.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-google --no-verify-jwt` (publicada em 25/10/2026).
3. Segredos `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` (Google Cloud → Credenciais → ID do cliente OAuth "Aplicativo da Web"; URI de redirecionamento `https://<projeto>.supabase.co/functions/v1/content-google`; Google Drive API ativada).


## v0.142
Nada a rodar no banco.


## v0.141
1. `supabase/RODAR_v0.141_acesso_content.sql` (aplicado em produção em 25/10/2026).


## v0.140 — Pasta do cliente no Drive
1. `supabase/RODAR_v0.140_content_drive.sql` (aplicado em produção em 25/10/2026).
2. Publicar a função: `supabase functions deploy content-drive --no-verify-jwt` (publicada em 25/10/2026).
3. Publicar o Apps Script (`integracoes/apps-script/growths-drive.gs`) como App da Web (Executar como: eu; Acesso: qualquer pessoa) e gravar `drive_script_url` em `sistema_config`.


## v0.139
Nada a rodar no banco: só a tela mudou.


## v0.138
Nada a rodar no banco: só a tela mudou.


## v0.137
Nada a rodar no banco: só a tela mudou.


## v0.136 — Classificar post do Instagram
1. `supabase/RODAR_v0.136_instagram_classificar.sql` (aplicado em produção em 25/10/2026). Pode rodar de novo sem erro.


## v0.135 — DMs do Instagram e canais
1. `supabase/RODAR_v0.135_dms_canais.sql` (aplicado em produção em 25/10/2026).
2. Função `zernio-sync` (sem verificação de JWT) na versão que também traz as DMs; cron `zernio-dms` a cada 30 minutos (`{"partes":["dms"]}`), além do `zernio-sync-diario` (posts e conta, 9h UTC). Ambos já criados em produção.
3. Migrações feitas em produção por outra sessão e agora copiadas para o repositório: `20261025022737_instagram_dm_crm.sql` (registrar_dm_instagram, canal Instagram DM) e `20261025034245_conexao_zernio.sql` (conexão zernio; o trecho do Vault só roda no Supabase).

## v0.134 — Dashboard do Instagram
1. `supabase/RODAR_v0.134_instagram.sql` (depois da v0.133; pode ser rodado de novo sem erro). Nenhuma edge function nova.
2. Para usar já: Marketing → Instagram → Importar posts (CSV exportado do Meta Business Suite ou do Metricool) e Importar dados da conta (seguidores e alcance por dia). Quando o app da Meta for aprovado, a conexão (`conexoes`) passa a preencher os mesmos números sozinha.

## v0.133 — Máquina de Conteúdo
1. `supabase/RODAR_v0.133_maquina_conteudo.sql` (só acrescenta colunas, tabelas e funções; pode ser rodado de novo sem erro). Não depende da v0.132.
2. Publicar a edge function `linha-editorial` (com verificação de JWT, padrão): `supabase functions deploy linha-editorial`. Usa os mesmos segredos de IA do "Pergunte ao Growths" (`ANTHROPIC_API_KEY` e/ou `OPENAI_API_KEY`). Sem chave, a tela usa "Copiar pedido" e "Colar resposta da IA".
3. No Growths, Marketing → Máquina de Conteúdo → "Instalar o modelo V18" no cliente da Rebecka (ou pelo SQL: `select conteudo_instalar_v18('<workspace>')`).

## v0.132 — Alertas e resumo do dia
Na ordem:
1. `supabase/RODAR_v0.132_alertas.sql` (tabelas e funções). Pode ser rodado de novo sem erro.
2. Publicar as edge functions: `supabase functions deploy avisos --no-verify-jwt` e `supabase functions deploy perguntar`.
3. `supabase/RODAR_v0.132_agendador.sql` com o id do projeto no lugar de `<PROJETO>` (liga pg_cron e pg_net e agenda `growths_rodar_agendado()` de hora em hora).
4. Segredos (Edge Functions → Secrets), quando houver: `RESEND_API_KEY` e `AVISOS_EMAIL_DE` (e-mail); `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID` e o modelo `aviso_growths` aprovado na Meta (WhatsApp); `ANTHROPIC_API_KEY` ou `OPENAI_API_KEY` (IA). Sem eles, o sino funciona e os e-mails/WhatsApps ficam marcados como "não foi" com o motivo.
5. Em cada cliente, na tela Alertas e resumo do dia, "Ligar alertas e resumo".
**Pendente em produção.**

## v0.131
- Nada a rodar no banco.

## v0.130 — Formulário de captação
- `supabase/RODAR_v0.130_formulario.sql`: colunas de aparência, captação e passo; funções `pesquisa_captar` (pública) e `pesquisa_registrar` (interna); reescreve `pesquisa_responder` e `pesquisa_publica` mantendo o comportamento. Precisa da v0.129 aplicada antes. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

## v0.129 — Qualificação por pontos
- `supabase/RODAR_v0.129_qualificacao.sql`: colunas da regra e dos pontos, funções de qualificação e a ligação com `pesquisa_responder`. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

## v0.128
- Nada a rodar.

## v0.127 — Saldo mínimo de caixa
- `supabase/RODAR_v0.127_saldo_minimo.sql`: cria `empresa.saldo_minimo`. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

## v0.126
- Nada a rodar no banco.

## v0.125
- Nada a rodar no banco.

## v0.124
- Nada a rodar no banco. Para ver o ritmo da meta, cadastre as metas mensais em Campanhas → Planejamento anual.

## v0.123 — Série do gráfico
- `supabase/RODAR_v0.123_arvore_serie.sql`: já aplicado em produção em 21/10/2026. Para outro projeto, rode depois do da v0.121.
