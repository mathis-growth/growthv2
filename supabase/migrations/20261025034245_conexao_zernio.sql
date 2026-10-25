-- Aplicada em produção em 25/10/2026 por outra sessão (copiada do histórico de migrações do Supabase para o repositório).
-- Conexão "zernio": posts e métricas do Instagram pelo Zernio (função zernio-sync, cron zernio-sync-diario às 9h UTC).
create extension if not exists pg_cron;
create extension if not exists pg_net;

alter table conexoes drop constraint conexoes_plataforma_check;
alter table conexoes add constraint conexoes_plataforma_check check (plataforma = any (array['meta','google','zernio']));

-- Zernio só traz Instagram; sem isso o 'else' marcava Google Ads/YouTube
CREATE OR REPLACE FUNCTION public.conexao_execucao(p_conexao uuid, p_id uuid, p_status text, p_registros integer, p_erro text, p_detalhe jsonb, p_por text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i uuid := p_id; ws uuid;
begin
  select workspace_id into ws from conexoes where id = p_conexao;
  if i is null then
    insert into conexao_execucoes (workspace_id, conexao_id, disparado_por) values (ws, p_conexao, p_por) returning id into i;
  else
    update conexao_execucoes set terminado_em = now(), status = p_status, registros = coalesce(p_registros, 0), erro = p_erro, detalhe = coalesce(p_detalhe, '{}') where id = i;
    update conexoes set ultima_sincronizacao = case when p_status in ('ok', 'parcial') then now() else ultima_sincronizacao end,
           ultimo_erro = p_erro, status = case when p_erro ~* 'token|oauth|expir|invalid_grant|session' then 'expirada' when p_status = 'erro' then 'erro' else 'conectado' end
     where id = p_conexao;
    update integracoes set ultima_sincronizacao = now(), status = case when p_status = 'erro' then 'erro' else 'conectado' end
     where workspace_id = ws and status <> 'desconectado'
       and provedor = any (case (select plataforma from conexoes where id = p_conexao) when 'meta' then array['Meta Ads', 'Instagram'] when 'zernio' then array['Instagram'] else array['Google Ads', 'YouTube'] end);
  end if;
  return i;
end $function$;

CREATE OR REPLACE FUNCTION public.conexao_desconectar(p_ws uuid, p_plataforma text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c uuid;
begin
  if not perm(p_ws, 'editar', '{cfg}'::text[]) then raise exception 'Só quem edita Configurações pode desconectar'; end if;
  select id into c from conexoes where workspace_id = p_ws and plataforma = p_plataforma;
  delete from privado.conexao_tokens where conexao_id = c;
  update conexoes set status = 'desconectado', expira_em = null where id = c;
  update integracoes set status = 'desconectado' where workspace_id = p_ws
     and provedor = any (case p_plataforma when 'meta' then array['Meta Ads', 'Instagram'] when 'zernio' then array['Instagram'] else array['Google Ads', 'YouTube'] end);
end $function$;

-- segredo que o cron manda para a função zernio-sync (só existe no Supabase: usa o Vault)
select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'zernio_sync_secret', 'Autoriza o cron a chamar a função zernio-sync');

create or replace function public.zernio_sync_autorizado(p_segredo text)
 returns boolean
 language sql
 stable security definer
 set search_path to ''
as $$
  select exists (select 1 from vault.decrypted_secrets where name = 'zernio_sync_secret' and decrypted_secret = p_segredo);
$$;
revoke all on function public.zernio_sync_autorizado(text) from public, anon, authenticated;
grant execute on function public.zernio_sync_autorizado(text) to service_role;
