-- v0.85 — Pacotes de acesso por cliente (ex.: Disparo, Consultoria, Mentoria).
-- A equipe interna (Mathisa) monta pacotes com as telas liberadas e escolhe um pacote para cada cliente (workspace),
-- podendo ligar ou desligar telas só para aquele cliente. As funções e permissões de cada pessoa continuam valendo por cima:
-- o pacote define o que o cliente contratou; a função define o que cada pessoa do cliente pode fazer.
-- No banco: um módulo sem nenhuma tela liberada fica "nenhum" para todos do cliente (inclusive administradores), pela nivel_modulo.
-- Configurações e Cadastros nunca são bloqueados no banco (são usados por todos os módulos); as telas deles são escondidas só na tela.
-- Equipe e acessos e Funções e permissões ficam sempre liberadas para o administrador do cliente.
-- Cliente sem pacote e sem ajustes = sem restrição (como hoje). Rode depois de 20261008230000_seguranca_fase1.sql. Idempotente.

-- catálogo das telas (o mesmo do menu do sistema)
create table if not exists acesso_telas (
  tela text primary key,
  modulo text not null,
  nome text not null,
  grupo text,
  ordem int not null default 0
);
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values
('adm-painel', 'adm', 'Dashboard', 'Administrativo', 1),
('adm-dash', 'adm', 'Dashboard Growth', 'Administrativo', 2),
('ia-perguntar', 'adm', 'Pergunte aos dados', 'Administrativo', 3),
('adm-plano', 'adm', 'Planejamento da empresa', 'Administrativo', 4),
('adm-empresa', 'adm', 'Cadastro da empresa', 'Administrativo', 5),
('mkt-dash', 'mkt', 'Dashboard', 'Marketing', 6),
('mkt-midia', 'mkt', 'Dashboard de mídia', 'Marketing', 7),
('mkt-camp', 'mkt', 'Campanhas e planejamento', 'Marketing', 8),
('mkt-trafego', 'mkt', 'Mídia paga', 'Marketing', 9),
('mkt-video', 'mkt', 'Vídeos e webinários', 'Marketing', 10),
('mkt-cont', 'mkt', 'Planejamento de conteúdo', 'Marketing', 11),
('crm-dash', 'vendas', 'Dashboard', 'Vendas', 12),
('crm-leads', 'vendas', 'Funil comercial', 'Vendas', 13),
('crm-oport', 'vendas', 'Oportunidades', 'Vendas', 14),
('crm-vendas', 'vendas', 'Vendas', 'Vendas', 15),
('crm-contratos', 'vendas', 'Contratos', 'Vendas', 16),
('mkt-origem', 'vendas', 'Leads por origem', 'Vendas', 17),
('ho-dash', 'revops', 'Dashboard', 'RevOps', 18),
('ho-ascensao', 'revops', 'Ascensão da escada', 'RevOps', 19),
('ho-cohort', 'revops', 'Cohorts', 'RevOps', 20),
('crm-alunos', 'revops', 'Alunos', 'RevOps', 21),
('fin-dash', 'fin', 'Dashboard', 'Financeiro', 22),
('fin-receber', 'fin', 'Contas a receber', 'Financeiro', 23),
('fin-pagar', 'fin', 'Contas a pagar', 'Financeiro', 24),
('fin-lanc', 'fin', 'Lançamentos contábeis', 'Financeiro', 25),
('prj-lista', 'prj', 'Projetos', 'Projetos', 26),
('prj-minhas', 'prj', 'Minhas atividades', 'Projetos', 27),
('prj-modelos', 'prj', 'Modelos de projeto', 'Projetos', 28),
('prj-avisos', 'prj', 'Avisos', 'Projetos', 29),
('gro-diag', 'gro', 'Diagnóstico Growth', 'Growth', 30),
('gro-modelo', 'gro', 'Growth Loops', 'Growth', 31),
('gro-lucro', 'gro', 'Unit Economics', 'Growth', 32),
('gro-analise', 'gro', 'Análise de funil', 'Growth', 33),
('gro-pesq', 'gro', 'Pesquisas', 'Growth', 34),
('gro-ciclo', 'gro', 'Ciclo de Growth (Kanban)', 'Growth', 35),
('cfg-importar', 'cfg', 'Importar e validar dados', 'Configurações / Dados e integrações', 36),
('cfg-integracoes', 'cfg', 'Integrações', 'Configurações / Dados e integrações', 37),
('cfg-uso', 'cfg', 'Uso da plataforma', 'Configurações / Dados e integrações', 38),
('cad-equipe', 'cad', 'Equipe e acessos', 'Configurações / Pessoas e acessos', 39),
('cad-funcoes', 'cad', 'Funções e permissões', 'Configurações / Pessoas e acessos', 40),
('cad-clientes', 'cad', 'Clientes', 'Configurações / Comercial e produtos', 41),
('cad-produtos', 'cad', 'Produtos', 'Configurações / Comercial e produtos', 42),
('cad-plataformas', 'cad', 'Plataformas', 'Configurações / Comercial e produtos', 43),
('cad-canais', 'cad', 'Canais', 'Configurações / Comercial e produtos', 44),
('cad-funis', 'cad', 'Estratégias e funis', 'Configurações / Comercial e produtos', 45),
('cad-motivos', 'cad', 'Motivos de ganho e perda', 'Configurações / Comercial e produtos', 46),
('cad-planocontas', 'cad', 'Plano de contas', 'Configurações / Financeiro e contabilidade', 47),
('cad-regras', 'cad', 'Regras contábeis', 'Configurações / Financeiro e contabilidade', 48),
('cad-impostos', 'cad', 'Impostos', 'Configurações / Financeiro e contabilidade', 49),
('cad-bancos', 'cad', 'Contas bancárias', 'Configurações / Financeiro e contabilidade', 50),
('cad-formaspag', 'cad', 'Formas de pagamento', 'Configurações / Financeiro e contabilidade', 51),
('cad-fornecedores', 'cad', 'Fornecedores', 'Configurações / Financeiro e contabilidade', 52),
('cad-centros', 'cad', 'Centros de custo', 'Configurações / Financeiro e contabilidade', 53),
('cad-rateio', 'cad', 'Rateio de custos', 'Configurações / Financeiro e contabilidade', 54),
('st-dash', 'adm', 'Dashboard', 'Growth Starter', 55),
('st-relatorios', 'adm', 'Relatórios', 'Growth Starter', 56)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo, ordem = excluded.ordem;

