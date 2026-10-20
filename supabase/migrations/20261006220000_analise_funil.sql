-- Análise de funil e cohorts (Growth). Só funções: os números saem daqui, em código fixo.
-- Lead = pessoa cadastrada no período (fuso de São Paulo). A coorte é seguida até hoje:
-- "chegou à etapa" = alguma vez entrou nela (histórico do funil); "cliente" = venda aprovada.
-- Todas rodam com as permissões de quem chama, então a RLS por workspace vale.

create function funil_resolve(p_ws uuid, p_camp uuid, p_funil uuid) returns uuid
language sql stable set search_path = public as $$
  select coalesce(
    p_funil,
    (select funil_id from campanhas where id = p_camp and workspace_id = p_ws),
    (select id from funis where workspace_id = p_ws and ativo order by nome limit 1))
$$;

-- Quem está em cada passo, para a coorte de leads do período.
create function funil_membros(p_ws uuid, p_ini date, p_fim date, p_camp uuid, p_funil uuid)
returns table(pessoa_id uuid, chave text)
language sql stable set search_path = public as $$
  with co as (
    select p.id, p.qualificacao, p.pesquisa_respondida_em from pessoas p
    where p.workspace_id = p_ws
      and p.criado_em >= (p_ini::timestamp at time zone 'America/Sao_Paulo')
      and p.criado_em < ((p_fim + 1)::timestamp at time zone 'America/Sao_Paulo')
      and (p_camp is null or p.campanha_id = p_camp))
  select co.id, 'leads'::text from co
  union all select co.id, 'qualificados'::text from co where co.qualificacao = 'qualificado'
  union all select co.id, 'pesquisa'::text from co where co.pesquisa_respondida_em is not null
  union all select distinct h.pessoa_id, 'e:' || e.id::text
    from funil_etapas e
    join pessoa_funil_historico h on h.workspace_id = p_ws and h.funil_id = e.funil_id and h.tipo = 'etapa' and h.para = e.nome
    where e.workspace_id = p_ws and e.funil_id = p_funil and e.tipo <> 'entrada' and h.pessoa_id in (select id from co)
  union all select distinct v.pessoa_id, 'clientes'::text
    from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' and v.pessoa_id in (select id from co)
$$;

-- Topo do funil: métricas dos anúncios no período (filtradas pela campanha, se houver).
create function funil_ads(p_ws uuid, p_ini date, p_fim date, p_camp uuid) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('impressoes', coalesce(sum(m.impressoes), 0), 'cliques', coalesce(sum(m.cliques), 0),
    'visualizacoes', coalesce(sum(m.visualizacoes_pagina), 0), 'custo', coalesce(sum(m.custo), 0))
  from metricas_anuncio_dia m
  join anuncios a on a.id = m.anuncio_id
  join campanha_canais cc on cc.id = a.campanha_canal_id
  where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_camp is null or cc.campanha_id = p_camp)
$$;

create function funil_analise(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null, p_funil uuid default null) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_funil uuid; v_len int; v_pini date; v_pfim date;
  r_ini timestamptz; r_fim timestamptz;
  r_cur jsonb; r_prev jsonb; r_ads jsonb; r_ads_p jsonb; r_et jsonb; r_dc jsonb; r_dk jsonb; r_camps jsonb; r_st jsonb; r_diag jsonb; r_nomes jsonb;
