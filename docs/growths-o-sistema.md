**Correção v0.190 · Grupos Evolution.** A importação de grupos agora consulta metadados com método GET e apresenta diagnóstico real por lote, incluindo nomes, avatares salvos e pendências. Fotos continuam privadas. Grupos sem metadados disponíveis não recebem nomes fictícios.

**Atendimento v0.189 · Identificação dos grupos.** O sistema enriquece nomes de grupos com metadados Evolution e apresenta miniaturas de contatos e grupos em armazenamento privado. A instância Evolution possui o checkbox **Exibir grupos arquivados** para controlar grupos arquivados operacionalmente no Growth V2; cada conversa de grupo pode ser arquivada/desarquivada sem apagar seu histórico. O arquivamento do celular não é espelhado automaticamente. Ver `docs/atendimento-grupos-arquivo-fotos-v0189.md`.

**Atendimento v0.188 · Mídia no chat.** Imagens recebidas aparecem com preview ampliável; áudios e vídeos têm controles de reprodução sem sair da interface. O operador pode anexar imagem/áudio/vídeo/PDF e gravar áudio diretamente no navegador. A Edge usa Supabase Storage privado, URLs assinadas e downloads autenticados da Evolution/Zernio. A implementação ainda depende de atualização da Edge e testes reais nos canais. Consulte `docs/atendimento-midias-v0188.md`.

**Evolução v0.185 · Identidade de canais e OAuth.** Em Atendimento, Instagram aparece em faixa vermelha com perfil; WhatsApp em verde com modalidade QR Code/Evolution ou API oficial/Zernio e número quando detectável. Administradores podem excluir uma instância da Evolution via API, preservando o histórico no Growth V2. Os cartões nativos iniciam OAuth de YouTube, LinkedIn/TikTok orgânicos, Facebook Page e WhatsApp oficial pela Zernio; Google Ads reutiliza o OAuth Google já existente. Os conectores de anúncios de TikTok/LinkedIn continuam distintos. Consulte `docs/canais-e-oauth-v0185.md` antes de implantar.

**Correção v0.183 · Conectar Meta.** A ação Meta do painel de Integrações é roteada exclusivamente para a Edge `meta-zernio` via chave Zernio central. O handler de Meta legado da função `conexoes` é interceptado; o Google continua a utilizar `conexoes`. O navegador deve revalidar o arquivo de interface antes de cada reutilização.

**Evolução v0.182 · Meta via Zernio.** Em Integrações, o cartão Meta agora abre autorização do Facebook Login for Business intermediada pela Zernio, com `ZERNIO_API_KEY` central. O cliente autoriza Meta Ads e seleciona contas de anúncio de seu workspace; dados de outros clientes não são importados. O Instagram orgânico, Facebook Page e WhatsApp oficial possuem fluxos próprios. A sincronização manual de métricas Meta Ads por Zernio foi codificada, mas ainda precisa de teste real e revisão de resultados antes da liberação; cron não configurado.

**Atualização v0.181 — Integração Meta:** o cartão Meta existente autoriza acesso às contas Ads, Páginas e Instagram profissional com escopos específicos; ao configurar `META_LOGIN_CONFIG_ID`, oferece seleção de ativos pelo Facebook Login for Business. WhatsApp Business Platform requer Embedded Signup próprio, não habilitado por este login. O sistema mantém um workspace por cliente e os tokens no servidor.

# Growths: o sistema, explicado

**Documento vivo.** Atualizado a cada entrega do Growths.
**Última atualização:** 13/11/2026, versão 0.291 (Plano do ano).

**v0.291 · Plano do ano.** Depois do baseline, o Growths confronta a meta de receita com o que o negócio já mostrou: quanto sobra para investir em aquisição depois dos custos fixos e do lucro desejado, quantos clientes novos a meta pede e até quanto cada um pode custar. Se o plano só fecha com um CAC menor que o de hoje, a tela avisa e mostra as saídas. O ano é dividido em trimestres, e cada campanha já nasce sabendo o orçamento disponível e quanto precisa deixar de contribuição.

**v0.290 · Diagnóstico e baseline.** Antes de planejar, o Growths mostra o retrato do negócio: receita, margem, clientes novos, CAC, ticket, recompra, custos fixos e o que há a receber e a pagar. Cada número diz de onde veio, quanto tempo de dado tem por trás e o quanto dá para confiar nele (validado, parcial, estimado, histórico insuficiente). Quem já usa o Growths recebe tudo preenchido; quem está chegando importa o histórico ou informa os números; quem está começando do zero trabalha com projeções, vendo quanto sobra por venda em cada produto. O que falta vira uma lista com o caminho para resolver, incluindo uma apuração guiada do custo de atender cada aluno. Aprovado, vira o baseline do ano.

**v0.289 · Mesma cara de Nova campanha.** O Planejamento de campanha avançado agora parece com o assistente que cria campanhas: passos em barras no topo, um passo por vez e Salvar e continuar no rodapé, com o rascunho salvo sozinho.

**v0.288 · Tipo de campanha.** No Planejamento de campanha avançado, o primeiro passo pergunta que campanha é: o objetivo (captar leads, conquistar novos clientes, vender de novo para a base ou abrir um mercado novo) e o modelo (evento, venda direta na página, comercial ou oferta para a base). Cada combinação tem o seu funil e a sua conta: em captação a meta é em leads e o limite é o CPL; para a base, o que importa é quanto custa cada venda, não o CAC.

**v0.287 · Planejamento de campanha avançado.** Em Marketing, uma tela nova para planejar a campanha antes de criar: escolhe a estratégia e o produto, vê o histórico das últimas campanhas desse produto (CAC, CPL, conversão, ticket, bump e upsell, por canal), confere a margem, marca os recursos que vai usar, vê até quanto o negócio aguenta investir, escolhe o CAC (por exemplo, o do histórico em vez do máximo), copia para os cenários pessimista, base e otimista, divide a verba entre os canais e mexe no funil da campanha etapa por etapa. Tudo fica salvo como rascunho.

**v0.285 · Copiar com as referências.** A cópia para a IA leva os links de cada conteúdo (fonte, copy, mídia, vídeo) e, no fim, as referências do cliente: posts que ele aprova, o que nunca fazer, cores e fontes. Dentro do conteúdo, o botão fica no painel Detalhes, ao lado.

**v0.284 · Copiar para a IA.** No Growth's Content, "Copiar" no cartão, "Copiar tudo" na barra da seleção ou "Copiar tudo para a IA" dentro do conteúdo: o texto sai organizado (título, tema, canais, data, descrição, gancho, roteiro…), pronto para colar no ChatGPT, na Claude ou em outra IA.

**v0.283 · Kanban em lote.** No Growth's Content, marque vários cartões (caixinha, "Selecionar todos" ou Ctrl+clique) e arraste todos de uma vez, ou use "Mover para…" na barra. Dois cliques abrem o cartão. Trocar de aba, filtro ou busca ficou imediato: o Growths não baixa tudo de novo a cada clique.

**v0.282 · Aprovar sem data.** No Growth's Content, aprovar a ideia não pede nada: ela vai para Pautas aprovadas. Tema e data de publicação só quando o conteúdo vai para a produção.

**v0.245 · Resposta à vista.** Quando alguém responde um formulário (lead, cliente ou diagnóstico), a equipe fica sabendo na hora: faixa verde, Meus avisos e WhatsApp, com a pontuação da qualificação.

