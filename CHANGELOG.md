# Histórico de versões

Formato: [Versão] - data. Seguimos o padrão `MAIOR.MENOR.CORREÇÃO`. Enquanto o sistema estiver em construção, a versão começa em 0.

## v0.24 — Permissões por ação e rateio de custos
- **Permissões por ação**: além do nível do módulo, cada função (e cada pessoa) pode liberar ou bloquear **Ver, Criar só lead, Criar, Editar e Excluir** em Clientes e leads, Vendas, Contratos, Alunos, Contas a receber, Contas a pagar, Campanhas, Produtos e Projetos. Ex.: ver clientes, não cadastrar cliente, mas cadastrar lead.
- **Por pessoa**: em Equipe e acessos, botão **Permissões** (só administrador): muda o nível de qualquer módulo e as ações só para aquela pessoa; vence a função. Ordem: pessoa > função > nível do módulo.
- Imposto pelo banco (políticas das 9 tabelas passam a usar `pode()`); "Criar só lead" só aceita cliente com status lead. Telas de outros dados que dependem dessas tabelas seguem o nível do módulo.
- **Rateio de custos** (Cadastros → Rateio de custos): regras que dividem um custo entre centros de custo por percentual (somam 100%). Aplica-se por conta contábil ("Rateio padrão do custo" no Plano de contas) ou direto na conta a pagar.
- Centros de custo ganharam **Entra no CAC**. O CAC (mídia e total) passa a usar só a parte dos custos que cai em centros marcados como CAC; o painel mostra quanto ficou de fora. Novos centros no Demo: Marketing, Comercial (no CAC), Sucesso do cliente e Administrativo (fora).
- Banco: `v_custos_rateados`, `v_rateio_regras`, tabelas `rateio_regras` e `rateio_itens`, colunas `funcoes.acoes`, `equipe.permissoes_ind/acoes_ind`, funções `pode()`, `valida_acoes()`.
- Limites: a ferramenta recusou criar a função `salvar_rateio` e um gatilho de validação das permissões individuais; a soma de 100% é conferida na tela e a view ignora regra que não soma 100%.
- Migrações: `20261006410000_rateio_custos.sql`, `20261006420000_permissoes_por_acao.sql` (já aplicadas no projeto).

## v0.23 — Ascensão da escada, rastro de responsáveis e banco único
- RevOps → **Ascensão da escada**: para quem comprou o produto X, quantos % foram para Y, em quantos dias em média, quantos "ficaram por aqui" e os caminhos mais comuns (em % das pessoas). Filtros: período da primeira compra, produto de entrada e mínimo de dias desde a compra (para não punir compra recente). Cálculo no banco (`revops_ascensao`), sem IA. Só compras aprovadas; recompra do mesmo produto não conta.
- **Rastro de responsáveis gravado no banco** (`responsavel_historico`): toda troca de comercial (lead) ou de CS (aluno) grava quem era, quem passou a ser, quem fez a troca e quando. Aparece na ficha do cliente (seção Responsáveis, histórico e linha do tempo).
- Ficha do cliente: seção **Responsáveis** (comercial e CS por matrícula, com botão Alterar) e coluna "Vendido por" nas compras.
- **Vendedor da venda**: vendas e contratos novos gravam o comercial responsável do lead no momento da venda (`vendedor_id`); aparece em Vendas e a receber e na ficha. Nova matrícula herda o CS atual do aluno.
- **Banco único**: os dados da escada de produtos (5 produtos, ~320 clientes fictícios, com saídas) foram colocados no workspace "Growths — Demo" (`seed/revops_escada_demo.sql`). O workspace paralelo "RevOps — Simulação" deve ser apagado (ver como-rodar-o-banco).
- Migrações: `20261006390000_responsavel_historico_vendedor.sql`, `20261006400000_revops_ascensao.sql` (já aplicadas no projeto).

## v0.22 — Cadastro da empresa, funções e permissões por módulo
- Administrativo → **Cadastro da empresa**: nome, razão social, CNPJ (validado pelos dígitos), telefone, e-mail de contato, endereço, responsável, responsável financeiro, regime tributário (MEI, Simples, Presumido, Real), regime de apuração (competência/caixa), exercício contábil (início/fim) e fechamento (mensal/trimestral/anual). Mostra o período contábil atual e os dias para fechar. Só administradores editam.
- Cadastros → **Funções e permissões** (só administrador): cada função define, para 9 módulos, "Sem acesso", "Só consultar" ou "Consultar e editar". Botão para criar funções sugeridas (Administrador, Comercial, CS, Financeiro, Marketing, Somente consulta).
- Cadastros → **Equipe e acessos**: cargo, avisos e, para administradores, "Pode entrar no sistema" + função de acesso; lista de quem já entra no sistema.
- Menu esconde módulos sem acesso; módulo só de consulta mostra aviso e esconde botões de criar/editar.
- **Imposto pelo banco**: políticas restritivas em 70+ tabelas (leitura e escrita por módulo). Quem não tem permissão não vê nem altera, mesmo fora da tela.
- PENDENTE de aplicar no banco: `20261006380000_acessos_sincronizacao.sql` (liberar/retirar acesso e aceitar convite no primeiro login). Ver docs.

## v0.21 — Cohorts do RevOps e ações financeiras só nos módulos próprios
- RevOps → **Cohorts**: tabela de calor (coorte × tempo desde a entrada). Agrupa por período de entrada, campanha, produto de entrada, origem (canal), UTM source ou tag. Mede retenção, recompra ou receita acumulada por pessoa. Filtros combináveis: período de entrada, campanha, produto, origem, UTM source e tag; colunas mensais ou semanais (6 a 24).
- Banco: função `revops_cohorts` (determinística). Coorte = primeira matrícula; "ativo" segue a regra do painel do RevOps.
- Painel gerencial: fluxo de caixa mantém só o botão "Lançamentos"; marcar recebido/pago, estornar e cancelar ficam apenas em Vendas e a receber e Contas a pagar.

## v0.20 — Etapas editáveis, responsáveis e alertas
- Funil de leads (CRM) e Alunos: botão **Gerenciar etapas** (criar, renomear, reordenar, excluir). Cada etapa tem "o que precisa acontecer", mensagem padrão (`{nome}`, `{primeiro_nome}`) e opção de avisar o responsável. A etapa "Cliente" dos leads é protegida.
- **Comercial responsável** (lead) e **CS responsável** (aluno): atribuição no cartão e no cadastro do cliente; filtro Todos / Só os meus / Sem responsável / por pessoa da equipe.
- Alertas (banco): ao atribuir um responsável ou mover o cartão para etapa com alerta, o responsável recebe notificação pelos canais da Equipe. No sino, "Abrir cartão" abre a ficha.
- Banco: `etapas_kanban.descricao/mensagem_padrao/alertar_responsavel`, `pessoas.responsavel_comercial_id`, `alunos.responsavel_cs_id`, `notificacoes.pessoa_id`, função `equipe_avisa` e triggers de validação/alerta.
- Não coberto: etapas do funil de campanha (`funil_etapas`) e mensagem padrão na ficha.

## v0.19 — Projeto do cliente, canais, ações no fluxo de caixa e ficha do aluno
- Projeto ligado a um cliente. No cadastro de Produtos, campo "Projeto automático (modelo)": ao ativar o contrato (ou aprovar a venda) desse produto, o projeto nasce para o cliente já com as atividades do modelo, uma vez só.
- Canais novos: WhatsApp API oficial, LinkedIn Ads, GPT Ads (ChatGPT) e TikTok Ads (todos os workspaces); entram também no catálogo de integrações.
- Dashboard de Mídia paga: tabela "CAC de mídia por canal" (investido, leads, CPL, clientes, CAC, comparação com o CAC geral, ROAS) com clique para filtrar.
- Painel gerencial: o fluxo de caixa ganhou os botões Marcar recebido, Marcar pago, Cancelar, Estornar e Lançamentos; na DRE, clicar no valor mostra os lançamentos que o formam e abre a operação de origem.
- Alunos: clicar no cartão abre a ficha completa; nome, e-mail e telefone são editáveis (origem, compras e presença não). A ficha mostra produtos comprados, total, primeira campanha, campanha da compra, tempo da entrada até a compra, tempo assistido e projetos.

## v0.18 — Painel dos projetos
- Projetos: painel com período (7, 15, 30, 90 dias, mês, ano, tudo ou datas manuais), contagem de em andamento, planejados, pausados, com atraso, concluídos e criados no período.
- Filtro por situação com contagem: ativos, em andamento, planejados, inativos (pausados e cancelados), pausados, concluídos no período, cancelados e todos; busca por nome.
- Lista com situação, responsável, progresso, atrasadas, início, previsão e data de conclusão. Novo campo `projetos.concluido_em`, preenchido sozinho ao concluir.

## v0.17 — Cadastro e ficha do lead organizados
- Cadastro de clientes em seções: Contato (nome, e-mail, telefone, "esta pessoa é" lead/cliente), Origem (campanha e canal), Rastreamento (UTM) e Identificadores. Cadastrar já cria o cartão no CRM.
- Ficha do lead redesenhada: nome com iniciais e situação, contato (e-mail clicável e link para o WhatsApp), origem, UTMs em blocos, negócio, tags, notas e linha do tempo; botão Editar cadastro.
- Cartão do CRM mostra nome, e-mail, telefone e origem.

## v0.16 — Menu, período, CAC de mídia x total, nomes no fluxo e notas do lead
- Menu: só o Administrativo (Painel gerencial e Planejamento) fica no topo; Configurações (com os Cadastros dentro) fica no rodapé. Linha separando o workspace do menu.
- Painel gerencial: período com 7, 15 e 30 dias, mês, 12 meses, ano, tudo e personalizado (de/até); vale para lucro, margem, ROI, CAC e fluxo de caixa (resultado calculado pela data do lançamento contábil).
- Campanhas ativas em uma linha por campanha (tabela), não mais cartões.
- CAC separado em dois: CAC de mídia (só anúncios) e CAC total (mídia + equipe, comissões, ferramentas marcadas). Composição por tipo de custo, por fornecedor e por campanha, com o quanto cada uma tira da margem. Plano de contas ganhou "Entra no CAC como".
- Fluxo de caixa com o nome do cliente (a receber) e do fornecedor (a pagar), previsto e realizado.
- CRM: clicar em qualquer ponto do cartão abre a ficha; a ficha ganhou notas do lead (autor e data).

## v0.15 — Rastro financeiro (botão "Lançamentos")
- Botão "Lançamentos" ao lado de cada venda, parcela de contrato (lista e detalhe do contrato) e conta a pagar: mostra de onde veio a operação, os lançamentos contábeis que ela gerou (com débito e crédito, inclusive estornos) e a movimentação no banco.
- Vendas mostram a forma de pagamento e o número de parcelas; o resumo do rastro mostra bruto, taxa, imposto, líquido e quando o valor cai no caixa.
- Lançamentos contábeis passam a nomear parcela e cancelamento de contrato.

## v0.14 — Administrativo no topo e Painel gerencial
- Menu Administrativo passa a ser o primeiro grupo; o Painel gerencial é a tela inicial.
- Painel: KPI de campanhas ativas e um cartão por campanha ativa (leads e vendas contra a meta, investido, receita, CAC, ROAS), que abre a campanha.
- Métricas financeiras por regra fixa, com período (mês, 12 meses, ano, tudo): lucro, margem, ROI (lucro ÷ saídas), MRR, ARR (MRR × 12), NRR e retenção bruta (GRR) dos clientes recorrentes de 12 meses atrás, e penetração de mercado (clientes ativos ÷ tamanho do mercado informado no plano).

## v0.13 — Importação segura de dados e botão Voltar
- Mídia paga e vídeos não aceitam mais lançamento manual: os números vêm da integração. Planilha só para primeira carga ou recuperação de falha de conexão.
- Importação segura (regras no banco): somente administrador; motivo obrigatório (primeira carga só se a integração nunca sincronizou; recuperação só com integração em erro ou sem sincronizar há mais de 48 h, e só a partir do último dia sincronizado); justificativa mínima de 20 caracteres; conferência prévia (simulação sem gravar) com totais; confirmação; arquivo repetido recusado (hash); limite de 10 importações por 24 h; validação de coerência (cliques ≤ impressões, sem datas futuras, dentro da janela da campanha, custo máximo por linha etc.); nunca sobrescreve dia que já tem dado; tudo ou nada.
- Histórico de importações com quem, quando, motivo e justificativa, e reversão do lote inteiro (com motivo). Dado importado fica marcado com a origem e aparece em aviso na Mídia paga.
- Botão "← Voltar para <tela>" em toda tela aberta a partir de outra, e o botão voltar do navegador/celular também funciona.

## v0.12 — CRM com filtros e ganho/perdido; Planejamento da empresa
- Funil comercial e Funil da campanha: filtros por nome, tag, origem, campanha, produto, negócio (aberto/ganho/perdido), qualificação, UTMs e data de entrada. O cartão abre com origem completa, tracking, tags, contratos, motivo e linha do tempo.
- Ganho e perdido com motivo (cadastro "Motivos de ganho e perda"); arrastar para Cliente pede o motivo do ganho e abre o contrato. Tags livres por pessoa (e as tags dos produtos comprados entram no filtro).
- Administrativo → Planejamento da empresa: plano (visão e estratégia), objetivos, índices com partida/meta/realizado automático (receita, MRR, leads, clientes, conversão, investimento, CAC, ticket médio) ou manual, metas por setor e campanhas ligadas a cada meta (campo novo no formulário da campanha).
- Ritmo por regra fixa: progresso x fração do tempo do plano (atingida, no ritmo, atrás do ritmo).

## v0.11 — Contratos de prestação de serviço
- Menu Vendas → Contratos: contrato com vários produtos, recorrente ou não (mensal/trimestral/semestral/anual), início/fim, parcelas, conta em que o cliente paga, forma de pagamento e acessos.
- Ao mover o lead para "Cliente" (funil comercial ou funil da campanha), abre o contrato pronto para preencher; quem ficou sem contrato aparece em "Ganhou, falta contrato".
- Ativar o contrato gera as parcelas em contas a receber e, por parcela, o lançamento de previsão (contas a receber de contratos x receita de serviços). A baixa credita o caixa e entra no fluxo e na DRE. Cancelar reverte só o que não foi recebido.
- Correção: arrastar cartão no "Funil da campanha" gravava na coluna errada (agora etapa_id).
- Documentado como próximos passos: dashboard gerencial do negócio com OKRs; entrada automática de conversas do Instagram e WhatsApp no CRM com origem; agente de resposta automática.

## v0.10 — Dashboard geral, dashboard por campanha e Fechamento
- Marketing → Dashboard agora é geral (todas as campanhas): período livre, atalhos, filtro de campanha, KPIs (leads, investido, CPL, clientes, CAC, receita, ROAS, ROI, LTV, churn), cohorts por campanha/semana/mês em 3 visões; clicar numa campanha abre a página dela.
- Cada campanha tem a aba Dashboard (números só dela) e a aba Fechamento (antes "Debriefing").
- Botão "Fechar a campanha" / "Fechar o ciclo" (perpétuo): guarda uma foto do planejado x realizado (campanha_fechamentos), opcionalmente finaliza.
- Fechamento: planejado x realizado (leads, vendas, receita, conversão, CAC, investimento), por canal, funil, debriefing e melhorias por sprint (campanha_melhorias) com sugestões por regra fixa e "Criar experimento".

## [0.123] - 2026-10-21 — Gráfico de linha no período da tela e cadastros dentro da nova campanha
- **Gráfico do painel "De onde vem este número" passa a ser sempre de linha**, dentro do período escolhido na tela de onde você clicou:
  - o agrupamento sai sozinho pelo tamanho do período (até 31 dias: por dia; até 4 meses: por semana; até ~2 anos: por mês; acima: por ano) e pode ser trocado nos botões **Dia / Semana / Mês / Ano**;
  - números "na data" (MRR, a receber, caixa…) mostram o valor no fim de cada dia, semana, mês ou ano;
  - mostra a variação do último ponto completo contra o anterior, o maior e o menor valor; o ponto de hoje ou do mês em andamento aparece tracejado como incompleto;
  - clicar num ponto abre aquele dia, semana ou mês, já com o gráfico daquele trecho.
  - Substitui os gráficos da v0.122 (rosca, cascata, barras e medidor). As listas de composição continuam abaixo do gráfico.
  - Banco: função `arvore_serie` (migração `20261024100000_arvore_serie.sql`), que calcula o mesmo número ponto a ponto, numa chamada só.
- **Nova campanha: cadastrar o que faltar sem sair dela**:
  - **Produto**: "＋ Cadastrar novo produto…" abre o cadastro por cima e já escolhe o produto criado;
  - **Estratégia**: "＋ Nova estratégia…" abre o cadastro da estratégia por cima, com as **etapas**: o modelo pronto marca as dele; você marca e desmarca as do catálogo por fase (Aquisição, Aquecimento, Conversão, Retenção) e escreve etapas novas em cada fase. A estratégia criada já fica escolhida;
  - ao escolher uma estratégia, a nova campanha mostra as etapas que vai receber;
  - **Canal**: "＋ Novo canal" na etapa 3 cria o canal e já marca na campanha.
- **Nova estratégia** (Configurações → Estratégias e funis) ganhou a mesma escolha de etapas.
- Banco em produção: aplicados `RODAR_v0.121_arvore_vendedor.sql` e `RODAR_v0.123_arvore_serie.sql` (a v0.120 já estava aplicada).
- Testes: `t123_linha_cadastros.py` (20 verificações). O `t122_graficos_arvore.py` saiu (o gráfico mudou).

## [0.122] - 2026-10-21 — Mini gráfico em cada número da árvore
- Ao clicar num número (em qualquer tela), o painel "De onde vem este número" abre com um **mini gráfico** no alto, escolhido sozinho pelo tipo do número:
  - **Evolução por mês** (linha): quando o número tem a quebra por mês. Mostra a variação do último mês fechado contra o anterior; o mês atual aparece como parcial.
  - **Cascata** ("Como se chega em…"): quando o número é uma conta de somar e subtrair em reais, como o Lucro (receitas − deduções − despesas).
  - **Composição** (rosca): quando é uma soma de partes (ex.: Despesas = deduções + custos + despesas) ou tem uma quebra (por produto, canal, conta, campanha). Até 5 fatias e "Outros".
  - **Por dia** (barras): quando só há a lista de registros com data (soma o valor, ou conta os registros).
  - **Evolução nos últimos meses**: para os indicadores de razão (CAC, CPL, CPC, CTR, ROAS, ROI, margem, LTV, churn, MRR…), o sistema calcula o mesmo número mês a mês (4 meses) e desenha a linha.
  - **Medidor**: percentual sem histórico.
- Vale para todos os níveis: ao descer, o nível de baixo também tem o seu gráfico. Clicar numa fatia, ponto ou barra desce para aquele item, igual à lista.
- Cores: subir é verde e cair é vermelho, exceto em custo, CAC, CPL, CPC e churn, em que subir é vermelho.
- Correção: o aviso "Na tela aparece…" não aparece mais quando o cartão mostra o valor compacto (R$ 147,8 mil).
- Cobertura conferida: 53 dos 60 números clicáveis das telas principais abrem com gráfico; os 7 restantes não têm dado (NRR, GRR e penetração sem base; Fixo e Variável zerados; Pró-labores com um único item; Imposto no equilíbrio).
- Testes: `t122_graficos_arvore.py`.

## [0.121] - 2026-10-21 — Visual com destaque de cores, Dashboard em camadas e campanha em etapas
- **Modo claro passa a ser o padrão.** O escuro continua no botão "Modo escuro" do menu e a escolha fica guardada no navegador.
- **Cores com significado (azul de sempre, com destaque neon):**
  - valor negativo em vermelho e variação boa em verde, com brilho no escuro e cor mais fechada no claro;
  - cartões de lucro, resultado, margem e ROI ficam com o valor e a borda verdes quando positivos e vermelhos quando negativos;
  - ▲▼ de Mídia paga e a coluna "Efeito" do Growth Model em verde ou vermelho conforme for bom ou ruim.
- **Efeito 3D**: ao passar o mouse, o cartão sobe, inclina para o lado do mouse e uma luz acompanha o cursor. Desligado para quem pediu menos movimento no computador.
- **Botões com hierarquia**: uma ação principal por tela (cheia, em degradê), secundárias com contorno e perigosas em vermelho.
- **Dashboard em camadas**:
  - "O que importa agora": Receita bruta, Lucro, Saldo em banco e CAC total em cartões grandes; receita e lucro com a tendência dos últimos meses (o mês atual aparece pontilhado e marcado "parcial") e a variação do último mês fechado contra o anterior;
  - Saldo mostra o projetado até o fim do período e o que entra e sai; o CAC mostra o só mídia e quanto consome da receita, e o clique leva ao painel do CAC;
  - "Funil, vendas e contas": os demais indicadores em cartões menores; valores de 10 mil para cima ficam compactos (R$ 147,8 mil) e o valor exato aparece no mouse;
  - Lucro e Margem saíram de "Métricas financeiras" porque já estão no alto.
- **Nova campanha em 3 etapas** (Campanhas → Nova campanha):
  1. O básico (nome, modelo, produto, estratégia, tipo de mídia e datas): já cria a campanha como rascunho;
  2. Orçamento e metas, com a conta na hora: CPL que cabe no orçamento, conversão necessária, CAC previsto e receita prevista; avisa se o CAC passa do máximo aceito;
  3. Canais: escolhe os canais e divide o orçamento e a meta de leads (o sistema sugere a divisão e a meta por dia); confere o total e avisa se sobrar ou passar de 100%. Grava na seção Canais da campanha (a mesma de antes), com a utm_campaign automática.
  - Cada etapa salva; "Terminar depois" volta para a campanha.
