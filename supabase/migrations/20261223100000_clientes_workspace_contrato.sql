-- v0.231 — Clientes da Mathisa: o Growths do cliente nasce do contrato; inativar, reativar e excluir clientes.
-- Decisões da Rebecka (02/11):
--  · inativar: o cliente some da lista de workspaces de todos e perde o acesso; os dados ficam e dá para reativar;
--  · excluir: só depois de inativar, digitando o nome do cliente; apaga tudo dele, sem volta;
--  · o workspace é criado sozinho ao ativar o contrato, só para produtos marcados "inclui o Growths do cliente";
--  · o contrato traz o nome da empresa, CNPJ e razão social, o responsável e o e-mail de acesso, e o pacote de acesso.
-- Só vale para contratos da Mathisa (workspace de agência). Aditivo e idempotente. Rode depois de 20261222100000_pesquisa_destino_cliente.sql.

alter table workspaces add column if not exists inativo_em timestamptz;
alter table workspaces add column if not exists inativo_por uuid;
alter table workspaces add column if not exists inativo_motivo text;
alter table workspaces add column if not exists contrato_origem_id uuid references contratos(id) on delete set null;

alter table produtos add column if not exists cria_workspace boolean not null default false;
alter table produtos add column if not exists workspace_modo text;
alter table produtos add column if not exists workspace_pacote_id uuid references pacotes_acesso(id) on delete set null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'produtos_workspace_modo_ck') then
    alter table produtos add constraint produtos_workspace_modo_ck check (workspace_modo is null or workspace_modo in ('starter', 'completo')); end if;
end $$;

