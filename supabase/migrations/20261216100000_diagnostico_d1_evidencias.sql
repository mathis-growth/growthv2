-- v0.223 — Growth's Brain, Diagnóstico Inteligente D1: o diagnóstico da empresa e a Central de Evidências.
-- Decisões da Rebecka (02/11): o diagnóstico é da empresa (workspace) e publica no Planejamento dela; IA com limite diário (D5);
-- construir de D1 a D8. Auditoria: docs/growths-brain-diagnostico-auditoria.md.
-- Tudo aditivo e idempotente. Rode depois de 20261215100000_brain_metas_areas.sql.
--  1. diagnosticos: pode nascer sem formulário (resposta_id opcional); título, responsável, período de referência, versão; mais estados.
--  2. diagnostico_decisoes: histórico (mudanças de status, decisões e comentários).
--  3. pesquisa_arquivos vira a Central de Evidências: arquivos da equipe também, hash (duplicidade), classificação manual ou sugerida
--     (a sugerida nunca troca a manual), período representado, dados pessoais, versão, status de processamento, arquivar (o original
--     nunca é apagado pela equipe).
--  4. Funções da equipe: registrar, confirmar, editar, conferir hash, arquivar e restaurar, marcar processamento; progresso e lista.
--  5. Storage: a equipe envia para o local privado "diagnostico" só no caminho que a função autorizou.

-- ---------- 1. diagnosticos ----------
alter table diagnosticos alter column resposta_id drop not null;
alter table diagnosticos add column if not exists titulo text;
alter table diagnosticos add column if not exists responsavel_id uuid references equipe(id) on delete set null;
alter table diagnosticos add column if not exists periodo_ini date;
alter table diagnosticos add column if not exists periodo_fim date;
alter table diagnosticos add column if not exists versao int not null default 1;
alter table diagnosticos add column if not exists criado_por uuid;
alter table diagnosticos drop constraint if exists diagnosticos_status_check;
alter table diagnosticos add constraint diagnosticos_status_check check (status in ('rascunho', 'em_analise', 'em_revisao', 'validado', 'arquivado'));
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'diagnosticos_titulo_ck') then
    alter table diagnosticos add constraint diagnosticos_titulo_ck check (titulo is null or length(titulo) between 1 and 160); end if;
  if not exists (select 1 from pg_constraint where conname = 'diagnosticos_periodo_ck') then
    alter table diagnosticos add constraint diagnosticos_periodo_ck check (periodo_ini is null or periodo_fim is null or periodo_fim >= periodo_ini); end if;
  if not exists (select 1 from pg_constraint where conname = 'diagnosticos_versao_ck') then
    alter table diagnosticos add constraint diagnosticos_versao_ck check (versao between 1 and 999); end if;
end $$;
create index if not exists diagnosticos_ws on diagnosticos (workspace_id, status);

-- a resposta passa a ser opcional; quando existe, pesquisa, envio e pessoa vêm dela
create or replace function public.diagnosticos_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare r pesquisa_respostas; v_ok boolean;
begin
  if new.resposta_id is not null then
    select * into r from pesquisa_respostas where id = new.resposta_id;
    if not found then raise exception 'Resposta não encontrada.'; end if;
    if new.workspace_id is distinct from r.workspace_id then raise exception 'O diagnóstico precisa ser da mesma empresa da resposta.'; end if;
    new.pesquisa_id := r.pesquisa_id; new.envio_id := r.envio_id; new.pessoa_id := r.pessoa_id;
  elsif tg_op = 'UPDATE' and old.resposta_id is not null then
    raise exception 'Não dá para desligar o formulário de um diagnóstico.';
  else
    new.pesquisa_id := null; new.envio_id := null;
  end if;
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

-- títulos dos diagnósticos que já existem (nascidos da reunião)
update diagnosticos d set titulo = left('Diagnóstico de ' || coalesce((select nome from pessoas where id = d.pessoa_id), 'cliente'), 160) where titulo is null;

