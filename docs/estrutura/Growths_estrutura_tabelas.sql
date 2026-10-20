-- Growths — estrutura de todas as tabelas do banco (schema public), 17/10/2026.

-- Conferido contra o banco de produção (projeto yngyghlyonybvfvjcmxl): mesmas 134 tabelas e mesmas colunas.

-- Só estrutura, sem dados, sem funções, gatilhos ou políticas de acesso. Serve para comparar com outro banco.

-- Tabelas do Supabase Auth (auth.users) não estão aqui; workspace_membros.user_id aponta para auth.users.
-- Alguns valores padrão usam auth.uid() (do Supabase). Para rodar num Postgres comum, crie antes:
--   create schema auth; create table auth.users (id uuid primary key);
--   create function auth.uid() returns uuid language sql as 'select null::uuid';

-- ======================================================================
-- FUNÇÕES USADAS EM COLUNAS CALCULADAS (telefone_norm, email_norm, nome_norm)
-- ======================================================================

CREATE OR REPLACE FUNCTION public.norm_email(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select nullif(lower(trim(coalesce(t, ''))), '');
$function$
;
CREATE OR REPLACE FUNCTION public.norm_fone(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when length(d) in (10, 11) then '55' || d when length(d) between 12 and 13 then d else null end
  from (select regexp_replace(coalesce(t, ''), '\D', '', 'g') as d) x;
$function$
;
CREATE OR REPLACE FUNCTION public.norm_nome(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select nullif(lower(regexp_replace(trim(coalesce(t, '')), '\s+', ' ', 'g')), '');
$function$
;


-- ======================================================================
-- TABELAS (colunas, tipos, obrigatórios, padrões e regras CHECK)
-- ======================================================================

CREATE TABLE public.acesso_telas (
    tela text NOT NULL,
    modulo text NOT NULL,
    nome text NOT NULL,
    grupo text,
    ordem integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.aluno_historico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    aluno_id uuid NOT NULL,
    pessoa_id uuid,
    tipo text NOT NULL,
    etapa_kanban_id uuid,
    em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT aluno_historico_tipo_check CHECK ((tipo = ANY (ARRAY['etapa'::text, 'saida'::text, 'volta'::text])))
);

CREATE TABLE public.alunos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    venda_id uuid,
    tag text NOT NULL,
    etapa_kanban_id uuid,
    status text DEFAULT 'ativo'::text NOT NULL,
    entrou_em timestamp with time zone DEFAULT now() NOT NULL,
    saiu_em timestamp with time zone,
    responsavel_cs_id uuid,
    contrato_id uuid,
    origem text DEFAULT 'venda'::text NOT NULL,
    CONSTRAINT alunos_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'inativo'::text, 'cancelado'::text])))
);

CREATE TABLE public.anuncios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_canal_id uuid NOT NULL,
    nome text NOT NULL,
    utm_content text NOT NULL,
    imagem_url text,
    id_externo text,
    ativo boolean DEFAULT true NOT NULL,
    angulo text,
    temperatura text,
    CONSTRAINT anuncios_temperatura_check CHECK (((temperatura IS NULL) OR (temperatura = ANY (ARRAY['frio'::text, 'quente'::text]))))
);

CREATE TABLE public.auditoria (
    id bigint NOT NULL,
    workspace_id uuid,
    tabela text NOT NULL,
    registro_id uuid,
    acao text NOT NULL,
    campos text[],
    antes jsonb,
    depois jsonb,
    usuario_id uuid,
    usuario_email text,
    origem text NOT NULL,
    em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auditoria_acao_check CHECK ((acao = ANY (ARRAY['inclusao'::text, 'alteracao'::text, 'exclusao'::text])))
);

CREATE TABLE public.benchmarks_mercado (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    metrica text NOT NULL,
    valor numeric(14,4) NOT NULL,
    fonte text,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT benchmarks_mercado_fonte_check CHECK (((fonte IS NULL) OR (char_length(fonte) <= 200))),
    CONSTRAINT benchmarks_mercado_metrica_check CHECK ((metrica = ANY (ARRAY['cpl'::text, 'cac'::text, 'conv'::text, 'ticket'::text, 'roas'::text, 'margem'::text, 'leads'::text, 'receita'::text]))),
    CONSTRAINT benchmarks_mercado_valor_check CHECK ((valor >= (0)::numeric))
);

CREATE TABLE public.campanha_blocos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    bloco_origem_id uuid,
    ordem integer DEFAULT 10 NOT NULL,
    fase text DEFAULT 'aquisicao'::text NOT NULL,
    tipo text NOT NULL,
    nome text NOT NULL,
    origem_ref uuid,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanha_blocos_fase_check CHECK ((fase = ANY (ARRAY['aquisicao'::text, 'aquecimento'::text, 'conversao'::text, 'retencao'::text])))
);

CREATE TABLE public.campanha_calculos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid,
    nome text NOT NULL,
    premissas jsonb DEFAULT '{}'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanha_calculos_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 120))),
    CONSTRAINT campanha_calculos_premissas_check CHECK ((jsonb_typeof(premissas) = 'object'::text))
);

CREATE TABLE public.campanha_canais (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    canal text NOT NULL,
    utm_campaign text NOT NULL,
    orcamento numeric(14,2),
    percentual_meta_leads numeric(6,3),
    meta_leads integer,
    meta_vendas integer,
    meta_cac numeric(12,2),
    meta_cpl numeric(12,2),
    temperatura text,
    tipo text,
    funil_id uuid,
    custo_producao numeric(12,2),
    observacoes text,
    CONSTRAINT campanha_canais_custo_producao_check CHECK (((custo_producao IS NULL) OR (custo_producao >= (0)::numeric))),
    CONSTRAINT campanha_canais_meta_cpl_check CHECK (((meta_cpl IS NULL) OR (meta_cpl >= (0)::numeric))),
    CONSTRAINT campanha_canais_temperatura_check CHECK (((temperatura IS NULL) OR (temperatura = ANY (ARRAY['frio'::text, 'quente'::text])))),
    CONSTRAINT campanha_canais_tipo_check CHECK (((tipo IS NULL) OR (tipo = ANY (ARRAY['pago'::text, 'organico'::text]))))
);

CREATE TABLE public.campanha_debriefing (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    resultado text,
    funcionou text,
    nao_funcionou text,
    aprendizados text,
    proximos_passos text,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.campanha_estrategias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    principal boolean DEFAULT false NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.campanha_etapa_valores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_etapa_id uuid NOT NULL,
    data date NOT NULL,
    valor numeric NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    disponibilidade text DEFAULT 'completo'::text NOT NULL,
    atualizado_na_origem timestamp with time zone,
    CONSTRAINT campanha_etapa_valores_disp_check CHECK ((disponibilidade = ANY (ARRAY['completo'::text, 'parcial'::text, 'indisponivel'::text]))),
    CONSTRAINT campanha_etapa_valores_origem_check CHECK ((origem = ANY (ARRAY['manual'::text, 'sendflow'::text, 'importacao'::text]))),
    CONSTRAINT campanha_etapa_valores_valor_check CHECK ((valor >= (0)::numeric))
);

CREATE TABLE public.campanha_etapas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    fase text DEFAULT 'aquisicao'::text NOT NULL,
    chave text NOT NULL,
    nome text NOT NULL,
    unidade text DEFAULT 'numero'::text NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    metrica text,
    origem_ref uuid,
    conta_como text,
    taxa_esperada numeric,
    ativa boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    bloco_id uuid,
    papel text,
    fonte text,
    CONSTRAINT campanha_etapas_chave_check CHECK ((chave ~ '^[a-z0-9_]{1,40}$'::text)),
    CONSTRAINT campanha_etapas_conta_como_check CHECK ((conta_como = ANY (ARRAY['investimento'::text, 'clientes_novos'::text, 'upgrades'::text, 'renovados'::text, 'receita'::text]))),
    CONSTRAINT campanha_etapas_fase_check CHECK ((fase = ANY (ARRAY['aquisicao'::text, 'aquecimento'::text, 'conversao'::text, 'retencao'::text]))),
    CONSTRAINT campanha_etapas_metrica_check CHECK (((metrica IS NULL) OR (char_length(metrica) <= 30))),
    CONSTRAINT campanha_etapas_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 80))),
    CONSTRAINT campanha_etapas_origem_check CHECK ((origem = ANY (ARRAY['anuncios'::text, 'leads'::text, 'etapa_funil'::text, 'lista'::text, 'video'::text, 'vendas'::text, 'disparo'::text, 'manual'::text]))),
    CONSTRAINT campanha_etapas_papel_chk CHECK (((papel IS NULL) OR (papel = ANY (ARRAY['principal'::text, 'diagnostico'::text])))),
    CONSTRAINT campanha_etapas_taxa_esperada_check CHECK (((taxa_esperada IS NULL) OR (taxa_esperada >= (0)::numeric))),
    CONSTRAINT campanha_etapas_unidade_check CHECK ((unidade = ANY (ARRAY['numero'::text, 'brl'::text, 'pct'::text])))
);

CREATE TABLE public.campanha_fechamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    fechado_em timestamp with time zone DEFAULT now() NOT NULL,
    fechado_por uuid DEFAULT auth.uid(),
    periodo_ini date,
    periodo_fim date,
    snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    versao integer,
    status text DEFAULT 'oficial'::text NOT NULL,
    motivo text,
    substitui_id uuid,
    corte_em timestamp with time zone,
    qualidade jsonb,
    fase text,
    CONSTRAINT campanha_fechamentos_status_check CHECK ((status = ANY (ARRAY['oficial'::text, 'substituido'::text])))
);

CREATE TABLE public.campanha_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_canal_id uuid NOT NULL,
    nome text NOT NULL,
    url_destino text NOT NULL,
    utm_source text NOT NULL,
    utm_medium text NOT NULL,
    utm_content text NOT NULL,
    utm_term text,
    angulo text,
    anuncio_id uuid,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanha_links_url_destino_check CHECK ((url_destino ~* '^https?://'::text))
);

CREATE TABLE public.campanha_melhorias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    titulo text NOT NULL,
    descricao text,
    origem text DEFAULT 'manual'::text NOT NULL,
    sprint text,
    status text DEFAULT 'a_fazer'::text NOT NULL,
    prazo date,
    responsavel text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanha_melhorias_origem_check CHECK ((origem = ANY (ARRAY['manual'::text, 'regra'::text]))),
    CONSTRAINT campanha_melhorias_status_check CHECK ((status = ANY (ARRAY['a_fazer'::text, 'em_andamento'::text, 'feito'::text, 'descartado'::text]))),
    CONSTRAINT campanha_melhorias_titulo_check CHECK ((length(btrim(titulo)) > 0))
);

CREATE TABLE public.campanha_metas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    tipo text NOT NULL,
    valor numeric NOT NULL,
    fase text,
    canal text,
    temperatura text,
    segmento text,
    data_ini date,
    data_fim date,
    observacao text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campanha_metas_segmento_check CHECK (((segmento IS NULL) OR (segmento = ANY (ARRAY['aluno'::text, 'nao_aluno'::text, 'cliente'::text])))),
    CONSTRAINT campanha_metas_temperatura_check CHECK (((temperatura IS NULL) OR (temperatura = ANY (ARRAY['frio'::text, 'quente'::text])))),
    CONSTRAINT campanha_metas_tipo_check CHECK ((tipo = ANY (ARRAY['investimento'::text, 'leads'::text, 'leads_qualificados'::text, 'vendas'::text, 'conversao'::text, 'receita'::text, 'ticket_medio'::text, 'cpl'::text, 'cac'::text, 'roas'::text, 'impressoes'::text, 'cliques'::text]))),
    CONSTRAINT campanha_metas_valor_check CHECK ((valor >= (0)::numeric))
);

CREATE TABLE public.campanha_metas_mes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    mes date NOT NULL,
    meta_leads integer,
    meta_vendas integer,
    CONSTRAINT campanha_metas_mes_mes_check CHECK ((mes = (date_trunc('month'::text, (mes)::timestamp with time zone))::date)),
    CONSTRAINT campanha_metas_mes_meta_leads_check CHECK (((meta_leads IS NULL) OR (meta_leads >= 0))),
    CONSTRAINT campanha_metas_mes_meta_vendas_check CHECK (((meta_vendas IS NULL) OR (meta_vendas >= 0)))
);

CREATE TABLE public.campanha_mix (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    vendas_mes integer NOT NULL,
    CONSTRAINT campanha_mix_vendas_mes_check CHECK ((vendas_mes > 0))
);

CREATE TABLE public.campanha_ofertas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    oferta_id uuid,
    nome text NOT NULL,
    papel text DEFAULT 'principal'::text NOT NULL,
    preco numeric(12,2) NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    oferta_versao integer,
    pai_id uuid,
    condicao text DEFAULT 'sempre'::text NOT NULL,
    etapa_exibicao text,
    elegibilidade text,
    gatilho text,
    taxa_exposicao numeric,
    taxa_aceite numeric,
    CONSTRAINT campanha_ofertas_condicao_check CHECK ((condicao = ANY (ARRAY['sempre'::text, 'aceitou'::text, 'recusou'::text]))),
    CONSTRAINT campanha_ofertas_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 120))),
    CONSTRAINT campanha_ofertas_papel_check CHECK ((papel = ANY (ARRAY['principal'::text, 'upsell'::text, 'order_bump'::text, 'cross_sell'::text, 'downsell'::text]))),
    CONSTRAINT campanha_ofertas_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT campanha_ofertas_taxa_aceite_check CHECK (((taxa_aceite IS NULL) OR ((taxa_aceite >= (0)::numeric) AND (taxa_aceite <= (1)::numeric)))),
    CONSTRAINT campanha_ofertas_taxa_exposicao_check CHECK (((taxa_exposicao IS NULL) OR ((taxa_exposicao >= (0)::numeric) AND (taxa_exposicao <= (1)::numeric))))
);

CREATE TABLE public.campanha_participacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    entrou_em timestamp with time zone NOT NULL,
    era_aluno boolean DEFAULT false NOT NULL,
    era_cliente boolean DEFAULT false NOT NULL,
    canal text,
    campanha_canal_id uuid,
    temperatura text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    tentativas integer DEFAULT 1 NOT NULL,
    ultima_tentativa_em timestamp with time zone
);

CREATE TABLE public.campanhas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    status text DEFAULT 'planejada'::text NOT NULL,
    data_inicio date,
    data_fim date,
    produto_id uuid,
    orcamento_total numeric(14,2),
    meta_leads integer,
    meta_vendas integer,
    meta_taxa_lead_venda numeric(6,3),
    meta_receita numeric(14,2),
    meta_cac numeric(12,2),
    observacoes text,
    funil_id uuid,
    modelo text DEFAULT 'lancamento'::text NOT NULL,
    data_carrinho_abre date,
    data_carrinho_fecha date,
    meta_id uuid,
    meta_leads_mes integer,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    meta_cpl numeric(12,2),
    fases jsonb DEFAULT '{}'::jsonb NOT NULL,
    projeto_auto boolean DEFAULT true NOT NULL,
    projeto_modelo_id uuid,
    tipo_midia text DEFAULT 'hibrida'::text NOT NULL,
    CONSTRAINT campanhas_extras_check CHECK ((jsonb_typeof(extras) = 'object'::text)),
    CONSTRAINT campanhas_fases_check CHECK ((jsonb_typeof(fases) = 'object'::text)),
    CONSTRAINT campanhas_meta_cpl_check CHECK (((meta_cpl IS NULL) OR (meta_cpl >= (0)::numeric))),
    CONSTRAINT campanhas_meta_leads_mes_check CHECK (((meta_leads_mes IS NULL) OR (meta_leads_mes > 0))),
    CONSTRAINT campanhas_modelo_check CHECK ((modelo = ANY (ARRAY['lancamento'::text, 'perpetuo'::text]))),
    CONSTRAINT campanhas_perpetuo_sem_fim CHECK (((modelo <> 'perpetuo'::text) OR (data_fim IS NULL))),
    CONSTRAINT campanhas_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'planejada'::text, 'ativa'::text, 'pausada'::text, 'finalizada'::text]))),
    CONSTRAINT campanhas_tipo_midia_check CHECK ((tipo_midia = ANY (ARRAY['hibrida'::text, 'paga'::text, 'organica'::text])))
);

CREATE TABLE public.campos_personalizados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    entidade text NOT NULL,
    chave text NOT NULL,
    rotulo text NOT NULL,
    tipo text DEFAULT 'text'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT campos_personalizados_chave_check CHECK ((chave ~ '^[a-z][a-z0-9_]{1,40}$'::text)),
    CONSTRAINT campos_personalizados_entidade_check CHECK ((entidade = ANY (ARRAY['pessoas'::text, 'produtos'::text, 'fornecedores'::text, 'campanhas'::text, 'vendas'::text]))),
    CONSTRAINT campos_personalizados_rotulo_check CHECK (((char_length(rotulo) >= 1) AND (char_length(rotulo) <= 80))),
    CONSTRAINT campos_personalizados_tipo_check CHECK ((tipo = ANY (ARRAY['text'::text, 'number'::text, 'date'::text])))
);

CREATE TABLE public.canais (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    codigo text NOT NULL,
    nome text NOT NULL,
    utm_source text,
    utm_medium text,
    ativo boolean DEFAULT true NOT NULL,
    tipo text DEFAULT 'organico'::text,
    CONSTRAINT canais_tipo_check CHECK ((tipo = ANY (ARRAY['pago'::text, 'organico'::text])))
);

CREATE TABLE public.centros_custo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    codigo text NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    entra_no_cac boolean DEFAULT true NOT NULL
);

CREATE TABLE public.chaves_api (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    escopo text DEFAULT 'ideias'::text NOT NULL,
    prefixo text NOT NULL,
    hash text NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    ultimo_uso timestamp with time zone,
    usos integer DEFAULT 0 NOT NULL,
    revogada_em timestamp with time zone,
    CONSTRAINT chaves_api_escopo_check CHECK ((escopo = 'ideias'::text)),
    CONSTRAINT chaves_api_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 80)))
);

CREATE TABLE public.checkout_abandonos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    campanha_id uuid,
    pessoa_id uuid,
    produto_id uuid,
    valor numeric,
    abandonado_em timestamp with time zone NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    id_externo text,
    recuperado_venda_id uuid,
    recuperado_em timestamp with time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.contas_bancarias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    banco text,
    saldo_inicial numeric(14,2) DEFAULT 0 NOT NULL,
    conta_contabil_id uuid NOT NULL,
    padrao boolean DEFAULT false NOT NULL,
    ativa boolean DEFAULT true NOT NULL,
    tipo text DEFAULT 'conta'::text NOT NULL,
    dia_vencimento integer,
    CONSTRAINT contas_bancarias_dia_venc_check CHECK (((dia_vencimento IS NULL) OR ((dia_vencimento >= 1) AND (dia_vencimento <= 31)))),
    CONSTRAINT contas_bancarias_tipo_check CHECK ((tipo = ANY (ARRAY['conta'::text, 'cartao'::text])))
);

