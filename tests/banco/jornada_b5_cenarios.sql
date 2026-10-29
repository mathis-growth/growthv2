-- v0.163 (B5/B5b): marcos manuais, automáticos e com confirmação; eventos de fora; marcos seguem para a nova versão.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "jornada_b5: tudo OK".
do $t$
declare ws uuid; pr uuid; pr2 uuid; j uuid; e1 uuid; e2 uuid; pe uuid; a uuid; plat uuid; fv uuid; s uuid; pq uuid; resp uuid;
  m_man uuid; m_et uuid; m_comp uuid; m_vid uuid; m_pq uuid; m_ev uuid; m_conf uuid; r jsonb; v2 uuid; x text;
begin
  ws := provisionar_workspace('B5');
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria-b5', 1000) returning id into pr;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Imersão', 'imersao-b5', 300) returning id into pr2;
  insert into jornadas (workspace_id, produto_id, nome) values (ws, pr, 'Mentoria') returning id into j;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Boas-vindas', 1, j) returning id into e1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Plano', 2, j) returning id into e2;
  perform jornada_publicar(j, 'continuar', '{}');
  insert into fontes_video (workspace_id, nome, tipo) values (ws, 'Aula 1', 'aula') returning id into fv;
  insert into pesquisas (workspace_id, nome, tipo) values (ws, 'Check-in 30 dias', 'jornada') returning id into s;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, texto, tipo, opcoes) values (ws, s, 'Já teve o primeiro resultado?', 'sim_nao', '{}') returning id into pq;

  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, obrigatorio, prazo_dias) values (ws, j, 'Apresentou o plano', 'manual', true, 30) returning id into m_man;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Chegou ao plano', 'automatico', jsonb_build_object('tipo', 'etapa', 'etapa_kanban_id', e2)) returning id into m_et;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Comprou a imersão', 'automatico', jsonb_build_object('tipo', 'compra', 'produto_id', pr2)) returning id into m_comp;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Assistiu à aula 1', 'automatico', jsonb_build_object('tipo', 'video', 'fonte_id', fv, 'minutos', 20)) returning id into m_vid;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Disse que teve resultado', 'auto_confirmar', jsonb_build_object('tipo', 'pesquisa', 'pesquisa_id', s, 'pergunta_id', pq, 'resposta', 'Sim')) returning id into m_pq;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Entregou o trabalho XPTO', 'automatico', jsonb_build_object('tipo', 'evento', 'evento', 'trabalho_xpto')) returning id into m_ev;
  begin insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao) values (ws, j, 'Sem regra', 'automatico'); raise exception 'X: automático sem regra';
  exception when check_violation then null; end;

  insert into pessoas (workspace_id, nome, email, telefone) values (ws, 'Ana', 'ana@b5.com', '11999990000') returning id into pe;
  select id into plat from plataformas_venda where workspace_id = ws limit 1;
  if plat is null then insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 0, 0) returning id into plat; end if;
  insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, valor_bruto, status) values (ws, pe, pr, plat, 'pix', 1000, 'aprovada');
  select id into a from alunos where pessoa_id = pe and produto_id = pr;
  if exists (select 1 from aluno_marcos where aluno_id = a) then raise exception 'X: marco antes de acontecer'; end if;

  -- etapa
  update alunos set etapa_kanban_id = e2 where id = a;
  if (select situacao from aluno_marcos where aluno_id = a and marco_id = m_et) <> 'atingido' then raise exception 'X: marco de etapa'; end if;
  -- vídeo: 10 min não basta, 25 min sim
  insert into presencas_video (workspace_id, fonte_id, pessoa_id, assistiu_seg) values (ws, fv, pe, 600);
  if exists (select 1 from aluno_marcos where aluno_id = a and marco_id = m_vid) then raise exception 'X: vídeo com pouco tempo'; end if;
  update presencas_video set assistiu_seg = 1500 where pessoa_id = pe;
  if (select sinal from aluno_marcos where aluno_id = a and marco_id = m_vid) <> 'observado' then raise exception 'X: marco de vídeo'; end if;
  -- compra de outro produto
  insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, valor_bruto, status) values (ws, pe, pr2, plat, 'pix', 300, 'aprovada');
  if (select situacao from aluno_marcos where aluno_id = a and marco_id = m_comp) <> 'atingido' then raise exception 'X: marco de compra'; end if;
  -- pesquisa: "Não" não marca; "Sim" fica aguardando confirmação, declarado
  insert into pesquisa_respostas (workspace_id, pesquisa_id, pessoa_id) values (ws, s, pe) returning id into resp;
  insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (ws, resp, pq, 'Não');
  if exists (select 1 from aluno_marcos where aluno_id = a and marco_id = m_pq) then raise exception 'X: resposta errada marcou'; end if;
  insert into pesquisa_respostas (workspace_id, pesquisa_id, pessoa_id) values (ws, s, pe) returning id into resp;
  insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (ws, resp, pq, 'sim');
  if (select situacao || '/' || sinal from aluno_marcos where aluno_id = a and marco_id = m_pq) <> 'aguardando/declarado' then raise exception 'X: marco de pesquisa'; end if;
  x := marco_confirmar(a, m_pq, 'confirmar', 'Confirmado na call');
  if (select situacao || '/' || sinal from aluno_marcos where aluno_id = a and marco_id = m_pq) <> 'atingido/validado' then raise exception 'X: confirmação'; end if;
  -- manual: recusar, depois confirmar, depois desfazer
  perform marco_confirmar(a, m_man, 'recusar', null);
  if (select situacao from aluno_marcos where aluno_id = a and marco_id = m_man) <> 'recusado' then raise exception 'X: recusa'; end if;
  perform marco_confirmar(a, m_man, 'confirmar', null);
  perform marco_confirmar(a, m_man, 'desfazer', null);
  if exists (select 1 from aluno_marcos where aluno_id = a and marco_id = m_man) then raise exception 'X: desfazer'; end if;
  -- recusado não volta sozinho
  perform marco_confirmar(a, m_vid, 'recusar', 'Vídeo assistido por outra pessoa');
  update presencas_video set assistiu_seg = 1800 where pessoa_id = pe;
  if (select situacao from aluno_marcos where aluno_id = a and marco_id = m_vid) <> 'recusado' then raise exception 'X: recusado voltou'; end if;

  -- evento de fora pela chave
  insert into t.cfg values ('uid', gen_random_uuid()::text) on conflict (k) do update set v = excluded.v;
  insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (ws, 'Plataforma', 'eventos', 'gw_teste', chave_api_hash('gw_testeeventos')) ;
  r := evento_por_chave('gw_testeeventos', jsonb_build_object('telefone', '(11) 99999-0000', 'evento', 'Trabalho XPTO'));
  if not (r->>'ok')::boolean or (r->>'marcos')::int <> 1 then raise exception 'X: evento: %', r; end if;
  if (select fonte from aluno_marcos where aluno_id = a and marco_id = m_ev) <> 'evento' then raise exception 'X: marco de evento'; end if;
  r := evento_por_chave('gw_testeeventos', jsonb_build_object('email', 'ninguem@b5.com', 'evento', 'x'));
  if (r->>'ok')::boolean then raise exception 'X: pessoa desconhecida aceita'; end if;
  begin perform evento_por_chave('gw_errada', jsonb_build_object('email', 'ana@b5.com', 'evento', 'x')); raise exception 'X: chave errada aceita';
  exception when sqlstate '28000' then null; end;
  begin perform evento_por_chave('gw_testeeventos', jsonb_build_object('email', 'ana@b5.com')); raise exception 'X: sem evento';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  delete from t.cfg where k = 'uid';

  -- retroativo de um marco novo
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, regra) values (ws, j, 'Passou pela boas-vindas', 'automatico', jsonb_build_object('tipo', 'etapa', 'etapa_kanban_id', e1)) returning id into m_conf;
  if marco_retroativo(m_conf) <> 1 then raise exception 'X: retroativo'; end if;

  -- nova versão leva os marcos (o de etapa aponta para a etapa equivalente)
  v2 := jornada_rascunho(pr, j, false);
  if (select count(*) from jornada_marcos where jornada_id = v2) <> (select count(*) from jornada_marcos where jornada_id = j) then raise exception 'X: marcos não foram para a v2: % de %', (select count(*) from jornada_marcos where jornada_id = v2), (select count(*) from jornada_marcos where jornada_id = j); end if;
  if not exists (select 1 from jornada_marcos m join etapas_kanban e on e.id::text = m.regra->>'etapa_kanban_id' where m.jornada_id = v2 and e.jornada_id = v2 and e.nome = 'Plano') then raise exception 'X: regra de etapa não foi remapeada'; end if;
  -- auditoria
  if not exists (select 1 from auditoria where tabela = 'alunos' and registro_id = a) then raise exception 'X: alunos sem auditoria'; end if;
  raise notice 'jornada_b5: tudo OK';
end $t$;
select 'jornada_b5: tudo OK' as resultado;
