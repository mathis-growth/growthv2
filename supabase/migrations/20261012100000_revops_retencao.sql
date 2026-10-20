-- v0.105 — RevOps → Retenção & Expansão: coortes, recompra e RFM a partir das compras que já existem (vendas e contratos)
-- Nada duplicado: lê vendas, contratos, contrato_itens, contas_receber, pessoas, produtos e campanhas.
-- 1. produtos.categoria (texto livre) para filtrar por categoria.
-- 2. Funções de base (regra única para todas as telas):
--    revops_itens     → cada produto comprado em uma compra válida (venda aprovada sem reembolso/cancelamento; contrato não cancelado ou com parcela recebida)
--    revops_pedidos   → itens agrupados em pedidos por cliente (mesmo dia = um pedido, ou por pedido_ref, conforme revops_config.simultanea) e numerados (1ª, 2ª, 3ª...)
--    revops_receitas  → receita de cada pedido no tempo: venda aprovada pelo líquido na data da venda; contrato pelas parcelas não canceladas com vencimento (ou recebimento) até hoje
--                       custo do produto (Custos e margens: % da receita + valor por pedido) só quando cadastrado; sem custo, a margem fica indisponível (nunca inventada)
--    revops_clientes  → um registro por cliente com primeira e segunda compra, produtos de entrada, origem e campanha, já com os filtros
--    revops_rfm_clientes → notas R, F e M (1 a 5) e segmento numa data de referência
-- 3. Telas: revops_coortes, revops_recompra, revops_rfm, revops_clientes_de (lista para investigar).
-- 4. revops_config (regra de compras simultâneas, notas e segmentos do RFM) e revops_visoes (filtros salvos por pessoa).
-- 5. Tela ho-retencao no catálogo de acesso, no lugar de Cohorts e Ascensão da escada.
-- Todas as funções rodam com as permissões de quem consulta (RLS das tabelas de origem).
-- Rode DEPOIS de 20261012000000_guardrails.sql. Idempotente.

alter table produtos add column if not exists categoria text;

create table if not exists revops_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  simultanea text not null default 'dia' check (simultanea in ('dia', 'pedido')),
  rfm jsonb not null default '{}'::jsonb check (jsonb_typeof(rfm) = 'object'),
  atualizado_em timestamptz not null default now()
);
create table if not exists revops_visoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  usuario_id uuid not null default auth.uid(),
  nome text not null check (char_length(nome) between 1 and 80),
  aba text not null default 'coortes' check (aba in ('coortes', 'recompra', 'rfm')),
  filtros jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
alter table revops_config enable row level security;
alter table revops_visoes enable row level security;
drop policy if exists revops_config_acesso on revops_config;
create policy revops_config_acesso on revops_config for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on revops_config;
create policy perm_ler on revops_config as restrictive for select using (perm(workspace_id, 'ler', array['revops', 'adm']));
drop policy if exists perm_escrever on revops_config;
create policy perm_escrever on revops_config as restrictive for all using (perm(workspace_id, 'editar', array['revops'])) with check (perm(workspace_id, 'editar', array['revops']));
drop policy if exists revops_visoes_acesso on revops_visoes;
create policy revops_visoes_acesso on revops_visoes for all to authenticated using (pertence_ao_workspace(workspace_id) and usuario_id = auth.uid()) with check (pertence_ao_workspace(workspace_id) and usuario_id = auth.uid());

-- ---------- base ----------
create or replace function public.revops_itens(p_ws uuid)
returns table (pessoa_id uuid, dia date, fonte text, ref uuid, produto_id uuid, campanha_id uuid, pedido_ref text)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  select v.pessoa_id, (coalesce(v.aprovada_em, v.data_venda) at time zone 'America/Sao_Paulo')::date, 'venda', v.id, v.produto_id, v.campanha_id, v.pedido_ref
    from vendas v
   where v.workspace_id = p_ws and v.pessoa_id is not null and v.status = 'aprovada' and v.reembolsada_em is null and v.cancelada_em is null
  union all
  select c.pessoa_id, coalesce(c.data_inicio, (c.ativado_em at time zone 'America/Sao_Paulo')::date, (c.criado_em at time zone 'America/Sao_Paulo')::date), 'contrato', c.id,
         i.produto_id, c.campanha_id, null
    from contratos c left join contrato_itens i on i.contrato_id = c.id
   where c.workspace_id = p_ws and c.pessoa_id is not null
     and (c.status <> 'cancelado' or exists (select 1 from contas_receber r where r.contrato_id = c.id and r.status = 'recebido'))
$$;

create or replace function public.revops_pedidos(p_ws uuid)
returns table (pessoa_id uuid, ord int, dia date, produtos uuid[], campanhas uuid[], fontes text[], refs uuid[])
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with cfg as (select coalesce((select simultanea from revops_config where workspace_id = p_ws), 'dia') as sim),
  it as (
    select i.*, case when (select sim from cfg) = 'dia' then i.dia::text else coalesce(i.pedido_ref, i.fonte || ':' || i.ref::text) end as chave
      from revops_itens(p_ws) i
  ), g as (
    select it.pessoa_id, it.chave, min(it.dia) as dia,
           array_agg(distinct it.produto_id) filter (where it.produto_id is not null) as produtos,
           array_agg(distinct it.campanha_id) filter (where it.campanha_id is not null) as campanhas,
           array_agg(distinct it.fonte) as fontes, array_agg(distinct it.ref) as refs
      from it group by it.pessoa_id, it.chave
  )
  select g.pessoa_id, (row_number() over (partition by g.pessoa_id order by g.dia, g.chave))::int, g.dia,
         coalesce(g.produtos, '{}'), coalesce(g.campanhas, '{}'), g.fontes, g.refs
    from g
