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
