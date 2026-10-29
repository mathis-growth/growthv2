-- =====================================================================
-- v0.163 — Customer Growth: Jornada e Inteligência do Cliente (RevOps).
-- Junta, na ordem, as migrações 20261116100000 a 20261123100000. Tudo ou nada: se algo falhar, nada fica gravado.
-- Pode ser rodado de novo sem erro. Precisa da v0.132 (alertas) e da v0.113 (chaves de API por escopo) já aplicadas.
-- Depois de rodar: recarregar o Growths. A tela nova fica em RevOps → Customer Growth.
-- =====================================================================
begin;

do $pre$
declare falta text[] := '{}';
begin
  if to_regclass('public.alertas') is null or to_regclass('public.alertas_config') is null or to_regprocedure('public.growths_rodar_agendado(timestamptz)') is null then falta := falta || 'RODAR_v0.132_alertas.sql (alertas e agendador)'::text; end if;
  if to_regprocedure('public.chave_api_ws_escopo(text, text)') is null then falta := falta || 'RODAR_v0.113_leads.sql (chaves de API por escopo)'::text; end if;
  if to_regclass('public.pessoa_toques') is null then falta := falta || 'migração 20261008220000_estrategias_jornada.sql (pontos de contato)'::text; end if;
  if to_regprocedure('public.heavyops_painel(uuid, integer)') is null or to_regprocedure('public.funil_analise(uuid, date, date, uuid, uuid)') is null then falta := falta || 'migrações do RevOps (heavy_ops e funil_pos_compra)'::text; end if;
  if cardinality(falta) > 0 then raise exception 'Antes de rodar a v0.163, aplique: %', array_to_string(falta, '; '); end if;
end $pre$;
-- ===================== 20261116100000_pesquisa_etapa_aluno.sql =====================
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

-- ===================== 20261117100000_jornada_produto.sql =====================
-- v0.163 — Jornada do produto (Customer Growth, etapas B2 e B4).
-- A jornada de depois da compra passa a ser de cada produto, com versão. As etapas continuam em etapas_kanban (quadro 'alunos'):
-- uma etapa sem jornada_id é da "Jornada geral" (as etapas de hoje, que continuam funcionando igual).
-- 1. jornadas: cabeçalho da jornada de um produto (ou modelo, sem produto), com versão e situação.
--    rascunho = editando; publicada = a versão em uso para matrículas novas (uma por produto); anterior = versão antiga que
--    ainda pode ter alunos (quem escolheu "continuar"); arquivada = fora de uso.
-- 2. etapas_kanban.jornada_id. O nome da etapa passa a ser único dentro da jornada (e na jornada geral, como antes).
--    Etapa de jornada que já não é rascunho não muda de nome, ordem nem jornada, e não é criada nem apagada (é a foto da versão).
-- 3. alunos.jornada_id. Gatilho antes de gravar: matrícula nova de um produto com jornada publicada já nasce na primeira etapa dela;
--    sem jornada publicada, nasce na primeira etapa da jornada geral (como hoje). Mover o cartão só para etapa da mesma jornada.
--    Assim processar_venda, ativar_contrato e cadastrar_cliente_historico não precisam ser reescritas.
-- 4. Análise de funil (pós-compra) e Dashboard de RevOps: a ordem das etapas passa a ser comparada dentro da mesma jornada.
-- Rode depois de 20261116100000_pesquisa_etapa_aluno.sql. Idempotente.

create table if not exists jornadas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  produto_id uuid references produtos(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  modelo boolean not null default false,
  versao int not null default 1 check (versao >= 1),
  status text not null default 'rascunho' check (status in ('rascunho', 'publicada', 'anterior', 'arquivada')),
  descricao text,
  baseada_em uuid references jornadas(id) on delete set null,
  publicada_em timestamptz,
  publicada_por uuid,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  check (modelo = (produto_id is null)),
  check (not modelo or status in ('rascunho', 'publicada', 'arquivada'))
);
create unique index if not exists jornadas_publicada_uq on jornadas (produto_id) where status = 'publicada' and produto_id is not null;
create unique index if not exists jornadas_versao_uq on jornadas (produto_id, versao) where produto_id is not null;
create unique index if not exists jornadas_rascunho_uq on jornadas (produto_id) where status = 'rascunho' and produto_id is not null;
create index if not exists jornadas_ws on jornadas (workspace_id, produto_id);

create or replace function public.jornadas_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.produto_id is not null and not exists (select 1 from produtos where id = new.produto_id and workspace_id = new.workspace_id) then
    raise exception 'O produto precisa ser deste cliente'; end if;
  if tg_op = 'UPDATE' then
    if new.produto_id is distinct from old.produto_id or new.workspace_id <> old.workspace_id or new.versao <> old.versao or new.modelo <> old.modelo then
      raise exception 'Produto, cliente, versão e tipo da jornada não mudam depois de criada'; end if;
    if old.status <> 'rascunho' and new.status = 'rascunho' then raise exception 'Uma versão publicada não volta a ser rascunho: crie uma nova versão'; end if;
  end if;
  if new.status = 'publicada' and new.publicada_em is null then new.publicada_em := now(); new.publicada_por := coalesce(new.publicada_por, auth.uid()); end if;
  return new;
end $$;
revoke execute on function public.jornadas_valida() from public, anon, authenticated;
drop trigger if exists jornadas_valida_t on jornadas;
create trigger jornadas_valida_t before insert or update on jornadas for each row execute function jornadas_valida();

alter table jornadas enable row level security;
drop policy if exists jornadas_acesso on jornadas;
create policy jornadas_acesso on jornadas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_inserir on jornadas; drop policy if exists perm_alterar on jornadas; drop policy if exists perm_excluir on jornadas;
create policy perm_inserir on jornadas as restrictive for insert with check (perm(workspace_id, 'editar', array['revops', 'vendas', 'cad']));
create policy perm_alterar on jornadas as restrictive for update using (perm(workspace_id, 'editar', array['revops', 'vendas', 'cad'])) with check (perm(workspace_id, 'editar', array['revops', 'vendas', 'cad']));
create policy perm_excluir on jornadas as restrictive for delete using (perm(workspace_id, 'editar', array['revops', 'vendas', 'cad']));
grant select, insert, update, delete on jornadas to authenticated;

-- ---------- etapas ----------
alter table etapas_kanban add column if not exists jornada_id uuid references jornadas(id) on delete cascade;
create index if not exists etapas_kanban_jornada on etapas_kanban (jornada_id, ordem);
-- a trava antiga (workspace, quadro, nome) sai, pelo nome que tiver no banco
do $u$
declare c text;
begin
  for c in select con.conname from pg_constraint con
            where con.conrelid = 'public.etapas_kanban'::regclass and con.contype = 'u'
              and (select array_agg(a.attname::text order by a.attname) from unnest(con.conkey) k join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k) = array['nome', 'quadro', 'workspace_id'] loop
    execute format('alter table etapas_kanban drop constraint %I', c);
  end loop;
end $u$;
create unique index if not exists etapas_kanban_geral_uq on etapas_kanban (workspace_id, quadro, nome) where jornada_id is null;
create unique index if not exists etapas_kanban_jornada_uq on etapas_kanban (jornada_id, nome) where jornada_id is not null;

create or replace function public.etapas_jornada_valida() returns trigger language plpgsql security definer set search_path = public as $$
declare j jornadas; jo jornadas;
begin
  if tg_op in ('UPDATE', 'DELETE') and old.jornada_id is not null then
    select * into jo from jornadas where id = old.jornada_id;
    if found and jo.status <> 'rascunho' and (tg_op = 'DELETE' or new.nome <> old.nome or new.ordem <> old.ordem or new.jornada_id is distinct from old.jornada_id) then
      -- apagar a jornada inteira (cascade) é permitido; mexer numa etapa solta de versão publicada, não
      if tg_op = 'DELETE' and not exists (select 1 from jornadas where id = old.jornada_id) then return old; end if;
      raise exception 'A versão % da jornada já foi publicada: crie uma nova versão para mudar as etapas', jo.versao;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if new.jornada_id is not null then
    select * into j from jornadas where id = new.jornada_id;
    if not found or j.workspace_id <> new.workspace_id then raise exception 'A jornada precisa ser deste cliente'; end if;
    if new.quadro <> 'alunos' then raise exception 'Só etapas da jornada do aluno pertencem a uma jornada de produto'; end if;
    if tg_op = 'INSERT' and j.status <> 'rascunho' then raise exception 'A versão % da jornada já foi publicada: crie uma nova versão para mudar as etapas', j.versao; end if;
  end if;
  return new;
end $$;
revoke execute on function public.etapas_jornada_valida() from public, anon, authenticated;
drop trigger if exists etapas_jornada_valida_t on etapas_kanban;
create trigger etapas_jornada_valida_t before insert or update or delete on etapas_kanban for each row execute function etapas_jornada_valida();

-- ---------- matrículas ----------
alter table alunos add column if not exists jornada_id uuid references jornadas(id) on delete set null;
create index if not exists alunos_jornada on alunos (jornada_id);

