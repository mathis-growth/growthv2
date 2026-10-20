-- v0.87 — "Casa" como módulo dentro da Mathisa — Operação
-- A Casa tem livro contábil próprio (plano de contas, bancos, lançamentos, contas a pagar e a receber) e nada se mistura com a empresa.
-- Por trás ela continua sendo um workspace separado (é o que garante a separação no banco), mas fica ligada à operação
-- (workspaces.casa_de) e aparece só como o grupo "Casa" no menu da operação, para quem é membro dela.
-- A única ponte é a transferência da empresa para a Casa: transferir_para_casa paga (no todo ou em parte) uma conta a pagar da
-- empresa, normalmente o pró-labore, ou lança uma retirada contra uma conta contábil escolhida, e na Casa registra o recebimento
-- (conta a receber avulsa já recebida). Cada lado tem o seu lançamento; a tabela transferencias_casa guarda a ligação.
-- Rode DEPOIS de 20261010240000_cartao_e_receber_avulso.sql. Idempotente.

alter table workspaces add column if not exists casa_de uuid references workspaces(id);
create unique index if not exists workspaces_uma_casa on workspaces (casa_de) where casa_de is not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'workspaces_casa_nao_agencia') then
    alter table workspaces add constraint workspaces_casa_nao_agencia check (casa_de is null or (casa_de <> id and not coalesce(agencia, false)));
  end if;
end $$;

-- liga a Casa já criada à operação da Mathisa (o workspace da agência)
update workspaces set casa_de = (select id from workspaces where agencia order by criado_em limit 1)
 where nome = 'Casa' and casa_de is null and not coalesce(agencia, false)
   and (select count(*) from workspaces where agencia) = 1;

-- a Casa não aparece como cliente na tela de pacotes
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.clientes_acesso()'::regprocedure);
  if position('casa_de' in d) = 0 then
    n := replace(d, 'from workspaces w where not coalesce(w.agencia, false)', 'from workspaces w where not coalesce(w.agencia, false) and w.casa_de is null');
    if n = d then raise exception 'clientes_acesso: trecho não encontrado — revisar'; end if;
    execute n;
  end if;
end $$;

alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo = any (array[
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar',
  'contrato_parcela', 'cancelamento_contrato', 'desconto', 'fatura_cartao', 'transferencia_casa']));

create table if not exists transferencias_casa (
  id uuid primary key default gen_random_uuid(),
  ws_origem uuid not null references workspaces(id) on delete cascade,
  ws_casa uuid not null references workspaces(id) on delete cascade,
  data date not null,
  valor numeric not null check (valor > 0),
  descricao text not null,
  conta_pagar_id uuid references contas_pagar(id),
  lancamento_origem uuid references lancamentos(id),
  conta_receber_casa uuid references contas_receber(id),
  desfeita_em timestamptz,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now()
);
alter table transferencias_casa enable row level security;
drop policy if exists transferencias_casa_ler on transferencias_casa;
create policy transferencias_casa_ler on transferencias_casa for select to authenticated
  using (pertence_ao_workspace(ws_origem) and pertence_ao_workspace(ws_casa));
revoke insert, update, delete on transferencias_casa from anon, authenticated;
grant select on transferencias_casa to authenticated;

