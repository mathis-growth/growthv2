-- v0.98: cenários do Growth Model. Rodar depois de gm_base.sql e da migração (duas vezes).
do $$
declare ws uuid := '00000000-0000-0000-0000-0000000000a1'; c1 uuid; c2 uuid; ok boolean; n int;
begin
  select id into c1 from gm_cenarios where workspace_id = ws and nome = 'Cenário 1';
  if c1 is null or (select count(*) from gm_cenarios where nome = 'Cenário 1') <> 1 then raise exception 'Cenário 1 não criado (ou duplicado na 2ª rodada)'; end if;
  if (select count(*) from gm_alavancas where cenario = c1::text) <> 2 or exists (select 1 from gm_alavancas where cenario = 'sim') then raise exception 'sim → Cenário 1'; end if;
  if not exists (select 1 from gm_cenarios where nome = 'Base UE' and ue ->> 'fixos' is not null) then raise exception 'cenário do Unit Economics não migrou'; end if;
  -- baseline travado
  begin insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values (ws, 'campanha:x', 'vol', '2026-12-01', 'base', 1); ok := false;
  exception when others then ok := sqlerrm like '%baseline está travado%'; end;
  if not ok then raise exception 'baseline deveria estar travado'; end if;
  begin update gm_alavancas set valor = 1 where cenario = 'base' and workspace_id = ws; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'update no baseline deveria falhar'; end if;
  -- só administrador e com motivo
  begin perform gm_premissas_salvar(ws, '[{"loop_chave":"campanha:x","alavanca":"tkt","mes":"2026-11-01","valor":950}]', '[]', 'ajuste'); ok := false; exception when others then ok := sqlerrm like '%administrador%'; end;
  if not ok then raise exception 'não-admin mudou premissa'; end if;
  insert into admins values (ws);
  begin perform gm_premissas_salvar(ws, '[{"loop_chave":"campanha:x","alavanca":"tkt","mes":"2026-11-01","valor":950}]', '[]', ' '); ok := false; exception when others then ok := sqlerrm like '%motivo%'; end;
  if not ok then raise exception 'premissa sem motivo'; end if;
  n := gm_premissas_salvar(ws, '[{"loop_chave":"campanha:x","alavanca":"tkt","mes":"2026-11-01","valor":950}]', '[]', 'ticket médio revisado');
  if (select valor from gm_alavancas where cenario = 'base' and workspace_id = ws and alavanca = 'tkt') <> 950 or (select count(*) from gm_alavancas where cenario = 'base' and workspace_id = ws) <> 1 then raise exception 'premissa salva'; end if;
  perform gm_premissas_salvar(ws, '[]', '[{"loop_chave":"campanha:x","alavanca":"tkt","mes":"2026-11-01"}]', 'volta ao calculado');
  if exists (select 1 from gm_alavancas where cenario = 'base' and workspace_id = ws) then raise exception 'premissa removida'; end if;
  -- cenário rascunho aceita ajuste; aprovado congela
  insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values (ws, 'campanha:x', 'vol', '2026-12-01', c1::text, 6000);
  update gm_cenarios set status = 'aprovado', aprovado_em = now() where id = c1;
  begin insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values (ws, 'campanha:x', 'tkt', '2026-12-01', c1::text, 1); ok := false; exception when others then ok := sqlerrm like '%aprovado%'; end;
  if not ok then raise exception 'cenário aprovado aceitou ajuste'; end if;
  begin update gm_cenarios set nome = 'mexido' where id = c1; ok := false; exception when others then ok := sqlerrm like '%congelado%'; end;
  if not ok then raise exception 'cenário aprovado mudou'; end if;
  begin delete from gm_cenarios where id = c1; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'cenário aprovado excluído'; end if;
  update gm_cenarios set status = 'arquivado' where id = c1;
  begin update gm_cenarios set status = 'rascunho' where id = c1; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'arquivado aprovado voltou a rascunho'; end if;
  begin insert into gm_alavancas (workspace_id, loop_chave, alavanca, mes, cenario, valor) values (ws, 'x', 'vol', '2026-12-01', 'qualquer', 1); ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'cenário inválido aceito'; end if;
  if (select count(*) from simulador_snapshots) <> 1 or not exists (select 1 from pg_constraint where conname = 'simulador_snapshots_gm_cenario_fk') then raise exception 'fotos do UE'; end if;
  -- rascunho pode ser excluído
  insert into gm_cenarios (workspace_id, nome) values (ws, 'Teste') returning id into c2; delete from gm_cenarios where id = c2;
  raise notice 'v0.98: cenários do Growth Model OK';
end $$;
