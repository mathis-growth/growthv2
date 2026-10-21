# Decisões e pendências

## Decisões tomadas

| Data | Decisão |
| --- | --- |
| 2026-10-05 | O produto se chama **Growths** |
| 2026-10-05 | O time é Rebecka e Rogério; o desenvolvimento usa Claude Code e Lovable |
| 2026-10-05 | "AR" é ARR (receita recorrente anual) |
| 2026-10-05 | Várias plataformas de venda conectadas ao mesmo tempo, configuradas dentro do sistema |
| 2026-10-05 | Cálculo de métricas por fórmula declarativa executada no banco, nunca por IA |
| 2026-10-05 | Primeiro uso: o time e os clientes atuais |
| 2026-10-05 | Fora do escopo: nota fiscal e conciliação bancária automática (só importação de extrato) |
| 2026-10-05 | SaaS cobrado mensalmente reconhece a receita por mês |
| 2026-10-06 | Menu: Marketing, CRM, Financeiro e Administrativo (painel gerencial e cadastros no pé) |
| 2026-10-06 | Cliente pode ser lead, ativo ou inativo, automático ou manual; venda direta sem plataforma permitida |

## Limitações da versão atual

- Venda parcelada no cartão gera um único recebimento
- Assinatura recorrente não gera cobranças mensais sozinha (cada cobrança entra como uma venda)
- Estorno devolve a taxa da plataforma e o imposto; chargeback é tratado como reembolso
- Qualificação do lead é manual (ainda não há questionário)

- Funil é só cadastro por enquanto: as etapas do Kanban ainda são únicas por workspace
- Contas a pagar recorrentes e parceladas ainda não são geradas sozinhas
- Não há cancelamento de conta a pagar já paga

## Perguntas em aberto

As cinco mais importantes estão em negrito: respondê-las destrava o hub de integrações e o motor de CAC.

1. **Existe data-limite? O MVP da Black Friday do Growths é este sistema?**
2. Qual cliente roda primeiro e com quantos dados históricos?
3. **Qual é a hipótese de NSM e de alavancas para um cliente real?**
4. As alavancas são fixas por negócio ou mudam a cada pesquisa?
5. Reembolso e garantia contam como receita só depois do prazo?
6. **Há afiliados, coprodutores ou split de comissão?**
7. Como tratar inadimplência e recorrência que falha?
8. Haverá receita fora da plataforma (serviço, consultoria)?
9. Como identificar a mesma pessoa em fontes diferentes (e-mail, telefone, CPF)?
10. Qual modelo de atribuição: primeiro toque, último toque ou ambos?
11. **Recompra e reativação contam como cliente novo no CAC?**
12. Como captar as UTMs hoje (pixel, formulário, página de captura, WhatsApp)?
13. **Quais custos entram no CAC e como o custo comum é rateado entre os canais?**
14. Os clientes trabalham com lançamento, perpétuo ou ambos?
15. Metas por campanha são de quê, e o planejamento anual é mensal ou trimestral?
16. Níveis de acesso dentro de um cliente (dono, gestor, analista)?
17. Dia de fechamento mensal e trava de período?
18. Quem pode alterar fórmulas, plano de contas e regras?

## Pontos para cuidar mais adiante

- LGPD: consentimento do lead, origem do consentimento e exclusão sob pedido
- Fuso horário e moeda
- Mapeamento de produto entre plataformas (o mesmo produto tem IDs diferentes em cada uma)
- Reprocessamento de webhooks duplicados ou que falharam
- Rastreabilidade: clicar em uma métrica e chegar até a venda ou o lançamento que a gerou

## Pendente: integração com plataformas de vídeo
Hoje as métricas de webinário e VSL entram por lançamento ou CSV. A integração direta (API ou webhook da plataforma usada) depende de qual plataforma ela usa. O contrato já existe: `registrar_presenca_video` e a tabela `video_metricas_dia`. Falta uma função de borda (Edge Function) com segredo por plataforma, que não deve ficar no front-end.

## Pendências do módulo de projetos
- Envio automático de e-mail e WhatsApp: precisa de provedor (por exemplo Resend para e-mail e a API oficial do WhatsApp com modelos aprovados), Edge Function com as chaves guardadas no servidor e leitura da fila `notificacoes` com status pendente. Hoje: sino no app e botão que abre o WhatsApp com a mensagem pronta.
- Aviso de atividade atrasada: precisa de tarefa agendada no banco.
- Trocar o modelo de um projeto que já tem atividades não é feito pela tela.

## Pendências do planejamento de conteúdo
- Pesquisa diária por IA: precisa de chave de API de um provedor de IA, de uma Edge Function e de uma tarefa agendada. Hoje as ideias entram por "Colar ideias" (a função `conteudo_importar_ideias` já aceita origem `ia`, para a automação usar).
- Postagem no Instagram a partir de uma pasta do Drive: precisa de app da Meta (conta profissional ligada a uma página), autorização do Google Drive e Edge Function com os segredos no servidor. A mídia e a copy já ficam guardadas por link no conteúdo.
- Métricas da conta e por conteúdo: entram por planilha. A coleta automática depende das mesmas conexões; LinkedIn, YouTube e TikTok têm APIs e regras próprias.
- Definir os 5 critérios de nota finais (os atuais são uma sugestão) e as metas semanais reais.

## Pendências de análise de funil e pesquisas
- Envio automático das pesquisas (WhatsApp e e-mail): precisa de provedor, Edge Function com segredos no servidor e tarefa agendada que leia a fila de envios pendentes.
- O link de resposta exige o arquivo hospedado (GitHub Pages ou similar).
- Link aberto sem limite de taxa: se ligado em página pública, pode receber spam. Avaliar CAPTCHA ou limite antes de usar em larga escala.
- Definir os limites do gargalo com dados reais de mais campanhas.

## Pendências de acessos e permissões (v0.22)
- Rodar `20261006380000_acessos_sincronizacao.sql` no SQL Editor do Supabase (libera acesso pela Equipe, retira acesso e aceita convite no primeiro login).
- Ligar a confirmação de e-mail no Supabase Auth (Authentication → Providers → Email). Sem ela, alguém poderia criar conta com o e-mail de outra pessoa e herdar o acesso reservado.
- Conferir os níveis das funções sugeridas e o mapa de módulos por tabela (migração `20261006370000`).
- Funções privilegiadas do banco (registrar recebimento, estornar, importar, etc.) ainda não checam o módulo do chamador.
- Decidir se haverá bloqueio contábil por período fechado.

## v0.23
- Decisão: um só workspace de demonstração ("Growths — Demo"); o paralelo "RevOps — Simulação" sai. A ferramenta recusou apagá-lo: rodar manualmente (ver como-rodar-o-banco).
- Decisão: vendedor é gravado na venda; trocar o responsável depois não muda o vendedor histórico.
- Pendente: relatório de desempenho por responsável (vendas, retenção do CS); receita de contratos no funil/ROI/LTV; checagem de módulo nas RPCs privilegiadas; confirmar e-mail no Supabase Auth; relato do funil que "parou" ainda sem tela/erro.
- Pendente do usuário: executar `20261006380000_acessos_sincronizacao.sql`.

## v0.24
- Decisão: permissões por ação ficam em jsonb (função e pessoa) e são lidas por `pode()`; sem detalhe, vale o nível do módulo.
- Decisão: novos centros de custo entram no CAC por padrão; existentes (Geral, Google, Meta, Produto) continuam no CAC até você desmarcar.
- Limite: a ferramenta recusou criar `salvar_rateio` e o gatilho de validação de `equipe.permissoes_ind`; a validação fica na tela, e no banco a view ignora regra que não soma 100%.
- Pendente: esconder botões da tela conforme as ações (hoje o banco bloqueia e mostra mensagem); rateio também na DRE por centro de custo; relatório de desempenho por responsável; receita de contratos no funil/ROI/LTV.

## v0.25
- Decisão: regra de negócio que gera número de gestão roda no banco (funções STABLE, checam workspace e respeitam RLS). O navegador só formata e desenha.
- Decisão: "Growths — Demo" é só demonstração; a operação real é "Mathisa — Operação" (8fd51ed1-0843-49d8-a2aa-b9bb99c59171).
- Limite: o `index.html` é sempre legível por quem o abre, então nada sensível de regra deve ficar nele; por isso a migração dos cálculos.
- Pendente: mover o que resta no navegador (ver CHANGELOG 0.25, "Ainda no navegador").
- Pendente do usuário: apagar o workspace "RevOps — Simulação" e executar `20261006380000_acessos_sincronizacao.sql`.
- Pendente: relatório por responsável; receita de contratos no funil/ROI/LTV; confirmação de e-mail no Supabase Auth; bug do funil em Growth (informar tela/erro).

## v0.26
- Decisão: atraso é sempre total; "a receber" é só o período escolhido. Padrão da tela: próximos 30 dias.
- Pendente: a Demo não tem contratos recorrentes, então MRR/ARR por cliente só foi conferido com dados simulados; conferir na operação real.
- Pendente: período também nas contas a pagar (você pediu só receber por enquanto).

