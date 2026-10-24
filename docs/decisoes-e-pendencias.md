

## v0.132 — "Como foi o meu dia?" e alertas
**Pedido da Rebecka (24/10)**: poder perguntar ao Growths ("como foi meu dia ontem?") e ter um resumo; e o sistema identificar algo acontecendo de forma brusca ou repetida e mandar alertas. Escolhas dela: alertas no sino, por e-mail e por WhatsApp; ligar o agendador do banco (pg_cron). Sobre a chave de IA, sem preferência.
**Decisões técnicas**
- O resumo do dia e os alertas são **contas exatas no banco**, sem IA: funcionam sem chave e não inventam número. A IA fica para as perguntas livres e passa a receber o dia a dia.
- "Brusco" = ontem contra os 14 dias anteriores: avisa quando a diferença passa da variação em % escolhida (padrão 40%) **e** de 2 desvios do normal, só para números com movimento (ex.: 3+ leads por dia, 7+ dias com dado). Dia inteiro zerado num negócio com movimento vira um alerta só de "dado não chegou" (quase sempre é integração parada).
- Para não virar barulho: cada alerta é gravado uma vez; o mesmo problema que continua só volta a avisar depois de alguns dias; vários alertas na mesma rodada viram um aviso só.
- Quem recebe e por onde reaproveita a Equipe (avisar no app, e-mail, WhatsApp), igual aos avisos de projetos e do CRM. A fila de notificações já existia, mas nada enviava e-mail/WhatsApp: a edge function `avisos` passa a enviar todos esses avisos.
- WhatsApp: mensagem iniciada pela empresa exige modelo aprovado na Meta (`aviso_growths`, 2 variáveis) e é cobrada por mensagem.
**Pendente**: aplicar em produção (a tentativa de 24/10 foi cancelada antes de rodar): `RODAR_v0.132_alertas.sql`, publicar `avisos` e `perguntar`, `RODAR_v0.132_agendador.sql`; cadastrar os segredos de e-mail, WhatsApp e IA; ligar os alertas no cliente Mathisa — Operação.

## v0.131 — Selo de qualificado, tags coloridas e quem respondeu
**Pedido da Rebecka (21/10)**: ver na cara se o lead é qualificado ou não (não só a tag do produto), com a pontuação que ele recebeu do formulário; tags coloridas; e ver todo mundo que respondeu a pesquisa com a pontuação de cada um.
**Decisões técnicas**
- Cor da tag automática (mesmo nome, mesma cor), sem cadastro de cores; prefixos "Oferta" e "Alerta" e as faixas quente/frio têm cor fixa. Se ela quiser escolher a cor de cada tag, vira um cadastro de tags (próximo passo).
- A pontuação por resposta na aba "Quem respondeu" é calculada na tela com a regra de hoje (mesma conta do banco, `pqPontua`); o que está gravado no lead aparece ao lado ("No CRM agora"). Assim não precisou mudar o banco.

## v0.130 — Formulário de captação nas Pesquisas
**Pedido da Rebecka (21/10)**: implementar no Growths o formulário de qualificação da Mathisa (pacote `Mathisa_Formulario_Qualificacao_Growths_2.zip`), criado dentro das Pesquisas, com o link para enviar ao cliente, alimentando o CRM, e com fontes e cores diferentes para cada cliente seguir a sua identidade visual.
**Decisões técnicas**
- Em vez de um endpoint externo (o pacote pedia um `GROWTHS_ENDPOINT`), o formulário é a própria página pública de pesquisa do Growths: grava direto no banco por `pesquisa_captar`, sem chave secreta no navegador.
- "Criar oportunidade no CRM, etapa Novo lead": no Growths, contato novo é um **cartão no Funil de leads**; a etapa é escolhida no formulário (padrão: a primeira, hoje "Novo lead"). Oportunidades seguem sendo para quem já é cliente.
- Deduplicação: primeiro e-mail, depois WhatsApp (normalizado). Quem já existe tem só o que faltava completado (telefone, Instagram, tags somadas, responsável se vazio); nome, etapa e origem não são trocados.
- Classificação do pacote: a oferta sugerida virou tag pela resposta de "Que tipo de ajuda"; é sugestão, a qualificação final continua manual (sem nota de corte no modelo, a qualificação do lead não muda sozinha).
- **Limitação**: os alertas que dependem de duas respostas juntas (ex.: implementação + sem plano → "Brain pode exigir Strategy antes") não cabem na regra de pontos por opção; ficam para a revisão humana.
- Fontes: só pelo nome do Google Fonts (letras, números e espaços); cores só no formato #rrggbb; logo só https. Tudo é conferido de novo na página pública antes de virar estilo.
- O site tem `X-Frame-Options: DENY`: o formulário abre pelo link, não dentro de um iframe no site do cliente.
**Banco em produção**: `RODAR_v0.130_formulario.sql` aplicado em 21/10/2026, com autorização da Rebecka.

