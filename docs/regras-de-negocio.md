

## v0.130 — Formulário de captação
- O link do formulário é o link aberto da pesquisa; só capta com a pesquisa **ativa** e a captação **ligada** (ligar a captação liga o link aberto).
- Nome (2+ letras) e e-mail válido são sempre obrigatórios. WhatsApp aceito com 10 a 13 dígitos (DDD + número, com ou sem 55). Campos desligados são ignorados mesmo se enviados.
- Quem é a pessoa: e-mail igual no workspace; se não houver, WhatsApp igual (normalizado). Achou: completa telefone se vazio, soma tags, põe responsável se vazio, atualiza Instagram e consentimentos; não muda nome, etapa nem origem. Não achou: cria lead na etapa escolhida (ou a primeira do Funil de leads), com origem = utm_source ou "formulario".
- Confirmações obrigatórias precisam vir marcadas (conferido no banco); todas ficam gravadas na resposta com o texto que a pessoa viu e se aceitou.
- Bloqueios: mesmo e-mail no mesmo formulário só depois de 2 minutos; até 500 respostas por hora por formulário; campo-armadilha preenchido = responde "ok" e não grava nada.
- Depois de gravar, roda a qualificação por pontos (v0.129): tags por opção, pontos e, se houver nota de corte, qualificado/não qualificado.

## v0.129 — Gráfico único e qualificação por pontos
- Movimento por dia: com uma métrica, eixo em valor real; com várias, cada linha de 0 até o maior valor dela no período (o tooltip mostra os valores reais). Metas tracejadas: leads (meta do dia) e custo por lead (meta de CPL), só com uma métrica.
- Pontos por pergunta: escolha e sim/não = pontos da opção marcada; várias opções = soma das marcadas; NPS/escala = nota × peso; texto = não pontua. Opção marcada sem pontos conta como 0 (entra na média).
- Total: soma = soma dos pontos; média = soma ÷ perguntas pontuadas respondidas (2 casas). Qualificado se total ≥ corte; sem corte, a qualificação não muda (só pontos e tags).
- Faixas: vale a de maior "a partir de" que o total alcança; as tags das outras faixas saem da pessoa. Tags das opções são somadas às da pessoa (não removem as que ela já tinha).
- Aplica na hora em que a pessoa responde (link único ou link aberto com e-mail que já existe) e no "Recalcular" (última resposta de cada pessoa). Grava `pontuacao_qualificacao` (até 9.999,99), `qualificacao` e `tags`.

## v0.128 — Painel da campanha
- Período: perpétuo = últimos 30 dias até hoje (ou até o fim); lançamento = do início ao fim (ou hoje). Opções 14, 30, 60 dias e campanha toda.
- Quadrinhos: leads (pessoas que entraram na campanha, a conta da meta de leads) contra a meta do dia de `campanha_meta_leads`; custo por lead = investimento do dia ÷ leads do dia, contra `meta_cpl`; vendas contra `meta_vendas ÷ dias do carrinho` (ou da campanha), só nos dias de carrinho aberto. Sem meta: contra a média do período (verde ≥ média; vermelho = 15% pior; amarelo no meio). Investimento e receita: intensidade da cor = tamanho do valor.
- Onde caiu: últimos 7 dias completos (sem hoje) × 7 anteriores. Leads dos anúncios = investimento ÷ CPM × 1.000 × CTR × connect rate × conversão da página; o fator com a maior piora é o que mais puxou para baixo. Criativos com 1.000+ impressões que perderam 10%+ de CTR.
- Criativos: "melhor" = menor custo por lead entre os que trouxeram 5+ leads.

## v0.127 — Onda 3
- Receita por papel da oferta: vendas aprovadas (bruto) do período, pelo papel da oferta ligada à venda (`vendas.oferta_id` → `ofertas.papel`); sem oferta = "Sem oferta ligada". Ofertas extras = order bump + upsell + cross-sell + downsell.
- Importação de vendas: coluna opcional da oferta; casa pelo nome da oferta (normalizado); sem par, a célula vira aviso e a venda entra sem oferta.
- Meta × realizado no plano: meses do início ao fim do plano; meta = soma das metas mensais (`planejamento_mensal`); realizado = vendas aprovadas (bruto e quantidade) e pessoas cadastradas, do início do plano até hoje; % = realizado acumulado ÷ meta acumulada até o mês atual. Projeção só de cenário aprovado com `resultados.projetado_consolidado`.
- Saldo mínimo: comparado dia a dia com o caixa projetado de 30 dias (`fin_dashboard_periodo.projecao`). Aviso na primeira data abaixo do mínimo. Vazio = sem aviso. Valor ≥ 0.

## v0.126 — Onda 2 (fim) e Onda 1 (resto)
- Agrupamento no tempo (abandono, mídia, marketing): até 31 dias por dia, até 200 dias por semana (segunda a domingo), acima por mês. O último ponto incompleto aparece mais claro ou tracejado.
- Abandono: conta na data do abandono; recuperado = tem venda de recuperação; taxa = recuperados ÷ abandonos do ponto.
- LTV por coorte: "Receita acumulada por cliente" da matriz de coortes, só nos pontos já completos; média ponderada pelo número de clientes de cada coorte.
- O que mais mexe no lucro (Growth Model): ±10% sobre o real do período da planilha, uma alavanca por vez. Preço: receita − impostos − taxas; conversão: margem de contribuição (receita − impostos − taxas − entrega), com a mesma mídia; custos (mídia, fixos, entrega, taxas): só o próprio custo. Imposto proporcional à receita (MEI fixo); entrega tratada como por cliente.
- Prioridade ICE: só experimentos não concluídos com impacto e facilidade; corte dos quadrantes em 5,5; a fila é ordenada por impacto × confiança × facilidade.
- Antes × depois: valor_base → valor_resultado do experimento, nas etapas "análise" e "concluído"; cada linha na sua escala.
- Desvio da meta: (realizado − meta) ÷ meta; em CAC e investimento, abaixo da meta é bom.
- Vendas acumuladas × meta: vendas aprovadas da campanha por dia; ritmo = meta × (dias passados ÷ dias da campanha); sem data final, só a linha da meta.
- CPM = investimento ÷ impressões × 1.000; CTR = cliques ÷ impressões; CPC = investimento ÷ cliques; frequência = impressões ÷ alcance (aproximação). CAC de mídia por canal = investimento ÷ clientes pela UTM.
- Marketing no tempo: série da árvore (`arvore_serie`) dos nós investimento em anúncios, custo por lead e CAC; não segue o filtro de campanha.
- Novos × existentes: vendas aprovadas (bruto) por mês; venda no dia da primeira compra do cliente (venda ou contrato) = novo, depois = existente.

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
