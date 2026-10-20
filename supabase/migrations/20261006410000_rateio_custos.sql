-- v0.24: rateio de custos entre centros de custo (como a distribuição do SAP) e CAC só com a parte de aquisição.
alter table centros_custo add column if not exists entra_no_cac boolean not null default true;
comment on column centros_custo.entra_no_cac is 'Se false, a parte do custo rateada para este centro não entra no CAC (ex.: CS, administrativo).';

create table if not exists rateio_regras (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null, descricao text, ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (workspace_id, nome));
create table if not exists rateio_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  regra_id uuid not null references rateio_regras(id) on delete cascade,
  centro_custo_id uuid not null references centros_custo(id) on delete restrict,
  percentual numeric(7,4) not null check (percentual > 0 and percentual <= 100),
  unique (regra_id, centro_custo_id));
alter table contas_pagar add column if not exists rateio_regra_id uuid references rateio_regras(id) on delete set null;
alter table plano_contas add column if not exists rateio_regra_id uuid references rateio_regras(id) on delete set null;

alter table rateio_regras enable row level security; alter table rateio_itens enable row level security;
do $$ declare t text; begin
  foreach t in array array['rateio_regras','rateio_itens'] loop
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id))', t || '_leitura', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (pode_operar(workspace_id))', t || '_insercao', t);
    execute format('create policy %I on public.%I for update to authenticated using (pode_operar(workspace_id)) with check (pode_operar(workspace_id))', t || '_edicao', t);
    execute format('create policy %I on public.%I for delete to authenticated using (pode_operar(workspace_id))', t || '_exclusao', t);
    execute format('create policy perm_ler on public.%I as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''fin'',''adm'',''mkt'',''cad'']))', t);
    execute format('create policy perm_inserir on public.%I as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''fin'',''cad'']))', t);
    execute format('create policy perm_alterar on public.%I as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''fin'',''cad''])) with check (perm(workspace_id, ''editar'', array[''fin'',''cad'']))', t);
    execute format('create policy perm_excluir on public.%I as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''fin'',''cad'']))', t);
  end loop; end $$;

-- (A soma de 100% é conferida na tela; no banco, a view abaixo só usa regras ativas que somam exatamente 100%.)
create or replace view v_rateio_regras with (security_invoker = true) as
select r.id, r.workspace_id, r.nome, r.descricao, r.ativo, coalesce(sum(i.percentual), 0) as soma_percentual, count(i.id) as itens
from rateio_regras r left join rateio_itens i on i.regra_id = r.id group by r.id;
grant select on v_rateio_regras to authenticated;

-- Cada conta a pagar dividida pela regra (da conta ou, se não houver, a padrão da conta contábil). Sem regra: 100% no centro da própria conta.
create or replace view v_custos_rateados with (security_invoker = true) as
select cp.id as conta_pagar_id, cp.workspace_id, cp.competencia, cp.vencimento, cp.status, cp.campanha_id, cp.fornecedor_id,
  cp.descricao, pc.codigo as conta_codigo, pc.nome as conta_nome, pc.cac_grupo,
  r.id as regra_id, r.nome as regra_nome,
  coalesce(i.centro_custo_id, cp.centro_custo_id) as centro_custo_id, cc.nome as centro_nome,
  coalesce(cc.entra_no_cac, true) as entra_no_cac,
  coalesce(i.percentual, 100) as percentual,
  cp.valor * coalesce(i.percentual, 100) / 100 as valor, cp.valor as valor_total
from contas_pagar cp
left join plano_contas pc on pc.id = cp.conta_despesa_id
left join (select r0.* from rateio_regras r0 where r0.ativo and (select coalesce(sum(percentual), 0) from rateio_itens x where x.regra_id = r0.id) = 100) r
  on r.id = coalesce(cp.rateio_regra_id, pc.rateio_regra_id)
left join rateio_itens i on i.regra_id = r.id
left join centros_custo cc on cc.id = coalesce(i.centro_custo_id, cp.centro_custo_id);
grant select on v_custos_rateados to authenticated;

-- Centros úteis para o rateio (só no Demo e só se ainda não existirem).
insert into centros_custo (workspace_id, codigo, nome, entra_no_cac)
select w.id, x.c, x.n, x.cac from workspaces w, (values ('MKT','Marketing',true),('COM','Comercial',true),('CS','Sucesso do cliente',false),('ADM','Administrativo',false)) x(c,n,cac)
where w.nome = 'Growths — Demo' and not exists (select 1 from centros_custo c where c.workspace_id = w.id and c.codigo = x.c);
