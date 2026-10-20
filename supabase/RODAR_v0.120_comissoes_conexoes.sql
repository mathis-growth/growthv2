-- v0.120 — Comissões + Conexões com Meta e Google. Rode no SQL Editor do Supabase (pode rodar de novo).
-- Depois publique a edge function "conexoes" sem verificação de JWT e cadastre os segredos (docs/conectar-meta-e-google.md).

-- v0.120 — Comissões
-- Quem recebe: pessoas da Equipe (vendedor da equipe comercial, coprodutor, estrategista, parceiro), com o tipo de vínculo.
-- Regras: % sobre a venda, valendo para o projeto todo (workspace), uma campanha, um produto ou uma oferta.
--   base: líquido (padrão) ou bruto · sobre: todas as vendas do escopo ou só as que a pessoa vendeu
--   pagamento: conta a pagar mensal por pessoa, conta a pagar por venda, ou só relatório
--   Se a mesma pessoa tiver mais de uma regra para a venda, vale a mais específica: oferta > produto > campanha > projeto.
--   Pessoas diferentes somam.
-- Comissões: geradas sozinhas quando a venda é aprovada e quando a parcela de contrato é recebida.
--   Venda que volta (reembolso, cancelamento, chargeback): a comissão prevista é cancelada; a já lançada vira
--   "estorno pendente" e é descontada no próximo fechamento do mês daquela pessoa.
-- Rode depois de 20261021100000_arvore_numeros_4.sql. Pode rodar de novo.

alter table equipe add column if not exists vinculo text not null default 'equipe';
alter table equipe add column if not exists equipe_comercial boolean not null default false;
alter table equipe add column if not exists fornecedor_id uuid references fornecedores(id) on delete set null;
do $$ begin
  alter table equipe add constraint equipe_vinculo_ck check (vinculo in ('equipe', 'vendedor', 'coprodutor', 'estrategista', 'parceiro'));
exception when duplicate_object then null; end $$;
update equipe set equipe_comercial = true where vinculo = 'vendedor' and not equipe_comercial;

alter table vendas add column if not exists oferta_id uuid references ofertas(id) on delete set null;
create index if not exists vendas_oferta_idx on vendas (oferta_id) where oferta_id is not null;

create table if not exists comissao_regras (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  equipe_id uuid not null references equipe(id) on delete cascade,
  escopo text not null check (escopo in ('projeto', 'campanha', 'produto', 'oferta')),
  campanha_id uuid references campanhas(id) on delete cascade,
  produto_id uuid references produtos(id) on delete cascade,
  oferta_id uuid references ofertas(id) on delete cascade,
  percentual numeric not null check (percentual > 0 and percentual <= 100),
  base text not null default 'liquido' check (base in ('liquido', 'bruto')),
  sobre text not null default 'todas' check (sobre in ('todas', 'proprias')),
  pagamento text not null default 'mensal' check (pagamento in ('mensal', 'por_venda', 'relatorio')),
  dia_pagamento smallint not null default 10 check (dia_pagamento between 1 and 28),
  inclui_contratos boolean not null default true,
  vigencia_ini date, vigencia_fim date,
  ativo boolean not null default true,
  observacao text,
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid(),
  constraint comissao_regras_escopo_ck check (
       (escopo = 'projeto'  and campanha_id is null     and produto_id is null     and oferta_id is null)
    or (escopo = 'campanha' and campanha_id is not null and produto_id is null     and oferta_id is null)
    or (escopo = 'produto'  and produto_id is not null  and campanha_id is null    and oferta_id is null)
    or (escopo = 'oferta'   and oferta_id is not null   and campanha_id is null    and produto_id is null)),
  constraint comissao_regras_vigencia_ck check (vigencia_fim is null or vigencia_ini is null or vigencia_fim >= vigencia_ini)
);
create index if not exists comissao_regras_ws_idx on comissao_regras (workspace_id, equipe_id) where ativo;

create table if not exists comissoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  equipe_id uuid not null references equipe(id) on delete cascade,
  regra_id uuid references comissao_regras(id) on delete set null,
  origem text not null check (origem in ('venda', 'contrato_parcela')),
  venda_id uuid references vendas(id) on delete cascade,
  conta_receber_id uuid references contas_receber(id) on delete cascade,
  data_fato date not null,
  competencia date not null,
  base text not null, base_valor numeric not null, percentual numeric not null, valor numeric not null,
  pagamento text not null,
  status text not null default 'prevista' check (status in ('prevista', 'lancada', 'paga_manual', 'cancelada', 'estorno_pendente', 'estornada')),
  conta_pagar_id uuid references contas_pagar(id) on delete set null,
  estorno_conta_pagar_id uuid references contas_pagar(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint comissoes_origem_ck check ((origem = 'venda' and venda_id is not null) or (origem = 'contrato_parcela' and conta_receber_id is not null))
);
create unique index if not exists comissoes_venda_uq on comissoes (venda_id, equipe_id) where venda_id is not null;
create unique index if not exists comissoes_parcela_uq on comissoes (conta_receber_id, equipe_id) where conta_receber_id is not null;
create index if not exists comissoes_ws_idx on comissoes (workspace_id, competencia, equipe_id);

-- acesso: ler (vendas, financeiro, administrativo); regras só financeiro e administrativo editam; comissões só por função
alter table comissao_regras enable row level security;
alter table comissoes enable row level security;
drop policy if exists comissao_regras_acesso on comissao_regras;
create policy comissao_regras_acesso on comissao_regras for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on comissao_regras;
create policy perm_ler on comissao_regras as restrictive for select to authenticated using (perm(workspace_id, 'ler', '{fin,vendas,adm}'::text[]));
drop policy if exists perm_inserir on comissao_regras;
create policy perm_inserir on comissao_regras as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', '{fin,adm}'::text[]));
drop policy if exists perm_alterar on comissao_regras;
create policy perm_alterar on comissao_regras as restrictive for update to authenticated using (perm(workspace_id, 'editar', '{fin,adm}'::text[])) with check (perm(workspace_id, 'editar', '{fin,adm}'::text[]));
drop policy if exists perm_excluir on comissao_regras;
create policy perm_excluir on comissao_regras as restrictive for delete to authenticated using (perm(workspace_id, 'editar', '{fin,adm}'::text[]));
drop policy if exists comissoes_ler on comissoes;
create policy comissoes_ler on comissoes for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{fin,vendas,adm}'::text[]));
grant select, insert, update, delete on comissao_regras to authenticated;
grant select on comissoes to authenticated;

