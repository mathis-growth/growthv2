-- v0.68: parcela baixada por desconto não pode ser "reativada" (o desconto já foi lançado; para desfazer, lance a correção manualmente).
do $mig$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p where proname = 'reativar_parcela_contrato' and pronamespace = 'public'::regnamespace;
  if d !~ 'baixada por desconto' then
    d := replace(d, $a$  if cr.substituida_por is not null then raise exception 'Esta parcela já foi reativada'; end if;$a$,
      $b$  if cr.substituida_por is not null then raise exception 'Esta parcela já foi reativada'; end if;
  if coalesce(cr.desconto, 0) > 0 then raise exception 'Esta parcela foi baixada por desconto e não pode ser reativada'; end if;$b$);
    execute d;
  end if;
end $mig$;