-- Primeira etapa de uma jornada (ou da jornada geral, com p_jornada nulo).
create or replace function public.jornada_primeira_etapa(p_ws uuid, p_jornada uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from etapas_kanban where workspace_id = p_ws and quadro = 'alunos' and jornada_id is not distinct from p_jornada order by ordem, nome limit 1;
$$;
-- Jornada publicada do produto (nula = usa a jornada geral).
create or replace function public.jornada_do_produto(p_produto uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from jornadas where produto_id = p_produto and status = 'publicada' limit 1;
$$;
revoke execute on function public.jornada_primeira_etapa(uuid, uuid), public.jornada_do_produto(uuid) from public, anon;
grant execute on function public.jornada_primeira_etapa(uuid, uuid), public.jornada_do_produto(uuid) to authenticated;

create or replace function public.alunos_jornada_t() returns trigger language plpgsql security definer set search_path = public as $$
declare j jornadas; ej uuid; tem boolean;
begin
  if tg_op = 'INSERT' then
    -- jornada: a informada (se for deste produto) ou a publicada do produto
    if new.jornada_id is not null then
      select * into j from jornadas where id = new.jornada_id;
      if not found or j.produto_id is distinct from new.produto_id or j.status not in ('publicada', 'anterior') then new.jornada_id := null; end if;
    end if;
    if new.jornada_id is null then new.jornada_id := jornada_do_produto(new.produto_id); end if;
    -- etapa: precisa ser da jornada; senão, a primeira dela
    select true, e.jornada_id into tem, ej from etapas_kanban e where e.id = new.etapa_kanban_id;
    if new.etapa_kanban_id is null or not coalesce(tem, false) or ej is distinct from new.jornada_id then
      if new.jornada_id is not null and jornada_primeira_etapa(new.workspace_id, new.jornada_id) is null then
        new.jornada_id := null;  -- jornada sem etapas: fica na jornada geral
      end if;
      if new.etapa_kanban_id is null or not coalesce(tem, false) or ej is distinct from new.jornada_id then
        new.etapa_kanban_id := jornada_primeira_etapa(new.workspace_id, new.jornada_id);
      end if;
    end if;
    return new;
  end if;
  -- UPDATE
  if new.jornada_id is distinct from old.jornada_id then
    if new.jornada_id is not null then
      select * into j from jornadas where id = new.jornada_id;
      if not found or j.produto_id is distinct from new.produto_id then raise exception 'A jornada precisa ser do produto desta matrícula'; end if;
    end if;
  end if;
  if new.etapa_kanban_id is not null and (new.etapa_kanban_id is distinct from old.etapa_kanban_id or new.jornada_id is distinct from old.jornada_id) then
    select e.jornada_id into ej from etapas_kanban e where e.id = new.etapa_kanban_id;
    if ej is distinct from new.jornada_id then raise exception 'Esta etapa é de outra jornada: o aluno só anda pelas etapas da jornada do produto dele'; end if;
  end if;
  return new;
end $$;
revoke execute on function public.alunos_jornada_t() from public, anon, authenticated;
drop trigger if exists alunos_jornada_t on alunos;
create trigger alunos_jornada_t before insert or update of etapa_kanban_id, jornada_id, produto_id on alunos for each row execute function alunos_jornada_t();

-- ---------- análise de funil e Dashboard de RevOps: ordem dentro da mesma jornada ----------
do $m$
declare d text; n text;
begin
  -- funil_membros: "chegou na etapa X do aluno" = está nela ou numa posterior DA MESMA JORNADA (ou passou por ela)
  select pg_get_functiondef('public.funil_membros(uuid, date, date, uuid, uuid)'::regprocedure) into d;
  d := replace(d, E'\r\n', E'\n');  -- o corpo pode ter sido gravado com quebra de linha do Windows
  if position('ea.jornada_id is not distinct from e.jornada_id' in d) = 0 then
    n := replace(d, 'ea.quadro = ''alunos'' and ea.ordem >= e.ordem', 'ea.quadro = ''alunos'' and ea.jornada_id is not distinct from e.jornada_id and ea.ordem >= e.ordem');
    if n = d then raise exception 'funil_membros: trecho da ordem das etapas do aluno não encontrado'; end if;
    execute n;
  end if;
  -- funil_analise: as etapas do pós-compra são as da jornada publicada do produto do funil; sem ela, as da jornada geral
  select pg_get_functiondef('public.funil_analise(uuid, date, date, uuid, uuid)'::regprocedure) into d;
  d := replace(d, E'\r\n', E'\n');  -- o corpo pode ter sido gravado com quebra de linha do Windows
  if position('jornada_do_produto' in d) = 0 then
    n := replace(d, 'from etapas_kanban where workspace_id = p_ws and quadro = ''alunos'';',
      'from etapas_kanban where workspace_id = p_ws and quadro = ''alunos'' and jornada_id is not distinct from (select jornada_do_produto(f.produto_id) from funis f where f.id = v_funil);');
    if n = d then raise exception 'funil_analise: trecho das etapas do aluno não encontrado'; end if;
    execute n;
  end if;
  -- heavyops_painel: alunos por etapa, com o produto na frente do nome quando a etapa é de uma jornada de produto
  select pg_get_functiondef('public.heavyops_painel(uuid, integer)'::regprocedure) into d;
  d := replace(d, E'\r\n', E'\n');  -- o corpo pode ter sido gravado com quebra de linha do Windows
  if position('jornada_id' in d) = 0 then
    n := replace(d, 'select coalesce(jsonb_agg(jsonb_build_object(''etapa'', e.nome, ''ordem'', e.ordem, ''n'', coalesce(c.n, 0)) order by e.ordem), ''[]'') into r_etapas
  from etapas_kanban e',
      'select coalesce(jsonb_agg(jsonb_build_object(''etapa'', case when pj.nome is null then e.nome else pj.nome || '' · '' || e.nome end, ''ordem'', e.ordem, ''n'', coalesce(c.n, 0)) order by pj.nome nulls first, e.ordem), ''[]'') into r_etapas
  from etapas_kanban e
  left join jornadas jj on jj.id = e.jornada_id left join produtos pj on pj.id = jj.produto_id');
    if n = d then raise exception 'heavyops_painel: trecho das etapas não encontrado'; end if;
    n := replace(n, 'where e.workspace_id = p_ws and e.quadro = ''alunos'';', 'where e.workspace_id = p_ws and e.quadro = ''alunos'' and (e.jornada_id is null or jj.status in (''publicada'', ''anterior''));');
    execute n;
  end if;
end $m$;

-- Para desfazer (na ordem): voltar funil_membros e funil_analise de 20261006240000_funil_pos_compra.sql e heavyops_painel de 20261006190000_heavy_ops.sql;
-- drop trigger if exists alunos_jornada_t on alunos; drop function if exists public.alunos_jornada_t();
-- drop function if exists public.jornada_primeira_etapa(uuid, uuid), public.jornada_do_produto(uuid);
-- alter table alunos drop column if exists jornada_id;
-- drop trigger if exists etapas_jornada_valida_t on etapas_kanban; drop function if exists public.etapas_jornada_valida();
-- delete from etapas_kanban where jornada_id is not null;  (antes, mover os alunos dessas etapas para a jornada geral)
-- drop index if exists etapas_kanban_geral_uq, etapas_kanban_jornada_uq; alter table etapas_kanban add constraint etapas_kanban_workspace_id_quadro_nome_key unique (workspace_id, quadro, nome);
-- alter table etapas_kanban drop column if exists jornada_id; drop table if exists jornadas;

-- ===================== 20261118100000_jornada_versoes.sql =====================
-- v0.163 — Versões da jornada do produto (Customer Growth, etapa B3).
-- 1. aluno_historico ganha o tipo 'jornada' (troca de versão) e as colunas jornada_id (para onde foi) e jornada_de (de onde veio).
-- 2. jornada_rascunho(produto, base, da_geral): cria a próxima versão em rascunho, copiando as etapas de uma jornada
--    (outra versão do produto ou um modelo), da jornada geral, ou vazia.
-- 3. jornada_transferir(de, para, mapa): leva alunos de uma versão (ou da jornada geral, de = nulo) para outra versão do mesmo produto.
--    mapa = {"<etapa antiga>": "<etapa nova>"}; etapa antiga fora do mapa (ou com valor nulo) = esses alunos ficam onde estão.
-- 4. jornada_publicar(jornada, modo, mapa): publica o rascunho. A publicada de antes vira 'anterior'. modo 'continuar' = ninguém muda;
--    'transferir' = leva os alunos da versão anterior (ou da jornada geral, na primeira versão) pelo mapa.
--    As pesquisas ligadas a etapas da versão anterior passam a apontar para a etapa equivalente da nova (pelo mapa ou pelo nome).
-- 5. jornada_salvar_modelo(jornada, nome): guarda a jornada como modelo (sem produto) para criar outras a partir dela.
-- Rode depois de 20261117100000_jornada_produto.sql. Idempotente.

alter table aluno_historico add column if not exists jornada_id uuid references jornadas(id) on delete set null;
alter table aluno_historico add column if not exists jornada_de uuid references jornadas(id) on delete set null;
alter table aluno_historico add column if not exists por_usuario uuid default auth.uid();
alter table aluno_historico drop constraint if exists aluno_historico_tipo_check;
alter table aluno_historico add constraint aluno_historico_tipo_check check (tipo in ('etapa', 'saida', 'volta', 'jornada'));

create or replace function public._jornada_pode(p_ws uuid) returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not pode_operar(p_ws) or not (perm(p_ws, 'editar', array['revops', 'vendas', 'cad']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then
    raise exception 'Sem permissão para editar a jornada deste cliente'; end if;
end $$;
revoke execute on function public._jornada_pode(uuid) from public, anon, authenticated;

create or replace function public._jornada_copiar_etapas(p_ws uuid, p_de uuid, p_geral boolean, p_para uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, descricao, mensagem_padrao, alertar_responsavel, jornada_id)
  select p_ws, 'alunos', e.nome, row_number() over (order by e.ordem, e.nome), e.descricao, e.mensagem_padrao, e.alertar_responsavel, p_para
  from etapas_kanban e
  where e.workspace_id = p_ws and e.quadro = 'alunos' and ((p_geral and e.jornada_id is null) or (not p_geral and p_de is not null and e.jornada_id = p_de));
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public._jornada_copiar_etapas(uuid, uuid, boolean, uuid) from public, anon, authenticated;

create or replace function public.jornada_rascunho(p_produto uuid, p_base uuid default null, p_da_geral boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare pr produtos; b jornadas; novo uuid; v int;
begin
  select * into pr from produtos where id = p_produto;
  if not found then raise exception 'Produto não encontrado'; end if;
  perform _jornada_pode(pr.workspace_id);
  if exists (select 1 from jornadas where produto_id = p_produto and status = 'rascunho') then raise exception 'Este produto já tem uma versão em rascunho'; end if;
  if p_base is not null then
    select * into b from jornadas where id = p_base and workspace_id = pr.workspace_id;
    if not found or not (b.modelo or b.produto_id = p_produto) then raise exception 'A base precisa ser um modelo ou uma versão deste produto'; end if;
  end if;
  select coalesce(max(versao), 0) + 1 into v from jornadas where produto_id = p_produto;
  insert into jornadas (workspace_id, produto_id, nome, versao, status, baseada_em, descricao)
  values (pr.workspace_id, p_produto, coalesce(case when b.modelo then null else b.nome end, 'Jornada do produto ' || pr.nome), v, 'rascunho', p_base, b.descricao)
  returning id into novo;
  perform _jornada_copiar_etapas(pr.workspace_id, p_base, coalesce(p_da_geral, false) and p_base is null, novo);
  return novo;
end $$;

create or replace function public.jornada_transferir(p_de uuid, p_para uuid, p_mapa jsonb default '{}'::jsonb, p_produto uuid default null) returns int
language plpgsql security definer set search_path = public as $$
declare jp jornadas; jd jornadas; r record; alvo uuid; n int := 0; prod uuid;
begin
  select * into jp from jornadas where id = p_para;
  if not found or jp.modelo then raise exception 'Versão de destino não encontrada'; end if;
  perform _jornada_pode(jp.workspace_id);
  if jp.status not in ('publicada', 'anterior') then raise exception 'Só dá para levar alunos para uma versão publicada'; end if;
  if p_de is not null then
    select * into jd from jornadas where id = p_de;
    if not found or jd.produto_id is distinct from jp.produto_id then raise exception 'As duas versões precisam ser do mesmo produto'; end if;
    if p_de = p_para then return 0; end if;
  end if;
  prod := jp.produto_id;
  if p_produto is not null and p_produto <> prod then raise exception 'A versão de destino é de outro produto'; end if;
  for r in select a.id, a.pessoa_id, a.etapa_kanban_id, a.jornada_id from alunos a
           where a.workspace_id = jp.workspace_id and a.produto_id = prod and a.jornada_id is not distinct from p_de and a.saiu_em is null loop
    alvo := nullif(coalesce(p_mapa, '{}'::jsonb) ->> r.etapa_kanban_id::text, '')::uuid;
    if alvo is null then continue; end if;
    if not exists (select 1 from etapas_kanban where id = alvo and jornada_id = p_para) then raise exception 'A etapa de destino precisa ser da nova versão'; end if;
    update alunos set jornada_id = p_para, etapa_kanban_id = alvo where id = r.id;
    insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, etapa_kanban_id, jornada_id, jornada_de)
    values (jp.workspace_id, r.id, r.pessoa_id, 'jornada', alvo, p_para, p_de);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.jornada_publicar(p_jornada uuid, p_modo text default 'continuar', p_mapa jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare j jornadas; ant uuid; n int := 0; mp jsonb := coalesce(p_mapa, '{}'::jsonb); e record; alvo uuid; np int := 0;
begin
  select * into j from jornadas where id = p_jornada for update;
  if not found or j.modelo then raise exception 'Jornada não encontrada'; end if;
  perform _jornada_pode(j.workspace_id);
  if j.status <> 'rascunho' then raise exception 'Só um rascunho pode ser publicado'; end if;
  if p_modo not in ('continuar', 'transferir') then raise exception 'Escolha continuar ou transferir'; end if;
  if not exists (select 1 from etapas_kanban where jornada_id = p_jornada) then raise exception 'Cadastre ao menos uma etapa antes de publicar'; end if;
  select id into ant from jornadas where produto_id = j.produto_id and status = 'publicada';
  if ant is not null then update jornadas set status = 'anterior' where id = ant; end if;
  update jornadas set status = 'publicada', publicada_em = now(), publicada_por = auth.uid() where id = p_jornada;
  if p_modo = 'transferir' then n := jornada_transferir(ant, p_jornada, mp, j.produto_id); end if;
  -- pesquisas ligadas às etapas da versão de antes (ou da geral, na primeira versão, só quando filtradas por este produto) seguem para a nova
  for e in select x.id, x.nome from etapas_kanban x
           where x.workspace_id = j.workspace_id and x.quadro = 'alunos' and x.jornada_id is not distinct from ant loop
    alvo := nullif(mp ->> e.id::text, '')::uuid;
    if alvo is null or not exists (select 1 from etapas_kanban where id = alvo and jornada_id = p_jornada) then
      select id into alvo from etapas_kanban where jornada_id = p_jornada and lower(nome) = lower(e.nome) limit 1;
    end if;
    if alvo is not null then
      update pesquisas set etapa_aluno_id = alvo
      where etapa_aluno_id = e.id and gatilho = 'etapa_aluno' and (ant is not null or produto_id = j.produto_id);
      get diagnostics n = row_count; np := np + n;
    end if;
  end loop;
  select count(*) into n from aluno_historico where tipo = 'jornada' and jornada_id = p_jornada and jornada_de is not distinct from ant;
  return jsonb_build_object('publicada', p_jornada, 'anterior', ant, 'transferidos', case when p_modo = 'transferir' then n else 0 end, 'pesquisas', np);
end $$;

create or replace function public.jornada_salvar_modelo(p_jornada uuid, p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare j jornadas; novo uuid;
begin
  select * into j from jornadas where id = p_jornada;
  if not found then raise exception 'Jornada não encontrada'; end if;
  perform _jornada_pode(j.workspace_id);
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao modelo'; end if;
  insert into jornadas (workspace_id, produto_id, nome, modelo, status, baseada_em, descricao)
  values (j.workspace_id, null, trim(p_nome), true, 'rascunho', p_jornada, j.descricao) returning id into novo;
  perform _jornada_copiar_etapas(j.workspace_id, p_jornada, false, novo);
  update jornadas set status = 'publicada' where id = novo;
  return novo;
end $$;

revoke execute on function public.jornada_rascunho(uuid, uuid, boolean), public.jornada_transferir(uuid, uuid, jsonb, uuid),
  public.jornada_publicar(uuid, text, jsonb), public.jornada_salvar_modelo(uuid, text) from public, anon;
grant execute on function public.jornada_rascunho(uuid, uuid, boolean), public.jornada_transferir(uuid, uuid, jsonb, uuid),
  public.jornada_publicar(uuid, text, jsonb), public.jornada_salvar_modelo(uuid, text) to authenticated;

-- Para desfazer: drop function if exists public.jornada_salvar_modelo(uuid, text), public.jornada_publicar(uuid, text, jsonb),
--   public.jornada_transferir(uuid, uuid, jsonb, uuid), public.jornada_rascunho(uuid, uuid, boolean), public._jornada_copiar_etapas(uuid, uuid, boolean, uuid), public._jornada_pode(uuid);
-- delete from aluno_historico where tipo = 'jornada'; alter table aluno_historico drop constraint aluno_historico_tipo_check;
-- alter table aluno_historico add constraint aluno_historico_tipo_check check (tipo in ('etapa', 'saida', 'volta'));
-- alter table aluno_historico drop column if exists por_usuario, drop column if exists jornada_de, drop column if exists jornada_id;

-- ===================== 20261119100000_jornada_marcos.sql =====================
-- v0.163 — Marcos da jornada do produto e sinais de cada aluno (Customer Growth, etapas B5 e B5b).
-- 1. jornada_marcos: o que o aluno precisa atingir (nome, o que prova, prazo em dias desde a matrícula, obrigatório, etapa ligada).
--    confirmacao: manual (a equipe confirma) | automatico (o sistema marca sozinho) | auto_confirmar (o sistema percebe e a equipe confirma).
--    regra (jsonb) para os automáticos, com dados que o Growths já guarda:
--      {"tipo":"compra","produto_id":…}                         comprou um produto (venda aprovada)
--      {"tipo":"video","fonte_id":…,"minutos":N}                assistiu a um vídeo/aula (N minutos ou mais; sem N, qualquer presença)
--      {"tipo":"pesquisa","pesquisa_id":…,"pergunta_id":…,"resposta":"Sim"}   respondeu a pesquisa (e, se informado, deu aquela resposta)
--      {"tipo":"etapa","etapa_kanban_id":…}                     chegou a uma etapa da jornada
--      {"tipo":"lista","lista_id":…}                            entrou numa lista ou grupo do funil
--      {"tipo":"evento","evento":"trabalho_xpto"}               evento vindo de fora (plataforma do curso), pelo endereço de eventos
-- 2. aluno_marcos: um por aluno e marco: situacao (atingido, aguardando, recusado), sinal (observado, declarado, validado), fonte e referência.
--    Marco recusado pela equipe não volta sozinho.
-- 3. Gatilhos em vendas, presencas_video, pesquisa_respostas/itens, aluno_historico, pessoa_lista e pessoa_toques avaliam os marcos.
--    Nunca bloqueiam a operação de origem (erro no marco não impede venda, presença ou resposta).
-- 4. marco_confirmar(aluno, marco, acao, observacao): confirmar, recusar ou desfazer.
-- 5. Eventos de fora: chave de escopo 'eventos' e evento_por_chave(chave, dados) para a edge function "leads" (?tipo=evento).
-- 6. Auditoria ligada em alunos, jornadas, jornada_marcos e aluno_marcos. As etapas copiadas para uma nova versão levam os marcos.
-- Rode depois de 20261118100000_jornada_versoes.sql. Idempotente.

create table if not exists jornada_marcos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  jornada_id uuid not null references jornadas(id) on delete cascade,
  etapa_kanban_id uuid references etapas_kanban(id) on delete set null,
  nome text not null check (char_length(nome) between 1 and 160),
  descricao text,
  evidencia text,
  prazo_dias int check (prazo_dias is null or prazo_dias between 0 and 3650),
  obrigatorio boolean not null default false,
  ordem int not null default 0,
  confirmacao text not null default 'manual' check (confirmacao in ('manual', 'automatico', 'auto_confirmar')),
  regra jsonb check (regra is null or jsonb_typeof(regra) = 'object'),
  criado_em timestamptz not null default now(),
  constraint jornada_marcos_regra_ck check (confirmacao = 'manual' or coalesce(regra->>'tipo', '') in ('compra', 'video', 'pesquisa', 'etapa', 'lista', 'evento'))
);
create index if not exists jornada_marcos_j on jornada_marcos (jornada_id, ordem);

create table if not exists aluno_marcos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  aluno_id uuid not null references alunos(id) on delete cascade,
  marco_id uuid not null references jornada_marcos(id) on delete cascade,
  situacao text not null check (situacao in ('atingido', 'aguardando', 'recusado')),
  sinal text not null check (sinal in ('observado', 'declarado', 'validado')),
  fonte text not null check (fonte in ('manual', 'compra', 'video', 'pesquisa', 'etapa', 'lista', 'evento')),
  ref_tabela text, ref_id uuid, valor text,
  em timestamptz not null default now(),
  validado_por uuid, validado_em timestamptz, observacao text,
  unique (aluno_id, marco_id)
);
create index if not exists aluno_marcos_ws on aluno_marcos (workspace_id, situacao);

create or replace function public.jornada_marcos_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from jornadas where id = new.jornada_id and workspace_id = new.workspace_id) then raise exception 'A jornada precisa ser deste cliente'; end if;
  if new.etapa_kanban_id is not null and not exists (select 1 from etapas_kanban where id = new.etapa_kanban_id and jornada_id = new.jornada_id) then
    raise exception 'A etapa do marco precisa ser desta jornada'; end if;
  if new.regra->>'tipo' = 'etapa' and not exists (select 1 from etapas_kanban where id::text = new.regra->>'etapa_kanban_id' and jornada_id = new.jornada_id) then
    raise exception 'A etapa da regra precisa ser desta jornada'; end if;
  return new;
end $$;
revoke execute on function public.jornada_marcos_valida() from public, anon, authenticated;
drop trigger if exists jornada_marcos_valida_t on jornada_marcos;
create trigger jornada_marcos_valida_t before insert or update on jornada_marcos for each row execute function jornada_marcos_valida();

create or replace function public.aluno_marcos_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from alunos a join jornada_marcos m on m.jornada_id = a.jornada_id where a.id = new.aluno_id and m.id = new.marco_id and a.workspace_id = new.workspace_id) then
    raise exception 'O marco precisa ser da jornada desta matrícula'; end if;
  return new;
end $$;
revoke execute on function public.aluno_marcos_valida() from public, anon, authenticated;
drop trigger if exists aluno_marcos_valida_t on aluno_marcos;
create trigger aluno_marcos_valida_t before insert or update of aluno_id, marco_id on aluno_marcos for each row execute function aluno_marcos_valida();

do $p$
declare t text;
begin
  foreach t in array array['jornada_marcos', 'aluno_marcos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_acesso', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on %I', t); execute format('drop policy if exists perm_inserir on %I', t);
    execute format('drop policy if exists perm_alterar on %I', t); execute format('drop policy if exists perm_excluir on %I', t);
    execute format($f$create policy perm_ler on %I as restrictive for select using (perm(workspace_id, 'ler', array['revops','vendas','adm','prj','fin','gro','cad']))$f$, t);
    execute format($f$create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format($f$create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, 'editar', array['revops','vendas','cad'])) with check (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format($f$create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format('grant select, insert, update, delete on %I to authenticated', t);
  end loop;
end $p$;

-- ---------- avaliação automática ----------
-- Marca os marcos automáticos de UMA matrícula que batem com o fato (fonte + dados). Devolve quantos marcou.
create or replace function public._marco_marcar(p_aluno uuid, p_fonte text, p_ref_tabela text, p_ref_id uuid, p_dados jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare a alunos; mk record; ok boolean; n int := 0; d jsonb := coalesce(p_dados, '{}'::jsonb);
begin
  select * into a from alunos where id = p_aluno;
  if not found or a.jornada_id is null then return 0; end if;
  for mk in select * from jornada_marcos where jornada_id = a.jornada_id and confirmacao <> 'manual' and regra->>'tipo' = p_fonte loop
    ok := case p_fonte
      when 'compra' then mk.regra->>'produto_id' is null or mk.regra->>'produto_id' = d->>'produto_id'
      when 'video' then (mk.regra->>'fonte_id' is null or mk.regra->>'fonte_id' = d->>'fonte_id') and coalesce((d->>'segundos')::int, 0) >= coalesce((mk.regra->>'minutos')::numeric, 0) * 60
      when 'pesquisa' then mk.regra->>'pesquisa_id' = d->>'pesquisa_id'
        and (mk.regra->>'pergunta_id' is null or (mk.regra->>'pergunta_id' = d->>'pergunta_id'
             and (mk.regra->>'resposta' is null or lower(trim(mk.regra->>'resposta')) = lower(trim(coalesce(d->>'valor', ''))))))
      when 'etapa' then mk.regra->>'etapa_kanban_id' = d->>'etapa_kanban_id'
      when 'lista' then mk.regra->>'lista_id' = d->>'lista_id'
      when 'evento' then lower(trim(mk.regra->>'evento')) = lower(trim(coalesce(d->>'evento', '')))
      else false end;
    if not coalesce(ok, false) then continue; end if;
    insert into aluno_marcos (workspace_id, aluno_id, marco_id, situacao, sinal, fonte, ref_tabela, ref_id, valor, em)
    values (a.workspace_id, a.id, mk.id, case when mk.confirmacao = 'automatico' then 'atingido' else 'aguardando' end,
            case when p_fonte = 'pesquisa' then 'declarado' else 'observado' end, p_fonte, p_ref_tabela, p_ref_id, left(d->>'valor', 500), coalesce((d->>'em')::timestamptz, now()))
    on conflict (aluno_id, marco_id) do nothing;
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;
-- Todas as matrículas ativas da pessoa (com jornada).
create or replace function public._marco_pessoa(p_pessoa uuid, p_fonte text, p_ref_tabela text, p_ref_id uuid, p_dados jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in select id from alunos where pessoa_id = p_pessoa and jornada_id is not null and saiu_em is null loop
    n := n + _marco_marcar(r.id, p_fonte, p_ref_tabela, p_ref_id, p_dados);
  end loop;
  return n;
end $$;
revoke execute on function public._marco_marcar(uuid, text, text, uuid, jsonb), public._marco_pessoa(uuid, text, text, uuid, jsonb) from public, anon, authenticated;

create or replace function public.marco_trg() returns trigger language plpgsql security definer set search_path = public as $$
declare pid uuid; pq uuid;
begin
  begin
    if tg_table_name = 'vendas' then
      if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
        perform _marco_pessoa(new.pessoa_id, 'compra', 'vendas', new.id, jsonb_build_object('produto_id', new.produto_id, 'em', new.data_venda)); end if;
    elsif tg_table_name = 'presencas_video' then
      perform _marco_pessoa(new.pessoa_id, 'video', 'presencas_video', new.id, jsonb_build_object('fonte_id', new.fonte_id, 'segundos', new.assistiu_seg));
    elsif tg_table_name = 'pesquisa_respostas' then
      if new.pessoa_id is not null then perform _marco_pessoa(new.pessoa_id, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em)); end if;
    elsif tg_table_name = 'pesquisa_resposta_itens' then
      select r.pessoa_id, r.pesquisa_id into pid, pq from pesquisa_respostas r where r.id = new.resposta_id;
      if pid is not null then perform _marco_pessoa(pid, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text))); end if;
    elsif tg_table_name = 'aluno_historico' then
      if new.tipo in ('etapa', 'jornada') and new.etapa_kanban_id is not null then
        perform _marco_marcar(new.aluno_id, 'etapa', 'aluno_historico', new.id, jsonb_build_object('etapa_kanban_id', new.etapa_kanban_id, 'em', new.em)); end if;
    elsif tg_table_name = 'pessoa_lista' then
      if new.ativo and (tg_op = 'INSERT' or not old.ativo) then perform _marco_pessoa(new.pessoa_id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', new.lista_id)); end if;
    elsif tg_table_name = 'pessoa_toques' then
      if new.tipo = 'outro' and new.chave is not null then perform _marco_pessoa(new.pessoa_id, 'evento', 'pessoa_toques', new.id, jsonb_build_object('evento', new.chave, 'em', new.em)); end if;
    end if;
  exception when others then raise warning 'marco_trg (%): %', tg_table_name, sqlerrm;  -- nunca bloqueia a operação de origem
  end;
  return null;
end $$;
revoke execute on function public.marco_trg() from public, anon, authenticated;
drop trigger if exists marco_venda_t on vendas;
create trigger marco_venda_t after insert or update of status on vendas for each row execute function marco_trg();
drop trigger if exists marco_video_t on presencas_video;
create trigger marco_video_t after insert or update of assistiu_seg on presencas_video for each row execute function marco_trg();
drop trigger if exists marco_resposta_t on pesquisa_respostas;
create trigger marco_resposta_t after insert on pesquisa_respostas for each row execute function marco_trg();
drop trigger if exists marco_resposta_item_t on pesquisa_resposta_itens;
create trigger marco_resposta_item_t after insert on pesquisa_resposta_itens for each row execute function marco_trg();
drop trigger if exists marco_hist_t on aluno_historico;
create trigger marco_hist_t after insert on aluno_historico for each row execute function marco_trg();
drop trigger if exists marco_lista_t on pessoa_lista;
create trigger marco_lista_t after insert or update of ativo on pessoa_lista for each row execute function marco_trg();
drop trigger if exists marco_toque_t on pessoa_toques;
create trigger marco_toque_t after insert on pessoa_toques for each row execute function marco_trg();

-- Ao criar um marco automático, olha o que já aconteceu com quem já está na jornada (etapas, compras, vídeos, respostas, listas, eventos).
create or replace function public.marco_retroativo(p_marco uuid) returns int
language plpgsql security definer set search_path = public as $$
declare mk jornada_marcos; r record; n int := 0;
begin
  select * into mk from jornada_marcos where id = p_marco;
  if not found or mk.confirmacao = 'manual' then return 0; end if;
  perform _jornada_pode(mk.workspace_id);
  for r in select a.id, a.pessoa_id from alunos a where a.jornada_id = mk.jornada_id and a.saiu_em is null loop
    if mk.regra->>'tipo' = 'etapa' then
      if exists (select 1 from aluno_historico h where h.aluno_id = r.id and h.etapa_kanban_id::text = mk.regra->>'etapa_kanban_id') then
        n := n + _marco_marcar(r.id, 'etapa', 'aluno_historico', null, jsonb_build_object('etapa_kanban_id', mk.regra->>'etapa_kanban_id')); end if;
    elsif mk.regra->>'tipo' = 'compra' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'compra', 'vendas', v.id, jsonb_build_object('produto_id', v.produto_id, 'em', v.data_venda)))
        from vendas v join alunos a on a.id = r.id where v.pessoa_id = r.pessoa_id and v.status = 'aprovada' and v.data_venda >= a.entrou_em), 0);
    elsif mk.regra->>'tipo' = 'video' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'video', 'presencas_video', x.id, jsonb_build_object('fonte_id', x.fonte_id, 'segundos', x.assistiu_seg))) from presencas_video x where x.pessoa_id = r.pessoa_id), 0);
    elsif mk.regra->>'tipo' = 'pesquisa' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'pesquisa', 'pesquisa_respostas', x.id, jsonb_build_object('pesquisa_id', x.pesquisa_id, 'em', x.respondida_em))) from pesquisa_respostas x where x.pessoa_id = r.pessoa_id), 0);
      n := n + coalesce((select sum(_marco_marcar(r.id, 'pesquisa', 'pesquisa_respostas', x.id, jsonb_build_object('pesquisa_id', x.pesquisa_id, 'pergunta_id', i.pergunta_id, 'valor', coalesce(i.valor_texto, i.valor_num::text))))
        from pesquisa_respostas x join pesquisa_resposta_itens i on i.resposta_id = x.id where x.pessoa_id = r.pessoa_id), 0);
    elsif mk.regra->>'tipo' = 'lista' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', x.lista_id))) from pessoa_lista x where x.pessoa_id = r.pessoa_id and x.ativo), 0);
    elsif mk.regra->>'tipo' = 'evento' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'evento', 'pessoa_toques', x.id, jsonb_build_object('evento', x.chave, 'em', x.em))) from pessoa_toques x where x.pessoa_id = r.pessoa_id and x.tipo = 'outro' and x.chave is not null), 0);
    end if;
  end loop;
  return n;
