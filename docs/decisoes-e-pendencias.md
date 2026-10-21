

## v0.124 — Data Storytelling, onda 1
**Decisões da Rebecka (21/10)**
- Aprovou a onda 1 do diagnóstico.
- Mídia: não precisa de duas telas; da campanha deve dar para abrir a tela de mídia já com os dados dela. → Mídia paga ficou como a tela única, com o relatório do Dashboard de mídia.
- Dashboard Growth: é o dashboard geral do negócio; se o novo é construído do zero, pode sair. → Saiu do menu; o endereço antigo abre o Dashboard.
- Tabelas longas (DRE, fluxo): sem resposta; aplicado o padrão sugerido (recolhidas, abrem com um clique).
**Decisões técnicas**
- Os endereços antigos (`adm-dash`, `st-dash`, `mkt-midia`) continuam funcionando e levam às telas novas, para não quebrar links salvos.
- O ritmo da meta usa as metas mensais que já existem (Planejamento anual); não foi criado campo novo.
- Nada mudou no banco nesta versão.
**Próximo (v0.125, onda 1 parte 2)**: marketing por semana (investimento, CPL, CAC), mídia (CPM, CTR, CPC, frequência; CAC por canal em barras), campanha (meta × realizado acumulado e funil com perdas), vendas e ticket por semana, receita de clientes novos × existentes.

## v0.123 — Linha no período e cadastros na campanha
**Pedidos da Rebecka (21/10)**
- Gráficos de linha, dentro do período da tela anterior, por dia, semana, mês ou ano, com opção de trocar.
- Cadastrar estratégia e etapas (e o que mais faltar) na hora de criar a campanha.
**Decisões técnicas**
- A série é calculada no banco (uma chamada), reaproveitando a conta do próprio número: o gráfico sempre bate com o número.
- O cartão "Saldo em banco" do Dashboard abre o extrato (como antes), não a árvore.
- A estratégia criada pela nova campanha guarda etapas (não blocos), mesmo com modelo pronto quando você mexe nas etapas.
**Banco em produção**: v0.120 já estava aplicada; v0.121 e v0.123 aplicadas em 21/10. A função `conexoes` continua sem publicar até existirem os apps do Meta e do Google.
