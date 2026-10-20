-- v0.99 — Growth Now, fase C: ICE no cenário, aprovação com documento de decisão, Kanban em 7 colunas, ideia ligada ao cenário, experimento ou planejamento
-- 1. gm_decisoes: documento de decisão imutável (contexto, baseline, inputs, projeções, riscos, ICE, responsável, próximos passos).
-- 2. gm_aprovar(cenário, responsável, próximos passos, documento): só administrador; exige hipótese e ICE; congela o cenário e grava o documento.
-- 3. growth_experimentos: colunas novas do Kanban (avaliacao, preparacao, arquivado), vínculo único com o cenário (sem cards duplicados),
--    decisão, tipo (experimento ou planejamento), projeto, público, intervenção, instrumentação, custo previsto, métrica-alvo e justificativa do ICE.
-- 4. gm_ideia_do_cenario(cenário): cria ou devolve a ideia do cenário no Kanban. exp_para_planejamento(experimento): cria o projeto da iniciativa.
-- Rode DEPOIS de 20261011800000_growth_model_cenarios.sql. Idempotente.

create table if not exists gm_decisoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  cenario_id uuid not null references gm_cenarios(id) on delete restrict,
  versao int not null default 1,
  titulo text not null,
  documento jsonb not null check (jsonb_typeof(documento) = 'object'),
  responsavel text,
  proximos_passos text,
  aprovado_por uuid default auth.uid(),
  aprovado_por_email text,
  criado_em timestamptz not null default now()
);
create index if not exists gm_decisoes_cen on gm_decisoes (cenario_id);
alter table gm_decisoes enable row level security;
drop policy if exists gm_decisoes_acesso on gm_decisoes;
create policy gm_decisoes_acesso on gm_decisoes for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on gm_decisoes;
create policy perm_ler on gm_decisoes as restrictive for select using (perm(workspace_id, 'ler', '{gro,adm,mkt}'::text[]));
create or replace function public.gm_decisoes_imutavel() returns trigger language plpgsql as $$
begin raise exception 'Documento de decisão não muda: aprove uma nova versão do cenário'; end $$;
drop trigger if exists gm_decisoes_imutavel_t on gm_decisoes;
create trigger gm_decisoes_imutavel_t before update or delete on gm_decisoes for each row execute function gm_decisoes_imutavel();

create or replace function public.gm_aprovar(p_cenario uuid, p_responsavel text, p_proximos text, p_documento jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare c gm_cenarios; d uuid; doc jsonb; em text;
begin
  select * into c from gm_cenarios where id = p_cenario for update;
  if not found then raise exception 'Cenário não encontrado'; end if;
  if not pertence_ao_workspace(c.workspace_id) or not eh_admin(c.workspace_id) then raise exception 'Só um administrador aprova cenários'; end if;
  if c.status <> 'rascunho' then raise exception 'Só cenário em rascunho pode ser aprovado (este está %)', c.status; end if;
  if coalesce(trim(c.hipotese), '') = '' then raise exception 'Escreva a hipótese do cenário antes de aprovar'; end if;
  if c.impacto is null or c.confianca is null or c.facilidade is null then raise exception 'Preencha o ICE (impacto, confiança e facilidade) antes de aprovar'; end if;
  if coalesce(trim(p_responsavel), '') = '' then raise exception 'Diga quem é o responsável'; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p_documento -> 'guardrails', '[]'::jsonb)) g where g ->> 'severidade' = 'critico' and g ->> 'situacao' = 'violado')
     and coalesce(trim(p_documento ->> 'justificativa_risco'), '') = '' then
    raise exception 'Há guardrail crítico violado na projeção: registre a justificativa do risco para aprovar'; end if;
  select email into em from auth.users where id = auth.uid();
  doc := coalesce(p_documento, '{}'::jsonb) || jsonb_build_object(
    'cenario', jsonb_build_object('id', c.id, 'nome', c.nome, 'versao', c.versao, 'hipotese', c.hipotese, 'escopo', c.escopo, 'financeiro', c.financeiro),
    'ice', jsonb_build_object('impacto', c.impacto, 'confianca', c.confianca, 'facilidade', c.facilidade, 'score', round((c.impacto + c.confianca + c.facilidade) / 3.0, 1), 'justificativa', c.ice_justificativa),
    'inputs_gravados', coalesce((select jsonb_agg(jsonb_build_object('loop', a.loop_chave, 'produto_id', a.produto_id, 'alavanca', a.alavanca, 'mes', a.mes, 'valor', a.valor) order by a.loop_chave, a.alavanca, a.mes)
                                 from gm_alavancas a where a.cenario = c.id::text), '[]'::jsonb),
    'responsavel', p_responsavel, 'proximos_passos', p_proximos, 'aprovado_em', now());
  update gm_cenarios set status = 'aprovado', aprovado_em = now(), aprovado_por = auth.uid() where id = c.id;
  insert into gm_decisoes (workspace_id, cenario_id, versao, titulo, documento, responsavel, proximos_passos, aprovado_por_email)
  values (c.workspace_id, c.id, c.versao, 'Decisão: ' || c.nome, doc, p_responsavel, p_proximos, em) returning id into d;
  return d;
