-- Etapas com instruções, mensagem padrão e alerta; responsável comercial (lead) e CS (aluno)
alter table etapas_kanban add column if not exists descricao text;
alter table etapas_kanban add column if not exists mensagem_padrao text;
alter table etapas_kanban add column if not exists alertar_responsavel boolean not null default false;
alter table pessoas add column if not exists responsavel_comercial_id uuid references equipe(id) on delete set null;
alter table alunos add column if not exists responsavel_cs_id uuid references equipe(id) on delete set null;
create index if not exists pessoas_resp_ix on pessoas (workspace_id, responsavel_comercial_id);
create index if not exists alunos_resp_ix on alunos (workspace_id, responsavel_cs_id);

alter table notificacoes add column if not exists pessoa_id uuid references pessoas(id) on delete cascade;
alter table notificacoes alter column projeto_id drop not null;
alter table notificacoes alter column atividade_id drop not null;

create or replace function equipe_avisa(p_ws uuid, p_equipe uuid, p_pessoa uuid, p_titulo text, p_msg text) returns void
language plpgsql security definer set search_path = public as $$
declare e equipe;
begin
  select * into e from equipe where id = p_equipe and workspace_id = p_ws;
  if not found or not e.ativo then return; end if;
  if e.avisar_app then
    insert into notificacoes (workspace_id, destinatario_id, pessoa_id, canal, titulo, mensagem, status, enviada_em)
    values (p_ws, e.id, p_pessoa, 'app', p_titulo, p_msg, 'enviada', now());
  end if;
  if e.avisar_email and e.email is not null then
    insert into notificacoes (workspace_id, destinatario_id, pessoa_id, canal, titulo, mensagem)
    values (p_ws, e.id, p_pessoa, 'email', p_titulo, p_msg);
  end if;
  if e.avisar_whatsapp and e.telefone is not null then
    insert into notificacoes (workspace_id, destinatario_id, pessoa_id, canal, titulo, mensagem)
    values (p_ws, e.id, p_pessoa, 'whatsapp', p_titulo, p_msg);
  end if;
end $$;

create or replace function responsavel_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'pessoas' then
    if new.responsavel_comercial_id is not null
       and not exists (select 1 from equipe where id = new.responsavel_comercial_id and workspace_id = new.workspace_id) then
      raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  else
    if new.responsavel_cs_id is not null
       and not exists (select 1 from equipe where id = new.responsavel_cs_id and workspace_id = new.workspace_id) then
      raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  end if;
  return new;
end $$;
create trigger pessoas_resp_valida_t before insert or update of responsavel_comercial_id on pessoas
  for each row execute function responsavel_valida();
create trigger alunos_resp_valida_t before insert or update of responsavel_cs_id on alunos
  for each row execute function responsavel_valida();

create or replace function pessoa_alerta_etapa() returns trigger
language plpgsql security definer set search_path = public as $$
declare et etapas_kanban;
begin
  if new.responsavel_comercial_id is null then return null; end if;
  if tg_op = 'UPDATE' and new.responsavel_comercial_id is distinct from old.responsavel_comercial_id then
    perform equipe_avisa(new.workspace_id, new.responsavel_comercial_id, new.id,
      'Novo lead sob sua responsabilidade: ' || new.nome, 'Você é o responsável comercial por ' || new.nome || '.');
  end if;
  if new.etapa_kanban_id is not null and (tg_op = 'INSERT' or new.etapa_kanban_id is distinct from old.etapa_kanban_id) then
    select * into et from etapas_kanban where id = new.etapa_kanban_id;
    if found and et.alertar_responsavel then
      perform equipe_avisa(new.workspace_id, new.responsavel_comercial_id, new.id,
        new.nome || ' entrou na etapa «' || et.nome || '»',
        coalesce('O que fazer: ' || nullif(et.descricao, ''), 'Veja o cartão no CRM.'));
    end if;
  end if;
  return null;
end $$;
create trigger pessoas_alerta_t after insert or update of etapa_kanban_id, responsavel_comercial_id on pessoas
  for each row execute function pessoa_alerta_etapa();

create or replace function aluno_alerta_etapa() returns trigger
language plpgsql security definer set search_path = public as $$
declare et etapas_kanban; nm text;
begin
  if new.responsavel_cs_id is null then return null; end if;
  select nome into nm from pessoas where id = new.pessoa_id;
  if tg_op = 'UPDATE' and new.responsavel_cs_id is distinct from old.responsavel_cs_id then
    perform equipe_avisa(new.workspace_id, new.responsavel_cs_id, new.pessoa_id,
      'Novo aluno sob sua responsabilidade: ' || coalesce(nm, ''), 'Você é o CS responsável por ' || coalesce(nm, 'este aluno') || '.');
  end if;
  if new.etapa_kanban_id is not null and (tg_op = 'INSERT' or new.etapa_kanban_id is distinct from old.etapa_kanban_id) then
    select * into et from etapas_kanban where id = new.etapa_kanban_id;
    if found and et.alertar_responsavel then
      perform equipe_avisa(new.workspace_id, new.responsavel_cs_id, new.pessoa_id,
        coalesce(nm, 'Aluno') || ' entrou na etapa «' || et.nome || '»',
        coalesce('O que fazer: ' || nullif(et.descricao, ''), 'Veja o cartão em Alunos.'));
    end if;
  end if;
  return null;
end $$;
create trigger alunos_alerta_t after insert or update of etapa_kanban_id, responsavel_cs_id on alunos
  for each row execute function aluno_alerta_etapa();
