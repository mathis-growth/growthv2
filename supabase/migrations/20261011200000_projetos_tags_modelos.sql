-- v0.90 — Projetos: tags, painel com gráfico, salvar como modelo, vínculo com campanha · Campanha: meta de CPL por canal
-- 1. projetos.tags e projeto_atividades.tags (filtros por tag).
-- 2. projeto_painel(projeto): situação, responsáveis e série diária planejado (pelo prazo) × concluído (para o gráfico).
-- 3. projeto_salvar_como_modelo(projeto, nome, padrao_campanha): copia atividades, subatividades, dependências, funções e prazos (em dias a partir do início).
-- 4. projeto_vincular_campanha(projeto, campanha) e campanha_criar_projeto(campanha, modelo, nome): projeto da campanha a partir de um modelo, já com as atividades dos blocos.
-- 5. campanha_canais_resultado(campanha): leads, investimento e CPL por canal da campanha contra a meta de leads e de CPL do canal.
-- Rode DEPOIS de 20261011100000_fase2_captacao_vendas.sql (usa campanha_participacoes). Idempotente.

alter table projetos add column if not exists tags text[] not null default '{}';
alter table projeto_atividades add column if not exists tags text[] not null default '{}';
create index if not exists projetos_tags_ix on projetos using gin (tags);
create index if not exists projeto_atividades_tags_ix on projeto_atividades using gin (tags);

