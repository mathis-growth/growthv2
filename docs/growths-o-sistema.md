# Growths: o sistema, explicado

**Documento vivo.** Atualizado a cada entrega do Growths.
**Última atualização:** 29/10/2026, versão 0.165.

Este documento conta o que o Growths faz, para quem e por quê, área por área, em linguagem simples. Ele não descreve tabelas nem código: descreve funcionalidades, decisões e a lógica por trás delas. Serve de base para criar conteúdo sobre o Growths, a Mathisa e o jeito Mathisa de fazer growth.

---

## 1. O que é o Growths

O Growths é a central de gestão e inteligência de crescimento da Mathisa para negócios digitais: infoprodutores, mentores, escolas online e prestadores de serviço.

Num sistema só, cada cliente tem o seu espaço isolado (um "workspace"). Ali estão:

- **captação de leads**, com origem e UTMs;
- **CRM e vendas**, contratos e comissões;
- **financeiro com contabilidade de verdade**: partidas dobradas, DRE e fluxo de caixa;
- **campanhas e mídia paga**;
- **conteúdo**, com o módulo Growth's Content;
- **RevOps**: retenção, recompra e expansão;
- **Growth Model**, cenários e experimentos;
- **pesquisas e formulários de qualificação**;
- **projetos e equipe**;
- uma camada de **inteligência**: perguntas em português, alertas, insights e a "árvore dos números".

A ideia central: o dono do negócio e a consultoria olham para os mesmos números, com a mesma definição, e cada número pode ser aberto até a origem.

### Para quem

- **Para a Mathisa** (equipe interna): atender vários clientes num lugar só, com o mesmo método, os mesmos indicadores e a mesma qualidade de dado.
- **Para o cliente**: enxergar o próprio negócio por inteiro (marketing, vendas, caixa, lucro, retenção e conteúdo) sem planilha solta e sem número que não fecha.
- **Duas formas de uso**:
  - **Growths completo**, com todos os módulos.
  - **Growth Starter**, uma versão enxuta para consultoria, com Dashboard, Aquisição, Mídia, Vendas, Retenção, Produtos, Clientes, Financeiro, Relatórios e Experimentos.

### O que torna o Growths diferente

- **Nada de número inventado.** Quando falta dado, aparece "sem dado" ou "indisponível", nunca zero. A IA não consulta o banco solta: recebe um resumo já calculado, e cada número da resposta é conferido.
- **Fato, conta, hipótese e recomendação separados.** Observações, insights e alertas dizem o que é fato medido, o que é a conta, o que é hipótese e onde investigar.
- **Árvore dos números.** Clicar em qualquer número abre a conta que o gerou, nível por nível, até a venda, a conta a pagar ou o lançamento contábil.
- **Uma definição por métrica.** Um dicionário oficial define cada indicador (fórmula, fonte e o que acontece sem dado). Lucro, CAC, ROAS e receita são os mesmos em todas as telas.
- **Contabilidade imutável.** Nada se apaga. Correção é sempre por estorno, com rastro de quem fez, o quê e quando.
- **Segurança no banco, não só na tela.** Cada cliente só enxerga o próprio workspace, e cada pessoa só faz o que a função dela permite, regra imposta pelo próprio banco de dados.

---

## 2. Administrativo: a visão do negócio

### Cockpit
A tela inicial. Um painel pequeno por área (Geral, Marketing, Vendas, Financeiro, Projetos, Growth e Clientes), dois lado a lado, cada um com os números que mais importam no período: caixa, receita, margem e lucro; campanhas e leads; vendas, ticket e conversão; a receber, a pagar e MRR; projetos e atividades atrasadas; North Star e experimentos; alunos ativos, alertas e satisfação. Cada painel traz também um gráfico: receita e lucro por mês, leads e faturamento por dia, o que entra e o que sai, alunos por etapa. Clicar num painel abre o dashboard daquela área, com tudo em detalhe. Cada pessoa só vê os painéis das áreas a que tem acesso.

### Dashboard geral
O detalhe do painel Geral do Cockpit. Mostra o negócio inteiro num período escolhido:

- receita, lucro e margem por mês;
- o ritmo da meta do mês (está no caminho ou atrás?);
- de onde vem a receita, por produto e por campanha, contra o período anterior;
- DRE e fluxo de caixa recolhidos, para abrir quando quiser.

O desenho é em camadas: 4 cartões grandes com tendência e, abaixo, cartões menores com números compactos. Saldo em banco, a receber e a pagar abrem o extrato e as listas na hora.

**Observações automáticas.** Até 4 avisos do que mudou contra o período anterior, cada um com a categoria (favorável, desfavorável ou atenção) e separado em fato, conta, referência, hipótese e onde investigar. Quando o período é um mês inteiro, a comparação é com o mês anterior inteiro: assim uma despesa lançada no dia 1 não some da conta e não cria uma queda de margem que não existiu.

**Cada número diz contra o quê.** O cartão da receita mostra a variação das próprias vendas contra o mês anterior, com o valor de antes. O lucro mostra a diferença em reais (porcentagem sobre um lucro negativo não tem leitura) e fica vermelho quando está negativo. O saldo em banco também. Os cartões pequenos da mesma linha usam a mesma escala ("mil" em todos), com o valor completo ao passar o mouse.

### Pergunte ao Growths
Um chat em português. Pergunte "como foi meu dia ontem?" e a resposta vem com os números exatos do dia e a comparação com a semana. Para perguntas abertas, a IA (Claude ou ChatGPT):

- recebe só um resumo calculado pelo sistema, sem nomes, e-mails ou telefones;
- tem regras fixas: não inventa número, diz "sem dado" quando falta, trata nome de campanha como simples rótulo (proteção contra instruções escondidas);
- tem cada número da resposta conferido. O que não bate aparece em vermelho com o aviso de não confiar;
- mostra na tela os dados que recebeu.

