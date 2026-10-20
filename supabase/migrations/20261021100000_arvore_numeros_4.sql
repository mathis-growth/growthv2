-- v0.119 — Árvore dos números, parte 4
-- 1) Lançamento de recebimento e de parcela de contrato mostra a origem: a parcela (vencimento, número) e a venda ou o contrato.
-- 2) Contas a receber: o MRR passa a usar a data de cancelamento no horário de São Paulo (antes UTC), igual ao Dashboard e à árvore.
-- Rode depois de 20261020300000_arvore_numeros_3.sql. Idempotente: pode rodar de novo, inclusive colado no editor do Supabase (cada troca confere uma marca de "já aplicado" e ignora quebras de linha do Windows).
do $do$ declare d text; antes text; depois text; fn text; i int;  -- trocas: função, trecho antigo, trecho novo, marca de que já foi aplicado
  trocas text[][] := array[
    ['public._arv_extra(uuid,text,jsonb)',
     $q$'fin.conta_pagar', jsonb_build_object('conta', l.origem_id)))) end),$q$,
     $q$'fin.conta_pagar', jsonb_build_object('conta', l.origem_id))))
        when l.origem_tipo in ('recebimento', 'contrato_parcela') then (select jsonb_build_object('titulo', 'Origem', 'itens',
          jsonb_build_array(_arv_item('Parcela com vencimento em ' || to_char(cr.vencimento, 'DD/MM/YYYY') || coalesce(' (' || cr.parcela || ')', '') || ' · ' || cr.status, cr.valor, null, null))
          || case when cr.venda_id is not null then jsonb_build_array(_arv_item('Venda', (select valor_bruto from vendas where id = cr.venda_id), 'ven.venda', jsonb_build_object('venda', cr.venda_id)))
                  when cr.contrato_id is not null then jsonb_build_array(_arv_item('Contrato nº ' || coalesce((select numero::text from contratos where id = cr.contrato_id), '?'), null, null, null))
                  else '[]'::jsonb end)
          from contas_receber cr where cr.id = l.origem_id) end),$q$,
     $q$'Parcela com vencimento em '$q$],
    ['public.receber_periodo(uuid,date,date,date)',
     $q$(c.cancelado_em at time zone 'UTC')::date <= p_hoje$q$,
     $q$(c.cancelado_em at time zone 'America/Sao_Paulo')::date <= p_hoje$q$,
     $q$(c.cancelado_em at time zone 'America/Sao_Paulo')::date <= p_hoje$q$]];
begin
  for i in 1 .. array_length(trocas, 1) loop
    fn := trocas[i][1]; antes := replace(trocas[i][2], E'\r', ''); depois := replace(trocas[i][3], E'\r', '');
    -- quebras de linha do Windows (CRLF) ao colar no editor não podem atrapalhar a conferência
    d := replace(pg_get_functiondef(fn::regprocedure), E'\r', '');
    if position(depois in d) > 0 or position(replace(trocas[i][4], E'\r', '') in d) > 0 then continue; end if;  -- já trocado
    if position(antes in d) = 0 then raise exception 'Trecho não encontrado em %', fn; end if;
    execute replace(d, antes, depois);
  end loop;
end $do$;
