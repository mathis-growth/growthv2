-- v0.177 — Diagnóstico 360° (G3): a reunião do diagnóstico, preenchida pela equipe.
-- Plano: docs/diagnostico-360-plano.md, seção 8 (G3) e seção D (D6 e D7, adaptados).
-- 1. diagnosticos: um por resposta do formulário. Guarda os números que o cliente usa para decidir, a arquitetura (North Star,
--    primeiro valor, guardrails, receita de novos e da base), as anotações, a leitura dos documentos feita no Diagnóstico Growth
--    (completude, cobertura, o que tem e o que falta, mensagem) e a situação (rascunho ou validado).
--    A leitura fica aqui e não mexe no modelo de Growth da empresa (gm_modelos).
-- 2. diagnostico_metricas: por métrica, o que o cliente declarou e o detalhe da reunião, conforme a natureza (valor ou taxa).
-- 3. Proteção por empresa: lê quem lê Pesquisas (gro, adm, mkt); altera quem edita Growth (gro). A empresa do diagnóstico é a da
--    resposta; a da métrica é a do diagnóstico.
-- Rode depois de 20261129110000_diagnostico_g2_arquivos.sql. Idempotente.

create table if not exists diagnosticos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  resposta_id uuid not null unique references pesquisa_respostas(id) on delete cascade,
  pesquisa_id uuid references pesquisas(id) on delete set null,
  envio_id uuid references pesquisa_envios(id) on delete set null,
  pessoa_id uuid references pessoas(id) on delete set null,
  status text not null default 'rascunho' check (status in ('rascunho', 'validado')),
  decide text[] not null default '{}',
  arquitetura jsonb not null default '{}'::jsonb check (jsonb_typeof(arquitetura) = 'object'),
  notas text check (length(notas) <= 20000),
  leitura jsonb check (leitura is null or (jsonb_typeof(leitura) = 'object' and length(leitura::text) <= 200000)),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  validado_em timestamptz,
  validado_por uuid
);
create index if not exists diagnosticos_pessoa on diagnosticos (workspace_id, pessoa_id);

create table if not exists diagnostico_metricas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  diagnostico_id uuid not null references diagnosticos(id) on delete cascade,
  codigo text not null check (length(codigo) between 1 and 60),
  declarado jsonb,
  detalhe jsonb not null default '{}'::jsonb check (jsonb_typeof(detalhe) = 'object' and length(detalhe::text) <= 30000),
  decide boolean not null default false,
  observacao text check (length(observacao) <= 5000),
  atualizado_em timestamptz not null default now(),
  unique (diagnostico_id, codigo)
);

-- a empresa vem da resposta (diagnóstico) e do diagnóstico (métrica); pesquisa, envio e pessoa saem da própria resposta
create or replace function public.diagnosticos_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare r pesquisa_respostas;
begin
  select * into r from pesquisa_respostas where id = new.resposta_id;
  if not found then raise exception 'Resposta não encontrada.'; end if;
  if new.workspace_id is distinct from r.workspace_id then raise exception 'O diagnóstico precisa ser da mesma empresa da resposta.'; end if;
  new.pesquisa_id := r.pesquisa_id; new.envio_id := r.envio_id; new.pessoa_id := r.pessoa_id; new.atualizado_em := now();
  if new.status = 'validado' and (tg_op = 'INSERT' or old.status <> 'validado') then new.validado_em := now(); end if;
  if new.status = 'rascunho' then new.validado_em := null; new.validado_por := null; end if;
  return new;
end $$;
drop trigger if exists diagnosticos_coerente_t on diagnosticos;
create trigger diagnosticos_coerente_t before insert or update on diagnosticos for each row execute function diagnosticos_coerente();

create or replace function public.diagnostico_metricas_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from diagnosticos where id = new.diagnostico_id;
  if v_ws is null then raise exception 'Diagnóstico não encontrado.'; end if;
  if new.workspace_id is distinct from v_ws then raise exception 'A métrica precisa ser da mesma empresa do diagnóstico.'; end if;
  new.atualizado_em := now();
  return new;
end $$;
drop trigger if exists diagnostico_metricas_coerente_t on diagnostico_metricas;
create trigger diagnostico_metricas_coerente_t before insert or update on diagnostico_metricas for each row execute function diagnostico_metricas_coerente();

do $$ declare t text; begin
  foreach t in array array['diagnosticos', 'diagnostico_metricas'] loop
    execute format('alter table %1$s enable row level security', t);
    execute format('drop policy if exists %1$s_acesso on %1$s', t);
    execute format('drop policy if exists perm_ler on %1$s', t);
    execute format('drop policy if exists perm_inserir on %1$s', t);
    execute format('drop policy if exists perm_alterar on %1$s', t);
    execute format('drop policy if exists perm_excluir on %1$s', t);
    execute format('create policy %1$s_acesso on %1$s for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t);
    execute format('create policy perm_ler on %1$s as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''gro'',''adm'',''mkt'']))', t);
    execute format('create policy perm_inserir on %1$s as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_alterar on %1$s as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('create policy perm_excluir on %1$s as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''gro'']))', t);
    execute format('grant select, insert, update, delete on %1$s to authenticated', t);
  end loop;
end $$;

-- Para desfazer: drop table diagnostico_metricas; drop table diagnosticos;
-- drop function diagnostico_metricas_coerente(); drop function diagnosticos_coerente().
