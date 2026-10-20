# Regras de negócio

## Taxa da plataforma

Cada componente da taxa (percentual e valor fixo) segue esta prioridade, do mais específico para o mais geral:

1. Taxa diferenciada do **produto** (`taxa_percentual_override`, `taxa_fixa_override`)
2. Taxa da **forma de pagamento** na plataforma (`plataforma_formas_pagamento`)
3. Taxa **padrão da plataforma** (`plataformas_venda`)

`taxa = valor bruto × percentual ÷ 100 + valor fixo`, arredondada a 2 casas.

## Imposto

Soma de todas as alíquotas ativas em `impostos_config`, cada uma sobre o valor bruto ou sobre o valor após a taxa, conforme a base configurada.

## Valores de uma venda

| Campo | Cálculo |
| --- | --- |
| `valor_bruto` | Preço pago pelo cliente |
| `taxa_plataforma` | Regra acima |
| `valor_a_receber` | Bruto menos taxa (o que a plataforma repassa) |
| `impostos` | Regra acima |
| `valor_liquido` | A receber menos impostos |

Exemplo (valores de exemplo do seed): venda de R$ 497,00 → taxa de R$ 50,20 (9,9% + R$ 1,00), imposto de R$ 29,82 (6%), a receber R$ 446,80, líquido R$ 416,98.

## Previsão de recebimento

`data_prevista_recebimento = data da venda + prazo_recebimento_dias` da forma de pagamento (por exemplo, Pix 0 dia, boleto 3 dias, cartão 30 dias nos valores de exemplo). O fuso usado é o de São Paulo.

## Partidas contábeis

Venda aprovada gera um lançamento com as partidas abaixo (contas do plano padrão, editáveis em `regras_contabilizacao`):

| Evento | Débito | Crédito | Valor |
| --- | --- | --- | --- |
| `venda_receita` | 1.1.02 Contas a receber – plataformas | 4.1.01 Receita de vendas | Bruto |
| `venda_taxa_plataforma` | 5.1.01 Taxas de plataformas | 1.1.02 Contas a receber – plataformas | Taxa |
| `venda_imposto` | 5.1.02 Impostos sobre vendas | 2.1.02 Impostos a recolher | Imposto |
| `recebimento` | Conta contábil do banco | 1.1.02 Contas a receber – plataformas | A receber |
| `estorno_pagamento` | 1.1.02 Contas a receber – plataformas | Conta contábil do banco | A receber |

O centro de custo da venda é o do produto. O banco confere que débitos e créditos de cada lançamento fecham antes de gravar.

## Cliente e aluno

- Ao aprovar uma venda, a pessoa vira **cliente ativo** (e vai para a etapa "Cliente" do Kanban de leads) e é criado um **aluno** com a tag do produto, na primeira etapa do Kanban de alunos.
- Quem já era cliente inativo e compra de novo volta a ser ativo.
- A origem (UTMs e campanha) da pessoa não muda; a venda herda a campanha da pessoa.

## Cancelamento, reembolso e chargeback

`registrar_estorno` faz, na mesma operação:

1. Cria um lançamento que **inverte** todas as partidas da venda original
2. Se o dinheiro ainda não tinha entrado, a conta a receber vira "cancelado"
3. Se já tinha entrado, devolve da conta bancária: saída bancária e partidas de devolução
4. Atualiza a venda (cancelada, reembolsada ou chargeback), o aluno (cancelado) e a pessoa (inativa, se não tiver outra venda aprovada)

Nada é apagado: o histórico contábil continua inteiro.

## Qualificação do lead

A pessoa tem `qualificacao` (pendente, qualificado ou não qualificado), `pontuacao_qualificacao` e `respostas_pesquisa` (JSON com as respostas da página de obrigado). Hoje a pontuação é manual. Toda mudança fica em `pessoa_historico`.

## Contas a pagar

- Ao lançar uma conta a pagar, o banco registra a despesa na **competência** (padrão: o vencimento): débito na conta de despesa escolhida e crédito em 2.1.01 Fornecedores a pagar.
- `registrar_pagamento` baixa a obrigação (débito em 2.1.01, crédito na conta bancária) e cria a saída bancária.
- `cancelar_conta_pagar` só vale para conta ainda não paga e inverte o lançamento original.
- Contas ligadas a uma campanha ou canal formam o **investimento** usado no CPL, CAC e ROAS.

## Métricas de marketing (views)

| Métrica | Cálculo |
| --- | --- |
| CPL | investimento ÷ leads da campanha |
| CAC | investimento ÷ clientes distintos com venda aprovada na campanha (recompra não conta duas vezes; reativação ainda não é distinguida) |
| ROAS | receita bruta aprovada ÷ investimento |
| Lead → venda | vendas aprovadas ÷ leads |

O rateio de custos comuns entre canais ainda está em aberto (pergunta 13).

## Venda direta

Venda sem plataforma (atendimento do vendedor) não tem taxa de plataforma e vence na data da venda. Imposto e contabilização seguem a regra normal.

## Conversão manual

No cadastro de clientes é possível marcar uma pessoa como lead, cliente ativo ou cliente inativo. Na integração completa, a campanha cria o lead e a venda aprovada converte em cliente sozinha.

## Contabilidade imutável
- Lançamentos e partidas não podem ser editados nem apagados (trava no banco).
- Correção só por estorno, que cria um lançamento novo com débito e crédito invertidos. O original fica no histórico e é marcado como estornado. Um lançamento só pode ser estornado uma vez.
- Venda: estornar pela venda (reembolso, cancelamento, chargeback). Conta a pagar: cancelar a conta. Lançamento manual: estornar na tela de lançamentos. Recebimentos e pagamentos ficam travados.

## Jornada do funil de lançamento
- Entrar em uma lista também coloca a pessoa nas listas "pai" (entrar na API coloca no grupo) e aplica a etapa de cada uma.
- Sair da API tira só da API e das dependentes. Sair do grupo (lista que reinicia a jornada) tira de todas as listas e volta a pessoa para a etapa de cadastro.
- Venda aprovada move a pessoa para a etapa de compra do funil.

## Tráfego e atribuição
- Leads e vendas voltam para o criativo por utm_campaign + utm_content. CAC = investimento ÷ clientes distintos. Razões (CTR, CPC, connect rate, conversão, CPL, ROAS) são calculadas por código, nunca por IA.

## Growth Model e ciclo de experimentos
- Métrica automática é calculada por código a partir dos dados do sistema (receita, leads, investimento, CPL, vendas, ticket, CAC, ROAS, conversão lead → venda, clientes ativos), nos últimos 7, 30 ou 90 dias, comparada ao período anterior de mesmo tamanho. Conversão = vendas aprovadas ÷ leads do período. Investimento usa o custo diário dos anúncios e, se não houver, as contas a pagar de campanha.
- Gargalo sugerido: entre as métricas com meta (exceto a North Star), a que tem menor atingimento abaixo de 100%. Para métricas em que menor é melhor, atingimento = meta ÷ valor. É uma pista, não uma conclusão.
- Experimento só vai para "Rodando" com hipótese (o início é preenchido com a data de hoje se vazio) e só vai para "Aprendizados" com resultado e aprendizado.

## Projetos e atividades
- Criar campanha cria o projeto "Campanha: nome" com o modelo marcado como padrão das campanhas. Sem modelo, o projeto nasce vazio.
- O responsável de cada atividade do modelo é a pessoa fixa ou, se não houver, a primeira pessoa ativa da equipe com a mesma função. Sem ninguém com a função, a atividade fica sem responsável e não avisa ninguém.
- Atividade nasce bloqueada. Libera quando todas as atividades de que depende estão concluídas ou canceladas e, se for subatividade, quando a principal está liberada. Bloqueada não pode ser iniciada nem concluída; dependência circular é recusada.
- A atividade principal com subatividades conclui sozinha quando todas as filhas terminam e não pode ser concluída à mão antes disso.
- Ao liberar, o responsável recebe um aviso por canal marcado na Equipe. App é imediato; e-mail e WhatsApp ficam pendentes na fila até haver provedor de envio.
- O projeto vira concluído quando todas as atividades terminam e volta a em andamento se entrar atividade nova.
- Link de tracking: utm_campaign vem do canal da campanha; o utm_content liga o link ao criativo do tráfego.

## RevOps
- Pessoa ativa em uma data: tem pelo menos uma matrícula que já tinha começado e ainda não tinha saído.
- Churn mensal: ativas há 30 dias que hoje não estão ativas ÷ ativas há 30 dias. Retenção em 90 dias: das pessoas que entraram há pelo menos 90 dias, as ativas 90 dias depois de entrar.
- LTV: receita líquida das vendas aprovadas ÷ clientes com venda aprovada. Reembolsos ficam de fora.
- Ascensão: compra de produto de nível maior que o maior já comprado. Taxa = clientes que subiram ÷ clientes cuja primeira compra está abaixo do topo da escada.
- Semáforo: verde dentro da meta; amarelo até a tolerância (padrão 15%) pior; vermelho além. Metas padrão: churn até 6%, retenção 90 dias a partir de 85%, LTV a partir de R$ 600, ascensão a partir de 15%.
- Simulação: workspace separado com dados fictícios; apagar o workspace remove tudo.

