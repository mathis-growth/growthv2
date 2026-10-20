-- Campanha como página central: status (rascunho, planejada, ativa, pausada, finalizada), modelo lançamento ou perpétuo, marcos do carrinho e debriefing.
alter table campanhas drop constraint if exists campanhas_status_check;
update campanhas set status = 'finalizada' where status = 'encerrada';
alter table campanhas add constraint campanhas_status_check check (status in ('rascunho', 'planejada', 'ativa', 'pausada', 'finalizada'));
alter table campanhas add column if not exists modelo text not null default 'lancamento' check (modelo in ('lancamento', 'perpetuo'));
alter table campanhas add column if not exists data_carrinho_abre date;
alter table campanhas add column if not exists data_carrinho_fecha date;
alter table campanhas add constraint campanhas_perpetuo_sem_fim check (modelo <> 'perpetuo' or data_fim is null);

create table if not exists campanha_debriefing (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  campanha_id uuid not null unique references campanhas(id) on delete cascade,
  resultado text, funcionou text, nao_funcionou text, aprendizados text, proximos_passos text,
  atualizado_em timestamptz not null default now()
);
alter table campanha_debriefing enable row level security;
create policy campanha_debriefing_rls on campanha_debriefing for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
