-- v0.206 — Importar histórico de vendas (primeira carga) e o histórico na ficha do cliente.
-- As vendas de antes do Growths ficam em vendas_historicas (fora da tabela vendas): contam nas métricas (receita por mês,
-- primeira compra, recompra, ticket, sazonalidade, planejamento anual), mas não geram lançamento, conta a receber, comissão,
-- projeto, jornada nem automação. Cada carga é um lote registrado, que pode ser desfeito.
-- Depende de: RODAR_v0.198_plano_anual.sql (a função de sugestões é refeita aqui para somar o histórico).
-- Pode rodar de novo sem erro.

create table if not exists public.importacoes_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  tipo text not null default 'vendas' check (tipo in ('vendas')),
  plataforma text not null,
  arquivo text,
  hash text,
  linhas int not null default 0,
  vendas int not null default 0,
  pessoas_novas int not null default 0,
  ignoradas int not null default 0,
  valor_aprovado numeric(14,2) not null default 0,
  periodo_ini date,
  periodo_fim date,
  pessoas_criadas uuid[] not null default '{}',
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid(),
  desfeito_em timestamptz
);
comment on table public.importacoes_historico is 'v0.206: cada carga de histórico (arquivo de vendas de antes do Growths), com o resumo e as pessoas que ela criou, para desfazer.';

create table if not exists public.vendas_historicas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  lote_id uuid not null references importacoes_historico(id) on delete cascade,
  pessoa_id uuid references pessoas(id) on delete set null,
  produto text,
  plataforma text not null,
  data_venda date not null,
  valor numeric(14,2) not null check (valor >= 0),
  status text not null check (status in ('aprovada', 'reembolsada', 'cancelada', 'chargeback')),
  id_externo text,
  criado_em timestamptz not null default now()
);
comment on table public.vendas_historicas is 'v0.206: vendas de antes do Growths (importadas). Contam nas métricas e no planejamento; não geram financeiro nem automações.';
create index if not exists vendas_historicas_ws_data on public.vendas_historicas (workspace_id, data_venda);
create index if not exists vendas_historicas_pessoa on public.vendas_historicas (pessoa_id);
create unique index if not exists vendas_historicas_ext on public.vendas_historicas (workspace_id, plataforma, id_externo) where id_externo is not null;

alter table public.importacoes_historico enable row level security;
alter table public.vendas_historicas enable row level security;
do $$ declare t text; begin
  foreach t in array array['importacoes_historico', 'vendas_historicas'] loop
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna())', t || '_ver', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop; end $$;

-- todas as vendas, as do Growths e as do histórico, no mesmo formato (dia em Brasília)
create or replace view public.v_vendas_todas with (security_invoker = true) as
  select workspace_id, pessoa_id, (data_venda at time zone 'America/Sao_Paulo')::date as dia, valor_bruto as valor, status, 'growths'::text as origem from vendas
  union all
  select workspace_id, pessoa_id, data_venda, valor, status, 'historico' from vendas_historicas;
grant select on public.v_vendas_todas to authenticated;

