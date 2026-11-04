-- v0.251 — Uma conta só para CAC de mídia, ROAS e receita de marketing.
-- Regras decididas em 03/11/2026:
--   investimento de mídia = anúncios da campanha ou do canal; sem anúncio conectado, as contas a pagar e os custos lançados (sem somar as duas fontes);
--   CAC de mídia = investimento ÷ vendas (order bump e upsell contam como venda);
--   receita de marketing = valor líquido das vendas aprovadas, tirando todo o valor das vendas de quem saiu (a pessoa tem aluno e nenhum ativo);
--   ROAS = receita de marketing ÷ investimento; ticket médio = receita antes do churn ÷ vendas.
-- O financeiro não muda: CAC total (por cliente novo), ROI, lucro e caixa seguem como estão.
-- Trocas de texto nas funções, com erro se o trecho não for encontrado. Rode depois de 20270105100000_v0250_ticket_e_foto.sql. Idempotente.

-- ---------- 1. peças únicas ----------
create or replace view public.v_pessoas_saiu with (security_invoker = true) as
  select pessoa_id from alunos group by pessoa_id having not bool_or(saiu_em is null);
grant select on public.v_pessoas_saiu to authenticated;

create or replace function public.campanha_tem_anuncio(p_campanha uuid) returns boolean language sql stable set search_path = public as $$
  select exists (select 1 from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id where cc.campanha_id = p_campanha and m.custo > 0)
$$;

-- ---------- 2. visões das campanhas e dos canais ----------
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
   select v.campanha_id, count(*) filter (where v.status = 'aprovada') as vendas,
     coalesce(sum(v.valor_bruto) filter (where v.status = 'aprovada'), 0) as receita_bruta,
     count(distinct v.pessoa_id) filter (where v.status = 'aprovada') as clientes,
     coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where v.status = 'aprovada' and s.pessoa_id is null), 0) as receita,
     coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where v.status = 'aprovada' and s.pessoa_id is not null), 0) as receita_saiu,
     coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where v.status = 'aprovada'), 0) as receita_antes_churn,
     count(distinct v.pessoa_id) filter (where v.status = 'aprovada' and s.pessoa_id is not null) as pessoas_saiu
   from vendas v left join v_pessoas_saiu s on s.pessoa_id = v.pessoa_id where v.campanha_id is not null group by v.campanha_id
 ), i as (
   select c.id, coalesce(ads.v, lan.v, 0) as v from campanhas c left join ads on ads.campanha_id = c.id left join lan on lan.campanha_id = c.id
 )
 select c.id as campanha_id, c.workspace_id, c.nome, c.status, c.orcamento_total, c.meta_leads, c.meta_vendas, c.meta_receita, c.meta_cac,
   i.v as investimento, coalesce(ld.leads, 0::bigint) as leads, coalesce(ld.qualificados, 0::bigint) as qualificados, coalesce(vd.vendas, 0::bigint) as vendas, coalesce(vd.clientes, 0::bigint) as clientes,
   coalesce(vd.receita_bruta, 0::numeric) as receita_bruta,
   round(i.v / nullif(ld.leads, 0)::numeric, 2) as cpl,
   round(i.v / nullif(vd.vendas, 0)::numeric, 2) as cac,
   round(vd.receita / nullif(i.v, 0::numeric), 2) as roas,
   round(vd.vendas::numeric * 100::numeric / nullif(ld.leads, 0)::numeric, 2) as taxa_lead_venda,
   coalesce(vd.receita, 0::numeric) as receita, coalesce(vd.receita_saiu, 0::numeric) as receita_saiu, coalesce(vd.receita_antes_churn, 0::numeric) as receita_antes_churn, coalesce(vd.pessoas_saiu, 0::bigint) as pessoas_saiu
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
   select p.workspace_id, p.utm_campaign, count(*) filter (where v.status = 'aprovada') as vendas,
     coalesce(sum(v.valor_bruto) filter (where v.status = 'aprovada'), 0) as receita_bruta,
     count(distinct v.pessoa_id) filter (where v.status = 'aprovada') as clientes,
     coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where v.status = 'aprovada' and s.pessoa_id is null), 0) as receita
   from vendas v join pessoas p on p.id = v.pessoa_id left join v_pessoas_saiu s on s.pessoa_id = v.pessoa_id where p.utm_campaign is not null group by p.workspace_id, p.utm_campaign
 )
 select cc.id as campanha_canal_id, cc.workspace_id, cc.campanha_id, c.nome as campanha, cc.canal, cc.utm_campaign, cc.orcamento, cc.meta_leads, cc.meta_vendas, cc.meta_cac,
   coalesce(ads.v, lan.v, 0::numeric) as investimento, coalesce(ld.leads, 0::bigint) as leads, coalesce(ld.qualificados, 0::bigint) as qualificados, coalesce(vd.vendas, 0::bigint) as vendas, coalesce(vd.clientes, 0::bigint) as clientes,
   coalesce(vd.receita_bruta, 0::numeric) as receita_bruta,
   round(coalesce(ads.v, lan.v, 0::numeric) / nullif(ld.leads, 0)::numeric, 2) as cpl,
   round(coalesce(ads.v, lan.v, 0::numeric) / nullif(vd.vendas, 0)::numeric, 2) as cac,
   coalesce(vd.receita, 0::numeric) as receita,
   round(vd.receita / nullif(coalesce(ads.v, lan.v, 0::numeric), 0::numeric), 2) as roas
 from campanha_canais cc join campanhas c on c.id = cc.campanha_id left join ads on ads.campanha_canal_id = cc.id left join lan on lan.campanha_canal_id = cc.id
   left join ld on ld.workspace_id = cc.workspace_id and ld.utm_campaign = cc.utm_campaign left join vd on vd.workspace_id = cc.workspace_id and vd.utm_campaign = cc.utm_campaign;

