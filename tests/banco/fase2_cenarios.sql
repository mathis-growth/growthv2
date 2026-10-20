\set ON_ERROR_STOP on
do $$
declare ws uuid := gen_random_uuid(); c uuid; cc1 uuid; cc2 uuid; an uuid; p1 uuid; p2 uuid; pr uuid; pb uuid; v1 uuid; v2 uuid; j jsonb; x uuid; ab uuid;
begin
  insert into workspaces (id, nome) values (ws, 'F2');
  insert into canais (workspace_id, codigo, nome, utm_source) values (ws, 'meta_ads', 'Meta Ads', 'facebook'), (ws, 'google_ads', 'Google Ads', 'google');
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Black', current_date - 10) returning id into c;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, temperatura) values (ws, c, 'meta_ads', 'bf_meta_frio', 'frio') returning id into cc1;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, temperatura) values (ws, c, 'meta_ads', 'bf_meta_quente', 'quente') returning id into cc2;
  insert into anuncios (workspace_id, campanha_canal_id, nome) values (ws, cc1, 'Criativo 1') returning id into an;
  insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo) values (ws, an, current_date - 3, 1000, 50, 400);
  -- 1. junção automática por telefone
  p1 := pessoa_resolver(ws, 'Bia', 'bia@x.com', null);
  p2 := pessoa_resolver(ws, 'Bia Lima', null, '11977776666');
  assert p1 <> p2;
  x := pessoa_resolver(ws, 'Bia Lima', 'bia@x.com', '11977776666');
  assert x = p2 and not exists (select 1 from pessoas where id = p1), 'e-mail sem telefone juntou no cadastro do telefone';
  assert (select email from pessoas where id = p2) = 'bia@x.com' and exists (select 1 from pessoas_mesclagens where pessoa_removida = p1 and motivo like 'Automático%'), 'junção automática registrada';
  -- 2/3. captação e duplicidade
  insert into alunos (workspace_id, pessoa_id, entrou_em) values (ws, p2, now() - interval '100 days');
  j := registrar_captura(ws, c, 'Bia Lima', 'bia@x.com', '11977776666', jsonb_build_object('utm_source', 'facebook', 'utm_campaign', 'bf_meta_frio', 'em', now() - interval '3 days'));
  assert (j->>'repetida')::boolean is false, 'primeira captura';
  j := registrar_captura(ws, c, 'Bia', null, '(11) 97777-6666', '{"utm_source":"facebook","utm_campaign":"bf_meta_frio"}');
  assert (j->>'repetida')::boolean and (j->>'pessoa_id')::uuid = p2, 'segunda vira repetida';
  j := registrar_captura(ws, c, 'Caio', 'caio@x.com', null, '{"utm_source":"google"}');
  update pessoas set qualificacao = 'qualificado' where email = 'caio@x.com';
  j := campanha_captacao(c);
  assert (j->>'leads')::int = 2 and (j->>'tentativas')::int = 3 and (j->>'repetidas')::int = 1, 'captação: ' || j::text;
  assert (j->>'alunos')::int = 1 and (j->>'qualificados')::int = 1, 'segmentos: ' || j::text;
  assert j->'por_canal' @> '[{"canal":"meta_ads","temperatura":"frio","leads":1}]' and j->'por_canal' @> '[{"canal":"google_ads","leads":1}]', 'canal e temperatura: ' || j::text;
  -- 6. abandono e recuperação
  insert into produtos (workspace_id, nome) values (ws, 'Curso') returning id into pr;
  insert into produtos (workspace_id, nome) values (ws, 'Bump') returning id into pb;
  ab := abandono_registrar(ws, c, 'Bia', null, '11977776666', pr, 997, now() - interval '2 days', 'HTX-1', 'integracao');
  assert abandono_registrar(ws, c, 'Bia', null, '11977776666', pr, 997, now() - interval '2 days', 'HTX-1', 'integracao') = ab, 'abandono idempotente';
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, valor_bruto, valor_a_receber, status, data_venda, utm_source, utm_campaign)
    values (ws, p2, pr, c, 997, 997, 'aprovada', now() - interval '1 day', 'facebook', 'bf_meta_frio') returning id into v1;
  assert (select recuperado_venda_id from checkout_abandonos where id = ab) = v1, 'abandono recuperado pela venda';
  j := abandonos_resumo(ws, current_date - 10, current_date);
  assert (j->>'recuperados')::int = 1 and (j->>'taxa_recuperacao')::numeric = 100, 'resumo abandonos: ' || j::text;
  -- 5. ofertas e aceite
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco) values (ws, c, pr, 'Curso', 'principal', 997), (ws, c, pb, 'Bump', 'order_bump', 47);
  insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, valor_bruto, valor_a_receber, status, pedido_ref) values (ws, p2, pb, c, 47, 47, 'aprovada', 'PED1') returning id into v2;
  j := campanha_ofertas_resultado(ws, c);
  assert j @> '[{"papel":"order_bump","aceite":100.0}]', 'aceite do bump: ' || j::text;
  -- 7. atribuição
  assert (select canal || '/' || temperatura from venda_atribuicoes where venda_id = v1 and modelo = 'ultimo_toque') = 'meta_ads/frio', 'último toque = origem da venda';
  assert (select canal from venda_atribuicoes where venda_id = v1 and modelo = 'primeiro_toque') = 'meta_ads', 'primeiro toque';
  assert (select evidencia->>'fonte' from venda_atribuicoes where venda_id = v2 and modelo = 'ultimo_toque') = 'toque', 'bump sem UTM usa o último toque';
  j := vendas_por_canal(ws, current_date - 10, current_date);
  assert j->>'modelo' = 'ultimo_toque' and j->'canais' @> '[{"canal":"meta_ads","temperatura":"frio","investimento":400,"vendas":2,"roas":2.61}]', 'vendas por canal: ' || j::text;
  update vendas set status = 'reembolsada' where id = v2;
  assert not exists (select 1 from venda_atribuicoes where venda_id = v2), 'reembolsada sai da atribuição';
  -- 8. metas
  insert into campanha_metas (workspace_id, campanha_id, tipo, valor) values (ws, c, 'leads', 4), (ws, c, 'cpl', 150), (ws, c, 'roas', 0);
  insert into campanha_metas (workspace_id, campanha_id, tipo, valor, canal, temperatura) values (ws, c, 'vendas', 1, 'meta_ads', 'frio');
  insert into campanha_metas (workspace_id, campanha_id, tipo, valor, segmento) values (ws, c, 'leads', 1, 'aluno');
  j := campanha_metas_painel(c);
  assert j @> '[{"tipo":"leads","meta":4,"realizado":2,"pct":50.0,"ok":false}]', 'meta leads: ' || j::text;
  assert j @> '[{"tipo":"cpl","realizado":200.00,"ok":false,"menor_melhor":true}]', 'meta cpl';
  assert j @> '[{"tipo":"roas","pct":null}]', 'meta zero sem %';
  assert j @> '[{"tipo":"vendas","canal":"meta_ads","realizado":1,"ok":true}]', 'meta por canal e temperatura';
  assert j @> '[{"tipo":"leads","segmento":"aluno","realizado":1}]', 'meta por segmento';
  raise notice 'v0.89: fase 2 OK';
end $$;
