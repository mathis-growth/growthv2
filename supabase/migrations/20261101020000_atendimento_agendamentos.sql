-- Agendamento de mensagens de texto do Atendimento: fuso definido pelo usuário,
-- armazenado em timestamptz UTC e processado em fila com reserva atômica.
create table public.atd_agendamentos (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id),
 conversa_id uuid not null,
 texto text not null check (length(trim(texto)) between 1 and 4000),
 enviar_em timestamptz not null,
 fuso text not null default 'America/Sao_Paulo',
 status text not null default 'agendado'
   check (status in ('agendado','processando','enviado','erro','incerto','cancelado')),
 autor_id uuid references auth.users(id) on delete set null,
 autor_nome text not null,
 mensagem_id uuid references public.atd_mensagens(id) on delete set null,
 externo_id text, erro text,
 tentativas integer not null default 0,
 criado_em timestamptz not null default now(),
 iniciado_em timestamptz, enviado_em timestamptz, atualizado_em timestamptz not null default now(),
 unique(workspace_id,id),
 foreign key(workspace_id,conversa_id) references public.atd_conversas(workspace_id,id)
);
create index atd_agenda_pendentes on public.atd_agendamentos(enviar_em,id) where status='agendado';
create index atd_agenda_conversa on public.atd_agendamentos(conversa_id,criado_em desc);
alter table public.atd_agendamentos enable row level security;
create policy atd_agenda_leitura on public.atd_agendamentos for select to authenticated
 using (public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_agendamentos from anon,authenticated;
grant select on public.atd_agendamentos to authenticated;
grant all on public.atd_agendamentos to service_role;

-- A chamada só pode ser feita pelo serviço. SKIP LOCKED impede dois workers
-- de reservar a mesma mensagem. Itens órfãos ficam incertos, sem reenvio cego.
create function public.atd_agenda_reservar(p_limite integer default 20)
returns setof public.atd_agendamentos
language plpgsql security invoker set search_path=public as $$
begin
 update public.atd_agendamentos set status='incerto',atualizado_em=now(),
   erro='Processamento interrompido; confira o provedor antes de qualquer novo envio.'
 where status='processando' and iniciado_em < now()-interval '10 minutes';
 return query
 with candidatos as (
   select id from public.atd_agendamentos
   where status='agendado' and enviar_em <= now()
   order by enviar_em,id for update skip locked limit least(greatest(p_limite,1),50)
 )
 update public.atd_agendamentos a set status='processando',iniciado_em=now(),
   atualizado_em=now(),tentativas=tentativas+1
 from candidatos c where a.id=c.id returning a.*;
end $$;
revoke all on function public.atd_agenda_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_agenda_reservar(integer) to service_role;

-- Usa a mesma infraestrutura pg_cron + pg_net já empregada no projeto.
-- Configurar as duas chaves em sistema_config antes de ativar os envios.
create extension if not exists pg_cron;
create extension if not exists pg_net;
insert into public.sistema_config(chave,valor) values
 ('atd_agenda_url',''),
 ('atd_agenda_token',replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''))
on conflict(chave) do nothing;

create function public.atd_agenda_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
 if not exists(select 1 from public.atd_agendamentos
   where (status='agendado' and enviar_em<=now())
      or (status='processando' and iniciado_em<now()-interval '10 minutes')) then return; end if;
 select valor into u from public.sistema_config where chave='atd_agenda_url';
 select valor into t from public.sistema_config where chave='atd_agenda_token';
 if coalesce(u,'')='' or coalesce(t,'')='' then
   raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token';return;
 end if;
 perform net.http_post(url:=u,body:='{"action":"processar-agendamentos"}'::jsonb,
   headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),
   timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_agenda_acordar() from public,anon,authenticated;
select cron.schedule('atendimento-envios-agendados','* * * * *',
  'select public.atd_agenda_acordar()');
