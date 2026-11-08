---
name: implementar-melhoria-interface-growth
description: Use quando Frank/dono autorizar uma alteração de interface no repositório Growth e houver objetivo e critério de aceite definidos.
version: 1.0.0
author: Mathisa
license: MIT
metadata:
  hermes:
    tags: [produto, ux, frontend, implementacao]
    related_skills: [auditar-interface-growth, seguranca-e-aprovacoes-growth]
---

# Implementar melhoria de interface no Growth

## Pré-requisitos

- Pedido explícito de implementação, problema compreendido e critério de aceite.
- Repositório e ambiente corretos identificados.
- Autorização para editar o código; autorização para commit, push e deploy é separada.

## Procedimento

1. Leia as instruções locais, documentação e componentes relacionados.
2. Confira `git status`, branch, diferenças locais, stashes e commits. Não substitua trabalho paralelo.
3. Compare com a `main` remota antes de integrar ou publicar. Se houver divergência, revise cada alteração relevante antes de continuar.
4. Escolha uma branch/worktree isolada quando outras pessoas estiverem trabalhando no mesmo repositório.
5. Reproduza o estado atual e identifique dependências entre interface, Edge, banco e permissões.
6. Faça uma mudança pequena que resolva o critério de aceite. Preserve convenções visuais, acessibilidade e comportamento em telas pequenas.
7. Se a Edge de Atendimento for tocada, mantenha-a em um único arquivo e revise o bundle/entrypoint conforme as regras do projeto.
8. Se precisar de migration, crie arquivo idempotente, inclua RLS, grants, índices e compatibilidade com ambientes já parcialmente migrados. Não aplique em banco remoto sem autorização.
9. Não introduza testes e não rode testes se não foram pedidos. Faça apenas verificações estáticas apropriadas, como revisão do diff e whitespace.
10. Revise diff e status; confirme que só os arquivos do escopo foram alterados.
11. Pare antes de commit, push, merge, publicação ou deploy, a menos que essa ação esteja explicitamente autorizada.

## Conferência

- O fluxo corrigido satisfaz cada critério de aceite.
- Erro, vazio, carregamento e permissões têm estados compreensíveis.
- Não há alteração acidental de dado, configuração ou recurso externo.
- Mudanças paralelas e pendências de migration/Edge estão descritas.

## Entrega

Informe arquivos alterados, comportamento, verificações realizadas, impacto/risco e estado de Git. Separe claramente o que está pronto localmente do que precisa de migration, deploy, commit ou aprovação.
