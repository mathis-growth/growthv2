## Endereço do formulário embutido (v0.235)
`t235_embed_endereco.py`: 6 verificações, 0 falhas. `_headers` e `_redirects` certos; o código aponta para `/formulario?pesquisa=…`; o link normal não muda; `/formulario` sem pesquisa volta para o Growths; com pesquisa fica no formulário. Regressão: t234 sem falhas.

## Código (embed) do formulário (v0.234)
`t234_embed_formulario.py`: 6 verificações, 0 falhas.
- Captação só com WhatsApp abre a aba; aparece o código com o iframe e o ajuste de altura; a UTM entra no código; o botão copia; sem link aberto, a tela diz o que marcar; a página pública avisa a altura; sem erros de JavaScript.

## Qualificação do lead por produto (v0.233)
`t233_qualificacao_produto.py`: 20 verificações, 0 falhas.
- **Banco:**
  - o RODAR do formulário monta as 13 perguntas, a regra, o aviso e a mensagem;
  - lead A (Porte 41, Estrutura 17, Momento 20 = 78): Full Brain, quente;
  - lead B (Porte 9): Starter, frio; pediu implementação → revisar;
  - faturamento até R$ 10 mil e "ainda não vendo": não qualificado, "qualif: nutrir", sem tag de produto;
  - a conta fica na resposta; recalcular troca a tag do grupo.
- **Tela:** bloco por pergunta; "elimina"; grupos e conferência; simulador por tag; salvar mantém tudo; "Quem respondeu" com os blocos e "eliminado"; sem erros de JavaScript.
- **Regressão:** t230 e t232 sem falhas.

## Correção: link do formulário do diagnóstico (v0.232)
`t232_diag_gerar_link.py`: 8 verificações, 0 falhas.
- **Banco:** o banco de teste tem a trava dos check-ins, igual à produção; gerar o link funciona e não duplica.
- **Tela:** o padrão vem escolhido; o botão gera o link; cliente sem contato pode copiar o link; sem erros de JavaScript.
- **Produção:** simulação desfeita no diagnóstico do Marco: antes dava o erro da trava; com a função nova gerou o envio. Nada foi gravado.
- **Regressão:** t228, t229, t230 e t231 sem falhas, já com a trava dos check-ins.

## Clientes: Growths pelo contrato; inativar e excluir (v0.231)
`t231_clientes_workspace.py`: 34 verificações, 0 falhas.
- **Banco:**
  - ativar contrato com produto marcado cria o workspace (nome, tipo, pacote, empresa, convite de Administrador, histórico);
  - contrato sem produto marcado não cria; "Tentar de novo" não duplica;
  - inativar: a equipe interna continua entrando, quem é só do cliente perde o acesso; reativar devolve;
  - excluir exige inativar e o nome certo; o workspace da equipe interna é protegido.
- **Tela:**
  - Pacotes de acesso: situação, Inativar, Reativar, Excluir; o seletor esconde o inativo;
  - produto com "inclui o Growths";
  - contrato: a caixa aparece com o produto, sugere o responsável, barra CNPJ errado e cria o Growths ao ativar;
  - sem erros de JavaScript.
- **Regressão:** t230, t228 e t197 sem falhas.



## Formulário para clientes (v0.230)
`t230_destino_cliente.py`: 12 verificações, 0 falhas.
- **Banco:**
  - formulário de lead não mexe na matrícula;
  - formulário para clientes move a matrícula e registra no histórico;
  - cliente sem matrícula: só registra;
  - link aberto: contato novo fica fora do funil;
  - o formulário público não mostra a etapa.
- **Tela:**
  - aviso no diagnóstico;
  - "Quem responde": lead ou cliente;
  - mostrar e esconder os campos;
  - salvar;
  - modelo para clientes;
  - sem erros de JavaScript.
- **Regressão:** t228, t229, t197 e t130 (captação) sem falhas.

## O que já se sabe (v0.229)
`t229_saber.py`: 17 verificações, 0 falhas.
- **Auditoria v2:** vendas aprovadas, sem a repetida e sem o reembolso.
- **Conflitos:** faturamento 80 mil × 62 mil (23%); ticket não bate; investimento bate.
- **Revisão:**
  - contagem na aba;
  - origem declarada;
  - "Vale o da planilha";
  - "Levar para a reunião" (entra na pauta; o resolvido não);
  - confirmar, corrigir e desfazer.
- **O que aparece:** dados das planilhas com o arquivo de origem; da reunião.
- **Excluir pergunta:** aviso de respostas e de dependentes; exclusão; dependente liberada.
- **Sem erros de JavaScript.**
- **Regressão:** t228, t227, t225, t224, t223 e t197 sem falhas. Uma falha intermitente no t223 (a tela atualizava enquanto se digitava o período) foi corrigida e passou em três rodadas seguidas.

## Processo do diagnóstico de clientes (v0.228)
`t228_diag_processo.py`: 23 verificações, 0 falhas.
- **Banco:** clientes esperando (contrato e jornada), um padrão por empresa.
- **Tela, até o envio:** lista de espera; começar com o padrão escolhido; diagnóstico com cliente, contrato e formulário; aba Formulário; mensagem com o link; botões; copiar marca como enviado e vai para o histórico.
- **Tela, até a resposta:** trocar o formulário; arquivo do link entra; progresso "cliente preenchendo"; resposta entra sozinha; não troca depois de respondido; passo final com a reunião.
- **Regras:** sai da lista de espera; não duplica o diagnóstico; modelo novo; outras empresas veem a leitura de planilhas; celular; sem erros de JavaScript.
- **Regressão:** t223, t224, t225, t227 e t197 sem falhas.

## Auditoria das planilhas (v0.227)
`t227_auditoria_planilhas.py`: 22 verificações, 0 falhas.
- **Conferência ao abrir:** 3 de 4 planilhas (uma corrompida); tipos reconhecidos.
- **Alertas da planilha de vendas:**
  - repetida;
  - data ilegível;
  - data futura;
  - valor negativo;
  - fora do período;
  - mês sem linha.
- **Qualidade e cobertura:** precisa de ajuste; recompra; colunas; e-mails e nomes não guardados.
- **Sinais** de vendas, leads e anúncios.
- **Preenchidos sozinhos:** período e classificação sugeridos.
- **Arquivo que não abre:** erro com o motivo.
- **Checklist e de-para:** leads da equipe contam no checklist; de-para confirmado (LTV, recompra) e com ressalva (CTR sem visitas).
- **Tela:** cartão, troca manual de coluna e de tipo, escolha manual mantida, celular, sem erros de JavaScript.
- **Regressão:** t225, t224 e t223 sem falhas.

## Diagnóstico em sete abas (v0.226)
- t225: 27 verificações. Cobre as 7 abas, as três abas de métricas com as contagens, o conteúdo que troca e a pauta na aba Preparar a reunião.
- t224: 30 verificações. Cobre o checklist na aba O que falta, o pedido e a pauta em Preparar a reunião, e a aba antiga guardada que abre em O que falta.
- t223: 50 verificações.
- t222 continua sem falhas.
- Todos com 0 falhas.

## De-para das métricas (v0.225)
`t225_diag_depara.py`: 22 verificações, 0 falhas.
- **Banco:**
  - principal e onde vê;
  - ressalva sem leitura;
  - cálculo descrito;
  - usa sem o dado;
  - lacuna;
  - oportunidade;
  - leitura antiga pelo título;
  - fonte externa;
  - resumo;
  - formulário Entrada (múltipla e principais);
  - sem formulário.
- **Tela:**
  - de-para;
  - tabela do que usa;
  - blocos;
  - para conversar.
