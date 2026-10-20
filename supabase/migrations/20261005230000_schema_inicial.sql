-- =====================================================================
-- GROWTHS — esquema inicial (Supabase / Postgres 15+)
-- Ordem: rode este arquivo, depois supabase/seed.sql, depois supabase/exemplos/simular_vendas.sql.
-- Tudo é multi-cliente: cada tabela tem workspace_id e RLS por membro.
-- Valores de taxa, prazo e imposto nos seeds são EXEMPLOS: ajuste nas tabelas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Workspaces (um por cliente) e membros
-- ---------------------------------------------------------------------
create table workspaces (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_em timestamptz not null default now()
);

create table workspace_membros (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  papel text not null default 'admin' check (papel in ('admin', 'editor', 'leitor')),
  primary key (workspace_id, user_id)
);

create function pertence_ao_workspace(ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from workspace_membros m
    where m.workspace_id = ws and m.user_id = auth.uid()
  );
$$;

-- Quem pode operar: membro do workspace, SQL Editor (postgres) ou service_role.
create function pode_operar(ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select pertence_ao_workspace(ws)
      or session_user in ('postgres', 'supabase_admin')
      or coalesce(auth.role(), '') = 'service_role';
$$;

-- ---------------------------------------------------------------------
-- 2. Cadastros contábeis e financeiros
-- ---------------------------------------------------------------------
create table centros_custo (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  codigo text not null,
  nome text not null,
  ativo boolean not null default true,
  unique (workspace_id, codigo)
);

create table plano_contas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  codigo text not null,
  nome text not null,
  tipo text not null check (tipo in ('ativo', 'passivo', 'patrimonio', 'receita', 'deducao', 'custo', 'despesa')),
  natureza text not null check (natureza in ('devedora', 'credora')),
  conta_pai_id uuid references plano_contas(id),
  aceita_lancamento boolean not null default true,
  ativo boolean not null default true,
  unique (workspace_id, codigo)
);

create table contas_bancarias (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  banco text,
  saldo_inicial numeric(14, 2) not null default 0,
  conta_contabil_id uuid not null references plano_contas(id),
  padrao boolean not null default false,
  ativa boolean not null default true
);
create unique index contas_bancarias_padrao_uq on contas_bancarias (workspace_id) where padrao;

-- Regras de contabilização: qual conta debita e qual credita em cada evento.
-- Conta nula = usa a conta contábil da conta bancária envolvida.
create table regras_contabilizacao (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  evento text not null check (evento in (
    'venda_receita', 'venda_taxa_plataforma', 'venda_imposto', 'recebimento', 'estorno_pagamento')),
  descricao text,
  conta_debito_id uuid references plano_contas(id),
  conta_credito_id uuid references plano_contas(id),
  ativo boolean not null default true,
  unique (workspace_id, evento)
);

create table impostos_config (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  aliquota_percentual numeric(6, 3) not null check (aliquota_percentual >= 0),
  base text not null default 'valor_bruto' check (base in ('valor_bruto', 'valor_liquido')),
  ativo boolean not null default true
);

-- ---------------------------------------------------------------------
-- 3. Plataformas de venda, formas de pagamento, produtos
-- ---------------------------------------------------------------------
create table plataformas_venda (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  taxa_percentual numeric(6, 3) not null default 0,   -- padrão da plataforma
  taxa_fixa numeric(12, 2) not null default 0,        -- padrão por venda
  ativa boolean not null default true,
  observacoes text
);

-- Taxa (opcional) e prazo de recebimento por forma de pagamento.
-- Taxa nula = usa o padrão da plataforma.
create table plataforma_formas_pagamento (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plataforma_id uuid not null references plataformas_venda(id) on delete cascade,
  forma_pagamento text not null check (forma_pagamento in ('pix', 'cartao_credito', 'boleto', 'outro')),
  taxa_percentual numeric(6, 3),
  taxa_fixa numeric(12, 2),
  prazo_recebimento_dias int not null default 0 check (prazo_recebimento_dias >= 0),
  ativa boolean not null default true,
  unique (plataforma_id, forma_pagamento)
);

