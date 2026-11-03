-- Disparo agendado e sequencial de mensagens em grupos conectados pela Evolution.
create table public.atd_disparos_grupos (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 nome text not null check(length(trim(nome)) between 1 and 100),
 texto text not null default '' check(length(texto)<=4000),
 iniciar_em timestamptz not null,
 intervalo_segundos integer not null check(intervalo_segundos between 60 and 86400),
 status text not null default 'agendado' check(status in ('agendado','em_andamento','pausado','concluido','cancelado')),
 total integer not null default 0 check(total between 1 and 500),
 enviados integer not null default 0,
 falhas integer not null default 0,
 autor_id uuid references auth.users(id) on delete set null,
 autor_nome text not null,
 midia_path text, midia_nome text, midia_mime text,
 erro text,
 criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now(),
 unique(workspace_id,id),
 check(texto<>'' or midia_path is not null),
 check(midia_mime is null or midia_mime in ('image/jpeg','image/png','image/webp','video/mp4'))
);
create table public.atd_disparos_grupos_itens (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 campanha_id uuid not null,
 conversa_id uuid not null,
 canal_id uuid not null,
 posicao integer not null check(posicao between 0 and 499),
 enviar_em timestamptz not null,
 status text not null default 'agendado' check(status in ('agendado','processando','enviado','erro','incerto','cancelado')),
 autor_mensagem_id uuid references public.atd_mensagens(id) on delete set null,
 externo_id text, erro text,
 criado_em timestamptz not null default now(), iniciado_em timestamptz,
 enviado_em timestamptz, atualizado_em timestamptz not null default now(),
 unique(workspace_id,id), unique(campanha_id,posicao), unique(campanha_id,conversa_id),
 foreign key(workspace_id,campanha_id) references public.atd_disparos_grupos(workspace_id,id) on delete cascade,
 foreign key(workspace_id,conversa_id) references public.atd_conversas(workspace_id,id),
 foreign key(workspace_id,canal_id) references public.atd_canais(workspace_id,id)
);
create index atd_grupo_disparo_pendentes on public.atd_disparos_grupos_itens(enviar_em,campanha_id,posicao) where status='agendado';
alter table public.atd_disparos_grupos enable row level security;
alter table public.atd_disparos_grupos_itens enable row level security;
create policy atd_grupo_disparos_leitura on public.atd_disparos_grupos for select to authenticated
 using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
create policy atd_grupo_disparo_itens_leitura on public.atd_disparos_grupos_itens for select to authenticated
 using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_disparos_grupos from anon,authenticated;
revoke all on public.atd_disparos_grupos_itens from anon,authenticated;
grant select on public.atd_disparos_grupos to authenticated;
grant select on public.atd_disparos_grupos_itens to authenticated;
grant all on public.atd_disparos_grupos to service_role;
grant all on public.atd_disparos_grupos_itens to service_role;

-- Reserva só o próximo horário elegível de uma campanha por execução do worker.
-- Falha/incerto pausa a campanha e exige conferência antes de qualquer retomada manual.
create function public.atd_grupo_disparo_reservar(p_limite integer default 1)
returns setof public.atd_disparos_grupos_itens
language plpgsql security invoker set search_path=public as $$
declare item public.atd_disparos_grupos_itens; wid uuid;cid uuid;
begin
 update public.atd_disparos_grupos_itens set status='incerto',erro='Processamento interrompido; confira o WhatsApp antes de reenviar.',atualizado_em=now()
 where status='processando' and iniciado_em<now()-interval '10 minutes';
 -- Lock por campanha evita que execuções concorrentes quebrem o intervalo sequencial.
 select c.workspace_id,c.id into wid,cid from public.atd_disparos_grupos c
 where c.status in ('agendado','em_andamento') and exists(select 1 from public.atd_disparos_grupos_itens i where i.campanha_id=c.id and i.status='agendado' and i.enviar_em<=now())
 order by c.criado_em,c.id for update skip locked limit 1;
 if cid is null then return; end if;
 select i.* into item from public.atd_disparos_grupos_itens i
 join public.atd_disparos_grupos c on c.id=i.campanha_id and c.workspace_id=i.workspace_id
 where i.workspace_id=wid and i.campanha_id=cid and i.status='agendado' and i.enviar_em<=now() and c.status in ('agendado','em_andamento')
 and not exists(select 1 from public.atd_disparos_grupos_itens running where running.campanha_id=i.campanha_id and running.status='processando')
 order by i.enviar_em,i.posicao for update of i skip locked limit 1;
 if item.id is null then return; end if;
 update public.atd_disparos_grupos_itens set status='processando',iniciado_em=now(),atualizado_em=now()
 where id=item.id returning * into item;
 update public.atd_disparos_grupos set status='em_andamento',atualizado_em=now() where id=item.campanha_id and status='agendado';
 return next item;
end $$;
revoke all on function public.atd_grupo_disparo_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_grupo_disparo_reservar(integer) to service_role;

create or replace function public.atd_grupo_disparo_progresso() returns trigger
language plpgsql security definer set search_path=public as $$
declare cid uuid; ws uuid;
begin
 if new.status is not distinct from old.status then return new; end if;
 cid:=new.campanha_id;ws:=new.workspace_id;
 update public.atd_disparos_grupos c set
  enviados=(select count(*) from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status='enviado'),
  falhas=(select count(*) from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status in ('erro','incerto')),
  status=case when c.status in ('cancelado','pausado') then c.status
    when exists(select 1 from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status in ('erro','incerto')) then 'pausado'
    when not exists(select 1 from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status in ('agendado','processando','incerto','erro')) then 'concluido'
    when exists(select 1 from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status='processando') then 'em_andamento'
    else 'agendado' end,
  atualizado_em=now() where c.id=cid and c.workspace_id=ws;
 if exists(select 1 from public.atd_disparos_grupos_itens i where i.campanha_id=cid and i.status in ('erro','incerto')) then
  update public.atd_disparos_grupos set erro=(select erro from public.atd_disparos_grupos_itens where campanha_id=cid and erro is not null order by posicao limit 1) where id=cid and workspace_id=ws;
 end if;
 return new;
end $$;
create trigger atd_grupo_disparo_progresso_t after update of status on public.atd_disparos_grupos_itens
for each row execute function public.atd_grupo_disparo_progresso();
revoke all on function public.atd_grupo_disparo_progresso() from public,anon,authenticated;

-- O worker aproveita o cron e as credenciais que já processam os envios do Atendimento.
create or replace function public.atd_agenda_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
 if not exists(select 1 from public.atd_agendamentos where (status='agendado' and enviar_em<=now()) or (status='processando' and iniciado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_envios_transacionais where status='pendente' or (status='processando' and iniciado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_automacao_execucoes where (status='aguardando' and retomar_em<=now()) or (status='processando' and retomar_em is null and criado_em<now()-interval '10 minutes'))
 and not exists(select 1 from public.atd_disparos_grupos_itens where (status='agendado' and enviar_em<=now()) or (status='processando' and iniciado_em<now()-interval '10 minutes')) then return; end if;
 select valor into u from public.sistema_config where chave='atd_agenda_url';
 select valor into t from public.sistema_config where chave='atd_agenda_token';
 if coalesce(u,'')='' or coalesce(t,'')='' then raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token';return; end if;
 perform net.http_post(url:=u,body:='{"action":"processar-agendamentos"}'::jsonb,
  headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_agenda_acordar() from public,anon,authenticated;
