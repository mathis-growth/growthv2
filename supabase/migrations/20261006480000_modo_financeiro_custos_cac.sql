-- v0.29 (parte 1, JÁ APLICADA) — custos informados só para o CAC, com rateio, e módulo financeiro por workspace (coluna).
alter table workspaces add column if not exists modo_financeiro text not null default 'completo' check (modo_financeiro in ('completo', 'simplificado'));

-- Custos que o cliente informa só para o CAC (sem contas a pagar, sem contabilidade)
create table if not exists custos_cac (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  descricao text not null,
  valor numeric(14,2) not null check (valor > 0),
  competencia date not null,
  grupo text not null default 'outros' check (grupo in ('midia', 'comissao', 'equipe', 'ferramentas', 'outros')),
  rateio_regra_id uuid references rateio_regras(id) on delete set null,
  fornecedor_id uuid references fornecedores(id) on delete set null,
  campanha_id uuid references campanhas(id) on delete set null,
  campanha_canal_id uuid references campanha_canais(id) on delete set null,
  criado_em timestamptz not null default now(), criado_por uuid default auth.uid());
comment on table custos_cac is 'Custo informado só para compor o CAC (rateado por regra). Não gera lançamento, saldo nem conta a pagar.';
alter table custos_cac enable row level security;
do $$ declare t text := 'custos_cac'; begin
  execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id))', t || '_leitura', t);
  execute format('create policy %I on public.%I for insert to authenticated with check (pode_operar(workspace_id))', t || '_insercao', t);
  execute format('create policy %I on public.%I for update to authenticated using (pode_operar(workspace_id)) with check (pode_operar(workspace_id))', t || '_edicao', t);
  execute format('create policy %I on public.%I for delete to authenticated using (pode_operar(workspace_id))', t || '_exclusao', t);
  execute format('create policy perm_ler on public.%I as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''fin'',''adm'',''mkt'']))', t);
  execute format('create policy perm_inserir on public.%I as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''fin'',''mkt'']))', t);
  execute format('create policy perm_alterar on public.%I as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''fin'',''mkt''])) with check (perm(workspace_id, ''editar'', array[''fin'',''mkt'']))', t);
  execute format('create policy perm_excluir on public.%I as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''fin'',''mkt'']))', t);
end $$;

-- v_custos_rateados passa a incluir os custos_cac (mesmas colunas; custo informado = 100% ou conforme a regra de rateio)
create or replace view v_custos_rateados with (security_invoker = true) as
select cp.id as conta_pagar_id, cp.workspace_id, cp.competencia, cp.vencimento, cp.status, cp.campanha_id, cp.fornecedor_id,
  cp.descricao, pc.codigo as conta_codigo, pc.nome as conta_nome, pc.cac_grupo,
  r.id as regra_id, r.nome as regra_nome,
  coalesce(i.centro_custo_id, cp.centro_custo_id) as centro_custo_id, cc.nome as centro_nome,
  coalesce(cc.entra_no_cac, true) as entra_no_cac,
  coalesce(i.percentual, 100) as percentual,
  cp.valor * coalesce(i.percentual, 100) / 100 as valor, cp.valor as valor_total
from contas_pagar cp
left join plano_contas pc on pc.id = cp.conta_despesa_id
left join (select r0.* from rateio_regras r0 where r0.ativo and (select coalesce(sum(percentual), 0) from rateio_itens x where x.regra_id = r0.id) = 100) r
  on r.id = coalesce(cp.rateio_regra_id, pc.rateio_regra_id)
left join rateio_itens i on i.regra_id = r.id
left join centros_custo cc on cc.id = coalesce(i.centro_custo_id, cp.centro_custo_id)
union all
select k.id, k.workspace_id, k.competencia, k.competencia, 'pago'::text, k.campanha_id, k.fornecedor_id,
  k.descricao, null::text, null::text, k.grupo,
  r.id, r.nome,
  i.centro_custo_id, cc.nome,
  coalesce(cc.entra_no_cac, true),
  coalesce(i.percentual, 100),
  k.valor * coalesce(i.percentual, 100) / 100, k.valor
