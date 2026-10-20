-- v0.49: Growth Model automático. O modelo é montado com os dados que já existem no sistema.
-- As tabelas manuais da v0.48 (gm_funis, gm_etapas, gm_valores, gm_config) deixam de ser usadas e ficam sem uso; não foram apagadas.

-- Ajustes de alavanca (baseline = correção do que o sistema calculou; sim = cenário)
create table if not exists gm_alavancas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  loop_chave text not null,
  produto_id uuid references produtos(id) on delete cascade,
  alavanca text not null,
  mes date not null,
  cenario text not null check (cenario in ('base','sim')),
  valor numeric not null,
  criado_em timestamptz not null default now()
);
create unique index if not exists gm_alavancas_uni on gm_alavancas (workspace_id, loop_chave, coalesce(produto_id,'00000000-0000-0000-0000-000000000000'::uuid), alavanca, mes, cenario);
alter table gm_alavancas enable row level security;
create policy gm_alavancas_acesso on gm_alavancas for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on gm_alavancas as restrictive for select using (perm(workspace_id, 'ler', '{gro,adm,mkt}'::text[]));
create policy perm_inserir on gm_alavancas as restrictive for insert with check (perm(workspace_id, 'editar', '{gro}'::text[]));
create policy perm_alterar on gm_alavancas as restrictive for update using (perm(workspace_id, 'editar', '{gro}'::text[])) with check (perm(workspace_id, 'editar', '{gro}'::text[]));
create policy perm_excluir on gm_alavancas as restrictive for delete using (perm(workspace_id, 'editar', '{gro}'::text[]));

