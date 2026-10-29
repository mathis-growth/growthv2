-- v0.165 — Strategy Canvas, etapas S1 a S3: biblioteca de estratégias, mapa (posições e conexões) e versões.
-- A estratégia continua sendo funis; os blocos continuam em estrategia_blocos e as métricas em estrategia_etapas.
-- 1. funis: categoria, objetivo, status (rascunho, ativa, arquivada), versao_atual, criterios. Arquivar desliga (ativo = false).
-- 2. estrategia_blocos e campanha_blocos: posição no mapa (x, y) e propriedades (props: objetivo, canal, produto_id, oferta_id,
--    responsavel_id, status, meta, eventos, dependencias, notas, e, no bloco personalizado, rotulo e icone). campanha_blocos.status
--    (planejado, implementado, pendente) para o mapa da campanha.
-- 3. estrategia_conexoes (de um bloco para outro): tipo segue | sim | nao | divisao, rótulo, condição, nota, peso (% na divisão).
--    campanha_conexoes: a cópia na campanha (igual às etapas: mudar a estratégia depois não muda a campanha).
-- 4. estrategia_versoes: foto imutável (estratégia, blocos, conexões, métricas) a cada "Publicar" (estrategia_publicar).
--    campanha_estrategias.versao_id: a versão que a campanha usou. Campanha criada com estratégia nunca publicada grava a versão 1 sozinha.
-- 5. campanha_aplicar_estrategia passa a copiar posições, propriedades e conexões e a gravar a versão.
-- Rode depois de 20261123100000_cg_alertas_chave.sql. Idempotente.

-- ---------- 1. biblioteca ----------
alter table funis add column if not exists categoria text check (categoria is null or char_length(categoria) <= 60);
alter table funis add column if not exists objetivo text check (objetivo is null or char_length(objetivo) <= 2000);
alter table funis add column if not exists status text not null default 'ativa';
alter table funis add column if not exists versao_atual int not null default 0 check (versao_atual >= 0);
alter table funis add column if not exists criterios text check (criterios is null or char_length(criterios) <= 4000);
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'funis_status_check') then
    alter table funis add constraint funis_status_check check (status in ('rascunho', 'ativa', 'arquivada'));
  end if;
end $c$;
update funis set status = 'arquivada' where not ativo and status = 'ativa';
create or replace function public.funis_status_t() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if not new.ativo then new.status := 'arquivada'; else new.ativo := new.status <> 'arquivada'; end if;
  elsif new.status is distinct from old.status then new.ativo := new.status <> 'arquivada';
  elsif new.ativo is distinct from old.ativo then new.status := case when new.ativo then (case when old.status = 'arquivada' then 'ativa' else old.status end) else 'arquivada' end;
  end if;
  return new;
end $$;
revoke execute on function public.funis_status_t() from public, anon, authenticated;
drop trigger if exists funis_status_t on funis;
create trigger funis_status_t before insert or update of status, ativo on funis for each row execute function funis_status_t();

-- ---------- 2. posições e propriedades ----------
alter table estrategia_blocos add column if not exists x numeric;
alter table estrategia_blocos add column if not exists y numeric;
alter table estrategia_blocos add column if not exists props jsonb not null default '{}'::jsonb;
alter table campanha_blocos add column if not exists x numeric;
alter table campanha_blocos add column if not exists y numeric;
alter table campanha_blocos add column if not exists props jsonb not null default '{}'::jsonb;
alter table campanha_blocos add column if not exists status text;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'estrategia_blocos_props_ck') then
    alter table estrategia_blocos add constraint estrategia_blocos_props_ck check (jsonb_typeof(props) = 'object');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'campanha_blocos_props_ck') then
    alter table campanha_blocos add constraint campanha_blocos_props_ck check (jsonb_typeof(props) = 'object');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'campanha_blocos_status_ck') then
    alter table campanha_blocos add constraint campanha_blocos_status_ck check (status is null or status in ('planejado', 'implementado', 'pendente'));
  end if;
