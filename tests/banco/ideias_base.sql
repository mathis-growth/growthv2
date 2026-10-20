-- Base mínima para testar a v0.109 (ideias pelo ChatGPT) num Postgres local: equipe, papéis do Supabase e stubs de auth/perm controláveis.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
end $$;
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('t.uid', true), '')::uuid $$;
create or replace function public.perm(uuid, text, text[]) returns boolean language sql stable as $$ select coalesce(current_setting('t.perm', true), 'sim') <> 'nao' $$;
create table if not exists equipe (id uuid primary key default gen_random_uuid(), workspace_id uuid references workspaces(id) on delete cascade, nome text);
insert into workspaces (id, nome) values ('00000000-0000-0000-0000-0000000000c1', 'Conteúdo A'), ('00000000-0000-0000-0000-0000000000c2', 'Conteúdo B') on conflict do nothing;
