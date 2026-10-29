-- v0.163 — Marcos da jornada do produto e sinais de cada aluno (Customer Growth, etapas B5 e B5b).
-- 1. jornada_marcos: o que o aluno precisa atingir (nome, o que prova, prazo em dias desde a matrícula, obrigatório, etapa ligada).
--    confirmacao: manual (a equipe confirma) | automatico (o sistema marca sozinho) | auto_confirmar (o sistema percebe e a equipe confirma).
--    regra (jsonb) para os automáticos, com dados que o Growths já guarda:
--      {"tipo":"compra","produto_id":…}                         comprou um produto (venda aprovada)
--      {"tipo":"video","fonte_id":…,"minutos":N}                assistiu a um vídeo/aula (N minutos ou mais; sem N, qualquer presença)
--      {"tipo":"pesquisa","pesquisa_id":…,"pergunta_id":…,"resposta":"Sim"}   respondeu a pesquisa (e, se informado, deu aquela resposta)
--      {"tipo":"etapa","etapa_kanban_id":…}                     chegou a uma etapa da jornada
--      {"tipo":"lista","lista_id":…}                            entrou numa lista ou grupo do funil
--      {"tipo":"evento","evento":"trabalho_xpto"}               evento vindo de fora (plataforma do curso), pelo endereço de eventos
-- 2. aluno_marcos: um por aluno e marco: situacao (atingido, aguardando, recusado), sinal (observado, declarado, validado), fonte e referência.
--    Marco recusado pela equipe não volta sozinho.
-- 3. Gatilhos em vendas, presencas_video, pesquisa_respostas/itens, aluno_historico, pessoa_lista e pessoa_toques avaliam os marcos.
--    Nunca bloqueiam a operação de origem (erro no marco não impede venda, presença ou resposta).
-- 4. marco_confirmar(aluno, marco, acao, observacao): confirmar, recusar ou desfazer.
-- 5. Eventos de fora: chave de escopo 'eventos' e evento_por_chave(chave, dados) para a edge function "leads" (?tipo=evento).
-- 6. Auditoria ligada em alunos, jornadas, jornada_marcos e aluno_marcos. As etapas copiadas para uma nova versão levam os marcos.
-- Rode depois de 20261118100000_jornada_versoes.sql. Idempotente.

create table if not exists jornada_marcos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  jornada_id uuid not null references jornadas(id) on delete cascade,
  etapa_kanban_id uuid references etapas_kanban(id) on delete set null,
  nome text not null check (char_length(nome) between 1 and 160),
  descricao text,
  evidencia text,
  prazo_dias int check (prazo_dias is null or prazo_dias between 0 and 3650),
  obrigatorio boolean not null default false,
  ordem int not null default 0,
  confirmacao text not null default 'manual' check (confirmacao in ('manual', 'automatico', 'auto_confirmar')),
  regra jsonb check (regra is null or jsonb_typeof(regra) = 'object'),
  criado_em timestamptz not null default now(),
  constraint jornada_marcos_regra_ck check (confirmacao = 'manual' or coalesce(regra->>'tipo', '') in ('compra', 'video', 'pesquisa', 'etapa', 'lista', 'evento'))
);
create index if not exists jornada_marcos_j on jornada_marcos (jornada_id, ordem);

create table if not exists aluno_marcos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  aluno_id uuid not null references alunos(id) on delete cascade,
  marco_id uuid not null references jornada_marcos(id) on delete cascade,
  situacao text not null check (situacao in ('atingido', 'aguardando', 'recusado')),
  sinal text not null check (sinal in ('observado', 'declarado', 'validado')),
  fonte text not null check (fonte in ('manual', 'compra', 'video', 'pesquisa', 'etapa', 'lista', 'evento')),
  ref_tabela text, ref_id uuid, valor text,
  em timestamptz not null default now(),
  validado_por uuid, validado_em timestamptz, observacao text,
  unique (aluno_id, marco_id)
);
create index if not exists aluno_marcos_ws on aluno_marcos (workspace_id, situacao);