**v0.244 · Lead novo à vista.** Lead novo aparece numa faixa verde no topo do Growths e o aviso vai para a equipe, também por WhatsApp. Nas pesquisas, dá para gerar um novo link.

**v0.243 · Growths no celular.** No celular, os blocos abrem no lugar (abrir um fecha o outro), o Kanban mostra uma etapa por vez com abas no topo e as janelas abrem em tela cheia com "← Voltar".

**v0.242 · Arrastar.** No Kanban do Growth's Content, no computador é só arrastar o cartão; no celular continua o "Mover para".

**v0.241 · Produção na ordem de leitura.** No Growth's Content, a Produção mostra a contagem por etapa, o Kanban e, depois, a semana e o calendário.

**v0.240 · Baú de ideias com microfone.** No Growth's Content, toque no microfone, fale a ideia e ela entra no Baú de ideias, esperando aprovação.

**v0.239 · Diagnóstico dos dados.** Antes de importar, o Growths lê cada planilha do cliente e mostra o que identificou, o que não identificou, o que dá para calcular e o que perguntar na reunião, num relatório para imprimir.

**v0.238 · Do diagnóstico para o Growths do cliente.** A aba Dados vem logo depois de "O que falta", e cada planilha do cliente pode ser importada para o Growths dele, conferindo o de-para.

**v0.237 · Anexar arquivos.** No formulário do diagnóstico, o cliente volta a anexar cada arquivo no próprio formulário, e editar uma pergunta não apaga mais essa configuração.

**v0.236 · Reabrir o formulário.** No diagnóstico, o link do cliente fica sempre visível para mandar de novo, e dá para reabrir o formulário para ele continuar de onde parou.

**v0.235 · Formulário embutido protegido.** O formulário colado na sua página abre por um endereço próprio. O resto do Growths continua sem poder ser aberto dentro de outros sites.

**v0.234 · Formulário na sua página.** Em Pesquisas, o formulário de captação tem o código para colar na página, que se ajusta à altura sozinho.

**v0.233 · Qualificação por produto.** O formulário de qualificação pontua o lead em blocos e diz qual produto ele comporta (Starter, Strategy ou Full Brain), quão quente ele está e quando o que ele pediu não bate com o que o negócio dele comporta.

**v0.232 · Gerar o link do formulário.** No diagnóstico, o formulário padrão já vem escolhido e um botão gera o link para mandar ao cliente.

**v0.231 · Clientes pelo contrato.** O Growths do cliente é criado sozinho quando o contrato é ativado, com os dados da empresa. Clientes podem ser inativados (somem e perdem o acesso), reativados e excluídos.

**v0.230 · Formulário para clientes.** Em Pesquisas, dá para dizer que quem responde é um cliente: a resposta atualiza o cadastro e a etapa dele na jornada, sem passar pelo Funil de leads.

**v0.229 · O que já se sabe.** Cada informação do cliente aparece com a origem. Quando o que ele declarou não bate com as planilhas, o Growths mostra os dois valores e a equipe decide.

**v0.228 · Diagnóstico de clientes.** Só na Mathisa. O cliente com contrato aparece esperando diagnóstico. O primeiro passo é mandar o formulário padrão por WhatsApp, por e-mail ou pelo link, e a resposta entra sozinha.

**v0.227 · Auditoria das planilhas.** Cada planilha do cliente é conferida sozinha ao abrir o diagnóstico: colunas, datas, valores, repetidas, meses sem dado. O resultado confirma o de-para das métricas.

**v0.226 · Diagnóstico em sete abas.** As abas seguem a ordem do trabalho: Evidências, O que falta, Métricas, Dados, Preparar a reunião, Arquitetura e Validação e entrega.

**v0.225 · De-para das métricas.** O que o cliente usa × o que os dados que ele mandou permitem calcular. No link, ele só conclui com todos os arquivos resolvidos e marca as métricas principais.

**v0.224 · Pré-diagnóstico.** Assim que o cliente sobe os arquivos, o Growths confere o que chegou, o que ele prometeu e o que falta, monta o pedido e a pauta da reunião.

**v0.223 · Diagnóstico Inteligente, primeira parte.** O Diagnóstico Growth é o diagnóstico da empresa, com cinco abas. A Central de Evidências recebe os arquivos do cliente e da equipe, confere repetidos e classifica sem passar por cima da escolha manual.

**v0.222 · Cockpit em abas.** Áreas, Metas do período e Riscos e oportunidades ficam em abas na mesma página, cada uma com o número do que pede atenção.

**v0.221 · Metas para todas as áreas.** Margem, caixa, churn, retenção, LTV, ascensão e North Star ganham meta no Planejamento anual e aparecem no Cockpit, com a fonte de cada número.

**v0.220 · Quanto confiar na projeção.** O Growths refaz a projeção nos meses passados, mede quanto ela errou e mostra no Cockpit a faixa provável do faturamento do mês.

**v0.219 · O funil inteiro.** No painel Growth do Cockpit, o funil AARRR mostra as seis etapas com o período anterior, as metas, a North Star e o gargalo sugerido.

**v0.218 · E se?** "Simular" testa mais leads, mais verba, outra conversão ou outro ticket numa meta e mostra se ela passa a ser alcançada, com as premissas e as incertezas. Os cenários ficam salvos com versão.

**v0.217 · Do número à venda.** "Investigar" abre qualquer meta do Cockpit por produto, campanha, canal, plataforma e cliente novo × recorrente, comparando com o período anterior. Um clique filtra tudo; outro mostra as vendas ou os leads por trás do número.

**v0.216 · A meta no tempo.** O gráfico de trajetória mostra a meta acumulada, o realizado e a projeção até o fim do período, e cada painel do Cockpit mostra as metas da sua área e o risco principal.

**v0.215 · Riscos num lugar só.** O Cockpit lista os riscos e oportunidades do cliente, vindos das metas, dos alertas, dos guardrails e da qualidade dos dados, com evidência, impacto estimado, ação sugerida e quem está tratando.

**v0.214 · Todas as metas no mesmo lugar.** Leads, vendas, as metas de cada campanha e as metas por produto entram no mesmo registro da meta de faturamento e aparecem no Cockpit com o esperado até hoje, o realizado, a projeção e o status.

**v0.213 · A meta no centro.** A meta de faturamento do Planejamento anual aparece no topo do Cockpit com o esperado até hoje, o realizado, o desvio, a projeção e o status. O Planejamento anual tem os objetivos do ano, e a North Star tem status.

**v0.212 · Um filtro só em todos os dashboards.** Financeiro, Customer Success e Cockpit entram no mesmo filtro de período, que começa no mês corrente. O Planejamento da empresa antigo saiu do menu.

**v0.211 · Um período para todos os dashboards.** O mesmo filtro (Período, De, Até) no Administrativo, Marketing, Vendas e Mídia paga, e o período escolhido vale em todos.

**v0.209 · Financeiro simplificado.** DRE do mês sem contas a pagar: o cliente lança os totais e as % dos parceiros, e o Growths mostra receita líquida, Resultado de marketing e Resultado da operação.

**v0.206 · Histórico de vendas.** As vendas de antes do Growths sobem pelo relatório da plataforma e viram o histórico de cada cliente e a base do planejamento, sem mexer no financeiro.

**v0.205 · Go-to-Market.** Pacote para quem não quer o financeiro no Growths: o resultado vira Resultado de marketing (receita menos mídia e custos de marketing), com rotina de fim de mês.

