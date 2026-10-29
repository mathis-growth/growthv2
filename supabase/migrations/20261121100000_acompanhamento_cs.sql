-- v0.163 — Acompanhamento do aluno (Customer Growth, etapas B7, B8 e B9).
-- B7. Alertas de CS no mesmo agendador de hora em hora e na mesma tabela de alertas (tipo novo 'cs'):
--     parado (há N dias na mesma etapa), marco obrigatório atrasado, check-in sem resposta, nota baixa (NPS), matrícula sem CS.
--     Cada alerta é gravado uma vez (chave única) e se resolve sozinho quando a situação muda. O aviso vai para o CS da matrícula
--     (sino, e-mail, WhatsApp, como cada pessoa escolheu) só quando o cliente tem os alertas ligados (alertas_config.ligado).
--     Sensibilidade em alertas_config.regras->'cs': {"parado_dias":14,"checkin_dias":7,"nps_max":6,"desligadas":["sem_cs",...]}.
-- B8. cs_intervencoes (tabela própria): ação de CS ligada à matrícula, ao alerta, à etapa, ao marco e à resposta de check-in,
--     com responsável, prazo, situação, resultado e efeito. Concluir resolve o alerta ligado. O responsável é avisado.
-- B9. oportunidades: aluno_id (matrícula de origem), origem (manual, alerta, rfm, ascensao, marco, intervencao) e tipos
--     'expansao' e 'retencao'.
-- Rode depois de 20261120100000_checkin_recorrente.sql. Idempotente.

alter table alertas drop constraint if exists alertas_tipo_check;
alter table alertas add constraint alertas_tipo_check check (tipo in ('brusco', 'repetido', 'operacional', 'cs'));
create index if not exists alertas_cs_aberto on alertas (workspace_id) where tipo = 'cs' and resolvido_em is null;