create or replace function public.jornada_marcos_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from jornadas where id = new.jornada_id and workspace_id = new.workspace_id) then raise exception 'A jornada precisa ser deste cliente'; end if;
  if new.etapa_kanban_id is not null and not exists (select 1 from etapas_kanban where id = new.etapa_kanban_id and jornada_id = new.jornada_id) then
    raise exception 'A etapa do marco precisa ser desta jornada'; end if;
  if new.regra->>'tipo' = 'etapa' and not exists (select 1 from etapas_kanban where id::text = new.regra->>'etapa_kanban_id' and jornada_id = new.jornada_id) then
    raise exception 'A etapa da regra precisa ser desta jornada'; end if;
  return new;
end $$;
revoke execute on function public.jornada_marcos_valida() from public, anon, authenticated;
drop trigger if exists jornada_marcos_valida_t on jornada_marcos;
create trigger jornada_marcos_valida_t before insert or update on jornada_marcos for each row execute function jornada_marcos_valida();

create or replace function public.aluno_marcos_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from alunos a join jornada_marcos m on m.jornada_id = a.jornada_id where a.id = new.aluno_id and m.id = new.marco_id and a.workspace_id = new.workspace_id) then
    raise exception 'O marco precisa ser da jornada desta matrícula'; end if;
  return new;
end $$;
revoke execute on function public.aluno_marcos_valida() from public, anon, authenticated;
drop trigger if exists aluno_marcos_valida_t on aluno_marcos;
create trigger aluno_marcos_valida_t before insert or update of aluno_id, marco_id on aluno_marcos for each row execute function aluno_marcos_valida();