end $$;

-- Confirmar, recusar ou desfazer um marco de um aluno (manual ou aguardando confirmação).
create or replace function public.marco_confirmar(p_aluno uuid, p_marco uuid, p_acao text, p_obs text default null) returns text
language plpgsql security definer set search_path = public as $$
declare a alunos;
begin
  select * into a from alunos where id = p_aluno;
  if not found then raise exception 'Matrícula não encontrada'; end if;
  perform _jornada_pode(a.workspace_id);
  if p_acao not in ('confirmar', 'recusar', 'desfazer') then raise exception 'Ação inválida'; end if;
  if p_acao = 'desfazer' then delete from aluno_marcos where aluno_id = p_aluno and marco_id = p_marco; return 'desfeito'; end if;
  insert into aluno_marcos (workspace_id, aluno_id, marco_id, situacao, sinal, fonte, validado_por, validado_em, observacao)
  values (a.workspace_id, p_aluno, p_marco, case when p_acao = 'confirmar' then 'atingido' else 'recusado' end, 'validado', 'manual', auth.uid(), now(), nullif(trim(coalesce(p_obs, '')), ''))
  on conflict (aluno_id, marco_id) do update set situacao = excluded.situacao, sinal = 'validado', validado_por = excluded.validado_por, validado_em = now(),
    observacao = coalesce(excluded.observacao, aluno_marcos.observacao);
  return case when p_acao = 'confirmar' then 'atingido' else 'recusado' end;
