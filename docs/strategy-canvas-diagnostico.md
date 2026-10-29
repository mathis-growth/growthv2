# Strategy Canvas — Arquitetura Visual de Estratégias · Diagnóstico e plano (Etapas A, B e C)

Data: 29/10/2026 · Base: `main` em `3756099` (v0.164). Situação: **só diagnóstico e plano**. Nenhuma tabela, tela ou migração foi criada.

## 0. O que foi verificado
- Migrações em `supabase/migrations` (estratégias, blocos, campanhas, ofertas, metas, projetos, simuladores, permissões) e o `index.html` (telas de Estratégias, Campanha, Simulador, Growth Model, Projetos).
- O banco de produção foi consultado só para os pré-requisitos da v0.163; para este plano, valem as migrações. Antes da implementação, confiro em produção as funções que serão estendidas (como fiz na v0.163).
- A tela é um `index.html` único, sem React nem bibliotecas externas (o Supabase vem embutido). Já existe arrastar e soltar próprio (`ligaArrastar`), SVG feito à mão nos gráficos e o mapa da North Star (`.gtree`). **React Flow não se aplica**; o editor será em SVG + HTML, sem dependência nova.

---

## 1. Etapa A — O que já existe (e serve ao Strategy Canvas)

| Peça do Canvas | Já existe no Growths | Onde |
|---|---|---|
| **Estratégia** (modelo reutilizável) | `funis` virou "Estratégia" na v0.77: nome, tipo (lançamento, perpétuo, webinário, disparo, recompra, comercial…), produto, descrição, ativo, modelo pronto | `20261008220000_estrategias_jornada.sql:7-10`; tela `vFunis` / `vEstrategia` (`index.html:9624`, `9665`) |
| **Blocos** (nós) | `estrategia_blocos`: tipo, nome, fase (aquisição, aquecimento, conversão, retenção), ordem, referência | `20261010200000_blocos_e_simulador.sql:8` |
| **Biblioteca de componentes** | `EST_BLOCOS` com 17 blocos prontos (Conteúdo Instagram, Tráfego pago, Página de captura, Indicação, Grupo de WhatsApp, Disparo WhatsApp, E-mail, Pesquisa, Aula/Webinário, VSL, Checkout, Comercial, Recompra, Renovação…), cada um com métricas e fonte | `index.html:9803`; modelos prontos `EST_MOD_BLOCOS` (`:9850`) |
| **KPIs do bloco** | `estrategia_etapas`: métrica por bloco, papel principal/diagnóstico, unidade, origem do dado (anúncios, leads, etapa do Kanban, lista, vídeo, vendas, disparo, manual), `taxa_esperada`, `conta_como` (investimento, clientes novos, receita…) | `20261008220000:26`; `20261010200000:47-52` |
| **Catálogo de métricas** | `etapas_catalogo` (métricas do cliente, iguais em todas as campanhas) e `metricas_definicoes` (dicionário oficial: CAC, CPL, ROAS, conversão…) | `20261008220000:13`; `20261011000000:399` |
| **Estratégia → campanha** | `campanhas.funil_id` (principal) + `campanha_estrategias` (N:N); `campanha_aplicar_estrategia` **copia** blocos e etapas para a campanha (`campanha_blocos`, `campanha_etapas`): mudar a estratégia depois não mexe no histórico | `20261011700000:246-276`; `20261010200000:93-134` |
| **Números reais por etapa** | `campanha_funil_etapas(campanha, ini, fim)`: calcula cada etapa pela fonte (custo, impressões e cliques dos anúncios; leads; Kanban; lista/grupo; presença em vídeo; vendas e contratos); manual por dia em `campanha_etapa_valores` | `20261008220000:282-330` |
| **Previsto × realizado** | `taxa_esperada` × taxa real, por etapa (`estFunilHtml`); metas da campanha (`meta_leads`, `meta_vendas`, `meta_receita`, `meta_cac`, `meta_cpl`, `orcamento_total`), `campanha_metas` (por tipo, canal, período) e `campanha_metas_mes` | `index.html:9693-9715`; `20261011100000:470` |
| **Simulação** | Calculadora da campanha (`campanha_calculos`), Simulador de lucro (`simulador_cenarios`/`snapshots`), cenários do Growth Model (`gm_cenarios`, com baseline travado) | `20261008080000:28`; `20261010200000:140`; `20261011800000` |
| **Tarefas / plano operacional** | Projetos e atividades com dependências e responsáveis (`projetos`, `projeto_atividades`, `projeto_modelos`); a campanha cria o projeto sozinha a partir de um modelo (`campanha_cria_projeto`) | `20261006180000`; `20261011300000:10` |
| **Cadastro de campanha** | `formCampanha` já tem: nome, modelo, status (rascunho → ativa), tipo de mídia, **estratégia (`funil_id`)**, produto, datas, carrinho, orçamento, metas (CPL, CAC, leads, vendas, receita, conversão), meta do plano da empresa, observações, projeto automático e modelo | `index.html:2212`; guia de rascunho `campRascunho` (`:12835`) |
| **Campanha (hub)** | 13 abas, entre elas **Estratégia e etapas**, Planejamento e metas, Captação, Funil, Análise e cohorts, Mídia paga, Leads e vendas, Ofertas | `index.html:2270` |
| **Drill-down** | Análise de funil e cohorts (`funil_analise`, `funil_cohorts`), leads e vendas da campanha, Árvore dos números (`arvore_no`, clicável), Retenção & Expansão por campanha (`revops_clientes_de`), atribuição (`venda_atribuicoes`) | várias |
| **Esteira de ofertas** | `campanha_ofertas` com ramificação (sempre/aceitou/recusou), upsell, downsell, versão da oferta | `20261011700000:4-5` |
| **Permissões e isolamento** | Tudo por `workspace_id` + RLS; estratégias: ler mkt/vendas/gro/adm, editar mkt; campanha × estratégia: editar mkt/gro | `20261006370000:163`; `20261011700000:263-264` |

