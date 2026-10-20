-- v0.39: parcelas personalizadas no contrato (valor e vencimento de cada parcela, ex.: entrada + 2x). JÁ APLICADA no projeto.
create table if not exists contrato_parcelas_plano (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  contrato_id uuid not null references contratos(id) on delete cascade,
  numero int not null check (numero >= 1),
  valor numeric(14,2) not null check (valor > 0),
  vencimento date not null,
  unique (contrato_id, numero)
);
alter table contrato_parcelas_plano enable row level security;
create policy contrato_parcelas_plano_rls on contrato_parcelas_plano for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_alterar on contrato_parcelas_plano as restrictive for update using (perm(workspace_id,'editar',array['vendas'])) with check (perm(workspace_id,'editar',array['vendas']));
create policy perm_excluir on contrato_parcelas_plano as restrictive for delete using (perm(workspace_id,'editar',array['vendas']));
create policy perm_inserir on contrato_parcelas_plano as restrictive for insert with check (perm(workspace_id,'editar',array['vendas']));
create policy perm_ler on contrato_parcelas_plano as restrictive for select using (perm(workspace_id,'ler',array['vendas','fin','adm','prj','revops']));
-- ativar_contrato: se o contrato não é recorrente e tem plano, usa os valores/datas do plano (precisa ter num_parcelas linhas e somar o total).
