-- Conferência da v0.105 (rodar depois de retencao_base.sql e da migração 20261012100000_revops_retencao.sql). Cada linha falha com erro se o número não bater.
do $$
declare w uuid := '00000000-0000-0000-0000-0000000000a1'; j jsonb; x jsonb; n int; v numeric;
  procedure_ok text;
begin
  -- pedidos: Bia (Curso + Bump no mesmo dia) = 1 pedido; reembolso não conta; contrato cancelado sem recebimento não conta; outro workspace não entra
  select count(*) into n from revops_pedidos(w); if n <> 8 then raise exception 'pedidos: esperava 8, veio %', n; end if;
  select count(*) into n from revops_pedidos(w) where pessoa_id = '00000000-0000-0000-0000-00000000000b'; if n <> 1 then raise exception 'Bia: compras do mesmo dia deviam ser 1 pedido, veio %', n; end if;
  select count(*) into n from revops_pedidos(w) where pessoa_id = '00000000-0000-0000-0000-00000000000e'; if n <> 0 then raise exception 'Eva: contrato cancelado sem recebimento não é compra'; end if;
  select dia into x from (select to_jsonb(dia) as dia from revops_pedidos(w) where pessoa_id = '00000000-0000-0000-0000-00000000000c' and ord = 1) z;
  if (x #>> '{}')::date <> d(380) then raise exception 'Caio: a coorte devia começar na compra válida (d-380), veio %', x; end if;
  -- receitas: parcelas do contrato até hoje (7 × 1.000), a futura fica de fora; tudo na 1ª compra do Davi
  select sum(valor) into v from revops_receitas(w); if v <> 13200 then raise exception 'receita total: esperava 13.200, veio %', v; end if;
  select sum(valor) into v from revops_receitas(w) where fonte = 'contrato'; if v <> 7000 then raise exception 'parcelas do contrato: esperava 7.000, veio %', v; end if;
  select sum(valor) into v from revops_receitas(w) where ord > 1; if v <> 2000 then raise exception 'receita de clientes existentes: esperava 2.000, veio %', v; end if;
  select sum(custo) into v from revops_receitas(w); if v <> 600 then raise exception 'custos: esperava 500 (10%% do Curso) + 100 (Mentoria por cliente, uma vez), veio %', v; end if;
  -- coortes
  j := revops_coortes(w, '{}', 'mes', 'periodo', 12); x := j -> 'total';
  if (x ->> 'clientes')::int <> 5 or (x ->> 'recompraram')::int <> 2 or (x ->> 'dois_mais')::int <> 2 then raise exception 'coortes total: %', x; end if;
  if (x ->> 'receita')::numeric <> 13200 or (x ->> 'receita_exist')::numeric <> 2000 or (x ->> 'mc')::numeric <> 11400 or (x ->> 'com_custo')::numeric <> 12000 then raise exception 'coortes receita/margem: %', x; end if;
  if (x ->> 'd2_media')::numeric <> 85 or (x ->> 'd2_mediana')::numeric <> 85 then raise exception 'tempo até a 2ª compra: esperava média e mediana 85 (30 e 140), veio %', x; end if;
  select t into x from jsonb_array_elements(j -> 'total' -> 'taxas') t where (t ->> 'h')::int = 30;
  if x ->> 'taxa' is not null or (x ->> 'el')::int <> 4 or (x ->> 'parcial')::numeric <> 25 then raise exception 'D30 com o Fábio ainda sem 30 dias: taxa indisponível e parcial 25%%, veio %', x; end if;
  -- curva da coorte do Fábio (comprou há 10 dias): existe até D10 e para em D15 (ainda não completou o prazo)
  select c into x from jsonb_array_elements(j -> 'coortes') c where c ->> 'gk' = to_char(date_trunc('month', d(10)), 'YYYY-MM-DD');
  if (select (t ->> 'pct') from jsonb_array_elements(x -> 'curva') t where (t ->> 'd')::int = 10) is null then raise exception 'curva da coorte D10 devia existir: %', x -> 'curva'; end if;
  if (select (t ->> 'pct') from jsonb_array_elements(x -> 'curva') t where (t ->> 'd')::int = 15) is not null then raise exception 'curva da coorte D15 não pode existir: %', x -> 'curva'; end if;
  -- curva de todas: em D15 conta só quem já tem 15 dias (4 clientes, 0 recompras até ali)
  select t into x from jsonb_array_elements(j -> 'total' -> 'curva') t where (t ->> 'd')::int = 15;
  if (x ->> 'n')::int <> 4 or (x ->> 'pct')::numeric <> 0 then raise exception 'curva total D15: %', x; end if;
  -- por produto de entrada: Curso (Ana, Bia, Caio, Fábio) e Mentoria (Davi); Bia também entra pelo Bump
  j := revops_coortes(w, '{}', 'mes', 'produto', 12);
  select c into x from jsonb_array_elements(j -> 'coortes') c where c ->> 'rotulo' = 'Curso'; if (x ->> 'n')::int <> 4 or (x ->> 'recompraram')::int <> 1 then raise exception 'coorte Curso: %', x; end if;
  -- filtros
  j := revops_coortes(w, '{"canal":"meta_ads"}', 'mes', 'periodo', 12); if (j -> 'total' ->> 'clientes')::int <> 2 then raise exception 'filtro canal: %', j -> 'total'; end if;
  j := revops_coortes(w, '{"campanha":"00000000-0000-0000-0000-0000000000c1"}', 'mes', 'periodo', 12); if (j -> 'total' ->> 'clientes')::int <> 1 then raise exception 'filtro campanha: %', j -> 'total'; end if;
  -- recompra
  j := revops_recompra(w, jsonb_build_object('ini', d(500), 'fim', d(0))); x := j -> 'kpi';
  if (x ->> 'primeira')::int <> 5 or (x ->> 'segunda')::int <> 2 or (x ->> 'receita_2')::numeric <> 1500 or (x ->> 'receita_3mais')::numeric <> 500 then raise exception 'recompra kpi: %', x; end if;
  if (x ->> 'intervalo_mediana')::numeric <> 140 then raise exception 'intervalo mediano entre compras: esperava 140 (30, 270 e 140), veio %', x; end if;
  if (j -> 'reconciliacao' ->> 'vendas')::numeric + (j -> 'reconciliacao' ->> 'contratos')::numeric <> 13200 then raise exception 'reconciliação: %', j -> 'reconciliacao'; end if;
  select count(*) into n from jsonb_array_elements(j -> 'novos_existentes') m; if n = 0 then raise exception 'novos × existentes vazio'; end if;
  select t into x from jsonb_array_elements(j -> 'transicao') t where t ->> 'de' = '00000000-0000-0000-0000-0000000000b4';
  if (x ->> 'para') <> '00000000-0000-0000-0000-0000000000b1' or (x ->> 'pct')::numeric <> 100 then raise exception 'transição Mentoria → Curso: %', x; end if;
  select t into x from jsonb_array_elements(j -> 'transicao') t where t ->> 'de' = '00000000-0000-0000-0000-0000000000b1';
  if (x ->> 'para') <> '00000000-0000-0000-0000-0000000000b2' or (x ->> 'pct')::numeric <> 25 then raise exception 'transição Curso → Livro: %', x; end if;
  select t into x from jsonb_array_elements(j -> 'distribuicao') t where t ->> 'faixa' = '8 a 30'; if (x ->> 'n')::int <> 1 then raise exception 'distribuição 8 a 30: %', x; end if;
  -- RFM por limites (determinístico)
  j := revops_rfm(w, '{}', null, '{"metodo":"limites"}', 'produto');
  if (j ->> 'clientes')::int <> 5 then raise exception 'rfm clientes: %', j ->> 'clientes'; end if;
  select s into x from jsonb_array_elements(j -> 'segmentos') s where s ->> 'nome' = 'Hibernando'; if (x ->> 'clientes')::int <> 2 then raise exception 'Hibernando (Bia e Caio): %', x; end if;
  select s into x from jsonb_array_elements(j -> 'segmentos') s where s ->> 'nome' = 'Novos clientes'; if (x ->> 'clientes')::int <> 1 then raise exception 'Novos clientes (Fábio): %', x; end if;
  select s into x from jsonb_array_elements(j -> 'segmentos') s where s ->> 'nome' = 'Potenciais leais'; if (x ->> 'clientes')::int <> 1 then raise exception 'Potenciais leais (Davi): %', x; end if;
  select s into x from jsonb_array_elements(j -> 'segmentos') s where s ->> 'nome' = 'Precisam de atenção'; if (x ->> 'clientes')::int <> 1 then raise exception 'Precisam de atenção (Ana): %', x; end if;
  -- RFM numa data passada (histórico): há 300 dias, Fábio e Davi ainda não eram clientes
  j := revops_rfm(w, '{}', d(300), '{"metodo":"limites"}', 'produto'); if (j ->> 'clientes')::int <> 3 then raise exception 'rfm histórico: esperava 3, veio %', j ->> 'clientes'; end if;
  -- segmentos configuráveis: uma regra só
  j := revops_rfm(w, '{}', null, '{"metodo":"limites","segmentos":[{"nome":"Recentes","r":[4,5],"f":[1,5]}]}', 'canal');
  select s into x from jsonb_array_elements(j -> 'segmentos') s where s ->> 'nome' = 'Recentes'; if (x ->> 'clientes')::int <> 2 then raise exception 'regra configurável: %', x; end if;
  -- quintis rodam
  j := revops_rfm(w, '{}', null, '{"metodo":"quintis"}', 'campanha'); if (j ->> 'clientes')::int <> 5 then raise exception 'quintis: %', j; end if;
  -- lista para investigar
  j := revops_clientes_de(w, '{}', '{"recomprou":"sim"}'); if (j ->> 'total')::int <> 2 then raise exception 'lista recompraram: %', j ->> 'total'; end if;
  j := revops_clientes_de(w, '{}', '{"de":"00000000-0000-0000-0000-0000000000b1","para":"00000000-0000-0000-0000-0000000000b2"}');
  if (j ->> 'total')::int <> 1 or j -> 'clientes' -> 0 ->> 'nome' <> 'Ana' or jsonb_array_length(j -> 'clientes' -> 0 -> 'historico') <> 3 then raise exception 'lista transição: %', j; end if;
  j := revops_clientes_de(w, '{}', '{"segmento":"Hibernando","cfg":{"metodo":"limites"}}'); if (j ->> 'total')::int <> 2 then raise exception 'lista segmento: %', j ->> 'total'; end if;
  -- filtro de segmento (RFM de hoje, configuração salva = padrão por quintis) roda
  perform revops_coortes(w, '{"segmento":"Hibernando"}', 'mes', 'periodo', 12);
  -- catálogo de acesso
  if not exists (select 1 from acesso_telas where tela = 'ho-retencao' and modulo = 'revops') then raise exception 'tela ho-retencao no catálogo'; end if;
  if not exists (select 1 from pacotes_acesso where nome = 'Completo' and telas @> array['ho-retencao']) or exists (select 1 from pacotes_acesso where nome = 'Sem RevOps' and telas @> array['ho-retencao']) then raise exception 'pacotes'; end if;
  raise notice 'TUDO OK';
end $$;
