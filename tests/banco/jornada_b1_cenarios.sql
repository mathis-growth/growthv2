-- v0.163 (B1): pesquisa disparada quando o aluno entra numa etapa da jornada.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "jornada_b1: tudo OK".
do $t$
declare ws uuid; ws2 uuid; pr1 uuid; pr2 uuid; e1 uuid; e2 uuid; eo uuid; pe uuid; pe2 uuid; a1 uuid; a2 uuid; s_et uuid; s_prod uuid; s_ent uuid; s_old uuid; n int;
begin
  insert into workspaces (nome) values ('B1') returning id into ws;
  insert into workspaces (nome) values ('Outro') returning id into ws2;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria', 1000) returning id into pr1;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso', 100) returning id into pr2;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Onboarding', 1) returning id into e1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Primeiro resultado', 2) returning id into e2;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws2, 'alunos', 'Onboarding', 1) returning id into eo;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Ana', 'ana@x.com') returning id into pe;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Bia', 'bia@x.com') returning id into pe2;

  -- validações
  begin insert into pesquisas (workspace_id, nome, tipo, gatilho) values (ws, 'sem etapa', 'jornada', 'etapa_aluno'); raise exception 'X: aceitou etapa_aluno sem etapa';
  exception when check_violation then null; end;
  begin insert into pesquisas (workspace_id, nome, tipo, gatilho, etapa_aluno_id) values (ws, 'etapa de outro', 'jornada', 'etapa_aluno', eo); raise exception 'X: aceitou etapa de outro cliente';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;

  -- pesquisa que já existia (entrada_aluno sem produto) continua valendo para todos
  insert into pesquisas (workspace_id, nome, tipo, gatilho) values (ws, 'Onboarding geral', 'onboarding', 'entrada_aluno') returning id into s_old;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, produto_id) values (ws, 'Onboarding mentoria', 'onboarding', 'entrada_aluno', pr1) returning id into s_ent;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, etapa_aluno_id) values (ws, 'NPS 1º resultado', 'jornada', 'etapa_aluno', e2) returning id into s_et;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, etapa_aluno_id, produto_id) values (ws, 'NPS 1º resultado curso', 'jornada', 'etapa_aluno', e2, pr2) returning id into s_prod;
  if (select etapa_aluno_id from pesquisas where id = s_old) is not null then raise exception 'X: etapa ficou em pesquisa sem gatilho de etapa'; end if;

  -- matrícula na mentoria
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe, pr1, 'mentoria', e1) returning id into a1;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_old and pessoa_id = pe) then raise exception 'X: onboarding geral não disparou'; end if;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_ent and pessoa_id = pe) then raise exception 'X: onboarding da mentoria não disparou'; end if;
  if exists (select 1 from pesquisa_envios where pesquisa_id = s_et) then raise exception 'X: NPS disparou antes da etapa'; end if;

  -- muda de etapa → dispara a de etapa sem produto; a do curso não
  update alunos set etapa_kanban_id = e2 where id = a1;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_et and pessoa_id = pe and origem = 'gatilho') then raise exception 'X: NPS da etapa não disparou'; end if;
  if exists (select 1 from pesquisa_envios where pesquisa_id = s_prod and pessoa_id = pe) then raise exception 'X: pesquisa do curso disparou para aluno da mentoria'; end if;

  -- matrícula no curso já começando na etapa → dispara as duas de etapa; a de onboarding da mentoria não
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe2, pr2, 'curso', e2) returning id into a2;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_prod and pessoa_id = pe2) then raise exception 'X: pesquisa do curso não disparou na primeira etapa'; end if;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s_et and pessoa_id = pe2) then raise exception 'X: NPS geral não disparou na primeira etapa'; end if;
  if exists (select 1 from pesquisa_envios where pesquisa_id = s_ent and pessoa_id = pe2) then raise exception 'X: onboarding da mentoria disparou para aluno do curso'; end if;

  -- retroativo: apaga a fila e gera de novo
  delete from pesquisa_envios where pesquisa_id in (s_et, s_prod, s_ent);
  n := pesquisa_gerar_envios(s_et); if n <> 2 then raise exception 'X: retroativo da etapa gerou % (esperado 2)', n; end if;
  n := pesquisa_gerar_envios(s_prod); if n <> 1 then raise exception 'X: retroativo do curso gerou % (esperado 1)', n; end if;
  n := pesquisa_gerar_envios(s_ent); if n <> 1 then raise exception 'X: retroativo da mentoria gerou % (esperado 1)', n; end if;

  -- o gatilho de etapa do funil continua igual
  if (select count(*) from pg_trigger where tgname = 'pesquisa_etapa_t') <> 1 then raise exception 'X: gatilho de etapa do funil sumiu'; end if;
  raise notice 'jornada_b1: tudo OK';
end $t$;
select 'jornada_b1: tudo OK' as resultado;