alter table contratos add column if not exists empresa_nome text;
alter table contratos add column if not exists empresa_razao_social text;
alter table contratos add column if not exists empresa_cnpj text;
alter table contratos add column if not exists responsavel_nome text;
alter table contratos add column if not exists responsavel_email text;
alter table contratos add column if not exists pacote_id uuid references pacotes_acesso(id) on delete set null;
alter table contratos add column if not exists cliente_workspace_id uuid references workspaces(id) on delete set null;
alter table contratos add column if not exists cliente_workspace_erro text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'contratos_resp_email_ck') then
    alter table contratos add constraint contratos_resp_email_ck check (responsavel_email is null or responsavel_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'); end if;
end $$;

-- registro do que foi excluído (só a equipe interna vê)
create table if not exists workspaces_excluidos (
  id uuid primary key,
  nome text not null,
  contrato_origem_id uuid,
  excluido_em timestamptz not null default now(),
  excluido_por uuid default auth.uid(),
  motivo text
);
alter table workspaces_excluidos enable row level security;
drop policy if exists workspaces_excluidos_interna on workspaces_excluidos;
create policy workspaces_excluidos_interna on workspaces_excluidos for select to authenticated using (sou_equipe_interna());
revoke all on workspaces_excluidos from anon, authenticated;
grant select on workspaces_excluidos to authenticated;

-- 1. cliente inativo: só a equipe interna continua entrando
create or replace function public.pertence_ao_workspace(ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from workspace_membros m join workspaces w on w.id = m.workspace_id
    where m.workspace_id = ws and m.user_id = auth.uid() and (w.inativo_em is null or sou_equipe_interna())
  );
$$;

create or replace function public.workspace_inativar(p_ws uuid, p_motivo text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna inativa clientes.'; end if;
  if exists (select 1 from workspaces where id = p_ws and coalesce(agencia, false)) then raise exception 'O workspace da equipe interna não pode ser inativado.'; end if;
  update workspaces set inativo_em = now(), inativo_por = auth.uid(), inativo_motivo = nullif(left(btrim(coalesce(p_motivo, '')), 500), '') where id = p_ws and inativo_em is null;
  if not found and not exists (select 1 from workspaces where id = p_ws) then raise exception 'Cliente não encontrado.'; end if;
end $$;

create or replace function public.workspace_reativar(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna reativa clientes.'; end if;
  update workspaces set inativo_em = null, inativo_por = null, inativo_motivo = null where id = p_ws;
  if not found then raise exception 'Cliente não encontrado.'; end if;
end $$;

-- 2. excluir: só inativo, digitando o nome; apaga o workspace e tudo o que é dele
create or replace function public.workspace_excluir(p_ws uuid, p_nome text) returns void
language plpgsql security definer set search_path = public as $$
declare w workspaces; r record; v_pend boolean; i int;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna exclui clientes.'; end if;
  select * into w from workspaces where id = p_ws;
  if not found then raise exception 'Cliente não encontrado.'; end if;
  if coalesce(w.agencia, false) then raise exception 'O workspace da equipe interna não pode ser excluído.'; end if;
  if w.inativo_em is null then raise exception 'Inative o cliente antes de excluir.'; end if;
  if btrim(coalesce(p_nome, '')) <> btrim(w.nome) then raise exception 'Digite o nome do cliente exatamente como aparece para confirmar.'; end if;
  insert into workspaces_excluidos (id, nome, contrato_origem_id, motivo) values (w.id, w.nome, w.contrato_origem_id, w.inativo_motivo) on conflict (id) do nothing;
  update contratos set cliente_workspace_id = null where cliente_workspace_id = p_ws;
  update workspaces set casa_de = null where casa_de = p_ws;
  -- tabelas que apontam para o workspace sem "apagar junto" (ex.: atendimento): apaga antes, em algumas passadas por causa da ordem entre elas
  for i in 1..6 loop
    v_pend := false;
    for r in select c.conrelid::regclass::text tb, a.attname col from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
             where c.contype = 'f' and c.confrelid = 'workspaces'::regclass and c.conrelid <> 'workspaces'::regclass and c.confdeltype in ('a', 'r') loop
      begin
        execute format('delete from %s where %I = $1', r.tb, r.col) using p_ws;
      exception when foreign_key_violation then v_pend := true;
      end;
    end loop;
    exit when not v_pend;
  end loop;
  delete from workspaces where id = p_ws;
end $$;
revoke all on function public.workspace_inativar(uuid, text) from public, anon;
revoke all on function public.workspace_reativar(uuid) from public, anon;
revoke all on function public.workspace_excluir(uuid, text) from public, anon;
grant execute on function public.workspace_inativar(uuid, text) to authenticated;
grant execute on function public.workspace_reativar(uuid) to authenticated;
grant execute on function public.workspace_excluir(uuid, text) to authenticated;

-- a lista de clientes (Configurações → Pacotes de acesso) passa a mostrar a situação e de qual contrato o cliente veio
create or replace function public.clientes_acesso() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê os pacotes dos clientes'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.nome, 'modo_produto', w.modo_produto, 'pacote_id', w.pacote_id, 'liga', to_jsonb(w.acesso_liga), 'desliga', to_jsonb(w.acesso_desliga),
                     'inativo_em', w.inativo_em, 'inativo_motivo', w.inativo_motivo, 'contrato_origem_id', w.contrato_origem_id, 'contrato_numero', c.numero, 'criado_em', w.criado_em) order by w.inativo_em is not null, w.nome)
                   from workspaces w left join contratos c on c.id = w.contrato_origem_id where not coalesce(w.agencia, false) and w.casa_de is null), '[]'::jsonb);
end $$;

