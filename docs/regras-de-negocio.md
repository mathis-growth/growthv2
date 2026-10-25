

## v0.139 — Insights e melhores dias
- Base: posts do período com alcance. Média de engajamento = interações somadas ÷ alcance somado.
- Assunto forte: palavra/hashtag da legenda (4+ letras, sem palavras comuns e formas de verbo) em ≥3 posts (≥2 com menos de 15 posts) e em ≤60% deles; engajamento do grupo > 110% da média; escolhe o maior engajamento × raiz do número de posts. Recomendação: levar para os tipos de mídia que o assunto ainda não usou. Assunto fraco: ≥3 posts e < 80% da média.
- Tema forte: só com ≥3 posts classificados; frente com ≥2 posts e > 110% da média. Aviso de classificação quando mais da metade dos posts está sem tema.
- Tipo de mídia: alcance médio do melhor ≥ 1,3× o do pior (tipos com ≥2 posts).
- Puxou conversa: post com ≥3 comentários e taxa de comentários (comentários ÷ alcance) ≥ 1,5× a do período. Salvamentos e compartilhamentos: mesma regra.
- DM (hipótese): conversas com a primeira mensagem nas 48 h depois da publicação; destaque se ≥2 e ≥1,5× a média por post.
- Melhor dia: dia com ≥2 posts e engajamento > 110% da média. Período: engajamento 15% acima ou abaixo do período anterior.
- Gráficos de linha: média da métrica por post em cada dia (segunda a domingo) e em cada faixa de horário (0–6, 6–9, 9–12, 12–15, 15–18, 18–21, 21–24 h, horário de São Paulo); ponto com a cor da faixa (±10% da média).


## v0.138 — Cores pela média
- Razão do grupo = valor do grupo ÷ média de referência. Vermelho se a razão for menor que 0,9; azul de 0,9 a 1,1; verde acima de 1,1. Diferença mostrada = (razão − 1), em %, arredondada.
- Referência: "Média por post" → média de todos os posts do período; "Total do período" e "Quantidade de posts" → média simples dos valores dos grupos. No quadro de agrupamentos, a média de todos os posts.


## v0.137 — Galeria e gráficos
- Ordem da galeria: maior valor da métrica escolhida primeiro (engajamento do post = interações ÷ alcance); "Mais recentes" = data e hora de publicação. Posts sem a métrica vão para o fim.
- Gráficos por grupo: "Média por post" = média da métrica nos posts do grupo (engajamento = interações somadas ÷ alcance somado); "Total do período" = soma (para engajamento, a mesma razão das somas); "Quantidade de posts" = número de posts. Um post entra no grupo do seu tema, formato e tipo de mídia; sem classificação, em "Sem classificação".


## v0.136 — Instagram e dashboard de canais
- Frente e formato do post = os do conteúdo da Máquina ligado a ele; sem ligação, os escolhidos no próprio post; sem nada, "Sem classificação".
- Eficiência do canal no período = posts, alcance somado, interações somadas e engajamento (soma das interações ÷ soma do alcance, só posts com alcance). "Na fila" = ideias do canal ainda não publicadas.
- Melhores de cada canal = 3 posts com maior engajamento no período.
- Números da conta (Instagram): seguidores = último valor no período; novos seguidores e visitas = soma por dia, quando a conexão entrega; alcance da conta = soma por dia. Comparação sempre com o período anterior de mesmo tamanho.


## v0.135 — DMs e canais
- Lead pela DM: quem mandou ao menos uma mensagem para a conta; uma pessoa por id do Instagram. Cada mensagem recebida vira um toque "DM Instagram: …". Conversa "não é lead" não gera mais toques.
- Números das DMs no período (fuso de São Paulo): conversas com alguma mensagem, conversas novas (primeira mensagem no período), recebidas, enviadas, leads novos (pessoas com origem Instagram DM criadas no período), esperando resposta (última mensagem é da pessoa, fora as "não é lead"), viraram clientes (origem Instagram DM e situação cliente).
- Canal sugerido de uma ideia nova = canais da frente ∪ canais de cada etiqueta.

