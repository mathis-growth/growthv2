-- v0.224 — Growth's Brain, Diagnóstico Inteligente D2 (parte 1): o pré-diagnóstico, antes da reunião.
-- Pedido da Rebecka (02/11): "o cliente sobe os arquivos e, na investigação, já valida o que tem, o que não tem, faz um diagnóstico
-- para depois ir para a reunião".
-- Aditivo e idempotente. Rode depois de 20261216100000_diagnostico_d1_evidencias.sql.
--  1. diagnostico_checklist(diag): para cada grupo de arquivos que o diagnóstico precisa (os grupos do próprio formulário do cliente,
--     ou os padrão quando não há formulário), cruza o que o cliente disse (tenho / em parte / mando depois / não tenho) com o que
--     chegou nas evidências, e quantos meses do período de referência os arquivos cobrem. Também resume os números que o cliente
--     disse que acompanha e os que não acompanha.
--  2. diagnostico_progresso ganha a etapa "Pré-diagnóstico revisado" (diagnosticos.arquitetura -> 'pre' -> 'revisado_em').

-- grupo do checklist de um arquivo: o grupo em que o cliente mandou; para os da equipe, pela classificação
create or replace function public.diag_grupo_arquivo(p_grupo text, p_classe text, p_nome text) returns text language sql immutable as $$
  select case
    when p_grupo is not null and p_grupo <> 'equipe' then p_grupo
    when p_classe = 'vendas' and p_nome ~* '(lead|crm|captac|inscri)' then 'crm'
    when p_classe = 'vendas' then 'vendas'
    when p_classe = 'marketing' and p_nome ~* '(lead|crm|captac|inscri)' then 'crm'
    when p_classe = 'marketing' then 'marketing'
    when p_classe = 'cs' then 'alunos'
    when p_classe = 'financeiro' then 'financeiro'
    when p_classe in ('produto', 'oferta') then 'produtos'
    when p_classe is null then null
    else 'complementares' end
$$;

create or replace function public.diagnostico_checklist(p_diag uuid, p_hoje date default current_date) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare d diagnosticos; v_cats jsonb; v_docr jsonb := '{}'; v_met jsonb := '{}'; v_ini date; v_fim date; v_meses int; v_itens jsonb := '[]'; c jsonb; k text;
  v_arqs jsonb; n int; n_sem int; v_cob int; v_decl text; v_st text; v_acomp jsonb; v_nao jsonb;
