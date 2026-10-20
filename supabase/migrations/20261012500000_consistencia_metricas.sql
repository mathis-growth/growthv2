-- v0.111 — Consistência das métricas (correções da auditoria v0.110: 3 críticas e 6 altas)
-- 1. empresa: premissas financeiras no banco (antes ficavam no navegador): anexo do Simples, alíquota manual e % de taxas/variáveis extras.
--    O regime continua em empresa.regime_tributario (Cadastro da empresa). Um só lugar para todos os computadores.
-- 2. dre_resumo(ws, ini, fim): DRE por mês e por produto, pela competência dos lançamentos (a mesma regra do Dashboard):
--    receita, taxas, impostos lançados, outras deduções, custos, mídia, aquisição sem mídia, demais despesas e lucro.
--    Por produto: receita, taxas, impostos e clientes (venda pela data da venda; contrato pela parcela, rateado pelos itens).
--    Usada por Custos e margens e pelo Growth Model (coluna Real), para que o lucro do mês seja o mesmo em todas as telas.
-- 3. painel_gerencial: vendas aprovadas, receita bruta, taxas, impostos e líquido passam a respeitar o período escolhido
--    (antes somavam todo o histórico); datas em horário de Brasília (antes UTC: venda após 21h caía no dia seguinte).
-- 4. fin_dashboard_periodo: receitas, despesas e resultado do PERÍODO escolhido (antes: sempre o mês de hoje).
-- Rode DEPOIS de 20261012400000_sincroniza_producao.sql. Idempotente.

alter table empresa add column if not exists anexo_simples text;
alter table empresa add column if not exists aliquota_manual numeric(6, 2);
alter table empresa add column if not exists taxas_variaveis_pct numeric(6, 2);
alter table empresa drop constraint if exists empresa_anexo_simples_check;
alter table empresa add constraint empresa_anexo_simples_check check (anexo_simples is null or anexo_simples in ('auto', 'III', 'V'));
alter table empresa drop constraint if exists empresa_aliquota_manual_check;
alter table empresa add constraint empresa_aliquota_manual_check check (aliquota_manual is null or (aliquota_manual >= 0 and aliquota_manual <= 100));
alter table empresa drop constraint if exists empresa_taxas_variaveis_pct_check;
alter table empresa add constraint empresa_taxas_variaveis_pct_check check (taxas_variaveis_pct is null or (taxas_variaveis_pct >= 0 and taxas_variaveis_pct <= 100));

