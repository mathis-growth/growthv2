-- RODAR no SQL Editor do Supabase (cópia de migrations/20261214100000_brain_calibracao.sql). Depende do RODAR_v0.214 (já rodado).
-- O que muda em produção: só cria funções de leitura (projecao_backtest, projecao_faixa, projecao_fotos). Não mexe em dados.
-- v0.220 — Growth's Brain: acerto da projeção (histórico, erro, viés e faixa provável).
--
-- As fotos diárias (metas_fotos) começaram na v0.213: ainda há pouco período encerrado para comparar. Para não esperar meses,
-- projecao_backtest refaz, para cada mês já fechado (até 12), a projeção que o Growths teria mostrado em alguns dias do mês
-- (3, 7, 10, 15, 20 e 25), com o MESMO método do Cockpit (ritmo do período a partir do 7º dia; antes, média dos últimos 28 dias),
-- e compara com o total real do mês. Resumo por dia do mês: quantos meses, erro médio absoluto (%), viés (% médio com sinal:
-- positivo = a projeção costuma passar do real) e o maior erro.
-- projecao_faixa: para um mês em andamento, a faixa provável da projeção de hoje usando o erro histórico do dia mais próximo.
-- É erro observado no passado, não probabilidade; com menos de 3 meses de histórico, não mostra faixa.
-- projecao_fotos: o mesmo resumo com as fotos guardadas de verdade (períodos já encerrados), quando houver.
-- Só leitura. Depende do RODAR_v0.214 (metas_realizado_dia). Pode rodar de novo sem erro.

create or replace function public.projecao_backtest(p_ws uuid, p_metrica text, p_hoje date, p_meses int default 12) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m0 date; mi date; mf date; tot numeric; k int; d date; rl numeric; h28 numeric; pj numeric; pts jsonb := '[]'::jsonb; res jsonb; n int;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if p_metrica not in ('faturamento', 'leads', 'vendas') then raise exception 'Métrica inválida'; end if;
  m0 := date_trunc('month', p_hoje)::date;
  for n in 1 .. least(greatest(coalesce(p_meses, 12), 1), 24) loop
    mi := (m0 - make_interval(months => n))::date; mf := (mi + interval '1 month - 1 day')::date;
    select coalesce(sum(v), 0) into tot from metas_realizado_dia(p_ws, p_metrica, 'empresa', null, mi, mf);
    if tot <= 0 then continue; end if;   -- mês sem movimento não ensina nada sobre o erro
    foreach k in array array[3, 7, 10, 15, 20, 25] loop
      d := mi + k - 1;
      select coalesce(sum(v), 0) into rl from metas_realizado_dia(p_ws, p_metrica, 'empresa', null, mi, d);
      if k >= 7 then pj := rl + rl / k * (mf - d);
      else select coalesce(sum(v), 0) into h28 from metas_realizado_dia(p_ws, p_metrica, 'empresa', null, d - 27, d);
           pj := case when h28 > 0 then rl + h28 / 28 * (mf - d) end; end if;
      if pj is null then continue; end if;
      pts := pts || jsonb_build_array(jsonb_build_object('mes', mi, 'dia', k, 'realizado_no_dia', rl, 'projecao', round(pj, 2), 'final', tot,
        'erro_pct', round((pj - tot) / tot * 100, 1)));
    end loop;
  end loop;
  select jsonb_agg(jsonb_build_object('dia', x.dia, 'meses', x.qt, 'erro_medio_pct', x.em, 'vies_pct', x.vi, 'maior_erro_pct', x.mx) order by x.dia) into res
    from (select (p->>'dia')::int dia, count(*) qt, round(avg(abs((p->>'erro_pct')::numeric)), 1) em, round(avg((p->>'erro_pct')::numeric), 1) vi,
                 round(max(abs((p->>'erro_pct')::numeric)), 1) mx
            from jsonb_array_elements(pts) p group by 1) x;
  return jsonb_build_object('metrica', p_metrica, 'metodo', 'Mesmo método do Cockpit: ritmo do período a partir do 7º dia; antes, média dos últimos 28 dias.',
    'pontos', pts, 'resumo', coalesce(res, '[]'::jsonb), 'meses_com_dado', (select count(distinct p->>'mes') from jsonb_array_elements(pts) p));