create table produtos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  tag text not null,                                   -- tag que vai para o Kanban de alunos
  tipo text not null default 'curso' check (tipo in ('curso', 'assinatura', 'servico', 'outro')),
  recorrente boolean not null default false,
  periodicidade text check (periodicidade in ('mensal', 'trimestral', 'semestral', 'anual')),
  preco numeric(12, 2) not null check (preco >= 0),
  taxa_percentual_override numeric(6, 3),              -- taxa diferenciada deste produto
  taxa_fixa_override numeric(12, 2),
  centro_custo_id uuid references centros_custo(id),
  ativo boolean not null default true,
  check (recorrente = (periodicidade is not null))
);

create table produto_plataforma (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  produto_id uuid not null references produtos(id) on delete cascade,
  plataforma_id uuid not null references plataformas_venda(id) on delete cascade,
  id_externo text,
  primary key (produto_id, plataforma_id)
);

-- ---------------------------------------------------------------------
-- 4. Campanhas e metas
-- ---------------------------------------------------------------------
create table campanhas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  status text not null default 'planejada' check (status in ('planejada', 'ativa', 'pausada', 'encerrada')),
  data_inicio date,
  data_fim date,
  produto_id uuid references produtos(id),
  orcamento_total numeric(14, 2),
  meta_leads int,
  meta_vendas int,
  meta_taxa_lead_venda numeric(6, 3),                  -- % de leads que viram venda
  meta_receita numeric(14, 2),
  meta_cac numeric(12, 2),
  observacoes text
);

-- Meta de aquisição por canal dentro da campanha (e a utm_campaign que identifica o canal).
create table campanha_canais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  canal text not null check (canal in ('google_ads', 'meta_ads', 'tiktok_ads', 'email', 'organico', 'whatsapp', 'outro')),
  utm_campaign text not null,
  orcamento numeric(14, 2),
  percentual_meta_leads numeric(6, 3),
  meta_leads int,
  meta_vendas int,
  meta_cac numeric(12, 2),
  unique (workspace_id, utm_campaign)
);

-- ---------------------------------------------------------------------
-- 5. CRM: Kanbans, pessoas e histórico
-- ---------------------------------------------------------------------
create table etapas_kanban (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  quadro text not null check (quadro in ('leads', 'alunos')),
  nome text not null,
  ordem int not null,
  unique (workspace_id, quadro, nome)
);

create table pessoas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  email text,
  telefone text,
  -- ciclo de vida
  status_funil text not null default 'lead' check (status_funil in ('lead', 'cliente')),
  status_cliente text check (status_cliente in ('ativo', 'inativo')),
  etapa_kanban_id uuid references etapas_kanban(id),
  -- origem (primeira captura)
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  pagina_origem text,
  campanha_id uuid references campanhas(id),
  canal_origem text,
  -- qualificação (pesquisa da página de obrigado)
  respostas_pesquisa jsonb,
  pesquisa_respondida_em timestamptz,
  pontuacao_qualificacao numeric(6, 2),
  qualificacao text not null default 'pendente' check (qualificacao in ('pendente', 'qualificado', 'nao_qualificado')),
  criado_em timestamptz not null default now(),
  convertido_em timestamptz,
  check ((status_funil = 'cliente') = (status_cliente is not null))
);
create unique index pessoas_email_uq on pessoas (workspace_id, lower(email)) where email is not null;
create index pessoas_utm_campaign_ix on pessoas (workspace_id, utm_campaign);
create index pessoas_status_ix on pessoas (workspace_id, status_funil);

-- Histórico append-only das mudanças de ciclo de vida e qualificação.
create table pessoa_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  campo text not null,
  valor_anterior text,
  valor_novo text,
  alterado_em timestamptz not null default now()
);

create function pessoas_antes_inserir() returns trigger
language plpgsql security definer set search_path = public as $$
declare cc record;
begin
  if new.campanha_id is null and new.utm_campaign is not null then
    select campanha_id, canal into cc
    from campanha_canais
    where workspace_id = new.workspace_id and utm_campaign = new.utm_campaign;
    if found then
      new.campanha_id := cc.campanha_id;
      new.canal_origem := coalesce(new.canal_origem, cc.canal);
    end if;
  end if;
  if new.etapa_kanban_id is null then
    select id into new.etapa_kanban_id from etapas_kanban
    where workspace_id = new.workspace_id and quadro = 'leads'
    order by ordem limit 1;
  end if;
  return new;
end $$;
create trigger pessoas_antes_inserir before insert on pessoas
  for each row execute function pessoas_antes_inserir();

