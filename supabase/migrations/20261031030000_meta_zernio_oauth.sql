-- v0.182 — Meta Ads por OAuth Zernio central. NÃO exige Meta App ID/Secret.
-- Preserva as conexões Instagram/WhatsApp e históricos. Aplicar depois da v0.179.
-- meta_ads é um canal financeiro; nunca aparece em Atendimento.
create or replace function public.conexao_zernio_isolamento()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare plataforma text;
begin
  select c.plataforma into plataforma from public.conexoes c
   where c.id = new.conexao_id and c.workspace_id = new.workspace_id;
  if plataforma is null then raise exception 'Conexão fora do workspace'; end if;
  if plataforma <> 'zernio' then return new; end if;
  if new.tipo not in ('instagram','whatsapp','meta_ads') then raise exception 'Canal Zernio inválido'; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.id_externo, 74812));
  if exists (
    select 1 from public.conexao_contas k
    join public.conexoes c on c.id = k.conexao_id
    where c.plataforma = 'zernio' and k.id_externo = new.id_externo
      and k.workspace_id <> new.workspace_id
  ) or exists (
    select 1 from public.atd_canais a
    where a.provedor = 'zernio' and a.externo_id = new.id_externo
      and a.workspace_id <> new.workspace_id
  ) then raise exception 'Conta Zernio já vinculada a outro cliente'; end if;
  return new;
end $$;

-- Nonce OAuth de uso único, reutilizando a infraestrutura privada já existente.
create or replace function public.zernio_meta_oauth_iniciar(p_ws uuid)
returns text language plpgsql security definer set search_path = public, privado, pg_temp as $$
declare n text := replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
begin
  if not public.zernio_oauth_permitido(p_ws) then
    raise exception 'Somente administradores deste cliente podem conectar Meta Ads.' using errcode = '42501';
  end if;
  delete from privado.conexao_estados where expira_em < now();
  insert into privado.conexao_estados(nonce, workspace_id, plataforma, user_id, volta)
  values (n,p_ws,'zernio',auth.uid(),'metaads-oauth');
  return n;
end $$;
revoke all on function public.zernio_meta_oauth_iniciar(uuid) from public,anon;
grant execute on function public.zernio_meta_oauth_iniciar(uuid) to authenticated;
