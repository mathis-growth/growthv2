

## v0.125 — Onda 2, parte 1
- Observações (Dashboard): período anterior = mesmo número de dias, logo antes (sem observações em "todo o período"). Gatilhos: receita bruta ±10%; margem ±3 pontos percentuais; CAC total ±15%; atraso a receber ≥10% de (a receber + atraso); produto com >60% da receita. Máximo 4, ordenadas pelo tamanho da variação. A hipótese da margem só aparece quando o peso do CAC na receita andou ≥2 pontos no sentido contrário da margem.
- Resultado × banco: resultado = DRE por competência do mês; banco = entradas − saídas das contas bancárias do tipo conta (cartões fora), pela data do movimento.
- Vencimentos: contas "previsto" e não substituídas; semanas de segunda a domingo a partir da semana de hoje; atraso = dias entre o vencimento e hoje.
- MRR mês a mês: no fim de cada mês (o atual, hoje), soma por cliente dos contratos recorrentes ativados, vigentes e não cancelados; valor dos itens ÷ meses da periodicidade. Movimento do mês por cliente: de 0 para >0 = novo; de >0 para 0 = cancelado; subiu = expansão; desceu = redução.
- Vendas por período: até 31 dias por dia, até 200 dias por semana, acima por mês. Margem por produto = líquido ÷ bruto das vendas aprovadas (contrato fechado entra com líquido = bruto).
- CAC × clientes: leads que entraram no período, seguidos até hoje (`funil_cohorts` por campanha); CAC = investimento ÷ clientes; linha = CAC médio ponderado das campanhas do gráfico; vermelho = acima da meta de CAC da própria campanha.
- Origem até a compra: cada lead em uma faixa só, a mais adiante (comprou > qualificado > não qualificado).

## v0.124 — Gráficos da onda 1
- Evolução no Dashboard: receita = contas de receita da DRE por mês; lucro = resultado da DRE; margem = lucro ÷ receita. Até o mês atual, no máximo 12 meses; o mês atual é incompleto (tracejado). A frase compara o último mês completo com o anterior.
- Ritmo da meta: metas da tabela `planejamento_mensal` (ano e mês de hoje). Realizado: vendas aprovadas (valor bruto e quantidade) e pessoas cadastradas do dia 1 até hoje. Onde deveria estar = meta × (dia de hoje ÷ dias do mês). "No ritmo" quando realizado ≥ esse valor. Projeção = realizado ÷ fração do mês (linear, só referência).
- De onde vem a receita: a mesma conta do cartão de receita (árvore `ven.soma`, valor bruto), no período da tela e no período anterior de mesmo tamanho, imediatamente antes. Até 6 barras; o resto vira "Outros".
- Cascata do Financeiro: árvore `fin.lucro` no período do filtro (sem data = todo o período), que é a mesma conta do cartão "Resultado no período". Linhas zeradas não aparecem.
- Resultado por mês (Financeiro): só meses até o mês atual.
- Custos e margens: o bullet usa `coEquilibrio` com os mesmos parâmetros da tabela de cenários. Custo por área: mesmos itens e desmarcações da lista do mês; mês anterior pelo mesmo cálculo (`coDados`).
- Campanha → Mídia paga: período = início da campanha (ou os últimos 30 dias, se ainda não começou) até hoje, ou até o fim da campanha se já acabou.
- Cores: verde/vermelho só para melhorou/piorou (em custo, subir é vermelho). Variação de 0% fica neutra.

## v0.123 — Linha no período e cadastros na campanha
- Agrupamento automático pelo período da tela: ≤ 31 dias → dia; ≤ 120 dias → semana; ≤ 800 dias → mês; acima → ano. Máximo de 62 pontos (os mais recentes).
- Semana começa na segunda-feira; o primeiro e o último ponto são cortados no início e no fim do período (aparecem como incompletos quando cortados ou quando incluem hoje).
- Números com `hoje` (MRR, a receber, caixa): o valor no último dia de cada ponto; sem período na tela, mostra 30 dias, 12 semanas, 12 meses ou 5 anos.
- Período "todo o período": os primeiros pontos zerados são escondidos.
- Variação: último ponto completo contra o anterior; "menor é melhor" como na v0.122.
- Etapas escolhidas na nova estratégia: ordem = fase (Aquisição → Retenção) e, dentro da fase, a ordem do catálogo e depois as novas; etapa nova entra como manual, em número. Chaves repetidas ganham _2, _3.
