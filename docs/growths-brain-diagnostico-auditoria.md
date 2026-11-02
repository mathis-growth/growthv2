# Growth's Brain: Diagnóstico Inteligente (Fase 1, auditoria)

**Data:** 02/11/2026 · **Base:** a especificação "Growth's Brain: implementação do Diagnóstico Inteligente de Growth" (Rebecka, 02/11) e o código no GitHub (v0.222, commit ddb4469). Nada foi construído nesta fase. O documento serve para decidir antes de construir.

Legenda: **[fato]** está no código ou no banco, conferido · **[hipótese]** suposição que precisa de confirmação · **[recomendação]** proposta minha.

## 1. O que existe hoje

O Diagnóstico está em **três lugares** que se conversam, mas não formam uma tela só.

### 1.1 Formulário do cliente (Pesquisas) [fato]
- Pesquisas do tipo `diagnostico`, com três modelos: Diagnóstico 360° completo (`PQ_DIAG360`), Diagnóstico 360° curto (`PQ_DIAG_CLI`) e Entrada do cliente (números e arquivos).
- Perguntas condicionais (`condicao`) e configuráveis (`config`). Tipos: número, valor em reais, mês a mês, escolha, múltipla, lista, métricas do funil pirata (tenho / não tenho / não sei, com objetivo e como acompanha) e documentos.
- Link individual (`pesquisa_envios.token`), com validade e rascunho salvo sozinho (`pesquisa_rascunho_salvar`).
- O cliente **não precisa entrar no sistema**: é o "portal" que já existe.

### 1.2 Arquivos do cliente (G2, v0.177) [fato]
- O cliente envia os arquivos pelo próprio link do diagnóstico. A função na nuvem `diagnostico-arquivo` autoriza o envio (uso único), o arquivo vai para o local privado `diagnostico` (limite de 20 MB) e a função confere se chegou.
- O registro fica em `pesquisa_arquivos`: nome, tamanho, tipo, grupo, status pendente ou enviado, data.
- **Não guarda hoje:** hash (duplicidade), versão, período representado, classificação do documento, status de processamento, erros.
- Na reunião, PDFs e imagens **só se baixam**. Só planilhas (.xlsx, .xls, .csv, .txt) são lidas.

### 1.3 Reunião do diagnóstico (G3, v0.177) [fato]
Fica em Pesquisas → Quem respondeu → Abrir reunião.
- **Tabela `diagnosticos`** (uma por resposta). Guarda status (`rascunho` ou `validado`), as métricas que decidem (`decide`), `arquitetura` (o roteiro), `notas`, `leitura` (o resultado da leitura das planilhas), além de quem validou e quando.
- **Tabela `diagnostico_metricas`**: para cada número, o que o cliente declarou, o detalhe que a equipe verificou e uma observação.
- **Tela em cinco partes:**
  1. os números que usam para decidir;
  2. como cada um funciona;
  3. o roteiro do que o formulário curto não pergunta (produtos, jornada, North Star e guardrails, dados, gestão, prioridades);
  4. documentos;
  5. anotações e o botão Validar.
- Permissões: ler para gro, adm e mkt; editar só para gro. Isolamento por empresa com RLS (`pertence_ao_workspace`).

### 1.4 Diagnóstico Growth, a tela `gro-diag` [fato]
- Lê planilhas no navegador (SheetJS):
  - acha o cabeçalho mesmo com título em cima;
  - sugere o tipo (vendas, leads, investimento, planilha estruturada);
  - sugere o significado de cada coluna, com troca manual;
  - mostra as primeiras linhas.
- Também deixa conferir canais, produtos e status (quais contam como venda), e define a renovação por número de dias.
- **Consolidar e diagnosticar** gera:
  - % de completude;
  - cobertura por mês;
  - o que tenho / parcial / falta;
  - a mensagem para o cliente.
- **Saídas:** planilha padronizada (.xlsx), diagnóstico em .txt, ou salvar como Growth Model (`gm_modelos`).
- Aberta pela reunião, a leitura vai para `diagnosticos.leitura` e não mexe no Growth Model da empresa.
- **Não faz hoje:** deduplicação explícita de linhas (só por regra de renovação), datas inconsistentes, validade dos valores, fórmulas e coerência entre fontes.