CREATE TABLE public.contas_pagar (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    fornecedor_id uuid,
    descricao text NOT NULL,
    valor numeric(14,2) NOT NULL,
    competencia date,
    vencimento date NOT NULL,
    conta_despesa_id uuid NOT NULL,
    centro_custo_id uuid,
    campanha_id uuid,
    campanha_canal_id uuid,
    status text DEFAULT 'previsto'::text NOT NULL,
    data_pagamento date,
    conta_bancaria_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    rateio_regra_id uuid,
    forma_pagamento_id uuid,
    estimativa boolean DEFAULT false NOT NULL,
    provisionada boolean DEFAULT false NOT NULL,
    substituida_por uuid,
    recorrencia_id uuid,
    saldo_de uuid,
    CONSTRAINT contas_pagar_status_check CHECK ((status = ANY (ARRAY['previsto'::text, 'pago'::text, 'cancelado'::text]))),
    CONSTRAINT contas_pagar_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.contas_receber (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    venda_id uuid,
    valor numeric(14,2) NOT NULL,
    vencimento date NOT NULL,
    status text DEFAULT 'previsto'::text NOT NULL,
    data_recebimento date,
    conta_bancaria_id uuid,
    contrato_id uuid,
    parcela integer,
    descricao text,
    substituida_por uuid,
    desconto numeric(14,2) DEFAULT 0 NOT NULL,
    desconto_motivo text,
    desconto_em date,
    conta_receita_id uuid,
    CONSTRAINT contas_receber_desconto_check CHECK ((desconto >= (0)::numeric)),
    CONSTRAINT contas_receber_origem_ck CHECK (((venda_id IS NOT NULL) OR (contrato_id IS NOT NULL))),
    CONSTRAINT contas_receber_status_check CHECK ((status = ANY (ARRAY['previsto'::text, 'recebido'::text, 'cancelado'::text, 'estornado'::text])))
);

CREATE TABLE public.conteudo_config (
    workspace_id uuid NOT NULL,
    criterios text[] DEFAULT ARRAY['Aderência à linha editorial'::text, 'Potencial de alcance'::text, 'Potencial de conversão'::text, 'Facilidade de produção'::text, 'Oportunidade e timing'::text] NOT NULL,
    CONSTRAINT conteudo_config_criterios_check CHECK ((cardinality(criterios) = 5))
);

CREATE TABLE public.conteudo_conta_dia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    canal text NOT NULL,
    data date NOT NULL,
    seguidores integer,
    alcance integer,
    impressoes integer,
    visitas_perfil integer,
    cliques_link integer,
    disponibilidade text DEFAULT 'completo'::text NOT NULL,
    atualizado_na_origem timestamp with time zone,
    CONSTRAINT conteudo_conta_dia_alcance_check CHECK ((alcance >= 0)),
    CONSTRAINT conteudo_conta_dia_canal_check CHECK ((canal = ANY (ARRAY['instagram'::text, 'linkedin'::text, 'youtube'::text, 'tiktok'::text, 'facebook'::text, 'x'::text, 'blog'::text, 'email'::text]))),
    CONSTRAINT conteudo_conta_dia_cliques_link_check CHECK ((cliques_link >= 0)),
    CONSTRAINT conteudo_conta_dia_disp_check CHECK ((disponibilidade = ANY (ARRAY['completo'::text, 'parcial'::text, 'indisponivel'::text]))),
    CONSTRAINT conteudo_conta_dia_impressoes_check CHECK ((impressoes >= 0)),
    CONSTRAINT conteudo_conta_dia_seguidores_check CHECK ((seguidores >= 0)),
    CONSTRAINT conteudo_conta_dia_visitas_perfil_check CHECK ((visitas_perfil >= 0))
);

CREATE TABLE public.conteudo_linhas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.conteudo_metas_semanais (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    formato text NOT NULL,
    quantidade integer NOT NULL,
    CONSTRAINT conteudo_metas_semanais_formato_check CHECK ((formato = ANY (ARRAY['video'::text, 'reels'::text, 'carrossel'::text, 'imagem'::text, 'story'::text, 'artigo'::text, 'newsletter'::text, 'live'::text]))),
    CONSTRAINT conteudo_metas_semanais_quantidade_check CHECK ((quantidade >= 0))
);

CREATE TABLE public.conteudo_publicacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    conteudo_id uuid NOT NULL,
    canal text NOT NULL,
    data_publicacao date,
    url text,
    status text DEFAULT 'agendada'::text NOT NULL,
    impressoes integer,
    alcance integer,
    visualizacoes integer,
    curtidas integer,
    comentarios integer,
    compartilhamentos integer,
    salvamentos integer,
    cliques integer,
    seguidores_ganhos integer,
    metricas_em date,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conteudo_publicacoes_alcance_check CHECK ((alcance >= 0)),
    CONSTRAINT conteudo_publicacoes_canal_check CHECK ((canal = ANY (ARRAY['instagram'::text, 'linkedin'::text, 'youtube'::text, 'tiktok'::text, 'facebook'::text, 'x'::text, 'blog'::text, 'email'::text]))),
    CONSTRAINT conteudo_publicacoes_cliques_check CHECK ((cliques >= 0)),
    CONSTRAINT conteudo_publicacoes_comentarios_check CHECK ((comentarios >= 0)),
    CONSTRAINT conteudo_publicacoes_compartilhamentos_check CHECK ((compartilhamentos >= 0)),
    CONSTRAINT conteudo_publicacoes_curtidas_check CHECK ((curtidas >= 0)),
    CONSTRAINT conteudo_publicacoes_impressoes_check CHECK ((impressoes >= 0)),
    CONSTRAINT conteudo_publicacoes_salvamentos_check CHECK ((salvamentos >= 0)),
    CONSTRAINT conteudo_publicacoes_status_check CHECK ((status = ANY (ARRAY['agendada'::text, 'publicada'::text]))),
    CONSTRAINT conteudo_publicacoes_url_check CHECK (((url IS NULL) OR (url ~* '^https?://'::text))),
    CONSTRAINT conteudo_publicacoes_visualizacoes_check CHECK ((visualizacoes >= 0))
);

CREATE TABLE public.conteudo_temas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    linha_id uuid,
    nome text NOT NULL,
    prioridade integer DEFAULT 2 NOT NULL,
    cor text DEFAULT '#0a6b5b'::text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conteudo_temas_cor_check CHECK ((cor ~ '^#[0-9a-fA-F]{6}$'::text)),
    CONSTRAINT conteudo_temas_prioridade_check CHECK (((prioridade >= 1) AND (prioridade <= 3)))
);

CREATE TABLE public.conteudos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    titulo text NOT NULL,
    descricao text,
    tema_id uuid,
    formato text DEFAULT 'carrossel'::text NOT NULL,
    canais text[] DEFAULT '{}'::text[] NOT NULL,
    status text DEFAULT 'ideia'::text NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    fonte_url text,
    copy_url text,
    midia_url text,
    responsavel_id uuid,
    prazo date,
    data_publicacao date,
    publicado_em timestamp with time zone,
    ideia_n1 integer,
    ideia_n2 integer,
    ideia_n3 integer,
    ideia_n4 integer,
    ideia_n5 integer,
    pauta_n1 integer,
    pauta_n2 integer,
    pauta_n3 integer,
    pauta_n4 integer,
    pauta_n5 integer,
    ideia_media numeric(3,1) GENERATED ALWAYS AS (
CASE
    WHEN ((ideia_n1 IS NOT NULL) AND (ideia_n2 IS NOT NULL) AND (ideia_n3 IS NOT NULL) AND (ideia_n4 IS NOT NULL) AND (ideia_n5 IS NOT NULL)) THEN round(((((((ideia_n1 + ideia_n2) + ideia_n3) + ideia_n4) + ideia_n5))::numeric / 5.0), 1)
    ELSE NULL::numeric
END) STORED,
    pauta_media numeric(3,1) GENERATED ALWAYS AS (
CASE
    WHEN ((pauta_n1 IS NOT NULL) AND (pauta_n2 IS NOT NULL) AND (pauta_n3 IS NOT NULL) AND (pauta_n4 IS NOT NULL) AND (pauta_n5 IS NOT NULL)) THEN round(((((((pauta_n1 + pauta_n2) + pauta_n3) + pauta_n4) + pauta_n5))::numeric / 5.0), 1)
    ELSE NULL::numeric
END) STORED,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT conteudos_canais_check CHECK ((canais <@ ARRAY['instagram'::text, 'linkedin'::text, 'youtube'::text, 'tiktok'::text, 'facebook'::text, 'x'::text, 'blog'::text, 'email'::text])),
    CONSTRAINT conteudos_copy_url_check CHECK (((copy_url IS NULL) OR (copy_url ~* '^https?://'::text))),
    CONSTRAINT conteudos_fonte_url_check CHECK (((fonte_url IS NULL) OR (fonte_url ~* '^https?://'::text))),
    CONSTRAINT conteudos_formato_check CHECK ((formato = ANY (ARRAY['video'::text, 'reels'::text, 'carrossel'::text, 'imagem'::text, 'story'::text, 'artigo'::text, 'newsletter'::text, 'live'::text]))),
    CONSTRAINT conteudos_ideia_n1_check CHECK (((ideia_n1 >= 1) AND (ideia_n1 <= 10))),
    CONSTRAINT conteudos_ideia_n2_check CHECK (((ideia_n2 >= 1) AND (ideia_n2 <= 10))),
    CONSTRAINT conteudos_ideia_n3_check CHECK (((ideia_n3 >= 1) AND (ideia_n3 <= 10))),
    CONSTRAINT conteudos_ideia_n4_check CHECK (((ideia_n4 >= 1) AND (ideia_n4 <= 10))),
    CONSTRAINT conteudos_ideia_n5_check CHECK (((ideia_n5 >= 1) AND (ideia_n5 <= 10))),
    CONSTRAINT conteudos_midia_url_check CHECK (((midia_url IS NULL) OR (midia_url ~* '^https?://'::text))),
    CONSTRAINT conteudos_origem_check CHECK ((origem = ANY (ARRAY['manual'::text, 'ia'::text, 'importada'::text]))),
    CONSTRAINT conteudos_pauta_n1_check CHECK (((pauta_n1 >= 1) AND (pauta_n1 <= 10))),
    CONSTRAINT conteudos_pauta_n2_check CHECK (((pauta_n2 >= 1) AND (pauta_n2 <= 10))),
    CONSTRAINT conteudos_pauta_n3_check CHECK (((pauta_n3 >= 1) AND (pauta_n3 <= 10))),
    CONSTRAINT conteudos_pauta_n4_check CHECK (((pauta_n4 >= 1) AND (pauta_n4 <= 10))),
    CONSTRAINT conteudos_pauta_n5_check CHECK (((pauta_n5 >= 1) AND (pauta_n5 <= 10))),
    CONSTRAINT conteudos_status_check CHECK ((status = ANY (ARRAY['ideia'::text, 'pauta'::text, 'producao'::text, 'pronto'::text, 'agendado'::text, 'publicado'::text, 'arquivado'::text])))
);

CREATE TABLE public.contrato_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    contrato_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    quantidade numeric(10,2) DEFAULT 1 NOT NULL,
    valor numeric(14,2) NOT NULL,
    CONSTRAINT contrato_itens_quantidade_check CHECK ((quantidade > (0)::numeric)),
    CONSTRAINT contrato_itens_valor_check CHECK ((valor >= (0)::numeric))
);

CREATE TABLE public.contrato_parcelas_plano (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    contrato_id uuid NOT NULL,
    numero integer NOT NULL,
    valor numeric(14,2) NOT NULL,
    vencimento date NOT NULL,
    CONSTRAINT contrato_parcelas_plano_numero_check CHECK ((numero >= 1)),
    CONSTRAINT contrato_parcelas_plano_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.contratos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    numero integer,
    pessoa_id uuid NOT NULL,
    campanha_id uuid,
    status text DEFAULT 'rascunho'::text NOT NULL,
    data_inicio date NOT NULL,
    data_fim date,
    recorrente boolean DEFAULT false NOT NULL,
    periodicidade text,
    num_parcelas integer DEFAULT 1 NOT NULL,
    primeiro_vencimento date,
    conta_bancaria_id uuid,
    forma_pagamento text,
    acessos text,
    observacoes text,
    ativado_em timestamp with time zone,
    cancelado_em timestamp with time zone,
    criado_por uuid DEFAULT auth.uid(),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    vendedor_id uuid,
    CONSTRAINT contratos_check CHECK ((recorrente = (periodicidade IS NOT NULL))),
    CONSTRAINT contratos_check1 CHECK (((data_fim IS NULL) OR (data_fim >= data_inicio))),
    CONSTRAINT contratos_num_parcelas_check CHECK (((num_parcelas >= 1) AND (num_parcelas <= 120))),
    CONSTRAINT contratos_periodicidade_check CHECK ((periodicidade = ANY (ARRAY['mensal'::text, 'trimestral'::text, 'semestral'::text, 'anual'::text]))),
    CONSTRAINT contratos_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'ativo'::text, 'encerrado'::text, 'cancelado'::text])))
);

CREATE TABLE public.custos_cac (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    descricao text NOT NULL,
    valor numeric(14,2) NOT NULL,
    competencia date NOT NULL,
    grupo text DEFAULT 'outros'::text NOT NULL,
    rateio_regra_id uuid,
    fornecedor_id uuid,
    campanha_id uuid,
    campanha_canal_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    CONSTRAINT custos_cac_grupo_check CHECK ((grupo = ANY (ARRAY['midia'::text, 'comissao'::text, 'equipe'::text, 'ferramentas'::text, 'outros'::text]))),
    CONSTRAINT custos_cac_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.dashboard_layouts (
    user_id uuid DEFAULT auth.uid() NOT NULL,
    workspace_id uuid NOT NULL,
    layout jsonb NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.despesas_recorrentes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    fornecedor_id uuid,
    descricao text NOT NULL,
    tipo text NOT NULL,
    valor numeric(14,2) NOT NULL,
    parcelas integer,
    data_inicio date NOT NULL,
    data_fim date,
    conta_despesa_id uuid NOT NULL,
    centro_custo_id uuid,
    forma_pagamento_id uuid,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    do_fornecedor boolean DEFAULT false NOT NULL,
    CONSTRAINT despesas_recorrentes_check CHECK (((tipo <> 'parcelada'::text) OR ((parcelas IS NOT NULL) AND (data_fim IS NULL)))),
    CONSTRAINT despesas_recorrentes_check1 CHECK (((tipo = 'parcelada'::text) OR (parcelas IS NULL))),
    CONSTRAINT despesas_recorrentes_check2 CHECK (((data_fim IS NULL) OR (data_fim >= data_inicio))),
    CONSTRAINT despesas_recorrentes_parcelas_check CHECK (((parcelas IS NULL) OR ((parcelas >= 2) AND (parcelas <= 120)))),
    CONSTRAINT despesas_recorrentes_tipo_check CHECK ((tipo = ANY (ARRAY['fixa'::text, 'variavel'::text, 'parcelada'::text]))),
    CONSTRAINT despesas_recorrentes_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.empresa (
    workspace_id uuid NOT NULL,
    nome text,
    razao_social text,
    cnpj text,
    telefone text,
    email_contato text,
    endereco text,
    responsavel_nome text,
    responsavel_email text,
    responsavel_telefone text,
    financeiro_nome text,
    financeiro_email text,
    financeiro_telefone text,
    regime_tributario text,
    regime_apuracao text,
    exercicio_inicio date,
    exercicio_fim date,
    periodicidade_fechamento text,
    observacoes text,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_por uuid,
    anexo_simples text,
    aliquota_manual numeric(6,2),
    taxas_variaveis_pct numeric(6,2),
    CONSTRAINT empresa_aliquota_manual_check CHECK (((aliquota_manual IS NULL) OR ((aliquota_manual >= (0)::numeric) AND (aliquota_manual <= (100)::numeric)))),
    CONSTRAINT empresa_anexo_simples_check CHECK (((anexo_simples IS NULL) OR (anexo_simples = ANY (ARRAY['auto'::text, 'III'::text, 'V'::text])))),
    CONSTRAINT empresa_check CHECK (((exercicio_fim IS NULL) OR (exercicio_inicio IS NULL) OR (exercicio_fim >= exercicio_inicio))),
    CONSTRAINT empresa_periodicidade_fechamento_check CHECK ((periodicidade_fechamento = ANY (ARRAY['mensal'::text, 'trimestral'::text, 'anual'::text]))),
    CONSTRAINT empresa_regime_apuracao_check CHECK ((regime_apuracao = ANY (ARRAY['competencia'::text, 'caixa'::text]))),
    CONSTRAINT empresa_regime_tributario_check CHECK ((regime_tributario = ANY (ARRAY['mei'::text, 'simples_nacional'::text, 'lucro_presumido'::text, 'lucro_real'::text, 'outro'::text]))),
    CONSTRAINT empresa_taxas_variaveis_pct_check CHECK (((taxas_variaveis_pct IS NULL) OR ((taxas_variaveis_pct >= (0)::numeric) AND (taxas_variaveis_pct <= (100)::numeric))))
);

CREATE TABLE public.equipe (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    email text,
    telefone text,
    funcao text,
    avisar_app boolean DEFAULT true NOT NULL,
    avisar_email boolean DEFAULT true NOT NULL,
    avisar_whatsapp boolean DEFAULT false NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    funcao_id uuid,
    acesso_ativo boolean DEFAULT false NOT NULL,
    user_id uuid,
    permissoes_ind jsonb DEFAULT '{}'::jsonb NOT NULL,
    acoes_ind jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.estornos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    venda_id uuid NOT NULL,
    tipo text NOT NULL,
    valor numeric(14,2) NOT NULL,
    motivo text,
    data date NOT NULL,
    lancamento_id uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estornos_tipo_check CHECK ((tipo = ANY (ARRAY['cancelamento'::text, 'reembolso'::text, 'chargeback'::text])))
);

CREATE TABLE public.estrategia_blocos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    ordem integer DEFAULT 10 NOT NULL,
    fase text DEFAULT 'aquisicao'::text NOT NULL,
    tipo text NOT NULL,
    nome text NOT NULL,
    origem_ref uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estrategia_blocos_fase_check CHECK ((fase = ANY (ARRAY['aquisicao'::text, 'aquecimento'::text, 'conversao'::text, 'retencao'::text])))
);

CREATE TABLE public.estrategia_etapas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    fase text DEFAULT 'aquisicao'::text NOT NULL,
    chave text NOT NULL,
    nome text NOT NULL,
    unidade text DEFAULT 'numero'::text NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    metrica text,
    origem_ref uuid,
    conta_como text,
    taxa_esperada numeric,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    bloco_id uuid,
    papel text,
    fonte text,
    CONSTRAINT estrategia_etapas_chave_check CHECK ((chave ~ '^[a-z0-9_]{1,40}$'::text)),
    CONSTRAINT estrategia_etapas_conta_como_check CHECK ((conta_como = ANY (ARRAY['investimento'::text, 'clientes_novos'::text, 'upgrades'::text, 'renovados'::text, 'receita'::text]))),
    CONSTRAINT estrategia_etapas_fase_check CHECK ((fase = ANY (ARRAY['aquisicao'::text, 'aquecimento'::text, 'conversao'::text, 'retencao'::text]))),
    CONSTRAINT estrategia_etapas_metrica_check CHECK (((metrica IS NULL) OR (char_length(metrica) <= 30))),
    CONSTRAINT estrategia_etapas_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 80))),
    CONSTRAINT estrategia_etapas_origem_check CHECK ((origem = ANY (ARRAY['anuncios'::text, 'leads'::text, 'etapa_funil'::text, 'lista'::text, 'video'::text, 'vendas'::text, 'disparo'::text, 'manual'::text]))),
    CONSTRAINT estrategia_etapas_papel_chk CHECK (((papel IS NULL) OR (papel = ANY (ARRAY['principal'::text, 'diagnostico'::text])))),
    CONSTRAINT estrategia_etapas_taxa_esperada_check CHECK (((taxa_esperada IS NULL) OR (taxa_esperada >= (0)::numeric))),
    CONSTRAINT estrategia_etapas_unidade_check CHECK ((unidade = ANY (ARRAY['numero'::text, 'brl'::text, 'pct'::text])))
);

