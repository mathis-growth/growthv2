-- Fechamento da campanha (foto do planejado x realizado) e lista de melhorias por sprint.
create table if not exists campanha_fechamentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  fechado_em timestamptz not null default now(),
  fechado_por uuid default auth.uid(),
  periodo_ini date, periodo_fim date,
  snapshot jsonb not null default '{}'::jsonb
);
create index if not exists campanha_fechamentos_camp on campanha_fechamentos (campanha_id, fechado_em desc);
alter table campanha_fechamentos enable row level security;
create policy campanha_fechamentos_rls on campanha_fechamentos for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

create table if not exists campanha_melhorias (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  titulo text not null check (length(btrim(titulo)) > 0),
  descricao text,
  origem text not null default 'manual' check (origem in ('manual', 'regra')),
  sprint text,
  status text not null default 'a_fazer' check (status in ('a_fazer', 'em_andamento', 'feito', 'descartado')),
  prazo date, responsavel text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists campanha_melhorias_camp on campanha_melhorias (campanha_id, status);
alter table campanha_melhorias enable row level security;
create policy campanha_melhorias_rls on campanha_melhorias for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
