-- v0.91 — Projeto automático da campanha passa a ser opcional
-- Antes: toda campanha nova criava sozinha o projeto "Campanha: <nome>" com o modelo padrão de campanha.
-- Agora: a campanha tem projeto_auto (marcado por padrão no formulário) e projeto_modelo_id (o modelo escolhido; vazio = o padrão).
-- Desmarcado, nenhum projeto é criado: depois dá para criar pelo botão Projeto da campanha, com o modelo que quiser.
-- Rode DEPOIS de 20261011200000_projetos_tags_modelos.sql. Idempotente.

alter table campanhas add column if not exists projeto_auto boolean not null default true;
alter table campanhas add column if not exists projeto_modelo_id uuid references projeto_modelos(id) on delete set null;

create or replace function public.campanha_cria_projeto()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare m uuid;
begin
  if not coalesce(new.projeto_auto, true) then return null; end if;
  m := coalesce((select id from projeto_modelos where id = new.projeto_modelo_id and workspace_id = new.workspace_id),
                (select id from projeto_modelos where workspace_id = new.workspace_id and padrao_campanha and ativo limit 1));
  insert into projetos (workspace_id, nome, descricao, campanha_id, modelo_id, data_inicio, data_fim_prevista)
  values (new.workspace_id, 'Campanha: ' || new.nome, 'Projeto criado automaticamente com a campanha.', new.id, m,
          coalesce(new.data_inicio, (now() at time zone 'America/Sao_Paulo')::date), new.data_fim);
  return null;
end $function$;
