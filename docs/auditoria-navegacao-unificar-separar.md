# Auditoria da navegação: unificar telas e dar espaço próprio a funções

**Estado da análise:** proposta para revisão por outra LLM. Não é uma especificação aprovada nem autoriza alterar a interface.

## Objetivo e escopo

Avaliar dois pontos da navegação do Growths:

1. **Unificação:** entradas da sidebar ou abas que mostram a mesma entidade, o mesmo fluxo ou a mesma configuração, gerando dúvida sobre onde trabalhar.
2. **Separação:** funções com objetivos e ciclos de trabalho diferentes que hoje estão escondidas dentro de uma tela ampla e merecem rota ou área própria.

A análise foi estática, baseada na `main` local de 13/11/2026, principalmente em `index.html` e `assets/atendimento.js`. Não houve teste autenticado de todas as telas nem validação dos dados e permissões em cada workspace. Há alterações locais pré-existentes, ainda sem commit, na Automação de Atendimento; este documento não as modifica. Antes de implementar, comparar novamente a `main` local e remota e revisar o diff do `index.html`, pois há trabalho paralelo no projeto.

## Mapa atual relevante

O menu principal é definido em `index.html:1448-1464`. O módulo de Atendimento injeta seu grupo na sidebar em `assets/atendimento.js:1122-1127`. O despachante de telas está em `index.html:1900-1905`, com registros complementares no próprio `index.html` e em `assets/atendimento.js`. O acesso por módulo e por tela é verificado em `index.html:1830-1840` e `index.html:13278-13284`.

Ao analisar uma unificação, distinguir **mesma função** de **mesmo nome**. Por exemplo, as duas entradas de Comissões usam a mesma função JavaScript, mas uma mostra regras e outra mostra extrato; isso não implica duplicação de produto.

## Ponto 1 — Telas que podem ser unificadas

### U1. Estratégias em Marketing e Configurações — prioridade alta

**Entradas atuais:** `Marketing > Estratégias (Canvas)` (`mkt-estrategias`) e `Configurações > Comercial e produtos > Estratégias e funis` (`cad-funis`).

**Evidência:** ambas apontam para `vFunis` (`index.html:1904`). Essa função consulta `funis`, `estrategia_etapas`, `campanhas` e `produtos` para a mesma lista e abre o mesmo editor (`index.html:11729-11751`). A diferença é `noMkt`: na entrada de Configurações, são adicionados os painéis `etapas_funil` e `listas_funil` abaixo da lista (`index.html:11743` e `11752-11755`).

**Problema:** editar uma estratégia em qualquer entrada altera o mesmo registro, mas os títulos sugerem módulos distintos. Os painéis extras fazem parecer que Configurações é a tela “completa”, incentivando dois caminhos para a mesma operação.

**Proposta:** uma entrada canônica `Marketing > Estratégias`. No detalhe da estratégia, preservar Resumo, Mapa e Lista. Mover os cadastros extras para uma seção identificada como `Configurações da estratégia` ou, se são cadastros globais, para itens com nomes específicos em Configurações: `Etapas do Kanban` e `Listas de grupos/API`. Manter um redirecionamento de `cad-funis` para a rota canônica para não quebrar links antigos.

**Risco a investigar:** os dois IDs podem ter permissões de módulo diferentes. `telaLiberada` já possui uma exceção para `mkt-estrategias` (`index.html:13280`), mas `moduloDaView` ainda encontra essa tela no grupo Marketing (`index.html:1840`). Confirmar cenários em que o usuário possui apenas acesso a Cadastros antes de remover a entrada antiga.

**Critérios de aceite sugeridos:** uma única lista e um único botão de criação; os cadastros extras continuam acessíveis conforme a permissão; campanha e produto ainda conseguem abrir a estratégia; links antigos chegam ao mesmo registro; nenhuma estratégia ou etapa é copiada ou perdida.

### U2. Operação de DMs do Instagram — prioridade média

**Entradas atuais:** `Vendas > DMs do Instagram`, `Atendimento > Conversas` e DMs em `Marketing > Growth's Content > Instagram`.

