-- v0.163 — Versões da jornada do produto (Customer Growth, etapa B3).
-- 1. aluno_historico ganha o tipo 'jornada' (troca de versão) e as colunas jornada_id (para onde foi) e jornada_de (de onde veio).
-- 2. jornada_rascunho(produto, base, da_geral): cria a próxima versão em rascunho, copiando as etapas de uma jornada
--    (outra versão do produto ou um modelo), da jornada geral, ou vazia.
-- 3. jornada_transferir(de, para, mapa): leva alunos de uma versão (ou da jornada geral, de = nulo) para outra versão do mesmo produto.
--    mapa = {"<etapa antiga>": "<etapa nova>"}; etapa antiga fora do mapa (ou com valor nulo) = esses alunos ficam onde estão.
-- 4. jornada_publicar(jornada, modo, mapa): publica o rascunho. A publicada de antes vira 'anterior'. modo 'continuar' = ninguém muda;
--    'transferir' = leva os alunos da versão anterior (ou da jornada geral, na primeira versão) pelo mapa.
--    As pesquisas ligadas a etapas da versão anterior passam a apontar para a etapa equivalente da nova (pelo mapa ou pelo nome).
-- 5. jornada_salvar_modelo(jornada, nome): guarda a jornada como modelo (sem produto) para criar outras a partir dela.
-- Rode depois de 20261117100000_jornada_produto.sql. Idempotente.

alter table aluno_historico add column if not exists jornada_id uuid references jornadas(id) on delete set null;
alter table aluno_historico add column if not exists jornada_de uuid references jornadas(id) on delete set null;
alter table aluno_historico add column if not exists por_usuario uuid default auth.uid();
alter table aluno_historico drop constraint if exists aluno_historico_tipo_check;
alter table aluno_historico add constraint aluno_historico_tipo_check check (tipo in ('etapa', 'saida', 'volta', 'jornada'));

create or replace function public._jornada_pode(p_ws uuid) returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not pode_operar(p_ws) or not (perm(p_ws, 'editar', array['revops', 'vendas', 'cad']) or session_user in ('postgres', 'supabase_admin') or coalesce(auth.role(), '') = 'service_role') then
    raise exception 'Sem permissão para editar a jornada deste cliente'; end if;
end $$;
revoke execute on function public._jornada_pode(uuid) from public, anon, authenticated;

create or replace function public._jornada_copiar_etapas(p_ws uuid, p_de uuid, p_geral boolean, p_para uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, descricao, mensagem_padrao, alertar_responsavel, jornada_id)
  select p_ws, 'alunos', e.nome, row_number() over (order by e.ordem, e.nome), e.descricao, e.mensagem_padrao, e.alertar_responsavel, p_para
  from etapas_kanban e
  where e.workspace_id = p_ws and e.quadro = 'alunos' and ((p_geral and e.jornada_id is null) or (not p_geral and p_de is not null and e.jornada_id = p_de));
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public._jornada_copiar_etapas(uuid, uuid, boolean, uuid) from public, anon, authenticated;

