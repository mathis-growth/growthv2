-- v0.217 — Growth's Brain: investigação (drill-down, filtro cruzado e drill-through até os registros).
--
-- investigar(ws, metrica, ini, fim, filtros): o total do período e do período anterior do mesmo tamanho, aberto por dimensão:
--   faturamento e vendas → produto, campanha, canal, plataforma, cliente (novo × recorrente);
--   leads                → campanha de origem, canal, qualificação, situação (virou cliente × ainda lead).
--   Os filtros ({"produto": "<id>", "canal": "meta_ads", ...}) valem para todas as dimensões ao mesmo tempo (filtro cruzado).
--   O histórico importado entra como fatia própria ("Histórico importado"), para o total bater com o Cockpit e o Dashboard de vendas.
-- investigar_registros(ws, metrica, ini, fim, filtros, limite): as vendas ou os leads por trás do número (até 500).
-- Regras do realizado iguais às das metas: vendas aprovadas pela data da venda; leads = pessoas captadas pela data do cadastro.
-- Só leitura. Depende do RODAR_v0.216. Pode rodar de novo sem erro.

create or replace function public.investigar_linhas(p_ws uuid, p_metrica text, p_ini date, p_fim date)
returns table (atual boolean, dia date, valor numeric, d jsonb, reg jsonb)
language sql stable security definer set search_path = public as $$
  with per as (select p_ini - (p_fim - p_ini + 1) as a0, p_ini - 1 as a1),
  prim as (select pessoa_id, min(dia) d0 from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and pessoa_id is not null group by pessoa_id),
  vg as (
    select (v.data_venda at time zone 'America/Sao_Paulo')::date as dia, v.valor_bruto, v.id, v.pessoa_id,
      jsonb_build_object(
        'produto', jsonb_build_object('k', coalesce(v.produto_id::text, 'sem'), 'r', coalesce(pr.nome, 'Sem produto')),
        'campanha', jsonb_build_object('k', coalesce(v.campanha_id::text, 'sem'), 'r', coalesce(ca.nome, 'Sem campanha')),
        'canal', jsonb_build_object('k', coalesce(nullif(v.canal_fechamento, ''), nullif(v.utm_source, ''), 'sem'), 'r', coalesce(nullif(v.canal_fechamento, ''), nullif(v.utm_source, ''), 'Sem canal')),
        'plataforma', jsonb_build_object('k', coalesce(v.plataforma_id::text, 'sem'), 'r', coalesce(pv.nome, 'Sem plataforma'))) as d0,
      jsonb_build_object('id', v.id, 'dia', (v.data_venda at time zone 'America/Sao_Paulo')::date, 'pessoa_id', v.pessoa_id, 'pessoa', pe.nome, 'produto', pr.nome,
        'campanha', ca.nome, 'canal', coalesce(nullif(v.canal_fechamento, ''), nullif(v.utm_source, '')), 'valor', v.valor_bruto, 'origem', 'growths') as reg
    from vendas v left join produtos pr on pr.id = v.produto_id left join campanhas ca on ca.id = v.campanha_id
      left join plataformas_venda pv on pv.id = v.plataforma_id left join pessoas pe on pe.id = v.pessoa_id, per
    where p_metrica in ('faturamento', 'vendas') and v.workspace_id = p_ws and v.status = 'aprovada'
      and (v.data_venda at time zone 'America/Sao_Paulo')::date between per.a0 and p_fim),
  vh as (
    select h.data_venda as dia, h.valor, h.pessoa_id,
      jsonb_build_object(
        'produto', jsonb_build_object('k', 'hist:' || coalesce(nullif(h.produto, ''), '?'), 'r', coalesce(nullif(h.produto, ''), 'Sem produto') || ' (histórico)'),
        'campanha', jsonb_build_object('k', 'hist', 'r', 'Histórico importado'),
        'canal', jsonb_build_object('k', 'hist', 'r', 'Histórico importado'),
        'plataforma', jsonb_build_object('k', 'hist:' || coalesce(nullif(h.plataforma, ''), '?'), 'r', coalesce(nullif(h.plataforma, ''), 'Sem plataforma') || ' (histórico)')) as d0,
      jsonb_build_object('id', h.id, 'dia', h.data_venda, 'pessoa_id', h.pessoa_id, 'pessoa', pe.nome, 'produto', h.produto, 'campanha', null, 'canal', null, 'valor', h.valor, 'origem', 'historico') as reg
    from vendas_historicas h left join pessoas pe on pe.id = h.pessoa_id, per
    where p_metrica in ('faturamento', 'vendas') and h.workspace_id = p_ws and h.status = 'aprovada' and h.data_venda between per.a0 and p_fim)
  select x.dia >= p_ini, x.dia, case when p_metrica = 'faturamento' then x.valor_bruto else 1 end,
    x.d0 || jsonb_build_object('cliente', case when x.pessoa_id is null then jsonb_build_object('k', 'sem', 'r', 'Sem pessoa')
                                               when pm.d0 = x.dia then jsonb_build_object('k', 'novo', 'r', 'Cliente novo (1ª compra)')
                                               else jsonb_build_object('k', 'recorrente', 'r', 'Cliente que já comprou') end),
    x.reg
  from (select dia, valor_bruto, pessoa_id, d0, reg from vg union all select dia, valor, pessoa_id, d0, reg from vh) x left join prim pm on pm.pessoa_id = x.pessoa_id
  union all
  select (p.criado_em at time zone 'America/Sao_Paulo')::date >= p_ini, (p.criado_em at time zone 'America/Sao_Paulo')::date, 1,
    jsonb_build_object(
      'campanha', jsonb_build_object('k', coalesce(p.campanha_id::text, 'sem'), 'r', coalesce(ca.nome, 'Sem campanha de origem')),
      'canal', jsonb_build_object('k', coalesce(nullif(p.canal_origem, ''), nullif(p.utm_source, ''), 'sem'), 'r', coalesce(nullif(p.canal_origem, ''), nullif(p.utm_source, ''), 'Sem canal')),
      'qualificacao', jsonb_build_object('k', coalesce(nullif(p.qualificacao, ''), 'sem'), 'r', coalesce(nullif(p.qualificacao, ''), 'Sem qualificação')),
      'situacao', jsonb_build_object('k', case when p.status_funil = 'cliente' then 'cliente' else 'lead' end, 'r', case when p.status_funil = 'cliente' then 'Já virou cliente' else 'Ainda lead' end)),
    jsonb_build_object('id', p.id, 'dia', (p.criado_em at time zone 'America/Sao_Paulo')::date, 'pessoa_id', p.id, 'pessoa', p.nome, 'campanha', ca.nome,
      'canal', coalesce(nullif(p.canal_origem, ''), nullif(p.utm_source, '')), 'qualificacao', p.qualificacao, 'situacao', p.status_funil)
  from pessoas p left join campanhas ca on ca.id = p.campanha_id, per
  where p_metrica = 'leads' and p.workspace_id = p_ws and coalesce(p.captada, true)
    and (p.criado_em at time zone 'America/Sao_Paulo')::date between per.a0 and p_fim
