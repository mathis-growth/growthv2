-- v0.258: order bump separado por item na Eduzz e na Hubla. Roda sobre o banco com todas as migrations. Termina com "v0258: tudo OK".
do $t$
declare ws uuid; pr uuid; b1 uuid; b2 uuid; ple uuid; plh uuid; u text; ce text; ch text; j jsonb; p_e jsonb; p_h jsonb;
begin
  ws := provisionar_workspace('Teste v0258');
  u := gen_random_uuid()::text;
  insert into t.cfg values ('uid', u) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0258@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0258', 1000) returning id into pr;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Bump A', 'bumpa_v0258', 97) returning id into b1;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Bump B', 'bumpb_v0258', 47) returning id into b2;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Eduzz', 10, 0) returning id into ple;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hubla', 10, 0) returning id into plh;
  ce := plataforma_configurar(ws, 'eduzz', ple, 'token-eduzz-1') ->> 'chave';
  ch := plataforma_configurar(ws, 'hubla', plh, 'token-hubla-1') ->> 'chave';
  perform plataforma_ligar_produto(ws, 'eduzz', 'E1', pr); perform plataforma_ligar_produto(ws, 'eduzz', 'EB1', b1);
  delete from t.cfg where k = 'uid'; insert into t.cfg values ('role', 'service_role') on conflict (k) do update set v = excluded.v;

  p_e := '{"id":"e1","event":"myeduzz.invoice_paid","data":{"id":"500","buyer":{"name":"Ana","email":"ana@exemplo.invalid"},"paid":{"currency":"BRL","value":1144},"paidAt":"2026-10-20T14:00:00.000Z","paymentMethod":"pix","orderBump":{"has":true,"isMainSale":true},"items":[{"productId":"E1","name":"Curso","isBump":false,"price":{"value":1000}},{"productId":"EB1","name":"Bump A","isBump":true,"price":{"value":97}},{"productId":"EB2","name":"Bump B","isBump":true,"price":{"value":47}}]}}';
  -- um bump sem ligação: nada entra pela metade, e a tela pede esse produto
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'e1', false, p_e);
  if j ->> 'situacao' <> 'revisar' or exists (select 1 from vendas where workspace_id = ws) then raise exception 'X: bump sem ligação %', j; end if;
  if (select produto_externo from eduzz_vendas_bruto where evento_id = 'e1') <> 'EB2' then raise exception 'X: painel não aponta o bump'; end if;
  insert into t.cfg values ('uid', u); update t.cfg set v = 'authenticated' where k = 'role';
  j := plataforma_ligar_produto(ws, 'eduzz', 'EB2', b2);
  delete from t.cfg where k = 'uid'; update t.cfg set v = 'service_role' where k = 'role';
  if (select count(*) from vendas where workspace_id = ws and plataforma_id = ple) <> 3 then raise exception 'X: Eduzz deveria ter 3 vendas %', j; end if;
  if (select valor_bruto from vendas where workspace_id = ws and produto_id = pr) <> 1000 or (select valor_bruto from vendas where workspace_id = ws and produto_id = b1) <> 97 or (select valor_bruto from vendas where workspace_id = ws and produto_id = b2) <> 47 then raise exception 'X: valores'; end if;
  if (select count(*) from vendas where workspace_id = ws and pedido_ref = '500') <> 3 or (select count(*) from vendas where workspace_id = ws and (extras ->> 'order_bump')::boolean) <> 2 then raise exception 'X: pedido e bump'; end if;
  if (select count(*) from pessoas where workspace_id = ws) <> 1 then raise exception 'X: cliente duplicado'; end if;
  -- reembolso alcança todos os itens da fatura
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'e2', false, jsonb_set(p_e, '{event}', '"myeduzz.invoice_refunded"'));
  if (select count(*) from vendas where workspace_id = ws and plataforma_id = ple and status = 'reembolsada') <> 3 then raise exception 'X: reembolso dos itens %', j; end if;
  -- o bump que chega também em fatura própria não conta duas vezes
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'e3', false, '{"id":"e3","event":"myeduzz.invoice_paid","data":{"id":"501","buyer":{"email":"ana@exemplo.invalid"},"paid":{"currency":"BRL","value":97},"orderBump":{"has":true,"isMainSale":false,"mainSaleId":"500"},"items":[{"productId":"EB1","name":"Bump A","isBump":true}]}}');
  if j ->> 'situacao' <> 'ignorado' or exists (select 1 from vendas where workspace_id = ws and id_externo = '501') then raise exception 'X: bump em dobro %', j; end if;

  -- Hubla
  insert into t.cfg values ('uid', u); update t.cfg set v = 'authenticated' where k = 'role';
  perform plataforma_ligar_produto(ws, 'hubla', 'H1', pr); perform plataforma_ligar_produto(ws, 'hubla', 'HB1', b1);
  delete from t.cfg where k = 'uid'; update t.cfg set v = 'service_role' where k = 'role';
  p_h := '{"type":"invoice.payment_succeeded","version":"2.0.0","event":{"product":{"id":"H1","name":"Curso"},"products":[{"id":"H1","name":"Curso","offers":[{"id":"o1","name":"Curso","amountCents":100000,"isOrderBump":false}]},{"id":"HB1","name":"Bump A","offers":[{"id":"o2","name":"Oferta bump","amountCents":9700,"isOrderBump":true}]}],"invoice":{"id":"HI1","status":"paid","currency":"BRL","paymentMethod":"pix","saleDate":"2026-10-20T15:00:00.000Z","amount":{"totalCents":109700},"payer":{"email":"hele@exemplo.invalid"}}}}';
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'h1', false, p_h);
  if j ->> 'situacao' <> 'processado' then raise exception 'X: Hubla %', j; end if;
  if (select valor_bruto from vendas where workspace_id = ws and id_externo = 'HI1') <> 1000 or (select valor_bruto from vendas where workspace_id = ws and id_externo = 'HI1:HB1') <> 97 then raise exception 'X: valores Hubla'; end if;
  -- fatura sem bump continua sendo uma venda só
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'h2', false, jsonb_set(jsonb_set(p_h, '{event,invoice,id}', '"HI2"'), '{event,products}', '[]'));
  if (select valor_bruto from vendas where workspace_id = ws and id_externo = 'HI2') <> 1097 then raise exception 'X: sem bump %', j; end if;
  delete from t.cfg where k = 'role';
end $t$;
select 'v0258: tudo OK' as resultado;