from custos_cac k
left join (select r0.* from rateio_regras r0 where r0.ativo and (select coalesce(sum(percentual), 0) from rateio_itens x where x.regra_id = r0.id) = 100) r on r.id = k.rateio_regra_id
left join rateio_itens i on i.regra_id = r.id
left join centros_custo cc on cc.id = i.centro_custo_id;
grant select on v_custos_rateados to authenticated;

-- Investimento por campanha/canal inclui os custos informados com campanha
create or replace view v_marketing_campanha with (security_invoker = true) as
 WITH inv AS (
         SELECT x.campanha_id, sum(x.valor) AS investimento
           FROM (SELECT campanha_id, valor FROM contas_pagar WHERE status <> 'cancelado'::text AND campanha_id IS NOT NULL
                 UNION ALL SELECT campanha_id, valor FROM custos_cac WHERE campanha_id IS NOT NULL) x
          GROUP BY x.campanha_id
        ), ld AS (
         SELECT pessoas.campanha_id,
            count(*) AS leads,
            count(*) FILTER (WHERE pessoas.qualificacao = 'qualificado'::text) AS qualificados
           FROM pessoas
          WHERE pessoas.campanha_id IS NOT NULL
          GROUP BY pessoas.campanha_id
        ), vd AS (
         SELECT vendas.campanha_id,
            count(*) FILTER (WHERE vendas.status = 'aprovada'::text) AS vendas,
            COALESCE(sum(vendas.valor_bruto) FILTER (WHERE vendas.status = 'aprovada'::text), 0::numeric) AS receita_bruta,
            count(DISTINCT vendas.pessoa_id) FILTER (WHERE vendas.status = 'aprovada'::text) AS clientes
           FROM vendas
          WHERE vendas.campanha_id IS NOT NULL
          GROUP BY vendas.campanha_id
        )
 SELECT c.id AS campanha_id, c.workspace_id, c.nome, c.status, c.orcamento_total, c.meta_leads, c.meta_vendas, c.meta_receita, c.meta_cac,
    COALESCE(inv.investimento, 0::numeric) AS investimento,
    COALESCE(ld.leads, 0::bigint) AS leads,
    COALESCE(ld.qualificados, 0::bigint) AS qualificados,
    COALESCE(vd.vendas, 0::bigint) AS vendas,
    COALESCE(vd.clientes, 0::bigint) AS clientes,
    COALESCE(vd.receita_bruta, 0::numeric) AS receita_bruta,
    round(COALESCE(inv.investimento, 0::numeric) / NULLIF(ld.leads, 0)::numeric, 2) AS cpl,
    round(COALESCE(inv.investimento, 0::numeric) / NULLIF(vd.clientes, 0)::numeric, 2) AS cac,
    round(vd.receita_bruta / NULLIF(inv.investimento, 0::numeric), 2) AS roas,
    round(vd.vendas::numeric * 100::numeric / NULLIF(ld.leads, 0)::numeric, 2) AS taxa_lead_venda
   FROM campanhas c
     LEFT JOIN inv ON inv.campanha_id = c.id
     LEFT JOIN ld ON ld.campanha_id = c.id
     LEFT JOIN vd ON vd.campanha_id = c.id;
grant select on v_marketing_campanha to authenticated;