create or replace function public.transferir_para_casa(
  p_ws uuid, p_banco_origem uuid, p_valor numeric, p_data date, p_descricao text,
  p_conta_pagar uuid, p_conta_contabil_origem uuid, p_banco_casa uuid, p_receita_casa uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare casa uuid; cp contas_pagar; b contas_bancarias; l uuid; cr uuid; d date; t uuid; v numeric; descr text;
begin
  select id into casa from workspaces where casa_de = p_ws;
  if casa is null then raise exception 'Esta operação não tem o módulo Casa'; end if;
  if not pode_editar(p_ws, '{fin}'::text[]) or not pode_editar(casa, '{fin}'::text[]) then
    raise exception 'Sem permissão: precisa editar o financeiro da empresa e da Casa'; end if;
  t := gen_random_uuid();
  v := round(p_valor, 2);
  if v is null or v <= 0 then raise exception 'Informe o valor da transferência'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select * into b from contas_bancarias where id = p_banco_origem and workspace_id = p_ws and tipo = 'conta';
  if not found then raise exception 'Escolha a conta bancária da empresa de onde sai o dinheiro'; end if;
  if not exists (select 1 from contas_bancarias where id = p_banco_casa and workspace_id = casa and tipo = 'conta') then
    raise exception 'Escolha a conta da Casa onde o dinheiro entra'; end if;

  if p_conta_pagar is not null then
    select * into cp from contas_pagar where id = p_conta_pagar and workspace_id = p_ws;
    if not found or cp.status <> 'previsto' then raise exception 'A conta a pagar escolhida não está em aberto'; end if;
    if v > cp.valor then raise exception 'O valor passa do que falta pagar nesta conta (%)', cp.valor; end if;
    descr := coalesce(nullif(trim(p_descricao), ''), cp.descricao);
    if v < cp.valor then l := registrar_pagamento_parcial(cp.id, v, d, b.id); else l := registrar_pagamento(cp.id, d, b.id); end if;
  else
    if not exists (select 1 from plano_contas where id = p_conta_contabil_origem and workspace_id = p_ws and aceita_lancamento) then
      raise exception 'Escolha a conta contábil da empresa (ex.: Distribuição de lucros)'; end if;
    descr := coalesce(nullif(trim(p_descricao), ''), 'Transferência para a Casa');
    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
    values (p_ws, d, 'Transferência para a Casa: ' || descr, 'transferencia_casa', t) returning id into l;
    perform _partida(l, p_ws, p_conta_contabil_origem, null, 'D', v);
    perform _partida(l, p_ws, b.conta_contabil_id, null, 'C', v);
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (p_ws, b.id, d, 'saida', v, 'Transferência para a Casa: ' || descr, 'transferencia_casa', t, l);
  end if;

  -- na Casa: conta a receber avulsa, já recebida (D banco da Casa / C receita escolhida)
  cr := receber_avulso_criar(casa, 'Da empresa: ' || descr, v, d, p_receita_casa, p_banco_casa);
  perform registrar_recebimento(cr, d, p_banco_casa);

  insert into transferencias_casa (id, ws_origem, ws_casa, data, valor, descricao, conta_pagar_id, lancamento_origem, conta_receber_casa)
  values (t, p_ws, casa, d, v, descr, cp.id, l, cr);
  return t;
end $$;

-- desfazer: estorna os dois lados (o histórico fica)
create or replace function public.desfazer_transferencia_casa(p_id uuid, p_data date default null)
returns void language plpgsql security definer set search_path = public as $$
declare t transferencias_casa; d date; l1 uuid; cpid uuid;
begin
  select * into t from transferencias_casa where id = p_id for update;
  if not found then raise exception 'Transferência não encontrada'; end if;
  if t.desfeita_em is not null then raise exception 'Esta transferência já foi desfeita'; end if;
  if not pode_editar(t.ws_origem, '{fin}'::text[]) or not pode_editar(t.ws_casa, '{fin}'::text[]) then
    raise exception 'Sem permissão: precisa editar o financeiro da empresa e da Casa'; end if;
  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  -- Casa
  perform desfazer_recebimento(t.conta_receber_casa, d);
  perform receber_avulso_cancelar(t.conta_receber_casa);
  -- empresa
  if t.conta_pagar_id is not null then
    -- o pagamento ficou na própria conta (pagamento total) ou na parte paga da baixa parcial (mesmo id)
    select origem_id into cpid from lancamentos where id = t.lancamento_origem;
    perform desfazer_pagamento(cpid, d);
  else
    insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
    select workspace_id, d, 'Desfeito: ' || descricao, 'transferencia_casa', t.id, id from lancamentos where id = t.lancamento_origem
    returning id into l1;
    insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
    select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor from partidas where lancamento_id = t.lancamento_origem;
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    select workspace_id, conta_bancaria_id, d, 'entrada', valor, 'Desfeito: ' || descricao, 'transferencia_casa', t.id, l1
      from movimentacoes_bancarias where lancamento_id = t.lancamento_origem;
  end if;
  update transferencias_casa set desfeita_em = now() where id = t.id;
end $$;

revoke execute on function public.transferir_para_casa(uuid, uuid, numeric, date, text, uuid, uuid, uuid, uuid), public.desfazer_transferencia_casa(uuid, date) from public, anon;
grant execute on function public.transferir_para_casa(uuid, uuid, numeric, date, text, uuid, uuid, uuid, uuid), public.desfazer_transferencia_casa(uuid, date) to authenticated, service_role;
