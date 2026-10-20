-- Tipos de produto: digital, SaaS e serviço (além dos que já existiam)
alter table produtos drop constraint produtos_tipo_check;
alter table produtos add constraint produtos_tipo_check
  check (tipo in ('digital', 'saas', 'servico', 'curso', 'assinatura', 'outro'));

-- Fontes de vídeo: webinário, VSL ou aula, em qualquer plataforma
create table fontes_video (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  nome text not null,
  tipo text not null check (tipo in ('webinario', 'vsl', 'aula')),
  plataforma text not null default 'outro' check (plataforma in ('youtube', 'vimeo', 'vturb', 'panda', 'wistia', 'zoom', 'meet', 'outro')),
  id_externo text,
  url text,
  funil_id uuid references funis(id) on delete set null,
  campanha_id uuid references campanhas(id) on delete set null,
  data_evento date,
  ativo boolean not null default true
);

-- Métricas por dia (vem de importação, manual ou integração futura)
create table video_metricas_dia (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  fonte_id uuid not null references fontes_video(id) on delete cascade,
  data date not null,
  plays int not null default 0 check (plays >= 0),
  espectadores int not null default 0 check (espectadores >= 0),
  tempo_assistido_seg bigint not null default 0 check (tempo_assistido_seg >= 0),
  retencao_pct numeric(5, 2) check (retencao_pct between 0 and 100),
  conclusoes int not null default 0 check (conclusoes >= 0),
  cliques_cta int not null default 0 check (cliques_cta >= 0),
  pico_simultaneo int not null default 0 check (pico_simultaneo >= 0),
  unique (fonte_id, data)
);
create index video_metricas_dia_ix on video_metricas_dia (workspace_id, data);

-- Presença por pessoa (quem assistiu, ao vivo ou replay, e quanto)
create table presencas_video (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  fonte_id uuid not null references fontes_video(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  assistiu_seg int not null default 0 check (assistiu_seg >= 0),
  ao_vivo boolean not null default false,
  primeiro_em timestamptz not null default now(),
  ultimo_em timestamptz not null default now(),
  unique (fonte_id, pessoa_id)
);
create index presencas_video_ix on presencas_video (workspace_id, pessoa_id);

create function video_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'fontes_video' then
    if new.funil_id is not null and not exists (select 1 from funis where id = new.funil_id and workspace_id = new.workspace_id) then
      raise exception 'Funil precisa pertencer ao mesmo workspace'; end if;
    if new.campanha_id is not null and not exists (select 1 from campanhas where id = new.campanha_id and workspace_id = new.workspace_id) then
      raise exception 'Campanha precisa pertencer ao mesmo workspace'; end if;
  else
    if not exists (select 1 from fontes_video where id = new.fonte_id and workspace_id = new.workspace_id) then
      raise exception 'Vídeo precisa pertencer ao mesmo workspace'; end if;
  end if;
  return new;
end $$;
create function video_valida_presenca() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from fontes_video where id = new.fonte_id and workspace_id = new.workspace_id) then
    raise exception 'Vídeo precisa pertencer ao mesmo workspace'; end if;
  if not exists (select 1 from pessoas where id = new.pessoa_id and workspace_id = new.workspace_id) then
    raise exception 'Pessoa precisa pertencer ao mesmo workspace'; end if;
  return new;
end $$;
create trigger fontes_video_valida before insert or update on fontes_video for each row execute function video_valida();
create trigger video_metricas_valida before insert or update on video_metricas_dia for each row execute function video_valida();
create trigger presencas_video_valida before insert or update on presencas_video for each row execute function video_valida_presenca();

-- Registra presença por e-mail (contrato para webhooks e importação de lista de presença)
create function registrar_presenca_video(p_ws uuid, p_fonte uuid, p_email text, p_segundos int, p_ao_vivo boolean default false, p_quando timestamptz default now())
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  if not pode_operar(p_ws) then raise exception 'Sem permissão neste workspace'; end if;
  if not exists (select 1 from fontes_video where id = p_fonte and workspace_id = p_ws) then raise exception 'Vídeo não encontrado'; end if;
  select id into pid from pessoas where workspace_id = p_ws and lower(email) = lower(trim(p_email)) limit 1;
  if pid is null then raise exception 'Nenhuma pessoa com o e-mail %', p_email; end if;
  insert into presencas_video (workspace_id, fonte_id, pessoa_id, assistiu_seg, ao_vivo, primeiro_em, ultimo_em)
  values (p_ws, p_fonte, pid, greatest(p_segundos, 0), p_ao_vivo, p_quando, p_quando)
  on conflict (fonte_id, pessoa_id) do update
    set assistiu_seg = greatest(presencas_video.assistiu_seg, excluded.assistiu_seg),
        ao_vivo = presencas_video.ao_vivo or excluded.ao_vivo,
        ultimo_em = greatest(presencas_video.ultimo_em, excluded.ultimo_em);
  return pid;
end $$;
revoke execute on function video_valida() from public, anon, authenticated;
revoke execute on function video_valida_presenca() from public, anon, authenticated;
revoke execute on function registrar_presenca_video(uuid, uuid, text, int, boolean, timestamptz) from public, anon;
grant execute on function registrar_presenca_video(uuid, uuid, text, int, boolean, timestamptz) to authenticated;

-- Resumo por vídeo (razões calculadas no código; aqui só somas e contagens)
create view v_video_resumo with (security_invoker = true) as
select f.id as fonte_id, f.workspace_id, f.nome, f.tipo, f.plataforma, f.data_evento, f.funil_id, f.campanha_id, f.ativo,
  coalesce(m.plays, 0) as plays, coalesce(m.espectadores, 0) as espectadores, coalesce(m.tempo_assistido_seg, 0) as tempo_assistido_seg,
  m.retencao_ponderada, coalesce(m.conclusoes, 0) as conclusoes, coalesce(m.cliques_cta, 0) as cliques_cta, coalesce(m.pico, 0) as pico_simultaneo,
  coalesce(p.presentes, 0) as presentes, coalesce(p.ao_vivo, 0) as presentes_ao_vivo, coalesce(p.compradores, 0) as compradores
from fontes_video f
left join (
  select fonte_id, sum(plays) plays, sum(espectadores) espectadores, sum(tempo_assistido_seg) tempo_assistido_seg,
         sum(retencao_pct * espectadores) filter (where retencao_pct is not null) / nullif(sum(espectadores) filter (where retencao_pct is not null), 0) as retencao_ponderada,
         sum(conclusoes) conclusoes, sum(cliques_cta) cliques_cta, max(pico_simultaneo) pico
  from video_metricas_dia group by fonte_id) m on m.fonte_id = f.id
left join (
  select pv.fonte_id, count(*) presentes, count(*) filter (where pv.ao_vivo) ao_vivo,
         count(*) filter (where exists (select 1 from vendas v where v.pessoa_id = pv.pessoa_id and v.status = 'aprovada' and v.data_venda >= pv.primeiro_em::date)) compradores
  from presencas_video pv group by pv.fonte_id) p on p.fonte_id = f.id;

do $$
declare t text;
begin
  foreach t in array array['fontes_video', 'video_metricas_dia', 'presencas_video'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
  end loop;
end $$;
