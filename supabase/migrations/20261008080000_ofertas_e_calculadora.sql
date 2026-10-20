-- v0.65: ofertas por produto, ofertas e preços por campanha, cenários da calculadora de campanha e meta de custo por lead.
create table ofertas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  produto_id uuid not null references produtos(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  papel text not null default 'principal' check (papel in ('principal', 'upsell', 'order_bump', 'cross_sell', 'downsell')),
  preco numeric(12,2) not null check (preco >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create index on ofertas (workspace_id, produto_id);

create table campanha_ofertas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null references campanhas(id) on delete cascade,
  produto_id uuid not null references produtos(id) on delete restrict,
  oferta_id uuid references ofertas(id) on delete set null,
  nome text not null check (char_length(nome) between 1 and 120),
  papel text not null default 'principal' check (papel in ('principal', 'upsell', 'order_bump', 'cross_sell', 'downsell')),
  preco numeric(12,2) not null check (preco >= 0),
  ordem int not null default 0,
  criado_em timestamptz not null default now()
);
create index on campanha_ofertas (workspace_id, campanha_id);

create table campanha_calculos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid references campanhas(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 120),
  premissas jsonb not null default '{}'::jsonb check (jsonb_typeof(premissas) = 'object'),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index on campanha_calculos (workspace_id, campanha_id);

alter table campanhas add column meta_cpl numeric(12,2) check (meta_cpl is null or meta_cpl >= 0);
alter table campanha_canais add column meta_cpl numeric(12,2) check (meta_cpl is null or meta_cpl >= 0);

do $r$
declare t text;
begin
  foreach t in array array['ofertas', 'campanha_ofertas', 'campanha_calculos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('create policy perm_ler on %I as restrictive for select using (perm(workspace_id, ''ler'', array[''mkt'',''adm'',''gro'',''vendas'',''cad'']))', t);
    execute format('create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
    execute format('create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad''])) with check (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
    execute format('create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, ''editar'', array[''mkt'',''gro'',''cad'']))', t);
  end loop;
end
$r$;

-- Registro por campanha: preço da oferta, vendas e receita de cada produto na campanha (vendas aprovadas e contratos ativos/encerrados).
create or replace function campanha_ofertas_resultado(p_ws uuid, p_campanha uuid)
returns jsonb language plpgsql stable set search_path = public as $f$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'produto_id', o.produto_id, 'produto', pr.nome, 'nome', o.nome, 'papel', o.papel, 'preco', o.preco,
      'vendas', coalesce(v.n, 0) + coalesce(c.n, 0), 'receita', coalesce(v.rec, 0) + coalesce(c.rec, 0)) order by o.ordem, o.criado_em), '[]'::jsonb) into r
  from campanha_ofertas o join produtos pr on pr.id = o.produto_id
  left join lateral (select count(*) n, sum(x.valor_bruto) rec from vendas x where x.workspace_id = p_ws and x.campanha_id = p_campanha and x.produto_id = o.produto_id and x.status = 'aprovada') v on true
  left join lateral (select count(distinct k.id) n, sum(ci.quantidade * ci.valor) rec from contratos k join contrato_itens ci on ci.contrato_id = k.id
      where k.workspace_id = p_ws and k.campanha_id = p_campanha and ci.produto_id = o.produto_id and k.status in ('ativo', 'encerrado')) c on true
  where o.workspace_id = p_ws and o.campanha_id = p_campanha;
  return r;
end $f$;
