-- Auditoria v0.110: empresa fictícia coerente ("Escola Aurora (auditoria)") criada pelos fluxos reais do banco
-- (vendas com taxa/imposto/recebimento, estorno, contratos ativados, contas a pagar pagas, anúncios com custo diário).
-- Rodar num banco montado do zero com todas as migrações (tests/auditoria/LEIA.md). Período: jul a out/2026, "hoje" = 15/10/2026.
\set ON_ERROR_STOP 1
select set_config('request.jwt.claims', '{"role":"service_role"}', false) \g /dev/null
do $$
declare
  ws uuid; uid uuid := '00000000-0000-0000-0000-00000000a0a0'; banco uuid; hot uuid; cc_prod uuid; cc_meta uuid; cc_goo uuid; cc_ger uuid;
  p_curso uuid; p_ment uuid; p_ebook uuid; c_perp uuid; c_lanc uuid; cn_meta uuid; cn_goo uuid; a uuid[] := '{}'; ag uuid;
  pe uuid; v uuid; ct uuid; d date; i int; k int; n int; dia date; custo numeric; fp text; forma text[] := array['pix','pix','cartao_credito','cartao_credito','cartao_credito','boleto'];
  nomes text[] := array['Ana','Bruno','Carla','Diego','Elisa','Fábio','Gabi','Heitor','Iara','João','Karen','Lucas','Marina','Nina','Otávio','Paula','Rafa','Sofia','Téo','Vera'];
  sob text[] := array['Silva','Souza','Lima','Costa','Rocha','Alves','Melo','Dias','Pires','Reis'];
  pc_meta uuid; pc_goo uuid; pc_pl uuid; pc_eq uuid; pc_fe uuid; seed float := 0.42;
