-- Usuários de integração do Frank e permissões por workspace.
-- Os tokens em texto puro são exibidos apenas na criação/rotação; o banco guarda SHA-256.
-- Acesso às tabelas somente pelo service_role dentro da Edge frank-growth.

create table if not exists public.frank_growth_integracoes (
  id uuid primary key default gen_random_uuid(),
  agencia_workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (char_length(btrim(nome)) between 1 and 100),
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  token_prefix text not null check (char_length(token_prefix) between 5 and 20),
  escopos text[] not null default array['growth:consultar']::text[],
  ativo boolean not null default true,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  ultimo_uso_em timestamptz,
  rotacionado_em timestamptz,
  revogado_em timestamptz,
  constraint frank_growth_integracoes_escopos_ck check (
    cardinality(escopos) > 0 and escopos <@ array['growth:consultar', 'campanha:criar']::text[]
  )
);
create index if not exists frank_growth_integracoes_agencia_ix
  on public.frank_growth_integracoes (agencia_workspace_id, ativo, criado_em desc);
alter table public.frank_growth_integracoes enable row level security;
revoke all on public.frank_growth_integracoes from public, anon, authenticated;
grant select, insert, update, delete on public.frank_growth_integracoes to service_role;

create table if not exists public.frank_growth_integracao_workspaces (
  integracao_id uuid not null references public.frank_growth_integracoes(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (integracao_id, workspace_id)
);
create index if not exists frank_growth_integracao_workspaces_workspace_ix
  on public.frank_growth_integracao_workspaces (workspace_id, integracao_id);
alter table public.frank_growth_integracao_workspaces enable row level security;
revoke all on public.frank_growth_integracao_workspaces from public, anon, authenticated;
grant select, insert, update, delete on public.frank_growth_integracao_workspaces to service_role;

comment on table public.frank_growth_integracoes is
  'Identidades de máquina do Frank; token em texto puro nunca é armazenado nem recuperável.';
comment on table public.frank_growth_integracao_workspaces is
  'Workspaces explicitamente autorizados para cada identidade de máquina do Frank.';