create function pessoas_registrar_historico() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status_funil is distinct from old.status_funil then
    insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
    values (new.workspace_id, new.id, 'status_funil', old.status_funil, new.status_funil);
  end if;
  if new.status_cliente is distinct from old.status_cliente then
    insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
    values (new.workspace_id, new.id, 'status_cliente', old.status_cliente, new.status_cliente);
  end if;
  if new.qualificacao is distinct from old.qualificacao then
    insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
    values (new.workspace_id, new.id, 'qualificacao', old.qualificacao, new.qualificacao);
  end if;
  return null;
end $$;
create trigger pessoas_historico after update on pessoas
  for each row execute function pessoas_registrar_historico();

-- ---------------------------------------------------------------------
-- 6. Vendas, contas a receber, estornos, alunos
-- ---------------------------------------------------------------------
create table vendas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id),
  produto_id uuid not null references produtos(id),
  plataforma_id uuid not null references plataformas_venda(id),
  campanha_id uuid references campanhas(id),
  forma_pagamento text not null check (forma_pagamento in ('pix', 'cartao_credito', 'boleto', 'outro')),
  parcelas int not null default 1 check (parcelas >= 1),
  status text not null default 'aprovada' check (status in ('pendente', 'aprovada', 'cancelada', 'reembolsada', 'chargeback')),
  data_venda timestamptz not null default now(),
  valor_bruto numeric(14, 2) not null check (valor_bruto >= 0),
  taxa_plataforma numeric(14, 2),      -- calculada se não informada
  impostos numeric(14, 2),             -- calculado se não informado
  valor_a_receber numeric(14, 2),      -- bruto - taxa (o que a plataforma repassa)
  valor_liquido numeric(14, 2),        -- a receber - impostos
  data_prevista_recebimento date,
  conta_bancaria_id uuid references contas_bancarias(id),
  id_externo text,
  criado_em timestamptz not null default now()
);
create index vendas_data_ix on vendas (workspace_id, data_venda);
create index vendas_pessoa_ix on vendas (pessoa_id);

create table contas_receber (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  venda_id uuid not null unique references vendas(id),
  valor numeric(14, 2) not null,
  vencimento date not null,
  status text not null default 'previsto' check (status in ('previsto', 'recebido', 'cancelado', 'estornado')),
  data_recebimento date,
  conta_bancaria_id uuid references contas_bancarias(id)
);
create index contas_receber_ix on contas_receber (workspace_id, status, vencimento);

create table alunos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id),
  produto_id uuid not null references produtos(id),
  venda_id uuid not null unique references vendas(id),
  tag text not null,
  etapa_kanban_id uuid references etapas_kanban(id),
  status text not null default 'ativo' check (status in ('ativo', 'inativo', 'cancelado')),
  entrou_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7. Razão contábil (append-only) e movimentação bancária
-- ---------------------------------------------------------------------
create table lancamentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  data_fato date not null,
  descricao text,
  origem_tipo text not null check (origem_tipo in ('venda', 'recebimento', 'estorno', 'manual')),
  origem_id uuid,
  estorno_de uuid references lancamentos(id),
  criado_em timestamptz not null default now()
);

create table partidas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  lancamento_id uuid not null references lancamentos(id),
  conta_id uuid not null references plano_contas(id),
  centro_custo_id uuid references centros_custo(id),
  tipo text not null check (tipo in ('D', 'C')),
  valor numeric(14, 2) not null check (valor > 0)
);
create index partidas_lancamento_ix on partidas (lancamento_id);

create table movimentacoes_bancarias (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_bancaria_id uuid not null references contas_bancarias(id),
  data date not null,
  tipo text not null check (tipo in ('entrada', 'saida')),
  valor numeric(14, 2) not null check (valor > 0),
  descricao text,
  origem_tipo text,
  origem_id uuid,
  lancamento_id uuid references lancamentos(id)
);

create table estornos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  venda_id uuid not null references vendas(id),
  tipo text not null check (tipo in ('cancelamento', 'reembolso', 'chargeback')),
  valor numeric(14, 2) not null,
  motivo text,
  data date not null,
  lancamento_id uuid references lancamentos(id),
  criado_em timestamptz not null default now()
);

