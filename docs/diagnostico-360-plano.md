# Diagnóstico 360° de Growth, Dados e Maturidade Operacional: plano técnico

**Data:** 30/10/2026 · **Situação:** G1 construída (v0.176: formulário do cliente e catálogo). G2 a G5 seguem só no plano.
**Base:** a especificação da Rebecka (30/10) e as decisões das etapas E1 a E7 (`docs/auditoria-integracao-comercial-onboarding.md`). Este plano detalha a etapa de onboarding com diagnóstico e o projeto de implantação de 90 dias.

## 0. Princípios

- **Três momentos:**
  1. o cliente responde;
  2. a equipe Growth's faz o diagnóstico técnico;
  3. saem dois relatórios.
- **O que o cliente declara não é verdade validada.** Cada métrica guarda, separados, o que o cliente disse, o que a equipe verificou e o que se recomenda.
- **A falta de uma métrica é diferente da falta de dado.** Por exemplo, o cliente não acompanha LTV, mas já tem o histórico de compras para calcular.
- **O diagnóstico não monta nada sozinho no sistema do cliente** (não cria árvore de métricas nem configurações). Ele gera os relatórios e vira **o primeiro projeto de implantação** do cliente, com tarefas até o dia 90.
- **Reaproveitar o que existe:**
  - formulário: `pesquisas`;
  - link individual: `pesquisa_envios.token`;
  - catálogo de métricas: `metricas_definicoes`;
  - roteiro de 90 dias: `projetos`, `projeto_modelos` e `projeto_atividades`;
  - jornada do aluno: Customer Growth;
  - cliente: `pessoas`.

  Estruturas novas só onde não há nada: diagnóstico validado, arquivos e checagem por métrica.

**Regra deste plano:** nada do que a Rebecka pediu é cortado ou resumido para caber. O que ela disse entra como disse. A especificação "Diagnóstico 360°" e o documento "Diagnóstico de Métricas da Sua Empresa" são o guia para o que ela não detalhou.

## A. Tudo o que a Rebecka pediu e onde está no plano

| # | Pedido (com as palavras dela) | Onde está |
|---|---|---|
| 1 | Opção no formulário: "se é um tipo para lead ou se é para cliente" | B.0 e D1 |
| 2 | O diagnóstico do cliente é "um primeiro passo": o primeiro do onboarding, não captação | Princípios e seção 2 |
| 3 | "Montar toda a árvore de métrica para entender o que realmente esse cliente tem hoje" | B.4 (todas as métricas do negócio) e mapa causal (seção 6, 3b). Não cria nada sozinho no sistema do cliente: o mapa vai para o relatório |
| 4 | "O que ele espera" | B.1, pergunta 1.10 |
| 5 | "O que tem que acontecer para ele entender que está trazendo resultado para ele" | B.1, pergunta 1.11 |
| 6 | "Levantar todas as métricas de um negócio", com um botão para ele identificar as que acompanha | B.4 e o catálogo C |
| 7 | "Separado por etapa do funil pirata" | C (Aquisição, Ativação, Retenção, Receita, Recomendação, mais Recompra e ascensão) |
| 8 | "Ele vai ticar: tenho, não tenho" | B.4, campo M1 (Tenho, em dois níveis: regularmente ou de vez em quando; Não tenho; Não sei) |
| 9 | Se tem: "espaço para descrever **qual o objetivo** dessa métrica hoje" | B.4, campo M3 |
| 10 | Se tem: "**como é que ele acompanha**: planilha, alguma automação…" | B.4, campo M8 (marcar: planilha, sistema, automação, painel, plataforma de venda, CRM, manual, outro) |
| 11 | Se tem: "**como é calculada**" | B.4, campos M4 a M7 (numerador, denominador, janela, quem entra e quem sai) + M7a (fórmula em texto livre) |
| 12 | Se tem: "**se tem algum responsável** por ela" | B.4, campos M11 e M12 |
| 13 | "Se ele não tem, vai passar reto" | B.4: com "Não tenho", o bloco fecha (só pergunta, sem obrigar: "tem os dados para calcular?") |
| 14 | No final, "um lugar para ele subir os arquivos" | B.8 e E (Central de Documentos) |
| 15 | Pedir os arquivos de **vendas, CRM, cadastro de lead, os alunos, as últimas vendas, os últimos 6 meses** | E, categorias E1 a E7, cada uma pedindo os últimos 6 meses |
| 16 | Responder "**qual o faturamento dos últimos 6 meses**" | B.1, pergunta 1.6 (mês a mês, com o nome do mês já escrito) |
| 17 | "**O CAC mídia, o CAC médio**" | B.3, perguntas 3.4 e 3.5 |
| 18 | "**Quais canais ele usa**" | B.3, pergunta 3.1 (marcar) |
| 19 | "O que a gente puder facilitar para ser só check"; pergunta aberta só quando precisa | Todo o banco B: marcar sempre que dá; texto só onde é opinião ou definição |
| 20 | Gerar **dois relatórios**: "um para mim e outro para o cliente" | F |
| 21 | Plano de **30, 60 e 90 dias** (aula da Ana), com tudo rodando, "inclusive acompanhando a parte dos alunos" | G (pendente: confirmar com a aula da Ana) |
| 22 | "No final eu quero que ele dê um local pro cliente fazer o upload desses arquivos" | E (no fim do formulário, pelo mesmo link) |
| 23 | O módulo "tem que responder 100%" do documento "Diagnóstico de Métricas da Sua Empresa" | Seção 6 (item por item) |
| 24 | "Não minimize; tem mais perguntas além do documento" | Este plano: o banco B tem as perguntas do documento **e** as das 8 seções |

