-- v0.111: com o seed Aurora (banco fa), as telas usam a mesma conta de setembro/2026. Rodar no banco fa depois da migração 20261012500000.
begin;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-0000-0000-00000000a0a0"}', true);
do $$
declare ws uuid := 'ac56e719-7325-4062-aa47-74bc2141f89d'; d jsonb; m jsonb; p jsonb; f jsonb; pid uuid; ok boolean;
begin
  d := dre_resumo(ws, '2026-09-01', '2026-09-30'); m := d -> 'meses' -> 0;
  if (m ->> 'receita')::numeric <> 75955 then raise exception 'dre receita %', m ->> 'receita'; end if;
  if (m ->> 'impostos')::numeric <> 4956.40 or (m ->> 'taxas')::numeric <> 6198.35 then raise exception 'dre deduções %', m; end if;
  if (m ->> 'midia')::numeric <> 32871.59 or (m ->> 'despesas')::numeric <> 29700 then raise exception 'dre despesas %', m; end if;
  if (m ->> 'lucro')::numeric <> 2228.66 then raise exception 'dre lucro %', m ->> 'lucro'; end if;
  if abs((select sum((x ->> 'receita')::numeric) from jsonb_array_elements(d -> 'produtos') x) - 75955) > 0.01 then raise exception 'produtos não somam a receita'; end if;
  f := fin_dashboard_periodo(ws, '2026-10-15', '2026-09-01', '2026-09-30');
  if (f ->> 'receitas_mes')::numeric <> 75955 or (f ->> 'resultado_mes')::numeric <> 2228.66 then raise exception 'fin dashboard não usa o período %', f ->> 'resultado_mes'; end if;
  p := painel_gerencial(ws, '2026-09-01', '2026-09-30', '2026-10-15');
  if (p -> 'vendas' ->> 'aprovadas')::int <> 65 or (p -> 'vendas' ->> 'bruto')::numeric <> 61955 then raise exception 'painel não filtra o período %', p -> 'vendas'; end if;
  -- venda às 23h30 de 30/09 em Brasília (02h30 UTC de 01/10) é de setembro
  insert into vendas (workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, valor_bruto, data_venda, id_externo)
  select workspace_id, pessoa_id, produto_id, plataforma_id, forma_pagamento, 100, '2026-09-30 23:30:00-03', 'FUSO-1' from vendas where workspace_id = ws limit 1;
  p := painel_gerencial(ws, '2026-09-01', '2026-09-30', '2026-10-15');
  if (p -> 'vendas' ->> 'aprovadas')::int <> 66 then raise exception 'fuso: venda das 23h30 saiu de setembro'; end if;
  -- empresa: novas premissas e checks
  update empresa set anexo_simples = 'III', aliquota_manual = 8.5, taxas_variaveis_pct = 4 where workspace_id = ws;
  begin update empresa set anexo_simples = 'IV' where workspace_id = ws; ok := false; exception when check_violation then ok := true; end;
  if not ok then raise exception 'anexo inválido aceito'; end if;
  begin update empresa set taxas_variaveis_pct = 120 where workspace_id = ws; ok := false; exception when check_violation then ok := true; end;
  if not ok then raise exception 'percentual acima de 100 aceito'; end if;
  -- sem acesso a outro workspace
  begin perform dre_resumo('00000000-0000-0000-0000-0000000000ff', '2026-09-01', '2026-09-30'); ok := false; exception when others then ok := sqlerrm like '%sem acesso%'; end;
  if not ok then raise exception 'dre_resumo abriu workspace alheio'; end if;
  raise notice 'consistencia: tudo OK';
end $$;
rollback;