do $p$
declare t text;
begin
  foreach t in array array['jornada_marcos', 'aluno_marcos'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_acesso', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on %I', t); execute format('drop policy if exists perm_inserir on %I', t);
    execute format('drop policy if exists perm_alterar on %I', t); execute format('drop policy if exists perm_excluir on %I', t);
    execute format($f$create policy perm_ler on %I as restrictive for select using (perm(workspace_id, 'ler', array['revops','vendas','adm','prj','fin','gro','cad']))$f$, t);
    execute format($f$create policy perm_inserir on %I as restrictive for insert with check (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format($f$create policy perm_alterar on %I as restrictive for update using (perm(workspace_id, 'editar', array['revops','vendas','cad'])) with check (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format($f$create policy perm_excluir on %I as restrictive for delete using (perm(workspace_id, 'editar', array['revops','vendas','cad']))$f$, t);
    execute format('grant select, insert, update, delete on %I to authenticated', t);
  end loop;
end $p$;

-- ---------- avaliação automática ----------
-- Marca os marcos automáticos de UMA matrícula que batem com o fato (fonte + dados). Devolve quantos marcou.
create or replace function public._marco_marcar(p_aluno uuid, p_fonte text, p_ref_tabela text, p_ref_id uuid, p_dados jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare a alunos; mk record; ok boolean; n int := 0; d jsonb := coalesce(p_dados, '{}'::jsonb);
begin
  select * into a from alunos where id = p_aluno;
  if not found or a.jornada_id is null then return 0; end if;
  for mk in select * from jornada_marcos where jornada_id = a.jornada_id and confirmacao <> 'manual' and regra->>'tipo' = p_fonte loop
    ok := case p_fonte
      when 'compra' then mk.regra->>'produto_id' is null or mk.regra->>'produto_id' = d->>'produto_id'
      when 'video' then (mk.regra->>'fonte_id' is null or mk.regra->>'fonte_id' = d->>'fonte_id') and coalesce((d->>'segundos')::int, 0) >= coalesce((mk.regra->>'minutos')::numeric, 0) * 60
      when 'pesquisa' then mk.regra->>'pesquisa_id' = d->>'pesquisa_id'
        and (mk.regra->>'pergunta_id' is null or (mk.regra->>'pergunta_id' = d->>'pergunta_id'
             and (mk.regra->>'resposta' is null or lower(trim(mk.regra->>'resposta')) = lower(trim(coalesce(d->>'valor', ''))))))
      when 'etapa' then mk.regra->>'etapa_kanban_id' = d->>'etapa_kanban_id'
      when 'lista' then mk.regra->>'lista_id' = d->>'lista_id'
      when 'evento' then lower(trim(mk.regra->>'evento')) = lower(trim(coalesce(d->>'evento', '')))
      else false end;
    if not coalesce(ok, false) then continue; end if;
    insert into aluno_marcos (workspace_id, aluno_id, marco_id, situacao, sinal, fonte, ref_tabela, ref_id, valor, em)
    values (a.workspace_id, a.id, mk.id, case when mk.confirmacao = 'automatico' then 'atingido' else 'aguardando' end,
            case when p_fonte = 'pesquisa' then 'declarado' else 'observado' end, p_fonte, p_ref_tabela, p_ref_id, left(d->>'valor', 500), coalesce((d->>'em')::timestamptz, now()))
    on conflict (aluno_id, marco_id) do nothing;
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;
-- Todas as matrículas ativas da pessoa (com jornada).
create or replace function public._marco_pessoa(p_pessoa uuid, p_fonte text, p_ref_tabela text, p_ref_id uuid, p_dados jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  for r in select id from alunos where pessoa_id = p_pessoa and jornada_id is not null and saiu_em is null loop
    n := n + _marco_marcar(r.id, p_fonte, p_ref_tabela, p_ref_id, p_dados);
  end loop;
  return n;
end $$;
revoke execute on function public._marco_marcar(uuid, text, text, uuid, jsonb), public._marco_pessoa(uuid, text, text, uuid, jsonb) from public, anon, authenticated;

create or replace function public.marco_trg() returns trigger language plpgsql security definer set search_path = public as $$
declare pid uuid; pq uuid;
begin
  begin
    if tg_table_name = 'vendas' then
      if new.status = 'aprovada' and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
        perform _marco_pessoa(new.pessoa_id, 'compra', 'vendas', new.id, jsonb_build_object('produto_id', new.produto_id, 'em', new.data_venda)); end if;
    elsif tg_table_name = 'presencas_video' then
      perform _marco_pessoa(new.pessoa_id, 'video', 'presencas_video', new.id, jsonb_build_object('fonte_id', new.fonte_id, 'segundos', new.assistiu_seg));
    elsif tg_table_name = 'pesquisa_respostas' then
      if new.pessoa_id is not null then perform _marco_pessoa(new.pessoa_id, 'pesquisa', 'pesquisa_respostas', new.id, jsonb_build_object('pesquisa_id', new.pesquisa_id, 'em', new.respondida_em)); end if;
    elsif tg_table_name = 'pesquisa_resposta_itens' then
      select r.pessoa_id, r.pesquisa_id into pid, pq from pesquisa_respostas r where r.id = new.resposta_id;
      if pid is not null then perform _marco_pessoa(pid, 'pesquisa', 'pesquisa_respostas', new.resposta_id,
        jsonb_build_object('pesquisa_id', pq, 'pergunta_id', new.pergunta_id, 'valor', coalesce(new.valor_texto, new.valor_num::text))); end if;
    elsif tg_table_name = 'aluno_historico' then
      if new.tipo in ('etapa', 'jornada') and new.etapa_kanban_id is not null then
        perform _marco_marcar(new.aluno_id, 'etapa', 'aluno_historico', new.id, jsonb_build_object('etapa_kanban_id', new.etapa_kanban_id, 'em', new.em)); end if;
    elsif tg_table_name = 'pessoa_lista' then
      if new.ativo and (tg_op = 'INSERT' or not old.ativo) then perform _marco_pessoa(new.pessoa_id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', new.lista_id)); end if;
    elsif tg_table_name = 'pessoa_toques' then
      if new.tipo = 'outro' and new.chave is not null then perform _marco_pessoa(new.pessoa_id, 'evento', 'pessoa_toques', new.id, jsonb_build_object('evento', new.chave, 'em', new.em)); end if;
    end if;
  exception when others then raise warning 'marco_trg (%): %', tg_table_name, sqlerrm;  -- nunca bloqueia a operação de origem
  end;
  return null;
end $$;
revoke execute on function public.marco_trg() from public, anon, authenticated;
drop trigger if exists marco_venda_t on vendas;
create trigger marco_venda_t after insert or update of status on vendas for each row execute function marco_trg();
drop trigger if exists marco_video_t on presencas_video;
create trigger marco_video_t after insert or update of assistiu_seg on presencas_video for each row execute function marco_trg();
drop trigger if exists marco_resposta_t on pesquisa_respostas;
create trigger marco_resposta_t after insert on pesquisa_respostas for each row execute function marco_trg();
drop trigger if exists marco_resposta_item_t on pesquisa_resposta_itens;
create trigger marco_resposta_item_t after insert on pesquisa_resposta_itens for each row execute function marco_trg();
drop trigger if exists marco_hist_t on aluno_historico;
create trigger marco_hist_t after insert on aluno_historico for each row execute function marco_trg();
drop trigger if exists marco_lista_t on pessoa_lista;
create trigger marco_lista_t after insert or update of ativo on pessoa_lista for each row execute function marco_trg();
drop trigger if exists marco_toque_t on pessoa_toques;
create trigger marco_toque_t after insert on pessoa_toques for each row execute function marco_trg();

-- Ao criar um marco automático, olha o que já aconteceu com quem já está na jornada (etapas, compras, vídeos, respostas, listas, eventos).
create or replace function public.marco_retroativo(p_marco uuid) returns int
language plpgsql security definer set search_path = public as $$
declare mk jornada_marcos; r record; n int := 0;
begin
  select * into mk from jornada_marcos where id = p_marco;
  if not found or mk.confirmacao = 'manual' then return 0; end if;
  perform _jornada_pode(mk.workspace_id);
  for r in select a.id, a.pessoa_id from alunos a where a.jornada_id = mk.jornada_id and a.saiu_em is null loop
    if mk.regra->>'tipo' = 'etapa' then
      if exists (select 1 from aluno_historico h where h.aluno_id = r.id and h.etapa_kanban_id::text = mk.regra->>'etapa_kanban_id') then
        n := n + _marco_marcar(r.id, 'etapa', 'aluno_historico', null, jsonb_build_object('etapa_kanban_id', mk.regra->>'etapa_kanban_id')); end if;
    elsif mk.regra->>'tipo' = 'compra' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'compra', 'vendas', v.id, jsonb_build_object('produto_id', v.produto_id, 'em', v.data_venda)))
        from vendas v join alunos a on a.id = r.id where v.pessoa_id = r.pessoa_id and v.status = 'aprovada' and v.data_venda >= a.entrou_em), 0);
    elsif mk.regra->>'tipo' = 'video' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'video', 'presencas_video', x.id, jsonb_build_object('fonte_id', x.fonte_id, 'segundos', x.assistiu_seg))) from presencas_video x where x.pessoa_id = r.pessoa_id), 0);
    elsif mk.regra->>'tipo' = 'pesquisa' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'pesquisa', 'pesquisa_respostas', x.id, jsonb_build_object('pesquisa_id', x.pesquisa_id, 'em', x.respondida_em))) from pesquisa_respostas x where x.pessoa_id = r.pessoa_id), 0);
      n := n + coalesce((select sum(_marco_marcar(r.id, 'pesquisa', 'pesquisa_respostas', x.id, jsonb_build_object('pesquisa_id', x.pesquisa_id, 'pergunta_id', i.pergunta_id, 'valor', coalesce(i.valor_texto, i.valor_num::text))))
        from pesquisa_respostas x join pesquisa_resposta_itens i on i.resposta_id = x.id where x.pessoa_id = r.pessoa_id), 0);
    elsif mk.regra->>'tipo' = 'lista' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'lista', 'pessoa_lista', null, jsonb_build_object('lista_id', x.lista_id))) from pessoa_lista x where x.pessoa_id = r.pessoa_id and x.ativo), 0);
    elsif mk.regra->>'tipo' = 'evento' then
      n := n + coalesce((select sum(_marco_marcar(r.id, 'evento', 'pessoa_toques', x.id, jsonb_build_object('evento', x.chave, 'em', x.em))) from pessoa_toques x where x.pessoa_id = r.pessoa_id and x.tipo = 'outro' and x.chave is not null), 0);
    end if;
  end loop;
  return n;