## Planejamento de conteúdo
- Nota: 5 critérios de 1 a 10 (nomes editáveis). Média simples com uma casa, calculada no banco. Ideia e pauta têm cada uma a sua nota.
- Etapas e o que cada uma exige: pauta (5 notas da ideia e tema); produção (5 notas da pauta e ao menos um canal); pronto (link da copy e link da mídia); agendado (data de publicação). Arquivar não exige nada.
- Ordem das listas: maior média primeiro; empate pela prioridade do tema e depois pela data de criação.
- Vagas da semana = soma das metas por formato menos o que está em produção ou pronto. "Produzir agora" marca as pautas de maior nota até esse número. É sugestão, a decisão é da pessoa.
- Plano semanal: conta conteúdos prontos, agendados ou publicados com data de publicação dentro da semana (segunda a domingo), por formato, contra a meta.
- Engajamento = (curtidas + comentários + compartilhamentos + salvamentos) ÷ alcance. Publicação sem alcance fica fora do denominador.
- Ao agendar ou publicar, a tela cria a publicação de cada canal marcado.

## Análise de funil
- Lead = pessoa cadastrada no período; a coorte é seguida até hoje. Etapa alcançada = entrou nela alguma vez (histórico do funil). Cliente = venda aprovada.
- Conversão de um passo = pessoas no passo ÷ pessoas no passo anterior. Qualificados e respondentes de pesquisa são laterais e comparam com os leads.
- Gargalo = passo com maior queda de conversão contra o período anterior de mesmo tamanho (queda de 15% ou mais, base de 10 ou mais). Maior perda = passo com mais pessoas que não passaram. São sugestões.
- CPL e CAC ficam vazios quando não há custo. Funil automático = o da campanha, ou o com mais gente.
- Cohort: conversão acumulada em 7, 14, 30, 60 e 90 dias a partir da entrada; janela só é completa quando o lead mais novo da coorte já tem essa idade.

## Pesquisas
- O gatilho gera um envio por pessoa e pesquisa (nunca duplica). Com "dispensar qualificados", quem já está qualificado fica como dispensado.
- NPS = (promotores 9 e 10 menos detratores 0 a 6) ÷ respostas × 100. PMF = parcela da primeira opção da pergunta de papel PMF; referência de 40%.
- Resposta de pesquisa de lead grava as respostas no cadastro da pessoa e marca a data de resposta.
- Cada link é único por envio; o link aberto só funciona se ligado na pesquisa.

## Cohorts do RevOps (v0.21)
- Coorte: cada pessoa entra na coorte na data da sua primeira matrícula (aluno). Campanha, origem e UTM vêm do cadastro da pessoa; produto e tag são os da primeira matrícula.
- Retenção no ponto k: pessoas com matrícula ativa (entrou até o ponto e não saiu até o ponto) ÷ pessoas que já chegaram ao ponto k. Só entram no cálculo as pessoas que já completaram k meses (ou semanas); células com coorte incompleta aparecem em itálico.
- Recompra: pessoas com 2 ou mais vendas aprovadas até o ponto ÷ pessoas que chegaram ao ponto.
- Receita acumulada por pessoa: vendas aprovadas (valor líquido) + parcelas de contrato recebidas (sem venda associada) até o ponto ÷ pessoas que chegaram ao ponto.
- Linha "Todas": média ponderada pelo número de pessoas elegíveis em cada ponto.
- Ações de recebimento, pagamento e estorno ficam só nos módulos Vendas e a receber e Contas a pagar; o Painel gerencial só permite ver o lançamento.

## Funções e permissões (v0.22)
- Níveis por módulo: Sem acesso, Só consultar, Consultar e editar. Administrador tem acesso total e é o único a editar empresa, funções e acessos.
- Membros antigos, sem função, mantêm o comportamento anterior: papel admin/editor = editar, leitor = consultar.
- Um módulo pode precisar ler dados de outro (nome do cliente no financeiro, campanha no CAC). Por isso as tabelas compartilhadas aceitam leitura por mais de um módulo (ver mapa na migração). Escrita sempre exige "editar" no módulo dono.
- Não é possível remover nem rebaixar o último administrador.
- Só administradores concedem acesso. Acesso nasce do cadastro em Equipe e acessos (e-mail + função) e vale quando a pessoa entra no sistema com o mesmo e-mail.
- Cadastro da empresa: CNPJ deve ter dígitos verificadores válidos; fim do exercício não pode ser antes do início. O período contábil atual é calculado a partir do início do exercício e da periodicidade de fechamento (código fixo).

## Ascensão da escada (v0.23)
- Por pessoa: produtos distintos ordenados pela data da primeira compra aprovada. Transição = produto seguinte diferente na sequência (pular degrau conta como a transição direta).
- % de uma transição = pessoas que seguiram ÷ pessoas que compraram o produto de origem. "Ficou por aqui" = sem nenhum produto novo depois. Caminho = sequência completa, em % de todas as pessoas.
- "Mínimo de dias": só entra na base quem comprou o produto de origem há pelo menos N dias.
- Cálculo determinístico no banco; nada de IA.

## Responsáveis e vendedor (v0.23)
- Toda troca de comercial ou CS fica gravada no histórico, com autor e data; o histórico não é editável pela tela.
- Venda/contrato novo grava o comercial do lead como vendedor, salvo informado. A troca posterior de responsável não reescreve vendas antigas (quem vendeu continua quem vendeu).
- Nova matrícula de quem já tem CS herda o CS mais recente.

## Rateio de custos e CAC (v0.24)
- Valor rateado = valor da conta a pagar × percentual do centro ÷ 100. A soma da regra precisa ser 100%; regra que não soma 100% é ignorada.
- Regra usada: a da conta a pagar; se vazia, a do plano de contas; se vazia, 100% no centro da conta.
- CAC e CAC de mídia somam só os custos de aquisição (grupo "Entra no CAC" da conta contábil) cuja parte caiu em centros com "Entra no CAC" marcado. O que cai em CS ou Administrativo fica fora e aparece no painel.
- O rateio é gerencial: não altera os lançamentos contábeis nem a DRE.

## Permissões por ação (v0.24)
- Ordem de decisão para cada ação: ação da pessoa, depois ação da função, depois o nível do módulo (editar libera tudo; consultar libera só ver). Administrador sempre pode.
- "Criar só lead" permite inserir cliente apenas com status lead.
- Nível de módulo individual (equipe.permissoes_ind) vence o da função. Só administrador altera.
- Ações detalhadas valem para as 9 tabelas principais; tabelas auxiliares (histórico, itens etc.) seguem o nível do módulo.

## Módulo financeiro opcional (v0.29)
- Padrão 'completo': tudo como antes. 'simplificado': só vendas, contas a receber e custos para o CAC; sem banco, contas a pagar, lançamentos, DRE, fluxo de caixa.
- CAC total = mídia + demais custos de aquisição (contas a pagar nos centros "Entra no CAC" **e** custos lançados em Custos para o CAC). Custo com regra de rateio só conta a parte dos centros marcados "Entra no CAC"; sem regra, entra inteiro. Cálculo sempre no banco.
- Recebimento no modo simplificado marca a parcela como recebida sem escolher banco; não existe saldo.

## Uso da plataforma (v0.30)
- Abertura de tela conta uma vez por visita à tela (recarregar a mesma tela depois de salvar não conta de novo). Tempo conta só com a aba visível, no máximo 30 min por visita.
- Desistência de formulário = cancelados ÷ abertos. Taxa de erro = erros ÷ aberturas da tela. Sinal de trava: desistência ≥ 50% ou erro ≥ 20%, com pelo menos 3 ocorrências. Tudo calculado no banco/`uso_resumo`; sem IA.

## Provisão de contas a pagar (v0.32)
- Só entram fornecedores ativos com "provisão automática" ligada, com dia de vencimento e conta de despesa. Valor: fixo = valor padrão; variável = média das últimas 3 contas não canceladas e já confirmadas, senão o valor padrão; sem nenhum dos dois, não gera (e avisa).
- Gera os próximos 2 vencimentos a partir de hoje (o do mês atual só se o dia ainda não passou). Dia 31 em mês curto vence no último dia. Não duplica por (fornecedor, competência), mesmo que a conta tenha sido cancelada.
- Conta variável nasce "estimada" e já lança a despesa na DRE pelo valor estimado (competência). Ao confirmar um valor diferente, o lançamento é estornado e refeito com o valor real; o histórico fica (conta antiga cancelada, ligada à nova). Conta estimada não pode ser paga.
- Pró-labore é tratado como despesa administrativa; encargos (INSS, IRRF) não são calculados.

