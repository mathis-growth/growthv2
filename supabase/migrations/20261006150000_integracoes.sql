create table integracoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  provedor text not null,
  categoria text not null check (categoria in ('anuncios', 'video', 'vendas', 'mensageria', 'outro')),
  status text not null default 'configurando' check (status in ('configurando', 'conectado', 'erro', 'desconectado')),
  conta_externa text,
  observacao text,
  ultima_sincronizacao timestamptz,
  criado_em timestamptz not null default now(),
  unique (workspace_id, provedor)
);
comment on table integracoes is 'Registro das integrações do workspace. Não guarda senha, token nem chave: segredos ficam nos segredos da função de borda.';
alter table integracoes enable row level security;
create policy integracoes_acesso on integracoes for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
