-- Persiste a quantidade de participantes retornada pela Evolution.
alter table public.atd_conversas
  add column if not exists grupo_membros integer;

alter table public.atd_conversas
  drop constraint if exists atd_conversas_grupo_membros_check;
alter table public.atd_conversas
  add constraint atd_conversas_grupo_membros_check
  check (grupo_membros is null or grupo_membros >= 0);

comment on column public.atd_conversas.grupo_membros is
  'Total de participantes do grupo informado pela Evolution.';
