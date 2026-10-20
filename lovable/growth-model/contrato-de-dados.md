# Growth Model — contrato de dados (o que o front lê e grava)

O banco é o do Growths (Supabase `yngyghlyonybvfvjcmxl`). O front só chama estas tabelas e funções. Toda tabela tem `workspace_id` (cliente) e RLS: o usuário logado só enxerga os clientes a que pertence.

## Funções (RPC) — todas retornam dados já calculados no banco
| Função | Argumentos | Retorno |
|---|---|---|
| `growth_modelo_historico` | `p_ws uuid, p_ini date, p_fim date` | linhas mensais: `loop, nome, fase (aquisicao\|retencao), tipo (campanha\|organico\|upgrade\|recompra\|contratos), produto_id, campanha_id, mes, inv, imp, clk, vis, led, qua, cli, rec, base` |
| `growth_metricas_auto` | `p_ws uuid, p_ini date, p_fim date` | objeto `{receita, leads, investimento, cpl, vendas, ticket, cac, roas, conv, clientes_ativos}`; `conv` em % |
| `campanha_ofertas_resultado` | `p_ws uuid, p_campanha uuid` | por oferta da campanha: `id, produto_id, produto, nome, papel, preco, vendas, receita` |

## Tabelas
- `growth_metricas`: id, pai_id, nome, descricao, formula, tipo (north_star\|input\|…), fonte (auto\|manual), chave_auto, unidade (brl\|pct\|numero\|x), direcao (sobe\|desce), meta, valor_manual, valor_manual_anterior, ordem. Árvore por `pai_id`.
- `growth_experimentos`: id, metrica_id, titulo, hipotese, criterio_sucesso, responsavel, etapa, impacto, confianca, facilidade, score, inicio, fim_previsto, valor_base, valor_resultado, resultado, decisao, aprendizado, concluido_em.
- `gm_alavancas`: id, loop_chave, produto_id, alavanca (`vol`, `r:<a>><b>`, `tkt`), mes (1º dia do mês), cenario (`base`\|`sim`), valor. Guarda o que o usuário digitou nas células do Modelo por loop (upsert por loop_chave+produto+alavanca+mes+cenario; apagar = voltar ao valor herdado).
- `benchmarks_mercado`: workspace_id, metrica (cpl\|cac\|conv\|ticket\|roas\|margem\|leads\|receita), valor, fonte. Única por (workspace_id, metrica). `conv` em %.
- `campanhas`: id, nome, status, produto_id, data_inicio, data_fim, orcamento_total, meta_leads, meta_vendas, meta_taxa_lead_venda, meta_receita, meta_cac, meta_cpl.
- `campanha_canais`: id, campanha_id, canal, orcamento, meta_leads, meta_cpl (também meta_vendas, meta_cac).
- `campanha_calculos`: id, campanha_id (vazio = simulação avulsa), nome, premissas jsonb (o objeto P da calculadora). 
- `ofertas`: id, produto_id, nome, papel (principal\|upsell\|order_bump\|cross_sell\|downsell), preco, ativo. `campanha_ofertas`: id, campanha_id, produto_id, oferta_id, nome, papel, preco, ordem.
- Apoio: `produtos(id, nome)`, `workspaces`, `canais(codigo, nome)`.

## Regras que valem no front (e estão em `src/lib`)
- **Nada de IA nos cálculos.** `growth-motor.ts` (loops, projeção), `calculadora.ts` (calculadora de campanha), `alertas.ts` (vermelho).
- Alertas em vermelho (aba Mapa): pior que o benchmark cadastrado (tolerância 0), ou >10% pior que a média dos 3 períodos anteriores ou que o período anterior. CPL e CAC: menor é melhor. Só métricas automáticas.
- Calculadora: base = ticket, conversão %, CPL, leads. Ligados (CAC, vendas, receita, mídia, ROAS) editados ajustam a base (`ccEdita`).
- Salvar metas na campanha atualiza `campanhas` (meta_leads, meta_vendas, meta_taxa_lead_venda, meta_cpl, meta_cac, meta_receita, orcamento_total) e `campanha_canais` dos canais já existentes.