-- ---------- 2. histórico ----------
create table if not exists diagnostico_decisoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  diagnostico_id uuid not null references diagnosticos(id) on delete cascade,
  tipo text not null check (tipo in ('status', 'decisao', 'comentario')),
  texto text not null check (length(texto) between 1 and 5000),
  autor uuid default auth.uid(),
  criado_em timestamptz not null default now()
);
create index if not exists diagnostico_decisoes_d on diagnostico_decisoes (diagnostico_id, criado_em desc);
create or replace function public.diagnostico_decisoes_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from diagnosticos where id = new.diagnostico_id;
  if v_ws is null then raise exception 'Diagnóstico não encontrado.'; end if;
  new.workspace_id := v_ws; new.autor := coalesce(new.autor, auth.uid()); new.criado_em := now();
  return new;
end $$;
drop trigger if exists diagnostico_decisoes_coerente_t on diagnostico_decisoes;
create trigger diagnostico_decisoes_coerente_t before insert on diagnostico_decisoes for each row execute function diagnostico_decisoes_coerente();

alter table diagnostico_decisoes enable row level security;
drop policy if exists diagnostico_decisoes_acesso on diagnostico_decisoes;
drop policy if exists perm_ler on diagnostico_decisoes;
drop policy if exists perm_inserir on diagnostico_decisoes;
create policy diagnostico_decisoes_acesso on diagnostico_decisoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on diagnostico_decisoes as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['gro', 'adm', 'mkt']));
create policy perm_inserir on diagnostico_decisoes as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', array['gro']));
revoke all on diagnostico_decisoes from anon, authenticated;
grant select, insert on diagnostico_decisoes to authenticated;   -- histórico: não se edita nem se apaga

-- cada mudança de status fica no histórico
create or replace function public.diagnosticos_status_log() returns trigger language plpgsql security definer set search_path = public as $$
declare rot jsonb := '{"rascunho":"Em coleta","em_analise":"Em análise","em_revisao":"Em revisão","validado":"Validado","arquivado":"Arquivado"}';
begin
  if tg_op = 'INSERT' then
    insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (new.workspace_id, new.id, 'status', 'Diagnóstico criado (' || (rot ->> new.status) || ')');
  elsif new.status is distinct from old.status then
    insert into diagnostico_decisoes (workspace_id, diagnostico_id, tipo, texto) values (new.workspace_id, new.id, 'status', 'De "' || (rot ->> old.status) || '" para "' || (rot ->> new.status) || '"');
  end if;
  return null;
end $$;
drop trigger if exists diagnosticos_status_log_t on diagnosticos;
create trigger diagnosticos_status_log_t after insert or update of status on diagnosticos for each row execute function diagnosticos_status_log();