-- ---------- 3. funções: troca de texto ----------
create or replace function public._v0251_troca(p_sig text, p_pares text[]) returns void language plpgsql as $f$
declare def text; i int;
begin
  select pg_get_functiondef(p_sig::regprocedure) into def; def := replace(def, E'\r\n', E'\n');
  if position('v0.251' in def) > 0 then return; end if;
  for i in 1 .. array_length(p_pares, 1) / 2 loop
    if position(p_pares[2 * i - 1] in def) = 0 then raise exception 'v0.251: trecho não encontrado em %: %', p_sig, left(p_pares[2 * i - 1], 80); end if;
    def := replace(def, p_pares[2 * i - 1], p_pares[2 * i]);
  end loop;
  -- marca a função como já trocada
  def := regexp_replace(def, E'\\$function\\$\\s*\n?(declare|begin)', E'$function$\n-- v0.251\n\\1', 'i');
  if position('v0.251' in def) = 0 then raise exception 'v0.251: não consegui marcar %', p_sig; end if;
  execute def;
end $f$;

do $m$ begin
  perform _v0251_troca('public.funil_analise(uuid,date,date,uuid,uuid)', array[
    'coalesce(sum(v.valor_liquido), 0) as receita from co join vendas v on v.pessoa_id = co.id and v.status = ''aprovada'' group by co.campanha_id',
    'coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as receita, coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)), 0) as receita_antes_churn from co join vendas v on v.pessoa_id = co.id and v.status = ''aprovada'' group by co.campanha_id',
    'cus as (select cc.campanha_id, sum(m.custo) as custo from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
          where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by cc.campanha_id),',
    'cus as (select z.campanha_id, sum(z.custo) as custo from (select cc.campanha_id, m.custo from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
          where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha)
          union all select cp.campanha_id, cp.valor from contas_pagar cp where cp.workspace_id = p_ws and cp.status <> ''cancelado'' and cp.campanha_id is not null and cp.competencia between p_ini and p_fim and (p_campanha is null or cp.campanha_id = p_campanha) and not campanha_tem_anuncio(cp.campanha_id)
          union all select cu.campanha_id, cu.valor from custos_cac cu where cu.workspace_id = p_ws and cu.campanha_id is not null and cu.competencia between p_ini and p_fim and (p_campanha is null or cu.campanha_id = p_campanha) and not campanha_tem_anuncio(cu.campanha_id)) z group by z.campanha_id),',
    '''cac'', case when coalesce(rec.clientes, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / rec.clientes, 2) end,',
    '''cac'', case when coalesce(rec.vendas, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / rec.vendas, 2) end, ''receita_antes_churn'', coalesce(rec.receita_antes_churn, 0),',
    'sum((x ->> ''receita'')::numeric), ''custo'', sum((x ->> ''custo'')::numeric),',
    'sum((x ->> ''receita'')::numeric), ''receita_antes_churn'', sum((x ->> ''receita_antes_churn'')::numeric), ''custo'', sum((x ->> ''custo'')::numeric),',
    '''cac'', case when coalesce((r_pos ->> ''clientes'')::numeric, 0) > 0 and coalesce((r_pos ->> ''custo'')::numeric, 0) > 0 then round((r_pos ->> ''custo'')::numeric / (r_pos ->> ''clientes'')::numeric, 2) end,',
    '''cac'', case when coalesce((r_pos ->> ''vendas'')::numeric, 0) > 0 and coalesce((r_pos ->> ''custo'')::numeric, 0) > 0 then round((r_pos ->> ''custo'')::numeric / (r_pos ->> ''vendas'')::numeric, 2) end,'
  ]);
  perform _v0251_troca('public.funil_cohorts(uuid,date,date,uuid,text)', array[
    'min(v.data_venda at time zone ''America/Sao_Paulo'') as primeira, sum(v.valor_liquido) as receita',
    'min(v.data_venda at time zone ''America/Sao_Paulo'') as primeira, count(*) as vendas, coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as receita',
    'count(pv.pessoa_id) as clientes, coalesce(sum(pv.receita), 0) as receita,',
    'count(pv.pessoa_id) as clientes, coalesce(sum(pv.vendas), 0) as vendas, coalesce(sum(pv.receita), 0) as receita,',
    '''cac'', case when g.clientes > 0 and coalesce(cu.custo, 0) > 0 then round(cu.custo / g.clientes, 2) end,',
    '''vendas'', g.vendas, ''cac'', case when g.vendas > 0 and coalesce(cu.custo, 0) > 0 then round(cu.custo / g.vendas, 2) end,',
    'where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by 1),',
    'where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by 1
    union all select case when p_gran = ''campanha'' then x.campanha_id::text else date_trunc(case when p_gran = ''mes'' then ''month'' else ''week'' end, x.competencia::timestamp)::date::text end, sum(x.valor) from (
      select campanha_id, competencia, valor from contas_pagar where workspace_id = p_ws and status <> ''cancelado'' and campanha_id is not null and competencia between p_ini and p_fim and (p_campanha is null or campanha_id = p_campanha) and not campanha_tem_anuncio(campanha_id)
      union all select campanha_id, competencia, valor from custos_cac where workspace_id = p_ws and campanha_id is not null and competencia between p_ini and p_fim and (p_campanha is null or campanha_id = p_campanha) and not campanha_tem_anuncio(campanha_id)) x group by 1),
  cu2 as (select k, sum(custo) as custo from cu group by k),',
    'from g left join cu on cu.k = g.k;', 'from g left join cu2 cu on cu.k = g.k;'
  ]);
  perform _v0251_troca('public.vendas_por_canal(uuid,date,date,text,uuid)', array[
    'select v.id, v.pessoa_id, v.valor_bruto, coalesce(a.canal, ''sem_origem'') as canal,',
    'select v.id, v.pessoa_id, case when exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id) then 0 else coalesce(v.valor_liquido, v.valor_bruto) end as valor_mkt, coalesce(a.canal, ''sem_origem'') as canal,',
    'sum(valor_bruto) as receita from v group by 1, 2', 'sum(valor_mkt) as receita from v group by 1, 2',
    '''cac'', case when j.investimento is not null and j.clientes > 0 then round(j.investimento / j.clientes, 2) end,',
    '''cac'', case when j.investimento is not null and j.vendas > 0 then round(j.investimento / j.vendas, 2) end,'
  ]);
  perform _v0251_troca('public._meta_realizado(campanhas,campanha_metas,date,date)', array[
    'select count(*), coalesce(sum(v.valor_bruto), 0), count(distinct v.pessoa_id) into vend, rec, cli',
    'select count(*), coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0), count(distinct v.pessoa_id) into vend, rec, cli',
    'return case mt.tipo',
    'if inv is null and mt.canal is null and mt.temperatura is null and not campanha_tem_anuncio(c.id) then
    select sum(x.valor) into inv from (select valor from contas_pagar where campanha_id = c.id and status <> ''cancelado'' and competencia between ini and fim
      union all select valor from custos_cac where campanha_id = c.id and competencia between ini and fim) x;
  end if;
  return case mt.tipo',
    'when ''cac'' then case when cli > 0 and inv is not null then round(inv / cli, 2) end',
    'when ''cac'' then case when vend > 0 and inv is not null then round(inv / vend, 2) end'
  ]);
  perform _v0251_troca('public.campanha_detalhe(uuid,date)', array[
    'vd as (select v.id, v.pessoa_id, v.valor_bruto, v.produto_id,',
    'vd as (select v.id, v.pessoa_id, v.valor_bruto as valor_original, case when exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id) then 0 else coalesce(v.valor_liquido, v.valor_bruto) end as valor_bruto, v.produto_id,',
    '''valor'', vd.valor_bruto,', '''valor'', vd.valor_original,'
  ]);
  perform _v0251_troca('public.growth_metricas_auto(uuid,date,date)', array[
    'select count(*), coalesce(sum(valor_bruto), 0), count(distinct pessoa_id) into nv, receita, clientes from vendas',
    'select count(*), coalesce(sum(coalesce(valor_liquido, valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = vendas.pessoa_id)), 0), count(distinct pessoa_id) into nv, receita, clientes from vendas',
    '''ticket'', receita / nullif(nv, 0), ''cac'', inv / nullif(clientes, 0),',
    '''ticket'', (select sum(coalesce(valor_liquido, valor_bruto)) from vendas where workspace_id = p_ws and status = ''aprovada'' and (data_venda at time zone ''America/Sao_Paulo'')::date between p_ini and p_fim) / nullif(nv, 0), ''cac'', inv / nullif(nv, 0),'
  ]);
  perform _v0251_troca('public.campanha_series(uuid,uuid,uuid,boolean,date)', array[
    'sum(v.valor_bruto) as rec, count(distinct v.pessoa_id) as cli',
    'coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where not exists (select 1 from v_pessoas_saiu s where s.pessoa_id = v.pessoa_id)), 0) as rec, count(*) as cli',
    'select receita_bruta / nullif(investimento, 0) into roas from v_marketing_campanha', 'select receita / nullif(investimento, 0) into roas from v_marketing_campanha',
    'select receita_bruta / nullif(investimento, 0) into roas from v_marketing_canal', 'select receita / nullif(investimento, 0) into roas from v_marketing_canal'
  ]);
