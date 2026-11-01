-- v0.213 — Growth's Brain, incremento 1: registro central de metas (começando pelo faturamento), avaliação da meta
-- (esperado até hoje, realizado, desvio, projeção, status por regra), foto diária, NSM com status e objetivos do ano.
--
-- Decisões da Rebecka (01/11): começar pelo faturamento; as metas existentes são ABSORVIDAS aos poucos (nada é apagado);
-- objetivos estratégicos dentro do Planejamento anual; a NSM "Receita bruta" fica marcada como provisória.
--
-- 1. metas: o registro central. Origem oficial = Planejamento anual. Uma linha por meta (métrica, período, escopo, direção,
--    trajetória, versão, status). Toda alteração guarda a versão anterior em metas_historico.
-- 2. Absorção do faturamento: a meta do ano (plano_anual.meta_receita) e as metas do mês (planejamento_mensal.meta_receita)
--    passam a ficar em metas. As telas antigas continuam funcionando: os dois lados se espelham por gatilho, com trava
--    para não entrar em loop. Quem manda é metas.
-- 3. metas_avaliar(ws, metrica, ini, fim, hoje): meta do período, esperado até hoje, realizado, desvio, projeção (com o método
--    escrito) e status pela regra do workspace (metas_regras). Sem probabilidade: com o histórico de hoje não dá para afirmar.
-- 4. metas_painel(ws, ini, fim, hoje): o que o Cockpit mostra (período escolhido + ano + conferência da soma dos meses).
-- 5. metas_fotos + metas_fotografar(): foto diária (cron 23:53) para medir depois se a projeção acertou.
-- 6. growth_metricas: status da NSM (candidata, provisória, em validação, aprovada), versão, aprovação e histórico.
-- 7. plano_objetivos: objetivos do ano (sem o plano antigo); metas podem se ligar a um objetivo.
-- 8. Dicionário: "faturamento" (vendas aprovadas, o mesmo número do Dashboard de vendas).
--
-- Depende do RODAR_v0.198 (plano_anual) e do RODAR_v0.206 (v_vendas_todas). Pode rodar de novo sem erro.

-- ---------------------------------------------------------------- 1. metas
create table if not exists public.metas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  metrica text not null check (metrica in ('faturamento')),                 -- cresce métrica a métrica (leads, vendas, CAC...)
  escopo text not null default 'empresa' check (escopo in ('empresa', 'produto', 'campanha')),
  produto_id uuid references public.produtos(id) on delete cascade,
  campanha_id uuid references public.campanhas(id) on delete cascade,
  granularidade text not null check (granularidade in ('ano', 'trimestre', 'mes', 'personalizado')),
  ini date not null,
  fim date not null,
  valor numeric not null check (valor >= 0),
  valor_max numeric check (valor_max is null or valor_max >= valor),       -- só para "dentro de uma faixa"
  unidade text not null default 'brl' check (unidade in ('brl', 'num', 'pct', 'x', 'dias')),
  direcao text not null default 'maior' check (direcao in ('maior', 'menor', 'faixa', 'minimo', 'maximo')),
  trajetoria text not null default 'linear' check (trajetoria in ('linear', 'sazonal', 'personalizada')),
  trajetoria_pesos jsonb check (trajetoria_pesos is null or jsonb_typeof(trajetoria_pesos) = 'array'),
  objetivo_id uuid,                                                          -- FK criada no passo 7
  plano_anual_id uuid references public.plano_anual(id) on delete set null,
  origem text not null default 'manual' check (origem in ('plano_anual', 'historico', 'manual', 'hibrido', 'migrada')),
  premissa text check (length(premissa) <= 2000),
  versao int not null default 1,
  status text not null default 'aprovada' check (status in ('rascunho', 'aprovada', 'arquivada')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  aprovado_por uuid default auth.uid(),
  aprovado_em timestamptz default now(),
  check (fim >= ini),
  check ((escopo = 'produto') = (produto_id is not null) and (escopo = 'campanha') = (campanha_id is not null))
);
-- uma meta aprovada por métrica, escopo e período
create unique index if not exists metas_unica_aprovada on public.metas (workspace_id, metrica, escopo,
  coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(campanha_id, '00000000-0000-0000-0000-000000000000'::uuid), ini, fim)
  where status = 'aprovada';