-- ---------- 3. Central de Evidências (pesquisa_arquivos) ----------
alter table pesquisa_arquivos alter column envio_id drop not null;
alter table pesquisa_arquivos alter column pesquisa_id drop not null;
alter table pesquisa_arquivos add column if not exists diagnostico_id uuid references diagnosticos(id) on delete set null;
alter table pesquisa_arquivos add column if not exists origem text not null default 'cliente';
alter table pesquisa_arquivos add column if not exists enviado_por uuid;
alter table pesquisa_arquivos add column if not exists hash text;
alter table pesquisa_arquivos add column if not exists classe text;
alter table pesquisa_arquivos add column if not exists classe_origem text;
alter table pesquisa_arquivos add column if not exists periodo_ini date;
alter table pesquisa_arquivos add column if not exists periodo_fim date;
alter table pesquisa_arquivos add column if not exists dados_pessoais boolean not null default false;
alter table pesquisa_arquivos add column if not exists versao int not null default 1;
alter table pesquisa_arquivos add column if not exists processamento text not null default 'aguardando';
alter table pesquisa_arquivos add column if not exists processamento_erro text;
alter table pesquisa_arquivos add column if not exists processado_em timestamptz;
alter table pesquisa_arquivos add column if not exists arquivado_em timestamptz;
alter table pesquisa_arquivos add column if not exists arquivado_por uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_origem_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_origem_ck check (origem in ('cliente', 'equipe')); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_dono_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_dono_ck check (envio_id is not null or diagnostico_id is not null); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_hash_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_hash_ck check (hash is null or hash ~ '^[0-9a-f]{64}$'); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_classe_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_classe_ck check (classe is null or classe in ('estrategia', 'modelo_negocio', 'produto', 'oferta', 'publico',
      'jornada', 'marketing', 'vendas', 'cs', 'financeiro', 'pesquisa', 'operacao', 'dados_brutos', 'outros')); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_classe_origem_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_classe_origem_ck check (classe_origem is null or classe_origem in ('manual', 'sugerida')); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_periodo_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_periodo_ck check (periodo_ini is null or periodo_fim is null or periodo_fim >= periodo_ini); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_proc_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_proc_ck check (processamento in ('aguardando', 'processando', 'lido', 'erro', 'so_guardar')); end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_arquivos_versao_ck') then
    alter table pesquisa_arquivos add constraint pesquisa_arquivos_versao_ck check (versao between 1 and 999); end if;
end $$;
create index if not exists pesquisa_arquivos_diag on pesquisa_arquivos (diagnostico_id, status);
create index if not exists pesquisa_arquivos_hash on pesquisa_arquivos (diagnostico_id, hash) where hash is not null;

-- o processamento esperado pelo tipo do arquivo: planilhas e documentos de texto são lidos; imagens e apresentações ficam guardadas
create or replace function public.diag_arquivo_proc_inicial(p_nome text) returns text language sql immutable as $$
  select case when lower(substring(p_nome from '\.([A-Za-z0-9]{1,5})$')) in ('xlsx', 'xls', 'csv', 'txt', 'pdf', 'docx', 'doc') then 'aguardando' else 'so_guardar' end
$$;

-- arquivo do cliente entra no diagnóstico ligado ao mesmo link; a empresa é sempre a do diagnóstico
create or replace function public.pesquisa_arquivos_diag() returns trigger language plpgsql security definer set search_path = public as $$
declare v_ws uuid;
begin
  if new.diagnostico_id is null and new.envio_id is not null then
    select id into new.diagnostico_id from diagnosticos where envio_id = new.envio_id order by criado_em limit 1;
  end if;
  if new.diagnostico_id is not null then
    select workspace_id into v_ws from diagnosticos where id = new.diagnostico_id;
    if v_ws is distinct from new.workspace_id then raise exception 'O arquivo precisa ser da mesma empresa do diagnóstico.'; end if;
  end if;
  if tg_op = 'INSERT' then new.processamento := diag_arquivo_proc_inicial(new.nome); end if;
  return new;
end $$;
drop trigger if exists pesquisa_arquivos_diag_t on pesquisa_arquivos;
create trigger pesquisa_arquivos_diag_t before insert or update of diagnostico_id on pesquisa_arquivos for each row execute function pesquisa_arquivos_diag();

-- quando o diagnóstico ganha (ou já tem) um formulário, os arquivos daquele link entram nele
create or replace function public.diagnosticos_liga_arquivos() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.envio_id is not null then
    update pesquisa_arquivos set diagnostico_id = new.id where envio_id = new.envio_id and diagnostico_id is null;
  end if;
  return null;
end $$;
drop trigger if exists diagnosticos_liga_arquivos_t on diagnosticos;
create trigger diagnosticos_liga_arquivos_t after insert or update of resposta_id on diagnosticos for each row execute function diagnosticos_liga_arquivos();
update pesquisa_arquivos a set diagnostico_id = d.id from diagnosticos d where a.envio_id = d.envio_id and a.diagnostico_id is null;
update pesquisa_arquivos set processamento = diag_arquivo_proc_inicial(nome) where processamento = 'aguardando' and diag_arquivo_proc_inicial(nome) = 'so_guardar';

