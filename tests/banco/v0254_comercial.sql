-- v0.254: comercial da campanha. Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "v0254: tudo OK".
do $t$
declare ws uuid; pr uuid; c1 uuid; e1 uuid; e2 uuid; e3 uuid; p1 uuid; v1 uuid; v2 uuid; v3 uuid; j jsonb; o uuid; n int; hoje_ date := current_date; rg comissao_regras; cm numeric;
begin
  ws := provisionar_workspace('Teste v0254');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0254@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0254', 1000) returning id into pr;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'Campanha', 'ativa', 'lancamento', pr, hoje_ - 5, hoje_ + 5, false) returning id into c1;
  insert into ofertas (workspace_id, produto_id, nome, papel, preco) values (ws, pr, 'Oferta', 'principal', 1000) returning id into o;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, oferta_id, nome, papel, preco) values (ws, c1, pr, o, 'Oferta', 'principal', 1000);
  insert into equipe (workspace_id, nome, vinculo, externo) values (ws, 'Ana interna', 'vendedor', false) returning id into e1;
  insert into equipe (workspace_id, nome, vinculo, externo) values (ws, 'Beto externo', 'vendedor', true) returning id into e2;
  insert into equipe (workspace_id, nome, vinculo) values (ws, 'Caio designer', 'equipe') returning id into e3;
  insert into comissao_regras (workspace_id, equipe_id, escopo, oferta_id, percentual, base, sobre) values (ws, e1, 'oferta', o, 10, 'bruto', 'proprias');

  j := campanha_comercial(c1);
  if jsonb_array_length(j -> 'candidatos') <> 1 or j -> 'candidatos' -> 0 ->> 'nome' <> 'Ana interna' or (j -> 'candidatos' -> 0 ->> 'comissao_pct')::numeric <> 10 then raise exception 'X: candidatos pela oferta %', j; end if;
  if jsonb_array_length(j -> 'outros') <> 1 or j -> 'outros' -> 0 ->> 'nome' <> 'Beto externo' or (j -> 'outros' -> 0 ->> 'externo')::boolean is not true then raise exception 'X: outros vendedores %', j; end if;

  n := campanha_comercial_salvar(c1, jsonb_build_array(jsonb_build_object('equipe_id', e1, 'comissao_pct', 20, 'base', 'bruto', 'meta_vendas', 30, 'codigo', 'vd_ana'), jsonb_build_object('equipe_id', e2, 'comissao_pct', 5, 'base', 'bruto', 'meta_vendas', 10, 'codigo', 'vd_beto')));
  if n <> 2 then raise exception 'X: salvar %', n; end if;
  select * into rg from comissao_regras where equipe_id = e1 and escopo = 'campanha';
  if rg.percentual <> 20 or rg.sobre <> 'proprias' or rg.campanha_id <> c1 then raise exception 'X: regra da campanha'; end if;

  insert into pessoas (workspace_id, nome, email, campanha_id) values (ws, 'Cliente', 'cli@exemplo.invalid', c1) returning id into p1;
  -- venda com o código no utm_content: liga ao vendedor e à campanha; a comissão da campanha vale mais que a da oferta
  insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto, utm_content) values (ws, p1, pr, 'pix', 'aprovada', now(), 1000, 'vd_ana') returning id into v1;
  if (select vendedor_id from vendas where id = v1) <> e1 or (select campanha_id from vendas where id = v1) <> c1 then raise exception 'X: venda pelo código não ligou'; end if;
  select valor into cm from comissoes where venda_id = v1 and equipe_id = e1;
  if cm is distinct from 200.00 then raise exception 'X: comissão da campanha sobre a venda (%)', cm; end if;
  -- código em extras.sck
  insert into vendas (workspace_id, pessoa_id, produto_id, forma_pagamento, status, data_venda, valor_bruto, extras) values (ws, p1, pr, 'pix', 'aprovada', now(), 500, '{"sck":"vd_beto"}') returning id into v2;
  if (select vendedor_id from vendas where id = v2) <> e2 then raise exception 'X: sck em extras'; end if;
  -- vendedor informado à mão continua valendo
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, forma_pagamento, status, data_venda, valor_bruto, utm_content, vendedor_id) values (ws, p1, pr, c1, 'pix', 'aprovada', now(), 300, 'vd_ana', e2) returning id into v3;
  if (select vendedor_id from vendas where id = v3) <> e2 then raise exception 'X: vendedor manual'; end if;

  j := campanha_comercial(c1);
  if jsonb_array_length(j -> 'vendedores') <> 2 then raise exception 'X: vendedores %', j; end if;
  if (select (x ->> 'vendas')::int from jsonb_array_elements(j -> 'vendedores') x where x ->> 'codigo' = 'vd_ana') <> 1 or (select (x ->> 'vendas')::int from jsonb_array_elements(j -> 'vendedores') x where x ->> 'codigo' = 'vd_beto') <> 2 then raise exception 'X: vendas por vendedor %', j; end if;
  if (select (x ->> 'comissao')::numeric from jsonb_array_elements(j -> 'vendedores') x where x ->> 'codigo' = 'vd_ana') <> 200 then raise exception 'X: comissão no resultado %', j; end if;

  -- mudar a comissão recalcula a venda já feita
  n := campanha_comercial_salvar(c1, jsonb_build_array(jsonb_build_object('equipe_id', e1, 'comissao_pct', 30, 'base', 'bruto', 'meta_vendas', 30, 'codigo', 'vd_ana'), jsonb_build_object('equipe_id', e2, 'comissao_pct', 5, 'base', 'bruto', 'meta_vendas', 10, 'codigo', 'vd_beto')));
  select valor into cm from comissoes where venda_id = v1 and equipe_id = e1;
  if cm is distinct from 300.00 then raise exception 'X: comissão recalculada (%)', cm; end if;
  if (select count(*) from comissao_regras where equipe_id = e1 and escopo = 'campanha') <> 1 then raise exception 'X: regra duplicada'; end if;

  -- tirar da lista: a regra para de valer; o da oferta volta a valer
  n := campanha_comercial_salvar(c1, jsonb_build_array(jsonb_build_object('equipe_id', e2, 'comissao_pct', 5, 'base', 'bruto', 'meta_vendas', 10, 'codigo', 'vd_beto')));
  if exists (select 1 from comissao_regras where equipe_id = e1 and escopo = 'campanha' and ativo) or exists (select 1 from campanha_vendedores where equipe_id = e1) then raise exception 'X: tirar vendedor'; end if;
  j := campanha_comercial(c1);
  if j -> 'candidatos' -> 0 ->> 'nome' <> 'Ana interna' then raise exception 'X: volta a candidato %', j; end if;
end $t$;
select 'v0254: tudo OK' as resultado;
