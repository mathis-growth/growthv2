## v0.244 — Aviso de lead novo e "Gerar novo link"
**Pedido da Rebecka (02/11):** "gerar novo link nas pesquisas para pegar o link novo do Growths… o alerta quando entrar um lead novo, um aviso em verdinho no topo do Growths e uma mensagem no WhatsApp… acho que o Rogério já configurou".
**Decisões dela:** as duas opções de link; o aviso vai para todos da equipe, de todos os leads; o WhatsApp sai pelo número da empresa.
**O que encontrei (fato):** os avisos por WhatsApp e e-mail do Growths falhavam por falta de configuração (WHATSAPP_TOKEN/WHATSAPP_PHONE_ID e Resend). O Rogério conectou no Atendimento o WhatsApp da empresa pela Zernio ("Mathisa Anúncios online e Automação") e o dele pela Evolution; as mensagens automáticas dele são para os leads, não para a equipe.
**Como ficou:** a função de avisos usa a API oficial da Meta se estiver configurada; senão, a conta WhatsApp da empresa na Zernio, com o modelo aprovado `aviso_growths`. Sem o modelo aprovado, o aviso fica como "falhou" com o motivo em Avisos.
**Pendentes:** publicar a função `avisos` (mudança em produção: precisa do ok dela) e aprovar o modelo na Meta; preencher o WhatsApp dela em Equipe e ligar "Avisar por WhatsApp" (hoje está desligado e sem telefone). Combinar com o Rogério, porque usa a conta do Atendimento.

## v0.243 — Celular
**Pedido da Rebecka (02/11):** "não quero ter que descer lá para baixo para ver as coisas; a telinha tem que ir abrindo ali mesmo, uma por cima da outra". Ela aprovou a proposta: sanfona, Kanban por etapa em abas, janelas em tela cheia com Voltar.
**Como ficou:** vale para todas as telas, sem mexer em cada uma: abaixo de 760 px de largura, os blocos com título viram sanfona (só quando há dois ou mais lado a lado), todo Kanban ganha as abas de etapa e toda janela abre em tela cheia.
**A observar:** telas com um bloco só não mudam; blocos sem título continuam sempre abertos.

## v0.242 — Plano da Máquina de conteúdo (decisões de 02/11)
**Decisões da Rebecka:**
- Ordem: 1) arrastar no Kanban; 2) questionário da Máquina com microfone e anexos; 3) botão "Iniciar a montar a minha máquina de conteúdo", que cria no Drive a pasta **Máquina de conteúdo** com **Referências, Identidade visual, Persona e Tom de voz**; 4) **Gerar roteiro** na pauta aprovada, escolhendo o tipo de roteiro.
- IA: usar a que estiver conectada em Configurações (Claude ou GPT), com um limite de uso que ela escolhe.
- Os arquivos ficam com uma cópia no Growths para a IA consultar (não lê o Drive a cada vez).
- "Skill do cliente": um documento consolidado (dossiê, persona, tom de voz, referências) guardado no sistema, que a IA usa sem procurar. Já existe o passo "Dossiê e aprovação: dossiê, PDF e a skill do cliente" (em breve) na configuração guiada.
- O botão vale para todos os clientes do Growth's Content; cada um cria no Drive dele (a Mathisa no da Mathisa).
- "Mover para": tirar no computador, manter no celular. **Feito na v0.242.**
**Pendente de entendimento:** melhorar o celular ("não quero ter que descer para ver as coisas; a tela vai abrindo ali mesmo, uma por cima da outra").

## v0.241 — Kanban antes do calendário
**Pedido da Rebecka (02/11):** "só uma aba escrito Baú de ideias, fica ok… quero mudar o Kanban de lugar: embaixo da contabilização, antes do calendário, para ficar mais fácil visualizar o que está acontecendo".
**Feito:** contagem por etapa → Kanban → Esta semana e calendário. O Baú de ideias não mudou.

## v0.240 — Baú de ideias com microfone
**Pedido da Rebecka (02/11):** "no Content, o baú de ideias, e um lugar com um microfonezinho para eu falar a minha ideia e ele salvar como ideia, uma pauta que tem que ser aprovada".
**Como ficou:** a transcrição é feita pelo próprio navegador (Chrome, Edge e Safari recentes), sem custo e sem mandar o áudio para o Growths; o áudio não é guardado, só o texto. A ideia entra como "ideia" (esperando aprovação) e segue o caminho de sempre: aprovar pede tema, formato e data.
**Limite (fato):** em navegadores sem transcrição, o microfone não aparece; dá para ditar pelo teclado do celular. Precisa de internet e da permissão do microfone.
**Próximo passo possível:** a ideia falada pelo ChatGPT do celular (botão que já existe) e a falada aqui caem no mesmo baú.

## v0.239 — Diagnóstico dos dados
**Pedido da Rebecka (02/11):** "antes de importar para o cliente, pegar os campos e cruzar com as tabelas que a gente tem… um relatório mostrando quais informações tem no arquivo, o que você identificou e o que não identificou de acordo com a estrutura do banco, relacionado a métricas e dados… para a reunião, um 'gerar diagnóstico dos dados'".
**Como ficou:** usa o mesmo reconhecimento do importador (tipo do arquivo e de-para das colunas) e o de-para das métricas (v0.225). Nada é gravado: o relatório é gerado na hora, fica na tela até sair do diagnóstico, e pode ser impresso ou salvo em PDF.
**Limites (fato):** lê a primeira aba de cada Excel; PDF e Word ainda não; as métricas dependem de "Ler as planilhas".
**Pendente:** guardar o relatório no diagnóstico (histórico de versões), se ela quiser.

## v0.238 — Importar os dados do diagnóstico
**Pedido da Rebecka (02/11):** "Dados tem que vir depois do que falta… eu passo os dados, valido as informações, e o que der para importar tem que ter um botãozinho de importar para já ir para o banco de dados… abre os dois, compara o que é o que, e a gente já importa".
**Decisões:**
- Dados passa a ser a aba 4, logo depois de "O que falta".
- **Para onde vão os dados (decisão minha, a confirmar):** para o Growths do cliente, nunca para o da Mathisa. Vem sugerido o Growths criado pelo contrato; sem Growths de cliente, a aba avisa para criar pelo contrato.
- O "Importar" usa o mesmo importador de "Importar e validar dados" (identifica o tipo, de-para com exemplos, não duplica por e-mail ou telefone), já aberto no arquivo, no Growths do cliente.
**Pendente:** registrar no diagnóstico o que foi importado (hoje fica só no Growths do cliente).

## v0.237 — O cliente não tinha onde anexar os arquivos
**Relato da Rebecka (02/11):** "o diagnóstico continua sem ter como colocar um arquivo… quando ele fala 'tenho', tem que ter um lugar onde ele anexa e esses arquivos chegam para mim".
**Causa (fato):** em produção, a pergunta 17 do "Diagnóstico Mathisa" estava só com o aviso e grupos g1…g9: sem `upload`, sem `onde`, sem período e sem planilhas-modelo. É o que o editor de perguntas grava quando alguém salva a pergunta: ele montava a configuração do zero com o que mostra.
**Correção:** o editor parte da configuração que já existe e troca só o que mostra; os grupos mantêm chave, plataforma e planilha-modelo quando o nome não muda; nova caixa "o cliente anexa os arquivos". O RODAR devolve a configuração do modelo, ligada ao "Onde vende?" do formulário.
**Marco:** o formulário dele já está respondido. Pelo mesmo link ele consegue mandar só os arquivos; para mudar respostas, use "Reabrir para o cliente continuar". Os arquivos chegam em Evidências no diagnóstico.

## v0.236 — Link do cliente no diagnóstico e reabrir o formulário
**Pedido da Rebecka (02/11):** "esse link tem que aparecer lá no diagnóstico… se o cliente perder, conseguir enviar de novo e ele conseguir continuar".
**O que estava acontecendo:** o formulário do Marco foi enviado às 14h15 (resposta de teste: "Mathisa", "teste"). Depois de respondido, a aba Formulário escondia o link.
**Decisões:**
- O link fica sempre na aba, com WhatsApp, e-mail e copiar. É sempre o mesmo link.
- Respondido, o mesmo link ainda serve para mandar os arquivos que faltam.
- "Reabrir para o cliente continuar" volta o link a aceitar respostas, com o rascunho guardado, e garante pelo menos 30 dias de prazo. A resposta anterior continua valendo até chegar a nova; a nova substitui e fica registrado "O cliente enviou o formulário de novo".

## v0.235 — Embed: o site bloqueava o formulário dentro de outra página
**Achado ao investigar o relato dos consentimentos:** o `_headers` do Cloudflare Pages manda `X-Frame-Options: DENY` para o site todo. Isso protege o login contra páginas que imitam o Growths, mas impede qualquer embed: o código da v0.234 e o da página de obrigado (v0.193) mostrariam um quadro vazio.
**Decisão:** liberar só o endereço `/formulario` (mesmo Growths, via `_redirects`), sem o `X-Frame-Options` e com `frame-ancestors *`. O código de embed aponta para ele. Sem `?pesquisa=`, `/formulario` volta para `/`, para o login não ficar exposto dentro de outra página.
**A validar na publicação:** que o Cloudflare aplica o `! X-Frame-Options` em `/formulario` (testado só com servidor local).

**Relato da Rebecka (02/11):** "essa informação [o consentimento do investimento mínimo] é apenas no final; deu esse erro mas depois passou para a próxima página".
**O que conferi:** no código atual, os consentimentos ficam só no último passo (Alinhamento) e a mensagem é "Marque para continuar: …". A mensagem da imagem ("Marque: …") não existe em nenhuma versão do Growths no repositório. Refiz o caminho com o formulário igual ao de produção e o aviso não aparece antes do final. A resposta dela das 16h11 foi gravada certa (Strategy, quente, 71 pontos). **Pendente:** saber em qual endereço ela abriu o formulário, para achar a versão que mostrou "Marque:".

## v0.234 — Código (embed) do formulário em Pesquisas
**Relato da Rebecka (02/11):** "nas pesquisas tinha um HTML para embedar nas páginas, e agora não está gerando mais".
**O que achei:** o código com iframe existia só na campanha (Pesquisa da campanha → página de obrigado, v0.193). Em Pesquisas havia só o link. E o "Lead: qualificação" da Mathisa está, em produção, sem o link aberto e sem a captação ligados, então nem o link aparecia. O RODAR_v0.233b liga os dois.
**Feito:** o código para colocar na página agora fica também em Formulário e aparência, junto do link, com a UTM. A tela diz o que falta quando o link não aparece. Uma captação gravada sem algum campo deixava a aba em branco: corrigido.
**Atenção:** o site onde o Growths está publicado precisa permitir ser aberto dentro de outra página (iframe). Testar na página real.

## v0.233 — Qualificação do lead por produto
**Pedido da Rebecka (02/11):** "trazer a pontuação lá na qualificação, para entender qual produto essa pessoa é mais elegível e criar as tags: esse é o Starter, esse é o Strategy, esse é o Full Brain (implementação)".

**Decisões dela (02/11):**
- O formulário é o **"Lead: qualificação"** da Mathisa, não o "Captação: diagnóstico inicial de crescimento". As perguntas desse outro entram no Lead (achei a cópia na Escola Aurora; o da Mathisa tinha sido excluído).
- Sai a pergunta "Você possui uma estratégia de crescimento estruturada?"; fica "Como você vende hoje?".
- **Faturamento até R$ 10 mil fica de fora**, assim como "Ainda não vendo": não qualificado, tag "qualif: nutrir".
- Aviso de investimento mínimo de R$ 3.500 e mensagem final com contato pelo WhatsApp em até 1 dia útil.

**A regra (pode ser ajustada na tela, em Qualificação e pontos):**
- **Pontos de 0 a 100:** Porte até 50 (faturamento, ticket, produtos, anúncios); Estrutura até 30 (tempo vendendo, como vende, como acompanha, equipe); Momento até 20 (quando começar).
- **Produto:** Full Brain = Porte ≥ 32 e Estrutura ≥ 15; Strategy = Porte ≥ 18; Starter = o resto.
- **Temperatura:** quente = Momento ≥ 15 e total ≥ 50; morno = total ≥ 30; frio = o resto.
- **Pedido × indicado:** "Que tipo de ajuda você procura" põe "pediu: …". Se não bater com o produto, entra "qualif: revisar", para conversar na reunião.