CREATE TABLE public.etapas_catalogo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    chave text NOT NULL,
    nome text NOT NULL,
    unidade text DEFAULT 'numero'::text NOT NULL,
    origem text DEFAULT 'manual'::text NOT NULL,
    metrica text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT etapas_catalogo_chave_check CHECK ((chave ~ '^[a-z0-9_]{1,40}$'::text)),
    CONSTRAINT etapas_catalogo_metrica_check CHECK (((metrica IS NULL) OR (char_length(metrica) <= 30))),
    CONSTRAINT etapas_catalogo_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 80))),
    CONSTRAINT etapas_catalogo_origem_check CHECK ((origem = ANY (ARRAY['anuncios'::text, 'leads'::text, 'etapa_funil'::text, 'lista'::text, 'video'::text, 'vendas'::text, 'disparo'::text, 'manual'::text]))),
    CONSTRAINT etapas_catalogo_unidade_check CHECK ((unidade = ANY (ARRAY['numero'::text, 'brl'::text, 'pct'::text])))
);

CREATE TABLE public.etapas_kanban (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    quadro text NOT NULL,
    nome text NOT NULL,
    ordem integer NOT NULL,
    descricao text,
    mensagem_padrao text,
    alertar_responsavel boolean DEFAULT false NOT NULL,
    CONSTRAINT etapas_kanban_quadro_check CHECK ((quadro = ANY (ARRAY['leads'::text, 'alunos'::text, 'oportunidades'::text])))
);

CREATE TABLE public.exp_guardrails (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    experimento_id uuid NOT NULL,
    guardrail_id uuid NOT NULL,
    ativado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.fontes_video (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    tipo text NOT NULL,
    plataforma text DEFAULT 'outro'::text NOT NULL,
    id_externo text,
    url text,
    funil_id uuid,
    campanha_id uuid,
    data_evento date,
    ativo boolean DEFAULT true NOT NULL,
    CONSTRAINT fontes_video_plataforma_check CHECK ((plataforma = ANY (ARRAY['youtube'::text, 'vimeo'::text, 'vturb'::text, 'panda'::text, 'wistia'::text, 'zoom'::text, 'meet'::text, 'outro'::text]))),
    CONSTRAINT fontes_video_tipo_check CHECK ((tipo = ANY (ARRAY['webinario'::text, 'vsl'::text, 'aula'::text])))
);

CREATE TABLE public.formas_pagamento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    tipo text DEFAULT 'outro'::text NOT NULL,
    titular_terceiro text,
    conta_bancaria_id uuid,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT formas_pagamento_tipo_check CHECK ((tipo = ANY (ARRAY['pix'::text, 'boleto'::text, 'cartao'::text, 'debito_automatico'::text, 'transferencia'::text, 'dinheiro'::text, 'outro'::text])))
);

CREATE TABLE public.fornecedores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    documento text,
    email text,
    telefone text,
    categoria text,
    ativo boolean DEFAULT true NOT NULL,
    tipo_custo text,
    valor_padrao numeric(14,2),
    dia_vencimento smallint,
    conta_despesa_id uuid,
    centro_custo_id uuid,
    forma_pagamento_id uuid,
    provisionar boolean DEFAULT false NOT NULL,
    recorrencia text,
    parcelas integer,
    data_inicio date,
    data_fim date,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    endereco text,
    observacoes text,
    contrato_url text,
    CONSTRAINT fornecedores_dia_vencimento_check CHECK (((dia_vencimento IS NULL) OR ((dia_vencimento >= 1) AND (dia_vencimento <= 31)))),
    CONSTRAINT fornecedores_extras_check CHECK ((jsonb_typeof(extras) = 'object'::text)),
    CONSTRAINT fornecedores_parcelas_check CHECK (((parcelas IS NULL) OR ((parcelas >= 2) AND (parcelas <= 120)))),
    CONSTRAINT fornecedores_recorrencia_check CHECK (((recorrencia IS NULL) OR (recorrencia = ANY (ARRAY['fixa'::text, 'variavel'::text, 'parcelada'::text])))),
    CONSTRAINT fornecedores_tipo_custo_check CHECK ((tipo_custo = ANY (ARRAY['fixo'::text, 'variavel'::text]))),
    CONSTRAINT fornecedores_valor_padrao_check CHECK (((valor_padrao IS NULL) OR (valor_padrao > (0)::numeric)))
);

CREATE TABLE public.funcoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    administrador boolean DEFAULT false NOT NULL,
    permissoes jsonb DEFAULT '{}'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    acoes jsonb DEFAULT '{}'::jsonb NOT NULL
);

CREATE TABLE public.funil_etapas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    nome text NOT NULL,
    ordem integer NOT NULL,
    tipo text DEFAULT 'meio'::text NOT NULL,
    CONSTRAINT funil_etapas_tipo_check CHECK ((tipo = ANY (ARRAY['entrada'::text, 'meio'::text, 'compra'::text])))
);

CREATE TABLE public.funil_listas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    nome text NOT NULL,
    tipo text DEFAULT 'outro'::text NOT NULL,
    lista_pai_id uuid,
    reinicia_jornada boolean DEFAULT false NOT NULL,
    etapa_ao_entrar_id uuid,
    CONSTRAINT funil_listas_check CHECK ((lista_pai_id <> id)),
    CONSTRAINT funil_listas_tipo_check CHECK ((tipo = ANY (ARRAY['grupo'::text, 'api'::text, 'outro'::text])))
);

CREATE TABLE public.funis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    tipo text DEFAULT 'captacao'::text NOT NULL,
    produto_id uuid,
    descricao text,
    ativo boolean DEFAULT true NOT NULL,
    modelo_pronto text,
    CONSTRAINT funis_modelo_pronto_check CHECK (((modelo_pronto IS NULL) OR (char_length(modelo_pronto) <= 40))),
    CONSTRAINT funis_tipo_check CHECK ((tipo = ANY (ARRAY['captacao'::text, 'lancamento'::text, 'perpetuo'::text, 'assinatura'::text, 'webinario'::text, 'disparo'::text, 'recompra'::text, 'comercial'::text, 'outro'::text])))
);

CREATE TABLE public.gm_alavancas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    loop_chave text NOT NULL,
    produto_id uuid,
    alavanca text NOT NULL,
    mes date NOT NULL,
    cenario text NOT NULL,
    valor numeric NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gm_alavancas_cenario_ok CHECK (((cenario = 'base'::text) OR (cenario ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'::text)))
);

CREATE TABLE public.gm_cenarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    hipotese text,
    autor uuid DEFAULT auth.uid(),
    escopo jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'rascunho'::text NOT NULL,
    versao integer DEFAULT 1 NOT NULL,
    substitui_id uuid,
    baseline jsonb,
    resultados jsonb,
    financeiro jsonb DEFAULT '{}'::jsonb NOT NULL,
    ue jsonb,
    impacto integer,
    confianca integer,
    facilidade integer,
    ice_justificativa text,
    aprovado_em timestamp with time zone,
    aprovado_por uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    descarte jsonb,
    CONSTRAINT gm_cenarios_confianca_check CHECK (((confianca IS NULL) OR ((confianca >= 1) AND (confianca <= 10)))),
    CONSTRAINT gm_cenarios_descarte_check CHECK (((descarte IS NULL) OR (jsonb_typeof(descarte) = 'object'::text))),
    CONSTRAINT gm_cenarios_escopo_check CHECK ((jsonb_typeof(escopo) = 'object'::text)),
    CONSTRAINT gm_cenarios_facilidade_check CHECK (((facilidade IS NULL) OR ((facilidade >= 1) AND (facilidade <= 10)))),
    CONSTRAINT gm_cenarios_financeiro_check CHECK ((jsonb_typeof(financeiro) = 'object'::text)),
    CONSTRAINT gm_cenarios_impacto_check CHECK (((impacto IS NULL) OR ((impacto >= 1) AND (impacto <= 10)))),
    CONSTRAINT gm_cenarios_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 120))),
    CONSTRAINT gm_cenarios_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'aprovado'::text, 'arquivado'::text])))
);

CREATE TABLE public.gm_config (
    workspace_id uuid NOT NULL,
    inicio date NOT NULL,
    meses integer DEFAULT 12 NOT NULL,
    CONSTRAINT gm_config_meses_check CHECK (((meses >= 1) AND (meses <= 36)))
);

CREATE TABLE public.gm_decisoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    cenario_id uuid NOT NULL,
    versao integer DEFAULT 1 NOT NULL,
    titulo text NOT NULL,
    documento jsonb NOT NULL,
    responsavel text,
    proximos_passos text,
    aprovado_por uuid DEFAULT auth.uid(),
    aprovado_por_email text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gm_decisoes_documento_check CHECK ((jsonb_typeof(documento) = 'object'::text))
);

CREATE TABLE public.gm_etapas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    nome text NOT NULL,
    unidade text DEFAULT 'numero'::text NOT NULL,
    op text DEFAULT 'input'::text NOT NULL,
    ref_id uuid,
    ref2_id uuid,
    refs uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    curva numeric[] DEFAULT '{}'::numeric[] NOT NULL,
    carrega boolean DEFAULT true NOT NULL,
    papel text,
    chave_auto text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gm_etapas_chave_auto_check CHECK ((chave_auto = ANY (ARRAY['investimento'::text, 'leads'::text, 'vendas'::text, 'receita'::text]))),
    CONSTRAINT gm_etapas_op_check CHECK ((op = ANY (ARRAY['input'::text, 'mult'::text, 'div'::text, 'div_mil'::text, 'soma'::text, 'coorte'::text]))),
    CONSTRAINT gm_etapas_papel_check CHECK ((papel = ANY (ARRAY['investimento'::text, 'clientes_novos'::text, 'renovados'::text, 'receita'::text]))),
    CONSTRAINT gm_etapas_unidade_check CHECK ((unidade = ANY (ARRAY['brl'::text, 'numero'::text, 'pct'::text])))
);

CREATE TABLE public.gm_funis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    fase text DEFAULT 'aquisicao'::text NOT NULL,
    produto_id uuid,
    ordem integer DEFAULT 0 NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gm_funis_fase_check CHECK ((fase = ANY (ARRAY['aquisicao'::text, 'retencao'::text])))
);

CREATE TABLE public.gm_modelos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text DEFAULT 'Modelo atual'::text NOT NULL,
    dados jsonb DEFAULT '{}'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gm_modelos_nome_check CHECK ((char_length(nome) <= 120))
);

CREATE TABLE public.gm_valores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    etapa_id uuid NOT NULL,
    mes date NOT NULL,
    cenario text NOT NULL,
    valor numeric NOT NULL,
    CONSTRAINT gm_valores_cenario_check CHECK ((cenario = ANY (ARRAY['base'::text, 'sim'::text])))
);

CREATE TABLE public.growth_experimentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    metrica_id uuid,
    titulo text NOT NULL,
    hipotese text,
    criterio_sucesso text,
    responsavel text,
    etapa text DEFAULT 'ideia'::text NOT NULL,
    impacto integer,
    confianca integer,
    facilidade integer,
    score numeric(4,1) GENERATED ALWAYS AS (round(((((impacto + confianca) + facilidade))::numeric / 3.0), 1)) STORED,
    inicio date,
    fim_previsto date,
    valor_base numeric,
    valor_resultado numeric,
    resultado text,
    decisao text,
    aprendizado text,
    concluido_em date,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    pesquisa_id uuid,
    insight text,
    cenario_id uuid,
    decisao_id uuid,
    tipo text DEFAULT 'experimento'::text NOT NULL,
    projeto_id uuid,
    publico text,
    intervencao text,
    instrumentacao text,
    custo_previsto numeric(12,2),
    metrica_alvo text,
    ice_justificativa text,
    link_doc text,
    CONSTRAINT growth_experimentos_check CHECK (((etapa <> 'concluido'::text) OR ((resultado IS NOT NULL) AND (aprendizado IS NOT NULL)))),
    CONSTRAINT growth_experimentos_confianca_check CHECK (((confianca >= 1) AND (confianca <= 10))),
    CONSTRAINT growth_experimentos_custo_previsto_check CHECK (((custo_previsto IS NULL) OR (custo_previsto >= (0)::numeric))),
    CONSTRAINT growth_experimentos_decisao_check CHECK ((decisao = ANY (ARRAY['escalar'::text, 'repetir'::text, 'descartar'::text]))),
    CONSTRAINT growth_experimentos_etapa_check CHECK ((etapa = ANY (ARRAY['ideia'::text, 'avaliacao'::text, 'priorizado'::text, 'preparacao'::text, 'rodando'::text, 'analise'::text, 'concluido'::text, 'arquivado'::text]))),
    CONSTRAINT growth_experimentos_facilidade_check CHECK (((facilidade >= 1) AND (facilidade <= 10))),
    CONSTRAINT growth_experimentos_impacto_check CHECK (((impacto >= 1) AND (impacto <= 10))),
    CONSTRAINT growth_experimentos_link_doc_check CHECK (((link_doc IS NULL) OR (link_doc ~* '^https?://'::text))),
    CONSTRAINT growth_experimentos_resultado_check CHECK ((resultado = ANY (ARRAY['venceu'::text, 'perdeu'::text, 'inconclusivo'::text]))),
    CONSTRAINT growth_experimentos_tipo_check CHECK ((tipo = ANY (ARRAY['experimento'::text, 'planejamento'::text])))
);

CREATE TABLE public.growth_metricas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pai_id uuid,
    nome text NOT NULL,
    descricao text,
    formula text,
    tipo text DEFAULT 'driver'::text NOT NULL,
    fonte text DEFAULT 'manual'::text NOT NULL,
    chave_auto text,
    unidade text DEFAULT 'numero'::text NOT NULL,
    direcao text DEFAULT 'sobe'::text NOT NULL,
    meta numeric,
    valor_manual numeric,
    valor_manual_anterior numeric,
    ordem integer DEFAULT 0 NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    nsm_evento text,
    nsm_populacao text,
    nsm_frequencia text,
    nsm_fonte text,
    produto_id uuid,
    CONSTRAINT growth_metricas_chave_auto_check CHECK ((chave_auto = ANY (ARRAY['investimento'::text, 'leads'::text, 'cpl'::text, 'vendas'::text, 'receita'::text, 'ticket'::text, 'cac'::text, 'roas'::text, 'conv'::text, 'clientes_ativos'::text]))),
    CONSTRAINT growth_metricas_check CHECK (((fonte = 'auto'::text) = (chave_auto IS NOT NULL))),
    CONSTRAINT growth_metricas_check1 CHECK ((pai_id IS DISTINCT FROM id)),
    CONSTRAINT growth_metricas_direcao_check CHECK ((direcao = ANY (ARRAY['sobe'::text, 'desce'::text]))),
    CONSTRAINT growth_metricas_fonte_check CHECK ((fonte = ANY (ARRAY['manual'::text, 'auto'::text]))),
    CONSTRAINT growth_metricas_tipo_check CHECK ((tipo = ANY (ARRAY['north_star'::text, 'driver'::text, 'input'::text]))),
    CONSTRAINT growth_metricas_unidade_check CHECK ((unidade = ANY (ARRAY['numero'::text, 'brl'::text, 'pct'::text, 'x'::text])))
);

CREATE TABLE public.guardrail_alertas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    experimento_id uuid,
    guardrail_id uuid NOT NULL,
    data date NOT NULL,
    valor numeric,
    limite numeric NOT NULL,
    severidade text NOT NULL,
    mensagem text NOT NULL,
    acao_sugerida text,
    status text DEFAULT 'aberto'::text NOT NULL,
    responsavel text,
    nota text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    resolvido_em timestamp with time zone,
    CONSTRAINT guardrail_alertas_severidade_check CHECK ((severidade = ANY (ARRAY['atencao'::text, 'critico'::text]))),
    CONSTRAINT guardrail_alertas_status_check CHECK ((status = ANY (ARRAY['aberto'::text, 'reconhecido'::text, 'resolvido'::text])))
);

CREATE TABLE public.guardrail_definicoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    metrica text NOT NULL,
    operador text NOT NULL,
    limite numeric NOT NULL,
    severidade text DEFAULT 'atencao'::text NOT NULL,
    escopo text DEFAULT 'negocio'::text NOT NULL,
    produto_id uuid,
    janela_dias integer DEFAULT 14 NOT NULL,
    frequencia text DEFAULT 'semanal'::text NOT NULL,
    acao_sugerida text,
    descricao text,
    continuo boolean DEFAULT false NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guardrail_definicoes_escopo_check CHECK ((escopo = ANY (ARRAY['negocio'::text, 'recorte'::text]))),
    CONSTRAINT guardrail_definicoes_frequencia_check CHECK ((frequencia = ANY (ARRAY['diaria'::text, 'semanal'::text]))),
    CONSTRAINT guardrail_definicoes_janela_dias_check CHECK (((janela_dias >= 1) AND (janela_dias <= 180))),
    CONSTRAINT guardrail_definicoes_metrica_check CHECK ((metrica = ANY (ARRAY['margem'::text, 'lucro'::text, 'roas'::text, 'cac_midia'::text, 'cpl'::text, 'midia'::text, 'receita'::text, 'vendas'::text, 'leads'::text, 'conv'::text, 'ticket'::text]))),
    CONSTRAINT guardrail_definicoes_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 120))),
    CONSTRAINT guardrail_definicoes_operador_check CHECK ((operador = ANY (ARRAY['min'::text, 'max'::text]))),
    CONSTRAINT guardrail_definicoes_severidade_check CHECK ((severidade = ANY (ARRAY['atencao'::text, 'critico'::text])))
);

CREATE TABLE public.guardrail_observacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    experimento_id uuid,
    guardrail_id uuid NOT NULL,
    data date NOT NULL,
    periodo text NOT NULL,
    janela_ini date,
    janela_fim date,
    valor numeric,
    limite numeric NOT NULL,
    situacao text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT guardrail_observacoes_periodo_check CHECK ((periodo = ANY (ARRAY['antes'::text, 'durante'::text, 'depois'::text, 'continuo'::text]))),
    CONSTRAINT guardrail_observacoes_situacao_check CHECK ((situacao = ANY (ARRAY['ok'::text, 'atencao'::text, 'violado'::text, 'sem_dado'::text])))
);

CREATE TABLE public.heavyops_metas (
    workspace_id uuid NOT NULL,
    churn_max numeric(6,2) DEFAULT 6 NOT NULL,
    retencao_min numeric(6,2) DEFAULT 85 NOT NULL,
    ltv_min numeric(14,2) DEFAULT 600 NOT NULL,
    ascensao_min numeric(6,2) DEFAULT 15 NOT NULL,
    tolerancia numeric(6,2) DEFAULT 15 NOT NULL,
    CONSTRAINT heavyops_metas_ascensao_min_check CHECK (((ascensao_min >= (0)::numeric) AND (ascensao_min <= (100)::numeric))),
    CONSTRAINT heavyops_metas_churn_max_check CHECK ((churn_max >= (0)::numeric)),
    CONSTRAINT heavyops_metas_ltv_min_check CHECK ((ltv_min >= (0)::numeric)),
    CONSTRAINT heavyops_metas_retencao_min_check CHECK (((retencao_min >= (0)::numeric) AND (retencao_min <= (100)::numeric))),
    CONSTRAINT heavyops_metas_tolerancia_check CHECK (((tolerancia >= (0)::numeric) AND (tolerancia <= (100)::numeric)))
);

CREATE TABLE public.ia_perguntas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    user_id uuid DEFAULT auth.uid() NOT NULL,
    pergunta text NOT NULL,
    resposta text,
    provedor text,
    modelo text,
    sem_dado boolean,
    nao_conferidos jsonb DEFAULT '[]'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ia_perguntas_pergunta_check CHECK ((char_length(pergunta) <= 600))
);

