# v0.185 — Canais de Atendimento, Evolution e OAuth de integrações

## O que foi implementado

### Remoção da instância WhatsApp QR Code
Em **Atendimento → Canais e conexões**, somente um administrador pode clicar em **Excluir instância** para uma instância Evolution ativa.

A Edge Function `atendimento`:
- autentica a sessão e confirma autorização administrativa no workspace;
- busca `atd_canais` pelo UUID do canal e do workspace, sem aceitar o nome remoto enviado pelo navegador;
- restringe exclusão a instâncias `growths-<uuid>` criadas pelo Growth V2;
- executa `DELETE /instance/delete/{instance}` na Evolution com a chave que já está armazenada no servidor;
- só após resposta remota bem-sucedida (ou 404 de instância ausente) marca o canal local como `ativo=false` e `status=desativado`;
- preserva todos os históricos `atd_conversas` / `atd_mensagens` no Supabase.

**Não** executar uma exclusão real de instância de cliente para testar isso sem autorização específica. A exclusão no servidor Evolution é irreversível.

### Identificação visual
- Instagram: faixa vermelha, nome do perfil;
- WhatsApp: faixa verde, modalidade `WhatsApp · QR Code` (Evolution) ou `WhatsApp · API oficial` (Zernio), telefone quando informado;
- faixas no topo da conversa, nas linhas da lista de atendimento e nos cartões dos canais;
- novo endpoint `atendimento` / `identidades` consulta `/instance/fetchInstances` para tentar completar números de instâncias Evolution existentes no workspace, sem inventar dados; quando não for possível, exibe `Número: não identificado`.

### OAuth sem Secrets individuais
A Edge Function **`zernio-social-oauth`** utiliza apenas o Secret global `ZERNIO_API_KEY` já existente no Supabase, além das variáveis internas Supabase.
- YouTube, LinkedIn (conteúdo), TikTok (conteúdo), Página do Facebook e WhatsApp API oficial: botões nos cartões nativos que iniciam OAuth `GET /v1/connect/{platform}`, com `profileId` do workspace;
- Facebook, LinkedIn e WhatsApp usam a seleção hospedada pela Zernio após consentimento; WhatsApp usa `onboarding=api`;
- callback público GET `zernio-social-oauth` valida nonce privado de uso único, o workspace e o `profileId`, a plataforma e a conta efetivamente encontrada na Zernio; o POST exige autenticação e autorização de administrador;
- contas são persistidas em `conexao_contas` com o tipo de canal correto; WhatsApp API oficial também cria/atualiza `atd_canais`.
- **Não confundir** TikTok/LinkedIn orgânico e YouTube com Ads. Os cartões `TikTok Ads`, `LinkedIn Ads`, `Google Ads` e as plataformas de pagamento precisam de seus conectores correspondentes e não ganham acesso a métricas pela conexão orgânica Zernio. A conexão Google Ads existente usa o OAuth independente `conexoes`.

### Publicar
1. Executar migration `supabase/migrations/20261031040000_social_oauth_atendimento.sql` depois da v0.182 (DDL aditivo para permissões e tipos de conta).
2. Publicar nova Edge Function **`zernio-social-oauth`** com código de `supabase/functions/zernio-social-oauth/index.ts` e **Verify JWT desativado**, porque o retorno OAuth GET é público. O POST valida token e permissões dentro da função.
3. Republicar Edge Function **`atendimento`**, mantendo arquivos `index.ts`, `providers.ts` e `core.ts` juntos; a v0.185 modifica apenas o `index.ts` existente. É necessário manter seus Secrets atuais (Evolution + Zernio).
4. Publicar `assets/atendimento.js` e `assets/atendimento.css` na Cloudflare.
5. Testar o OAuth real de cada provedor e os diferentes estados de conexão. A versão foi submetida à verificação estática, mas ainda requer homologação ponta a ponta.

### Não incluído nesta versão
- A correção pendente de entrega do webhook de DMs da Zernio (investigação separada), que exige confirmação real do endpoint, assinatura e teste de entrega;
- sincronização de métricas de LinkedIn/TikTok/YouTube com esses novos vínculos. OAuth não equivale a importação automática.
