-- v0.135 — DMs do Instagram no Growths e canais na Máquina de Conteúdo.
-- 1) social_conversas e social_mensagens: as DMs do Instagram trazidas pelo Zernio (função zernio-sync). Quem escreve para a conta
--    entra no CRM pela registrar_dm_instagram (tag "DM Instagram", origem instagram_dm, cada mensagem recebida vira um toque).
--    Conversa marcada como "não é lead" para de alimentar o CRM.
-- 2) Canais por frente e por etiqueta (conteudo_temas.canais_padrao, conteudo_config.canais_por_tag) e os canais que a
--    Máquina mostra como subabas (conteudo_config.canais_ativos).
-- Pode ser rodado de novo sem erro.

create table if not exists public.social_conversas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  conta_id uuid not null references public.conexao_contas(id) on delete cascade,
  rede text not null default 'instagram',
  id_externo text not null,
  participante_id text,
  participante_nome text,
  participante_usuario text,
  url text,
  ultima_mensagem text,
  ultima_em timestamptz,
  nao_lidas int not null default 0,
  primeira_em timestamptz,
  mensagens int not null default 0,
  recebidas int not null default 0,
  enviadas int not null default 0,
  anuncio jsonb,
  pessoa_id uuid references public.pessoas(id) on delete set null,
  ignorada boolean not null default false,
  sincronizado_em timestamptz not null default now(),
  unique (conta_id, id_externo)
);
create index if not exists social_conversas_ws on public.social_conversas (workspace_id, ultima_em desc);

create table if not exists public.social_mensagens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  conversa_id uuid not null references public.social_conversas(id) on delete cascade,
  id_externo text not null,
  direcao text not null check (direcao in ('recebida', 'enviada')),
  texto text,
  anexos int not null default 0,
  em timestamptz not null,
  unique (conversa_id, id_externo)
);
create index if not exists social_mensagens_conv on public.social_mensagens (conversa_id, em);

alter table public.social_conversas enable row level security;
alter table public.social_mensagens enable row level security;
drop policy if exists ler on public.social_conversas;
create policy ler on public.social_conversas for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{mkt,vendas,adm}'::text[]));
drop policy if exists marcar on public.social_conversas;
create policy marcar on public.social_conversas for update to authenticated
  using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'editar', '{mkt,vendas}'::text[]))
  with check (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'editar', '{mkt,vendas}'::text[]));
drop policy if exists ler on public.social_mensagens;
create policy ler on public.social_mensagens for select to authenticated using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'ler', '{mkt,vendas,adm}'::text[]));
grant select on public.social_conversas, public.social_mensagens to authenticated;
grant update (ignorada) on public.social_conversas to authenticated;
revoke all on public.social_conversas, public.social_mensagens from anon;

