-- Campanhas de grupos reutilizáveis. O disparo guarda um snapshot dos destinatários
-- e uma referência à campanha usada no agendamento.
create table if not exists public.atd_grupo_campanhas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 100),
  descricao text not null default '' check (length(descricao) <= 1000),
  conversas uuid[] not null default '{}'::uuid[] check (cardinality(conversas) <= 500),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, id)
);

create index if not exists atd_grupo_campanhas_workspace_idx
  on public.atd_grupo_campanhas (workspace_id, atualizado_em desc);

alter table public.atd_grupo_campanhas enable row level security;
drop policy if exists atd_grupo_campanhas_leitura on public.atd_grupo_campanhas;
create policy atd_grupo_campanhas_leitura on public.atd_grupo_campanhas
  for select to authenticated
  using (public.pertence_ao_workspace(workspace_id)
    and public.perm(workspace_id, 'ler', array['vendas']));

revoke all on public.atd_grupo_campanhas from anon, authenticated;
grant select on public.atd_grupo_campanhas to authenticated;
grant all on public.atd_grupo_campanhas to service_role;

alter table public.atd_disparos_grupos
  add column if not exists grupo_campanha_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'atd_disparos_grupos_campanha_fk'
      and conrelid = 'public.atd_disparos_grupos'::regclass
  ) then
    alter table public.atd_disparos_grupos
      add constraint atd_disparos_grupos_campanha_fk
      foreign key (workspace_id, grupo_campanha_id)
      references public.atd_grupo_campanhas(workspace_id, id);
  end if;
end;
$$;

create index if not exists atd_disparos_grupos_campanha_idx
  on public.atd_disparos_grupos (workspace_id, grupo_campanha_id);