$$;

create or replace function public.revops_receitas(p_ws uuid)
returns table (pessoa_id uuid, ord int, dia_pedido date, dia date, produto_id uuid, valor numeric, custo numeric, fonte text)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with p as (select * from revops_pedidos(p_ws)),
  ref as (select p.pessoa_id, p.ord, p.dia, unnest(p.refs) as r from p),
  ev as (
    select v.pessoa_id, v.id as r, (coalesce(v.aprovada_em, v.data_venda) at time zone 'America/Sao_Paulo')::date as dia, v.produto_id,
           coalesce(v.valor_liquido, coalesce(v.valor_bruto, 0) - coalesce(v.taxa_plataforma, 0) - coalesce(v.impostos, 0)) as valor, 'venda' as fonte, 1 as n_prod
      from vendas v
     where v.workspace_id = p_ws and v.pessoa_id is not null and v.status = 'aprovada' and v.reembolsada_em is null and v.cancelada_em is null
    union all
    select c.pessoa_id, c.id, coalesce(r.data_recebimento, r.vencimento), i.produto_id,
           (r.valor - coalesce(r.desconto, 0)) * case when it.tot > 0 then coalesce(i.valor, 0) * coalesce(i.quantidade, 1) / it.tot when it.n > 0 then 1.0 / it.n else 1 end,
           'contrato', 1
      from contratos c
      join contas_receber r on r.contrato_id = c.id and r.venda_id is null and r.status not in ('cancelado', 'estornado') and r.substituida_por is null
           and coalesce(r.data_recebimento, r.vencimento) <= (now() at time zone 'America/Sao_Paulo')::date
      left join lateral (select sum(coalesce(x.valor, 0) * coalesce(x.quantidade, 1)) as tot, count(*) as n from contrato_itens x where x.contrato_id = c.id) it on true
      left join contrato_itens i on i.contrato_id = c.id
     where c.workspace_id = p_ws and c.pessoa_id is not null
  )
  select e.pessoa_id, rf.ord, rf.dia, e.dia, e.produto_id, round(e.valor, 2),
         case when pr.id is null or not (pr.extras ? 'mc_custo_pct' or pr.extras ? 'mc_custo_cliente') then null
              else round(e.valor * coalesce(nullif(pr.extras ->> 'mc_custo_pct', '')::numeric, 0) / 100
                   + case when row_number() over (partition by e.pessoa_id, rf.ord, e.produto_id order by e.dia) = 1 then coalesce(nullif(pr.extras ->> 'mc_custo_cliente', '')::numeric, 0) else 0 end, 2) end,
         e.fonte
    from ev e join ref rf on rf.pessoa_id = e.pessoa_id and rf.r = e.r
    left join produtos pr on pr.id = e.produto_id
$$;

-- ---------- RFM ----------
create or replace function public.revops_rfm_padrao() returns jsonb language sql immutable as $$
  select jsonb_build_object('metodo', 'quintis', 'janela_dias', 365,
    'limites', jsonb_build_object('r', jsonb_build_array(30, 90, 180, 365), 'f', jsonb_build_array(1, 2, 3, 5), 'm', jsonb_build_array(500, 1500, 4000, 10000)),
    'segmentos', jsonb_build_array(
      jsonb_build_object('nome', 'Campeões', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(4, 5)),
      jsonb_build_object('nome', 'Clientes leais', 'r', jsonb_build_array(3, 5), 'f', jsonb_build_array(3, 5)),
      jsonb_build_object('nome', 'Novos clientes', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(1, 1)),
      jsonb_build_object('nome', 'Potenciais leais', 'r', jsonb_build_array(4, 5), 'f', jsonb_build_array(2, 3)),
      jsonb_build_object('nome', 'Precisam de atenção', 'r', jsonb_build_array(3, 3), 'f', jsonb_build_array(1, 2)),
      jsonb_build_object('nome', 'Em risco', 'r', jsonb_build_array(1, 2), 'f', jsonb_build_array(3, 5)),
      jsonb_build_object('nome', 'Hibernando', 'r', jsonb_build_array(1, 2), 'f', jsonb_build_array(1, 2))))
$$;

/* notas numa data de referência. Recência: dias desde a última compra válida até a referência. Frequência: pedidos na janela (referência − janela_dias, referência].
   Valor: receita na janela. Quintis: nota pela posição (empates ficam juntos); limites: 4 cortes crescentes. Segmento: a primeira regra que bate, na ordem; senão "Outros". */
