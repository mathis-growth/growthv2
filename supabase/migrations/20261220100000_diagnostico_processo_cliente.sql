-- v0.228 — Diagnóstico de clientes da Mathisa: o processo começa pelo cliente e pelo formulário.
-- Decisões da Rebecka (02/11):
--  · o diagnóstico é de um CLIENTE da Mathisa (pessoa com contrato), feito no workspace da Mathisa;
--  · a tela e todo o processo são só da Mathisa (workspace de agência), não viram padrão para os clientes;
--  · o cliente entra depois do contrato; na jornada do produto, a etapa "Diagnóstico" é onde ele espera o diagnóstico;
--  · a primeira etapa do diagnóstico é o formulário: escolher o formulário (há um padrão), enviar por WhatsApp ou e-mail ou copiar o link,
--    e ver se o cliente já abriu, está preenchendo ou respondeu.
-- Aditivo e idempotente. Rode depois de 20261219100000_diagnostico_d4_planilhas.sql.

-- 1. o diagnóstico guarda o contrato e a matrícula do cliente
alter table diagnosticos add column if not exists contrato_id uuid references contratos(id) on delete set null;
alter table diagnosticos add column if not exists aluno_id uuid references alunos(id) on delete set null;
create index if not exists diagnosticos_pessoa_status on diagnosticos (workspace_id, pessoa_id, status);

-- 2. o formulário padrão do diagnóstico (um por empresa)
alter table pesquisas add column if not exists padrao_diagnostico boolean not null default false;
create unique index if not exists pesquisas_padrao_diagnostico on pesquisas (workspace_id) where padrao_diagnostico;

-- 3. coerência: com resposta, tudo vem dela; sem resposta, o formulário enviado (envio) pode estar escolhido, do mesmo cliente
create or replace function public.diagnosticos_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare r pesquisa_respostas; e pesquisa_envios; v_ok boolean;
begin
  if new.resposta_id is not null then
    select * into r from pesquisa_respostas where id = new.resposta_id;
    if not found then raise exception 'Resposta não encontrada.'; end if;
    if new.workspace_id is distinct from r.workspace_id then raise exception 'O diagnóstico precisa ser da mesma empresa da resposta.'; end if;
    new.pesquisa_id := r.pesquisa_id; new.envio_id := r.envio_id; new.pessoa_id := coalesce(r.pessoa_id, new.pessoa_id);
  elsif tg_op = 'UPDATE' and old.resposta_id is not null then
    raise exception 'Não dá para desligar o formulário de um diagnóstico.';
  elsif new.envio_id is not null then
    select * into e from pesquisa_envios where id = new.envio_id;
    if not found or e.workspace_id <> new.workspace_id then raise exception 'Envio do formulário não encontrado.'; end if;
    if new.pessoa_id is not null and e.pessoa_id is distinct from new.pessoa_id then raise exception 'O formulário precisa ser do mesmo cliente do diagnóstico.'; end if;
    new.pesquisa_id := e.pesquisa_id; new.pessoa_id := e.pessoa_id;
  else
    new.pesquisa_id := null;
  end if;
  if new.pessoa_id is not null and not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id) then raise exception 'Cliente não encontrado.'; end if;
  if new.contrato_id is not null and not exists (select 1 from contratos where id = new.contrato_id and workspace_id = new.workspace_id) then raise exception 'Contrato não encontrado.'; end if;
  if new.aluno_id is not null and not exists (select 1 from alunos where id = new.aluno_id and workspace_id = new.workspace_id) then raise exception 'Matrícula não encontrada.'; end if;
  if new.responsavel_id is not null then
    select exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) into v_ok;
    if not v_ok then raise exception 'O responsável precisa ser da equipe da empresa.'; end if;
  end if;
  if tg_op = 'INSERT' then new.criado_por := coalesce(new.criado_por, auth.uid()); end if;
  new.atualizado_em := now();
  if new.status = 'validado' and (tg_op = 'INSERT' or old.status <> 'validado') then new.validado_em := now(); new.validado_por := coalesce(new.validado_por, auth.uid()); end if;
  if new.status in ('rascunho', 'em_analise', 'em_revisao') then new.validado_em := null; new.validado_por := null; end if;
  return new;
end $$;
-- os arquivos do link também entram quando o envio é escolhido (antes da resposta)
drop trigger if exists diagnosticos_liga_arquivos_t on diagnosticos;
create trigger diagnosticos_liga_arquivos_t after insert or update of resposta_id, envio_id on diagnosticos for each row execute function diagnosticos_liga_arquivos();

-- 4. quando o cliente responde, a resposta entra sozinha no diagnóstico daquele envio
create or replace function public.pesquisa_respostas_diag() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.envio_id is not null then
    update diagnosticos set resposta_id = new.id where envio_id = new.envio_id and resposta_id is null;
    if found then
      insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto, autor)
        select workspace_id, id, 'status', 'O cliente respondeu o formulário', null from diagnosticos where resposta_id = new.id;
    end if;
  end if;
  return null;
