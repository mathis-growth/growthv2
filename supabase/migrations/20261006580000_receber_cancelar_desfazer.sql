-- v0.44: cancelar, desfazer recebimento e reativar parcelas no contas a receber. JÁ APLICADA no projeto.
-- cancelar_parcela_contrato(p_conta_receber, p_data): parcela de contrato ativo ainda prevista é cancelada; a receita prevista é estornada (origem 'cancelamento_contrato').
-- desfazer_recebimento(p_conta_receber, p_data): parcela ou venda já recebida volta a "previsto"; lança o espelho do recebimento e uma saída bancária de devolução.
-- reativar_parcela_contrato(p_conta_receber): parcela cancelada de contrato ativo vira uma NOVA parcela prevista (copia as partidas da receita original);
--   a cancelada guarda o vínculo em contas_receber.substituida_por e some da lista.
alter table contas_receber add column if not exists substituida_por uuid references contas_receber(id);

create or replace function public.cancelar_parcela_contrato(p_conta_receber uuid, p_data date default null)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cr contas_receber; c contratos; l0 uuid; l1 uuid; d date;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber não encontrada'; end if;
  if not pode_operar(cr.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cr.contrato_id is null then raise exception 'Esta conta é de uma venda: use Estornar na venda'; end if;
  if cr.status <> 'previsto' then raise exception 'Só dá para cancelar parcela ainda não recebida (esta está %)', cr.status; end if;
  select * into c from contratos where id = cr.contrato_id;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select l.id into l0 from lancamentos l where l.origem_tipo = 'contrato_parcela' and l.origem_id = cr.id
     and not exists (select 1 from lancamentos e where e.estorno_de = l.id) order by l.criado_em desc limit 1;
  if l0 is null then raise exception 'Parcela sem lançamento contábil para estornar'; end if;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cr.workspace_id, d, 'Cancelamento do contrato #' || c.numero || ' – parcela ' || cr.parcela, 'cancelamento_contrato', cr.id, l0)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0;
  update contas_receber set status = 'cancelado' where id = cr.id;
  return l1;
end $function$;

create or replace function public.desfazer_recebimento(p_conta_receber uuid, p_data date default null)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cr contas_receber; l0 uuid; l1 uuid; m movimentacoes_bancarias; d date;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber não encontrada'; end if;
  if not pode_operar(cr.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cr.status <> 'recebido' then raise exception 'Só dá para desfazer recebimento de conta recebida (esta está %)', cr.status; end if;
  select l.id into l0 from lancamentos l where l.origem_tipo = 'recebimento' and l.origem_id = cr.id
     and not exists (select 1 from lancamentos e where e.estorno_de = l.id) order by l.criado_em desc limit 1;
  if l0 is null then raise exception 'Recebimento sem lançamento contábil para desfazer'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cr.workspace_id, d, 'Recebimento desfeito: ' || coalesce(cr.descricao, 'venda'), case when cr.contrato_id is not null then 'cancelamento_contrato' else 'estorno' end, cr.id, l0)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = l0;
  select * into m from movimentacoes_bancarias where lancamento_id = l0 limit 1;
  if found then
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (m.workspace_id, m.conta_bancaria_id, d, 'saida', m.valor, 'Recebimento desfeito: ' || coalesce(cr.descricao, 'venda'), 'recebimento', cr.id, l1);
  end if;
  update contas_receber set status = 'previsto', data_recebimento = null where id = cr.id;
  return l1;
end $function$;

create or replace function public.reativar_parcela_contrato(p_conta_receber uuid)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cr contas_receber; c contratos; n uuid; l0 uuid; l1 uuid;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber não encontrada'; end if;
  if not pode_operar(cr.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cr.contrato_id is null then raise exception 'Esta conta é de uma venda'; end if;
  if cr.status <> 'cancelado' then raise exception 'Só dá para reativar parcela cancelada (esta está %)', cr.status; end if;
  if cr.substituida_por is not null then raise exception 'Esta parcela já foi reativada'; end if;
  select * into c from contratos where id = cr.contrato_id;
  if c.status <> 'ativo' then raise exception 'O contrato está %: para refazer as parcelas, volte-o para pendente e assine de novo', c.status; end if;
  select l.id into l0 from lancamentos l where l.origem_tipo = 'contrato_parcela' and l.origem_id = cr.id order by l.criado_em limit 1;
  if l0 is null then raise exception 'Parcela sem lançamento de origem'; end if;
  insert into contas_receber (workspace_id, contrato_id, parcela, descricao, valor, vencimento, conta_bancaria_id)
  values (cr.workspace_id, cr.contrato_id, cr.parcela, cr.descricao, cr.valor, cr.vencimento, cr.conta_bancaria_id) returning id into n;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  select workspace_id, data_fato, descricao, 'contrato_parcela', n from lancamentos where id = l0 returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, tipo, valor from partidas where lancamento_id = l0;
  update contas_receber set substituida_por = n where id = cr.id;
  return n;
end $function$;
