-- v0.175 (Diagnóstico 360°, G1): formulário do cliente, tipos novos, condição, validade do link e catálogo por etapa.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "diagnostico_g1: tudo OK".
do $t$
declare ws uuid; pe uuid; pq uuid; q_mod uuid; q_fat uuid; q_metr uuid; q_cac uuid; q_tem uuid; q_qual uuid; q_lista uuid; q_doc uuid; env uuid; tok text; d jsonb; r uuid; n int; grande jsonb;
begin
  ws := provisionar_workspace('Diag G1');
  insert into pessoas (workspace_id, nome, email) values (ws, 'Cliente Diag', 'cli@diag.com') returning id into pe;
  -- catálogo
  if (select count(*) from metricas_definicoes where etapa_aarrr is not null) < 50 then raise exception 'X: catálogo por etapa incompleto (%)', (select count(*) from metricas_definicoes where etapa_aarrr is not null); end if;
  if (select string_agg(distinct etapa_aarrr, ',' order by etapa_aarrr) from metricas_definicoes) <> 'aquisicao,ativacao,receita,recomendacao,recompra,retencao' then raise exception 'X: etapas do funil pirata'; end if;
  if (select calcula_sozinho from metricas_definicoes where codigo = 'cac') is not true or (select calcula_sozinho from metricas_definicoes where codigo = 'ltv') is not false then raise exception 'X: calcula_sozinho'; end if;
  if (select modelos from metricas_definicoes where codigo = 'mrr') <> array['assinatura', 'comunidade'] then raise exception 'X: MRR só para assinatura'; end if;
  -- formulário de diagnóstico para cliente
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'Diagnóstico 360°', 'diagnostico', 'manual', true, 'cliente') returning id into pq;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, obrigatoria, secao) values (ws, pq, 1, 'Modelo de negócio', 'multipla', array['Infoproduto ou curso', 'Assinatura ou recorrência'], true, 'Perfil') returning id into q_mod;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, config) values (ws, pq, 2, 'Faturamento dos últimos 6 meses', 'meses', true, 'Perfil', '{"meses": 6}') returning id into q_fat;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao) values (ws, pq, 3, 'CAC mídia', 'moeda', false, 'Jornada') returning id into q_cac;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, config) values (ws, pq, 4, 'Métricas', 'metricas', true, 'Métricas', '{"etapas": ["aquisicao", "receita"]}') returning id into q_metr;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, obrigatoria, secao) values (ws, pq, 5, 'Tem North Star?', 'escolha', array['Sim', 'Não', 'Não sei'], true, 'Métricas') returning id into q_tem;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, condicao) values (ws, pq, 6, 'Qual é a North Star?', 'texto', true, 'Métricas', jsonb_build_object('pergunta', q_tem, 'valores', jsonb_build_array('Sim'))) returning id into q_qual;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, config) values (ws, pq, 7, 'Produtos', 'lista', false, 'Produtos', '{"colunas": ["nome", "preco"]}') returning id into q_lista;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, config) values (ws, pq, 8, 'Documentos', 'documentos', false, 'Documentação', '{"categorias": ["vendas", "crm"]}') returning id into q_doc;
  -- condição inválida (sem valores) é recusada
  begin insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, condicao) values (ws, pq, 9, 'x', 'texto', '{"pergunta": "a"}'); raise exception 'X: condição sem valores aceita';
  exception when check_violation then null; end;
  -- envio individual: validade de 30 dias
  perform set_config('growths.dummy', '1', true);
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning id, token into env, tok;
  if (select expira_em from pesquisa_envios where id = env) is null or (select expira_em from pesquisa_envios where id = env) < now() + interval '29 days' then raise exception 'X: validade de 30 dias'; end if;
  -- o formulário público traz condição, configuração e o catálogo
  d := pesquisa_publica(tok);
  if d is null or d ->> 'tipo' <> 'diagnostico' or jsonb_array_length(d -> 'metricas') < 50 then raise exception 'X: público sem catálogo'; end if;
  if (select x -> 'condicao' ->> 'pergunta' from jsonb_array_elements(d -> 'perguntas') x where x ->> 'id' = q_qual::text) <> q_tem::text then raise exception 'X: condição no público'; end if;
  if (select x -> 'config' ->> 'meses' from jsonb_array_elements(d -> 'perguntas') x where x ->> 'id' = q_fat::text) <> '6' then raise exception 'X: config no público'; end if;
  -- obrigatória escondida pela condição não é cobrada (respondeu "Não")
  perform pesquisa_responder(tok, jsonb_build_object(
    q_mod::text, jsonb_build_array('Infoproduto ou curso'),
    q_fat::text, jsonb_build_object('2026-05', 40000, '2026-06', 42000, '2026-07', 38000, '2026-08', 45000, '2026-09', 51000, '2026-10', 50000),
    q_cac::text, 180.5,
    q_metr::text, jsonb_build_object(
      'cac', jsonb_build_object('status', 'regular', 'decide', true, 'objetivo', 'Controlar o custo do cliente', 'numerador', 'Investimento em mídia', 'denominador', 'Clientes novos', 'janela', 'mês', 'como', jsonb_build_array('planilha'), 'responsavel', 'Ana', 'clareza', 'sim', 'decisao', 'Aumentar ou cortar verba'),
      'ltv', jsonb_build_object('status', 'nao', 'tem_dados', 'sim'),
      'roas', jsonb_build_object('status', 'ocasional')),
    q_tem::text, 'Não',
    q_lista::text, jsonb_build_array(jsonb_build_object('nome', 'Mentoria', 'preco', 3000)),
    q_doc::text, jsonb_build_object('vendas', 'sim', 'crm', 'depois')), null);
  select id into r from pesquisa_respostas where pesquisa_id = pq;
  if r is null then raise exception 'X: resposta não registrada'; end if;
  if (select valor_num from pesquisa_resposta_itens where resposta_id = r and pergunta_id = q_metr) <> 2 then raise exception 'X: contagem das métricas que tem'; end if;
  if (select valor_json -> 'cac' ->> 'objetivo' from pesquisa_resposta_itens where resposta_id = r and pergunta_id = q_metr) <> 'Controlar o custo do cliente' then raise exception 'X: detalhe da métrica'; end if;
  if (select valor_json ->> '2026-10' from pesquisa_resposta_itens where resposta_id = r and pergunta_id = q_fat) <> '50000' then raise exception 'X: faturamento mês a mês'; end if;
  if (select valor_num from pesquisa_resposta_itens where resposta_id = r and pergunta_id = q_cac) <> 180.5 then raise exception 'X: CAC em reais'; end if;
  if exists (select 1 from pesquisa_resposta_itens where resposta_id = r and pergunta_id = q_qual) then raise exception 'X: pergunta escondida gravada'; end if;
  if (select status from pesquisa_envios where id = env) <> 'respondido' then raise exception 'X: envio não ficou respondido'; end if;

  -- condição satisfeita: a obrigatória passa a ser cobrada
  insert into pessoas (workspace_id, nome, email) values (ws, 'Outro', 'outro@diag.com') returning id into pe;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning token into tok;
  begin perform pesquisa_responder(tok, jsonb_build_object(q_mod::text, jsonb_build_array('Infoproduto ou curso'), q_fat::text, jsonb_build_object('2026-10', 1),
      q_metr::text, jsonb_build_object('cac', jsonb_build_object('status', 'nao')), q_tem::text, 'Sim'), null);
    raise exception 'X: condição satisfeita não cobrou a obrigatória';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  -- métrica com status inválido é recusada
  begin perform pesquisa_responder(tok, jsonb_build_object(q_mod::text, jsonb_build_array('Infoproduto ou curso'), q_fat::text, jsonb_build_object('2026-10', 1),
      q_metr::text, jsonb_build_object('cac', jsonb_build_object('status', 'talvez')), q_tem::text, 'Não'), null);
    raise exception 'X: status de métrica inválido aceito';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  -- resposta grande (diagnóstico detalhado) passa do limite antigo de 20 mil caracteres
  select jsonb_object_agg(codigo, jsonb_build_object('status', 'regular', 'objetivo', repeat('o', 300), 'como_calcula', repeat('c', 300), 'decisao', repeat('d', 300))) into grande
    from metricas_definicoes where etapa_aarrr is not null;
  perform pesquisa_responder(tok, jsonb_build_object(q_mod::text, jsonb_build_array('Assinatura ou recorrência'), q_fat::text, jsonb_build_object('2026-10', 1),
    q_metr::text, grande, q_tem::text, 'Não'), null);
  if length(grande::text) <= 20000 then raise exception 'X: o teste devia passar de 20 mil caracteres'; end if;
  -- link vencido: não abre e não aceita resposta
  insert into pessoas (workspace_id, nome, email) values (ws, 'Vencido', 'venc@diag.com') returning id into pe;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem, expira_em) values (ws, pq, pe, 'manual', now() - interval '1 day') returning token into tok;
  if (pesquisa_publica(tok) ->> 'expirado') <> 'true' then raise exception 'X: link vencido abriu'; end if;
  begin perform pesquisa_responder(tok, jsonb_build_object(q_tem::text, 'Não'), null); raise exception 'X: link vencido aceitou resposta';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; if sqlerrm not like '%venceu%' then raise exception 'X: mensagem do vencido: %', sqlerrm; end if; end;
  -- pesquisa de lead continua igual (limite de 20 mil e sem validade)
  if (select publico from pesquisas where id = pq) <> 'cliente' then raise exception 'X: público'; end if;
  raise notice 'diagnostico_g1: tudo OK';
end $t$;
select 'diagnostico_g1: tudo OK' as resultado;