-- regra da regra: a mais específica de cada pessoa
create or replace function public._comissao_regras_aplicaveis(p_ws uuid, p_data date, p_campanha uuid, p_produtos uuid[], p_oferta uuid, p_vendedor uuid, p_contrato boolean)
returns setof comissao_regras language sql stable security definer set search_path = public as $$
  select distinct on (r.equipe_id) r.*
    from comissao_regras r join equipe e on e.id = r.equipe_id
   where r.workspace_id = p_ws and r.ativo
     and (r.vigencia_ini is null or p_data >= r.vigencia_ini) and (r.vigencia_fim is null or p_data <= r.vigencia_fim)
     and (not p_contrato or r.inclui_contratos)
     and (r.sobre = 'todas' or r.equipe_id = p_vendedor)
     and case r.escopo when 'projeto' then true when 'campanha' then r.campanha_id = p_campanha
                       when 'produto' then r.produto_id = any (coalesce(p_produtos, '{}'::uuid[])) when 'oferta' then r.oferta_id = p_oferta end
   order by r.equipe_id, case r.escopo when 'oferta' then 4 when 'produto' then 3 when 'campanha' then 2 else 1 end desc, r.criado_em desc
$$;
revoke execute on function public._comissao_regras_aplicaveis(uuid, date, uuid, uuid[], uuid, uuid, boolean) from public, anon, authenticated;

