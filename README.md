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
| **Versão da tela** | 0.122 · 21/10/2026 (`index.html`) |
| **Banco em produção** (Supabase `yngyghlyonybvfvjcmxl`) | até a **v0.119** |
| **Falta aplicar em produção** | `supabase/RODAR_v0.120_comissoes_conexoes.sql`, publicar a função `conexoes` (sem verificação de JWT) e depois `supabase/RODAR_v0.121_arvore_vendedor.sql` |
| **Falta configurar** | app do Meta, projeto do Google e os segredos no Supabase: [docs/conectar-meta-e-google.md](docs/conectar-meta-e-google.md) |

## Registro de versões

Cada linha é uma entrega. **Banco** diz se a versão mudou o banco e se já está em produção.

| Versão | Data | O que mudou | Banco |
|---|---|---|---|
| 0.122 | 21/10/2026 | **Mini gráfico em cada número da árvore**: evolução por mês, cascata, composição (rosca), barras por dia ou medidor, escolhido pelo tipo do número; série dos últimos meses para CAC, CPL, ROAS, margem e outros; clicar no gráfico desce o nível. | não muda o banco |
| 0.121 | 21/10/2026 | **Visual**: claro como padrão (escuro como opção), verde no que é bom e vermelho no negativo com brilho neon, cartões em 3D, uma ação principal por tela. **Dashboard em camadas** (4 cartões grandes com tendência + cartões menores com números compactos). **Nova campanha em 3 etapas** (o básico; orçamento e metas; canais), faixa de rascunho com o que falta, "começa em" para campanha que não começou, Editar campanha em blocos com Ctrl+S, Growth Model com "Mais ações". Correção: "Por vendedor" na árvore. | `RODAR_v0.121_arvore_vendedor.sql`, **ainda não aplicado** |
| 0.120 | 20/10/2026 | **Comissões**: vendedor, coprodutor, estrategista e parceiro; regras por projeto, campanha, produto ou oferta; base líquida ou bruta; pagamento mensal, por venda ou só relatório; fechamento do mês em contas a pagar; estornos. A configuração fica em Configurações → Comissões e o acompanhamento em Vendas → Comissões. **Conexões** com Meta (Facebook Ads + Instagram) e Google (Google Ads + YouTube) por login oficial. | `RODAR_v0.120_comissoes_conexoes.sql`, **ainda não aplicado** |
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