### 1.5 O que está ao redor [fato]
| Peça | Onde | Serve para |
|---|---|---|
| Catálogo de métricas | `metricas_definicoes` (69 linhas; etapa AARRR, natureza valor/taxa, fórmula, fonte, "calcula sozinho") | Catálogo de métricas disponíveis (§10) |
| Árvore de métricas e NSM | `growth_metricas` (pai_id, tipo north_star/driver/input, `nsm_status` = provisória desde a v0.213, `nsm_evento`, `nsm_populacao`), na aba "Mapa de métricas e North Star" | Árvore (§12) e NSM (§11) |
| Guardrails | `guardrail_definicoes`, `guardrail_alertas`, `exp_guardrails` | Guardrails da árvore |
| Hipóteses e experimentos | `growth_experimentos` (Ciclo de Growth, ICE), `gm_cenarios`, `gm_decisoes` | Oportunidades (§15) e decisões |
| Marcos de valor por produto | `jornadas`, `jornada_marcos` (evidência e prazo), `aluno_marcos` (Customer Growth) | NSM por produto e instrumentação (§11, §14) |
| Planejamento anual | `metas` (registro único), `plano_objetivos`, `planejamento_mensal`, `plano_anual` | Publicação (§19) |
| Cockpit | `metas_painel`, `riscos`, `investigar`, `projecao_*` | Consumo (§20) |
| Tarefas | `projetos`, `projeto_atividades`, `projeto_modelos` | Plano de instrumentação vira tarefa (§14) |
| IA | Função `perguntar` (Claude/ChatGPT, temperatura 0, só sobre o resumo do servidor, limite de 40/hora, registro em `ia_perguntas` com modelo, conferência dos números) | Modelo para a extração com IA (§7, §22) |
| PDF | Só impressão do navegador (`window.print`) em três telas | Entregáveis (§18) |

### 1.6 O que há no banco de produção hoje (leitura de 02/11) [fato]
| Item | Quantidade |
|---|---|
| Diagnósticos | 1 (rascunho, 5 métricas detalhadas) |
| Pesquisas do tipo diagnóstico | 4, com 1 resposta |
| Arquivos enviados por cliente | 0 |
| Growth Models salvos | 3 |
| North Star | 2, ambas provisórias |
| Métricas da árvore | 16 |
| Metas | 15 |
| Riscos | 5 |

Ou seja, há pouco dado real a preservar, mas o que existe precisa continuar abrindo.

## 2. Matriz de reaproveitamento

