-- v0.55: Growth Starter = workspace de consultoria (cliente que ainda não contratou o Growths).
alter table workspaces add column if not exists modo_produto text not null default 'completo' check (modo_produto in ('completo', 'starter'));

create or replace function criar_workspace_starter(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  if coalesce(trim(p_nome), '') = '' then raise exception 'Informe o nome do cliente'; end if;
  w := provisionar_workspace(trim(p_nome));
  update workspaces set modo_produto = 'starter' where id = w;
  return w;
end $$;
revoke execute on function criar_workspace_starter(text) from public, anon;
grant execute on function criar_workspace_starter(text) to authenticated;
