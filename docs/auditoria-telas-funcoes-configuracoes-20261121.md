# Auditoria de telas, funções e configurações — 21/11/2026

## Andamento em 22/11/2026

A `main` local foi alinhada por fast-forward a `21c1ef5`, preservando as alterações sem commit que já existiam. O commit `985845a` desta rodada já aparece na `main` do GitHub. O texto abaixo registra o estado encontrado em 21/11; os pontos tratados estão listados aqui para não confundir a leitura histórica com o estado atual.

- Estratégias tem rota canônica em Marketing, com compatibilidade para `cad-funis` e preservação do acesso de quem usa somente Cadastros. Os painéis de etapas do Kanban e listas continuam disponíveis em “Configurações da estratégia”. O atalho da campanha foi atualizado.
- “Entrada de leads” e “Agentes de sistema” ganharam telas próprias em Configurações. Integrações mantém cartões que levam a elas. Agentes de sistema continua restrita a administrador interno.
- “Campanhas de grupos” ganhou uma tela própria em Atendimento → Envios. A tela “Grupos” ficou com configuração do disparo, criação, agendados e histórico. O rascunho da seleção é compartilhado entre as duas telas.
- O detalhe de campanhas de marketing organiza as abas em Planejamento, Operação, Resultados e Fechamento, mantendo os IDs internos e seus atalhos. Campanhas de lançamento elegíveis continuam abrindo inicialmente o canvas “Visão por etapas”.
- A DM histórica agora busca a conversa correspondente no Atendimento tanto por `externo_id` quanto por `endereco`, e oferece um atalho quando a encontra. Havendo mais de uma correspondência, exige escolher qual abrir.

Consulta agregada ao banco em 22/11: há 161 conversas e 4.235 mensagens em `social_*` para Instagram; em `atd_*`, 89 conversas e 622 mensagens. Todas as 89 conversas do Atendimento correspondem a uma conversa social ao usar as duas chaves. Elas apontam para 88 conversas sociais distintas, pois uma tem duas conversas no Atendimento. Outras 73 conversas sociais só existem no histórico antigo; nenhuma teve atividade nos últimos 30 dias (a mais recente foi em 14/10/2026). Das 622 mensagens do Atendimento, 621 compartilham `id_externo` com mensagens sociais, portanto uma cópia direta criaria duplicatas. A análise inicial encontrou 72 conversas do Atendimento sem `pessoa_id` que poderiam herdar um vínculo inequívoco do histórico social, sem conflito observado.

O SQL de `20270204100000_atendimento_instagram_vinculo_pessoa.sql` foi executado no banco: as conversas do Atendimento com `pessoa_id` passaram de 1 para 73. A Edge única de Atendimento, com busca do vínculo social ao abrir uma DM Instagram sem pessoa associada, também está publicada (versão 63). O SQL foi executado diretamente; seu nome não consta no histórico de migrations do Supabase.

Na etapa seguinte, a análise confirmou que as 73 DMs que só existem em `social_*` guardam 1.509 mensagens; 66 mensagens registram anexos apenas como contagem, sem arquivo recuperável nessa tabela. A interface local agora oferece um arquivo de DMs dentro de Conversas, com consulta paginada e atalho de volta à conversa operacional. A única duplicação em `atd_*` tem 83 mensagens na conversa principal e 3 mensagens distintas na secundária, sem agendamentos ou outras referências; `20270205100000_atendimento_instagram_conversa_duplicada.sql` foi preparada para mover essas 3 mensagens e arquivar a secundária, sem apagar registros. Esta segunda migration ainda não foi aplicada.

**Pendente antes de encerrar a unificação das DMs:** aplicar e conferir a consolidação da conversa duplicada, testar o arquivo de DMs e os atalhos em sessão autenticada, e investigar se os 66 anexos do legado podem ser recuperados pela origem. O histórico social foi preservado.

## Escopo e estado do repositório