## v0.27
- Decisão: um período só para receber, pagar e dashboard financeiro; atraso sempre total.
- Limite: a ferramenta recusou `drop function`; por isso `fin_dashboard_periodo` nasceu ao lado de `fin_dashboard`. Se quiser, rode `drop function public.fin_dashboard(uuid, date);`.
- Pendente: curva de caixa projetado acompanhar o período escolhido.

## v0.28
- Decisão: lead de marketing = pessoa captada. Cliente cadastrado direto ou importado não é lead.
- Decisão: pagamento de antes do sistema é só histórico, fora do banco, da DRE e de contas a receber.
- Pendente: histórico anterior entrar em LTV, cohorts e RevOps.
- Pendente: **entrada de compra por API/webhook** (curso online): precisa de função de borda com chave por workspace, idempotência por id da compra e mapeamento do payload da plataforma; hoje a venda só é lançada pela tela.
- Pendente: **mover o aluno sozinho** entre etapas do onboarding e **enviar a mensagem por API** (WhatsApp): as etapas e os alertas existem; falta regra de avanço automático e a integração de envio.
- Pendente: o cadastro de cliente antigo gera o envio da pesquisa 'entrada de aluno' (fila); revise se não quer isso para clientes antigos.

## v0.29
- Decisão: padrão 'completo'; o modo simplificado é escolha por cliente (workspace).
- Decisão: custo para o CAC é lançamento próprio (`custos_cac`), não conta a pagar; não aparece em DRE.
- **Pendente (ação sua)**: rodar `20261006481000_modo_financeiro_bloqueio.sql` no SQL Editor (a ferramenta recusou). Sem ele não dá para ativar o modo simplificado e o banco não bloqueia as tabelas financeiras.
- Pendente: ao voltar de simplificado para completo, a conta "Recebimentos (controle interno)" continua existindo; revise se quiser removê-la.
- Pendente: custos recorrentes (lançar todo mês automaticamente).

## v0.30
- Decisão: medir tela, tempo, formulário e erro, nunca conteúdo digitado.
- **Pendente (ação sua)**: rodar `20261006490000_uso_plataforma.sql`.
- Pendente: medir cliques em botões específicos e funis de ação (ex.: abriu contrato → ativou), se quiser ir além de telas.
- Pendente: retenção (apagar eventos com mais de 12 meses) e relatório comparando clientes quando houver um banco por cliente.

## Atualização (06/10/2026, noite)
- Decisão: **não rodar** `20261006481000_modo_financeiro_bloqueio.sql`. Os dados financeiros do cliente serão protegidos por **criptografia** (nem a Mathisa vê), a desenhar. Por isso o modo simplificado não pode ser ativado pela tela por enquanto; o padrão "completo" segue igual. A parte já aplicada (`custos_cac`, coluna `modo_financeiro`) fica no banco sem efeito até lá.
- Pendente: desenhar a criptografia (quem guarda a chave, o que é cifrado, como o CAC e os totais seguem calculados no banco sem ver o dado aberto).
- Rastreio de uso (v0.30): migração aplicada e já gravando.

## v0.31 — criptografia do financeiro (em estudo)
- Decisão: o modo "sem financeiro" foi removido; no lugar, o cliente poderá ter os dados sensíveis criptografados (contas bancárias, contas a pagar, movimentação) de modo que nem a Mathisa veja os detalhes.
- **Decisão pendente 1 — o que cifrar.** (a) Só os detalhes (descrição, fornecedor, observações, nome e número da conta): valores, datas e categorias seguem legíveis e todos os cálculos continuam no banco; a Mathisa vê quanto, não quem nem o quê. (b) Detalhes e valores: nem o saldo é visível, mas totais, DRE, CAC e fluxo só podem ser calculados no navegador de quem tem a chave, o que quebra a regra de cálculo no banco para esses dados.
- **Decisão pendente 2 — a chave.** Senha própria do financeiro (digitada ao abrir as telas, nunca salva; se for perdida, os dados cifrados não se recuperam) ou chave em arquivo guardada pelo cliente.
- Aviso: criptografia no navegador só garante sigilo se a chave nunca passar pelo servidor, e quem controla o `index.html` poderia, em tese, alterá-lo. Com a chave perdida não há recuperação, nem por nós.
- Pendente: desenhar a migração dos dados já lançados (o que existe hoje está em texto aberto).

## v0.32
- Decisão: correção de valor estimado é por estorno e novo lançamento (a contabilidade é imutável), não por edição.
- Decisão: provisão roda ao abrir as telas financeiras (o pg_cron não está instalado). Se quiser rodar sem ninguém abrir o sistema, dá para ativar o pg_cron depois.
- **Pendente (ação sua)**: rodar `20261006500100_bloqueia_pagar_estimativa.sql` (gatilho; a ferramenta recusou). Depois preencher nos fornecedores cadastrados à mão o tipo de custo, valor, dia de vencimento, conta de despesa, centro de custo e forma de pagamento, e ligar a provisão automática.
- Pendente: pagamento com cartão de terceiros (Tio Lutero) como dívida automática; por ora o fornecedor Tio Lutero fica "a pagar" até o reembolso.
- Pendente: as contas novas e as formas de pagamento valem só para a Mathisa — Operação; novos workspaces não nascem com elas.
- Pendente: tablet como bem da empresa (depreciação) em vez de despesa; encargos do pró-labore; hosting e demais ferramentas sem nome do fornecedor real; ferramentas hoje no centro Administrativo (avaliar rateio com Marketing).

## v0.33
- Decisão: parcelas ligadas só pela descrição, sem coluna nova (não exige SQL). Se quiser cancelar todas de uma vez ou ver o total da compra, falta um grupo de parcelas no banco.
- Pendente: competência na data da compra (e não por parcela) e juros de parcelamento, se o cartão cobrar.

## v0.34
- Decisão (da Rebecka): a recorrência fica no cadastro do fornecedor, não em tela separada. Um fornecedor tem uma recorrência; custos diferentes do mesmo prestador (ex.: contador e pró-labore) exigem fornecedores/cadastros distintos.
- Pendente: editar o fornecedor não atualiza contas já geradas; as novas contas e formas valem só para o workspace onde foram criadas.
- Decisão: "recorrente" significa sem fim; só parcelada tem fim. Parar recorrência não é reversível pela tela (cria-se outra).
- Pendente: rateio e campanha não passam para as contas geradas pela recorrência; reativar recorrência parada.

## v0.35
- Decisão (da Rebecka): metas definidas uma vez com ajuste por mês; mix em quantidade de vendas por produto. O modelo "Perpétuo" passou a se chamar "Recorrente (perpétua)".
- Pendente: mix diferente por mês; alerta automático de ritmo; meta de conversão própria (hoje a necessária é derivada); comparar com a meta de receita da empresa (planejamento).

## v0.36
- Decisão: baixa parcial divide a conta em duas, em vez de guardar "valor pago" numa coluna, para não alterar os relatórios que somam contas em aberto.
- Pendente: recebimento parcial de venda avulsa (exigiria permitir mais de uma conta a receber por venda e ajustar o estorno de venda); histórico que ligue o saldo à conta de origem (hoje só pela descrição "(saldo)").

## v0.37
- Decisão (da Rebecka): códigos de tudo que se cadastra são automáticos e incrementais. Mantida a opção de digitar. Codes antigos com letras (google_ads, ADM) ficam como estão.
- Pendente: se quiser, renumerar os códigos antigos com letras; trava de unicidade por workspace nos códigos de canal e centro (hoje a geração evita repetição só olhando a lista na hora de salvar).

## v0.38
- Decisão (da Rebecka): para editar contrato errado, basta voltar o status para Pendente; sem tela de edição separada para contrato ativo.
- Pendente: voltar contrato com parcela já recebida (hoje exige desfazer o recebimento antes); ajustar automaticamente projetos já criados quando o contrato mudar.

## v0.39
- Decisão (da Rebecka): contratos negociados em parcelas diferentes (entrada + restante) têm valor e data por parcela.
- Pendente: plano para contrato recorrente (hoje recorrente segue a periodicidade fixa); editar valor/data de parcela já gerada sem voltar para pendente.

## v0.40
- Decisão (da Rebecka): avisar quando o contrato estiver vencendo, a 40 e a 30 dias do fim, com destaque vermelho, para renegociar a renovação.
- Pendente: aviso por e-mail/notificação (hoje só na tela); prazos configuráveis por workspace; ação "Renovar contrato" que copia o contrato antigo.

## v0.41
- Decisão (da Rebecka): ver no contrato o total do mês (recebido ou não), quanto falta receber no mês e o total dos contratos.
- Pendente: escolher outro mês (hoje é sempre o mês atual); valor mensal por contrato na lista.

## v0.42
- Decisão (da Rebecka): novos negócios com clientes existentes precisam de oportunidade própria no Kanban, ligada ao cliente, com etapas de negociação; renovar contrato e ajustar datas.
- Pendente: ligar automaticamente o contrato gerado à oportunidade ganha (hoje o vínculo é só pelo cliente); renovar estendendo o mesmo contrato em vez de criar outro; histórico de movimentação entre etapas; filtro por responsável no quadro; oportunidade automática quando o contrato entra na faixa de vencimento.

