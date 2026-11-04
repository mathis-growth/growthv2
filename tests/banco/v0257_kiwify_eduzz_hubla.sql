-- v0.257: bruto e tratamento de Kiwify, Eduzz e Hubla. Roda sobre o banco com todas as migrations. Termina com "v0257: tudo OK".
do $t$
declare ws uuid; pr uuid; plk uuid; ple uuid; plh uuid; u text; ck text; ce text; ch text; j jsonb; v vendas; ok_ boolean; ev jsonb; p_k jsonb; p_e jsonb; p_h jsonb;
begin
  ws := provisionar_workspace('Teste v0257');
  u := gen_random_uuid()::text;
  insert into t.cfg values ('uid', u) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0257@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0257', 500) returning id into pr;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Kiwify', 10, 0) returning id into plk;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Eduzz', 8, 0) returning id into ple;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hubla', 5, 0) returning id into plh;
  begin perform plataforma_configurar(ws, 'kiwify', plk, null); raise exception 'X: sem token'; exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform plataforma_configurar(ws, 'hotmart', plk, 'token-longo-1'); raise exception 'X: plataforma fora da lista'; exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  ck := plataforma_configurar(ws, 'kiwify', plk, 'token-kiwify-1') ->> 'chave';
  ce := plataforma_configurar(ws, 'eduzz', ple, 'token-eduzz-1') ->> 'chave';
  ch := plataforma_configurar(ws, 'hubla', plh, 'token-hubla-1') ->> 'chave';
  if (select segredo_hmac from plataforma_webhooks where workspace_id = ws and provedor = 'hubla') is not null then raise exception 'X: Hubla não guarda o token'; end if;
  perform plataforma_ligar_produto(ws, 'kiwify', 'K1', pr); perform plataforma_ligar_produto(ws, 'eduzz', 'E1', pr); perform plataforma_ligar_produto(ws, 'hubla', 'H1', pr);
  if has_table_privilege('authenticated', 'public.kiwify_vendas_bruto', 'select') or has_table_privilege('anon', 'public.hubla_vendas_bruto', 'select') then raise exception 'X: bruto acessível'; end if;
  delete from t.cfg where k = 'uid'; insert into t.cfg values ('role', 'service_role') on conflict (k) do update set v = excluded.v;

  -- segredo só com a chave da plataforma certa
  if plataforma_webhook_segredo(ck, 'kiwify') <> 'token-kiwify-1' then raise exception 'X: segredo'; end if;
  ok_ := false; begin perform plataforma_webhook_segredo(ck, 'eduzz'); exception when sqlstate '28000' then ok_ := true; end; if not ok_ then raise exception 'X: chave de outra plataforma'; end if;
  ok_ := false; begin perform plataforma_webhook_gravar(ch, 'hubla', 'errado', 'x', false, '{}'); exception when sqlstate '28000' then ok_ := true; end; if not ok_ then raise exception 'X: token Hubla errado'; end if;

  -- Kiwify
  p_k := '{"order_id":"KO1","order_status":"paid","webhook_event_type":"order_approved","payment_method":"credit_card","installments":3,"approved_date":"2026-10-20 09:15","created_at":"2026-10-20 09:10","Product":{"product_id":"K1","product_name":"Curso K"},"Customer":{"full_name":"Kiko Silva","email":"kiko@exemplo.invalid","mobile":"+5535999990001","CPF":"52998224725"},"Commissions":{"charge_amount":50000,"product_base_price":50000,"product_base_price_currency":"BRL"},"TrackingParameters":{"sck":"","src":"insta","utm_source":"insta","utm_campaign":"cmp"},"campo_novo":"guardado"}';
  j := plataforma_webhook_gravar(ck, 'kiwify', null, 'KO1:order_approved', false, p_k);
  if j ->> 'situacao' <> 'processado' then raise exception 'X: Kiwify %', j; end if;
  select * into v from vendas where workspace_id = ws and id_externo = 'KO1';
  if v.valor_bruto <> 500 or v.parcelas <> 3 or v.forma_pagamento <> 'cartao_credito' or v.plataforma_id <> plk or v.status <> 'aprovada' or v.taxa_plataforma <> 50 or v.utm_campaign <> 'cmp' then raise exception 'X: venda Kiwify %', to_jsonb(v); end if;
  if to_char(v.data_venda at time zone 'America/Sao_Paulo', 'YYYY-MM-DD HH24:MI') <> '2026-10-20 09:15' then raise exception 'X: data Kiwify %', v.data_venda; end if;
  if (select payload ->> 'campo_novo' from kiwify_vendas_bruto where evento_id = 'KO1:order_approved') <> 'guardado' then raise exception 'X: bruto Kiwify'; end if;
  if not exists (select 1 from pessoas where id = v.pessoa_id and documento = '52998224725') then raise exception 'X: cliente Kiwify'; end if;
  j := plataforma_webhook_gravar(ck, 'kiwify', null, 'KO1:order_approved', false, p_k);
  if j ->> 'situacao' <> 'repetido' then raise exception 'X: repetido Kiwify %', j; end if;
  j := plataforma_webhook_gravar(ck, 'kiwify', null, 'KO1:order_refunded', false, jsonb_set(jsonb_set(p_k, '{webhook_event_type}', '"order_refunded"'), '{order_status}', '"refunded"'));
  select * into v from vendas where id = v.id;
  if v.status <> 'reembolsada' or not exists (select 1 from estornos where venda_id = v.id) then raise exception 'X: reembolso Kiwify %', j; end if;
  j := plataforma_webhook_gravar(ck, 'kiwify', null, 'KO9:order_rejected', false, '{"order_id":"KO9","order_status":"refused","webhook_event_type":"order_rejected"}');
  if j ->> 'situacao' <> 'ignorado' then raise exception 'X: recusada %', j; end if;
  -- campos que não vieram: bruto guardado, venda a revisar
  j := plataforma_webhook_gravar(ck, 'kiwify', null, 'KO2:order_approved', false, '{"order_id":"KO2","order_status":"paid","webhook_event_type":"order_approved","Product":{"product_id":"K1"}}');
  if j ->> 'situacao' <> 'revisar' or not exists (select 1 from kiwify_vendas_bruto where evento_id = 'KO2:order_approved') then raise exception 'X: sem valor %', j; end if;

  -- Eduzz
  p_e := '{"id":"ev1","event":"myeduzz.invoice_paid","sentDate":"2026-10-20T15:00:00.000Z","data":{"id":"12345","status":"paid","buyer":{"name":"Edu Lima","email":"Edu@exemplo.invalid","cellphone":"35 99999-0002","document":"","address":{"city":"Lavras"}},"utm":{"source":"meta","content":"vd_x","campaign":"c1"},"tracker":{},"paid":{"currency":"BRL","value":301.5},"price":{"currency":"BRL","value":301.5},"installments":2,"paymentMethod":"pix","paidAt":"2026-10-20T14:00:00.000Z","createdAt":"2026-10-20T13:00:00.000Z","orderBump":{"has":false,"isMainSale":true},"items":[{"productId":"Z9","name":"Bump","isBump":true},{"productId":"E1","name":"Curso E","isBump":false}]}}';
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'ev1', false, p_e);
  if j ->> 'situacao' <> 'processado' then raise exception 'X: Eduzz %', j; end if;
  select * into v from vendas where workspace_id = ws and id_externo = '12345';
  if v.valor_bruto <> 301.5 or v.parcelas <> 2 or v.forma_pagamento <> 'pix' or v.plataforma_id <> ple or v.produto_id <> pr or v.utm_content <> 'vd_x' or v.extras -> 'itens' is null then raise exception 'X: venda Eduzz %', to_jsonb(v); end if;
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'ev2', false, jsonb_set(p_e, '{event}', '"myeduzz.invoice_chargeback"'));
  select * into v from vendas where id = v.id; if v.status <> 'chargeback' then raise exception 'X: chargeback Eduzz %', j; end if;
  j := plataforma_webhook_gravar(ce, 'eduzz', null, 'ev3', false, jsonb_set(p_e, '{event}', '"myeduzz.invoice_opened"'));
  if j ->> 'situacao' <> 'ignorado' then raise exception 'X: fatura aberta %', j; end if;

  -- Hubla
  p_h := '{"type":"invoice.payment_succeeded","version":"2.0.0","event":{"product":{"id":"H1","name":"Curso H"},"invoice":{"id":"HI1","status":"paid","currency":"BRL","installments":12,"paymentMethod":"credit_card","saleDate":"2026-10-20T15:00:00.000Z","amount":{"totalCents":112320,"installmentFeeCents":12320},"payer":{"firstName":"Hele","lastName":"Souza","email":"hele@exemplo.invalid","phone":"+5535999990003","document":"11144477735"},"billingAddress":{"city":"Lavras"},"paymentSession":{"utm":{"source":"google","content":"a1"},"params":{"SCK":"ze"}}}}}';
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'idem1', false, p_h);
  if j ->> 'situacao' <> 'processado' then raise exception 'X: Hubla %', j; end if;
  select * into v from vendas where workspace_id = ws and id_externo = 'HI1';
  if v.valor_bruto <> 1000 or v.parcelas <> 12 or v.plataforma_id <> plh or v.extras ->> 'sck' <> 'ze' then raise exception 'X: venda Hubla %', to_jsonb(v); end if;
  -- os dois avisos do mesmo pagamento: uma venda só
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'idem2', false, jsonb_set(p_h, '{type}', '"invoice.status_updated"'));
  if j ->> 'situacao' <> 'ignorado' or (select count(*) from vendas where workspace_id = ws and id_externo = 'HI1') <> 1 then raise exception 'X: aviso duplo %', j; end if;
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'idem3', false, jsonb_set(jsonb_set(p_h, '{type}', '"invoice.status_updated"'), '{event,invoice,status}', '"refunded"'));
  select * into v from vendas where id = v.id; if v.status <> 'reembolsada' then raise exception 'X: reembolso Hubla %', j; end if;
  -- evento de teste: guardado, sem criar venda
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'idem4', true, jsonb_set(p_h, '{event,invoice,id}', '"HI2"'));
  if j ->> 'situacao' <> 'ignorado' or exists (select 1 from vendas where workspace_id = ws and id_externo = 'HI2') or not exists (select 1 from hubla_vendas_bruto where evento_id = 'idem4') then raise exception 'X: sandbox %', j; end if;

  -- produto sem ligação aparece no painel e entra ao ligar
  j := plataforma_webhook_gravar(ch, 'hubla', 'token-hubla-1', 'idem5', false, jsonb_set(jsonb_set(p_h, '{event,invoice,id}', '"HI3"'), '{event,product,id}', '"H2"'));
  if j ->> 'situacao' <> 'revisar' then raise exception 'X: sem ligação %', j; end if;
  insert into t.cfg values ('uid', u); update t.cfg set v = 'authenticated' where k = 'role';
  j := plataforma_painel(ws, 'hubla');
  if jsonb_array_length(j -> 'sem_ligacao') <> 1 or j -> 'sem_ligacao' -> 0 ->> 'id' <> 'H2' or position('11144477735' in j::text) > 0 then raise exception 'X: painel %', j; end if;
  j := plataforma_ligar_produto(ws, 'hubla', 'H2', pr);
  if (j ->> 'resolvidos')::int < 1 or not exists (select 1 from vendas where workspace_id = ws and id_externo = 'HI3') then raise exception 'X: ligar %', j; end if;
  -- endereço novo sem colar o token mantém o segredo
  ce := plataforma_configurar(ws, 'kiwify', plk, null, true) ->> 'chave';
  if (select segredo_hmac from plataforma_webhooks where workspace_id = ws and provedor = 'kiwify') <> 'token-kiwify-1' then raise exception 'X: perdeu o segredo'; end if;
  delete from t.cfg where k = 'role';
end $t$;
select 'v0257: tudo OK' as resultado;