end $$;

-- Confirmar, recusar ou desfazer um marco de um aluno (manual ou aguardando confirmação).
create or replace function public.marco_confirmar(p_aluno uuid, p_marco uuid, p_acao text, p_obs text default null) returns text
language plpgsql security definer set search_path = public as $$
declare a alunos;
begin
  select * into a from alunos where id = p_aluno;
  if not found then raise exception 'Matrícula não encontrada'; end if;
  perform _jornada_pode(a.workspace_id);
  if p_acao not in ('confirmar', 'recusar', 'desfazer') then raise exception 'Ação inválida'; end if;
  if p_acao = 'desfazer' then delete from aluno_marcos where aluno_id = p_aluno and marco_id = p_marco; return 'desfeito'; end if;
  insert into aluno_marcos (workspace_id, aluno_id, marco_id, situacao, sinal, fonte, validado_por, validado_em, observacao)
  values (a.workspace_id, p_aluno, p_marco, case when p_acao = 'confirmar' then 'atingido' else 'recusado' end, 'validado', 'manual', auth.uid(), now(), nullif(trim(coalesce(p_obs, '')), ''))
  on conflict (aluno_id, marco_id) do update set situacao = excluded.situacao, sinal = 'validado', validado_por = excluded.validado_por, validado_em = now(),
    observacao = coalesce(excluded.observacao, aluno_marcos.observacao);
  return case when p_acao = 'confirmar' then 'atingido' else 'recusado' end;
