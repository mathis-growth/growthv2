-- Pesquisas: de lead, de onboarding, da jornada do aluno e de descoberta da NSM.
-- O envio em si (WhatsApp, e-mail) depende de integração; aqui ficam a fila, o link de resposta,
-- as respostas e os números (NPS, escala, PMF, distribuição), tudo em código fixo.

create table pesquisas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  tipo text not null default 'lead' check (tipo in ('lead', 'onboarding', 'jornada', 'nsm', 'outra')),
  descricao text,
  ativa boolean not null default true,
  gatilho text not null default 'manual' check (gatilho in ('manual', 'cadastro', 'etapa', 'entrada_aluno')),
  gatilho_etapa text,
  funil_id uuid references funis(id) on delete set null,
  dispensa_qualificado boolean not null default false,
  canal_envio text not null default 'link' check (canal_envio in ('link', 'whatsapp', 'email')),
  mensagem text,
  aceita_link_aberto boolean not null default false,
  token_aberto text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  criado_em timestamptz not null default now(),
  check (gatilho <> 'etapa' or gatilho_etapa is not null)
);

create table pesquisa_perguntas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pesquisa_id uuid not null references pesquisas(id) on delete cascade,
  ordem int not null default 0,
  texto text not null,
  tipo text not null check (tipo in ('nps', 'escala', 'escolha', 'multipla', 'sim_nao', 'texto')),
  opcoes text[] not null default '{}',
  obrigatoria boolean not null default true,
  papel text not null default 'livre' check (papel in ('livre', 'nps', 'pmf', 'valor', 'alavanca', 'qualificacao')),
  criado_em timestamptz not null default now(),
  check (tipo not in ('escolha', 'multipla') or cardinality(opcoes) >= 2)
);
create index pesquisa_perguntas_p on pesquisa_perguntas (pesquisa_id, ordem);

create table pesquisa_envios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pesquisa_id uuid not null references pesquisas(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  token text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  status text not null default 'pendente' check (status in ('pendente', 'enviado', 'respondido', 'dispensado')),
  motivo text,
  origem text not null default 'gatilho' check (origem in ('gatilho', 'manual', 'retroativo')),
  gerado_em timestamptz not null default now(),
  enviado_em timestamptz,
  respondido_em timestamptz,
  unique (pesquisa_id, pessoa_id)
);
create index pesquisa_envios_ws on pesquisa_envios (workspace_id, status);

create table pesquisa_respostas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pesquisa_id uuid not null references pesquisas(id) on delete cascade,
  envio_id uuid references pesquisa_envios(id) on delete set null,
  pessoa_id uuid references pessoas(id) on delete set null,
  email text,
  respondida_em timestamptz not null default now()
);
create index pesquisa_respostas_p on pesquisa_respostas (pesquisa_id, respondida_em);

create table pesquisa_resposta_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  resposta_id uuid not null references pesquisa_respostas(id) on delete cascade,
  pergunta_id uuid not null references pesquisa_perguntas(id) on delete cascade,
  valor_num numeric,
  valor_texto text,
  unique (resposta_id, pergunta_id, valor_texto)
);
create index pesquisa_itens_p on pesquisa_resposta_itens (pergunta_id);

-- Leitura humana das respostas: o que a pessoa concluiu e qual alavanca ou métrica isso toca.
create table pesquisa_insights (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pesquisa_id uuid not null references pesquisas(id) on delete cascade,
  pergunta_id uuid references pesquisa_perguntas(id) on delete set null,
  metrica_id uuid references growth_metricas(id) on delete set null,
  texto text not null,
  criado_em timestamptz not null default now()
);

-- Um experimento pode nascer de uma pesquisa.
alter table growth_experimentos add column pesquisa_id uuid references pesquisas(id) on delete set null;
alter table growth_experimentos add column insight text;

