-- A Edge pode desvincular a API Evolution sem expor a chave ao navegador.
create or replace function public.atd_segredo_remover(p_ws uuid)
returns void language plpgsql security definer set search_path=public,privado as $$
begin
  if exists (select 1 from public.atd_canais where workspace_id=p_ws and provedor='evolution' and ativo) then
    raise exception 'Remova os canais Evolution ativos antes de desvincular a API.';
  end if;
  delete from privado.atd_segredos where workspace_id=p_ws;
end $$;
revoke all on function public.atd_segredo_remover(uuid) from public,anon,authenticated;
grant execute on function public.atd_segredo_remover(uuid) to service_role;
