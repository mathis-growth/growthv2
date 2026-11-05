-- v0.262: resultado por canal das campanhas anteriores. Termina com "v0262: tudo OK".
do $t$
declare ws uuid; pr uuid; c1 uuid; p1 uuid; p2 uuid; p3 uuid; j jsonb;
begin
  ws := provisionar_workspace('Teste v0262');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0262@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0262', 100) returning id into pr;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'C', 'finalizada', 'lancamento', pr, current_date - 20, current_date - 5, false) returning id into c1;
  insert into pessoas (workspace_id, nome, email) values (ws, 'A', 'a@exemplo.invalid') returning id into p1;
  insert into pessoas (workspace_id, nome, email) values (ws, 'B', 'b@exemplo.invalid') returning id into p2;
  insert into pessoas (workspace_id, nome, email) values (ws, 'C', 'c@exemplo.invalid') returning id into p3;
  delete from campanha_participacoes where campanha_id = c1;
  insert into campanha_participacoes (workspace_id, campanha_id, pessoa_id, canal, entrou_em) values (ws, c1, p1, 'meta_ads', now()), (ws, c1, p2, 'meta_ads', now()), (ws, c1, p3, 'email', now());
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p1, pr, c1, 'pix', 'aprovada', now(), 100), (ws, p3, pr, c1, 'pix', 'aprovada', now(), 100), (ws, p2, pr, c1, 'pix', 'cancelada', now(), 100);
  j := campanhas_canais_historico(array[c1]);
  if jsonb_array_length(j) <> 2 then raise exception 'X: linhas %', j; end if;
  if (select (x ->> 'leads')::int from jsonb_array_elements(j) x where x ->> 'canal' = 'meta_ads') <> 2 or (select (x ->> 'vendas')::int from jsonb_array_elements(j) x where x ->> 'canal' = 'meta_ads') <> 1 or (select (x ->> 'vendas')::int from jsonb_array_elements(j) x where x ->> 'canal' = 'email') <> 1 then raise exception 'X: números %', j; end if;
  delete from t.cfg where k = 'uid';
end $t$;
select 'v0262: tudo OK' as resultado;
