-- v0.251: CAC de mídia, ROAS e receita de marketing com a mesma conta em todas as funções.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "v0251: tudo OK".
do $t$
declare ws uuid; pc uuid; pr uuid; c1 uuid; c2 uuid; cc1 uuid; an uuid; p1 uuid; p2 uuid; p3 uuid; v record; j jsonb; hoje_ date := (now() at time zone 'America/Sao_Paulo')::date; mt uuid; c campanhas; m campanha_metas; n numeric;
begin
  ws := provisionar_workspace('Teste v0251');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0251@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, aceita_lancamento) values (ws, '9.9.99', 'Mídia v0251', 'despesa', 'devedora', true) returning id into pc;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0251', 1000) returning id into pr;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'Com anúncio', 'ativa', 'lancamento', pr, hoje_ - 30, hoje_ + 30, false) returning id into c1;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'Sem anúncio', 'ativa', 'lancamento', pr, hoje_ - 30, hoje_ + 30, false) returning id into c2;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign) values (ws, c1, 'meta_ads', 'v0251_meta') returning id into cc1;
  insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content) values (ws, cc1, 'Anúncio', 'ad1') returning id into an;
  insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, custo) values (ws, an, hoje_ - 1, 2000);
  -- a mesma despesa também lançada em contas a pagar: não pode somar
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, campanha_id, conta_despesa_id) values (ws, 'Meta Ads', 2000, hoje_ - 1, hoje_ - 1, c1, pc);
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, campanha_id, conta_despesa_id) values (ws, 'Agência', 300, hoje_ - 1, hoje_ - 1, c2, pc);
  insert into custos_cac (workspace_id, descricao, valor, competencia, grupo, campanha_id) values (ws, 'Mídia', 200, hoje_ - 1, 'midia', c2);
  insert into pessoas (workspace_id, nome, email, campanha_id, utm_campaign) values (ws, 'Fica', 'fica@v0251.invalid', c1, 'v0251_meta') returning id into p1;
  insert into pessoas (workspace_id, nome, email, campanha_id, utm_campaign) values (ws, 'Sai', 'sai@v0251.invalid', c1, 'v0251_meta') returning id into p2;
  insert into pessoas (workspace_id, nome, email, campanha_id) values (ws, 'Sem', 'sem@v0251.invalid', c2) returning id into p3;
  -- p1 compra 1000 e um order bump de 100; p2 compra 1000 e sai
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, forma_pagamento, status, data_venda, valor_bruto, taxa_plataforma) values
    (ws, p1, pr, c1, 'pix', 'aprovada', now(), 1000, 100), (ws, p1, pr, c1, 'pix', 'aprovada', now(), 100, 10), (ws, p2, pr, c1, 'pix', 'aprovada', now(), 1000, 100), (ws, p3, pr, c2, 'pix', 'aprovada', now(), 500, 50);
  update alunos set status = 'cancelado', saiu_em = now() where pessoa_id = p2;
  if not exists (select 1 from alunos where pessoa_id = p2) then insert into alunos (workspace_id, pessoa_id, produto_id, tag, status, saiu_em) values (ws, p2, pr, 'v0251', 'cancelado', now()); end if;
  if exists (select 1 from alunos where pessoa_id = p2 and saiu_em is null) then raise exception 'X: aluno ainda ativo'; end if;

  select * into v from v_marketing_campanha where campanha_id = c1;
  if v.investimento <> 2000 then raise exception 'X: anúncios sem somar contas a pagar (%)', v.investimento; end if;
  if v.vendas <> 3 or v.clientes <> 2 then raise exception 'X: vendas e clientes'; end if;
  if v.cac <> round(2000.0 / 3, 2) then raise exception 'X: CAC = investimento ÷ vendas (%)', v.cac; end if;
  if v.receita <> 990 or v.receita_saiu <> 900 or v.receita_antes_churn <> 1890 or v.pessoas_saiu <> 1 then raise exception 'X: receita sem o churn (%, %, %)', v.receita, v.receita_saiu, v.pessoas_saiu; end if;
  if v.roas <> round(990.0 / 2000, 2) then raise exception 'X: ROAS (%)', v.roas; end if;
  if v.receita_bruta <> 2100 then raise exception 'X: a receita bruta continua disponível'; end if;
  select * into v from v_marketing_campanha where campanha_id = c2;
  if v.investimento <> 500 then raise exception 'X: sem anúncio, usa os lançamentos (%)', v.investimento; end if;
  if v.cac <> 500 or v.roas <> 0.9 then raise exception 'X: sem anúncio: CAC e ROAS'; end if;
  select * into v from v_marketing_canal where campanha_canal_id = cc1;
  if v.investimento <> 2000 or v.cac <> round(2000.0 / 3, 2) or v.receita <> 990 or v.roas <> round(990.0 / 2000, 2) then raise exception 'X: canal (%, %, %)', v.investimento, v.cac, v.receita; end if;

  -- dashboard de marketing
  j := funil_analise(ws, hoje_ - 30, hoje_, null, null) -> 'pos';
  if (j ->> 'custo')::numeric <> 2500 then raise exception 'X: dashboard: anúncios + lançamentos de quem não tem anúncio (%)', j ->> 'custo'; end if;
  if (j ->> 'vendas')::numeric <> 4 or (j ->> 'receita')::numeric <> 1440 or (j ->> 'receita_antes_churn')::numeric <> 2340 then raise exception 'X: dashboard: vendas e receita %', j; end if;
  if (j ->> 'cac')::numeric <> 625 then raise exception 'X: dashboard: CAC (%)', j ->> 'cac'; end if;
  if (j ->> 'roas')::numeric <> round(1440.0 / 2500, 2) then raise exception 'X: dashboard: ROAS (%)', j ->> 'roas'; end if;
  j := funil_analise(ws, hoje_ - 30, hoje_, c1, null) -> 'pos';
  if (j ->> 'custo')::numeric <> 2000 or (j ->> 'cac')::numeric <> round(2000.0 / 3, 2) or (j ->> 'roas')::numeric <> round(990.0 / 2000, 2) then raise exception 'X: dashboard por campanha %', j; end if;
  -- coortes
  j := funil_cohorts(ws, hoje_ - 30, hoje_, c1, 'campanha') -> 0;
  if (j ->> 'custo')::numeric <> 2000 or (j ->> 'vendas')::numeric <> 3 or (j ->> 'cac')::numeric <> round(2000.0 / 3, 2) or (j ->> 'receita')::numeric <> 990 then raise exception 'X: coortes %', j; end if;
  j := funil_cohorts(ws, hoje_ - 30, hoje_, c2, 'campanha') -> 0;
  if (j ->> 'custo')::numeric <> 500 or (j ->> 'cac')::numeric <> 500 then raise exception 'X: coortes sem anúncio %', j; end if;
  -- métricas do growth
  j := growth_metricas_auto(ws, hoje_ - 30, hoje_);
  if (j ->> 'receita')::numeric <> 1440 or (j ->> 'vendas')::numeric <> 4 or round((j ->> 'ticket')::numeric, 2) <> 585 then raise exception 'X: growth %', j; end if;
  -- gráfico do dashboard da campanha
  j := campanha_series(ws, c1, null, true, hoje_);
  if round((j ->> 'roas')::numeric, 2) <> round(990.0 / 2000, 2) then raise exception 'X: série: ROAS %', j ->> 'roas'; end if;
  if round((j -> 'serie' -> -1 ->> 'cac')::numeric, 2) <> round(2000.0 / 3, 2) or (j -> 'serie' -> -1 ->> 'rec')::numeric <> 990 then raise exception 'X: série: último dia %', j -> 'serie' -> -1; end if;
  -- vendas por canal
  j := vendas_por_canal(ws, hoje_ - 30, hoje_, null, c1);
  if jsonb_array_length(j -> 'canais') < 1 or (select sum((x ->> 'receita')::numeric) from jsonb_array_elements(j -> 'canais') x) <> 990 then raise exception 'X: por canal: receita %', j; end if;
  -- árvore: a mesma conta dos cards
  j := _arv_mkt_norm(ws, 'mkt.cac', jsonb_build_object('campanha', c1));
  if round((j ->> 'valor')::numeric, 2) <> round(2000.0 / 3, 2) then raise exception 'X: árvore do CAC %', j; end if;
  j := _arv_mkt_norm(ws, 'mkt.roas', jsonb_build_object('campanha', c1));
  if round((j ->> 'valor')::numeric, 2) <> round(990.0 / 2000, 2) or jsonb_array_length(j -> 'formula') <> 3 then raise exception 'X: árvore do ROAS %', j; end if;
  j := _arv_mkt_norm(ws, 'mkt.cac', jsonb_build_object('campanha', c2));
  if (j ->> 'valor')::numeric <> 500 then raise exception 'X: árvore sem anúncio %', j; end if;
  j := _arv_mkt_norm(ws, 'mkt.roas', jsonb_build_object('ini', hoje_ - 30, 'fim', hoje_));
  if round((j ->> 'valor')::numeric, 2) <> round(1440.0 / 2500, 2) then raise exception 'X: árvore por período %', j; end if;
  -- a pessoa com dois alunos, um ativo, não conta como churn
  insert into alunos (workspace_id, pessoa_id, produto_id, tag) values (ws, p2, pr, 'v0251');
  if exists (select 1 from v_pessoas_saiu where pessoa_id = p2) then raise exception 'X: quem tem aluno ativo não saiu'; end if;
  if (select receita from v_marketing_campanha where campanha_id = c1) <> 1890 then raise exception 'X: receita volta quando há aluno ativo'; end if;
end $t$;
select 'v0251: tudo OK' as resultado;