## v0.134 — Dashboard do Instagram
- Posts do período = dia da publicação (fuso de São Paulo) entre as datas. Fontes: Meta, planilha importada e publicações da Máquina com canal Instagram que não estão ligadas a nenhum post.
- Engajamento do post = interações ÷ alcance; do período e dos grupos = soma das interações ÷ soma do alcance (só posts com alcance). Outras métricas por grupo = média por post.
- Período anterior = mesmo número de dias, imediatamente antes. Seguidores: último valor do período; variação contra o último valor antes do período (ou o primeiro do período).
- Top 1 e melhores = ordem pela métrica escolhida; "contra a média" = valor do post ÷ média do período.
- Ligação automática: só com exatamente 1 post sem ligação e 1 conteúdo (Instagram nos canais, agendado ou publicado, sem post ligado) no mesmo dia.

## v0.133 — Máquina de Conteúdo
- Território = linha editorial; frente = tema dentro do território; camada transversal = frente marcada como transversal. Formato = como é feito; quadro = formato de autoridade (opcional); tipo de mídia = reels, carrossel etc.
- Score V18: 6 critérios de 1 a 5; total = soma (6 a 30), só quando as 6 notas existem. Ordem: VALIDAR primeiro (no Kanban), depois score, potencial de impacto, robustez da evidência e data de criação.
- Regras do Kanban no score V18: para virar pauta, 6 notas + frente + destino (se houver destinos cadastrados) + formato (se houver formatos); para produzir, VALIDAR + canal; pronto pede copy e mídia; agendar pede data. Quem não usa o score segue as regras antigas.
- Destino só aceita os destinos cadastrados (grafia ajustada sozinha: "mathisa" vira "Mathisa"). Dia da semana vem da data de publicação quando não foi escolhido.
- Semana = segunda a domingo. Planejados = com data de publicação na semana (fora arquivados); publicados = desses, os publicados; banco forte = validadas ainda não publicadas (ideia a pronto); validadas na semana = VALIDAR marcado na semana; lacunas = território ou formato sem nada na semana e formato com frequência fixa abaixo do combinado.
- Desempenho do fechamento = publicações com métricas registradas na semana; engajamento = (curtidas + comentários + compartilhamentos + salvamentos) ÷ alcance, só onde há alcance.

## v0.132 — Resumo do dia e alertas
- Dia = fuso de São Paulo. Leads = pessoas criadas no dia; vendas/receita = vendas aprovadas pela data da venda; reembolsos pela data do reembolso; mídia = `v_trafego_anuncio_dia`; comparação = média dos 7 dias anteriores e o mesmo dia da semana passada.
- Brusco (ontem × 14 dias anteriores): alerta se |ontem − média| ≥ maior entre (desvios × desvio padrão) e (média × variação %). Só com 7+ dias com dado e movimento mínimo (3 leads, 1 venda, R$ 100 de receita ou R$ 50 de mídia por dia; CPL com 3+ leads de anúncio; CTR com 500+ impressões). Mídia zerada no dia não gera alerta de mídia. A mesma métrica para o mesmo lado em 3 dias não repete.
- Repetido: leads caindo todo dia por N dias (padrão 3) e terminando 30% abaixo; N dias sem venda quando a média era 0,5+/dia; CPL acima da meta da campanha ativa em todos os N dias com gasto; 3+ reembolsos em 3 dias, em 2+ dias.
- Pede ação: investimento ≥ R$ 100 (ajustável) sem lead de anúncio (ontem ou hoje); contas a pagar vencidas (no máximo 1 aviso por semana); saldo das contas abaixo do saldo mínimo; dia sem nenhum lead, venda nem mídia num negócio com movimento.
- Repetição de aviso: queda seguida e sem vendas, a cada N dias; CPL por campanha, a cada N dias; reembolsos e sem dados, a cada 3; saldo, a cada 3; contas vencidas, a cada 7.
- Resumo: na primeira rodada a partir da hora escolhida, uma vez por dia, sobre ontem.

## v0.131 — Selo, tags e quem respondeu
- Selo: qualificado = verde, não qualificado = vermelho, pendente = tracejado; pontos = `pontuacao_qualificacao` do lead (a última qualificação gravada).
- Quem respondeu: por padrão, a última resposta de cada pessoa (sem pessoa: por e-mail). "Pontos" e "Pela regra" = regra de hoje aplicada às respostas daquela vez; "No CRM agora" = o que está no lead. Pontuação média = média dos pontos de quem aparece na lista (antes do filtro).

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