end $c$;

-- ---------- 3. conexões ----------
create table if not exists estrategia_conexoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  de_bloco uuid not null references estrategia_blocos(id) on delete cascade,
  para_bloco uuid not null references estrategia_blocos(id) on delete cascade,
  tipo text not null default 'segue' check (tipo in ('segue', 'sim', 'nao', 'divisao')),
  rotulo text check (rotulo is null or char_length(rotulo) <= 80),
  condicao text check (condicao is null or char_length(condicao) <= 500),
  nota text check (nota is null or char_length(nota) <= 2000),
  peso numeric check (peso is null or (peso >= 0 and peso <= 100)),
  criado_em timestamptz not null default now(),
  check (de_bloco <> para_bloco),
  unique (de_bloco, para_bloco)
);
create index if not exists estrategia_conexoes_funil on estrategia_conexoes (funil_id);
create table if not exists campanha_conexoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  conexao_origem_id uuid,
  de_bloco uuid not null references campanha_blocos(id) on delete cascade,
  para_bloco uuid not null references campanha_blocos(id) on delete cascade,
  tipo text not null default 'segue' check (tipo in ('segue', 'sim', 'nao', 'divisao')),
  rotulo text check (rotulo is null or char_length(rotulo) <= 80),
  condicao text check (condicao is null or char_length(condicao) <= 500),
  nota text check (nota is null or char_length(nota) <= 2000),
  peso numeric check (peso is null or (peso >= 0 and peso <= 100)),
  criado_em timestamptz not null default now(),
  check (de_bloco <> para_bloco),
  unique (de_bloco, para_bloco)
);
create index if not exists campanha_conexoes_camp on campanha_conexoes (campanha_id);

create or replace function public.conexao_valida() returns trigger language plpgsql set search_path = public as $$
begin
  if new.de_bloco = new.para_bloco then raise exception 'Uma conexão liga dois blocos diferentes.' using errcode = '23514'; end if;
  if tg_table_name = 'estrategia_conexoes' then
    if (select count(*) from estrategia_blocos b where b.id in (new.de_bloco, new.para_bloco) and b.funil_id = new.funil_id and b.workspace_id = new.workspace_id) <> 2 then
      raise exception 'Os dois blocos precisam ser desta estratégia.'; end if;
  else
    if (select count(*) from campanha_blocos b where b.id in (new.de_bloco, new.para_bloco) and b.campanha_id = new.campanha_id and b.workspace_id = new.workspace_id) <> 2 then
      raise exception 'Os dois blocos precisam ser desta campanha.'; end if;
  end if;
  if new.tipo <> 'divisao' then new.peso := null; end if;
  return new;
end $$;
revoke execute on function public.conexao_valida() from public, anon;
drop trigger if exists estrategia_conexoes_valida_t on estrategia_conexoes;
create trigger estrategia_conexoes_valida_t before insert or update on estrategia_conexoes for each row execute function conexao_valida();
drop trigger if exists campanha_conexoes_valida_t on campanha_conexoes;
create trigger campanha_conexoes_valida_t before insert or update on campanha_conexoes for each row execute function conexao_valida();

-- ---------- 4. versões ----------
create table if not exists estrategia_versoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  versao int not null check (versao >= 1),
  foto jsonb not null check (jsonb_typeof(foto) = 'object'),
  nota text check (nota is null or char_length(nota) <= 1000),
  publicada_por uuid default auth.uid(),
  publicada_em timestamptz not null default now(),
  unique (funil_id, versao)
);
create or replace function public.estrategia_versoes_imutavel() returns trigger language plpgsql as $$
begin raise exception 'Versão publicada não muda: publique uma nova versão.'; end $$;
drop trigger if exists estrategia_versoes_imutavel_t on estrategia_versoes;
create trigger estrategia_versoes_imutavel_t before update on estrategia_versoes for each row execute function estrategia_versoes_imutavel();
alter table campanha_estrategias add column if not exists versao_id uuid references estrategia_versoes(id) on delete set null;