-- ---------- 4. funções da equipe ----------
-- confere o diagnóstico e a permissão de editar (Growth); devolve a empresa
create or replace function public.diag_pode(p_diag uuid) returns uuid language plpgsql stable security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from diagnosticos where id = p_diag;
  if v_ws is null or not pertence_ao_workspace(v_ws) then raise exception 'Diagnóstico não encontrado.'; end if;
  if not perm(v_ws, 'editar', array['gro']) then raise exception 'Sem permissão para editar o diagnóstico.'; end if;
  return v_ws;
end $$;
create or replace function public.diag_arquivo_pode(p_id uuid) returns pesquisa_arquivos language plpgsql stable security definer set search_path = public as $$
declare a pesquisa_arquivos;
begin
  select * into a from pesquisa_arquivos where id = p_id;
  if not found or a.diagnostico_id is null then raise exception 'Arquivo não encontrado.'; end if;
  perform diag_pode(a.diagnostico_id);
  return a;
end $$;

-- 4.1 registrar um arquivo da equipe (antes do envio). Mesmo conteúdo (hash) já guardado no diagnóstico: não registra, devolve o que já existe.
create or replace function public.diagnostico_arquivo_registrar(p_diag uuid, p_nome text, p_tamanho bigint, p_tipo text, p_hash text,
  p_classe text default null, p_classe_origem text default null, p_ini date default null, p_fim date default null, p_pessoais boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ws uuid := diag_pode(p_diag); v_ext text; v_id uuid := gen_random_uuid(); v_cam text; v_nome text; v_dup pesquisa_arquivos; v_ver int;
begin
  v_nome := left(btrim(regexp_replace(coalesce(p_nome, ''), '[[:cntrl:]/\\]', '', 'g')), 200);
  v_ext := lower(substring(v_nome from '\.([A-Za-z0-9]{1,5})$'));
  if v_ext is null or v_ext not in ('xlsx', 'xls', 'csv', 'txt', 'pdf', 'doc', 'docx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg') then
    raise exception 'Tipo de arquivo não aceito. Envie planilha, CSV, texto, PDF, Word, PowerPoint ou imagem.';
  end if;
  if p_tamanho is null or p_tamanho <= 0 then raise exception 'Arquivo vazio.'; end if;
  if p_tamanho > 20971520 then raise exception 'Arquivo maior que 20 MB. Divida em partes.'; end if;
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'Não consegui conferir o conteúdo do arquivo.'; end if;
  if p_classe_origem is not null and p_classe_origem not in ('manual', 'sugerida') then raise exception 'Classificação inválida.'; end if;
  select * into v_dup from pesquisa_arquivos where diagnostico_id = p_diag and hash = p_hash and status = 'enviado' and arquivado_em is null limit 1;
  if found then return jsonb_build_object('duplicado', true, 'id', v_dup.id, 'nome', v_dup.nome); end if;
  delete from pesquisa_arquivos where diagnostico_id = p_diag and origem = 'equipe' and status = 'pendente' and criado_em < now() - interval '1 day';
  if (select count(*) from pesquisa_arquivos where diagnostico_id = p_diag and arquivado_em is null) >= 200 then raise exception 'Este diagnóstico já tem 200 arquivos. Arquive os que não servem mais.'; end if;
  select coalesce(max(versao), 0) + 1 into v_ver from pesquisa_arquivos where diagnostico_id = p_diag and lower(nome) = lower(v_nome) and status = 'enviado';
  v_cam := v_ws || '/diag/' || p_diag || '/' || v_id || '.' || v_ext;
  insert into pesquisa_arquivos (id, workspace_id, diagnostico_id, origem, enviado_por, grupo, nome, caminho, tamanho, tipo, hash, classe, classe_origem, periodo_ini, periodo_fim, dados_pessoais, versao)
    values (v_id, v_ws, p_diag, 'equipe', auth.uid(), 'equipe', v_nome, v_cam, p_tamanho, left(p_tipo, 120), p_hash, p_classe,
      case when p_classe is null then null else coalesce(p_classe_origem, 'manual') end, p_ini, p_fim, coalesce(p_pessoais, false), least(v_ver, 999));
  return jsonb_build_object('duplicado', false, 'id', v_id, 'caminho', v_cam, 'versao', v_ver);
end $$;

-- 4.2 confirmar que o arquivo chegou ao Storage
create or replace function public.diagnostico_arquivo_confirmar(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id);
begin
  if a.origem <> 'equipe' or a.status <> 'pendente' then raise exception 'Arquivo não encontrado.'; end if;
  if to_regclass('storage.objects') is not null then
    if not exists (select 1 from storage.objects where bucket_id = 'diagnostico' and name = a.caminho) then raise exception 'O arquivo não chegou. Tente enviar de novo.'; end if;
  end if;
  update pesquisa_arquivos set status = 'enviado', enviado_em = now() where id = p_id;
end $$;

-- 4.3 classificação, período e dados pessoais. A sugerida nunca troca a manual.
create or replace function public.diagnostico_arquivo_editar(p_id uuid, p_campos jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id); v_c text; v_o text;
begin
  if p_campos ? 'classe' then
    v_c := nullif(p_campos ->> 'classe', ''); v_o := coalesce(p_campos ->> 'classe_origem', 'manual');
    if v_o not in ('manual', 'sugerida') then raise exception 'Classificação inválida.'; end if;
    if not (v_o = 'sugerida' and a.classe_origem = 'manual') then
      update pesquisa_arquivos set classe = v_c, classe_origem = case when v_c is null then null else v_o end where id = p_id;
    end if;
  end if;
  if p_campos ? 'periodo_ini' or p_campos ? 'periodo_fim' then
    update pesquisa_arquivos set periodo_ini = case when p_campos ? 'periodo_ini' then nullif(p_campos ->> 'periodo_ini', '')::date else periodo_ini end,
      periodo_fim = case when p_campos ? 'periodo_fim' then nullif(p_campos ->> 'periodo_fim', '')::date else periodo_fim end where id = p_id;
  end if;
  if p_campos ? 'dados_pessoais' then update pesquisa_arquivos set dados_pessoais = coalesce((p_campos ->> 'dados_pessoais')::boolean, false) where id = p_id; end if;
  return (select to_jsonb(x) - 'caminho' from pesquisa_arquivos x where id = p_id);
end $$;

-- 4.4 hash de um arquivo do cliente (conferido pela equipe): devolve se já existe outro igual no diagnóstico
create or replace function public.diagnostico_arquivo_hash(p_id uuid, p_hash text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id); v_dup pesquisa_arquivos;
begin
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then raise exception 'Hash inválido.'; end if;
  if a.hash is not null and a.hash <> p_hash then raise exception 'O conteúdo deste arquivo já foi conferido com outro resultado.'; end if;
  update pesquisa_arquivos set hash = p_hash where id = p_id and hash is null;
  select * into v_dup from pesquisa_arquivos where diagnostico_id = a.diagnostico_id and hash = p_hash and id <> p_id and status = 'enviado' and arquivado_em is null order by enviado_em limit 1;
  return jsonb_build_object('duplicado', v_dup.id is not null, 'id', v_dup.id, 'nome', v_dup.nome);
end $$;

-- 4.5 arquivar e restaurar (o original continua guardado)
create or replace function public.diagnostico_arquivo_arquivar(p_id uuid, p_arquivar boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id);
begin
  update pesquisa_arquivos set arquivado_em = case when p_arquivar then now() end, arquivado_por = case when p_arquivar then auth.uid() end where id = p_id;
end $$;

-- 4.6 processamento (leitura de planilha na tela; documentos de texto na D5)
create or replace function public.diagnostico_arquivo_processamento(p_id uuid, p_status text, p_erro text default null) returns void
language plpgsql security definer set search_path = public as $$
declare a pesquisa_arquivos := diag_arquivo_pode(p_id);
begin
  if p_status not in ('aguardando', 'processando', 'lido', 'erro') then raise exception 'Status inválido.'; end if;
  if a.processamento = 'so_guardar' then return; end if;
  update pesquisa_arquivos set processamento = p_status, processamento_erro = case when p_status = 'erro' then left(coalesce(p_erro, 'Erro ao ler o arquivo.'), 1000) end,
    processado_em = case when p_status in ('lido', 'erro') then now() end where id = p_id;
end $$;

-- 4.7 progresso: as etapas do diagnóstico que já têm o que precisam (cresce com as próximas versões)
create or replace function public.diagnostico_progresso(p_diag uuid) returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare d diagnosticos; n_arq int; n_cls int; n_pla int; n_pla_lido int; n_nsm int; e jsonb;
begin
  select * into d from diagnosticos where id = p_diag;
  if not found then return null; end if;
  select count(*), count(classe), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$'), count(*) filter (where nome ~* '\.(xlsx|xls|csv|txt)$' and processamento = 'lido')
    into n_arq, n_cls, n_pla, n_pla_lido from pesquisa_arquivos where diagnostico_id = p_diag and status = 'enviado' and arquivado_em is null;
  select count(*) into n_nsm from growth_metricas where workspace_id = d.workspace_id and tipo = 'north_star';
  e := jsonb_build_array(
    jsonb_build_object('k', 'evidencias', 'rot', 'Evidências recebidas', 'ok', n_arq > 0, 'det', n_arq || ' arquivo(s)'),
    jsonb_build_object('k', 'classificacao', 'rot', 'Evidências classificadas', 'ok', n_arq > 0 and n_cls = n_arq, 'det', n_cls || ' de ' || n_arq),
    jsonb_build_object('k', 'formulario', 'rot', 'Formulário do cliente respondido', 'ok', d.resposta_id is not null, 'det', case when d.resposta_id is null then 'sem formulário ligado' else 'respondido' end),
    jsonb_build_object('k', 'numeros', 'rot', 'Números que decidem', 'ok', coalesce(array_length(d.decide, 1), 0) > 0, 'det', coalesce(array_length(d.decide, 1), 0) || ' marcado(s)'),
    jsonb_build_object('k', 'dados', 'rot', 'Planilhas lidas', 'ok', d.leitura is not null or (n_pla > 0 and n_pla_lido = n_pla), 'det', case when n_pla = 0 then 'nenhuma planilha' else n_pla_lido || ' de ' || n_pla end),
    jsonb_build_object('k', 'nsm', 'rot', 'North Star definida', 'ok', n_nsm > 0, 'det', case when n_nsm = 0 then 'sem North Star' else n_nsm || ' na árvore' end),
    jsonb_build_object('k', 'validado', 'rot', 'Diagnóstico validado', 'ok', d.status = 'validado', 'det', ('{"rascunho":"em coleta","em_analise":"em análise","em_revisao":"em revisão","validado":"validado","arquivado":"arquivado"}'::jsonb ->> d.status)));
  return jsonb_build_object('etapas', e, 'feitas', (select count(*) from jsonb_array_elements(e) x where (x ->> 'ok')::boolean), 'total', jsonb_array_length(e),
    'pct', round(100.0 * (select count(*) from jsonb_array_elements(e) x where (x ->> 'ok')::boolean) / jsonb_array_length(e)));
end $$;

-- 4.8 lista dos diagnósticos da empresa (o que a tela mostra)
create or replace function public.diagnosticos_lista(p_ws uuid) returns jsonb
language sql stable security invoker set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'titulo', coalesce(d.titulo, 'Diagnóstico'), 'status', d.status, 'versao', d.versao,
    'periodo_ini', d.periodo_ini, 'periodo_fim', d.periodo_fim, 'responsavel', (select nome from equipe where id = d.responsavel_id),
    'responsavel_id', d.responsavel_id, 'resposta_id', d.resposta_id, 'pessoa', (select nome from pessoas where id = d.pessoa_id),
    'arquivos', (select count(*) from pesquisa_arquivos a where a.diagnostico_id = d.id and a.status = 'enviado' and a.arquivado_em is null),
    'progresso', diagnostico_progresso(d.id), 'criado_em', d.criado_em, 'atualizado_em', d.atualizado_em) order by (d.status = 'arquivado'), d.atualizado_em desc), '[]'::jsonb)
  from diagnosticos d where d.workspace_id = p_ws