create index if not exists metas_ws_periodo on public.metas (workspace_id, metrica, ini, fim) where status = 'aprovada';

create table if not exists public.metas_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  meta_id uuid not null references public.metas(id) on delete cascade,
  versao int not null,
  dados jsonb not null,
  alterado_por uuid default auth.uid(),
  alterado_em timestamptz not null default now()
);
create index if not exists metas_historico_meta on public.metas_historico (meta_id, versao);

create table if not exists public.metas_regras (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  atencao_pct numeric not null default 10 check (atencao_pct between 0 and 100),  -- até X% abaixo do esperado: dentro do esperado
  risco_pct numeric not null default 25 check (risco_pct between 0 and 100),      -- de X% a Y% abaixo: atenção; mais que Y%: em risco
  min_dias int not null default 3 check (min_dias between 0 and 60),              -- antes disso: "sem dados suficientes"
  atualizado_em timestamptz not null default now(),
  check (risco_pct >= atencao_pct)
);

create table if not exists public.metas_fotos (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  metrica text not null,
  ini date not null,
  fim date not null,
  dia date not null,
  meta numeric,
  esperado numeric,
  realizado numeric,
  projecao numeric,
  metodo text,
  status text,
  dados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  primary key (workspace_id, metrica, ini, fim, dia)
);

