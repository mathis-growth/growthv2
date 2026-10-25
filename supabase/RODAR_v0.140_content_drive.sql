-- v0.140 — Growth's Content: cliente marcado como "usa o Growth's Content" ganha uma pasta no Google Drive,
-- criada sozinha dentro de "Mathisa Growth's Content" (com a árvore de pastas, quando houver uma cadastrada).
-- Quem cria a pasta: a função "content-drive", que chama um Google Apps Script publicado na conta da Rebecka
-- (integracoes/apps-script/growths-drive.gs). Endereço e senha do script ficam só em sistema_config (sem acesso pela API).
-- Pode ser rodado de novo sem erro.

create extension if not exists pg_net;

alter table public.workspaces add column if not exists content_ativo boolean not null default false;
alter table public.workspaces add column if not exists content_drive_id text;
alter table public.workspaces add column if not exists content_drive_url text;
alter table public.workspaces add column if not exists content_drive_status text;
alter table public.workspaces drop constraint if exists workspaces_content_drive_status_check;
alter table public.workspaces add constraint workspaces_content_drive_status_check check (content_drive_status is null or content_drive_status in ('criando', 'ok', 'erro'));
alter table public.workspaces add column if not exists content_drive_erro text;
alter table public.workspaces add column if not exists content_drive_em timestamptz;

-- configuração (preenchida no RODAR, com os valores de produção):
--   content_drive_raiz   id da pasta "Mathisa Growth's Content"
--   content_drive_arvore lista JSON de caminhos de subpastas, ex. ["01 Briefing","02 Conteúdos/Roteiros"]
--   content_drive_url    endereço da função content-drive
--   content_drive_token  senha que o banco usa para chamar a função
--   drive_script_url     endereço do Apps Script (termina em /exec)
--   drive_script_senha   senha que está dentro do Apps Script
insert into public.sistema_config (chave, valor) values ('content_drive_token', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')) on conflict (chave) do nothing;
insert into public.sistema_config (chave, valor) values ('content_drive_arvore', '[]') on conflict (chave) do nothing;

-- pede a criação da pasta (não espera: a função grava o resultado no cliente)
create or replace function public.content_drive_pedir(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
declare url text; tok text;
begin
  select valor into url from sistema_config where chave = 'content_drive_url';
  select valor into tok from sistema_config where chave = 'content_drive_token';
  if url is null then
    update workspaces set content_drive_status = 'erro', content_drive_erro = 'A criação de pastas ainda não está ligada (falta o endereço da função).', content_drive_em = now() where id = p_ws;
    return;
  end if;
  update workspaces set content_drive_status = 'criando', content_drive_erro = null, content_drive_em = now() where id = p_ws;
  begin
    execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 60000)'
      using url, jsonb_build_object('workspace_id', p_ws), jsonb_build_object('Content-Type', 'application/json', 'x-growths-token', tok);
  exception when others then
    update workspaces set content_drive_status = 'erro', content_drive_erro = 'Não consegui chamar a função de pastas: ' || sqlerrm where id = p_ws;
  end;
end $$;
revoke all on function public.content_drive_pedir(uuid) from public, anon, authenticated;

-- ligou o Growth's Content e ainda não tem pasta → pede a pasta
create or replace function public.content_ws_gatilho() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.content_ativo and new.content_drive_id is null and (tg_op = 'INSERT' or not coalesce(old.content_ativo, false)) then
    perform content_drive_pedir(new.id);
  end if;
  return null;
end $$;
revoke all on function public.content_ws_gatilho() from public, anon, authenticated;
drop trigger if exists content_ws_t on public.workspaces;
create trigger content_ws_t after insert or update of content_ativo on public.workspaces for each row execute function public.content_ws_gatilho();

-- equipe interna: liga ou desliga o Growth's Content de um cliente (desligar não apaga a pasta)
create or replace function public.content_definir(p_ws uuid, p_ativo boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna define quem usa o Growth''s Content'; end if;
  update workspaces set content_ativo = coalesce(p_ativo, false) where id = p_ws;
  if not found then raise exception 'Cliente não encontrado'; end if;
  select jsonb_build_object('id', id, 'content_ativo', content_ativo, 'status', content_drive_status, 'url', content_drive_url, 'erro', content_drive_erro) into r from workspaces where id = p_ws;
  return r;
end $$;
revoke all on function public.content_definir(uuid, boolean) from public, anon;
grant execute on function public.content_definir(uuid, boolean) to authenticated;

-- equipe interna: tenta de novo (pasta com erro, ou árvore nova para completar)
create or replace function public.content_drive_tentar(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna cria as pastas'; end if;
  if not exists (select 1 from workspaces where id = p_ws and content_ativo) then raise exception 'Marque antes que o cliente usa o Growth''s Content'; end if;
  perform content_drive_pedir(p_ws);
end $$;
revoke all on function public.content_drive_tentar(uuid) from public, anon;
grant execute on function public.content_drive_tentar(uuid) to authenticated;

-- equipe interna: lista de clientes com a situação da pasta (inclui a própria Mathisa)
create or replace function public.content_clientes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê esta lista'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'agencia', coalesce(w.agencia, false), 'content_ativo', w.content_ativo,
      'status', w.content_drive_status, 'url', w.content_drive_url, 'erro', w.content_drive_erro, 'em', w.content_drive_em) order by coalesce(w.agencia, false) desc, w.nome)
    from workspaces w where w.casa_de is null), '[]'::jsonb);
end $$;
revoke all on function public.content_clientes() from public, anon;
grant execute on function public.content_clientes() to authenticated;

-- o próprio cliente (e quem tem acesso a ele) vê o link da pasta dele
create or replace function public.content_minha_pasta(p_ws uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when pertence_ao_workspace(p_ws) then (select jsonb_build_object('content_ativo', content_ativo, 'status', content_drive_status, 'url', content_drive_url) from workspaces where id = p_ws) end;
$$;
revoke all on function public.content_minha_pasta(uuid) from public, anon;
grant execute on function public.content_minha_pasta(uuid) to authenticated;

notify pgrst, 'reload schema';

-- ---------- valores de produção (troque os marcados) ----------
insert into public.sistema_config (chave, valor) values
  ('content_drive_raiz', '1dlyWC_TxDdZe2g-Zk-IXIm2cHmzcDua8'),                                   -- pasta "Mathisa Growth's Content"
  ('content_drive_url', 'https://yngyghlyonybvfvjcmxl.supabase.co/functions/v1/content-drive')
on conflict (chave) do update set valor = excluded.valor;
-- depois de publicar o Apps Script (a senha é a mesma da linha SENHA do growths-drive.gs):
-- insert into public.sistema_config (chave, valor) values ('drive_script_url', '<URL /exec>'), ('drive_script_senha', '<SENHA>')
--   on conflict (chave) do update set valor = excluded.valor;
