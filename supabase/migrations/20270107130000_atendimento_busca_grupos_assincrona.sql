-- Guarda o estado e a contagem da consulta enquanto a Evolution lista grupos.
alter table public.atd_canais
  add column if not exists grupos_busca_estado text not null default 'ociosa'
    check (grupos_busca_estado in ('ociosa','em_andamento','concluida','falhou')),
  add column if not exists grupos_busca_resultado jsonb not null default '{}'::jsonb,
  add column if not exists grupos_busca_atualizada_em timestamptz;

comment on column public.atd_canais.grupos_busca_estado is
  'Estado da consulta assíncrona para descobrir grupos novos da Evolution.';
