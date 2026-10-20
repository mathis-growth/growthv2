-- v0.120 — Conexões com Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube)
-- Login OAuth pela edge function "conexoes"; dados puxados pela edge function "sincronizar".
-- Os tokens ficam no schema "privado" (fora da API do Supabase): só as funções do servidor (service_role) leem.
-- Anúncios importados caem primeiro em ads_externo_dia e são ligados ao canal da campanha pelo nome/utm_campaign
-- (ou pelo vínculo escolhido na tela); daí entram em anuncios + metricas_anuncio_dia (origem "integracao").
-- Orgânico: social_perfis_dia (seguidores, alcance… por dia) e social_posts (cada post/vídeo com métricas).
-- YouTube: vídeos cadastrados em Vídeos e webinários (plataforma youtube + id) recebem video_metricas_dia.
-- Rode depois de 20261022100000_comissoes.sql. Pode rodar de novo.

create schema if not exists privado;
revoke all on schema privado from public, anon, authenticated;
grant usage on schema privado to service_role;

create table if not exists conexoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  plataforma text not null check (plataforma in ('meta', 'google')),
  status text not null default 'desconectado' check (status in ('conectado', 'expirada', 'erro', 'desconectado')),
  conta_nome text, escopos text[] not null default '{}',
  conectado_em timestamptz, conectado_por uuid, expira_em timestamptz,
  ultima_sincronizacao timestamptz, ultimo_erro text,
  sincronizar_auto boolean not null default true, dias_retroativos smallint not null default 30 check (dias_retroativos between 1 and 365),
  criado_em timestamptz not null default now(),
  unique (workspace_id, plataforma)
);

create table if not exists privado.conexao_tokens (
  conexao_id uuid primary key references public.conexoes(id) on delete cascade,
  access_token text not null, refresh_token text, expira_em timestamptz, atualizado_em timestamptz not null default now()
);
revoke all on privado.conexao_tokens from public, anon, authenticated;
grant select, insert, update, delete on privado.conexao_tokens to service_role;

create table if not exists privado.conexao_estados (
  nonce text primary key, workspace_id uuid not null, plataforma text not null, user_id uuid, volta text,
  expira_em timestamptz not null default now() + interval '15 minutes'
);
revoke all on privado.conexao_estados from public, anon, authenticated;

create table if not exists conexao_contas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conexao_id uuid not null references conexoes(id) on delete cascade,
  tipo text not null check (tipo in ('meta_ads', 'instagram', 'facebook_pagina', 'google_ads', 'youtube')),
  id_externo text not null, nome text, sincronizar boolean not null default true, extras jsonb not null default '{}',
  criado_em timestamptz not null default now(),
  unique (conexao_id, tipo, id_externo)
);

create table if not exists conexao_execucoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conexao_id uuid references conexoes(id) on delete cascade,
  iniciado_em timestamptz not null default now(), terminado_em timestamptz,
  status text not null default 'rodando' check (status in ('rodando', 'ok', 'parcial', 'erro')),
  registros int not null default 0, erro text, detalhe jsonb not null default '{}', disparado_por text
);
create index if not exists conexao_execucoes_idx on conexao_execucoes (workspace_id, iniciado_em desc);

create table if not exists ads_externo_dia (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  provedor text not null, data date not null,
  campanha_ext text not null, campanha_nome text, conjunto_nome text,
  anuncio_ext text not null, anuncio_nome text, url_tags text,
  impressoes bigint not null default 0, cliques bigint not null default 0, custo numeric not null default 0, alcance bigint,
  leads int, conversoes numeric, receita numeric,
  anuncio_id uuid references anuncios(id) on delete set null,
  atualizado_em timestamptz not null default now(),
  primary key (conta_id, anuncio_ext, data)
);
create index if not exists ads_externo_ws_idx on ads_externo_dia (workspace_id, provedor, campanha_ext);

create table if not exists ads_externo_vinculos (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  provedor text not null, campanha_ext text not null, campanha_nome text,
  campanha_canal_id uuid references campanha_canais(id) on delete cascade,
  ignorar boolean not null default false,
  primary key (workspace_id, provedor, campanha_ext)
);

