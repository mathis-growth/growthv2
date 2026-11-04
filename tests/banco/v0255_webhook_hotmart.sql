-- v0.255: webhook da Hotmart. Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "v0255: tudo OK".
create or replace function t.ev255(p_id text, p_ev text, p_tx text, p_prod text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'event', p_ev, 'version', '2.0.0', 'creation_date', 1790000000000,
    'data', jsonb_build_object(
      'product', jsonb_build_object('id', p_prod, 'ucode', 'uc-' || p_prod, 'name', 'Curso na Hotmart'),
      'buyer', jsonb_build_object('name', 'Maria Compradora', 'email', 'maria@exemplo.invalid', 'checkout_phone_code', '55', 'checkout_phone', '35999998888', 'document', '12345678900', 'address', jsonb_build_object('city', 'Lavras')),
      'producer', jsonb_build_object('name', 'Produtor', 'document', '999'),
      'purchase', jsonb_build_object('transaction', p_tx, 'approved_date', 1790000000000, 'order_date', 1790000000000, 'status', 'APPROVED',
        'price', jsonb_build_object('value', 1000, 'currency_value', 'BRL'), 'full_price', jsonb_build_object('value', 1100, 'currency_value', 'BRL'),
        'payment', jsonb_build_object('type', 'CREDIT_CARD', 'installments_number', 12, 'pix_code', 'segredo'),
        'offer', jsonb_build_object('code', 'off1'), 'origin', jsonb_build_object('sck', '', 'src', 'instagram'),
        'order_bump', jsonb_build_object('is_order_bump', false)) || p_extra)) ;