end $m$;

-- detalhe (árvore) do CAC e do ROAS: a mesma conta dos cards, mostrando quanto saiu pelo churn
create or replace function public._arv_mkt_norm(p_ws uuid, p_no text, par jsonb) returns jsonb language plpgsql stable set search_path = public as $f$
declare camp uuid := nullif(par ->> 'campanha', '')::uuid; ini date := nullif(par ->> 'ini', '')::date; fim date := nullif(par ->> 'fim', '')::date;
  inv numeric; ven numeric; rec numeric; ant numeric; base jsonb; porcamp boolean := camp is not null and ini is null; ads boolean;
begin
  if porcamp then
    select v.investimento, v.vendas, v.receita, v.receita_antes_churn into inv, ven, rec, ant from v_marketing_campanha v where v.campanha_id = camp and v.workspace_id = p_ws;
    ads := campanha_tem_anuncio(camp); base := jsonb_build_object('campanha', camp);
  else
    select count(*), coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)) filter (where s.pessoa_id is null), 0), coalesce(sum(coalesce(v.valor_liquido, v.valor_bruto)), 0) into ven, rec, ant
      from pessoas p join vendas v on v.pessoa_id = p.id and v.status = 'aprovada' left join v_pessoas_saiu s on s.pessoa_id = p.id
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
  return jsonb_build_object('titulo', 'ROAS', 'valor', case when inv > 0 then rec / inv end, 'un', 'x', 'explica', 'Receita sem o churn ÷ investimento em anúncios. A receita é o valor líquido das vendas aprovadas, sem as vendas de quem saiu.',
    'formula', jsonb_build_array(_arv_item('Receita líquida das vendas', ant, 'ven.soma', base || case when porcamp then '{"campo":"liquido"}' else '{"campo":"liquido","coorte":true}' end::jsonb), _arv_item('− Vendas de quem saiu (churn)', ant - rec, null, null), case when ads then _arv_item('÷ Investimento em anúncios', inv, 'mkt.ads', base || '{"campo":"custo"}') else _arv_item('÷ Investimento lançado na campanha', inv, 'mkt.camp_total', jsonb_build_object('campanha', camp, 'campo', 'investimento')) end));