-- Fila: quando alguém se cadastra, entra numa etapa ou vira aluno, gera o envio das pesquisas ativas ligadas ao gatilho.
create function pesquisa_enfileira(p_ws uuid, p_pessoa uuid, p_gatilho text, p_etapa text, p_funil uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, status, motivo, origem)
  select s.workspace_id, s.id, p_pessoa,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = p_pessoa and x.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when s.dispensa_qualificado and exists (select 1 from pessoas x where x.id = p_pessoa and x.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'gatilho'
  from pesquisas s
  where s.workspace_id = p_ws and s.ativa and s.gatilho = p_gatilho
    and (p_gatilho <> 'etapa' or (s.gatilho_etapa = p_etapa and (s.funil_id is null or s.funil_id = p_funil)))
  on conflict (pesquisa_id, pessoa_id) do nothing;
end $$;

create function pesquisa_trg_pessoa() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pesquisa_enfileira(new.workspace_id, new.id, 'cadastro', null, null);
  return null;
end $$;
create trigger pesquisa_pessoa_t after insert on pessoas for each row execute function pesquisa_trg_pessoa();

create function pesquisa_trg_etapa() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'etapa' and new.para is not null then
    perform pesquisa_enfileira(new.workspace_id, new.pessoa_id, 'etapa', new.para, new.funil_id);
  end if;
  return null;
end $$;
create trigger pesquisa_etapa_t after insert on pessoa_funil_historico for each row execute function pesquisa_trg_etapa();

create function pesquisa_trg_aluno() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pesquisa_enfileira(new.workspace_id, new.pessoa_id, 'entrada_aluno', null, null);
  return null;
end $$;
create trigger pesquisa_aluno_t after insert on alunos for each row execute function pesquisa_trg_aluno();
revoke execute on function pesquisa_enfileira(uuid, uuid, text, text, uuid), pesquisa_trg_pessoa(), pesquisa_trg_etapa(), pesquisa_trg_aluno() from public, anon, authenticated;

-- Gera os envios de quem já estava no gatilho antes da pesquisa existir.
create function pesquisa_gerar_envios(p_pesquisa uuid) returns int
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; n int;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found or not pode_operar(v_p.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  if v_p.gatilho = 'manual' then raise exception 'Pesquisa manual: escolha as pessoas na tela de envios'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, status, motivo, origem)
  select v_p.workspace_id, v_p.id, x.pessoa_id,
    case when v_p.dispensa_qualificado and exists (select 1 from pessoas q where q.id = x.pessoa_id and q.qualificacao = 'qualificado') then 'dispensado' else 'pendente' end,
    case when v_p.dispensa_qualificado and exists (select 1 from pessoas q where q.id = x.pessoa_id and q.qualificacao = 'qualificado') then 'ja_qualificado' end,
    'retroativo'
  from (
    select id as pessoa_id from pessoas where v_p.gatilho = 'cadastro' and workspace_id = v_p.workspace_id
    union select pessoa_id from alunos where v_p.gatilho = 'entrada_aluno' and workspace_id = v_p.workspace_id
    union select pessoa_id from pessoa_funil_historico where v_p.gatilho = 'etapa' and workspace_id = v_p.workspace_id and tipo = 'etapa' and para = v_p.gatilho_etapa and (v_p.funil_id is null or funil_id = v_p.funil_id)
  ) x
  on conflict (pesquisa_id, pessoa_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

create function pesquisa_enviar_para(p_pesquisa uuid, p_pessoas uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare v_p pesquisas; n int;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found or not pode_operar(v_p.workspace_id) then raise exception 'Sem permissão neste workspace'; end if;
  insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem)
  select v_p.workspace_id, v_p.id, x.id, 'manual' from pessoas x where x.id = any (coalesce(p_pessoas, '{}')) and x.workspace_id = v_p.workspace_id
  on conflict (pesquisa_id, pessoa_id) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function pesquisa_gerar_envios(uuid), pesquisa_enviar_para(uuid, uuid[]) from public, anon;
grant execute on function pesquisa_gerar_envios(uuid), pesquisa_enviar_para(uuid, uuid[]) to authenticated;

-- Página pública de resposta: só enxerga e grava quem tem o token.
create function pesquisa_publica(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas; v_aberto boolean := false; r_perg jsonb;
begin
  if p_token is null or length(p_token) < 32 then return null; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if found then select * into v_p from pesquisas where id = v_e.pesquisa_id;
  else select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto; v_aberto := true; end if;
  if v_p.id is null or not v_p.ativa then return null; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'texto', texto, 'tipo', tipo, 'opcoes', to_jsonb(opcoes), 'obrigatoria', obrigatoria) order by ordem, criado_em), '[]'::jsonb)
  into r_perg from pesquisa_perguntas where pesquisa_id = v_p.id;
  return jsonb_build_object('nome', v_p.nome, 'descricao', v_p.descricao, 'perguntas', r_perg, 'aberto', v_aberto, 'ja_respondida', (not v_aberto and v_e.status = 'respondido'));
end $$;