create table if not exists social_perfis_dia (
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  data date not null,
  seguidores int, seguidores_ganhos int, alcance int, impressoes int, visualizacoes int, visitas_perfil int, cliques_site int,
  minutos_assistidos numeric, atualizado_em timestamptz not null default now(),
  primary key (conta_id, data)
);

create table if not exists social_posts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conta_id uuid not null references conexao_contas(id) on delete cascade,
  id_externo text not null, tipo text, legenda text, url text, miniatura text, publicado_em timestamptz,
  alcance int, impressoes int, visualizacoes int, curtidas int, comentarios int, compartilhamentos int, salvamentos int,
  minutos_assistidos numeric, conteudo_publicacao_id uuid references conteudo_publicacoes(id) on delete set null,
  atualizado_em timestamptz not null default now(),
  unique (conta_id, id_externo)
);

-- acesso pelo navegador: ler (Configurações e Marketing); editar só o que é escolha (contas a sincronizar, vínculos)
do $$ declare t text; begin
  foreach t in array array['conexoes', 'conexao_contas', 'conexao_execucoes', 'ads_externo_dia', 'ads_externo_vinculos', 'social_perfis_dia', 'social_posts'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists acesso_ler on %I', t);
    execute format('create policy acesso_ler on %I for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, ''ler'', ''{cfg,mkt,adm}''::text[]))', t);
    execute format('grant select on %I to authenticated', t);
  end loop;
end $$;
drop policy if exists escolher on conexao_contas;
create policy escolher on conexao_contas for update to authenticated using (perm(workspace_id, 'editar', '{cfg}'::text[])) with check (perm(workspace_id, 'editar', '{cfg}'::text[]));
grant update (sincronizar) on conexao_contas to authenticated;
drop policy if exists escolher on conexoes;
create policy escolher on conexoes for update to authenticated using (perm(workspace_id, 'editar', '{cfg}'::text[])) with check (perm(workspace_id, 'editar', '{cfg}'::text[]));
grant update (sincronizar_auto, dias_retroativos) on conexoes to authenticated;
drop policy if exists vincular on ads_externo_vinculos;
create policy vincular on ads_externo_vinculos for all to authenticated using (perm(workspace_id, 'editar', '{cfg,mkt}'::text[])) with check (perm(workspace_id, 'editar', '{cfg,mkt}'::text[]));
grant insert, update, delete on ads_externo_vinculos to authenticated;

-- ===== chamadas do navegador (usuário logado) =====
create or replace function public.conexao_iniciar(p_ws uuid, p_plataforma text, p_volta text) returns text
language plpgsql security definer set search_path = public as $$
declare n text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not perm(p_ws, 'editar', '{cfg}'::text[]) then raise exception 'Só quem edita Configurações pode conectar contas'; end if;
  if p_plataforma not in ('meta', 'google') then raise exception 'Plataforma inválida'; end if;
  delete from privado.conexao_estados where expira_em < now();
  insert into privado.conexao_estados (nonce, workspace_id, plataforma, user_id, volta) values (n, p_ws, p_plataforma, auth.uid(), left(p_volta, 500));
  return n;
end $$;
grant execute on function public.conexao_iniciar(uuid, text, text) to authenticated;

create or replace function public.conexao_pode(p_ws uuid) returns boolean
language sql stable security definer set search_path = public as $$ select perm(p_ws, 'editar', '{cfg,mkt}'::text[]) $$;
grant execute on function public.conexao_pode(uuid) to authenticated;

create or replace function public.conexao_desconectar(p_ws uuid, p_plataforma text) returns void
language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  if not perm(p_ws, 'editar', '{cfg}'::text[]) then raise exception 'Só quem edita Configurações pode desconectar'; end if;
  select id into c from conexoes where workspace_id = p_ws and plataforma = p_plataforma;
  delete from privado.conexao_tokens where conexao_id = c;
  update conexoes set status = 'desconectado', expira_em = null where id = c;
  update integracoes set status = 'desconectado' where workspace_id = p_ws
     and provedor = any (case p_plataforma when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end);
end $$;
grant execute on function public.conexao_desconectar(uuid, text) to authenticated;

-- ===== chamadas das edge functions (service_role) =====
create or replace function public.conexao_estado_usar(p_nonce text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e privado.conexao_estados;
begin
  delete from privado.conexao_estados where nonce = p_nonce returning * into e;
  if e.nonce is null or e.expira_em < now() then return null; end if;
  return jsonb_build_object('ws', e.workspace_id, 'plataforma', e.plataforma, 'uid', e.user_id, 'volta', e.volta);
end $$;

create or replace function public.conexao_salvar(p_ws uuid, p_plataforma text, p_uid uuid, p_conta_nome text, p_escopos text[], p_access text, p_refresh text, p_expira timestamptz, p_contas jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid; x jsonb; provs text[] := case p_plataforma when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end; p text;
begin
  insert into conexoes (workspace_id, plataforma, status, conta_nome, escopos, conectado_em, conectado_por, expira_em, ultimo_erro)
  values (p_ws, p_plataforma, 'conectado', p_conta_nome, coalesce(p_escopos, '{}'), now(), p_uid, p_expira, null)
  on conflict (workspace_id, plataforma) do update set status = 'conectado', conta_nome = excluded.conta_nome, escopos = excluded.escopos,
     conectado_em = now(), conectado_por = excluded.conectado_por, expira_em = excluded.expira_em, ultimo_erro = null
  returning id into c;
  insert into privado.conexao_tokens (conexao_id, access_token, refresh_token, expira_em) values (c, p_access, p_refresh, p_expira)
  on conflict (conexao_id) do update set access_token = excluded.access_token,
     refresh_token = coalesce(excluded.refresh_token, privado.conexao_tokens.refresh_token), expira_em = excluded.expira_em, atualizado_em = now();
  for x in select * from jsonb_array_elements(coalesce(p_contas, '[]'::jsonb)) loop
    insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome, extras)
    values (p_ws, c, x ->> 'tipo', x ->> 'id', x ->> 'nome', coalesce(x -> 'extras', '{}'::jsonb))
    on conflict (conexao_id, tipo, id_externo) do update set nome = excluded.nome, extras = excluded.extras;
  end loop;
  foreach p in array provs loop
    insert into integracoes (workspace_id, provedor, categoria, status, conta_externa, observacao, ultima_sincronizacao)
    values (p_ws, p, case when p in ('Meta Ads', 'Google Ads') then 'anuncios' when p = 'YouTube' then 'video' else 'social' end, 'conectado', p_conta_nome, 'Conectado pelo login da plataforma.', null)
    on conflict (workspace_id, provedor) do update set status = 'conectado', conta_externa = excluded.conta_externa;
  end loop;
  return c;
end $$;

create or replace function public.conexao_para_sincronizar(p_ws uuid, p_plataforma text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ws', c.workspace_id, 'plataforma', c.plataforma, 'dias', c.dias_retroativos, 'ultima', c.ultima_sincronizacao,
      'access_token', t.access_token, 'refresh_token', t.refresh_token, 'expira_em', t.expira_em,
      'contas', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'tipo', k.tipo, 'id_externo', k.id_externo, 'nome', k.nome, 'extras', k.extras)) from conexao_contas k where k.conexao_id = c.id and k.sincronizar), '[]'::jsonb),
      'videos', case when c.plataforma = 'google' then coalesce((select jsonb_agg(jsonb_build_object('fonte_id', f.id, 'video', f.id_externo)) from fontes_video f where f.workspace_id = c.workspace_id and f.plataforma = 'youtube' and f.ativo and f.id_externo is not null), '[]'::jsonb) end)), '[]'::jsonb)
    from conexoes c join privado.conexao_tokens t on t.conexao_id = c.id
   where c.status in ('conectado', 'expirada', 'erro') and (p_ws is null or c.workspace_id = p_ws) and (p_plataforma is null or c.plataforma = p_plataforma)
     and (p_ws is not null or c.sincronizar_auto)
