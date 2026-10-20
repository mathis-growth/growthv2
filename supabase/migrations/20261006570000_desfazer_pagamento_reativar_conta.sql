-- v0.43: reverter erros em contas a pagar. JÁ APLICADA no projeto.
-- desfazer_pagamento(p_conta, p_data): conta paga volta a "previsto". O razão não é editado: lança-se o espelho do pagamento
--   (origem 'cancelamento_pagar', estorno_de = lançamento do pagamento) e uma entrada bancária de devolução na mesma data (default: hoje).
-- reativar_conta_pagar(p_conta): conta cancelada vira uma NOVA conta "previsto" com os mesmos dados (o gatilho lança a despesa de novo);
--   a cancelada fica no histórico com substituida_por apontando para a nova. Devolve o id da nova conta.
create or replace function public.desfazer_pagamento(p_conta uuid, p_data date default null)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cp contas_pagar; l0 uuid; l1 uuid; m movimentacoes_bancarias; d date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
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
  return l1;
end $function$;

create or replace function public.reativar_conta_pagar(p_conta uuid)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cp contas_pagar; n uuid;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar não encontrada'; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'cancelado' then raise exception 'Só dá para reativar conta cancelada (esta está %)', cp.status; end if;
  if cp.substituida_por is not null then raise exception 'Esta conta já foi reativada ou substituída'; end if;
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id,
                            campanha_id, campanha_canal_id, rateio_regra_id, forma_pagamento_id, estimativa, provisionada, recorrencia_id)
  values (cp.workspace_id, cp.fornecedor_id, cp.descricao, cp.valor, cp.competencia, cp.vencimento, cp.conta_despesa_id, cp.centro_custo_id,
          cp.campanha_id, cp.campanha_canal_id, cp.rateio_regra_id, cp.forma_pagamento_id, cp.estimativa, false, cp.recorrencia_id)
  returning id into n;
  update contas_pagar set substituida_por = n where id = cp.id;
  return n;
end $function$;
