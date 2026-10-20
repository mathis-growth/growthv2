-- v0.35: campanha recorrente com metas mensais. JÁ APLICADA no projeto.
alter table campanhas add column if not exists meta_leads_mes integer check (meta_leads_mes is null or meta_leads_mes > 0);
create table if not exists campanha_mix (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  produto_id uuid not null references produtos(id),
  vendas_mes integer not null check (vendas_mes > 0),
  unique (campanha_id, produto_id));
create table if not exists campanha_metas_mes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  mes date not null check (mes = date_trunc('month', mes)::date),
  meta_leads integer check (meta_leads is null or meta_leads >= 0),
  meta_vendas integer check (meta_vendas is null or meta_vendas >= 0),
  unique (campanha_id, mes));
alter table campanha_mix enable row level security;
alter table campanha_metas_mes enable row level security;
-- políticas: permissiva por workspace + restritivas perm_ler (mkt, adm, gro, vendas) e perm_inserir/alterar/excluir (editar em mkt), como campanha_canais.
-- função public.campanha_metas_mensal(p_ws, p_campanha, p_hoje): meta × realizado por mês (ver definição no banco com pg_get_functiondef).