create or replace function public.cg_verificar_alertas(p_ws uuid, p_ref timestamptz default now(), p_avisar boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare cfg jsonb; des text[]; parado int; ckd int; npsm numeric; liga boolean; cx record; novo int := 0; resolv int := 0; dia date := (p_ref at time zone 'America/Sao_Paulo')::date;
  ch text; tit text; msg text; sev text;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  select coalesce(regras->'cs', '{}'::jsonb), ligado into cfg, liga from alertas_config where workspace_id = p_ws;
  cfg := coalesce(cfg, '{}'::jsonb); liga := coalesce(liga, false);
  des := coalesce(array(select jsonb_array_elements_text(cfg->'desligadas')), '{}');
  parado := greatest(coalesce((cfg->>'parado_dias')::int, 14), 1); ckd := greatest(coalesce((cfg->>'checkin_dias')::int, 7), 1); npsm := coalesce((cfg->>'nps_max')::numeric, 6);

  -- casos de agora (um por linha), já com a chave do alerta
  create temp table if not exists _cg_casos (chave text primary key, regra text, severidade text, titulo text, mensagem text, dados jsonb, cs uuid, pessoa uuid) on commit drop;
  delete from _cg_casos;
  if not 'parado' = any (des) then
    insert into _cg_casos
    select 'cs:parado:' || a.id || ':' || a.etapa_kanban_id, 'parado', 'media',
      p.nome || ' parado em «' || e.nome || '» há ' || floor(extract(epoch from (p_ref - u.em)) / 86400)::int || ' dias',
      p.nome || ' (' || pr.nome || ') está na etapa «' || e.nome || '» desde ' || to_char(u.em at time zone 'America/Sao_Paulo', 'DD/MM') || '.' || coalesce(' O que fazer: ' || nullif(e.descricao, ''), ''),
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'etapa_id', a.etapa_kanban_id, 'dias', floor(extract(epoch from (p_ref - u.em)) / 86400)::int),
      a.responsavel_cs_id, a.pessoa_id
    from alunos a join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id join etapas_kanban e on e.id = a.etapa_kanban_id
    cross join lateral (select coalesce(max(h.em), a.entrou_em) as em from aluno_historico h where h.aluno_id = a.id and h.tipo in ('etapa', 'jornada') and h.etapa_kanban_id = a.etapa_kanban_id) u
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and u.em < p_ref - make_interval(days => parado)
      and exists (select 1 from etapas_kanban x where x.workspace_id = p_ws and x.quadro = 'alunos' and x.jornada_id is not distinct from e.jornada_id and x.ordem > e.ordem)  -- na última etapa não é "parado"
    on conflict do nothing;
  end if;
  if not 'marco_atrasado' = any (des) then
    insert into _cg_casos
    select 'cs:marco:' || a.id || ':' || m.id, 'marco_atrasado', 'alta', 'Marco atrasado: ' || m.nome || ' (' || p.nome || ')',
      p.nome || ' (' || pr.nome || ') não atingiu «' || m.nome || '», com prazo de ' || m.prazo_dias || ' dias desde a matrícula (' || to_char(a.entrou_em at time zone 'America/Sao_Paulo', 'DD/MM') || ').',
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'marco_id', m.id, 'etapa_id', m.etapa_kanban_id), a.responsavel_cs_id, a.pessoa_id
    from alunos a join jornada_marcos m on m.jornada_id = a.jornada_id join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and m.obrigatorio and m.prazo_dias is not null
      and a.entrou_em + make_interval(days => m.prazo_dias) < p_ref
      and not exists (select 1 from aluno_marcos x where x.aluno_id = a.id and x.marco_id = m.id and x.situacao = 'atingido')
    on conflict do nothing;
  end if;
  if not 'checkin_sem_resposta' = any (des) then
    insert into _cg_casos
    select 'cs:checkin:' || v.id, 'checkin_sem_resposta', 'media', p.nome || ' não respondeu o check-in «' || s.nome || '»',
      'O check-in foi gerado em ' || to_char(v.gerado_em at time zone 'America/Sao_Paulo', 'DD/MM') || ' e ainda não teve resposta.' || case when v.status = 'pendente' then ' Ele ainda está na fila: confira se foi enviado.' else '' end,
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id, 'envio_id', v.id, 'pesquisa_id', s.id), a.responsavel_cs_id, a.pessoa_id
    from pesquisa_envios v join alunos a on a.id = v.aluno_id join pesquisas s on s.id = v.pesquisa_id join pessoas p on p.id = a.pessoa_id
    where v.workspace_id = p_ws and v.status in ('pendente', 'enviado') and v.gerado_em < p_ref - make_interval(days => ckd) and a.status = 'ativo' and a.saiu_em is null
    on conflict do nothing;
  end if;
  if not 'nps_baixo' = any (des) then
    insert into _cg_casos
    select 'cs:nps:' || r.id, 'nps_baixo', 'alta', p.nome || ' deu nota ' || trim(to_char(i.valor_num, 'FM990')) || ' em «' || s.nome || '»',
      p.nome || ' respondeu ' || trim(to_char(i.valor_num, 'FM990')) || ' de 0 a 10 em ' || to_char(r.respondida_em at time zone 'America/Sao_Paulo', 'DD/MM') || '. Vale conversar e entender o que está travando.',
      jsonb_build_object('aluno_id', al.id, 'pessoa_id', r.pessoa_id, 'produto_id', al.produto_id, 'resposta_id', r.id, 'pesquisa_id', s.id, 'nota', i.valor_num), al.responsavel_cs_id, r.pessoa_id
    from pesquisa_respostas r join pesquisa_resposta_itens i on i.resposta_id = r.id join pesquisa_perguntas q on q.id = i.pergunta_id and q.papel = 'nps'
    join pesquisas s on s.id = r.pesquisa_id join pessoas p on p.id = r.pessoa_id
    left join pesquisa_envios v on v.id = r.envio_id
    cross join lateral (select a.* from alunos a where a.pessoa_id = r.pessoa_id and a.status = 'ativo' and a.saiu_em is null order by (a.id = v.aluno_id) desc nulls last, a.entrou_em desc limit 1) al
    where r.workspace_id = p_ws and i.valor_num <= npsm and r.respondida_em > p_ref - interval '30 days'
    on conflict do nothing;
  end if;
  if not 'sem_cs' = any (des) then
    insert into _cg_casos
    select 'cs:sem_cs:' || a.id, 'sem_cs', 'media', p.nome || ' está sem CS responsável (' || pr.nome || ')',
      'A matrícula de ' || p.nome || ' em ' || pr.nome || ' não tem CS responsável: ninguém recebe os avisos dela.',
      jsonb_build_object('aluno_id', a.id, 'pessoa_id', a.pessoa_id, 'produto_id', a.produto_id), null, a.pessoa_id
    from alunos a join pessoas p on p.id = a.pessoa_id join produtos pr on pr.id = a.produto_id
    where a.workspace_id = p_ws and a.status = 'ativo' and a.saiu_em is null and a.responsavel_cs_id is null
    on conflict do nothing;
  end if;

  -- grava os novos e avisa o CS da matrícula
  for cx in select c.* from _cg_casos c where not exists (select 1 from alertas x where x.workspace_id = p_ws and x.chave = c.chave) loop
    insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dados, dia)
    values (p_ws, cx.chave, 'cs', cx.regra, cx.severidade, cx.titulo, cx.mensagem, cx.dados, dia) on conflict (workspace_id, chave) do nothing;
    if found then
      novo := novo + 1;
      if p_avisar and liga and cx.cs is not null and cx.regra <> 'sem_cs' then perform equipe_avisa(p_ws, cx.cs, cx.pessoa, cx.titulo, cx.mensagem); end if;
    end if;
  end loop;
  -- o que deixou de valer se resolve sozinho
  update alertas x set resolvido_em = p_ref
  where x.workspace_id = p_ws and x.tipo = 'cs' and x.resolvido_em is null and not (x.regra = any (des))
    and not exists (select 1 from _cg_casos c where c.chave = x.chave)
    and not (x.regra = 'nps_baixo');  -- nota baixa só se resolve com uma intervenção concluída ou à mão
  get diagnostics resolv = row_count;
  return jsonb_build_object('novos', novo, 'resolvidos', resolv, 'abertos', (select count(*) from alertas where workspace_id = p_ws and tipo = 'cs' and resolvido_em is null));
