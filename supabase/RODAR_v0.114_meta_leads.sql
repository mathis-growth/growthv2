-- JÁ APLICADO em produção em 19/10/2026 (via Supabase). Guardado para registro / para outro projeto. Pode rodar de novo sem problema.
-- v0.114 — Meta de leads: ritmo por dia, por mês e por canal (Dashboard da campanha)
-- campanha_meta_leads(campanha, hoje) devolve, num jsonb só, tudo o que os gráficos de meta da campanha usam.
-- Lead = pessoa que entrou na campanha (campanha_participacoes): cada pessoa conta uma vez, inclusive quem já estava na base.
--   É a mesma contagem de "Captação e metas" e da coluna "Leads (meta)" dos canais.
-- Dois modos:
--   lancamento: meta total (campanhas.meta_leads) espalhada por igual nos dias da CAPTAÇÃO (fases.aquisicao);
--               sem as datas da captação, usa o início e o fim da campanha.
--               Meta do canal = campanha_canais.meta_leads (ou % da meta da campanha), espalhada nos mesmos dias.
--   mensal (campanha com meta_leads_mes): meta do mês (ajuste em campanha_metas_mes ou a padrão) ÷ dias do mês.
--               Meta do canal = campanha_canais.meta_leads por mês (ou % da meta do mês).
-- Esperado até hoje = soma das metas diárias até hoje (o dia de hoje entra pela fração do dia que já passou).
-- Rode depois das migrações da v0.89 (campanha_participacoes). Só leitura; respeita o acesso ao workspace.