create function pesquisa_responder(p_token text, p_respostas jsonb, p_email text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas; v_aberto boolean := false; q record; v jsonb; v_num numeric; v_txt text; v_resp uuid; v_pessoa uuid; v_email text; r_lead jsonb := '{}'::jsonb; o jsonb;
begin
  if p_token is null or length(p_token) < 32 then raise exception 'Link inválido'; end if;
  if p_respostas is null or jsonb_typeof(p_respostas) <> 'object' or length(p_respostas::text) > 20000 then raise exception 'Resposta inválida'; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if found then
    if v_e.status = 'respondido' then raise exception 'Esta pesquisa já foi respondida'; end if;
    select * into v_p from pesquisas where id = v_e.pesquisa_id; v_pessoa := v_e.pessoa_id;
  else
    select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto; v_aberto := true;
  end if;
  if v_p.id is null or not v_p.ativa then raise exception 'Pesquisa indisponível'; end if;
  v_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_email is not null and (length(v_email) > 200 or v_email !~ '^[^@\s]+@[^@\s]+$') then raise exception 'E-mail inválido'; end if;
  if v_aberto and v_email is not null then select id into v_pessoa from pessoas where workspace_id = v_p.workspace_id and lower(email) = v_email limit 1; end if;

  insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id, email) values (v_p.workspace_id, v_p.id, v_e.id, v_pessoa, v_email) returning id into v_resp;

  for q in select * from pesquisa_perguntas where pesquisa_id = v_p.id order by ordem, criado_em loop
    v := p_respostas -> q.id::text;
    if v is null or v = 'null'::jsonb or (jsonb_typeof(v) = 'string' and trim(v #>> '{}') = '') or (jsonb_typeof(v) = 'array' and jsonb_array_length(v) = 0) then
      if q.obrigatoria then raise exception 'Responda: %', q.texto; end if;
      continue;
    end if;
    begin
      if q.tipo in ('nps', 'escala') then
        v_num := (v #>> '{}')::numeric;
        if v_num <> trunc(v_num) or (q.tipo = 'nps' and (v_num < 0 or v_num > 10)) or (q.tipo = 'escala' and (v_num < 1 or v_num > 5)) then raise exception 'fora da faixa'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num) values (v_p.workspace_id, v_resp, q.id, v_num);
        r_lead := r_lead || jsonb_build_object(q.texto, v_num);
      elsif q.tipo = 'sim_nao' then
        v_txt := lower(v #>> '{}');
        if v_txt not in ('sim', 'nao') then raise exception 'valor inválido'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num, valor_texto) values (v_p.workspace_id, v_resp, q.id, case when v_txt = 'sim' then 1 else 0 end, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      elsif q.tipo = 'escolha' then
        v_txt := v #>> '{}';
        if not (v_txt = any (q.opcoes)) then raise exception 'opção inválida'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      elsif q.tipo = 'multipla' then
        if jsonb_typeof(v) <> 'array' then raise exception 'esperava lista'; end if;
        for o in select * from jsonb_array_elements(v) loop
          v_txt := o #>> '{}';
          if not (v_txt = any (q.opcoes)) then raise exception 'opção inválida'; end if;
          insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt) on conflict do nothing;
        end loop;
        r_lead := r_lead || jsonb_build_object(q.texto, v);
      else
        v_txt := trim(v #>> '{}');
        if length(v_txt) > 2000 then raise exception 'texto longo demais'; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values (v_p.workspace_id, v_resp, q.id, v_txt);
        r_lead := r_lead || jsonb_build_object(q.texto, v_txt);
      end if;
    exception when others then
      raise exception 'Resposta inválida em: %', q.texto;
    end;
  end loop;

  if v_e.id is not null then update pesquisa_envios set status = 'respondido', respondido_em = now() where id = v_e.id; end if;
  if v_p.tipo = 'lead' and v_pessoa is not null then
    update pessoas set respostas_pesquisa = coalesce(respostas_pesquisa, '{}'::jsonb) || r_lead, pesquisa_respondida_em = coalesce(pesquisa_respondida_em, now()) where id = v_pessoa and workspace_id = v_p.workspace_id;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Painel de uma pesquisa: envios, taxa de resposta e números por pergunta.
-- NPS = (promotores 9-10 menos detratores 0-6) ÷ respostas × 100. PMF = parcela que marcou a PRIMEIRA opção da pergunta de papel "pmf"
-- (por convenção "Muito desapontado"); 40% ou mais é a referência usual de ajuste produto-mercado.
create function pesquisa_painel(p_pesquisa uuid, p_ini date default null, p_fim date default null) returns jsonb
language plpgsql stable set search_path = public as $$
declare v_p pesquisas; r_env jsonb; r_perg jsonb; v_resp int; v_ini timestamptz; v_fim timestamptz;
begin
  select * into v_p from pesquisas where id = p_pesquisa;
  if not found then raise exception 'Pesquisa não encontrada'; end if;
  v_ini := case when p_ini is null then '-infinity'::timestamptz else p_ini::timestamp at time zone 'America/Sao_Paulo' end;
  v_fim := case when p_fim is null then 'infinity'::timestamptz else (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo' end;
  select jsonb_build_object('total', count(*), 'pendente', count(*) filter (where status = 'pendente'), 'enviado', count(*) filter (where status = 'enviado'),
    'respondido', count(*) filter (where status = 'respondido'), 'dispensado', count(*) filter (where status = 'dispensado')) into r_env
  from pesquisa_envios where pesquisa_id = p_pesquisa;
  select count(*) into v_resp from pesquisa_respostas where pesquisa_id = p_pesquisa and respondida_em >= v_ini and respondida_em < v_fim;

  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'texto', q.texto, 'tipo', q.tipo, 'papel', q.papel, 'opcoes', to_jsonb(q.opcoes), 'ordem', q.ordem,
    'n', a.n, 'media', a.media, 'promotores', a.prom, 'neutros', a.neut, 'detratores', a.detr,
    'nps', case when q.tipo = 'nps' and a.n > 0 then round((a.prom - a.detr)::numeric / a.n * 100, 1) end,
    'pmf', case when q.papel = 'pmf' and q.tipo = 'escolha' and r.base > 0 then round(coalesce(a.primeira, 0)::numeric / r.base * 100, 1) end,
    'distribuicao', coalesce(a.dist, '[]'::jsonb), 'textos', coalesce(a.textos, '[]'::jsonb)) order by q.ordem, q.criado_em), '[]'::jsonb)
  into r_perg
  from pesquisa_perguntas q
  left join lateral (select count(distinct i.resposta_id) as base from pesquisa_resposta_itens i join pesquisa_respostas rr on rr.id = i.resposta_id
      where i.pergunta_id = q.id and rr.respondida_em >= v_ini and rr.respondida_em < v_fim) r on true
  left join lateral (
    select count(distinct i.resposta_id) as n,
      avg(i.valor_num) filter (where q.tipo in ('nps', 'escala')) as media,
      count(*) filter (where q.tipo = 'nps' and i.valor_num >= 9) as prom,
      count(*) filter (where q.tipo = 'nps' and i.valor_num between 7 and 8) as neut,
      count(*) filter (where q.tipo = 'nps' and i.valor_num <= 6) as detr,
      count(*) filter (where i.valor_texto = q.opcoes[1]) as primeira,
      (select jsonb_agg(jsonb_build_object('k', d.k, 'n', d.n) order by d.n desc, d.k) from (
        select coalesce(i2.valor_texto, i2.valor_num::text) as k, count(*) as n from pesquisa_resposta_itens i2 join pesquisa_respostas r2 on r2.id = i2.resposta_id
        where i2.pergunta_id = q.id and q.tipo <> 'texto' and r2.respondida_em >= v_ini and r2.respondida_em < v_fim group by 1) d) as dist,
      (select jsonb_agg(t.valor_texto) from (
        select i3.valor_texto from pesquisa_resposta_itens i3 join pesquisa_respostas r3 on r3.id = i3.resposta_id
        where i3.pergunta_id = q.id and q.tipo = 'texto' and r3.respondida_em >= v_ini and r3.respondida_em < v_fim order by r3.respondida_em desc limit 30) t) as textos
    from pesquisa_resposta_itens i join pesquisa_respostas rr on rr.id = i.resposta_id
    where i.pergunta_id = q.id and rr.respondida_em >= v_ini and rr.respondida_em < v_fim) a on true
  where q.pesquisa_id = p_pesquisa;

  return jsonb_build_object('envios', r_env, 'respostas', v_resp,
    'taxa_resposta', case when (r_env ->> 'enviado')::int + (r_env ->> 'respondido')::int > 0 then round((r_env ->> 'respondido')::numeric / ((r_env ->> 'enviado')::int + (r_env ->> 'respondido')::int), 4) end,
    'perguntas', r_perg);
end $$;
revoke execute on function pesquisa_painel(uuid, date, date) from public, anon;
grant execute on function pesquisa_painel(uuid, date, date) to authenticated;
revoke execute on function pesquisa_publica(text), pesquisa_responder(text, jsonb, text) from public;
grant execute on function pesquisa_publica(text), pesquisa_responder(text, jsonb, text) to anon, authenticated;

alter table pesquisas enable row level security;
alter table pesquisa_perguntas enable row level security;
alter table pesquisa_envios enable row level security;
alter table pesquisa_respostas enable row level security;
alter table pesquisa_resposta_itens enable row level security;
alter table pesquisa_insights enable row level security;
create policy pesquisas_acesso on pesquisas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy pesquisa_perguntas_acesso on pesquisa_perguntas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy pesquisa_envios_acesso on pesquisa_envios for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy pesquisa_respostas_acesso on pesquisa_respostas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy pesquisa_resposta_itens_acesso on pesquisa_resposta_itens for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy pesquisa_insights_acesso on pesquisa_insights for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