end $$;
revoke execute on function public.cg_verificar_alertas(uuid, timestamptz, boolean) from public, anon;
grant execute on function public.cg_verificar_alertas(uuid, timestamptz, boolean) to authenticated;

-- O que o agendador roda de hora em hora para o acompanhamento: check-ins do dia e alertas de CS de quem tem alunos ativos.
create or replace function public.cg_rodar_agendado(p_ref timestamptz default now()) returns jsonb
language plpgsql security definer set search_path = public as $$
declare w record; n int := 0; ck int := 0;
begin
  begin ck := pesquisa_checkins_gerar(p_ref, null); exception when others then raise warning 'cg_rodar_agendado (check-ins): %', sqlerrm; end;
  for w in select distinct workspace_id from alunos where status = 'ativo' and saiu_em is null loop
    begin perform cg_verificar_alertas(w.workspace_id, p_ref, true); n := n + 1;
    exception when others then raise warning 'cg_rodar_agendado %: %', w.workspace_id, sqlerrm; end;
  end loop;
  return jsonb_build_object('clientes', n, 'checkins', ck);
end $$;
revoke all on function public.cg_rodar_agendado(timestamptz) from public, anon, authenticated;

do $m$
declare d text; n text;
begin
  select pg_get_functiondef('public.growths_rodar_agendado(timestamptz)'::regprocedure) into d;
  d := replace(d, E'\r\n', E'\n');
  if position('cg_rodar_agendado' in d) = 0 then
    n := replace(d, '  -- pede o envio de e-mails e WhatsApps que estão na fila',
      '  -- v0.163: acompanhamento dos alunos (check-ins do dia e alertas de CS), antes de pedir o envio da fila
  begin perform cg_rodar_agendado(p_ref); exception when others then raise warning ''growths_rodar_agendado (acompanhamento): %'', sqlerrm; end;
  -- pede o envio de e-mails e WhatsApps que estão na fila');
    if n = d then raise exception 'growths_rodar_agendado: ponto de inserção não encontrado'; end if;
    execute n;
  end if;
end $m$;
revoke all on function public.growths_rodar_agendado(timestamptz) from public, anon, authenticated;

-- ---------- B8: intervenções de CS ----------
create table if not exists cs_intervencoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  aluno_id uuid not null references alunos(id) on delete cascade,
  pessoa_id uuid references pessoas(id) on delete cascade,
  alerta_id uuid references alertas(id) on delete set null,
  etapa_kanban_id uuid references etapas_kanban(id) on delete set null,
  marco_id uuid references jornada_marcos(id) on delete set null,
  pesquisa_resposta_id uuid references pesquisa_respostas(id) on delete set null,
  tipo text not null default 'mensagem' check (tipo in ('ligacao', 'mensagem', 'reuniao', 'conteudo', 'oferta', 'outro')),
  descricao text not null check (char_length(descricao) between 1 and 2000),
  responsavel_id uuid references equipe(id) on delete set null,
  prazo date,
  status text not null default 'aberta' check (status in ('aberta', 'feita', 'cancelada')),
  resultado text,
  efeito text check (efeito is null or efeito in ('resolveu', 'em_andamento', 'nao_resolveu')),
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  concluida_em timestamptz
);
create index if not exists cs_intervencoes_ws on cs_intervencoes (workspace_id, status);
create index if not exists cs_intervencoes_aluno on cs_intervencoes (aluno_id);
create index if not exists cs_intervencoes_resp on cs_intervencoes (workspace_id, responsavel_id, status);

