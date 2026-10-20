-- v0.83 — Desfazer o pagamento de uma baixa parcial junta a parte desfeita com o saldo que ainda não foi pago.
-- Antes: pagar 700 de 10.000 dividia em "700 pago" + "9.300 (saldo)". Desfazer o pagamento deixava duas contas em aberto (700 + 9.300).
-- Agora: se o saldo ainda está em aberto, as duas partes são canceladas (com estorno) e nasce uma conta única de 10.000,
--        com a mesma competência, vencimento, fornecedor, conta contábil e centro de custo. O histórico contábil fica.
-- Se o saldo já foi pago (total ou parcialmente), nada é juntado: a parte desfeita volta para "a pagar" sozinha, como antes.
-- Os estornos dos cancelamentos usam a data da competência de cada parte, para a despesa do mês não mudar.
-- Rode DEPOIS de 20261008230000_seguranca_fase1.sql (usa pode_editar). Idempotente.

-- 1. ligação explícita entre a conta paga em parte e o saldo que ela gerou
alter table contas_pagar add column if not exists saldo_de uuid references contas_pagar(id);
create index if not exists contas_pagar_saldo_de on contas_pagar (saldo_de);

-- contas antigas: o saldo nasceu na mesma transação do lançamento "Divisão por pagamento parcial" da conta original
update contas_pagar s set saldo_de = o.id
from contas_pagar o
join lancamentos l on l.origem_id = o.id and l.origem_tipo = 'cancelamento_pagar' and l.descricao like 'Divisão por pagamento parcial:%'
where s.saldo_de is null and s.workspace_id = o.workspace_id and s.id <> o.id
  and s.descricao = o.descricao || ' (saldo)'
  and s.fornecedor_id is not distinct from o.fornecedor_id and s.competencia = o.competencia
  and s.criado_em = l.criado_em;

-- 2. a baixa parcial passa a gravar a ligação
create or replace function public.registrar_pagamento_parcial(p_conta uuid, p_valor numeric, p_data date default null, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; l0 uuid; l1 uuid; l0_data date; resto numeric; ratio numeric; novo uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_editar(cp.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;
  if cp.estimativa then raise exception 'Confirme o valor real antes de pagar'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor pago'; end if;
  if p_valor >= cp.valor then return registrar_pagamento(p_conta, p_data, p_conta_bancaria); end if;
  resto := round(cp.valor - p_valor, 2);
  ratio := resto / cp.valor;
  select id, data_fato into l0, l0_data from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id order by criado_em desc limit 1;
  if l0 is null then raise exception 'Conta sem lançamento contábil para dividir'; end if;
  -- tira do lançamento original a parte que continua em aberto (estorno parcial, mesma data)
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cp.workspace_id, l0_data, 'Divisão por pagamento parcial: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, v
  from (select p.*, round(sum(p.valor) over (partition by p.tipo order by p.id) * ratio, 2) - coalesce(round(sum(p.valor) over (partition by p.tipo order by p.id rows between unbounded preceding and 1 preceding) * ratio, 2), 0) as v
        from partidas p where p.lancamento_id = l0) x where v > 0;
  -- a parte que sobra vira uma conta nova, ligada à original (saldo_de), já com a despesa lançada pelo gatilho
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id, rateio_regra_id, forma_pagamento_id, estimativa, provisionada, saldo_de)
  values (cp.workspace_id, cp.fornecedor_id, cp.descricao || ' (saldo)', resto, cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id, cp.rateio_regra_id, cp.forma_pagamento_id, false, false, cp.id)
  returning id into novo;
  update contas_pagar set valor = p_valor where id = cp.id;
  return registrar_pagamento(cp.id, p_data, p_conta_bancaria);
end $$;

-- 3. desfazer pagamento: estorna o pagamento e, se for uma baixa parcial com saldo em aberto, junta as duas partes
create or replace function public.desfazer_pagamento(p_conta uuid, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; s contas_pagar; l0 uuid; l1 uuid; m movimentacoes_bancarias; d date; novo uuid; dc date; ds date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_editar(cp.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cp.status <> 'pago' then raise exception 'Só dá para desfazer pagamento de conta paga (esta está %)', cp.status; end if;
  select l.id into l0 from lancamentos l
   where l.origem_tipo = 'pagamento' and l.origem_id = cp.id
     and not exists (select 1 from lancamentos e where e.estorno_de = l.id)
   order by l.criado_em desc limit 1;
  if l0 is null then raise exception 'Pagamento sem lançamento contábil para desfazer'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cp.workspace_id, d, 'Pagamento desfeito: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0;
  select * into m from movimentacoes_bancarias where lancamento_id = l0 limit 1;
  if found then
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (m.workspace_id, m.conta_bancaria_id, d, 'entrada', m.valor, 'Pagamento desfeito: ' || cp.descricao, 'pagamento', cp.id, l1);
  end if;
  update contas_pagar set status = 'previsto', data_pagamento = null, conta_bancaria_id = null where id = cp.id;

  -- baixa parcial: o saldo que ela gerou ainda está em aberto? junta tudo numa conta só
  select * into s from contas_pagar
   where saldo_de = cp.id and status = 'previsto' and substituida_por is null and workspace_id = cp.workspace_id
   order by criado_em desc limit 1 for update;
  if found then
    select data_fato into dc from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id order by criado_em limit 1;
    select data_fato into ds from lancamentos where origem_tipo = 'conta_pagar' and origem_id = s.id order by criado_em limit 1;
    perform cancelar_conta_pagar(cp.id, coalesce(dc, cp.competencia));
    perform cancelar_conta_pagar(s.id, coalesce(ds, s.competencia));
    insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id, campanha_canal_id,
                              rateio_regra_id, forma_pagamento_id, estimativa, provisionada, recorrencia_id, saldo_de)
    values (cp.workspace_id, cp.fornecedor_id, cp.descricao, round(cp.valor + s.valor, 2), cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id, cp.campanha_id, cp.campanha_canal_id,
            cp.rateio_regra_id, cp.forma_pagamento_id, false, false, cp.recorrencia_id, cp.saldo_de)
    returning id into novo;
    update contas_pagar set substituida_por = novo where id in (cp.id, s.id);
  end if;
  return l1;
end $$;

revoke execute on function public.registrar_pagamento_parcial(uuid, numeric, date, uuid) from public, anon;
revoke execute on function public.desfazer_pagamento(uuid, date) from public, anon;
grant execute on function public.registrar_pagamento_parcial(uuid, numeric, date, uuid) to authenticated, service_role;
grant execute on function public.desfazer_pagamento(uuid, date) to authenticated, service_role;
