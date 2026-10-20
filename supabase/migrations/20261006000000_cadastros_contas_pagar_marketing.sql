-- =====================================================================
-- v0.2.0: canais, funis, fornecedores, contas a pagar, planejamento mensal,
-- venda direta (sem plataforma) e views de marketing.
-- =====================================================================

-- ---------- Canais (cadastro) ----------
create table canais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  codigo text not null,
  nome text not null,
  utm_source text,
  utm_medium text,
  ativo boolean not null default true,
  unique (workspace_id, codigo)
);

-- ---------- Funis (cadastro) ----------
create table funis (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  tipo text not null default 'captacao' check (tipo in ('captacao', 'lancamento', 'perpetuo', 'assinatura', 'outro')),
  produto_id uuid references produtos(id) on delete set null,
  descricao text,
  ativo boolean not null default true
);
alter table campanhas add column funil_id uuid references funis(id) on delete set null;

-- ---------- Fornecedores ----------
create table fornecedores (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  documento text,
  email text,
  telefone text,
  categoria text,
  ativo boolean not null default true
);

-- ---------- Planejamento mensal ----------
create table planejamento_mensal (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  ano int not null,
  mes int not null check (mes between 1 and 12),
  meta_leads int,
  meta_vendas int,
  meta_receita numeric(14, 2),
  orcamento numeric(14, 2),
  unique (workspace_id, ano, mes)
);

-- ---------- Regras e lançamentos aceitam os novos eventos ----------
alter table regras_contabilizacao drop constraint if exists regras_contabilizacao_evento_check;
alter table regras_contabilizacao add constraint regras_contabilizacao_evento_check check (evento in (
  'venda_receita', 'venda_taxa_plataforma', 'venda_imposto', 'recebimento', 'estorno_pagamento',
  'conta_pagar', 'pagamento'));

alter table lancamentos drop constraint if exists lancamentos_origem_tipo_check;
alter table lancamentos add constraint lancamentos_origem_tipo_check check (origem_tipo in (
  'venda', 'recebimento', 'estorno', 'manual', 'conta_pagar', 'pagamento', 'cancelamento_pagar'));

-- ---------- Contas a pagar ----------
create table contas_pagar (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  fornecedor_id uuid references fornecedores(id),
  descricao text not null,
  valor numeric(14, 2) not null check (valor > 0),
  competencia date,
  vencimento date not null,
  conta_despesa_id uuid not null references plano_contas(id),
  centro_custo_id uuid references centros_custo(id),
  campanha_id uuid references campanhas(id),
  campanha_canal_id uuid references campanha_canais(id),
  status text not null default 'previsto' check (status in ('previsto', 'pago', 'cancelado')),
  data_pagamento date,
  conta_bancaria_id uuid references contas_bancarias(id),
  criado_em timestamptz not null default now()
);
create index contas_pagar_ix on contas_pagar (workspace_id, status, vencimento);

create function contas_pagar_antes_inserir() returns trigger
language plpgsql security definer set search_path = public as $$
declare tp text; aceita boolean; cc_camp uuid;
begin
  select tipo, aceita_lancamento into tp, aceita from plano_contas
    where id = new.conta_despesa_id and workspace_id = new.workspace_id;
  if tp is null then raise exception 'Conta de despesa inválida para este workspace'; end if;
  if tp not in ('despesa', 'custo') or not aceita then
    raise exception 'Escolha uma conta de despesa ou custo que aceite lançamento';
  end if;
  if (new.fornecedor_id is not null and not exists (select 1 from fornecedores where id = new.fornecedor_id and workspace_id = new.workspace_id))
     or (new.centro_custo_id is not null and not exists (select 1 from centros_custo where id = new.centro_custo_id and workspace_id = new.workspace_id))
     or (new.campanha_id is not null and not exists (select 1 from campanhas where id = new.campanha_id and workspace_id = new.workspace_id)) then
    raise exception 'Fornecedor, centro de custo e campanha precisam pertencer ao mesmo workspace';
  end if;
  if new.campanha_canal_id is not null then
    select campanha_id into cc_camp from campanha_canais where id = new.campanha_canal_id and workspace_id = new.workspace_id;
    if cc_camp is null then raise exception 'Canal da campanha inválido para este workspace'; end if;
    new.campanha_id := coalesce(new.campanha_id, cc_camp);
  end if;
  new.status := 'previsto';
  new.data_pagamento := null;
  new.conta_bancaria_id := null;
  new.competencia := coalesce(new.competencia, new.vencimento);
  return new;