-- Débito = crédito em todo lançamento, conferido ao final da transação.
create function checa_lancamento_balanceado() returns trigger
language plpgsql as $$
declare saldo numeric;
begin
  select coalesce(sum(case tipo when 'D' then valor else -valor end), 0) into saldo
  from partidas where lancamento_id = new.lancamento_id;
  if saldo <> 0 then
    raise exception 'Lançamento % desbalanceado: débitos e créditos diferem em %', new.lancamento_id, saldo;
  end if;
  return null;
end $$;
create constraint trigger partidas_balanceadas after insert on partidas
  deferrable initially deferred for each row execute function checa_lancamento_balanceado();

-- ---------------------------------------------------------------------
-- 8. Funções: taxas, impostos, venda -> partidas, recebimento, estorno
-- ---------------------------------------------------------------------
create function calcular_taxa_venda(p_produto uuid, p_plataforma uuid, p_forma text, p_bruto numeric)
returns numeric language plpgsql stable security definer set search_path = public as $$
declare pr produtos; fp plataforma_formas_pagamento; pl plataformas_venda; pct numeric; fixo numeric;
begin
  select * into pr from produtos where id = p_produto;
  select * into fp from plataforma_formas_pagamento
    where plataforma_id = p_plataforma and forma_pagamento = p_forma and ativa;
  select * into pl from plataformas_venda where id = p_plataforma;
  -- prioridade: produto > forma de pagamento > padrão da plataforma
  pct := coalesce(pr.taxa_percentual_override, fp.taxa_percentual, pl.taxa_percentual, 0);
  fixo := coalesce(pr.taxa_fixa_override, fp.taxa_fixa, pl.taxa_fixa, 0);
  return round(p_bruto * pct / 100 + fixo, 2);
end $$;

create function calcular_impostos(p_ws uuid, p_bruto numeric, p_taxa numeric)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(round(
    case base when 'valor_bruto' then p_bruto else p_bruto - p_taxa end * aliquota_percentual / 100, 2)), 0)
  from impostos_config where workspace_id = p_ws and ativo;
$$;

create function vendas_antes_inserir() returns trigger
language plpgsql security definer set search_path = public as $$
declare prazo int; pc uuid;
begin
  -- impede referenciar cadastros de outro cliente
  if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id)
     or not exists (select 1 from produtos where id = new.produto_id and workspace_id = new.workspace_id)
     or not exists (select 1 from plataformas_venda where id = new.plataforma_id and workspace_id = new.workspace_id) then
    raise exception 'Pessoa, produto e plataforma precisam pertencer ao mesmo workspace da venda';
  end if;
  if new.taxa_plataforma is null then
    new.taxa_plataforma := calcular_taxa_venda(new.produto_id, new.plataforma_id, new.forma_pagamento, new.valor_bruto);
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
create trigger vendas_antes_inserir before insert on vendas
  for each row execute function vendas_antes_inserir();

create function _partida(p_lanc uuid, p_ws uuid, p_conta uuid, p_cc uuid, p_tipo text, p_valor numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_conta is null then raise exception 'Conta contábil não definida na regra de contabilização'; end if;
  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  values (p_ws, p_lanc, p_conta, p_cc, p_tipo, p_valor);
end $$;

create function _regra(p_ws uuid, p_evento text)
returns regras_contabilizacao language plpgsql stable security definer set search_path = public as $$
declare r regras_contabilizacao;
begin
  select * into r from regras_contabilizacao where workspace_id = p_ws and evento = p_evento and ativo;
  if not found then raise exception 'Regra de contabilização "%" não configurada', p_evento; end if;
  return r;
end $$;

-- Venda aprovada -> lançamento contábil, conta a receber, cliente e aluno.
create function processar_venda(p_venda uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v vendas; pr produtos; l uuid; r regras_contabilizacao;
begin
  select * into v from vendas where id = p_venda for update;
  if not found then raise exception 'Venda % não encontrada', p_venda; end if;
  if not pode_operar(v.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if v.status <> 'aprovada' then raise exception 'Só vendas aprovadas geram partidas'; end if;

  select id into l from lancamentos where origem_tipo = 'venda' and origem_id = v.id;
  if l is not null then return l; end if;   -- já processada

  select * into pr from produtos where id = v.produto_id;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (v.workspace_id, (v.data_venda at time zone 'America/Sao_Paulo')::date,
          'Venda: ' || pr.nome, 'venda', v.id)
  returning id into l;

  r := _regra(v.workspace_id, 'venda_receita');
  perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.valor_bruto);
  perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.valor_bruto);

  if v.taxa_plataforma > 0 then
    r := _regra(v.workspace_id, 'venda_taxa_plataforma');
    perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.taxa_plataforma);
    perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.taxa_plataforma);
  end if;

  if v.impostos > 0 then
    r := _regra(v.workspace_id, 'venda_imposto');
    perform _partida(l, v.workspace_id, r.conta_debito_id, pr.centro_custo_id, 'D', v.impostos);
    perform _partida(l, v.workspace_id, r.conta_credito_id, pr.centro_custo_id, 'C', v.impostos);
  end if;

  insert into contas_receber (workspace_id, venda_id, valor, vencimento, conta_bancaria_id)
  values (v.workspace_id, v.id, v.valor_a_receber, v.data_prevista_recebimento, v.conta_bancaria_id);

  update pessoas set
    status_funil = 'cliente',
    status_cliente = 'ativo',
    convertido_em = coalesce(convertido_em, now()),
    etapa_kanban_id = coalesce(
      (select id from etapas_kanban where workspace_id = v.workspace_id and quadro = 'leads' and nome = 'Cliente'),
      etapa_kanban_id)
  where id = v.pessoa_id;

  insert into alunos (workspace_id, pessoa_id, produto_id, venda_id, tag, etapa_kanban_id)
  values (v.workspace_id, v.pessoa_id, v.produto_id, v.id, pr.tag,
          (select id from etapas_kanban where workspace_id = v.workspace_id and quadro = 'alunos'
           order by ordem limit 1))
  on conflict (venda_id) do nothing;

  return l;
