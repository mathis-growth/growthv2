-- Biblioteca de e-mails reutilizáveis entre Envios e os canvas de Automações.
create table if not exists public.atd_email_modelos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 160),
  assunto text not null check (length(trim(assunto)) between 1 and 180),
  html text not null check (length(html) between 1 and 100000),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id,id)
);
create index if not exists atd_email_modelos_workspace_data on public.atd_email_modelos(workspace_id,atualizado_em desc);
alter table public.atd_email_modelos enable row level security;
drop policy if exists atd_email_modelos_ler on public.atd_email_modelos;
create policy atd_email_modelos_ler on public.atd_email_modelos for select to authenticated
  using (public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_email_modelos from public,anon,authenticated;
grant select on public.atd_email_modelos to authenticated;
grant all on public.atd_email_modelos to service_role;