**v0.201 · Entrada do cliente.** Formulário curto para quem está chegando, com a visão dos números e as planilhas do último ano (com modelo para baixar).

**v0.200 · Planeje o ano que vem.** O ano fica no topo do Planejamento anual, e o ano novo pode começar com as premissas do anterior.

**v0.199 · Do faturamento ao lucro.** Editar a meta virou um passo a passo; o imposto vem do regime da empresa e a tela mostra o lucro que sobra em cada cenário.

**v0.198 · Planejamento anual.** A meta do ano sai de uma conta escolhida (ambição, realista ou as duas), com cada número do sistema, digitado ou estimado com ajuda, e vira meta por trimestre e por mês.

**v0.197 · Pesquisas.** Editar e Excluir à vista em cada pesquisa; os modelos que você não usa saem da lista.

**v0.196 · Ligações por qualquer lado.** No mapa da estratégia, cada bloco tem bolinhas de ligação nos quatro lados.

**v0.195 · Mapa da estratégia e Customer Success.** Order bump e downsell no mapa, tela cheia, nome do bloco e rótulo da seta editados com dois cliques. O menu RevOps passa a se chamar Customer Success.

**Visual v0.194 · Campos legíveis.** Em todos os formulários, o nome do campo em negrito, a caixa com borda visível e o exemplo em itálico.

**Marketing v0.193 · Pesquisa na campanha.** A nova campanha pergunta se vai ter pesquisa, qual e onde entra (captação, página de obrigado com o código pronto, disparo para os leads).

**Visual v0.192 · Dashboards em seções.** O Dashboard, o Dashboard financeiro e o Dashboard de Vendas são divididos em seções com moldura e título: cada uma responde uma pergunta (como está o negócio, o que mudou, de onde vem a receita...).

**Financeiro v0.191 · Pagar e receber em lote.** Em Contas a pagar e a receber, um quadradinho em cada conta em aberto: marque as que quiser e dê baixa em todas de uma vez.

Este documento conta o que o Growths faz, para quem e por quê, área por área, em linguagem simples. Ele não descreve tabelas nem código: descreve funcionalidades, decisões e a lógica por trás delas. Serve de base para criar conteúdo sobre o Growths, a Mathisa e o jeito Mathisa de fazer growth.

**Evolução v0.180 · Uma integração, um cartão.** Em Configurações → Integrações, o cartão já existente de Instagram oferece Conectar Instagram e exibe as contas autorizadas pelo cliente. O login OAuth não cria cartões ou seções extras; WhatsApp e Evolution também utilizam seus cartões existentes.

**Evolução v0.179 · Instagram direto.** Em Integrações e Atendimento, Conectar Instagram abre o login da própria plataforma, sem exigir cadastro manual na Zernio. A conta Zernio e a API Key são centrais na Mathisa; cada cliente recebe um perfil técnico próprio e só acessa suas contas sociais. O retorno OAuth é validado no servidor e gera vínculo de conta e canal no workspace. Para anúncios Meta Ads há um processo de autorização distinto.

**Evolução v0.178 · Atendimento e Integrações.** A equipe interna Mathisa pode associar explicitamente uma conta do Instagram ou WhatsApp oficial já existente na Zernio ao workspace de um cliente em Configurações → Integrações. A conta vinculada pode então ser adicionada aos Canais e conexões de Atendimento. Outras contas do mesmo perfil não são incorporadas automaticamente: cada cliente tem somente as contas designadas para ele. A chave da Zernio fica no servidor. O fluxo ainda exige validação do deploy atualizado e publicação da interface.

---

## 1. O que é o Growths

O Growths é a central de gestão e inteligência de crescimento da Mathisa para negócios digitais: infoprodutores, mentores, escolas online e prestadores de serviço.

Num sistema só, cada cliente tem o seu espaço isolado (um "workspace"). Ali estão:

- **captação de leads**, com origem e UTMs;
- **CRM e vendas**, contratos e comissões;
- **financeiro com contabilidade de verdade**: partidas dobradas, DRE e fluxo de caixa;
- **campanhas e mídia paga**;
- **conteúdo**, com o módulo Growth's Content;
- **Customer Success** (antes chamado RevOps): retenção, recompra e expansão;
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
A tela inicial, em três abas na mesma página: **Áreas** (a primeira), **Metas do período** e **Riscos e oportunidades**; as duas últimas mostram no título quantas metas estão fora do esperado e quantos riscos estão em aberto, e o período escolhido vale para as três. Um painel pequeno por área (Geral, Marketing, Vendas, Financeiro, Projetos, Growth e Clientes), dois lado a lado, cada um com os números que mais importam no período: caixa, receita, margem e lucro; campanhas e leads; vendas, ticket e conversão; a receber, a pagar e MRR; projetos e atividades atrasadas; North Star e experimentos; alunos ativos, alertas e satisfação. Cada painel traz também um gráfico: receita e lucro por mês, leads e faturamento por dia, o que entra e o que sai, alunos por etapa. Clicar num painel abre o dashboard daquela área, com tudo em detalhe. Cada pessoa só vê os painéis das áreas a que tem acesso. Em cima, o mesmo filtro de período de todos os dashboards (começa no mês corrente); mudar o período muda todos os painéis.

Logo abaixo, a **Meta de faturamento**: a meta do período (vinda do Planejamento anual), quanto deveria ter sido vendido até hoje, quanto foi vendido, o desvio, a projeção até o fim do período e o status (Dentro do esperado, Atenção, Em risco, Atingida…). Embaixo, o mesmo para o ano. "Como calculamos" mostra a conta, o método da projeção e a regra do status, sem prometer probabilidade. Se as metas dos meses não somam a meta do ano, o Cockpit avisa. Num mês em andamento, abaixo da projeção aparece a **faixa provável** (de quanto a quanto o mês deve fechar), calculada pelo erro que a projeção teve nos meses anteriores na mesma altura do mês; o botão "Acerto da projeção" mostra esse histórico para faturamento, leads e vendas (erro médio, viés e maior erro). É erro observado, não probabilidade. Logo abaixo, o **gráfico de trajetória**: a meta acumulada dia a dia, o realizado acumulado até hoje e a projeção até o fim do período, para ver quando o resultado começou a descolar da meta. Cada meta da tabela tem o mesmo gráfico no botão "Trajetória". O botão **Investigar** abre o número por produto, campanha, canal, plataforma e cliente novo × recorrente (nos leads: campanha, canal, qualificação e situação), comparando com o período anterior e mostrando o que mais mudou. Clicar numa fatia filtra todas as outras; o caminho no topo permite voltar a qualquer passo; "Ver os registros" lista as vendas ou os leads por trás do número, com link para a ficha da pessoa. As fatias sempre somam o total. O botão **Simular** testa o "e se": mais leads, investimento extra em mídia (convertido em leads pelo CPL dos últimos 90 dias), outra conversão ou outro ticket, só no que falta do período. Mostra o atual ao lado do cenário, se a meta passa a ser alcançada, quanto o resto do período precisaria render para bater, as premissas e as incertezas (não é garantia). Os cenários podem ser salvos, carregados, versionados, aprovados e arquivados, sem mexer nos dados reais. Logo depois vêm as metas de leads e de vendas da empresa e as metas de cada campanha e produto, cada uma na sua janela (a campanha conta leads nos dias da captação e vendas nos dias do carrinho aberto); clicar numa campanha abre a campanha.