**Evidência:** a tela de Vendas usa `vDMsCrm` (`index.html:22926`), com histórico em modal consultando `social_mensagens` (`index.html:22916-22924`). Atendimento usa `atd-conversas` e a central multicanal (`assets/atendimento.js:61` e `1127`). O módulo de conteúdo possui uma aba `DMs` em `MQ_CANAL` (`index.html:22938-22950`).

**Problema:** o usuário encontra três caminhos com aparências e capacidades diferentes para o mesmo canal. A existência de armazenamento e sincronização diferentes precisa ser apurada; não assumir que os registros já estejam unificados.

**Proposta:** definir `Atendimento > Conversas` como local para responder e consultar o histórico operacional. Preservar em Vendas e Marketing apenas indicadores específicos de vendas/conteúdo, com botão `Abrir conversa` que resolva o contato e a conversa correta. Se a tela de Vendas for essencial como relatório, renomeá-la para `Análise de DMs`.

**Dependências:** mapear `social_conversas/social_mensagens` versus `atd_conversas/atd_mensagens`; conferir identidade do contato, permissões, histórico legado e deduplicação. Não remover a tela antiga antes de garantir acesso ao histórico.

**Critérios de aceite sugeridos:** um destino operacional para responder; atalhos de Vendas e Marketing abrem o mesmo contato quando houver vínculo; históricos legados permanecem consultáveis; contagens dos relatórios não mudam inadvertidamente.

### U3. Configuração dos canais de mensagem — prioridade média

**Entradas atuais:** `Configurações > Dados e integrações > Integrações` e `Atendimento > Canais e conexões`.

**Evidência:** Integrações reúne diversos provedores (`index.html:7871-7902`). Atendimento possui uma tela própria de canais (`assets/atendimento.js:540`) e intercepta cliques de algumas ações da integração antiga (`assets/atendimento.js:1128-1135`).

**Problema:** conexão, configuração e operação de canais ficam distribuídas entre duas telas; a ponte de interceptação indica sobreposição técnica.

**Proposta:** escolher um único componente/fluxo para criar e administrar contas WhatsApp e Instagram. Permitir acesso contextual pelas duas áreas: em Integrações, `Configurar canal`; em Atendimento, `Ver conexão`, ambos abrindo o mesmo registro. Manter a operação diária, QR Code e estado do número onde forem mais úteis ao atendente.

**Riscos:** não remover opções da Evolution/Zernio sem verificar ações exclusivas (instância, QR compartilhável, foto/status, sincronização). Conferir permissões de quem administra credenciais versus quem apenas atende.

### Casos parecidos que não devem ser fundidos automaticamente

- `Vendas > Comissões` e `Configurações > Comercial e produtos > Comissões` compartilham `vComissoes`, mas a primeira mostra `Resumo do mês/Extrato` e a segunda `Regras/Quem recebe` (`index.html:15051-15077`). Renomear a entrada de Configurações para **Regras de comissão**; manter as duas funções.
- `Atendimento > Contatos`, `Configurações > Comercial e produtos > Clientes` e `Customer Success > Alunos` são visões de trabalho diferentes sobre pessoas. Preferir nomes claros e atalhos entre fichas antes de fundir listas.
- `Configurações > Comercial e produtos > Canais` é cadastro de classificação/origem (`index.html:6559`); `Atendimento > Canais e conexões` é conexão de mensageria. Renomear o primeiro para **Canais de aquisição**.
- `Marketing > Estratégia de conteúdo` e `Marketing > Instagram` compartilham o módulo de conteúdo, mas a segunda abre o canal filtrado (`index.html:22937-22950`). É um atalho contextual, não uma duplicação obrigatória de remover.
- `Projetos > Pipeline dos agentes` abre um projeto específico, criado/encontrado pela flag `pipeline_agentes` (`index.html:16964-16977`); não equivale à lista geral de Projetos.
- `Casa` mapeia telas financeiras/cadastrais para outro contexto (`index.html:11084`). Não fundir sem estudar a separação de workspaces.

