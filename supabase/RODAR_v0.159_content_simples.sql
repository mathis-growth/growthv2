-- v0.159 — Growth's Content simplificado: o dossiê pronto vira a ficha do cliente, identidade visual por cliente,
-- roteiro e peça com aprovação e versões. Só a estrutura: as chamadas à Claude entram quando a API tiver crédito.
-- Arquivos (PDF do dossiê, artes, vídeos) ficam na pasta do cliente no Drive; aqui só os links e o texto.
-- Pode ser rodado de novo sem erro.

-- 1. Ficha do cliente (tirada do dossiê), com versões. Só uma versão aprovada vale por vez: a mais nova aprovada.
create table if not exists public.content_fichas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  versao int not null check (versao >= 1),
  status text not null default 'rascunho' check (status in ('rascunho', 'aprovada')),
  dossie_url text check (dossie_url is null or length(dossie_url) <= 1000),
  secoes jsonb not null default '{}'::jsonb check (jsonb_typeof(secoes) = 'object'),
  aprovado_por text,
  aprovado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, versao),
  check (status <> 'aprovada' or (aprovado_por is not null and aprovado_em is not null))
);

-- 2. Identidade visual do cliente (uma por cliente)
create table if not exists public.content_identidade (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  cores jsonb not null default '[]'::jsonb check (jsonb_typeof(cores) = 'array'),   -- [{nome, hex, papel}]
  fonte_titulo text check (fonte_titulo is null or length(fonte_titulo) <= 120),
  fonte_texto text check (fonte_texto is null or length(fonte_texto) <= 120),
  pasta_url text check (pasta_url is null or length(pasta_url) <= 1000),
  referencias text check (referencias is null or length(referencias) <= 8000),        -- um link por linha
  nunca_fazer text check (nunca_fazer is null or length(nunca_fazer) <= 4000),
  formatos text[] not null default array['feed', 'carrossel', 'story'],
  aprovado_por text,
  aprovado_em timestamptz,
  atualizado_em timestamptz not null default now()
);

-- 3. Roteiro e peça dentro do conteúdo
alter table public.conteudos add column if not exists roteiro text;
alter table public.conteudos add column if not exists roteiro_aprovado_por text;
alter table public.conteudos add column if not exists roteiro_aprovado_em timestamptz;
alter table public.conteudos add column if not exists peca_aprovada_por text;
alter table public.conteudos add column if not exists peca_aprovada_em timestamptz;
alter table public.conteudos add column if not exists video_bruto_url text;

-- 4. Versões da peça e pedidos de ajuste (arte, capa, vídeo). O arquivo fica no Drive; aqui o link e o pedido.
create table if not exists public.content_versoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  conteudo_id uuid not null references public.conteudos(id) on delete cascade,
  n int not null check (n >= 1),
  tipo text not null check (tipo in ('arte', 'capa', 'video')),
  arquivo_url text check (arquivo_url is null or length(arquivo_url) <= 1000),
  nota text check (nota is null or length(nota) <= 2000),
  ajuste text check (ajuste is null or length(ajuste) <= 2000),          -- o ajuste pedido sobre esta versão
  status text not null default 'nova' check (status in ('nova', 'ajuste_pedido', 'aprovada', 'substituida')),
  criado_por text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (conteudo_id, tipo, n)
);
create index if not exists content_versoes_conteudo on public.content_versoes (conteudo_id);