-- ============ painel do projeto ============
create or replace function public.projeto_painel(p_projeto uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p projetos; ini date; fim date; h date := (now() at time zone 'America/Sao_Paulo')::date; r jsonb;
begin
  select * into p from projetos where id = p_projeto;
  if not found or not pertence_ao_workspace(p.workspace_id) or not perm(p.workspace_id, 'ler', '{prj,adm,vendas,revops}'::text[]) then raise exception 'Projeto não encontrado'; end if;
  -- só atividades que são de fato feitas (folhas), sem as canceladas
  select coalesce(p.data_inicio, min((a.criado_em at time zone 'America/Sao_Paulo')::date), h),
         greatest(coalesce(p.data_fim_prevista, h), h, coalesce(max(a.prazo), h))
    into ini, fim
    from projeto_atividades a where a.projeto_id = p.id and a.status <> 'cancelada' and not exists (select 1 from projeto_atividades f where f.pai_id = a.id);
  if fim - ini > 366 then ini := fim - 366; end if;
  with pp as (select a.id, a.status, a.responsavel_id, a.prazo, (a.concluida_em at time zone 'America/Sao_Paulo')::date as concluida_em
                from projeto_atividades a where a.projeto_id = p.id and a.status <> 'cancelada' and not exists (select 1 from projeto_atividades f where f.pai_id = a.id))
  select jsonb_build_object(
    'inicio', ini, 'fim', fim, 'total', (select count(*) from pp),
    'status', coalesce((select jsonb_agg(jsonb_build_object('status', status, 'n', n) order by status) from (select status, count(*) n from pp group by 1) s), '[]'::jsonb),
    'responsaveis', coalesce((select jsonb_agg(x order by x.abertas desc, x.nome) from (
        select coalesce(e.nome, 'Sem responsável') as nome, count(*) filter (where pp.status in ('liberada', 'em_andamento')) as abertas,
               count(*) filter (where pp.status = 'bloqueada') as bloqueadas, count(*) filter (where pp.status = 'concluida') as concluidas,
               count(*) filter (where pp.status <> 'concluida' and pp.prazo < h) as atrasadas
          from pp left join equipe e on e.id = pp.responsavel_id group by 1) x), '[]'::jsonb),
    'serie', coalesce((select jsonb_agg(jsonb_build_object('d', g.d::date,
        'planejado', (select count(*) from pp where pp.prazo <= g.d::date),
        'concluido', case when g.d::date <= h then (select count(*) from pp where pp.status = 'concluida' and pp.concluida_em <= g.d::date) end) order by g.d)
      from generate_series(ini, fim, case when fim - ini > 90 then interval '7 days' else interval '1 day' end) g(d)), '[]'::jsonb),
    'sem_prazo', (select count(*) from pp where pp.prazo is null))
  into r;
  return r;
end $$;
revoke execute on function public.projeto_painel(uuid) from public, anon;
grant execute on function public.projeto_painel(uuid) to authenticated, service_role;

-- ============ salvar como modelo ============
create or replace function public.projeto_salvar_como_modelo(p_projeto uuid, p_nome text, p_padrao_campanha boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare p projetos; m uuid;
begin
  select * into p from projetos where id = p_projeto;
  if not found then raise exception 'Projeto não encontrado'; end if;
  if not pode_editar(p.workspace_id, '{prj}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if coalesce(trim(p_nome), '') = '' then raise exception 'Dê um nome ao modelo'; end if;
  if exists (select 1 from projeto_modelos where workspace_id = p.workspace_id and lower(nome) = lower(trim(p_nome)) and ativo) then raise exception 'Já existe um modelo com este nome'; end if;
  if not exists (select 1 from projeto_atividades where projeto_id = p.id and status <> 'cancelada') then raise exception 'O projeto não tem atividades para virar modelo'; end if;
  if coalesce(p_padrao_campanha, false) then update projeto_modelos set padrao_campanha = false where workspace_id = p.workspace_id and padrao_campanha; end if;
  insert into projeto_modelos (workspace_id, nome, descricao, padrao_campanha, ativo)
  values (p.workspace_id, trim(p_nome), 'Criado a partir do projeto "' || p.nome || '"' || coalesce(' — ' || nullif(p.descricao, ''), ''), coalesce(p_padrao_campanha, false), true)
  returning id into m;
  with a as (select x.*, gen_random_uuid() as novo from projeto_atividades x where x.projeto_id = p.id and x.status <> 'cancelada')
  insert into projeto_modelo_atividades (id, workspace_id, modelo_id, pai_id, titulo, descricao, funcao, responsavel_id, ordem, depende_de, prazo_dias)
  select a.novo, a.workspace_id, m, (select y.novo from a y where y.id = a.pai_id), a.titulo, a.descricao, a.funcao, a.responsavel_id, a.ordem,
         coalesce((select array_agg(y.novo) from a y where y.id = any(a.depende_de)), '{}'),
         case when a.prazo is not null and p.data_inicio is not null then greatest(a.prazo - p.data_inicio, 0) end
    from a order by (a.pai_id is not null), a.ordem;
  return m;
end $$;
revoke execute on function public.projeto_salvar_como_modelo(uuid, text, boolean) from public, anon;
grant execute on function public.projeto_salvar_como_modelo(uuid, text, boolean) to authenticated, service_role;

-- ============ vínculo projeto × campanha ============
create or replace function public.projeto_vincular_campanha(p_projeto uuid, p_campanha uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p projetos;
begin
  select * into p from projetos where id = p_projeto;
  if not found then raise exception 'Projeto não encontrado'; end if;
  if not pode_editar(p.workspace_id, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_campanha is not null and not exists (select 1 from campanhas where id = p_campanha and workspace_id = p.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  update projetos set campanha_id = p_campanha where id = p.id;
  if p_campanha is not null then perform _campanha_gerar_atividades(p_campanha); end if;
end $$;
revoke execute on function public.projeto_vincular_campanha(uuid, uuid) from public, anon;
grant execute on function public.projeto_vincular_campanha(uuid, uuid) to authenticated, service_role;

create or replace function public.campanha_criar_projeto(p_campanha uuid, p_modelo uuid, p_nome text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c campanhas; novo uuid; resp uuid;
begin
  select * into c from campanhas where id = p_campanha;
  if not found then raise exception 'Campanha não encontrada'; end if;
  if not pode_editar(c.workspace_id, '{prj,mkt}'::text[]) then raise exception 'Sem permissão para esta operação neste módulo'; end if;
  if p_modelo is not null and not exists (select 1 from projeto_modelos where id = p_modelo and workspace_id = c.workspace_id) then raise exception 'Modelo não encontrado'; end if;
  insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
  values (c.workspace_id, coalesce(nullif(trim(p_nome), ''), 'Campanha: ' || c.nome), 'Criado pela campanha a partir de um modelo.', c.id, p_modelo,
          coalesce(c.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), c.data_fim)
  returning id into novo;
  -- o gatilho do projeto já criou as atividades do modelo; agora as dos blocos da estratégia (no projeto mais antigo da campanha)
  perform _campanha_gerar_atividades(c.id);
  return novo;
end $$;
revoke execute on function public.campanha_criar_projeto(uuid, uuid, text) from public, anon;
grant execute on function public.campanha_criar_projeto(uuid, uuid, text) to authenticated, service_role;

-- ============ leads e CPL por canal da campanha ============
create or replace function public.campanha_canais_resultado(p_campanha uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c campanhas; r jsonb;
begin
  select * into c from campanhas where id = p_campanha;
  if not found or not pertence_ao_workspace(c.workspace_id) then raise exception 'Campanha não encontrada'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', cc.id, 'canal', cc.canal, 'temperatura', cc.temperatura, 'utm_campaign', cc.utm_campaign,
      'meta_leads', cc.meta_leads, 'meta_cpl', cc.meta_cpl, 'orcamento', cc.orcamento,
      'leads', l.n, 'investimento', i.v,
      'cpl', case when l.n > 0 and i.v is not null then round(i.v / l.n, 2) end,
      'pct_leads', case when cc.meta_leads > 0 then round(l.n * 100.0 / cc.meta_leads, 1) end) order by cc.canal, cc.temperatura nulls first), '[]'::jsonb)
  into r
  from campanha_canais cc
  left join lateral (select count(*) n from campanha_participacoes p where p.campanha_id = c.id and (p.campanha_canal_id = cc.id or (p.campanha_canal_id is null and p.utm_campaign = cc.utm_campaign))) l on true
  left join lateral (select sum(md.custo) v from metricas_anuncio_dia md join anuncios an on an.id = md.anuncio_id where an.campanha_canal_id = cc.id) i on true
  where cc.campanha_id = c.id;
  return r;
end $$;
revoke execute on function public.campanha_canais_resultado(uuid) from public, anon;
grant execute on function public.campanha_canais_resultado(uuid) to authenticated, service_role;

-- ============ tela nova no catálogo de acesso ============
insert into acesso_telas (tela, modulo, nome, grupo, ordem) values ('prj-atividades', 'prj', 'Todas as atividades', 'Projetos', 27)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['prj-atividades'] where telas @> array['prj-lista'] and not telas @> array['prj-atividades'];
