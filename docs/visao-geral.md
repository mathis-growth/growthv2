# Visão geral

O Growths é o módulo de gestão e inteligência de crescimento para negócios digitais. O lead nasce com origem rastreada, vira aluno, gera movimento financeiro e alimenta métricas, DRE e planejamento, tudo no mesmo sistema. Serve ao negócio da Mathisa e aos clientes dela (multi-cliente desde o início).

## Dentro do escopo

- Cadastros: pessoas (com papéis), produtos, plataformas de venda, canais, campanhas, centros de custo
- CRM de leads e jornada do aluno
- Plano de contas, partidas contábeis automáticas, contas a receber, fluxo de caixa e DRE gerencial
- Importação de extrato bancário por arquivo (planejado)
- Motor de métricas configurável, dashboards, growth model e planejamento anual (planejado)
- Produção de conteúdo conectada ao Instagram e a outros canais (planejado)

## Fora do escopo

- Emissão de nota fiscal
- Conciliação bancária automática (só importação de extrato)
- Folha, estoque e contabilidade fiscal oficial: a contabilidade é **gerencial**

## Princípios de arquitetura

1. **Pessoa única com papéis.** Lead, aluno e fornecedor são a mesma entidade. O histórico fica contínuo.
2. **Campanha e canal como eixo central.** Todo lead, venda e custo aponta para a campanha e o canal.
3. **Origem do lead congelada na entrada.** A primeira origem (UTMs e campanha) não muda depois.
4. **Planejado, realizado e simulado separados.** Um nunca sobrescreve o outro.
5. **Razão contábil append-only.** Lançamento não se edita: erro se corrige com estorno. Débito é igual a crédito, conferido pelo banco.
6. **Contabilização por regra.** Você configura quais contas cada evento debita e credita. O sistema gera as partidas sozinho.
7. **Métricas por fórmula declarativa, nunca por IA.** O mesmo dado sempre dá o mesmo número.
8. **Multi-cliente com RLS.** Cada cliente só enxerga os próprios dados.

## Fases

| Fase | Entrega |
| --- | --- |
| 0. Fundação | Glossário de métricas, plano de contas padrão, esquema de dados |
| 1. Pessoas e receita | Cadastros, captura de lead com origem, vendas |
| 2. Financeiro | Regras de contabilização, partidas automáticas, fluxo de caixa, DRE |
| 3. Aquisição e métricas | Conectores de mídia, CPL, CAC, ROAS, margem, dashboard |
| 4. Jornada e conteúdo | Cohorts, churn, NRR, calendário de conteúdo, Instagram |
| 5. Growth model e plano | Árvore de drivers, cenários, orçamento anual |

Estado atual: o banco das fases 1 e 2 está pronto na versão 0.1.0. As demais fases ainda estão por fazer.

## Identidade visual (v0.54)
Tema escuro com vinho e carmim, fonte Inter, cartões arredondados. Conceito de referência: "Growth's — Estrutura de UX do Dashboard Principal" (hierarquia: KPIs, NSM e guardrails, tendências, canais, funil, alertas, ações prioritárias).

## Growth Starter (v0.55)
Para clientes que ainda não contrataram o Growths: cria-se o banco dele, importam-se as planilhas com de-para, e o dashboard e o relatório de diagnóstico saem dos dados.

## Equipe interna (v0.57)
A agência (workspace marcado como agencia) enxerga e troca entre clientes e cria novos; o cliente só vê o próprio ambiente.

## Personalização (v0.58)
Cada pessoa monta o próprio dashboard (ordem e itens visíveis).

## Mídia (v0.59)
Dashboard de mídia com saúde dos anúncios e relatórios por canal, campanha, anúncio e ângulo.

## IA (v0.60)
Chat "Pergunte aos dados" com Claude ou ChatGPT, restrito a um resumo calculado e com conferência dos números.

## Dashboards (v0.61)
Tela inicial: Dashboard (antigo Painel gerencial). Também: Dashboard Growth (conceito, personalizável) e Dashboard de mídia.

## Importação (v0.62)
Fila de arquivos com identificação automática e semáforo verde, amarelo e vermelho antes da conferência de-para.

## Dashboard e campos personalizados (v0.63)
O Dashboard Growth aceita período personalizado e comparação à escolha. Cada cliente pode criar campos próprios para colunas de planilha que o Growths não tem.


## v0.76
Growth Model ganhou Baseline e Cenário na mesma tabela.


## v0.77
Estratégias: o funil de venda é desenhado uma vez (fases e etapas) e cada campanha recebe uma cópia. A campanha ganhou o funil etapa por etapa e o lançamento de números por dia. O lead ganhou a jornada de pontos de contato, com primeira origem e último clique. No Growth Model, upgrade deixou de ser cliente novo.


