# Central de Atendimento

Entrega v0.175, preparada em 30/10/2026 sobre a v0.174. Código e testes locais; banco, Edge Function, credenciais e webhooks ainda precisam ser publicados/configurados. Esta entrega não envia mensagens reais durante os testes.

## O que está implementado

- Menu Atendimento, entre Vendas e RevOps: Conversas e Canais e conexões.
- Caixa de entrada com filtros por nome/número, conta conectada, pessoas/grupos, situação, responsável e não lidas.
- Histórico em três colunas, notas internas, responsável, aberta/aguardando/resolvida e rascunhos em memória por conversa.
- Vincular uma conversa individual a uma pessoa existente ou criar um lead; abrir a ficha atualizada da v0.174 (documento, linha do tempo, oportunidades, contratos, jornada e campos extras).
- WhatsApp Evolution 2.3.7: configuração de URL/Key em Integrações, criação de instância própria do Growths, QR Code, status, busca de conversas e grupos, importação paginada do histórico, envio e recebimento.
- WhatsApp oficial e Instagram pela Zernio: contas do perfil já conectado ao workspace, sincronização paginada, envio de respostas, webhooks assinados e eventos de entrega/leitura.
- Assinatura aplicada pelo servidor a partir de `equipe.nome`, ligada ao usuário autenticado. No WhatsApp: `*Nome:* mensagem`. Se faltar nome, o envio é recusado até corrigir o cadastro da equipe.
- Anexos até 8 MB: imagens JPEG/PNG/WebP, MP4, áudio e PDF. Arquivos recebidos são copiados para Storage privado; falhas ficam visíveis como anexo pendente e podem ser recuperadas. Não há transcrição nem gravação de áudio no navegador nesta etapa.

## Modelo de dados e permissões

`atd_canais` identifica provedor, canal e conta/instância. `atd_conversas` identifica a conversa e seu vínculo com `pessoas`; grupos têm vários participantes e não representam uma única pessoa. `atd_mensagens` guarda texto, autor, participante, instante, estado, anexo e chave de deduplicação.

Desconectar um número não apaga as mensagens. As tabelas não dependem de exclusão em cascata das conexões antigas. O histórico anterior à instalação depende do que cada provedor disponibiliza. Não se promete recuperar conteúdo que nunca foi capturado ou já deixou de estar disponível.

A fase inicial herda permissões do módulo Vendas. Acesso ao menu também segue o catálogo de pacotes; liberar `atd-conversas` e `atd-canais` nos pacotes desejados. Somente administradores configuram credenciais, contas, QR e webhooks. Usuários com leitura não enviam nem alteram atendimentos.

RLS em todas as tabelas públicas; navegador só tem SELECT. Alterações passam pela função, que valida login, workspace e permissão antes de usar `service_role`. Vínculos cruzados entre workspaces são recusados também por FK/trigger. Segredos ficam em `privado.atd_segredos`; funções que os acessam só podem ser executadas por `service_role`. O bucket `atendimento` é privado e links de leitura são temporários, emitidos após autorização.

Um identificador de requisição impede o reenvio do mesmo pedido. Se o provedor não confirmar a entrega, a mensagem fica **Sem confirmação**. Não há reenvio automático: consultar o histórico antes de tentar novamente. Webhooks repetidos não duplicam registros, estados atrasados não fazem uma mensagem lida voltar a enviada, e importação antiga não aumenta não lidas nem reabre conversas.

## Publicação

1. Aplicar `supabase/migrations/20261030021541_central_atendimento.sql` no projeto Supabase correto, sobre a base atual. O nome foi gerado pela CLI; migrações antigas do repositório têm nomes com datas futuras. Para banco existente, aplicar este arquivo explicitamente no SQL Editor; não executar um `db push` indiscriminado.
2. Publicar a Edge Function `atendimento` **sem verificação automática de JWT**, porque o mesmo endpoint recebe webhooks. O código verifica o JWT nos comandos do aplicativo, HMAC nos webhooks Zernio e segredo de header + instância nos webhooks Evolution. Com a CLI: `supabase functions deploy atendimento --no-verify-jwt --project-ref <projeto>`.
3. Manter `ZERNIO_API_KEY` no servidor e cadastrar `ZERNIO_ATENDIMENTO_WEBHOOK_SECRET` com um segredo aleatório forte. As variáveis padrão do Supabase são fornecidas pelo runtime. Não colocar chaves no HTML, repositório ou campos genéricos de Integrações.
4. Publicar `index.html` **e a pasta `assets/`**. O front continua sem build; agora depende também de `assets/atendimento.js` e `assets/atendimento.css`.
5. Liberar as duas telas nos pacotes de acesso que usarão Atendimento. Conferir o nome e o `user_id` do atendente em Equipe e acessos.
6. Integrações → Evolution: informar URL HTTPS pública e API Key global. A função testa a chave por leitura antes de salvar. Criar uma instância em Canais, ler o QR, verificar status e buscar conversas/grupos. Só instâncias criadas pelo Growths são gerenciadas nesta primeira versão.
7. Zernio: adicionar uma conta do perfil já vinculado ao workspace. Ativar recebimento cria um webhook próprio, sem substituir os existentes. Buscar conversas e importar o histórico de cada conversa. Contas sem perfil verificável não são expostas entre clientes.
8. Fazer homologação com contas de teste: mensagem de entrada, resposta assinada, grupo com dois participantes, entrega/leitura, reconexão, anexo, falta de permissão e acesso por outro workspace. Nenhuma integração real foi testada sem URL/chaves/contas do usuário.