-- fornecedor e conta contábil para lançar a comissão no Contas a pagar
create or replace function public._comissao_fornecedor(p_equipe uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare e equipe; f uuid;
begin
  select * into e from equipe where id = p_equipe;
  if e.fornecedor_id is not null and exists (select 1 from fornecedores where id = e.fornecedor_id) then return e.fornecedor_id; end if;
  select id into f from fornecedores where workspace_id = e.workspace_id and lower(nome) = lower(e.nome) limit 1;
  if f is null then
    insert into fornecedores (workspace_id, nome, email, telefone, categoria, tipo_custo, ativo) values (e.workspace_id, e.nome, e.email, e.telefone, 'Comissões', 'variavel', true) returning id into f;
  end if;
  perform set_config('growths.sync', '1', true);
  update equipe set fornecedor_id = f where id = p_equipe;
  perform set_config('growths.sync', '', true);
  return f;
end $$;
revoke execute on function public._comissao_fornecedor(uuid) from public, anon, authenticated;

create or replace function public._comissao_conta_despesa(p_ws uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from plano_contas where workspace_id = p_ws and tipo in ('despesa', 'custo') and aceita_lancamento
   order by (codigo = '6.2.03') desc, (nome ilike 'comiss%') desc, (nome ilike '%comiss%') desc limit 1
$$;
revoke execute on function public._comissao_conta_despesa(uuid) from public, anon, authenticated;

create or replace function public._comissao_vencimento(p_competencia date, p_dia int) returns date
language sql immutable as $$ select (date_trunc('month', p_competencia) + interval '1 month')::date + (least(greatest(coalesce(p_dia, 10), 1), 28) - 1) $$;

create or replace function public._comissao_lanca(p_ws uuid, p_equipe uuid, p_valor numeric, p_competencia date, p_dia int, p_desc text, p_campanha uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare cd uuid := _comissao_conta_despesa(p_ws); cp uuid;
begin
  if cd is null then raise exception 'Cadastre no Plano de contas uma conta de despesa para comissões (ex.: 6.2.03 Comissões e afiliados).'; end if;
  insert into contas_pagar (workspace_id, fornecedor_id, descricao, valor, competencia, vencimento, conta_despesa_id, campanha_id)
  values (p_ws, _comissao_fornecedor(p_equipe), p_desc, round(p_valor, 2), date_trunc('month', p_competencia)::date, _comissao_vencimento(p_competencia, p_dia), cd, p_campanha)
  returning id into cp;
  return cp;
end $$;
revoke execute on function public._comissao_lanca(uuid, uuid, numeric, date, int, text, uuid) from public, anon, authenticated;

-- grava (ou ajusta) a comissão de uma pessoa sobre um fato (venda ou parcela)
create or replace function public._comissao_grava(p_ws uuid, r comissao_regras, p_origem text, p_venda uuid, p_parcela uuid, p_data date, p_bruto numeric, p_liquido numeric, p_campanha uuid, p_rotulo text)
returns void language plpgsql security definer set search_path = public as $$
declare c comissoes; bv numeric := case r.base when 'bruto' then p_bruto else coalesce(p_liquido, p_bruto) end; v numeric; cp uuid;
begin
  v := round(coalesce(bv, 0) * r.percentual / 100, 2);
  if p_venda is not null then select * into c from comissoes where venda_id = p_venda and equipe_id = r.equipe_id;
  else select * into c from comissoes where conta_receber_id = p_parcela and equipe_id = r.equipe_id; end if;
  if c.id is null then
    if v <= 0 then return; end if;
    insert into comissoes (workspace_id, equipe_id, regra_id, origem, venda_id, conta_receber_id, data_fato, competencia, base, base_valor, percentual, valor, pagamento)
    values (p_ws, r.equipe_id, r.id, p_origem, p_venda, p_parcela, p_data, date_trunc('month', p_data)::date, r.base, coalesce(bv, 0), r.percentual, v, r.pagamento)
    returning * into c;
  elsif c.status in ('prevista', 'cancelada') then
    update comissoes set regra_id = r.id, data_fato = p_data, competencia = date_trunc('month', p_data)::date, base = r.base, base_valor = coalesce(bv, 0),
           percentual = r.percentual, valor = v, pagamento = r.pagamento, status = 'prevista', atualizado_em = now()
     where id = c.id returning * into c;
  elsif c.status = 'estorno_pendente' then  -- a venda voltou a valer antes do desconto: a comissão continua lançada
    update comissoes set status = case when conta_pagar_id is null then 'paga_manual' else 'lancada' end, atualizado_em = now() where id = c.id;
    return;
  elsif c.status = 'lancada' and c.pagamento = 'por_venda' and c.valor <> v
        and exists (select 1 from contas_pagar where id = c.conta_pagar_id and status = 'previsto') then  -- conta ainda não paga: acompanha o valor
    update contas_pagar set valor = v where id = c.conta_pagar_id and v > 0;
    update comissoes set base_valor = coalesce(bv, 0), percentual = r.percentual, valor = v, atualizado_em = now() where id = c.id;
    return;
  else
    return;  -- lançada numa conta mensal ou paga: fica como está
  end if;
  if c.status = 'prevista' and c.pagamento = 'por_venda' and c.valor > 0 then
    cp := _comissao_lanca(p_ws, c.equipe_id, c.valor, c.data_fato, r.dia_pagamento, 'Comissão · ' || (select nome from equipe where id = c.equipe_id) || ' · ' || p_rotulo, p_campanha);
    update comissoes set status = 'lancada', conta_pagar_id = cp, atualizado_em = now() where id = c.id;
  end if;
end $$;
revoke execute on function public._comissao_grava(uuid, comissao_regras, text, uuid, uuid, date, numeric, numeric, uuid, text) from public, anon, authenticated;

-- a venda deixou de valer: cancela o que não foi lançado, marca para estornar o que já foi
create or replace function public._comissao_desfaz(p_venda uuid, p_parcela uuid, p_apaga boolean) returns void
language plpgsql security definer set search_path = public as $$
declare c comissoes;
begin
  for c in select * from comissoes where (p_venda is not null and venda_id = p_venda) or (p_parcela is not null and conta_receber_id = p_parcela) loop
    if c.status = 'prevista' then
      if p_apaga then delete from comissoes where id = c.id; else update comissoes set status = 'cancelada', atualizado_em = now() where id = c.id; end if;
    elsif c.status = 'lancada' and c.pagamento = 'por_venda'
          and exists (select 1 from contas_pagar where id = c.conta_pagar_id and status = 'previsto')
          and (select count(*) from comissoes where conta_pagar_id = c.conta_pagar_id) = 1 then
      update contas_pagar set status = 'cancelado' where id = c.conta_pagar_id;
      update comissoes set status = 'cancelada', atualizado_em = now() where id = c.id;
    elsif c.status in ('lancada', 'paga_manual') then
      update comissoes set status = 'estorno_pendente', atualizado_em = now() where id = c.id;
    end if;
  end loop;
end $$;
revoke execute on function public._comissao_desfaz(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function public.comissao_calcular_venda(p_venda uuid) returns int
language plpgsql security definer set search_path = public as $$
declare v vendas; r comissao_regras; n int := 0; d date; rot text;
begin
  select * into v from vendas where id = p_venda;
  if not found then return 0; end if;
  if v.status <> 'aprovada' then perform _comissao_desfaz(v.id, null, v.status = 'pendente'); return 0; end if;
  d := (coalesce(v.aprovada_em, v.data_venda) at time zone 'America/Sao_Paulo')::date;
  rot := coalesce((select nome from produtos where id = v.produto_id), 'venda') || ' · ' || coalesce((select nome from pessoas where id = v.pessoa_id), '') || ' · ' || to_char(d, 'DD/MM/YYYY');
  -- quem não tem mais regra para esta venda e ainda não foi lançado sai
  delete from comissoes c where c.venda_id = v.id and c.status in ('prevista', 'cancelada')
     and not exists (select 1 from _comissao_regras_aplicaveis(v.workspace_id, d, v.campanha_id, array[v.produto_id], v.oferta_id, v.vendedor_id, false) a where a.equipe_id = c.equipe_id);
  for r in select * from _comissao_regras_aplicaveis(v.workspace_id, d, v.campanha_id, array[v.produto_id], v.oferta_id, v.vendedor_id, false) loop
    perform _comissao_grava(v.workspace_id, r, 'venda', v.id, null, d, v.valor_bruto, v.valor_liquido, v.campanha_id, rot); n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.comissao_calcular_venda(uuid) from public, anon, authenticated;

-- parcela de contrato recebida (produto: a parte da parcela que cabe aos itens daquele produto)
create or replace function public.comissao_calcular_parcela(p_parcela uuid) returns int
language plpgsql security definer set search_path = public as $$
declare cr contas_receber; ct contratos; r comissao_regras; n int := 0; tot numeric; base numeric; share numeric; prods uuid[]; rot text;
begin
  select * into cr from contas_receber where id = p_parcela;
  if not found or cr.contrato_id is null then return 0; end if;
  select * into ct from contratos where id = cr.contrato_id;
  if cr.status <> 'recebido' then perform _comissao_desfaz(null, cr.id, cr.status = 'previsto'); return 0; end if;
  base := cr.valor - coalesce(cr.desconto, 0);
  select coalesce(sum(valor * coalesce(quantidade, 1)), 0), array_agg(distinct produto_id) into tot, prods from contrato_itens where contrato_id = ct.id;
  rot := 'contrato nº ' || ct.numero || coalesce(' · parcela ' || cr.parcela, '') || ' · ' || coalesce((select nome from pessoas where id = ct.pessoa_id), '');
  delete from comissoes c where c.conta_receber_id = cr.id and c.status in ('prevista', 'cancelada')
     and not exists (select 1 from _comissao_regras_aplicaveis(cr.workspace_id, coalesce(cr.data_recebimento, cr.vencimento), ct.campanha_id, prods, null, ct.vendedor_id, true) a where a.equipe_id = c.equipe_id);
  for r in select * from _comissao_regras_aplicaveis(cr.workspace_id, coalesce(cr.data_recebimento, cr.vencimento), ct.campanha_id, prods, null, ct.vendedor_id, true) loop
    share := case when r.escopo = 'produto' and tot > 0 then (select coalesce(sum(valor * coalesce(quantidade, 1)), 0) from contrato_itens where contrato_id = ct.id and produto_id = r.produto_id) / tot else 1 end;
    perform _comissao_grava(cr.workspace_id, r, 'contrato_parcela', null, cr.id, coalesce(cr.data_recebimento, cr.vencimento), base * share, base * share, ct.campanha_id, rot); n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.comissao_calcular_parcela(uuid) from public, anon, authenticated;

create or replace function public.comissao_trg_venda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from comissao_regras where workspace_id = new.workspace_id) or exists (select 1 from comissoes where venda_id = new.id) then
    perform comissao_calcular_venda(new.id);
  end if;
  return null;
end $$;
drop trigger if exists comissao_venda_t on vendas;
create trigger comissao_venda_t after insert or update of status, valor_bruto, valor_liquido, campanha_id, produto_id, oferta_id, vendedor_id, data_venda, aprovada_em on vendas
  for each row execute function comissao_trg_venda();

create or replace function public.comissao_trg_parcela() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.contrato_id is not null and (exists (select 1 from comissao_regras where workspace_id = new.workspace_id) or exists (select 1 from comissoes where conta_receber_id = new.id)) then
    perform comissao_calcular_parcela(new.id);
  end if;
  return null;
end $$;
drop trigger if exists comissao_parcela_t on contas_receber;
create trigger comissao_parcela_t after insert or update of status, valor, desconto, data_recebimento on contas_receber
  for each row execute function comissao_trg_parcela();

-- depois de criar ou mudar regras: refaz as comissões ainda não lançadas desde uma data
create or replace function public.comissao_recalcular(p_ws uuid, p_desde date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid; n int := 0; m int := 0;
begin
  if not perm(p_ws, 'editar', '{fin,adm}'::text[]) then raise exception 'Sem permissão para recalcular comissões'; end if;
  for v in select id from vendas where workspace_id = p_ws and (coalesce(aprovada_em, data_venda) at time zone 'America/Sao_Paulo')::date >= p_desde loop
    perform comissao_calcular_venda(v); n := n + 1;
  end loop;
  for v in select id from contas_receber where workspace_id = p_ws and contrato_id is not null and status = 'recebido' and coalesce(data_recebimento, vencimento) >= p_desde loop
    perform comissao_calcular_parcela(v); m := m + 1;
  end loop;
  return jsonb_build_object('vendas', n, 'parcelas', m);
end $$;
grant execute on function public.comissao_recalcular(uuid, date) to authenticated;

-- fechamento do mês: uma conta a pagar por pessoa (comissões mensais do mês − estornos pendentes)
create or replace function public.comissao_fechar_mes(p_ws uuid, p_mes date, p_equipe uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e record; cp uuid; mes date := date_trunc('month', p_mes)::date; res jsonb := '[]'::jsonb; dia int;
begin
  if not perm(p_ws, 'editar', '{fin,adm}'::text[]) then raise exception 'Sem permissão para fechar comissões'; end if;
  for e in
    select q.equipe_id, sum(q.v) total, sum(q.v) filter (where q.v > 0) cred, -sum(q.v) filter (where q.v < 0) est from (
      select equipe_id, valor v from comissoes where workspace_id = p_ws and status = 'prevista' and pagamento = 'mensal' and competencia = mes
      union all
      select equipe_id, -valor from comissoes where workspace_id = p_ws and status = 'estorno_pendente' and competencia <= mes) q
    where p_equipe is null or q.equipe_id = p_equipe
    group by q.equipe_id
  loop
    if coalesce(e.cred, 0) <= 0 then continue; end if;
    if e.total <= 0 then
      res := res || jsonb_build_object('equipe_id', e.equipe_id, 'nome', (select nome from equipe where id = e.equipe_id), 'valor', 0, 'aviso', 'Os estornos (' || e.est || ') são maiores que as comissões do mês: nada lançado, fica para o próximo fechamento.');
      continue;
    end if;
    select max(r.dia_pagamento) into dia from comissoes c join comissao_regras r on r.id = c.regra_id
     where c.workspace_id = p_ws and c.equipe_id = e.equipe_id and c.status = 'prevista' and c.pagamento = 'mensal' and c.competencia = mes;
    cp := _comissao_lanca(p_ws, e.equipe_id, e.total, mes, coalesce(dia, 10),
      'Comissões de ' || to_char(mes, 'MM/YYYY') || ' · ' || (select nome from equipe where id = e.equipe_id) || case when coalesce(e.est, 0) > 0 then ' (com estornos)' else '' end, null);
    update comissoes set status = 'lancada', conta_pagar_id = cp, atualizado_em = now()
     where workspace_id = p_ws and equipe_id = e.equipe_id and status = 'prevista' and pagamento = 'mensal' and competencia = mes;
    update comissoes set status = 'estornada', estorno_conta_pagar_id = cp, atualizado_em = now()
     where workspace_id = p_ws and equipe_id = e.equipe_id and status = 'estorno_pendente' and competencia <= mes;
    res := res || jsonb_build_object('equipe_id', e.equipe_id, 'nome', (select nome from equipe where id = e.equipe_id), 'valor', e.total, 'conta_pagar_id', cp);
  end loop;
  return res;
end $$;
grant execute on function public.comissao_fechar_mes(uuid, date, uuid) to authenticated;

-- regra "só relatório": marcar como paga por fora (ou desfazer)
create or replace function public.comissao_marcar_paga(p_ids uuid[], p_paga boolean default true) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update comissoes c set status = case when p_paga then 'paga_manual' else 'prevista' end, atualizado_em = now()
   where c.id = any (p_ids) and perm(c.workspace_id, 'editar', '{fin,adm}'::text[])
     and ((p_paga and c.status = 'prevista' and c.pagamento = 'relatorio') or (not p_paga and c.status = 'paga_manual'));
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on function public.comissao_marcar_paga(uuid[], boolean) to authenticated;

-- extrato pronto para a tela (situação da conta a pagar incluída)
create or replace view v_comissoes with (security_invoker = true) as
select c.*, e.nome as pessoa, e.vinculo, e.equipe_comercial,
       r.escopo, coalesce(ca.nome, pr.nome, o.nome) as escopo_nome,
       cp.status as conta_status, cp.data_pagamento as conta_pago_em, cp.vencimento as conta_vencimento,
       case when c.status = 'lancada' and cp.status = 'pago' then 'paga'
            when c.status = 'lancada' and cp.status = 'cancelado' then 'conta_cancelada'
            else c.status end as situacao,
       coalesce(v.campanha_id, ct.campanha_id) as campanha_id, coalesce(v.produto_id, ci.produto_id) as produto_id, v.oferta_id,
       coalesce(pv.nome, pc.nome) as cliente, coalesce(prv.nome, prc.nome) as produto
  from comissoes c join equipe e on e.id = c.equipe_id
  left join comissao_regras r on r.id = c.regra_id
  left join campanhas ca on ca.id = r.campanha_id left join produtos pr on pr.id = r.produto_id left join ofertas o on o.id = r.oferta_id
  left join contas_pagar cp on cp.id = c.conta_pagar_id
  left join vendas v on v.id = c.venda_id left join pessoas pv on pv.id = v.pessoa_id left join produtos prv on prv.id = v.produto_id
  left join contas_receber crr on crr.id = c.conta_receber_id left join contratos ct on ct.id = crr.contrato_id left join pessoas pc on pc.id = ct.pessoa_id
  left join lateral (select produto_id from contrato_itens where contrato_id = ct.id order by valor desc limit 1) ci on true
  left join produtos prc on prc.id = ci.produto_id;
grant select on v_comissoes to authenticated;

-- v0.120 — Conexões com Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube)
-- Login OAuth pela edge function "conexoes"; dados puxados pela edge function "sincronizar".
-- Os tokens ficam no schema "privado" (fora da API do Supabase): só as funções do servidor (service_role) leem.
-- Anúncios importados caem primeiro em ads_externo_dia e são ligados ao canal da campanha pelo nome/utm_campaign
-- (ou pelo vínculo escolhido na tela); daí entram em anuncios + metricas_anuncio_dia (origem "integracao").
-- Orgânico: social_perfis_dia (seguidores, alcance… por dia) e social_posts (cada post/vídeo com métricas).
-- YouTube: vídeos cadastrados em Vídeos e webinários (plataforma youtube + id) recebem video_metricas_dia.
-- Rode depois de 20261022100000_comissoes.sql. Pode rodar de novo.

create schema if not exists privado;
revoke all on schema privado from public, anon, authenticated;
grant usage on schema privado to service_role;

create table if not exists conexoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plataforma text not null check (plataforma in ('meta', 'google')),
  status text not null default 'desconectado' check (status in ('conectado', 'expirada', 'erro', 'desconectado')),
  conta_nome text, escopos text[] not null default '{}',
  conectado_em timestamptz, conectado_por uuid, expira_em timestamptz,
  ultima_sincronizacao timestamptz, ultimo_erro text,
  sincronizar_auto boolean not null default true, dias_retroativos smallint not null default 30 check (dias_retroativos between 1 and 365),
  criado_em timestamptz not null default now(),
  unique (workspace_id, plataforma)
);

create table if not exists privado.conexao_tokens (
  conexao_id uuid primary key references public.conexoes(id) on delete cascade,
  access_token text not null, refresh_token text, expira_em timestamptz, atualizado_em timestamptz not null default now()
);
revoke all on privado.conexao_tokens from public, anon, authenticated;
grant select, insert, update, delete on privado.conexao_tokens to service_role;

create table if not exists privado.conexao_estados (
  nonce text primary key, workspace_id uuid not null, plataforma text not null, user_id uuid, volta text,
  expira_em timestamptz not null default now() + interval '15 minutes'
);
revoke all on privado.conexao_estados from public, anon, authenticated;

create table if not exists conexao_contas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conexao_id uuid not null references conexoes(id) on delete cascade,
  tipo text not null check (tipo in ('meta_ads', 'instagram', 'facebook_pagina', 'google_ads', 'youtube')),
  id_externo text not null, nome text, sincronizar boolean not null default true, extras jsonb not null default '{}',
  criado_em timestamptz not null default now(),
  unique (conexao_id, tipo, id_externo)
);

create table if not exists conexao_execucoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conexao_id uuid references conexoes(id) on delete cascade,
  iniciado_em timestamptz not null default now(), terminado_em timestamptz,
  status text not null default 'rodando' check (status in ('rodando', 'ok', 'parcial', 'erro')),
  registros int not null default 0, erro text, detalhe jsonb not null default '{}', disparado_por text
);
create index if not exists conexao_execucoes_idx on conexao_execucoes (workspace_id, iniciado_em desc);

create table if not exists ads_externo_dia (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  provedor text not null, data date not null,
  campanha_ext text not null, campanha_nome text, conjunto_nome text,
  anuncio_ext text not null, anuncio_nome text, url_tags text,
  impressoes bigint not null default 0, cliques bigint not null default 0, custo numeric not null default 0, alcance bigint,
  leads int, conversoes numeric, receita numeric,
  anuncio_id uuid references anuncios(id) on delete set null,
  atualizado_em timestamptz not null default now(),
  primary key (conta_id, anuncio_ext, data)
);
create index if not exists ads_externo_ws_idx on ads_externo_dia (workspace_id, provedor, campanha_ext);

create table if not exists ads_externo_vinculos (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  provedor text not null, campanha_ext text not null, campanha_nome text,
  campanha_canal_id uuid references campanha_canais(id) on delete cascade,
  ignorar boolean not null default false,
  primary key (workspace_id, provedor, campanha_ext)
);

create table if not exists social_perfis_dia (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  data date not null,
  seguidores int, seguidores_ganhos int, alcance int, impressoes int, visualizacoes int, visitas_perfil int, cliques_site int,
  minutos_assistidos numeric, atualizado_em timestamptz not null default now(),
  primary key (conta_id, data)
);

create table if not exists social_posts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  id_externo text not null, tipo text, legenda text, url text, miniatura text, publicado_em timestamptz,
  alcance int, impressoes int, visualizacoes int, curtidas int, comentarios int, compartilhamentos int, salvamentos int,
  minutos_assistidos numeric, conteudo_publicacao_id uuid references conteudo_publicacoes(id) on delete set null,
  atualizado_em timestamptz not null default now(),
  unique (conta_id, id_externo)
);

