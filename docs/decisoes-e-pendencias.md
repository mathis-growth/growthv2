

## v0.140 — Pasta do cliente no Drive (Growth's Content)
**Pedido da Rebecka (25/10)**: ao cadastrar um cliente e definir que ele usa o Growth's Content, criar a pasta dele no Drive dentro de "Mathisa Growth's Content" (criada nesta data em GERAL › Mathisa › Clientes). Sem painel "Comece aqui": sem configuração, o módulo abre na primeira tela de configuração e segue tela a tela (próximas versões); configurado, abre nas abas de hoje.
Decisões:
- Acesso ao Drive por um Google Apps Script na conta da Rebecka (as pastas ficam no nome dela, sem login que expira e sem projeto no Google Cloud). O Growths chama o script com uma senha; endereço e senha ficam só em `sistema_config`, fora da API.
- Disparo pelo banco: marcar o cliente pede a pasta (gatilho + pg_net → função `content-drive`). Erro fica gravado no cliente, com "Tentar de novo". Desmarcar não apaga a pasta. Pasta com o mesmo nome já existente é reaproveitada (nunca duplica).
- Só a equipe interna marca quem usa o módulo; a lista inclui a própria Mathisa.
- Nome do módulo no menu: "Growth's Content". A pasta raiz no Drive: "Mathisa Growth's Content".
- Teste do fluxo de configuração do zero num cliente novo de teste; a Mathisa mantém a linha editorial V18.
**Pendente**: endereço do Apps Script (a Rebecka publica e envia); árvore de subpastas (a Rebecka envia; entra em `content_drive_arvore` sem mudar código); telas de configuração passo a passo.


## v0.139 — Insights automáticos; melhores dias e horários
**Pedido da Rebecka (25/10)**: um trecho de insights que diga qual conteúdo, assunto ou tema está mais relevante, o que levar para outros formatos, qual post trouxe conversa; e os melhores dias em gráfico de linha.
Decisões:
- Insights por regras sobre os números (sem IA): não inventam nada, saem na hora e cada um mostra os posts que o formam. Rótulo em cada um: Fato (está nos números), Hipótese (pode ser) ou Recomendação (o que fazer).
- Assunto: como só 1 de 36 posts da conta tem tema (fato, conferido em 25/10), o assunto sai das palavras e hashtags das legendas: palavra que aparece em pelo menos 3 posts (2, se o período tiver menos de 15 posts) e em até 60% deles, sem palavras comuns nem verbos. Rodado nos dados reais (90 dias): "eficiência" (4 posts, +23% de engajamento) em destaque; "faturamento" (3 posts, −61%) rendendo menos.
- DM depois do post: conversas novas nas 48 horas seguintes. É coincidência no tempo, por isso vem como hipótese.
- Destaques só quando passam do limite: assunto e dia +10% sobre a média; comentários, salvamentos e compartilhamentos 1,5× a taxa do período; tipo de mídia 1,3× o alcance do outro; período 15% acima ou abaixo do anterior.
- Melhores dias e horários: linha com uma série, ponto colorido pela faixa da v0.138, linha tracejada na média, quantidade de posts embaixo de cada dia; clicar no ponto mostra os posts.
**Pendente (recomendação)**: as palavras da legenda são uma pista, não o tema. Próximo passo possível: a IA ler as legendas e sugerir a frente e o formato de cada post para a Rebecka confirmar, o que deixa os gráficos por tema completos.


## v0.138 — Cores pela média; quadros; menu em níveis
**Pedido da Rebecka (25/10)**: gráficos com cores (piores em vermelho, na média em azul, bem melhores em verde), para ver e rastrear o dado; cada gráfico num quadro com contorno; menu com recuo por nível. Aprovou a prévia em 25/10.
Decisões:
- Faixa de 10%: abaixo de 90% da média = vermelho; de 90% a 110% = azul; acima de 110% = verde. Média de referência: em "Média por post", a média de todos os posts do período (engajamento = interações somadas ÷ alcance somado); em "Total do período" e "Quantidade de posts", a média entre os grupos.
- A cor nunca é a única pista: cada barra traz o texto "+22% vs. média" e a legenda fica no topo do quadro.
- Rastrear: clicar na barra filtra a galeria para os posts que formam aquele número (já existia; agora o aviso diz isso).
- Menu: o recuo vale para todos os grupos. A Rebecka vai definir depois os outros menus e submenus.