## Compra parcelada (v0.33)
Parcelas de 2 a 60, mensais, mesmo dia de vencimento (último dia do mês se o mês for curto). Valor informado como total é dividido em centavos, com a sobra na última parcela; como valor da parcela, é repetido. Competência de cada parcela = mês do vencimento (ou, se informada, a competência da 1ª avançando um mês por parcela). Cada parcela é uma conta a pagar independente.

## Contas recorrentes (v0.34)
Três tipos: **fixa** (valor mensal combinado), **variável** (estimativa = média das últimas 3 contas confirmadas daquela recorrência, senão o valor informado; nasce "estimada") e **parcelada** (valor total dividido em centavos, sobra na última; 2 a 120 parcelas, mensais). Dia do vencimento = dia do primeiro vencimento (último dia em mês curto). Fixa/variável: gera os próximos 2 vencimentos até a data final, se houver. Idempotente por (recorrência, competência); conta cancelada pode ser regerada. Mudar uma recorrência não altera contas já geradas. A recorrência é definida no cadastro do fornecedor (uma por fornecedor); a função espelha o cadastro numa linha de `despesas_recorrentes` e gera as contas dela.

Recorrente criada em Nova conta a pagar: vale sem data final até alguém clicar em Parar recorrência (para só de gerar as próximas; as existentes ficam). A 1ª conta nasce na hora; as seguintes, nos próximos 2 meses a cada abertura do financeiro. Cancelar a conta de um mês não faz o mês voltar. O fornecedor é opcional nesse caminho; o rateio e a campanha não são copiados para as contas seguintes.

## Campanha recorrente e metas mensais (v0.35)
Vale para campanhas do modelo recorrente (sem fim). Meta mensal padrão = leads por mês + mix (vendas por mês de cada produto). Faturamento esperado = soma(vendas × preço); ticket médio = faturamento ÷ vendas; conversão necessária = vendas do mix ÷ leads. Meta diária de leads = leads do mês ÷ dias do mês; no mês atual, esperado até hoje = meta diária × dia do mês. Ajuste de um mês: leads próprios e/ou total de vendas próprio (o mix escala na proporção e o faturamento usa o ticket médio do mix). Realizado: leads = pessoas ligadas à campanha por data de cadastro; vendas e receita = vendas aprovadas da campanha por data da venda (fuso de São Paulo). A janela mostra do mês de início até 12 meses (ou o mês atual, se maior), no máximo 36.

## Baixa parcial (v0.36)
Pagamento: valor menor que a conta divide a conta em duas (paga e "(saldo)"), preservando competência, vencimento, conta de despesa, centro, rateio e forma. O valor total da despesa e o mês em que ela pesa na DRE não mudam. A conta estimada não aceita baixa até o valor ser confirmado. O saldo de conta recorrente não herda o vínculo com a recorrência. Recebimento: vale para parcelas de contrato; a receita da parcela é dividida na mesma data entre a parte recebida e a parcela "(saldo)". Venda avulsa recebe sempre o valor inteiro.

## Códigos automáticos (v0.37)
Canal e centro de custo: próximo número de 3 dígitos após o maior código puramente numérico do workspace (códigos com letras são ignorados). Plano de contas: filho = código do pai + "." + próximo número, com a largura dos irmãos já existentes (padrão 2 dígitos a partir do 3º nível, 1 dígito antes); sem pai, próximo inteiro de primeiro nível. Tag de produto: nome sem acentos, minúsculo, com hífens; repetida ganha -2, -3. utm_campaign de canal de campanha: campanha_canal em minúsculas com sublinhado; repetida ganha _2. Vale só na criação, e só se o campo ficar vazio; a geração roda no momento de salvar (duas pessoas salvando no mesmo segundo podem gerar o mesmo número; a regra de unicidade do banco barra e basta salvar de novo).

## Status e edição de contrato (v0.38)
Na tela: Pendente (rascunho), Assinado e ativo, Encerrado, Cancelado. Só contrato pendente pode ser editado. "Voltar para pendente" vale para contrato ativo ou cancelado e é barrado se alguma parcela já foi recebida (desfaça o recebimento antes). Ao voltar: parcelas previstas viram canceladas (ficam como histórico) e, se o contrato estava ativo, o reconhecimento delas é estornado na data original. Aluno, pessoa e projetos já criados não são desfeitos; ao assinar de novo, projetos não duplicam (um por contrato e produto) e as parcelas são geradas novamente.

## Parcelas personalizadas do contrato (v0.39)
Só contrato não recorrente. Se houver plano, o número de parcelas do plano deve ser igual a "Nº de parcelas" e a soma dos valores deve ser igual ao total dos itens (centavo a centavo); senão a assinatura é barrada. Cada parcela nasce com o valor e o vencimento do plano; o fim do contrato, se vazio, vira o maior vencimento. Sem plano, vale a divisão igual mensal de antes. Contrato assinado não muda o plano (volte para pendente antes).

## Contrato vencendo (v0.40)
Vale para contrato assinado e ativo com data de fim. Dias restantes = data de fim menos hoje. De 40 a 31 dias: aviso amarelo; 30 dias ou menos (inclusive vencido): vermelho. Os limites (40 e 30) são constantes na tela (`CT_AVISO_ATENCAO`, `CT_AVISO_URGENTE`). Contrato sem data de fim não avisa. Contrato recorrente ganha como fim o último vencimento gerado ao assinar.

## Números do mês nos contratos (v0.41)
Mês = mês de hoje, pelo vencimento da parcela. Total do mês = parcelas de contrato que vencem no mês, recebidas ou previstas, sem as canceladas. A receber no mês = só as previstas do mês (atrasadas de meses anteriores aparecem em "Em atraso" e em "A receber (tudo em aberto)"). Total em contratos ativos = soma do valor total dos contratos assinados e ativos (recorrente: valor da cobrança × número de parcelas). Receita recorrente (valor mensal) = soma da cobrança mensal equivalente dos recorrentes ativos.

## Oportunidades e renovação (v0.42)
Oportunidade = negócio novo com uma pessoa já cadastrada. Status: aberta, ganha, perdida; só as abertas aparecem no quadro. Tipos: nova venda, renovação, ajuste/aditivo. Ganhar não cria contrato sozinha: abre o contrato pendente já com cliente e produto (e valor estimado) para conferir e salvar; renovação ganha abre a renovação do contrato de origem. Perder pede motivo; reabrir volta para aberta. Renovar contrato cria um contrato novo e pendente, copiado do anterior, com início no dia seguinte ao fim do contrato (ou hoje, se não houver fim) e sem data de fim; o contrato antigo não é alterado. Valores do contrato novo e da oportunidade não entram em indicadores financeiros até o contrato ser assinado.

## Reverter erros em contas a pagar (v0.43)
Desfazer pagamento: só conta paga. Lança o espelho do pagamento (origem cancelamento_pagar, ligado ao lançamento do pagamento) e uma entrada bancária de devolução na data escolhida (padrão hoje); a conta volta a previsto, sem data de pagamento nem conta bancária. A despesa (competência) não muda. Vale também para a parte paga de uma baixa parcial; o saldo continua como conta separada. Reativar: só conta cancelada ainda não reativada. Cria conta nova (previsto) com os mesmos dados e lança a despesa de novo; a cancelada guarda o vínculo em substituida_por e some da lista padrão. Contrato cancelado volta com "Voltar para pendente" (ver regras de contrato).

## Vendas x Contas a receber (v0.44)
Vendas = compras realizadas (venda aprovada, reembolsada etc.); os números "quantidade de vendas" e "quanto gerou" vêm da data da venda e alimentam o dashboard de vendas e as metas. Contas a receber = o que entra no caixa: parcelas de contratos assinados e recebimentos de vendas, por vencimento. Contrato fechado não conta como venda nos números de Vendas (conta como parcelas em Contas a receber e como receita contratada em Contratos).
Cancelar parcela: só parcela de contrato ainda prevista; estorna a receita prevista dela (origem cancelamento_contrato) e a marca cancelada; venda se cancela por Estornar. Desfazer recebimento: conta recebida (contrato ou venda) volta a previsto; lança o espelho do recebimento e uma saída bancária de devolução na data escolhida; a receita prevista não muda. Reativar parcela: só com contrato ativo; cria parcela nova prevista, copia a receita da original; a cancelada fica com substituida_por e some da lista.

## Metas x vendas no Dashboard de Vendas (v0.45)
Só campanhas com status ativa. Lançamento: meta de vendas e de receita da campanha contra vendas aprovadas da campanha (receita = valor bruto); esperado até hoje = meta x (dias decorridos ÷ dias da campanha), só se a campanha tem início e fim. Recorrente: meta do mês atual (padrão ou ajuste do mês) contra as vendas aprovadas do mês; esperado = meta x dia do mês ÷ dias do mês. Ritmo: No ritmo se vendeu pelo menos o esperado, senão Atrás do ritmo. Vendas sem campanha entram no total do mês, não em nenhuma linha. Contrato assinado não entra como venda aqui (ver pendência).

