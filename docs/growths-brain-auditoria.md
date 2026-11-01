# Growth's Brain — Auditoria inicial (etapa 1)

**Data:** 01/11/2026 · **Base:** código do GitHub (v0.212), 165 migrations, banco de produção (só leitura).
**Legenda:** **Fato** = conferido no código ou no banco · **Hipótese** = provável, não confirmado · **Recomendação** = proposta para você decidir.

**Andamento:** decisões de 01/11: começar pelo faturamento, absorver as metas aos poucos, objetivos no Planejamento anual e NSM provisória. O incremento 1 foi entregue na **v0.213**: registro central de metas, avaliação no Cockpit, objetivos do ano e status da NSM. Ver `decisoes-e-pendencias.md`.

## Resumo em 5 pontos

1. **Fato:** quase todos os blocos pedidos já existem em algum grau. NSM e árvore estão no Growth Model; metas, cenários, guardrails, alertas, qualidade de dados, dicionário de métricas e drill-down (a "árvore" dos cartões) também já existem. Não faz sentido criar motores do zero. O trabalho é **ligar e centralizar** o que já existe.
2. **Fato — o maior problema é haver várias fontes de meta.** Hoje há pelo menos 8 lugares com meta, sem ligação entre eles: `plano_anual` (meta do ano), `planejamento_mensal` (mês), `campanha_metas` e `campanha_metas_mes`, `heavyops_metas` (CS), `growth_metricas.meta` (NSM e drivers), `guardrail_definicoes` e `plano_objetivos/indicadores/metas` (o Planejamento da empresa antigo). O documento pede exatamente o contrário: o Planejamento Anual como única origem.
3. **Fato — a NSM das duas empresas que têm uma é "Receita bruta"** (Mathisa — Operação e Demo), sem meta. O botão "Modelo padrão" do Growth Model cria "Receita bruta" como NSM. Isso contradiz o documento ("não definir faturamento como NSM").
4. **Fato — previsão e probabilidade praticamente não existem.** Há ritmo e projeção simples em pontos isolados (meta de leads da campanha, vendas × meta, trimestres do Planejamento anual), mas nada registra método, premissas e acerto. Também não há um registro de riscos: existem alertas (950 em produção), alertas de guardrail e alertas de CS, cada um no seu formato.
5. **Fato — os "objetivos estratégicos" que o documento pede estavam no Planejamento da empresa antigo**, que saiu do menu hoje (v0.212). A Mathisa — Operação tem 2 objetivos lá ("Dobrar a Receita recorrente", "Operar com margem de lucro saudável"). Os dados estão preservados. **Recomendação:** trazer os objetivos para dentro do Planejamento anual, e não reabrir a tela antiga.

## O que existe em produção (contagem, 01/11)

| Estrutura | Linhas | Leitura |
|---|---|---|
| `growth_metricas` (NSM + drivers) | 16 (2 NSM) | em uso, NSM = receita |
| `plano_anual` | 1 | meta 2026 do Lumen |
| `planejamento_mensal` | 0 | o desdobramento mês a mês ainda não foi gravado |
| `plano_objetivos` / `plano_indicadores` / `plano_metas` | 2 / 1 / 1 | tela antiga, fora do menu |
| `campanha_metas` | 27 | em uso |
| `heavyops_metas` (metas de CS) | 1 | em uso |
| `guardrail_definicoes` | 0 | existe, sem uso |
| `gm_cenarios` (cenários do Growth Model) | 5 | em uso |
| `growth_experimentos` | 2 | em uso |
| `alertas` | 950 | em uso |
| `metricas_definicoes` (dicionário) | 66 | global, sem tenant |
| `diagnosticos` | 1 | em uso |

## Matriz: funcionalidade × o que existe

