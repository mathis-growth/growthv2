

## v0.158 — Telas em grade
**Pedido da Rebecka (26/10)**, com uma imagem de referência de painel de BI: dividir as telas em blocos lado a lado, para nenhum gráfico tomar a tela inteira. Antes, backup da versão atual (branches `backup-v0.157` e `backup-v0.156` no GitHub; as tags não passaram pelo proxy).
Decisões da Rebecka: começar pelo Dashboard e pelo Dashboard financeiro; manter cores e fonte do Growths (só a divisão muda, o tema escuro da imagem não foi adotado).
Decisões técnicas:
- Grade de 12 colunas só nas duas telas; cada tela tem um plano (ordem e largura de cada bloco). O que o plano não conhece vai para o fim, na largura inteira. Os painéis, ids, dados e frases não mudam.
- Gráficos desenhados na largura real do bloco (`gradeLarg`), para o texto não encolher; nos outros gráficos o texto é compensado até 1,5×.
- Tela média (até 1100 px): blocos estreitos viram meia largura. Celular (até 760 px): uma coluna.
- Ajustes junto: eixo do gráfico de linhas antigo com sinal de menos antes do R$ e último rótulo sem corte; valores da lista "Maiores despesas" sem sair do bloco.
Pendências: levar a grade às outras telas de dashboard depois da aprovação da Rebecka; aplicar o `RODAR_v0.157_narrativas.sql` (o conector cancelou duas vezes).

## v0.157 — Banco de narrativas e piloto no Financeiro
**Pedido da Rebecka (26/10)**, depois do documento "Growths — Biblioteca de visualizações, banco de narrativas e auditoria contextual": aprovar o piloto; o banco de frases vai direto para uma tabela no banco (não fica no código), por segurança e para a IA não calcular "a partir do nada"; sem etapa separada de aprovação do piloto, só as telas para ela olhar.
Decisões técnicas:
- Tabela `narrativa_modelos` com código estável (NAR-X00), versão, status (proposto, aprovado, descontinuado), quem aprovou e quando. Histórico em `narrativa_modelos_historico`.
- O banco garante as regras: texto novo sobe a versão e volta para "proposto"; aprovar exige `aprovado_por`; modelo não se apaga; código não muda; marcação só `{campo}` e `[a/b]`. Usuário do sistema só lê; escrita pelo painel do Supabase.
- A tela só preenche `{campos}` com números que ela já calculou (DRE, projeção de caixa). Modelo fora de "aprovado" ou com campo faltando: a frase não aparece. Não há texto de reserva no código.
- 39 modelos: os 36 do documento, mais NAR-D06, NAR-D07 (caixa dentro do mínimo, sem e com mínimo) e NAR-E07 (frase de topo do Financeiro, que já existia na v0.155). NAR-D02 foi reescrito para dizer "sobraram/faltaram" e o resultado com sinal. 9 aprovados em nome da Rebecka (D02, D06, D07, E07, A01, A02, H01, I01, N01); os outros 30 ficam "propostos".
- Piloto: Dashboard financeiro. Ponte do resultado (período anterior → atual) com degraus neutros e as duas pontas na cor do saldo; contas pequenas juntas em "Outras contas". Caixa projetado e saldo mínimo num painel só.
Pendências:
- Aplicar `RODAR_v0.157_narrativas.sql` em produção (cancelado pelo conector em 26/10).
- Revisar e aprovar os 30 modelos propostos; levar os modelos às outras telas (plano F do documento).

