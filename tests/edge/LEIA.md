# Teste da edge function "ideias" contra o Postgres local

1. Prepare o banco `g109` como em `tests/banco/LEIA.md` (v0.109) e gere uma chave:
   `select set_config('t.uid','00000000-0000-0000-0000-00000000aaaa',false); select chave_api_criar('00000000-0000-0000-0000-0000000000c1','teste edge');`
2. Suba a função com o stub (o `rpc` vira `select função(...)` via psql):
   `DENO_SERVE_ADDRESS=tcp:127.0.0.1:8787 SUPABASE_URL=x SUPABASE_ANON_KEY=y deno run --allow-all --import-map=tests/edge/import_map.json supabase/functions/ideias/index.ts`
   (o import map aponta para `./stub_supabase.ts`; copie a função para esta pasta ou ajuste o caminho.)
3. Rode `CHAVE=gw_... deno run --allow-net --allow-env tests/edge/ideias_teste.ts`.

# Teste da edge function "leads" (v0.113)
1. `deno run --allow-env tests/edge/leads_teste.ts` — leitura dos campos (página, Respondi, Meta), sem banco.
2. Com banco (ex.: `escp` com a migração 20261018100000) e uma chave de escopo `leads`:
   `DENO_SERVE_ADDRESS=tcp:127.0.0.1:8788 PGDB=escp SUPABASE_URL=x SUPABASE_ANON_KEY=y deno run --allow-all --import-map=tests/edge/import_map.json supabase/functions/leads/index.ts`
   e depois `CHAVE=gw_... BASE=http://127.0.0.1:8788 deno run --allow-net --allow-env tests/edge/leads_teste.ts`.
