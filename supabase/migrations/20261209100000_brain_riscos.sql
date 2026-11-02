-- v0.215 — Growth's Brain, incremento 3: Risk Engine (registro único de riscos).
--
-- Um lugar só para os riscos do cliente, alimentado pelo que o Growths já detecta, sem criar um detector novo para cada área:
--   metas      → das metas do registro central (mês e ano da empresa; campanhas e produtos em andamento):
--                "abaixo do esperado" (status Atenção/Em risco), "risco de não atingir" (projeção abaixo da meta) e "oportunidade" (projeção 10% acima).
--   alertas    → os avisos em aberto do assistente e do CS (tabela alertas), AGRUPADOS por regra: 484 alunos sem CS viram 1 risco, não 484.
--   guardrails → alertas de guardrail em aberto.
--   qualidade  → regras de qualidade de dados com problema nos últimos 30 dias (só quando um usuário atualiza; o cron não roda sem login).
-- Cada risco tem: tipo, área, métrica, meta, escopo, período, severidade, evidência (texto + números), impacto estimado, fonte, data de detecção,
-- status (aberto, em tratamento, resolvido, descartado), responsável, ação sugerida, nota e o histórico de cada mudança (riscos_eventos).
-- O detector é idempotente: um risco que continua existindo é atualizado (não duplica); um risco cuja condição sumiu é resolvido "pelo sistema";
-- um risco descartado por alguém não volta enquanto a condição for a mesma (mesma chave).
-- Severidade e impacto são regras escritas (sem probabilidade estatística).
-- Depende do RODAR_v0.214. Pode rodar de novo sem erro.

create table if not exists public.riscos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  chave text not null,
  tipo text not null check (tipo in ('abaixo_do_esperado', 'risco_de_nao_atingir', 'oportunidade', 'qualidade_dados', 'operacional')),
  area text not null check (area in ('empresa', 'marketing', 'vendas', 'cs', 'financeiro', 'growth')),
  metrica text,
  meta_id uuid references public.metas(id) on delete set null,
  escopo text,
  ref uuid,
  ini date,
  fim date,
  severidade text not null check (severidade in ('alta', 'media', 'baixa')),
  titulo text not null,
  evidencia text not null,
  dados jsonb not null default '{}'::jsonb,
  impacto numeric,
  impacto_unidade text check (impacto_unidade in ('brl', 'num', 'qtd')),
  fonte text not null check (fonte in ('metas', 'alertas', 'guardrails', 'qualidade')),
  acao_sugerida text,
  status text not null default 'aberto' check (status in ('aberto', 'em_tratamento', 'resolvido', 'descartado')),
  responsavel text check (length(responsavel) <= 120),
  nota text check (length(nota) <= 2000),
  detectado_em timestamptz not null default now(),
  visto_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  resolvido_em timestamptz,
  resolvido_por text check (resolvido_por in ('sistema', 'usuario')),
  unique (workspace_id, chave)
);
create index if not exists riscos_ws_status on public.riscos (workspace_id, status, severidade);

create table if not exists public.riscos_eventos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  risco_id uuid not null references public.riscos(id) on delete cascade,
  evento text not null check (evento in ('detectado', 'reaberto', 'resolvido_sistema', 'em_tratamento', 'resolvido', 'descartado', 'reaberto_usuario', 'responsavel', 'nota')),
  de text, para text, nota text,
  por uuid default auth.uid(),
  em timestamptz not null default now()
);
create index if not exists riscos_eventos_risco on public.riscos_eventos (risco_id, em);

create table if not exists public.riscos_rodadas (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  rodou_em timestamptz not null,
  resumo jsonb not null default '{}'::jsonb
);

alter table public.riscos enable row level security;
alter table public.riscos_eventos enable row level security;
alter table public.riscos_rodadas enable row level security;
do $$ begin
  drop policy if exists riscos_ler on public.riscos;
  create policy riscos_ler on public.riscos for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
  drop policy if exists riscos_eventos_ler on public.riscos_eventos;
  create policy riscos_eventos_ler on public.riscos_eventos for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
  drop policy if exists riscos_rodadas_ler on public.riscos_rodadas;
  create policy riscos_rodadas_ler on public.riscos_rodadas for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