## B. Banco de perguntas do formulário do cliente ("Diagnóstico 360°")

**Legenda:**
- [marcar] = escolha ou múltipla escolha;
- [número], [R$], [mês a mês];
- [texto] = resposta aberta;
- (se…) = pergunta condicional.

Tudo pode ser editado no construtor de pesquisas. Este é o modelo pronto.

### B.0 Configuração do formulário (para a equipe)
- **Para quem é:** Lead (captação) ou Cliente (diagnóstico / onboarding).
- **Tipo:** diagnóstico.
- **Produto ligado** (opcional): o produto que leva a este diagnóstico.
- **Envio:** link individual por cliente, com validade (padrão de 30 dias, a confirmar) e o mesmo link para a Central de Documentos.

### B.1 Seção 1: Perfil do negócio
1.1 Nome da empresa e CPF/CNPJ [já vêm do cadastro; o cliente só confirma ou corrige; não sobrescreve sem confirmação].
1.2 Segmento [marcar: educação/infoproduto, consultoria, serviços, saúde, beleza, varejo/e-commerce, SaaS/tecnologia, outro + texto].
1.3 **Modelo de negócio** [marcar vários: infoproduto/curso, mentoria, consultoria ou serviço, assinatura/recorrência, comunidade, e-commerce, high ticket, outro]. É a pergunta que **define a triagem de métricas** da seção 4.
1.4 Há quanto tempo vende [marcar: menos de 1 ano, 1 a 2, 3 a 5, mais de 5].
1.5 Faturamento médio mensal [marcar faixas].
1.6 **Faturamento dos últimos 6 meses** [mês a mês, com o nome do mês escrito; "não sei" por mês].
1.7 Tamanho da equipe [marcar faixas] e quem cuida de cada área [para cada área (marketing, comercial, CS/sucesso do aluno, produto, financeiro, dados): própria, terceirizada, ninguém].
1.8 **Objetivos** do negócio para os próximos 12 meses [marcar: aumentar faturamento, aumentar margem, reduzir CAC, aumentar recorrência, lançar produto, escalar time, organizar dados, outro + texto].
1.9 **Principais desafios** hoje [marcar: gerar leads, converter, reter, entender os números, equipe, caixa, outro + texto].
1.10 **O que você espera deste trabalho?** [texto].
1.11 **O que precisa acontecer para você perceber que este trabalho está trazendo resultado?** [texto].
1.12 Em quanto tempo espera ver esse resultado [marcar: 30, 60, 90 dias, 6 meses, mais].

### B.2 Seção 2: Produtos e ofertas
2.1 **Produtos e ofertas** [lista que se repete, uma linha por produto]: nome; tipo [marcar]; preço ou ticket [R$]; recorrente? [sim/não → periodicidade]; margem aproximada [%, ou "não sei"]; participação nas vendas [%, ou "não sei"]; posição na esteira [marcar: entrada, principal, high ticket, recorrente, upsell].
2.2 Ticket médio geral [R$].
2.3 Onde vende [marcar: Hotmart, Kiwify, Eduzz, outra plataforma, venda direta/contrato, loja própria].
2.4 Formas de pagamento [marcar: Pix, cartão, boleto, parcelado, recorrência no cartão].
2.5 Tem **esteira de produtos** definida? [sim, em construção, não] (se sim) qual é o caminho do cliente na esteira [texto].

### B.3 Seção 3: Jornada do cliente (funil pirata, como acontece hoje)
3.1 **Canais que usa** [marcar vários: Meta Ads, Google Ads, YouTube Ads, TikTok Ads, Instagram orgânico, YouTube orgânico, TikTok orgânico, LinkedIn, e-mail, WhatsApp, grupos, indicação, afiliados, eventos, prospecção ativa/SDR, parcerias, SEO/blog, outro].
3.2 Canal que mais traz clientes [marcar um dos que marcou].
3.3 Investimento médio mensal em mídia [R$].
3.4 **CAC mídia** (custo de mídia por cliente) [R$, ou "não sei"].
3.5 **CAC médio** (custo total de aquisição por cliente: mídia, equipe, ferramentas) [R$, ou "não sei"].
3.6 Como vende [marcar vários: lançamento, perpétuo, webinário, desafio, comercial/SDR, direct, evento, outro].
3.7 (Ativação) Existe **primeiro valor** definido depois da compra? [sim, mais ou menos, não] (se sim) qual é [texto]; qual **evento** mostra que o cliente chegou nele [texto]; em quanto tempo o cliente chega lá [número de dias, ou "não sei"]; que parte **não chega** no tempo esperado [%, ou "não sei"].
3.8 (Ativação) Tem **onboarding** depois da compra? [sim, em parte, não] (se sim) como [marcar: boas-vindas, reunião, aula, grupo, sequência de e-mails/WhatsApp, área de membros].
3.9 (Retenção) Acompanha **consumo ou progresso** dos alunos ou clientes? [sim, em parte, não] (se sim) como [texto].
3.10 (Retenção) Mede **churn ou cancelamento**? [sim, não, não se aplica] (se sim) quanto, por mês [%].
3.11 (Receita da base) **Separa a receita de clientes novos da receita de clientes que já compraram?** [sim, não].
3.12 (Receita da base) Acompanha **retenção, churn e expansão** (renovação, upsell) juntas? [sim, em parte, não].
3.13 (Recompra) Tem **recompra ou ascensão** na esteira? [sim, não] (se sim) que parte dos clientes compra de novo [%, ou "não sei"].
3.14 (Recomendação) Tem **programa de indicação**? [sim, informal, não] (se sim) quantos clientes vêm por indicação [%, ou "não sei"].

