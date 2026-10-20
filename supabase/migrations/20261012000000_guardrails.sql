-- v0.100 — Growth Now, fase D: guardrails projetados e monitorados, alertas, acompanhamento contínuo
-- 1. guardrail_definicoes: limite mínimo ou máximo de uma métrica (margem, lucro, ROAS, CAC mídia, CPL, mídia, receita, vendas, leads, conversão, ticket),
--    severidade (atenção ou crítico), escopo, produto, janela de leitura, frequência, ação sugerida e se segue no acompanhamento contínuo.
-- 2. exp_guardrails: quais guardrails cada teste monitora. Quando um card entra em "Em teste", liga sozinho os guardrails ativos (do produto do cenário ou gerais).
-- 3. guardrail_observacoes (antes/durante/depois/contínuo, por dia) e guardrail_alertas (um aberto por teste e guardrail; reconhecer e resolver com nota).
--    Nada é pausado automaticamente: o alerta só sugere a ação.
-- 4. Telas Growth → Guardrails e Growth → Resultados e aprendizados no catálogo de acesso.
-- Rode DEPOIS de 20261011900000_decisao_kanban.sql. Idempotente.

create table if not exists guardrail_definicoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  metrica text not null check (metrica in ('margem', 'lucro', 'roas', 'cac_midia', 'cpl', 'midia', 'receita', 'vendas', 'leads', 'conv', 'ticket')),
  operador text not null check (operador in ('min', 'max')),
  limite numeric not null,
  severidade text not null default 'atencao' check (severidade in ('atencao', 'critico')),
  escopo text not null default 'negocio' check (escopo in ('negocio', 'recorte')),
  produto_id uuid references produtos(id) on delete set null,
  janela_dias int not null default 14 check (janela_dias between 1 and 180),
  frequencia text not null default 'semanal' check (frequencia in ('diaria', 'semanal')),
  acao_sugerida text,
  descricao text,
  continuo boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists exp_guardrails (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid not null references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  ativado_em timestamptz not null default now(),
  unique (experimento_id, guardrail_id)
);
create table if not exists guardrail_observacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  data date not null,
  periodo text not null check (periodo in ('antes', 'durante', 'depois', 'continuo')),
  janela_ini date, janela_fim date,
  valor numeric,
  limite numeric not null,
  situacao text not null check (situacao in ('ok', 'atencao', 'violado', 'sem_dado')),
  criado_em timestamptz not null default now()
);
create unique index if not exists guardrail_observacoes_uq on guardrail_observacoes (coalesce(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id, data, periodo);
create table if not exists guardrail_alertas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  experimento_id uuid references growth_experimentos(id) on delete cascade,
  guardrail_id uuid not null references guardrail_definicoes(id) on delete cascade,
  data date not null,
  valor numeric,
  limite numeric not null,
  severidade text not null check (severidade in ('atencao', 'critico')),
  mensagem text not null,
  acao_sugerida text,
  status text not null default 'aberto' check (status in ('aberto', 'reconhecido', 'resolvido')),
  responsavel text,
  nota text,
  criado_em timestamptz not null default now(),
  resolvido_em timestamptz
);
create unique index if not exists guardrail_alertas_aberto_uq on guardrail_alertas (coalesce(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id) where status <> 'resolvido';

do $r$
declare t text;
begin
  foreach t in array array['guardrail_definicoes', 'exp_guardrails', 'guardrail_observacoes', 'guardrail_alertas'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_acesso', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on %I', t);
    execute format('create policy perm_ler on %I as restrictive for select using (perm(workspace_id, ''ler'', array[''gro'',''adm'',''mkt'']))', t);
    execute format('drop policy if exists perm_escrever on %I', t);
    execute format('create policy perm_escrever on %I as restrictive for all using (perm(workspace_id, ''editar'', array[''gro'',''mkt''])) with check (perm(workspace_id, ''editar'', array[''gro'',''mkt'']))', t);
  end loop;
end
$r$;

-- teste que entra em "Em teste" passa a monitorar os guardrails ativos (gerais ou do produto do cenário de origem)
create or replace function public.exp_liga_guardrails() returns trigger language plpgsql security definer set search_path = public as $$
declare prod uuid;
begin
  if new.etapa = 'rodando' and (tg_op = 'INSERT' or old.etapa is distinct from 'rodando')
     and not exists (select 1 from exp_guardrails where experimento_id = new.id) then
    if new.cenario_id is not null then select nullif(escopo ->> 'prod', '')::uuid into prod from gm_cenarios where id = new.cenario_id; end if;
    insert into exp_guardrails (workspace_id, experimento_id, guardrail_id)
    select new.workspace_id, new.id, g.id from guardrail_definicoes g
     where g.workspace_id = new.workspace_id and g.ativo and (g.produto_id is null or g.produto_id = prod)
    on conflict (experimento_id, guardrail_id) do nothing;
  end if;
  return null;
end $$;
drop trigger if exists exp_liga_guardrails_t on growth_experimentos;
create trigger exp_liga_guardrails_t after insert or update of etapa on growth_experimentos for each row execute function exp_liga_guardrails();

do $$
declare t text;
begin
  if to_regprocedure('public.auditar()') is not null then
    foreach t in array array['guardrail_definicoes', 'guardrail_alertas'] loop
      execute format('drop trigger if exists auditoria_t on public.%I', t);
      execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
    end loop;
  end if;
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem) values
      ('gro-guard', 'gro', 'Guardrails', 'Growth', coalesce((select max(ordem) from acesso_telas where grupo = 'Growth'), 60) + 1),
      ('gro-result', 'gro', 'Resultados e aprendizados', 'Growth', coalesce((select max(ordem) from acesso_telas where grupo = 'Growth'), 60) + 2)
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
    update pacotes_acesso set telas = telas || array['gro-guard', 'gro-result'] where telas @> array['gro-ciclo'] and not telas @> array['gro-guard'];
  end if;
end $$;
