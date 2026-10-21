-- NÃO APLICADO em produção ainda. Rode no SQL Editor do Supabase depois do RODAR_v0.120.
-- v0.121 — Árvore dos números: "Por vendedor" mostrava "Sem vendedor" para todas as vendas.
-- vendas.vendedor_id aponta para equipe.id (o mesmo que pessoas.responsavel_comercial_id e as comissões usam), não para o usuário.
-- Idempotente: pode rodar de novo (confere a marca de já aplicado e ignora quebras de linha do Windows).
do $do$ declare d text; antes text; depois text; fn text; i int;
  trocas text[][] := array[
    ['public._arv_vendas(uuid,jsonb)',
     $q$left join equipe e on e.user_id = z.vendedor_id and e.workspace_id = p_ws$q$,
     $q$left join equipe e on e.id = z.vendedor_id and e.workspace_id = p_ws$q$,
     $q$e.id = z.vendedor_id$q$]];
begin
  for i in 1 .. array_length(trocas, 1) loop
    fn := trocas[i][1]; antes := replace(trocas[i][2], E'\r', ''); depois := replace(trocas[i][3], E'\r', '');
    d := replace(pg_get_functiondef(fn::regprocedure), E'\r', '');
    if position(depois in d) > 0 or position(replace(trocas[i][4], E'\r', '') in d) > 0 then continue; end if;
    if position(antes in d) = 0 then raise exception 'Trecho não encontrado em %', fn; end if;
    execute replace(d, antes, depois);
  end loop;
end $do$;
