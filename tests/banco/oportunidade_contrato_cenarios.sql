-- v0.174 (E2): oportunidade → contrato. Roda sobre o banco com todas as migrations (ver tests/banco/LEIA.md). Termina com "oportunidade_contrato: tudo OK".
do $t$
declare ws uuid; pe uuid; pe2 uuid; pr uuid; o1 uuid; o2 uuid; o3 uuid; c1 uuid; c2 uuid; n int;
begin
  ws := provisionar_workspace('E2 oportunidade');
  insert into pessoas (workspace_id, nome, email) values (ws, 'Lead Ana', 'ana@e2.com') returning id into pe;
  insert into pessoas (workspace_id, nome, email) values (ws, 'Outro', 'outro@e2.com') returning id into pe2;
  insert into produtos (workspace_id, nome, tag, tipo, preco) values (ws, 'Consultoria', 'consultoria', 'servico', 9000) returning id into pr;
  if (select negocio_status from pessoas where id = pe) <> 'aberto' then raise exception 'X: lead nasce com negócio aberto'; end if;

  -- oportunidade de venda nova aberta a partir do CRM
  insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, produto_id, valor_estimado, origem) values (ws, pe, 'Consultoria 90 dias', 'nova_venda', pr, 9000, 'crm') returning id into o1;
  -- duas propostas (contratos em rascunho) na mesma oportunidade
  insert into contratos (workspace_id, pessoa_id, data_inicio, num_parcelas, oportunidade_id) values (ws, pe, current_date, 3, o1) returning id into c1;
  insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values (ws, c1, pr, 1, 9000);
  insert into contratos (workspace_id, pessoa_id, data_inicio, num_parcelas, recorrente, periodicidade, oportunidade_id) values (ws, pe, current_date, 12, true, 'mensal', o1) returning id into c2;
  insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values (ws, c2, pr, 1, 1500);
  if (select count(*) from contratos where oportunidade_id = o1) <> 2 then raise exception 'X: dois contratos por oportunidade'; end if;
  -- contrato de outra pessoa não pode apontar para a oportunidade
  begin insert into contratos (workspace_id, pessoa_id, data_inicio, num_parcelas, oportunidade_id) values (ws, pe2, current_date, 1, o1); raise exception 'X: contrato de outra pessoa na oportunidade';
  exception when raise_exception then if sqlerrm like 'X:%' then raise; end if; end;
  -- ativar a primeira proposta: a oportunidade vira ganha e o negócio da pessoa, ganho
  perform ativar_contrato(c1);
  if (select status from oportunidades where id = o1) <> 'ganha' or (select fechado_em from oportunidades where id = o1) is null then raise exception 'X: ativar não ganhou a oportunidade'; end if;
  if (select negocio_status from pessoas where id = pe) <> 'ganho' then raise exception 'X: negócio da pessoa não ficou ganho'; end if;
  if (select count(*) from contas_receber where contrato_id = c1) <> 3 then raise exception 'X: parcelas do contrato'; end if;
  -- ativar a segunda (mensalidade) não muda nada na oportunidade já ganha
  perform ativar_contrato(c2);
  if (select status from oportunidades where id = o1) <> 'ganha' then raise exception 'X: segunda ativação'; end if;

  -- outra pessoa: perde a única oportunidade → negócio perdido; reabre → aberto
  insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, origem) values (ws, pe2, 'Mentoria', 'nova_venda', 'crm') returning id into o2;
  update oportunidades set status = 'perdida', fechado_em = now(), motivo = 'Preço' where id = o2;
  if (select negocio_status from pessoas where id = pe2) <> 'perdido' then raise exception 'X: perder a única oportunidade não marcou perdido'; end if;
  update oportunidades set status = 'aberta', fechado_em = null where id = o2;
  if (select negocio_status from pessoas where id = pe2) <> 'aberto' then raise exception 'X: reabrir não voltou o negócio para aberto'; end if;
  -- com outra oportunidade aberta, perder uma não marca perdido
  insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, origem) values (ws, pe2, 'Curso', 'nova_venda', 'crm') returning id into o3;
  update oportunidades set status = 'perdida', fechado_em = now() where id = o2;
  if (select negocio_status from pessoas where id = pe2) <> 'aberto' then raise exception 'X: perdeu uma, mas outra está aberta'; end if;
  -- oportunidade de expansão não mexe no negócio do lead
  update pessoas set negocio_status = 'aberto' where id = pe2;
  insert into oportunidades (workspace_id, pessoa_id, titulo, tipo) values (ws, pe2, 'Upsell', 'expansao') returning id into o2;
  update oportunidades set status = 'ganha', fechado_em = now() where id = o2;
  if (select negocio_status from pessoas where id = pe2) <> 'aberto' then raise exception 'X: expansão mexeu no negócio do lead'; end if;
  -- origem fora da lista continua recusada
  begin insert into oportunidades (workspace_id, pessoa_id, titulo, tipo, origem) values (ws, pe2, 'x', 'nova_venda', 'qualquer'); raise exception 'X: origem inválida aceita';
  exception when check_violation then null; end;
  raise notice 'oportunidade_contrato: tudo OK';
end $t$;
select 'oportunidade_contrato: tudo OK' as resultado;