**Conclusão da Etapa A:** a "estratégia" do Strategy Canvas **é** o `funis` de hoje, os blocos do mapa **são** `estrategia_blocos`, os KPIs **são** `estrategia_etapas`, a execução **é** a campanha com a cópia em `campanha_blocos`/`campanha_etapas`, e a performance **é** `campanha_funil_etapas`. Não há segundo cadastro de estratégia, campanha, métrica ou tarefa a criar.

### O que realmente falta
1. **Posição dos blocos no mapa** (x, y) e **conexões explícitas** entre blocos, com ramificação (sim/não, divisão em %, condição, nota). Hoje o caminho é implícito (fase + ordem), sempre linear.
2. **Propriedades estratégicas do bloco:** objetivo, canal, produto/oferta, responsável, status de implementação, meta, eventos de rastreamento, dependências, observações. Hoje o bloco só tem tipo, nome, fase e referência.
3. **Versões da estratégia**, com a versão usada gravada na campanha. Hoje a cópia protege o histórico, mas não se sabe de qual versão veio.
4. **Blocos de lógica e personalizados:** condição, decisão, divisão, evento, gatilho e "bloco personalizado", sem programar um tipo novo para cada um.
5. **Plano estratégico gerado do mapa:** objetivo geral, jornada, etapas, critérios de conclusão, tarefas ligadas aos blocos.
6. **Mapa dentro da campanha** com status por bloco e o modo **Visualizar Performance**.
7. **Biblioteca:** categoria, objetivo, status, versão e comparação entre campanhas da mesma estratégia.

---

## 2. Etapa B — Arquitetura proposta (estender, não duplicar)

### 2.1 Dados (todas as mudanças aditivas e reversíveis)