create or replace function public.revops_rfm_clientes(p_ws uuid, p_ref date default null, p_cfg jsonb default null)
returns table (pessoa_id uuid, ultima date, dias int, f int, m numeric, sr int, sf int, sm int, segmento text)
language plpgsql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
#variable_conflict use_column
declare cfg jsonb; ref date := coalesce(p_ref, (now() at time zone 'America/Sao_Paulo')::date); jan int; met text; lr jsonb; lf jsonb; lm jsonb;
begin
  cfg := revops_rfm_padrao() || coalesce((select rfm from revops_config where workspace_id = p_ws), '{}'::jsonb) || coalesce(p_cfg, '{}'::jsonb);
  jan := greatest(30, coalesce((cfg ->> 'janela_dias')::int, 365)); met := coalesce(cfg ->> 'metodo', 'quintis');
  lr := cfg -> 'limites' -> 'r'; lf := cfg -> 'limites' -> 'f'; lm := cfg -> 'limites' -> 'm';
  return query
  with p as (select * from revops_pedidos(p_ws) x where x.dia <= ref),
  rc as (select * from revops_receitas(p_ws) x where x.dia <= ref and x.dia > ref - jan),
  rm as (select rc.pessoa_id, sum(rc.valor) as m from rc group by rc.pessoa_id),
  b as (
    select pp.pessoa_id, pp.ultima, pp.dias, pp.f, coalesce(rm.m, 0) as m
      from (select p.pessoa_id, max(p.dia) as ultima, (ref - max(p.dia))::int as dias, (count(*) filter (where p.dia > ref - jan))::int as f from p group by p.pessoa_id) pp
      left join rm on rm.pessoa_id = pp.pessoa_id
  ), s as (
    select b.*,
      case when met = 'quintis' then 5 - least(4, floor(percent_rank() over (order by b.dias) * 5))::int
           else case when b.dias <= (lr ->> 0)::numeric then 5 when b.dias <= (lr ->> 1)::numeric then 4 when b.dias <= (lr ->> 2)::numeric then 3 when b.dias <= (lr ->> 3)::numeric then 2 else 1 end end as sr,
      case when met = 'quintis' then 1 + least(4, floor(percent_rank() over (order by b.f) * 5))::int
           else case when b.f <= (lf ->> 0)::numeric then 1 when b.f <= (lf ->> 1)::numeric then 2 when b.f <= (lf ->> 2)::numeric then 3 when b.f <= (lf ->> 3)::numeric then 4 else 5 end end as sf,
      case when met = 'quintis' then 1 + least(4, floor(percent_rank() over (order by b.m) * 5))::int
           else case when b.m <= (lm ->> 0)::numeric then 1 when b.m <= (lm ->> 1)::numeric then 2 when b.m <= (lm ->> 2)::numeric then 3 when b.m <= (lm ->> 3)::numeric then 4 else 5 end end as sm
    from b
  )
  select s.pessoa_id, s.ultima, s.dias, s.f, round(s.m, 2), s.sr, s.sf, s.sm,
    coalesce((select g ->> 'nome' from jsonb_array_elements(cfg -> 'segmentos') with ordinality as t(g, o)
              where s.sr between coalesce((g -> 'r' ->> 0)::int, 1) and coalesce((g -> 'r' ->> 1)::int, 5)
                and s.sf between coalesce((g -> 'f' ->> 0)::int, 1) and coalesce((g -> 'f' ->> 1)::int, 5)
                and s.sm between coalesce((g -> 'm' ->> 0)::int, 1) and coalesce((g -> 'm' ->> 1)::int, 5)
              order by o limit 1), 'Outros')
    from s;
end $$;

/* filtros (p_f): ini, fim (primeira compra), produto e categoria (produto de entrada), canal (pessoas.canal_origem), origem (pessoas.utm_source),
   campanha (da pessoa ou da primeira compra), segmento (RFM na data de hoje) */
create or replace function public.revops_clientes(p_ws uuid, p_f jsonb default '{}')
returns table (pessoa_id uuid, primeira date, segunda date, ultima date, n int, entrada uuid[], canal text, origem text, campanha uuid)
language sql stable rows 5000 set search_path = public set enable_nestloop = off set jit = off as $$
  with p as (select * from revops_pedidos(p_ws)),
  c as (
    select g.*, p1.produtos as entrada, p1.campanhas as camp1
      from (select p.pessoa_id, min(p.dia) filter (where p.ord = 1) as primeira, min(p.dia) filter (where p.ord = 2) as segunda, max(p.dia) as ultima, count(*)::int as n
              from p group by p.pessoa_id) g
      join p p1 on p1.pessoa_id = g.pessoa_id and p1.ord = 1
  )
  select c.pessoa_id, c.primeira, c.segunda, c.ultima, c.n, c.entrada, coalesce(nullif(pe.canal_origem, ''), '(sem origem)'), coalesce(nullif(pe.utm_source, ''), '(sem utm_source)'),
         coalesce(pe.campanha_id, c.camp1[1])
    from c join pessoas pe on pe.id = c.pessoa_id
   where (nullif(p_f ->> 'ini', '') is null or c.primeira >= (p_f ->> 'ini')::date)
     and (nullif(p_f ->> 'fim', '') is null or c.primeira <= (p_f ->> 'fim')::date)
     and (nullif(p_f ->> 'produto', '') is null or (p_f ->> 'produto')::uuid = any (c.entrada))
     and (nullif(p_f ->> 'categoria', '') is null or exists (select 1 from produtos x where x.id = any (c.entrada) and x.categoria = p_f ->> 'categoria'))
     and (nullif(p_f ->> 'canal', '') is null or coalesce(nullif(pe.canal_origem, ''), '(sem origem)') = p_f ->> 'canal')
     and (nullif(p_f ->> 'origem', '') is null or coalesce(nullif(pe.utm_source, ''), '(sem utm_source)') = p_f ->> 'origem')
     and (nullif(p_f ->> 'campanha', '') is null or coalesce(pe.campanha_id, c.camp1[1]) = (p_f ->> 'campanha')::uuid)
     and (nullif(p_f ->> 'segmento', '') is null or c.pessoa_id in (select s.pessoa_id from revops_rfm_clientes(p_ws, null, null) s where s.segmento = p_f ->> 'segmento'))
