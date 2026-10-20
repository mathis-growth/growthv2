-- Sincronização (auditoria v0.110): esta função já existia no banco de produção, mas não estava em nenhuma migração do repositório.
-- Sem ela, montar o banco do zero falhava em 20261010240000_cartao_e_receber_avulso.sql. Texto copiado do banco de produção em 17/10/2026.
CREATE OR REPLACE FUNCTION public.registrar_recebimento_parcial(p_conta_receber uuid, p_valor numeric, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cr contas_receber; l0 uuid; l1 uuid; l2 uuid; l0_data date; resto numeric; ratio numeric; novo uuid;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber não encontrada'; end if;
  if not pode_editar(cr.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cr.status <> 'previsto' then raise exception 'Conta a receber já está %', cr.status; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor recebido'; end if;
  if p_valor >= cr.valor then return registrar_recebimento(p_conta_receber, p_data, p_conta_bancaria); end if;
  if cr.contrato_id is null then raise exception 'Recebimento parcial vale para parcelas de contrato. Venda avulsa recebe o valor inteiro; para dividir, ajuste a venda.'; end if;
  resto := round(cr.valor - p_valor, 2);
  ratio := resto / cr.valor;
  select id, data_fato into l0, l0_data from lancamentos where origem_tipo = 'contrato_parcela' and origem_id = cr.id;
  if l0 is null then raise exception 'Parcela sem lançamento contábil para dividir'; end if;
  -- tira do lançamento da parcela a parte que continua em aberto (estorno parcial, mesma data)
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cr.workspace_id, l0_data, 'Divisão por recebimento parcial: ' || coalesce(cr.descricao, 'parcela'), 'cancelamento_contrato', cr.id, l0) returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, v
  from (select p.*, round(sum(p.valor) over (partition by p.tipo order by p.id) * ratio, 2) - coalesce(round(sum(p.valor) over (partition by p.tipo order by p.id rows between unbounded preceding and 1 preceding) * ratio, 2), 0) as v
        from partidas p where p.lancamento_id = l0) x where v > 0;
  -- a parte que sobra vira uma parcela nova, com a receita reconhecida na mesma data
  insert into contas_receber (workspace_id, contrato_id, parcela, descricao, valor, vencimento, conta_bancaria_id)
  values (cr.workspace_id, cr.contrato_id, cr.parcela, coalesce(cr.descricao, 'Parcela') || ' (saldo)', resto, cr.vencimento, cr.conta_bancaria_id) returning id into novo;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  select workspace_id, l0_data, descricao || ' (saldo)', 'contrato_parcela', novo from lancamentos where id = l0 returning id into l2;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l2, conta_id, centro_custo_id, tipo, v
  from (select p.*, round(sum(p.valor) over (partition by p.tipo order by p.id) * ratio, 2) - coalesce(round(sum(p.valor) over (partition by p.tipo order by p.id rows between unbounded preceding and 1 preceding) * ratio, 2), 0) as v
        from partidas p where p.lancamento_id = l0) x where v > 0;
  update contas_receber set valor = p_valor where id = cr.id;
  return registrar_recebimento(cr.id, p_data, p_conta_bancaria);
end $function$;
