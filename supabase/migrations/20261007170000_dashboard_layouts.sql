-- v0.58: layout personalizado do dashboard, por pessoa e por workspace.
create table dashboard_layouts (
  user_id uuid not null default auth.uid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  layout jsonb not null,
  atualizado_em timestamptz not null default now(),
  primary key (user_id, workspace_id)
);
alter table dashboard_layouts enable row level security;
create policy dash_layout_proprio on dashboard_layouts
  for all to authenticated
  using (user_id = auth.uid() and pertence_ao_workspace(workspace_id))
  with check (user_id = auth.uid() and pertence_ao_workspace(workspace_id));