## Período padrão das listas financeiras (v0.46)
Contas a receber e a pagar abrem com período de vencimento do primeiro dia do mês corrente até hoje + 30 dias; recebidas e pagas entram pela data do recebimento/pagamento. Para ver mais, mude o período no filtro.

## Pró-labore e sócios (v0.47)
Despesa de pró-labore (6.2.04) fica a pagar em 2.1.03, não em Fornecedores. O pagamento baixa a mesma conta de passivo do lançamento de competência. Distribuição de lucros não é despesa: usa 3.1.02. Cancelamentos estornam apenas o saldo ainda não estornado.

## Período dos Lançamentos contábeis (v0.47)
A tela abre no mês corrente, pela data do fato. Para ver mais, mude o período ou escolha "Tudo".

## Growth Model por loop (v0.49)
- **Classificação das vendas aprovadas**: com campanha, entram no loop da campanha. Sem campanha: se o cliente já tinha compra anterior do mesmo produto, **recompra**; de outro produto, **upgrade**; senão, **orgânico/direto**. Leads (captados) sem campanha entram no orgânico. Contratos de serviço formam um loop de recorrência: contratos ativos no mês e receita das parcelas (não canceladas) por mês de vencimento, dividida entre os produtos pelo valor dos itens.
- **Cadeia de cada loop**: usa só as etapas que têm dado (investimento, impressões, cliques, visitas, leads, qualificados, compras). Entre duas etapas há uma taxa (CPM entre investimento e impressões: impressões = investimento × 1000 ÷ CPM). Receita = compras × ticket.
- **Projeção**: meses antes do mês atual são reais; do mês atual em diante, volume inicial = média mensal e taxas = soma do destino ÷ soma da origem, ambos nos últimos 1, 2, 3 ou 6 meses reais. Alavanca digitada vale daquele mês em diante, até o próximo valor digitado. No cenário vale o valor mais recente entre cenário e baseline. Campanha encerrada tem volume inicial zero.
- Receita nunca é digitada. Tudo calculado por regra fixa, sem IA.

## Plano de contas por cliente (v0.51)
- O plano padrão serve de ponto de partida; cada cliente pode ter o seu, importado de planilha.
- Substituir só é permitido enquanto não houver lançamentos, contas bancárias, contas a pagar ou recorrências. Depois disso, só adicionar.
- Conta com filhos não aceita lançamento. Conta com lançamento não muda código, tipo nem natureza.
- Depois de importar, é preciso apontar as contas do sistema (fornecedores, receitas, impostos, bancos, pró-labore) para o plano do cliente.

## Planejamento anual de campanhas (v0.52)
- Campanhas do ano = as que têm início até 31/12 e fim (se houver) depois de 01/01. Sem data de início aparecem à parte, "sem data definida".
- Meta de faturamento por campanha vem de `meta_receita`. Total das campanhas é comparado com a soma das metas mensais da empresa.
- Distribuição por mês é estimativa: lançamento no mês do fechamento do carrinho (ou do fim); perpétua dividida igualmente do início a dezembro. Cálculo fixo, sem IA.

## Regras contábeis personalizadas (v0.53)
- Os 9 eventos do sistema são fixos. A pessoa pode criar eventos novos (código `x_...`), cada um com uma conta de débito e uma de crédito.
- Evento personalizado só gera lançamento pelo botão "Lançar" (lançamento manual com as contas da regra). Débito e crédito não podem ser a mesma conta; regra inativa não lança.
- Excluir a regra não apaga lançamentos já feitos (o razão é imutável).

## Importação de dados com de-para (v0.55)
- Cada linha do arquivo é validada contra os campos do Growths. Obrigatório vazio ou inválido: a linha não entra. Opcional inválido: vira branco e a linha entra. Quem já existe (e-mail, nome ou ID externo) é ignorado, nada é sobrescrito.
- Vendas dependem de Clientes e Produtos já cadastrados; venda aprovada gera lançamento contábil e conta a receber.
- Ordem sugerida: Produtos e Clientes e leads → Campanhas → Vendas.

## Growth Starter (v0.55)
- Workspace de consultoria (`modo_produto = 'starter'`): menu enxuto do conceito de UX, mesmos dados e permissões. Serve para importar planilhas do cliente e puxar relatórios antes de ele contratar o Growths completo.

## Dashboard (v0.55)
- Receita, leads, CAC de mídia e conversão vêm do Growth Model (vendas e contratos). Margem vem de v_dre_mensal. Recompra = clientes com 2+ compras. CAC = investimento em campanhas ÷ novos clientes da aquisição. Conversão = novos clientes ÷ leads. Alertas por regra fixa (variação ≥ 10% a 15%), sem IA.

## Dashboard (v0.57)
- Investimento em mídia = investimento de campanhas no período. Por canal: CAC = investimento ÷ vendas; ROI = receita ÷ investimento; leads e vendas atribuídos ao canal de origem da pessoa.
- Só a equipe interna vê o seletor de clientes e cria clientes.

## Dashboard personalizável (v0.58)
- Indicadores só trocam de lugar entre indicadores; blocos, entre blocos. Contas a pagar = contas previstas com vencimento até o fim do período (inclui vencidas).

## Dashboard de mídia (v0.59)
- CTR = cliques ÷ impressões; CPC = investimento ÷ cliques; CPL = investimento ÷ leads; CAC = investimento ÷ vendas; ROAS = receita ÷ investimento. Leads e vendas vêm do UTM do anúncio.
- Índice de CPL do anúncio = CPL dos últimos 7 dias do período ÷ CPL de referência (últimos 30 dias, com os filtros ativos). Anúncio sem leads que já gastou ao menos o CPL de referência recebe índice 4,0. Frequência = impressões ÷ alcance nos 7 dias.
- Faixas: saudável ≤ 1,0; atenção até 2,0; risco até 2,5; crítico acima.
- Ação sugerida: Pausar (índice > 2,0, ou frequência > 3 com CTR caindo 30% ou mais); Monitorar (índice > 1,2, frequência > 2,2 ou CTR caindo 10% ou mais); Escalar (índice ≤ 1,0 com CTR estável ou subindo); senão Manter. É sugestão: nada é pausado sozinho.

## Pergunte aos dados (v0.60)
- A IA nunca calcula. Só cita valores que já estão no resumo; percentuais vêm prontos (campos _pct). Se não há dado, ela diz que não há.
- Conferência: números com R$, %, x, decimais ou a partir de 100 que não existirem no resumo (tolerância de 0,6%) são sinalizados em vermelho. Contagens pequenas, anos e datas não são conferidos.
- Quem não tem permissão para ver um dado não o recebe no resumo, porque o resumo roda com os direitos de quem pergunta.

## Identificação de arquivos (v0.62)
- Pontuação por palavras nas colunas (e no nome do arquivo). Menos de 2,5 pontos: não reconhecido (amarelo). Primeiro lugar com menos de 1,4 vez o segundo: em dúvida (amarelo). Caso contrário o tipo é assumido e o arquivo é validado: sem problema = verde; coluna obrigatória faltando ou linhas com erro = vermelho.
- Nada é importado sem o ok da pessoa. Linhas com problema nunca entram; o ok no vermelho autoriza apenas as linhas corretas.

## Período e comparação do dashboard (v0.63)
- O período é sempre em meses inteiros (De/Até). Comparação: período anterior (mesma quantidade de meses imediatamente antes), mesmo período do ano anterior, ou um período escolhido. Cálculo fixo, sem IA.
- Campos personalizados: servem para colunas de planilha sem campo no Growths. Não entram em cálculos (CAC, receita etc.); são dados descritivos do cadastro.

## Contrato é venda (v0.64)
Contrato ativo ou encerrado conta como uma venda, na data do fechamento, pelo valor das parcelas não canceladas. Aparece em Vendas, no Dashboard de Vendas e em Contas a receber (parcelas), uma vez em cada. Nunca vira duas vendas.
No Growth Model, o primeiro contrato ou venda da pessoa é novo cliente (aquisição, na campanha do contrato ou orgânico); contratos seguintes de quem já comprou são upgrade (retenção). Só quantidade; receita vem das parcelas por vencimento. A conversão lead → cliente pode passar de 100% se houver contratos de pessoas que não foram cadastradas como lead captado no período.

## Calculadora de campanha (v0.65)
Base: ticket, conversão, CPL e leads. Ligados: CAC = CPL ÷ conversão; vendas = leads × conversão; receita = vendas × ticket; mídia = leads × CPL; ROAS = receita ÷ mídia. Editar um ligado ajusta a base (CAC e ROAS mexem no CPL; vendas, receita e mídia mexem nos leads).
Margem de contribuição por venda = ticket × (1 − impostos − taxa − comissão) − custo de entrega. Resultado = vendas × contribuição − mídia − custos adicionais − despesa da empresa. Margem = resultado ÷ receita.
CAC máximo (margem alvo) = contribuição − margem alvo × ticket − (custos adicionais + despesa) ÷ vendas. CPL máximo = CAC máximo × conversão. ROAS ideal = ticket ÷ CAC máximo; ROAS de equilíbrio usa a margem zero. CAC total = (mídia + custos adicionais) ÷ vendas. ROI da empresa = resultado ÷ custo total. Itens de custo: fixo, por lead, por venda ou % da receita.
Ofertas: a campanha registra o preço de cada oferta; a oferta principal define o ticket sugerido.

