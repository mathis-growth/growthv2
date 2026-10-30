-- v0.177 (Diagnóstico 360°, G2): arquivos pelo link do diagnóstico.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "diagnostico_g2: tudo OK".
-- O Storage não existe no PGlite: aqui se testa o registro e as regras; o envio de verdade é conferido no Supabase.
do $t$
declare ws uuid; ws2 uuid; pe uuid; pq uuid; pq2 uuid; env uuid; tok text; tok2 text; a jsonb; b jsonb; c text; n int; l jsonb;
begin
  ws := provisionar_workspace('Diag G2');
  insert into pessoas (workspace_id, nome, email) values (ws, 'Cliente G2', 'g2@diag.com') returning id into pe;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'Diagnóstico', 'diagnostico', 'manual', true, 'cliente') returning id into pq;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning id, token into env, tok;

  -- autoriza: caminho dentro da empresa e do envio, com a extensão do arquivo
  a := pesquisa_arquivo_autorizar(tok, 'vendas', 'Vendas maio-out.XLSX', 52000, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  if a ->> 'caminho' not like ws || '/' || env || '/%.xlsx' then raise exception 'X: caminho %', a ->> 'caminho'; end if;
  if (select status from pesquisa_arquivos where id = (a ->> 'id')::uuid) <> 'pendente' or (select pessoa_id from pesquisa_arquivos where id = (a ->> 'id')::uuid) <> pe then raise exception 'X: registro pendente'; end if;
  -- pendente não aparece para o cliente
  if jsonb_array_length(pesquisa_arquivos_do_link(tok)) <> 0 then raise exception 'X: pendente aparece'; end if;
  if pesquisa_arquivo_caminho(tok, (a ->> 'id')::uuid) <> a ->> 'caminho' then raise exception 'X: caminho do pendente'; end if;
  perform pesquisa_arquivo_confirmar(tok, (a ->> 'id')::uuid);
  l := pesquisa_arquivos_do_link(tok);
  if jsonb_array_length(l) <> 1 or l -> 0 ->> 'nome' <> 'Vendas maio-out.XLSX' or l -> 0 ? 'caminho' then raise exception 'X: lista do link %', l; end if;
  -- confirmado não volta a ser confirmado nem dá caminho de pendente
  begin perform pesquisa_arquivo_caminho(tok, (a ->> 'id')::uuid); raise exception 'X: caminho de confirmado';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- nome com barra e controle é limpo
  b := pesquisa_arquivo_autorizar(tok, 'crm', '../../x/leads.csv', 10, 'text/csv');
  if (select nome from pesquisa_arquivos where id = (b ->> 'id')::uuid) <> '....xleads.csv' then raise exception 'X: nome limpo: %', (select nome from pesquisa_arquivos where id = (b ->> 'id')::uuid); end if;
  -- recusas: tipo, tamanho, grupo, token
  begin perform pesquisa_arquivo_autorizar(tok, 'vendas', 'virus.exe', 10, ''); raise exception 'X: .exe aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivo_autorizar(tok, 'vendas', 'sem_extensao', 10, ''); raise exception 'X: sem extensão aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivo_autorizar(tok, 'vendas', 'grande.pdf', 20971521, ''); raise exception 'X: maior que 20 MB aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivo_autorizar(tok, 'vendas', 'vazio.pdf', 0, ''); raise exception 'X: vazio aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivo_autorizar(tok, 'Vendas X', 'a.pdf', 10, ''); raise exception 'X: grupo inválido aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivo_autorizar(repeat('a', 40), 'vendas', 'a.pdf', 10, ''); raise exception 'X: token falso aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- limite de 40 por link
  for n in 1..38 loop perform pesquisa_arquivo_autorizar(tok, 'outros', 'p' || n || '.pdf', 10, ''); end loop;
  begin perform pesquisa_arquivo_autorizar(tok, 'outros', 'p41.pdf', 10, ''); raise exception 'X: 41º arquivo aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- pendentes antigos deixam de contar
  update pesquisa_arquivos set criado_em = now() - interval '2 days' where envio_id = env and nome like 'p%.pdf';
  perform pesquisa_arquivo_autorizar(tok, 'outros', 'depois.pdf', 10, '');
  if (select count(*) from pesquisa_arquivos where envio_id = env) <> 3 then raise exception 'X: limpeza dos pendentes antigos (%)', (select count(*) from pesquisa_arquivos where envio_id = env); end if;
  -- remover devolve o caminho e só vale para o próprio link
  insert into pessoas (workspace_id, nome, email) values (ws, 'Outro', 'outro@g2.com') returning id into pe;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning token into tok2;
  begin perform pesquisa_arquivo_remover(tok2, (a ->> 'id')::uuid); raise exception 'X: removeu arquivo de outro link';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  c := pesquisa_arquivo_remover(tok, (a ->> 'id')::uuid);
  if c <> a ->> 'caminho' or exists (select 1 from pesquisa_arquivos where id = (a ->> 'id')::uuid) then raise exception 'X: remover'; end if;
  -- depois de responder ainda manda o que faltou; vencido não
  update pesquisa_envios set status = 'respondido' where id = env;
  perform pesquisa_arquivo_autorizar(tok, 'vendas', 'faltou.csv', 10, '');
  update pesquisa_envios set expira_em = now() - interval '1 minute' where id = env;
  begin perform pesquisa_arquivo_autorizar(tok, 'vendas', 'tarde.csv', 10, ''); raise exception 'X: link vencido aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_arquivos_do_link(tok); raise exception 'X: lista em link vencido';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- só diagnóstico
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'NPS', 'jornada', 'manual', true, 'cliente') returning id into pq2;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq2, pe, 'manual') returning token into tok2;
  begin perform pesquisa_arquivo_autorizar(tok2, 'vendas', 'a.csv', 10, ''); raise exception 'X: arquivo fora do diagnóstico';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- quem não é da empresa não vê os registros
  ws2 := provisionar_workspace('Outra G2');
  if exists (select 1 from pesquisa_arquivos where workspace_id = ws2) then raise exception 'X: registros na outra empresa'; end if;
  raise notice 'diagnostico_g2: tudo OK';
end $t$;
-- o anônimo não chama as funções que só a função na nuvem usa
do $t$ begin
  if has_function_privilege('anon', 'public.pesquisa_arquivo_autorizar(text, text, text, bigint, text)', 'execute') then raise exception 'X: anon autoriza'; end if;
  if has_function_privilege('anon', 'public.pesquisa_arquivo_remover(text, uuid)', 'execute') then raise exception 'X: anon remove'; end if;
  if not has_function_privilege('anon', 'public.pesquisa_arquivos_do_link(text)', 'execute') then raise exception 'X: anon não lista'; end if;
  if has_table_privilege('authenticated', 'public.pesquisa_arquivos', 'insert') then raise exception 'X: authenticated grava registro'; end if;
end $t$;
select 'diagnostico_g2: tudo OK' as resultado;