## v0.129 — Gráfico único e qualificação por pontos
**Pedidos da Rebecka (21/10)**
- Cada dia num gráfico só, uma cor por métrica, escolhendo quais ver (todas juntas ou só algumas).
- Regra de qualificação: no questionário que ela monta, colocar tags, qualificar, pontuar (pergunta tal vale tanto) e decidir por soma ou média.
**Decisões técnicas**
- Várias métricas com unidades diferentes no mesmo gráfico: cada linha na sua escala (para comparar o movimento) e o valor real no tooltip; com uma só, eixo real.
- A pontuação roda no banco (mesma conta no simulador da tela), para valer também para quem responde pelo link sem ninguém com o sistema aberto.
- As respostas que chegam por formulários de fora (Respondi, Meta Lead Ads) ainda não passam por esta regra: próximo passo, se ela quiser.
**Banco em produção**: `RODAR_v0.127_saldo_minimo.sql` e `RODAR_v0.129_qualificacao.sql` aplicados em 21/10/2026, com autorização da Rebecka.

## v0.128 — Painel da campanha
**Pedido da Rebecka (21/10)**: a campanha precisa mostrar, por dia, o movimento do tráfego com verde/vermelho de dentro ou fora da meta; quanto está indo em cada vídeo; vendas por dia; o produto que mais vende; order bump; o melhor criativo; o CTR por dia; e, quando cair, onde caiu.
**Decisões técnicas**
- O painel entra no topo da aba Dashboard da campanha; o que já existia continua abaixo (nada saiu).
- "Quanto estou postando por vídeo" foi lido como quanto foi investido em cada vídeo/criativo e o que ele trouxe.
- Sem meta cadastrada, a cor compara com a média da própria campanha, e a tela diz isso em cada linha.
- Não muda o banco.

## v0.127 — Onda 3
**Pedido da Rebecka (21/10)**: fazer a Onda 3 depois da v0.126.
**Decisões técnicas**
- O saldo mínimo é o único item que precisa de banco. Como a autorização para mudar produção ainda não veio, a tela funciona sem a coluna (guarda no navegador e avisa) e passa a usar o cadastro da empresa sozinha quando `RODAR_v0.127_saldo_minimo.sql` for rodado.
- A árvore NSM → outputs → inputs já existia no Growth Model (Mapa de métricas e North Star), com a ligação "Fica abaixo de"; não foi refeita.
- A projeção do plano vem só de cenário aprovado (regra da seção 7 do diagnóstico): nada de extrapolar o ritmo.
**Pendente**
- ~~Autorizar e rodar `supabase/RODAR_v0.127_saldo_minimo.sql` em produção~~ — feito em 21/10/2026.
- Para os gráficos da Onda 3 terem conteúdo: cadastrar ofertas e ligar as vendas (ou trazer a coluna na importação), criar o plano da empresa e as metas mensais, ligar as métricas do Growth.