begin
  select * into d from diagnosticos where id = p_diag;
  if not found then return null; end if;
  -- os grupos do formulário que o cliente respondeu (com o que ele disse); sem formulário, os grupos padrão
  if d.resposta_id is not null then
    select pp.config -> 'categorias', i.valor_json into v_cats, v_docr from pesquisa_perguntas pp
      left join pesquisa_resposta_itens i on i.pergunta_id = pp.id and i.resposta_id = d.resposta_id
      where pp.pesquisa_id = d.pesquisa_id and pp.tipo = 'documentos' order by pp.ordem limit 1;
    select i.valor_json into v_met from pesquisa_perguntas pp join pesquisa_resposta_itens i on i.pergunta_id = pp.id and i.resposta_id = d.resposta_id
      where pp.pesquisa_id = d.pesquisa_id and pp.tipo = 'metricas' order by pp.ordem limit 1;
  end if;
  v_docr := coalesce(v_docr, '{}'); v_met := coalesce(v_met, '{}');
  if v_cats is null or jsonb_typeof(v_cats) <> 'array' or jsonb_array_length(v_cats) = 0 then
    v_cats := '[{"k":"vendas","l":"Vendas e pedidos"},{"k":"crm","l":"CRM e leads"},{"k":"alunos","l":"Alunos e clientes"},{"k":"marketing","l":"Marketing e aquisição"},
      {"k":"financeiro","l":"Financeiro"},{"k":"produtos","l":"Produtos e ofertas"},{"k":"complementares","l":"Arquivos complementares"}]';
  end if;
  -- período de referência: o do diagnóstico; sem ele, os últimos 6 meses completos
  v_fim := coalesce(d.periodo_fim, (date_trunc('month', p_hoje) - interval '1 day')::date);
  v_ini := coalesce(d.periodo_ini, (date_trunc('month', v_fim) - interval '5 months')::date);
  v_meses := (extract(year from age(date_trunc('month', v_fim), date_trunc('month', v_ini))) * 12 + extract(month from age(date_trunc('month', v_fim), date_trunc('month', v_ini))))::int + 1;
  for c in select value from jsonb_array_elements(v_cats) loop
    k := c ->> 'k';
    select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'nome', a.nome, 'periodo_ini', a.periodo_ini, 'periodo_fim', a.periodo_fim, 'processamento', a.processamento, 'origem', a.origem) order by a.enviado_em), '[]'),
      count(*), count(*) filter (where a.periodo_ini is null or a.periodo_fim is null)
      into v_arqs, n, n_sem from pesquisa_arquivos a
      where a.diagnostico_id = p_diag and a.status = 'enviado' and a.arquivado_em is null and diag_grupo_arquivo(a.grupo, a.classe, a.nome) = k;
    v_decl := v_docr ->> k;
    -- grupo condicional do formulário (ex.: vendas de uma plataforma) que o cliente nem viu: fica de fora
    if c ? 'se' and v_decl is null and n = 0 then continue; end if;
    select count(*) into v_cob from generate_series(date_trunc('month', v_ini), date_trunc('month', v_fim), interval '1 month') m
      where exists (select 1 from pesquisa_arquivos a where a.diagnostico_id = p_diag and a.status = 'enviado' and a.arquivado_em is null
        and diag_grupo_arquivo(a.grupo, a.classe, a.nome) = k and a.periodo_ini <= (m + interval '1 month - 1 day')::date and a.periodo_fim >= m::date);
    v_st := case when n > 0 and n_sem = 0 and v_cob < v_meses then 'parcial'
      when n > 0 then 'recebido'
      when v_decl in ('sim', 'parte', 'depois') then 'prometido'
      when v_decl = 'nao' then 'nao_tem'
      when k = 'complementares' then 'opcional'
      else 'falta' end;
    v_itens := v_itens || jsonb_build_object('k', k, 'rot', coalesce(c ->> 'l', k), 'descricao', c ->> 'd', 'status', v_st, 'declarado', v_decl, 'arquivos', v_arqs,
      'n', n, 'sem_periodo', n_sem, 'meses_cobertos', v_cob, 'meses_ref', v_meses);
  end loop;
  -- números: o que o cliente disse que acompanha
  select jsonb_agg(jsonb_build_object('codigo', e.key, 'nome', coalesce(md.nome, e.key)) order by md.ordem) filter (where e.value ->> 'status' in ('regular', 'ocasional')),
         jsonb_agg(jsonb_build_object('codigo', e.key, 'nome', coalesce(md.nome, e.key)) order by md.ordem) filter (where e.value ->> 'status' = 'nao')
    into v_acomp, v_nao
    from jsonb_each(case when jsonb_typeof(v_met) = 'object' then v_met else '{}' end) e left join metricas_definicoes md on md.codigo = e.key
    where jsonb_typeof(e.value) = 'object';
  return jsonb_build_object('itens', v_itens, 'ref_ini', v_ini, 'ref_fim', v_fim, 'meses_ref', v_meses, 'formulario', d.resposta_id is not null,
    'resumo', jsonb_build_object(
      'recebidos', (select count(*) from jsonb_array_elements(v_itens) x where x ->> 'status' = 'recebido'),
      'parciais', (select count(*) from jsonb_array_elements(v_itens) x where x ->> 'status' = 'parcial'),
      'prometidos', (select count(*) from jsonb_array_elements(v_itens) x where x ->> 'status' = 'prometido'),
      'nao_tem', (select count(*) from jsonb_array_elements(v_itens) x where x ->> 'status' = 'nao_tem'),
      'faltam', (select count(*) from jsonb_array_elements(v_itens) x where x ->> 'status' = 'falta')),
    'numeros', jsonb_build_object('acompanha', coalesce(v_acomp, '[]'), 'nao_acompanha', coalesce(v_nao, '[]')),
    'pre', d.arquitetura -> 'pre');