-- acesso: vê quem é do cliente (ou a equipe interna); grava quem configura o Growth's Content
do $$ declare t text; begin
  foreach t in array array['content_fichas', 'content_identidade', 'content_versoes'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna())', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_gravar', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (content_pode_configurar(workspace_id))', t || '_gravar', t);
    execute format('drop policy if exists %I on public.%I', t || '_alterar', t);
    execute format('create policy %I on public.%I for update to authenticated using (content_pode_configurar(workspace_id)) with check (content_pode_configurar(workspace_id))', t || '_alterar', t);
    execute format('drop policy if exists %I on public.%I', t || '_excluir', t);
    execute format('create policy %I on public.%I for delete to authenticated using (content_pode_configurar(workspace_id))', t || '_excluir', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;
create index if not exists content_fichas_ws on public.content_fichas (workspace_id, versao desc);


-- 5. O fluxo novo vira o padrão: método "simples" (sem as notas da ideia e da pauta; o roteiro e a peça aprovados é que liberam as etapas).
--    Em 26/10/2026 a produção tinha 1 configuração (score6) e nenhum conteúdo. As regras de notas continuam para quem escolher notas5 ou score6.
alter table public.conteudo_config drop constraint if exists conteudo_config_metodo_check;
alter table public.conteudo_config add constraint conteudo_config_metodo_check check (metodo = any (array['simples', 'notas5', 'score6']));
alter table public.conteudo_config alter column metodo set default 'simples';
update public.conteudo_config set metodo = 'simples' where metodo is distinct from 'simples';
CREATE OR REPLACE FUNCTION public.conteudo_valida()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pos int; tem_ideia boolean; tem_pauta boolean; met text; dests text[]; tem_formatos boolean;
begin
  if new.tema_id is not null and not exists (select 1 from conteudo_temas where id = new.tema_id and workspace_id = new.workspace_id) then
    raise exception 'O tema precisa pertencer ao mesmo workspace'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  if new.formato_id is not null and not exists (select 1 from conteudo_formatos where id = new.formato_id and workspace_id = new.workspace_id and grupo = 'formato') then
    raise exception 'O formato precisa ser um formato deste workspace'; end if;
  if new.quadro_id is not null and not exists (select 1 from conteudo_formatos where id = new.quadro_id and workspace_id = new.workspace_id and grupo = 'quadro') then
    raise exception 'O quadro de autoridade precisa ser deste workspace'; end if;
  select coalesce(c.metodo, 'simples'), coalesce(c.destinos, '{}') into met, dests from conteudo_config c where c.workspace_id = new.workspace_id;
  met := coalesce(met, 'simples'); dests := coalesce(dests, '{}');
  new.destino := nullif(trim(coalesce(new.destino, '')), '');
  if new.destino is not null and cardinality(dests) > 0 and not (lower(new.destino) = any (select lower(x) from unnest(dests) x)) then
    raise exception 'Destino "%" não está entre os destinos cadastrados (%)', new.destino, array_to_string(dests, ', '); end if;
  if new.destino is not null and cardinality(dests) > 0 then select x into new.destino from unnest(dests) x where lower(x) = lower(new.destino) limit 1; end if;
  new.palavra_chave := nullif(trim(coalesce(new.palavra_chave, '')), '');
  new.tags := coalesce((select array_agg(distinct trim(x)) from unnest(new.tags) x where trim(x) <> ''), '{}');
  if new.validado and (tg_op = 'INSERT' or not old.validado) then new.validado_em := coalesce(new.validado_em, now()); end if;
  if not new.validado then new.validado_em := null; end if;
  pos := array_position(array['ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado'], new.status);
  if pos is not null then
    if met = 'simples' then
      -- v0.159: o fluxo novo do Growth's Content (roteiro aprovado antes da peça; peça aprovada antes de ficar pronta)
      if pos >= 3 and new.roteiro_aprovado_em is null then raise exception 'Aprove o roteiro antes de produzir a peça'; end if;
      if pos >= 4 and new.peca_aprovada_em is null then raise exception 'Aprove a peça antes de marcar como pronta'; end if;
    elsif met = 'score6' then
      tem_formatos := exists (select 1 from conteudo_formatos where workspace_id = new.workspace_id and grupo = 'formato' and ativo);
      if pos >= 2 and num_nonnulls(new.s1, new.s2, new.s3, new.s4, new.s5, new.s6) < 6 then raise exception 'Dê as 6 notas (1 a 5) do score antes de aprovar a pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o território e a frente antes de aprovar a pauta'; end if;
      if pos >= 2 and cardinality(dests) > 0 and new.destino is null then raise exception 'Escolha o destino (%) antes de aprovar a pauta', array_to_string(dests, ', '); end if;
      if pos >= 2 and tem_formatos and new.formato_id is null then raise exception 'Escolha o formato antes de aprovar a pauta'; end if;
      if pos >= 3 and not new.validado then raise exception 'Marque VALIDAR antes de produzir: a escolha é sua, não do ranking'; end if;
    else
      tem_ideia := num_nonnulls(new.ideia_n1, new.ideia_n2, new.ideia_n3, new.ideia_n4, new.ideia_n5) = 5;
      tem_pauta := num_nonnulls(new.pauta_n1, new.pauta_n2, new.pauta_n3, new.pauta_n4, new.pauta_n5) = 5;
      if pos >= 2 and not tem_ideia then raise exception 'Dê as 5 notas da ideia antes de aprová-la como pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o tema antes de aprovar a pauta'; end if;
      if pos >= 3 and not tem_pauta then raise exception 'Dê as 5 notas da pauta antes de produzir'; end if;
    end if;
    if met <> 'simples' and pos >= 3 and cardinality(new.canais) = 0 then raise exception 'Marque pelo menos um canal antes de produzir'; end if;
    if met <> 'simples' and pos >= 4 and (new.copy_url is null or new.midia_url is null) then raise exception 'Informe o link da copy e o link da mídia para marcar como pronto'; end if;
    if pos >= 5 and new.data_publicacao is null then raise exception 'Informe a data de publicação para agendar'; end if;
  end if;
  if new.data_publicacao is not null and new.dia_semana is null then new.dia_semana := extract(isodow from new.data_publicacao)::smallint; end if;
  if new.status = 'publicado' then new.publicado_em := coalesce(new.publicado_em, now()); else new.publicado_em := null; end if;
  new.atualizado_em := now();
  return new;
end $function$;

notify pgrst, 'reload schema';
