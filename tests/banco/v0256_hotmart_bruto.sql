-- v0.256: bruto completo da Hotmart e tratamento de clientes. Roda sobre o banco com todas as migrations. Termina com "v0256: tudo OK".
create or replace function t.ev256(p_id text, p_ev text, p_tx text, p_buyer jsonb) returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'event', p_ev, 'version', '2.0.0', 'creation_date', 1790000000000, 'campo_novo_da_hotmart', 'guardado',
    'data', jsonb_build_object('product', jsonb_build_object('id', '222', 'name', 'Curso'), 'buyer', p_buyer, 'producer', jsonb_build_object('name', 'Produtor', 'document', '999'),
      'purchase', jsonb_build_object('transaction', p_tx, 'approved_date', 1790000000000, 'price', jsonb_build_object('value', 500, 'currency_value', 'BRL'),
        'payment', jsonb_build_object('type', 'PIX', 'pix_code', 'codigo-pix'), 'order_bump', jsonb_build_object('is_order_bump', false))));
$$;
do $t$
declare ws uuid; pr uuid; pl uuid; ch text; tok text := 'hottok-de-teste-456'; j jsonb; u text; p1 uuid; p2 uuid; l hotmart_vendas_bruto; n int;
begin
  ws := provisionar_workspace('Teste v0256');
  u := gen_random_uuid()::text;
  insert into t.cfg values ('uid', u) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0256@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0256', 500) returning id into pr;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 10, 0) returning id into pl;
  ch := hotmart_configurar(ws, pl, tok) ->> 'chave';
  -- já existe um cliente com este e-mail, sem telefone nem documento
  insert into pessoas (workspace_id, nome, email) values (ws, 'Maria Antiga', 'maria@exemplo.invalid') returning id into p1;
  delete from t.cfg where k = 'uid'; insert into t.cfg values ('role', 'service_role') on conflict (k) do update set v = excluded.v;

  -- produto sem ligação: o bruto fica inteiro, mesmo sem tratar
  j := hotmart_webhook(ch, tok, t.ev256('b1', 'PURCHASE_APPROVED', 'HX1', '{"name":"Maria Nova","email":"MARIA@exemplo.invalid","checkout_phone_code":"55","checkout_phone":"35988887777","document":"529.982.247-25","address":{"city":"Lavras"}}'));
  select * into l from hotmart_vendas_bruto where workspace_id = ws and evento_id = 'b1';
  if l.id is null or l.tratamento <> 'revisar' then raise exception 'X: bruto %', to_jsonb(l); end if;
  if l.payload ->> 'campo_novo_da_hotmart' <> 'guardado' or l.payload -> 'data' -> 'buyer' ->> 'document' <> '529.982.247-25' or l.payload -> 'data' -> 'buyer' -> 'address' ->> 'city' <> 'Lavras'
     or l.payload -> 'data' -> 'producer' ->> 'document' <> '999' or l.payload -> 'data' -> 'purchase' -> 'payment' ->> 'pix_code' <> 'codigo-pix' then raise exception 'X: bruto incompleto %', l.payload; end if;

  -- ligar: o cliente existente é completado, sem criar outro
  insert into t.cfg values ('uid', u); update t.cfg set v = 'authenticated' where k = 'role';
  j := hotmart_ligar_produto(ws, '222', pr);
  if (j ->> 'resolvidos')::int <> 1 then raise exception 'X: ligar %', j; end if;
  if position('529.982' in hotmart_painel(ws)::text) > 0 or position('Lavras' in hotmart_painel(ws)::text) > 0 then raise exception 'X: painel mostra dado pessoal'; end if;
  if has_table_privilege('authenticated', 'public.hotmart_vendas_bruto', 'select') or has_table_privilege('anon', 'public.hotmart_vendas_bruto', 'select') then raise exception 'X: bruto acessível'; end if;
  delete from t.cfg where k = 'uid'; update t.cfg set v = 'service_role' where k = 'role';
  select count(*) into n from pessoas where workspace_id = ws;
  if n <> 1 then raise exception 'X: duplicou cliente (%)', n; end if;
  if not exists (select 1 from pessoas where id = p1 and nome = 'Maria Antiga' and documento = '52998224725' and telefone_norm is not null and extras -> 'endereco' ->> 'city' = 'Lavras' and status_funil = 'cliente') then raise exception 'X: não completou o cliente %', (select to_jsonb(x) from pessoas x where id = p1); end if;
  if not exists (select 1 from vendas where workspace_id = ws and id_externo = 'HX1' and pessoa_id = p1 and plataforma_id = pl and origem_dado = 'integracao') then raise exception 'X: venda sem cliente ou plataforma'; end if;

  -- mesmo cliente por telefone, depois por documento: segunda e terceira vendas, um cliente só
  j := hotmart_webhook(ch, tok, t.ev256('b2', 'PURCHASE_APPROVED', 'HX2', '{"name":"Outro nome","checkout_phone_code":"55","checkout_phone":"35988887777"}'));
  j := hotmart_webhook(ch, tok, t.ev256('b3', 'PURCHASE_APPROVED', 'HX3', '{"name":"Outro nome","document":"52998224725"}'));
  if (select count(*) from pessoas where workspace_id = ws) <> 1 or (select count(*) from vendas where workspace_id = ws and pessoa_id = p1) <> 3 then raise exception 'X: identificação do cliente'; end if;

  -- documento inválido não quebra: cria o cliente sem documento
  j := hotmart_webhook(ch, tok, t.ev256('b4', 'PURCHASE_APPROVED', 'HX4', '{"name":"Novo","email":"novo@exemplo.invalid","document":"111"}'));
  if j ->> 'situacao' <> 'processado' or not exists (select 1 from pessoas where workspace_id = ws and email = 'novo@exemplo.invalid' and documento is null) then raise exception 'X: documento inválido %', j; end if;

  -- comprador sem nenhum contato: a revisar, com o bruto guardado
  j := hotmart_webhook(ch, tok, t.ev256('b5', 'PURCHASE_APPROVED', 'HX5', '{"name":"Sem contato"}'));
  if j ->> 'situacao' <> 'revisar' or not exists (select 1 from hotmart_vendas_bruto where evento_id = 'b5') then raise exception 'X: sem contato %', j; end if;

  -- erro no tratamento não perde o bruto
  j := hotmart_webhook(ch, tok, jsonb_set(t.ev256('b6', 'PURCHASE_APPROVED', 'HX6', '{"email":"x@exemplo.invalid"}'), '{data,purchase,payment,installments_number}', '"nao-numero"'));
  if j ->> 'situacao' <> 'erro' or not exists (select 1 from hotmart_vendas_bruto where evento_id = 'b6' and tratamento = 'erro' and motivo is not null) then raise exception 'X: erro no tratamento %', j; end if;
  if exists (select 1 from vendas where workspace_id = ws and id_externo = 'HX6') then raise exception 'X: venda pela metade'; end if;

  -- repetido não grava de novo
  j := hotmart_webhook(ch, tok, t.ev256('b2', 'PURCHASE_APPROVED', 'HX2', '{}'));
  if j ->> 'situacao' <> 'repetido' or (select count(*) from hotmart_vendas_bruto where workspace_id = ws and evento_id = 'b2') <> 1 then raise exception 'X: repetido %', j; end if;
  delete from t.cfg where k = 'role';
end $t$;
select 'v0256: tudo OK' as resultado;
