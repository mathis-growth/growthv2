-- v0.185: OAuth Zernio para YouTube, LinkedIn, TikTok, Páginas e WhatsApp oficial.
-- Mantém todas as conexões e históricos já existentes.
alter table public.conexao_contas drop constraint if exists conexao_contas_tipo_check;
alter table public.conexao_contas add constraint conexao_contas_tipo_check
 check (tipo in ('meta_ads','instagram','facebook_pagina','google_ads','youtube','whatsapp','linkedin','tiktok'));

create or replace function public.zernio_social_oauth_iniciar(p_ws uuid, p_platform text)
returns text language plpgsql security definer
set search_path = public, privado, pg_temp as $$
declare n text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
begin
  if p_platform not in ('youtube','linkedin','tiktok','facebook','whatsapp') then
    raise exception 'Plataforma OAuth não suportada' using errcode = '22023';
  end if;
  if not public.zernio_oauth_permitido(p_ws) then
    raise exception 'Somente administradores deste workspace podem autorizar integrações.'
      using errcode = '42501';
  end if;
  delete from privado.conexao_estados where expira_em < now();
  insert into privado.conexao_estados(nonce,workspace_id,plataforma,user_id,volta)
  values (n,p_ws,'zernio',auth.uid(),'zernio-social:'||p_platform);
  return n;
end $$;
revoke all on function public.zernio_social_oauth_iniciar(uuid,text) from public,anon;
grant execute on function public.zernio_social_oauth_iniciar(uuid,text) to authenticated;

-- Mantém o isolamento de contas Zernio, estendendo-o aos canais sociais OAuth.
create or replace function public.conexao_zernio_isolamento()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare plataforma text;
begin
  select c.plataforma into plataforma from public.conexoes c
   where c.id = new.conexao_id and c.workspace_id = new.workspace_id;
  if plataforma is null then raise exception 'Conexão fora do workspace'; end if;
  if plataforma <> 'zernio' then return new; end if;
  if new.tipo not in ('instagram','whatsapp','meta_ads','youtube','linkedin','tiktok','facebook_pagina') then
    raise exception 'Canal Zernio inválido';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.id_externo,74812));
  if exists (
    select 1 from public.conexao_contas k join public.conexoes c on c.id=k.conexao_id
     where c.plataforma='zernio' and k.id_externo=new.id_externo and k.workspace_id<>new.workspace_id
  ) or exists (
    select 1 from public.atd_canais a
    where a.provedor='zernio' and a.externo_id=new.id_externo and a.workspace_id<>new.workspace_id
  ) then raise exception 'Conta Zernio já vinculada a outro cliente'; end if;
  return new;
end $$;
