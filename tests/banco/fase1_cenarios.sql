\set ON_ERROR_STOP on
do $$
declare ws uuid := gen_random_uuid(); c uuid; p1 uuid; p2 uuid; p3 uuid; v1 uuid; f1 uuid; f2 uuid; j jsonb; n int; pc uuid;
begin
  insert into workspaces (id, nome) values (ws, 'F1');
  -- identidade
  p1 := pessoa_resolver(ws, 'Ana Souza', 'ANA@x.com ', '(11) 98888-7777');
  assert (select telefone_norm from pessoas where id = p1) = '5511988887777', 'telefone normalizado';
  p2 := pessoa_resolver(ws, 'Ana', null, '11 98888 7777');
  assert p2 = p1, 'mesmo telefone acha a mesma pessoa';
  p2 := pessoa_resolver(ws, 'Ana', 'ana@x.com', null);
  assert p2 = p1, 'mesmo e-mail acha a mesma pessoa';
  begin insert into pessoas (workspace_id, nome, telefone) values (ws, 'Outra', '+55 11 98888-7777'); assert false, 'telefone repetido deveria falhar';
  exception when unique_violation then null; end;
  -- duplicados por nome e mesclagem
  p3 := pessoa_resolver(ws, 'Ana  souza', 'ana.souza@y.com', null);
  update pessoas set email = null where id = p1;  -- p1 só com telefone, p3 só com e-mail
  assert exists (select 1 from v_pessoas_duplicadas where workspace_id = ws), 'sugere duplicado';
  insert into pessoa_lista values (ws, p1, '00000000-0000-0000-0000-000000000001'), (ws, p3, '00000000-0000-0000-0000-000000000001'), (ws, p3, '00000000-0000-0000-0000-000000000002');
  insert into pessoa_notas (workspace_id, pessoa_id, texto) values (ws, p3, 'nota');
  insert into vendas (workspace_id, pessoa_id, valor_bruto, valor_a_receber, id_externo, status) values (ws, p3, 100, 90, 'HX1', 'aprovada') returning id into v1;
  perform pessoas_mesclar(p1, p3, 'mesma pessoa');
  assert not exists (select 1 from pessoas where id = p3), 'removida apagada';
  assert (select email from pessoas where id = p1) = 'ana.souza@y.com', 'e-mail herdado';
  assert (select count(*) from pessoa_lista where pessoa_id = p1) = 2, 'listas juntadas sem repetir';
  assert (select pessoa_id from vendas where id = v1) = p1 and (select pessoa_id from pessoa_notas limit 1) = p1, 'venda e nota passaram';
  assert exists (select 1 from pessoas_mesclagens where pessoa_removida = p3 and dados_removida->>'nome' = 'Ana  souza'), 'histórico da junção';
  -- venda sem duplicar e evidência
  begin insert into vendas (workspace_id, pessoa_id, valor_bruto, id_externo) values (ws, p1, 1, 'HX1'); assert false, 'venda repetida deveria falhar';
  exception when unique_violation then null; end;
  assert (select comprador_email from vendas where id = v1) = 'ana.souza@y.com' and (select aprovada_em from vendas where id = v1) is not null, 'evidência gravada';
  update vendas set status = 'reembolsada' where id = v1;
  assert (select reembolsada_em from vendas where id = v1) is not null, 'reembolsada_em';
  update pessoas set email = 'novo@x.com' where id = p1; update vendas set comprador_email = 'trocado@x.com' where id = v1;
  assert (select comprador_email from vendas where id = v1) = 'ana.souza@y.com', 'evidência não muda';
  -- auditoria
  assert exists (select 1 from auditoria where tabela = 'vendas' and registro_id = v1 and acao = 'alteracao' and campos @> array['status'] and antes->>'status' = 'aprovada' and depois->>'status' = 'reembolsada'), 'auditoria da venda';
  assert exists (select 1 from auditoria where tabela = 'pessoas' and registro_id = p3 and acao = 'exclusao'), 'auditoria da exclusão';
  assert (select origem from auditoria order by id desc limit 1) = 'banco', 'origem banco';
  -- qualidade
  insert into vendas (workspace_id, pessoa_id, valor_bruto, valor_a_receber, status) values (ws, p1, 50, 50, 'aprovada');
  insert into metricas_anuncio_dia (workspace_id, data, impressoes, cliques, custo) values (ws, current_date - 5, 100, 150, 10), (ws, current_date - 2, 100, 5, 10);
  insert into metricas_anuncio_dia (workspace_id, data, impressoes, cliques, custo, disponibilidade) values (ws, current_date - 1, 0, 0, 0, 'parcial');
  j := qualidade_dados(ws, current_date - 10, current_date);
  assert j @> '[{"codigo":"cliques_maior_impressoes"}]', 'cliques > impressões: ' || j::text;
  assert j @> '[{"codigo":"dias_sem_midia","qtd":2}]', 'dias sem mídia (−4 e −3): ' || j::text;
  assert j @> '[{"codigo":"metricas_incompletas","qtd":1}]', 'parcial';
  assert j @> '[{"codigo":"vendas_sem_origem"}]', 'vendas sem origem';
  assert j @> '[{"codigo":"venda_receber_diverge"}]', 'venda sem conta a receber diverge';
  assert j @> '[{"codigo":"leads_sem_origem"}]', 'leads sem origem';
  insert into qualidade_regras (workspace_id, codigo, ativa) values (ws, 'leads_sem_origem', false);
  j := qualidade_dados(ws, current_date - 10, current_date);
  assert not (j @> '[{"codigo":"leads_sem_origem"}]'), 'regra desligada some';
  -- fechamento versionado
  insert into campanhas (workspace_id, nome, data_inicio) values (ws, 'Black', current_date - 10) returning id into c;
  f1 := campanha_fechar(c, current_date - 10, current_date, '{"receita":2000}');
  assert (select versao from campanha_fechamentos where id = f1) = 1;
  begin perform campanha_fechar(c, current_date - 10, current_date, '{"receita":2500}'); assert false, 'V2 sem motivo deveria falhar';
  exception when others then if sqlerrm not like '%motivo%' then raise; end if; end;
  f2 := campanha_fechar(c, current_date - 10, current_date, '{"receita":2500}', 'Vendas da Hotmart chegaram atrasadas');
  assert (select status from campanha_fechamentos where id = f1) = 'substituido' and (select snapshot->>'receita' from campanha_fechamentos where id = f1) = '2000', 'V1 preservada';
  assert (select versao || status from campanha_fechamentos where id = f2) = '2oficial' and (select substitui_id from campanha_fechamentos where id = f2) = f1, 'V2 oficial';
  assert (select qualidade from campanha_fechamentos where id = f2) is not null, 'qualidade gravada no fechamento';
  begin update campanha_fechamentos set snapshot = '{}' where id = f1; assert false; exception when others then if sqlerrm not like '%não pode ser alterado%' then raise; end if; end;
  begin delete from campanha_fechamentos where id = f1; assert false; exception when others then if sqlerrm not like '%não pode ser alterado%' then raise; end if; end;
  begin insert into campanha_fechamentos (workspace_id, campanha_id, snapshot) values (ws, c, '{}'); assert false; exception when others then if sqlerrm not like '%não pode ser alterado%' then raise; end if; end;
  -- extrato
  insert into plano_contas (workspace_id, codigo, nome, tipo) values (ws, '1.1.01', 'Bancos', 'ativo') returning id into pc;
  insert into contas_bancarias (id, workspace_id, nome, saldo_inicial, conta_contabil_id) values ('00000000-0000-0000-0000-0000000000b1', ws, 'Conta', 100, pc);
  insert into movimentacoes_bancarias (workspace_id, conta_bancaria_id, data, tipo, valor) values
    (ws, '00000000-0000-0000-0000-0000000000b1', '2026-09-30', 'entrada', 50), (ws, '00000000-0000-0000-0000-0000000000b1', '2026-10-02', 'saida', 30), (ws, '00000000-0000-0000-0000-0000000000b1', '2026-10-05', 'entrada', 10);
  j := extrato_conta('00000000-0000-0000-0000-0000000000b1', '2026-10-01', '2026-10-31');
  assert (j->>'saldo_anterior')::numeric = 150 and (j->>'saldo_final')::numeric = 130 and jsonb_array_length(j->'linhas') = 2 and (j->'linhas'->0->>'saldo')::numeric = 120, 'extrato: ' || j::text;
  raise notice 'v0.88: fase 1 OK';
end $$;
