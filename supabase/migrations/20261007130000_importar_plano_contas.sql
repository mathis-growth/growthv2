-- v0.51: importar o plano de contas do cliente (substituir o padrão ou adicionar contas).
-- p_contas: [{codigo, nome, tipo, natureza?, pai?, aceita?}]. Só administradores.
create or replace function importar_plano_contas(p_ws uuid, p_contas jsonb, p_modo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  it jsonb; cod text; pai text; tp text; nat text; ids jsonb := '{}'::jsonb; faltam jsonb; novo jsonb := '[]'::jsonb; rodada int := 0; antes int;
  ins int := 0; atu int := 0; rem int := 0; n int; tem_filho boolean; pid uuid; nid uuid; r record;
begin
  if not eh_admin(p_ws) then raise exception 'Só administradores importam o plano de contas.'; end if;
  if p_modo not in ('substituir', 'adicionar') then raise exception 'Modo inválido.'; end if;
  if jsonb_typeof(p_contas) <> 'array' or jsonb_array_length(p_contas) = 0 then raise exception 'Nenhuma conta para importar.'; end if;
  -- validação
  for it in select * from jsonb_array_elements(p_contas) loop
    cod := btrim(coalesce(it->>'codigo', ''));
    if cod = '' then raise exception 'Há conta sem código.'; end if;
    if btrim(coalesce(it->>'nome', '')) = '' then raise exception 'A conta % está sem nome.', cod; end if;
    if (it->>'tipo') not in ('ativo','passivo','patrimonio','receita','deducao','custo','despesa') then raise exception 'A conta % está com tipo inválido (%).', cod, it->>'tipo'; end if;
  end loop;
  select count(*) - count(distinct btrim(c->>'codigo')) into n from jsonb_array_elements(p_contas) c;
  if n > 0 then raise exception 'Há códigos repetidos no arquivo.'; end if;

  if p_modo = 'substituir' then
    if exists (select 1 from partidas where workspace_id = p_ws) then raise exception 'Já existem lançamentos contábeis. Use "Adicionar ao plano atual".'; end if;
    if exists (select 1 from contas_pagar where workspace_id = p_ws) or exists (select 1 from despesas_recorrentes where workspace_id = p_ws) then
      raise exception 'Já existem contas a pagar ou despesas recorrentes usando o plano atual. Use "Adicionar ao plano atual".'; end if;
    if exists (select 1 from contas_bancarias where workspace_id = p_ws) then
      raise exception 'Já existem contas bancárias ligadas ao plano atual. Importe o plano antes de cadastrar contas bancárias, ou use "Adicionar ao plano atual".'; end if;
    update regras_contabilizacao set conta_debito_id = null, conta_credito_id = null where workspace_id = p_ws;
    update fornecedores set conta_despesa_id = null where workspace_id = p_ws;
    update plano_contas set conta_passivo_id = null, conta_pai_id = null where workspace_id = p_ws;
    delete from plano_contas where workspace_id = p_ws; get diagnostics rem = row_count;
  else
    for r in select id, codigo from plano_contas where workspace_id = p_ws loop ids := ids || jsonb_build_object(r.codigo, r.id::text); end loop;
  end if;

  -- inserção por níveis: um item entra quando o pai já existe
  novo := p_contas;
  while jsonb_array_length(novo) > 0 and rodada < 20 loop
    rodada := rodada + 1; antes := jsonb_array_length(novo); faltam := '[]'::jsonb;
    for it in select * from jsonb_array_elements(novo) loop
      cod := btrim(it->>'codigo'); pai := nullif(btrim(coalesce(it->>'pai', '')), '');
      if pai is not null and not (ids ? pai) then
        if exists (select 1 from jsonb_array_elements(p_contas) c where btrim(c->>'codigo') = pai) then faltam := faltam || jsonb_build_array(it); continue;
        else raise exception 'A conta % aponta para o pai %, que não existe.', cod, pai; end if;
      end if;
      tp := it->>'tipo';
      nat := coalesce(nullif(it->>'natureza', ''), case when tp in ('ativo','deducao','custo','despesa') then 'devedora' else 'credora' end);
      tem_filho := exists (select 1 from jsonb_array_elements(p_contas) c where nullif(btrim(coalesce(c->>'pai', '')), '') = cod);
      pid := case when pai is null then null else (ids->>pai)::uuid end;
      if ids ? cod then
        update plano_contas set nome = btrim(it->>'nome') where id = (ids->>cod)::uuid and nome <> btrim(it->>'nome'); get diagnostics n = row_count; atu := atu + n;
      else
        insert into plano_contas (workspace_id, codigo, nome, tipo, natureza, conta_pai_id, aceita_lancamento)
          values (p_ws, cod, btrim(it->>'nome'), tp, nat, pid, not tem_filho and coalesce((it->>'aceita')::boolean, true)) returning id into nid;
        ids := ids || jsonb_build_object(cod, nid::text); ins := ins + 1;
      end if;
    end loop;
    novo := faltam;
    if jsonb_array_length(novo) = antes then raise exception 'Hierarquia com ciclo ou pai ausente.'; end if;
  end loop;
  return jsonb_build_object('inseridas', ins, 'atualizadas', atu, 'removidas', rem);
end $$;