## v0.43
- Decisão: reverter erro de pagamento por estorno (histórico preservado), não por apagar ou editar lançamento. Reativar cria conta nova em vez de ressuscitar a cancelada, para cada conta ter só uma despesa lançada.
- Pendente: desfazer recebimento (contas a receber) com a mesma lógica; nome repetido "(saldo) (saldo)" em baixas parciais seguidas; avisar antes de cancelar um saldo de baixa parcial.

## v0.44
- Decisão (da Rebecka): vendas realizadas e contas a receber são coisas diferentes e ficam em telas separadas; contas a receber reúne contratos fechados (parcelas) e vendas já realizadas.
- Pendente: decidir se contrato assinado deve contar como venda no dashboard de vendas e nas metas (hoje só vendas); recebimento parcial de venda avulsa.

## v0.45
- Decisão (da Rebecka): dashboard de vendas separado do financeiro, com metas x vendas realizadas, oportunidades e contratos vencendo; oportunidade ganha vira contrato.
- Pendente: decidir se contrato assinado (inclusive venda lateral/ascensão de cliente) conta como venda nas metas; meta geral da empresa por mês (hoje as metas são por campanha); filtro de período no painel (hoje: mês atual / campanha toda).

## v0.46
- Contrato #10: recebimento de R$ 1.300 desfeito a pedido da Rebecka (valor combinado e valor recebido não bateram: entrou R$ 1.000 e R$ 300 foram perdidos). Parcelas ficam em aberto até ela ajustar o contrato (volta para pendente, edita valores/parcelas e assina de novo).
- Pendente: recebimento de valor diferente do combinado com opção de perdoar/baixar a diferença (desconto ou perda) em vez de manter saldo aberto.

## v0.47
- Decisão: pró-labore credita 2.1.03 (passivo próprio), não Fornecedores. Distribuição de lucros fica em 3.1.02 (patrimônio, não despesa).
- Pendente: encargos do pró-labore (INSS, IRRF) como contas próprias; mesma correção de saldo líquido em `cancelar_contrato` e `reabrir_contrato` com parcelas divididas; nome "(saldo) (saldo)" após pagamentos parciais seguidos.

## v0.49
- Decisão da Rebecka: não existe um "Modelo de funis" separado; é o próprio Growth Model, montado automático com os dados do sistema e filtrável por produto, campanha, etapa e período.
- Pendente: ligar o Growth Model às metas de campanha e à meta da empresa; projeção de contratos considerando renovação e fim de vigência; gráficos por loop; vários loops por campanha (ex.: lista de e-mail separada de mídia paga); loops de retenção por coorte (curva de renovação) quando houver histórico suficiente; comparar com a planilha de referência.
- Pendente (financeiro): conferir por que o saldo do banco aparece negativo na tela (no banco, as contas somam positivo).

## v0.50
- Decisão da Rebecka: criar um Demo 2 vazio para validar com dados reais de captação e tráfego (importação a partir de planilha).
- Pendente: rodar `limpar_demo.sql` se quiser limpar o Demo antigo; importador de tráfego/captação por planilha.

## v0.51
- Decisão da Rebecka: o plano atual é o padrão, mas cada cliente traz o seu e ele precisa ser importado e personalizado.
- Pendente: rodar `20261007130000_importar_plano_contas.sql` no SQL Editor (a aplicação automática foi cancelada).

## v0.52
- Decisão da Rebecka: planejar o ano de campanhas (ex.: 3 lançamentos + perpétuo) com datas editáveis e meta de faturamento por campanha e no total.
- Pendente: meta de faturamento do perpétuo é um valor único do ano; se quiser meta mês a mês de receita no perpétuo, falta criar.

## v0.53
- Decisão da Rebecka: poder registrar regra contábil para evento novo do sistema.
- Pendente: o sistema não aciona eventos personalizados automaticamente (venda, conta a pagar etc.). Se quiser que uma regra nova seja usada por algum fluxo (ex.: tarifa dentro do pagamento), precisa ser ligada a esse fluxo.

## v0.54
- Decisão da Rebecka: o conceito de UX enviado (escuro, vinho/carmim, cartões, North Star e guardrails) é o visual base do sistema.
- Pendente: refazer o dashboard principal no desenho do conceito (KPIs com variação e mini-gráfico, North Star, guardrails, desempenho por canal, funil de crescimento, insights, ações prioritárias, produtos). Hoje só o visual geral foi aplicado.

## v0.55
- Decisão da Rebecka: toda a parte de cadastro precisa de importação com de-para colorido; o Growth Starter é um módulo de consultoria com o menu do conceito; o dashboard segue o conceito.
- Pendente: importar plano de contas, fornecedores recorrentes e mídia paga pelo mesmo de-para (hoje o plano tem importador próprio e a mídia tem o dela); guardar o de-para para reusar com o mesmo cliente; definir os relatórios do Starter além do diagnóstico; guardrails próprios (retenção e margem mínimas); dashboard comparar com outros períodos além do anterior.

## v0.56
- Decisão da Rebecka: Configurações precisa ser agrupada, com menus e submenus.
- Pendente: confirmar com a Rebecka se o erro que ela viu ao cadastrar função era o das funções sugeridas; se for outro (ao salvar uma função nova), pedir a mensagem exata.

## v0.57
- Decisão da Rebecka: o seletor de clientes é só da equipe interna; clientes não veem outros clientes.
- Decisão: ascensão fica como está (bloco no dashboard + tela existente) por enquanto.
- Pendente: `provisionar_workspace` segue aberto a qualquer usuário logado; fechar exige outro fluxo para o primeiro acesso.

## v0.58
- Decisão da Rebecka: o cliente personaliza o próprio dashboard arrastando blocos; escolhido salvar por pessoa e por cliente.
- Pendente: contrato pela Autentique e boas-vindas por e-mail e WhatsApp a cada venda ou contrato (depende do token da Autentique e do provedor de envio).

## v0.59
- Decisão da Rebecka: ter um dashboard de mídia nos moldes do Dashboard de Tráfego, com relatórios por canal e por campanha.
- Pendente: o limite de CPL e o CTR mínimo por campanha (linhas de referência do gráfico) ainda não existem no cadastro; hoje o índice usa o CPL médio dos últimos 30 dias como referência.
- Pendente: a frequência depende do alcance importado por anúncio; sem alcance o anúncio não aparece na matriz.

## v0.60
- Decisão da Rebecka: a IA responde perguntas, mas não pode inventar nem consultar o banco livremente; precisa ser seguro.
- Decisão de desenho: a IA só lê o resumo de `ia_contexto`, com regras fixas, e os números da resposta são conferidos contra esse resumo.
- Pendente: cadastrar as chaves de IA e testar com uma resposta real; ampliar o resumo (por exemplo anúncios e clientes agregados) conforme as perguntas que aparecerem em `ia_perguntas`.

## v0.61
- Decisão da Rebecka: a primeira versão do dashboard (Painel gerencial) volta a ser o Dashboard principal; o dashboard do conceito fica como Dashboard Growth.
- Observação: a tela Mídia paga (vTrafego) já tinha, desde antes, matriz de fadiga, gráfico de CTR e CPL por dia, mapa de ângulos e alertas. O Dashboard de mídia novo (v0.59) acrescentou os relatórios por canal, campanha, anúncio e ângulo; os dois coexistem por enquanto.

## v0.62
- Decisão da Rebecka: subir os CSVs e o sistema identificar o que são; verde é só dar ok, vermelho mostra o problema e pede ok, amarelo é dúvida.
- Pendente: guardar o de-para por cliente para reaproveitar quando ele mandar o mesmo layout de novo; ler as demais abas de planilhas Excel (hoje só a primeira).

## v0.63
- Decidido: período em meses inteiros (não por dia), porque a base do Growth Model e do DRE é mensal.
- Decidido: remover Personalizar; `dashboard_layouts` fica sem uso (pode ser apagada depois).
- Pendente: campos personalizados de produtos, fornecedores, campanhas e vendas só entram pela importação (sem edição em formulário); o de-para ainda não é salvo por cliente; só a primeira aba do Excel é lida.