## Alertas de métricas (v0.66)
Vermelho quando a métrica automática está pior que o benchmark cadastrado (sem tolerância) ou mais de 10% pior que a média dos 3 períodos anteriores ou que o período anterior. Pior = abaixo para métricas que sobem, acima para CPL e CAC. Cálculo determinístico, sem IA.

## Contas a pagar canceladas (v0.67)
Cancelada nunca entra em total, KPI, por fornecedor, atraso nem CAC. Na lista aparece só quando o filtro pede, fora do total.

## Desconto concedido (v0.68)
Desconto dado ao cliente depois do fechamento é dedução da receita (5.1.03), nunca despesa: a receita bruta fica como vendida e a líquida cai. Não entra dinheiro. Parcela com desconto total sai do a receber e do valor da venda no dashboard; não pode ser reativada.

## Calculadora: ordem de preenchimento (v0.70)
Qualquer campo pode ser preenchido primeiro. Os calculados (CAC, vendas, receita, mídia, ROAS) esperam a base e passam a valer quando ela permite; vale sempre o último que você digitou para o mesmo campo da base.

## Atribuição da melhoria (v0.71)
O ganho de cada alavanca é medido isoladamente sobre o baseline. Como as taxas do funil se multiplicam, a soma das partes pode ser menor que o total; a diferença aparece como "Efeito combinado".

## Importação de baseline e cenário (v0.72)
Coluna Baseline da planilha vira baseline; coluna Cenário vira cenário. Célula vazia no Cenário não grava nada (herda o baseline). O investimento mês a mês, quando marcado, grava um valor por mês para os dois cenários; no primeiro mês o Cenário usa o valor da coluna Cenário. Linhas calculadas da planilha são ignoradas porque o sistema recalcula.

## Formato de moeda (v0.73)
Valores em reais aparecem como `R$ 1.234,56`. Campos de percentual, quantidade e pontuação não têm máscara. O banco recebe sempre o número puro.

## Growth Model novo (v0.74)
- Mês 1 é o primeiro mês com dado do cliente (ignora um mês isolado com menos de 2% das linhas). O modelo mostra 12 meses.
- Venda nova: primeira compra daquela pessoa. Renovação: mesma pessoa, mesmo produto, depois do prazo configurado (padrão 25 dias). Antes disso é repetida e não conta. Upgrade: pessoa que já comprou outro produto. Sem identificação do comprador, tudo conta como nova e o diagnóstico avisa.
- Só entram vendas com status aprovado/pago/concluído. Reembolsado, cancelado, pendente e recusado ficam fora (editável).
- Sumário: investido = soma dos passos marcados como investimento; clientes novos = clientes dos loops de aquisição e upgrade; renovados = loops de renovação; receita = soma dos passos de receita; ROI = receita ÷ investido.
- Leads e investimento sem produto vão para "Sem produto identificado", a menos que você escolha um produto.

## Growth Model do cliente (v0.75)
- Cliente com dados no sistema: o modelo aparece sozinho; os números vêm dos cadastros e não se editam na tela.
- Cliente que manda planilhas: Diagnóstico Growth, e ao salvar o modelo importado passa a ser mostrado (editável).
- Os dois podem existir; escolhe-se qual ver. Loops manuais valem em ambos os casos.
- Meses depois do mês atual, ou sem nenhum dado, aparecem como "—".


## Baseline e Cenário (v0.76)
Baseline é o real. Cenário substitui só as taxas preenchidas e recalcula os passos seguintes do funil em cadeia nos meses com dados reais; taxas vazias seguem o real. Sumário compara os dois.


## v0.77
- A campanha copia as etapas da estratégia ao ser criada, ou quando a estratégia é trocada. "Reaplicar" sem substituir só acrescenta as etapas que faltam; substituindo, apaga as etapas e os números da campanha.
- Volume da etapa, pela origem:
  - anúncios: soma da mídia diária da campanha;
  - leads: pessoas com a campanha;
  - etapa do Kanban: pessoas distintas que chegaram a ela;
  - lista: pessoas distintas que entraram;
  - vídeo: presentes distintos (ou só ao vivo);
  - vendas: clientes distintos (vendas aprovadas e contratos ativados) ou receita (vendas, mais o valor dos itens do contrato);
  - manual, disparo, ou etapa sem item ou sem dado automático: soma do que foi lançado por dia.
- Taxa sobre a anterior: só entre etapas de quantidade, contra a última etapa acima que tem número. Custo por pessoa = investimento da campanha ÷ volume da etapa.
- Atribuição: vale o último clique. A venda fica com a campanha e o canal que fecharam, e a primeira origem fica no lead.
- Compra é a primeira compra da pessoa (venda aprovada ou contrato ativado). Depois disso, é "nova compra".
- Growth Model: clientes novos somam só aquisição. Upgrades têm linha própria e renovados somam renovação e recompra.


## v0.78
- Cenário: um campo vazio usa o real do mês (ou, num mês projetado, a média ou a taxa do período real). O investimento do cenário é um valor por mês. Impressões = investimento ÷ CPM × 1000, leads = investimento ÷ CPL e clientes = investimento ÷ CAC (quando o loop vai direto do investimento para eles). Os passos seguintes usam as taxas, e a receita = clientes × ticket.
- Projeção: só para os meses depois do último mês com dado real, até completar 12 meses. Baseline e Cenário comparam os mesmos 12 meses.


## v0.79
Nos meses reais, um passo sem taxa calculável (por exemplo, 0 leads) mantém o valor real, até que o cenário dê a taxa. Num loop sem mídia, simular exige preencher o investimento e as taxas do funil.


## v0.80
Permissão nas operações: pagar, receber, desfazer, provisionar, lançamento manual e estorno de lançamento exigem editar no Financeiro. Ativar, cancelar e reabrir contrato, mexer em parcela de contrato, processar venda e estornar venda exigem editar em Vendas ou Financeiro. Entrar/sair de lista: Marketing ou Vendas. Cliente histórico: Vendas ou RevOps. Projetos: Projetos (e Marketing para projetos de campanha). Envio de pesquisas: Growth ou Marketing. Administrador passa em tudo. Conta a pagar estimada não pode ser paga, nem pelo banco: primeiro confirme o valor real.


## v0.81
**Blocos.** Cada bloco tem uma métrica principal; a conversão da campanha é a principal de um bloco sobre a última principal com número acima (por fase e ordem). Métricas de diagnóstico mostram volume e custo por pessoa, sem taxa. Não se remove a principal de um bloco que tem outras métricas sem escolher outra. Nome de bloco é único na estratégia/campanha; renomear o bloco renomeia as métricas ("Aula 2 · Presentes"). Ligar o vídeo ou o grupo no bloco liga as métricas de presença/entrada. Desligar um bloco na campanha desliga as métricas dele.
**Simulador.** Receita bruta = compras × preço efetivo. Receita líquida = bruta − reembolsos − impostos. Contribuição = líquida − custos variáveis. Resultado = contribuição − fixos − mídia − outros de aquisição. Margem operacional = resultado ÷ líquida (N/D sem receita). CAC mídia = mídia ÷ clientes novos; CAC total inclui outros custos (N/D sem mídia ou sem clientes). ROAS 1ª compra = receita da primeira compra ÷ mídia; ROAS da jornada = receita das coortes no horizonte ÷ mídia. CAC mídia máximo = (C − F − A − m × R) ÷ N, com volume fixo; orçamento = máx(0, C − F − A − m × R). ROAS-alvo = (M + F + A) ÷ (C − m × R) × receita da 1ª compra ÷ M (produto único: (M+F+A) ÷ [M × (c − m)]). Payback de contribuição: primeiro mês em que a contribuição acumulada da primeira coorte cobre a aquisição dela; de caixa: recebido − desembolsos variáveis. Produto desativado sai dos cálculos; canal cuja entrada está desativada sai inteiro (mídia e clientes); transição com produto desativado fica suspensa. Rateio de fixos (receita, igual ou manual) muda só a visão por produto. Mídia variando usa eficiência: clientes × (mídia nova ÷ mídia)^eficiência.


## v0.82
Sem mudança de regra. Growth Loops e Unit Economics seguem a permissão do módulo Growth.


## v0.83
Desfazer pagamento: se a conta foi paga por baixa parcial e o saldo gerado ainda está a pagar, as duas partes são canceladas e substituídas por uma conta única com a soma, mesma competência, vencimento, fornecedor, conta contábil e centro de custo, e descrição da conta que foi paga. Os estornos dos cancelamentos usam a data da competência de cada parte; a despesa do mês não muda. Se o saldo já foi pago (no todo ou em parte), não há junção.