$$;

revoke all on function public.diag_pode(uuid) from public, anon;
revoke all on function public.diag_arquivo_pode(uuid) from public, anon;
revoke all on function public.diagnostico_arquivo_registrar(uuid, text, bigint, text, text, text, text, date, date, boolean) from public, anon;
revoke all on function public.diagnostico_arquivo_confirmar(uuid) from public, anon;
revoke all on function public.diagnostico_arquivo_editar(uuid, jsonb) from public, anon;
revoke all on function public.diagnostico_arquivo_hash(uuid, text) from public, anon;
revoke all on function public.diagnostico_arquivo_arquivar(uuid, boolean) from public, anon;
revoke all on function public.diagnostico_arquivo_processamento(uuid, text, text) from public, anon;
revoke all on function public.diagnostico_progresso(uuid) from public, anon;
revoke all on function public.diagnosticos_lista(uuid) from public, anon;
grant execute on function public.diagnostico_arquivo_registrar(uuid, text, bigint, text, text, text, text, date, date, boolean) to authenticated;
grant execute on function public.diagnostico_arquivo_confirmar(uuid) to authenticated;
grant execute on function public.diagnostico_arquivo_editar(uuid, jsonb) to authenticated;
grant execute on function public.diagnostico_arquivo_hash(uuid, text) to authenticated;
grant execute on function public.diagnostico_arquivo_arquivar(uuid, boolean) to authenticated;
grant execute on function public.diagnostico_arquivo_processamento(uuid, text, text) to authenticated;
grant execute on function public.diagnostico_progresso(uuid) to authenticated;
grant execute on function public.diagnosticos_lista(uuid) to authenticated;

