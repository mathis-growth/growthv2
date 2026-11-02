-- v0.219 — Growth's Brain: visão AARRR (funil pirata) montada só com o que o Growths já calcula.
--
-- aarrr_painel(ws, ini, fim, hoje): para o período e o anterior do mesmo tamanho, as etapas do Diagnóstico (mesmos nomes de AARRR):
--   aquisição   → leads captados, investimento em mídia, CPL
--   ativação    → clientes novos (1ª compra no período), conversão lead → cliente novo, marcos obrigatórios atingidos (CS)
--   retenção    → alunos ativos, saíram, saída (saíram ÷ (ativos + saíram)) (CS)
--   receita     → faturamento, vendas, ticket médio
--   recomendação→ NPS e respostas (CS); indicação ainda não é medida (aparece "sem dado")
--   recompra    → clientes que compraram de novo e a parte do faturamento que veio deles
-- Cada métrica: valor, período anterior, direção (sobe/desce é bom), fonte e "sem dado" quando o Growths não tem a informação.
-- Metas do registro central entram onde existem (leads na aquisição; faturamento e vendas na receita), com o status do Cockpit.
-- "Gargalo sugerido": a taxa que mais piorou contra o período anterior (pista calculada por regra, não diagnóstico).
-- A North Star aparece na etapa que ela mede. O funil não é tratado como linear: só leads → cliente novo é mostrado como passagem.
-- Só leitura. Depende do RODAR_v0.218. Os números de CS só aparecem se o Customer Growth estiver no banco (cg_indicadores). Pode rodar de novo sem erro.

