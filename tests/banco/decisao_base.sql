-- Complemento do gm_base.sql + v0.98 para testar a v0.99 (decisão e Kanban).
create table if not exists auth.users (id uuid primary key, email text);
create table projetos (id uuid primary key default gen_random_uuid(), workspace_id uuid not null, nome text not null, descricao text, data_inicio date, data_fim_prevista date, status text not null default 'planejado');
create table growth_experimentos (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null, metrica_id uuid, titulo text not null, hipotese text, criterio_sucesso text, responsavel text,
  etapa text not null default 'ideia' check (etapa in ('ideia','priorizado','rodando','analise','concluido')),
  impacto int, confianca int, facilidade int, score numeric(4,1) generated always as (round((impacto + confianca + facilidade) / 3.0, 1)) stored,
  inicio date, fim_previsto date, insight text, criado_em timestamptz default now());
insert into growth_experimentos (workspace_id, titulo, etapa) values ('00000000-0000-0000-0000-0000000000a1', 'Antigo', 'rodando');