-- ---------- gravar as DMs (chamada só pela função zernio-sync, com a chave de serviço) ----------
-- p_conversas: [{"id","participante_id","nome","usuario","url","ultima_mensagem","ultima_em","nao_lidas","anuncio",
--               "mensagens":[{"id","direcao":"recebida|enviada","texto","anexos","em"}]}]
create or replace function public.social_gravar_dms(p_conta uuid, p_conversas jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare ws uuid; cv jsonb; m jsonb; cid uuid; ign boolean; pes uuid; n_conv int := 0; n_msg int := 0; n_lead int := 0; novo boolean;
begin
  select workspace_id into ws from conexao_contas where id = p_conta;
  if ws is null then raise exception 'Conta não encontrada'; end if;
  for cv in select * from jsonb_array_elements(coalesce(p_conversas, '[]')) loop
    continue when coalesce(cv ->> 'id', '') = '';
    insert into social_conversas (workspace_id, conta_id, id_externo, participante_id, participante_nome, participante_usuario, url, ultima_mensagem, ultima_em, nao_lidas, anuncio, sincronizado_em)
    values (ws, p_conta, cv ->> 'id', cv ->> 'participante_id', nullif(cv ->> 'nome', ''), nullif(cv ->> 'usuario', ''), cv ->> 'url',
            left(cv ->> 'ultima_mensagem', 500), (cv ->> 'ultima_em')::timestamptz, coalesce((cv ->> 'nao_lidas')::int, 0), nullif(cv -> 'anuncio', 'null'::jsonb), now())
    on conflict (conta_id, id_externo) do update set participante_id = coalesce(excluded.participante_id, social_conversas.participante_id),
      participante_nome = coalesce(excluded.participante_nome, social_conversas.participante_nome), participante_usuario = coalesce(excluded.participante_usuario, social_conversas.participante_usuario),
      url = coalesce(excluded.url, social_conversas.url), ultima_mensagem = excluded.ultima_mensagem, ultima_em = excluded.ultima_em, nao_lidas = excluded.nao_lidas,
      anuncio = coalesce(excluded.anuncio, social_conversas.anuncio), sincronizado_em = now()
    returning id, ignorada into cid, ign;
    n_conv := n_conv + 1;
    for m in select * from jsonb_array_elements(coalesce(cv -> 'mensagens', '[]')) order by (value ->> 'em') loop
      continue when coalesce(m ->> 'id', '') = '' or (m ->> 'em') is null;
      insert into social_mensagens (workspace_id, conversa_id, id_externo, direcao, texto, anexos, em)
      values (ws, cid, m ->> 'id', case when m ->> 'direcao' = 'enviada' then 'enviada' else 'recebida' end, left(m ->> 'texto', 4000), coalesce((m ->> 'anexos')::int, 0), (m ->> 'em')::timestamptz)
      on conflict (conversa_id, id_externo) do nothing;
      if found then n_msg := n_msg + 1; end if;
      -- quem escreveu para a conta entra no CRM (uma vez por pessoa; cada mensagem recebida vira um toque)
      if not ign and m ->> 'direcao' <> 'enviada' and coalesce(cv ->> 'participante_id', '') <> '' then
        novo := not exists (select 1 from pessoas where workspace_id = ws and extras ->> 'instagram_id' = cv ->> 'participante_id');
        pes := registrar_dm_instagram(ws, cv ->> 'participante_id', m ->> 'id', m ->> 'texto', nullif(cv ->> 'usuario', ''), nullif(cv ->> 'nome', ''), (m ->> 'em')::timestamptz);
        if novo then n_lead := n_lead + 1; end if;
        update social_conversas set pessoa_id = pes where id = cid and pessoa_id is distinct from pes;
      end if;
    end loop;
    update social_conversas c set mensagens = x.n, recebidas = x.r, enviadas = x.e, primeira_em = x.p
    from (select count(*) n, count(*) filter (where direcao = 'recebida') r, count(*) filter (where direcao = 'enviada') e, min(em) p from social_mensagens where conversa_id = cid) x
    where c.id = cid;
  end loop;
  return jsonb_build_object('conversas', n_conv, 'mensagens', n_msg, 'leads_novos', n_lead);
end $$;
revoke all on function public.social_gravar_dms(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.social_gravar_dms(uuid, jsonb) to service_role;

-- para o zernio-sync saber o que já tem e buscar só as conversas que mudaram
create or replace function public.social_conversas_conhecidas(p_conta uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(id_externo, ultima_em), '{}'::jsonb) from social_conversas where conta_id = p_conta;
$$;
revoke all on function public.social_conversas_conhecidas(uuid) from public, anon, authenticated;
grant execute on function public.social_conversas_conhecidas(uuid) to service_role;

-- ---------- números das DMs para a aba do Instagram ----------
create or replace function public.instagram_dms_resumo(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t0 timestamptz := p_ini::timestamp at time zone 'America/Sao_Paulo'; t1 timestamptz := (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo';
begin
  if auth.uid() is not null and not perm(p_ws, 'ler', array['mkt', 'vendas', 'adm']) then raise exception 'Sem acesso a este cliente'; end if;
  return jsonb_build_object(
    'conversas_ativas', (select count(distinct m.conversa_id) from social_mensagens m where m.workspace_id = p_ws and m.em >= t0 and m.em < t1),
    'conversas_novas', (select count(*) from social_conversas c where c.workspace_id = p_ws and c.primeira_em >= t0 and c.primeira_em < t1),
    'recebidas', (select count(*) from social_mensagens m where m.workspace_id = p_ws and m.direcao = 'recebida' and m.em >= t0 and m.em < t1),
    'enviadas', (select count(*) from social_mensagens m where m.workspace_id = p_ws and m.direcao = 'enviada' and m.em >= t0 and m.em < t1),
    'leads_novos', (select count(*) from pessoas p where p.workspace_id = p_ws and p.canal_origem = 'instagram_dm' and p.criado_em >= t0 and p.criado_em < t1),
    'clientes', (select count(*) from pessoas p where p.workspace_id = p_ws and p.canal_origem = 'instagram_dm' and p.status_funil = 'cliente'),
    'sem_resposta', (select count(*) from social_conversas c where c.workspace_id = p_ws and not c.ignorada
                     and (select direcao from social_mensagens m where m.conversa_id = c.id order by em desc limit 1) = 'recebida'),
    'ultima_sincronizacao', (select max(sincronizado_em) from social_conversas where workspace_id = p_ws));
end $$;
revoke execute on function public.instagram_dms_resumo(uuid, date, date) from public, anon;
grant execute on function public.instagram_dms_resumo(uuid, date, date) to authenticated;

-- ---------- canais na Máquina de Conteúdo ----------
alter table public.conteudo_temas add column if not exists canais_padrao text[] not null default '{}';
alter table public.conteudo_temas drop constraint if exists conteudo_temas_canais_padrao_check;
alter table public.conteudo_temas add constraint conteudo_temas_canais_padrao_check check (canais_padrao <@ array['instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email']::text[]);
alter table public.conteudo_config add column if not exists canais_por_tag jsonb not null default '{}'::jsonb;
alter table public.conteudo_config add column if not exists canais_ativos text[] not null default array['instagram'];
alter table public.conteudo_config drop constraint if exists conteudo_config_canais_ativos_check;
alter table public.conteudo_config add constraint conteudo_config_canais_ativos_check check (canais_ativos <@ array['instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email']::text[]);

notify pgrst, 'reload schema';
