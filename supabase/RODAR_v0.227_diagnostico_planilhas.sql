-- RODAR no SQL Editor do Supabase (cópia de migrations/20261219100000_diagnostico_d4_planilhas.sql). Depende do RODAR_v0.225.
-- O que muda em produção: pesquisa_arquivos ganha a coluna auditoria (resultado da conferência das planilhas); função nova para guardar a auditoria;
-- o checklist e o de-para passam a usar a auditoria (troca pontual no corpo das duas funções). Nenhum dado existente muda.
-- v0.227 — Diagnóstico Inteligente D4: auditoria automática das planilhas.
-- A planilha é lida na tela (o arquivo original nunca muda) e o resultado fica guardado no próprio arquivo das evidências:
-- abas, colunas (significado e tipo de dado), qualidade (repetidas, datas inválidas, fora do período, futuras, valores negativos ou zerados),
-- cobertura por mês, produto e canal, e os "sinais" que o de-para usa (identificação do comprador, origem, status, recorrência…).
-- Aditivo e idempotente. Rode depois de 20261218100000_diagnostico_depara_metricas.sql.

alter table pesquisa_arquivos add column if not exists auditoria jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_auditoria_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_auditoria_ck check (auditoria is null or (jsonb_typeof(auditoria) = 'object' and length(auditoria::text) <= 300000)); end if;
end $$;

-- guarda a auditoria de uma planilha; sem período informado, usa o que a planilha mostra; sem classificação, sugere pelo tipo
create or replace function public.diagnostico_arquivo_auditoria(p_id uuid, p_aud jsonb, p_erro text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id); v_ini date; v_fim date; v_cls text;
begin
  if p_erro is not null then
    update pesquisa_arquivos set processamento = 'erro', processamento_erro = left(p_erro, 1000), processado_em = now() where id = p_id;
    return null;
  end if;
  if p_aud is null or jsonb_typeof(p_aud) <> 'object' then raise exception 'Auditoria inválida.'; end if;
  begin v_ini := nullif(p_aud -> 'periodo' ->> 'ini', '')::date; v_fim := nullif(p_aud -> 'periodo' ->> 'fim', '')::date; exception when others then v_ini := null; v_fim := null; end;
  if v_ini is not null and v_fim is not null and v_fim < v_ini then v_ini := null; v_fim := null; end if;
  v_cls := case p_aud ->> 'tipo' when 'vendas' then 'vendas' when 'leads' then 'marketing' when 'midia' then 'marketing' end;
  update pesquisa_arquivos set auditoria = p_aud || jsonb_build_object('auditado_em', now()), processamento = 'lido', processamento_erro = null, processado_em = now(),
    periodo_ini = case when periodo_ini is null and periodo_fim is null then v_ini else periodo_ini end,
    periodo_fim = case when periodo_ini is null and periodo_fim is null then v_fim else periodo_fim end,
    classe = case when classe is null and v_cls is not null then v_cls else classe end,
    classe_origem = case when classe is null and v_cls is not null then 'sugerida' else classe_origem end
  where id = p_id;
  return (select to_jsonb(x) - 'caminho' - 'auditoria' from pesquisa_arquivos x where id = p_id);
end $$;
revoke all on function public.diagnostico_arquivo_auditoria(uuid, jsonb, text) from public, anon;
grant execute on function public.diagnostico_arquivo_auditoria(uuid, jsonb, text) to authenticated;

-- o grupo do checklist também olha o tipo que a auditoria achou (uma planilha de leads da equipe conta como CRM e leads)
create or replace function public.diag_grupo_arquivo(p_grupo text, p_classe text, p_nome text, p_tipo text) returns text language sql immutable as $$
  select case
    when p_grupo is not null and p_grupo <> 'equipe' then p_grupo
    when p_tipo = 'leads' then 'crm'
    when p_tipo = 'midia' then 'marketing'
    when p_tipo = 'vendas' and coalesce(p_classe, 'vendas') = 'vendas' then 'vendas'
    else diag_grupo_arquivo(p_grupo, p_classe, p_nome) end
$$;

-- o checklist e o de-para passam a usar a auditoria (troca pontual no corpo das funções da v0.224 e da v0.225)
do $f$ declare v text;
begin
  v := pg_get_functiondef('public.diagnostico_checklist(uuid, date)'::regprocedure);
  if position('a.auditoria ->> ''tipo''' in v) = 0 then
    v := replace(v, 'diag_grupo_arquivo(a.grupo, a.classe, a.nome)', 'diag_grupo_arquivo(a.grupo, a.classe, a.nome, a.auditoria ->> ''tipo'')');
    execute v;
  end if;
  v := pg_get_functiondef('public.diagnostico_depara(uuid, date)'::regprocedure);
  if position('v0.227' in v) = 0 then
    -- os sinais das planilhas auditadas entram junto com a leitura consolidada (vale o melhor de cada um)
    v := replace(v, '  v_met := case when jsonb_typeof(v_met) = ''object'' then v_met else ''{}'' end;',
      '  -- v0.227: sinais da auditoria automática das planilhas
  select coalesce(jsonb_object_agg(sk, case sm when 3 then ''ok'' when 2 then ''parcial'' else ''falta'' end), ''{}'') into v_le from (
    select sk, max(case sv when ''ok'' then 3 when ''parcial'' then 2 else 1 end) sm from (
      select e.key sk, e.value #>> ''{}'' sv from jsonb_each(v_le) e
      union all
      select s.key, s.value #>> ''{}'' from pesquisa_arquivos a, jsonb_each(a.auditoria -> ''sinais'') s
        where a.diagnostico_id = p_diag and a.status = ''enviado'' and a.arquivado_em is null and jsonb_typeof(a.auditoria -> ''sinais'') = ''object'') u group by sk) z;
  v_lido := v_lido or exists (select 1 from pesquisa_arquivos a where a.diagnostico_id = p_diag and a.status = ''enviado'' and a.arquivado_em is null and a.auditoria ? ''sinais'');
  v_met := case when jsonb_typeof(v_met) = ''object'' then v_met else ''{}'' end;');
    -- item que a leitura não cobriu: fica como "confirmar", não como "tem"
    v := replace(v, 'elsif st = ''parcial'' then v_ress := v_ress || to_jsonb(coalesce(ROT_L ->> val, val) || '' em parte''); end if;',
      'elsif st = ''parcial'' then v_ress := v_ress || to_jsonb(coalesce(ROT_L ->> val, val) || '' em parte'');
          elsif st is null then v_ress := v_ress || to_jsonb(''confirmar '' || coalesce(ROT_L ->> val, val)); end if;');
    execute v;
  end if;
end $f$;

-- Para desfazer: drop function diagnostico_arquivo_auditoria(uuid, jsonb, text), diag_grupo_arquivo(text, text, text, text);
-- rodar de novo as funções diagnostico_checklist (20261217100000) e diagnostico_depara (20261218100000); alter table pesquisa_arquivos drop column auditoria.
