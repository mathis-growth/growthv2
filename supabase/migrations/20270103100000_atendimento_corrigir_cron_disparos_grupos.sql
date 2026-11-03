-- Corrige a coluna usada pelo cron ao verificar execuções de automações travadas.
-- O erro na referência a criado_em impedia o cron de acordar também a fila de grupos.
create or replace function public.atd_agenda_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
 if not exists(select 1 from public.atd_agendamentos where (status='agendado' and enviar_em<=now()) or (status='processando' and iniciado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_envios_transacionais where status='pendente' or (status='processando' and iniciado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_automacao_execucoes where (status='aguardando' and retomar_em<=now()) or (status='processando' and retomar_em is null and executado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_disparos_grupos_itens where (status='agendado' and enviar_em<=now()) or (status='processando' and iniciado_em<now()-interval '10 minutes')) then return; end if;
 select valor into u from public.sistema_config where chave='atd_agenda_url';
 select valor into t from public.sistema_config where chave='atd_agenda_token';
 if coalesce(u,'')='' or coalesce(t,'')='' then raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token';return; end if;
 perform net.http_post(url:=u,body:='{"action":"processar-agendamentos"}'::jsonb,
  headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_agenda_acordar() from public,anon,authenticated;
