# Growths

Central de gestão e inteligência de crescimento para negócios digitais (infoprodutores e prestadores de serviço), da Mathisa. Num só sistema, multi-cliente (cada cliente é um workspace isolado), o Growths reúne:

- captação de leads com UTMs;
- CRM, vendas, contratos e comissões;
- contabilidade gerencial (partidas, DRE e fluxo de caixa);
- campanhas e mídia paga;
- RevOps e Growth Model;
- a "árvore dos números", que mostra de onde vem cada número da tela.

Este repositório é o **lugar padrão de salvar as mudanças**. Cada entrega vira um commit, e o registro de cada versão fica na tabela abaixo. O detalhe completo de cada versão está em [CHANGELOG.md](CHANGELOG.md).

## Estado atual

| | |
|---|---|
| **Versão da tela** | 0.170 · 29/10/2026 (`index.html`) |
| **Banco em produção** (Supabase `yngyghlyonybvfvjcmxl`) | até a **v0.156** (26/10/2026): dicionário de métricas com direção e referência; alertas, Máquina de Conteúdo, dashboard e DMs do Instagram; funções `avisos`, `perguntar`, `linha-editorial` e `zernio-sync` (posts, conta e DMs); crons `growths-alertas` (hora em hora), `zernio-sync-diario` e `zernio-dms` (a cada 30 min) |
| **Falta aplicar no banco** | `supabase/RODAR_v0.157_narrativas.sql` (banco de narrativas; sem ele, as frases do Financeiro não aparecem) e `supabase/RODAR_v0.159_content_simples.sql` + `supabase/RODAR_v0.160_content_segmentos.sql` (Growth's Content; sem eles, as abas novas avisam) |
| **Falta publicar** | a função `conexoes` (sem verificação de JWT), quando os apps do Meta e do Google existirem |
| **Falta configurar** | app do Meta; crédito na conta da API da Anthropic (a chave `ANTHROPIC_API_KEY` está cadastrada e funciona, mas as pesquisas de 25 e 26/10 voltaram com "credit balance is too low"); o app do Google já existe (segredos conferidos em 25/10/2026): [docs/conectar-meta-e-google.md](docs/conectar-meta-e-google.md) |

## Registro de versões

Cada linha é uma entrega. **Banco** diz se a versão mudou o banco e se já está em produção.

| Versão | Data | O que mudou | Banco |
|---|---|---|---|
| 0.170 | 29/10/2026 | **Criar a estratégia pelo mapa**: "Criar no mapa" abre um mapa em branco; ao publicar, dá o nome e a estratégia entra na lista com as etapas montadas (versão 1). | Sem mudança no banco |
| 0.169 | 29/10/2026 | **Lixeira nos cards do Canvas**: um clique exclui o bloco, e o mapa oferece Desfazer por 8 segundos. | Sem mudança no banco |
| 0.168 | 29/10/2026 | **Canvas por fase**: o funil inteiro num mapa só, com cor e faixa por fase (Captação, Aquecimento, Vendas, Pós-venda/CS) e legenda que destaca uma fase. Correção: trocar de workspace com uma estratégia aberta gravava os blocos no workspace errado. | Sem mudança no banco |
| 0.167 | 29/10/2026 | **Ajustar os cards do Canvas**: arrastar o card por qualquer ponto (encaixa na grade), mudar o tamanho de cada card pelo canto e botão **Organizar** (colunas por fase, sem encostar). | Sem mudança no banco |
| 0.166 | 29/10/2026 | **Desenhos no Canvas**: cada bloco mostra o que é (mini página com foto e textos, anúncio com o símbolo da Meta ou do Google, WhatsApp com a escolha API ou Grupo, vídeo, e-mail, lógica). | Sem mudança no banco |
| 0.165 | 29/10/2026 | **Strategy Canvas (S1 a S3)**: Marketing → Estratégias (Canvas) com biblioteca (categoria, versão, situação), mapa visual da estratégia (arrastar blocos, ligar com sim/não/divisão, painel de propriedades) e vista em lista; **versões** publicadas, e cada campanha guarda a versão que usou. | `20261124100000_strategy_canvas.sql` — aplicado em produção |
| 0.164 | 29/10/2026 | **Cockpit** na entrada do Growths: um painel compacto por área (Geral, Marketing, Vendas, Financeiro, Projetos, Growth e Clientes), dois lado a lado, com os números principais do período e um gráfico (7 dias, 30 dias, mês, ano); clicar no painel abre o dashboard do módulo. Cada painel só aparece para quem tem acesso ao módulo. | Só tela |
| 0.163 | 29/10/2026 | **Customer Growth (RevOps)**: cada produto ganha a sua **Jornada do produto** (etapas com versão; ao publicar, quem já está dentro continua ou é transferido; modelos de jornada); Alunos com seletor de jornada e lista de todos os produtos; **marcos** manuais, automáticos ou com confirmação (compra, vídeo, pesquisa, etapa, grupo, evento da plataforma do curso); seção **Jornada e evolução** na ficha, por produto; pesquisa que dispara na etapa do aluno e **check-in a cada N dias**; **alertas de CS** de hora em hora; **intervenções de CS** (tabela própria, também em Minhas atividades); oportunidades de expansão e retenção ligadas à matrícula; tela **RevOps → Customer Growth** com Evolução, Check-ins, Alertas e intervenções, Retenção e expansão e Indicadores. | Aplicado em produção em 29/10/2026; alertas de CS ligados |
| 0.162 | 29/10/2026 | **Mapa de métricas com a North Star em destaque**: NSM com estrela, valor grande e frequência; as filhas dela aparecem em "Alavancas que movem a NSM", com o papel (Driver/Input) e a variação ao lado do valor; na NSM o botão vira "+ Alavanca". | Só tela |
| 0.161 | 26/10/2026 | **Pesquisa must-have da consultoria** (modelo em Pesquisas, 25 perguntas em 6 passos) e leitura do must-have em três faixas nos Resultados. | Só tela |
| 0.160 | 26/10/2026 | **Produção = Kanban com calendário** e a aprovação em cada cartão; **Linha editorial** com subtemas e conteúdos por segmento; ideia aprovada com tema, subtema, formato e data. | `RODAR_v0.160_content_segmentos.sql`, **ainda não aplicado** |
| 0.159 | 26/10/2026 | **Growth's Content simplificado**: cinco abas (Base do cliente, Identidade visual, Ideias, Produção, Mais ferramentas), ficha do dossiê com versões, identidade com prévia, roteiro aprovado antes da peça, versões e ajustes. Botões da Claude desligados até haver crédito na API. | `RODAR_v0.159_content_simples.sql`, **ainda não aplicado** |
| 0.158 | 26/10/2026 | **Telas em grade**: Dashboard e Dashboard financeiro em blocos lado a lado, gráficos no tamanho do bloco, uma coluna no celular. Backup antes: branches `backup-v0.157` e `backup-v0.156`. | Só tela |
| 0.157 | 26/10/2026 | **Banco de narrativas**: as frases de análise passam a morar na tabela `narrativa_modelos` (código, versão, aprovação, histórico); a tela só preenche números calculados. Piloto no **Dashboard financeiro**: frase da cascata com "sobraram/faltaram", ponte do resultado (mês anterior → atual), caixa projetado e saldo mínimo num painel só. Dicionário mostra as frases. | `RODAR_v0.157_narrativas.sql`, **ainda não aplicado** em produção |
| 0.156 | 26/10/2026 | **Alertas em quatro categorias** (favorável, desfavorável, atenção, informativo) e **Dicionário de métricas** com unidade, direção, zero como limite e referência. | `RODAR_v0.156_metricas_semantica.sql`, aplicado em 26/10/2026 |
| 0.155 | 26/10/2026 | **Contexto e frase-recado** no Financeiro, Marketing e Vendas (contra o período anterior, com a base escrita); custos neutros. | Só tela |
| 0.154 | 26/10/2026 | **Gráficos**: negativos na escala (dois gráficos do Financeiro voltaram), cascata com custos neutros e resultado com sinal, meta e saldo mínimo como linha de referência, séries sem verde/vermelho. | Só tela |
| 0.153 | 26/10/2026 | **Cor pelo significado em todas as telas**: zero como limite só nos saldos, variações pela direção com tolerância de 5%, cores de status novas, sem neon nos números, sinal de menos verdadeiro. | Só tela |
| 0.152 | 26/10/2026 | **Data Storytelling no Dashboard (piloto)**: camada semântica (tokens, dicionário, formatador), receita com a variação das vendas, lucro em reais e vermelho, escala única nos cartões, mês cheio contra mês cheio. | Só tela |
| 0.151 | 25/10/2026 | **Pesquisa com um botão** (pastas + call + produtos + canais + web, relatório para ler) e o **dossiê** em seções. | `RODAR_v0.151_content_pesquisa.sql` + função `content-pesquisa`, aplicado em 25/10/2026 (falta a chave da API e reimplantar o Apps Script) |
| 0.150 | 25/10/2026 | **Ficha de produto simples** (nome, valor, histórico) no Growth's Content e o bloco **Produtos e esteira** no questionário da call. | `RODAR_v0.150_content_produtos_v2.sql`, aplicado em 25/10/2026 |
| 0.149 | 25/10/2026 | **Produtos na Estratégia de conteúdo**: ficha de conteúdo de cada produto (público, dor, transformação, método, provas, objeções, momento de venda) e ideias ligadas a um produto. | `RODAR_v0.149_content_produtos.sql`, aplicado em 25/10/2026 |
| 0.148 | 25/10/2026 | **Painel da produção no Kanban**: total por etapa, prontos da semana contra a meta e calendário das próximas semanas (completas ou quanto falta). | Só tela |
| 0.147 | 25/10/2026 | **Só a pasta do cliente** (sai o Drive da Mathisa), **outras pastas que o cliente já tem** no passo 1 e **Pastas da Mathisa** (padrões) numa tela interna. | `RODAR_v0.147_content_pastas.sql`, aplicado em 25/10/2026 |
| 0.146 | 25/10/2026 | **Estruturas de roteiro e copy** (biblioteca interna; o cliente só escolhe por formato) e **Custos de IA** (só para a Rebecka). | `RODAR_v0.146_content_estruturas.sql`, aplicado em 25/10/2026 |
| 0.145 | 25/10/2026 | **Canais e materiais do cliente antes da call**: configuração em 9 passos; o cliente informa o @ de cada plataforma e resolve seis tipos de material, cada um com a sua pasta. | `RODAR_v0.145_content_fontes.sql`, aplicado em 25/10/2026 |
| 0.144 | 25/10/2026 | **Configuração em 8 passos**: o cliente **compartilha uma pasta do Drive** dele e o Growths cria a árvore de 10 pastas (gratuito); roteiro da **call de briefing** na tela; lista de **materiais**; pesquisa, tese e dossiê em construção. | `RODAR_v0.144_content_setup_v2.sql` + função `content-drive`, aplicado em 25/10/2026 |
| 0.143 | 25/10/2026 | **Growth's Content começa pela configuração**: passo a passo de 5 telas antes das abas; passo 1 **conecta o Google Drive do cliente** e cria lá a pasta (sem Drive, no da Mathisa). | `RODAR_v0.143_content_setup.sql` + função `content-google`, aplicado em 25/10/2026 |
| 0.142 | 25/10/2026 | Corrigido: cliente do **Growth's Content** ficava como Growth Starter (sem o Marketing); agora vira Growths completo, com aviso. | Só tela |
| 0.141 | 25/10/2026 | **Novo cliente** com "O que o cliente acessa" em árvore (setinhas, tela por tela, atalhos); **Growth's Content dentro de Marketing** libera só o módulo e cria a pasta no Drive; Instagram e DMs no catálogo dos pacotes. | `RODAR_v0.141_acesso_content.sql`, aplicado em 25/10/2026 |
| 0.140 | 25/10/2026 | Módulo renomeado para **Growth's Content**; "Usa o Growth's Content" no cliente cria a **pasta do cliente no Google Drive** (Apps Script), com link no topo do módulo. | `RODAR_v0.140_content_drive.sql` + função `content-drive`, aplicado em 25/10/2026 |
| 0.139 | 25/10/2026 | **Insights automáticos** no Instagram (assunto que mais engaja, o que levar para outros formatos, post que puxou conversa, DMs, salvos, compartilhados, melhor dia), cada um como fato, hipótese ou recomendação e com os posts que o formam; **melhores dias e horários** em linha. | Só tela, sem banco |
| 0.138 | 25/10/2026 | **Cores pela média** nos gráficos de tema, formato e tipo (verde acima, azul na média, vermelho abaixo, com "+X% vs. média"); cada gráfico num quadro; **menu em níveis** com recuo. | Só tela, sem banco |
| 0.137 | 25/10/2026 | **Os posts em imagens** no dashboard do Instagram (4 primeiro, Mostrar mais, ordenar por engajamento, curtidas, alcance, recentes…) e **gráficos por tema, formato e tipo de mídia** com filtro de métrica e de contagem; clicar na barra filtra a galeria. | Só tela, sem banco |
| 0.136 | 25/10/2026 | **Instagram vira submenu da Máquina de Conteúdo**; dashboard geral de canais (eficiência e melhores posts por canal); dashboard do Instagram só com dados da conexão (conta, cada post, melhores por frente, formato e tipo); classificar o post direto; saem importação manual e Relatórios. A tela mostra qual conta está conectada e em qual cliente. | `RODAR_v0.136_instagram_classificar.sql`, aplicado em 25/10/2026 |
| 0.135 | 25/10/2026 | **Máquina em duas partes**: Estratégia de conteúdo (com a aba **Canais**: canal por frente e por etiqueta) e **Instagram** (Dashboard, Ideias do canal, Relatórios, **DMs**). **DMs do Instagram** trazidas a cada 30 min; quem escreve vira lead no CRM; também em Vendas → DMs do Instagram. Corrigido: as DMs nunca chegavam. | `RODAR_v0.135_dms_canais.sql` + `zernio-sync`, aplicado em 25/10/2026 |
| 0.134 | 25/10/2026 | **Dashboard do Instagram** (aba da Máquina e atalho em Marketing): indicadores contra o período anterior, top 1, gráficos por dia, o que performa melhor por território, frente, formato, tipo, destino, etiqueta, dia e horário, melhores posts e cada post contra a média; importação da planilha do Meta Business Suite ou do Metricool até a Meta aprovar. | `RODAR_v0.134_instagram.sql`, aplicado em 25/10/2026 |
| 0.133 | 24/10/2026 | **Máquina de Conteúdo** (antes Planejamento de conteúdo): modelo V18 por botão (4 territórios com Empreendedorismo em Negócios, 5 formatos com Carrossel caderno e Série musical 1× por semana, quadros, destinos Rebecka/Mathisa/Ambas), pauta com palavra-chave, score de 6 critérios e VALIDAR, etiquetas e dia da semana; matriz território × formato, semana por dia, fechamento de sábado, questionário de persona com proposta de linha editorial pela IA. | `RODAR_v0.133_maquina_conteudo.sql` + edge function `linha-editorial`, aplicado em 25/10/2026 |
| 0.132 | 24/10/2026 | **Pergunte ao Growths**: "como foi meu dia ontem?" com os números exatos do dia e a comparação; IA com o dia a dia. **Alertas e resumo do dia**: conferência de hora em hora (mudança brusca, se repetindo, pede ação, dia sem dados), resumo de ontem toda manhã, avisos no sino, e-mail (Resend) e WhatsApp (Meta). | `RODAR_v0.132_alertas.sql` + `RODAR_v0.132_agendador.sql` + edge functions, aplicado em 25/10/2026 |
| 0.131 | 21/10/2026 | **Selo de qualificado** (verde/vermelho com a pontuação) no cartão, na ficha e na lista de leads; **tags coloridas**; aba **"Quem respondeu"** na pesquisa, com a pontuação de cada pessoa, situação no CRM, filtro e planilha. | não muda o banco |
| 0.130 | 21/10/2026 | **Formulário de captação nas Pesquisas**: aba "Formulário e aparência" com passos, link para enviar (com UTM e WhatsApp), contato que entra ou é atualizado no Funil de leads (etapa, tags, responsável, sem duplicar), aviso e confirmações gravadas, fontes e cores do cliente com pré-visualização; modelo pronto do diagnóstico de qualificação da Mathisa com a oferta sugerida como tag. | `RODAR_v0.130_formulario.sql`, aplicado |
| 0.129 | 21/10/2026 | **Movimento por dia da campanha num gráfico só**, com botões para escolher as métricas; **qualificação por pontos nas pesquisas** (pontos e tags por resposta, soma ou média, nota de corte, faixas, simulador; qualifica ao responder e no recalcular). | `RODAR_v0.129_qualificacao.sql`, aplicado |
| 0.128 | 21/10/2026 | **Painel da campanha, dia a dia**: quadrinhos verde/vermelho de cada dia contra a meta (investimento, CTR, CPC, leads, CPL, vendas, receita); onde caiu (7 dias × 7 anteriores, etapa por etapa); movimento por dia; vendas por dia, produto e oferta; quanto foi e o que trouxe cada vídeo/criativo. | não muda o banco |
| 0.127 | 21/10/2026 | **Onda 3**: receita por papel da oferta (order bump, upsell, downsell) em Vendas e a oferta na importação; meta × realizado acumulado do plano e a projeção dos cenários aprovados; saldo mínimo de caixa no Financeiro e aviso no Dashboard. | `RODAR_v0.127_saldo_minimo.sql`, aplicado |
| 0.126 | 21/10/2026 | **Fecha a Onda 2 e completa a Onda 1**: abandono e recuperação no tempo; LTV por coorte; o que mais mexe no lucro (Growth Model); o que testar primeiro (ICE 2x2); antes × depois dos experimentos; desvio da meta e funil com perdas no fechamento; vendas acumuladas × meta; CPM, CTR, CPC, frequência e CAC por canal na Mídia paga; investimento, CPL e CAC no tempo; receita de novos × existentes. | não muda o banco |
| 0.125 | 21/10/2026 | **Onda 2, parte 1**: observações no Dashboard (fato, conta, hipótese, investigar); resultado × dinheiro no banco; vencimentos por semana e faixas de atraso em Contas a receber e a pagar; MRR mês a mês com novos, expansão, redução e cancelados; vendas, ticket e margem por produto; CAC × clientes por campanha; leads por origem até a compra. | não muda o banco |
| 0.124 | 21/10/2026 | **Gráficos com função (onda 1)**: componente único de gráficos; **Dashboard** vira o dashboard geral do negócio (receita, lucro e margem por mês; ritmo da meta do mês; receita por produto e campanha contra o período anterior; DRE e fluxo recolhidos) e **substitui o Dashboard Growth**; **uma tela só de mídia** (Mídia paga, com o Relatório de mídia) e **campanha → Ver na Mídia paga** já filtrada; Financeiro com **cascata do resultado** e linha mensal sem meses futuros; Custos e margens com **receita × equilíbrio × cenários** e **custo por área × mês anterior**. | não muda o banco |
| 0.123 | 21/10/2026 | **Gráfico de linha** no painel de cada número, dentro do período da tela, com Dia/Semana/Mês/Ano (substitui o da 0.122). **Nova campanha**: cadastrar produto, estratégia (com as etapas) e canal sem sair dela; Nova estratégia com escolha das etapas por fase. | `RODAR_v0.123_arvore_serie.sql`, aplicado |
| 0.122 | 21/10/2026 | **Mini gráfico em cada número da árvore**: evolução por mês, cascata, composição (rosca), barras por dia ou medidor, escolhido pelo tipo do número; série dos últimos meses para CAC, CPL, ROAS, margem e outros; clicar no gráfico desce o nível. | não muda o banco |
| 0.121 | 21/10/2026 | **Visual**: claro como padrão (escuro como opção), verde no que é bom e vermelho no negativo com brilho neon, cartões em 3D, uma ação principal por tela. **Dashboard em camadas** (4 cartões grandes com tendência + cartões menores com números compactos). **Nova campanha em 3 etapas** (o básico; orçamento e metas; canais), faixa de rascunho com o que falta, "começa em" para campanha que não começou, Editar campanha em blocos com Ctrl+S, Growth Model com "Mais ações". Correção: "Por vendedor" na árvore. | `RODAR_v0.121_arvore_vendedor.sql`, aplicado |
| 0.120 | 20/10/2026 | **Comissões**: vendedor, coprodutor, estrategista e parceiro; regras por projeto, campanha, produto ou oferta; base líquida ou bruta; pagamento mensal, por venda ou só relatório; fechamento do mês em contas a pagar; estornos. A configuração fica em Configurações → Comissões e o acompanhamento em Vendas → Comissões. **Conexões** com Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube) por login oficial. | `RODAR_v0.120_comissoes_conexoes.sql`, aplicado |
| 0.119 | 20/10/2026 | Árvore, parte 4: cards de Custos e margens (montados no navegador), tabelas de Mídia paga, origem do recebimento; MRR de Contas a receber no horário de São Paulo. Scripts RODAR que podem ser colados de novo sem erro. | aplicado |
| 0.118 | 20/10/2026 | Árvore, parte 3: números das tabelas (Campanhas ativas e coortes); venda e conta a pagar como passos da árvore; caixa projetado em 30 dias, novos em 30 dias e a qualificar. | aplicado |
| 0.117 | 20/10/2026 | Árvore, parte 2: lançamento contábil, LTV, churn, NRR, GRR, penetração, contas a receber e a pagar, contratos. | aplicado |
| 0.116 | 20/10/2026 | Árvore dos números: clicar num número abre a conta que o gerou, nível por nível. | aplicado |
| 0.115 | 19/10/2026 | Detalhe dos cards da campanha (por canal, por dia, qualificação, anúncios). | aplicado |
| 0.114 | 19/10/2026 | Meta de leads por dia, por mês e por canal; gráficos menores; taxas do funil. | aplicado |
| 0.113 | 17/10/2026 | Receber leads de formulários (função `leads`). | aplicado |
| 0.112 e anteriores | até 17/10/2026 | Ver [CHANGELOG.md](CHANGELOG.md). | aplicado |

