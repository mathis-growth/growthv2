-- v0.98 — Growth Now, fase B: cenários nomeados do Growth Model, baseline travado e auditoria
-- 1. gm_cenarios: cenário com nome, hipótese, autor, escopo (filtros e período), status (rascunho/aprovado/arquivado), versão, foto do baseline,
--    resultados projetados, premissas financeiras (regime, % variáveis, ajuste de custos fixos), ICE e os dados do Unit Economics (ue).
-- 2. gm_alavancas.cenario passa a aceitar o id do cenário; o antigo 'sim' de cada empresa vira o "Cenário 1".
-- 3. Baseline travado: o que está em cenario = 'base' são as "premissas do baseline"; só um administrador muda, pela função gm_premissas_salvar
--    (com motivo, registrado na auditoria). Cenário aprovado também fica congelado (para mudar, duplica).
-- 4. Cenários do Unit Economics (simulador_cenarios, se existir) viram cenários do Growth Model, com os dados em gm_cenarios.ue.
-- Rode DEPOIS de 20261011700000_ofertas_esteira_campanha.sql. Idempotente.

create table if not exists gm_cenarios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  hipotese text,
  autor uuid default auth.uid(),
  escopo jsonb not null default '{}'::jsonb check (jsonb_typeof(escopo) = 'object'),
  status text not null default 'rascunho' check (status in ('rascunho', 'aprovado', 'arquivado')),
  versao int not null default 1,
  substitui_id uuid references gm_cenarios(id) on delete set null,
  baseline jsonb,
  resultados jsonb,
  financeiro jsonb not null default '{}'::jsonb check (jsonb_typeof(financeiro) = 'object'),
  ue jsonb,
  impacto int check (impacto is null or impacto between 1 and 10),
  confianca int check (confianca is null or confianca between 1 and 10),
  facilidade int check (facilidade is null or facilidade between 1 and 10),
  ice_justificativa text,
  aprovado_em timestamptz,
  aprovado_por uuid,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists gm_cenarios_ws on gm_cenarios (workspace_id, status);
alter table gm_cenarios enable row level security;
drop policy if exists gm_cenarios_acesso on gm_cenarios;
create policy gm_cenarios_acesso on gm_cenarios for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on gm_cenarios;
create policy perm_ler on gm_cenarios as restrictive for select using (perm(workspace_id, 'ler', '{gro,adm,mkt}'::text[]));
drop policy if exists perm_escrever on gm_cenarios;
create policy perm_escrever on gm_cenarios as restrictive for all using (perm(workspace_id, 'editar', '{gro}'::text[])) with check (perm(workspace_id, 'editar', '{gro}'::text[]));

-- cenário aprovado é congelado: só pode ir para arquivado; arquivado só volta a rascunho se nunca foi aprovado
create or replace function public.gm_cenarios_guarda() returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'aprovado' or old.aprovado_em is not null then raise exception 'Cenário aprovado não pode ser excluído: arquive-o'; end if;
    return old;
  end if;
  if old.status = 'aprovado' or (old.aprovado_em is not null and old.status = 'arquivado') then
    if new.status = 'arquivado' and old.status = 'aprovado'
       and new.nome = old.nome and new.escopo = old.escopo and new.financeiro = old.financeiro and coalesce(new.ue, '{}') = coalesce(old.ue, '{}')
       and coalesce(new.resultados, '{}') = coalesce(old.resultados, '{}') and coalesce(new.baseline, '{}') = coalesce(old.baseline, '{}') then
      new.atualizado_em := now(); return new;
    end if;
    raise exception 'Cenário aprovado está congelado: duplique para criar uma nova versão';
  end if;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists gm_cenarios_guarda_t on gm_cenarios;
create trigger gm_cenarios_guarda_t before update or delete on gm_cenarios for each row execute function gm_cenarios_guarda();

-- alavancas: cenário = 'base' ou id do cenário
alter table gm_alavancas drop constraint if exists gm_alavancas_cenario_check;
do $$
declare w record; novo uuid;
begin
  for w in select distinct workspace_id from gm_alavancas where cenario = 'sim' loop
    insert into gm_cenarios (workspace_id, nome, hipotese, autor) values (w.workspace_id, 'Cenário 1', 'Cenário que já existia no Growth Model antes dos cenários nomeados.', null) returning id into novo;
    update gm_alavancas set cenario = novo::text where workspace_id = w.workspace_id and cenario = 'sim';
  end loop;