$$;

-- ---------- coortes ----------
create or replace function public.revops_coortes(p_ws uuid, p_f jsonb default '{}', p_gran text default 'mes', p_agrupar text default 'periodo', p_hz int default 12)
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date; gran text := case when p_gran in ('trimestre', 'ano') then p_gran else 'mes' end;
  passo int := case gran when 'trimestre' then 3 when 'ano' then 12 else 1 end; hz int := least(greatest(coalesce(p_hz, 12), 3), 36); r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, p_f)),
  m as materialized (
    select cl.*, case when p_agrupar = 'produto' then e.pid::text
                      else to_char(date_trunc(case gran when 'trimestre' then 'quarter' when 'ano' then 'year' else 'month' end, cl.primeira), 'YYYY-MM-DD') end as gk,
           (cl.segunda - cl.primeira) as d2,
           case when cl.segunda is not null then ((date_part('year', age(cl.segunda, cl.primeira)) * 12 + date_part('month', age(cl.segunda, cl.primeira)))::int / passo) end as k2
      from cl left join lateral (select unnest(case when p_agrupar = 'produto' then coalesce(nullif(cl.entrada, '{}'), array[null::uuid]) else array[null::uuid] end) as pid) e on true
  ),
  mt as materialized (select distinct cl.pessoa_id, cl.primeira, cl.segunda - cl.primeira as d2, cl.n from cl),
  rc as materialized (select x.* from revops_receitas(p_ws) x join cl on cl.pessoa_id = x.pessoa_id),
  rcm as (select m.gk, rc.valor, rc.custo, rc.ord, ((date_part('year', age(rc.dia, m.primeira)) * 12 + date_part('month', age(rc.dia, m.primeira)))::int / passo) as k
            from m join rc on rc.pessoa_id = m.pessoa_id),
  ped as (select distinct m.gk, m.pessoa_id, ((date_part('year', age(p.dia, m.primeira)) * 12 + date_part('month', age(p.dia, m.primeira)))::int / passo) as k
            from m join revops_pedidos(p_ws) p on p.pessoa_id = m.pessoa_id),
  g as materialized (
    select m.gk, count(*) as n, min(m.primeira) as ini, max(m.primeira) as fim,
      count(*) filter (where m.d2 is not null) as rec, count(*) filter (where m.n >= 2) as dois,
      round(avg(m.d2) filter (where m.d2 is not null), 1) as d2_media, percentile_cont(0.5) within group (order by m.d2) filter (where m.d2 is not null) as d2_mediana
      from m group by m.gk
  ),
  hzs as (select unnest(array[30, 60, 90, 180, 365]) as h),
  dias as (select generate_series(0, 365, 5) as d),
  ks as (select generate_series(0, hz) as k),
  taxa as (
    select m.gk, h.h, count(*) filter (where hoje - m.primeira >= h.h) as el, count(*) filter (where hoje - m.primeira >= h.h and m.d2 <= h.h) as sim, count(*) as n
      from m cross join hzs h group by m.gk, h.h
  ),
  curva as (
    select m.gk, d.d, count(*) filter (where m.d2 <= d.d) as sim from m cross join dias d group by m.gk, d.d
  ),
  rcg as (select rcm.gk, sum(rcm.valor) as rec, sum(rcm.valor) filter (where rcm.ord > 1) as exist, sum(rcm.valor - rcm.custo) filter (where rcm.custo is not null) as mc,
                 sum(rcm.valor) filter (where rcm.custo is not null) as com_custo from rcm group by rcm.gk),
  mk as (
    select m.gk, ks.k, count(*) filter (where (m.primeira + make_interval(months => ks.k * passo))::date <= hoje) as el,
           count(*) filter (where m.k2 is not null and m.k2 <= ks.k) as rec
      from m cross join ks group by m.gk, ks.k
  ),
  rk as (select gk, k, sum(valor) as v from rcm group by gk, k),
  ak as (select gk, k, count(*) as a from ped group by gk, k),
  mat as (
    select g.gk, mk.k, (g.fim + make_interval(months => (mk.k + 1) * passo))::date <= hoje as completo, mk.el, mk.rec,
           coalesce(sum(rk.v) over (partition by g.gk order by mk.k), 0) as receita, coalesce(ak.a, 0) as ativos, g.n
      from g join mk on mk.gk is not distinct from g.gk
      left join rk on rk.gk is not distinct from g.gk and rk.k = mk.k
      left join ak on ak.gk is not distinct from g.gk and ak.k = mk.k
  ),
  tt as (select h.h, count(*) filter (where hoje - z.primeira >= h.h) as el, count(*) filter (where hoje - z.primeira >= h.h and z.d2 <= h.h) as sim, count(*) as n
           from mt z cross join hzs h group by h.h),
  -- curva de todas as coortes juntas: em cada dia, entre os clientes que já têm aquele tempo de observação
  tc as (select d.d, count(*) filter (where hoje - z.primeira >= d.d) as n, count(*) filter (where hoje - z.primeira >= d.d and z.d2 <= d.d) as sim from mt z cross join dias d group by d.d)
  select jsonb_build_object(
    'gran', gran, 'agrupar', p_agrupar, 'hz', hz, 'hoje', hoje,
    'total', jsonb_build_object(
      'clientes', (select count(*) from mt), 'recompraram', (select count(*) from mt where d2 is not null), 'dois_mais', (select count(*) from mt where n >= 2),
      'd2_media', (select round(avg(d2), 1) from mt where d2 is not null), 'd2_mediana', (select percentile_cont(0.5) within group (order by d2) from mt where d2 is not null),
      'receita', (select coalesce(sum(valor), 0) from rc), 'receita_exist', (select coalesce(sum(valor), 0) from rc where ord > 1),
      'mc', (select sum(valor - custo) from rc where custo is not null), 'com_custo', (select coalesce(sum(valor), 0) from rc where custo is not null),
      'taxas', (select coalesce(jsonb_agg(jsonb_build_object('h', h, 'el', el, 'sim', sim, 'n', n, 'taxa', case when el = n and n > 0 then round(sim::numeric / n * 100, 1) end,
                  'parcial', case when el > 0 then round(sim::numeric / el * 100, 1) end) order by h), '[]') from tt),
      'curva', (select coalesce(jsonb_agg(jsonb_build_object('d', d, 'n', n, 'sim', sim, 'pct', case when n > 0 and sim is not null then round(sim::numeric / n * 100, 1) end) order by d), '[]') from tc)),
    'coortes', coalesce((select jsonb_agg(jsonb_build_object(
        'gk', g.gk, 'rotulo', case when p_agrupar = 'produto' then coalesce((select nome from produtos where id::text = g.gk), '(sem produto)') else g.gk end,
        'n', g.n, 'ini', g.ini, 'fim', g.fim, 'obs_dias', hoje - g.fim, 'recompraram', g.rec, 'dois_mais', g.dois, 'd2_media', g.d2_media, 'd2_mediana', g.d2_mediana,
        'receita', coalesce(rcg.rec, 0), 'receita_cli', round(coalesce(rcg.rec, 0) / g.n, 2), 'receita_exist', coalesce(rcg.exist, 0),
        'mc', rcg.mc, 'com_custo', coalesce(rcg.com_custo, 0),
        'taxas', (select jsonb_agg(jsonb_build_object('h', t.h, 'el', t.el, 'sim', t.sim, 'taxa', case when t.el = t.n then round(t.sim::numeric / t.n * 100, 1) end,
                    'parcial', case when t.el > 0 then round(t.sim::numeric / t.el * 100, 1) end) order by t.h) from taxa t where t.gk is not distinct from g.gk),
        'curva', (select jsonb_agg(jsonb_build_object('d', c.d, 'sim', case when hoje - g.fim >= c.d then c.sim end,
                    'pct', case when hoje - g.fim >= c.d then round(c.sim::numeric / g.n * 100, 1) end) order by c.d) from curva c where c.gk is not distinct from g.gk),
        'matriz', (select jsonb_agg(jsonb_build_object('k', x.k, 'completo', x.completo, 'el', x.el,
                    'recompra', round(x.rec::numeric / x.n * 100, 1), 'receita_cli', round(x.receita / x.n, 2), 'ativos', round(x.ativos::numeric / x.n * 100, 1)) order by x.k)
                   from mat x where x.gk is not distinct from g.gk and x.el > 0)
      ) order by case when p_agrupar = 'produto' then lpad((1000000 - g.n)::text, 8, '0') else g.gk end) from g left join rcg on rcg.gk is not distinct from g.gk), '[]')
  ) into r;
  return r;