## v0.126 — Fecha a Onda 2 e a Onda 1
**Pedido da Rebecka (21/10)**: terminar a v0.126 (fim da Onda 2 e o que faltou da Onda 1) e depois fazer a Onda 3.
**Decisões técnicas**
- A sensibilidade do Growth Model é uma conta direta sobre o resultado real (régua para escolher o que testar), não uma nova simulação; a coluna Cenário continua sendo o lugar de simular. A tabela de sensibilidade antiga ficava no simulador antigo, que não aparece mais no menu.
- Burn-up só de vendas: o de leads (Leads acumulados) já existia no painel de meta de leads da campanha.
- O gráfico de investimento, CPL e CAC do marketing usa a árvore, que hoje não filtra por campanha; a tela avisa quando há filtro de campanha.
- Não muda o banco.
**Próximo (v0.127, Onda 3)**: order bump, upsell e downsell (ofertas nas vendas, inclusive nas importações das plataformas); árvore NSM → outputs → inputs com a tela para ligar as métricas; meta × projetado × realizado no Planejamento; saldo mínimo de caixa (único item que muda o banco: precisa da autorização da Rebecka para aplicar em produção).

## v0.125 — Onda 2, parte 1
**Pedido da Rebecka (21/10)**: "onda 2".
**Decisões técnicas**
- A Onda 2 foi dividida em duas versões. Esta não muda o banco: as consultas novas são feitas na tela, sobre tabelas e funções que já existem, com as mesmas regras do banco (o MRR é conferido contra o painel no teste).
- Custo de entrega por produto não entra na margem de Vendas: ele não é lançado por produto. A tela diz isso e aponta Custos e margens.
- O CAC da dispersão é o das coortes por campanha (investimento ÷ clientes dos leads do período), o mesmo da tabela de cohorts; pode ser diferente do CAC do cartão, que conta todo investimento do período.
**Próximo (v0.126)**: abandono de checkout (recuperação por semana), LTV por coorte, sensibilidade do Growth Model, 2x2 de prioridade (ICE), projetado × realizado dos experimentos, desvio por canal no debriefing; e os itens que faltam da Onda 1 (CPM, CTR, CPC e frequência por semana; CAC por canal em barras; burn-up e funil da campanha; receita de novos × existentes).

## v0.124 — Data Storytelling, onda 1
**Decisões da Rebecka (21/10)**
- Aprovou a onda 1 do diagnóstico.
- Mídia: não precisa de duas telas; da campanha deve dar para abrir a tela de mídia já com os dados dela. → Mídia paga ficou como a tela única, com o relatório do Dashboard de mídia.
- Dashboard Growth: é o dashboard geral do negócio; se o novo é construído do zero, pode sair. → Saiu do menu; o endereço antigo abre o Dashboard.
- Tabelas longas (DRE, fluxo): sem resposta; aplicado o padrão sugerido (recolhidas, abrem com um clique).
**Decisões técnicas**
- Os endereços antigos (`adm-dash`, `st-dash`, `mkt-midia`) continuam funcionando e levam às telas novas, para não quebrar links salvos.
- O ritmo da meta usa as metas mensais que já existem (Planejamento anual); não foi criado campo novo.
- Nada mudou no banco nesta versão.
**Próximo (v0.125, onda 1 parte 2)**: marketing por semana (investimento, CPL, CAC), mídia (CPM, CTR, CPC, frequência; CAC por canal em barras), campanha (meta × realizado acumulado e funil com perdas), vendas e ticket por semana, receita de clientes novos × existentes.

## v0.123 — Linha no período e cadastros na campanha
**Pedidos da Rebecka (21/10)**
- Gráficos de linha, dentro do período da tela anterior, por dia, semana, mês ou ano, com opção de trocar.
- Cadastrar estratégia e etapas (e o que mais faltar) na hora de criar a campanha.
**Decisões técnicas**
- A série é calculada no banco (uma chamada), reaproveitando a conta do próprio número: o gráfico sempre bate com o número.
- O cartão "Saldo em banco" do Dashboard abre o extrato (como antes), não a árvore.
- A estratégia criada pela nova campanha guarda etapas (não blocos), mesmo com modelo pronto quando você mexe nas etapas.
**Banco em produção**: v0.120 já estava aplicada; v0.121 e v0.123 aplicadas em 21/10. A função `conexoes` continua sem publicar até existirem os apps do Meta e do Google.
