# Diagnóstico 360° de Growth, Dados e Maturidade Operacional: plano técnico

**Data:** 30/10/2026 · **Situação:** só o plano. Nada foi construído nem migrado.
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

## 1. O que já existe e onde cada parte entra

| Parte da especificação | O que já existe | O que falta |
|---|---|---|
| Formulário em 8 seções, perguntas condicionais | `pesquisas` + `pesquisa_perguntas` (com `secao`, `obrigatoria`, `pontos`). Tipos de pergunta: nps, escala, escolha, múltipla, sim/não, texto | "Para quem" (lead ou cliente); tipos de pergunta novos (número, valor em reais, valores por mês, **métrica**, **arquivos**); **condição** para mostrar a pergunta; tipo `diagnostico` |
| Link individual e seguro | `pesquisa_envios` (um código por pessoa, status, respondido em) | **Validade** do link (`expira_em`); o mesmo link abre a Central de Documentos |
| Avaliação de cada métrica (acompanha?, como calcula, responsável, uso nas decisões, fonte, periodicidade, granularidade, validação, confiabilidade) | — | Pergunta do tipo `metrica`: uma pergunta mostra o bloco inteiro para cada métrica do catálogo; o detalhe vai num campo `valor_json` da resposta |
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
| G1 | Catálogo de métricas completo (D5) + formulário-modelo "Diagnóstico 360°" com as 8 seções e as perguntas novas (D1–D4). O cliente já consegue responder |
| G2 | Central de Documentos com armazenamento seguro (D8) |
| G3 | Pré-diagnóstico automático + tela do diagnóstico para a equipe (D6, D7) |
| G4 | Relatórios executivo e técnico em PDF |
| G5 | Projeto de implantação de 90 dias com o modelo e as tarefas que nascem das lacunas, incluindo a jornada do aluno (D9, D10) |

## 6. Pendências que dependem de você

1. **Aulas do EVA e da Ana** (diagnóstico e primeiros 90 dias): a transcrição, o PDF ou o nome exato da aula. As seções, as perguntas e as fases acima são proposta nossa; com o material, ajusto aos critérios das aulas antes da G1.
2. **Formulário do Growth's ou Google Forms.** Recomendo o **formulário do próprio Growth's**:
   - ele já tem link público e não pede login do Google;
   - a resposta cai direto no cadastro do cliente;
   - o mesmo link leva à Central de Documentos.

   Com o Google Forms, as respostas teriam de ser importadas e ligadas ao cliente depois.
3. **Validade do link de envio:** 30 dias por padrão?
4. **Quem dispara o diagnóstico:** sozinho, ao ativar o contrato de um produto marcado "com diagnóstico", ou a equipe manda manualmente?
