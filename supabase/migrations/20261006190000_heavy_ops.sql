-- RevOps: operação de alunos (retenção, churn, LTV, produtos e ascensão).
-- Os números saem desta função, em código fixo. A tela só desenha e compara com as metas.

-- Escada de valor: nível do produto (1 = entrada). Ascensão = comprar um nível acima do que já comprou.
alter table produtos add column nivel_escada int check (nivel_escada >= 1);

-- Quando o aluno deixou de estar ativo (base do churn e da retenção).
alter table alunos add column saiu_em timestamptz;
update alunos set saiu_em = now() where status <> 'ativo' and saiu_em is null;

create function alunos_saida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ativo' then new.saiu_em := null;
  elsif new.saiu_em is null then new.saiu_em := now(); end if;
  return new;
end $$;
create trigger alunos_saida_t before insert or update on alunos for each row execute function alunos_saida();
revoke execute on function alunos_saida() from public, anon, authenticated;

-- Metas de referência por workspace (a tela pinta verde, amarelo ou vermelho comparando com elas).
create table heavyops_metas (
  workspace_id uuid primary key references workspaces(id) on delete cascade,
  churn_max numeric(6, 2) not null default 6 check (churn_max >= 0),
  retencao_min numeric(6, 2) not null default 85 check (retencao_min between 0 and 100),
  ltv_min numeric(14, 2) not null default 600 check (ltv_min >= 0),
  ascensao_min numeric(6, 2) not null default 15 check (ascensao_min between 0 and 100),
  tolerancia numeric(6, 2) not null default 15 check (tolerancia between 0 and 100)
);
alter table heavyops_metas enable row level security;
create policy heavyops_metas_acesso on heavyops_metas for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

-- Painel inteiro em uma chamada. Roda com as permissões de quem chama (RLS vale).
create function heavyops_painel(p_ws uuid, p_dias int default 30) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  agora timestamptz := now();
  dias int := least(greatest(coalesce(p_dias, 30), 7), 365);
  m heavyops_metas;
  r_serie jsonb; r_curva jsonb; r_ltv jsonb; r_ltv_ent jsonb; r_prods jsonb; r_asc jsonb; r_etapas jsonb; r_tot jsonb;