-- ---------- 5. Storage: envio pela equipe ----------
do $s$ begin
  if to_regclass('storage.buckets') is not null then
    execute 'drop policy if exists diagnostico_equipe_enviar on storage.objects';
    execute $p$create policy diagnostico_equipe_enviar on storage.objects for insert to authenticated with check (
      bucket_id = 'diagnostico' and exists (select 1 from public.pesquisa_arquivos a where a.caminho = storage.objects.name and a.origem = 'equipe' and a.status = 'pendente'
        and public.pertence_ao_workspace(a.workspace_id) and public.perm(a.workspace_id, 'editar', array['gro'])))$p$;
  end if;
end $s$;

-- Para desfazer: drop policy diagnostico_equipe_enviar on storage.objects;
-- drop function diagnosticos_lista(uuid), diagnostico_progresso(uuid), diagnostico_arquivo_processamento(uuid, text, text), diagnostico_arquivo_arquivar(uuid, boolean),
--   diagnostico_arquivo_hash(uuid, text), diagnostico_arquivo_editar(uuid, jsonb), diagnostico_arquivo_confirmar(uuid),
--   diagnostico_arquivo_registrar(uuid, text, bigint, text, text, text, text, date, date, boolean), diag_arquivo_pode(uuid), diag_pode(uuid);
-- drop trigger diagnosticos_liga_arquivos_t on diagnosticos; drop trigger pesquisa_arquivos_diag_t on pesquisa_arquivos; drop trigger diagnosticos_status_log_t on diagnosticos;
-- drop table diagnostico_decisoes; as colunas novas de pesquisa_arquivos e diagnosticos podem ficar (não atrapalham o que já existia).