end $$;
-- escrita só pelas funções (riscos_detectar / riscos_acao): assim todo passo fica no histórico
grant select on public.riscos, public.riscos_eventos, public.riscos_rodadas to authenticated;

-- ---------------------------------------------------------------- textos
create or replace function public.riscos_fmt(v numeric, un text) returns text language sql immutable as $$
  select case when un = 'brl' then growths_brl(v) else growths_num(round(v)) end
$$;
create or replace function public.riscos_mes_nome(d date) returns text language sql immutable as $$
  select (array['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'])[extract(month from d)::int] || '/' || extract(year from d)::int
$$;

-- grava um candidato: insere, atualiza, reabre (se o sistema tinha resolvido) ou mantém descartado
create or replace function public.riscos_grava(p_ws uuid, c jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare r riscos; ch text := c->>'chave';
begin
  select * into r from riscos where workspace_id = p_ws and chave = ch;
  if r.id is null then
    insert into riscos (workspace_id, chave, tipo, area, metrica, meta_id, escopo, ref, ini, fim, severidade, titulo, evidencia, dados, impacto, impacto_unidade, fonte, acao_sugerida)
    values (p_ws, ch, c->>'tipo', c->>'area', c->>'metrica', (c->>'meta_id')::uuid, c->>'escopo', (c->>'ref')::uuid, (c->>'ini')::date, (c->>'fim')::date,
            c->>'severidade', c->>'titulo', c->>'evidencia', coalesce(c->'dados', '{}'::jsonb), round((c->>'impacto')::numeric, 2), c->>'impacto_unidade', c->>'fonte', c->>'acao')
    returning * into r;
    update riscos set visto_em = clock_timestamp() where id = r.id;
    insert into riscos_eventos (workspace_id, risco_id, evento, para) values (p_ws, r.id, 'detectado', r.severidade);
    return 'novo';
  end if;
  update riscos set severidade = c->>'severidade', titulo = c->>'titulo', evidencia = c->>'evidencia', dados = coalesce(c->'dados', '{}'::jsonb),
         impacto = round((c->>'impacto')::numeric, 2), impacto_unidade = c->>'impacto_unidade', acao_sugerida = c->>'acao', meta_id = coalesce((c->>'meta_id')::uuid, meta_id),
         visto_em = clock_timestamp(), atualizado_em = now(),
         status = case when status = 'resolvido' and resolvido_por = 'sistema' then 'aberto' else status end,
         resolvido_em = case when status = 'resolvido' and resolvido_por = 'sistema' then null else resolvido_em end,
         resolvido_por = case when status = 'resolvido' and resolvido_por = 'sistema' then null else resolvido_por end
   where id = r.id;
  if r.status = 'resolvido' and r.resolvido_por = 'sistema' then
    insert into riscos_eventos (workspace_id, risco_id, evento, de, para) values (p_ws, r.id, 'reaberto', 'resolvido', 'aberto');
    return 'reaberto';
  end if;
  return 'atualizado';
end $$;
revoke all on function public.riscos_grava(uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- detectores
-- metas: uma avaliação vira até um "abaixo do esperado" + um "risco de não atingir" (ou uma "oportunidade")
create or replace function public.riscos_de_meta(p_ws uuid, r jsonb, p_rot text, p_area text, p_meta uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare out jsonb := '[]'::jsonb; un text := r->>'unidade'; st text := r->>'status'; base text; nome text;
  meta numeric := (r->>'meta')::numeric; esp numeric := (r->>'esperado')::numeric; rl numeric := (r->>'realizado')::numeric;
  pj numeric := (r->>'projecao')::numeric; pp numeric := (r->>'pct_projetado')::numeric; fim date := (r->>'fim')::date; hoje date := (r->>'hoje')::date;
  acao text;
begin
  if meta is null or st in ('sem_meta', 'nao_comecou', 'sem_dados', 'atingida', 'nao_atingida') then return out; end if;
  -- período só em parte coberto por meta (ex.: o ano com meta só em novembro): o risco já aparece no período que tem meta
  if coalesce((r->>'parcial')::boolean, false) then return out; end if;
  nome := initcap(case r->>'metrica' when 'faturamento' then 'faturamento' when 'leads' then 'leads' else 'vendas' end);
  base := 'meta:' || (r->>'metrica') || ':' || (r->>'escopo') || ':' || coalesce(r->>'ref', '') || ':' || (r->>'ini') || ':' || (r->>'fim');
  acao := case r->>'metrica'
    when 'leads' then 'Ver no Dashboard de marketing quais campanhas e canais estão abaixo do ritmo; revisar investimento, criativo e página.'
    when 'vendas' then 'Ver no Dashboard de vendas a conversão e as oportunidades abertas; revisar oferta, follow-up e recuperação de carrinho.'
    else 'Ver no Dashboard de vendas o que está faltando (produto, ticket, volume) e as campanhas do período.' end;
  if st in ('atencao', 'risco') then
    out := out || jsonb_build_array(jsonb_build_object('chave', base || ':abaixo', 'tipo', 'abaixo_do_esperado', 'area', p_area, 'metrica', r->>'metrica', 'meta_id', p_meta,
      'escopo', r->>'escopo', 'ref', r->>'ref', 'ini', r->>'ini', 'fim', r->>'fim', 'fonte', 'metas', 'severidade', case when st = 'risco' then 'alta' else 'media' end,
      'titulo', nome || ' abaixo do esperado · ' || p_rot,
      'evidencia', 'Até ' || to_char(least(hoje, fim), 'DD/MM') || ': ' || riscos_fmt(rl, un) || ' realizados; o esperado era ' || riscos_fmt(esp, un) ||
                   ' (' || replace(to_char(round(((rl - esp) / nullif(esp, 0)) * 100, 1), 'FM990.0'), '.', ',') || '%). Regra: ' || (r #>> '{regra,atencao_pct}') || '% abaixo = atenção, ' || (r #>> '{regra,risco_pct}') || '% = em risco.',
      'impacto', greatest(esp - rl, 0), 'impacto_unidade', un, 'acao', acao, 'dados', r));
  end if;
  if pj is not null and pp is not null and hoje < fim and r->>'metodo' <> 'sem_dados' then
    if pp < 0.95 then
      out := out || jsonb_build_array(jsonb_build_object('chave', base || ':projecao', 'tipo', 'risco_de_nao_atingir', 'area', p_area, 'metrica', r->>'metrica', 'meta_id', p_meta,
        'escopo', r->>'escopo', 'ref', r->>'ref', 'ini', r->>'ini', 'fim', r->>'fim', 'fonte', 'metas', 'severidade', case when pp < 0.75 then 'alta' when pp < 0.9 then 'media' else 'baixa' end,
        'titulo', 'Risco de não atingir a meta de ' || lower(nome) || ' · ' || p_rot,
        'evidencia', 'No ritmo atual, a projeção até ' || to_char(fim, 'DD/MM') || ' é ' || riscos_fmt(pj, un) || ' (' || round(pp * 100) || '% da meta de ' || riscos_fmt(meta, un) || '). ' ||
                     'Para bater, faltam ' || riscos_fmt(greatest(meta - rl, 0), un) || ' em ' || (r->>'dias_restantes') || ' dia(s). Projeção pelo ' ||
                     case r->>'metodo' when 'ritmo_do_periodo' then 'ritmo do período' else 'média dos últimos 28 dias' end || '; não é probabilidade.',
        'impacto', meta - pj, 'impacto_unidade', un, 'acao', acao, 'dados', r));
    elsif pp >= 1.1 then
      out := out || jsonb_build_array(jsonb_build_object('chave', base || ':oportunidade', 'tipo', 'oportunidade', 'area', p_area, 'metrica', r->>'metrica', 'meta_id', p_meta,
        'escopo', r->>'escopo', 'ref', r->>'ref', 'ini', r->>'ini', 'fim', r->>'fim', 'fonte', 'metas', 'severidade', 'baixa',
        'titulo', 'Pode superar a meta de ' || lower(nome) || ' · ' || p_rot,
        'evidencia', 'No ritmo atual, a projeção até ' || to_char(fim, 'DD/MM') || ' é ' || riscos_fmt(pj, un) || ' (' || round(pp * 100) || '% da meta de ' || riscos_fmt(meta, un) || ').',
        'impacto', pj - meta, 'impacto_unidade', un, 'acao', 'Ver o que está puxando o resultado e se dá para escalar (verba, estoque de atendimento, oferta).', 'dados', r));
    end if;
  end if;
  return out;
end $$;
revoke all on function public.riscos_de_meta(uuid, jsonb, text, text, uuid) from public, anon, authenticated;

create or replace function public.riscos_detectar(p_ws uuid, p_hoje date default ((now() at time zone 'America/Sao_Paulo')::date)) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  inicio timestamptz := clock_timestamp(); cands jsonb := '[]'::jsonb; c jsonb; k text; r jsonb; per record; mr record; al record; g record; q jsonb;
  fontes text[] := array['metas', 'alertas', 'guardrails']; n_novo int := 0; n_at int := 0; n_re int := 0; n_res int := 0; x text; area text; rot text;
begin
  if not metas_pode(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  perform set_config('growths.metas_interno', '1', true);
  -- 1. metas da empresa: mês e ano
  for per in select * from (values (date_trunc('month', p_hoje)::date, (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date, riscos_mes_nome(p_hoje)),
                                   (make_date(extract(year from p_hoje)::int, 1, 1), make_date(extract(year from p_hoje)::int, 12, 31), 'ano ' || extract(year from p_hoje)::int)) v(i, f, rot) loop
    foreach k in array array['faturamento', 'leads', 'vendas'] loop
      r := metas_avaliar(p_ws, k, per.i, per.f, p_hoje);
      area := case k when 'faturamento' then 'empresa' when 'leads' then 'marketing' else 'vendas' end;
      cands := cands || riscos_de_meta(p_ws, r, per.rot, area, null);
    end loop;
  end loop;
  -- 2. metas de campanha e produto em andamento
  for mr in select m.id, m.metrica, m.escopo, coalesce(m.produto_id, m.campanha_id) ref, m.ini, m.fim, coalesce(pr.nome, ca.nome) nome
              from metas m left join produtos pr on pr.id = m.produto_id left join campanhas ca on ca.id = m.campanha_id
             where m.workspace_id = p_ws and m.status = 'aprovada' and m.escopo in ('produto', 'campanha') and p_hoje between m.ini and m.fim loop
    r := metas_avaliar(p_ws, mr.metrica, mr.ini, mr.fim, p_hoje, mr.escopo, mr.ref);
    area := case when mr.escopo = 'campanha' and mr.metrica = 'leads' then 'marketing' when mr.escopo = 'campanha' then 'marketing' else 'vendas' end;
    cands := cands || riscos_de_meta(p_ws, r, case when mr.escopo = 'campanha' then 'campanha ' else 'produto ' end || coalesce(mr.nome, '—'), area, mr.id);
  end loop;
  -- 3. alertas em aberto, agrupados por regra (CS: todos em aberto; os outros: últimos 14 dias)
  for al in select a.regra, a.tipo, count(*) n, max(a.dia) ultimo,
                   max(case a.severidade when 'alta' then 3 when 'media' then 2 else 1 end) sev,
                   (array_agg(a.titulo order by a.dia desc, a.criado_em desc))[1] titulo, (array_agg(a.mensagem order by a.dia desc, a.criado_em desc))[1] mensagem
              from alertas a where a.workspace_id = p_ws and a.resolvido_em is null and (a.tipo = 'cs' or a.dia >= p_hoje - 13)
             group by a.regra, a.tipo loop
    area := case when al.tipo = 'cs' then 'cs' when al.regra in ('contas_vencidas', 'saldo_minimo') then 'financeiro'
                 when al.regra in ('sem_vendas', 'reembolsos', 'brusco_vendas', 'brusco_receita') then 'vendas'
                 when al.regra = 'sem_dados' then 'empresa' else 'marketing' end;
    rot := case al.regra when 'sem_cs' then 'Alunos sem CS responsável' when 'parado' then 'Alunos parados na jornada' when 'contas_vencidas' then 'Contas vencidas'
                when 'saldo_minimo' then 'Caixa abaixo do saldo mínimo' when 'sem_vendas' then 'Dias seguidos sem venda' when 'reembolsos' then 'Reembolsos acima do normal'
                when 'cpl_meta' then 'CPL acima da meta da campanha' when 'gasto_sem_lead' then 'Gasto em anúncio sem lead' when 'queda_seguida' then 'Leads caindo dias seguidos'
                when 'sem_dados' then 'Dados que pararam de chegar'
                else case when al.regra like 'brusco_%' then 'Variação fora do normal: ' || replace(substr(al.regra, 8), '_', ' ') else al.titulo end end;
    cands := cands || jsonb_build_array(jsonb_build_object('chave', 'alerta:' || al.regra, 'tipo', case when al.regra = 'sem_dados' then 'qualidade_dados' else 'operacional' end,
      'area', area, 'fonte', 'alertas', 'severidade', case al.sev when 3 then 'alta' when 2 then 'media' else 'baixa' end,
      'titulo', rot || case when al.n > 1 then ' (' || al.n || ')' else '' end,
      'evidencia', al.n || ' aviso(s) em aberto. O mais recente (' || to_char(al.ultimo, 'DD/MM') || '): ' || al.titulo || coalesce(' — ' || nullif(al.mensagem, ''), ''),
      'impacto', al.n, 'impacto_unidade', 'qtd',
      'acao', case when al.tipo = 'cs' then 'Abrir Customer Growth e distribuir ou atender os alunos da lista.' when area = 'financeiro' then 'Abrir Contas a pagar/receber e regularizar.'
                   else 'Abrir Alertas e resumo do dia para ver cada aviso.' end,
      'dados', jsonb_build_object('regra', al.regra, 'tipo_alerta', al.tipo, 'avisos', al.n, 'ultimo', al.ultimo)));
  end loop;
  -- 4. guardrails em aberto
  for g in select d.id, d.nome, d.metrica, count(*) n, max(case ga.severidade when 'critico' then 2 else 1 end) sev, max(ga.data) ultimo,
                  (array_agg(ga.mensagem order by ga.data desc))[1] mensagem, (array_agg(coalesce(ga.acao_sugerida, d.acao_sugerida) order by ga.data desc))[1] acao
             from guardrail_alertas ga join guardrail_definicoes d on d.id = ga.guardrail_id
            where ga.workspace_id = p_ws and ga.status <> 'resolvido' group by d.id, d.nome, d.metrica loop
    cands := cands || jsonb_build_array(jsonb_build_object('chave', 'guardrail:' || g.id, 'tipo', 'operacional', 'fonte', 'guardrails',
      'area', case when g.metrica in ('margem', 'lucro') then 'financeiro' when g.metrica in ('receita', 'vendas', 'ticket', 'conv') then 'vendas' else 'marketing' end,
      'severidade', case g.sev when 2 then 'alta' else 'media' end, 'titulo', 'Guardrail: ' || g.nome,
      'evidencia', g.n || ' alerta(s) em aberto. O mais recente (' || to_char(g.ultimo, 'DD/MM') || '): ' || g.mensagem, 'impacto', g.n, 'impacto_unidade', 'qtd',
      'acao', coalesce(g.acao, 'Abrir Guardrails e decidir se o limite foi cruzado de fato.'), 'dados', jsonb_build_object('guardrail_id', g.id, 'alertas', g.n)));
  end loop;
  -- 5. qualidade dos dados (precisa de login: o cron pula)
  begin
    q := qualidade_dados(p_ws, p_hoje - 29, p_hoje);
    fontes := array_append(fontes, 'qualidade');
    for c in select * from jsonb_array_elements(coalesce(q, '[]'::jsonb)) loop
      cands := cands || jsonb_build_array(jsonb_build_object('chave', 'qualidade:' || (c->>'codigo'), 'tipo', 'qualidade_dados', 'area', 'empresa', 'fonte', 'qualidade',
        'severidade', case when c->>'severidade' = 'alerta' then 'media' else 'baixa' end, 'titulo', 'Dado com problema: ' || (c->>'titulo'),
        'evidencia', coalesce(c->>'texto', c->>'explica', c->>'titulo') || ' (últimos 30 dias)',
        'impacto', (c->>'qtd')::numeric, 'impacto_unidade', 'qtd', 'acao', 'Corrigir na origem para os números do Cockpit ficarem confiáveis.', 'dados', c));
    end loop;
  exception when others then null;
  end;
  -- grava
  for c in select * from jsonb_array_elements(cands) loop
    x := riscos_grava(p_ws, c);
    if x = 'novo' then n_novo := n_novo + 1; elsif x = 'reaberto' then n_re := n_re + 1; else n_at := n_at + 1; end if;
  end loop;
  -- o que não apareceu nesta rodada (nas fontes que rodaram) foi resolvido pelo sistema
  with fechados as (
    update riscos set status = 'resolvido', resolvido_em = now(), resolvido_por = 'sistema', atualizado_em = now()
     where workspace_id = p_ws and status in ('aberto', 'em_tratamento') and fonte = any (fontes) and visto_em < inicio
    returning id, status)
  insert into riscos_eventos (workspace_id, risco_id, evento, de, para, nota)
  select p_ws, id, 'resolvido_sistema', 'aberto', 'resolvido', 'A condição deixou de existir em ' || to_char(p_hoje, 'DD/MM/YYYY') || '.' from fechados;
  get diagnostics n_res = row_count;
  insert into riscos_rodadas (workspace_id, rodou_em, resumo) values (p_ws, now(), jsonb_build_object('novos', n_novo, 'atualizados', n_at, 'reabertos', n_re, 'resolvidos', n_res, 'fontes', to_jsonb(fontes), 'dia', p_hoje))
  on conflict (workspace_id) do update set rodou_em = excluded.rodou_em, resumo = excluded.resumo;
  return jsonb_build_object('novos', n_novo, 'atualizados', n_at, 'reabertos', n_re, 'resolvidos', n_res, 'fontes', to_jsonb(fontes));
end $$;
revoke all on function public.riscos_detectar(uuid, date) from public, anon;
grant execute on function public.riscos_detectar(uuid, date) to authenticated;

-- ---------------------------------------------------------------- tela
-- devolve os riscos em aberto (e roda o detector se a última rodada tem mais de 3 horas)
create or replace function public.riscos_painel(p_ws uuid, p_hoje date default ((now() at time zone 'America/Sao_Paulo')::date), p_forcar boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ult timestamptz;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  select rodou_em into ult from riscos_rodadas where workspace_id = p_ws;
  if p_forcar or ult is null or ult < now() - interval '3 hours' then perform riscos_detectar(p_ws, p_hoje); end if;
  return jsonb_build_object(
    'rodou_em', (select rodou_em from riscos_rodadas where workspace_id = p_ws),
    'resumo', (select resumo from riscos_rodadas where workspace_id = p_ws),
    'abertos', coalesce((select jsonb_agg(to_jsonb(r) - 'dados' order by case r.severidade when 'alta' then 1 when 'media' then 2 else 3 end,
                           case r.tipo when 'oportunidade' then 2 else 1 end, r.detectado_em desc)
                         from riscos r where r.workspace_id = p_ws and r.status in ('aberto', 'em_tratamento')), '[]'::jsonb),
    'por_area', coalesce((select jsonb_object_agg(area, n) from (select area, count(*) n from riscos where workspace_id = p_ws and status in ('aberto', 'em_tratamento') and tipo <> 'oportunidade' group by area) x), '{}'::jsonb),
    'resolvidos_30d', (select count(*) from riscos where workspace_id = p_ws and status = 'resolvido' and resolvido_em > now() - interval '30 days'),
    'descartados', (select count(*) from riscos where workspace_id = p_ws and status = 'descartado'));
end $$;
revoke all on function public.riscos_painel(uuid, date, boolean) from public, anon;
grant execute on function public.riscos_painel(uuid, date, boolean) to authenticated;

-- ação de uma pessoa: assumir, tratar, resolver, descartar, reabrir, anotar (tudo fica em riscos_eventos)
create or replace function public.riscos_acao(p_risco uuid, p_acao text, p_nota text default null, p_responsavel text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r riscos; novo text;
begin
  select * into r from riscos where id = p_risco;
  if r.id is null or not (pertence_ao_workspace(r.workspace_id) or sou_equipe_interna()) then raise exception 'Risco não encontrado'; end if;
  if p_acao not in ('em_tratamento', 'resolvido', 'descartado', 'reaberto_usuario', 'responsavel', 'nota') then raise exception 'Ação inválida'; end if;
  if p_acao = 'descartado' and coalesce(trim(p_nota), '') = '' then raise exception 'Diga por que o risco foi descartado.'; end if;
  novo := case p_acao when 'reaberto_usuario' then 'aberto' when 'responsavel' then r.status when 'nota' then r.status else p_acao end;
  update riscos set status = novo,
         responsavel = case when p_acao = 'responsavel' then nullif(trim(p_responsavel), '') else coalesce(nullif(trim(p_responsavel), ''), responsavel) end,
         nota = coalesce(nullif(trim(p_nota), ''), nota), atualizado_em = now(),
         resolvido_em = case when novo in ('resolvido', 'descartado') then now() else null end,
         resolvido_por = case when novo in ('resolvido', 'descartado') then 'usuario' else null end
   where id = r.id;
  insert into riscos_eventos (workspace_id, risco_id, evento, de, para, nota)
  values (r.workspace_id, r.id, p_acao, case when p_acao = 'responsavel' then r.responsavel else r.status end, case when p_acao = 'responsavel' then p_responsavel else novo end, nullif(trim(p_nota), ''));
  return jsonb_build_object('id', r.id, 'status', novo);
end $$;
revoke all on function public.riscos_acao(uuid, text, text, text) from public, anon;
grant execute on function public.riscos_acao(uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------- cron: todo dia 08:17 (depois dos alertas e da foto das metas)
create or replace function public.riscos_rodar(p_hoje date default ((now() at time zone 'America/Sao_Paulo')::date)) returns int
language plpgsql security definer set search_path = public as $$
declare w uuid; n int := 0;
begin
  perform set_config('growths.metas_interno', '1', true);
  for w in select id from workspaces where id in (select workspace_id from metas where status = 'aprovada' union select workspace_id from alertas where resolvido_em is null
                                                   union select workspace_id from guardrail_alertas where status <> 'resolvido') loop
    begin perform riscos_detectar(w, p_hoje); n := n + 1;
    exception when others then raise warning 'riscos_rodar %: %', w, sqlerrm; end;
  end loop;
  return n;
end $$;
revoke all on function public.riscos_rodar(date) from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'growths-riscos';
    perform cron.schedule('growths-riscos', '17 11 * * *', 'select public.riscos_rodar()');
  end if;
end $$;

notify pgrst, 'reload schema';
