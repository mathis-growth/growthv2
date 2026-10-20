-- Análise de funil: continuação no pós-compra (RevOps) e cohorts com churn, retenção, LTV, CAC, ROAS e ROI.
-- Tudo calculado por regra fixa, sem IA.

-- 1) Histórico de etapas do aluno (a tabela alunos só guarda a etapa atual).
create table if not exists aluno_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  aluno_id uuid not null references alunos(id) on delete cascade,
  pessoa_id uuid references pessoas(id) on delete cascade,
  tipo text not null check (tipo in ('etapa', 'saida', 'volta')),
  etapa_kanban_id uuid references etapas_kanban(id) on delete set null,
  em timestamptz not null default now()
);
create index if not exists aluno_historico_ws_pessoa on aluno_historico (workspace_id, pessoa_id);
alter table aluno_historico enable row level security;
create policy aluno_historico_rls on aluno_historico for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));

create or replace function aluno_historico_t() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.etapa_kanban_id is not null then
      insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, etapa_kanban_id, em) values (new.workspace_id, new.id, new.pessoa_id, 'etapa', new.etapa_kanban_id, coalesce(new.entrou_em, now()));
    end if;
  else
    if new.etapa_kanban_id is distinct from old.etapa_kanban_id and new.etapa_kanban_id is not null then
      insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, etapa_kanban_id) values (new.workspace_id, new.id, new.pessoa_id, 'etapa', new.etapa_kanban_id);
    end if;
    if old.saiu_em is null and new.saiu_em is not null then
      insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, em) values (new.workspace_id, new.id, new.pessoa_id, 'saida', new.saiu_em);
    elsif old.saiu_em is not null and new.saiu_em is null then
      insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo) values (new.workspace_id, new.id, new.pessoa_id, 'volta');
    end if;
  end if;
  return null;
end $$;
revoke execute on function aluno_historico_t() from public, anon, authenticated;
create trigger aluno_historico_trg after insert or update of etapa_kanban_id, saiu_em on alunos for each row execute function aluno_historico_t();

-- Alunos que já existiam: um registro da etapa atual (data de entrada). O que veio antes não é conhecido.
insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, etapa_kanban_id, em)
select a.workspace_id, a.id, a.pessoa_id, 'etapa', a.etapa_kanban_id, a.entrou_em from alunos a
where a.etapa_kanban_id is not null and not exists (select 1 from aluno_historico h where h.aluno_id = a.id);

-- 2) Quem chegou em cada passo, agora com o pós-compra.
-- Chaves novas: alunos, a:<etapa do aluno>, ativos, saiu, ascensao, recompra.
-- "Chegou na etapa do aluno" = está nela, está numa etapa posterior (pela ordem) ou já passou por ela (histórico).
create or replace function funil_membros(p_ws uuid, p_ini date, p_fim date, p_camp uuid, p_funil uuid)
returns table(pessoa_id uuid, chave text)
language sql stable set search_path = public as $$
  with co as (
    select p.id, p.qualificacao, p.pesquisa_respondida_em from pessoas p
    where p.workspace_id = p_ws
      and p.criado_em >= (p_ini::timestamp at time zone 'America/Sao_Paulo')
      and p.criado_em < ((p_fim + 1)::timestamp at time zone 'America/Sao_Paulo')
      and (p_camp is null or p.campanha_id = p_camp)),
  al as (select a.pessoa_id, bool_or(a.saiu_em is null) as ativo from alunos a where a.workspace_id = p_ws and a.pessoa_id in (select id from co) group by a.pessoa_id),
  vn as (select v.pessoa_id, pr.nivel_escada as nivel,
      max(pr.nivel_escada) over (partition by v.pessoa_id order by v.data_venda, v.id rows between unbounded preceding and 1 preceding) as ant
    from vendas v join produtos pr on pr.id = v.produto_id
    where v.workspace_id = p_ws and v.status = 'aprovada' and v.pessoa_id in (select id from co))
  select co.id, 'leads'::text from co
  union all select co.id, 'qualificados'::text from co where co.qualificacao = 'qualificado'
  union all select co.id, 'pesquisa'::text from co where co.pesquisa_respondida_em is not null
  union all select distinct h.pessoa_id, 'e:' || e.id::text
    from funil_etapas e
    join pessoa_funil_historico h on h.workspace_id = p_ws and h.funil_id = e.funil_id and h.tipo = 'etapa' and h.para = e.nome
    where e.workspace_id = p_ws and e.funil_id = p_funil and e.tipo <> 'entrada' and h.pessoa_id in (select id from co)
  union all select distinct v.pessoa_id, 'clientes'::text
    from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' and v.pessoa_id in (select id from co)
  union all select al.pessoa_id, 'alunos'::text from al
  union all select al.pessoa_id, 'ativos'::text from al where al.ativo
  union all select al.pessoa_id, 'saiu'::text from al where not al.ativo
  union all select distinct a.pessoa_id, 'a:' || e.id::text
    from etapas_kanban e
    join etapas_kanban ea on ea.workspace_id = p_ws and ea.quadro = 'alunos' and ea.ordem >= e.ordem
    join alunos a on a.etapa_kanban_id = ea.id and a.workspace_id = p_ws
    where e.workspace_id = p_ws and e.quadro = 'alunos' and a.pessoa_id in (select id from co)
  union all select distinct h.pessoa_id, 'a:' || h.etapa_kanban_id::text
    from aluno_historico h where h.workspace_id = p_ws and h.tipo = 'etapa' and h.etapa_kanban_id is not null and h.pessoa_id in (select id from co)
  union all select distinct vn.pessoa_id, 'ascensao'::text from vn where vn.nivel is not null and vn.ant is not null and vn.nivel > vn.ant
  union all select vn.pessoa_id, 'recompra'::text from vn group by vn.pessoa_id having count(*) >= 2
