-- Pipeline fixa dos agentes em cada workspace, usando o quadro de Projetos.
alter table public.projetos add column if not exists pipeline_agentes boolean not null default false;
create unique index if not exists projetos_pipeline_agentes_uq
  on public.projetos (workspace_id) where pipeline_agentes;

alter table public.projeto_atividades add column if not exists agente_id text;
alter table public.projeto_atividades add column if not exists hermes_tarefa_id text;
alter table public.projeto_atividades add column if not exists hermes_resumo text;
create unique index if not exists projeto_atividades_hermes_uq
  on public.projeto_atividades (workspace_id, hermes_tarefa_id)
  where hermes_tarefa_id is not null;

alter table public.frank_growth_integracoes drop constraint if exists frank_growth_integracoes_escopos_ck;
alter table public.frank_growth_integracoes add constraint frank_growth_integracoes_escopos_ck
  check (cardinality(escopos) > 0 and escopos <@ array['growth:consultar', 'campanha:criar', 'tarefas:gerenciar']::text[]);