- **Campanha em rascunho**: faixa no alto com o que já foi feito e o que falta (o básico, orçamento e metas, canais, projeto da equipe), com "Continuar de onde parei" (abre a etapa que falta) e "Ativar campanha". Em rascunho, "Fechar a campanha" deixa de ser o botão em destaque.
- **Campanha que ainda não começou** mostra "começa em dd/mm" no lugar de "abaixo da meta".
- **Editar campanha** em 4 blocos (Sobre, Datas e orçamento, Metas, Projeto), só com os campos do modelo escolhido, explicações no ⓘ, botões fixos no rodapé e Ctrl+S para salvar.
- **Growth Model**: "Novo cenário" em destaque e "Comparar cenários" ao lado; Duplicar, Nome e hipótese, Limpar mudanças e Descartar foram para "Mais ações".
- **Tabelas mais limpas**: o pontilhado de "clique para ver de onde vem" aparece só na linha sob o mouse.
- **Correção — árvore dos números**: em Receita bruta → "Por vendedor", todas as vendas apareciam como "Sem vendedor". A venda guarda a pessoa da Equipe e a árvore procurava pelo usuário. Migração `20261023100000_arvore_vendedor.sql` (`RODAR_v0.121_arvore_vendedor.sql`).
- Testes: `t121_visual_campanha.py` (37 verificações).

## [0.120] - 2026-10-20 — Comissões e conexões com Meta e Google
- **Comissões**: a configuração (Quem recebe e Regras) fica em **Configurações → Comercial e produtos → Comissões**; o acompanhamento (Resumo do mês, Extrato e Fechar o mês) fica em **Vendas → Comissões**:
  - **Quem recebe**: as pessoas da Equipe ganharam **vínculo** (vendedor, coprodutor, estrategista, parceiro ou equipe) e a marca **"faz parte da equipe comercial"**. Quem é de fora não precisa ter acesso ao sistema.
  - **Regras**: % sobre a venda, valendo para o **projeto todo**, uma **campanha**, um **produto** ou uma **oferta**. Cada regra escolhe:
    - a base: líquido (padrão) ou bruto;
    - sobre quais vendas: todas ou só as que a pessoa fez (vendedor);
    - como paga: conta a pagar mensal, conta a pagar por venda ou só relatório;
    - o dia do vencimento, a vigência e se conta as parcelas de contrato.
  - Se a mesma pessoa tiver mais de uma regra para a venda, vale a **mais específica**: oferta, depois produto, depois campanha, depois projeto. Pessoas diferentes somam. O formulário mostra a conta em português (ex.: "ganha 10% do líquido de cada venda do projeto").
  - A comissão é calculada sozinha quando a venda é aprovada e quando a parcela de contrato é recebida. Ao salvar uma regra, o sistema refaz as comissões ainda não lançadas desde a data escolhida.
  - **Resumo do mês**: por pessoa, o total, o que falta lançar, o que é só relatório, o lançado, o pago e os estornos. O botão **Fechar o mês** cria uma conta a pagar por pessoa (conta "Comissões e afiliados", fornecedor criado sozinho).
  - **Venda devolvida**: o que ainda não foi lançado é cancelado. O que já foi lançado vira **estorno pendente** e é descontado no próximo fechamento. Na regra "por venda", a conta ainda não paga é cancelada junto.
  - **Extrato**: cada comissão com cliente, produto, regra, base, %, valor e situação. As de "só relatório" podem ser marcadas como pagas por fora.
- **Nova venda**: campos **Oferta** (para as regras por oferta) e **Quem vendeu** (equipe comercial; vazio = o comercial responsável pela pessoa).
- **Conexões automáticas** (Configurações → Integrações):
  - **Meta** (Facebook Ads + Instagram) e **Google** (Google Ads + YouTube) conectam pelo login oficial da plataforma;
  - você escolhe as contas, sincroniza na hora ou deixa a sincronização diária;
  - o acesso fica guardado no servidor (schema privado) e nunca passa pelo navegador.
  - Anúncios vão para **Mídia paga**, ligados ao canal da campanha pelo `utm_campaign`. O que não bater aparece para você escolher o canal.
  - Instagram e YouTube: seguidores ou inscritos, alcance ou visualizações por dia, e os posts e vídeos com métricas. Os vídeos do YouTube cadastrados em Vídeos e webinários recebem as métricas diárias.
  - Para ligar de verdade, falta criar o app no Meta e o projeto no Google e guardar as chaves no Supabase: passo a passo em `docs/conectar-meta-e-google.md`.
- Banco: migrações `20261022100000_comissoes.sql` e `20261022200000_conexoes.sql` (juntas em `supabase/RODAR_v0.120_comissoes_conexoes.sql`) e a edge function `conexoes`.
- Testes: `t120_comissoes_conexoes.py` (33 verificações na tela), `t120_comissoes_banco.sql` (cenário completo das comissões) e `tests/edge/conexoes_teste.ts` (29 verificações da função, com Meta e Google simulados).

## [0.119] - 2026-10-20 — Árvore dos números, parte 4
- **Custos e margens com árvore em todos os cards de custo**: Custo do mês, Pró-labores, Operação (sem pró-labore), Fixo, Variável, Parcelado e pontual, Ponto de equilíbrio, Para a meta de X% de lucro, Imposto no equilíbrio e A receber no mês.
  - O custo abre por tipo, por área e por conta contábil, e cada item mostra as contas a pagar que o compõem (ou explica que é uma recorrência ainda não lançada, entrando pelo valor da regra). Da conta a pagar se chega aos lançamentos.
  - O ponto de equilíbrio mostra os custos contados e o que sai de cada real vendido (alíquota, % variável e, na meta, a margem). O imposto mostra receita × alíquota efetiva, com anexo e fator R.
  - Esses números usam as escolhas desta tela ("Contar no custo" e premissas), que ficam no navegador. Por isso a árvore deles é montada no próprio navegador, com a mesma conta da tela. Se a tela não estiver aberta naquele mês, a árvore pede para reabrir.
- **Mídia paga**: os números das tabelas por canal (investido, leads, CPL, clientes, CAC de mídia, receita, ROAS) e por dia (investimento, impressões, cliques, CTR, CPC, connect rate, leads, CPL, vendas, ROAS) abrem a árvore só daquela linha. Clicar no restante da linha continua filtrando a tela.
- **Lançamento de recebimento e de parcela de contrato** agora mostra a origem: a parcela (vencimento, número e situação) e a venda, que abre na árvore, ou o número do contrato.
- **Correção**: em Contas a receber, o MRR passou a usar a data de cancelamento no horário de São Paulo, como o Dashboard e a árvore. Antes usava UTC e um cancelamento perto da meia-noite podia contar diferente.
- Conferido: 27 verificações novas, e as anteriores (t118, t117, t116 e t115) continuam passando.
- Banco: migração `20261021100000_arvore_numeros_4.sql`, já aplicada em produção (`supabase/RODAR_v0.119_arvore_numeros_4.sql` fica para registro).
- **Correção nos scripts de banco (20/10, depois da entrega)**: rodar de novo o `RODAR_v0.118` no editor do Supabase, com o banco já atualizado, duplicava o trecho "Origem" do lançamento. Em seguida, o `RODAR_v0.119` parava com "Trecho não encontrado em public._arv_extra". Nada quebrou na tela, porque o trecho repetido era igual. Mas a função ficou com o bloco duplicado, e ele foi removido em produção.
  - Causa: a conferência de "já aplicado" procurava o trecho novo inteiro. Colado no editor, o arquivo pode vir com quebras de linha do Windows, e aí o trecho não era encontrado.
  - Os dois scripts agora ignoram essas quebras de linha e conferem também uma marca curta de que a troca já foi feita. Foram testados rodando 8 vezes seguidas, com e sem quebras do Windows, sem erro e sem duplicar. Em produção, as 6 trocas constam como já aplicadas, então rodar de novo não muda nada.

## [0.118] - 2026-10-20 — Árvore dos números, parte 3
- **Números dentro das tabelas agora abrem a árvore**. O número clicável fica sublinhado com pontilhado; clicar nele abre a árvore com o recorte da linha, e o clique na linha continua abrindo a campanha.
  - **Dashboard › Campanhas ativas**: Leads, Vendas, Investido, Receita, CAC de mídia e ROAS de cada campanha;
  - **Dashboard de marketing › Coortes** (por campanha, mês ou semana, nas 3 abas) e **Por campanha**: Leads, Clientes, Custo, CPL, CAC, Receita, LTV, ROAS, ROI, Alunos e Churn da linha.
- **Novos cards com árvore**: Caixa projetado em 30 dias (Dashboard financeiro: saldo + a receber − a pagar até daqui a 30 dias), Novos em 30 dias e A qualificar (Dashboard de vendas), com quebras por canal e campanha e a lista de pessoas.
- **Venda e conta a pagar viraram um nível da árvore**: na lista de vendas, a venda abre o valor bruto → taxas → impostos → líquido, as parcelas e os lançamentos contábeis. Na lista de contas a pagar, a conta abre fornecedor, conta contábil, centro de custo, campanha e os lançamentos. E o lançamento ganhou a "Origem", que volta para a venda ou a conta. Exemplo: Vendas › Gerado › venda › lançamento › venda.
- O aviso "Na tela aparece…" não aparece mais quando a diferença é só de casas decimais (a tabela mostra ROI 73% e a árvore 73,2%).
- Tudo conferido: cada célula e cada card ligado mostram o mesmo número da árvore. Foram 44 verificações novas, e as anteriores (t117, t116, t115 e t114) continuam passando.
- Banco: migração `20261020300000_arvore_numeros_3.sql`, já aplicada em produção (`supabase/RODAR_v0.118_arvore_numeros_3.sql` fica para registro). Os nós novos ficam em `_arv_extra2`.

## [0.117] - 2026-10-20 — Árvore dos números, parte 2
- **A árvore chega ao lançamento contábil**: no Lucro, nas Receitas e nas Despesas, cada linha de lançamento agora abre o próprio lançamento. Ele mostra as partidas (débito e crédito de cada conta, com o centro de custo), a origem (venda, parcela, conta a pagar e fornecedor) e o botão "Abrir a ficha de …" da pessoa por trás. Exemplo: Lucro › Receitas › 4.1.01 › Venda: E-book de bônus.
- **Novos cards com árvore**:
  - **Dashboard**: NRR e GRR (MRR de hoje dos clientes de 1 ano atrás ÷ MRR deles na época, cliente a cliente) e Penetração de mercado;
  - **Dashboard de marketing**: LTV (receita líquida ÷ clientes da coorte) e Churn (saíram ÷ entraram como aluno, com a lista de alunos);
  - **Contas a receber**: A receber no período, Em atraso, Recebido no período e MRR/ARR;
  - **Contas a pagar**: A pagar no período, Em atraso e Pago no período (por fornecedor, por conta de despesa e por mês);
  - **Contratos**: Contratos ativos, Total em contratos ativos, Receita recorrente mensal, Total do mês, A receber no mês, A receber em aberto, Em atraso e Já recebido;
  - **Custos e margens**: Custos e despesas e Margem de lucro líquida.
- Em todas as telas ligadas, o número do card confere com o da árvore. Foram 54 verificações novas, e as 80 da v0.116 continuam passando.
- Banco:
  - migração `20261020200000_arvore_numeros_2.sql`, já aplicada em produção (`supabase/RODAR_v0.117_arvore_numeros_2.sql` fica para registro);
  - os nós novos ficam em `_arv_extra`, para as próximas partes entrarem sem mexer no resto;
  - `fin.receber` e `fin.pagar` passaram a aceitar a situação (previsto, recebido/pago, atraso, todas) e o filtro só de contratos.

## [0.116] - 2026-10-20 — Árvore dos números: "De onde vem este número"
- **Clicar num número abre um painel à direita** com a conta que gerou o número. Cada parte da conta, cada linha das quebras e cada registro levam ao nível seguinte: por canal, campanha, anúncio, conta contábil, produto, mês… até o lançamento ou a ficha da pessoa.
- No topo do painel fica a **trilha do caminho** (ex.: CAC › Investimento em anúncios › Pesquisa lançamento). Clicar num nível da trilha volta a ele. Esc ou ✕ fecha o painel.
- Os cards com árvore têm "›" e mostram a dica "De onde vem este número?".
- **Onde já funciona** (o número do card e o da árvore conferem em todos os casos, conferido automaticamente):
  - **Dashboard**: Lucro, Margem, ROI, MRR, ARR, Pessoas no funil, Leads qualificados, Clientes ativos, Vendas aprovadas, Receita bruta e Receita líquida das vendas;
  - **Dashboard financeiro**: Receitas, Despesas e Resultado do período;
  - **Custos e margens**: Receita do mês e Lucro líquido;
  - **Dashboard de marketing**: Leads, Investido, CPL, Clientes, CAC, Receita, ROAS e ROI;
  - **Mídia paga**: Investimento, Impressões, Cliques, CTR, CPC, Connect rate, Leads, CPL, Vendas, CAC e ROAS;
  - **Dashboard de vendas**: Pessoas, Qualificados, Clientes ativos, Lead → cliente e Ticket médio;
  - **Vendas**: Vendas aprovadas, Gerado (bruto), Líquido, Ticket médio e Reembolsos;
  - **Campanha**: Dashboard, Planejamento e metas e Captação e metas. O botão "Ver o painel completo da campanha" leva ao detalhe com gráficos da v0.115.
- Os cards que já levavam a outra tela (Saldo em banco, A receber, A pagar) continuam como eram.
- Se uma tela mostrar um número diferente da conta feita com os registros, a árvore avisa e mostra os dois.
- Banco:
  - função `arvore_no(ws, nó, filtros)`, mais as auxiliares `_arv_*`;
  - migração `20261020100000_arvore_numeros.sql`, já aplicada em produção (`supabase/RODAR_v0.116_arvore_numeros.sql` fica para registro).

## [0.115] - 2026-10-19 — Clicar no card da campanha abre o detalhe
- Na campanha, os cards **Leads, Investimento, Custo por lead, Vendas, CAC, Receita bruta, ROAS e Lead → venda** abrem um detalhe com:
  - os números de apoio;
  - gráficos por dia;
  - o mesmo indicador por canal, com a meta do canal;
  - botões para trocar de indicador sem fechar a janela.
  Os cards têm "›" e funcionam no Dashboard, em Planejamento e metas e em Captação e metas.
- **Leads**:
  - novos na base × já estavam na base;
  - qualificados, não qualificados e pendentes, no total e por canal;
  - cadastros repetidos;
  - leads por dia;
  - tabela por canal com meta, % da meta e custo por lead novo;
  - os 30 últimos leads, e o nome abre a ficha.
- **Investimento**:
  - investido × orçamento por canal;
  - investimento por dia e acumulado contra o orçamento;
  - impressões, cliques, CTR, CPC e CPL por canal;
  - os 15 anúncios que mais gastaram.
- **Custo por lead**: custo por lead novo e de todos os leads, o canal mais barato e o mais caro, CPL por dia e por canal contra a meta de CPL.
- **Vendas / Receita**:
  - por dia e acumuladas;
  - por canal (com meta) e por produto;
  - ticket médio;
  - as 30 últimas vendas, e o nome abre a ficha.
- **CAC**: por canal contra a meta de CAC e CAC acumulado dia a dia. **ROAS**: por canal e receita × investimento acumulados. **Lead → venda**: conversão por canal e conversão de qualificado em venda.
- Clicar numa linha de canal no detalhe volta ao Dashboard já filtrado nesse canal.
- Gráficos: a margem do eixo cresceu para caber valores como "R$ 5000".
- Banco: função `campanha_detalhe(campanha, hoje)`, migração `20261019200000_campanha_detalhe.sql`. Já aplicada em produção; `supabase/RODAR_v0.115_detalhe_campanha.sql` fica para registro.

## [0.114] - 2026-10-19 — Meta de leads por dia, por mês e por canal; gráficos menores; taxas do funil
- **Dashboard da campanha** com o ritmo da meta de leads:
  - painel com leads até hoje, esperado até hoje (dentro, perto ou abaixo), meta por dia, média por dia (quantos dias bateram a meta) e quanto precisa por dia até o fim da captação;
  - gráficos de linha **Leads por dia** e **Leads acumulados**, com meta, ponto verde no dia que bateu e vermelho no que ficou abaixo, e a marca de hoje;
  - **Por mês: dentro ou fora da meta**: o mês em andamento compara com o esperado até hoje;
  - **Meta de leads por canal**: barra de cada canal com a marca da meta e do esperado até hoje, situação e meta por dia. Clicar no canal filtra os gráficos e o painel.
  - Botão **Metas por canal**: edita a meta de leads de todos os canais de uma vez, mostra a soma contra a meta da campanha e pode distribuir a meta pelo orçamento dos canais pagos.
- **Gráficos menores, lado a lado**, em grade de duas colunas (uma no celular).
  - "Investimento, receita, custo por lead e CAC", que usava dois eixos, virou dois gráficos: "Investimento e receita" e "Custo por lead e CAC".
  - O seletor "Gráfico" virou "Custos" (por dia ou acumulado).
- **Meta diária correta no lançamento**: a meta é dividida pelos dias da captação (Datas das fases), não pela campanha inteira. Na Escola Aurora: 192 leads por dia (5.000 em 26 dias), antes 108,7 (5.000 em 46 dias). Campanha recorrente: meta do mês ÷ dias do mês.
- **Uma conta de lead na meta**: pessoa que entrou na campanha, uma vez cada, inclusive quem já estava na base (a mesma de Captação e metas e de Planejamento). O KPI Leads do Dashboard da campanha passa a mostrar essa conta (3.027) e informa quantos são novos na base (2.522). O CPL continua sobre os leads novos, e isso está escrito no card.
- **Funil**:
  - painel "Funil: conversão entre etapas", com as etapas principais e a % de uma para a outra, comparada com a taxa esperada;
  - na tabela "Funil etapa por etapa", as métricas de diagnóstico ganham a taxa do que medem: CTR, connect rate, conversão da página, saída do grupo, cliques por pessoa, conversão do checkout, abandono, abertura de e-mail e outras.
- A tabela de canais do Dashboard ficou só com vendas, investimento e custos; os leads com meta estão no painel novo.
- Banco: função `campanha_meta_leads(campanha, hoje)`, migração `20261019100000_meta_leads_ritmo.sql`. Já aplicada em produção; `supabase/RODAR_v0.114_meta_leads.sql` fica para registro.

## [0.113] - 2026-10-17 — Receber leads de formulários (edge function "leads")
- **Novo endereço para receber leads**: `https://yngyghlyonybvfvjcmxl.supabase.co/functions/v1/leads?chave=gw_...`. Aceita formulário HTML da página de captura, webhook da Respondi e Meta Lead Ads (pelo Zapier/Make, ou direto da Meta com o segredo `META_ACCESS_TOKEN`).
- Os campos são achados pelo nome: nome, e-mail, telefone/WhatsApp e UTMs, inclusive nas perguntas da Respondi e no `field_data` da Meta. As demais respostas ficam no cadastro da pessoa (`extras.formulario`).
- **Campanha pelo utm_campaign do canal**. Ordem de prioridade:
  1. a UTM que veio no formulário;
  2. a UTM do endereço da página;
  3. a `utm_campaign` do endereço da função.

  Quem já está cadastrado ganha um toque de captura e, se já estava na campanha, soma em "repetidas".
- Campanha → Captação e metas: botões **Receber leads de formulários** e **Religar leads**.
  - Receber leads de formulários: gera uma chave só para leads, monta o endereço por canal e traz o código do formulário e o passo a passo para Respondi e Meta.
  - Religar leads: liga à campanha os leads que chegaram antes de o canal existir.
- **Chaves com escopo**: a chave de leads só grava leads; a de ideias só grava ideias. A lista de Ideias pelo ChatGPT mostra só as chaves de ideias.
- Banco:
  - migração `20261018100000_leads_por_chave.sql`, já aplicada em produção (`supabase/RODAR_v0.113_leads.sql` fica para registro);
  - funções `chave_api_criar_escopo`, `chave_api_ws_escopo`, `lead_por_chave` e `campanha_religar_leads`;
  - `chaves_api.escopo` aceita 'ideias', 'leads' e 'vendas'.
- Edge function `leads`, publicada sem verificação de JWT, em dois arquivos: `index.ts` e `campos.ts` (leitura dos campos).
- Vendas pelo Conta Azul: ainda não feito. O Conta Azul não envia avisos (webhooks), então será uma busca agendada com login OAuth do app de desenvolvedor (ver decisões).

## [0.112] - 2026-10-17 — Escola Aurora: empresa fictícia com lançamento em captação (sem mudança de tela)
- **`supabase/RODAR_escola_aurora_1_dados.sql` + partes 2 a 4 (imagens)**: cria o workspace **Escola Aurora** no banco real para testar as telas com dados coerentes. Não mexe nos outros workspaces.
  - Histórico de julho a 16/10: perpétuo, lançamento de setembro, contratos de mentoria, despesas, recebimentos e reembolsos, tudo pelos fluxos reais.
  - **Lançamento Formação Fluência · Nov/26** (lançamento clássico) em captação:
    - R$ 20 mil de tráfego na aquisição, em 7 campanhas de anúncio no Meta, Google e TikTok, mais Instagram orgânico e e-mail;
    - 31 anúncios com imagem do criativo e métricas diárias de 01 a 16/10;
    - cerca de 3 mil leads, grupo VIP e pesquisa de qualificação;
    - estratégia em blocos e 27 metas (por canal, público, semana e conversão).
- Criativos simulados (marca fictícia): 35 imagens, em `supabase/seed/escola_aurora/criativos/`.
- Testado num banco montado do zero, com as funções de produção.
- Achados ao usar os dados (detalhe em decisões e pendências):
  - três números de "leads" para a mesma campanha;
  - a meta diária de leads do Dashboard da campanha é dividida pelos 46 dias da campanha, não pelos 26 da captação;
  - as metas por tipo marcam "fora" sem considerar o ritmo;
  - 24 funções do repositório estão diferentes das de produção.