- **Formulário do cliente:**
  - sem "Mando depois";
  - lista do que falta;
  - campo "principal";
  - "tudo certo".
- **Sem erros de JavaScript.**
- **Regressão:** t224, t223, t197, t151 e t130 sem falhas.

## Pré-diagnóstico (v0.224)
`t224_diag_pre.py`: 27 verificações, 0 falhas.
- **Banco:**
  - grupo condicional fora;
  - parcial por meses;
  - recebido pela classificação da equipe;
  - recebido sem período;
  - prometido;
  - não tem;
  - arquivado não conta;
  - opcional;
  - resumo;
  - números;
  - progresso;
  - sem formulário.
- **Tela:**
  - número na aba;
  - checklist;
  - mensagem;
  - o que conversar;
  - aviso de período;
  - mensagem guardada;
  - revisado com histórico e progresso;
  - montar de novo;
  - revisar de novo;
  - ir para a reunião;
  - sem formulário;
  - celular;
  - sem erros.
- **Regressão:** t223 e t222 sem falhas.

## Diagnóstico D1: evidências (v0.223)
`t223_diag_evidencias.py`: 49 verificações, 0 falhas.
- **Banco:**
  - diagnóstico sem formulário;
  - histórico;
  - responsável da equipe;
  - período;
  - registro, confirmação (só com o arquivo no Storage), repetido, versão 2, extensão, tamanho e hash recusados;
  - imagem só guardada;
  - sugerida × manual;
  - período e dados pessoais;
  - arquivar e restaurar;
  - erro de leitura;
  - permissão de outra empresa;
  - grants;
  - status;
  - arquivos do cliente pelo link (antes e depois de ligar);
  - progresso;
  - lista.
- **Tela:**
  - lista;
  - novo diagnóstico;
  - envio;
  - repetido;
  - extensão falsa;
  - classificação;
  - período;
  - Dados → leitura → volta;
  - validação e decisão;
  - Arquitetura;
  - reunião de antes;
  - planilhas sem diagnóstico;
  - celular;
  - sem erros de JavaScript.
- **Regressão:** t222, t221, t197 e t151 sem falhas.

## Abas no Cockpit (v0.222)
- `t222_abas.py` (9 verificações, 0 falhas): três abas; abre em Áreas; números nas abas; Metas com o gráfico; Riscos; período mantém a aba; voltar ao Cockpit abre na última aba; celular.
- Regressão (com os testes ajustados para as abas): t213 a t221, t211, t192, t158 sem falhas.

## Metas das áreas (v0.221)
- `t221_metas_areas.py` (18 verificações, 0 falhas): metas do CS absorvidas com a direção certa; espelho churn ↔ CS; saldo mínimo ↔ meta de caixa nos dois sentidos; meta da North Star; meta de margem pela função da tela; margem = DRE com a fonte e "em risco"; churn = cálculo do CS; caixa = saldo de hoje; North Star automática; as sete em `metas_niveis`; risco de margem no Financeiro; tela do Planejamento (sete linhas, salvar com versão); Cockpit (tabela, saúde do Financeiro e do CS).
- Regressão: t220, t219, t218, t217, t216, t215, t214, t213, t209, t198 sem falhas.

## Acerto da projeção (v0.220)
- `t220_acerto.py` (12 verificações, 0 falhas): projeção refeita no dia 15 de outubro igual ao método do Cockpit; erro do mês; resumo (meses, erro médio, viés); dias de referência; faixa provável com texto; faixa não abaixo do realizado; mês encerrado sem faixa; fotos guardadas; sem login recusa; no Cockpit: faixa e "Acerto da projeção".
- Regressão: t219, t218, t217, t216, t215, t213 sem falhas.

## Funil AARRR (v0.219)
- `t219_aarrr.py` (14 verificações, 0 falhas): seis etapas; leads e faturamento iguais às metas; clientes novos e passagem; metas nas etapas; sem dado sem inventar; gargalo; North Star na etapa; sem login recusa; no Cockpit: botão, funil sem sair do Cockpit, Investigar, celular.
- Regressão: t218, t217, t216, t215, t213, t211 sem falhas.

## Cenários ligados à meta (v0.218)
- `t218_cenarios.py` (17 verificações, 0 falhas): sem alavanca = projeção do Cockpit; +10% de leads; ticket +20%; mídia vira leads pelo CPL; dados intactos; meta de leads ignora conversão e ticket com aviso; fator que bate a meta; período encerrado; incertezas; na tela: simular, veredito, salvar, carregar, nova versão ligada, aprovar, simular leads só com alavancas de leads.
- Regressão: t217, t216, t215, t214, t213, t211 sem falhas.

## Investigação (v0.217)
- `t217_investigar.py` (18 verificações, 0 falhas): total e período anterior = vendas aprovadas; em cada dimensão as fatias somam o total; filtro por produto e filtro cruzado; registros somam a fatia; leads iguais às metas; sem login recusa; no Cockpit: investigar o faturamento, clicar no produto (caminho), ver registros com link, voltar duas vezes, investigar leads; celular.
- Regressão: t216, t215, t214, t213, t211, t192 sem falhas.

## Trajetória e saúde por área (v0.216)
- `t216_trajetoria.py` (12 verificações, 0 falhas): 31 pontos com a meta acumulada fechando em 18.000; realizado até hoje e vazio depois; mesmos números da faixa; sem login recusa; gráfico no Cockpit com meta, realizado, projeção e "hoje"; Trajetória dos leads; saúde do Marketing, do Geral e de Vendas (sem meta = diz isso); celular.
- Regressão: t215, t214, t213, t211, t192, t158 sem falhas.

## Risk Engine (v0.215)
- `t215_riscos.py` (32 verificações, 0 falhas): riscos de meta (faturamento e leads), sem duplicar com o ano parcial; 3 alertas de aluno parado = 1 risco de CS; contas vencidas no financeiro; alerta resolvido fora; guardrail crítico; evidência sem probabilidade; idempotência; resolve sozinho, reabre, histórico; sem login não mexe; Cockpit (bloco, contagem por área, Atualizar agora com qualidade, Ver todos com filtro, assumir, descartar só com nota, descartado não volta, Abrir leva ao Customer Growth, celular).
- Regressão: t213, t214, t211, t192, t158, t205, t209 sem falhas; t164 (tela) com a mesma falha de antes.

## Growth's Brain, incremento 2 (v0.214)
- `t214_metas_leads_campanhas.py` (21 verificações, 0 falhas): leads e vendas do mês no registro (espelho só da coluna certa); leads e vendas de outubro iguais ao Dashboard de vendas; cobertura parcial; metas da campanha (janela da campanha e do carrinho, versão nova ao mudar, perpétua fora); recortes; foto das campanhas; Cockpit com as tabelas e o clique na campanha; Planejamento anual (listar, criar, editar e tirar meta de produto; abrir a campanha).
- Regressão: t213, t211, t198, t200, t192, t205 sem falhas.

## Growth's Brain, incremento 1 (v0.213)
- `t213_metas.py` (31 verificações, 0 falhas): espelho plano anual ↔ registro ↔ mês (com versões); ano soma a meta do ano; outubro encerrado; meio do mês (esperado linear, projeção pelo ritmo, status pela regra); dia 1 = sem dados suficientes; sem meta = sem número; regra por cliente; foto diária; acesso negado sem login; NSM provisória com versão; Cockpit (mês e mês passado, aviso da soma, Como calculamos, Ver as vendas com o mesmo faturamento); objetivos do ano (criar, ligar a meta); salvar o mês pela tabela antiga atualiza o registro; Growth Model com status; celular.
- Regressão: t213, t214, t211, t192, t158, t205, t209 sem falhas; t164 (tela) com a mesma falha de antes.

