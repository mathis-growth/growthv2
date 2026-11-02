-- Mensagens transacionais por campanha, produto e formulário.
-- Os gatilhos só enfileiram; a Edge existente envia fora da transação de negócio.

alter table public.pesquisas
  add column if not exists extras jsonb not null default '{}'::jsonb
  check (jsonb_typeof(extras) = 'object');

create table if not exists public.atd_envios_transacionais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pessoa_id uuid not null references public.pessoas(id) on delete cascade,
  canal_id uuid not null,
  origem text not null check (origem in ('cadastro','venda','pesquisa')),
  origem_id uuid not null,
  template_name text not null,
  idioma text not null,
  parametros jsonb not null default '[]'::jsonb check (jsonb_typeof(parametros) = 'array'),
  status text not null default 'pendente' check (status in ('pendente','processando','enviado','erro','incerto')),
  tentativas integer not null default 0,
  externo_id text,
  erro text,
  criado_em timestamptz not null default now(),
  iniciado_em timestamptz,
  enviado_em timestamptz,
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, origem, origem_id),
  foreign key (workspace_id, canal_id) references public.atd_canais(workspace_id,id)
);
create index if not exists atd_tx_pendentes on public.atd_envios_transacionais(criado_em,id) where status='pendente';
create index if not exists atd_tx_pessoa on public.atd_envios_transacionais(pessoa_id,criado_em desc);
alter table public.atd_envios_transacionais enable row level security;
revoke all on public.atd_envios_transacionais from public, anon, authenticated;
grant all on public.atd_envios_transacionais to service_role;

create or replace function public._atd_tx_valor(pessoa jsonb, evento jsonb, chave text)
returns text language plpgsql stable set search_path=pg_catalog,public as $$
declare v text;
begin
  if chave like 'extra:%' then return pessoa #>> array['extras',substring(chave from 7)]; end if;
  case chave
    when 'nome' then v := pessoa->>'nome';
    when 'primeiro_nome' then v := split_part(trim(coalesce(pessoa->>'nome','')), ' ', 1);
    when 'email' then v := pessoa->>'email';
    when 'telefone' then v := pessoa->>'telefone';
    when 'produto' then v := evento->>'produto';
    when 'campanha' then v := coalesce(evento->>'campanha',pessoa->>'utm_campaign');
    when 'utm_campaign' then v := pessoa->>'utm_campaign';
    when 'capturado_em' then v := coalesce(evento->>'capturado_em',to_char((pessoa->>'criado_em')::timestamptz at time zone 'America/Sao_Paulo','DD/MM/YYYY'));
    when 'valor_venda' then v := evento->>'valor_venda';
    when 'data_venda' then v := evento->>'data_venda';
    when 'pesquisa' then v := evento->>'pesquisa';
    else v := null;
  end case;
  return nullif(trim(v),'');
end $$;
revoke all on function public._atd_tx_valor(jsonb,jsonb,text) from public,anon,authenticated;

create or replace function public._atd_tx_enfileirar(
  p_workspace uuid, p_pessoa uuid, p_origem text, p_origem_id uuid,
  p_config jsonb, p_evento jsonb
) returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare
  canal uuid; nome text; idioma text; vals jsonb; novo uuid; pj jsonb;
begin
  if p_config is null or jsonb_typeof(p_config) <> 'object' then return null; end if;
  begin canal := (p_config->>'canal_id')::uuid; exception when others then return null; end;
  nome := trim(coalesce(p_config->>'template_name',''));
  idioma := trim(coalesce(p_config->>'idioma',''));
  if nome = '' or idioma = '' or p_origem not in ('cadastro','venda','pesquisa') then return null; end if;
  if not exists(select 1 from public.atd_canais c where c.id=canal and c.workspace_id=p_workspace and c.provedor='zernio' and c.canal='whatsapp') then return null; end if;
  select to_jsonb(p) into pj from public.pessoas p where p.id=p_pessoa and p.workspace_id=p_workspace;
  if pj is null then return null; end if;
  select coalesce(jsonb_agg(to_jsonb(coalesce(public._atd_tx_valor(pj,coalesce(p_evento,'{}'::jsonb),x.value),'')) order by x.ordinality),'[]'::jsonb)
    into vals
    from jsonb_array_elements_text(case when jsonb_typeof(p_config->'parametros')='array' then p_config->'parametros' else '[]'::jsonb end) with ordinality x(value,ordinality);
  insert into public.atd_envios_transacionais(workspace_id,pessoa_id,canal_id,origem,origem_id,template_name,idioma,parametros)
    values (p_workspace,p_pessoa,canal,p_origem,p_origem_id,nome,idioma,vals)
  on conflict(workspace_id,origem,origem_id) do nothing
  returning id into novo;
  return novo;