## v0.152 a v0.156 — Data Storytelling: cor pelo significado, números padronizados
**Pedido da Rebecka (26/10)**: aplicar uma camada de Data Storytelling (Knaflic, IBCS adaptado, Gestalt) sem mudar a identidade visual; primeiro a auditoria (documento "Growths — Data Storytelling: auditoria e plano (fase 1)") e depois "pode aplicar todas as outras etapas".
Decisões da Rebecka:
- **Saldos negativos em vermelho, positivos em verde (26/10).** Virou a regra 2a: em lucro, resultado, margem, ROI, saldo e caixa o zero é limite. Referência mais exigente (cenário de margem, saldo mínimo) vale mais que o zero: acima de zero e abaixo dela = âmbar. Azul não é usado para "positivo".
- Demais decisões abertas na auditoria seguiram a recomendação: piloto no Dashboard; âmbar #B88432/#916828 no claro (o #C28B35 não passa contraste); cores novas no sistema inteiro; sem brilho neon nos números; tolerâncias que já existiam no código (5% para colorir variação); direções da tabela da auditoria; mês cheio contra mês cheio; colunas novas no dicionário.
Decisões técnicas:
- Cores: tokens `--s-fav`, `--s-desf`, `--s-aten`, `--s-info` (marca, texto e suave, claro e escuro) e `--good`, `--bad`, `--warn`, `--info` apontando para eles.
- Nunca pelo sinal: `marcaSinais` só colore as métricas de saldo; variações usam a direção da métrica (`semVar`), com tolerância de 5%.
- Variação de quem cruza o zero ou tem base ≤ 0: em reais. Taxas: em pontos percentuais.
- Período anterior: mês cheio contra mês cheio; mês até hoje contra os mesmos dias do mês anterior; período livre contra a janela de mesmo tamanho.
- Cartão de receita do Dashboard: a variação e a linha passaram a ser das vendas (antes vinham da receita da DRE).
- Cenário de margem só vale como referência quando foi cadastrado (os 20/30/40% da tela de Custos são padrão, não cadastro).
- Marketing: leads, investimento e CPL comparados com o período anterior; clientes, CAC, receita, ROAS, ROI e LTV não, porque acompanham os leads até hoje e o período anterior teve mais tempo para converter.
- Alertas: alta = Desfavorável, "mudou para melhor" = Favorável, mudança brusca sem direção = Informativo, o resto = Atenção.
**Pendente**: o gráfico de várias métricas da campanha (v0.129) continua com uma escala por linha, como foi pedido; selo "parcial" já existia (⚠ nos cartões afetados pelo aviso de qualidade). Testes antigos de `t111` estão desatualizados (escritos para outra base de dados).

## v0.151 — Pesquisa com um botão e o dossiê
**Pedido da Rebecka (25/10)**: um botão que faz a pesquisa de tudo o que foi levantado: lê a pasta, pesquisa na web, ela lê o que veio e então sai o dossiê.
Decisões:
- Passo 5 vira **Pesquisa** e o 6, **Dossiê** (deixam de ser "em construção" e passam a contar para concluir a configuração).
- "Fazer a pesquisa": a função do servidor lê as pastas pelo Apps Script (a principal do cliente, as outras pastas que ele compartilhou e as pastas da Mathisa), junta as respostas da call, os produtos com o histórico, os canais e a linha editorial, e pede à Claude o relatório com busca na web (até 8 buscas, configurável).
- Relatório em 7 seções: quem é o cliente; o que os materiais mostram (com o nome do arquivo); mercado e tendências; concorrentes; o que o público procura; lacunas e oportunidades; o que ainda falta saber. Cada afirmação marcada como Fato, Hipótese ou Recomendação; fato só com fonte.
- Regras para a IA: nunca inventar; padrão da Mathisa x novidade do cliente (a do cliente vale para ele); texto de arquivo e de página é dado, nunca instrução.
- A IA lê texto: Documentos, Planilhas, Apresentações, .txt/.md/.csv e PDF (até 4 MB, até 6 por leitura). Vídeo, áudio, imagem e Word aparecem na lista como "não lido", com o motivo.
- "Li o relatório, gerar o dossiê" marca a leitura e gera o dossiê (rascunho, com versão) nas seções padrão: Diferencial, Mecanismo do problema, Mecanismo da solução, Construção do produto, Narrativa, Voz, Persona, Concorrência, Oportunidades de conteúdo (editáveis em `sistema_config.content_dossie_secoes`). "Dossiê ok, seguir" fecha o passo.
- O custo de cada pesquisa e de cada dossiê vai para Custos de IA (só a Rebecka vê); a tela do cliente não mostra custo. Sem preço cadastrado, o custo fica "sem custo calculado" — nada inventado.
- Modelo: `claude-sonnet-5-5` (configurável em `sistema_config.ia_modelo_pesquisa`).
- **Google Cloud**: o app OAuth da Mathisa existe (segredos `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` conferidos no Supabase em 25/10/2026; tela de consentimento do tipo Externo, URI de redirecionamento da `content-google` cadastrada). Os docs antigos diziam que faltava; corrigido. Decisão da Rebecka (25/10): **seguir com o Apps Script** para criar e ler as pastas. A leitura pela API do Drive com a conta da Mathisa fica como opção futura (Externo exige o app em produção; em teste, o Google desconecta a cada 7 dias).
**Pendente**: a chave da API (`ANTHROPIC_API_KEY`, conferida em 25/10: ainda não está no Supabase); colar e reimplantar o Apps Script; preços para o custo; aprovação do cliente, PDF e skill do cliente; a rotina diária de ideias.
**Risco conhecido**: pastas muito grandes podem passar do tempo da função no servidor; nesse caso a tela mostra "não terminou" e dá para tentar de novo (limites de 80 arquivos e 600 mil caracteres por leitura).

