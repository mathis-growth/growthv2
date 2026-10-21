# Registro de implementação do Growths

Documento vivo. A ideia é você abrir este arquivo no dia da revisão e ver, módulo por módulo, o que foi pedido, o que está pronto, o que foi testado e como, o que falta e o que pode melhorar. Atualizado a cada entrega. Última atualização: 06/10/2026 (funil no pós-compra e cohorts com ROI, LTV e churn).

## Como ler

- **Pronto**: existe, foi testado e usa dados reais do banco.
- **Parcial**: existe, mas falta uma parte (quase sempre uma integração externa).
- **Pendente**: pedido registrado, ainda não construído.
- **Testado**: "banco" = função ou regra rodada de verdade no Supabase e revertida; "tela" = tela aberta num navegador simulado com dados de teste. **Nenhuma tela foi testada com login real**, porque o ambiente de trabalho não alcança o Supabase. Esse é o primeiro item da revisão.

## Princípios que valem para tudo

1. Todo cálculo (CAC, LTV, CPL, ROAS, churn, retenção, conversão, NPS, média de notas) é código fixo, nunca IA.
2. Sugestões (gargalo, "produzir agora", alertas de fadiga) usam regras fixas e documentadas; quem decide é você.
3. Contabilidade é imutável: só estorno, nunca edição.
4. Cada workspace só enxerga os próprios dados (RLS no banco).
5. Fora do escopo: emissão de nota fiscal e conciliação bancária automática.
6. Senha de teste nunca é guardada nem enviada ao repositório.

## Inventário por módulo

### Marketing

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Dashboard de marketing | Marketing, Dashboard | Pronto | tela | Comparar períodos lado a lado |
| **Campanha como página central**: lista com filtro de status e modelo; página com abas Resumo, Funil da campanha, Análise e cohorts, Mídia paga, Vídeos e eventos, Leads e vendas, Links e tracking, Debriefing | Marketing, Campanhas e planejamento | Pronto | banco, tela | Comparar duas campanhas lado a lado; criar experimento direto do debriefing |
| **Status e modelo da campanha**: rascunho, planejada, ativa, pausada, finalizada; lançamento (começo, meio e fim, com carrinho) ou perpétuo (sem data de fim, banco bloqueia fim em perpétuo) | Marketing, Campanhas | Pronto | banco, tela | |
| **Vídeos, webinários e VSL ligados à campanha**: criar ou vincular dentro da campanha, com indicadores por vídeo | Campanha, aba Vídeos e eventos; Marketing, Vídeos e webinários | Parcial | banco, tela | Hoje um vídeo pertence a uma campanha só. Métricas por planilha ou lançamento; falta integração com a plataforma de vídeo |
| **Debriefing por campanha**: meta e realizado calculados por regra fixa, mais 5 campos de análise | Campanha, aba Debriefing | Pronto | banco, tela | |
| Mídia paga (antes "Tráfego pago") por anúncio, com CTR, CPC, connect rate, conversão da página, CPL | Marketing, Tráfego pago | Parcial | banco, tela | Entrada por lançamento e CSV. Falta a integração direta com Google Ads e Meta Ads |
| Leads por origem (UTM, gclid, fbclid, referrer) | Vendas, Leads por origem (saiu do Marketing) | Pronto | banco, tela | |
| Webinário e VSL: visualizações, retenção, presença | Marketing, Vídeos | Parcial | banco, tela | CSV e lançamento manual. Falta integração com a plataforma de vídeo (depende de qual você usa) |
| Campanhas, metas e planejamento anual | Marketing, Campanhas e planejamento | Pronto | banco, tela | |
| Links e tracking dentro da campanha (UTMs, links por canal) | Campanhas, aba Links e tracking | Pronto | tela | Encurtador de link próprio |
| Planejamento de conteúdo: linhas editoriais, temas, Kanban, 5 notas, plano semanal, etiquetas de canal, relatórios | Marketing, Planejamento de conteúdo | Parcial | banco, tela | Pesquisa diária por IA, postagem no Instagram a partir do Drive e coleta automática de métricas dependem de credenciais externas. Hoje: ideias por "Colar ideias", métricas por planilha |

### Vendas

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Dashboard de vendas | Vendas, Dashboard | Pronto | tela | |
| Quadro do funil (etapas, listas de grupo e API, regras de entrada e saída), antes "CRM" em Vendas | Campanha, aba Funil da campanha | Pronto | banco, tela | Entrada automática por webhook (hoje por função do banco). Visão de todas as campanhas juntas deixou de existir: hoje o quadro é sempre de uma campanha |
| Funil comercial | Vendas, Funil comercial | Pronto | tela | |
| Funil da campanha filtra por origem, lista e busca | Campanha, aba Funil da campanha | Pronto | tela | Os leads também aparecem na aba Leads e vendas da campanha |

Nota de nome: o módulo se chama **Vendas** (Dashboard, Funil comercial, Leads por origem). O quadro por etapa que era "CRM" agora é **Funil da campanha** e fica dentro de cada campanha. A aba "Funil e cohorts" virou **Análise e cohorts**.

### RevOps

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Painel de alunos: retenção, churn, LTV, produtos mais vendidos, ascensão, com semáforo | RevOps, Dashboard | Pronto | banco, tela | O churn de assinatura recorrente precisa de definição sua. O nível de cada produto na escada precisa ser preenchido nos produtos reais |
| Alunos por etapa da jornada | RevOps, Alunos | Pronto | tela | |
| Dados simulados para demonstração | Workspace "RevOps — Simulação" | Pronto | banco | Apagar o workspace remove tudo |

### Financeiro

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Vendas e a receber, taxas de plataforma, impostos | Financeiro, Vendas e a receber | Pronto | banco, tela | |
| Contas a pagar | Financeiro, Contas a pagar | Pronto | banco, tela | |
| Lançamentos contábeis imutáveis, plano de contas, centros de custo, regras | Financeiro, Lançamentos | Pronto | banco | Relatórios contábeis formais (DRE, balanço) |
| Fluxo de caixa | Financeiro, Dashboard | Pronto | tela | |

### Projetos

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Campanha vira projeto sozinha; projeto manual; modelos; atividades com dependência e liberação em sequência | Projetos | Pronto | banco ponta a ponta, tela | |
| Avisos ao responsável (app, e-mail, WhatsApp) | Projetos, Avisos e sino | Parcial | banco, tela | Só o sino dentro do app. E-mail e WhatsApp precisam de provedor |
| Aviso de atividade atrasada | | Pendente | | Precisa de tarefa agendada no banco |
| Final da sua mensagem sobre projetos ("reparta essa tarefa em várias atividades e…") | | Pendente | | A mensagem chegou cortada. Preciso do restante |

### Growth

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Growth Model (árvore de métricas, NSM, alavancas) | Growth, Growth Model | Pronto | banco, tela | Preencher com a sua NSM depois da pesquisa |
| Ciclo de Growth: Kanban de experimentos, ICE, aprendizado obrigatório para concluir | Growth, Ciclo | Pronto | banco, tela | Painel de aprendizados por métrica |
| **Análise de funil clicável**, por campanha e período, com gargalo | Growth, Análise de funil | Pronto | banco (dados reais), tela | Ver a lista abaixo |
| **Funil no pós-compra (RevOps)**: entrada como aluno, cada etapa da jornada do aluno, ainda ativos, saíram, ascensão, recompra; clicável, com quebra por campanha e canal e lista de pessoas | Growth, Análise de funil | Pronto | banco (dados reais), tela | O histórico de etapas do aluno só existe a partir de agora; antes, "chegou na etapa" vale para quem está nela ou adiante |
| **Retorno do grupo de leads**: alunos, churn, retenção, LTV, CAC, ROAS, ROI, ascensão | Growth, Análise de funil | Pronto | banco (conferido contra consulta independente), tela | Custo só de anúncios; custos do financeiro (equipe, ferramentas) ainda não entram no ROI |
| **Cohorts** por semana, mês ou campanha, em três visões: Conversão (7 a 90 dias), Retorno (custo, CPL, CAC, LTV, LTV÷CAC, ROAS, ROI) e Pós-compra (churn, retenção, retenção em 30/60/90 dias, ascensão, recompra) | Growth, Análise de funil, aba Cohorts | Pronto | banco, tela | Comparar duas campanhas lado a lado; curva de retenção por idade |
| **Pesquisas**: lead, onboarding, jornada, descoberta da NSM; construtor, gatilho por etapa, fila, link de resposta, resultados, insights | Growth, Pesquisas | Parcial | banco ponta a ponta, tela | O envio automático (WhatsApp, e-mail) depende de integração. Hoje: fila, copiar link, botão de WhatsApp e marcar como enviado |
| Pesquisas e insights dentro do loop de experimentação | Insights, "Criar experimento" | Pronto | tela | |

### Administrativo e configurações

| Pedido | Onde | Status | Testado | Falta ou pode melhorar |
|---|---|---|---|---|
| Painel gerencial, cadastros (clientes, equipe, fornecedores, produtos, plataformas, canais, anúncios, vídeos, funis, plano de contas, centros de custo, regras, impostos, bancos) | Administrativo | Pronto | tela | Anúncios e vídeos deixaram de ter cadastro manual: virão das plataformas (Google/Meta Ads e hospedagem de vídeo) |
| Registro de integrações | Configurações, Integrações | Parcial | tela | É só um controle de status. Nenhuma conexão automática existe ainda |

### Infraestrutura

| Item | Status | Observação |
|---|---|---|
| Banco Supabase com RLS por workspace | Pronto | Projeto saudável, região São Paulo |
| Login e dados reais pela tela | **Não testado** | O ambiente de trabalho não alcança o Supabase. Testar abrindo o arquivo num navegador comum |
| Hospedagem do arquivo | Pendente | Precisa de GitHub conectado e um nome de repositório. Sem isso, o link de resposta das pesquisas não funciona para outras pessoas |
| Visualizador do app | Limitação | Bloqueia chamadas ao Supabase. Abrir num navegador de verdade |

## Análise de funil e pesquisas: o que foi decidido

- **Lead** é a pessoa cadastrada no período (fuso de São Paulo). A coorte é seguida até hoje, então "chegou na etapa" olha o histórico completo da pessoa.
- **Passos**: impressões, cliques, visualizações da página (anúncios, por data), leads, cada etapa do funil escolhido, clientes (venda aprovada). **Qualificados** e **responderam pesquisa** aparecem como laterais, porque não são uma etapa depois da outra.
- **Gargalo**: passo que mais piorou contra o período anterior de mesmo tamanho, com queda de pelo menos 15% e base de pelo menos 10. **Maior perda**: passo em que mais pessoas ficaram pelo caminho. Ambos são sugestão.
- **Funil automático**: o da campanha escolhida; sem campanha, o que tem mais gente.
- **Pós-compra**: parte dos mesmos leads do período. "Chegou na etapa do aluno" = está nela, está numa etapa mais adiante (pela ordem) ou já passou por ela (histórico novo, `aluno_historico`). **Ativo** = tem pelo menos um cadastro de aluno sem data de saída. **Churn do grupo** = alunos que saíram ÷ alunos do grupo. **Ascensão** = comprou nível da escada maior que o maior já comprado. **Recompra** = 2 ou mais compras aprovadas. Pode haver mais alunos que clientes (aluno cadastrado sem venda aprovada no período); aí a tela mostra "pulou etapa?".
- **Retorno**: LTV = receita ÷ clientes; CAC = custo de anúncios ÷ clientes; ROAS = receita ÷ custo; ROI = (receita − custo) ÷ custo. Sem custo registrado, ficam em branco. A receita é de vendas aprovadas até hoje, então coortes novas ainda vão subir.
- **Retenção em 30/60/90 dias**: entre os alunos que entraram há pelo menos N dias, os que ainda estavam ativos N dias depois de entrar.
- **Cohort**: janelas de 7 a 90 dias contam a primeira compra aprovada depois da entrada. Janela em itálico ainda está aberta.
- **Pesquisa dispensada**: quem já chegou qualificado pela página de obrigado não entra na fila quando a opção está marcada.
- **NPS**: promotores (9 e 10) menos detratores (0 a 6), sobre o total. **PMF**: parcela que marcou a primeira opção da pergunta de PMF; 40% ou mais é a referência.
- **Descobrir a NSM**: o sistema organiza e conta as respostas de "valor" e de "alavanca". Escolher a métrica é decisão sua e fica registrada em Insights.
- **Link de resposta**: cada envio tem um link único e secreto. O link aberto (para a página de obrigado) vem desligado e só funciona se você ligar. Respostas ficam presas ao workspace da pesquisa.