create table if not exists pacotes_acesso (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  descricao text,
  telas text[] not null default '{}',
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

alter table workspaces add column if not exists pacote_id uuid references pacotes_acesso(id) on delete set null;
alter table workspaces add column if not exists acesso_liga text[] not null default '{}';
alter table workspaces add column if not exists acesso_desliga text[] not null default '{}';

alter table acesso_telas enable row level security;
alter table pacotes_acesso enable row level security;
drop policy if exists acesso_telas_ler on acesso_telas;
create policy acesso_telas_ler on acesso_telas for select to authenticated using (true);
drop policy if exists pacotes_acesso_ler on pacotes_acesso;
create policy pacotes_acesso_ler on pacotes_acesso for select to authenticated using (sou_equipe_interna());
-- escrita só pelas funções abaixo
revoke insert, update, delete on acesso_telas, pacotes_acesso from anon, authenticated;

-- telas liberadas de um cliente (null = sem restrição)
create or replace function public.acesso_telas_ws(p_ws uuid) returns text[]
language sql stable security definer set search_path = public as $$
  select case when w.pacote_id is null and cardinality(w.acesso_liga) = 0 and cardinality(w.acesso_desliga) = 0 then null
    else array(select distinct t from unnest(coalesce(p.telas, case when w.pacote_id is null then (select array_agg(tela) from acesso_telas) else '{}'::text[] end) || w.acesso_liga) t
               where not (t = any (w.acesso_desliga)) or t in ('cad-equipe', 'cad-funcoes')
               union select unnest(array['cad-equipe', 'cad-funcoes'])) end
  from workspaces w left join pacotes_acesso p on p.id = w.pacote_id
  where w.id = p_ws;
$$;
-- o módulo tem alguma tela liberada para o cliente?
create or replace function public.modulo_liberado(p_ws uuid, p_mod text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare t text[];
begin
  if p_mod in ('cfg', 'cad') then return true; end if;
  t := acesso_telas_ws(p_ws);
  if t is null then return true; end if;
  return exists (select 1 from acesso_telas a where a.tela = any (t) and a.modulo = p_mod);
end $$;

-- nivel_modulo passa a respeitar o pacote do cliente (antes de olhar papel e função)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.nivel_modulo(uuid,text)'::regprocedure);
  if position('modulo_liberado' in d) > 0 then return; end if;
  n := replace(d, 'if coalesce(auth.role(), '''') = ''service_role'' then return ''editar''; end if;',
    'if coalesce(auth.role(), '''') = ''service_role'' then return ''editar''; end if;' || chr(10) || '  if not modulo_liberado(ws, modulo) then return ''nenhum''; end if;');
  if n = d then raise exception 'nivel_modulo: trecho esperado não encontrado — revisar'; end if;
  execute n;
end $$;

-- para a tela do cliente: o que está liberado
create or replace function public.acesso_workspace(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare w workspaces; p pacotes_acesso;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  select * into w from workspaces where id = p_ws;
  select * into p from pacotes_acesso where id = w.pacote_id;
  return jsonb_build_object('pacote_id', w.pacote_id, 'pacote', p.nome, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga), 'telas', to_jsonb(acesso_telas_ws(p_ws)));
end $$;

-- equipe interna: salvar e excluir pacote
create or replace function public.pacote_salvar(p_id uuid, p_nome text, p_descricao text, p_telas text[], p_ativo boolean default true) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; ruins text[];
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna monta pacotes de acesso'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao pacote'; end if;
  select array_agg(t) into ruins from unnest(coalesce(p_telas, '{}')) t where not exists (select 1 from acesso_telas a where a.tela = t);
  if ruins is not null then raise exception 'Telas desconhecidas: %', array_to_string(ruins, ', '); end if;
  if p_id is null then
    insert into pacotes_acesso (nome, descricao, telas, ativo) values (trim(p_nome), p_descricao, coalesce(p_telas, '{}'), coalesce(p_ativo, true)) returning id into v;
  else
    update pacotes_acesso set nome = trim(p_nome), descricao = p_descricao, telas = coalesce(p_telas, '{}'), ativo = coalesce(p_ativo, true), atualizado_em = now() where id = p_id returning id into v;
    if v is null then raise exception 'Pacote não encontrado'; end if;
  end if;
  return v;
end $$;
create or replace function public.pacote_excluir(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna mexe nos pacotes de acesso'; end if;
  select count(*) into n from workspaces where pacote_id = p_id;
  if n > 0 then raise exception 'Este pacote está em % cliente(s). Troque o pacote deles antes de excluir.', n; end if;
  delete from pacotes_acesso where id = p_id;
end $$;

-- equipe interna: lista os clientes com o pacote e os ajustes de cada um
create or replace function public.clientes_acesso() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê os pacotes dos clientes'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'modo_produto', w.modo_produto, 'pacote_id', w.pacote_id, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga)) order by w.nome)
                   from workspaces w where not coalesce(w.agencia, false)), '[]'::jsonb);
end $$;
-- equipe interna: define o pacote e os ajustes de um cliente
create or replace function public.workspace_definir_acesso(p_ws uuid, p_pacote uuid, p_liga text[], p_desliga text[]) returns void
language plpgsql security definer set search_path = public as $$
declare ruins text[];
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna define o pacote de um cliente'; end if;
  if exists (select 1 from workspaces where id = p_ws and coalesce(agencia, false)) then raise exception 'O workspace da equipe interna não recebe pacote'; end if;
  if p_pacote is not null and not exists (select 1 from pacotes_acesso where id = p_pacote and ativo) then raise exception 'Pacote não encontrado ou inativo'; end if;
  select array_agg(t) into ruins from unnest(coalesce(p_liga, '{}') || coalesce(p_desliga, '{}')) t where not exists (select 1 from acesso_telas a where a.tela = t);
  if ruins is not null then raise exception 'Telas desconhecidas: %', array_to_string(ruins, ', '); end if;
  update workspaces set pacote_id = p_pacote, acesso_liga = coalesce(p_liga, '{}'), acesso_desliga = coalesce(p_desliga, '{}') where id = p_ws;
  if not found then raise exception 'Cliente não encontrado'; end if;
end $$;

revoke execute on function public.acesso_telas_ws(uuid), public.modulo_liberado(uuid, text), public.acesso_workspace(uuid), public.pacote_salvar(uuid, text, text, text[], boolean),
  public.pacote_excluir(uuid), public.clientes_acesso(), public.workspace_definir_acesso(uuid, uuid, text[], text[]) from public, anon;
grant execute on function public.acesso_workspace(uuid), public.pacote_salvar(uuid, text, text, text[], boolean), public.pacote_excluir(uuid), public.clientes_acesso(),
  public.workspace_definir_acesso(uuid, uuid, text[], text[]) to authenticated;
-- usadas dentro das políticas (via nivel_modulo): authenticated precisa poder executar
grant execute on function public.acesso_telas_ws(uuid), public.modulo_liberado(uuid, text) to authenticated, service_role;

-- pacotes iniciais (pontos de partida; a equipe interna ajusta na tela Configurações → Pacotes de acesso)
insert into pacotes_acesso (nome, descricao, telas) values
('Consultoria', 'Acesso completo a todos os módulos.', (select array_agg(tela order by ordem) from acesso_telas where tela not like 'st-%')),
('Mentoria', 'Marketing, vendas, retenção, growth e projetos. Sem o módulo financeiro.',
  (select array_agg(tela order by ordem) from acesso_telas where tela not like 'st-%' and modulo <> 'fin'
     and tela not in ('cad-planocontas', 'cad-regras', 'cad-impostos', 'cad-bancos', 'cad-formaspag', 'cad-fornecedores', 'cad-centros', 'cad-rateio'))),
('Disparo', 'Campanhas, mídia, leads e funil comercial para operação de disparos.',
  array['adm-painel', 'ia-perguntar', 'mkt-dash', 'mkt-midia', 'mkt-camp', 'mkt-trafego', 'crm-dash', 'crm-leads', 'crm-vendas', 'mkt-origem', 'gro-analise',
        'cfg-importar', 'cfg-integracoes', 'cad-equipe', 'cad-funcoes', 'cad-clientes', 'cad-produtos', 'cad-canais', 'cad-funis'])
on conflict (nome) do nothing;