| Separação pedida | Onde fica | Mudança |
|---|---|---|
| Definição da estratégia | `funis` | + `categoria`, `objetivo`, `status` (rascunho, ativa, arquivada), `versao_atual`, `criterios` (texto) |
| Versões | **nova** `estrategia_versoes` (estratégia, nº, foto jsonb de blocos + conexões + etapas, publicada_por/em, nota), imutável. Mesmo padrão de `oferta_versoes` e `jornadas` | tabela nova |
| Nós | `estrategia_blocos` | + `x`, `y`, `props` jsonb (objetivo, canal, produto_id, oferta_id, responsavel_id, status, meta, eventos[], dependências[], notas) |
| Conexões | **nova** `estrategia_conexoes` (de_bloco, para_bloco, tipo: segue / sim / não / divisão %, `condicao`, `nota`, `peso`) | tabela nova (não existe nada equivalente) |
| KPIs do bloco | `estrategia_etapas` (sem tabela nova) | + `meta_valor` (meta absoluta, além da `taxa_esperada`) |
| Execução na campanha | `campanha_blocos`, `campanha_etapas`, `campanha_estrategias` | + `campanha_blocos.x/y/props/status`; **nova** `campanha_conexoes` (cópia, como as etapas); + `campanha_estrategias.versao_id` |
| Plano operacional | `projeto_modelos` / `projeto_modelo_atividades` (o "plano da estratégia") → `projetos` / `projeto_atividades` (o "plano da campanha") | + `funis.projeto_modelo_id`; + `bloco_id` nas atividades (de modelo e de projeto) |
| Indicadores | `estrategia_etapas` + `etapas_catalogo` + `metricas_definicoes` | nada novo; o painel do bloco escolhe métrica do catálogo |
| Dados observados | `campanha_funil_etapas`, `campanha_etapa_valores`, anúncios, leads, vendas | estender `campanha_funil_etapas` para devolver por bloco e o realizado × meta |
| Projeções | `campanha_calculos.premissas` (já existe, por campanha) | gravar as premissas do canvas (3 cenários) com `tipo = 'canvas'` dentro do jsonb |

**Blocos de lógica e personalizados:** o tipo do bloco continua texto livre. A biblioteca (`EST_BLOCOS`) ganha os grupos da especificação (Aquisição, Páginas, Comunicação, Conversão, Pós-venda e Lógica). Um bloco "personalizado" escolhe nome, ícone e métricas do `etapas_catalogo`. Não precisa de código novo por tipo.

### 2.2 Telas e navegação
- **Onde fica:** o Growths não tem um grupo "Planejamento Estratégico". Hoje as estratégias estão em Configurações → Comercial e produtos → "Estratégias e funis" (`cad-funis`), lugar escondido para algo usado no dia a dia. Recomendo **Marketing → Estratégias (Strategy Canvas)**, ao lado de "Campanhas e planejamento", mantendo `cad-funis` como atalho para a mesma tela. Planejamento da empresa (Administrativo) continua onde está, ligado pelas metas (`campanhas.meta_id`).
- **Biblioteca de estratégias** (a lista atual `vFunis`, ampliada): nome, categoria, objetivo, versão, status, nº de campanhas, criada em, duplicar, comparar campanhas.
- **Editor da estratégia** com duas vistas da **mesma** estratégia:
  - **Mapa (Canvas):** biblioteca lateral arrastável, área livre com zoom e arraste, blocos conectáveis por setas, ramificações, painel de propriedades à direita, notas e condições nas conexões, duplicar/excluir, salvar automático, "Publicar versão".
  - **Lista (manual):** a tela de blocos por fase de hoje (`vEstrategia`), mais as propriedades novas.
  - **Sincronização:** as duas vistas leem e gravam as mesmas linhas (`estrategia_blocos`, `estrategia_conexoes`, `estrategia_etapas`). Não há cópia entre elas, então não há o que sincronizar. Um bloco criado na lista entra no mapa em posição automática (por fase e ordem); uma conexão criada no mapa aparece na lista como "segue para…". A ordem da lista sai da ordem topológica das conexões; sem conexões, vale fase + ordem, como hoje.
