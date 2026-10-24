-- v0.132: "Como foi meu dia?" e alertas automáticos.
-- 1) growths_serie / growths_fatos_dia: os números de cada dia (leads, vendas, receita, reembolsos, mídia, formulários,
--    abandonos e contas), com a comparação com os 7 dias anteriores e o mesmo dia da semana passada. Sem IA: conta exata.
-- 2) growths_verificar_alertas: procura o que mudou de forma brusca (ontem fora do normal dos 14 dias anteriores),
--    o que se repete (dias seguidos de queda, sem vendas, CPL acima da meta, reembolsos) e o que pede ação hoje
--    (gasto sem lead, contas vencidas, saldo abaixo do mínimo). Cada alerta é gravado uma vez e avisa a equipe
--    pelos canais que cada pessoa escolheu (sino, e-mail, WhatsApp) na fila de notificações.
-- 3) growths_resumo_gerar: o resumo do dia em texto, guardado e enviado do mesmo jeito.
-- 4) growths_rodar_agendado: o que o agendador do banco (pg_cron) roda de hora em hora; pede à edge function
--    "avisos" que envie os e-mails e WhatsApps da fila (via pg_net, se existir).
-- Pode ser rodado de novo sem erro.

create table if not exists public.alertas_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  ligado boolean not null default true,
  resumo_diario boolean not null default true,
  resumo_hora int not null default 7 check (resumo_hora between 0 and 23),
  regras jsonb not null default '{}'::jsonb check (jsonb_typeof(regras) = 'object'),
  destinatarios uuid[] not null default '{}',
  atualizado_em timestamptz not null default now()
);
comment on column public.alertas_config.regras is 'Sensibilidade: {"variacao_pct":40,"desvios":2,"dias_seguidos":3,"gasto_sem_lead":100,"desligadas":["contas_vencidas",...]}.';
comment on column public.alertas_config.destinatarios is 'Pessoas da equipe que recebem (vazio = todos da equipe com acesso ao sistema). O canal é o de cada pessoa (avisar_app/email/whatsapp).';

create table if not exists public.alertas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  chave text not null,
  tipo text not null check (tipo in ('brusco', 'repetido', 'operacional')),
  regra text not null,
  severidade text not null check (severidade in ('alta', 'media', 'info')),
  titulo text not null,
  mensagem text not null,
  dados jsonb not null default '{}'::jsonb,
  dia date not null,
  criado_em timestamptz not null default now(),
  visto_em timestamptz,
  resolvido_em timestamptz,
  unique (workspace_id, chave)
);
create index if not exists alertas_ws_ix on public.alertas (workspace_id, criado_em desc);

create table if not exists public.resumos_diarios (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  dia date not null,
  fatos jsonb not null,
  texto text not null,
  criado_em timestamptz not null default now(),
  avisado_em timestamptz,
  primary key (workspace_id, dia)
);