## Ponto 2 — Funções que merecem área própria

### S1. Automações de e-mail — prioridade alta

**Situação atual:** `Atendimento > Automações` abre `vAutomacoes`. O botão `Automações de e-mail` chama diretamente `vEmailAutomacoes(m)`, sem trocar `S.view` nem registrar uma rota (`assets/atendimento.js:852-857` e `948-951`). Os fluxos de chat e e-mail têm editores e execuções diferentes.

**Problema:** a navegação não representa a subtela. Um `render()` ou atualização volta a desenhar a tela principal de chat. Links diretos, histórico do navegador, breadcrumbs e permissões específicas ficam difíceis.

**Proposta:** um grupo `Atendimento > Automações` com duas rotas filhas, `Chatbots` e `E-mail`. Pode ser submenu da sidebar ou abas persistentes com IDs de rota distintos. Preservar os fluxos já gravados e os links que chegam a `atd-automacoes`.

**Critérios de aceite sugeridos:** recarregar a página mantém a subtela; botão Voltar funciona; cada tela tem cabeçalho e estado próprios; permissões podem ser concedidas separadamente se necessário; nenhum fluxo é migrado ou duplicado sem motivo.

### S2. Gestão de campanhas de grupos — prioridade alta

**Situação atual:** `Atendimento > Disparos` contém cinco seções internas: `Campanhas`, `Configuração`, `Criação`, `Agendado`, `Histórico` (`assets/atendimento.js:979-1009`). A primeira gerencia conjuntos de grupos, convites, imagem e privacidade; as demais conduzem um envio.

**Problema:** administrar uma campanha de grupos é um ciclo de trabalho contínuo, enquanto configurar/criar/agendar um disparo é uma operação pontual. O nome “Campanha” também pode ser confundido com campanha de Marketing.

**Proposta:** `Atendimento > Campanhas de grupos` para criar/importar grupos, convite, nome, foto e privacidade. `Atendimento > Disparos` para selecionar a campanha ou contatos, compor, agendar e acompanhar. Dentro de Disparos, `Criar`, `Agendados` e `Histórico` podem continuar como abas. Deixar o rascunho de envio intacto durante a mudança de tela.

**Critérios de aceite sugeridos:** campanhas existentes e segmentos continuam acessíveis; um disparo programado permanece com os mesmos destinatários e horários; edição de grupos não altera retroativamente um disparo sem regra explícita; links de convite continuam válidos.

### S3. Entrada de leads — prioridade média

**Situação atual:** a página `Integrações` combina conexões Meta/Google, plataformas e bancos, agentes externos, scripts WordPress/Elementor, webhooks e um catálogo de ferramentas (`index.html:7886-7892`).

**Proposta:** subseção `Configurações > Entrada de leads` para script de tracking, webhook direto, exemplos de payload, mapeamento e testes de recebimento. Manter em `Integrações` um cartão-resumo com estado e botão de acesso. Evitar várias entradas de sidebar para cada fonte individual.

**Critérios de aceite sugeridos:** URLs, tokens e scripts existentes não mudam; copiar script e webhook ainda funciona; configurações são encontráveis pelo nome da função, não pelo nome do provedor.

### S4. Agentes de sistema — prioridade média

**Situação atual:** gestão do Frank e outros usuários externos é renderizada dentro de Integrações para administradores internos (`index.html:7827-7838` e `7889`). Envolve identidade, token e workspaces autorizados.

**Proposta:** `Configurações > Pessoas e acessos > Agentes de sistema`, mantendo um atalho ou estado resumido em Integrações. Não confundir esse usuário de integração com um membro humano da Equipe.

**Critérios de aceite sugeridos:** só perfis internos autorizados veem tokens e escopos; revogação funciona; a mudança de tela não altera a Edge nem os segredos existentes.

### S5. Detalhe de campanha — reorganizar internamente, sem nova entrada por aba

