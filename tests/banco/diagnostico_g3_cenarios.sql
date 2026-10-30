-- v0.177 (Diagnóstico 360°, G3): reunião do diagnóstico.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "diagnostico_g3: tudo OK".
do $t$
declare ws uuid; ws2 uuid; pe uuid; pq uuid; q1 uuid; env uuid; tok text; r uuid; dg uuid; dm uuid;
begin
  ws := provisionar_workspace('Diag G3'); ws2 := provisionar_workspace('Outra G3');
  insert into pessoas (workspace_id, nome, email) values (ws, 'Cliente G3', 'g3@diag.com') returning id into pe;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'Diagnóstico', 'diagnostico', 'manual', true, 'cliente') returning id into pq;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria) values (ws, pq, 1, 'Nome da empresa', 'texto', true) returning id into q1;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning id, token into env, tok;
  perform pesquisa_responder(tok, jsonb_build_object(q1::text, 'Escola Aurora'), null);
  select id into r from pesquisa_respostas where pesquisa_id = pq;

  -- pesquisa, envio e pessoa vêm da resposta, mesmo se a tela mandar outros
  insert into diagnosticos (workspace_id, resposta_id, pessoa_id, decide, arquitetura) values (ws, r, null, array['cac', 'leads'], '{"ns": "Sim"}') returning id into dg;
  if (select pessoa_id from diagnosticos where id = dg) <> pe or (select envio_id from diagnosticos where id = dg) <> env or (select pesquisa_id from diagnosticos where id = dg) <> pq then raise exception 'X: dados da resposta'; end if;
  -- um diagnóstico por resposta
  begin insert into diagnosticos (workspace_id, resposta_id) values (ws, r); raise exception 'X: dois diagnósticos na mesma resposta';
  exception when unique_violation then null; end;
  -- empresa diferente da resposta é recusada
  begin update diagnosticos set workspace_id = ws2 where id = dg; raise exception 'X: diagnóstico mudou de empresa';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- validar marca a data; voltar a rascunho limpa
  update diagnosticos set status = 'validado' where id = dg;
  if (select validado_em from diagnosticos where id = dg) is null then raise exception 'X: validado_em'; end if;
  update diagnosticos set status = 'rascunho' where id = dg;
  if (select validado_em from diagnosticos where id = dg) is not null then raise exception 'X: rascunho limpa a validação'; end if;
  begin update diagnosticos set status = 'pronto' where id = dg; raise exception 'X: situação inválida';
  exception when check_violation then null; end;
  begin update diagnosticos set arquitetura = '[]' where id = dg; raise exception 'X: arquitetura em lista';
  exception when check_violation then null; end;
  -- métricas: uma por código, da mesma empresa
  insert into diagnostico_metricas (workspace_id, diagnostico_id, codigo, declarado, detalhe, decide)
    values (ws, dg, 'cac', '{"status": "regular", "como": ["Planilha"]}', '{"numerador": "Investimento", "denominador": "Clientes novos", "responsavel": "Ana"}', true) returning id into dm;
  insert into diagnostico_metricas (workspace_id, diagnostico_id, codigo, detalhe) values (ws, dg, 'cac', '{"janela": "Mês"}')
    on conflict (diagnostico_id, codigo) do update set detalhe = diagnostico_metricas.detalhe || excluded.detalhe;
  if (select detalhe ->> 'janela' from diagnostico_metricas where id = dm) <> 'Mês' or (select detalhe ->> 'responsavel' from diagnostico_metricas where id = dm) <> 'Ana' then raise exception 'X: upsert da métrica'; end if;
  begin insert into diagnostico_metricas (workspace_id, diagnostico_id, codigo) values (ws2, dg, 'leads'); raise exception 'X: métrica de outra empresa';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- leitura dos documentos guardada no diagnóstico
  update diagnosticos set leitura = jsonb_build_object('score', 46, 'itens', jsonb_build_array(jsonb_build_object('titulo', 'Investimento', 'status', 'falta')), 'mensagem', 'Oi!') where id = dg;
  if (select leitura ->> 'score' from diagnosticos where id = dg) <> '46' then raise exception 'X: leitura'; end if;
  -- apagar a resposta apaga o diagnóstico e as métricas
  delete from pesquisa_respostas where id = r;
  if exists (select 1 from diagnosticos where id = dg) or exists (select 1 from diagnostico_metricas where id = dm) then raise exception 'X: cascata'; end if;
  raise notice 'diagnostico_g3: tudo OK';
end $t$;
do $t$ begin
  if (select count(*) from pg_policies where tablename in ('diagnosticos', 'diagnostico_metricas')) <> 10 then raise exception 'X: políticas (%)', (select count(*) from pg_policies where tablename in ('diagnosticos', 'diagnostico_metricas')); end if;
end $t$;
select 'diagnostico_g3: tudo OK' as resultado;
