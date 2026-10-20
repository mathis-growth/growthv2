-- Projetos, equipe, modelos de projeto, avisos e links de tracking da campanha.
-- Regras principais:
--  * Toda campanha nova gera um projeto (com o modelo padrão de campanha, se houver).
--  * Atividade nasce bloqueada e é liberada sozinha quando tudo de que depende está concluído.
--  * Ao liberar, o responsável é avisado (app agora; e-mail e WhatsApp ficam na fila de envio).
--  * Link de tracking gera o criativo (anúncio) correspondente, casando por utm_content.

-- ---------------------------------------------------------------------
-- 1. Equipe
-- ---------------------------------------------------------------------
create table equipe (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  email text,
  telefone text,
  funcao text,
  avisar_app boolean not null default true,
  avisar_email boolean not null default true,
  avisar_whatsapp boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index equipe_email_uq on equipe (workspace_id, lower(email)) where email is not null;

-- ---------------------------------------------------------------------
-- 2. Modelos de projeto
-- ---------------------------------------------------------------------
create table projeto_modelos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  descricao text,
  padrao_campanha boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index projeto_modelos_padrao_uq on projeto_modelos (workspace_id) where padrao_campanha;

create table projeto_modelo_atividades (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  modelo_id uuid not null references projeto_modelos(id) on delete cascade,
  pai_id uuid references projeto_modelo_atividades(id) on delete cascade,
  titulo text not null,
  descricao text,
  funcao text,
  responsavel_id uuid references equipe(id) on delete set null,
  ordem int not null default 0,
  depende_de uuid[] not null default '{}',
  prazo_dias int not null default 0 check (prazo_dias >= 0)
);
create index projeto_modelo_atividades_ix on projeto_modelo_atividades (modelo_id, ordem);

-- ---------------------------------------------------------------------
-- 3. Projetos e atividades
-- ---------------------------------------------------------------------
create table projetos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  descricao text,
  status text not null default 'planejado' check (status in ('planejado', 'em_andamento', 'concluido', 'pausado', 'cancelado')),
  campanha_id uuid unique references campanhas(id) on delete set null,
  modelo_id uuid references projeto_modelos(id) on delete set null,
  responsavel_id uuid references equipe(id) on delete set null,
  data_inicio date,
  data_fim_prevista date,
  criado_em timestamptz not null default now()
);
create index projetos_ws on projetos (workspace_id, status);

create table projeto_atividades (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  projeto_id uuid not null references projetos(id) on delete cascade,
  pai_id uuid references projeto_atividades(id) on delete cascade,
  titulo text not null,
  descricao text,
  funcao text,
  responsavel_id uuid references equipe(id) on delete set null,
  status text not null default 'bloqueada' check (status in ('bloqueada', 'liberada', 'em_andamento', 'concluida', 'cancelada')),
  ordem int not null default 0,
  depende_de uuid[] not null default '{}',
  prazo date,
  liberada_em timestamptz,
  iniciada_em timestamptz,
  concluida_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index projeto_atividades_ix on projeto_atividades (projeto_id, ordem);
create index projeto_atividades_resp on projeto_atividades (workspace_id, responsavel_id, status);

-- ---------------------------------------------------------------------
-- 4. Avisos (um registro por pessoa e canal)
-- ---------------------------------------------------------------------
create table notificacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  destinatario_id uuid not null references equipe(id) on delete cascade,
  projeto_id uuid references projetos(id) on delete cascade,
  atividade_id uuid references projeto_atividades(id) on delete cascade,
  tipo text not null default 'atividade_liberada',
  canal text not null check (canal in ('app', 'email', 'whatsapp')),
  titulo text not null,
  mensagem text not null,
  status text not null default 'pendente' check (status in ('pendente', 'enviada', 'falhou')),
  erro text,
  criada_em timestamptz not null default now(),
  enviada_em timestamptz,
  lida_em timestamptz
);
create index notificacoes_ix on notificacoes (workspace_id, destinatario_id, criada_em desc);

-- ---------------------------------------------------------------------
-- 5. Links de tracking da campanha
-- ---------------------------------------------------------------------
create table campanha_links (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_canal_id uuid not null references campanha_canais(id) on delete cascade,
  nome text not null,
  url_destino text not null check (url_destino ~* '^https?://'),
  utm_source text not null,
  utm_medium text not null,
  utm_content text not null,
  utm_term text,
  angulo text,
  anuncio_id uuid references anuncios(id) on delete set null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (campanha_canal_id, utm_content)
);