## v0.137 — Galeria de posts e gráficos de tema e formato
**Pedido da Rebecka (25/10)**: ver na tela principal as imagens dos posts, os 4 principais, com "mostrar mais"; ordenar por curtidas, engajamento, alcance e mais recentes; gráficos de temas e de formato que mudam pelo filtro.
Decisões:
- A galeria fica logo depois dos números dos posts; os gráficos, logo depois da galeria. Nada saiu da tela (Top 1, gráficos por dia, agrupamentos, top 10 e tabela continuam abaixo).
- 4 posts de início; cada "Mostrar mais" abre mais 8; "Mostrar menos" volta para 4. Trocar a ordem ou o período volta para 4.
- Gráficos: tema (frente), formato e tipo de mídia, lado a lado. A métrica e a forma de contar (média por post, total do período, quantidade de posts) são escolhidas no próprio quadro, sem mexer no resto da tela.
- Clicar numa barra filtra a galeria (clicar de novo, ou "Mostrar todos", tira o filtro).
**Limite (fato, conferido em 25/10)**: as imagens vêm do Instagram com link que vence em cerca de 4 dias; a sincronização diária troca os links de todos os posts. Se a sincronização parar mais de 4 dias, o cartão mostra o tipo e o título do post no lugar da imagem.


## v0.136 — Instagram como submenu; sem importação
**Pedido da Rebecka (25/10)**: Instagram como submenu dentro da Máquina de Conteúdo; o que se repete no Instagram não precisa estar na Máquina; na Máquina, um dashboard geral de todos os canais (eficiência e melhores posts de cada canal, clicando cai no canal); nada de importar ou digitar à mão; tirar Relatórios; no Instagram, um dash da conta (insights gerais), de cada post e dos melhores por tema e formato. E: "continua sem trazer nenhuma informação".
**Diagnóstico de "sem informação" (fato, conferido no banco de produção em 25/10)**: os dados existem só no cliente **Mathisa — Operação** (conta @rebecka.mkt): 36 posts, 89 dias de alcance da conta, DMs. O dashboard desse cliente devolve 21 posts nos últimos 30 dias e 795 seguidores. Se a tela mostra vazio, a hipótese mais provável é estar em outro cliente (seletor no topo do menu) ou numa versão antiga do site. Agora a tela diz qual conta está conectada, quando atualizou e, se a conta estiver em outro cliente, em qual.
Decisões:
- Menu: Marketing → Máquina de Conteúdo → Estratégia de conteúdo | Instagram. A aba Dashboard da Estratégia é a primeira.
- Sem importação: os botões de importar planilha e de digitar números saíram da tela. As funções do banco continuam (não apagamos nada), mas nada na tela as chama.
- Relatórios saiu da tela (fica para outra função depois, como ela pediu).
- Classificar o post: post que não nasceu na Máquina pode receber frente e formato direto (`social_posts.tema_id`, `formato_id`). Se o post estiver ligado a um conteúdo da Máquina, vale a classificação do conteúdo.
- Eficiência por canal (hoje só Instagram tem dados): posts, alcance, interações, engajamento (interações ÷ alcance) e ideias na fila do canal.
**Limites (fato)**: o Zernio entrega o alcance da conta por dia, mas os seguidores só como foto do dia em que sincroniza (1 dia até agora) e não entrega visitas ao perfil nem novos seguidores. Esses quadros mostram "—" até haver dias suficientes; o gráfico de seguidores vai se formar dia a dia.
**Pendente**: conferir se o Zernio tem histórico de seguidores (estatística de seguidores da conta) para preencher o passado; confirmar com a Rebecka a URL do site e o cliente selecionado.