## v0.150 — Ficha de produto simples; produtos e esteira no questionário
**Pedido da Rebecka (25/10)**: não criar oferta nem produto do cadastro dentro do conteúdo; só uma ficha de produto: qual produto, o valor e o histórico. Ficar só com a primeira tela (a lista), sem o formulário longo. No questionário, perguntas sobre os produtos e como a esteira funciona.
Decisões:
- Os produtos do conteúdo viram uma lista própria do Growth's Content (`content_produtos`), separada do cadastro comercial: quem só usa o módulo de conteúdo também cadastra. Se o cliente tiver produtos no cadastro comercial e nenhum aqui, a tela oferece "Trazer do cadastro" (nome e valor).
- Ficha: produto, valor e histórico (texto livre: como surgiu, turmas, resultados, o momento de agora). Ativo ou inativo.
- A ficha longa da v0.149 saiu (tabela e função removidas; não havia dado). As ideias continuam podendo ser ligadas a um produto.
- Questionário da call ganha o bloco **Produtos e esteira** (3º bloco): produtos e valores, como funciona a esteira, carro-chefe e o que quer vender mais, como a venda acontece, histórico dos produtos. Com isso, o passo da call fica pronto com 14 das 27 perguntas.
**Próximo pacote (pedido)**: botão "Fazer a pesquisa" — lê as pastas (do cliente, extras e da Mathisa), as respostas da call, os produtos e os canais, pesquisa na web e entrega um relatório para a Rebecka ler; depois, "Gerar o dossiê". Depende da chave da API da Claude e de uma atualização do Apps Script (ler os arquivos das pastas).

## v0.149 — Produtos dentro da Estratégia de conteúdo
**Pedido da Rebecka (25/10)**: dentro da estratégia de conteúdo, colocar as informações sobre os produtos, para entender cada produto e fazer conteúdo em cima dele.
Decisões:
- Nova aba **Produtos** na Estratégia de conteúdo, com os produtos do cadastro (Configurações → Produtos). O cadastro comercial (preço, ofertas) não muda; o conteúdo ganha uma **ficha de conteúdo** por produto.
- Ficha em 7 partes: o que é (frase, para quem é, para quem não é); problema e transformação (dor, o que já tentou, resultado, prazo); método e entrega (método, etapas, entregáveis, bônus, formato); diferenciais e provas (diferenciais, provas, garantia); objeções (objeção | resposta); oferta e momento de venda (momento, próxima abertura, condições, página, checkout, chamada, papel na escada, nível de consciência); para o conteúdo (temas, palavras do público, o que evitar, onde estão os materiais).
- O cartão mostra a frase, o momento de venda, quanto da ficha está preenchido (12 campos principais) e quantos conteúdos falam do produto; "Ver ficha" mostra a leitura por seções.
- Cada ideia ou pauta pode ser ligada a um produto ("Nova ideia sobre este produto" já vem com ele).
- Quem edita a ficha: quem configura o Growth's Content do cliente (Marketing com edição) ou a equipe interna. Provas: só o que é real, dizendo onde está.
**Pendente**: a rotina diária de ideias usar a ficha (falta a chave da API da Claude); filtro por produto no Kanban.

## v0.148 — Painel da produção no Kanban
**Pedido da Rebecka (25/10)**: no Kanban, um dashboard do total: quantos em cada etapa, quantos prontos para a semana, quais semanas estão completas, com um calendariozinho para visualizar. Confirmado também o entendimento das pastas: o cliente já tem as pastas dele organizadas e só acrescenta os links para a gente ler (feito na v0.147).
Decisões:
- O painel substitui os quadrinhos antigos do topo do Kanban (Ideias a avaliar, Pautas, Em produção, Publicados em 30 dias): total por etapa (as 6 colunas), clicável para ir à coluna.
- "Pronto para a semana" = pronto, agendado ou publicado com data de publicação naquela semana (segunda a domingo). Semana completa = esse número chega à meta semanal. Sem meta, mostra só os números, sem dizer "completa".
- Calendário: a semana atual e as 5 seguintes, um ponto por conteúdo com a cor da etapa; passar o mouse mostra os títulos; clicar na semana abre o planejamento dela (aba Semana).
- Segue os filtros do Kanban (tema, canal, tipo de mídia).

