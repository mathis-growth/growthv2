-- v0.198 — Planejamento anual, etapa 1: meta do ano (caminho, premissas com a origem de cada uma, três cenários) e sugestões calculadas no banco.
-- As metas por mês continuam em planejamento_mensal. Pode rodar de novo sem erro.

-- 1. Plano do ano: um por cliente e ano
create table if not exists public.plano_anual (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  ano int not null check (ano between 2000 and 2100),
  caminho text not null default 'ambicao' check (caminho in ('ambicao', 'realista', 'ambos')),
  modo_ambicao text not null default 'lucro' check (modo_ambicao in ('lucro', 'crescimento')),
  premissas jsonb not null default '{}'::jsonb check (jsonb_typeof(premissas) = 'object'),   -- { chave: { valor, fonte: sistema|digitado|estimativa, nota } }
  pct_pessimista numeric not null default 20 check (pct_pessimista between 0 and 90),
  pct_otimista numeric not null default 20 check (pct_otimista between 0 and 300),
  base_de text not null default 'ambicao' check (base_de in ('ambicao', 'realista')),       -- com as duas contas, qual vira o cenário base
  cenario_meta text not null default 'base' check (cenario_meta in ('pessimista', 'base', 'otimista')),
  meta_receita numeric check (meta_receita is null or meta_receita >= 0),                     -- a meta escolhida, gravada para as outras telas
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, ano)
);
alter table public.plano_anual enable row level security;
drop policy if exists plano_anual_ver on public.plano_anual;
create policy plano_anual_ver on public.plano_anual for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
drop policy if exists plano_anual_gravar on public.plano_anual;
create policy plano_anual_gravar on public.plano_anual for insert to authenticated with check (pode_editar(workspace_id, '{adm,mkt}'::text[]));
drop policy if exists plano_anual_alterar on public.plano_anual;
create policy plano_anual_alterar on public.plano_anual for update to authenticated using (pode_editar(workspace_id, '{adm,mkt}'::text[])) with check (pode_editar(workspace_id, '{adm,mkt}'::text[]));
drop policy if exists plano_anual_excluir on public.plano_anual;
create policy plano_anual_excluir on public.plano_anual for delete to authenticated using (pode_editar(workspace_id, '{adm,mkt}'::text[]));
revoke all on public.plano_anual from anon;
grant select, insert, update, delete on public.plano_anual to authenticated;

-- 2. Sugestões "Do sistema": o que o Growths já sabe do cliente. Cada número vem com a regra e o período; sem dado, null.
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
  select coalesce(sum(valor_bruto), 0), count(distinct date_trunc('month', data_venda at time zone 'America/Sao_Paulo')) into v, n
    from vendas where workspace_id = p_ws and status = 'aprovada' and extract(year from data_venda at time zone 'America/Sao_Paulo') = p_ano - 1;
  r := r || jsonb_build_object('receita_ano_anterior', case when n > 0 then round(v, 2) end, 'receita_ano_anterior_meses', n, 'receita_ano_anterior_base', 'ano');
  -- v0.200: planejando o ano que vem com o ano anterior ainda aberto, a receita é a dos últimos 12 meses fechados
  if p_ano - 1 >= extract(year from h) then
    select coalesce(sum(valor_bruto), 0), count(distinct date_trunc('month', data_venda at time zone 'America/Sao_Paulo')) into v, n
      from vendas where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between ini12 and fim12;
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
  select count(distinct pessoa_id), round(avg(valor_bruto), 2) into comp, v from vendas where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between ini12 and h;
  select count(*) into recomp from (select pessoa_id from vendas where workspace_id = p_ws and status = 'aprovada' and pessoa_id in
    (select pessoa_id from vendas where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between ini12 and h) group by pessoa_id having count(*) > 1) x;
  r := r || jsonb_build_object('clientes_ativos', nullif(comp, 0), 'ticket_medio', v, 'taxa_recompra', case when comp > 0 then round(recomp::numeric / comp * 100, 1) end);
  -- sazonalidade: peso de cada mês na receita dos últimos 12 meses fechados (só com 6 meses ou mais de venda)
  select jsonb_agg(coalesce(p, 0) order by m) into saz from (select m, (select sum(valor_bruto) from vendas where workspace_id = p_ws and status = 'aprovada'
      and (data_venda at time zone 'America/Sao_Paulo')::date between ini12 and fim12 and extract(month from data_venda at time zone 'America/Sao_Paulo') = m) as p from generate_series(1, 12) m) s;
  select count(*) into n from jsonb_array_elements(saz) e where (e #>> '{}')::numeric > 0;
  r := r || jsonb_build_object('sazonalidade', case when n >= 6 then saz end, 'sazonalidade_meses', n);
  -- realizado do ano do plano, mês a mês (vendas aprovadas, valor bruto: a mesma regra das metas mensais)
  select jsonb_agg(coalesce(p, 0) order by m) into saz from (select m, (select sum(valor_bruto) from vendas where workspace_id = p_ws and status = 'aprovada'
      and extract(year from data_venda at time zone 'America/Sao_Paulo') = p_ano and extract(month from data_venda at time zone 'America/Sao_Paulo') = m) as p from generate_series(1, 12) m) s;
  return r || jsonb_build_object('realizado_mes', saz, 'hoje', h);
end $$;
revoke all on function public.plano_anual_sugestoes(uuid, int, date) from anon, public;
grant execute on function public.plano_anual_sugestoes(uuid, int, date) to authenticated;
notify pgrst, 'reload schema';
