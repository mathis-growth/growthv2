-- v0.209 — Financeiro simplificado: DRE simplificado sem contas a pagar e a receber.
-- 1. Custos com grupo: marketing (entra no CAC e no Resultado de marketing) ou operacional (outros custos da operação).
-- 2. Parceiros (coprodutor, afiliado, vendedor) com uma comissão geral e, se for diferente, uma por produto.
-- 3. dre_simplificado: mês a mês, faturamento − taxa − impostos − comissões = receita líquida − mídia − marketing =
--    Resultado de marketing − outros custos = Resultado da operação.
-- 4. Tela "Financeiro simplificado" (adm-financeiro): no Go-to-Market é o único financeiro; no Growths completo aparece junto do financeiro completo.
-- Depende de: RODAR_v0.205 (custos de marketing) e RODAR_v0.206 (v_vendas_todas). Pode rodar de novo sem erro.

alter table public.mkt_custos_itens add column if not exists grupo text not null default 'marketing';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'mkt_custos_itens_grupo_check') then
    alter table public.mkt_custos_itens add constraint mkt_custos_itens_grupo_check check (grupo in ('marketing', 'operacional'));
  end if; end $$;
comment on column public.mkt_custos_itens.grupo is 'v0.209: marketing (CAC e Resultado de marketing) ou operacional (outros custos, só no Financeiro simplificado).';