O detalhe de Marketing contém 14 abas (`CAMP_TABS`, `index.html:2680`), abrangendo estratégia, planejamento, captação, CRM, mídia, vídeo, links, vendas e fechamento. A quantidade é alta, mas essas funções pertencem à mesma campanha. **Não** criar 14 itens de sidebar.

Proposta de navegação de segundo nível:

| Área | Abas existentes a agrupar |
| --- | --- |
| Planejamento | Visão por etapas, Estratégia e etapas, Metas mensais, Planejamento e metas, Captação e metas, Ofertas e preços |
| Operação | Funil da campanha, Mídia paga, Vídeos e eventos, Links e tracking |
| Resultados | Dashboard, Análise e cohorts, Leads e vendas |
| Fechamento | Fechamento |

Conferir se `Visão por etapas` deve ser a visão geral fixa acima dos grupos. Preservar os identificadores das abas (`S.campTab`) para não quebrar atalhos internos, como os que abrem Links, Ofertas ou CRM diretamente.

### Funções que devem continuar como abas internas

- Pesquisas: Perguntas, Formulário, Qualificação, Respostas, Fila, Resultados e Insights fazem parte do ciclo da mesma pesquisa (`index.html:21210`). Melhorar o agrupamento e os rótulos antes de criar telas independentes.
- Produto: Jornada e Dados pertencem ao mesmo produto (`index.html:4506`).
- Estratégia: Resumo, Mapa e Lista são formas de ver o mesmo funil (`index.html:11803`).
- Comissões: Regras/Quem recebe e Resumo/Extrato são dois contextos de trabalho, já separados por entrada de menu (`index.html:15051-15077`).
- Instagram no módulo de conteúdo: Dashboard, Ideias e DMs são visões do mesmo canal (`index.html:22938-22950`); a operação de resposta a DM deve, porém, apontar para Atendimento.

## Requisitos transversais para qualquer mudança

1. **Preservar compatibilidade de rotas e atalhos.** Mapear todos os pontos que atribuem `S.view`, `S.campTab`, `S.estSel` e parâmetros equivalentes antes de retirar uma entrada.
2. **Separar navegação de permissão.** O menu usa tanto módulos (`MOD_GRUPO`, `moduloDaView`) quanto telas liberadas (`telaLiberada`). Uma tela movida de Marketing para Configurações, ou vice-versa, pode ficar invisível para clientes existentes.
3. **Não migrar dados por causa de uma mudança de menu.** Primeiro unificar a experiência e verificar se há bases distintas; só depois propor migração com plano de reconciliação.
4. **Manter links antigos.** IDs removidos da sidebar devem redirecionar para o destino canônico quando forem usados por um atalho ou URL salva.
5. **Respeitar trabalho paralelo.** Comparar `index.html` com a `main` remota imediatamente antes de qualquer alteração e não sobrescrever mudanças em Atendimento já em andamento.
6. **Testar por perfil.** Ao menos administrador interno, cliente com Marketing/Vendas, cliente apenas com Atendimento e Growth Starter; conferir sidebar, rota direta, Voltar, recarga e links entre fichas.

## Perguntas para a outra LLM responder

1. Quais unificações são realmente seguras sem conciliar bancos ou fluxos diferentes?
2. Qual deve ser a rota canônica de Estratégias, considerando acesso de clientes com permissões limitadas?
3. DMs do Instagram já convergem para a mesma conversa e o mesmo histórico? Se não, qual é o plano de transição sem perda de mensagens?
4. Onde devem ficar as credenciais de canais para separar administradores de atendentes?
5. Quais telas separadas exigem nova permissão e quais podem herdar a permissão atual?
6. A proposta de quatro áreas para o detalhe da campanha preserva todos os atalhos existentes?
7. Qual sequência de implementação tem menor risco para disparos agendados e automações em execução?

**Resultado esperado da próxima análise:** arquitetura de navegação proposta, matriz `tela atual → tela futura`, matriz de permissões, inventário de atalhos afetados, plano de transição para dados/rotas e critérios de teste. Não implementar antes de validar essas matrizes.