end $$;

create function vendas_depois() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
    perform processar_venda(new.id);
  end if;
  return null;
end $$;
create trigger vendas_depois after insert or update of status on vendas
  for each row execute function vendas_depois();

-- Dinheiro entrou na conta: lançamento, movimentação bancária e baixa da conta a receber.
create function registrar_recebimento(p_conta_receber uuid, p_data date default null, p_conta_bancaria uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare cr contas_receber; r regras_contabilizacao; v_banco uuid; v_banco_contabil uuid; l uuid; d date;
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
  r := _regra(cr.workspace_id, 'recebimento');

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id)
  values (cr.workspace_id, d, 'Recebimento de venda', 'recebimento', cr.id)
  returning id into l;
  perform _partida(l, cr.workspace_id, coalesce(r.conta_debito_id, v_banco_contabil), null, 'D', cr.valor);
  perform _partida(l, cr.workspace_id, coalesce(r.conta_credito_id, v_banco_contabil), null, 'C', cr.valor);

  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
  values (cr.workspace_id, v_banco, d, 'entrada', cr.valor, 'Recebimento de venda', 'recebimento', cr.id, l);

  update contas_receber set status = 'recebido', data_recebimento = d, conta_bancaria_id = v_banco where id = cr.id;
  return l;
end $$;

-- Recebe de uma vez tudo o que venceu até a data (útil para simular o caixa).
create function registrar_recebimentos_ate(p_ws uuid, p_ate date default null)
returns int language plpgsql security definer set search_path = public as $$
declare cr record; n int := 0; ate date;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  ate := coalesce(p_ate, (now() at time zone 'America/Sao_Paulo')::date);
  for cr in select id, vencimento from contas_receber
            where workspace_id = p_ws and status = 'previsto' and vencimento <= ate and conta_bancaria_id is not null
            order by vencimento loop
    perform registrar_recebimento(cr.id, cr.vencimento);
    n := n + 1;
  end loop;
  return n;
end $$;