end $$;
revoke execute on function public.marco_retroativo(uuid), public.marco_confirmar(uuid, uuid, text, text) from public, anon;
grant execute on function public.marco_retroativo(uuid), public.marco_confirmar(uuid, uuid, text, text) to authenticated;

-- ---------- nova versão / modelo levam os marcos ----------
create or replace function public._jornada_copiar_etapas(p_ws uuid, p_de uuid, p_geral boolean, p_para uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, descricao, mensagem_padrao, alertar_responsavel, jornada_id)
  select p_ws, 'alunos', e.nome, row_number() over (order by e.ordem, e.nome), e.descricao, e.mensagem_padrao, e.alertar_responsavel, p_para
  from etapas_kanban e
  where e.workspace_id = p_ws and e.quadro = 'alunos' and ((p_geral and e.jornada_id is null) or (not p_geral and p_de is not null and e.jornada_id = p_de));
  get diagnostics n = row_count;
  if not p_geral and p_de is not null then
    insert into jornada_marcos (workspace_id, jornada_id, etapa_kanban_id, nome, descricao, evidencia, prazo_dias, obrigatorio, ordem, confirmacao, regra)
    select p_ws, p_para, en.id, m.nome, m.descricao, m.evidencia, m.prazo_dias, m.obrigatorio, m.ordem, m.confirmacao,
      case when coalesce(m.regra->>'tipo', '') = 'etapa' then
        (select case when x.id is null then null else jsonb_set(m.regra, '{etapa_kanban_id}', to_jsonb(x.id::text)) end
           from etapas_kanban eo left join etapas_kanban x on x.jornada_id = p_para and x.nome = eo.nome where eo.id::text = m.regra->>'etapa_kanban_id')
      else m.regra end
    from jornada_marcos m
    left join etapas_kanban eo on eo.id = m.etapa_kanban_id
    left join etapas_kanban en on en.jornada_id = p_para and en.nome = eo.nome
    where m.jornada_id = p_de
      and not (coalesce(m.regra->>'tipo', '') = 'etapa' and not exists (select 1 from etapas_kanban eo2 join etapas_kanban x2 on x2.jornada_id = p_para and x2.nome = eo2.nome where eo2.id::text = m.regra->>'etapa_kanban_id'));
  end if;
  return n;
end $$;
revoke execute on function public._jornada_copiar_etapas(uuid, uuid, boolean, uuid) from public, anon, authenticated;

-- ---------- eventos de fora ----------
alter table chaves_api drop constraint if exists chaves_api_escopo_check;
alter table chaves_api add constraint chaves_api_escopo_check check (escopo in ('ideias', 'leads', 'vendas', 'eventos'));
alter table pessoa_toques drop constraint if exists pessoa_toques_origem_check;
alter table pessoa_toques add constraint pessoa_toques_origem_check check (origem in ('sistema', 'sendflow', 'manual', 'importacao', 'captura', 'integracao'));  -- 'captura' veio da v0.135 (DMs do Instagram)
create or replace function public.chave_api_criar_escopo(p_ws uuid, p_nome text, p_escopo text) returns text
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if p_escopo not in ('ideias', 'leads', 'vendas', 'eventos') then raise exception 'Escopo inválido'; end if;
  if p_escopo = 'eventos' then
    if auth.uid() is null or not perm(p_ws, 'editar', array['revops', 'vendas', 'cad']) then raise exception 'Só quem edita RevOps, Vendas ou Cadastros deste workspace pode gerar chave de eventos'; end if;
  elsif auth.uid() is null or not perm(p_ws, 'editar', '{mkt}'::text[]) then raise exception 'Só quem edita o Marketing deste workspace pode gerar chave'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome para a chave (ex.: Página de captura)'; end if;
  k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (p_ws, trim(p_nome), p_escopo, left(k, 9), chave_api_hash(k));
  return k;
