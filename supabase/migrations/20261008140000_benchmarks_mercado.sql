-- v0.66: tabela de benchmarks do mercado por cliente (valores digitados por você; nada vem pré-preenchido).
create table benchmarks_mercado (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  metrica text not null check (metrica in ('cpl', 'cac', 'conv', 'ticket', 'roas', 'margem', 'leads', 'receita')),
  valor numeric(14,4) not null check (valor >= 0),
  fonte text check (fonte is null or char_length(fonte) <= 200),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, metrica)
);
alter table benchmarks_mercado enable row level security;
create policy benchmarks_mercado_acesso on benchmarks_mercado for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on benchmarks_mercado as restrictive for select using (perm(workspace_id, 'ler', array['mkt','adm','gro','vendas','cad']));
create policy perm_inserir on benchmarks_mercado as restrictive for insert with check (perm(workspace_id, 'editar', array['mkt','gro','cad']));
create policy perm_alterar on benchmarks_mercado as restrictive for update using (perm(workspace_id, 'editar', array['mkt','gro','cad'])) with check (perm(workspace_id, 'editar', array['mkt','gro','cad']));
create policy perm_excluir on benchmarks_mercado as restrictive for delete using (perm(workspace_id, 'editar', array['mkt','gro','cad']));