| Pedido da especificação | O que existe | Decisão [recomendação] |
|---|---|---|
| §3 Diagnóstico com empresa, responsável, período, status, progresso, versão, histórico | `diagnosticos` (status, validado_por; sem responsável, período, versão nem progresso) | **Evoluir** `diagnosticos`: colunas novas e status com mais estados. Histórico em tabela de decisões. Não criar outra tabela de diagnóstico. |
| §3 Cinco áreas na mesma tela | A reunião (5 partes) e `gro-diag` (planilhas) separadas | **Juntar** numa tela só de Diagnóstico, com o padrão de abas da v0.222: Evidências · Investigação · Dados · Arquitetura · Validação e entrega. A reunião atual vira a aba Investigação e a leitura de planilhas vira a aba Dados. O menu continua "Diagnóstico Growth". |
| §4 Central de Evidências | `pesquisa_arquivos` + local `diagnostico` | **Evoluir** `pesquisa_arquivos`: hash, classificação manual/sugerida, período, status de processamento, erro, versão. Upload pela equipe também (hoje só o cliente envia). |
| §5 Pipeline (validação, extração, normalização) | Leitura de planilha no navegador; nada para PDF/DOCX | **Planilhas:** continuar no navegador (já funciona, não custa IA). **PDF/DOCX/TXT:** função na nuvem nova para extrair texto e uma fila simples no banco (status, tentativas, erro). |
| §6 Inventário por domínios | O roteiro da reunião (`arquitetura.roteiro`) já cobre modelo, produtos, jornada, North Star, dados, gestão | **Reaproveitar** as perguntas do roteiro como os campos do inventário. Cada resposta vira uma afirmação com origem "reunião". |
| §7 Afirmações extraídas com origem e estados | Não existe (o mais perto é `diagnostico_metricas.declarado` × `detalhe`) | **Criar** `diagnostico_afirmacoes`: uma tabela para tudo o que se sabe, vindo de formulário, reunião, planilha, documento ou IA. Com estado, trecho, origem, confiança da extração e conflito. |
| §8 Perguntas dinâmicas por lacuna | Formulário fixo + condicionais | **Criar** `diagnostico_perguntas` (gerada pelas lacunas, com responsável, prioridade, tipos "não sei / não medimos / não se aplica"). O envio ao cliente reaproveita o link da pesquisa. |
| §9 Auditoria de planilhas | `gxMontaTab`, `gxDetectaTipo`, `gxDetectaCampos`, `gxDiagnostico` | **Evoluir** no navegador: qualidade (completude, unicidade, validade, datas fora do período, valores negativos, duplicidades), cobertura por produto e canal. O resultado vai para o banco como evidência. O arquivo original nunca muda. |
| §10 Catálogo de métricas disponíveis | `metricas_definicoes` (definição, fórmula, fonte) + `metas_nivel_valor` / `calcAuto` | **Reaproveitar** o catálogo. **Criar só** o vínculo diagnóstico × métrica com a classificação (disponível e validada … não disponível): estender `diagnostico_metricas`, que já é por código do catálogo. |
| §11 NSM: candidatas, estados, aprovação humana | `growth_metricas` tipo north_star com `nsm_status` (provisória) | **Criar** `diagnostico_nsm` (candidatas e comparação). Aprovar publica na `growth_metricas` existente (não duplica). Marcos por produto = `jornada_marcos`. |
| §12 Árvore de métricas | `growth_metricas` (pai_id, driver/input) + tela do mapa | **Reaproveitar** a árvore e a tela. Rascunho da árvore dentro do diagnóstico (JSON versionado); ao publicar, vira linhas em `growth_metricas`. Falta o tipo de relação (componente matemático × hipótese), que está na lista de prioridades (item 6) e serve aos dois. |
| §13 Hipóteses e validação | `growth_experimentos`; coortes e retenção em Customer Success | **Criar** registro de hipóteses do diagnóstico. A comparação de grupos reaproveita as funções de retenção e coortes que já existem. Sem causalidade automática. |
| §14 Mapa de instrumentação | Nada específico; tarefas em `projeto_atividades` | **Criar** `diagnostico_instrumentacao`. Com autorização, cada item vira atividade no projeto do cliente. |
| §15 Oportunidades com ICE/RICE | `growth_experimentos` (ICE) | **Criar** oportunidades no diagnóstico; ao aprovar, viram experimento no Ciclo de Growth (sem duplicar). |
| §16 Pendências e decisões | `diagnosticos.notas` | **Criar** `diagnostico_decisoes` (decisões e comentários, com autor e data). As pendências saem das perguntas, conflitos e lacunas, sem tabela extra. |
| §17 Cliente | Link da pesquisa (sem login) | **Reaproveitar** o link: o cliente responde às perguntas novas e envia arquivos por ele. Notas internas nunca saem no link. |
| §18 Quatro entregáveis | `leitura` + mensagem; plano G4 (PDF) não feito | Entregáveis montados dos dados (sem tabela própria), com versão congelada na publicação. PDF pela impressão do navegador, que é o que existe. |
| §19 Publicação no Planejamento | `metas`, `plano_objetivos`, `growth_metricas` | **Criar** `diagnostico_publicacoes` (o que foi publicado, versão, quando, por quem, diferenças). Publica só o que foi aprovado; hipótese nunca vira meta. |
| §20 Cockpits | Já leem `metas`, `growth_metricas` (NSM) e o catálogo | Nada novo: publicar no lugar certo já faz o Cockpit enxergar. |
| §22 IA e segurança | Função `perguntar` como modelo | **Função nova** `diagnostico-ia`: conteúdo do documento sempre como dado, saída em JSON validada, registro de modelo, versão do prompt e custo; limite por dia; custo só para a Rebecka. |

