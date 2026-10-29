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
alter table etapas_kanban drop constraint if exists etapas_kanban_workspace_id_quadro_nome_key;
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