create or replace function public.cs_intervencoes_t() returns trigger language plpgsql security definer set search_path = public as $$
declare a alunos; nm text; pr text;
begin
  select * into a from alunos where id = new.aluno_id;
  if not found or a.workspace_id <> new.workspace_id then raise exception 'A matrícula precisa ser deste cliente'; end if;
  new.pessoa_id := a.pessoa_id;
  if tg_op = 'INSERT' and new.responsavel_id is null then new.responsavel_id := a.responsavel_cs_id; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then raise exception 'O responsável precisa ser da equipe deste cliente'; end if;
  if new.alerta_id is not null and not exists (select 1 from alertas where id = new.alerta_id and workspace_id = new.workspace_id) then raise exception 'O alerta precisa ser deste cliente'; end if;
  if new.marco_id is not null and not exists (select 1 from jornada_marcos where id = new.marco_id and jornada_id = a.jornada_id) then raise exception 'O marco precisa ser da jornada desta matrícula'; end if;
  if new.status in ('feita', 'cancelada') and (tg_op = 'INSERT' or old.status = 'aberta') then new.concluida_em := coalesce(new.concluida_em, now()); end if;
  if new.status = 'aberta' then new.concluida_em := null; end if;
  return new;
end $$;
create or replace function public.cs_intervencoes_depois() returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; pr text;
begin
  begin
    select p.nome, d.nome into nm, pr from alunos a join pessoas p on p.id = a.pessoa_id join produtos d on d.id = a.produto_id where a.id = new.aluno_id;
    if new.responsavel_id is not null and (tg_op = 'INSERT' or new.responsavel_id is distinct from old.responsavel_id) and new.status = 'aberta' then
      perform equipe_avisa(new.workspace_id, new.responsavel_id, new.pessoa_id, 'Intervenção de CS: ' || coalesce(nm, 'aluno') || ' (' || coalesce(pr, '') || ')',
        left(new.descricao, 300) || coalesce(' · prazo ' || to_char(new.prazo, 'DD/MM'), ''));
    end if;
    if new.status = 'feita' and (tg_op = 'INSERT' or old.status <> 'feita') and new.alerta_id is not null and coalesce(new.efeito, '') <> 'nao_resolveu' then
      update alertas set resolvido_em = coalesce(resolvido_em, now()) where id = new.alerta_id;
    end if;
  exception when others then raise warning 'cs_intervencoes_depois: %', sqlerrm;
  end;
  return null;
