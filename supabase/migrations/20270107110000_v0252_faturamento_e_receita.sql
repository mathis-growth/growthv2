-- v0.252 — Faturamento e Receita líquida separados; ROAS sobre o Faturamento.
-- Regras decididas em 03/11/2026:
--   Faturamento = valor total das vendas aprovadas − vendas de quem saiu;
--   Receita líquida = valor líquido (já sem taxas e impostos) − comissões, sem as vendas de quem saiu;
--   ROAS = Faturamento ÷ investimento de mídia; ticket médio = valor das vendas ÷ vendas.
-- A coluna "receita" das visões passa a descontar também as comissões. O financeiro não muda.
-- Trocas de texto nas funções, com erro se o trecho não for encontrado. Rode depois de 20270106100000_v0251_cac_roas_receita.sql. Idempotente.

-- ---------- 1. uma linha por venda, com as três partes ----------
create or replace view public.v_vendas_mkt with (security_invoker = true) as
  select v.id, v.workspace_id, v.pessoa_id, v.campanha_id, v.status, v.data_venda, v.valor_bruto, coalesce(v.valor_liquido, v.valor_bruto) as liquido, coalesce(cm.valor, 0::numeric) as comissao, s.pessoa_id is not null as saiu
  from vendas v left join v_pessoas_saiu s on s.pessoa_id = v.pessoa_id
    left join (select venda_id, sum(valor) as valor from comissoes where venda_id is not null and status not in ('cancelada', 'estorno_pendente', 'estornada') group by venda_id) cm on cm.venda_id = v.id;
grant select on public.v_vendas_mkt to authenticated;

-- ---------- 2. visões ----------
create or replace view public.v_marketing_campanha with (security_invoker = true) as
 with ads as (
   select cc.campanha_id, sum(m.custo) as v from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id group by cc.campanha_id having sum(m.custo) > 0
 ), lan as (
   select x.campanha_id, sum(x.valor) as v from (
     select campanha_id, valor from contas_pagar where status <> 'cancelado' and campanha_id is not null
     union all select campanha_id, valor from custos_cac where campanha_id is not null) x group by x.campanha_id
 ), ld as (
   select campanha_id, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados from pessoas where campanha_id is not null group by campanha_id
 ), vd as (
   select v.campanha_id, count(*) as vendas, sum(v.valor_bruto) as receita_bruta, count(distinct v.pessoa_id) as clientes,
     coalesce(sum(v.liquido - v.comissao) filter (where not v.saiu), 0) as receita,
     coalesce(sum(v.liquido - v.comissao) filter (where v.saiu), 0) as receita_saiu,
     sum(v.liquido - v.comissao) as receita_antes_churn,
     count(distinct v.pessoa_id) filter (where v.saiu) as pessoas_saiu,
     coalesce(sum(v.valor_bruto) filter (where not v.saiu), 0) as faturamento,
     coalesce(sum(v.valor_bruto) filter (where v.saiu), 0) as faturamento_saiu,
     sum(v.comissao) as comissoes
   from v_vendas_mkt v where v.campanha_id is not null and v.status = 'aprovada' group by v.campanha_id
 ), i as (
   select c.id, coalesce(ads.v, lan.v, 0) as v from campanhas c left join ads on ads.campanha_id = c.id left join lan on lan.campanha_id = c.id
 )
 select c.id as campanha_id, c.workspace_id, c.nome, c.status, c.orcamento_total, c.meta_leads, c.meta_vendas, c.meta_receita, c.meta_cac,
   i.v as investimento, coalesce(ld.leads, 0::bigint) as leads, coalesce(ld.qualificados, 0::bigint) as qualificados, coalesce(vd.vendas, 0::bigint) as vendas, coalesce(vd.clientes, 0::bigint) as clientes,
   coalesce(vd.receita_bruta, 0::numeric) as receita_bruta,
   round(i.v / nullif(ld.leads, 0)::numeric, 2) as cpl,
   round(i.v / nullif(vd.vendas, 0)::numeric, 2) as cac,
   round(vd.faturamento / nullif(i.v, 0::numeric), 2) as roas,
   round(vd.vendas::numeric * 100::numeric / nullif(ld.leads, 0)::numeric, 2) as taxa_lead_venda,
   coalesce(vd.receita, 0::numeric) as receita, coalesce(vd.receita_saiu, 0::numeric) as receita_saiu, coalesce(vd.receita_antes_churn, 0::numeric) as receita_antes_churn, coalesce(vd.pessoas_saiu, 0::bigint) as pessoas_saiu,
   coalesce(vd.faturamento, 0::numeric) as faturamento, coalesce(vd.faturamento_saiu, 0::numeric) as faturamento_saiu, coalesce(vd.comissoes, 0::numeric) as comissoes
 from campanhas c join i on i.id = c.id left join ld on ld.campanha_id = c.id left join vd on vd.campanha_id = c.id;

