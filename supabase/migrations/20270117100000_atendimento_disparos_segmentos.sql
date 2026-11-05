-- Segmentos reutilizáveis de destinatários para disparos de Atendimento.
create table if not exists public.atd_disparos_segmentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 100),
  conversas uuid[] not null check (cardinality(conversas) between 1 and 500),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, id)
);

create index if not exists atd_disparos_segmentos_workspace_idx
  on public.atd_disparos_segmentos (workspace_id, criado_em desc);

alter table public.atd_disparos_segmentos enable row level security;
drop policy if exists atd_disparos_segmentos_leitura on public.atd_disparos_segmentos;
create policy atd_disparos_segmentos_leitura on public.atd_disparos_segmentos
  for select to authenticated
  using (public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id, 'ler', array['vendas']));

revoke all on public.atd_disparos_segmentos from anon, authenticated;
grant select on public.atd_disparos_segmentos to authenticated;
grant all on public.atd_disparos_segmentos to service_role;