end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'gm_alavancas_cenario_ok') then
    alter table gm_alavancas add constraint gm_alavancas_cenario_ok check (cenario = 'base' or cenario ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  end if;
end $$;

create or replace function public.gm_alavancas_guarda() returns trigger language plpgsql set search_path = public as $$
declare r gm_alavancas; st text;
begin
  r := case when tg_op = 'DELETE' then old else new end;
  if r.cenario = 'base' then
    if coalesce(current_setting('growths.gm_premissas', true), '') <> '1' then
      raise exception 'O baseline está travado. Premissas do baseline só mudam por um administrador, em "Premissas do baseline", com motivo.';
    end if;
  else
    select status into st from gm_cenarios where id = r.cenario::uuid;
    if st is null then raise exception 'Cenário não encontrado'; end if;
    if st <> 'rascunho' then raise exception 'Este cenário está %: duplique para criar uma nova versão', st; end if;
    if tg_op = 'UPDATE' and old.cenario <> new.cenario then raise exception 'Não dá para mover ajuste entre cenários'; end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists gm_alavancas_guarda_t on gm_alavancas;
create trigger gm_alavancas_guarda_t before insert or update or delete on gm_alavancas for each row execute function gm_alavancas_guarda();

-- premissas do baseline: só administrador, com motivo (fica na auditoria)
create or replace function public.gm_premissas_salvar(p_ws uuid, p_linhas jsonb, p_remover jsonb, p_motivo text)
returns int language plpgsql security definer set search_path = public as $$
declare n int := 0; e jsonb;
begin
  if not pertence_ao_workspace(p_ws) or not eh_admin(p_ws) then raise exception 'Só um administrador muda as premissas do baseline'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Diga o motivo da mudança na premissa do baseline'; end if;
  perform set_config('growths.gm_premissas', '1', true);
  perform set_config('growths.motivo', left(trim(p_motivo), 300), true);
  for e in select * from jsonb_array_elements(coalesce(p_remover, '[]'::jsonb)) loop
    delete from gm_alavancas where workspace_id = p_ws and cenario = 'base' and loop_chave = e ->> 'loop_chave' and alavanca = e ->> 'alavanca' and mes = (e ->> 'mes')::date
      and coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(nullif(e ->> 'produto_id', '')::uuid, '00000000-0000-0000-0000-000000000000'::uuid);
    n := n + 1;
  end loop;
  for e in select * from jsonb_array_elements(coalesce(p_linhas, '[]'::jsonb)) loop
    delete from gm_alavancas where workspace_id = p_ws and cenario = 'base' and loop_chave = e ->> 'loop_chave' and alavanca = e ->> 'alavanca' and mes = (e ->> 'mes')::date
      and coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid) = coalesce(nullif(e ->> 'produto_id', '')::uuid, '00000000-0000-0000-0000-000000000000'::uuid);
    insert into gm_alavancas (workspace_id, loop_chave, produto_id, alavanca, mes, cenario, valor)
    values (p_ws, e ->> 'loop_chave', nullif(e ->> 'produto_id', '')::uuid, e ->> 'alavanca', (e ->> 'mes')::date, 'base', (e ->> 'valor')::numeric);
    n := n + 1;
  end loop;
  perform set_config('growths.gm_premissas', '', true);
  return n;
end $$;
revoke execute on function public.gm_premissas_salvar(uuid, jsonb, jsonb, text) from public, anon;
grant execute on function public.gm_premissas_salvar(uuid, jsonb, jsonb, text) to authenticated, service_role;

-- cenários do Unit Economics viram cenários do Growth Model (os dados do simulador ficam em gm_cenarios.ue)
do $$ begin
  if to_regclass('public.simulador_cenarios') is not null then
    insert into gm_cenarios (id, workspace_id, nome, hipotese, autor, status, ue, criado_em)
    select s.id, s.workspace_id, s.nome, 'Trazido do Unit Economics.', s.criado_por, case when s.status = 'arquivado' then 'arquivado' else 'rascunho' end, s.dados, s.criado_em
      from simulador_cenarios s where not exists (select 1 from gm_cenarios g where g.id = s.id);
  end if;
end $$;

-- as fotos do Unit Economics passam a apontar para o cenário do Growth Model
do $$ begin
  if to_regclass('public.simulador_snapshots') is not null then
    alter table simulador_snapshots drop constraint if exists simulador_snapshots_cenario_id_fkey;
    if not exists (select 1 from pg_constraint where conname = 'simulador_snapshots_gm_cenario_fk') then
      delete from simulador_snapshots s where not exists (select 1 from gm_cenarios g where g.id = s.cenario_id);
      alter table simulador_snapshots add constraint simulador_snapshots_gm_cenario_fk foreign key (cenario_id) references gm_cenarios(id) on delete cascade;
    end if;
  end if;
end $$;

-- auditoria
do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['gm_alavancas', 'gm_cenarios'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
end $$;
