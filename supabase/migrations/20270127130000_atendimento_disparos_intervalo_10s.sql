-- Permite intervalo de 10 segundos e acorda a fila de grupos nessa frequência.
alter table public.atd_disparos_grupos
  drop constraint if exists atd_disparos_grupos_intervalo_segundos_check;
alter table public.atd_disparos_grupos
  add constraint atd_disparos_grupos_intervalo_segundos_check
  check (intervalo_segundos between 10 and 86400);

-- O próximo envio só pode começar após o intervalo contado do envio confirmado.
-- Mantém o lock por campanha e a reserva de um destinatário por execução.
create or replace function public.atd_grupo_disparo_reservar(p_limite integer default 1)
returns setof public.atd_disparos_grupos_itens
language plpgsql security invoker set search_path=public as $$
declare item public.atd_disparos_grupos_itens; wid uuid; cid uuid;
begin
 update public.atd_disparos_grupos_itens set status='incerto',erro='Processamento interrompido; confira o WhatsApp antes de reenviar.',atualizado_em=now()
 where status='processando' and iniciado_em<now()-interval '10 minutes';
 select c.workspace_id,c.id into wid,cid from public.atd_disparos_grupos c
 where c.status in ('agendado','em_andamento')
   and exists (select 1 from public.atd_disparos_grupos_itens i
     where i.campanha_id=c.id and i.status='agendado' and i.enviar_em<=now())
   and not exists (select 1 from public.atd_disparos_grupos_itens enviado
     where enviado.campanha_id=c.id and enviado.status='enviado'
       and enviado.enviado_em>now()-make_interval(secs=>c.intervalo_segundos))
 order by c.criado_em,c.id for update skip locked limit 1;
 if cid is null then return; end if;
 select i.* into item from public.atd_disparos_grupos_itens i
 join public.atd_disparos_grupos c on c.id=i.campanha_id and c.workspace_id=i.workspace_id
 where i.workspace_id=wid and i.campanha_id=cid and i.status='agendado' and i.enviar_em<=now()
   and c.status in ('agendado','em_andamento')
   and not exists (select 1 from public.atd_disparos_grupos_itens running
     where running.campanha_id=i.campanha_id and running.status='processando')
 order by i.enviar_em,i.posicao for update of i skip locked limit 1;
 if item.id is null then return; end if;
 update public.atd_disparos_grupos_itens set status='processando',iniciado_em=now(),atualizado_em=now()
 where id=item.id returning * into item;
 update public.atd_disparos_grupos set status='em_andamento',atualizado_em=now()
 where id=item.campanha_id and status='agendado';
 return next item;
end $$;
revoke all on function public.atd_grupo_disparo_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_grupo_disparo_reservar(integer) to service_role;

create or replace function public.atd_grupos_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
 if not exists (select 1 from public.atd_disparos_grupos_itens
   where status='agendado' and enviar_em<=now()) then return; end if;
 select valor into u from public.sistema_config where chave='atd_agenda_url';
 select valor into t from public.sistema_config where chave='atd_agenda_token';
 if coalesce(u,'')='' or coalesce(t,'')='' then
   raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token';
   return;
 end if;
 perform net.http_post(url:=u,body:='{"action":"processar-grupos-disparo"}'::jsonb,
   headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_grupos_acordar() from public,anon,authenticated;

-- pg_cron aceita intervalos em segundos nas versões atuais do Supabase.
select cron.schedule('atendimento-disparos-grupos-10s','10 seconds',
  'select public.atd_grupos_acordar()');