create function campanha_link_valida() returns trigger
language plpgsql security definer set search_path = public as $$
declare a uuid;
begin
  if not exists (select 1 from campanha_canais where id = new.campanha_canal_id and workspace_id = new.workspace_id) then
    raise exception 'O canal da campanha precisa pertencer ao mesmo workspace'; end if;
  -- o link é a ponte para o criativo: acha ou cria o anúncio com o mesmo utm_content
  select id into a from anuncios where campanha_canal_id = new.campanha_canal_id and utm_content = new.utm_content;
  if a is null then
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, angulo)
    values (new.workspace_id, new.campanha_canal_id, new.nome, new.utm_content, new.angulo) returning id into a;
  end if;
  new.anuncio_id := a;
  return new;
end $$;
create trigger campanha_link_valida_t before insert or update on campanha_links for each row execute function campanha_link_valida();

-- ---------------------------------------------------------------------
-- 6. Funções internas
-- ---------------------------------------------------------------------
create function equipe_resolve(p_ws uuid, p_funcao text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from equipe
  where workspace_id = p_ws and ativo and p_funcao is not null and lower(trim(funcao)) = lower(trim(p_funcao))
  order by criado_em limit 1;
$$;

create function atividade_avisa(p_atividade uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a projeto_atividades; p projetos; e equipe; t text; msg text;
begin
  select * into a from projeto_atividades where id = p_atividade;
  if not found or a.responsavel_id is null then return; end if;
  select * into e from equipe where id = a.responsavel_id;
  if not found or not e.ativo then return; end if;
  select * into p from projetos where id = a.projeto_id;
  t := 'Atividade liberada: ' || a.titulo;
  msg := 'A atividade «' || a.titulo || '» do projeto «' || p.nome || '» foi liberada para você.'
         || case when a.prazo is not null then ' Prazo: ' || to_char(a.prazo, 'DD/MM/YYYY') || '.' else '' end;
  if e.avisar_app then
    insert into notificacoes (workspace_id, destinatario_id, projeto_id, atividade_id, canal, titulo, mensagem, status, enviada_em)
    values (a.workspace_id, e.id, a.projeto_id, a.id, 'app', t, msg, 'enviada', now());
  end if;
  if e.avisar_email and e.email is not null then
    insert into notificacoes (workspace_id, destinatario_id, projeto_id, atividade_id, canal, titulo, mensagem)
    values (a.workspace_id, e.id, a.projeto_id, a.id, 'email', t, msg);
  end if;
  if e.avisar_whatsapp and e.telefone is not null then
    insert into notificacoes (workspace_id, destinatario_id, projeto_id, atividade_id, canal, titulo, mensagem)
    values (a.workspace_id, e.id, a.projeto_id, a.id, 'whatsapp', t, msg);
  end if;
end $$;

-- Libera o que ficou livre, fecha atividades principais cujas subatividades terminaram
-- e atualiza o status do projeto. Repete até estabilizar.
create function projeto_recalcula(p_projeto uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r record; mudou boolean; n int := 0;
begin
  perform set_config('growths.recalc', '1', true);
  loop
    mudou := false; n := n + 1;
    exit when n > 25;
    for r in
      select a.id from projeto_atividades a
      where a.projeto_id = p_projeto and a.status = 'bloqueada'
        and (a.pai_id is null or exists (select 1 from projeto_atividades pa where pa.id = a.pai_id and pa.status in ('liberada', 'em_andamento')))
        and not exists (select 1 from unnest(a.depende_de) d(id) join projeto_atividades x on x.id = d.id where x.status not in ('concluida', 'cancelada'))
    loop
      update projeto_atividades set status = 'liberada', liberada_em = now() where id = r.id;
      mudou := true;
      if not exists (select 1 from projeto_atividades c where c.pai_id = r.id) then perform atividade_avisa(r.id); end if;
    end loop;
    for r in
      select g.id from projeto_atividades g
      where g.projeto_id = p_projeto and g.status in ('liberada', 'em_andamento')
        and exists (select 1 from projeto_atividades c where c.pai_id = g.id)
        and not exists (select 1 from projeto_atividades c where c.pai_id = g.id and c.status not in ('concluida', 'cancelada'))
    loop
      update projeto_atividades set status = 'concluida', concluida_em = now() where id = r.id;
      mudou := true;
    end loop;
    exit when not mudou;
  end loop;
  update projetos pr set status = case
      when not exists (select 1 from projeto_atividades where projeto_id = pr.id and status <> 'cancelada') then pr.status
      when not exists (select 1 from projeto_atividades where projeto_id = pr.id and status not in ('concluida', 'cancelada')) then 'concluido'
      when exists (select 1 from projeto_atividades where projeto_id = pr.id and status in ('em_andamento', 'concluida')) then 'em_andamento'
      else pr.status end
  where pr.id = p_projeto and pr.status in ('planejado', 'em_andamento', 'concluido');
  perform set_config('growths.recalc', '', true);
end $$;

create function projeto_aplica_modelo(p_projeto uuid, p_modelo uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p projetos;
begin
  select * into p from projetos where id = p_projeto;
  if not found then raise exception 'Projeto não encontrado'; end if;
  perform set_config('growths.recalc', '1', true);
  with m as (
    select a.*, gen_random_uuid() as novo from projeto_modelo_atividades a
    where a.modelo_id = p_modelo and a.workspace_id = p.workspace_id
  )
  insert into projeto_atividades (id, workspace_id, projeto_id, pai_id, titulo, descricao, funcao, responsavel_id, ordem, depende_de, prazo)
  select m.novo, m.workspace_id, p_projeto,
         (select x.novo from m x where x.id = m.pai_id),
         m.titulo, m.descricao, m.funcao,
         coalesce(m.responsavel_id, equipe_resolve(m.workspace_id, m.funcao)),
         m.ordem,
         coalesce((select array_agg(x.novo) from m x where x.id = any(m.depende_de)), '{}'),
         case when p.data_inicio is not null then p.data_inicio + m.prazo_dias end
  from m;
  perform projeto_recalcula(p_projeto);
end $$;

-- ---------------------------------------------------------------------
-- 7. Gatilhos
-- ---------------------------------------------------------------------
create function atividade_valida() returns trigger
language plpgsql security definer set search_path = public as $$
declare livre boolean := coalesce(current_setting('growths.recalc', true), '') = '1';
begin
  if new.id = any(new.depende_de) then raise exception 'Uma atividade não pode depender dela mesma'; end if;
  if not livre then
    if not exists (select 1 from projetos where id = new.projeto_id and workspace_id = new.workspace_id) then
      raise exception 'O projeto precisa pertencer ao mesmo workspace'; end if;
    if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
      raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
    if new.pai_id is not null then
      if new.pai_id = new.id then raise exception 'Uma atividade não pode ser subatividade dela mesma'; end if;
      if not exists (select 1 from projeto_atividades where id = new.pai_id and projeto_id = new.projeto_id and pai_id is null) then
        raise exception 'A atividade principal precisa ser do mesmo projeto e não pode ser uma subatividade'; end if;
      if tg_op = 'UPDATE' and exists (select 1 from projeto_atividades where pai_id = new.id) then
        raise exception 'Esta atividade tem subatividades e não pode virar subatividade'; end if;
    end if;
    if tg_op = 'UPDATE' and cardinality(new.depende_de) > 0 and new.depende_de is distinct from old.depende_de then
      if exists (
        with recursive cadeia(id) as (
          select unnest(new.depende_de)
          union
          select unnest(a.depende_de) from projeto_atividades a join cadeia c on a.id = c.id
        ) select 1 from cadeia where id = new.id) then
        raise exception 'Dependência circular: uma das atividades escolhidas já depende desta'; end if;
    end if;
  end if;
  if tg_op = 'INSERT' then
    new.status := 'bloqueada';
  else
    if new.status = 'liberada' and new.depende_de is distinct from old.depende_de and exists (
      select 1 from unnest(new.depende_de) d(id) join projeto_atividades x on x.id = d.id where x.status not in ('concluida', 'cancelada')) then
      new.status := 'bloqueada';
    end if;
    if new.status is distinct from old.status then
      if old.status = 'bloqueada' and new.status in ('em_andamento', 'concluida') then
        raise exception 'Esta atividade está bloqueada: conclua antes as atividades das quais ela depende'; end if;
      if new.status = 'concluida' and exists (select 1 from projeto_atividades where pai_id = new.id and status not in ('concluida', 'cancelada')) then
        raise exception 'Conclua antes as subatividades'; end if;
      if new.status = 'liberada' then new.liberada_em := coalesce(new.liberada_em, now()); end if;
      if new.status = 'em_andamento' then new.iniciada_em := coalesce(old.iniciada_em, now()); end if;
      if new.status = 'concluida' then new.concluida_em := now(); new.iniciada_em := coalesce(old.iniciada_em, now());
      elsif old.status = 'concluida' then new.concluida_em := null; end if;
    end if;
  end if;
  new.atualizado_em := now();
  return new;
end $$;
create trigger atividade_valida_t before insert or update on projeto_atividades for each row execute function atividade_valida();

create function atividade_pos() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('growths.recalc', true), '') = '1' then return null; end if;
  if tg_op = 'DELETE' then
    perform projeto_recalcula(old.projeto_id);
    return null;
  end if;
  if tg_op = 'UPDATE' and new.responsavel_id is distinct from old.responsavel_id and new.responsavel_id is not null
     and new.status = 'liberada' and not exists (select 1 from projeto_atividades where pai_id = new.id) then
    perform atividade_avisa(new.id);
  end if;
  perform projeto_recalcula(new.projeto_id);
  return null;
end $$;
create trigger atividade_pos_t after insert or update or delete on projeto_atividades for each row execute function atividade_pos();

create function projeto_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.modelo_id is not null and not exists (select 1 from projeto_modelos where id = new.modelo_id and workspace_id = new.workspace_id) then
    raise exception 'O modelo precisa pertencer ao mesmo workspace'; end if;
  if new.campanha_id is not null and not exists (select 1 from campanhas where id = new.campanha_id and workspace_id = new.workspace_id) then
    raise exception 'A campanha precisa pertencer ao mesmo workspace'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  return new;
end $$;
create trigger projeto_valida_t before insert or update on projetos for each row execute function projeto_valida();

create function projeto_gera_atividades() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.modelo_id is not null then perform projeto_aplica_modelo(new.id, new.modelo_id); end if;
  return null;
end $$;
create trigger projeto_gera_t after insert on projetos for each row execute function projeto_gera_atividades();

create function modelo_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from projeto_modelos where id = new.modelo_id and workspace_id = new.workspace_id) then
    raise exception 'O modelo precisa pertencer ao mesmo workspace'; end if;
  if new.pai_id is not null and not exists (select 1 from projeto_modelo_atividades where id = new.pai_id and modelo_id = new.modelo_id and pai_id is null and id <> new.id) then
    raise exception 'A atividade principal precisa ser do mesmo modelo e não pode ser uma subatividade'; end if;
  if new.id = any(new.depende_de) then raise exception 'Uma atividade não pode depender dela mesma'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  return new;
end $$;
create trigger modelo_valida_t before insert or update on projeto_modelo_atividades for each row execute function modelo_valida();

create function campanha_cria_projeto() returns trigger
language plpgsql security definer set search_path = public as $$
declare m uuid;
begin
  select id into m from projeto_modelos where workspace_id = new.workspace_id and padrao_campanha and ativo limit 1;
  insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
  values (new.workspace_id, 'Campanha: ' || new.nome, 'Projeto criado automaticamente com a campanha.', new.id, m,
          coalesce(new.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), new.data_fim);
  return null;
end $$;
create trigger campanha_cria_projeto_t after insert on campanhas for each row execute function campanha_cria_projeto();

revoke execute on function campanha_link_valida(), equipe_resolve(uuid, text), atividade_avisa(uuid), projeto_recalcula(uuid), projeto_aplica_modelo(uuid, uuid),
  atividade_valida(), atividade_pos(), projeto_valida(), projeto_gera_atividades(), modelo_valida(), campanha_cria_projeto() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Funções chamadas pela tela
-- ---------------------------------------------------------------------
-- Cria projeto para as campanhas que ainda não têm um (campanhas anteriores a esta migração).
create function projetos_das_campanhas(p_ws uuid) returns int
language plpgsql security definer set search_path = public as $$
declare c record; m uuid; n int := 0;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  select id into m from projeto_modelos where workspace_id = p_ws and padrao_campanha and ativo limit 1;
  for c in select * from campanhas where workspace_id = p_ws and not exists (select 1 from projetos where campanha_id = campanhas.id) loop
    insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
    values (p_ws, 'Campanha: ' || c.nome, 'Projeto criado a partir de uma campanha existente.', c.id, m,
            coalesce(c.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), c.data_fim);
    n := n + 1;
  end loop;
  return n;
end $$;

-- Aplica um modelo a um projeto que ainda não tem atividades.
create function aplica_modelo_projeto(p_projeto uuid, p_modelo uuid) returns void
language plpgsql security definer set search_path = public as $$
declare w uuid;
begin
  select workspace_id into w from projetos where id = p_projeto;
  if w is null or not pode_operar(w) then raise exception 'Sem permissão neste projeto'; end if;
  if exists (select 1 from projeto_atividades where projeto_id = p_projeto) then raise exception 'O projeto já tem atividades'; end if;
  if not exists (select 1 from projeto_modelos where id = p_modelo and workspace_id = w) then raise exception 'Modelo inválido'; end if;
  update projetos set modelo_id = p_modelo where id = p_projeto;
  perform projeto_aplica_modelo(p_projeto, p_modelo);
end $$;

-- Modelo padrão de campanha, com atividades, funções e dependências.
create function modelo_padrao_campanha(p_ws uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare mid uuid := gen_random_uuid();
  g1 uuid := gen_random_uuid(); g2 uuid := gen_random_uuid(); g3 uuid := gen_random_uuid(); g4 uuid := gen_random_uuid(); g5 uuid := gen_random_uuid();
  a11 uuid := gen_random_uuid(); a12 uuid := gen_random_uuid(); a21 uuid := gen_random_uuid(); a22 uuid := gen_random_uuid(); a23 uuid := gen_random_uuid();
  a31 uuid := gen_random_uuid(); a32 uuid := gen_random_uuid(); a41 uuid := gen_random_uuid(); a42 uuid := gen_random_uuid(); a51 uuid := gen_random_uuid();
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if exists (select 1 from projeto_modelos where workspace_id = p_ws and padrao_campanha) then raise exception 'Já existe um modelo padrão de campanha'; end if;
  insert into projeto_modelos (id, workspace_id, nome, descricao, padrao_campanha)
  values (mid, p_ws, 'Campanha de tráfego pago', 'Do planejamento ao relatório de aprendizados. Ajuste atividades, funções e prazos.', true);
  insert into projeto_modelo_atividades (id, workspace_id, modelo_id, pai_id, titulo, funcao, ordem, depende_de, prazo_dias) values
    (g1, p_ws, mid, null, '1. Planejamento', null, 10, '{}', 3),
    (g2, p_ws, mid, null, '2. Criativos', null, 20, array[g1], 10),
    (g3, p_ws, mid, null, '3. Tracking e páginas', null, 30, array[g1], 8),
    (g4, p_ws, mid, null, '4. Execução', null, 40, array[g2, g3], 12),
    (g5, p_ws, mid, null, '5. Análise', null, 50, array[g4], 20);
  insert into projeto_modelo_atividades (id, workspace_id, modelo_id, pai_id, titulo, funcao, ordem, depende_de, prazo_dias) values
    (a11, p_ws, mid, g1, 'Definir metas, orçamento e público', 'Estrategista', 11, '{}', 2),
    (a12, p_ws, mid, g1, 'Definir ângulos e oferta dos criativos', 'Estrategista', 12, array[a11], 3),
    (a21, p_ws, mid, g2, 'Escrever roteiros e copys', 'Copywriter', 21, '{}', 6),
    (a22, p_ws, mid, g2, 'Produzir as peças', 'Designer', 22, array[a21], 9),
    (a23, p_ws, mid, g2, 'Revisar e aprovar os criativos', 'Estrategista', 23, array[a22], 10),
    (a31, p_ws, mid, g3, 'Gerar os links com UTM de cada criativo', 'Gestor de tráfego', 31, '{}', 6),
    (a32, p_ws, mid, g3, 'Conferir pixel, eventos e conversões', 'Gestor de tráfego', 32, array[a31], 8),
    (a41, p_ws, mid, g4, 'Subir e publicar as campanhas', 'Gestor de tráfego', 41, '{}', 11),
    (a42, p_ws, mid, g4, 'Acompanhar e otimizar todo dia', 'Gestor de tráfego', 42, array[a41], 12),
    (a51, p_ws, mid, g5, 'Relatório de resultados e aprendizados', 'Analista de dados', 51, '{}', 20);
  return mid;
end $$;
revoke execute on function projetos_das_campanhas(uuid), aplica_modelo_projeto(uuid, uuid), modelo_padrao_campanha(uuid) from public, anon;
grant execute on function projetos_das_campanhas(uuid), aplica_modelo_projeto(uuid, uuid), modelo_padrao_campanha(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 9. Segurança por workspace
-- ---------------------------------------------------------------------
alter table equipe enable row level security;
alter table projeto_modelos enable row level security;
alter table projeto_modelo_atividades enable row level security;
alter table projetos enable row level security;
alter table projeto_atividades enable row level security;
alter table notificacoes enable row level security;
alter table campanha_links enable row level security;
create policy equipe_acesso on equipe for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy projeto_modelos_acesso on projeto_modelos for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy projeto_modelo_atividades_acesso on projeto_modelo_atividades for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy projetos_acesso on projetos for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy projeto_atividades_acesso on projeto_atividades for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy notificacoes_acesso on notificacoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy campanha_links_acesso on campanha_links for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
