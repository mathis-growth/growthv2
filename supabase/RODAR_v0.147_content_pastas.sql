-- v0.147 — Growth's Content: só a pasta do próprio cliente (sem "Não tenho Google Drive"), outras pastas do cliente no passo 1
-- e as pastas da Mathisa (padrões), que a IA também lê.
-- Regra de leitura (interna, não aparece para o cliente): pastas da Mathisa = padrões (mudam pouco);
-- pastas do cliente = novidades (método novo, estudo novo, material novo).
-- Pode ser rodado de novo sem erro.

-- 1) a opção "pasta no Drive da Mathisa" sai da tela; quem já tem continua funcionando
revoke execute on function public.content_drive_sem_google(uuid) from authenticated;

-- 2) materiais: "Links de outros Drives" sai do passo 3 (vai para o passo 1); ficam 5 tipos
create or replace function public.content_material_marcar(p_ws uuid, p_item text, p_estado text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare itens text[] := array['documentos', 'identidade', 'reunioes', 'aulas', 'depoimentos']; m jsonb; r jsonb; todos boolean;
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
-- quem já tinha resolvido os 5 tipos fica com o passo pronto
update public.workspaces set content_setup_marcos = content_setup_marcos || jsonb_build_object('materiais', to_jsonb(now()))
 where not (content_setup_marcos ? 'materiais')
   and (select bool_and(content_fontes->'materiais' ? i) from unnest(array['documentos', 'identidade', 'reunioes', 'aulas', 'depoimentos']) i);

-- 3) id da pasta a partir do link do Drive
create or replace function public.drive_pasta_id(p_link text) returns text
language sql immutable set search_path = public as $$
  select coalesce((regexp_match(coalesce(p_link, ''), '/folders/([A-Za-z0-9_-]{10,})'))[1], (regexp_match(coalesce(p_link, ''), '[?&]id=([A-Za-z0-9_-]{10,})'))[1],
                  (regexp_match(trim(coalesce(p_link, '')), '^([A-Za-z0-9_-]{20,})$'))[1]);
$$;

-- 4) pastas da Mathisa (padrões): para todos os clientes (workspace_id nulo) ou para um cliente
create table if not exists public.content_pastas_mathisa (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.workspaces(id) on delete cascade,
  nome text not null,
  pasta_id text not null,
  url text not null,
  ativo boolean not null default true,
  criado_por uuid,
  criado_em timestamptz not null default now()
);
alter table public.content_pastas_mathisa enable row level security;
drop policy if exists content_pastas_mathisa_interno on public.content_pastas_mathisa;
create policy content_pastas_mathisa_interno on public.content_pastas_mathisa for all to authenticated using (sou_equipe_interna()) with check (sou_equipe_interna());
revoke all on public.content_pastas_mathisa from anon;
grant select, update, delete on public.content_pastas_mathisa to authenticated;

create or replace function public.content_pasta_mathisa_add(p_ws uuid, p_nome text, p_link text) returns uuid
language plpgsql security definer set search_path = public as $$
declare pid text := drive_pasta_id(p_link); r uuid;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna cadastra as pastas da Mathisa'; end if;
  if pid is null then raise exception 'Não reconheci o link da pasta. Abra a pasta no Google Drive e copie o endereço (drive.google.com/drive/folders/...).'; end if;
  if trim(coalesce(p_nome, '')) = '' then raise exception 'Dê um nome à pasta'; end if;
  insert into content_pastas_mathisa (workspace_id, nome, pasta_id, url, criado_por)
    values (p_ws, left(trim(p_nome), 120), pid, 'https://drive.google.com/drive/folders/' || pid, auth.uid()) returning id into r;
  return r;
end $$;
revoke all on function public.content_pasta_mathisa_add(uuid, text, text) from public, anon;
grant execute on function public.content_pasta_mathisa_add(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';