end $$;
revoke all on function public.projecao_backtest(uuid, text, date, int) from public, anon;
grant execute on function public.projecao_backtest(uuid, text, date, int) to authenticated;

create or replace function public.projecao_faixa(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare av jsonb; bt jsonb; dec int; r jsonb; pj numeric; e numeric; v numeric;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  -- só para um mês do calendário em andamento
  if p_ini <> date_trunc('month', p_ini)::date or p_fim <> (p_ini + interval '1 month - 1 day')::date or p_hoje < p_ini or p_hoje >= p_fim then
    return jsonb_build_object('motivo', 'A faixa só aparece num mês do calendário em andamento.');
  end if;
  perform set_config('growths.metas_interno', '1', true);
  av := metas_avaliar(p_ws, p_metrica, p_ini, p_fim, p_hoje);
  pj := (av->>'projecao')::numeric; dec := p_hoje - p_ini + 1;
  if pj is null then return jsonb_build_object('motivo', 'Sem projeção hoje.'); end if;
  bt := projecao_backtest(p_ws, p_metrica, p_hoje, 12);
  select x into r from jsonb_array_elements(bt->'resumo') x where (x->>'dia')::int <= dec order by (x->>'dia')::int desc limit 1;
  if r is null or (r->>'meses')::int < 3 then
    return jsonb_build_object('motivo', 'Menos de 3 meses fechados com movimento: ainda não dá para medir o erro.', 'meses', coalesce((r->>'meses')::int, 0));
  end if;
  e := (r->>'erro_medio_pct')::numeric / 100; v := (r->>'vies_pct')::numeric;
  return jsonb_build_object('projecao', pj, 'de', round(greatest(pj * (1 - e), (av->>'realizado')::numeric), 2), 'ate', round(pj * (1 + e), 2),
    'erro_medio_pct', r->'erro_medio_pct', 'vies_pct', v, 'dia_ref', r->'dia', 'meses', r->'meses',
    'texto', 'Nos últimos ' || (r->>'meses') || ' meses fechados, no dia ' || (r->>'dia') || ' do mês, a projeção errou em média ' ||
             replace((r->>'erro_medio_pct'), '.', ',') || '%' ||
             case when abs(v) >= 5 then ' e costumou ficar ' || case when v > 0 then 'acima' else 'abaixo' end || ' do total real do mês (em média ' || replace(abs(v)::text, '.', ',') || '%)'
                  else ', ora para mais, ora para menos' end || '.');
end $$;
revoke all on function public.projecao_faixa(uuid, text, date, date, date) from public, anon;
grant execute on function public.projecao_faixa(uuid, text, date, date, date) to authenticated;

-- as fotos guardadas de verdade, de períodos já encerrados (o acerto real das projeções mostradas no Cockpit)
create or replace function public.projecao_fotos(p_ws uuid, p_metrica text, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare out jsonb;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  with f as (select ft.ini, ft.fim, ft.dia, ft.projecao, (ft.dia - ft.ini + 1) dias,
                    (select coalesce(sum(v), 0) from metas_realizado_dia(p_ws, p_metrica, ft.escopo, ft.ref, ft.ini, ft.fim)) final
               from metas_fotos ft where ft.workspace_id = p_ws and ft.metrica = p_metrica and ft.escopo = 'empresa' and ft.fim < p_hoje
                and ft.projecao is not null and ft.fim - ft.ini < 40),
       e as (select *, case when final > 0 then (projecao - final) / final * 100 end err from f)
  select jsonb_build_object('fotos', count(*), 'periodos', count(distinct (ini, fim)), 'erro_medio_pct', round(avg(abs(err)), 1), 'vies_pct', round(avg(err), 1))
    into out from e where err is not null;
  return out;
end $$;
revoke all on function public.projecao_fotos(uuid, text, date) from public, anon;
grant execute on function public.projecao_fotos(uuid, text, date) to authenticated;

notify pgrst, 'reload schema';
