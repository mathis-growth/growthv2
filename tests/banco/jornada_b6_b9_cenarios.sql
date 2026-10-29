-- v0.163 (B6 a B9): check-in que se repete, alertas de CS, intervenções e oportunidades ligadas à matrícula.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "jornada_b6_b9: tudo OK".
do $t$
declare ws uuid; pr uuid; j uuid; e1 uuid; e2 uuid; pe uuid; pe2 uuid; a uuid; a2 uuid; s uuid; ck uuid; q_nps uuid; resp uuid; env uuid; mk uuid; cs uuid; iv uuid; al uuid;
  r jsonb; n int; agora timestamptz := now(); op uuid; s_old uuid;
begin
  insert into workspaces (nome) values ('B6') returning id into ws;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria-b6', 1000) returning id into pr;
  insert into jornadas (workspace_id, produto_id, nome) values (ws, pr, 'Mentoria') returning id into j;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id, descricao) values (ws, 'alunos', 'Boas-vindas', 1, j, 'Ligar para o aluno') returning id into e1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Formado', 2, j) returning id into e2;
  perform jornada_publicar(j, 'continuar', '{}');
  insert into equipe (workspace_id, nome, email, avisar_app, avisar_email) values (ws, 'Carla CS', 'carla@b6.com', true, false) returning id into cs;
  insert into alertas_config (workspace_id, ligado) values (ws, true);
  insert into pessoas (workspace_id, nome, email) values (ws, 'Ana', 'ana@b6.com') returning id into pe;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Bia', 'bia@b6.com') returning id into pe2;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, entrou_em, responsavel_cs_id) values (ws, pe, pr, 'mentoria-b6', agora - interval '45 days', cs) returning id into a;
  update aluno_historico set em = agora - interval '45 days' where aluno_id = a;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, entrou_em) values (ws, pe2, pr, 'mentoria-b6', agora - interval '3 days') returning id into a2;

  -- B6: envio único de antes continua único; check-in a cada 14 dias, no máximo 3
  insert into pesquisas (workspace_id, nome, tipo, gatilho) values (ws, 'Onboarding', 'onboarding', 'entrada_aluno') returning id into s_old;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Caio', 'caio@b6.com') returning id into op;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag) values (ws, op, pr, 'mentoria-b6');
  insert into alunos (workspace_id, pessoa_id, produto_id, tag) values (ws, op, pr, 'mentoria-b6');
  if (select count(*) from pesquisa_envios where pesquisa_id = s_old and pessoa_id = op) <> 1 then raise exception 'X: envio único repetiu'; end if;
  if (select ciclo from pesquisa_envios where pesquisa_id = s_old and pessoa_id = op) <> 0 then raise exception 'X: envio único fora do ciclo 0'; end if;
  begin insert into pesquisas (workspace_id, nome, tipo, gatilho) values (ws, 'Sem dias', 'jornada', 'checkin'); raise exception 'X: check-in sem dias';
  exception when check_violation then null; end;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, checkin_dias, checkin_max, produto_id) values (ws, 'Check-in quinzenal', 'jornada', 'checkin', 14, 3, pr) returning id into ck;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, texto, tipo, papel) values (ws, ck, 'De 0 a 10?', 'nps', 'nps') returning id into q_nps;
  n := pesquisa_checkins_gerar(agora, null);
  if (select count(*) from pesquisa_envios where pesquisa_id = ck) <> 1 or (select ciclo from pesquisa_envios where pesquisa_id = ck and pessoa_id = pe) <> 3 then raise exception 'X: check-in do dia (% envios)', n; end if;
  if (select aluno_id from pesquisa_envios where pesquisa_id = ck and pessoa_id = pe) <> a then raise exception 'X: check-in sem matrícula'; end if;
  n := pesquisa_checkins_gerar(agora, null); if n <> 0 then raise exception 'X: check-in duplicou'; end if;
  n := pesquisa_checkins_gerar(agora + interval '20 days', null); if n <> 2 then raise exception 'X: Bia e Caio (um por pessoa, mesmo com duas matrículas) deveriam ganhar o 1º check-in (%)', n; end if;
  n := pesquisa_checkins_gerar(agora + interval '30 days', null); if exists (select 1 from pesquisa_envios where pesquisa_id = ck and pessoa_id = pe and ciclo > 3) then raise exception 'X: passou do máximo'; end if;
  perform pesquisa_enviar_para(s_old, array[pe]);  -- manual continua funcionando
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_old and pessoa_id = pe) then raise exception 'X: envio manual'; end if;

  -- B7: alertas de CS
  update pesquisa_envios set gerado_em = agora - interval '10 days' where pesquisa_id = ck and pessoa_id = pe;
  insert into jornada_marcos (workspace_id, jornada_id, nome, confirmacao, obrigatorio, prazo_dias) values (ws, j, 'Plano entregue', 'manual', true, 30) returning id into mk;
  r := cg_verificar_alertas(ws, agora, true);
  if not exists (select 1 from alertas where workspace_id = ws and regra = 'parado' and dados->>'aluno_id' = a::text) then raise exception 'X: alerta parado: %', r; end if;
  if not exists (select 1 from alertas where workspace_id = ws and regra = 'marco_atrasado' and dados->>'marco_id' = mk::text) then raise exception 'X: alerta marco'; end if;
  if not exists (select 1 from alertas where workspace_id = ws and regra = 'checkin_sem_resposta') then raise exception 'X: alerta check-in'; end if;
  if not exists (select 1 from alertas where workspace_id = ws and regra = 'sem_cs' and dados->>'aluno_id' = a2::text) then raise exception 'X: alerta sem CS'; end if;
  if exists (select 1 from alertas where workspace_id = ws and regra = 'parado' and dados->>'aluno_id' = a2::text) then raise exception 'X: Bia não está parada'; end if;
  if not exists (select 1 from notificacoes where workspace_id = ws and destinatario_id = cs and titulo like 'Marco atrasado%') then raise exception 'X: CS não foi avisada'; end if;
  n := (select count(*) from alertas where workspace_id = ws and tipo = 'cs');
  r := cg_verificar_alertas(ws, agora, true);
  if (select count(*) from alertas where workspace_id = ws and tipo = 'cs') <> n then raise exception 'X: alerta repetiu'; end if;
  -- responde o check-in com nota 4 → nota baixa; o de check-in se resolve sozinho
  select id into env from pesquisa_envios where pesquisa_id = ck and pessoa_id = pe;
  insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values (ws, ck, env, pe) returning id into resp;
  insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num) values (ws, resp, q_nps, 4);
  update pesquisa_envios set status = 'respondido', respondido_em = now() where id = env;
  r := cg_verificar_alertas(ws, agora, true);
  select id into al from alertas where workspace_id = ws and regra = 'nps_baixo' and dados->>'resposta_id' = resp::text;
  if al is null then raise exception 'X: alerta de nota baixa'; end if;
  if (select resolvido_em from alertas where workspace_id = ws and regra = 'checkin_sem_resposta') is null then raise exception 'X: check-in respondido não resolveu'; end if;
  -- desligar uma regra
  update alertas_config set regras = '{"cs": {"desligadas": ["sem_cs"]}}' where workspace_id = ws;
  delete from alertas where workspace_id = ws and regra = 'sem_cs';
  r := cg_verificar_alertas(ws, agora, true);
  if exists (select 1 from alertas where workspace_id = ws and regra = 'sem_cs') then raise exception 'X: regra desligada gerou alerta'; end if;
  -- agendador chama o acompanhamento
  if position('cg_rodar_agendado' in pg_get_functiondef('public.growths_rodar_agendado(timestamptz)'::regprocedure)) = 0 then raise exception 'X: agendador sem o acompanhamento'; end if;
  r := growths_rodar_agendado(agora);

  -- B8: intervenção ligada ao alerta; concluir resolve o alerta
  insert into cs_intervencoes (workspace_id, aluno_id, alerta_id, tipo, descricao, prazo) values (ws, a, al, 'ligacao', 'Ligar para entender a nota 4', (agora + interval '2 days')::date) returning id into iv;
  if (select responsavel_id from cs_intervencoes where id = iv) <> cs or (select pessoa_id from cs_intervencoes where id = iv) <> pe then raise exception 'X: responsável/pessoa da intervenção'; end if;
  if not exists (select 1 from notificacoes where destinatario_id = cs and titulo like 'Intervenção de CS%') then raise exception 'X: CS não avisada da intervenção'; end if;
  update cs_intervencoes set status = 'feita', resultado = 'Ajustamos o horário das reuniões', efeito = 'resolveu' where id = iv;
  if (select concluida_em from cs_intervencoes where id = iv) is null or (select resolvido_em from alertas where id = al) is null then raise exception 'X: concluir não resolveu o alerta'; end if;
  begin insert into cs_intervencoes (workspace_id, aluno_id, descricao, marco_id) values (ws, a2, 'x', gen_random_uuid()); raise exception 'X: marco inválido';
  exception when raise_exception or foreign_key_violation then if sqlerrm like 'X:%' then raise; end if; end;

  -- B9: oportunidade de expansão ligada à matrícula
  insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, aluno_id, origem) values (ws, pe, 'Imersão para a Ana', 'expansao', a, 'marco') returning id into op;
  begin insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, aluno_id) values (ws, pe2, 'Errada', 'retencao', a); raise exception 'X: matrícula de outra pessoa';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  raise notice 'jornada_b6_b9: tudo OK';
end $t$;
select 'jornada_b6_b9: tudo OK' as resultado;