## v0.135 — Estratégia e canais; DMs no CRM
**Pedido da Rebecka (25/10)**: separar a Máquina em Estratégia de conteúdo (tudo o que se define: ideias, canais por tema e etiqueta) e uma parte por canal (hoje só Instagram: dashboard, relatórios, ideias e as DMs); DMs também no comercial, porque entram no CRM; e descobrir por que os dados não apareciam.
**Por que não aparecia (fato, conferido no banco com o login dela)**: (1) os posts e os números da conta estavam no banco (36 posts, 89 dias), mas só aparecem na aba Instagram da tela v0.134+; as telas antigas leem as métricas digitadas na Máquina, que estavam vazias. (2) As DMs nunca chegavam: a função `registrar_dm_instagram` existia, mas nada a chamava; o `zernio-sync` só trazia posts e conta. O Zernio tem as conversas (Inbox API).
Decisões:
- DMs entram a cada 30 minutos. Quem escreve para a conta entra no CRM como lead (função já criada antes: origem `instagram_dm`, etiqueta "DM Instagram", cada mensagem recebida vira um toque). Conversa só com mensagens enviadas por ela não cria lead.
- Conversas pessoais: botão "Não é lead" para de levar as mensagens ao CRM. A pessoa que já entrou continua no CRM (excluir é manual, para não apagar nada por engano).
- Primeira carga: conversas dos últimos 90 dias, até 60 conversas com mensagens novas por rodada e até 100 mensagens por conversa; o resto entra nas rodadas seguintes.
- Canais: canal padrão por frente e por etiqueta só **sugerem** (marcam ao criar a ideia; nunca desmarcam). "Canais em uso" decide quais canais aparecem como parte da Máquina.
**Pendente**: conferir depois da primeira rodada quantas conversas viraram leads e marcar as pessoais como "não é lead".

