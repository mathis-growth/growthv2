-- v0.68: desconto concedido em parcela de contrato.
-- Lançamento: D 5.1.03 Descontos concedidos / C conta de contas a receber da parcela (a mesma do lançamento original). Dedução da receita, não despesa.
-- Desconto total: parcela vira 'cancelado' com desconto = valor (sai do a receber). Parcial: o valor da parcela diminui e continua prevista.
alter table contas_receber add column if not exists desconto numeric(14,2) not null default 0 check (desconto >= 0);
alter table contas_receber add column if not exists desconto_motivo text;
alter table contas_receber add column if not exists desconto_em date;

alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array['venda','recebimento','estorno','manual','conta_pagar','pagamento','cancelamento_pagar','contrato_parcela','cancelamento_contrato','desconto']));

-- conta 5.1.03 nos clientes que já existem
insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento)
select p.workspace_id, '5.1.03', 'Descontos concedidos', 'deducao', 'devedora', p.id, true
from plano_contas p where p.codigo = '5.1'
  and not exists (select 1 from plano_contas x where x.workspace_id = p.workspace_id and x.codigo = '5.1.03');

-- e no plano padrão dos clientes novos
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = '_provisionar_base' and pronamespace = 'public'::regnamespace;
  if d !~ '5\.1\.03' then
    d := regexp_replace(d, '(\(''5\.1\.02'',[^\n]*\n)', E'\\1    (''5.1.03'', ''Descontos concedidos'',                    ''deducao'',    ''devedora'', ''5.1'',   true),\n');
    execute d;
  end if;
end $mig$;

create or replace function public.dar_desconto_parcela(p_conta_receber uuid, p_valor numeric, p_motivo text, p_data date default null)
 returns uuid language plpgsql security definer set search_path to 'public'
as $function$
declare cr contas_receber; c contratos; l0 uuid; l1 uuid; d date; v_desc uuid; v_cli uuid;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber não encontrada'; end if;
  if not pode_operar(cr.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cr.contrato_id is null then raise exception 'Desconto por aqui é só para parcela de contrato'; end if;
  if cr.status <> 'previsto' then raise exception 'Só dá para dar desconto em parcela ainda não recebida (esta está %)', cr.status; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Informe o valor do desconto'; end if;
  if p_valor > cr.valor then raise exception 'O desconto (%) é maior que a parcela (%)', p_valor, cr.valor; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Informe o motivo do desconto'; end if;
  select * into c from contratos where id = cr.contrato_id;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select id into v_desc from plano_contas where workspace_id = cr.workspace_id and codigo = '5.1.03' and aceita_lancamento;
  if v_desc is null then raise exception 'Falta a conta 5.1.03 Descontos concedidos no plano de contas'; end if;
  -- conta de contas a receber usada no lançamento original da parcela
  select pa.conta_id into v_cli from lancamentos l join partidas pa on pa.lancamento_id = l.id and pa.tipo = 'D'
    where l.origem_tipo = 'contrato_parcela' and l.origem_id = cr.id and l.estorno_de is null
    order by l.criado_em limit 1;
  if v_cli is null then raise exception 'Parcela sem lançamento contábil de contas a receber'; end if;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cr.workspace_id, d, 'Desconto concedido – contrato #' || c.numero || ' parcela ' || cr.parcela || ': ' || trim(p_motivo), 'desconto', cr.id)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, tipo, valor) values
    (cr.workspace_id, l1, v_desc, 'D', p_valor), (cr.workspace_id, l1, v_cli, 'C', p_valor);
  update contas_receber set desconto = desconto + p_valor, desconto_motivo = trim(p_motivo), desconto_em = d,
    valor = cr.valor - p_valor, status = case when cr.valor - p_valor = 0 then 'cancelado' else 'previsto' end
  where id = cr.id;
  return l1;
end $function$;
grant execute on function public.dar_desconto_parcela(uuid, numeric, text, date) to authenticated;