-- Histórico mensal por loop, calculado do que existe no sistema (sem IA).
-- tipo do loop: campanha | organico | upgrade | recompra | contratos
create or replace function growth_modelo_historico(p_ws uuid, p_ini date, p_fim date)
returns jsonb language plpgsql stable set search_path = public as $$
declare r jsonb; v_ini date := date_trunc('month', p_ini)::date; v_fim date := (date_trunc('month', p_fim) + interval '1 month - 1 day')::date;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  meses as (select generate_series(v_ini, date_trunc('month', p_fim)::date, interval '1 month')::date m),
  va as (select v.id, v.pessoa_id, v.produto_id, v.campanha_id, (v.data_venda at time zone 'America/Sao_Paulo')::date d, v.valor_bruto
         from vendas v where v.workspace_id = p_ws and v.status = 'aprovada'),
  vc as (select a.*, date_trunc('month', a.d)::date m,
           exists (select 1 from va b where b.pessoa_id = a.pessoa_id and b.id <> a.id and b.d < a.d) tem_ant,
           exists (select 1 from va b where b.pessoa_id = a.pessoa_id and b.id <> a.id and b.d < a.d and b.produto_id = a.produto_id) mesmo
         from va a where a.d between v_ini and v_fim),
  pl as (select p.campanha_id, date_trunc('month', (p.criado_em at time zone 'America/Sao_Paulo')::date)::date m, count(*) led,
           count(*) filter (where p.qualificacao = 'qualificado') qua
         from pessoas p where p.workspace_id = p_ws and p.captada and (p.criado_em at time zone 'America/Sao_Paulo')::date between v_ini and v_fim group by 1, 2),
  tr as (select t.campanha_id, date_trunc('month', t.data)::date m, sum(t.impressoes) imp, sum(t.cliques) clk, sum(t.custo) custo, sum(t.visualizacoes_pagina) vis
         from v_trafego_anuncio_dia t where t.workspace_id = p_ws and t.campanha_id is not null and t.data between v_ini and v_fim group by 1, 2),
  cp as (select z.campanha_id, date_trunc('month', z.competencia)::date m, sum(z.v) v from (
           select campanha_id, competencia, valor v from contas_pagar where workspace_id = p_ws and campanha_id is not null and status <> 'cancelado'
           union all select campanha_id, competencia, valor from custos_cac where workspace_id = p_ws and campanha_id is not null) z
         where z.competencia between v_ini and v_fim group by 1, 2),
  camp_loops as (
    select 'campanha:' || c.id loop, c.nome, 'aquisicao' fase, 'campanha' tipo, c.produto_id, c.id campanha_id, ms.m,
      coalesce(nullif(tr.custo, 0), cp.v, 0) inv, coalesce(tr.imp, 0) imp, coalesce(tr.clk, 0) clk, coalesce(tr.vis, 0) vis,
      coalesce(pl.led, 0) led, coalesce(pl.qua, 0) qua,
      coalesce((select count(*) from vc where vc.campanha_id = c.id and vc.m = ms.m), 0) cli,
      coalesce((select sum(valor_bruto) from vc where vc.campanha_id = c.id and vc.m = ms.m), 0) rec, 0::numeric base
    from campanhas c cross join meses ms
      left join tr on tr.campanha_id = c.id and tr.m = ms.m left join cp on cp.campanha_id = c.id and cp.m = ms.m left join pl on pl.campanha_id = c.id and pl.m = ms.m
    where c.workspace_id = p_ws),
  org_leads as (
    select 'organico', 'Orgânico e direto (sem campanha)', 'aquisicao', 'organico', null::uuid, null::uuid, pl.m, 0::numeric, 0::numeric, 0::numeric, 0::numeric, pl.led::numeric, pl.qua::numeric, 0::numeric, 0::numeric, 0::numeric
    from pl where pl.campanha_id is null),
  org_vendas as (
    select 'organico', 'Orgânico e direto (sem campanha)', 'aquisicao', 'organico', vc.produto_id, null::uuid, vc.m, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, count(*)::numeric, sum(vc.valor_bruto), 0::numeric
    from vc where vc.campanha_id is null and not vc.tem_ant group by vc.produto_id, vc.m),
  ret_vendas as (
    select case when vc.mesmo then 'recompra' else 'upgrade' end, case when vc.mesmo then 'Recompra / renovação do mesmo produto' else 'Upgrade: cliente que já comprou outro produto' end,
      'retencao', case when vc.mesmo then 'recompra' else 'upgrade' end, vc.produto_id, null::uuid, vc.m, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, count(*)::numeric, sum(vc.valor_bruto),
      (select count(distinct b.pessoa_id) from va b where b.d < vc.m and ((vc.mesmo and b.produto_id = vc.produto_id) or (not vc.mesmo and b.produto_id <> vc.produto_id
         and not exists (select 1 from va c2 where c2.pessoa_id = b.pessoa_id and c2.produto_id = vc.produto_id and c2.d < vc.m))))::numeric
    from vc where vc.campanha_id is null and vc.tem_ant group by vc.mesmo, vc.produto_id, vc.m),
  itens as (select ci.contrato_id, ci.produto_id, (ci.quantidade * ci.valor) tot, sum(ci.quantidade * ci.valor) over (partition by ci.contrato_id) soma from contrato_itens ci where ci.workspace_id = p_ws),
  ct_rec as (select it.produto_id, date_trunc('month', cr.vencimento)::date m, sum(cr.valor * case when it.soma > 0 then it.tot / it.soma else 0 end) rec
    from contas_receber cr join itens it on it.contrato_id = cr.contrato_id
    where cr.workspace_id = p_ws and cr.contrato_id is not null and cr.status <> 'cancelado' and cr.substituida_por is null and cr.vencimento between v_ini and v_fim group by 1, 2),
  ct_ativos as (select it.produto_id, ms.m, count(distinct c.id) n from meses ms join contratos c on c.workspace_id = p_ws and c.ativado_em is not null
      and (c.ativado_em at time zone 'America/Sao_Paulo')::date < (ms.m + interval '1 month')::date and (c.cancelado_em is null or (c.cancelado_em at time zone 'America/Sao_Paulo')::date >= ms.m)
    join itens it on it.contrato_id = c.id group by 1, 2),
  ct_loops as (
    select 'contratos', 'Contratos de serviço (recorrência)', 'retencao', 'contratos', coalesce(a.produto_id, r.produto_id), null::uuid, coalesce(a.m, r.m), 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric,
      coalesce(a.n, 0)::numeric, coalesce(r.rec, 0), 0::numeric
    from ct_ativos a full join ct_rec r on r.produto_id = a.produto_id and r.m = a.m),
  todos as (
    select * from camp_loops union all select * from org_leads union all select * from org_vendas union all select * from ret_vendas union all select * from ct_loops)
  select coalesce(jsonb_agg(jsonb_build_object('loop', t.loop, 'nome', t.nome, 'fase', t.fase, 'tipo', t.tipo, 'produto_id', t.produto_id, 'campanha_id', t.campanha_id,
      'mes', t.m, 'inv', t.inv, 'imp', t.imp, 'clk', t.clk, 'vis', t.vis, 'led', t.led, 'qua', t.qua, 'cli', t.cli, 'rec', t.rec, 'base', t.base) order by t.fase, t.loop, t.m), '[]'::jsonb)
  into r
  from todos t(loop, nome, fase, tipo, produto_id, campanha_id, m, inv, imp, clk, vis, led, qua, cli, rec, base)
  where (t.inv + t.imp + t.clk + t.vis + t.led + t.qua + t.cli + t.rec + t.base) <> 0;
  return r;
end $$;