-- acesso pelo navegador: ler (Configurações e Marketing); editar só o que é escolha (contas a sincronizar, vínculos)
do $$ declare t text; begin
  foreach t in array array['conexoes', 'conexao_contas', 'conexao_execucoes', 'ads_externo_dia', 'ads_externo_vinculos', 'social_perfis_dia', 'social_posts'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists acesso_ler on %I', t);
    execute format('create policy acesso_ler on %I for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, ''ler'', ''{cfg,mkt,adm}''::text[]))', t);
    execute format('grant select on %I to authenticated', t);
  end loop;
end $$;
drop policy if exists escolher on conexao_contas;
create policy escolher on conexao_contas for update to authenticated using (perm(workspace_id, 'editar', '{cfg}'::text[])) with check (perm(workspace_id, 'editar', '{cfg}'::text[]));
grant update (sincronizar) on conexao_contas to authenticated;
drop policy if exists escolher on conexoes;
create policy escolher on conexoes for update to authenticated using (perm(workspace_id, 'editar', '{cfg}'::text[])) with check (perm(workspace_id, 'editar', '{cfg}'::text[]));
grant update (sincronizar_auto, dias_retroativos) on conexoes to authenticated;
drop policy if exists vincular on ads_externo_vinculos;
create policy vincular on ads_externo_vinculos for all to authenticated using (perm(workspace_id, 'editar', '{cfg,mkt}'::text[])) with check (perm(workspace_id, 'editar', '{cfg,mkt}'::text[]));
grant insert, update, delete on ads_externo_vinculos to authenticated;

-- ===== chamadas do navegador (usuário logado) =====
create or replace function public.conexao_iniciar(p_ws uuid, p_plataforma text, p_volta text) returns text
language plpgsql security definer set search_path = public as $$
declare n text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not perm(p_ws, 'editar', '{cfg}'::text[]) then raise exception 'Só quem edita Configurações pode conectar contas'; end if;
  if p_plataforma not in ('meta', 'google') then raise exception 'Plataforma inválida'; end if;
  delete from privado.conexao_estados where expira_em < now();
  insert into privado.conexao_estados (nonce, workspace_id, plataforma, user_id, volta) values (n, p_ws, p_plataforma, auth.uid(), left(p_volta, 500));
  return n;
end $$;
grant execute on function public.conexao_iniciar(uuid, text, text) to authenticated;

create or replace function public.conexao_pode(p_ws uuid) returns boolean
language sql stable security definer set search_path = public as $$ select perm(p_ws, 'editar', '{cfg,mkt}'::text[]) $$;
grant execute on function public.conexao_pode(uuid) to authenticated;

create or replace function public.conexao_desconectar(p_ws uuid, p_plataforma text) returns void
language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  if not perm(p_ws, 'editar', '{cfg}'::text[]) then raise exception 'Só quem edita Configurações pode desconectar'; end if;
  select id into c from conexoes where workspace_id = p_ws and plataforma = p_plataforma;
  delete from privado.conexao_tokens where conexao_id = c;
  update conexoes set status = 'desconectado', expira_em = null where id = c;
  update integracoes set status = 'desconectado' where workspace_id = p_ws
     and provedor = any (case p_plataforma when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end);
end $$;
grant execute on function public.conexao_desconectar(uuid, text) to authenticated;

-- ===== chamadas das edge functions (service_role) =====
create or replace function public.conexao_estado_usar(p_nonce text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e privado.conexao_estados;
begin
  delete from privado.conexao_estados where nonce = p_nonce returning * into e;
  if e.nonce is null or e.expira_em < now() then return null; end if;
  return jsonb_build_object('ws', e.workspace_id, 'plataforma', e.plataforma, 'uid', e.user_id, 'volta', e.volta);
end $$;

create or replace function public.conexao_salvar(p_ws uuid, p_plataforma text, p_uid uuid, p_conta_nome text, p_escopos text[], p_access text, p_refresh text, p_expira timestamptz, p_contas jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid; x jsonb; provs text[] := case p_plataforma when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end; p text;
begin
  insert into conexoes (workspace_id, plataforma, status, conta_nome, escopos, conectado_em, conectado_por, expira_em, ultimo_erro)
  values (p_ws, p_plataforma, 'conectado', p_conta_nome, coalesce(p_escopos, '{}'), now(), p_uid, p_expira, null)
  on conflict (workspace_id, plataforma) do update set status = 'conectado', conta_nome = excluded.conta_nome, escopos = excluded.escopos,
     conectado_em = now(), conectado_por = excluded.conectado_por, expira_em = excluded.expira_em, ultimo_erro = null
  returning id into c;
  insert into privado.conexao_tokens (conexao_id, access_token, refresh_token, expira_em) values (c, p_access, p_refresh, p_expira)
  on conflict (conexao_id) do update set access_token = excluded.access_token,
     refresh_token = coalesce(excluded.refresh_token, privado.conexao_tokens.refresh_token), expira_em = excluded.expira_em, atualizado_em = now();
  for x in select * from jsonb_array_elements(coalesce(p_contas, '[]'::jsonb)) loop
    insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome, extras)
    values (p_ws, c, x ->> 'tipo', x ->> 'id', x ->> 'nome', coalesce(x -> 'extras', '{}'::jsonb))
    on conflict (conexao_id, tipo, id_externo) do update set nome = excluded.nome, extras = excluded.extras;
  end loop;
  foreach p in array provs loop
    insert into integracoes (workspace_id, provedor, categoria, status, conta_externa, observacao, ultima_sincronizacao)
    values (p_ws, p, case when p in ('Meta Ads', 'Google Ads') then 'anuncios' when p = 'YouTube' then 'video' else 'social' end, 'conectado', p_conta_nome, 'Conectado pelo login da plataforma.', null)
    on conflict (workspace_id, provedor) do update set status = 'conectado', conta_externa = excluded.conta_externa;
  end loop;
  return c;
end $$;

create or replace function public.conexao_para_sincronizar(p_ws uuid, p_plataforma text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ws', c.workspace_id, 'plataforma', c.plataforma, 'dias', c.dias_retroativos, 'ultima', c.ultima_sincronizacao,
      'access_token', t.access_token, 'refresh_token', t.refresh_token, 'expira_em', t.expira_em,
      'contas', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'tipo', k.tipo, 'id_externo', k.id_externo, 'nome', k.nome, 'extras', k.extras)) from conexao_contas k where k.conexao_id = c.id and k.sincronizar), '[]'::jsonb),
      'videos', case when c.plataforma = 'google' then coalesce((select jsonb_agg(jsonb_build_object('fonte_id', f.id, 'video', f.id_externo)) from fontes_video f where f.workspace_id = c.workspace_id and f.plataforma = 'youtube' and f.ativo and f.id_externo is not null), '[]'::jsonb) end)), '[]'::jsonb)
    from conexoes c join privado.conexao_tokens t on t.conexao_id = c.id
   where c.status in ('conectado', 'expirada', 'erro') and (p_ws is null or c.workspace_id = p_ws) and (p_plataforma is null or c.plataforma = p_plataforma)
     and (p_ws is not null or c.sincronizar_auto)
