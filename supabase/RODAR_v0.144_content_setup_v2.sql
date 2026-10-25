-- v0.144 — Configuração do Growth's Content em 8 passos e o Drive do cliente por pasta compartilhada.
-- 1) Passo 1 recomendado: o cliente cria uma pasta no Drive dele e compartilha com o e-mail da Mathisa (editor);
--    o Apps Script da Mathisa cria a árvore dentro dela (gratuito, e o Growths enxerga tudo o que for colocado ali).
--    "Não tenho Google Drive" continua (pasta no Drive da Mathisa). O login com o Google fica guardado para depois.
-- 2) Árvore de subpastas padrão (sistema_config.content_drive_arvore).
-- 3) Marcos da configuração (ex.: "material pronto para a IA ler") em workspaces.content_setup_marcos.
-- Pode ser rodado de novo sem erro.

alter table public.workspaces drop constraint if exists workspaces_content_drive_modo_check;
alter table public.workspaces add constraint workspaces_content_drive_modo_check check (content_drive_modo is null or content_drive_modo in ('cliente', 'mathisa', 'compartilhada'));
alter table public.workspaces add column if not exists content_setup_marcos jsonb not null default '{}'::jsonb;

insert into public.sistema_config (chave, valor) values ('drive_script_email', 'rebecka@rebeckacappello.com.br') on conflict (chave) do nothing;
insert into public.sistema_config (chave, valor) values ('content_drive_arvore',
  '["01 Briefing", "02 Materiais do cliente", "03 Identidade visual", "04 Referências de conteúdo", "05 Pesquisa de mercado", "06 Dossiê da marca", "07 Skill do cliente", "08 Produção/Roteiros", "08 Produção/Gravações", "08 Produção/Edição", "08 Produção/Artes", "09 Publicados", "10 Resultados"]')
on conflict (chave) do update set valor = excluded.valor where public.sistema_config.valor in ('', '[]');

-- o cliente compartilhou uma pasta do Drive dele com a Mathisa: guarda a pasta e pede a árvore dentro dela
create or replace function public.content_drive_compartilhar(p_ws uuid, p_link text) returns void
language plpgsql security definer set search_path = public as $$
declare pid text;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  pid := coalesce((regexp_match(coalesce(p_link, ''), '/folders/([A-Za-z0-9_-]{10,})'))[1], (regexp_match(coalesce(p_link, ''), '[?&]id=([A-Za-z0-9_-]{10,})'))[1],
                  (regexp_match(trim(coalesce(p_link, '')), '^([A-Za-z0-9_-]{20,})$'))[1]);
  if pid is null then raise exception 'Não reconheci o link da pasta. Abra a pasta no Google Drive e copie o endereço (drive.google.com/drive/folders/...).'; end if;
  update workspaces set content_ativo = true, content_drive_modo = 'compartilhada', content_drive_id = pid, content_drive_url = null, content_drive_email = null where id = p_ws;
  perform content_drive_pedir(p_ws);
end $$;
revoke all on function public.content_drive_compartilhar(uuid, text) from public, anon;
grant execute on function public.content_drive_compartilhar(uuid, text) to authenticated;

-- "Tentar de novo" / "Completar as pastas": mantém onde a pasta está (compartilhada ou Drive da Mathisa)
create or replace function public.content_drive_tentar(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para criar as pastas deste cliente'; end if;
  select content_drive_modo into m from workspaces where id = p_ws;
  if m = 'cliente' then raise exception 'A pasta deste cliente foi conectada pelo login do Google: refaça pelo passo 1'; end if;
  update workspaces set content_ativo = true, content_drive_modo = coalesce(m, 'mathisa') where id = p_ws;
  perform content_drive_pedir(p_ws);
end $$;

-- marcos da configuração (só os conhecidos)
create or replace function public.content_setup_marcar(p_ws uuid, p_marco text, p_feito boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not content_pode_configurar(p_ws) then raise exception 'Sem permissão para configurar o Growth''s Content deste cliente'; end if;
  if p_marco not in ('materiais', 'leitura', 'tese', 'dossie') then raise exception 'Marco desconhecido'; end if;
  update workspaces set content_setup_marcos = case when p_feito then content_setup_marcos || jsonb_build_object(p_marco, now()) else content_setup_marcos - p_marco end
  where id = p_ws returning content_setup_marcos into r;
  return r;
end $$;
revoke all on function public.content_setup_marcar(uuid, text, boolean) from public, anon;
grant execute on function public.content_setup_marcar(uuid, text, boolean) to authenticated;

-- situação da configuração: + marcos e o e-mail com quem compartilhar
create or replace function public.content_setup_estado(p_ws uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  return (select jsonb_build_object('etapa', w.content_setup_etapa, 'concluido_em', w.content_setup_em, 'content_ativo', w.content_ativo, 'marcos', w.content_setup_marcos,
    'drive', jsonb_build_object('modo', w.content_drive_modo, 'status', w.content_drive_status, 'url', w.content_drive_url, 'erro', w.content_drive_erro, 'email', w.content_drive_email,
                                'compartilhar_com', (select valor from sistema_config where chave = 'drive_script_email')),
    'pode', content_pode_configurar(p_ws), 'nome', w.nome) from workspaces w where w.id = p_ws);
end $$;

notify pgrst, 'reload schema';
