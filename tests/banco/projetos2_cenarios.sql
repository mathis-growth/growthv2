\set ON_ERROR_STOP on
do $$
declare ws uuid := gen_random_uuid(); pj uuid; a1 uuid; a2 uuid; s1 uuid; md uuid; c uuid; c2 uuid; pn uuid; j jsonb; cc uuid; an uuid; pe uuid;
begin
  insert into workspaces (id, nome) values (ws, 'P');
  insert into projetos (workspace_id, nome, data_inicio, data_fim_prevista, tags) values (ws, 'Lançamento piloto', current_date - 10, current_date + 10, '{lancamento,piloto}') returning id into pj;
  insert into projeto_atividades (workspace_id, projeto_id, titulo, funcao, ordem, prazo, tags) values (ws, pj, 'Página', 'Designer', 10, current_date - 5, '{site}') returning id into a1;
  insert into projeto_atividades (workspace_id, projeto_id, titulo, ordem, prazo, depende_de) values (ws, pj, 'Tráfego', 20, current_date + 5, array[a1]) returning id into a2;
  insert into projeto_atividades (workspace_id, projeto_id, pai_id, titulo, ordem, prazo) values (ws, pj, a2, 'Criativos', 1, current_date + 3) returning id into s1;
  perform set_config('growths.recalc', '1', true);
  update projeto_atividades set status = 'concluida', concluida_em = now() - interval '2 days' where id = a1;
  perform set_config('growths.recalc', '', true);
  -- painel
  j := projeto_painel(pj);
  assert (j->>'total')::int = 2, 'folhas: Página e Criativos: ' || j::text;
  assert (select (x->>'concluido')::int from jsonb_array_elements(j->'serie') x where x->>'d' = current_date::text) = 1, 'concluído acumulado hoje';
  assert (select (x->>'planejado')::int from jsonb_array_elements(j->'serie') x where x->>'d' = (current_date + 10)::text) = 2, 'planejado no fim';
  assert (select x->>'concluido' from jsonb_array_elements(j->'serie') x where x->>'d' = (current_date + 5)::text) is null, 'futuro sem concluído';
  -- modelo
  md := projeto_salvar_como_modelo(pj, 'Modelo lançamento', true);
  assert (select count(*) from projeto_modelo_atividades where modelo_id = md) = 3, 'copiou 3 atividades';
  assert (select prazo_dias from projeto_modelo_atividades where modelo_id = md and titulo = 'Página') = 5, 'prazo relativo';
  assert (select pai_id from projeto_modelo_atividades where modelo_id = md and titulo = 'Criativos') = (select id from projeto_modelo_atividades where modelo_id = md and titulo = 'Tráfego'), 'subatividade mantida';
  assert (select depende_de[1] from projeto_modelo_atividades where modelo_id = md and titulo = 'Tráfego') = (select id from projeto_modelo_atividades where modelo_id = md and titulo = 'Página'), 'dependência mantida';
  begin perform projeto_salvar_como_modelo(pj, 'modelo LANÇAMENTO'); assert false; exception when others then if sqlerrm not like '%Já existe%' then raise; end if; end;
  -- campanha cria projeto pelo modelo (com blocos)
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Black 2', current_date) returning id into c;   -- o gatilho cria o projeto automático
  insert into campanha_blocos (workspace_id, campanha_id, ordem, fase, tipo, nome) values (ws, c, 10, 'aquisicao', 'trafego', 'Tráfego pago');
  pn := campanha_criar_projeto(c, md, 'Black 2 — execução');
  assert (select count(*) from projeto_atividades where projeto_id = pn) = 3, 'projeto do modelo com 3 atividades';
  assert (select campanha_id from projetos where id = pn) = c, 'vinculado à campanha';
  -- vincular projeto existente a outra campanha
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Perpétuo', current_date) returning id into c2;
  perform projeto_vincular_campanha(pj, c2);
  assert (select campanha_id from projetos where id = pj) = c2;
  perform projeto_vincular_campanha(pj, null);
  assert (select campanha_id from projetos where id = pj) is null, 'desvincular';
  -- CPL por canal
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, meta_leads, meta_cpl) values (ws, c, 'meta_ads', 'b2_meta', 2, 50) returning id into cc;
  insert into anuncios (workspace_id, campanha_canal_id, nome) values (ws, cc, 'A') returning id into an;
  insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo) values (ws, an, current_date, 100, 10, 120);
  insert into pessoas (workspace_id, nome, email, campanha_id, utm_campaign, utm_source) values (ws, 'L1', 'l1@x.com', c, 'b2_meta', 'facebook');
  j := campanha_canais_resultado(c);
  assert j @> '[{"canal":"meta_ads","leads":1,"investimento":120,"cpl":120.00,"meta_cpl":50,"pct_leads":50.0}]', 'canais: ' || j::text;
  raise notice 'v0.90: projetos OK';
end $$;