### Alertas e resumo do dia
O Growths confere os números de hora em hora e avisa quando:

- algo muda de forma brusca;
- algo se repete;
- algo pede ação;
- um dia fica sem dados.

Toda manhã chega o resumo de ontem. Os avisos vão para o sino do sistema, por e-mail e por WhatsApp.

### Planejamento da empresa
Objetivos e indicadores do ano, com meta (cenário bom), cenário ruim e cenário ótimo. Alguns indicadores são calculados sozinhos pela contabilidade, como margem de contribuição e margem de lucro líquida.

### Cadastro da empresa
Dados da empresa, CNPJ validado e responsáveis. Inclui também:

- regime tributário (MEI, Simples com anexo pelo fator R, Presumido, Real);
- alíquota e % de taxas da venda;
- regime de apuração e exercício contábil.

Essas escolhas valem para todas as telas e computadores.

---

## 3. Marketing

### Campanhas e planejamento
A campanha é uma página com abas: dashboard, estratégia e etapas, metas, captação, funil, análise e coortes, mídia paga, vídeos e eventos, leads e vendas, links e tracking, fechamento, e ofertas e preços.

- **Nova campanha em 3 etapas:**
  1. O básico.
  2. Orçamento e metas.
  3. Canais.
  
  Produto, estratégia e canal se cadastram sem sair dali, e uma faixa de rascunho mostra o que falta.
- **Estratégia em blocos.** O funil da campanha é montado com blocos prontos em 4 fases (Aquisição, Aquecimento, Conversão, Retenção): conteúdo do Instagram, tráfego pago, página de captura, indicação, grupo de WhatsApp, disparo, e-mail, pesquisa, aula/webinário, VSL, checkout, comercial, recompra e assinatura. Cada bloco traz as métricas certas, com uma principal e as de diagnóstico. Há modelos prontos: lançamento clássico, perpétuo, webinário, disparo, recompra, comercial e social selling.
- **Estratégias (Canvas).** Em Marketing → Estratégias (Canvas), cada estratégia pode ser vista como mapa: blocos arrastáveis, setas com sim, não e divisão em %, e um painel com objetivo, canal, responsável, oferta e métricas de cada bloco. "Publicar versão" congela a estratégia; a campanha guarda a versão que usou, e mudar a estratégia depois não mexe nela.
- **Campanha híbrida, só paga ou só orgânica.** Cada canal é uma execução, com a própria estratégia e o próprio custo de produção.
- **Metas:**
  - de leads por dia, por mês e por canal;
  - de CPL e CAC;
  - por tipo (investimento, leads, qualificados, vendas, conversão, receita, ticket, ROAS), por fase, canal, público e período;
  - na campanha perpétua, metas mensais com mix de produtos.
- **Painel dia a dia:**
  - quadrinhos verde/vermelho de cada dia contra a meta;
  - onde a campanha caiu (últimos 7 dias contra os 7 anteriores, etapa por etapa);
  - movimento por dia num gráfico só, com as métricas que você escolher;
  - vendas por produto e oferta;
  - quanto custou e o que trouxe cada vídeo ou criativo.
- **Ofertas e esteira.** Oferta principal com order bumps, upsells, downsells e cross-sells. Cada item tem condição (sempre, se aceitou, se recusou), validações contra ciclos e taxa de aceite medida com o denominador certo (quem recebeu a oferta, não todos).
- **Calculadora de campanha.** Preencha o que souber e o resto se ajusta: CPL e conversão dão o CAC, a margem-alvo dá o CAC máximo, e assim por diante. "Salvar metas na campanha" leva tudo para a campanha.
- **Planejamento anual.** Linha do tempo do ano com lançamentos e perpétuas, meta de faturamento por campanha contra a meta da empresa e orçamento planejado contra realizado.
- **Projeto da campanha.** Toda campanha pode gerar o próprio projeto com as atividades dos blocos (ex.: tráfego pago → públicos, criativos, configurar, acompanhar), com responsável por função.
- **Links e tracking.** Monta a URL com UTM e liga o criativo pelo utm_content.
- **Fechamento oficial.** Fechar a campanha guarda a foto do planejado contra o realizado, o debriefing e as melhorias. Fechar de novo cria uma versão nova e mantém a anterior.

### Mídia paga
Uma tela só para mídia, filtrável por canal e campanha, comparando com o período anterior:

- investimento, impressões, cliques, CTR, CPL, leads, vendas, CAC e ROAS;
- CPM, frequência e CAC por canal;
- matriz de fadiga criativa (frequência × índice de CPL);
- mapa de saturação de ângulos;
- alertas por anúncio com ação sugerida (pausar, monitorar, escalar, manter), por regra fixa;
- relatórios por canal, campanha, anúncio e ângulo, em CSV e Excel.

### Vídeos e webinários
Cadastro por plataforma e métricas diárias. Presença por pessoa, retenção, conclusões, cliques no botão e quem estava presente e comprou.

### Leads por origem
De onde vem quem compra: canal, UTM e campanha até a venda. O rastreamento guarda UTMs, gclid, fbclid, referrer e página de origem.

---

## 4. Growth's Content: o módulo de conteúdo

O Growth's Content leva para dentro do Growths a metodologia de conteúdo da Rebecka. Ele serve para a Mathisa e para os clientes que contratam o módulo. Fica em Marketing → Growth's Content, com duas entradas: **Estratégia de conteúdo** e **Instagram**.

### 4.0 O módulo em seis abas (desde a v0.159, ajustado na v0.160)

O Growth's Content agora segue a ordem do trabalho, sem a configuração em 9 passos na frente:

- **Base do cliente:** a pasta no Drive, o dossiê pronto (PDF na pasta) e a ficha do cliente. Quem ainda não tem dossiê abre a configuração guiada (call de briefing, materiais, pesquisa e dossiê) por um botão ali mesmo. A ficha reúne narrativa, para quem fala, tom de voz, produtos e esteira, diferencial, pilares, o que nunca dizer. Ela é aprovada uma vez e tem versões: mudar a aprovada cria uma nova, que precisa de aprovação.
- **Linha editorial:** as linhas (territórios), os temas (frentes), os subtemas opcionais e os formatos. Todo conteúdo nasce com essa segmentação, e uma tabela mostra quantos conteúdos há em cada linha, tema, subtema e formato, de ideia a publicado.
- **Identidade visual:** cores com o papel de cada uma, fontes, pasta com logos e fotos, referências, o que nunca fazer e os formatos usados, com uma prévia.
- **Ideias:** aprovar ou descartar. Aprovar pede o tema, o subtema, o formato e a data de publicação, e a ideia entra no calendário.
- **Produção:** o Kanban com o painel da semana, o calendário das próximas semanas e as colunas por etapa. Cada cartão diz se o roteiro ou a peça falta aprovar; o botão Roteiro e peça abre a aprovação: o roteiro é aprovado antes de qualquer arte ou vídeo, a arte ou o vídeo tem versões e pedidos de ajuste, e a aprovada vai para a data.
- **Mais ferramentas:** as outras abas de antes (dashboard, semana, priorização, máquina, fechamento, persona, produtos, estruturas, canais).

A Claude vai escrever a ficha a partir do dossiê, sugerir ideias, escrever roteiros e produzir arte, capa e edição de vídeo, sempre com aprovação. Os botões já estão no lugar e ficam desligados até a conta da API ter crédito.

### 4.1 Começa pela configuração
Enquanto o cliente não estiver configurado, o módulo abre num passo a passo de 9 passos, que guarda onde a pessoa parou. Só depois de concluído aparecem as abas de trabalho.

1. **Google Drive.** O cliente cria uma pasta no Drive dele e compartilha com o e-mail da Mathisa. O Growths cria ali a árvore de pastas:
   - 01 Briefing;
   - 02 Materiais do cliente (Documentos, Reuniões gravadas, Aulas e cursos, Depoimentos e provas);
   - 03 Identidade visual;
   - 04 Referências de conteúdo;
   - 05 Pesquisa de mercado;
   - 06 Dossiê da marca;
   - 07 Skill do cliente;
   - 08 Produção (Roteiros, Gravações, Edição, Artes);
   - 09 Publicados;
   - 10 Resultados.
   
   A pasta e os arquivos continuam no Drive do cliente, e o Growths enxerga tudo o que for colocado ali. O cliente também pode acrescentar **outras pastas que já tem organizadas**, só compartilhando cada uma: o Growths lê essas também.
2. **Seus canais** (o cliente faz). O @ ou endereço de cada plataforma onde já publica: Instagram, YouTube, TikTok, LinkedIn, Threads, Facebook, site ou blog, podcast e outros. Cada @ vira link do perfil.
3. **Seus materiais** (o cliente faz). Cinco tipos, um por tela, cada um com a pasta certa e o botão "Pronto, está na pasta" ou "Não tenho":
   - documentos;
   - identidade visual;
   - reuniões gravadas, com a transcrição se houver;
   - aulas e cursos, inclusive os de plataforma de venda, baixados e subidos;
   - depoimentos e provas.
4. **Call de briefing.** O roteiro da call aparece na tela, um bloco de perguntas por vez, salvando sozinho enquanto a pessoa digita: nicho, objetivo, **produtos e esteira** (quais produtos e valores, como a esteira funciona, o carro-chefe, como a venda acontece e o histórico), tese, repertório e formatos. Tem data da call e anotações livres.
5. **Pesquisa.** Um botão, "Fazer a pesquisa". A IA lê as pastas do cliente (a principal e as outras que ele compartilhou) e as pastas com os padrões da Mathisa, junta as respostas da call, os produtos com o histórico e os canais, e pesquisa na web o mercado, as tendências, os concorrentes e o que o público pergunta. Entrega um relatório para ler, com:
   - cada afirmação marcada como fato, hipótese ou recomendação;
   - as fontes de cada fato;
   - a lista do que foi lido e do que não foi lido (por exemplo, vídeo sem transcrição), com o motivo.

   Como a leitura funciona: as pastas da Mathisa são lidas primeiro, e cada pasta tem a sua própria cota de arquivos e de texto, para que uma pasta grande do cliente não tome o lugar dos padrões. Documentos, planilhas e apresentações do Google, Word, Excel e PowerPoint (convertidos na hora) e PDFs entram; fontes, arquivos compactados e e-books são pulados sem gastar a cota.
6. **Dossiê.** Depois de ler o relatório, um clique gera o dossiê da marca em seções: diferencial, mecanismo do problema, mecanismo da solução, construção do produto, narrativa, voz, persona, concorrência e oportunidades de conteúdo. Cada nova geração é uma versão. A aprovação do cliente, o PDF e a skill do cliente vêm na sequência.
7. **Linha editorial e formatos.** A IA propõe territórios, frentes e formatos a partir da call. Aqui também se escolhem as estruturas de roteiro e copy.
8. **Onde publicar.** Os canais em uso e as regras de canal por frente e etiqueta.
9. **Rotina da semana.** Quantos conteúdos por semana, o dia da curadoria (sexta por padrão) e quem publica.

### 4.2 A Máquina de Conteúdo (Estratégia de conteúdo)

- **Territórios e frentes.** O modelo V18 instala por botão:
  - 4 territórios: Estratégia; Negócios, com Empreendedorismo; Dados + IA; Vida Real & Crenças;
  - frentes e camadas transversais;
  - 5 formatos, incluindo Carrossel caderno e Série musical 1× por semana;
  - quadros de autoridade;
  - destinos: Rebecka, Mathisa ou Ambas.
