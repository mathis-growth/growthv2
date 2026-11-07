-- v0.273: LTV com censura, desconto, mistura com o planejado, renovação projetada e teto de CAC. Termina com "v0273: tudo OK".
-- Rodar no PGlite: node pglite_run.mjs <repo> tests/banco/v0273_teto_cac.sql
do $t$
declare ws uuid; cur uuid; men uuid; ass uuid; p uuid; i int; d0 date; j jsonb; c jsonb; a jsonb; g jsonb; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  ws := provisionar_workspace('Teste v0273');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0273@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0273', 1000) returning id into cur;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria_v0273', 2000) returning id into men;
  insert into produtos (workspace_id, nome, tag, preco, tipo, recorrente, periodicidade, extras) values (ws, 'Assinatura', 'assin_v0273', 1200, 'assinatura', true, 'anual', '{"ltv_renovacao_pct": 50}') returning id into ass;

  -- Curso: 4 clientes antigos (13 meses), 2 deles compram a Mentoria no mês 3; 2 clientes novos (40 dias)
  d0 := (hoje - interval '13 months' - interval '5 days')::date;
  for i in 1 .. 4 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Antigo ' || i, 'ant' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, cur, 'pix', 'aprovada', d0, 1000);
    if i <= 2 then insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, men, 'pix', 'aprovada', d0 + interval '3 months' + interval '2 days', 2000); end if;
  end loop;
  for i in 1 .. 2 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Novo ' || i, 'novo' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, cur, 'pix', 'aprovada', hoje - 40, 1000);
  end loop;
  -- Assinatura anual: 3 clientes há 14 meses, 2 renovaram no mês 12
  d0 := (hoje - interval '14 months' - interval '5 days')::date;
  for i in 1 .. 3 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Assinante ' || i, 'ass' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, ass, 'pix', 'aprovada', d0, 1200);
    if i <= 2 then insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, ass, 'pix', 'aprovada', d0 + interval '12 months' + interval '2 days', 1200); end if;
  end loop;
  update vendas set taxa_plataforma = 0, impostos = 0, valor_liquido = valor_bruto, aprovada_em = data_venda where workspace_id = ws;
  -- custos de aquisição do período: mídia 600, equipe 200
  insert into custos_cac (workspace_id, descricao, valor, competencia, grupo) values (ws, 'Meta', 600, hoje - 10, 'midia'), (ws, 'Time', 200, hoje - 10, 'equipe');

  insert into ltv_config (workspace_id, taxa_modo, taxa_propria_aa, min_clientes) values (ws, 'propria', 0, 1);
  j := cac_teto(ws, hoje - 60, hoje);
  c := (select x from jsonb_array_elements(j -> 'produtos') x where x ->> 'nome' = 'Curso');
  a := (select x from jsonb_array_elements(j -> 'produtos') x where x ->> 'nome' = 'Assinatura');
  g := j -> 'geral';
  -- censura: a média simples daria (4000 + 4000 + 2000) / 6 = 1.666,67; o certo é 1.000 + metade × 2.000
  if (c ->> 'ltv')::numeric is distinct from 2000 or (c -> 'partes' ->> 'primeira')::numeric is distinct from 1000 or (c -> 'partes' ->> 'ascensao')::numeric is distinct from 1000 or c ->> 'fonte' is distinct from 'real' or (c ->> 'clientes')::int is distinct from 6 then
    raise exception 'A: curso %', c; end if;
  -- renovação: 1.200 + 2/3 × 1.200 no ano 2 + projeção de 50% do ano 2 no ano 3 (800 × 0,5 = 400)
  if (a ->> 'ltv')::numeric is distinct from 2400 or (a -> 'partes' ->> 'renovacao')::numeric is distinct from 800 or (a -> 'partes' ->> 'projetado')::numeric is distinct from 400 or (a ->> 'janela')::int is distinct from 36 or a ->> 'fonte' is distinct from 'misto' then
    raise exception 'B: assinatura %', a; end if;
  if exists (select 1 from jsonb_array_elements(j -> 'produtos') x where x ->> 'nome' = 'Mentoria') then raise exception 'C: mentoria não é produto de entrada'; end if;
  -- geral: média pesada pelos clientes (6 × 2.000 + 3 × 2.400) / 9
  if coalesce(abs((g ->> 'ltv')::numeric - 2133.33) > 0.01, true) or (g ->> 'clientes')::int is distinct from 9 then raise exception 'D: geral %', g; end if;
  if (g -> 'cac' ->> 'novos')::int is distinct from 2 or (g -> 'cac' ->> 'cac_midia')::numeric is distinct from 300 or (g -> 'cac' ->> 'cac_total')::numeric is distinct from 400 or (g -> 'cac' ->> 'fixo_cliente')::numeric is distinct from 100 then
    raise exception 'E: cac %', g -> 'cac'; end if;
  if coalesce(abs((g -> 'teto' ->> 'cac_total_max')::numeric - 1185.19) > 0.01, true) or coalesce(abs((g -> 'teto' ->> 'cac_midia_max')::numeric - 1085.19) > 0.01, true)
     or coalesce(abs((g -> 'teto' ->> 'cac_midia_eq')::numeric - 2033.33) > 0.01, true) or coalesce(abs((g -> 'teto' ->> 'ticket1')::numeric - 1066.67) > 0.01, true)
     or coalesce(abs((g -> 'teto' ->> 'roas_min')::numeric - 0.983) > 0.001, true) or coalesce(abs((g ->> 'ltv_cac')::numeric - 5.333) > 0.001, true) or (g ->> 'payback_meses')::int is distinct from 0 then
    raise exception 'F: teto %', g; end if;
  if (c -> 'cac' ->> 'midia')::numeric is distinct from 600 or (c -> 'cac' ->> 'novos')::int is distinct from 2 then raise exception 'G: cac do curso (rateio do custo sem campanha) %', c -> 'cac'; end if;
  if jsonb_array_length(j -> 'historico') <> 13 or not ((j -> 'historico' -> 12 ->> 'atual')::bool) then raise exception 'H: histórico %', j -> 'historico'; end if;

  -- desconto: 12% ao ano → a Mentoria do mês 3 vale 1.000 / 1,12^(3/12)
  update ltv_config set taxa_propria_aa = 12 where workspace_id = ws;
  c := (select x from jsonb_array_elements(cac_teto(ws, hoje - 60, hoje) -> 'produtos') x where x ->> 'nome' = 'Curso');
  if coalesce(abs((c ->> 'ltv')::numeric - (1000 + 1000 / power(1.12, 0.25))) > 0.05, true) then raise exception 'I: desconto %', c ->> 'ltv'; end if;

  -- pouco histórico (mínimo de 8 clientes) + LTV planejado de 3.000: mês 0 = 1.000; meses 1 a 11 = metade real (1.000) + metade plano (2.000)
  update ltv_config set taxa_propria_aa = 0, min_clientes = 8 where workspace_id = ws;
  update produtos set extras = extras || '{"ltv_planejado": 3000}' where id = cur;
  c := (select x from jsonb_array_elements(cac_teto(ws, hoje - 60, hoje) -> 'produtos') x where x ->> 'nome' = 'Curso');
  if coalesce(abs((c ->> 'ltv')::numeric - 2500) > 0.01, true) or c ->> 'fonte' is distinct from 'misto' then raise exception 'J: misto %', c; end if;

  -- produto novo, sem clientes, só com o planejado
  insert into produtos (workspace_id, nome, tag, preco, extras) values (ws, 'Lançamento', 'lanc_v0273', 500, '{"ltv_planejado": 900, "ltv_meta": 2}') returning id into p;
  c := (select x from jsonb_array_elements(cac_teto(ws, hoje - 60, hoje) -> 'produtos') x where x ->> 'nome' = 'Lançamento');
  if c ->> 'fonte' is distinct from 'planejado' or (c ->> 'ltv')::numeric is distinct from 900 or (c -> 'teto' ->> 'cac_total_max')::numeric is distinct from 450 or (c -> 'teto' ->> 'ticket1')::numeric is distinct from 500 then raise exception 'K: planejado %', c; end if;

  -- taxa: Selic do dia
  update ltv_config set taxa_modo = 'selic' where workspace_id = ws;
  insert into selic_diaria values (hoje - 1, 15) on conflict (dia) do update set meta_aa = 15;
  j := ltv_taxa(ws, hoje);
  if j ->> 'fonte' is distinct from 'selic' or (j ->> 'aa')::numeric is distinct from 15 or coalesce(abs((j ->> 'am')::numeric - 0.011715) > 0.000001, true) then raise exception 'L: selic %', j; end if;
  delete from selic_diaria;
  if ltv_taxa(ws, hoje) ->> 'fonte' is distinct from 'padrao' then raise exception 'M: sem selic guardada usa 12%%'; end if;

  -- exemplo da aula (Kaplan-Meier): 100 clientes, 20 saem no 1º mês (80%), 20 dos 80 no 2º (75% → 60%); assinatura de 100 por mês, janela de 3 meses
  update ltv_config set taxa_modo = 'propria', taxa_propria_aa = 0, min_clientes = 1 where workspace_id = ws;
  insert into produtos (workspace_id, nome, tag, preco, tipo, recorrente, periodicidade, extras) values (ws, 'Clube', 'clube_v0273', 100, 'assinatura', true, 'mensal', '{"ltv_janela": 3}') returning id into men;
  d0 := (hoje - interval '4 months' - interval '5 days')::date;
  for i in 1 .. 100 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Clube ' || i, 'clube' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto, valor_liquido, taxa_plataforma, impostos, aprovada_em) values (ws, p, men, 'pix', 'aprovada', d0, 100, 100, 0, 0, d0);
    if i <= 80 then insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto, valor_liquido, taxa_plataforma, impostos, aprovada_em) values (ws, p, men, 'pix', 'aprovada', d0 + interval '1 month' + interval '1 day', 100, 100, 0, 0, d0 + interval '1 month' + interval '1 day'); end if;
    if i <= 60 then insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto, valor_liquido, taxa_plataforma, impostos, aprovada_em) values (ws, p, men, 'pix', 'aprovada', d0 + interval '2 months' + interval '1 day', 100, 100, 0, 0, d0 + interval '2 months' + interval '1 day'); end if;
  end loop;
  update vendas set taxa_plataforma = 0, impostos = 0, valor_liquido = valor_bruto where workspace_id = ws and produto_id = men;
  c := (select x from jsonb_array_elements(cac_teto(ws, hoje - 60, hoje) -> 'produtos') x where x ->> 'nome' = 'Clube');
  -- LTV = ARPU × Σ S(t) = 100 × (1 + 0,8 + 0,6) = 240
  if (c ->> 'ltv')::numeric is distinct from 240 or (c -> 'partes' ->> 'primeira')::numeric is distinct from 100 or (c -> 'partes' ->> 'renovacao')::numeric is distinct from 140
     or c -> 'acumulado' is distinct from '[100, 180, 240]'::jsonb then raise exception 'KM: clube %', c; end if;

  -- outro workspace não lê
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  begin perform cac_teto(ws, hoje - 60, hoje); raise exception 'N: leu de outro workspace';
  exception when others then if sqlerrm not like '%sem acesso%' then raise; end if; end;
  delete from t.cfg where k = 'uid';
end $t$;

-- leitura da resposta do Banco Central
create table if not exists net._http_response (id bigint, status_code int, content text);
insert into net._http_response values (77, 200, '[{"data":"01/10/2026","valor":"15.00"},{"data":"02/10/2026","valor":"14,75"},{"data":"x","valor":"1"}]');
insert into sistema_config (chave, valor) values ('selic_pedido', '77') on conflict (chave) do update set valor = excluded.valor;
do $t$ begin
  if selic_ler() <> 2 or (select meta_aa from selic_diaria where dia = '2026-10-02') <> 14.75 then raise exception 'O: selic_ler'; end if;
end $t$;
select 'v0273: tudo OK' as resultado;
