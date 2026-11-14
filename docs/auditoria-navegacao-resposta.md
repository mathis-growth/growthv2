# Resposta à auditoria de navegação (unificar/separar)

**Em relação a:** `docs/auditoria-navegacao-unificar-separar.md`.
**Status:** análise de verificação, feita por outra LLM como o documento pediu. Ainda não autoriza implementar — só valida (ou corrige) as matrizes antes da próxima etapa.

## Como verifiquei

Antes de ler o código, comparei a `main` local com a remota: estava **3 commits atrás** (mudanças em Atendimento — e-mail, templates). Dei `git pull --ff-only` para alinhar. O próprio documento já está commitado na `main` remota.

Conferi no código atual cerca de 20 das referências de linha e função citadas no documento (`index.html`, `assets/atendimento.js`): menu principal, despachante de telas, `moduloDaView`, `telaLiberada`, `vFunis`/`cad-funis`/`mkt-estrategias`, `vComissoes`, `vDMsCrm`, `CAMP_TABS`, `pipeline_agentes`, `Casa`, a tela de Pesquisas, Jornada/Dados do produto, e as seções de Atendimento (Automações de e-mail sem rota própria, as 5 seções de Disparos, a ponte de interceptação em Integrações). **Todas bateram exatamente com o que o documento descreve.** Trato o restante do documento como confiável por amostragem.

Fui além do documento em dois pontos, porque mudam a resposta:

1. **DMs do Instagram (U2) — a duplicação é mais funda do que o documento registra.** Vendas e Growth's Content leem `social_conversas`/`social_mensagens`, alimentadas por um RPC próprio (`instagram_dms_resumo`) com sincronização a cada 30 minutos. Mas `assets/atendimento.js` já conecta contas Instagram pelo Zernio (`atd_canais` com `canal='instagram', provedor='zernio'`) e guarda em `atd_conversas`/`atd_mensagens` — **a mesma fonte (Zernio/Instagram), em duas tabelas diferentes, sem ligação entre si confirmada no código.** Isso não é "duas telas olhando pro mesmo dado": são dois pipelines de ingestão escrevendo em dois lugares. Antes de apontar um "Abrir conversa" de um lado para o histórico do outro, é preciso confirmar se as duas sincronizações estão ativas ao mesmo tempo para o mesmo cliente (se sim, o risco de mensagem perdida ou duplicada é real, não hipotético).

2. **Estratégias (U1) — o risco de permissão já está coberto.** Fui ver se `cad-funis` e `mkt-estrategias` são permissões independentes: são. `cad-funis` tem sua própria linha em `acesso_telas` (migration `20261010230000_pacotes_acesso.sql`) e aparece no array `telas` de pacotes existentes. `mkt-estrategias` tem outra linha própria (migration `20261124100000_strategy_canvas.sql`), mas **não** precisa estar no pacote: o código já tem a regra "quem vê `cad-funis` ou `mkt-camp` também vê `mkt-estrategias`" (`telaLiberada`, a linha que o documento cita). Ou seja, a base para unificar sem quebrar permissão **já existe no código** — não é um risco a mitigar, é um risco já mitigado. Só falta a parte de interface: redirecionar `cad-funis` para a rota canônica.

## Respostas às 7 perguntas

**1. Quais unificações são realmente seguras sem conciliar bancos ou fluxos diferentes?**
- **Seguras agora:** U1 (Estratégias — mesma função, mesma tabela, permissão já coberta); os casos que o documento já separou como "não fundir automaticamente" (Comissões, Clientes/Contatos/Alunos, Canais cadastro vs. conexão, Conteúdo/Instagram) — aí a mudança é só nome e atalho, sem risco de dado.
- **Ainda não seguras:** U2 (DMs) — pela duplicação de pipeline que achei acima, precisa primeiro confirmar se as duas sincronizações do Instagram coexistem e, se sim, qual é a de verdade. U3 (canais de mensageria) — a ponte de interceptação já existente em Atendimento é sinal de migração parcial; decidir qual componente fica exige testar as ações específicas da Evolution (QR, instância, foto/status) antes de remover a tela antiga.

**2. Qual deve ser a rota canônica de Estratégias, considerando acesso de clientes com permissões limitadas?**
`mkt-estrategias`. Com a ressalva confirmada acima: a permissão que deve continuar existindo no banco é `cad-funis` (é ela que está nos pacotes hoje); `mkt-estrategias` continua sendo liberada por regra, não por pacote. Então "unificar a tela" não exige nenhuma migração de permissão — só o redirecionamento de interface de `cad-funis` → `mkt-estrategias`, mantendo os painéis extras (`etapas_funil`, `listas_funil`) como o documento propõe.

