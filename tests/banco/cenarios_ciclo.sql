-- v0.107: descartar e reabrir cenário, aprovado não descarta, link da documentação do teste. Rodar depois de decisao_cenarios (v0.99) e v0.107 (2x).
do $$
declare ws uuid := '00000000-0000-0000-0000-0000000000a1'; c uuid; a uuid; e uuid; ok boolean;
begin
  insert into gm_cenarios (workspace_id, nome) values (ws, 'Descartável') returning id into c;
  update gm_cenarios set status = 'arquivado', descarte = jsonb_build_object('motivo', 'ice_baixo', 'obs', 'rever em março', 'em', now()) where id = c;
  if (select descarte ->> 'motivo' from gm_cenarios where id = c) <> 'ice_baixo' then raise exception 'descarte não gravou'; end if;
  update gm_cenarios set status = 'rascunho', descarte = null where id = c;
  if (select status from gm_cenarios where id = c) <> 'rascunho' then raise exception 'não reabriu'; end if;
  begin update gm_cenarios set descarte = '"texto"' where id = c; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'descarte aceitou não-objeto'; end if;
  -- aprovado: não descarta
  insert into gm_cenarios (workspace_id, nome) values (ws, 'Aprovado') returning id into a;
  update gm_cenarios set status = 'aprovado', aprovado_em = now() where id = a;
  begin update gm_cenarios set status = 'arquivado', descarte = '{"motivo":"x"}' where id = a; ok := false; exception when others then ok := sqlerrm like '%congelado%'; end;
  if not ok then raise exception 'aprovado foi descartado'; end if;
  begin delete from gm_cenarios where id = a; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'aprovado foi excluído'; end if;
  -- link da documentação
  insert into growth_experimentos (workspace_id, titulo, etapa, impacto, confianca, facilidade, cenario_id) values (ws, 'Teste', 'rodando', 5, 5, 5, a) returning id into e;
  update growth_experimentos set link_doc = 'https://notion.so/teste' where id = e;
  begin update growth_experimentos set link_doc = 'notion.so/sem-protocolo' where id = e; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'link sem http aceito'; end if;
  raise notice 'cenarios_ciclo: tudo OK';
end $$;
