-- ===== Parte 2: Lançamento "Formação Fluência · Semana da Fluência" (captação em andamento) =====
create function pg_temp._blk(p_ws uuid, p_funil uuid, p_tipo text, p_nome text, p_ordem int, p_n int) returns void language plpgsql as $f$
declare bid uuid := gen_random_uuid(); fase_ text; m record; j int := 0;
begin
  fase_ := case p_tipo when 'grupo' then 'aquecimento' when 'aula' then 'aquecimento' when 'checkout' then 'conversao' else 'aquisicao' end;
  insert into estrategia_blocos (id, workspace_id, funil_id, ordem, fase, tipo, nome, origem_ref) values (bid, p_ws, p_funil, p_ordem, fase_, p_tipo, p_nome, null);
  -- mesmas métricas do catálogo de blocos do Growths (EST_BLOCOS)
  for m in select * from (values
    ('trafego', 'cliques', 'Cliques no link', 'principal', 'anuncios', 'cliques', 'numero', null, 'Anúncios (importação)'),
    ('trafego', 'investimento', 'Investimento', 'diagnostico', 'anuncios', 'investimento', 'brl', 'investimento', 'Anúncios (importação)'),
    ('trafego', 'impressoes', 'Impressões', 'diagnostico', 'anuncios', 'impressoes', 'numero', null, 'Anúncios (importação)'),
    ('trafego', 'visitas', 'Visitas à página', 'diagnostico', 'anuncios', 'visitas', 'numero', null, 'Anúncios (importação)'),
    ('captura', 'leads', 'Leads', 'principal', 'leads', null, 'numero', null, 'Growths (leads da campanha)'),
    ('captura', 'visitas_pagina', 'Visitas à página', 'diagnostico', 'manual', null, 'numero', null, 'Analytics'),
    ('grupo', 'entradas', 'Entradas no grupo', 'principal', 'lista', null, 'numero', null, 'Growths (lista) / Sendflow'),
    ('grupo', 'saidas', 'Saídas do grupo', 'diagnostico', 'manual', null, 'numero', null, 'Sendflow'),
    ('grupo', 'cliques_links', 'Cliques nos links enviados', 'diagnostico', 'manual', null, 'numero', null, 'Sendflow'),
    ('aula', 'presentes', 'Presentes', 'principal', 'video', 'presentes', 'numero', null, 'Growths (presenças)'),
    ('aula', 'pico', 'Pico simultâneo', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'tempo_medio', 'Tempo médio assistido (min)', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'ate_oferta', 'Ficaram até a oferta', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma da transmissão'),
    ('aula', 'cliques_oferta', 'Cliques no link da oferta', 'diagnostico', 'manual', null, 'numero', null, 'Growths (UTM)'),
    ('checkout', 'vendas', 'Vendas aprovadas', 'principal', 'vendas', 'clientes', 'numero', 'clientes_novos', 'Growths (vendas)'),
    ('checkout', 'receita', 'Receita', 'diagnostico', 'vendas', 'receita', 'brl', 'receita', 'Growths (vendas)'),
    ('checkout', 'checkouts', 'Checkouts iniciados', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma de venda'),
    ('checkout', 'abandonos', 'Abandonos', 'diagnostico', 'manual', null, 'numero', null, 'Plataforma de venda')
  ) x(tipo, k, nome, papel, origem, metrica, un, conta, fonte) where x.tipo = p_tipo loop
    insert into estrategia_etapas (workspace_id, funil_id, bloco_id, papel, fonte, ordem, fase, chave, nome, unidade, origem, metrica, origem_ref, conta_como, taxa_esperada)
    values (p_ws, p_funil, bid, m.papel, m.fonte, p_ordem * 10 + j, fase_, p_tipo || p_n || '_' || m.k, p_nome || ' · ' || m.nome, m.un, m.origem, m.metrica, null, m.conta, null);
    j := j + 1;
  end loop;
end $f$;

do $$
declare
  ws uuid := (select id from _lfa_ids where k = 'ws'); hot uuid := (select id from _lfa_ids where k = 'hot');
  cc_prod uuid := (select id from _lfa_ids where k = 'cc_prod'); cc_meta uuid := (select id from _lfa_ids where k = 'cc_meta'); cc_goo uuid := (select id from _lfa_ids where k = 'cc_goo');
  p_ment uuid := (select id from _lfa_ids where k = 'p_ment');
  p_form uuid; p_kit uuid; fn uuid; lista uuid; c uuid; cc_tt uuid; pc_tt uuid; r record; x record; a record; i int; n int := 0; pid uuid; em timestamptz;
  nomes text[] := array['Ana','Beatriz','Camila','Daniela','Eduarda','Fernanda','Gabriela','Helena','Isabela','Juliana','Larissa','Mariana','Natália','Patrícia','Renata','Sabrina','Tatiane','Vanessa','Aline','Bianca',
                        'André','Bruno','Caio','Diego','Eduardo','Felipe','Gustavo','Henrique','Igor','João','Leonardo','Marcelo','Matheus','Pedro','Rafael','Rodrigo','Thiago','Vinícius','Lucas','Gabriel'];
  sob text[] := array['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira','Lima','Gomes','Costa','Ribeiro','Martins','Carvalho','Almeida','Lopes','Soares','Fernandes','Vieira','Barbosa',
                      'Rocha','Dias','Nascimento','Andrade','Moreira','Nunes','Marques','Machado','Mendes','Freitas'];
  ddd int[] := array[11,11,11,21,21,31,35,41,47,51,61,62,71,81,85,19,27,48];
begin
  perform setseed(0.7);
  -- produtos e plataforma
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id, extras) values (ws, 'Formação Fluência Aurora', 'formacao-fluencia', 'curso', false, 1997, cc_prod, '{"mc_custo_pct": 12}') returning id into p_form;
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, preco, centro_custo_id) values (ws, 'Kit de Conversação (order bump)', 'kit-conversacao', 'digital', false, 67, cc_prod) returning id into p_kit;
  insert into produto_plataforma (workspace_id, produto_id, plataforma_id, id_externo) values (ws, p_form, hot, 'AUR-FLUENCIA'), (ws, p_kit, hot, 'AUR-KIT');
  -- TikTok Ads: conta de mídia (6.1.03) e centro de custo, como os de Meta e Google
  insert into plano_contas select (jsonb_populate_record(null::plano_contas, to_jsonb(pc) || jsonb_build_object('id', gen_random_uuid(), 'codigo', '6.1.03', 'nome', 'Mídia paga – TikTok Ads'))).*
    from plano_contas pc where pc.workspace_id = ws and pc.codigo = '6.1.02' returning id into pc_tt;
  insert into centros_custo select (jsonb_populate_record(null::centros_custo, to_jsonb(cc) || jsonb_build_object('id', gen_random_uuid(), 'codigo', 'TIKTOK', 'nome', 'Aquisição – TikTok Ads'))).*
    from centros_custo cc where cc.id = cc_meta returning id into cc_tt;

  -- estratégia "Lançamento clássico" com os blocos do modelo pronto (tráfego, captura, grupo, 3 aulas, checkout)
  insert into funis (workspace_id, nome, tipo, produto_id, descricao, modelo_pronto, ativo)
  values (ws, 'Lançamento clássico · Semana da Fluência', 'lancamento', p_form, 'Captação paga e orgânica para o grupo VIP, 3 aulas ao vivo e carrinho de 7 dias.', 'lancamento', true) returning id into fn;
  perform pg_temp._blk(ws, fn, 'trafego', 'Tráfego pago', 10, 1);
  perform pg_temp._blk(ws, fn, 'captura', 'Página de captura', 20, 1);
  perform pg_temp._blk(ws, fn, 'grupo', 'Grupo de WhatsApp', 130, 1);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 1', 140, 1);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 2', 150, 2);
  perform pg_temp._blk(ws, fn, 'aula', 'Aula 3', 160, 3);
  perform pg_temp._blk(ws, fn, 'checkout', 'Checkout', 270, 1);
  insert into funil_listas (workspace_id, funil_id, nome, tipo) values (ws, fn, 'Grupo VIP · Semana da Fluência', 'grupo') returning id into lista;

  -- campanha
  insert into campanhas (workspace_id, nome, status, modelo, tipo_midia, data_inicio, data_fim, data_carrinho_abre, data_carrinho_fecha, produto_id, orcamento_total,
                         meta_leads, meta_vendas, meta_receita, meta_cac, meta_cpl, meta_taxa_lead_venda, projeto_auto, fases, observacoes)
  values (ws, 'Lançamento Formação Fluência · Nov/26', 'ativa', 'lancamento', 'hibrida', '2026-10-01', '2026-11-15', '2026-11-03', '2026-11-09', p_form, 20000,
          5000, 75, 150000, 270, 4.00, 1.5, false,
          '{"aquisicao": {"ini": "2026-10-01", "fim": "2026-10-26"}, "aquecimento": {"ini": "2026-10-27", "fim": "2026-11-02"}, "conversao": {"ini": "2026-11-03", "fim": "2026-11-09"}}',
          'Lançamento clássico. Captação de 01 a 26/10 com R$ 20 mil em tráfego (Meta 75%, Google 15%, TikTok 10%) + Instagram orgânico e e-mail para a base. '
          || 'Semana da Fluência: aulas ao vivo em 27, 29 e 31/10, às 20h, no YouTube. Carrinho de 03 a 09/11: Formação Fluência a R$ 1.997 (12x), order bump Kit de Conversação (R$ 67) e upsell da Mentoria. '
          || 'Meta: 5.000 leads (CPL pago de R$ 4,84), 75 vendas (1,5% dos leads), R$ 150 mil, CAC de mídia até R$ 270.')
  returning id into c;
  perform campanha_aplicar_estrategia(c, fn, false);
  insert into campanha_estrategias (workspace_id, campanha_id, funil_id, principal) values (ws, c, fn, true) on conflict do nothing;
  update campanha_blocos set origem_ref = lista where campanha_id = c and tipo = 'grupo';
  update campanha_etapas set origem_ref = lista where campanha_id = c and chave = 'grupo1_entradas';
  -- taxas esperadas entre as etapas principais (sobre a etapa anterior)
  update campanha_etapas e set taxa_esperada = t.v from (values ('captura1_leads', 0.33), ('grupo1_entradas', 0.66), ('aula1_presentes', 0.40), ('aula2_presentes', 0.72), ('aula3_presentes', 0.85), ('checkout1_vendas', 0.08)) t(k, v)
   where e.campanha_id = c and e.chave = t.k;
  insert into campanha_ofertas (workspace_id, campanha_id, produto_id, nome, papel, preco, ordem, taxa_exposicao, taxa_aceite) values
    (ws, c, p_form, 'Formação Fluência Aurora (12x de R$ 199,70)', 'principal', 1997, 1, null, null),
    (ws, c, p_kit, 'Kit de Conversação', 'order_bump', 67, 2, 1, 0.30),
    (ws, c, p_ment, 'Mentoria de Conversação (upsell)', 'upsell', 3000, 3, 1, 0.06);

  -- campanhas de anúncio (canal) com metas; orgânicos sem verba
  for r in select * from _lfa_camp loop
    insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento, meta_leads, meta_vendas, meta_cac, meta_cpl, temperatura, tipo, funil_id, observacoes)
    values (ws, c, r.canal, r.utm, r.orc, r.meta, r.vendas, round(r.orc / r.vendas, 2), round(r.orc / r.meta, 2), r.temp, 'pago', fn,
            r.nome || case r.k when 'int' then ' · público: interesse em inglês, intercâmbio, carreira (25–45)' when 'lal' then ' · público: semelhante 1–3% de alunos e compradores'
              when 'adv' then ' · público aberto, otimização por lead' when 'rmk' then ' · público: visitantes da página, engajados no Instagram e vídeo 50% (30 dias)'
              when 'yt' then ' · in-stream pulável, palavras-chave e afinidade' when 'src' then ' · termos: curso de inglês online, inglês para adultos' else ' · Spark Ads com vídeos da professora' end);
  end loop;
  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento, meta_leads, meta_vendas, temperatura, tipo, funil_id, observacoes) values
    (ws, c, 'organico', 'lfa26-instagram-organico', null, 450, 6, 'quente', 'organico', fn, 'Instagram orgânico · link da bio, stories e 2 lives por semana'),
    (ws, c, 'email', 'lfa26-email-base', null, 420, 6, 'quente', 'organico', fn, 'E-mail para a base de alunos e leads · 1 envio por semana');
  -- nome do canal: o utm_campaign identifica; o nome legível fica nas observações. Anúncios:
  for a in select d.*, cc.id ccid, k.temp, k.canal from _lfa_ad d join _lfa_camp k on k.k = d.camp join campanha_canais cc on cc.utm_campaign = k.utm and cc.workspace_id = ws order by d.cod loop
    insert into anuncios (workspace_id, campanha_canal_id, nome, utm_content, imagem_url, id_externo, ativo, angulo, temperatura)
    values (ws, a.ccid, a.nome, a.utm_content, a.img, case a.canal when 'meta_ads' then '1202' when 'google_ads' then '7001' else '7389' end || lpad((random() * 1e8)::bigint::text, 9, '0'),
            a.fim is null, a.angulo, a.temp);
    insert into campanha_links (workspace_id, campanha_canal_id, nome, url_destino, utm_source, utm_medium, utm_content, angulo, anuncio_id)
    values (ws, a.ccid, a.nome, 'https://escolaaurora.test/semana-da-fluencia', case a.canal when 'meta_ads' then 'facebook' when 'google_ads' then 'google' else 'tiktok' end,
            case a.canal when 'google_ads' then 'cpc' else 'paid_social' end, a.utm_content, a.angulo, (select id from anuncios where campanha_canal_id = a.ccid and utm_content = a.utm_content));
  end loop;

  -- métricas diárias dos anúncios (como vindas da integração com Meta, Google e TikTok, 01 a 16/10)
  insert into metricas_anuncio_dia (workspace_id, anuncio_id, data, impressoes, cliques, custo, visualizacoes_pagina, alcance, origem)
  select ws, an.id, m.data, m.imp, m.cli, m.custo, m.vis, m.alc, 'integracao'
    from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp join campanha_canais cc on cc.utm_campaign = k.utm and cc.workspace_id = ws
    join anuncios an on an.campanha_canal_id = cc.id and an.utm_content = d.utm_content;

  -- leads dos anúncios: pessoa nova entra pelo cadastro; 5% já estavam na base e entram por um toque de captura (como registrar_captura faz)
  for x in select m.data, m.leads, d.utm_content, k.utm, k.canal from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp where m.leads > 0 order by m.data, d.cod loop
    for i in 1..x.leads loop
      em := x.data + time '07:00' + (power(random(), 0.75) * interval '16 hours 50 minutes');
      if random() < 0.05 then
        select p.id into pid from pessoas p where p.workspace_id = ws and p.criado_em < '2026-10-01' and not exists (select 1 from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id) order by random() limit 1;
        insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
        values (ws, pid, em, 'captura', x.canal, c, 'Cadastro na campanha', case x.canal when 'meta_ads' then 'facebook' when 'google_ads' then 'google' else 'tiktok' end,
                case x.canal when 'google_ads' then 'cpc' else 'paid_social' end, x.utm, x.utm_content, 'captura', 'captura', gen_random_uuid());
      else
        n := n + 1;
        insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, canal_origem, campanha_id, criado_em)
        values (ws, nomes[1 + (random() * 39)::int] || ' ' || sob[1 + (random() * 29)::int], 'fluencia' || n || '@email.test',
                '(' || ddd[1 + (random() * 17)::int] || ') 9' || lpad((70000000 + n * 7)::text, 8, '0'), 'lead',
                case x.canal when 'meta_ads' then (array['facebook','instagram'])[1 + (random() < 0.62)::int] when 'google_ads' then 'google' else 'tiktok' end,
                case x.canal when 'google_ads' then 'cpc' else 'paid_social' end, x.utm, x.utm_content, x.canal, c, em);
      end if;
    end loop;
  end loop;
  -- orgânicos: Instagram (85% pessoas novas) e e-mail para a base (80% já estavam na base)
  for x in select * from _lfa_org order by data loop
    for i in 1..(x.ig + x.email) loop
      em := x.data + time '08:00' + (random() * interval '15 hours');
      if (i <= x.ig and random() < 0.15) or (i > x.ig and random() < 0.80) then
        select p.id into pid from pessoas p where p.workspace_id = ws and p.criado_em < '2026-10-01' and not exists (select 1 from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id) order by random() limit 1;
        insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_source, utm_medium, utm_campaign, utm_content, origem, ref_tabela, ref_id)
        values (ws, pid, em, 'captura', case when i <= x.ig then 'organico' else 'email' end, c, 'Cadastro na campanha', case when i <= x.ig then 'instagram' else 'email' end,
                case when i <= x.ig then 'organic' else 'email' end, case when i <= x.ig then 'lfa26-instagram-organico' else 'lfa26-email-base' end,
                case when i > x.ig then 'email-' || to_char(x.data - ((extract(isodow from x.data)::int + 3) % 7), 'DDMM') when x.data in ('2026-10-06', '2026-10-13') and random() < 0.6 then 'live' when random() < 0.55 then 'bio' else 'stories' end,
                'captura', 'captura', gen_random_uuid());
      else
        n := n + 1;
        insert into pessoas (workspace_id, nome, email, telefone, status_funil, utm_source, utm_medium, utm_campaign, utm_content, canal_origem, campanha_id, criado_em)
        values (ws, nomes[1 + (random() * 39)::int] || ' ' || sob[1 + (random() * 29)::int], 'fluencia' || n || '@email.test',
                '(' || ddd[1 + (random() * 17)::int] || ') 9' || lpad((70000000 + n * 7)::text, 8, '0'), 'lead',
                case when i <= x.ig then 'instagram' else 'email' end, case when i <= x.ig then 'organic' else 'email' end,
                case when i <= x.ig then 'lfa26-instagram-organico' else 'lfa26-email-base' end,
                case when i > x.ig then 'email-' || to_char(x.data - ((extract(isodow from x.data)::int + 3) % 7), 'DDMM') when x.data in ('2026-10-06', '2026-10-13') and random() < 0.6 then 'live' when random() < 0.55 then 'bio' else 'stories' end,
                case when i <= x.ig then 'organico' else 'email' end, c, em);
      end if;
    end loop;
  end loop;
  -- cadastros repetidos: 4% tentam de novo nos dias seguintes
  for x in select cp.pessoa_id, cp.entrou_em, cp.canal, cp.utm_campaign, cp.utm_content from campanha_participacoes cp where cp.campanha_id = c and random() < 0.04 loop
    em := x.entrou_em + (1 + random() * 4) * interval '1 day';
    if em < '2026-10-17 00:00-03' then
      insert into pessoa_toques (workspace_id, pessoa_id, em, tipo, canal, campanha_id, descricao, utm_campaign, utm_content, origem, ref_tabela, ref_id)
      values (ws, x.pessoa_id, em, 'captura', x.canal, c, 'Nova tentativa de cadastro (repetida)', x.utm_campaign, x.utm_content, 'captura', 'captura', gen_random_uuid());
    end if;
  end loop;
  -- grupo VIP: 66% entram minutos depois do cadastro; 3% saem
  insert into pessoa_lista (workspace_id, pessoa_id, lista_id, ativo, entrou_em, saiu_em)
  select ws, cp.pessoa_id, lista, s.sai is null, cp.entrou_em + (2 + random() * 90) * interval '1 minute', s.sai
    from campanha_participacoes cp cross join lateral (select case when random() < 0.045 then least(cp.entrou_em + (1 + random() * 6) * interval '1 day', timestamptz '2026-10-16 22:00-03') end sai) s
   where cp.campanha_id = c and random() < 0.66;
  -- pesquisa de qualificação (respondida por 70%): 38% qualificados, 32% não qualificados
  update pessoas p set pesquisa_respondida_em = cp.entrou_em + interval '3 minutes', pontuacao_qualificacao = (random() * 100)::int,
         respostas_pesquisa = jsonb_build_object('nivel', (array['iniciante','básico','intermediário','avançado'])[1 + (random() * 3)::int],
                                                  'objetivo', (array['trabalho','viagem','intercâmbio','concurso','conversar com estrangeiros'])[1 + (random() * 4)::int],
                                                  'investe', (array['até R$ 100/mês','R$ 100 a 200/mês','mais de R$ 200/mês'])[1 + (random() * 2)::int])
    from campanha_participacoes cp where cp.campanha_id = c and cp.pessoa_id = p.id and p.criado_em >= '2026-10-01' and random() < 0.70;
  update pessoas p set qualificacao = case when p.pontuacao_qualificacao >= 46 then 'qualificado' else 'nao_qualificado' end
   where p.workspace_id = ws and p.campanha_id = c and p.pesquisa_respondida_em is not null;
  update pessoas p set qualificacao = 'pendente' where p.workspace_id = ws and p.campanha_id = c and p.pesquisa_respondida_em is null;

  -- valores digitados por dia (Analytics e Sendflow): visitas da página de captura, saídas e cliques no grupo
  insert into campanha_etapa_valores (workspace_id, campanha_etapa_id, data, valor, origem)
  select ws, e.id, v.data, v.valor, case when e.chave like 'grupo%' then 'sendflow' else 'importacao' end
    from campanha_etapas e join (
      select 'captura1_visitas_pagina' k, d.data, (coalesce(sum(m.vis), 0) + round(o.ig * 2.7 + o.email * 1.9))::numeric valor from _lfa_org o join (select distinct data from _lfa_dia) d on d.data = o.data left join _lfa_dia m on m.data = o.data group by d.data, o.ig, o.email
      union all select 'grupo1_saidas', (pl.saiu_em at time zone 'America/Sao_Paulo')::date, count(*) from pessoa_lista pl where pl.lista_id = lista and pl.saiu_em is not null group by 2
      union all select 'grupo1_cliques_links', g.d, round(g.n * (0.12 + random() * 0.08)) from (select (pl.entrou_em at time zone 'America/Sao_Paulo')::date d, count(*) over (order by (pl.entrou_em at time zone 'America/Sao_Paulo')::date) n from pessoa_lista pl where pl.lista_id = lista) g group by g.d, g.n
    ) v on v.k = e.chave where e.campanha_id = c
  on conflict (campanha_etapa_id, data) do nothing;

  -- metas por tipo (aba Captação e metas): campanha, canais, público e ritmo por semana
  insert into campanha_metas (workspace_id, campanha_id, tipo, valor, fase, canal, temperatura, data_ini, data_fim, observacao) values
    (ws, c, 'investimento', 20000, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Só tráfego pago da captação'),
    (ws, c, 'leads', 5000, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Pagos 4.130 + orgânicos 870'),
    (ws, c, 'cpl', 4.00, 'aquisicao', null, null, '2026-10-01', '2026-10-26', 'Investimento ÷ todos os leads (com orgânicos)'),
    (ws, c, 'leads_qualificados', 1900, 'aquisicao', null, null, '2026-10-01', '2026-10-26', '38% dos leads com pesquisa qualificada'),
    (ws, c, 'investimento', 15000, 'aquisicao', 'meta_ads', null, null, null, '75% da verba'),
    (ws, c, 'leads', 3300, 'aquisicao', 'meta_ads', null, null, null, null),
    (ws, c, 'cpl', 4.55, 'aquisicao', 'meta_ads', null, null, null, null),
    (ws, c, 'investimento', 3000, 'aquisicao', 'google_ads', null, null, null, 'YouTube R$ 2.000 + Pesquisa R$ 1.000'),
    (ws, c, 'leads', 430, 'aquisicao', 'google_ads', null, null, null, null),
    (ws, c, 'cpl', 6.98, 'aquisicao', 'google_ads', null, null, null, null),
    (ws, c, 'investimento', 2000, 'aquisicao', 'tiktok_ads', null, null, null, 'Teste de canal: 10% da verba'),
    (ws, c, 'leads', 400, 'aquisicao', 'tiktok_ads', null, null, null, null),
    (ws, c, 'cpl', 5.00, 'aquisicao', 'tiktok_ads', null, null, null, null),
    (ws, c, 'leads', 450, 'aquisicao', 'organico', null, null, null, 'Instagram: bio, stories e lives'),
    (ws, c, 'leads', 420, 'aquisicao', 'email', null, null, null, 'Base de alunos e leads'),
    (ws, c, 'leads', 3460, 'aquisicao', null, 'frio', null, null, 'Interesses, lookalike, Advantage+, YouTube e TikTok'),
    (ws, c, 'leads', 1540, 'aquisicao', null, 'quente', null, null, 'Remarketing, pesquisa, Instagram e e-mail'),
    (ws, c, 'leads', 1000, 'aquisicao', null, null, '2026-10-01', '2026-10-07', 'Semana 1 (verba em 70%, aprendizado)'),
    (ws, c, 'leads', 1350, 'aquisicao', null, null, '2026-10-08', '2026-10-14', 'Semana 2 (verba cheia, criativos novos)'),
    (ws, c, 'leads', 1450, 'aquisicao', null, null, '2026-10-15', '2026-10-21', 'Semana 3 (escala dos vencedores)'),
    (ws, c, 'leads', 1200, 'aquisicao', null, null, '2026-10-22', '2026-10-26', 'Semana 4 (últimos 5 dias, remarketing forte)'),
    (ws, c, 'vendas', 75, 'conversao', null, null, '2026-11-03', '2026-11-09', null),
    (ws, c, 'conversao', 1.5, 'conversao', null, null, null, null, 'Vendas ÷ leads'),
    (ws, c, 'receita', 150000, 'conversao', null, null, '2026-11-03', '2026-11-09', 'Formação + order bump + upsell'),
    (ws, c, 'ticket_medio', 2000, 'conversao', null, null, null, null, null),
    (ws, c, 'cac', 270, null, null, null, null, null, 'CAC de mídia'),
    (ws, c, 'roas', 7.5, null, null, null, null, null, null);

  -- faturas de mídia do lançamento (gasto de 01 a 16/10, a pagar no cartão em 10/11)
  insert into contas_pagar (workspace_id, descricao, valor, competencia, vencimento, conta_despesa_id, centro_custo_id, campanha_id)
  select ws, f.nome || ' — Lançamento Fluência (01 a 16/10)', sum(m.custo), '2026-10-01', '2026-11-10', f.pc, f.cc, c
    from _lfa_dia m join _lfa_ad d on d.cod = m.cod join _lfa_camp k on k.k = d.camp
    join (values ('meta_ads', 'Meta Ads', (select id from plano_contas where workspace_id = ws and codigo = '6.1.02'), cc_meta),
                 ('google_ads', 'Google Ads', (select id from plano_contas where workspace_id = ws and codigo = '6.1.01'), cc_goo),
                 ('tiktok_ads', 'TikTok Ads', pc_tt, cc_tt)) f(canal, nome, pc, cc) on f.canal = k.canal
   group by f.nome, f.pc, f.cc;
end $$;