CREATE TABLE public.importacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    tipo text NOT NULL,
    escopo_id uuid NOT NULL,
    motivo text NOT NULL,
    justificativa text NOT NULL,
    arquivo_nome text,
    arquivo_hash text NOT NULL,
    linhas integer NOT NULL,
    periodo_ini date,
    periodo_fim date,
    totais jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'aplicada'::text NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    revertida_em timestamp with time zone,
    revertida_por uuid,
    motivo_reversao text,
    CONSTRAINT importacoes_motivo_check CHECK ((motivo = ANY (ARRAY['primeira_carga'::text, 'recuperacao_falha'::text]))),
    CONSTRAINT importacoes_status_check CHECK ((status = ANY (ARRAY['aplicada'::text, 'revertida'::text]))),
    CONSTRAINT importacoes_tipo_check CHECK ((tipo = ANY (ARRAY['trafego'::text, 'video_metricas'::text, 'video_presenca'::text])))
);

CREATE TABLE public.impostos_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    aliquota_percentual numeric(6,3) NOT NULL,
    base text DEFAULT 'valor_bruto'::text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    CONSTRAINT impostos_config_aliquota_percentual_check CHECK ((aliquota_percentual >= (0)::numeric)),
    CONSTRAINT impostos_config_base_check CHECK ((base = ANY (ARRAY['valor_bruto'::text, 'valor_liquido'::text])))
);

CREATE TABLE public.integracoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    provedor text NOT NULL,
    categoria text NOT NULL,
    status text DEFAULT 'configurando'::text NOT NULL,
    conta_externa text,
    observacao text,
    ultima_sincronizacao timestamp with time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT integracoes_categoria_check CHECK ((categoria = ANY (ARRAY['anuncios'::text, 'video'::text, 'vendas'::text, 'mensageria'::text, 'social'::text, 'ia'::text, 'outro'::text]))),
    CONSTRAINT integracoes_status_check CHECK ((status = ANY (ARRAY['configurando'::text, 'conectado'::text, 'erro'::text, 'desconectado'::text])))
);

CREATE TABLE public.lancamentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    data_fato date NOT NULL,
    descricao text,
    origem_tipo text NOT NULL,
    origem_id uuid,
    estorno_de uuid,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lancamentos_origem_tipo_check CHECK ((origem_tipo = ANY (ARRAY['venda'::text, 'recebimento'::text, 'estorno'::text, 'manual'::text, 'conta_pagar'::text, 'pagamento'::text, 'cancelamento_pagar'::text, 'contrato_parcela'::text, 'cancelamento_contrato'::text, 'desconto'::text, 'fatura_cartao'::text, 'transferencia_casa'::text])))
);

CREATE TABLE public.metricas_anuncio_dia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    anuncio_id uuid NOT NULL,
    data date NOT NULL,
    impressoes integer DEFAULT 0 NOT NULL,
    cliques integer DEFAULT 0 NOT NULL,
    custo numeric(14,2) DEFAULT 0 NOT NULL,
    visualizacoes_pagina integer DEFAULT 0 NOT NULL,
    alcance integer,
    origem text DEFAULT 'integracao'::text NOT NULL,
    importacao_id uuid,
    disponibilidade text DEFAULT 'completo'::text NOT NULL,
    atualizado_na_origem timestamp with time zone,
    CONSTRAINT metricas_anuncio_dia_alcance_check CHECK ((alcance >= 0)),
    CONSTRAINT metricas_anuncio_dia_cliques_check CHECK ((cliques >= 0)),
    CONSTRAINT metricas_anuncio_dia_custo_check CHECK ((custo >= (0)::numeric)),
    CONSTRAINT metricas_anuncio_dia_disp_check CHECK ((disponibilidade = ANY (ARRAY['completo'::text, 'parcial'::text, 'indisponivel'::text]))),
    CONSTRAINT metricas_anuncio_dia_impressoes_check CHECK ((impressoes >= 0)),
    CONSTRAINT metricas_anuncio_dia_origem_check CHECK ((origem = ANY (ARRAY['integracao'::text, 'importacao'::text, 'legado'::text]))),
    CONSTRAINT metricas_anuncio_dia_visualizacoes_pagina_check CHECK ((visualizacoes_pagina >= 0))
);

CREATE TABLE public.metricas_definicoes (
    codigo text NOT NULL,
    nome text NOT NULL,
    formula text NOT NULL,
    fonte text NOT NULL,
    sem_dado text NOT NULL,
    observacao text,
    versao integer DEFAULT 1 NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.motivos_resultado (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    tipo text NOT NULL,
    nome text NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    CONSTRAINT motivos_resultado_tipo_check CHECK ((tipo = ANY (ARRAY['ganho'::text, 'perdido'::text])))
);

CREATE TABLE public.movimentacoes_bancarias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    conta_bancaria_id uuid NOT NULL,
    data date NOT NULL,
    tipo text NOT NULL,
    valor numeric(14,2) NOT NULL,
    descricao text,
    origem_tipo text,
    origem_id uuid,
    lancamento_id uuid,
    CONSTRAINT movimentacoes_bancarias_tipo_check CHECK ((tipo = ANY (ARRAY['entrada'::text, 'saida'::text]))),
    CONSTRAINT movimentacoes_bancarias_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.notificacoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    destinatario_id uuid NOT NULL,
    projeto_id uuid,
    atividade_id uuid,
    tipo text DEFAULT 'atividade_liberada'::text NOT NULL,
    canal text NOT NULL,
    titulo text NOT NULL,
    mensagem text NOT NULL,
    status text DEFAULT 'pendente'::text NOT NULL,
    erro text,
    criada_em timestamp with time zone DEFAULT now() NOT NULL,
    enviada_em timestamp with time zone,
    lida_em timestamp with time zone,
    pessoa_id uuid,
    CONSTRAINT notificacoes_canal_check CHECK ((canal = ANY (ARRAY['app'::text, 'email'::text, 'whatsapp'::text]))),
    CONSTRAINT notificacoes_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'enviada'::text, 'falhou'::text])))
);

CREATE TABLE public.oferta_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    oferta_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    quantidade numeric DEFAULT 1 NOT NULL,
    alocacao_pct numeric DEFAULT 100 NOT NULL,
    CONSTRAINT oferta_itens_alocacao_pct_check CHECK (((alocacao_pct >= (0)::numeric) AND (alocacao_pct <= (100)::numeric))),
    CONSTRAINT oferta_itens_quantidade_check CHECK ((quantidade > (0)::numeric))
);

CREATE TABLE public.oferta_versoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    oferta_id uuid NOT NULL,
    versao integer NOT NULL,
    nome text NOT NULL,
    preco numeric(12,2) NOT NULL,
    condicoes text,
    parcelas_max integer,
    itens jsonb DEFAULT '[]'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid DEFAULT auth.uid()
);

CREATE TABLE public.ofertas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    produto_id uuid,
    nome text NOT NULL,
    papel text DEFAULT 'principal'::text NOT NULL,
    preco numeric(12,2) NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    descricao text,
    condicoes text,
    parcelas_max integer,
    vigencia_ini date,
    vigencia_fim date,
    status text DEFAULT 'ativa'::text NOT NULL,
    versao integer DEFAULT 1 NOT NULL,
    CONSTRAINT ofertas_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 120))),
    CONSTRAINT ofertas_papel_check CHECK ((papel = ANY (ARRAY['principal'::text, 'upsell'::text, 'order_bump'::text, 'cross_sell'::text, 'downsell'::text]))),
    CONSTRAINT ofertas_parcelas_max_check CHECK (((parcelas_max IS NULL) OR ((parcelas_max >= 1) AND (parcelas_max <= 36)))),
    CONSTRAINT ofertas_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT ofertas_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'ativa'::text, 'pausada'::text, 'encerrada'::text]))),
    CONSTRAINT ofertas_vigencia_check CHECK (((vigencia_fim IS NULL) OR (vigencia_ini IS NULL) OR (vigencia_fim >= vigencia_ini)))
);

CREATE TABLE public.oportunidades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    titulo text NOT NULL,
    tipo text DEFAULT 'nova_venda'::text NOT NULL,
    produto_id uuid,
    contrato_origem_id uuid,
    valor_estimado numeric(14,2),
    previsao_fechamento date,
    etapa_kanban_id uuid,
    status text DEFAULT 'aberta'::text NOT NULL,
    motivo text,
    responsavel_id uuid,
    observacoes text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    fechado_em timestamp with time zone,
    CONSTRAINT oportunidades_status_check CHECK ((status = ANY (ARRAY['aberta'::text, 'ganha'::text, 'perdida'::text]))),
    CONSTRAINT oportunidades_tipo_check CHECK ((tipo = ANY (ARRAY['nova_venda'::text, 'renovacao'::text, 'ajuste'::text]))),
    CONSTRAINT oportunidades_valor_estimado_check CHECK (((valor_estimado IS NULL) OR (valor_estimado >= (0)::numeric)))
);

CREATE TABLE public.pacotes_acesso (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    descricao text,
    telas text[] DEFAULT '{}'::text[] NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pagamentos_historicos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    produto_id uuid,
    valor numeric(14,2) NOT NULL,
    periodo_inicio date,
    periodo_fim date,
    descricao text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    CONSTRAINT pagamentos_historicos_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.partidas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    lancamento_id uuid NOT NULL,
    conta_id uuid NOT NULL,
    centro_custo_id uuid,
    tipo text NOT NULL,
    valor numeric(14,2) NOT NULL,
    CONSTRAINT partidas_tipo_check CHECK ((tipo = ANY (ARRAY['D'::text, 'C'::text]))),
    CONSTRAINT partidas_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.pesquisa_envios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pesquisa_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    token text DEFAULT replace(((gen_random_uuid())::text || (gen_random_uuid())::text), '-'::text, ''::text) NOT NULL,
    status text DEFAULT 'pendente'::text NOT NULL,
    motivo text,
    origem text DEFAULT 'gatilho'::text NOT NULL,
    gerado_em timestamp with time zone DEFAULT now() NOT NULL,
    enviado_em timestamp with time zone,
    respondido_em timestamp with time zone,
    CONSTRAINT pesquisa_envios_origem_check CHECK ((origem = ANY (ARRAY['gatilho'::text, 'manual'::text, 'retroativo'::text]))),
    CONSTRAINT pesquisa_envios_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'enviado'::text, 'respondido'::text, 'dispensado'::text])))
);

CREATE TABLE public.pesquisa_insights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pesquisa_id uuid NOT NULL,
    pergunta_id uuid,
    metrica_id uuid,
    texto text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pesquisa_perguntas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pesquisa_id uuid NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    texto text NOT NULL,
    tipo text NOT NULL,
    opcoes text[] DEFAULT '{}'::text[] NOT NULL,
    obrigatoria boolean DEFAULT true NOT NULL,
    papel text DEFAULT 'livre'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pesquisa_perguntas_check CHECK (((tipo <> ALL (ARRAY['escolha'::text, 'multipla'::text])) OR (cardinality(opcoes) >= 2))),
    CONSTRAINT pesquisa_perguntas_papel_check CHECK ((papel = ANY (ARRAY['livre'::text, 'nps'::text, 'pmf'::text, 'valor'::text, 'alavanca'::text, 'qualificacao'::text]))),
    CONSTRAINT pesquisa_perguntas_tipo_check CHECK ((tipo = ANY (ARRAY['nps'::text, 'escala'::text, 'escolha'::text, 'multipla'::text, 'sim_nao'::text, 'texto'::text])))
);

CREATE TABLE public.pesquisa_resposta_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    resposta_id uuid NOT NULL,
    pergunta_id uuid NOT NULL,
    valor_num numeric,
    valor_texto text
);

CREATE TABLE public.pesquisa_respostas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pesquisa_id uuid NOT NULL,
    envio_id uuid,
    pessoa_id uuid,
    email text,
    respondida_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pesquisas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    tipo text DEFAULT 'lead'::text NOT NULL,
    descricao text,
    ativa boolean DEFAULT true NOT NULL,
    gatilho text DEFAULT 'manual'::text NOT NULL,
    gatilho_etapa text,
    funil_id uuid,
    dispensa_qualificado boolean DEFAULT false NOT NULL,
    canal_envio text DEFAULT 'link'::text NOT NULL,
    mensagem text,
    aceita_link_aberto boolean DEFAULT false NOT NULL,
    token_aberto text DEFAULT replace(((gen_random_uuid())::text || (gen_random_uuid())::text), '-'::text, ''::text) NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pesquisas_canal_envio_check CHECK ((canal_envio = ANY (ARRAY['link'::text, 'whatsapp'::text, 'email'::text]))),
    CONSTRAINT pesquisas_check CHECK (((gatilho <> 'etapa'::text) OR (gatilho_etapa IS NOT NULL))),
    CONSTRAINT pesquisas_gatilho_check CHECK ((gatilho = ANY (ARRAY['manual'::text, 'cadastro'::text, 'etapa'::text, 'entrada_aluno'::text]))),
    CONSTRAINT pesquisas_tipo_check CHECK ((tipo = ANY (ARRAY['lead'::text, 'onboarding'::text, 'jornada'::text, 'nsm'::text, 'outra'::text])))
);

CREATE TABLE public.pessoa_funil (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    etapa_id uuid NOT NULL,
    entrou_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pessoa_funil_historico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    funil_id uuid NOT NULL,
    tipo text NOT NULL,
    ref text,
    de text,
    para text,
    em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pessoa_funil_historico_tipo_check CHECK ((tipo = ANY (ARRAY['etapa'::text, 'lista'::text])))
);

CREATE TABLE public.pessoa_historico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    campo text NOT NULL,
    valor_anterior text,
    valor_novo text,
    alterado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.pessoa_lista (
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    lista_id uuid NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    entrou_em timestamp with time zone DEFAULT now() NOT NULL,
    saiu_em timestamp with time zone
);

CREATE TABLE public.pessoa_notas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    texto text NOT NULL,
    autor_id uuid DEFAULT auth.uid(),
    autor_email text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pessoa_notas_texto_check CHECK ((length(btrim(texto)) > 0))
);

CREATE TABLE public.pessoa_toques (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    em timestamp with time zone DEFAULT now() NOT NULL,
    tipo text NOT NULL,
    canal text,
    campanha_id uuid,
    chave text,
    descricao text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    origem text DEFAULT 'sistema'::text NOT NULL,
    ref_tabela text,
    ref_id uuid,
    CONSTRAINT pessoa_toques_origem_check CHECK ((origem = ANY (ARRAY['sistema'::text, 'sendflow'::text, 'manual'::text, 'importacao'::text, 'captura'::text, 'integracao'::text]))),
    CONSTRAINT pessoa_toques_tipo_check CHECK ((tipo = ANY (ARRAY['entrada'::text, 'etapa'::text, 'lista'::text, 'video'::text, 'disparo'::text, 'comercial'::text, 'compra'::text, 'recompra'::text, 'outro'::text, 'captura'::text])))
);

CREATE TABLE public.pessoas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    email text,
    telefone text,
    status_funil text DEFAULT 'lead'::text NOT NULL,
    status_cliente text,
    etapa_kanban_id uuid,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    utm_term text,
    pagina_origem text,
    campanha_id uuid,
    canal_origem text,
    respostas_pesquisa jsonb,
    pesquisa_respondida_em timestamp with time zone,
    pontuacao_qualificacao numeric(6,2),
    qualificacao text DEFAULT 'pendente'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    convertido_em timestamp with time zone,
    utm_id text,
    gclid text,
    fbclid text,
    referrer text,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    negocio_status text DEFAULT 'aberto'::text NOT NULL,
    negocio_motivo_id uuid,
    negocio_obs text,
    negocio_fechado_em timestamp with time zone,
    responsavel_comercial_id uuid,
    captada boolean DEFAULT true NOT NULL,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    telefone_norm text GENERATED ALWAYS AS (public.norm_fone(telefone)) STORED,
    email_norm text GENERATED ALWAYS AS (public.norm_email(email)) STORED,
    CONSTRAINT pessoas_check CHECK (((status_funil = 'cliente'::text) = (status_cliente IS NOT NULL))),
    CONSTRAINT pessoas_extras_check CHECK ((jsonb_typeof(extras) = 'object'::text)),
    CONSTRAINT pessoas_negocio_status_check CHECK ((negocio_status = ANY (ARRAY['aberto'::text, 'ganho'::text, 'perdido'::text]))),
    CONSTRAINT pessoas_qualificacao_check CHECK ((qualificacao = ANY (ARRAY['pendente'::text, 'qualificado'::text, 'nao_qualificado'::text]))),
    CONSTRAINT pessoas_status_cliente_check CHECK ((status_cliente = ANY (ARRAY['ativo'::text, 'inativo'::text]))),
    CONSTRAINT pessoas_status_funil_check CHECK ((status_funil = ANY (ARRAY['lead'::text, 'cliente'::text])))
);

CREATE TABLE public.pessoas_mesclagens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_mantida uuid NOT NULL,
    pessoa_removida uuid NOT NULL,
    dados_removida jsonb NOT NULL,
    motivo text,
    feito_por uuid DEFAULT auth.uid(),
    feito_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.planejamento_mensal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    ano integer NOT NULL,
    mes integer NOT NULL,
    meta_leads integer,
    meta_vendas integer,
    meta_receita numeric(14,2),
    orcamento numeric(14,2),
    CONSTRAINT planejamento_mensal_mes_check CHECK (((mes >= 1) AND (mes <= 12)))
);

CREATE TABLE public.plano_contas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    codigo text NOT NULL,
    nome text NOT NULL,
    tipo text NOT NULL,
    natureza text NOT NULL,
    conta_pai_id uuid,
    aceita_lancamento boolean DEFAULT true NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    cac_grupo text,
    rateio_regra_id uuid,
    conta_passivo_id uuid,
    CONSTRAINT plano_contas_cac_grupo_check CHECK (((cac_grupo IS NULL) OR (cac_grupo = ANY (ARRAY['midia'::text, 'equipe'::text, 'ferramentas'::text, 'comissao'::text, 'outros'::text])))),
    CONSTRAINT plano_contas_natureza_check CHECK ((natureza = ANY (ARRAY['devedora'::text, 'credora'::text]))),
    CONSTRAINT plano_contas_tipo_check CHECK ((tipo = ANY (ARRAY['ativo'::text, 'passivo'::text, 'patrimonio'::text, 'receita'::text, 'deducao'::text, 'custo'::text, 'despesa'::text])))
);

CREATE TABLE public.plano_indicadores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    plano_id uuid NOT NULL,
    objetivo_id uuid NOT NULL,
    nome text NOT NULL,
    chave text,
    unidade text DEFAULT 'num'::text NOT NULL,
    sentido text DEFAULT 'aumentar'::text NOT NULL,
    valor_base numeric(16,4) DEFAULT 0 NOT NULL,
    valor_meta numeric(16,4) NOT NULL,
    valor_atual numeric(16,4),
    responsavel text,
    faixa_ruim numeric,
    faixa_otimo numeric,
    CONSTRAINT plano_indicadores_chave_check CHECK ((chave = ANY (ARRAY['receita'::text, 'mrr'::text, 'leads'::text, 'clientes'::text, 'conversao'::text, 'investimento'::text, 'cac'::text, 'ticket_medio'::text, 'margem_lucro'::text, 'margem_contribuicao'::text]))),
    CONSTRAINT plano_indicadores_sentido_check CHECK ((sentido = ANY (ARRAY['aumentar'::text, 'diminuir'::text]))),
    CONSTRAINT plano_indicadores_unidade_check CHECK ((unidade = ANY (ARRAY['brl'::text, 'num'::text, 'pct'::text])))
);