## Ideias registradas e ainda não construídas

1. Envio automático das pesquisas por WhatsApp e e-mail, com horário e limite de tentativas.
2. Quebra dos resultados da pesquisa por campanha, canal e etapa do funil.
3. Pontuação automática de qualificação a partir das respostas da pesquisa de lead (hoje a qualificação vem de fora).
4. Comparação de duas coortes ou campanhas lado a lado.
5. Funil por criativo (anúncio), ligando utm_content ao passo.
6. Alerta automático quando um passo piora (hoje só aparece ao abrir a tela).
7. Exportar tabelas e cohorts para CSV.
8. Correlação entre ações do aluno e resultado, para apoiar a escolha da NSM.
9. Tela de revisão deste registro dentro do app, com status editável.

## Perguntas em aberto para a revisão

- Um vídeo ou VSL pode servir a mais de uma campanha? Hoje cada vídeo pertence a uma só. Se precisar de vários, trocamos por uma ligação muitos-para-muitos.
- A lista de status serve (rascunho, planejada, ativa, pausada, finalizada)? Mantive "pausada" além dos quatro que você citou.

- Anúncios e vídeos: o cadastro manual saiu do menu Administrativo. As tabelas continuam no banco porque tráfego, funil e custo leem delas e as integrações vão alimentá-las. Quando as integrações existirem, o anúncio e o vídeo nascem da plataforma. Se quiser, removo as tabelas também, mas o tráfego pago deixa de funcionar até a integração.

- Quais etapas do pós-compra você usa? Hoje a jornada do aluno tem Novo aluno, Onboarding, Em andamento e Concluído. Se tem Ativação, Retenção ou Ascensão como etapas, é só cadastrar em RevOps, Alunos e elas entram no funil sozinhas.
- O ROI deve incluir custos do financeiro (equipe, ferramentas) além do gasto com anúncios?
- Em qual plataforma você roda o webinário e a VSL? Define a integração de vídeo.
- Qual provedor de IA você quer para a pesquisa diária de pautas?
- Os cinco critérios de nota de conteúdo servem ou você quer outros?
- Quais são as metas semanais reais de vídeo e carrossel?
- Como você define churn quando o aluno tem assinatura recorrente?
- Os limites do gargalo (queda de 15%, base de 10) fazem sentido para o seu volume?
- Qual o final da sua mensagem sobre projetos?
- Lembrete: trocar a senha usada nos testes de login.

## Marketing: dashboard geral, dashboard da campanha e Fechamento
- Dashboard geral de todas as campanhas (período, cohorts); aba Dashboard em cada campanha; aba Fechamento com planejado x realizado, debriefing e melhorias por sprint (sugestões por regra fixa, sem IA); botão Fechar a campanha guarda a foto dos números.
- Em aberto: um vídeo servir a várias campanhas; manter status "pausada".

## Contratos de prestação de serviço
- Regras: produto tipo "serviço" (já existente) + contrato com vários itens; recorrente = valor de cada item é o de uma cobrança e as parcelas vão do início ao fim; não recorrente = valor total dividido em N parcelas. Contabilidade por regra fixa, competência na data de vencimento de cada parcela.
- Em aberto: a receita de contrato ainda NÃO entra na análise de funil/cohorts (receita, LTV, ROAS, ROI usam só vendas); acesso do cliente é texto livre (não libera plataforma sozinho); parcelas de contrato não passam por estorno de venda, só cancelamento do contrato.

## Planejamento da empresa e CRM (v0.12)
- Plano → objetivos → índices → metas por setor → campanhas; realizado automático por regra fixa. Em aberto: índices como churn, retenção e NPS ainda são manuais; o Painel gerencial (dashboard da empresa) ainda não consome o plano; metas por setor sem rotina de revisão/alerta.
- CRM: filtros, cartão completo, ganho/perdido com motivo e tags. Em aberto: análise de motivos de perda por campanha/origem no funil.

## Importação segura e Voltar (v0.13)
- Regra de negócio: dado de mídia paga e de vídeo vem de integração. Planilha é exceção controlada (primeira carga ou falha), só administrador, com justificativa, conferência, coerência, sem sobrescrever e com histórico reversível. Escrita direta nas tabelas de métricas foi revogada no banco.
- Navegação: pilha de telas visitadas (até 40) por workspace; botão Voltar e popstate.
- Não testado com dados reais (sem acesso ao Supabase neste ambiente); testado no banco com rollback e na interface com dados simulados.
- Em aberto: importação de outros tipos (vendas, leads) segue fora; limite de 10 por dia é fixo.

## Painel gerencial (v0.14)
- NRR/GRR calculados pelos contratos recorrentes (ativo na data = ativado, início ≤ data, sem fim ou fim ≥ data, não cancelado antes). Não há histórico de reajuste de itens: o valor usado é o atual do contrato.
- Penetração depende de `planos.mercado_total` (campo novo no plano).
- Em aberto: churn, LTV e outras métricas que ela levantar depois; OKRs no painel.

## Rastro financeiro (v0.15)
- O rastro busca `v_lancamentos` por `origem_id` (venda, conta a receber, conta a pagar), os estornos ligados e `movimentacoes_bancarias`. Em aberto: assinatura vinda de plataforma (Hotmart) chega como vendas separadas, ainda sem agrupar as cobranças de uma mesma assinatura; botão de rastro também nas telas de fluxo de caixa e na ficha da pessoa.

## CAC e período (v0.16)
- CAC de mídia = custos das contas marcadas como mídia ÷ clientes novos. CAC total = todas as contas com "Entra no CAC" ÷ clientes novos. Cliente novo = primeira venda aprovada ou primeiro contrato ativado dentro do período. Custo pela competência da conta a pagar.
- Peso na margem = custo de aquisição ÷ receita do período (em pontos percentuais).
- Em aberto: equipe e ferramentas só entram se marcadas no Plano de contas; rateio de custo de equipe entre campanhas.

## Projetos, cadastros e ficha (v0.17 a v0.19)
- Cadastros ficam dentro de Configurações. Cadastro do lead em seções (contato, origem, rastreamento UTM, negócio); a ficha mostra jornada de compra, compras, engajamento em vídeos, projetos e notas.
- Painel dos projetos: filtros por situação, período e busca; contagem de concluídos (`concluido_em` por gatilho). Projeto vinculado ao cliente, contrato, venda e produto; produto com "modelo de projeto" gera o projeto e as atividades automaticamente ao vender/ativar contrato.
- Canais novos no catálogo (WhatsApp API oficial, TikTok Ads, LinkedIn Ads, GPT Ads): só catalogados, sem conexão. CAC de mídia por canal no tráfego. Fluxo de caixa e DRE com ações (recebido, estorno, cancelar) e detalhe do lançamento. Ficha do aluno ao clicar no cartão.
- Em aberto: receita de contratos no funil/ROI/LTV; assinatura da Hotmart agrupada; OKRs no Painel.

## Etapas editáveis, responsáveis e alertas (v0.20)
- Etapas do funil de leads e dos alunos são editáveis (nome, ordem, "o que precisa acontecer", mensagem padrão, avisar responsável). "Cliente" nos leads é fixa porque vendas e contratos dependem dela; a primeira etapa dos alunos é usada pela automação de venda aprovada.
- Responsável comercial (`pessoas.responsavel_comercial_id`) e CS (`alunos.responsavel_cs_id`), com filtros "Só os meus", "Sem responsável" e por pessoa. "Só os meus" casa o e-mail do usuário com o da Equipe.
- Alertas por gatilho no banco (atribuição e entrada em etapa com alerta), enviados pelos canais da Equipe; sino abre o cartão.
- Não coberto: etapas do funil de campanha (`funil_etapas`); mensagem padrão na ficha com copiar/WhatsApp; envio real de e-mail/WhatsApp depende de integração.

## Cohorts do RevOps (v0.21)
- Cohort feito sobre matrículas de alunos para ficar coerente com o painel do RevOps (mesma regra de "ativo"). Validado no banco com cenário sintético (retenção 100% → 100% → 50% conferida) e na interface com dados simulados.
- Em aberto: cohort baseado em leads/clientes sem matrícula; receita de contratos recorrentes entra só pelas parcelas recebidas; comparação lado a lado de duas coortes; exportar para planilha.

## Empresa, funções e permissões (v0.22)
- Permissão imposta no banco por políticas restritivas (RLS), em vez de só esconder o menu. Testado com papel `authenticated`: administrador vê tudo; função restrita não vê lançamentos contábeis, não altera tabelas de módulos sem "editar" e não consegue se autopromover nem criar funções.
- A ferramenta de migração do banco recusou duas peças que concedem ou retiram acesso de usuários (`sincroniza_acesso` e `aceitar_convites`). Elas ficaram no arquivo `20261006380000_acessos_sincronizacao.sql`, para revisão e execução manual no SQL Editor. Até lá, a tela salva o cadastro e avisa que a liberação automática ainda não está instalada.
- Limitação: funções do banco que rodam com privilégio elevado (por exemplo registrar recebimento, estornar, importar) não conferem o módulo; a tela esconde os botões e as tabelas continuam protegidas, mas um usuário técnico poderia chamar essas funções diretamente. Fechar isso função a função é a próxima etapa.
- Em aberto: convites por e-mail; "fechamento de período" que bloqueie lançamentos (o cadastro só informa o período); permissões por tela dentro de um módulo; log de quem alterou acessos.
## Planejado (ainda não construído)
- Integração de conversas: quem falar no Instagram ou WhatsApp cai no CRM com a origem (precisa de ferramenta de automação/API oficial).
- Agente de resposta automática ao novo contato (fase posterior).

| Ascensão da escada (RevOps) | `revops_ascensao` + tela | Pronto (v0.23) | banco + tela | Testado com dados fictícios do Demo |
| Histórico de responsáveis e vendedor | `responsavel_historico`, triggers | Pronto (v0.23) | banco + ficha | Login com dados reais nunca testado |

| Permissões por ação e por pessoa | `pode()`, `funcoes.acoes`, `equipe.acoes_ind` | Pronto (v0.24) | banco + tela | Testado com usuário simulado no banco: lead criado, cliente bloqueado |
| Rateio de custos e CAC por centro | `v_custos_rateados`, tela Rateio de custos | Pronto (v0.24) | banco + tela | Login com dados reais nunca testado |