**Hipótese a validar:** os pesos e os cortes são ponto de partida. Revisar depois dos primeiros leads, com o simulador.
**Não mexi:** o formulário continua com o gatilho "ao cadastrar" (manda o link para todo lead novo do CRM). Para um formulário que fica na página, o normal seria "manual"; fica para ela decidir.

## v0.232 — Correção: o link do formulário do diagnóstico não era gerado
**Relato da Rebecka (02/11):** "abro o diagnóstico e escolho o formulário, tenho ali 'tornar este o padrão', mas não consigo iniciar para gerar o link e mandar para o cliente".

**O que acontecia:** escolher o formulário chamava `diagnostico_formulario`, que dava erro no banco ("there is no unique or exclusion constraint matching the ON CONFLICT specification"). A função foi escrita para a trava antiga de envios (pesquisa, pessoa); em produção, desde os check-ins (v0.163), a trava é (pesquisa, pessoa, ciclo). O banco de teste local não tinha essa migração, por isso os testes não pegaram.
**Correção:** a função passa a funcionar com qualquer trava; o banco de teste foi atualizado para ficar igual à produção. Confirmado em produção numa simulação desfeita (sem gravar nada), no diagnóstico "Diagnóstico de Marco".
**Tela:** o formulário padrão já vem escolhido e há um botão claro, "Gerar o link do formulário". Antes o link era gerado só ao trocar a opção da lista, o que não era evidente.
**Atenção:** o Marco não tem e-mail nem WhatsApp no cadastro. Dá para copiar o link, ou completar o cadastro para enviar direto.

## v0.231 — Clientes: o Growths nasce do contrato; inativar, reativar e excluir
**Pedido da Rebecka (02/11):** "inativar e desativar clientes para não aparecer no workspace. E excluir. Acabei de criar um ali que ele não está aparecendo, porque ele não tem contrato… quando ele assinar o contrato, já automaticamente criar esse workspace ali com os dados do contrato da empresa".

**Decisões dela (02/11):**
- **Inativar:** some da lista de todos e bloqueia o acesso; os dados ficam e dá para reativar.
- **Excluir:** só depois de inativar, digitando o nome; sem volta.
- **Criar sozinho:** só para alguns produtos (cada produto diz se inclui o Growths).
- **Dados do contrato:** nome da empresa; CNPJ e razão social; responsável e e-mail de acesso; pacote de acesso.

**Como ficou:**
- "Assinar" = **Ativar o contrato**. A assinatura eletrônica não está integrada; quando estiver, a criação acontece no mesmo ponto.
- Só contratos da Mathisa (workspace de agência) criam Growths.
- Se der erro na criação, o contrato é ativado mesmo assim e mostra o erro com o botão "Tentar de novo".
- A equipe interna continua vendo o cliente inativo (em Pacotes de acesso), para poder reativar ou excluir. Ele não aparece no seletor de ninguém.
- Excluir apaga o workspace e tudo o que está nele. O contrato e o cadastro na Mathisa ficam.

**Sobre o cliente criado à mão (pelo "+ Novo cliente"):** ele não tem pessoa nem contrato na Mathisa, por isso não aparece no diagnóstico. Caminho: cadastrar o cliente na Mathisa e fazer o contrato. Se o contrato for criar um Growths novo, inative e exclua o criado à mão. **Pendente:** ligar um Growths que já existe a um contrato (não foi feito).



## v0.230 — Formulário para clientes (não entra no Funil de leads)
**Pedido da Rebecka (02/11):** "tenho que ter um botão onde este formulário capta as informações e atualiza o CRM dos clientes; ele já é cliente, não entra no funil de leads, entra no funil de clientes na etapa de diagnóstico".

**Decisões:**
- **Novo bloco em Pesquisas → Formulário e aparência: "Quem responde este formulário".**
  - **Um lead:** como sempre, entra no Funil de leads ou é atualizado.
  - **Um cliente:** atualiza o cadastro dele e a etapa na jornada do cliente, e não entra no Funil de leads. Pede a **etapa do cliente depois que ele responder** (por exemplo, Diagnóstico); vazio = não muda a etapa.
- **Vale para os dois links:** o individual de cada cliente e o aberto.
  - **Link aberto, contato que não existe:** é criado fora do Funil de leads, com a marca "cliente sem cadastro".
- **Quando um cliente responde:**
  - as matrículas ativas dele vão para a etapa escolhida, só dentro da mesma jornada. O histórico do aluno registra a mudança;
  - o histórico do cliente registra o formulário e a etapa;
  - se não houver matrícula, só fica registrado ("sem matrícula: a etapa não mudou").
- O formulário público não mostra a etapa.
- O modelo **"Diagnóstico Mathisa (pré-diagnóstico)"** já nasce marcado "para clientes"; falta só escolher a etapa.
- **Aviso no diagnóstico:** a aba Formulário avisa quando o formulário escolhido não está marcado "para clientes".

**Depende de:** ter a jornada do cliente com a etapa "Diagnóstico" cadastrada em Customer Success. Hoje não há nenhuma em produção.

## v0.229 — "O que já se sabe" e excluir pergunta na lista
**Pedidos da Rebecka (02/11):**
- Seguir para a próxima etapa ("O que já se sabe").
- "Tem a opção de eu excluir uma pergunta, não só editar".

**Decisões:**
- **Aba "4. O que já se sabe":** tudo o que se sabe do cliente, com a origem de cada informação.
  - **Do formulário:** o que ele declarou, por assunto (negócio, números, como os clientes chegam e compram, o que espera).
  - **Das planilhas:** o que a auditoria calculou (vendas válidas, faturamento, média por mês, ticket médio, compradores, produtos, leads e origem, investimento), com o arquivo de origem.
  - **Da reunião:** o que a equipe anotou no roteiro.
- **"As fontes batem?":** compara o que o cliente declarou com o que as planilhas mostram.
  - Compara faturamento médio por mês (nos mesmos meses, quando o cliente informou mês a mês), ticket médio e investimento em anúncios por mês.
  - Diferença de até 20% = batem. Acima disso, **o Growths não escolhe uma fonte sozinho**: a equipe decide entre "Vale o do cliente", "Vale o da planilha", "Corrigir" (com o valor certo) ou "Levar para a reunião".
  - O que vai para a reunião entra na pauta da aba "Preparar a reunião", com os dois valores.
- **Revisão de cada informação:** Confirmar, Corrigir (com o valor certo e uma observação) ou Rejeitar; "Desfazer" volta atrás.
  - Fica guardada a revisão (`diagnostico_saber_revisoes`), não a lista: a lista se monta das fontes e está sempre atualizada.
  - Spec §7, simplificada: os estados são declarado, calculado e anotado, mais confirmado, corrigido, rejeitado e levar para a reunião.
- **Auditoria das planilhas, versão 2:** soma por mês só das vendas aprovadas (sem as linhas repetidas e sem datas no futuro) e do investimento. As planilhas já conferidas são conferidas de novo sozinhas.
- **A conferência em segundo plano não apaga o que está sendo digitado:** se a pessoa estiver num campo, a tela só atualiza quando ela sai dele.
- **Pesquisas, excluir pergunta direto na lista:** o botão "Excluir" fica ao lado de "Editar". O primeiro toque avisa quantas respostas serão apagadas e quais perguntas dependiam dela; o segundo confirma. As perguntas que só apareciam conforme a excluída passam a aparecer sempre.
- **Correção:** apagar um diagnóstico com arquivos da equipe dava erro. O registro do arquivo continua, sem diagnóstico.
- O diagnóstico agora tem **nove abas**.

## v0.228 — O diagnóstico começa pelo cliente e pelo formulário (só da Mathisa)
**Pedido da Rebecka (02/11):**
- A primeira etapa é o formulário, não as evidências.
- Não pode ficar confuso qual formulário mandar.
- O diagnóstico registra qual formulário o cliente recebeu.
- O cliente é cadastrado depois do contrato e cai na etapa Diagnóstico da jornada.
- O envio é por e-mail, por WhatsApp ou copiando o link.

**Respostas dela:**
- **Formulário:** "precisamos montar um que seja suficiente para o pré-diagnóstico, inclusive para ele enviar os arquivos".
- **Dono:** o diagnóstico é do cliente da Mathisa.
- **Jornada:** depende do produto (Starter e Strategy são consultoria; na implementação, o diagnóstico é a primeira etapa). Na Mathisa, usar a mesma jornada do cliente.
- **Escopo:** "a tela de diagnóstico e todo esse processo é só nosso".

**Decisões:**
- **Só a Mathisa:** a tela vira "Diagnóstico de clientes" e só aparece no workspace de agência (Mathisa — Operação). Nas outras empresas, Growth → Diagnóstico Growth continua sendo a leitura de planilhas que monta o Growth Model.
- **O dono é o cliente,** e isto substitui a decisão de manhã ("da empresa"). O diagnóstico guarda o cliente, o contrato e a matrícula.
- **Clientes esperando diagnóstico:** entram quem está numa etapa da jornada com "Diagnóstico" no nome e quem tem contrato ativo sem diagnóstico aberto. A jornada de cada produto é cadastrada pela Rebecka em Customer Success. Hoje não existe nenhuma jornada em produção.
- **Começar diagnóstico:** escolhe o cliente (ou acha pelo e-mail), o formulário (o padrão já vem escolhido), o responsável e o período. Cliente com diagnóstico aberto abre o que já existe.
- **Etapa 1, Formulário:**
  - escolhido, enviado, cliente preenchendo e respondido, com data;
  - mensagem pronta com o link individual;
  - "Enviar por WhatsApp" e "Enviar por e-mail" abrem no aparelho com a mensagem; "Copiar o link";
  - cada envio fica no histórico;
  - dá para trocar o formulário até o cliente responder.
  - Quando o cliente responde, a resposta entra sozinha. Os arquivos que ele manda pelo link entram nas evidências antes mesmo de ele concluir.
- **Formulário padrão:** um por empresa ("Tornar este o padrão").
- **Modelo novo, "Diagnóstico Mathisa (pré-diagnóstico)":**
  - o perfil e os números do jeito do cliente (do modelo Entrada);
  - o que acompanha, onde vê e quais são as principais (até 5);
  - o que espera e em quanto tempo;
  - os arquivos por plataforma de venda, com planilha-modelo.

  Os arquivos não têm "Mando depois": cada grupo precisa de arquivo ou "Não tenho". O formulário salva sozinho.
- **As abas passaram a ser oito:**
  1. Formulário;
  2. Evidências;
  3. O que falta;
  4. Métricas;
  5. Dados;
  6. Preparar a reunião;
  7. Arquitetura;
  8. Validação e entrega.
- **O progresso** ganhou "Formulário enviado" e "Formulário respondido" (9 etapas).

**Decisão da Rebecka (02/11, 11h21):** validar o diagnóstico **não** move o cliente para a etapa seguinte da jornada. Ela quer validar o processo primeiro; a equipe move à mão. Reavaliar depois da validação.

**Limites:** o envio automático por e-mail ou WhatsApp, sem abrir o aparelho, depende do Resend e da API do WhatsApp configurados para mensagens a clientes. Hoje eles só enviam avisos para a equipe.

## v0.227 — Auditoria automática das planilhas (D4)
**Pedido:** a etapa D4 do Diagnóstico Inteligente. A especificação chama esta parte de prioritária ("auditoria inteligente de planilhas"). A Rebecka disse "sim" à próxima etapa em 02/11.

**Decisões:**
- **Conferência automática.** Ao abrir o diagnóstico, cada planilha das evidências que ainda não foi conferida é lida na própria tela, uma vez por sessão. O arquivo original não muda. O resultado fica guardado no arquivo (`pesquisa_arquivos.auditoria`).
- **O que a conferência mostra, por aba:**
  - o tipo (vendas, leads, investimento em anúncios ou "não usar");
  - a linha do cabeçalho;
  - cada coluna com o que ela é (sugerido; a equipe troca), o tipo de dado e quanto está preenchida;
  - três exemplos.
