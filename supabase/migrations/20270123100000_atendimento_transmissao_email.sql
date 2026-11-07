-- Transmissao de e-mail agendada com fila duravel e log individual por contato.
create table if not exists public.atd_email_campanhas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 160),
  inicio_em timestamptz not null,
  fuso text not null default 'America/Sao_Paulo',
  intervalo_segundos integer not null default 10 check (intervalo_segundos between 1 and 3600),
  filtros jsonb not null default '{}'::jsonb check (jsonb_typeof(filtros)='object'),
  status text not null default 'agendada' check (status in ('agendada','em_execucao','concluida','cancelada')),
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(workspace_id,id)
);

create table if not exists public.atd_email_config (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  dominio text not null,
  resend_domain_id text not null unique,
  email_remetente text not null,
  status_dominio text not null default 'not_started',
  atualizado_em timestamptz not null default now(),
  unique(dominio)
);

create table if not exists public.atd_email_envios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  campanha_id uuid not null,
  pessoa_id uuid not null,
  etapa integer not null check (etapa between 1 and 10),
  enviar_em timestamptz not null,
  email text not null,
  assunto text not null check (length(trim(assunto)) between 1 and 180),
  corpo_html text not null check (length(corpo_html) between 1 and 100000),
  atraso_minutos integer not null default 0 check (atraso_minutos between 0 and 525600),
  condicao jsonb not null default '{}'::jsonb check (jsonb_typeof(condicao)='object'),
  status text not null default 'pendente' check (status in ('pendente','processando','enviado','ignorado','erro','incerto','cancelado')),
  externo_id text,
  erro text,
  tentativas integer not null default 0,
  criado_em timestamptz not null default now(),
  iniciado_em timestamptz,
  enviado_em timestamptz,
  atualizado_em timestamptz not null default now(),
  unique(workspace_id,campanha_id,pessoa_id,etapa),
  foreign key(workspace_id,campanha_id) references public.atd_email_campanhas(workspace_id,id) on delete cascade,
  foreign key(pessoa_id) references public.pessoas(id) on delete cascade
);
create index if not exists atd_email_pendentes on public.atd_email_envios(enviar_em,id) where status='pendente';
create index if not exists atd_email_pessoa on public.atd_email_envios(pessoa_id,criado_em desc);
create index if not exists atd_email_campanha on public.atd_email_envios(campanha_id,status,enviar_em);
alter table public.atd_email_campanhas enable row level security;
alter table public.atd_email_envios enable row level security;
alter table public.atd_email_config enable row level security;
drop policy if exists atd_email_config_leitura on public.atd_email_config;
create policy atd_email_config_leitura on public.atd_email_config for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
drop policy if exists atd_email_campanha_leitura on public.atd_email_campanhas;
create policy atd_email_campanha_leitura on public.atd_email_campanhas for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
drop policy if exists atd_email_envio_leitura on public.atd_email_envios;
create policy atd_email_envio_leitura on public.atd_email_envios for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_email_campanhas,public.atd_email_envios,public.atd_email_config from anon,authenticated;
grant select on public.atd_email_campanhas,public.atd_email_envios to authenticated;
grant all on public.atd_email_campanhas,public.atd_email_envios,public.atd_email_config to service_role;

create or replace function public.atd_email_historico()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare rotulo text;
begin
  if tg_op='INSERT' then rotulo:='Na fila';
  elsif old.status is distinct from new.status and new.status in ('enviado','ignorado','erro','incerto') then
    rotulo:=case new.status when 'enviado' then 'Enviado' when 'ignorado' then 'Ignorado por condição' when 'erro' then 'Falha no envio' else 'Envio sem confirmação' end;
  else return new; end if;
  insert into public.pessoa_historico(workspace_id,pessoa_id,campo,valor_anterior,valor_novo)
  values(new.workspace_id,new.pessoa_id,'Transmissão de e-mail · etapa '||new.etapa,
    case when tg_op='UPDATE' then old.status else null end,
    rotulo||' · '||new.assunto||coalesce(' · '||nullif(new.erro,''),''));
  return new;
end $$;
drop trigger if exists atd_email_historico_t on public.atd_email_envios;
create trigger atd_email_historico_t after insert or update of status on public.atd_email_envios
for each row execute function public.atd_email_historico();
revoke all on function public.atd_email_historico() from public,anon,authenticated;

create or replace function public.atd_email_reservar(p_limite integer default 10)
returns setof public.atd_email_envios language plpgsql security invoker set search_path=public as $$
begin
  update public.atd_email_envios set status='incerto',atualizado_em=now(),erro='Processamento interrompido; confira o provedor antes de reenviar.'
    where status='processando' and iniciado_em<now()-interval '10 minutes';
  return query with candidatos as (
    select id from public.atd_email_envios where status='pendente' and enviar_em<=now()
    order by enviar_em,id for update skip locked limit least(greatest(p_limite,1),20)
  ) update public.atd_email_envios e set status='processando',iniciado_em=now(),atualizado_em=now(),tentativas=tentativas+1
    from candidatos c where e.id=c.id returning e.*;
end $$;
revoke all on function public.atd_email_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_email_reservar(integer) to service_role;

-- Reutiliza URL e token privados do worker de Atendimento, sem expor segredo no cliente.
create or replace function public.atd_email_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
  if not exists(select 1 from public.atd_email_envios where (status='pendente' and enviar_em<=now()) or (status='processando' and iniciado_em<now()-interval '10 minutes')) then return; end if;
  select valor into u from public.sistema_config where chave='atd_agenda_url';
  select valor into t from public.sistema_config where chave='atd_agenda_token';
  if coalesce(u,'')='' or coalesce(t,'')='' then raise warning 'Atendimento: configure atd_agenda_url e atd_agenda_token'; return; end if;
  perform net.http_post(url:=u,body:='{"action":"processar-emails"}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_email_acordar() from public,anon,authenticated;
do $$ begin perform cron.unschedule('atendimento-transmissao-email'); exception when others then null; end $$;
select cron.schedule('atendimento-transmissao-email','* * * * *','select public.atd_email_acordar()');

-- Imagens públicas para uso no corpo HTML dos e-mails; escrita limitada ao workspace.
do $storage$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
    values('email-assets','email-assets',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
    on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];
    execute 'drop policy if exists atd_email_assets_ler on storage.objects';
    execute 'drop policy if exists atd_email_assets_gravar on storage.objects';
    execute 'drop policy if exists atd_email_assets_editar on storage.objects';
    execute 'drop policy if exists atd_email_assets_apagar on storage.objects';
    execute $p$create policy atd_email_assets_ler on storage.objects for select to public using (bucket_id='email-assets')$p$;
    execute $p$create policy atd_email_assets_gravar on storage.objects for insert to authenticated with check (
      bucket_id='email-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
    execute $p$create policy atd_email_assets_editar on storage.objects for update to authenticated using (
      bucket_id='email-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas'])) with check (
      bucket_id='email-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
    execute $p$create policy atd_email_assets_apagar on storage.objects for delete to authenticated using (
      bucket_id='email-assets' and public.pertence_ao_workspace(((storage.foldername(name))[1])::uuid)
      and public.perm(((storage.foldername(name))[1])::uuid,'editar',array['vendas']))$p$;
  end if;
end $storage$;