end $$;
revoke execute on function public.gm_aprovar(uuid, text, text, jsonb) from public, anon;
grant execute on function public.gm_aprovar(uuid, text, text, jsonb) to authenticated, service_role;

-- Kanban
alter table growth_experimentos drop constraint if exists growth_experimentos_etapa_check;
alter table growth_experimentos add constraint growth_experimentos_etapa_check check (etapa in ('ideia', 'avaliacao', 'priorizado', 'preparacao', 'rodando', 'analise', 'concluido', 'arquivado'));
alter table growth_experimentos add column if not exists cenario_id uuid references gm_cenarios(id) on delete set null;
alter table growth_experimentos add column if not exists decisao_id uuid references gm_decisoes(id) on delete set null;
alter table growth_experimentos add column if not exists tipo text not null default 'experimento';
alter table growth_experimentos add column if not exists projeto_id uuid references projetos(id) on delete set null;
alter table growth_experimentos add column if not exists publico text;
alter table growth_experimentos add column if not exists intervencao text;
alter table growth_experimentos add column if not exists instrumentacao text;
alter table growth_experimentos add column if not exists custo_previsto numeric(12,2) check (custo_previsto is null or custo_previsto >= 0);
alter table growth_experimentos add column if not exists metrica_alvo text;
alter table growth_experimentos add column if not exists ice_justificativa text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'growth_experimentos_tipo_check') then
    alter table growth_experimentos add constraint growth_experimentos_tipo_check check (tipo in ('experimento', 'planejamento'));
  end if;
end $$;
create unique index if not exists growth_experimentos_cenario_uq on growth_experimentos (cenario_id) where cenario_id is not null;

create or replace function public.gm_ideia_do_cenario(p_cenario uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare c gm_cenarios; e uuid; d uuid;
begin
  select * into c from gm_cenarios where id = p_cenario;
  if not found then raise exception 'Cenário não encontrado'; end if;
  if not pertence_ao_workspace(c.workspace_id) or not perm(c.workspace_id, 'editar', '{gro}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  select id into e from growth_experimentos where cenario_id = c.id;
  if e is not null then return e; end if;
  select id into d from gm_decisoes where cenario_id = c.id order by criado_em desc limit 1;
  insert into growth_experimentos (workspace_id, titulo, hipotese, etapa, impacto, confianca, facilidade, ice_justificativa, cenario_id, decisao_id, insight)
  values (c.workspace_id, left(c.nome, 200), c.hipotese, case when c.status = 'aprovado' then 'priorizado' else 'ideia' end, c.impacto, c.confianca, c.facilidade, c.ice_justificativa, c.id, d,
          'Cenário do Growth Model: ' || c.nome || ' (v' || c.versao || ')')
  returning id into e;
  return e;
end $$;
revoke execute on function public.gm_ideia_do_cenario(uuid) from public, anon;
grant execute on function public.gm_ideia_do_cenario(uuid) to authenticated, service_role;

create or replace function public.exp_para_planejamento(p_exp uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare e growth_experimentos; p uuid;
begin
  select * into e from growth_experimentos where id = p_exp for update;
  if not found then raise exception 'Ideia não encontrada'; end if;
  if not pertence_ao_workspace(e.workspace_id) or not perm(e.workspace_id, 'editar', '{gro,prj}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if e.projeto_id is not null then return e.projeto_id; end if;
  insert into projetos (workspace_id, nome, descricao, data_inicio, data_fim_prevista)
  values (e.workspace_id, 'Iniciativa: ' || left(e.titulo, 180), coalesce(e.hipotese, '') || case when e.criterio_sucesso is not null then E'\nCritério de sucesso: ' || e.criterio_sucesso else '' end,
          coalesce(e.inicio, (now() at time zone 'America/Sao_Paulo')::date), e.fim_previsto)
  returning id into p;
  update growth_experimentos set projeto_id = p, tipo = 'planejamento', etapa = case when etapa in ('ideia', 'avaliacao', 'priorizado') then 'preparacao' else etapa end where id = e.id;
  return p;
end $$;
revoke execute on function public.exp_para_planejamento(uuid) from public, anon;
grant execute on function public.exp_para_planejamento(uuid) to authenticated, service_role;

do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['growth_experimentos', 'gm_decisoes'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
end $$;
