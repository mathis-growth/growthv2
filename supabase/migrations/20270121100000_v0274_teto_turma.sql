-- v0.274: teto de CAC filtrado por turma de entrada.
-- cac_teto ganha p_f jsonb: {"entrada_ini": "AAAA-MM-DD", "entrada_fim": "AAAA-MM-DD"}. Com a turma, o LTV (e o mês a mês) é só de quem
-- fez a 1ª compra entre as duas datas, no lugar dos últimos N meses; o ticket da 1ª compra também. O produto é filtrado na tela.
-- A assinatura muda (parâmetro novo): a função antiga sai antes, para não ficar ambígua. Para desfazer: rodar de novo o bloco da v0.273.
drop function if exists public.cac_teto(uuid, date, date, date, int);
create or replace function public.cac_teto(p_ws uuid, p_ini date, p_fim date, p_hoje date default null, p_hist int default 12, p_f jsonb default '{}')
returns jsonb language plpgsql stable set search_path = public set enable_nestloop = off set jit = off as $f$
#variable_conflict use_column
declare
  hoje date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  nhist int := least(greatest(coalesce(p_hist, 12), 0), 24);
  c_meta numeric; c_min int; c_jan int; c_base int;
  pinfo jsonb := '{}'; hmax int; x record; d record; pi jsonb; pk text;
  hh int; per int; meta numeric; plano numeric; plano_r numeric; preco_liq numeric;
  n numeric[]; sp numeric[]; sa numeric[]; sr numeric[]; eh numeric[]; pl numeric[]; cum numeric[];
  w numeric; ep numeric; ea numeric; er numeric; reals numeric; alt numeric; v numeric; df numeric; im numeric;
  l_tot numeric; l_p numeric; l_a numeric; l_r numeric; l_x numeric; tem_real bool; tem_alt bool; falta bool; todo_cred bool; mc int;
  r_obs numeric; r_n int; r_eff numeric; nb int; fonte text;
  res jsonb := '{}'; obj jsonb; taxas jsonb := '{}'; k int; q int; mv int;
  geral jsonb; produtos jsonb; historico jsonb := '[]'; refkey text; g_n numeric; g_l numeric; g_p numeric; g_a numeric; g_r numeric; g_x numeric; g_rows jsonb;
  cacs jsonb; cg jsonb; out_prod jsonb := '[]'; row_j jsonb; ltv numeric; c_tot numeric; c_mid numeric; nov numeric; fixo numeric; tick numeric; tmax numeric; teq numeric;
  mmax numeric; meq numeric; pb int;
  e_ini date := nullif(p_f ->> 'entrada_ini', '')::date; e_fim date := nullif(p_f ->> 'entrada_fim', '')::date; turma bool;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  turma := e_ini is not null or e_fim is not null;
  if turma and e_ini is not null and e_fim is not null and e_fim < e_ini then raise exception 'a data final da turma é antes da inicial'; end if;
  select coalesce(max(meta_ltv_cac), 1.8), coalesce(max(min_clientes), 30), coalesce(max(janela_meses), 12), coalesce(max(base_meses), 24)
    into c_meta, c_min, c_jan, c_base from ltv_config where workspace_id = p_ws;

  -- produtos: período da recorrência, janela, meta e plano
  select coalesce(jsonb_object_agg(p.id::text, jsonb_build_object(
           'nome', p.nome, 'recorrente', p.recorrente, 'periodicidade', p.periodicidade,
           'per', case when p.recorrente then case p.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end end,
           'h', coalesce(nullif(p.extras ->> 'ltv_janela', '')::int, case when p.recorrente and p.periodicidade = 'anual' then 36 when p.recorrente and p.periodicidade = 'semestral' then 24 end, c_jan),
           'meta', nullif(p.extras ->> 'ltv_meta', '')::numeric,
           'plano', nullif(p.extras ->> 'ltv_planejado', '')::numeric,
           'plano_r', nullif(p.extras ->> 'ltv_renovacao_pct', '')::numeric / 100,
           'preco_liq', greatest(0, p.preco * (1 - coalesce(nullif(p.extras ->> 'mc_custo_pct', '')::numeric, 0) / 100) - coalesce(nullif(p.extras ->> 'mc_custo_cliente', '')::numeric, 0)),
           'ativo', p.ativo)), '{}')
    into pinfo from produtos p where p.workspace_id = p_ws;
  pinfo := pinfo || jsonb_build_object('-', jsonb_build_object('nome', 'Sem produto identificado', 'recorrente', false, 'h', c_jan, 'ativo', true));
  select greatest(c_jan, coalesce(max((value ->> 'h')::int), 0)) into hmax from jsonb_each(pinfo);
  hmax := least(greatest(hmax, 1), 60);

  -- taxa por data de referência
  for d in select hoje as r union all select (date_trunc('month', hoje) - make_interval(months => g - 1) - interval '1 day')::date from generate_series(1, nhist) g loop
    taxas := taxas || jsonb_build_object(d.r::text, ltv_taxa(p_ws, d.r));
  end loop;

  -- dados: para cada data de referência e produto de entrada, quantos clientes viveram cada mês e o lucro de cada mês
  for x in
    with refs as (select hoje as r union all select (date_trunc('month', hoje) - make_interval(months => g - 1) - interval '1 day')::date from generate_series(1, nhist) g),
    cl as materialized (select c.pessoa_id, c.primeira, coalesce(c.entrada[1]::text, '-') as pid from revops_clientes(p_ws, '{}') c),
    rc as materialized (select r.pessoa_id, r.ord, r.dia, r.produto_id, r.valor - coalesce(r.custo, 0) as c from revops_receitas(p_ws) r),
    rt as materialized (
      select rc.*, case when rc.ord = 1 then 'p'
                        when coalesce(pr.recorrente, false) and exists (select 1 from rc r2 where r2.pessoa_id = rc.pessoa_id and r2.produto_id = rc.produto_id and r2.ord < rc.ord) then 'r'
                        else 'a' end as tp
        from rc left join produtos pr on pr.id = rc.produto_id),
    base as materialized (
      select refs.r, cl.pessoa_id, cl.primeira, cl.pid,
             (date_part('year', age(refs.r, cl.primeira)) * 12 + date_part('month', age(refs.r, cl.primeira)))::int as mv
        from refs join cl on cl.primeira <= refs.r
         and case when turma then cl.primeira >= coalesce(e_ini, '-infinity'::date) and cl.primeira <= coalesce(e_fim, 'infinity'::date)
                  else cl.primeira > (refs.r - make_interval(months => c_base))::date end),
    hi as (select b.r, b.pid, jsonb_object_agg(b.mv::text, b.q) as hist, sum(b.q)::int as nb
             from (select r, pid, mv, count(*) as q from base group by 1, 2, 3) b group by 1, 2),
    rv0 as (
      select b.r, b.pid, b.pessoa_id, b.mv, rt.tp, rt.c,
             (date_part('year', age(rt.dia, b.primeira)) * 12 + date_part('month', age(rt.dia, b.primeira)))::int as k
        from base b join rt on rt.pessoa_id = b.pessoa_id and rt.dia <= b.r and rt.dia >= b.primeira),
    rv as (select r, pid, jsonb_object_agg(k::text, jsonb_build_array(sp, sa, sr)) as rv
             from (select r, pid, k, coalesce(sum(c) filter (where tp = 'p'), 0) as sp, coalesce(sum(c) filter (where tp = 'a'), 0) as sa,
                          coalesce(sum(c) filter (where tp = 'r'), 0) as sr
                     from rv0 where k < mv and k < hmax group by 1, 2, 3) z group by 1, 2),
    -- renovação: entre quem já viveu dois ciclos, lucro do 2º ciclo ÷ lucro do 1º
    rr as (select z.r, z.pid, count(*)::int as n, sum(z.a) as a, sum(z.b) as b
             from (select v.r, v.pid, v.pessoa_id,
                          coalesce(sum(v.c) filter (where v.k < (pinfo -> v.pid ->> 'per')::int), 0) as a,
                          coalesce(sum(v.c) filter (where v.k >= (pinfo -> v.pid ->> 'per')::int and v.k < 2 * (pinfo -> v.pid ->> 'per')::int), 0) as b
                     from rv0 v
                    where (pinfo -> v.pid ->> 'per') is not null and v.mv >= 2 * (pinfo -> v.pid ->> 'per')::int
                    group by 1, 2, 3) z group by 1, 2),
    ks as (select refs.r, j.key as pid from refs cross join jsonb_each(pinfo) j)
    select ks.r, ks.pid, hi.hist, coalesce(hi.nb, 0) as nb, rv.rv, rr.n as rr_n, rr.a as rr_a, rr.b as rr_b
      from ks left join hi on hi.r = ks.r and hi.pid = ks.pid left join rv on rv.r = ks.r and rv.pid = ks.pid left join rr on rr.r = ks.r and rr.pid = ks.pid
     order by ks.r, ks.pid
  loop
    pi := pinfo -> x.pid; plano := (pi ->> 'plano')::numeric;
    if x.nb = 0 and plano is null then continue; end if;
    if x.nb = 0 and not coalesce((pi ->> 'ativo')::bool, true) then continue; end if;
    hh := least((pi ->> 'h')::int, hmax); per := (pi ->> 'per')::int; plano_r := (pi ->> 'plano_r')::numeric; preco_liq := (pi ->> 'preco_liq')::numeric;
    im := ((taxas -> x.r::text) ->> 'am')::numeric;
    n := array_fill(0::numeric, array[hh]); sp := n; sa := n; sr := n; eh := n; pl := n; cum := n;
    if x.hist is not null then
      for mv, q in select key::int, value::int from jsonb_each_text(x.hist) loop
        for k in 0 .. least(mv, hh) - 1 loop n[k + 1] := n[k + 1] + q; end loop;
      end loop;
    end if;
    if x.rv is not null then
      for k, obj in select key::int, value from jsonb_each(x.rv) loop
        if k < hh then sp[k + 1] := (obj ->> 0)::numeric; sa[k + 1] := (obj ->> 1)::numeric; sr[k + 1] := (obj ->> 2)::numeric; end if;
      end loop;
    end if;
    -- curva planejada: 1ª compra no mês 0 (até o preço líquido), o resto do LTV planejado espalhado nos outros meses
    if plano is not null then
      pl[1] := case when hh = 1 then plano else least(plano, coalesce(nullif(preco_liq, 0), plano)) end;
      for k in 1 .. hh - 1 loop pl[k + 1] := (plano - pl[1]) / (hh - 1); end loop;
    end if;
    -- taxa de renovação por ciclo
    r_n := coalesce(x.rr_n, 0); r_obs := case when coalesce(x.rr_a, 0) > 0 then x.rr_b / x.rr_a end;
    r_eff := case when r_obs is not null and plano_r is not null then least(1, r_n::numeric / c_min) * r_obs + (1 - least(1, r_n::numeric / c_min)) * plano_r
                  else coalesce(r_obs, plano_r) end;
    l_tot := 0; l_p := 0; l_a := 0; l_r := 0; l_x := 0; tem_real := false; tem_alt := false; falta := false; todo_cred := true; mc := 0;
    for k in 0 .. hh - 1 loop
      df := power(1 + im, k);
      w := least(1, n[k + 1] / c_min);
      if n[k + 1] > 0 then ep := sp[k + 1] / n[k + 1]; ea := sa[k + 1] / n[k + 1]; er := sr[k + 1] / n[k + 1]; tem_real := true; else ep := 0; ea := 0; er := 0; end if;
      if n[k + 1] >= c_min then mc := mc + 1; else todo_cred := false; end if;
      reals := ep + ea + er;
      alt := null;
      if per is not null and k >= per and r_eff is not null then alt := eh[k - per + 1] * r_eff;
      elsif plano is not null then alt := pl[k + 1];
      end if;
      if w < 1 and alt is null then
        if n[k + 1] = 0 then falta := true; end if;
        w := case when n[k + 1] > 0 then 1 else 0 end; alt := 0;
      end if;
      alt := coalesce(alt, 0);
      if w < 1 then tem_alt := true; end if;
      v := w * reals + (1 - w) * alt;
      eh[k + 1] := v;
      l_tot := l_tot + v / df; l_p := l_p + w * ep / df; l_a := l_a + w * ea / df; l_r := l_r + w * er / df; l_x := l_x + (1 - w) * alt / df;
      cum[k + 1] := round(l_tot, 2);
    end loop;
    fonte := case when not tem_real then case when plano is not null or r_eff is not null then 'planejado' else 'sem_dados' end
                  when todo_cred then 'real' else 'misto' end;
    obj := jsonb_build_object('produto_id', case when x.pid = '-' then null else x.pid end, 'nome', pi ->> 'nome',
      'recorrente', coalesce((pi ->> 'recorrente')::bool, false), 'periodicidade', pi ->> 'periodicidade', 'janela', hh,
      'meta', coalesce((pi ->> 'meta')::numeric, c_meta), 'meta_propria', (pi ->> 'meta') is not null,
      'plano', plano, 'clientes', x.nb, 'meses_credito', mc, 'fonte', fonte, 'incompleto', falta,
      'renovacao', case when per is not null then jsonb_build_object('taxa', round(r_eff, 4), 'observada', round(r_obs, 4), 'clientes', r_n) end,
      'ltv', case when fonte = 'sem_dados' then null else round(l_tot, 2) end,
      'partes', jsonb_build_object('primeira', round(l_p, 2), 'ascensao', round(l_a, 2), 'renovacao', round(l_r, 2), 'projetado', round(l_x, 2)),
      'acumulado', to_jsonb(cum));
    res := jsonb_set(res, array[x.r::text], coalesce(res -> x.r::text, '{}') || jsonb_build_object(x.pid, obj));
  end loop;

  -- histórico (geral = média dos produtos pesada pelos clientes de cada um)
  for d in select r from (select hoje as r union all select (date_trunc('month', hoje) - make_interval(months => g - 1) - interval '1 day')::date from generate_series(1, nhist) g) z order by r loop
    g_rows := coalesce(res -> d.r::text, '{}');
    select sum((value ->> 'clientes')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0),
           sum((value ->> 'clientes')::numeric * (value ->> 'ltv')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0),
           sum((value ->> 'clientes')::numeric * (value -> 'partes' ->> 'primeira')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0),
           sum((value ->> 'clientes')::numeric * (value -> 'partes' ->> 'ascensao')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0),
           sum((value ->> 'clientes')::numeric * (value -> 'partes' ->> 'renovacao')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0),
           sum((value ->> 'clientes')::numeric * (value -> 'partes' ->> 'projetado')::numeric) filter (where value ->> 'ltv' is not null and (value ->> 'clientes')::int > 0)
      into g_n, g_l, g_p, g_a, g_r, g_x from jsonb_each(g_rows);
    geral := jsonb_build_object('produto_id', null, 'nome', 'Empresa', 'clientes', coalesce(g_n, 0), 'meta', c_meta, 'janela', c_jan,
      'ltv', case when g_n > 0 then round(g_l / g_n, 2) end,
      'fonte', case when g_n is null then 'sem_dados'
                    when exists (select 1 from jsonb_each(g_rows) j where (j.value ->> 'clientes')::int > 0 and j.value ->> 'fonte' <> 'real') then 'misto' else 'real' end,
      'incompleto', exists (select 1 from jsonb_each(g_rows) j where (j.value ->> 'clientes')::int > 0 and (j.value ->> 'incompleto')::bool),
      'partes', case when g_n > 0 then jsonb_build_object('primeira', round(g_p / g_n, 2), 'ascensao', round(g_a / g_n, 2), 'renovacao', round(g_r / g_n, 2), 'projetado', round(g_x / g_n, 2)) end,
      -- acumulado da empresa: média pesada do acumulado de cada produto (produto de janela menor fica parado no último valor)
      'acumulado', case when g_n > 0 then (
        select jsonb_agg(round(z.s, 2) order by z.k) from (
          select gk.k, sum((j.value ->> 'clientes')::numeric * coalesce((j.value -> 'acumulado' ->> least(gk.k, jsonb_array_length(j.value -> 'acumulado') - 1))::numeric, 0)) / g_n as s
            from generate_series(0, c_jan - 1) gk(k) cross join jsonb_each(g_rows) j
           where j.value ->> 'ltv' is not null and (j.value ->> 'clientes')::int > 0 group by gk.k) z) end);
    res := jsonb_set(res, array[d.r::text], g_rows || jsonb_build_object('*', geral));
    historico := historico || jsonb_build_array(jsonb_build_object('ref', d.r, 'mes', to_char(d.r, 'YYYY-MM'), 'atual', d.r = hoje,
      'taxa_aa', (taxas -> d.r::text) ->> 'aa',
      'geral', jsonb_build_object('ltv', geral -> 'ltv', 'clientes', geral -> 'clientes', 'fonte', geral -> 'fonte'),
      'produtos', coalesce((select jsonb_object_agg(j.key, jsonb_build_object('ltv', j.value -> 'ltv', 'clientes', j.value -> 'clientes', 'fonte', j.value -> 'fonte'))
                              from jsonb_each(g_rows) j), '{}')));
  end loop;

  -- CAC atual no período (mesma regra do cockpit) e ticket da 1ª compra (receita bruta), por produto de entrada
  with evt as (
      select v.pessoa_id, (v.data_venda at time zone 'America/Sao_Paulo')::date as d, v.campanha_id, v.produto_id, v.valor_bruto as bruto, 0 as ord
        from vendas v where v.workspace_id = p_ws and v.status = 'aprovada'
      union all
      select c.pessoa_id, (c.ativado_em at time zone 'America/Sao_Paulo')::date, c.campanha_id,
             (select i.produto_id from contrato_itens i where i.contrato_id = c.id order by coalesce(i.valor, 0) * coalesce(i.quantidade, 1) desc limit 1),
             (select sum(coalesce(i.quantidade, 1) * coalesce(i.valor, 0)) from contrato_itens i where i.contrato_id = c.id), 1
        from contratos c where c.workspace_id = p_ws and c.ativado_em is not null),
    prim as (select distinct on (pessoa_id) pessoa_id, d, campanha_id, coalesce(produto_id::text, '-') as pid from evt where pessoa_id is not null and d is not null order by pessoa_id, d, ord),
    pbruto as (select p.pessoa_id, p.d, p.pid, coalesce((select sum(e.bruto) from evt e where e.pessoa_id = p.pessoa_id and e.d = p.d), 0) as bruto from prim p),
    novos as (select * from pbruto where d between p_ini and p_fim),
    cus as (select v.*, coalesce(v.cac_grupo, case when v.conta_codigo like '6.1.%' then 'midia' end) as grupo
              from v_custos_rateados v where v.workspace_id = p_ws and v.status <> 'cancelado' and coalesce(v.competencia, v.vencimento) between p_ini and p_fim),
    cin as (select c.valor, c.grupo, coalesce(ca.produto_id::text, '-') as pid from cus c left join campanhas ca on ca.id = c.campanha_id where c.grupo is not null and c.entra_no_cac),
    nt as (select count(*)::numeric as n from novos),
    np as (select pid, count(*)::numeric as n, sum(bruto) as rec1 from novos group by pid),
    pbase as (select * from pbruto where d <= hoje and case when turma then d >= coalesce(e_ini, '-infinity'::date) and d <= coalesce(e_fim, 'infinity'::date)
                                                            else d > (hoje - make_interval(months => c_base))::date end),
    tk as (select pid, avg(bruto) as tick from pbase group by pid),
    tkg as (select avg(bruto) as tick from pbase),
    dir as (select pid, sum(valor) filter (where grupo = 'midia') as mid, sum(valor) as tot from cin where pid <> '-' and pid in (select pid from np) group by pid),
    sem as (select coalesce(sum(valor) filter (where grupo = 'midia'), 0) as mid, coalesce(sum(valor), 0) as tot from cin where pid = '-' or pid not in (select pid from np)),
    ger as (select coalesce(sum(valor) filter (where grupo = 'midia'), 0) as mid, coalesce(sum(valor), 0) as tot from cin)
  select jsonb_build_object(
      '*', (select jsonb_build_object('novos', nt.n, 'midia', ger.mid, 'total', ger.tot, 'receita1', (select coalesce(sum(bruto), 0) from novos), 'ticket1', tkg.tick)
              from nt, ger, tkg))
    || coalesce((select jsonb_object_agg(np.pid, jsonb_build_object('novos', np.n, 'receita1', np.rec1, 'ticket1', tk.tick,
                   'midia', coalesce(dir.mid, 0) + sem.mid * np.n / nullif(nt.n, 0), 'total', coalesce(dir.tot, 0) + sem.tot * np.n / nullif(nt.n, 0)))
                   from np cross join nt cross join sem left join dir on dir.pid = np.pid left join tk on tk.pid = np.pid), '{}')
    || coalesce((select jsonb_object_agg(tk.pid, jsonb_build_object('novos', 0, 'receita1', 0, 'ticket1', tk.tick, 'midia', 0, 'total', 0))
                   from tk where tk.pid not in (select pid from np)), '{}')
    into cacs;

  -- monta o teto de hoje
  for pk, row_j in select key, value from jsonb_each(coalesce(res -> hoje::text, '{}')) order by case when key = '*' then 0 else 1 end, (value ->> 'clientes')::int desc nulls last loop
    cg := coalesce(cacs -> pk, jsonb_build_object('novos', 0, 'midia', 0, 'total', 0, 'receita1', 0));
    ltv := (row_j ->> 'ltv')::numeric; meta := (row_j ->> 'meta')::numeric;
    nov := (cg ->> 'novos')::numeric; c_mid := (cg ->> 'midia')::numeric; c_tot := (cg ->> 'total')::numeric;
    fixo := case when nov > 0 then (c_tot - c_mid) / nov end;
    tick := coalesce((cg ->> 'ticket1')::numeric, case when pk not in ('*', '-') then nullif((pinfo -> pk ->> 'preco_liq')::numeric, 0) end);
    tmax := case when ltv is not null then ltv / meta end; teq := ltv;
    mmax := case when tmax is not null then tmax - coalesce(fixo, 0) end; meq := case when teq is not null then teq - coalesce(fixo, 0) end;
    pb := null;
    if nov > 0 and c_tot > 0 and jsonb_typeof(row_j -> 'acumulado') = 'array' then
      select min(o - 1)::int into pb from jsonb_array_elements_text(row_j -> 'acumulado') with ordinality a(v, o) where a.v::numeric >= c_tot / nov;
    end if;
    row_j := row_j || jsonb_build_object(
      'cac', jsonb_build_object('novos', nov, 'midia', round(c_mid, 2), 'total', round(c_tot, 2), 'receita1', round((cg ->> 'receita1')::numeric, 2),
                                'cac_midia', case when nov > 0 then round(c_mid / nov, 2) end, 'cac_total', case when nov > 0 then round(c_tot / nov, 2) end,
                                'fixo_cliente', round(fixo, 2), 'roas', case when c_mid > 0 then round((cg ->> 'receita1')::numeric / c_mid, 3) end),
      'teto', jsonb_build_object('ticket1', round(tick, 2),
                                 'cac_total_eq', round(teq, 2), 'cac_total_max', round(tmax, 2),
                                 'cac_midia_eq', round(meq, 2), 'cac_midia_max', round(mmax, 2),
                                 'roas_eq', case when meq > 0 and tick > 0 then round(tick / meq, 3) end,
                                 'roas_min', case when mmax > 0 and tick > 0 then round(tick / mmax, 3) end,
                                 'inviavel', mmax is not null and mmax <= 0),
      'ltv_cac', case when nov > 0 and c_tot > 0 and ltv is not null then round(ltv / (c_tot / nov), 3) end,
      'payback_meses', pb);
    if pk = '*' then geral := row_j; else out_prod := out_prod || jsonb_build_array(row_j); end if;
  end loop;

  return jsonb_build_object('hoje', hoje, 'ini', p_ini, 'fim', p_fim, 'taxa', taxas -> hoje::text,
    'filtro', jsonb_build_object('entrada_ini', e_ini, 'entrada_fim', e_fim),
    'config', jsonb_build_object('meta', c_meta, 'min_clientes', c_min, 'janela', c_jan, 'base_meses', c_base,
                                 'existe', exists (select 1 from ltv_config where workspace_id = p_ws)),
    'geral', geral, 'produtos', out_prod, 'historico', historico);
end $f$;
grant execute on function public.cac_teto(uuid, date, date, date, int, jsonb) to authenticated;