- **Ideias e pautas (Kanban).** Ideia → pauta aprovada → em produção → pronto → agendado → publicado. Cada pauta tem palavra-chave e perguntas de busca, e o score de 6 critérios (timing, potencial estratégico, impacto, facilidade, robustez da evidência, novidade) com o VALIDAR.
- **Painel da produção** (no topo do Kanban):
  - quantos conteúdos estão em cada etapa;
  - quantos estão prontos para a semana atual contra a meta;
  - um calendário da semana atual e das 5 seguintes, com um ponto colorido por conteúdo, dizendo quais semanas estão completas e quanto falta nas outras.
- **Priorização.** Quadro de validação e reservas, do maior para o menor score.
- **Máquina.** A matriz território × formato: cada célula é uma combinação replicável, e dá para ver onde há buraco.
- **Semana.** Os dias da semana com o que está marcado, a fila de validadas sem data (arrasta para o dia), formatos com frequência fixa e metas por tipo de mídia.
- **Fechamento de sábado.** Retrospectiva (o que funcionou, o que repetir, o que melhorar, que tese ganhou força, o que ficou repetitivo, o que descartar) e a pré-pauta da semana seguinte.
- **Persona.** Questionário completo, base para a IA propor a linha editorial de qualquer cliente.
- **Produtos.** A lista dos produtos do cliente, cada um com o nome, o valor e o histórico (como surgiu, turmas e lançamentos, resultados, o momento de agora). Cadastrados ali mesmo, ou trazidos do cadastro comercial. O cartão de cada produto mostra quantos conteúdos já falam dele, e cada ideia pode ser ligada a um produto.
- **Estruturas.** O cliente escolhe as estruturas de roteiro e copy que quer em cada formato (veja 4.4).
- **Canais.** O canal de cada frente e de cada etiqueta.
- **Ideias pelo ChatGPT.** A pessoa dita a ideia num GPT no celular e ela cai direto no Kanban, já com título, ângulo, formato e tema.

### 4.3 Instagram
- **Conexão automática.** Os números chegam pela conexão oficial, sem planilha: a conta, cada post e as DMs.
- **Dashboard:**
  - posts, alcance, interações, engajamento, salvamentos, compartilhamentos e seguidores contra o período anterior;
  - top 1 e gráficos por dia;
  - os posts em imagens (4 primeiro, "Mostrar mais"), ordenáveis por engajamento, curtidas, alcance, recentes, salvos, compartilhados, comentários ou visualizações;
  - gráficos por tema, formato e tipo de mídia. A cor diz se está acima da média (verde), na média (azul) ou abaixo (vermelho), com "+X% vs. média". Clicar na barra mostra os posts que formam o número;
  - melhores dias da semana e horários de publicação, em linha.
- **Insights automáticos.** O Growths lê o período e diz o que se destaca, cada item como fato, hipótese ou recomendação e com um botão para ver os posts:
  - o assunto que mais engaja e o que rende menos, pelas palavras das legendas;
  - o tema mais forte;
  - o tipo de mídia que mais alcança;
  - o post que puxou conversa;
  - o que pode ter levado gente para a DM;
  - o mais salvo e o mais compartilhado;
  - o melhor dia;
  - a comparação com o período anterior.
- **Classificar o post** que não veio da Máquina (frente e formato) no próprio post.
- **DMs no CRM.** As mensagens chegam a cada 30 minutos. Quem escreve vira lead no CRM e aparece também em Vendas → DMs do Instagram.

### 4.4 Bastidores do Growth's Content (o que só a Mathisa vê)
- **Estruturas de roteiro e copy.** Uma biblioteca interna com as etapas e as instruções que a IA segue. O cliente vê só o nome e para que serve cada uma. Começa com 7 estruturas:
  - AIDA;
  - PAS;
  - Antes, depois e a ponte;
  - Gancho, conteúdo e chamada para Reels;
  - Carrossel educativo;
  - Storytelling em jornada curta;
  - copy pelos 5 níveis de consciência.
  
  A equipe pode criar outras (como as do método MIRA), editar, reordenar e desativar.
- **Pastas da Mathisa.** Pastas do Drive da Mathisa que a IA lê junto com as do cliente, para todos os clientes ou para um. A regra: as pastas da Mathisa são os **padrões** (método, estruturas, exemplos, o que muda pouco). As pastas do cliente são as **novidades** (método novo, estudo novo, material novo). Quando os dois falam do mesmo assunto, a novidade do cliente vale para aquele cliente.
- **Custos de IA.** Uma tela que só a Rebecka vê: tokens, buscas na web e custo por cliente e por mês, em dólar e em reais (com o câmbio informado por ela). Serve para medir o custo real antes de definir os planos.
- **Acesso por cliente.** Marcar o Growth's Content num cliente libera só o módulo de conteúdo e sempre como Growths completo.

### 4.5 O que vem a seguir no Growth's Content
- **Rotina diária**, todos os dias por cliente:
  - ler o que entrou nas pastas (da Mathisa e do cliente);
  - buscar na web sobre o nicho (notícias, tendências, concorrentes), com fonte;
  - gerar ideias pela linha editorial, persona, voz e estruturas escolhidas, no formato e na quantidade da rotina;
  - registrar o custo de cada rodada.
- **Leitura dos outros canais** (YouTube, TikTok, LinkedIn, Threads) pela conexão.
- **Pesquisa, tese, dossiê e skill do cliente**, com aprovação.
- **Aprovação do dossiê pelo cliente**, o PDF e a skill do cliente.
- **A rotina de ideias usando os produtos** e o histórico de cada um.
- **Planos por faixa**, com limites de produção e ferramentas de vídeo e arte. Começa pelo básico: cortar pausas.
- A IA trabalha pela API da Claude: cada cliente separado e nada passando por contas pessoais.

