-- Canvas visual e execução persistente de fluxos da Central de Atendimento.
-- Compatível com automações já existentes: fluxo vazio mantém a resposta simples.
alter table public.atd_automacoes
  add column if not exists fluxo jsonb not null default '{"nodes":[],"edges":[]}'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='atd_automacoes_fluxo_ck' and conrelid='public.atd_automacoes'::regclass) then
    alter table public.atd_automacoes add constraint atd_automacoes_fluxo_ck
      check (jsonb_typeof(fluxo)='object' and jsonb_typeof(coalesce(fluxo->'nodes','[]'::jsonb))='array' and jsonb_typeof(coalesce(fluxo->'edges','[]'::jsonb))='array');
  end if;
end $$;

alter table public.atd_automacao_execucoes
  add column if not exists estado jsonb not null default '{}'::jsonb,
  add column if not exists retomar_em timestamptz;

alter table public.atd_automacao_execucoes drop constraint if exists atd_automacao_execucoes_status_check;
alter table public.atd_automacao_execucoes add constraint atd_automacao_execucoes_status_check
  check (status in ('processando','aguardando','enviado','erro','incerto'));
create index if not exists atd_automacao_execucoes_agendadas
  on public.atd_automacao_execucoes(retomar_em) where status='aguardando';