end $$;
revoke execute on function public.marco_retroativo(uuid), public.marco_confirmar(uuid, uuid, text, text) from public, anon;
grant execute on function public.marco_retroativo(uuid), public.marco_confirmar(uuid, uuid, text, text) to authenticated;

-- ---------- nova versão / modelo levam os marcos ----------
create or replace function public._jornada_copiar_etapas(p_ws uuid, p_de uuid, p_geral boolean, p_para uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  insert into etapas_kanban (workspace_id, quadro, nome, ordem, descricao, mensagem_padrao, alertar_responsavel, jornada_id)
  select p_ws, 'alunos', e.nome, row_number() over (order by e.ordem, e.nome), e.descricao, e.mensagem_padrao, e.alertar_responsavel, p_para
  from etapas_kanban e
  where e.workspace_id = p_ws and e.quadro = 'alunos' and ((p_geral and e.jornada_id is null) or (not p_geral and p_de is not null and e.jornada_id = p_de));
  get diagnostics n = row_count;
  if not p_geral and p_de is not null then
    insert into jornada_marcos (workspace_id, jornada_id, etapa_kanban_id, nome, descricao, evidencia, prazo_dias, obrigatorio, ordem, confirmacao, regra)
    select p_ws, p_para, en.id, m.nome, m.descricao, m.evidencia, m.prazo_dias, m.obrigatorio, m.ordem, m.confirmacao,
      case when coalesce(m.regra->>'tipo', '') = 'etapa' then
        (select case when x.id is null then null else jsonb_set(m.regra, '{etapa_kanban_id}', to_jsonb(x.id::text)) end
           from etapas_kanban eo left join etapas_kanban x on x.jornada_id = p_para and x.nome = eo.nome where eo.id::text = m.regra->>'etapa_kanban_id')
      else m.regra end
    from jornada_marcos m
    left join etapas_kanban eo on eo.id = m.etapa_kanban_id
    left join etapas_kanban en on en.jornada_id = p_para and en.nome = eo.nome
    where m.jornada_id = p_de
      and not (coalesce(m.regra->>'tipo', '') = 'etapa' and not exists (select 1 from etapas_kanban eo2 join etapas_kanban x2 on x2.jornada_id = p_para and x2.nome = eo2.nome where eo2.id::text = m.regra->>'etapa_kanban_id'));
  end if;
  return n;
end $$;
revoke execute on function public._jornada_copiar_etapas(uuid, uuid, boolean, uuid) from public, anon, authenticated;

-- ---------- eventos de fora ----------
alter table chaves_api drop constraint if exists chaves_api_escopo_check;
alter table chaves_api add constraint chaves_api_escopo_check check (escopo in ('ideias', 'leads', 'vendas', 'eventos'));
alter table pessoa_toques drop constraint if exists pessoa_toques_origem_check;
alter table pessoa_toques add constraint pessoa_toques_origem_check check (origem in ('sistema', 'sendflow', 'manual', 'importacao', 'integracao'));
create or replace function public.chave_api_criar_escopo(p_ws uuid, p_nome text, p_escopo text) returns text
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if p_escopo not in ('ideias', 'leads', 'vendas', 'eventos') then raise exception 'Escopo inválido'; end if;
  if p_escopo = 'eventos' then
    if auth.uid() is null or not perm(p_ws, 'editar', array['revops', 'vendas', 'cad']) then raise exception 'Só quem edita RevOps, Vendas ou Cadastros deste workspace pode gerar chave de eventos'; end if;
  elsif auth.uid() is null or not perm(p_ws, 'editar', '{mkt}'::text[]) then raise exception 'Só quem edita o Marketing deste workspace pode gerar chave'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome para a chave (ex.: Página de captura)'; end if;
  k := 'gw_' || replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into chaves_api (workspace_id, nome, escopo, prefixo, hash) values (p_ws, trim(p_nome), p_escopo, left(k, 9), chave_api_hash(k));
  return k;
end $$;
revoke execute on function public.chave_api_criar_escopo(uuid, text, text) from public, anon;
grant execute on function public.chave_api_criar_escopo(uuid, text, text) to authenticated;

-- Recebe um evento de fora: {"email" ou "telefone", "evento": "trabalho_xpto", "em"?, "descricao"?}. Grava um toque na pessoa;
-- os marcos com regra {"tipo":"evento","evento":…} das matrículas dela são marcados pelo gatilho. Pessoa desconhecida não é criada.
create or replace function public.evento_por_chave(p_chave text, p_dados jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w uuid; d jsonb := coalesce(p_dados, '{}'::jsonb); e text; f text; ev text; em timestamptz; pid uuid; tid uuid; n int;
begin
  w := chave_api_ws_escopo(p_chave, 'eventos');
  ev := nullif(lower(regexp_replace(trim(coalesce(d->>'evento', '')), '\s+', '_', 'g')), '');
  if ev is null or char_length(ev) > 80 then raise exception 'Informe o nome do evento (até 80 caracteres)'; end if;
  e := norm_email(nullif(lower(trim(coalesce(d->>'email', ''))), '')); f := norm_fone(nullif(trim(coalesce(d->>'telefone', '')), ''));
  if e is null and f is null then raise exception 'O evento precisa do e-mail ou do telefone do aluno'; end if;
  em := coalesce(nullif(d->>'em', '')::timestamptz, now());
  if em > now() + interval '1 hour' or em < now() - interval '400 days' then em := now(); end if;
  if f is not null then select id into pid from pessoas where workspace_id = w and telefone_norm = f; end if;
  if pid is null and e is not null then select id into pid from pessoas where workspace_id = w and email_norm = e; end if;
  if pid is null then return jsonb_build_object('ok', false, 'erro', 'Pessoa não encontrada no Growths (confira o e-mail ou o telefone)'); end if;
  insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, chave, descricao, origem)
  values (w, pid, em, 'outro', 'plataforma', ev, left(coalesce(nullif(d->>'descricao', ''), 'Evento: ' || ev), 300), 'integracao') returning id into tid;
  select count(*) into n from aluno_marcos where ref_tabela = 'pessoa_toques' and ref_id = tid;
  return jsonb_build_object('ok', true, 'pessoa_id', pid, 'evento', ev, 'marcos', n);
end $$;
revoke execute on function public.evento_por_chave(text, jsonb) from public;
grant execute on function public.evento_por_chave(text, jsonb) to anon, authenticated;

-- ---------- auditoria ----------
do $$
declare t text;
begin
  foreach t in array array['alunos', 'jornadas', 'jornada_marcos', 'aluno_marcos'] loop
    execute format('drop trigger if exists auditoria_t on public.%I', t);
    execute format('create trigger auditoria_t after insert or update or delete on public.%I for each row execute function public.auditar()', t);
  end loop;
end $$;

-- Para desfazer: drop dos gatilhos marco_*_t e auditoria_t de alunos/jornadas/jornada_marcos/aluno_marcos; drop function evento_por_chave, marco_confirmar,
-- marco_retroativo, marco_trg, _marco_pessoa, _marco_marcar, aluno_marcos_valida, jornada_marcos_valida; _jornada_copiar_etapas da 20261118100000;
-- chave_api_criar_escopo e chaves_api_escopo_check da 20261018100000; pessoa_toques_origem_check sem 'integracao' (depois de apagar os toques de integração);
-- drop table aluno_marcos, jornada_marcos.