**3. DMs do Instagram já convergem para a mesma conversa e o mesmo histórico? Se não, qual o plano de transição?**
Não convergem — e a causa é mais séria do que "três telas, um dado": são **duas tabelas** (`social_conversas` vs `atd_conversas`) potencialmente recebendo o mesmo Instagram pelo mesmo Zernio. Antes de qualquer unificação de tela:
1. Checar, por workspace, se a conta Instagram está conectada nos dois lugares (`social_` antigo e `atd_canais` novo) ao mesmo tempo.
2. Se estiver, decidir qual desliga — não dá para manter as duas rodando e escolher a tela depois.
3. Migrar o histórico da que for descontinuada para a que fica (ou manter as duas de leitura, só escrevendo numa).
4. Só então mexer em "Atendimento > Conversas" como destino único.

**4. Onde devem ficar as credenciais de canais para separar administradores de atendentes?**
O documento já aponta a direção certa (S4: `Configurações > Pessoas e acessos > Agentes de sistema` para o Frank/agentes externos, token e workspaces autorizados ficando fora do atendente comum). Para os canais de mensageria (U3/S3), a mesma lógica: quem conecta/desconecta/revoga (credencial) fica em Configurações ou num card de administrador dentro de Atendimento; quem só acompanha status e QR do dia a dia fica em `Atendimento > Canais e conexões`. Isso bate com o papel que `atd_canais` já modela (campos de status e numero separados dos tokens do provedor).

**5. Quais telas separadas exigem nova permissão e quais podem herdar a permissão atual?**
- **Herdam a atual (sem nova linha em `acesso_telas`):** S1 (Chatbots/E-mail dentro de Automações — é a mesma tela `atd-automacoes` virando duas rotas filhas); S2 (Campanhas de grupos é hoje uma aba dentro de `atd-grupos-disparo` — pode continuar sob a mesma permissão de Disparos).
- **Podem precisar de permissão própria:** S4 (Agentes de sistema) — já é tratado como acesso interno/admin, separado do atendente; uma tela própria em Configurações deveria manter essa restrição, não herdar a permissão geral de Atendimento ou Integrações.

**6. A proposta de quatro áreas para o detalhe da campanha preserva todos os atalhos existentes?**
Não dá para garantir sem mapear quem lê `S.campTab` com um valor fixo (ex.: um botão em outro lugar do sistema que abre a campanha já na aba "Ofertas e preços" ou "Funil da campanha"). O documento já pede isso no requisito transversal 1; não encontrei, na amostragem que fiz, nenhum lugar que dependa de uma ordem específica das abas dentro de `CAMP_TABS` — mas o inventário completo de quem seta `S.campTab` diretamente (fora dos cliques na própria tela) ainda precisa ser feito antes de reorganizar.

**7. Qual sequência de implementação tem menor risco para disparos agendados e automações em execução?**
Nenhuma das unificações/separações propostas toca a tabela ou a fila de um disparo já agendado — S2 reorganiza onde a campanha de grupos é *gerenciada*, não como ela é *executada* (a execução já é por `campanha_id`/fila, independente da tela). Ordem de menor risco:
1. U1 (Estratégias) — zero dado em trânsito, risco mais baixo do lote.
2. S1 (Automações: dar rota própria ao que já é `vEmailAutomacoes`) — é trocar *como se chega* na tela, não o que ela guarda.
3. S5 (reorganizar abas da campanha) — depois de mapear atalhos (pergunta 6).
4. S2 (Campanhas de grupos com tela própria) — fazer **fora** de qualquer horário com disparo agendado em andamento, e sem migrar `grupo_campanha_id` nem recriar registros.
5. U2 (DMs) e U3 (canais) — por último, só depois de resolver a duplicação de dados que achei acima; são os únicos itens do lote com risco real de perda de histórico.

## Matrizes (resumo verificado)

### Tela atual → tela futura

| Atual | Futura | Tipo | Risco |
|---|---|---|---|
| `cad-funis` (Configurações) | redireciona para `mkt-estrategias` | unificação | baixo — permissão já coberta |
| `mkt-estrategias` | rota canônica, com seção "Configurações da estratégia" | unificação | baixo |
| `crm-dms` (Vendas) | indicador + "Abrir conversa" apontando pro destino operacional | unificação | **alto** — tabelas não unificadas ainda |
| MQ_CANAL "DMs" (Conteúdo) | idem acima | unificação | **alto** — mesma causa |
| `atd-conversas` | destino operacional único (se a duplicação de dado for resolvida antes) | unificação | alto, condicionado |
| Integrações (canais de mensagem) | ação contextual "Configurar canal" / "Ver conexão" para o mesmo registro | unificação | médio — já existe ponte parcial |
| Integrações → Frank/agentes externos | `Configurações > Pessoas e acessos > Agentes de sistema` | separação | médio — mexe em token/escopo |
| Integrações → leads (tracking/webhook) | `Configurações > Entrada de leads` | separação | baixo |
| `atd-automacoes` botão "Automações de e-mail" | `atd-automacoes/email` com rota própria | separação | baixo |
| `atd-grupos-disparo` seção "Campanhas" | `Atendimento > Campanhas de grupos` | separação | médio — não fazer com disparo em andamento |
| `CAMP_TABS` (14 abas) | 4 grupos (Planejamento/Operação/Resultados/Fechamento) | reorganização | médio — depende do inventário de atalhos (pergunta 6) |

