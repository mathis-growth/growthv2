-- v0.133 — Máquina de Conteúdo.
-- O "Planejamento de conteúdo" vira a Máquina de Conteúdo, seguindo a metodologia da Máquina Editorial de Aprendizado (V18):
--   território (linha editorial) → frente/subtema → formato de execução (No Quadro, Yap, Análise, Carrossel caderno, Série musical)
--   → quadro de autoridade (Repertório de Funis, Business Case, Analisando os Dados de um Funil, Growth na Prática)
--   → pauta com destino (Rebecka / Mathisa / Ambas), palavra-chave, pergunta de busca, intenção, classificação, score de 6 critérios (1 a 5)
--   → VALIDAR (escolha humana) → produção → publicação → fechamento semanal (retrospectiva, capacidade x meta, pré-pauta).
-- Também: questionário de persona/nicho, propostas de linha editorial (pela IA ou coladas) e o modelo V18 instalável por botão.
-- Tudo aditivo: nenhuma coluna existente muda de significado. Quem continua no método antigo (5 notas de 1 a 10) não é afetado.
-- Pode ser rodado de novo sem erro.

-- ---------- configuração do método ----------
alter table public.conteudo_config add column if not exists metodo text not null default 'notas5';
alter table public.conteudo_config drop constraint if exists conteudo_config_metodo_check;
alter table public.conteudo_config add constraint conteudo_config_metodo_check check (metodo in ('notas5', 'score6'));
alter table public.conteudo_config add column if not exists criterios_score text[] not null
  default array['Timing / pauta quente', 'Potencial estratégico', 'Potencial de impacto', 'Facilidade de execução', 'Robustez da evidência', 'Novidade / pouco explorado no Brasil'];
alter table public.conteudo_config drop constraint if exists conteudo_config_criterios_score_check;
alter table public.conteudo_config add constraint conteudo_config_criterios_score_check check (cardinality(criterios_score) = 6);
alter table public.conteudo_config add column if not exists destinos text[] not null default '{}';
alter table public.conteudo_config add column if not exists meta_semanal int check (meta_semanal is null or meta_semanal >= 0);
alter table public.conteudo_config add column if not exists dia_fechamento smallint not null default 6 check (dia_fechamento between 1 and 7); -- 1 = segunda … 6 = sábado, 7 = domingo
alter table public.conteudo_config add column if not exists tags text[] not null default '{}';
alter table public.conteudo_config add column if not exists linha jsonb not null default '{}'::jsonb; -- núcleo da marca: papel, tese, inimigo, frases, camadas, lentes
alter table public.conteudo_config add column if not exists modelo text; -- de onde veio a linha instalada (ex.: 'V18', 'proposta IA de 29/10')

-- ---------- territórios (linhas) e frentes (temas) ganham o que a metodologia pede ----------
alter table public.conteudo_linhas add column if not exists pergunta_central text;
alter table public.conteudo_linhas add column if not exists funcao text;
alter table public.conteudo_linhas add column if not exists papel_funil text;
alter table public.conteudo_linhas add column if not exists entra text;
alter table public.conteudo_linhas add column if not exists nao_entra text;
alter table public.conteudo_linhas add column if not exists cor text check (cor is null or cor ~ '^#[0-9a-fA-F]{6}$');
alter table public.conteudo_temas add column if not exists descricao text;
alter table public.conteudo_temas add column if not exists transversal boolean not null default false; -- camada transversal: atravessa territórios

