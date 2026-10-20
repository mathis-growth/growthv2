-- v0.48: Modelo de funis (simulador de Growth Model por mês, baseline x cenário).
-- Os números do modelo são calculados no front-end por regra fixa (sem IA); aqui ficam só as entradas.
create table if not exists gm_config (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  inicio date not null,
  meses int not null default 12 check (meses between 1 and 36)
);
create table if not exists gm_funis (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  fase text not null default 'aquisicao' check (fase in ('aquisicao','retencao')),
  produto_id uuid references produtos(id) on delete set null,
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists gm_etapas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  funil_id uuid not null references gm_funis(id) on delete cascade,
  ordem int not null default 0,
  nome text not null,
  unidade text not null default 'numero' check (unidade in ('brl','numero','pct')),
  op text not null default 'input' check (op in ('input','mult','div','div_mil','soma','coorte')),
  ref_id uuid references gm_etapas(id) on delete set null,
  ref2_id uuid references gm_etapas(id) on delete set null,
  refs uuid[] not null default '{}',
  curva numeric[] not null default '{}',
  carrega boolean not null default true,
  papel text check (papel in ('investimento','clientes_novos','renovados','receita')),
  chave_auto text check (chave_auto in ('investimento','leads','vendas','receita')),
  criado_em timestamptz not null default now()
);
create table if not exists gm_valores (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  etapa_id uuid not null references gm_etapas(id) on delete cascade,
  mes date not null,
  cenario text not null check (cenario in ('base','sim')),
  valor numeric not null,
  unique (etapa_id, mes, cenario)
);
create index if not exists gm_etapas_funil on gm_etapas(funil_id, ordem);
create index if not exists gm_valores_etapa on gm_valores(etapa_id);
do $$ declare t text; begin
  foreach t in array array['gm_config','gm_funis','gm_etapas','gm_valores'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t||'_acesso', t);
    execute format('create policy perm_ler on %I as restrictive for select using (perm(workspace_id, ''ler'', ''{gro,adm,mkt}''::text[]))', t);
    execute format('create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, ''editar'', ''{gro}''::text[]))', t);
    execute format('create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, ''editar'', ''{gro}''::text[])) with check (perm(workspace_id, ''editar'', ''{gro}''::text[]))', t);
    execute format('create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, ''editar'', ''{gro}''::text[]))', t);
  end loop;
end $$;
