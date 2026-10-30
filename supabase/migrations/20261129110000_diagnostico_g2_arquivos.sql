-- v0.177 — Diagnóstico 360° (G2): o cliente envia os arquivos pelo link do diagnóstico.
-- Plano: docs/diagnostico-360-plano.md, seção 8 (G2) e seção E (Central de Documentos).
-- 1. Local privado "diagnostico" no Storage: até 20 MB por arquivo. Sem acesso anônimo: o envio usa uma autorização de uso único
--    criada pela função na nuvem "diagnostico-arquivo" depois de conferir o link.
-- 2. pesquisa_arquivos: um registro por arquivo (empresa, envio, pessoa, grupo, nome, caminho, tamanho, tipo).
-- 3. Funções do link (o cliente não está logado):
--    pesquisa_arquivo_autorizar, pesquisa_arquivo_caminho, pesquisa_arquivo_confirmar e pesquisa_arquivo_remover: só a função na
--    nuvem chama (service_role);
--    pesquisa_arquivos_do_link: o cliente vê os arquivos que ele mesmo mandou por aquele link.
--    Valem só no diagnóstico, com o link dentro da validade (mesmo depois de responder, para mandar o que faltou).
--    No máximo 40 arquivos por link. Tipos aceitos: planilha, CSV, texto, PDF, Word, PowerPoint e imagem.
-- 4. A equipe lê os registros e baixa os arquivos pela proteção por empresa.
-- Rode depois de 20261129100000_diagnostico_g1b.sql. Idempotente.

-- ---------- 2. registro dos arquivos ----------
create table if not exists pesquisa_arquivos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  envio_id uuid not null references pesquisa_envios(id) on delete cascade,
  pesquisa_id uuid not null references pesquisas(id) on delete cascade,
  pessoa_id uuid references pessoas(id) on delete set null,
  grupo text not null check (grupo ~ '^[a-z0-9_]{1,40}$'),
  nome text not null check (length(nome) between 1 and 200),
  caminho text not null unique,
  tamanho bigint not null check (tamanho > 0 and tamanho <= 20971520),
  tipo text,
  status text not null default 'pendente' check (status in ('pendente', 'enviado')),
  criado_em timestamptz not null default now(),
  enviado_em timestamptz
);
create index if not exists pesquisa_arquivos_envio on pesquisa_arquivos (envio_id, status);
alter table pesquisa_arquivos enable row level security;
drop policy if exists pesquisa_arquivos_acesso on pesquisa_arquivos;
drop policy if exists perm_ler on pesquisa_arquivos;
drop policy if exists perm_excluir on pesquisa_arquivos;
create policy pesquisa_arquivos_acesso on pesquisa_arquivos for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on pesquisa_arquivos as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['gro', 'adm', 'mkt']));
create policy perm_excluir on pesquisa_arquivos as restrictive for delete to authenticated using (perm(workspace_id, 'editar', array['gro']));
-- a equipe só lê e exclui; quem grava é a função do link
revoke all on pesquisa_arquivos from anon, authenticated;
grant select, delete on pesquisa_arquivos to authenticated;

-- ---------- 3. funções do link ----------
-- o envio do token, se ele vale para mandar arquivos
create or replace function public.pesquisa_arquivo_envio(p_token text) returns pesquisa_envios
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas;
begin
  if p_token is null or length(p_token) < 32 then raise exception 'Link inválido.'; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if not found then raise exception 'Link inválido.'; end if;
  select * into v_p from pesquisas where id = v_e.pesquisa_id;
  if v_p.tipo <> 'diagnostico' or not v_p.ativa then raise exception 'Este formulário não recebe arquivos.'; end if;
  if v_e.expira_em is not null and v_e.expira_em < now() then raise exception 'Este link venceu. Peça um novo link a quem enviou.'; end if;
  return v_e;
end $$;

