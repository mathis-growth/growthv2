-- v0.177 (Diagnóstico 360°, G1b): natureza das métricas e rascunho do link individual.
-- Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "diagnostico_g1b: tudo OK".
do $t$
declare ws uuid; pe uuid; pq uuid; pq2 uuid; q1 uuid; env uuid; tok text; tok2 text; d jsonb;
begin
  -- natureza
  if (select natureza from metricas_definicoes where codigo = 'investimento') <> 'valor' or (select natureza from metricas_definicoes where codigo = 'cac') <> 'taxa'
     or (select natureza from metricas_definicoes where codigo = 'receita') <> 'valor' or (select natureza from metricas_definicoes where codigo = 'churn') <> 'taxa' then raise exception 'X: natureza'; end if;
  if exists (select 1 from metricas_definicoes where etapa_aarrr is not null and natureza is null) then raise exception 'X: métrica do funil sem natureza'; end if;
  begin update metricas_definicoes set natureza = 'outra' where codigo = 'cac'; raise exception 'X: natureza inválida aceita';
  exception when check_violation then null; end;

  ws := provisionar_workspace('Diag G1b');
  insert into pessoas (workspace_id, nome, email) values (ws, 'Cliente G1b', 'g1b@diag.com') returning id into pe;
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'Diagnóstico curto', 'diagnostico', 'manual', true, 'cliente') returning id into pq;
  insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao) values (ws, pq, 1, 'Nome da empresa', 'texto', true, 'Negócio') returning id into q1;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning id, token into env, tok;

  -- sem rascunho, o público devolve null
  d := pesquisa_publica(tok);
  if d -> 'rascunho' <> 'null'::jsonb then raise exception 'X: rascunho inicial'; end if;
  -- salva e volta
  perform pesquisa_rascunho_salvar(tok, jsonb_build_object('passo', 2, 'campos', jsonb_build_object('a', 'Escola Aurora')));
  d := pesquisa_publica(tok);
  if d -> 'rascunho' -> 'campos' ->> 'a' <> 'Escola Aurora' or (d -> 'rascunho' ->> 'passo')::int <> 2 then raise exception 'X: rascunho não voltou'; end if;
  if (select rascunho_em from pesquisa_envios where id = env) is null then raise exception 'X: rascunho_em'; end if;
  -- formato e tamanho
  begin perform pesquisa_rascunho_salvar(tok, '[1]'::jsonb); raise exception 'X: rascunho em lista aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_rascunho_salvar(tok, jsonb_build_object('x', repeat('a', 400001))); raise exception 'X: rascunho grande aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  begin perform pesquisa_rascunho_salvar('curto', '{}'::jsonb); raise exception 'X: token curto aceito';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- depois de responder: não salva mais e o público não devolve o rascunho
  perform pesquisa_responder(tok, jsonb_build_object(q1::text, 'Escola Aurora'), null);
  begin perform pesquisa_rascunho_salvar(tok, '{"a": 1}'::jsonb); raise exception 'X: rascunho depois de responder';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- link vencido
  insert into pessoas (workspace_id, nome, email) values (ws, 'Vencido', 'venc@diag.com') returning id into pe;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq, pe, 'manual') returning id, token into env, tok2;
  update pesquisa_envios set expira_em = now() - interval '1 day' where id = env;
  begin perform pesquisa_rascunho_salvar(tok2, '{"a": 1}'::jsonb); raise exception 'X: rascunho em link vencido';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  -- pesquisa que não é diagnóstico não guarda rascunho
  insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa, publico) values (ws, 'Onboarding', 'onboarding', 'manual', true, 'cliente') returning id into pq2;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (ws, pq2, pe, 'manual') returning token into tok2;
  begin perform pesquisa_rascunho_salvar(tok2, '{"a": 1}'::jsonb); raise exception 'X: rascunho fora do diagnóstico';
  exception when others then if sqlerrm like 'X:%' then raise; end if; end;
  raise notice 'diagnostico_g1b: tudo OK';
end $t$;
select 'diagnostico_g1b: tudo OK' as resultado;