$$;
revoke all on function public.investigar_linhas(uuid, text, date, date) from public, anon, authenticated;

-- a linha passa nos filtros? (cada filtro compara a chave da dimensão)
create or replace function public.investigar_passa(d jsonb, f jsonb) returns boolean language sql immutable as $$
  select coalesce(bool_and(d #>> array[k, 'k'] = v), true) from jsonb_each_text(coalesce(f, '{}'::jsonb)) as t(k, v)
$$;

create or replace function public.investigar(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_filtros jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare dims text[]; k text; out jsonb := '{}'::jsonb; tot numeric; tot_a numeric; n int; rot jsonb := '{}'::jsonb;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_metrica not in ('faturamento', 'vendas', 'leads') then raise exception 'Métrica inválida'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 400 then raise exception 'Período inválido (até 400 dias)'; end if;
  dims := case when p_metrica = 'leads' then array['campanha', 'canal', 'qualificacao', 'situacao'] else array['produto', 'campanha', 'canal', 'plataforma', 'cliente'] end;
  create temp table if not exists _inv (atual boolean, valor numeric, d jsonb) on commit drop;
  truncate _inv;
  insert into _inv select l.atual, l.valor, l.d from investigar_linhas(p_ws, p_metrica, p_ini, p_fim) l where investigar_passa(l.d, p_filtros);
  select coalesce(sum(valor) filter (where atual), 0), coalesce(sum(valor) filter (where not atual), 0), count(*) filter (where atual) into tot, tot_a, n from _inv;
  foreach k in array dims loop
    out := out || jsonb_build_object(k, coalesce((
      select jsonb_agg(jsonb_build_object('k', kk, 'r', rr, 'v', v, 'v_ant', va) order by v desc, va desc)
        from (select d #>> array[k, 'k'] kk, max(d #>> array[k, 'r']) rr, coalesce(sum(valor) filter (where atual), 0) v, coalesce(sum(valor) filter (where not atual), 0) va
                from _inv group by 1) g), '[]'::jsonb));
  end loop;
  -- nomes dos filtros ativos (para o caminho de volta)
  select coalesce(jsonb_object_agg(f.key, (select max(d #>> array[f.key, 'r']) from _inv where d #>> array[f.key, 'k'] = f.value)), '{}'::jsonb) into rot
    from jsonb_each_text(coalesce(p_filtros, '{}'::jsonb)) f;
  return jsonb_build_object('metrica', p_metrica, 'ini', p_ini, 'fim', p_fim, 'ini_ant', p_ini - (p_fim - p_ini + 1), 'fim_ant', p_ini - 1,
    'filtros', coalesce(p_filtros, '{}'::jsonb), 'filtros_nomes', rot, 'total', tot, 'total_ant', tot_a, 'registros', n, 'dims', out, 'ordem', to_jsonb(dims));
end $$;
revoke all on function public.investigar(uuid, text, date, date, jsonb) from public, anon;
grant execute on function public.investigar(uuid, text, date, date, jsonb) to authenticated;

create or replace function public.investigar_registros(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_filtros jsonb default '{}'::jsonb, p_limite int default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 400 then raise exception 'Período inválido (até 400 dias)'; end if;
  return coalesce((select jsonb_agg(reg order by dia desc, reg->>'pessoa')
                     from (select l.reg, l.dia from investigar_linhas(p_ws, p_metrica, p_ini, p_fim) l
                            where l.atual and investigar_passa(l.d, p_filtros) order by l.dia desc limit least(greatest(coalesce(p_limite, 200), 1), 500)) x), '[]'::jsonb);
end $$;
revoke all on function public.investigar_registros(uuid, text, date, date, jsonb, int) from public, anon;
grant execute on function public.investigar_registros(uuid, text, date, date, jsonb, int) to authenticated;

notify pgrst, 'reload schema';