- **Alertas que ela gera:**
  - linhas repetidas;
  - datas que não dá para ler, datas no futuro ou fora do período do diagnóstico;
  - meses sem nenhuma linha;
  - valores que não são número, negativos ou zerados;
  - coluna de data ou de valor que não foi encontrada;
  - menos da metade das vendas com identificação do comprador;
  - leads sem origem.
- **Qualidade:** boa, com alertas, ou precisa de ajuste (data ou valor ausente, ou mais de 5% das datas ilegíveis).
- **Cobertura:** linhas por mês, produtos, canais e status, com os mais frequentes.
- **Dados pessoais:** e-mails, CPFs, telefones e nomes nunca ficam guardados nem aparecem nos exemplos; são trocados por •••. É a minimização de dados pedida na especificação.
- **Sinais para o de-para:**
  - identificação do comprador;
  - produto;
  - status;
  - origem das vendas;
  - recompra (compradores com mais de uma compra);
  - origem dos leads;
  - qualificação;
  - investimento;
  - topo do funil.

  Quando há leitura consolidada, vale o melhor sinal de cada fonte. Item que a leitura não cobriu fica como "confirmar".
- **O que a conferência preenche sozinha:**
  - o período do arquivo, quando não foi informado;
  - a classificação, quando não existe (marcada como sugerida).

  Uma planilha de leads da equipe passa a contar como "CRM e leads" no checklist.
- **Troca manual:** a equipe muda o tipo de uma aba ou o que é uma coluna, e o Growths confere de novo. A escolha manual fica guardada e não é desfeita ao conferir de novo.
- **Arquivo que não abre:** fica com "Não consegui ler" e o motivo, e com o botão "Conferir agora".
- **A leitura consolidada de antes continua** na mesma aba, para o Growth Model e para separar venda nova, renovação e upgrade.
- **Correção:** marcar a planilha como lida ao guardar a leitura consolidada (v0.223) falhava em silêncio. Corrigido.

## v0.226 — O diagnóstico em sete abas, na ordem do trabalho
**Pedido da Rebecka (02/11):** "muito grandes; dá para dividir em mais etapas para ficarem uma do lado da outra e não ficar tão extenso". Ela também perguntou onde fica o diagnóstico.

**Onde fica:** em Growth → Diagnóstico Growth, como antes. A tela abre na lista, e cada diagnóstico abre nas abas dele.

**Decisões:**
- A Investigação virou três abas. O diagnóstico ficou com sete, numeradas porque seguem a ordem do trabalho:
  1. Evidências;
  2. O que falta (checklist);
  3. Métricas (de-para);
  4. Dados (leitura das planilhas);
  5. Preparar a reunião (pedido ao cliente, pauta, revisado, ir para a reunião);
  6. Arquitetura;
  7. Validação e entrega.
- **O de-para tem três abas próprias:** Usa hoje, Dá para calcular e não olha, Não dá com o que veio. Cada uma mostra a contagem.
- **Números nas abas:**
  - O que falta: itens pendentes;
  - Métricas: métricas usadas sem o cálculo entendido;
  - Dados: planilhas não lidas;
  - Validação: decisões registradas.
- O bloco "O que os dados mostram" saiu da Investigação, porque repetia a aba Dados. Quem tinha a aba "Investigação" guardada na sessão abre em "O que falta".

## v0.225 — De-para das métricas e formulário que só conclui com os arquivos resolvidos
**Pedidos da Rebecka (02/11):**
- "O cliente deve receber o checklist do que falta e só concluir quando estiver tudo ok, e pode salvar para continuar depois."
- "Não vou mostrar isso no link para o cliente: vou analisar e apresentar na reunião."
- "Ver todas as métricas que a pessoa usa, o que olha, o que não olha, quais dados tem ou não tem, e fazer o de-para."
- "No diagnóstico, ela tem que responder quais são as métricas principais."
- "Das que usa, entender como calcula; das que não usa, se os dados da planilha permitem calcular novas métricas."

**Decisões:**
- **Formulário do cliente (link do diagnóstico):**
  - sai o "Mando depois";
  - cada grupo de arquivos precisa de arquivo enviado ou "Não tenho" para concluir;
  - embaixo dos grupos, a lista "Ainda falta: …" se atualiza sozinha e vira "Tudo certo, já pode concluir";
  - o que o cliente preenche fica salvo, e ele volta pelo mesmo link.
- **O pré-diagnóstico continua só para a equipe.** O cliente não vê a análise.
- **Métricas principais:**
  - no formulário curto, cada número que o cliente acompanha ganha "É um dos principais: uso para tomar decisões" (até 5);
  - no modelo "Entrada do cliente" entra a pergunta "Desses, quais são os principais…".
  - Formulários já criados a partir do modelo "Entrada do cliente" não ganham a pergunta sozinhos; os que usam a pergunta de métricas (formulário curto) já mostram o campo.
- **De-para das métricas,** na aba Investigação: as 53 métricas do catálogo em três blocos.
  - **O que usa hoje:** principal ou acompanha, onde vê, se o cálculo já foi descrito na reunião (senão, "perguntar na reunião") e se os dados que mandou permitem conferir.
  - **Dá para calcular e hoje não olha:** dá, ou dá com ressalvas (com o porquê).
  - **Não dá para calcular com o que veio:** o que falta, ou se a fonte nem vem em arquivo (área de membros, NPS, redes).
  - Antes da leitura das planilhas, "dá para calcular" considera o tipo de arquivo e pede para confirmar as colunas. Depois da leitura, usa o que a leitura achou (identificação do comprador, origem, status, recorrência).
- O que cada métrica precisa ficou no catálogo (`metricas_definicoes.requisitos`), para valer igual no Diagnóstico, no Planejamento e nos Cockpits.
- **"Para conversar na reunião"** ganhou três tipos de item: "Como vocês calculam X?" (primeiro as principais), "Usa X, mas não mandou o dado" e a lista do que dá para calcular e hoje não olha.

**Pendências:**
- Rebecka: rodar os RODAR na ordem.
- Recriar ou editar o formulário de entrada, se quiser a pergunta das principais nos formulários antigos.

## v0.224 — Pré-diagnóstico na Investigação (antes da reunião)
**Pedido da Rebecka (02/11):** "o cliente sobe os arquivos e, na investigação, já valida o que tem, o que não tem, faz um diagnóstico para depois ir para a reunião".

**Decisões:**
- A aba **Investigação** virou o **pré-diagnóstico**, que fica antes da reunião e tem quatro partes.
- **Checklist:** para cada grupo de arquivos que o formulário pediu, cruza três coisas: o que o cliente disse (tenho / em parte / mando depois / não tenho), o que chegou nas evidências (do cliente ou da equipe, pela classificação) e quantos meses do período de referência os arquivos cobrem. Sem formulário, valem os grupos padrão e os últimos 6 meses completos.
  - **Situações:**
    - recebido;
    - recebido em parte (não cobre o período todo);
    - disse que tem, não mandou;
    - não tem (lacuna, não pedido);
    - falta;
    - opcional (complementares).
  - Os grupos de plataforma que o cliente não viu no formulário ficam de fora.
- **O que os dados mostram:** os pontos fracos da leitura das planilhas e os números que acompanha e não acompanha.
- **Pedir ao cliente:** uma mensagem montada com o que falta. A equipe edita, e a versão editada fica guardada; "Montar de novo" refaz com o que falta agora.
- **Para conversar na reunião:** o que ele prometeu e não mandou, o que não tem e os números que não acompanha.
- **"Marcar pré-diagnóstico como revisado"** registra a revisão no histórico e no progresso (etapa nova). A partir daí, o próximo passo é a reunião.
- O número na aba Investigação soma o que falta, o que foi prometido e o que chegou em parte.
- **Hipótese em aberto:** mostrar ao cliente, no próprio link, uma versão simples do checklist ("recebemos 4 de 7"). Por enquanto, fica só para a equipe, até a decisão da Rebecka.

## v0.223 — Diagnóstico Inteligente, D1: o diagnóstico da empresa e a Central de Evidências
**Pedido da Rebecka (02/11):** especificação "Growth's Brain: Diagnóstico Inteligente de Growth". A auditoria (Fase 1) está em `docs/growths-brain-diagnostico-auditoria.md`.
**Decisões dela (02/11):**
- O diagnóstico é **da empresa** (workspace) e publica no Planejamento dela.
- A IA pode ler PDF, Word e texto, com limite diário; o custo fica visível só para ela (entra na D5).
- Construir na ordem D1 a D8.

**O que a D1 decide:**
- **Tela única** em Growth → Diagnóstico Growth: a lista dos diagnósticos da empresa e, dentro de cada um, cinco abas:
  - Evidências;
  - Investigação;
  - Dados;
  - Arquitetura;
  - Validação e entrega.
- O diagnóstico **pode nascer sem formulário** e ganha título, responsável (da equipe), período de referência, versão e cinco status: em coleta, em análise, em revisão, validado, arquivado.
- Ligar a um formulário respondido é opcional e **não tem volta**. Quando ligado, os arquivos que o cliente mandou por aquele link entram nas evidências, inclusive os que chegarem depois.
- **Central de Evidências:** a equipe também sobe arquivos (antes, só o cliente pelo link).
  - Antes do envio, o Growths confere o tipo real do arquivo pelos primeiros bytes (um .pdf que não é PDF é recusado), o tamanho (até 20 MB) e o conteúdo (hash SHA-256).
  - O mesmo conteúdo não entra duas vezes. O mesmo nome com conteúdo novo vira versão 2.
  - Classificação em 14 tipos. A **sugestão pelo nome** fica marcada como "sugerida" e **nunca troca** a escolhida à mão.
  - Cada arquivo também guarda o período que representa e a marca de dados pessoais.
  - A leitura tem status: aguardando, lido, erro com o motivo, só guardado (imagens e apresentações).
  - **A equipe não apaga arquivo: arquiva.** O original continua guardado e dá para restaurar.
- **Arquivos do cliente** que chegaram antes não têm a conferência de conteúdo. O botão "Conferir repetidos" baixa e confere.
- **Progresso:** sete etapas que se conferem sozinhas (evidências recebidas e classificadas, formulário, números que decidem, planilhas lidas, North Star, validado). As próximas versões acrescentam etapas.
- **Histórico:** toda mudança de status entra sozinha. Decisões e comentários são registrados à mão. Não se edita nem se apaga.
- **O que já existia continua igual:** a reunião do diagnóstico (Pesquisas) abre pela aba Investigação. A leitura de planilhas abre pela aba Dados, guarda o resultado no diagnóstico e marca as planilhas como lidas. A leitura que monta o Growth Model da empresa fica no botão "Ler planilhas sem diagnóstico".

**Próximo (D2):** o que já se sabe, com a origem de cada informação (formulário, reunião, planilha, documento), os conflitos entre fontes, as pendências por prioridade e as decisões ligadas a cada informação.

**Pendências para a Rebecka:**
1. Rodar o RODAR_v0.223 (depois do 0.221).
2. Testar o passo a passo.

## v0.222 — Padrão de abas na mesma página (Cockpit primeiro)
**Pedido da Rebecka (02/11)**: a página do Cockpit ficou longa; dividir em abas na mesma página, com as áreas na aba principal e, nas outras, as metas do período e os riscos e oportunidades. "Isso podia ser um padrão de todas as nossas páginas."
Decisões:
- **Cockpit em três abas**: **Áreas** (padrão: Geral, Marketing, Vendas, Financeiro, Projetos, Growth, Clientes), **Metas do período** (faturamento, trajetória, faixa provável, leads e vendas, campanhas e produtos, metas das áreas) e **Riscos e oportunidades**.
- **Número na aba**: quantas metas estão em atenção ou em risco; quantos riscos estão em aberto. Assim dá para ver de longe se vale abrir a aba.
- O filtro de período fica em cima das abas e vale para as três. A aba escolhida fica guardada enquanto a sessão está aberta (trocar o período ou sair e voltar ao Cockpit mantém a aba).
- **Padrão reutilizável**: `abasHtml(chave, abas, padrão)` e `abasLiga(m, chave, padrão)`. Qualquer página pode usar.
**Próximo**: aplicar o mesmo padrão às páginas longas: Dashboard geral (Administrativo), Dashboard financeiro, Dashboard de vendas e Dashboard de marketing (as seções viram abas), o Planejamento anual (objetivos e metas / meta do ano e trimestres / calendário de campanhas) e o Customer Success. Combinar a ordem com a Rebecka.

