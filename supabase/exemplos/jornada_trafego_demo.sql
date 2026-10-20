-- =====================================================================
-- GROWTHS — dados fictícios de jornada de funil e tráfego pago
-- (usa o workspace "Growths — Demo"; rode DEPOIS do seed.sql e ANTES de simular_vendas.sql)
-- =====================================================================
do $$
declare
  ws uuid; camp uuid; curso uuid; fun uuid; grupo uuid; api uuid;
  e_entrada uuid; e_grupo uuid; e_live uuid; e_replay uuid;
  cg uuid; cm uuid; i int; d int; a int; imp int; clq int; r record;
  nomes text[] := array['Alice','Bernardo','Camila','Davi','Elisa','Fabio','Giovana','Heitor','Iara','Julio','Kelly','Leandro'];
begin
  select id into ws from workspaces where nome = 'Growths — Demo';
  select id into camp from campanhas where workspace_id = ws and nome = 'Lançamento Out/26';
  select id into curso from produtos where workspace_id = ws and nome = 'Curso Exemplo';
  select id into cg from campanha_canais where workspace_id = ws and canal = 'google_ads';
  select id into cm from campanha_canais where workspace_id = ws and canal = 'meta_ads';

  -- 24 leads fictícios vindos do Meta Ads
  for i in 1..24 loop
    insert into pessoas (workspace_id, nome, email, telefone, utm_source, utm_medium, utm_campaign, utm_content,
                         utm_id, fbclid, pagina_origem, criado_em)
    values (ws, nomes[1 + i % 12] || ' Meta ' || i, 'meta.lead' || i || '@exemplo.com.br',
            '55119' || lpad(((i * 4157311) % 100000000)::text, 8, '0'),
            'facebook', 'paid', 'lancamento-out26-meta',
            case when i % 2 = 0 then 'meta-video-lp' else 'meta-estatico' end,
            'camp-meta-001', 'fb.1.' || i, 'https://exemplo.com.br/lp-lancamento',
            timestamptz '2026-10-01 09:30:00-03' + (i * interval '4.6 hours'));
  end loop;

  -- Funil de lançamento com etapas e listas
  insert into funis (workspace_id, nome, tipo, produto_id, descricao)
  values (ws, 'Lançamento Out/26', 'lancamento', curso, 'Cadastro, grupo de WhatsApp, aula ao vivo, replay e carrinho.')
  returning id into fun;
  insert into funil_etapas (workspace_id, funil_id, nome, ordem, tipo) values
    (ws, fun, 'Cadastrou na página', 1, 'entrada'), (ws, fun, 'Entrou no grupo', 2, 'meio'),
    (ws, fun, 'Assistiu à aula ao vivo', 3, 'meio'), (ws, fun, 'Assistiu ao replay', 4, 'meio'),
    (ws, fun, 'Carrinho aberto', 5, 'meio'), (ws, fun, 'Comprou', 6, 'compra');
  select id into e_entrada from funil_etapas where funil_id = fun and tipo = 'entrada';
  select id into e_grupo from funil_etapas where funil_id = fun and nome = 'Entrou no grupo';
  select id into e_live from funil_etapas where funil_id = fun and nome = 'Assistiu à aula ao vivo';
  select id into e_replay from funil_etapas where funil_id = fun and nome = 'Assistiu ao replay';
  insert into funil_listas (workspace_id, funil_id, nome, tipo, reinicia_jornada, etapa_ao_entrar_id)
  values (ws, fun, 'Grupo de WhatsApp', 'grupo', true, e_grupo) returning id into grupo;
  insert into funil_listas (workspace_id, funil_id, nome, tipo, lista_pai_id)
  values (ws, fun, 'Lista de transmissão (API)', 'api', grupo) returning id into api;

  -- ligar a campanha ao funil matricula todos os leads dela
  update campanhas set funil_id = fun where id = camp;

  -- movimentos de exemplo
  for r in select pf.pessoa_id, row_number() over (order by p.criado_em) as rn
           from pessoa_funil pf join pessoas p on p.id = pf.pessoa_id where pf.funil_id = fun loop
    if r.rn % 10 <> 0 then perform entrar_na_lista(r.pessoa_id, grupo); end if;
    if r.rn % 3 = 0 and r.rn % 10 <> 0 then perform entrar_na_lista(r.pessoa_id, api); end if;
    if r.rn % 9 = 0 and r.rn % 10 <> 0 then perform sair_da_lista(r.pessoa_id, api); end if;
    if r.rn % 13 = 0 then perform sair_da_lista(r.pessoa_id, grupo); end if;
    if r.rn % 4 = 0 and r.rn % 10 <> 0 and r.rn % 13 <> 0 then
      update pessoa_funil set etapa_id = e_live where pessoa_id = r.pessoa_id and funil_id = fun;
    elsif r.rn % 7 = 0 and r.rn % 10 <> 0 and r.rn % 13 <> 0 then
      update pessoa_funil set etapa_id = e_replay where pessoa_id = r.pessoa_id and funil_id = fun;
    end if;
  end loop;

  -- Anúncios (criativos) e métricas diárias de 1 a 5 de outubro
  insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content) values
    (ws, cg, 'Vídeo depoimento', 'anuncio-a-video'), (ws, cg, 'Imagem oferta', 'anuncio-b-imagem'),
    (ws, cg, 'Carrossel método', 'anuncio-c-carrossel'),
    (ws, cm, 'Reels 15 segundos', 'meta-video-lp'), (ws, cm, 'Estático prova social', 'meta-estatico');

  for r in select an.id, an.utm_content, row_number() over (partition by an.campanha_canal_id order by an.utm_content) as k
           from anuncios an where an.workspace_id = ws loop
    for d in 0..4 loop
      a := r.k::int;
      imp := 8000 + 700 * d + 900 * a;
      clq := round(imp * (0.014 + 0.003 * a));
      insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina)
      values (ws, r.id, date '2026-10-01' + d, imp, clq,
              round(clq * (case when r.utm_content like 'meta%' then 0.70 else 1.20 end + 0.15 * a), 2),
              round(clq * (0.62 + 0.08 * a)));
    end loop;
  end loop;
end $$;

select count(*) as pessoas, (select count(*) from pessoa_funil) as no_funil,
       (select count(*) from pessoa_lista where ativo) as listas_ativas,
       (select count(*) from metricas_anuncio_dia) as metricas
from pessoas;
