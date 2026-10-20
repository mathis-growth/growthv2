-- v0.23: ascensão da escada de produtos (determinística, sem IA). Já aplicado no banco.
create or replace function revops_ascensao(p_ws uuid, p_ini date default null, p_fim date default null, p_entrada uuid default null, p_min_dias int default 0)
returns jsonb language plpgsql stable set search_path to 'public' as $f$
declare agora timestamptz := now(); md int := greatest(coalesce(p_min_dias, 0), 0); r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with compras as (
    select v.pessoa_id, v.produto_id, min(v.data_venda) as f
    from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' group by v.pessoa_id, v.produto_id
  ), seq as (
    select c.pessoa_id, c.produto_id, c.f,
      row_number() over (partition by c.pessoa_id order by c.f, c.produto_id) as ord,
      lead(c.produto_id) over (partition by c.pessoa_id order by c.f, c.produto_id) as prox,
      lead(c.f) over (partition by c.pessoa_id order by c.f, c.produto_id) as prox_f
    from compras c
  ), coorte as (
    select s.* from seq s join (select pessoa_id, produto_id as e, f from seq where ord = 1) p on p.pessoa_id = s.pessoa_id
    where (p_ini is null or p.f::date >= p_ini) and (p_fim is null or p.f::date <= p_fim) and (p_entrada is null or p.e = p_entrada)
  ), el as (
    select * from coorte where f <= agora - make_interval(days => md)
  ), bases as (
    select produto_id, count(*) as n from el group by produto_id
  ), trans as (
    select produto_id as de, prox as para, count(*) as n, round(avg(extract(epoch from (prox_f - f)) / 86400)::numeric, 0) as dias
    from el where prox is not null group by produto_id, prox
  ), paradas as (
    select produto_id as de, count(*) as n from el where prox is null group by produto_id
  ), caminhos as (
    select caminho, count(*) as n from (select pessoa_id, array_agg(produto_id order by ord) as caminho from coorte group by pessoa_id) x group by caminho
  )
  select jsonb_build_object(
    'pessoas', (select count(distinct pessoa_id) from coorte),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'nivel', p.nivel_escada) order by p.nivel_escada nulls last, p.nome) from produtos p where p.workspace_id = p_ws and p.id in (select produto_id from coorte)), '[]'),
    'bases', coalesce((select jsonb_agg(jsonb_build_object('produto', b.produto_id, 'n', b.n)) from bases b), '[]'),
    'transicoes', coalesce((select jsonb_agg(jsonb_build_object('de', t.de, 'para', t.para, 'n', t.n, 'dias', t.dias,
        'pct', round(t.n::numeric / nullif((select n from bases where produto_id = t.de), 0) * 100, 1))) from trans t), '[]'),
    'paradas', coalesce((select jsonb_agg(jsonb_build_object('de', q.de, 'n', q.n,
        'pct', round(q.n::numeric / nullif((select n from bases where produto_id = q.de), 0) * 100, 1))) from paradas q), '[]'),
    'caminhos', coalesce((select jsonb_agg(jsonb_build_object('produtos', to_jsonb(c.caminho), 'n', c.n,
        'pct', round(c.n::numeric / nullif((select count(distinct pessoa_id) from coorte), 0) * 100, 1)) order by c.n desc) from (select * from caminhos order by n desc limit 25) c), '[]')
  ) into r;
  return r;
end $f$;
grant execute on function revops_ascensao(uuid, date, date, uuid, int) to authenticated;