## [0.111] - 2026-10-17 — Consistência das métricas (correção dos achados críticos e altos da auditoria)
- **Um lucro só**: Dashboard, Dashboard financeiro, Custos e margens e Growth Model mostram o mesmo lucro do mês. Na empresa da auditoria, setembro: R$ 2.228,66 nas quatro telas (antes: R$ 2.229, R$ 33.302 e −R$ 29.844).
- **Custos e margens**:
  - receita, impostos e taxas do mês vêm da contabilidade (DRE, competência), não mais das contas a receber pelo vencimento;
  - tabela por produto com receita, impostos e taxas lançados, e depois mídia e demais despesas até o lucro;
  - imposto e taxas só são estimados quando nada foi lançado no mês, e aparecem marcados como "estimado";
  - "A receber no mês" continua, separado, no bloco "Quanto preciso vender";
  - o custo de entrega por produto virou um quadro próprio: é premissa das projeções e não entra no real (o gasto real já está nas contas lançadas).
- **Regime, alíquota e % de taxas no Cadastro da empresa** (antes ficavam no navegador). O seletor de Custos e margens grava no cadastro; vale em todas as telas e computadores. Só administradores mudam. O Cadastro da empresa ganhou anexo do Simples, alíquota manual e % de taxas variáveis.
- **Growth Model**:
  - os custos fixos voltaram a aparecer (estavam sempre zerados por um erro no formato do mês);
  - nos meses fechados, impostos e taxas são os lançados; o custo de entrega real já está nas contas;
  - o regime vem do Cadastro da empresa;
  - o cenário mexe por cima do real.
- **Dashboard (Administrativo)**: vendas aprovadas, receita bruta, taxas e impostos respeitam o período escolhido (antes somavam todo o histórico). Datas em horário de Brasília: venda depois das 21h não cai mais no dia seguinte. Rótulos: "Receita bruta das vendas" e "Receita líquida das vendas".
- **Dashboard financeiro**: "Receitas, Despesas e Resultado no período" seguem o período escolhido (antes: sempre o mês de hoje).
- Banco: migração `20261012500000_consistencia_metricas.sql`, para rodar com `supabase/RODAR_v0.111_consistencia.sql`. Nova função `dre_resumo`.
- Testes: `tests/auditoria/consistencia.sql` (banco) e `tests/auditoria/t111_consistencia.py` (19 verificações de tela no banco completo).

## [0.110] - 2026-10-17 — Auditoria de consistência (sem mudança de tela)
- **Auditoria**: mesma empresa fictícia, mesmo período (setembro/2026), números de cada tela comparados.
  - A empresa fictícia foi criada pelos fluxos reais do banco.
  - O front real foi ligado a um banco local completo.
  - 26 comparações: 3 críticas, 6 altas, 10 médias, 3 baixas e 4 que batem.
  - Resultado na planilha `Growths_auditoria_consistencia.xlsx` e em `tests/auditoria/`.
- **Principais achados (ainda não corrigidos nas telas)**:
  - O lucro do mesmo mês aparece como R$ 2.229 (Dashboard/DRE), R$ 33.302 (Growth Model) e −R$ 29.844 (Custos e margens).
  - O regime de imposto e a % de taxas ficam no navegador.
  - "Receita do mês" tem quatro definições.
  - O Dashboard (Administrativo) ignora o período em vendas e receita bruta.
  - O Dashboard financeiro mostra sempre o mês de hoje.
  - Há três CACs de mídia, três LTVs e dois ROAS para o mesmo mês.
- **Repositório × produção**: o banco não podia ser montado do zero a partir do repositório.
  - Cinco funções e uma coluna existiam só em produção.
  - Migrações novas que só sincronizam: `20261010235000_registrar_recebimento_parcial.sql` e `20261012400000_sincroniza_producao.sql`. Não mudam nada em produção e não precisam ser rodadas lá.
- Sem mudança no `index.html`.

## [0.109] - 2026-10-16 — Ideias de conteúdo pelo ChatGPT
- **Ideias pelo ChatGPT**: você fala ou dita a ideia num GPT do ChatGPT no celular, e ela entra no **Planejamento de conteúdo**, na coluna **Ideia**. Vem com título, ângulo, formato, tema (escolhido entre os temas cadastrados) e canais.
- Novo botão **Ideias pelo ChatGPT** no Kanban do Planejamento de conteúdo, com o passo a passo:
  1. Gerar a chave. Ela aparece uma vez só e pode ser revogada.
  2. Copiar as instruções do GPT.
  3. Copiar o esquema da ação e colar a chave na autenticação Bearer.
  4. Usar o GPT no celular.
- A tela lista as chaves com o último uso, a quantidade de usos e o status.
- O cartão que veio da IA mostra o selo **pela IA**.
- Funciona pelo microfone de ditado. O modo de conversa por voz do ChatGPT ainda não executa ações de GPTs.
- Banco: migração `20261012300000_ideias_chatgpt.sql`, para rodar com `supabase/RODAR_v0.109_ideias_chatgpt.sql`.
  - Tabela `chaves_api`, que guarda só o hash da chave.
  - Funções `chave_api_criar`, `chave_api_revogar`, `ideia_por_chave` e `ideias_por_chave_contexto`.
- Edge function `ideias` (sem verificação de JWT, autenticada pela chave do Growths), já publicada no projeto:
  - `GET` devolve temas, formatos, canais e as últimas ideias;
  - `POST` grava uma ideia, ou até 10 de uma vez.
- Testes:
  - `tests/banco/ideias_base.sql` e `ideias_cenarios.sql`;
  - `tests/edge/` (a função contra o Postgres local);
  - `tests/tela/t109_ideias_chatgpt.py`.

## [0.108] - 2026-10-16 — Growth reorganizado
- **Menu Growth com 6 itens**: Diagnóstico Growth, Growth Model, Pesquisas, Ciclo de Growth (Kanban), Resultados e aprendizados e Guardrails.
- **Growth Model** tem duas abas, **Planilha** e **Cenários**. Na aba Cenários o menu continua marcando Growth Model.
- **Unit Economics** saiu do sistema: não está mais no menu nem nas abas. Margem, impostos, custos e lucro já estão na Planilha.
- **Análise de funil** saiu do sistema: não está mais no menu, e o botão "Abrir na Análise de funil" da campanha também saiu.
- Links antigos para essas duas telas abrem a Planilha. O código antigo ficou no arquivo, sem uso, para dar para voltar se precisar.
- **Pacotes de acesso**: Unit Economics, Análise de funil, Cenários (que segue o Growth Model), Cohorts e Ascensão (que viraram Retenção & Expansão) não aparecem mais para ligar ou desligar.
- Sem migração.
- Testes:
  - `t96_retirada.py` foi aposentado, porque testava só o Unit Economics.
  - `t81`, `t98`, `t100` e `t107` foram ajustados ao menu novo.
  - `t90` deixou de depender da data de hoje.

## [0.107] - 2026-10-16 — Cenários: ciclo de vida e histórico
- **Menu Growth**: "Growth Loops" passa a se chamar **Growth Model** (a planilha). Nova tela **Cenários** ao lado, também como aba no topo: Growth Model · Cenários · Unit Economics.
- **Status do cenário**:
  - Em estudo: você está mexendo.
  - Descartado: você decidiu não fazer agora.
  - Aprovado: foi para o Kanban e ainda não está no ar.
  - Ativo: o card está em Em teste ou Análise.
  - Encerrado: o card foi concluído.
  - Cancelado: o card parou antes de ir ao ar.
  - Depois de aprovado, o status segue o card do Kanban sozinho.
- **Descartar** (no lugar de excluir; nada se apaga):
  - Só para cenário em estudo.
  - Pede o motivo (ICE baixo, perdeu para outro cenário, sem verba agora, fora de época, outro), para qual cenário perdeu (opcional) e uma observação.
  - O cenário sai da lista da planilha. Dá para **Reabrir** em Cenários.
  - No modo detalhado, "Arquivar" virou "Descartar".
- **Planilha**: a lista de cenários mostra só os vivos (em estudo, aprovados e ativos, com "ativo desde"). O lucro projetado de cada cenário em estudo fica guardado para o histórico.
- **Tela Cenários**, o banco de testes:
  - Abas por status com contagem, busca (nome, hipótese, observação) e filtro por produto.
  - Por cenário: status, ICE, período ativo (datas e semanas), lucro projetado, decisão e resultado ou motivo do descarte.
  - Botões: Abrir na planilha, Descartar, Reabrir, Ver aprendizado, Ver card e Documentação ↗.
- **Card do Kanban**: novo campo **Link da documentação** (Notion, Drive…), ao lado do aprendizado escrito. Sem https://, ele é completado. O link aparece em Cenários e em Resultados e aprendizados.
- Migração `20261012200000_cenarios_ciclo.sql`, para rodar com `supabase/RODAR_v0.107_cenarios.sql`.
  - Adiciona `gm_cenarios.descarte` e `growth_experimentos.link_doc`.
  - A trava do cenário aprovado passa a barrar também o descarte.
  - Registra a tela `gro-cenarios` no catálogo de acesso.
- Testes: `tests/banco/cenarios_ciclo.sql` e `tests/tela/t107_cenarios.py`.

## [0.106] - 2026-10-15 — Growth Model em formato de planilha
- **Uma planilha de cima a baixo**:
  - Colunas: **Real + projeção (travado)**, **Cenário (onde você mexe)** e **Efeito**.
  - Mexeu numa célula, o resto da coluna Cenário e o topo recalculam. Exemplo: o preço sobe, a receita sobe, o imposto acompanha a receita, a margem e o lucro mudam.
  - **Amarelo** = o que você mexeu; **azul** = o que mudou por consequência; **tracejado** = dá para mexer e ainda está igual ao real.
- **Topo fixo**: receita, impostos, margem de contribuição, lucro, margem de lucro e lucro por mês. O real fica em cima e o cenário embaixo.
- **Resultado do período**:
  - Linhas: receita, impostos, taxas e custos variáveis, custo de entrega, margem de contribuição, mídia, aquisição sem mídia, custos fixos, lucro, margem de lucro e lucro por mês.
  - Dá para mexer no regime de imposto (e na alíquota, se manual), na % de taxas variáveis e no total de custos fixos do período.
- **Por venda, um bloco por produto**:
  - Linhas: vendas, preço (ticket médio), imposto, taxas e custo de entrega por venda, margem de contribuição por venda (R$ e %) e no período.
  - Dá para mexer no preço e no custo de entrega (% do preço e R$ por cliente). O preço vale para todos os loops do produto, salvo um loop com ticket próprio.
- **De onde vêm as vendas**: cada loop ou campanha é uma seção que abre com todas as etapas para mexer, como antes.
- **Comparar cenários salvos**:
  - O real e até 3 cenários lado a lado, cada um dizendo o que mexeu. O melhor resultado de cada linha fica em verde.
  - Inclui guardrails projetados, hipótese e notas do ICE (impacto, confiança, facilidade) guardadas no cenário, com o ICE calculado.
  - Botões "Abrir" e "Aprovar e levar para o Kanban" (documento de decisão e ideia no Kanban, como já existia).
- Novo cenário, Duplicar, Nome e hipótese e Limpar mudanças no topo. Limpar zera etapas, preços, custos, regime, taxas e fixos do cenário.
- A aba Unit Economics continua igual, e Mais opções continua com o modo detalhado.
- Sem migração: o financeiro do cenário fica em `gm_cenarios.financeiro`. Teste de tela: `tests/tela/t106_growth_planilha.py`, que substitui o `t103`.

## [0.105] - 2026-10-15 — RevOps → Retenção & Expansão
- **Nova tela RevOps → Retenção & Expansão**, no lugar de Cohorts e Ascensão da escada (os endereços antigos abrem as abas novas). Três abas com os mesmos filtros: período da primeira compra, produto e categoria de entrada, canal de aquisição, campanha, origem (utm_source), segmento RFM, e visão consolidada ou por produto de entrada. Visões salvas por pessoa.
- **Análise de Coortes**:
  - Indicadores: clientes únicos, 2ª compra em 30, 60, 90, 180 e 365 dias, tempo médio e mediano até a 2ª compra, receita acumulada, receita por cliente, % da receita de clientes existentes, margem de contribuição e % com 2 ou mais compras.
  - Coorte que ainda não completou o prazo mostra "indisponível", com o parcial no detalhe.
  - Curva D0–D365 com uma linha por coorte (até 8, escolhidas na tabela), marcadores em D30/60/90/180/365 e ponto clicável.
  - Matriz de coortes: % com 2ª compra acumulado, receita acumulada por cliente ou % que comprou no período. Intervalo mensal, trimestral ou anual.
- **Análise de Recompra**:
  - Indicadores: clientes com 1ª e 2ª compra, taxa de recompra, intervalo médio e mediano entre compras, frequência, ticket de recompra, receita da 2ª e da 3ª em diante e margem das compras recorrentes.
  - Gráficos: curva acumulada, distribuição do tempo até a 2ª compra, receita de novos × existentes por mês (com a conferência do financeiro) e ranking dos produtos de 2ª compra.
  - Papel de cada produto de entrada (expande, recompra moderada, não expande) e matriz de transição de produtos.
- **Segmentação RFM**:
  - Notas de 1 a 5 por quintis ou por limites, com data de referência (dá para ver a base como estava antes) e janela configurável.
  - Sete segmentos padrão, com regras editáveis por workspace. Para cada segmento: clientes, % da receita, ticket, frequência, receita por cliente, margem, produtos mais comprados e dias desde a última compra.
  - Grade R×F e cruzamento com produto, campanha, canal ou origem.
- **Investigar**: indicadores, pontos, barras, células e segmentos abrem a lista de clientes com o histórico de compras e exportação em CSV.
- **Regras** (decididas em 15/10):
  - Contrato recorrente: só contrato novo é recompra.
  - Compras do mesmo dia são um pedido.
  - Reembolso não conta; a coorte começa na próxima compra válida.
- **Banco**: `produtos.categoria`, `revops_config`, `revops_visoes` e as funções `revops_itens`, `revops_pedidos`, `revops_receitas`, `revops_clientes`, `revops_rfm_clientes`, `revops_coortes`, `revops_recompra`, `revops_rfm` e `revops_clientes_de`.
- Migração `20261012100000_revops_retencao.sql`, para rodar com `supabase/RODAR_v0.105_retencao.sql`. Testes: `tests/banco/retencao_base.sql` + `retencao_cenarios.sql` e `tests/tela/t105_retencao.py`.

## [0.104] - 2026-10-13 — Cenário vale em qualquer filtro de produto
- Um número mudado no cenário com "Todos os produtos" aparece também quando você filtra o produto do loop, e o mudado com um produto filtrado aparece em "Todos os produtos". Vale na tela simples e no modo detalhado (cenários, mês a mês, comparador).
- Os ajustes passam a ser gravados por loop, sem produto. Ajustes antigos feitos com um produto filtrado continuam valendo e têm prioridade até serem mudados de novo.
- Sem migração. Teste de tela: `t103_growth_simples.py` ganhou os dois casos.

## [0.103] - 2026-10-13 — Growth Model simplificado
- **Growth → Growth Loops abre numa tela só**: escolha o período (De / Até; padrão: o ano inteiro), o produto (ou todos) e a campanha.
- **Topo fixo** enquanto você rola: Receita, Investimento em mídia, CAC mídia, CAC sem mídia, Custo de entrega, Lucro, Margem de lucro e ROI do período. Quando há mudança no cenário, cada indicador mostra também o valor do cenário e a diferença.
  - CAC sem mídia: custos das contas marcadas em "Entra no CAC" (equipe, ferramentas, comissões, outros), sem a mídia, ÷ clientes novos.
  - Custo de entrega: custo do produto cadastrado em Custos e margens (% da receita + valor por cliente).
  - Lucro: receita − mídia − CAC sem mídia − custo de entrega − taxas − impostos − demais custos fixos. Com filtro de produto ou campanha, os custos fixos e o CAC sem mídia são rateados pela participação na receita.
  - ROI: lucro ÷ tudo o que foi gasto.
- **Loops do período** embaixo, cada um abre e fecha. Cada etapa (investimento, CPM, impressões, CTR, cliques, conversões, vendas, ticket, receita) tem três colunas: Real (ou Real + projeção), Cenário e Efeito. Do lado, a receita do loop mês a mês: real, projeção e cenário.
- **Cenário**: o número digitado vale para todos os meses do loop, inclusive os que já passaram ("e se o CTR do lançamento tivesse sido 2,5%?"). O investimento é digitado como total do período. A primeira mudança cria um cenário em rascunho sozinho; "Novo cenário" e "Limpar mudanças" ficam no topo. "Ajustar mês a mês" leva para a grade por mês.
- **Mais opções** (fechado): cenários detalhados (mês a mês, ICE e aprovação, guardrails, histórico, premissas), Modelo de 12 meses, Mapa de métricas e North Star, Calculadora de campanha e Importar planilha. Nada foi removido.
- Sem migração. Teste de tela: `tests/tela/t103_growth_simples.py`; `t98_growth_model.py` agora entra no modo detalhado por Mais opções.

## [0.102] - 2026-10-12 — Visual azul em degradê, modo claro e modo escuro
- **Novo visual**: azul-marinho com degradê azul → ciano no lugar do vinho. O item aberto do menu, o botão principal, o título da página e o sublinhado das abas ficam em degradê; o fundo tem duas luzes azuis que se movem devagar.
- **Movimento ao passar o mouse**: no menu, um brilho em degradê entra da esquerda e o ícone anda e acende; os indicadores sobem um pouco e ganham borda em degradê; botões sobem um pouco.
- **Modo claro e modo escuro**: botão "Modo claro" / "Modo escuro" no rodapé da barra lateral. A escolha fica guardada no navegador (cada pessoa, em cada computador). No modo claro o conteúdo fica em fundo branco e a barra lateral continua azul-marinho em degradê.
- Quem pediu menos movimento no sistema operacional não vê as animações.
- Cores fixas de vinho espalhadas pelo código (mapas de calor, funil, hover de tabela, indicador da North Star) passaram a seguir a cor do tema. Primeira cor dos gráficos do Dashboard Growth agora é azul.
- Sem migração. Teste de tela: `tests/tela/t102_visual.py`.

## [0.101] - 2026-10-11 — Growth Model: telas novas visíveis
- **Correção de navegação**: as fases B, C e D (cenários, cabeçalho Produto × Consolidado, ICE, aprovação, documento de decisão e guardrails projetados) foram construídas na tela de simulação por loop, que não tinha entrada no menu: o menu Growth → Growth Loops abria só o modelo de 12 meses. Agora o Growth Model tem abas visíveis: **Cenários e simulação** (abre primeiro), **Modelo de 12 meses**, **Mapa de métricas e North Star** e **Calculadora de campanha**.
- O banco de produção já estava com todas as atualizações (v0.80 a v0.100) aplicadas; esta versão só muda a tela.
- Teste de tela `t98_growth_model.py` agora começa pelo caminho do menu.

## [0.100] - 2026-10-11 — Growth Now, fase D (guardrails e aprendizados)
- **Correção no arquivo único (11/10, 12h)**: o SQL Editor do Supabase parou em "registrar_recebimento: trecho não encontrado". A busca do trecho na v0.86 (`20261010240000_cartao_e_receber_avulso.sql`) era literal, com quebra de linha; ao colar, o editor pode trocar a quebra de linha (\n por \r\n). Agora a busca ignora espaços e quebras de linha. Conferido contra a função de produção, nas duas formas. Como o arquivo roda numa transação, a tentativa anterior não gravou nada: é só rodar o arquivo novo.
Com esta versão, as 4 fases da especificação "Growth Now / Growth's Brain v1.0" estão no Growths.
- **Guardrails** (Growth → Guardrails → Cadastro): limite mínimo ou máximo de margem, lucro, ROAS, CAC mídia, CPL, mídia, receita, vendas, leads, conversão ou ticket; severidade (atenção ou crítico), negócio ou recorte, produto, janela de leitura, frequência, ação sugerida e se segue no acompanhamento contínuo. Margem e lucro são "só projeção" (não há leitura diária real deles).
- **Fase 1 — projetados no Growth Model**: painel "Guardrails projetados" no cenário, com baseline, projetado, limite, severidade, situação (dentro, perto do limite, fora), evidência, confiança e recomendação. É estimativa, não alerta. O comparador mostra quantos guardrails cada cenário rompe. Na aprovação, guardrail crítico rompido exige a justificativa do risco e vai para o documento de decisão.
- **Fase 2 — monitoramento real** (Growth → Guardrails → Testes em andamento): quando um card entra em **Em teste**, os guardrails ativos (gerais e do produto do cenário) são ligados a ele (dá para ajustar em "Guardrails do teste"). Para cada um: **antes** (janela anterior ao início), **durante** (do início até hoje) e **depois** (janela após a conclusão), limite, situação e variação durante × antes. As leituras ficam registradas por dia.
- **Alertas**: rompeu durante o teste → alerta (um aberto por teste e guardrail) com a ação sugerida, ligado ao teste e à hipótese. Reconhecer (quem está cuidando) e resolver (o que foi feito). **Nada é pausado automaticamente.**
- **Acompanhamento contínuo**: guardrails marcados como contínuos são lidos sempre, sem depender de teste (para quando a mudança vira rotina).
- **Resultados e aprendizados** (Growth → Resultados e aprendizados): para cada teste em análise ou concluído, baseline × projeção do cenário × realizado (proporcional aos meses que já passaram), alertas que aconteceram, aprendizado e a decisão — **Escalar, Iterar ou Interromper** (os nomes da decisão no experimento mudaram para esses).
- Migração `20261012000000_guardrails.sql` (testada num Postgres local: `tests/banco/guardrails_base.sql` + `guardrails_cenarios.sql`, depois da v0.98 e v0.99). Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.100.sql`. Teste de tela: `tests/tela/t100_guardrails.py`.

## [0.99] - 2026-10-11 — Growth Now, fase C (decisão e Kanban)
- **ICE no cenário** (botão ICE na barra do Growth Model): impacto, confiança e facilidade de 1 a 10, score = média, com justificativa, evidências e premissas.
- **Aprovar cenário** (só administrador): exige hipótese e ICE; mostra receita e lucro incrementais, inputs alterados e os guardrails projetados; pede responsável e próximos passos. Se houver guardrail crítico violado, exige a justificativa do risco (o score alto não esconde o risco). A aprovação **congela** o cenário e gera o **documento de decisão** imutável: contexto, hipótese, baseline × projeção (negócio e recorte), inputs (baseline e cenário mês a mês), premissas financeiras, riscos, ICE, responsável e próximos passos. Botão **Documento de decisão** abre e imprime/salva em PDF.
- **Ideia no Kanban sem duplicar**: a aprovação cria a ideia (já priorizada) ligada ao cenário; o botão "Ideia no Kanban" cria ou mostra a que já existe (um cenário = uma ideia, garantido no banco).
- **Kanban em 7 colunas**: Ideias → Em avaliação → Priorizadas → Preparação → Em teste → Análise → Concluídas / Arquivadas. Os cards que existiam mantêm a etapa ("Rodando" agora se chama Em teste). Cards mostram se vieram de cenário e se viraram planejamento.
- **Desenho do teste** no experimento: tipo (experimento ou planejamento), métrica-alvo, público, intervenção, instrumentação, custo previsto e justificativa do ICE, além de janela, critério de sucesso, leitura e aprendizado que já existiam. Botões **Abrir o cenário** e **Converter em planejamento** (cria o projeto da iniciativa em Projetos, com lista de atividades e prazos; não duplica).
- Migração `20261011900000_decisao_kanban.sql` (testada num Postgres local: `tests/banco/gm_base.sql` + v0.98 + `decisao_base.sql` + `decisao_cenarios.sql`). Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.99.sql`. Teste de tela: `tests/tela/t99_decisao_kanban.py`.