end $$;
create trigger contas_pagar_antes_inserir before insert on contas_pagar
  for each row execute function contas_pagar_antes_inserir();

create function contas_pagar_depois() returns trigger
language plpgsql security definer set search_path = public as $$
declare r regras_contabilizacao; l uuid;
begin
  r := _regra(new.workspace_id, 'conta_pagar');
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (new.workspace_id, new.competencia, 'Despesa: ' || new.descricao, 'conta_pagar', new.id)
  returning id into l;
  perform _partida(l, new.workspace_id, coalesce(r.conta_debito_id, new.conta_despesa_id), new.centro_custo_id, 'D', new.valor);
  perform _partida(l, new.workspace_id, r.conta_credito_id, new.centro_custo_id, 'C', new.valor);
  return null;
end $$;
create trigger contas_pagar_depois after insert on contas_pagar
  for each row execute function contas_pagar_depois();

create function registrar_pagamento(p_conta uuid, p_data date default null, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar % não encontrada', p_conta; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'previsto' then raise exception 'Conta a pagar já está %', cp.status; end if;

  v_banco := coalesce(p_conta_bancaria,
    (select id from contas_bancarias where workspace_id = cp.workspace_id and padrao and ativa limit 1));
  if v_banco is null then raise exception 'Informe a conta bancária do pagamento'; end if;
  select conta_contabil_id into v_banco_contabil from contas_bancarias
    where id = v_banco and workspace_id = cp.workspace_id;
  if v_banco_contabil is null then raise exception 'Conta bancária inválida para este workspace'; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  r := _regra(cp.workspace_id, 'pagamento');

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cp.workspace_id, d, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id)
  returning id into l;
  perform _partida(l, cp.workspace_id, r.conta_debito_id, null, 'D', cp.valor);
  perform _partida(l, cp.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cp.valor);

  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  values (cp.workspace_id, v_banco, d, 'saida', cp.valor, 'Pagamento: ' || cp.descricao, 'pagamento', cp.id, l);

  update contas_pagar set status = 'pago', data_pagamento = d, conta_bancaria_id = v_banco where id = cp.id;
  return l;
end $$;