## v0.147 — Sem o Drive da Mathisa para o cliente; outras pastas do cliente; pastas da Mathisa
**Pedido da Rebecka (25/10)**: tirar a opção de criar no Drive da Mathisa; o cliente sempre compartilha a pasta dele e pode acrescentar várias pastas que já tem organizadas; a Mathisa coloca pastas dela, com as informações dela, que a IA também lê. Regra: nas pastas da Mathisa ficam os padrões (muda pouco); na pasta do cliente, as novidades (metodologia nova, estudo novo). Não precisa estar escrito para o cliente.
Decisões:
- "Não tenho Google Drive" sai da tela (a função deixa de poder ser chamada pela tela). Clientes antigos com pasta no Drive da Mathisa continuam funcionando.
- Passo 1: a pasta principal (onde a árvore é criada) + "Outras pastas que você já tem" (várias, compartilhadas como Leitor, com uma descrição). "Links de outros Drives" sai do passo 3, que fica com 5 tipos de material.
- Configurações → Growth's Content (interno) → Pastas da Mathisa: nome, link e "vale para" (todos os clientes ou um cliente); pausar e tirar. Só a equipe interna vê.
- Regra para a IA (vai no pedido de cada leitura, não aparece para o cliente): pastas da Mathisa = padrões, base de todos os clientes; pastas do cliente = novidades; em conflito sobre o mesmo assunto, a novidade do cliente vale para ele.
- A migração da v0.146 foi aplicada pela Rebecka no SQL Editor (a ferramenta estava sem permissão naquele momento); a da v0.147 aplicou normalmente.
**Pendente**: chave da API da Claude e a rotina diária (lendo pastas da Mathisa, pasta principal e pastas extras do cliente, canais e web); pesquisa, tese e dossiê (falta o formato das seções); conexão das outras plataformas; limites por plano.

