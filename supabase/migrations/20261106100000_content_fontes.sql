-- v0.145 — Growth's Content: o cliente informa os canais dele e entrega os materiais antes da call.
-- 1) workspaces.content_fontes (jsonb): canais (@ ou endereço de cada plataforma), "não tenho conteúdo publicado",
--    situação de cada tipo de material (pronto / não tenho) e links de outros Drives.
-- 2) A árvore padrão ganha subpastas em "02 Materiais do cliente" (Documentos, Reuniões gravadas, Aulas e cursos, Depoimentos e provas).
-- 3) Quando todos os materiais estão resolvidos, o marco "materiais" é marcado sozinho (e desmarcado se algum for reaberto).
-- Pode ser rodado de novo sem erro.

alter table public.workspaces add column if not exists content_fontes jsonb not null default '{}'::jsonb;

-- árvore: só troca se ainda for a padrão da v0.144 (ou vazia)
update public.sistema_config set valor =
  '["01 Briefing", "02 Materiais do cliente/Documentos", "02 Materiais do cliente/Reuniões gravadas", "02 Materiais do cliente/Aulas e cursos", "02 Materiais do cliente/Depoimentos e provas", "03 Identidade visual", "04 Referências de conteúdo", "05 Pesquisa de mercado", "06 Dossiê da marca", "07 Skill do cliente", "08 Produção/Roteiros", "08 Produção/Gravações", "08 Produção/Edição", "08 Produção/Artes", "09 Publicados", "10 Resultados"]'
where chave = 'content_drive_arvore' and valor in ('', '[]',
  '["01 Briefing", "02 Materiais do cliente", "03 Identidade visual", "04 Referências de conteúdo", "05 Pesquisa de mercado", "06 Dossiê da marca", "07 Skill do cliente", "08 Produção/Roteiros", "08 Produção/Gravações", "08 Produção/Edição", "08 Produção/Artes", "09 Publicados", "10 Resultados"]');

-- canais do cliente e links de outros Drives
create or replace function public.content_fontes_salvar(p_ws uuid, p_canais jsonb, p_sem_canais boolean, p_links jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k text; v text; c jsonb := '{}'::jsonb; l jsonb := '[]'::jsonb; x jsonb; r jsonb;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  if p_canais is not null then
    if jsonb_typeof(p_canais) <> 'object' then raise exception 'Canais inválidos'; end if;
    for k, v in select key, trim(coalesce(value #>> '{}', '')) from jsonb_each(p_canais) loop
      if k not in ('instagram', 'youtube', 'tiktok', 'linkedin', 'threads', 'facebook', 'site', 'podcast', 'outro') then raise exception 'Plataforma desconhecida: %', k; end if;
      if length(v) > 300 then raise exception 'Endereço longo demais em %', k; end if;
      if v <> '' then c := c || jsonb_build_object(k, v); end if;
    end loop;
  end if;
  if p_links is not null then
    if jsonb_typeof(p_links) <> 'array' or jsonb_array_length(p_links) > 30 then raise exception 'Links inválidos (no máximo 30)'; end if;
    for x in select value from jsonb_array_elements(p_links) loop
      if trim(coalesce(x->>'url', '')) !~* '^https?://\S+$' then raise exception 'Link inválido: %', coalesce(x->>'url', ''); end if;
      l := l || jsonb_build_array(jsonb_build_object('url', left(trim(x->>'url'), 500), 'desc', left(trim(coalesce(x->>'desc', '')), 200)));
    end loop;
  end if;
  update workspaces set content_fontes = content_fontes
      || case when p_canais is not null then jsonb_build_object('canais', c) else '{}'::jsonb end
      || case when p_sem_canais is not null then jsonb_build_object('sem_canais', p_sem_canais) else '{}'::jsonb end
      || case when p_links is not null then jsonb_build_object('links', l) else '{}'::jsonb end
  where id = p_ws returning content_fontes into r;
  return r;
end $$;
revoke all on function public.content_fontes_salvar(uuid, jsonb, boolean, jsonb) from public, anon;
grant execute on function public.content_fontes_salvar(uuid, jsonb, boolean, jsonb) to authenticated;

-- situação de um tipo de material: 'ok' (está na pasta), 'nao_tem' ou null (reabrir)
create or replace function public.content_material_marcar(p_ws uuid, p_item text, p_estado text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare itens text[] := array['documentos', 'identidade', 'reunioes', 'aulas', 'depoimentos', 'links']; m jsonb; r jsonb; todos boolean;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  if not (p_item = any(itens)) then raise exception 'Material desconhecido'; end if;
  if p_estado is not null and p_estado not in ('ok', 'nao_tem') then raise exception 'Situação inválida'; end if;
  select coalesce(content_fontes->'materiais', '{}'::jsonb) into m from workspaces where id = p_ws;
  m := case when p_estado is null then m - p_item else m || jsonb_build_object(p_item, jsonb_build_object('estado', p_estado, 'em', now())) end;
  todos := (select bool_and(m ? i) from unnest(itens) i);
  update workspaces set content_fontes = content_fontes || jsonb_build_object('materiais', m),
    content_setup_marcos = case when todos then content_setup_marcos || jsonb_build_object('materiais', coalesce(content_setup_marcos->'materiais', to_jsonb(now()))) else content_setup_marcos - 'materiais' end
  where id = p_ws returning content_fontes into r;
  return r;
end $$;
revoke all on function public.content_material_marcar(uuid, text, text) from public, anon;
grant execute on function public.content_material_marcar(uuid, text, text) to authenticated;

-- situação da configuração: + fontes
create or replace function public.content_setup_estado(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  return (select jsonb_build_object('etapa', w.content_setup_etapa, 'concluido_em', w.content_setup_em, 'content_ativo', w.content_ativo, 'marcos', w.content_setup_marcos, 'fontes', w.content_fontes,
    'drive', jsonb_build_object('modo', w.content_drive_modo, 'status', w.content_drive_status, 'url', w.content_drive_url, 'erro', w.content_drive_erro, 'email', w.content_drive_email,
                                'compartilhar_com', (select valor from sistema_config where chave = 'drive_script_email')),
    'pode', content_pode_configurar(p_ws), 'nome', w.nome) from workspaces w where w.id = p_ws);
end $$;

notify pgrst, 'reload schema';
