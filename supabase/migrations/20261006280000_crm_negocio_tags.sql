-- CRM: tags, ganho/perdido com motivo.
create table motivos_resultado (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  tipo text not null check (tipo in ('ganho', 'perdido')),
  nome text not null,
  ativo boolean not null default true,
  unique (workspace_id, tipo, nome)
);
alter table motivos_resultado enable row level security;
create policy motivos_resultado_rls on motivos_resultado for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

alter table pessoas add column tags text[] not null default '{}';
alter table pessoas add column negocio_status text not null default 'aberto' check (negocio_status in ('aberto', 'ganho', 'perdido'));
alter table pessoas add column negocio_motivo_id uuid references motivos_resultado(id);
alter table pessoas add column negocio_obs text;
alter table pessoas add column negocio_fechado_em timestamptz;
create index pessoas_negocio_ix on pessoas (workspace_id, negocio_status);
create index pessoas_tags_ix on pessoas using gin (tags);
-- quem já era cliente antes deste recurso entra como ganho
update pessoas set negocio_status = 'ganho', negocio_fechado_em = coalesce(convertido_em, criado_em) where status_funil = 'cliente';

create or replace function pessoas_negocio_antes() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- virou cliente sem fechamento manual: negócio ganho
  if new.status_funil = 'cliente' and old.status_funil = 'lead' and new.negocio_status = 'aberto' then
    new.negocio_status := 'ganho';
  end if;
  if new.negocio_status is distinct from old.negocio_status then
    new.negocio_fechado_em := case when new.negocio_status = 'aberto' then null else now() end;
    if new.negocio_status = 'aberto' then new.negocio_motivo_id := null; end if;
  end if;
  if new.negocio_motivo_id is not null and not exists (
       select 1 from motivos_resultado where id = new.negocio_motivo_id and workspace_id = new.workspace_id
         and tipo = new.negocio_status) then
    raise exception 'O motivo precisa ser do tipo "%" e do mesmo workspace', new.negocio_status;
  end if;
  return new;
end $$;
create trigger pessoas_negocio_antes before update on pessoas
  for each row execute function pessoas_negocio_antes();

create or replace function pessoas_negocio_historico() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.negocio_status is distinct from old.negocio_status then
    insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
    values (new.workspace_id, new.id, 'negocio',
            old.negocio_status,
            new.negocio_status || coalesce(' (' || (select nome from motivos_resultado where id = new.negocio_motivo_id) || ')', ''));
  end if;
  return null;
end $$;
create trigger pessoas_negocio_historico after update on pessoas
  for each row execute function pessoas_negocio_historico();

create or replace function _provisionar_motivos(p_ws uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into motivos_resultado (workspace_id, tipo, nome)
  select p_ws, m.t, m.n from (values
    ('ganho', 'Preço e condição de pagamento'), ('ganho', 'Confiança na marca ou indicação'), ('ganho', 'Prova e depoimentos'),
    ('ganho', 'Oferta e bônus'), ('ganho', 'Urgência e prazo'), ('ganho', 'Outro'),
    ('perdido', 'Preço'), ('perdido', 'Sem orçamento agora'), ('perdido', 'Sem tempo ou momento errado'),
    ('perdido', 'Escolheu concorrente'), ('perdido', 'Sem resposta'), ('perdido', 'Fora do perfil'), ('perdido', 'Outro')
  ) as m(t, n)
  on conflict (workspace_id, tipo, nome) do nothing;
end $$;
select _provisionar_motivos(id) from workspaces;

alter function provisionar_workspace(text) rename to _provisionar_pre_motivos;
create function provisionar_workspace(p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare ws uuid;
begin
  ws := _provisionar_pre_motivos(p_nome);
  perform _provisionar_motivos(ws);
  return ws;
end $$;
revoke execute on function _provisionar_motivos(uuid) from public, anon, authenticated;
revoke execute on function _provisionar_pre_motivos(text) from public, anon, authenticated;
grant execute on function provisionar_workspace(text) to authenticated;
