-- v0.221 — Growth's Brain: metas das áreas (Financeiro, Customer Success e Growth) no registro central.
--
-- Decisão da Rebecka (01/11): a margem vem da DRE (lançamentos) para quem tem o Financeiro completo e do Financeiro simplificado
-- para quem só tem o Go-to-Market, e a tela mostra de onde veio o número.
--
-- 1. Métricas novas no registro (metas de NÍVEL, que não se somam no tempo):
--      margem      (%)  no mínimo — DRE: lucro ÷ receita; sem DRE no período: Financeiro simplificado (resultado da operação ÷ faturamento)
--      caixa       (R$) no mínimo — saldo em banco hoje
--      churn       (%)  no máximo — saída mensal de alunos (janela de 30 dias, como o Customer Success)
--      retencao90  (%)  no mínimo — retenção em 90 dias (curva do Customer Success)
--      ltv         (R$) no mínimo — LTV médio (Customer Success)
--      ascensao    (%)  no mínimo — taxa de ascensão (Customer Success)
--      nsm         (unidade da North Star) — o valor da North Star do Growth Model; quanto maior/menor, conforme o Growth Model
-- 2. metas_avaliar_nivel: compara o valor do período com a meta (sem "esperado até hoje" nem projeção: não faz sentido somar margem ou churn).
--    Status: dentro / atenção (até a tolerância além do limite) / em risco / sem dados.
-- 3. Absorção sem duplicar (espelho com trava, quem manda é metas): heavyops_metas (churn, retenção, LTV, ascensão),
--    empresa.saldo_minimo (caixa) e growth_metricas.meta da North Star ↔ a meta do ano corrente no registro.
-- 4. metas_painel devolve também "niveis"; o Risk Engine passa a apontar meta de nível fora do limite.
-- Depende do RODAR_v0.220. Pode rodar de novo sem erro.

alter table public.metas drop constraint if exists metas_metrica_check;
alter table public.metas add constraint metas_metrica_check check (metrica in ('faturamento', 'leads', 'vendas', 'margem', 'caixa', 'churn', 'retencao90', 'ltv', 'ascensao', 'nsm'));

create or replace function public.metas_nivel_cfg(p_metrica text) returns jsonb language sql immutable as $$
  select case p_metrica
    when 'margem' then '{"nome":"Margem","area":"financeiro","unidade":"pct","direcao":"minimo"}'
    when 'caixa' then '{"nome":"Saldo de caixa","area":"financeiro","unidade":"brl","direcao":"minimo"}'
    when 'churn' then '{"nome":"Saída mensal de alunos (churn)","area":"cs","unidade":"pct","direcao":"maximo"}'
    when 'retencao90' then '{"nome":"Retenção em 90 dias","area":"cs","unidade":"pct","direcao":"minimo"}'
    when 'ltv' then '{"nome":"LTV médio","area":"cs","unidade":"brl","direcao":"minimo"}'
    when 'ascensao' then '{"nome":"Taxa de ascensão","area":"cs","unidade":"pct","direcao":"minimo"}'
    when 'nsm' then '{"nome":"North Star","area":"growth","unidade":"num","direcao":"maior"}'
  end::jsonb
$$;

