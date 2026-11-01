-- v0.209 — Financeiro simplificado: DRE simplificado sem contas a pagar e a receber.
-- 1. Custos com grupo: marketing (entra no CAC e no Resultado de marketing) ou operacional (outros custos da operação).
-- 2. Comissões de parceiros: coprodutor, afiliado, vendedor ou outro, com % sobre as vendas (de um produto ou de todos).
-- 3. dre_simplificado: mês a mês, faturamento − taxa − impostos − comissões = receita líquida − mídia − marketing =
--    Resultado de marketing − outros custos = Resultado da operação.
-- 4. Tela "Financeiro simplificado" (adm-financeiro) e o pacote "Financeiro simplificado" (Go-to-Market + esta tela).
-- Depende de: RODAR_v0.205 (custos de marketing) e RODAR_v0.206 (v_vendas_todas). Pode rodar de novo sem erro.

alter table public.mkt_custos_itens add column if not exists grupo text not null default 'marketing';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'mkt_custos_itens_grupo_check') then
    alter table public.mkt_custos_itens add constraint mkt_custos_itens_grupo_check check (grupo in ('marketing', 'operacional'));
  end if; end $$;
comment on column public.mkt_custos_itens.grupo is 'v0.209: marketing (CAC e Resultado de marketing) ou operacional (outros custos, só no Financeiro simplificado).';

create table if not exists public.parceiros_comissao (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 120),
  papel text not null default 'coprodutor' check (papel in ('coprodutor', 'afiliado', 'vendedor', 'outro')),
  percentual numeric(5,2) not null check (percentual > 0 and percentual <= 100),
  base text not null default 'bruto' check (base in ('bruto', 'liquido')),
  produto_id uuid references produtos(id) on delete set null,
  desde date not null check (desde = date_trunc('month', desde)::date),
  ate date check (ate is null or (ate = date_trunc('month', ate)::date and ate >= desde)),
  criado_em timestamptz not null default now()
);
comment on table public.parceiros_comissao is 'v0.209: quem ganha % das vendas (coprodutor, afiliado, vendedor). Base bruto = valor da venda; líquido = valor − taxa da plataforma. Sem produto = todas as vendas.';
alter table public.parceiros_comissao enable row level security;
drop policy if exists parceiros_comissao_ver on public.parceiros_comissao;
create policy parceiros_comissao_ver on public.parceiros_comissao for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
drop policy if exists parceiros_comissao_gravar on public.parceiros_comissao;
create policy parceiros_comissao_gravar on public.parceiros_comissao for insert to authenticated with check (pode_editar(workspace_id, '{adm,vendas}'::text[]));
drop policy if exists parceiros_comissao_alterar on public.parceiros_comissao;
create policy parceiros_comissao_alterar on public.parceiros_comissao for update to authenticated using (pode_editar(workspace_id, '{adm,vendas}'::text[])) with check (pode_editar(workspace_id, '{adm,vendas}'::text[]));
drop policy if exists parceiros_comissao_excluir on public.parceiros_comissao;
create policy parceiros_comissao_excluir on public.parceiros_comissao for delete to authenticated using (pode_editar(workspace_id, '{adm,vendas}'::text[]));
revoke all on public.parceiros_comissao from anon;
grant select, insert, update, delete on public.parceiros_comissao to authenticated;

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
      from parceiros_comissao pc join vendas v on v.workspace_id = pc.workspace_id and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between m and fim
        and (pc.produto_id is null or v.produto_id = pc.produto_id)
      where pc.workspace_id = p_ws and pc.desde <= m and (pc.ate is null or pc.ate >= m);
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
insert into pacotes_acesso (nome, descricao, telas, ativo)
select 'Financeiro simplificado', 'O Go-to-Market mais o Financeiro simplificado: DRE do mês com taxas, comissões, mídia, custos de marketing e outros custos operacionais, sem contas a pagar e a receber, bancos e lançamentos.',
  (select telas from pacotes_acesso where nome = 'Go-to-Market') || array['adm-financeiro'], true
where not exists (select 1 from pacotes_acesso where nome = 'Financeiro simplificado') and exists (select 1 from pacotes_acesso where nome = 'Go-to-Market');
notify pgrst, 'reload schema';
