-- Contratos de prestação de serviço: do "ganhou" no CRM até parcelas a receber,
-- lançamento contábil de previsão, baixa, fluxo de caixa e DRE. Tudo por regra fixa.

-- ---------- Regras e lançamentos aceitam os novos eventos ----------
alter table regras_contabilizacao drop constraint if exists regras_contabilizacao_evento_check;
alter table regras_contabilizacao add constraint regras_contabilizacao_evento_check check (evento in (
  'venda_receita', 'venda_taxa_plataforma', 'venda_imposto', 'recebimento', 'estorno_pagamento',
  'conta_pagar', 'pagamento', 'contrato_receita', 'contrato_recebimento'));
alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo in (
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar',
  'contrato_parcela', 'cancelamento_contrato'));

-- ---------- Contratos ----------
create table contratos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  numero int,
  pessoa_id uuid not null references pessoas(id),
  campanha_id uuid references campanhas(id),
  status text not null default 'rascunho' check (status in ('rascunho', 'ativo', 'encerrado', 'cancelado')),
  data_inicio date not null,
  data_fim date,
  recorrente boolean not null default false,
  periodicidade text check (periodicidade in ('mensal', 'trimestral', 'semestral', 'anual')),
  num_parcelas int not null default 1 check (num_parcelas between 1 and 120),
  primeiro_vencimento date,
  conta_bancaria_id uuid references contas_bancarias(id),   -- conta em que ele vai pagar
  forma_pagamento text,
  acessos text,                                              -- o que o cliente tem acesso
  observacoes text,
  ativado_em timestamptz,
  cancelado_em timestamptz,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  check (recorrente = (periodicidade is not null)),
  check (data_fim is null or data_fim >= data_inicio)
);
create index contratos_ix on contratos (workspace_id, status);
create index contratos_pessoa_ix on contratos (pessoa_id);

create table contrato_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  contrato_id uuid not null references contratos(id) on delete cascade,
  produto_id uuid not null references produtos(id),
  quantidade numeric(10, 2) not null default 1 check (quantidade > 0),
  -- recorrente: valor cobrado em cada parcela; não recorrente: valor total do item
  valor numeric(14, 2) not null check (valor >= 0)
);
create index contrato_itens_ix on contrato_itens (contrato_id);

alter table contas_receber alter column venda_id drop not null;
alter table contas_receber add column contrato_id uuid references contratos(id);
alter table contas_receber add column parcela int;
alter table contas_receber add column descricao text;
alter table contas_receber drop constraint if exists contas_receber_origem_ck;
alter table contas_receber add constraint contas_receber_origem_ck check (venda_id is not null or contrato_id is not null);
create index contas_receber_contrato_ix on contas_receber (contrato_id);

alter table contratos enable row level security;
alter table contrato_itens enable row level security;
create policy contratos_rls on contratos for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy contrato_itens_rls on contrato_itens for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

create or replace function contratos_antes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id) then
      raise exception 'A pessoa precisa pertencer ao mesmo workspace do contrato';
    end if;
    select coalesce(max(numero), 0) + 1 into new.numero from contratos where workspace_id = new.workspace_id;
    new.primeiro_vencimento := coalesce(new.primeiro_vencimento, new.data_inicio);
  else
    if old.status <> 'rascunho' and (
         new.pessoa_id is distinct from old.pessoa_id or new.data_inicio is distinct from old.data_inicio
         or new.data_fim is distinct from old.data_fim or new.recorrente is distinct from old.recorrente
         or new.periodicidade is distinct from old.periodicidade or new.num_parcelas is distinct from old.num_parcelas
         or new.primeiro_vencimento is distinct from old.primeiro_vencimento) then
      raise exception 'Contrato já ativado: valores, datas e recorrência não mudam mais. Cancele e crie outro.';
    end if;
  end if;
  return new;
end $$;
create trigger contratos_antes before insert or update on contratos
  for each row execute function contratos_antes();