end $$;
revoke execute on function public.chave_api_criar_escopo(uuid, text, text) from public, anon;
grant execute on function public.chave_api_criar_escopo(uuid, text, text) to authenticated;

-- Recebe um evento de fora: {"email" ou "telefone", "evento": "trabalho_xpto", "em"?, "descricao"?}. Grava um toque na pessoa;
-- os marcos com regra {"tipo":"evento","evento":…} das matrículas dela são marcados pelo gatilho. Pessoa desconhecida não é criada.
create or replace function public.evento_por_chave(p_chave text, p_dados jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w uuid; d jsonb := coalesce(p_dados, '{}'::jsonb); e text; f text; ev text; em timestamptz; pid uuid; tid uuid; n int;
begin
  w := chave_api_ws_escopo(p_chave, 'eventos');
  ev := nullif(lower(regexp_replace(trim(coalesce(d->>'evento', '')), '\s+', '_', 'g')), '');
  if ev is null or char_length(ev) > 80 then raise exception 'Informe o nome do evento (até 80 caracteres)'; end if;
  e := norm_email(nullif(lower(trim(coalesce(d->>'email', ''))), '')); f := norm_fone(nullif(trim(coalesce(d->>'telefone', '')), ''));
  if e is null and f is null then raise exception 'O evento precisa do e-mail ou do telefone do aluno'; end if;
  em := coalesce(nullif(d->>'em', '')::timestamptz, now());
  if em > now() + interval '1 hour' or em < now() - interval '400 days' then em := now(); end if;
  if f is not null then select id into pid from pessoas where workspace_id = w and telefone_norm = f; end if;
  if pid is null and e is not null then select id into pid from pessoas where workspace_id = w and email_norm = e; end if;
  if pid is null then return jsonb_build_object('ok', false, 'erro', 'Pessoa não encontrada no Growths (confira o e-mail ou o telefone)'); end if;
  insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, chave, descricao, origem)
  values (w, pid, em, 'outro', 'plataforma', ev, left(coalesce(nullif(d->>'descricao', ''), 'Evento: ' || ev), 300), 'integracao') returning id into tid;
  select count(*) into n from aluno_marcos where ref_tabela = 'pessoa_toques' and ref_id = tid;
  return jsonb_build_object('ok', true, 'pessoa_id', pid, 'evento', ev, 'marcos', n);
end $$;
revoke execute on function public.evento_por_chave(text, jsonb) from public;
grant execute on function public.evento_por_chave(text, jsonb) to anon, authenticated;

-- ---------- auditoria ----------
do $$
declare t text;
begin
  foreach t in array array['alunos', 'jornadas', 'jornada_marcos', 'aluno_marcos'] loop
    execute format('drop trigger if exists auditoria_t on public.%I', t);
    execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
  end loop;
end $$;

-- Para desfazer: drop dos gatilhos marco_*_t e auditoria_t de alunos/jornadas/jornada_marcos/aluno_marcos; drop function evento_por_chave, marco_confirmar,
-- marco_retroativo, marco_trg, _marco_pessoa, _marco_marcar, aluno_marcos_valida, jornada_marcos_valida; _jornada_copiar_etapas da 20261118100000;
-- chave_api_criar_escopo e chaves_api_escopo_check da 20261018100000; pessoa_toques_origem_check sem 'integracao' (depois de apagar os toques de integração);
-- drop table aluno_marcos, jornada_marcos.

-- ===================== 20261120100000_checkin_recorrente.sql =====================
-- v0.163 — Check-in que se repete (Customer Growth, etapa B6).
-- 1. pesquisa_envios ganha aluno_id (a matrícula do check-in) e ciclo (0 = envio único de sempre; 1, 2, 3… = check-ins).
--    A trava única passa de (pesquisa, pessoa) para (pesquisa, pessoa, ciclo). Envios que já existem ficam no ciclo 0: nada muda para eles.
-- 2. Todas as funções que gravam envios passam a usar a trava nova (pesquisa_enfileira, pesquisa_gerar_envios, pesquisa_enviar_para,
--    pesquisa_enfileira_aluno), na mesma migração.
-- 3. Gatilho novo 'checkin': a cada N dias (pesquisas.checkin_dias) desde a matrícula, enquanto ela estiver ativa, com filtro opcional
--    de produto e um limite de vezes (checkin_max). pesquisa_checkins_gerar(ref) cria os envios do dia; o agendador de hora em hora chama.
-- 4. A resposta de um check-in vale para os marcos daquela matrícula (não para todas as matrículas da pessoa).
-- Rode depois de 20261119100000_jornada_marcos.sql. Idempotente.

alter table pesquisa_envios add column if not exists aluno_id uuid references alunos(id) on delete set null;
alter table pesquisa_envios add column if not exists ciclo int not null default 0 check (ciclo >= 0);
create index if not exists pesquisa_envios_aluno on pesquisa_envios (aluno_id);
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_envios_ciclo_uq') then
    alter table pesquisa_envios add constraint pesquisa_envios_ciclo_uq unique (pesquisa_id, pessoa_id, ciclo);
  end if;
end $c$;

alter table pesquisas add column if not exists checkin_dias int check (checkin_dias is null or checkin_dias between 1 and 365);
alter table pesquisas add column if not exists checkin_max int check (checkin_max is null or checkin_max between 1 and 100);
alter table pesquisas drop constraint if exists pesquisas_gatilho_check;
alter table pesquisas add constraint pesquisas_gatilho_check check (gatilho in ('manual', 'cadastro', 'etapa', 'entrada_aluno', 'etapa_aluno', 'checkin'));
alter table pesquisas drop constraint if exists pesquisas_checkin_ck;
alter table pesquisas add constraint pesquisas_checkin_ck check (gatilho <> 'checkin' or checkin_dias is not null);

-- Troca a trava nas funções que já existem (o corpo pode estar com quebra de linha do Windows).
do $m$
declare f text; d text; n text;
begin
  foreach f in array array['public.pesquisa_enfileira(uuid, uuid, text, text, uuid)', 'public.pesquisa_gerar_envios(uuid)', 'public.pesquisa_enviar_para(uuid, uuid[])'] loop
    select pg_get_functiondef(f::regprocedure) into d;
    d := replace(d, E'\r\n', E'\n');
    if position('on conflict (pesquisa_id, pessoa_id, ciclo)' in d) = 0 then
      n := replace(d, 'on conflict (pesquisa_id, pessoa_id) do nothing', 'on conflict (pesquisa_id, pessoa_id, ciclo) do nothing');
      if n = d then raise exception '%: trava de envio não encontrada', f; end if;
      execute n;
    end if;
  end loop;
end $m$;

-- Pesquisas de aluno (entrada, etapa) guardam a matrícula no envio.
create or replace function public.pesquisa_enfileira_aluno(p_aluno uuid, p_gatilho text, p_etapa uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a alunos;
begin
  select * into a from alunos where id = p_aluno;
  if not found then return; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, aluno_id, status, motivo, origem)
  select s.workspace_id, s.id, a.pessoa_id, a.id,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = a.pessoa_id and x.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'gatilho'
  from pesquisas s
  where s.workspace_id = a.workspace_id and s.ativa and s.gatilho = p_gatilho
    and (s.produto_id is null or s.produto_id = a.produto_id)
    and (p_gatilho <> 'etapa_aluno' or s.etapa_aluno_id = p_etapa)
  on conflict (pesquisa_id, pessoa_id, ciclo) do nothing;
end $$;
revoke execute on function public.pesquisa_enfileira_aluno(uuid, text, uuid) from public, anon, authenticated;

-- Check-ins do dia: para cada pesquisa de check-in ativa, cada matrícula ativa recebe o ciclo k quando completa k × N dias.
-- Só cria o ciclo de hoje (não recria os que passaram enquanto o agendador estava desligado). Devolve quantos criou.
create or replace function public.pesquisa_checkins_gerar(p_ref timestamptz default now(), p_ws uuid default null) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_ws is not null and not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, aluno_id, ciclo, origem)
  select distinct on (s.id, a.pessoa_id) s.workspace_id, s.id, a.pessoa_id, a.id,
    floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias)::int, 'gatilho'
  from pesquisas s
  join alunos a on a.workspace_id = s.workspace_id and a.saiu_em is null and a.status = 'ativo' and (s.produto_id is null or a.produto_id = s.produto_id)
  where s.ativa and s.gatilho = 'checkin' and (p_ws is null or s.workspace_id = p_ws)
    and floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias) >= 1
    and (s.checkin_max is null or floor(extract(epoch from (p_ref - a.entrou_em)) / 86400 / s.checkin_dias) <= s.checkin_max)
  order by s.id, a.pessoa_id, a.entrou_em
  on conflict (pesquisa_id, pessoa_id, ciclo) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.pesquisa_checkins_gerar(timestamptz, uuid) from public, anon, authenticated;

