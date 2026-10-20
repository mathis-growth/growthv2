-- v0.25 — Cálculos dos dashboards saem do navegador e vão para o banco.
-- Todas as funções são STABLE, checam pertence_ao_workspace e respeitam RLS.
-- (Já aplicadas no projeto de origem; este arquivo é o registro versionado.)

CREATE OR REPLACE FUNCTION public.campanha_series(p_ws uuid, p_campanha uuid, p_canal uuid DEFAULT NULL::uuid, p_acum boolean DEFAULT false, p_hoje date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare b record; cc record; utm text; v_meta numeric; ini date; fim_plan date; fim date; tot_dias int; meta_dia numeric; usa_trf boolean; roas numeric; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  select data_inicio, data_fim, meta_leads into b from campanhas where id = p_campanha and workspace_id = p_ws;
  if not found then return jsonb_build_object('dias', '[]'::jsonb, 'reais', '[]'::jsonb, 'metas', '[]'::jsonb, 'serie', '[]'::jsonb, 'roas', null); end if;
  if p_canal is not null then select utm_campaign, meta_leads into cc from campanha_canais where id = p_canal and campanha_id = p_campanha; utm := cc.utm_campaign; v_meta := cc.meta_leads;
  else v_meta := b.meta_leads; end if;
  ini := coalesce(b.data_inicio, (select min((criado_em at time zone 'America/Sao_Paulo')::date) from pessoas where workspace_id = p_ws and campanha_id = p_campanha and (p_canal is null or utm_campaign = utm)), p_hoje);
  fim_plan := b.data_fim;
  fim := case when fim_plan is not null and fim_plan < p_hoje then fim_plan else p_hoje end;
  if fim < ini then fim := ini; end if;
  if fim - ini > 399 then fim := ini + 399; end if;
  tot_dias := case when fim_plan is null then null else greatest(least(fim_plan - ini + 1, 400), 0) end;
  meta_dia := case when coalesce(v_meta, 0) > 0 and coalesce(tot_dias, 0) > 0 then v_meta / tot_dias end;
  select exists (select 1 from v_trafego_anuncio_dia where workspace_id = p_ws and campanha_id = p_campanha and data >= ini and (p_canal is null or utm_campaign = utm) and custo > 0) into usa_trf;
  with dias as (select (ini + i)::date as d, i from generate_series(0, fim - ini) i),
  lead_d as (select (criado_em at time zone 'America/Sao_Paulo')::date as d, count(*) as n from pessoas where workspace_id = p_ws and campanha_id = p_campanha and (p_canal is null or utm_campaign = utm) group by 1),
  inv_d as (select d, sum(v) as v from (
              select data as d, custo as v from v_trafego_anuncio_dia where usa_trf and workspace_id = p_ws and campanha_id = p_campanha and data >= ini and (p_canal is null or utm_campaign = utm)
              union all select competencia, valor from contas_pagar where not usa_trf and workspace_id = p_ws and campanha_id = p_campanha and status <> 'cancelado' and (p_canal is null or campanha_canal_id = p_canal)) x group by d),
  ven_d as (select (v.data_venda at time zone 'America/Sao_Paulo')::date as d, sum(v.valor_bruto) as rec, count(distinct v.pessoa_id) as cli
            from vendas v join pessoas pe on pe.id = v.pessoa_id where v.workspace_id = p_ws and v.campanha_id = p_campanha and v.status = 'aprovada' and (p_canal is null or pe.utm_campaign = utm) group by 1),
  base as (select d.d, d.i, coalesce(l.n, 0) as leads, coalesce(i.v, 0) as inv, coalesce(v.rec, 0) as rec, coalesce(v.cli, 0) as cli
           from dias d left join lead_d l on l.d = d.d left join inv_d i on i.d = d.d left join ven_d v on v.d = d.d),
  acc as (select *, sum(leads) over (order by i) as a_leads, sum(inv) over (order by i) as a_inv, sum(rec) over (order by i) as a_rec, sum(cli) over (order by i) as a_cli from base)
  select jsonb_build_object(
    'dias', jsonb_agg(d order by i),
    'reais', jsonb_agg(case when p_acum then a_leads else leads end order by i),
    'metas', jsonb_agg(case when meta_dia is null then null when p_acum then meta_dia * (i + 1) else meta_dia end order by i),
    'serie', jsonb_agg(jsonb_build_object(
        'inv', case when p_acum then a_inv else inv end, 'rec', case when p_acum then a_rec else rec end,
        'cpl', (case when p_acum then a_inv else inv end) / nullif(case when p_acum then a_leads else leads end, 0),
        'cac', (case when p_acum then a_inv else inv end) / nullif(case when p_acum then a_cli else cli end, 0)) order by i)) into r from acc;
  if p_canal is null then select receita_bruta / nullif(investimento, 0) into roas from v_marketing_campanha where campanha_id = p_campanha;
  else select receita_bruta / nullif(investimento, 0) into roas from v_marketing_canal where campanha_canal_id = p_canal; end if;
  return r || jsonb_build_object('roas', roas, 'meta_dia', meta_dia, 'tot_dias', tot_dias, 'usa_trafego', usa_trf);
end $function$;

CREATE OR REPLACE FUNCTION public.fin_dashboard(p_ws uuid, p_hoje date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare r jsonb; mes_atual text := to_char(p_hoje, 'YYYY-MM');
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  sd as (select nome, saldo_atual from v_saldo_contas_bancarias where workspace_id = p_ws order by nome),
  cx as (select coalesce(sum(saldo_atual), 0) as caixa, count(*) as n from sd),
  rp as (select cr.id, cr.valor, cr.vencimento, coalesce(pv.nome, pcn.nome, '—') as nome, coalesce(nullif(cr.descricao, ''), pr.nome, '') as descr
         from contas_receber cr left join vendas ve on ve.id = cr.venda_id left join pessoas pv on pv.id = ve.pessoa_id left join produtos pr on pr.id = ve.produto_id
              left join contratos ct on ct.id = cr.contrato_id left join pessoas pcn on pcn.id = ct.pessoa_id
         where cr.workspace_id = p_ws and cr.status = 'previsto'),
  pp as (select cp.id, cp.valor, cp.vencimento, cp.descricao, coalesce(fo.nome, '') as fornecedor
         from contas_pagar cp left join fornecedores fo on fo.id = cp.fornecedor_id where cp.workspace_id = p_ws and cp.status = 'previsto'),
  dias as (select i, p_hoje + i as d from generate_series(0, 30) i),
  proj as (select d.i, d.d, (select caixa from cx)
             + sum(coalesce((select sum(valor) from rp where case when d2.i = 0 then rp.vencimento <= d2.d else rp.vencimento = d2.d end), 0)
                 - coalesce((select sum(valor) from pp where case when d2.i = 0 then pp.vencimento <= d2.d else pp.vencimento = d2.d end), 0))
               over (order by d.i) as saldo
           from dias d join dias d2 on d2.i = d.i),
  dre as (select mes, tipo, conta, valor from v_dre_mensal where workspace_id = p_ws),
  mes_ as (select coalesce(sum(valor) filter (where tipo = 'receita'), 0) as rec, coalesce(sum(valor) filter (where tipo <> 'receita'), 0) as desp
           from dre where to_char(mes, 'YYYY-MM') = mes_atual)
  select jsonb_build_object(
    'caixa', (select caixa from cx), 'n_contas', (select n from cx),
    'a_receber', jsonb_build_object('valor', coalesce((select sum(valor) from rp), 0), 'qtd', (select count(*) from rp),
        'atraso', coalesce((select sum(valor) from rp where vencimento < p_hoje), 0)),
    'a_pagar', jsonb_build_object('valor', coalesce((select sum(valor) from pp), 0), 'qtd', (select count(*) from pp),
        'atraso', coalesce((select sum(valor) from pp where vencimento < p_hoje), 0)),
    'caixa_30d', (select saldo from proj where i = 30),
    'projecao', coalesce((select jsonb_agg(jsonb_build_object('d', d, 'saldo', saldo) order by i) from proj), '[]'),
    'receitas_mes', (select rec from mes_), 'despesas_mes', (select desp from mes_), 'resultado_mes', (select rec - desp from mes_),
    'pct_resultado_mes', case when (select rec from mes_) > 0 then (select rec - desp from mes_) / (select rec from mes_) end,
    'resultado_por_mes', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'resultado', rs) order by mes)
        from (select mes, sum(case when tipo = 'receita' then valor else -valor end) as rs from dre group by mes) x), '[]'),
    'proximos_receber', coalesce((select jsonb_agg(to_jsonb(x) order by x.vencimento) from (select nome, descr, valor, vencimento, vencimento < p_hoje as atr from rp order by vencimento limit 8) x), '[]'),
    'proximos_pagar', coalesce((select jsonb_agg(to_jsonb(x) order by x.vencimento) from (select descricao, fornecedor, valor, vencimento, vencimento < p_hoje as atr from pp order by vencimento limit 8) x), '[]'),
    'saldos', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'saldo', saldo_atual) order by nome) from sd), '[]'),
    'maiores_despesas', coalesce((select jsonb_agg(jsonb_build_object('conta', conta, 'valor', s) order by s desc)
        from (select conta, sum(valor) as s from dre where to_char(mes, 'YYYY-MM') = mes_atual and tipo <> 'receita' group by conta order by 2 desc limit 6) y), '[]')
  ) into r;
  return r;
