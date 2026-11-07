-- Fluxos de e-mail em canvas, vinculáveis a cadastro, resposta de pesquisa e venda.
create table if not exists public.atd_email_automacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check(length(trim(nome)) between 1 and 120),
  evento text not null check(evento in ('cadastro','pesquisa','venda')),
  fluxo jsonb not null default '{}'::jsonb check(jsonb_typeof(fluxo)='object'),
  ativo boolean not null default false,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(workspace_id,id)
);
create index if not exists atd_email_automacoes_workspace_evento on public.atd_email_automacoes(workspace_id,evento,ativo);
alter table public.atd_email_automacoes enable row level security;
drop policy if exists atd_email_automacoes_ler on public.atd_email_automacoes;
create policy atd_email_automacoes_ler on public.atd_email_automacoes for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_email_automacoes from public,anon,authenticated;
grant select on public.atd_email_automacoes to authenticated;
grant all on public.atd_email_automacoes to service_role;

create table if not exists public.atd_email_automacao_execucoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  automacao_id uuid not null,
  pessoa_id uuid not null,
  origem text not null check(origem in ('cadastro','pesquisa','venda')),
  origem_id uuid not null,
  estado jsonb not null default '{}'::jsonb,
  status text not null default 'pendente' check(status in ('pendente','processando','aguardando','enviado','erro','incerto')),
  retomar_em timestamptz not null default now(),
  erro text,
  executado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(automacao_id,origem,origem_id),
  foreign key(workspace_id,automacao_id) references public.atd_email_automacoes(workspace_id,id),
  foreign key(pessoa_id) references public.pessoas(id) on delete cascade
);
create index if not exists atd_email_auto_execucoes_pendentes on public.atd_email_automacao_execucoes(status,retomar_em);
create index if not exists atd_email_auto_execucoes_pessoa on public.atd_email_automacao_execucoes(pessoa_id,executado_em desc);
alter table public.atd_email_automacao_execucoes enable row level security;
drop policy if exists atd_email_auto_execucoes_ler on public.atd_email_automacao_execucoes;
create policy atd_email_auto_execucoes_ler on public.atd_email_automacao_execucoes for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_email_automacao_execucoes from public,anon,authenticated;
grant select on public.atd_email_automacao_execucoes to authenticated;
grant all on public.atd_email_automacao_execucoes to service_role;