-- grava (ou arquiva, com valor nulo) a meta de nível do ano
create or replace function public.metas_grava_nivel(p_ws uuid, p_metrica text, p_ano int, p_valor numeric, p_origem text default 'manual',
  p_direcao text default null, p_unidade text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare mid uuid; c jsonb := metas_nivel_cfg(p_metrica); i date := make_date(p_ano, 1, 1); f date := make_date(p_ano, 12, 31);
begin
  if c is null then raise exception 'Métrica de nível inválida'; end if;
  select id into mid from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and ini = i and fim = f and status = 'aprovada';
  if p_valor is null then
    if mid is not null then update metas set status = 'arquivada' where id = mid; end if;
    return null;
  end if;
  if mid is null then
    insert into metas (workspace_id, metrica, escopo, granularidade, ini, fim, valor, unidade, direcao, origem, trajetoria)
    values (p_ws, p_metrica, 'empresa', 'ano', i, f, p_valor, coalesce(p_unidade, c->>'unidade'), coalesce(p_direcao, c->>'direcao'), p_origem, 'linear')
    returning id into mid;
  else
    update metas set valor = p_valor, direcao = coalesce(p_direcao, direcao), unidade = coalesce(p_unidade, unidade)
     where id = mid and (valor, direcao, unidade) is distinct from (p_valor, coalesce(p_direcao, direcao), coalesce(p_unidade, unidade));
  end if;
  return mid;
end $$;
revoke all on function public.metas_grava_nivel(uuid, text, int, numeric, text, text, text) from public, anon, authenticated;

-- para a tela: grava a meta de nível do ano (com checagem de acesso)
create or replace function public.metas_nivel_salvar(p_ws uuid, p_metrica text, p_ano int, p_valor numeric) returns uuid
language plpgsql security definer set search_path = public as $$
declare d text; u text;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_metrica = 'nsm' then
    select case when direcao = 'desce' then 'menor' else 'maior' end, case unidade when 'brl' then 'brl' when 'pct' then 'pct' else 'num' end into d, u
      from growth_metricas where workspace_id = p_ws and tipo = 'north_star' order by criado_em limit 1;
    if d is null then raise exception 'Defina a North Star no Growth Model antes da meta.'; end if;
  end if;
  return metas_grava_nivel(p_ws, p_metrica, p_ano, p_valor, 'manual', d, u);
end $$;
revoke all on function public.metas_nivel_salvar(uuid, text, int, numeric) from public, anon;
grant execute on function public.metas_nivel_salvar(uuid, text, int, numeric) to authenticated;

-- valor realizado de uma métrica de nível no período (até hoje), com a fonte
create or replace function public.metas_nivel_valor(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ate date := least(p_fim, p_hoje); pg jsonb; ho jsonb; s jsonb; v numeric; fonte text; nota text; dias int; ns record; fat numeric; rop numeric; x jsonb; ult jsonb; c90 jsonb;
begin
  if p_metrica in ('margem', 'caixa') then
    begin pg := painel_gerencial(p_ws, p_ini, ate, p_hoje); exception when others then pg := null; end;
    if p_metrica = 'caixa' then
      v := (pg #>> '{caixa,saldo}')::numeric; fonte := 'Saldo em banco hoje (contas bancárias do Financeiro)';
    elsif coalesce((pg #>> '{resultado,receita}')::numeric, 0) > 0 then
      v := round((pg #>> '{resultado,margem}')::numeric * 100, 2); fonte := 'DRE (lançamentos): lucro ÷ receita';
    else
      begin s := dre_simplificado(p_ws, ate, greatest(1, (extract(year from age(date_trunc('month', ate), date_trunc('month', p_ini))) * 12 + extract(month from age(date_trunc('month', ate), date_trunc('month', p_ini))))::int + 1));
      exception when others then s := null; end;
      fat := 0; rop := 0;
      for x in select * from jsonb_array_elements(coalesce(s->'meses', '[]'::jsonb)) loop
        if (x->>'mes')::date between date_trunc('month', p_ini)::date and ate then
          fat := fat + coalesce((x->>'faturamento')::numeric, 0);
          rop := rop + coalesce((x->>'faturamento')::numeric, 0) - coalesce((x->>'taxa')::numeric, 0) - coalesce((x->>'impostos')::numeric, 0)
                     - coalesce((x->>'comissoes_parceiros')::numeric, 0) - coalesce((x->>'comissoes_equipe')::numeric, 0) - coalesce((x->>'midia')::numeric, 0)
                     - coalesce((x->>'custos_mkt')::numeric, 0) - coalesce((x->>'custos_op')::numeric, 0);
        end if;
      end loop;
      if fat > 0 then v := round(rop / fat * 100, 2); fonte := 'Financeiro simplificado: resultado da operação ÷ faturamento';
        nota := 'Sem lançamentos na DRE no período; usa os custos informados no Financeiro simplificado.'; end if;
    end if;
  elsif p_metrica in ('churn', 'retencao90', 'ltv', 'ascensao') then
    dias := 30;  -- o mesmo padrão da tela de Customer Success (os indicadores de CS são a situação de hoje)
    begin ho := heavyops_painel(p_ws, dias); exception when others then ho := null; end;
    if ho is not null then
      fonte := 'Customer Success (o mesmo cálculo da tela)';
      if p_metrica = 'churn' then
        select e into ult from jsonb_array_elements(coalesce(ho->'serie', '[]'::jsonb)) e order by (e->>'k')::int asc limit 1;
        if ult is null then select e into ult from jsonb_array_elements(coalesce(ho->'serie', '[]'::jsonb)) e limit 1; end if;
        v := case when (ult->>'base')::numeric > 0 then round((ult->>'perdidos')::numeric / (ult->>'base')::numeric * 100, 2) end;
        nota := 'Últimos 30 dias até hoje.';
      elsif p_metrica = 'retencao90' then
        select e into c90 from jsonb_array_elements(coalesce(ho->'curva', '[]'::jsonb)) e where (e->>'dias')::int = 90;
        v := case when (c90->>'elegiveis')::numeric > 0 then round((c90->>'retidos')::numeric / (c90->>'elegiveis')::numeric * 100, 2) end;
      elsif p_metrica = 'ltv' then
        v := case when (ho #>> '{ltv,clientes}')::numeric > 0 then round((ho #>> '{ltv,ltv}')::numeric, 2) end;
      else
        v := case when (ho #>> '{ascensao,elegiveis}')::numeric > 0 then round((ho #>> '{ascensao,subiram}')::numeric / (ho #>> '{ascensao,elegiveis}')::numeric * 100, 2) end;
      end if;
    end if;
  elsif p_metrica = 'nsm' then
    select * into ns from growth_metricas where workspace_id = p_ws and tipo = 'north_star' order by criado_em limit 1;
    if ns.id is not null then
      if ns.fonte = 'auto' and ns.chave_auto is not null then
        begin v := round((growth_metricas_auto(p_ws, p_ini, ate) ->> ns.chave_auto)::numeric, 2); exception when others then v := null; end;
        fonte := 'Growth Model (automática: ' || ns.chave_auto || ')';
      else v := ns.valor_manual; fonte := 'Growth Model (valor preenchido à mão)'; end if;
      nota := ns.nome;
    end if;
  end if;
  return jsonb_build_object('v', v, 'fonte', fonte, 'nota', nota);
end $$;
revoke all on function public.metas_nivel_valor(uuid, text, date, date, date) from public, anon, authenticated;

create or replace function public.metas_avaliar_nivel(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m metas; c jsonb := metas_nivel_cfg(p_metrica); vv jsonb; v numeric; tol numeric; lim numeric; st text; nome text;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if c is null then raise exception 'Métrica de nível inválida'; end if;
  select * into m from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada' and ini <= p_fim and fim >= p_ini
   order by case granularidade when 'mes' then 1 when 'trimestre' then 2 else 3 end, ini desc limit 1;
  vv := metas_nivel_valor(p_ws, p_metrica, p_ini, p_fim, p_hoje); v := (vv->>'v')::numeric;
  tol := case when p_metrica in ('churn', 'retencao90', 'ltv', 'ascensao') then coalesce((select tolerancia from heavyops_metas where workspace_id = p_ws), 15)
              else coalesce((select atencao_pct from metas_regras where workspace_id = p_ws), 10) end / 100;
  nome := case when p_metrica = 'nsm' then 'North Star' || coalesce(' (' || (vv->>'nota') || ')', '') else c->>'nome' end;
  if m.id is null then st := 'sem_meta';
  elsif v is null then st := 'sem_dados';
  elsif m.direcao in ('minimo', 'maior') then
    lim := m.valor - abs(m.valor) * tol;
    st := case when v >= m.valor then 'dentro' when v >= lim then 'atencao' else 'risco' end;
  else
    lim := m.valor + abs(m.valor) * tol;
    st := case when v <= m.valor then 'dentro' when v <= lim then 'atencao' else 'risco' end;
  end if;
  return jsonb_build_object('metrica', p_metrica, 'tipo', 'nivel', 'nome', nome, 'area', c->>'area', 'unidade', coalesce(m.unidade, c->>'unidade'),
    'direcao', coalesce(m.direcao, c->>'direcao'), 'meta', m.valor, 'meta_id', m.id, 'realizado', v, 'status', st, 'fonte', vv->>'fonte', 'nota', vv->>'nota',
    'ini', p_ini, 'fim', p_fim, 'tolerancia_pct', round(tol * 100, 1));
end $$;
revoke all on function public.metas_avaliar_nivel(uuid, text, date, date, date) from public, anon;
grant execute on function public.metas_avaliar_nivel(uuid, text, date, date, date) to authenticated;

-- ---------------------------------------------------------------- espelhos (quem manda é metas)
create or replace function public.metas_de_heavyops() returns trigger
language plpgsql security definer set search_path = public as $$
declare a int := extract(year from (now() at time zone 'America/Sao_Paulo'))::int;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  if tg_op = 'INSERT' or new.churn_max is distinct from old.churn_max then perform metas_grava_nivel(new.workspace_id, 'churn', a, new.churn_max, 'migrada'); end if;
  if tg_op = 'INSERT' or new.retencao_min is distinct from old.retencao_min then perform metas_grava_nivel(new.workspace_id, 'retencao90', a, new.retencao_min, 'migrada'); end if;
  if tg_op = 'INSERT' or new.ltv_min is distinct from old.ltv_min then perform metas_grava_nivel(new.workspace_id, 'ltv', a, new.ltv_min, 'migrada'); end if;
  if tg_op = 'INSERT' or new.ascensao_min is distinct from old.ascensao_min then perform metas_grava_nivel(new.workspace_id, 'ascensao', a, new.ascensao_min, 'migrada'); end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_de_heavyops on public.heavyops_metas;
create trigger metas_de_heavyops after insert or update on public.heavyops_metas for each row execute function public.metas_de_heavyops();

create or replace function public.metas_de_nsm() returns trigger
language plpgsql security definer set search_path = public as $$
declare a int := extract(year from (now() at time zone 'America/Sao_Paulo'))::int;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  if new.tipo <> 'north_star' or (tg_op = 'UPDATE' and new.meta is not distinct from old.meta and new.direcao is not distinct from old.direcao and new.unidade is not distinct from old.unidade) then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  perform metas_grava_nivel(new.workspace_id, 'nsm', a, new.meta, 'migrada', case when new.direcao = 'desce' then 'menor' else 'maior' end,
    case new.unidade when 'brl' then 'brl' when 'pct' then 'pct' else 'num' end);
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_de_nsm on public.growth_metricas;
create trigger metas_de_nsm after insert or update on public.growth_metricas for each row execute function public.metas_de_nsm();

create or replace function public.metas_de_saldo_minimo() returns trigger
language plpgsql security definer set search_path = public as $$
declare a int := extract(year from (now() at time zone 'America/Sao_Paulo'))::int;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  if tg_op = 'UPDATE' and new.saldo_minimo is not distinct from old.saldo_minimo then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  perform metas_grava_nivel(new.workspace_id, 'caixa', a, new.saldo_minimo, 'migrada');
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_de_saldo_minimo on public.empresa;
create trigger metas_de_saldo_minimo after insert or update on public.empresa for each row execute function public.metas_de_saldo_minimo();

-- metas -> origem (só a meta do ano corrente, que é a que essas telas usam)
create or replace function public.metas_para_origens() returns trigger
language plpgsql security definer set search_path = public as $$
declare r metas; v numeric; a int := extract(year from (now() at time zone 'America/Sao_Paulo'))::int;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  if tg_op = 'DELETE' then r := old; else r := new; end if;
  if r.escopo <> 'empresa' or r.granularidade <> 'ano' or r.ini <> make_date(a, 1, 1) or r.metrica not in ('churn', 'retencao90', 'ltv', 'ascensao', 'nsm', 'caixa') then return null; end if;
  v := case when tg_op <> 'DELETE' and r.status = 'aprovada' then r.valor end;
  perform set_config('growths.metas_espelho', '1', true);
  if r.metrica = 'caixa' then update empresa set saldo_minimo = v where workspace_id = r.workspace_id;
  elsif r.metrica = 'nsm' then update growth_metricas set meta = v where workspace_id = r.workspace_id and tipo = 'north_star';
  elsif v is not null then
    insert into heavyops_metas (workspace_id) values (r.workspace_id) on conflict (workspace_id) do nothing;
    execute format('update heavyops_metas set %I = $1 where workspace_id = $2',
      case r.metrica when 'churn' then 'churn_max' when 'retencao90' then 'retencao_min' when 'ltv' then 'ltv_min' else 'ascensao_min' end) using v, r.workspace_id;
  end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_para_origens on public.metas;
create trigger metas_para_origens after insert or update or delete on public.metas for each row execute function public.metas_para_origens();

-- absorção do que já existe (ano corrente)
do $$ declare r record; a int := extract(year from (now() at time zone 'America/Sao_Paulo'))::int; begin
  perform set_config('growths.metas_espelho', '1', true);
  for r in select * from heavyops_metas loop
    perform metas_grava_nivel(r.workspace_id, 'churn', a, r.churn_max, 'migrada'); perform metas_grava_nivel(r.workspace_id, 'retencao90', a, r.retencao_min, 'migrada');
    perform metas_grava_nivel(r.workspace_id, 'ltv', a, r.ltv_min, 'migrada'); perform metas_grava_nivel(r.workspace_id, 'ascensao', a, r.ascensao_min, 'migrada');
  end loop;
  for r in select workspace_id, meta, direcao, unidade from growth_metricas where tipo = 'north_star' and meta is not null loop
    perform metas_grava_nivel(r.workspace_id, 'nsm', a, r.meta, 'migrada', case when r.direcao = 'desce' then 'menor' else 'maior' end, case r.unidade when 'brl' then 'brl' when 'pct' then 'pct' else 'num' end);
  end loop;
  for r in select workspace_id, saldo_minimo from empresa where saldo_minimo is not null loop
    perform metas_grava_nivel(r.workspace_id, 'caixa', a, r.saldo_minimo, 'migrada');
  end loop;
  perform set_config('growths.metas_espelho', '', true);
end $$;

-- ---------------------------------------------------------------- painel: inclui as metas de nível
create or replace function public.metas_niveis(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare k text; out jsonb := '[]'::jsonb;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  for k in select unnest(array['margem', 'caixa', 'churn', 'retencao90', 'ltv', 'ascensao', 'nsm']) loop
    if exists (select 1 from metas where workspace_id = p_ws and metrica = k and escopo = 'empresa' and status = 'aprovada' and ini <= p_fim and fim >= p_ini) then
      out := out || jsonb_build_array(metas_avaliar_nivel(p_ws, k, p_ini, p_fim, p_hoje));
    end if;
  end loop;
  return out;
end $$;
revoke all on function public.metas_niveis(uuid, date, date, date) from public, anon;
grant execute on function public.metas_niveis(uuid, date, date, date) to authenticated;

create or replace function public.metas_painel(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a int := extract(year from p_hoje)::int; c jsonb; met jsonb := '{}'::jsonb; k text;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  c := metas_consistencia(p_ws, 'faturamento', a);
  foreach k in array array['faturamento', 'leads', 'vendas'] loop
    met := met || jsonb_build_object(k, jsonb_build_object(
      'periodo', metas_avaliar(p_ws, k, p_ini, p_fim, p_hoje),
      'ano', metas_avaliar(p_ws, k, make_date(a, 1, 1), make_date(a, 12, 31), p_hoje)));
  end loop;
  return jsonb_build_object(
    'periodo', met #> '{faturamento,periodo}', 'ano', met #> '{faturamento,ano}', 'metricas', met,
    'recortes', metas_recortes(p_ws, p_ini, p_fim, p_hoje),
    'niveis', metas_niveis(p_ws, p_ini, p_fim, p_hoje),
    'consistencia', c || jsonb_build_object('diferenca', case when c->>'meta_ano' is not null and c->>'soma_meses' is not null then (c->>'soma_meses')::numeric - (c->>'meta_ano')::numeric end));
end $$;
revoke all on function public.metas_painel(uuid, date, date, date) from public, anon;
grant execute on function public.metas_painel(uuid, date, date, date) to authenticated;

-- ---------------------------------------------------------------- Risk Engine: meta de nível fora do limite (mês corrente)
do $$
declare d text;
begin
  d := pg_get_functiondef('public.riscos_detectar(uuid, date)'::regprocedure);
  if position('nivel:' in d) = 0 then
    d := replace(d, '  -- 3. alertas em aberto, agrupados por regra', $blk$  -- 2b. metas de nível (margem, caixa, CS, North Star) fora do limite no mês até hoje (v0.221)
  for k in select distinct m.metrica from metas m where m.workspace_id = p_ws and m.status = 'aprovada' and m.escopo = 'empresa'
              and m.metrica in ('margem', 'caixa', 'churn', 'retencao90', 'ltv', 'ascensao', 'nsm') and m.ini <= p_hoje and m.fim >= p_hoje loop
    r := metas_avaliar_nivel(p_ws, k, date_trunc('month', p_hoje)::date, p_hoje, p_hoje);
    if r->>'status' in ('atencao', 'risco') then
      cands := cands || jsonb_build_array(jsonb_build_object('chave', 'nivel:' || k || ':' || to_char(p_hoje, 'YYYY-MM'), 'tipo', 'abaixo_do_esperado',
        'area', r->>'area', 'metrica', k, 'meta_id', r->>'meta_id', 'escopo', 'empresa', 'ini', r->>'ini', 'fim', r->>'fim', 'fonte', 'metas',
        'severidade', case when r->>'status' = 'risco' then 'alta' else 'media' end,
        'titulo', (r->>'nome') || ' fora do limite · ' || riscos_mes_nome(p_hoje),
        'evidencia', 'Agora: ' || riscos_fmt((r->>'realizado')::numeric, case when r->>'unidade' = 'brl' then 'brl' else 'num' end) || case when r->>'unidade' = 'pct' then '%' else '' end ||
                     '; a meta é ' || case when r->>'direcao' in ('maximo', 'menor') then 'no máximo ' else 'no mínimo ' end ||
                     riscos_fmt((r->>'meta')::numeric, case when r->>'unidade' = 'brl' then 'brl' else 'num' end) || case when r->>'unidade' = 'pct' then '%' else '' end ||
                     '. Fonte: ' || coalesce(r->>'fonte', '—') || '.',
        'impacto', null, 'impacto_unidade', null,
        'acao', case r->>'area' when 'financeiro' then 'Abrir o Financeiro e ver o que pesou (custos, preço, impostos).' when 'cs' then 'Abrir o Customer Success e ver quem saiu ou está parado.' else 'Abrir o Growth Model e ver as alavancas da North Star.' end,
        'dados', r));
    end if;
  end loop;
  -- 3. alertas em aberto, agrupados por regra$blk$);
    execute d;
  end if;
end $$;

notify pgrst, 'reload schema';