Esta revisão atualiza `auditoria-navegacao-unificar-separar.md` e sua contraposição. Conferi estaticamente o menu, o registro e o despachante de telas, as rotas de Atendimento, os principais atalhos e as configurações citadas na auditoria anterior. Não executei telas autenticadas nem consultei dados de clientes.

A `main` local está seis commits atrás de `origin/main`. Há trabalho local sem commit em `index.html`, `assets/atendimento.js`, `assets/atendimento.css` e na Edge de Atendimento. Não fiz pull, commit ou alterações na aplicação. Os seis commits remotos tratam principalmente de análise de uso; também removem um redirecionamento indevido de `adm-plano`. Esta auditoria considera o código local e assinala essa correção já presente no remoto.

O menu local tem 108 entradas, correspondentes a 99 IDs distintos. Todos os IDs têm uma função registrada ou cadastro genérico, exceto as dez rotas `casa-*`, que são resolvidas pelo `CASA_MAP` de propósito (`index.html:11085`). Esta contagem prova cobertura do despachante, não que cada tela funcione em execução.

## Achados prioritários

| Prioridade | Área | Achado e evidência | Encaminhamento |
| --- | --- | --- | --- |
| Alta | Administrativo | `adm-plano` é registrado como plano anual, mas uma atribuição posterior o redireciona para `mkt-camp` (`index.html:1904`, `19592-19594`). O remoto já removeu a segunda atribuição. | Incorporar a correção remota após reconciliar o `index.html` local; testar a entrada e o botão Voltar. |
| Alta | Estratégias | `Marketing > Estratégias (Canvas)` e `Configurações > Estratégias e funis` chamam `vFunis` e editam os mesmos funis (`index.html:1452`, `1463`, `1905`, `11729-11755`). Os painéis de Kanban e listas só aparecem no caminho de Configurações. O botão `Cadastrar estratégia` da campanha ainda abre `cad-funis` (`index.html:11876`). | Uma lista canônica de estratégias, com os painéis preservados e rota antiga compatível. Trocar o atalho da campanha. |
| Alta | Permissões de Estratégias | A contraposição anterior tratou o risco de acesso como resolvido pela exceção em `telaLiberada` (`index.html:13282`), mas `render` também exige `nivelMod(moduloDaView(S.view))` (`index.html:1966`). `mkt-estrategias` pertence ao módulo `mkt`, e `cad-funis` ao `cad` (`index.html:1841`). Um usuário com apenas `cad` pode perder acesso se houver redirecionamento simples para Marketing; um usuário de Marketing pode ser barrado pelo atalho atual para `cad-funis`. | Testar perfis `mkt` sem `cad` e `cad` sem `mkt`; decidir explicitamente o acesso da rota canônica antes de retirar o item antigo. |
| Alta | Instagram DM | Vendas e Growth's Content usam `social_conversas` e `social_mensagens` (`index.html:22905-22944`); Atendimento usa `atd_conversas`, `atd_mensagens` e seus canais Zernio (`assets/atendimento.js:71-95`, `421-438`). A interface de Vendas ainda informa que as mesmas DMs aparecem em Conteúdo, sem citar Atendimento. | Comparar contas, conversas e mensagens por workspace nas duas bases; definir a fonte operacional e preservar histórico antes de unificar os atalhos. Não há prova nesta revisão de perda ou duplicação real. |
| Média | Integrações e canais | `Configurações > Integrações` e `Atendimento > Canais e conexões` ainda repartem a configuração de mensageria. Atendimento altera botões e intercepta ações da tela antiga (`assets/atendimento.js:1254` em diante); não é um fluxo único de origem. | Definir uma tela canônica para conta, instância, QR e credenciais, com atalhos contextuais e permissão de administrador separada da operação diária. |
| Média | Campanhas de grupos | `Envios > Grupos` ainda combina gestão de grupos e disparo nas cinco etapas `Campanhas`, `Configuração`, `Criação`, `Agendado`, `Histórico` (`assets/atendimento.js:1124-1160`). | Dar destino próprio à gestão de campanhas de grupos; manter o disparo agendado e a seleção salvos. Diferenciar “campanha de grupos” de “campanha de marketing”. |
| Média | Configurações extensas | Scripts e webhooks de entrada de leads e gestão de agentes externos/Frank continuam embutidos em `Configurações > Integrações` (`index.html:7828-7839`, `7887-7902`). São trabalhos com públicos, permissões e ciclos diferentes. | Rotas próprias para `Entrada de leads` e `Agentes de sistema`, com cartões de estado e acesso em Integrações. Preservar a restrição interna de tokens. |