-- A resposta de um envio com matrícula vale para os marcos daquela matrícula.
create or replace function public.marco_trg() returns trigger language plpgsql security definer set search_path = public as $$
declare pid uuid; pq uuid; al uuid;
begin
  begin
    if tg_table_name = 'vendas' then
      if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
        perform _marco_pessoa(new.pessoa_id, 'compra', 'vendas', new.id, jsonb_build_object('produto_id', new.produto_id, 'em', new.data_venda)); end if;
    elsif tg_table_name = 'presencas_video' then
      perform _marco_pessoa(new.pessoa_id, 'video', 'presencas_video', new.id, jsonb_build_object('fonte_id', new.fonte_id, 'segundos', new.assistiu_seg));
    elsif tg_table_name = 'pesquisa_respostas' then
      select aluno_id into al from pesquisa_envios where id = new.envio_id;
      if al is not null then perform _marco_marcar(al, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em));
      elsif new.pessoa_id is not null then perform _marco_pessoa(new.pessoa_id, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em)); end if;
    elsif tg_table_name = 'pesquisa_resposta_itens' then
      select r.pessoa_id, r.pesquisa_id, e.aluno_id into pid, pq, al from pesquisa_respostas r left join pesquisa_envios e on e.id = r.envio_id where r.id = new.resposta_id;
      if al is not null then perform _marco_marcar(al, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text)));
      elsif pid is not null then perform _marco_pessoa(pid, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text))); end if;
    elsif tg_table_name = 'aluno_historico' then
      if new.tipo in ('etapa', 'jornada') and new.etapa_kanban_id is not null then
        perform _marco_marcar(new.aluno_id, 'etapa', 'aluno_historico', new.id, jsonb_build_object('etapa_kanban_id', new.etapa_kanban_id, 'em', new.em)); end if;
    elsif tg_table_name = 'pessoa_lista' then
      if new.ativo and (tg_op = 'INSERT' or not old.ativo) then perform _marco_pessoa(new.pessoa_id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', new.lista_id)); end if;
    elsif tg_table_name = 'pessoa_toques' then
      if new.tipo = 'outro' and new.chave is not null then perform _marco_pessoa(new.pessoa_id, 'evento', 'pessoa_toques', new.id, jsonb_build_object('evento', new.chave, 'em', new.em)); end if;
    end if;
  exception when others then raise warning 'marco_trg (%): %', tg_table_name, sqlerrm;
  end;
  return null;
end $$;
revoke execute on function public.marco_trg() from public, anon, authenticated;

-- Por último, a trava antiga sai (as funções acima já usam a nova).
alter table pesquisa_envios drop constraint if exists pesquisa_envios_pesquisa_id_pessoa_id_key;

-- Para desfazer: apagar os envios de ciclo > 0 (delete from pesquisa_envios where ciclo > 0), recriar a trava
-- (alter table pesquisa_envios add constraint pesquisa_envios_pesquisa_id_pessoa_id_key unique (pesquisa_id, pessoa_id)), trocar de volta
-- o "on conflict" nas quatro funções, drop function pesquisa_checkins_gerar; update pesquisas set gatilho = 'manual' where gatilho = 'checkin';
-- recriar pesquisas_gatilho_check sem 'checkin'; drop constraint pesquisas_checkin_ck; drop columns checkin_max, checkin_dias, ciclo, aluno_id.

-- ===================== 20261121100000_acompanhamento_cs.sql =====================
-- v0.163 — Acompanhamento do aluno (Customer Growth, etapas B7, B8 e B9).
-- B7. Alertas de CS no mesmo agendador de hora em hora e na mesma tabela de alertas (tipo novo 'cs'):
--     parado (há N dias na mesma etapa), marco obrigatório atrasado, check-in sem resposta, nota baixa (NPS), matrícula sem CS.
--     Cada alerta é gravado uma vez (chave única) e se resolve sozinho quando a situação muda. O aviso vai para o CS da matrícula
--     (sino, e-mail, WhatsApp, como cada pessoa escolheu) só quando o cliente tem os alertas ligados (alertas_config.ligado).
--     Sensibilidade em alertas_config.regras->'cs': {"parado_dias":14,"checkin_dias":7,"nps_max":6,"desligadas":["sem_cs",...]}.
-- B8. cs_intervencoes (tabela própria): ação de CS ligada à matrícula, ao alerta, à etapa, ao marco e à resposta de check-in,
--     com responsável, prazo, situação, resultado e efeito. Concluir resolve o alerta ligado. O responsável é avisado.
-- B9. oportunidades: aluno_id (matrícula de origem), origem (manual, alerta, rfm, ascensao, marco, intervencao) e tipos
--     'expansao' e 'retencao'.
-- Rode depois de 20261120100000_checkin_recorrente.sql. Idempotente.

alter table alertas drop constraint if exists alertas_tipo_check;
alter table alertas add constraint alertas_tipo_check check (tipo in ('brusco', 'repetido', 'operacional', 'cs'));
create index if not exists alertas_cs_aberto on alertas (workspace_id) where tipo = 'cs' and resolvido_em is null;

create or replace function public.cg_verificar_alertas(p_ws uuid, p_ref timestamptz default now(), p_avisar boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cfg jsonb; des text[]; parado int; ckd int; npsm numeric; liga boolean; cx record; novo int := 0; resolv int := 0; dia date := (p_ref at time zone 'America/Sao_Paulo')::date;
  ch text; tit text; msg text; sev text;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  select coalesce(regras->'cs', '{}'::jsonb), ligado into cfg, liga from alertas_config where workspace_id = p_ws;
  cfg := coalesce(cfg, '{}'::jsonb); liga := coalesce(liga, false);
  des := coalesce(array(select jsonb_array_elements_text(cfg->'desligadas')), '{}');
  parado := greatest(coalesce((cfg->>'parado_dias')::int, 14), 1); ckd := greatest(coalesce((cfg->>'checkin_dias')::int, 7), 1); npsm := coalesce((cfg->>'nps_max')::numeric, 6);

  -- casos de agora (um por linha), já com a chave do alerta
  create temp table if not exists _cg_casos (chave text primary key, regra text, severidade text, titulo text, mensagem text, dados jsonb, cs uuid, pessoa uuid) on commit drop;
  delete from _cg_casos;
  if not 'parado' = any (des) then
    insert into _cg_casos
    select 'cs:parado:' || a.id || ':' || a.etapa_kanban_id, 'parado', 'media',
      p.nome || ' parado em «' || e.nome || '» há ' || floor(extract(epoch from (p_ref - u.em)) / 86400)::int || ' dias',
      p.nome || ' (' || pr.nome || ') está na etapa «' || e.nome || '» desde ' || to_char(u.em at time zone 'America/Sao_Paulo', 'DD/MM') || '.' || coalesce(' O que fazer: ' || nullif(e.descricao, ''), ''),
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'etapa_id', a.etapa_kanban_id, 'dias', floor(extract(epoch from (p_ref - u.em)) / 86400)::int),
      a.responsavel_cs_id, a.pessoa_id
    from alunos a join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id join etapas_kanban e on e.id = a.etapa_kanban_id
    cross join lateral (select coalesce(max(h.em), a.entrou_em) as em from aluno_historico h where h.aluno_id = a.id and h.tipo in ('etapa', 'jornada') and h.etapa_kanban_id = a.etapa_kanban_id) u
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and u.em < p_ref - make_interval(days => parado)
      and exists (select 1 from etapas_kanban x where x.workspace_id = p_ws and x.quadro = 'alunos' and x.jornada_id is not distinct from e.jornada_id and x.ordem > e.ordem)  -- na última etapa não é "parado"
    on conflict do nothing;
  end if;
  if not 'marco_atrasado' = any (des) then
    insert into _cg_casos
    select 'cs:marco:' || a.id || ':' || m.id, 'marco_atrasado', 'alta', 'Marco atrasado: ' || m.nome || ' (' || p.nome || ')',
      p.nome || ' (' || pr.nome || ') não atingiu «' || m.nome || '», com prazo de ' || m.prazo_dias || ' dias desde a matrícula (' || to_char(a.entrou_em at time zone 'America/Sao_Paulo', 'DD/MM') || ').',
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'marco_id', m.id, 'etapa_id', m.etapa_kanban_id), a.responsavel_cs_id, a.pessoa_id
    from alunos a join jornada_marcos m on m.jornada_id = a.jornada_id join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and m.obrigatorio and m.prazo_dias is not null
      and a.entrou_em + make_interval(days => m.prazo_dias) < p_ref
      and not exists (select 1 from aluno_marcos x where x.aluno_id = a.id and x.marco_id = m.id and x.situacao = 'atingido')
    on conflict do nothing;
  end if;
  if not 'checkin_sem_resposta' = any (des) then
    insert into _cg_casos
    select 'cs:checkin:' || v.id, 'checkin_sem_resposta', 'media', p.nome || ' não respondeu o check-in «' || s.nome || '»',
      'O check-in foi gerado em ' || to_char(v.gerado_em at time zone 'America/Sao_Paulo', 'DD/MM') || ' e ainda não teve resposta.' || case when v.status = 'pendente' then ' Ele ainda está na fila: confira se foi enviado.' else '' end,
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'envio_id', v.id, 'pesquisa_id', s.id), a.responsavel_cs_id, a.pessoa_id
    from pesquisa_envios v join alunos a on a.id = v.aluno_id join pesquisas s on s.id = v.pesquisa_id join pessoas p on p.id = a.pessoa_id
    where v.workspace_id = p_ws and v.status in ('pendente', 'enviado') and v.gerado_em < p_ref - make_interval(days => ckd) and a.status = 'ativo' and a.saiu_em is null
    on conflict do nothing;
  end if;
  if not 'nps_baixo' = any (des) then
    insert into _cg_casos
    select 'cs:nps:' || r.id, 'nps_baixo', 'alta', p.nome || ' deu nota ' || trim(to_char(i.valor_num, 'FM990')) || ' em «' || s.nome || '»',
      p.nome || ' respondeu ' || trim(to_char(i.valor_num, 'FM990')) || ' de 0 a 10 em ' || to_char(r.respondida_em at time zone 'America/Sao_Paulo', 'DD/MM') || '. Vale conversar e entender o que está travando.',
      jsonb_build_object('aluno_id', al.id, 'pessoa_id', r.pessoa_id, 'produto_id', al.produto_id, 'resposta_id', r.id, 'pesquisa_id', s.id, 'nota', i.valor_num), al.responsavel_cs_id, r.pessoa_id
    from pesquisa_respostas r join pesquisa_resposta_itens i on i.resposta_id = r.id join pesquisa_perguntas q on q.id = i.pergunta_id and q.papel = 'nps'
    join pesquisas s on s.id = r.pesquisa_id join pessoas p on p.id = r.pessoa_id
    left join pesquisa_envios v on v.id = r.envio_id
    cross join lateral (select a.* from alunos a where a.pessoa_id = r.pessoa_id and a.status = 'ativo' and a.saiu_em is null order by (a.id = v.aluno_id) desc nulls last, a.entrou_em desc limit 1) al
    where r.workspace_id = p_ws and i.valor_num <= npsm and r.respondida_em > p_ref - interval '30 days'
    on conflict do nothing;
  end if;
  if not 'sem_cs' = any (des) then
    insert into _cg_casos
    select 'cs:sem_cs:' || a.id, 'sem_cs', 'media', p.nome || ' está sem CS responsável (' || pr.nome || ')',
      'A matrícula de ' || p.nome || ' em ' || pr.nome || ' não tem CS responsável: ninguém recebe os avisos dela.',
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id), null, a.pessoa_id
    from alunos a join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and a.responsavel_cs_id is null
    on conflict do nothing;
  end if;

  -- grava os novos e avisa o CS da matrícula
  for cx in select c.* from _cg_casos c where not exists (select 1 from alertas x where x.workspace_id = p_ws and x.chave = c.chave) loop
    insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
    values (p_ws, cx.chave, 'cs', cx.regra, cx.severidade, cx.titulo, cx.mensagem, cx.dados, dia) on conflict (workspace_id, chave) do nothing;
    if found then
      novo := novo + 1;
      if p_avisar and liga and cx.cs is not null and cx.regra <> 'sem_cs' then perform equipe_avisa(p_ws, cx.cs, cx.pessoa, cx.titulo, cx.mensagem); end if;
    end if;
  end loop;
  -- o que deixou de valer se resolve sozinho
  update alertas x set resolvido_em = p_ref
  where x.workspace_id = p_ws and x.tipo = 'cs' and x.resolvido_em is null and not (x.regra = any (des))
    and not exists (select 1 from _cg_casos c where c.chave = x.chave)
    and not (x.regra = 'nps_baixo');  -- nota baixa só se resolve com uma intervenção concluída ou à mão
  get diagnostics resolv = row_count;
  return jsonb_build_object('novos', novo, 'resolvidos', resolv, 'abertos', (select count(*) from alertas where workspace_id = p_ws and tipo = 'cs' and resolvido_em is null));
end $$;
revoke execute on function public.cg_verificar_alertas(uuid, timestamptz, boolean) from public, anon;
grant execute on function public.cg_verificar_alertas(uuid, timestamptz, boolean) to authenticated;

