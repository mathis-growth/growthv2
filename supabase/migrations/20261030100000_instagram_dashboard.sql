-- v0.134 — Dashboard do Instagram (aba "Instagram" da Máquina de Conteúdo).
-- Fonte 1: a conexão com a Meta (social_posts e social_perfis_dia, já existentes), quando o app for aprovado.
-- Fonte 2 (até lá): planilha exportada do Meta Business Suite ou do Metricool, importada pela tela (social_importar_posts).
-- Fonte 3: as métricas já registradas em cada publicação da Máquina (conteudo_publicacoes, canal Instagram).
-- Cada post pode ser ligado a um conteúdo da Máquina, e então ganha território, frente, formato, destino e etiquetas.
-- Pode ser rodado de novo sem erro.

-- posts importados não têm conta conectada
alter table public.social_posts alter column conta_id drop not null;
alter table public.social_posts add column if not exists origem text not null default 'api';
alter table public.social_posts drop constraint if exists social_posts_origem_check;
alter table public.social_posts add constraint social_posts_origem_check check (origem in ('api', 'importado'));
alter table public.social_posts add column if not exists rede text not null default 'instagram';
alter table public.social_posts add column if not exists conteudo_id uuid references public.conteudos(id) on delete set null;
alter table public.social_posts add column if not exists seguidores_ganhos int;
alter table public.social_posts add column if not exists vinculo text check (vinculo is null or vinculo in ('manual', 'automatico'));
create unique index if not exists social_posts_importado_uq on public.social_posts (workspace_id, rede, id_externo) where conta_id is null;
create index if not exists social_posts_ws_data on public.social_posts (workspace_id, publicado_em);

-- quem edita Marketing pode ligar um post a um conteúdo (só essas colunas)
drop policy if exists vincular_conteudo on public.social_posts;
create policy vincular_conteudo on public.social_posts for update to authenticated
  using (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'editar', '{mkt}'::text[]))
  with check (pertence_ao_workspace(workspace_id) and perm(workspace_id, 'editar', '{mkt}'::text[]));
grant update (conteudo_id, vinculo) on public.social_posts to authenticated;

create or replace function public.social_posts_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.conteudo_id is not null and not exists (select 1 from conteudos where id = new.conteudo_id and workspace_id = new.workspace_id) then
    raise exception 'O conteúdo precisa ser deste cliente'; end if;
  if new.conteudo_id is null then new.vinculo := null; end if;
  return new;
end $$;
drop trigger if exists social_posts_valida_t on public.social_posts;
create trigger social_posts_valida_t before insert or update on public.social_posts for each row execute function public.social_posts_valida();
revoke execute on function public.social_posts_valida() from public, anon, authenticated;