create table if not exists public.atd_email_automacao_envios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  execucao_id uuid not null,
  pessoa_id uuid not null,
  node_id text not null,
  email text not null,
  assunto text not null,
  status text not null default 'processando' check(status in ('processando','enviado','erro','incerto')),
  externo_id text,
  erro text,
  criado_em timestamptz not null default now(),
  enviado_em timestamptz,
  atualizado_em timestamptz not null default now(),
  unique(execucao_id,node_id),
  foreign key(execucao_id) references public.atd_email_automacao_execucoes(id) on delete cascade,
  foreign key(pessoa_id) references public.pessoas(id) on delete cascade
);
create index if not exists atd_email_auto_envios_pessoa on public.atd_email_automacao_envios(pessoa_id,criado_em desc);
alter table public.atd_email_automacao_envios enable row level security;
drop policy if exists atd_email_auto_envios_ler on public.atd_email_automacao_envios;
create policy atd_email_auto_envios_ler on public.atd_email_automacao_envios for select to authenticated
  using(public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_email_automacao_envios from public,anon,authenticated;
grant select on public.atd_email_automacao_envios to authenticated;
grant all on public.atd_email_automacao_envios to service_role;

create or replace function public.atd_email_automacao_historico()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare rotulo text;
begin
  if tg_op='INSERT' then rotulo:='Na fila';
  elsif old.status is distinct from new.status and new.status in ('enviado','erro','incerto') then
    rotulo:=case new.status when 'enviado' then 'Enviado' when 'erro' then 'Falha no envio' else 'Envio sem confirmação' end;
  else return new; end if;
  insert into public.pessoa_historico(workspace_id,pessoa_id,campo,valor_anterior,valor_novo)
  values(new.workspace_id,new.pessoa_id,'Automação de e-mail',case when tg_op='UPDATE' then old.status else null end,
    rotulo||' · '||new.assunto||coalesce(' · '||nullif(new.erro,''),''));
  return new;
end $$;
drop trigger if exists atd_email_automacao_historico_t on public.atd_email_automacao_envios;
create trigger atd_email_automacao_historico_t after insert or update of status on public.atd_email_automacao_envios
for each row execute function public.atd_email_automacao_historico();
revoke all on function public.atd_email_automacao_historico() from public,anon,authenticated;

create or replace function public._atd_email_automacao_enfileirar(
  p_workspace uuid,p_pessoa uuid,p_automacao text,p_evento text,p_origem_id uuid,p_contexto jsonb
) returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare aid uuid; f public.atd_email_automacoes; novo uuid; start_id text;
begin
  begin aid:=nullif(p_automacao,'')::uuid; exception when others then return null; end;
  if aid is null or p_evento not in ('cadastro','pesquisa','venda') or p_origem_id is null then return null; end if;
  select * into f from public.atd_email_automacoes where id=aid and workspace_id=p_workspace and evento=p_evento and ativo;
  if not found then return null; end if;
  select n->>'id' into start_id from jsonb_array_elements(coalesce(f.fluxo->'nodes','[]'::jsonb)) n where n->>'tipo'='gatilho' limit 1;
  insert into public.atd_email_automacao_execucoes(workspace_id,automacao_id,pessoa_id,origem,origem_id,estado,retomar_em)
  values(p_workspace,aid,p_pessoa,p_evento,p_origem_id,jsonb_build_object('fluxo',f.fluxo,'evento',coalesce(p_contexto,'{}'::jsonb),'no_id',start_id,'visitados','[]'::jsonb),now())
  on conflict(automacao_id,origem,origem_id) do nothing returning id into novo;
  return novo;
end $$;
revoke all on function public._atd_email_automacao_enfileirar(uuid,uuid,text,text,uuid,jsonb) from public,anon,authenticated;

create or replace function public.atd_email_automacao_reservar(p_limite integer default 10)
returns setof public.atd_email_automacao_execucoes language plpgsql security invoker set search_path=public as $$
begin
  update public.atd_email_automacao_execucoes set status='incerto',retomar_em=now(),atualizado_em=now(),erro='Processamento interrompido; confira o histórico do Resend antes de repetir.'
    where status='processando' and atualizado_em<now()-interval '10 minutes';
  return query with candidatos as (
    select id from public.atd_email_automacao_execucoes
    where status in ('pendente','aguardando') and retomar_em<=now()
    order by retomar_em,id for update skip locked limit least(greatest(p_limite,1),20)
  ) update public.atd_email_automacao_execucoes e set status='processando',retomar_em=now()+interval '10 minutes',atualizado_em=now()
    from candidatos c where e.id=c.id returning e.*;
end $$;
revoke all on function public.atd_email_automacao_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_email_automacao_reservar(integer) to service_role;

-- Ingresso na campanha: envia e-mail separado do template WhatsApp atual.
create or replace function public.atd_tx_pessoa_nova()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb; email_flow text;
begin
  if new.status_funil <> 'lead' or new.campanha_id is null then return new; end if;
  select c.extras->'mensagem_cadastro',c.extras->>'email_automacao_cadastro_id',
    jsonb_build_object('campanha',c.nome,'produto',p.nome,'capturado_em',to_char(new.criado_em at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,email_flow,ctx from public.campanhas c left join public.produtos p on p.id=c.produto_id
    where c.id=new.campanha_id and c.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.id,'cadastro',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  perform public._atd_email_automacao_enfileirar(new.workspace_id,new.id,email_flow,'cadastro',new.id,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
revoke all on function public.atd_tx_pessoa_nova() from public,anon,authenticated;

create or replace function public.atd_tx_captura_repetida()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb; email_flow text;
begin
  if new.tipo <> 'captura' or new.ref_tabela <> 'captura' or new.campanha_id is null then return new; end if;
  select c.extras->'mensagem_cadastro',c.extras->>'email_automacao_cadastro_id',jsonb_build_object('campanha',c.nome,'produto',p.nome,
    'capturado_em',to_char(new.em at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,email_flow,ctx from public.campanhas c
    join public.pessoas pessoa on pessoa.id=new.pessoa_id and pessoa.workspace_id=new.workspace_id
    left join public.produtos p on p.id=c.produto_id where c.id=new.campanha_id and c.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'cadastro',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  perform public._atd_email_automacao_enfileirar(new.workspace_id,new.pessoa_id,email_flow,'cadastro',new.id,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
revoke all on function public.atd_tx_captura_repetida() from public,anon,authenticated;

create or replace function public.atd_tx_venda_aprovada()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb; email_flow text;
begin
  if new.status <> 'aprovada' or (tg_op='UPDATE' and old.status='aprovada') then return new; end if;
  select p.extras->'mensagem_venda',p.extras->>'email_automacao_venda_id',jsonb_build_object('produto',p.nome,'campanha',c.nome,
    'valor_venda',to_char(new.valor_bruto,'FM999999990D00'),'data_venda',to_char(new.data_venda at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,email_flow,ctx from public.produtos p left join public.campanhas c on c.id=new.campanha_id
    where p.id=new.produto_id and p.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'venda',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  perform public._atd_email_automacao_enfileirar(new.workspace_id,new.pessoa_id,email_flow,'venda',new.id,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
revoke all on function public.atd_tx_venda_aprovada() from public,anon,authenticated;

create or replace function public.atd_tx_pesquisa_respondida()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb; email_flow text;
begin
  if new.pessoa_id is null then return new; end if;
  select s.extras->'mensagem_resposta',s.extras->>'email_automacao_pesquisa_id',jsonb_build_object('pesquisa',s.nome,
    'capturado_em',to_char(new.respondida_em at time zone 'America/Sao_Paulo','DD/MM/YYYY'),
    'produto',(select pr.nome from public.vendas v join public.produtos pr on pr.id=v.produto_id where v.workspace_id=new.workspace_id and v.pessoa_id=new.pessoa_id and v.status='aprovada' order by v.data_venda desc limit 1),
    'campanha',(select c.nome from public.pessoas pessoa join public.campanhas c on c.id=pessoa.campanha_id and c.workspace_id=pessoa.workspace_id where pessoa.id=new.pessoa_id and pessoa.workspace_id=new.workspace_id))
    into cfg,email_flow,ctx from public.pesquisas s where s.id=new.pesquisa_id and s.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'pesquisa',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  perform public._atd_email_automacao_enfileirar(new.workspace_id,new.pessoa_id,email_flow,'pesquisa',new.id,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
revoke all on function public.atd_tx_pesquisa_respondida() from public,anon,authenticated;