-- O que o agendador roda de hora em hora para o acompanhamento: check-ins do dia e alertas de CS de quem tem alunos ativos.
create or replace function public.cg_rodar_agendado(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0; ck int := 0;
begin
  begin ck := pesquisa_checkins_gerar(p_ref, null); exception when others then raise warning 'cg_rodar_agendado (check-ins): %', sqlerrm; end;
  for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
    begin perform cg_verificar_alertas(w.workspace_id, p_ref, true); n := n + 1;
    exception when others then raise warning 'cg_rodar_agendado %: %', w.workspace_id, sqlerrm; end;
  end loop;
  return jsonb_build_object('clientes', n, 'checkins', ck);
end $$;
revoke all on function public.cg_rodar_agendado(timestamptz) from public, anon, authenticated;

do $m$
declare d text; n text;
begin
  select pg_get_functiondef('public.growths_rodar_agendado(timestamptz)'::regprocedure) into d;
  d := replace(d, E'\r\n', E'\n');
  if position('cg_rodar_agendado' in d) = 0 then
    -- o ponto de inserção é a contagem da fila (existe com ou sem os comentários da versão original)
    n := replace(d, '  select count(*) into pend from notificacoes',
      '  -- v0.163: acompanhamento dos alunos (check-ins do dia e alertas de CS), antes de pedir o envio da fila
  begin perform cg_rodar_agendado(p_ref); exception when others then raise warning ''growths_rodar_agendado (acompanhamento): %'', sqlerrm; end;
  select count(*) into pend from notificacoes');
    if n = d then raise exception 'growths_rodar_agendado: ponto de inserção não encontrado'; end if;
    execute n;
  end if;
end $m$;
revoke all on function public.growths_rodar_agendado(timestamptz) from public, anon, authenticated;

-- Primeira passada sem avisar ninguém: o que já está acontecendo hoje (alunos parados há tempo, sem CS…) fica registrado como alerta,
-- mas o CS não recebe dezenas de avisos de uma vez. Daqui em diante, só o caso novo avisa.
do $s$
declare w record;
begin
  for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
    begin perform cg_verificar_alertas(w.workspace_id, now(), false);
    exception when others then raise warning 'primeira passada %: %', w.workspace_id, sqlerrm; end;
  end loop;
end $s$;

-- ---------- B8: intervenções de CS ----------
create table if not exists cs_intervencoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  aluno_id uuid not null references alunos(id) on delete cascade,
  pessoa_id uuid references pessoas(id) on delete cascade,
  alerta_id uuid references alertas(id) on delete set null,
  etapa_kanban_id uuid references etapas_kanban(id) on delete set null,
  marco_id uuid references jornada_marcos(id) on delete set null,
  pesquisa_resposta_id uuid references pesquisa_respostas(id) on delete set null,
  tipo text not null default 'mensagem' check (tipo in ('ligacao', 'mensagem', 'reuniao', 'conteudo', 'oferta', 'outro')),
  descricao text not null check (char_length(descricao) between 1 and 2000),
  responsavel_id uuid references equipe(id) on delete set null,
  prazo date,
  status text not null default 'aberta' check (status in ('aberta', 'feita', 'cancelada')),
  resultado text,
  efeito text check (efeito is null or efeito in ('resolveu', 'em_andamento', 'nao_resolveu')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  concluida_em timestamptz
);
create index if not exists cs_intervencoes_ws on cs_intervencoes (workspace_id, status);
create index if not exists cs_intervencoes_aluno on cs_intervencoes (aluno_id);
create index if not exists cs_intervencoes_resp on cs_intervencoes (workspace_id, responsavel_id, status);

create or replace function public.cs_intervencoes_t() returns trigger language plpgsql security definer set search_path = public as $$
declare a alunos; nm text; pr text;
begin
  select * into a from alunos where id = new.aluno_id;
  if not found or a.workspace_id <> new.workspace_id then raise exception 'A matrícula precisa ser deste cliente'; end if;
  new.pessoa_id := a.pessoa_id;
  if tg_op = 'INSERT' and new.responsavel_id is null then new.responsavel_id := a.responsavel_cs_id; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then raise exception 'O responsável precisa ser da equipe deste cliente'; end if;
  if new.alerta_id is not null and not exists (select 1 from alertas where id = new.alerta_id and workspace_id = new.workspace_id) then raise exception 'O alerta precisa ser deste cliente'; end if;
  if new.marco_id is not null and not exists (select 1 from jornada_marcos where id = new.marco_id and jornada_id = a.jornada_id) then raise exception 'O marco precisa ser da jornada desta matrícula'; end if;
  if new.status in ('feita', 'cancelada') and (tg_op = 'INSERT' or old.status = 'aberta') then new.concluida_em := coalesce(new.concluida_em, now()); end if;
  if new.status = 'aberta' then new.concluida_em := null; end if;
  return new;
end $$;
create or replace function public.cs_intervencoes_depois() returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; pr text;
begin
  begin
    select p.nome, d.nome into nm, pr from alunos a join pessoas p on p.id = a.pessoa_id join produtos d on d.id = a.produto_id where a.id = new.aluno_id;
    if new.responsavel_id is not null and (tg_op = 'INSERT' or new.responsavel_id is distinct from old.responsavel_id) and new.status = 'aberta' then
      perform equipe_avisa(new.workspace_id, new.responsavel_id, new.pessoa_id, 'Intervenção de CS: ' || coalesce(nm, 'aluno') || ' (' || coalesce(pr, '') || ')',
        left(new.descricao, 300) || coalesce(' · prazo ' || to_char(new.prazo, 'DD/MM'), ''));
    end if;
    if new.status = 'feita' and (tg_op = 'INSERT' or old.status <> 'feita') and new.alerta_id is not null and coalesce(new.efeito, '') <> 'nao_resolveu' then
      update alertas set resolvido_em = coalesce(resolvido_em, now()) where id = new.alerta_id;
    end if;
  exception when others then raise warning 'cs_intervencoes_depois: %', sqlerrm;
  end;
  return null;
end $$;
revoke execute on function public.cs_intervencoes_t(), public.cs_intervencoes_depois() from public, anon, authenticated;
drop trigger if exists cs_intervencoes_t on cs_intervencoes;
create trigger cs_intervencoes_t before insert or update on cs_intervencoes for each row execute function cs_intervencoes_t();
drop trigger if exists cs_intervencoes_depois_t on cs_intervencoes;
create trigger cs_intervencoes_depois_t after insert or update on cs_intervencoes for each row execute function cs_intervencoes_depois();

alter table cs_intervencoes enable row level security;
drop policy if exists cs_intervencoes_acesso on cs_intervencoes;
create policy cs_intervencoes_acesso on cs_intervencoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on cs_intervencoes; drop policy if exists perm_inserir on cs_intervencoes; drop policy if exists perm_alterar on cs_intervencoes; drop policy if exists perm_excluir on cs_intervencoes;
create policy perm_ler on cs_intervencoes as restrictive for select using (perm(workspace_id, 'ler', array['revops','vendas','adm','prj','fin','gro']));
create policy perm_inserir on cs_intervencoes as restrictive for insert with check (perm(workspace_id, 'editar', array['revops','vendas']));
create policy perm_alterar on cs_intervencoes as restrictive for update using (perm(workspace_id, 'editar', array['revops','vendas'])) with check (perm(workspace_id, 'editar', array['revops','vendas']));
create policy perm_excluir on cs_intervencoes as restrictive for delete using (perm(workspace_id, 'editar', array['revops','vendas']));
grant select, insert, update, delete on cs_intervencoes to authenticated;
drop trigger if exists auditoria_t on cs_intervencoes;
create trigger auditoria_t after insert or update or delete on cs_intervencoes for each row execute function auditar();

-- ---------- B9: oportunidades de retenção e expansão ligadas à matrícula ----------
alter table oportunidades add column if not exists aluno_id uuid references alunos(id) on delete set null;
alter table oportunidades add column if not exists origem text not null default 'manual';
alter table oportunidades drop constraint if exists oportunidades_origem_check;
alter table oportunidades add constraint oportunidades_origem_check check (origem in ('manual', 'alerta', 'rfm', 'ascensao', 'marco', 'intervencao'));
alter table oportunidades drop constraint if exists oportunidades_tipo_check;
alter table oportunidades add constraint oportunidades_tipo_check check (tipo in ('nova_venda', 'renovacao', 'ajuste', 'expansao', 'retencao'));
create index if not exists oportunidades_aluno on oportunidades (aluno_id);
create or replace function public.oportunidades_aluno_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.aluno_id is not null and not exists (select 1 from alunos where id = new.aluno_id and pessoa_id = new.pessoa_id and workspace_id = new.workspace_id) then
    raise exception 'A matrícula precisa ser desta pessoa'; end if;
  return new;
end $$;
revoke execute on function public.oportunidades_aluno_valida() from public, anon, authenticated;
drop trigger if exists oportunidades_aluno_valida_t on oportunidades;
create trigger oportunidades_aluno_valida_t before insert or update of aluno_id, pessoa_id on oportunidades for each row execute function oportunidades_aluno_valida();

-- Para desfazer: voltar growths_rodar_agendado de 20261028100000_assistente_alertas.sql; drop function cg_rodar_agendado, cg_verificar_alertas;
-- delete from alertas where tipo = 'cs'; recriar alertas_tipo_check sem 'cs'; drop table cs_intervencoes (e funções cs_intervencoes_*);
-- update oportunidades set tipo = 'nova_venda' where tipo in ('expansao', 'retencao'); recriar oportunidades_tipo_check;
-- drop trigger oportunidades_aluno_valida_t; drop function oportunidades_aluno_valida; drop columns oportunidades.origem, oportunidades.aluno_id.

-- ===================== 20261122100000_customer_growth_indicadores.sql =====================
-- v0.163 — Tela Customer Growth em RevOps e indicadores de evolução (Customer Growth, etapa B10).
-- 1. acesso_telas: 'ho-cg' (Customer Growth) no módulo RevOps.
-- 2. cg_indicadores(ws, produto, ini, fim): números da evolução dos alunos, sem IA, só lendo o que já existe:
--    matrículas (ativas, novas, saíram), alunos por etapa, marcos (atingidos, % no prazo, dias até atingir), check-ins (gerados,
--    respondidos, taxa), NPS das respostas ligadas a matrículas, alertas de CS abertos, intervenções (abertas, feitas, % que resolveu)
--    e receita por cliente pela regra única do RevOps (revops_receitas), sem cálculo novo de LTV.
-- 3. Dicionário de métricas: as definições novas.
-- Rode depois de 20261121100000_acompanhamento_cs.sql. Idempotente.

do $a$ begin
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem)
    values ('ho-cg', 'revops', 'Customer Growth', 'RevOps', coalesce((select min(ordem) from acesso_telas where tela = 'crm-alunos'), 40))
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
  end if;
end $a$;

create or replace function public.cg_indicadores(p_ws uuid, p_produto uuid default null, p_ini date default null, p_fim date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ini timestamptz; fim timestamptz; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) and not pode_operar(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  if not (perm(p_ws, 'ler', array['revops', 'vendas', 'adm', 'gro']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then raise exception 'Sem permissão para ver RevOps'; end if;
  ini := (coalesce(p_ini, (now() at time zone 'America/Sao_Paulo')::date - 89))::timestamp at time zone 'America/Sao_Paulo';
  fim := (coalesce(p_fim, (now() at time zone 'America/Sao_Paulo')::date) + 1)::timestamp at time zone 'America/Sao_Paulo';
  with al as (select a.* from alunos a where a.workspace_id = p_ws and (p_produto is null or a.produto_id = p_produto)),
  ati as (select * from al where status = 'ativo' and saiu_em is null),
  et as (
    select e.id, e.nome, e.ordem, e.jornada_id, coalesce(pj.nome || ' · v' || j.versao, 'Jornada geral') as jornada, j.status as jst
      from etapas_kanban e left join jornadas j on j.id = e.jornada_id left join produtos pj on pj.id = j.produto_id
     where e.workspace_id = p_ws and e.quadro = 'alunos' and (e.jornada_id is null or j.status in ('publicada', 'anterior'))
       and (p_produto is null or j.produto_id = p_produto or (e.jornada_id is null and exists (select 1 from ati where ati.jornada_id is null)))),
  mk as (
    select m.id, m.nome, m.prazo_dias, m.obrigatorio, m.jornada_id,
      (select count(*) from ati where ati.jornada_id = m.jornada_id) as elegiveis,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido') as atingidos,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'aguardando') as aguardando,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido' and (m.prazo_dias is null or coalesce(x.validado_em, x.em) <= ati.entrou_em + make_interval(days => m.prazo_dias))) as no_prazo,
      (select round(avg(extract(epoch from (coalesce(x.validado_em, x.em) - a2.entrou_em)) / 86400)::numeric, 1) from aluno_marcos x join al a2 on a2.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido') as dias_medio,
      (select count(*) from ati where ati.jornada_id = m.jornada_id and m.prazo_dias is not null and ati.entrou_em + make_interval(days => m.prazo_dias) < now()
          and not exists (select 1 from aluno_marcos x where x.aluno_id = ati.id and x.marco_id = m.id and x.situacao = 'atingido')) as atrasados
    from jornada_marcos m join jornadas j on j.id = m.jornada_id
    where m.workspace_id = p_ws and j.status in ('publicada', 'anterior') and (p_produto is null or j.produto_id = p_produto)),
  ck as (select v.* from pesquisa_envios v join al on al.id = v.aluno_id where v.workspace_id = p_ws and v.gerado_em >= ini and v.gerado_em < fim),
  nps as (select i.valor_num as nota from pesquisa_respostas r join pesquisa_envios v on v.id = r.envio_id join al on al.id = v.aluno_id
           join pesquisa_resposta_itens i on i.resposta_id = r.id join pesquisa_perguntas q on q.id = i.pergunta_id and q.papel = 'nps'
          where r.workspace_id = p_ws and r.respondida_em >= ini and r.respondida_em < fim and i.valor_num is not null),
  iv as (select x.* from cs_intervencoes x join al on al.id = x.aluno_id where x.workspace_id = p_ws),
  rec as (select x.pessoa_id, sum(x.valor) as v from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from al) group by x.pessoa_id)
  select jsonb_build_object(
    'periodo', jsonb_build_object('ini', (ini at time zone 'America/Sao_Paulo')::date, 'fim', (fim at time zone 'America/Sao_Paulo')::date - 1),
    'matriculas', jsonb_build_object('ativas', (select count(*) from ati), 'novas', (select count(*) from al where entrou_em >= ini and entrou_em < fim),
      'sairam', (select count(*) from al where saiu_em >= ini and saiu_em < fim), 'sem_cs', (select count(*) from ati where responsavel_cs_id is null),
      'na_jornada_geral', (select count(*) from ati where jornada_id is null)),
    'etapas', coalesce((select jsonb_agg(jsonb_build_object('jornada', et.jornada, 'etapa', et.nome, 'ordem', et.ordem, 'n', (select count(*) from ati where ati.etapa_kanban_id = et.id)) order by et.jornada = 'Jornada geral', et.jornada, et.ordem) from et), '[]'),
    'marcos', coalesce((select jsonb_agg(jsonb_build_object('id', mk.id, 'nome', mk.nome, 'obrigatorio', mk.obrigatorio, 'prazo_dias', mk.prazo_dias, 'elegiveis', mk.elegiveis, 'atingidos', mk.atingidos,
      'aguardando', mk.aguardando, 'atrasados', mk.atrasados, 'pct', case when mk.elegiveis > 0 then round(mk.atingidos * 100.0 / mk.elegiveis, 1) end,
      'no_prazo_pct', case when mk.atingidos > 0 then round(mk.no_prazo * 100.0 / mk.atingidos, 1) end, 'dias_medio', mk.dias_medio) order by mk.nome) from mk), '[]'),
    'checkins', jsonb_build_object('gerados', (select count(*) from ck), 'respondidos', (select count(*) from ck where status = 'respondido'),
      'taxa', case when (select count(*) from ck where status <> 'dispensado') > 0 then round((select count(*) from ck where status = 'respondido') * 100.0 / (select count(*) from ck where status <> 'dispensado'), 1) end),
    'nps', jsonb_build_object('respostas', (select count(*) from nps), 'media', (select round(avg(nota), 1) from nps),
      'nps', case when (select count(*) from nps) > 0 then round(((select count(*) from nps where nota >= 9) - (select count(*) from nps where nota <= 6)) * 100.0 / (select count(*) from nps)) end),
    'alertas', coalesce((select jsonb_object_agg(regra, n) from (select a.regra, count(*) as n from alertas a where a.workspace_id = p_ws and a.tipo = 'cs' and a.resolvido_em is null
       and (p_produto is null or a.dados->>'produto_id' = p_produto::text) group by a.regra) t), '{}'),
    'intervencoes', jsonb_build_object('abertas', (select count(*) from iv where status = 'aberta'), 'atrasadas', (select count(*) from iv where status = 'aberta' and prazo < (now() at time zone 'America/Sao_Paulo')::date),
      'feitas', (select count(*) from iv where status = 'feita' and concluida_em >= ini and concluida_em < fim),
      'resolveu_pct', case when (select count(*) from iv where status = 'feita' and efeito is not null and concluida_em >= ini and concluida_em < fim) > 0 then
        round((select count(*) from iv where status = 'feita' and efeito = 'resolveu' and concluida_em >= ini and concluida_em < fim) * 100.0 / (select count(*) from iv where status = 'feita' and efeito is not null and concluida_em >= ini and concluida_em < fim), 1) end),
    'receita', jsonb_build_object('clientes', (select count(*) from rec), 'por_cliente', (select round(avg(v), 2) from rec), 'total', (select round(sum(v), 2) from rec),
      'regra', 'revops_receitas: vendas aprovadas sem reembolso + parcelas de contrato recebidas (a mesma de Retenção & Expansão)')
  ) into r;
  return r;
end $$;
revoke execute on function public.cg_indicadores(uuid, uuid, date, date) from public, anon;
grant execute on function public.cg_indicadores(uuid, uuid, date, date) to authenticated;

insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao) values
  ('cg_marco_pct', 'Marco atingido (%)', 'Matrículas ativas que atingiram o marco ÷ matrículas ativas na jornada do marco.', 'aluno_marcos + alunos', 'Sem matrícula ativa na jornada: sem valor.', 'Atingido = situação "atingido" (manual confirmado, automático, ou automático confirmado pela equipe).'),
  ('cg_marco_prazo', 'Marco no prazo (%)', 'Atingidos até "prazo em dias" depois da matrícula ÷ atingidos.', 'aluno_marcos + jornada_marcos.prazo_dias', 'Sem marco atingido: sem valor.', null),
  ('cg_checkin_taxa', 'Resposta dos check-ins (%)', 'Check-ins respondidos ÷ check-ins gerados no período (sem os dispensados).', 'pesquisa_envios com aluno_id', 'Sem check-in no período: sem valor.', null),
  ('cg_nps', 'NPS dos alunos', '% de notas 9 e 10 menos % de notas 0 a 6, nas respostas de pesquisas ligadas a matrículas no período.', 'pesquisa_resposta_itens (pergunta de papel nps)', 'Sem resposta: sem valor.', null),
  ('cg_intervencao_resolveu', 'Intervenções que resolveram (%)', 'Intervenções feitas no período com efeito "resolveu" ÷ intervenções feitas com efeito informado.', 'cs_intervencoes', 'Sem intervenção feita com efeito: sem valor.', null)
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao, atualizado_em = now();
do $s$ begin
  if exists (select 1 from information_schema.columns where table_name = 'metricas_definicoes' and column_name = 'unidade') then
    update metricas_definicoes set unidade = case when codigo = 'cg_nps' then 'numero' else 'pct' end, casas = case when codigo = 'cg_nps' then 0 else 1 end, direcao = 'maior'
     where codigo in ('cg_marco_pct', 'cg_marco_prazo', 'cg_checkin_taxa', 'cg_nps', 'cg_intervencao_resolveu');
  end if;
end $s$;

-- Para desfazer: drop function if exists public.cg_indicadores(uuid, uuid, date, date); delete from acesso_telas where tela = 'ho-cg';
-- delete from metricas_definicoes where codigo like 'cg\_%';

-- ===================== 20261123100000_cg_alertas_chave.sql =====================
-- v0.163 — Alertas de CS só depois de ligados, e fora do resumo do dia e do "Pergunte ao Growths".
-- Motivo: em produção, a primeira passada criou centenas de alertas de CS (alunos parados e sem CS) de uma vez. A tela antiga
-- "Alertas e resumo do dia" mostra os 200 mais recentes de todos os tipos e o resumo do dia lista todos os do dia: os de CS
-- tomariam o lugar dos alertas de negócio.
-- 1. sistema_config 'cg_alertas' ('sim' | 'nao', padrão 'nao'): o agendador só gera alertas de CS com 'sim'. Os check-ins continuam.
-- 2. cg_ligar_alertas(): registra em silêncio o que já está acontecendo (sem avisar ninguém) e liga. Rodar quando a tela
--    RevOps → Customer Growth estiver no ar.
-- 3. Os alertas de CS saem do resumo do dia (growths_fatos_dia) e dos alertas abertos do "Pergunte ao Growths" (growths_ia_extra);
--    eles têm a tela própria em Customer Growth.
-- 4. Apaga os alertas de CS gerados antes de ligar (eram só o acúmulo da primeira passada; nada aponta para eles).
-- Rode depois de 20261122100000_customer_growth_indicadores.sql. Idempotente.

insert into sistema_config (chave, valor) values ('cg_alertas', 'nao') on conflict (chave) do nothing;

create or replace function public.cg_rodar_agendado(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0; ck int := 0; liga boolean := coalesce((select valor from sistema_config where chave = 'cg_alertas'), 'nao') = 'sim';
begin
  begin ck := pesquisa_checkins_gerar(p_ref, null); exception when others then raise warning 'cg_rodar_agendado (check-ins): %', sqlerrm; end;
  if liga then
    for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
      begin perform cg_verificar_alertas(w.workspace_id, p_ref, true); n := n + 1;
      exception when others then raise warning 'cg_rodar_agendado %: %', w.workspace_id, sqlerrm; end;
    end loop;
  end if;
  return jsonb_build_object('clientes', n, 'checkins', ck, 'alertas_cs', liga);
end $$;
revoke all on function public.cg_rodar_agendado(timestamptz) from public, anon, authenticated;

create or replace function public.cg_ligar_alertas() returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0;
begin
  if not (session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role' or sou_equipe_interna()) then raise exception 'Só a equipe interna liga os alertas de CS'; end if;
  for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
    begin perform cg_verificar_alertas(w.workspace_id, now(), false); n := n + 1;
    exception when others then raise warning 'cg_ligar_alertas %: %', w.workspace_id, sqlerrm; end;
  end loop;
  insert into sistema_config (chave, valor) values ('cg_alertas', 'sim') on conflict (chave) do update set valor = 'sim';
  return jsonb_build_object('clientes', n, 'alertas_abertos', (select count(*) from alertas where tipo = 'cs' and resolvido_em is null));
end $$;
revoke all on function public.cg_ligar_alertas() from public, anon;
grant execute on function public.cg_ligar_alertas() to authenticated;

do $m$
declare d text; n text;
begin
  select replace(pg_get_functiondef('public.growths_fatos_dia(uuid, date)'::regprocedure), E'\r\n', E'\n') into d;
  if position('tipo <> ''cs''' in d) = 0 then
    n := replace(d, 'from alertas where workspace_id = p_ws and dia = p_dia)', 'from alertas where workspace_id = p_ws and dia = p_dia and tipo <> ''cs'')');
    if n = d then raise exception 'growths_fatos_dia: trecho dos alertas do dia não encontrado'; end if;
    execute n;
  end if;
  select replace(pg_get_functiondef('public.growths_ia_extra(uuid, date, date)'::regprocedure), E'\r\n', E'\n') into d;
  if position('tipo <> ''cs''' in d) = 0 then
    n := replace(d, 'from alertas where workspace_id = p_ws and resolvido_em is null order by', 'from alertas where workspace_id = p_ws and resolvido_em is null and tipo <> ''cs'' order by');
    if n = d then raise exception 'growths_ia_extra: trecho dos alertas abertos não encontrado'; end if;
    execute n;
  end if;
end $m$;

delete from alertas a where a.tipo = 'cs' and coalesce((select valor from sistema_config where chave = 'cg_alertas'), 'nao') <> 'sim'
  and not exists (select 1 from cs_intervencoes i where i.alerta_id = a.id);

-- Para desfazer: cg_rodar_agendado de 20261121100000 (sem a chave); drop function cg_ligar_alertas(); tirar "and tipo <> 'cs'" das duas funções;
-- delete from sistema_config where chave = 'cg_alertas'.

commit;
select 'v0.163 aplicada' as resultado;