## v0.85
Acesso em duas camadas: (1) pacote do cliente, definido pela equipe interna = quais telas o workspace tem; (2) função de cada pessoa = nível por módulo e ações. Telas liberadas = telas do pacote + ligadas − desligadas; sem pacote e sem ajustes = tudo. Equipe e acessos e Funções e permissões sempre liberadas. Módulo sem tela liberada fica bloqueado no banco; Configurações e Cadastros só são escondidos na tela. Pacote em uso não pode ser excluído; pacote inativo não aparece para escolher, mas continua valendo para quem já tem.

## v0.86
Saldo em banco = só contas do tipo Conta. Compra no cartão: a conta a pagar fica paga na data da compra e o valor passa para a fatura; a despesa já está na competência. Pagamento da fatura: sai do banco, abate a fatura, não gera despesa nova. Recebimento nunca entra em cartão. Conta a receber avulsa não tem lançamento até a baixa (a receita é reconhecida no recebimento); recebe o valor inteiro; cancelar só marca como cancelada. Extrato: saldo anterior = saldo inicial + movimentos antes do período. Projeto de campanha: a campanha é criada primeiro e o projeto dela é renomeado com os dados do formulário (um projeto por campanha). Cada bloco ativo da estratégia vira uma atividade com subatividades, uma vez só por bloco; responsável = pessoa da equipe com a função da subatividade.

## v0.87
Casa = finanças pessoais com contabilidade própria, aberta pelo menu da operação. Transferência empresa → Casa: na empresa, paga a conta a pagar escolhida (parcial se o valor for menor; não pode passar do valor em aberto) ou lança retirada (débito na conta contábil escolhida, crédito no banco); na Casa, entrada já recebida na conta e receita escolhidas. Só contas bancárias (não cartão) dos dois lados. Desfazer estorna os dois lados com a data informada.

## v0.88
Identidade: a mesma pessoa é o mesmo telefone normalizado (55 + DDD + número); sem telefone, o mesmo e-mail. Venda: plataforma + ID externo nunca se repete; o comprador gravado na venda não muda. Indisponível não é zero: dia sem dado ou marcado como parcial gera aviso, não vira 0 em silêncio. Os avisos de qualidade não alteram os números. Fechamento: só um oficial por campanha; corrigir exige motivo de pelo menos 10 caracteres e cria nova versão; nenhum fechamento é alterado ou apagado. Auditoria: tudo o que muda nas tabelas críticas fica registrado com antes e depois.

## v0.89
Uma pessoa participa uma vez de cada campanha; a entrada oficial é a primeira e as tentativas seguintes são duplicidade. "Era aluno" e "já era cliente" são medidos na hora da entrada. Atribuição v1: primeiro toque = primeira entrada, captura ou lista com origem até a venda; último toque = origem da própria venda (canal de fechamento ou UTM) ou, sem ela, o último toque com origem antes da venda; peso 1; venda que deixa de ser aprovada sai da atribuição. ROAS = receita bruta ÷ investimento. Aceite = vendas da oferta ÷ vendas das ofertas principais da campanha. Abandono recuperado = mesma pessoa compra o mesmo produto em até 30 dias. Metas: em investimento, CPL e CAC ficar abaixo é bom; meta zero não gera %.

## v0.90
Filtro "abertas" = liberadas e em andamento; "atrasadas" = não concluídas com prazo vencido. No painel do projeto contam só as atividades que são feitas de fato (sem subatividades) e não canceladas. Planejado no dia = atividades com prazo até aquele dia. Vincular projeto a campanha só para campanha não finalizada. CPL do canal = investimento dos anúncios do canal ÷ leads que entraram pela utm_campaign do canal; dentro da meta quando CPL ≤ meta.

## v0.91
Campanha nova: com "Criar o projeto da campanha agora" marcado, nasce o projeto "Campanha: <nome>" com o modelo escolhido (ou o padrão) e as atividades dos blocos; desmarcado, a campanha fica sem projeto até alguém criar ou vincular um.

## v0.92
Saldo em banco soma só contas do tipo "conta"; o cartão de crédito é fatura (passivo) e aparece à parte. Clicar no saldo mostra o extrato: saldo anterior, cada entrada e saída e o saldo final.

## v0.93
- Custo do mês = contas a pagar com competência no mês (menos canceladas) + recorrências ativas ainda não lançadas, menos os itens desmarcados.
- Tipos: fixo (recorrência fixa), variável (recorrência variável), parcelado (descrição "(n/m)"), pontual (o resto).
- Ponto de equilíbrio: receita mensal em que receita − imposto − custos variáveis da venda = custo do mês. Com margem: sobra ainda a margem sobre a receita.
- MEI: DAS fixo de R$ 86,05 (serviços, 2026) somado ao custo; limite de R$ 81.000/ano; aviso acima do limite e acima de 20% dele (desenquadramento retroativo).
- Simples Nacional: anexo III quando o fator R ≥ 28%, anexo V abaixo; alíquota efetiva pela faixa da receita de 12 meses. O INSS de 11% do pró-labore é do sócio e não entra como custo da empresa.

## v0.94
- Margem de contribuição (produto) = receita − imposto sobre a venda − taxas da venda − custo do produto; em % da receita do produto.
- Margem de lucro líquida (mês) = (soma das contribuições − custos fixos do mês) ÷ receita do mês. Custos fixos = custo contado na tela (inclui pró-labores) + DAS no MEI.
- Situação: dentro da meta quando a margem líquida ≥ meta; "falta para a meta" = receita × meta − lucro; também mostra a receita mensal que dá a meta com os custos atuais.
- No Planejamento, as margens automáticas usam a DRE: contribuição = (receitas − deduções − custos) ÷ receitas; lucro líquido = (receitas − deduções − custos − despesas) ÷ receitas.

## v0.95
- Cenários da margem de lucro líquida: ruim < bom (meta) < ótimo, definidos pela empresa.
- Situação do mês: Ótimo se a margem ≥ ótimo; Bom se ≥ bom; Ruim se ≥ ruim; Abaixo do ruim no resto. "Falta" = receita do mês × margem do próximo cenário − lucro do mês.

## v0.96
- Faturamento necessário = (custos da empresa + retirada dos sócios [+ DAS no MEI]) ÷ (1 − imposto − custos variáveis − margem do cenário).
- Cenários de margem do negócio: mínima < muito boa < ótima (definidos pela empresa).
- Retirada possível no mês = a receber do mês × (1 − imposto − custos variáveis − margem) − custos da empresa [− DAS].
- "Possível": o a receber do mês já cobre o faturamento necessário do cenário.

## v0.97
- Oferta: produto ou pacote; no pacote, a receita é repartida pelos % de alocação (soma 100%). Uma alteração comercial cria versão nova; versões não mudam.
- Esteira: uma principal por campanha; cada outra oferta parte de uma etapa anterior (sem etapa = após a principal); sem ciclos; downsell só após recusa; order bump só no checkout da principal.
- Quem recebeu uma oferta: compradores da etapa anterior (sempre/aceitou) ou quem recusou (recusou); sem etapa anterior, os compradores da principal. Aceite = vendas ÷ quem recebeu.
- Receita simulada da oferta = quem recebeu × exposição × aceite × preço. Receita nunca é digitada.
- Campanha só paga aceita só execuções pagas; só orgânica, só orgânicas; híbrida, ambas.

## v0.98
- Receita, compras, leads, lucro e margem são resultados; só volume inicial, taxas, ticket, investimento e custos são inputs.
- Baseline = real nos meses passados; projeção = média dos últimos meses + premissas do baseline. Premissa só muda por administrador, com motivo.
- Cenário em rascunho muda à vontade; aprovado fica congelado; arquivado sai da lista e da comparação, mas fica guardado.
- Lucro (cabeçalho) = receita − impostos (regime) − custos variáveis (% da receita) − mídia − custos fixos (financeiro sem mídia; no recorte, rateados pela participação na receita).
- Comparação só entre cenários do mesmo contexto, salvo normalização explícita; até 3 cenários + baseline.

## v0.99
- ICE = (impacto + confiança + facilidade) ÷ 3, notas inteiras de 1 a 10.
- Aprovar: só administrador, cenário em rascunho, com hipótese e ICE; guardrail crítico violado exige justificativa do risco. Aprovado = congelado; documento de decisão não muda.
- Um cenário gera no máximo uma ideia no Kanban; cenário aprovado entra como Priorizada.
- Converter em planejamento cria um projeto (uma vez só) e leva a ideia para Preparação.