- **Gerar Plano Estratégico:** monta o plano a partir do mapa, sem IA e sem inventar dados:
  - o objetivo, a jornada (o caminho principal e os ramos), as etapas na ordem;
  - para cada etapa: objetivo, KPIs e metas, dependências (conexões), responsável, recursos (canal, produto, oferta), pontos de coleta (fonte de cada KPI) e critério de conclusão;
  - as tarefas viram **atividades do modelo de projeto** da estratégia, uma ou mais por bloco, com `bloco_id`.

  O plano fica editável: os textos ficam nas propriedades dos blocos e as tarefas, no modelo de projeto. Quando uma campanha nasce, `campanha_cria_projeto` já copia o modelo para o projeto dela.
- **Criar Campanha com esta Estratégia:** abre o `formCampanha` que já existe, com a estratégia preenchida. Ao salvar, `campanha_aplicar_estrategia` copia blocos, conexões e etapas e grava a versão usada. Antes de confirmar, o usuário vê e ajusta as etapas (a aba "Estratégia e etapas" da campanha já faz isso).
- **No cadastro da campanha (adendo):** seção **"Estratégia da campanha"** no `formCampanha`, com três opções:
  1. **Selecionar existente:** busca na biblioteca, mostra um resumo (blocos, KPIs, versão) e vincula.
  2. **Criar nova:** escolher entre o Canvas e a Lista; a estratégia nasce e fica vinculada.
  3. **Definir depois:** a campanha fica em `rascunho`, status que já existe, com o guia `campRascunho` lembrando.
- **Campanha → aba "Mapa estratégico"** (ao lado de "Estratégia e etapas"): o mapa da cópia da campanha, com status por bloco (planejado, implementado, pendente) e o botão **Visualizar Performance**. Os blocos mostram os números reais de `campanha_funil_etapas` no período escolhido; sem dado, mostram "sem dado" e nunca zero inventado. Também mostram meta × realizado e alertas (taxa abaixo do esperado, etapa sem fonte de dados).
- **Drill-down do bloco:** painel com a série por dia da métrica, quebra por canal e anúncio (anúncios), por origem e UTM (leads), por produto e oferta (vendas), lista de pessoas que passaram pela etapa, e atalhos para Análise de funil, Árvore dos números e Retenção & Expansão filtrados pela campanha. Onde não há rastreio (ex.: entrou no grupo sem lista ligada), a tela diz isso.
- **Simulação:** no mapa, o usuário informa investimento e taxas esperadas (ou usa as do bloco). O Canvas propaga pelo caminho principal (investimento → cliques → leads → conversões → receita → margem) em três cenários (conservador, base, otimista), sempre com o selo **"Projeção"**. As fórmulas de CAC, ROAS e margem seguem `metricas_definicoes`; a margem usa o custo variável do produto (`extras.mc_custo_pct`), como Retenção & Expansão já faz.
- **Comparar campanhas da mesma estratégia:** uma tabela por bloco/KPI com uma coluna por campanha e a versão usada. Cada campanha tem os seus números (vêm de `campanha_funil_etapas` de cada uma), e nada se mistura.

---

## 3. Etapa C — Plano, impactos e riscos

