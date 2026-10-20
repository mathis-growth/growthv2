-- v0.57: seletor de cliente só para a equipe interna (a agência). Cliente vê apenas o próprio ambiente.
alter table workspaces add column if not exists agencia boolean not null default false;
update workspaces set agencia = true where id = '8fd51ed1-0843-49d8-a2aa-b9bb99c59171'; -- Mathisa

create or replace function sou_equipe_interna() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from workspace_membros m join workspaces w on w.id = m.workspace_id where m.user_id = auth.uid() and w.agencia);
$$;
revoke execute on function sou_equipe_interna() from public, anon;
grant execute on function sou_equipe_interna() to authenticated;

-- criar cliente: só equipe interna
create or replace function criar_workspace_cliente(p_nome text, p_modo text default 'starter') returns uuid
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna cria clientes'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Informe o nome do cliente'; end if;
  if p_modo not in ('starter', 'completo') then raise exception 'Tipo de acesso inválido'; end if;
  w := provisionar_workspace(trim(p_nome));
  update workspaces set modo_produto = p_modo where id = w;
  return w;
end $$;
revoke execute on function criar_workspace_cliente(text, text) from public, anon;
grant execute on function criar_workspace_cliente(text, text) to authenticated;

create or replace function criar_workspace_starter(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
begin
  return criar_workspace_cliente(p_nome, 'starter');
end $$;