CREATE TABLE public.plano_metas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    plano_id uuid NOT NULL,
    indicador_id uuid,
    setor text NOT NULL,
    titulo text NOT NULL,
    chave text,
    unidade text DEFAULT 'num'::text NOT NULL,
    sentido text DEFAULT 'aumentar'::text NOT NULL,
    valor_base numeric(16,4) DEFAULT 0 NOT NULL,
    valor_meta numeric(16,4) NOT NULL,
    valor_atual numeric(16,4),
    prazo date,
    responsavel text,
    status text DEFAULT 'em_andamento'::text NOT NULL,
    CONSTRAINT plano_metas_chave_check CHECK ((chave = ANY (ARRAY['receita'::text, 'mrr'::text, 'leads'::text, 'clientes'::text, 'conversao'::text, 'investimento'::text, 'cac'::text, 'ticket_medio'::text]))),
    CONSTRAINT plano_metas_sentido_check CHECK ((sentido = ANY (ARRAY['aumentar'::text, 'diminuir'::text]))),
    CONSTRAINT plano_metas_setor_check CHECK ((setor = ANY (ARRAY['marketing'::text, 'vendas'::text, 'financeiro'::text, 'operacao'::text, 'produto'::text, 'cs'::text, 'outro'::text]))),
    CONSTRAINT plano_metas_status_check CHECK ((status = ANY (ARRAY['em_andamento'::text, 'concluida'::text, 'cancelada'::text]))),
    CONSTRAINT plano_metas_unidade_check CHECK ((unidade = ANY (ARRAY['brl'::text, 'num'::text, 'pct'::text])))
);

CREATE TABLE public.plano_objetivos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    plano_id uuid NOT NULL,
    titulo text NOT NULL,
    descricao text,
    ordem integer DEFAULT 0 NOT NULL
);

CREATE TABLE public.planos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    visao text,
    estrategia text,
    status text DEFAULT 'rascunho'::text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    mercado_total numeric(16,0),
    mercado_rotulo text,
    CONSTRAINT planos_check CHECK ((data_fim >= data_inicio)),
    CONSTRAINT planos_mercado_total_check CHECK (((mercado_total IS NULL) OR (mercado_total > (0)::numeric))),
    CONSTRAINT planos_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'ativo'::text, 'encerrado'::text])))
);

CREATE TABLE public.plataforma_formas_pagamento (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    plataforma_id uuid NOT NULL,
    forma_pagamento text NOT NULL,
    taxa_percentual numeric(6,3),
    taxa_fixa numeric(12,2),
    prazo_recebimento_dias integer DEFAULT 0 NOT NULL,
    ativa boolean DEFAULT true NOT NULL,
    CONSTRAINT plataforma_formas_pagamento_forma_pagamento_check CHECK ((forma_pagamento = ANY (ARRAY['pix'::text, 'cartao_credito'::text, 'boleto'::text, 'outro'::text]))),
    CONSTRAINT plataforma_formas_pagamento_prazo_recebimento_dias_check CHECK ((prazo_recebimento_dias >= 0))
);

CREATE TABLE public.plataformas_venda (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    taxa_percentual numeric(6,3) DEFAULT 0 NOT NULL,
    taxa_fixa numeric(12,2) DEFAULT 0 NOT NULL,
    ativa boolean DEFAULT true NOT NULL,
    observacoes text
);

CREATE TABLE public.presencas_video (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    fonte_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    assistiu_seg integer DEFAULT 0 NOT NULL,
    ao_vivo boolean DEFAULT false NOT NULL,
    primeiro_em timestamp with time zone DEFAULT now() NOT NULL,
    ultimo_em timestamp with time zone DEFAULT now() NOT NULL,
    origem text DEFAULT 'integracao'::text NOT NULL,
    importacao_id uuid,
    CONSTRAINT presencas_video_assistiu_seg_check CHECK ((assistiu_seg >= 0)),
    CONSTRAINT presencas_video_origem_check CHECK ((origem = ANY (ARRAY['integracao'::text, 'importacao'::text, 'legado'::text])))
);

CREATE TABLE public.produto_plataforma (
    workspace_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    plataforma_id uuid NOT NULL,
    id_externo text
);

CREATE TABLE public.produtos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    tag text NOT NULL,
    tipo text DEFAULT 'curso'::text NOT NULL,
    recorrente boolean DEFAULT false NOT NULL,
    periodicidade text,
    preco numeric(12,2) NOT NULL,
    taxa_percentual_override numeric(6,3),
    taxa_fixa_override numeric(12,2),
    centro_custo_id uuid,
    ativo boolean DEFAULT true NOT NULL,
    nivel_escada integer,
    modelo_projeto_id uuid,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    categoria text,
    CONSTRAINT produtos_check CHECK ((recorrente = (periodicidade IS NOT NULL))),
    CONSTRAINT produtos_extras_check CHECK ((jsonb_typeof(extras) = 'object'::text)),
    CONSTRAINT produtos_nivel_escada_check CHECK ((nivel_escada >= 1)),
    CONSTRAINT produtos_periodicidade_check CHECK ((periodicidade = ANY (ARRAY['mensal'::text, 'trimestral'::text, 'semestral'::text, 'anual'::text]))),
    CONSTRAINT produtos_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT produtos_tipo_check CHECK ((tipo = ANY (ARRAY['digital'::text, 'saas'::text, 'servico'::text, 'curso'::text, 'assinatura'::text, 'outro'::text])))
);

CREATE TABLE public.projeto_atividades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    projeto_id uuid NOT NULL,
    pai_id uuid,
    titulo text NOT NULL,
    descricao text,
    funcao text,
    responsavel_id uuid,
    status text DEFAULT 'bloqueada'::text NOT NULL,
    ordem integer DEFAULT 0 NOT NULL,
    depende_de uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    prazo date,
    liberada_em timestamp with time zone,
    iniciada_em timestamp with time zone,
    concluida_em timestamp with time zone,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    campanha_bloco_id uuid,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT projeto_atividades_status_check CHECK ((status = ANY (ARRAY['bloqueada'::text, 'liberada'::text, 'em_andamento'::text, 'concluida'::text, 'cancelada'::text])))
);

CREATE TABLE public.projeto_modelo_atividades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    modelo_id uuid NOT NULL,
    pai_id uuid,
    titulo text NOT NULL,
    descricao text,
    funcao text,
    responsavel_id uuid,
    ordem integer DEFAULT 0 NOT NULL,
    depende_de uuid[] DEFAULT '{}'::uuid[] NOT NULL,
    prazo_dias integer DEFAULT 0 NOT NULL,
    CONSTRAINT projeto_modelo_atividades_prazo_dias_check CHECK ((prazo_dias >= 0))
);

CREATE TABLE public.projeto_modelos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    padrao_campanha boolean DEFAULT false NOT NULL,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.projetos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    status text DEFAULT 'planejado'::text NOT NULL,
    campanha_id uuid,
    modelo_id uuid,
    responsavel_id uuid,
    data_inicio date,
    data_fim_prevista date,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    concluido_em timestamp with time zone,
    pessoa_id uuid,
    contrato_id uuid,
    venda_id uuid,
    produto_id uuid,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT projetos_status_check CHECK ((status = ANY (ARRAY['planejado'::text, 'em_andamento'::text, 'concluido'::text, 'pausado'::text, 'cancelado'::text])))
);

CREATE TABLE public.qualidade_regras (
    workspace_id uuid NOT NULL,
    codigo text NOT NULL,
    ativa boolean DEFAULT true NOT NULL,
    tolerancia numeric,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.rateio_itens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    regra_id uuid NOT NULL,
    centro_custo_id uuid NOT NULL,
    percentual numeric(7,4) NOT NULL,
    CONSTRAINT rateio_itens_percentual_check CHECK (((percentual > (0)::numeric) AND (percentual <= (100)::numeric)))
);

CREATE TABLE public.rateio_regras (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    descricao text,
    ativo boolean DEFAULT true NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.regras_contabilizacao (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    evento text NOT NULL,
    descricao text,
    conta_debito_id uuid,
    conta_credito_id uuid,
    ativo boolean DEFAULT true NOT NULL,
    nome text,
    personalizada boolean DEFAULT false NOT NULL,
    CONSTRAINT regras_contabilizacao_evento_check CHECK ((((NOT personalizada) AND (evento = ANY (ARRAY['venda_receita'::text, 'venda_taxa_plataforma'::text, 'venda_imposto'::text, 'recebimento'::text, 'estorno_pagamento'::text, 'conta_pagar'::text, 'pagamento'::text, 'contrato_receita'::text, 'contrato_recebimento'::text]))) OR (personalizada AND (evento ~ '^x_[a-z0-9_]{2,40}$'::text) AND (nome IS NOT NULL) AND (length(TRIM(BOTH FROM nome)) > 0))))
);

CREATE TABLE public.responsavel_historico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    tipo text NOT NULL,
    pessoa_id uuid NOT NULL,
    aluno_id uuid,
    de_equipe_id uuid,
    para_equipe_id uuid,
    de_nome text,
    para_nome text,
    alterado_por uuid,
    alterado_por_email text,
    motivo text,
    alterado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT responsavel_historico_tipo_check CHECK ((tipo = ANY (ARRAY['comercial'::text, 'cs'::text])))
);

CREATE TABLE public.revops_config (
    workspace_id uuid NOT NULL,
    simultanea text DEFAULT 'dia'::text NOT NULL,
    rfm jsonb DEFAULT '{}'::jsonb NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT revops_config_rfm_check CHECK ((jsonb_typeof(rfm) = 'object'::text)),
    CONSTRAINT revops_config_simultanea_check CHECK ((simultanea = ANY (ARRAY['dia'::text, 'pedido'::text])))
);

CREATE TABLE public.revops_visoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    usuario_id uuid DEFAULT auth.uid() NOT NULL,
    nome text NOT NULL,
    aba text DEFAULT 'coortes'::text NOT NULL,
    filtros jsonb DEFAULT '{}'::jsonb NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT revops_visoes_aba_check CHECK ((aba = ANY (ARRAY['coortes'::text, 'recompra'::text, 'rfm'::text]))),
    CONSTRAINT revops_visoes_nome_check CHECK (((char_length(nome) >= 1) AND (char_length(nome) <= 80)))
);

CREATE TABLE public.simulador_cenarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    nome text NOT NULL,
    dados jsonb DEFAULT '{}'::jsonb NOT NULL,
    versao_formula text DEFAULT 'gps-1.0'::text NOT NULL,
    status text DEFAULT 'rascunho'::text NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT simulador_cenarios_dados_check CHECK ((jsonb_typeof(dados) = 'object'::text)),
    CONSTRAINT simulador_cenarios_status_check CHECK ((status = ANY (ARRAY['rascunho'::text, 'ativo'::text, 'arquivado'::text])))
);

CREATE TABLE public.simulador_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    cenario_id uuid NOT NULL,
    nome text NOT NULL,
    versao_formula text NOT NULL,
    premissas jsonb NOT NULL,
    metricas jsonb NOT NULL,
    calculado_em timestamp with time zone DEFAULT now() NOT NULL,
    criado_por uuid DEFAULT auth.uid(),
    CONSTRAINT simulador_snapshots_metricas_check CHECK ((jsonb_typeof(metricas) = 'object'::text)),
    CONSTRAINT simulador_snapshots_premissas_check CHECK ((jsonb_typeof(premissas) = 'object'::text))
);

CREATE TABLE public.transferencias_casa (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ws_origem uuid NOT NULL,
    ws_casa uuid NOT NULL,
    data date NOT NULL,
    valor numeric NOT NULL,
    descricao text NOT NULL,
    conta_pagar_id uuid,
    lancamento_origem uuid,
    conta_receber_casa uuid,
    desfeita_em timestamp with time zone,
    criado_por uuid DEFAULT auth.uid(),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT transferencias_casa_valor_check CHECK ((valor > (0)::numeric))
);

CREATE TABLE public.uso_eventos (
    id bigint NOT NULL,
    workspace_id uuid NOT NULL,
    user_id uuid DEFAULT auth.uid() NOT NULL,
    usuario_email text,
    sessao text NOT NULL,
    tipo text NOT NULL,
    tela text NOT NULL,
    detalhe text,
    segundos integer,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT uso_eventos_segundos_check CHECK (((segundos IS NULL) OR ((segundos >= 0) AND (segundos <= 14400)))),
    CONSTRAINT uso_eventos_tipo_check CHECK ((tipo = ANY (ARRAY['tela'::text, 'tempo'::text, 'modal_abre'::text, 'modal_salva'::text, 'modal_cancela'::text, 'erro'::text])))
);

CREATE TABLE public.venda_atribuicoes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    venda_id uuid NOT NULL,
    modelo text NOT NULL,
    canal text,
    campanha_id uuid,
    campanha_canal_id uuid,
    temperatura text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    toque_id uuid,
    peso numeric DEFAULT 1 NOT NULL,
    regra_versao integer DEFAULT 1 NOT NULL,
    evidencia jsonb DEFAULT '{}'::jsonb NOT NULL,
    atribuido_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT venda_atribuicoes_modelo_check CHECK ((modelo = ANY (ARRAY['primeiro_toque'::text, 'ultimo_toque'::text])))
);

CREATE TABLE public.vendas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    pessoa_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    plataforma_id uuid,
    campanha_id uuid,
    forma_pagamento text NOT NULL,
    parcelas integer DEFAULT 1 NOT NULL,
    status text DEFAULT 'aprovada'::text NOT NULL,
    data_venda timestamp with time zone DEFAULT now() NOT NULL,
    valor_bruto numeric(14,2) NOT NULL,
    taxa_plataforma numeric(14,2),
    impostos numeric(14,2),
    valor_a_receber numeric(14,2),
    valor_liquido numeric(14,2),
    data_prevista_recebimento date,
    conta_bancaria_id uuid,
    id_externo text,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    vendedor_id uuid,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    canal_fechamento text,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    utm_content text,
    comprador_email text,
    comprador_telefone text,
    aprovada_em timestamp with time zone,
    reembolsada_em timestamp with time zone,
    cancelada_em timestamp with time zone,
    origem_dado text DEFAULT 'manual'::text NOT NULL,
    pedido_ref text,
    CONSTRAINT vendas_canal_fechamento_check CHECK (((canal_fechamento IS NULL) OR (char_length(canal_fechamento) <= 60))),
    CONSTRAINT vendas_extras_check CHECK ((jsonb_typeof(extras) = 'object'::text)),
    CONSTRAINT vendas_forma_pagamento_check CHECK ((forma_pagamento = ANY (ARRAY['pix'::text, 'cartao_credito'::text, 'boleto'::text, 'outro'::text]))),
    CONSTRAINT vendas_origem_dado_check CHECK ((origem_dado = ANY (ARRAY['manual'::text, 'importacao'::text, 'integracao'::text]))),
    CONSTRAINT vendas_parcelas_check CHECK ((parcelas >= 1)),
    CONSTRAINT vendas_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'aprovada'::text, 'cancelada'::text, 'reembolsada'::text, 'chargeback'::text]))),
    CONSTRAINT vendas_valor_bruto_check CHECK ((valor_bruto >= (0)::numeric))
);

CREATE TABLE public.video_metricas_dia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workspace_id uuid NOT NULL,
    fonte_id uuid NOT NULL,
    data date NOT NULL,
    plays integer DEFAULT 0 NOT NULL,
    espectadores integer DEFAULT 0 NOT NULL,
    tempo_assistido_seg bigint DEFAULT 0 NOT NULL,
    retencao_pct numeric(5,2),
    conclusoes integer DEFAULT 0 NOT NULL,
    cliques_cta integer DEFAULT 0 NOT NULL,
    pico_simultaneo integer DEFAULT 0 NOT NULL,
    origem text DEFAULT 'integracao'::text NOT NULL,
    importacao_id uuid,
    disponibilidade text DEFAULT 'completo'::text NOT NULL,
    atualizado_na_origem timestamp with time zone,
    CONSTRAINT video_metricas_dia_cliques_cta_check CHECK ((cliques_cta >= 0)),
    CONSTRAINT video_metricas_dia_conclusoes_check CHECK ((conclusoes >= 0)),
    CONSTRAINT video_metricas_dia_disp_check CHECK ((disponibilidade = ANY (ARRAY['completo'::text, 'parcial'::text, 'indisponivel'::text]))),
    CONSTRAINT video_metricas_dia_espectadores_check CHECK ((espectadores >= 0)),
    CONSTRAINT video_metricas_dia_origem_check CHECK ((origem = ANY (ARRAY['integracao'::text, 'importacao'::text, 'legado'::text]))),
    CONSTRAINT video_metricas_dia_pico_simultaneo_check CHECK ((pico_simultaneo >= 0)),
    CONSTRAINT video_metricas_dia_plays_check CHECK ((plays >= 0)),
    CONSTRAINT video_metricas_dia_retencao_pct_check CHECK (((retencao_pct >= (0)::numeric) AND (retencao_pct <= (100)::numeric))),
    CONSTRAINT video_metricas_dia_tempo_assistido_seg_check CHECK ((tempo_assistido_seg >= 0))
);

CREATE TABLE public.workspace_membros (
    workspace_id uuid NOT NULL,
    user_id uuid NOT NULL,
    papel text DEFAULT 'admin'::text NOT NULL,
    funcao_id uuid,
    CONSTRAINT workspace_membros_papel_check CHECK ((papel = ANY (ARRAY['admin'::text, 'editor'::text, 'leitor'::text])))
);

CREATE TABLE public.workspaces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome text NOT NULL,
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    modo_financeiro text DEFAULT 'completo'::text NOT NULL,
    modo_produto text DEFAULT 'completo'::text NOT NULL,
    agencia boolean DEFAULT false NOT NULL,
    pacote_id uuid,
    acesso_liga text[] DEFAULT '{}'::text[] NOT NULL,
    acesso_desliga text[] DEFAULT '{}'::text[] NOT NULL,
    casa_de uuid,
    atribuicao_padrao text DEFAULT 'ultimo_toque'::text NOT NULL,
    CONSTRAINT workspaces_atribuicao_check CHECK ((atribuicao_padrao = ANY (ARRAY['primeiro_toque'::text, 'ultimo_toque'::text]))),
    CONSTRAINT workspaces_casa_nao_agencia CHECK (((casa_de IS NULL) OR ((casa_de <> id) AND (NOT COALESCE(agencia, false))))),
    CONSTRAINT workspaces_modo_financeiro_check CHECK ((modo_financeiro = ANY (ARRAY['completo'::text, 'simplificado'::text]))),
    CONSTRAINT workspaces_modo_produto_check CHECK ((modo_produto = ANY (ARRAY['completo'::text, 'starter'::text])))
);

-- ======================================================================
-- SEQUÊNCIAS
-- ======================================================================

CREATE SEQUENCE public.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE public.uso_eventos ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.uso_eventos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER SEQUENCE public.auditoria_id_seq OWNED BY public.auditoria.id;

-- ======================================================================
-- VALORES PADRÃO DE SEQUÊNCIAS
-- ======================================================================

ALTER TABLE ONLY public.auditoria ALTER COLUMN id SET DEFAULT nextval('public.auditoria_id_seq'::regclass);

-- ======================================================================
-- CHAVES PRIMÁRIAS E ÚNICAS
-- ======================================================================

ALTER TABLE ONLY public.acesso_telas
    ADD CONSTRAINT acesso_telas_pkey PRIMARY KEY (tela);

ALTER TABLE ONLY public.aluno_historico
    ADD CONSTRAINT aluno_historico_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_venda_id_key UNIQUE (venda_id);

ALTER TABLE ONLY public.anuncios
    ADD CONSTRAINT anuncios_campanha_canal_id_utm_content_key UNIQUE (campanha_canal_id, utm_content);

