# Conectar Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube)

Desde a v0.120, o Growths conecta direto nas plataformas. A pessoa entra com a conta dela (login oficial do Meta ou do Google), escolhe as contas e os dados passam a entrar sozinhos:

- **Meta Ads**: custo, impressões, cliques, alcance, leads e compras por anúncio, por dia. Os dados vão para **Mídia paga**.
- **Instagram (conta profissional)**:
  - seguidores, alcance por dia, visualizações e cliques no link do perfil;
  - os posts, com alcance, salvamentos, compartilhamentos, curtidas, comentários e visualizações.
- **Google Ads**: custo, impressões, cliques e conversões por anúncio, por dia. Os dados também vão para **Mídia paga**.
- **YouTube**:
  - visualizações, minutos assistidos e inscritos por dia;
  - os vídeos do canal;
  - as métricas diárias dos vídeos cadastrados em **Vídeos e webinários** (plataforma YouTube + link do vídeo).

Para isso funcionar, é preciso fazer uma vez:

1. criar um **app no Meta for Developers**;
2. criar um **projeto no Google Cloud**;
3. guardar as chaves no Supabase.

Nada disso é cadastrado na tela do Growths: as chaves ficam só no servidor.

---

## 1. Endereço de retorno (o mesmo para as duas plataformas)

```
https://yngyghlyonybvfvjcmxl.supabase.co/functions/v1/conexoes/retorno
```

É para esse endereço que o Meta e o Google devolvem a pessoa depois do login. Ele precisa ser cadastrado igualzinho nos dois apps.

---

## 2. Meta (Facebook Ads + Instagram)

1. Entre em **developers.facebook.com** → *Meus apps* → **Criar app**.
2. Tipo de app: **Empresa** (Business). Ligue o app ao Portfólio empresarial (Business Manager) da Mathisa.
3. No painel do app, adicione os produtos:
   - **Login do Facebook para Empresas** (Facebook Login for Business);
   - **API de Marketing** (Marketing API);
   - **API do Instagram**, na opção "com login do Facebook".
4. Em **Login do Facebook → Configurações**, cole o endereço de retorno do item 1 em *URIs de redirecionamento do OAuth válidos*.
5. Em **Configurações do app → Básico**, anote o **ID do app** e a **Chave secreta do app**.
6. **Facebook Login for Business (seleção de ativos):** crie uma configuração de login no app da Meta para conceder acesso às contas empresariais e copie o **Configuration ID** para o Secret `META_LOGIN_CONFIG_ID` no Supabase. Com esse Secret a Edge `conexoes` inclui `config_id` na autorização. Sem ele, o login clássico continua disponível. A configuração precisa contemplar Ads, Páginas e Instagram; contas não autorizadas não ficam disponíveis.
7. Permissões que o Growths pede:
   - `ads_read` e `read_insights`;
   - `pages_show_list` e `pages_read_engagement`;
   - `instagram_basic` e `instagram_manage_insights`;
   - `business_management`.
8. **Enquanto o app está em modo de desenvolvimento**, só quem tem papel no app (administrador, desenvolvedor ou testador) consegue conectar.
   - Para os primeiros clientes, adicione a pessoa como **testador** em *Funções do app*.
   - Para abrir para qualquer cliente, peça **Acesso avançado** dessas permissões na *Análise do app* (App Review). Para isso, a empresa precisa estar verificada (Verificação da empresa).
9. O acesso do Meta vale cerca de **60 dias**. Antes de vencer, a tela Integrações mostra a data. Depois de vencer, mostra "Acesso expirado: conecte de novo", e basta clicar em **Conectar de novo**.

> **WhatsApp API oficial:** não é habilitado automaticamente por este login. Para criar/associar números WhatsApp Business Platform é necessário o fluxo específico de **Embedded Signup**, permissões de WhatsApp e configuração do app; a conexão de anúncios, páginas e Instagram continua independente. Não confundir com Evolution/WhatsApp Web.

O Instagram precisa ser uma **conta profissional** (comercial ou criador) ligada a uma **Página do Facebook**. É pela página que o Meta entrega o Instagram.

## 3. Google (Google Ads + YouTube)

1. Entre em **console.cloud.google.com** e crie um projeto, por exemplo "Growths".
2. Em **APIs e serviços → Biblioteca**, ative:
   - **YouTube Data API v3**;
   - **YouTube Analytics API**;
   - **Google Ads API**.
