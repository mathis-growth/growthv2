-- Registra quando cada chip Evolution foi consultado para descobrir grupos novos.
alter table public.atd_canais
  add column if not exists grupos_sincronizados_em timestamptz;

alter table public.atd_conversas
  add column if not exists grupo_tipo text not null default 'grupo',
  add column if not exists grupo_pai_externo_id text;
alter table public.atd_conversas
  drop constraint if exists atd_conversas_grupo_tipo_check;
alter table public.atd_conversas
  add constraint atd_conversas_grupo_tipo_check
  check (grupo_tipo in ('grupo','comunidade','avisos_comunidade'));
create index if not exists atd_conversas_comunidade_pai_idx
  on public.atd_conversas(workspace_id,canal_id,grupo_pai_externo_id)
  where grupo_pai_externo_id is not null;

comment on column public.atd_canais.grupos_sincronizados_em is
  'Instante da última tentativa de consulta para descobrir grupos Evolution novos; rotina periódica espera seis horas entre tentativas por chip.';

-- A rotina usa o mesmo endpoint e token privado do worker de Atendimento.
create or replace function public.atd_grupos_acordar()
returns void
language plpgsql
security definer
set search_path=public
as $$
declare endpoint text; token text; chamada bigint;
begin
  if not exists (
    select 1 from public.atd_canais
    where provedor='evolution' and canal='whatsapp' and ativo and status='conectado'
      and (grupos_sincronizados_em is null or grupos_sincronizados_em<=now()-interval '6 hours')
  ) then return; end if;

  select valor into endpoint from public.sistema_config where chave='atd_agenda_url';
  select valor into token from public.sistema_config where chave='atd_agenda_token';
  if coalesce(endpoint,'')='' or coalesce(token,'')='' then
    raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token para buscar grupos periodicamente';
    return;
  end if;

  select net.http_post(
    url:=endpoint,
    body:='{"action":"processar-grupos-periodico"}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',token),
    timeout_milliseconds:=90000
  ) into chamada;
end $$;
revoke all on function public.atd_grupos_acordar() from public,anon,authenticated;

do $$
begin
  if not exists(select 1 from cron.job where jobname='atendimento-grupos-periodicos') then
    perform cron.schedule('atendimento-grupos-periodicos','*/15 * * * *',
      'select public.atd_grupos_acordar()');
  end if;
end $$;