## v0.64
- Decidido: contrato fechado = venda, contada uma vez. Não cria linha em `vendas`; a tela Vendas e vendas_dashboard o somam por leitura. Growth Model e Painel gerencial já o contam por regra própria.
- Feito: growth_modelo_historico conta contrato como venda (quantidade).
- Pendente: campanha_metas_mensal, campanha_series, growth_metricas_auto, funis, ascensão, heavyops e contexto da IA ainda contam só a tabela `vendas`; unificar (ex.: contrato gera venda e some a regra própria) exige mexer no Growth Model.
- Pendente: conferir se o cadastro de contrato marca a primeira parcela como recebida ao criar quando informa conta bancária (o #12 nasceu recebido).

## v0.65
- Decidido: calculadora dentro do Growth Model; ticket por campanha, vindo da oferta principal; margem alvo padrão 20%, editável.
- Pendente: despesa da empresa entra como valor editável (média do DRE sugerida), sem rateio automático por vendas; ofertas ainda não ligadas à venda individual (o registro por campanha soma vendas do produto na campanha); custos de WhatsApp entram como item de custo até a integração do provedor.

## v0.66
- Benchmarks não vêm prontos: o usuário digita. Pendência: alertas também no Dashboard Growth e na aba por loop, e benchmark por segmento/produto.

## v0.67
- Contrato do fornecedor é um link; upload de arquivo fica como pendência.

## v0.68
- Desconto só em parcela de contrato. Pendência: desconto em venda avulsa (tabela vendas) e relatório de descontos por cliente/motivo.

## v0.69
- Front no Lovable: começa pelo Growth Model (piloto). A lógica continua sendo ajustada e testada no sistema atual e replicada no Lovable. Pendente: conectar o conector Lovable ao Claude para publicar direto.

## Growth Model: planilha e North Star (v0.71)
Decisão: atribuição por alavanca isolada. Pendente: importar a planilha do Growth Model da Rebecka (Produto principal/summary). North Star Metrics fica parado, a pedido dela.

## Importador do Growth Model (v0.72)
Decisão: mapeamento confirmado por quem importa, sem adivinhar em silêncio. Pendente: loops 2 a 4 da planilha (lista de e-mail, upgrade, renovação) dependem de existir o loop equivalente no sistema; cohorts de renovação não são importados; cliente sem nenhum dado real ainda não tem loop para receber a planilha.

## Máscara de moeda (v0.73)
Decisão: máscara aplicada de forma central e automática, para não depender de editar cada formulário. Pendente: campos de valor sem "(R$)" no rótulo e fora da lista de nomes conhecidos precisam de `data-money="1"`; revisar na primeira rodada de uso real.

## Growth Model novo (v0.74)
Decisões: NSM e calculadora saem da tela e ficam guardadas; modelo em JSON provisório até validar o formato; loops personalizáveis por produto; planilha padronizada e mensagem ao cliente como saídas do diagnóstico.
Pendentes: cohorts e curvas de renovação; projeção e cenários sobre o modelo novo (a tela antiga de alavancas continua separada); atribuição de leads a produto quando o CRM não traz produto; ratear investimento sem produto; ler outras abas de vendas com colunas por parcela; testar com arquivos reais de cliente.
Divergência na planilha de referência: no High Ticket, "Clientes novos" não soma os upgrades, mas a receita soma.

## Menu Growth e Growth Model (v0.75)
Decisões: Diagnóstico Growth e Growth Model como telas separadas no menu; tabela única no formato da planilha; modelo do sistema montado na hora (não é copiado para o JSON), para sempre refletir os cadastros.
Pendentes: pedir melhorias de visual depois do uso real; cohorts e curvas de renovação; projeção e cenários sobre o modelo novo; exportar o Growth Model em .xlsx no mesmo formato; edição manual de números sobre loops do sistema (hoje só em loops manuais).


## v0.76
Decidido: cenário por taxa, sem tela separada. Pendente: projetar meses futuros no cenário; usar o cenário na atribuição de melhoria de receita.


## v0.77
Decidido em 08/10:
- estratégia genérica;
- último clique na atribuição;
- upgrade não é cliente novo;
- grupo, aula e disparo vêm do Sendflow;
- cenário vira meta por botão;
- colunas automáticas por dia até 45 dias e por semana até 6 meses;
- o modelo antigo sai quando o novo for aprovado;
- não há mais MVP de Black Friday: os módulos são liberados por partes.

As etapas da estratégia ficaram fora de `funil_etapas` para não virarem colunas do Kanban.

Pendente:
- rodar a migração;
- dados de acesso do Sendflow (parte 3);
- parte 2: Growth Model por produto e data, cenários e caminhos até a compra.


## v0.78
Decidido: o Growth Model abre num produto; a visão de todos os produtos fica como "Visão geral". Pendente (parte 2): vários cenários com nome, período por data e escopo por estratégia ou campanha.


## v0.79
Decidido: o topo de funil sempre aparece. Próximo: cruzar o modelo da Fernanda (Baseline e meta com rampa do Mês 1 ao 12, meta × previsão, bloco de MRR, versões Baseline, Real e Max) com o outro modelo que a Rebecka vai mandar, antes de redesenhar o Growth Model.


## v0.80
Decidido: segurança fase 1 aplicada (fechar funções para não logados, permissão por módulo nas operações de escrita, trava de estimativa). Resolvidas as pendências "`provisionar_workspace` aberto a qualquer usuário" e "rodar `20261006500100`". Pendente: decidir o que o modo financeiro simplificado bloqueia no banco; testar login real com perfis não administradores (hoje todos os membros são administradores); fase 2 (migração de baseline com as funções que só existem no banco, avisos e campos personalizados por administrador).


## v0.81
Decidido (sugestões do plano de blocos, assumidas até você mudar): métrica principal do conteúdo = cliques no link medidos por UTM; catálogo de 14 blocos fixo, com métricas extras por estratégia; um bloco por aula. Simulador: valor esperado fracionário; percentuais de custo e impostos sobre a receita após reembolso; parcelado reconhece a receita na venda e recebe em parcelas iguais; custos variáveis e impostos saem no mês da venda; ROAS de equilíbrio e alvo escalam o volume com mídia, fixos e outros custos constantes; payback calculado para a primeira coorte com clientes. Pendente: alimentação automática das métricas dos blocos (fase 2 do plano), integrações (fase 3), Growth Model lendo as métricas principais (fase 4); no simulador, importar histórico real (mídia, clientes, reembolsos) e PDF do relatório.

Simulador (após revisão): CAC mídia, ROAS e CAC mídia máximo usam só clientes e receita dos canais com mídia; CAC total usa todos os clientes novos. LTV de contribuição = contribuição da primeira coorte ÷ clientes dela. O regime "caixa" troca o indicador do topo para o caixa acumulado.


## v0.82
Decidido: nomes Growth Loops e Unit Economics, como abas do Growth Model. Correção de dados: a baixa parcial de R$ 700 do pró-labore de 10/2026 foi desfeita e a parte desfeita cancelada, deixando só R$ 9.300; a conta de R$ 9.300 foi substituída (confirmar_valor_conta_pagar) por uma de R$ 10.000 em aberto, vencimento 30/10. Razão conferido: 6.2.04 = R$ 10.000, 2.1.03 = R$ 10.000 a pagar, banco sem efeito. Pendente (proposto): ao desfazer o pagamento de uma baixa parcial, juntar a parte desfeita com o saldo ainda não pago.


## v0.83
Decidido: desfazer pagamento de baixa parcial junta com o saldo em aberto (pendência da v0.82 resolvida).


## v0.85
Decidido: acesso por pacote, com personalização por módulo e por tela; pacote + ajuste por cliente. Pacotes iniciais Consultoria, Mentoria e Disparo são pontos de partida. Atenção: tirar um módulo do cliente também esconde os dados dele em painéis de outros módulos (ex.: sem Vendas, o painel de marketing não mostra receita). Pendente: quando uma tela nova entrar no menu, incluí-la no catálogo pela migração.

## v0.86
Decidido: cartão de crédito é um tipo de conta bancária (não uma tabela nova). A compra no cartão baixa a conta a pagar na data da compra e vira passivo do cartão; a saída de caixa é o pagamento da fatura (débito cartão, crédito banco). Fatura em aberto = −(saldo inicial + movimentos do cartão). Finanças da casa ficam num workspace separado ("Casa"), não num módulo dentro da Mathisa: o acesso é por membro, então cliente nenhum vê, e os números da casa não se misturam com os da empresa.
Pendente: (1) confirmar se os R$ 1.500 recebidos no "Cartão de Crédito" (contratos #10 e #7, 07/10) e os R$ 1.500 pagos ao Rogério por ele eram da conta principal (saldo líquido zero, não muda o total); (2) ligar a forma de pagamento "Cartão da empresa" ao cartão em Formas de pagamento; (3) fatura por ciclo (fechamento/vencimento mês a mês) ainda não existe: hoje é o saldo em aberto do cartão; (4) itens 6 a 8 do pedido de 10/10 (transcrição por microfone, IA lendo documento/áudio e virando atividades) esperam a chave de IA.

## v0.87
Decidido (pedido da Rebecka): a Casa não é um "cliente"; é um módulo dentro da operação. Por trás continua um livro separado (workspace ligado por `casa_de`), porque é o que garante no banco que lançamentos, plano de contas e bancos não se cruzam; na tela ele aparece só como o grupo Casa do menu. A única ponte é a transferência empresa → Casa, que lança nos dois livros e fica registrada em `transferencias_casa`. Quem é membro só da operação não vê a Casa.

## v0.88
Decidido: o nosso Growths é a base; regras e campos do Growth's do Rogério entram nele em 3 fases (documento "Growths × Growth's do Rogério — comparação e plano"). Fase 1 entregue. Identidade: telefone manda, depois e-mail. Junção de cadastros por enquanto é sempre confirmada por alguém (tela Cadastros repetidos); a junção automática por telefone fica para a decisão da Fase 2. O fechamento continua com os números montados na tela (dadosFechamento); o banco grava, versiona e protege. Pendente para a Fase 2: decisão de atribuição oficial e ROAS bruto × líquido; mover o cálculo do funil da estratégia para o banco.

## v0.89
Decidido (Rebecka, 10/10/2026): atribuição grava primeiro e último toque, painéis usam o último (regra v1: último toque = origem da própria venda; sem ela, o último toque com origem antes da venda); ROAS oficial bruto; mesmo telefone junta sozinho (mesmo e-mail com telefones diferentes continua indo para Cadastros repetidos). Bump e upsell continuam sendo vendas separadas (uma por produto, cada uma com a sua contabilidade); `pedido_ref` agrupa as do mesmo pedido. Fases da meta são um rótulo; o recorte de tempo vem do período da meta. Pendente: mover o cálculo do funil da estratégia para o banco; Fase 3 (entrada bruta de eventos, webhooks, saúde das integrações, links rastreados, acesso por campanha, progresso do aluno, contexto da IA) depende de definir quem faz os conectores.

## v0.90
Decidido: tags são texto livre em minúsculas (sem cadastro de tags). Uma campanha pode ter mais de um projeto (o automático continua sendo criado na campanha nova; pelo botão Projeto dá para criar outro a partir de um modelo ou vincular um existente). As atividades dos blocos vão para o projeto mais antigo da campanha. Modelo guarda os prazos em dias a partir do início do projeto. Pendente: avaliar se a criação automática do projeto na campanha nova deve virar opcional, agora que dá para escolher o modelo pela campanha.

## v0.91
Decidido (Rebecka, 11/10/2026): a criação automática do projeto na campanha nova é opcional, escolhida no formulário da campanha (marcada por padrão, com o modelo padrão). Campanhas que já existem não mudam.

## v0.92
- Pendente (Rebecka): rodar `supabase/RODAR_TUDO_v0.80_a_v0.95.sql (antes v0.91, v0.93 e v0.94)` no SQL Editor. Até lá o cartão continua descontado do saldo em banco e as telas novas (Casa, Fase 1, Fase 2, projetos com tags e modelos) ficam sem os dados do banco.
- Ainda sem resposta: os R$ 1.500 recebidos no cartão em 07/10 (contrato #10 R$ 1.000 e #7 R$ 500, já desfeitos na conta da empresa) e o pró-labore do Rogério pago pelo cartão (R$ 1.000 + R$ 500, lançado contra 2.1.01.01 Conta Pessoal): opção 1, passar para a Conta Mathisa Rogerio, ou opção 2, conta pessoal separada.

## v0.93
- Decidido (Rebecka, 11/10/2026): a Mathisa hoje é MEI e deve passar para o Simples; o regime entra na tela de Custo operacional como opção de simulação (MEI, Simples pelo fator R, anexo III, anexo V ou alíquota manual), sem mudar o cadastro.
- Decidido: corrigir Claude e Servidor N8N para Ferramentas e software, dar centro de custo ao N8N (Sucesso do cliente) e ao Scale Mentoring (Administrativo) e cancelar o tablet duplicado. Feito.
- Pendente (Rebecka): a Contabo tem duas recorrências de R$ 50 ("Servidor N8N" e "Contabo"). São dois servidores ou é cobrança em dobro?
- Pendente: preencher o Cadastro da empresa (regime tributário) e, quando for para o Simples, configurar os impostos sobre as vendas.
- Atenção registrada para a contabilidade: o MEI admite um titular só e limite de R$ 81.000/ano; com o custo atual a operação precisa faturar bem acima disso.

## v0.94
- Decidido (Rebecka, 11/10/2026): meta de margem de lucro líquida de pelo menos 30%, guardada no Planejamento da empresa e acompanhada na tela Custos e margens.
- Decidido: margem de contribuição por produto = receita − imposto − taxas da venda − custo do produto (% da receita e/ou R$ por cliente/mês).
- Pendente (Rebecka): informar o custo direto de cada produto (ex.: Disparos — custo de envio por cliente; Growth's Recorrência — terceirizados da entrega), sem repetir o que já está no Contas a pagar.

## v0.95
- Decidido (Rebecka, 11/10/2026): a meta de margem é definida por ela em três cenários, ruim, bom e ótimo; o bom é a meta (hoje 30%). Ruim e ótimo começam em 20% e 40% até ela mudar.

## v0.96
- Decidido (Rebecka, 11/10/2026): o planejamento de quanto os sócios precisam tirar para a casa (hoje ela fala em R$ 30 mil por mês somando os dois) fica no Growth Model → Unit Economics, como simulação, sem gravar valor fixo no financeiro. Margens do negócio em três cenários: mínima, muito boa e ótima.

## v0.97 — Growth Now (especificação v1.0 de 11/10/2026)
- Decidido (Rebecka): o Growths é a base; a especificação entra em 4 fases em sequência (A cadastros, B Growth Model, C decisão e Kanban, D guardrails), entregando a cada fase. O Growth Loops atual evolui (não é substituído); o Unit Economics vira o lado financeiro do Growth Model; o visual escuro fica para depois.
- Decidido: na Calculadora de campanha só a receita deixa de ser editável; CAC, ROAS e vendas continuam editáveis.
- Decidido: o baseline do Growth Loops fica travado; o que já foi alterado nele vira "premissas do baseline", e um administrador pode reabrir com registro (fase B).
- Pendentes da especificação (seção 16) com padrão adotado até decisão: margem gerencial = Custos e margens (contribuição e lucro líquido); rateio de pacote = % de alocação por produto na oferta; atribuição = último toque nos painéis (v0.89); nome do módulo continua "Growth" no menu.

## v0.98
- Decidido: o baseline fica travado; as alterações antigas no baseline viraram premissas, que só administrador muda com motivo.
- Decidido: Unit Economics e Growth Model compartilham os cenários.
- Pendente (técnico): simular por execução de canal dentro da campanha (hoje a simulação é por loop).

## v0.99
- Padrão adotado (especificação, seção 16 "controles de aprovação e papéis"): quem aprova cenário é o administrador do workspace. Pode virar uma permissão própria depois.
- Planejamento da especificação = projeto em Projetos (lista de atividades, responsáveis, prazos e dependências).

## v0.100
- Guardrails: o Growths nunca pausa campanha sozinho (especificação, seção 9); o alerta só sugere a ação.
- Pendentes da especificação (seção 16) que dependem da Rebecka: limites de cada guardrail; convenções de coorte, churn e LTV (hoje LTV/churn aparecem como indicadores observados, sem simulação); NSM por produto; catálogo inicial de estratégias; contratos de integração; nome do módulo (Growth Now ou Growth's Brain); visual escuro (deixado para depois).
- Versão 0.100: seguimos MAIOR.MENOR.CORREÇÃO; ainda em construção, por isso 0.x.

## v0.101
- Decidido (padrão): o Growth Model abre na aba Cenários e simulação. Pendente: levar cenários também para o Modelo de 12 meses (hoje ele continua com a lógica própria da planilha).

## v0.102
- Decidido: visual azul (escolhido entre 7 paletas mostradas em imagem: vinho/violeta, vinho/laranja, claro com barra ameixa, azul/ciano, verde, índigo/rosa e preto/dourado). Pedido: azul mais escuro.
- Decidido: modo claro e modo escuro escolhidos pela pessoa, guardados no navegador. Padrão: escuro. No claro, a barra lateral continua azul-marinho.
- Pendente: se quiser que a escolha do modo acompanhe a pessoa em qualquer computador, gravar no banco (hoje é por navegador).

## v0.103
- Decidido (Rebecka, 13/10): Growth Model em tela única, aprovada pela imagem de proposta. Topo fixo com receita, mídia, CAC mídia, CAC sem mídia, custo de entrega, lucro, margem e ROI; loops do período com Real | Cenário | Efeito.
- Decidido: o número do cenário vale para todos os meses do loop (com "Ajustar mês a mês" para exceções).
- Decidido: aprovação com ICE, guardrails, histórico, premissas, Modelo de 12 meses, Mapa e Calculadora ficam em "Mais opções", sem remover nada.
- Regra adotada: com filtro de produto ou campanha, custos fixos e CAC sem mídia são rateados pela participação na receita do período (mesma regra do cabeçalho antigo). No cenário, custos fixos não mudam; custo de entrega, taxas e imposto acompanham a receita.
- Pendente: o CAC sem mídia só aparece se as contas de equipe, ferramentas e comissões estiverem marcadas em "Entra no CAC" (Cadastros → Plano de contas). O custo de entrega só aparece se o custo do produto estiver preenchido em Custos e margens.
- ~~Pendente: mudança feita em "Todos os produtos" não aparece quando se filtra um produto~~ (resolvido na v0.104).

## v0.104
- Decidido (Rebecka, 13/10): mudança no cenário feita em "Todos os produtos" tem que aparecer no filtro de cada produto, e vice-versa. O ajuste passa a ser do loop (cada loop já pertence a um produto).

## v0.105 — Retenção & Expansão
Decididas por Rebecka em 15/10, antes de implementar:
- Assinatura ou contrato recorrente: só contrato novo é recompra. Mensalidade não é; renovação ou outro produto em contrato novo é.
- Compras simultâneas: mesmo cliente no mesmo dia = um pedido. Order bump não vira 2ª compra. Configurável em `revops_config.simultanea`: `dia` ou `pedido`.
- Reembolso e chargeback: não contam como compra. Se a 1ª foi reembolsada, a coorte começa na próxima válida. Não existe status de chargeback; ele entra como reembolso.
- A tela nova substitui Cohorts e Ascensão da escada no menu. As funções antigas continuam no banco.

Decisões técnicas:
- Receita: vendas pelo líquido na data da venda + parcelas de contrato não canceladas nem estornadas com vencimento ou recebimento até hoje.
- Imposto de contrato não é descontado por parcela. O MEI/Simples é apurado no financeiro.
- Margem de contribuição só onde há custo cadastrado no produto, mostrando a cobertura. Nunca inventada.
- Produto e categoria do filtro são os da primeira compra. Campanha é a do cadastro do cliente ou, se vazia, a da primeira compra.
- Tempo de resposta: as funções desligam nested loop e JIT. Com 2.000 clientes, cada aba responde em cerca de 0,2 a 0,6 s.

Pendentes:
- Preencher a categoria dos produtos (Cadastros → Produtos) para usar o filtro.
- Preencher o custo dos produtos (Custos e margens) para a margem aparecer.
- Integração com CRM, WhatsApp e automações: as listas e o CSV já saem por segmento; nenhuma campanha é disparada.
- Coortes por análise de sobrevivência (Kaplan-Meier) não foram implementadas. Hoje vale "indisponível até completar o prazo".

## v0.106 — Growth Model em formato de planilha
Decidido (Rebecka, 15/10, depois de ver as imagens de proposta):
- O Growth Model vira uma planilha com Real travado e Cenário editável de cima a baixo.
- As cores mostram o que ela mexeu e o que mudou por consequência.
- Cada campanha abre com todas as etapas. Dá para comparar cenários salvos e dar o ICE.
- O Unit Economics fica como etapa por venda dentro da planilha, e a aba Unit Economics continua por enquanto. Se não agradar, volta-se o `index.html` anterior; os cenários no banco são os mesmos.

Regras adotadas:
- Margem de contribuição = receita − impostos − taxas variáveis − custo de entrega. Mídia, aquisição sem mídia e custos fixos ficam abaixo dela.
- No MEI, o DAS é fixo: o imposto por venda é o DAS dividido pela receita.
- O verde da comparação só marca resultados (receita, margem, lucro, vendas). Custo menor pode ser só menos venda.

Pendentes:
- Recompra e LTV no cenário (taxa de 2ª compra, ticket de recompra, LTV de margem e meta de LTV).
- Meta de retirada dentro da planilha.
- Aposentar a aba Unit Economics, se a planilha resolver.

## v0.107 — Cenários: ciclo de vida e histórico
Decidido (Rebecka, 15 e 16/10, depois de ver o desenho):
- Cenário não se exclui: quem não serve é **descartado**, com motivo, e fica no histórico. Dá para reabrir.
- Status: em estudo, descartado, aprovado, ativo, encerrado e cancelado. Depois de aprovado, quem manda no status é o card do Kanban, para não atualizar em dois lugares.
- A documentação do teste é **link + texto**: o aprendizado curto escrito no Growths e o link do documento completo (Notion, Drive).
- **Cenários** é uma tela própria dentro do Growth (e aba no topo), separada da planilha: a planilha é onde se mexe, Cenários é o histórico.

Regras adotadas:
- Cancelado = card arquivado, ou concluído com decisão "Interromper", sem nunca ter ido ao ar (sem data de início). Se foi ao ar e parou, é Encerrado com a decisão "Interromper".
- Período ativo = data de início do card (quando entrou em Em teste) até a data de conclusão.
- Lucro projetado no histórico = lucro do cenário − lucro real do mesmo período, guardado na última vez em que o cenário em estudo foi aberto na planilha.

Pendentes:
- Lucro realizado no histórico. Hoje o realizado aparece em Resultados e aprendizados como receita × projeção.
- Remover as funções antigas `revops_ascensao` e `revops_cohorts`, que ficaram sem uso desde a v0.105.
- Recompra e LTV na planilha (continua pendente da v0.106).

## v0.108 — Growth reorganizado
Decidido (Rebecka, 16/10):
- O menu Growth fica com 6 itens. Cenários vira uma aba do Growth Model, ao lado da Planilha.
- O Unit Economics sai: a Planilha cobre margem e lucro.
- A Análise de funil sai do sistema.
- O funil do cenário (desenho mostrado em 16/10) não será construído por enquanto. Se ela quiser, traz de volta.

Consequências:
- Payback e a meta de retirada existiam só no Unit Economics e deixaram de aparecer. A meta de retirada e Recompra/LTV continuam pendentes para entrar na Planilha.
- O código das telas antigas (`vSimulador`, `vAnaliseFunil`) ficou no arquivo, sem uso. Remover numa limpeza futura, junto com as funções do banco `revops_ascensao`, `revops_cohorts` e as de análise de funil, se não voltarem.

## v0.109 — Ideias pelo ChatGPT
Decidido (Rebecka, 16/10):
- A IA do celular é o **ChatGPT**. As ideias vão para o **Planejamento de conteúdo**, na etapa Ideia.
- Ordem das próximas frentes: ideias por voz (esta versão), depois o Growths no celular, depois o Instagram.
- Do Instagram ela quer:
  - métricas dos posts;
  - seguidores e perfil;
  - mensagens (DM) como leads;
  - comentários como leads.

Regras adotadas:
- Integração por **GPT personalizado com ação** (esquema OpenAPI) chamando a edge function `ideias`, com uma chave pessoal por workspace.
- A chave é gerada no Growths e mostrada uma vez. Fica só como hash (sha256), dá para revogar e cada uso é contado. Só quem edita o Marketing gera ou revoga chaves.
- Formato desconhecido vira carrossel. O tema só vale se for um tema ativo do mesmo workspace (busca pelo nome exato e depois por parte do nome); se não achar, fica sem tema. Só entram canais válidos.

Limitação conhecida:
- O modo de conversa por voz do ChatGPT não executa ações de GPTs personalizados (fórum da OpenAI, 2026). Use o microfone de ditado.

Pendentes:
- Growths no celular: endereço na internet, instalação na tela inicial e telas ajustadas.
- Instagram: app na Meta (conta Business ou Creator ligada a uma página), sincronização de métricas e perfil, DMs e comentários como leads.

## v0.110 — Auditoria de consistência
Decidido (Rebecka, 17/10): começar pela auditoria antes dos gráficos novos.

Achados, por gravidade (detalhe na planilha `Growths_auditoria_consistencia.xlsx`):
- **Críticos**:
  - lucro do mês diferente no Growth Model e em Custos e margens;
  - imposto real do Growth Model calculado como MEI numa empresa do Simples.
- **Altos**:
  - Dashboard (Administrativo) ignora o período em vendas e receita bruta;
  - Dashboard financeiro mostra sempre o mês de hoje;
  - Custos e margens chama de "receita" o que é a receber pelo vencimento;
  - regime salvo no navegador muda o ponto de equilíbrio.
- **Médios**:
  - três CACs de mídia (cada tela divide por uma coisa);
  - ROAS da tela de marketing com a receita dos leads do período;
  - três LTVs;
  - ticket médio que mistura contratos e order bump;
  - "Clientes" do marketing ≠ clientes novos;
  - telas com janelas padrão diferentes;
  - duas matrizes de fadiga com regras diferentes.
- **Baixos**:
  - janela de 30 dias sem limite final quando a data de referência fica no passado;
  - e-book da campanha contado como venda do curso no Growth Model.

Proposta (aguarda aprovação): uma definição única por métrica, calculada no banco (aba "Definições propostas" da planilha). O regime e as taxas passam para o Cadastro da empresa. Um seletor de período comum.

Pendentes: corrigir as telas pela ordem de gravidade; depois, os gráficos novos (lista de 17/10).

## v0.111 — Correção dos achados críticos e altos
Decidido (Rebecka, 17/10: "pode corrigir"):
- receita e lucro de todas as telas = DRE (competência);
- regime e taxas no Cadastro da empresa;
- imposto real = lançado; estimativa só quando nada foi lançado, marcada como "estimado";
- custo de entrega por produto = premissa de projeção, fora do real.

Pendente (médios e baixos da auditoria):
- definição única de CAC, ROAS, LTV, ticket e clientes novos;
- seletor de período comum;
- uma matriz de fadiga só;
- janelas de 30 dias com limite final;
- e-book da campanha contado como venda do curso no Growth Model.
Depois: os gráficos novos.

Mathisa: o Cadastro da empresa está sem regime e sem impostos configurados. Até preencher, outubro aparece com imposto estimado (DAS do MEI).

## v0.112 — Escola Aurora (dados de teste)
Decidido (Rebecka, 17/10):
- um workspace novo no banco real;
- um lançamento clássico no meio da captação;
- R$ 20 mil de tráfego só na aquisição e cerca de 30 anúncios divididos em campanhas;
- criativos simulados.

Sem preferência de oferta: usamos uma formação nova a R$ 1.997.

Achados ao navegar com esses dados (para a próxima rodada de consistência):
- **Leads da mesma campanha em três números**:
  - 3.027 em Captação e metas: participações, incluindo quem já estava na base;
  - 2.522 em Estratégia e etapas e no Dashboard da campanha: só pessoas novas, mas a taxa sobre os cliques soma os orgânicos;
  - 2.060 em Mídia paga: só pessoas novas vindas de anúncio.
- **Dashboard da campanha**: a meta diária de leads divide 5.000 pelos 46 dias da campanha (108/dia). O certo é usar a fase de captação, 26 dias (192/dia).
- **Metas por tipo**: "fora" com 60% da meta quando já passaram 62% do tempo. Falta a leitura de ritmo (no ritmo, adiantado, atrasado).
- **Links de canal orgânico viram "anúncios"**: o gatilho `campanha_link_valida` cria um anúncio para cada link, e eles aparecem no ranking de criativos. Na Escola Aurora os orgânicos ficaram sem link.
- **Repositório × produção**: 24 funções diferentes. O repositório tem a migração do "modo financeiro" (`fin_completo`, `definir_modo_financeiro`), que nunca rodou em produção, e versões de `registrar_recebimento`, `registrar_pagamento`, `ativar_contrato`, `processar_venda`, entre outras, que dependem dela. Pendente: decidir se a migração vai para produção ou se o repositório volta para as versões de produção.

## v0.113 — Receber leads
Decidido (Rebecka, 17/10): leads vêm do formulário da página de captura, da Respondi e do Meta Lead Ads. As vendas vêm do Conta Azul.
- **A campanha precisa existir antes?** Para ligar sozinho, sim: precisa existir o canal com a `utm_campaign`. Quando o lead chega antes, entra em Pessoas sem campanha, e a resposta avisa. Depois de criar o canal, "Religar leads" liga esses leads, com a data do cadastro.
- **Chave no endereço (`?chave=`)**: a Respondi e o formulário HTML não mandam cabeçalho. Por isso a chave de leads só grava leads e não lê nada. Se vazar, o pior caso é lead falso; aí basta revogar e gerar outra. O campo-isca `website` barra robôs simples.
- **Meta**: o caminho recomendado é o Zapier/Make, com um zap por formulário e a `utm_campaign` no endereço. O webhook nativo já é aceito, mas precisa de app no Meta for Developers, de revisão da permissão `leads_retrieval` e do segredo `META_ACCESS_TOKEN`; com um token só, atende um negócio.
- **Pendente: vendas do Conta Azul**. A API não tem webhooks, então a função vai buscar as vendas de tempos em tempos. Precisa de:
  1. app de desenvolvedor no Conta Azul (client_id e client_secret);
  2. login OAuth uma vez para guardar o refresh token como segredo;
  3. função agendada a cada 15–30 min;
  4. ligação dos produtos do Conta Azul aos produtos do Growths;
  5. cliente (e-mail/telefone) → pessoa, para a atribuição de origem.
- Pendente: na Respondi, conferir o formato real do webhook com um envio de teste. A leitura foi feita para `respondent.answers`, `raw_answers` e `respondent_utms`.

## v0.114 — Meta de leads e gráficos da campanha
Pedido da Rebecka (19/10):
- acompanhar a meta de leads por dia, com gráfico de linha;
- ver por mês se está dentro ou fora da meta;
- gráficos menores, lado a lado;
- % de conversão entre as etapas do funil;
- meta de leads por canal, com acompanhamento.

Decidido:
- **Lead na meta = participação na campanha**: cada pessoa uma vez, inclusive quem já estava na base. É a conta de Captação e metas e da coluna "Leads (meta)" dos canais. O e-mail para a base e o orgânico trazem muita gente que já existia; contar só os novos punia esses canais (ex.: e-mail 80 de 420, quando na verdade são 398).
- **Meta diária pela captação**. No lançamento, a meta de leads é da captação. Sem as datas da fase, vale a campanha inteira.
- **Esperado até hoje**: o dia de hoje entra pela fração já passada, para não marcar "abaixo" de manhã.
- **Situação**: no ritmo (100% ou mais do esperado), perto (85% a 99%) ou abaixo (menos de 85%). Mês fechado: dentro ou fora.
- **Taxas das métricas de diagnóstico**: cada uma tem uma regra fixa por chave (`ML_TAXAS` no front). Por exemplo, CTR = cliques ÷ impressões e connect rate = visitas ÷ cliques. Métrica sem regra continua sem taxa.

Pendente:
- O CPL e o "Lead → venda" do Dashboard ainda usam os leads novos (`v_marketing_campanha`). Resolver junto com a unificação das três contagens de leads (ver v0.112).
- Campanha recorrente: o gráfico por dia mostra os últimos 60 dias, e o histórico de meses completo continua em "Metas mensais".

## v0.115 — Detalhe ao clicar nos cards
Pedido da Rebecka (19/10): dentro da campanha, cada número clicável deve levar ao detalhe (por canal, gráficos, qualificação), para tudo ficar rastreável.

Decidido:
- O detalhe abre numa janela grande, sem trocar de tela, com botões para os outros indicadores. Clicar num canal volta ao Dashboard filtrado nele.
- A venda vai para o canal por onde o comprador entrou na campanha. Se não houver participação, vale o `utm_campaign` dele.
- **Investimento**: custo dos anúncios quando houver; senão, contas a pagar e custos de CAC dos canais. É o mesmo critério dos gráficos da campanha. Por isso o investimento por canal aqui pode ser diferente do que aparece na tabela antiga "Por canal: vendas, investimento e custos" (`v_marketing_canal`), que soma só contas a pagar. Pendente: alinhar a view.
- A função roda como dona (sem o custo das políticas linha a linha, que levava 1,2 s; agora 0,1 s). Para isso, ela exige ser do workspace e poder ler o Marketing.

Observação: em produção, a campanha da Escola Aurora tem 2.550 leads novos, e o banco de teste tem 2.522. É uma diferença entre os dois bancos, presente em todas as telas, e cada banco é coerente consigo mesmo.

## v0.116 — Árvore dos números
Pedido da Rebecka (19/10): em todo o sistema, clicar num número mostra como ele foi gerado e permite ir descendo nível por nível. Escolhas dela: começar por Marketing e campanhas, Dashboard, Financeiro e Vendas/RevOps, com o detalhe num painel lateral com trilha.

Decidido:
- **Um motor só, no banco** (`arvore_no`). Cada nó devolve:
  - o valor e a explicação;
  - a fórmula, com as partes clicáveis;
  - as quebras, com os itens clicáveis;
  - os registros.

  O front só desenha. Assim, a mesma conta vale em todas as telas.
- **Regras iguais às das telas**:
  - resultado pela DRE (partidas por data do fato);
  - vendas pela data da venda;
  - Dashboard de marketing pela coorte de leads do período, com receita líquida;
  - Mídia paga pelos números dos anúncios;
  - campanha por participações e cadastros novos.

  A tela de Vendas e o Dashboard de vendas contam contratos fechados como venda, e a árvore também conta.
- **Conferência**: a raiz da árvore tem que dar o número do card. Quando não der, o painel avisa e mostra os dois.
- **Acesso**: o nó exige ser do workspace e ter leitura do módulo (financeiro, vendas ou marketing).

Pendente (próximas partes da árvore):
- **Dashboard**: CAC por grupo, NRR, GRR e penetração.
- **Dashboard de marketing**: LTV e churn.
- **Dashboard financeiro**: caixa projetado em 30 dias.
- **Custos e margens**: os outros cards.
- **Contas a receber e a pagar**: os cards de período e de atraso. O motor já tem `fin.receber` e `fin.pagar`; falta ligar.
- **Contratos**, **RevOps (Retenção & Expansão)**, **Growth Model** e as tabelas (hoje só os cards abrem a árvore).
- **Lançamento contábil e conta a pagar**: o último nível ainda é a linha do lançamento. Falta abrir o próprio registro, como já acontece com a ficha da pessoa.

## v0.120 — Comissões e conexões
**Comissões**
- **Onde fica**: a configuração (Quem recebe e Regras) fica em Configurações → Comercial e produtos → Comissões (pedido da Rebecka: "tudo que for configuração fica em Configurações"). O acompanhamento (Resumo do mês, Extrato e fechamento) fica em Vendas → Comissões, com o atalho "Configurar comissões". As duas telas usam a mesma função (`vComissoes`), e as abas mudam conforme o menu.
- **Quem recebe fica na Equipe** (com o vínculo), e não numa tabela nova. O vendedor da venda (`vendas.vendedor_id`) já apontava para a Equipe. Assim a mesma pessoa é "quem vendeu" e "quem recebe".
- **Regra mais específica vence** para a mesma pessoa; pessoas diferentes somam (decisão da Rebecka, 20/10).
- **Base, "sobre quais vendas" e forma de pagamento são da regra** (decisão da Rebecka: "quero poder definir essa regra"). O vendedor sugere "só as vendas dele"; coprodutor e estrategista sugerem "todas".
- **Comissão lançada não muda sozinha.** Mudar a regra refaz só as previstas. A exceção é a regra "por venda" com a conta ainda não paga, que acompanha o novo valor.
- **Venda devolvida depois de lançada vira estorno pendente**, descontado no próximo fechamento da pessoa. Se os estornos forem maiores que as comissões do mês, nada é lançado e o saldo fica para o mês seguinte.
- **Parcela de contrato** gera comissão quando é recebida. Na regra por produto, conta só a parte da parcela que cabe aos itens daquele produto. Oferta não se aplica a contrato.
- O vencimento é o dia escolhido na regra, no mês seguinte à competência. A conta contábil é a 6.2.03 "Comissões e afiliados" (ou a primeira despesa com "comiss" no nome).

**Conexões**
- **Uma função para tudo** (`conexoes`): login, retorno, sincronizar e desconectar. Os tokens ficam em `privado.conexao_tokens`, fora da API. Só a função (service_role) lê.
- **O pedido de login usa um código de uso único** guardado no banco (`privado.conexao_estados`, vale 15 minutos), e não uma assinatura com segredo. Menos um segredo para cadastrar.
- **Anúncios entram primeiro numa tabela própria** (`ads_externo_dia`) e só depois em `anuncios` e `metricas_anuncio_dia`, quando a campanha está ligada a um canal. Assim nenhum dado se perde enquanto o vínculo não é feito.
- **Instagram**: a API atual só dá série por dia para o alcance. Visualizações e cliques no link são pedidos dia a dia (até 31 dias por vez). "Impressões" foi descontinuada pelo Meta e não é usada.
- O acesso do Meta vale cerca de 60 dias; o do Google se renova sozinho (refresh token).

**Pendente**
- **Aplicar em produção**: a aplicação foi cancelada antes de rodar, e ficou para a Rebecka decidir entre eu aplicar ou ela rodar o RODAR. Falta também publicar a função `conexoes`.
- Criar o app do Meta, o projeto do Google e o token do Google Ads, cadastrar os segredos e o agendamento (`docs/conectar-meta-e-google.md`).
- Página do Facebook (orgânico) ainda não sincroniza; só serve de ponte para o Instagram.
- Mostrar os dados orgânicos (`social_perfis_dia` e `social_posts`) nas telas de conteúdo e no dashboard.
- Comissões na árvore dos números e no CAC (grupo "comissão").
- Comissão "quando o dinheiro entrar" (hoje é na aprovação da venda).

## v0.119 — Árvore, parte 4
- **Nós montados no navegador** (`loc.*`): os cards de custo de Custos e margens dependem de escolhas guardadas no navegador ("Contar no custo", regime da simulação, % variável). Refazer essa conta no banco daria outro número. Por isso a tela guarda uma foto do que calculou (`ARV_CO`) e a árvore monta esses nós a partir dela. Do item em diante, a árvore volta para o banco (conta a pagar → lançamentos).
- Se a foto não for do mesmo mês (ou a tela não foi aberta), o nó local mostra uma mensagem pedindo para abrir a tela de novo, em vez de mostrar um número que pode não bater.
- **MRR**: Contas a receber passou a usar o horário de São Paulo na data de cancelamento (pendência da v0.117 resolvida).
- **Em produção**, `_arv_extra` e `receber_periodo` foram ajustadas trocando só os trechos, com conferência.
- **Scripts que trocam trechos de função** precisam aguentar ser colados de novo no editor do Supabase. Cada troca tem 4 partes: função, trecho antigo, trecho novo e uma **marca curta** de "já aplicado". As quebras de linha do Windows (`\r`) são retiradas antes de comparar. Motivo: em 20/10, rodar de novo o RODAR v0.118 duplicou o bloco "Origem" em `_arv_extra`, e o v0.119 parou com "Trecho não encontrado". O bloco repetido foi removido em produção.

Ainda pendente na árvore:
- Custos e margens: Receita líquida (%), "Falta para o cenário" e a tabela da DRE por produto;
- RevOps (Retenção & Expansão) e Growth Model;
- tabelas do Fechamento da campanha e da DRE;
- contrato como nó próprio (hoje a origem mostra só o número).

## v0.118 — Árvore, parte 3
- **Células de tabela**: um único mapa por tela (`arvColunas`) diz o seletor das linhas, os parâmetros da linha e qual cabeçalho vira qual nó. A célula para o clique (não abre a campanha) e manda o próprio texto para o aviso de diferença.
- **Coortes por mês e semana**: a linha leva o intervalo da coorte cortado pelo período escolhido (`data-arvp`), porque é assim que a coorte é calculada.
- **Investido da tabela Campanhas ativas** não é o gasto de anúncios: vem das contas a pagar e dos custos de aquisição ligados à campanha, desde o início (`v_marketing_campanha`). Por isso ganhou nó próprio (`mkt.camp_total`), em vez de usar o de Mídia paga.
- O aviso de diferença ignora arredondamento: se o número da tela é o da árvore com menos casas, não há aviso.
- **Em produção**, `arvore_no`, `_arv_vendas`, `_arv_caixa` e `_arv_extra` foram ajustados trocando só trechos (com conferência); `_arv_extra2` foi criada inteira.

Ainda pendente na árvore:
- Custos e margens: Pró-labores, Fixo, Variável, Ponto de equilíbrio e os outros cards com estimativa;
- RevOps (Retenção & Expansão) e Growth Model;
- tabelas de outras telas (Mídia paga por anúncio, Fechamento da campanha, DRE);
- o lançamento de recebimento ainda não mostra a origem (a parcela e a venda);
- alinhar o MRR de Contas a receber (UTC) com o do Dashboard (São Paulo).

## v0.117 — Árvore, parte 2
- O último nível do razão é o **lançamento** (partidas dobradas), e dele se chega à pessoa. Antes, a linha ia direto para a ficha.
- Os nós novos ficam numa função à parte (`_arv_extra`), e `arvore_no` passa para ela o que não conhece. Assim cada parte nova não mexe nas anteriores.
- **Em produção**:
  - `_arv_razao` e `arvore_no` foram ajustados trocando só os trechos mudados no próprio banco (`pg_get_functiondef` + `replace`, com conferência), sem colar as funções inteiras;
  - `_arv_caixa` e `_arv_extra` foram aplicadas inteiras.
- **Achado**: em Contas a receber, o MRR usa a data de cancelamento em UTC, e o Dashboard usa a de São Paulo. A diferença só aparece num cancelamento perto da meia-noite. Pendente alinhar.

Ainda pendente na árvore:
- Dashboard financeiro: caixa projetado em 30 dias;
- Custos e margens: Pró-labores, Fixo, Variável, Ponto de equilíbrio e os outros cards com estimativa;
- Dashboard de vendas: Novos em 30 dias e A qualificar;
- RevOps (Retenção & Expansão) e Growth Model;
- números dentro das tabelas (hoje só os cards abrem a árvore);
- abrir a conta a pagar e a venda como registro próprio.

## v0.121 — Visual e campanha em etapas
**Decisões (Rebecka, 21/10)**
- Manter o azul de hoje, nos modos claro e escuro, com destaque de cor: verde no que é bom, vermelho no negativo, brilho neon. A proposta com as cores da Mathisa (vinho) e a seta dourada do SAP B1 foi vista e descartada.
- Manter o efeito 3D ao passar o mouse; o clique no número continua abrindo a origem como antes (sem seta).
- Modo claro como padrão; escuro como opção.
- Dashboard com a hierarquia da prévia aprovada ("O que importa agora" + cartões menores).
- Nova campanha em etapas (salvar e continuar), com as metas detalhadas na página da campanha para não virar uma lista longa.
**Escolhas técnicas**
- A cor por sinal é aplicada depois de desenhar a tela (um observador olha o conteúdo novo), então vale para todas as telas sem mexer em cada uma.
- CAC total ficou sem tendência mensal: calcular o CAC de cada mês exigiria uma consulta por mês. Fica para quando houver uma função de série no banco.
- A etapa 3 não apaga canais desmarcados que já existiam (evita perder metas e links); para tirar um canal, use a seção Canais da campanha.
- "Editar campanha" continua com o formulário único (agora em blocos); só a criação virou etapas.
**Pendências**
- Aplicar em produção `RODAR_v0.120_comissoes_conexoes.sql` e depois `RODAR_v0.121_arvore_vendedor.sql`.
- Próximas melhorias propostas: tela simples do cliente (só leitura, celular), busca rápida (Ctrl+K) e caminho "de onde vim" no alto das telas.
