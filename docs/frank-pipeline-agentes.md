# Pipeline dos agentes

O Growth mantém um projeto reservado **Pipeline dos agentes** em cada workspace. A aba fica em **Projetos → Pipeline dos agentes** e usa o quadro de atividades já existente. O projeto é criado no primeiro acesso pela interface ou pela Edge `frank-growth`.

## Permissão

Em **Integrações → Agentes externos · Frank**, habilite **Gerenciar tarefas na pipeline dos agentes** para a identidade de integração e selecione os workspaces permitidos. Cada agente pode ter a própria identidade e token. O token vai no cabeçalho `x-frank-growth-key`; nunca deve entrar no navegador ou no texto das tarefas.

## Chamadas da VPS

Todas as chamadas são `POST` para `/functions/v1/frank-growth`, com `Content-Type: application/json`. O ID do workspace é obrigatório; o mesmo nome de cliente pode existir mais de uma vez.

Na VPS, use `FRANK_GROWTH_URL` e `FRANK_GROWTH_TOKEN` já configurados para a integração, por exemplo:

```bash
curl -sS "$FRANK_GROWTH_URL" \
  -H 'Content-Type: application/json' \
  -H "x-frank-growth-key: $FRANK_GROWTH_TOKEN" \
  --data-binary @tarefa.json
```

Criar uma tarefa depois de criá-la no Kanban do Hermes:

```json
{
  "acao": "tarefa_criar",
  "workspace_id": "UUID_DO_CLIENTE",
  "hermes_tarefa_id": "t_ID_DO_HERMES",
  "agente_id": "camila",
  "titulo": "Preparar roteiro de lançamento",
  "descricao": "Objetivo, contexto e critérios de entrega",
  "prazo": "2026-11-20"
}
```

Repetir `tarefa_criar` com o mesmo `hermes_tarefa_id` devolve a tarefa existente (`replay: true`), sem duplicar o cartão.

Atualizar o andamento:

```json
{
  "acao": "tarefa_atualizar",
  "workspace_id": "UUID_DO_CLIENTE",
  "hermes_tarefa_id": "t_ID_DO_HERMES",
  "status": "concluida",
  "resumo": "Roteiro entregue para revisão."
}
```

Os status aceitos são `liberada`, `em_andamento`, `concluida` e `cancelada`. Uma atividade nasce bloqueada pelo gatilho de Projetos e é liberada quando não há dependências pendentes. Use `tarefas_listar` com `workspace_id` para consultar até 500 tarefas recentes.

Essa integração grava o acompanhamento no Growth quando o Frank ou outro agente chama a Edge. Alterações feitas diretamente no Kanban do Hermes não são sincronizadas automaticamente; a ponte da VPS deve chamar `tarefa_criar` e `tarefa_atualizar` nos eventos correspondentes.
