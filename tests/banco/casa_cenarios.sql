-- Cenários da v0.87 (Casa como módulo da operação).
\set ON_ERROR_STOP on
do $$
declare op uuid := gen_random_uuid(); ca uuid := gen_random_uuid();
  b_op uuid; b_ca uuid; pc_b uuid; pc_p uuid; pc_pl uuid; pc_dl uuid; pc_cb uuid; pc_rec uuid; pl uuid; t uuid; t2 uuid; s numeric; j jsonb;
begin
  insert into workspaces (id, nome, agencia) values (op, 'Mathisa — Operação', true);
  insert into workspaces (id, nome) values (ca, 'Casa');
  -- aplica a ligação da migração de novo (agora que os workspaces existem)
  update workspaces set casa_de = op where id = ca;
  assert not exists (select 1 from jsonb_array_elements(clientes_acesso()) x where x->>'id' = ca::text), 'Casa não aparece como cliente';
  -- empresa
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (op, '1.1.01', 'Bancos', 'ativo') returning id into pc_b;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (op, '2.1.03', 'Pró-labore a pagar', 'passivo') returning id into pc_p;
  insert into plano_contas (workspace_id, codigo, nome, tipo, conta_passivo_id) values (op, '6.2.04', 'Pró-labore', 'despesa', pc_p) returning id into pc_pl;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (op, '3.1.02', 'Distribuição de lucros', 'patrimonio') returning id into pc_dl;
  insert into regras_contabilizacao (workspace_id, evento, conta_debito_id, conta_credito_id) values (op, 'conta_pagar', null, pc_p), (op, 'pagamento', pc_p, null);
  insert into contas_bancarias (workspace_id, nome, saldo_inicial, conta_contabil_id, padrao) values (op, 'Conta Mathisa', 20000, pc_b, true) returning id into b_op;
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id) values (op, 'Rebecka — 10/2026', 10000, '2026-10-01', '2026-10-30', pc_pl) returning id into pl;
  -- casa
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ca, '1.1.01', 'Bancos', 'ativo') returning id into pc_cb;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ca, '4.1.03', 'Salários e pró-labore recebidos', 'receita') returning id into pc_rec;
  insert into regras_contabilizacao (workspace_id, evento, conta_debito_id, conta_credito_id) values (ca, 'recebimento', null, pc_cb);
  insert into contas_bancarias (workspace_id, nome, saldo_inicial, conta_contabil_id, padrao) values (ca, 'Conta da casa', 0, pc_cb, true) returning id into b_ca;

  -- 1. paga 4.000 do pró-labore e manda para a Casa
  t := transferir_para_casa(op, b_op, 4000, '2026-10-30', null, pl, null, b_ca, pc_rec);
  select saldo_atual into s from v_saldo_contas_bancarias where conta_bancaria_id = b_op; assert s = 16000, 'empresa saiu 4.000: ' || s;
  select saldo_atual into s from v_saldo_contas_bancarias where conta_bancaria_id = b_ca; assert s = 4000, 'casa entrou 4.000: ' || s;
  assert (select valor from contas_pagar where workspace_id = op and status = 'previsto' and descricao like 'Rebecka%(saldo)') = 6000, 'saldo do pró-labore 6.000';
  select coalesce(sum(case tipo when 'C' then valor else -valor end), 0) into s from partidas where conta_id = pc_rec; assert s = 4000, 'receita da casa 4.000: ' || s;
  assert not exists (select 1 from partidas p join lancamentos l on l.id = p.lancamento_id where l.workspace_id = ca and p.conta_id in (pc_b, pc_p, pc_pl, pc_dl)), 'nenhuma partida da Casa usa conta da empresa';
  assert not exists (select 1 from partidas p join lancamentos l on l.id = p.lancamento_id where l.workspace_id = op and p.conta_id in (pc_cb, pc_rec)), 'nenhuma partida da empresa usa conta da Casa';
  assert (select descricao from contas_receber where workspace_id = ca) = 'Da empresa: Rebecka — 10/2026', 'descrição na Casa';

  -- 2. retirada sem conta a pagar (distribuição de lucros)
  t2 := transferir_para_casa(op, b_op, 1500, '2026-10-31', 'Retirada', null, pc_dl, b_ca, pc_rec);
  select saldo_atual into s from v_saldo_contas_bancarias where conta_bancaria_id = b_op; assert s = 14500, 'empresa 14.500: ' || s;
  select coalesce(sum(case tipo when 'D' then valor else -valor end), 0) into s from partidas where conta_id = pc_dl; assert s = 1500, 'distribuição 1.500';

  -- erros
  begin perform transferir_para_casa(op, b_op, 7000, null, null, (select id from contas_pagar where workspace_id = op and status = 'previsto' limit 1), null, b_ca, pc_rec); assert false;
  exception when others then if sqlerrm not like '%passa do que falta%' then raise; end if; end;
  begin perform transferir_para_casa(ca, b_ca, 10, null, null, null, pc_rec, b_ca, pc_rec); assert false;
  exception when others then if sqlerrm not like '%não tem o módulo Casa%' then raise; end if; end;
  begin perform transferir_para_casa(op, b_op, 10, null, null, null, pc_dl, b_op, pc_rec); assert false;
  exception when others then if sqlerrm not like '%conta da Casa%' then raise; end if; end;

  -- 3. desfazer as duas
  perform desfazer_transferencia_casa(t2, '2026-10-31');
  perform desfazer_transferencia_casa(t, '2026-10-31');
  select saldo_atual into s from v_saldo_contas_bancarias where conta_bancaria_id = b_op; assert s = 20000, 'empresa volta a 20.000: ' || s;
  select saldo_atual into s from v_saldo_contas_bancarias where conta_bancaria_id = b_ca; assert s = 0, 'casa volta a 0: ' || s;
  assert (select count(*) from contas_pagar where workspace_id = op and status = 'previsto') = 1 and (select valor from contas_pagar where workspace_id = op and status = 'previsto') = 10000, 'pró-labore volta a uma conta de 10.000';
  select coalesce(sum(case tipo when 'C' then valor else -valor end), 0) into s from partidas where conta_id = pc_rec; assert s = 0, 'receita da casa zerada: ' || s;
  begin perform desfazer_transferencia_casa(t); assert false; exception when others then if sqlerrm not like '%já foi desfeita%' then raise; end if; end;
  raise notice 'v0.87: casa OK';
end $$;