---

## 5. Vendas

- **Funil comercial (CRM).** Kanban de leads com etapas editáveis. Cada etapa tem "o que precisa acontecer", mensagem padrão e aviso ao responsável. Também tem comercial responsável, filtros "só os meus" e "sem responsável", selo verde/vermelho de qualificado com a pontuação e tags coloridas.
- **Ficha do lead e do cliente:**
  - primeira origem e último clique;
  - quantos contatos até a compra e a linha do tempo da jornada;
  - responsáveis e o histórico de quem mudou;
  - compras, contratos e oportunidades;
  - pagamentos anteriores ao sistema.
- **Identidade sem duplicar.** A mesma pessoa é reconhecida por telefone e e-mail. Cadastro repetido junta sozinho ou por botão, com histórico.
- **Vendas.** Vendas aprovadas, bruto e líquido, ticket médio e reembolsos. A receita aparece por papel da oferta (order bump, upsell, downsell). Cada venda guarda o primeiro e o último toque, com o painel "Vendas por canal" (CAC e ROAS bruto).
- **Contratos:**
  - status claros: pendente, assinado e ativo, cancelado, encerrado;
  - parcelas personalizadas;
  - alerta de vencimento a 40 e a 30 dias;
  - renovar e negociar;
  - números do mês e MRR/ARR.
- **Oportunidades.** Kanban de novos negócios com quem já é cliente: outro produto, renovação ou aditivo. "Ganhou" abre o contrato já preenchido.
- **Comissões.** Vendedor, coprodutor, estrategista e parceiro, com regras por projeto, campanha, produto ou oferta, base líquida ou bruta, fechamento do mês em contas a pagar e estornos.
- **Abandono de checkout.** Registro, recuperação automática quando a pessoa compra em até 30 dias e taxa de recuperação.
- **DMs do Instagram.** As conversas viram leads.
- **Metas × vendas.** Para cada campanha ativa, o ritmo esperado até hoje: no ritmo ou atrás.

---

## 6. RevOps: retenção e expansão

- **Retenção & Expansão**, com filtros de período da primeira compra, produto, canal, campanha, origem e segmento:
  - **Coortes:** segunda compra em 30, 60, 90, 180 e 365 dias, receita acumulada por cliente, curva D0 a D365 e matriz de coortes. Coorte que não completou o prazo aparece como "indisponível", com o parcial à mostra.
  - **Recompra:** taxa, intervalo entre compras, frequência, ticket de recompra, receita de novos contra existentes e o papel de cada produto de entrada (expande, recompra moderada, não expande).
  - **RFM:** sete segmentos com regras editáveis, a grade R×F e o cruzamento com produto, campanha, canal e origem.
  - **Investigar:** qualquer número abre a lista de clientes com o histórico, exportável.
- **Alunos.** Kanban da jornada de depois da compra, com CS responsável. O aluno nasce sozinho na venda ou no contrato. Escolhe-se a jornada (a geral ou a de cada produto) ou a lista de todos os produtos, uma linha por matrícula.
- **Jornada do produto.** Cada produto pode ter as próprias etapas (uma mentoria não anda como um curso online), com versões: ao publicar uma versão nova, decide-se se quem já está dentro continua na antiga ou é transferido. Dá para salvar uma jornada como modelo e começar outras a partir dele.
- **Marcos.** O que o aluno precisa atingir em cada jornada, com prazo e prova. Alguns a equipe confirma; outros o sistema percebe sozinho (comprou, assistiu à aula, respondeu que teve resultado, chegou à etapa, entrou no grupo, ou um evento que a plataforma do curso manda), com ou sem confirmação da equipe.
- **Customer Growth.** A tela de acompanhamento dos alunos: evolução por produto, check-ins que voltam a cada tantos dias, alertas para o CS (parado, marco atrasado, check-in sem resposta, nota baixa), intervenções com o efeito de cada uma, oportunidades de retenção e expansão e os indicadores de evolução. Na ficha de cada pessoa, a jornada dela em cada produto.
- **Dashboard de RevOps.** Ativos, churn, retenção, LTV e ascensão, com semáforo contra metas.

---

## 7. Financeiro e contabilidade

- **Contabilidade de verdade.** Cada venda, recebimento, conta e pagamento gera as partidas dobradas sozinho, pelas regras contábeis (que podem ser personalizadas). Nada se apaga: correção é estorno.
- **Contas a receber.** Parcelas de contratos e vendas, provisionamento por mês e por cliente, MRR/ARR, receitas avulsas (com repetição) e desconto em parcela, que vira dedução da receita e não despesa. Também dá para cancelar, desfazer recebimento e reativar.
- **Contas a pagar.** Conta única, recorrente fixa, recorrente variável (valor estimado que se confirma) ou parcelada. Tem formas de pagamento, inclusive cartão de outra pessoa, e fornecedores com valor e vencimento padrão.
- **Baixa parcial.** Pagar ou receber uma parte deixa o saldo em aberto, sem bagunçar a despesa ou a receita do mês. Desfazer junta de novo.
- **Cartão de crédito como fatura**, não como saldo. O dinheiro só sai do banco ao pagar a fatura.
- **Dashboard financeiro.** Saldo em banco (abre o extrato com saldo linha a linha), a receber e a pagar no período, atraso, projeção, resultado contra caixa e a cascata de como o resultado se formou. A cascata diz "sobraram" ou "faltaram" conforme o sinal do resultado. Um gráfico de ponte mostra o que mudou do período anterior para este: parte do resultado anterior, cada barra é quanto a receita ou uma conta mexeu, e chega no resultado atual; ao lado, a conta que mais pesou aparece como "possível fator associado" (nunca como causa). Caixa projetado e saldo mínimo ficam num painel só, com o aviso de quando o caixa fura o mínimo (ou o zero, se não houver mínimo).
- **Custos e margens:**
  - custo do mês (fixo, variável, parcelado, pontual) e pró-labores;
  - margem de contribuição por produto e lucro líquido;
  - ponto de equilíbrio e "quanto preciso vender";
  - comparação entre regimes tributários;
  - cenários ruim, bom e ótimo de margem;
  - custo por área contra o mês anterior.