-- ---------- importar posts (planilha do Meta Business Suite, Metricool ou digitada) ----------
-- Cada item: {"id_externo","publicado_em","tipo","legenda","url","alcance","impressoes","visualizacoes","curtidas","comentarios",
--             "compartilhamentos","salvamentos","seguidores_ganhos"}. Mesmo id_externo atualiza. Se der erro em um, nada entra.
create or replace function public.social_importar_posts(p_ws uuid, p_itens jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare it jsonb; n_novos int := 0; n_atual int := 0; idx text; i int := 0;
  num_ text := 'alcance,impressoes,visualizacoes,curtidas,comentarios,compartilhamentos,salvamentos,seguidores_ganhos'; k text;
begin
  if auth.uid() is not null and not perm(p_ws, 'editar', array['mkt']) then raise exception 'Sem permissão para editar o conteúdo deste cliente'; end if;
  if jsonb_typeof(p_itens) is distinct from 'array' then raise exception 'Envie uma lista de posts'; end if;
  if jsonb_array_length(p_itens) > 2000 then raise exception 'No máximo 2.000 posts por importação'; end if;
  for it in select * from jsonb_array_elements(p_itens) loop
    i := i + 1;
    idx := nullif(trim(coalesce(it ->> 'id_externo', '')), '');
    if idx is null then raise exception 'Linha %: falta o identificador do post (ID ou link)', i; end if;
    if (it ->> 'publicado_em') is null then raise exception 'Linha %: falta a data de publicação', i; end if;
    foreach k in array string_to_array(num_, ',') loop
      if it ? k and it ->> k is not null and not ((it ->> k) ~ '^\d+$') then raise exception 'Linha %: % precisa ser um número inteiro, zero ou maior', i, k; end if;
    end loop;
    if exists (select 1 from social_posts where workspace_id = p_ws and conta_id is null and rede = 'instagram' and id_externo = idx) then n_atual := n_atual + 1; else n_novos := n_novos + 1; end if;
    insert into social_posts (workspace_id, conta_id, origem, rede, id_externo, tipo, legenda, url, publicado_em, alcance, impressoes, visualizacoes,
      curtidas, comentarios, compartilhamentos, salvamentos, seguidores_ganhos)
    values (p_ws, null, 'importado', 'instagram', idx, nullif(lower(trim(coalesce(it ->> 'tipo', ''))), ''), nullif(it ->> 'legenda', ''),
      case when it ->> 'url' ~* '^https?://' then it ->> 'url' end, (it ->> 'publicado_em')::timestamptz,
      (it ->> 'alcance')::int, (it ->> 'impressoes')::int, (it ->> 'visualizacoes')::int, (it ->> 'curtidas')::int, (it ->> 'comentarios')::int,
      (it ->> 'compartilhamentos')::int, (it ->> 'salvamentos')::int, (it ->> 'seguidores_ganhos')::int)
    on conflict (workspace_id, rede, id_externo) where conta_id is null do update set
      tipo = coalesce(excluded.tipo, social_posts.tipo), legenda = coalesce(excluded.legenda, social_posts.legenda), url = coalesce(excluded.url, social_posts.url),
      publicado_em = excluded.publicado_em, alcance = coalesce(excluded.alcance, social_posts.alcance), impressoes = coalesce(excluded.impressoes, social_posts.impressoes),
      visualizacoes = coalesce(excluded.visualizacoes, social_posts.visualizacoes), curtidas = coalesce(excluded.curtidas, social_posts.curtidas),
      comentarios = coalesce(excluded.comentarios, social_posts.comentarios), compartilhamentos = coalesce(excluded.compartilhamentos, social_posts.compartilhamentos),
      salvamentos = coalesce(excluded.salvamentos, social_posts.salvamentos), seguidores_ganhos = coalesce(excluded.seguidores_ganhos, social_posts.seguidores_ganhos),
      atualizado_em = now();
  end loop;
  return jsonb_build_object('novos', n_novos, 'atualizados', n_atual, 'ligados', social_vincular_auto(p_ws));
end $$;

-- ---------- ligar posts aos conteúdos da Máquina pela data ----------
-- Liga só quando não há dúvida: no dia (fuso de São Paulo) existe exatamente 1 post sem ligação e exatamente 1 conteúdo
-- com Instagram nos canais, data de publicação nesse dia e ainda sem post ligado. O resto fica para ligar na tela.
create or replace function public.social_vincular_auto(p_ws uuid) returns int
language plpgsql security definer set search_path = public as $$
declare n int := 0; r record;
begin
  if auth.uid() is not null and not perm(p_ws, 'editar', array['mkt']) then raise exception 'Sem permissão para editar o conteúdo deste cliente'; end if;
  for r in
    with p as (select id, (publicado_em at time zone 'America/Sao_Paulo')::date as dia from social_posts
               where workspace_id = p_ws and rede = 'instagram' and conteudo_id is null and publicado_em is not null),
         c as (select c.id, c.data_publicacao as dia from conteudos c where c.workspace_id = p_ws and 'instagram' = any (c.canais)
               and c.data_publicacao is not null and c.status in ('agendado', 'publicado')
               and not exists (select 1 from social_posts s where s.conteudo_id = c.id)),
         pd as (select dia, min(id::text)::uuid as post from p group by dia having count(*) = 1),
         cd as (select dia, min(id::text)::uuid as cont from c group by dia having count(*) = 1)
    select pd.post, cd.cont from pd join cd using (dia)
  loop
    update social_posts set conteudo_id = r.cont, vinculo = 'automatico' where id = r.post and conteudo_id is null;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------- o dashboard ----------
-- Posts do período (Meta conectada, importados e publicações registradas na Máquina que não estão em nenhum post),
-- totais, período anterior de mesmo tamanho e série por dia da conta. Nada é estimado: campo sem dado vem nulo.
create or replace function public.instagram_dashboard(p_ws uuid, p_ini date, p_fim date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare dias int := p_fim - p_ini + 1; a_ini date := p_ini - (p_fim - p_ini + 1); a_fim date := p_ini - 1; r jsonb;
begin
  if auth.uid() is not null and not perm(p_ws, 'ler', array['mkt', 'adm']) then raise exception 'Sem acesso ao conteúdo deste cliente'; end if;
  if p_fim < p_ini then raise exception 'Período inválido'; end if;
  if dias > 400 then raise exception 'Use um período de até 400 dias'; end if;
  with base as (
    select s.id::text as id, case when s.conta_id is null then 'importado' else 'meta' end as fonte, s.tipo, s.legenda, s.url, s.miniatura,
           (s.publicado_em at time zone 'America/Sao_Paulo') as quando, s.alcance, s.impressoes, s.visualizacoes, s.curtidas, s.comentarios,
           s.compartilhamentos, s.salvamentos, s.seguidores_ganhos, coalesce(s.conteudo_id, cp.conteudo_id) as conteudo_id, s.vinculo
    from social_posts s left join conteudo_publicacoes cp on cp.id = s.conteudo_publicacao_id
    where s.workspace_id = p_ws and s.rede = 'instagram' and s.publicado_em is not null
    union all
    select 'pub:' || p.id, 'maquina', c.formato, null, p.url, null, p.data_publicacao::timestamp, p.alcance, p.impressoes, p.visualizacoes, p.curtidas, p.comentarios,
           p.compartilhamentos, p.salvamentos, p.seguidores_ganhos, p.conteudo_id, 'manual'
    from conteudo_publicacoes p join conteudos c on c.id = p.conteudo_id
    where p.workspace_id = p_ws and p.canal = 'instagram' and p.status = 'publicada' and p.data_publicacao is not null
      and not exists (select 1 from social_posts s where s.workspace_id = p_ws and (s.conteudo_publicacao_id = p.id or s.conteudo_id = p.conteudo_id))
  ), b as (
    select base.*, base.quando::date as dia,
           coalesce(curtidas, 0) + coalesce(comentarios, 0) + coalesce(compartilhamentos, 0) + coalesce(salvamentos, 0) as interacoes
    from base
  ), per as (select * from b where dia between p_ini and p_fim), ant as (select * from b where dia between a_ini and a_fim),
  conta as (  -- conta conectada primeiro; sem ela, a conta digitada/importada na Máquina
    select d.data, sum(d.seguidores) as seguidores, sum(d.alcance) as alcance, sum(d.visitas_perfil) as visitas, sum(d.seguidores_ganhos) as ganhos, 'meta' as fonte
    from social_perfis_dia d join conexao_contas cc on cc.id = d.conta_id and cc.tipo = 'instagram'
    where d.workspace_id = p_ws and d.data between a_ini and p_fim group by d.data
    union all
    select x.data, x.seguidores, x.alcance, x.visitas_perfil, null, 'maquina' from conteudo_conta_dia x
    where x.workspace_id = p_ws and x.canal = 'instagram' and x.data between a_ini and p_fim
      and not exists (select 1 from social_perfis_dia d join conexao_contas cc on cc.id = d.conta_id and cc.tipo = 'instagram' where d.workspace_id = p_ws and d.data = x.data)
  ),
  tot as (
    select 'per' as k, count(*) as posts, sum(alcance) as alcance, sum(visualizacoes) as visualizacoes, sum(interacoes) as interacoes,
           sum(salvamentos) as salvamentos, sum(compartilhamentos) as compartilhamentos, sum(comentarios) as comentarios,
           round(sum(interacoes) filter (where alcance > 0)::numeric / nullif(sum(alcance) filter (where alcance > 0), 0), 4) as engajamento
    from per
    union all
    select 'ant', count(*), sum(alcance), sum(visualizacoes), sum(interacoes), sum(salvamentos), sum(compartilhamentos), sum(comentarios),
           round(sum(interacoes) filter (where alcance > 0)::numeric / nullif(sum(alcance) filter (where alcance > 0), 0), 4)
    from ant
  )
  select jsonb_build_object(
    'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim, 'anterior_ini', a_ini, 'anterior_fim', a_fim),
    'fontes', jsonb_build_object('meta', (select count(*) from per where fonte = 'meta'), 'importado', (select count(*) from per where fonte = 'importado'),
                                 'maquina', (select count(*) from per where fonte = 'maquina'), 'conta', (select max(fonte) from conta where data between p_ini and p_fim)),
    'totais', (select to_jsonb(t) - 'k' from tot t where k = 'per'),
    'anterior', (select to_jsonb(t) - 'k' from tot t where k = 'ant'),
    'seguidores', jsonb_build_object(
      'fim', (select seguidores from conta where data between p_ini and p_fim and seguidores is not null order by data desc limit 1),
      'inicio', (select seguidores from conta where data between p_ini and p_fim and seguidores is not null order by data limit 1),
      'antes', (select seguidores from conta where data < p_ini and seguidores is not null order by data desc limit 1),
      'alcance_conta', (select sum(alcance) from conta where data between p_ini and p_fim),
      'visitas', (select sum(visitas) from conta where data between p_ini and p_fim)),
    'serie', coalesce((select jsonb_agg(jsonb_build_object('dia', g.d::date,
        'alcance_conta', (select sum(alcance) from conta where data = g.d::date), 'seguidores', (select max(seguidores) from conta where data = g.d::date),
        'posts', (select count(*) from per where dia = g.d::date), 'interacoes', (select sum(interacoes) from per where dia = g.d::date),
        'alcance_posts', (select sum(alcance) from per where dia = g.d::date)) order by g.d)
      from generate_series(p_ini, p_fim, interval '1 day') g(d)), '[]'),
    'posts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'fonte', p.fonte, 'tipo', p.tipo, 'legenda', left(p.legenda, 400), 'url', p.url, 'miniatura', p.miniatura,
        'quando', p.quando, 'dia', p.dia, 'alcance', p.alcance, 'impressoes', p.impressoes, 'visualizacoes', p.visualizacoes, 'curtidas', p.curtidas,
        'comentarios', p.comentarios, 'compartilhamentos', p.compartilhamentos, 'salvamentos', p.salvamentos, 'seguidores_ganhos', p.seguidores_ganhos,
        'interacoes', p.interacoes, 'engajamento', round(p.interacoes::numeric / nullif(p.alcance, 0), 4), 'conteudo_id', p.conteudo_id, 'vinculo', p.vinculo,
        'titulo', c.titulo, 'territorio', l.nome, 'territorio_cor', l.cor, 'frente', t.nome, 'formato', f.nome, 'quadro', q.nome, 'destino', c.destino, 'tags', c.tags,
        'midia', c.formato, 'score', c.score_total) order by p.quando desc)
      from per p left join conteudos c on c.id = p.conteudo_id left join conteudo_temas t on t.id = c.tema_id left join conteudo_linhas l on l.id = t.linha_id
      left join conteudo_formatos f on f.id = c.formato_id left join conteudo_formatos q on q.id = c.quadro_id), '[]')
  ) into r;
  return r;
end $$;

revoke execute on function public.social_importar_posts(uuid, jsonb), public.social_vincular_auto(uuid), public.instagram_dashboard(uuid, date, date) from public, anon;
grant execute on function public.social_importar_posts(uuid, jsonb), public.social_vincular_auto(uuid), public.instagram_dashboard(uuid, date, date) to authenticated;