### B.4 Seção 4: Maturidade das métricas (todas as métricas do negócio)
Na tela, uma lista **por etapa do funil pirata**, já filtrada pelo modelo de negócio (1.3), com um botão em cada métrica. Para cada métrica do catálogo C:

- **M1. Acompanha esta métrica?** [marcar: Tenho, calculamos regularmente · Tenho, calculamos de vez em quando · Não tenho · Não sei informar].
- (Se **Não tenho**) o bloco fecha ("passa reto"). Só aparece, sem obrigar: **M1a. Tem os dados para calcular?** [sim, em parte, não, não sei].
- (Se **Tenho**) abre:
  - **M2. Usamos para tomar decisões** [sim/não]. O formulário pede que marque de 5 a 8 (as "mais usadas para decidir" do documento).
  - **M3. Qual é o objetivo desta métrica hoje?** [texto].
  - **M4. Numerador:** o que entra em cima da conta [texto].
  - **M5. Denominador:** pelo que divide [texto, ou "não tem"].
  - **M6. Janela de tempo** [marcar: dia, semana, mês, trimestre, campanha, desde sempre, outro].
  - **M7. Quem entra e quem sai da conta** (por exemplo, exclui reembolsos?) [texto].
  - **M7a. Como é calculada, do seu jeito** [texto], se preferir explicar de uma vez.
  - **M8. Como acompanha** [marcar vários: planilha, sistema/CRM, plataforma de venda, automação, painel/dashboard, relatório da ferramenta de anúncio, manual, outro + qual].
  - **M9. De onde vêm os dados (fonte)** [texto, por exemplo: Hotmart, Meta Ads, planilha do comercial].
  - **M10. De quanto em quanto tempo atualiza** [marcar: tempo real, diária, semanal, mensal, quando alguém lembra].
  - **M10a. Nível de detalhe (granularidade)** [marcar: total, por canal, por campanha, por produto, por cliente].
  - **M11. Quem é o responsável** [texto].
  - **M12. Isso está claro na empresa?** [sim, em parte, não].
  - **M13. Que decisão vocês tomam olhando este número?** [texto].
  - **M14. Depois que vocês agem, quanto tempo leva para este número mudar?** [marcar: horas, dias, semanas, meses]. Ajuda na lente antecedente ou consequente.
  - **M15. Alguém confere se o número está certo?** [sim, às vezes, não] e **quanto confia nele** [escala de 1 a 5].
  - **M16. Valor atual** [número, opcional], para a tabela final "com números".

Ainda nesta seção:
- 4.1 **Tem uma North Star (métrica principal)?** [sim, não, não sei] (se sim) qual [texto] e por que ela [texto].
- 4.2 **Quando um número melhora, vocês olham se outro piorou?** (guardrails) [sempre, às vezes, nunca] (se sempre ou às vezes) quais pares [texto, por exemplo: "CPL caiu, mas a qualidade do lead caiu?"].
- 4.3 Métricas que vocês usam e **não estão na lista** [lista: nome + o mesmo bloco M2 a M16].

### B.5 Seção 5: Infraestrutura de dados
5.1 **Ferramentas** [marcar vários: Excel/Google Sheets, CRM (qual), plataforma de venda (qual), ERP/financeiro (qual), e-mail marketing (qual), WhatsApp/automação (qual), área de membros (qual), BI/dashboard (qual), Google Analytics 4, Pixel/API de Conversões, outro].
5.2 **Integrações** que já funcionam entre elas [texto, ou marcar pares comuns].
5.3 **UTMs padronizadas** nos links? [sim, às vezes, não, não sei o que é].
5.4 **Atribuição:** como sabe de onde veio cada venda [marcar: UTM, pergunta no checkout, pergunta do comercial, relatório da plataforma, não sabemos].
5.5 Os dados **batem entre as ferramentas** (por exemplo, vendas da plataforma × financeiro)? [sim, quase, não, nunca conferimos].
5.6 **Cadastros duplicados** de clientes ou leads? [não, alguns, muitos, não sei].
5.7 **Quem cuida dos dados** [marcar: ninguém, eu, alguém da equipe, terceirizado].
5.8 **Confiança geral nos números** [escala de 1 a 5].

### B.6 Seção 6: Gestão e decisões
6.1 **Rotina de análise** [marcar: diária, semanal, quinzenal, mensal, não tem].
6.2 Tem **reunião de resultados**? [sim, não] (se sim) quem participa [marcar áreas].
6.3 Tem **metas definidas**? [por área, só faturamento, não] e quem define [texto].
6.4 **Uma decisão importante recente tomada com dados** [texto].
6.5 **Uma decisão importante tomada sem dados**, e por quê [texto].
6.6 O que **mais atrapalha** decidir com dados hoje [marcar: não confio nos números, demora para juntar, não sei o que olhar, ninguém cuida, outro].