Abaixo das metas fica **Riscos e oportunidades**: os riscos mais graves do cliente num lugar só. Eles vêm das metas (abaixo do esperado, risco de não atingir, chance de superar), dos alertas do Growths (agrupados: centenas de avisos de aluno parado viram um risco só), dos guardrails e da qualidade dos dados. Cada risco traz a evidência, o impacto estimado e uma ação sugerida. Alguém pode assumir, resolver ou descartar (com nota), e tudo fica no histórico. Quando a causa some, o risco se resolve sozinho; se voltar, reabre. Cada painel de área mostra quantos riscos tem, as metas daquela área com o status e o risco principal, sem média nem nota única.

No painel Growth, **Abrir o funil AARRR** mostra as etapas do Diagnóstico (aquisição, ativação, retenção, receita, recomendação, recompra e ascensão), cada uma respondendo a uma pergunta, com o número do período, o anterior, a meta quando existe e o botão Investigar. A passagem de lead para cliente novo aparece em destaque, a North Star aparece na etapa que ela mede e o "gargalo sugerido" aponta a taxa que mais piorou. O que o Growths ainda não mede (como indicações) aparece como "sem dado", nunca como zero.

### Dashboard geral
O detalhe do painel Geral do Cockpit. Mostra o negócio inteiro num período escolhido:

- receita, lucro e margem por mês;
- o ritmo da meta do mês (está no caminho ou atrás?);
- de onde vem a receita, por produto e por campanha, contra o período anterior;
- DRE e fluxo de caixa recolhidos, para abrir quando quiser.

Desde a v0.192 a tela é dividida em seções com moldura e título (Visão geral, Alertas, Evolução e meta, De onde vem a receita, Saúde financeira, Funil e campanhas, Tabelas completas), para cada assunto ficar separado do outro. O Dashboard financeiro e o Dashboard de Vendas seguem o mesmo padrão.

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
Saiu do menu na v0.212. O planejamento do ano (meta, 3 cenários, trimestres) fica em Marketing › Campanhas e planejamento › Planejamento anual. Desde a v0.213, os objetivos do ano também ficam lá, na seção "Objetivos e metas do ano", ligados às metas que medem cada um. Na mesma seção ficam as metas por produto (criadas ali) e as metas das campanhas (editadas na própria campanha). Logo abaixo, **Metas das áreas**: margem (no mínimo), saldo de caixa (no mínimo), churn (no máximo), retenção em 90 dias, LTV, ascensão e a North Star, com o valor de agora, o status e de onde vem o número (a margem vem da DRE ou, sem lançamentos, do Financeiro simplificado). As metas do Customer Success, o saldo mínimo do Financeiro e a meta da North Star são as mesmas das telas deles: mudar num lugar muda no outro.

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

- **Nova campanha em 4 etapas:**
  1. O básico.
  2. Orçamento e metas.
  3. Canais.
  4. Pesquisa: se a campanha vai ter pesquisa, qual (uma que já existe, um modelo pronto ou nova) e onde entra: na captação, na página de obrigado (o Growths gera o código para colar) ou em disparo para os leads (por enquanto pela fila de envio; o envio automático ainda vai ser decidido).
  
  Produto, estratégia e canal se cadastram sem sair dali, e uma faixa de rascunho mostra o que falta.
- **Estratégia em blocos.** O funil da campanha é montado com blocos prontos em 4 fases (Aquisição, Aquecimento, Conversão, Retenção): conteúdo do Instagram, tráfego pago, página de captura, indicação, grupo de WhatsApp, disparo, e-mail, pesquisa, aula/webinário, VSL, checkout, comercial, recompra e assinatura. Cada bloco traz as métricas certas, com uma principal e as de diagnóstico. Há modelos prontos: lançamento clássico, perpétuo, webinário, disparo, recompra, comercial e social selling.
- **Estratégias (Canvas).** Em Marketing → Estratégias (Canvas), dá para começar pelo mapa ("Criar no mapa"): monta o funil e, ao publicar, dá o nome e a estratégia entra na lista. cada estratégia pode ser vista como mapa: blocos arrastáveis, setas com sim, não e divisão em %, e um painel com objetivo, canal, responsável, oferta e métricas de cada bloco. "Publicar versão" congela a estratégia; a campanha guarda a versão que usou, e mudar a estratégia depois não mexe nela. Cada bloco mostra o desenho do que é: a página de captura ou de vendas vira uma mini página com a foto e os textos que você define, o anúncio leva o símbolo da Meta ou do Google, e o WhatsApp tem o símbolo e a escolha entre API e grupo. Os cards se arrastam por qualquer ponto e se alinham numa grade, cada um pode ficar maior ou menor pelo canto, e o botão Organizar arruma tudo em colunas por fase. O funil inteiro (da captação às vendas e depois o CS) fica num mapa só: cada fase tem uma cor e uma faixa em volta dos seus blocos, e clicar no nome da fase destaca só ela. A fase de cada bloco muda clicando na etiqueta do card, e o bloco "Passagem para o CS" marca onde o cliente passa a ser do CS. A estratégia publicada abre no Resumo (dados, versão e funil por fase), e o botão "Criar campanha" cria a campanha já com ela e com as etapas copiadas.
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
  - Dashboard de vendas com filtro de período e, no topo, valor das vendas, vendas, ticket, clientes novos, clientes ativos e conversão de lead em cliente, contra o período anterior;
  - vendas por plataforma (Hotmart, Kiwify, Eduzz…): bruto, taxas, reembolsos e o que a plataforma deve repassar;
  - quanto custou e o que trouxe cada vídeo ou criativo.
