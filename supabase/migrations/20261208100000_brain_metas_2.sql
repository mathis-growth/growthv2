-- v0.214 — Growth's Brain, incremento 2: leads e vendas no registro central de metas, e metas por produto e por campanha.
--
-- 1. metas aceita as métricas leads e vendas (além de faturamento).
-- 2. Planejamento mensal: as metas de leads e de vendas do mês (planejamento_mensal.meta_leads / meta_vendas) entram no registro,
--    com o mesmo espelho do faturamento (os dois lados se atualizam; quem manda é metas). Orçamento continua só no planejamento.
-- 3. Campanhas: as metas da campanha (campanhas.meta_leads, meta_vendas, meta_receita) entram no registro como metas de escopo
--    "campanha", na janela certa — não linear no ano todo:
--      leads → janela da captação (fases.aquisicao); sem ela, início e fim da campanha;
--      vendas e faturamento → janela do carrinho (data_carrinho_abre/fecha); sem ela, início e fim da campanha.
--    A campanha continua sendo o lugar de editar (espelho de mão única). Campanha perpétua com meta por mês (meta_leads_mes) fica de fora
--    por enquanto; as metas por fase e canal (campanha_metas) também (próximo incremento).
-- 4. Produtos: metas de faturamento e de vendas por produto, criadas no Planejamento anual (não havia meta por produto antes).
-- 5. Avaliação refeita em séries por dia (meta do dia e realizado do dia) para qualquer escopo. Período só em parte coberto por meta:
--    o realizado conta só nos dias com meta (senão a comparação seria injusta) e a resposta avisa "cobertura parcial".
-- 6. metas_painel devolve faturamento, leads e vendas (período e ano) e as metas de produto e campanha do período.
-- 7. Foto diária também para leads, vendas, produtos e campanhas.
--
-- Definições do realizado (as mesmas das telas):
--   faturamento: valor bruto das vendas aprovadas (Growths + histórico importado), pela data da venda. Produto/campanha: só vendas do Growths
--                (o histórico importado não tem produto nem campanha ligados).
--   vendas: quantidade de vendas aprovadas, mesma regra.
--   leads: empresa = pessoas captadas no dia (como o Dashboard de vendas); campanha = pessoas que entraram na campanha (campanha_participacoes,
--          como o Dashboard da campanha).
-- Depende do RODAR_v0.213. Pode rodar de novo sem erro.

-- ---------------------------------------------------------------- 1. métricas
alter table public.metas drop constraint if exists metas_metrica_check;
alter table public.metas add constraint metas_metrica_check check (metrica in ('faturamento', 'leads', 'vendas'));