## v0.221 — Metas das áreas (Financeiro, Customer Success e Growth)
**Pedido da Rebecka (01/11)**: completar as metas das outras áreas. Decisão dela: a margem vem da DRE (lançamentos) para quem tem o Financeiro completo e do Financeiro simplificado para quem só tem o Go-to-Market, com a tela mostrando de onde veio o número.
Decisões:
- **Métricas de nível** (não se somam no tempo, por isso não têm "esperado até hoje" nem projeção): margem (no mínimo), saldo de caixa (no mínimo), churn mensal (no máximo), retenção em 90 dias, LTV e ascensão (no mínimo), North Star (para cima ou para baixo, conforme o Growth Model).
- **Valor e fonte**: margem = lucro ÷ receita da DRE; sem receita na DRE, resultado da operação ÷ faturamento do Financeiro simplificado. Caixa = saldo em banco hoje. CS = o mesmo cálculo da tela de Customer Success (situação de hoje, janela de 30 dias). North Star = valor automático do Growth Model (ou o preenchido à mão). A tela sempre escreve a fonte.
- **Status**: dentro / atenção (até a tolerância além do limite) / em risco / sem dados. Tolerância do CS = a das metas do CS (15%); as outras usam a regra do Cockpit (10%).
- **Absorção sem duplicar**: as metas do CS, o saldo mínimo do Financeiro e a meta da North Star viram metas do ano no registro. Mudar de um lado muda o outro (espelho com trava). **Fato**: em produção, as metas do CS de um cliente estão nos valores padrão (churn 6%, retenção 85%, LTV R$ 600, ascensão 15%). Elas entram como estão; confira se são as desejadas.
- **Telas**: Planejamento anual › "Metas das áreas" (as sete métricas, regra, meta do ano, valor agora, status, fonte, um botão para salvar); Cockpit › tabela "Metas das áreas" na faixa de metas; a saúde dos painéis de Financeiro, CS e Growth passa a mostrar essas metas; o Risk Engine aponta meta de nível fora do limite (mês até hoje).
- **Correção**: "Ver todos" dos riscos abre sempre sem filtro (o filtro de antes escondia riscos).
**Pendências**: metas de nível por mês (hoje são do ano); retenção e NPS do Customer Growth como métricas próprias; caixa projetado (não só o de hoje).

## v0.220 — Acerto da projeção (histórico e calibração)
**Pedido da Rebecka (01/11)**: próximo (medir o acerto da projeção).
Decisões:
- **Não esperar meses de fotos**: as fotos diárias começaram na v0.213. Para medir o acerto já, o Growths **refaz** a projeção que o Cockpit teria mostrado em cada mês fechado (até 12), nos dias 3, 7, 10, 15, 20 e 25, com o mesmo método, e compara com o total real do mês (`projecao_backtest`).
- **Duas medidas**: erro médio (quanto errou, para mais ou para menos) e viés (se erra sempre para o mesmo lado: positivo = a projeção passou do real). Também o maior erro.
- **Faixa provável no Cockpit**: num mês do calendário em andamento, abaixo da projeção do faturamento aparece "Faixa provável até dd/mm: R$ A a R$ B", usando o erro histórico do dia do mês mais próximo. Diz quando a meta fica abaixo mesmo no melhor caso ou é batida mesmo no pior. A faixa nunca começa abaixo do que já foi realizado.
- **Honestidade**: com menos de 3 meses fechados com movimento, não há faixa e a tela diz o motivo. O texto sempre avisa que é erro observado no passado, não probabilidade.
- **Fotos guardadas**: o acerto real (as projeções mostradas de verdade) aparece em "Acerto da projeção" assim que houver período encerrado com foto (`projecao_fotos`).
- **Fato** (base de teste, 3 meses): no dia 15 a projeção do faturamento errou em média 70% e ficou sempre abaixo do real (as vendas se concentram no fim do mês, em lançamentos). Os leads erraram 11%. Isso mostra que, para faturamento de lançamento, o ritmo linear subestima. É uma pista para a próxima melhoria do método (trajetória sazonal dentro do mês).
**Pendências**: método de projeção com a curva típica do mês (corrigir o viés); faixa também para leads, vendas, campanhas e produtos; probabilidade de bater a meta quando houver ao menos 6 meses de fotos.

## v0.219 — Funil AARRR
**Pedido da Rebecka (01/11)**: continuar (próximo do documento: a visão AARRR).
Decisões:
- **Onde**: botão "Abrir o funil AARRR" no painel Growth do Cockpit. Abre por cima, no período escolhido, comparando com o período anterior do mesmo tamanho.
- **Etapas iguais às do Diagnóstico** (Aquisição, Ativação, Retenção, Receita, Recomendação, Recompra e ascensão), cada uma com a sua pergunta e só com números que o Growths já calcula:
  - aquisição: leads, investimento em mídia, CPL;
  - ativação: clientes novos (1ª compra), lead → cliente novo, marcos obrigatórios atingidos;
  - retenção: alunos ativos, saíram, saída;
  - receita: faturamento, vendas, ticket;
  - recomendação: NPS e respostas;
  - recompra: clientes que compraram de novo e a parte do faturamento que veio deles.
- **Sem dado é sem dado**: indicação ainda não é medida; marcos, alunos ativos e NPS precisam do Customer Growth. A tela diz isso em vez de mostrar zero.
- **Não linear**: só leads → cliente novo aparece como passagem; as outras etapas são lidas cada uma por si.
- **Metas** do registro aparecem nas etapas (leads, faturamento, vendas), com o status do Cockpit. "Investigar" abre a investigação daquele número.
- **Gargalo sugerido**: a taxa que mais piorou (mais de 5%) contra o período anterior, sempre como pista e não como diagnóstico. **Fato**: no teste, os leads caíram 83%, mas o gargalo apontado foi o ticket (−7%), porque a regra olha taxas e não volumes. Volume em queda já aparece no risco da meta.
- **North Star**: aparece na etapa que ela mede (pela métrica automática), com o status (provisória).
**Pendências**: registrar indicações; tempo entre etapas (lead → 1ª compra, compra → 1º marco); coortes por etapa; metas próprias de ativação, retenção e recomendação no registro.

## v0.218 — Cenários ligados à meta (Scenario Engine)
**Pedido da Rebecka (01/11)**: seguir com os cenários.
Decisões:
- **Onde**: "Simular" no faturamento da faixa de metas, em cada linha de meta (leads, vendas, campanha, produto) e nos riscos que vêm de meta. Abre por cima do Cockpit.
- **Alavancas**: leads a mais (%), investimento extra em mídia (R$, convertido em leads pelo CPL dos últimos 90 dias), conversão lead → venda (%) e ticket médio (R$). Valem só para o que falta do período. A meta de leads só aceita as alavancas de leads; a de vendas também a conversão; a de faturamento todas.
- **Conta**: parte da mesma projeção do Cockpit (cenário sem alavanca = projeção de hoje) e multiplica o que falta pela relação faturamento = leads × conversão × ticket. As médias de 90 dias são da empresa toda.
- **Mostra**: atual × cenário (leads, vendas e faturamento que faltam; projeção até o fim), se o cenário bate a meta e quanto falta, quanto o resto do período precisaria render a mais para bater, as premissas (janela, médias, CPL) e as incertezas (não é garantia; mais verba costuma subir o CPL e baixar a conversão).
- **Salvar, comparar e versionar**: cenários salvos (nome, hipótese, alavancas, resultado do dia) ficam na lista daquela meta. "Carregar" refaz a conta com os números de hoje; salvar de novo cria a versão seguinte, ligada à anterior. Dá para aprovar e arquivar.
- **Tabela nova (`metas_cenarios`) e não `gm_cenarios`**: `gm_cenarios` são os cenários do modelo de 12 meses do Growth Model (planilha, ICE, unit economics). Gravar o "e se" de uma meta ali quebraria aquelas telas. Os dois não copiam números um do outro.
- **Nada muda nos dados reais.**
**Pendências**: médias por campanha e por produto (hoje são da empresa); cenário aprovado alimentar o Planejamento anual e virar experimento no Growth; efeito do investimento com retorno decrescente (hoje é linear).

## v0.217 — Investigação (Investigation Engine)
**Pedido da Rebecka (01/11)**: continuar (próximo passo do documento: clicar num número e descer até a composição e os registros, com caminho de volta).
Decisões:
- **Onde**: "Investigar o faturamento" na faixa de metas; "Investigar" em cada linha (leads, vendas, campanhas, produtos); "Investigar" nos riscos que vêm de meta. Abre por cima do Cockpit, sem tela nova.
- **O que mostra**: o total do período, o do período anterior do mesmo tamanho e a diferença; o número aberto por dimensão (faturamento e vendas: produto, campanha, canal, plataforma, cliente novo × recorrente; leads: campanha de origem, canal, qualificação, situação), com a marca do período anterior, a diferença de cada fatia e "o que mais mudou".
- **Filtro cruzado**: clicar numa fatia filtra todas as outras dimensões por ela, e o caminho no topo mostra cada passo. Dá para voltar a qualquer passo ou usar "Voltar".
- **Registros**: "Ver os registros" lista as vendas ou os leads por trás do número (até 300 na tela, os mais recentes), com link para a ficha da pessoa.
- **Números fecham**: as fatias de cada dimensão somam o total, e o total é o mesmo das metas e do Dashboard de vendas. **Fato**: o histórico importado entra como fatia própria ("Histórico importado"), porque não tem campanha nem canal ligados.
- **Leads por campanha** aqui usam a campanha de origem do cadastro (`pessoas.campanha_id`); a meta da campanha usa quem entrou na campanha. Os dois números podem ser diferentes, e a tela avisa.
**Pendências**: investigar também a partir dos cartões dos dashboards (não só do Cockpit); comparar dois segmentos lado a lado; coortes dentro da investigação.

## v0.216 — Trajetória das metas e saúde por área
**Pedido da Rebecka (01/11)**: seguir (a parte visual: gráfico de trajetória e saúde por área no Cockpit).
Decisões:
- **Gráfico de trajetória**: meta acumulada (tracejada), realizado acumulado e projeção (pontilhada) até o fim do período, com o dia de hoje marcado. Os números vêm de `metas_trajetoria`, que usa as mesmas funções da faixa de metas (o último ponto bate com o "esperado até hoje" e o "realizado"). Fica no faturamento da faixa de metas; leads, vendas, campanhas e produtos abrem o mesmo gráfico no botão "Trajetória". Até 400 dias; períodos longos usam no máximo 120 pontos.
- **Saúde por área**: cada painel do Cockpit ganhou uma linha com as metas daquela área (faturamento no Geral; leads e campanhas no Marketing; vendas e produtos em Vendas), com status e realizado × esperado, e o risco principal da área. **Sem média nem nota única**: o documento proíbe consolidar sem metodologia. Área sem meta diz "Sem meta definida para esta área no período".
- **Correções**: (1) o risco de qualidade dos dados mostrava "56,2 aviso(s)", mas esse número é um percentual da regra, não uma contagem; agora fica sem número de impacto. (2) A linha do ano diz "(só os meses com meta)" quando o ano tem meta só em parte.
**Pendências**: metas de Financeiro (margem, caixa), CS (retenção, churn) e Growth (NSM com meta no registro) para a saúde dessas áreas; trajetória por mês nos períodos longos.

## v0.215 — Growth's Brain, incremento 3: Risk Engine
**Pedido da Rebecka (01/11)**: "faça o Risk Engine" (antes dos gráficos de trajetória e da saúde por área).
Decisões:
- **Um registro só (`riscos`)**, alimentado pelo que o Growths já detecta, sem detector novo por área:
  - **metas** (mês e ano da empresa; campanhas e produtos em andamento): "abaixo do esperado" (status Atenção ou Em risco), "risco de não atingir" (projeção abaixo de 95% da meta) e "oportunidade" (projeção 10% acima);
  - **alertas** em aberto (assistente e CS) **agrupados por regra**: **fato**, a produção tem 948 avisos de CS em aberto (484 "sem CS", 464 "parado"); viram 2 riscos, não 948;
  - **guardrails** em aberto;
  - **qualidade dos dados** (últimos 30 dias). Só roda quando alguém com login atualiza, porque a função de qualidade exige login; o cron diário pula essa parte.