-- Cancelamento, reembolso ou chargeback: reverte as partidas da venda e,
-- se o dinheiro já entrou, devolve da conta bancária.
create function registrar_estorno(p_venda uuid, p_tipo text, p_motivo text default null, p_data date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v vendas; cr contas_receber; r regras_contabilizacao; l0 uuid; l1 uuid; d date; banco_contabil uuid;
begin
  if p_tipo not in ('cancelamento', 'reembolso', 'chargeback') then
    raise exception 'Tipo de estorno inválido: % (use cancelamento, reembolso ou chargeback)', p_tipo;
  end if;
  select * into v from vendas where id = p_venda for update;
  if not found then raise exception 'Venda % não encontrada', p_venda; end if;
  if not pode_operar(v.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if v.status <> 'aprovada' then raise exception 'Venda já está %', v.status; end if;

  d := coalesce(p_data, (now() at time zone 'America/Sao_Paulo')::date);
  select id into l0 from lancamentos where origem_tipo = 'venda' and origem_id = v.id;
  if l0 is null then raise exception 'Venda sem partidas contábeis para estornar'; end if;

  insert into lancamentos (workspace_id, data_fato, descricao, origem_tipo, origem_id, estorno_de)
  values (v.workspace_id, d, 'Estorno (' || p_tipo || ') de venda', 'estorno', v.id, l0)
  returning id into l1;

  insert into partidas (workspace_id, lancamento_id, conta_id, centro_custo_id, tipo, valor)
  select workspace_id, l1, conta_id, centro_custo_id, case tipo when 'D' then 'C' else 'D' end, valor
  from partidas where lancamento_id = l0;

  select * into cr from contas_receber where venda_id = v.id for update;
  if cr.status = 'recebido' then
    select conta_contabil_id into banco_contabil from contas_bancarias where id = cr.conta_bancaria_id;
    r := _regra(v.workspace_id, 'estorno_pagamento');
    perform _partida(l1, v.workspace_id, coalesce(r.conta_debito_id, banco_contabil), null, 'D', cr.valor);
    perform _partida(l1, v.workspace_id, coalesce(r.conta_credito_id, banco_contabil), null, 'C', cr.valor);
    insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor, descricao, origem_tipo, origem_id, lancamento_id)
    values (v.workspace_id, cr.conta_bancaria_id, d, 'saida', cr.valor, 'Estorno de venda (' || p_tipo || ')', 'estorno', v.id, l1);
    update contas_receber set status = 'estornado' where id = cr.id;
  else
    update contas_receber set status = 'cancelado' where id = cr.id;
  end if;

  insert into estornos (workspace_id, venda_id, tipo, valor, motivo, data, lancamento_id)
  values (v.workspace_id, v.id, p_tipo, v.valor_bruto, p_motivo, d, l1);

  update vendas set status = case p_tipo
    when 'cancelamento' then 'cancelada' when 'reembolso' then 'reembolsada' else 'chargeback' end
  where id = v.id;

  update alunos set status = 'cancelado' where venda_id = v.id;

  update pessoas set status_cliente = 'inativo'
  where id = v.pessoa_id
    and not exists (select 1 from vendas where pessoa_id = v.pessoa_id and status = 'aprovada' and id <> v.id);

  return l1;
end $$;

-- ---------------------------------------------------------------------
-- 9. Provisionar um workspace novo (cliente) com o padrão
-- ---------------------------------------------------------------------
create function provisionar_workspace(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare ws uuid; r record;
begin
  if not (session_user in ('postgres', 'supabase_admin')
          or coalesce(auth.role(), '') = 'service_role'
          or auth.uid() is not null) then
    raise exception 'Sem permissão para criar workspace';
  end if;

  insert into workspaces (nome) values (p_nome) returning id into ws;
  if auth.uid() is not null then
    insert into workspace_membros (workspace_id, user_id, papel) values (ws, auth.uid(), 'admin');
  end if;

  insert into centros_custo (workspace_id, codigo, nome) values
    (ws, 'GERAL', 'Geral'),
    (ws, 'GOOGLE', 'Aquisição – Google Ads'),
    (ws, 'META', 'Aquisição – Meta Ads'),
    (ws, 'PRODUTO', 'Produtos digitais');

  for r in select * from (values
    ('1',      'Ativo',                                   'ativo',      'devedora', null,    false),
    ('1.1',    'Ativo circulante',                        'ativo',      'devedora', '1',     false),
    ('1.1.01', 'Bancos e caixa',                          'ativo',      'devedora', '1.1',   true),
    ('1.1.02', 'Contas a receber – plataformas de venda', 'ativo',      'devedora', '1.1',   true),
    ('2',      'Passivo',                                 'passivo',    'credora',  null,    false),
    ('2.1',    'Passivo circulante',                      'passivo',    'credora',  '2',     false),
    ('2.1.01', 'Fornecedores a pagar',                    'passivo',    'credora',  '2.1',   true),
    ('2.1.02', 'Impostos a recolher',                     'passivo',    'credora',  '2.1',   true),
    ('3',      'Patrimônio líquido',                      'patrimonio', 'credora',  null,    false),
    ('3.1',    'Capital e resultados',                    'patrimonio', 'credora',  '3',     false),
    ('3.1.01', 'Capital e resultados acumulados',         'patrimonio', 'credora',  '3.1',   true),
    ('4',      'Receitas',                                'receita',    'credora',  null,    false),
    ('4.1',    'Receita bruta',                           'receita',    'credora',  '4',     false),
    ('4.1.01', 'Receita de vendas de produtos digitais',  'receita',    'credora',  '4.1',   true),
    ('4.1.02', 'Receita de serviços',                     'receita',    'credora',  '4.1',   true),
    ('5',      'Deduções da receita',                     'deducao',    'devedora', null,    false),
    ('5.1',    'Deduções',                                'deducao',    'devedora', '5',     false),
    ('5.1.01', 'Taxas de plataformas de venda',           'deducao',    'devedora', '5.1',   true),
    ('5.1.02', 'Impostos sobre vendas',                   'deducao',    'devedora', '5.1',   true),
    ('6',      'Custos e despesas',                       'despesa',    'devedora', null,    false),
    ('6.1',    'Aquisição de clientes',                   'despesa',    'devedora', '6',     false),
    ('6.1.01', 'Mídia paga – Google Ads',                 'despesa',    'devedora', '6.1',   true),
    ('6.1.02', 'Mídia paga – Meta Ads',                   'despesa',    'devedora', '6.1',   true),
    ('6.2',    'Operação',                                'despesa',    'devedora', '6',     false),
    ('6.2.01', 'Ferramentas e software',                  'despesa',    'devedora', '6.2',   true),
    ('6.2.02', 'Equipe e prestadores',                    'despesa',    'devedora', '6.2',   true),
    ('6.2.03', 'Comissões e afiliados',                   'despesa',    'devedora', '6.2',   true)
  ) as t(codigo, nome, tipo, natureza, pai, aceita) loop
    insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento)
    values (ws, r.codigo, r.nome, r.tipo, r.natureza,
            (select id from plano_contas where workspace_id = ws and codigo = r.pai), r.aceita);
  end loop;

  insert into regras_contabilizacao (workspace_id, evento, descricao, conta_debito_id, conta_credito_id)
  select ws, e.evento, e.descricao,
         (select id from plano_contas where workspace_id = ws and codigo = e.deb),
         (select id from plano_contas where workspace_id = ws and codigo = e.cred)
  from (values
    ('venda_receita',         'Venda aprovada: reconhece a receita e o valor a receber da plataforma', '1.1.02', '4.1.01'),
    ('venda_taxa_plataforma', 'Taxa descontada pela plataforma de venda',                              '5.1.01', '1.1.02'),
    ('venda_imposto',         'Imposto incidente sobre a venda',                                       '5.1.02', '2.1.02'),
    ('recebimento',           'Plataforma repassou o dinheiro (débito = conta bancária)',              null,     '1.1.02'),
    ('estorno_pagamento',     'Devolução do dinheiro já recebido (crédito = conta bancária)',          '1.1.02', null)
  ) as e(evento, descricao, deb, cred);

  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values
    (ws, 'leads',  'Novo lead',    1),
    (ws, 'leads',  'Em contato',   2),
    (ws, 'leads',  'Negociação',   3),
    (ws, 'leads',  'Cliente',      4),
    (ws, 'alunos', 'Novo aluno',   1),
    (ws, 'alunos', 'Onboarding',   2),
    (ws, 'alunos', 'Em andamento', 3),
    (ws, 'alunos', 'Concluído',    4);

  return ws;
end $$;

-- Liga um usuário (pelo e-mail do login) a um workspace. Uso: SQL Editor.
create function vincular_usuario(p_workspace uuid, p_email text, p_papel text default 'admin') returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then raise exception 'Usuário % não encontrado em auth.users (crie o login antes)', p_email; end if;
  insert into workspace_membros (workspace_id, user_id, papel) values (p_workspace, uid, p_papel)
  on conflict (workspace_id, user_id) do update set papel = excluded.papel;
end $$;

-- ---------------------------------------------------------------------
-- 10. Views para dashboards (respeitam a RLS de quem consulta)
-- ---------------------------------------------------------------------
create view v_saldo_contas_bancarias with (security_invoker = true) as
select cb.id as conta_bancaria_id, cb.workspace_id, cb.nome, cb.saldo_inicial,
       cb.saldo_inicial + coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0) as saldo_atual
