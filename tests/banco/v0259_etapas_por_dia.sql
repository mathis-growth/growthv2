-- v0.259: série por dia das etapas da campanha bate com o total de campanha_funil_etapas. Termina com "v0259: tudo OK".
do $t$
declare ws uuid; pr uuid; c1 uuid; e1 uuid; e2 uuid; e3 uuid; p1 uuid; p2 uuid; j jsonb; tot jsonb; h date := current_date; soma numeric;
begin
  ws := provisionar_workspace('Teste v0259');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0259@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0259', 100) returning id into pr;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'C', 'ativa', 'lancamento', pr, h - 10, h + 5, false) returning id into c1;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem) values (ws, c1, 1, 'aquisicao', 'leads', 'Página · Leads', 'numero', 'leads') returning id into e1;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem, metrica) values (ws, c1, 2, 'conversao', 'receita', 'Checkout · Receita', 'brl', 'vendas', 'receita') returning id into e2;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem) values (ws, c1, 3, 'aquecimento', 'saidas', 'Grupo · Saídas', 'numero', 'manual') returning id into e3;
  insert into pessoas (workspace_id, nome, email, campanha_id, criado_em) values (ws, 'A', 'a@exemplo.invalid', c1, now() - interval '2 days') returning id into p1;
  insert into pessoas (workspace_id, nome, email, campanha_id, criado_em) values (ws, 'B', 'b@exemplo.invalid', c1, now() - interval '1 day') returning id into p2;
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, forma_pagamento, status, data_venda, valor_bruto) values (ws, p1, pr, c1, 'pix', 'aprovada', now() - interval '1 day', 100), (ws, p2, pr, c1, 'pix', 'aprovada', now() - interval '1 day', 100);
  insert into campanha_etapa_valores (workspace_id, campanha_etapa_id, data, valor, origem) values (ws, e3, h - 3, 7, 'manual');
  j := campanha_etapas_dia(c1, h - 10, h); tot := campanha_funil_etapas(c1, h - 10, h);
  if jsonb_array_length(j) <> 3 then raise exception 'X: etapas %', j; end if;
  for e1, soma in select (x ->> 'id')::uuid, (select coalesce(sum(v::numeric), 0) from jsonb_each_text(x -> 'dias') as d(k, v)) from jsonb_array_elements(j) x loop
    if soma <> (select (y ->> 'valor')::numeric from jsonb_array_elements(tot) y where (y ->> 'id')::uuid = e1) then raise exception 'X: soma diferente do total, etapa % (%), %', e1, soma, tot; end if;
  end loop;
  if (select (x -> 'dias' ->> (h - 3)::text)::numeric from jsonb_array_elements(j) x where (x ->> 'id')::uuid = e3) <> 7 then raise exception 'X: manual %', j; end if;
  delete from t.cfg where k = 'uid';
end $t$;
select 'v0259: tudo OK' as resultado;
