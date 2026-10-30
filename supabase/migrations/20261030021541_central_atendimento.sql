-- Central de atendimento. Independente das tabelas sociais e das conexões: desligar
-- uma conta nunca apaga o histórico. Permissões iniciais herdadas de Vendas.
create schema if not exists privado;
revoke all on schema privado from public, anon, authenticated;

create table public.atd_canais (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id),
 provedor text not null, canal text not null, nome text not null, externo_id text not null,
 status text not null default 'desconectado', numero text, ativo boolean not null default true,
 criado_em timestamptz not null default now(), unique(workspace_id,id), unique(provedor,externo_id)
);
create table privado.atd_segredos (
 workspace_id uuid primary key references public.workspaces(id), evolution_url text not null,
 evolution_key text not null, webhook_secret text not null, atualizado_em timestamptz not null default now()
);
revoke all on privado.atd_segredos from public,anon,authenticated;
create table public.atd_conversas (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references workspaces(id),
 canal_id uuid not null, externo_id text not null, nome text not null, endereco text,
 grupo boolean not null default false, pessoa_id uuid references pessoas(id) on delete set null,
 responsavel_id uuid references auth.users(id) on delete set null,
 status text not null default 'aberta' check(status in ('aberta','aguardando','resolvida')),
 ultima_em timestamptz, ultima_mensagem text, nao_lidas int not null default 0,
 criado_em timestamptz not null default now(), unique(workspace_id,id), unique(canal_id,externo_id),
 foreign key(workspace_id,canal_id) references atd_canais(workspace_id,id)
);
create index atd_conversas_fila on atd_conversas(workspace_id,ultima_em desc,id);
create table public.atd_mensagens (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null,
 conversa_id uuid not null, externo_id text, requisicao_id uuid,
 direcao text not null check(direcao in ('recebida','enviada','nota')),
 texto text not null default '', autor_id uuid references auth.users(id) on delete set null,
 autor_nome text, participante text, anexos jsonb not null default '[]',
 status text not null default 'recebida' check(status in ('recebida','enviando','enviada','entregue','lida','falhou','incerto','nota')),
 erro text, em timestamptz not null default now(), criado_em timestamptz not null default now(),
 foreign key(workspace_id,conversa_id) references atd_conversas(workspace_id,id),
 unique(conversa_id,externo_id), unique(workspace_id,requisicao_id)
);
create index atd_mensagens_historico on atd_mensagens(conversa_id,em desc,id);
-- Dados de recuperação de mídia ficam exclusivamente no servidor.
create table privado.atd_midias_pendentes (
 mensagem_id uuid primary key references public.atd_mensagens(id) on delete cascade, origem jsonb not null,
 tentativas int not null default 0, erro text, atualizado_em timestamptz not null default now()
);
revoke all on privado.atd_midias_pendentes from public,anon,authenticated;

create function public.atd_contexto(p_ws uuid) returns jsonb
language plpgsql volatile security definer set search_path=public as $$
declare n text; email_login text;
begin
 if auth.uid() is null or not pertence_ao_workspace(p_ws) or not perm(p_ws,'ler',array['vendas']) then
  raise exception 'Sem acesso ao Atendimento.' using errcode='42501'; end if;
 select nome into n from equipe where workspace_id=p_ws and user_id=auth.uid() and ativo limit 1;
 if n is null then
  select email into email_login from auth.users where id=auth.uid();
  if email_login is not null then
   update equipe set user_id=auth.uid()
    where id=(select id from equipe where workspace_id=p_ws and ativo and lower(email)=lower(email_login) and user_id is null order by criado_em limit 1)
    returning nome into n;
  end if;
 end if;
 return jsonb_build_object('user_id',auth.uid(),'nome',n,'editar',perm(p_ws,'editar',array['vendas']),'admin',eh_admin(p_ws));
end $$;
revoke all on function public.atd_contexto(uuid) from public,anon;
grant execute on function public.atd_contexto(uuid) to authenticated;

-- Única entrada para segredos. Não concedida ao navegador, mesmo a administradores.
create function public.atd_segredo(p_ws uuid,p_dados jsonb default null) returns jsonb
language plpgsql security definer set search_path=public,privado as $$
begin
 if p_dados is not null then
  insert into privado.atd_segredos(workspace_id,evolution_url,evolution_key,webhook_secret)
  values(p_ws,p_dados->>'url',p_dados->>'key',p_dados->>'secret')
  on conflict(workspace_id) do update set evolution_url=excluded.evolution_url,
   evolution_key=excluded.evolution_key, atualizado_em=now();
 end if;
 return (select to_jsonb(s) from privado.atd_segredos s where workspace_id=p_ws);