-- grava (ou arquiva, com valor nulo) uma meta aprovada. Empresa: acha pelo período. Campanha: acha pela campanha (as datas podem mudar).
create or replace function public.metas_grava(p_ws uuid, p_metrica text, p_escopo text, p_ref uuid, p_gran text, p_ini date, p_fim date,
  p_valor numeric, p_origem text, p_plano uuid default null, p_premissa text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if p_escopo = 'campanha' then
    select id into mid from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'campanha' and campanha_id = p_ref and status = 'aprovada';
  else
    select id into mid from metas where workspace_id = p_ws and metrica = p_metrica and escopo = p_escopo
      and coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(case when p_escopo = 'produto' then p_ref end, '00000000-0000-0000-0000-000000000000'::uuid)
      and ini = p_ini and fim = p_fim and status = 'aprovada';
  end if;
  if p_valor is null or p_ini is null or p_fim is null or p_fim < p_ini then
    if mid is not null then update metas set status = 'arquivada' where id = mid; end if;
    return null;
  end if;
  if mid is null then
    insert into metas (workspace_id, metrica, escopo, produto_id, campanha_id, granularidade, ini, fim, valor, unidade, origem, plano_anual_id, trajetoria, premissa)
    values (p_ws, p_metrica, p_escopo, case when p_escopo = 'produto' then p_ref end, case when p_escopo = 'campanha' then p_ref end, p_gran, p_ini, p_fim, p_valor,
            case when p_metrica = 'faturamento' then 'brl' else 'num' end, p_origem, p_plano, case when p_gran = 'ano' then 'sazonal' else 'linear' end, p_premissa)
    returning id into mid;
  else
    update metas set valor = p_valor, ini = p_ini, fim = p_fim, plano_anual_id = coalesce(p_plano, plano_anual_id), premissa = coalesce(p_premissa, premissa)
     where id = mid and (valor, ini, fim, premissa) is distinct from (p_valor, p_ini, p_fim, coalesce(p_premissa, premissa));
  end if;
  return mid;
end $$;
revoke all on function public.metas_grava(uuid, text, text, uuid, text, date, date, numeric, text, uuid, text) from public, anon, authenticated;

-- compatibilidade com a v0.213
create or replace function public.metas_grava_faturamento(p_ws uuid, p_gran text, p_ini date, p_fim date, p_valor numeric, p_origem text, p_plano uuid default null)
returns uuid language sql security definer set search_path = public as $$
  select metas_grava(p_ws, 'faturamento', 'empresa', null, p_gran, p_ini, p_fim, p_valor, p_origem, p_plano)
$$;
revoke all on function public.metas_grava_faturamento(uuid, text, date, date, numeric, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- 2. planejamento mensal: faturamento, leads e vendas
create or replace function public.metas_de_planejamento_mensal() returns trigger
language plpgsql security definer set search_path = public as $$
declare i date; f date;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  if tg_op = 'DELETE' then
    i := make_date(old.ano, old.mes, 1); f := (i + interval '1 month - 1 day')::date;
    perform metas_grava(old.workspace_id, 'faturamento', 'empresa', null, 'mes', i, f, null, 'plano_anual');
    perform metas_grava(old.workspace_id, 'leads', 'empresa', null, 'mes', i, f, null, 'plano_anual');
    perform metas_grava(old.workspace_id, 'vendas', 'empresa', null, 'mes', i, f, null, 'plano_anual');
  else
    i := make_date(new.ano, new.mes, 1); f := (i + interval '1 month - 1 day')::date;
    if tg_op = 'INSERT' or new.meta_receita is distinct from old.meta_receita then
      perform metas_grava(new.workspace_id, 'faturamento', 'empresa', null, 'mes', i, f, nullif(new.meta_receita, 0), 'plano_anual'); end if;
    if tg_op = 'INSERT' or new.meta_leads is distinct from old.meta_leads then
      perform metas_grava(new.workspace_id, 'leads', 'empresa', null, 'mes', i, f, nullif(new.meta_leads, 0), 'plano_anual'); end if;
    if tg_op = 'INSERT' or new.meta_vendas is distinct from old.meta_vendas then
      perform metas_grava(new.workspace_id, 'vendas', 'empresa', null, 'mes', i, f, nullif(new.meta_vendas, 0), 'plano_anual'); end if;
  end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;

create or replace function public.metas_para_planejamento_mensal() returns trigger
language plpgsql security definer set search_path = public as $$
declare r metas; v numeric; col text;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  if tg_op = 'DELETE' then r := old; else r := new; end if;
  if r.escopo <> 'empresa' or r.granularidade <> 'mes' then return null; end if;
  col := case r.metrica when 'faturamento' then 'meta_receita' when 'leads' then 'meta_leads' when 'vendas' then 'meta_vendas' end;
  if col is null then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  v := case when tg_op <> 'DELETE' and r.status = 'aprovada' then r.valor end;
  if v is not null then
    execute format('insert into planejamento_mensal (workspace_id, ano, mes, %1$I) values ($1, $2, $3, $4) on conflict (workspace_id, ano, mes) do update set %1$I = excluded.%1$I', col)
      using r.workspace_id, extract(year from r.ini)::int, extract(month from r.ini)::int, case when col = 'meta_receita' then v else round(v) end;
  elsif not exists (select 1 from metas where workspace_id = r.workspace_id and metrica = r.metrica and escopo = 'empresa' and granularidade = 'mes' and ini = r.ini and status = 'aprovada') then
    execute format('update planejamento_mensal set %I = null where workspace_id = $1 and ano = $2 and mes = $3', col)
      using r.workspace_id, extract(year from r.ini)::int, extract(month from r.ini)::int;
  end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;

-- ---------------------------------------------------------------- 3. campanhas
create or replace function public.metas_de_campanha_grava(c campanhas) returns void
language plpgsql security definer set search_path = public as $$
declare li date; lf date; vi date; vf date; jl text; jv text;
begin
  li := nullif(c.fases #>> '{aquisicao,ini}', '')::date; lf := nullif(c.fases #>> '{aquisicao,fim}', '')::date; jl := 'da captação';
  if li is null or lf is null or lf < li then li := c.data_inicio; lf := c.data_fim; jl := 'da campanha (do início ao fim)'; end if;
  vi := c.data_carrinho_abre; vf := c.data_carrinho_fecha; jv := 'do carrinho aberto';
  if vi is null or vf is null or vf < vi then vi := c.data_inicio; vf := c.data_fim; jv := 'da campanha (do início ao fim)'; end if;
  perform metas_grava(c.workspace_id, 'leads', 'campanha', c.id, 'personalizado', li, lf,
    case when coalesce(c.meta_leads_mes, 0) > 0 then null else nullif(c.meta_leads, 0) end, 'manual', null, 'Meta da campanha dividida por igual nos dias ' || jl || '.');
  perform metas_grava(c.workspace_id, 'vendas', 'campanha', c.id, 'personalizado', vi, vf, nullif(c.meta_vendas, 0), 'manual', null, 'Meta da campanha dividida por igual nos dias ' || jv || '.');
  perform metas_grava(c.workspace_id, 'faturamento', 'campanha', c.id, 'personalizado', vi, vf, nullif(c.meta_receita, 0), 'manual', null, 'Meta da campanha dividida por igual nos dias ' || jv || '.');
end $$;
revoke all on function public.metas_de_campanha_grava(campanhas) from public, anon, authenticated;

create or replace function public.metas_de_campanha() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or (old.meta_leads, old.meta_vendas, old.meta_receita, old.meta_leads_mes, old.data_inicio, old.data_fim, old.fases, old.data_carrinho_abre, old.data_carrinho_fecha)
     is distinct from (new.meta_leads, new.meta_vendas, new.meta_receita, new.meta_leads_mes, new.data_inicio, new.data_fim, new.fases, new.data_carrinho_abre, new.data_carrinho_fecha) then
    perform metas_de_campanha_grava(new);
  end if;
  return null;
end $$;
drop trigger if exists metas_de_campanha on public.campanhas;
create trigger metas_de_campanha after insert or update on public.campanhas for each row execute function public.metas_de_campanha();

-- absorção do que já existe
do $$ declare r record; c campanhas; begin
  perform set_config('growths.metas_espelho', '1', true);
  for r in select workspace_id, ano, mes, meta_leads, meta_vendas from planejamento_mensal where coalesce(meta_leads, 0) > 0 or coalesce(meta_vendas, 0) > 0 loop
    if coalesce(r.meta_leads, 0) > 0 then perform metas_grava(r.workspace_id, 'leads', 'empresa', null, 'mes', make_date(r.ano, r.mes, 1), (make_date(r.ano, r.mes, 1) + interval '1 month - 1 day')::date, r.meta_leads, 'migrada'); end if;
    if coalesce(r.meta_vendas, 0) > 0 then perform metas_grava(r.workspace_id, 'vendas', 'empresa', null, 'mes', make_date(r.ano, r.mes, 1), (make_date(r.ano, r.mes, 1) + interval '1 month - 1 day')::date, r.meta_vendas, 'migrada'); end if;
  end loop;
  for c in select * from campanhas where coalesce(meta_leads, 0) > 0 or coalesce(meta_vendas, 0) > 0 or coalesce(meta_receita, 0) > 0 loop
    perform metas_de_campanha_grava(c);
  end loop;
  perform set_config('growths.metas_espelho', '', true);
end $$;

-- ---------------------------------------------------------------- 5. séries por dia
-- meta de cada dia. Empresa: meta do mês ÷ dias do mês; sem meta do mês, a sobra da meta do ano ÷ dias livres.
-- Produto e campanha: cada meta aprovada dividida pelos dias da sua janela.
create or replace function public.metas_serie(p_ws uuid, p_metrica text, p_escopo text, p_ref uuid, p_ini date, p_fim date)
returns table (dia date, meta numeric) language sql stable security definer set search_path = public as $$
  with d as (select g::date as dia from generate_series(p_ini, p_fim, interval '1 day') g),
  mm as (select ini, fim, valor from metas where p_escopo = 'empresa' and workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada'
           and granularidade = 'mes' and fim >= make_date(extract(year from p_ini)::int, 1, 1) and ini <= make_date(extract(year from p_fim)::int, 12, 31)),
  ma as (select a.ini, a.fim,
           greatest(a.valor - coalesce((select sum(valor) from mm where mm.ini between a.ini and a.fim), 0), 0) as sobra,
           (a.fim - a.ini + 1) - coalesce((select sum(mm.fim - mm.ini + 1) from mm where mm.ini between a.ini and a.fim), 0) as livres
         from metas a where p_escopo = 'empresa' and a.workspace_id = p_ws and a.metrica = p_metrica and a.escopo = 'empresa' and a.status = 'aprovada'
           and a.granularidade = 'ano' and a.fim >= p_ini and a.ini <= p_fim),
  mr as (select ini, fim, valor from metas where p_escopo <> 'empresa' and workspace_id = p_ws and metrica = p_metrica and escopo = p_escopo and status = 'aprovada'
           and (produto_id = p_ref or campanha_id = p_ref) and fim >= p_ini and ini <= p_fim)
  select d.dia,
    case when p_escopo = 'empresa' then coalesce(
           (select mm.valor / (mm.fim - mm.ini + 1) from mm where d.dia between mm.ini and mm.fim limit 1),
           (select case when ma.livres > 0 then ma.sobra / ma.livres else 0 end from ma where d.dia between ma.ini and ma.fim limit 1))
         else (select sum(mr.valor / (mr.fim - mr.ini + 1)) from mr where d.dia between mr.ini and mr.fim) end
  from d
$$;
revoke all on function public.metas_serie(uuid, text, text, uuid, date, date) from public, anon, authenticated;

-- realizado de cada dia (só os dias com movimento; os outros são zero)
create or replace function public.metas_realizado_dia(p_ws uuid, p_metrica text, p_escopo text, p_ref uuid, p_ini date, p_fim date)
returns table (dia date, v numeric) language sql stable security definer set search_path = public as $$
  -- empresa: vendas + histórico importado
  select x.dia, case when p_metrica = 'faturamento' then sum(x.valor) else count(*) end
    from v_vendas_todas x where p_escopo = 'empresa' and p_metrica in ('faturamento', 'vendas') and x.workspace_id = p_ws and x.status = 'aprovada' and x.dia between p_ini and p_fim group by x.dia
  union all
  select (p.criado_em at time zone 'America/Sao_Paulo')::date, count(*)
    from pessoas p where p_escopo = 'empresa' and p_metrica = 'leads' and p.workspace_id = p_ws and coalesce(p.captada, true)
     and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1
  union all
  -- produto e campanha: só vendas do Growths (o histórico importado não tem produto nem campanha ligados)
  select (vv.data_venda at time zone 'America/Sao_Paulo')::date, case when p_metrica = 'faturamento' then sum(vv.valor_bruto) else count(*) end
    from vendas vv where p_escopo in ('produto', 'campanha') and p_metrica in ('faturamento', 'vendas') and vv.workspace_id = p_ws and vv.status = 'aprovada'
     and ((p_escopo = 'produto' and vv.produto_id = p_ref) or (p_escopo = 'campanha' and vv.campanha_id = p_ref))
     and (vv.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1
  union all
  select (cp.entrou_em at time zone 'America/Sao_Paulo')::date, count(*)
    from campanha_participacoes cp where p_escopo = 'campanha' and p_metrica = 'leads' and cp.workspace_id = p_ws and cp.campanha_id = p_ref
     and (cp.entrou_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by 1
$$;
revoke all on function public.metas_realizado_dia(uuid, text, text, uuid, date, date) from public, anon, authenticated;

-- compatibilidade: realizado de um período (empresa)
create or replace function public.metas_realizado(p_ws uuid, p_metrica text, p_ini date, p_fim date) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce(sum(v), 0) from metas_realizado_dia(p_ws, p_metrica, 'empresa', null, p_ini, p_fim)
$$;
revoke all on function public.metas_realizado(uuid, text, date, date) from public, anon, authenticated;

drop function if exists public.metas_avaliar_interno(uuid, text, date, date, date);
drop function if exists public.metas_painel(uuid, date, date, date);
drop function if exists public.metas_avaliar(uuid, text, date, date, date);

create or replace function public.metas_avaliar(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date, p_escopo text default 'empresa', p_ref uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  rg metas_regras; meta numeric; esp numeric; vreal numeric; ate date; dec int; rest int; d_com int; d_sem int; parcial boolean;
  ritmo numeric; proj numeric; metodo text; nota text; st text; razao numeric; nbase int; h28 numeric; un text; v_all numeric; v_cov numeric;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  if p_escopo not in ('empresa', 'produto', 'campanha') or (p_escopo <> 'empresa' and p_ref is null) then raise exception 'Escopo inválido'; end if;
  select * into rg from metas_regras where workspace_id = p_ws;
  if rg.workspace_id is null then rg.atencao_pct := 10; rg.risco_pct := 25; rg.min_dias := 3; end if;
  un := case when p_metrica = 'faturamento' then 'brl' else 'num' end;
  ate := least(p_fim, p_hoje);
  with sr as (select x.dia, x.meta from metas_serie(p_ws, p_metrica, p_escopo, p_ref, p_ini, p_fim) x),
       rr as (select y.dia, sum(y.v) v from metas_realizado_dia(p_ws, p_metrica, p_escopo, p_ref, p_ini, ate) y group by y.dia),
       j as (select sr.dia, sr.meta, coalesce(rr.v, 0) v from sr left join rr on rr.dia = sr.dia)
  select count(*) filter (where j.meta is not null), count(*) filter (where j.meta is null), sum(j.meta),
         coalesce(sum(j.meta) filter (where j.dia <= ate), 0), coalesce(sum(j.v) filter (where j.dia <= ate), 0),
         coalesce(sum(j.v) filter (where j.dia <= ate and j.meta is not null), 0)
    into d_com, d_sem, meta, esp, v_all, v_cov from j;
  parcial := d_com > 0 and d_sem > 0;
  meta := case when d_com > 0 then round(meta, 2) end; esp := round(esp, 2);
  -- com cobertura parcial, o realizado só conta nos dias que têm meta (comparação justa)
  vreal := case when parcial then v_cov else v_all end;
  dec := greatest(ate - p_ini + 1, 0);
  rest := greatest(p_fim - greatest(ate, p_ini - 1), 0);
  select count(*) into nbase from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between p_hoje - 89 and p_hoje;
  if p_hoje >= p_fim then proj := vreal; metodo := 'periodo_encerrado';
  elsif dec >= 7 then ritmo := vreal / dec; proj := vreal + ritmo * rest; metodo := 'ritmo_do_periodo';
  else
    select coalesce(sum(r.v), 0) into h28 from metas_realizado_dia(p_ws, p_metrica, p_escopo, p_ref, p_hoje - 27, p_hoje) r;
    if h28 > 0 then ritmo := h28 / 28; proj := vreal + ritmo * rest; metodo := 'media_28_dias';
    else proj := null; metodo := 'sem_dados'; end if;
  end if;
  if un = 'num' and proj is not null then proj := round(proj); end if;
  nota := case when metodo = 'periodo_encerrado' then 'Período encerrado: a projeção é o realizado.'
               when metodo = 'ritmo_do_periodo' then 'Média por dia do período até hoje, repetida nos dias que faltam. Não considera sazonalidade dentro do período nem campanhas futuras.'
               when metodo = 'media_28_dias' then 'Menos de 7 dias de período: usa a média por dia dos últimos 28 dias, repetida nos dias que faltam.'
               else 'Sem movimento no período nem nos últimos 28 dias: não há base para projetar.' end
          || case when p_metrica <> 'leads' and nbase < 10 then ' Pouco histórico (menos de 10 vendas em 90 dias): projeção frágil.' else '' end
          || case when parcial then ' Cobertura parcial: ' || d_sem || ' dia(s) do período sem meta ficaram fora da comparação.' else '' end;
  if meta is null then st := 'sem_meta';
  elsif p_hoje < p_ini then st := 'nao_comecou';
  elsif vreal >= meta then st := 'atingida';
  elsif p_hoje >= p_fim then st := 'nao_atingida';
  elsif dec < rg.min_dias then st := 'sem_dados';
  elsif esp <= 0 then st := 'dentro';
  else
    razao := vreal / esp;
    st := case when razao >= 1 - rg.atencao_pct / 100 then 'dentro' when razao >= 1 - rg.risco_pct / 100 then 'atencao' else 'risco' end;
  end if;
  return jsonb_build_object('metrica', p_metrica, 'unidade', un, 'escopo', p_escopo, 'ref', p_ref, 'ini', p_ini, 'fim', p_fim, 'hoje', p_hoje, 'ate', ate,
    'meta', meta, 'esperado', esp, 'realizado', vreal, 'desvio', round(vreal - esp, 2), 'desvio_pct', case when esp > 0 then (vreal - esp) / esp end,
    'pct_realizado', case when meta > 0 then vreal / meta end, 'projecao', proj, 'pct_projetado', case when meta > 0 and proj is not null then proj / meta end,
    'falta', case when meta is not null then greatest(meta - vreal, 0) end, 'dias_passados', dec, 'dias_restantes', rest,
    'ritmo_dia', ritmo, 'ritmo_necessario_dia', case when meta is not null and rest > 0 then greatest(meta - vreal, 0) / rest end,
    'metodo', metodo, 'nota', nota, 'vendas_90d', nbase, 'status', st, 'parcial', parcial,
    'regra', jsonb_build_object('atencao_pct', rg.atencao_pct, 'risco_pct', rg.risco_pct, 'min_dias', rg.min_dias),
    'cobertura', jsonb_build_object('dias', d_com + d_sem, 'dias_com_meta', d_com, 'dias_sem_meta', d_sem));
end $$;
revoke all on function public.metas_avaliar(uuid, text, date, date, date, text, uuid) from public, anon;
grant execute on function public.metas_avaliar(uuid, text, date, date, date, text, uuid) to authenticated;

create or replace function public.metas_avaliar_interno(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date, p_escopo text default 'empresa', p_ref uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  perform set_config('growths.metas_interno', '1', true);
  return metas_avaliar(p_ws, p_metrica, p_ini, p_fim, p_hoje, p_escopo, p_ref);
end $$;
revoke all on function public.metas_avaliar_interno(uuid, text, date, date, date, text, uuid) from public, anon, authenticated;

-- metas de produto e de campanha que tocam o período, cada uma avaliada na sua própria janela
create or replace function public.metas_recortes(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r record; out jsonb := '[]'::jsonb;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  for r in select m.id, m.metrica, m.escopo, coalesce(m.produto_id, m.campanha_id) as ref, m.ini, m.fim, m.premissa, m.origem, m.versao,
                  coalesce(pr.nome, ca.nome) as nome
             from metas m left join produtos pr on pr.id = m.produto_id left join campanhas ca on ca.id = m.campanha_id
            where m.workspace_id = p_ws and m.status = 'aprovada' and m.escopo in ('produto', 'campanha') and m.fim >= p_ini and m.ini <= p_fim
            order by m.escopo, coalesce(pr.nome, ca.nome), case m.metrica when 'leads' then 1 when 'vendas' then 2 else 3 end loop
    out := out || jsonb_build_array(metas_avaliar(p_ws, r.metrica, r.ini, r.fim, p_hoje, r.escopo, r.ref)
                   || jsonb_build_object('meta_id', r.id, 'nome', r.nome, 'premissa', r.premissa, 'origem', r.origem, 'versao', r.versao));
  end loop;
  return out;
end $$;
revoke all on function public.metas_recortes(uuid, date, date, date) from public, anon;
grant execute on function public.metas_recortes(uuid, date, date, date) to authenticated;

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
    'consistencia', c || jsonb_build_object('diferenca', case when c->>'meta_ano' is not null and c->>'soma_meses' is not null then (c->>'soma_meses')::numeric - (c->>'meta_ano')::numeric end));
end $$;
revoke all on function public.metas_painel(uuid, date, date, date) from public, anon;
grant execute on function public.metas_painel(uuid, date, date, date) to authenticated;


-- ---------------------------------------------------------------- 7. foto diária com escopo
alter table public.metas_fotos add column if not exists escopo text not null default 'empresa';
alter table public.metas_fotos add column if not exists ref uuid;
alter table public.metas_fotos drop constraint if exists metas_fotos_pkey;
create unique index if not exists metas_fotos_chave on public.metas_fotos (workspace_id, metrica, escopo, coalesce(ref, '00000000-0000-0000-0000-000000000000'::uuid), ini, fim, dia);

create or replace function public.metas_fotografar(p_hoje date default ((now() at time zone 'America/Sao_Paulo')::date)) returns int
language plpgsql security definer set search_path = public as $$
declare w uuid; n int := 0; per record; r jsonb; k text; mr record;
begin
  for w in select distinct workspace_id from metas where status = 'aprovada' loop
    for per in select * from (values (date_trunc('month', p_hoje)::date, (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date),
                                     (make_date(extract(year from p_hoje)::int, 1, 1), make_date(extract(year from p_hoje)::int, 12, 31))) v(i, f) loop
      foreach k in array array['faturamento', 'leads', 'vendas'] loop
        begin
          r := metas_avaliar_interno(w, k, per.i, per.f, p_hoje);
          if r->>'meta' is null then continue; end if;
          delete from metas_fotos where workspace_id = w and metrica = k and escopo = 'empresa' and ref is null and ini = per.i and fim = per.f and dia = p_hoje;
          insert into metas_fotos (workspace_id, metrica, escopo, ref, ini, fim, dia, meta, esperado, realizado, projecao, metodo, status, dados)
          values (w, k, 'empresa', null, per.i, per.f, p_hoje, (r->>'meta')::numeric, (r->>'esperado')::numeric, (r->>'realizado')::numeric,
                  (r->>'projecao')::numeric, r->>'metodo', r->>'status', r);
          n := n + 1;
        exception when others then raise warning 'metas_fotografar % %: %', w, k, sqlerrm;
        end;
      end loop;
    end loop;
    -- produtos e campanhas com meta em andamento (janela que contém hoje)
    for mr in select metrica, escopo, coalesce(produto_id, campanha_id) ref, ini, fim from metas
               where workspace_id = w and status = 'aprovada' and escopo in ('produto', 'campanha') and p_hoje between ini and fim loop
      begin
        r := metas_avaliar_interno(w, mr.metrica, mr.ini, mr.fim, p_hoje, mr.escopo, mr.ref);
        delete from metas_fotos where workspace_id = w and metrica = mr.metrica and escopo = mr.escopo and ref = mr.ref and ini = mr.ini and fim = mr.fim and dia = p_hoje;
        insert into metas_fotos (workspace_id, metrica, escopo, ref, ini, fim, dia, meta, esperado, realizado, projecao, metodo, status, dados)
        values (w, mr.metrica, mr.escopo, mr.ref, mr.ini, mr.fim, p_hoje, (r->>'meta')::numeric, (r->>'esperado')::numeric, (r->>'realizado')::numeric,
                (r->>'projecao')::numeric, r->>'metodo', r->>'status', r);
        n := n + 1;
      exception when others then raise warning 'metas_fotografar % recorte: %', w, sqlerrm;
      end;
    end loop;
  end loop;
  return n;
end $$;
revoke all on function public.metas_fotografar(date) from public, anon, authenticated;

drop function if exists public.metas_no_intervalo(uuid, text, date, date);

-- ---------------------------------------------------------------- dicionário
insert into public.metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao)
values ('meta_vendas', 'Vendas (quantidade, metas)', 'Quantidade de vendas aprovadas, pela data da venda. Empresa: inclui o histórico importado. Produto e campanha: só as vendas do Growths ligadas a eles.',
  'v_vendas_todas / vendas', 'Sem vendas aprovadas: 0 (zero é zero).', 'Usada nas metas de vendas do Planejamento anual, das campanhas e dos produtos.'),
  ('meta_leads', 'Leads (metas)', 'Empresa: pessoas captadas no dia (o mesmo número do Dashboard de vendas). Campanha: pessoas que entraram na campanha (o mesmo número do Dashboard da campanha).',
  'pessoas / campanha_participacoes', 'Sem cadastro no período: 0.', 'Usada nas metas de leads do Planejamento anual e das campanhas.')
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao;

notify pgrst, 'reload schema';
