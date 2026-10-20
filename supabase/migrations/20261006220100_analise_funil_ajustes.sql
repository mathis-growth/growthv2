-- Ajustes da análise de funil: funil padrão = o com mais gente; maior perda só entre pessoas; CPL e CAC vazios sem custo.
create or replace function funil_resolve(p_ws uuid, p_camp uuid, p_funil uuid) returns uuid
language sql stable set search_path = public as $$
  select coalesce(
    p_funil,
    (select funil_id from campanhas where id = p_camp and workspace_id = p_ws),
    (select pf.funil_id from pessoa_funil pf join funis f on f.id = pf.funil_id and f.ativo where pf.workspace_id = p_ws group by pf.funil_id order by count(*) desc limit 1),
    (select id from funis where workspace_id = p_ws and ativo order by nome limit 1))
$$;

create or replace function funil_analise(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null, p_funil uuid default null) returns jsonb
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
      'do_topo', case when not lat and grupo = 'pessoa' and (select n from s where chave = 'leads') > 0 then round(n / (select n from s where chave = 'leads'), 4) end) order by ord), '[]'::jsonb)
  into r_st from d;

  -- Gargalo = passo que mais piorou contra o período anterior (queda de pelo menos 15%, base mínima de 10).
  -- Maior perda = passo em que mais gente ficou pelo caminho.
  with e as (select x ->> 'chave' as chave, x ->> 'nome' as nome, (x ->> 'conv')::numeric as conv, (x ->> 'conv_ant')::numeric as conv_ant, (x ->> 'var')::numeric as var,
      (x ->> 'base')::numeric as base, (x ->> 'n')::numeric as n, (x ->> 'grupo') as grupo, (x ->> 'lateral')::boolean as lat
    from jsonb_array_elements(r_st) x)
  select jsonb_build_object(
    'gargalo', (select jsonb_build_object('chave', chave, 'nome', nome, 'conv', conv, 'conv_ant', conv_ant, 'var', var) from e where not lat and base >= 10 and var is not null and var <= -0.15 order by var limit 1),
    'maior_perda', (select jsonb_build_object('chave', chave, 'nome', nome, 'perdidos', base - n, 'base', base) from e where not lat and grupo = 'pessoa' and base is not null and base > n and chave <> 'leads' order by base - n desc limit 1))
  into r_diag;

  with co as (select p.id, p.campanha_id, p.qualificacao from pessoas p where p.workspace_id = p_ws and p.criado_em >= r_ini and p.criado_em < r_fim and (p_campanha is null or p.campanha_id = p_campanha)),
  le as (select campanha_id, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados from co group by campanha_id),
  rec as (select co.campanha_id, count(distinct v.pessoa_id) as clientes, coalesce(sum(v.valor_liquido), 0) as receita from co join vendas v on v.pessoa_id = co.id and v.status = 'aprovada' group by co.campanha_id),
  cus as (select cc.campanha_id, sum(m.custo) as custo from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
          where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by cc.campanha_id),
  k as (select campanha_id from le union select campanha_id from cus)
  select coalesce(jsonb_agg(jsonb_build_object('id', k.campanha_id, 'nome', coalesce(ca.nome, '(sem campanha)'), 'leads', coalesce(le.leads, 0), 'qualificados', coalesce(le.qualificados, 0),
      'clientes', coalesce(rec.clientes, 0), 'receita', coalesce(rec.receita, 0), 'custo', coalesce(cus.custo, 0),
      'cpl', case when coalesce(le.leads, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / le.leads, 2) end,
      'cac', case when coalesce(rec.clientes, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / rec.clientes, 2) end,
      'lead_cliente', case when coalesce(le.leads, 0) > 0 then round(coalesce(rec.clientes, 0)::numeric / le.leads, 4) end,
      'roas', case when coalesce(cus.custo, 0) > 0 then round(coalesce(rec.receita, 0) / cus.custo, 2) end) order by coalesce(le.leads, 0) desc), '[]'::jsonb)
  into r_camps
  from k left join campanhas ca on ca.id = k.campanha_id left join le on le.campanha_id is not distinct from k.campanha_id
    left join rec on rec.campanha_id is not distinct from k.campanha_id left join cus on cus.campanha_id is not distinct from k.campanha_id;

  return jsonb_build_object('funil_id', v_funil, 'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim), 'anterior', jsonb_build_object('ini', v_pini, 'fim', v_pfim),
    'custo', r_ads -> 'custo', 'custo_ant', r_ads_p -> 'custo', 'passos', r_st, 'diagnostico', r_diag, 'por_campanha', r_dc, 'por_canal', r_dk, 'campanhas', r_camps, 'nomes_campanhas', r_nomes);
end $$;