## Pontos resolvidos desde a auditoria anterior

- A automação de e-mail tem rota própria `atd-auto-email`, ligada a `vEmailAutomacoes`; WhatsApp, Instagram e WhatsApp Oficial têm rotas filhas próprias (`assets/atendimento.js:1247-1253`). A recomendação antiga S1 está implementada na navegação.
- Envios também têm rotas distintas para WhatsApp, e-mail, WhatsApp Oficial e grupos. WhatsApp usa a audiência de contatos; Grupos usa a audiência de grupos, embora ambas reutilizem `vDisparoGrupos` (`assets/atendimento.js:1099-1110`). Não tratar essa reutilização de código como duplicação de produto.
- A lista geral de rotas do menu não mostrou destino ausente no despachante. Isso não substitui testes dos botões e dos dados dentro de cada tela.

## Organização e nomes

- `Marketing > Campanhas e planejamento` contém 14 abas no detalhe (`CAMP_TABS`, `index.html:2681`). Agrupar visualmente em Planejamento, Operação, Resultados e Fechamento, mantendo os IDs internos, que já são usados por atalhos como `crm`, `resumo`, `links` e `etapas` (`index.html:2072`, `3766`, `3847`, `11827`).
- `Vendas > Comissões` e `Configurações > Comercial e produtos > Comissões` mostram contextos diferentes da mesma função; renomear a segunda para `Regras de comissão`, sem fundir as telas (`index.html:1903`).
- `Configurações > Comercial e produtos > Canais` é classificação de aquisição; `Atendimento > Canais e conexões` é mensageria. Renomear o primeiro para `Canais de aquisição` (`index.html:1463`, `assets/atendimento.js:1247`).
- `Atendimento > Contatos`, `Configurações > Clientes` e `Customer Success > Alunos` são perspectivas distintas sobre pessoas. Melhorar a identificação do registro e os atalhos, sem fundir listas só pelo nome.
- A nova tela remota `Administrativo > Uso do Growths pelos clientes` agrega a carteira; `Configurações > Uso da plataforma` detalha um workspace. Devem manter nomes que indiquem o escopo, pois têm funções distintas. Essa tela remota ainda não está na cópia local.
- Todo Atendimento herda o módulo `vendas` no menu (`assets/atendimento.js:1250`); não há permissão de módulo específica para Atendimento. Verificar isso antes de oferecer um perfil “somente atendimento”.

## Verificações necessárias antes de alterar rotas

1. Entrar com quatro perfis: administrador interno, Marketing sem Cadastros, Cadastros sem Marketing e cliente com apenas o pacote de Atendimento. Conferir menu, URL direta, recarga, Voltar e edição.
2. No Instagram, comparar `social_*` com `atd_*` por conta e período, inclusive anexos e vínculo com a pessoa. A análise estática não confirma se os dois pipelines estão ativos simultaneamente.
3. Testar ações de conexão Evolution/Zernio, QR, foto, status e desconexão antes de remover qualquer controle antigo de Integrações.
4. Em disparos, conferir rascunho, campanha selecionada, destinatários e filas já agendadas ao mover a gestão dos grupos.
5. Reconciliar os seis commits remotos e o `index.html` local antes de qualquer publicação. A correção de `adm-plano` já existe no remoto e não deve ser sobrescrita.
