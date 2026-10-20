-- v0.27 — Contas a pagar por período e dashboards com "a receber / a pagar" só do período.
-- Atraso é sempre total. Aplicado por substituição de texto nas funções já existentes (painel_gerencial, fin_dashboard).

-- 1) painel_gerencial: a receber / a pagar só até o fim da janela do fluxo; atraso separado
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'painel_gerencial' and pronamespace = 'public'::regnamespace;
  d := replace(d, $a$(select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto') as a_receber,$a$,
    $b$(select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento between p_hoje and fim_prev) as a_receber,
                (select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento < p_hoje) as atraso_receber,
                (select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento < p_hoje) as atraso_pagar,$b$);
  d := replace(d, $a$(select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto') as a_pagar)$a$,
    $b$(select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento between p_hoje and fim_prev) as a_pagar)$b$);
  execute d;
end $mig$;

-- 2) fin_dashboard_periodo: cópia de fin_dashboard com período opcional (padrão: hoje até +30 dias).
--    fin_dashboard (sem período) continua existindo, sem uso na tela.
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'fin_dashboard' and pronamespace = 'public'::regnamespace;
  d := replace(d, 'fin_dashboard(p_ws uuid, p_hoje date DEFAULT CURRENT_DATE)', 'fin_dashboard_periodo(p_ws uuid, p_hoje date DEFAULT CURRENT_DATE, p_ini date DEFAULT NULL, p_fim date DEFAULT NULL)');
  d := replace(d, $a$declare r jsonb; mes_atual text := to_char(p_hoje, 'YYYY-MM');$a$, $b$declare r jsonb; mes_atual text := to_char(p_hoje, 'YYYY-MM'); v_ini date := coalesce(p_ini, p_hoje); v_fim date := coalesce(p_fim, p_hoje + 30);$b$);
  d := replace(d, $a$'a_receber', jsonb_build_object('valor', coalesce((select sum(valor) from rp), 0), 'qtd', (select count(*) from rp),$a$,
    $b$'periodo', jsonb_build_object('ini', v_ini, 'fim', v_fim),
    'a_receber', jsonb_build_object('valor', coalesce((select sum(valor) from rp where vencimento between v_ini and v_fim), 0), 'qtd', (select count(*) from rp where vencimento between v_ini and v_fim),$b$);
  d := replace(d, $a$'a_pagar', jsonb_build_object('valor', coalesce((select sum(valor) from pp), 0), 'qtd', (select count(*) from pp),$a$,
    $b$'a_pagar', jsonb_build_object('valor', coalesce((select sum(valor) from pp where vencimento between v_ini and v_fim), 0), 'qtd', (select count(*) from pp where vencimento between v_ini and v_fim),$b$);
  d := replace(d, 'from rp order by vencimento limit 8', 'from rp where vencimento <= v_fim order by vencimento limit 8');
  d := replace(d, 'from pp order by vencimento limit 8', 'from pp where vencimento <= v_fim order by vencimento limit 8');
  execute d;
end $mig$;

-- 3) pagar_periodo
create or replace function public.pagar_periodo(p_ws uuid, p_ini date, p_fim date, p_hoje date default current_date)
returns jsonb language plpgsql stable set search_path to 'public' as $function$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  cp as (select c.id, c.valor, c.vencimento, c.status, c.data_pagamento, c.fornecedor_id from contas_pagar c where c.workspace_id = p_ws),
  prev as (select * from cp where status = 'previsto' and vencimento between p_ini and p_fim),
  pag as (select * from cp where status = 'pago' and coalesce(data_pagamento, vencimento) between p_ini and p_fim),
  atr as (select * from cp where status = 'previsto' and vencimento < p_hoje),
  mes as (select date_trunc('month', vencimento)::date as m, sum(valor) as v, count(*) as n from prev group by 1),
  forn as (select coalesce(f.nome, 'Sem fornecedor informado') as nome,
             coalesce(sum(valor) filter (where cp.id in (select id from prev)), 0) as a_pagar,
             coalesce(sum(valor) filter (where cp.id in (select id from atr)), 0) as atraso,
             coalesce(sum(valor) filter (where cp.id in (select id from pag)), 0) as pago
           from cp left join fornecedores f on f.id = cp.fornecedor_id
           where cp.id in (select id from prev) or cp.id in (select id from atr) or cp.id in (select id from pag) group by 1)
  select jsonb_build_object(
    'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim),
    'a_pagar', jsonb_build_object('valor', coalesce((select sum(valor) from prev), 0), 'qtd', (select count(*) from prev)),
    'atraso', jsonb_build_object('valor', coalesce((select sum(valor) from atr), 0), 'qtd', (select count(*) from atr)),
    'pago', jsonb_build_object('valor', coalesce((select sum(valor) from pag), 0), 'qtd', (select count(*) from pag)),
    'por_mes', coalesce((select jsonb_agg(jsonb_build_object('mes', m, 'valor', v, 'qtd', n) order by m) from mes), '[]'),
    'por_fornecedor', coalesce((select jsonb_agg(to_jsonb(x) order by x.a_pagar desc, x.atraso desc) from (select * from forn order by a_pagar desc, atraso desc limit 100) x), '[]')
  ) into r;
  return r;
end $function$;