-- ---------- formatos de execução e quadros de autoridade ----------
create table if not exists public.conteudo_formatos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  grupo text not null default 'formato' check (grupo in ('formato', 'quadro')), -- formato = como é feito; quadro = formato de autoridade
  nome text not null,
  funcao text,
  execucao text,
  melhor_uso text,
  estrutura text,
  tipo_midia text check (tipo_midia is null or tipo_midia in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live')),
  vezes_semana int check (vezes_semana is null or vezes_semana >= 0),
  dias_semana smallint[] not null default '{}' check (dias_semana <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  cor text not null default '#521F32' check (cor ~ '^#[0-9a-fA-F]{6}$'),
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create unique index if not exists conteudo_formatos_nome_uq on public.conteudo_formatos (workspace_id, grupo, lower(nome));

-- ---------- a pauta da Máquina ----------
alter table public.conteudos add column if not exists formato_id uuid references public.conteudo_formatos(id) on delete set null;
alter table public.conteudos add column if not exists quadro_id uuid references public.conteudo_formatos(id) on delete set null;
alter table public.conteudos add column if not exists destino text;
alter table public.conteudos add column if not exists palavra_chave text;
alter table public.conteudos add column if not exists palavras_relacionadas text[] not null default '{}';
alter table public.conteudos add column if not exists perguntas_busca text[] not null default '{}';
alter table public.conteudos add column if not exists intencao text check (intencao is null or intencao in ('aprender', 'comparar', 'diagnosticar', 'decidir', 'calcular', 'implementar', 'contratar'));
alter table public.conteudos add column if not exists entidade text;
alter table public.conteudos add column if not exists problema text;
alter table public.conteudos add column if not exists achado text;            -- "o que encontrei"
alter table public.conteudos add column if not exists classificacao text check (classificacao is null or classificacao in ('evidencia', 'tendencia', 'discussao', 'hype'));
alter table public.conteudos add column if not exists fundamento text check (fundamento is null or fundamento in ('interno', 'externo', 'ambos'));
alter table public.conteudos add column if not exists evidencia text;
alter table public.conteudos add column if not exists s1 smallint check (s1 between 1 and 5);
alter table public.conteudos add column if not exists s2 smallint check (s2 between 1 and 5);
alter table public.conteudos add column if not exists s3 smallint check (s3 between 1 and 5);
alter table public.conteudos add column if not exists s4 smallint check (s4 between 1 and 5);
alter table public.conteudos add column if not exists s5 smallint check (s5 between 1 and 5);
alter table public.conteudos add column if not exists s6 smallint check (s6 between 1 and 5);
alter table public.conteudos add column if not exists score_notas text;       -- justificativas curtas das notas
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'conteudos' and column_name = 'score_total') then
    alter table public.conteudos add column score_total smallint generated always as (case when s1 is not null and s2 is not null and s3 is not null and s4 is not null and s5 is not null and s6 is not null then s1 + s2 + s3 + s4 + s5 + s6 end) stored;
  end if;
end $$;
alter table public.conteudos add column if not exists tags text[] not null default '{}';
alter table public.conteudos add column if not exists dia_semana smallint check (dia_semana between 1 and 7);
alter table public.conteudos add column if not exists validado boolean not null default false;
alter table public.conteudos add column if not exists validado_em timestamptz;
alter table public.conteudos add column if not exists hook text;
alter table public.conteudos add column if not exists tese text;
alter table public.conteudos add column if not exists cta text;
alter table public.conteudos add column if not exists objetivo text;
alter table public.conteudos add column if not exists estrutura text check (estrutura is null or estrutura in ('aida', 'vida_real', 'case', 'funil', 'livre'));
alter table public.conteudos add column if not exists estrutura_notas jsonb not null default '{}'::jsonb;
alter table public.conteudos add column if not exists obs_producao text;
alter table public.conteudos add column if not exists decisao text check (decisao is null or decisao in ('manter', 'aprofundar', 'testar', 'descartar'));
alter table public.conteudos add column if not exists aprendizado text;
create index if not exists conteudos_validado on public.conteudos (workspace_id, validado_em);

-- ---------- fechamento semanal ----------
create table if not exists public.conteudo_fechamentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  semana_ini date not null check (extract(isodow from semana_ini) = 1),
  resumo jsonb not null default '{}'::jsonb,       -- foto dos números no momento do fechamento
  retro jsonb not null default '{}'::jsonb,        -- respostas da retrospectiva
  objetivo_proxima text,
  pre_pauta text,
  fechado_por uuid,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (workspace_id, semana_ini)
);

-- ---------- persona/nicho e propostas de linha editorial ----------
create table if not exists public.conteudo_personas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null default 'Persona principal',
  respostas jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create table if not exists public.conteudo_linha_propostas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  persona_id uuid references public.conteudo_personas(id) on delete set null,
  origem text not null default 'ia' check (origem in ('ia', 'colada', 'modelo')),
  modelo_ia text,
  proposta jsonb not null,
  status text not null default 'proposta' check (status in ('proposta', 'aplicada', 'descartada')),
  criado_em timestamptz not null default now(),
  aplicada_em timestamptz
);

