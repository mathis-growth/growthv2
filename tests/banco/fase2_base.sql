-- Base para testar 20261011100000_fase2_captacao_vendas.sql (depois de fase1_base.sql e da migração v0.88).
alter table pessoas add column qualificacao text;
alter table vendas add column utm_medium text, add column utm_campaign text, add column utm_content text;
create table canais (id uuid primary key default gen_random_uuid(), workspace_id uuid, codigo text, nome text, utm_source text, utm_medium text, ativo boolean default true);
create table campanha_canais (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, canal text, utm_campaign text, orcamento numeric, unique (workspace_id, utm_campaign));
create table anuncios (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_canal_id uuid, nome text, utm_content text);
alter table metricas_anuncio_dia add constraint mad_anuncio_fk foreign key (anuncio_id) references anuncios(id);
create table alunos (id uuid primary key default gen_random_uuid(), workspace_id uuid, pessoa_id uuid references pessoas(id), entrou_em timestamptz, saiu_em timestamptz, status text default 'ativo');
create table produtos (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text);
create table campanha_ofertas (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, produto_id uuid, nome text, papel text, preco numeric, ordem int default 0, criado_em timestamptz default now());
create table contratos (id uuid primary key default gen_random_uuid(), workspace_id uuid, campanha_id uuid, status text, pessoa_id uuid);
create table contrato_itens (id uuid primary key default gen_random_uuid(), contrato_id uuid, produto_id uuid, quantidade int, valor numeric);
create table pessoa_toques (id uuid primary key default gen_random_uuid(), workspace_id uuid, pessoa_id uuid references pessoas(id) on delete cascade, em timestamptz, tipo text, canal text,
  campanha_id uuid, chave text, descricao text, utm_source text, utm_medium text, utm_campaign text, utm_content text, origem text, ref_tabela text, ref_id uuid,
  constraint pessoa_toques_ref unique (pessoa_id, ref_tabela, ref_id, tipo),
  check (origem = any (array['sistema', 'sendflow', 'manual', 'importacao'])),
  check (tipo = any (array['entrada', 'etapa', 'lista', 'video', 'disparo', 'comercial', 'compra', 'recompra', 'outro'])));
create or replace function public.toque_registrar(p_ws uuid, p_pessoa uuid, p_em timestamptz, p_tipo text, p_canal text, p_campanha uuid, p_descricao text, p_us text, p_um text, p_uc text, p_ux text, p_ref_tabela text, p_ref_id uuid)
 returns void language plpgsql security definer set search_path to 'public' as $function$
begin
  insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
  values (p_ws, p_pessoa, coalesce(p_em, now()), p_tipo, nullif(p_canal, ''), p_campanha, p_descricao, p_us, p_um, p_uc, p_ux, 'sistema', p_ref_tabela, p_ref_id)
  on conflict on constraint pessoa_toques_ref do nothing;
end $function$;
create or replace function public.toque_trg_pessoa() returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  perform toque_registrar(new.workspace_id, new.id, new.criado_em, 'entrada', coalesce(new.canal_origem, new.utm_source), new.campanha_id, 'Entrou como lead', new.utm_source, new.utm_medium, new.utm_campaign, new.utm_content, 'pessoas', new.id);
  return null;
end $function$;
create trigger toque_pessoa_t after insert on pessoas for each row execute function toque_trg_pessoa();