### 3.1 Etapas (cada uma é uma versão com teste de banco e de tela)
| Etapa | O que entra | Banco |
|---|---|---|
| S1 | Biblioteca de estratégias no Marketing (lista ampliada: categoria, objetivo, status, versão, campanhas) | `funis` + 5 colunas |
| S2 | Canvas: posições, conexões, arrastar/zoom, biblioteca lateral com os grupos da especificação, painel de propriedades; Lista e Mapa sobre os mesmos dados | `estrategia_blocos.x/y/props`; `estrategia_conexoes` |
| S3 | Versões: publicar versão, ver versões, campanha grava a versão usada | `estrategia_versoes`; `campanha_estrategias.versao_id`; `campanha_aplicar_estrategia` estendida (copia conexões e props) |
| S4 | Gerar Plano Estratégico (texto do plano + tarefas no modelo de projeto ligadas aos blocos) | `funis.projeto_modelo_id`; `bloco_id` nas atividades |
| S5 | "Estratégia da campanha" no cadastro (selecionar, criar no Canvas/Lista, definir depois) + "Criar campanha" no Canvas | — |
| S6 | Aba Mapa estratégico na campanha + Visualizar Performance + meta × realizado | `campanha_blocos.x/y/props/status`; `campanha_conexoes`; `campanha_etapas.meta_valor`; `campanha_funil_etapas` por bloco |
| S7 | Drill-down do bloco (série, quebras, pessoas, atalhos para as análises) | funções de leitura |
| S8 | Simulação no Canvas (3 cenários, selo Projeção) | `campanha_calculos` (premissas) |
| S9 | Comparar campanhas da mesma estratégia | função de leitura |

### 3.2 Impactos no que já existe
- **Estratégias e funis:** a tela atual vira a vista "Lista" e continua funcionando como antes. Estratégias sem posição aparecem no mapa arrumadas por fase.
- **`campanha_aplicar_estrategia`:** passa a copiar também as conexões e as propriedades. Copiar só o que ainda não existe ("não duplica") continua igual.
- **Campanhas existentes:** ficam sem versão vinculada (nulo = "antes das versões") e com o mapa gerado da cópia que já têm.
- **Kanban da jornada e análise de funil:** `funis` também é usado pelo Kanban (`funil_etapas`, `pessoa_funil`), pela Análise de funil e pelas pesquisas. Nada disso muda: as colunas novas são opcionais e as tabelas novas não são lidas por eles.

### 3.3 Riscos de duplicação (e como evitar)
1. **Duas noções de "etapa":** etapa do Kanban da jornada (`funil_etapas`, estado da pessoa) e etapa-métrica da estratégia (`estrategia_etapas`). O Canvas trabalha com blocos e métricas; o Kanban entra só como fonte de dado ("chegou à etapa X"), como já é hoje.
2. **Três simuladores** (Calculadora da campanha, Simulador de lucro e Cenários do Growth Model): o Canvas não cria um quarto. A projeção do mapa usa as premissas da Calculadora da campanha e as fórmulas oficiais. Se a Rebecka quiser, a projeção aprovada vira um cenário do Growth Model.
3. **Plano operacional:** nada de "tarefas do canvas". As tarefas são atividades do modelo de projeto e do projeto da campanha (Projetos já tem dependências, responsáveis e avisos).
4. **Métricas:** os KPIs do bloco vêm do `etapas_catalogo` e do dicionário, sem nome novo para CAC, CPL ou conversão.
5. **Performance:** o mapa só desenha o que `campanha_funil_etapas` e as análises já calculam. Sem número simulado no modo "real".

### 3.4 Riscos de regressão
- `campanha_aplicar_estrategia` e `campanha_funil_etapas` são usadas pela aba "Estratégia e etapas" e pelo dashboard da campanha. A extensão deve ser feita por troca de trecho conferida em produção (como na v0.163), com testes antes e depois.
- O editor visual é a parte mais pesada da tela: ele deve carregar só quando aberto, para não pesar o `index.html` em quem não usa.
- O desempenho do mapa com muitos blocos (> 60) exige desenhar as setas só quando algo muda.
- No celular, o Canvas vira só leitura com zoom; a edição fica pela Lista.

### 3.5 O que preciso da Rebecka para começar (Etapa D)
1. Aprovar o local: **Marketing → Estratégias (Strategy Canvas)**, com o atalho antigo mantido.
2. Aprovar que a estratégia continua sendo `funis` (sem tabela nova de estratégia) e que as tarefas do plano ficam em Projetos.
3. Versão: a cada "Publicar", ou automática a cada vez que uma campanha é criada?
4. Ordem das etapas: começar por S1 a S3 (biblioteca + Canvas + versões) e mostrar antes de seguir?