-- ---------- segurança: mesmo padrão das outras tabelas de conteúdo ----------
do $$
declare t text;
begin
  foreach t in array array['conteudo_formatos', 'conteudo_fechamentos', 'conteudo_personas', 'conteudo_linha_propostas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_acesso', t);
    execute format('create policy %I on public.%I for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id))', t || '_acesso', t);
    execute format('drop policy if exists perm_ler on public.%I', t);
    execute format('drop policy if exists perm_inserir on public.%I', t);
    execute format('drop policy if exists perm_alterar on public.%I', t);
    execute format('drop policy if exists perm_excluir on public.%I', t);
    execute format('create policy perm_ler on public.%I as restrictive for select to authenticated using (perm(workspace_id, ''ler'', array[''mkt'',''adm'']))', t);
    execute format('create policy perm_inserir on public.%I as restrictive for insert to authenticated with check (perm(workspace_id, ''editar'', array[''mkt'']))', t);
    execute format('create policy perm_alterar on public.%I as restrictive for update to authenticated using (perm(workspace_id, ''editar'', array[''mkt''])) with check (perm(workspace_id, ''editar'', array[''mkt'']))', t);
    execute format('create policy perm_excluir on public.%I as restrictive for delete to authenticated using (perm(workspace_id, ''editar'', array[''mkt'']))', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- ---------- regras do Kanban, agora sabendo qual é o método ----------
-- notas5 (padrão antigo): igual a antes. score6 (Máquina V18): para virar pauta, 6 notas de 1 a 5 + território/frente + destino
-- (se houver destinos cadastrados) + formato (se houver formatos); para produzir, VALIDAR marcado + canal.
create or replace function public.conteudo_valida() returns trigger
language plpgsql security definer set search_path = public as $$
declare pos int; tem_ideia boolean; tem_pauta boolean; met text; dests text[]; tem_formatos boolean;
begin
  if new.tema_id is not null and not exists (select 1 from conteudo_temas where id = new.tema_id and workspace_id = new.workspace_id) then
    raise exception 'O tema precisa pertencer ao mesmo workspace'; end if;
  if new.responsavel_id is not null and not exists (select 1 from equipe where id = new.responsavel_id and workspace_id = new.workspace_id) then
    raise exception 'O responsável precisa ser da equipe deste workspace'; end if;
  if new.formato_id is not null and not exists (select 1 from conteudo_formatos where id = new.formato_id and workspace_id = new.workspace_id and grupo = 'formato') then
    raise exception 'O formato precisa ser um formato deste workspace'; end if;
  if new.quadro_id is not null and not exists (select 1 from conteudo_formatos where id = new.quadro_id and workspace_id = new.workspace_id and grupo = 'quadro') then
    raise exception 'O quadro de autoridade precisa ser deste workspace'; end if;
  select coalesce(c.metodo, 'notas5'), coalesce(c.destinos, '{}') into met, dests from conteudo_config c where c.workspace_id = new.workspace_id;
  met := coalesce(met, 'notas5'); dests := coalesce(dests, '{}');
  new.destino := nullif(trim(coalesce(new.destino, '')), '');
  if new.destino is not null and cardinality(dests) > 0 and not (lower(new.destino) = any (select lower(x) from unnest(dests) x)) then
    raise exception 'Destino "%" não está entre os destinos cadastrados (%)', new.destino, array_to_string(dests, ', '); end if;
  if new.destino is not null and cardinality(dests) > 0 then select x into new.destino from unnest(dests) x where lower(x) = lower(new.destino) limit 1; end if;
  new.palavra_chave := nullif(trim(coalesce(new.palavra_chave, '')), '');
  new.tags := coalesce((select array_agg(distinct trim(x)) from unnest(new.tags) x where trim(x) <> ''), '{}');
  if new.validado and (tg_op = 'INSERT' or not old.validado) then new.validado_em := coalesce(new.validado_em, now()); end if;
  if not new.validado then new.validado_em := null; end if;
  pos := array_position(array['ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado'], new.status);
  if pos is not null then
    if met = 'score6' then
      tem_formatos := exists (select 1 from conteudo_formatos where workspace_id = new.workspace_id and grupo = 'formato' and ativo);
      if pos >= 2 and num_nonnulls(new.s1, new.s2, new.s3, new.s4, new.s5, new.s6) < 6 then raise exception 'Dê as 6 notas (1 a 5) do score antes de aprovar a pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o território e a frente antes de aprovar a pauta'; end if;
      if pos >= 2 and cardinality(dests) > 0 and new.destino is null then raise exception 'Escolha o destino (%) antes de aprovar a pauta', array_to_string(dests, ', '); end if;
      if pos >= 2 and tem_formatos and new.formato_id is null then raise exception 'Escolha o formato antes de aprovar a pauta'; end if;
      if pos >= 3 and not new.validado then raise exception 'Marque VALIDAR antes de produzir: a escolha é sua, não do ranking'; end if;
    else
      tem_ideia := num_nonnulls(new.ideia_n1, new.ideia_n2, new.ideia_n3, new.ideia_n4, new.ideia_n5) = 5;
      tem_pauta := num_nonnulls(new.pauta_n1, new.pauta_n2, new.pauta_n3, new.pauta_n4, new.pauta_n5) = 5;
      if pos >= 2 and not tem_ideia then raise exception 'Dê as 5 notas da ideia antes de aprová-la como pauta'; end if;
      if pos >= 2 and new.tema_id is null then raise exception 'Escolha o tema antes de aprovar a pauta'; end if;
      if pos >= 3 and not tem_pauta then raise exception 'Dê as 5 notas da pauta antes de produzir'; end if;
    end if;
    if pos >= 3 and cardinality(new.canais) = 0 then raise exception 'Marque pelo menos um canal antes de produzir'; end if;
    if pos >= 4 and (new.copy_url is null or new.midia_url is null) then raise exception 'Informe o link da copy e o link da mídia para marcar como pronto'; end if;
    if pos >= 5 and new.data_publicacao is null then raise exception 'Informe a data de publicação para agendar'; end if;
  end if;
  if new.data_publicacao is not null and new.dia_semana is null then new.dia_semana := extract(isodow from new.data_publicacao)::smallint; end if;
  if new.status = 'publicado' then new.publicado_em := coalesce(new.publicado_em, now()); else new.publicado_em := null; end if;
  new.atualizado_em := now();
  return new;
end $$;
revoke execute on function public.conteudo_valida() from public, anon, authenticated;

-- ---------- o modelo V18 (Rebecka Cappello / Mathisa) ----------
-- Fonte: "Linha Editorial V18" e "Metodologia Própria — Máquina Editorial de Aprendizado" (Google Drive).
-- O agrupamento dos temas de Dados + IA e de Vida Real & Crenças em frentes é uma organização para o Kanban, editável.
create or replace function public.conteudo_modelo_v18() returns jsonb
language sql immutable set search_path = public as $f$
select $j${
  "nome": "Linha Editorial V18",
  "linha": {
    "papel": "Ajudar negócios digitais a encontrar alavancas eficientes e lucrativas de crescimento, usando estratégia, dados, comportamento do cliente, experiência, produto e IA para decidir com mais segurança onde agir.",
    "tese": "Growth não começa na escala. Começa no aprendizado.",
    "sintese": "Encontrar alavancas eficientes e lucrativas em negócios digitais.",
    "visao": "Ajudar a construir negócios sólidos, lucrativos e sustentáveis, capazes de atravessar ciclos de mercado e continuar crescendo com inteligência, sem depender de decisões impulsivas ou de empilhamento de estratégias sem contexto.",
    "objetivo": "Aumentar resultados com menos desperdício, mais clareza, melhor uso de recursos e sustentabilidade de longo prazo.",
    "inimigo": "A Lógica do Próximo",
    "inimigo_descricao": "Buscar sempre a próxima campanha, o próximo funil, a próxima ferramenta, o próximo canal, a próxima automação ou a próxima IA sem antes entender profundamente o que o negócio realmente precisa.",
    "nicho": "Negócios digitais e infoprodutores",
    "frase_guia": "Vida Real & Crenças aproxima. Estratégia e Negócios organizam o pensamento. Dados + IA ampliam a capacidade de enxergar. A Mathisa transforma diagnóstico e estratégia em implementação e prova.",
    "assinatura": "Cê acha ou tem dado?",
    "estruturas": ["AIDA invisível: Atenção → Interesse + Desejo → Ação", "Vida Real → Tensão → Crença → Ponte → Negócio → Conclusão", "Case: Problema → Diagnóstico → Solução → Implementação → Resultado/Aprendizado"],
    "lentes": ["Comportamento + Comunicação", "Finanças", "Dados", "IA", "Growth"],
    "regra_destino": "Responde “como pensar?” → Rebecka. Responde “como fizemos?” → Mathisa. Responde as duas coisas → Ambas.",
    "frases": [
      "Growth não começa na escala. Começa no aprendizado.",
      "A métrica é a pista. Não é a resposta.",
      "Escalar antes de entender é errar mais rápido.",
      "Antes de adicionar uma nova estratégia, descubra se existe dinheiro escondido naquilo que você já construiu.",
      "O problema não é buscar o próximo. É precisar do próximo porque você não sabe o que fazer com o que já tem.",
      "Não é parar de buscar o próximo. É saber quando o próximo é realmente necessário.",
      "IA sem infraestrutura vira ferramenta.",
      "Antes de colocar IA no negócio, construa o terreno onde ela consegue pensar.",
      "Automação não escala negócio. Estratégia sim.",
      "Growth não é otimizar campanha. É otimizar o negócio.",
      "Campanha é uma alavanca. O negócio é o sistema.",
      "Marketing sem Finanças mede atividade. Marketing conectado a Finanças mede criação de valor.",
      "ROAS é uma métrica de Marketing. Lucro é uma métrica de negócio.",
      "Faturamento não prova eficiência. Margem e retorno ajudam a provar."
    ]
  },
  "destinos": ["Rebecka", "Mathisa", "Ambas"],
  "meta_semanal": 12,
  "dia_fechamento": 6,
  "criterios_score": ["Timing / pauta quente", "Potencial estratégico", "Potencial de impacto", "Facilidade de execução", "Robustez da evidência", "Novidade / pouco explorado no Brasil"],
  "tags": ["Cê acha ou tem dado?", "Lógica do Próximo", "Case", "Collab", "Animação", "Humor", "Fundo de funil"],
  "territorios": [
    {"nome": "Estratégia", "cor": "#521F32", "pergunta": "O que podemos fazer para melhorar o negócio, as vendas e a resposta do mercado — e por quê?",
     "frentes": [
       {"nome": "A — Comportamento do consumidor + Comunicação", "descricao": "Psicologia e comportamento do consumidor, percepção de valor, vieses, motivação, decisão, copy, narrativa, mensagem, persuasão, posicionamento e mecanismos."},
       {"nome": "B — Hipóteses + Experimentação", "descricao": "Formulação de hipóteses, desenho de experimentos, priorização, métrica primária, guardrails, testes e análise de resultado."},
       {"nome": "C — Oferta + Posicionamento + Mecanismos", "descricao": "Oferta, proposta de valor, diferenciação, promessa, mecanismos, pricing, percepção de valor e arquitetura de produtos."},
       {"nome": "D — Estratégia comercial, Marketing e Vendas", "descricao": "Canais, funis, lançamentos, perpétuo, webinar, eventos, vendas consultivas, aquisição, monetização, ascensão, recompra e recuperação."},
       {"nome": "E — Estratégia de melhoria do negócio", "descricao": "Diagnóstico estratégico: gargalos, oportunidades, hipóteses, priorização de alavancas, o que otimizar ou construir."}]},
    {"nome": "Negócios", "cor": "#1F4E52", "pergunta": "Como construir um negócio digital eficiente, lucrativo, sustentável e capaz de crescer continuamente?",
     "frentes": [
       {"nome": "Growth", "descricao": "North Star Metric, árvore de métricas, drivers, guardrails, aquisição, ativação, Momento Aha, retenção, churn, recompra, indicação, expansão, LTV, loops e alavancas."},
       {"nome": "Finanças e economia do crescimento", "descricao": "Receita, margem, lucro, CAC, CAC marginal, LTV:CAC, payback, unit economics, caixa, forecast, rentabilidade e alocação de capital."},
       {"nome": "Gestão e modelo de negócio", "descricao": "Modelo de negócio, produto, monetização, operação, capacidade, recorrência, portfólio, experiência, canais e sustentabilidade do crescimento."},
       {"nome": "Empreendedorismo", "descricao": "Construir e tocar o próprio negócio: decisões de fundadora, riscos, equipe, sociedade, crescimento com sustentabilidade."}]},
    {"nome": "Dados + IA", "cor": "#2F3A6B", "pergunta": "Como criar a infraestrutura e a inteligência necessárias para enxergar, medir, automatizar e melhorar o negócio?",
     "frentes": [
       {"nome": "Tracking e infraestrutura de dados", "descricao": "Tracking e rastreamento, infraestrutura de dados, banco de dados e modelagem, ETL/ELT."},
       {"nome": "Integrações, CRM e automações", "descricao": "Integração de fontes, CRM, automações e alertas."},
       {"nome": "Dashboards, BI e qualidade do dado", "descricao": "Dashboards e BI, qualidade e governança, aplicação dos dados à tomada de decisão."},
       {"nome": "IA aplicada e agentes", "descricao": "Agentes, IA aplicada à análise, inteligência contínua, human in the loop."}]},
    {"nome": "Vida Real & Crenças", "cor": "#8A5A12", "pergunta": "Que experiências, crenças e repertório explicam como eu penso estratégia, negócios, dados e crescimento?",
     "frentes": [
       {"nome": "MBA, estudos e repertório", "descricao": "Estudos, leituras, repertório e curiosidade."},
       {"nome": "Construção da Mathisa e bastidores", "descricao": "Construção da Mathisa e do Growth Brain, bastidores de clientes e projetos."},
       {"nome": "Carreira e transição", "descricao": "Carreira, transição profissional, coragem e inseguranças."},
       {"nome": "Maternidade, família e rotina", "descricao": "Maternidade, família, rotina, tempo e trabalhar com o marido."},
       {"nome": "Hobbies e criatividade", "descricao": "Hobbies, curiosidade e criatividade como parte da personalidade."}]}
  ],
  "camadas": [
    {"nome": "First Principles + Contexto"}, {"nome": "Finanças para Marketing / Economia do Growth"}, {"nome": "Growth Operations"},
    {"nome": "Customer behavior & experience"}, {"nome": "Experimentação & aprendizado contínuo"}, {"nome": "Encontrabilidade (SEO, Social Search e AI Search)"}
  ],
  "formatos": [
    {"nome": "No Quadro / Tablet", "funcao": "Mostrar como pensar.", "execucao": "Quadro branco ou tablet, com raciocínio desenhado, fluxos, métricas, árvores e decomposição de problemas.", "melhor_uso": "Conceitos, frameworks, métricas, First Principles, processos e explicações estruturadas.", "tipo_midia": "reels", "cor": "#521F32"},
    {"nome": "Yap Content", "funcao": "Conversar, conectar e argumentar.", "execucao": "Sentada no seu ambiente, falando direto com a câmera, tom próximo, autoral e argumentativo.", "melhor_uso": "Teses, crenças, opiniões, provocações, vida real, repertório, estratégia e reflexões.", "tipo_midia": "reels", "cor": "#1F4E52"},
    {"nome": "Análise", "funcao": "Mostrar como eu analiso.", "execucao": "Analisar um negócio digital, campanha, funil, dashboard, fala, conteúdo, case ou estratégia.", "melhor_uso": "Data cases, diagnóstico, comparação, reação com profundidade, pontos cegos e alavancas.", "tipo_midia": "reels", "cor": "#2F3A6B"},
    {"nome": "Carrossel caderno", "funcao": "Explicar em páginas, como anotação de caderno.", "execucao": "Carrossel com estética de caderno; pode ter versão animada.", "melhor_uso": "Frameworks, passo a passo, comparações e resumos que a pessoa salva.", "tipo_midia": "carrossel", "cor": "#8A5A12"},
    {"nome": "Série musical (IA)", "funcao": "Humor e alcance: um tema do negócio virando música sertaneja.", "execucao": "Música sertaneja criada com IA sobre um tema, com vídeo feito em IA.", "melhor_uso": "Alcance, compartilhamento e identificação, com humor.", "tipo_midia": "reels", "vezes_semana": 1, "cor": "#6B2F5A"}
  ],
  "quadros": [
    {"nome": "Repertório de Funis", "funcao": "Como esse funil funciona, para que serve e quando pode fazer sentido?", "estrutura": "funcionamento → etapas/variações → contexto de uso → pré-requisitos → comportamento/comunicação → dados a observar → limitações/riscos → possibilidades de aplicação"},
    {"nome": "Business Case", "funcao": "Onde pode estar o problema e como eu investigaria e tentaria resolvê-lo?", "estrutura": "problema → perguntas e dados necessários → investigação → hipóteses → solução/experimento → métricas e guardrails → impacto financeiro esperado (hipótese)"},
    {"nome": "Analisando os Dados de um Funil", "funcao": "O que os números estão contando?", "estrutura": "aquisição → captura → qualificação → engajamento → oferta → venda → CAC → ativação → reembolso → retenção → LTV → margem"},
    {"nome": "Growth na Prática", "funcao": "Como criamos estrutura para enxergar, medir ou resolver isso?", "estrutura": "problema de negócio → informação necessária → diagnóstico → solução/infraestrutura → implementação → visibilidade obtida → decisão possível → resultado/aprendizado"}
  ]
}$j$::jsonb
$f$;

-- ---------- aplicar uma linha editorial (do modelo V18, de uma proposta da IA ou colada) ----------
-- Não apaga nada: cria o que falta e atualiza pelo nome (território, frente, formato e quadro). Devolve o que fez.
create or replace function public.conteudo_aplicar_linha(p_ws uuid, p_linha jsonb, p_modelo text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t jsonb; fr jsonb; lid uuid; i int := 0; j int; n_t int := 0; n_f int := 0; n_fm int := 0; g text; it jsonb; arr jsonb;
begin
  if auth.uid() is not null and not perm(p_ws, 'editar', array['mkt']) then raise exception 'Sem permissão para editar o conteúdo deste cliente'; end if;
  if jsonb_typeof(p_linha -> 'territorios') is distinct from 'array' or jsonb_array_length(p_linha -> 'territorios') = 0 then
    raise exception 'A linha editorial precisa de pelo menos um território'; end if;
  if jsonb_array_length(p_linha -> 'territorios') > 6 then raise exception 'Use no máximo 6 territórios (a metodologia recomenda 3 ou 4)'; end if;

  insert into conteudo_config (workspace_id) values (p_ws) on conflict (workspace_id) do nothing;
  update conteudo_config set
    metodo = 'score6',
    linha = coalesce(p_linha -> 'linha', linha),
    destinos = coalesce((select array_agg(trim(x)) from jsonb_array_elements_text(p_linha -> 'destinos') x where trim(x) <> ''), destinos),
    meta_semanal = coalesce((p_linha ->> 'meta_semanal')::int, meta_semanal),
    dia_fechamento = coalesce((p_linha ->> 'dia_fechamento')::smallint, dia_fechamento),
    tags = coalesce((select array_agg(distinct trim(x)) from jsonb_array_elements_text(p_linha -> 'tags') x where trim(x) <> ''), tags),
    criterios_score = case when jsonb_array_length(coalesce(p_linha -> 'criterios_score', '[]')) = 6
                           then (select array_agg(x) from jsonb_array_elements_text(p_linha -> 'criterios_score') x) else criterios_score end,
    modelo = coalesce(p_modelo, p_linha ->> 'nome', modelo)
  where workspace_id = p_ws;

  for t in select * from jsonb_array_elements(p_linha -> 'territorios') loop
    continue when coalesce(trim(t ->> 'nome'), '') = '';
    i := i + 1;
    select id into lid from conteudo_linhas where workspace_id = p_ws and lower(nome) = lower(trim(t ->> 'nome'));
    if lid is null then
      insert into conteudo_linhas (workspace_id, nome, ordem) values (p_ws, trim(t ->> 'nome'), i) returning id into lid; n_t := n_t + 1;
    end if;
    update conteudo_linhas set ativo = true, ordem = i,
      descricao = coalesce(nullif(t ->> 'descricao', ''), descricao), pergunta_central = coalesce(nullif(t ->> 'pergunta', ''), pergunta_central),
      funcao = coalesce(nullif(t ->> 'funcao', ''), funcao), papel_funil = coalesce(nullif(t ->> 'papel_funil', ''), papel_funil),
      entra = coalesce(nullif(t ->> 'entra', ''), entra), nao_entra = coalesce(nullif(t ->> 'nao_entra', ''), nao_entra),
      cor = case when t ->> 'cor' ~ '^#[0-9a-fA-F]{6}$' then t ->> 'cor' else cor end
    where id = lid;
    j := 0;
    for fr in select * from jsonb_array_elements(coalesce(t -> 'frentes', '[]')) loop
      continue when coalesce(trim(fr ->> 'nome'), '') = '';
      j := j + 1;
      if exists (select 1 from conteudo_temas where workspace_id = p_ws and lower(nome) = lower(trim(fr ->> 'nome'))) then
        update conteudo_temas set linha_id = lid, ativo = true, transversal = false, descricao = coalesce(nullif(fr ->> 'descricao', ''), descricao),
          cor = case when t ->> 'cor' ~ '^#[0-9a-fA-F]{6}$' then t ->> 'cor' else cor end
        where workspace_id = p_ws and lower(nome) = lower(trim(fr ->> 'nome'));
      else
        insert into conteudo_temas (workspace_id, linha_id, nome, descricao, prioridade, cor)
        values (p_ws, lid, trim(fr ->> 'nome'), nullif(fr ->> 'descricao', ''), 2, case when t ->> 'cor' ~ '^#[0-9a-fA-F]{6}$' then t ->> 'cor' else '#521F32' end);
        n_f := n_f + 1;
      end if;
    end loop;
  end loop;

  for fr in select * from jsonb_array_elements(coalesce(p_linha -> 'camadas', '[]')) loop
    continue when coalesce(trim(fr ->> 'nome'), '') = '';
    if exists (select 1 from conteudo_temas where workspace_id = p_ws and lower(nome) = lower(trim(fr ->> 'nome'))) then
      update conteudo_temas set transversal = true, ativo = true, descricao = coalesce(nullif(fr ->> 'descricao', ''), descricao) where workspace_id = p_ws and lower(nome) = lower(trim(fr ->> 'nome'));
    else
      insert into conteudo_temas (workspace_id, nome, descricao, prioridade, cor, transversal) values (p_ws, trim(fr ->> 'nome'), nullif(fr ->> 'descricao', ''), 2, '#6b6f78', true);
      n_f := n_f + 1;
    end if;
  end loop;

  foreach g in array array['formato', 'quadro'] loop
    arr := coalesce(p_linha -> (case g when 'formato' then 'formatos' else 'quadros' end), '[]'); j := 0;
    for it in select * from jsonb_array_elements(arr) loop
      continue when coalesce(trim(it ->> 'nome'), '') = '';
      j := j + 1;
      insert into conteudo_formatos (workspace_id, grupo, nome, ordem) values (p_ws, g, trim(it ->> 'nome'), j)
      on conflict (workspace_id, grupo, lower(nome)) do nothing;
      if found then n_fm := n_fm + 1; end if;
      update conteudo_formatos set ativo = true, ordem = j,
        funcao = coalesce(nullif(it ->> 'funcao', ''), funcao), execucao = coalesce(nullif(it ->> 'execucao', ''), execucao),
        melhor_uso = coalesce(nullif(it ->> 'melhor_uso', ''), melhor_uso), estrutura = coalesce(nullif(it ->> 'estrutura', ''), estrutura),
        tipo_midia = case when it ->> 'tipo_midia' in ('video', 'reels', 'carrossel', 'imagem', 'story', 'artigo', 'newsletter', 'live') then it ->> 'tipo_midia' else tipo_midia end,
        vezes_semana = coalesce((it ->> 'vezes_semana')::int, vezes_semana),
        cor = case when it ->> 'cor' ~ '^#[0-9a-fA-F]{6}$' then it ->> 'cor' else cor end
      where workspace_id = p_ws and grupo = g and lower(nome) = lower(trim(it ->> 'nome'));
    end loop;
  end loop;

  return jsonb_build_object('territorios_novos', n_t, 'frentes_novas', n_f, 'formatos_novos', n_fm,
    'territorios', (select count(*) from conteudo_linhas where workspace_id = p_ws and ativo),
    'formatos', (select count(*) from conteudo_formatos where workspace_id = p_ws and ativo and grupo = 'formato'));
end $$;

create or replace function public.conteudo_instalar_v18(p_ws uuid) returns jsonb
language sql security definer set search_path = public as $$ select conteudo_aplicar_linha(p_ws, conteudo_modelo_v18(), 'V18') $$;

create or replace function public.conteudo_aplicar_proposta(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare pr conteudo_linha_propostas; r jsonb;
begin
  select * into pr from conteudo_linha_propostas where id = p_id;
  if pr.id is null then raise exception 'Proposta não encontrada'; end if;
  r := conteudo_aplicar_linha(pr.workspace_id, pr.proposta, 'Proposta ' || pr.origem || ' de ' || to_char(pr.criado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'));
  update conteudo_linha_propostas set status = 'descartada' where workspace_id = pr.workspace_id and status = 'aplicada' and id <> p_id;
  update conteudo_linha_propostas set status = 'aplicada', aplicada_em = now() where id = p_id;
  return r;
end $$;

-- ---------- números da semana (para o fechamento de sábado) ----------
-- Semana de segunda (p_ini) a domingo. Fatos do banco; nada é estimado.
create or replace function public.conteudo_semana(p_ws uuid, p_ini date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare fim date := p_ini + 6; cfg conteudo_config; r jsonb;
begin
  if auth.uid() is not null and not perm(p_ws, 'ler', array['mkt', 'adm']) then raise exception 'Sem acesso ao conteúdo deste cliente'; end if;
  if extract(isodow from p_ini) <> 1 then raise exception 'A semana começa na segunda-feira'; end if;
  select * into cfg from conteudo_config where workspace_id = p_ws;
  with c as (
    select c.*, coalesce(c.data_publicacao, (c.publicado_em at time zone 'America/Sao_Paulo')::date) as dpub,
           t.nome as frente, l.nome as territorio, f.nome as formato_nome, q.nome as quadro_nome
    from conteudos c left join conteudo_temas t on t.id = c.tema_id left join conteudo_linhas l on l.id = t.linha_id
    left join conteudo_formatos f on f.id = c.formato_id left join conteudo_formatos q on q.id = c.quadro_id
    where c.workspace_id = p_ws and c.status <> 'arquivado'
  ), sem as (select * from c where dpub between p_ini and fim),
  pubs as (select p.*, (coalesce(p.curtidas, 0) + coalesce(p.comentarios, 0) + coalesce(p.compartilhamentos, 0) + coalesce(p.salvamentos, 0)) as inter
           from conteudo_publicacoes p where p.workspace_id = p_ws and p.status = 'publicada' and p.data_publicacao between p_ini and fim)
  select jsonb_build_object(
    'semana', jsonb_build_object('ini', p_ini, 'fim', fim),
    'meta', cfg.meta_semanal,
    'planejados', (select count(*) from sem),
    'publicados', (select count(*) from sem where status = 'publicado'),
    'validadas_na_semana', (select count(*) from c where validado and (validado_em at time zone 'America/Sao_Paulo')::date between p_ini and fim),
    'banco_forte', (select count(*) from c where validado and status in ('ideia', 'pauta', 'producao', 'pronto')),
    'ranking', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'titulo', titulo, 'score', score_total, 'impacto', s3, 'destino', destino, 'territorio', territorio, 'frente', frente, 'formato', formato_nome, 'status', status) order by score_total desc nulls last, s3 desc nulls last, criado_em)
                         from c where validado and status in ('ideia', 'pauta', 'producao', 'pronto')), '[]'),
    'reservas', coalesce((select jsonb_agg(x order by (x ->> 'score')::int desc nulls last) from (
                         select jsonb_build_object('id', id, 'titulo', titulo, 'score', score_total, 'impacto', s3, 'destino', destino, 'territorio', territorio, 'formato', formato_nome) x
                         from c where not validado and status in ('ideia', 'pauta') and score_total is not null order by score_total desc, s3 desc nulls last limit 10) z), '[]'),
    'por_territorio', coalesce((select jsonb_agg(jsonb_build_object('nome', l.nome, 'planejados', (select count(*) from sem where sem.territorio = l.nome), 'banco', (select count(*) from c where c.territorio = l.nome and c.status in ('ideia', 'pauta'))) order by l.ordem, l.nome)
                         from conteudo_linhas l where l.workspace_id = p_ws and l.ativo), '[]'),
    'por_formato', coalesce((select jsonb_agg(jsonb_build_object('nome', f.nome, 'planejados', (select count(*) from sem where sem.formato_id = f.id), 'vezes_semana', f.vezes_semana) order by f.ordem, f.nome)
                         from conteudo_formatos f where f.workspace_id = p_ws and f.ativo and f.grupo = 'formato'), '[]'),
    'por_destino', coalesce((select jsonb_object_agg(coalesce(destino, 'Sem destino'), n) from (select destino, count(*) n from sem group by 1) z), '{}'),
    'sem_territorio', (select count(*) from sem where territorio is null),
    'desempenho', jsonb_build_object(
      'publicacoes', (select count(*) from pubs), 'alcance', (select sum(alcance) from pubs), 'interacoes', (select sum(inter) from pubs),
      'engajamento', (select round(sum(inter) filter (where alcance > 0)::numeric / nullif(sum(alcance) filter (where alcance > 0), 0), 4) from pubs),
      'top', coalesce((select jsonb_agg(x) from (select jsonb_build_object('titulo', c2.titulo, 'canal', p.canal, 'alcance', p.alcance, 'interacoes', p.inter,
                         'engajamento', round(p.inter::numeric / nullif(p.alcance, 0), 4)) x
                         from pubs p join conteudos c2 on c2.id = p.conteudo_id where p.alcance > 0 order by p.inter::numeric / p.alcance desc limit 3) z), '[]'))
  ) into r;
  return r;
end $$;

create or replace function public.conteudo_fechar_semana(p_ws uuid, p_ini date, p_retro jsonb, p_objetivo text, p_pre_pauta text) returns uuid
language plpgsql security definer set search_path = public as $$
declare id_ uuid;
begin
  if auth.uid() is not null and not perm(p_ws, 'editar', array['mkt']) then raise exception 'Sem permissão para editar o conteúdo deste cliente'; end if;
  insert into conteudo_fechamentos (workspace_id, semana_ini, resumo, retro, objetivo_proxima, pre_pauta, fechado_por)
  values (p_ws, p_ini, conteudo_semana(p_ws, p_ini), coalesce(p_retro, '{}'), nullif(trim(coalesce(p_objetivo, '')), ''), nullif(trim(coalesce(p_pre_pauta, '')), ''), auth.uid())
  on conflict (workspace_id, semana_ini) do update set resumo = excluded.resumo, retro = excluded.retro, objetivo_proxima = excluded.objetivo_proxima,
    pre_pauta = excluded.pre_pauta, fechado_por = excluded.fechado_por, atualizado_em = now()
  returning id into id_;
  return id_;
end $$;

revoke execute on function public.conteudo_aplicar_linha(uuid, jsonb, text), public.conteudo_instalar_v18(uuid), public.conteudo_aplicar_proposta(uuid),
  public.conteudo_semana(uuid, date), public.conteudo_fechar_semana(uuid, date, jsonb, text, text) from public, anon;
grant execute on function public.conteudo_aplicar_linha(uuid, jsonb, text), public.conteudo_instalar_v18(uuid), public.conteudo_aplicar_proposta(uuid),
  public.conteudo_semana(uuid, date), public.conteudo_fechar_semana(uuid, date, jsonb, text, text), public.conteudo_modelo_v18() to authenticated;
