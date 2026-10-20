-- =====================================================================
-- GROWTHS — dados iniciais de demonstração (TODOS FICTÍCIOS)
-- Cria o workspace "Growths — Demo" com plano de contas, regras de
-- contabilização, Kanbans, Hotmart (taxas/prazos de EXEMPLO), imposto de
-- EXEMPLO, 2 produtos, 1 campanha com metas por canal (Google e Meta)
-- e 40 leads vindos da campanha do Google.
--
-- Depois de rodar, vincule o seu login ao workspace (troque o e-mail):
--   select vincular_usuario(
--     (select id from workspaces where nome = 'Growths — Demo'), 'seu@email.com');
-- =====================================================================

do $$
declare
  ws uuid;
  camp uuid;
  prod_curso uuid;
  prod_saas uuid;
  hotmart uuid;
  conta_banco uuid;
  cc_produto uuid;
  i int;
  primeiro text;
  sobrenome text;
  nomes text[] := array['Ana','Bruno','Carla','Diego','Eduarda','Felipe','Gabriela','Henrique','Isabela','João',
                        'Karina','Lucas','Mariana','Nicolas','Olívia','Paulo','Rafaela','Samuel','Tatiane','Vitor'];
  sobrenomes text[] := array['Silva','Souza','Oliveira','Santos','Pereira','Lima','Costa','Ribeiro','Almeida','Carvalho'];
  termos text[] := array['curso online marketing digital','como vender infoproduto','lançamento digital passo a passo',
                         'mentoria growth','estratégia de lançamento','como criar curso online'];
  anuncios text[] := array['anuncio-a-video','anuncio-b-imagem','anuncio-c-carrossel'];
begin
  ws := provisionar_workspace('Growths — Demo');
  select id into cc_produto from centros_custo where workspace_id = ws and codigo = 'PRODUTO';

  -- Imposto (exemplo editável)
  insert into impostos_config (workspace_id, nome, aliquota_percentual, base)
  values (ws, 'Impostos sobre vendas (exemplo)', 6, 'valor_bruto');

  -- Conta bancária padrão, ligada à conta contábil 1.1.01
  insert into contas_bancarias (workspace_id, nome, banco, saldo_inicial, conta_contabil_id, padrao)
  values (ws, 'Conta principal', 'Banco exemplo', 0,
          (select id from plano_contas where workspace_id = ws and codigo = '1.1.01'), true)
  returning id into conta_banco;

  -- Plataforma de venda com taxas e prazos por forma de pagamento (EXEMPLO)
  insert into plataformas_venda (workspace_id, nome, taxa_percentual, taxa_fixa, observacoes)
  values (ws, 'Hotmart', 9.9, 1.00, 'Valores de exemplo: ajuste conforme o seu contrato.')
  returning id into hotmart;

  insert into plataforma_formas_pagamento (workspace_id, plataforma_id, forma_pagamento, prazo_recebimento_dias) values
    (ws, hotmart, 'pix', 0),
    (ws, hotmart, 'cartao_credito', 30),
    (ws, hotmart, 'boleto', 3);

  -- Produtos
  insert into produtos (workspace_id, nome, tag, tipo, recorrente, periodicidade, preco, centro_custo_id)
  values (ws, 'Curso Exemplo', 'curso-exemplo', 'curso', false, null, 497.00, cc_produto)
  returning id into prod_curso;

  insert into produtos (workspace_id, nome, tag, tipo, recorrente, periodicidade, preco, centro_custo_id)
  values (ws, 'Assinatura SaaS Exemplo', 'saas-exemplo', 'assinatura', true, 'mensal', 97.00, cc_produto)
  returning id into prod_saas;

  insert into produto_plataforma (workspace_id, produto_id, plataforma_id, id_externo) values
    (ws, prod_curso, hotmart, 'HOT-0001'),
    (ws, prod_saas, hotmart, 'HOT-0002');

  -- Campanha com metas e metas por canal
  insert into campanhas (workspace_id, nome, status, data_inicio, data_fim, produto_id,
                         orcamento_total, meta_leads, meta_vendas, meta_taxa_lead_venda, meta_receita, meta_cac)
  values (ws, 'Lançamento Out/26', 'ativa', '2026-10-01', '2026-10-31', prod_curso,
          15000, 1200, 60, 5.0, 29820, 250)
  returning id into camp;

  insert into campanha_canais (workspace_id, campanha_id, canal, utm_campaign, orcamento,
                               percentual_meta_leads, meta_leads, meta_vendas, meta_cac) values
    (ws, camp, 'google_ads', 'lancamento-out26-google', 9000, 60, 720, 36, 250),
    (ws, camp, 'meta_ads',   'lancamento-out26-meta',   6000, 40, 480, 24, 250);

  -- 40 leads da campanha do Google (fictícios). A campanha, o canal e a etapa
  -- do Kanban são preenchidos automaticamente pela utm_campaign.
  for i in 1..40 loop
    primeiro := nomes[1 + (i * 7) % 20];
    sobrenome := sobrenomes[1 + (i * 3) % 10];
    insert into pessoas (workspace_id, nome, email, telefone,
                         utm_source, utm_medium, utm_campaign, utm_content, utm_term,
                         pagina_origem, criado_em)
    values (ws,
            primeiro || ' ' || sobrenome,
            translate(lower(primeiro || '.' || sobrenome || i), 'áàâãéêíóôõúç', 'aaaaeeiooouc') || '@exemplo.com.br',
            '55119' || lpad(((i * 7919321) % 100000000)::text, 8, '0'),
            'google', 'cpc', 'lancamento-out26-google',
            anuncios[1 + i % 3],
            termos[1 + i % 6],
            'https://exemplo.com.br/lp-lancamento',
            timestamptz '2026-10-01 08:00:00-03' + (i * interval '2.7 hours'));
  end loop;
end $$;

-- Conferência rápida
select p.nome, p.email, p.status_funil, p.qualificacao, p.canal_origem, p.utm_campaign, e.nome as etapa
from pessoas p left join etapas_kanban e on e.id = p.etapa_kanban_id
order by p.criado_em limit 10;