- **Saldo mínimo de caixa**, com aviso no Dashboard.
- **Plano de contas por cliente**: importar, baixar e ligar as contas do sistema.
- **DRE e fluxo de caixa**, sempre com a mesma definição de lucro em todas as telas.

### Casa
As finanças pessoais da sócia num livro contábil separado, que nunca se mistura com a empresa: dashboard, contas, bancos, plano de contas próprio. A transferência da empresa para a Casa (pró-labore ou distribuição de lucros) lança cada lado no seu livro e pode ser desfeita.

---

## 8. Growth: modelo, cenários e experimentos

- **Diagnóstico Growth.** Sobe planilhas bagunçadas do cliente e o sistema identifica vendas, leads e investimento. Classifica cada venda (nova, renovação, upgrade, repetida) e mostra o que falta em 13 itens, com a mensagem pronta para pedir ao cliente e a planilha padronizada para baixar.
- **Growth Model em planilha:**
  - colunas Real + projeção (travado), Cenário (onde se mexe) e Efeito;
  - mexeu numa célula, o resto recalcula: o preço sobe, a receita sobe, o imposto acompanha, a margem e o lucro mudam;
  - amarelo é o que se mexeu, azul é o que mudou por consequência;
  - resultado do período, um bloco por produto e uma seção por loop ou campanha;
  - comparar até 3 cenários lado a lado.
- **Mapa de métricas e North Star.** A árvore que liga a North Star às métricas que a movem. A NSM fica em destaque, com o evento que conta, quem entra na conta e a frequência; logo abaixo, as **alavancas que movem a NSM**, cada uma com o papel (driver ou input), a meta e quanto mudou contra o período anterior. O sistema aponta o gargalo sugerido (a alavanca mais longe da meta) e dali já se cria o experimento.
- **Cenários com ciclo de vida.** Em estudo, descartado (com motivo, e dá para reabrir), aprovado, ativo, encerrado, cancelado.
- **Decisão.** ICE (impacto, confiança, facilidade) com justificativa. A aprovação congela o cenário e gera o documento de decisão imutável (contexto, hipótese, baseline contra projeção, riscos, responsável) e a ideia no Kanban.
- **Ciclo de Growth (Kanban de experimentos).** Ideias → em avaliação → priorizadas → preparação → em teste → análise → concluídas. Cada experimento tem o desenho do teste: métrica-alvo, público, intervenção, critério de sucesso.
- **Guardrails.** Limites de margem, lucro, ROAS, CAC, CPL e outros:
  - projetados no cenário: "este plano rompe o limite?";
  - monitorados de verdade quando o teste vai ao ar: antes, durante e depois;
  - quando rompem, geram alerta com a ação sugerida. Nada é pausado sozinho.
- **Resultados e aprendizados.** Baseline, projeção e realizado de cada teste, com a decisão: escalar, iterar ou interromper.
- **Pesquisas:**
  - construtor de perguntas, com modelos de lead, onboarding, jornada, descoberta da North Star e **must-have de consultoria** (o cliente diz quão desapontado ficaria sem a consultoria, o que faria no lugar, quanto valeu cada entrega e o que travou a execução);
  - página pública de resposta;
  - NPS, PMF e insights; o must-have aparece em três faixas (40% ou mais, 25% a 40%, menos de 25%) com o próximo passo, sem contar quem marcou "Não se aplica";
  - **qualificação por pontos:** cada resposta vale pontos e tags, e a nota de corte decide quem é qualificado na hora;
  - **formulário de captação** com a cara do cliente (fontes e cores), em passos, que coloca quem responde direto no funil de leads;
  - a aba "Quem respondeu".

---

## 9. Projetos e equipe

- **Projetos** com atividades, subatividades, dependências (a atividade só libera quando a anterior termina), responsáveis por função, prazos, tags e filtros.
- **Painel do projeto:** planejado contra concluído, dia a dia.
- **Minhas atividades, Todas as atividades e Avisos.**
- **Modelos de projeto.** Qualquer projeto vira modelo, e o modelo pode ser o padrão das campanhas.
- **Equipe** com função, e-mail, WhatsApp e canais de aviso.

---

## 10. Configurações, dados e confiança

- **Importar e validar dados.** Sobe vários arquivos de uma vez, e o sistema diz o que é cada um:
  - verde: pronto;
  - vermelho: tem problema, com o motivo;
  - amarelo: em dúvida.
  
  Depois vem o de-para campo a campo. Colunas sem campo viram campos personalizados.
- **Qualidade dos dados.** 10 verificações automáticas, como venda sem origem, mais cliques que impressões, dias sem dado de mídia e mídia dos anúncios diferente do financeiro. Os dashboards marcam com ⚠ os números afetados.
- **Dicionário de métricas.** A definição oficial de cada indicador, com o ⓘ nos cartões. Para cada número: a unidade, quantas casas, a direção (quanto maior melhor, quanto menor melhor, faixa ou neutra), se o zero é limite e de onde vem a referência que dá a cor.
- **Auditoria.** Quem incluiu, alterou ou excluiu, com antes e depois. Ninguém altera nem apaga a auditoria.
- **Uso da plataforma.** Que telas se usam, por quanto tempo, onde as pessoas desistem de formulários e onde aparecem erros, sem gravar dados de clientes.
- **Equipe, funções e permissões.** Por módulo e por ação (ver, criar só lead, criar, editar, excluir), por função e por pessoa.
- **Pacotes de acesso dos clientes.** No "Novo cliente", uma árvore com setinhas para marcar tela por tela o que o cliente acessa, com atalhos de pacote.
- **Integrações e conexões.** Meta (anúncios e Instagram), Google (Ads e YouTube), formulários, Instagram pelo Zernio e WhatsApp e e-mail para avisos.