from contas_bancarias cb
left join movimentacoes_bancarias m on m.conta_bancaria_id = cb.id
group by cb.id;

create view v_fluxo_caixa with (security_invoker = true) as
select workspace_id, vencimento as data, 'previsto'::text as situacao,
       sum(valor) as entradas, 0::numeric as saidas
from contas_receber where status = 'previsto' group by workspace_id, vencimento
union all
select workspace_id, data, 'realizado'::text,
       sum(case when tipo = 'entrada' then valor else 0 end),
       sum(case when tipo = 'saida' then valor else 0 end)
from movimentacoes_bancarias group by workspace_id, data;

create view v_dre_mensal with (security_invoker = true) as
select l.workspace_id, date_trunc('month', l.data_fato)::date as mes,
       pc.tipo, pc.codigo, pc.nome as conta,
       sum(case when pc.natureza = 'credora'
                then case p.tipo when 'C' then p.valor else -p.valor end
                else case p.tipo when 'D' then p.valor else -p.valor end end) as valor
from partidas p
join lancamentos l on l.id = p.lancamento_id
join plano_contas pc on pc.id = p.conta_id
where pc.tipo in ('receita', 'deducao', 'custo', 'despesa')
group by l.workspace_id, date_trunc('month', l.data_fato), pc.tipo, pc.codigo, pc.nome;

