-- v0.163 — Pesquisa disparada quando o aluno entra numa etapa da jornada (Customer Growth, etapa B1).
-- Antes: o gatilho "etapa" só ouvia as etapas do FUNIL (pessoa_funil_historico); uma pesquisa de jornada do aluno nunca disparava sozinha.
-- 1. pesquisas.etapa_aluno_id: a etapa do Kanban de alunos (etapas_kanban, quadro 'alunos') que dispara a pesquisa.
-- 2. pesquisas.produto_id: opcional; só matrículas deste produto (vale para "quando vira aluno" e "quando o aluno entra numa etapa").
-- 3. gatilho novo 'etapa_aluno', ouvindo aluno_historico (tipo 'etapa'), que já registra a primeira etapa e cada mudança.
-- 4. pesquisa_gerar_envios passa a gerar os retroativos dos dois gatilhos de aluno respeitando o produto.
-- Pesquisas que já existem não mudam (produto_id vazio = todos os produtos). Rode depois de 20261115100000_content_segmentos.sql. Idempotente.

alter table pesquisas add column if not exists etapa_aluno_id uuid references etapas_kanban(id) on delete set null;
alter table pesquisas add column if not exists produto_id uuid references produtos(id) on delete set null;
alter table pesquisas drop constraint if exists pesquisas_gatilho_check;
alter table pesquisas add constraint pesquisas_gatilho_check check (gatilho in ('manual', 'cadastro', 'etapa', 'entrada_aluno', 'etapa_aluno'));
alter table pesquisas drop constraint if exists pesquisas_etapa_aluno_ck;
alter table pesquisas add constraint pesquisas_etapa_aluno_ck check (gatilho <> 'etapa_aluno' or etapa_aluno_id is not null);

-- Etapa e produto precisam ser do mesmo cliente; a etapa precisa ser do quadro de alunos.
create or replace function public.pesquisas_valida_aluno() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.etapa_aluno_id is not null and not exists (select 1 from etapas_kanban e where e.id = new.etapa_aluno_id and e.workspace_id = new.workspace_id and e.quadro = 'alunos') then
    raise exception 'A etapa precisa ser uma etapa da jornada do aluno deste cliente'; end if;
  if new.produto_id is not null and not exists (select 1 from produtos p where p.id = new.produto_id and p.workspace_id = new.workspace_id) then
    raise exception 'O produto precisa ser deste cliente'; end if;
  if new.gatilho <> 'etapa_aluno' then new.etapa_aluno_id := null; end if;
  return new;
end $$;
revoke execute on function public.pesquisas_valida_aluno() from public, anon, authenticated;
drop trigger if exists pesquisas_valida_aluno_t on pesquisas;
create trigger pesquisas_valida_aluno_t before insert or update of etapa_aluno_id, produto_id, gatilho, workspace_id on pesquisas
  for each row execute function pesquisas_valida_aluno();

-- Enfileira as pesquisas de aluno de uma matrícula (entrada_aluno ou etapa_aluno), respeitando o produto.
create or replace function public.pesquisa_enfileira_aluno(p_aluno uuid, p_gatilho text, p_etapa uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a alunos;
begin
  select * into a from alunos where id = p_aluno;
  if not found then return; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, status, motivo, origem)
  select s.workspace_id, s.id, a.pessoa_id,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'gatilho'
  from pesquisas s
  where s.workspace_id = a.workspace_id and s.ativa and s.gatilho = p_gatilho
    and (s.produto_id is null or s.produto_id = a.produto_id)
    and (p_gatilho <> 'etapa_aluno' or s.etapa_aluno_id = p_etapa)
  on conflict (pesquisa_id, pessoa_id) do nothing;
end $$;
revoke execute on function public.pesquisa_enfileira_aluno(uuid, text, uuid) from public, anon, authenticated;

-- "Quando vira aluno": mesma regra de antes, agora com o filtro de produto.
create or replace function public.pesquisa_trg_aluno() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pesquisa_enfileira_aluno(new.id, 'entrada_aluno', null);
  return null;
