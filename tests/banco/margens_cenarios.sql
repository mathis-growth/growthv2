-- v0.94: chaves de margem no Planejamento e valor_indicador. Banco mínimo isolado (roda num banco vazio).
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql as $$ select null::uuid $$;
create table if not exists workspaces (id uuid primary key);
create or replace function pertence_ao_workspace(uuid) returns boolean language sql as $$ select true $$;
create table if not exists planos (id uuid primary key, workspace_id uuid);
create table if not exists plano_indicadores (id uuid primary key default gen_random_uuid(), workspace_id uuid, plano_id uuid, nome text, chave text, unidade text, sentido text, valor_meta numeric,
  constraint plano_indicadores_chave_check check (chave = any (array['receita','mrr','leads','clientes','conversao','investimento','cac','ticket_medio'])));
create table if not exists dre (workspace_id uuid, mes date, tipo text, valor numeric);
create or replace view v_dre_mensal as select * from dre;
create table if not exists pessoas (workspace_id uuid, criado_em timestamptz, convertido_em timestamptz);
create table if not exists trafego (workspace_id uuid, data date, custo numeric);
create or replace view v_trafego_anuncio_dia as select * from trafego;
create table if not exists contratos (id uuid, workspace_id uuid, status text, recorrente boolean, periodicidade text, data_inicio date, data_fim date);
create table if not exists contrato_itens (contrato_id uuid, quantidade numeric, valor numeric);
insert into workspaces values ('00000000-0000-0000-0000-000000000001') on conflict do nothing;
insert into plano_indicadores (workspace_id, nome, chave, unidade, sentido, valor_meta) values ('00000000-0000-0000-0000-000000000001', 'Margem de lucro líquida', null, 'pct', 'aumentar', 30);
insert into dre values ('00000000-0000-0000-0000-000000000001', '2026-11-01', 'receita', 10000), ('00000000-0000-0000-0000-000000000001', '2026-11-01', 'deducao', 600),
  ('00000000-0000-0000-0000-000000000001', '2026-11-01', 'custo', 1400), ('00000000-0000-0000-0000-000000000001', '2026-11-01', 'despesa', 5000);
\i supabase/migrations/20261011500000_margens_indicadores.sql
\i supabase/migrations/20261011500000_margens_indicadores.sql
do $$ declare mc numeric; ml numeric; ws uuid := '00000000-0000-0000-0000-000000000001'; begin
  if (select chave from plano_indicadores where nome = 'Margem de lucro líquida') <> 'margem_lucro' then raise exception 'chave não migrou'; end if;
  mc := valor_indicador(ws, 'margem_contribuicao', '2026-11-01', '2026-11-30'); ml := valor_indicador(ws, 'margem_lucro', '2026-11-01', '2026-11-30');
  if mc <> 80 or ml <> 30 then raise exception 'margens erradas: % %', mc, ml; end if;
  if valor_indicador(ws, 'margem_lucro', '2027-01-01', '2027-01-31') is not null then raise exception 'sem receita deveria ser nulo'; end if;
  if valor_indicador(ws, 'receita', '2026-11-01', '2026-11-30') <> 10000 then raise exception 'receita mudou'; end if;
  raise notice 'v0.94: margens no Planejamento OK';
end $$;
\i supabase/migrations/20261011600000_cenarios_indicadores.sql
\i supabase/migrations/20261011600000_cenarios_indicadores.sql
do $$ begin
  update plano_indicadores set faixa_ruim = 20, faixa_otimo = 40 where chave = 'margem_lucro';
  if (select faixa_otimo from plano_indicadores where chave = 'margem_lucro') <> 40 then raise exception 'faixa não gravou'; end if;
  raise notice 'v0.95: cenários ruim/ótimo OK';
end $$;