### Matriz de permissões (o que confirmei no banco)

| Tela | Linha própria em `acesso_telas`? | Hoje aparece em pacotes? | Observação |
|---|---|---|---|
| `cad-funis` | sim | sim (ex.: pacote padrão de Configurações) | é a permissão "de verdade" |
| `mkt-estrategias` | sim | não precisa | liberada por regra via `cad-funis` ou `mkt-camp` |
| Automações (chat/e-mail) | não verificado | — | provavelmente herda `atd-automacoes` |
| Campanhas de grupos | não verificado | — | provavelmente herda `atd-grupos-disparo` |
| Agentes de sistema | não existe hoje como tela própria | — | hoje é lógica interna dentro de Integrações, não uma permissão de cliente |

### Inventário de atalhos afetados (parcial — o que achei na amostragem)

- `telaLiberada`: regra explícita ligando `mkt-estrategias` a `cad-funis`/`mkt-camp` (linha ~13280) — preservar literalmente se `cad-funis` for removido do menu.
- `moduloDaView`: resolve `mkt-estrategias` para o módulo `mkt` (por estar no grupo Marketing, que vem antes de Configurações na lista `NAV`) e `cad-funis` para `cad` — qualquer refatoração de `NAV` que reordene os grupos muda esse resultado silenciosamente.
- `CASA_MAP`/`CASA_REV`: já é o padrão de "redirecionar ID antigo para o destino real" que o documento sugere para `cad-funis` — vale copiar essa estrutura em vez de inventar um novo mecanismo.
- `S.view` default (`new URLSearchParams(...).get('v')`): um link salvo com `?v=cad-funis` ou `?v=atd-automacoes` precisa continuar resolvendo, então qualquer redirecionamento tem que acontecer na leitura do parâmetro, não só no clique do menu.

### Plano de transição (visão geral)

1. **Agora, sem risco:** redirecionar `cad-funis` → `mkt-estrategias` na interface (sem tocar banco); dar rota própria a `atd-automacoes`/e-mail; renomear Comissões/Canais/Clientes conforme o documento já propôs (texto só).
2. **Depois de eu confirmar a duplicação do Instagram:** decidir qual tabela de DM fica, migrar/descontinuar a outra, só então unificar a tela.
3. **Antes de tocar nas 14 abas da campanha:** levantar todo lugar que abre a campanha já numa aba específica.
4. **Fora de janela de disparo agendado:** separar Campanhas de grupos de Disparos.
5. **Por último, com teste por perfil** (administrador interno, cliente com Marketing/Vendas, cliente só com Atendimento, Growth Starter): Integrações → canais de mensagem e Agentes de sistema, porque são os que tocam credencial.

### Critérios de teste (além dos que o documento já lista)

- Para U2 especificamente: antes de testar a tela, testar o dado — comparar, para um workspace com Instagram conectado, a contagem de conversas em `social_conversas` e em `atd_conversas` no mesmo período.
- Para U1: abrir a mesma estratégia pelos dois caminhos atuais (Marketing e Configurações), confirmar que é o mesmo `id`, só então aplicar o redirecionamento.
- Para qualquer redirecionamento de ID: testar `?v=<id-antigo>` direto na URL, não só o clique no menu.

## O que ainda falta para fechar essas matrizes (pendente de você ou de mais levantamento)

- Confirmar comigo mesmo se as duas sincronizações de Instagram (`social_*` e `atd_*`) estão ativas ao mesmo tempo em algum workspace real — isso decide se U2 é "projeto de migração de dado" ou só "escolher a tela".
- Inventariar todos os lugares que setam `S.campTab` com um valor fixo (fora da própria tela de campanha), para responder a pergunta 6 com certeza.
- Confirmar se "Automações" e "Campanhas de grupos" têm (ou deveriam ganhar) permissão própria, ou se continuam herdando a de Atendimento — não achei pacote que distinga isso hoje.

Nenhuma implementação foi feita nesta resposta — é só a verificação e as matrizes que o documento pediu antes da próxima etapa.
