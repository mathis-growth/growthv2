---
name: analisar-dados-do-growth
description: Use para analisar campanhas, leads, vendas, formulários, atendimento e atribuição no Growth e cruzar os resultados com plataformas de anúncios conectadas.
version: 1.0.0
author: Mathisa
license: MIT
metadata:
  hermes:
    tags: [analytics, growth, atribuicao, funil, dados]
    related_skills: [consultar-growth, resumo-da-manha, ler-conta-de-anuncios]
---

# Analisar dados internos do Growth

## Quando usar

- O Frank pede análise de campanha, funil, origem de leads, vendas ou conversão.
- É preciso investigar queda ou aumento de resultado e encontrar os registros agregados que explicam o indicador.
- O resumo da manhã ou relatório semanal precisa combinar Growth com Meta Ads/Google Ads.

## Procedimento

1. Confirme workspace, período, fuso, campanhas e pergunta que a análise precisa responder.
2. Leia dados internos com `consultar-growth`, que é somente leitura e exige escopo do workspace.
3. Leia Meta Ads/Google Ads com `ler-conta-de-anuncios` quando houver conexão. Registre data/hora da leitura e nível (conta, campanha, conjunto ou anúncio).
4. Separe fontes: Growth/CRM, plataforma de anúncios e plataforma de pagamento. Não some métricas com definições ou períodos diferentes.
5. Confirme definições antes de calcular: lead, contato único, venda aprovada, reembolso, cliente novo/recorrente, receita bruta/líquida, clique e conversa.
6. Verifique cobertura e qualidade: UTMs ausentes, URL registrada, vendas sem pessoa, campanhas sem identificador, duplicidade, atraso de sincronização, reembolso e diferença de fuso.
7. Compare com período equivalente quando houver base suficiente. Informe denominador, fórmula, período e filtros; não compare períodos incompletos como se fossem fechados.
8. Investigue o detalhe necessário sem expor PII. Faça os cálculos com totais agregados e identifique registros de origem sem copiar conteúdo pessoal.
9. Separe: fato observado, cálculo, inferência e recomendação. Declare as lacunas de cada fonte.
10. Recomendações de orçamento, pausa ou ativação são propostas. Não altere contas nem campanhas.

## Fórmulas e atribuição

- Calcule taxas com denominador explícito: conversão = eventos finais / população elegível da etapa anterior.
- CAC e ROAS devem declarar receita/custo usados, canal, período e regra de atribuição.
- Preserve diferenças entre atribuição da plataforma (janela/modelo da plataforma) e associação do CRM por UTM ou identificador Growth.
- `utm_growth` identifica vínculo configurado com campanha; sozinho não comprova causalidade nem garante que a venda veio do anúncio.
- Não reconcilie divergências apagando ou reclassificando registros. Mostre o valor por fonte e indique a verificação necessária.

## Cuidados

- Nunca invente ou estime valor que a fonte não fornece.
- Nunca use dado de um workspace para explicar outro.
- Não revele nome, telefone, e-mail ou conteúdo de mensagem em relatório agregado.
- Não altere nem exclua dados.
- Não recomende ação externa como se estivesse aprovada.

## Entrega

1. Conclusão em uma frase.
2. Indicadores com fórmula, período, fonte e hora de leitura.
3. Comparação e qualidade/cobertura dos dados.
4. Fatos, hipóteses e recomendação em blocos separados.
5. Bloqueios e próxima evidência necessária.