begin
  select * into m from heavyops_metas where workspace_id = p_ws;
  if not found then m.churn_max := 6; m.retencao_min := 85; m.ltv_min := 600; m.ascensao_min := 15; m.tolerancia := 15; end if;

  -- Base ativa e churn por janelas de 30 dias (k = 0 é a mais recente).
  select coalesce(jsonb_agg(jsonb_build_object('k', k, 'ini', ini, 'fim', fim, 'base', base_ini, 'ativos', ativos_fim, 'perdidos', perdidos) order by k desc), '[]') into r_serie
  from (
    select s.k, s.ini, s.fim,
      (select count(distinct a.pessoa_id) from alunos a where a.workspace_id = p_ws and a.entrou_em <= s.ini and (a.saiu_em is null or a.saiu_em > s.ini)) as base_ini,
      (select count(distinct a.pessoa_id) from alunos a where a.workspace_id = p_ws and a.entrou_em <= s.fim and (a.saiu_em is null or a.saiu_em > s.fim)) as ativos_fim,
      (select count(distinct x.pessoa_id) from alunos x
        where x.workspace_id = p_ws and x.entrou_em <= s.ini and (x.saiu_em is null or x.saiu_em > s.ini)
          and not exists (select 1 from alunos y where y.pessoa_id = x.pessoa_id and y.entrou_em <= s.fim and (y.saiu_em is null or y.saiu_em > s.fim))) as perdidos
    from (select k, agora - make_interval(days => (k + 1) * 30) as ini, agora - make_interval(days => k * 30) as fim from generate_series(0, 5) k) s
  ) q;

  -- Curva de retenção: das pessoas que entraram há pelo menos t dias, quantas seguiam ativas t dias depois de entrar.
  select coalesce(jsonb_agg(jsonb_build_object('dias', d, 'elegiveis', el, 'retidos', ret) order by d), '[]') into r_curva
  from (
    select t.d, count(*) filter (where f.f <= agora - make_interval(days => t.d)) as el,
      count(*) filter (where f.f <= agora - make_interval(days => t.d) and exists (
        select 1 from alunos a where a.pessoa_id = f.pessoa_id and a.entrou_em <= f.f + make_interval(days => t.d) and (a.saiu_em is null or a.saiu_em > f.f + make_interval(days => t.d)))) as ret
    from (select unnest(array[30, 60, 90, 120, 150]) as d) t
    cross join (select pessoa_id, min(entrou_em) as f from alunos where workspace_id = p_ws group by pessoa_id) f
    group by t.d
  ) q;

  -- LTV: receita líquida acumulada por cliente (vendas aprovadas).
  select jsonb_build_object('clientes', count(*), 'receita', coalesce(sum(ltv), 0), 'ltv', coalesce(avg(ltv), 0), 'compras_por_cliente', coalesce(avg(n), 0)) into r_ltv
  from (select pessoa_id, sum(valor_liquido) as ltv, count(*) as n from vendas where workspace_id = p_ws and status = 'aprovada' group by pessoa_id) c;

  select coalesce(jsonb_agg(jsonb_build_object('produto', nome, 'nivel', nivel, 'clientes', clientes, 'ltv', ltv) order by clientes desc), '[]') into r_ltv_ent
  from (
    select p.nome, p.nivel_escada as nivel, count(*) as clientes, avg(c.ltv) as ltv
    from (select distinct on (v.pessoa_id) v.pessoa_id, v.produto_id from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' order by v.pessoa_id, v.data_venda, v.id) pri
    join (select pessoa_id, sum(valor_liquido) as ltv from vendas where workspace_id = p_ws and status = 'aprovada' group by pessoa_id) c on c.pessoa_id = pri.pessoa_id
    join produtos p on p.id = pri.produto_id
    group by p.nome, p.nivel_escada
  ) q;

  -- Produtos: vendas no período, período anterior, ascensões recebidas e taxa de ascensão a partir de cada um.
  with v as (
    select x.id, x.pessoa_id, x.produto_id, x.valor_liquido, x.data_venda, p.nivel_escada as nivel,
      max(p.nivel_escada) over (partition by x.pessoa_id order by x.data_venda, x.id rows between unbounded preceding and 1 preceding) as nivel_antes
    from vendas x join produtos p on p.id = x.produto_id
    where x.workspace_id = p_ws and x.status = 'aprovada'
  ), topo as (select max(nivel_escada) as n from produtos where workspace_id = p_ws)
  select coalesce(jsonb_agg(jsonb_build_object(
      'produto', p.nome, 'nivel', p.nivel_escada, 'preco', p.preco,
      'vendas', coalesce(a.vendas, 0), 'vendas_ant', coalesce(a.vendas_ant, 0), 'receita', coalesce(a.receita, 0),
      'compradores', coalesce(a.compradores, 0), 'asc_recebidas', coalesce(a.asc_rec, 0), 'asc_recebidas_total', coalesce(a.asc_rec_total, 0),
      'sobem', coalesce(a.sobem, 0), 'pode_subir', p.nivel_escada is not null and p.nivel_escada < (select n from topo)
    ) order by coalesce(a.vendas, 0) desc, p.nome), '[]') into r_prods
  from produtos p
  left join (
    select produto_id,
      count(*) filter (where data_venda >= agora - make_interval(days => dias)) as vendas,
      count(*) filter (where data_venda >= agora - make_interval(days => dias * 2) and data_venda < agora - make_interval(days => dias)) as vendas_ant,
      coalesce(sum(valor_liquido) filter (where data_venda >= agora - make_interval(days => dias)), 0) as receita,
      count(distinct pessoa_id) as compradores,
      count(*) filter (where nivel_antes is not null and nivel > nivel_antes and data_venda >= agora - make_interval(days => dias)) as asc_rec,
      count(*) filter (where nivel_antes is not null and nivel > nivel_antes) as asc_rec_total,
      count(distinct pessoa_id) filter (where exists (select 1 from v v2 where v2.pessoa_id = v.pessoa_id and v2.nivel > v.nivel and v2.data_venda > v.data_venda)) as sobem
    from v group by produto_id
  ) a on a.produto_id = p.id
  where p.workspace_id = p_ws and p.ativo;

  -- Ascensão geral: dos clientes que entraram abaixo do topo da escada, quantos já subiram pelo menos um degrau.
  with v as (
    select x.id, x.pessoa_id, p.nivel_escada as nivel, x.data_venda,
      max(p.nivel_escada) over (partition by x.pessoa_id order by x.data_venda, x.id rows between unbounded preceding and 1 preceding) as nivel_antes
    from vendas x join produtos p on p.id = x.produto_id
    where x.workspace_id = p_ws and x.status = 'aprovada' and p.nivel_escada is not null
  ), pri as (select distinct on (pessoa_id) pessoa_id, nivel from v order by pessoa_id, data_venda, id),
  topo as (select max(nivel_escada) as n from produtos where workspace_id = p_ws)
  select jsonb_build_object(
    'elegiveis', (select count(*) from pri where nivel < (select n from topo)),
    'subiram', (select count(distinct pessoa_id) from v where nivel_antes is not null and nivel > nivel_antes)) into r_asc;

  select coalesce(jsonb_agg(jsonb_build_object('etapa', e.nome, 'ordem', e.ordem, 'n', coalesce(c.n, 0)) order by e.ordem), '[]') into r_etapas
  from etapas_kanban e
  left join (select etapa_kanban_id, count(*) as n from alunos where workspace_id = p_ws and saiu_em is null group by etapa_kanban_id) c on c.etapa_kanban_id = e.id
  where e.workspace_id = p_ws and e.quadro = 'alunos';

  select jsonb_build_object(
    'ativos', (select count(distinct pessoa_id) from alunos where workspace_id = p_ws and saiu_em is null),
    'matriculas', (select count(*) from alunos where workspace_id = p_ws),
    'saidas', (select count(*) from alunos where workspace_id = p_ws and saiu_em is not null)) into r_tot;

  return jsonb_build_object('gerado_em', agora, 'dias', dias,
    'metas', jsonb_build_object('churn_max', m.churn_max, 'retencao_min', m.retencao_min, 'ltv_min', m.ltv_min, 'ascensao_min', m.ascensao_min, 'tolerancia', m.tolerancia),
    'serie', r_serie, 'curva', r_curva, 'ltv', r_ltv, 'ltv_entrada', r_ltv_ent, 'produtos', r_prods, 'ascensao', r_asc, 'etapas', r_etapas, 'totais', r_tot);
end $$;
revoke execute on function heavyops_painel(uuid, int) from public, anon;
grant execute on function heavyops_painel(uuid, int) to authenticated;
