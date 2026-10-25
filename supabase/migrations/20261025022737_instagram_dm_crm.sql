-- Aplicada em produção em 25/10/2026 por outra sessão (copiada do histórico de migrações do Supabase para o repositório).
-- Canal "Instagram DM" no workspace Mathisa — Operação
insert into public.canais (workspace_id, codigo, nome, utm_source, utm_medium, ativo, tipo)
select '8fd51ed1-0843-49d8-a2aa-b9bb99c59171', 'instagram_dm', 'Instagram DM', 'instagram', 'dm', true, 'organico'
where not exists (
  select 1 from public.canais
  where workspace_id = '8fd51ed1-0843-49d8-a2aa-b9bb99c59171' and codigo = 'instagram_dm'
);

create index if not exists pessoas_instagram_id_ix
  on public.pessoas (workspace_id, (extras->>'instagram_id'))
  where extras ? 'instagram_id';

-- Registra uma DM do Instagram no CRM: cria (ou reaproveita) a pessoa pelo id do Instagram,
-- garante a tag "DM Instagram" e grava a mensagem no histórico de toques (sem duplicar pelo id da mensagem).
create or replace function public.registrar_dm_instagram(
  p_workspace_id uuid,
  p_instagram_id text,
  p_mensagem_id text,
  p_texto text default null,
  p_username text default null,
  p_nome text default null,
  p_em timestamptz default now()
) returns uuid
language plpgsql
set search_path to 'public'
as $function$
declare v_pessoa uuid; v_tag constant text := 'DM Instagram';
begin
  if p_instagram_id is null or p_mensagem_id is null then
    raise exception 'instagram_id e mensagem_id são obrigatórios';
  end if;

  perform pg_advisory_xact_lock(hashtext('dm_instagram:' || p_workspace_id || ':' || p_instagram_id));

  select id into v_pessoa from pessoas
   where workspace_id = p_workspace_id and extras ? 'instagram_id' and extras->>'instagram_id' = p_instagram_id
   order by criado_em limit 1;

  if v_pessoa is null then
    insert into pessoas (workspace_id, nome, canal_origem, utm_source, utm_medium, tags, extras, criado_em)
    values (p_workspace_id,
            coalesce(nullif(trim(p_nome), ''), '@' || nullif(trim(p_username), ''), 'Instagram ' || p_instagram_id),
            'instagram_dm', 'instagram', 'dm', array[v_tag],
            jsonb_strip_nulls(jsonb_build_object('instagram_id', p_instagram_id, 'instagram_username', nullif(trim(p_username), ''))),
            coalesce(p_em, now()))
    returning id into v_pessoa;
  else
    update pessoas
       set tags = case when v_tag = any(tags) then tags else tags || v_tag end,
           extras = case when nullif(trim(p_username), '') is not null and extras->>'instagram_username' is distinct from trim(p_username)
                         then extras || jsonb_build_object('instagram_username', trim(p_username)) else extras end
     where id = v_pessoa
       and (not (v_tag = any(tags))
            or (nullif(trim(p_username), '') is not null and extras->>'instagram_username' is distinct from trim(p_username)));
  end if;

  if not exists (select 1 from pessoa_toques where pessoa_id = v_pessoa and canal = 'instagram_dm' and chave = p_mensagem_id) then
    insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, chave, descricao, utm_source, utm_medium, origem)
    values (p_workspace_id, v_pessoa, coalesce(p_em, now()), 'outro', 'instagram_dm', p_mensagem_id,
            'DM Instagram: ' || coalesce(left(p_texto, 500), '(anexo)'), 'instagram', 'dm', 'integracao');
  end if;

  return v_pessoa;
end $function$;

revoke all on function public.registrar_dm_instagram(uuid, text, text, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.registrar_dm_instagram(uuid, text, text, text, text, text, timestamptz) to service_role;
