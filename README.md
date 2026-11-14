# Growths

Central de gestão e inteligência de crescimento para negócios digitais (infoprodutores e prestadores de serviço), da Mathisa. Num só sistema, multi-cliente (cada cliente é um workspace isolado), o Growths reúne:

- captação de leads com UTMs;
- CRM, vendas, contratos e comissões;
- contabilidade gerencial (partidas, DRE e fluxo de caixa);
- campanhas e mídia paga;
- RevOps e Growth Model;
- a "árvore dos números", que mostra de onde vem cada número da tela.

Este repositório é o **lugar padrão de salvar as mudanças**. Cada entrega vira um commit, e o registro de cada versão fica na tabela abaixo. O detalhe completo de cada versão está em [CHANGELOG.md](CHANGELOG.md).

## Estado atual

| | |
|---|---|
| **Versão da tela** | 0.294 · 14/11/2026 (`index.html` + `assets/atendimento.*`) |
| **Atendimento (0.175)** | Código preparado; falta aplicar `supabase/migrations/20261030021541_central_atendimento.sql`, publicar a função `atendimento`, configurar canais e liberar as telas nos pacotes. [Guia](docs/atendimento.md). |
| **Banco em produção** (Supabase `yngyghlyonybvfvjcmxl`) | conferido em 31/10/2026: tem tudo até a **v0.189**, inclusive as narrativas (v0.157, 39 modelos), o Growth's Content simplificado (v0.159), os subtemas (v0.160), o Customer Growth (v0.163), o Atendimento e o Diagnóstico 360° (v0.177) |
| **Falta aplicar no banco** | `supabase/RODAR_v0.197_pesquisa_modelos.sql` (modelos de pesquisa fora da lista) e `supabase/RODAR_v0.198_plano_anual.sql` (meta do ano, com impostos e custos variáveis da v0.199) `supabase/RODAR_v0.205_go_to_market.sql` (pacote Go-to-Market e custos de marketing) `supabase/RODAR_v0.206_historico_vendas.sql` (histórico de vendas) `supabase/RODAR_v0.208_vendas_periodo.sql` (dashboard de vendas) e `supabase/RODAR_v0.209_financeiro_simplificado.sql` (Financeiro simplificado) |
| **Falta publicar** | a função `conexoes` (sem verificação de JWT), quando os apps do Meta e do Google existirem |
| **Falta configurar** | app do Meta; crédito na conta da API da Anthropic (a chave `ANTHROPIC_API_KEY` está cadastrada e funciona, mas as pesquisas de 25 e 26/10 voltaram com "credit balance is too low"); o app do Google já existe (segredos conferidos em 25/10/2026): [docs/conectar-meta-e-google.md](docs/conectar-meta-e-google.md) |

**Planejamento de campanha avançado** (v0.287, 08/11/2026): tela nova em Marketing. Fonte, motor e 82 testes em `docs/planejamento-campanha-avancado/`. Desde a v0.293, o Diagnóstico/baseline e o Plano e resultados do ano moraram para o **Administrativo** (telas só da equipe interna); a campanha em Marketing ficou só com o planejamento da campanha em si.

**Em desenvolvimento (branch `fix/zernio-vinculo-por-cliente`):** v0.178 — vínculo de contas Zernio por cliente em Integrações, com opção de iniciar pelo Atendimento; requer migração, publicação da Edge Function e homologação. Não está na `main` nem publicado em produção.

**Correção v0.180:** o OAuth de Instagram agora aparece no cartão Instagram original de Integrações, sem painéis duplicados. Branch `fix/instagram-cartao-existente`, sem novos requisitos de banco ou Edge Function.

## Registro de versões

Cada linha é uma entrega. **Banco** diz se a versão mudou o banco e se já está em produção.