create or replace function public.dre_resumo(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable set search_path = public as $$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  pt as (
    select date_trunc('month', l.data_fato)::date mes, l.origem_tipo, l.origem_id, pc.tipo, pc.codigo, pc.cac_grupo,
           case when pc.tipo = 'receita' then case when pa.tipo = 'C' then pa.valor else -pa.valor end
                else case when pa.tipo = 'D' then pa.valor else -pa.valor end end v
    from partidas pa join plano_contas pc on pc.id = pa.conta_id join lancamentos l on l.id = pa.lancamento_id
    where pa.workspace_id = p_ws and l.data_fato between p_ini and p_fim and pc.tipo in ('receita', 'deducao', 'custo', 'despesa')),
  cl as (select *, case
           when tipo = 'receita' then 'receita'
           when tipo = 'deducao' and codigo = '5.1.01' then 'taxas'
           when tipo = 'deducao' and codigo = '5.1.02' then 'impostos'
           when tipo = 'deducao' then 'outras_deducoes'
           when tipo = 'custo' then 'custos'
           when coalesce(cac_grupo, case when codigo like '6.1.%' then 'midia' end) = 'midia' then 'midia'
           when cac_grupo is not null then 'aquisicao'
           else 'despesas' end k from pt),
  m as (select mes,
          coalesce(sum(v) filter (where k = 'receita'), 0) receita, coalesce(sum(v) filter (where k = 'taxas'), 0) taxas,
          coalesce(sum(v) filter (where k = 'impostos'), 0) impostos, coalesce(sum(v) filter (where k = 'outras_deducoes'), 0) outras_deducoes,
          coalesce(sum(v) filter (where k = 'custos'), 0) custos, coalesce(sum(v) filter (where k = 'midia'), 0) midia,
          coalesce(sum(v) filter (where k = 'aquisicao'), 0) aquisicao, coalesce(sum(v) filter (where k = 'despesas'), 0) despesas
        from cl group by mes),
  -- produto de cada lançamento: venda/estorno pela venda; parcela de contrato (e cancelamento/desconto) rateada pelos itens do contrato
  vp as (select c.mes, c.k, c.v, ve.produto_id, ve.pessoa_id, 1::numeric peso from cl c join vendas ve on ve.id = c.origem_id
         where c.origem_tipo in ('venda', 'estorno') and c.k in ('receita', 'taxas', 'impostos', 'outras_deducoes')),
  it as (select ci.contrato_id, ci.produto_id, coalesce(ci.quantidade, 1) * ci.valor tot, sum(coalesce(ci.quantidade, 1) * ci.valor) over (partition by ci.contrato_id) soma
         from contrato_itens ci where ci.workspace_id = p_ws),
  cp as (select c.mes, c.k, c.v, it.produto_id, ct.pessoa_id, case when it.soma > 0 then it.tot / it.soma else 0 end peso
         from cl c join contas_receber cr on cr.id = c.origem_id join contratos ct on ct.id = cr.contrato_id join it on it.contrato_id = cr.contrato_id
         where c.origem_tipo in ('contrato_parcela', 'cancelamento_contrato', 'desconto') and c.k in ('receita', 'taxas', 'impostos', 'outras_deducoes')),
  pr as (select mes, produto_id,
           coalesce(sum(v * peso) filter (where k = 'receita'), 0) receita, coalesce(sum(v * peso) filter (where k = 'taxas'), 0) taxas,
           coalesce(sum(v * peso) filter (where k = 'impostos'), 0) impostos, coalesce(sum(v * peso) filter (where k = 'outras_deducoes'), 0) outras_deducoes,
           count(distinct pessoa_id) filter (where k = 'receita' and v > 0) clientes
         from (select * from vp union all select * from cp) x group by mes, produto_id)
  select jsonb_build_object(
    'meses', coalesce((select jsonb_agg(jsonb_build_object('mes', to_char(mes, 'YYYY-MM'), 'receita', receita, 'taxas', taxas, 'impostos', impostos, 'outras_deducoes', outras_deducoes,
        'custos', custos, 'midia', midia, 'aquisicao', aquisicao, 'despesas', despesas,
        'lucro', receita - taxas - impostos - outras_deducoes - custos - midia - aquisicao - despesas) order by mes) from m), '[]'),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('mes', to_char(mes, 'YYYY-MM'), 'produto_id', produto_id, 'receita', receita, 'taxas', taxas, 'impostos', impostos,
        'outras_deducoes', outras_deducoes, 'clientes', clientes) order by mes) from pr), '[]'),
    'imposto_configurado', exists (select 1 from impostos_config ic where ic.workspace_id = p_ws),
    'imposto_lancado', coalesce((select sum(impostos) from m), 0) > 0
  ) into r;
  return r;
end $$;
revoke execute on function public.dre_resumo(uuid, date, date) from public, anon;
grant execute on function public.dre_resumo(uuid, date, date) to authenticated;

