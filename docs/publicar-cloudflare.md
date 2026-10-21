# Publicar o Growths no Cloudflare Pages

O Growths é um arquivo só (`index.html`, na raiz do repositório `mathis-growth/growthv2`) que conversa com o Supabase. O Cloudflare Pages publica o repositório a cada atualização no GitHub. Não precisa compilar nada.

## 1. GitHub (uma vez)
1. Em github.com, crie um repositório **privado** chamado `growths` (sem README, sem .gitignore).
2. Suba esta pasta para ele (o Claude faz isso se o GitHub estiver conectado; ou use o GitHub Desktop: File → Add local repository → a pasta `growths` → Publish).

## 2. Cloudflare Pages (uma vez)
1. dash.cloudflare.com → **Workers & Pages** → **Create** → aba **Pages** → **Connect to Git**.
2. Autorize o GitHub e escolha o repositório `growths`.
3. Configuração:
   - Production branch: `main`
   - Framework preset: **None**
   - Build command: *(deixe vazio)*
   - Build output directory: *(deixe vazio: o `index.html` está na raiz)*
4. **Save and Deploy**. Em cerca de 1 minuto o Growths fica no ar em `https://growths.pages.dev` (ou o nome que o Cloudflare der).
5. Opcional: **Custom domains** → `app.mathisa.com.br` (ou outro). O Cloudflare mostra o registro DNS a criar.

## 3. Supabase (uma vez, depois que tiver o endereço)
Authentication → URL Configuration:
- **Site URL**: o endereço do Cloudflare (ex.: `https://growths.pages.dev`). É para onde vão os links de convite, confirmação de e-mail e troca de senha.
- **Redirect URLs**: acrescente o mesmo endereço e, se tiver, o domínio próprio.

## Como atualizar
Cada versão nova do `index.html` que entra no GitHub (branch `main`) é publicada sozinha. As migrações do banco continuam sendo rodadas no SQL Editor, como hoje (o Cloudflare só publica a tela).
Para voltar uma versão: Cloudflare → o projeto → **Deployments** → escolha uma publicação anterior → **Rollback**.

## Segurança
- A chave no `index.html` é a **publicável** do Supabase: pode ficar pública. Quem protege os dados são as regras de acesso (RLS) do banco.
- Nunca coloque no repositório a chave `service_role` ou senhas. O `.gitignore` já bloqueia arquivos `.env`.
- O repositório deve ser privado: tem a documentação e as regras de negócio da Mathisa.
- `frontend/_headers` impede que o Growths seja aberto dentro de outro site (proteção contra clickjacking).