begin
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  if p_fim - p_ini > 400 then raise exception 'O período máximo é de 400 dias'; end if;
  v_funil := funil_resolve(p_ws, p_campanha, p_funil);
  v_len := p_fim - p_ini + 1; v_pfim := p_ini - 1; v_pini := p_ini - v_len;
  r_ini := p_ini::timestamp at time zone 'America/Sao_Paulo'; r_fim := (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo';

  with m as (select distinct pessoa_id, chave from funil_membros(p_ws, p_ini, p_fim, p_campanha, v_funil)),
  b as (select p.id, coalesce(p.campanha_id::text, '') as camp, coalesce(nullif(p.canal_origem, ''), '(sem canal)') as canal from pessoas p where p.id in (select pessoa_id from m))
  select
    (select coalesce(jsonb_object_agg(chave, n), '{}'::jsonb) from (select chave, count(*) as n from m group by chave) t),
    (select coalesce(jsonb_object_agg(chave, arr), '{}'::jsonb) from (select x.chave, jsonb_agg(jsonb_build_object('k', x.k, 'n', x.n) order by x.n desc) as arr from (select m.chave, b.camp as k, count(*) as n from m join b on b.id = m.pessoa_id group by m.chave, b.camp) x group by x.chave) t),
    (select coalesce(jsonb_object_agg(chave, arr), '{}'::jsonb) from (select x.chave, jsonb_agg(jsonb_build_object('k', x.k, 'n', x.n) order by x.n desc) as arr from (select m.chave, b.canal as k, count(*) as n from m join b on b.id = m.pessoa_id group by m.chave, b.canal) x group by x.chave) t)
  into r_cur, r_dc, r_dk;

  select coalesce(jsonb_object_agg(chave, n), '{}'::jsonb) into r_prev
  from (select chave, count(distinct pessoa_id) as n from funil_membros(p_ws, v_pini, v_pfim, p_campanha, v_funil) group by chave) t;

  r_ads := funil_ads(p_ws, p_ini, p_fim, p_campanha); r_ads_p := funil_ads(p_ws, v_pini, v_pfim, p_campanha);
  select coalesce(jsonb_agg(jsonb_build_object('chave', 'e:' || id::text, 'nome', nome, 'ordem', ordem, 'tipo', tipo) order by ordem), '[]'::jsonb) into r_et
  from funil_etapas where workspace_id = p_ws and funil_id = v_funil and tipo <> 'entrada';
  select coalesce(jsonb_object_agg(id::text, nome), '{}'::jsonb) into r_nomes from campanhas where workspace_id = p_ws;

  -- Passos em ordem. Qualificados e pesquisa são laterais: comparam com os leads, não com o passo anterior.
  with s as (
    select 1 as ord, 'impressoes' as chave, 'Impressões' as nome, 'anuncio' as grupo, false as lat, (r_ads ->> 'impressoes')::numeric as n, (r_ads_p ->> 'impressoes')::numeric as np
      where (r_ads ->> 'impressoes')::numeric > 0 or (r_ads_p ->> 'impressoes')::numeric > 0
    union all select 2, 'cliques', 'Cliques', 'anuncio', false, (r_ads ->> 'cliques')::numeric, (r_ads_p ->> 'cliques')::numeric
      where (r_ads ->> 'cliques')::numeric > 0 or (r_ads_p ->> 'cliques')::numeric > 0
    union all select 3, 'visualizacoes', 'Visualizações da página', 'anuncio', false, (r_ads ->> 'visualizacoes')::numeric, (r_ads_p ->> 'visualizacoes')::numeric
      where (r_ads ->> 'visualizacoes')::numeric > 0 or (r_ads_p ->> 'visualizacoes')::numeric > 0
    union all select 4, 'leads', 'Leads', 'pessoa', false, coalesce((r_cur ->> 'leads')::numeric, 0), coalesce((r_prev ->> 'leads')::numeric, 0)
    union all select 10 + (e.value ->> 'ordem')::int, e.value ->> 'chave', e.value ->> 'nome', 'pessoa', false, coalesce((r_cur ->> (e.value ->> 'chave'))::numeric, 0), coalesce((r_prev ->> (e.value ->> 'chave'))::numeric, 0)
      from jsonb_array_elements(r_et) e
    union all select 900, 'clientes', 'Clientes (venda aprovada)', 'pessoa', false, coalesce((r_cur ->> 'clientes')::numeric, 0), coalesce((r_prev ->> 'clientes')::numeric, 0)
    union all select 950, 'qualificados', 'Qualificados', 'pessoa', true, coalesce((r_cur ->> 'qualificados')::numeric, 0), coalesce((r_prev ->> 'qualificados')::numeric, 0)
    union all select 951, 'pesquisa', 'Responderam pesquisa', 'pessoa', true, coalesce((r_cur ->> 'pesquisa')::numeric, 0), coalesce((r_prev ->> 'pesquisa')::numeric, 0)
  ), c as (
    select s.*,
      case when s.lat then null else lag(s.n) over (partition by s.lat order by s.ord) end as base,
      case when s.lat then null else lag(s.np) over (partition by s.lat order by s.ord) end as base_p,
      coalesce((r_cur ->> 'leads')::numeric, 0) as leads_n, coalesce((r_prev ->> 'leads')::numeric, 0) as leads_p
    from s
  ), d as (
    select c.*,
      case when c.lat then case when c.leads_n > 0 then c.n / c.leads_n end else case when c.base > 0 then c.n / c.base end end as conv,
      case when c.lat then case when c.leads_p > 0 then c.np / c.leads_p end else case when c.base_p > 0 then c.np / c.base_p end end as conv_p
    from c
  )
  select coalesce(jsonb_agg(jsonb_build_object('chave', chave, 'nome', nome, 'grupo', grupo, 'lateral', lat, 'n', n, 'n_ant', np, 'base', base,
      'conv', round(conv, 4), 'conv_ant', round(conv_p, 4), 'var', case when conv_p > 0 and conv is not null then round(conv / conv_p - 1, 4) end,
      'do_topo', case when not lat and (select n from s where chave = 'leads') > 0 then round(n / (select n from s where chave = 'leads'), 4) end) order by ord), '[]'::jsonb)
  into r_st from d;

  -- Gargalo = passo que mais piorou contra o período anterior (queda de pelo menos 15%, base mínima de 10).
  -- Maior perda = passo em que mais gente ficou pelo caminho.
  with e as (select x ->> 'chave' as chave, x ->> 'nome' as nome, (x ->> 'conv')::numeric as conv, (x ->> 'conv_ant')::numeric as conv_ant, (x ->> 'var')::numeric as var,
      (x ->> 'base')::numeric as base, (x ->> 'n')::numeric as n, (x ->> 'grupo') as grupo, (x ->> 'lateral')::boolean as lat
    from jsonb_array_elements(r_st) x)
  select jsonb_build_object(
    'gargalo', (select jsonb_build_object('chave', chave, 'nome', nome, 'conv', conv, 'conv_ant', conv_ant, 'var', var) from e where not lat and base >= 10 and var is not null and var <= -0.15 order by var limit 1),
    'maior_perda', (select jsonb_build_object('chave', chave, 'nome', nome, 'perdidos', base - n, 'base', base) from e where not lat and base is not null and base > n and chave <> 'leads' order by base - n desc limit 1))
  into r_diag;

  with co as (select p.id, p.campanha_id, p.qualificacao from pessoas p where p.workspace_id = p_ws and p.criado_em >= r_ini and p.criado_em < r_fim and (p_campanha is null or p.campanha_id = p_campanha)),
  le as (select campanha_id, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados from co group by campanha_id),
  rec as (select co.campanha_id, count(distinct v.pessoa_id) as clientes, coalesce(sum(v.valor_liquido), 0) as receita from co join vendas v on v.pessoa_id = co.id and v.status = 'aprovada' group by co.campanha_id),
  cus as (select cc.campanha_id, sum(m.custo) as custo from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
          where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by cc.campanha_id),
  k as (select campanha_id from le union select campanha_id from cus)
  select coalesce(jsonb_agg(jsonb_build_object('id', k.campanha_id, 'nome', coalesce(ca.nome, '(sem campanha)'), 'leads', coalesce(le.leads, 0), 'qualificados', coalesce(le.qualificados, 0),
      'clientes', coalesce(rec.clientes, 0), 'receita', coalesce(rec.receita, 0), 'custo', coalesce(cus.custo, 0),
      'cpl', case when coalesce(le.leads, 0) > 0 then round(coalesce(cus.custo, 0) / le.leads, 2) end,
      'cac', case when coalesce(rec.clientes, 0) > 0 then round(coalesce(cus.custo, 0) / rec.clientes, 2) end,
      'lead_cliente', case when coalesce(le.leads, 0) > 0 then round(coalesce(rec.clientes, 0)::numeric / le.leads, 4) end,
      'roas', case when coalesce(cus.custo, 0) > 0 then round(coalesce(rec.receita, 0) / cus.custo, 2) end) order by coalesce(le.leads, 0) desc), '[]'::jsonb)
  into r_camps
  from k left join campanhas ca on ca.id = k.campanha_id left join le on le.campanha_id is not distinct from k.campanha_id
    left join rec on rec.campanha_id is not distinct from k.campanha_id left join cus on cus.campanha_id is not distinct from k.campanha_id;

  return jsonb_build_object('funil_id', v_funil, 'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim), 'anterior', jsonb_build_object('ini', v_pini, 'fim', v_pfim),
    'custo', r_ads -> 'custo', 'custo_ant', r_ads_p -> 'custo', 'passos', r_st, 'diagnostico', r_diag, 'por_campanha', r_dc, 'por_canal', r_dk, 'campanhas', r_camps, 'nomes_campanhas', r_nomes);
end $$;

-- Lista de pessoas de um passo, para investigar um a um.
-- modo 'chegaram': quem está no passo. modo 'pararam': quem estava no passo anterior e não chegou neste.
create function funil_pessoas(p_ws uuid, p_ini date, p_fim date, p_campanha uuid, p_funil uuid, p_chave text, p_modo text default 'chegaram', p_anterior text default null, p_limite int default 200) returns jsonb
language plpgsql stable set search_path = public as $$
declare v_funil uuid; r jsonb;
begin
  if p_fim - p_ini > 400 then raise exception 'O período máximo é de 400 dias'; end if;
  if p_modo not in ('chegaram', 'pararam') then raise exception 'Modo inválido'; end if;
  v_funil := funil_resolve(p_ws, p_campanha, p_funil);
  with m as (select distinct pessoa_id, chave from funil_membros(p_ws, p_ini, p_fim, p_campanha, v_funil)),
  alvo as (
    select pessoa_id from m where chave = p_chave and p_modo = 'chegaram'
    union all
    select pessoa_id from m where chave = coalesce(p_anterior, 'leads') and p_modo = 'pararam'
      and pessoa_id not in (select pessoa_id from m where chave = p_chave))
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'email', p.email, 'telefone', p.telefone, 'campanha_id', p.campanha_id, 'canal', p.canal_origem,
      'utm_source', p.utm_source, 'utm_content', p.utm_content, 'qualificacao', p.qualificacao, 'criado_em', p.criado_em) order by p.criado_em desc), '[]'::jsonb)
  into r from (select p.* from pessoas p where p.id in (select pessoa_id from alvo) order by p.criado_em desc limit least(greatest(coalesce(p_limite, 200), 1), 500)) p;
  return r;