-- endereço e senha que o agendador usa para chamar a edge function "avisos" (ninguém do sistema lê; só o banco e a função)
create table if not exists public.sistema_config (chave text primary key, valor text not null);
alter table public.sistema_config enable row level security;
revoke all on public.sistema_config from public, anon, authenticated;
insert into public.sistema_config (chave, valor) values ('avisos_token', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')) on conflict (chave) do nothing;

alter table public.alertas_config enable row level security;
alter table public.alertas enable row level security;
alter table public.resumos_diarios enable row level security;
drop policy if exists alertas_config_acesso on public.alertas_config;
create policy alertas_config_acesso on public.alertas_config for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists alertas_ler on public.alertas;
create policy alertas_ler on public.alertas for select to authenticated using (pertence_ao_workspace(workspace_id));
drop policy if exists alertas_marcar on public.alertas;
create policy alertas_marcar on public.alertas for update to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists resumos_ler on public.resumos_diarios;
create policy resumos_ler on public.resumos_diarios for select to authenticated using (pertence_ao_workspace(workspace_id));

grant select, insert, update on public.alertas_config to authenticated;
grant select, update on public.alertas to authenticated;
grant select on public.resumos_diarios to authenticated;
revoke all on public.alertas_config, public.alertas, public.resumos_diarios from anon;

-- notificações: novos tipos (alerta, resumo) usam a mesma fila
alter table public.notificacoes drop constraint if exists notificacoes_tipo_check;

-- ---------- formatação em português ----------
create or replace function public.growths_brl(v numeric) returns text language sql immutable as $$
  select case when v is null then '—' else (case when v < 0 then '-' else '' end) || 'R$ ' ||
    replace(replace(replace(to_char(abs(round(v, 2)), 'FM999,999,999,990.00'), ',', '#'), '.', ','), '#', '.') end;
$$;
create or replace function public.growths_num(v numeric, casas int default 0) returns text language sql immutable as $$
  select case when v is null then '—' else
    replace(replace(replace(case when casas = 0 then to_char(round(v), 'FM999,999,999,990') else rtrim(rtrim(to_char(round(v, casas), 'FM999,999,999,990.' || repeat('0', casas)), '0'), '.') end, ',', '#'), '.', ','), '#', '.') end;
$$;
create or replace function public.growths_dia_semana(d date) returns text language sql immutable as $$
  select (array['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'])[extract(dow from d)::int + 1];
$$;

-- ---------- série diária ----------
create or replace function public.growths_serie(p_ws uuid, p_ini date, p_fim date)
returns table (dia date, leads int, qualificados int, vendas int, receita numeric, reembolsos int, valor_reembolsado numeric,
               investimento numeric, impressoes bigint, cliques bigint, leads_midia bigint, respostas int, abandonos int)
language plpgsql stable set search_path = public as $$
#variable_conflict use_column
declare tz text := 'America/Sao_Paulo'; t0 timestamptz; t1 timestamptz;
begin
  if auth.uid() is not null and not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 400 then raise exception 'Período inválido'; end if;
  t0 := p_ini::timestamp at time zone tz; t1 := (p_fim + 1)::timestamp at time zone tz;
  return query
  with d as (select g::date as dia from generate_series(p_ini, p_fim, interval '1 day') g),
  l as (select (criado_em at time zone tz)::date dd, count(*)::int n, count(*) filter (where qualificacao = 'qualificado')::int q
        from pessoas where workspace_id = p_ws and criado_em >= t0 and criado_em < t1 group by 1),
  v as (select (data_venda at time zone tz)::date dd, count(*)::int n, sum(valor_bruto) r
        from vendas where workspace_id = p_ws and status = 'aprovada' and data_venda >= t0 and data_venda < t1 group by 1),
  rb as (select (reembolsada_em at time zone tz)::date dd, count(*)::int n, sum(valor_bruto) r
        from vendas where workspace_id = p_ws and reembolsada_em >= t0 and reembolsada_em < t1 group by 1),
  m as (select data dd, sum(custo) c, sum(impressoes)::bigint im, sum(cliques)::bigint cl, sum(leads)::bigint ld
        from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim group by 1),
  pr as (select (respondida_em at time zone tz)::date dd, count(*)::int n
        from pesquisa_respostas where workspace_id = p_ws and respondida_em >= t0 and respondida_em < t1 group by 1),
  ab as (select (abandonado_em at time zone tz)::date dd, count(*)::int n
        from checkout_abandonos where workspace_id = p_ws and abandonado_em >= t0 and abandonado_em < t1 group by 1)
  select d.dia, coalesce(l.n, 0), coalesce(l.q, 0), coalesce(v.n, 0), round(coalesce(v.r, 0), 2), coalesce(rb.n, 0), round(coalesce(rb.r, 0), 2),
         round(coalesce(m.c, 0), 2), coalesce(m.im, 0), coalesce(m.cl, 0), coalesce(m.ld, 0), coalesce(pr.n, 0), coalesce(ab.n, 0)
  from d left join l on l.dd = d.dia left join v on v.dd = d.dia left join rb on rb.dd = d.dia left join m on m.dd = d.dia
       left join pr on pr.dd = d.dia left join ab on ab.dd = d.dia
  order by d.dia;
end $$;

-- ---------- os fatos de um dia ----------
create or replace function public.growths_fatos_dia(p_ws uuid, p_dia date)
returns jsonb language plpgsql stable set search_path = public as $$
declare tz text := 'America/Sao_Paulo'; hoje date := (now() at time zone tz)::date; s record; b record; sem record;
        t0 timestamptz := p_dia::timestamp at time zone tz; t1 timestamptz := (p_dia + 1)::timestamp at time zone tz;
        r jsonb; var jsonb := '{}'::jsonb; k text;
begin
  if auth.uid() is not null and not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  select * into s from growths_serie(p_ws, p_dia, p_dia);
  select avg(leads) leads, avg(vendas) vendas, avg(receita) receita, avg(investimento) investimento,
         sum(investimento) / nullif(sum(leads_midia), 0) cpl
    into b from growths_serie(p_ws, p_dia - 7, p_dia - 1);
  select * into sem from growths_serie(p_ws, p_dia - 7, p_dia - 7);
  foreach k in array array['leads', 'vendas', 'receita', 'investimento'] loop
    var := var || jsonb_build_object(k, case when (to_jsonb(b) ->> k)::numeric > 0 then round(((to_jsonb(s) ->> k)::numeric / (to_jsonb(b) ->> k)::numeric - 1) * 100, 1) end);
  end loop;
  r := jsonb_build_object(
    'data', p_dia, 'dia_semana', growths_dia_semana(p_dia), 'parcial', p_dia >= hoje,
    'leads', s.leads, 'qualificados', s.qualificados,
    'leads_por_origem', coalesce((select jsonb_agg(x order by (x ->> 'leads')::int desc) from (
        select jsonb_build_object('origem', coalesce(nullif(canal_origem, ''), 'sem origem'), 'leads', count(*)) x
        from pessoas where workspace_id = p_ws and criado_em >= t0 and criado_em < t1 group by canal_origem order by count(*) desc limit 5) z), '[]'::jsonb),
    'vendas', s.vendas, 'receita', s.receita, 'ticket_medio', case when s.vendas > 0 then round(s.receita / s.vendas, 2) end,
    'vendas_por_produto', coalesce((select jsonb_agg(x order by (x ->> 'receita')::numeric desc) from (
        select jsonb_build_object('produto', coalesce(pr.nome, 'sem produto'), 'vendas', count(*), 'receita', round(sum(v.valor_bruto), 2)) x
        from vendas v left join produtos pr on pr.id = v.produto_id
        where v.workspace_id = p_ws and v.status = 'aprovada' and v.data_venda >= t0 and v.data_venda < t1 group by pr.nome order by sum(v.valor_bruto) desc limit 5) z), '[]'::jsonb),
    'reembolsos', s.reembolsos, 'valor_reembolsado', s.valor_reembolsado,
    'midia', jsonb_build_object('investimento', s.investimento, 'impressoes', s.impressoes, 'cliques', s.cliques, 'leads', s.leads_midia,
        'ctr_pct', case when s.impressoes > 0 then round(s.cliques::numeric / s.impressoes * 100, 2) end,
        'cpc', case when s.cliques > 0 then round(s.investimento / s.cliques, 2) end,
        'cpl', case when s.leads_midia > 0 then round(s.investimento / s.leads_midia, 2) end),
    'midia_por_canal', coalesce((select jsonb_agg(x order by (x ->> 'investimento')::numeric desc) from (
        select jsonb_build_object('canal', coalesce(canal, 'sem canal'), 'investimento', round(sum(custo), 2), 'leads', sum(leads),
               'cpl', case when sum(leads) > 0 then round(sum(custo) / sum(leads), 2) end) x
        from v_trafego_anuncio_dia where workspace_id = p_ws and data = p_dia group by canal having sum(custo) > 0 order by sum(custo) desc limit 5) z), '[]'::jsonb),
    'respostas_formularios', s.respostas, 'abandonos_checkout', s.abandonos,
    'financeiro', (select jsonb_build_object(
        'recebido', (select round(coalesce(sum(valor), 0), 2) from contas_receber where workspace_id = p_ws and status = 'recebido' and data_recebimento = p_dia),
        'pago', (select round(coalesce(sum(valor), 0), 2) from contas_pagar where workspace_id = p_ws and status = 'pago' and data_pagamento = p_dia),
        'contas_vencidas_qtd', (select count(*) from contas_pagar where workspace_id = p_ws and status = 'previsto' and substituida_por is null and vencimento < p_dia),
        'contas_vencidas_valor', (select round(coalesce(sum(valor), 0), 2) from contas_pagar where workspace_id = p_ws and status = 'previsto' and substituida_por is null and vencimento < p_dia),
        'vencem_no_dia_qtd', (select count(*) from contas_pagar where workspace_id = p_ws and status = 'previsto' and substituida_por is null and vencimento = p_dia),
        'vencem_no_dia_valor', (select round(coalesce(sum(valor), 0), 2) from contas_pagar where workspace_id = p_ws and status = 'previsto' and substituida_por is null and vencimento = p_dia))),
    'comparacao', jsonb_build_object(
        'media_7_dias_anteriores', jsonb_build_object('leads', round(b.leads, 1), 'vendas', round(b.vendas, 1), 'receita', round(b.receita, 2), 'investimento', round(b.investimento, 2), 'cpl', round(b.cpl, 2)),
        'variacao_vs_media_pct', var,
        'mesmo_dia_semana_passada', jsonb_build_object('data', p_dia - 7, 'leads', sem.leads, 'vendas', sem.vendas, 'receita', sem.receita, 'investimento', sem.investimento)),
    'alertas_do_dia', coalesce((select jsonb_agg(jsonb_build_object('titulo', titulo, 'severidade', severidade) order by criado_em) from alertas where workspace_id = p_ws and dia = p_dia), '[]'::jsonb));
  return r;
end $$;

-- ---------- quem recebe e a fila de avisos ----------
create or replace function public.growths_avisar(p_ws uuid, p_tipo text, p_titulo text, p_msg text) returns int
language plpgsql security definer set search_path = public as $$
declare c alertas_config; e record; n int := 0;
begin
  select * into c from alertas_config where workspace_id = p_ws;
  for e in select * from equipe where workspace_id = p_ws and ativo
           and (case when c.workspace_id is not null and cardinality(c.destinatarios) > 0 then id = any (c.destinatarios) else coalesce(acesso_ativo, false) end) loop
    if e.avisar_app then
      insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem, status, enviada_em) values (p_ws, e.id, p_tipo, 'app', left(p_titulo, 200), left(p_msg, 3000), 'enviada', now()); n := n + 1;
    end if;
    if e.avisar_email and nullif(trim(e.email), '') is not null then
      insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem) values (p_ws, e.id, p_tipo, 'email', left(p_titulo, 200), left(p_msg, 3000)); n := n + 1;
    end if;
    if e.avisar_whatsapp and nullif(trim(e.telefone), '') is not null then
      insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem) values (p_ws, e.id, p_tipo, 'whatsapp', left(p_titulo, 200), left(p_msg, 1000)); n := n + 1;
    end if;
  end loop;
  return n;