## Período padrão em todos os dashboards (v0.212)
- `t211_periodo_padrao.py` (31 verificações, 0 falhas): 7 dashboards com o mesmo filtro e a ordem nova; todos começam em 01 a 30/11; "Mês passado" escolhido no Marketing vale no Vendas, Administrativo, Mídia paga, Financeiro, Customer Success e Cockpit; Cockpit diz o período no topo; Customer Success conta 32 dias (01/10 até hoje); Financeiro com Próximos 30 dias; menu sem Planejamento da empresa e link antigo abre o Planejamento anual.
- Regressão: t157, t158, t192, t205, t208, t209 e t127 sem falhas. t111, t116, t117, t118, t124, t153, t155 (auditoria) e t86, t164 (tela) têm as mesmas falhas da v0.211, de antes desta versão (base local e datas). t127: a parte do Planejamento da empresa antigo virou "o link leva ao Planejamento anual". Os cartões "A receber/A pagar no período" do Dashboard financeiro abrem a lista no período padrão.

## Período padrão nos dashboards (v0.211)
- Teste `t211_periodo_padrao.py` (17 verificações, 0 falhas): os 4 dashboards com o mesmo filtro e atalhos; começam em 30 dias; o "Mês passado" do Marketing vale no Vendas, Administrativo e Mídia paga; data à mão vira Personalizado e vale no Administrativo; filtro no topo; atalho do Planejamento da empresa abre o Planejamento anual. t192, t205, t208, t158 sem falhas.

## Financeiro simplificado no completo e comissão por produto (v0.210)
- Teste `t209_financeiro_simplificado.py` (21 verificações, 0 falhas): Go-to-Market com a tela; custos com grupo; parceiro com 10% geral e 20% no Curso Base; gravado em duas linhas; comissão de outubro = 20% no produto e 10% no resto, sem somar; DRE; mudar a geral a partir de novembro fecha a antiga e não muda outubro; Growths completo com o Financeiro simplificado e o completo, e o aviso. `t205` 0 falhas.

## Financeiro simplificado (v0.209)
- Teste `t209_financeiro_simplificado.py` (16 verificações, 0 falhas): pacote; ligar; custos com grupo; meses somam os grupos; parceiro; linhas do DRE; comissão de 10% confere no banco; resultado da operação de outubro confere; cartão soma os 3 meses; aviso; Resultado de marketing só com o grupo marketing; menu com e sem a tela. t205 e t208 sem falhas.

## Dashboard de vendas no padrão (v0.208)
- Teste `t208_dashboard_vendas.py` (10 verificações, 0 falhas): filtro; os seis números; valor, vendas e ticket conferem com o banco; clientes ativos e comparação; seções; filtro no topo; Vendas por plataforma no mesmo período; atalhos. `t205` e `t192` 0 falhas.

## Correções da Entrada do cliente (v0.207)
- Teste `t201_entrada_cliente.py` (35 verificações, 0 falhas): 15 perguntas em 4 passos; pergunta das métricas; ✓ verde e aviso de teste no link aberto; grupo com arquivo conta como respondido; tirar o arquivo tira o ✓. `t197` 0 falhas; `t177` com as 2 falhas antigas do Diagnóstico Growth.

## Histórico de vendas (v0.206)
- Teste `t206_historico_vendas.py` (19 verificações, 0 falhas): painel; de-para automático de um relatório com cabeçalhos em português; status traduzidos; conferir não grava; resumo (7 vendas, R$ 7.494 aprovados; 1 não é venda, 1 repetida, 1 já no Growths, 1 com erro); carga registrada; nada na tabela de vendas; pessoa nova cliente desde a primeira compra; lead antigo vira cliente; só reembolso = lead; ficha; planejamento soma o histórico; desfazer; quem já existia fica. t198, t200 e t205 sem falhas.

## Pacote Go-to-Market e Custos de marketing (v0.205)
- Teste `t205_go_to_market.py` (27 verificações, 0 falhas): pacote sem financeiro; menu; reconhece sem financeiro; ligar; itens fixo e variável; meses desde o primeiro custo; não fecha com variável faltando; rotina cria a atividade no último dia, não repete, avisa a agência no dia 3; lançar; fechar conclui a atividade; mês fechado trava; resultado de outubro confere com o banco (receita − mídia − 6.200); painéis de marketing, vendas (com a seção) e administrativo (sem lucro, saldo, CAC total, saúde financeira e DRE); cliente completo não muda. t198 0 falhas.

## Título que o cliente vê (v0.204)
- Teste `t201_entrada_cliente.py` (29 verificações, 0 falhas): nasce com o título; o cliente vê o título no formulário e na aba do navegador, não o nome interno; Editar mostra os dois campos; salvar o título mantém a aparência. `t197_pesquisas_editar_excluir.py` 0 falhas.

## Vendas por plataforma na Entrada do cliente (v0.203)
- Teste `t201_entrada_cliente.py` (24 verificações, 0 falhas): 9 grupos no modelo; ligação com "Onde vende?" (com Hubla); sem plataforma, o genérico; Hotmart + Kiwify, um grupo para cada sem o genérico; texto do relatório sem mexer; Contrato direto traz o genérico de volta; cobra só os grupos à mostra; grava só os à mostra. `t177` mantém as 2 falhas antigas do Diagnóstico Growth (anteriores à v0.201).

## Entrada do cliente sem "Mando depois" (v0.202)
- Teste `t201_entrada_cliente.py` (15 verificações, 0 falhas): config e texto sem "Mando depois"; no formulário, só "Não tenho" ao lado de Enviar arquivo; a cobrança pede o arquivo ou "Não tenho".

## Entrada do cliente (v0.201)
- `g201.js`: modelo com `get objetos()` (o período é calculado quando a pesquisa é criada), planilhas-modelo geradas no navegador (CSV com BOM, separador ;).
- Teste `t201_entrada_cliente.py` (12 verificações, 0 falhas): modelo na lista; 13 perguntas em 4 passos; criado desativado no tipo diagnóstico; perguntas da visão do cliente; 5 grupos com envio; período em novembro e em março; 4 partes no formulário; 5 planilhas-modelo; colunas e exemplo de vendas; texto do export das plataformas.

## Planejar outro ano (v0.200)
- `g198.js`: barra de anos no topo; vazio com cópia das premissas do último ano com plano; Excluir a meta; textos da receita com base nos últimos 12 meses.
- Teste `t200_plano_outro_ano.py` (18 verificações, 0 falhas): anos 2025–2028, ✓ no ano com meta, convite em novembro, Excluir, 2027 vazio com cópia, metas mensais acompanham o ano, caminho/premissas/imposto/cenários copiados, receita dos 12 meses, 2027 gravado e 2026 intacto, trimestres de 2027 por começar, Excluir apaga só 2027. `t198_plano_anual.py` 0 falhas.

## Editar a meta em passos, impostos e lucro final (v0.199)
- `g198.js`: `paImposto(R, cfg)` por regime (usa `CO_SIMPLES`, `coAliqSimples`, `CO_MEI_DAS`); `paContas` resolve a meta pela ambição por iteração (a alíquota do Simples muda com o faturamento); `paLucro` e a tabela "Do faturamento ao lucro" na seção 1 e no passo 4; cards com o lucro no fim.
- Teste `t198_plano_anual.py` (31 verificações, 0 falhas): sugestões novas; custos fixos sem comissões; quatro passos; Salvar só no passo 4; margem fora das premissas; regime do cadastro; folha no Simples e ISS no Lucro Real; alíquota e anexo; resumo no passo 4; meta com Simples confere com a conta feita no teste; lucro na meta = lucro desejado; Lucro Real com IR separado; trimestres e metas mensais como antes. t124 e t127 sem falhas.

