-- v0.42: oportunidades de novos negócios com clientes. JÁ APLICADA no projeto.
alter table etapas_kanban drop constraint if exists etapas_kanban_quadro_check;
alter table etapas_kanban add constraint etapas_kanban_quadro_check check (quadro = any (array['leads','alunos','oportunidades']));
create table if not exists oportunidades (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  titulo text not null,
  tipo text not null default 'nova_venda' check (tipo in ('nova_venda','renovacao','ajuste')),
  produto_id uuid references produtos(id) on delete set null,
  contrato_origem_id uuid references contratos(id) on delete set null,
  valor_estimado numeric(14,2) check (valor_estimado is null or valor_estimado >= 0),
  previsao_fechamento date,
  etapa_kanban_id uuid references etapas_kanban(id) on delete restrict,
  status text not null default 'aberta' check (status in ('aberta','ganha','perdida')),
  motivo text,
  responsavel_id uuid references equipe(id) on delete set null,
  observacoes text,
  criado_em timestamptz not null default now(),
  fechado_em timestamptz
);
create index if not exists oportunidades_ws_idx on oportunidades (workspace_id, status);
create index if not exists oportunidades_pessoa_idx on oportunidades (pessoa_id);
alter table oportunidades enable row level security;
create policy oportunidades_rls on oportunidades for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_alterar on oportunidades as restrictive for update using (perm(workspace_id,'editar',array['vendas'])) with check (perm(workspace_id,'editar',array['vendas']));
create policy perm_excluir on oportunidades as restrictive for delete using (perm(workspace_id,'editar',array['vendas']));
create policy perm_inserir on oportunidades as restrictive for insert with check (perm(workspace_id,'editar',array['vendas']));
create policy perm_ler on oportunidades as restrictive for select using (perm(workspace_id,'ler',array['vendas','fin','adm','prj','revops']));
-- Etapas padrão (Conversa inicial, Proposta enviada, Negociação, Decisão) são criadas pela tela na primeira abertura de cada workspace.