end $$;
revoke all on function public.atd_segredo(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.atd_segredo(uuid,jsonb) to service_role;

create function public.atd_validar_vinculo() returns trigger language plpgsql set search_path=public as $$
begin
 if new.pessoa_id is not null and (new.grupo or not exists(select 1 from pessoas where id=new.pessoa_id and workspace_id=new.workspace_id)) then
  raise exception 'Pessoa inválida para esta conversa.'; end if;
 if new.responsavel_id is not null and not exists(select 1 from workspace_membros where workspace_id=new.workspace_id and user_id=new.responsavel_id) then
  raise exception 'Responsável não pertence ao workspace.'; end if;
 return new;
end $$;
create trigger atd_vinculo before insert or update on atd_conversas for each row execute function atd_validar_vinculo();

-- UPSERT atômico: repetição de webhook não duplica mensagens/não lidas; eventos
-- atrasados não fazem o resumo da conversa voltar no tempo.
create function public.atd_receber(p_canal uuid,p_conversa jsonb,p_mensagem jsonb default null) returns uuid
language plpgsql security definer set search_path=public as $$
declare c atd_canais; cv uuid; mid uuid; nova boolean;
begin
 select * into strict c from atd_canais where id=p_canal for update;
 insert into atd_conversas(workspace_id,canal_id,externo_id,nome,endereco,grupo)
 values(c.workspace_id,c.id,p_conversa->>'id',coalesce(nullif(p_conversa->>'nome',''),p_conversa->>'id'),p_conversa->>'endereco',coalesce((p_conversa->>'grupo')::boolean,false))
 on conflict(canal_id,externo_id) do update set nome=case when nullif(p_conversa->>'nome','') is not null then excluded.nome else atd_conversas.nome end
 returning id into cv;
 if p_mensagem is null then return cv; end if;
 insert into atd_mensagens(workspace_id,conversa_id,externo_id,direcao,texto,participante,autor_nome,status,em,anexos)
 values(c.workspace_id,cv,p_mensagem->>'id',p_mensagem->>'direcao',coalesce(p_mensagem->>'texto',''),p_mensagem->>'participante',p_mensagem->>'autor_nome',
 coalesce(p_mensagem->>'status','recebida'),coalesce((p_mensagem->>'em')::timestamptz,now()),coalesce(p_mensagem->'anexos','[]'))
 on conflict(conversa_id,externo_id) do nothing returning id into mid;
 nova := mid is not null;
 if nova then
  update atd_conversas set nao_lidas=nao_lidas+case when p_mensagem->>'direcao'='recebida' and not coalesce((p_mensagem->>'historica')::boolean,false) then 1 else 0 end,
   status=case when p_mensagem->>'direcao'='recebida' and not coalesce((p_mensagem->>'historica')::boolean,false) then 'aberta' else status end,
   ultima_mensagem=case when ultima_em is null or ultima_em <= coalesce((p_mensagem->>'em')::timestamptz,now()) then p_mensagem->>'texto' else ultima_mensagem end,
   ultima_em=greatest(ultima_em,coalesce((p_mensagem->>'em')::timestamptz,now())) where id=cv;
 end if;
 return cv;
end $$;
revoke all on function public.atd_receber(uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.atd_receber(uuid,jsonb,jsonb) to service_role;

create function public.atd_confirmar_envio(p_mensagem uuid,p_externo text) returns void
language plpgsql security definer set search_path=public as $$
declare m atd_mensagens; eco atd_mensagens; cid uuid;
begin
 select * into strict m from atd_mensagens where id=p_mensagem;
 select canal_id into cid from atd_conversas where id=m.conversa_id;
 perform 1 from atd_canais where id=cid for update;
 select * into eco from atd_mensagens where conversa_id=m.conversa_id and externo_id=p_externo and id<>m.id;
 if eco.id is not null then delete from atd_mensagens where id=eco.id; end if;
 update atd_mensagens set externo_id=p_externo,status=coalesce(eco.status,'enviada'),
  anexos=case when jsonb_array_length(m.anexos)>0 then m.anexos else coalesce(eco.anexos,'[]') end where id=m.id;
 update atd_conversas set ultima_em=m.em,ultima_mensagem=m.texto where id=m.conversa_id and (ultima_em is null or ultima_em<=m.em);
end $$;
revoke all on function public.atd_confirmar_envio(uuid,text) from public,anon,authenticated;
grant execute on function public.atd_confirmar_envio(uuid,text) to service_role;

create function public.atd_midia_pendente(p_mensagem uuid,p_origem jsonb default null) returns jsonb
language plpgsql security definer set search_path=public,privado as $$
begin
 if p_origem is not null then
  insert into privado.atd_midias_pendentes(mensagem_id,origem) values(p_mensagem,p_origem)
  on conflict(mensagem_id) do update set origem=excluded.origem,atualizado_em=now();
 end if;
 return (select origem from privado.atd_midias_pendentes where mensagem_id=p_mensagem);
end $$;
revoke all on function public.atd_midia_pendente(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.atd_midia_pendente(uuid,jsonb) to service_role;

do $$ declare t text; begin
 foreach t in array array['atd_canais','atd_conversas','atd_mensagens'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy atd_leitura on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id,''ler'',array[''vendas'']))',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;

insert into acesso_telas(tela,modulo,nome,grupo,ordem) values
 ('atd-conversas','vendas','Conversas','Atendimento',120),('atd-canais','vendas','Canais e conexões','Atendimento',121)
on conflict(tela) do nothing;

-- Storage é privado, sem acesso anônimo. URLs curtas emitidas apenas após autorização.
insert into storage.buckets(id,name,public,file_size_limit) values('atendimento','atendimento',false,20971520) on conflict(id) do nothing;
-- A tela usa Realtime com recuperação por leitura periódica, sem mexer no schema realtime.
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.atd_conversas,public.atd_mensagens;
 end if;
end $$;