**Para registrar uma versão nova**:

1. Acrescente a linha no alto da tabela.
2. Atualize o "Estado atual".
3. Escreva o detalhe no `CHANGELOG.md` e nos docs.
4. Faça o commit com a mensagem `vX.YYY — título`.

## Estrutura

```
index.html                o Growths (tela, um arquivo só) — é o que vai para o ar
_headers                  cabeçalhos do Cloudflare Pages
CHANGELOG.md              histórico detalhado de cada versão
docs/
  visao-geral.md          o que o sistema faz, versão a versão
  growths-o-sistema.md    todas as funcionalidades explicadas (documento vivo, base de conteúdo)
  regras-de-negocio.md    como cada número é calculado
  modelo-de-dados.md      tabelas, funções e views
  decisoes-e-pendencias.md decisões tomadas e o que falta
  como-rodar-o-banco.md   o que rodar no Supabase, em ordem
  registro-de-implementacao.md como foi feito e testado
  guia-de-versionamento.md como numerar e registrar versões
  conectar-meta-e-google.md passo a passo dos apps do Meta e do Google
  publicar-cloudflare.md  publicar a tela
  estrutura/              dicionário de campos e estrutura
supabase/
  migrations/             cada mudança de banco, em ordem de data
  RODAR_v*.sql            o mesmo conteúdo, pronto para colar no SQL Editor
  functions/              edge functions (leads, ideias, perguntar, conexoes)
  seed/                   dados fictícios (Escola Aurora e demonstração)
tests/
  auditoria/              testes de tela (Playwright) e de banco, por versão (tNNN_*.py)
  edge/                   testes das edge functions (Deno)
lovable/                  material de apoio
```

## Segurança

- O `index.html` leva só o endereço do Supabase e a chave pública (anon). Quem protege os dados é o RLS e as permissões por módulo, no banco.
- Segredos (tokens do Meta e do Google, chaves de IA e o segredo do agendamento) **nunca** entram no repositório. Eles ficam em Edge Functions → Secrets, no Supabase, e os tokens das conexões ficam no schema `privado`.
- O repositório é público: se for guardar dados reais de cliente aqui, torne-o privado antes.