- **Severidade e impacto por regra escrita**, sem probabilidade. Meta: Em risco = alta, Atenção = média; projeção abaixo de 75% = alta, abaixo de 90% = média, abaixo de 95% = baixa. Impacto = o que falta em R$ ou em quantidade.
- **Período com meta só em parte** (ex.: o ano com meta só em novembro) não gera risco, para não repetir o do mês.
- **Ciclo de vida**: a conferência é idempotente (atualiza, não duplica). Quando a condição some, o sistema resolve; quando volta, reabre. Descartado por uma pessoa (com nota obrigatória) não volta enquanto a condição for a mesma. Toda mudança fica em `riscos_eventos`.
- **Cockpit**: bloco "Riscos e oportunidades" com os 5 mais graves, "Ver todos" (por área, com filtro), "Tratar" (assumir, resolver, descartar, reabrir, nota, histórico) e "Abrir" (vai à tela de origem). Os painéis de cada área mostram quantos riscos têm.
- A conferência roda ao abrir o Cockpit se a última tem mais de 3 horas, no botão "Atualizar agora" e todo dia às 08:17.
**Pendências**: riscos de margem e de dependência de produto ou canal (§11 "Empresa") e riscos combinados entre áreas; risco por cliente no CS (§17); avisar o responsável quando um risco alto aparece.

## v0.214 — Growth's Brain, incremento 2
**Pedido da Rebecka (01/11)**: seguir para o próximo passo (leads e vendas no registro de metas, metas por produto e por campanha).
Decisões:
- **Leads e vendas da empresa** no registro, vindos da tabela do mês do Planejamento (mesmo espelho do faturamento). O orçamento continua só no planejamento (não é meta de resultado).
- **Metas de campanha**: a meta de leads, vendas e receita de cada campanha entra no registro com escopo "campanha". A campanha continua sendo o lugar de editar (espelho de mão única). Janela, para não supor resultado linear no mês: leads nos dias da captação; vendas e faturamento nos dias do carrinho aberto; sem essas datas, do início ao fim da campanha.
- **Campanha perpétua com meta por mês** (meta_leads_mes) e **metas por fase e canal** (campanha_metas, 27 em produção) ficam para o próximo incremento.
- **Meta por produto**: nova, criada no Planejamento anual (faturamento ou vendas, com janela, premissa e objetivo). Conta só as vendas do Growths ligadas ao produto: **fato**, o histórico importado guarda o produto como texto, sem ligação.
- **Mesmos números das telas**: leads da empresa = pessoas captadas (Dashboard de vendas); leads da campanha = pessoas que entraram na campanha (Dashboard da campanha); vendas = vendas aprovadas.
- **Cobertura parcial**: se só parte do período tem meta (ex.: setembro e outubro, com meta só em outubro), o realizado conta só nos dias com meta e a linha mostra "parcial". Assim a comparação não fica injusta.
- **Cockpit**: a faixa virou "Metas do período". Mostra o faturamento, a tabela de leads e vendas da empresa e a tabela de campanhas e produtos com meta (cada uma na sua janela; clicar abre a campanha).
- **Pendência**: vendas e leads de uma campanha fora da janela da meta (ex.: venda depois do carrinho fechar) não entram na meta da campanha.

## v0.213 — Growth's Brain, incremento 1
**Pedido da Rebecka (01/11)**: documento "Growth's Brain" (planejar → executar → monitorar → detectar → investigar → simular → decidir → aprender). Etapa 1 = auditoria (`docs/growths-brain-auditoria.md`). Decisões dela depois da auditoria: começar pelo **faturamento**; as metas que já existem são **absorvidas aos poucos**; **objetivos dentro do Planejamento anual**; NSM "Receita bruta" **marcada como provisória**.
Decisões de implementação:
- **Registro central `metas`** ligado ao Planejamento anual. Por enquanto, só a métrica "faturamento" (empresa, ano e mês). Cada mudança cria uma versão nova e guarda a anterior.
- **Absorção sem quebrar nada**: a meta do ano (`plano_anual`) e a do mês (`planejamento_mensal`) se espelham com `metas` por gatilho. As telas antigas continuam funcionando, e quem manda é `metas`.
- **Faturamento** = vendas aprovadas (Growths + histórico importado), pela data da venda: o mesmo número do Dashboard de vendas e da meta do Planejamento anual. **Fato**: o "Receita" do Cockpit e do Dashboard geral é a receita da DRE (lançamentos, por competência), outro número. Por isso a meta se chama "faturamento". **Pendência**: a definição "receita" do dicionário diz "vendas OU DRE"; separar em duas.
- **Meta de um período**: cada dia recebe a meta do mês dividida pelos dias do mês; um mês sem meta divide o que sobra da meta do ano. Assim o ano soma exatamente a meta do ano. Se a soma dos meses passa da meta do ano, o Cockpit e o Planejamento avisam.
- **Projeção**: com 7 dias ou mais de período, o ritmo do período; antes disso, a média dos últimos 28 dias; sem venda nenhuma, não projeta. O método e a limitação aparecem em "Como calculamos". **Não há probabilidade** (o documento proíbe inventar; ela entra quando houver histórico de previsões, e a foto diária começa a guardar isso).
- **Status por regra do cliente** (`metas_regras`): até 10% abaixo do esperado, "Dentro do esperado"; de 10% a 25%, "Atenção"; mais que 25%, "Em risco". Com menos de 3 dias de período, "Sem dados suficientes". Também "Atingida", "Não atingida", "Sem meta" e "Ainda não começou".
- **Cockpit**: faixa "Meta de faturamento" no topo, no período padrão, com meta, esperado até hoje, realizado, desvio, projeção e status, mais a linha do ano. Botões: Como calculamos, Ver as vendas do período (abre o Dashboard de vendas no mesmo período) e Planejamento anual.
- **Objetivos do ano**: nova seção "Objetivos e metas do ano" no Planejamento anual. Os 2 objetivos da tela antiga da Mathisa — Operação aparecem lá como "do planejamento antigo". A meta do ano pode ser ligada a um objetivo.
- **NSM**: status (candidata, provisória, em validação, aprovada), versão e histórico. Toda NSM nova nasce provisória.
Próximos incrementos (ordem do documento): leads e vendas no mesmo registro; metas de campanha e de CS absorvidas; registro de riscos alimentado pelos alertas que já existem; cenário ligado à meta; visão AARRR; calibração da projeção com as fotos.

## v0.212 — Período padrão em todos os dashboards e sem o Planejamento da empresa antigo
**Pedidos da Rebecka (01/11)**: (1) "Pode ocultar esse menu" — o Planejamento da empresa antigo (objetivos); (2) todos os dashboards com o mesmo filtro de período no topo, com "30 dias, este mês, próximos 30 dias, 7 dias e o personalizado", inclusive Financeiro, Customer Success e Cockpit; o Cockpit traz o mês corrente e, mudando o período, muda todos os painéis dele.
Decisões:
- **Atalhos, nesta ordem**: Últimos 30 dias, Este mês, Próximos 30 dias, Últimos 7 dias; depois Mês passado, Últimos 90 dias, Últimos 12 meses, Este ano; e Personalizado.
- **Começa no mês corrente** em todos (antes: últimos 30 dias). "Este mês" agora é o mês inteiro (01 a 30/11), para o Financeiro mostrar o que vence até o fim do mês. "Próximos 30 dias" = hoje + 29 dias.
- **Cockpit**: os botões de período saíram; usa o filtro padrão. Os números contam até hoje (um período no futuro é cortado em hoje). Acima de ~2 meses os gráficos juntam por mês.
- **Customer Success**: o banco (`heavyops_painel`) só sabe contar "N dias para trás a partir de hoje". Por isso os produtos contam do início do período escolhido até hoje — o texto ao lado do filtro mostra as datas certas. **Hipótese**: se for preciso um período fechado no passado (só outubro), a função do banco precisa ganhar início e fim.
- **Financeiro (dashboard)**: usa o período padrão. O filtro de vencimentos (próximos 7 dias, já vencidas, tudo…) continua só em Contas a receber e Contas a pagar, que são listas de trabalho e não dashboards.
- **Planejamento da empresa antigo**: saiu do menu. Um link antigo abre o Planejamento anual. Os dados antigos continuam no banco (nada foi apagado).

## v0.211 — Período padrão nos dashboards
**Pedido da Rebecka (01/11)**: os dashboards têm de ser padronizados (o de Vendas não tinha o filtro igual aos outros). Levantamento (fato): Administrativo com uma lista só (7, 15, 30 dias, mês, 12 meses, ano, personalizado); Marketing com De, Até e atalho; Mídia paga com De e Até; Vendas com De, Até e atalho (v0.208); Financeiro com vencimentos futuros; Customer Success com "produtos nos últimos 30, 90 ou 180 dias"; Cockpit com botões.
Decisões:
- **Filtro padrão** nos dashboards de período — Administrativo, Marketing, Vendas e Mídia paga: "Período" (Últimos 7, 30 e 90 dias, Últimos 12 meses, Este mês, Mês passado, Este ano, Personalizado), "De" e "Até". Mudar a data à mão vira "Personalizado".
- **O período vale para todos**: escolher "Mês passado" no Marketing faz o Vendas, o Administrativo e a Mídia paga abrirem em outubro. Abrir a Mídia paga de uma campanha (ou de um dia do gráfico) também muda o período padrão.
- Começa nos últimos 30 dias (o Marketing começava em 90 e a Mídia paga em 14).
- **Ficam com a lógica própria (por ora)**: Financeiro (o filtro é de vencimentos futuros: próximos 7 dias, 30 dias…), Customer Success (janela dos produtos) e Cockpit (botões de resumo). Se quiser, dá para trazer os três para o mesmo componente numa próxima versão.
- Os números principais já ficam no topo em todos (Visão geral).
- **Fato**: o Financeiro já guardava o período de vencimento em `S.per`; o período padrão novo usa `S.perD` para não misturar os dois.
- **Planejamento da empresa × planejamento do ano**: a Rebecka procurou o planejamento anual (meta, 3 cenários, trimestres) em Administrativo › Planejamento da empresa, que é a tela de objetivos. Ele está em Marketing › Campanhas e planejamento › Planejamento anual, e a meta de 2026 do Lumen está salva em produção. Agora o Planejamento da empresa tem no topo um atalho, "Abrir o planejamento do ano".

## v0.210 — Financeiro simplificado no completo e comissão geral ou por produto
**Pedido da Rebecka (01/11)**:
- O Financeiro simplificado também vale para o **Growths completo**; no **Go-to-Market** ele é o único financeiro. Decisão: a tela Administrativo › Financeiro simplificado aparece para todos (cliente sem pacote vê tudo; o Go-to-Market passa a incluir a tela) e o pacote separado "Financeiro simplificado" da v0.209 deixa de existir. No completo, a tela avisa que os custos são os lançados ali (não vêm das contas a pagar) e que o DRE completo fica em Financeiro. Os Custos de marketing (menu Marketing) continuam só para cliente sem financeiro.
- **Comissão do parceiro**: geral (vale para todos os produtos, "cadastro geral") ou diferente por produto. Decisão: cada parceiro tem uma comissão geral opcional e uma lista de produtos com % diferente; na venda de um produto vale a % daquele produto, senão a geral (as duas nunca somam). Mudar uma % a partir de um mês fecha a anterior no mês de antes, sem mudar o passado. Parceiro inativo para de entrar no DRE; excluir apaga do DRE de todos os meses.
- Ela também pensou num filtro para ver o resultado só das campanhas nos relatórios: fica como próxima ideia (DRE simplificado por campanha), a validar.

