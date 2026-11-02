-- v0.225 — Diagnóstico Inteligente: de-para das métricas (o que o cliente usa × o que os dados permitem calcular).
-- Pedido da Rebecka (02/11): ver todas as métricas que a pessoa usa hoje, o que olha e o que não olha, quais dados tem ou não tem,
-- e fazer o de-para: das que usa, entender como calcula; das que não usa, saber se os dados que ela mandou permitem calcular.
-- Aditivo e idempotente. Rode depois de 20261217100000_diagnostico_d2_pre.sql.
--  1. metricas_definicoes.requisitos: o que cada métrica do catálogo precisa para ser calculada.
--     g:<grupo>  arquivo do grupo (vendas, crm, marketing, alunos, financeiro, produtos)
--     l:<item>   item da leitura das planilhas (vendas, cliente, produto, status, recorrencia, leads, origemvenda, midia, topo, qualificacao)
--     c:<texto>  coluna que precisa ser confirmada no arquivo (no máximo "com ressalvas")
--     x:<texto>  fonte que não vem nos arquivos pedidos (área de membros, pesquisa, redes, plataforma)
--  2. diagnostico_depara(diag, hoje): para cada métrica do catálogo, o uso (principal, acompanha, não acompanha, não sei, não perguntado),
--     onde vê, se o cálculo já foi descrito na reunião, e se os dados recebidos permitem calcular (sim, com ressalvas, não, fonte fora
--     dos arquivos), com o que falta. Classifica em: usa, oportunidade (dá para calcular e hoje não olha) e lacuna.

alter table metricas_definicoes add column if not exists requisitos jsonb;
update metricas_definicoes m set requisitos = r.req::jsonb from (values
  ('investimento', '["g:marketing","l:midia"]'), ('impressoes', '["g:marketing","l:topo"]'), ('ctr', '["g:marketing","l:topo"]'), ('cpc', '["g:marketing","l:topo"]'),
  ('leads', '["g:crm","l:leads"]'), ('leads_canal', '["g:crm","l:leads","c:origem (canal ou UTM) de cada lead"]'), ('cpl', '["g:marketing","g:crm","l:midia","l:leads"]'),
  ('cpl_qualificado', '["g:marketing","g:crm","l:midia","l:qualificacao"]'), ('conv_captura', '["g:crm","x:visitas da página de captura (analytics)"]'),
  ('cac_midia', '["g:marketing","g:vendas","l:midia","l:cliente","l:origemvenda"]'), ('cac', '["g:marketing","g:vendas","g:financeiro","l:midia","l:cliente"]'),
  ('roas', '["g:marketing","g:vendas","l:midia","l:vendas"]'), ('roi', '["g:marketing","g:vendas","l:midia","l:vendas"]'), ('organico', '["x:redes sociais e leads com origem orgânica"]'),
  ('taxa_qualificacao', '["g:crm","l:qualificacao"]'), ('conv_lead_venda', '["g:crm","g:vendas","l:leads","l:cliente"]'), ('comparecimento', '["x:plataforma do evento ou agenda"]'),
  ('tempo_compra', '["g:crm","g:vendas","l:leads","l:cliente"]'), ('primeiro_acesso', '["g:alunos","c:data do primeiro acesso dos alunos"]'),
  ('onboarding_concluido', '["g:alunos","c:conclusão do onboarding"]'), ('ativacao', '["g:alunos","c:evento de primeiro valor"]'), ('ttv', '["g:vendas","g:alunos","c:data do primeiro valor"]'),
  ('churn', '["g:alunos","c:situação de cada aluno (ativo, cancelado)"]'), ('retencao_coorte', '["g:vendas","l:cliente"]'), ('consumo_progresso', '["g:alunos","c:progresso no produto"]'),
  ('conclusao', '["g:alunos","c:conclusão do produto"]'), ('frequencia_uso', '["x:acessos da área de membros, app ou comunidade"]'), ('alunos_risco', '["g:alunos","c:sinais de risco (parado, sem resposta)"]'),
  ('receita', '["g:vendas","l:vendas"]'), ('ticket_medio', '["g:vendas","l:vendas"]'), ('conv_vendas', '["g:crm","g:vendas","l:cliente"]'), ('aceite_oferta', '["g:vendas","l:produto"]'),
  ('cliente', '["g:vendas","l:cliente"]'), ('mrr', '["g:vendas","l:recorrencia"]'), ('arr', '["g:vendas","l:recorrencia"]'), ('receita_novos_base', '["g:vendas","l:cliente"]'),
  ('ltv', '["g:vendas","l:cliente"]'), ('ltv_cac', '["g:vendas","g:marketing","l:cliente","l:midia"]'), ('payback_cac', '["g:vendas","g:marketing","g:financeiro","l:cliente"]'),
  ('reembolso', '["g:vendas","l:status"]'), ('expansao', '["g:vendas","l:cliente","l:recorrencia"]'), ('nrr', '["g:vendas","l:recorrencia"]'),
  ('margem', '["g:vendas","g:financeiro"]'), ('lucro', '["g:vendas","g:financeiro"]'), ('recuperacao_checkout', '["x:abandonos de checkout (plataforma de venda)"]'),
  ('indicacoes', '["g:crm","c:origem \"indicação\" nos leads"]'), ('taxa_indicacao', '["x:programa de indicação"]'), ('receita_indicacao', '["g:vendas","l:origemvenda","c:origem \"indicação\" nas vendas"]'),
  ('depoimentos', '["x:coleta de depoimentos"]'), ('promotores', '["x:pesquisa de NPS"]'), ('recompra', '["g:vendas","l:cliente"]'),
  ('ascensao', '["g:vendas","l:cliente","l:produto"]'), ('tempo_segunda_compra', '["g:vendas","l:cliente"]')
) r(cod, req) where m.codigo = r.cod and m.requisitos is distinct from r.req::jsonb;