end $$;
revoke all on function public.diagnostico_checklist(uuid, date) from public, anon;
grant execute on function public.diagnostico_checklist(uuid, date) to authenticated;

-- progresso: entra a etapa do pré-diagnóstico
create or replace function public.diagnostico_progresso(p_diag uuid) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare d diagnosticos; n_arq int; n_cls int; n_pla int; n_pla_lido int; n_nsm int; e jsonb;
begin
  select * into d from diagnosticos where id = p_diag;
  if not found then return null; end if;
  select count(*), count(classe), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$'), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$' and processamento = 'lido')
    into n_arq, n_cls, n_pla, n_pla_lido from pesquisa_arquivos where diagnostico_id = p_diag and status = 'enviado' and arquivado_em is null;
  select count(*) into n_nsm from growth_metricas where workspace_id = d.workspace_id and tipo = 'north_star';
  e := jsonb_build_array(
    jsonb_build_object('k', 'evidencias', 'rot', 'Evidências recebidas', 'ok', n_arq > 0, 'det', n_arq || ' arquivo(s)'),
    jsonb_build_object('k', 'classificacao', 'rot', 'Evidências classificadas', 'ok', n_arq > 0 and n_cls = n_arq, 'det', n_cls || ' de ' || n_arq),
    jsonb_build_object('k', 'formulario', 'rot', 'Formulário do cliente respondido', 'ok', d.resposta_id is not null, 'det', case when d.resposta_id is null then 'sem formulário ligado' else 'respondido' end),
    jsonb_build_object('k', 'dados', 'rot', 'Planilhas lidas', 'ok', d.leitura is not null or (n_pla > 0 and n_pla_lido = n_pla), 'det', case when n_pla = 0 then 'nenhuma planilha' else n_pla_lido || ' de ' || n_pla end),
    jsonb_build_object('k', 'pre', 'rot', 'Pré-diagnóstico revisado', 'ok', d.arquitetura -> 'pre' ->> 'revisado_em' is not null, 'det', case when d.arquitetura -> 'pre' ->> 'revisado_em' is null then 'antes da reunião' else 'pronto para a reunião' end),
    jsonb_build_object('k', 'numeros', 'rot', 'Números que decidem', 'ok', coalesce(array_length(d.decide, 1), 0) > 0, 'det', coalesce(array_length(d.decide, 1), 0) || ' marcado(s) na reunião'),
    jsonb_build_object('k', 'nsm', 'rot', 'North Star definida', 'ok', n_nsm > 0, 'det', case when n_nsm = 0 then 'sem North Star' else n_nsm || ' na árvore' end),
    jsonb_build_object('k', 'validado', 'rot', 'Diagnóstico validado', 'ok', d.status = 'validado', 'det', ('{"rascunho":"em coleta","em_analise":"em análise","em_revisao":"em revisão","validado":"validado","arquivado":"arquivado"}'::jsonb ->> d.status)));
  return jsonb_build_object('etapas', e, 'feitas', (select count(*) from jsonb_array_elements(e) x where (x ->> 'ok')::boolean), 'total', jsonb_array_length(e),
    'pct', round(100.0 * (select count(*) from jsonb_array_elements(e) x where (x ->> 'ok')::boolean) / jsonb_array_length(e)));
end $$;

-- Para desfazer: drop function diagnostico_checklist(uuid, date), diag_grupo_arquivo(text, text, text);
-- e rodar de novo a diagnostico_progresso da migração 20261216100000.
