-- Base mínima e isolada para testar a v0.98 (cenários do Growth Model). Roda num banco vazio.
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql as $$ select null::uuid $$;
do $$ begin create role authenticated; exception when others then null; end $$;
do $$ begin create role anon; exception when others then null; end $$;
do $$ begin create role service_role; exception when others then null; end $$;
create table workspaces (id uuid primary key default gen_random_uuid(), nome text);
create table produtos (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text);
create or replace function pertence_ao_workspace(uuid) returns boolean language sql as $$ select true $$;
create or replace function perm(uuid, text, text[]) returns boolean language sql as $$ select true $$;
create table admins (ws uuid);
create or replace function eh_admin(ws uuid) returns boolean language sql as $$ select exists (select 1 from admins a where a.ws = ws) $$;
create table gm_alavancas (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade, loop_chave text not null,
  produto_id uuid references produtos(id) on delete cascade, alavanca text not null, mes date not null,
  cenario text not null check (cenario in ('base','sim')), valor numeric not null, criado_em timestamptz not null default now());
create unique index gm_alavancas_uni on gm_alavancas (workspace_id, loop_chave, coalesce(produto_id,'00000000-0000-0000-0000-000000000000'::uuid), alavanca, mes, cenario);
create table simulador_cenarios (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, dados jsonb, status text default 'rascunho', criado_por uuid, criado_em timestamptz default now());
insert into workspaces values ('00000000-0000-0000-0000-0000000000a1', 'W'), ('00000000-0000-0000-0000-0000000000a2', 'Sem cenário');
insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values
  ('00000000-0000-0000-0000-0000000000a1', 'campanha:x', 'tkt', '2026-11-01', 'base', 900), ('00000000-0000-0000-0000-0000000000a1', 'campanha:x', 'tkt', '2026-11-01', 'sim', 1100),
  ('00000000-0000-0000-0000-0000000000a1', 'campanha:x', 'vol', '2026-11-01', 'sim', 5000), ('00000000-0000-0000-0000-0000000000a2', 'organico', 'vol', '2026-11-01', 'base', 10);
insert into simulador_cenarios (id, workspace_id, nome, dados) values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1', 'Base UE', '{"fixos":[{"valor":100}]}');
create table simulador_snapshots (id uuid primary key default gen_random_uuid(), workspace_id uuid, cenario_id uuid not null references simulador_cenarios(id) on delete cascade, nome text);
insert into simulador_snapshots (workspace_id, cenario_id, nome) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', 'foto');