create or replace function public.jornada_rascunho(p_produto uuid, p_base uuid default null, p_da_geral boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare pr produtos; b jornadas; novo uuid; v int;
begin
  select * into pr from produtos where id = p_produto;
  if not found then raise exception 'Produto não encontrado'; end if;
  perform _jornada_pode(pr.workspace_id);
  if exists (select 1 from jornadas where produto_id = p_produto and status = 'rascunho') then raise exception 'Este produto já tem uma versão em rascunho'; end if;
  if p_base is not null then
    select * into b from jornadas where id = p_base and workspace_id = pr.workspace_id;
    if not found or not (b.modelo or b.produto_id = p_produto) then raise exception 'A base precisa ser um modelo ou uma versão deste produto'; end if;
  end if;
  select coalesce(max(versao), 0) + 1 into v from jornadas where produto_id = p_produto;
  insert into jornadas (workspace_id, produto_id, nome, versao, status, baseada_em, descricao)
  values (pr.workspace_id, p_produto, coalesce(case when b.modelo then null else b.nome end, 'Jornada do produto ' || pr.nome), v, 'rascunho', p_base, b.descricao)
  returning id into novo;
  perform _jornada_copiar_etapas(pr.workspace_id, p_base, coalesce(p_da_geral, false) and p_base is null, novo);
  return novo;
end $$;

create or replace function public.jornada_transferir(p_de uuid, p_para uuid, p_mapa jsonb default '{}'::jsonb, p_produto uuid default null) returns int
language plpgsql security definer set search_path = public as $$
declare jp jornadas; jd jornadas; r record; alvo uuid; n int := 0; prod uuid;
begin
  select * into jp from jornadas where id = p_para;
  if not found or jp.modelo then raise exception 'Versão de destino não encontrada'; end if;
  perform _jornada_pode(jp.workspace_id);
  if jp.status not in ('publicada', 'anterior') then raise exception 'Só dá para levar alunos para uma versão publicada'; end if;
  if p_de is not null then
    select * into jd from jornadas where id = p_de;
    if not found or jd.produto_id is distinct from jp.produto_id then raise exception 'As duas versões precisam ser do mesmo produto'; end if;
    if p_de = p_para then return 0; end if;
  end if;
  prod := jp.produto_id;
  if p_produto is not null and p_produto <> prod then raise exception 'A versão de destino é de outro produto'; end if;
  for r in select a.id, a.pessoa_id, a.etapa_kanban_id, a.jornada_id from alunos a
           where a.workspace_id = jp.workspace_id and a.produto_id = prod and a.jornada_id is not distinct from p_de and a.saiu_em is null loop
    alvo := nullif(coalesce(p_mapa, '{}'::jsonb) ->> r.etapa_kanban_id::text, '')::uuid;
    if alvo is null then continue; end if;
    if not exists (select 1 from etapas_kanban where id = alvo and jornada_id = p_para) then raise exception 'A etapa de destino precisa ser da nova versão'; end if;
    update alunos set jornada_id = p_para, etapa_kanban_id = alvo where id = r.id;
    insert into aluno_historico (workspace_id, aluno_id, pessoa_id, tipo, etapa_kanban_id, jornada_id, jornada_de)
    values (jp.workspace_id, r.id, r.pessoa_id, 'jornada', alvo, p_para, p_de);
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.jornada_publicar(p_jornada uuid, p_modo text default 'continuar', p_mapa jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare j jornadas; ant uuid; n int := 0; mp jsonb := coalesce(p_mapa, '{}'::jsonb); e record; alvo uuid; np int := 0;
begin
  select * into j from jornadas where id = p_jornada for update;
  if not found or j.modelo then raise exception 'Jornada não encontrada'; end if;
  perform _jornada_pode(j.workspace_id);
  if j.status <> 'rascunho' then raise exception 'Só um rascunho pode ser publicado'; end if;
  if p_modo not in ('continuar', 'transferir') then raise exception 'Escolha continuar ou transferir'; end if;
  if not exists (select 1 from etapas_kanban where jornada_id = p_jornada) then raise exception 'Cadastre ao menos uma etapa antes de publicar'; end if;
  select id into ant from jornadas where produto_id = j.produto_id and status = 'publicada';
  if ant is not null then update jornadas set status = 'anterior' where id = ant; end if;
  update jornadas set status = 'publicada', publicada_em = now(), publicada_por = auth.uid() where id = p_jornada;
  if p_modo = 'transferir' then n := jornada_transferir(ant, p_jornada, mp, j.produto_id); end if;
  -- pesquisas ligadas às etapas da versão de antes (ou da geral, na primeira versão, só quando filtradas por este produto) seguem para a nova
  for e in select x.id, x.nome from etapas_kanban x
           where x.workspace_id = j.workspace_id and x.quadro = 'alunos' and x.jornada_id is not distinct from ant loop
    alvo := nullif(mp ->> e.id::text, '')::uuid;
    if alvo is null or not exists (select 1 from etapas_kanban where id = alvo and jornada_id = p_jornada) then
      select id into alvo from etapas_kanban where jornada_id = p_jornada and lower(nome) = lower(e.nome) limit 1;
    end if;
    if alvo is not null then
      update pesquisas set etapa_aluno_id = alvo
      where etapa_aluno_id = e.id and gatilho = 'etapa_aluno' and (ant is not null or produto_id = j.produto_id);
      get diagnostics n = row_count; np := np + n;
    end if;
  end loop;
  select count(*) into n from aluno_historico where tipo = 'jornada' and jornada_id = p_jornada and jornada_de is not distinct from ant;
  return jsonb_build_object('publicada', p_jornada, 'anterior', ant, 'transferidos', case when p_modo = 'transferir' then n else 0 end, 'pesquisas', np);
end $$;

create or replace function public.jornada_salvar_modelo(p_jornada uuid, p_nome text) returns uuid
language plpgsql security definer set search_path = public as $$
declare j jornadas; novo uuid;
begin
  select * into j from jornadas where id = p_jornada;
  if not found then raise exception 'Jornada não encontrada'; end if;
  perform _jornada_pode(j.workspace_id);
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao modelo'; end if;
  insert into jornadas (workspace_id, produto_id, nome, modelo, status, baseada_em, descricao)
  values (j.workspace_id, null, trim(p_nome), true, 'rascunho', p_jornada, j.descricao) returning id into novo;
  perform _jornada_copiar_etapas(j.workspace_id, p_jornada, false, novo);
  update jornadas set status = 'publicada' where id = novo;
  return novo;
end $$;

revoke execute on function public.jornada_rascunho(uuid, uuid, boolean), public.jornada_transferir(uuid, uuid, jsonb, uuid),
  public.jornada_publicar(uuid, text, jsonb), public.jornada_salvar_modelo(uuid, text) from public, anon;
grant execute on function public.jornada_rascunho(uuid, uuid, boolean), public.jornada_transferir(uuid, uuid, jsonb, uuid),
  public.jornada_publicar(uuid, text, jsonb), public.jornada_salvar_modelo(uuid, text) to authenticated;

-- Para desfazer: drop function if exists public.jornada_salvar_modelo(uuid, text), public.jornada_publicar(uuid, text, jsonb),
--   public.jornada_transferir(uuid, uuid, jsonb, uuid), public.jornada_rascunho(uuid, uuid, boolean), public._jornada_copiar_etapas(uuid, uuid, boolean, uuid), public._jornada_pode(uuid);
-- delete from aluno_historico where tipo = 'jornada'; alter table aluno_historico drop constraint aluno_historico_tipo_check;
-- alter table aluno_historico add constraint aluno_historico_tipo_check check (tipo in ('etapa', 'saida', 'volta'));
-- alter table aluno_historico drop column if exists por_usuario, drop column if exists jornada_de, drop column if exists jornada_id;
