

## v0.122 — Gráfico da árvore
- Ordem de escolha: (1) quebra "Por mês" com 3 meses ou mais → linha; (2) fórmula em R$ com pelo menos uma subtração → cascata; (3) fórmula só de somas, ou a primeira quebra com 2 itens positivos → rosca (5 maiores + Outros); (4) registros com data → barras por dia (até 31 dias); (5) percentual → medidor.
- Sem nenhum desses e com período (`ini`/`fim`) ou data (`hoje`): o mesmo nó é calculado para os 4 últimos meses (meses fechados inteiros; o atual até a data final; para `hoje`, o último dia de cada mês) e vira a linha "Evolução nos últimos meses".
- Variação: último mês fechado contra o anterior. "Menor é melhor" (subir = vermelho): CAC, CPL, CPC, churn, custos, despesas e contas a pagar.
