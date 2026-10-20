-- v0.99: aprovação, documento de decisão, ideia do cenário sem duplicar, planejamento. Rodar depois de gm_base, v0.98, decisao_base e v0.99 (2x).
do $$
declare ws uuid := '00000000-0000-0000-0000-0000000000a1'; c uuid; d uuid; e1 uuid; e2 uuid; p uuid; ok boolean;
begin
  delete from admins;
  insert into gm_cenarios (workspace_id, nome) values (ws, 'Aprovar') returning id into c;
  insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values (ws, 'campanha:x', 'tkt', '2026-12-01', c::text, 1500);
  begin perform gm_aprovar(c, 'Rebecka', 'rodar', '{}'); ok := false; exception when others then ok := sqlerrm like '%administrador%'; end;
  if not ok then raise exception 'não-admin aprovou'; end if;
  insert into admins values (ws);
  begin perform gm_aprovar(c, 'Rebecka', 'rodar', '{}'); ok := false; exception when others then ok := sqlerrm like '%hipótese%'; end;
  if not ok then raise exception 'aprovou sem hipótese'; end if;
  update gm_cenarios set hipotese = 'Ticket maior' where id = c;
  begin perform gm_aprovar(c, 'Rebecka', 'rodar', '{}'); ok := false; exception when others then ok := sqlerrm like '%ICE%'; end;
  if not ok then raise exception 'aprovou sem ICE'; end if;
  update gm_cenarios set impacto = 8, confianca = 6, facilidade = 7 where id = c;
  begin perform gm_aprovar(c, 'Rebecka', 'rodar', '{"guardrails":[{"severidade":"critico","situacao":"violado"}]}'); ok := false; exception when others then ok := sqlerrm like '%guardrail crítico%'; end;
  if not ok then raise exception 'guardrail crítico ignorado'; end if;
  d := gm_aprovar(c, 'Rebecka', 'rodar 30 dias', '{"guardrails":[{"severidade":"critico","situacao":"violado"}],"justificativa_risco":"risco aceito por 30 dias"}');
  if (select status from gm_cenarios where id = c) <> 'aprovado' then raise exception 'não congelou'; end if;
  if (select documento -> 'ice' ->> 'score' from gm_decisoes where id = d)::numeric <> 7 or jsonb_array_length((select documento -> 'inputs_gravados' from gm_decisoes where id = d)) <> 1 then raise exception 'documento incompleto'; end if;
  begin update gm_decisoes set titulo = 'x' where id = d; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'documento mudou'; end if;
  begin perform gm_aprovar(c, 'Rebecka', 'de novo', '{}'); ok := false; exception when others then ok := sqlerrm like '%rascunho%'; end;
  if not ok then raise exception 'aprovou duas vezes'; end if;
  -- ideia sem duplicar
  e1 := gm_ideia_do_cenario(c); e2 := gm_ideia_do_cenario(c);
  if e1 <> e2 or (select count(*) from growth_experimentos where cenario_id = c) <> 1 then raise exception 'ideia duplicada'; end if;
  if (select etapa from growth_experimentos where id = e1) <> 'priorizado' or (select decisao_id from growth_experimentos where id = e1) <> d or (select score from growth_experimentos where id = e1) <> 7 then raise exception 'ideia do cenário aprovado'; end if;
  -- colunas novas do Kanban
  update growth_experimentos set etapa = 'avaliacao' where id = e1; update growth_experimentos set etapa = 'arquivado' where titulo = 'Antigo';
  -- planejamento
  p := exp_para_planejamento(e1);
  if (select tipo from growth_experimentos where id = e1) <> 'planejamento' or (select projeto_id from growth_experimentos where id = e1) <> p or (select etapa from growth_experimentos where id = e1) <> 'preparacao' then raise exception 'planejamento'; end if;
  if exp_para_planejamento(e1) <> p or (select count(*) from projetos) <> 1 then raise exception 'planejamento duplicado'; end if;
  raise notice 'v0.99: decisão e Kanban OK';
end $$;