end $f$;

do $m$ begin
  perform _v0251_troca('public.arvore_no(uuid,text,jsonb)', array[
    'when ''mkt.cpl'', ''mkt.cac'', ''mkt.roas'', ''mkt.roi'', ''mkt.conv'',',
    'when ''mkt.cac'', ''mkt.roas'' then r := _arv_mkt_norm(p_ws, p_no, par);
  when ''mkt.cpl'', ''mkt.roi'', ''mkt.conv'',',
    '''explica'', ''Investimento ÷ clientes.''', '''explica'', ''Investimento ÷ vendas.''',
    'when ''mkt.trf_cac'' then ''clientes'' else ''receita'' end', 'when ''mkt.trf_cac'' then ''vendas'' else ''receita'' end',
    'case p_no when ''mkt.trf_cpl'' then ''leads'' else ''clientes'' end', 'case p_no when ''mkt.trf_cpl'' then ''leads'' else ''vendas'' end'
  ]);
  perform _v0251_troca('public._arv_extra2(uuid,text,jsonb)', array[
    'inv := coalesce((select sum(valor) from contas_pagar where campanha_id = camp and status <> ''cancelado''), 0) + coalesce((select sum(valor) from custos_cac where campanha_id = camp), 0);',
    'select v.investimento, v.vendas, v.receita into inv, cli, rb from v_marketing_campanha v where v.campanha_id = camp;',
    'select count(distinct pessoa_id), coalesce(sum(valor_bruto), 0) into cli, rb from vendas where campanha_id = camp and status = ''aprovada'';', '',
    '''valor'', inv, ''un'', ''brl'', ''quebras'', a,', '''valor'', inv, ''un'', ''brl'', ''quebras'', case when campanha_tem_anuncio(camp) then ''[]''::jsonb else a end,',
    'Tudo o que foi lançado para a campanha desde o início: contas a pagar ligadas a ela (menos as canceladas) e custos de aquisição. É o investimento da tabela de campanhas ativas do Painel; o gasto de anúncios importado das plataformas aparece em Mídia paga.',
    'Gasto em anúncios da campanha, desde o início. Sem anúncio conectado, as contas a pagar ligadas a ela (menos as canceladas) e os custos de aquisição, sem somar as duas fontes.',
    'Investido na campanha ÷ clientes (pessoas com venda aprovada na campanha).', 'Investimento em anúncios da campanha ÷ vendas aprovadas. Order bump e upsell contam como venda.',
    '÷ Clientes (pessoas distintas nas vendas aprovadas)', '÷ Vendas',
    'Receita bruta das vendas aprovadas da campanha ÷ investido na campanha.', 'Receita sem o churn ÷ investimento em anúncios da campanha.',
    '_arv_item(''Receita bruta'', rb, ''ven.soma'', jsonb_build_object(''campanha'', camp, ''campo'', ''bruto''))', '_arv_item(''Receita sem o churn'', rb, ''ven.soma'', jsonb_build_object(''campanha'', camp, ''campo'', ''liquido''))'
  ]);
end $m$;

-- ---------- 4. catálogo de métricas ----------
update metricas_definicoes set formula = 'Investimento em anúncios ÷ vendas (order bump e upsell contam como venda)' where codigo = 'cac_midia';
update metricas_definicoes set formula = 'Anúncios + equipe de marketing e vendas ÷ clientes novos do período' where codigo = 'cac';
update metricas_definicoes set formula = 'Receita sem o churn ÷ investimento em anúncios' where codigo = 'roas';
update metricas_definicoes set formula = 'Receita antes do churn ÷ vendas' where codigo = 'ticket_medio';

drop function public._v0251_troca(text, text[]);

-- Para desfazer: reaplicar v_marketing_campanha e v_marketing_canal de 20261006480000_modo_financeiro_custos_cac.sql (com security_invoker) e as definições anteriores das funções;
-- drop function _arv_mkt_norm(uuid, text, jsonb), campanha_tem_anuncio(uuid); drop view v_pessoas_saiu.