## Produção — 25/10/2026
- Aplicado no Supabase: v0.132 (`assistente_alertas` e `assistente_alertas_agendador`: pg_cron `growths-alertas` no minuto 7 de cada hora, `sistema_config.avisos_url`), funções `avisos` (sem verificação de JWT), `perguntar` (nova versão) e `linha-editorial`. A v0.133 e a v0.134 já estavam no banco, idênticas aos arquivos (conferido função por função).
- Alertas ligados para **Mathisa — Operação** (resumo às 7h). **Ninguém da equipe desse cliente está marcado com acesso ao sistema**, então os alertas são gravados mas ainda não viram aviso: marcar as pessoas em Alertas e resumo do dia (ou em Equipe).
- Máquina V18 já instalada na Mathisa — Operação; o dashboard do Instagram já lê os 36 posts da conexão existente.
- Falta: segredos de e-mail (`RESEND_API_KEY`, `AVISOS_EMAIL_DE`), WhatsApp (`WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, modelo aprovado) e IA (`ANTHROPIC_API_KEY` e/ou `OPENAI_API_KEY`); publicar o `index.html` v0.134 no site.

## v0.134 — Dashboard do Instagram
**Pedido da Rebecka (24 e 25/10)**: uma aba de dashboard do Instagram dentro da Máquina, com insights, o top 1, os melhores conteúdos, os números de cada post e tudo separado por tema/território, para ver em gráficos.
Decisões:
- Fica como aba **Instagram** da Máquina de Conteúdo e como atalho **Marketing → Instagram**.
- Três fontes, sem contar duas vezes: conexão com a Meta (quando aprovada), **planilha importada** (Meta Business Suite ou Metricool, que ela já usa sem plano pago; o Metricool gratuito não tem API) e as métricas registradas nas publicações da Máquina. Se um post real está ligado ao conteúdo, a métrica digitada no conteúdo deixa de contar.
- **Ligação post ↔ conteúdo da Máquina** é o que permite ver por território, frente, formato, quadro, destino e etiqueta. Automática só quando não há dúvida (1 post e 1 conteúdo do Instagram no mesmo dia); o resto se liga no próprio post.
- Engajamento = (curtidas + comentários + compartilhamentos + salvamentos) ÷ alcance (o mesmo dos Relatórios). Médias por grupo: engajamento ponderado pelo alcance; demais métricas, média por post. Comparação sempre com o período anterior de mesmo tamanho.
- Datas da planilha: dia/mês ou mês/dia é decidido pelos dados (dia > 12); sem como decidir, cabeçalho em inglês = mês/dia. A prévia mostra como leu antes de importar.
**Pendente**: rodar `RODAR_v0.133_maquina_conteudo.sql` e `RODAR_v0.134_instagram.sql` em produção; aprovação do app da Meta para a conexão automática (horário dos posts por hora e miniaturas só vêm com ela ou se a planilha trouxer).

## v0.133 — Máquina de Conteúdo
**Pedido da Rebecka (24/10)**: o menu de conteúdo passa a se chamar Máquina de Conteúdo; padronizar no Growths a linha editorial V18 (Estratégia, Negócios — com Empreendedorismo registrado —, Dados + IA e Vida Real & Crenças), os formatos (No Quadro, Yap Content, Análise, Carrossel caderno com animações e a série musical sertaneja feita com IA, 1× por semana), destino, palavra-chave, critérios, fechamento semanal, etiquetas e dias da semana, tudo dentro do Growths, sem planilha; e um questionário de persona para a IA montar a linha editorial pelo método dela.
Decisões:
- **Fato**: territórios, frentes de Estratégia e Negócios, formatos de autoridade, destinos, score de 6 critérios, meta de 12 e fechamento no sábado vêm do documento "Linha Editorial V18" e da "Metodologia Própria" (Drive). **Organização (editável)**: a V18 lista os temas de Dados + IA e de Vida Real & Crenças num parágrafo só; agrupei em 4 e 5 frentes. A descrição de Empreendedorismo, do Carrossel caderno e da Série musical foi escrita a partir do pedido (não estão na V18).
- O "formato" antigo (reels, carrossel, story…) continua e virou **tipo de mídia**; o formato da Máquina é uma tabela nova (`conteudo_formatos`), editável por cliente. Os 4 formatos de autoridade da seção 15 da V18 (Repertório de Funis, Business Case, Analisando os Dados de um Funil, Growth na Prática) entram como **quadros**, opcionais na pauta.
- Dois métodos de nota convivem por cliente: o antigo (5 notas de 1 a 10) e o **score V18** (6 critérios de 1 a 5). Instalar a V18 ou aplicar uma proposta liga o score; dá para voltar em Linha editorial. As notas antigas ficam guardadas.
- **VALIDAR é obrigatório para produzir** no score V18 ("a validação humana faz parte da metodologia"); o ranking nunca desmarca o VALIDAR.
- O modelo V18 é **instalado por botão** (função `conteudo_instalar_v18`), não fixo no código: outros clientes podem ter a linha deles. Instalar ou aplicar uma proposta **não apaga nada** (cria/atualiza pelo nome).
- A proposta da IA fica como "proposta" até alguém clicar em Aplicar. A IA só usa o que está no questionário e lista o que faltou ("pendências"); nada inventado.
- Fechamento: antes do dia do fechamento, a tela abre a semana anterior; no dia (sábado) ou depois, a semana atual. Fechar guarda uma foto dos números daquele momento.
**Pendente**: rodar `RODAR_v0.133_maquina_conteudo.sql` em produção, publicar `linha-editorial` e instalar o V18 no cliente da Rebecka. Dashboard do Instagram (v0.134) vem a seguir, lendo `social_posts`/`social_perfis_dia` (Meta) com importação manual enquanto o app da Meta não é aprovado. Radar diário automático continua não conectado.

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
