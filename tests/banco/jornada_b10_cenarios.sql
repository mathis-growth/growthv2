-- v0.163 (B10): indicadores da tela Customer Growth. Rode depois de jornada_b6_b9_cenarios.sql (usa o cliente "B6").
-- Termina com "jornada_b10: tudo OK".
do $t$
declare ws uuid; pr uuid; r jsonb;
begin
  select id into ws from workspaces where nome = 'B6' order by criado_em desc limit 1;
  select id into pr from produtos where workspace_id = ws and nome = 'Mentoria';
  r := cg_indicadores(ws, null, (now() - interval '100 days')::date, (now() + interval '1 day')::date);
  if (r#>>'{matriculas,ativas}')::int <> 4 then raise exception 'X: ativas: %', r->'matriculas'; end if;
  if jsonb_array_length(r->'marcos') <> 1 or (r->'marcos'->0->>'atrasados')::int < 1 then raise exception 'X: marcos: %', r->'marcos'; end if;
  if (r#>>'{checkins,respondidos}')::int <> 1 then raise exception 'X: check-ins: %', r->'checkins'; end if;
  if (r#>>'{nps,nps}')::int <> -100 then raise exception 'X: NPS: %', r->'nps'; end if;
  if (r#>>'{intervencoes,resolveu_pct}')::numeric <> 100 then raise exception 'X: intervenções: %', r->'intervencoes'; end if;
  if not exists (select 1 from jsonb_array_elements(r->'etapas') x where x->>'jornada' = 'Mentoria · v1' and x->>'etapa' = 'Boas-vindas') then raise exception 'X: etapas: %', r->'etapas'; end if;
  if r#>>'{receita,regra}' not like 'revops_receitas%' then raise exception 'X: receita fora da regra única'; end if;
  r := cg_indicadores(ws, gen_random_uuid(), null, null);
  if (r#>>'{matriculas,ativas}')::int <> 0 then raise exception 'X: filtro de produto'; end if;
  if not exists (select 1 from metricas_definicoes where codigo = 'cg_nps') then raise exception 'X: dicionário'; end if;
  raise notice 'jornada_b10: tudo OK';
end $t$;
select 'jornada_b10: tudo OK' as resultado;