- **Ofertas e esteira.** Oferta principal com order bumps, upsells, downsells e cross-sells. Cada item tem condição (sempre, se aceitou, se recusou), validações contra ciclos e taxa de aceite medida com o denominador certo (quem recebeu a oferta, não todos).
- **Plano do ano (v0.291).** Segunda aba do Planejamento de campanha avançado. Meta de receita × baseline: orçamento de aquisição, clientes novos necessários, CAC máximo, receita mínima, cenários pessimista, base e otimista, trimestres e o orçamento livre para campanhas. Alimenta os passos 2 e 7 de cada campanha.
- **Diagnóstico e baseline (v0.290).** Primeira aba do Planejamento de campanha avançado. Retrato dos últimos 12 meses e ano a ano, com origem, cobertura e confiança de cada indicador; correções marcadas como informadas; apuração do custo de servir; lista do que falta; aprovação com versão. Vale para todas as campanhas do ano.
- **Planejamento de campanha avançado (v0.287).** Tela própria em Marketing, em 14 passos, do histórico do produto ao Growth Model da campanha. Mostra o que as últimas campanhas do produto custaram ao lado de cada limite, para não planejar um CAC de R$ 500 quando o histórico é R$ 195. A escolha do CAC vira a verba; a verba vai para três cenários e é dividida por canal, com quanto o orgânico precisa trazer para a meta. Salva como rascunho por produto e estratégia.
- **Calculadora de campanha.** Preencha o que souber e o resto se ajusta: CPL e conversão dão o CAC, a margem-alvo dá o CAC máximo, e assim por diante. "Salvar metas na campanha" leva tudo para a campanha.
- **Financeiro simplificado** (no Go-to-Market é o único financeiro; no Growths completo, uma visão rápida ao lado do financeiro completo). O cliente lança os totais do mês, de marketing e de outros custos da operação, e os parceiros (coprodutor, afiliado, vendedor) com uma comissão geral e, se for diferente, uma % por produto. O Growths monta o DRE simplificado mês a mês, de faturamento a Resultado da operação, com % do faturamento, médias, gráfico e "para onde vai cada R$ 100 vendidos". Sem caixa, sem o que foi pago e sem lançamento contábil.
- **Custos de marketing e Resultado de marketing** (cliente sem financeiro, pacote Go-to-Market). Custos fixos (repetem todo mês) e variáveis (lançados no fim do mês), sem detalhar a equipe; no último dia do mês o cliente recebe a atividade para lançar e, se não lançar, a Mathisa é avisada; o mês só fecha com tudo lançado. Resultado de marketing = receita − mídia − custos de marketing, sempre com o aviso de que as outras despesas da empresa não entram, com ROAS de mídia, ROAS total, CAC de mídia e CAC completo.
- **Planejamento anual.** Ano escolhido no topo (do ano passado até dois à frente; o ano novo pode começar com as premissas do anterior). Em seções: 1. Meta do ano (ambição, realista ou as duas, com cada premissa do sistema, digitada ou estimada; impostos pelo regime; do faturamento ao lucro; três cenários com o lucro no fim), 2. Por trimestre (ritmo, previsão e sugestão mês a mês), 3. Calendário de campanhas (linha do tempo com lançamentos e perpétuas, meta por campanha, orçamento planejado contra realizado) e as metas mês a mês.
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
- **Baú de ideias:** aprovar ou descartar. **Aprovar ideia** leva para Pautas aprovadas sem pedir nada (v0.282). Tema, subtema, formato e data de publicação só são pedidos quando o conteúdo vai para Em produção: aí ele entra no calendário. Com o **microfone** (v0.240), você fala a ideia, o texto aparece na hora e ela entra no baú esperando aprovação; também dá para falar pelo Kanban da Produção.
- **Kanban em lote** (v0.283): cada cartão tem uma caixinha para marcar; no topo da coluna, "Selecionar todos". Com cartões marcados aparece uma barra com a quantidade, "Mover para…" e "Limpar seleção". Arrastar qualquer marcado leva todos. Para Em produção, os sem tema ou data ficam e a tela diz quais. **Dois cliques** no cartão abrem o conteúdo.
- **Copiar para a IA** (v0.284): "Copiar" em cada cartão; "Copiar tudo" na barra quando há cartões marcados (vários, separados por ---); "Copiar tudo para a IA" dentro do conteúdo aberto, com o que está na tela mesmo antes de salvar. Só os campos preenchidos entram.
  - Com as referências (v0.285): "Referências e links" de cada conteúdo e "Referências do cliente" (de Identidade visual) uma vez no fim. Dentro do conteúdo, o botão fica no painel Detalhes.
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

### Atendimento multicanal

A Central de Atendimento reúne conversas do WhatsApp oficial e do Instagram pela Zernio, além do WhatsApp e grupos pela Evolution. À esquerda ficam as conversas e os filtros; no centro, o histórico e as respostas; à direita, a pessoa do CRM, com responsável, oportunidades, compras e acesso à ficha completa. É possível registrar notas internas e indicar se a conversa está aberta, aguardando ou resolvida.

As respostas levam o nome do atendente cadastrado no Growths. Nos grupos, cada mensagem identifica seu participante. O histórico capturado fica salvo no Growths e continua disponível mesmo se o número for desconectado; arquivos recebidos são copiados para armazenamento privado, com indicação quando a recuperação ainda está pendente. Conversas individuais podem ser vinculadas a pessoas existentes ou originar um novo lead.

A primeira etapa está implementada e testada localmente na v0.175, aguardando publicação do banco e da função e configuração dos canais. Templates, disparos, automações e outros canais serão etapas seguintes.

## 6. Customer Success: retenção e expansão

O menu se chamava RevOps até a v0.195.

- **Retenção & Expansão**, com filtros de período da primeira compra, produto, canal, campanha, origem e segmento:
  - **Coortes:** segunda compra em 30, 60, 90, 180 e 365 dias, receita acumulada por cliente, curva D0 a D365 e matriz de coortes. Coorte que não completou o prazo aparece como "indisponível", com o parcial à mostra.
  - **Recompra:** taxa, intervalo entre compras, frequência, ticket de recompra, receita de novos contra existentes e o papel de cada produto de entrada (expande, recompra moderada, não expande).
  - **RFM:** sete segmentos com regras editáveis, a grade R×F e o cruzamento com produto, campanha, canal e origem.
  - **Investigar:** qualquer número abre a lista de clientes com o histórico, exportável.
- **Alunos.** Kanban da jornada de depois da compra, com CS responsável. O aluno nasce sozinho na venda ou no contrato. Escolhe-se a jornada (a geral ou a de cada produto) ou a lista de todos os produtos, uma linha por matrícula.
- **Jornada do produto.** Cada produto pode ter as próprias etapas (uma mentoria não anda como um curso online), com versões: ao publicar uma versão nova, decide-se se quem já está dentro continua na antiga ou é transferido. Dá para salvar uma jornada como modelo e começar outras a partir dele.
- **Marcos.** O que o aluno precisa atingir em cada jornada, com prazo e prova. Alguns a equipe confirma; outros o sistema percebe sozinho (comprou, assistiu à aula, respondeu que teve resultado, chegou à etapa, entrou no grupo, ou um evento que a plataforma do curso manda), com ou sem confirmação da equipe.
- **Customer Growth.** A tela de acompanhamento dos alunos: evolução por produto, check-ins que voltam a cada tantos dias, alertas para o CS (parado, marco atrasado, check-in sem resposta, nota baixa), intervenções com o efeito de cada uma, oportunidades de retenção e expansão e os indicadores de evolução. Na ficha de cada pessoa, a jornada dela em cada produto.
- **Dashboard de Customer Success.** Ativos, churn, retenção, LTV e ascensão, com semáforo contra metas.

---

## 7. Financeiro e contabilidade

- **Contabilidade de verdade.** Cada venda, recebimento, conta e pagamento gera as partidas dobradas sozinho, pelas regras contábeis (que podem ser personalizadas). Nada se apaga: correção é estorno.
- **Contas a receber.** Parcelas de contratos e vendas, provisionamento por mês e por cliente, MRR/ARR, receitas avulsas (com repetição) e desconto em parcela, que vira dedução da receita e não despesa. Também dá para cancelar, desfazer recebimento e reativar.
- **Pagar e receber em lote.** Nas duas telas, cada conta em aberto tem um quadradinho: você marca as que quer (ou todas pelo cabeçalho), vê quantas são e o total numa barra embaixo e dá baixa em todas de uma vez, com a data e a conta bancária. Cada uma vira o mesmo lançamento da baixa individual. Conta com valor estimado só entra depois de confirmar o valor real.
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