CREATE OR REPLACE FUNCTION public.painel_gerencial(p_ws uuid, p_ini date, p_fim date, p_hoje date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare r jsonb; fim_prev date := case when p_fim > p_hoje then p_fim else p_hoje + 30 end;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  pes as (select count(*) as total, count(*) filter (where qualificacao = 'qualificado') as quals,
            count(*) filter (where status_funil = 'cliente') as clientes,
            count(*) filter (where status_funil = 'cliente' and status_cliente = 'ativo') as ativos
          from pessoas where workspace_id = p_ws),
  ven as (select count(*) as total, count(*) filter (where status = 'aprovada') as apr,
            coalesce(sum(valor_bruto) filter (where status = 'aprovada'), 0) as bruto,
            coalesce(sum(taxa_plataforma) filter (where status = 'aprovada'), 0) as taxas,
            coalesce(sum(impostos) filter (where status = 'aprovada'), 0) as impostos,
            coalesce(sum(valor_liquido) filter (where status = 'aprovada'), 0) as liquido
          from vendas where workspace_id = p_ws and (data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim),
  cx as (select (select coalesce(sum(saldo_atual), 0) from v_saldo_contas_bancarias where workspace_id = p_ws) as saldo,
                (select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento between p_hoje and fim_prev) as a_receber,
                (select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento < p_hoje) as atraso_receber,
                (select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento < p_hoje) as atraso_pagar,
                (select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento between p_hoje and fim_prev) as a_pagar),
  res as (select
            coalesce(sum(case when pc.tipo = 'receita' then case when pa.tipo = 'C' then pa.valor else -pa.valor end end), 0) as receita,
            coalesce(sum(case when pc.tipo = 'deducao' then case when pa.tipo = 'D' then pa.valor else -pa.valor end end), 0) as deducao,
            coalesce(sum(case when pc.tipo = 'custo' then case when pa.tipo = 'D' then pa.valor else -pa.valor end end), 0) as custo,
            coalesce(sum(case when pc.tipo = 'despesa' then case when pa.tipo = 'D' then pa.valor else -pa.valor end end), 0) as despesa
          from partidas pa join plano_contas pc on pc.id = pa.conta_id join lancamentos l on l.id = pa.lancamento_id
          where pa.workspace_id = p_ws and l.data_fato between p_ini and p_fim),
  ct as (select c.pessoa_id, c.data_inicio, c.data_fim, c.ativado_em, c.cancelado_em,
           coalesce((select sum(coalesce(i.quantidade, 1) * coalesce(i.valor, 0)) from contrato_itens i where i.contrato_id = c.id), 0)
             / case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end as mrr
         from contratos c where c.workspace_id = p_ws and c.recorrente),
  m1 as (select pessoa_id, sum(mrr) as v from ct where ativado_em is not null and data_inicio <= p_hoje and (data_fim is null or data_fim >= p_hoje)
           and not (cancelado_em is not null and (cancelado_em at time zone 'America/Sao_Paulo')::date <= p_hoje) group by pessoa_id),
  m0 as (select pessoa_id, sum(mrr) as v from ct where ativado_em is not null and data_inicio <= p_hoje - 365 and (data_fim is null or data_fim >= p_hoje - 365)
           and not (cancelado_em is not null and (cancelado_em at time zone 'America/Sao_Paulo')::date <= p_hoje - 365) group by pessoa_id),
  rec as (select coalesce((select sum(v) from m1), 0) as mrr_hoje,
                 (select sum(v) from m0) as mrr0,
                 (select sum(coalesce(m1.v, 0)) from m0 left join m1 using (pessoa_id)) as ret,
                 (select sum(least(m0.v, coalesce(m1.v, 0))) from m0 left join m1 using (pessoa_id)) as retb),
  pl as (select mercado_total, mercado_rotulo from planos where workspace_id = p_ws and mercado_total > 0 order by (status = 'ativo') desc, data_inicio desc limit 1),
  evt as (select pessoa_id, (data_venda at time zone 'America/Sao_Paulo')::date as d, campanha_id, 0 as ord from vendas where workspace_id = p_ws and status = 'aprovada'
          union all select pessoa_id, (ativado_em at time zone 'America/Sao_Paulo')::date, campanha_id, 1 from contratos where workspace_id = p_ws and ativado_em is not null),
  prim as (select distinct on (pessoa_id) pessoa_id, d, campanha_id from evt where pessoa_id is not null and d is not null order by pessoa_id, d, ord),
  novos as (select * from prim where d between p_ini and p_fim),
  cus as (select v.*, coalesce(v.cac_grupo, case when v.conta_codigo like '6.1.%' then 'midia' end) as grupo
          from v_custos_rateados v where v.workspace_id = p_ws and v.status <> 'cancelado' and coalesce(v.competencia, v.vencimento) between p_ini and p_fim),
  cus_g as (select * from cus where grupo is not null),
  cin as (select * from cus_g where entra_no_cac),
  tot as (select coalesce(sum(valor) filter (where grupo = 'midia'), 0) as midia, coalesce(sum(valor), 0) as total from cin),
  nn as (select count(*) as n from novos)
  select jsonb_build_object(
    'funil', (select jsonb_build_object('total', total, 'qualificados', quals, 'clientes', clientes, 'ativos', ativos, 'inativos', clientes - ativos,
                'leads', total - clientes, 'pct_qualificados', quals::numeric / nullif(total, 0)) from pes),
    'vendas', (select jsonb_build_object('total', total, 'aprovadas', apr, 'nao_aprovadas', total - apr, 'bruto', bruto, 'taxas', taxas, 'impostos', impostos, 'liquido', liquido) from ven),
    'caixa', (select to_jsonb(cx) from cx),
    'resultado', (select jsonb_build_object('receita', receita, 'deducao', deducao, 'custo', custo, 'despesa', despesa,
                   'saidas', deducao + custo + despesa, 'lucro', receita - (deducao + custo + despesa),
                   'margem', case when receita > 0 then (receita - (deducao + custo + despesa)) / receita end,
                   'roi', case when (deducao + custo + despesa) > 0 then (receita - (deducao + custo + despesa)) / (deducao + custo + despesa) end) from res),
    'recorrencia', (select jsonb_build_object('mrr', mrr_hoje, 'arr', mrr_hoje * 12,
                   'nrr', case when mrr0 > 0 then ret / mrr0 end, 'grr', case when mrr0 > 0 then retb / mrr0 end, 'base_ini', p_hoje - 365) from rec),
    'penetracao', (select jsonb_build_object('mercado', coalesce((select mercado_total from pl), 0), 'rotulo', (select mercado_rotulo from pl),
                   'ativos', (select ativos from pes), 'pct', case when coalesce((select mercado_total from pl), 0) > 0 then (select ativos from pes)::numeric / (select mercado_total from pl) end)),
    'cac', jsonb_build_object(
      'novos', (select n from nn), 'custo_midia', (select midia from tot), 'custo_total', (select total from tot),
      'cac_midia', case when (select n from nn) > 0 then (select midia from tot) / (select n from nn) end,
      'cac_total', case when (select n from nn) > 0 then (select total from tot) / (select n from nn) end,
      'peso_margem', case when (select receita from res) > 0 then (select total from tot) / (select receita from res) end,
      'margem_sem_cac', case when (select receita from res) > 0 then ((select receita - (deducao + custo + despesa) from res) + (select total from tot)) / (select receita from res) end,
      'fora_cac', coalesce((select sum(valor) from cus_g where not entra_no_cac), 0),
      'com_rateio', exists (select 1 from cin where percentual < 100) or exists (select 1 from cus_g where not entra_no_cac),
      'por_grupo', coalesce((select jsonb_agg(jsonb_build_object('k', grupo, 'valor', s, 'pct', s / nullif((select total from tot), 0),
                     'por_cliente', case when (select n from nn) > 0 then s / (select n from nn) end) order by s desc)
                     from (select grupo, sum(valor) as s from cin group by grupo) g), '[]'),
      'por_fornecedor', coalesce((select jsonb_agg(jsonb_build_object('k', nome, 'valor', s, 'pct', s / nullif((select total from tot), 0)) order by s desc)
                     from (select coalesce(f.nome, 'Sem fornecedor informado') as nome, sum(c.valor) as s from cin c left join fornecedores f on f.id = c.fornecedor_id
                           group by 1 order by 2 desc limit 8) x), '[]'),
      'por_campanha', coalesce((select jsonb_agg(jsonb_build_object('k', k, 'valor', s, 'novos', n, 'cac', case when n > 0 then s / n end,
                     'pct', s / nullif((select total from tot), 0), 'tira_margem', case when (select receita from res) > 0 then s / (select receita from res) end) order by s desc)
                     from (select g.k, g.s, (select count(*) from novos nv where coalesce(nv.campanha_id::text, '') = g.k) as n
                           from (select coalesce(c.campanha_id::text, '') as k, sum(c.valor) as s from cin c group by 1) g) y), '[]')),
    'fluxo', jsonb_build_object(
      'ate', fim_prev,
      'previsto', coalesce((select jsonb_agg(to_jsonb(x) order by x.d, x.tp) from (
          select cr.vencimento as d, 'entrada' as tp, coalesce(pv.nome, pcn.nome, '—') as nome, coalesce(nullif(cr.descricao, ''), pr.nome, '') as descr, cr.valor as v,
                 cr.vencimento < p_hoje as atr, 'cr' as k, cr.id, cr.venda_id as venda, cr.contrato_id as contrato, cr.conta_bancaria_id as banco_id
          from contas_receber cr left join vendas ve on ve.id = cr.venda_id left join pessoas pv on pv.id = ve.pessoa_id left join produtos pr on pr.id = ve.produto_id
               left join contratos ctt on ctt.id = cr.contrato_id left join pessoas pcn on pcn.id = ctt.pessoa_id
          where cr.workspace_id = p_ws and cr.status = 'previsto' and cr.vencimento <= fim_prev
          union all
          select cp.vencimento, 'saida', coalesce(fo.nome, '—'), cp.descricao, cp.valor, cp.vencimento < p_hoje, 'cp', cp.id, null, null, null
          from contas_pagar cp left join fornecedores fo on fo.id = cp.fornecedor_id
          where cp.workspace_id = p_ws and cp.status = 'previsto' and cp.vencimento <= fim_prev
          order by 1, 2 limit 80) x), '[]'),
      'realizado', coalesce((select jsonb_agg(to_jsonb(x) order by x.d) from (
          select * from (select mv.data as d, mv.tipo as tp,
                 coalesce(case when mv.origem_tipo = 'recebimento' then coalesce(pv.nome, pcn.nome) when mv.origem_tipo = 'pagamento' then fo.nome end, '—') as nome,
                 coalesce(nullif(case when mv.origem_tipo = 'recebimento' then coalesce(nullif(cr.descricao, ''), pr.nome) when mv.origem_tipo = 'pagamento' then cp.descricao end, ''), mv.descricao, '') as descr,
                 mv.valor as v, cb.nome as banco,
                 case when cr.id is not null then 'cr' when cp.id is not null then 'cp' else '' end as k,
                 coalesce(cr.id, cp.id) as id, cr.venda_id as venda, cr.contrato_id as contrato, cr.conta_bancaria_id as banco_id
            from movimentacoes_bancarias mv left join contas_bancarias cb on cb.id = mv.conta_bancaria_id
              left join contas_receber cr on mv.origem_tipo = 'recebimento' and cr.id = mv.origem_id
              left join vendas ve on ve.id = cr.venda_id left join pessoas pv on pv.id = ve.pessoa_id left join produtos pr on pr.id = ve.produto_id
              left join contratos ctt on ctt.id = cr.contrato_id left join pessoas pcn on pcn.id = ctt.pessoa_id
              left join contas_pagar cp on mv.origem_tipo = 'pagamento' and cp.id = mv.origem_id left join fornecedores fo on fo.id = cp.fornecedor_id
            where mv.workspace_id = p_ws and mv.data between p_ini and p_fim order by mv.data desc limit 120) z) x), '[]'),
      'qtd_realizado', (select count(*) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and conta_bancaria_id not in (select id from contas_bancarias where tipo = 'cartao')),
      'entrou', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and conta_bancaria_id not in (select id from contas_bancarias where tipo = 'cartao') and tipo = 'entrada'),
      'saiu', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and conta_bancaria_id not in (select id from contas_bancarias where tipo = 'cartao') and tipo = 'saida'),
      'qtd_previsto', (select count(*) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento <= fim_prev)
                    + (select count(*) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento <= fim_prev)),
    'dre_resultado', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'resultado', rs) order by mes)
        from (select mes, sum(case when tipo = 'receita' then valor else -valor end) as rs from v_dre_mensal where workspace_id = p_ws group by mes) d), '[]')
  ) into r;
  return r;
