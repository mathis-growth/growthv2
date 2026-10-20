-- =====================================================================
-- GROWTHS — simulação de qualificação, vendas, recebimento e estorno
-- (usa o workspace "Growths — Demo" criado em supabase/seed.sql; dados fictícios)
-- Rode uma vez só. Para recomeçar do zero, apague o workspace de demo e rode
-- supabase/seed.sql de novo:
--   delete from workspaces where nome = 'Growths — Demo';
-- =====================================================================

do $$
declare
  ws uuid;
  curso uuid;
  hotmart uuid;
  lead record;
  n int := 0;
  formas text[] := array['pix', 'pix', 'pix', 'cartao_credito', 'cartao_credito', 'boleto'];
  venda_reembolso uuid;
begin
  select id into ws from workspaces where nome = 'Growths — Demo';
  select id into curso from produtos where workspace_id = ws and nome = 'Curso Exemplo';
  select id into hotmart from plataformas_venda where workspace_id = ws and nome = 'Hotmart';

  -- 1. Qualificação: 10 leads respondem a pesquisa (6 qualificados, 4 não)
  for lead in select id, row_number() over (order by criado_em) as rn
              from pessoas where workspace_id = ws order by criado_em limit 10 loop
    update pessoas set
      respostas_pesquisa = jsonb_build_object('faturamento', 'ate_10k', 'urgencia', 'alta'),
      pesquisa_respondida_em = criado_em + interval '3 minutes',
      pontuacao_qualificacao = case when lead.rn <= 6 then 80 else 25 end,
      qualificacao = case when lead.rn <= 6 then 'qualificado' else 'nao_qualificado' end
    where id = lead.id;
  end loop;

  -- 2. Vendas: os 6 qualificados compram o Curso Exemplo (R$ 497) em 2 a 5 de out
  for lead in select id from pessoas
              where workspace_id = ws and qualificacao = 'qualificado' order by criado_em loop
    n := n + 1;
    insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento,
                        valor_bruto, data_venda, id_externo)
    values (ws, lead.id, curso, hotmart, formas[n], 497.00,
            timestamptz '2026-10-02 10:00:00-03' + (n * interval '14 hours'),
            'HP-SIM-' || n);
  end loop;

  -- 3. O Pix cai no mesmo dia, o boleto em 3 dias, o cartão em 30: recebe só o que já venceu
  perform registrar_recebimentos_ate(ws, date '2026-10-05');

  -- 4. Um reembolso de uma venda em Pix já recebida
  select v.id into venda_reembolso from vendas v
  where v.workspace_id = ws and v.forma_pagamento = 'pix' order by v.data_venda limit 1;
  perform registrar_estorno(venda_reembolso, 'reembolso', 'Simulação: pediu reembolso em 3 dias', date '2026-10-05');
end $$;

-- ---------------- Resultado (uma tabela só) ----------------
select item, valor from (
  select 1 as ordem, 'Leads captados' as item, count(*)::text as valor from pessoas
  union all select 2, 'Leads qualificados', count(*)::text from pessoas where qualificacao = 'qualificado'
  union all select 3, 'Clientes ativos', count(*)::text from pessoas where status_cliente = 'ativo'
  union all select 4, 'Clientes inativos (reembolso)', count(*)::text from pessoas where status_cliente = 'inativo'
  union all select 5, 'Vendas aprovadas', count(*)::text from vendas where status = 'aprovada'
  union all select 6, 'Vendas estornadas', count(*)::text from vendas where status <> 'aprovada'
  union all select 7, 'Receita bruta (DRE)', coalesce(sum(valor), 0)::text from v_dre_mensal where tipo = 'receita'
  union all select 8, 'Taxas da plataforma (DRE)', coalesce(sum(valor), 0)::text from v_dre_mensal where codigo = '5.1.01'
  union all select 9, 'Impostos (DRE)', coalesce(sum(valor), 0)::text from v_dre_mensal where codigo = '5.1.02'
  union all select 10, 'Saldo na conta bancária', coalesce(sum(saldo_atual), 0)::text from v_saldo_contas_bancarias
  union all select 11, 'A receber (previsto)', coalesce(sum(valor), 0)::text from contas_receber where status = 'previsto'
  union all select 12, 'Diferença débitos - créditos (deve ser 0)',
         coalesce(sum(case tipo when 'D' then valor else -valor end), 0)::text from partidas
) r order by ordem;

-- Para olhar com calma, rode uma consulta por vez:
--   select * from vendas order by data_venda;          -- taxa, imposto, líquido e previsão por venda
--   select * from v_fluxo_caixa order by data;          -- caixa realizado e previsto
--   select * from v_dre_mensal order by codigo;         -- DRE gerencial por conta
--   select * from v_funil_campanha;                     -- metas x realizado da campanha
--   select * from alunos;                               -- Kanban de alunos com a tag do produto