$$;

create or replace function public.conexao_token_atualizar(p_conexao uuid, p_access text, p_expira timestamptz) returns void
language sql security definer set search_path = public as $$
  update privado.conexao_tokens set access_token = p_access, expira_em = p_expira, atualizado_em = now() where conexao_id = p_conexao;
  update conexoes set expira_em = p_expira, status = 'conectado' where id = p_conexao;
$$;

create or replace function public.conexao_execucao(p_conexao uuid, p_id uuid, p_status text, p_registros int, p_erro text, p_detalhe jsonb, p_por text) returns uuid
language plpgsql security definer set search_path = public as $$
declare i uuid := p_id; ws uuid;
begin
  select workspace_id into ws from conexoes where id = p_conexao;
  if i is null then
    insert into conexao_execucoes (workspace_id, conexao_id, disparado_por) values (ws, p_conexao, p_por) returning id into i;
  else
    update conexao_execucoes set terminado_em = now(), status = p_status, registros = coalesce(p_registros, 0), erro = p_erro, detalhe = coalesce(p_detalhe, '{}') where id = i;
    update conexoes set ultima_sincronizacao = case when p_status in ('ok', 'parcial') then now() else ultima_sincronizacao end,
           ultimo_erro = p_erro, status = case when p_erro ~* 'token|oauth|expir|invalid_grant|session' then 'expirada' when p_status = 'erro' then 'erro' else 'conectado' end
     where id = p_conexao;
    update integracoes set ultima_sincronizacao = now(), status = case when p_status = 'erro' then 'erro' else 'conectado' end
     where workspace_id = ws and status <> 'desconectado'
       and provedor = any (case (select plataforma from conexoes where id = p_conexao) when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end);
  end if;
  return i;