end $$;
revoke execute on function public.cs_intervencoes_t(), public.cs_intervencoes_depois() from public, anon, authenticated;
drop trigger if exists cs_intervencoes_t on cs_intervencoes;
create trigger cs_intervencoes_t before insert or update on cs_intervencoes for each row execute function cs_intervencoes_t();
drop trigger if exists cs_intervencoes_depois_t on cs_intervencoes;
create trigger cs_intervencoes_depois_t after insert or update on cs_intervencoes for each row execute function cs_intervencoes_depois();

alter table cs_intervencoes enable row level security;
drop policy if exists cs_intervencoes_acesso on cs_intervencoes;
create policy cs_intervencoes_acesso on cs_intervencoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on cs_intervencoes; drop policy if exists perm_inserir on cs_intervencoes; drop policy if exists perm_alterar on cs_intervencoes; drop policy if exists perm_excluir on cs_intervencoes;
create policy perm_ler on cs_intervencoes as restrictive for select using (perm(workspace_id, 'ler', array['revops','vendas','adm','prj','fin','gro']));
create policy perm_inserir on cs_intervencoes as restrictive for insert with check (perm(workspace_id, 'editar', array['revops','vendas']));
create policy perm_alterar on cs_intervencoes as restrictive for update using (perm(workspace_id, 'editar', array['revops','vendas'])) with check (perm(workspace_id, 'editar', array['revops','vendas']));
create policy perm_excluir on cs_intervencoes as restrictive for delete using (perm(workspace_id, 'editar', array['revops','vendas']));
grant select, insert, update, delete on cs_intervencoes to authenticated;
drop trigger if exists auditoria_t on cs_intervencoes;
create trigger auditoria_t after insert or update or delete on cs_intervencoes for each row execute function auditar();

-- ---------- B9: oportunidades de retenção e expansão ligadas à matrícula ----------
alter table oportunidades add column if not exists aluno_id uuid references alunos(id) on delete set null;
alter table oportunidades add column if not exists origem text not null default 'manual';
alter table oportunidades drop constraint if exists oportunidades_origem_check;
alter table oportunidades add constraint oportunidades_origem_check check (origem in ('manual', 'alerta', 'rfm', 'ascensao', 'marco', 'intervencao'));
alter table oportunidades drop constraint if exists oportunidades_tipo_check;
alter table oportunidades add constraint oportunidades_tipo_check check (tipo in ('nova_venda', 'renovacao', 'ajuste', 'expansao', 'retencao'));
create index if not exists oportunidades_aluno on oportunidades (aluno_id);
create or replace function public.oportunidades_aluno_valida() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.aluno_id is not null and not exists (select 1 from alunos where id = new.aluno_id and pessoa_id = new.pessoa_id and workspace_id = new.workspace_id) then
    raise exception 'A matrícula precisa ser desta pessoa'; end if;
  return new;
end $$;
revoke execute on function public.oportunidades_aluno_valida() from public, anon, authenticated;
drop trigger if exists oportunidades_aluno_valida_t on oportunidades;
create trigger oportunidades_aluno_valida_t before insert or update of aluno_id, pessoa_id on oportunidades for each row execute function oportunidades_aluno_valida();

-- Para desfazer: voltar growths_rodar_agendado de 20261028100000_assistente_alertas.sql; drop function cg_rodar_agendado, cg_verificar_alertas;
-- delete from alertas where tipo = 'cs'; recriar alertas_tipo_check sem 'cs'; drop table cs_intervencoes (e funções cs_intervencoes_*);
-- update oportunidades set tipo = 'nova_venda' where tipo in ('expansao', 'retencao'); recriar oportunidades_tipo_check;
-- drop trigger oportunidades_aluno_valida_t; drop function oportunidades_aluno_valida; drop columns oportunidades.origem, oportunidades.aluno_id.