## v0.209 — Financeiro simplificado (DRE simplificado)
**Pedido da Rebecka (01/11)**: para o cliente que não faz contas a pagar e a receber no Growths, um DRE simplificado: quanto vende, taxa da plataforma, comissões (coprodutor, vendedor com a %), mídia, custos de marketing (equipe, ferramentas) e outros custos da operação numa linha geral, com a margem, médias e gráficos. Nome: **Financeiro simplificado**. Sem caixa, sem o que foi pago ou não, sem lançamento contábil e sem custo por funcionário.
Decisões:
- **Pacote "Financeiro simplificado"** = Go-to-Market + a tela Administrativo › Financeiro simplificado. O Go-to-Market continua só com os custos de marketing.
- **Custos do mês** (a mesma rotina dos custos de marketing: fixo repete, variável no fim do mês, fechar o mês, aviso à Mathisa) com **grupo**: Marketing (entra no CAC e no Resultado de marketing) ou **Outros custos da operação** (pró-labore, administrativo, aluguel…; só no DRE).
- **Comissões de parceiros**: nome, papel (coprodutor, afiliado, vendedor, outro), %, sobre o valor da venda ou o valor menos a taxa, de um produto ou de todos, com vigência. O Growths calcula a comissão de cada mês sobre as vendas aprovadas. As comissões da equipe (já calculadas no Growths) entram junto.
- **DRE simplificado mês a mês** (3, 6 ou 12 meses até o mês escolhido): Faturamento (vendas aprovadas, com o histórico importado) − taxa da plataforma − impostos sobre as vendas − comissões = **Receita líquida** − mídia − custos de marketing = **Resultado de marketing** − outros custos da operação = **Resultado da operação**; total, % do faturamento e média por mês. Cartões com os totais e o peso do marketing; gráfico de faturamento e resultados; "para onde vai cada R$ 100 vendidos".
- Avisos na tela: sem caixa e sem contas a pagar e a receber; mês com custo variável faltando aparece marcado e incompleto; vendas sem taxa informada entram com taxa zero.
- O Resultado de marketing (Custos de marketing, dashboards) continua só com o grupo marketing.
- **Hipótese**: comissões de parceiros só sobre as vendas do Growths (o histórico importado não tem produto ligado); taxa e impostos só das vendas do Growths.

## v0.208 — Dashboard de vendas no padrão
**Pedido da Rebecka (01/11)**: o Dashboard de vendas mostrava pessoas e leads no topo e não tinha o filtro de período dos outros; o que importa é clientes ativos, novos, valor das vendas, ticket e conversão. Os dashboards têm de ser padronizados.
Decisões:
- **Filtro de período** igual ao do Dashboard de marketing: de, até e atalhos (7, 30, 90 dias, 12 meses, este mês, mês passado). Padrão: últimos 30 dias.
- **No topo (Visão geral)**: valor das vendas, vendas (com reembolsos), ticket médio, clientes novos (primeira compra no período, contando o histórico importado), clientes ativos (hoje) e lead → cliente (dos leads que entraram no período, quantos já viraram cliente). Valor, vendas, ticket e clientes novos comparados com o período anterior do mesmo tamanho.
- Os números de cadastros (pessoas, cadastros novos em 30 dias, qualificados, a qualificar) descem para **Cadastros e funil**.
- **Vendas por plataforma** usa o mesmo período (sem filtro próprio).
- Próximo: revisar os outros dashboards com a mesma regra (filtro igual e os números principais no topo).

## v0.207 — Correções da Entrada do cliente e restauração do index.html
**Fato (repositório)**: os commits 5605139 e 8f466f8 (atendimento: automações de chatbot, de outra sessão) gravaram um `index.html` cortado: o arquivo tinha o texto "Warning: truncated output" no meio do código e perdeu cerca de 377 KB (por exemplo, os Pacotes de acesso). A v0.207 parte da v0.206 inteira e reaplica a única mudança deles no index (`atendimento.css?v=0197` e `atendimento.js?v=0197`). Os outros arquivos deles (assets/atendimento.*, função atendimento, migração 20261204100000) não foram mexidos. Se o index cortado foi publicado, publique de novo esta versão.
**Pedido da Rebecka (01/11)**, testando a Entrada do cliente:
- "Não deixa continuar mesmo com os arquivos enviados": **fato** — a pesquisa em produção tem 0 envios e 0 arquivos, ou seja, o teste foi pelo link aberto/pré-visualização, que não envia arquivo; o aviso de erro só aparecia no rodapé. Agora: pelo link aberto ou pré-visualização, o arquivo fica marcado como **teste** (o grupo conta como respondido e dá para continuar), com o aviso no próprio grupo de que o cliente envia pelo link individual (Fila de envio). Erro de envio também aparece no grupo.
- **✓ verde** no grupo quando há arquivo anexado ("✓ arquivo anexado" e borda verde); some se o arquivo for retirado.
- **Pergunta nova**: "Quais números você acompanha hoje no seu negócio? (marque todos)" — lista com 19 opções (faturamento, ticket, investimento, leads, CPL, conversão, CAC, ROAS, comparecimento, checkout, abandono, reembolsos, churn, recompra, LTV, NPS, MRR, margem, nenhum) — e "Acompanha outro número? Qual?" (opcional). O formulário passa a 15 perguntas, ainda em 4 partes. Pesquisa já criada: criar de novo pelo modelo (a de produção não tem envios).
- **Pacotes de acesso dos clientes**: a coluna Tipo mostra "Completo · sem financeiro" para o cliente num pacote sem Financeiro (Go-to-Market).
**Em planejamento (aguardando o ok dela)**: Financeiro simplificado (DRE simplificado sem contas a pagar e a receber) e o Dashboard de vendas no padrão dos outros dashboards.

## v0.206 — Importar histórico de vendas e histórico na ficha (etapas 2 e 3)
**Pedido da Rebecka (01/11)**: subir as vendas do último ano do cliente que entra (clientes, compras, plataforma, data, primeira compra) para ter o histórico, comparar e calcular o planejamento anual, sem o financeiro.
Decisões:
- **Onde**: Configurações › Importar e validar dados › "Histórico de vendas (antes do Growths)". A Central de importação que já existia (clientes, produtos, vendas…) continua para os dados do dia a dia; a importação de vendas de lá gera financeiro, por isso o histórico tem a sua.
- **Tabela separada** (`vendas_historicas`): conta nas métricas e no planejamento; não gera lançamento, conta a receber, comissão, projeto, jornada nem automação.
- **De-para**: o Growths liga as colunas pelos nomes (português e inglês) e você troca o que estiver errado; aceita CSV (com aspas, ; , ou tab) e Excel. Os status do arquivo viram aprovada, reembolsada, cancelada, chargeback ou "não é venda" (aguardando pagamento, expirado…), editáveis. Sem coluna de status, tudo entra como aprovada (com aviso).
- **Conferir antes**: resumo sem gravar nada (vendas por status, valor aprovado, período, clientes novos e já cadastrados, e o que fica de fora: não é venda, repetida, já no Growths, com erro, com as linhas).
- **Pessoas**: liga por e-mail, depois telefone. Quem não existe é criado (cliente inativo desde a primeira compra aprovada; lead se só reembolsou ou cancelou; origem = plataforma). Quem já existia e comprou antes vira cliente desde a primeira compra.
- **Sem duplicar**: código da venda na plataforma; sem código, dia + valor + e-mail. Venda que já está no Growths (mesmo código, ou mesma pessoa, dia e valor) fica de fora. O mesmo arquivo não entra duas vezes.
- **Desfazer**: apaga as vendas da carga e as pessoas que ela criou, se não ganharam venda, contrato ou aluno depois.
- **Ficha do cliente**: bloco "Antes do Growths (histórico importado)" com primeira e última compra, compras aprovadas, total, plataformas e reembolsos; as compras entram na linha do tempo.
- **Planejamento anual**: receita do ano anterior, clientes, ticket, recompra, sazonalidade e realizado somam o histórico.
- **Hipótese**: os nomes das colunas dos relatórios de Hotmart, Kiwify, Eduzz e Hubla não foram confirmados em fonte oficial; o de-para reconhece nomes comuns e deixa ajustar. Com um arquivo real de cada, dá para afinar.
- Fica para a etapa 5: comparar os anos (ano contra ano).

## v0.205 — Pacote Go-to-Market e Custos de marketing (etapa 4)
**Pedido da Rebecka (01/11)**: cliente que não quer o financeiro no Growths. Ela escolhe os módulos no cadastro do cliente; o pacote se chama **Go-to-Market**; o número se chama **Resultado de marketing**; a atividade do fim do mês é do cliente e a equipe da Mathisa recebe alerta se não foi preenchido; antes de fechar o mês, sempre conferir. Ela pediu para fazer a etapa 4 antes das 2 e 3.
Decisões:
- **Pacote "Go-to-Market"** em Configurações › Pacotes de acesso dos clientes (o sistema de pacotes da v0.85): todas as telas menos o Financeiro (dashboard, contas a pagar e a receber, custos e margens, lançamentos) e o cadastro financeiro e contábil. Os pacotes já bloqueiam no banco o módulo sem tela.
- **"Sem financeiro"** = o cliente tem pacote e nenhuma tela do Financeiro. Vale para o Go-to-Market e para qualquer pacote sem financeiro (por exemplo, Disparo).
- **Custos de marketing** (Marketing › Custos de marketing, só para cliente sem financeiro; desligado até ligar): itens **fixos** (repetem todo mês do "a partir de" ao "até") e **variáveis** (lançados mês a mês); um valor fechado por mês, sem detalhar quem é quem. Mudou um fixo: encerra e cria outro, para os meses passados não mudarem.
- **Fechar o mês**: só a partir do último dia e com todos os variáveis lançados (0 se não teve); mês fechado não muda (só reabrindo); fechar conclui a atividade.
- **Rotina diária**: no último dia do mês, cria a atividade "Lançar os custos de marketing de MM/AAAA" no projeto "Rotinas do mês" do cliente (criado se não existir), para o responsável escolhido (equipe do cliente), com aviso; a partir do dia 3 do mês seguinte, se faltar lançar ou fechar, avisa a equipe da agência (workspace marcado como agência: Mathisa) uma vez por mês.
- **Resultado de marketing** = receita − mídia − custos de marketing (proporcionais aos dias do mês no período), sempre com o aviso de que as outras despesas da empresa não entram; ROAS de mídia (receita ÷ mídia) e ROAS total (receita ÷ (mídia + marketing)); CAC de mídia e CAC completo (clientes novos = primeira compra aprovada no período). Faltou variável: o número aparece, marcado como incompleto.
- Aparece em: Custos de marketing (mês a mês), Dashboard de marketing (período) e Dashboard administrativo (mês atual), que também tira lucro, saldo em banco, CAC total, Saúde financeira e DRE/fluxo de caixa.
- **Vendas por plataforma** (Dashboard de vendas, para todos os clientes): vendas aprovadas, bruto, taxa, impostos, comissões da equipe, reembolsos e o que a plataforma deve repassar; sem financeiro, avisa que não dá para saber se caiu na conta.
- Planejamento anual sem financeiro: o "Do faturamento ao lucro" ganha o aviso de que é estimativa com os custos digitados.
- **Fica para depois**: Cockpit (painel Financeiro) no Go-to-Market; comissão de afiliado e coprodutor por plataforma (hoje só as comissões da equipe); o de-para dos relatórios das plataformas (etapa 2).
- **Hipótese a testar em produção**: com o módulo financeiro bloqueado no banco, as rotinas que geram contas a receber a partir das vendas (integrações, importação) podem recusar; testar com o cliente de teste antes de usar com um cliente real.

## v0.204 — Nome da pesquisa × título que o cliente vê
**Pedido da Rebecka (01/11)**: "Entrada do cliente (números e arquivos)" serve como nome para ela, mas o cliente via esse nome no alto do formulário, e ficou feio.
Decisões:
- Em **Editar pesquisa**, o campo vira "Nome da pesquisa (só a equipe vê)" e entra **"Título que quem responde vê"** (vazio: aparece o nome). Vale para todas as pesquisas; é o mesmo título da aba Formulário e aparência.
- A Entrada do cliente já nasce com o título **"Boas-vindas! Vamos conhecer o seu negócio"**. Pesquisa já criada: ponha o título em Editar.