end $$;

-- ---------- recompra ----------
create or replace function public.revops_recompra(p_ws uuid, p_f jsonb default '{}')
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date; r jsonb;
  ini date := coalesce(nullif(p_f ->> 'ini', '')::date, (date_trunc('month', hoje) - interval '11 months')::date); fim date := coalesce(nullif(p_f ->> 'fim', '')::date, hoje);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, p_f)),
  -- para novos × existentes vale o mesmo filtro, menos a data da primeira compra (a janela é a das receitas)
  cl_todos as (select * from revops_clientes(p_ws, p_f - 'ini' - 'fim')),
  p as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rcj as (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl_todos) and x.dia between ini and fim),
  rco as (select pessoa_id, ord, sum(valor) as v from rc group by 1, 2),
  rpos as (select pessoa_id, sum(valor) as v from rc where ord >= 2 group by 1),
  pv as (select p.*, rco.v as receita from p left join rco on rco.pessoa_id = p.pessoa_id and rco.ord = p.ord),
  inter as (select (p.dia - lag(p.dia) over (partition by p.pessoa_id order by p.ord)) as d from p),
  d2 as (select cl.pessoa_id, cl.segunda - cl.primeira as d from cl where cl.segunda is not null),
  ent as (select cl.pessoa_id, unnest(coalesce(nullif(cl.entrada, '{}'), array[null::uuid])) as de from cl),
  depois as (select distinct p.pessoa_id, unnest(p.produtos) as para from p where p.ord >= 2),
  seg as (select distinct p.pessoa_id, unnest(p.produtos) as prod from p where p.ord = 2)
  select jsonb_build_object('ini', ini, 'fim', fim,
    'kpi', jsonb_build_object(
      'primeira', (select count(*) from cl), 'segunda', (select count(*) from cl where segunda is not null),
      'intervalo_media', (select round(avg(d), 1) from inter where d is not null), 'intervalo_mediana', (select percentile_cont(0.5) within group (order by d) from inter where d is not null),
      'frequencia', (select round(avg(n), 2) from cl), 'pedidos_recompra', (select count(*) from pv where ord >= 2),
      'receita_recompra', (select coalesce(sum(receita), 0) from pv where ord >= 2),
      'receita_2', (select coalesce(sum(valor), 0) from rc where ord = 2), 'receita_3mais', (select coalesce(sum(valor), 0) from rc where ord >= 3),
      'mc_recorrente', (select sum(valor - custo) from rc where ord >= 2 and custo is not null), 'com_custo_recorrente', (select coalesce(sum(valor), 0) from rc where ord >= 2 and custo is not null),
      'receita_recorrente', (select coalesce(sum(valor), 0) from rc where ord >= 2)),
    'curva', (select coalesce(jsonb_agg(jsonb_build_object('d', d.d, 'n', z.n, 'sim', z.sim, 'pct', case when z.n > 0 then round(z.sim::numeric / z.n * 100, 1) end) order by d.d), '[]')
              from generate_series(0, 365, 5) d(d) cross join lateral (select count(*) filter (where hoje - cl.primeira >= d.d) as n,
                    count(*) filter (where hoje - cl.primeira >= d.d and cl.segunda - cl.primeira <= d.d) as sim from cl) z),
    'distribuicao', (select coalesce(jsonb_agg(jsonb_build_object('faixa', f.rot, 'min', f.a, 'max', f.b, 'n', (select count(*) from d2 where d2.d between f.a and f.b))
                     order by f.o), '[]')
                     from (values (1, 'Até 7 dias', 0, 7), (2, '8 a 30', 8, 30), (3, '31 a 60', 31, 60), (4, '61 a 90', 61, 90), (5, '91 a 180', 91, 180), (6, '181 a 365', 181, 365), (7, 'Mais de 365', 366, 100000)) f(o, rot, a, b)),
    'novos_existentes', (select coalesce(jsonb_agg(jsonb_build_object('mes', x.mes, 'novos', x.nov, 'existentes', x.ex) order by x.mes), '[]')
                         from (select to_char(date_trunc('month', dia), 'YYYY-MM') as mes, coalesce(sum(valor) filter (where ord = 1), 0) as nov, coalesce(sum(valor) filter (where ord > 1), 0) as ex
                                 from rcj group by 1) x),
    'reconciliacao', jsonb_build_object('vendas', (select coalesce(sum(valor), 0) from rcj where fonte = 'venda'), 'contratos', (select coalesce(sum(valor), 0) from rcj where fonte = 'contrato')),
    'segunda_produtos', (select coalesce(jsonb_agg(jsonb_build_object('produto', s.prod, 'nome', pr.nome, 'clientes', s.n,
                            'receita', (select coalesce(sum(valor), 0) from rc where rc.ord = 2 and rc.produto_id = s.prod)) order by s.n desc), '[]')
                         from (select prod, count(*) as n from seg group by prod) s left join produtos pr on pr.id = s.prod),
    'entrada', (select coalesce(jsonb_agg(jsonb_build_object('produto', e.de, 'nome', coalesce(pr.nome, '(sem produto)'), 'clientes', e.n, 'recompraram', e.rec,
                    'pct', round(e.rec::numeric / e.n * 100, 1), 'receita_depois', e.rd, 'receita_depois_cli', round(e.rd / e.n, 2)) order by e.n desc), '[]')
                from (select ent.de, count(*) as n, count(*) filter (where cl.segunda is not null) as rec,
                             coalesce(sum(rpos.v), 0) as rd
                        from ent join cl on cl.pessoa_id = ent.pessoa_id left join rpos on rpos.pessoa_id = ent.pessoa_id group by ent.de) e left join produtos pr on pr.id = e.de),
    'transicao', (select coalesce(jsonb_agg(jsonb_build_object('de', t.de, 'para', t.para, 'n', t.n,
                    'pct', round(t.n::numeric / nullif((select count(*) from ent e2 where e2.de is not distinct from t.de), 0) * 100, 1)) order by t.n desc), '[]')
                  from (select ent.de, depois.para, count(*) as n from ent join depois on depois.pessoa_id = ent.pessoa_id group by 1, 2) t),
    'produtos', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'nome', nome, 'nivel', nivel_escada, 'categoria', categoria) order by nivel_escada nulls last, nome), '[]') from produtos where workspace_id = p_ws)
  ) into r;
  return r;