### B.7 Seção 7: Prioridades de crescimento
7.1 **Gargalos** [marcar por etapa do funil pirata + texto].
7.2 **Hipóteses**: o que você acha que resolveria [texto].
7.3 **Oportunidades** que vê e ainda não explorou [texto].
7.4 **Objetivos para os próximos 90 dias** [marcar + texto].
7.5 **Restrições** [marcar: orçamento, equipe, tempo, tecnologia, outro].

### B.8 Seção 8: Documentação (fim do formulário)
8.1 Para cada categoria da Central de Documentos (E): **tem** [sim, em parte, não, mando depois].
8.2 Botão **"Ir para a Central de Documentos"**, no mesmo link, sem outro login. Ali ele envia agora ou volta depois.
8.3 Aviso: **não envie senhas nem acessos** em planilhas ou documentos. Os dados pessoais são tratados conforme a LGPD.

## C. Catálogo de métricas por etapa do funil pirata (lista inicial para editar)

Cada métrica tem: etapa, modelos de negócio em que se aplica, fórmula de referência do Growth's, se o Growth's **já calcula sozinho** e a explicação simples para o cliente. As que já existem no catálogo (`metricas_definicoes`) estão marcadas com ✓.

- **Aquisição:** investimento em mídia ✓, impressões e alcance, CTR ✓, CPC, leads ✓, leads por canal, CPL ✓, custo por lead qualificado, conversão da página de captura, CAC mídia, CAC médio/total ✓ (CAC), ROAS ✓, ROI ✓, crescimento orgânico (seguidores e alcance), recuperação de checkout ✓.
- **Ativação:** taxa de qualificação (lead → qualificado), comparecimento (aula, reunião, webinário), lead → cliente ✓, tempo até a compra, primeiro acesso, onboarding concluído, **primeiro valor / ativação**, **Time to Value (TTV)**.
- **Retenção:** churn ✓, retenção por coorte, consumo e progresso, conclusão, frequência de uso, NPS ✓ (NPS dos alunos), resposta dos check-ins ✓, marco atingido e marco no prazo ✓, alunos em risco, intervenções que resolveram ✓.
- **Receita:** faturamento/receita ✓, ticket médio ✓, conversão de vendas, aceite da oferta ✓, receita de novos × de clientes existentes, MRR ✓ (só assinatura), ARR (só assinatura), LTV, LTV/CAC, payback do CAC, margem ✓, lucro ✓, reembolso e chargeback, expansão (upsell), NRR (sinalizar para a etapa seguinte).
- **Recomendação:** indicações, taxa de indicação, receita vinda de indicação, depoimentos e avaliações, promotores (NPS).
- **Recompra e ascensão:** taxa de recompra, ascensão na esteira, tempo até a segunda compra.

## D. O que a equipe preenche no diagnóstico técnico

**Por métrica:**
- o que foi declarado (vem do formulário);
- o que o Growth's suporta (vem do catálogo);
- o **estado**: validado, precisa de validação, parcialmente disponível, não disponível ou não aplicável;
- tem dados para calcular?;
- evidência (o arquivo que confirma);
- as **5 lentes** do documento (seção 6);
- observação e recomendação;
- a tarefa no projeto de implantação.

**Pelo diagnóstico inteiro:**
- avaliação da North Star e a candidata;
- **mapa causal** (ligações entre as métricas);
- guardrails ausentes e o risco;
- ativação e TTV;
- retenção e expansão;
- as 4 recomendações;
- a tabela final (North Star, resultado e KPIs, entrada, guardrails, com números);
- problemas de qualidade dos dados (5.5, 5.6 e o que os arquivos mostrarem);
- integrações necessárias;
- prioridades.

## E. Central de Documentos

Pelo mesmo link do formulário, com validade, sem login e sem pedir senhas. Cada categoria aceita **vários arquivos**, **mandar depois** e **"não tenho"**. Cada arquivo fica ligado ao **cliente** e ao **diagnóstico**, com categoria, período, data de envio e situação da validação (recebido, conferido, com problema).

| # | Categoria | O que pedir (preferencialmente os **últimos 6 meses completos**) |
|---|---|---|
| E1 | **Vendas e pedidos** (inclui "as últimas vendas") | Data, produto, valor, desconto, forma de pagamento, reembolsos e cancelamentos, identificação do cliente (e-mail ou CPF), plataforma, origem/UTM quando houver |
| E2 | **CRM e leads** (inclui "cadastro de lead") | Leads com data de entrada, origem e canal, etapa do funil, responsável, resultado (ganho ou perdido) |
| E3 | **Alunos e clientes** | Cadastro de alunos ou clientes, produto, data de entrada, acesso e ativação, consumo e progresso, conclusão, cancelamento, recompra |
| E4 | **Marketing e aquisição** | Campanhas por canal: investimento, impressões, cliques, leads, conversões, por mês |
| E5 | **Financeiro** | Receitas, custos, despesas, taxas das plataformas, margens, quando houver |
| E6 | **Produtos e ofertas** | Catálogo, preços, ofertas, recorrências, esteira |
| E7 | **Arquivos complementares** | Painéis, planilhas de acompanhamento, relatórios, documentação de processos |