end $$;

-- grava o que veio da plataforma. p_tipo: ads | perfil | posts | video
create or replace function public.conexao_gravar(p_conta uuid, p_tipo text, p_linhas jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare k conexao_contas; x jsonb; n int := 0; f uuid;
begin
  select * into k from conexao_contas where id = p_conta;
  if k.id is null then raise exception 'Conta não encontrada'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_linhas, '[]'::jsonb)) loop
    if p_tipo = 'ads' then
      insert into ads_externo_dia (workspace_id, conta_id, provedor, data, campanha_ext, campanha_nome, conjunto_nome, anuncio_ext, anuncio_nome, url_tags, impressoes, cliques, custo, alcance, leads, conversoes, receita)
      values (k.workspace_id, k.id, k.tipo, (x ->> 'data')::date, x ->> 'campanha_ext', x ->> 'campanha_nome', x ->> 'conjunto_nome', x ->> 'anuncio_ext', x ->> 'anuncio_nome', x ->> 'url_tags',
              coalesce((x ->> 'impressoes')::bigint, 0), coalesce((x ->> 'cliques')::bigint, 0), coalesce((x ->> 'custo')::numeric, 0), (x ->> 'alcance')::bigint,
              (x ->> 'leads')::int, (x ->> 'conversoes')::numeric, (x ->> 'receita')::numeric)
      on conflict (conta_id, anuncio_ext, data) do update set campanha_ext = excluded.campanha_ext, campanha_nome = excluded.campanha_nome, conjunto_nome = excluded.conjunto_nome,
         anuncio_nome = excluded.anuncio_nome, url_tags = coalesce(excluded.url_tags, ads_externo_dia.url_tags), impressoes = excluded.impressoes, cliques = excluded.cliques,
         custo = excluded.custo, alcance = excluded.alcance, leads = excluded.leads, conversoes = excluded.conversoes, receita = excluded.receita, atualizado_em = now();
    elsif p_tipo = 'perfil' then
      insert into social_perfis_dia (workspace_id, conta_id, data, seguidores, seguidores_ganhos, alcance, impressoes, visualizacoes, visitas_perfil, cliques_site, minutos_assistidos)
      values (k.workspace_id, k.id, (x ->> 'data')::date, (x ->> 'seguidores')::int, (x ->> 'seguidores_ganhos')::int, (x ->> 'alcance')::int, (x ->> 'impressoes')::int,
              (x ->> 'visualizacoes')::int, (x ->> 'visitas_perfil')::int, (x ->> 'cliques_site')::int, (x ->> 'minutos_assistidos')::numeric)
      on conflict (conta_id, data) do update set
         seguidores = coalesce(excluded.seguidores, social_perfis_dia.seguidores), seguidores_ganhos = coalesce(excluded.seguidores_ganhos, social_perfis_dia.seguidores_ganhos),
         alcance = coalesce(excluded.alcance, social_perfis_dia.alcance), impressoes = coalesce(excluded.impressoes, social_perfis_dia.impressoes),
         visualizacoes = coalesce(excluded.visualizacoes, social_perfis_dia.visualizacoes), visitas_perfil = coalesce(excluded.visitas_perfil, social_perfis_dia.visitas_perfil),
         cliques_site = coalesce(excluded.cliques_site, social_perfis_dia.cliques_site), minutos_assistidos = coalesce(excluded.minutos_assistidos, social_perfis_dia.minutos_assistidos), atualizado_em = now();
    elsif p_tipo = 'posts' then
      insert into social_posts (workspace_id, conta_id, id_externo, tipo, legenda, url, miniatura, publicado_em, alcance, impressoes, visualizacoes, curtidas, comentarios, compartilhamentos, salvamentos, minutos_assistidos)
      values (k.workspace_id, k.id, x ->> 'id', x ->> 'tipo', left(x ->> 'legenda', 2000), x ->> 'url', x ->> 'miniatura', (x ->> 'publicado_em')::timestamptz,
              (x ->> 'alcance')::int, (x ->> 'impressoes')::int, (x ->> 'visualizacoes')::int, (x ->> 'curtidas')::int, (x ->> 'comentarios')::int, (x ->> 'compartilhamentos')::int,
              (x ->> 'salvamentos')::int, (x ->> 'minutos_assistidos')::numeric)
      on conflict (conta_id, id_externo) do update set tipo = excluded.tipo, legenda = excluded.legenda, url = excluded.url, miniatura = excluded.miniatura, publicado_em = excluded.publicado_em,
         alcance = coalesce(excluded.alcance, social_posts.alcance), impressoes = coalesce(excluded.impressoes, social_posts.impressoes), visualizacoes = coalesce(excluded.visualizacoes, social_posts.visualizacoes),
         curtidas = excluded.curtidas, comentarios = excluded.comentarios, compartilhamentos = coalesce(excluded.compartilhamentos, social_posts.compartilhamentos),
         salvamentos = coalesce(excluded.salvamentos, social_posts.salvamentos), minutos_assistidos = coalesce(excluded.minutos_assistidos, social_posts.minutos_assistidos), atualizado_em = now();
    elsif p_tipo = 'video' then
      f := (x ->> 'fonte_id')::uuid;
      if not exists (select 1 from fontes_video where id = f and workspace_id = k.workspace_id) then continue; end if;
      insert into video_metricas_dia (workspace_id, fonte_id, data, plays, espectadores, tempo_assistido_seg, retencao_pct, origem, disponibilidade, atualizado_na_origem)
      values (k.workspace_id, f, (x ->> 'data')::date, coalesce((x ->> 'plays')::int, 0), coalesce((x ->> 'espectadores')::int, 0), coalesce(round((x ->> 'minutos')::numeric * 60), 0)::bigint,
              least(100, greatest(0, (x ->> 'retencao_pct')::numeric)), 'integracao', 'parcial', now())
      on conflict (fonte_id, data) do update set plays = excluded.plays, espectadores = excluded.espectadores, tempo_assistido_seg = excluded.tempo_assistido_seg,
         retencao_pct = coalesce(excluded.retencao_pct, video_metricas_dia.retencao_pct), origem = 'integracao', atualizado_na_origem = now();
    else raise exception 'Tipo inválido: %', p_tipo;
    end if;
    n := n + 1;
  end loop;
  if p_tipo = 'ads' then perform ads_externo_aplicar(k.workspace_id); end if;
  return n;