## v0.78
Growth Model: o cenário pode ser editado (investimento, custos, taxas, ticket) e os meses sem dados são projetados.


## v0.79
Growth Model: o topo de funil (impressões, cliques, visitas, leads) aparece sempre nos loops de aquisição, para simular mesmo sem dado de mídia.


## v0.80
Segurança: o banco só aceita chamadas de quem está logado (exceto a página pública da pesquisa), e cada operação confere a permissão do módulo. Quem entra sem workspace vê como pedir acesso.


## v0.81
Growth ganhou o **Simulador de lucro**: rentabilidade por produto, jornada e negócio, com cenários, limites de CAC e ROAS, payback e caixa. As estratégias passam a ser montadas com **blocos** (conteúdo, tráfego, grupo, aula, checkout...), cada um com as métricas que precisa ter.


## v0.82
Growth Model tem duas abas: Growth Loops (quanto se vende: volume de aquisição, retenção e vendas) e Unit Economics (quanto se ganha: margem, CAC, LTV, payback e caixa).


## v0.83
Contas a pagar: desfazer o pagamento de uma baixa parcial devolve a conta inteira, sem deixar pedaços em aberto.


## v0.84
No menu Growth: Growth Loops e Unit Economics aparecem como itens próprios.


## v0.85
Cada cliente recebe um pacote de acesso (ex.: Disparo, Consultoria, Mentoria) com as telas que contratou; a equipe Mathisa monta e ajusta os pacotes.

## v0.86
No dashboard financeiro, clicar no saldo abre o extrato do banco e clicar em a receber / a pagar lista todas as contas. Cartão de crédito tem fatura própria e não diminui mais o saldo em banco. Existe um espaço "Casa" só para as finanças pessoais. Projeto marcado como de campanha cria a campanha, e cada bloco da estratégia vira atividade no projeto.

## v0.87
A Casa fica no menu da Mathisa — Operação, com financeiro próprio que não se mistura com o da empresa. O dinheiro passa da empresa para a Casa pela "Transferência da empresa", normalmente pagando o pró-labore.

## v0.88
Os painéis avisam quando o dado está incompleto ou não bate (e explicam cada indicador no ⓘ), cada mudança importante fica na Auditoria, cadastros repetidos podem ser juntados e o fechamento de campanha virou oficial, com versões.

## v0.89
A campanha mostra leads únicos, cadastros repetidos, alunos e não alunos, metas por tipo e vendas por canal (último toque, ROAS bruto). Ofertas mostram a taxa de aceite do bump e do upsell, e há uma tela de abandono de checkout com a recuperação.

## v0.90
Projetos têm tags, filtros, painel com gráfico de andamento e podem virar modelo. Projeto e campanha se vinculam pelos dois lados, e a campanha cria o projeto a partir de um modelo. A campanha e cada canal têm meta de CPL.

## v0.91
Ao criar uma campanha, você escolhe se o projeto dela já nasce junto (e com qual modelo) ou se cria depois.

## v0.92
No Dashboard principal, clique em Saldo em banco para ver as transações da conta, e em A receber ou A pagar para ver as contas.

## v0.93
Financeiro → Custo operacional mostra quanto custa manter a empresa por mês, por área e por tipo, e quanto é preciso vender para empatar ou ter lucro no MEI ou no Simples. No simulador de lucro, "Puxar do financeiro" traz esses custos.

## v0.94
Em Financeiro → Custos e margens você vê a margem de contribuição de cada produto, o lucro e a margem líquida do mês, põe a sua meta de margem (ex.: 30%) e vê se está dentro ou abaixo dela.

## v0.95
Você define três cenários para a margem de lucro (ruim, bom e ótimo) e a tela mostra em qual deles o mês está e quanto vender para chegar em cada um.

## v0.96
No Unit Economics, a aba Meta de retirada mostra quanto a empresa precisa faturar para os sócios tirarem o que querem por mês, com margem mínima, muito boa e ótima para o negócio, e o que é possível com o que já está para receber.

## v0.97
Ofertas viraram um cadastro próprio (com pacotes e versões), cada campanha monta a sua esteira de ofertas com order bumps, upsells e downsells ramificados e simula a receita, e a campanha pode ser híbrida, com cada canal tendo a sua execução e estratégia.

## v0.98
No Growth Model você cria cenários com nome e hipótese, simula mexendo só nas alavancas, vê ao mesmo tempo o resultado do recorte e do negócio inteiro (receita, custos, lucro e margem) e compara até 3 cenários com o baseline, que fica travado.

