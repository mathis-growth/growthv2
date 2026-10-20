-- Growths v0.109 — Ideias de conteúdo pelo ChatGPT: chaves e funções. Só esta atualização (o banco já tem até a v0.107).
-- Como usar: Supabase → SQL Editor → New query → cole este arquivo inteiro → Run. Pode rodar de novo sem problema.
-- A edge function "ideias" já foi publicada no projeto; ela só passa a funcionar depois deste arquivo.

begin;
-- v0.109 — Ideias de conteúdo pelo ChatGPT (ou qualquer IA que chame um endereço com chave)
-- 1. chaves_api: chaves pessoais para uma IA gravar ideias no Planejamento de conteúdo de UM workspace.
--    Só o hash (sha256) fica no banco; a chave aparece uma vez, na hora de gerar. Dá para revogar.
-- 2. chave_api_criar(ws, nome) → devolve a chave (só nesta hora). chave_api_revogar(id).
--    Quem pode: quem edita o módulo de Marketing do workspace.
-- 3. ideia_por_chave(chave, titulo, descricao, formato, tema, canais) → cria o conteúdo na etapa "ideia", origem "ia".
--    ideias_por_chave_contexto(chave) → temas, formatos, canais e as últimas ideias (para a IA sugerir tema e não repetir).
--    As duas rodam sem login (a chave é a senha) e só tocam no workspace da chave. A edge function "ideias" chama estas funções.
-- Rode DEPOIS de 20261012200000_cenarios_ciclo.sql. Idempotente.

create table if not exists chaves_api (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 80),
  escopo text not null default 'ideias' check (escopo in ('ideias')),
  prefixo text not null,
  hash text not null unique,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  ultimo_uso timestamptz,
  usos integer not null default 0,
  revogada_em timestamptz
);
create index if not exists chaves_api_ws on chaves_api (workspace_id);
alter table chaves_api enable row level security;
drop policy if exists chaves_api_ler on chaves_api;
create policy chaves_api_ler on chaves_api for select to authenticated using (perm(workspace_id, 'editar', '{mkt}'::text[]));
-- escrita só pelas funções abaixo (sem política de insert/update/delete)
revoke insert, update, delete on chaves_api from anon, authenticated;

create or replace function public.chave_api_hash(p text) returns text language sql immutable set search_path = public as $$
  select encode(sha256(convert_to(coalesce(p, ''), 'UTF8')), 'hex');
$$;

create or replace function public.chave_api_criar(p_ws uuid, p_nome text) returns text
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if auth.uid() is null or not perm(p_ws, 'editar', '{mkt}'::text[]) then raise exception 'Só quem edita o Marketing deste workspace pode gerar chave'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome para a chave (ex.: ChatGPT do celular)'; end if;
  k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into chaves_api (workspace_id, nome, prefixo, hash) values (p_ws, trim(p_nome), left(k, 9), chave_api_hash(k));
  return k;
end $$;

create or replace function public.chave_api_revogar(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  select workspace_id into w from chaves_api where id = p_id;
  if w is null then raise exception 'Chave não encontrada'; end if;
  if auth.uid() is null or not perm(w, 'editar', '{mkt}'::text[]) then raise exception 'Só quem edita o Marketing deste workspace pode revogar a chave'; end if;
  update chaves_api set revogada_em = coalesce(revogada_em, now()) where id = p_id;
end $$;

-- acha a chave ativa e conta o uso; erro genérico para não dizer se a chave existe
create or replace function public.chave_api_ws(p_chave text) returns uuid
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  update chaves_api set ultimo_uso = now(), usos = usos + 1
   where hash = chave_api_hash(p_chave) and revogada_em is null and escopo = 'ideias'
  returning workspace_id into w;
  if w is null then raise exception 'Chave inválida ou revogada' using errcode = '28000'; end if;
  return w;
end $$;

create or replace function public.ideia_por_chave(p_chave text, p_titulo text, p_descricao text default null, p_formato text default null, p_tema text default null, p_canais text[] default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare w uuid; t uuid; f text; c text[]; novo conteudos%rowtype; tnome text;
begin
  w := chave_api_ws(p_chave);
  if coalesce(trim(p_titulo), '') = '' then raise exception 'A ideia precisa de um título'; end if;
  f := lower(trim(coalesce(p_formato, '')));
  f := case f when 'reel' then 'reels' when 'vídeo' then 'video' when 'post' then 'imagem' when 'stories' then 'story' when '' then 'carrossel' else f end;
  if f not in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live') then f := 'carrossel'; end if;
  if p_tema is not null and trim(p_tema) <> '' then
    select id, nome into t, tnome from conteudo_temas where workspace_id = w and coalesce(ativo, true)
      and lower(nome) = lower(trim(p_tema)) limit 1;
    if t is null then select id, nome into t, tnome from conteudo_temas where workspace_id = w and coalesce(ativo, true)
      and lower(nome) like '%' || lower(trim(p_tema)) || '%' order by prioridade nulls last limit 1; end if;
  end if;
  select coalesce(array_agg(distinct lower(trim(x))), '{}') into c from unnest(coalesce(p_canais, '{}'::text[])) x
   where lower(trim(x)) in ('instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email');
  insert into conteudos (workspace_id, titulo, descricao, formato, tema_id, canais, status, origem)
  values (w, left(trim(p_titulo), 200), nullif(trim(coalesce(p_descricao, '')), ''), f, t, c, 'ideia', 'ia')
  returning * into novo;
  return jsonb_build_object('ok', true, 'id', novo.id, 'titulo', novo.titulo, 'formato', novo.formato, 'tema', tnome, 'canais', novo.canais,
    'mensagem', 'Ideia guardada no Planejamento de conteúdo, na etapa Ideia.');
end $$;

create or replace function public.ideias_por_chave_contexto(p_chave text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  w := chave_api_ws(p_chave);
  return jsonb_build_object(
    'workspace', (select nome from workspaces where id = w),
    'temas', coalesce((select jsonb_agg(nome order by prioridade nulls last, nome) from conteudo_temas where workspace_id = w and coalesce(ativo, true)), '[]'),
    'formatos', '["carrossel","reels","video","imagem","story","artigo","newsletter","live"]'::jsonb,
    'canais', '["instagram","linkedin","youtube","tiktok","facebook","x","blog","email"]'::jsonb,
    'ultimas_ideias', coalesce((select jsonb_agg(jsonb_build_object('titulo', titulo, 'status', status, 'criado_em', criado_em::date) order by criado_em desc)
      from (select titulo, status, criado_em from conteudos where workspace_id = w order by criado_em desc limit 15) z), '[]'));
end $$;

revoke execute on function public.chave_api_criar(uuid, text) from public, anon;
grant execute on function public.chave_api_criar(uuid, text) to authenticated;
revoke execute on function public.chave_api_revogar(uuid) from public, anon;
grant execute on function public.chave_api_revogar(uuid) to authenticated;
revoke execute on function public.chave_api_ws(text) from public, anon, authenticated;
grant execute on function public.ideia_por_chave(text, text, text, text, text, text[]) to anon, authenticated;
grant execute on function public.ideias_por_chave_contexto(text) to anon, authenticated;

commit;

-- Conferência: deve listar a tabela chaves_api e as 4 funções.
select 'tabela' tipo, tablename nome from pg_tables where schemaname = 'public' and tablename = 'chaves_api'
union all select 'função', proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and proname in ('chave_api_criar', 'chave_api_revogar', 'ideia_por_chave', 'ideias_por_chave_contexto');
