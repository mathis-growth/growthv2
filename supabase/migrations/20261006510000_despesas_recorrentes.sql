-- v0.34: contas recorrentes (fixa, variável e parcelada com início/fim). JÁ APLICADA no projeto.
create table if not exists despesas_recorrentes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  fornecedor_id uuid not null references fornecedores(id),
  descricao text not null,
  tipo text not null check (tipo in ('fixa','variavel','parcelada')),
  valor numeric(14,2) not null check (valor > 0),
  parcelas integer check (parcelas is null or parcelas between 2 and 120),
  data_inicio date not null,
  data_fim date,
  conta_despesa_id uuid not null references plano_contas(id),
  centro_custo_id uuid references centros_custo(id),
  forma_pagamento_id uuid references formas_pagamento(id) on delete set null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  check (tipo <> 'parcelada' or (parcelas is not null and data_fim is null)),
  check (tipo = 'parcelada' or parcelas is null),
  check (data_fim is null or data_fim >= data_inicio)
);
comment on column despesas_recorrentes.valor is 'Fixa: valor mensal. Variável: valor de partida da estimativa. Parcelada: valor TOTAL (centavos; sobra na última parcela).';
create index if not exists despesas_recorrentes_ix on despesas_recorrentes (workspace_id, ativo);
alter table despesas_recorrentes enable row level security;
create policy despesas_recorrentes_acesso on despesas_recorrentes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on despesas_recorrentes as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['fin','adm']));
create policy perm_inserir on despesas_recorrentes as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', array['fin']));
create policy perm_alterar on despesas_recorrentes as restrictive for update to authenticated using (perm(workspace_id, 'editar', array['fin'])) with check (perm(workspace_id, 'editar', array['fin']));
create policy perm_excluir on despesas_recorrentes as restrictive for delete to authenticated using (perm(workspace_id, 'editar', array['fin']));
alter table contas_pagar add column if not exists recorrencia_id uuid references despesas_recorrentes(id) on delete set null;
create unique index if not exists contas_pagar_recorrencia_uq on contas_pagar (recorrencia_id, competencia) where recorrencia_id is not null and status <> 'cancelado';

-- função provisionar_recorrencias: ver definição aplicada no banco (pg_get_functiondef) — gera fixa/variável (próximos meses, respeitando data_fim) e parcelada (todas as parcelas), idempotente por (recorrencia_id, competência).

alter table fornecedores add column if not exists recorrencia text check (recorrencia is null or recorrencia in ('fixa','variavel','parcelada'));
alter table fornecedores add column if not exists parcelas integer check (parcelas is null or parcelas between 2 and 120);
alter table fornecedores add column if not exists data_inicio date;
alter table fornecedores add column if not exists data_fim date;
alter table despesas_recorrentes add column if not exists do_fornecedor boolean not null default false;
create unique index if not exists despesas_recorrentes_forn_uq on despesas_recorrentes (fornecedor_id) where do_fornecedor;
-- A função provisionar_recorrencias também lê a recorrência do cadastro do fornecedor e a espelha em despesas_recorrentes (do_fornecedor = true).

-- v0.34 (aplicado): fornecedor_id opcional na recorrência; confirmar_valor_conta_pagar passa a copiar recorrencia_id;
-- provisionar_recorrencias não regera mês cuja conta foi cancelada (checa só recorrencia_id + competência).
alter table despesas_recorrentes alter column fornecedor_id drop not null;