- **Diagnóstico de clientes (só da Mathisa, desde a v0.228).**
  - **Quem aparece esperando diagnóstico:** os clientes com contrato ativo, ou que estão na etapa "Diagnóstico" da jornada.
  - **Como começa:** "Começar diagnóstico" já vem com o formulário padrão escolhido.
  - **Aba 1, Formulário:** o formulário padrão já vem escolhido e o botão **Gerar o link do formulário** cria o link do cliente. Depois mostra a situação (escolhido, enviado, cliente preenchendo, respondido), a mensagem pronta com o link do cliente e os botões de WhatsApp, e-mail e copiar o link.
  - **Link sempre à mão e reabrir** (v0.236): o link do cliente fica visível também depois que ele responde (serve para mandar os arquivos que faltam). "Reabrir para o cliente continuar" deixa ele mudar as respostas pelo mesmo link; a última resposta enviada é a que vale.
  - **Dados e importar** (v0.238): a aba Dados vem logo depois de "O que falta". Cada planilha tem "Importar": o Growths abre o de-para (colunas do arquivo ao lado dos campos do Growths) já no Growths do cliente, você confere e importa leads, clientes, produtos, campanhas ou vendas, sem duplicar quem já existe.
  - **Diagnóstico dos dados** (v0.239): um botão na aba Dados e em Preparar a reunião lê cada planilha e mostra, coluna por coluna, o que ela é no Growths (ou "Não identifiquei"), quanto está preenchida, o que não veio, as métricas que dá para calcular e as perguntas para a reunião. Imprime ou salva em PDF, com e-mails e telefones escondidos.
  - **O que entra sozinho:** a resposta e os arquivos do cliente.
  - **O modelo "Diagnóstico Mathisa (pré-diagnóstico)":** pede o perfil, os números do jeito do cliente, o que ele acompanha e quais são os principais, o que espera e os arquivos por plataforma de venda.
  - **O que já se sabe** (aba 4, v0.229): tudo sobre o cliente, com a origem — o que ele declarou no formulário, o que as planilhas mostram (vendas válidas, faturamento, média por mês, ticket, compradores, produtos, leads, investimento) e o que a equipe anotou na reunião.
    - **"As fontes batem?":** faturamento, ticket e investimento declarados × planilhas. Acima de 20% de diferença, a equipe decide qual vale, corrige ou leva para a reunião, e isso entra na pauta.
    - **Revisão:** cada informação pode ser confirmada, corrigida ou rejeitada.
  - **Nas outras empresas,** Diagnóstico Growth continua sendo a leitura de planilhas que monta o Growth Model.

- **Diagnóstico Growth: o diagnóstico da empresa** (desde a v0.223). Uma lista de diagnósticos, cada um com responsável, período de referência, versão, status (em coleta, em análise, em revisão, validado, arquivado) e o progresso por etapas. Dentro, sete abas na ordem do trabalho (desde a v0.226). A Investigação de antes virou três delas: **O que falta** (o checklist), **Métricas** (o de-para, com três abas próprias) e **Preparar a reunião** (o pedido ao cliente e a pauta). Antes da divisão, eram cinco:
  - **Evidências:** tudo o que serve de prova, mandado pelo cliente (pelo link do formulário) ou pela equipe. O Growths confere o tipo real do arquivo, o tamanho e o conteúdo: o mesmo arquivo não entra duas vezes, e o mesmo nome com conteúdo novo vira versão 2. Cada arquivo tem classificação (14 tipos, sugerida pelo nome sem nunca trocar a escolha manual), período que representa, marca de dados pessoais e status de leitura. O original nunca é apagado: arquiva-se.
  - **Investigação: o pré-diagnóstico, antes da reunião** (v0.224). Um checklist cruza o que o cliente disse no formulário com o que chegou e com os meses que os arquivos cobrem. As situações são: recebido, recebido em parte, disse que tem e não mandou, não tem, falta. Embaixo vêm o que os dados mostram, a mensagem pronta para pedir o que falta (editável) e a lista do que conversar. Junto vem o **de-para das métricas** (v0.225):
    - **o que o cliente usa hoje:** principal ou não, onde vê, se já se sabe como calcula e se os dados que ele mandou permitem conferir;
    - **o que dá para calcular e ele não olha;**
    - **o que não dá para calcular com o que veio,** e o que faltaria.

    A equipe marca como revisado e segue para a reunião do diagnóstico, que tem os números que decidem, o roteiro e as anotações.
  - **Dados:** a **auditoria das planilhas** (desde a v0.227) e a leitura consolidada.
    - **A auditoria:** cada planilha é conferida sozinha quando o diagnóstico abre. Mostra o tipo (vendas, leads, anúncios), o que é cada coluna (dá para trocar), o tipo de dado, quanto está preenchido, as linhas repetidas, as datas que não dá para ler, as datas no futuro ou fora do período, os meses sem dado e os valores negativos ou zerados.
    - **O que mais aparece:** as linhas por mês, os produtos, os canais e o status. E-mails, CPFs, telefones e nomes nunca aparecem: viram •••.
    - **Para o de-para:** a auditoria diz se as métricas podem mesmo ser calculadas.
    - **A leitura consolidada** continua abaixo dela.
  - **Arquitetura:** a North Star da empresa e o caminho para o mapa de métricas.
  - **Validação e entrega:** a mudança de status e o histórico, com decisões e comentários que não se apagam.
- **Leitura de planilhas.** Sobe planilhas bagunçadas do cliente e o sistema identifica vendas, leads e investimento. Classifica cada venda (nova, renovação, upgrade, repetida) e mostra o que falta em 13 itens, com a mensagem pronta para pedir ao cliente e a planilha padronizada para baixar.
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
  - página pública de resposta, com um título para quem responde diferente do nome interno da pesquisa;
  - NPS, PMF e insights; o must-have aparece em três faixas (40% ou mais, 25% a 40%, menos de 25%) com o próximo passo, sem contar quem marcou "Não se aplica";
  - **qualificação por pontos:** cada resposta vale pontos e tags, e a nota de corte decide quem é qualificado na hora;
  - **formulário de captação** com a cara do cliente (fontes e cores), em passos, que coloca quem responde direto no funil de leads;
  - a aba "Quem respondeu";
  - **Histórico de vendas** (Importar e validar dados): o relatório que a plataforma exporta, com de-para automático, conferência antes de gravar e desfazer; vira o histórico de cada cliente (bloco "Antes do Growths" na ficha) e a base do planejamento anual, sem financeiro;
  - **Quem responde** (v0.230): em Formulário e aparência, você escolhe se quem responde é um **lead** (entra no Funil de leads) ou um **cliente** (atualiza o cadastro e vai para a etapa escolhida da jornada do cliente, por exemplo Diagnóstico, sem entrar no Funil de leads). Vale para o link individual e para o link aberto, e fica no histórico do cliente.
  - **Qualificação por produto** (v0.233): na aba Qualificação e pontos, cada pergunta pode ter um bloco (Porte, Estrutura, Momento) e uma resposta pode eliminar o lead. Grupos de regras põem a tag do produto indicado (Starter, Strategy, Full Brain) e da temperatura (quente, morno, frio). Se o que o lead pediu não bate com o indicado, ele ganha a tag "revisar". "Quem respondeu" mostra os pontos de cada bloco.
  - **Código para a página** (v0.234): em Formulário e aparência, junto do link, o código para colar num bloco de HTML (WordPress, Elementor, Webflow…). O formulário se ajusta à altura e leva a origem (UTM) escolhida.
  - **Gerar novo link** (v0.244): atualiza o endereço do link (mesmo código) ou troca o código, quando o link antigo não deve mais funcionar.
  - **Aviso de formulário respondido** (v0.245): quando alguém responde, a equipe recebe "<nome> respondeu o formulário" com o nome do formulário e, na qualificação, a pontuação e as faixas (por exemplo, Strategy · quente). Lead novo pelo formulário gera os dois avisos: lead novo e resposta. Cada pessoa liga ou desliga em Equipe.
  - **Entrada do cliente**: formulário curto para o cliente que está chegando (faturamento, ticket, clientes, investimento, custo e regime, do jeito dele) e o checklist de arquivos do período certo (vendas, clientes, leads, anúncios, custos), cada um com planilha-modelo para baixar; cada grupo é enviar o arquivo ou "Não tenho", sem deixar para depois, e ganha ✓ verde quando o arquivo chega. Inclui a lista "quais números você acompanha hoje", ponto de partida do diagnóstico. As vendas seguem as plataformas que o cliente marca (Hotmart, Kiwify, Eduzz, Hubla): um relatório para cada, do jeito que sai.

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
- **Clientes nascem do contrato** (v0.231). O produto diz se inclui o Growths do cliente. Ao ativar o contrato, o Growths da empresa é criado com nome, razão social, CNPJ, pacote e o responsável convidado como administrador. Em Pacotes de acesso, cada cliente mostra a situação e o contrato de origem, com **Inativar** (some da lista de todos e perde o acesso, sem apagar nada), **Reativar** e **Excluir** (só depois de inativar, digitando o nome).
- **Integrações e conexões.** Meta (anúncios e Instagram), Google (Ads e YouTube), formulários, Instagram pelo Zernio e WhatsApp e e-mail para avisos.