create or replace function public.pesquisa_arquivo_autorizar(p_token text, p_grupo text, p_nome text, p_tamanho bigint, p_tipo text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios; v_ext text; v_id uuid := gen_random_uuid(); v_cam text; v_nome text;
begin
  v_e := pesquisa_arquivo_envio(p_token);
  if p_grupo is null or p_grupo !~ '^[a-z0-9_]{1,40}$' then raise exception 'Grupo de arquivos inválido.'; end if;
  v_nome := left(regexp_replace(coalesce(p_nome, ''), '[[:cntrl:]/\\]', '', 'g'), 200);
  v_ext := lower(substring(v_nome from '\.([A-Za-z0-9]{1,5})$'));
  if v_ext is null or v_ext not in ('xlsx', 'xls', 'csv', 'txt', 'pdf', 'doc', 'docx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg') then
    raise exception 'Tipo de arquivo não aceito. Envie planilha, CSV, PDF, Word, PowerPoint ou imagem.';
  end if;
  if p_tamanho is null or p_tamanho <= 0 then raise exception 'Arquivo vazio.'; end if;
  if p_tamanho > 20971520 then raise exception 'Arquivo maior que 20 MB. Divida em partes ou mande por outro caminho.'; end if;
  -- autorizações antigas que não viraram arquivo deixam de contar
  delete from pesquisa_arquivos where envio_id = v_e.id and status = 'pendente' and criado_em < now() - interval '1 day';
  if (select count(*) from pesquisa_arquivos where envio_id = v_e.id) >= 40 then raise exception 'Este link já tem 40 arquivos. Tire algum ou fale com quem enviou.'; end if;
  v_cam := v_e.workspace_id || '/' || v_e.id || '/' || v_id || '.' || v_ext;
  insert into pesquisa_arquivos (id, workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, tipo)
    values (v_id, v_e.workspace_id, v_e.id, v_e.pesquisa_id, v_e.pessoa_id, p_grupo, v_nome, v_cam, p_tamanho, left(p_tipo, 120));
  return jsonb_build_object('id', v_id, 'caminho', v_cam);
end $$;

-- caminho de um arquivo ainda não confirmado daquele link
create or replace function public.pesquisa_arquivo_caminho(p_token text, p_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios; v_c text;
begin
  v_e := pesquisa_arquivo_envio(p_token);
  select caminho into v_c from pesquisa_arquivos where id = p_id and envio_id = v_e.id and status = 'pendente';
  if v_c is null then raise exception 'Arquivo não encontrado.'; end if;
  return v_c;
end $$;

create or replace function public.pesquisa_arquivo_confirmar(p_token text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios;
begin
  v_e := pesquisa_arquivo_envio(p_token);
  update pesquisa_arquivos set status = 'enviado', enviado_em = now() where id = p_id and envio_id = v_e.id and status = 'pendente';
  if not found then raise exception 'Arquivo não encontrado.'; end if;
end $$;

-- tira o registro e devolve o caminho, para a função na nuvem apagar o arquivo
create or replace function public.pesquisa_arquivo_remover(p_token text, p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios; v_c text;
begin
  v_e := pesquisa_arquivo_envio(p_token);
  delete from pesquisa_arquivos where id = p_id and envio_id = v_e.id returning caminho into v_c;
  if v_c is null then raise exception 'Arquivo não encontrado.'; end if;
  return v_c;
end $$;

-- o que o cliente já mandou por este link (sem o caminho)
create or replace function public.pesquisa_arquivos_do_link(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios;
begin
  v_e := pesquisa_arquivo_envio(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'grupo', grupo, 'nome', nome, 'tamanho', tamanho, 'enviado_em', enviado_em) order by enviado_em)
    from pesquisa_arquivos where envio_id = v_e.id and status = 'enviado'), '[]'::jsonb);
end $$;

revoke all on function public.pesquisa_arquivo_envio(text) from public, anon, authenticated;
revoke all on function public.pesquisa_arquivo_autorizar(text, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.pesquisa_arquivo_caminho(text, uuid) from public, anon, authenticated;
revoke all on function public.pesquisa_arquivo_confirmar(text, uuid) from public, anon, authenticated;
revoke all on function public.pesquisa_arquivo_remover(text, uuid) from public, anon, authenticated;
revoke all on function public.pesquisa_arquivos_do_link(text) from public;
do $g$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.pesquisa_arquivo_autorizar(text, text, text, bigint, text) to service_role;
    grant execute on function public.pesquisa_arquivo_caminho(text, uuid) to service_role;
    grant execute on function public.pesquisa_arquivo_confirmar(text, uuid) to service_role;
    grant execute on function public.pesquisa_arquivo_remover(text, uuid) to service_role;
    grant execute on function public.pesquisa_arquivos_do_link(text) to service_role;
  end if;
end $g$;
grant execute on function public.pesquisa_arquivos_do_link(text) to anon, authenticated;

-- ---------- 1 e 4. local privado no Storage ----------
do $s$ begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public, file_size_limit) values ('diagnostico', 'diagnostico', false, 20971520)
      on conflict (id) do update set public = false, file_size_limit = 20971520;
    execute 'drop policy if exists diagnostico_ler on storage.objects';
    execute $p$create policy diagnostico_ler on storage.objects for select to authenticated using (
      bucket_id = 'diagnostico' and exists (select 1 from public.pesquisa_arquivos a where a.caminho = storage.objects.name
        and public.pertence_ao_workspace(a.workspace_id) and public.perm(a.workspace_id, 'ler', array['gro', 'adm', 'mkt'])))$p$;
  end if;
end $s$;

-- Para desfazer: drop policy diagnostico_ler on storage.objects; apagar os arquivos e o local "diagnostico" pelo painel do Storage;
-- drop function pesquisa_arquivos_do_link(text), pesquisa_arquivo_remover(text, uuid), pesquisa_arquivo_confirmar(text, uuid),
--   pesquisa_arquivo_caminho(text, uuid), pesquisa_arquivo_autorizar(text, text, text, bigint, text), pesquisa_arquivo_envio(text);
-- drop table pesquisa_arquivos.
