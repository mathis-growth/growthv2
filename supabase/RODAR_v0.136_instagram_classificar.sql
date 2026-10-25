-- v0.136 — Dashboard do Instagram: classificar o post direto (frente e formato, sem precisar de um conteúdo da Máquina),
-- números da conta com novos seguidores e comparação com o período anterior. Pode ser rodado de novo sem erro.
alter table public.social_posts add column if not exists tema_id uuid references public.conteudo_temas(id) on delete set null;
alter table public.social_posts add column if not exists formato_id uuid references public.conteudo_formatos(id) on delete set null;
grant update (tema_id, formato_id) on public.social_posts to authenticated;

create or replace function public.social_posts_valida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.conteudo_id is not null and not exists (select 1 from conteudos where id = new.conteudo_id and workspace_id = new.workspace_id) then
    raise exception 'O conteúdo precisa ser deste cliente'; end if;
  if new.tema_id is not null and not exists (select 1 from conteudo_temas where id = new.tema_id and workspace_id = new.workspace_id) then
    raise exception 'A frente precisa ser deste cliente'; end if;
  if new.formato_id is not null and not exists (select 1 from conteudo_formatos where id = new.formato_id and workspace_id = new.workspace_id and grupo = 'formato') then
    raise exception 'O formato precisa ser deste cliente'; end if;
  if new.conteudo_id is null then new.vinculo := null; end if;
  return new;
end $$;
revoke execute on function public.social_posts_valida() from public, anon, authenticated;

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
           s.compartilhamentos, s.salvamentos, s.seguidores_ganhos, coalesce(s.conteudo_id, cp.conteudo_id) as conteudo_id, s.vinculo, s.tema_id as post_tema, s.formato_id as post_formato
    from social_posts s left join conteudo_publicacoes cp on cp.id = s.conteudo_publicacao_id
    where s.workspace_id = p_ws and s.rede = 'instagram' and s.publicado_em is not null
    union all
    select 'pub:' || p.id, 'maquina', c.formato, null, p.url, null, p.data_publicacao::timestamp, p.alcance, p.impressoes, p.visualizacoes, p.curtidas, p.comentarios,
           p.compartilhamentos, p.salvamentos, p.seguidores_ganhos, p.conteudo_id, 'manual', null::uuid, null::uuid
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
      'visitas', (select sum(visitas) from conta where data between p_ini and p_fim),
      'ganhos', (select sum(ganhos) from conta where data between p_ini and p_fim),
      'ganhos_antes', (select sum(ganhos) from conta where data between a_ini and a_fim),
      'alcance_conta_antes', (select sum(alcance) from conta where data between a_ini and a_fim)),
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
        'midia', c.formato, 'score', c.score_total, 'post_tema', p.post_tema, 'post_formato', p.post_formato) order by p.quando desc)
      from per p left join conteudos c on c.id = p.conteudo_id left join conteudo_temas t on t.id = coalesce(c.tema_id, p.post_tema) left join conteudo_linhas l on l.id = t.linha_id
      left join conteudo_formatos f on f.id = coalesce(c.formato_id, p.post_formato) left join conteudo_formatos q on q.id = c.quadro_id), '[]')
  ) into r;
  return r;
end $$;


notify pgrst, 'reload schema';
