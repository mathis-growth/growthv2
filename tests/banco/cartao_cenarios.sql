-- Cenários da v0.86 (rode depois de contas_pagar_base.sql, cartao_base.sql e da migração 20261010240000).
\set ON_ERROR_STOP on
do $$
declare ws uuid := gen_random_uuid(); bco uuid; car uuid; pc_b uuid; pc_c uuid; pc_f uuid; pc_d uuid; pc_r uuid; pc_rec uuid;
        cp1 uuid; cp2 uuid; cr1 uuid; lf uuid; s numeric; f numeric; j jsonb; ok boolean;
begin
  insert into workspaces (id, nome) values (ws, 'Teste');
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '1.1.01', 'Bancos', 'ativo') returning id into pc_b;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '2.1.01.02', 'Cartão de Credito', 'passivo') returning id into pc_c;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '2.1.01', 'Fornecedores a pagar', 'passivo') returning id into pc_f;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '6.2.01', 'Ferramentas', 'despesa') returning id into pc_d;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '4.1.03', 'Salários recebidos', 'receita') returning id into pc_r;
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '1.1.02', 'A receber plataformas', 'ativo') returning id into pc_rec;
  insert into regras_contabilizacao (workspace_id, evento, conta_debito_id, conta_credito_id) values
    (ws, 'conta_pagar', null, pc_f), (ws, 'pagamento', pc_f, null), (ws, 'recebimento', null, pc_rec);
  insert into contas_bancarias (workspace_id, nome, saldo_inicial, conta_contabil_id, padrao) values (ws, 'Conta', 1000, pc_b, true) returning id into bco;
  -- cartão cadastrado do jeito antigo (tipo ainda não existe): a migração já rodou, então simulamos com tipo = 'cartao' via nome
  insert into contas_bancarias (workspace_id, nome, saldo_inicial, conta_contabil_id, padrao, tipo) values (ws, 'Cartão Nubank', 0, pc_c, true, 'cartao') returning id into car;
  select padrao into ok from contas_bancarias where id = car;
  assert not ok, 'cartão não pode ser padrão';

  -- compra no cartão: conta a pagar paga com o cartão
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id) values (ws, 'Lovable', 100, '2026-10-01', '2026-10-01', pc_d) returning id into cp1;
  perform registrar_pagamento(cp1, '2026-10-02', car);
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id) values (ws, 'Meet', 50, '2026-10-01', '2026-10-01', pc_d) returning id into cp2;
  perform registrar_pagamento(cp2, '2026-10-03', bco);

  select coalesce(sum(saldo_atual), 0) into s from v_saldo_contas_bancarias where workspace_id = ws;
  assert s = 950, 'saldo em banco deve ignorar o cartão: ' || s;
  select fatura_aberta into f from v_cartoes_fatura where conta_bancaria_id = car;
  assert f = 100, 'fatura aberta deveria ser 100: ' || f;
  j := painel_gerencial(ws, '2026-10-01', '2026-10-31', '2026-10-10');
  assert (j->>'saiu')::numeric = 50, 'saiu deve ignorar compra no cartão: ' || j::text;
  assert (j->>'saldo')::numeric = 950, 'saldo do painel: ' || j::text;

  -- pagar fatura
  lf := pagar_fatura_cartao(car, 100, '2026-10-15', null);
  select coalesce(sum(saldo_atual), 0) into s from v_saldo_contas_bancarias where workspace_id = ws;
  assert s = 850, 'banco depois da fatura: ' || s;
  select fatura_aberta into f from v_cartoes_fatura where conta_bancaria_id = car;
  assert f = 0, 'fatura depois de paga: ' || f;
  select coalesce(sum(case tipo when 'C' then valor else -valor end), 0) into f from partidas where conta_id = pc_c;
  assert f = 0, 'passivo do cartão zerado: ' || f;
  j := painel_gerencial(ws, '2026-10-01', '2026-10-31', '2026-10-10');
  assert (j->>'saiu')::numeric = 150, 'saiu conta a fatura paga: ' || j::text;

  -- desfazer fatura
  perform desfazer_fatura_cartao(lf, '2026-10-16');
  select fatura_aberta into f from v_cartoes_fatura where conta_bancaria_id = car;
  assert f = 100, 'fatura volta a 100: ' || f;
  begin perform desfazer_fatura_cartao(lf); assert false, 'desfazer duas vezes deveria falhar';
  exception when others then if sqlerrm not like '%já foi desfeito%' then raise; end if; end;
  begin perform pagar_fatura_cartao(car, 10, null, car); assert false, 'pagar fatura com cartão deveria falhar';
  exception when others then if sqlerrm not like '%conta bancária que pagou%' then raise; end if; end;
  begin perform pagar_fatura_cartao(bco, 10); assert false, 'pagar fatura de conta deveria falhar';
  exception when others then if sqlerrm not like '%Escolha um cartão%' then raise; end if; end;

  -- conta a receber avulsa
  cr1 := receber_avulso_criar(ws, 'Salário Rebecka', 5000, '2026-10-30', pc_r, bco);
  assert not exists (select 1 from lancamentos where origem_id = cr1), 'avulsa não lança nada ao criar';
  begin perform registrar_recebimento(cr1, '2026-10-30', car); assert false, 'receber no cartão deveria falhar';
  exception when others then if sqlerrm not like '%cartão de crédito%' then raise; end if; end;
  begin perform registrar_recebimento_parcial(cr1, 100, '2026-10-30', bco); assert false, 'parcial avulsa deveria falhar';
  exception when others then if sqlerrm not like '%Conta avulsa%' then raise; end if; end;
  perform registrar_recebimento(cr1, '2026-10-30', null);
  select coalesce(sum(case tipo when 'C' then valor else -valor end), 0) into f from partidas where conta_id = pc_r;
  assert f = 5000, 'receita de 5000: ' || f;
  select coalesce(sum(saldo_atual), 0) into s from v_saldo_contas_bancarias where workspace_id = ws;
  assert s = 5950, 'banco depois do salário (fatura desfeita): ' || s;
  -- cancelar avulsa
  cr1 := receber_avulso_criar(ws, 'Reembolso', 80, '2026-11-05', pc_r, null);
  perform receber_avulso_cancelar(cr1);
  assert (select status from contas_receber where id = cr1) = 'cancelado';
  -- venda continua usando a regra antiga
  insert into contas_receber (workspace_id, valor, vencimento) values (ws, 30, '2026-10-10') returning id into cr1;
  perform registrar_recebimento(cr1, '2026-10-10', bco);
  assert exists (select 1 from partidas where conta_id = pc_rec and tipo = 'C' and valor = 30), 'venda credita a receber plataformas';
  raise notice 'v0.86: todos os cenários OK';
