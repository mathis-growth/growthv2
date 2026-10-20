-- Alcance (para a frequência) e ângulo do criativo; a view ganha as duas colunas no fim.
alter table metricas_anuncio_dia add column alcance int check (alcance >= 0);
alter table anuncios add column angulo text;

create or replace view v_trafego_anuncio_dia as
 WITH base AS (
         SELECT a_1.id AS anuncio_id, a_1.workspace_id, cc_1.utm_campaign, a_1.utm_content
           FROM anuncios a_1 JOIN campanha_canais cc_1 ON cc_1.id = a_1.campanha_canal_id
        ), lead_dia AS (
         SELECT b.anuncio_id, (p.criado_em AT TIME ZONE 'America/Sao_Paulo'::text)::date AS data,
            count(*) AS leads, count(*) FILTER (WHERE p.qualificacao = 'qualificado'::text) AS qualificados
           FROM base b JOIN pessoas p ON p.workspace_id = b.workspace_id AND p.utm_campaign = b.utm_campaign AND p.utm_content = b.utm_content
          GROUP BY b.anuncio_id, ((p.criado_em AT TIME ZONE 'America/Sao_Paulo'::text)::date)
        ), venda_dia AS (
         SELECT b.anuncio_id, (v_1.data_venda AT TIME ZONE 'America/Sao_Paulo'::text)::date AS data,
            count(*) AS vendas, sum(v_1.valor_bruto) AS receita, count(DISTINCT v_1.pessoa_id) AS clientes
           FROM base b JOIN pessoas p ON p.workspace_id = b.workspace_id AND p.utm_campaign = b.utm_campaign AND p.utm_content = b.utm_content
             JOIN vendas v_1 ON v_1.pessoa_id = p.id AND v_1.status = 'aprovada'::text
          GROUP BY b.anuncio_id, ((v_1.data_venda AT TIME ZONE 'America/Sao_Paulo'::text)::date)
        ), chaves AS (
         SELECT metricas_anuncio_dia.anuncio_id, metricas_anuncio_dia.data FROM metricas_anuncio_dia
        UNION SELECT lead_dia.anuncio_id, lead_dia.data FROM lead_dia
        UNION SELECT venda_dia.anuncio_id, venda_dia.data FROM venda_dia
        )
 SELECT k.anuncio_id, a.workspace_id, a.nome AS anuncio, a.utm_content, a.imagem_url, cc.canal, cc.utm_campaign, cc.campanha_id,
    c.nome AS campanha, k.data,
    COALESCE(m.impressoes, 0) AS impressoes, COALESCE(m.cliques, 0) AS cliques, COALESCE(m.custo, 0::numeric) AS custo,
    COALESCE(m.visualizacoes_pagina, 0) AS visualizacoes_pagina, COALESCE(l.leads, 0::bigint) AS leads,
    COALESCE(l.qualificados, 0::bigint) AS qualificados, COALESCE(v.vendas, 0::bigint) AS vendas,
    COALESCE(v.receita, 0::numeric) AS receita, COALESCE(v.clientes, 0::bigint) AS clientes,
    COALESCE(m.alcance, 0) AS alcance, a.angulo
   FROM chaves k
     JOIN anuncios a ON a.id = k.anuncio_id
     JOIN campanha_canais cc ON cc.id = a.campanha_canal_id
     JOIN campanhas c ON c.id = cc.campanha_id
     LEFT JOIN metricas_anuncio_dia m ON m.anuncio_id = k.anuncio_id AND m.data = k.data
     LEFT JOIN lead_dia l ON l.anuncio_id = k.anuncio_id AND l.data = k.data
     LEFT JOIN venda_dia v ON v.anuncio_id = k.anuncio_id AND v.data = k.data;
-- CREATE OR REPLACE VIEW zera as opções da view: sem isto a RLS das tabelas não valeria para quem consulta.
alter view v_trafego_anuncio_dia set (security_invoker = true);
-- Nenhuma view fica aberta ao papel anônimo.
do $$
declare v text;
begin
  for v in select viewname from pg_views where schemaname = 'public' loop
    execute format('revoke all on public.%I from anon', v);
  end loop;
end $$;