end $$;

-- Cohorts: leads agrupados por semana ou mês de entrada, seguidos até hoje.
-- min_idade = idade em dias do lead mais novo da coorte: uma janela só está completa se min_idade >= janela.
create function funil_cohorts(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null, p_gran text default 'semana') returns jsonb
language plpgsql stable set search_path = public as $$
declare r jsonb; v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  if p_fim - p_ini > 800 then raise exception 'O período máximo é de 800 dias'; end if;
  if p_gran not in ('semana', 'mes') then raise exception 'Granularidade inválida'; end if;
  with co as (
    select p.id, p.qualificacao, p.pesquisa_respondida_em, (p.criado_em at time zone 'America/Sao_Paulo') as ts,
      date_trunc(case when p_gran = 'mes' then 'month' else 'week' end, p.criado_em at time zone 'America/Sao_Paulo')::date as coorte
    from pessoas p
    where p.workspace_id = p_ws and p.criado_em >= (p_ini::timestamp at time zone 'America/Sao_Paulo') and p.criado_em < ((p_fim + 1)::timestamp at time zone 'America/Sao_Paulo')
      and (p_campanha is null or p.campanha_id = p_campanha)),
  pv as (select v.pessoa_id, min(v.data_venda at time zone 'America/Sao_Paulo') as primeira, sum(v.valor_liquido) as receita
         from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' group by v.pessoa_id)
  select coalesce(jsonb_agg(jsonb_build_object('coorte', coorte, 'leads', leads, 'qualificados', qualificados, 'pesquisa', pesquisa,
      'c7', c7, 'c14', c14, 'c30', c30, 'c60', c60, 'c90', c90, 'clientes', clientes, 'receita', receita, 'min_idade', min_idade) order by coorte), '[]'::jsonb)
  into r
  from (
    select co.coorte, count(*) as leads, count(*) filter (where co.qualificacao = 'qualificado') as qualificados, count(*) filter (where co.pesquisa_respondida_em is not null) as pesquisa,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '7 days') as c7,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '14 days') as c14,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '30 days') as c30,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '60 days') as c60,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '90 days') as c90,
      count(pv.pessoa_id) as clientes, coalesce(sum(pv.receita), 0) as receita,
      (v_hoje - max(co.ts::date)) as min_idade
    from co left join pv on pv.pessoa_id = co.id group by co.coorte) t;
  return r;
end $$;

revoke execute on function funil_resolve(uuid, uuid, uuid), funil_membros(uuid, date, date, uuid, uuid), funil_ads(uuid, date, date, uuid),
  funil_analise(uuid, date, date, uuid, uuid), funil_pessoas(uuid, date, date, uuid, uuid, text, text, text, int), funil_cohorts(uuid, date, date, uuid, text) from public, anon;
grant execute on function funil_resolve(uuid, uuid, uuid), funil_membros(uuid, date, date, uuid, uuid), funil_ads(uuid, date, date, uuid),
  funil_analise(uuid, date, date, uuid, uuid), funil_pessoas(uuid, date, date, uuid, uuid, text, text, text, int), funil_cohorts(uuid, date, date, uuid, text) to authenticated;