## Planejamento anual, etapa 1 (v0.198)
- `g198.js`: premissas e as contas na tela (deterministas, com a fórmula escrita ao lado); formulário com caminho, origem de cada premissa e a ajuda que calcula; trimestres com ritmo; sugestão mês a mês; gráfico acumulado com previsão.
- Teste `t198_plano_anual.py`: tela sem plano; seções; três caminhos; premissas que aparecem por caminho; "do sistema" só com dado e travado; ajuda calcula; plano gravado com a origem; meta = (custos + lucro) ÷ margem; diferença com as três saídas; aviso de estimativa; conta realista; trimestres; gráfico; preencher meses soma a meta; mês fechado com o realizado; botão desligado sem mês vazio; caminho só ambição. 0 falhas. t121 e t124 sem falhas.

## Pesquisas: editar, excluir e modelos (v0.197)
- `g197.js`: modelos ocultos lidos da tabela (ou do navegador, sem a tabela); modal Modelos; exclusão com contagem de respostas e envios e limpeza da pesquisa nas campanhas.
- Teste `t197_pesquisas_editar_excluir.py`: Editar e Excluir na lista; edição grava; aviso com 3 respostas; Cancelar não exclui; topo com Editar pesquisa e Excluir; excluir sem respostas; modelo fora da lista (no banco), some do seletor e volta. 0 falhas. t161, t193 e testes de tela de pesquisa sem falhas.

## Mapa: ligar por qualquer lado (v0.196)
- `g196.js`: `CV_DIR`, `CV_LADOS`, `cvPonto` (direita e esquerda na altura do título, em cima e embaixo no meio), `cvLados` (o guardado ou o automático pela posição), `cvLadoPerto`.
- Teste `t196_canvas_lados.py` (banco de mentira): quatro bolinhas por bloco; ligação antiga com destino embaixo sai por baixo; arrastar de baixo até o topo liga baixo → cima; segunda ligação entre os mesmos blocos por outros lados; direita → esquerda; painel troca o lado de chegada. OK. t165 a t172 e t195 sem falhas.

## Mapa da estratégia e Customer Success (v0.195)
- `g195.js`: `cvTelaCheia` (classe `cv-cheia`, trava a rolagem da página, Esc fecha, lembra em `S.cvCheia`), `cvEdicaoRapida` (dois cliques no nome: campo no próprio bloco, checa nome repetido, renomeia métricas; dois cliques na seta: modal de rótulo).
- Teste `t195_canvas_bump_downsell.py` (banco de mentira): menu Customer Success, biblioteca com Order bump e Downsell, métricas criadas, desenho, zoom com percentual, tela cheia e Esc, editar nome com Enter e cancelar com Esc, Condição renomeada, rótulo da seta. OK. t165 a t172 e t163 sem falhas.

## Campos de formulário (v0.194)
- `g194.css`: regras gerais de rótulo e campo no bloco de estilos mais recente (vencem as regras base de mesma força; as de componentes, como o formulário público, continuam valendo). Conferido no assistente da nova campanha e na nova conta a pagar, modo claro e escuro.

## Pesquisa na campanha (v0.193)
- `g193.js`: bloco de pesquisa (passo 4 da nova campanha e modal Configurar), criação da pesquisa a partir do modelo sem abrir outro modal, painel "Pesquisa da campanha" com captação (link por canal), página de obrigado (código e copiar) e disparo (leads da campanha, na fila, responderam, sem envio; colocar na fila; abrir a fila).
- Página pública: dentro de um iframe, avisa a altura do conteúdo (`postMessage` `growthsPesquisa`) medindo o conteúdo e não a página, para não crescer sem fim.
- Teste `t193_pesquisa_campanha.py`: 4 passos; Não esconde o resto; opções existentes, modelos e nova; sem pesquisa não conclui; aviso do disparo; escolha gravada; pesquisa do modelo com link aberto, canal e desativada; painel com aviso; código com iframe, origem e ajuste de altura; campanha sem pesquisa; etapa obrigatória; link de captação com UTM; 700 leads na fila; abrir a fila; o código colado numa página mostra a pesquisa e a altura acompanha (693 px). 0 falhas. Apaga o que criou.

## Dashboards em seções (v0.192)
- `g192.js`: `GRADE_SECOES` para `adm-painel`, `fin-dash` e `crm-dash`; `gradeSecoes` cria `section.dsec` (cabeçalho `.dsec-h` com título e pergunta, corpo `.dsec-b` em 12 colunas), move os quadros para dentro na ordem do plano e esconde seção vazia; o que o plano não conhece fica no fim. Reaplicado a cada mudança da tela pelo observador da v0.158, sem mover o que já está no lugar.
- `g192.css`: moldura da seção (fundo `--surface-2`, borda, faixa de 4 px na cor de destaque), cartões em uma linha dentro da seção, cartões principais em uma coluna no celular.
- Teste `t192_secoes.py`: ordem das seções nas três telas, quadros dentro da seção certa, nenhuma seção vazia, rótulos antigos escondidos, moldura e fundo diferentes dos quadros, clique no cartão continua abrindo a árvore, Marketing sem mudança, celular sem rolagem lateral e com um quadro embaixo do outro (modo escuro). 0 falhas. `t158_grade.py` ajustado: 0 falhas.

## Pagar e receber em lote (v0.191)
- `g162.js`: `loteCaixa` (quadradinho só para conta em aberto; estimada desligada), `loteTodos` (selecionar todas da lista, com estado "pela metade"), `loteLigar` (barra fixa embaixo com quantidade, total, Limpar seleção e Pagar/Receber; linha marcada em destaque), `loteModal` (lista, total, data, conta bancária; baixa uma a uma e resume o resultado).
- `vPagar` e `vReceber` ganham a primeira coluna de seleção; totais e linhas vazias ajustados à coluna nova.
- Teste `t191_lote.py`: quadradinho por conta em aberto, estimada desligada, paga sem quadradinho, selecionar todas, seleção parcial, modal com total, contas pagas na data escolhida, a desmarcada continua a pagar, uma saída no banco por conta, duas parcelas recebidas, lista atualizada. 0 falhas. O teste desfaz os lançamentos que criou. t125 (receber e pagar): 0 falhas.

## Pesquisa must-have da consultoria (v0.161)
- `g161.js`: modelo `must_servico` (25 perguntas, 6 passos, primeira de papel PMF com 4 opções, a última "Não se aplica"); `pqLeituraPmf` (percentual sem "Não se aplica", faixas 40% e 25%, pílula de cor e ação sugerida).
- Teste `t161_must_have.py`: modelo na lista, 25 perguntas em 6 passos, pesquisa desativada e manual, 50% (3 de 6) sem o "Não se aplica" em verde, 16,7% em vermelho. 0 falhas. t129, t130 e t131 (pesquisas): 0 falhas.

## Kanban, linha editorial e subtemas (v0.160)
- `g160.js`: `tabProducao160` (Kanban de sempre + pílulas de aprovação + "Roteiro e peça" em cada cartão; abre `ctPeca`), `modalAprovaIdeia` (tema, subtema, formato, tipo de mídia, prazo, data), `tabLinhas160` (tela de antes + subtemas + conteúdos por segmento), `modalSubtemas`, `mqOptSub`, `mqLigaSub`, `ehSimples`, `CT_SUB_SIMPLES` (subtítulos das colunas).
- Kanban: filtro de subtema quando o tema tem subtemas; colunas dizem o que falta aprovar no método simples.
- Teste `t159_content_simples.py` (46 verificações, 0 falhas) cobre banco, abas, ficha, subtemas, identidade, aprovação de ideia, Kanban com calendário, peça, vídeo, Mais ferramentas e celular.