create function cancelar_conta_pagar(p_conta uuid, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cp contas_pagar; l0 uuid; l1 uuid; d date;
begin
  select * into cp from contas_pagar where id = p_conta for update;
  if not found then raise exception 'Conta a pagar % não encontrada', p_conta; end if;
  if not pode_operar(cp.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if cp.status <> 'previsto' then raise exception 'Só dá para cancelar conta ainda não paga (esta está %)', cp.status; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select id into l0 from lancamentos where origem_tipo = 'conta_pagar' and origem_id = cp.id;
  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (cp.workspace_id, d, 'Cancelamento: ' || cp.descricao, 'cancelamento_pagar', cp.id, l0)
  returning id into l1;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor
  from partidas where lancamento_id = l0;

  update contas_pagar set status = 'cancelado' where id = cp.id;
  return l1;
end $$;

-- ---------- Provisionamento: acrescenta regras, canais e funil padrão ----------
create function _provisionar_extras(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into regras_contabilizacao (workspace_id, evento, descricao, conta_debito_id, conta_credito_id)
  select p_ws, e.evento, e.descricao,
         (select id from plano_contas where workspace_id = p_ws and codigo = e.deb),
         (select id from plano_contas where workspace_id = p_ws and codigo = e.cred)
  from (values
    ('conta_pagar', 'Conta a pagar: débito = conta de despesa escolhida na conta; crédito = fornecedores a pagar', null, '2.1.01'),
    ('pagamento',   'Pagamento: baixa fornecedores a pagar (crédito = conta bancária)',                          '2.1.01', null)
  ) as e(evento, descricao, deb, cred)
  on conflict (workspace_id, evento) do nothing;

  insert into canais (workspace_id, codigo, nome, utm_source, utm_medium)
  select p_ws, c.codigo, c.nome, c.s, c.m from (values
    ('google_ads', 'Google Ads', 'google',    'cpc'),
    ('meta_ads',   'Meta Ads',   'facebook',  'paid'),
    ('tiktok_ads', 'TikTok Ads', 'tiktok',    'paid'),
    ('email',      'E-mail',     'email',     'email'),
    ('organico',   'Orgânico',   'organic',   'organic'),
    ('whatsapp',   'WhatsApp',   'whatsapp',  'chat'),
    ('outro',      'Outro',      null,        null)
  ) as c(codigo, nome, s, m)
  on conflict (workspace_id, codigo) do nothing;

  insert into funis (workspace_id, nome, tipo, descricao)
  select p_ws, 'Funil principal', 'captacao', 'Funil padrão criado automaticamente.'
  where not exists (select 1 from funis where workspace_id = p_ws);
end $$;

select _provisionar_extras(id) from workspaces;

alter table campanha_canais drop constraint if exists campanha_canais_canal_check;
alter table campanha_canais add constraint campanha_canais_canal_fk
  foreign key (workspace_id, canal) references canais (workspace_id, codigo) on update cascade;

alter function provisionar_workspace(text) rename to _provisionar_base;
create function provisionar_workspace(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  ws := _provisionar_base(p_nome);
  perform _provisionar_extras(ws);
  return ws;
end $$;

-- ---------- Venda direta: plataforma passa a ser opcional ----------
alter table vendas alter column plataforma_id drop not null;

create or replace function vendas_antes_inserir() returns trigger
language plpgsql security definer set search_path = public as $$
declare prazo int; pc uuid;
begin
  if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id)
     or not exists (select 1 from produtos where id = new.produto_id and workspace_id = new.workspace_id)
     or (new.plataforma_id is not null
         and not exists (select 1 from plataformas_venda where id = new.plataforma_id and workspace_id = new.workspace_id)) then
    raise exception 'Pessoa, produto e plataforma precisam pertencer ao mesmo workspace da venda';
  end if;
  if new.taxa_plataforma is null then
    new.taxa_plataforma := case when new.plataforma_id is null then 0
      else calcular_taxa_venda(new.produto_id, new.plataforma_id, new.forma_pagamento, new.valor_bruto) end;
  end if;
  if new.impostos is null then
    new.impostos := calcular_impostos(new.workspace_id, new.valor_bruto, new.taxa_plataforma);
  end if;
  new.valor_a_receber := new.valor_bruto - new.taxa_plataforma;
  new.valor_liquido := new.valor_a_receber - new.impostos;
  if new.data_prevista_recebimento is null then
    select prazo_recebimento_dias into prazo from plataforma_formas_pagamento
      where plataforma_id = new.plataforma_id and forma_pagamento = new.forma_pagamento;
    new.data_prevista_recebimento := (new.data_venda at time zone 'America/Sao_Paulo')::date + coalesce(prazo, 0);
  end if;
  if new.conta_bancaria_id is null then
    select id into new.conta_bancaria_id from contas_bancarias
      where workspace_id = new.workspace_id and padrao and ativa limit 1;
  end if;
  if new.campanha_id is null then
    select campanha_id into pc from pessoas where id = new.pessoa_id;
    new.campanha_id := pc;
  end if;
  return new;
end $$;

-- ---------- Fluxo de caixa agora inclui contas a pagar ----------
create or replace view v_fluxo_caixa with (security_invoker = true) as
select workspace_id, vencimento as data, 'previsto'::text as situacao,
       sum(valor) as entradas, 0::numeric as saidas
from contas_receber where status = 'previsto' group by workspace_id, vencimento
union all
select workspace_id, vencimento, 'previsto'::text, 0::numeric, sum(valor)
from contas_pagar where status = 'previsto' group by workspace_id, vencimento
union all
select workspace_id, data, 'realizado'::text,
       sum(case when tipo = 'entrada' then valor else 0 end),
       sum(case when tipo = 'saida' then valor else 0 end)
from movimentacoes_bancarias group by workspace_id, data;

-- ---------- Views de marketing (cálculo determinístico no banco) ----------
create view v_marketing_campanha with (security_invoker = true) as
with inv as (
  select campanha_id, sum(valor) as investimento
  from contas_pagar where status <> 'cancelado' and campanha_id is not null group by campanha_id
), ld as (
  select campanha_id, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados
  from pessoas where campanha_id is not null group by campanha_id
), vd as (
  select campanha_id,
         count(*) filter (where status = 'aprovada') as vendas,
         coalesce(sum(valor_bruto) filter (where status = 'aprovada'), 0) as receita_bruta,
         count(distinct pessoa_id) filter (where status = 'aprovada') as clientes
  from vendas where campanha_id is not null group by campanha_id
)
select c.id as campanha_id, c.workspace_id, c.nome, c.status, c.orcamento_total,
       c.meta_leads, c.meta_vendas, c.meta_receita, c.meta_cac,
       coalesce(inv.investimento, 0) as investimento,
       coalesce(ld.leads, 0) as leads, coalesce(ld.qualificados, 0) as qualificados,
       coalesce(vd.vendas, 0) as vendas, coalesce(vd.clientes, 0) as clientes,
       coalesce(vd.receita_bruta, 0) as receita_bruta,
       round(coalesce(inv.investimento, 0) / nullif(ld.leads, 0), 2) as cpl,
       round(coalesce(inv.investimento, 0) / nullif(vd.clientes, 0), 2) as cac,
       round(vd.receita_bruta / nullif(inv.investimento, 0), 2) as roas,
       round(vd.vendas::numeric * 100 / nullif(ld.leads, 0), 2) as taxa_lead_venda
from campanhas c
left join inv on inv.campanha_id = c.id
left join ld on ld.campanha_id = c.id
left join vd on vd.campanha_id = c.id;

create view v_marketing_canal with (security_invoker = true) as
with inv as (
  select campanha_canal_id, sum(valor) as investimento
  from contas_pagar where status <> 'cancelado' and campanha_canal_id is not null group by campanha_canal_id
), ld as (
  select workspace_id, utm_campaign, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados
  from pessoas where utm_campaign is not null group by workspace_id, utm_campaign
), vd as (
  select p.workspace_id, p.utm_campaign,
         count(*) filter (where v.status = 'aprovada') as vendas,
         coalesce(sum(v.valor_bruto) filter (where v.status = 'aprovada'), 0) as receita_bruta,
         count(distinct v.pessoa_id) filter (where v.status = 'aprovada') as clientes
  from vendas v join pessoas p on p.id = v.pessoa_id
  where p.utm_campaign is not null group by p.workspace_id, p.utm_campaign
)
select cc.id as campanha_canal_id, cc.workspace_id, cc.campanha_id, c.nome as campanha, cc.canal, cc.utm_campaign,
       cc.orcamento, cc.meta_leads, cc.meta_vendas, cc.meta_cac,
       coalesce(inv.investimento, 0) as investimento,
       coalesce(ld.leads, 0) as leads, coalesce(ld.qualificados, 0) as qualificados,
       coalesce(vd.vendas, 0) as vendas, coalesce(vd.clientes, 0) as clientes,
       coalesce(vd.receita_bruta, 0) as receita_bruta,
       round(coalesce(inv.investimento, 0) / nullif(ld.leads, 0), 2) as cpl,
       round(coalesce(inv.investimento, 0) / nullif(vd.clientes, 0), 2) as cac
from campanha_canais cc
join campanhas c on c.id = cc.campanha_id
left join inv on inv.campanha_canal_id = cc.id
left join ld on ld.workspace_id = cc.workspace_id and ld.utm_campaign = cc.utm_campaign
left join vd on vd.workspace_id = cc.workspace_id and vd.utm_campaign = cc.utm_campaign;

-- ---------- Segurança ----------
alter table canais enable row level security;
alter table funis enable row level security;
alter table fornecedores enable row level security;
alter table planejamento_mensal enable row level security;
create policy canais_acesso on canais for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy funis_acesso on funis for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy fornecedores_acesso on fornecedores for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy planejamento_acesso on planejamento_mensal for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

alter table contas_pagar enable row level security;
create policy contas_pagar_leitura on contas_pagar for select to authenticated using (pertence_ao_workspace(workspace_id));
create policy contas_pagar_insercao on contas_pagar for insert to authenticated with check (pertence_ao_workspace(workspace_id));

revoke execute on function contas_pagar_antes_inserir() from public, anon, authenticated;
revoke execute on function contas_pagar_depois() from public, anon, authenticated;
revoke execute on function _provisionar_extras(uuid) from public, anon, authenticated;
revoke execute on function _provisionar_base(text) from public, anon, authenticated;
revoke execute on function provisionar_workspace(text) from public, anon, authenticated;
revoke execute on function registrar_pagamento(uuid, date, uuid) from public, anon, authenticated;
revoke execute on function cancelar_conta_pagar(uuid, date) from public, anon, authenticated;
grant execute on function provisionar_workspace(text) to authenticated;
grant execute on function registrar_pagamento(uuid, date, uuid) to authenticated;
grant execute on function cancelar_conta_pagar(uuid, date) to authenticated;