$$;

create or replace function public.conexao_token_atualizar(p_conexao uuid, p_access text, p_expira timestamptz) returns void
language sql security definer set search_path = public as $$
  update privado.conexao_tokens set access_token = p_access, expira_em = p_expira, atualizado_em = now() where conexao_id = p_conexao;
  update conexoes set expira_em = p_expira, status = 'conectado' where id = p_conexao;
$$;

create or replace function public.conexao_execucao(p_conexao uuid, p_id uuid, p_status text, p_registros int, p_erro text, p_detalhe jsonb, p_por text) returns uuid
language plpgsql security definer set search_path = public as $$
declare i uuid := p_id; ws uuid;
begin
  select workspace_id into ws from conexoes where id = p_conexao;
  if i is null then
    insert into conexao_execucoes (workspace_id, conexao_id, disparado_por) values (ws, p_conexao, p_por) returning id into i;
  else
    update conexao_execucoes set terminado_em = now(), status = p_status, registros = coalesce(p_registros, 0), erro = p_erro, detalhe = coalesce(p_detalhe, '{}') where id = i;
    update conexoes set ultima_sincronizacao = case when p_status in ('ok', 'parcial') then now() else ultima_sincronizacao end,
           ultimo_erro = p_erro, status = case when p_erro ~* 'token|oauth|expir|invalid_grant|session' then 'expirada' when p_status = 'erro' then 'erro' else 'conectado' end
     where id = p_conexao;
    update integracoes set ultima_sincronizacao = now(), status = case when p_status = 'erro' then 'erro' else 'conectado' end
     where workspace_id = ws and status <> 'desconectado'
       and provedor = any (case (select plataforma from conexoes where id = p_conexao) when 'meta' then array['Meta Ads', 'Instagram'] else array['Google Ads', 'YouTube'] end);
  end if;
  return i;