end $$;
revoke all on function public._atd_tx_enfileirar(uuid,uuid,text,uuid,jsonb,jsonb) from public,anon,authenticated;

create or replace function public.atd_tx_pessoa_nova()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb;
begin
  if new.status_funil <> 'lead' or new.campanha_id is null then return new; end if;
  select c.extras->'mensagem_cadastro',jsonb_build_object('campanha',c.nome,'produto',p.nome,'capturado_em',to_char(new.criado_em at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,ctx from public.campanhas c left join public.produtos p on p.id=c.produto_id
    where c.id=new.campanha_id and c.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.id,'cadastro',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
drop trigger if exists atd_tx_pessoa_nova_t on public.pessoas;
create trigger atd_tx_pessoa_nova_t after insert on public.pessoas
for each row execute function public.atd_tx_pessoa_nova();
revoke all on function public.atd_tx_pessoa_nova() from public,anon,authenticated;

-- Formulários também podem atualizar uma pessoa existente, em vez de inserir outra.
-- Nessa situação lead_por_chave grava um toque captura com ref_tabela='captura'.
-- ref_tabela='religar' fica de fora para não disparar mensagem retroativa em lote.
create or replace function public.atd_tx_captura_repetida()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb;
begin
  if new.tipo <> 'captura' or new.ref_tabela <> 'captura' or new.campanha_id is null then return new; end if;
  select c.extras->'mensagem_cadastro',jsonb_build_object('campanha',c.nome,'produto',p.nome,
    'capturado_em',to_char(new.em at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,ctx from public.campanhas c
    join public.pessoas pessoa on pessoa.id=new.pessoa_id and pessoa.workspace_id=new.workspace_id
    left join public.produtos p on p.id=c.produto_id
    where c.id=new.campanha_id and c.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'cadastro',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
drop trigger if exists atd_tx_captura_repetida_t on public.pessoa_toques;
create trigger atd_tx_captura_repetida_t after insert on public.pessoa_toques
for each row execute function public.atd_tx_captura_repetida();
revoke all on function public.atd_tx_captura_repetida() from public,anon,authenticated;

create or replace function public.atd_tx_venda_aprovada()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb;
begin
  if new.status <> 'aprovada' or (tg_op='UPDATE' and old.status='aprovada') then return new; end if;
  select p.extras->'mensagem_venda',jsonb_build_object('produto',p.nome,'campanha',c.nome,
    'valor_venda',to_char(new.valor_bruto,'FM999999990D00'),'data_venda',to_char(new.data_venda at time zone 'America/Sao_Paulo','DD/MM/YYYY'))
    into cfg,ctx from public.produtos p left join public.campanhas c on c.id=new.campanha_id
    where p.id=new.produto_id and p.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'venda',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
drop trigger if exists atd_tx_venda_aprovada_t on public.vendas;
create trigger atd_tx_venda_aprovada_t after insert or update of status on public.vendas
for each row execute function public.atd_tx_venda_aprovada();
revoke all on function public.atd_tx_venda_aprovada() from public,anon,authenticated;

create or replace function public.atd_tx_pesquisa_respondida()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare cfg jsonb; ctx jsonb;
begin
  if new.pessoa_id is null then return new; end if;
  select s.extras->'mensagem_resposta',jsonb_build_object('pesquisa',s.nome,
    'capturado_em',to_char(new.respondida_em at time zone 'America/Sao_Paulo','DD/MM/YYYY'),
    'produto',(select pr.nome from public.vendas v join public.produtos pr on pr.id=v.produto_id
      where v.workspace_id=new.workspace_id and v.pessoa_id=new.pessoa_id and v.status='aprovada'
      order by v.data_venda desc limit 1),
    'campanha',(select c.nome from public.pessoas pessoa join public.campanhas c
      on c.id=pessoa.campanha_id and c.workspace_id=pessoa.workspace_id
      where pessoa.id=new.pessoa_id and pessoa.workspace_id=new.workspace_id))
    into cfg,ctx from public.pesquisas s where s.id=new.pesquisa_id and s.workspace_id=new.workspace_id;
  perform public._atd_tx_enfileirar(new.workspace_id,new.pessoa_id,'pesquisa',new.id,cfg,coalesce(ctx,'{}'::jsonb));
  return new;
end $$;
drop trigger if exists atd_tx_pesquisa_respondida_t on public.pesquisa_respostas;
create trigger atd_tx_pesquisa_respondida_t after insert on public.pesquisa_respostas
for each row execute function public.atd_tx_pesquisa_respondida();
revoke all on function public.atd_tx_pesquisa_respondida() from public,anon,authenticated;

create or replace function public.atd_tx_historico()
returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
declare situacao text;
begin
  if tg_op='INSERT' then
    situacao := 'Na fila';
  elsif old.status is distinct from new.status and new.status in ('enviado','erro','incerto') then
    situacao := case new.status when 'enviado' then 'Enviado' when 'erro' then 'Falha no envio' else 'Envio sem confirmação' end;
  else return new;
  end if;
  insert into public.pessoa_historico(workspace_id,pessoa_id,campo,valor_anterior,valor_novo)
  values(new.workspace_id,new.pessoa_id,'Mensagem automática · '||new.origem,
    case when tg_op='UPDATE' then old.status else null end,
    situacao||' · template '||new.template_name||coalesce(' · '||nullif(new.erro,''),''));
  return new;
end $$;
drop trigger if exists atd_tx_historico_t on public.atd_envios_transacionais;
create trigger atd_tx_historico_t after insert or update of status on public.atd_envios_transacionais
for each row execute function public.atd_tx_historico();
revoke all on function public.atd_tx_historico() from public,anon,authenticated;

create or replace function public.atd_tx_reservar(p_limite integer default 20)
returns setof public.atd_envios_transacionais language plpgsql security invoker set search_path=public as $$
begin
  update public.atd_envios_transacionais set status='incerto',atualizado_em=now(),
    erro='Processamento interrompido; confira o provedor antes de reenviar.'
  where status='processando' and iniciado_em < now()-interval '10 minutes';
  return query
  with candidatos as (
    select id from public.atd_envios_transacionais where status='pendente'
    order by criado_em,id for update skip locked limit least(greatest(p_limite,1),50)
  )
  update public.atd_envios_transacionais e set status='processando',iniciado_em=now(),atualizado_em=now(),tentativas=tentativas+1
  from candidatos c where e.id=c.id returning e.*;
end $$;
revoke all on function public.atd_tx_reservar(integer) from public,anon,authenticated;
grant execute on function public.atd_tx_reservar(integer) to service_role;

-- Amplia o cron existente do Atendimento para acordar também a fila transacional.
-- Assim não criamos um segundo cron nem uma segunda chamada Edge por minuto.
create or replace function public.atd_agenda_acordar() returns void
language plpgsql security definer set search_path=public as $$
declare u text; t text;
begin
  if not exists(select 1 from public.atd_agendamentos
      where (status='agendado' and enviar_em<=now())
         or (status='processando' and iniciado_em<now()-interval '10 minutes'))
     and not exists(select 1 from public.atd_envios_transacionais where status='pendente'
      or (status='processando' and iniciado_em<now()-interval '10 minutes')) then return; end if;
  select valor into u from public.sistema_config where chave='atd_agenda_url';
  select valor into t from public.sistema_config where chave='atd_agenda_token';
  if coalesce(u,'')='' or coalesce(t,'')='' then
    raise warning 'Atendimento transacional: configure atd_agenda_url e atd_agenda_token'; return;
  end if;
  perform net.http_post(url:=u,body:='{"action":"processar-agendamentos"}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json','x-atd-agenda-token',t),timeout_milliseconds:=30000);
end $$;
revoke all on function public.atd_agenda_acordar() from public,anon,authenticated;