---

## 11. Visual e experiência

- **Claro como padrão e escuro como opção.** Uma ação principal por tela.
- **Cor com significado (Data Storytelling).** Quatro cores só para leitura de dados: verde (favorável), vermelho (desfavorável), âmbar (atenção) e azul (informação e comparação). A cor nunca vem sozinha: sempre com seta ou símbolo (▲ ▼ ✓ ✕ ⚠) e uma palavra, porque verde e vermelho se confundem para quem tem daltonismo. Lucro, resultado, margem, ROI e saldo têm o zero como limite: negativo em vermelho, positivo em verde, âmbar quando passa de zero mas não chega na meta ou no cenário cadastrado. As outras métricas só ganham cor quando há meta, limite ou período anterior comparável, e cada uma tem a sua direção: CAC caindo é bom, margem caindo é ruim, investimento subindo é neutro. Variações abaixo de 5% ficam neutras.
- **Números num padrão só.** Sinal de menos verdadeiro, reais abreviados em cartões e completos em tabelas, pontos percentuais para taxas, ROAS com uma casa (4,5x) e LTV:CAC como razão (3,2:1). "—" quer dizer sem dado; zero quer dizer zero.
- **Gráficos limpos.** Verde e vermelho saem das linhas e barras comuns e ficam para o que é bom ou ruim. Meta, limite e saldo mínimo aparecem como linha tracejada com o valor escrito. Na cascata do resultado, receitas, deduções e despesas ficam neutras e só o resultado ganha cor.
- **Frases que vêm do banco, não da cabeça da IA.** Cada frase de análise é um modelo guardado numa tabela, com código, versão e aprovação. A tela só preenche os números que ela mesma calculou; se faltar um número, a frase não aparece. Mudar o texto cria uma versão nova, que volta para "proposta" até ser aprovada, e a antiga fica no histórico. O Dicionário de métricas mostra todas as frases e quais estão aprovadas. O Dashboard financeiro é o primeiro a usar.
- **Painéis em blocos.** O Dashboard e o Dashboard financeiro são divididos em blocos lado a lado, como um painel de BI, para nenhum gráfico tomar a tela inteira. O gráfico mais importante fica maior e os de apoio ficam ao lado; cada gráfico é desenhado no tamanho do seu bloco, para a letra continuar legível, e no celular tudo vira uma coluna.
- **Menu em níveis**, com recuo e linha guia.
- **Gráficos com função.** Cada gráfico responde uma pergunta: o tipo é escolhido pelo número (linha no tempo, cascata, composição, barras por dia, medidor).
- **Campos de moeda com máscara** (R$ 1.234,56).
- **Códigos automáticos.**
- **"Cadastrar novo…" de dentro dos formulários**, sem sair da tela.
- **Respeita quem pediu menos movimento** no sistema operacional.

---

## 12. Como o Growths é construído (bastidores)

- **Ritmo.** Mais de 150 versões em 3 semanas (de 05/10 a 26/10/2026), cada uma com registro do que mudou, por quê e como foi testada.
- **Testes de verdade.** Cada versão roda testes que abrem a tela real ligada a um banco completo e conferem número por número. Existe uma empresa fictícia, a Escola Aurora, com lançamento, anúncios, leads e vendas coerentes, para testar com dado realista.
- **Auditoria de consistência.** Uma rodada comparou o mesmo número em todas as telas. O lucro do mesmo mês aparecia de três jeitos; foi corrigido para um lucro só.
- **Decisões documentadas.** O sistema guarda cada decisão com o pedido que a originou. Exemplos:
  - "ROAS oficial é o bruto";
  - "mesmo telefone junta sozinho";
  - "contrato recorrente: só contrato novo é recompra".
- **A IA no lugar certo.** Ela trabalha sobre números calculados e conferidos, nunca como fonte de número.

---

## 13. Ideias de conteúdo a partir do Growths (sugestões)

Ângulos que nascem do sistema, para usar como ponto de partida:

- "Seu lucro tem três números diferentes?" A história da auditoria de consistência.
- Por que "sem dado" é melhor do que zero.
- Fato, hipótese e recomendação: como ler um insight sem se enganar.
- A árvore dos números: de onde vem cada número do seu dashboard.
- Contabilidade imutável: por que nada se apaga e tudo se estorna.
- Guardrails: o limite que protege o teste de growth de quebrar o negócio.
- Escalar, iterar ou interromper: como decidir depois de um experimento.
- O cliente que já tem tudo no Drive: como a pasta vira matéria-prima de conteúdo.
- Padrões da consultoria contra novidades do cliente: como a IA equilibra os dois.
- Estruturas de copy (AIDA, PAS, 5 níveis de consciência) aplicadas a Reels e carrosséis.
- Semana completa: planejar conteúdo pela meta e não pela inspiração.
- DM que vira lead: o caminho do Instagram ao CRM.
- Order bump, upsell e downsell medidos com o denominador certo.
- Cenário ruim, bom e ótimo: margem como meta de gestão.
- A esteira explicada: por onde o cliente entra e o que compra depois.
- Da pasta ao dossiê: como a IA lê o material do cliente sem inventar nada.
- Fato, hipótese ou recomendação: como ler uma pesquisa feita por IA.
- Objeção com resposta: transformar o "não tenho tempo" em pauta.
- Construir um sistema em 140 versões: o bastidor da Mathisa.
- "Seu dashboard pinta de verde o que não é bom": a cor tem que seguir a direção da métrica, não o sinal.
- CAC caiu 40%: verde. Investimento subiu 40%: nem verde nem vermelho. Por quê.
- Ponto percentual não é porcentagem: a margem que cai de 25% para 20% caiu 5 p.p. e 20%.
- O dia 1 que sumiu da conta: como uma janela de comparação mal escolhida inventa uma queda de margem.
- Lucro negativo não cai "242%": quando falar em reais e não em porcentagem.
- Cor nunca sozinha: dashboards que funcionam para quem tem daltonismo.
- "A IA não escreve seus números": frases de análise com modelo aprovado, e só número calculado entra nelas.
- Sobrou ou faltou? Quando a frase do relatório contradiz o próprio número.
- A ponte do resultado: o gráfico que responde "por que meu lucro piorou" em uma olhada.
- Possível fator não é causa: como um dashboard deve falar de hipótese.
- Versão e aprovação para frases: governança de texto num sistema de dados.
- Um gráfico por tela é desperdício: como montar um painel em blocos que se lê em um minuto.
- Do dossiê à peça agendada: quatro aprovações e nenhuma arte antes do roteiro.
- Menos abas, mais entrega: como simplificar um módulo sem apagar nada.
- Identidade visual como regra, não como inspiração: cores com papel, fontes reais e o que nunca fazer.
- Linha, tema e subtema: segmentar o conteúdo no nascimento para o relatório fazer sentido depois.
- Aprovação sem perder o calendário: o Kanban que mostra o que falta aprovar e quando publica.
- Sua consultoria é must-have? A pergunta do desapontamento aplicada a um serviço.
- "O que você teria feito no lugar?": descobrir o concorrente real de uma consultoria.
- O backup antes da mudança: por que toda versão do Growths tem caminho de volta.

---

## 14. Histórico resumido

- **29/10 (v0.165):** Strategy Canvas: biblioteca de estratégias no Marketing, mapa visual com ligações e ramificações, e versões que cada campanha guarda.
- **29/10 (v0.164):** Cockpit na entrada: um painel por área (Geral, Marketing, Vendas, Financeiro e Clientes), cada um abrindo o dashboard do módulo.

- **29/10 (v0.163):** Customer Growth em RevOps: jornada de cada produto com versão, marcos, check-ins, alertas e intervenções de CS e indicadores de evolução.

- **05 a 06/10/2026:**
  - base do sistema: workspaces, pessoas, vendas com contabilidade automática, contas a receber, campanhas;
  - financeiro completo;
  - CRM, funis e jornada do lead;
  - mídia paga, vídeos, RevOps, projetos;
  - Growth Model e Ciclo de Growth;
  - pesquisas e planejamento de conteúdo.
- **07 a 08/10:**
  - contratos com parcelas personalizadas, oportunidades, renovação;
  - novo visual, Growth Starter, importação inteligente;
  - "Pergunte aos dados" com IA conferida;
  - dashboards de mídia e vendas;
  - Growth Model automático e calculadora de campanha.
- **10 a 11/10:**
  - estratégia em blocos e simulador de lucro;
  - pacotes de acesso, cartões de crédito, Casa;
  - segurança e confiança do dado: identidade, auditoria, qualidade, dicionário;
  - captação e atribuição;
  - projetos com modelos, custos e margens;
  - "Growth Now": ofertas, cenários, decisão, guardrails.
- **12 a 17/10:**
  - visual azul;
  - Growth Model em planilha;
  - Retenção & Expansão (coortes, recompra, RFM);
  - cenários com ciclo de vida, ideias pelo ChatGPT;
  - auditoria de consistência e correção;
  - Escola Aurora; leads por formulário.
- **19 a 21/10:**
  - metas de leads; árvore dos números;
  - comissões e conexões com Meta e Google;
  - visual com destaque e dashboard em camadas;
  - gráficos com função (ondas 1 a 3);
  - painel da campanha dia a dia; qualificação por pontos;
  - formulário de captação; selo de qualificado.
- **24 a 25/10:**
  - Pergunte ao Growths e alertas;
  - Máquina de Conteúdo; Instagram (dashboard, DMs, insights);
  - Growth's Content com pasta no Drive, configuração em 9 passos, estruturas de roteiro e copy, custos de IA, pastas da Mathisa;
  - painel da produção no Kanban;
  - produtos no conteúdo (nome, valor e histórico), com as ideias ligadas a eles, e o bloco Produtos e esteira no questionário;
  - pesquisa com um botão (pastas, call, produtos, canais e web) e o dossiê em seções.
- **26/10:**
  - auditoria de Data Storytelling e a camada de leitura dos dados em todo o sistema: cores com significado, zero como limite dos saldos, números padronizados, comparações com a base escrita, gráficos sem cor pelo sinal, frases que contam o que aconteceu, alertas em quatro categorias e o dicionário com direção e referência.
  - biblioteca de visualizações, banco de narrativas e auditoria das telas; as frases de análise passam a morar numa tabela no banco, com versão e aprovação, começando pelo Dashboard financeiro (frase da cascata corrigida, ponte do resultado, caixa e saldo mínimo juntos).
  - Dashboard e Dashboard financeiro em blocos lado a lado (grade de painel de BI), com backup da versão anterior.
  - Growth's Content em cinco abas: base do cliente com dossiê e ficha aprovada, identidade visual, ideias, produção com roteiro, versões e aprovação; as ferramentas de antes em Mais ferramentas.
  - Produção de volta ao Kanban com calendário, com a aprovação dentro de cada cartão; linha editorial com subtemas na configuração; ideia aprovada já com tema e data.
  - modelo de pesquisa must-have para consultoria, com a leitura em três faixas nos resultados.
- **29/10:**
  - Mapa de métricas com a North Star em destaque e as alavancas que movem a NSM agrupadas embaixo dela.