**Estruturas novas** [recomendação]: `diagnostico_afirmacoes`, `diagnostico_perguntas`, `diagnostico_nsm`, `diagnostico_hipoteses` (hipóteses e oportunidades, com tipo), `diagnostico_instrumentacao`, `diagnostico_decisoes`, `diagnostico_publicacoes` e uma fila `diagnostico_processamentos`. Ficam **evoluídas** `diagnosticos`, `diagnostico_metricas` e `pesquisa_arquivos`.

## 3. Pontos que precisam de decisão

1. **De quem é o diagnóstico.** [fato] Hoje o diagnóstico nasce de uma **resposta de pesquisa** e se liga a uma **pessoa** (o cliente) dentro do workspace da Mathisa. Já a especificação publica o resultado no **Planejamento anual**, que é **da empresa (workspace)**. [hipótese] Se cada cliente da Mathisa tem (ou vai ter) o seu próprio workspace no Growths, o diagnóstico precisa saber em qual empresa publicar.
2. **Diagnóstico sem formulário.** Hoje só existe diagnóstico a partir de uma resposta (`resposta_id` obrigatório). Para a equipe começar um diagnóstico só com arquivos, essa obrigação precisa sair.
3. **IA para PDF, DOCX e texto.** Ler documentos de estratégia e oferta exige chamar a IA (custo por documento). A chave do Claude já está configurada para o "Perguntar".
4. **Ordem de construção.** A especificação tem 8 fases. [recomendação] Construir em versões pequenas, cada uma testada, igual ao Brain:

| Versão | Fase | O que entrega |
|---|---|---|
| D1 | 2 | Tela única em abas; diagnóstico com empresa, responsável, período, status e progresso; Central de Evidências (upload pela equipe, hash e duplicidade, classificação manual, período) |
| D2 | 3 | Afirmações com origem e estados (o que veio do formulário e da reunião vira afirmação); conflitos; pendências por prioridade; decisões |
| D3 | 3 | Perguntas dinâmicas pelas lacunas, com responsável, e respostas do cliente pelo link |
| D4 | 4 | Auditoria de planilhas (qualidade, cobertura, duplicidades, datas) e catálogo de métricas disponíveis com a classificação |
| D5 | 2–3 | Extração de PDF/DOCX/TXT com IA (fila, reprocessamento, saída validada, custo) → afirmações "identificadas automaticamente" para revisão |
| D6 | 5 | NSM: investigação, candidatas, comparação e aprovação humana; NSM por produto (marcos) |
| D7 | 5–6 | Árvore no diagnóstico (componente × hipótese), hipóteses, instrumentação e oportunidades (ICE/RICE) |
| D8 | 7 | Entregáveis, versões, publicação no Planejamento com diferenças; testes de ponta a ponta A, B e C |

## 4. Limites que já dá para ver

- **Arquivos:** o limite atual é de 20 MB por arquivo. Planilhas muito grandes são lidas no navegador; acima de cerca de 100 mil linhas, a tela fica lenta [hipótese, a medir na D4].
- **PDF escaneado** (imagem) precisa de leitura de imagem pela IA, com custo maior. Na D5 entra só o PDF com texto; o escaneado fica marcado como "precisa de leitura de imagem".
- **Conteúdo malicioso:** dá para conferir o tipo real do arquivo (assinatura), o tamanho e a extensão. Não há antivírus no Supabase; os arquivos nunca são executados, só lidos como dado.
- **Testes estatísticos** (§13) só quando a amostra permitir; abaixo disso, o Growths diz "amostra pequena" e não calcula.
- O **relatório em PDF** sai pela impressão do navegador, como nas outras telas.

## 5. Decisões da Rebecka (02/11)

1. O diagnóstico é **da empresa (workspace)** e publica no Planejamento dela.
2. A IA lê PDF, Word e texto com **limite diário**; o custo fica visível só para ela.
3. Construir na ordem **D1 a D8**. A D1 foi entregue na v0.223.