alter table public.metas enable row level security;
alter table public.metas_historico enable row level security;
alter table public.metas_regras enable row level security;
alter table public.metas_fotos enable row level security;
do $$ begin
  drop policy if exists metas_rls on public.metas;
  create policy metas_rls on public.metas for all to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna()) with check (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
  drop policy if exists metas_regras_rls on public.metas_regras;
  create policy metas_regras_rls on public.metas_regras for all to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna()) with check (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
  drop policy if exists metas_historico_ler on public.metas_historico;
  create policy metas_historico_ler on public.metas_historico for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
  drop policy if exists metas_fotos_ler on public.metas_fotos;
  create policy metas_fotos_ler on public.metas_fotos for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
end $$;
grant select, insert, update, delete on public.metas, public.metas_regras to authenticated;
grant select on public.metas_historico, public.metas_fotos to authenticated;

-- versão: toda mudança de valor, período, direção, trajetória ou status guarda a anterior
create or replace function public.metas_versiona() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (old.valor, old.valor_max, old.ini, old.fim, old.direcao, old.trajetoria, old.trajetoria_pesos, old.status, old.objetivo_id)
     is distinct from (new.valor, new.valor_max, new.ini, new.fim, new.direcao, new.trajetoria, new.trajetoria_pesos, new.status, new.objetivo_id) then
    insert into metas_historico (workspace_id, meta_id, versao, dados) values (old.workspace_id, old.id, old.versao, to_jsonb(old));
    new.versao := old.versao + 1;
    if new.status = 'aprovada' and old.status <> 'aprovada' then new.aprovado_em := now(); new.aprovado_por := auth.uid(); end if;
  end if;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists metas_versiona on public.metas;
create trigger metas_versiona before update on public.metas for each row execute function public.metas_versiona();

-- ---------------------------------------------------------------- 2. absorção do faturamento (espelho com trava)
-- grava a meta aprovada de faturamento da empresa num período; valor nulo arquiva
create or replace function public.metas_grava_faturamento(p_ws uuid, p_gran text, p_ini date, p_fim date, p_valor numeric, p_origem text, p_plano uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  select id into mid from metas where workspace_id = p_ws and metrica = 'faturamento' and escopo = 'empresa' and ini = p_ini and fim = p_fim and status = 'aprovada';
  if p_valor is null then
    if mid is not null then update metas set status = 'arquivada' where id = mid; end if;
    return null;
  end if;
  if mid is null then
    insert into metas (workspace_id, metrica, escopo, granularidade, ini, fim, valor, origem, plano_anual_id, trajetoria)
    values (p_ws, 'faturamento', 'empresa', p_gran, p_ini, p_fim, p_valor, p_origem, p_plano, case when p_gran = 'ano' then 'sazonal' else 'linear' end)
    returning id into mid;
  else
    update metas set valor = p_valor, plano_anual_id = coalesce(p_plano, plano_anual_id) where id = mid and valor is distinct from p_valor;
  end if;
  return mid;
end $$;
revoke all on function public.metas_grava_faturamento(uuid, text, date, date, numeric, text, uuid) from public, anon, authenticated;

-- planejamento_mensal (tela antiga e Planejamento anual) -> metas
create or replace function public.metas_de_planejamento_mensal() returns trigger
language plpgsql security definer set search_path = public as $$
declare i date;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  if tg_op = 'DELETE' then
    i := make_date(old.ano, old.mes, 1);
    perform metas_grava_faturamento(old.workspace_id, 'mes', i, (i + interval '1 month - 1 day')::date, null, 'plano_anual');
  elsif tg_op = 'INSERT' or new.meta_receita is distinct from old.meta_receita then
    i := make_date(new.ano, new.mes, 1);
    perform metas_grava_faturamento(new.workspace_id, 'mes', i, (i + interval '1 month - 1 day')::date, nullif(new.meta_receita, 0), 'plano_anual');
  end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_de_planejamento_mensal on public.planejamento_mensal;
create trigger metas_de_planejamento_mensal after insert or update or delete on public.planejamento_mensal
  for each row execute function public.metas_de_planejamento_mensal();

-- metas -> planejamento_mensal (as telas que ainda leem de lá continuam certas)
create or replace function public.metas_para_planejamento_mensal() returns trigger
language plpgsql security definer set search_path = public as $$
declare r metas; v numeric;
begin
  if coalesce(current_setting('growths.metas_espelho', true), '') = '1' then return null; end if;
  if tg_op = 'DELETE' then r := old; else r := new; end if;
  if r.metrica <> 'faturamento' or r.escopo <> 'empresa' or r.granularidade <> 'mes' then return null; end if;
  perform set_config('growths.metas_espelho', '1', true);
  v := case when tg_op <> 'DELETE' and r.status = 'aprovada' then r.valor end;
  if v is not null then
    insert into planejamento_mensal (workspace_id, ano, mes, meta_receita) values (r.workspace_id, extract(year from r.ini)::int, extract(month from r.ini)::int, v)
    on conflict (workspace_id, ano, mes) do update set meta_receita = excluded.meta_receita;
  elsif not exists (select 1 from metas where workspace_id = r.workspace_id and metrica = 'faturamento' and escopo = 'empresa' and granularidade = 'mes' and ini = r.ini and status = 'aprovada') then
    update planejamento_mensal set meta_receita = null where workspace_id = r.workspace_id and ano = extract(year from r.ini) and mes = extract(month from r.ini);
  end if;
  perform set_config('growths.metas_espelho', '', true);
  return null;
end $$;
drop trigger if exists metas_para_planejamento_mensal on public.metas;
create trigger metas_para_planejamento_mensal after insert or update or delete on public.metas
  for each row execute function public.metas_para_planejamento_mensal();

-- plano_anual.meta_receita -> meta do ano
create or replace function public.metas_de_plano_anual() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform metas_grava_faturamento(old.workspace_id, 'ano', make_date(old.ano, 1, 1), make_date(old.ano, 12, 31), null, 'plano_anual');
    return old;
  end if;
  if tg_op = 'INSERT' or new.meta_receita is distinct from old.meta_receita then
    perform metas_grava_faturamento(new.workspace_id, 'ano', make_date(new.ano, 1, 1), make_date(new.ano, 12, 31), new.meta_receita, 'plano_anual', new.id);
  end if;
  return new;
end $$;
drop trigger if exists metas_de_plano_anual on public.plano_anual;
create trigger metas_de_plano_anual after insert or update on public.plano_anual for each row execute function public.metas_de_plano_anual();
drop trigger if exists metas_de_plano_anual_del on public.plano_anual;
create trigger metas_de_plano_anual_del before delete on public.plano_anual for each row execute function public.metas_de_plano_anual();

-- absorção do que já existe (uma vez; rodar de novo não duplica)
do $$ declare r record; begin
  perform set_config('growths.metas_espelho', '1', true);
  for r in select workspace_id, ano, mes, meta_receita from planejamento_mensal where coalesce(meta_receita, 0) > 0 loop
    perform metas_grava_faturamento(r.workspace_id, 'mes', make_date(r.ano, r.mes, 1), (make_date(r.ano, r.mes, 1) + interval '1 month - 1 day')::date, r.meta_receita, 'migrada');
  end loop;
  for r in select id, workspace_id, ano, meta_receita from plano_anual where meta_receita is not null loop
    perform metas_grava_faturamento(r.workspace_id, 'ano', make_date(r.ano, 1, 1), make_date(r.ano, 12, 31), r.meta_receita, 'plano_anual', r.id);
  end loop;
  perform set_config('growths.metas_espelho', '', true);
end $$;

-- ---------------------------------------------------------------- 3. avaliação
-- realizado do faturamento: vendas aprovadas (Growths + histórico importado) pela data da venda. O mesmo número do Dashboard de vendas.
create or replace function public.metas_realizado(p_ws uuid, p_metrica text, p_ini date, p_fim date) returns numeric
language sql stable security definer set search_path = public as $$
  select case p_metrica
    when 'faturamento' then (select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between p_ini and p_fim)
  end
$$;
revoke all on function public.metas_realizado(uuid, text, date, date) from public, anon, authenticated;

-- meta de um intervalo de dias: dia a dia. Dia com meta do mês: a meta do mês dividida pelos dias do mês (linear no mês).
-- Dia sem meta do mês, dentro de um ano com meta: o que sobra da meta do ano (meta do ano menos a soma das metas dos meses)
-- dividido pelos dias do ano que não têm meta do mês. Assim a soma do ano inteiro dá exatamente a meta do ano.
create or replace function public.metas_no_intervalo(p_ws uuid, p_metrica text, p_ini date, p_fim date) returns jsonb
language sql stable security definer set search_path = public as $$
  with d as (select g::date as dia from generate_series(p_ini, p_fim, interval '1 day') g),
  mm as (select ini, fim, valor from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada'
           and granularidade = 'mes' and fim >= make_date(extract(year from p_ini)::int, 1, 1) and ini <= make_date(extract(year from p_fim)::int, 12, 31)),
  ma as (select a.ini, a.fim, a.valor,
           greatest(a.valor - coalesce((select sum(valor) from mm where mm.ini between a.ini and a.fim), 0), 0) as sobra,
           (a.fim - a.ini + 1) - coalesce((select sum(mm.fim - mm.ini + 1) from mm where mm.ini between a.ini and a.fim), 0) as dias_livres
         from metas a where a.workspace_id = p_ws and a.metrica = p_metrica and a.escopo = 'empresa' and a.status = 'aprovada'
           and a.granularidade = 'ano' and a.fim >= p_ini and a.ini <= p_fim),
  x as (
    select d.dia,
      (select mm.valor / (mm.fim - mm.ini + 1) from mm where d.dia between mm.ini and mm.fim limit 1) as vm,
      (select case when ma.dias_livres > 0 then ma.sobra / ma.dias_livres else 0 end from ma where d.dia between ma.ini and ma.fim limit 1) as va
    from d)
  select jsonb_build_object(
    'valor', case when count(*) filter (where vm is not null or va is not null) > 0 then round(sum(coalesce(vm, va)), 2) end,
    'dias', count(*),
    'dias_meta_mes', count(*) filter (where vm is not null),
    'dias_meta_ano', count(*) filter (where vm is null and va is not null),
    'dias_sem_meta', count(*) filter (where vm is null and va is null))
  from x
$$;
revoke all on function public.metas_no_intervalo(uuid, text, date, date) from public, anon, authenticated;

create or replace function public.metas_avaliar(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  rg metas_regras; mt jsonb; es jsonb; meta numeric; esp numeric; vreal numeric; ate date; dec int; rest int;
  ritmo numeric; proj numeric; metodo text; nota text; st text; razao numeric; n90 int; h28 numeric;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  select * into rg from metas_regras where workspace_id = p_ws;
  if rg.workspace_id is null then rg.atencao_pct := 10; rg.risco_pct := 25; rg.min_dias := 3; end if;
  ate := least(p_fim, p_hoje);
  mt := metas_no_intervalo(p_ws, p_metrica, p_ini, p_fim);
  meta := (mt->>'valor')::numeric;
  if ate >= p_ini then
    es := metas_no_intervalo(p_ws, p_metrica, p_ini, ate); esp := coalesce((es->>'valor')::numeric, 0);
    vreal := metas_realizado(p_ws, p_metrica, p_ini, ate); dec := ate - p_ini + 1;
  else esp := 0; vreal := 0; dec := 0; end if;
  rest := greatest(p_fim - ate, 0);
  select count(*) into n90 from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between p_hoje - 89 and p_hoje;
  -- projeção até o fim do período (método escrito na resposta)
  if p_hoje >= p_fim then proj := vreal; metodo := 'periodo_encerrado';
  elsif dec >= 7 then ritmo := vreal / dec; proj := vreal + ritmo * rest; metodo := 'ritmo_do_periodo';
  else
    h28 := metas_realizado(p_ws, p_metrica, p_hoje - 27, p_hoje);
    if h28 > 0 then ritmo := h28 / 28; proj := vreal + ritmo * rest; metodo := 'media_28_dias';
    else proj := null; metodo := 'sem_dados'; end if;
  end if;
  nota := case when metodo = 'periodo_encerrado' then 'Período encerrado: a projeção é o realizado.'
               when metodo = 'ritmo_do_periodo' then 'Média por dia do período até hoje, repetida nos dias que faltam. Não considera sazonalidade dentro do período nem campanhas futuras.'
               when metodo = 'media_28_dias' then 'Período com menos de 7 dias: usa a média por dia dos últimos 28 dias, repetida nos dias que faltam.'
               else 'Sem vendas no período nem nos últimos 28 dias: não há base para projetar.' end
          || case when n90 < 10 then ' Pouco histórico (menos de 10 vendas em 90 dias): projeção frágil.' else '' end;
  -- status pela regra do workspace (faturamento: quanto maior, melhor)
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
  return jsonb_build_object('metrica', p_metrica, 'ini', p_ini, 'fim', p_fim, 'hoje', p_hoje, 'ate', ate,
    'meta', meta, 'esperado', round(esp, 2), 'realizado', vreal, 'desvio', round(vreal - esp, 2), 'desvio_pct', case when esp > 0 then (vreal - esp) / esp end,
    'pct_realizado', case when meta > 0 then vreal / meta end, 'projecao', proj, 'pct_projetado', case when meta > 0 and proj is not null then proj / meta end,
    'falta', case when meta is not null then greatest(meta - vreal, 0) end, 'dias_passados', dec, 'dias_restantes', rest,
    'ritmo_dia', ritmo, 'ritmo_necessario_dia', case when meta is not null and rest > 0 then greatest(meta - vreal, 0) / rest end,
    'metodo', metodo, 'nota', nota, 'vendas_90d', n90, 'status', st,
    'regra', jsonb_build_object('atencao_pct', rg.atencao_pct, 'risco_pct', rg.risco_pct, 'min_dias', rg.min_dias),
    'cobertura', mt);
end $$;
revoke all on function public.metas_avaliar(uuid, text, date, date, date) from public, anon;
grant execute on function public.metas_avaliar(uuid, text, date, date, date) to authenticated;

-- conferência: a soma das metas do mês bate com a meta do ano? (faturamento é aditivo; taxas nunca são somadas)
create or replace function public.metas_consistencia(p_ws uuid, p_metrica text, p_ano int) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ano', p_ano,
    'meta_ano', (select valor from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada' and granularidade = 'ano' and ini = make_date(p_ano, 1, 1) and fim = make_date(p_ano, 12, 31)),
    'soma_meses', (select sum(valor) from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada' and granularidade = 'mes' and extract(year from ini) = p_ano),
    'meses', (select count(*) from metas where workspace_id = p_ws and metrica = p_metrica and escopo = 'empresa' and status = 'aprovada' and granularidade = 'mes' and extract(year from ini) = p_ano))
$$;
revoke all on function public.metas_consistencia(uuid, text, int) from public, anon, authenticated;

create or replace function public.metas_painel(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a int := extract(year from p_hoje)::int; c jsonb;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  c := metas_consistencia(p_ws, 'faturamento', a);
  return jsonb_build_object(
    'periodo', metas_avaliar(p_ws, 'faturamento', p_ini, p_fim, p_hoje),
    'ano', metas_avaliar(p_ws, 'faturamento', make_date(a, 1, 1), make_date(a, 12, 31), p_hoje),
    'consistencia', c || jsonb_build_object('diferenca', case when c->>'meta_ano' is not null and c->>'soma_meses' is not null then (c->>'soma_meses')::numeric - (c->>'meta_ano')::numeric end));
end $$;
revoke all on function public.metas_painel(uuid, date, date, date) from public, anon;
grant execute on function public.metas_painel(uuid, date, date, date) to authenticated;

-- ---------------------------------------------------------------- 5. foto diária
create or replace function public.metas_fotografar(p_hoje date default ((now() at time zone 'America/Sao_Paulo')::date)) returns int
language plpgsql security definer set search_path = public as $$
declare w uuid; n int := 0; per record; r jsonb;
begin
  for w in select distinct workspace_id from metas where status = 'aprovada' loop
    for per in select * from (values (date_trunc('month', p_hoje)::date, (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date),
                                     (make_date(extract(year from p_hoje)::int, 1, 1), make_date(extract(year from p_hoje)::int, 12, 31))) v(i, f) loop
      begin
        r := metas_avaliar_interno(w, 'faturamento', per.i, per.f, p_hoje);
        if r->>'meta' is null then continue; end if;
        insert into metas_fotos (workspace_id, metrica, ini, fim, dia, meta, esperado, realizado, projecao, metodo, status, dados)
        values (w, 'faturamento', per.i, per.f, p_hoje, (r->>'meta')::numeric, (r->>'esperado')::numeric, (r->>'realizado')::numeric,
                (r->>'projecao')::numeric, r->>'metodo', r->>'status', r)
        on conflict (workspace_id, metrica, ini, fim, dia) do update set meta = excluded.meta, esperado = excluded.esperado, realizado = excluded.realizado,
          projecao = excluded.projecao, metodo = excluded.metodo, status = excluded.status, dados = excluded.dados, criado_em = now();
        n := n + 1;
      exception when others then raise warning 'metas_fotografar %: %', w, sqlerrm;
      end;
    end loop;
  end loop;
  return n;
end $$;
revoke all on function public.metas_fotografar(date) from public, anon, authenticated;

-- a versão do cron roda sem usuário: metas_avaliar checa o acesso; esta é a mesma conta, chamada só por funções do banco
create or replace function public.metas_avaliar_interno(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('growths.metas_interno', '1', true);
  return metas_avaliar(p_ws, p_metrica, p_ini, p_fim, p_hoje);
end $$;
revoke all on function public.metas_avaliar_interno(uuid, text, date, date, date) from public, anon, authenticated;
-- metas_avaliar aceita a chamada interna (cron) além do usuário com acesso
create or replace function public.metas_pode(p_ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_setting('growths.metas_interno', true), '') = '1' and auth.uid() is null or pertence_ao_workspace(p_ws) or sou_equipe_interna()
$$;
revoke all on function public.metas_pode(uuid) from public, anon;
grant execute on function public.metas_pode(uuid) to authenticated;
do $$ begin
  -- troca a checagem de acesso de metas_avaliar pela que aceita o cron
  execute replace(pg_get_functiondef('public.metas_avaliar(uuid, text, date, date, date)'::regprocedure),
    'if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then', 'if not metas_pode(p_ws) then');
end $$;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'growths-metas-foto';
    perform cron.schedule('growths-metas-foto', '53 2 * * *', 'select public.metas_fotografar(((now() at time zone ''America/Sao_Paulo'') - interval ''10 minutes'')::date)');
  end if;
end $$;

-- ---------------------------------------------------------------- 6. NSM com status, versão e histórico
alter table public.growth_metricas add column if not exists nsm_status text check (nsm_status in ('candidata', 'provisoria', 'em_validacao', 'aprovada'));
alter table public.growth_metricas add column if not exists nsm_versao int not null default 1;
alter table public.growth_metricas add column if not exists nsm_aprovada_em timestamptz;
alter table public.growth_metricas add column if not exists nsm_aprovada_por uuid;
alter table public.growth_metricas add column if not exists nsm_nota text check (length(nsm_nota) <= 2000);

create table if not exists public.nsm_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  metrica_id uuid references public.growth_metricas(id) on delete set null,
  versao int not null,
  dados jsonb not null,
  alterado_por uuid default auth.uid(),
  alterado_em timestamptz not null default now()
);
alter table public.nsm_historico enable row level security;
drop policy if exists nsm_historico_ler on public.nsm_historico;
create policy nsm_historico_ler on public.nsm_historico for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
grant select on public.nsm_historico to authenticated;

create or replace function public.nsm_versiona() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'north_star' and new.nsm_status is null then new.nsm_status := 'provisoria'; end if;
  if new.tipo <> 'north_star' then new.nsm_status := null; end if;
  if tg_op = 'UPDATE' and old.tipo = 'north_star' and (old.nome, old.formula, old.chave_auto, old.meta, old.nsm_status, old.nsm_evento, old.unidade)
     is distinct from (new.nome, new.formula, new.chave_auto, new.meta, new.nsm_status, new.nsm_evento, new.unidade) then
    insert into nsm_historico (workspace_id, metrica_id, versao, dados) values (old.workspace_id, old.id, old.nsm_versao, to_jsonb(old));
    new.nsm_versao := old.nsm_versao + 1;
    if new.nsm_status = 'aprovada' and old.nsm_status is distinct from 'aprovada' then new.nsm_aprovada_em := now(); new.nsm_aprovada_por := auth.uid(); end if;
  end if;
  return new;
end $$;
drop trigger if exists nsm_versiona on public.growth_metricas;
create trigger nsm_versiona before insert or update on public.growth_metricas for each row execute function public.nsm_versiona();
-- as NSM que já existem ficam provisórias (decisão de 01/11: "Receita bruta" não é a NSM definitiva)
update public.growth_metricas set nsm_status = 'provisoria' where tipo = 'north_star' and nsm_status is null;

-- ---------------------------------------------------------------- 7. objetivos do ano
alter table public.plano_objetivos add column if not exists ano int check (ano between 2000 and 2100);
alter table public.plano_objetivos alter column plano_id drop not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plano_objetivos_plano_ou_ano') then
    alter table public.plano_objetivos add constraint plano_objetivos_plano_ou_ano check (plano_id is not null or ano is not null);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'metas_objetivo_fk') then
    alter table public.metas add constraint metas_objetivo_fk foreign key (objetivo_id) references public.plano_objetivos(id) on delete set null;
  end if;
end $$;
create or replace function public.plano_mesmo_workspace() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'campanhas' then
    if new.meta_id is not null and not exists (select 1 from plano_metas where id = new.meta_id and workspace_id = new.workspace_id) then
      raise exception 'A meta precisa ser do mesmo workspace da campanha';
    end if;
  elsif new.plano_id is not null then
    if not exists (select 1 from planos where id = new.plano_id and workspace_id = new.workspace_id) then
      raise exception 'O plano precisa ser do mesmo workspace';
    end if;
  end if;
  return new;
end $$;
-- meta e objetivo sempre do mesmo workspace
create or replace function public.metas_mesmo_workspace() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.objetivo_id is not null and not exists (select 1 from plano_objetivos where id = new.objetivo_id and workspace_id = new.workspace_id) then
    raise exception 'O objetivo precisa ser do mesmo cliente da meta';
  end if;
  if new.produto_id is not null and not exists (select 1 from produtos where id = new.produto_id and workspace_id = new.workspace_id) then
    raise exception 'O produto precisa ser do mesmo cliente da meta';
  end if;
  if new.campanha_id is not null and not exists (select 1 from campanhas where id = new.campanha_id and workspace_id = new.workspace_id) then
    raise exception 'A campanha precisa ser do mesmo cliente da meta';
  end if;
  return new;
end $$;
drop trigger if exists metas_mesmo_workspace on public.metas;
create trigger metas_mesmo_workspace before insert or update on public.metas for each row execute function public.metas_mesmo_workspace();

-- ---------------------------------------------------------------- 8. dicionário
insert into public.metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao)
values ('faturamento', 'Faturamento (vendas)',
  'Soma do valor bruto das vendas aprovadas, pela data da venda. Inclui o histórico importado. Reembolsadas e canceladas ficam de fora.',
  'vendas.valor_bruto + vendas_historicas.valor (v_vendas_todas)', 'Sem vendas aprovadas no período: R$ 0,00 (zero é zero).',
  'É a métrica das metas de faturamento do Planejamento anual e o "Faturamento" do Dashboard de vendas. Não é a receita da DRE (lançamentos, por competência).')
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao;

notify pgrst, 'reload schema';
