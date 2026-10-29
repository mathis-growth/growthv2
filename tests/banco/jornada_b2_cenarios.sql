-- v0.163 (B2/B4): jornada do produto com versão; matrícula nasce na jornada publicada do produto.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "jornada_b2: tudo OK".
do $t$
declare ws uuid; pr1 uuid; pr2 uuid; g1 uuid; g2 uuid; j1 uuid; j2 uuid; m1 uuid; m2 uuid; m3 uuid; pe uuid; pe2 uuid; a1 uuid; a2 uuid; a3 uuid;
  plat uuid; v uuid; r jsonb; s uuid; n int;
begin
  ws := provisionar_workspace('B2');
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Mentoria', 'mentoria-b2', 1000) returning id into pr1;
  insert into produtos (workspace_id, nome, tag, preco) values (ws, 'Curso', 'curso-b2', 100) returning id into pr2;
  delete from etapas_kanban where workspace_id = ws and quadro = 'alunos';
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Onboarding', 1) returning id into g1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Ativo', 2) returning id into g2;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Ana', 'ana@b2.com') returning id into pe;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Bia', 'bia@b2.com') returning id into pe2;

  -- sem jornada: igual a hoje
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe, pr2, 'curso-b2', g1) returning id into a1;
  if (select jornada_id from alunos where id = a1) is not null or (select etapa_kanban_id from alunos where id = a1) <> g1 then raise exception 'X: matrícula sem jornada mudou'; end if;

  -- jornada da mentoria (rascunho) com etapa de mesmo nome da geral; ordem menor que a geral, para pegar o erro de "primeira etapa do quadro"
  insert into jornadas (workspace_id, produto_id, nome) values (ws, pr1, 'Jornada da mentoria') returning id into j1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Onboarding', 0, j1) returning id into m1;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Diagnóstico', 1, j1) returning id into m2;
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Plano', 2, j1) returning id into m3;
  begin insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Plano', 3, j1); raise exception 'X: nome repetido na jornada';
  exception when unique_violation then null; end;
  begin insert into etapas_kanban (workspace_id, quadro, nome, ordem) values (ws, 'alunos', 'Ativo', 9); raise exception 'X: nome repetido na geral';
  exception when unique_violation then null; end;
  begin insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'leads', 'X', 1, j1); raise exception 'X: etapa de lead em jornada';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;

  -- rascunho não vale para matrícula nova; o aluno da mentoria fica na geral (primeira etapa da geral, não a 'Onboarding' de ordem 0 da jornada)
  insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id) values (ws, pe2, pr1, 'mentoria-b2', m1) returning id into a2;
  if (select jornada_id from alunos where id = a2) is not null or (select etapa_kanban_id from alunos where id = a2) <> g1 then raise exception 'X: rascunho foi usado na matrícula'; end if;

  -- publicar
  update jornadas set status = 'publicada' where id = j1;
  if (select publicada_em from jornadas where id = j1) is null then raise exception 'X: publicada_em vazio'; end if;
  begin update etapas_kanban set nome = 'Outro' where id = m2; raise exception 'X: renomeou etapa publicada';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Nova', 5, j1); raise exception 'X: criou etapa em versão publicada';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin delete from etapas_kanban where id = m3; raise exception 'X: apagou etapa publicada';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  update etapas_kanban set descricao = 'Fazer a reunião de diagnóstico' where id = m2;  -- o que fazer pode mudar
  begin update jornadas set status = 'rascunho' where id = j1; raise exception 'X: voltou para rascunho';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  insert into jornadas (workspace_id, produto_id, nome, versao) values (ws, pr1, 'Jornada da mentoria', 2) returning id into j2;
  begin update jornadas set status = 'publicada' where id = j2; raise exception 'X: duas publicadas';
  exception when unique_violation then null; end;

  -- matrícula nova da mentoria (pela venda de verdade) nasce na primeira etapa da jornada publicada
  select id into plat from plataformas_venda where workspace_id = ws limit 1;
  if plat is null then insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa) values (ws, 'Hotmart', 0, 0) returning id into plat; end if;
  insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, valor_bruto, status)
    values (ws, pe, pr1, plat, 'pix', 1000, 'aprovada') returning id into v;
  select id into a3 from alunos where venda_id = v;
  if a3 is null then raise exception 'X: venda não gerou matrícula'; end if;
  if (select jornada_id from alunos where id = a3) <> j1 or (select etapa_kanban_id from alunos where id = a3) <> m1 then raise exception 'X: matrícula da venda fora da jornada do produto'; end if;
  if not exists (select 1 from aluno_historico where aluno_id = a3 and etapa_kanban_id = m1) then raise exception 'X: histórico sem a primeira etapa'; end if;

  -- anda só pelas etapas da própria jornada
  update alunos set etapa_kanban_id = m3 where id = a3;
  begin update alunos set etapa_kanban_id = g2 where id = a3; raise exception 'X: foi para etapa da geral';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin update alunos set etapa_kanban_id = m2 where id = a1; raise exception 'X: aluno da geral foi para etapa da jornada';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  begin update alunos set jornada_id = j1 where id = a1; raise exception 'X: jornada de outro produto';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  -- curso continua na geral pela venda
  insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, valor_bruto, status)
    values (ws, pe2, pr2, plat, 'pix', 100, 'aprovada') returning id into v;
  if (select jornada_id from alunos where venda_id = v) is not null or (select etapa_kanban_id from alunos where venda_id = v) <> g1 then raise exception 'X: curso saiu da geral'; end if;

  -- pesquisa por etapa da jornada do produto
  insert into pesquisas (workspace_id, nome, tipo, gatilho, etapa_aluno_id) values (ws, 'NPS do plano', 'jornada', 'etapa_aluno', m2) returning id into s;
  update alunos set etapa_kanban_id = m2 where id = a3;
  if not exists (select 1 from pesquisa_envios where pesquisa_id = s and pessoa_id = pe) then raise exception 'X: pesquisa da etapa da jornada não disparou'; end if;

  -- Dashboard de RevOps: etapas com o produto na frente
  r := heavyops_painel(ws, 30);
  if not (r->'etapas' @> '[{"etapa": "Mentoria · Plano"}]'::jsonb) and not exists (select 1 from jsonb_array_elements(r->'etapas') x where x->>'etapa' = 'Mentoria · Diagnóstico') then
    raise exception 'X: painel sem as etapas da mentoria: %', r->'etapas'; end if;
  if exists (select 1 from jsonb_array_elements(r->'etapas') x where x->>'etapa' like '%Mentoria%' and x->>'etapa' not like 'Mentoria · %') then raise exception 'X: rótulo errado'; end if;
  -- rascunho (versão 2) fica fora do painel
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, jornada_id) values (ws, 'alunos', 'Só no rascunho', 1, j2);
  r := heavyops_painel(ws, 30);
  if exists (select 1 from jsonb_array_elements(r->'etapas') x where x->>'etapa' like '%Só no rascunho%') then raise exception 'X: rascunho no painel'; end if;

  -- análise de funil: "chegou na etapa" compara a ordem dentro da mesma jornada
  select count(distinct pessoa_id) into n from funil_membros(ws, (now() - interval '2 days')::date, (now() + interval '1 day')::date, null, null) where chave = 'a:' || g2::text;
  if n <> 0 then raise exception 'X: aluno da mentoria contado na etapa Ativo da geral (% pessoas)', n; end if;
  select count(distinct pessoa_id) into n from funil_membros(ws, (now() - interval '2 days')::date, (now() + interval '1 day')::date, null, null) where chave = 'a:' || m1::text;
  if n <> 1 then raise exception 'X: Onboarding da mentoria deveria ter 1 pessoa (tem %)', n; end if;
  perform funil_analise(ws, (now() - interval '2 days')::date, (now() + interval '1 day')::date, null, null);

  -- apagar a jornada inteira (versão 2, rascunho) leva as etapas dela
  delete from jornadas where id = j2;
  if exists (select 1 from etapas_kanban where jornada_id = j2) then raise exception 'X: etapas do rascunho ficaram'; end if;
  raise notice 'jornada_b2: tudo OK';
end $t$;
select 'jornada_b2: tudo OK' as resultado;