-- o que o formulário "Entrada do cliente" chama de cada número (pergunta de múltipla escolha) → código do catálogo
create or replace function public.diag_metrica_rotulo(p_rot text) returns text language sql immutable as $$
  select case p_rot when 'Faturamento' then 'receita' when 'Ticket médio' then 'ticket_medio' when 'Investimento em anúncios' then 'investimento' when 'Leads' then 'leads'
    when 'Custo por lead (CPL)' then 'cpl' when 'Conversão de lead em venda' then 'conv_lead_venda' when 'Custo de aquisição (CAC)' then 'cac' when 'Retorno sobre anúncios (ROAS)' then 'roas'
    when 'Comparecimento nas aulas ou lives' then 'comparecimento' when 'Conversão do checkout' then 'conv_vendas' when 'Abandono de checkout' then 'recuperacao_checkout'
    when 'Reembolsos' then 'reembolso' when 'Cancelamentos (churn)' then 'churn' when 'Recompra' then 'recompra' when 'Valor do cliente no tempo (LTV)' then 'ltv'
    when 'NPS ou satisfação' then 'promotores' when 'Receita recorrente (MRR)' then 'mrr' when 'Margem ou lucro' then 'margem' end
$$;

create or replace function public.diagnostico_depara(p_diag uuid, p_hoje date default current_date) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare d diagnosticos; ck jsonb; v_met jsonb := '{}'; v_mult text[] := '{}'; v_princ text[] := '{}'; v_tem_perg boolean := false; v_le jsonb; v_lido boolean;
  g jsonb := '{}'; r record; req text; tp text; val text; st text; v_falta jsonb; v_ress jsonb; v_ext jsonb; v_dados text; v_uso text; v_cat text; v_calc boolean;
  v_det jsonb; v_lista jsonb := '[]'; li jsonb; k text;
  ROT_G jsonb := '{"vendas":"planilha de vendas","crm":"planilha de leads","marketing":"investimento em anúncios","alunos":"lista de alunos ou clientes","financeiro":"custos ou financeiro","produtos":"produtos e ofertas"}';
  ROT_L jsonb := '{"vendas":"vendas com data e valor","cliente":"identificação do comprador nas vendas","produto":"produto em cada venda","status":"status do pagamento","recorrencia":"recompra, renovação e upgrade","leads":"leads com data e origem","origemvenda":"origem de cada venda","midia":"investimento por mês e canal","topo":"impressões, cliques e visitas","qualificacao":"qualificação dos leads"}';