create or replace view public.v_marketing_canal with (security_invoker = true) as
 with ads as (
   select a.campanha_canal_id, sum(m.custo) as v from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id where a.campanha_canal_id is not null group by a.campanha_canal_id having sum(m.custo) > 0
 ), lan as (
   select x.campanha_canal_id, sum(x.valor) as v from (
     select campanha_canal_id, valor from contas_pagar where status <> 'cancelado' and campanha_canal_id is not null
     union all select campanha_canal_id, valor from custos_cac where campanha_canal_id is not null) x group by x.campanha_canal_id
 ), ld as (
   select workspace_id, utm_campaign, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados from pessoas where utm_campaign is not null group by workspace_id, utm_campaign
 ), vd as (
   select p.workspace_id, p.utm_campaign, count(*) as vendas, sum(v.valor_bruto) as receita_bruta, count(distinct v.pessoa_id) as clientes,
     coalesce(sum(v.liquido - v.comissao) filter (where not v.saiu), 0) as receita,
     coalesce(sum(v.valor_bruto) filter (where not v.saiu), 0) as faturamento
   from v_vendas_mkt v join pessoas p on p.id = v.pessoa_id where p.utm_campaign is not null and v.status = 'aprovada' group by p.workspace_id, p.utm_campaign
 )
 select cc.id as campanha_canal_id, cc.workspace_id, cc.campanha_id, c.nome as campanha, cc.canal, cc.utm_campaign, cc.orcamento, cc.meta_leads, cc.meta_vendas, cc.meta_cac,
   coalesce(ads.v, lan.v, 0::numeric) as investimento, coalesce(ld.leads, 0::bigint) as leads, coalesce(ld.qualificados, 0::bigint) as qualificados, coalesce(vd.vendas, 0::bigint) as vendas, coalesce(vd.clientes, 0::bigint) as clientes,
   coalesce(vd.receita_bruta, 0::numeric) as receita_bruta,
   round(coalesce(ads.v, lan.v, 0::numeric) / nullif(ld.leads, 0)::numeric, 2) as cpl,
   round(coalesce(ads.v, lan.v, 0::numeric) / nullif(vd.vendas, 0)::numeric, 2) as cac,
   coalesce(vd.receita, 0::numeric) as receita,
   round(vd.faturamento / nullif(coalesce(ads.v, lan.v, 0::numeric), 0::numeric), 2) as roas,
   coalesce(vd.faturamento, 0::numeric) as faturamento
 from campanha_canais cc join campanhas c on c.id = cc.campanha_id left join ads on ads.campanha_canal_id = cc.id left join lan on lan.campanha_canal_id = cc.id
   left join ld on ld.workspace_id = cc.workspace_id and ld.utm_campaign = cc.utm_campaign left join vd on vd.workspace_id = cc.workspace_id and vd.utm_campaign = cc.utm_campaign;