end $$;

-- grava o que veio da plataforma. p_tipo: ads | perfil | posts | video
create or replace function public.conexao_gravar(p_conta uuid, p_tipo text, p_linhas jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare k conexao_contas; x jsonb; n int := 0; f uuid;
begin
  select * into k from conexao_contas where id = p_conta;
  if k.id is null then raise exception 'Conta não encontrada'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_linhas, '[]'::jsonb)) loop
    if p_tipo = 'ads' then
      insert into ads_externo_dia (workspace_id, conta_id, provedor, data, campanha_ext, campanha_nome, conjunto_nome, anuncio_ext, anuncio_nome, url_tags, impressoes, cliques, custo, alcance, leads, conversoes, receita)
      values (k.workspace_id, k.id, k.tipo, (x ->> 'data')::date, x ->> 'campanha_ext', x ->> 'campanha_nome', x ->> 'conjunto_nome', x ->> 'anuncio_ext', x ->> 'anuncio_nome', x ->> 'url_tags',
              coalesce((x ->> 'impressoes')::bigint, 0), coalesce((x ->> 'cliques')::bigint, 0), coalesce((x ->> 'custo')::numeric, 0), (x ->> 'alcance')::bigint,
              (x ->> 'leads')::int, (x ->> 'conversoes')::numeric, (x ->> 'receita')::numeric)
      on conflict (conta_id, anuncio_ext, data) do update set campanha_ext = excluded.campanha_ext, campanha_nome = excluded.campanha_nome, conjunto_nome = excluded.conjunto_nome,
         anuncio_nome = excluded.anuncio_nome, url_tags = coalesce(excluded.url_tags, ads_externo_dia.url_tags), impressoes = excluded.impressoes, cliques = excluded.cliques,
         custo = excluded.custo, alcance = excluded.alcance, leads = excluded.leads, conversoes = excluded.conversoes, receita = excluded.receita, atualizado_em = now();
    elsif p_tipo = 'perfil' then
      insert into social_perfis_dia (workspace_id, conta_id, data, seguidores, seguidores_ganhos, alcance, impressoes, visualizacoes, visitas_perfil, cliques_site, minutos_assistidos)
      values (k.workspace_id, k.id, (x ->> 'data')::date, (x ->> 'seguidores')::int, (x ->> 'seguidores_ganhos')::int, (x ->> 'alcance')::int, (x ->> 'impressoes')::int,
              (x ->> 'visualizacoes')::int, (x ->> 'visitas_perfil')::int, (x ->> 'cliques_site')::int, (x ->> 'minutos_assistidos')::numeric)
      on conflict (conta_id, data) do update set
         seguidores = coalesce(excluded.seguidores, social_perfis_dia.seguidores), seguidores_ganhos = coalesce(excluded.seguidores_ganhos, social_perfis_dia.seguidores_ganhos),
         alcance = coalesce(excluded.alcance, social_perfis_dia.alcance), impressoes = coalesce(excluded.impressoes, social_perfis_dia.impressoes),
         visualizacoes = coalesce(excluded.visualizacoes, social_perfis_dia.visualizacoes), visitas_perfil = coalesce(excluded.visitas_perfil, social_perfis_dia.visitas_perfil),
         cliques_site = coalesce(excluded.cliques_site, social_perfis_dia.cliques_site), minutos_assistidos = coalesce(excluded.minutos_assistidos, social_perfis_dia.minutos_assistidos), atualizado_em = now();
    elsif p_tipo = 'posts' then
      insert into social_posts (workspace_id, conta_id, id_externo, tipo, legenda, url, miniatura, publicado_em, alcance, impressoes, visualizacoes, curtidas, comentarios, compartilhamentos, salvamentos, minutos_assistidos)
      values (k.workspace_id, k.id, x ->> 'id', x ->> 'tipo', left(x ->> 'legenda', 2000), x ->> 'url', x ->> 'miniatura', (x ->> 'publicado_em')::timestamptz,
              (x ->> 'alcance')::int, (x ->> 'impressoes')::int, (x ->> 'visualizacoes')::int, (x ->> 'curtidas')::int, (x ->> 'comentarios')::int, (x ->> 'compartilhamentos')::int,
              (x ->> 'salvamentos')::int, (x ->> 'minutos_assistidos')::numeric)
      on conflict (conta_id, id_externo) do update set tipo = excluded.tipo, legenda = excluded.legenda, url = excluded.url, miniatura = excluded.miniatura, publicado_em = excluded.publicado_em,
         alcance = coalesce(excluded.alcance, social_posts.alcance), impressoes = coalesce(excluded.impressoes, social_posts.impressoes), visualizacoes = coalesce(excluded.visualizacoes, social_posts.visualizacoes),
         curtidas = excluded.curtidas, comentarios = excluded.comentarios, compartilhamentos = coalesce(excluded.compartilhamentos, social_posts.compartilhamentos),
         salvamentos = coalesce(excluded.salvamentos, social_posts.salvamentos), minutos_assistidos = coalesce(excluded.minutos_assistidos, social_posts.minutos_assistidos), atualizado_em = now();
    elsif p_tipo = 'video' then
      f := (x ->> 'fonte_id')::uuid;
      if not exists (select 1 from fontes_video where id = f and workspace_id = k.workspace_id) then continue; end if;
      insert into video_metricas_dia (workspace_id, fonte_id, data, plays, espectadores, tempo_assistido_seg, retencao_pct, origem, disponibilidade, atualizado_na_origem)
      values (k.workspace_id, f, (x ->> 'data')::date, coalesce((x ->> 'plays')::int, 0), coalesce((x ->> 'espectadores')::int, 0), coalesce(round((x ->> 'minutos')::numeric * 60), 0)::bigint,
              least(100, greatest(0, (x ->> 'retencao_pct')::numeric)), 'integracao', 'parcial', now())
      on conflict (fonte_id, data) do update set plays = excluded.plays, espectadores = excluded.espectadores, tempo_assistido_seg = excluded.tempo_assistido_seg,
         retencao_pct = coalesce(excluded.retencao_pct, video_metricas_dia.retencao_pct), origem = 'integracao', atualizado_na_origem = now();
    else raise exception 'Tipo inválido: %', p_tipo;
    end if;
    n := n + 1;
  end loop;
  if p_tipo = 'ads' then perform ads_externo_aplicar(k.workspace_id); end if;
  return n;