begin
  perform setseed(seed);
  insert into auth.users (id, email) values (uid, 'auditoria@escolaaurora.com.br') on conflict do nothing;
  ws := provisionar_workspace('Escola Aurora (auditoria)');
  insert into workspace_membros (workspace_id, user_id, papel) values (ws, uid, 'admin') on conflict do nothing;
  insert into empresa (workspace_id, nome, regime_tributario) values (ws, 'Escola Aurora', 'simples_nacional') on conflict (workspace_id) do update set regime_tributario = 'simples_nacional';
  select id into cc_prod from centros_custo where workspace_id = ws and codigo = 'PRODUTO';
  select id into cc_meta from centros_custo where workspace_id = ws and codigo = 'META';
  select id into cc_goo from centros_custo where workspace_id = ws and codigo = 'GOOGLE';
  select id into cc_ger from centros_custo where workspace_id = ws and codigo = 'GERAL';
  select id into pc_meta from plano_contas where workspace_id = ws and codigo = '6.1.02';
  select id into pc_goo from plano_contas where workspace_id = ws and codigo = '6.1.01';
  select id into pc_pl from plano_contas where workspace_id = ws and codigo = '6.2.04';
  select id into pc_eq from plano_contas where workspace_id = ws and codigo = '6.2.02';
  select id into pc_fe from plano_contas where workspace_id = ws and codigo = '6.2.01';
  insert into impostos_config (workspace_id, nome, aliquota_percentual, base) values (ws, 'Simples Nacional (estimado)', 8, 'valor_bruto');
  insert into contas_bancarias (workspace_id, nome, banco, saldo_inicial, conta_contabil_id, padrao)
  values (ws, 'Conta principal', 'Banco Aurora', 20000, (select id from plano_contas where workspace_id = ws and codigo = '1.1.01'), true) returning id into banco;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 9.9, 1.00) returning id into hot;
  insert into plataforma_formas_pagamento (workspace_id, plataforma_id, forma_pagamento, prazo_recebimento_dias) values (ws, hot, 'pix', 0), (ws, hot, 'cartao_credito', 30), (ws, hot, 'boleto', 3);
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Curso Base', 'curso-base', 'curso', false, 997, cc_prod, '{"mc_custo_pct": 10}') returning id into p_curso;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Mentoria em grupo', 'mentoria-grupo', 'servico', false, 3000, cc_prod, '{"mc_custo_pct": 25, "mc_custo_cliente": 150}') returning id into p_ment;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id) values (ws, 'E-book de bônus', 'ebook-bonus', 'digital', false, 47, cc_prod) returning id into p_ebook;
  insert into produto_plataforma (workspace_id, produto_id, plataforma_id, id_externo) values (ws, p_curso, hot, 'AUR-CURSO'), (ws, p_ebook, hot, 'AUR-EBOOK');
  insert into campanhas (workspace_id, nome, status, modelo, data_inicio, produto_id, meta_leads_mes, meta_cac)
  values (ws, 'Perpétuo Curso Base', 'ativa', 'perpetuo', '2026-07-01', p_curso, 400, 220) returning id into c_perp;
  insert into campanhas (workspace_id, nome, status, modelo, data_inicio, data_fim, produto_id, orcamento_total, meta_leads, meta_vendas, meta_receita, meta_cac)
  values (ws, 'Lançamento Setembro', 'ativa', 'lancamento', '2026-09-01', '2026-09-30', p_curso, 21000, 700, 45, 44865, 300) returning id into c_lanc;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento) values (ws, c_perp, 'meta_ads', 'perpetuo-meta', 36000) returning id into cn_meta;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento) values (ws, c_lanc, 'google_ads', 'lanc-set-google', 21000) returning id into cn_goo;
  for k in 1..3 loop
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, ativo, angulo) values (ws, cn_meta, 'Criativo ' || k, 'criativo-' || k, true, (array['dor','prova','oferta'])[k]) returning id into ag; a := a || ag;
  end loop;
  insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, ativo, angulo) values (ws, cn_goo, 'Pesquisa lançamento', 'busca-1', true, 'oferta') returning id into ag;

  -- anúncios: custo e métricas por dia (perpétuo jul–out; lançamento só em setembro)
  for dia in select generate_series('2026-07-01'::date, '2026-10-15'::date, '1 day')::date loop
    for k in 1..3 loop
      custo := round((90 + k * 15 + random() * 30)::numeric, 2);
      insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
      values (ws, a[k], dia, (custo * 95)::int, (custo * 95 * (0.012 - k * 0.0015 - (dia - '2026-07-01'::date) * 0.00002))::int, custo, (custo * 95 * 0.009)::int, (custo * 95 / (1.2 + (dia - '2026-07-01'::date) * 0.012))::int, 'importacao');
    end loop;
    if dia between '2026-09-01' and '2026-09-30' then
      custo := round((620 + random() * 160)::numeric, 2);
      insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
      values (ws, ag, dia, (custo * 40)::int, (custo * 40 * 0.05)::int, custo, (custo * 40 * 0.04)::int, (custo * 32)::int, 'importacao');
    end if;
  end loop;

  -- leads e vendas do perpétuo (Meta): ~12 leads por dia, 4,5% compram em até 7 dias; 30% levam o e-book
  n := 0;
  for dia in select generate_series('2026-07-01'::date, '2026-10-15'::date, '1 day')::date loop
    for i in 1..(9 + (random() * 6)::int) loop
      n := n + 1;
      insert into pessoas (workspace_id, nome, email, utm_source, utm_medium, utm_campaign, utm_content, criado_em)
      values (ws, nomes[1 + n % 20] || ' ' || sob[1 + (n / 20) % 10], 'lead' || n || '@aurora.test', 'facebook', 'cpc', 'perpetuo-meta', 'criativo-' || (1 + n % 3), dia + time '09:00' + (i * interval '37 minutes'))
      returning id into pe;
      if random() < 0.045 and dia <= '2026-10-12' then
        fp := forma[1 + (random() * 5)::int];
        insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref, utm_campaign, utm_content)
        values (ws, pe, p_curso, hot, c_perp, fp, 997, dia + (1 + (random() * 3)::int) + time '20:00', 'P-' || n, 'PED-' || n, 'perpetuo-meta', 'criativo-' || (1 + n % 3));
        if random() < 0.3 then
          insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref)
          values (ws, pe, p_ebook, hot, c_perp, fp, 47, dia + (1 + (random() * 3)::int) + time '20:01', 'E-' || n, 'PED-' || n);
        end if;
      end if;
    end loop;
  end loop;
  -- lançamento de setembro (Google): 700 leads de 1 a 20/09, carrinho de 21 a 27/09, 6% compram
  for i in 1..700 loop
    n := n + 1; d := '2026-09-01'::date + (i % 20);
    insert into pessoas (workspace_id, nome, email, utm_source, utm_medium, utm_campaign, utm_content, criado_em)
    values (ws, nomes[1 + n % 20] || ' ' || sob[1 + (n / 20) % 10], 'lead' || n || '@aurora.test', 'google', 'cpc', 'lanc-set-google', 'busca-1', d + time '10:00' + (i % 9) * interval '1 hour')
    returning id into pe;
    if random() < 0.06 then
      insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, campanha_id, forma_pagamento, valor_bruto, data_venda, id_externo, pedido_ref, utm_campaign)
      values (ws, pe, p_curso, hot, c_lanc, forma[1 + (random() * 5)::int], 997, '2026-09-21'::date + (i % 7) + time '19:00', 'L-' || n, 'PEDL-' || n, 'lanc-set-google');
    end if;
  end loop;

  -- recebe o que já venceu; 4 reembolsos de vendas do curso
  perform registrar_recebimentos_ate(ws, '2026-10-15');
  for v in select id from vendas where workspace_id = ws and produto_id = p_curso and data_venda < '2026-10-01' order by data_venda limit 4 loop
    perform registrar_estorno(v, 'reembolso', 'Auditoria: pediu reembolso na garantia', (select (data_venda + interval '5 days')::date from vendas where id = v));
  end loop;

  -- mentoria: 14 alunos do curso fecham contrato de 3 parcelas de R$ 1.000 (ago a out); parcelas vencidas são recebidas
  k := 0;
  for pe, d in select distinct on (v2.pessoa_id) v2.pessoa_id, (v2.data_venda + interval '20 days')::date from vendas v2
               where v2.workspace_id = ws and v2.produto_id = p_curso and v2.status = 'aprovada' and v2.data_venda between '2026-07-05' and '2026-09-20' order by v2.pessoa_id, v2.data_venda limit 14 loop
    k := k + 1;
    insert into contratos (workspace_id, pessoa_id, campanha_id, status, data_inicio, num_parcelas, primeiro_vencimento, conta_bancaria_id, forma_pagamento)
    values (ws, pe, null, 'rascunho', d, 3, d, banco, 'pix') returning id into ct;
    insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values (ws, ct, p_ment, 1, 3000);
    perform ativar_contrato(ct);
  end loop;
  for v in select id from contas_receber where workspace_id = ws and contrato_id is not null and status = 'previsto' and vencimento <= '2026-10-15' loop
    perform registrar_recebimento(v, (select vencimento from contas_receber where id = v), banco);
  end loop;

  -- despesas: pró-labore, equipe, ferramentas (recorrentes) e as faturas de mídia (= soma do custo dos anúncios no mês)
  for d in select generate_series('2026-07-01'::date, '2026-10-01'::date, '1 month')::date loop
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id) values
      (ws, 'Pró-labore — ' || to_char(d, 'MM/YYYY'), 18000, d, d + 4, pc_pl, cc_ger),
      (ws, 'Equipe (editor e social media) — ' || to_char(d, 'MM/YYYY'), 9500, d, d + 9, pc_eq, cc_ger),
      (ws, 'Ferramentas — ' || to_char(d, 'MM/YYYY'), 2200, d, d + 14, pc_fe, cc_ger);
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
    select ws, 'Meta Ads — ' || to_char(d, 'MM/YYYY'), sum(m.custo), d, (d + interval '1 month')::date + 9, pc_meta, cc_meta, c_perp
      from metricas_anuncio_dia m where m.workspace_id = ws and m.anuncio_id = any(a) and date_trunc('month', m.data) = d having sum(m.custo) > 0;
    insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
    select ws, 'Google Ads — ' || to_char(d, 'MM/YYYY'), sum(m.custo), d, (d + interval '1 month')::date + 9, pc_goo, cc_goo, c_lanc
      from metricas_anuncio_dia m where m.workspace_id = ws and m.anuncio_id = ag and date_trunc('month', m.data) = d having sum(m.custo) > 0;
  end loop;
  for v in select id from contas_pagar where workspace_id = ws and vencimento <= '2026-10-15' and status = 'previsto' loop
    perform registrar_pagamento(v, (select vencimento from contas_pagar where id = v), banco);
  end loop;
end $$;

select 'pessoas' item, count(*)::text from pessoas p join workspaces w on w.id = p.workspace_id where w.nome = 'Escola Aurora (auditoria)'
union all select 'vendas aprovadas', count(*)::text from vendas v join workspaces w on w.id = v.workspace_id where w.nome = 'Escola Aurora (auditoria)' and v.status = 'aprovada'
union all select 'vendas estornadas', count(*)::text from vendas v join workspaces w on w.id = v.workspace_id where w.nome = 'Escola Aurora (auditoria)' and v.status <> 'aprovada'
union all select 'contratos ativos', count(*)::text from contratos c join workspaces w on w.id = c.workspace_id where w.nome = 'Escola Aurora (auditoria)' and c.status = 'ativo'
union all select 'contas a pagar', count(*)::text from contas_pagar c join workspaces w on w.id = c.workspace_id where w.nome = 'Escola Aurora (auditoria)'
union all select 'partidas D-C (deve ser 0)', sum(case tipo when 'D' then valor else -valor end)::text from partidas p join workspaces w on w.id = p.workspace_id where w.nome = 'Escola Aurora (auditoria)';