## v0.100
- Guardrail rompido: mínimo → valor abaixo do limite; máximo → acima. "Perto do limite" = dentro de 10% de folga.
- Projeção (fase 1) usa os números do cabeçalho do cenário; não é alerta. Monitoramento (fase 2) usa dados reais do teste: antes = janela de N dias antes do início; durante = início até hoje ou o fim; depois = N dias após a conclusão.
- Alerta: só durante o teste (ou no acompanhamento contínuo), um aberto por teste e guardrail; resolver exige nota. Nada é pausado automaticamente.
- Resultados: projeção e baseline proporcionais aos meses passados do período do cenário; realizado = receita de vendas aprovadas no período. Comparação no tempo não prova causa.

## v0.101
Sem mudança de regra.

## v0.102
Sem mudança de regra.

## v0.103 — Growth Model simplificado
- Período: meses passados mostram o real; meses a partir do mês atual, a projeção (média dos últimos meses e premissas do baseline).
- CAC mídia = mídia ÷ clientes novos (loops de aquisição). CAC sem mídia = custos de aquisição que não são mídia ÷ clientes novos.
- Custo de entrega = receita × % de custo do produto + clientes × custo por cliente (Custos e margens).
- Lucro = receita − mídia − CAC sem mídia − custo de entrega − taxas (% variável) − impostos (regime) − demais custos fixos. Margem = lucro ÷ receita. ROI = lucro ÷ (receita − lucro).
- Cenário: o número vale para todos os meses do loop, inclusive os passados. Custos fixos e CAC sem mídia (total) não mudam com o cenário; custo de entrega, taxas e imposto acompanham a receita.

## v0.104
- O número do cenário é do loop: vale com "Todos os produtos" e com o produto do loop filtrado.

## v0.105 — Retenção & Expansão: definições das métricas
**Cliente, compra e coorte:**
- **Cliente**: o cadastro único de pessoas, já com as mesclagens de duplicados (e-mail e telefone normalizados). A mesma pessoa nunca conta duas vezes.
- **Compra válida**:
  - Venda com status aprovada, sem reembolso nem cancelamento.
  - Ou contrato não cancelado; cancelado só conta se teve parcela recebida.
  - Parcelas de uma venda ou de um contrato não são compras novas. Mensalidade de contrato recorrente também não. Contrato novo (renovação ou outro produto) é compra nova.
- **Pedido**: compras do mesmo cliente no mesmo dia viram um pedido só. Com a opção `pedido`, ficam separadas, salvo mesmo nº de pedido.
- **1ª compra**: o primeiro pedido válido. Se a primeira foi reembolsada, vale a próxima válida.
- **Coorte**: mês (ou trimestre ou ano) da 1ª compra. Na visão por produto, o produto da 1ª compra.

**Coortes e recompra:**
- **Taxa de 2ª compra em N dias**: clientes com 2ª compra até N dias depois da 1ª ÷ clientes da coorte.
  - Só é mostrada quando todos os clientes já completaram N dias.
  - Antes disso aparece "indisponível", e o parcial (só entre quem já completou N dias) fica no detalhe.
- **Curva de 2ª compra**:
  - Por coorte: % acumulado por dia, até o dia que todos já completaram.
  - Todas: em cada dia, entre os clientes que já têm aquele tempo.
- **Tempo até a 2ª compra**: dias entre a 1ª e a 2ª compra (média e mediana entre quem recomprou).
- **Intervalo entre compras**: dias entre compras consecutivas do mesmo cliente.
- **Frequência**: compras por cliente.
- **Ticket de recompra**: receita dos pedidos a partir da 2ª ÷ número desses pedidos.

**Receita e margem:**
- **Receita**: vendas aprovadas pelo valor líquido (depois de taxa e impostos da venda) na data da venda + parcelas de contrato não canceladas nem estornadas com vencimento ou recebimento até hoje. Reconciliada na aba Recompra.
- **Receita de existentes**: receita de pedidos a partir da 2ª compra. As parcelas de um contrato pertencem à compra em que ele foi fechado.
- **Receita por cliente da coorte**: receita acumulada ÷ clientes da coorte.
- **Margem de contribuição**: receita − custo do produto (Custos e margens: % da receita + valor por cliente, uma vez por compra).
  - Só sobre a receita de produtos com custo cadastrado; a cobertura aparece ao lado.
  - Não é lucro: não desconta custos fixos.

**RFM** (data de referência explícita):
- **Recência**: dias desde a última compra válida.
- **Frequência**: compras na janela.
- **Valor**: receita líquida na janela.
- **Notas de 1 a 5**:
  - Quintis: posição entre todos, empates juntos.
  - Limites: 4 cortes.
- **Segmentos padrão**, na ordem: Campeões (R4–5, F4–5), Clientes leais (R3–5, F3–5), Novos clientes (R4–5, F1), Potenciais leais (R4–5, F2–3), Precisam de atenção (R3, F1–2), Em risco (R1–2, F3–5), Hibernando (R1–2, F1–2).
- O cliente fica na primeira regra que bate; sem regra, "Outros". As regras são editáveis por workspace.
- **Papel do produto de entrada**: Expande (30% ou mais recompram e geram receita depois), Recompra moderada (10% a 30%), Não expande (menos de 10%).

## v0.106 — Growth Model em planilha
- O cenário recalcula em cascata:
  - preço → receita → imposto (pela faixa, no Simples) → taxas e custo de entrega → margem de contribuição → lucro;
  - etapas do loop → vendas → receita → o mesmo encadeamento.
- Margem de contribuição por venda = preço − imposto por venda (alíquota efetiva do período) − taxas variáveis − custo de entrega por venda.
- Custos fixos do período no cenário = custos fixos do financeiro (sem mídia e sem aquisição) + ajuste × meses. Com filtro de produto ou campanha, são rateados pela receita.
- ICE = média de impacto, confiança e facilidade (notas de 1 a 10). Aprovar congela o cenário e gera o documento de decisão.

## v0.107 — Ciclo de vida dos cenários
- **Em estudo**: o cenário pode ser editado, aprovado ou descartado.
- **Descartado**: só cenário em estudo. O motivo é obrigatório (ICE baixo, perdeu para outro cenário, sem verba agora, fora de época, outro). Nada se apaga; dá para reabrir.
- **Aprovado**: o cenário fica congelado e não pode mais ser descartado nem excluído. Para mudar, duplica-se.
- Depois de aprovado, o status segue o card do Kanban:
  - Ideias, Em avaliação, Priorizadas ou Preparação → Aprovado;
  - Em teste ou Análise → **Ativo** (desde a data de início);
  - Concluída → **Encerrado** (período ativo do início à conclusão, com a decisão, o resultado e o aprendizado);
  - parou antes de ir ao ar (arquivado, ou interrompido sem início) → **Cancelado**.
- A planilha lista só cenários vivos (em estudo, aprovado e ativo). A tela Cenários lista todos.
- A documentação do teste = aprendizado escrito no card (obrigatório para concluir) + link opcional do documento completo.

## v0.108 — Organização do Growth
- Menu Growth com 6 itens: Diagnóstico Growth, Growth Model, Pesquisas, Ciclo de Growth (Kanban), Resultados e aprendizados, Guardrails.
- O acesso à aba Cenários segue o acesso ao Growth Model.
- Unit Economics e Análise de funil não existem mais como telas. Quem abrir um link antigo vai para a Planilha do Growth Model.

## v0.109 — Ideias pela IA
- Toda ideia que chega pela IA entra como **Ideia**, com origem "ia". Ela segue as mesmas regras do Kanban de conteúdo: para virar pauta precisa das 5 notas e do tema.
- Cada chave vale para um workspace só e grava só nele.
- Chave revogada para de funcionar na hora.
- A IA recebe os temas ativos e as últimas 15 ideias, para sugerir o tema e não repetir ideia.

## v0.110 — Definições únicas propostas (aguardando aprovação)
- **Receita**: competência, igual à DRE. A venda entra pela data da venda (aprovada, sem reembolso) e o contrato pela parcela no vencimento. "Recebido" e "a receber" são outras medidas, com outro nome.
- **Lucro**: o da DRE.
- **Imposto real**: o lançado nas vendas. A simulação de regime só existe nos cenários.
- **Regime tributário**: um só, no Cadastro da empresa.
- **Clientes novos**: 1ª compra aprovada ou 1º contrato ativado no período.
- **CAC de mídia**: investimento em anúncios ÷ clientes novos.
- **ROAS**: receita das vendas atribuídas ÷ investimento.
- **Ticket**: por produto.
- **LTV**: receita líquida acumulada por cliente. O "LTV de margem" é uma métrica separada.
- **Período**: um seletor comum a todas as telas.

## v0.111 — Definições em uso
- **Receita do mês**: DRE, competência. A venda conta na data da venda (horário de Brasília) e o contrato na parcela do mês. "A receber" é outra medida e tem outro nome.
- **Lucro**: o da DRE, igual no Dashboard, no Dashboard financeiro, em Custos e margens e no Growth Model (meses fechados).
- **Imposto e taxas**: os lançados. Se nada foi lançado no mês e não há imposto configurado, há uma estimativa pelo regime do Cadastro da empresa, marcada como "estimado". O % de taxas do cadastro só entra quando não há taxas lançadas.
- **Regime**: um só, no Cadastro da empresa. Só administrador muda. O cenário do Growth Model pode simular outro.
- **Custo de entrega por produto**: premissa das projeções; no real não entra.
- **Dashboard (Administrativo)**: "Receita bruta das vendas" = vendas aprovadas no período. Parcelas de contrato entram no Lucro.