-- 3. o Growths do cliente nasce do contrato (Mathisa), quando um produto do contrato inclui o Growths
create or replace function public.contrato_criar_workspace(p_contrato uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c contratos; p produtos; v_nome text; w uuid; v_pac uuid; v_fun uuid; v_pessoa text;
begin
  select * into c from contratos where id = p_contrato;
  if not found then raise exception 'Contrato não encontrado.'; end if;
  if c.cliente_workspace_id is not null then return c.cliente_workspace_id; end if;
  if not exists (select 1 from workspaces where id = c.workspace_id and coalesce(agencia, false)) then return null; end if;
  select pr.* into p from contrato_itens it join produtos pr on pr.id = it.produto_id where it.contrato_id = c.id and pr.cria_workspace order by pr.nome limit 1;
  if not found then return null; end if;
  select nome into v_pessoa from pessoas where id = c.pessoa_id;
  v_nome := left(coalesce(nullif(btrim(c.empresa_nome), ''), v_pessoa, 'Cliente'), 120);
  w := provisionar_workspace(v_nome);
  v_pac := coalesce(c.pacote_id, p.workspace_pacote_id);
  update workspaces set modo_produto = coalesce(p.workspace_modo, 'completo'), contrato_origem_id = c.id, pacote_id = coalesce(v_pac, pacote_id) where id = w;
  insert into empresa (workspace_id, nome, razao_social, cnpj, responsavel_nome, responsavel_email)
    values (w, v_nome, nullif(btrim(c.empresa_razao_social), ''), nullif(btrim(c.empresa_cnpj), ''), nullif(btrim(c.responsavel_nome), ''), lower(nullif(btrim(c.responsavel_email), '')))
    on conflict (workspace_id) do update set nome = excluded.nome, razao_social = coalesce(excluded.razao_social, empresa.razao_social), cnpj = coalesce(excluded.cnpj, empresa.cnpj),
      responsavel_nome = coalesce(excluded.responsavel_nome, empresa.responsavel_nome), responsavel_email = coalesce(excluded.responsavel_email, empresa.responsavel_email);
  -- convite: o responsável entra como Administrador quando criar a conta com este e-mail
  if nullif(btrim(c.responsavel_email), '') is not null then
    select id into v_fun from funcoes where workspace_id = w and administrador order by (nome = 'Administrador') desc, nome limit 1;
    if v_fun is null then
      insert into funcoes (workspace_id, nome, descricao, administrador) values (w, 'Administrador', 'Acesso total ao Growths da empresa.', true) returning id into v_fun;
    end if;
    perform set_config('growths.sync', '1', true);
    insert into equipe (workspace_id, nome, email, acesso_ativo, funcao_id)
      values (w, coalesce(nullif(btrim(c.responsavel_nome), ''), v_pessoa, 'Responsável'), lower(btrim(c.responsavel_email)), true, v_fun);
    perform set_config('growths.sync', '', true);
  end if;
  update contratos set cliente_workspace_id = w, cliente_workspace_erro = null where id = c.id;
  if c.pessoa_id is not null then insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
    values (c.workspace_id, c.pessoa_id, 'growths_cliente', null, left('Growths criado pelo contrato #' || c.numero || ': ' || v_nome, 300)); end if;
  return w;
end $$;
revoke all on function public.contrato_criar_workspace(uuid) from public, anon, authenticated;

create or replace function public.contratos_cria_workspace() returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    perform contrato_criar_workspace(new.id);
  exception when others then
    update contratos set cliente_workspace_erro = left('Não consegui criar o Growths do cliente: ' || sqlerrm, 500) where id = new.id;
  end;
  return null;
end $$;
drop trigger if exists contratos_cria_workspace_t on contratos;
create trigger contratos_cria_workspace_t after update of status on contratos for each row
  when (new.status = 'ativo' and old.status is distinct from 'ativo') execute function contratos_cria_workspace();

-- tentar de novo (quando deu erro ou o produto foi marcado depois)
create or replace function public.contrato_criar_workspace_manual(p_contrato uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c contratos; w uuid;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna cria o Growths do cliente.'; end if;
  select * into c from contratos where id = p_contrato;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Contrato não encontrado.'; end if;
  if c.status <> 'ativo' then raise exception 'Ative o contrato antes.'; end if;
  w := contrato_criar_workspace(p_contrato);
  if w is null then raise exception 'Nenhum produto deste contrato está marcado "inclui o Growths do cliente".'; end if;
  return w;
end $$;
revoke all on function public.contrato_criar_workspace_manual(uuid) from public, anon;
grant execute on function public.contrato_criar_workspace_manual(uuid) to authenticated;

-- Para desfazer: drop trigger contratos_cria_workspace_t on contratos; drop function contratos_cria_workspace(), contrato_criar_workspace(uuid),
--   contrato_criar_workspace_manual(uuid), workspace_excluir(uuid, text), workspace_reativar(uuid), workspace_inativar(uuid, text);
-- pertence_ao_workspace volta a: select exists (select 1 from workspace_membros m where m.workspace_id = ws and m.user_id = auth.uid());
-- as colunas novas podem ficar.
