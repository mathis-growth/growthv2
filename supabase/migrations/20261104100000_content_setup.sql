-- v0.143 — Growth's Content: configuração passo a passo e o Google Drive do próprio cliente.
-- 1) Enquanto a configuração não é concluída, a Estratégia de conteúdo mostra só a configuração (passo a passo);
--    o passo atual e a conclusão ficam no cliente (workspaces.content_setup_*).
-- 2) Passo 1: o cliente conecta o Google Drive DELE (login Google, função content-google) e o Growths cria lá a pasta e a
--    árvore; se ele não tiver Drive, a pasta é criada no Drive da Mathisa (Apps Script da v0.140).
-- 3) Marcar o Growth's Content no acesso não cria mais a pasta sozinho: ela nasce no passo 1.
-- Pode ser rodado de novo sem erro.

alter table public.workspaces add column if not exists content_setup_etapa smallint not null default 0;
alter table public.workspaces add column if not exists content_setup_em timestamptz;      -- concluída em
alter table public.workspaces add column if not exists content_drive_modo text;
alter table public.workspaces drop constraint if exists workspaces_content_drive_modo_check;
alter table public.workspaces add constraint workspaces_content_drive_modo_check check (content_drive_modo is null or content_drive_modo in ('cliente', 'mathisa'));
alter table public.workspaces add column if not exists content_drive_email text;           -- conta Google conectada

-- conta Google do cliente (só o servidor lê: o token nunca vai para a tela)
create table if not exists public.content_google (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  email text,
  refresh_token text not null,
  escopos text,
  conectado_por uuid,
  conectado_em timestamptz not null default now()
);
alter table public.content_google enable row level security;
revoke all on public.content_google from public, anon, authenticated;

-- pedidos de login em andamento (validade de 15 minutos)
create table if not exists public.content_google_estados (
  estado text primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid,
  voltar text,
  criado_em timestamptz not null default now()
);
alter table public.content_google_estados enable row level security;
revoke all on public.content_google_estados from public, anon, authenticated;

-- a pasta não nasce mais ao ligar o módulo (nasce no passo 1 da configuração)
drop trigger if exists content_ws_t on public.workspaces;

-- quem pode configurar o Growth's Content deste cliente
create or replace function public.content_pode_configurar(p_ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select sou_equipe_interna() or (pertence_ao_workspace(p_ws) and perm(p_ws, 'editar', array['mkt']));
$$;
revoke all on function public.content_pode_configurar(uuid) from public, anon;
grant execute on function public.content_pode_configurar(uuid) to authenticated;

-- situação da configuração (para a tela)
create or replace function public.content_setup_estado(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  return (select jsonb_build_object('etapa', w.content_setup_etapa, 'concluido_em', w.content_setup_em, 'content_ativo', w.content_ativo,
    'drive', jsonb_build_object('modo', w.content_drive_modo, 'status', w.content_drive_status, 'url', w.content_drive_url, 'erro', w.content_drive_erro, 'email', w.content_drive_email),
    'pode', content_pode_configurar(p_ws), 'nome', w.nome) from workspaces w where w.id = p_ws);
end $$;
revoke all on function public.content_setup_estado(uuid) from public, anon;
grant execute on function public.content_setup_estado(uuid) to authenticated;

-- guarda o passo atual; p_concluir = true fecha a configuração; p_reabrir = true volta para o passo a passo
create or replace function public.content_setup_salvar(p_ws uuid, p_etapa smallint, p_concluir boolean default false, p_reabrir boolean default false) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  if p_concluir and not exists (select 1 from workspaces where id = p_ws and content_drive_status = 'ok') then raise exception 'Falta a pasta no Google Drive (passo 1)'; end if;
  update workspaces set content_setup_etapa = greatest(0, least(coalesce(p_etapa, content_setup_etapa), 20)),
    content_setup_em = case when p_reabrir then null when p_concluir then coalesce(content_setup_em, now()) else content_setup_em end
  where id = p_ws;
end $$;
revoke all on function public.content_setup_salvar(uuid, smallint, boolean, boolean) from public, anon;
grant execute on function public.content_setup_salvar(uuid, smallint, boolean, boolean) to authenticated;

-- "Não tenho Google Drive": a pasta é criada no Drive da Mathisa (Apps Script)
create or replace function public.content_drive_sem_google(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  update workspaces set content_ativo = true, content_drive_modo = 'mathisa', content_drive_email = null,
    content_drive_id = case when content_drive_modo = 'mathisa' then content_drive_id end,
    content_drive_url = case when content_drive_modo = 'mathisa' then content_drive_url end
  where id = p_ws;
  perform content_drive_pedir(p_ws);
end $$;
revoke all on function public.content_drive_sem_google(uuid) from public, anon;
grant execute on function public.content_drive_sem_google(uuid) to authenticated;

-- a pasta do Apps Script (Drive da Mathisa) só vale no modo "mathisa"
create or replace function public.content_drive_tentar(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para criar as pastas deste cliente'; end if;
  select content_drive_modo into m from workspaces where id = p_ws;
  if m = 'cliente' then raise exception 'A pasta deste cliente fica no Google Drive dele: conecte de novo na configuração (passo 1)'; end if;
  update workspaces set content_ativo = true, content_drive_modo = 'mathisa' where id = p_ws;
  perform content_drive_pedir(p_ws);
end $$;

-- a lista da equipe interna mostra onde está a pasta
create or replace function public.content_clientes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê esta lista'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'agencia', coalesce(w.agencia, false), 'content_ativo', w.content_ativo,
      'status', w.content_drive_status, 'url', w.content_drive_url, 'erro', w.content_drive_erro, 'em', w.content_drive_em, 'modo', w.content_drive_modo,
      'email', w.content_drive_email, 'concluido', w.content_setup_em is not null) order by coalesce(w.agencia, false) desc, w.nome)
    from workspaces w where w.casa_de is null), '[]'::jsonb);
end $$;

-- o link da pasta no topo do módulo
create or replace function public.content_minha_pasta(p_ws uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when pertence_ao_workspace(p_ws) or sou_equipe_interna() then (select jsonb_build_object('content_ativo', content_ativo, 'status', content_drive_status, 'url', content_drive_url, 'modo', content_drive_modo) from workspaces where id = p_ws) end;
$$;

-- o mesmo cliente de teste da v0.140 (pasta no Drive da Mathisa) fica marcado como modo "mathisa"
update public.workspaces set content_drive_modo = 'mathisa' where content_drive_status = 'ok' and content_drive_modo is null;

notify pgrst, 'reload schema';