O endpoint da Evolution recebe os eventos `MESSAGES_UPSERT`, `MESSAGES_UPDATE` e `CONNECTION_UPDATE`, usando `headers`, `byEvents` e `base64`, conforme o código oficial da versão 2.3.7. O QR pode expirar; o botão obtém outro. Mídias pendentes podem precisar de nova tentativa antes de o provedor deixar de disponibilizá-las. Não há trabalhador agendado de recuperação nesta versão.

## Extensão para outros canais

O banco usa textos para `provedor` e `canal`, sem enum fechado. O registro `providers` em `supabase/functions/atendimento/providers.ts` define envio; normalizadores em `core.ts` traduzem os eventos para o contrato comum. Para Telegram ou TikTok: implementar/registrar adaptador e normalizador, habilitar descoberta de contas daquele canal, documentar suas capacidades e adicionar testes. O seletor e o histórico usam os registros do banco. Telegram/TikTok não aparecem como conectáveis antes dessa implementação.

Templates, disparos, editor de automações, indicadores, respostas rápidas, iniciar conversa proativa, importação automática dos registros antigos de DMs e unificação automática de identidades entre canais não fazem parte desta primeira etapa. As DMs antigas permanecem disponíveis nas telas anteriores. WhatsApp oficial continua exigindo template aprovado quando a janela de resposta estiver fechada; a central informa a recusa do provedor.

## Validação e integração

Base atualizada por fast-forward até `d07498c` (v0.174), preservando as mudanças comerciais e de ficha do cliente. O módulo foi separado em assets para reduzir o conflito no `index.html`.

- `deno check supabase/functions/atendimento/index.ts`: tipagem do runtime.
- `deno test tests/atendimento/core_test.ts`: assinatura, HMAC, identificadores, grupos, mídia, ordenação de estados e URLs.
- `node tests/atendimento/banco.mjs`: PGlite com schema mínimo; RLS, acesso a segredos, deduplicação, vínculos entre clientes, eco de envio e preservação do histórico.
- `node tests/atendimento/tela.mjs`: navegador com banco simulado; navegação, pessoa, grupos, envio, notas, rascunhos, filtros, responsividade, QR e chave oculta.
- Regressões de tela `t172_estrategia_resumo_campanha.py`, `t173_pessoa_documento_linha_tempo.py` e `t174_oportunidade_contrato.py`: todas passaram após incorporar a base da outra pessoa.

Ferramentas de teste locais ficam em `.dev-tools`, fora do Git. Instalação reproduzível: `npm install --prefix .dev-tools @electric-sql/pglite@0.2.17 playwright deno@2.5.6`. O teste de tela usa Microsoft Edge instalado; só o perfil temporário do teste é aberto.

A tentativa de montar **todas** as migrações no PGlite apresentou 15 falhas existentes na base, reproduzidas igualmente sem a migração de Atendimento: extensões `pg_cron`/`pg_net`, seed com workspace fixo e dependências de jornadas/conteúdo. O teste SQL de documento da v0.173 passou; o de oportunidade da v0.174 depende das migrações que falharam na base. Isso não equivale a validar toda a produção. A migração de Atendimento passou no conjunto completo e no teste isolado.

Fontes conferidas: [Evolution API 2.3.7](https://github.com/evolution-foundation/evolution-api/tree/2.3.7), [Zernio Inbox](https://docs.zernio.com/multi-tenant/inbox), [Webhooks Zernio](https://docs.zernio.com/webhooks), [Storage Supabase](https://supabase.com/docs/guides/storage/security/access-control).


## Vínculo Zernio por cliente (v0.178)
Selecione o cliente atual e acesse Configurações → Integrações → Zernio → Vincular conta. O administrador escolhe uma conta Instagram ou WhatsApp existente na Zernio; sua chave permanece nos Secrets do servidor.
A associação grava a conta no workspace em `conexoes` e `conexao_contas`. Depois, adicione o canal em Atendimento → Canais e conexões. Cada conta pertence explicitamente a um cliente, sem herdar outras contas do mesmo perfil.
Publicação pendente: aplicar `supabase/migrations/20261030220000_zernio_cliente.sql` depois da v0.175, publicar a Edge Function `atendimento` e o asset da interface e testar com uma conta real.
