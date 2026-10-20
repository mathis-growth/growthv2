-- v0.23: histórico de responsáveis (comercial e CS) e "vendedor" gravado em vendas e contratos.
-- Já aplicado no banco do projeto; arquivo guardado para versionamento (idempotente).
create table if not exists responsavel_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  tipo text not null check (tipo in ('comercial','cs')),
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  aluno_id uuid references alunos(id) on delete cascade,
  de_equipe_id uuid, para_equipe_id uuid, de_nome text, para_nome text,
  alterado_por uuid, alterado_por_email text, motivo text,
  alterado_em timestamptz not null default now());
create index if not exists responsavel_historico_pessoa_idx on responsavel_historico (pessoa_id, alterado_em desc);
create index if not exists responsavel_historico_ws_idx on responsavel_historico (workspace_id, alterado_em desc);
alter table responsavel_historico enable row level security;
drop policy if exists responsavel_historico_leitura on responsavel_historico;
create policy responsavel_historico_leitura on responsavel_historico for select using (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on responsavel_historico;
create policy perm_ler on responsavel_historico as restrictive for select using (perm(workspace_id, 'ler', array['vendas','revops','adm','prj','fin']));

alter table vendas add column if not exists vendedor_id uuid;
alter table contratos add column if not exists vendedor_id uuid;

create or replace function resp_hist_pessoa() returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if tg_op = 'INSERT' then
    if new.responsavel_comercial_id is null then return null; end if;
  elsif new.responsavel_comercial_id is not distinct from old.responsavel_comercial_id then return null;
  end if;
  insert into responsavel_historico (workspace_id, tipo, pessoa_id, de_equipe_id, para_equipe_id, de_nome, para_nome, alterado_por, alterado_por_email, motivo)
  values (new.workspace_id, 'comercial', new.id,
    case when tg_op = 'UPDATE' then old.responsavel_comercial_id end, new.responsavel_comercial_id,
    case when tg_op = 'UPDATE' then (select nome from equipe where id = old.responsavel_comercial_id) end,
    (select nome from equipe where id = new.responsavel_comercial_id),
    auth.uid(), auth.jwt() ->> 'email', case when tg_op = 'INSERT' then 'na criação do lead' end);
  return null;
end $f$;
drop trigger if exists pessoas_resp_hist_t on pessoas;
create trigger pessoas_resp_hist_t after insert or update of responsavel_comercial_id on pessoas for each row execute function resp_hist_pessoa();

create or replace function resp_hist_aluno() returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if tg_op = 'INSERT' then
    if new.responsavel_cs_id is null then return null; end if;
  elsif new.responsavel_cs_id is not distinct from old.responsavel_cs_id then return null;
  end if;
  insert into responsavel_historico (workspace_id, tipo, pessoa_id, aluno_id, de_equipe_id, para_equipe_id, de_nome, para_nome, alterado_por, alterado_por_email, motivo)
  values (new.workspace_id, 'cs', new.pessoa_id, new.id,
    case when tg_op = 'UPDATE' then old.responsavel_cs_id end, new.responsavel_cs_id,
    case when tg_op = 'UPDATE' then (select nome from equipe where id = old.responsavel_cs_id) end,
    (select nome from equipe where id = new.responsavel_cs_id),
    auth.uid(), auth.jwt() ->> 'email', case when tg_op = 'INSERT' then 'na matrícula' end);
  return null;
end $f$;
drop trigger if exists alunos_resp_hist_t on alunos;
create trigger alunos_resp_hist_t after insert or update of responsavel_cs_id on alunos for each row execute function resp_hist_aluno();

create or replace function alunos_herda_cs() returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if new.responsavel_cs_id is null then
    select a.responsavel_cs_id into new.responsavel_cs_id from alunos a
    where a.pessoa_id = new.pessoa_id and a.responsavel_cs_id is not null order by a.entrou_em desc limit 1;
  end if;
  return new;
end $f$;
drop trigger if exists alunos_herda_cs_t on alunos;
create trigger alunos_herda_cs_t before insert on alunos for each row execute function alunos_herda_cs();

create or replace function vendedor_da_pessoa() returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if new.vendedor_id is null then
    select p.responsavel_comercial_id into new.vendedor_id from pessoas p where p.id = new.pessoa_id;
  end if;
  return new;
end $f$;
drop trigger if exists vendas_vendedor_t on vendas;
create trigger vendas_vendedor_t before insert on vendas for each row execute function vendedor_da_pessoa();
drop trigger if exists contratos_vendedor_t on contratos;
create trigger contratos_vendedor_t before insert on contratos for each row execute function vendedor_da_pessoa();
