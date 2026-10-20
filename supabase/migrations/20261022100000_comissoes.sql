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