begin
  select * into d from diagnosticos where id = p_diag;
  if not found then return null; end if;
  ck := diagnostico_checklist(p_diag, p_hoje);
  -- situação de cada grupo (as vendas por plataforma contam como vendas)
  for li in select value from jsonb_array_elements(ck -> 'itens') loop
    k := case when li ->> 'k' like 'vendas_%' then 'vendas' else li ->> 'k' end;
    st := li ->> 'status';
    if st in ('recebido', 'parcial') and coalesce(g ->> k, '') <> 'recebido' then g := g || jsonb_build_object(k, st); end if;
  end loop;
  -- a leitura das planilhas (item por id; leituras antigas, pelo título)
  v_le := '{}'; v_lido := d.leitura is not null;
  if v_lido then
    select coalesce(jsonb_object_agg(coalesce(x ->> 'id', case
        when x ->> 'titulo' like 'Vendas com%' then 'vendas' when x ->> 'titulo' like 'Identificação do comprador%' then 'cliente' when x ->> 'titulo' like 'Produto em cada%' then 'produto'
        when x ->> 'titulo' like 'Status do pagamento%' then 'status' when x ->> 'titulo' like 'Recompra%' then 'recorrencia' when x ->> 'titulo' like 'Leads com%' then 'leads'
        when x ->> 'titulo' like 'Origem de cada venda%' then 'origemvenda' when x ->> 'titulo' like 'Investimento em mídia%' then 'midia' when x ->> 'titulo' like 'Topo do funil%' then 'topo'
        when x ->> 'titulo' like 'Qualificação%' then 'qualificacao' else x ->> 'titulo' end), x ->> 'status'), '{}') into v_le
      from jsonb_array_elements(coalesce(d.leitura -> 'itens', '[]')) x;
  end if;
  -- o que o cliente disse: pergunta de métricas (formulário 360°) e múltipla escolha (Entrada do cliente)
  if d.resposta_id is not null then
    select i.valor_json into v_met from pesquisa_perguntas pp join pesquisa_resposta_itens i on i.pergunta_id = pp.id and i.resposta_id = d.resposta_id
      where pp.pesquisa_id = d.pesquisa_id and pp.tipo = 'metricas' order by pp.ordem limit 1;
    select coalesce(array_agg(diag_metrica_rotulo(i.valor_texto)) filter (where diag_metrica_rotulo(i.valor_texto) is not null), '{}') into v_mult
      from pesquisa_perguntas pp join pesquisa_resposta_itens i on i.pergunta_id = pp.id and i.resposta_id = d.resposta_id
      where pp.pesquisa_id = d.pesquisa_id and pp.tipo = 'multipla' and pp.texto like 'Quais números você acompanha hoje%';
    select coalesce(array_agg(diag_metrica_rotulo(i.valor_texto)) filter (where diag_metrica_rotulo(i.valor_texto) is not null), '{}') into v_princ
      from pesquisa_perguntas pp join pesquisa_resposta_itens i on i.pergunta_id = pp.id and i.resposta_id = d.resposta_id
      where pp.pesquisa_id = d.pesquisa_id and pp.tipo = 'multipla' and pp.texto like 'Desses, quais são os principais%';
    select exists (select 1 from pesquisa_perguntas pp where pp.pesquisa_id = d.pesquisa_id and (pp.tipo = 'metricas' or (pp.tipo = 'multipla' and pp.texto like 'Quais números você acompanha hoje%'))) into v_tem_perg;
  end if;
  v_met := case when jsonb_typeof(v_met) = 'object' then v_met else '{}' end;
  for r in select md.codigo, md.nome, md.etapa_aarrr, md.formula, md.ordem, md.modelos, coalesce(md.requisitos, '[]') reqs, dm.detalhe, dm.observacao
      from metricas_definicoes md left join diagnostico_metricas dm on dm.diagnostico_id = p_diag and dm.codigo = md.codigo
      where md.etapa_aarrr is not null order by md.ordem loop
    -- uso
    v_uso := case
      when r.codigo = any (d.decide) or coalesce((v_met -> r.codigo ->> 'decide')::boolean, false) or r.codigo = any (v_princ) then 'principal'
      when v_met -> r.codigo ->> 'status' in ('regular', 'ocasional') or r.codigo = any (v_mult) then 'acompanha'
      when v_met -> r.codigo ->> 'status' = 'nao' then 'nao'
      when v_met -> r.codigo ->> 'status' = 'nao_sei' then 'nao_sei'
      when v_tem_perg and cardinality(v_mult) > 0 then 'nao'
      else null end;
    v_calc := coalesce(nullif(r.detalhe ->> 'numerador', '') is not null or nullif(r.detalhe ->> 'fonte', '') is not null or nullif(r.detalhe ->> 'decisao', '') is not null, false);
    -- dados
    v_falta := '[]'; v_ress := '[]'; v_ext := '[]';
    for req in select jsonb_array_elements_text(r.reqs) loop
      tp := split_part(req, ':', 1); val := substr(req, length(tp) + 2);
      if tp = 'g' then
        if g ->> val is null then v_falta := v_falta || to_jsonb(coalesce(ROT_G ->> val, val));
        elsif g ->> val = 'parcial' then v_ress := v_ress || to_jsonb(coalesce(ROT_G ->> val, val) || ' não cobre o período todo'); end if;
      elsif tp = 'l' then
        if v_lido then
          st := v_le ->> val;
          if st = 'falta' then v_falta := v_falta || to_jsonb(coalesce(ROT_L ->> val, val));
          elsif st = 'parcial' then v_ress := v_ress || to_jsonb(coalesce(ROT_L ->> val, val) || ' em parte'); end if;
        else v_ress := v_ress || to_jsonb('confirmar ' || coalesce(ROT_L ->> val, val) || ' na leitura'); end if;
      elsif tp = 'c' then v_ress := v_ress || to_jsonb('confirmar ' || val);
      elsif tp = 'x' then v_ext := v_ext || to_jsonb(val); end if;
    end loop;
    v_dados := case when jsonb_array_length(r.reqs) = 0 then 'sem_regra'
      when jsonb_array_length(v_ext) > 0 and jsonb_array_length(v_ext) = jsonb_array_length(r.reqs) then 'externo'
      when jsonb_array_length(v_falta) > 0 or jsonb_array_length(v_ext) > 0 then 'nao'
      when jsonb_array_length(v_ress) > 0 then 'ressalvas' else 'sim' end;
    v_cat := case when v_uso in ('principal', 'acompanha') then 'usa'
      when v_dados in ('sim', 'ressalvas') then 'oportunidade' else 'lacuna' end;
    v_lista := v_lista || jsonb_build_object('codigo', r.codigo, 'nome', r.nome, 'etapa', r.etapa_aarrr, 'formula', r.formula, 'modelos', r.modelos,
      'uso', v_uso, 'onde', v_met -> r.codigo -> 'como', 'calculo_descrito', v_calc, 'observacao', r.observacao,
      'dados', v_dados, 'falta', v_falta, 'ressalvas', v_ress, 'externo', v_ext, 'categoria', v_cat);
  end loop;
  return jsonb_build_object('metricas', v_lista, 'formulario', d.resposta_id is not null, 'perguntou', v_tem_perg, 'leitura', v_lido,
    'resumo', jsonb_build_object(
      'usa', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'categoria' = 'usa'),
      'principais', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'uso' = 'principal'),
      'sem_calculo', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'categoria' = 'usa' and not (x ->> 'calculo_descrito')::boolean),
      'oportunidades', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'categoria' = 'oportunidade'),
      'lacunas', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'categoria' = 'lacuna'),
      'usa_sem_dado', (select count(*) from jsonb_array_elements(v_lista) x where x ->> 'categoria' = 'usa' and x ->> 'dados' in ('nao', 'externo'))));
end $$;
revoke all on function public.diagnostico_depara(uuid, date) from public, anon;
grant execute on function public.diagnostico_depara(uuid, date) to authenticated;

-- Para desfazer: drop function diagnostico_depara(uuid, date), diag_metrica_rotulo(text); alter table metricas_definicoes drop column requisitos;
