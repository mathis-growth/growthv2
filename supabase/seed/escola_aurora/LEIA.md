# Escola Aurora (empresa fictícia para testar as telas)

Arquivos para rodar, em ordem: `supabase/RODAR_escola_aurora_1_dados.sql` e depois `_2_imagens`, `_3_imagens` e `_4_imagens` (SQL Editor → uma query nova para cada arquivo → Run). As imagens ficam em arquivos separados porque um arquivo único de 466 KB é pesado demais para o editor. Cria o workspace **Escola Aurora**, com acesso para rebecka@rebeckacappello.com.br. Se ele já existir, o arquivo para sem mudar nada.

## O que tem
- **Histórico (jul a 16/10/2026)**, pelos fluxos reais do banco:
  - perpétuo do Curso Inglês Base (Meta Ads, 3 anúncios);
  - lançamento de setembro (Google);
  - 14 contratos da Mentoria de Conversação;
  - despesas pagas, recebimentos e 4 reembolsos;
  - saldo inicial do banco de R$ 140 mil.
- **Lançamento "Formação Fluência · Nov/26" (Semana da Fluência)**:
  - captação de 01 a 26/10, aulas em 27, 29 e 31/10, carrinho de 03 a 09/11;
  - oferta principal R$ 1.997, order bump R$ 67 e upsell da Mentoria;
  - R$ 20 mil de tráfego na aquisição, em 7 campanhas de anúncio (Meta R$ 15 mil, Google R$ 3 mil, TikTok R$ 2 mil), mais Instagram orgânico e e-mail;
  - 31 anúncios com imagem e métricas diárias de 01 a 16/10, como se viessem da integração;
  - os leads entram pelo cadastro: 5% já estavam na base, 4% tentaram se cadastrar de novo, 66% entraram no grupo VIP, 70% responderam a pesquisa;
  - estratégia em blocos (modelo Lançamento clássico) com as taxas esperadas;
  - 27 metas: por canal, por público (frio e quente), por semana e de conversão;
  - faturas de mídia de 01 a 16/10 a pagar em 10/11.

## Números de 01 a 16/10
| Campanha | Orçamento | Gasto | Leads (meta) | CPL (meta) |
|---|---|---|---|---|
| Frio · Interesses | 5.500 | 3.007 | 606 (1.200) | 4,96 (4,58) |
| Frio · Lookalike | 4.500 | 2.420 | 502 (1.000) | 4,82 (4,50) |
| Frio · Advantage+ | 3.000 | 2.147 | 499 (600) | 4,30 (5,00) |
| Quente · Remarketing | 2.000 | 819 | 181 (500) | 4,52 (4,00) |
| YouTube | 2.000 | 1.128 | 171 (260) | 6,60 (7,69) |
| Pesquisa | 1.000 | 464 | 54 (170) | 8,59 (5,88) |
| TikTok | 2.000 | 1.017 | 167 (400) | 6,09 (5,00) |

Total pago: R$ 11.002 (55% da verba, com 62% do tempo), 2.180 leads e CPL de R$ 5,05. Os orgânicos trouxeram 847 leads.

O que dá para analisar nesses dados:
- AD19 ("I am agree") é o vencedor e o Advantage+ foi escalado;
- AD01 e AD10 estão com fadiga (o CTR caiu cerca de 30%);
- o remarketing está saturado (frequência acima de 3 e o CTR caiu 40%);
- a Pesquisa e o TikTok estão acima da meta de CPL;
- AD06, AD15 e AD28 foram pausados.

## Como foi montado (para refazer)
1. `python3 sim.py` → `plano.json`: a simulação diária, com semente fixa.
2. `python3 criativos.py` → `imagens.json` + `criativos/` (Playwright + Pillow; prévia 16:9 em WebP dentro do banco).
3. `python3 gen_sql.py` → `RODAR_escola_aurora.sql` (junta `base.sql` e `lancamento.sql`).

Testado num banco do zero com as migrações do repositório + `prod_funcs.sql`, que tem as versões de produção das funções que diferem do repositório (ver decisões e pendências, v0.112).