## Growth's Content simplificado (v0.159)
- `g159.js`: `tabBase` (pasta do Drive via `csDrive2`, link do dossiê, ficha com versões e aprovação), `tabIdentidade` (cores com papel, fontes, prévia, pasta, referências, limites, formatos, aprovação), `tabIdeias` (aprovar ou descartar), `tabProducao` (quadro Roteiro/Peça/Aprovada/Agendada) e `ctPeca` (roteiro com aprovação; arte ou vídeo com versões, ajuste e aprovação; capa; agendamento), `tabMais` (as abas antigas). `CT_BTN_IA`: botão da Claude desligado com o motivo.
- Banco: `20261114100000_content_simples.sql` (tabelas, colunas, método simples, `conteudo_valida` com a regra nova).
- Teste `t159_content_simples.py`: 25 verificações, 0 falhas (abas, ficha e versões, identidade e prévia, ideias, produção, peça, vídeo, Mais ferramentas, regras do banco, celular).

## Telas em grade (v0.158)
- `g158.js`: `GRADE_TELAS` (plano do Dashboard e do Dashboard financeiro: ordem e colunas de cada bloco), `gradeLiga` (marca a tela no `#main` e observa as mudanças), `gradeAplica` (põe ordem e largura; `.cols` e `.gc-sec` viram parte da grade), `gradeLarg` (largura útil do bloco para desenhar o gráfico), `gradeTextos` (compensa a letra de gráficos desenhados mais largos que o bloco).
- `g158.css`: grade de 12 colunas, blocos com a mesma altura na linha, pontos de quebra em 1100 e 760 px.
- Teste `t158_grade.py`: posições lado a lado, 7 cartões numa linha, letra mínima dos gráficos ≥ 9,5 px, gráficos na largura do bloco, frases do banco nos mesmos blocos, outras telas sem grade, celular em uma coluna, tela média. 0 falhas.

## Banco de narrativas (v0.157)
- `g157.js`: `narrCarrega` (lê os modelos aprovados uma vez), `narr(codigo, campos, alternativas)` (monta a frase, põe `data-nar` e `data-nar-v`; sem modelo ou sem campo, devolve vazio); Financeiro: `finContexto` (NAR-E07), `finCascata` + `gcCascata` (NAR-D02, "sobraram/faltaram"), `finPonte` (ponte ago → set, NAR-H01 e NAR-I01), `finSaldoMin` (caixa + saldo mínimo, NAR-A01, A02, D06, D07); `vMetricas157` (Dicionário com as frases do sistema e a situação de cada uma).
- Banco: `20261113100000_narrativa_modelos.sql` gerado de `nar_modelos.py` (fonte única dos 39 modelos).
- Teste novo `t157_narrativas.py`: regras do banco (versão, histórico, aprovação, sem apagar, só leitura), montagem das frases, ponte que fecha com os dois resultados, cores, modelo não aprovado some, saldo mínimo, Dicionário, celular. 0 falhas. Bateria de regressão: ver CHANGELOG.

## Data Storytelling (v0.152 a v0.156)
- `g152.js`: `SEM` (dicionário de apresentação), `semFmt`/`semBRL`/`semEscala` (formatador único, sinal de menos verdadeiro, "—" para sem dado), `semVar` (variação com direção, tolerância, p.p. e reais), `semStatus` (regra 2a e referências), `semPerAnt` (período anterior), `semCenarioMargem`; Dashboard: `painelHero`, `painelRecVendas`, `painelSemRefs`, `saldoHero`, `compactaKpis` (escala única por linha); observações com categoria e Referência.
- `g153.js`: `marcaSinais` (só saldos; tabelas pela coluna ou linha de saldo), `kpiD`, `dgDeltaG`, `varMes` com a camada nova; `brl` com "—" e sinal de menos; ROAS com 1 casa; LTV ÷ CAC como razão; cores de status do sistema = camada semântica; sem neon nos números.
- `g154.js`: `linhas` refeito (negativos, buracos, vazio); `gcLinhas` com `ref` e pontos na cor da série; cascata neutra com resultado com sinal; séries sem verde/vermelho; saldo mínimo e cenário como linha de referência; dispersão sem sobreposição; título repetido em Mídia paga.
- `g155.js`: contexto e frase-recado no Financeiro (`finContexto`), Marketing (`mktContexto`) e Vendas; custos neutros; mês até hoje contra os mesmos dias.
- `g156.js`: `alCat` (quatro categorias nos alertas), dicionário com unidade, direção e referência.
- Testes novos t152 a t156: 0 falhas. Bateria de tela anterior (t113 a t151, 31 testes): 0 falhas depois de ajustar t121, t127 e t132 às classes e ao sinal de menos novos. Falhas que já existiam na v0.151 (conferidas rodando a v0.151): t116/t117 (o teste compara o cartão abreviado com o valor completo da árvore), t146 (custos de IA) e 6 px de sobra no celular nas tabelas do Dashboard. t111 está desatualizado (outra base de dados). Uma venda de setembro da base de teste virou reembolso durante a bateria (t120); os testes novos calculam o esperado a partir do banco.

