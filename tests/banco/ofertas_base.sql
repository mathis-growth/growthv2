-- Base mínima e isolada para testar a v0.97 (ofertas, esteira, campanha híbrida, NSM). Roda num banco vazio.
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql as $$ select null::uuid $$;
do $$ begin create role authenticated; exception when others then null; end $$;
do $$ begin create role anon; exception when others then null; end $$;
do $$ begin create role service_role; exception when others then null; end $$;
create table workspaces (id uuid primary key default gen_random_uuid(), nome text);
create or replace function pertence_ao_workspace(uuid) returns boolean language sql as $$ select true $$;
create or replace function perm(uuid, text, text[]) returns boolean language sql as $$ select true $$;
create table produtos (id uuid primary key default gen_random_uuid(), workspace_id uuid references workspaces(id), nome text);
create table funis (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text);
create table canais (id uuid primary key default gen_random_uuid(), workspace_id uuid, codigo text, nome text, utm_source text, utm_medium text, ativo boolean default true);
create table campanhas (id uuid primary key default gen_random_uuid(), workspace_id uuid references workspaces(id), nome text, funil_id uuid references funis(id));
create table campanha_canais (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid references campanhas(id) on delete cascade, canal text, orcamento numeric);
create table ofertas (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  produto_id uuid not null references produtos(id) on delete cascade, nome text not null,
  papel text not null default 'principal' check (papel in ('principal', 'upsell', 'order_bump', 'cross_sell', 'downsell')),
  preco numeric(12,2) not null check (preco >= 0), ativo boolean not null default true, criado_em timestamptz not null default now());
create table campanha_ofertas (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade, produto_id uuid not null references produtos(id) on delete restrict,
  oferta_id uuid references ofertas(id) on delete set null, nome text not null,
  papel text not null default 'principal' check (papel in ('principal', 'upsell', 'order_bump', 'cross_sell', 'downsell')),
  preco numeric(12,2) not null check (preco >= 0), ordem int not null default 0, criado_em timestamptz not null default now());
create table vendas (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, produto_id uuid, status text, valor_bruto numeric);
create table contratos (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, status text);
create table contrato_itens (id uuid primary key default gen_random_uuid(), contrato_id uuid, produto_id uuid, quantidade numeric, valor numeric);
create table growth_metricas (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, tipo text);
insert into workspaces (id, nome) values ('00000000-0000-0000-0000-0000000000a1', 'W');
insert into produtos (id, workspace_id, nome) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Curso'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 'Mentoria'), ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000a1', 'E-book');
insert into funis (id, workspace_id, nome) values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Lançamento');
insert into canais (workspace_id, codigo, nome, utm_medium) values ('00000000-0000-0000-0000-0000000000a1', 'meta_ads', 'Meta Ads', 'paid'), ('00000000-0000-0000-0000-0000000000a1', 'instagram', 'Instagram', null), ('00000000-0000-0000-0000-0000000000a1', 'google', 'Google', 'cpc');
insert into campanhas (id, workspace_id, nome, funil_id) values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Black', '00000000-0000-0000-0000-0000000000f1');
insert into campanha_canais (workspace_id, campanha_id, canal) values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'meta_ads'), ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'instagram');
insert into ofertas (id, workspace_id, produto_id, nome, preco, ativo) values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'Curso à vista', 997, true),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b3', 'E-book bump', 47, false);