end $$;

-- ---------- RFM (tela) ----------
create or replace function public.revops_rfm(p_ws uuid, p_f jsonb default '{}', p_ref date default null, p_cfg jsonb default null, p_cruzar text default 'produto')
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare ref date := coalesce(p_ref, (now() at time zone 'America/Sao_Paulo')::date); cfg jsonb; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  cfg := revops_rfm_padrao() || coalesce((select rfm from revops_config where workspace_id = p_ws), '{}'::jsonb) || coalesce(p_cfg, '{}'::jsonb);
  with cl as materialized (select * from revops_clientes(p_ws, (p_f - 'ini' - 'fim' - 'segmento'))),
  s as materialized (select x.* from revops_rfm_clientes(p_ws, ref, cfg) x where x.pessoa_id in (select pessoa_id from cl)),
  ent as (select cl.pessoa_id, coalesce(string_agg(pr.nome, ' + ' order by pr.nome), '(sem produto)') as nome from cl left join produtos pr on pr.id = any (cl.entrada) group by cl.pessoa_id),
  jan as (select (cfg ->> 'janela_dias')::int as j),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from s) and x.dia <= ref and x.dia > ref - (select j from jan)),
  pj as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from s) and x.dia <= ref and x.dia > ref - (select j from jan)),
  cz as (
    select s.segmento, case p_cruzar when 'campanha' then coalesce((select nome from campanhas where id = cl.campanha), '(sem campanha)')
                                     when 'canal' then cl.canal when 'origem' then cl.origem
                                     else ent.nome end as chave, count(*) as n
      from s join cl on cl.pessoa_id = s.pessoa_id join ent on ent.pessoa_id = s.pessoa_id group by 1, 2
  )
  select jsonb_build_object('ref', ref, 'config', cfg, 'cruzar', p_cruzar,
    'clientes', (select count(*) from s), 'receita', (select coalesce(sum(valor), 0) from rc),
    'segmentos', (select coalesce(jsonb_agg(jsonb_build_object('nome', g.segmento, 'clientes', g.n, 'receita', g.rec,
          'pct_receita', round(g.rec / nullif((select sum(valor) from rc), 0) * 100, 1), 'ticket', round(g.rec / nullif(g.ped, 0), 2), 'frequencia', round(g.ped::numeric / g.n, 2),
          'receita_cli', round(g.rec / g.n, 2), 'dias', g.dias, 'mc', g.mc, 'com_custo', g.cc,
          'produtos', (select jsonb_agg(z) from (select pr.nome, count(*) as n from pj join s s2 on s2.pessoa_id = pj.pessoa_id and s2.segmento = g.segmento
                         cross join unnest(pj.produtos) u(pid) join produtos pr on pr.id = u.pid group by pr.nome order by count(*) desc limit 3) z))
          order by g.rec desc), '[]')
      from (select s.segmento, count(*) as n, round(avg(s.dias)) as dias,
                   coalesce((select sum(valor) from rc where rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)), 0) as rec,
                   (select count(*) from pj where pj.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as ped,
                   (select sum(valor - custo) from rc where custo is not null and rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as mc,
                   (select coalesce(sum(valor), 0) from rc where custo is not null and rc.pessoa_id in (select pessoa_id from s s3 where s3.segmento = s.segmento)) as cc
              from s group by s.segmento) g),
    'grade', (select coalesce(jsonb_agg(jsonb_build_object('r', sr, 'f', sf, 'n', n)), '[]') from (select sr, sf, count(*) as n from s group by sr, sf) x),
    'cruzamento', (select coalesce(jsonb_agg(jsonb_build_object('segmento', segmento, 'chave', chave, 'n', n)), '[]') from cz)
  ) into r;
  return r;
end $$;

-- ---------- lista para investigar ----------
/* p_sel: coorte + gran + agrupar | recomprou (sim/nao) | ate_dias | d2_min/d2_max | segunda_produto | de + para | segmento (+ ref, cfg) | mes_receita + tipo (novos/existentes) */
create or replace function public.revops_clientes_de(p_ws uuid, p_f jsonb default '{}', p_sel jsonb default '{}', p_limite int default 500)
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $$
declare r jsonb; gran text := coalesce(p_sel ->> 'gran', 'mes'); hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  ref date := coalesce(nullif(p_sel ->> 'ref', '')::date, hoje);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with cl as materialized (select * from revops_clientes(p_ws, case when p_sel ? 'segmento' or p_sel ? 'mes_receita' then p_f - 'ini' - 'fim' - 'segmento' else p_f end)),
  p as materialized (select x.* from revops_pedidos(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rc as materialized (select x.* from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from cl)),
  rco as materialized (select pessoa_id, ord, sum(valor) as v from rc group by 1, 2),
  rfm as (select x.* from revops_rfm_clientes(p_ws, ref, p_sel -> 'cfg') x where p_sel ? 'segmento'),
  sel as (
    select cl.* from cl
     where (not p_sel ? 'coorte' or (case when p_sel ->> 'agrupar' = 'produto' then (p_sel ->> 'coorte')::uuid = any (cl.entrada)
             else to_char(date_trunc(case gran when 'trimestre' then 'quarter' when 'ano' then 'year' else 'month' end, cl.primeira), 'YYYY-MM-DD') = p_sel ->> 'coorte' end))
       and (not p_sel ? 'recomprou' or ((p_sel ->> 'recomprou') = 'sim') = (cl.segunda is not null and (not p_sel ? 'ate_dias' or cl.segunda - cl.primeira <= (p_sel ->> 'ate_dias')::int)))
       and (not p_sel ? 'd2_min' or (cl.segunda is not null and cl.segunda - cl.primeira between (p_sel ->> 'd2_min')::int and (p_sel ->> 'd2_max')::int))
       and (not p_sel ? 'segunda_produto' or exists (select 1 from p where p.pessoa_id = cl.pessoa_id and p.ord = 2 and (p_sel ->> 'segunda_produto')::uuid = any (p.produtos)))
       and (not p_sel ? 'de' or (case when p_sel ->> 'de' = '' then cl.entrada = '{}' else (p_sel ->> 'de')::uuid = any (cl.entrada) end))
       and (not p_sel ? 'para' or exists (select 1 from p where p.pessoa_id = cl.pessoa_id and p.ord >= 2 and (p_sel ->> 'para')::uuid = any (p.produtos)))
       and (not p_sel ? 'segmento' or exists (select 1 from rfm where rfm.pessoa_id = cl.pessoa_id and rfm.segmento = p_sel ->> 'segmento'))
       and (not p_sel ? 'mes_receita' or exists (select 1 from rc where rc.pessoa_id = cl.pessoa_id and to_char(rc.dia, 'YYYY-MM') = p_sel ->> 'mes_receita'
                and ((p_sel ->> 'tipo') = 'existentes') = (rc.ord > 1)))
     order by cl.primeira desc
  )
  select jsonb_build_object('total', (select count(*) from sel), 'limite', p_limite,
    'clientes', coalesce((select jsonb_agg(x order by x ->> 'primeira' desc) from (
      select jsonb_build_object('id', sel.pessoa_id, 'nome', pe.nome, 'email', pe.email, 'telefone', pe.telefone, 'primeira', sel.primeira, 'segunda', sel.segunda, 'ultima', sel.ultima,
        'pedidos', sel.n, 'dias_ultima', hoje - sel.ultima, 'canal', sel.canal, 'origem', sel.origem, 'campanha', (select nome from campanhas where id = sel.campanha),
        'receita', (select coalesce(sum(v), 0) from rco where rco.pessoa_id = sel.pessoa_id),
        'entrada', (select string_agg(nome, ' + ' order by nome) from produtos where id = any (sel.entrada)),
        'segmento', (select segmento from rfm where rfm.pessoa_id = sel.pessoa_id), 'rfm', (select sr || '' || sf || '' || sm from rfm where rfm.pessoa_id = sel.pessoa_id),
        'historico', (select jsonb_agg(jsonb_build_object('ord', p.ord, 'dia', p.dia, 'produtos', (select string_agg(nome, ' + ' order by nome) from produtos where id = any (p.produtos)),
                        'receita', (select coalesce(sum(v), 0) from rco where rco.pessoa_id = p.pessoa_id and rco.ord = p.ord)) order by p.ord) from p where p.pessoa_id = sel.pessoa_id)) as x
        from (select * from sel limit greatest(1, least(coalesce(p_limite, 500), 5000))) sel join pessoas pe on pe.id = sel.pessoa_id) z), '[]')
  ) into r;
  return r;
end $$;

do $$
declare f text;
begin
  foreach f in array array['revops_itens(uuid)', 'revops_pedidos(uuid)', 'revops_receitas(uuid)', 'revops_clientes(uuid,jsonb)', 'revops_rfm_clientes(uuid,date,jsonb)',
                           'revops_coortes(uuid,jsonb,text,text,integer)', 'revops_recompra(uuid,jsonb)', 'revops_rfm(uuid,jsonb,date,jsonb,text)', 'revops_clientes_de(uuid,jsonb,jsonb,integer)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
  if to_regprocedure('public.auditar()') is not null then
    execute 'drop trigger if exists auditoria_t on public.revops_config';
    execute 'create trigger auditoria_t after insert or update or delete on public.revops_config for each row execute function public.auditar()';
  end if;
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem)
    values ('ho-retencao', 'revops', 'Retenção & Expansão', 'RevOps', coalesce((select min(ordem) from acesso_telas where tela in ('ho-cohort', 'ho-ascensao')), 40))
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
    update pacotes_acesso set telas = telas || array['ho-retencao'] where (telas @> array['ho-cohort'] or telas @> array['ho-ascensao']) and not telas @> array['ho-retencao'];
  end if;
end $$;
