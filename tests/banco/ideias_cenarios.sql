-- v0.109: chaves para a IA gravar ideias. Rodar depois de ideias_base.sql, 20261006200000_conteudo.sql e 20261012300000_ideias_chatgpt.sql (2x).
do $$
declare a uuid := '00000000-0000-0000-0000-0000000000c1'; b uuid := '00000000-0000-0000-0000-0000000000c2';
  k text; k2 text; r jsonb; ok boolean; cid uuid; t1 uuid;
begin
  insert into conteudo_temas (workspace_id, nome, prioridade) values (a, 'Bastidores da mentoria', 1) returning id into t1;
  insert into conteudo_temas (workspace_id, nome, prioridade) values (a, 'Erros de lançamento', 2), (b, 'Tema do B', 1);
  -- gerar chave: precisa estar logado e poder editar o Marketing
  perform set_config('t.uid', '', true);
  begin k := chave_api_criar(a, 'ChatGPT'); ok := false; exception when others then ok := sqlerrm like '%Marketing%'; end;
  if not ok then raise exception 'gerou chave sem login'; end if;
  perform set_config('t.uid', '00000000-0000-0000-0000-00000000aaaa', true); perform set_config('t.perm', 'nao', true);
  begin k := chave_api_criar(a, 'ChatGPT'); ok := false; exception when others then ok := sqlerrm like '%Marketing%'; end;
  if not ok then raise exception 'gerou chave sem permissão'; end if;
  perform set_config('t.perm', 'sim', true);
  k := chave_api_criar(a, 'ChatGPT do celular');
  if k !~ '^gw_[0-9a-f]{64}$' then raise exception 'formato da chave: %', k; end if;
  if (select count(*) from chaves_api where hash = chave_api_hash(k) and prefixo = left(k, 9)) <> 1 then raise exception 'hash não gravado'; end if;
  if exists (select 1 from chaves_api where hash = k or prefixo = k) then raise exception 'chave em texto no banco'; end if;
  -- ideia completa
  r := ideia_por_chave(k, '  Os 3 erros que matam um lançamento  ', 'Ângulo: contar o que deu errado no nosso', 'Reel', 'erros de lançamento', array['Instagram', 'tiktok', 'orkut']);
  cid := (r ->> 'id')::uuid;
  if not (r ->> 'ok')::boolean then raise exception 'não criou'; end if;
  if (select status || '|' || origem || '|' || formato || '|' || workspace_id::text || '|' || titulo from conteudos where id = cid) <> 'ideia|ia|reels|' || a || '|Os 3 erros que matam um lançamento' then
    raise exception 'conteúdo errado: %', (select row_to_json(c) from conteudos c where id = cid); end if;
  if (select canais from conteudos where id = cid) @> array['instagram', 'tiktok'] is not true or (select cardinality(canais) from conteudos where id = cid) <> 2 then raise exception 'canais: %', (select canais from conteudos where id = cid); end if;
  if (select tema_id from conteudos c where id = cid) is distinct from (select id from conteudo_temas where workspace_id = a and nome = 'Erros de lançamento') then raise exception 'tema não casou'; end if;
  -- tema parcial, formato desconhecido e sem canais
  r := ideia_por_chave(k, 'Um dia na mentoria', null, 'podcast', 'bastidores', null);
  if (select formato || '|' || coalesce(tema_id::text, '-') || '|' || cardinality(canais) from conteudos where id = (r ->> 'id')::uuid) <> 'carrossel|' || t1 || '|0' then raise exception 'padrões: %', r; end if;
  -- tema de outro workspace nunca é usado
  r := ideia_por_chave(k, 'Outra', null, null, 'Tema do B', null);
  if (select tema_id from conteudos where id = (r ->> 'id')::uuid) is not null then raise exception 'usou tema do outro workspace'; end if;
  -- título obrigatório
  begin r := ideia_por_chave(k, '   ', null, null, null, null); ok := false; exception when others then ok := sqlerrm like '%título%'; end;
  if not ok then raise exception 'aceitou sem título'; end if;
  -- contexto
  r := ideias_por_chave_contexto(k);
  if r ->> 'workspace' <> 'Conteúdo A' or jsonb_array_length(r -> 'temas') <> 2 or jsonb_array_length(r -> 'ultimas_ideias') <> 3 or r -> 'temas' ->> 0 <> 'Bastidores da mentoria' then raise exception 'contexto: %', r; end if;
  if (select usos from chaves_api where hash = chave_api_hash(k)) <> 4 then raise exception 'usos: %', (select usos from chaves_api where hash = chave_api_hash(k)); end if;
  -- chave errada
  begin r := ideia_por_chave('gw_' || repeat('0', 64), 'x'); ok := false; exception when others then ok := sqlerrm like '%inválida%'; end;
  if not ok then raise exception 'aceitou chave errada'; end if;
  -- chave de outro workspace só grava no dele
  k2 := chave_api_criar(b, 'Outro');
  r := ideia_por_chave(k2, 'Ideia do B');
  if (select workspace_id from conteudos where id = (r ->> 'id')::uuid) <> b then raise exception 'workspace errado'; end if;
  -- revogar
  perform chave_api_revogar((select id from chaves_api where hash = chave_api_hash(k)));
  begin r := ideia_por_chave(k, 'depois de revogar'); ok := false; exception when others then ok := sqlerrm like '%revogada%'; end;
  if not ok then raise exception 'chave revogada ainda grava'; end if;
  begin r := ideias_por_chave_contexto(k); ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'chave revogada ainda lê'; end if;
  raise notice 'ideias_cenarios: tudo OK';
end $$;
-- quem não está logado (anon) não lê a tabela de chaves nem chama as funções internas
set role anon;
do $$ declare ok boolean; begin
  begin perform 1 from chaves_api limit 1; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'anon leu chaves_api'; end if;
  begin perform chave_api_ws('x'); ok := false; exception when others then ok := sqlerrm like '%permission%' or sqlerrm like '%permissão%'; end;
  if not ok then raise exception 'anon chamou chave_api_ws'; end if;
  begin perform chave_api_criar('00000000-0000-0000-0000-0000000000c1', 'x'); ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'anon gerou chave'; end if;
  raise notice 'ideias_cenarios (anon): tudo OK';
end $$;
reset role;