create view v_funil_campanha with (security_invoker = true) as
with leads as (
  select campanha_id, count(*) as leads,
         count(*) filter (where qualificacao = 'qualificado') as qualificados
  from pessoas where campanha_id is not null group by campanha_id
), vend as (
  select campanha_id, count(*) filter (where status = 'aprovada') as vendas,
         coalesce(sum(valor_bruto) filter (where status = 'aprovada'), 0) as receita_bruta
  from vendas where campanha_id is not null group by campanha_id
)
select c.id as campanha_id, c.workspace_id, c.nome, c.meta_leads, c.meta_vendas, c.meta_receita,
       coalesce(l.leads, 0) as leads, coalesce(l.qualificados, 0) as leads_qualificados,
       coalesce(v.vendas, 0) as vendas, coalesce(v.receita_bruta, 0) as receita_bruta
from campanhas c
left join leads l on l.campanha_id = c.id
left join vend v on v.campanha_id = c.id;

-- ---------------------------------------------------------------------
-- 11. Segurança: RLS por workspace
-- ---------------------------------------------------------------------
alter table workspaces enable row level security;
create policy workspaces_leitura on workspaces for select to authenticated using (pertence_ao_workspace(id));
alter table workspace_membros enable row level security;
create policy membros_leitura on workspace_membros for select to authenticated using (user_id = auth.uid());

do $$
declare t text;
begin
  -- leitura e escrita pelos membros
  foreach t in array array['centros_custo', 'plano_contas', 'contas_bancarias', 'regras_contabilizacao',
      'impostos_config', 'plataformas_venda', 'plataforma_formas_pagamento', 'produtos', 'produto_plataforma',
      'campanhas', 'campanha_canais', 'etapas_kanban', 'pessoas', 'alunos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
  end loop;
  -- somente leitura (alteradas só pelas funções)
  foreach t in array array['lancamentos', 'partidas', 'estornos', 'pessoa_historico',
      'movimentacoes_bancarias', 'contas_receber'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for select to authenticated using (pertence_ao_workspace(workspace_id))', t || '_leitura', t);
  end loop;
end $$;

-- vendas: sem exclusão (o ledger não pode ficar sem origem)
alter table vendas enable row level security;
create policy vendas_leitura on vendas for select to authenticated using (pertence_ao_workspace(workspace_id));
create policy vendas_insercao on vendas for insert to authenticated with check (pertence_ao_workspace(workspace_id));
create policy vendas_edicao on vendas for update to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

-- Funções internas não ficam expostas pela API; só as de uso do app.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function pertence_ao_workspace(uuid) to authenticated;
grant execute on function registrar_recebimento(uuid, date, uuid) to authenticated;
grant execute on function registrar_recebimentos_ate(uuid, date) to authenticated;
grant execute on function registrar_estorno(uuid, text, text, date) to authenticated;
grant execute on function provisionar_workspace(text) to authenticated;