---

## 11. Visual e experiência

- **No celular** (v0.243): os blocos com título viram sanfona (toca no título e ele abre ali mesmo; abrir um fecha o outro), todo Kanban mostra uma etapa por vez com as etapas como abas no topo, e formulários e cartões abrem em tela cheia com "← Voltar".
- **Claro como padrão e escuro como opção.** Uma ação principal por tela.
- **Um filtro de período só.** Todos os dashboards têm em cima o mesmo filtro (Últimos 30 dias, Este mês, Próximos 30 dias, Últimos 7 dias… e Personalizado), que começa no mês corrente e vale em todos.
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

- "O lead esfria em 5 minutos": por que o aviso de lead novo chega no WhatsApp da equipe na hora.

- "Do Growths para a IA em um clique": levar a pauta inteira, com contexto, para a IA escrever o roteiro.

- "Arraste dez de uma vez": organizar a semana de conteúdo em lote, em vez de cartão por cartão.

- "Aprovar não é agendar": separar o que vale a pena do que já tem data tira o peso de decidir tudo de uma vez.

- "Ele respondeu, e agora?": o aviso chega com a pontuação e a faixa, e a equipe já sabe qual conversa ter antes de ligar.

- "A melhor ideia de conteúdo aparece no carro": por que o baú de ideias tem microfone.

- "Metade das colunas da sua planilha não serve para nada": o que o diagnóstico dos dados mostra antes da primeira reunião.

- "A planilha do cliente vira base em 5 minutos": o de-para que coloca as colunas dele ao lado dos campos do sistema.

- "Ele quer implementação, mas fatura R$ 25 mil": por que a qualificação compara o que o lead pede com o que o negócio comporta.

- "O cliente assina e o sistema dele já está pronto": o onboarding que começa no contrato, não numa planilha de pendências.

- "Você disse que fatura R$ 80 mil, sua planilha diz R$ 62 mil": por que o diagnóstico compara o que o cliente declara com o que os dados mostram.
- "Sua planilha de vendas tem 12% das datas ilegíveis": o que a auditoria encontra nas planilhas que todo cliente manda.
- "Você acompanha CAC, mas consegue me mostrar a conta?": o de-para entre a métrica que o cliente usa e o dado que ele tem.
- "Seus dados já calculam o LTV e você não olha": métricas escondidas nas planilhas que todo infoprodutor já tem.
- "A reunião começa antes da reunião": o pré-diagnóstico que mostra o que o cliente prometeu e não mandou.
- "O cliente mandou a mesma planilha três vezes": por que todo diagnóstico começa organizando as evidências.
- Sugestão de IA que não passa por cima da sua escolha: classificar documentos com o humano no controle.
- "Seu lucro tem três números diferentes?" A história da auditoria de consistência.
- Por que "sem dado" é melhor do que zero.
- Meta, previsão e probabilidade não são a mesma coisa (e por que o Growths ainda não mostra probabilidade).
- "Esperado até hoje": o número que diz se você está atrasado antes do fim do mês.
- Meta de lançamento não é linear: por que o Growths mede leads na captação e vendas no carrinho.
- 948 alertas ou 2 riscos? Como transformar aviso em decisão.
- O dia em que a curva descolou: ler a trajetória da meta.
- "Faturamento caiu 71%": como descer do número até a campanha que explica a queda em três cliques.
- Mais verba ou mais ticket? Simular antes de decidir (e por que dobrar a verba não dobra as vendas).
- O funil pirata não é uma linha reta: AARRR para quem vende curso e mentoria.
- Sua previsão erra para baixo? Por que o ritmo do dia 15 engana em mês de lançamento.
- Meta que soma e meta que não soma: faturamento × margem, churn e caixa.
- Risco, oportunidade e problema de dado: três coisas diferentes no mesmo painel.
- Um período só para a empresa inteira: por que marketing, vendas e financeiro precisam olhar a mesma janela de tempo.
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
- Fechar o mês em um clique: pagar dez contas de uma vez sem perder o lançamento de cada uma.
- Dashboard não é relatório: por que cada bloco da tela precisa responder uma pergunta só.
- A pesquisa na página de obrigado: o momento em que o lead mais quer falar com você.
- Ambição × realista: por que a meta do ano precisa de duas contas, e o que fazer com a diferença.
- Primeira compra e recompra: o que o histórico do último ano conta sobre o seu cliente.
- "Para onde vai cada R$ 100 que você vende": taxas, comissões, mídia, marketing e o que sobra.
- "Seu lucro de marketing não é o lucro da empresa": ROAS, CAC de mídia e CAC completo, e por que separar.
- "Me manda suas planilhas": o que pedir a um cliente novo para montar o histórico e o diagnóstico (e por que o relatório da plataforma basta).
- Novembro é mês de planejar o ano que vem: o que levar do ano que termina e o que recalcular.
- "Quero lucrar 200 mil": quanto precisa faturar depois do imposto e das comissões (a conta que quase ninguém faz).

---

## 14. Histórico resumido