**Regras:**
- **Tipos aceitos:** planilha (xlsx, xls, csv), PDF, imagem, documento. **Tamanho máximo** por arquivo, a definir; proposta: 25 MB.
- O armazenamento é **privado**. Só a equipe logada daquele cliente baixa.
- Fica registrado **quem enviou e quando**.
- Aviso de LGPD na tela.

## F. Os dois relatórios

**Relatório do cliente (executivo, em PDF), "para o cliente":**
- o que ele espera e o critério de sucesso dele (1.10 a 1.12);
- **visão de maturidade** por etapa do funil pirata;
- os números que ele informou (faturamento mês a mês, CAC mídia, CAC médio, ticket, canais);
- as principais lacunas, os riscos e as oportunidades;
- o **plano de 30, 60 e 90 dias**.

Cada ponto diz se é **declarado**, **verificado** ou **recomendação**. Sai como **pré-diagnóstico** (só respostas) e depois como **validado**.

**Relatório técnico (para você e a equipe), em PDF:**
- **segue as 4 seções do documento "Diagnóstico de Métricas da Sua Empresa"** (Mapeamento, Análise crítica, Arquitetura, Recomendações), com o mapa causal desenhado, a tabela final com números e o contador de palavras;
- depois, o resto do 360°:
  - o de-para por métrica (declarado × Growth's × estado);
  - as fórmulas declaradas comparadas com as do Growth's;
  - fontes e responsáveis;
  - problemas de qualidade dos dados;
  - integrações necessárias;
  - prioridades;
  - arquivos recebidos e pendentes;
  - a **lista de implantação**.

## G. Roteiro de implantação de 90 dias (o primeiro projeto do cliente)

O objetivo dos primeiros 90 dias não é aumentar o faturamento de imediato. É **colocar o sistema de crescimento funcionando**: dados confiáveis, workflows implantados, rotina de acompanhamento e a jornada dos alunos acompanhada. O roteiro é a base e muda conforme a maturidade e as lacunas; os prazos podem ser **acelerados ou adaptados**. Cada atividade tem **responsável, prazo, dependências, status e critério de aceite**.

- **Dias 1–30, entender e estruturar:**
  - diagnóstico validado e auditoria dos dados recebidos;
  - definição da North Star, da árvore de métricas e dos responsáveis;
  - prioridades e arquitetura de implantação.

  **Entrega:** diagnóstico validado, plano de ação priorizado e arquitetura aprovada.
- **Dias 31–60, conectar e implementar:**
  - integrações (por exemplo, Hotmart) e configuração das métricas;
  - dashboards, workflows e rastreamento (UTMs, pixel);
  - campanhas e etapas da jornada do cliente, com os pontos de coleta e as automações prioritárias.

  **Entrega:** fluxos prioritários implantados e dados começando a circular.
- **Dias 61–90, validar e operar:**
  - validação dos indicadores e testes dos workflows;
  - monitoramento da jornada dos alunos;
  - treinamento da equipe;
  - rotina de análise e de experimentos.

  **Entrega:** operação prioritária funcionando, com responsáveis, indicadores e acompanhamento contínuo.
- **Jornada do aluno (Customer Growth), sempre dentro dos 90 dias:**
  - entrada e onboarding depois da compra;
  - primeiro acesso e ativação;
  - consumo e progresso;
  - check-ins e identificação de alunos em risco;
  - conclusão e resultados alcançados;
  - renovação, recompra e ascensão na esteira.

  Tudo usa o que já existe no Customer Growth (jornada do produto, marcos, check-ins, alertas, intervenções, oportunidades).
- **Tarefas que nascem das lacunas:** cada métrica "precisa de validação" ou "não disponível" que importa para o cliente vira uma tarefa, por exemplo "Validar o cálculo do CAC" ou "Começar a medir a ativação".
- **Pendente:** confirmar as fases e os critérios com a **aula da Ana**.

## 1. O que já existe e onde cada parte entra

| Parte da especificação | O que já existe | O que falta |
|---|---|---|
| Formulário em 8 seções, perguntas condicionais | `pesquisas` + `pesquisa_perguntas` (com `secao`, `obrigatoria`, `pontos`). Tipos de pergunta: nps, escala, escolha, múltipla, sim/não, texto | "Para quem" (lead ou cliente); tipos de pergunta novos (número, valor em reais, valores por mês, **métrica**, **arquivos**); **condição** para mostrar a pergunta; tipo `diagnostico` |
| Link individual e seguro | `pesquisa_envios` (um código por pessoa, status, respondido em) | **Validade** do link (`expira_em`); o mesmo link abre a Central de Documentos |
| Avaliação de cada métrica: os campos M1 a M16 de B.4 (tenho ou não tenho, **objetivo**, como calcula, como acompanha, fonte, atualização, granularidade, responsável e clareza, decisão, tempo de reação, conferência e confiança, valor atual) | — | Pergunta do tipo `metrica`: uma pergunta mostra o bloco inteiro para cada métrica do catálogo; o detalhe vai num campo `valor_json` da resposta |
| Catálogo de métricas do Growth's | `metricas_definicoes` (30 métricas, com fórmula, fonte e unidade, globais): CAC, CPL, CTR, leads, investimento, ROAS, ROI, lead → cliente, ticket médio, receita, margem, lucro, MRR, churn, NPS dos alunos, marcos e check-ins (Customer Growth), recuperação de checkout… | **Etapa do funil pirata** (AARRR), **modelos de negócio** em que se aplica (assinatura, infoproduto, serviço, mentoria, e-commerce), se o Growth's **já calcula sozinho** ou não. Métricas que faltam: LTV, LTV/CAC, ativação, primeiro acesso, consumo e progresso, conclusão, recompra, indicação, payback, taxa de comparecimento, ARR, entre outras |
| Triagem pelo modelo de negócio | O perfil do negócio é uma seção do formulário | A seção 1 define o modelo, e a seção 4 mostra só as métricas que se aplicam (MRR e ARR só para assinatura) |
| De-para em 3 dimensões e 5 estados | — | **Nova tabela** `diagnosticos` (um por cliente e resposta: pré-diagnóstico → validado) + **nova tabela** `diagnostico_metricas` (por métrica: o que foi declarado, o que o Growth's suporta, estado entre validado / precisa de validação / parcialmente disponível / não disponível / não aplicável, se tem dados para calcular, evidência, observação, recomendação) |
| Central de Documentos (6 categorias, vários arquivos, mandar depois, marcar "não tenho", LGPD) | Não há armazenamento nem tabela de arquivos | **Nova tabela** `arquivos` (empresa, diagnóstico, cliente, categoria, período, nome, tamanho, tipo, data de envio, situação da validação) + **local privado** de armazenamento + **função de envio** que só aceita quem tem o código válido e não vencido, com limite de tamanho e de tipo (planilha, CSV, PDF, imagem), sem pedir senhas. Baixar é só para a equipe logada |
| Relatório executivo (cliente) e técnico (equipe), em PDF | Telas imprimíveis (o padrão do Growth's é a página com "salvar em PDF") | Duas páginas novas, geradas do diagnóstico, que mostram separados **o que foi declarado**, **o que foi verificado** e **o que se recomenda**. O pré-diagnóstico sai das respostas; o validado, depois da análise dos arquivos |
| Roteiro de 90 dias como **primeiro projeto** | `projeto_modelos` + `projeto_modelo_atividades` (com `prazo_dias`, `depende_de`, função, responsável) → `projeto_atividades` (status, prazo, dependências, responsável). O projeto já pode nascer do produto (`produtos.modelo_projeto_id`) | O **modelo** "Implantação Growth's: 90 dias" (é dado, não estrutura), com três fases (dias 1–30, 31–60 e 61–90) como atividades-mãe; **critério de aceite** na atividade (coluna nova); atividades **acrescentadas pelas lacunas** do diagnóstico (por exemplo, "Validar o cálculo do CAC" ou "Integrar a Hotmart") |
| Jornada do aluno nos 90 dias | Customer Growth inteiro: jornadas por produto, marcos, check-ins, alertas, intervenções, oportunidades de expansão e retenção, indicadores | Só **atividades no modelo** para configurar o que já existe: jornada do produto, marcos de ativação e consumo, check-ins, responsáveis do CS, renovação e ascensão. Nada novo no Customer Growth |

## 2. Fluxo

1. **Disparo.** O cliente fecha (contrato ativado, E2) ou é marcado para diagnóstico.
   - O sistema cria o **envio individual** do formulário "Diagnóstico 360°", com validade (padrão: 30 dias).
   - Também cria o **projeto de implantação** do modelo de 90 dias. Ou o projeto nasce do produto, se o produto tiver o modelo.
2. **O cliente responde.** São as 8 seções, com condições. Ao final, o mesmo link leva à **Central de Documentos**, onde ele envia agora ou depois.
3. **Pré-diagnóstico** (automático, ao responder). Cria o registro em `diagnosticos` e, para cada métrica, o que foi declarado. O estado inicial sai das regras:
   - "não acompanhamos" → não disponível;
   - acompanha, mas por planilha manual e sem validação → precisa de validação;
   - fora do modelo de negócio → não aplicável;
   - e assim por diante.

   O relatório executivo e o técnico já saem marcados como **pré-diagnóstico**.
4. **Diagnóstico técnico** (a equipe). Na tela do diagnóstico, a equipe revê métrica por métrica: muda o estado, anota a evidência (o arquivo que confirma), marca "tem dados para calcular" e escreve a recomendação. O que vira tarefa entra no projeto de implantação, com responsável, prazo, dependência e critério de aceite.
5. **Diagnóstico validado.** Os relatórios saem de novo, agora como **validado**, e o executivo traz o plano de 30, 60 e 90 dias.
6. **Implantação.** O projeto anda até o dia 90 com o acompanhamento que já existe em Projetos.

## 3. Mudanças no banco (todas aditivas)

| # | Mudança | Por quê |
|---|---|---|
| D1 | `pesquisas.tipo` aceita `diagnostico`; `pesquisas.publico` (`lead` ou `cliente`) | "Para quem" no formulário |
| D2 | `pesquisa_perguntas.tipo` aceita `numero`, `moeda`, `meses`, `metrica`, `arquivos`; `pesquisa_perguntas.condicao` jsonb (mostrar se a pergunta X teve a resposta Y); `pesquisa_perguntas.config` jsonb (lista de métricas, categorias de arquivos, quantidade de meses) | Perguntas novas e condicionais, sem tabela paralela |
| D3 | `pesquisa_resposta_itens.valor_json` jsonb | Detalhe de cada métrica e valores por mês |
| D4 | `pesquisa_envios.expira_em` | Link individual com validade |
| D5 | `metricas_definicoes`: `etapa_aarrr`, `modelos` text[], `calcula_sozinho` boolean, `descricao_cliente`; mais as métricas que faltam (dados) | O catálogo do Growth's é o lado "o que o sistema suporta" do de-para |
| D6 | **`diagnosticos`** (workspace, pessoa, envio, resposta, projeto, status: `pre`, `em_analise` ou `validado`, modelo de negócio, resumo, datas) | O diagnóstico é diferente da resposta: tem análise da equipe |
| D7 | **`diagnostico_metricas`** (diagnóstico, código da métrica, declarado jsonb, estado com os 5 valores, `tem_dados`, evidência que aponta para o arquivo, observação, recomendação, atividade do projeto) | De-para por métrica |
| D8 | **`arquivos`** + local privado no Storage + função de envio | Central de Documentos |
| D9 | `projeto_atividades.criterio_aceite` e `projeto_modelo_atividades.criterio_aceite` | Critério de aceite em cada tarefa |
| D10 | Modelo "Implantação Growth's: 90 dias" (dados) e formulário-modelo "Diagnóstico 360°" (dados) | Prontos para usar |

Proteção (RLS) em tudo, por empresa. O cliente que responde não está logado: ele só lê o próprio formulário e só envia arquivos pelo código válido. Não lê nada de ninguém.

## 4. Telas

1. **Pesquisas:** "Para quem é" (lead ou cliente), os tipos de pergunta novos, a condição em cada pergunta e o botão "Começar do modelo Diagnóstico 360°".
2. **Formulário público:** as 8 seções, as condições, o bloco de cada métrica (acompanha? → abre os detalhes) e, no final, a Central de Documentos.
3. **Central de Documentos** (cliente): as 6 categorias, vários arquivos em cada uma, "não tenho" e "mando depois", o que já foi enviado e um aviso de LGPD.
4. **Diagnóstico** (equipe), na ficha do cliente e em RevOps → Customer Growth:
   - visão por etapa do funil pirata;
   - métrica por métrica: declarado, Growth's, estado, tem dados, evidência e recomendação;
   - arquivos recebidos;
   - botão "Validar diagnóstico".
5. **Relatório executivo** (cliente, em PDF): maturidade por etapa, principais lacunas, riscos, oportunidades, o que ele espera e o plano de 30, 60 e 90 dias. Diz em cada ponto se é declarado ou verificado.
6. **Relatório técnico** (equipe, em PDF): de-para por métrica, fórmulas declaradas comparadas com as do Growth's, fontes, responsáveis, problemas de qualidade, integrações necessárias, prioridades e lista de implantação.
7. **Projeto de implantação:** o que já existe em Projetos, com as três fases e o critério de aceite.

## 5. Etapas (cada uma com aprovação)

| Etapa | Entrega |
|---|---|
| G1 | Catálogo de métricas completo (D5) + formulário-modelo "Diagnóstico 360°" com as 8 seções, as perguntas novas (D1–D4) e tudo o que o cliente responde do documento de Arquitetura de Métricas (seção 6). O cliente já consegue responder |
| G2 | Central de Documentos com armazenamento seguro (D8) |
| G3 | Pré-diagnóstico automático + tela do diagnóstico para a equipe (D6, D7) |
| G4 | Relatórios executivo e técnico em PDF. O técnico segue as 4 seções do documento de Arquitetura de Métricas, com o mapa causal desenhado e o contador de palavras |
| G5 | Projeto de implantação de 90 dias com o modelo e as tarefas que nascem das lacunas, incluindo a jornada do aluno (D9, D10) |

## 6. Cobertura de 100% do documento "Diagnóstico de Métricas da Sua Empresa" (Entregável 1, Módulo 1)

O módulo precisa responder o documento inteiro, além do que este plano já tem. O documento separa inventário de diagnóstico: um inventário lista o que existe; um diagnóstico avalia se o que existe serve ao propósito. Cada item vem de uma de três fontes:
- **o cliente responde** (no formulário);
- **a equipe analisa** (na tela do diagnóstico);
- **o relatório monta** (juntando as duas).

O **relatório técnico segue as 4 seções do documento, na mesma ordem e com os mesmos itens**, e por isso o responde por inteiro. O executivo resume.

| Item do documento | Quem responde | Onde fica |
|---|---|---|
| **Seção 1, Mapeamento (20%):** as 5 a 8 métricas mais usadas para decidir | Cliente: marca "usamos para decidir" nas métricas que tem; o formulário pede de 5 a 8 | Bloco da métrica (`metrica`) |
| 1a. Nome e **definição exata**: numerador, denominador, janela de tempo, quem entra e quem sai | Cliente: quatro campos separados, além do "como calcula" livre | `valor_json` da resposta → `diagnostico_metricas.declarado` |
| 1b. **Fonte**; manual ou extraído de ferramenta; **atualização** (tempo real, diária, semanal, mensal) | Cliente: marcar | idem |
| 1c. **Responsável** e se há clareza sobre isso | Cliente: nome do responsável + "está claro na empresa? sim, em parte, não" | idem |
| 1d. **Decisão associada**, explícita no ciclo atual | Cliente: texto ("que decisão vocês tomam olhando este número?") | idem |
| **Seção 2, Análise crítica (40%):** as 5 lentes, por métrica mapeada | **Equipe** (é análise, não autodeclaração) | `diagnostico_metricas` (campos novos abaixo) |
| Lente 1, epistemológica: evidência de quê, correlação ou causalidade, se há confusão na forma de reportar | Equipe: "é evidência de…" + correlação, causalidade ou indefinido + "há confusão? sim, não, em parte" + comentário | `lente_epistemica` jsonb |
| Lente 2: antecedente, consequente ou North Star; implicação para a velocidade da decisão | Equipe: classificação + texto | `lente_tempo` jsonb (o cliente também diz quanto tempo leva para o número mudar depois de uma ação) |
| Lente 3, Goodhart: como pode ser manipulada (por pessoas, algoritmos, mercado) e se já está acontecendo | Equipe: texto + "já acontece? sim, não, suspeita" | `lente_goodhart` jsonb |
| Lente 4: denominador oculto e se ele mudaria a leitura | Equipe: texto + "muda a interpretação? sim, não" | `lente_denominador` jsonb |
| Lente 5: viés de seleção, se é a população certa | Equipe: texto + "população adequada? sim, parcial, não" | `lente_selecao` jsonb |
| **Seção 3, Arquitetura (25%):** 3a. North Star explícita? Qual? Captura o mecanismo de valor? Senão, qual seria a candidata | Cliente: "tem North Star? qual?"; equipe: "captura o valor? sim, em parte, não" + candidata | `diagnosticos.arquitetura` jsonb |
| 3b. **Conexão causal** entre as métricas e com a North Star, ou silos; desenhar o mapa | Equipe: liga as métricas (de → para, "influencia" ou "é parte de") ou marca "silo"; o relatório **desenha o mapa** | `diagnosticos.mapa_causal` jsonb (lista de ligações) → desenho no relatório |
| 3c. **Guardrails ausentes**: KPI otimizado sem métrica de saúde e o risco concreto | Equipe: lista de "KPI → saúde que falta → risco". O cliente responde antes: "quando melhora um número, vocês olham se piorou outro?" | `arquitetura.guardrails` |
| 3d. **Ativação e Time to Value**: primeiro valor definido? Evento observável? Quanto tempo leva? Que parte não chega na janela? TTV como causa ou diagnóstico, não como North Star | Cliente: primeiro valor, evento, tempo médio, parte que não chega (se souber); equipe: avaliação | `arquitetura.ativacao` |
| 3e. **Retenção e expansão**: separa receita de clientes novos e existentes? Lê retenção, churn e expansão juntas? Sinaliza NRR para a etapa seguinte quando fizer sentido | Cliente: "separa a receita de novos e de existentes? sim, não"; "acompanha churn, renovação e upsell juntos?"; equipe: lacuna + "recomendar NRR na próxima etapa" | `arquitetura.retencao` |
| **Seção 4, Recomendações (15%):** 4a. Métrica mais mal usada e o que muda (definição, cálculo, interpretação) | Equipe | `diagnosticos.recomendacoes` jsonb |
| 4b. Métrica mais importante que falta, olhando primeiro valor, ativação e TTV, e retenção, churn e expansão quando o modelo pede | Equipe; o sistema lembra as checagens conforme o modelo de negócio | idem |
| 4c. Mudança de arquitetura de maior impacto | Equipe | idem |
| 4d. Como construir uma arquitetura nova e mais eficaz | Equipe | idem |
| Lista final: **North Star, métricas de resultado (output) e KPIs, métricas de entrada (input) e guardrails, com números** | Equipe: tabela com tipo, métrica, definição, valor atual (do que o cliente informou ou dos arquivos), meta e fonte | `diagnosticos.arquitetura_nova` jsonb |

**Mudanças a mais por causa do documento:**
- D7 ganha as 5 lentes (jsonb) e "usada para decidir".
- D6 ganha `arquitetura`, `mapa_causal`, `recomendacoes` e `arquitetura_nova` (jsonb).
- O bloco da métrica no formulário ganha numerador, denominador, janela, inclusões e exclusões, decisão associada e clareza do responsável.
- O formulário ganha as perguntas de North Star, primeiro valor e TTV, guardrails e receita de novos e existentes.

Nenhuma tabela a mais além das três já previstas.

**O relatório técnico tem um contador de palavras.** O documento pede entre 1.200 e 2.000 palavras, e o relatório mostra quantas tem.

**Ajuda opcional:** a equipe pode pedir à IA do Growth's (a função `perguntar`, que já existe) uma primeira versão das 5 lentes e das recomendações, sempre marcada como sugestão para a equipe revisar. Fica para depois da G3 e só se você quiser.

## 7. Pendências que dependem de você

1. **Material de base:** o documento "01 - Diagnóstico de Arquitetura de Métricas - Produto Base" já está coberto (seção 6). Falta a **aula da Ana sobre os primeiros 90 dias**, para as fases do projeto de implantação (G5). Ela não bloqueia as etapas G1 a G4.
2. **Formulário do Growth's ou Google Forms.** Recomendo o **formulário do próprio Growth's**:
   - ele já tem link público e não pede login do Google;
   - a resposta cai direto no cadastro do cliente;
   - o mesmo link leva à Central de Documentos.

   Com o Google Forms, as respostas teriam de ser importadas e ligadas ao cliente depois.
3. **Validade do link de envio:** 30 dias por padrão?
4. **Quem dispara o diagnóstico:** sozinho, ao ativar o contrato de um produto marcado "com diagnóstico", ou a equipe manda manualmente?