3. Em **Tela de consentimento OAuth**:
   - tipo **Externo**;
   - nome do app "Growths", e-mail de suporte e domínio;
   - escopos: `youtube.readonly`, `yt-analytics.readonly`, `adwords`, `openid` e `email`.
   - Enquanto não estiver verificado, adicione os e-mails de quem vai conectar em **Usuários de teste** (até 100).
4. Em **Credenciais → Criar credenciais → ID do cliente OAuth**:
   - tipo **Aplicativo da Web**;
   - em *URIs de redirecionamento autorizados*, cole o endereço do item 1;
   - anote o **ID do cliente** e a **Chave secreta do cliente**.
5. **Google Ads** precisa também de um **token de desenvolvedor**:
   - pegue em ads.google.com, dentro de uma **conta de administrador (MCC)**, em *Ferramentas → Centro de API*;
   - o acesso "Teste" só lê contas de teste; para contas reais, peça o acesso **Básico**;
   - se as contas dos clientes ficam embaixo da MCC, anote também o número da MCC (sem traços).
   - Sem o token, o YouTube funciona normalmente e só o Google Ads fica de fora.

## 4. Guardar as chaves no Supabase

No painel do Supabase: **Edge Functions → Secrets** (ou *Project Settings → Edge Functions*). Crie:

| Nome | O que é |
|---|---|
| `META_APP_ID` | ID do app do Meta |
| `META_APP_SECRET` | Chave secreta do app do Meta |
| `META_LOGIN_CONFIG_ID` | ID da configuração Facebook Login for Business (opcional; habilita seleção de ativos) |
| `GOOGLE_CLIENT_ID` | ID do cliente OAuth do Google |
| `GOOGLE_CLIENT_SECRET` | Chave secreta do cliente OAuth |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Token de desenvolvedor do Google Ads (opcional) |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | Número da MCC, se as contas estiverem embaixo dela (opcional) |
| `CONEXOES_CRON_SEGREDO` | Uma senha longa qualquer, usada pela sincronização automática |
| `APP_URL` | Endereço onde o Growths está publicado (para onde a pessoa volta) |

A função `conexoes` já está publicada no projeto, sem verificação de JWT, porque o retorno vem da plataforma e não do Growths. Ela começa a funcionar assim que as chaves são salvas, sem precisar publicar de novo.

## 5. Sincronização automática (todo dia)

No Supabase: **Integrations → Cron** → *Create job*:

- **Schedule:** `0 9 * * *` (todo dia às 9h UTC, 6h em Brasília).
- **Type:** *Supabase Edge Function* → `conexoes`, caminho `/sincronizar`, método POST.
- **Header:** `x-growths-cron: <o mesmo valor de CONEXOES_CRON_SEGREDO>`. **Body:** `{}`.

O que a sincronização faz:

- puxa todas as conexões com **"Sincronizar todo dia"** marcado;
- na primeira vez, traz os dias escolhidos em *Primeira carga* (7, 30, 90 ou 180);
- depois, traz sempre os últimos 3 dias, porque as plataformas ainda ajustam os números recentes.

## 6. Como os anúncios entram em Mídia paga

Cada campanha da plataforma precisa estar ligada a um **canal de uma campanha do Growths**. O Growths liga sozinho quando:

- o nome da campanha na plataforma é igual ao `utm_campaign` do canal; ou
- o anúncio tem `utm_campaign=...` nos parâmetros de URL (no Meta, "Parâmetros de URL"; no Google, na URL final).

O que não bater aparece em **Integrações → Campanhas de anúncio sem canal**. Ali você escolhe o canal ou ignora a campanha.

O anúncio é reconhecido pelo `utm_content` dos parâmetros. Sem ele, o anúncio é reconhecido pelo nome. Use o mesmo `utm_content` nos links para os leads e as vendas caírem no anúncio certo.

## 7. Onde os dados ficam (banco)

- `conexoes`: uma por plataforma e workspace (situação, quem conectou, validade, última sincronização).
- `conexao_contas`: contas encontradas no login, cada uma com a marcação "sincronizar".
- `privado.conexao_tokens`: os acessos. Ficam fora da API, e só a função do servidor lê.
- `conexao_execucoes`: histórico de cada sincronização.
- `ads_externo_dia` e `ads_externo_vinculos`: o que veio da plataforma e o vínculo campanha → canal. Daí os dados vão para `anuncios` e `metricas_anuncio_dia`, com origem "integracao".
- `social_perfis_dia` e `social_posts`: o orgânico do Instagram e do YouTube.
- `video_metricas_dia`: as métricas diárias dos vídeos do YouTube cadastrados.
