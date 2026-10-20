-- Base para testar 20261010250000_casa_modulo.sql (rode depois de contas_pagar_base.sql, da migração v0.83, cartao_base.sql e projetos_base.sql + v0.86).
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql as $$ select null::uuid $$;
alter table workspaces add column if not exists criado_em timestamptz default now(), add column if not exists modo_produto text, add column if not exists acesso_liga text[] default '{}', add column if not exists acesso_desliga text[] default '{}';
create or replace function pertence_ao_workspace(ws uuid) returns boolean language sql as $$ select true $$;
create or replace function sou_equipe_interna() returns boolean language sql as $$ select true $$;
create or replace function public.clientes_acesso() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê os pacotes dos clientes'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'modo_produto', w.modo_produto, 'pacote_id', w.pacote_id, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga)) order by w.nome)
                   from workspaces w where not coalesce(w.agencia, false)), '[]'::jsonb);
end $$;
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