end $function$;

CREATE OR REPLACE FUNCTION public.growth_metricas_auto(p_ws uuid, p_ini date, p_fim date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare leads bigint; nv bigint; receita numeric; clientes bigint; inv_t numeric; inv_c numeric; inv numeric;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  select count(*) into leads from pessoas where workspace_id = p_ws and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select count(*), coalesce(sum(valor_bruto), 0), count(distinct pessoa_id) into nv, receita, clientes from vendas
    where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select coalesce(sum(custo), 0) into inv_t from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim;
  select coalesce(sum(valor), 0) into inv_c from contas_pagar where workspace_id = p_ws and campanha_id is not null and status <> 'cancelado' and competencia between p_ini and p_fim;
  inv := case when inv_t > 0 then inv_t else inv_c end;
  return jsonb_build_object('receita', receita, 'leads', leads, 'investimento', inv, 'cpl', inv / nullif(leads, 0), 'vendas', nv,
    'ticket', receita / nullif(nv, 0), 'cac', inv / nullif(clientes, 0), 'roas', receita / nullif(inv, 0),
    'conv', case when leads > 0 then nv::numeric / leads * 100 end,
    'clientes_ativos', (select count(*) from pessoas where workspace_id = p_ws and status_funil = 'cliente' and status_cliente = 'ativo'));
end $function$;

CREATE OR REPLACE FUNCTION public.vendas_dashboard(p_ws uuid, p_hoje date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  pes as (select id, nome, email, status_funil, status_cliente, qualificacao, canal_origem, criado_em,
                 (criado_em at time zone 'America/Sao_Paulo')::date as dia from pessoas where workspace_id = p_ws),
  tot as (select count(*) as total, count(*) filter (where status_funil = 'lead') as leads, count(*) filter (where status_funil = 'cliente') as clientes,
                 count(*) filter (where status_funil = 'cliente' and status_cliente = 'ativo') as ativos,
                 count(*) filter (where qualificacao = 'qualificado') as qual, count(*) filter (where qualificacao = 'pendente') as pend,
                 count(*) filter (where dia >= p_hoje - 29) as novos, count(*) filter (where dia >= p_hoje - 59 and dia < p_hoje - 29) as ant from pes),
  ven as (select v.pessoa_id, v.valor_bruto, coalesce(pr.nome, '—') as produto from vendas v left join produtos pr on pr.id = v.produto_id where v.workspace_id = p_ws and v.status = 'aprovada'),
  vt as (select count(*) as n, coalesce(sum(valor_bruto), 0) as soma from ven)
  select jsonb_build_object(
    'total', (select total from tot), 'leads', (select leads from tot), 'clientes', (select clientes from tot), 'ativos', (select ativos from tot),
    'inativos', (select clientes - ativos from tot), 'qualificados', (select qual from tot), 'pendentes', (select pend from tot),
    'novos_30', (select novos from tot), 'anteriores_30', (select ant from tot),
    'variacao_30', case when (select ant from tot) > 0 then ((select novos from tot) - (select ant from tot))::numeric / (select ant from tot) end,
    'pct_qualificados', (select qual::numeric / nullif(total, 0) from tot),
    'conv_lead_cliente', (select clientes::numeric / nullif(total, 0) from tot),
    'ticket_medio', (select soma / nullif(n, 0) from vt), 'vendas_aprovadas', (select n from vt),
    'por_dia', (select jsonb_agg(jsonb_build_object('d', d, 'n', (select count(*) from pes where dia = d)) order by d) from (select (p_hoje - 29 + i)::date as d from generate_series(0, 29) i) x),
    'canais', coalesce((select jsonb_agg(to_jsonb(x) order by x.n desc) from (select coalesce(canal_origem, '(sem canal)') as c, count(*) as n,
        count(*) filter (where qualificacao = 'qualificado') as q, count(*) filter (where status_funil = 'cliente') as cl,
        count(*) filter (where status_funil = 'cliente')::numeric / nullif(count(*), 0) as conv
        from pes group by 1 order by 2 desc limit 8) x), '[]'),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('nome', produto, 'n', n) order by n desc) from (select produto, count(distinct pessoa_id) as n from ven group by 1 order by 2 desc limit 6) x), '[]'),
    'jornada', coalesce((select jsonb_agg(jsonb_build_object('funil', f.nome, 'etapas', e.arr) order by f.nome)
        from funis f join lateral (select jsonb_agg(jsonb_build_object('nome', fe.nome, 'n', (select count(*) from pessoa_funil pf where pf.etapa_id = fe.id)) order by fe.ordem) as arr
                                   from funil_etapas fe where fe.funil_id = f.id) e on e.arr is not null where f.workspace_id = p_ws), '[]'),
    'ultimos', coalesce((select jsonb_agg(to_jsonb(x) order by x.criado_em desc) from (select id, nome, email, canal_origem, status_funil, status_cliente, qualificacao, criado_em from pes order by criado_em desc limit 8) x), '[]')
  ) into r;
  return r;
end $function$;