$$;

-- 3) Análise de funil com o pós-compra.
create or replace function funil_analise(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null, p_funil uuid default null) returns jsonb
language plpgsql stable set search_path = public as $$
declare
  v_funil uuid; v_len int; v_pini date; v_pfim date;
  r_ini timestamptz; r_fim timestamptz;
  r_cur jsonb; r_prev jsonb; r_ads jsonb; r_ads_p jsonb; r_et jsonb; r_ea jsonb; r_dc jsonb; r_dk jsonb; r_camps jsonb; r_st jsonb; r_diag jsonb; r_nomes jsonb; r_pos jsonb;
begin
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  if p_fim - p_ini > 400 then raise exception 'O período máximo é de 400 dias'; end if;
  v_funil := funil_resolve(p_ws, p_campanha, p_funil);
  v_len := p_fim - p_ini + 1; v_pfim := p_ini - 1; v_pini := p_ini - v_len;
  r_ini := p_ini::timestamp at time zone 'America/Sao_Paulo'; r_fim := (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo';

  with m as (select distinct pessoa_id, chave from funil_membros(p_ws, p_ini, p_fim, p_campanha, v_funil)),
  b as (select p.id, coalesce(p.campanha_id::text, '') as camp, coalesce(nullif(p.canal_origem, ''), '(sem canal)') as canal from pessoas p where p.id in (select pessoa_id from m))
  select
    (select coalesce(jsonb_object_agg(chave, n), '{}'::jsonb) from (select chave, count(*) as n from m group by chave) t),
    (select coalesce(jsonb_object_agg(chave, arr), '{}'::jsonb) from (select x.chave, jsonb_agg(jsonb_build_object('k', x.k, 'n', x.n) order by x.n desc) as arr from (select m.chave, b.camp as k, count(*) as n from m join b on b.id = m.pessoa_id group by m.chave, b.camp) x group by x.chave) t),
    (select coalesce(jsonb_object_agg(chave, arr), '{}'::jsonb) from (select x.chave, jsonb_agg(jsonb_build_object('k', x.k, 'n', x.n) order by x.n desc) as arr from (select m.chave, b.canal as k, count(*) as n from m join b on b.id = m.pessoa_id group by m.chave, b.canal) x group by x.chave) t)
  into r_cur, r_dc, r_dk;

  select coalesce(jsonb_object_agg(chave, n), '{}'::jsonb) into r_prev
  from (select chave, count(distinct pessoa_id) as n from funil_membros(p_ws, v_pini, v_pfim, p_campanha, v_funil) group by chave) t;

  r_ads := funil_ads(p_ws, p_ini, p_fim, p_campanha); r_ads_p := funil_ads(p_ws, v_pini, v_pfim, p_campanha);
  select coalesce(jsonb_agg(jsonb_build_object('chave', 'e:' || id::text, 'nome', nome, 'ordem', ordem, 'tipo', tipo) order by ordem), '[]'::jsonb) into r_et
  from funil_etapas where workspace_id = p_ws and funil_id = v_funil and tipo <> 'entrada';
  select coalesce(jsonb_agg(jsonb_build_object('chave', 'a:' || id::text, 'nome', nome, 'ordem', ordem) order by ordem), '[]'::jsonb) into r_ea
  from etapas_kanban where workspace_id = p_ws and quadro = 'alunos';
  select coalesce(jsonb_object_agg(id::text, nome), '{}'::jsonb) into r_nomes from campanhas where workspace_id = p_ws;

  -- Passos em ordem. Laterais (qualificados, pesquisa, ativos, saíram, ascensão, recompra) não são "o passo seguinte":
  -- os do topo comparam com os leads; os do pós-compra comparam com os alunos.
  with s as (
    select 1 as ord, 'impressoes' as chave, 'Impressões' as nome, 'anuncio' as grupo, false as lat, (r_ads ->> 'impressoes')::numeric as n, (r_ads_p ->> 'impressoes')::numeric as np
      where (r_ads ->> 'impressoes')::numeric > 0 or (r_ads_p ->> 'impressoes')::numeric > 0
    union all select 2, 'cliques', 'Cliques', 'anuncio', false, (r_ads ->> 'cliques')::numeric, (r_ads_p ->> 'cliques')::numeric
      where (r_ads ->> 'cliques')::numeric > 0 or (r_ads_p ->> 'cliques')::numeric > 0
    union all select 3, 'visualizacoes', 'Visualizações da página', 'anuncio', false, (r_ads ->> 'visualizacoes')::numeric, (r_ads_p ->> 'visualizacoes')::numeric
      where (r_ads ->> 'visualizacoes')::numeric > 0 or (r_ads_p ->> 'visualizacoes')::numeric > 0
    union all select 4, 'leads', 'Leads', 'pessoa', false, coalesce((r_cur ->> 'leads')::numeric, 0), coalesce((r_prev ->> 'leads')::numeric, 0)
    union all select 10 + (e.value ->> 'ordem')::int, e.value ->> 'chave', e.value ->> 'nome', 'pessoa', false, coalesce((r_cur ->> (e.value ->> 'chave'))::numeric, 0), coalesce((r_prev ->> (e.value ->> 'chave'))::numeric, 0)
      from jsonb_array_elements(r_et) e
    union all select 900, 'clientes', 'Clientes (venda aprovada)', 'pessoa', false, coalesce((r_cur ->> 'clientes')::numeric, 0), coalesce((r_prev ->> 'clientes')::numeric, 0)
    union all select 905, 'alunos', 'Entraram como aluno', 'pos', false, coalesce((r_cur ->> 'alunos')::numeric, 0), coalesce((r_prev ->> 'alunos')::numeric, 0)
    union all select 910 + (e.value ->> 'ordem')::int, e.value ->> 'chave', e.value ->> 'nome', 'pos', false, coalesce((r_cur ->> (e.value ->> 'chave'))::numeric, 0), coalesce((r_prev ->> (e.value ->> 'chave'))::numeric, 0)
      from jsonb_array_elements(r_ea) e
    union all select 950, 'qualificados', 'Qualificados', 'pessoa', true, coalesce((r_cur ->> 'qualificados')::numeric, 0), coalesce((r_prev ->> 'qualificados')::numeric, 0)
    union all select 951, 'pesquisa', 'Responderam pesquisa', 'pessoa', true, coalesce((r_cur ->> 'pesquisa')::numeric, 0), coalesce((r_prev ->> 'pesquisa')::numeric, 0)
    union all select 960, 'ativos', 'Ainda ativos', 'pos', true, coalesce((r_cur ->> 'ativos')::numeric, 0), coalesce((r_prev ->> 'ativos')::numeric, 0)
    union all select 961, 'saiu', 'Saíram (churn)', 'pos', true, coalesce((r_cur ->> 'saiu')::numeric, 0), coalesce((r_prev ->> 'saiu')::numeric, 0)
    union all select 962, 'ascensao', 'Ascenderam (compraram nível maior)', 'pos', true, coalesce((r_cur ->> 'ascensao')::numeric, 0), coalesce((r_prev ->> 'ascensao')::numeric, 0)
    union all select 963, 'recompra', 'Recompraram', 'pos', true, coalesce((r_cur ->> 'recompra')::numeric, 0), coalesce((r_prev ->> 'recompra')::numeric, 0)
  ), c as (
    select s.*,
      case when s.lat then null else lag(s.n) over (partition by s.lat order by s.ord) end as base,
      case when s.lat then null else lag(s.np) over (partition by s.lat order by s.ord) end as base_p,
      case when s.lat and s.grupo = 'pos' then coalesce((r_cur ->> 'alunos')::numeric, 0) else coalesce((r_cur ->> 'leads')::numeric, 0) end as ref_n,
      case when s.lat and s.grupo = 'pos' then coalesce((r_prev ->> 'alunos')::numeric, 0) else coalesce((r_prev ->> 'leads')::numeric, 0) end as ref_p
    from s
  ), d as (
    select c.*,
      case when c.lat then case when c.ref_n > 0 then c.n / c.ref_n end else case when c.base > 0 then c.n / c.base end end as conv,
      case when c.lat then case when c.ref_p > 0 then c.np / c.ref_p end else case when c.base_p > 0 then c.np / c.base_p end end as conv_p
    from c
  )
  select coalesce(jsonb_agg(jsonb_build_object('chave', chave, 'nome', nome, 'grupo', grupo, 'lateral', lat, 'n', n, 'n_ant', np, 'base', base,
      'conv', round(conv, 4), 'conv_ant', round(conv_p, 4), 'var', case when conv_p > 0 and conv is not null then round(conv / conv_p - 1, 4) end,
      'do_topo', case when not lat and grupo in ('pessoa', 'pos') and (select n from s where chave = 'leads') > 0 then round(n / (select n from s where chave = 'leads'), 4) end) order by ord), '[]'::jsonb)
  into r_st from d;

  -- Gargalo = passo que mais piorou contra o período anterior (queda de pelo menos 15%, base mínima de 10).
  -- Maior perda = passo de pessoas (inclui o pós-compra) em que mais gente ficou pelo caminho.
  with e as (select x ->> 'chave' as chave, x ->> 'nome' as nome, (x ->> 'conv')::numeric as conv, (x ->> 'conv_ant')::numeric as conv_ant, (x ->> 'var')::numeric as var,
      (x ->> 'base')::numeric as base, (x ->> 'n')::numeric as n, (x ->> 'grupo') as grupo, (x ->> 'lateral')::boolean as lat
    from jsonb_array_elements(r_st) x)
  select jsonb_build_object(
    'gargalo', (select jsonb_build_object('chave', chave, 'nome', nome, 'conv', conv, 'conv_ant', conv_ant, 'var', var) from e where not lat and base >= 10 and var is not null and var <= -0.15 order by var limit 1),
    'maior_perda', (select jsonb_build_object('chave', chave, 'nome', nome, 'perdidos', base - n, 'base', base) from e where not lat and grupo in ('pessoa', 'pos') and base is not null and base > n and chave <> 'leads' order by base - n desc limit 1))
  into r_diag;

  with co as (select p.id, p.campanha_id, p.qualificacao from pessoas p where p.workspace_id = p_ws and p.criado_em >= r_ini and p.criado_em < r_fim and (p_campanha is null or p.campanha_id = p_campanha)),
  le as (select campanha_id, count(*) as leads, count(*) filter (where qualificacao = 'qualificado') as qualificados from co group by campanha_id),
  rec as (select co.campanha_id, count(distinct v.pessoa_id) as clientes, coalesce(sum(v.valor_liquido), 0) as receita from co join vendas v on v.pessoa_id = co.id and v.status = 'aprovada' group by co.campanha_id),
  alp as (select a.pessoa_id, bool_or(a.saiu_em is null) as ativo from alunos a where a.workspace_id = p_ws and a.pessoa_id in (select id from co) group by a.pessoa_id),
  alc as (select co.campanha_id, count(*) as alunos, count(*) filter (where alp.ativo) as ativos, count(*) filter (where not alp.ativo) as saiu from co join alp on alp.pessoa_id = co.id group by co.campanha_id),
  cus as (select cc.campanha_id, sum(m.custo) as custo from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
          where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by cc.campanha_id),
  k as (select campanha_id from le union select campanha_id from cus)
  select coalesce(jsonb_agg(jsonb_build_object('id', k.campanha_id, 'nome', coalesce(ca.nome, '(sem campanha)'), 'leads', coalesce(le.leads, 0), 'qualificados', coalesce(le.qualificados, 0),
      'clientes', coalesce(rec.clientes, 0), 'receita', coalesce(rec.receita, 0), 'custo', coalesce(cus.custo, 0),
      'cpl', case when coalesce(le.leads, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / le.leads, 2) end,
      'cac', case when coalesce(rec.clientes, 0) > 0 and coalesce(cus.custo, 0) > 0 then round(coalesce(cus.custo, 0) / rec.clientes, 2) end,
      'lead_cliente', case when coalesce(le.leads, 0) > 0 then round(coalesce(rec.clientes, 0)::numeric / le.leads, 4) end,
      'roas', case when coalesce(cus.custo, 0) > 0 then round(coalesce(rec.receita, 0) / cus.custo, 2) end,
      'roi', case when coalesce(cus.custo, 0) > 0 then round((coalesce(rec.receita, 0) - cus.custo) / cus.custo, 4) end,
      'ltv', case when coalesce(rec.clientes, 0) > 0 then round(rec.receita / rec.clientes, 2) end,
      'alunos', coalesce(alc.alunos, 0), 'ativos', coalesce(alc.ativos, 0), 'saiu', coalesce(alc.saiu, 0),
      'churn', case when coalesce(alc.alunos, 0) > 0 then round(alc.saiu::numeric / alc.alunos, 4) end) order by coalesce(le.leads, 0) desc), '[]'::jsonb)
  into r_camps
  from k left join campanhas ca on ca.id = k.campanha_id left join le on le.campanha_id is not distinct from k.campanha_id
    left join rec on rec.campanha_id is not distinct from k.campanha_id left join cus on cus.campanha_id is not distinct from k.campanha_id
    left join alc on alc.campanha_id is not distinct from k.campanha_id;

  -- Resumo do pós-compra e do retorno sobre o investimento, somando as campanhas listadas.
  select jsonb_build_object('leads', sum((x ->> 'leads')::numeric), 'clientes', sum((x ->> 'clientes')::numeric), 'receita', sum((x ->> 'receita')::numeric), 'custo', sum((x ->> 'custo')::numeric),
      'alunos', sum((x ->> 'alunos')::numeric), 'ativos', sum((x ->> 'ativos')::numeric), 'saiu', sum((x ->> 'saiu')::numeric))
  into r_pos from jsonb_array_elements(r_camps) x;
  r_pos := coalesce(r_pos, '{}'::jsonb);
  r_pos := r_pos || jsonb_build_object(
    'churn', case when coalesce((r_pos ->> 'alunos')::numeric, 0) > 0 then round((r_pos ->> 'saiu')::numeric / (r_pos ->> 'alunos')::numeric, 4) end,
    'retencao', case when coalesce((r_pos ->> 'alunos')::numeric, 0) > 0 then round((r_pos ->> 'ativos')::numeric / (r_pos ->> 'alunos')::numeric, 4) end,
    'ltv', case when coalesce((r_pos ->> 'clientes')::numeric, 0) > 0 then round((r_pos ->> 'receita')::numeric / (r_pos ->> 'clientes')::numeric, 2) end,
    'cac', case when coalesce((r_pos ->> 'clientes')::numeric, 0) > 0 and coalesce((r_pos ->> 'custo')::numeric, 0) > 0 then round((r_pos ->> 'custo')::numeric / (r_pos ->> 'clientes')::numeric, 2) end,
    'roas', case when coalesce((r_pos ->> 'custo')::numeric, 0) > 0 then round((r_pos ->> 'receita')::numeric / (r_pos ->> 'custo')::numeric, 2) end,
    'roi', case when coalesce((r_pos ->> 'custo')::numeric, 0) > 0 then round(((r_pos ->> 'receita')::numeric - (r_pos ->> 'custo')::numeric) / (r_pos ->> 'custo')::numeric, 4) end,
    'ascensao', coalesce((r_cur ->> 'ascensao')::numeric, 0), 'recompra', coalesce((r_cur ->> 'recompra')::numeric, 0));

  return jsonb_build_object('funil_id', v_funil, 'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim), 'anterior', jsonb_build_object('ini', v_pini, 'fim', v_pfim),
    'custo', r_ads -> 'custo', 'custo_ant', r_ads_p -> 'custo', 'passos', r_st, 'diagnostico', r_diag, 'por_campanha', r_dc, 'por_canal', r_dk, 'campanhas', r_camps, 'nomes_campanhas', r_nomes, 'pos', r_pos);
end $$;

-- 4) Cohorts completas. p_gran: semana, mes ou campanha.
-- Por coorte: funil até a venda, janelas de conversão, receita, LTV, CAC, ROAS, ROI e, no pós-compra, churn e retenção.
-- Retenção em 30/60/90 dias: dos alunos que entraram há pelo menos N dias, quantos continuavam ativos N dias depois de entrar (campos retN_ok e retN_base).
-- Custo = gasto de anúncios nas datas da coorte (dentro do período) ou da campanha (no período).
create or replace function funil_cohorts(p_ws uuid, p_ini date, p_fim date, p_campanha uuid default null, p_gran text default 'semana') returns jsonb
language plpgsql stable set search_path = public as $$
declare r jsonb; v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  if p_ini is null or p_fim is null or p_fim < p_ini then raise exception 'Período inválido'; end if;
  if p_fim - p_ini > 800 then raise exception 'O período máximo é de 800 dias'; end if;
  if p_gran not in ('semana', 'mes', 'campanha') then raise exception 'Granularidade inválida'; end if;
  with co as (
    select p.id, p.qualificacao, p.pesquisa_respondida_em, p.campanha_id, (p.criado_em at time zone 'America/Sao_Paulo') as ts,
      case when p_gran = 'campanha' then coalesce(p.campanha_id::text, '')
           else date_trunc(case when p_gran = 'mes' then 'month' else 'week' end, p.criado_em at time zone 'America/Sao_Paulo')::date::text end as k
    from pessoas p
    where p.workspace_id = p_ws and p.criado_em >= (p_ini::timestamp at time zone 'America/Sao_Paulo') and p.criado_em < ((p_fim + 1)::timestamp at time zone 'America/Sao_Paulo')
      and (p_campanha is null or p.campanha_id = p_campanha)),
  pv as (select v.pessoa_id, min(v.data_venda at time zone 'America/Sao_Paulo') as primeira, sum(v.valor_liquido) as receita
         from vendas v where v.workspace_id = p_ws and v.status = 'aprovada' group by v.pessoa_id),
  al as (select a.pessoa_id, min(a.entrou_em) as entrou, bool_or(a.saiu_em is null) as ativo, max(a.saiu_em) as saiu_em
         from alunos a where a.workspace_id = p_ws and a.pessoa_id in (select id from co) group by a.pessoa_id),
  vn as (select v.pessoa_id, pr.nivel_escada as nivel,
      max(pr.nivel_escada) over (partition by v.pessoa_id order by v.data_venda, v.id rows between unbounded preceding and 1 preceding) as ant,
      count(*) over (partition by v.pessoa_id) as n_compras
    from vendas v join produtos pr on pr.id = v.produto_id
    where v.workspace_id = p_ws and v.status = 'aprovada' and v.pessoa_id in (select id from co)),
  asc_p as (select pessoa_id, bool_or(nivel is not null and ant is not null and nivel > ant) as ascendeu, max(n_compras) >= 2 as recomprou from vn group by pessoa_id),
  cu as (
    select case when p_gran = 'campanha' then coalesce(cc.campanha_id::text, '')
                else date_trunc(case when p_gran = 'mes' then 'month' else 'week' end, m.data::timestamp)::date::text end as k, sum(m.custo) as custo
    from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id
    where m.workspace_id = p_ws and m.data between p_ini and p_fim and (p_campanha is null or cc.campanha_id = p_campanha) group by 1),
  g as (
    select co.k, max(co.campanha_id::text) as camp_id, min(co.ts)::date as de, max(co.ts)::date as ate,
      count(*) as leads, count(*) filter (where co.qualificacao = 'qualificado') as qualificados, count(*) filter (where co.pesquisa_respondida_em is not null) as pesquisa,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '7 days') as c7,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '14 days') as c14,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '30 days') as c30,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '60 days') as c60,
      count(*) filter (where pv.primeira is not null and pv.primeira <= co.ts + interval '90 days') as c90,
      count(pv.pessoa_id) as clientes, coalesce(sum(pv.receita), 0) as receita,
      count(al.pessoa_id) as alunos, count(*) filter (where al.ativo) as ativos, count(*) filter (where al.pessoa_id is not null and not al.ativo) as saiu,
      count(*) filter (where ap.ascendeu) as ascensao, count(*) filter (where ap.recomprou) as recompra,
      count(*) filter (where al.entrou <= now() - interval '30 days') as r30_base,
      count(*) filter (where al.entrou <= now() - interval '30 days' and (al.ativo or al.saiu_em > al.entrou + interval '30 days')) as r30_ok,
      count(*) filter (where al.entrou <= now() - interval '60 days') as r60_base,
      count(*) filter (where al.entrou <= now() - interval '60 days' and (al.ativo or al.saiu_em > al.entrou + interval '60 days')) as r60_ok,
      count(*) filter (where al.entrou <= now() - interval '90 days') as r90_base,
      count(*) filter (where al.entrou <= now() - interval '90 days' and (al.ativo or al.saiu_em > al.entrou + interval '90 days')) as r90_ok,
      (v_hoje - max(co.ts::date)) as min_idade
    from co left join pv on pv.pessoa_id = co.id left join al on al.pessoa_id = co.id left join asc_p ap on ap.pessoa_id = co.id group by co.k)
  select coalesce(jsonb_agg(jsonb_build_object(
      'coorte', case when p_gran = 'campanha' then g.k else g.k end,
      'rotulo', case when p_gran = 'campanha' then coalesce((select ca.nome from campanhas ca where ca.id::text = g.k), '(sem campanha)') end,
      'de', g.de, 'ate', g.ate,
      'leads', g.leads, 'qualificados', g.qualificados, 'pesquisa', g.pesquisa, 'c7', g.c7, 'c14', g.c14, 'c30', g.c30, 'c60', g.c60, 'c90', g.c90,
      'clientes', g.clientes, 'receita', g.receita, 'min_idade', g.min_idade,
      'custo', coalesce(cu.custo, 0),
      'cpl', case when g.leads > 0 and coalesce(cu.custo, 0) > 0 then round(cu.custo / g.leads, 2) end,
      'cac', case when g.clientes > 0 and coalesce(cu.custo, 0) > 0 then round(cu.custo / g.clientes, 2) end,
      'ltv', case when g.clientes > 0 then round(g.receita / g.clientes, 2) end,
      'roas', case when coalesce(cu.custo, 0) > 0 then round(g.receita / cu.custo, 2) end,
      'roi', case when coalesce(cu.custo, 0) > 0 then round((g.receita - cu.custo) / cu.custo, 4) end,
      'ltv_cac', case when g.clientes > 0 and coalesce(cu.custo, 0) > 0 then round((g.receita / g.clientes) / (cu.custo / g.clientes), 2) end,
      'alunos', g.alunos, 'ativos', g.ativos, 'saiu', g.saiu,
      'churn', case when g.alunos > 0 then round(g.saiu::numeric / g.alunos, 4) end,
      'retencao', case when g.alunos > 0 then round(g.ativos::numeric / g.alunos, 4) end,
      'ascensao', g.ascensao, 'recompra', g.recompra,
      'r30_base', g.r30_base, 'r30_ok', g.r30_ok, 'r60_base', g.r60_base, 'r60_ok', g.r60_ok, 'r90_base', g.r90_base, 'r90_ok', g.r90_ok
    ) order by case when p_gran = 'campanha' then null else g.k end, g.leads desc), '[]'::jsonb)
  into r
  from g left join cu on cu.k = g.k;
  return r;
end $$;

revoke execute on function funil_membros(uuid, date, date, uuid, uuid), funil_analise(uuid, date, date, uuid, uuid), funil_cohorts(uuid, date, date, uuid, text) from public, anon;
grant execute on function funil_membros(uuid, date, date, uuid, uuid), funil_analise(uuid, date, date, uuid, uuid), funil_cohorts(uuid, date, date, uuid, text) to authenticated;