ALTER TABLE ONLY public.anuncios
    ADD CONSTRAINT anuncios_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.benchmarks_mercado
    ADD CONSTRAINT benchmarks_mercado_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.benchmarks_mercado
    ADD CONSTRAINT benchmarks_mercado_workspace_id_metrica_key UNIQUE (workspace_id, metrica);

ALTER TABLE ONLY public.campanha_blocos
    ADD CONSTRAINT campanha_blocos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_calculos
    ADD CONSTRAINT campanha_calculos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_workspace_id_utm_campaign_key UNIQUE (workspace_id, utm_campaign);

ALTER TABLE ONLY public.campanha_debriefing
    ADD CONSTRAINT campanha_debriefing_campanha_id_key UNIQUE (campanha_id);

ALTER TABLE ONLY public.campanha_debriefing
    ADD CONSTRAINT campanha_debriefing_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_estrategias
    ADD CONSTRAINT campanha_estrategias_campanha_id_funil_id_key UNIQUE (campanha_id, funil_id);

ALTER TABLE ONLY public.campanha_estrategias
    ADD CONSTRAINT campanha_estrategias_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_etapa_valores
    ADD CONSTRAINT campanha_etapa_valores_campanha_etapa_id_data_key UNIQUE (campanha_etapa_id, data);

ALTER TABLE ONLY public.campanha_etapa_valores
    ADD CONSTRAINT campanha_etapa_valores_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_etapas
    ADD CONSTRAINT campanha_etapas_campanha_id_chave_key UNIQUE (campanha_id, chave);

ALTER TABLE ONLY public.campanha_etapas
    ADD CONSTRAINT campanha_etapas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_fechamentos
    ADD CONSTRAINT campanha_fechamentos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_links
    ADD CONSTRAINT campanha_links_campanha_canal_id_utm_content_key UNIQUE (campanha_canal_id, utm_content);

ALTER TABLE ONLY public.campanha_links
    ADD CONSTRAINT campanha_links_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_melhorias
    ADD CONSTRAINT campanha_melhorias_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_metas_mes
    ADD CONSTRAINT campanha_metas_mes_campanha_id_mes_key UNIQUE (campanha_id, mes);

ALTER TABLE ONLY public.campanha_metas_mes
    ADD CONSTRAINT campanha_metas_mes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_metas
    ADD CONSTRAINT campanha_metas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_mix
    ADD CONSTRAINT campanha_mix_campanha_id_produto_id_key UNIQUE (campanha_id, produto_id);

ALTER TABLE ONLY public.campanha_mix
    ADD CONSTRAINT campanha_mix_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_campanha_id_pessoa_id_key UNIQUE (campanha_id, pessoa_id);

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campos_personalizados
    ADD CONSTRAINT campos_personalizados_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.campos_personalizados
    ADD CONSTRAINT campos_personalizados_workspace_id_entidade_chave_key UNIQUE (workspace_id, entidade, chave);

ALTER TABLE ONLY public.canais
    ADD CONSTRAINT canais_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.canais
    ADD CONSTRAINT canais_workspace_id_codigo_key UNIQUE (workspace_id, codigo);

ALTER TABLE ONLY public.centros_custo
    ADD CONSTRAINT centros_custo_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.centros_custo
    ADD CONSTRAINT centros_custo_workspace_id_codigo_key UNIQUE (workspace_id, codigo);

ALTER TABLE ONLY public.chaves_api
    ADD CONSTRAINT chaves_api_hash_key UNIQUE (hash);

ALTER TABLE ONLY public.chaves_api
    ADD CONSTRAINT chaves_api_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_venda_id_key UNIQUE (venda_id);

ALTER TABLE ONLY public.conteudo_config
    ADD CONSTRAINT conteudo_config_pkey PRIMARY KEY (workspace_id);

ALTER TABLE ONLY public.conteudo_conta_dia
    ADD CONSTRAINT conteudo_conta_dia_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.conteudo_conta_dia
    ADD CONSTRAINT conteudo_conta_dia_workspace_id_canal_data_key UNIQUE (workspace_id, canal, data);

ALTER TABLE ONLY public.conteudo_linhas
    ADD CONSTRAINT conteudo_linhas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.conteudo_metas_semanais
    ADD CONSTRAINT conteudo_metas_semanais_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.conteudo_metas_semanais
    ADD CONSTRAINT conteudo_metas_semanais_workspace_id_formato_key UNIQUE (workspace_id, formato);

ALTER TABLE ONLY public.conteudo_publicacoes
    ADD CONSTRAINT conteudo_publicacoes_conteudo_id_canal_key UNIQUE (conteudo_id, canal);

ALTER TABLE ONLY public.conteudo_publicacoes
    ADD CONSTRAINT conteudo_publicacoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.conteudo_temas
    ADD CONSTRAINT conteudo_temas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.conteudos
    ADD CONSTRAINT conteudos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contrato_itens
    ADD CONSTRAINT contrato_itens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contrato_parcelas_plano
    ADD CONSTRAINT contrato_parcelas_plano_contrato_id_numero_key UNIQUE (contrato_id, numero);

ALTER TABLE ONLY public.contrato_parcelas_plano
    ADD CONSTRAINT contrato_parcelas_plano_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.contratos
    ADD CONSTRAINT contratos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.dashboard_layouts
    ADD CONSTRAINT dashboard_layouts_pkey PRIMARY KEY (user_id, workspace_id);

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_pkey PRIMARY KEY (workspace_id);

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.estornos
    ADD CONSTRAINT estornos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.estrategia_blocos
    ADD CONSTRAINT estrategia_blocos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.estrategia_etapas
    ADD CONSTRAINT estrategia_etapas_funil_id_chave_key UNIQUE (funil_id, chave);

ALTER TABLE ONLY public.estrategia_etapas
    ADD CONSTRAINT estrategia_etapas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.etapas_catalogo
    ADD CONSTRAINT etapas_catalogo_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.etapas_catalogo
    ADD CONSTRAINT etapas_catalogo_workspace_id_chave_key UNIQUE (workspace_id, chave);

ALTER TABLE ONLY public.etapas_kanban
    ADD CONSTRAINT etapas_kanban_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.etapas_kanban
    ADD CONSTRAINT etapas_kanban_workspace_id_quadro_nome_key UNIQUE (workspace_id, quadro, nome);

ALTER TABLE ONLY public.exp_guardrails
    ADD CONSTRAINT exp_guardrails_experimento_id_guardrail_id_key UNIQUE (experimento_id, guardrail_id);

ALTER TABLE ONLY public.exp_guardrails
    ADD CONSTRAINT exp_guardrails_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.fontes_video
    ADD CONSTRAINT fontes_video_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.formas_pagamento
    ADD CONSTRAINT formas_pagamento_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.formas_pagamento
    ADD CONSTRAINT formas_pagamento_workspace_id_nome_key UNIQUE (workspace_id, nome);

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.funcoes
    ADD CONSTRAINT funcoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.funcoes
    ADD CONSTRAINT funcoes_workspace_id_nome_key UNIQUE (workspace_id, nome);

ALTER TABLE ONLY public.funil_etapas
    ADD CONSTRAINT funil_etapas_funil_id_nome_key UNIQUE (funil_id, nome);

ALTER TABLE ONLY public.funil_etapas
    ADD CONSTRAINT funil_etapas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_funil_id_nome_key UNIQUE (funil_id, nome);

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.funis
    ADD CONSTRAINT funis_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_alavancas
    ADD CONSTRAINT gm_alavancas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_cenarios
    ADD CONSTRAINT gm_cenarios_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_config
    ADD CONSTRAINT gm_config_pkey PRIMARY KEY (workspace_id);

ALTER TABLE ONLY public.gm_decisoes
    ADD CONSTRAINT gm_decisoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_etapas
    ADD CONSTRAINT gm_etapas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_funis
    ADD CONSTRAINT gm_funis_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_modelos
    ADD CONSTRAINT gm_modelos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gm_modelos
    ADD CONSTRAINT gm_modelos_workspace_id_key UNIQUE (workspace_id);

ALTER TABLE ONLY public.gm_valores
    ADD CONSTRAINT gm_valores_etapa_id_mes_cenario_key UNIQUE (etapa_id, mes, cenario);

ALTER TABLE ONLY public.gm_valores
    ADD CONSTRAINT gm_valores_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.growth_metricas
    ADD CONSTRAINT growth_metricas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.guardrail_alertas
    ADD CONSTRAINT guardrail_alertas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.guardrail_definicoes
    ADD CONSTRAINT guardrail_definicoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.guardrail_observacoes
    ADD CONSTRAINT guardrail_observacoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.heavyops_metas
    ADD CONSTRAINT heavyops_metas_pkey PRIMARY KEY (workspace_id);

ALTER TABLE ONLY public.ia_perguntas
    ADD CONSTRAINT ia_perguntas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.importacoes
    ADD CONSTRAINT importacoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.impostos_config
    ADD CONSTRAINT impostos_config_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.integracoes
    ADD CONSTRAINT integracoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.integracoes
    ADD CONSTRAINT integracoes_workspace_id_provedor_key UNIQUE (workspace_id, provedor);

ALTER TABLE ONLY public.lancamentos
    ADD CONSTRAINT lancamentos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.metricas_anuncio_dia
    ADD CONSTRAINT metricas_anuncio_dia_anuncio_id_data_key UNIQUE (anuncio_id, data);

ALTER TABLE ONLY public.metricas_anuncio_dia
    ADD CONSTRAINT metricas_anuncio_dia_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.metricas_definicoes
    ADD CONSTRAINT metricas_definicoes_pkey PRIMARY KEY (codigo);

ALTER TABLE ONLY public.motivos_resultado
    ADD CONSTRAINT motivos_resultado_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.motivos_resultado
    ADD CONSTRAINT motivos_resultado_workspace_id_tipo_nome_key UNIQUE (workspace_id, tipo, nome);

ALTER TABLE ONLY public.movimentacoes_bancarias
    ADD CONSTRAINT movimentacoes_bancarias_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.oferta_itens
    ADD CONSTRAINT oferta_itens_oferta_id_produto_id_key UNIQUE (oferta_id, produto_id);

ALTER TABLE ONLY public.oferta_itens
    ADD CONSTRAINT oferta_itens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.oferta_versoes
    ADD CONSTRAINT oferta_versoes_oferta_id_versao_key UNIQUE (oferta_id, versao);

ALTER TABLE ONLY public.oferta_versoes
    ADD CONSTRAINT oferta_versoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ofertas
    ADD CONSTRAINT ofertas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pacotes_acesso
    ADD CONSTRAINT pacotes_acesso_nome_key UNIQUE (nome);

ALTER TABLE ONLY public.pacotes_acesso
    ADD CONSTRAINT pacotes_acesso_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pagamentos_historicos
    ADD CONSTRAINT pagamentos_historicos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.partidas
    ADD CONSTRAINT partidas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_pesquisa_id_pessoa_id_key UNIQUE (pesquisa_id, pessoa_id);

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_token_key UNIQUE (token);

ALTER TABLE ONLY public.pesquisa_insights
    ADD CONSTRAINT pesquisa_insights_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisa_perguntas
    ADD CONSTRAINT pesquisa_perguntas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisa_resposta_itens
    ADD CONSTRAINT pesquisa_resposta_itens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisa_resposta_itens
    ADD CONSTRAINT pesquisa_resposta_itens_resposta_id_pergunta_id_valor_texto_key UNIQUE (resposta_id, pergunta_id, valor_texto);

ALTER TABLE ONLY public.pesquisa_respostas
    ADD CONSTRAINT pesquisa_respostas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisas
    ADD CONSTRAINT pesquisas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pesquisas
    ADD CONSTRAINT pesquisas_token_aberto_key UNIQUE (token_aberto);

ALTER TABLE ONLY public.pessoa_funil_historico
    ADD CONSTRAINT pessoa_funil_historico_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_pessoa_id_funil_id_key UNIQUE (pessoa_id, funil_id);

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoa_historico
    ADD CONSTRAINT pessoa_historico_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoa_lista
    ADD CONSTRAINT pessoa_lista_pkey PRIMARY KEY (pessoa_id, lista_id);

ALTER TABLE ONLY public.pessoa_notas
    ADD CONSTRAINT pessoa_notas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoa_toques
    ADD CONSTRAINT pessoa_toques_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoa_toques
    ADD CONSTRAINT pessoa_toques_ref UNIQUE (pessoa_id, ref_tabela, ref_id, tipo);

ALTER TABLE ONLY public.pessoas_mesclagens
    ADD CONSTRAINT pessoas_mesclagens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.planejamento_mensal
    ADD CONSTRAINT planejamento_mensal_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.planejamento_mensal
    ADD CONSTRAINT planejamento_mensal_workspace_id_ano_mes_key UNIQUE (workspace_id, ano, mes);

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_workspace_id_codigo_key UNIQUE (workspace_id, codigo);

ALTER TABLE ONLY public.plano_indicadores
    ADD CONSTRAINT plano_indicadores_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.plano_metas
    ADD CONSTRAINT plano_metas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.plano_objetivos
    ADD CONSTRAINT plano_objetivos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.planos
    ADD CONSTRAINT planos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.plataforma_formas_pagamento
    ADD CONSTRAINT plataforma_formas_pagamento_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.plataforma_formas_pagamento
    ADD CONSTRAINT plataforma_formas_pagamento_plataforma_id_forma_pagamento_key UNIQUE (plataforma_id, forma_pagamento);

ALTER TABLE ONLY public.plataformas_venda
    ADD CONSTRAINT plataformas_venda_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_fonte_id_pessoa_id_key UNIQUE (fonte_id, pessoa_id);

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.produto_plataforma
    ADD CONSTRAINT produto_plataforma_pkey PRIMARY KEY (produto_id, plataforma_id);

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.projeto_modelo_atividades
    ADD CONSTRAINT projeto_modelo_atividades_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.projeto_modelos
    ADD CONSTRAINT projeto_modelos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_campanha_id_key UNIQUE (campanha_id);

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.qualidade_regras
    ADD CONSTRAINT qualidade_regras_pkey PRIMARY KEY (workspace_id, codigo);

ALTER TABLE ONLY public.rateio_itens
    ADD CONSTRAINT rateio_itens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.rateio_itens
    ADD CONSTRAINT rateio_itens_regra_id_centro_custo_id_key UNIQUE (regra_id, centro_custo_id);

ALTER TABLE ONLY public.rateio_regras
    ADD CONSTRAINT rateio_regras_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.rateio_regras
    ADD CONSTRAINT rateio_regras_workspace_id_nome_key UNIQUE (workspace_id, nome);

ALTER TABLE ONLY public.regras_contabilizacao
    ADD CONSTRAINT regras_contabilizacao_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.regras_contabilizacao
    ADD CONSTRAINT regras_contabilizacao_workspace_id_evento_key UNIQUE (workspace_id, evento);

ALTER TABLE ONLY public.responsavel_historico
    ADD CONSTRAINT responsavel_historico_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.revops_config
    ADD CONSTRAINT revops_config_pkey PRIMARY KEY (workspace_id);

ALTER TABLE ONLY public.revops_visoes
    ADD CONSTRAINT revops_visoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.simulador_cenarios
    ADD CONSTRAINT simulador_cenarios_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.simulador_snapshots
    ADD CONSTRAINT simulador_snapshots_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.uso_eventos
    ADD CONSTRAINT uso_eventos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.venda_atribuicoes
    ADD CONSTRAINT venda_atribuicoes_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.venda_atribuicoes
    ADD CONSTRAINT venda_atribuicoes_venda_id_modelo_key UNIQUE (venda_id, modelo);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.video_metricas_dia
    ADD CONSTRAINT video_metricas_dia_fonte_id_data_key UNIQUE (fonte_id, data);

ALTER TABLE ONLY public.video_metricas_dia
    ADD CONSTRAINT video_metricas_dia_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.workspace_membros
    ADD CONSTRAINT workspace_membros_pkey PRIMARY KEY (workspace_id, user_id);

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);

-- ======================================================================
-- ÍNDICES
-- ======================================================================

CREATE INDEX aluno_historico_ws_pessoa ON public.aluno_historico USING btree (workspace_id, pessoa_id);

CREATE UNIQUE INDEX alunos_contrato_uq ON public.alunos USING btree (contrato_id);

CREATE INDEX alunos_resp_ix ON public.alunos USING btree (workspace_id, responsavel_cs_id);

CREATE INDEX auditoria_registro ON public.auditoria USING btree (tabela, registro_id);

CREATE INDEX auditoria_ws_em ON public.auditoria USING btree (workspace_id, em DESC);

CREATE INDEX campanha_blocos_campanha ON public.campanha_blocos USING btree (campanha_id);

CREATE INDEX campanha_calculos_workspace_id_campanha_id_idx ON public.campanha_calculos USING btree (workspace_id, campanha_id);

CREATE INDEX campanha_etapas_bloco ON public.campanha_etapas USING btree (bloco_id);

CREATE INDEX campanha_etapas_camp ON public.campanha_etapas USING btree (campanha_id, ordem);

CREATE INDEX campanha_fechamentos_camp ON public.campanha_fechamentos USING btree (campanha_id, fechado_em DESC);

CREATE INDEX campanha_melhorias_camp ON public.campanha_melhorias USING btree (campanha_id, status);

CREATE UNIQUE INDEX campanha_metas_uq ON public.campanha_metas USING btree (campanha_id, tipo, COALESCE(fase, ''::text), COALESCE(canal, ''::text), COALESCE(temperatura, ''::text), COALESCE(segmento, ''::text), COALESCE(data_ini, '2000-01-01'::date), COALESCE(data_fim, '2000-01-01'::date));

CREATE INDEX campanha_ofertas_pai ON public.campanha_ofertas USING btree (pai_id);

CREATE INDEX campanha_ofertas_workspace_id_campanha_id_idx ON public.campanha_ofertas USING btree (workspace_id, campanha_id);

CREATE INDEX campanha_participacoes_ws ON public.campanha_participacoes USING btree (workspace_id, entrou_em);

CREATE INDEX chaves_api_ws ON public.chaves_api USING btree (workspace_id);

CREATE UNIQUE INDEX checkout_abandonos_externo ON public.checkout_abandonos USING btree (workspace_id, id_externo) WHERE (id_externo IS NOT NULL);

CREATE INDEX checkout_abandonos_ws ON public.checkout_abandonos USING btree (workspace_id, abandonado_em);

CREATE UNIQUE INDEX contas_bancarias_padrao_uq ON public.contas_bancarias USING btree (workspace_id) WHERE padrao;

CREATE INDEX contas_pagar_ix ON public.contas_pagar USING btree (workspace_id, status, vencimento);

CREATE UNIQUE INDEX contas_pagar_provisao_uq ON public.contas_pagar USING btree (workspace_id, fornecedor_id, competencia) WHERE provisionada;

CREATE UNIQUE INDEX contas_pagar_recorrencia_uq ON public.contas_pagar USING btree (recorrencia_id, competencia) WHERE ((recorrencia_id IS NOT NULL) AND (status <> 'cancelado'::text));

CREATE INDEX contas_pagar_saldo_de ON public.contas_pagar USING btree (saldo_de);

CREATE INDEX contas_receber_contrato_ix ON public.contas_receber USING btree (contrato_id);

CREATE INDEX contas_receber_ix ON public.contas_receber USING btree (workspace_id, status, vencimento);

CREATE INDEX conteudo_publicacoes_ws ON public.conteudo_publicacoes USING btree (workspace_id, data_publicacao);

CREATE UNIQUE INDEX conteudo_temas_nome_uq ON public.conteudo_temas USING btree (workspace_id, lower(nome));