## v0.146 — Estruturas de roteiro e copy (internas) e custos de IA só para a Rebecka
**Pedido da Rebecka (25/10)**: estruturas de roteiro e de copy para escolher; a construção é interna, o cliente só vê a opção e escolhe a que quer; os custos só aparecem para ela. Sem limite de plano por enquanto (ela vai testar e medir o gasto de tokens).
Decisões:
- Biblioteca única da Mathisa (Configurações → Growth's Content (interno) → Estruturas de roteiro e copy), editável pela equipe interna: nome e "para que serve" (o cliente vê), formatos, etapas e instruções para a IA (só a equipe vê), ativar/desativar, ordem.
- 7 estruturas iniciais: AIDA; PAS; Antes, depois e a ponte; Gancho, conteúdo e chamada (Reels); Carrossel educativo; Storytelling (jornada curta); Pelos 5 níveis de consciência. A Rebecka pode mandar as estruturas próprias (Mathisa/MIRA).
- O cliente escolhe por formato (Reels, Carrossel, Post, Stories, Vídeo longo, E-mail) na aba Estruturas e no passo 7 da configuração. Sem escolha num formato, a IA escolhe.
- Custos: tabela `ia_uso` (cada chamada de IA: tokens, buscas na web, custo em US$). Tela Custos de IA só para quem está em `custos_emails` e é da equipe interna; nem a tabela nem a função ficam abertas para mais ninguém. Câmbio informado por ela (não inventamos cotação).
- Rotina diária (próximo pacote, depende da chave da API): lê o que entrou na pasta, busca na web sobre o nicho e gera ideias pela linha editorial, persona, voz e estruturas escolhidas; cada rodada registra o custo.
**Pendente**: chave da API da Claude; rotina diária, leitura das pastas e dos canais, ideias e roteiros; tabela de preço por modelo (confirmar na página oficial antes de calcular o custo); conexão das outras plataformas; pesquisa, tese e dossiê (falta o formato das seções); limites por plano.

## v0.145 — O cliente informa os canais e entrega os materiais antes da call
**Pedido da Rebecka (25/10)**: antes da call, o cliente informa o @ de todas as plataformas onde já tem conteúdo e sobe os materiais (documentos, identidade visual, reuniões gravadas, aulas, inclusive de plataforma de venda), indo de tela em tela e dando ok em cada um; cada tipo com a sua pastinha na árvore; poder informar o link de outro Drive (mas a recomendação é subir na pasta). Ao concluir a rotina, a primeira leitura e as primeiras ideias. Sem limite de plano por enquanto: ela vai testar na conta dela e medir o gasto de tokens.
Decisões:
- Ordem: 1 Google Drive; 2 Seus canais (cliente); 3 Seus materiais (cliente); 4 Call de briefing; 5 Pesquisa e tese e 6 Dossiê e aprovação (em construção); 7 Linha editorial; 8 Onde publicar; 9 Rotina.
- Canais: Instagram, YouTube, TikTok, LinkedIn, Threads, Facebook, Site ou blog, Podcast, Outro; ou "Ainda não tenho conteúdo publicado". O @ vira o link do perfil.
- Materiais: Documentos, Identidade visual, Reuniões gravadas, Aulas e cursos, Depoimentos e provas, Links de outros Drives — cada um "Pronto" ou "Não tenho"; com os 6 resolvidos, o passo fica pronto sozinho.
- Identidade visual continua na raiz (03) para não duplicar pastas já criadas; as outras subpastas entram em "02 Materiais do cliente".
- Ler só pelo @, sem conectar a conta, seria raspagem (paga e contra os termos de algumas redes): não fazemos. A leitura dos posts vem da conta conectada (Instagram já; YouTube, TikTok, LinkedIn e Threads pelo Zernio no próximo pacote, a confirmar plataforma por plataforma).
- A IA não assiste vídeo: lê a transcrição. Pedimos a transcrição quando existir; o resto vai precisar de um serviço de transcrição (pago por minuto).
**Pendente (próximo pacote)**: leitura das pastas e dos canais; primeiras ideias ao concluir a rotina; registro de tokens gastos por leitura; conexão das outras plataformas; depois pesquisa, tese e dossiê (falta o formato das seções); limites por plano.

## v0.144 — Pasta compartilhada pelo cliente; configuração em 8 passos
**Pedido da Rebecka (25/10)**: não pagar Google Cloud; seguir o caminho recomendado ("a gente vai usar o recomendado. E já!"); o roteiro da call de briefing dentro do sistema; depois, a IA lê transcrição e materiais, faz pesquisa e tese, gera o dossiê para o cliente aprovar e, aprovado, vira o padrão editável e a skill do cliente.
Decisões:
- Passo 1 recomendado: o cliente cria uma pasta no Drive dele e **compartilha com rebecka@rebeckacappello.com.br como Editor**; cola o link no Growths e o Apps Script cria a árvore dentro dela. É gratuito e, ao contrário do login com escopo `drive.file`, o Growths enxerga tudo o que o cliente puser na pasta (necessário para a IA ler os materiais). "Não tenho Google Drive" continua (pasta no Drive da Mathisa). O login com o Google (`content-google`, v0.143) fica publicado, mas escondido.
- Árvore padrão: 01 Briefing, 02 Materiais do cliente, 03 Identidade visual, 04 Referências de conteúdo, 05 Pesquisa de mercado, 06 Dossiê da marca, 07 Skill do cliente, 08 Produção (Roteiros, Gravações, Edição, Artes), 09 Publicados, 10 Resultados.
- 8 passos: 1 Google Drive; 2 Call de briefing (roteiro na tela, uma parte por vez, salva sozinho); 3 Materiais do cliente (lista do que pedir e "Material pronto, pode ler"); 4 Pesquisa e tese e 5 Dossiê e aprovação (em construção, não travam a conclusão); 6 Linha editorial (com proposta pela IA para colar); 7 Canais; 8 Rotina.
- IA: pela API da Claude (não pelo plano Pro/Max, que proíbe uso automatizado e revenda); cada cliente separado pelo `workspace_id`; dossiê guardado no banco e injetado a cada pedido; skills pela API depois.
- Vídeo e arte: ferramentas pagas (ex.: Rig Studio) entram por faixa de plano; começar pelo básico (cortar pausas).
**Pendente**: passos 4 e 5 (IA lendo a pasta pelo Apps Script, pesquisa, tese, dossiê em PDF, aprovação, skill do cliente) — falta a Rebecka mandar o formato das seções do dossiê; custos por faixa de plano; Instagram ainda ligado à mão (Zernio).

## v0.143 — Configuração passo a passo; Google Drive do cliente
**Pedido da Rebecka (25/10)**: a pasta deve ficar no Drive do cliente (conectando a conta Google dele); sem Drive, criar as pastas do nosso lado. A configuração é a primeira tela: sem configuração, nada do módulo aparece; ela segue tela a tela e, preenchida, abre o que existe hoje. Tirar a configuração da Mathisa para testar do zero; primeiro passo "Conectar meu Google".
Decisões:
- Configuração da Mathisa — Operação removida em 25/10/2026 (4 territórios, 24 frentes, 9 formatos, 3 metas, configuração), com cópia completa em `conteudo_backups` (dá para restaurar). Posts e DMs do Instagram ficaram.
- 5 passos, reaproveitando as telas existentes: 1 Google Drive; 2 Briefing e persona (questionário; pronto com metade das perguntas respondidas); 3 Linha editorial e formatos (pronto com território, frente e formato); 4 Canais; 5 Rotina da semana (conteúdos por semana, dia da curadoria — sexta por padrão —, quem publica). "Concluir" só com os 5 prontos e a pasta criada.
- Google: login OAuth com escopo `drive.file` (o Growths só enxerga o que ele mesmo criou no Drive do cliente); o token fica só no servidor (`content_google`). Pasta "Growth's Content — <cliente>" na raiz do Drive dele + árvore. "Completar as pastas", "Trocar de conta", "Desconectar".
- Sem Drive: Apps Script da Mathisa (v0.140), na pasta "Mathisa Growth's Content".
- Marcar o Growth's Content no acesso não cria mais a pasta sozinho: ela nasce no passo 1.
- Quem configura: quem edita o Marketing do cliente ou a equipe interna.
**Pendente**: Google Cloud da Mathisa (projeto, Drive API, tela de consentimento com usuários de teste, ID do cliente OAuth) e os segredos `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`; verificação do app no Google antes de vender (até lá, aviso "app não verificado" e só usuários de teste); árvore de subpastas; Instagram ainda é ligado à mão (Zernio).


## v0.142 — Correção: cliente do Growth's Content criado como Growth Starter
**Relato da Rebecka (25/10)**: o cliente de teste liberou outras coisas e não a parte do marketing.
**Causa (fato, conferido no banco)**: o cliente "Teste Growth's Content" foi criado às 12h04 na tela antiga (v0.140), em que "Growth Starter" era o tipo de acesso marcado por padrão; o Growth Starter tem menu próprio (diagnóstico e relatórios) e não mostra o Marketing. A pasta no Drive foi criada certa.
Decisões:
- Cliente corrigido em produção: Growths completo, acesso só ao Growth's Content (Estratégia de conteúdo e Instagram, mais Equipe e Funções).
- Novo cliente: "Growths completo" vem primeiro (já na v0.141); marcar o Growth's Content (ou o atalho "Só Growth's Content") troca para completo; com Growth Starter escolhido, aviso na tela; ao gravar, cliente com Growth's Content é sempre completo.


## v0.141 — Acesso do cliente em árvore; Growth's Content pelo acesso
**Pedido da Rebecka (25/10)**: no cadastro do cliente, em vez de escolher numa lista, abrir a setinha e marcar o que a pessoa acessa, dentro do que já existe (sem mais uma opção solta); marcar Growth's Content libera só a parte de marketing.
**Fato (25/10)**: o primeiro cliente de teste ("Teste Growth's Content") foi criado pela tela e a pasta dele saiu no Drive (v0.140 funcionando de ponta a ponta).
Decisões:
- Catálogo de telas: Growth's Content é um subgrupo de Marketing (Estratégia de conteúdo e Instagram); DMs do Instagram entram em Vendas. Antes o Instagram e as DMs não existiam no catálogo.
- Gravação do acesso: tudo marcado = sem restrição; igual a um pacote = aquele pacote; senão, telas ligadas e todas as outras desligadas (inclusive as abas internas, como Cohorts e Unit Economics, que antes ficavam liberadas sem querer).
- O cliente usa o Growth's Content quando o acesso restrito dele inclui o módulo (por árvore, pacote ou "Ajustar telas"); tirar do acesso desliga (a pasta fica). Cliente sem restrição não muda sozinho. Na tela de Pacotes, só a equipe interna tem a caixa manual.
- Cliente criado só com o Growth's Content abre direto no módulo.
- Equipe e acessos e Funções e permissões continuam sempre liberadas para o administrador do cliente.
**Pendente**: árvore de subpastas; telas de configuração passo a passo do Growth's Content.


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