## [0.98] - 2026-10-11 — Growth Now, fase B (Growth Model)
O Growth Loops evoluiu para o Growth Model da especificação.
- **Cenários nomeados**: cada cenário tem nome, hipótese, autor, contexto (produto, campanha, etapa, loop, período), situação (rascunho, aprovado, arquivado) e versão. **Novo**, **Duplicar** (cria a versão seguinte com as mesmas alterações), **Detalhes**, **Arquivar**. Escolher um cenário reabre o contexto dele; se o filtro atual for diferente, aparece o aviso e o botão para voltar ao contexto do cenário.
- **Baseline travado**: meses passados são o real e a projeção é a média do real com as **premissas do baseline**. Só um administrador abre "Premissas do baseline", diz o motivo e muda; cada mudança fica na auditoria. As 34 alterações que já existiam no baseline do Demo viraram premissas.
- **Cenário aprovado fica congelado** (no banco): para mudar, duplica.
- **Cabeçalho financeiro duplo e fixo**: **Recorte selecionado** (o filtro) × **Negócio consolidado** (todos os produtos e loops), com baseline, cenário e diferença (R$ e %) de receita, mídia paga, impostos, custos variáveis, custos fixos (do financeiro, sem a mídia, rateados pela receita no recorte), lucro e margem. Sem filtro, mostra que o recorte é o próprio consolidado.
- **Custos e premissas financeiras do cenário** (recolhido por padrão): regime, alíquota, % de custos variáveis e ajuste de custo fixo por mês. Custo muda lucro e margem, nunca a receita.
- **Inputs × resultados**: só os pontinhos azuis (volume inicial, taxas, ticket) são editáveis; receita, compras e leads são calculados (ƒ). Alterações aparecem em verde. Validação de limites (sem negativo, taxa até 100%).
- **Desfazer / Refazer**, **Restaurar baseline neste cenário** e **Histórico** (quem mudou o quê e quando).
- **Comparar cenários**: baseline + até 3 cenários com receita e lucro incrementais, investimento adicional, custos, margem, compras, ROAS (receita ÷ mídia), CAC mídia (mídia ÷ compras), hipótese, ICE e contexto; marca o de maior lucro e o de maior receita. Cenário com contexto diferente fica bloqueado, a menos que você marque "Normalizar".
- **Unit Economics usa os mesmos cenários**: os dados do simulador ficam dentro do cenário do Growth Model; escolher o cenário numa aba vale na outra.
- **Rótulos corrigidos**: "ROI (receita ÷ investido)" virou **ROAS (receita ÷ mídia)** e "CAC (investido ÷ compras)" virou **CAC mídia**.
- Migração `20261011800000_growth_model_cenarios.sql` (testada num Postgres local: `tests/banco/gm_base.sql` + `gm_cenarios.sql`). Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.98.sql`. Teste de tela: `tests/tela/t98_growth_model.py`.
- Limite conhecido: a simulação é por loop (campanha, orgânico, upgrade, recompra, contratos); a quebra por execução de canal aparece nos dados da campanha, mas ainda não é simulada separadamente.

## [0.97] - 2026-10-11 — Growth Now, fase A (cadastros)
Base da especificação "Growth Now / Growth's Brain v1.0": ofertas, esteira e campanhas.
- **Ofertas independentes** (Cadastros → Produtos → Ofertas): uma oferta é um produto **ou um pacote** (bundle) com quantidade e **% da receita de cada produto** (soma 100%, para a receita ficar certa por produto sem duplicar), preço, condições, parcelamento máximo, vigência e situação (rascunho, ativa, pausada, encerrada).
- **Versões**: mudar nome, preço, condições, parcelamento ou produtos cria uma versão nova (v1, v2…); o botão **Versões** mostra o histórico, que não pode ser alterado. A campanha guarda a versão da oferta que usou.
- **Esteira de ofertas da campanha** (aba Ofertas da campanha): uma oferta principal e quantos order bumps, upsells, downsells e cross-sells quiser, cada um com **etapa anterior**, condição (**sempre / se aceitou / se recusou**), onde aparece, quem pode receber, gatilho e premissas de **exposição** e **aceite**. Mostra a esteira em árvore.
  - Validações (na tela e no banco): uma principal por campanha; etapa anterior da mesma campanha; **sem ciclos**; downsell só depois de uma **recusa**; order bump só no checkout da principal; avisos para oferta sem etapa anterior ou que perdeu a etapa anterior.
  - **Aceite real com o denominador certo**: quem recebeu a oferta (compradores da etapa anterior; no downsell, quem recusou), não todos os compradores.
  - **Simulação da esteira**: receita = quem recebeu × exposição × aceite × preço, com o total e a receita por produto (pacotes repartidos pela alocação).
- **Campanha híbrida, só paga ou só orgânica** (padrão híbrida). Canais ganham tipo pago/orgânico. Cada canal da campanha vira uma **execução**: tipo, **estratégia** daquela execução, custo de produção/operação (separado da mídia) e observações. Campanha só paga não aceita execução orgânica (e vice-versa).
- **Várias estratégias por campanha** (painel "Estratégias da campanha" em Planejamento e metas); a principal acompanha a estratégia da campanha.
- **North Star**: evento que conta, população elegível, frequência, fonte e produto (vazio = empresa); aparece na árvore de métricas.
- **Calculadora de campanha**: **receita deixou de ser editável** (é vendas × ticket). CAC, ROAS, vendas e investimento continuam editáveis (decisão da Rebecka).
- Migração `20261011700000_ofertas_esteira_campanha.sql` (testada num Postgres local: `tests/banco/ofertas_base.sql` + `ofertas_cenarios.sql`). Arquivo único: `supabase/RODAR_TUDO_v0.80_a_v0.97.sql`. Teste de tela: `tests/tela/t97_ofertas_campanha.py`.

## [0.96] - 2026-10-11
- **Growth → Unit Economics → 7. Meta de retirada**: planejamento de quanto os sócios querem tirar por mês e quanto a empresa precisa faturar para isso, mantendo a lucratividade do negócio.
  - **Retirada dos sócios**: uma linha por sócio (vem dos pró-labores lançados no financeiro, com o valor de hoje ao lado); você digita quanto quer tirar e vê o total para a casa. Pode incluir ou remover sócios. Não muda o pró-labore do financeiro.
  - **Custos da empresa sem pró-labore**: puxados do Contas a pagar e das recorrências do mês escolhido (respeitando o que foi desmarcado em Custos e margens), com um campo de ajuste para o que ainda não está lançado.
  - **Imposto e custos da venda**: regime (MEI, Simples pelo fator R, anexo III, anexo V ou alíquota) e % de custos variáveis.
  - **Margem que deve sobrar no negócio** em três cenários definidos por você: **mínima**, **muito boa** e **ótima** (começam em 10%, 20% e 30%).
  - Resultado por cenário: quanto precisa faturar no mês, imposto, lucro que fica na empresa, se é possível com o que há para receber (ou quanto falta), **retirada possível** com o que já está para receber e quantas vendas a mais de um produto cobrem a diferença. Mais a tabela dos próximos 6 meses no cenário muito bom.
  - Fica salvo junto com o cenário do Unit Economics (botão Salvar), sem virar lançamento.
- Sem migração nova. Teste de tela: `tests/tela/t96_retirada.py`.

## [0.95] - 2026-10-11
- **Cenários ruim, bom e ótimo** para a margem de lucro líquida, definidos por você na tela **Custos e margens** (o bom é a meta; padrão 20%, 30% e 40% até você mudar). O ruim precisa ser menor que o bom, e o bom menor que o ótimo.
  - Situação do mês: **Abaixo do ruim**, **Ruim**, **Bom** ou **Ótimo**, e quanto de lucro falta para o próximo cenário.
  - Tabela dos três cenários: margem, quanto vender no mês, lucro e quanto falta em relação ao que há para receber no mês (com "você está aqui").
- **Planejamento da empresa**: todo índice pode ter **cenário ruim** e **cenário ótimo** (a meta continua sendo o cenário bom); aparecem no formulário e embaixo da meta na tabela.
- Migração `20261011600000_cenarios_indicadores.sql` (`plano_indicadores.faixa_ruim` e `faixa_otimo`). Até ela rodar, o bom (meta) já fica no Planejamento e o ruim e o ótimo ficam salvos no navegador. Arquivo único agora: `supabase/RODAR_TUDO_v0.80_a_v0.95.sql`.
- Teste de tela `tests/tela/t94_margens.py` cobre os cenários; teste de banco `tests/banco/margens_cenarios.sql` cobre a migração.

## [0.94] - 2026-10-11
- **Margens e meta** na tela Financeiro → **Custos e margens** (novo nome do Custo operacional; na Casa, "Custos do mês"):
  - **Margem de contribuição por produto**: receita do mês (contas a receber; contrato → itens do contrato, venda → produto; o resto em "Sem produto"), menos imposto sobre a venda, taxas da venda (%) e custo do produto. O custo do produto é informado na própria tabela: **% da receita** e/ou **R$ por cliente no mês** (gravado em `produtos.extras`).
  - **Lucro líquido e margem de lucro líquida** do mês: contribuição − custos fixos do mês (no MEI, o DAS entra como custo fixo).
  - **Meta de margem de lucro líquida** (padrão 30%) com a situação **Dentro da meta / Abaixo da meta** e quanto falta (em lucro ou em vendas no mês). A meta fica guardada no **Planejamento da empresa**, como indicador "Margem de lucro líquida" do plano ativo; sem plano ativo, fica só no navegador.
  - O ponto de equilíbrio passa a considerar o custo dos produtos e a receita para a meta substitui a "margem desejada".
- **Planejamento da empresa**: dois indicadores automáticos novos, **Margem de contribuição (%)** e **Margem de lucro líquida (%)**, calculados pela DRE do período (`valor_indicador`).
- **Dados da Mathisa**: criado no "Plano estrategico 2026" o objetivo "Operar com margem de lucro saudável" com o indicador "Margem de lucro líquida", meta 30%.
- Migração `20261011500000_margens_indicadores.sql` (chaves novas em `plano_indicadores`, `valor_indicador` com as margens e o indicador já criado passa a usar a chave). Testada num Postgres local (`tests/banco/margens_cenarios.sql`). Arquivo único agora: `supabase/RODAR_TUDO_v0.80_a_v0.94.sql`.
- Teste de tela: `tests/tela/t94_margens.py`.

## [0.93] - 2026-10-11
- **Financeiro → Custo operacional** (e **Casa → Custo mensal**): quanto custa manter a empresa no mês escolhido. Junta tudo o que está no Contas a pagar com competência no mês e as recorrências ativas que ainda não foram lançadas (aparecem como "projetado"). Pedaços de um mesmo pagamento (ex.: pró-labore pago em partes) viram um item só.
  - Cada item tem tipo: **fixo** (recorrente), **variável** (recorrente marcada como variável, ex.: luz), **parcelado** (com o mês da última parcela) ou **pontual**. Dá para desmarcar o que não deve contar (ex.: o webdesigner); a escolha fica salva no navegador.
  - Cartões: custo do mês, pró-labores (o que vai para casa), operação sem pró-labore, fixo, variável, parcelado e pontual. Gráfico por área (centro de custo), por conta contábil ou por tipo.
  - **Quanto preciso vender**: ponto de equilíbrio e receita para a margem de lucro desejada, com custos variáveis da venda (%) e o regime tributário da simulação: MEI (DAS de R$ 86,05 e limite de R$ 81.000/ano, com aviso quando estoura), Simples Nacional com anexo pelo fator R, anexo III, anexo V ou alíquota informada. O seletor é só simulação: não muda o cadastro nem as vendas.
  - **Comparação entre regimes** lado a lado e **próximos 12 meses** (custo, pró-labores, operação, a receber e diferença).
- **Simulador de lucro → Puxar do financeiro**: troca os custos fixos da simulação pelos do mês atual do Contas a pagar, agrupados por conta e já com categoria (sem os pontuais e sem o que foi desmarcado no Custo operacional).
- **Correções nos dados da Mathisa** (feitas no banco, com cancelamento e relançamento; nenhum lançamento apagado): Claude e Servidor N8N saíram de "Mídia paga – Google Ads" para "Ferramentas e software" (contas de nov e dez e as recorrências); Servidor N8N foi para Sucesso do cliente; as 11 parcelas do Scale Mentoring foram para Administrativo; o "Tablet — 11/2026" que sobrou da recorrência parada foi cancelado.
- Migração `20261011400000_custo_operacional.sql` (só põe a tela no catálogo de acesso e nos pacotes com Contas a pagar). O arquivo único agora é `supabase/RODAR_TUDO_v0.80_a_v0.93.sql`.
- Teste de tela: `tests/tela/t93_custo_operacional.py`.

## [0.92] - 2026-10-11
- **Dashboard principal clicável**: no Dashboard (Administrativo), os cartões **Saldo em banco**, **A receber** e **A pagar** agora abrem o extrato da conta (com as transações e o saldo linha a linha) e as listas de contas a receber e a pagar do período do dashboard. Antes só o dashboard do Financeiro era clicável.
- **Saldo do banco**: diagnóstico no banco de produção (11/10/2026): nenhuma das migrações v0.80 a v0.91 tinha sido rodada. Por isso o Cartão de Crédito (fatura de R$ 188,41) ainda é descontado do "Saldo em banco" (R$ 1.924,23 − 188,41 = R$ 1.735,82). Rodando as migrações, o cartão sai do saldo e passa a aparecer como fatura: Saldo em banco = R$ 1.924,23 (Conta Mathisa Rogerio).
- **Arquivo único com todas as migrações pendentes**: `supabase/RODAR_TUDO_v0.80_a_v0.91.sql`, substituído na v0.93 por `RODAR_TUDO_v0.80_a_v0.93.sql` (v0.80, v0.81, v0.83, v0.85, v0.86, v0.87, v0.88, v0.89, v0.90, v0.91 em ordem, numa transação só: se algo falhar, nada é gravado). Os trechos que alteram funções existentes foram conferidos contra o banco de produção antes da entrega.
- Teste de tela: `tests/tela/t92_painel_clicavel.py`.

## [0.91] - 2026-10-11
- **Projeto automático da campanha virou opcional.** Na campanha nova, "Criar o projeto da campanha agora" vem marcado, com o modelo padrão já escolhido (dá para trocar o modelo). Desmarcado, nenhum projeto é criado; depois ele pode ser criado pelo botão Projeto da campanha, com qualquer modelo, ou um projeto existente pode ser vinculado.
- Migração `20261011300000_projeto_auto_opcional.sql` (colunas `campanhas.projeto_auto` e `campanhas.projeto_modelo_id`; gatilho `campanha_cria_projeto` respeita as duas). Testada num Postgres local (`tests/banco/projeto_auto_cenarios.sql`). Teste de tela em `tests/tela/t90_projetos.py`.

## [0.90] - 2026-10-11
- **Tags em projetos e atividades** (separadas por vírgula, gravadas em minúsculas) e filtros: na lista de projetos por tag e responsável; dentro do projeto por situação (abertas, atrasadas, bloqueadas, liberadas, em andamento, concluídas, todas), responsável e tag.
- **Projetos → Todas as atividades**: atividades de todos os projetos abertos, com filtros de situação, responsável (inclusive "sem responsável"), projeto e tag, e botões Iniciar e Concluir.
- **Painel do projeto**: gráfico de andamento (planejado pelo prazo × concluído, dia a dia), situação das atividades e tabela por responsável com abertas, bloqueadas, concluídas e atrasadas. Calculado no banco (`projeto_painel`).
- **Datas no projeto em destaque**: no formulário, data de início (obrigatória) e de fim vêm logo depois do nome, em campo maior; a data de fim não pode ser antes do início.
- **Salvar como modelo**: o projeto vira um modelo com atividades, subatividades, dependências, funções, responsáveis e prazos em dias a partir do início (opção de virar o modelo padrão das campanhas).
- **Projeto ↔ campanha**: o projeto pode ser vinculado (ou trocado, ou desvinculado) a uma campanha aberta, no formulário ou pelo botão "Vincular campanha"; ao vincular, entram as atividades dos blocos da estratégia. Na campanha, o botão "Projeto" mostra os projetos vinculados, vincula um projeto aberto ou cria um projeto a partir de um modelo, já com as atividades do modelo e dos blocos.
- **Meta de CPL**: na campanha (formulário e quadro "Meta e realizado") e em cada canal da campanha, junto com a meta de leads do canal. O quadro de canais mostra leads contra a meta e o CPL do canal contra a meta de CPL (verde dentro, vermelho fora), calculados no banco (`campanha_canais_resultado`).
- Migração `20261011200000_projetos_tags_modelos.sql` (rodar depois da v0.89). Testada num Postgres local (`tests/banco/projetos2_base.sql` + `projetos2_cenarios.sql`). Teste de tela `tests/tela/t90_projetos.py` (27 checagens).

## [0.89] - 2026-10-11
Fase 2 da comparação com o Growth's do Rogério (captação e vendas). Decisões de 10/10: atribuição grava primeiro e último toque e os painéis usam o último; ROAS oficial é o bruto; mesmo telefone junta sozinho.
- **Lead por campanha**: cada pessoa participa uma vez de cada campanha, com data de entrada, se era aluno ou já cliente na hora, canal, público e UTMs (`campanha_participacoes`, preenchida pela jornada e pelo histórico).
- **Duplicidade de captação**: nova tentativa de cadastro de quem já entrou soma em "repetidas" e não cria lead novo. `registrar_captura` é a porta de entrada única (formulários, importação, integrações).
- **Junção automática**: quando chega telefone + e-mail e o e-mail está num cadastro sem telefone, os dois viram um só (fica o do telefone), com histórico.
- **Público frio e quente** no canal da campanha (e no anúncio). Meta Ads frio e quente viram dois canais com a sua utm_campaign; sem classificação, nada é inferido.
- **Atribuição explícita**: toda venda aprovada guarda primeiro e último toque, com canal, público, UTMs, peso, versão da regra e evidência (`venda_atribuicoes`). Painel "Vendas por canal" (dashboard de vendas e aba da campanha) com vendas, clientes, receita, investimento, CAC e ROAS bruto, e troca para primeiro toque. Canal sem dado de mídia mostra "sem dado", não zero.
- **Aceite de ofertas**: order bump, upsell, downsell e cross-sell mostram a taxa de aceite (vendas da oferta ÷ vendas das principais). `vendas.pedido_ref` para agrupar itens do mesmo pedido.
- **Abandono de checkout** (Vendas → Abandono de checkout): registro (manual ou integração, sem duplicar pelo ID externo), recuperação automática quando a mesma pessoa compra o produto em até 30 dias, taxa de recuperação.
- **Metas por tipo** (aba "Captação e metas" da campanha): investimento, leads, leads qualificados, vendas, conversão, receita, ticket, CPL, CAC, ROAS, impressões e cliques, para a campanha toda ou por fase, canal, público, segmento (alunos, não alunos, já clientes) e período, com realizado, % e dentro/fora. Meta zero não gera %.
- Dicionário: ROAS bruto oficial; novas definições de atribuição, duplicidade, aceite e recuperação de checkout.
- Migração `20261011100000_fase2_captacao_vendas.sql` (rodar depois da v0.88). Testada num Postgres local (`tests/banco/fase2_base.sql` + `fase2_cenarios.sql`). Teste de tela `tests/tela/t89_fase2.py` (16 checagens).

## [0.88] - 2026-10-11
Fase 1 da comparação com o Growth's do Rogério (segurança e confiança do dado). Documento da comparação: "Growths × Growth's do Rogério — comparação e plano".
- **Identidade da pessoa pelo banco**: telefone e e-mail normalizados (`telefone_norm`, `email_norm`), telefone único por workspace, `pessoa_resolver` (acha pelo telefone, depois pelo e-mail, senão cria). A importação de clientes também ignora quem já tem o mesmo telefone. Erros de cadastro repetido aparecem em português.
- **Cadastros repetidos** (Configurações → Comercial e produtos): pares com o mesmo nome e contatos compatíveis; "Juntar" passa vendas, contratos, alunos, notas, listas, jornada e pesquisas para o cadastro que fica e guarda o removido em `pessoas_mesclagens`.
- **Venda sem duplicar**: plataforma + ID externo únicos. **Evidência na venda**: e-mail e telefone do comprador como estavam, aprovada em, reembolsada em, cancelada em, origem do dado; não mudam depois de gravados.
- **Auditoria** (Configurações → Pessoas e acessos, só administradores): quem incluiu, alterou ou excluiu, com antes e depois, em 22 tabelas (vendas, contas, contratos, campanhas, fechamentos, pessoas, acessos, plano de contas…). Ninguém altera nem apaga.
- **Indisponível não é zero**: métricas diárias de anúncio, vídeo, etapas da campanha e conteúdo ganham disponibilidade (completo, parcial, indisponível) e "atualizado na origem".
- **Qualidade do dado**: 10 verificações no banco (vendas sem origem, venda diferente do a receber, mais cliques que impressões, métricas parciais, dias sem dado de mídia, mídia dos anúncios × financeiro, leads sem origem, cadastros repetidos, estimativas vencidas, integração atrasada), com tolerância por cliente. Os dashboards (financeiro, Casa, painel, marketing, mídia, tráfego, vendas) mostram a faixa de avisos e marcam com ⚠ os cartões afetados. Tela Configurações → Qualidade dos dados.
- **Dicionário de métricas**: definição oficial de 16 indicadores (fórmula, fonte, o que acontece sem dado). ⓘ nos cartões dos painéis e tela Configurações → Dicionário de métricas.
- **Fechamento oficial versionado**: fechar de novo pede motivo e cria V2; a V1 fica guardada como substituída. Fechamento não pode ser alterado nem apagado; guarda a qualidade do dado no momento. A aba Fechamento mostra as versões.
- **Extrato calculado no banco** (`extrato_conta`).
- Migração `20261011000000_fase1_confianca_dado.sql` (rodar depois da v0.87). Testada num Postgres local (`tests/banco/fase1_base.sql` + `fase1_cenarios.sql`). Teste de tela `tests/tela/t88_fase1.py` (19 checagens).

## [0.87] - 2026-10-10
- **Casa vira um módulo dentro da Mathisa — Operação** (grupo "Casa" no menu, logo abaixo do Financeiro): Dashboard, Contas a receber, Contas a pagar, Lançamentos contábeis, Contas bancárias e cartões, Plano de contas, Fornecedores, Formas de pagamento e Centros de custo, todos da Casa. A Casa tem livro contábil próprio: plano de contas, bancos, lançamentos e contas separados; nada dela entra nos números da empresa, e nada da empresa entra nos dela. Ela some do seletor de workspace e da lista de clientes; só quem é membro da Casa vê o grupo.
- **Transferência da empresa para a Casa** (botão na faixa da Casa): escolhe a conta a pagar da empresa que está sendo paga (o pró-labore aparece primeiro; valor menor vira pagamento parcial) ou "retirada" contra uma conta contábil (ex.: 3.1.02 Distribuição de lucros), a conta da empresa de onde sai, a conta da Casa onde entra e a receita da Casa. Cada lado lança no seu livro; a Casa recebe como conta a receber já recebida. Lista de transferências no dashboard da Casa, com Desfazer (estorna os dois lados; o pró-labore volta a uma conta só).
- Dentro da Casa, os atalhos do financeiro (Contas a receber, Contas a pagar…) continuam na Casa; ao clicar num item do Financeiro, volta para a empresa.
- Migração `20261010250000_casa_modulo.sql` (rodar depois da v0.86): `workspaces.casa_de`, liga a Casa à operação, tabela `transferencias_casa`, `transferir_para_casa`, `desfazer_transferencia_casa`. Testada num Postgres local (`tests/banco/casa_base.sql` + `casa_cenarios.sql`: pagamento parcial do pró-labore, retirada, nenhuma partida cruzando os livros, desfazer os dois lados). Teste de tela `tests/tela/t87_casa.py` (20 checagens).

## [0.86] - 2026-10-10
- **Dashboard financeiro clicável**: "Saldo em banco" abre o **extrato** (saldo anterior, cada entrada e saída com saldo corrido, saldo final; troca de conta e de período; botão Lançamento em cada linha). "A receber" e "A pagar" abrem a lista de todas as contas (em aberto + atraso, só atraso, recebidas/pagas ou todas do período), com cliente/fornecedor, situação, conta e lançamentos. Clicar numa linha de "Saldo por conta bancária" abre o extrato dela. Botão "Extrato" no topo.
- **Cartão de crédito não é mais saldo em banco**. Contas bancárias ganham o tipo *Conta* ou *Cartão de crédito* (e o dia de vencimento da fatura). Cartão fica fora do "Saldo em banco", do caixa projetado e do "saiu" do painel gerencial. Pagar uma conta escolhendo o cartão tira a conta do a pagar e coloca na fatura; o dinheiro só sai do banco ao **pagar a fatura** (novo painel "Cartões de crédito" no dashboard, com Ver fatura e Pagar fatura). Recebimento não pode cair no cartão. O "Cartão de Crédito" da Mathisa é marcado como cartão pela migração (pelo nome e pela conta contábil 2.1.01.02).
- **Contas a receber avulsas** (sem venda nem contrato): salário, reembolso, aluguel… com conta de receita, conta prevista e opção de repetir por 2, 3, 6 ou 12 meses. A receita entra na baixa (débito banco, crédito na receita escolhida). Filtro "Só avulsas" e botão Cancelar.
- **Workspace "Casa"** para as finanças pessoais, com só a Rebecka como membro (ela adiciona quem quiser): plano de contas com receitas da casa (salários, outras) e despesas da casa (moradia, contas de consumo, mercado, transporte, saúde, educação, lazer, assinaturas, manutenção, outros) e a "Conta da casa". Nenhum cliente vê: acesso é só por membro. Pacote de acesso novo **Casa** (só o financeiro e os cadastros financeiros), aplicado a ele pela migração.
- **Projeto ↔ campanha**: em Novo projeto, marcar "Projeto de campanha" cria a campanha (rascunho, com nome, início, fim, estratégia e produto) e usa o projeto que a campanha gera, sem duplicar. Toda campanha com estratégia em blocos ganha, no projeto, uma atividade por bloco com subatividades do tipo dele (ex.: Tráfego pago → públicos e orçamento, criativos, configurar campanhas, acompanhar; Aula → roteiro, apresentação, sala, ensaio, lembretes), com responsável pela função da equipe. Botão "Atividades dos blocos" no projeto gera para campanhas antigas.
- Migração `20261010240000_cartao_e_receber_avulso.sql` (rodar depois da v0.85). Testada num Postgres local (`tests/banco/cartao_*.sql`, `projetos_base.sql`); teste de tela `tests/tela/t86_financeiro_projetos.py` (34 checagens).

## [0.85] - 2026-10-10
- **Pacotes de acesso por cliente** (Configurações → Pessoas e acessos → Pacotes de acesso dos clientes, só para a equipe interna). A equipe monta pacotes marcando as telas liberadas (por módulo e por tela) e escolhe um pacote para cada cliente; "Ajustar telas" liga ou desliga telas só para aquele cliente. Pacotes iniciais: Consultoria (tudo), Mentoria (sem o financeiro) e Disparo (marketing, mídia, leads e funil comercial), para ajustar.
- O menu do cliente mostra só as telas liberadas e a tela fora do pacote não abre. No banco, módulo sem nenhuma tela liberada fica "nenhum" para todos do cliente (nivel_modulo), inclusive administradores. Configurações e Cadastros nunca são bloqueados no banco; "Equipe e acessos" e "Funções e permissões" ficam sempre liberadas. As funções e permissões de cada pessoa continuam valendo por cima do pacote.
- "Novo cliente" já pergunta o pacote. Cliente sem pacote continua vendo tudo.
- Migração `20261010230000_pacotes_acesso.sql` (rodar depois da de segurança). Testada num Postgres local: recusa quem não é da equipe interna, telas inválidas, pacote no workspace da agência e exclusão de pacote em uso.

## [0.84] - 2026-10-10
- Menu Growth mostra os dois modelos como itens: **Growth Loops** e **Unit Economics** (antes só "Growth Model", com as abas dentro). As abas no topo continuam.

## [0.83] - 2026-10-10
- **Desfazer pagamento de baixa parcial junta com o saldo.** Se o saldo que a baixa parcial gerou ainda está em aberto, as duas partes são canceladas (com estorno na data da competência, sem mexer na despesa do mês) e nasce uma conta única com o valor inteiro. Se o saldo já foi pago, a parte desfeita volta sozinha, como antes. Funciona em cadeia (várias baixas parciais desfeitas de trás para frente).
- Nova coluna `contas_pagar.saldo_de` liga o saldo à conta que o gerou; contas antigas ligadas pela migração. Migração `20261010220000_desfazer_parcial_junta_saldo.sql` (rodar depois da de segurança).
- Tela: o aviso de "Desfazer pagamento" explica a junção, e a mensagem final diz quando juntou.
- Testado num Postgres local com as funções contábeis de produção (`tests/banco/`).

## [0.82] - 2026-10-10
- **Growth Model com duas abas:** **Growth Loops** (o modelo de volume: aquisição, retenção e vendas, mês a mês) e **Unit Economics** (o simulador de lucro da v0.81: margem, CAC, LTV, payback e caixa). O menu Growth passa a ter um item só, "Growth Model"; as duas abas usam a permissão do módulo Growth.
- Dados: pró-labore de outubro (Mathisa — Operação) refeito como uma conta de R$ 10.000 em aberto, depois de baixa parcial desfeita e cancelada (ver decisões e pendências).

## [0.81] - 2026-10-10
- **Growth → Simulador de lucro** (Growth Profit Simulator, especificação de 10/10/2026). Seis abas: Negócio (horizonte, margem-alvo, modo de custos, imposto padrão, rateio, custos fixos), Produtos (N produtos, cobrança à vista, parcelada ou recorrente com churn, reembolso, custos no modo simplificado ou completo, trazer do cadastro), Aquisição (canais com mídia, outros custos, leads × conversão ou clientes, produto de entrada), Jornada (transições A → B com probabilidade, defasagem e limite de compras), Cenários (conservador, otimista e customizado editáveis, ROAS fixo com mídia constante, eficiência da mídia, sensibilidade) e Resultados (Negócio, Produto, Jornada e coorte, Caixa, Comparação).
- Indicadores: receita bruta e líquida, contribuição, margem de contribuição e operacional, CAC mídia e total, ROAS da 1ª compra e da jornada, LTV de contribuição, payback de contribuição e de caixa, CAC mídia máximo, orçamento máximo de mídia, ROAS de equilíbrio e alvo, ascensões necessárias e conversão mínima, capital de giro. N/D quando não há mídia ou clientes.
- Alertas: margem negativa, CAC máximo negativo, ascensão acima de 100%, caixa negativo, janela curta, divergência entre os modos de custo, transição ou canal suspenso, ciclo sem defasagem.
- Cenários salvos no banco (`simulador_cenarios`) com fotos (`simulador_snapshots`) que guardam premissas, resultados e a versão da fórmula (gps-1.0); exportação CSV e JSON. Sem a migração, salva no navegador e avisa.
- Motor de cálculo em funções puras (`gps*`), testado com o exemplo de referência da especificação e os testes de aceite T01 a T14.
- Revisão independente das fórmulas achou 9 defeitos, todos corrigidos e cobertos por teste: jornada lenta (exponencial) e corte silencioso em 12 níveis; CAC mídia e ROAS contando clientes orgânicos; conversão mínima errada com assinatura defasada e com limite de compras; ROAS-alvo 0x com produto de entrada gratuito; corte de mídia acima de 100% gerando lucro; ciclo no mesmo mês cortando transições demais; itens vazios quebrando o cálculo. LTV passa a ser o da primeira coorte; renovações fora do horizonte somadas até a duração.
- **Blocos de estratégia** (fase 1 do plano de 09/10): a estratégia é montada com 14 blocos prontos em 4 colunas (Aquisição, Aquecimento, Conversão, Retenção): Conteúdo Instagram, Tráfego pago, Página de captura, Indicação, Grupo de WhatsApp, Disparo pela API, E-mail, Pesquisa, Aula/webinário/evento, VSL, Checkout, Comercial, Recompra e ascensão, Assinatura. Cada bloco traz as métricas, com uma principal e as de diagnóstico, e a fonte de cada uma.
- Adicionar, duplicar (Aula 1 → Aula 2...), renomear, mover, desligar (na campanha) e remover blocos; ligar o vídeo ou o grupo real; trocar a métrica principal; adicionar métricas.
- Na campanha, o funil aparece agrupado por bloco e a conversão anda só pelas métricas principais. Modelos prontos passam a criar blocos; duplicar a estratégia copia os blocos.
- Migração `20261010200000_blocos_e_simulador.sql`. Sem ela, estratégias e campanhas continuam como na v0.77.

## [0.80] - 2026-10-08
- **Segurança, fase 1 (auditoria de 08/10/2026).** Migração `20261008230000_seguranca_fase1.sql`.
- Nenhuma função do banco pode ser chamada sem login, exceto a pesquisa pública (`pesquisa_publica`, `pesquisa_responder`). Funções criadas daqui em diante nascem fechadas para quem não está logado.
- `sincroniza_acesso` exige login e administrador (antes, sem login, a checagem não rodava).
- `_provisionar_prolabore`, `equipe_avisa`, `projeto_do_produto` e `provisionar_workspace` não podem mais ser chamadas direto; continuam funcionando por dentro (gatilhos e `criar_workspace_cliente`).
- As 32 operações que gravam (pagamentos, recebimentos, lançamentos, contratos, parcelas, listas, projetos, pesquisas, conteúdo) exigem "Consultar e editar" no módulo certo, pela nova `pode_editar(ws, módulos)`. Antes bastava ser membro do workspace. Financeiro → fin; contratos, parcelas, venda e estorno → vendas ou fin; listas → mkt ou vendas; cliente histórico → vendas ou revops; projetos → prj (e mkt para os de campanha); pesquisas → gro ou mkt; ideias e presença em vídeo → mkt.
- Trava no banco: conta a pagar com valor estimado não pode ser paga (substitui a migração pendente `20261006500100`).
- Front: o menu Growth Starter não define mais a permissão de telas que pertencem a outros módulos (`moduloDaView`). Login sem workspace não cria mais workspace sozinho; mostra como pedir acesso.

## [0.79] - 2026-10-08
- **Growth Model: topo de funil sempre presente.** Os loops de aquisição mostram o funil completo (Investimento, Impressões, CPM, Cliques, CTR, Visitas, Connect rate, Leads, conversões, Clientes, Receita, ROAS, CPL, CAC) mesmo sem dado de mídia, com Baseline e Cenário editáveis. Inspirado no modelo da Fernanda ("Marketing growth model – Adaptado").
- **Onde o cálculo começa:** a cadeia do cenário parte do primeiro passo com cenário preenchido; se não houver, do primeiro passo com dado real. Assim um loop orgânico (só clientes e receita) continua com os números reais, e ao preencher investimento, CPM e as taxas, o funil inteiro é simulado.

## [0.78] - 2026-10-08
Growth Model: simular com o Cenário ficou possível e visível.
- **Abre direto no produto:** o modelo abre no primeiro produto, e não mais em "Todos", que não tinha nada editável. A visão de todos os produtos virou o botão "Visão geral" (só o sumário).
- **Campos do Cenário à vista:** cada campo editável tem borda tracejada, mostra o valor real formatado como referência e aceita "2,5", "1.500", "R$ 10.000" ou "3%". O valor que você muda fica destacado, e a diferença também aparece no sumário.
- **Alavancas novas:** além das taxas e do ticket, agora entram o investimento por mês (ou o primeiro passo do loop, como a base de clientes), o CPM, o CPL e o CAC. A partir dos custos, impressões, leads ou clientes são recalculados a partir do investimento, e o resto do funil segue em cadeia.
- **Projeção dos meses sem dados:** os meses depois do último mês real são projetados com a média e as taxas reais (no Baseline) ou com as alavancas do cenário (no Cenário), e aparecem em itálico. Dá para desligar em "Projetar os meses sem dados". Com a projeção ligada, Baseline e Cenário comparam os mesmos 12 meses.
- **Ao mudar um campo do Cenário**, os meses passam para o modo Cenário sozinhos. Também há o botão "Limpar cenário deste produto".

## [0.77] - 2026-10-08
Parte 1 do projeto "Estratégias, Campanhas e Growth Model" (especificação aprovada em 08/10).
- **Cadastro de estratégias** (Cadastros → Estratégias e funis, antes "Funis, etapas e listas"): cada estratégia desenha o funil em quatro fases (Aquisição, Aquecimento, Conversão, Retenção). Cada etapa tem unidade, origem do dado (anúncios, leads, etapa do Kanban, lista ou grupo, vídeo, vendas e contratos, disparo, manual), papel no sumário e taxa esperada.
- **Modelos prontos:** Lançamento clássico, Perpétuo, Webinário, Disparo de WhatsApp, Recompra e renovação, Comercial e Social selling. Também dá para duplicar uma estratégia.
- **Catálogo de etapas:** as etapas são as mesmas em todas as campanhas, para comparar e somar. Uma etapa criada na hora entra no catálogo do cliente.
- **Kanban da jornada:** continua como estava. "Chegou à etapa X do Kanban" passou a ser uma das origens do dado.
- **Campanha escolhe a estratégia:** estratégia e produto são obrigatórios em campanha nova. Ao salvar, as etapas são copiadas para a campanha; mudar a estratégia depois não mexe no histórico.
- **Aba Estratégia e etapas da campanha:**
  - funil etapa por etapa no período: volume, taxa sobre a etapa anterior, taxa esperada, diferença e custo por pessoa;
  - lançamento de números por dia, para etapas manuais, de disparo ou sem item escolhido;
  - etapas só desta campanha: acrescentar, tirar, ligar ou desligar, reordenar;
  - datas das fases e reaplicar a estratégia.
- **Dashboard da campanha:** ganhou o bloco "Funil etapa por etapa".
- **Jornada do lead:** cada ponto de contato vira um registro (entrada, etapa da jornada, lista ou grupo, vídeo, comercial, compra, nova compra). Os registros são gravados sozinhos e o histórico que já existia foi copiado. A ficha do lead mostra a primeira origem, o último clique, quantos contatos houve até a compra e a linha do tempo.
- **Último clique:** a venda guarda o canal e a UTM de fechamento, e o formulário de venda pede a campanha e o canal que fecharam. A primeira origem continua no cadastro do lead.
- **Growth Model:** upgrade não conta mais como cliente novo e ganhou a linha "Total de upgrades" no sumário (também no resumo do Diagnóstico).
- **Versão no menu lateral:** o rodapé do menu mostra "Versão 0.77 · 08/10/2026", para conferir qual arquivo está aberto.
- **Banco:** migração `20261008220000_estrategias_jornada.sql` (ainda não aplicada no Supabase). Sem ela, as telas novas avisam que falta rodar o SQL.

## [0.76] - 2026-10-08
- **Growth Model: colunas Baseline e Cenário na própria tabela**, logo depois da Unidade, como na planilha (Un. | Baseline | Cenário | Mês 1…12 | Total). Sem trocar de tela.
- Baseline = valor real (taxa do período; para volumes, média mensal; na planilha importada, a coluna D dela). Cenário = campo editável nas taxas (CTR, connect rate, conversões, CPM, ticket); na planilha importada vem da coluna E.
- Chave **Meses mostram: Baseline (real) / Cenário** recalcula os meses e o sumário com as taxas do cenário (as demais taxas seguem o real). O sumário mostra Baseline e Cenário lado a lado.
- Cenários dos loops do sistema ficam salvos em `gm_modelos.dados.cen`; nos importados, em cada passo (`b`, `c`). Sem mudança de banco.
- Limite: o cenário recalcula só os meses que já têm dados reais; projeção para meses futuros fica para a próxima versão.

## [0.75] - 2026-10-08
### Mudou
- **Menu Growth reorganizado**: Diagnóstico Growth, Growth Model, Análise de funil, Pesquisas e Ciclo de Growth. As abas internas do Growth Model saíram; a tela antiga de cenários e alavancas continua no código, sem atalho no menu.
- **Diagnóstico Growth** (antes "Dados do cliente"): mesma tela de importar, diagnosticar e baixar. Ao clicar em **Salvar no Growth Model**, abre o Growth Model daquele cliente.
- **Growth Model no formato da planilha**: uma tabela só, letras iguais, sem caixas. Sumário, depois "Loop 1", "Loop 2"... com os passos e as taxas, Mês 1 a Mês 12 e Total. Cabeçalho e coluna de nomes ficam fixos ao rolar.
### Adicionado
- **Cliente que você já alimenta no sistema**: o Growth Model aparece sozinho, montado com as campanhas, vendas, recompras e contratos dele, sem importar nada. O Mês 1 é o primeiro mês com dado (dá para escolher outro em "Começar em"). Meses sem dado aparecem como "—".
- Loops manuais em cima dos dados do sistema, por produto, com números editáveis (ficam salvos no modelo do cliente).
- Se o cliente tem dados no sistema e também um modelo importado, aparecem os dois botões "Dados do sistema" e "Modelo importado".
- Cliente sem nada: botão "Montar o modelo manualmente" cria o modelo vazio (Produto 1), com "+ Produto", "Renomear produto" e "+ Adicionar loop".
### Limites
- Nos loops que vêm do sistema os números não se editam (mudam nos cadastros). Só os loops manuais e o modelo importado são editáveis.

## [0.74] - 2026-10-08
### Mudou
- **Growth Model refeito.** Saíram da tela a North Star Metric e a Calculadora de campanha (o código e os dados continuam no sistema, para reestruturar depois). A tela agora tem três abas: **Modelo (12 meses)**, **Dados do cliente** e **Cenários e alavancas (do sistema)** (a tela anterior, mantida).
### Adicionado
- **Dados do cliente**: sobe várias planilhas de uma vez (.xlsx, .xls, .csv), mesmo bagunçadas (título solto no topo, colunas em qualquer ordem, datas e valores em formatos diferentes, abas ocultas). O sistema identifica o que é cada uma (vendas, leads, investimento e anúncios, ou a planilha já no formato do Growth Model), sugere as colunas e você corrige.
- Conferência antes de consolidar: Mês 1 (o primeiro mês com dado do cliente), canais de cada loop, nomes de produto (use o mesmo nome para juntar), quais status contam como venda, prazo para considerar renovação e para onde vão leads e investimento sem produto.
- Classificação automática de cada venda em nova, renovação, upgrade ou repetida, pelo e-mail/CPF/telefone do comprador. A origem da venda vem da coluna de origem ou do lead com o mesmo e-mail.
- **Diagnóstico do que falta**: 13 itens (vendas, identificação do comprador, produto, status, recompra/renovação, leads, origem da venda, investimento, topo do funil, qualificação, período, qualidade, custos) com situação Tenho/Parcial/Falta, por que importa e o que pedir ao cliente. Cobertura por mês. Mensagem pronta para o cliente (copiar). Download do diagnóstico (.txt) e da **planilha padronizada** (.xlsx) com Vendas, Leads, Investimento, Resumo mensal e Diagnóstico.
- **Modelo (12 meses)** no formato da planilha: Sumário (total investido, clientes novos, clientes renovados, receita total, cumulativo, ROI), premissas e um painel por loop, com filtro por produto (cada produto tem a sua visão) e a visão de todos. Taxas (CPM, CTR, connect rate, conversões, ticket, ROAS, CPL, CAC) calculadas. Números ajustáveis na tela, salvos sozinhos.
- **Personalização**: adicionar loops a partir de modelos (tráfego pago, compra direta, funil comercial, e-mail, orgânico, social selling, upgrade, renovação, personalizado), editar passos (remover, reordenar, criar passo próprio), mudar o papel do loop no sumário e excluir loop.
- Importa a planilha já estruturada (como a `growth_model_info`): cada aba vira um produto e cada bloco "Loop" vira um loop. Conferido contra o Sumário da planilha: 133 de 144 valores iguais; as 11 diferenças são "Clientes novos" do High Ticket (a planilha não soma upgrades ali; o sistema soma, como no Produto principal).
### Banco
- Nova tabela `gm_modelos` (JSON por cliente, provisória): migração `20261008170000_gm_modelos.sql`, já aplicada.
### Limites
- Cohorts e curvas de renovação ainda não entram. Qualificação de lead só entra quando vier nos dados. Projeção e cenários sobre o modelo novo ficam para a próxima etapa.

## [0.73] - 2026-10-08
### Adicionado
- **Campos de moeda com máscara**: todo campo de valor em reais mostra `R$ 1.234,56`, com ponto de milhar e vírgula decimal, enquanto você digita. Vale para os formulários (valor, preço, orçamento, metas em R$, taxas fixas, saldo inicial, desconto), para a calculadora do Growth Model e para os campos de valor dentro de tabelas. Campos de quantidade, percentual e pontuação não mudam.
- Os limites mínimo e máximo continuam valendo (ex.: desconto não passa do valor da parcela), agora com mensagem em reais.
### Técnico
- O sistema continua guardando e enviando o número puro (`1234.56`); a máscara só muda o que aparece na tela.

## [0.72] - 2026-10-08
### Adicionado
- Growth Model, aba "Modelo por loop": botão **Importar planilha**. Lê o .xlsx do Growth Model (aba "Produto principal" por padrão, ignora abas ocultas), separa os blocos "Loop N" e as premissas gerais, e mostra cada linha com Baseline e Cenário. Você escolhe o loop de destino e a alavanca de cada linha (já vem sugerido: investimento, CPM, CTR, connect rate, visita→lead, qualificação, conversão e ticket). Baseline vira baseline, Cenário vira cenário, a partir do mês escolhido. Opção de usar o investimento mês a mês da planilha.
- Depois de importar, a vista abre no Cenário e o painel "De onde vem a melhoria na receita" já mostra o efeito de cada alavanca.
### Limites
- O loop de destino precisa existir no sistema (vem de campanhas, vendas e contratos). Linhas calculadas da planilha (totais, ROAS, cohorts) são ignoradas.

## [0.71] - 2026-10-08
### Adicionado
- Growth Model, aba "Modelo por loop": painel **De onde vem a melhoria na receita**. Mostra, para cada alavanca mexida no cenário, quanto de receita e de compras ela gera sozinha sobre o baseline, o % do ganho, o efeito combinado (alavancas que se multiplicam) e o ganho total. Aparece nas vistas de cenário e comparação.

## [0.70] - 2026-10-08
- **Calculadora de campanha**: corrigido o caso em que "não calculava". Se você preenchia primeiro um campo calculado (meta de vendas, receita, CAC, investimento ou ROAS) antes de ticket, conversão, CPL e leads, o valor sumia e nada era calculado. Agora o sistema **guarda o que você digitou** (campo amarelo), avisa o que falta e calcula sozinho quando a base fica completa. Digitar direto o campo da base que ele ajusta cancela o valor guardado.
- Testado digitando tecla a tecla nas duas ordens (base primeiro e calculados primeiro): mesmo resultado (1.000 leads, 100 vendas, R$ 50.000, ROAS 5).

## [0.69] - 2026-10-08
- **Pacote para o Lovable (Growth Model)** em `lovable/growth-model/`: prompt para colar, contrato de dados e a lógica de cálculo em arquivos prontos (`growth-motor.ts`, `calculadora.ts`, `alertas.ts`), verificados contra o sistema atual. Sem mudança no banco nem no index.html.

## [0.68] - 2026-10-08
- **Desconto concedido em parcela de contrato** (Contas a receber → botão **Dar desconto**): pede valor, motivo e data. Lança **D 5.1.03 Descontos concedidos / C Contas a receber – contratos**: é dedução da receita (aparece na DRE em Deduções e reduz a margem), não despesa, e não mexe em banco. Desconto parcial diminui a parcela; desconto total tira ela do "a receber" e ela fica marcada "baixada por desconto" (não dá para reativar).
- Conta **5.1.03 – Descontos concedidos** criada em todos os clientes que já tinham o plano padrão e incluída no plano dos clientes novos.
- **Aplicado na Mathisa**: desconto de R$ 300 do Rogério na parcela 1 do contrato #10 da Anna Vitar (08/10/2026). Testado antes numa transação desfeita.
- Banco: colunas `contas_receber.desconto`, `desconto_motivo`, `desconto_em`; função `dar_desconto_parcela`; origem `desconto` em lançamentos (`20261008160000_desconto_parcela.sql` e `20261008160100_reativar_bloqueia_desconto.sql`, já aplicadas).

## [0.67] - 2026-10-08
- **Cadastro de fornecedor simplificado**: nome, CNPJ/CPF, telefone, e-mail, **endereço**, categoria, **descrição/observações** e **link do contrato de serviço**. Saiu a seção de repetição/parcelas: as contas a pagar do fornecedor são lançadas em Contas a pagar. A lista mostra documento, telefone e link do contrato.
- **Contas a pagar**: o "Total na lista" somava as canceladas quando o filtro era "Todas" ou "só canceladas". Agora o total ignora as canceladas e mostra quantas e quanto ficaram de fora. A tabela "Por fornecedor" e os KPIs já ignoravam canceladas (conferido no banco).
- Banco: colunas `fornecedores.endereco`, `observacoes`, `contrato_url` (`20261008150000_fornecedores_endereco_contrato.sql`, já aplicada). Importação de fornecedores aceita endereço e descrição.

## [0.66] - 2026-10-08
- **Alertas em vermelho no Growth Model (aba Mapa de métricas)**: a métrica automática aparece em vermelho, com o motivo, quando está pior que (1) o **benchmark do mercado** que você cadastrou, (2) a **média histórica da empresa** (3 períodos anteriores de mesmo tamanho; vermelho se mais de 10% pior) ou (3) o **período anterior** (mais de 10% pior). Painel "Chamam atenção" no topo lista tudo.
- Botão **Benchmarks do mercado**: você digita CPL, CAC, conversão, ticket e ROAS de referência, com a fonte. Em branco = sem benchmark (usa só histórico).
- CPL e CAC são sempre "quanto menor, melhor"; as demais seguem a direção da métrica.
- Banco: tabela `benchmarks_mercado` (`20261008140000_benchmarks_mercado.sql`, já aplicada; RLS por workspace e permissão).

## [0.65] - 2026-10-08
- **Calculadora de campanha** (Growth Model → aba "Calculadora de campanha"): você preenche o que souber e o resto se ajusta nos dois sentidos. Ex.: CPL R$ 10 e conversão 10% já dão CAC R$ 100; editar CAC, vendas, receita, investimento ou ROAS ajusta a base (CPL ou leads). Calcula margem prevista, ROAS planejado, de equilíbrio e ideal, CPL e CAC máximos para a margem alvo, CAC de mídia e total, ROI da empresa e vendas para equilíbrio, com o resumo "para onde vai cada real". Contas fixas no código, sem IA.
- Custos e margem editáveis: impostos, taxa, comissão, custo de entrega, margem alvo (padrão 20% do faturamento), despesa da empresa a cobrir (com atalho para a média mensal do DRE), **itens de custo que você adiciona** (fixo, por lead, por venda ou % da receita) e **canais** com meta de leads e CPL por canal.
- **Cenários**: salvar, carregar e atualizar; **Salvar metas na campanha** grava leads, vendas, conversão, CPL, CAC, receita e orçamento na campanha, e leads/CPL nos canais que já existem nela.
- **Ofertas por produto** (Cadastros → Produtos): principal, upsell, order bump, cross-sell e downsell, cada uma com preço. **Ofertas e preços na campanha** (nova aba): escolha a oferta e dê um preço só daquela campanha; a tabela registra quanto cada oferta vendeu na campanha. O ticket da calculadora vem da oferta principal.
- Banco: tabelas `ofertas`, `campanha_ofertas`, `campanha_calculos`; colunas `meta_cpl` em campanhas e campanha_canais; função `campanha_ofertas_resultado`. Migração `20261008080000_ofertas_e_calculadora.sql` (já aplicada).

## [0.64] - 2026-10-07
- **Contrato fechado é venda, contada uma vez**: a tela **Vendas** lista cada contrato como uma venda (origem Contrato, data do fechamento, produto, valor, situação do recebimento) e soma nos totais; o **Dashboard de Vendas** passa a contar contratos em vendas aprovadas, ticket médio e clientes por produto (migração `20261007200000_vendas_dashboard_contratos.sql`, já aplicada). Não é criada linha em `vendas`, então Growth Model e Painel gerencial, que já contam contratos por regra própria, não contam em dobro. Contas a receber continua mostrando as parcelas.
- **Dashboard Growth e Painel**: o Growth Model (`growth_modelo_historico`) passa a contar o contrato fechado como venda na quantidade de clientes: o primeiro contrato ou venda de uma pessoa é novo cliente de aquisição (na campanha do contrato ou orgânico) e os seguintes entram como upgrade na retenção. Só a quantidade; a receita continua vinda das parcelas, sem soma dobrada. Migração `20261007210000_growth_modelo_contrato_venda.sql` (já aplicada). Antes, contrato só aparecia como recorrência e a venda do dia não contava em novos clientes, conversão e CAC.
- Dados: recebimento de R$ 1.500 do contrato #12 (Anna Vitar), marcado como recebido por engano, foi desfeito pelo fluxo do sistema (estorno contábil e bancário). Recebido da Mathisa: R$ 3.500.
- Projeto "Growths Starter + Disparos Black Friday" criado na Mathisa (07/10 a 12/10, 10 atividades).

## [0.63] - 2026-10-07
- **Dashboard Growth e Relatório**: período **personalizado** (De/Até, em meses inteiros, porque Growth Model e DRE são mensais) e **Comparar com** escolhível: período anterior, mesmo período do ano anterior ou outro período à escolha. Os indicadores dizem contra o que estão comparando.
- **Personalizar removido** (botão, modo de edição e layout salvo). "Contas a pagar" passou a ser um dos indicadores padrão. A tabela `dashboard_layouts` fica sem uso.
- **Campos personalizados por cliente**: na importação, cada coluna da planilha "sem campo no Growths" ganha o botão **Criar campo personalizado** (nome e tipo texto/número/data). A coluna é ligada ao novo campo e os valores vão para `extras` de cada registro. Os campos criados também são reconhecidos automaticamente nas próximas planilhas.
- No cadastro de **clientes e leads**, os campos personalizados aparecem para ver e editar. Para produtos, fornecedores, campanhas e vendas, os valores entram só pela importação por enquanto.
- Banco: tabela `campos_personalizados` e coluna `extras jsonb` em pessoas, produtos, fornecedores, campanhas e vendas. Migração `20261007190000_campos_personalizados.sql` (já aplicada).

## [0.62] - 2026-10-07
- **Importar vários arquivos de uma vez, com identificação automática** (Configurações → Importar e validar dados). Você sobe os CSVs ou planilhas do cliente e o sistema olha as colunas (e o nome do arquivo) para dizer o que cada um é: clientes e leads, produtos, fornecedores, campanhas ou vendas.
  - **Verde**: identificado, sem problema; é só dar o ok (há "Dar ok em todos os verdes").
  - **Vermelho**: identificado, mas com problema (coluna obrigatória faltando ou linhas com erro, com o motivo escrito); o ok autoriza importar só o que está certo.
  - **Amarelo**: em dúvida ou não reconhecido; você escolhe o tipo e o sistema confere de novo.
  - Depois do ok, "Conferir de-para" abre a conferência campo a campo (já existente) e a importação. A fila mostra "Importado" e reavalia os demais (por exemplo, a venda só fica verde depois de importar clientes e produtos).
  - Arquivos podem ser ignorados e voltar para a fila. A fila é separada por cliente.
- Importar um arquivo só, escolhendo o tipo, continua disponível logo abaixo.
- Sem mudança no banco.

## [0.61] - 2026-10-07
- **A primeira versão do dashboard voltou como tela inicial**: o antigo "Painel gerencial" agora se chama **Dashboard** (Administrativo) e é a primeira tela ao entrar. O dashboard no desenho do conceito continua no menu como **Dashboard Growth**, com o "Personalizar".
- Os valores dos indicadores ficaram menores em todo o sistema, para não serem cortados nem quebrarem linha (ex.: R$ 17.700,00, R$ 189.600,00, -R$ 6.600,00).
- Sem mudança no banco.

## [0.60] - 2026-10-07
- **Dashboard principal mais compacto**: gráficos menores e blocos reorganizados (os pequenos preenchem as lacunas), funil sem cortar o texto.
- **Pergunte aos dados** (Administrativo e Growth Starter): chat em que a pessoa escolhe Claude ou ChatGPT e faz perguntas em português. Desenhado para a IA não inventar:
  - a IA **não consulta o banco**: a função do servidor chama `ia_contexto()`, que devolve um resumo já calculado (receita e funil por mês, mídia por canal, campanha e ângulo, receita por produto, resultado contábil e contas a pagar), com os direitos de quem pergunta e sem nome, e-mail ou telefone de ninguém;
  - regras fixas para a IA: usar só o JSON, não calcular nem inventar número, dizer "sem dado" quando faltar, e tratar nomes de campanha como simples rótulos (defesa contra instruções escondidas);
  - temperatura zero, e **todo número da resposta é conferido** contra o resumo: o que não bater aparece em vermelho com o aviso para não confiar;
  - a tela mostra os dados que a IA recebeu e as fontes usadas; cada pergunta e resposta fica registrada (`ia_perguntas`); limite de 40 perguntas por hora por pessoa.
- Banco: tabela `ia_perguntas` (RLS por pessoa) e função `ia_contexto` (`20261007180000_ia_perguntas.sql`, já aplicada). Função de servidor `perguntar` (`supabase/functions/perguntar`), já publicada, com autenticação obrigatória.
- **Para funcionar**: cadastrar os segredos `ANTHROPIC_API_KEY` (Claude) e/ou `OPENAI_API_KEY` (ChatGPT) no Supabase, em Edge Functions → Secrets. Sem a chave, a tela avisa e desabilita o provedor.
- Limites: nunca testado com a IA de verdade (sem chave); a conferência pega números inventados, mas não garante que a interpretação em palavras esteja certa, por isso o resumo fica visível.

## [0.59] - 2026-10-07
- **Dashboard de mídia** (Marketing → Dashboard de mídia; no Growth Starter, "Mídia"), no formato do Dashboard de Tráfego de referência:
  - filtros por período, atalho (7/30/90 dias), canal e campanha, com comparação automática contra o período anterior de mesmo tamanho;
  - indicadores: investimento, impressões, cliques, CTR, CPL, leads, vendas, CAC e ROAS;
  - gráfico de performance por dia ou por semana (CTR, CPL e impressões);
  - matriz de fadiga criativa (frequência × índice de CPL, com as faixas saudável, atenção, risco e crítico);
  - mapa de saturação de ângulos (tamanho = investimento, cor = índice de CPL);
  - alertas de tráfego por anúncio com ação sugerida (Pausar, Monitorar, Escalar, Manter) por regra fixa, com tendência do CTR.
- **Relatórios de mídia** por canal, por campanha, por anúncio e por ângulo, com total. Clicar numa linha de canal ou de campanha filtra o dashboard. Baixa em CSV e Excel e imprime.
- O detalhe do indicador "Investimento em mídia" do dashboard principal agora abre o Dashboard de mídia.
- Sem migração nova: usa `v_trafego_anuncio_dia`.

## [0.58] - 2026-10-07
- **Dashboard personalizável**: botão "Personalizar" no dashboard. Cada pessoa arrasta os indicadores e os blocos para mudar a ordem, oculta o que não quer (×) e traz de volta pelos botões "Ocultos". Há "Restaurar padrão", "Cancelar" e "Salvar". O layout vale só para quem salvou, em cada cliente.
- Novo indicador **Contas a pagar** (total a pagar até o fim do período, com vencidos), disponível para colocar no dashboard; o clique abre a lista.
- Botões "Abrir..." dos detalhes levam à tela mais próxima quando o cliente é Growth Starter.
- Banco: tabela `dashboard_layouts` com RLS por pessoa (`20261007170000_dashboard_layouts.sql`, já aplicada).

## [0.57] - 2026-10-07
- **Seletor de cliente só para a equipe interna**: o seletor de workspace e o botão "+ Novo cliente" só aparecem para quem é da equipe da agência. Quem é cliente vê só o próprio workspace, sem lista de outros.
- **Investimento em mídia** (total do período, com comparação e minigráfico) como novo indicador do dashboard.
- **Desempenho por canal, mês a mês**: gráfico de linhas por mês (receita, leads, investimento, vendas, CAC ou ROI, à escolha) e, embaixo, tabela com todos os canais por mês. Caixinhas escolhem os canais do gráfico.
- **Detalhes por clique**: indicadores, etapas do funil, canais e produtos abrem o detalhe, com segundo nível (produto leva às vendas; canal leva aos leads) e botão para abrir a tela de origem.
- **Ascensão da escada** como bloco do dashboard (clique abre a análise completa); entrou no menu do Growth Starter.
- Gráfico de receita e leads não despenca mais a zero nos meses futuros.
- Banco: `workspaces.agencia`, `sou_equipe_interna()`, `criar_workspace_cliente(p_nome, p_modo)` (`20261007160000_equipe_interna.sql`, já aplicada).
- Limite: `provisionar_workspace` continua chamável por qualquer usuário logado (necessário no primeiro acesso).

## [0.56] - 2026-10-07
- **Menu de Configurações agrupado**: quatro grupos com submenus dentro. Dados e integrações (importar e validar dados, integrações, uso da plataforma); Pessoas e acessos (equipe e acessos, funções e permissões); Comercial e produtos (clientes, produtos, plataformas, canais, funis, motivos de ganho e perda); Financeiro e contabilidade (plano de contas, regras contábeis, impostos, contas bancárias, formas de pagamento, fornecedores, centros de custo, rateio). Cada grupo abre e fecha, e o que você está usando abre sozinho.
- **Corrigido: erro ao criar "Funções sugeridas"**. O envio das seis funções ao mesmo tempo ia com colunas diferentes e o banco recusava as que ficavam sem "administrador" e "ações". Agora todas vão completas.
- **Importador**: linhas com conjuntos de colunas diferentes passam a ser gravadas em grupos separados (evita o mesmo tipo de erro e deixa a importação mais rápida).

## [0.55] - 2026-10-07
- **Importar e validar dados** (Configurações): sobe planilha (.csv ou .xlsx) ou texto colado e mostra o **de-para** entre as colunas do cliente e os campos do Growths. Verde = ok; amarelo = falta de um dos lados (campo opcional que não veio, valor não reconhecido, coluna do arquivo sem campo no Growths); vermelho = campo obrigatório sem dado. Cada linha tem a explicação do que falta e dá para trocar a coluna ligada. Mostra linhas prontas, com problema e já existentes, baixa as linhas com problema em CSV e só então importa. Tipos: Clientes e leads, Produtos, Fornecedores, Campanhas, Vendas. Modelo em branco para baixar.
- **Growth Starter** (consultoria): botão **+ Novo cliente** cria um banco separado, como Growth Starter ou completo. O Starter tem o menu do conceito (Dashboard, Aquisição, Vendas, Retenção, Produtos, Clientes / Alunos, Financeiro, Relatórios, Experimentos) mais Configurações para importar dados.
- **Dashboard no desenho do conceito** (também para workspaces completos, em Administrativo → Dashboard): KPIs com variação e mini-gráfico, North Star, guardrails, receita e leads no ano, desempenho por canal, funil de crescimento, insights e alertas, ações prioritárias e produtos. Período: este mês, mês passado, últimos 3 e 6 meses, este ano, comparado com o período anterior.
- **Relatório de diagnóstico** (Relatórios): resumo, canais, funil, produtos, pontos de atenção e recomendações, pronto para imprimir ou salvar em PDF.
- Banco: coluna `workspaces.modo_produto` e função `criar_workspace_starter`. Migração 20261007150000 já aplicada.
- Limites: o dashboard usa vendas e contratos (Growth Model); margem só aparece com lançamentos contábeis; guardrails vêm das metas de CAC e conversão das campanhas; vendas importadas geram lançamento contábil e conta a receber.

## [0.54] - 2026-10-07
- **Novo visual base do sistema** (conceito de UX do Growth's): tema escuro com vinho e carmim, fonte Inter, menu lateral com item ativo em destaque, cartões arredondados com borda suave, botão principal em degradê carmim, indicadores (KPIs) maiores, tabelas e formulários no mesmo estilo, fundo com brilho vinho.
- Todas as telas herdam o visual pelas cores centrais (variáveis de cor); cores fixas claras de avisos e mapas de calor foram trocadas para as do novo tema.
- Tema claro continua possível por configuração (`data-theme="light"`), na mesma paleta carmim.
- Não mudou o conteúdo nem a organização das telas. O desenho novo do dashboard principal (KPIs, North Star e guardrails, receita e leads no tempo, desempenho por canal, funil, alertas, ações prioritárias, produtos) fica para a próxima etapa.

## [0.53] - 2026-10-07
- **Regras contábeis personalizadas** (Cadastros → Regras contábeis): botão **Nova regra** para registrar um evento novo (ex.: tarifa bancária, juros, repasse a parceiro) com nome, descrição, conta de débito e conta de crédito.
- Em cada regra personalizada, **Lançar** registra o valor na data escolhida (débito e crédito da regra) e **Excluir** remove a regra (os lançamentos já feitos continuam). Os 9 eventos do sistema seguem fixos e editáveis só nas contas.
- Banco: colunas `nome` e `personalizada` em `regras_contabilizacao`; o evento personalizado tem código `x_<nome>`. Migração 20261007140000 já aplicada.
- O sistema não lança sozinho eventos personalizados (ex.: uma venda não usa a regra nova); o lançamento é feito pelo botão Lançar.

## [0.52] - 2026-10-07
- **Planejamento anual de campanhas** (Marketing → Campanhas e planejamento → Planejamento anual): linha do tempo do ano com todas as campanhas. Lançamentos mostram começo, meio e fim (e o trecho do carrinho aberto); campanhas perpétuas atravessam o ano.
- Botões **+ Lançamento** e **+ Campanha perpétua** criam a campanha já como *Planejada*; clicar numa linha abre para editar datas, produto, meta e orçamento. Dá para abrir a página completa da campanha.
- Meta de faturamento por campanha e total do ano, comparada com a meta mensal da empresa (quanto falta planejar), orçamento planejado e realizado. Meta por mês estimada: lançamento no mês em que o carrinho fecha; perpétua dividida igualmente.
- Sem mudança no banco: usa os campos que a campanha já tinha (status planejada, datas, produto, meta de receita, orçamento).

## [0.51] - 2026-10-07
- **Plano de contas por cliente**: em Cadastros → Plano de contas, o plano atual é o padrão; para cada cliente novo dá para **Importar plano do cliente** (CSV, texto colado ou Excel), **Baixar plano (CSV)** e **Contas do sistema**.
- Importação: lê código, nome (e tipo/natureza se vierem), acha a conta-mãe pelo código, sugere o tipo por grupo e mostra a prévia. Modos: **Substituir o plano padrão** (só se ainda não houver lançamentos, bancos, contas a pagar ou recorrências) e **Adicionar ao plano atual**.
- Contas do sistema: aponta fornecedores a pagar, contas a receber, receitas, taxas, impostos, bancos e pró-labore para as contas do cliente; um aviso lembra o que ainda falta.
- Banco: função `importar_plano_contas` (migração 20261007130000, **precisa ser rodada no SQL Editor**).

## [0.50] - 2026-10-07
- **Novo workspace em branco "Growths — Demo 2"** criado com a estrutura básica (plano de contas, regras contábeis, centros de custo, etapas do Kanban, motivos e canais) e sem nenhum dado, para a Rebecka começar a preencher e validar o sistema com dados reais de captação e tráfego. O Demo antigo ficou como estava.
- Todo workspace novo agora já nasce com **Pró-labore (6.2.04)** ligado a **Pró-labore e retiradas a pagar (2.1.03)** e com **Distribuição de lucros (3.1.02)**. Antes, só a Mathisa tinha essas contas. Migração `20261007120000_provisionar_prolabore.sql` (já aplicada).
- Script opcional `supabase/manutencao/limpar_demo.sql` para limpar o Demo antigo, mantendo a estrutura. Não foi rodado.

## [0.49] - 2026-10-07
- **Growth Model automático**: o Growth Model agora tem a aba **Modelo por loop**, montada sozinha com os dados do sistema (campanhas, anúncios, leads, vendas, contas a receber e contratos). Não começa do zero. O mapa de métricas e a North Star continuam na outra aba, "Mapa de métricas e North Star".
- **Loops** identificados pelo sistema: **Campanha** (uma por campanha: investimento, impressões, cliques, visitas, leads, qualificados, compras, receita), **Orgânico e direto** (leads e compras sem campanha), **Upgrade** (cliente que já comprou outro produto), **Recompra/renovação** (cliente que já comprou o mesmo produto) e **Contratos de serviço** (contratos ativos e receita das parcelas, dividida entre os produtos do contrato).
- **Filtros**: período (mês inicial e 6 a 36 meses), **produto**, **campanha**, **etapa** (aquisição até a compra ou ativação e retenção) e **loop**.
- **Real + projeção**: meses passados mostram o real. Do mês atual em diante é projeção; as taxas (CPM, CTR, connect rate, conversões, % de qualificação, ticket) e o volume inicial começam na **média dos últimos 1, 2, 3 ou 6 meses** do real. Campanha encerrada projeta zero.
- **Alavancas**: nos meses de projeção você digita por cima de qualquer taxa, custo, ticket ou do volume inicial (investimento, leads…) e tudo que depende recalcula. Botão "Todos os meses" aplica a um intervalo e pode zerar o mês seguinte (investimento de lançamento).
- **Baseline x cenário** com visão Comparar, e botão Limpar cenário. Resumo com investido, leads, compras, receita, acumulado, ROI e CAC. Painel da North Star quando a métrica for receita, leads, vendas ou investimento.
- Banco: tabela `gm_alavancas` e função `growth_modelo_historico` (regra fixa, sem IA). Migração `20261007110000_growth_model_automatico.sql` (já aplicada).
- O "Modelo de funis" da v0.48 foi retirado do menu (era uma tela separada, em branco). As tabelas `gm_funis`, `gm_etapas`, `gm_valores` e `gm_config` ficaram sem uso e não foram apagadas.

## [0.47] - 2026-10-07
- **Filtro de período nos Lançamentos contábeis**: seletor Este mês (padrão), Mês passado, Últimos 30/90 dias, Este ano, Tudo ou Escolher datas, com contagem de lançamentos. O filtro agora é feito no banco (antes só os 1000 mais recentes eram carregados). Contas a receber e a pagar ganharam a opção "Mês passado".
- **Pró-labore e retiradas de sócio não são mais "Fornecedores a pagar"**: novas contas **2.1.03 Pró-labore e retiradas a pagar** (passivo) e **3.1.02 Distribuição de lucros** (patrimônio, para distribuição de lucros, que não é despesa).
- Plano de contas ganhou o campo **"Onde fica o que falta pagar"** (`conta_passivo_id`) nas contas de despesa/custo. Vazio = Fornecedores a pagar (2.1.01). A despesa de pró-labore aponta para 2.1.03.
- O lançamento da conta a pagar, o pagamento (baixa do passivo certo) e os cancelamentos passam a usar essa conta.
- Correção latente: cancelar conta a pagar ou parcela de contrato que já teve parte estornada por pagamento parcial agora estorna só o saldo restante, não o valor original inteiro.
- Dados da Mathisa: as 4 contas em aberto do Rogério foram reclassificadas para 2.1.03 (estorno + novo lançamento); a despesa por mês em 6.2.04 não mudou.
- Migração (nota): `20261006600000_prolabore_passivo_proprio.sql` (já aplicada no projeto). Login real no Supabase segue não testado.

## [0.46] - 2026-10-07
- **Período padrão de Contas a receber e a pagar**: passa a abrir do **primeiro dia do mês até 30 dias à frente** (antes: só de hoje em diante). O recebimento ou pagamento feito no começo do mês ou ontem não some mais da lista.
- Correção nos dados da Mathisa: contrato #10 (Anna Vitar). O recebimento de R$ 1.300,00 da parcela 1 foi desfeito (lançamento de estorno e devolução no banco, na data de 06/10). As 3 parcelas do contrato estão em aberto (previstas), o caixa líquido da parcela é zero, e a previsão de receita do contrato continua lançada para você ajustar.

## [0.45] - 2026-10-07
- **Dashboard de Vendas: painel "Metas x vendas realizadas"**: para cada campanha ativa mostra meta de vendas, quanto já vendeu (e %), ritmo esperado até hoje (No ritmo / Atrás do ritmo), meta de receita e receita. Campanha de lançamento: meta da campanha toda; campanha recorrente: meta do mês atual. Mais: vendas no mês, vendas sem campanha, oportunidades em negociação e ganhas no mês. Contratos vencendo continuam no topo.
- Atalhos entre o Funil de leads e as Oportunidades de clientes (as Oportunidades seguem como item do menu Vendas, ao lado do Funil).
- Menus separados confirmados: Vendas (Dashboard, Funil comercial, Oportunidades, Vendas, Contratos) e Financeiro (Dashboard, Contas a receber, Contas a pagar, Lançamentos), cada um com o seu dashboard.
- Banco: função `vendas_metas_painel` (`20261006590000_vendas_metas_painel.sql`, já aplicada).

## [0.44] - 2026-10-06
- **Vendas e Contas a receber separadas.** Nova tela **Vendas** (menu Vendas): vendas já realizadas, com quantidade de vendas aprovadas, quanto geraram (bruto e líquido), ticket médio, reembolsos, Nova venda e Estornar; período próprio (padrão: este mês). **Contas a receber** (menu Financeiro) passa a mostrar só o que entra no caixa: parcelas de contratos fechados e vendas, juntas numa lista (com a origem), mais provisionamento por mês, por cliente, MRR/ARR e "Receber o que venceu até hoje". Filtro "Só contratos / Só vendas".
- **Contas a receber ganhou os botões de correção**: **Cancelar** uma parcela de contrato (só ela, o resto do contrato continua), **Desfazer recebimento** (parcela ou venda recebida volta para a receber, com estorno e devolução no banco) e **Reativar** parcela cancelada.
- Banco: coluna `contas_receber.substituida_por` e funções `cancelar_parcela_contrato`, `desfazer_recebimento`, `reativar_parcela_contrato` (`20261006580000_receber_cancelar_desfazer.sql`, já aplicada). Testadas em transação desfeita com os dados reais da Mathisa.

## [0.43] - 2026-10-06
- **Desfazer pagamento** (Contas a pagar → conta paga): a conta volta para "a pagar" e o dinheiro volta para a conta bancária, com lançamento de estorno na contabilidade (nada é apagado). Serve para pagamento lançado com valor errado.
- **Reativar** (Contas a pagar → filtro "só cancelado"): cria uma nova conta a pagar igual à cancelada (mesmo valor, vencimento, competência, rateio) e lança a despesa de novo; a cancelada fica no histórico.
- Correção feita nos dados da Mathisa: Rogério 10/2026 — o pagamento de R$ 1.800,00 foi desfeito e o saldo cancelado de R$ 4.211,91 foi reativado; as duas contas estão a pagar (somam os R$ 6.011,91 do saldo). Contas #5 e #6 (Pedro) canceladas continuam canceladas; dá para trazer de volta com "Voltar para pendente" na tela de Contratos.
- Banco: funções `desfazer_pagamento` e `reativar_conta_pagar` (`20261006570000_desfazer_pagamento_reativar_conta.sql`, já aplicada).

## [0.42] - 2026-10-06
- **Oportunidades** (Vendas → Oportunidades): quadro Kanban para novos negócios com quem já é cliente (ou lead): vender outro produto, renovar, fazer ajuste/aditivo. Cada cartão é ligado ao cliente, com título, tipo, produto, valor estimado, previsão de fechamento e responsável. Etapas padrão: Conversa inicial, Proposta enviada, Negociação e Decisão (editáveis em "Gerenciar etapas"). Arraste entre etapas; **Ganhou** abre o contrato já com o cliente e o produto; **Perdeu** pede o motivo; dá para reabrir. As oportunidades aparecem também na ficha do cliente.
- **Renovar contrato**: botão **Renovar** em contrato ativo ou encerrado (e no painel "Contratos vencendo"): abre um novo contrato pendente copiado do anterior (produtos, valores, recorrência, parcelas), começando no dia seguinte ao fim, para você ajustar datas e valores antes de assinar.
- **Negociar** (mesmos lugares): abre uma oportunidade de renovação ligada ao contrato; ao marcar Ganhou, abre a renovação.
- Banco: tabela `oportunidades`, quadro `oportunidades` em `etapas_kanban` (`20261006560000_oportunidades.sql`, já aplicada).

## [0.41] - 2026-10-06
- **Contratos: números do mês**: novos indicadores no topo da tela de Contratos: **Total do mês** (tudo que vence no mês, recebido ou não, com quanto já foi recebido), **A receber no mês** (quanto falta receber no mês), **Total em contratos ativos** (valor cheio), além dos já existentes: Receita recorrente (valor mensal), A receber (tudo em aberto), Em atraso e Já recebido.
- Parcelas canceladas não entram nos números. Sem mudança no banco.

## [0.40] - 2026-10-06
- **Alerta de contrato vencendo**: contrato assinado e ativo com data de fim mostra um aviso ao lado da situação: 🟠 amarelo a 40 dias do fim e 🔴 vermelho a 30 dias ou menos (e "Venceu há X dia(s)" depois do fim), para renegociar a renovação.
- Painel "Contratos vencendo" no topo da tela de Contratos e no Dashboard de Vendas; filtro "🔴 Vencendo" na lista de contratos.
- Sem mudança no banco (cálculo na tela, a partir da data de fim).

## [0.39] - 2026-10-06
- **Parcelas personalizadas no contrato**: marque "Definir o valor e o vencimento de cada parcela" e informe valor e data de cada uma (ex.: entrada numa data, o resto em outras). Começa dividido igualmente; há botão "Dividir igualmente de novo". A soma precisa bater com o total do contrato (a tela mostra a diferença e barra o salvamento; o banco também confere).
- Vale para contrato não recorrente. Ao assinar, cada parcela vai para o contas a receber e para a previsão contábil com o seu valor e a sua data. Voltar para pendente mantém o plano para você ajustar.
- Banco: tabela `contrato_parcelas_plano` e `ativar_contrato` atualizada (`20261006550000_parcelas_personalizadas.sql`, já aplicada).

## [0.38] - 2026-10-06
- **Contratos com status claros**: Pendente, Assinado e ativo, Cancelado (e Encerrado). Contrato pendente pode ser editado e marcado como assinado.
- **Editar contrato errado**: botão **Voltar para pendente** em contrato assinado ou cancelado. As parcelas previstas são canceladas (e a receita reconhecida é estornada), você ajusta e assina de novo. Não deixa voltar se alguma parcela já foi recebida.
- **Cadastrar produto de qualquer tela**: o seletor de produto dos itens do contrato (inclusive em "+ Outro produto") ganhou "＋ Cadastrar novo…".
- Coluna "Recebido x/y" dos contratos não conta mais parcelas canceladas.
- Banco: função `reabrir_contrato` (`20261006540000_reabrir_contrato.sql`, já aplicada).

## [0.37] - 2026-10-06
- **Códigos automáticos e em sequência**: o campo Código deixou de ser obrigatório. Deixando vazio, o sistema gera: **Canais** e **Centros de custo** → próximo número da sequência (001, 002, 003…, olhando os códigos numéricos já usados); **Plano de contas** → próximo código dentro da conta pai (pai 6.3 → 6.3.07; sem pai → próximo de primeiro nível); **Produto** → tag a partir do nome (curso-exemplo, curso-exemplo-2…); **canal da campanha** → utm_campaign a partir da campanha e do canal. Quem preferir digitar o código continua podendo; códigos já existentes não mudam.
- Sem alteração de banco.

## [0.36] - 2026-10-06
- **Baixa parcial**: ao pagar uma conta a pagar ou dar baixa numa parcela de contrato, há o campo **Valor pago / Valor recebido**. Se for menor que o total, a parte paga é baixada e o **saldo continua em aberto** numa nova conta "(saldo)", com o mesmo vencimento. Dá para repetir quantas vezes precisar.
- Contabilidade: o razão não é editado; a divisão é feita com um estorno parcial (mesma data) e o saldo é lançado de novo. Despesa/receita não mudam de mês nem de valor total. Testado em transação desfeita: despesa de R$ 1.000,01 paga em 3 vezes (400, 100,50 e o resto) lançou a despesa uma só vez; parcela de R$ 2.000 recebida em R$ 800 manteve a receita em R$ 2.000 e, se o contrato for cancelado, só fica a parte recebida.
- **Não vale** para venda avulsa a receber (cada venda tem uma única conta a receber); nesses casos a baixa continua inteira.
- **Correção**: o botão Pagar do fluxo de caixa e do painel gerencial usava código que só funcionava em Contas a pagar; agora os dois usam o mesmo modal (com a conta bancária sugerida pela forma de pagamento).
- Banco: `registrar_pagamento_parcial`, `registrar_recebimento_parcial`.

## [0.35] - 2026-10-06
- **Campanha recorrente** (modelo "Recorrente (perpétua)", sem data de fim): nova aba **Metas mensais**. Você define uma vez a meta de leads por mês e o **mix de produtos** (quantas vendas de cada por mês); o sistema calcula faturamento esperado, ticket médio, conversão lead→venda necessária e meta de leads por dia.
- **Mês a mês**: para cada mês, leads, vendas (por produto) e faturamento reais contra a meta, com % e conversão real × necessária. No mês atual compara com o ritmo esperado até hoje. Um mês diferente (ex.: Black Friday) é ajustado só nele (leads e/ou vendas; o mix escala na proporção).
- Banco: `campanhas.meta_leads_mes`, tabelas `campanha_mix` e `campanha_metas_mes`, função `campanha_metas_mensal` (cálculo todo no banco). Testado em transação desfeita.
- Fica de fora por ora: meta de leads/vendas por dia da semana, aviso automático quando o ritmo cai, e o mix mudando mês a mês (hoje só leads e total de vendas mudam por mês).

## [0.34] - 2026-10-06
- **Nova conta a pagar** agora pergunta "Esta conta": *única*, *recorrente fixa* (todo mês, mesmo valor, **sem fim, até você parar**), *recorrente variável* (todo mês, valor estimado que você corrige) ou *parcelada* (número de vezes, tem fim). Na lista, contas recorrentes mostram a marca "recorrente" e o botão **Parar recorrência**.
- **Correções**: confirmar o valor de uma conta variável mantém o vínculo com a recorrência (antes o mês podia ser gerado de novo); conta cancelada de um mês não volta a ser gerada.
- **Correção**: no Dashboard financeiro os filtros de período (Este mês, 30 dias etc.) não faziam nada, porque o seletor não estava ligado à tela. Contas a pagar e Vendas e a receber já funcionavam.
- **Recorrência no cadastro do fornecedor** (Cadastros → Fornecedores → "Como esta conta se repete"): *avulso*, *fixa recorrente* (mesmo valor todo mês), *variável recorrente* (estimativa mensal que você corrige quando a conta chega) ou *parcelada* (valor total, nº de parcelas e primeiro vencimento; o fim é calculado). Fixa e variável aceitam data final opcional.
- Geração automática ao abrir o financeiro e logo após salvar o fornecedor: fixa/variável geram os próximos 2 vencimentos; parcelada gera todas as parcelas. Não duplica. Mudar o cadastro não altera contas já geradas; tirar a recorrência para de gerar novas.
- A antiga "provisão automática" do fornecedor foi substituída por esta recorrência.
- Banco: colunas `fornecedores.recorrencia/parcelas/data_inicio/data_fim`, tabela `despesas_recorrentes` (motor interno), `contas_pagar.recorrencia_id`, função `provisionar_recorrencias` (aplicados no projeto). Testado em transação desfeita e na tela com navegador simulado.

## [0.33] - 2026-10-06

### Adicionado
- **Compra parcelada em Contas a pagar**: campo "Em quantas vezes?" (1 a 60) e "O valor informado é o total da compra ou o de cada parcela". Cria uma conta por mês, com o mesmo dia de vencimento (em mês curto vale o último dia), descrição "Tablet (1/3)", "(2/3)"… e competência de cada parcela no mês do seu vencimento. A diferença de centavos da divisão fica na última parcela. Tudo entra de uma vez: ou cria todas, ou nenhuma.
- A lista de Contas a pagar passa a **esconder as canceladas** por padrão; o filtro tem "só canceladas" e "todas, com as canceladas".

### Observações
- Não precisa de SQL novo. Conta a pagar não pode ser apagada (a contabilidade é imutável): "Cancelar" reverte o lançamento e a conta some da lista.
- A despesa de cada parcela pesa na DRE no mês do vencimento dela, e não na data da compra.

## [0.32] - 2026-10-06

### Adicionado — fornecedores, formas de pagamento e provisão automática
- **Formas de pagamento** (Cadastros → Formas de pagamento): PIX, boleto, cartão da empresa, débito automático e também cartão ou conta de **outra pessoa** (ex.: "Cartão do Tio Lutero"), cada uma com a conta bancária de onde sai. A conta a pagar ganhou o campo **Forma de pagamento**, e a conta bancária dela já vem sugerida na hora de pagar.
- **Fornecedor fixo ou variável**, com valor padrão, dia de vencimento, conta de despesa, centro de custo e forma de pagamento. Ao escolher o fornecedor numa nova conta a pagar, tudo isso já vem preenchido.
- **Provisão automática**: fornecedores marcados geram sozinhos as contas dos próximos 2 vencimentos (quando alguém abre Contas a pagar, o Dashboard financeiro ou o Painel gerencial; também no botão "Gerar provisões agora"). Fixo usa o valor combinado. Variável usa a média das últimas 3 contas confirmadas, ou o valor padrão, e a conta nasce **"estimada"**. Não duplica: rodar de novo não cria de novo.
- **Confirmar valor** de conta estimada: informe o valor real. Se mudar, o sistema estorna a provisão na contabilidade e lança a conta correta. Conta estimada **não pode ser paga** até ser confirmada.
- Contas novas no plano de contas da Mathisa: 6.2.04 Pró-labore; 6.3 Administrativas com 6.3.01 Contabilidade, 6.3.02 Energia elétrica, 6.3.03 Água e esgoto, 6.3.04 Internet e telefonia, 6.3.05 Treinamento e cursos, 6.3.06 Equipamentos.
- Fornecedores: cadastrados à mão (o SQL não cadastra fornecedores). Para provisionar, abra cada um e preencha tipo de custo, valor padrão, dia de vencimento, conta de despesa, centro de custo e forma de pagamento, e ligue a provisão automática.
- Migrações: `20261006500000_fornecedores_provisao_formas_pagamento.sql` **aplicada** (estrutura, contas novas, 5 formas de pagamento, funções `provisionar_contas_pagar` e `confirmar_valor_conta_pagar`) e `20261006500100_bloqueia_pagar_estimativa.sql` (gatilho que impede pagar conta estimada; **a ferramenta recusou, você precisa rodar**). Os fornecedores foram cadastrados à mão por você, não pelo SQL.

### Limites
- Sem o gatilho pendente, o banco não impede pagar uma conta estimada (a tela esconde o botão Pagar nelas).
- Pagar no cartão de terceiros não gera dívida automática com a pessoa: o fornecedor "Tio Lutero" cobre isso, mantendo a conta dele a pagar até o reembolso.
- Testado no banco real, dentro de uma transação desfeita: gerou 4 contas para 2 fornecedores, não duplicou ao rodar de novo e a correção de valor estornou e relançou com partidas equilibradas.

## [0.31] - 2026-10-06

### Removido
- A opção "Este cliente vai usar o financeiro completo?" e o modo simplificado: saíram a configuração em Cadastro da empresa, a tela **Custos para o CAC**, o menu escondido por modo e os ajustes no painel gerencial e na baixa de recebimento. O financeiro volta a ser sempre completo, como antes da v0.29.
- No banco ficam, sem uso: a coluna `workspaces.modo_financeiro` e a tabela `custos_cac` (e as views que a somam, que não mudam nenhum resultado enquanto ela estiver vazia). `20261006481000_modo_financeiro_bloqueio.sql` **não deve ser rodada**.

### Em estudo
- Criptografia dos dados sensíveis do financeiro (contas bancárias, contas a pagar, movimentação), para que só o cliente veja os detalhes. Decisões pendentes: o que cifrar (só detalhes ou também valores) e como o cliente guarda a chave. Ver decisões e pendências.

## [0.30] - 2026-10-06

### Adicionado — uso da plataforma
- O sistema passa a registrar, para cada pessoa logada: **qual tela abriu, quando, por quanto tempo ficou**, quais **formulários abriu, salvou ou cancelou** e cada **erro** (mensagem curta, com e-mails e números longos mascarados). Não grava nome de cliente, lead, valores nem o que foi digitado.
- Nova tela **Configurações → Uso da plataforma** (só administrador): telas mais usadas, pessoas ativas, sessões, tempo total e médio por tela, uso por pessoa e por dia, formulários com maior desistência, erros mais comuns, telas que ninguém abriu e o bloco **"Onde estão empacando"** (tela com metade ou mais dos formulários cancelados, ou 20% das aberturas com erro, com pelo menos 3 ocorrências).
- Banco: tabela `uso_eventos` (cada pessoa só grava os próprios eventos; só administrador lê) e função `uso_resumo(p_ws, p_ini, p_fim)` com todos os totais calculados no banco.
- Migração: `20261006490000_uso_plataforma.sql` (**você precisa rodar**; a ferramenta recusou aplicar).

### Limites
- Até a migração ser rodada, o app não grava nada e a tela mostra o aviso; o resto do sistema não é afetado.
- Se o navegador fechar de repente, os últimos segundos podem se perder. O envio é a cada 20 s e ao trocar de aba.
- Mede telas e formulários, não cada clique. "Empacando" é um sinal, não prova.
- Avise equipe e clientes que o uso é medido (transparência e LGPD).

## [0.29] - 2026-10-06

### Adicionado — módulo financeiro opcional por cliente
- Configuração **"Este cliente vai usar o financeiro completo?"** em Administrativo → Cadastro da empresa (só administrador). **Padrão: sim, e nada muda.** Coluna `workspaces.modo_financeiro` ('completo' ou 'simplificado').
- No modo **simplificado** ficam: vendas, contas a receber (com baixa sem escolher banco), contratos, MRR/ARR e o CAC. Somem: Dashboard financeiro, Contas a pagar, Lançamentos, Plano de contas, Regras contábeis, Impostos, Contas bancárias, e no Painel gerencial o saldo em banco, a pagar, DRE e fluxo de caixa.
- Nova tela **Financeiro → Custos para o CAC** (só no modo simplificado): você lança o valor gasto (descrição, valor, mês, tipo: mídia, equipe, ferramentas, comissões, outros), com **regra de rateio** opcional, campanha e fornecedor. Entra no CAC total e no CAC por campanha, sem contas a pagar.
- Banco: tabela `custos_cac` (com permissões), `v_custos_rateados` e views de marketing passam a somar `custos_cac`; `growth_metricas_auto` e `campanha_series` também.
- Migrações: `20261006480000_modo_financeiro_custos_cac.sql` (aplicada) e `20261006481000_modo_financeiro_bloqueio.sql` (**você precisa rodar**: bloqueio no banco das tabelas financeiras e a função que troca o modo).

### Limites
- Enquanto a segunda migração não for rodada, não é possível trocar para o modo simplificado pela tela e nada é bloqueado no banco.
- Custos para o CAC não aparecem na DRE (não há DRE nesse modo).
- Voltar de simplificado para completo não apaga nada; os custos lançados continuam entrando no CAC.

## [0.28] - 2026-10-06

### Corrigido
- Cliente cadastrado direto (ou importado) deixa de contar como **lead** no dashboard de marketing, no funil e nas métricas do Growth. Nova marca `pessoas.captada` (false = não veio de captação). O cadastro novo de cliente já grava `captada = false`; o cliente que você já tinha na operação foi ajustado.
- O **onboarding (Alunos)** agora nasce sozinho também quando um **contrato** é ativado (antes só a venda criava o aluno). O contrato já ativado da operação ganhou o cartão em "Novo aluno".

### Adicionado
- **Cadastrar cliente antigo** (Clientes): entra na data real, com o produto, a situação, o CS e **quanto já pagou até hoje**. Esse valor é só histórico (`pagamentos_historicos`): não entra no saldo do banco, na DRE nem em contas a receber. Cria o aluno e o onboarding automaticamente.
- Ficha da pessoa: "Pago antes do sistema" com total, lista e botão "Registrar pagamento anterior".
- Migração `20261006470000_historico_onboarding_leads.sql`.

### Limites
- LTV, cohorts e RevOps ainda calculam receita só de vendas e contratos; o histórico anterior aparece na ficha, mas não entra nesses números.
- Compra online por API/webhook e envio automático de mensagem de onboarding: ainda não construídos (ver decisões e pendências).

## [0.27] - 2026-10-06

### Alterado
- **Período de vencimento compartilhado** (mesmo seletor) em Vendas e a receber, Contas a pagar e Dashboard financeiro. Padrão: próximos 30 dias; o que você escolhe vale nas três telas.
- Contas a pagar: "A pagar no período", "Em atraso (total)" e "Pago no período", provisionamento por mês e por fornecedor (`pagar_periodo`). A lista também segue o período.
- Dashboard financeiro: cartões de a receber e a pagar só do período; atraso total à parte (`fin_dashboard_periodo`; a `fin_dashboard` antiga continua no banco, sem uso).
- Painel gerencial: "A receber até <data final>" e "A pagar até <data final>" (de hoje até o fim do período), com atraso total separado.
- Migração `20261006460000_pagar_periodo_e_dash.sql`.

## [0.26] - 2026-10-06

### Alterado
- Vendas e contas a receber passa a ter **período de vencimento** (próximos 7/30/90 dias, 6/12 meses, este mês, já vencidas, tudo ou datas livres; padrão: próximos 30 dias). "A receber" conta só o que vence no período; o que está diluído nos meses seguintes de um contrato aparece no mês dele. "Em atraso" continua total, separado do período.
- Novo painel "Provisionamento por mês" e "Por cliente: a receber, MRR e ARR", calculados no banco por `receber_periodo(p_ws, p_ini, p_fim, p_hoje)` (migração `20261006450000_receber_periodo.sql`).
- MRR/ARR seguem a mesma regra do painel gerencial: contratos recorrentes ativos hoje, valor dos itens dividido pela periodicidade.

## [0.25] - 2026-10-06

### Alterado — cálculos saem do navegador e vão para o banco
- Painel gerencial: `painel_gerencial(p_ws, p_ini, p_fim, p_hoje)` devolve funil, vendas, caixa, resultado, recorrência (MRR, ARR, NRR, GRR), penetração, CAC (com rateio) e fluxo de caixa.
- Dashboard financeiro: `fin_dashboard`. Dashboard de vendas: `vendas_dashboard`. Métricas automáticas do Growth Model: `growth_metricas_auto`. Séries diárias da campanha: `campanha_series`.
- Conversão lead → venda passa a vir de `v_marketing_campanha.taxa_lead_venda`.
- Migrações `20261006430000_painel_gerencial_no_banco.sql` e `20261006440000_dashboards_no_banco.sql`.

### Adicionado
- Cadastro rápido dentro dos formulários: a opção "＋ Cadastrar novo…" nos campos de fornecedor, centro de custo, produto, funil, canal e plataforma abre o cadastro por cima, salva e já seleciona o item criado, sem sair da tela (conta a pagar, venda, produto, funil, campanha, cliente). O atalho também vale para conta contábil, pessoa/cliente, pessoa da equipe e campanha (formulário mínimo; o restante se completa na tela própria).
- Workspace "Mathisa — Operação" com cadastros-base (centros de custo, plano de contas, etapas, canais, motivos, regras contábeis). "Growths — Demo" fica só para demonstração.
- Guia de banco por cliente (`docs/como-rodar-o-banco.md`).

### Ainda no navegador (aritmética de exibição)
Tráfego pago (CTR, CPL, frequência), indicadores do RevOps pesado (churn, retenção 90d, ascensão), totais de contas a pagar/receber, métricas da ficha da pessoa, prévia de valores de contrato, atingimento/gargalo do Growth e larguras de barras.

## [Não lançado]

Mudanças feitas e ainda não numeradas entram aqui. Quando fechar uma versão, mova este bloco para uma versão nova.

### Adicionado
- Análise de funil (Growth): funil clicável com anúncios, leads, etapas do funil e clientes; filtro por campanha, funil e período; comparação com o período anterior; gargalo e maior perda por regra fixa; quebra por campanha e canal; lista de quem chegou e de quem parou; cohorts por semana ou mês com conversão em 7, 14, 30, 60 e 90 dias; visão por campanha com CPL, CAC, ROAS. Migrações `20261006220000_analise_funil` e `20261006220100_analise_funil_ajustes`.
- Pesquisas (Growth): construtor de perguntas (nota 0 a 10, escala, escolha, múltipla, sim ou não, texto), modelos de lead, onboarding, jornada e descoberta da NSM, gatilho por cadastro, etapa do funil ou entrada de aluno, dispensa de quem já chegou qualificado, fila com link único, página pública de resposta sem login, resultados com NPS, média, PMF e distribuição, insights e criação de experimento a partir deles. Migração `20261006230000_pesquisas`. O envio automático por WhatsApp e e-mail ainda não está conectado.
- `docs/registro-de-implementacao.md`: inventário vivo do que foi pedido, pronto, testado e pendente.
- Planejamento de conteúdo (Marketing): linhas editoriais com temas e prioridade, Kanban (ideia, pauta aprovada, produção, pronto, agendado, publicado) com 5 notas por ideia e por pauta e média calculada no banco, etiquetas de canal (Instagram, LinkedIn, YouTube, TikTok e outros), copy em Docs e mídia no Drive por link, meta semanal por formato x planejado, ranking com sugestão do que produzir, relatórios por canal, tema, formato e conteúdo, importação de ideias e de métricas por planilha. Migrações `20261006200000_conteudo` e `20261006210000_integracoes_social`.
- Cadastros de canais, funis e fornecedores; canais deixam de ser uma lista fixa e viram cadastro por workspace.
- Contas a pagar: lançamento da despesa na competência, pagamento (saída bancária) e cancelamento por reversão, ligados ao plano de contas, centro de custo e, opcionalmente, campanha e canal.
- Planejamento mensal (metas de leads, vendas, receita e orçamento) e comparação com o realizado.
- Venda direta, sem plataforma (sem taxa de plataforma).
- Views `v_marketing_campanha` e `v_marketing_canal` (investimento, CPL, CAC, ROAS, taxa lead → venda). O fluxo de caixa passa a incluir contas a pagar.
- `frontend/index.html` reorganizado em Marketing, CRM, Financeiro e Administrativo (painel gerencial e cadastros).
- Migrações `20261005231500_fixa_search_path_checa_lancamento` e `20261006000000_cadastros_contas_pagar_marketing`.
- Jornada do funil (lançamento): etapas do funil, listas (grupo, API) com regras de entrada e saída. Sair da API mantém no grupo; sair do grupo tira de tudo e volta a pessoa só ao cadastro. Funções `entrar_na_lista` e `sair_da_lista` são o ponto de integração para webhooks (grupo, API, webinar, quem está online).
- Rastreamento completo nos cadastros: utm_id, gclid, fbclid, referrer e página de origem, com filtros por canal e UTM em Clientes e a tela "Leads por origem".
- Tráfego pago: anúncios por utm_content, métricas diárias (lançamento manual ou importação de CSV), resumo por dia e cartões por criativo com CTR, CPC, connect rate, conversão da página, CPL, CAC, ROAS, leads e vendas.
- Dashboard de campanhas por canal: meta x realizado e gráfico de linha diário.
- Contabilidade imutável: lançamentos e partidas não podem ser alterados nem apagados. Correção só por estorno (`estornar_lancamento`, `registrar_estorno`, `cancelar_conta_pagar`). Lançamento manual com partidas dobradas (`registrar_lancamento_manual`).
- Telas: Lançamentos contábeis, Regras contábeis (como o sistema lança sozinho, com exemplo), Plano de contas, Centros de custo, Anúncios, Funis/etapas/listas. Menu redesenhado: ícones, grupos recolhíveis, item ativo destacado e Cadastros recolhido no fim, em tema claro e escuro.
- Tipos de produto: digital, SaaS, serviço, curso, assinatura e outro.
- Vídeos (webinário, VSL, aula): cadastro por plataforma, métricas diárias (lançamento ou CSV), presença por pessoa (CSV ou `registrar_presenca_video`) e tela com retenção, conclusões, cliques no CTA, presentes e compradores.
- Dashboard por área: Dashboard financeiro (caixa, a receber, a pagar, projeção de 30 dias, resultado do mês), Dashboard de CRM (cadastros, qualificação, origem, jornada) e o de Marketing. Abrir um grupo do menu leva ao dashboard dele.
- Nomes no menu: o módulo CRM passou a se chamar Vendas, e a Jornada do funil passou a se chamar CRM. O módulo de alunos se chama RevOps (antes Heavy Ops).
- RevOps: grupo de menu com Dashboard e Alunos (CRM). O dashboard mostra alunos ativos, churn mensal, retenção em 90 dias, LTV, taxa de ascensão, etapas dos alunos, produtos mais vendidos e quais recebem mais ascensão, tudo com semáforo (verde, amarelo, vermelho) contra metas editáveis. Cálculo na função `heavyops_painel`. Produtos ganham `nivel_escada`; alunos ganham `saiu_em`. Simulação com dados fictícios em `supabase/seed/heavy_ops_simulacao.sql`. Migração `20261006190000_heavy_ops`.
- Projetos: equipe (cadastro com função, e-mail, WhatsApp e canais de aviso), modelos de projeto (atividades principais, subatividades, função/responsável, prazo em dias e dependências), projetos com lista e quadro, Minhas atividades e Avisos. Toda campanha nova gera um projeto sozinha com o modelo padrão; atividade só libera quando as anteriores terminam e o responsável é avisado (app agora; e-mail e WhatsApp ficam na fila). Links e tracking dentro da campanha: monta a URL com UTM e cria o criativo no tráfego pelo utm_content. Migração `20261006180000_projetos_equipe_links`.
- Módulo Growth: Growth Model (árvore de métricas com North Star, valores automáticos ou manuais, meta, variação contra o período anterior e gargalo sugerido por regra fixa) e Ciclo de Growth (Kanban de experimentos: ideias, priorizados por ICE, rodando, analisando e aprendizados, ligado às métricas do modelo). Migração `20261006170000_growth_modelo_e_ciclo`.
- Dashboard de tráfego redesenhado: matriz de fadiga criativa (frequência x índice de CPL), gráfico de CTR e CPL por dia com CPL limite e CTR mínimo, mapa de saturação por ângulo, alertas com sugestão (pausar, monitorar, escalar) por regras fixas e criativos em ordem de performance. Compara com o período anterior. Novos campos: alcance nas métricas e ângulo no anúncio. Migração `20261006160000_trafego_alcance_angulo` (também fecha as views para o papel anônimo).
- Dashboard de campanhas: gráfico diário (ou acumulado) com uma linha para investimento, receita, custo por lead e CAC, em dois eixos, com botões para ligar e desligar cada linha e tabela de valores por dia.
- Contas a receber e a pagar com totais (aberto, em atraso, recebido ou pago, vencendo em 7 dias), filtro por situação e linha de total.
- Menu Configurações → Integrações: registro das ferramentas (anúncios, vídeo, plataformas de venda, grupos e webhook) com situação e ID da conta, sem guardar segredos. A conexão automática ainda não existe.
- `index.html` passa a embutir a biblioteca do Supabase (não depende mais de CDN) e mostra aviso claro se o servidor não responder.
- Migrações `20261006150000_integracoes`, `20261006140000_tipos_produto_e_videos`, `20261006120000_jornada_trafego_contabilidade` e `20261006123000_lista_etapa_cadeia`.

## [0.1.0] - 2026-10-05

Primeira versão do banco de dados.

### Adicionado
- Workspaces por cliente, membros e isolamento por RLS
- Pessoas com ciclo de vida (lead, cliente ativo ou inativo), UTMs, qualificação e histórico de mudanças
- Kanbans de leads e de alunos, com etapas configuráveis
- Plataformas de venda com taxa e prazo de recebimento por forma de pagamento
- Produtos, recorrentes ou não, com taxa diferenciada opcional
- Plano de contas, centros de custo, contas bancárias e regras de contabilização
- Vendas com cálculo automático de taxa, imposto e líquido, e geração das partidas contábeis
- Contas a receber, recebimento com movimentação bancária, cancelamento, reembolso e chargeback
- Campanhas com metas gerais e por canal
- Views: funil da campanha, DRE mensal, saldo das contas e fluxo de caixa
- Função para criar um workspace novo já com o plano de contas, as regras e as etapas padrão
- Dados de demonstração e script de simulação de vendas

### Limitações conhecidas
- Venda parcelada no cartão gera um único recebimento
- Assinatura recorrente não gera cobranças mensais automaticamente
- Estorno devolve a taxa da plataforma e o imposto (pode ser ajustado depois)


## v0.8 (06/10/2026)
- Análise de funil continua no pós-compra: entrada como aluno, etapas da jornada do aluno, ativos, saíram, ascensão e recompra, clicáveis, com quebra por campanha e canal.
- Painel de retorno do grupo de leads (churn, retenção, LTV, CAC, ROAS, ROI).
- Cohorts por semana, mês ou campanha, em três visões (conversão, retorno, pós-compra).
- Nova tabela `aluno_historico` (histórico de etapas e saídas do aluno, por gatilho).
- Migração `20261006240000_funil_pos_compra.sql`.
- Removidos do menu Administrativo os cadastros manuais de Anúncios (criativos) e Vídeos.
- Menu lateral: títulos dos grupos maiores, itens menores, todos os grupos começam fechados; clicar num grupo só abre ou fecha (não troca mais de tela).

## v0.9 (06/10/2026)
- Marketing reorganizado: Dashboard, Campanhas e planejamento, Mídia paga, Vídeos e webinários, Planejamento de conteúdo. Leads por origem foi para Vendas.
- Campanha virou página com abas (resumo, funil e cohorts, mídia paga, vídeos e eventos, leads e vendas, links e tracking, debriefing).
- Campanha com status (rascunho, planejada, ativa, pausada, finalizada) e modelo lançamento ou perpétuo; carrinho no lançamento.
- Vídeo pode ser criado ou vinculado dentro da campanha.
- Tabela `campanha_debriefing`; migração `20261006250000_campanha_hub.sql`.
- CRM ganhou filtro de origem.
- O quadro de etapas e listas (antes Vendas → CRM) virou a aba "Funil da campanha", dentro de cada campanha. A aba de análise passou a se chamar "Análise e cohorts". Vendas ficou com Dashboard, Funil comercial e Leads por origem.