create or replace function public.campanha_meta_leads(p_campanha uuid, p_hoje date default null) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare
  c campanhas; agora timestamp := now() at time zone 'America/Sao_Paulo';
  h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  fr numeric; mensal boolean; j_ini date; j_fim date; fonte text; d_ini date; d_fim date; n_jan int; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  fr := case when p_hoje is null or p_hoje = agora::date then extract(epoch from (agora - agora::date)) / 86400.0 else 1 end;
  mensal := coalesce(c.meta_leads_mes, 0) > 0;
  if mensal then
    fonte := 'mensal';
    d_fim := least(h, coalesce(c.data_fim, h));
    d_ini := greatest(coalesce(c.data_inicio, d_fim - 59), d_fim - 59);
  else
    j_ini := nullif(c.fases #>> '{aquisicao,ini}', '')::date; j_fim := nullif(c.fases #>> '{aquisicao,fim}', '')::date;
    if j_ini is not null and j_fim is not null and j_fim >= j_ini then fonte := 'captacao';
    else j_ini := c.data_inicio; j_fim := c.data_fim; fonte := case when j_ini is not null and j_fim is not null then 'campanha' end; end if;
    d_ini := coalesce(least(c.data_inicio, j_ini), j_ini, c.data_inicio,
                      (select min((entrou_em at time zone 'America/Sao_Paulo')::date) from campanha_participacoes where campanha_id = c.id), h);
    d_fim := greatest(coalesce(j_fim, d_ini), least(h, coalesce(c.data_fim, h)));
  end if;
  if d_fim < d_ini then d_fim := d_ini; end if;
  if d_fim - d_ini > 399 then d_ini := d_fim - 399; end if;
  n_jan := case when fonte in ('captacao', 'campanha') then j_fim - j_ini + 1 end;

  with dias as (select (d_ini + i)::date d, i from generate_series(0, d_fim - d_ini) i),
  meta_mes as (  -- só no modo mensal
    select d.d, coalesce(mm.meta_leads, c.meta_leads_mes)::numeric as mes_meta,
           extract(day from (date_trunc('month', d.d) + interval '1 month - 1 day'))::int as dias_mes
      from dias d left join campanha_metas_mes mm on mm.campanha_id = c.id and mm.mes = date_trunc('month', d.d)::date),
  cn as (  -- canais com meta (total no lançamento, por mês no mensal)
    select cc.id, cc.canal, cc.utm_campaign, cc.tipo, cc.meta_leads, cc.percentual_meta_leads from campanha_canais cc where cc.campanha_id = c.id),
  part as (select (entrou_em at time zone 'America/Sao_Paulo')::date d, campanha_canal_id cid, count(*) n
             from campanha_participacoes where campanha_id = c.id group by 1, 2),
  -- meta diária da campanha (null fora da janela / sem meta)
  md as (
    select d.d, d.i,
      case when mensal then mm.mes_meta / mm.dias_mes
           when n_jan > 0 and coalesce(c.meta_leads, 0) > 0 and d.d between j_ini and j_fim then c.meta_leads::numeric / n_jan end as meta,
      case when mensal then mm.dias_mes end as dias_mes, mm.mes_meta
    from dias d left join meta_mes mm on mm.d = d.d),
  ld as (select d.d, d.i, md.meta, md.dias_mes, md.mes_meta, case when d.d <= h then coalesce((select sum(n) from part p where p.d = d.d), 0) end as leads
           from dias d join md on md.d = d.d),
  -- peso do dia para o "esperado até hoje"
  pe as (select ld.*, case when ld.d < h then 1 when ld.d = h then fr else 0 end as peso from ld),
  canais as (
    select cn.id, cn.canal, cn.utm_campaign, cn.tipo,
      case when mensal then coalesce(cn.meta_leads::numeric, cn.percentual_meta_leads * c.meta_leads_mes / 100.0)
           else coalesce(cn.meta_leads::numeric, cn.percentual_meta_leads * c.meta_leads / 100.0) end as meta_base,
      (select jsonb_agg(case when pe.d <= h then coalesce((select sum(n) from part p where p.d = pe.d and p.cid = cn.id), 0) end order by pe.i) from pe) as leads_dia,
      (select coalesce(sum(n), 0) from part p where p.cid = cn.id and (not mensal or p.d >= date_trunc('month', h)::date)) as leads
    from cn),
  canais2 as (
    select x.*,
      -- meta diária do canal: mesma forma da meta da campanha, na proporção da meta do canal
      case when x.meta_base is null then null
           when mensal then x.meta_base / extract(day from (date_trunc('month', h) + interval '1 month - 1 day'))
           when n_jan > 0 then x.meta_base / n_jan end as meta_dia
    from canais x),
  meses as (
    select date_trunc('month', pe.d)::date mes, sum(pe.meta) meta, sum(pe.leads) leads, sum(pe.meta * pe.peso) esperado,
           bool_and(pe.d < h) completo, min(pe.d) de, max(pe.d) ate
      from pe group by 1)
  select jsonb_build_object(
    'modo', case when mensal then 'mensal' else 'lancamento' end, 'hoje', h, 'fonte_janela', fonte,
    'janela', case when j_ini is not null then jsonb_build_object('ini', j_ini, 'fim', j_fim, 'dias', n_jan) end,
    'meta_total', case when mensal then (select mes_meta from md where md.d = least(h, d_fim)) else c.meta_leads end,
    'meta_dia', (select meta from md where md.d = least(greatest(h, coalesce(j_ini, h)), d_fim)),
    'dias', (select jsonb_agg(d order by i) from pe),
    'leads', (select jsonb_agg(leads order by i) from pe),
    'metas', (select jsonb_agg(round(meta, 2) order by i) from pe),
    'leads_total', case when mensal then (select coalesce(sum(n), 0) from part where d >= date_trunc('month', h)::date)
                        else (select coalesce(sum(n), 0) from part) end,
    'esperado_hoje', round((select sum(meta * peso) from pe where not mensal or d >= date_trunc('month', h)::date), 1),
    'restam_dias', case when mensal then (date_trunc('month', h) + interval '1 month - 1 day')::date - h + 1
                        when j_fim is not null and j_fim >= h then j_fim - greatest(h, j_ini) + 1 else 0 end,
    'canais', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'canal', canal, 'utm_campaign', utm_campaign, 'tipo', tipo,
        'meta', round(meta_base), 'meta_dia', round(meta_dia, 2), 'leads', leads, 'leads_dia', leads_dia,
        'esperado_hoje', case when meta_dia is null then null
                              when mensal then round(meta_dia * ((h - date_trunc('month', h)::date) + fr), 1)
                              else round(meta_dia * (select sum(peso) from pe where pe.meta is not null), 1) end)
        order by meta_base desc nulls last, canal), '[]'::jsonb) from canais2),
    'sem_canal', (select coalesce(sum(n), 0) from part where cid is null and (not mensal or d >= date_trunc('month', h)::date)),
    'meses', (select coalesce(jsonb_agg(jsonb_build_object('mes', mes, 'meta', round(meta), 'leads', leads, 'esperado', round(esperado),
        'completo', completo, 'de', de, 'ate', ate) order by mes), '[]'::jsonb) from meses)
  ) into r;
  return r;
end $$;

revoke execute on function public.campanha_meta_leads(uuid, date) from public, anon;
grant execute on function public.campanha_meta_leads(uuid, date) to authenticated;
