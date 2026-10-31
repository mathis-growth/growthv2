-- v0.179 — OAuth Instagram direto pelo Growths usando a Zernio central.
-- Não substitui conexões Meta, contas Zernio ou históricos existentes.
-- Requer: 20261022200000_conexoes.sql e Central de Atendimento v0.175.
alter table public.conexoes
  add column if not exists zernio_profile_id text;

-- Um perfil técnico da conta central Zernio pertence a exatamente um workspace Growths.
create unique index if not exists conexoes_zernio_profile_unico
  on public.conexoes (zernio_profile_id)
  where plataforma = 'zernio' and zernio_profile_id is not null;

-- Consultado pela interface para não oferecer o botão a quem não administra o workspace.
create or replace function public.zernio_oauth_permitido(p_ws uuid)
returns boolean
language sql stable security invoker set search_path = public, pg_temp
as $$
  select coalesce(
    auth.uid() is not null
    and public.pertence_ao_workspace(p_ws)
    and public.eh_admin(p_ws)
    and public.perm(p_ws, 'editar', '{cfg}'::text[]),
    false
  );
$$;
revoke all on function public.zernio_oauth_permitido(uuid) from public, anon;
grant execute on function public.zernio_oauth_permitido(uuid) to authenticated;

-- Reaproveita os estados OAuth privados existentes (Meta / Google), com namespace Zernio.
-- O callback consome o nonce uma única vez por conexao_estado_usar.
create or replace function public.zernio_oauth_iniciar(p_ws uuid)
returns text
language plpgsql security definer set search_path = public, privado, pg_temp
as $$
declare
  n text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not public.zernio_oauth_permitido(p_ws) then
    raise exception 'Somente administradores deste cliente podem conectar Instagram.'
      using errcode = '42501';
  end if;
  delete from privado.conexao_estados where expira_em < now();
  insert into privado.conexao_estados(nonce, workspace_id, plataforma, user_id, volta)
  values(n, p_ws, 'zernio', auth.uid(), 'instagram-oauth');
  return n;
end;
$$;
revoke all on function public.zernio_oauth_iniciar(uuid) from public, anon;
grant execute on function public.zernio_oauth_iniciar(uuid) to authenticated;
