-- v0.21: cohorts do RevOps com filtros livres. Cálculo 100% determinístico (sem IA).
-- Coorte = pessoa pela data da 1ª matrícula (alunos.entrou_em). "Ativo em t" = tem matrícula
-- que entrou até t e não saiu até t (mesma regra do painel do RevOps).
-- Métricas: retencao (% ativos), recompra (% com 2+ compras aprovadas), receita (R$ acumulado por pessoa:
-- vendas aprovadas líquidas + parcelas de contrato recebidas).
create or replace function public.revops_cohorts(
  p_ws uuid, p_ini date default null, p_fim date default null,
  p_gran text default 'mes', p_agrupar text default 'periodo', p_metrica text default 'retencao',
  p_campanha uuid default null, p_produto uuid default null, p_canal text default null,
  p_utm_source text default null, p_tag text default null, p_max int default 12)
returns jsonb language plpgsql stable set search_path to 'public' as $$
declare
  agora timestamptz := now();
  gran text := case when p_gran = 'semana' then 'semana' else 'mes' end;
  agr text := case when p_agrupar in ('campanha','produto','canal','utm_source','tag') then p_agrupar else 'periodo' end;
  met text := case when p_metrica in ('receita','recompra') then p_metrica else 'retencao' end;
  n int := least(greatest(coalesce(p_max, 12), 3), 24);
  r_linhas jsonb; r_total jsonb; r_opc jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;

  with base as (
    select pr.pessoa_id, pr.f,
      case agr
        when 'campanha' then coalesce(pe.campanha_id::text, '')
        when 'produto' then coalesce(pr.produto_id::text, '')
        when 'canal' then coalesce(nullif(pe.canal_origem, ''), '(sem origem)')
        when 'utm_source' then coalesce(nullif(pe.utm_source, ''), '(sem utm_source)')
        when 'tag' then coalesce(nullif(pr.tag, ''), '(sem tag)')
        else to_char(date_trunc(case when gran = 'mes' then 'month' else 'week' end, pr.f at time zone 'America/Sao_Paulo'), 'YYYY-MM-DD')
      end as gk
    from (select distinct on (a.pessoa_id) a.pessoa_id, a.entrou_em as f, a.produto_id, a.tag
          from alunos a where a.workspace_id = p_ws order by a.pessoa_id, a.entrou_em, a.id) pr
    join pessoas pe on pe.id = pr.pessoa_id
    where (p_ini is null or pr.f::date >= p_ini) and (p_fim is null or pr.f::date <= p_fim)
      and (p_campanha is null or pe.campanha_id = p_campanha)
      and (p_produto is null or pr.produto_id = p_produto)
      and (p_canal is null or coalesce(nullif(pe.canal_origem, ''), '(sem origem)') = p_canal)
      and (p_utm_source is null or coalesce(nullif(pe.utm_source, ''), '(sem utm_source)') = p_utm_source)
      and (p_tag is null or coalesce(nullif(pr.tag, ''), '(sem tag)') = p_tag)
  ), calc as (
    select p.gk, p.k,
      case met
        when 'receita' then
          coalesce((select sum(v.valor_liquido) from vendas v where v.workspace_id = p_ws and v.pessoa_id = p.pessoa_id and v.status = 'aprovada' and v.data_venda <= p.t), 0)
          + coalesce((select sum(cr.valor) from contas_receber cr join contratos c on c.id = cr.contrato_id
                      where cr.workspace_id = p_ws and c.pessoa_id = p.pessoa_id and cr.venda_id is null
                        and cr.status = 'recebido' and cr.data_recebimento <= p.t::date), 0)
        when 'recompra' then
          case when (select count(*) from vendas v where v.workspace_id = p_ws and v.pessoa_id = p.pessoa_id and v.status = 'aprovada' and v.data_venda <= p.t) >= 2 then 1 else 0 end
        else
          case when exists (select 1 from alunos a where a.workspace_id = p_ws and a.pessoa_id = p.pessoa_id
                            and a.entrou_em <= p.t and (a.saiu_em is null or a.saiu_em > p.t)) then 1 else 0 end
      end as v
    from (select b.gk, b.pessoa_id, k.k,
            b.f + case when gran = 'mes' then make_interval(months => k.k) else make_interval(weeks => k.k) end as t
          from base b cross join generate_series(0, n) as k(k)) p
    where p.t <= agora
  ), agg as (
    select gk, k, count(*) as el, sum(v) as soma from calc group by gk, k
  ), tot as (
    select k, count(*) as el, sum(v) as soma from calc group by k
  ), grp as (
    select gk, count(*) as tam from base group by gk
  )
  select
    (select coalesce(jsonb_agg(x order by x->>'ordem'), '[]') from (
      select jsonb_build_object('grupo', g.gk,
        'rotulo', case agr when 'campanha' then coalesce((select nome from campanhas where id::text = g.gk), '(sem campanha)')
                           when 'produto' then coalesce((select nome from produtos where id::text = g.gk), '(sem produto)')
                           else g.gk end,
        'ordem', case when agr = 'periodo' then g.gk else lpad((1000000 - g.tam)::text, 8, '0') end,
        'tamanho', g.tam,
        'pontos', (select coalesce(jsonb_agg(jsonb_build_object('k', a.k, 'el', a.el, 'abs', a.soma,
            'valor', case when met = 'receita' then round(a.soma / a.el, 2) else round(a.soma / a.el * 100, 1) end) order by a.k), '[]')
          from agg a where a.gk = g.gk)) as x
      from grp g) t),
    jsonb_build_object('tamanho', (select coalesce(sum(tam), 0) from grp),
      'pontos', (select coalesce(jsonb_agg(jsonb_build_object('k', a.k, 'el', a.el, 'abs', a.soma,
        'valor', case when met = 'receita' then round(a.soma / a.el, 2) else round(a.soma / a.el * 100, 1) end) order by a.k), '[]') from tot a))
  into r_linhas, r_total;

  select jsonb_build_object(
    'canais', coalesce((select jsonb_agg(distinct coalesce(nullif(pe.canal_origem, ''), '(sem origem)')) from alunos a join pessoas pe on pe.id = a.pessoa_id where a.workspace_id = p_ws), '[]'),
    'utm_sources', coalesce((select jsonb_agg(distinct coalesce(nullif(pe.utm_source, ''), '(sem utm_source)')) from alunos a join pessoas pe on pe.id = a.pessoa_id where a.workspace_id = p_ws), '[]'),
    'tags', coalesce((select jsonb_agg(distinct coalesce(nullif(a.tag, ''), '(sem tag)')) from alunos a where a.workspace_id = p_ws), '[]'),
    'campanhas', coalesce((select jsonb_agg(distinct jsonb_build_object('id', c.id, 'nome', c.nome)) from alunos a join pessoas pe on pe.id = a.pessoa_id join campanhas c on c.id = pe.campanha_id where a.workspace_id = p_ws), '[]'),
    'produtos', coalesce((select jsonb_agg(distinct jsonb_build_object('id', p.id, 'nome', p.nome)) from alunos a join produtos p on p.id = a.produto_id where a.workspace_id = p_ws), '[]')
  ) into r_opc;

  return jsonb_build_object('gran', gran, 'agrupar', agr, 'metrica', met, 'n', n, 'total', r_total, 'linhas', r_linhas, 'opcoes', r_opc);
end $$;
grant execute on function public.revops_cohorts(uuid,date,date,text,text,text,uuid,uuid,text,text,text,int) to authenticated;
