-- Atualiza o agendamento e os itens ainda não enviados em uma única transação.
create or replace function public.atd_grupo_disparo_editar_agendamento(
  p_workspace uuid,
  p_campanha uuid,
  p_nome text,
  p_texto text,
  p_iniciar_em timestamptz
) returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_campanha public.atd_disparos_grupos;
  v_pendentes integer;
begin
  if length(trim(coalesce(p_nome, ''))) not between 1 and 100
     or length(coalesce(p_texto, '')) > 4000
     or p_iniciar_em is null or p_iniciar_em < now() + interval '1 minute' then
    raise exception 'Informe nome, mensagem e horário futuro válido.';
  end if;

  select * into v_campanha
  from public.atd_disparos_grupos
  where workspace_id = p_workspace and id = p_campanha
  for update;

  if not found or v_campanha.status <> 'agendado' then
    raise exception 'Somente campanhas agendadas podem ter nome e horário alterados.';
  end if;
  if length(trim(coalesce(p_texto, ''))) = 0 and v_campanha.midia_path is null then
    raise exception 'Informe uma mensagem; a campanha não possui mídia.';
  end if;
  if exists (
    select 1 from public.atd_disparos_grupos_itens
    where workspace_id = p_workspace and campanha_id = p_campanha and status <> 'agendado'
  ) then
    raise exception 'O envio já começou; o agendamento não pode ser alterado.';
  end if;

  update public.atd_disparos_grupos
  set nome = trim(p_nome), texto = coalesce(p_texto, ''),
      iniciar_em = p_iniciar_em, atualizado_em = now()
  where workspace_id = p_workspace and id = p_campanha;

  update public.atd_disparos_grupos_itens
  set texto = coalesce(p_texto, ''),
      enviar_em = p_iniciar_em + posicao * v_campanha.intervalo_segundos * interval '1 second',
      atualizado_em = now()
  where workspace_id = p_workspace and campanha_id = p_campanha and status = 'agendado';
  get diagnostics v_pendentes = row_count;
  return v_pendentes;
end;
$$;

revoke all on function public.atd_grupo_disparo_editar_agendamento(uuid, uuid, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.atd_grupo_disparo_editar_agendamento(uuid, uuid, text, text, timestamptz) to service_role;
