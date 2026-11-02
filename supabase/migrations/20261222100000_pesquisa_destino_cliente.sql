-- v0.230 — Formulário para clientes: quem responde é um cliente, não um lead.
-- Pedido da Rebecka (02/11): "o formulário capta as informações e atualiza o CRM dos clientes; ele já é cliente, não entra no funil de leads,
-- entra no funil de clientes na etapa de diagnóstico".
-- pesquisas.captacao ganha:
--   destino            'lead' (padrão: como sempre, cria ou atualiza o lead no Funil de leads) ou 'cliente'
--   etapa_cliente_id   etapa da jornada do cliente (quadro de clientes) para onde a matrícula vai depois que ele responde (vazio = não muda)
-- Com destino 'cliente', vale para o link individual e para o link aberto:
--   · ninguém entra no Funil de leads (no link aberto, contato novo fica fora do funil e marcado "cliente sem cadastro");
--   · o cadastro do cliente é atualizado (WhatsApp e Instagram, se pedidos);
--   · as matrículas ativas do cliente vão para a etapa escolhida (só etapas da mesma jornada; o histórico do aluno registra a mudança);
--   · o histórico do cliente registra o formulário e a etapa.
-- Aditivo e idempotente. Rode depois de 20261221100000_diagnostico_saber.sql.

create or replace function public.pesquisa_cliente_etapa(p_resposta uuid) returns int
language plpgsql security definer set search_path = public as $$
declare r pesquisa_respostas; v_p pesquisas; v_et etapas_kanban; n int := 0; v_tem_jor boolean;
begin
  select * into r from pesquisa_respostas where id = p_resposta;
  if not found or r.pessoa_id is null then return 0; end if;
  select * into v_p from pesquisas where id = r.pesquisa_id;
  if coalesce(v_p.captacao ->> 'destino', 'lead') <> 'cliente' then return 0; end if;
  if (v_p.captacao ->> 'etapa_cliente_id') ~ '^[0-9a-f-]{36}$' then
    select * into v_et from etapas_kanban where id = (v_p.captacao ->> 'etapa_cliente_id')::uuid and workspace_id = v_p.workspace_id and quadro = 'alunos';
  end if;
  if v_et.id is not null then
    v_tem_jor := exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'etapas_kanban' and column_name = 'jornada_id');
    if v_tem_jor then
      execute 'update alunos a set etapa_kanban_id = $1 where a.workspace_id = $2 and a.pessoa_id = $3 and coalesce(a.status, ''ativo'') not in (''cancelado'', ''concluido'', ''inativo'')
        and a.etapa_kanban_id is distinct from $1
        and ($4::uuid is null or a.etapa_kanban_id is null or exists (select 1 from etapas_kanban e where e.id = a.etapa_kanban_id and e.jornada_id is not distinct from $4::uuid))'
        using v_et.id, v_p.workspace_id, r.pessoa_id, (to_jsonb(v_et) ->> 'jornada_id');
    else
      update alunos a set etapa_kanban_id = v_et.id where a.workspace_id = v_p.workspace_id and a.pessoa_id = r.pessoa_id
        and coalesce(a.status, 'ativo') not in ('cancelado', 'concluido', 'inativo') and a.etapa_kanban_id is distinct from v_et.id;
    end if;
    get diagnostics n = row_count;
  end if;
  insert into pessoa_historico (workspace_id, pessoa_id, campo, valor_anterior, valor_novo)
  values (v_p.workspace_id, r.pessoa_id, 'formulario_cliente', null,
    left(v_p.nome || case when v_et.id is null then '' when n > 0 then ' → etapa "' || v_et.nome || '"' when exists (select 1 from alunos where pessoa_id = r.pessoa_id and workspace_id = v_p.workspace_id) then ' (já estava na etapa ou em outra jornada)' else ' (sem matrícula: a etapa não mudou)' end, 300));
  return n;
end $$;
revoke all on function public.pesquisa_cliente_etapa(uuid) from public, anon, authenticated;

-- toda resposta de formulário para clientes passa por aqui (link individual e link aberto)
create or replace function public.pesquisa_respostas_cliente() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.pessoa_id is not null and exists (select 1 from pesquisas where id = new.pesquisa_id and captacao ->> 'destino' = 'cliente') then
    perform pesquisa_cliente_etapa(new.id);
  end if;
  return null;
end $$;
drop trigger if exists pesquisa_respostas_cliente_t on pesquisa_respostas;
create trigger pesquisa_respostas_cliente_t after insert on pesquisa_respostas for each row execute function pesquisa_respostas_cliente();

-- link aberto: com destino "cliente", não põe ninguém no Funil de leads; quem não tem cadastro fica marcado
do $f$ declare v text;
begin
  v := pg_get_functiondef('public.pesquisa_captar(text, jsonb, jsonb, jsonb)'::regprocedure);
  if position('v0.230' in v) = 0 then
    v := replace(v, '  v_tags := array(select distinct left(trim(x), 40)',
      '  if c ->> ''destino'' = ''cliente'' then v_etapa := null; v_resp_id := null; end if; -- v0.230: formulário para clientes
  v_tags := array(select distinct left(trim(x), 40)');
    v := replace(v, '    returning id into v_pessoa;
    v_novo := true;',
      '    returning id into v_pessoa;
    v_novo := true;
    if c ->> ''destino'' = ''cliente'' then update pessoas set etapa_kanban_id = null, tags = array(select distinct t from unnest(coalesce(tags, ''{}'') || array[''cliente sem cadastro'']) t) where id = v_pessoa; end if;');
    if position('v0.230' in v) = 0 then raise exception 'Não consegui ajustar pesquisa_captar (versão inesperada).'; end if;
    execute v;
  end if;
  -- o formulário público não precisa saber para qual etapa o cliente vai
  v := pg_get_functiondef('public.pesquisa_publica(text)'::regprocedure);
  if position('etapa_cliente_id' in v) = 0 and position('- ''responsavel_id''' in v) > 0 then
    v := replace(v, '- ''responsavel_id''', '- ''responsavel_id'' - ''etapa_cliente_id''');
    execute v;
  end if;
end $f$;

-- Para desfazer: drop trigger pesquisa_respostas_cliente_t on pesquisa_respostas; drop function pesquisa_respostas_cliente(), pesquisa_cliente_etapa(uuid);
-- rodar de novo pesquisa_captar (20261027100000) e pesquisa_publica da última migração que a definiu.
