-- v0.22 (PENDENTE DE APLICAÇÃO): funções que CONCEDEM e RETIRAM acesso de usuários ao workspace.
-- Foram separadas porque alteram quem pode entrar no sistema; revise e rode no SQL Editor do Supabase.
-- Depende de 20261006370000_empresa_funcoes_acessos.sql (já aplicada).

-- Dar/retirar acesso conforme o cadastro da pessoa na Equipe (função + "pode entrar no sistema").
create or replace function public.sincroniza_acesso(p_equipe uuid) returns text language plpgsql security definer set search_path to 'public' as $$
declare e equipe; f funcoes; uid uuid; novo text;
begin
  select * into e from equipe where id = p_equipe;
  if not found then return 'inexistente'; end if;
  if auth.uid() is not null and not eh_admin(e.workspace_id) then raise exception 'Só administradores gerenciam acessos'; end if;
  perform set_config('growths.sync', '1', true);
  if coalesce(e.email, '') = '' then return 'sem_email'; end if;
  select id into uid from auth.users where lower(email) = lower(e.email) limit 1;
  if not coalesce(e.acesso_ativo, false) or e.funcao_id is null then
    if uid is not null then
      if exists (select 1 from workspace_membros where workspace_id = e.workspace_id and user_id = uid and papel = 'admin')
         and (select count(*) from workspace_membros where workspace_id = e.workspace_id and papel = 'admin') <= 1 then
        raise exception 'Não é possível remover o último administrador';
      end if;
      delete from workspace_membros where workspace_id = e.workspace_id and user_id = uid;
    end if;
    update equipe set user_id = null where id = e.id and user_id is not null;
    return 'sem_acesso';
  end if;
  select * into f from funcoes where id = e.funcao_id and workspace_id = e.workspace_id;
  if not found then raise exception 'Função inexistente neste workspace'; end if;
  if uid is null then return 'convite_pendente'; end if;
  novo := papel_da_funcao(f);
  if novo <> 'admin' and exists (select 1 from workspace_membros where workspace_id = e.workspace_id and user_id = uid and papel = 'admin')
     and (select count(*) from workspace_membros where workspace_id = e.workspace_id and papel = 'admin') <= 1 then
    raise exception 'Não é possível tirar o último administrador do cargo de administrador';
  end if;
  insert into workspace_membros (workspace_id, user_id, papel, funcao_id) values (e.workspace_id, uid, novo, f.id)
  on conflict (workspace_id, user_id) do update set papel = excluded.papel, funcao_id = excluded.funcao_id;
  update equipe set user_id = uid where id = e.id and user_id is distinct from uid;
  return 'ativo';
end $$;

create or replace function public.equipe_sincroniza() returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null or eh_admin(new.workspace_id) then perform sincroniza_acesso(new.id); end if;
  return null;
end $$;
create trigger equipe_sincroniza_t after insert or update of funcao_id, acesso_ativo, email on public.equipe for each row execute function public.equipe_sincroniza();

-- Ao entrar, quem foi cadastrado na Equipe com acesso ativo e e-mail igual ao do login passa a ter acesso.
-- Importante: exija confirmação de e-mail no Supabase Auth, senão alguém poderia se cadastrar com o e-mail de outra pessoa.
create or replace function public.aceitar_convites() returns int language plpgsql security definer set search_path to 'public' as $$
declare em text; e record; f funcoes; n int := 0;
begin
  if auth.uid() is null then return 0; end if;
  select email into em from auth.users where id = auth.uid();
  if coalesce(em, '') = '' then return 0; end if;
  perform set_config('growths.sync', '1', true);
  for e in select * from equipe where lower(email) = lower(em) and acesso_ativo and funcao_id is not null and (user_id is null or user_id = auth.uid()) loop
    select * into f from funcoes where id = e.funcao_id and workspace_id = e.workspace_id;
    if found then
      insert into workspace_membros (workspace_id, user_id, papel, funcao_id) values (e.workspace_id, auth.uid(), papel_da_funcao(f), f.id) on conflict (workspace_id, user_id) do nothing;
      update equipe set user_id = auth.uid() where id = e.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

grant execute on function public.aceitar_convites(), public.sincroniza_acesso(uuid) to authenticated;
