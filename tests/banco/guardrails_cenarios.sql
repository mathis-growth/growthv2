-- v0.100: guardrails. Rodar depois de guardrails_base.sql e da migração (2x).
do $$
declare ws uuid := '00000000-0000-0000-0000-0000000000a1'; g1 uuid; g2 uuid; g3 uuid; c uuid; e uuid; e2 uuid; ok boolean;
begin
  insert into guardrail_definicoes (workspace_id, nome, metrica, operador, limite, severidade) values (ws, 'CAC mídia máximo', 'cac_midia', 'max', 300, 'critico') returning id into g1;
  insert into guardrail_definicoes (workspace_id, nome, metrica, operador, limite, produto_id) values (ws, 'ROAS mínimo do curso', 'roas', 'min', 2, '00000000-0000-0000-0000-0000000000b1') returning id into g2;
  insert into guardrail_definicoes (workspace_id, nome, metrica, operador, limite, produto_id) values (ws, 'ROAS mínimo da mentoria', 'roas', 'min', 3, '00000000-0000-0000-0000-0000000000b2') returning id into g3;
  begin insert into guardrail_definicoes (workspace_id, nome, metrica, operador, limite) values (ws, 'x', 'churn_magico', 'max', 1); ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'métrica inválida aceita'; end if;
  -- cenário do curso → teste liga os guardrails gerais e os do curso
  insert into gm_cenarios (workspace_id, nome, escopo) values (ws, 'Curso', jsonb_build_object('prod', '00000000-0000-0000-0000-0000000000b1')) returning id into c;
  insert into growth_experimentos (workspace_id, titulo, etapa, cenario_id) values (ws, 'Teste curso', 'ideia', c) returning id into e;
  if exists (select 1 from exp_guardrails where experimento_id = e) then raise exception 'ligou antes de entrar em teste'; end if;
  update growth_experimentos set etapa = 'rodando' where id = e;
  if (select count(*) from exp_guardrails where experimento_id = e) <> 2 or exists (select 1 from exp_guardrails where experimento_id = e and guardrail_id = g3) then raise exception 'guardrails ligados ao teste: %', (select count(*) from exp_guardrails where experimento_id = e); end if;
  update growth_experimentos set etapa = 'analise' where id = e; update growth_experimentos set etapa = 'rodando' where id = e;
  if (select count(*) from exp_guardrails where experimento_id = e) <> 2 then raise exception 'religou duplicado'; end if;
  -- teste sem cenário: só os gerais... e os de produto não entram
  insert into growth_experimentos (workspace_id, titulo, etapa) values (ws, 'Teste geral', 'rodando') returning id into e2;
  if (select count(*) from exp_guardrails where experimento_id = e2) <> 1 then raise exception 'teste geral'; end if;
  -- alerta aberto único por teste e guardrail
  insert into guardrail_alertas (workspace_id, experimento_id, guardrail_id, data, valor, limite, severidade, mensagem) values (ws, e, g1, '2026-10-10', 350, 300, 'critico', 'CAC acima');
  begin insert into guardrail_alertas (workspace_id, experimento_id, guardrail_id, data, valor, limite, severidade, mensagem) values (ws, e, g1, '2026-10-11', 360, 300, 'critico', 'CAC acima'); ok := false; exception when unique_violation then ok := true; end;
  if not ok then raise exception 'alerta aberto duplicado'; end if;
  update guardrail_alertas set status = 'resolvido', resolvido_em = now() where experimento_id = e;
  insert into guardrail_alertas (workspace_id, experimento_id, guardrail_id, data, valor, limite, severidade, mensagem) values (ws, e, g1, '2026-10-12', 360, 300, 'critico', 'CAC acima de novo');
  -- observação única por dia e período
  insert into guardrail_observacoes (workspace_id, experimento_id, guardrail_id, data, periodo, valor, limite, situacao) values (ws, e, g1, '2026-10-11', 'durante', 350, 300, 'violado');
  begin insert into guardrail_observacoes (workspace_id, experimento_id, guardrail_id, data, periodo, valor, limite, situacao) values (ws, e, g1, '2026-10-11', 'durante', 340, 300, 'violado'); ok := false; exception when unique_violation then ok := true; end;
  if not ok then raise exception 'observação duplicada'; end if;
  if not exists (select 1 from acesso_telas where tela = 'gro-guard') or not (select telas @> array['gro-guard', 'gro-result'] from pacotes_acesso where nome = 'Consultoria') then raise exception 'telas no catálogo'; end if;
  raise notice 'v0.100: guardrails OK';
end $$;
