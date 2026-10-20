-- v0.74: Growth Model refeito. O modelo de 12 meses (produtos, loops, séries mensais, diagnóstico) fica em um JSON por cliente.
-- Provisório de propósito: o banco será reestruturado depois, quando o formato estiver validado em uso real.
create table gm_modelos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null default 'Modelo atual' check (char_length(nome) <= 120),
  dados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id)
);
alter table gm_modelos enable row level security;
create policy gm_modelos_acesso on gm_modelos for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on gm_modelos as restrictive for select using (perm(workspace_id, 'ler', array['mkt','adm','gro','vendas','cad']));
create policy perm_inserir on gm_modelos as restrictive for insert with check (perm(workspace_id, 'editar', array['mkt','gro','cad']));
create policy perm_alterar on gm_modelos as restrictive for update using (perm(workspace_id, 'editar', array['mkt','gro','cad'])) with check (perm(workspace_id, 'editar', array['mkt','gro','cad']));
create policy perm_excluir on gm_modelos as restrictive for delete using (perm(workspace_id, 'editar', array['mkt','gro','cad']));