## v0.203 — Entrada do cliente: vendas por plataforma
**Pedido da Rebecka (01/11)**: os clientes usam Hotmart, Eduzz, Kiwify e, em breve, Hubla, às vezes mais de uma. A planilha de vendas deve seguir a plataforma que o cliente marca, e o de-para fica com a equipe.
Decisões:
- "Onde vende?" ganhou **Hubla**. No checklist, aparece **um grupo "Vendas da <plataforma>" para cada plataforma marcada**, pedindo o relatório exportado do jeito que sai (todas as vendas, com reembolsos e cancelamentos), sem planilha-modelo: o de-para das colunas é feito na importação (etapa 2).
- **"Vendas fora das plataformas"** (com planilha-modelo) aparece quando o cliente marca Contrato direto, Loja própria ou Outro, ou quando não marca nenhuma plataforma.
- Só os grupos à mostra são cobrados e gravados.
- **Hipótese a confirmar**: os nomes das colunas de cada relatório (Hotmart, Kiwify, Eduzz, Hubla) não foram confirmados em fonte oficial; o de-para da importação vai reconhecer por sinônimos e deixar ligar à mão, e fica afinado com o primeiro arquivo real de cada plataforma.

## v0.202 — Entrada do cliente sem "Mando depois"
**Pedido da Rebecka (01/11)**: nos grupos de arquivos da Entrada do cliente, "Mando depois" não pode ser opção (o cliente não manda). Agora cada grupo é **enviar o arquivo** ou **"Não tenho"**; a cobrança e o texto da pergunta dizem o mesmo. O Diagnóstico 360° continua com "Mando depois". Pesquisa já criada com o modelo da v0.201 precisa ser criada de novo para pegar a mudança (a configuração fica gravada na pergunta).

## v0.201 — Entrada do cliente (etapa 1 do plano de primeira carga)
**Pedido da Rebecka (01/11)**: um "board inicial" para o cliente que está entrando responder a visão dele (ticket, faturamento…) e mandar as planilhas de clientes, leads e vendas, para gerar o diagnóstico e o planejamento. O Diagnóstico 360° ficou grande demais para isso. Plano aprovado em 5 etapas: 1 Entrada do cliente; 2 Importar histórico; 3 Histórico na ficha; 4 modo "só marketing" (redefinido por ela: sem financeiro, administrativo e custos; só marketing, vendas, atendimento e CS); 5 comparar os anos.
Decisões da etapa 1:
- Modelo novo **"Entrada do cliente (números e arquivos)"** na lista de modelos de Pesquisas, tipo diagnóstico: mesmo link individual, salvar e continuar, e o mesmo envio de arquivos do Diagnóstico 360°.
- **Curto**: 13 perguntas em 4 partes (Sobre o negócio, Seus números do seu jeito, O que você espera, Seus arquivos). Números com "Não sei"; custo da operação, regime e meta de 12 meses opcionais.
- **Checklist de arquivos**: Vendas, Clientes, Leads, Investimento em anúncios e Custos (opcional), cada um com **planilha-modelo** (CSV separado por ;, com as colunas que a importação vai ler e uma linha de exemplo). Vendas aceita o relatório que Hotmart, Kiwify ou Eduzz exportam.
- **Período pedido pela data em que a pesquisa é criada**: de julho em diante, os últimos 12 meses completos; de fevereiro a junho, o ano passado inteiro e este ano até agora; em janeiro, o ano passado inteiro.
- Os grupos usam as mesmas chaves da Central de Documentos (vendas, alunos, crm, marketing, financeiro); na tela da equipe aparecem com os nomes da Central.
- **Fato**: o teste de tela `t177_diagnostico_reuniao.py` já falhava antes desta versão no passo do Diagnóstico Growth ("abre o Diagnóstico Growth com o nome do cliente"); não é desta mudança. Fica para revisar.

## v0.200 — Planejar outro ano (2027)
**Pedido da Rebecka (01/11)**: ela queria fazer a meta de 2027, mas a tela só deixava 2026 (o seletor de ano ficava escondido lá embaixo, nas metas mês a mês, e o ano padrão era fixo em 2026); queria também poder ajustar o que salvou em 2026, que mostrou meta só no último trimestre.
Decisões:
- **Ano do planejamento no topo da aba**, com o ano passado até dois anos à frente e "✓ meta" nos anos que já têm meta. O ano padrão passa a ser o ano corrente (não mais fixo em 2026). As metas mês a mês acompanham o ano escolhido.
- De outubro em diante, o ano corrente mostra "O ano está acabando: planeje o próximo".
- **Ano novo vazio**: "Montar a meta" ou "Começar com as premissas do ano anterior" (traz caminho, imposto, cenários e números digitados; o que vem do sistema é recalculado). Revisa nos quatro passos antes de salvar; o ano anterior não muda.
- **Excluir a meta** do ano (as metas mês a mês, as campanhas e o calendário ficam).
- **Receita do ano anterior**: planejando 2027 com 2026 ainda aberto, o sistema usa os últimos 12 meses fechados e diz isso na premissa.
- **Por que 2026 só mostrou meta no T4 (fato, não erro)**: na meta de 2026, os meses que já fecharam ficam com o realizado e o resto da meta vai para os meses que faltam; montada em novembro, quase tudo cai em out–dez. Para 2026, o uso é acompanhar; o planejamento de verdade é o de 2027.

## v0.199 — Editar a meta em quatro passos, impostos e lucro final
**Pedido da Rebecka (01/11)**, ao testar a v0.198: a tela de editar era extensa (dividir em passos, como a nova campanha); considerar o regime tributário; entender se o resultado de (custos fixos + lucro) ÷ margem é o lucro que sobra; e qual o lucro final. Ela aprovou a proposta ("pode").
Decisões:
- **Editar a meta** vira quatro passos com Voltar e Continuar: 1. Caminho, 2. Premissas, 3. Impostos, 4. Cenários e lucro. Salvar só no último, com o resumo do faturamento ao lucro ao vivo.
- **Correção da margem (fato)**: na v0.198 as comissões (6.2.03) estavam nos custos fixos, mas elas acompanham cada venda. Agora a margem não é premissa: sai de faturamento − impostos − custos variáveis (taxas de plataforma, comissões, entrega). Os custos fixos do sistema não contam mídia paga (6.1) nem comissões.
- **Impostos pelo regime**, que vem do cadastro da empresa (dá para mudar no passo 3): MEI (DAS fixo × 12, avisa acima do limite); Simples Nacional com a alíquota efetiva da faixa, anexo III ou V pelo fator R (folha ÷ faturamento, 28%); Lucro Presumido de serviços (PIS 0,65 + COFINS 3 + IRPJ 4,8 + CSLL 2,88 + ISS, mais o adicional de 10% do IRPJ acima de R$ 240 mil de lucro presumido no ano); Lucro Real (PIS e COFINS 9,25% sem créditos + ISS sobre o faturamento e 34% de IRPJ e CSLL sobre o lucro); ou alíquota manual.
- A meta pela ambição agora é o faturamento em que, **depois** de impostos, custos variáveis, custos fixos (e do IR, no Lucro Real), sobra o lucro desejado. Ou seja: o lucro digitado é o lucro final.
- Cada cenário mostra o lucro no fim; "Meta menor" mostra o lucro do realista.
- **Hipótese**: as alíquotas são para planejamento; Lucro Real sem créditos de PIS/COFINS fica conservador. A tela pede para confirmar com o contador.
- Fica para a etapa 4: KPIs por ritmo (mês, trimestre, ano).

## v0.198 — Planejamento anual, etapa 1: meta do ano e trimestres
**Pedido da Rebecka (01/11)**: melhorar o Planejamento anual com um método validado (meta de faturamento, divisão por trimestre, campanhas, verba). Desenho no documento "Planejamento anual no Growths: desenho das telas". Ela apontou que o cliente chega sem dados: o sistema traz as contas, deixa escolher o caminho e de onde vem cada número, e no ano seguinte calcula pelo ano anterior.
Decisões (com as recomendações do documento, que ela aprovou ao pedir para fazer):
- A aba **Marketing › Campanhas › Planejamento anual** vira o painel do ano em seções: 1. Meta do ano, 2. Por trimestre, 3. Calendário de campanhas (o que já existia), e o detalhe Metas mês a mês.
- **Caminho da meta**: só pela ambição (lucro: (custos fixos + lucro) ÷ margem; ou crescimento sobre o ano anterior), só pelo realista (base recorrente × 12 menos metade da perda + clientes × recompra × ticket + metas das campanhas do ano) ou as duas comparadas, com a diferença e três saídas (mais campanhas, mais vendas, meta menor).
- **Cada premissa**: do sistema (só quando o Growths tem o dado; com o período), digitada ou "não sei, me ajude" (pergunta simples que calcula; fica marcada como estimativa). Sem dado, "sem dado", nunca zero inventado. A tela avisa quantas premissas são estimativa.
- **Do sistema**: margem de contribuição = (receita − deduções) ÷ receita e custos fixos = despesas fora de mídia paga (contas 6.1), ambos da DRE dos últimos 12 meses fechados (custos levados ao ano pela média do mês); receita do ano anterior, clientes, recompra e ticket pelas vendas aprovadas; recorrência e perda pelos contratos recorrentes.
- **Cenários**: pessimista e otimista em % sobre a base (você define; vem 20%); você escolhe qual vira a meta (vem o base).
- **Trimestres**: meta e realizado com o ritmo do trimestre em curso; a sugestão mês a mês deixa os meses que já fecharam com o realizado e, nos outros, põe as campanhas, a base e a recompra, e o resto pela sazonalidade das vendas (com 6 meses ou mais; se não, igual). "Preencher os meses sem meta" e "Refazer todos pela sugestão" gravam só a meta de receita das metas mensais; quem digitou um mês continua mandando nele.
- Próximas etapas: funil reverso por campanha (etapa 2), verba de marketing (etapa 3), prioridades do trimestre e índices (etapa 4).

## v0.197 — Pesquisas: editar, excluir e modelos
**Pedido da Rebecka (01/11)**: poder excluir um modelo; depois de criar a pesquisa, editar ou excluir ("tô sentindo falta disso").
Fato: editar e excluir a pesquisa já existiam, mas escondidos (botão Configurar no topo da pesquisa; Excluir só dentro do formulário).
Decisões:
- Lista de pesquisas: **Editar** e **Excluir** em cada linha (clicar no resto da linha continua abrindo a pesquisa).
- Topo da pesquisa: "Configurar" vira **Editar pesquisa**, e há **Excluir**.
- Excluir avisa o que vai junto (respostas e envios da fila, que o banco apaga junto) e as campanhas que usam a pesquisa (elas ficam sem pesquisa). Sugere desativar, se a ideia for só parar de receber respostas.
- Modelos: botão **Modelos** ao lado de "Começar de um modelo" lista os prontos, com **Usar** e **Excluir da lista**; o modelo sai da lista deste cliente e pode voltar com **Mostrar de novo**. Os modelos vêm do código, então "excluir" esconde; as pesquisas já criadas a partir dele não mudam.
- Pendente: rodar `RODAR_v0.197_pesquisa_modelos.sql` em produção para a escolha valer para toda a equipe.

## v0.196 — Mapa: ligar por qualquer lado do bloco
**Pedido da Rebecka (01/11)**: a bolinha de ligação em cima, embaixo, à esquerda e à direita, para conectar por todos os lados e mais de uma vez se precisar.
Decisões:
- Cada bloco tem quatro bolinhas. A da direita fica sempre à vista (como antes); as outras aparecem ao passar o mouse, com o bloco selecionado ou durante uma ligação.
- A ligação sai pelo lado da bolinha arrastada e chega pelo lado do outro bloco mais perto de onde ela foi solta.
- Os mesmos dois blocos podem ter mais de uma ligação, desde que por lados diferentes.
- No painel da ligação, **Sai por** e **Chega por** (Automático, Direita, Esquerda, Em cima, Embaixo) trocam os lados depois.
- Ligações de antes (sem lado escolhido) seguem a posição dos blocos: destino à direita, sai pela direita e chega pela esquerda (como sempre); destino à esquerda, o contrário; destino embaixo ou em cima, sai e chega pelo meio de baixo ou de cima.
- Sem mudança no banco: o lado fica em `props.lados` do bloco de origem ({ id da ligação: { de, para } }).

