-- v0.163 — Tela Customer Growth em RevOps e indicadores de evolução (Customer Growth, etapa B10).
-- 1. acesso_telas: 'ho-cg' (Customer Growth) no módulo RevOps.
-- 2. cg_indicadores(ws, produto, ini, fim): números da evolução dos alunos, sem IA, só lendo o que já existe:
--    matrículas (ativas, novas, saíram), alunos por etapa, marcos (atingidos, % no prazo, dias até atingir), check-ins (gerados,
--    respondidos, taxa), NPS das respostas ligadas a matrículas, alertas de CS abertos, intervenções (abertas, feitas, % que resolveu)
--    e receita por cliente pela regra única do RevOps (revops_receitas), sem cálculo novo de LTV.
-- 3. Dicionário de métricas: as definições novas.
-- Rode depois de 20261121100000_acompanhamento_cs.sql. Idempotente.

do $a$ begin
  if to_regclass('public.acesso_telas') is not null then
    insert into acesso_telas (tela, modulo, nome, grupo, ordem)
    values ('ho-cg', 'revops', 'Customer Growth', 'RevOps', coalesce((select min(ordem) from acesso_telas where tela = 'crm-alunos'), 40))
    on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
  end if;
end $a$;

create or replace function public.cg_indicadores(p_ws uuid, p_produto uuid default null, p_ini date default null, p_fim date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ini timestamptz; fim timestamptz; r jsonb;
begin
  if not pertence_ao_workspace(p_ws) and not pode_operar(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  if not (perm(p_ws, 'ler', array['revops', 'vendas', 'adm', 'gro']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then raise exception 'Sem permissão para ver RevOps'; end if;
  ini := (coalesce(p_ini, (now() at time zone 'America/Sao_Paulo')::date - 89))::timestamp at time zone 'America/Sao_Paulo';
  fim := (coalesce(p_fim, (now() at time zone 'America/Sao_Paulo')::date) + 1)::timestamp at time zone 'America/Sao_Paulo';
  with al as (select a.* from alunos a where a.workspace_id = p_ws and (p_produto is null or a.produto_id = p_produto)),
  ati as (select * from al where status = 'ativo' and saiu_em is null),
  et as (
    select e.id, e.nome, e.ordem, e.jornada_id, coalesce(pj.nome || ' · v' || j.versao, 'Jornada geral') as jornada, j.status as jst
      from etapas_kanban e left join jornadas j on j.id = e.jornada_id left join produtos pj on pj.id = j.produto_id
     where e.workspace_id = p_ws and e.quadro = 'alunos' and (e.jornada_id is null or j.status in ('publicada', 'anterior'))
       and (p_produto is null or j.produto_id = p_produto or (e.jornada_id is null and exists (select 1 from ati where ati.jornada_id is null)))),
  mk as (
    select m.id, m.nome, m.prazo_dias, m.obrigatorio, m.jornada_id,
      (select count(*) from ati where ati.jornada_id = m.jornada_id) as elegiveis,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido') as atingidos,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'aguardando') as aguardando,
      (select count(*) from aluno_marcos x join ati on ati.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido' and (m.prazo_dias is null or coalesce(x.validado_em, x.em) <= ati.entrou_em + make_interval(days => m.prazo_dias))) as no_prazo,
      (select round(avg(extract(epoch from (coalesce(x.validado_em, x.em) - a2.entrou_em)) / 86400)::numeric, 1) from aluno_marcos x join al a2 on a2.id = x.aluno_id where x.marco_id = m.id and x.situacao = 'atingido') as dias_medio,
      (select count(*) from ati where ati.jornada_id = m.jornada_id and m.prazo_dias is not null and ati.entrou_em + make_interval(days => m.prazo_dias) < now()
          and not exists (select 1 from aluno_marcos x where x.aluno_id = ati.id and x.marco_id = m.id and x.situacao = 'atingido')) as atrasados
    from jornada_marcos m join jornadas j on j.id = m.jornada_id
    where m.workspace_id = p_ws and j.status in ('publicada', 'anterior') and (p_produto is null or j.produto_id = p_produto)),
  ck as (select v.* from pesquisa_envios v join al on al.id = v.aluno_id where v.workspace_id = p_ws and v.gerado_em >= ini and v.gerado_em < fim),
  nps as (select i.valor_num as nota from pesquisa_respostas r join pesquisa_envios v on v.id = r.envio_id join al on al.id = v.aluno_id
           join pesquisa_resposta_itens i on i.resposta_id = r.id join pesquisa_perguntas q on q.id = i.pergunta_id and q.papel = 'nps'
          where r.workspace_id = p_ws and r.respondida_em >= ini and r.respondida_em < fim and i.valor_num is not null),
  iv as (select x.* from cs_intervencoes x join al on al.id = x.aluno_id where x.workspace_id = p_ws),
  rec as (select x.pessoa_id, sum(x.valor) as v from revops_receitas(p_ws) x where x.pessoa_id in (select pessoa_id from al) group by x.pessoa_id)
  select jsonb_build_object(
    'periodo', jsonb_build_object('ini', (ini at time zone 'America/Sao_Paulo')::date, 'fim', (fim at time zone 'America/Sao_Paulo')::date - 1),
    'matriculas', jsonb_build_object('ativas', (select count(*) from ati), 'novas', (select count(*) from al where entrou_em >= ini and entrou_em < fim),
      'sairam', (select count(*) from al where saiu_em >= ini and saiu_em < fim), 'sem_cs', (select count(*) from ati where responsavel_cs_id is null),
      'na_jornada_geral', (select count(*) from ati where jornada_id is null)),
    'etapas', coalesce((select jsonb_agg(jsonb_build_object('jornada', et.jornada, 'etapa', et.nome, 'ordem', et.ordem, 'n', (select count(*) from ati where ati.etapa_kanban_id = et.id)) order by et.jornada = 'Jornada geral', et.jornada, et.ordem) from et), '[]'),
    'marcos', coalesce((select jsonb_agg(jsonb_build_object('id', mk.id, 'nome', mk.nome, 'obrigatorio', mk.obrigatorio, 'prazo_dias', mk.prazo_dias, 'elegiveis', mk.elegiveis, 'atingidos', mk.atingidos,
      'aguardando', mk.aguardando, 'atrasados', mk.atrasados, 'pct', case when mk.elegiveis > 0 then round(mk.atingidos * 100.0 / mk.elegiveis, 1) end,
      'no_prazo_pct', case when mk.atingidos > 0 then round(mk.no_prazo * 100.0 / mk.atingidos, 1) end, 'dias_medio', mk.dias_medio) order by mk.nome) from mk), '[]'),
    'checkins', jsonb_build_object('gerados', (select count(*) from ck), 'respondidos', (select count(*) from ck where status = 'respondido'),
      'taxa', case when (select count(*) from ck where status <> 'dispensado') > 0 then round((select count(*) from ck where status = 'respondido') * 100.0 / (select count(*) from ck where status <> 'dispensado'), 1) end),
    'nps', jsonb_build_object('respostas', (select count(*) from nps), 'media', (select round(avg(nota), 1) from nps),
      'nps', case when (select count(*) from nps) > 0 then round(((select count(*) from nps where nota >= 9) - (select count(*) from nps where nota <= 6)) * 100.0 / (select count(*) from nps)) end),
    'alertas', coalesce((select jsonb_object_agg(regra, n) from (select a.regra, count(*) as n from alertas a where a.workspace_id = p_ws and a.tipo = 'cs' and a.resolvido_em is null
       and (p_produto is null or a.dados->>'produto_id' = p_produto::text) group by a.regra) t), '{}'),
    'intervencoes', jsonb_build_object('abertas', (select count(*) from iv where status = 'aberta'), 'atrasadas', (select count(*) from iv where status = 'aberta' and prazo < (now() at time zone 'America/Sao_Paulo')::date),
      'feitas', (select count(*) from iv where status = 'feita' and concluida_em >= ini and concluida_em < fim),
      'resolveu_pct', case when (select count(*) from iv where status = 'feita' and efeito is not null and concluida_em >= ini and concluida_em < fim) > 0 then
        round((select count(*) from iv where status = 'feita' and efeito = 'resolveu' and concluida_em >= ini and concluida_em < fim) * 100.0 / (select count(*) from iv where status = 'feita' and efeito is not null and concluida_em >= ini and concluida_em < fim), 1) end),
    'receita', jsonb_build_object('clientes', (select count(*) from rec), 'por_cliente', (select round(avg(v), 2) from rec), 'total', (select round(sum(v), 2) from rec),
      'regra', 'revops_receitas: vendas aprovadas sem reembolso + parcelas de contrato recebidas (a mesma de Retenção & Expansão)')
  ) into r;
  return r;
end $$;
revoke execute on function public.cg_indicadores(uuid, uuid, date, date) from public, anon;
grant execute on function public.cg_indicadores(uuid, uuid, date, date) to authenticated;

insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao) values
  ('cg_marco_pct', 'Marco atingido (%)', 'Matrículas ativas que atingiram o marco ÷ matrículas ativas na jornada do marco.', 'aluno_marcos + alunos', 'Sem matrícula ativa na jornada: sem valor.', 'Atingido = situação "atingido" (manual confirmado, automático, ou automático confirmado pela equipe).'),
  ('cg_marco_prazo', 'Marco no prazo (%)', 'Atingidos até "prazo em dias" depois da matrícula ÷ atingidos.', 'aluno_marcos + jornada_marcos.prazo_dias', 'Sem marco atingido: sem valor.', null),
  ('cg_checkin_taxa', 'Resposta dos check-ins (%)', 'Check-ins respondidos ÷ check-ins gerados no período (sem os dispensados).', 'pesquisa_envios com aluno_id', 'Sem check-in no período: sem valor.', null),
  ('cg_nps', 'NPS dos alunos', '% de notas 9 e 10 menos % de notas 0 a 6, nas respostas de pesquisas ligadas a matrículas no período.', 'pesquisa_resposta_itens (pergunta de papel nps)', 'Sem resposta: sem valor.', null),
  ('cg_intervencao_resolveu', 'Intervenções que resolveram (%)', 'Intervenções feitas no período com efeito "resolveu" ÷ intervenções feitas com efeito informado.', 'cs_intervencoes', 'Sem intervenção feita com efeito: sem valor.', null)
on conflict (codigo) do update set nome = excluded.nome, formula = excluded.formula, fonte = excluded.fonte, sem_dado = excluded.sem_dado, observacao = excluded.observacao, atualizado_em = now();
do $s$ begin
  if exists (select 1 from information_schema.columns where table_name = 'metricas_definicoes' and column_name = 'unidade') then
    update metricas_definicoes set unidade = case when codigo = 'cg_nps' then 'numero' else 'pct' end, casas = case when codigo = 'cg_nps' then 0 else 1 end, direcao = 'maior'
     where codigo in ('cg_marco_pct', 'cg_marco_prazo', 'cg_checkin_taxa', 'cg_nps', 'cg_intervencao_resolveu');
  end if;
end $s$;

-- Para desfazer: drop function if exists public.cg_indicadores(uuid, uuid, date, date); delete from acesso_telas where tela = 'ho-cg';
-- delete from metricas_definicoes where codigo like 'cg\_%';