end $function$;

CREATE OR REPLACE FUNCTION public.fin_dashboard_periodo(p_ws uuid, p_hoje date DEFAULT CURRENT_DATE, p_ini date DEFAULT NULL::date, p_fim date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare r jsonb; mes_atual text := to_char(p_hoje, 'YYYY-MM'); v_ini date := coalesce(p_ini, p_hoje); v_fim date := coalesce(p_fim, p_hoje + 30);
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  sd as (select nome, saldo_atual from v_saldo_contas_bancarias where workspace_id = p_ws order by nome),
  cx as (select coalesce(sum(saldo_atual), 0) as caixa, count(*) as n from sd),
  rp as (select cr.id, cr.valor, cr.vencimento, coalesce(pv.nome, pcn.nome, '—') as nome, coalesce(nullif(cr.descricao, ''), pr.nome, '') as descr
         from contas_receber cr left join vendas ve on ve.id = cr.venda_id left join pessoas pv on pv.id = ve.pessoa_id left join produtos pr on pr.id = ve.produto_id
              left join contratos ct on ct.id = cr.contrato_id left join pessoas pcn on pcn.id = ct.pessoa_id
         where cr.workspace_id = p_ws and cr.status = 'previsto'),
  pp as (select cp.id, cp.valor, cp.vencimento, cp.descricao, coalesce(fo.nome, '') as fornecedor
         from contas_pagar cp left join fornecedores fo on fo.id = cp.fornecedor_id where cp.workspace_id = p_ws and cp.status = 'previsto'),
  dias as (select i, p_hoje + i as d from generate_series(0, 30) i),
  proj as (select d.i, d.d, (select caixa from cx)
             + sum(coalesce((select sum(valor) from rp where case when d2.i = 0 then rp.vencimento <= d2.d else rp.vencimento = d2.d end), 0)
                 - coalesce((select sum(valor) from pp where case when d2.i = 0 then pp.vencimento <= d2.d else pp.vencimento = d2.d end), 0))
               over (order by d.i) as saldo
           from dias d join dias d2 on d2.i = d.i),
  dre as (select mes, tipo, conta, valor from v_dre_mensal where workspace_id = p_ws),
  -- v0.111: receitas, despesas e resultado do PERÍODO escolhido (antes: sempre o mês de hoje), pela competência dos lançamentos (mesma regra da DRE)
  mes_ as (select
             coalesce(sum(case when pc.tipo = 'receita' then case when pa.tipo = 'C' then pa.valor else -pa.valor end end), 0) as rec,
             coalesce(sum(case when pc.tipo in ('deducao', 'custo', 'despesa') then case when pa.tipo = 'D' then pa.valor else -pa.valor end end), 0) as desp
           from partidas pa join plano_contas pc on pc.id = pa.conta_id join lancamentos l on l.id = pa.lancamento_id
           where pa.workspace_id = p_ws
             and l.data_fato between coalesce(p_ini, date_trunc('month', p_hoje)::date) and coalesce(p_fim, (date_trunc('month', p_hoje) + interval '1 month - 1 day')::date))
  select jsonb_build_object(
    'caixa', (select caixa from cx), 'n_contas', (select n from cx),
    'periodo', jsonb_build_object('ini', v_ini, 'fim', v_fim),
    'a_receber', jsonb_build_object('valor', coalesce((select sum(valor) from rp where vencimento between v_ini and v_fim), 0), 'qtd', (select count(*) from rp where vencimento between v_ini and v_fim),
        'atraso', coalesce((select sum(valor) from rp where vencimento < p_hoje), 0)),
    'a_pagar', jsonb_build_object('valor', coalesce((select sum(valor) from pp where vencimento between v_ini and v_fim), 0), 'qtd', (select count(*) from pp where vencimento between v_ini and v_fim),
        'atraso', coalesce((select sum(valor) from pp where vencimento < p_hoje), 0)),
    'caixa_30d', (select saldo from proj where i = 30),
    'projecao', coalesce((select jsonb_agg(jsonb_build_object('d', d, 'saldo', saldo) order by i) from proj), '[]'),
    'receitas_mes', (select rec from mes_), 'despesas_mes', (select desp from mes_), 'resultado_mes', (select rec - desp from mes_),
    'pct_resultado_mes', case when (select rec from mes_) > 0 then (select rec - desp from mes_) / (select rec from mes_) end,
    'resultado_por_mes', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'resultado', rs) order by mes)
        from (select mes, sum(case when tipo = 'receita' then valor else -valor end) as rs from dre group by mes) x), '[]'),
    'proximos_receber', coalesce((select jsonb_agg(to_jsonb(x) order by x.vencimento) from (select nome, descr, valor, vencimento, vencimento < p_hoje as atr from rp where vencimento <= v_fim order by vencimento limit 8) x), '[]'),
    'proximos_pagar', coalesce((select jsonb_agg(to_jsonb(x) order by x.vencimento) from (select descricao, fornecedor, valor, vencimento, vencimento < p_hoje as atr from pp where vencimento <= v_fim order by vencimento limit 8) x), '[]'),
    'saldos', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'saldo', saldo_atual) order by nome) from sd), '[]'),
    'maiores_despesas', coalesce((select jsonb_agg(jsonb_build_object('conta', conta, 'valor', s) order by s desc)
        from (select conta, sum(valor) as s from dre where to_char(mes, 'YYYY-MM') = mes_atual and tipo <> 'receita' group by conta order by 2 desc limit 6) y), '[]')
  ) into r;
  return r;
end $function$;
