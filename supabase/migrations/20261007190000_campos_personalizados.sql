-- v0.63: campos personalizados por cliente (para as colunas da planilha que não existem no Growths).
create table campos_personalizados (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  entidade text not null check (entidade in ('pessoas', 'produtos', 'fornecedores', 'campanhas', 'vendas')),
  chave text not null check (chave ~ '^[a-z][a-z0-9_]{1,40}$'),
  rotulo text not null check (char_length(rotulo) between 1 and 80),
  tipo text not null default 'text' check (tipo in ('text', 'number', 'date')),
  criado_em timestamptz not null default now(),
  unique (workspace_id, entidade, chave)
);
alter table campos_personalizados enable row level security;
create policy campos_personalizados_acesso on campos_personalizados for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

alter table pessoas add column extras jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object');
alter table produtos add column extras jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object');
alter table fornecedores add column extras jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object');
alter table campanhas add column extras jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object');
alter table vendas add column extras jsonb not null default '{}'::jsonb check (jsonb_typeof(extras) = 'object');