## Pesquisa e dossiê (v0.151)
- Apps Script: ação `ler` (Docs, Planilhas, Apresentações, texto, PDF em base64; limites de arquivos e de texto; pastas sem acesso listadas).
- Função `content-pesquisa` (publicada em 25/10/2026, versão 2): GET (diz se `ANTHROPIC_API_KEY`, `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` existem, nunca o valor), POST `pesquisar` e `dossie`; responde na hora e segue em segundo plano (`EdgeRuntime.waitUntil`); continua a conversa se a IA pausar (`pause_turn`); grava em `ia_uso`. `logica.ts` com as regras puras (6 testes Deno).
- Teste de ponta a ponta `tests/edge/pesquisa/teste_pesquisa.ts`: a função de verdade contra o banco local, com a Claude e o Apps Script simulados (18 verificações: permissões, o que vai para a IA, gravação, fontes, arquivos, custo com e sem preço, dossiê).
- `g151.js`: `csPesquisa` (o que a pesquisa usa, acompanhamento, relatório, fontes, arquivos), `csDossie` (seções com índice), `mdHtml` (Markdown escapado), atualização sozinha a cada 4 s enquanto roda.
- Testes de tela: `t151` (novo), `t143`, `t150`, `t148`, `t147`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Ficha de produto simples (v0.150)
- `g150.js`: bloco Produtos no questionário (`PERSONA_BLOCOS`, `PERSONA_P`), `prModal` (produto, valor, histórico, ativo), `tabProdutos2` (lista, trazer do cadastro, nova ideia sobre o produto, histórico recolhido com "Ler o histórico inteiro"). `integra150.py` troca as consultas do `dadosConteudo` e a aba.
- Migração `20261110100000_content_produtos_v2.sql` (aplicada em produção em 25/10/2026).
- Testes: `t150` (novo), `t143`, `t148`, `t147`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Ficha de conteúdo dos produtos (v0.149)
- `g149.js`: `PF_SECOES` (7 partes), `pfModal` (formulário), `pfLeitura` (ver ficha), `tabProdutos` (cartões com % preenchido e conteúdos ligados). `integra149.py`: produtos e fichas no `dadosConteudo`, campo Produto no `modalConteudo` (com score e com notas), aba Produtos.
- Links da página e do checkout aceitos sem "https://" (o sistema completa).
- Migração `20261109100000_content_produtos.sql` (aplicada em produção em 25/10/2026).
- Testes: `t149` (novo), `t148`, `t147`, `t143`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Painel da produção no Kanban (v0.148)
- `g148.js`: `kbPainel(L, D)` (total por etapa, semana atual, calendário de 6 semanas) e `kbLiga(el, C)` (ir para a coluna; abrir a semana na aba Semana). `integra148.py` troca a linha de quadrinhos do Kanban pelo painel. `g148.css` com as cores das etapas.
- Testes: `t148` (novo), `t147`, `t143`, `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Pastas do cliente e da Mathisa (v0.147)
- `g147.js`: `csDrive2` (só a pasta compartilhada; "Outras pastas que você já tem" com adicionar, salvar e tirar), tira "links" do `CS_MAT`, `vPastasMathisa` (tela interna). `integra147.py`: menu, `TELAS_INT`, rota `cfg-pastas`, passo 1 usando `csDrive2`.
- Migração `20261108100000_content_pastas.sql` (aplicada em produção em 25/10/2026).
- Testes: `t147` (novo), `t143` (passo 1 e 5 materiais), `t146`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Estruturas e custos de IA (v0.146)
- `g146.js`: `vEstruturas` e `esModal` (biblioteca, etapas com subir/tirar), `tabEstruturas` (escolha do cliente por formato; aba nova e passo 7), `vCustos` (período, câmbio, por cliente e mês, por tipo de uso). `integra146.py`: menu "Growth's Content (interno)", `TELAS_INT` no lugar do `cfg-pacotes` fixo, `S.verCustos` no início, rotas e a aba. `g146.css` com `body #main` / `body #modalRoot`.
- Câmbio com `data-money="0"` para não cair na máscara de moeda.
- Migração `20261107100000_content_estruturas.sql` (aplicada em produção em 25/10/2026, pelo SQL Editor; conferida: 7 estruturas, 3 tabelas, 5 funções, `ia_uso` fechada).
- Testes: `t146` (novo), `t143`, `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Canais e materiais do cliente (v0.145)
- `g145.js`: reordena `CS_PASSOS` (9 passos, com `fontes` e `materiais` novos) e `CS_IR`; `csFontes` (canais, `csPerfilUrl`), `csMateriais2` (seis tipos em abas, "Pronto"/"Não tenho"/"Reabrir", links de outros Drives). `integra145.py` liga o passo `fontes` e troca o `csMateriais` pelo `csMateriais2`. `g145.css` com `body #main` para vencer o CSS anterior.
- Migração `20261106100000_content_fontes.sql` (aplicada em produção em 25/10/2026).
- Testes: `t143` (9 passos, canais, materiais, links, permissões), `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Configuração em 8 passos e pasta compartilhada (v0.144)
- `g143.js`: `CS_PASSOS` com 8 passos (`emBreve` não trava a conclusão), `CS_IR`, novo `csDrive` (compartilhar pasta, copiar e-mail, colar link, "Verificar de novo"; "Não tenho Google Drive").
- `g144.js`: `csCall` (roteiro da call por blocos, salva em 900 ms), `csMateriais` (lista e marco "material pronto"), `csEmBreve`, `csLinhaIA` (gerar, copiar, colar e aplicar a proposta). `g144.css` com seletores mais específicos (`#main ol.cs-passos`, `#main .cc-q > label`).
- Função `content-drive` (versão 5): lê `drive_script_email` e o modo; pasta compartilhada sem acesso devolve a explicação de como compartilhar.
- Migração `20261105100000_content_setup_v2.sql` (aplicada em produção em 25/10/2026). Cliente "Teste Growth's Content": árvore criada na pasta dele em 25/10/2026 (conferida no Drive).
- Testes: `t143` (8 passos), `t140`, `t141`, `t133`, `t134`, `t135` — 0 falhas.

## Configuração passo a passo e Google do cliente (v0.143)
- `g143.js`: `vConteudo` novo (configuração ou abas), `csWizard` (abertura, barra de passos, rodapé fixo com Voltar/Continuar/Concluir e o que falta), `csDrive` (conectar Google, sem Drive, completar, trocar, desconectar, espera da pasta), `csRotina`, `csRetornoGoogle`. As telas de Persona, Linha editorial e Canais são as mesmas, dentro dos passos. `integra143.py` renomeia o `vConteudo` antigo para `vConteudoAbas`.
- Função `supabase/functions/content-google` (index.ts, logica.ts, logica_test.ts), publicada sem verificação de JWT.
- Migração `20261104100000_content_setup.sql` (aplicada em produção em 25/10/2026). Testes: `t143_content_setup.py`; `t133`, `t134`, `t135`, `t140`, `t141` marcam o módulo como configurado ou seguem a regra nova.


## Correção Growth Starter (v0.142)
- `g141.js` (`ncModal`): `starter` só quando o Growth's Content não está marcado; aviso `.ac-aviso`; troca automática do tipo. Teste `t141` ganhou 3 verificações.


## Acesso em árvore (v0.141)
- `g141.js`: `acMonta`/`acArvore`/`acLiga` (árvore com setinhas, grupos e subgrupos, estado parcial, atalhos), `acGrava` (tudo / pacote igual / ligadas e desligadas), `ncModal` (Novo cliente). `integra141.py` troca o "Novo cliente" antigo e deixa no quadro do Growth's Content a caixa só para a equipe interna.
- Migração `20261103100000_acesso_content.sql` (aplicada em produção em 25/10/2026). Teste `t141_acesso_content.py`; `t140` ajustado.


## Pasta do cliente no Drive (v0.140)
- Migração `20261102100000_content_drive.sql` (aplicada em produção em 25/10/2026) + valores em `sistema_config`.
- Função `supabase/functions/content-drive` (index.ts, logica.ts, logica_test.ts), publicada sem verificação de JWT: aceita a senha do banco (`x-growths-token`) ou alguém da equipe interna logado; ação `teste` confere a ligação.
- Apps Script `integracoes/apps-script/growths-drive.gs` (publicado na conta da Rebecka como App da Web): `criar_cliente` e `teste`, com trava contra pedidos simultâneos.
- `g140.js`: `cdPainel` (quadro em Pacotes de acesso), `cdPillModulo` (link no topo do módulo), opção no "Novo cliente"; `integra140.py` renomeia o módulo para Growth's Content.
- Teste `t140_content_drive.py`; `t133` e `t135` com o nome novo.


## Insights e melhores dias (v0.139)
- `g139.js`: `igInsights(P, R, DM)` (regras acima; cada item `{cls: fato|hip|rec, tit, txt, rec, ids}`), `igPalavras` (palavras da legenda, `IG_STOP`), `igMontaInsights` (cartões; "Ver os posts" filtra a galeria por `ids`), `igLinhaCat` (linha por categoria), `igDiasCats`, `igHorasCats`, `igMontaDias`, `igDMs` (conversas novas do período). `igFiltra` aceita filtro por lista de posts.
- `integra139.py` (roda o `integra138.py`): blocos `#igIns` (antes da galeria) e `#igDias` (depois dela); os insights esperam as DMs.
- Validado também com os dados reais da conta (somente leitura, 90 dias). Teste `t134` ganhou insights e linhas.


## Cores pela média, quadros e menu em níveis (v0.138)
- `g138.js`: `IG_FAIXA` (baixo/media/alto), `igDifTxt`, `igLegendaFaixas`; `igGrafico` e `igBarrasH` redefinidos com a classe da faixa e a diferença para a média. `g137.js`: cada gráfico vira `<section class="ig-gc">` com contorno e número de grupos; legenda no topo.
- `integra138.py` (roda o `integra137.py`): `desenhaNav` envolve o conteúdo de cada grupo aberto num `<div class="lv2">` recuado; subgrupos (`.sublist`) recuam mais um nível. No celular, cada linha do gráfico empilha nome em cima e barra embaixo.
- Testes: `t134` (cores, legenda, quadros) e `t135` (menu em níveis).