end $$;
revoke all on function public.growths_avisar(uuid, text, text, text) from public, anon, authenticated;

-- ---------- regras de alerta ----------
-- o mesmo problema que continua não vira um aviso por dia: só volta a avisar depois de alguns dias
create or replace function public.growths_alerta_recente(p_ws uuid, p_regra text, p_desde date, p_campanha uuid default null) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from alertas where workspace_id = p_ws and regra = p_regra and dia > p_desde
                 and (p_campanha is null or dados ->> 'campanha_id' = p_campanha::text));
$$;
create or replace function public.growths_verificar_alertas(p_ws uuid, p_ref timestamptz default now(), p_avisar boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare tz text := 'America/Sao_Paulo'; hoje date := (p_ref at time zone tz)::date; ontem date := hoje - 1;
        c alertas_config; R jsonb; pct numeric; dsv numeric; nseg int; gsl numeric; desl text[];
        ser record; met record; x numeric; mu numeric; sd numeric; dias_com int; novo int := 0; titulos text[] := '{}';
        cp record; v_txt text; v_id uuid; q record; i int; ok boolean; vals numeric[]; vazio boolean;
begin
  if auth.uid() is not null and not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  select * into c from alertas_config where workspace_id = p_ws;
  R := coalesce(c.regras, '{}'::jsonb);
  pct := coalesce((R ->> 'variacao_pct')::numeric, 40); dsv := coalesce((R ->> 'desvios')::numeric, 2);
  nseg := greatest(2, coalesce((R ->> 'dias_seguidos')::int, 3)); gsl := coalesce((R ->> 'gasto_sem_lead')::numeric, 100);
  desl := coalesce(array(select jsonb_array_elements_text(R -> 'desligadas')), '{}');

  create temp table if not exists _gs (dia date, leads numeric, vendas numeric, receita numeric, investimento numeric, cpl numeric, ctr numeric, leads_midia numeric, impressoes numeric, reembolsos numeric, valor_reembolsado numeric) on commit drop;
  truncate _gs;
  insert into _gs select s.dia, s.leads, s.vendas, s.receita, s.investimento,
    case when s.leads_midia > 0 then round(s.investimento / s.leads_midia, 2) end,
    case when s.impressoes > 0 then round(s.cliques::numeric / s.impressoes * 100, 2) end, s.leads_midia, s.impressoes, s.reembolsos, s.valor_reembolsado
  from growths_serie(p_ws, ontem - 14, hoje) s;

  -- 0) ontem sem nenhum lead, venda nem investimento, num negócio que tinha movimento: quase sempre é dado que não chegou
  --    (integração ou importação parada). Vira um alerta só, no lugar de vários "caiu 100%".
  vazio := exists (select 1 from _gs where dia = ontem and leads = 0 and vendas = 0 and investimento = 0)
           and ((select avg(leads) from _gs where dia between ontem - 14 and ontem - 1) >= 3 or (select avg(vendas) from _gs where dia between ontem - 14 and ontem - 1) >= 1
                or (select avg(investimento) from _gs where dia between ontem - 14 and ontem - 1) >= 50);
  if vazio and not ('sem_dados' = any (desl)) and not growths_alerta_recente(p_ws, 'sem_dados', ontem - 3) then
    insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
    values (p_ws, 'sem_dados:' || ontem, 'operacional', 'sem_dados', 'alta', 'Nenhum dado de ontem chegou',
      'Em ' || to_char(ontem, 'DD/MM') || ' (' || growths_dia_semana(ontem) || ') não há nenhum lead, venda nem investimento em mídia registrado, e nos 14 dias anteriores havia movimento. Confira se as integrações e importações (plataforma de vendas, formulários, Meta e Google) rodaram.',
      '{}'::jsonb, ontem)
    on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
    if found then novo := novo + 1; titulos := titulos || v_txt; end if;
  end if;

  -- 1) brusco: ontem fora do normal dos 14 dias anteriores
  if not ('brusco' = any (desl)) and not vazio then
    for met in select * from (values ('leads', 'Leads', 3::numeric, 1, true), ('vendas', 'Vendas', 1, 1, true), ('receita', 'Receita', 100, 1, false), ('investimento', 'Investimento em mídia', 50, 0, false),
                                     ('cpl', 'Custo por lead', 1, -1, false), ('ctr', 'CTR', 0.1, 1, false)) t(k, rot, minimo, sentido, plural) loop
      execute format('select %I from _gs where dia = $1', met.k) into x using ontem;
      execute format('select avg(%I), stddev_pop(%I), count(*) filter (where coalesce(%I, 0) > 0) from _gs where dia between $1 and $2', met.k, met.k, met.k) into mu, sd, dias_com using ontem - 14, ontem - 1;
      continue when x is null or mu is null or dias_com < 7 or mu < met.minimo;
      -- mídia zerada no dia quase sempre é dado que ainda não chegou: não alerta queda de mídia sem investimento
      continue when met.k in ('investimento', 'cpl', 'ctr') and coalesce((select investimento from _gs where dia = ontem), 0) = 0;
      if met.k = 'cpl' and (select avg(leads_midia) from _gs where dia between ontem - 14 and ontem - 1) < 3 then continue; end if;
      if met.k = 'ctr' and (select avg(impressoes) from _gs where dia between ontem - 14 and ontem - 1) < 500 then continue; end if;
      continue when abs(x - mu) < greatest(dsv * coalesce(sd, 0), mu * pct / 100);
      -- mesma métrica indo para o mesmo lado nos últimos 3 dias: já avisou
      continue when exists (select 1 from alertas where workspace_id = p_ws and regra = 'brusco_' || met.k and dia > ontem - 3 and dia < ontem
                            and sign((dados ->> 'variacao_pct')::numeric) = sign(x - mu));
      ok := (x > mu) = (met.sentido = 1);  -- true = mudou para melhor
      v_txt := case when met.k in ('receita', 'investimento', 'cpl') then growths_brl(x) when met.k = 'ctr' then growths_num(x, 2) || '%' else growths_num(x) end;
      insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
      values (p_ws, 'brusco:' || met.k || ':' || ontem, 'brusco', 'brusco_' || met.k,
        case when met.sentido = 0 then 'media' when ok then 'info' else 'alta' end,
        met.rot || case when x > mu then case when met.plural then ' subiram ' else ' subiu ' end else case when met.plural then ' caíram ' else ' caiu ' end end || growths_num(abs(x / mu - 1) * 100) || '% ontem',
        met.rot || ' em ' || to_char(ontem, 'DD/MM') || ' (' || growths_dia_semana(ontem) || '): ' || v_txt || '. A média dos 14 dias anteriores é ' ||
          case when met.k in ('receita', 'investimento', 'cpl') then growths_brl(mu) when met.k = 'ctr' then growths_num(mu, 2) || '%' else growths_num(mu, 1) end || '.' ||
          case when not ok and met.sentido <> 0 then case met.k when 'leads' then ' Vale olhar a mídia e as páginas de captura.' when 'vendas' then ' Vale olhar o checkout e o comercial.' when 'receita' then ' Vale olhar as vendas e os reembolsos.' when 'cpl' then ' Vale olhar os criativos e a segmentação.' when 'ctr' then ' Os anúncios podem estar cansando.' else '' end else '' end,
        jsonb_build_object('valor', x, 'media', round(mu, 2), 'desvio', round(coalesce(sd, 0), 2), 'variacao_pct', round((x / mu - 1) * 100, 1)), ontem)
      on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
      if found then novo := novo + 1; titulos := titulos || v_txt; end if;
    end loop;
  end if;

  -- 2) repetido
  if not ('queda_seguida' = any (desl)) and not vazio then
    select array_agg(leads order by dia) into vals from _gs where dia between ontem - nseg and ontem;
    ok := cardinality(vals) = nseg + 1 and vals[1] >= 3;
    if ok then for i in 2 .. cardinality(vals) loop if not (vals[i] < vals[i - 1]) then ok := false; end if; end loop; end if;
    if ok and vals[cardinality(vals)] <= vals[1] * 0.7 and not growths_alerta_recente(p_ws, 'queda_seguida', ontem - nseg) then
      insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
      values (p_ws, 'queda_seguida:leads:' || ontem, 'repetido', 'queda_seguida', 'alta', 'Leads caindo há ' || nseg || ' dias seguidos',
        'Leads por dia de ' || to_char(ontem - nseg, 'DD/MM') || ' a ' || to_char(ontem, 'DD/MM') || ': ' || array_to_string(array(select growths_num(u) from unnest(vals) u), ' → ') || '.',
        jsonb_build_object('valores', to_jsonb(vals)), ontem)
      on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
      if found then novo := novo + 1; titulos := titulos || v_txt; end if;
    end if;
  end if;
  if not ('sem_vendas' = any (desl)) and not growths_alerta_recente(p_ws, 'sem_vendas', ontem - nseg) and (select avg(vendas) from _gs where dia between ontem - 14 and ontem - nseg) >= 0.5
     and not exists (select 1 from _gs where dia between ontem - nseg + 1 and ontem and vendas > 0) then
    insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
    values (p_ws, 'sem_vendas:' || ontem, 'repetido', 'sem_vendas', 'alta', 'Nenhuma venda há ' || nseg || ' dias',
      'De ' || to_char(ontem - nseg + 1, 'DD/MM') || ' a ' || to_char(ontem, 'DD/MM') || ' não entrou venda aprovada; antes disso a média era de ' ||
      growths_num((select avg(vendas) from _gs where dia between ontem - 14 and ontem - nseg), 1) || ' por dia.', '{}'::jsonb, ontem)
    on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
    if found then novo := novo + 1; titulos := titulos || v_txt; end if;
  end if;
  if not ('reembolsos' = any (desl)) and not growths_alerta_recente(p_ws, 'reembolsos', ontem - 3) and (select sum(reembolsos) from _gs where dia between ontem - 2 and ontem) >= 3
     and (select count(*) from _gs where dia between ontem - 2 and ontem and reembolsos > 0) >= 2 then
    insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
    values (p_ws, 'reembolsos:' || ontem, 'repetido', 'reembolsos', 'alta', 'Reembolsos se repetindo',
      growths_num((select sum(reembolsos) from _gs where dia between ontem - 2 and ontem)) || ' reembolsos nos últimos 3 dias (' ||
      growths_brl((select sum(valor_reembolsado) from _gs where dia between ontem - 2 and ontem)) || '). Vale ver o produto e o que foi prometido na venda.', '{}'::jsonb, ontem)
    on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
    if found then novo := novo + 1; titulos := titulos || v_txt; end if;
  end if;
  if not ('cpl_meta' = any (desl)) then
    for cp in select ca.id, ca.nome, ca.meta_cpl from campanhas ca where ca.workspace_id = p_ws and ca.meta_cpl > 0 and coalesce(ca.status, 'ativa') = 'ativa' loop
      select array_agg(case when ld > 0 then round(cu / ld, 2) end order by dd), count(*) filter (where cu > 0 and (ld = 0 or cu / ld > cp.meta_cpl))
        into vals, i
      from (select g::date dd, coalesce(sum(t.custo), 0) cu, coalesce(sum(t.leads), 0) ld from generate_series(ontem - nseg + 1, ontem, interval '1 day') g
            left join v_trafego_anuncio_dia t on t.workspace_id = p_ws and t.campanha_id = cp.id and t.data = g::date group by 1) z;
      continue when i < nseg or growths_alerta_recente(p_ws, 'cpl_meta', ontem - nseg, cp.id);
      insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
      values (p_ws, 'cpl_meta:' || cp.id || ':' || ontem, 'repetido', 'cpl_meta', 'alta', 'CPL acima da meta há ' || nseg || ' dias: ' || left(cp.nome, 60),
        'Meta de custo por lead: ' || growths_brl(cp.meta_cpl) || '. Últimos ' || nseg || ' dias: ' ||
        array_to_string(array(select coalesce(growths_brl(u), 'sem lead') from unnest(vals) u), ' → ') || '.', jsonb_build_object('campanha_id', cp.id), ontem)
      on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
      if found then novo := novo + 1; titulos := titulos || v_txt; end if;
    end loop;
  end if;

  -- 3) pede ação: gasto sem lead (ontem e hoje), contas vencidas, saldo abaixo do mínimo
  if not ('gasto_sem_lead' = any (desl)) then
    for q in select dia, investimento, leads_midia from _gs where dia in (ontem, hoje) and investimento >= gsl and leads_midia = 0 loop
      insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
      values (p_ws, 'gasto_sem_lead:' || q.dia, 'operacional', 'gasto_sem_lead', 'alta', 'Mídia gastando sem trazer lead' || case when q.dia = hoje then ' hoje' else ' ontem' end,
        growths_brl(q.investimento) || ' investidos em ' || to_char(q.dia, 'DD/MM') || ' e nenhum lead registrado pelos anúncios. Confira o formulário, a página e o pixel.', '{}'::jsonb, q.dia)
      on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
      if found then novo := novo + 1; titulos := titulos || v_txt; end if;
    end loop;
  end if;
  if not ('contas_vencidas' = any (desl)) then
    select count(*) n, sum(valor) v into q from contas_pagar where workspace_id = p_ws and status = 'previsto' and substituida_por is null and vencimento < hoje;
    if q.n > 0 and not growths_alerta_recente(p_ws, 'contas_vencidas', hoje - 7) then
      insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
      values (p_ws, 'contas_vencidas:' || hoje, 'operacional', 'contas_vencidas', 'media', growths_num(q.n) || ' conta(s) a pagar vencida(s)',
        growths_num(q.n) || ' conta(s) a pagar com vencimento antes de hoje ainda em aberto, somando ' || growths_brl(q.v) || '.', jsonb_build_object('qtd', q.n, 'valor', q.v), hoje)
      on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
      if found then novo := novo + 1; titulos := titulos || v_txt; end if;
    end if;
  end if;
  if not ('saldo_minimo' = any (desl)) then
    select (to_jsonb(e) ->> 'saldo_minimo')::numeric into x from empresa e where e.workspace_id = p_ws;
    if x is not null and x > 0 then
      select sum(saldo_atual) into mu from v_saldo_contas_bancarias where workspace_id = p_ws;
      if mu is not null and mu < x and not growths_alerta_recente(p_ws, 'saldo_minimo', hoje - 3) then
        insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
        values (p_ws, 'saldo_minimo:' || hoje, 'operacional', 'saldo_minimo', 'alta', 'Caixa abaixo do saldo mínimo',
          'Saldo somado das contas: ' || growths_brl(mu) || '. Saldo mínimo definido: ' || growths_brl(x) || '.', jsonb_build_object('saldo', mu, 'minimo', x), hoje)
        on conflict (workspace_id, chave) do nothing returning titulo into v_txt;
        if found then novo := novo + 1; titulos := titulos || v_txt; end if;
      end if;
    end if;
  end if;

  if novo > 0 and p_avisar then
    perform growths_avisar(p_ws, 'alerta', case when novo = 1 then 'Alerta: ' || titulos[1] else novo || ' alertas novos no Growths' end,
      case when novo = 1 then (select mensagem from alertas where workspace_id = p_ws and titulo = titulos[1] order by criado_em desc limit 1)
           else array_to_string(array(select '- ' || t from unnest(titulos) t), E'\n') end || E'\n\nVeja em Growth → Alertas e resumo.');
  end if;
  return jsonb_build_object('novos', novo, 'titulos', to_jsonb(titulos));
