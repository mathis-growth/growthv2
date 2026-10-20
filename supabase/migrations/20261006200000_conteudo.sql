-- Planejamento de conteúdo (dentro de Marketing): linhas editoriais, temas com prioridade,
-- Kanban de ideias a publicado com 5 notas, meta semanal por formato, publicações por canal e métricas.

create table conteudo_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  criterios text[] not null default array['Aderência à linha editorial', 'Potencial de alcance', 'Potencial de conversão', 'Facilidade de produção', 'Oportunidade e timing']
    check (cardinality(criterios) = 5)
);

create table conteudo_linhas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  descricao text,
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table conteudo_temas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  linha_id uuid references conteudo_linhas(id) on delete set null,
  nome text not null,
  prioridade int not null default 2 check (prioridade between 1 and 3),   -- 1 alta, 2 média, 3 baixa
  cor text not null default '#0a6b5b' check (cor ~ '^#[0-9a-fA-F]{6}$'),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index conteudo_temas_nome_uq on conteudo_temas (workspace_id, lower(nome));

create table conteudo_metas_semanais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  formato text not null check (formato in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live')),
  quantidade int not null check (quantidade >= 0),
  unique (workspace_id, formato)
);

create table conteudos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  titulo text not null,
  descricao text,
  tema_id uuid references conteudo_temas(id) on delete set null,
  formato text not null default 'carrossel' check (formato in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live')),
  canais text[] not null default '{}' check (canais <@ array['instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email']::text[]),
  status text not null default 'ideia' check (status in ('ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado', 'arquivado')),
  origem text not null default 'manual' check (origem in ('manual', 'ia', 'importada')),
  fonte_url text check (fonte_url is null or fonte_url ~* '^https?://'),
  copy_url text check (copy_url is null or copy_url ~* '^https?://'),
  midia_url text check (midia_url is null or midia_url ~* '^https?://'),
  responsavel_id uuid references equipe(id) on delete set null,
  prazo date,
  data_publicacao date,
  publicado_em timestamptz,
  ideia_n1 int check (ideia_n1 between 1 and 10), ideia_n2 int check (ideia_n2 between 1 and 10), ideia_n3 int check (ideia_n3 between 1 and 10),
  ideia_n4 int check (ideia_n4 between 1 and 10), ideia_n5 int check (ideia_n5 between 1 and 10),
  pauta_n1 int check (pauta_n1 between 1 and 10), pauta_n2 int check (pauta_n2 between 1 and 10), pauta_n3 int check (pauta_n3 between 1 and 10),
  pauta_n4 int check (pauta_n4 between 1 and 10), pauta_n5 int check (pauta_n5 between 1 and 10),
  ideia_media numeric(3, 1) generated always as (case when ideia_n1 is not null and ideia_n2 is not null and ideia_n3 is not null and ideia_n4 is not null and ideia_n5 is not null
    then round((ideia_n1 + ideia_n2 + ideia_n3 + ideia_n4 + ideia_n5) / 5.0, 1) end) stored,
  pauta_media numeric(3, 1) generated always as (case when pauta_n1 is not null and pauta_n2 is not null and pauta_n3 is not null and pauta_n4 is not null and pauta_n5 is not null
    then round((pauta_n1 + pauta_n2 + pauta_n3 + pauta_n4 + pauta_n5) / 5.0, 1) end) stored,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index conteudos_ws on conteudos (workspace_id, status);
create index conteudos_pub on conteudos (workspace_id, data_publicacao);

create table conteudo_publicacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  conteudo_id uuid not null references conteudos(id) on delete cascade,
  canal text not null check (canal in ('instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email')),
  data_publicacao date,
  url text check (url is null or url ~* '^https?://'),
  status text not null default 'agendada' check (status in ('agendada', 'publicada')),
  impressoes int check (impressoes >= 0), alcance int check (alcance >= 0), visualizacoes int check (visualizacoes >= 0),
  curtidas int check (curtidas >= 0), comentarios int check (comentarios >= 0), compartilhamentos int check (compartilhamentos >= 0),
  salvamentos int check (salvamentos >= 0), cliques int check (cliques >= 0), seguidores_ganhos int,
  metricas_em date,
  criado_em timestamptz not null default now(),
  unique (conteudo_id, canal)
);
create index conteudo_publicacoes_ws on conteudo_publicacoes (workspace_id, data_publicacao);

create table conteudo_conta_dia (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  canal text not null check (canal in ('instagram', 'linkedin', 'youtube', 'tiktok', 'facebook', 'x', 'blog', 'email')),
  data date not null,
  seguidores int check (seguidores >= 0), alcance int check (alcance >= 0), impressoes int check (impressoes >= 0),
  visitas_perfil int check (visitas_perfil >= 0), cliques_link int check (cliques_link >= 0),
  unique (workspace_id, canal, data)
);