create or replace function public.aarrr_numeros(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare leads int; inv numeric; novos int; vend int; fat numeric; recomp int; fat_rec numeric; cg jsonb; marc numeric; at int; sa int;
begin
  select count(*) into leads from pessoas where workspace_id = p_ws and coalesce(captada, true) and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select coalesce(sum(custo), 0) into inv from metricas_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim;
  select count(*), coalesce(sum(valor), 0) into vend, fat from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between p_ini and p_fim;
  with pr as (select pessoa_id, min(dia) d0 from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and pessoa_id is not null group by pessoa_id)
  select count(*) filter (where d0 between p_ini and p_fim) into novos from pr;
  with pr as (select pessoa_id, min(dia) d0 from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and pessoa_id is not null group by pessoa_id),
       pe as (select v.pessoa_id, sum(v.valor) s from v_vendas_todas v join pr on pr.pessoa_id = v.pessoa_id
               where v.workspace_id = p_ws and v.status = 'aprovada' and v.dia between p_ini and p_fim and pr.d0 < p_ini group by v.pessoa_id)
  select count(*), coalesce(sum(s), 0) into recomp, fat_rec from pe;
  if to_regprocedure('public.cg_indicadores(uuid, uuid, date, date)') is not null then
    begin execute 'select public.cg_indicadores($1, null, $2, $3)' into cg using p_ws, p_ini, p_fim; exception when others then cg := null; end;
  end if;
  if cg is not null then
    select round(sum((m->>'atingidos')::numeric) * 100 / nullif(sum((m->>'elegiveis')::numeric), 0), 1) into marc
      from jsonb_array_elements(coalesce(cg->'marcos', '[]'::jsonb)) m where coalesce((m->>'obrigatorio')::boolean, false);
    at := (cg #>> '{matriculas,ativas}')::int; sa := (cg #>> '{matriculas,sairam}')::int;
  end if;
  return jsonb_build_object('leads', leads, 'investimento', inv, 'cpl', case when leads > 0 and inv > 0 then round(inv / leads, 2) end,
    'novos', novos, 'conv_lead_cliente', case when leads > 0 then round(novos * 100.0 / leads, 2) end, 'marcos_pct', marc,
    'ativos', at, 'sairam', sa, 'saida_pct', case when coalesce(at, 0) + coalesce(sa, 0) > 0 then round(sa * 100.0 / (at + sa), 2) end,
    'faturamento', fat, 'vendas', vend, 'ticket', case when vend > 0 then round(fat / vend, 2) end,
    'nps', (cg #>> '{nps,nps}')::numeric, 'nps_respostas', (cg #>> '{nps,respostas}')::int,
    'recompra_clientes', recomp, 'recompra_pct_fat', case when fat > 0 then round(fat_rec * 100 / fat, 2) end, 'tem_cs', cg is not null);
end $$;
revoke all on function public.aarrr_numeros(uuid, date, date) from public, anon, authenticated;

create or replace function public.aarrr_painel(p_ws uuid, p_ini date, p_fim date, p_hoje date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a jsonb; b jsonb; a0 date := p_ini - (p_fim - p_ini + 1); a1 date := p_ini - 1; ate date := least(p_fim, p_hoje);
  m jsonb; etapas jsonb; met jsonb := '{}'::jsonb; ns record; gar jsonb; k text;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 400 then raise exception 'Período inválido (até 400 dias)'; end if;
  -- o período atual conta até hoje; o anterior tem o mesmo tamanho
  a := aarrr_numeros(p_ws, p_ini, ate); b := aarrr_numeros(p_ws, a0, a1);
  perform set_config('growths.metas_interno', '1', true);
  foreach k in array array['leads', 'vendas', 'faturamento'] loop
    m := metas_avaliar(p_ws, k, p_ini, p_fim, p_hoje);
    if m->>'meta' is not null then met := met || jsonb_build_object(k, m); end if;
  end loop;
  -- métrica: [codigo, nome, unidade, direcao(sobe|desce|neutra), taxa?]
  etapas := jsonb_build_array(
    jsonb_build_object('k', 'aquisicao', 'nome', 'Aquisição', 'pergunta', 'Quanta gente nova chega?', 'metricas', jsonb_build_array(
      jsonb_build_array('leads', 'Leads captados', 'num', 'sobe', false), jsonb_build_array('investimento', 'Investimento em mídia', 'brl', 'neutra', false),
      jsonb_build_array('cpl', 'Custo por lead', 'brl', 'desce', true))),
    jsonb_build_object('k', 'ativacao', 'nome', 'Ativação', 'pergunta', 'Quantos viram cliente e chegam ao primeiro resultado?', 'metricas', jsonb_build_array(
      jsonb_build_array('novos', 'Clientes novos (1ª compra)', 'num', 'sobe', false), jsonb_build_array('conv_lead_cliente', 'Lead → cliente novo', 'pct', 'sobe', true),
      jsonb_build_array('marcos_pct', 'Marcos obrigatórios atingidos', 'pct', 'sobe', true))),
    jsonb_build_object('k', 'retencao', 'nome', 'Retenção', 'pergunta', 'Quantos ficam?', 'metricas', jsonb_build_array(
      jsonb_build_array('ativos', 'Alunos ativos', 'num', 'sobe', false), jsonb_build_array('sairam', 'Saíram no período', 'num', 'desce', false),
      jsonb_build_array('saida_pct', 'Saída (saíram ÷ ativos + saíram)', 'pct', 'desce', true))),
    jsonb_build_object('k', 'receita', 'nome', 'Receita', 'pergunta', 'Quanto entra?', 'metricas', jsonb_build_array(
      jsonb_build_array('faturamento', 'Faturamento', 'brl', 'sobe', false), jsonb_build_array('vendas', 'Vendas', 'num', 'sobe', false),
      jsonb_build_array('ticket', 'Ticket médio', 'brl', 'sobe', true))),
    jsonb_build_object('k', 'recomendacao', 'nome', 'Recomendação', 'pergunta', 'Quantos indicariam?', 'metricas', jsonb_build_array(
      jsonb_build_array('nps', 'NPS dos alunos', 'num', 'sobe', true), jsonb_build_array('nps_respostas', 'Respostas de NPS', 'num', 'neutra', false),
      jsonb_build_array('indicacoes', 'Indicações', 'num', 'sobe', false))),
    jsonb_build_object('k', 'recompra', 'nome', 'Recompra e ascensão', 'pergunta', 'Quantos compram de novo?', 'metricas', jsonb_build_array(
      jsonb_build_array('recompra_clientes', 'Clientes que compraram de novo', 'num', 'sobe', false), jsonb_build_array('recompra_pct_fat', 'Parte do faturamento vinda deles', 'pct', 'sobe', true))));
  -- monta os valores
  select jsonb_agg(e || jsonb_build_object('metricas', (
           select jsonb_agg(jsonb_build_object('codigo', x->>0, 'nome', x->>1, 'unidade', x->>2, 'direcao', x->>3, 'taxa', (x->>4)::boolean,
             'v', a->(x->>0), 'v_ant', b->(x->>0),
             'var', case when (a->>(x->>0)) is not null and (b->>(x->>0)) is not null and (b->>(x->>0))::numeric <> 0
                         then round(((a->>(x->>0))::numeric - (b->>(x->>0))::numeric) / abs((b->>(x->>0))::numeric), 4) end,
             'meta', met->(x->>0),
             'sem_dado', case when x->>0 = 'indicacoes' then 'O Growths ainda não registra indicações.'
                              when x->>0 in ('marcos_pct', 'ativos', 'sairam', 'saida_pct', 'nps', 'nps_respostas') and not coalesce((a->>'tem_cs')::boolean, false) then 'Precisa do Customer Growth (acompanhamento de alunos).'
                              when a->>(x->>0) is null then 'Sem dado no período.' end))
           from jsonb_array_elements(e->'metricas') x)) order by ord)
    into etapas from jsonb_array_elements(etapas) with ordinality t(e, ord);
  -- gargalo sugerido: a taxa que mais piorou (mais de 5%) contra o período anterior
  select jsonb_build_object('etapa', e->>'k', 'etapa_nome', e->>'nome', 'metrica', mm->>'nome', 'var', (mm->>'var')::numeric,
         'texto', (mm->>'nome') || ' ' || case when mm->>'direcao' = 'desce' then 'subiu' else 'caiu' end || ' ' || round(abs((mm->>'var')::numeric) * 100) || '% contra o período anterior.')
    into gar
    from jsonb_array_elements(etapas) e, jsonb_array_elements(e->'metricas') mm
   where (mm->>'taxa')::boolean and mm->>'var' is not null and mm->>'direcao' in ('sobe', 'desce')
     and (case when mm->>'direcao' = 'desce' then (mm->>'var')::numeric else -(mm->>'var')::numeric end) > 0.05
   order by case when mm->>'direcao' = 'desce' then (mm->>'var')::numeric else -(mm->>'var')::numeric end desc limit 1;
  select g.nome, g.nsm_status, g.chave_auto, g.meta into ns from growth_metricas g where g.workspace_id = p_ws and g.tipo = 'north_star' order by g.criado_em limit 1;
  return jsonb_build_object('ini', p_ini, 'fim', p_fim, 'ate', ate, 'ini_ant', a0, 'fim_ant', a1, 'etapas', etapas, 'gargalo', gar,
    'passagem', jsonb_build_object('de', 'Leads', 'para', 'Clientes novos', 'taxa', a->'conv_lead_cliente', 'taxa_ant', b->'conv_lead_cliente'),
    'nsm', case when ns.nome is not null then jsonb_build_object('nome', ns.nome, 'status', ns.nsm_status, 'meta', ns.meta,
      'etapa', case ns.chave_auto when 'leads' then 'aquisicao' when 'cpl' then 'aquisicao' when 'investimento' then 'aquisicao' when 'conv' then 'ativacao'
                                  when 'clientes_ativos' then 'retencao' when 'receita' then 'receita' when 'vendas' then 'receita' when 'ticket' then 'receita' else null end) end,
    'tem_cs', a->'tem_cs');
end $$;
revoke all on function public.aarrr_painel(uuid, date, date, date) from public, anon;
grant execute on function public.aarrr_painel(uuid, date, date, date) to authenticated;

notify pgrst, 'reload schema';
