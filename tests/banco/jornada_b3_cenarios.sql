-- v0.163 (B3): rascunho, publicação com "continuar" ou "transferir", transferência depois e modelos.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "jornada_b3: tudo OK".
do $t$
declare ws uuid; pr uuid; pr2 uuid; g1 uuid; g2 uuid; v1 uuid; v2 uuid; v3 uuid; md uuid; pe1 uuid; pe2 uuid; pe3 uuid; a1 uuid; a2 uuid; a3 uuid;
  r jsonb; s uuid; e_v1a uuid; e_v1b uuid; e_v2a uuid; e_v2b uuid; e_v2c uuid; n int; x uuid;
begin
  insert into workspaces (nome) values ('B3') returning id into ws;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria-b3', 1000) returning id into pr;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso-b3', 100) returning id into pr2;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Onboarding', 1) returning id into g1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Ativo', 2) returning id into g2;
  insert into pessoas (workspace_id, nome) values (ws, 'Ana') returning id into pe1;
  insert into pessoas (workspace_id, nome) values (ws, 'Bia') returning id into pe2;
  insert into pessoas (workspace_id, nome) values (ws, 'Caio') returning id into pe3;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe1, pr, 'mentoria-b3', g1) returning id into a1;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe2, pr, 'mentoria-b3', g2) returning id into a2;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe3, pr2, 'curso-b3', g1) returning id into a3;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, etapa_aluno_id, produto_id) values (ws, 'NPS ativo mentoria', 'jornada', 'etapa_aluno', g2, pr) returning id into s;

  -- v1 a partir da jornada geral
  v1 := jornada_rascunho(pr, null, true);
  if (select count(*) from etapas_kanban where jornada_id = v1) <> 2 then raise exception 'X: v1 não copiou a geral'; end if;
  begin perform jornada_rascunho(pr, null, false); raise exception 'X: dois rascunhos';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  select id into e_v1a from etapas_kanban where jornada_id = v1 and nome = 'Onboarding';
  select id into e_v1b from etapas_kanban where jornada_id = v1 and nome = 'Ativo';
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Formado', 3, v1);
  -- publicar transferindo só quem está em Onboarding (Ativo fica de fora = continua na geral)
  r := jornada_publicar(v1, 'transferir', jsonb_build_object(g1::text, e_v1a::text));
  if (r->>'transferidos')::int <> 1 then raise exception 'X: transferiu % (esperado 1)', r; end if;
  if (select jornada_id from alunos where id = a1) <> v1 or (select etapa_kanban_id from alunos where id = a1) <> e_v1a then raise exception 'X: Ana não foi para v1'; end if;
  if (select jornada_id from alunos where id = a2) is not null then raise exception 'X: Bia não deveria ter ido'; end if;
  if (select jornada_id from alunos where id = a3) is not null then raise exception 'X: aluno do curso foi transferido'; end if;
  if not exists (select 1 from aluno_historico where aluno_id = a1 and tipo = 'jornada' and jornada_id = v1 and jornada_de is null) then raise exception 'X: histórico sem a troca de jornada'; end if;
  if (select etapa_aluno_id from pesquisas where id = s) <> e_v1b then raise exception 'X: pesquisa não seguiu para a etapa Ativo da v1'; end if;

  -- Bia vem depois, pelo botão Transferir alunos
  n := jornada_transferir(null, v1, jsonb_build_object(g2::text, e_v1b::text), pr);
  if n <> 1 or (select etapa_kanban_id from alunos where id = a2) <> e_v1b then raise exception 'X: transferência posterior'; end if;

  -- v2 a partir da v1, com uma etapa a mais e um nome trocado; publicar "continuar"
  v2 := jornada_rascunho(pr, v1, false);
  if (select versao from jornadas where id = v2) <> 2 then raise exception 'X: versão não subiu'; end if;
  update etapas_kanban set nome = 'Boas-vindas' where jornada_id = v2 and nome = 'Onboarding';
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Diagnóstico', 2, v2);
  r := jornada_publicar(v2, 'continuar', '{}'::jsonb);
  if (select status from jornadas where id = v1) <> 'anterior' or (select status from jornadas where id = v2) <> 'publicada' then raise exception 'X: situações das versões'; end if;
  if (select jornada_id from alunos where id = a1) <> v1 then raise exception 'X: continuar mudou o aluno'; end if;
  select id into e_v2b from etapas_kanban where jornada_id = v2 and nome = 'Ativo';
  if (select etapa_aluno_id from pesquisas where id = s) <> e_v2b then raise exception 'X: pesquisa não seguiu pelo nome para a v2'; end if;
  -- matrícula nova vai para a v2
  insert into pessoas (workspace_id, nome) values (ws, 'Duda') returning id into x;
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, x, pr, 'mentoria-b3', g1) returning id into x;
  if (select jornada_id from alunos where id = x) <> v2 then raise exception 'X: matrícula nova fora da v2'; end if;
  -- depois decide levar a v1 para a v2 (Onboarding → Boas-vindas)
  select id into e_v2a from etapas_kanban where jornada_id = v2 and nome = 'Boas-vindas';
  n := jornada_transferir(v1, v2, jsonb_build_object(e_v1a::text, e_v2a::text, e_v1b::text, e_v2b::text));
  if n <> 2 then raise exception 'X: levou % da v1 para a v2', n; end if;
  -- não leva para rascunho nem para outro produto
  v3 := jornada_rascunho(pr, v2, false);
  begin perform jornada_transferir(v2, v3, '{}'::jsonb); raise exception 'X: transferiu para rascunho';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform jornada_publicar(v2, 'continuar', '{}'::jsonb); raise exception 'X: publicou de novo';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  delete from etapas_kanban where jornada_id = v3;
  begin perform jornada_publicar(v3, 'continuar', '{}'::jsonb); raise exception 'X: publicou sem etapas';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  delete from jornadas where id = v3;

  -- modelo e jornada do curso a partir dele
  md := jornada_salvar_modelo(v2, 'Mentoria (modelo)');
  if (select count(*) from etapas_kanban where jornada_id = md) <> (select count(*) from etapas_kanban where jornada_id = v2) then raise exception 'X: modelo sem as etapas'; end if;
  if (select produto_id from jornadas where id = md) is not null or not (select modelo from jornadas where id = md) then raise exception 'X: modelo com produto'; end if;
  x := jornada_rascunho(pr2, md, false);
  if (select count(*) from etapas_kanban where jornada_id = x) <> 4 then raise exception 'X: jornada do curso não copiou o modelo'; end if;
  begin perform jornada_rascunho(pr2, v1, false); raise exception 'X: base de outro produto';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id, jornada_id) values (ws, pe3, pr2, 'curso-b3', g1, md);
    if (select jornada_id from alunos where pessoa_id = pe3 order by entrou_em desc limit 1) is not null then raise exception 'X: matrícula entrou num modelo'; end if;
  end;
  raise notice 'jornada_b3: tudo OK';
end $t$;
select 'jornada_b3: tudo OK' as resultado;
