---
name: desenhar-automacao-crm
description: Use para desenhar, revisar ou preparar automações de e-mail, WhatsApp e outros canais autorizados no Growth, incluindo gatilhos, filtros, condições, atrasos e saídas.
version: 1.0.0
author: Mathisa
license: MIT
metadata:
  hermes:
    tags: [crm, lifecycle, automacao, email, whatsapp]
    related_skills: [consultar-banco, consultar-growth, seguranca-e-aprovacoes-growth, escrever-anuncio]
---

# Desenhar uma automação de CRM

## Quando usar

- O Frank pede uma jornada para lead, aluno ou cliente.
- Uma campanha, pesquisa ou venda precisa iniciar uma sequência.
- É preciso revisar mensagens, atrasos, filtros, condições ou saídas de automação existentes.

## Entradas necessárias

- Workspace autorizado, produto/campanha e evento de origem.
- Público e objetivo da jornada.
- Canal e conta conectados, quando disponíveis.
- Oferta e regras confirmadas no banco da empresa.
- Campos/variáveis reais disponíveis no contato ou evento.

Se faltar consentimento, evento de origem, canal ou regra comercial, devolva o item como pendência. Não suponha.

## Procedimento

1. Consulte as regras do negócio e o plano aprovado. Use `consultar-growth` para ler o fluxo existente e os campos disponíveis.
2. Especifique quem pode entrar, quando entra e quando deve ser excluído. Defina deduplicação para que o mesmo evento não crie execuções repetidas.
3. Desenhe a jornada em blocos:
   - gatilho e origem;
   - condição de entrada;
   - mensagem por canal;
   - variável e fallback;
   - tempo de espera e fuso horário;
   - condição de avanço/saída;
   - encerramento e tratamento de falha.
4. Em cada mensagem, inclua objetivo, conteúdo aprovado, remetente/canal, CTA e variáveis utilizadas.
5. Defina supressões: descadastro, bloqueio, endereço inválido, compra já realizada, resposta humana, falta de consentimento e limite de frequência.
6. Para WhatsApp, use o tipo de mensagem e janela permitidos pelo provedor e pela configuração conectada. Não transforme template aprovado em texto livre nem prometa que a API enviará sem validar a conta.
7. Para e-mail, verifique domínio/remetente autenticado e links; não use pixel de rastreamento ou dados sensíveis sem autorização.
8. Simule os caminhos com casos representativos: elegível, inelegível, compra ocorrida, descadastro, falta de variável e provedor indisponível.
9. Prepare o fluxo como rascunho usando a ferramenta autorizada. Se não houver conector, entregue o mapa pronto para implementação e declare o bloqueio.
10. Apresente o conteúdo, público estimado se confirmado, horários, frequência, saídas e impacto antes de pedir liberação para ativar.

## Regras de comunicação

- Não invente preço, prazo, bônus, garantia, depoimento ou promessa.
- Não insista após pedido de parada. O pedido de descadastro prevalece sobre qualquer etapa da jornada.
- Não envie para contatos sem permissão registrada para aquele canal/finalidade.
- Evite dados pessoais ou sensíveis no assunto, URL, logs e texto da mensagem.
- Não dispare mensagens durante a preparação ou simulação.

## Conferência final

- O gatilho está ligado ao evento e workspace corretos.
- Condições e saídas cobrem opt-out, compra e erro.
- A frequência total considera outras jornadas ativas para o mesmo contato.
- Variáveis existem e têm fallback definido.
- Horários e esperas usam o fuso combinado.
- Domínio/canal estão conectados; o fluxo segue inativo até aprovação.
- A tarefa descreve o que foi configurado e o que ficou apenas como proposta.
