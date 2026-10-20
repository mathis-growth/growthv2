-- LIMPAR O WORKSPACE "Growths — Demo" (não mexe na Mathisa).
-- Apaga: pessoas, vendas, financeiro, lançamentos contábeis, campanhas, tráfego, produtos, funis, pesquisas, Growth Model etc.
-- Mantém: plano de contas, regras contábeis, centros de custo, etapas do Kanban, motivos, canais, impostos e o seu acesso.
-- NÃO DÁ PARA DESFAZER. Rode no SQL Editor do Supabase, tudo de uma vez. Se qualquer passo falhar, nada é apagado.
-- Como os lançamentos contábeis são travados, a trava é desligada só durante esta limpeza e religada no fim.
do $$
declare
  ws constant uuid := '0583533e-7818-49f2-b8ef-3cd4ecfc551a';       -- Growths — Demo
  mathisa constant uuid := '8fd51ed1-0843-49d8-a2aa-b9bb99c59171';  -- Mathisa (conferida no fim)
  manter text[] := array['plano_contas','regras_contabilizacao','centros_custo','etapas_kanban','motivos_resultado','canais','impostos_config','workspace_membros'];
  t text; pend text[]; passo int := 0; n int; restante int; falhou text[];
  antes_m jsonb := '{}'::jsonb; depois_m jsonb := '{}'::jsonb;
begin
  for t in select c.table_name from information_schema.columns c join information_schema.tables x on x.table_schema=c.table_schema and x.table_name=c.table_name and x.table_type='BASE TABLE' where c.table_schema='public' and c.column_name='workspace_id' loop
    execute format('select count(*) from public.%I where workspace_id = $1', t) into n using mathisa; antes_m := antes_m || jsonb_build_object(t, n);
  end loop;
  select array_agg(c.table_name order by c.table_name) into pend from information_schema.columns c join information_schema.tables x on x.table_schema=c.table_schema and x.table_name=c.table_name and x.table_type='BASE TABLE'
    where c.table_schema='public' and c.column_name='workspace_id' and c.table_name <> all (manter);
  alter table lancamentos disable trigger lancamentos_imutavel;
  alter table partidas disable trigger partidas_imutavel;
  while passo < 25 loop
    passo := passo + 1; falhou := '{}';
    foreach t in array pend loop
      begin execute format('delete from public.%I where workspace_id = $1', t) using ws;
      exception when others then falhou := falhou || t; end;
    end loop;
    exit when coalesce(array_length(falhou, 1), 0) = 0;
  end loop;
  alter table lancamentos enable trigger lancamentos_imutavel;
  alter table partidas enable trigger partidas_imutavel;
  restante := 0;
  foreach t in array pend loop execute format('select count(*) from public.%I where workspace_id = $1', t) into n using ws; restante := restante + n; end loop;
  if restante > 0 or coalesce(array_length(falhou,1),0) > 0 then raise exception 'Ainda sobraram % linhas (falhou: %)', restante, falhou; end if;
  for t in select c.table_name from information_schema.columns c join information_schema.tables x on x.table_schema=c.table_schema and x.table_name=c.table_name and x.table_type='BASE TABLE' where c.table_schema='public' and c.column_name='workspace_id' loop
    execute format('select count(*) from public.%I where workspace_id = $1', t) into n using mathisa; depois_m := depois_m || jsonb_build_object(t, n);
  end loop;
  if antes_m <> depois_m then raise exception 'A Mathisa mudou! Nada foi apagado.'; end if;
end $$;