CREATE INDEX conteudos_pub ON public.conteudos USING btree (workspace_id, data_publicacao);

CREATE INDEX conteudos_ws ON public.conteudos USING btree (workspace_id, status);

CREATE INDEX contrato_itens_ix ON public.contrato_itens USING btree (contrato_id);

CREATE INDEX contratos_ix ON public.contratos USING btree (workspace_id, status);

CREATE INDEX contratos_pessoa_ix ON public.contratos USING btree (pessoa_id);

CREATE UNIQUE INDEX despesas_recorrentes_forn_uq ON public.despesas_recorrentes USING btree (fornecedor_id) WHERE do_fornecedor;

CREATE INDEX despesas_recorrentes_ix ON public.despesas_recorrentes USING btree (workspace_id, ativo);

CREATE UNIQUE INDEX equipe_email_uq ON public.equipe USING btree (workspace_id, lower(email)) WHERE (email IS NOT NULL);

CREATE INDEX estrategia_blocos_funil ON public.estrategia_blocos USING btree (funil_id);

CREATE INDEX estrategia_etapas_bloco ON public.estrategia_etapas USING btree (bloco_id);

CREATE INDEX estrategia_etapas_funil ON public.estrategia_etapas USING btree (funil_id, ordem);

CREATE UNIQUE INDEX funil_etapas_compra_uq ON public.funil_etapas USING btree (funil_id) WHERE (tipo = 'compra'::text);

CREATE UNIQUE INDEX funil_etapas_entrada_uq ON public.funil_etapas USING btree (funil_id) WHERE (tipo = 'entrada'::text);

CREATE UNIQUE INDEX gm_alavancas_uni ON public.gm_alavancas USING btree (workspace_id, loop_chave, COALESCE(produto_id, '00000000-0000-0000-0000-000000000000'::uuid), alavanca, mes, cenario);

CREATE INDEX gm_cenarios_ws ON public.gm_cenarios USING btree (workspace_id, status);

CREATE INDEX gm_decisoes_cen ON public.gm_decisoes USING btree (cenario_id);

CREATE INDEX gm_etapas_funil ON public.gm_etapas USING btree (funil_id, ordem);

CREATE INDEX gm_valores_etapa ON public.gm_valores USING btree (etapa_id);

CREATE UNIQUE INDEX growth_experimentos_cenario_uq ON public.growth_experimentos USING btree (cenario_id) WHERE (cenario_id IS NOT NULL);

CREATE INDEX growth_experimentos_ws ON public.growth_experimentos USING btree (workspace_id, etapa);

CREATE UNIQUE INDEX growth_metricas_north_star ON public.growth_metricas USING btree (workspace_id) WHERE (tipo = 'north_star'::text);

CREATE INDEX growth_metricas_ws ON public.growth_metricas USING btree (workspace_id, pai_id);