create or replace function contrato_itens_antes() returns trigger
language plpgsql security definer set search_path = public as $$
declare st text;
begin
  select status into st from contratos where id = coalesce(new.contrato_id, old.contrato_id);
  if st is distinct from 'rascunho' then raise exception 'Só dá para mudar os itens de contrato em rascunho'; end if;
  if tg_op <> 'DELETE' and not exists (
       select 1 from produtos p join contratos c on c.id = new.contrato_id
       where p.id = new.produto_id and p.workspace_id = c.workspace_id) then
    raise exception 'O produto precisa pertencer ao mesmo workspace do contrato';
  end if;
  return coalesce(new, old);
end $$;
create trigger contrato_itens_antes before insert or update or delete on contrato_itens
  for each row execute function contrato_itens_antes();

-- ---------- Plano de contas e regras ----------
create or replace function _provisionar_contratos(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento)
  select p_ws, '1.1.03', 'Contas a receber – contratos', 'ativo', 'devedora',
         (select id from plano_contas where workspace_id = p_ws and codigo = '1.1'), true
  where not exists (select 1 from plano_contas where workspace_id = p_ws and codigo = '1.1.03');

  insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento)
  select p_ws, '4.1.02', 'Receita de serviços', 'receita', 'credora',
         (select id from plano_contas where workspace_id = p_ws and codigo = '4.1'), true
  where not exists (select 1 from plano_contas where workspace_id = p_ws and codigo = '4.1.02');

  insert into regras_contabilizacao (workspace_id, evento, descricao, conta_debito_id, conta_credito_id)
  select p_ws, e.evento, e.descricao,
         (select id from plano_contas where workspace_id = p_ws and codigo = e.deb),
         (select id from plano_contas where workspace_id = p_ws and codigo = e.cred)
  from (values
    ('contrato_receita',      'Parcela de contrato: reconhece a receita de serviços e o valor a receber', '1.1.03', '4.1.02'),
    ('contrato_recebimento',  'Cliente pagou a parcela (débito = conta bancária)',                         null,     '1.1.03')
  ) as e(evento, descricao, deb, cred)
  on conflict (workspace_id, evento) do nothing;
end $$;
select _provisionar_contratos(id) from workspaces;

