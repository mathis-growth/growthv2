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
| **Versão da tela** | 0.132 · 24/10/2026 (`index.html`) |
| **Banco em produção** (Supabase `yngyghlyonybvfvjcmxl`) | até a **v0.130** (aplicado em 21/10/2026); **falta** a v0.132 (`RODAR_v0.132_alertas.sql`, funções `avisos` e `perguntar`, `RODAR_v0.132_agendador.sql`) |
| **Falta publicar** | a função `conexoes` (sem verificação de JWT), quando os apps do Meta e do Google existirem |
| **Falta configurar** | app do Meta, projeto do Google e os segredos no Supabase: [docs/conectar-meta-e-google.md](docs/conectar-meta-e-google.md) |

## Registro de versões

Cada linha é uma entrega. **Banco** diz se a versão mudou o banco e se já está em produção.

| Versão | Data | O que mudou | Banco |
|---|---|---|---|
| 0.132 | 24/10/2026 | **Pergunte ao Growths**: "como foi meu dia ontem?" com os números exatos do dia e a comparação; IA com o dia a dia. **Alertas e resumo do dia**: conferência de hora em hora (mudança brusca, se repetindo, pede ação, dia sem dados), resumo de ontem toda manhã, avisos no sino, e-mail (Resend) e WhatsApp (Meta). | `RODAR_v0.132_alertas.sql` + `RODAR_v0.132_agendador.sql` + edge functions, **pendente** |
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