-- Regras do Kanban: cada etapa exige o que ela precisa para andar.
create function conteudo_valida() returns trigger
language plpgsql security definer set search_path = public as $$
declare pos int; tem_ideia boolean; tem_pauta boolean;
begin
  if new.tema_id is not null and not exists (select 1 from conteudo_temas where id = new.tema_id and workspace_id = new.workspace_id) then
    raise exception 'O tema precisa pertencer ao mesmo workspace'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  -- colunas geradas só existem depois do gatilho BEFORE: valida pelas 5 notas, não pela média
  tem_ideia := num_nonnulls(new.ideia_n1, new.ideia_n2, new.ideia_n3, new.ideia_n4, new.ideia_n5) = 5;
  tem_pauta := num_nonnulls(new.pauta_n1, new.pauta_n2, new.pauta_n3, new.pauta_n4, new.pauta_n5) = 5;
  pos := array_position(array['ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado'], new.status);
  if pos is not null then
    if pos >= 2 and not tem_ideia then raise exception 'Dê as 5 notas da ideia antes de aprová-la como pauta'; end if;
    if pos >= 2 and new.tema_id is null then raise exception 'Escolha o tema antes de aprovar a pauta'; end if;
    if pos >= 3 and not tem_pauta then raise exception 'Dê as 5 notas da pauta antes de produzir'; end if;
    if pos >= 3 and cardinality(new.canais) = 0 then raise exception 'Marque pelo menos um canal antes de produzir'; end if;
    if pos >= 4 and (new.copy_url is null or new.midia_url is null) then raise exception 'Informe o link da copy e o link da mídia para marcar como pronto'; end if;
    if pos >= 5 and new.data_publicacao is null then raise exception 'Informe a data de publicação para agendar'; end if;
  end if;
  if new.status = 'publicado' then new.publicado_em := coalesce(new.publicado_em, now()); else new.publicado_em := null; end if;
  new.atualizado_em := now();
  return new;
end $$;
create trigger conteudo_valida_t before insert or update on conteudos for each row execute function conteudo_valida();

create function conteudo_pub_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from conteudos where id = new.conteudo_id and workspace_id = new.workspace_id) then
    raise exception 'O conteúdo precisa pertencer ao mesmo workspace'; end if;
  return new;
end $$;
create trigger conteudo_pub_valida_t before insert or update on conteudo_publicacoes for each row execute function conteudo_pub_valida();
revoke execute on function conteudo_valida(), conteudo_pub_valida() from public, anon, authenticated;

-- Entrada de ideias em lote (pesquisa diária por IA ou colagem na tela). Ignora título repetido.
-- Cada item: {"titulo": "...", "descricao": "...", "tema": "nome do tema", "formato": "carrossel", "fonte_url": "https://..."}
create function conteudo_importar_ideias(p_ws uuid, p_itens jsonb, p_origem text default 'ia') returns int
language plpgsql security definer set search_path = public as $$
declare it jsonb; n int := 0; t uuid; f text;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if p_origem not in ('ia', 'importada') then raise exception 'Origem inválida'; end if;
  for it in select * from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) loop
    continue when coalesce(trim(it ->> 'titulo'), '') = '';
    continue when exists (select 1 from conteudos where workspace_id = p_ws and lower(titulo) = lower(trim(it ->> 'titulo')));
    select id into t from conteudo_temas where workspace_id = p_ws and lower(nome) = lower(trim(coalesce(it ->> 'tema', '')));
    f := lower(trim(coalesce(it ->> 'formato', '')));
    if f not in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live') then f := 'carrossel'; end if;
    insert into conteudos (workspace_id, titulo, descricao, tema_id, formato, origem, fonte_url)
    values (p_ws, trim(it ->> 'titulo'), nullif(trim(coalesce(it ->> 'descricao', '')), ''), t, f, p_origem,
            case when (it ->> 'fonte_url') ~* '^https?://' then it ->> 'fonte_url' end);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function conteudo_importar_ideias(uuid, jsonb, text) from public, anon;
grant execute on function conteudo_importar_ideias(uuid, jsonb, text) to authenticated;

alter table conteudo_config enable row level security;
alter table conteudo_linhas enable row level security;
alter table conteudo_temas enable row level security;
alter table conteudo_metas_semanais enable row level security;
alter table conteudos enable row level security;
alter table conteudo_publicacoes enable row level security;
alter table conteudo_conta_dia enable row level security;
create policy conteudo_config_acesso on conteudo_config for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudo_linhas_acesso on conteudo_linhas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudo_temas_acesso on conteudo_temas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudo_metas_semanais_acesso on conteudo_metas_semanais for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudos_acesso on conteudos for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudo_publicacoes_acesso on conteudo_publicacoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy conteudo_conta_dia_acesso on conteudo_conta_dia for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