## v0.195 — Mapa da estratégia: order bump, downsell, tela cheia, edição rápida; menu Customer Success
**Pedido da Rebecka (31/10)**: no mapa (Canvas) da estratégia faltavam downsell e order bump, era ruim aumentar a tela e ruim mudar o nome da condição. E o menu RevOps passa a se chamar Customer Success.
Decisões:
- **Order bump** e **Downsell** viram blocos com métricas próprias (manuais, da plataforma de venda): order bump = aceitos (principal), receita e taxa de aceite; downsell = vendas do downsell (principal), receita e quantos receberam a oferta. Na biblioteca ficam em Conversão, logo depois do Checkout; o Downsell aparece também em Pós-venda. Desenho: order bump como checkout, downsell como página de oferta. Não somam em clientes novos nem na receita do funil, para não contar duas vezes a venda principal.
- **Tela cheia** no mapa (botão na barra; Esc fecha), zoom dos botões + e − a partir do centro da tela e o percentual do zoom à vista. A alça de tamanho do bloco ficou maior.
- **Dois cliques no nome de um bloco** (Condição, Decisão, qualquer um) editam o nome ali mesmo: Enter salva, Esc cancela; as métricas do bloco são renomeadas junto, como no painel. **Dois cliques numa seta** abrem tipo, rótulo e condição da ligação.
- **Menu**: "RevOps" → **"Customer Success"** (título da tela, metas e textos que citavam RevOps). Por dentro o módulo continua `revops`, então permissões, pacotes de acesso e telas liberadas não mudam.

## v0.194 — Campos de formulário mais legíveis
**Pedido da Rebecka (31/10)**: o nome do campo e o que está dentro dele estavam iguais (mesma cor e peso), e a caixa de preencher não tinha uma borda visível. Exemplo: "Nome" e o exemplo dentro do campo, na nova campanha.
Decisões (vale para todos os formulários do sistema, menos o formulário público da pesquisa, que tem a identidade visual do cliente):
- **Nome do campo** em negrito (600), na cor do texto principal, um pouco maior (12,5 px). Antes era cinza claro, peso 500.
- **Caixa de preencher** com borda bem visível (cor do texto a 28%, mais forte ao passar o mouse), leve sombra interna e o texto digitado na cor principal (antes herdava o cinza do rótulo).
- **Exemplo dentro do campo** (placeholder) em itálico e mais claro, para não ser confundido com um valor preenchido.
- Campo desativado ou só de leitura: fundo diferente e borda tracejada.
- Caixas de marcar e opções continuam com peso normal.

## v0.193 — Pesquisa na campanha
**Pedido da Rebecka (31/10)**: ao criar a campanha, dizer se vai usar pesquisa, escolher qual (um modelo pronto ou uma nova) e onde ela entra: na captação, na página de obrigado (com o código HTML para colar) ou em disparo. Para o disparo, "tenho que criar um processo para automatizar… não sei o que a gente pode fazer".
Decisões:
- Nova campanha ganhou o passo 4, **Pesquisa**: usar ou não; qual (pesquisas que já existem, criar de um modelo pronto ou nova em branco); onde entra (captação, página de obrigado, disparo); no disparo, quando (logo depois do cadastro, ao entrar numa etapa do funil, ou eu escolho) e por onde (WhatsApp, e-mail, só o link). O mesmo bloco fica em **Configurar** no painel "Pesquisa da campanha" (aba Planejamento e metas).
- Pesquisa criada de modelo nasce **desativada**, com o nome do modelo e da campanha; o painel avisa até ela ser ativada.
- Página de obrigado: o Growths gera o código (iframe com o link aberto, a campanha e utm_medium=obrigado). A página da pesquisa, dentro do iframe, avisa a altura do conteúdo e o iframe se ajusta. Quem responde é ligado ao lead pelo e-mail (regra do link aberto).
- Captação: link de inscrição por canal da campanha, com utm_source, utm_medium (pago/orgânico) e o utm_campaign do canal.
- **Disparo automático: ainda não decidido** (Rebecka, 31/10). Por enquanto o Growths coloca os leads da campanha na fila da pesquisa (botão "Colocar N leads na fila", usa `pesquisa_enviar_para`) e o envio é pelo botão da fila. A escolha de quando e por onde fica gravada para o disparo usar depois.
- Opções levantadas para o disparo: (A) o Growths envia pelo WhatsApp do Atendimento com um agendador; (B) o Growths avisa e o n8n envia (e-mail ou a ferramenta atual); (C) semiautomático, como está agora.
- Sem mudança no banco: a escolha fica em `campanhas.extras.pesquisa`.

## v0.192 — Dashboards em seções
**Pedido da Rebecka (31/10)**: o Dashboard do Administrativo "parece um relatório de Word": evolução e meta, de onde vem a receita, clientes novos e existentes, produto e campanha não ficam delimitados, e não se vê onde termina uma informação e começa outra. Acontece em quase todos os dashboards.
Decisões:
- Cada dashboard é dividido em **seções com moldura**: fundo próprio, borda, uma faixa de cor à esquerda e um título com a pergunta que a seção responde. Os quadros (brancos) ficam dentro da seção (fundo tingido), então a separação entre uma informação e outra é visível.
- **Dashboard (Administrativo):** Visão geral · Alertas · Evolução e meta · De onde vem a receita · Saúde financeira · Funil e campanhas · Tabelas completas.
- **Dashboard financeiro:** Visão geral · Resultado do período · Resultado e despesas · Caixa e bancos · Próximos vencimentos.
- **Dashboard de Vendas:** Visão geral · Metas e renovações · Cadastros e funil · De onde vêm os clientes · Cadastros recentes.
- Só muda a disposição: quadros, dados, frases e cliques são os mesmos. Os rótulos soltos de antes ("O que importa agora", "Funil, vendas e contas"...) saem, porque a seção já tem título.
- No celular, cada quadro ocupa a largura da seção, um embaixo do outro.
- Pendente: levar o mesmo padrão para os outros dashboards (Marketing, Mídia, Retenção, Customer Growth, Growth's Content, Projetos) depois que a Rebecka aprovar estes três.

## v0.191 — Pagar e receber várias contas de uma vez
**Pedido da Rebecka (31/10)**: em Contas a pagar e Contas a receber, um quadradinho de seleção para escolher as contas que quiser e pagar (ou receber) todas de uma vez.
Decisões técnicas:
- Sem função nova no banco: cada conta selecionada passa pela mesma função da baixa de uma por uma (`registrar_pagamento` / `registrar_recebimento`). Lançamentos, movimentação no banco, DRE e fluxo de caixa ficam iguais aos da baixa individual. Assim a versão não depende de rodar SQL em produção.
- A baixa em lote é sempre pelo valor inteiro. Baixa parcial continua no botão da própria conta.
- Conta a pagar **estimada** aparece com o quadradinho desligado: o valor real precisa ser confirmado antes de pagar.
- Conta bancária: uma para todas, ou "a de cada conta (ou a padrão)": na conta a pagar, a da forma de pagamento; na conta a receber, a que já está na parcela; sem nenhuma, a conta padrão. No contas a receber, cartão de crédito não aparece.
- Se alguma conta não puder ser baixada, as outras seguem e o aviso diz qual falhou e por quê.
- Também vale para Casa (contas a pagar e a receber da Casa usam as mesmas telas).
- Pendência registrada: o plano da NSM no Growths está no documento "NSM no Growths: onde cadastrar e como configurar" (decididos em 31/10: NSM da empresa como principal, com ficha por produto opcional; must-have baixo só avisa; aprovam a equipe interna e o dono da conta do cliente). Faltam as decisões sobre "Receita bruta" como North Star padrão e o lugar da tela no menu.

## v0.161 — Pesquisa must-have da consultoria
**Pedido da Rebecka (26/10)**: um formulário para saber se a consultoria de desenvolvimento de produto (pesquisa, construção do produto, narrativa, página de vendas e desenho da estratégia de venda, que a cliente não executou) é must-have, feito dentro do módulo de Pesquisas e com base no que já estava definido no Drive ("03 - Roteiro de Diagnóstico - Must-Have ao Aha e North Star").
Decisões técnicas:
- Novo modelo em Pesquisas → "Começar de um modelo": "Must-have: consultoria de desenvolvimento de produto", 25 perguntas em 6 passos (o essencial, cada entrega, o valor sentido, a estratégia de venda, indicação e melhoria, próximos passos). Criada desativada e manual, como os outros modelos.
- A grade "quanto valeu cada entrega" virou uma pergunta por entrega (o módulo não tem pergunta em grade).
- Resultados: a pergunta de papel PMF passa a mostrar as três faixas do roteiro (40% ou mais, 25% a 40%, menos de 25%) com a ação sugerida, e tira "Não se aplica" da base, como no método original. Vale para todas as pesquisas com pergunta PMF.
- O mesmo questionário ficou também no documento "Pesquisa must-have: consultoria de desenvolvimento de produto" (com a tabela de leitura e o roteiro da conversa de 20 minutos).

## v0.160 — Kanban com calendário na Produção, linha editorial e subtemas
**Pedido da Rebecka (26/10)**: manter o Kanban com as datas e o calendário (onde ela vê o que publica quando), com os aprovados e os pendentes de aprovação; a aprovação da v0.159 "está ótima, só precisa cair nesse Kanban"; na configuração inicial, cadastrar a linha editorial, os temas, os formatos e, se quiser, subtemas, para os conteúdos nascerem segmentados e os relatórios saírem por eles.
Decisões técnicas:
- Seis abas: Base do cliente, Linha editorial, Identidade visual, Ideias, Produção, Mais ferramentas. A Produção é o Kanban de antes (painel, calendário das próximas semanas, seis colunas, filtros); cada cartão mostra o que falta aprovar e tem o botão "Roteiro e peça", que abre a aprovação da v0.159. O quadro de 4 colunas da v0.159 saiu.
- Linha editorial é a tela de antes (territórios, frentes/temas, formatos, quadros, método), com os painéis novos de subtemas e de conteúdos por linha, tema, subtema e formato.
- Subtema = tema com `tema_pai_id` (dois níveis), herda a linha do tema. O nome continua único no cliente (para não confundir as importações que procuram o tema pelo nome). Se uma importação apontar um subtema como tema, o banco o põe no lugar certo.
- Aprovar a ideia abre um formulário com linha e tema, subtema, formato, tipo de mídia, prazo e data de publicação (tema e data obrigatórios, também no banco).
- Método "simples" ganha opção no Método e configuração e é o padrão sem configuração; os cartões não mostram "sem nota".
Pendências: aplicar os três SQL em produção; crédito na API para ligar a Claude.

## v0.159 — Growth's Content simplificado
**Pedido da Rebecka (26/10)**: o módulo de conteúdo ficou complexo; partir do dossiê pronto, identidade visual por cliente e produção pedida e aprovada no Growths (documento "Growth's Content: dossiê, identidade visual e produção pela Claude"). Sem crédito na API por enquanto: "vamos parar por aqui e só ajustar as telas e o processo no Growth".
Decisões técnicas:
- Cinco abas na ordem do trabalho: Base do cliente, Identidade visual, Ideias, Produção, Mais ferramentas. As 11 abas antigas ficam em Mais ferramentas (nada foi apagado).
- A configuração em 9 passos deixa de travar o módulo; a pasta do Drive fica em Base do cliente. Quem não tem dossiê abre a configuração guiada por um botão na Base do cliente (call de briefing, materiais, pesquisa e dossiê continuam lá).
- As abas antigas guardam o próprio nome (o código de antes continua mandando para "plano", "kanban"…) e aparecem dentro de Mais ferramentas.
- Ficha com versões: mudar a ficha aprovada cria a versão seguinte em rascunho; a aprovada continua valendo até a nova ser aprovada.
- Método "simples" (novo padrão): sem notas de ideia e pauta; o banco exige roteiro aprovado para ir à Peça e peça aprovada para ficar Pronta. Notas5 e score6 continuam para quem escolher. A configuração existente em produção passa para "simples" ao rodar o SQL.
- Arquivos ficam na pasta do cliente no Drive; o Growths guarda os links (vídeo bruto, versões, capa). Versão nova substitui a anterior sem apagar.
- Botões da Claude aparecem desligados, com o motivo (sem crédito na API).
Pendências: crédito na API; ligar a Claude (ficha pelo dossiê, ideias, roteiro, arte, capa, vídeo) conforme o plano; aplicar `RODAR_v0.159_content_simples.sql` e `RODAR_v0.157_narrativas.sql`.

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