| Funcionalidade pedida | Existe hoje | Reaproveitar | Ampliar | Criar de fato | Riscos |
|---|---|---|---|---|---|
| **NSM** (status, versão, aprovação, fórmula, escopo) | `growth_metricas` tipo `north_star` + `nsm_evento/populacao/frequencia/fonte`; pesquisa "Descoberta da NSM" | tabela e tela do Growth Model | status (candidata → aprovada), versão, aprovado por/em, histórico | nada separado | trocar a NSM "Receita" dos clientes exige conversa, não migração |
| **Árvore de métricas** | `growth_metricas.pai_id` (NSM → driver → input), "Alavancas que movem a NSM" | a árvore | tipo de relação (matemática, operacional, hipotética, empírica), métricas compartilhadas | — | não confundir com a "árvore" dos cartões (explicação de cálculo) |
| **Objetivos estratégicos** | `plano_objetivos` (tela antiga) | os dados | levar para o Planejamento anual | ligação objetivo → meta | — |
| **Metas centralizadas** | 8 fontes (ver acima) | `plano_anual` como origem | — | **registro central de metas** (métrica, período, escopo, direção, trajetória, versão, status) que lê ou absorve as outras | maior risco do projeto: duplicar em vez de unificar |
| **Desdobramento** (ano → trimestre → mês; área, produto, campanha) | Planejamento anual: trimestres e sugestão mês a mês por receita → `planejamento_mensal` | sugestões (`plano_anual_sugestoes`, histórico importado) | leads, vendas, CAC, por produto e campanha; checagem de soma (aditivas) e numerador/denominador (taxas) | — | taxa somada por engano |
| **Metric Engine** | `metricas_definicoes` (66), regra única de receita (`revops_receitas`), `painel_gerencial`, `growth_metricas_auto`, `cg_indicadores`, `qualidade_dados` | dicionário e funções do banco | dimensões, regra de agregação, direção, por tenant quando for preciso | catálogo ligando código → função de cálculo | o mesmo número calculado em 2 funções diferentes (os testes t111/t116 já mostram cartão ≠ árvore em alguns casos) |
| **Goal Engine** (esperado até hoje, desvio, status) | ritmo em `campanha_meta_leads`, `vendas_metas_painel`, `heavyops_metas.tolerancia` | essas regras | trajetória sazonal e personalizada, status configurável | **função única `meta_avaliar`** | — |
| **Forecast** | projeção simples nos trimestres e campanhas | — | — | registro de previsões (método, versão, premissas, horizonte, intervalo) + métodos por tipo de métrica | inventar precisão com pouco histórico |
| **Probabilidade de atingir** | não existe | — | — | só quando houver dado; antes disso, status por regra, sem chamar de probabilidade | — |
| **Risk Engine** | `alertas`, `guardrail_alertas`, alertas de CS (`cg_verificar_alertas`), avisos | os detectores | — | registro único de riscos (meta, evidência, severidade, impacto, responsável, status) alimentado pelos detectores existentes | ruído (950 alertas já) |
| **Scenario Engine** | `gm_cenarios` (versão, aprovação, ICE), `simulador_cenarios/snapshots`, cenários do plano anual | `gm_cenarios` | ligar o cenário à meta (impacto na trajetória) | — | 3 lugares de cenário: escolher um como oficial |
| **Investigação** (filtro global, drill-down, drill-through, voltar) | período padrão global (v0.212), "árvore" do cartão, cartões clicáveis → listas, "Voltar para…", Leads por origem, coortes | tudo | filtro global de produto/campanha, levar o contexto ao clicar | — | tenant: tudo passa por RLS e funções com `p_ws` |
| **Cockpit Geral** | Cockpit (7 painéis) + Dashboard geral | o Cockpit | meta, esperado, realizado, projeção e status por área | — | não fazer média de tudo |
| **Cockpit Marketing / Vendas / CS** | Dashboards de marketing, campanha, vendas, CS, Customer Growth, Retenção | todos | metas do registro central, previsão, riscos | — | — |
| **Cockpit Growth / AARRR** | Growth Model, Ciclo, Resultados, funis | métricas existentes | visão AARRR por cima delas | uma tela de leitura (sem dado novo) | etapas não lineares |
| **Arquitetura de receita** (1ª venda, ascensão, recompra, renovação…) | `revops_pedidos` (numera 1ª, 2ª…), `revops_ascensao`, `revops_recompra`, contratos | a regra única | classificação exclusiva por pedido | — | dupla contagem |
| **Histórico e calibração** | `simulador_snapshots`, `narrativa_modelos_historico` | padrão de snapshot | — | foto diária de meta × realizado × previsão | volume (usar foto, não recalcular o passado) |
| **Contrato com o Diagnóstico** | `diagnosticos`, `diagnostico_metricas` | — | publicar NSM, árvore e premissas aprovadas para o plano | versão publicada + revisão de impacto | o Diagnóstico não pode virar segunda NSM |

## Recomendação: o primeiro fluxo completo (incremento 1)

O documento pede para validar **um fluxo completo — dado, meta, cálculo, tela —** antes de montar toda a infraestrutura. A proposta é fazer isso com **receita**, a métrica com mais dado e uma regra única já pronta.

1. **Registro central de metas** (tabela nova, ligada ao `plano_anual`): cada linha tem métrica, período, escopo (empresa, produto ou campanha), direção, trajetória (linear, sazonal pelo histórico ou personalizada), versão e status. Para começar, ele absorve as metas mensais de receita, leads e vendas (`planejamento_mensal`) sem apagar nada.
2. **`meta_avaliar(ws, meta, hoje)` no banco**, que devolve: meta do período, esperado até hoje, realizado (pela regra única de receita), desvio em R$ e em %, projeção até o fim do período com o método escrito e status por regra configurável. O status vai de "Dentro do esperado" até "Sem dados suficientes". **Não haverá probabilidade nesta etapa.**
3. **Cockpit Geral:** o painel Geral passa a mostrar meta × esperado × realizado × projeção da receita, com o status. Ao clicar, abre a composição (por produto e por tipo de receita), já no período padrão.
4. **Foto diária** de meta, realizado e projeção, para medir depois se a projeção acertou.
5. **Testes:** soma dos meses igual à meta do ano; o mesmo número de receita no Cockpit, no Dashboard e no Financeiro; comportamento sem dado.

Depois desse fluxo validado, a mesma estrutura recebe leads, CAC, retenção e churn, e então vêm riscos, cenários e AARRR, na ordem do documento.

## Decisões que são suas (antes de construir)

1. **Começar pelo incremento 1 (receita)** ou por outra métrica?
2. **Metas espalhadas:** o registro central **absorve** as metas existentes (migra para um lugar só e as telas passam a ler de lá) ou **referencia** cada uma onde está (menos mudança agora, mais complexidade depois)? **Recomendação:** absorver aos poucos, uma métrica por vez.
3. **Objetivos estratégicos:** trazer os objetivos da tela antiga para dentro do Planejamento anual?
4. **NSM "Receita bruta":** deixar como está até o Diagnóstico propor uma NSM, ou marcar como "provisória" já agora?
