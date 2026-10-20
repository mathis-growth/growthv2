-- v0.81 — Blocos de estratégia e Simulador de lucro
-- 1. Blocos: a estratégia passa a ser montada com blocos prontos (Conteúdo, Tráfego, Grupo, Aula, Checkout...).
--    Cada bloco agrupa etapas-métrica; uma delas é a principal (passa para o próximo bloco), as outras são de diagnóstico.
-- 2. Simulador de lucro (Growth): cenários salvos em JSON + fotos (snapshots) com a versão da fórmula.
-- Idempotente. Depende da 20261008220000_estrategias_jornada.sql. Rode também a 20261008230000_seguranca_fase1.sql se ainda não rodou.

-- ---------- 1. Blocos ----------
create table if not exists estrategia_blocos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references funis(id) on delete cascade,
  ordem int not null default 10,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  tipo text not null,
  nome text not null,
  origem_ref uuid,
  criado_em timestamptz not null default now()
);
create index if not exists estrategia_blocos_funil on estrategia_blocos (funil_id);

create table if not exists campanha_blocos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  bloco_origem_id uuid,
  ordem int not null default 10,
  fase text not null default 'aquisicao' check (fase in ('aquisicao', 'aquecimento', 'conversao', 'retencao')),
  tipo text not null,
  nome text not null,
  origem_ref uuid,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create index if not exists campanha_blocos_campanha on campanha_blocos (campanha_id);

alter table estrategia_etapas add column if not exists bloco_id uuid references estrategia_blocos(id) on delete cascade;
alter table estrategia_etapas add column if not exists papel text;
alter table estrategia_etapas add column if not exists fonte text;
alter table campanha_etapas add column if not exists bloco_id uuid references campanha_blocos(id) on delete cascade;
alter table campanha_etapas add column if not exists papel text;
alter table campanha_etapas add column if not exists fonte text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'estrategia_etapas_papel_chk') then
    alter table estrategia_etapas add constraint estrategia_etapas_papel_chk check (papel is null or papel in ('principal', 'diagnostico'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'campanha_etapas_papel_chk') then
    alter table campanha_etapas add constraint campanha_etapas_papel_chk check (papel is null or papel in ('principal', 'diagnostico'));
  end if;
end $$;
create index if not exists estrategia_etapas_bloco on estrategia_etapas (bloco_id);
create index if not exists campanha_etapas_bloco on campanha_etapas (bloco_id);

-- bloco e etapa do mesmo workspace e da mesma estratégia/campanha
create or replace function bloco_etapa_valida() returns trigger language plpgsql set search_path = public as $$
begin
  if new.bloco_id is null then return new; end if;
  if tg_table_name = 'estrategia_etapas' then
    if not exists (select 1 from estrategia_blocos b where b.id = new.bloco_id and b.funil_id = new.funil_id and b.workspace_id = new.workspace_id) then
      raise exception 'O bloco não pertence a esta estratégia.';
    end if;
  else
    if not exists (select 1 from campanha_blocos b where b.id = new.bloco_id and b.campanha_id = new.campanha_id and b.workspace_id = new.workspace_id) then
      raise exception 'O bloco não pertence a esta campanha.';
    end if;
  end if;
  return new;
end $$;
revoke execute on function bloco_etapa_valida() from public, anon;
drop trigger if exists estrategia_etapas_bloco_t on estrategia_etapas;
create trigger estrategia_etapas_bloco_t before insert or update of bloco_id on estrategia_etapas for each row execute function bloco_etapa_valida();
drop trigger if exists campanha_etapas_bloco_t on campanha_etapas;
create trigger campanha_etapas_bloco_t before insert or update of bloco_id on campanha_etapas for each row execute function bloco_etapa_valida();

-- RLS: mesmo padrão de estrategia_etapas/campanha_etapas (v0.77): ler mkt/vendas/gro/adm, editar mkt/gro
alter table estrategia_blocos enable row level security;
alter table campanha_blocos enable row level security;
do $$ declare t text; begin
  foreach t in array array['estrategia_blocos', 'campanha_blocos'] loop
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
  end loop;
end $$;

-- aplicar a estratégia na campanha agora copia os blocos e liga cada etapa ao bloco copiado
create or replace function campanha_aplicar_estrategia(p_campanha uuid, p_funil uuid, p_substituir boolean default false) returns int
language plpgsql set search_path = public as $$
declare v_ws uuid; v_n int; b record; v_novo uuid;
begin
  select workspace_id into v_ws from campanhas where id = p_campanha;
  if v_ws is null then raise exception 'Campanha não encontrada.'; end if;
  if not exists (select 1 from funis where id = p_funil and workspace_id = v_ws) then raise exception 'Estratégia não encontrada.'; end if;
  update campanhas set funil_id = p_funil where id = p_campanha;
  if p_substituir then
    delete from campanha_etapas where campanha_id = p_campanha;
    delete from campanha_blocos where campanha_id = p_campanha;
  end if;
  -- blocos que ainda não estão na campanha
  for b in select * from estrategia_blocos where funil_id = p_funil order by ordem loop
    -- só copia o bloco se ele ainda não está na campanha e se pelo menos uma etapa dele vai entrar (chave nova)
    if not exists (select 1 from campanha_blocos where campanha_id = p_campanha and bloco_origem_id = b.id)
       and exists (select 1 from estrategia_etapas e where e.bloco_id = b.id
                   and not exists (select 1 from campanha_etapas x where x.campanha_id = p_campanha and x.chave = e.chave)) then
      insert into campanha_blocos (workspace_id, campanha_id, bloco_origem_id, ordem, fase, tipo, nome, origem_ref)
      values (v_ws, p_campanha, b.id, b.ordem, b.fase, b.tipo, b.nome, b.origem_ref);
    end if;
  end loop;
  insert into campanha_etapas (workspace_id, campanha_id, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada, bloco_id, papel, fonte)
  select v_ws, p_campanha, e.ordem, e.fase, e.chave, e.nome, e.unidade, e.origem, e.metrica, e.origem_ref, e.conta_como, e.taxa_esperada,
         (select cb.id from campanha_blocos cb where cb.campanha_id = p_campanha and cb.bloco_origem_id = e.bloco_id limit 1), e.papel, e.fonte
  from estrategia_etapas e where e.funil_id = p_funil
  on conflict (campanha_id, chave) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) from public, anon;
