# v0.182 — Conectar Meta Ads sem aplicativo Meta próprio
O Growth V2 abre o **Facebook Login for Business da Zernio**. Não pede `META_APP_ID`, `META_APP_SECRET` nem `META_LOGIN_CONFIG_ID`. Só usa `ZERNIO_API_KEY` no Supabase. Cada cliente (workspace) reutiliza/cria seu próprio perfil técnico na mesma conta central Zernio.

## Arquivos e publicação
1. Aplicar a migration `supabase/migrations/20261031030000_meta_zernio_oauth.sql` **depois** das migrations 0.178 e 0.179.
2. Criar/publicar Edge Function **`meta-zernio`** usando somente `supabase/functions/meta-zernio/index.ts`. Desativar a verificação automática de JWT porque o callback GET é público; no POST a Edge valida o usuário por `auth.getUser`, a autorização de workspace por `zernio_oauth_permitido`, e não aceita operações sem autenticação.
3. Confirmar o Secret existente `ZERNIO_API_KEY`. NÃO cadastrar chaves da Meta para este fluxo.
4. Publicar `assets/atendimento.js` (a função `conexoes` legada Meta/Google não é necessária para conectar a Meta pela Zernio).

## Fluxo do usuário
Cliente atual → Integrações → cartão Meta → **Conectar Meta** → login da Meta → autorizar → callback Zernio confirma conta `metaads` do perfil técnico do cliente → na volta o Growths consulta `GET /v1/ads/accounts`. Havendo uma conta de anúncios, vincula automaticamente; havendo várias contas, solicita que o usuário selecione **somente** as contas do cliente. A seleção é armazenada em `conexao_contas.extras.adAccountIds`. Não selecionar todas automaticamente em agências.

## Separação das integrações
- **Meta Ads**: `meta-zernio` (Zernio, `platform=metaads`), autenticação e seleção de ad accounts. Autorização de ads NÃO implica integração automática de Instagram orgânico, Páginas ou WhatsApp.
- **Instagram orgânico e Atendimento**: `instagram-oauth` via Zernio, já existente. Não alterar.
- **Facebook Página**: Zernio oferece OAuth `/connect/facebook` com seleção de Página hospedada; conexão de Página separada da Meta Ads.
- **WhatsApp oficial**: autorização/fluxo próprio; não herdar de ads.
- **Google Ads/YouTube**: seguem com a Edge `conexoes` legada; não afetam o novo login Meta.

## Desconectar
**Desconectar** no cartão Meta desabilita e remove a seleção do Growth V2; mantém histórico. Isso **não revoga** a credencial armazenada na Zernio. Revogação completa exige desconectar a conta na Zernio ou Meta. O produto deve informar essa distinção na confirmação.

## Limite atual da entrega
Esta v0.182 implementa **login, isolamento, listagem, seleção e desligamento local** de contas Meta Ads. Ainda é necessário acrescentar o conector de **sincronização dos insights Zernio → ads_externo_dia** para que métricas de mídia passem a entrar nos dashboards. Não declarar a sincronização como concluída antes de um teste real. O cadastro de seleção não autoriza importar dados de contas não selecionadas.

## Validação sugerida
- Selecionar dois workspaces, usar dois perfis técnicos e confirmar nenhum acesso cruzado;
- Login negado, callback inválido, estado usado duas vezes, permissão de usuário comum;
- Perfil Zernio existente com conta Instagram: Meta deve usar o mesmo profileId, preservando a conta já ligada;
- Usuário que gerencia 5 ad accounts: escolher apenas a conta correta e confirmar `extras.adAccountIds`;
- Confirmar que não apareceu cartão duplicado Meta e que os cards Instagram/Google continuam intactos.