end $$;

-- liga anúncio externo ao canal da campanha e grava em anuncios + metricas_anuncio_dia
create or replace function public.ads_externo_aplicar(p_ws uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare g record; cc uuid; an uuid; ut text; n int := 0; sem int := 0;
begin
  -- vínculo automático: utm_campaign do canal = nome da campanha externa, ou utm_campaign= nas url_tags
  insert into ads_externo_vinculos (workspace_id, provedor, campanha_ext, campanha_nome, campanha_canal_id)
  select distinct on (a.provedor, a.campanha_ext) a.workspace_id, a.provedor, a.campanha_ext, a.campanha_nome, c.id
    from ads_externo_dia a join campanha_canais c on c.workspace_id = a.workspace_id and c.utm_campaign is not null and c.utm_campaign <> ''
     and (lower(c.utm_campaign) = lower(a.campanha_nome) or lower(c.utm_campaign) = lower(substring(a.url_tags from 'utm_campaign=([^&]+)')))
   where a.workspace_id = p_ws
  on conflict (workspace_id, provedor, campanha_ext) do update set campanha_canal_id = coalesce(ads_externo_vinculos.campanha_canal_id, excluded.campanha_canal_id), campanha_nome = excluded.campanha_nome;
  insert into ads_externo_vinculos (workspace_id, provedor, campanha_ext, campanha_nome)
  select distinct a.workspace_id, a.provedor, a.campanha_ext, a.campanha_nome from ads_externo_dia a where a.workspace_id = p_ws
  on conflict (workspace_id, provedor, campanha_ext) do update set campanha_nome = excluded.campanha_nome;
  for g in select a.provedor, a.anuncio_ext, max(a.anuncio_nome) nome, max(a.url_tags) tags, v.campanha_canal_id cc
             from ads_externo_dia a join ads_externo_vinculos v on v.workspace_id = a.workspace_id and v.provedor = a.provedor and v.campanha_ext = a.campanha_ext
            where a.workspace_id = p_ws and v.campanha_canal_id is not null and not v.ignorar
            group by 1, 2, 5 loop
    ut := coalesce(nullif(substring(g.tags from 'utm_content=([^&]+)'), ''), nullif(g.nome, ''), g.anuncio_ext);
    select id into an from anuncios where campanha_canal_id = g.cc and (id_externo = g.anuncio_ext or lower(utm_content) = lower(ut)) order by (id_externo = g.anuncio_ext) desc limit 1;
    if an is null then
      insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, id_externo, ativo) values (p_ws, g.cc, coalesce(g.nome, g.anuncio_ext), ut, g.anuncio_ext, true)
      on conflict (campanha_canal_id, utm_content) do update set id_externo = coalesce(anuncios.id_externo, excluded.id_externo) returning id into an;
    elsif (select id_externo from anuncios where id = an) is null then
      update anuncios set id_externo = g.anuncio_ext where id = an;
    end if;
    update ads_externo_dia set anuncio_id = an where workspace_id = p_ws and provedor = g.provedor and anuncio_ext = g.anuncio_ext;
    insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, alcance, origem, disponibilidade, atualizado_na_origem)
    select p_ws, an, a.data, sum(a.impressoes), sum(a.cliques), sum(a.custo), sum(a.alcance), 'integracao', 'completo', max(a.atualizado_em)
      from ads_externo_dia a where a.workspace_id = p_ws and a.provedor = g.provedor and a.anuncio_ext = g.anuncio_ext group by a.data
    on conflict (anuncio_id, data) do update set impressoes = excluded.impressoes, cliques = excluded.cliques, custo = excluded.custo, alcance = excluded.alcance,
       origem = 'integracao', disponibilidade = 'completo', atualizado_na_origem = excluded.atualizado_na_origem;
    n := n + 1;
  end loop;
  select count(*) into sem from ads_externo_vinculos where workspace_id = p_ws and campanha_canal_id is null and not ignorar;
  return jsonb_build_object('anuncios', n, 'campanhas_sem_vinculo', sem);
end $$;

-- o navegador chama depois de ligar uma campanha externa a um canal
create or replace function public.ads_externo_religar(p_ws uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not perm(p_ws, 'editar', '{cfg,mkt}'::text[]) then raise exception 'Sem permissão'; end if;
  return ads_externo_aplicar(p_ws);
end $$;
grant execute on function public.ads_externo_religar(uuid) to authenticated;

do $$ declare f text; begin
  foreach f in array array['conexao_estado_usar(text)', 'conexao_salvar(uuid,text,uuid,text,text[],text,text,timestamptz,jsonb)', 'conexao_para_sincronizar(uuid,text)',
    'conexao_token_atualizar(uuid,text,timestamptz)', 'conexao_execucao(uuid,uuid,text,integer,text,jsonb,text)', 'conexao_gravar(uuid,text,jsonb)', 'ads_externo_aplicar(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