- **07/11 (v0.285):** Content: a cópia para a IA leva as referências; botão no painel Detalhes.
- **07/11 (v0.284):** Content: copiar tudo de um ou vários conteúdos para levar a uma IA.
- **07/11 (v0.283):** Content: selecionar vários e mover de uma vez, dois cliques para abrir, carregamento mais rápido.
- **07/11 (v0.282):** Growth's Content: aprovar a ideia sem data; tema e data só na produção.
- **02/11 (v0.245):** aviso de formulário respondido, com a pontuação da qualificação.
- **02/11 (v0.244):** aviso de lead novo (faixa verde e WhatsApp) e "Gerar novo link" nas pesquisas.
- **02/11 (v0.243):** celular: sanfona, Kanban por etapa e janelas em tela cheia.
- **02/11 (v0.242):** Kanban do Content: no computador só arrastar.
- **02/11 (v0.241):** Growth's Content: Kanban logo abaixo da contagem, antes do calendário.
- **02/11 (v0.240):** Growth's Content: Baú de ideias com microfone.
- **02/11 (v0.239):** diagnóstico dos dados para levar à reunião.
- **02/11 (v0.238):** diagnóstico: Dados depois de "O que falta" e importar para o Growths do cliente.
- **02/11 (v0.237):** diagnóstico: o cliente volta a anexar os arquivos; o editor de perguntas não apaga mais a configuração.
- **02/11 (v0.236):** diagnóstico: link do cliente sempre visível e reabrir o formulário.
- **02/11 (v0.235):** endereço próprio para o formulário embutido em outras páginas.
- **02/11 (v0.234):** código para colocar o formulário na página.
- **02/11 (v0.233):** qualificação do lead por produto (Starter, Strategy, Full Brain) e o formulário "Lead: qualificação".
- **02/11 (v0.232):** correção: gerar o link do formulário no diagnóstico.
- **02/11 (v0.231):** o Growths do cliente nasce do contrato; inativar, reativar e excluir clientes.
- **02/11 (v0.230):** formulário para clientes (atualiza o cliente e a etapa na jornada, sem Funil de leads).
- **02/11 (v0.229):** o que já se sabe do cliente (origem e conflitos entre fontes); excluir pergunta direto na lista.
- **02/11 (v0.228):** diagnóstico de clientes da Mathisa começa pelo cliente e pelo formulário.
- **02/11 (v0.227):** auditoria automática das planilhas do diagnóstico.
- **02/11 (v0.226):** diagnóstico em sete abas; de-para em três abas.
- **02/11 (v0.225):** de-para das métricas; formulário do diagnóstico só conclui com os arquivos resolvidos; métricas principais.
- **02/11 (v0.224):** pré-diagnóstico na Investigação, antes da reunião.
- **02/11 (v0.223):** Diagnóstico Inteligente D1: diagnóstico da empresa em cinco abas e Central de Evidências.
- **02/11 (v0.222):** Cockpit em abas; padrão de abas para as páginas longas.
- **01/11 (v0.221):** metas das áreas (Financeiro, CS e Growth) no Planejamento anual e no Cockpit.
- **01/11 (v0.220):** acerto da projeção e faixa provável no Cockpit.
- **01/11 (v0.219):** funil AARRR no Cockpit.
- **01/11 (v0.218):** cenários ligados à meta: simular, comparar e salvar com versão.
- **01/11 (v0.217):** investigação: do número do Cockpit até as vendas e os leads.
- **01/11 (v0.216):** trajetória das metas e saúde por área no Cockpit.
- **01/11 (v0.215):** Risk Engine: riscos e oportunidades no Cockpit, com tratamento e histórico.
- **01/11 (v0.214):** metas de leads, vendas, campanhas e produtos no registro central e no Cockpit.
- **01/11 (v0.213):** Growth's Brain, primeiro fluxo: meta de faturamento no Cockpit, objetivos do ano, NSM com status.
- **01/11 (v0.212):** Financeiro, Customer Success e Cockpit no mesmo filtro de período; sem o Planejamento da empresa antigo.
- **01/11 (v0.211):** Dashboards com o mesmo filtro de período, que vale em todos.
- **01/11 (v0.210):** Financeiro simplificado também no completo; comissão de parceiro geral ou por produto.
- **01/11 (v0.209):** Financeiro simplificado: DRE do mês sem contas a pagar, com custos por grupo e comissões de parceiros.
- **01/11 (v0.208):** Dashboard de vendas no padrão dos outros: filtro de período e os números de vendas e clientes no topo.
- **01/11 (v0.207):** Entrada do cliente com ✓ verde nos arquivos e a lista de números que o cliente acompanha.
- **01/11 (v0.206):** Histórico de vendas: importar o relatório da plataforma, ficha com o histórico, planejamento com o histórico.
- **01/11 (v0.205):** Pacote Go-to-Market (sem financeiro), Custos de marketing com rotina mensal, Resultado de marketing e vendas por plataforma.
- **01/11 (v0.204):** Pesquisas: nome só para a equipe e título para quem responde.
- **01/11 (v0.203):** Entrada do cliente: vendas por plataforma marcada.
- **01/11 (v0.202):** Entrada do cliente: cada arquivo é enviar ou "Não tenho".
- **01/11 (v0.201):** Entrada do cliente: formulário curto com os números do cliente e o checklist de arquivos com planilha-modelo.
- **01/11 (v0.200):** Planejar outro ano: ano no topo, começar com as premissas do ano anterior, excluir a meta.
- **01/11 (v0.199):** Meta do ano em quatro passos, impostos pelo regime, comissões fora dos custos fixos e o lucro final por cenário.
- **01/11 (v0.198):** Planejamento anual com meta do ano por método (ambição × realista), cenários e trimestres.
- **30/10 (v0.177):** Diagnóstico 360°: formulário curto do cliente (salva e continua depois), envio de arquivos pelo link e a reunião do diagnóstico, com a leitura dos arquivos no Diagnóstico Growth.
- **30/10 (v0.176):** Diagnóstico 360° (G1): formulário do cliente com as métricas do funil pirata e o modelo pronto com as 8 seções.
- **30/10 (v0.175):** Central de Atendimento, grupos WhatsApp, conexões, assinatura do atendente e histórico ligado ao CRM; publicação e configuração pendentes.
- **30/10 (v0.174):** O lead vira oportunidade, e a oportunidade gera o contrato em rascunho (a proposta).
- **30/10 (v0.173):** CPF/CNPJ no cadastro da pessoa e linha do tempo única do cliente na ficha.
- **30/10 (v0.172):** Resumo da estratégia (funil por fase) e Criar campanha direto da estratégia.
- **29/10 (v0.171):** Publicar a estratégia volta a funcionar; a fase muda no próprio card; bloco Passagem para o CS.
- **29/10 (v0.170):** Criar a estratégia direto no mapa: monta o funil e, ao publicar, dá o nome e ela entra na lista com as etapas.
- **29/10 (v0.169):** Lixeira nos cards do Canvas, com Desfazer por alguns segundos.
- **29/10 (v0.168):** Canvas por fase: o funil inteiro num mapa só, com cor e faixa para Captação, Aquecimento, Vendas e Pós-venda (CS).
- **29/10 (v0.167):** Ajustar os cards do Canvas: arrastar por qualquer ponto, mudar o tamanho pelo canto e Organizar por fase.
- **29/10 (v0.166):** Desenhos nos blocos do Canvas: mini páginas com foto e textos, anúncios com o símbolo da Meta e do Google, WhatsApp com API ou Grupo.
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
- **31/10 (Financeiro):**
  - pagar e receber várias contas de uma vez, com seleção, total e baixa em lote;
  - plano da North Star no Growths (onde cadastrar e como configurar), a partir do documento de NSM da consultoria;
  - Dashboard, Dashboard financeiro e Dashboard de Vendas divididos em seções com moldura e título;
  - pesquisa dentro da campanha: escolher qual e onde entra, código para a página de obrigado e leads na fila de envio;
  - campos de formulário com o nome em negrito e a caixa bem marcada.
- **01/11:**
  - mapa da estratégia com order bump e downsell, tela cheia e edição com dois cliques;
  - menu RevOps passa a se chamar Customer Success;
  - bolinha de ligação nos quatro lados dos blocos do mapa, com mais de uma ligação se precisar;
  - pesquisas com Editar e Excluir à vista e modelos que saem da lista;
  - planejamento anual com meta do ano por método (ambição × realista), cenários e divisão por trimestre e mês.