-- ---------- 3. funções: troca de texto ----------
create or replace function public._v0252_troca(p_sig text, p_pares text[]) returns void language plpgsql as $f$
declare def text; i int;
begin
  select pg_get_functiondef(p_sig::regprocedure) into def; def := replace(def, E'\r\n', E'\n');
  if position('v0.252' in def) > 0 then return; end if;
  for i in 1 .. array_length(p_pares, 1) / 2 loop
    if position(p_pares[2 * i - 1] in def) = 0 then raise exception 'v0.252: trecho não encontrado em %: %', p_sig, left(p_pares[2 * i - 1], 80); end if;
    def := replace(def, p_pares[2 * i - 1], p_pares[2 * i]);
  end loop;
  if position('-- v0.251' in def) = 0 then raise exception 'v0.252: sem a marca da v0.251 em %', p_sig; end if;
  def := replace(def, '-- v0.251', E'-- v0.251\n-- v0.252');
  execute def;
end $f$;

do $m$ begin
  perform _v0252_troca('public.funil_analise(uuid,date,date,uuid,uuid)', array[
    'coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as receita, coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)), 0) as receita_antes_churn from co join vendas v on v.pessoa_id = co.id and v.status = ''aprovada'' group by co.campanha_id',
    'coalesce(sum(v.liquido - v.comissao) filter (where not v.saiu), 0) as receita, coalesce(sum(v.valor_bruto) filter (where not v.saiu), 0) as faturamento, coalesce(sum(v.valor_bruto), 0) as faturamento_antes_churn from co join v_vendas_mkt v on v.pessoa_id = co.id and v.status = ''aprovada'' group by co.campanha_id',
    '''receita_antes_churn'', coalesce(rec.receita_antes_churn, 0),', '''faturamento'', coalesce(rec.faturamento, 0), ''faturamento_antes_churn'', coalesce(rec.faturamento_antes_churn, 0),',
    '''roas'', case when coalesce(cus.custo, 0) > 0 then round(coalesce(rec.receita, 0) / cus.custo, 2) end,', '''roas'', case when coalesce(cus.custo, 0) > 0 then round(coalesce(rec.faturamento, 0) / cus.custo, 2) end,',
    '''receita_antes_churn'', sum((x ->> ''receita_antes_churn'')::numeric),', '''faturamento'', sum((x ->> ''faturamento'')::numeric), ''faturamento_antes_churn'', sum((x ->> ''faturamento_antes_churn'')::numeric),',
    'round((r_pos ->> ''receita'')::numeric / (r_pos ->> ''custo'')::numeric, 2)', 'round((r_pos ->> ''faturamento'')::numeric / (r_pos ->> ''custo'')::numeric, 2)'
  ]);
  perform _v0252_troca('public.funil_cohorts(uuid,date,date,uuid,text)', array[
    'count(*) as vendas, coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as receita',
    'count(*) as vendas, coalesce(sum(v.liquido - v.comissao) filter (where not v.saiu), 0) as receita, coalesce(sum(v.valor_bruto) filter (where not v.saiu), 0) as faturamento',
    'from vendas v where v.workspace_id = p_ws and v.status = ''aprovada'' group by v.pessoa_id)', 'from v_vendas_mkt v where v.workspace_id = p_ws and v.status = ''aprovada'' group by v.pessoa_id)',
    'coalesce(sum(pv.vendas), 0) as vendas, coalesce(sum(pv.receita), 0) as receita,', 'coalesce(sum(pv.vendas), 0) as vendas, coalesce(sum(pv.receita), 0) as receita, coalesce(sum(pv.faturamento), 0) as faturamento,',
    '''clientes'', g.clientes, ''receita'', g.receita,', '''clientes'', g.clientes, ''receita'', g.receita, ''faturamento'', g.faturamento,',
    '''ltv'', case when g.clientes > 0 then round(g.receita / g.clientes, 2) end,', '''ltv'', case when g.clientes > 0 then round(g.faturamento / g.clientes, 2) end,',
    '''roas'', case when coalesce(cu.custo, 0) > 0 then round(g.receita / cu.custo, 2) end,', '''roas'', case when coalesce(cu.custo, 0) > 0 then round(g.faturamento / cu.custo, 2) end,'
  ]);
  perform _v0252_troca('public.vendas_por_canal(uuid,date,date,text,uuid)', array[
    'then 0 else coalesce(v.valor_liquido, v.valor_bruto) end as valor_mkt,', 'then 0 else v.valor_bruto end as valor_mkt,'
  ]);
  perform _v0252_troca('public._meta_realizado(campanhas,campanha_metas,date,date)', array[
    'vend numeric; rec numeric;', 'vend numeric; rec numeric; bru numeric;',
    'coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0), count(distinct v.pessoa_id) into vend, rec, cli',
    'coalesce(sum(v.valor_bruto) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0), coalesce(sum(v.valor_bruto), 0), count(distinct v.pessoa_id) into vend, rec, bru, cli',
    'when ''ticket_medio'' then case when vend > 0 then round(rec / vend, 2) end', 'when ''ticket_medio'' then case when vend > 0 then round(bru / vend, 2) end'
  ]);
  perform _v0252_troca('public.campanha_detalhe(uuid,date)', array[
    'then 0 else coalesce(v.valor_liquido, v.valor_bruto) end as valor_bruto,', 'then 0 else v.valor_bruto end as valor_bruto,'
  ]);
  perform _v0252_troca('public.growth_metricas_auto(uuid,date,date)', array[
    'coalesce(sum(coalesce(valor_liquido, valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = vendas.pessoa_id)), 0), count(distinct pessoa_id) into nv, receita, clientes from vendas',
    'coalesce(sum(valor_bruto) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = vendas.pessoa_id)), 0), count(distinct pessoa_id) into nv, receita, clientes from vendas',
    '''ticket'', (select sum(coalesce(valor_liquido, valor_bruto)) from vendas', '''ticket'', (select sum(valor_bruto) from vendas'
  ]);
  perform _v0252_troca('public.campanha_series(uuid,uuid,uuid,boolean,date)', array[
    'coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as rec,', 'coalesce(sum(v.valor_bruto) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as rec,',
    'select receita / nullif(investimento, 0) into roas from v_marketing_campanha', 'select faturamento / nullif(investimento, 0) into roas from v_marketing_campanha',
    'select receita / nullif(investimento, 0) into roas from v_marketing_canal', 'select faturamento / nullif(investimento, 0) into roas from v_marketing_canal'
  ]);
  perform _v0252_troca('public._arv_extra2(uuid,text,jsonb)', array[
    'select v.investimento, v.vendas, v.receita into inv, cli, rb from v_marketing_campanha v', 'select v.investimento, v.vendas, v.faturamento into inv, cli, rb from v_marketing_campanha v',
    'Receita sem o churn ÷ investimento em anúncios da campanha.', 'Faturamento (valor das vendas, sem as de quem saiu) ÷ investimento em anúncios da campanha.',
    '_arv_item(''Receita sem o churn'', rb, ''ven.soma'', jsonb_build_object(''campanha'', camp, ''campo'', ''liquido''))', '_arv_item(''Faturamento'', rb, ''ven.soma'', jsonb_build_object(''campanha'', camp, ''campo'', ''bruto''))'
  ]);
end $m$;

-- detalhe do CAC e do ROAS: a mesma conta dos cards
create or replace function public._arv_mkt_norm(p_ws uuid, p_no text, par jsonb) returns jsonb language plpgsql stable set search_path = public as $f$
declare camp uuid := nullif(par ->> 'campanha', '')::uuid; ini date := nullif(par ->> 'ini', '')::date; fim date := nullif(par ->> 'fim', '')::date;
  inv numeric; ven numeric; fat numeric; ant numeric; base jsonb; porcamp boolean := camp is not null and ini is null; ads boolean;
begin
  if porcamp then
    select v.investimento, v.vendas, v.faturamento, v.receita_bruta into inv, ven, fat, ant from v_marketing_campanha v where v.campanha_id = camp and v.workspace_id = p_ws;
    ads := campanha_tem_anuncio(camp); base := jsonb_build_object('campanha', camp);
  else
    select count(*), coalesce(sum(v.valor_bruto) filter (where not v.saiu), 0), coalesce(sum(v.valor_bruto), 0) into ven, fat, ant
      from pessoas p join v_vendas_mkt v on v.pessoa_id = p.id and v.status = 'aprovada'
     where p.captada and p.workspace_id = p_ws and (camp is null or p.campanha_id = camp)
       and (ini is null or p.criado_em >= (ini::timestamp at time zone 'America/Sao_Paulo')) and (fim is null or p.criado_em < ((fim + 1)::timestamp at time zone 'America/Sao_Paulo'));
    select coalesce(sum(z.v), 0) into inv from (
      select m.custo as v from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id where m.workspace_id = p_ws and (ini is null or m.data >= ini) and (fim is null or m.data <= fim) and (camp is null or cc.campanha_id = camp)
      union all select cp.valor from contas_pagar cp where cp.workspace_id = p_ws and cp.status <> 'cancelado' and cp.campanha_id is not null and (ini is null or cp.competencia >= ini) and (fim is null or cp.competencia <= fim) and (camp is null or cp.campanha_id = camp) and not campanha_tem_anuncio(cp.campanha_id)
      union all select cu.valor from custos_cac cu where cu.workspace_id = p_ws and cu.campanha_id is not null and (ini is null or cu.competencia >= ini) and (fim is null or cu.competencia <= fim) and (camp is null or cu.campanha_id = camp) and not campanha_tem_anuncio(cu.campanha_id)) z;
    ads := true; base := par - 'campo';
  end if;
  if p_no = 'mkt.cac' then
    return jsonb_build_object('titulo', 'CAC de mídia', 'valor', case when ven > 0 then inv / ven end, 'un', 'brl', 'explica', 'Investimento em anúncios ÷ vendas. Order bump e upsell contam como venda. O CAC total, com equipe, fica nos números do negócio.',
      'formula', jsonb_build_array(case when ads then _arv_item('Investimento em anúncios', inv, 'mkt.ads', base || '{"campo":"custo"}') else _arv_item('Investimento lançado na campanha', inv, 'mkt.camp_total', jsonb_build_object('campanha', camp, 'campo', 'investimento')) end, _arv_item('÷ Vendas', ven, 'ven.soma', base || case when porcamp then '{"campo":"qtd"}' else '{"campo":"qtd","coorte":true}' end::jsonb) || jsonb_build_object('un', 'n')));
  end if;
  return jsonb_build_object('titulo', 'ROAS', 'valor', case when inv > 0 then fat / inv end, 'un', 'x', 'explica', 'Faturamento ÷ investimento em anúncios. O faturamento é o valor total das vendas aprovadas, sem as vendas de quem saiu.',
    'formula', jsonb_build_array(_arv_item('Valor total das vendas', ant, 'ven.soma', base || case when porcamp then '{"campo":"bruto"}' else '{"campo":"bruto","coorte":true}' end::jsonb), _arv_item('− Vendas de quem saiu (churn)', ant - fat, null, null), case when ads then _arv_item('÷ Investimento em anúncios', inv, 'mkt.ads', base || '{"campo":"custo"}') else _arv_item('÷ Investimento lançado na campanha', inv, 'mkt.camp_total', jsonb_build_object('campanha', camp, 'campo', 'investimento')) end));
end $f$;

-- ---------- 4. catálogo ----------
update metricas_definicoes set formula = 'Faturamento ÷ investimento em anúncios' where codigo = 'roas';
update metricas_definicoes set formula = 'Valor das vendas aprovadas ÷ vendas' where codigo = 'ticket_medio';

drop function public._v0252_troca(text, text[]);

-- Para desfazer: reaplicar as visões e as funções da v0.251 (20270106100000_v0251_cac_roas_receita.sql) e: drop view v_vendas_mkt.