## v0.99
Do cenário à decisão: você dá a nota ICE, aprova (o cenário congela e sai um documento de decisão para imprimir), a ideia entra no Kanban de 7 colunas e pode virar experimento ou planejamento em Projetos.

## v0.100
Guardrails protegem o lucro: você define limites (margem, CAC, ROAS…), vê o risco de cada cenário antes de aprovar e, quando o teste vai ao ar, o Growths compara antes, durante e depois, avisa quando sai do limite e guarda o aprendizado com a decisão de escalar, iterar ou interromper.

## v0.101
Growth → Growth Loops abre em "Cenários e simulação"; nas abas do topo ficam o Modelo de 12 meses, o Mapa de métricas e North Star e a Calculadora de campanha.

## v0.102
Novo visual azul em degradê, com movimento ao passar o mouse no menu e nos indicadores. No rodapé da barra lateral, o botão Modo claro / Modo escuro troca o fundo; a escolha fica guardada no navegador.

## v0.103
Growth → Growth Loops abre numa tela só: escolha período, produto e campanha. No topo, fixos, receita, mídia, CAC mídia, CAC sem mídia, custo de entrega, lucro, margem e ROI. Embaixo, cada loop do período (lançamento, perpétuo, orgânico, recompra...) com as etapas e três colunas: real, cenário e efeito. Mude um número no cenário (ex.: CTR de 1,5% para 2,5%) e veja na hora o que acontece com receita, lucro e margem. O resto (aprovação, guardrails, modelo de 12 meses, mapa, calculadora) fica em Mais opções.

## v0.104
No Growth Model, o que você muda no cenário vale em qualquer filtro: mudou com todos os produtos, aparece ao filtrar o produto; mudou com o produto filtrado, aparece em todos.

## v0.105
RevOps → **Retenção & Expansão** (substitui Cohorts e Ascensão da escada):
- **Análise de Coortes**: quantos clientes de cada mês voltam a comprar em 30, 60, 90, 180 e 365 dias, quanto cada coorte já gerou e quanto vem de clientes antigos.
- **Análise de Recompra**: quem recompra, quando, o quê, e quais produtos abrem a porta e quais expandem a receita.
- **Segmentação RFM**: campeões, leais, novos, em risco, hibernando...

Filtros por período, produto, categoria, canal, campanha, origem e segmento. Visões salvas. Em qualquer número, gráfico ou segmento, um clique abre a lista de clientes com o histórico e o CSV.

## v0.106
O Growth Model virou uma planilha: o real fica travado e, na coluna Cenário, você mexe em preço, custo de entrega, imposto, custos fixos ou em qualquer etapa de uma campanha. Tudo o que muda por consequência acende em azul, e o resultado final aparece no topo. Os cenários salvos podem ser comparados lado a lado, com ICE, e o escolhido vai para o Kanban.

## v0.107
O Growth ganhou a tela **Cenários**, ao lado da planilha do Growth Model. É o histórico de tudo o que já foi simulado: o que está em estudo, o que foi para o Kanban, o que está no ar, o que foi testado (com período, decisão, aprendizado e link da documentação) e o que foi descartado e por quê. Cenário não se apaga: quem não serve é descartado com motivo e pode ser reaberto. Depois de aprovado, o status do cenário acompanha o card do Kanban sozinho.

## v0.108
O módulo Growth ficou mais enxuto: seis itens no menu. O Growth Model reúne a Planilha (onde se simula) e os Cenários (o histórico). O Unit Economics e a Análise de funil saíram, porque a Planilha já cobre margem, impostos, custos e lucro.

## v0.109
Agora dá para mandar ideias de conteúdo pelo ChatGPT do celular: você fala a ideia (pelo microfone de ditado) num GPT ligado ao Growths, e ela aparece no Planejamento de conteúdo, na coluna Ideia, já com título, ângulo, formato e tema. A configuração fica em Planejamento de conteúdo → Ideias pelo ChatGPT.

## v0.110
Fizemos uma auditoria: com a mesma empresa fictícia e o mesmo mês, comparamos o número que cada tela mostra. Achamos onde as telas não batem (lucro, receita, impostos, CAC, LTV e ROAS) e por quê. A próxima etapa é ter uma definição única por métrica, calculada num só lugar.

## v0.111
As telas passaram a mostrar o mesmo número: lucro, receita e imposto do mês vêm da contabilidade em todas elas. O regime de imposto fica no Cadastro da empresa e vale para todo mundo. O Growth Model voltou a contar os custos fixos.