## Cadastro rápido nos formulários (v0.25)
Campos de seleção com `novo: '<cadastro>'` (ou `data-novo` em HTML manual) ganham a opção "＋ Cadastrar novo…". Usa os mesmos campos do módulo de cadastros (`ENT`), segundo modal em `#modalRoot2`. Testado com banco simulado (conta a pagar → fornecedor). Também cobre conta contábil, pessoa, equipe e campanha (formulário mínimo em `QX`; sem acesso ao sistema para equipe, sem metas para campanha).

## Contas a receber por período (v0.26)
Filtro de período em Vendas e contas a receber; KPIs, lista de vendas e parcelas de contratos respeitam o período (data de referência: vencimento, ou data do recebimento se já recebido). Função `receber_periodo` devolve a receber, atraso, recebido, MRR/ARR, provisionamento por mês e por cliente. Testado no banco com o workspace Demo (sem contratos, MRR 0) e na tela com banco simulado.

## Período em pagar, dashboard e painel (v0.27)
Seletor único (`perGet/perHtml/perLigar`) guardado em `S.per`. RPCs: `pagar_periodo`, `fin_dashboard_periodo`, `painel_gerencial` (caixa.a_receber/a_pagar só até o fim da janela; `atraso_receber`/`atraso_pagar`). Testado no banco (Demo sem contas a pagar) e na tela com banco simulado. Limite: a curva de caixa projetado continua fixa em 30 dias.

## Leads de marketing, onboarding e histórico (v0.28)
`pessoas.captada` filtra funil_analise, funil_cohorts, funil_membros e growth_metricas_auto (as views por campanha/UTM já ignoravam quem não tem campanha). `ativar_contrato` cria o aluno (contrato_id, origem 'contrato'); `alunos.venda_id` passou a aceitar nulo. `cadastrar_cliente_historico` cria pessoa (data real), aluno e pagamento histórico. Testado no banco (rollback): leads 0, aluno do contrato criado, cadastro histórico sem movimentação de banco nem conta a receber.

## Módulo financeiro opcional e custos do CAC (v0.29)
`S.modoFin` é lido em `carregaPerm`; `telaOculta()` filtra o menu (SO_COMPLETO/SO_SIMPLES) e redireciona telas ocultas. Painel gerencial troca os blocos de DRE/fluxo/saldo por uma nota. Tela `vCustosCac`; bloco de configuração em `vEmpresa` chama `definir_modo_financeiro`. Teste de banco: dois custos (mídia 1.000, equipe 500) viraram CAC total 1.500 / mídia 1.000 em `painel_gerencial`, sem gravar nada. Teste de tela (Playwright com mock): menu, redirecionamento, painel, lançar custo, troca de modo nos dois sentidos. Testes anteriores seguem passando.

## Uso da plataforma (v0.30)
Objeto `UT` no front: buffer de eventos, envio a cada 20 s, ao esconder a aba e ao sair; ganchos em `render()` (abertura), `modal()` (abre/salva/cancela) e `act()` (erro). Falha de envio ou tabela ausente desliga o rastreio sem avisar o usuário. Tela `vUso` (cfg-uso, só administrador). Teste com navegador simulado: eventos, mascaramento e tela. **Não testado no banco real** porque a migração foi recusada pela ferramenta.

## Fornecedores, formas de pagamento e provisão (v0.32)
`ENT.fornecedores` com padrões (só aparecem se a migração estiver rodada), `ENT.formaspag` (tela Cadastros → Formas de pagamento), `provisionaAuto()` (uma vez por dia por workspace, silenciosa) em Contas a pagar, Dashboard financeiro e Painel gerencial, botão "Gerar provisões agora", modal "Confirmar valor", preenchimento automático ao escolher fornecedor, conta bancária sugerida pela forma de pagamento. Teste com navegador simulado, com e sem a migração (sem ela, a tela segue funcionando como antes). SQL **não** testado no banco real.

## Parcelamento (v0.33)
`parcelar()` e `somaMes()` no front; `abrirForm` aceita lista de linhas no insert (uma única requisição, tudo ou nada). Contas parceladas ficam ligadas só pelo texto "(n/total)" na descrição. Teste: 3x de R$ 100 (33,33 + 33,33 + 33,34), 4x de R$ 250 começando em 31/12 (28/02 no mês curto) e à vista.

## Contas recorrentes (v0.34)
`ENT.fornecedores` com a seção "Como esta conta se repete" (`ENT.recorrentes` ficou no código mas sem entrada no menu), `abrirForm` ganhou `depois` (roda a provisão logo após salvar), `provisionaAuto` chama também `provisionar_recorrencias`. Contas geradas por recorrência não usam a marca `provisionada` (o índice antigo impedia duas recorrências do mesmo fornecedor no mês); a unicidade vem de `recorrencia_id + competência`. Testado no banco em transação desfeita (fixa com dia 31, variável com data final, parcelada 3x de 100 = 33,33/33,33/33,34, segunda chamada não duplica).

## Metas mensais da campanha recorrente (v0.35)
Aba `metas` em `vCampanha` (só aparece no modelo recorrente) → `tcMetas`; dados de `campanha_metas_mensal` (RPC) + `campanha_mix`. Ajuste por mês faz upsert em `campanha_metas_mes` (vazio nos dois campos apaga o ajuste). Teste: navegador simulado (aba, KPIs, ajuste, duplicidade no mix) e banco em transação desfeita (mix 10+3, mês ajustado 500 leads/26 vendas → mix escalado 20+6).

## Baixa parcial (v0.36)
`modalPagarConta(cid)` (único modal de pagamento, usado por Contas a pagar, fluxo e painel) e `modalBaixaParcela(id, conta, valor)` chamam `registrar_pagamento_parcial` / `registrar_recebimento_parcial` quando o valor é menor que o total. Divisão contábil por estorno parcial proporcional (arredondamento acumulado por partida, fechando exato) mais novo lançamento do saldo. Testes no banco: contas a pagar (3 baixas, despesa 1.000,01 lançada uma vez, banco 1.000,01, a pagar zerado) e parcela de contrato real da Mathisa em transação desfeita.

## Códigos automáticos (v0.37)
`proxCodigoNum(tabela)`, `proxCodigoConta(paiId)` e `slugCod()` perto de `ENT`; ganchos `antes` em `ENT.canais`, `ENT.centros`, `ENT.planocontas`, `ENT.produtos` e no formulário de canal da campanha. O cadastro rápido (+ Cadastrar novo…) usa os mesmos ganchos. Teste com navegador simulado: canal 004 (com 001, 003 e google_ads), centro 008, conta 6.3.07, conta de primeiro nível, tag repetida, código digitado preservado.

## Status de contrato e produto rápido (v0.38)
`CT_ROT`/`pillCt` rotulam os status; botões `data-ca` (assinar), `data-cv` (voltar para pendente → RPC `reabrir_contrato`), `data-ce`, `data-cc`. Seletores `.itp` do modal de contrato usam `ligarNovo` e a opção `__novo__`; `recCt` ignora parcelas canceladas. Testes: Playwright com cliente simulado (rótulos, botões, chamada da RPC, opção de cadastro nas linhas). Login real no Supabase não foi testado.

## Parcelas personalizadas (v0.39)
No `modalContrato`: caixa `#ctPlanoBox`, funções `lerPlano/desenhaPlano/planoSoma`; ao salvar apaga e regrava `contrato_parcelas_plano` e valida contagem e soma. `ativar_contrato` lê o plano quando existe. Testado no navegador com cliente simulado e no banco (3 parcelas 1.500/900/600 em datas distintas; soma errada barrada, com dados desfeitos). Login real não testado.

## Alerta de contrato vencendo (v0.40)
`ctDias/ctVenc/pillVenc/painelVenc` perto de `CT_ROT`; usados em `vContratos` (pílula, painel, filtro `vencendo`) e `vCrmDash` (consulta própria de contratos ativos com data de fim). Testado no navegador com cliente simulado. Login real não testado.

## Indicadores do mês em Contratos (v0.41)
Em `vContratos`: `totAtivos`, `doMes`, `abertoMes` a partir de `contas_receber` filtrado por vencimento no mês; KPIs na linha `.kpis`. Testado no navegador com cliente simulado (500 previsto + 300 recebido no mês, cancelada ignorada → total 800, falta 500). Login real não testado.

## Oportunidades e renovação (v0.42)
`vCrmOport` (view `crm-oport`), `modalOport`, `etapasOport` (cria etapas padrão se vazio), `renovarContrato`, `negociarRenovacao`; `modalContrato` aceita `pre.itens`, `pre.base` e `pre.renovacao`. Reaproveita `quadro()`/`ligaArrastar` (tabela `oportunidades`). Botões `data-cr`/`data-cn` na lista e no painel de vencendo. Ficha do cliente lista as oportunidades. Testes: Playwright com cliente simulado; no banco, inserção e ganho como usuário autenticado (desfeitos). Login real não testado.

## Desfazer pagamento e reativar conta (v0.43)
Botões `data-dp` (pagas) e `data-ra` (canceladas sem substituida_por) em `vPagar`, chamando as RPCs `desfazer_pagamento` e `reativar_conta_pagar`. Testado no banco com os dados reais da Mathisa primeiro em transação desfeita (banco +1.800, razão equilibrado) e depois aplicado; e na tela com cliente simulado. Login real não testado.

## Telas Vendas e Contas a receber (v0.44)
`vVendas` (view `crm-vendas`, período próprio `S.vp`) e `vReceber` (view `fin-receber`, lista única de `contas_receber` com embed de contratos e vendas, `S.rf`). Botões `data-cp`, `data-dr`, `data-rp` chamam as três RPCs novas. Testado com Playwright (cliente simulado) e no banco em transação desfeita. Login real não testado.

## Painel de metas no Dashboard de Vendas (v0.45)
`painelMetasVendas(MP)` usado em `vCrmDash` com a RPC `vendas_metas_painel`; botões de atalho Funil de leads ↔ Oportunidades. Testado com Playwright (cliente simulado: lançamento atrás do ritmo, recorrente no ritmo) e a função no banco com dados reais. Login real não testado.

## Período padrão (v0.46)
`perGet()` passa a iniciar em 'pers' com de = dia 1 do mês e ate = hoje+30. Correção de dados do contrato #10 feita com `desfazer_recebimento` (data 2026-10-06). Login real não testado.

## Pró-labore com passivo próprio (v0.47)
Campo `plano_contas.conta_passivo_id` (select no Plano de contas, só contas 2.x). Gatilho `contas_pagar_depois`, `registrar_pagamento`, `cancelar_conta_pagar` e `cancelar_parcela_contrato` atualizados (ver migração-nota 20261006600000). Reclassificação dos dados do Rogério feita em transação testada antes. Login real não testado.

## Período nos Lançamentos contábeis (v0.47)
`vLanc` usa `S.lf.pre` (mes, ant, 30, 90, ano, tudo, pers) e filtra `data_fato` no banco (gte/lte, limite 2000). Padrão: mês corrente. `perHtml/perLigar` ganharam "Mês passado". Login real não testado.

## Growth Model automático (v0.49)
Aba "Modelo por loop" dentro do Growth Model (`vGmLoop`, `glCalc`, `glInstancias`, `glDesenha`, `glModalTodos`), ligada à função `growth_modelo_historico`. Função e tabela testadas no banco (Mathisa: 13 linhas de contratos e orgânico; Demo: 29 linhas, com campanha, upgrade e recompra). Tela testada com dados simulados. Login real não testado.

## Demo 2 e provisionamento do pró-labore (v0.50)
`provisionar_workspace` agora chama `_provisionar_prolabore`, que cria 2.1.03, 3.1.02 e 6.2.04 (com `conta_passivo_id` = 2.1.03) se ainda não existirem. Login real não testado.

