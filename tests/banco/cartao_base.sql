-- Base para testar 20261010240000_cartao_e_receber_avulso.sql (rode depois de contas_pagar_base.sql).
-- Tabelas e funções copiadas da produção em 10/10/2026, só com o necessário.
alter table workspaces add column agencia boolean default false, add column pacote_id uuid;
create table contas_receber (id uuid primary key default gen_random_uuid(), workspace_id uuid not null, venda_id uuid, valor numeric not null, vencimento date not null,
  status text not null default 'previsto', data_recebimento date, conta_bancaria_id uuid, contrato_id uuid, parcela int, descricao text, substituida_por uuid,
  desconto numeric not null default 0, desconto_motivo text, desconto_em timestamptz);
create table pacotes_acesso (id uuid primary key default gen_random_uuid(), nome text unique, descricao text, telas text[] default '{}', ativo boolean default true);
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array['venda','recebimento','estorno','manual','conta_pagar','pagamento','cancelamento_pagar','contrato_parcela','cancelamento_contrato','desconto']));
alter table movimentacoes_bancarias add constraint movimentacoes_bancarias_tipo_check check (tipo in ('entrada','saida'));
alter table partidas add constraint partidas_valor_check check (valor > 0);

create view v_saldo_contas_bancarias with (security_invoker = true) as
 SELECT cb.id AS conta_bancaria_id, cb.workspace_id, cb.nome, cb.saldo_inicial,
    (cb.saldo_inicial + COALESCE(sum(CASE m.tipo WHEN 'entrada'::text THEN m.valor ELSE (- m.valor) END), (0)::numeric)) AS saldo_atual
   FROM (contas_bancarias cb LEFT JOIN movimentacoes_bancarias m ON ((m.conta_bancaria_id = cb.id)))
  GROUP BY cb.id;

-- painel_gerencial reduzido: só os trechos que a migração altera
create or replace function public.painel_gerencial(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb language plpgsql stable as $f$
begin
  return jsonb_build_object(
      'saldo', (select coalesce(sum(saldo_atual), 0) from v_saldo_contas_bancarias where workspace_id = p_ws),
      'qtd_realizado', (select count(*) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim),
      'entrou', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and tipo = 'entrada'),
      'saiu', (select coalesce(sum(valor), 0) from movimentacoes_bancarias where workspace_id = p_ws and data between p_ini and p_fim and tipo = 'saida'));
end $f$;

CREATE OR REPLACE FUNCTION public.registrar_recebimento(p_conta_receber uuid, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cr contas_receber; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date; v_desc text;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber % não encontrada', p_conta_receber; end if;
  if not pode_editar(cr.workspace_id, '{fin}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if cr.status <> 'previsto' then raise exception 'Conta a receber já está %', cr.status; end if;

  v_banco := coalesce(p_conta_bancaria, cr.conta_bancaria_id);
  if v_banco is null then raise exception 'Informe a conta bancária do recebimento'; end if;
  select conta_contabil_id into v_banco_contabil from contas_bancarias
    where id = v_banco and workspace_id = cr.workspace_id;
  if v_banco_contabil is null then raise exception 'Conta bancária inválida para este workspace'; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  if cr.contrato_id is not null then
    r := _regra(cr.workspace_id, 'contrato_recebimento');
    v_desc := 'Recebimento: ' || coalesce(cr.descricao, 'contrato');
  else
    r := _regra(cr.workspace_id, 'recebimento');
    v_desc := 'Recebimento de venda';
  end if;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cr.workspace_id, d, v_desc, 'recebimento', cr.id)
  returning id into l;
  perform _partida(l, cr.workspace_id, coalesce(r.conta_debito_id, v_banco_contabil), null, 'D', cr.valor);
  perform _partida(l, cr.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cr.valor);

  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  values (cr.workspace_id, v_banco, d, 'entrada', cr.valor, v_desc, 'recebimento', cr.id, l);

  update contas_receber set status = 'recebido', data_recebimento = d, conta_bancaria_id = v_banco where id = cr.id;
  return l;
end $function$;

CREATE OR REPLACE FUNCTION public.registrar_recebimento_parcial(p_conta_receber uuid, p_valor numeric, p_data date DEFAULT NULL::date, p_conta_bancaria uuid DEFAULT NULL::uuid)
 RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare cr contas_receber;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if p_valor >= cr.valor then return registrar_recebimento(p_conta_receber, p_data, p_conta_bancaria); end if;
  if cr.contrato_id is null then raise exception 'Recebimento parcial vale para parcelas de contrato. Venda avulsa recebe o valor inteiro; para dividir, ajuste a venda.'; end if;
  return null;
end $function$;