## v0.112
O Growths ganhou uma escola fictícia completa, a Escola Aurora, para testar as telas com dados que fazem sentido entre si. Ela tem histórico de julho a outubro e um lançamento no meio da captação: R$ 20 mil em anúncios, 31 criativos com imagem, cerca de 3 mil leads e metas por canal.

## v0.113
Agora os leads entram sozinhos. O formulário da página de captura, a Respondi e os formulários do Meta Lead Ads mandam cada inscrição para um endereço do Growths, e ela cai em Pessoas e na campanha certa pelo `utm_campaign` do canal, sem duplicar quem já está na base. Tudo fica na campanha → Captação e metas → **Receber leads de formulários**. As vendas do Conta Azul vêm na próxima etapa.

## v0.114
O Dashboard da campanha agora mostra se a captação está no ritmo da meta:
- quantos leads já entraram e quantos eram esperados até hoje;
- quanto falta por dia;
- gráficos de leads por dia e acumulados, com cada dia marcado como dentro ou fora da meta;
- uma visão por mês;
- a meta de cada canal, com a situação de cada um.

Os gráficos ficaram menores e lado a lado. O funil mostra a % de conversão de uma etapa para a outra e a taxa de cada métrica de apoio, como CTR e connect rate.

## v0.115
Na campanha, cada card (leads, investimento, custo por lead, vendas, CAC, receita, ROAS e conversão) agora abre o detalhe.
- Leads: de que canal vieram, quantos são novos, como foram qualificados e quem são os últimos.
- Investimento: por canal, contra o orçamento, e os anúncios que mais gastaram.
- Vendas: por produto, por canal e quem comprou.

Tudo leva a mais um nível: do canal para o Dashboard filtrado, do nome para a ficha da pessoa.

## v0.116
Agora dá para perguntar ao sistema "de onde vem este número?". Ao clicar num card, abre um painel à direita com a conta que gerou o número. Por exemplo: CAC R$ 513 = Investimento R$ 32.871 ÷ 64 clientes.

Cada parte também é clicável. O investimento abre por campanha, por canal e por anúncio, até os dias de cada anúncio. Os clientes abrem a lista de pessoas, e cada nome abre a ficha. O lucro abre receitas e despesas, depois as contas contábeis e, por fim, os lançamentos.

O caminho percorrido aparece no topo do painel, e dá para voltar a qualquer nível. Já funciona no Dashboard, no Financeiro, no Marketing, na Mídia paga, em Vendas e nas campanhas. As próximas partes vão levar a árvore às telas que faltam.

## v0.120
**Comissões.** Em Configurações → Comissões você cadastra quem recebe (vendedor da equipe comercial, coprodutor, estrategista ou parceiro) e as regras: quantos % e sobre quais vendas (do projeto todo, de uma campanha, de um produto ou de uma oferta). Também define se a base é o líquido ou o bruto e como paga. O sistema calcula sozinho a cada venda e parcela de contrato. Em Vendas → Comissões você acompanha quanto cada um tem a receber no mês, vê o extrato e, com um botão, transforma tudo em contas a pagar, já descontando o que foi devolvido.

**Conexões.** Em Configurações → Integrações, o Meta (Facebook Ads e Instagram) e o Google (Google Ads e YouTube) conectam com o login da própria plataforma. Os anúncios entram em Mídia paga, e o orgânico do Instagram e do YouTube fica guardado dia a dia. Para ligar de verdade, falta criar os apps nas plataformas: o passo a passo está em `conectar-meta-e-google.md`.

## v0.119
Custos e margens agora tem árvore em todos os cards de custo. O custo do mês abre por tipo, área e conta contábil. Cada item mostra as contas a pagar que o formam. O ponto de equilíbrio mostra quanto sai de cada real vendido.

Nas tabelas de Mídia paga, por canal e por dia, cada número também abre a árvore. E o lançamento de um recebimento agora leva à venda ou ao contrato de onde veio.

## v0.118
Agora também os números de dentro das tabelas abrem a árvore: na tabela de campanhas ativas do Dashboard e nas coortes do Dashboard de marketing, cada número sublinhado mostra de onde veio, só daquela linha.

A venda e a conta a pagar viraram um passo do caminho: da receita se chega à venda, dela aos lançamentos, e do lançamento de volta à venda ou à conta que o originou. Ganharam árvore também o caixa projetado em 30 dias, os novos em 30 dias e os que faltam qualificar.

## v0.117
A árvore desce até o fim: do lucro às receitas, depois à conta contábil, ao lançamento (com débito e crédito de cada conta) e à pessoa por trás da venda.

Também ganharam árvore:
- as telas de Contas a receber, Contas a pagar e Contratos;
- LTV e churn do marketing;
- NRR, GRR e penetração do Dashboard;
- mais cards de Custos e margens.