| Versão | Data | O que mudou | Banco |
|---|---|---|---|
| 0.294 | 14/11/2026 | **Administrativo → Uso do Growths pelos clientes** (só equipe interna): ranking dos clientes mais ativos, telas mais usadas por toda a carteira e atividade por dia, reaproveitando a coleta que já existia desde a v0.30. Corrige uma reatribuição antiga que fazia `adm-plano` abrir a campanha em vez do Plano do ano. | `RODAR_v0.294_uso_resumo_mathisa.sql` |
| 0.293 | 13/11/2026 | Diagnóstico/baseline e Plano e resultados do ano saem da campanha e ganham telas no **Administrativo** (só a equipe interna). Cliente novo entra direto no Diagnóstico e baseline ao ser cadastrado. Campanha avançada fica só com a campanha. | Sem mudança |
| 0.292 | 13/11/2026 | **Planejamento avançado**: aba Resultados do ano (trimestres, planejado → realizado por campanha, onde as premissas erraram) e ligação do planejamento a uma campanha. | Sem mudança |
| 0.291 | 13/11/2026 | **Planejamento avançado**: aba Plano do ano (meta × baseline, orçamento de aquisição, CAC máximo, cenários, trimestres; alimenta as campanhas). | Sem mudança |
| 0.290 | 13/11/2026 | **Planejamento avançado**: aba Diagnóstico e baseline (indicadores com origem, cobertura e confiança; custo de servir; aprovação com versão). | Sem mudança |
| 0.289 | 08/11/2026 | **Planejamento avançado** com o visual do assistente Nova campanha (barras de passo, rodapé, tema do Growths). | Sem mudança |
| 0.288 | 08/11/2026 | **Planejamento avançado**: tipo de campanha (objetivo × modelo) no passo 1; funil e cálculo seguem o tipo. | Sem mudança |
| 0.287 | 08/11/2026 | **Marketing**: Planejamento de campanha avançado (tela nova, dados reais, salva rascunho). | Sem mudança |
| 0.285 | 07/11/2026 | **Conteúdo**: copiar para a IA com as referências; botão no painel Detalhes. | Sem mudança |
| 0.284 | 07/11/2026 | **Conteúdo**: copiar tudo de um ou vários conteúdos para levar a uma IA. | Sem mudança |
| 0.283 | 07/11/2026 | **Conteúdo**: selecionar vários e mover de uma vez, dois cliques para abrir, carregamento mais rápido. | Sem mudança |
| 0.282 | 07/11/2026 | **Conteúdo**: aprovar a ideia sem data; tema e data só na produção. | `20270126100000_conteudo_aprovar_sem_data.sql` (rodar `RODAR_v0.282`) |
| 0.275 | 06/11/2026 | **Conteúdo**: colunas livres por etapa, prioridade pelo score no cartão, busca por texto e voz, ordem. | `20270122100000_v0275_conteudo_colunas.sql` |
| 0.274 | 06/11/2026 | **Filtros e métricas**: teto de CAC por produto e turma, MRR/ARR/NRR/penetração/NSM no cockpit, filtro por nota no conteúdo. | `20270121100000_v0274_teto_turma.sql` |
| 0.273 | 06/11/2026 | **Teto de CAC pelo LTV**: no cockpit, por produto, na campanha e na calculadora, com Selic automática. | `20270120100000_v0273_teto_cac_ltv.sql` |
| 0.272 | 06/11/2026 | **Conteúdo em destaque**: painel lateral móvel e geração pela estrutura de copy escolhida. | `20270119100000_v0272_estruturas_e_roteiro.sql` |
| 0.271 | 06/11/2026 | **Editar continua de onde parou**: passos preenchidos marcados e clicáveis, sem perder o que foi digitado. | — |
| 0.262 | 04/11/2026 | **Histórico no passo Canais**: porcentagem de cada canal na última campanha e na média; Planejamento sem repetição. | `20270116100000_v0262_canais_historico.sql` |
| 0.261 | 04/11/2026 | **Bruto de anúncios**: tabelas de Meta, Google Ads e YouTube Ads com tudo o que a API devolve. | `20270115100000_v0261_ads_bruto.sql` |
| 0.260 | 04/11/2026 | **Dashboard único da campanha**: lançamento sem abas, filtros que mudam os gráficos, comparação com outra campanha e meta por canal. | — |
| 0.259 | 04/11/2026 | **Etapas e submenus pela estratégia**: barra sempre com Aquecimento e Carrinho, submenus por bloco e Editar campanha no assistente. | `20270114100000_v0259_etapas_por_dia.sql` |
| 0.258 | 04/11/2026 | **Campanha com mini gráficos e order bump separado**: tela por etapas em todo lançamento, vendas por oferta e uma venda por item na Eduzz e na Hubla. | `20270113100000_v0258_order_bump_por_item.sql` |
| 0.257 | 04/11/2026 | **Kiwify, Eduzz e Hubla**: ativação por cliente, tabelas brutas e tratamento em vendas e clientes. | `20270112100000_v0257_kiwify_eduzz_hubla.sql` |
| 0.256 | 04/11/2026 | **Bruto da Hotmart e campanha por etapas**: tabela bruta completa, tratamento de clientes sem duplicar, tela por etapas com filtros, gráficos e simulador. | `20270111100000_v0256_hotmart_bruto.sql` |
| 0.255 | 04/11/2026 | **Vendas da Hotmart automáticas**: webhook 2.0.0, reembolso e chargeback com estorno, vendedor pelo código do link e eventos a revisar. | `20270110100000_v0255_webhook_hotmart.sql` |
| 0.254 | 04/11/2026 | **Comercial da campanha**: vendedor interno ou externo, comissão, meta e link por campanha, e a previsão do que sobra do faturamento. | `20270109100000_v0254_comercial_campanha.sql` |
| 0.253 | 04/11/2026 | **Assistente da campanha**: ofertas escolhidas do cadastro, cenários para cada oferta e canais com porcentagem de leads e de vendas. | `20270108100000_v0253_metas_canal_e_oferta.sql` |
| 0.252 | 03/11/2026 | **Faturamento e Receita líquida**: as campanhas mostram os dois números e o ROAS passa a ser sobre o faturamento. O financeiro não muda. | `20270107110000_v0252_faturamento_e_receita.sql` |
| 0.251 | 03/11/2026 | **Uma conta só para CAC de mídia, ROAS e receita**: investimento pelos anúncios, CAC por vendas e receita sem as vendas de quem saiu, nas telas de marketing. O financeiro não muda. | `20270106100000_v0251_cac_roas_receita.sql` |
| 0.250 | 03/11/2026 | **Fase da campanha, luzinha de meta, foto e saudação**: telas conforme a fase; dashboard de marketing sem ROI e LTV, com ticket médio e churn em pessoas; luzinha de meta × planejado; foto com menu da conta e saudação pelo horário. | `20270105100000_v0250_ticket_e_foto.sql` |
| 0.249 | 03/11/2026 | **Assistente da campanha**: passo Oferta, datas em qualquer campanha, filtro por período, gráficos de linha e order bump, upsell e downsell no histórico e nos cenários. | Sem migração |
| 0.248 | 03/11/2026 | **Assistente da campanha**: passo próprio para as datas das etapas do lançamento (com reabertura e downsell) e três cenários no orçamento, com recálculo entre as métricas e o Base vindo do histórico. | Sem migração |
| 0.247 | 03/11/2026 | **Assistente da campanha**: datas de cada etapa do lançamento e passo "Histórico e referências", com quantas campanhas trazer, lista de métricas, gráficos, histórico da campanha clicada e a escolha de levar a média ou uma campanha para CPL, CAC e conversão. | Sem migração |
| 0.246 | 03/11/2026 | **Histórico e referências no planejamento da campanha**: até 3 campanhas finalizadas do mesmo produto e modelo, médias ponderadas, avisos, "Usar as médias como metas" e memória das referências usadas. | Sem migração |
| 0.245 | 02/11/2026 | Aviso de formulário respondido (faixa verde, Meus avisos, WhatsApp), com a pontuação da qualificação. | RODAR_v0.245 |
| 0.244 | 02/11/2026 | Aviso de lead novo (faixa verde, Meus avisos, WhatsApp da empresa) e "Gerar novo link" nas pesquisas. | RODAR_v0.244 + função avisos |
| 0.243 | 02/11/2026 | Celular: blocos em sanfona, Kanban uma etapa por vez, janelas em tela cheia com Voltar. | — |
| 0.242 | 02/11/2026 | Kanban do Content: no computador só arrastar; "Mover para" só no celular. | — |
| 0.241 | 02/11/2026 | Growth's Content: Kanban logo abaixo da contagem por etapa, antes do calendário. | — |
| 0.240 | 02/11/2026 | Growth's Content: Baú de ideias com microfone (fala → ideia esperando aprovação). | — |
| 0.239 | 02/11/2026 | Diagnóstico dos dados: o que cada planilha traz, o que o Growths identificou e não identificou, métricas e perguntas para a reunião. | — |
| 0.238 | 02/11/2026 | Diagnóstico: Dados depois de "O que falta"; importar cada planilha para o Growths do cliente com o de-para. | — |
| 0.237 | 02/11/2026 | Diagnóstico: o cliente volta a anexar os arquivos; o editor de perguntas não apaga mais a configuração. | RODAR_v0.237 (dados) |
| 0.236 | 02/11/2026 | Diagnóstico: link do cliente sempre visível; reabrir o formulário para ele continuar. | RODAR_v0.236 |
| 0.235 | 02/11/2026 | Formulário embutido: endereço /formulario liberado para abrir dentro de outra página. | — |
| 0.234 | 02/11/2026 | Código (embed) para colocar o formulário na página, em Formulário e aparência. | — |
| 0.233 | 02/11/2026 | Qualificação do lead por produto (Starter, Strategy, Full Brain): blocos, eliminatórias, regras e o formulário "Lead: qualificação". | RODAR_v0.233 e 0.233b |
| 0.232 | 02/11/2026 | Correção: gerar o link do formulário no diagnóstico (botão "Gerar o link do formulário"). | RODAR_v0.232 |
| 0.231 | 02/11/2026 | Clientes: o Growths nasce do contrato; inativar, reativar e excluir. | RODAR_v0.231 |
| 0.230 | 02/11/2026 | Formulário para clientes: atualiza o cliente e a etapa na jornada, sem Funil de leads. | RODAR_v0.230 |
| 0.229 | 02/11/2026 | O que já se sabe (origem e conflitos entre fontes); excluir pergunta na lista. | RODAR_v0.229 |
| 0.228 | 02/11/2026 | Diagnóstico de clientes da Mathisa: começa pelo cliente e pelo formulário. | RODAR_v0.228 |
| 0.227 | 02/11/2026 | Auditoria automática das planilhas do diagnóstico. | RODAR_v0.227 |
| 0.226 | 02/11/2026 | Diagnóstico em sete abas, na ordem do trabalho; de-para em três abas. | nada |
| 0.225 | 02/11/2026 | De-para das métricas; formulário só conclui com os arquivos resolvidos; métricas principais. | RODAR_v0.225 |
| 0.224 | 02/11/2026 | Pré-diagnóstico na Investigação, antes da reunião. | RODAR_v0.224 |
| 0.223 | 02/11/2026 | Diagnóstico Inteligente D1: diagnóstico da empresa, cinco abas e Central de Evidências. | RODAR_v0.223 |
| 0.222 | 02/11/2026 | Cockpit em abas (Áreas, Metas do período, Riscos e oportunidades). | nada |
| 0.221 | 01/11/2026 | Metas das áreas (margem, caixa, CS, North Star) no Planejamento anual e no Cockpit. | RODAR_v0.221_brain_metas_areas.sql |
| 0.220 | 01/11/2026 | Acerto da projeção: erro e viés históricos e faixa provável no Cockpit. | RODAR_v0.220_brain_calibracao.sql |
| 0.219 | 01/11/2026 | Funil AARRR no Cockpit (etapas, metas, North Star, gargalo). | RODAR_v0.219_brain_aarrr.sql |
| 0.218 | 01/11/2026 | Simular cada meta: alavancas, atual × cenário, premissas; cenários salvos com versão. | RODAR_v0.218_brain_cenarios.sql |
| 0.217 | 01/11/2026 | Investigar: do número do Cockpit até as vendas ou os leads, com filtro cruzado e caminho de volta. | RODAR_v0.217_brain_investigar.sql |
| 0.216 | 01/11/2026 | Trajetória das metas no Cockpit e saúde por área. | RODAR_v0.216_brain_trajetoria.sql |
| 0.215 | 01/11/2026 | Risk Engine: riscos e oportunidades no Cockpit, com evidência, impacto, ação e tratamento. | RODAR_v0.215_brain_riscos.sql |
| 0.214 | 01/11/2026 | Metas de leads, vendas, campanhas e produtos no registro central e no Cockpit. | RODAR_v0.214_brain_metas_2.sql |
| 0.213 | 01/11/2026 | Growth's Brain: meta de faturamento no Cockpit (esperado, realizado, projeção, status), objetivos do ano, NSM provisória. | RODAR_v0.213_brain_metas.sql |
| 0.212 | 01/11/2026 | Todos os dashboards com o mesmo filtro de período (começa no mês corrente); sem o Planejamento da empresa antigo. | nada |
| 0.211 | 01/11/2026 | Dashboards com o mesmo filtro de período, que vale em todos. | nada |
| 0.210 | 01/11/2026 | Financeiro simplificado também no completo; comissão de parceiro geral ou por produto. | `RODAR_v0.209_financeiro_simplificado.sql` (atualizado), **ainda não aplicado** |
| 0.209 | 01/11/2026 | **Financeiro simplificado**: DRE simplificado sem contas a pagar, custos por grupo, comissões de parceiros. | `RODAR_v0.209_financeiro_simplificado.sql`, **ainda não aplicado** |
| 0.208 | 01/11/2026 | **Dashboard de vendas** no padrão: filtro de período e os números de vendas e clientes no topo. | `RODAR_v0.208_vendas_periodo.sql`, **ainda não aplicado** |
| 0.207 | 01/11/2026 | Entrada do cliente: ✓ verde, métricas que acompanha, teste pelo link aberto. **index.html restaurado** (commits de atendimento tinham cortado o arquivo). | nada |
| 0.206 | 01/11/2026 | **Histórico de vendas**: importar o relatório da plataforma com de-para, ficha com o histórico, planejamento com o histórico. | `RODAR_v0.206_historico_vendas.sql`, **ainda não aplicado** |
| 0.205 | 01/11/2026 | **Go-to-Market**: pacote sem financeiro, Custos de marketing com rotina mensal, Resultado de marketing, vendas por plataforma. | `RODAR_v0.205_go_to_market.sql`, **ainda não aplicado** |
| 0.204 | 01/11/2026 | Pesquisas: nome interno e título para quem responde. | nada |
| 0.203 | 01/11/2026 | Entrada do cliente: vendas por plataforma marcada (Hotmart, Kiwify, Eduzz, Hubla). | nada |
| 0.202 | 01/11/2026 | Entrada do cliente: cada grupo de arquivos é enviar ou "Não tenho" (sem "Mando depois"). | nada |
| 0.201 | 01/11/2026 | **Entrada do cliente**: formulário curto com a visão do cliente e checklist de arquivos com planilha-modelo. | nada |
| 0.200 | 01/11/2026 | **Planejar outro ano**: ano no topo da aba, começar com as premissas do ano anterior, excluir a meta. | `RODAR_v0.198_plano_anual.sql` (atualizado), **ainda não aplicado** |
| 0.199 | 01/11/2026 | **Meta do ano** em quatro passos, impostos pelo regime (MEI, Simples pelo fator R, Presumido, Real), margem corrigida e lucro final por cenário. | `RODAR_v0.198_plano_anual.sql` (atualizado), **ainda não aplicado** |
| 0.198 | 01/11/2026 | **Planejamento anual**: meta do ano (caminho, premissas com origem, cenários, diferença) e trimestres (ritmo, sugestão mês a mês, previsão). | `RODAR_v0.198_plano_anual.sql`, **ainda não aplicado** |
| 0.197 | 01/11/2026 | **Pesquisas**: Editar e Excluir à vista (lista e topo), aviso do que vai junto ao excluir, e Modelos (usar, tirar da lista, mostrar de novo). | `RODAR_v0.197_pesquisa_modelos.sql`, **ainda não aplicado** |
| 0.196 | 01/11/2026 | **Mapa da estratégia**: bolinha de ligação nos quatro lados do bloco, mais de uma ligação entre os mesmos blocos e escolha do lado no painel. | Só tela |
| 0.195 | 01/11/2026 | **Mapa da estratégia**: order bump, downsell, tela cheia e edição com dois cliques; menu **RevOps → Customer Success**. | Só tela |
| 0.194 | 31/10/2026 | **Campos de formulário mais legíveis**: nome do campo em negrito, caixa com borda visível, exemplo em itálico. | Só tela |
| 0.193 | 31/10/2026 | **Pesquisa na campanha**: passo 4 na nova campanha (usar pesquisa, qual, onde entra), código para a página de obrigado e leads da campanha na fila de envio. | Só tela |
| 0.192 | 31/10/2026 | **Dashboards em seções**: Dashboard, Dashboard financeiro e Dashboard de Vendas com seções de moldura e título (visão geral, alertas, evolução e meta, de onde vem a receita, saúde financeira, funil e campanhas...). | Só tela |
| 0.191 | 31/10/2026 | **Pagar e receber várias contas de uma vez**: seleção em Contas a pagar e Contas a receber, com barra de total e baixa em lote. | Só tela |
| 0.177 | 30/10/2026 | **Diagnóstico 360°: formulário curto, arquivos e reunião (G1b, G2, G3)**: modelo curto do cliente com métricas no modo simples e rascunho; envio de arquivos pelo link para um local privado; reunião da equipe com perguntas por natureza da métrica, roteiro do modelo completo e leitura dos arquivos no Diagnóstico Growth guardada no diagnóstico do cliente. | `20261129100000_diagnostico_g1b.sql`, `20261129110000_diagnostico_g2_arquivos.sql`, `20261129120000_diagnostico_g3_reuniao.sql` + função `diagnostico-arquivo` |
| 0.176 | 30/10/2026 | **Diagnóstico 360° (G1)**: formulário do cliente (para lead ou cliente), tipos de pergunta novos (métricas do funil pirata com tenho/não tenho e o detalhe de cada uma, mês a mês, lista, documentos), perguntas condicionais, link com validade e o modelo pronto com as 8 seções; catálogo de métricas por etapa do funil pirata. | `20261128100000_diagnostico_g1.sql` — aplicado em produção |
| 0.175 | 30/10/2026 | **Atendimento multicanal**: conversas, grupos Evolution, QR/status, cartão URL/Key, WhatsApp oficial e Instagram/Zernio, assinatura do usuário, notas internas e vínculo com a ficha do cliente. | `20261030021541_central_atendimento.sql` + função `atendimento` — **ainda não publicados** |
| 0.174 | 30/10/2026 | **E2**: o lead vira **oportunidade** e a oportunidade gera o **contrato em rascunho** (a proposta), com mais de um contrato por oportunidade; ativar o contrato ganha a oportunidade; CPF/CNPJ pedido no contrato. | `20261127100000_oportunidade_contrato.sql` — aplicado em produção |
| 0.173 | 30/10/2026 | **E1 da integração comercial**: CPF/CNPJ na pessoa (validado, único, buscável) e **linha do tempo única do cliente** na ficha (cadastro, marketing, comercial, financeiro, jornada e CS). Correção: mesclar cadastros sem tags falhava. | `20261126100000_pessoa_documento.sql` — aplicado em produção |
| 0.172 | 30/10/2026 | **Resumo da estratégia** (dados, versão e funil por fase) e botão **Criar campanha** a partir da estratégia, que já vem escolhida e copia as etapas. | Sem mudança no banco |
| 0.171 | 29/10/2026 | **Correção de publicar a estratégia** (dava "Sem permissão"); fase no próprio card; soltar na faixa define a fase; bloco **Passagem para o CS**. | `20261125100000_estrategia_publicar_definer.sql` — aplicado em produção |
| 0.170 | 29/10/2026 | **Criar a estratégia pelo mapa**: "Criar no mapa" abre um mapa em branco; ao publicar, dá o nome e a estratégia entra na lista com as etapas montadas (versão 1). | Sem mudança no banco |
| 0.169 | 29/10/2026 | **Lixeira nos cards do Canvas**: um clique exclui o bloco, e o mapa oferece Desfazer por 8 segundos. | Sem mudança no banco |
| 0.168 | 29/10/2026 | **Canvas por fase**: o funil inteiro num mapa só, com cor e faixa por fase (Captação, Aquecimento, Vendas, Pós-venda/CS) e legenda que destaca uma fase. Correção: trocar de workspace com uma estratégia aberta gravava os blocos no workspace errado. | Sem mudança no banco |
| 0.167 | 29/10/2026 | **Ajustar os cards do Canvas**: arrastar o card por qualquer ponto (encaixa na grade), mudar o tamanho de cada card pelo canto e botão **Organizar** (colunas por fase, sem encostar). | Sem mudança no banco |
| 0.166 | 29/10/2026 | **Desenhos no Canvas**: cada bloco mostra o que é (mini página com foto e textos, anúncio com o símbolo da Meta ou do Google, WhatsApp com a escolha API ou Grupo, vídeo, e-mail, lógica). | Sem mudança no banco |
| 0.165 | 29/10/2026 | **Strategy Canvas (S1 a S3)**: Marketing → Estratégias (Canvas) com biblioteca (categoria, versão, situação), mapa visual da estratégia (arrastar blocos, ligar com sim/não/divisão, painel de propriedades) e vista em lista; **versões** publicadas, e cada campanha guarda a versão que usou. | `20261124100000_strategy_canvas.sql` — aplicado em produção |
| 0.164 | 29/10/2026 | **Cockpit** na entrada do Growths: um painel compacto por área (Geral, Marketing, Vendas, Financeiro, Projetos, Growth e Clientes), dois lado a lado, com os números principais do período e um gráfico (7 dias, 30 dias, mês, ano); clicar no painel abre o dashboard do módulo. Cada painel só aparece para quem tem acesso ao módulo. | Só tela |
| 0.163 | 29/10/2026 | **Customer Growth (RevOps)**: cada produto ganha a sua **Jornada do produto** (etapas com versão; ao publicar, quem já está dentro continua ou é transferido; modelos de jornada); Alunos com seletor de jornada e lista de todos os produtos; **marcos** manuais, automáticos ou com confirmação (compra, vídeo, pesquisa, etapa, grupo, evento da plataforma do curso); seção **Jornada e evolução** na ficha, por produto; pesquisa que dispara na etapa do aluno e **check-in a cada N dias**; **alertas de CS** de hora em hora; **intervenções de CS** (tabela própria, também em Minhas atividades); oportunidades de expansão e retenção ligadas à matrícula; tela **RevOps → Customer Growth** com Evolução, Check-ins, Alertas e intervenções, Retenção e expansão e Indicadores. | Aplicado em produção em 29/10/2026; alertas de CS ligados |
| 0.162 | 29/10/2026 | **Mapa de métricas com a North Star em destaque**: NSM com estrela, valor grande e frequência; as filhas dela aparecem em "Alavancas que movem a NSM", com o papel (Driver/Input) e a variação ao lado do valor; na NSM o botão vira "+ Alavanca". | Só tela |
| 0.161 | 26/10/2026 | **Pesquisa must-have da consultoria** (modelo em Pesquisas, 25 perguntas em 6 passos) e leitura do must-have em três faixas nos Resultados. | Só tela |
| 0.160 | 26/10/2026 | **Produção = Kanban com calendário** e a aprovação em cada cartão; **Linha editorial** com subtemas e conteúdos por segmento; ideia aprovada com tema, subtema, formato e data. | `RODAR_v0.160_content_segmentos.sql`, **ainda não aplicado** |
| 0.159 | 26/10/2026 | **Growth's Content simplificado**: cinco abas (Base do cliente, Identidade visual, Ideias, Produção, Mais ferramentas), ficha do dossiê com versões, identidade com prévia, roteiro aprovado antes da peça, versões e ajustes. Botões da Claude desligados até haver crédito na API. | `RODAR_v0.159_content_simples.sql`, **ainda não aplicado** |
| 0.158 | 26/10/2026 | **Telas em grade**: Dashboard e Dashboard financeiro em blocos lado a lado, gráficos no tamanho do bloco, uma coluna no celular. Backup antes: branches `backup-v0.157` e `backup-v0.156`. | Só tela |
| 0.157 | 26/10/2026 | **Banco de narrativas**: as frases de análise passam a morar na tabela `narrativa_modelos` (código, versão, aprovação, histórico); a tela só preenche números calculados. Piloto no **Dashboard financeiro**: frase da cascata com "sobraram/faltaram", ponte do resultado (mês anterior → atual), caixa projetado e saldo mínimo num painel só. Dicionário mostra as frases. | `RODAR_v0.157_narrativas.sql`, **ainda não aplicado** em produção |
| 0.156 | 26/10/2026 | **Alertas em quatro categorias** (favorável, desfavorável, atenção, informativo) e **Dicionário de métricas** com unidade, direção, zero como limite e referência. | `RODAR_v0.156_metricas_semantica.sql`, aplicado em 26/10/2026 |
| 0.155 | 26/10/2026 | **Contexto e frase-recado** no Financeiro, Marketing e Vendas (contra o período anterior, com a base escrita); custos neutros. | Só tela |
| 0.154 | 26/10/2026 | **Gráficos**: negativos na escala (dois gráficos do Financeiro voltaram), cascata com custos neutros e resultado com sinal, meta e saldo mínimo como linha de referência, séries sem verde/vermelho. | Só tela |
| 0.153 | 26/10/2026 | **Cor pelo significado em todas as telas**: zero como limite só nos saldos, variações pela direção com tolerância de 5%, cores de status novas, sem neon nos números, sinal de menos verdadeiro. | Só tela |
| 0.152 | 26/10/2026 | **Data Storytelling no Dashboard (piloto)**: camada semântica (tokens, dicionário, formatador), receita com a variação das vendas, lucro em reais e vermelho, escala única nos cartões, mês cheio contra mês cheio. | Só tela |
| 0.151 | 25/10/2026 | **Pesquisa com um botão** (pastas + call + produtos + canais + web, relatório para ler) e o **dossiê** em seções. | `RODAR_v0.151_content_pesquisa.sql` + função `content-pesquisa`, aplicado em 25/10/2026 (falta a chave da API e reimplantar o Apps Script) |
| 0.150 | 25/10/2026 | **Ficha de produto simples** (nome, valor, histórico) no Growth's Content e o bloco **Produtos e esteira** no questionário da call. | `RODAR_v0.150_content_produtos_v2.sql`, aplicado em 25/10/2026 |
| 0.149 | 25/10/2026 | **Produtos na Estratégia de conteúdo**: ficha de conteúdo de cada produto (público, dor, transformação, método, provas, objeções, momento de venda) e ideias ligadas a um produto. | `RODAR_v0.149_content_produtos.sql`, aplicado em 25/10/2026 |
| 0.148 | 25/10/2026 | **Painel da produção no Kanban**: total por etapa, prontos da semana contra a meta e calendário das próximas semanas (completas ou quanto falta). | Só tela |
| 0.147 | 25/10/2026 | **Só a pasta do cliente** (sai o Drive da Mathisa), **outras pastas que o cliente já tem** no passo 1 e **Pastas da Mathisa** (padrões) numa tela interna. | `RODAR_v0.147_content_pastas.sql`, aplicado em 25/10/2026 |
| 0.146 | 25/10/2026 | **Estruturas de roteiro e copy** (biblioteca interna; o cliente só escolhe por formato) e **Custos de IA** (só para a Rebecka). | `RODAR_v0.146_content_estruturas.sql`, aplicado em 25/10/2026 |
| 0.145 | 25/10/2026 | **Canais e materiais do cliente antes da call**: configuração em 9 passos; o cliente informa o @ de cada plataforma e resolve seis tipos de material, cada um com a sua pasta. | `RODAR_v0.145_content_fontes.sql`, aplicado em 25/10/2026 |
| 0.144 | 25/10/2026 | **Configuração em 8 passos**: o cliente **compartilha uma pasta do Drive** dele e o Growths cria a árvore de 10 pastas (gratuito); roteiro da **call de briefing** na tela; lista de **materiais**; pesquisa, tese e dossiê em construção. | `RODAR_v0.144_content_setup_v2.sql` + função `content-drive`, aplicado em 25/10/2026 |
| 0.143 | 25/10/2026 | **Growth's Content começa pela configuração**: passo a passo de 5 telas antes das abas; passo 1 **conecta o Google Drive do cliente** e cria lá a pasta (sem Drive, no da Mathisa). | `RODAR_v0.143_content_setup.sql` + função `content-google`, aplicado em 25/10/2026 |
| 0.142 | 25/10/2026 | Corrigido: cliente do **Growth's Content** ficava como Growth Starter (sem o Marketing); agora vira Growths completo, com aviso. | Só tela |
| 0.141 | 25/10/2026 | **Novo cliente** com "O que o cliente acessa" em árvore (setinhas, tela por tela, atalhos); **Growth's Content dentro de Marketing** libera só o módulo e cria a pasta no Drive; Instagram e DMs no catálogo dos pacotes. | `RODAR_v0.141_acesso_content.sql`, aplicado em 25/10/2026 |
| 0.140 | 25/10/2026 | Módulo renomeado para **Growth's Content**; "Usa o Growth's Content" no cliente cria a **pasta do cliente no Google Drive** (Apps Script), com link no topo do módulo. | `RODAR_v0.140_content_drive.sql` + função `content-drive`, aplicado em 25/10/2026 |
| 0.139 | 25/10/2026 | **Insights automáticos** no Instagram (assunto que mais engaja, o que levar para outros formatos, post que puxou conversa, DMs, salvos, compartilhados, melhor dia), cada um como fato, hipótese ou recomendação e com os posts que o formam; **melhores dias e horários** em linha. | Só tela, sem banco |
| 0.138 | 25/10/2026 | **Cores pela média** nos gráficos de tema, formato e tipo (verde acima, azul na média, vermelho abaixo, com "+X% vs. média"); cada gráfico num quadro; **menu em níveis** com recuo. | Só tela, sem banco |
| 0.137 | 25/10/2026 | **Os posts em imagens** no dashboard do Instagram (4 primeiro, Mostrar mais, ordenar por engajamento, curtidas, alcance, recentes…) e **gráficos por tema, formato e tipo de mídia** com filtro de métrica e de contagem; clicar na barra filtra a galeria. | Só tela, sem banco |
| 0.136 | 25/10/2026 | **Instagram vira submenu da Máquina de Conteúdo**; dashboard geral de canais (eficiência e melhores posts por canal); dashboard do Instagram só com dados da conexão (conta, cada post, melhores por frente, formato e tipo); classificar o post direto; saem importação manual e Relatórios. A tela mostra qual conta está conectada e em qual cliente. | `RODAR_v0.136_instagram_classificar.sql`, aplicado em 25/10/2026 |
| 0.135 | 25/10/2026 | **Máquina em duas partes**: Estratégia de conteúdo (com a aba **Canais**: canal por frente e por etiqueta) e **Instagram** (Dashboard, Ideias do canal, Relatórios, **DMs**). **DMs do Instagram** trazidas a cada 30 min; quem escreve vira lead no CRM; também em Vendas → DMs do Instagram. Corrigido: as DMs nunca chegavam. | `RODAR_v0.135_dms_canais.sql` + `zernio-sync`, aplicado em 25/10/2026 |
| 0.134 | 25/10/2026 | **Dashboard do Instagram** (aba da Máquina e atalho em Marketing): indicadores contra o período anterior, top 1, gráficos por dia, o que performa melhor por território, frente, formato, tipo, destino, etiqueta, dia e horário, melhores posts e cada post contra a média; importação da planilha do Meta Business Suite ou do Metricool até a Meta aprovar. | `RODAR_v0.134_instagram.sql`, aplicado em 25/10/2026 |
| 0.133 | 24/10/2026 | **Máquina de Conteúdo** (antes Planejamento de conteúdo): modelo V18 por botão (4 territórios com Empreendedorismo em Negócios, 5 formatos com Carrossel caderno e Série musical 1× por semana, quadros, destinos Rebecka/Mathisa/Ambas), pauta com palavra-chave, score de 6 critérios e VALIDAR, etiquetas e dia da semana; matriz território × formato, semana por dia, fechamento de sábado, questionário de persona com proposta de linha editorial pela IA. | `RODAR_v0.133_maquina_conteudo.sql` + edge function `linha-editorial`, aplicado em 25/10/2026 |
| 0.132 | 24/10/2026 | **Pergunte ao Growths**: "como foi meu dia ontem?" com os números exatos do dia e a comparação; IA com o dia a dia. **Alertas e resumo do dia**: conferência de hora em hora (mudança brusca, se repetindo, pede ação, dia sem dados), resumo de ontem toda manhã, avisos no sino, e-mail (Resend) e WhatsApp (Meta). | `RODAR_v0.132_alertas.sql` + `RODAR_v0.132_agendador.sql` + edge functions, aplicado em 25/10/2026 |
| 0.131 | 21/10/2026 | **Selo de qualificado** (verde/vermelho com a pontuação) no cartão, na ficha e na lista de leads; **tags coloridas**; aba **"Quem respondeu"** na pesquisa, com a pontuação de cada pessoa, situação no CRM, filtro e planilha. | não muda o banco |
| 0.130 | 21/10/2026 | **Formulário de captação nas Pesquisas**: aba "Formulário e aparência" com passos, link para enviar (com UTM e WhatsApp), contato que entra ou é atualizado no Funil de leads (etapa, tags, responsável, sem duplicar), aviso e confirmações gravadas, fontes e cores do cliente com pré-visualização; modelo pronto do diagnóstico de qualificação da Mathisa com a oferta sugerida como tag. | `RODAR_v0.130_formulario.sql`, aplicado |
| 0.129 | 21/10/2026 | **Movimento por dia da campanha num gráfico só**, com botões para escolher as métricas; **qualificação por pontos nas pesquisas** (pontos e tags por resposta, soma ou média, nota de corte, faixas, simulador; qualifica ao responder e no recalcular). | `RODAR_v0.129_qualificacao.sql`, aplicado |
| 0.128 | 21/10/2026 | **Painel da campanha, dia a dia**: quadrinhos verde/vermelho de cada dia contra a meta (investimento, CTR, CPC, leads, CPL, vendas, receita); onde caiu (7 dias × 7 anteriores, etapa por etapa); movimento por dia; vendas por dia, produto e oferta; quanto foi e o que trouxe cada vídeo/criativo. | não muda o banco |
| 0.127 | 21/10/2026 | **Onda 3**: receita por papel da oferta (order bump, upsell, downsell) em Vendas e a oferta na importação; meta × realizado acumulado do plano e a projeção dos cenários aprovados; saldo mínimo de caixa no Financeiro e aviso no Dashboard. | `RODAR_v0.127_saldo_minimo.sql`, aplicado |
| 0.126 | 21/10/2026 | **Fecha a Onda 2 e completa a Onda 1**: abandono e recuperação no tempo; LTV por coorte; o que mais mexe no lucro (Growth Model); o que testar primeiro (ICE 2x2); antes × depois dos experimentos; desvio da meta e funil com perdas no fechamento; vendas acumuladas × meta; CPM, CTR, CPC, frequência e CAC por canal na Mídia paga; investimento, CPL e CAC no tempo; receita de novos × existentes. | não muda o banco |
| 0.125 | 21/10/2026 | **Onda 2, parte 1**: observações no Dashboard (fato, conta, hipótese, investigar); resultado × dinheiro no banco; vencimentos por semana e faixas de atraso em Contas a receber e a pagar; MRR mês a mês com novos, expansão, redução e cancelados; vendas, ticket e margem por produto; CAC × clientes por campanha; leads por origem até a compra. | não muda o banco |
| 0.124 | 21/10/2026 | **Gráficos com função (onda 1)**: componente único de gráficos; **Dashboard** vira o dashboard geral do negócio (receita, lucro e margem por mês; ritmo da meta do mês; receita por produto e campanha contra o período anterior; DRE e fluxo recolhidos) e **substitui o Dashboard Growth**; **uma tela só de mídia** (Mídia paga, com o Relatório de mídia) e **campanha → Ver na Mídia paga** já filtrada; Financeiro com **cascata do resultado** e linha mensal sem meses futuros; Custos e margens com **receita × equilíbrio × cenários** e **custo por área × mês anterior**. | não muda o banco |
| 0.123 | 21/10/2026 | **Gráfico de linha** no painel de cada número, dentro do período da tela, com Dia/Semana/Mês/Ano (substitui o da 0.122). **Nova campanha**: cadastrar produto, estratégia (com as etapas) e canal sem sair dela; Nova estratégia com escolha das etapas por fase. | `RODAR_v0.123_arvore_serie.sql`, aplicado |
| 0.122 | 21/10/2026 | **Mini gráfico em cada número da árvore**: evolução por mês, cascata, composição (rosca), barras por dia ou medidor, escolhido pelo tipo do número; série dos últimos meses para CAC, CPL, ROAS, margem e outros; clicar no gráfico desce o nível. | não muda o banco |
| 0.121 | 21/10/2026 | **Visual**: claro como padrão (escuro como opção), verde no que é bom e vermelho no negativo com brilho neon, cartões em 3D, uma ação principal por tela. **Dashboard em camadas** (4 cartões grandes com tendência + cartões menores com números compactos). **Nova campanha em 3 etapas** (o básico; orçamento e metas; canais), faixa de rascunho com o que falta, "começa em" para campanha que não começou, Editar campanha em blocos com Ctrl+S, Growth Model com "Mais ações". Correção: "Por vendedor" na árvore. | `RODAR_v0.121_arvore_vendedor.sql`, aplicado |
| 0.120 | 20/10/2026 | **Comissões**: vendedor, coprodutor, estrategista e parceiro; regras por projeto, campanha, produto ou oferta; base líquida ou bruta; pagamento mensal, por venda ou só relatório; fechamento do mês em contas a pagar; estornos. A configuração fica em Configurações → Comissões e o acompanhamento em Vendas → Comissões. **Conexões** com Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube) por login oficial. | `RODAR_v0.120_comissoes_conexoes.sql`, aplicado |
| 0.119 | 20/10/2026 | Árvore, parte 4: cards de Custos e margens (montados no navegador), tabelas de Mídia paga, origem do recebimento; MRR de Contas a receber no horário de São Paulo. Scripts RODAR que podem ser colados de novo sem erro. | aplicado |
| 0.118 | 20/10/2026 | Árvore, parte 3: números das tabelas (Campanhas ativas e coortes); venda e conta a pagar como passos da árvore; caixa projetado em 30 dias, novos em 30 dias e a qualificar. | aplicado |
| 0.117 | 20/10/2026 | Árvore, parte 2: lançamento contábil, LTV, churn, NRR, GRR, penetração, contas a receber e a pagar, contratos. | aplicado |
| 0.116 | 20/10/2026 | Árvore dos números: clicar num número abre a conta que o gerou, nível por nível. | aplicado |
| 0.115 | 19/10/2026 | Detalhe dos cards da campanha (por canal, por dia, qualificação, anúncios). | aplicado |
| 0.114 | 19/10/2026 | Meta de leads por dia, por mês e por canal; gráficos menores; taxas do funil. | aplicado |
| 0.113 | 17/10/2026 | Receber leads de formulários (função `leads`). | aplicado |
| 0.112 e anteriores | até 17/10/2026 | Ver [CHANGELOG.md](CHANGELOG.md). | aplicado |