end $$;
drop trigger if exists pesquisa_respostas_diag_t on pesquisa_respostas;
create trigger pesquisa_respostas_diag_t after insert on pesquisa_respostas for each row execute function pesquisa_respostas_diag();

-- 5. escolher e preparar o formulário do diagnóstico (gera o link individual do cliente)
create or replace function public.diagnostico_formulario(p_diag uuid, p_pesquisa uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ws uuid := diag_pode(p_diag); d diagnosticos; v_p pesquisas; v_e pesquisa_envios;
begin
  select * into d from diagnosticos where id = p_diag;
  if d.resposta_id is not null then raise exception 'O cliente já respondeu: o formulário não pode mais ser trocado.'; end if;
  if d.pessoa_id is null then raise exception 'Escolha o cliente do diagnóstico antes do formulário.'; end if;
  select * into v_p from pesquisas where id = p_pesquisa and workspace_id = v_ws;
  if not found or v_p.tipo <> 'diagnostico' then raise exception 'Escolha um formulário de diagnóstico.'; end if;
  if not v_p.ativa then raise exception 'Este formulário está desativado. Ative em Pesquisas antes de enviar.'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values (v_ws, v_p.id, d.pessoa_id, 'manual')
    on conflict (pesquisa_id, pessoa_id) do nothing;
  select * into v_e from pesquisa_envios where pesquisa_id = v_p.id and pessoa_id = d.pessoa_id;
  update diagnosticos set envio_id = v_e.id where id = p_diag;
  insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (v_ws, p_diag, 'status', 'Formulário escolhido: ' || v_p.nome);
  return jsonb_build_object('envio_id', v_e.id, 'token', v_e.token, 'status', v_e.status);
end $$;

-- 6. marcar como enviado (por WhatsApp, e-mail ou link copiado)
create or replace function public.diagnostico_formulario_enviado(p_diag uuid, p_canal text) returns void
language plpgsql security definer set search_path = public as $$
declare v_ws uuid := diag_pode(p_diag); d diagnosticos;
begin
  select * into d from diagnosticos where id = p_diag;
  if d.envio_id is null then raise exception 'Escolha o formulário antes de enviar.'; end if;
  if p_canal not in ('whatsapp', 'email', 'link') then raise exception 'Canal inválido.'; end if;
  update pesquisa_envios set status = case when status = 'pendente' then 'enviado' else status end, enviado_em = coalesce(enviado_em, now()) where id = d.envio_id;
  insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (v_ws, p_diag, 'status',
    'Formulário enviado ' || case p_canal when 'whatsapp' then 'por WhatsApp' when 'email' then 'por e-mail' else '(link copiado)' end);
end $$;

-- 7. padrão do diagnóstico
create or replace function public.diagnostico_formulario_padrao(p_pesquisa uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found or v_p.tipo <> 'diagnostico' or not pertence_ao_workspace(v_p.workspace_id) or not perm(v_p.workspace_id, 'editar', array['gro']) then raise exception 'Sem permissão.'; end if;
  update pesquisas set padrao_diagnostico = false where workspace_id = v_p.workspace_id and padrao_diagnostico and id <> p_pesquisa;
  update pesquisas set padrao_diagnostico = true where id = p_pesquisa;
end $$;

-- 8. clientes esperando diagnóstico: na etapa "Diagnóstico" da jornada, ou com contrato ativo, sem diagnóstico aberto
create or replace function public.diagnosticos_clientes(p_ws uuid) returns jsonb
language sql stable security invoker set search_path = public as $$
  with abertos as (select pessoa_id from diagnosticos where workspace_id = p_ws and pessoa_id is not null and status <> 'arquivado'),
  jor as (select distinct on (a.pessoa_id) a.pessoa_id, a.id aluno_id, a.contrato_id, a.produto_id, ek.nome etapa, a.entrou_em dt
    from alunos a join etapas_kanban ek on ek.id = a.etapa_kanban_id
    where a.workspace_id = p_ws and ek.nome ilike '%diagn%' and coalesce(a.status, 'ativo') not in ('cancelado', 'concluido', 'inativo')
    order by a.pessoa_id, a.entrou_em desc),
  con as (select distinct on (c.pessoa_id) c.pessoa_id, null::uuid aluno_id, c.id contrato_id, null::uuid produto_id, null::text etapa, coalesce(c.ativado_em::date, c.data_inicio) dt
    from contratos c where c.workspace_id = p_ws and c.status = 'ativo' and c.pessoa_id is not null order by c.pessoa_id, c.ativado_em desc nulls last),
  todos as (select *, 'jornada' origem from jor union all select *, 'contrato' from con where pessoa_id not in (select pessoa_id from jor))
  select coalesce(jsonb_agg(jsonb_build_object('pessoa_id', t.pessoa_id, 'nome', p.nome, 'email', p.email, 'telefone', p.telefone, 'origem', t.origem, 'etapa', t.etapa,
      'aluno_id', t.aluno_id, 'contrato_id', t.contrato_id, 'produto', (select nome from produtos where id = t.produto_id), 'desde', t.dt) order by (t.origem = 'jornada') desc, t.dt desc nulls last), '[]'::jsonb)
  from todos t join pessoas p on p.id = t.pessoa_id where t.pessoa_id not in (select pessoa_id from abertos)
$$;

-- 9. progresso: o formulário vira as duas primeiras etapas
create or replace function public.diagnostico_progresso(p_diag uuid) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare d diagnosticos; e pesquisa_envios; n_arq int; n_cls int; n_pla int; n_pla_lido int; n_nsm int; et jsonb;
begin
  select * into d from diagnosticos where id = p_diag;
  if not found then return null; end if;
  if d.envio_id is not null then select * into e from pesquisa_envios where id = d.envio_id; end if;
  select count(*), count(classe), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$'), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$' and processamento = 'lido')
    into n_arq, n_cls, n_pla, n_pla_lido from pesquisa_arquivos where diagnostico_id = p_diag and status = 'enviado' and arquivado_em is null;
  select count(*) into n_nsm from growth_metricas where workspace_id = d.workspace_id and tipo = 'north_star';
  et := jsonb_build_array(
    jsonb_build_object('k', 'enviado', 'rot', 'Formulário enviado', 'ok', d.resposta_id is not null or e.enviado_em is not null, 'det', case when d.envio_id is null then 'escolher e enviar' when e.enviado_em is null and d.resposta_id is null then 'link pronto' else 'enviado' end),
    jsonb_build_object('k', 'formulario', 'rot', 'Formulário respondido', 'ok', d.resposta_id is not null, 'det', case when d.resposta_id is not null then 'respondido' when e.rascunho_em is not null then 'cliente preenchendo' else 'aguardando' end),
    jsonb_build_object('k', 'evidencias', 'rot', 'Evidências recebidas', 'ok', n_arq > 0, 'det', n_arq || ' arquivo(s)'),
    jsonb_build_object('k', 'classificacao', 'rot', 'Evidências classificadas', 'ok', n_arq > 0 and n_cls = n_arq, 'det', n_cls || ' de ' || n_arq),
    jsonb_build_object('k', 'dados', 'rot', 'Planilhas lidas', 'ok', d.leitura is not null or (n_pla > 0 and n_pla_lido = n_pla), 'det', case when n_pla = 0 then 'nenhuma planilha' else n_pla_lido || ' de ' || n_pla end),
    jsonb_build_object('k', 'pre', 'rot', 'Pré-diagnóstico revisado', 'ok', d.arquitetura -> 'pre' ->> 'revisado_em' is not null, 'det', case when d.arquitetura -> 'pre' ->> 'revisado_em' is null then 'antes da reunião' else 'pronto para a reunião' end),
    jsonb_build_object('k', 'numeros', 'rot', 'Números que decidem', 'ok', coalesce(array_length(d.decide, 1), 0) > 0, 'det', coalesce(array_length(d.decide, 1), 0) || ' marcado(s) na reunião'),
    jsonb_build_object('k', 'nsm', 'rot', 'North Star definida', 'ok', n_nsm > 0, 'det', case when n_nsm = 0 then 'sem North Star' else n_nsm || ' na árvore' end),
    jsonb_build_object('k', 'validado', 'rot', 'Diagnóstico validado', 'ok', d.status = 'validado', 'det', ('{"rascunho":"em coleta","em_analise":"em análise","em_revisao":"em revisão","validado":"validado","arquivado":"arquivado"}'::jsonb ->> d.status)));
  return jsonb_build_object('etapas', et, 'feitas', (select count(*) from jsonb_array_elements(et) x where (x ->> 'ok')::boolean), 'total', jsonb_array_length(et),
    'pct', round(100.0 * (select count(*) from jsonb_array_elements(et) x where (x ->> 'ok')::boolean) / jsonb_array_length(et)));
end $$;

revoke all on function public.diagnostico_formulario(uuid, uuid) from public, anon;
revoke all on function public.diagnostico_formulario_enviado(uuid, text) from public, anon;
revoke all on function public.diagnostico_formulario_padrao(uuid) from public, anon;
revoke all on function public.diagnosticos_clientes(uuid) from public, anon;
grant execute on function public.diagnostico_formulario(uuid, uuid) to authenticated;
grant execute on function public.diagnostico_formulario_enviado(uuid, text) to authenticated;
grant execute on function public.diagnostico_formulario_padrao(uuid) to authenticated;
grant execute on function public.diagnosticos_clientes(uuid) to authenticated;

-- Para desfazer: drop function diagnosticos_clientes(uuid), diagnostico_formulario_padrao(uuid), diagnostico_formulario_enviado(uuid, text), diagnostico_formulario(uuid, uuid);
-- drop trigger pesquisa_respostas_diag_t on pesquisa_respostas; drop function pesquisa_respostas_diag();
-- rodar de novo diagnosticos_coerente e diagnostico_progresso das migrações anteriores; as colunas novas podem ficar.
