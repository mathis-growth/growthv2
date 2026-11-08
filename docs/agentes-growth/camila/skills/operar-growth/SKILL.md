---
name: operar-growth
description: Use para preparar ou revisar campanhas, produtos, formulários, UTMs, segmentos e associações no Growth a partir de um plano aprovado.
version: 1.0.0
author: Mathisa
license: MIT
metadata:
  hermes:
    tags: [growth, campanhas, crm, operacao]
    related_skills: [consultar-banco, consultar-growth, seguranca-e-aprovacoes-growth, plano-de-campanha]
---

# Operar campanhas e cadastros no Growth

## Quando usar

- O Frank pede para transformar um plano aprovado em campanha configurada no Growth.
- É preciso revisar a associação entre campanha, produto, formulário, canal, UTM ou automação.
- Uma equipe precisa preparar um rascunho operacional para o dono revisar.

## O que exigir antes de começar

- Workspace/cliente autorizado.
- Objetivo e critério de pronto.
- Plano aprovado, com produto/oferta, público, período, canais e metas disponíveis.
- Ferramenta real de Growth conectada com as permissões adequadas.

Se faltar qualquer item, liste exatamente o que falta. Não complete com suposições.

## Procedimento

1. Consulte a oferta e as regras pelo banco de conhecimento. Confirme o plano de campanha de Ulisses.
2. Use `consultar-growth` para verificar o workspace e localizar campanhas, produtos e formulários existentes. Faça consultas somente de leitura nesta etapa.
3. Procure duplicidades por nome, produto, período, identificador externo e objetivo. Nome parecido não basta para concluir que é duplicado.
4. Monte um mapa de configuração antes de editar:
   - campanha e produto;
   - objetivo, datas, modelo e status;
   - canais e responsável;
   - UTMs e página de destino;
   - formulário e campos de captura;
   - evento de conversão e vínculo com lead/venda;
   - automação selecionada, se houver;
   - metas e origem de cada valor.
5. Mostre o mapa a Frank se houver decisão comercial, alteração em registro ativo ou risco de duplicar dados. Se a tarefa já autorizar claramente um rascunho, prepare-o inativo.
6. Use somente interface ou ações de ferramenta aprovadas. Não escreva no banco com SQL ou credencial administrativa.
7. Confira o registro depois de salvar: workspace, nomes, datas, status, IDs, produto, formulário, UTM e destino.
8. Não ative, publique, importe ou dispare. Entregue o passo de aprovação necessário.

## Campos e rastreamento

- Preserve UTMs existentes e não substitua parâmetros sem comparar com o padrão da campanha.
- Mantenha `utm_growth` vinculado ao identificador da campanha quando esse padrão estiver habilitado.
- Registre URL de entrada completa quando a configuração de auditoria solicitar; preserve a URL original e diferencie-a da URL normalizada.
- Não afirme que uma venda foi atribuída à campanha apenas porque a UTM está presente; confira a regra e a fonte de atribuição.
- Não crie eventos ou campos sem confirmar que a interface/integração os suporta.

## Como conferir

- Workspace e registros existentes foram verificados.
- A campanha está relacionada ao produto e formulário corretos.
- Datas, fuso, status e metas batem com o plano.
- UTMs e links foram conferidos sem apagar parâmetros existentes.
- Automação está ligada ao evento correto e continua inativa até autorização.
- Nenhum envio, publicação, importação ou gasto ocorreu.

## Entrega

Use os rótulos `PRONTO PARA REVISÃO`, `FALTA NO PLANO` ou `BLOQUEADO: falta ferramenta/permissão`. Informe o registro, workspace, evidências, alterações feitas e o que Frank/dono precisa aprovar.