-- RLS: mesmo padrão dos blocos (ler mkt/vendas/gro/adm, editar mkt/gro)
do $$ declare t text; begin
  foreach t in array array['estrategia_conexoes', 'campanha_conexoes', 'estrategia_versoes'] loop
    execute format('alter table %1$s enable row level security', t);
    execute format('drop policy if exists %1$s_acesso on %1$s', t);
    execute format('drop policy if exists perm_ler on %1$s', t);
    execute format('drop policy if exists perm_inserir on %1$s', t);
    execute format('drop policy if exists perm_alterar on %1$s', t);
    execute format('drop policy if exists perm_excluir on %1$s', t);
    execute format('create policy %1$s_acesso on %1$s for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t);
    execute format('create policy perm_ler on %1$s as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''mkt'',''vendas'',''gro'',''adm'']))', t);
    execute format('create policy perm_inserir on %1$s as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
    execute format('create policy perm_alterar on %1$s as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
    execute format('create policy perm_excluir on %1$s as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''mkt'',''gro'']))', t);
    execute format('grant select, insert, update, delete on %1$s to authenticated', t);
  end loop;
end $$;

-- Publica a estratégia como está agora: devolve o número da versão nova.
create or replace function public.estrategia_publicar(p_funil uuid, p_nota text default null) returns int
language plpgsql set search_path = public as $$
declare f funis; v int; foto jsonb;
begin
  select * into f from funis where id = p_funil for update;
  if not found then raise exception 'Estratégia não encontrada.'; end if;
  if not pode_operar(f.workspace_id) or not (perm(f.workspace_id, 'editar', array['mkt', 'gro']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then
    raise exception 'Sem permissão para publicar esta estratégia.'; end if;
  v := coalesce((select max(versao) from estrategia_versoes where funil_id = p_funil), 0) + 1;
  foto := jsonb_build_object(
    'estrategia', jsonb_build_object('nome', f.nome, 'tipo', f.tipo, 'produto_id', f.produto_id, 'descricao', f.descricao, 'categoria', f.categoria, 'objetivo', f.objetivo, 'criterios', f.criterios),
    'blocos', coalesce((select jsonb_agg(to_jsonb(b) - 'workspace_id' - 'funil_id' order by b.fase, b.ordem) from estrategia_blocos b where b.funil_id = p_funil), '[]'::jsonb),
    'conexoes', coalesce((select jsonb_agg(to_jsonb(c) - 'workspace_id' - 'funil_id' order by c.criado_em) from estrategia_conexoes c where c.funil_id = p_funil), '[]'::jsonb),
    'etapas', coalesce((select jsonb_agg(to_jsonb(e) - 'workspace_id' - 'funil_id' order by e.ordem) from estrategia_etapas e where e.funil_id = p_funil), '[]'::jsonb));
  insert into estrategia_versoes (workspace_id, funil_id, versao, foto, nota) values (f.workspace_id, p_funil, v, foto, nullif(trim(coalesce(p_nota, '')), ''));
  update funis set versao_atual = v, status = case when status = 'rascunho' then 'ativa' else status end where id = p_funil;
  return v;
end $$;
revoke execute on function public.estrategia_publicar(uuid, text) from public, anon;
grant execute on function public.estrategia_publicar(uuid, text) to authenticated;

-- ---------- 5. aplicar na campanha: também posições, propriedades, conexões e a versão ----------
create or replace function campanha_aplicar_estrategia(p_campanha uuid, p_funil uuid, p_substituir boolean default false) returns int
language plpgsql set search_path = public as $$
declare v_ws uuid; v_n int; b record; v_ver uuid;
begin
  select workspace_id into v_ws from campanhas where id = p_campanha;
  if v_ws is null then raise exception 'Campanha não encontrada.'; end if;
  if not exists (select 1 from funis where id = p_funil and workspace_id = v_ws) then raise exception 'Estratégia não encontrada.'; end if;
  update campanhas set funil_id = p_funil where id = p_campanha;
  if p_substituir then
    delete from campanha_conexoes where campanha_id = p_campanha;
    delete from campanha_etapas where campanha_id = p_campanha;
    delete from campanha_blocos where campanha_id = p_campanha;
  end if;
  -- blocos que ainda não estão na campanha
  for b in select * from estrategia_blocos where funil_id = p_funil order by ordem loop
    -- só copia o bloco se ele ainda não está na campanha e se pelo menos uma etapa dele vai entrar (chave nova), ou se é um bloco sem métricas (lógica, personalizado)
    if not exists (select 1 from campanha_blocos where campanha_id = p_campanha and bloco_origem_id = b.id)
       and (exists (select 1 from estrategia_etapas e where e.bloco_id = b.id
                    and not exists (select 1 from campanha_etapas x where x.campanha_id = p_campanha and x.chave = e.chave))
            or not exists (select 1 from estrategia_etapas e where e.bloco_id = b.id)) then
      insert into campanha_blocos (workspace_id, campanha_id, bloco_origem_id, ordem, fase, tipo, nome, origem_ref, x, y, props, status)
      values (v_ws, p_campanha, b.id, b.ordem, b.fase, b.tipo, b.nome, b.origem_ref, b.x, b.y, b.props, 'planejado');
    end if;
  end loop;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada, bloco_id, papel, fonte)
  select v_ws, p_campanha, e.ordem, e.fase, e.chave, e.nome, e.unidade, e.origem, e.metrica, e.origem_ref, e.conta_como, e.taxa_esperada,
         (select cb.id from campanha_blocos cb where cb.campanha_id = p_campanha and cb.bloco_origem_id = e.bloco_id limit 1), e.papel, e.fonte
  from estrategia_etapas e where e.funil_id = p_funil
  on conflict (campanha_id, chave) do nothing;
  get diagnostics v_n = row_count;
  -- conexões entre blocos que estão na campanha
  insert into campanha_conexoes (workspace_id, campanha_id, conexao_origem_id, de_bloco, para_bloco, tipo, rotulo, condicao, nota, peso)
  select v_ws, p_campanha, c.id, d.id, p.id, c.tipo, c.rotulo, c.condicao, c.nota, c.peso
  from estrategia_conexoes c
  join campanha_blocos d on d.campanha_id = p_campanha and d.bloco_origem_id = c.de_bloco
  join campanha_blocos p on p.campanha_id = p_campanha and p.bloco_origem_id = c.para_bloco
  where c.funil_id = p_funil
  on conflict (de_bloco, para_bloco) do nothing;
  -- a versão usada (estratégia nunca publicada: publica a versão 1 agora)
  select id into v_ver from estrategia_versoes where funil_id = p_funil order by versao desc limit 1;
  if v_ver is null then perform estrategia_publicar(p_funil, 'Publicada ao criar a primeira campanha'); select id into v_ver from estrategia_versoes where funil_id = p_funil order by versao desc limit 1; end if;
  update campanha_estrategias set versao_id = v_ver where campanha_id = p_campanha and funil_id = p_funil;
  return v_n;
end $$;
revoke execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) from public, anon;
grant execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) to authenticated;

-- Para desfazer: campanha_aplicar_estrategia de 20261010200000_blocos_e_simulador.sql; drop function estrategia_publicar(uuid, text);
-- alter table campanha_estrategias drop column versao_id; drop table estrategia_versoes, campanha_conexoes, estrategia_conexoes;
-- drop function conexao_valida(), estrategia_versoes_imutavel(); drop columns x, y, props (e status em campanha_blocos);
-- drop trigger funis_status_t; drop function funis_status_t(); alter table funis drop column categoria, objetivo, status, versao_atual, criterios.