## Plano de contas por cliente (v0.51)
Telas: importação (arquivo ou texto, conferência por grupo, prévia), mapeamento das contas do sistema e download em CSV. Excel lido com SheetJS 0.18.5 carregado sob demanda. Testado só com dados simulados; a função do banco ainda precisa ser instalada.

## Planejamento anual de campanhas (v0.52)
Função `planCamp` dentro da aba Planejamento anual: linha do tempo em grade de 12 meses, KPIs, tabela e distribuição mensal. `formCampanha` aceita valores iniciais (status, modelo, início). Sem migração. Testado só com dados simulados.

## Regras contábeis personalizadas (v0.53)
Tela de regras ganhou Nova regra, Lançar e Excluir (só personalizadas). Lançar usa `registrar_lancamento_manual` com as contas da regra. Migração 20261007140000 aplicada. Testado na tela com dados simulados e a restrição testada no banco com reversão.

## Visual base: tema escuro carmim (v0.54)
Paleta nas variáveis `:root` (fundo #0c090d, superfície #151016, destaque #e5365f, vinho #3a1424), fonte Inter, raio 14px. Tema claro em `[data-theme="light"]`. Cores fixas claras de avisos viraram `var(--info-soft)`, `var(--warn-soft)`, `var(--bad-soft)`, `var(--good-soft)`. Mapas de calor em carmim.

## Importador, Growth Starter e dashboard (v0.55)
Módulos no index.html: `IMP_ALVOS` (catálogo de campos por tipo) e funções imp* (leitura, auto-mapa, validação, execução em lotes de 50 com retorno linha a linha em caso de erro); `dgDados`/`vDashGrowth`/`vRelatorios`; grupo de menu Growth Starter (flat) filtrado por `ehStarter()`. Testado só com dados simulados; as inserções de cada tipo foram conferidas no banco com reversão.

## Menu de Configurações em grupos e correção das funções (v0.56)
NAV: o grupo Configurações passou a ter `subs` (lista de subgrupos com `mod`, o módulo de permissão). Helpers `subsDe`, `itensDe`, `modSub`, `abreMenu`. Causa do erro das funções sugeridas: inserção em lote com chaves diferentes (o cliente de API preenche as ausentes com NULL e as colunas administrador e acoes não aceitam NULL). Regra daqui para a frente: inserção em lote com as mesmas chaves em todas as linhas.

## Dashboard com canais mês a mês e detalhes (v0.57)
Bloco do dashboard reescrito: `dgDados` traz `canalMes` (12 meses por canal), `canalNome`, `asc` (revops_ascensao). Funções `dgCanais`, `dgLinhas`, `dgSerieCanal`, `dgAscensao`, `dgDetalhe` (S.dd e S.dd2 guardam o detalhe aberto). Seletor de workspace controlado por `S.interno` (RPC sou_equipe_interna).

## Dashboard personalizável (v0.58)
`DG_KPIS` e `DG_BLOCOS` listam o que existe; `dgLayout()` lê o layout salvo (padrão se não houver); `dgLigaEdicao` trata arrastar (HTML5 drag and drop), ocultar, adicionar, restaurar e salvar (upsert em dashboard_layouts). Em `vDashGrowth`, `K` e `B` guardam o HTML de cada indicador e bloco; `env()` embrulha cada um.

## Dashboard de mídia (v0.59)
Tela `mkt-midia` (`vMidia`). Auxiliares: `mdAgg` (agregação), `mdRun` (gráfico por dia), `mdMatriz` (fadiga), `mdRelatorio` (agrupa por canal, campanha, anúncio ou ângulo), `MD_COLS` e `MD_COR`. Estado em `S.md`. O CSV e o Excel saem do mesmo vetor de linhas do relatório na tela.

## Pergunte aos dados (v0.60)
Tela `ia-perguntar` (`vPerguntar`, `iaChama`). A tela chama a função `perguntar`, que: valida a pergunta; checa as chaves; limita 40 por hora; chama `ia_contexto` com o JWT da pessoa; monta a mensagem (`montaMensagem`) com as regras (`REGRAS`); chama Claude ou ChatGPT com temperatura 0; lê o JSON (`leResposta`); confere os números (`confere`); registra em ia_perguntas e devolve resposta, avisos e o contexto. A lógica pura está em `logica.ts` e foi testada em Node.

## Dashboard inicial (v0.61)
View inicial `S.view = 'adm-painel'` (vPainel, rótulo Dashboard). `adm-dash` (vDashGrowth) segue no menu como Dashboard Growth. CSS `.kpi .v` com `clamp(15px,1.2vw,19px)`.

## Fila de importação com identificação (v0.62)
`IMP_SIG` (palavras-chave por tipo), `impDetecta` (pontua colunas e nome do arquivo), `impAvalia` (identifica ou usa o tipo escolhido e roda `impValida`), `impFilaDesenha` (tela), `impAbre` (leva o arquivo ao de-para existente), `impPosImporta` (marca importado e reavalia a fila). Estado em `IMPQ`; `IMPST.q` liga o de-para ao item da fila.

## Período, comparação e campos personalizados (v0.63)
`dgMeses` monta cur/prev conforme S.dp, S.dc e os meses escolhidos; `dgControles`/`dgLigaControles` são compartilhados entre Dashboard Growth e Relatório; `dgDeltaG` recebe o rótulo da comparação. Removidos o modo Personalizar e `dgLayout` (agora devolve o padrão). Importador: `impAlvoCompleto` soma os campos personalizados ao alvo; `montaLinha` move chaves `x:` para `extras`; `impNovoCampo` cria o campo e liga a coluna. Cadastro de pessoa lê e grava `extras` com mesclagem. Testes: simulação em navegador (rich66/rich67) e regressões anteriores sem erros. Login real no Supabase nunca foi testado.

## Contratos na tela de Vendas (v0.64)
`vVendas` mescla contratos ativos/encerrados (data de ativação, valor = parcelas não canceladas nem substituídas) à lista e aos totais. `vendas_dashboard` ganhou union de contratos no CTE `ven`. Não grava em `vendas`.

## Calculadora e ofertas (v0.65)
`ccEdita` (propaga edições), `ccSaida` (todas as contas), `vCalcCampanha` (tela, atualiza sem redesenhar o campo em edição), `ofertasProduto` (painel em Produtos), `tcOfertas` (aba da campanha). Testado: contas conferidas no node e fluxo na tela com banco simulado.

## Alertas e benchmarks (v0.66)
`vGrowthModelo` (mapa) busca 4 períodos via `calcAuto` e `benchmarks_mercado`; `pior()` compara por regra fixa; `modalBenchmarks` grava com upsert (workspace_id, metrica). Testado com banco simulado (2 alertas esperados, ticket sem alerta).

## Fornecedor e total de contas a pagar (v0.67)
Formulário de fornecedor sem seção de recorrência (`antes` só zera `provisionar`; dados antigos de recorrência não são tocados). Total da lista de contas a pagar usa só status diferente de cancelado.

## Desconto em parcela (v0.68)
`dar_desconto_parcela(parcela, valor, motivo, data)`: SECURITY DEFINER, só parcela de contrato prevista; D 5.1.03 / C conta de contas a receber do lançamento original; desconto total vira status cancelado com desconto > 0. `reativar_parcela_contrato` recusa parcela com desconto. Testado em transação desfeita e na tela com banco simulado.

## Pacote Lovable (v0.69)
`lovable/growth-model/`: extração literal de glMonta/glCalc, ccEdita/ccSaida e das regras de alerta. Conferido em node: calculadora (ticket 500, conv 10%, CPL 10, 1.000 leads → 100 vendas, R$ 50.000, CAC 100, ROAS 5), motor de loops e alertas.

## Calculadora: valores guardados (v0.70)
`C.pend` guarda campos ligados digitados sem base; `ccAplicaPend` tenta aplicá-los a cada edição da base (vale o último dígito). Lógica de `ccEdita`/`ccSaida` não mudou, então o pacote do Lovable continua igual.

## Origem da melhoria na receita (v0.71)
`impactoPainel` em `glDesenha`: aplica cada alavanca do cenário sozinha sobre o baseline com `glCalc` e compara a receita; a diferença para o ganho total é o efeito combinado. Conferido em mock: soma das partes + combinado = ganho total.

## Importador da planilha do Growth Model (v0.72)
`glImportar` (front-end): `giLeitura` percorre a aba (força o intervalo a começar em A1), separa blocos `Loop N` e premissas; `giSugere` sugere a alavanca pelo nome da linha, só entre as alavancas que o loop de destino tem. Grava com `glSalva` em `gm_alavancas` (base e sim). Percentual em fração; valor > 1 com unidade % é dividido por 100. Conferido em mock com `growth_model_info-_v2.xlsx`: 34 valores gravados, CPM/CTR/connect/conversões/ticket nas alavancas certas.

## Máscara de moeda (v0.73)
`mascaraMoeda` no front-end: um observador converte `input[type=number]` que são dinheiro (rótulo com "(R$)", nomes conhecidos como valor/preco/orcamento, ou `data-money`) em texto com máscara `R$ 1.234,56`. A propriedade `value` do campo continua devolvendo o número puro; o `modal` troca o valor de tela pelo número puro ao montar os dados do formulário. Mínimo e máximo viram `setCustomValidity`. Para forçar ou impedir a máscara em um campo: `data-money="1"` ou `data-money="0"`.

## Growth Model refeito (v0.74)
Front-end, blocos `gx*` no `index.html`: `gxCabecalho`/`gxDetectaTipo`/`gxDetectaCampos` (leitura e detecção), `gxPrepara` (normaliza linhas e descobre canais, produtos e status), `gxCfgPadrao`, `gxConsolida` (classifica vendas, atribui canal, agrega por produto, loop e mês), `gxDiagnostico`, `gxLeEstruturado` (planilha no formato do Growth Model), `gxLinhas`/`gxValor`/`gxTotal`/`gxSumario` (modelo), telas `gxViewDados` e `gxViewModelo`. Banco: `gm_modelos(workspace_id unique, dados jsonb)`. Cada loop guarda só os passos e as séries mensais; as taxas são calculadas na exibição. Conferido: 11 execuções de teste com arquivos bagunçados (CSV com ; e títulos soltos, xlsx com linha solta e aba oculta, relatório de anúncios) e com a planilha estruturada.

## Menu e Growth Model a partir dos dados do sistema (v0.75)
Views: `gro-diag` (`gxViewDiag`, importar e diagnosticar) e `gro-modelo` (`gxViewModelo`). `gxMontaSis` monta o modelo a partir da RPC `growth_modelo_historico` (últimos 36 meses): um loop por campanha, recompra ou contrato, por produto; passos só com dado; papel pelo tipo (campanha = aquisição, recompra = renovação, upgrade). Loops manuais ficam em `gm_modelos.dados.manuais`. O modelo importado fica em `dados` com `base` diferente de `sistema`. A tabela é uma só, com CSS escopado em `.gxm`.


## Baseline e Cenário no Growth Model (v0.76)
Front-end: `gxCenario(L)` recalcula as séries aplicando as taxas de cenário (`L.cen`) em cadeia; `gxBaseVal`, `gxEditavel`. Colunas Baseline/Cenário em `gxViewModelo`; chave `E.modo` base|cen. Planilha estruturada: `gxLeEstruturado` guarda `b` e `c` por passo.


## Estratégias, etapas por campanha e jornada do lead (v0.77)
Front-end: bloco `/* ===== v0.77 — Estratégias` no `index.html` com `vFunis` (lista), `vEstrategia` (editor), `estNova`, `estModalEtapa`, `estTabelaEtapas`, `estLigaTabela`, `tcEtapas` (aba da campanha), `estAnexaFunil` (bloco no dashboard), `estCalcFunil`, `estFunilHtml` e `estToquesHtml` (ficha do lead). Constantes: `EST_CAT` (catálogo base) e `EST_MOD` (modelos prontos). Alterados: `formCampanha` (estratégia, produto e cópia das etapas no `depois`), `CAMP_TABS`, `vCampanha`, `modalVenda` (campanha e canal de fechamento), `fichaPessoa` e `gxSumario` (`upg`). Banco: `20261008220000_estrategias_jornada.sql`. Testes: simulador de banco com estado (filtros, gravação, RPCs) em Playwright, com 22 verificações, e regressões do Growth Model.

A versão aparece no rodapé do menu lateral (`#versaoApp`). Atualizar o texto a cada entrega.


## Cenário editável e projeção (v0.78)
`gxCenario(L, proj)` foi reescrito: as alavancas são o primeiro passo de volume (`gxPrimeiro`), os custos (`GX_CUSTO`: r_cpm, r_cpl, r_cac), as taxas e o ticket. A cadeia é recalculada mês a mês; com proj=true, os meses depois do último mês real são projetados, e a função `projetado(i)` marca esses meses. `gxNumBR` lê números em português. Em `gxViewModelo`: `dsB` (baseline projetado), `dsC` (cenário), produto padrão, `E.proj`, `#gxLimpa` e o CSS de `.gxc` e `.pj`.


## Topo de funil sempre presente (v0.79)
Em `gxMontaSis`, os loops de aquisição sempre levam os passos inv, imp, clk, vis e led. `gxInicio(L)` define onde a cadeia começa: o primeiro passo com cenário, senão o primeiro com dado maior que zero. O primeiro passo e o passo de início são editáveis no Cenário.


## Segurança fase 1 (v0.80)
Migração `20261008230000_seguranca_fase1.sql`: laço sobre todas as funções do schema public revoga EXECUTE de public/anon e regrava o EXECUTE de authenticated/service_role que já existia; `alter default privileges` fecha as próximas. As 32 RPCs são reescritas trocando `pode_operar(x)` por `pode_editar(x, '{módulos}'::text[])`; a migração para com erro se alguma função não tiver exatamente uma chamada (diferente do padrão antigo de `replace()`, que falhava em silêncio). `sincroniza_acesso`: checagem passa a ser `session_user in (postgres, supabase_admin) or service_role or (auth.uid() not null and eh_admin)`. Front: `moduloDaView` procura primeiro nos grupos que não são Growth Starter; a tela sem workspace não chama mais `provisionar_workspace`.


## Simulador de lucro e blocos (v0.81)
Motor: `gpsCalc(premissas, ajustes)` projeta mês a mês por coorte (mês de aquisição): canais geram clientes no produto de entrada, `propaga` segue a jornada (máx. 12 níveis, limite de compras por cliente, ciclo sem defasagem cortado), `registra` lança receita, reembolso, impostos, custos e caixa por produto e por coorte. Devolve indicadores, totais, mensal, produtos, canais, transições (ascensões necessárias via `gpsUnidade`), coorte e avisos. `gpsCenario` aplica os ajustes (ROAS fixo acha a escala de conversão), `gpsComparar`, `gpsSensibilidade` (±10% / ±2 p.p.), `gpsSnapshot`. Testes: `t_engine.js` (referência da seção 10 + T01–T14 + extras). Tela: `vSimulador` e `gpsTab*`/`gpsRes*`; campos ligados por `data-p` (caminho no JSON), números aceitam formato brasileiro (`gxNum`), faixa de indicadores recalcula com espera de 250 ms. Persistência `gpsLista/gpsCarrega/gpsGrava/gpsSnaps` com queda para localStorage. Blocos: catálogo `EST_BLOCOS`, `EST_MOD_BLOCOS`, `blkCria`, `blkQuadroHtml`, `blkLigaQuadro`, `blkModalNovo`, `blkModalAbrir`, `blkDoModelo`, `blkCopiaEstrategia`; `estCalcFunil` passa a calcular a taxa só entre principais; `estFunilHtml` agrupa por bloco. Testes no repositório: `tests/simulador_motor.test.js` (node, 60 verificações do motor, incluindo os defeitos achados na revisão independente) e `tests/tela/t81_blocos_simulador.py` (Playwright com banco simulado, 62 verificações de tela).


## Growth Model em abas (v0.82)
`gmAbas(m, aba, fn)` desenha a barra de abas e chama `vGrowthModelo` ou `vSimulador` num contêiner interno. `gro-lucro` saiu do NAV; `moduloDaView('gro-lucro')` devolve 'gro' e o menu marca Growth Model nas duas abas.


## Junção da baixa parcial (v0.83)
`desfazer_pagamento` estorna o pagamento (como antes) e, se houver conta com `saldo_de` = a conta desfeita, em aberto e não substituída, chama `cancelar_conta_pagar` nas duas (data = data_fato do lançamento de despesa de cada uma) e insere a conta única (o gatilho lança a despesa inteira); as duas ficam com `substituida_por` = nova. A nova herda `saldo_de` da conta desfeita, o que permite desfazer cadeias. Teste local em `tests/banco/`.


## Menu (v0.84)
`gro-lucro` voltou ao NAV como "Unit Economics"; `gro-modelo` se chama "Growth Loops" no menu. `gmAbas` continua desenhando as abas no topo.


## Pacotes de acesso (v0.85)
`carregaPerm` chama `carregaAcesso` (rpc acesso_workspace → `S.acesso`, Set de telas ou null). `telaLiberada(k)` filtra o menu (`desenhaNav`), a primeira tela e o bloqueio do `render`. Tela `vPacotes` (cfg-pacotes, só `S.interno`): pacotes com árvore de telas (`pacArvore`), clientes com seleção de pacote e ajuste por tela (Do pacote / Ligar / Desligar). Ao criar um cliente, o pacote escolhido é aplicado com `workspace_definir_acesso`. Novas telas do menu precisam entrar no catálogo `acesso_telas` (migração) para poderem ser liberadas.

## Cartão, extrato e projeto de campanha (v0.86)
Front: bloco `fin86` antes de `vFinDash` (`ehCartao`, `soContas`, `bancoLab`, `kpiClic`, `finExtrato`, `finLista`, `finCartoesHtml`, `finPagarFatura`, `finDashLigar`, `modalReceberAvulso`, `criaProjetoDeCampanha`). `vFinDash` marca os 3 KPIs com `data-fin` e chama `finDashLigar`. Selects de recebimento (`modalContrato`, `modalBaixaParcela`) usam `soContas`; `modalPagarConta` e Formas de pagamento mostram o cartão com `bancoLab`. Cadastro de contas detecta a coluna `tipo` antes de mostrar os campos novos (funciona sem a migração). `vReceber` trata `ehA` (avulsa). `modalProjeto` tem a caixa "Projeto de campanha"; `vProjetoDet` tem o botão "Atividades dos blocos". Integração: `integra86.py` aplica as trocas sobre a v0.85.
Banco: as trocas em `painel_gerencial`, `registrar_recebimento` e `registrar_recebimento_parcial` são feitas sobre a definição atual (`pg_get_functiondef` + replace), com erro se o trecho esperado não existir.

## Módulo Casa (v0.87)
`S.wsBase` = workspace escolhido no seletor; `S.ws` passa a ser decidido no `render`: tela `casa-*` usa o workspace da Casa (`casaDe(S.wsBase)`), as outras usam `S.wsBase`. `CASA_MAP` liga cada tela `casa-*` à tela do financeiro/cadastro que ela reaproveita; `rotaCtx` mantém os atalhos dentro da Casa. Permissões e pacote do menu continuam os da operação (não recarrega `minhas_permissoes` na Casa); o banco checa a Casa pelos membros dela. `boot` tira do seletor os workspaces com `casa_de` (guardados em `S.casas`). `casaFaixa`, `casaTransfPainel`, `modalTransfCasa` em `casa87`. Integração: `integra87.py` (roda a `integra86.py` e aplica as trocas da v0.87).

## Fase 1 — confiança do dado (v0.88)
Front: bloco `fase1` antes de `vFinDash` (`normFone`, `traduzErro` usado em `q()`, `qualidadeFaixa`, `dicNosCartoes`, `depoisDaTela88` chamado no `render` depois de cada tela, `vQualidade`, `vMetricas`, `vAuditoria`, `vDuplicados`). `finExtrato` usa `extrato_conta` e calcula na tela só sem a migração. `fecharCampanha` usa `campanha_fechar` (pede motivo quando já há oficial); `tcFechamento` lista as versões. Importação de pessoas deduplica também por telefone. Integração: `integra88.py` (roda a integra87 e aplica as trocas).

## Fase 2 — captação e vendas (v0.89)
Front: bloco `fase2` antes de `vFinDash` (`temColuna`, `vendasPorCanalHtml/Painel`, `tcCaptacao` = aba "Captação e metas" da campanha, `vAbandonos`). O `render` chama `vendasPorCanalPainel` no dashboard de vendas. A aba de ofertas ganhou a coluna Aceite; o formulário do canal da campanha ganhou Público (só aparece com a migração). Integração: `integra89.py` (roda a integra88 e aplica as trocas).

## Projetos e meta de CPL (v0.90)
Front: bloco `projetos90` antes de `vFinDash` (`parseTags`, `tagsHtml`, `atvPassa` + `filtroAtvHtml`, `vTodasAtividades`, `projetoPainel` com `linhas`, `modalSalvarModelo`, `vincularCampanha`, `modalCampanhaDoProjeto`, `modalProjetoCampanha`). `modalProjeto` reordenado (datas em destaque, tags, campanha vinculada); `vProjetoDet` com painel, filtros e botões novos; `modalAtividade` com tags; botão Projeto da campanha sempre visível; meta de CPL nos formulários e no quadro de canais. Integração: `integra90.py`.

## Projeto automático opcional (v0.91)
`formCampanha` mostra, só na campanha nova e só com a migração, os campos `projeto_auto` (caixa) e `projeto_modelo_id` (modelo). Integração: `integra91.py` (roda a integra90).

## Dashboard principal clicável (v0.92)
`vPainel` usa `kpiClic` em Saldo em banco (`extrato`), A receber e A pagar (com o período de hoje até o fim da previsão, via `data-de`/`data-ate`) e chama `finDashLigar(m)` no fim. `kpiClic` ganhou o 4º parâmetro (período) e `finLista(tipo, per)` aceita o período no lugar do do Financeiro. Integração: `integra92.py` (roda a integra91). Conferência em produção antes de gerar o arquivo único: os trechos usados pelos `replace` dinâmicos (sincroniza_acesso, campanha_funil_etapas, nivel_modulo, painel_gerencial, registrar_recebimento) existem, e as 32 funções com `pode_operar` estão todas no mapa da v0.80 com uma chamada cada.

## Custo operacional (v0.93)
`coDados(meses)` lê recorrentes, contas a pagar (sem canceladas) e a receber; agrupa por chave: `r:<recorrência>` (pela recorrencia_id ou pelo nome-base igual ao da recorrência, tirando " (saldo)" e " — mm/aaaa", o que junta pagamentos parciais), `p:<fornecedor>|<nome>` para "(n/m)" e `a:<id>` para avulsas; recorrência ativa sem conta no mês entra pelo valor da regra. `coEquilibrio` calcula a receita: MEI = (C + DAS) ÷ (1 − var − margem); manual = C ÷ (1 − alíquota − var − margem); Simples por iteração com RBT12 = 12 × receita, alíquota efetiva = (RBT12 × nominal − dedução) ÷ RBT12 (tabelas dos anexos III e V da LC 123) e fator R = (pró-labores × 12) ÷ RBT12 (≥ 28% → III). Pró-labore reconhecido pelo nome da conta. `gpsPuxarCustos(D)` alimenta `D.fixos` do simulador. Integração: `integra93.py` (roda a integra92). Correções de dados feitas por `cancelar_conta_pagar` + novo `insert` com a conta/centro certos (substituida_por aponta para a nova).

## Margens e meta (v0.94)
`coMargens(dm, aliqVar, varPct)` reparte a receita do mês por produto (contas a receber → `contrato_itens` proporcional ao valor × quantidade; venda → `vendas.produto_id`) e conta clientes distintos por produto. Imposto variável: MEI 0 (DAS fixo somado aos custos fixos), manual = alíquota, Simples = alíquota efetiva da faixa com RBT12 = 12 × receita do mês e anexo pelo fator R. `coMetaLer`/`coMetaSalvar` usam o plano vigente (ativo) e o indicador com chave `margem_lucro` (ou nome "Margem de lucro…"); sem objetivo no plano, cria "Operar com margem de lucro saudável"; insere com chave e, se a migração não rodou, sem chave. Trava contra gravação dupla. O ponto de equilíbrio usa % variável efetivo = taxas da venda + custo dos produtos ÷ receita. Integração: `integra94.py` (roda a integra93).

## Cenários da margem (v0.95)
`coMetaLer` devolve `meta`, `ruim` e `otimo`; `coMetaSalvar(M, {ruim, bom, otimo})` grava `valor_meta` e, se `temColuna('plano_indicadores','faixa_ruim')`, as faixas; senão ruim e ótimo vão para o `localStorage` ("custoOp:<ws>"). Validação na tela: 0 ≤ valor < 100 e ruim < bom < ótimo. Classificação: ≥ ótimo → Ótimo; ≥ bom → Bom; ≥ ruim → Ruim; abaixo → Abaixo do ruim. A receita de cada cenário usa `coEquilibrio` com a margem do cenário. Planejamento: `plCarregar` liga `S.plFaixa` e `modalInd` mostra os campos. Integração: `integra95.py` (roda a integra94).

## Meta de retirada (v0.96)
`gpsTabRetirada(el, G)` (aba `retirada` em `GPS_TABS`) usa `coDados` (Custos e margens) para os custos do mês sem os itens de pró-labore (`coEhProlabore`) e sem os desmarcados (`coPref().fora`), e `coEquilibrio` com C = custos + ajuste + retirada, folha = retirada (fator R) e a margem de cada cenário. Retirada possível = receita do mês × (1 − alíquota efetiva − variáveis − margem) − custos − DAS (MEI). Sócios iniciais = itens de pró-labore do mês. Integração: `integra96.py` (roda a integra95).

## Growth Now fase A (v0.97)
Módulo `fasea97.js` (integrado por `integra97.py`, que roda a integra96): `ofertasProduto` (catálogo novo, formulário com itens do pacote, `oferta_salvar`; sem a migração grava como antes), `tcOfertas` (esteira em árvore, formulário com etapa anterior/condição/premissas, `ofEsteiraSim` para a simulação), `campExecCampos`/`campExecValida` (execução por canal) e `campEstrategiasPainel`. As versões antigas ficaram como `ofertasProdutoV65` e `tcOfertasV65` (não usadas). Calculadora: `receita` só leitura e fora de `CC_LIG_K`. North Star: campos no `modalMetricaG` só com a coluna no banco (`_colCache`).

## Growth Now fase B (v0.98)
Módulo `gmb98.js` (integrado por `integra98.py`): `glCabecalho`/`glNumeros`/`glFinanceiro` (cabeçalho duplo; custos fixos de `coDados` sem contas 6.1 e sem os desmarcados; imposto pelo regime como em Custos e margens), `glBarraCenarios`, `glCustosCenario`, `glComparador`, `glGrava` (cenário com pilha de desfazer; baseline via RPC com motivo), `glDesfaz`, `glHistorico` (auditoria), `glCenForm`, `glLigaCenarios`, `glGuardaResultados` (grava baseline/resultados no cenário em rascunho quando o contexto bate). O motor `glCalc` lê `ov[alavanca][cenario|mes]` para qualquer id de cenário. `glInstancias(true)` monta o consolidado sem filtros; ajustes feitos com filtro de produto valem para os loops daquele produto. Unit Economics: `gpsLista/gpsCarrega/gpsGrava` usam `gm_cenarios` quando a tabela existe (`S.gpsGm`), com `S.gmCen` compartilhado.

## Growth Now fase C (v0.99)
Módulo `decisao99.js` (integrado por `integra99.py`): `glBotoesDecisao`/`glLigaDecisao` na barra de cenários, `glModalIce`, `glModalAprovar` (monta o documento com `G.ultCab`, `glInputsCenario` — valor do baseline via `glCalc(...).lev` — e `grProjetados` quando existir), `glVerDocumento`/`glDocHtml` (impressão em janela nova), `ETAPAS_G7`/`etapasG`/`etapasMover` (7 colunas só com a coluna nova no banco; sem ela, as 5 antigas), `expCamposExtra` e `expBotoes` no modal do experimento.

## Growth Now fase D (v0.100)
Módulo `guard100.js` (integrado por `integra100.py`, que roda a integra99 → … → integra86): `GR_MET` (métricas e unidades; margem/lucro só projeção), `grValorProj` (do cabeçalho financeiro), `grValorReal` (de `growth_metricas_auto` via `calcAuto`), `grSituacao` (fora do limite; perto = 10% de folga), `grProjetados`/`grPainelProjetado`/`grResumoCol` (Growth Model e comparador), `vGuardrails` (abas monitoramento, alertas, contínuo e cadastro; grava observações e alertas sem duplicar), `vResultados`. Telas `gro-guard` e `gro-result` no menu Growth e no catálogo de acesso.

## Correção da v0.86 no arquivo único (v0.100)
O patch dinâmico de `registrar_recebimento` usava `replace` com texto de várias linhas; trocado por `regexp_replace` com `\s+` (tolera \r\n e espaços). Era o único patch com busca de várias linhas no arquivo único (conferido por script).

## Abas do Growth Model (v0.101)
`vGrowthModelo` virou um invólucro com `GM_TABS` (loop, modelo, mapa, calc) e chama `vGrowthModeloCorpo`; aba padrão = `loop` (Cenários e simulação). `gxTabsBar` deixou de desenhar o chip "← Growth Model". Integração: `integra101.py`. Lição registrada: toda tela nova precisa de teste que comece pelo caminho do menu.

## Visual azul e modo claro/escuro (v0.102)
- `<html data-estilo="azul">`. Todo o CSS novo fica sob `:root[data-estilo="azul"]` (fim do `<style>` principal), então tirar o atributo volta ao visual vinho antigo. Modo claro = `data-theme="light"` no `<html>` (mesmo atributo que já existia), com variáveis próprias em `:root[data-estilo="azul"][data-theme="light"]`.
- Script no `<head>` aplica `data-theme` a partir de `localStorage.growths_tema` antes de desenhar (sem piscar). Botão `#temaBtn` no rodapé da barra: `trocaTema()` / `desenhaTemaBtn()`.
- Nova variável `--accent-rgb` (números R,G,B): todos os `rgba(229,54,95,…)` fixos viraram `rgba(var(--accent-rgb),…)`, inclusive os montados em JS (mapa de calor, funil, cohorts). `DG_CORES[0]` = `#3b82f6`.
- Movimento: pseudo-elemento `::after` nos itens do menu desliza de `translateX(-101%)` a 0; `.kpi::before` faz a borda em degradê (máscara); `body::before` com duas luzes radiais e animação `estDeriva` de 28 s. Tudo desligado com `prefers-reduced-motion`.
- Integração: `integra102.py` (CSS em `azul102.css`).

## Growth Model simplificado (v0.103)
- `vGrowthModelo`: aba padrão `simples` (sem barra de abas), que chama `vGmSimples`. As outras abas (`loop` agora "Cenários detalhados", `modelo`, `mapa`, `calc`) ganharam a aba "← Simulação" e são abertas por Mais opções.
- `vGmLoop(m, desenha)`: o carregamento (histórico, alavancas, campanhas, produtos, cenários, guardrails, financeiro) é o mesmo; a tela simples passa `gsDesenha`.
- Motor: `glCalc` dá o baseline (real nos meses passados, média nos futuros). `gsCen(R, ov, off, n)` aplica o cenário em todos os meses do período: etapa mudada substitui a taxa; etapa não mudada mantém a taxa do mês (escala pela etapa anterior); ticket mudado vale para todas as vendas; investimento escala proporcionalmente ao do baseline (ou é dividido igual se o baseline for zero).
- `glCalc.lev`: o valor do cenário com `mes = 1900-01-01` vale depois dos ajustes mês a mês do cenário e antes das premissas do baseline. Assim o modo detalhado mostra a mesma mudança nos meses projetados.
- Financeiro: `gsFinanceiro` (fixos sem 6.1 e sem o desmarcado em Custos e margens; CAC sem mídia = itens cuja conta tem `cac_grupo` diferente de `midia`); `gsResultado` (imposto pelo regime das premissas, `varPct`, custo de entrega por produto via `produtos.extras.mc_custo_pct` / `mc_custo_cliente`, rateio pela receita). `coDados` passou a ler `plano_contas.cac_grupo` quando a coluna existe.
- Cenário: `gsCenParaEditar` usa o escolhido se estiver em rascunho; se não houver, cria "Simulação dd/mm/aaaa"; cenário aprovado não muda.
- Integração: `integra103.py` (módulo `simples103.js`).

## Ajuste do loop em qualquer filtro (v0.104)
- `glAlavDe(G, L)`: ajustes efetivos de um loop = linhas sem produto + linhas do produto (`G.prod` ou o produto do loop); a com produto vence. Usada em `gsOv`, nos `ovMap`/`ovP` da tela simples e do modo detalhado, no comparador (`ovMapC`) e na célula de entrada do modo detalhado.
- Gravação (tela simples, célula mês a mês e "Todos os meses"): grava `produto_id = null` e remove as versões por produto (`glPidsDe`).
- Integração: `integra104.py`.

## Retenção & Expansão (v0.105)
**Banco:**
- Uma regra única de compra válida (`revops_itens` → `revops_pedidos` → `revops_receitas`) alimenta todas as telas, em `20261012100000_revops_retencao.sql`.
- As agregações são feitas por junção (sem subconsulta por linha).
- As funções têm `set enable_nestloop = off` e `set jit = off`. As estimativas de funções e CTEs levavam a laços aninhados, e o custo inflado ligava o JIT (cerca de 0,9 s por consulta).
- Com 2.000 clientes e 4.400 compras: coortes 0,6 s, recompra 0,2 s, RFM 0,2 s.

**Tela** (módulo `retencao105.js`, integrado por `integra105.py`):
- `vRetencao` desenha o cabeçalho, os filtros e as visões salvas; cada aba fica em `rxCoortes`, `rxRecompra` e `rxRfm`.
- Investigação: `rxLista` (modal com lista, histórico e CSV). Gráficos: `rxLinhas` e `rxBarras` (SVG próprio, clicável por `data-rxsel`). Configuração do RFM: `rxCfgModal`.
- Menu: `ho-retencao` substitui `ho-cohort` e `ho-ascensao`. Os endereços antigos redirecionam (aba Coortes / Recompra), e `telaLiberada` aceita quem tinha as telas antigas até o catálogo ser atualizado.
- Cadastro de produto ganhou o campo Categoria (só grava se a coluna existir).

**Testes:**
- `tests/banco/retencao_*.sql`: 5 clientes com reembolso, compra no mesmo dia, contrato recorrente com parcela futura, contrato cancelado sem recebimento e coorte incompleta.
- `tests/tela/t105_retencao.py`: usa a saída real dessas funções (`t105_dados.json`) e entra pelo menu.

## Growth Model em formato de planilha (v0.106)
- Módulo `planilha106.js`, integrado por `integra106.py`. `vGmSimples` passa a desenhar com `gpDesenha` (o `gsDesenha` da v0.103 continua no código, sem uso).
- `gpCalcula(G, SC, cen)`: real e cenário de uma vez.
  - Loops: `glCalc` + `gsCen`. O preço do produto entra como ticket do loop quando o loop não tem ticket próprio.
  - Impostos: pelo regime de `gpPrem(G, cen)`.
  - Custo de entrega: por produto (`gpCusto`).
  - Custos fixos: com o ajuste do cenário. Resultados por produto em `prods`.
- `gpComparar`: calcula cada cenário marcado (até 3). Guardrails: `grProjetados` com `gpH(K)`. O ICE é gravado direto no cenário em rascunho. A aprovação reaproveita `glModalAprovar` com `G.ultCab = gpH(K)`.
- Edição:
  - etapas → `gm_alavancas` (todos os meses), como na v0.104;
  - preço, custo, regime, alíquota, taxas e fixos → `gm_cenarios.financeiro`.
  - A primeira mudança cria o cenário (`gsCenParaEditar`).

## Cenários: ciclo de vida e histórico (v0.107)
- Módulo `cenarios107.js`, integrado por `integra107.py` (que roda o `integra106`).
- `cnStatus(cenário, cards)`:
  - rascunho → em estudo;
  - arquivado sem aprovação → descartado;
  - aprovado → pelo card mais recente ligado ao cenário:
    - etapas até Preparação → aprovado;
    - Em teste ou Análise → ativo;
    - Concluída ou Arquivada → encerrado. Vira cancelado quando não há início e a decisão foi interromper, ou o card foi arquivado.
- `cnModalDescartar`: grava `status = 'arquivado'` + `descarte`. Usado na planilha (`#gpDesc`), no modo detalhado (`#glCenArq`) e na tela Cenários.
- `vGmCenarios`: rota `gro-cenarios`, aberta por `gmAbas` (abas Growth Model · Cenários · Unit Economics).
  - Lê os cenários, os cards ligados e os produtos.
  - Filtros ficam em `S.cn` (aba, busca, produto).
- Planilha: `cnCarregaExps(G)` busca os cards uma vez por carga de cenários; a lista do `#gsCen` mostra só os vivos (`cnVivo`). O cenário em estudo mexido guarda `resultados` e `baseline` com `glGuardaResultados`, para o lucro projetado do histórico.
- Kanban: campo `link_doc` no `modalExperimento` quando a coluna existe; `validaExp` completa com https://. Resultados e aprendizados mostra o link.
- Acesso: `telaLiberada('gro-cenarios')` vale para quem tem `gro-modelo`.
- Testes:
  - `tests/banco/cenarios_ciclo.sql`: descartar, reabrir, aprovado não descarta nem exclui, link sem http recusado;
  - `tests/tela/t107_cenarios.py`: 31 verificações.

## Growth reorganizado (v0.108)
- `integra108.py` roda o `integra107`.
- `NAV` do Growth: `gro-diag`, `gro-modelo`, `gro-pesq`, `gro-ciclo`, `gro-result`, `gro-guard`.
- Rotas `gro-lucro` e `gro-analise` redirecionam para `gro-modelo` com `gmAbas`.
- `gmAbas`: abas "Planilha" (`gro-modelo`) e "Cenários" (`gro-cenarios`). O menu marca `gro-modelo` quando a tela é `gro-cenarios`. `moduloDaView` trata `gro-lucro`, `gro-cenarios` e `gro-analise` como módulo `gro`.
- Campanha: o botão `#cfAbrir` saiu; o handler ficou condicional.
- Pacotes: `TELAS_FORA_DO_MENU` tira do catálogo mostrado as telas aposentadas ou que viraram aba.

## Ideias pelo ChatGPT (v0.109)
- Banco: `20261012300000_ideias_chatgpt.sql`. O hash usa o `sha256()` nativo do Postgres e a chave usa dois `gen_random_uuid()`, sem depender de extensão.
- Edge function `supabase/functions/ideias/index.ts`:
  - lê a chave de `Authorization: Bearer` ou `x-growths-chave`;
  - chama as funções do banco com a chave anônima do projeto;
  - aceita `{ideias: [...]}` com até 10 ideias.
  - Publicada pelo conector do Supabase com `verify_jwt = false`.
- Front: módulo `ideias109.js`, integrado por `integra109.py`.
  - `modalIdeiasIA()` gera e revoga chaves e mostra as instruções (`IA_INSTR`) e o esquema OpenAPI (`IA_SCHEMA()`, servidor `SB_URL/functions/v1`).
  - Botão `#cIA` no Kanban do conteúdo e selo "pela IA" no cartão com origem 'ia'.
- Testes:
  - banco: `ideias_cenarios.sql`;
  - edge: `tests/edge/`, com Deno e stub do supabase-js via psql;
  - tela: `t109_ideias_chatgpt.py`, 15 verificações.

## Auditoria de consistência (v0.110)
- `tests/auditoria/`:
  - `monta_banco.sh` + `supabase_stub.sql`: banco do zero com todas as migrações;
  - `aurora_seed.sql`: empresa fictícia criada pelos fluxos reais (vendas, estornos, contratos, contas pagas e anúncios);
  - `grants.sql` e `pgrst.conf`: PostgREST 12 local;
  - `front.py` e `jwt.py`: o `index.html` real com o endereço trocado, o login simulado por JWT e o relógio fixado;
  - `coleta.py`: abre cada tela em setembro/2026 e grava os KPIs;
  - `referencia.sql`: as consultas de referência.
- O `hoje()` do front é `const` e não pode ser trocado pelos testes: a auditoria fixa o relógio do navegador (`page.clock`). Os testes de tela antigos que faziam `window.hoje = ...` não estavam fixando a data.
- Sincronização com produção: `20261010235000_registrar_recebimento_parcial.sql` e `20261012400000_sincroniza_producao.sql` (funções `campanha_metas_mensal`, `vendas_metas_painel`, `provisionar_recorrencias`, `reabrir_contrato`, `papel_da_funcao` e a coluna `plano_contas.conta_passivo_id`).

## Consistência das métricas (v0.111)
- Front, em `sim/consist111.js` + `integra111.py`:
  - `coPremCarrega`/`coPremSalva`: premissas no Cadastro da empresa. `coPref` mescla o cadastro e ignora regime e % do navegador quando as colunas existem.
  - `coDre`, `coDreMes`, `coDreBloco`, `coDreHtml`: Custos e margens pela DRE.
  - `gpAliq`, `gpAjusteDre`: Growth Model. Nos meses fechados soma (DRE − conta pelas premissas) ao real e ao cenário.
- Erro corrigido: o Growth Model chamava `coDados` com 'AAAA-MM-01'. A consulta falhava, `G.fin` ficava nulo e os custos fixos ficavam zerados em produção.
- Sem a migração, `dre_resumo` não existe e as telas caem no cálculo antigo; os testes de tela com o banco simulado continuam nesse caminho.
- Verificação:
  - `coleta.py` refeito;
  - `consistencia.sql` + `t111_consistencia.py` no banco completo (seed Aurora);
  - bateria `tests/tela` completa;
  - antes de gerar o arquivo, as funções de produção foram conferidas: hash idêntico ao do repositório.

## Escola Aurora (v0.112)
- `supabase/seed/escola_aurora/`:
  - `sim.py`: simulação diária com semente fixa. O orçamento cresce em rampa (70% na 1ª semana), o algoritmo dá mais verba a quem tem CPL melhor, a frequência sobe com a idade do anúncio, o CTR cai com a frequência (fadiga), e a conexão e a conversão da página variam por canal e criativo.
  - `criativos.py`: 35 criativos em HTML renderizados com Playwright (estático, carrossel, reels/stories, vídeo 16:9, vertical e texto de pesquisa), com a prévia 16:9 em WebP.
  - `gen_sql.py`: junta `base.sql` (histórico, adaptado do seed da auditoria) e `lancamento.sql` num arquivo só.
- O lançamento é criado pelos caminhos da aplicação:
  - blocos copiados do catálogo `EST_BLOCOS` com as mesmas chaves (`trafego1_cliques`, `captura1_leads`…);
  - `campanha_aplicar_estrategia`;
  - pessoas novas pelo cadastro, e quem já existia por toque de `captura` (como `registrar_captura`);
  - participação e jornada pelos gatilhos.
- Verificação:
  - banco do zero + `prod_funcs.sql` (versões de produção);
  - conferência no fim do arquivo;
  - telas abertas no front real via PostgREST: campanha (Dashboard, Estratégia, Captação e metas, Mídia paga), Dashboard de tráfego, Dashboard de mídia e Painel, sem erro de JavaScript.

## Receber leads (v0.113)
- `campos.ts` transforma qualquer corpo numa lista de pares pergunta → resposta. Reconhece:
  - objetos aninhados (`respondent`, `answers`, `data`…);
  - `{name, values}` da Meta;
  - `{question:{question_title}, answer}` da Respondi.

  O tipo de cada campo sai do nome normalizado: sem acento, minúsculo, com `_`.
- Telefone em partes (`{ddd, numero}`) vira um texto só.
- Data sem fuso é tratada como horário de Brasília.
- `first_name` + `last_name` viram o nome.
- O lead é gravado pela mesma regra do cadastro: telefone primeiro, depois e-mail. Pessoa nova entra pelos gatilhos de sempre (`pessoas_antes_inserir`, toque de entrada, participação); quem já existia entra por toque de captura, como `registrar_captura`.
- Testes:
  - 10 de leitura (página, Respondi, Meta, precedência de UTM);
  - 11 com a função no ar contra o banco `escp`: form HTML, repetida, redirect 303, cabeçalho, campo-isca, sem contato, chave inválida, Meta sem token e verificação da Meta;
  - 12 de tela (`t113_leads.py`);
  - regressão: t111, t109 e t107 OK.
- Em produção: `lead_por_chave` testada como anon dentro de transação desfeita (nova + repetida na campanha da Escola Aurora). Daqui não dá para chamar o endereço da função, porque a rede desta máquina bloqueia o supabase.co.

## Meta de leads e gráficos da campanha (v0.114)
- Front (`meta114.js`):
  - `mlLinhas` é o gráfico de linhas compacto: um eixo só, 480×196, marca de hoje, dica por dia (`<title>`) e pontos coloridos pela meta;
  - `mlSerie` monta dia, acumulado, mês e ritmo para a campanha ou para um canal (a meta do canal segue a forma da meta da campanha, na proporção);
  - `mlPainel` desenha ritmo, por dia, acumulado, canais e mês dentro de `#mlGrid`;
  - `mlModalMetas` edita a meta de todos os canais de uma vez;
  - `mlFunilHtml` desenha o funil compacto;
  - `mlTaxaDiag` calcula as taxas das métricas de diagnóstico.
- `vMktDashCampanha`:
  - lê `campanha_meta_leads` antes dos KPIs;
  - os dois painéis grandes viraram a grade `.ml-grid` (`auto-fit`, mínimo de 430 px), e o gráfico de dois eixos virou dois.
- `estAnexaFunil` coloca o funil compacto na grade; `estFunilHtml` mostra a taxa das métricas de diagnóstico.
- Testes:
  - `t114_meta_leads.py`, com 21 verificações. No banco: janela da captação, meta diária, soma por dia e por canal, esperado, perpétuo e acesso. Na tela: painel, KPI, grade lado a lado, pontos dentro e fora, mês, funil, filtro por canal, salvar metas, perpétuo, sem erro de JavaScript e celular sem rolagem lateral;
  - regressão: t113, t111, t109 e t107 OK.
- Em produção: Escola Aurora, com a captação de 26 dias, 192,3 leads por dia e 3.027 leads, igual ao teste local.

## Detalhe dos indicadores da campanha (v0.115)
- Front (`det115.js`):
  - `cdLigaKpis` liga os cards pelo rótulo (mapa `CD_KPI`). É chamado em `vCampanha` depois de qualquer aba, por isso vale no Dashboard, em Planejamento e metas e em Captação e metas.
  - `cdAbrir(campanha, indicador)` monta a janela (até 1120 px) com os blocos de cada indicador. Reaproveita `mlLinhas`, `mlBarra` e `ml-row` da v0.114.
  - `cdBarras`: barras por canal contra a meta, com "menor é melhor" para CPL e CAC.
  - `cdTabela`: tabela por canal com total e linha clicável.
- Banco: tudo numa chamada. As séries por dia saem de uma agregação por canal e dia (`ag`), sem subconsulta por dia. A primeira compra de cada pessoa marca o cliente do dia (`clientes_dia`).
- Testes:
  - `t115_detalhe.py`, com 18 verificações. No banco: somas por canal = participações, novos, investimento = anúncios, séries batem com os totais, qualificação soma os leads, vendas e clientes do perpétuo, acesso. Na tela: 8 cards clicáveis, Leads, troca para Investimento, filtro por canal, cards em Captação, Vendas com produtos, ficha pela lista, sem erro nos 8 detalhes, celular sem rolagem lateral;
  - regressão: t114 OK.

## Árvore dos números (v0.116)
- **Banco**:
  - uma função por família: `_arv_razao`, `_arv_vendas`, `_arv_pessoas`, `_arv_participacoes`, `_arv_ads`, `_arv_clientes` e `_arv_caixa`;
  - os nós compostos (fórmulas) ficam em `arvore_no`;
  - `_arv_meses` monta a quebra por mês; `_arv_un` dá a unidade de cada parte da fórmula.
  - Tudo roda como dono, de 50 a 200 ms por nó.
- **Front** (`arv116.js`):
  - `arvMapa(tela)` liga o rótulo do card a um nó, com os filtros da tela (período, campanha, canal);
  - `arvLigaTela` marca os cards;
  - `arvAbrir`, `arvVai` e `arvDesenha` controlam o painel e a pilha da trilha. Cada nível fica guardado, então voltar não consulta o banco de novo;
  - o registro com pessoa abre `fichaPessoa` por cima do painel.
- **Testes**:
  - `t116_arvore.py`, com 80 verificações: cada card ligado de 8 telas (fa) e de 3 abas da campanha (escp) confere com a raiz da árvore. Também cobre os níveis Lucro › Despesas › conta › lançamentos, a trilha voltando, venda → ficha, Investimento › anúncio, a árvore → painel da campanha, a tela sem erro e o celular;
  - regressão: t115, t114, t113, t111, t109 e t107 OK.
- **Em produção**: nós da campanha da Escola Aurora conferidos (leads 3.027, investimento R$ 11.002,19, CPL R$ 4,31 = 11.002 ÷ 2.550 novos, igual ao card de produção).

## Comissões e conexões (v0.120)
**Comissões**
- Banco: gatilho `comissao_venda_t` em `vendas` e `comissao_parcela_t` em `contas_receber`. Os dois só trabalham se o workspace tiver regra ou se o fato já tiver comissão, então importações grandes sem regra não ficam mais lentas.
- Front:
  - `vComissoes`: em `cad-comissoes` (Configurações), as abas Regras e Quem recebe; em `crm-comissoes` (Vendas), as abas Resumo do mês e Extrato;
  - formulários de pessoa e de regra (com explicação), fechamento do mês e marcar como paga;
  - a Equipe ganhou vínculo e equipe comercial;
  - a Nova venda ganhou oferta e quem vendeu.
- Teste de banco (`t120_comissoes_banco.sql`, banco `fa`): coprodutor com 30% do líquido de 80 vendas e 22 parcelas; vendedor com 8% no produto e 5% nas demais (só as dele); estrategista com 10% do bruto por venda (44 contas a pagar); fechamento de setembro; reembolso que vira estorno e é descontado em outubro; reembolso "por venda" que cancela a conta.

**Conexões**
- Função `conexoes`, com as rotas iniciar, retorno, sincronizar e desconectar:
  - Meta: Graph API v21.0 (troca pelo token de 60 dias, contas de anúncio, páginas e Instagram, insights por anúncio com paginação, Instagram);
  - Google: OAuth offline com refresh, YouTube Data e Analytics, e Google Ads searchStream (v20).
- Front:
  - `cxHtml` e `cxLiga` em Integrações: cartões, contas, sincronizar, desconectar, campanhas sem canal e últimas execuções;
  - `cxRetorno` trata a volta do login. `?v=tela` abre uma tela pelo endereço.
- Teste da função (`tests/edge/conexoes_teste.ts`, 29 verificações, APIs simuladas):
  - login e retorno do Meta e do Google; retorno de uso único;
  - token fora do alcance do navegador;
  - anúncios com 2 páginas, ligados ao canal pelo `utm_campaign` das url_tags;
  - Instagram (perfil e posts, com métrica não suportada); YouTube (canal, vídeos e vídeo cadastrado);
  - Google Ads (custo em micros); renovação do token do Google;
  - agendamento com segredo; token do Meta vencido marca "expirada"; desconectar.
- Teste da tela (`t120_comissoes_conexoes.py`, 33 verificações): tudo pela interface, conferindo com o banco, e no celular sem rolagem lateral.
- Produção: ainda não aplicado (ver decisoes-e-pendencias).

## Árvore, parte 4 (v0.119)
- Front:
  - `arvLocal(no, par)` e o desvio em `arvDesenha` (nó que começa com `loc.` não vai ao banco);
  - `vCustoOp` grava `ARV_CO`; `coDados` guarda em cada item as contas a pagar (`ids`);
  - mapa de `fin-custo` com 10 cards a mais; o texto do card ignora o "/mês" no fim;
  - `arvColunas('mkt-trafego')`: linhas `tr[data-canal]` (com a plataforma) e `tr[data-d]` (o dia, com o canal escolhido).
- Testes:
  - `t119_arvore4.py`, com 27 verificações: cards de Custos e margens = árvore; soma por tipo = custo do mês; custo › tipo › item › conta a pagar; ponto de equilíbrio; mensagem sem a foto da tela; as células de Mídia paga = árvore sem aviso; clique na célula não seleciona o dia; origem do lançamento de recebimento e de parcela de contrato;
  - regressão: t118, t117, t116 e t115.
- Em produção (Escola Aurora): o lançamento de recebimento leva à venda e o de parcela de contrato mostra o contrato nº 1. O MRR de Contas a receber é igual ao da árvore.

## Árvore, parte 3 (v0.118)
- Front:
  - `arvColunas(vk)` e `arvLigaCelulas(el, vk)`, chamada em `arvLigaTela`. Cabeçalho lido por `textContent` (o CSS põe em maiúsculas). Células ganham a classe `arvc`;
  - `corpoCohorts` põe `data-arvp` {ini, fim} nas linhas de mês e semana;
  - `arvArred` evita o aviso quando a diferença é só arredondamento;
  - mapas novos: `fin-dash` (Caixa projetado em 30 dias) e `crm-dash` (Novos em 30 dias, A qualificar).
- Testes:
  - `t118_arvore3.py`: cards novos = árvore; Caixa › A pagar › conta; Vendas › Gerado › venda › lançamento › Origem › venda (trilha de 4 níveis); Contas a pagar › Pago › conta; as 12 células de Campanhas ativas, as coortes (campanha, mês e semana × 3 abas) e Por campanha, cada célula = raiz da árvore sem aviso; clique na célula não abre a campanha; celular;
  - regressão: t117, t116, t115 e t114.
- Em produção (Escola Aurora): caixa projetado em 30 dias R$ 70.995,09 (igual ao Dashboard financeiro), ROAS da campanha ativa 1,24x (igual à tabela), 2.792 pessoas a qualificar; vendas, contas a pagar e lançamentos já ligados entre si.

## Árvore, parte 2 (v0.117)
- Front:
  - a linha com `ir` vira clique que empilha o nó (`arvVai`);
  - o nó com `pessoa` mostra o botão da ficha;
  - os mapas novos ficam em `arvMapa`: `fin-receber`, `fin-pagar` e `crm-contratos`, além de cards a mais em `adm-painel`, `mkt-dash` e `fin-custo`.
- Testes:
  - `t117_arvore2.py`, com 54 verificações: cards de 6 telas conferidos; Lucro › Receitas › conta › lançamento com débitos = créditos, a trilha de 4 níveis e o botão da ficha; sem erro de JavaScript;
  - regressão: t116 (80), t115 e t114 OK.
- Em produção (Escola Aurora): lançamento de venda R$ 1.176,46, LTV de setembro R$ 818,71, pago em setembro R$ 42.499,11 e 14 contratos ativos. A linha do razão já leva ao lançamento.

## Visual, Dashboard em camadas e campanha em etapas (v0.121)
- Montagem: `integra121.py` roda o `integra120.py` e junta `v121.css` (tema e componentes) e `v121.js` (comportamento).
- Visual: bloco `<style id="v121">` com os tokens neon sob `:root[data-estilo="azul"]` (escuro e claro), 3D (`--rx`, `--ry`, `--mx`, `--my` definidos pelo `mousemove`), hierarquia de botões e o menu `.maism`.
- `marcaSinais()`: chamado por um `MutationObserver` (uma vez por quadro) e marca `.vneg/.vpos` nos valores e `.kneg/.kpos` nos cartões.
- Dashboard: `painelHero()` monta os 4 cartões com `sparkMes()` e `varMes()`; `saldoHero()`; `painelPos()` compacta os cartões menores (`brlK`) e liga o cartão do CAC ao painel `#pgCac`. A faixa "Qualidade do dado" é inserida antes do rótulo da seção.
- Nova campanha: `abrirWizard(id, passo)` no `#modalRoot`; cada etapa grava (insert/update em `campanhas`, insert/update em `campanha_canais`) e aplica a estratégia (`campanha_aplicar_estrategia`) quando ela muda. Novo projeto da campanha segue o padrão anterior (`projeto_auto` com o modelo padrão).
- Rascunho: `campRascunho(m, c, nProjetos)` no topo da campanha.
- Editar campanha: `campFormCompacto()` depois do `abrirForm`.
- Growth Model: botões reorganizados no próprio template; os ids (`gpDup`, `gpDet`, `gsLimpa`, `gpDesc`) foram mantidos, então os eventos não mudaram.
- Testes: `t121_visual_campanha.py` (banco fa): tema, Dashboard, cores, as 3 etapas com conferência no banco, rascunho, "começa em", formulário em blocos, Ctrl+S, Mais ações e a árvore do vendedor. t118 a t120 rodados de novo.