end $$;
revoke all on function public.growths_verificar_alertas(uuid, timestamptz, boolean) from public, anon;
grant execute on function public.growths_verificar_alertas(uuid, timestamptz, boolean) to authenticated;

-- ---------- resumo do dia em texto ----------
create or replace function public.growths_resumo_texto(f jsonb) returns text language plpgsql immutable as $$
declare m jsonb := f -> 'comparacao' -> 'media_7_dias_anteriores'; v jsonb := f -> 'comparacao' -> 'variacao_vs_media_pct'; t text; fin jsonb := f -> 'financeiro';
  pv text := ''; al text;
begin
  t := 'Resumo de ' || (f ->> 'dia_semana') || ', ' || to_char((f ->> 'data')::date, 'DD/MM') || case when (f ->> 'parcial')::boolean then ' (até agora)' else '' end || E'\n';
  t := t || '- Leads: ' || growths_num((f ->> 'leads')::numeric) || case when (f ->> 'qualificados')::int > 0 then ' (' || growths_num((f ->> 'qualificados')::numeric) || ' qualificados)' else '' end
    || coalesce(' · média dos 7 dias anteriores: ' || growths_num((m ->> 'leads')::numeric, 1) || coalesce(' (' || case when (v ->> 'leads')::numeric >= 0 then '+' else '' end || growths_num((v ->> 'leads')::numeric) || '%)', ''), '') || E'\n';
  t := t || '- Vendas: ' || growths_num((f ->> 'vendas')::numeric) || ', receita ' || growths_brl((f ->> 'receita')::numeric)
    || coalesce(' · média: ' || growths_num((m ->> 'vendas')::numeric, 1) || ' vendas, ' || growths_brl((m ->> 'receita')::numeric), '') || E'\n';
  if jsonb_array_length(f -> 'vendas_por_produto') > 0 then
    t := t || '- Mais vendido: ' || (f -> 'vendas_por_produto' -> 0 ->> 'produto') || ' (' || growths_num((f -> 'vendas_por_produto' -> 0 ->> 'vendas')::numeric) || ', ' || growths_brl((f -> 'vendas_por_produto' -> 0 ->> 'receita')::numeric) || ')' || E'\n';
  end if;
  if (f -> 'midia' ->> 'investimento')::numeric > 0 then
    t := t || '- Mídia: ' || growths_brl((f -> 'midia' ->> 'investimento')::numeric) || ' investidos' || coalesce(', CPL ' || growths_brl((f -> 'midia' ->> 'cpl')::numeric), '')
      || coalesce(', CTR ' || growths_num((f -> 'midia' ->> 'ctr_pct')::numeric, 2) || '%', '') || E'\n';
  end if;
  if (f ->> 'reembolsos')::int > 0 then t := t || '- Reembolsos: ' || growths_num((f ->> 'reembolsos')::numeric) || ' (' || growths_brl((f ->> 'valor_reembolsado')::numeric) || ')' || E'\n'; end if;
  if (f ->> 'abandonos_checkout')::int > 0 then t := t || '- Abandonos de checkout: ' || growths_num((f ->> 'abandonos_checkout')::numeric) || E'\n'; end if;
  if (f ->> 'respostas_formularios')::int > 0 then t := t || '- Respostas de formulários: ' || growths_num((f ->> 'respostas_formularios')::numeric) || E'\n'; end if;
  if (fin ->> 'recebido')::numeric > 0 or (fin ->> 'pago')::numeric > 0 then t := t || '- Caixa: recebido ' || growths_brl((fin ->> 'recebido')::numeric) || ', pago ' || growths_brl((fin ->> 'pago')::numeric) || E'\n'; end if;
  if (fin ->> 'contas_vencidas_qtd')::int > 0 then t := t || '- Contas a pagar vencidas: ' || (fin ->> 'contas_vencidas_qtd') || ' (' || growths_brl((fin ->> 'contas_vencidas_valor')::numeric) || ')' || E'\n'; end if;
  select string_agg(x ->> 'titulo', '; ') into al from jsonb_array_elements(f -> 'alertas_do_dia') x;
  if al is not null then t := t || '- Alertas: ' || al || E'\n'; end if;
  return rtrim(t, E'\n');