alter function provisionar_workspace(text) rename to _provisionar_pre_contratos;
create function provisionar_workspace(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  ws := _provisionar_pre_contratos(p_nome);
  perform _provisionar_contratos(ws);
  return ws;
end $$;

-- ---------- Ativar: gera parcelas, contas a receber e lançamentos de previsão ----------
create or replace function ativar_contrato(p_contrato uuid) returns int
language plpgsql security definer set search_path = public as $$
declare c contratos; r regras_contabilizacao; total numeric; por_parcela numeric; passo int;
        i int; v numeric; venc date; l uuid; cr uuid; cc uuid; nome_prod text; ultimo date;
begin
  select * into c from contratos where id = p_contrato for update;
  if not found then raise exception 'Contrato não encontrado'; end if;
  if not pode_operar(c.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if c.status <> 'rascunho' then raise exception 'Contrato já está %', c.status; end if;

  select coalesce(sum(quantidade * valor), 0) into total from contrato_itens where contrato_id = c.id;
  if total <= 0 then raise exception 'Inclua ao menos um produto com valor no contrato'; end if;
  select string_agg(p.nome, ', ' order by p.nome), (array_agg(p.centro_custo_id))[1]
    into nome_prod, cc from contrato_itens it join produtos p on p.id = it.produto_id where it.contrato_id = c.id;

  passo := case when c.recorrente then
             case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end
           else 1 end;
  por_parcela := case when c.recorrente then total else round(total / c.num_parcelas, 2) end;
  r := _regra(c.workspace_id, 'contrato_receita');

  for i in 1..c.num_parcelas loop
    venc := (c.primeiro_vencimento + ((i - 1) * passo) * interval '1 month')::date;
    v := case when not c.recorrente and i = c.num_parcelas then total - por_parcela * (c.num_parcelas - 1) else por_parcela end;

    insert into contas_receber (workspace_id, contrato_id, parcela, descricao, valor, vencimento, conta_bancaria_id)
    values (c.workspace_id, c.id, i, 'Contrato #' || c.numero || ' – parcela ' || i || '/' || c.num_parcelas, v, venc,
            coalesce(c.conta_bancaria_id, (select id from contas_bancarias
                     where workspace_id = c.workspace_id and padrao and ativa limit 1)))
    returning id into cr;

    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
    values (c.workspace_id, venc, 'Contrato #' || c.numero || ' (' || nome_prod || ') – parcela ' || i || '/' || c.num_parcelas,
            'contrato_parcela', cr)
    returning id into l;
    perform _partida(l, c.workspace_id, r.conta_debito_id, cc, 'D', v);
    perform _partida(l, c.workspace_id, r.conta_credito_id, cc, 'C', v);
    ultimo := venc;
  end loop;

  update contratos set status = 'ativo', ativado_em = now(),
         data_fim = coalesce(data_fim, ultimo)
   where id = c.id;

  update pessoas set status_funil = 'cliente', status_cliente = 'ativo',
         convertido_em = coalesce(convertido_em, now()),
         etapa_kanban_id = coalesce(
           (select id from etapas_kanban where workspace_id = c.workspace_id and quadro = 'leads' and nome = 'Cliente'),
           etapa_kanban_id)
   where id = c.pessoa_id;
  return c.num_parcelas;
end $$;

-- ---------- Cancelar: desfaz o que ainda não foi recebido ----------
create or replace function cancelar_contrato(p_contrato uuid, p_data date default null) returns int
language plpgsql security definer set search_path = public as $$
declare c contratos; cr record; l0 uuid; l1 uuid; d date; n int := 0;
begin
  select * into c from contratos where id = p_contrato for update;
  if not found then raise exception 'Contrato não encontrado'; end if;
  if not pode_operar(c.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if c.status in ('cancelado') then raise exception 'Contrato já está cancelado'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);

  if c.status = 'ativo' then
    for cr in select * from contas_receber where contrato_id = c.id and status = 'previsto' loop
      select id into l0 from lancamentos where origem_tipo = 'contrato_parcela' and origem_id = cr.id;
      insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
      values (c.workspace_id, d, 'Cancelamento do contrato #' || c.numero || ' – parcela ' || cr.parcela, 'cancelamento_contrato', cr.id, l0)
      returning id into l1;
      insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
      select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor
      from partidas where lancamento_id = l0;
      update contas_receber set status = 'cancelado' where id = cr.id;
      n := n + 1;
    end loop;
  end if;
  update contratos set status = 'cancelado', cancelado_em = now() where id = c.id;
  return n;
end $$;

-- ---------- Recebimento: parcela de contrato credita "contratos a receber" ----------
create or replace function registrar_recebimento(p_conta_receber uuid, p_data date default null, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cr contas_receber; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date; v_desc text;
begin
  select * into cr from contas_receber where id = p_conta_receber for update;
  if not found then raise exception 'Conta a receber % não encontrada', p_conta_receber; end if;
  if not pode_operar(cr.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
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
end $$;

-- ---------- Ganhou no CRM, mas ainda sem contrato nem venda ----------
create or replace view v_contratos_pendentes with (security_invoker = true) as
select p.workspace_id, p.id as pessoa_id, p.nome, p.email, p.telefone, p.campanha_id, p.convertido_em
from pessoas p
where p.status_funil = 'cliente'
  and not exists (select 1 from contratos c where c.pessoa_id = p.id and c.status <> 'cancelado')
  and not exists (select 1 from vendas v where v.pessoa_id = p.id and v.status = 'aprovada');

revoke execute on function ativar_contrato(uuid) from public, anon;
revoke execute on function cancelar_contrato(uuid, date) from public, anon;
revoke execute on function _provisionar_contratos(uuid) from public, anon, authenticated;
revoke execute on function _provisionar_pre_contratos(text) from public, anon, authenticated;
grant execute on function ativar_contrato(uuid) to authenticated;
grant execute on function cancelar_contrato(uuid, date) to authenticated;
grant execute on function provisionar_workspace(text) to authenticated;