$$;
do $t$
declare ws uuid; ws2 uuid; pr uuid; pl uuid; c1 uuid; o uuid; e1 uuid; v vendas; j jsonb; ch text; ch2 text; tok text := 'hottok-de-teste-123'; n int; ok_ boolean;
begin
  ws := provisionar_workspace('Teste v0255');
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into auth.users (id, email) values (auth.uid(), 'v0255@exemplo.invalid');
  insert into workspace_membros (workspace_id, user_id) values (ws, auth.uid());
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso_v0255', 1000) returning id into pr;
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 10, 0) returning id into pl;
  insert into ofertas (workspace_id, produto_id, nome, papel, preco) values (ws, pr, 'À vista', 'principal', 1000) returning id into o;
  insert into campanhas (workspace_id, nome, status, modelo, produto_id, data_inicio, data_fim, projeto_auto) values (ws, 'Campanha', 'ativa', 'lancamento', pr, '2026-01-01', '2027-12-31', false) returning id into c1;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, oferta_id, nome, papel, preco) values (ws, c1, pr, o, 'À vista', 'principal', 1000);

  begin perform hotmart_configurar(ws, pl, null); raise exception 'X: sem hottok'; exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  j := hotmart_configurar(ws, pl, tok); ch := j ->> 'chave';
  if ch !~ '^gw_' then raise exception 'X: chave %', j; end if;
  if exists (select 1 from plataforma_webhooks where segredo_hash = tok) then raise exception 'X: hottok em texto puro'; end if;

  -- daqui em diante, como a função: sem usuário e com o papel de serviço
  delete from t.cfg where t.cfg.k = 'uid'; insert into t.cfg values ('role', 'service_role') on conflict (k) do update set v = excluded.v;

  -- hottok ou chave errados não entram
  ok_ := false; begin perform hotmart_webhook(ch, 'errado', t.ev255('e0', 'PURCHASE_APPROVED', 'HP0', '111')); exception when sqlstate '28000' then ok_ := true; end;
  if not ok_ then raise exception 'X: hottok errado passou'; end if;
  ok_ := false; begin perform hotmart_webhook('gw_' || repeat('0', 64), tok, t.ev255('e0', 'PURCHASE_APPROVED', 'HP0', '111')); exception when sqlstate '28000' then ok_ := true; end;
  if not ok_ then raise exception 'X: chave errada passou'; end if;

  -- produto sem ligação: não perde o evento, fica a revisar
  j := hotmart_webhook(ch, tok, t.ev255('e1', 'PURCHASE_APPROVED', 'HP1', '111'));
  if j ->> 'situacao' <> 'revisar' then raise exception 'X: sem ligação %', j; end if;
  if exists (select 1 from vendas where workspace_id = ws) then raise exception 'X: criou venda sem produto'; end if;
  if exists (select 1 from plataforma_eventos where evento_id = 'e1' and (payload::text like '%12345678900%' or payload::text like '%Lavras%' or payload::text like '%segredo%')) then raise exception 'X: dado sensível no registro'; end if;

  -- ligar e reprocessar (volta o usuário, que é quem liga pela tela)
  insert into t.cfg values ('uid', (select user_id::text from workspace_membros where workspace_id = ws limit 1)); update t.cfg set v = 'authenticated' where t.cfg.k = 'role';
  j := hotmart_ligar_produto(ws, '111', pr);
  if (j ->> 'resolvidos')::int <> 1 then raise exception 'X: ligar %', j; end if;
  j := hotmart_painel(ws);
  if (j ->> 'configurado')::boolean is not true or (j ->> 'revisar')::int <> 0 or jsonb_array_length(j -> 'sem_ligacao') <> 0 then raise exception 'X: painel %', j; end if;
  select * into v from vendas where workspace_id = ws and id_externo = 'HP1';
  if v.id is null or v.status <> 'aprovada' or v.valor_bruto <> 1000 or v.parcelas <> 12 or v.forma_pagamento <> 'cartao_credito' or v.origem_dado <> 'integracao' then raise exception 'X: venda %', to_jsonb(v); end if;
  if v.taxa_plataforma <> 100 or v.oferta_id <> o or v.campanha_id <> c1 or v.utm_source <> 'instagram' or v.plataforma_id <> pl then raise exception 'X: ligações da venda %', to_jsonb(v); end if;
  if not exists (select 1 from pessoas where id = v.pessoa_id and email = 'maria@exemplo.invalid' and status_funil = 'cliente') then raise exception 'X: pessoa'; end if;
  if not exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then raise exception 'X: sem lançamento'; end if;
  if not exists (select 1 from contas_receber where venda_id = v.id) then raise exception 'X: sem conta a receber'; end if;

  delete from t.cfg where t.cfg.k = 'uid'; update t.cfg set v = 'service_role' where t.cfg.k = 'role';

  -- evento repetido não duplica
  j := hotmart_webhook(ch, tok, t.ev255('e1', 'PURCHASE_APPROVED', 'HP1', '111'));
  if j ->> 'situacao' <> 'repetido' then raise exception 'X: repetido %', j; end if;
  j := hotmart_webhook(ch, tok, t.ev255('e1b', 'PURCHASE_APPROVED', 'HP1', '111'));
  if j ->> 'situacao' <> 'ignorado' then raise exception 'X: mesma venda com outro id %', j; end if;
  if (select count(*) from vendas where workspace_id = ws) <> 1 then raise exception 'X: duplicou'; end if;

  -- reembolso usa o estorno completo
  j := hotmart_webhook(ch, tok, t.ev255('e2', 'PURCHASE_REFUNDED', 'HP1', '111'));
  if j ->> 'situacao' <> 'processado' then raise exception 'X: reembolso %', j; end if;
  select * into v from vendas where id = v.id;
  if v.status <> 'reembolsada' or v.reembolsada_em is null then raise exception 'X: status reembolso'; end if;
  if not exists (select 1 from estornos where venda_id = v.id and tipo = 'reembolso') then raise exception 'X: sem estorno'; end if;

  -- aprovação atrasada não desfaz o reembolso
  j := hotmart_webhook(ch, tok, t.ev255('e3', 'PURCHASE_COMPLETE', 'HP1', '111'));
  select * into v from vendas where id = v.id;
  if v.status <> 'reembolsada' or j ->> 'situacao' <> 'ignorado' then raise exception 'X: evento fora de ordem %', j; end if;

  -- boleto: pendente e depois aprovada, com a contabilidade na aprovação
  j := hotmart_webhook(ch, tok, t.ev255('e4', 'PURCHASE_BILLET_PRINTED', 'HP2', '111', '{"approved_date":null,"payment":{"type":"BILLET","installments_number":1}}'));
  select * into v from vendas where workspace_id = ws and id_externo = 'HP2';
  if v.status <> 'pendente' or v.forma_pagamento <> 'boleto' or exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then raise exception 'X: boleto %', to_jsonb(v); end if;
  j := hotmart_webhook(ch, tok, t.ev255('e5', 'PURCHASE_APPROVED', 'HP2', '111'));
  select * into v from vendas where id = v.id;
  if v.status <> 'aprovada' or not exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then raise exception 'X: boleto aprovado %', to_jsonb(v); end if;

  -- boleto vencido: cancela sem estorno
  j := hotmart_webhook(ch, tok, t.ev255('e6', 'PURCHASE_BILLET_PRINTED', 'HP3', '111', '{"approved_date":null}'));
  j := hotmart_webhook(ch, tok, t.ev255('e7', 'PURCHASE_EXPIRED', 'HP3', '111'));
  select * into v from vendas where workspace_id = ws and id_externo = 'HP3';
  if v.status <> 'cancelada' or exists (select 1 from estornos where venda_id = v.id) then raise exception 'X: expirado %', to_jsonb(v); end if;

  -- renovação de assinatura é outra venda
  j := hotmart_webhook(ch, tok, t.ev255('e8', 'PURCHASE_APPROVED', 'HP1', '111', '{"recurrence_number":2}'));
  if not exists (select 1 from vendas where workspace_id = ws and id_externo = 'HP1-r2' and status = 'aprovada') then raise exception 'X: renovação %', j; end if;

  -- order bump fica ligado ao pedido principal
  j := hotmart_webhook(ch, tok, t.ev255('e9', 'PURCHASE_APPROVED', 'HP4', '111', '{"order_bump":{"is_order_bump":true,"parent_purchase_transaction":"HP2"}}'));
  if not exists (select 1 from vendas where workspace_id = ws and id_externo = 'HP4' and pedido_ref = 'HP2' and (extras ->> 'order_bump')::boolean) then raise exception 'X: order bump %', j; end if;

  -- código do vendedor no sck liga vendedor e campanha
  insert into equipe (workspace_id, nome, vinculo) values (ws, 'Ana', 'vendedor') returning id into e1;
  insert into campanha_vendedores (workspace_id, campanha_id, equipe_id, comissao_pct, base, meta_vendas, codigo) values (ws, c1, e1, 10, 'bruto', 10, 'vd_ana');
  j := hotmart_webhook(ch, tok, t.ev255('e10', 'PURCHASE_APPROVED', 'HP5', '111', '{"origin":{"sck":"vd_ana","src":"zap"}}'));
  select * into v from vendas where workspace_id = ws and id_externo = 'HP5';
  if v.vendedor_id is distinct from e1 or v.campanha_id is distinct from c1 then raise exception 'X: vendedor %', to_jsonb(v); end if;

  -- moeda estrangeira e comprador sem contato ficam a revisar; evento desconhecido é ignorado
  j := hotmart_webhook(ch, tok, t.ev255('e11', 'PURCHASE_APPROVED', 'HP6', '111', '{"price":{"value":100,"currency_value":"USD"}}'));
  if j ->> 'situacao' <> 'revisar' then raise exception 'X: moeda %', j; end if;
  j := hotmart_webhook(ch, tok, t.ev255('e12', 'PURCHASE_PROTEST', 'HP1', '111'));
  if j ->> 'situacao' <> 'ignorado' then raise exception 'X: protesto %', j; end if;
  -- venda desconhecida que já chega reembolsada entra como reembolsada, sem contabilidade
  j := hotmart_webhook(ch, tok, t.ev255('e13', 'PURCHASE_REFUNDED', 'HP7', '111'));
  select * into v from vendas where workspace_id = ws and id_externo = 'HP7';
  if v.status <> 'reembolsada' or exists (select 1 from lancamentos where origem_tipo = 'venda' and origem_id = v.id) then raise exception 'X: reembolso sem venda %', to_jsonb(v); end if;

  -- isolamento: a chave de um workspace não enxerga o outro; endereço novo revoga o antigo
  insert into t.cfg values ('uid', (select user_id::text from workspace_membros where workspace_id = ws limit 1)); update t.cfg set v = 'authenticated' where t.cfg.k = 'role';
  j := hotmart_configurar(ws, pl, null, true); ch2 := j ->> 'chave';
  if ch2 is null or ch2 = ch then raise exception 'X: endereço novo'; end if;
  delete from t.cfg where t.cfg.k = 'uid'; update t.cfg set v = 'service_role' where t.cfg.k = 'role';
  ok_ := false; begin perform hotmart_webhook(ch, tok, t.ev255('e14', 'PURCHASE_APPROVED', 'HP8', '111')); exception when sqlstate '28000' then ok_ := true; end;
  if not ok_ then raise exception 'X: chave antiga ainda vale'; end if;
  j := hotmart_webhook(ch2, tok, t.ev255('e15', 'PURCHASE_APPROVED', 'HP8', '111'));
  if j ->> 'situacao' <> 'processado' then raise exception 'X: chave nova %', j; end if;
  delete from t.cfg where t.cfg.k = 'role';
end $t$;
select 'v0255: tudo OK' as resultado;
