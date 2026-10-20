-- v0.97: cenários das ofertas, esteira e campanha. Rodar depois de ofertas_base.sql e da migração (duas vezes).
do $$
declare ws uuid := '00000000-0000-0000-0000-0000000000a1'; c uuid := '00000000-0000-0000-0000-0000000000c1';
  pc uuid := '00000000-0000-0000-0000-0000000000b1'; pm uuid := '00000000-0000-0000-0000-0000000000b2'; pe uuid := '00000000-0000-0000-0000-0000000000b3';
  o uuid; b uuid; pr uuid; bump uuid; up uuid; down uuid; r jsonb; ok boolean;
begin
  -- backfill
  if (select count(*) from oferta_itens) <> 2 or (select count(*) from oferta_versoes) <> 2 then raise exception 'backfill de itens/versões'; end if;
  if (select status from ofertas where id = '00000000-0000-0000-0000-0000000000d2') <> 'pausada' then raise exception 'status da oferta inativa'; end if;
  if (select tipo from canais where codigo = 'meta_ads') <> 'pago' or (select tipo from canais where codigo = 'instagram') <> 'organico' or (select tipo from canais where codigo = 'google') <> 'pago' then raise exception 'tipo dos canais'; end if;
  if (select count(*) from campanha_canais where tipo is null) > 0 then raise exception 'tipo da execução'; end if;
  if not exists (select 1 from campanha_estrategias where campanha_id = c and principal) then raise exception 'estratégia principal'; end if;
  -- oferta nova: bundle precisa somar 100%
  begin perform oferta_salvar(ws, null, '{"nome":"Combo","preco":1500}', jsonb_build_array(jsonb_build_object('produto_id', pc, 'alocacao_pct', 60), jsonb_build_object('produto_id', pm, 'alocacao_pct', 30))); ok := false;
  exception when others then ok := sqlerrm like '%somar 100%'; end;
  if not ok then raise exception 'bundle sem 100%% deveria falhar'; end if;
  b := oferta_salvar(ws, null, '{"nome":"Combo","preco":1500,"condicoes":"12x"}', jsonb_build_array(jsonb_build_object('produto_id', pc, 'alocacao_pct', 70), jsonb_build_object('produto_id', pm, 'alocacao_pct', 30)));
  if (select versao from ofertas where id = b) <> 1 or (select count(*) from oferta_itens where oferta_id = b) <> 2 then raise exception 'bundle v1'; end if;
  -- salvar sem mudar nada não cria versão; mudar o preço cria
  perform oferta_salvar(ws, b, '{"nome":"Combo","preco":1500,"condicoes":"12x"}', jsonb_build_array(jsonb_build_object('produto_id', pc, 'alocacao_pct', 70), jsonb_build_object('produto_id', pm, 'alocacao_pct', 30)));
  if (select count(*) from oferta_versoes where oferta_id = b) <> 1 then raise exception 'salvar igual não deveria versionar'; end if;
  perform oferta_salvar(ws, b, '{"nome":"Combo","preco":1297,"condicoes":"12x"}', jsonb_build_array(jsonb_build_object('produto_id', pc, 'alocacao_pct', 70), jsonb_build_object('produto_id', pm, 'alocacao_pct', 30)));
  if (select versao from ofertas where id = b) <> 2 or (select preco from oferta_versoes where oferta_id = b and versao = 1) <> 1500 then raise exception 'versão 2 e histórico'; end if;
  begin update oferta_versoes set preco = 1 where oferta_id = b; ok := false; exception when others then ok := true; end;
  if not ok then raise exception 'versão deveria ser imutável'; end if;
  -- um produto só: alocação vira 100
  o := oferta_salvar(ws, null, '{"nome":"Mentoria upsell","preco":3000}', jsonb_build_array(jsonb_build_object('produto_id', pm, 'alocacao_pct', 10)));
  if (select alocacao_pct from oferta_itens where oferta_id = o) <> 100 then raise exception 'item único 100%%'; end if;
  -- esteira: principal, bump, upsell, downsell após recusa
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, oferta_id, oferta_versao, nome, papel, preco, ordem) values (ws, c, pc, '00000000-0000-0000-0000-0000000000d1', 1, 'Curso', 'principal', 997, 0) returning id into pr;
  begin insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco) values (ws, c, pm, 'Outra', 'principal', 1); ok := false; exception when others then ok := sqlerrm like '%já tem uma oferta principal%'; end;
  if not ok then raise exception 'duas principais'; end if;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, pai_id, condicao, ordem) values (ws, c, pe, 'E-book', 'order_bump', 47, pr, 'sempre', 1) returning id into bump;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, pai_id, condicao, ordem) values (ws, c, pm, 'Mentoria', 'upsell', 3000, pr, 'aceitou', 2) returning id into up;
  begin insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, pai_id, condicao) values (ws, c, pm, 'Down', 'downsell', 1500, up, 'aceitou'); ok := false; exception when others then ok := sqlerrm like '%recusa%'; end;
  if not ok then raise exception 'downsell sem recusa'; end if;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, pai_id, condicao, ordem) values (ws, c, pe, 'Mentoria lite', 'downsell', 500, up, 'recusou', 3) returning id into down;
  begin insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, pai_id, condicao) values (ws, c, pe, 'Bump errado', 'order_bump', 10, up, 'aceitou'); ok := false; exception when others then ok := sqlerrm like '%checkout%'; end;
  if not ok then raise exception 'bump fora do checkout'; end if;
  begin update campanha_ofertas set pai_id = down, condicao = 'aceitou' where id = up; ok := false; exception when others then ok := sqlerrm like '%ciclo%'; end;
  if not ok then raise exception 'ciclo não detectado'; end if;
  -- vendas: 100 cursos, 20 e-books (bump), 10 mentorias (upsell). Downsell: 90 recusaram; 9 compraram (produto e-book já contado — usa o mesmo produto: aqui só checa o denominador)
  insert into vendas (workspace_id, campanha_id, produto_id, status, valor_bruto) select ws, c, pc, 'aprovada', 997 from generate_series(1, 100);
  insert into vendas (workspace_id, campanha_id, produto_id, status, valor_bruto) select ws, c, pm, 'aprovada', 3000 from generate_series(1, 10);
  r := campanha_ofertas_resultado(ws, c);
  if (select (e ->> 'base_aceite')::numeric from jsonb_array_elements(r) e where e ->> 'id' = up::text) <> 100 then raise exception 'denominador do upsell: %', r; end if;
  if (select (e ->> 'aceite')::numeric from jsonb_array_elements(r) e where e ->> 'id' = up::text) <> 10 then raise exception 'aceite do upsell: %', r; end if;
  if (select (e ->> 'base_aceite')::numeric from jsonb_array_elements(r) e where e ->> 'id' = down::text) <> 90 then raise exception 'denominador do downsell = quem recusou: %', r; end if;
  if (select (e ->> 'base_aceite')::numeric from jsonb_array_elements(r) e where e ->> 'id' = bump::text) <> 100 then raise exception 'denominador do bump: %', r; end if;
  -- trocar estratégia principal acompanha a lista N:N
  insert into funis (id, workspace_id, nome) values ('00000000-0000-0000-0000-0000000000f2', ws, 'Perpétuo') on conflict do nothing;
  update campanhas set funil_id = '00000000-0000-0000-0000-0000000000f2' where id = c;
  if (select count(*) from campanha_estrategias where campanha_id = c) <> 2 or (select funil_id from campanha_estrategias where campanha_id = c and principal) <> '00000000-0000-0000-0000-0000000000f2' then raise exception 'estratégias N:N'; end if;
  raise notice 'v0.97: ofertas, esteira e campanha híbrida OK';
end $$;