create or replace view v_marketing_canal with (security_invoker = true) as
 WITH inv AS (
         SELECT x.campanha_canal_id, sum(x.valor) AS investimento
           FROM (SELECT campanha_canal_id, valor FROM contas_pagar WHERE status <> 'cancelado'::text AND campanha_canal_id IS NOT NULL
                 UNION ALL SELECT campanha_canal_id, valor FROM custos_cac WHERE campanha_canal_id IS NOT NULL) x
          GROUP BY x.campanha_canal_id
        ), ld AS (
         SELECT pessoas.workspace_id, pessoas.utm_campaign, count(*) AS leads,
            count(*) FILTER (WHERE pessoas.qualificacao = 'qualificado'::text) AS qualificados
           FROM pessoas WHERE pessoas.utm_campaign IS NOT NULL
          GROUP BY pessoas.workspace_id, pessoas.utm_campaign
        ), vd AS (
         SELECT p.workspace_id, p.utm_campaign,
            count(*) FILTER (WHERE v.status = 'aprovada'::text) AS vendas,
            COALESCE(sum(v.valor_bruto) FILTER (WHERE v.status = 'aprovada'::text), 0::numeric) AS receita_bruta,
            count(DISTINCT v.pessoa_id) FILTER (WHERE v.status = 'aprovada'::text) AS clientes
           FROM vendas v JOIN pessoas p ON p.id = v.pessoa_id
          WHERE p.utm_campaign IS NOT NULL
          GROUP BY p.workspace_id, p.utm_campaign
        )
 SELECT cc.id AS campanha_canal_id, cc.workspace_id, cc.campanha_id, c.nome AS campanha, cc.canal, cc.utm_campaign, cc.orcamento, cc.meta_leads, cc.meta_vendas, cc.meta_cac,
    COALESCE(inv.investimento, 0::numeric) AS investimento,
    COALESCE(ld.leads, 0::bigint) AS leads,
    COALESCE(ld.qualificados, 0::bigint) AS qualificados,
    COALESCE(vd.vendas, 0::bigint) AS vendas,
    COALESCE(vd.clientes, 0::bigint) AS clientes,
    COALESCE(vd.receita_bruta, 0::numeric) AS receita_bruta,
    round(COALESCE(inv.investimento, 0::numeric) / NULLIF(ld.leads, 0)::numeric, 2) AS cpl,
    round(COALESCE(inv.investimento, 0::numeric) / NULLIF(vd.clientes, 0)::numeric, 2) AS cac
   FROM campanha_canais cc
     JOIN campanhas c ON c.id = cc.campanha_id
     LEFT JOIN inv ON inv.campanha_canal_id = cc.id
     LEFT JOIN ld ON ld.workspace_id = cc.workspace_id AND ld.utm_campaign = cc.utm_campaign
     LEFT JOIN vd ON vd.workspace_id = cc.workspace_id AND vd.utm_campaign = cc.utm_campaign;
grant select on v_marketing_canal to authenticated;

-- Métricas do Growth e série da campanha também enxergam o custo informado
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'growth_metricas_auto' and pronamespace = 'public'::regnamespace;
  d := replace(d, $a$select coalesce(sum(valor), 0) into inv_c from contas_pagar where workspace_id = p_ws and campanha_id is not null and status <> 'cancelado' and competencia between p_ini and p_fim;$a$,
    $b$select coalesce(sum(v), 0) into inv_c from (select valor as v from contas_pagar where workspace_id = p_ws and campanha_id is not null and status <> 'cancelado' and competencia between p_ini and p_fim
      union all select valor from custos_cac where workspace_id = p_ws and campanha_id is not null and competencia between p_ini and p_fim) z;$b$);
  execute d;
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'campanha_series' and pronamespace = 'public'::regnamespace;
  d := replace(d, $a$union all select competencia, valor from contas_pagar where not usa_trf and workspace_id = p_ws and campanha_id = p_campanha and status <> 'cancelado' and (p_canal is null or campanha_canal_id = p_canal))$a$,
    $b$union all select competencia, valor from contas_pagar where not usa_trf and workspace_id = p_ws and campanha_id = p_campanha and status <> 'cancelado' and (p_canal is null or campanha_canal_id = p_canal)
              union all select competencia, valor from custos_cac where not usa_trf and workspace_id = p_ws and campanha_id = p_campanha and (p_canal is null or campanha_canal_id = p_canal))$b$);
  execute d;
end $mig$;