end $$;

-- "Quando o aluno entra numa etapa": cada linha nova de aluno_historico do tipo etapa (inclui a primeira etapa da matrícula).
create or replace function public.pesquisa_trg_etapa_aluno() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'etapa' and new.etapa_kanban_id is not null then
    perform pesquisa_enfileira_aluno(new.aluno_id, 'etapa_aluno', new.etapa_kanban_id);
  end if;
  return null;
end $$;
revoke execute on function public.pesquisa_trg_aluno(), public.pesquisa_trg_etapa_aluno() from public, anon, authenticated;
drop trigger if exists pesquisa_etapa_aluno_t on aluno_historico;
create trigger pesquisa_etapa_aluno_t after insert on aluno_historico for each row execute function pesquisa_trg_etapa_aluno();

-- Retroativos: quem já estava no gatilho antes da pesquisa existir.
create or replace function public.pesquisa_gerar_envios(p_pesquisa uuid) returns int
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; n int;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found or not pode_operar(v_p.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if v_p.gatilho = 'manual' then raise exception 'Pesquisa manual: escolha as pessoas na tela de envios'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, status, motivo, origem)
  select v_p.workspace_id, v_p.id, x.pessoa_id,
    case when v_p.dispensa_qualificado and exists (select 1 from pessoas q where q.id = x.pessoa_id and q.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when v_p.dispensa_qualificado and exists (select 1 from pessoas q where q.id = x.pessoa_id and q.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'retroativo'
  from (
    select id as pessoa_id from pessoas where v_p.gatilho = 'cadastro' and workspace_id = v_p.workspace_id
    union select pessoa_id from alunos where v_p.gatilho = 'entrada_aluno' and workspace_id = v_p.workspace_id and (v_p.produto_id is null or produto_id = v_p.produto_id)
    union select pessoa_id from pessoa_funil_historico where v_p.gatilho = 'etapa' and workspace_id = v_p.workspace_id and tipo = 'etapa' and para = v_p.gatilho_etapa and (v_p.funil_id is null or funil_id = v_p.funil_id)
    union select a.pessoa_id from aluno_historico h join alunos a on a.id = h.aluno_id
      where v_p.gatilho = 'etapa_aluno' and h.workspace_id = v_p.workspace_id and h.tipo = 'etapa' and h.etapa_kanban_id = v_p.etapa_aluno_id
        and (v_p.produto_id is null or a.produto_id = v_p.produto_id)
  ) x
  on conflict (pesquisa_id, pessoa_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.pesquisa_gerar_envios(uuid) from public, anon;
grant execute on function public.pesquisa_gerar_envios(uuid) to authenticated;

-- Para desfazer (na ordem):
-- drop trigger if exists pesquisa_etapa_aluno_t on aluno_historico; drop function if exists public.pesquisa_trg_etapa_aluno();
-- create or replace function public.pesquisa_trg_aluno() ... (versão de 20261006230000_pesquisas.sql: perform pesquisa_enfileira(new.workspace_id, new.pessoa_id, 'entrada_aluno', null, null));
-- e pesquisa_gerar_envios da mesma migration; drop function if exists public.pesquisa_enfileira_aluno(uuid, text, uuid);
-- drop trigger if exists pesquisas_valida_aluno_t on pesquisas; drop function if exists public.pesquisas_valida_aluno();
-- update pesquisas set gatilho = 'manual' where gatilho = 'etapa_aluno';
-- alter table pesquisas drop constraint if exists pesquisas_etapa_aluno_ck; alter table pesquisas drop constraint pesquisas_gatilho_check;
-- alter table pesquisas add constraint pesquisas_gatilho_check check (gatilho in ('manual', 'cadastro', 'etapa', 'entrada_aluno'));
-- alter table pesquisas drop column if exists produto_id, drop column if exists etapa_aluno_id;
