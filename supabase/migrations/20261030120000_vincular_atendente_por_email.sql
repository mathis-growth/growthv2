-- Vincula a pessoa da Equipe ao usuário autenticado pelo e-mail.
-- Executar depois da migration original da Central de Atendimento.
create or replace function public.atd_contexto(p_ws uuid) returns jsonb
language plpgsql volatile security definer set search_path=public as $$
declare n text; email_login text;
begin
 if auth.uid() is null or not pertence_ao_workspace(p_ws) or not perm(p_ws,'ler',array['vendas']) then
  raise exception 'Sem acesso ao Atendimento.' using errcode='42501';
 end if;
 select nome into n from equipe
  where workspace_id=p_ws and user_id=auth.uid() and ativo limit 1;
 if n is null then
  select email into email_login from auth.users where id=auth.uid();
  if email_login is not null then
   update equipe set user_id=auth.uid()
    where id=(select id from equipe where workspace_id=p_ws and ativo
      and lower(email)=lower(email_login) and user_id is null order by criado_em limit 1)
    returning nome into n;
  end if;
 end if;
 return jsonb_build_object('user_id',auth.uid(),'nome',n,
  'editar',perm(p_ws,'editar',array['vendas']),'admin',eh_admin(p_ws));
end $$;
revoke all on function public.atd_contexto(uuid) from public,anon;
grant execute on function public.atd_contexto(uuid) to authenticated;