## Galeria e gráficos de tema e formato (v0.137)
- `g137.js`: `igMontaGaleria` (cartões com imagem, ordem `IG_GORD`, "Mostrar mais" de 8 em 8, filtro vindo do gráfico) e `igMontaGraf` (`igGrafico` por frente, formato e tipo, `igGrupoVal` com média/total/quantidade, barras clicáveis). Cada bloco se redesenha sozinho, sem recarregar os dados. Ícones SVG em `IG_IC`.
- `integra137.py` (roda o `integra136.py`): coloca `#igGal` e `#igGraf` depois dos números dos posts e chama os dois no fim de `tabInsta`; trocar o período zera o filtro.
- Teste `t134_instagram_dashboard.py` ganhou galeria, ordenação, gráficos e filtro pela barra.


## Instagram como submenu; dashboard de canais (v0.136)
- `g136.js`: `vConteudo` novo, com a parte decidida pela rota (`mkt-cont` = Estratégia, `mkt-insta` = Instagram; `MQ_VIEW_CANAL`/`MQ_CANAL_VIEW`), abas da estratégia em `MQ_EST` (Dashboard primeiro) e do canal em `MQ_CANAL`; `mqIrCanal` abre o canal e o menu. `tabDashCanais` (eficiência por canal e melhores posts). `igConexao`/`igFonteHtml` (conta conectada, última atualização ou em qual cliente ela está). `tabInsta` sem importação: seção A conta (seguidores, novos seguidores, alcance, visitas) e Os posts, top 1, gráficos, agrupamentos e lista com "classificar". `igModalPost` salva frente e formato no post.
- `integra136.py`: corta o `vConteudo`, o `tabInsta` e o `igModalPost` antigos; menu com `subs` "Máquina de Conteúdo"; ícone novo.
- Testes atualizados: `t133`, `t134` (sem importação, classificação do post, dashboard de canais) e `t135`.


## Estratégia e canais; DMs (v0.135)
- `g135.js`: `vConteudo` novo com `C.sec` ('estrategia' ou o canal) e subabas; abas antigas 'insta', 'dms' e 'rel' são levadas para a parte do canal. `tabCanais` (canais em uso, por frente, por etiqueta, aplicar sugeridos), `mqCanaisAuto` no cartão novo, `tabDMs` + `dmConversa` (chat) e `vDMsCrm` (Vendas → DMs do Instagram). As ideias do canal usam o Kanban com o canal fixo.
- `zernio-sync`: nova etapa `dms` (Inbox API do Zernio: `/inbox/conversations` e `/inbox/conversations/{id}/messages`), escolhida por `partes`.
- Teste `t135_dms_canais.py`.

## Dashboard do Instagram (v0.134)
- `g134.js`: `tabInsta` (aba 'insta' da Máquina; rota `mkt-insta`), gráficos SVG próprios de uma série e um eixo cada (`igBarrasDia`, `igLinhaDia`), barras horizontais com a média geral marcada (`igBarrasH`), `igModalPost` (post contra a média do período, posição e ligação), importação com leitor de CSV com aspas e quebra de linha (`igCsv`), mapeamento de colunas em português e inglês (`IG_COLS`/`igMapeia`), data dia/mês ou mês/dia (`igData`) e prévia.
- Testes: `t134_instagram_dashboard.py` (banco e telas).

## Máquina de Conteúdo (v0.133)
- `integra133.py` corta as versões antigas de `dadosConteudo`, `vConteudo`, `modalConteudo`, Kanban, Priorização, Plano e Linhas e injeta `g133.js` (antes de `const PQ_TOKEN`) e `g133.css`. Relatórios, métricas e importações ficaram como estavam (ganharam agrupamento por território, formato da Máquina e destino).
- Abas: Kanban, Priorização (`tabPrior` / `tabPriorNotas` no método antigo), Máquina (`tabMaquina`, matriz território × formato), Semana (`tabPlano`, dias com arrastar e soltar; metas por tipo de mídia num bloco recolhível), Fechamento (`tabFechamento`, RPC `conteudo_semana` e `conteudo_fechar_semana`), Relatórios, Persona (`tabPersona`), Linha editorial (`tabLinhas`, núcleo, método, territórios, camadas, formatos, quadros).
- Cartão (`modalConteudo`) no score V18: seções Pauta, Encontrabilidade, Radar e evidência, Score (6 × 1 a 5, total ao vivo, VALIDAR), Roteiro (estrutura com passos), Produção e publicação, Depois de publicar.
- Edge function `linha-editorial`: lê o questionário pelo cliente da pessoa logada (RLS), manda as respostas + o modelo V18 como exemplo, valida a resposta (`validaProposta`) e grava em `conteudo_linha_propostas`. Limite de 6 propostas por hora por cliente. A tela tem a mesma validação para a resposta colada (`mqValidaProposta`).
- Testes: `t133_maquina_conteudo.py` (banco e telas, 70+ conferências) e `deno test supabase/functions/linha-editorial`.

## "Como foi o meu dia?" e alertas (v0.132)
- Tela `ia-perguntar` → `vPerguntar` reescrita (a antiga saiu no `integra132.py`): botões de dia e `diaDaPergunta(texto)` reconhecem ontem/hoje/anteontem/dd/mm e mostram `cardFatos(f)` (de `growths_fatos_dia`); com chave de IA, a pergunta também vai para `perguntar`.
- Tela nova `ia-alertas` → `vAlertas`: alertas (`alertas`), configuração (`alertas_config`), canais por pessoa (`equipe.avisar_*`), status dos canais (`avisos` → `{acao:'status'}`), teste (`growths_aviso_teste` + `avisos` → `{acao:'enviar'}`), envios recentes (`notificacoes`).
- Edge function `avisos`: autentica pelo `x-growths-token` (agendador) ou login; reserva cada notificação antes de enviar (não manda duas vezes); expira fila com mais de 3 dias; `logica.ts` monta e-mail (Resend) e WhatsApp (modelo da Meta, variáveis sem quebra de linha).
- `perguntar`: junta `growths_ia_extra` ao contexto; regra 7 da IA explica hoje/ontem/série/alertas.
- Montagem: `integra132.py` (roda o `integra131.py`) com `g132.js` e `g132.css`.
- Testes: `t132_assistente_alertas.py` (banco com cliente de teste e telas), `deno test supabase/functions/avisos/logica_test.ts`.

## Selo, tags coloridas e quem respondeu (v0.131)
- `seloQual(p)` (usa `qualificacao` e `pontuacao_qualificacao`) no `crmCardTopo`, no topo da `fichaPessoa` e na lista de clientes; `tagCor(t)` / `tagPill(t)` no `chipsTags` (CRM) e no topo da ficha; `fmtPts`.
- Pesquisa: aba `quem` em `vPesquisaDet` → `pqRespondentes(el, p, perg)` (estado `S.pqRv`: todas, filtro, ordem; CSV com BOM e `;`).
- Montagem: `integra131.py` (roda o `integra130.py`) com `g131.js` (antes de `const PQ_TOKEN`) e `g131.css`.
- Teste: `t131_selo_tags_respondentes.py`.

