-- v0.25: cálculos do Painel gerencial passam do navegador para o banco (determinístico, sem IA).
-- A tela só formata o que esta função devolve.
create or replace function public.painel_gerencial(p_ws uuid, p_ini date, p_fim date, p_hoje date default current_date)
returns jsonb language plpgsql stable set search_path to 'public' as $f$
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
          from vendas where workspace_id = p_ws),
  cx as (select (select coalesce(sum(saldo_atual), 0) from v_saldo_contas_bancarias where workspace_id = p_ws) as saldo,
                (select coalesce(sum(valor), 0) from contas_receber where workspace_id = p_ws and status = 'previsto') as a_receber,
                (select coalesce(sum(valor), 0) from contas_pagar where workspace_id = p_ws and status = 'previsto') as a_pagar),
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
           and not (cancelado_em is not null and (cancelado_em at time zone 'UTC')::date <= p_hoje) group by pessoa_id),
  m0 as (select pessoa_id, sum(mrr) as v from ct where ativado_em is not null and data_inicio <= p_hoje - 365 and (data_fim is null or data_fim >= p_hoje - 365)
           and not (cancelado_em is not null and (cancelado_em at time zone 'UTC')::date <= p_hoje - 365) group by pessoa_id),
  rec as (select coalesce((select sum(v) from m1), 0) as mrr_hoje,
                 (select sum(v) from m0) as mrr0,
                 (select sum(coalesce(m1.v, 0)) from m0 left join m1 using (pessoa_id)) as ret,
                 (select sum(least(m0.v, coalesce(m1.v, 0))) from m0 left join m1 using (pessoa_id)) as retb),
  pl as (select mercado_total, mercado_rotulo from planos where workspace_id = p_ws and mercado_total > 0 order by (status = 'ativo') desc, data_inicio desc limit 1),
  evt as (select pessoa_id, (data_venda at time zone 'UTC')::date as d, campanha_id, 0 as ord from vendas where workspace_id = p_ws and status = 'aprovada'
          union all select pessoa_id, (ativado_em at time zone 'UTC')::date, campanha_id, 1 from contratos where workspace_id = p_ws and ativado_em is not null),
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
      'qtd_realizado', (select count(*) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim),
      'entrou', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and tipo = 'entrada'),
      'saiu', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and tipo = 'saida'),
      'qtd_previsto', (select count(*) from contas_receber where workspace_id = p_ws and status = 'previsto' and vencimento <= fim_prev)
                    + (select count(*) from contas_pagar where workspace_id = p_ws and status = 'previsto' and vencimento <= fim_prev)),
    'dre_resultado', coalesce((select jsonb_agg(jsonb_build_object('mes', mes, 'resultado', rs) order by mes)
        from (select mes, sum(case when tipo = 'receita' then valor else -valor end) as rs from v_dre_mensal where workspace_id = p_ws group by mes) d), '[]')
  ) into r;
  return r;
end $f$;
grant execute on function public.painel_gerencial(uuid, date, date, date) to authenticated;