end $$;

-- parte 4: campanha com blocos gera atividades no projeto
do $$
declare ws uuid := gen_random_uuid(); c uuid; pj uuid; n int; eq uuid;
begin
  insert into workspaces (id, nome) values (ws, 'Proj');
  insert into equipe (workspace_id, nome, funcao) values (ws, 'Ana', 'Tráfego') returning id into eq;
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Lançamento X', '2026-10-01') returning id into c;
  select id into pj from projetos where campanha_id = c;
  assert pj is not null, 'projeto da campanha';
  insert into campanha_blocos (workspace_id, campanha_id, ordem, fase, tipo, nome) values
    (ws, c, 20, 'conversao', 'aula', 'Aula 1'), (ws, c, 10, 'aquisicao', 'trafego', 'Tráfego pago'), (ws, c, 30, 'conversao', 'xyz', 'Bloco livre');
  select count(*) into n from projeto_atividades where projeto_id = pj and pai_id is null;
  assert n = 3, 'três atividades principais: ' || n;
  select count(*) into n from projeto_atividades where projeto_id = pj;
  assert n = 3 + 5 + 4 + 1, 'subatividades: ' || n;
  assert (select string_agg(titulo, '|' order by ordem) from projeto_atividades where projeto_id = pj and pai_id is null) = 'Tráfego pago|Aula 1|Bloco livre', 'ordem por fase';
  assert (select string_agg(a.titulo, '|' order by a.ordem) from projeto_atividades a join projeto_atividades p on p.id = a.pai_id where p.titulo = 'Aula 1') like 'Definir o roteiro da aula|Preparar a apresentação|%', 'ordem das subatividades';
  assert (select responsavel_id from projeto_atividades where titulo = 'Definir públicos e orçamento' and projeto_id = pj) = eq, 'responsável pela função';
  assert not exists (select 1 from projeto_atividades where projeto_id = pj and status = 'bloqueada'), 'tudo liberado';
  n := campanha_gerar_atividades(c);
  assert n = 0, 'idempotente: ' || n;
  raise notice 'v0.86 parte 4 (projetos): OK';
end $$;
