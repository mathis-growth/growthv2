-- v0.274: teto de CAC por turma de entrada. Termina com "v0274: tudo OK".
-- Rodar no PGlite: node pglite_run.mjs <repo> tests/banco/v0274_teto_turma.sql
do $t$
declare ws uuid; cur uuid; men uuid; p uuid; i int; d0 date; j jsonb; c jsonb; hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  ws := provisionar_workspace('Teste v0274');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0274@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0274', 1000) returning id into cur;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria_v0274', 2000) returning id into men;
  d0 := (hoje - interval '13 months' - interval '5 days')::date;
  for i in 1 .. 4 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Antigo ' || i, 'ant' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, cur, 'pix', 'aprovada', d0, 1000);
    if i <= 2 then insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, men, 'pix', 'aprovada', d0 + interval '3 months' + interval '2 days', 2000); end if;
  end loop;
  for i in 1 .. 2 loop
    insert into pessoas (workspace_id, nome, email) values (ws, 'Novo ' || i, 'novo' || i || '@exemplo.invalid') returning id into p;
    insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p, cur, 'pix', 'aprovada', hoje - 40, 1200);
  end loop;
  update vendas set taxa_plataforma = 0, impostos = 0, valor_liquido = valor_bruto, aprovada_em = data_venda where workspace_id = ws;
  insert into ltv_config (workspace_id, taxa_modo, taxa_propria_aa, min_clientes) values (ws, 'propria', 0, 1);

  -- sem filtro: as duas turmas (mês 0 = (4×1.000 + 2×1.200) / 6; mês 3 = 4.000 / 4)
  c := (select x from jsonb_array_elements(cac_teto(ws, hoje - 60, hoje) -> 'produtos') x where x ->> 'nome' = 'Curso');
  if abs((c ->> 'ltv')::numeric - 2066.67) > 0.01 then raise exception 'A: sem filtro %', c ->> 'ltv'; end if;
  -- só a turma antiga
  j := cac_teto(ws, hoje - 60, hoje, null, 12, jsonb_build_object('entrada_fim', hoje - 300));
  c := (select x from jsonb_array_elements(j -> 'produtos') x where x ->> 'nome' = 'Curso');
  if (c ->> 'ltv')::numeric is distinct from 2000 or (c ->> 'clientes')::int is distinct from 4 or (j -> 'geral' -> 'teto' ->> 'ticket1')::numeric is distinct from 1000
     or (j -> 'filtro' ->> 'entrada_fim')::date is distinct from hoje - 300 then raise exception 'B: turma antiga %', j -> 'geral'; end if;
  -- só a turma nova: viveu só o mês 0; o resto falta (sem plano)
  j := cac_teto(ws, hoje - 60, hoje, null, 12, jsonb_build_object('entrada_ini', hoje - 60, 'entrada_fim', hoje));
  c := (select x from jsonb_array_elements(j -> 'produtos') x where x ->> 'nome' = 'Curso');
  if (c ->> 'ltv')::numeric is distinct from 1200 or (c ->> 'clientes')::int is distinct from 2 or not (c ->> 'incompleto')::bool or (j -> 'geral' -> 'teto' ->> 'ticket1')::numeric is distinct from 1200 then raise exception 'C: turma nova %', c; end if;
  -- no mês a mês, a turma nova só aparece depois de entrar
  if (j -> 'historico' -> 0 -> 'geral' ->> 'ltv') is not null then raise exception 'D: turma antes de existir %', j -> 'historico' -> 0; end if;
  begin perform cac_teto(ws, hoje - 60, hoje, null, 12, jsonb_build_object('entrada_ini', hoje, 'entrada_fim', hoje - 1)); raise exception 'E: datas invertidas';
  exception when others then if sqlerrm not like '%antes da inicial%' then raise; end if; end;
  delete from t.cfg where k = 'uid';
end $t$;
select 'v0274: tudo OK' as resultado;