**Para registrar uma versão nova**:

1. Acrescente a linha no alto da tabela.
2. Atualize o "Estado atual".
3. Escreva o detalhe no `CHANGELOG.md` e nos docs.
4. Faça o commit com a mensagem `vX.YYY — título`.

## Estrutura

```
index.html                o Growths (tela, um arquivo só) — é o que vai para o ar
_headers                  cabeçalhos do Cloudflare Pages
CHANGELOG.md              histórico detalhado de cada versão
docs/
  visao-geral.md          o que o sistema faz, versão a versão
  growths-o-sistema.md    todas as funcionalidades explicadas (documento vivo, base de conteúdo)
  regras-de-negocio.md    como cada número é calculado
  modelo-de-dados.md      tabelas, funções e views
  decisoes-e-pendencias.md decisões tomadas e o que falta
  como-rodar-o-banco.md   o que rodar no Supabase, em ordem
  registro-de-implementacao.md como foi feito e testado
  guia-de-versionamento.md como numerar e registrar versões
  conectar-meta-e-google.md passo a passo dos apps do Meta e do Google
  publicar-cloudflare.md  publicar a tela
  estrutura/              dicionário de campos e estrutura
supabase/
  migrations/             cada mudança de banco, em ordem de data
  RODAR_v*.sql            o mesmo conteúdo, pronto para colar no SQL Editor
  functions/              edge functions (leads, ideias, perguntar, conexoes)
  seed/                   dados fictícios (Escola Aurora e demonstração)
tests/
  auditoria/              testes de tela (Playwright) e de banco, por versão (tNNN_*.py)
  edge/                   testes das edge functions (Deno)
lovable/                  material de apoio
```

## Segurança

- O `index.html` leva só o endereço do Supabase e a chave pública (anon). Quem protege os dados é o RLS e as permissões por módulo, no banco.
- Segredos (tokens do Meta e do Google, chaves de IA e o segredo do agendamento) **nunca** entram no repositório. Eles ficam em Edge Functions → Secrets, no Supabase, e os tokens das conexões ficam no schema `privado`.
- O repositório é público: se for guardar dados reais de cliente aqui, torne-o privado antes.


**Em desenvolvimento — v0.179:** `feat/instagram-oauth-direto` abre o Instagram OAuth direto no cliente e salva o vínculo com perfil Zernio por workspace. SQL, Edge `instagram-oauth` e frontend ainda não publicados nesta entrega.