-- parceiros (coprodutor, afiliado, vendedor) e as comissões deles: uma geral (todos os produtos) e, se for diferente, uma por produto.
-- Na venda de um produto vale a % daquele produto; se não tiver, a geral.
drop table if exists public.parceiros_comissao; -- desenho anterior desta mesma versão, nunca aplicado em produção
create table if not exists public.parceiros (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 120),
  papel text not null default 'coprodutor' check (papel in ('coprodutor', 'afiliado', 'vendedor', 'outro')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists public.parceiro_comissoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  parceiro_id uuid not null references parceiros(id) on delete cascade,
  produto_id uuid references produtos(id) on delete cascade,
  percentual numeric(5,2) not null check (percentual > 0 and percentual <= 100),
  base text not null default 'bruto' check (base in ('bruto', 'liquido')),
  desde date not null check (desde = date_trunc('month', desde)::date),
  ate date check (ate is null or (ate = date_trunc('month', ate)::date and ate >= desde)),
  criado_em timestamptz not null default now()
);
comment on table public.parceiro_comissoes is 'v0.209: % do parceiro. produto_id vazio = geral (todos os produtos); com produto = vale para aquele produto no lugar da geral. Base bruto = valor da venda; líquido = valor − taxa da plataforma.';
create index if not exists parceiro_comissoes_parc on public.parceiro_comissoes (parceiro_id);
do $$ declare t text; begin
  foreach t in array array['parceiros', 'parceiro_comissoes'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_ver', t);
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna())', t || '_ver', t);
    execute format('drop policy if exists %I on public.%I', t || '_gravar', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (pode_editar(workspace_id, ''{adm,vendas}''::text[]))', t || '_gravar', t);
    execute format('drop policy if exists %I on public.%I', t || '_alterar', t);
    execute format('create policy %I on public.%I for update to authenticated using (pode_editar(workspace_id, ''{adm,vendas}''::text[])) with check (pode_editar(workspace_id, ''{adm,vendas}''::text[]))', t || '_alterar', t);
    execute format('drop policy if exists %I on public.%I', t || '_excluir', t);
    execute format('create policy %I on public.%I for delete to authenticated using (pode_editar(workspace_id, ''{adm,vendas}''::text[]))', t || '_excluir', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop; end $$;

-- custos do mês por grupo (fixos e variáveis de marketing ficam onde estavam, para o Resultado de marketing não mudar)
create or replace function public.mkt_custos_mes(p_ws uuid, p_mes date) returns jsonb
language sql stable security definer set search_path = public as $$
  with it as (select * from mkt_custos_itens where workspace_id = p_ws and desde <= p_mes and (ate is null or ate >= p_mes)),
       vl as (select it.grupo, v.valor from it join mkt_custos_valores v on v.item_id = it.id and v.mes = p_mes where it.tipo = 'variavel')
  select jsonb_build_object('mes', p_mes,
    'fixos', coalesce((select sum(valor) from it where tipo = 'fixo' and grupo = 'marketing'), 0),
    'variaveis', coalesce((select sum(valor) from vl where grupo = 'marketing'), 0),
    'fixos_op', coalesce((select sum(valor) from it where tipo = 'fixo' and grupo = 'operacional'), 0),
    'variaveis_op', coalesce((select sum(valor) from vl where grupo = 'operacional'), 0),
    'n_variaveis', (select count(*) from it where tipo = 'variavel'),
    'faltam', (select count(*) from it where tipo = 'variavel' and not exists (select 1 from mkt_custos_valores v where v.item_id = it.id and v.mes = p_mes)),
    'fechado_em', (select fechado_em from mkt_custos_meses where workspace_id = p_ws and mes = p_mes))
$$;
revoke all on function public.mkt_custos_mes(uuid, date) from public, anon, authenticated;

-- DRE simplificado: p_meses meses terminando no mês de p_ate
create or replace function public.dre_simplificado(p_ws uuid, p_ate date, p_meses int default 6) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m date; fim date; i int; L jsonb := '[]'::jsonb; dm jsonb; fat numeric; taxa numeric; imp numeric; com_p numeric; com_e numeric; mid numeric; reemb numeric; ntaxa int; nv int;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  p_meses := greatest(1, least(coalesce(p_meses, 6), 24));
  for i in reverse p_meses - 1 .. 0 loop
    m := (date_trunc('month', p_ate) - make_interval(months => i))::date; fim := (m + interval '1 month - 1 day')::date;
    select coalesce(sum(valor) filter (where status = 'aprovada'), 0), coalesce(sum(valor) filter (where status = 'reembolsada'), 0) into fat, reemb
      from v_vendas_todas where workspace_id = p_ws and dia between m and fim;
    select coalesce(sum(taxa_plataforma), 0), coalesce(sum(impostos), 0), count(*) filter (where taxa_plataforma is null), count(*) into taxa, imp, ntaxa, nv
      from vendas where workspace_id = p_ws and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between m and fim;
    select coalesce(sum(round(case when pc.base = 'liquido' then v.valor_bruto - coalesce(v.taxa_plataforma, 0) else v.valor_bruto end * pc.percentual / 100, 2)), 0) into com_p
      from vendas v join parceiros pa on pa.workspace_id = v.workspace_id and pa.ativo
      join lateral (select c.* from parceiro_comissoes c where c.parceiro_id = pa.id and c.desde <= m and (c.ate is null or c.ate >= m)
                    and (c.produto_id = v.produto_id or c.produto_id is null) order by (c.produto_id is null) limit 1) pc on true
      where v.workspace_id = p_ws and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between m and fim;
    select coalesce(sum(c.valor), 0) into com_e from comissoes c where c.workspace_id = p_ws and c.status <> 'cancelada' and c.competencia between m and fim;
    select coalesce(sum(custo), 0) into mid from metricas_anuncio_dia where workspace_id = p_ws and data between m and fim;
    dm := mkt_custos_mes(p_ws, m);
    L := L || jsonb_build_object('mes', m, 'faturamento', fat, 'reembolsos', reemb, 'taxa', taxa, 'vendas_sem_taxa', ntaxa, 'vendas', nv, 'impostos', imp,
      'comissoes_parceiros', com_p, 'comissoes_equipe', com_e, 'midia', mid,
      'custos_mkt', (dm->>'fixos')::numeric + (dm->>'variaveis')::numeric, 'custos_op', (dm->>'fixos_op')::numeric + (dm->>'variaveis_op')::numeric,
      'faltam', (dm->>'faltam')::int, 'fechado_em', dm->'fechado_em');
  end loop;
  return jsonb_build_object('meses', L, 'custos_ativo', coalesce((select ativo from mkt_custos_config where workspace_id = p_ws), false));
end $$;
revoke all on function public.dre_simplificado(uuid, date, int) from public, anon;
grant execute on function public.dre_simplificado(uuid, date, int) to authenticated;

-- tela e pacote
insert into acesso_telas (tela, modulo, nome, grupo, ordem)
values ('adm-financeiro', 'adm', 'Financeiro simplificado', 'Administrativo', coalesce((select ordem from acesso_telas where tela = 'adm-empresa'), 0) + 1)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
-- no Go-to-Market o Financeiro simplificado é o único financeiro; no Growths completo (sem pacote) ele aparece junto do financeiro completo
update pacotes_acesso set telas = telas || array['adm-financeiro'] where nome = 'Go-to-Market' and not ('adm-financeiro' = any (telas));
delete from pacotes_acesso p where p.nome = 'Financeiro simplificado' and not exists (select 1 from workspaces w where w.pacote_id = p.id); -- desenho anterior desta versão
notify pgrst, 'reload schema';