## v0.112 — Dados de teste
- O workspace de teste tem nome fixo (Escola Aurora). O arquivo não roda de novo se ele já existir.
- As métricas de anúncio da Escola Aurora entram como `integracao`, para não acionar o aviso de dado importado por planilha.
- Os leads de quem já estava na base entram por toque de captura, sem criar pessoa duplicada. Nova tentativa de cadastro soma em "repetidas".

## v0.113 — Leads de formulários
- O lead precisa de e-mail válido ou telefone; sem os dois, não é gravado (erro 400).
- Prioridade da `utm_campaign`:
  1. a do formulário;
  2. a do endereço da página (campo `pagina`);
  3. a do endereço da função.
- Lead com `utm_campaign` que não pertence a nenhum canal entra sem campanha e com aviso. "Religar leads" resolve depois.
- A mesma pessoa (telefone ou e-mail) não é duplicada:
  - nova tentativa na mesma campanha conta como "repetida";
  - campos vazios (telefone, e-mail, nome) são completados, sem tirar de outra pessoa;
  - as respostas se somam (a mais nova vence).
- Data informada pelo formulário só vale entre 400 dias atrás e 1 hora à frente; fora disso, vale a hora do recebimento.
- Origem da pessoa: `formulario`, `respondi` ou `meta_lead_ads`, gravada nas respostas (`_origem`).

## v0.114 — Meta de leads
- Lead que conta para a meta: pessoa que entrou na campanha, uma vez cada (quem já estava na base também conta).
- Meta diária:
  - lançamento: meta de leads ÷ dias da captação (Datas das fases → Aquisição); sem essas datas, ÷ dias da campanha;
  - recorrente: meta do mês (ajuste do mês ou padrão) ÷ dias do mês.
- Meta do canal: a do canal (no recorrente, por mês). Sem ela, usa o % do canal sobre a meta da campanha. Ela é espalhada nos mesmos dias que a meta da campanha.
- Esperado até hoje: soma das metas diárias até ontem, mais a fração de hoje que já passou.
- Situação:
  - no ritmo: 100% ou mais do esperado;
  - perto: 85% a 99%;
  - abaixo: menos de 85%;
  - mês encerrado: dentro (bateu a meta) ou fora.
- Precisa por dia: (meta − leads) ÷ dias que faltam na captação (ou no mês).

## v0.115 — Detalhe da campanha
- Lead novo = cadastro criado pela campanha. Já na base = pessoa que existia e entrou na campanha.
- Pendente = lead sem qualificação definida (sem pesquisa respondida ou sem nota).
- Custo por lead novo = investimento ÷ leads novos (o mesmo do card). Custo por lead (todos) = investimento ÷ todos os leads.
- CAC = investimento ÷ clientes (pessoas distintas com venda aprovada da campanha). ROAS = receita bruta ÷ investimento.
- Venda por canal = canal por onde o comprador entrou na campanha.

## v0.116 — Árvore dos números
- **Resultado (Lucro, Margem, ROI, Receitas, Despesas)**: partidas dos lançamentos com data do fato no período.
  - Receita conta crédito − débito; deduções, custos e despesas contam débito − crédito.
  - Margem = lucro ÷ receitas. ROI = lucro ÷ (deduções + custos + despesas).
- **Vendas**: data da venda no fuso de São Paulo.
  - Líquido = bruto − taxas − impostos (± ajustes informados na venda).
  - Na tela de Vendas e no Dashboard de vendas, contrato ativo ou encerrado conta como venda (valor = parcelas não canceladas).
- **Dashboard de marketing**:
  - leads = pessoas captadas cadastradas no período;
  - clientes = esses leads com venda aprovada em qualquer data;
  - receita = valor líquido dessas vendas;
  - investimento = custo dos anúncios no período.
- **Campanha**:
  - leads da meta = participações; leads do CPL = cadastros novos;
  - clientes e receita = vendas aprovadas da campanha;
  - investimento = custo dos anúncios. Sem anúncio, contas a pagar e custos de CAC ligados à campanha.
- **Mídia paga**: tudo pelos números diários dos anúncios.
- **MRR**: contratos recorrentes ativos hoje (valor dos itens ÷ meses da periodicidade). ARR = MRR × 12.

## v0.120 — Comissões e conexões
- **Comissão** = base × % da regra. A base é o líquido (bruto − taxa − imposto) ou o bruto. Na parcela de contrato, a base é o valor − o desconto.
- **Qual regra vale**:
  - só regras ativas e dentro da vigência na data da venda (aprovação, horário de São Paulo) ou do recebimento da parcela;
  - "só as vendas dela" exige que a pessoa seja quem vendeu;
  - para a mesma pessoa vale a mais específica (oferta > produto > campanha > projeto); empate fica com a mais nova;
  - pessoas diferentes recebem cada uma a sua.
- **Competência** = mês da venda ou do recebimento. **Vencimento** = dia da regra, no mês seguinte.
- **Fechamento do mês** = comissões mensais previstas do mês − estornos pendentes até o mês. Se der zero ou menos, nada é lançado.
- **Venda devolvida** (reembolso, cancelamento ou chargeback):
  - prevista → cancelada;
  - "por venda" com a conta não paga → conta e comissão canceladas;
  - lançada ou paga → estorno pendente.
  - Se a venda volta a valer antes do desconto, a comissão volta a "lançada".
- **Venda pendente** não gera comissão.
- **Conexões**:
  - a primeira sincronização traz os dias escolhidos (7 a 180); as seguintes, os últimos 3 dias;
  - a campanha da plataforma é ligada ao canal quando o nome dela, ou o `utm_campaign` dos parâmetros do anúncio, é igual ao `utm_campaign` do canal;
  - o anúncio é reconhecido pelo `utm_content` (ou, sem ele, pelo nome).

## v0.119 — Árvore, parte 4
- **Custo do mês (Custos e margens)** = contas a pagar com competência no mês, agrupadas por item, + recorrências ativas ainda não lançadas no mês (pelo valor da regra), − o que foi desmarcado em "Contar no custo".
- **Ponto de equilíbrio** = (custos contados [+ DAS no MEI]) ÷ (1 − alíquota efetiva − % variável). **Para a meta** = o mesmo, tirando também a margem desejada. No Simples, a alíquota depende da receita e a conta é refeita até estabilizar.
- **Imposto no equilíbrio** = receita do equilíbrio × alíquota efetiva (no MEI, o DAS fixo).
- **A receber no mês (Custos e margens)** = parcelas com vencimento no mês, menos as canceladas, já descontado o desconto.
- **MRR** (todas as telas): um contrato cancelado deixa de contar a partir do dia do cancelamento no horário de São Paulo.

## v0.118 — Árvore, parte 3
- **Caixa projetado em 30 dias** = saldo em banco + tudo previsto para receber até hoje + 30 dias (inclusive o que já venceu) − tudo previsto para pagar até a mesma data.
- **Novos em 30 dias** = pessoas cadastradas a partir de hoje − 29 dias (horário de São Paulo), de qualquer origem. **A qualificar** = qualificação pendente.
- **Campanhas ativas (Dashboard)**: totais desde o início. Investido = contas a pagar da campanha (menos canceladas) + custos de aquisição; CAC de mídia = investido ÷ pessoas com venda aprovada; ROAS = receita bruta ÷ investido.
- **Coorte por mês ou semana**: as pessoas que entraram no intervalo da coorte dentro do período escolhido; custo = anúncios nessas datas.
- **Venda**: líquido = bruto − taxa da plataforma − impostos.

## v0.117 — Árvore, parte 2
- **Lançamento**: o valor é a soma dos débitos, que é igual à soma dos créditos.
- **NRR** = MRR de hoje dos clientes que tinham contrato recorrente ativo há 365 dias ÷ o MRR deles naquela data. **GRR** = o mesmo, limitando cada cliente ao que pagava antes (sem expansão).
- **Penetração** = clientes ativos ÷ mercado do Planejamento da empresa.
- **LTV (marketing)** = receita líquida da coorte ÷ clientes da coorte. **Churn (marketing)** = alunos da coorte que saíram de todos os cursos ÷ alunos da coorte.
- **Contas a receber e a pagar**:
  - previsto, pela data de vencimento no período;
  - recebido ou pago, pela data do recebimento ou pagamento (sem ela, pelo vencimento);
  - em atraso, previsto com vencimento antes de hoje.
- **Contratos** (situação ativo):
  - total = parcela × número de parcelas (recorrente) ou soma dos itens (avulso);
  - valor mensal = itens ÷ meses da periodicidade.