## Formulário de captação (v0.130)
- Página pública: `vPesquisaPublica(token)` → `pfDesenha(el, d, token, {previa})`; passos por `pfPassos(d)`; campos por `pfCampo`; aparência saneada por `pfVis` (fonte, cor, logo) e aplicada como variáveis CSS (`pfEstilo`); fontes carregadas por `pfCarregaFontes` (dois links por família, um sem pesos que sempre existe).
- Editor: aba `form` em `vPesquisaDet` → `pqForm(el, p, perg)` (configuração em `C`/`V`, pré-visualização com `pfDesenha(..., {previa: true})`, temas `PF_TEMAS`, contraste por `pfContraste`). `modalPergunta` ganhou `secao` (se a coluna existir: `S.pqSecao`).
- Modelo `PQ_MODELOS.captacao_mathisa` com `extra` (visual, captação, qualif) e perguntas com passo e pontos; `criarDeModelo` grava esses campos.
- Banco: `pesquisa_registrar` concentra a gravação (antes dentro de `pesquisa_responder`); `pesquisa_captar` valida, deduplica, cria/atualiza a pessoa e chama `pesquisa_registrar`.
- Montagem: `integra130.py` (roda o `integra129.py`) com `g130.js` e `g130.css`; o `g130.js` substitui a página pública antiga e fica no fim do script (depois de `PQ_MODELOS`).
- Teste: `t130_formulario_captacao.py` (41 verificações: editor, página pública no celular, CRM, deduplicação, bloqueios e o fluxo antigo).

## Gráfico único e qualificação por pontos (v0.129)
- `gcMulti(el, {rotulos, metricas, sel, parcial, metas})` e o novo `cpLinhas` (a versão da v0.128 saiu); seleção em `S.cp128.selM`. `CP_MET` lista as métricas e cores.
- Pesquisa: aba `qual` em `vPesquisaDet` → `pqQualif(el, p, perg)`; `pqPontua(cfg, perg, itens)` repete a conta do banco para o simulador.
- Banco: `pesquisa_qualificar(p_resposta)` (interna, sem permissão para o cliente), `pesquisa_requalificar(p_pesquisa)` (autenticado, confere o workspace), `pesquisa_responder` chama a qualificação no fim (alterada por substituição no texto da função, sem reescrever o resto).
- Montagem: `integra129.py` (roda o `integra128.py`) com `g129.js` e `g129.css`.
- Teste: `t129_multi_qualificacao.py`.

## Painel da campanha (v0.128)
- `campPainel128(el, c)` na aba Dashboard da campanha (depois de `vMktDashCampanha`): `cpGrade`, `cpQueda`, `cpLinhas`, `cpCriativos`, `cpVendas`; estado em `S.cp128` (período).
- `gcLinhas`: rótulos de data pela largura; escala com folga quando a variação é muito pequena. `GC.fmtK`: mais casas em valores pequenos e porcentagens abaixo de 5%. `gcDivergente` aceita a legenda.
- Montagem: `integra128.py` (roda o `integra127.py`) com `g128.js` e `g128.css`.
- Teste: `t128_painel_campanha.py`.

## Onda 3 (v0.127)
- `vendasOfertas127` (Vendas), `planoV127` (fim do `vPlano`), `saldoMinLer`/`saldoMinGrava`/`finSaldoMin` (Financeiro); `painelObs` ganhou a regra do saldo mínimo.
- Importação: campo `oferta_id` (ref `ofertas`) em `IMP_ALVOS.vendas`; `impCarregaRefs` carrega as ofertas pelo nome; a mensagem de "não encontrado" usa o nome da referência quando ela não é um alvo de importação.
- Montagem: `integra127.py` (roda o `integra126.py`) com `g127.js`.
- Teste: `t127_onda3.py` (cria e apaga dados de teste; roda o RODAR na base de teste e remove a coluna no fim).

## Fim da Onda 2 e da Onda 1 (v0.126)
- Componentes: `gcPilha`, `gcTornado`, `gcMatriz2x2`, `gcHalteres`, `gcDivergente`, `gcFunil`; `gcLinhas` ganhou `W` (largura) e `GC` o formato `n2`. Agrupamento: `gcGranDe`, `gcBaldes`, `gcChave`, `gcSemana`.
- Telas: `abandonoV126`, `rxLtvPainel` (em `rxCoortes`), `gmTornado` (fim do `gpDesenha`), `cicloV126`, `resultadosV126`, `debriefDesvio` e `gcFunil` (em `htmlComparativo`), `campBurnup` (aba Dashboard da campanha), `midiaV126` (Mídia paga), `mktSerie126` (Dashboard de marketing), `painelNovosExist` (Dashboard).
- Montagem: `integra126.py` (roda o `integra125.py`) com `g126.js` e `g126.css`.
- Teste: `t126_onda2_parte2.py`.

## Onda 2, parte 1 (v0.125)
- Componentes: `gcBarrasV`, `gcEmpilhada`, `gcDispersao`, `gcTodos` (paginação de 1.000 linhas); `gcBarrasH` ganhou `fixo` (mantém ordem e zeros).
- Telas: `painelObs` (Dashboard), `finResBanco` (Financeiro), `finVencimentos(m, 'receber'|'pagar')`, `mrrEm` e `contratosV125` (Contratos), `vendasV125` (Vendas), `mktV125` (Dashboard de marketing), `origemV125` (Leads por origem).
- Montagem: `integra125.py` (roda o `integra124.py`) com `g125.js` e `g125.css`.
- Teste: `t125_onda2_parte1.py`.

## Gráficos da onda 1 (v0.124)
- Componente: `gcLinhas`, `gcBarrasH`, `gcCascata`, `gcBullet`, `gcRitmo`, `gcLiga` (cliques que abrem a árvore) e o objeto `GC` (formatos, vazio, fonte). CSS com prefixo `gc-`. (O prefixo `gx` já era usado pelo Growth Model.)
- Dashboard: `painelV124(m, ctx)` chamado no fim do `vPainel`; DRE e fluxo em `<details class="gc-det">`.
- Financeiro: `finCascata(m, PER)` no fim do `vFinDash`; filtro de meses ≤ mês atual em "Resultado por mês".
- Custos e margens: `custoV124(m, ctx)` no fim do `vCustoOp`.
- Mídia: `midiaRelatorio(el, R, de, ate, cs, cp)` no fim do `vTrafego`; `irMidiaCampanha(c)` no botão `#cMidia` da campanha. Rotas: `adm-dash` → `vPainel` (troca a view para `adm-painel`), `st-dash` → `vPainel`, `mkt-midia` → `vTrafego` (fora do Starter troca para `mkt-trafego`). `vMidia` e `vDashGrowth` ficaram no código, sem rota.
- Montagem: `integra124.py` (roda o `integra123.py`) com `g124.js` e `g124.css`.
- Teste: `t124_graficos_onda1.py`.

## Linha no período e cadastros na campanha (v0.123)
- `arvLinha(top, N, root)` (no `arvDesenha`): caixa com os botões de agrupamento, chama `arvore_serie` e guarda por agrupamento em `top.series`. `arvGranAuto`, `arvRotPonto`.
- `estNova(pr, dup, aoCriar)`: com `aoCriar` abre em `#modalRoot2` (o `modal()` ganhou o parâmetro `raiz` e só redesenha a tela quando é o modal principal). Etapas: `estPickHtml`, `estPickModelo`, `estPickLer`.
- Nova campanha (`abrirWizard`): produto com `data-novo="produtos"` (`ligarNovo`), estratégia com "＋ Nova estratégia…" e prévia das etapas (`#wzEt`), canal com `cadastroRapido(ENT.canais…)`.
- Montagem: `integra123.py` (roda o `integra122.py`), com `g123.js` e `est123.js`; remove o bloco da v0.122.
- Teste: `t123_linha_cadastros.py`.