end $$;

create or replace function public.growths_resumo_gerar(p_ws uuid, p_dia date default null, p_avisar boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d date := coalesce(p_dia, (now() at time zone 'America/Sao_Paulo')::date - 1); f jsonb; t text; ja timestamptz;
begin
  if auth.uid() is not null and not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  f := growths_fatos_dia(p_ws, d); t := growths_resumo_texto(f);
  insert into resumos_diarios (workspace_id, dia, fatos, texto) values (p_ws, d, f, t)
  on conflict (workspace_id, dia) do update set fatos = excluded.fatos, texto = excluded.texto, criado_em = now();
  select avisado_em into ja from resumos_diarios where workspace_id = p_ws and dia = d;
  if p_avisar and ja is null then
    perform growths_avisar(p_ws, 'resumo', 'Resumo de ' || growths_dia_semana(d) || ', ' || to_char(d, 'DD/MM'), t);
    update resumos_diarios set avisado_em = now() where workspace_id = p_ws and dia = d;
  end if;
  return jsonb_build_object('fatos', f, 'texto', t);
end $$;
revoke all on function public.growths_resumo_gerar(uuid, date, boolean) from public, anon;
grant execute on function public.growths_resumo_gerar(uuid, date, boolean) to authenticated;

-- ---------- o que a IA enxerga a mais (para "como foi ontem?") ----------
create or replace function public.growths_ia_extra(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable set search_path = public as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date; i date := greatest(p_ini, least(p_fim, hoje) - 59); f date := least(p_fim, hoje);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  return jsonb_build_object(
    'hoje', growths_fatos_dia(p_ws, hoje), 'ontem', growths_fatos_dia(p_ws, hoje - 1),
    'serie_diaria', case when i <= f then (select jsonb_agg(jsonb_build_object('data', dia, 'dia_semana', growths_dia_semana(dia), 'leads', leads, 'qualificados', qualificados, 'vendas', vendas,
        'receita', receita, 'reembolsos', reembolsos, 'investimento', investimento, 'cpl', case when leads_midia > 0 then round(investimento / leads_midia, 2) end) order by dia)
      from growths_serie(p_ws, i, f)) else '[]'::jsonb end,
    'alertas_abertos', coalesce((select jsonb_agg(jsonb_build_object('data', dia, 'titulo', titulo, 'detalhe', mensagem, 'severidade', severidade) order by criado_em desc)
      from (select * from alertas where workspace_id = p_ws and resolvido_em is null order by criado_em desc limit 15) a), '[]'::jsonb));
end $$;
revoke all on function public.growths_ia_extra(uuid, date, date) from public, anon;
grant execute on function public.growths_ia_extra(uuid, date, date) to authenticated;
grant execute on function public.growths_serie(uuid, date, date), public.growths_fatos_dia(uuid, date) to authenticated;
revoke all on function public.growths_serie(uuid, date, date), public.growths_fatos_dia(uuid, date) from anon;

-- ---------- aviso de teste para quem está logado (sai nos canais ligados para a pessoa em Equipe) ----------
create or replace function public.growths_aviso_teste(p_ws uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e equipe; n int := 0;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  select * into e from equipe where workspace_id = p_ws and ativo and (user_id = auth.uid() or lower(email) = lower(auth.jwt() ->> 'email')) order by (user_id = auth.uid()) desc nulls last limit 1;
  if not found then raise exception 'Seu login não está na Equipe deste cliente. Cadastre seu e-mail em Equipe para receber avisos.'; end if;
  if e.avisar_app then insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem, status, enviada_em) values (p_ws, e.id, 'teste', 'app', 'Aviso de teste', 'Se você está lendo isto no sino, os avisos do Growths chegam para você.', 'enviada', now()); n := n + 1; end if;
  if e.avisar_email and nullif(trim(e.email), '') is not null then insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem) values (p_ws, e.id, 'teste', 'email', 'Aviso de teste do Growths', 'Se você recebeu este e-mail, os alertas e o resumo do dia vão chegar por aqui.'); n := n + 1; end if;
  if e.avisar_whatsapp and nullif(trim(e.telefone), '') is not null then insert into notificacoes (workspace_id, destinatario_id, tipo, canal, titulo, mensagem) values (p_ws, e.id, 'teste', 'whatsapp', 'Aviso de teste do Growths', 'Se você recebeu esta mensagem, os alertas vão chegar pelo WhatsApp.'); n := n + 1; end if;
  return jsonb_build_object('nome', e.nome, 'app', e.avisar_app, 'email', e.avisar_email and nullif(trim(e.email), '') is not null, 'whatsapp', e.avisar_whatsapp and nullif(trim(e.telefone), '') is not null, 'criados', n);
end $$;
revoke all on function public.growths_aviso_teste(uuid) from public, anon;
grant execute on function public.growths_aviso_teste(uuid) to authenticated;

-- ---------- agendador ----------
create or replace function public.growths_rodar_agendado(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record; hora int := extract(hour from (p_ref at time zone 'America/Sao_Paulo'))::int; ontem date := (p_ref at time zone 'America/Sao_Paulo')::date - 1;
        n int := 0; nr int := 0; pend int; url text; tok text;
begin
  for c in select * from alertas_config where ligado loop
    begin
      perform growths_verificar_alertas(c.workspace_id, p_ref, true); n := n + 1;
      if c.resumo_diario and hora >= c.resumo_hora and not exists (select 1 from resumos_diarios where workspace_id = c.workspace_id and dia = ontem and avisado_em is not null) then
        perform growths_resumo_gerar(c.workspace_id, ontem, true); nr := nr + 1;
      end if;
    exception when others then
      raise warning 'growths_rodar_agendado %: %', c.workspace_id, sqlerrm;
    end;
  end loop;
  -- pede o envio de e-mails e WhatsApps que estão na fila
  select count(*) into pend from notificacoes where status = 'pendente' and canal in ('email', 'whatsapp');
  select valor into url from sistema_config where chave = 'avisos_url';
  select valor into tok from sistema_config where chave = 'avisos_token';
  if pend > 0 and url is not null then
    begin
      execute 'select net.http_post(url := $1, body := $2, headers := $3)' using url, '{"acao":"enviar"}'::jsonb, jsonb_build_object('Content-Type', 'application/json', 'x-growths-token', tok);
    exception when others then raise warning 'growths_rodar_agendado: não consegui chamar a função de avisos: %', sqlerrm;
    end;
  end if;
  return jsonb_build_object('clientes', n, 'resumos', nr, 'na_fila', pend);
end $$;
revoke all on function public.growths_rodar_agendado(timestamptz) from public, anon, authenticated;

notify pgrst, 'reload schema';
