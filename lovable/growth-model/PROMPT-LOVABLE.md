# Prompt para colar no Lovable — Growth Model (módulo piloto)

> Cole o texto abaixo no Lovable. Depois envie os 3 arquivos de `src/lib` (growth-motor.ts, calculadora.ts, alertas.ts) e o `.env.example`. Os arquivos de `src/lib` não devem ser reescritos pelo Lovable: o cálculo é igual ao do sistema original.

---

Crie o módulo **Growth Model** de uma plataforma chamada **Growths** (gestão e inteligência de crescimento para vários clientes). Idioma: português do Brasil. React + TypeScript + Tailwind + shadcn/ui, tema claro com cor de destaque rosa (#e5365f) e suporte a modo escuro.

## Conexão (não crie banco novo)
Use o Supabase que já existe. Variáveis: `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` (arquivo `.env.example`). **Não crie tabelas nem migrações.** Todas as tabelas e funções estão descritas em `contrato-de-dados.md`. Nunca use service_role, e não guarde senha em lugar nenhum.

## Estrutura
1. **Login** por e-mail e senha (`supabase.auth.signInWithPassword`), com sair.
2. **Seletor de cliente** (workspace) no topo: lista de `workspaces` visíveis ao usuário; guarda o escolhido em estado global. Todas as consultas filtram por `workspace_id`.
3. Menu lateral com um item **Growth Model**, com três abas: **Modelo por loop**, **Mapa de métricas e North Star**, **Calculadora de campanha**.

## Aba 1 — Modelo por loop
Dados: RPC `growth_modelo_historico(p_ws, p_ini, p_fim)` e tabela `gm_alavancas`. Use `glMonta` e `glCalc` de `src/lib/growth-motor.ts` (não reescreva).
- Filtros: mês inicial, nº de meses (6, 12, 14, 18, 24, 36), produto, campanha, fase (aquisição/retenção), tipo de loop, janela de média (1 a 6 meses), vista (baseline, cenário, comparar).
- Para cada loop, um painel recolhível com tabela mensal: volume inicial, taxas entre etapas (CPM, CTR, connect rate, conversão…), ticket, receita. Meses passados = real (cinza); mês atual em diante = projeção, com **células editáveis** (as alavancas) que gravam em `gm_alavancas` (upsert; limpar = voltar ao valor herdado). Botão "Todos os meses" aplica um valor a todos os meses futuros.
- Painéis de resumo (Investido, Leads, Compras, Receita, Receita acumulada, ROI, CAC) para aquisição e retenção, e painel Baseline x Cenário com diferença em %.
- Se a métrica North Star tiver meta, mostrar o modelo do mês atual contra a meta.

## Aba 2 — Mapa de métricas e North Star
Dados: `growth_metricas`, `growth_experimentos`, RPC `growth_metricas_auto` e `benchmarks_mercado`.
- Período: últimos 7, 30 ou 90 dias, comparado ao período anterior de mesmo tamanho (e mais 3 períodos para a média histórica).
- Árvore de métricas (por `pai_id`) em cartões: nome, valor, barra de meta com % atingido, variação vs. período anterior (verde/vermelho conforme `direcao`), botões Editar, + Métrica filha, Novo experimento.
- **Alertas em vermelho**: use `alertasDaMetrica` de `src/lib/alertas.ts`. Métrica em alerta: valor em vermelho, borda vermelha e o motivo escrito embaixo. No topo, painel "Chamam atenção (N)" listando todas.
- Botão **Benchmarks do mercado**: modal com CPL, CAC, conversão (%), ticket e ROAS (valor e fonte); salvar faz upsert em `benchmarks_mercado`; vazio apaga.
- Painel "Gargalo sugerido": a métrica não-North-Star mais distante da meta (menor `atingimento`), com botão para criar experimento.
- Botão "Criar modelo padrão" quando não houver métricas.

## Aba 3 — Calculadora de campanha
Use `ccEdita` e `ccSaida` de `src/lib/calculadora.ts`. Seletor de campanha (ou "simulação avulsa") e de cenário salvo (`campanha_calculos`). Campos ao vivo: ticket, conversão %, CPL, leads, e os ligados CAC, vendas, receita, mídia, ROAS (editar um ligado ajusta a base). Custos por canal e custos extras (valor fixo, por lead, por venda, % da receita). Saídas: margem, lucro, margem de contribuição, CAC máximo, CPL máximo, ROAS ideal, ROAS de equilíbrio, conversão mínima, ROI, vendas de equilíbrio. Painel de ofertas da campanha (`campanha_ofertas_resultado`). Botões: salvar cenário e **Salvar metas na campanha** (atualiza `campanhas` e `campanha_canais` como em `contrato-de-dados.md`).

## Qualidade
Estados de carregando, vazio e erro em português. Nada de dado inventado: se o banco não retornar, mostrar vazio. Responsivo. Números em formato brasileiro (R$ 1.234,56).
