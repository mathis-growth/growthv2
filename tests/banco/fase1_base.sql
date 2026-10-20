-- Base para testar 20261011000000_fase1_confianca_dado.sql (depois de casa_base.sql e das migrações v0.86/v0.87).
create or replace function auth.role() returns text language sql as $$ select nullif(current_setting('test.role', true), '') $$;
create or replace function eh_admin(ws uuid) returns boolean language sql as $$ select true $$;
create or replace function perm(ws uuid, req text, mods text[]) returns boolean language sql as $$ select true $$;
create table pessoas (id uuid primary key default gen_random_uuid(), workspace_id uuid not null, nome text, email text, telefone text, status_funil text default 'lead',
  status_cliente text, utm_source text, utm_medium text, utm_campaign text, utm_content text, utm_term text, pagina_origem text, campanha_id uuid, canal_origem text,
  referrer text, gclid text, fbclid text, tags text[] default '{}', convertido_em timestamptz, criado_em timestamptz default now());
create unique index pessoas_email_uq on pessoas (workspace_id, lower(email)) where email is not null;
create table pessoa_lista (workspace_id uuid, pessoa_id uuid references pessoas(id) on delete cascade, lista_id uuid, ativo boolean default true, primary key (workspace_id, pessoa_id, lista_id));
create table pessoa_notas (id uuid primary key default gen_random_uuid(), workspace_id uuid, pessoa_id uuid references pessoas(id) on delete cascade, texto text);
create table vendas (id uuid primary key default gen_random_uuid(), workspace_id uuid, pessoa_id uuid references pessoas(id), produto_id uuid, plataforma_id uuid, campanha_id uuid,
  status text default 'aprovada', data_venda timestamptz default now(), valor_bruto numeric, valor_a_receber numeric, id_externo text, utm_source text, canal_fechamento text);
create table estornos (id uuid primary key default gen_random_uuid(), workspace_id uuid, venda_id uuid, tipo text, valor numeric, data date);
alter table contas_receber add constraint cr_venda_fk foreign key (venda_id) references vendas(id);
create table metricas_anuncio_dia (id uuid primary key default gen_random_uuid(), workspace_id uuid, anuncio_id uuid, data date, impressoes int, cliques int, custo numeric);
create table video_metricas_dia (id uuid primary key default gen_random_uuid(), workspace_id uuid, fonte_id uuid, data date);
create table campanha_etapa_valores (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_etapa_id uuid, data date, valor numeric);
create table conteudo_conta_dia (id uuid primary key default gen_random_uuid(), workspace_id uuid, canal text, data date);
create table integracoes (id uuid primary key default gen_random_uuid(), workspace_id uuid, provedor text, status text, ultima_sincronizacao timestamptz);
alter table campanhas add column status text, add column modelo text;
create table campanha_fechamentos (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, fechado_em timestamptz default now(), fechado_por uuid,
  periodo_ini date, periodo_fim date, snapshot jsonb);
create table acesso_telas (tela text primary key, modulo text, nome text, grupo text, ordem int);