CREATE UNIQUE INDEX guardrail_alertas_aberto_uq ON public.guardrail_alertas USING btree (COALESCE(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id) WHERE (status <> 'resolvido'::text);

CREATE UNIQUE INDEX guardrail_observacoes_uq ON public.guardrail_observacoes USING btree (COALESCE(experimento_id, '00000000-0000-0000-0000-000000000000'::uuid), guardrail_id, data, periodo);

CREATE INDEX ia_perguntas_ix ON public.ia_perguntas USING btree (user_id, criado_em DESC);

CREATE UNIQUE INDEX importacoes_hash_uq ON public.importacoes USING btree (workspace_id, arquivo_hash) WHERE (status = 'aplicada'::text);

CREATE INDEX importacoes_ix ON public.importacoes USING btree (workspace_id, criado_em DESC);

CREATE INDEX metricas_anuncio_dia_ix ON public.metricas_anuncio_dia USING btree (workspace_id, data);

CREATE INDEX notificacoes_ix ON public.notificacoes USING btree (workspace_id, destinatario_id, criada_em DESC);

CREATE INDEX oferta_itens_oferta ON public.oferta_itens USING btree (oferta_id);

CREATE INDEX ofertas_workspace_id_produto_id_idx ON public.ofertas USING btree (workspace_id, produto_id);

CREATE INDEX oportunidades_pessoa_idx ON public.oportunidades USING btree (pessoa_id);

CREATE INDEX oportunidades_ws_idx ON public.oportunidades USING btree (workspace_id, status);

CREATE INDEX partidas_lancamento_ix ON public.partidas USING btree (lancamento_id);

CREATE INDEX pesquisa_envios_ws ON public.pesquisa_envios USING btree (workspace_id, status);

CREATE INDEX pesquisa_itens_p ON public.pesquisa_resposta_itens USING btree (pergunta_id);

CREATE INDEX pesquisa_perguntas_p ON public.pesquisa_perguntas USING btree (pesquisa_id, ordem);

CREATE INDEX pesquisa_respostas_p ON public.pesquisa_respostas USING btree (pesquisa_id, respondida_em);

CREATE INDEX pessoa_funil_historico_ix ON public.pessoa_funil_historico USING btree (pessoa_id, em);

CREATE INDEX pessoa_funil_ix ON public.pessoa_funil USING btree (workspace_id, funil_id, etapa_id);

CREATE INDEX pessoa_notas_ix ON public.pessoa_notas USING btree (pessoa_id, criado_em DESC);

CREATE INDEX pessoa_toques_pessoa ON public.pessoa_toques USING btree (pessoa_id, em);

CREATE INDEX pessoa_toques_ws_em ON public.pessoa_toques USING btree (workspace_id, em);

CREATE UNIQUE INDEX pessoas_email_uq ON public.pessoas USING btree (workspace_id, lower(email)) WHERE (email IS NOT NULL);

CREATE INDEX pessoas_negocio_ix ON public.pessoas USING btree (workspace_id, negocio_status);

CREATE INDEX pessoas_nome_norm_ix ON public.pessoas USING btree (workspace_id, public.norm_nome(nome));

CREATE INDEX pessoas_resp_ix ON public.pessoas USING btree (workspace_id, responsavel_comercial_id);

CREATE INDEX pessoas_status_ix ON public.pessoas USING btree (workspace_id, status_funil);

CREATE INDEX pessoas_tags_ix ON public.pessoas USING gin (tags);

CREATE UNIQUE INDEX pessoas_telefone_uq ON public.pessoas USING btree (workspace_id, telefone_norm) WHERE (telefone_norm IS NOT NULL);

CREATE INDEX pessoas_utm_campaign_ix ON public.pessoas USING btree (workspace_id, utm_campaign);

CREATE INDEX pessoas_utm_content_ix ON public.pessoas USING btree (workspace_id, utm_content);

CREATE INDEX plano_ind_ix ON public.plano_indicadores USING btree (plano_id);

CREATE INDEX plano_metas_ix ON public.plano_metas USING btree (plano_id);

CREATE INDEX presencas_video_ix ON public.presencas_video USING btree (workspace_id, pessoa_id);

CREATE INDEX projeto_atividades_bloco ON public.projeto_atividades USING btree (campanha_bloco_id);

CREATE INDEX projeto_atividades_ix ON public.projeto_atividades USING btree (projeto_id, ordem);

CREATE INDEX projeto_atividades_resp ON public.projeto_atividades USING btree (workspace_id, responsavel_id, status);

CREATE INDEX projeto_atividades_tags_ix ON public.projeto_atividades USING gin (tags);

CREATE INDEX projeto_modelo_atividades_ix ON public.projeto_modelo_atividades USING btree (modelo_id, ordem);

CREATE UNIQUE INDEX projeto_modelos_padrao_uq ON public.projeto_modelos USING btree (workspace_id) WHERE padrao_campanha;

CREATE UNIQUE INDEX projetos_contrato_produto_uq ON public.projetos USING btree (contrato_id, produto_id) WHERE (contrato_id IS NOT NULL);

CREATE INDEX projetos_pessoa_ix ON public.projetos USING btree (pessoa_id);

CREATE INDEX projetos_tags_ix ON public.projetos USING gin (tags);

CREATE UNIQUE INDEX projetos_venda_uq ON public.projetos USING btree (venda_id) WHERE (venda_id IS NOT NULL);

CREATE INDEX projetos_ws ON public.projetos USING btree (workspace_id, status);

CREATE INDEX responsavel_historico_pessoa_idx ON public.responsavel_historico USING btree (pessoa_id, alterado_em DESC);

CREATE INDEX responsavel_historico_ws_idx ON public.responsavel_historico USING btree (workspace_id, alterado_em DESC);

CREATE INDEX simulador_cenarios_ws ON public.simulador_cenarios USING btree (workspace_id);

CREATE INDEX simulador_snapshots_cenario ON public.simulador_snapshots USING btree (cenario_id);

CREATE INDEX uso_eventos_ws_data ON public.uso_eventos USING btree (workspace_id, criado_em DESC);

CREATE INDEX uso_eventos_ws_tela ON public.uso_eventos USING btree (workspace_id, tela, tipo);

CREATE INDEX venda_atribuicoes_ws ON public.venda_atribuicoes USING btree (workspace_id, modelo, canal);

CREATE INDEX vendas_data_ix ON public.vendas USING btree (workspace_id, data_venda);

CREATE UNIQUE INDEX vendas_externo_uq ON public.vendas USING btree (workspace_id, COALESCE(plataforma_id, '00000000-0000-0000-0000-000000000000'::uuid), id_externo) WHERE (id_externo IS NOT NULL);

CREATE INDEX vendas_pedido_ref ON public.vendas USING btree (workspace_id, pedido_ref) WHERE (pedido_ref IS NOT NULL);

CREATE INDEX vendas_pessoa_ix ON public.vendas USING btree (pessoa_id);

CREATE INDEX video_metricas_dia_ix ON public.video_metricas_dia USING btree (workspace_id, data);

CREATE UNIQUE INDEX workspaces_uma_casa ON public.workspaces USING btree (casa_de) WHERE (casa_de IS NOT NULL);

-- ======================================================================
-- CHAVES ESTRANGEIRAS (relações entre tabelas)
-- ======================================================================

ALTER TABLE ONLY public.aluno_historico
    ADD CONSTRAINT aluno_historico_aluno_id_fkey FOREIGN KEY (aluno_id) REFERENCES public.alunos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.aluno_historico
    ADD CONSTRAINT aluno_historico_etapa_kanban_id_fkey FOREIGN KEY (etapa_kanban_id) REFERENCES public.etapas_kanban(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.aluno_historico
    ADD CONSTRAINT aluno_historico_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.aluno_historico
    ADD CONSTRAINT aluno_historico_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contratos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_etapa_kanban_id_fkey FOREIGN KEY (etapa_kanban_id) REFERENCES public.etapas_kanban(id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_responsavel_cs_id_fkey FOREIGN KEY (responsavel_cs_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id);

ALTER TABLE ONLY public.alunos
    ADD CONSTRAINT alunos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.anuncios
    ADD CONSTRAINT anuncios_campanha_canal_id_fkey FOREIGN KEY (campanha_canal_id) REFERENCES public.campanha_canais(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.anuncios
    ADD CONSTRAINT anuncios_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.benchmarks_mercado
    ADD CONSTRAINT benchmarks_mercado_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_blocos
    ADD CONSTRAINT campanha_blocos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_blocos
    ADD CONSTRAINT campanha_blocos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_calculos
    ADD CONSTRAINT campanha_calculos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_calculos
    ADD CONSTRAINT campanha_calculos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_canal_fk FOREIGN KEY (workspace_id, canal) REFERENCES public.canais(workspace_id, codigo) ON UPDATE CASCADE;

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanha_canais
    ADD CONSTRAINT campanha_canais_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_debriefing
    ADD CONSTRAINT campanha_debriefing_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_debriefing
    ADD CONSTRAINT campanha_debriefing_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_estrategias
    ADD CONSTRAINT campanha_estrategias_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_estrategias
    ADD CONSTRAINT campanha_estrategias_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_estrategias
    ADD CONSTRAINT campanha_estrategias_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_etapa_valores
    ADD CONSTRAINT campanha_etapa_valores_campanha_etapa_id_fkey FOREIGN KEY (campanha_etapa_id) REFERENCES public.campanha_etapas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_etapa_valores
    ADD CONSTRAINT campanha_etapa_valores_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_etapas
    ADD CONSTRAINT campanha_etapas_bloco_id_fkey FOREIGN KEY (bloco_id) REFERENCES public.campanha_blocos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_etapas
    ADD CONSTRAINT campanha_etapas_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_etapas
    ADD CONSTRAINT campanha_etapas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_fechamentos
    ADD CONSTRAINT campanha_fechamentos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_fechamentos
    ADD CONSTRAINT campanha_fechamentos_substitui_id_fkey FOREIGN KEY (substitui_id) REFERENCES public.campanha_fechamentos(id);

ALTER TABLE ONLY public.campanha_fechamentos
    ADD CONSTRAINT campanha_fechamentos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_links
    ADD CONSTRAINT campanha_links_anuncio_id_fkey FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanha_links
    ADD CONSTRAINT campanha_links_campanha_canal_id_fkey FOREIGN KEY (campanha_canal_id) REFERENCES public.campanha_canais(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_links
    ADD CONSTRAINT campanha_links_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_melhorias
    ADD CONSTRAINT campanha_melhorias_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_melhorias
    ADD CONSTRAINT campanha_melhorias_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_metas
    ADD CONSTRAINT campanha_metas_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_metas_mes
    ADD CONSTRAINT campanha_metas_mes_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_metas_mes
    ADD CONSTRAINT campanha_metas_mes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_metas
    ADD CONSTRAINT campanha_metas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_mix
    ADD CONSTRAINT campanha_mix_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_mix
    ADD CONSTRAINT campanha_mix_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);

ALTER TABLE ONLY public.campanha_mix
    ADD CONSTRAINT campanha_mix_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_oferta_id_fkey FOREIGN KEY (oferta_id) REFERENCES public.ofertas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_pai_id_fkey FOREIGN KEY (pai_id) REFERENCES public.campanha_ofertas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.campanha_ofertas
    ADD CONSTRAINT campanha_ofertas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_campanha_canal_id_fkey FOREIGN KEY (campanha_canal_id) REFERENCES public.campanha_canais(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanha_participacoes
    ADD CONSTRAINT campanha_participacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_meta_id_fkey FOREIGN KEY (meta_id) REFERENCES public.plano_metas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_projeto_modelo_id_fkey FOREIGN KEY (projeto_modelo_id) REFERENCES public.projeto_modelos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.campanhas
    ADD CONSTRAINT campanhas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.campos_personalizados
    ADD CONSTRAINT campos_personalizados_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.canais
    ADD CONSTRAINT canais_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.centros_custo
    ADD CONSTRAINT centros_custo_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.chaves_api
    ADD CONSTRAINT chaves_api_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_recuperado_venda_id_fkey FOREIGN KEY (recuperado_venda_id) REFERENCES public.vendas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.checkout_abandonos
    ADD CONSTRAINT checkout_abandonos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_conta_contabil_id_fkey FOREIGN KEY (conta_contabil_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.contas_bancarias
    ADD CONSTRAINT contas_bancarias_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_campanha_canal_id_fkey FOREIGN KEY (campanha_canal_id) REFERENCES public.campanha_canais(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_conta_despesa_id_fkey FOREIGN KEY (conta_despesa_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_forma_pagamento_id_fkey FOREIGN KEY (forma_pagamento_id) REFERENCES public.formas_pagamento(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_rateio_regra_id_fkey FOREIGN KEY (rateio_regra_id) REFERENCES public.rateio_regras(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_recorrencia_id_fkey FOREIGN KEY (recorrencia_id) REFERENCES public.despesas_recorrentes(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_saldo_de_fkey FOREIGN KEY (saldo_de) REFERENCES public.contas_pagar(id);

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_substituida_por_fkey FOREIGN KEY (substituida_por) REFERENCES public.contas_pagar(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.contas_pagar
    ADD CONSTRAINT contas_pagar_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_conta_receita_id_fkey FOREIGN KEY (conta_receita_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contratos(id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_substituida_por_fkey FOREIGN KEY (substituida_por) REFERENCES public.contas_receber(id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id);

ALTER TABLE ONLY public.contas_receber
    ADD CONSTRAINT contas_receber_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_config
    ADD CONSTRAINT conteudo_config_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_conta_dia
    ADD CONSTRAINT conteudo_conta_dia_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_linhas
    ADD CONSTRAINT conteudo_linhas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_metas_semanais
    ADD CONSTRAINT conteudo_metas_semanais_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_publicacoes
    ADD CONSTRAINT conteudo_publicacoes_conteudo_id_fkey FOREIGN KEY (conteudo_id) REFERENCES public.conteudos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_publicacoes
    ADD CONSTRAINT conteudo_publicacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudo_temas
    ADD CONSTRAINT conteudo_temas_linha_id_fkey FOREIGN KEY (linha_id) REFERENCES public.conteudo_linhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.conteudo_temas
    ADD CONSTRAINT conteudo_temas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.conteudos
    ADD CONSTRAINT conteudos_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.conteudos
    ADD CONSTRAINT conteudos_tema_id_fkey FOREIGN KEY (tema_id) REFERENCES public.conteudo_temas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.conteudos
    ADD CONSTRAINT conteudos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contrato_itens
    ADD CONSTRAINT contrato_itens_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contratos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contrato_itens
    ADD CONSTRAINT contrato_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);

ALTER TABLE ONLY public.contrato_itens
    ADD CONSTRAINT contrato_itens_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contrato_parcelas_plano
    ADD CONSTRAINT contrato_parcelas_plano_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contratos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contrato_parcelas_plano
    ADD CONSTRAINT contrato_parcelas_plano_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.contratos
    ADD CONSTRAINT contratos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id);

ALTER TABLE ONLY public.contratos
    ADD CONSTRAINT contratos_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id);

ALTER TABLE ONLY public.contratos
    ADD CONSTRAINT contratos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id);

ALTER TABLE ONLY public.contratos
    ADD CONSTRAINT contratos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_campanha_canal_id_fkey FOREIGN KEY (campanha_canal_id) REFERENCES public.campanha_canais(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_rateio_regra_id_fkey FOREIGN KEY (rateio_regra_id) REFERENCES public.rateio_regras(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.custos_cac
    ADD CONSTRAINT custos_cac_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.dashboard_layouts
    ADD CONSTRAINT dashboard_layouts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id);

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_conta_despesa_id_fkey FOREIGN KEY (conta_despesa_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_forma_pagamento_id_fkey FOREIGN KEY (forma_pagamento_id) REFERENCES public.formas_pagamento(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id);

ALTER TABLE ONLY public.despesas_recorrentes
    ADD CONSTRAINT despesas_recorrentes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_funcao_id_fkey FOREIGN KEY (funcao_id) REFERENCES public.funcoes(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.equipe
    ADD CONSTRAINT equipe_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estornos
    ADD CONSTRAINT estornos_lancamento_id_fkey FOREIGN KEY (lancamento_id) REFERENCES public.lancamentos(id);

ALTER TABLE ONLY public.estornos
    ADD CONSTRAINT estornos_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id);

ALTER TABLE ONLY public.estornos
    ADD CONSTRAINT estornos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estrategia_blocos
    ADD CONSTRAINT estrategia_blocos_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estrategia_blocos
    ADD CONSTRAINT estrategia_blocos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estrategia_etapas
    ADD CONSTRAINT estrategia_etapas_bloco_id_fkey FOREIGN KEY (bloco_id) REFERENCES public.estrategia_blocos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estrategia_etapas
    ADD CONSTRAINT estrategia_etapas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.estrategia_etapas
    ADD CONSTRAINT estrategia_etapas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.etapas_catalogo
    ADD CONSTRAINT etapas_catalogo_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.etapas_kanban
    ADD CONSTRAINT etapas_kanban_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.exp_guardrails
    ADD CONSTRAINT exp_guardrails_experimento_id_fkey FOREIGN KEY (experimento_id) REFERENCES public.growth_experimentos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.exp_guardrails
    ADD CONSTRAINT exp_guardrails_guardrail_id_fkey FOREIGN KEY (guardrail_id) REFERENCES public.guardrail_definicoes(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.exp_guardrails
    ADD CONSTRAINT exp_guardrails_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.fontes_video
    ADD CONSTRAINT fontes_video_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.fontes_video
    ADD CONSTRAINT fontes_video_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.fontes_video
    ADD CONSTRAINT fontes_video_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.formas_pagamento
    ADD CONSTRAINT formas_pagamento_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.formas_pagamento
    ADD CONSTRAINT formas_pagamento_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_conta_despesa_id_fkey FOREIGN KEY (conta_despesa_id) REFERENCES public.plano_contas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_forma_pagamento_id_fkey FOREIGN KEY (forma_pagamento_id) REFERENCES public.formas_pagamento(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.fornecedores
    ADD CONSTRAINT fornecedores_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funcoes
    ADD CONSTRAINT funcoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funil_etapas
    ADD CONSTRAINT funil_etapas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funil_etapas
    ADD CONSTRAINT funil_etapas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_etapa_ao_entrar_id_fkey FOREIGN KEY (etapa_ao_entrar_id) REFERENCES public.funil_etapas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_lista_pai_id_fkey FOREIGN KEY (lista_pai_id) REFERENCES public.funil_listas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.funil_listas
    ADD CONSTRAINT funil_listas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.funis
    ADD CONSTRAINT funis_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.funis
    ADD CONSTRAINT funis_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_alavancas
    ADD CONSTRAINT gm_alavancas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_alavancas
    ADD CONSTRAINT gm_alavancas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_cenarios
    ADD CONSTRAINT gm_cenarios_substitui_id_fkey FOREIGN KEY (substitui_id) REFERENCES public.gm_cenarios(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.gm_cenarios
    ADD CONSTRAINT gm_cenarios_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_config
    ADD CONSTRAINT gm_config_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_decisoes
    ADD CONSTRAINT gm_decisoes_cenario_id_fkey FOREIGN KEY (cenario_id) REFERENCES public.gm_cenarios(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.gm_decisoes
    ADD CONSTRAINT gm_decisoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_etapas
    ADD CONSTRAINT gm_etapas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.gm_funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_etapas
    ADD CONSTRAINT gm_etapas_ref2_id_fkey FOREIGN KEY (ref2_id) REFERENCES public.gm_etapas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.gm_etapas
    ADD CONSTRAINT gm_etapas_ref_id_fkey FOREIGN KEY (ref_id) REFERENCES public.gm_etapas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.gm_etapas
    ADD CONSTRAINT gm_etapas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_funis
    ADD CONSTRAINT gm_funis_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.gm_funis
    ADD CONSTRAINT gm_funis_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_modelos
    ADD CONSTRAINT gm_modelos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_valores
    ADD CONSTRAINT gm_valores_etapa_id_fkey FOREIGN KEY (etapa_id) REFERENCES public.gm_etapas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.gm_valores
    ADD CONSTRAINT gm_valores_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_cenario_id_fkey FOREIGN KEY (cenario_id) REFERENCES public.gm_cenarios(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_decisao_id_fkey FOREIGN KEY (decisao_id) REFERENCES public.gm_decisoes(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_metrica_id_fkey FOREIGN KEY (metrica_id) REFERENCES public.growth_metricas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_pesquisa_id_fkey FOREIGN KEY (pesquisa_id) REFERENCES public.pesquisas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_experimentos
    ADD CONSTRAINT growth_experimentos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.growth_metricas
    ADD CONSTRAINT growth_metricas_pai_id_fkey FOREIGN KEY (pai_id) REFERENCES public.growth_metricas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_metricas
    ADD CONSTRAINT growth_metricas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.growth_metricas
    ADD CONSTRAINT growth_metricas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_alertas
    ADD CONSTRAINT guardrail_alertas_experimento_id_fkey FOREIGN KEY (experimento_id) REFERENCES public.growth_experimentos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_alertas
    ADD CONSTRAINT guardrail_alertas_guardrail_id_fkey FOREIGN KEY (guardrail_id) REFERENCES public.guardrail_definicoes(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_alertas
    ADD CONSTRAINT guardrail_alertas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_definicoes
    ADD CONSTRAINT guardrail_definicoes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.guardrail_definicoes
    ADD CONSTRAINT guardrail_definicoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_observacoes
    ADD CONSTRAINT guardrail_observacoes_experimento_id_fkey FOREIGN KEY (experimento_id) REFERENCES public.growth_experimentos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_observacoes
    ADD CONSTRAINT guardrail_observacoes_guardrail_id_fkey FOREIGN KEY (guardrail_id) REFERENCES public.guardrail_definicoes(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.guardrail_observacoes
    ADD CONSTRAINT guardrail_observacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.heavyops_metas
    ADD CONSTRAINT heavyops_metas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.ia_perguntas
    ADD CONSTRAINT ia_perguntas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.importacoes
    ADD CONSTRAINT importacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.impostos_config
    ADD CONSTRAINT impostos_config_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.integracoes
    ADD CONSTRAINT integracoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.lancamentos
    ADD CONSTRAINT lancamentos_estorno_de_fkey FOREIGN KEY (estorno_de) REFERENCES public.lancamentos(id);

ALTER TABLE ONLY public.lancamentos
    ADD CONSTRAINT lancamentos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.metricas_anuncio_dia
    ADD CONSTRAINT metricas_anuncio_dia_anuncio_id_fkey FOREIGN KEY (anuncio_id) REFERENCES public.anuncios(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.metricas_anuncio_dia
    ADD CONSTRAINT metricas_anuncio_dia_importacao_id_fkey FOREIGN KEY (importacao_id) REFERENCES public.importacoes(id);

ALTER TABLE ONLY public.metricas_anuncio_dia
    ADD CONSTRAINT metricas_anuncio_dia_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.motivos_resultado
    ADD CONSTRAINT motivos_resultado_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.movimentacoes_bancarias
    ADD CONSTRAINT movimentacoes_bancarias_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id);

ALTER TABLE ONLY public.movimentacoes_bancarias
    ADD CONSTRAINT movimentacoes_bancarias_lancamento_id_fkey FOREIGN KEY (lancamento_id) REFERENCES public.lancamentos(id);

ALTER TABLE ONLY public.movimentacoes_bancarias
    ADD CONSTRAINT movimentacoes_bancarias_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_atividade_id_fkey FOREIGN KEY (atividade_id) REFERENCES public.projeto_atividades(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_destinatario_id_fkey FOREIGN KEY (destinatario_id) REFERENCES public.equipe(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notificacoes
    ADD CONSTRAINT notificacoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oferta_itens
    ADD CONSTRAINT oferta_itens_oferta_id_fkey FOREIGN KEY (oferta_id) REFERENCES public.ofertas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oferta_itens
    ADD CONSTRAINT oferta_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.oferta_itens
    ADD CONSTRAINT oferta_itens_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oferta_versoes
    ADD CONSTRAINT oferta_versoes_oferta_id_fkey FOREIGN KEY (oferta_id) REFERENCES public.ofertas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oferta_versoes
    ADD CONSTRAINT oferta_versoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.ofertas
    ADD CONSTRAINT ofertas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.ofertas
    ADD CONSTRAINT ofertas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_contrato_origem_id_fkey FOREIGN KEY (contrato_origem_id) REFERENCES public.contratos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_etapa_kanban_id_fkey FOREIGN KEY (etapa_kanban_id) REFERENCES public.etapas_kanban(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.oportunidades
    ADD CONSTRAINT oportunidades_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pagamentos_historicos
    ADD CONSTRAINT pagamentos_historicos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pagamentos_historicos
    ADD CONSTRAINT pagamentos_historicos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pagamentos_historicos
    ADD CONSTRAINT pagamentos_historicos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.partidas
    ADD CONSTRAINT partidas_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id);

ALTER TABLE ONLY public.partidas
    ADD CONSTRAINT partidas_conta_id_fkey FOREIGN KEY (conta_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.partidas
    ADD CONSTRAINT partidas_lancamento_id_fkey FOREIGN KEY (lancamento_id) REFERENCES public.lancamentos(id);

ALTER TABLE ONLY public.partidas
    ADD CONSTRAINT partidas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_pesquisa_id_fkey FOREIGN KEY (pesquisa_id) REFERENCES public.pesquisas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_envios
    ADD CONSTRAINT pesquisa_envios_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_insights
    ADD CONSTRAINT pesquisa_insights_metrica_id_fkey FOREIGN KEY (metrica_id) REFERENCES public.growth_metricas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pesquisa_insights
    ADD CONSTRAINT pesquisa_insights_pergunta_id_fkey FOREIGN KEY (pergunta_id) REFERENCES public.pesquisa_perguntas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pesquisa_insights
    ADD CONSTRAINT pesquisa_insights_pesquisa_id_fkey FOREIGN KEY (pesquisa_id) REFERENCES public.pesquisas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_insights
    ADD CONSTRAINT pesquisa_insights_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_perguntas
    ADD CONSTRAINT pesquisa_perguntas_pesquisa_id_fkey FOREIGN KEY (pesquisa_id) REFERENCES public.pesquisas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_perguntas
    ADD CONSTRAINT pesquisa_perguntas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_resposta_itens
    ADD CONSTRAINT pesquisa_resposta_itens_pergunta_id_fkey FOREIGN KEY (pergunta_id) REFERENCES public.pesquisa_perguntas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_resposta_itens
    ADD CONSTRAINT pesquisa_resposta_itens_resposta_id_fkey FOREIGN KEY (resposta_id) REFERENCES public.pesquisa_respostas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_resposta_itens
    ADD CONSTRAINT pesquisa_resposta_itens_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_respostas
    ADD CONSTRAINT pesquisa_respostas_envio_id_fkey FOREIGN KEY (envio_id) REFERENCES public.pesquisa_envios(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pesquisa_respostas
    ADD CONSTRAINT pesquisa_respostas_pesquisa_id_fkey FOREIGN KEY (pesquisa_id) REFERENCES public.pesquisas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisa_respostas
    ADD CONSTRAINT pesquisa_respostas_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pesquisa_respostas
    ADD CONSTRAINT pesquisa_respostas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pesquisas
    ADD CONSTRAINT pesquisas_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pesquisas
    ADD CONSTRAINT pesquisas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_etapa_id_fkey FOREIGN KEY (etapa_id) REFERENCES public.funil_etapas(id);

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil_historico
    ADD CONSTRAINT pessoa_funil_historico_funil_id_fkey FOREIGN KEY (funil_id) REFERENCES public.funis(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil_historico
    ADD CONSTRAINT pessoa_funil_historico_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil_historico
    ADD CONSTRAINT pessoa_funil_historico_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_funil
    ADD CONSTRAINT pessoa_funil_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_historico
    ADD CONSTRAINT pessoa_historico_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_lista
    ADD CONSTRAINT pessoa_lista_lista_id_fkey FOREIGN KEY (lista_id) REFERENCES public.funil_listas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_lista
    ADD CONSTRAINT pessoa_lista_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_lista
    ADD CONSTRAINT pessoa_lista_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_notas
    ADD CONSTRAINT pessoa_notas_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_notas
    ADD CONSTRAINT pessoa_notas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_toques
    ADD CONSTRAINT pessoa_toques_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pessoa_toques
    ADD CONSTRAINT pessoa_toques_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoa_toques
    ADD CONSTRAINT pessoa_toques_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id);

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_etapa_kanban_id_fkey FOREIGN KEY (etapa_kanban_id) REFERENCES public.etapas_kanban(id);

ALTER TABLE ONLY public.pessoas_mesclagens
    ADD CONSTRAINT pessoas_mesclagens_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_negocio_motivo_id_fkey FOREIGN KEY (negocio_motivo_id) REFERENCES public.motivos_resultado(id);

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_responsavel_comercial_id_fkey FOREIGN KEY (responsavel_comercial_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.pessoas
    ADD CONSTRAINT pessoas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.planejamento_mensal
    ADD CONSTRAINT planejamento_mensal_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_conta_pai_id_fkey FOREIGN KEY (conta_pai_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_conta_passivo_id_fkey FOREIGN KEY (conta_passivo_id) REFERENCES public.plano_contas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_rateio_regra_id_fkey FOREIGN KEY (rateio_regra_id) REFERENCES public.rateio_regras(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.plano_contas
    ADD CONSTRAINT plano_contas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_indicadores
    ADD CONSTRAINT plano_indicadores_objetivo_id_fkey FOREIGN KEY (objetivo_id) REFERENCES public.plano_objetivos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_indicadores
    ADD CONSTRAINT plano_indicadores_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.planos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_indicadores
    ADD CONSTRAINT plano_indicadores_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_metas
    ADD CONSTRAINT plano_metas_indicador_id_fkey FOREIGN KEY (indicador_id) REFERENCES public.plano_indicadores(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.plano_metas
    ADD CONSTRAINT plano_metas_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.planos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_metas
    ADD CONSTRAINT plano_metas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_objetivos
    ADD CONSTRAINT plano_objetivos_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.planos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plano_objetivos
    ADD CONSTRAINT plano_objetivos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.planos
    ADD CONSTRAINT planos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plataforma_formas_pagamento
    ADD CONSTRAINT plataforma_formas_pagamento_plataforma_id_fkey FOREIGN KEY (plataforma_id) REFERENCES public.plataformas_venda(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plataforma_formas_pagamento
    ADD CONSTRAINT plataforma_formas_pagamento_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.plataformas_venda
    ADD CONSTRAINT plataformas_venda_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_fonte_id_fkey FOREIGN KEY (fonte_id) REFERENCES public.fontes_video(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_importacao_id_fkey FOREIGN KEY (importacao_id) REFERENCES public.importacoes(id);

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.presencas_video
    ADD CONSTRAINT presencas_video_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.produto_plataforma
    ADD CONSTRAINT produto_plataforma_plataforma_id_fkey FOREIGN KEY (plataforma_id) REFERENCES public.plataformas_venda(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.produto_plataforma
    ADD CONSTRAINT produto_plataforma_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.produto_plataforma
    ADD CONSTRAINT produto_plataforma_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id);

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_modelo_projeto_id_fkey FOREIGN KEY (modelo_projeto_id) REFERENCES public.projeto_modelos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_campanha_bloco_id_fkey FOREIGN KEY (campanha_bloco_id) REFERENCES public.campanha_blocos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_pai_id_fkey FOREIGN KEY (pai_id) REFERENCES public.projeto_atividades(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_projeto_id_fkey FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projeto_atividades
    ADD CONSTRAINT projeto_atividades_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_modelo_atividades
    ADD CONSTRAINT projeto_modelo_atividades_modelo_id_fkey FOREIGN KEY (modelo_id) REFERENCES public.projeto_modelos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_modelo_atividades
    ADD CONSTRAINT projeto_modelo_atividades_pai_id_fkey FOREIGN KEY (pai_id) REFERENCES public.projeto_modelo_atividades(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_modelo_atividades
    ADD CONSTRAINT projeto_modelo_atividades_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projeto_modelo_atividades
    ADD CONSTRAINT projeto_modelo_atividades_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projeto_modelos
    ADD CONSTRAINT projeto_modelos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_contrato_id_fkey FOREIGN KEY (contrato_id) REFERENCES public.contratos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_modelo_id_fkey FOREIGN KEY (modelo_id) REFERENCES public.projeto_modelos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_responsavel_id_fkey FOREIGN KEY (responsavel_id) REFERENCES public.equipe(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.qualidade_regras
    ADD CONSTRAINT qualidade_regras_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.rateio_itens
    ADD CONSTRAINT rateio_itens_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES public.centros_custo(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.rateio_itens
    ADD CONSTRAINT rateio_itens_regra_id_fkey FOREIGN KEY (regra_id) REFERENCES public.rateio_regras(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.rateio_itens
    ADD CONSTRAINT rateio_itens_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.rateio_regras
    ADD CONSTRAINT rateio_regras_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.regras_contabilizacao
    ADD CONSTRAINT regras_contabilizacao_conta_credito_id_fkey FOREIGN KEY (conta_credito_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.regras_contabilizacao
    ADD CONSTRAINT regras_contabilizacao_conta_debito_id_fkey FOREIGN KEY (conta_debito_id) REFERENCES public.plano_contas(id);

ALTER TABLE ONLY public.regras_contabilizacao
    ADD CONSTRAINT regras_contabilizacao_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.responsavel_historico
    ADD CONSTRAINT responsavel_historico_aluno_id_fkey FOREIGN KEY (aluno_id) REFERENCES public.alunos(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.responsavel_historico
    ADD CONSTRAINT responsavel_historico_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.responsavel_historico
    ADD CONSTRAINT responsavel_historico_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.revops_config
    ADD CONSTRAINT revops_config_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.revops_visoes
    ADD CONSTRAINT revops_visoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.simulador_cenarios
    ADD CONSTRAINT simulador_cenarios_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.simulador_snapshots
    ADD CONSTRAINT simulador_snapshots_gm_cenario_fk FOREIGN KEY (cenario_id) REFERENCES public.gm_cenarios(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.simulador_snapshots
    ADD CONSTRAINT simulador_snapshots_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_conta_pagar_id_fkey FOREIGN KEY (conta_pagar_id) REFERENCES public.contas_pagar(id);

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_conta_receber_casa_fkey FOREIGN KEY (conta_receber_casa) REFERENCES public.contas_receber(id);

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_lancamento_origem_fkey FOREIGN KEY (lancamento_origem) REFERENCES public.lancamentos(id);

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_ws_casa_fkey FOREIGN KEY (ws_casa) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.transferencias_casa
    ADD CONSTRAINT transferencias_casa_ws_origem_fkey FOREIGN KEY (ws_origem) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.uso_eventos
    ADD CONSTRAINT uso_eventos_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.venda_atribuicoes
    ADD CONSTRAINT venda_atribuicoes_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.venda_atribuicoes
    ADD CONSTRAINT venda_atribuicoes_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_campanha_id_fkey FOREIGN KEY (campanha_id) REFERENCES public.campanhas(id);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_conta_bancaria_id_fkey FOREIGN KEY (conta_bancaria_id) REFERENCES public.contas_bancarias(id);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_pessoa_id_fkey FOREIGN KEY (pessoa_id) REFERENCES public.pessoas(id);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_plataforma_id_fkey FOREIGN KEY (plataforma_id) REFERENCES public.plataformas_venda(id);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id);

ALTER TABLE ONLY public.vendas
    ADD CONSTRAINT vendas_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.video_metricas_dia
    ADD CONSTRAINT video_metricas_dia_fonte_id_fkey FOREIGN KEY (fonte_id) REFERENCES public.fontes_video(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.video_metricas_dia
    ADD CONSTRAINT video_metricas_dia_importacao_id_fkey FOREIGN KEY (importacao_id) REFERENCES public.importacoes(id);

ALTER TABLE ONLY public.video_metricas_dia
    ADD CONSTRAINT video_metricas_dia_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.workspace_membros
    ADD CONSTRAINT workspace_membros_funcao_id_fkey FOREIGN KEY (funcao_id) REFERENCES public.funcoes(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.workspace_membros
    ADD CONSTRAINT workspace_membros_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.workspace_membros
    ADD CONSTRAINT workspace_membros_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_casa_de_fkey FOREIGN KEY (casa_de) REFERENCES public.workspaces(id);

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pacote_id_fkey FOREIGN KEY (pacote_id) REFERENCES public.pacotes_acesso(id) ON DELETE SET NULL;
