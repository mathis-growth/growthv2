-- Snapshot do texto por destinatário para editar somente os que ainda aguardam envio.
alter table public.atd_disparos_grupos_itens
  add column if not exists texto text not null default '';

alter table public.atd_disparos_grupos_itens
  drop constraint if exists atd_disparos_grupos_itens_texto_check;
alter table public.atd_disparos_grupos_itens
  add constraint atd_disparos_grupos_itens_texto_check check (length(texto) <= 4000);

update public.atd_disparos_grupos_itens i
set texto = c.texto
from public.atd_disparos_grupos c
where i.workspace_id = c.workspace_id
  and i.campanha_id = c.id
  and i.texto = ''
  and c.texto <> '';

create or replace function public.atd_grupo_disparo_editar_mensagem(
  p_workspace uuid,
  p_campanha uuid,
  p_texto text
) returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
  v_midia text;
  v_pendentes integer;
begin
  if length(coalesce(p_texto, '')) > 4000 then
    raise exception 'A mensagem pode ter no máximo 4.000 caracteres.';
  end if;

  select status, midia_path into v_status, v_midia
  from public.atd_disparos_grupos
  where workspace_id = p_workspace and id = p_campanha
  for update;

  if not found or v_status not in ('agendado', 'em_andamento') then
    raise exception 'Esta campanha não aceita mais alterações.';
  end if;
  if length(trim(coalesce(p_texto, ''))) = 0 and v_midia is null then
    raise exception 'Informe uma mensagem; a campanha não possui mídia.';
  end if;

  select count(*) into v_pendentes
  from public.atd_disparos_grupos_itens
  where workspace_id = p_workspace and campanha_id = p_campanha and status = 'agendado';
  if v_pendentes = 0 then
    raise exception 'Não há destinatários aguardando envio.';
  end if;

  update public.atd_disparos_grupos
  set texto = coalesce(p_texto, ''), atualizado_em = now()
  where workspace_id = p_workspace and id = p_campanha;

  update public.atd_disparos_grupos_itens
  set texto = coalesce(p_texto, ''), atualizado_em = now()
  where workspace_id = p_workspace and campanha_id = p_campanha and status = 'agendado';
  get diagnostics v_pendentes = row_count;
  return v_pendentes;
end;
$$;

revoke all on function public.atd_grupo_disparo_editar_mensagem(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.atd_grupo_disparo_editar_mensagem(uuid, uuid, text) to service_role;