-- importar (ou só conferir, com p_simular): p_linhas = [{nome, email, telefone, produto, valor, data (aaaa-mm-dd), status, id_externo}]
create or replace function public.importar_historico_vendas(p_ws uuid, p_plataforma text, p_arquivo text, p_hash text, p_linhas jsonb, p_simular boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare l jsonb; i int := 0; erros text[] := '{}'; lote uuid; pid uuid; em text; tel text; d date; v numeric; st text; ext text;
  n_v int := 0; n_dup int := 0; n_ja int := 0; n_pn int := 0; n_pe int := 0; aprov numeric := 0; d0 date; d1 date; criadas uuid[] := '{}';
  vistos text[] := '{}'; existentes uuid[] := '{}'; chave text; por_mes jsonb := '{}'::jsonb; mk text; st_n jsonb := '{}'::jsonb; emails_novos text[] := '{}';
begin
  if not pode_editar(p_ws, '{adm,vendas}'::text[]) then raise exception 'Sem permissão para importar vendas neste cliente'; end if;
  p_plataforma := nullif(trim(coalesce(p_plataforma, '')), '');
  if p_plataforma is null then return jsonb_build_object('ok', false, 'erros', jsonb_build_array('Escolha a plataforma de onde veio o arquivo.')); end if;
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then return jsonb_build_object('ok', false, 'erros', jsonb_build_array('O arquivo não tem linhas para importar.')); end if;
  if jsonb_array_length(p_linhas) > 50000 then return jsonb_build_object('ok', false, 'erros', jsonb_build_array('Mais de 50 mil linhas: divida o arquivo.')); end if;
  if not p_simular and p_hash is not null and exists (select 1 from importacoes_historico where workspace_id = p_ws and hash = p_hash and desfeito_em is null) then
    return jsonb_build_object('ok', false, 'erros', jsonb_build_array('Este mesmo arquivo já foi importado. Desfaça a carga anterior antes de importar de novo.'));
  end if;
  if not p_simular then
    insert into importacoes_historico (workspace_id, plataforma, arquivo, hash, linhas) values (p_ws, p_plataforma, left(p_arquivo, 200), p_hash, jsonb_array_length(p_linhas)) returning id into lote;
  end if;
  for l in select * from jsonb_array_elements(p_linhas) loop
    i := i + 1;
    begin d := (l->>'data')::date; exception when others then d := null; end;
    begin v := (l->>'valor')::numeric; exception when others then v := null; end;
    st := l->>'status'; ext := nullif(trim(coalesce(l->>'id_externo', '')), '');
    em := nullif(lower(trim(coalesce(l->>'email', ''))), ''); tel := nullif(regexp_replace(coalesce(l->>'telefone', ''), '\D', '', 'g'), '');
    if d is null or v is null or v < 0 or st not in ('aprovada', 'reembolsada', 'cancelada', 'chargeback') or (em is null and tel is null and nullif(trim(coalesce(l->>'nome', '')), '') is null) then
      if array_length(erros, 1) is null or array_length(erros, 1) < 20 then erros := erros || ('Linha ' || i || ': ' || case when d is null then 'data inválida' when v is null or v < 0 then 'valor inválido' when st not in ('aprovada', 'reembolsada', 'cancelada', 'chargeback') then 'status inválido' else 'sem nome, e-mail e telefone' end); end if;
      continue;
    end if;
    if d > (now() at time zone 'America/Sao_Paulo')::date then
      if array_length(erros, 1) is null or array_length(erros, 1) < 20 then erros := erros || ('Linha ' || i || ': data no futuro'); end if; continue;
    end if;
    -- repetida no próprio arquivo ou já importada antes
    chave := coalesce('x' || ext, 'k' || d || '|' || v || '|' || coalesce(em, tel, lower(l->>'nome')));
    if chave = any (vistos) or (ext is not null and exists (select 1 from vendas_historicas where workspace_id = p_ws and plataforma = p_plataforma and id_externo = ext))
       or (ext is null and exists (select 1 from vendas_historicas h left join pessoas p on p.id = h.pessoa_id where h.workspace_id = p_ws and h.plataforma = p_plataforma and h.data_venda = d and h.valor = v and coalesce(p.email, '') = coalesce(em, ''))) then
      n_dup := n_dup + 1; continue;
    end if;
    vistos := vistos || chave;
    -- a pessoa: por e-mail, depois telefone
    pid := null;
    if em is not null then select id into pid from pessoas where workspace_id = p_ws and lower(email) = em limit 1; end if;
    if pid is null and tel is not null then select id into pid from pessoas where workspace_id = p_ws and regexp_replace(coalesce(telefone, ''), '\D', '', 'g') in (tel, '55' || tel, substr(tel, 3)) and length(tel) >= 10 limit 1; end if;
    -- a venda já está no Growths (mesmo ID na plataforma, ou mesma pessoa, dia e valor)
    if (ext is not null and exists (select 1 from vendas where workspace_id = p_ws and id_externo = ext))
       or (pid is not null and exists (select 1 from vendas where workspace_id = p_ws and pessoa_id = pid and (data_venda at time zone 'America/Sao_Paulo')::date = d and valor_bruto = v)) then
      n_ja := n_ja + 1; continue;
    end if;
    if pid is null then
      if em is null or not (em = any (emails_novos)) then n_pn := n_pn + 1; if em is not null then emails_novos := emails_novos || em; end if; end if;
      if not p_simular then
        insert into pessoas (workspace_id, nome, email, telefone, status_funil, status_cliente, canal_origem, criado_em, convertido_em, captada)
        values (p_ws, coalesce(nullif(trim(l->>'nome'), ''), em, tel), em, tel, case when st = 'aprovada' then 'cliente' else 'lead' end, case when st = 'aprovada' then 'inativo' end,
                p_plataforma, (d::timestamp + time '12:00') at time zone 'America/Sao_Paulo', case when st = 'aprovada' then (d::timestamp + time '12:00') at time zone 'America/Sao_Paulo' end, false)
        returning id into pid;
        criadas := criadas || pid;
      end if;
    else
      if not (pid = any (criadas)) and not (pid = any (existentes)) then existentes := existentes || pid; n_pe := n_pe + 1; end if;
      if not p_simular then
        -- quem já existia e comprou antes: a data de cliente vai para a primeira compra
        if st = 'aprovada' then
          update pessoas set status_funil = 'cliente', status_cliente = coalesce(status_cliente, 'inativo'),
            convertido_em = least(coalesce(convertido_em, (d::timestamp + time '12:00') at time zone 'America/Sao_Paulo'), (d::timestamp + time '12:00') at time zone 'America/Sao_Paulo')
          where id = pid and (status_funil <> 'cliente' or convertido_em is null or convertido_em > (d::timestamp + time '12:00') at time zone 'America/Sao_Paulo');
        end if;
      end if;
    end if;
    if not p_simular then
      insert into vendas_historicas (workspace_id, lote_id, pessoa_id, produto, plataforma, data_venda, valor, status, id_externo)
      values (p_ws, lote, pid, nullif(trim(coalesce(l->>'produto', '')), ''), p_plataforma, d, v, st, ext);
    end if;
    n_v := n_v + 1; st_n := jsonb_set(st_n, array[st], to_jsonb(coalesce((st_n->>st)::int, 0) + 1));
    if st = 'aprovada' then aprov := aprov + v; mk := to_char(d, 'YYYY-MM'); por_mes := jsonb_set(por_mes, array[mk], to_jsonb(coalesce((por_mes->>mk)::numeric, 0) + v)); end if;
    d0 := least(coalesce(d0, d), d); d1 := greatest(coalesce(d1, d), d);
  end loop;
  if not p_simular then
    if n_v = 0 then delete from importacoes_historico where id = lote; lote := null;
    else update importacoes_historico set vendas = n_v, pessoas_novas = array_length(criadas, 1), ignoradas = i - n_v, valor_aprovado = aprov, periodo_ini = d0, periodo_fim = d1, pessoas_criadas = criadas where id = lote; end if;
  end if;
  return jsonb_build_object('ok', n_v > 0, 'lote_id', lote, 'erros', to_jsonb(erros), 'resumo', jsonb_build_object('linhas', i, 'vendas', n_v, 'por_status', st_n, 'valor_aprovado', round(aprov, 2),
    'repetidas', n_dup, 'ja_no_growths', n_ja, 'invalidas', i - n_v - n_dup - n_ja, 'pessoas_novas', n_pn, 'pessoas_existentes', n_pe, 'periodo_ini', d0, 'periodo_fim', d1, 'por_mes', por_mes));
end $$;
revoke all on function public.importar_historico_vendas(uuid, text, text, text, jsonb, boolean) from public, anon;
grant execute on function public.importar_historico_vendas(uuid, text, text, text, jsonb, boolean) to authenticated;

-- desfazer uma carga: apaga as vendas do lote e as pessoas que ele criou (se não ganharam outro uso depois)
create or replace function public.desfazer_importacao_historico(p_lote uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare lt importacoes_historico; pid uuid; nv int; np int := 0; nf int := 0;
begin
  select * into lt from importacoes_historico where id = p_lote;
  if not found then raise exception 'Carga não encontrada'; end if;
  if not pode_editar(lt.workspace_id, '{adm,vendas}'::text[]) then raise exception 'Sem permissão para desfazer esta carga'; end if;
  if lt.desfeito_em is not null then raise exception 'Esta carga já foi desfeita'; end if;
  delete from vendas_historicas where lote_id = p_lote; get diagnostics nv = row_count;
  foreach pid in array lt.pessoas_criadas loop
    if exists (select 1 from vendas where pessoa_id = pid) or exists (select 1 from vendas_historicas where pessoa_id = pid) or exists (select 1 from contratos where pessoa_id = pid) or exists (select 1 from alunos where pessoa_id = pid) then nf := nf + 1; continue; end if;
    begin delete from pessoas where id = pid; np := np + 1; exception when others then nf := nf + 1; end;
  end loop;
  update importacoes_historico set desfeito_em = now() where id = p_lote;
  return jsonb_build_object('vendas', nv, 'pessoas', np, 'pessoas_mantidas', nf);
end $$;
revoke all on function public.desfazer_importacao_historico(uuid) from public, anon;
grant execute on function public.desfazer_importacao_historico(uuid) to authenticated;

-- o planejamento anual passa a somar o histórico importado (receita do ano anterior, clientes, recompra, ticket, sazonalidade, realizado)
create or replace function public.plano_anual_sugestoes(p_ws uuid, p_ano int, p_hoje date default null)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare h date := coalesce(p_hoje, (now() at time zone 'America/Sao_Paulo')::date);
  ini12 date; fim12 date; r jsonb := '{}'::jsonb; v numeric; n int; rec12 numeric; ded12 numeric; mrr numeric;
  ativos int; cancel int; comp int; recomp int; saz jsonb; imp12 numeric; var12 numeric;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  fim12 := (date_trunc('month', h) - interval '1 day')::date;             -- último mês fechado
  ini12 := (date_trunc('month', h) - interval '12 months')::date;
  -- receita do ano anterior (vendas aprovadas, valor bruto) e quantos meses têm venda
  select coalesce(sum(valor), 0), count(distinct date_trunc('month', dia)) into v, n
    from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and extract(year from dia) = p_ano - 1;
  r := r || jsonb_build_object('receita_ano_anterior', case when n > 0 then round(v, 2) end, 'receita_ano_anterior_meses', n, 'receita_ano_anterior_base', 'ano');
  -- v0.200: planejando o ano que vem com o ano anterior ainda aberto, a receita é a dos últimos 12 meses fechados
  if p_ano - 1 >= extract(year from h) then
    select coalesce(sum(valor), 0), count(distinct date_trunc('month', dia)) into v, n
      from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between ini12 and fim12;
    r := r || jsonb_build_object('receita_ano_anterior', case when n > 0 then round(v, 2) end, 'receita_ano_anterior_meses', n, 'receita_ano_anterior_base', '12m');
  end if;
  -- DRE dos últimos 12 meses fechados (v0.199): impostos sobre vendas (5.1.02) à parte; custos variáveis = taxas de plataforma e
  -- outras deduções + comissões (6.2.03); custos fixos = despesas sem mídia paga (6.1) e sem comissões
  select coalesce(sum(valor) filter (where tipo = 'receita'), 0), coalesce(sum(valor) filter (where tipo = 'deducao'), 0),
         coalesce(sum(valor) filter (where tipo = 'despesa' and coalesce(codigo, '') not like '6.1%' and coalesce(codigo, '') <> '6.2.03'), 0), count(distinct mes) filter (where tipo = 'receita'),
         coalesce(sum(valor) filter (where tipo = 'deducao' and codigo = '5.1.02'), 0),
         coalesce(sum(valor) filter (where (tipo = 'deducao' and coalesce(codigo, '') <> '5.1.02') or (tipo = 'despesa' and codigo = '6.2.03')), 0)
    into rec12, ded12, v, n, imp12, var12 from v_dre_mensal where workspace_id = p_ws and mes between ini12 and fim12;
  r := r || jsonb_build_object('dre_meses', n, 'dre_de', ini12, 'dre_ate', fim12,
    'margem_contribuicao', case when rec12 > 0 then round((rec12 - ded12) / rec12 * 100, 1) end,
    'custos_variaveis_pct', case when rec12 > 0 then round(var12 / rec12 * 100, 1) end,
    'imposto_hist_pct', case when rec12 > 0 then round(imp12 / rec12 * 100, 1) end,
    'custos_fixos_ano', case when n > 0 then round(v / n * 12, 2) end);
  -- recorrência de hoje (mesma regra do contas a receber) e perda dos últimos 12 meses
  mrr := nullif(((receber_periodo(p_ws, h, h, h)) ->> 'mrr')::numeric, 0);
  select count(*) filter (where cancelado_em is null or (cancelado_em at time zone 'America/Sao_Paulo')::date > h),
         count(*) filter (where cancelado_em is not null and (cancelado_em at time zone 'America/Sao_Paulo')::date between ini12 and h)
    into ativos, cancel from contratos where workspace_id = p_ws and recorrente and ativado_em is not null;
  r := r || jsonb_build_object('mrr', mrr, 'churn_anual', case when coalesce(ativos, 0) + coalesce(cancel, 0) > 0 and mrr is not null then round(cancel::numeric / (ativos + cancel) * 100, 1) end);
  -- clientes, recompra e ticket (vendas aprovadas dos últimos 12 meses)
  select count(distinct pessoa_id), round(avg(valor), 2) into comp, v from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between ini12 and h;
  select count(*) into recomp from (select pessoa_id from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and pessoa_id in
    (select pessoa_id from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between ini12 and h) group by pessoa_id having count(*) > 1) x;
  r := r || jsonb_build_object('clientes_ativos', nullif(comp, 0), 'ticket_medio', v, 'taxa_recompra', case when comp > 0 then round(recomp::numeric / comp * 100, 1) end);
  -- sazonalidade: peso de cada mês na receita dos últimos 12 meses fechados (só com 6 meses ou mais de venda)
  select jsonb_agg(coalesce(p, 0) order by m) into saz from (select m, (select sum(valor) from v_vendas_todas where workspace_id = p_ws and status = 'aprovada'
      and dia between ini12 and fim12 and extract(month from dia) = m) as p from generate_series(1, 12) m) s;
  select count(*) into n from jsonb_array_elements(saz) e where (e #>> '{}')::numeric > 0;
  r := r || jsonb_build_object('sazonalidade', case when n >= 6 then saz end, 'sazonalidade_meses', n);
  -- realizado do ano do plano, mês a mês (vendas aprovadas, valor bruto: a mesma regra das metas mensais)
  select jsonb_agg(coalesce(p, 0) order by m) into saz from (select m, (select sum(valor) from v_vendas_todas where workspace_id = p_ws and status = 'aprovada'
      and extract(year from dia) = p_ano and extract(month from dia) = m) as p from generate_series(1, 12) m) s;
  select count(*), min(data_venda), max(data_venda) into n, ini12, fim12 from vendas_historicas where workspace_id = p_ws;
  r := r || jsonb_build_object('historico_vendas', n, 'historico_de', ini12, 'historico_ate', fim12);
  return r || jsonb_build_object('realizado_mes', saz, 'hoje', h);
end $$;
revoke all on function public.plano_anual_sugestoes(uuid, int, date) from anon, public;
grant execute on function public.plano_anual_sugestoes(uuid, int, date) to authenticated;notify pgrst, 'reload schema';
