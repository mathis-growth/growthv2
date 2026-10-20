-- Base mínima e isolada para testar a v0.105 (RevOps → Retenção & Expansão). Roda num banco vazio; datas relativas a hoje.
-- Depois rode supabase/migrations/20261012100000_revops_retencao.sql e retencao_cenarios.sql.
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql as $$ select '00000000-0000-0000-0000-0000000000f1'::uuid $$;
do $$ begin create role authenticated; exception when others then null; end $$;
do $$ begin create role anon; exception when others then null; end $$;
do $$ begin create role service_role; exception when others then null; end $$;
create or replace function pertence_ao_workspace(uuid) returns boolean language sql as $$ select true $$;
create or replace function perm(uuid, text, text[]) returns boolean language sql as $$ select true $$;
create table workspaces (id uuid primary key, nome text);
create table pessoas (id uuid primary key, workspace_id uuid, nome text, email text, telefone text, canal_origem text, utm_source text, campanha_id uuid);
create table produtos (id uuid primary key, workspace_id uuid, nome text, nivel_escada int, extras jsonb default '{}');
create table campanhas (id uuid primary key, workspace_id uuid, nome text);
create table vendas (id uuid primary key default gen_random_uuid(), workspace_id uuid, pessoa_id uuid, produto_id uuid, campanha_id uuid, status text, data_venda timestamptz, aprovada_em timestamptz,
  reembolsada_em timestamptz, cancelada_em timestamptz, valor_bruto numeric, taxa_plataforma numeric, impostos numeric, valor_liquido numeric, pedido_ref text);
create table contratos (id uuid primary key, workspace_id uuid, pessoa_id uuid, campanha_id uuid, status text, data_inicio date, ativado_em timestamptz, criado_em timestamptz default now(), recorrente boolean);
create table contrato_itens (id uuid primary key default gen_random_uuid(), workspace_id uuid, contrato_id uuid, produto_id uuid, quantidade numeric, valor numeric);
create table contas_receber (id uuid primary key default gen_random_uuid(), workspace_id uuid, contrato_id uuid, venda_id uuid, valor numeric, desconto numeric, vencimento date, data_recebimento date, status text, substituida_por uuid);
create table acesso_telas (tela text primary key, modulo text not null, nome text not null, grupo text, ordem int not null default 0);
create table pacotes_acesso (id uuid primary key default gen_random_uuid(), nome text, telas text[]);
insert into acesso_telas values ('ho-ascensao', 'revops', 'Ascensão da escada', 'RevOps', 19), ('ho-cohort', 'revops', 'Cohorts', 'RevOps', 20);
insert into pacotes_acesso (nome, telas) values ('Completo', array['ho-dash', 'ho-cohort', 'ho-ascensao']), ('Sem RevOps', array['fin-dash']);

insert into workspaces values ('00000000-0000-0000-0000-0000000000a1', 'W'), ('00000000-0000-0000-0000-0000000000a2', 'Outro');
insert into produtos values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Curso', 1, '{"mc_custo_pct": 10}'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 'Livro', 2, '{}'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a1', 'Bump', null, '{}'),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000a1', 'Mentoria', 3, '{"mc_custo_cliente": 100}');
insert into campanhas values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Lançamento');
insert into pessoas values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'Ana', 'ana@x', null, 'meta_ads', 'facebook', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000a1', 'Bia', 'bia@x', null, 'meta_ads', 'facebook', null),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000a1', 'Caio', 'caio@x', null, 'google_ads', 'google', null),
  ('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-0000000000a1', 'Davi', 'davi@x', null, '', null, null),
  ('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-0000000000a1', 'Eva', 'eva@x', null, '', null, null),
  ('00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000a1', 'Fábio', 'fabio@x', null, 'google_ads', 'google', null),
  ('00000000-0000-0000-0000-000000000099', '00000000-0000-0000-0000-0000000000a2', 'Outro ws', 'o@x', null, '', null, null);
-- datas ao meio-dia de São Paulo, relativas a hoje
create or replace function t(dias int) returns timestamptz language sql as $$ select (((now() at time zone 'America/Sao_Paulo')::date - dias)::timestamp + interval '12 hours') at time zone 'America/Sao_Paulo' $$;
create or replace function d(dias int) returns date language sql as $$ select (now() at time zone 'America/Sao_Paulo')::date - dias $$;
-- Ana: Curso, depois Livro em 30 dias, depois Livro de novo
insert into vendas (workspace_id, pessoa_id, produto_id, campanha_id, status, data_venda, valor_bruto, valor_liquido) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', 'aprovada', t(400), 1100, 1000),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b2', null, 'aprovada', t(370), 550, 500),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b2', null, 'aprovada', t(100), 550, 500),
-- Bia: Curso + Bump no mesmo dia (um pedido só)
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b1', null, 'aprovada', t(395), 1100, 1000),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000b3', null, 'aprovada', t(395) + interval '5 minutes', 220, 200),
-- Caio: a primeira foi reembolsada; a coorte começa na segunda
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000b1', null, 'reembolsada', t(390), 1100, 1000),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-0000000000b1', null, 'aprovada', t(380), 1100, 1000),
-- Davi: além do contrato, compra o Curso
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-0000000000b1', null, 'aprovada', t(60), 1100, 1000),
-- Fábio: compra recente (coorte incompleta)
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000f', '00000000-0000-0000-0000-0000000000b1', null, 'aprovada', t(10), 1100, 1000),
-- outro workspace (não pode aparecer)
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000099', null, null, 'aprovada', t(10), 9999, 9999);
-- Davi: mentoria recorrente; cada parcela até hoje é receita do mesmo pedido (a 1ª compra), não recompra
insert into contratos values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000d', null, 'ativo', d(200), null, now(), true),
-- Eva: contrato cancelado sem nada recebido (não é compra)
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000e', null, 'cancelado', d(50), null, now(), false);
insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000b4', 1, 1000),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000b4', 1, 1000);
insert into contas_receber (workspace_id, contrato_id, valor, vencimento, data_recebimento, status)
select '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d1', 1000, d(x), case when x > 30 then d(x) end, case when x > 30 then 'recebido' else 'aberto' end
  from unnest(array[200, 170, 140, 110, 80, 50, 20, -10]) x;
insert into contas_receber (workspace_id, contrato_id, valor, vencimento, status) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000d2', 1000, d(50), 'cancelado');
