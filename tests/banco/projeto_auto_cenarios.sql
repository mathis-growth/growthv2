\set ON_ERROR_STOP on
do $$
declare ws uuid := gen_random_uuid(); md uuid; c1 uuid; c2 uuid; c3 uuid;
begin
  insert into workspaces (id, nome) values (ws, 'PA');
  insert into projeto_modelos (workspace_id, nome, padrao_campanha) values (ws, 'Padrão', true);
  insert into projeto_modelos (workspace_id, nome) values (ws, 'Outro') returning id into md;
  insert into projeto_modelo_atividades (workspace_id, modelo_id, titulo, ordem) values (ws, md, 'Briefing', 10);
  insert into campanhas (workspace_id, nome, data_inicio, projeto_auto) values (ws, 'Sem projeto', current_date, false) returning id into c1;
  assert not exists (select 1 from projetos where campanha_id = c1), 'desmarcado não cria projeto';
  insert into campanhas (workspace_id, nome, data_inicio, projeto_modelo_id) values (ws, 'Com outro modelo', current_date, md) returning id into c2;
  assert (select modelo_id from projetos where campanha_id = c2) = md and exists (select 1 from projeto_atividades a join projetos p on p.id = a.projeto_id where p.campanha_id = c2 and a.titulo = 'Briefing'), 'usa o modelo escolhido';
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Padrão', current_date) returning id into c3;
  assert (select m.nome from projetos p join projeto_modelos m on m.id = p.modelo_id where p.campanha_id = c3) = 'Padrão', 'sem escolha usa o padrão';
  raise notice 'v0.91: projeto automático opcional OK';
end $$;