end $$;

-- liga anúncio externo ao canal da campanha e grava em anuncios + metricas_anuncio_dia
create or replace function public.ads_externo_aplicar(p_ws uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare g record; cc uuid; an uuid; ut text; n int := 0; sem int := 0;
begin
  -- vínculo automático: utm_campaign do canal = nome da campanha externa, ou utm_campaign= nas url_tags
  insert into ads_externo_vinculos (workspace_id, provedor, campanha_ext, campanha_nome, campanha_canal_id)
  select distinct on (a.provedor, a.campanha_ext) a.workspace_id, a.provedor, a.campanha_ext, a.campanha_nome, c.id
    from ads_externo_dia a join campanha_canais c on c.workspace_id = a.workspace_id and c.utm_campaign is not null and c.utm_campaign <> ''
     and (lower(c.utm_campaign) = lower(a.campanha_nome) or lower(c.utm_campaign) = lower(substring(a.url_tags from 'utm_campaign=([^&]+)')))
   where a.workspace_id = p_ws
  on conflict (workspace_id, provedor, campanha_ext) do update set campanha_canal_id = coalesce(ads_externo_vinculos.campanha_canal_id, excluded.campanha_canal_id), campanha_nome = excluded.campanha_nome;
  insert into ads_externo_vinculos (workspace_id, provedor, campanha_ext, campanha_nome)
  select distinct a.workspace_id, a.provedor, a.campanha_ext, a.campanha_nome from ads_externo_dia a where a.workspace_id = p_ws
  on conflict (workspace_id, provedor, campanha_ext) do update set campanha_nome = excluded.campanha_nome;
  for g in select a.provedor, a.anuncio_ext, max(a.anuncio_nome) nome, max(a.url_tags) tags, v.campanha_canal_id cc
             from ads_externo_dia a join ads_externo_vinculos v on v.workspace_id = a.workspace_id and v.provedor = a.provedor and v.campanha_ext = a.campanha_ext
            where a.workspace_id = p_ws and v.campanha_canal_id is not null and not v.ignorar
            group by 1, 2, 5 loop
    ut := coalesce(nullif(substring(g.tags from 'utm_content=([^&]+)'), ''), nullif(g.nome, ''), g.anuncio_ext);
    select id into an from anuncios where campanha_canal_id = g.cc and (id_externo = g.anuncio_ext or lower(utm_content) = lower(ut)) order by (id_externo = g.anuncio_ext) desc limit 1;
    if an is null then
      insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, id_externo, ativo) values (p_ws, g.cc, coalesce(g.nome, g.anuncio_ext), ut, g.anuncio_ext, true)
      on conflict (campanha_canal_id, utm_content) do update set id_externo = coalesce(anuncios.id_externo, excluded.id_externo) returning id into an;
    elsif (select id_externo from anuncios where id = an) is null then
      update anuncios set id_externo = g.anuncio_ext where id = an;
    end if;
    update ads_externo_dia set anuncio_id = an where workspace_id = p_ws and provedor = g.provedor and anuncio_ext = g.anuncio_ext;
    insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, alcance, origem, disponibilidade, atualizado_na_origem)
    select p_ws, an, a.data, sum(a.impressoes), sum(a.cliques), sum(a.custo), sum(a.alcance), 'integracao', 'completo', max(a.atualizado_em)
      from ads_externo_dia a where a.workspace_id = p_ws and a.provedor = g.provedor and a.anuncio_ext = g.anuncio_ext group by a.data
    on conflict (anuncio_id, data) do update set impressoes = excluded.impressoes, cliques = excluded.cliques, custo = excluded.custo, alcance = excluded.alcance,
       origem = 'integracao', disponibilidade = 'completo', atualizado_na_origem = excluded.atualizado_na_origem;
    n := n + 1;
  end loop;
  select count(*) into sem from ads_externo_vinculos where workspace_id = p_ws and campanha_canal_id is null and not ignorar;
  return jsonb_build_object('anuncios', n, 'campanhas_sem_vinculo', sem);
end $$;

-- o navegador chama depois de ligar uma campanha externa a um canal
create or replace function public.ads_externo_religar(p_ws uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not perm(p_ws, 'editar', '{cfg,mkt}'::text[]) then raise exception 'Sem permissão'; end if;
  return ads_externo_aplicar(p_ws);
end $$;
grant execute on function public.ads_externo_religar(uuid) to authenticated;

do $$ declare f text; begin
  foreach f in array array['conexao_estado_usar(text)', 'conexao_salvar(uuid,text,uuid,text,text[],text,text,timestamptz,jsonb)', 'conexao_para_sincronizar(uuid,text)',
    'conexao_token_atualizar(uuid,text,timestamptz)', 'conexao_execucao(uuid,uuid,text,integer,text,jsonb,text)', 'conexao_gravar(uuid,text,jsonb)', 'ads_externo_aplicar(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;