grant execute on function campanha_aplicar_estrategia(uuid, uuid, boolean) to authenticated;

-- o funil da campanha devolve também bloco, papel e fonte (para agrupar e calcular pela principal)
do $$
declare d text; n text;
begin
  d := pg_get_functiondef('public.campanha_funil_etapas(uuid,date,date)'::regprocedure);
  if position('''bloco_id''' in d) > 0 then return; end if;
  n := replace(d, '''valor'', coalesce(v, 0), ''tem'', v is not null)', '''valor'', coalesce(v, 0), ''tem'', v is not null, ''bloco_id'', e.bloco_id, ''papel'', e.papel, ''fonte'', e.fonte)');
  if n = d then raise exception 'campanha_funil_etapas: trecho esperado não encontrado — revisar'; end if;
  execute n;
end $$;
revoke execute on function campanha_funil_etapas(uuid, date, date) from public, anon;
grant execute on function campanha_funil_etapas(uuid, date, date) to authenticated;

-- ---------- 2. Simulador de lucro ----------
create table if not exists simulador_cenarios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  dados jsonb not null default '{}'::jsonb check (jsonb_typeof(dados) = 'object'),
  versao_formula text not null default 'gps-1.0',
  status text not null default 'rascunho' check (status in ('rascunho', 'ativo', 'arquivado')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists simulador_cenarios_ws on simulador_cenarios (workspace_id);

create table if not exists simulador_snapshots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  cenario_id uuid not null references simulador_cenarios(id) on delete cascade,
  nome text not null,
  versao_formula text not null,
  premissas jsonb not null check (jsonb_typeof(premissas) = 'object'),
  metricas jsonb not null check (jsonb_typeof(metricas) = 'object'),
  calculado_em timestamptz not null default now(),
  criado_por uuid default auth.uid()
);
create index if not exists simulador_snapshots_cenario on simulador_snapshots (cenario_id);

create or replace function simulador_mesmo_ws() returns trigger language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from simulador_cenarios c where c.id = new.cenario_id and c.workspace_id = new.workspace_id) then
    raise exception 'Cenário de outro workspace.';
  end if;
  return new;
end $$;
revoke execute on function simulador_mesmo_ws() from public, anon;
drop trigger if exists simulador_snapshots_ws on simulador_snapshots;
create trigger simulador_snapshots_ws before insert or update on simulador_snapshots for each row execute function simulador_mesmo_ws();

alter table simulador_cenarios enable row level security;
alter table simulador_snapshots enable row level security;
do $$ declare t text; begin
  foreach t in array array['simulador_cenarios', 'simulador_snapshots'] loop
    execute format('drop policy if exists %1$s_acesso on %1$s', t);
    execute format('drop policy if exists perm_ler on %1$s', t);
    execute format('drop policy if exists perm_inserir on %1$s', t);
    execute format('drop policy if exists perm_alterar on %1$s', t);
    execute format('drop policy if exists perm_excluir on %1$s', t);
    execute format('create policy %1$s_acesso on %1$s for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t);
    execute format('create policy perm_ler on %1$s as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''gro'',''fin'',''adm'']))', t);
    execute format('create policy perm_inserir on %1$s as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_alterar on %1$s as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_excluir on %1$s as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
  end loop;
end $$;
-- snapshot é foto: não se altera depois de gravado
revoke update on simulador_snapshots from authenticated;
