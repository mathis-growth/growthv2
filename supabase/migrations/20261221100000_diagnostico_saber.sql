-- v0.229 — Diagnóstico de clientes: "O que já se sabe" (cada informação com a origem, conflitos entre fontes e a revisão da equipe).
-- As informações vêm do formulário (o que o cliente declarou), da reunião e das planilhas (o que a auditoria calculou); a tela monta a lista.
-- Aqui fica só a revisão da equipe: confirmar, corrigir (com o valor certo), rejeitar, ou levar o conflito para a reunião.
-- Aditivo e idempotente. Rode depois de 20261220100000_diagnostico_processo_cliente.sql.

create table if not exists diagnostico_saber_revisoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  diagnostico_id uuid not null references diagnosticos(id) on delete cascade,
  chave text not null check (length(chave) between 1 and 120),
  estado text not null check (estado in ('confirmado', 'corrigido', 'rejeitado', 'reuniao')),
  valor text check (length(valor) <= 500),
  nota text check (length(nota) <= 2000),
  autor uuid default auth.uid(),
  atualizado_em timestamptz not null default now(),
  unique (diagnostico_id, chave)
);
create or replace function public.diagnostico_saber_coerente() returns trigger language plpgsql security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from diagnosticos where id = new.diagnostico_id;
  if v_ws is null then raise exception 'Diagnóstico não encontrado.'; end if;
  new.workspace_id := v_ws; new.autor := coalesce(auth.uid(), new.autor); new.atualizado_em := now();
  if new.estado = 'corrigido' and coalesce(btrim(new.valor), '') = '' then raise exception 'Informe o valor certo.'; end if;
  return new;
end $$;
drop trigger if exists diagnostico_saber_coerente_t on diagnostico_saber_revisoes;
create trigger diagnostico_saber_coerente_t before insert or update on diagnostico_saber_revisoes for each row execute function diagnostico_saber_coerente();
alter table diagnostico_saber_revisoes enable row level security;
drop policy if exists diagnostico_saber_acesso on diagnostico_saber_revisoes;
drop policy if exists perm_ler on diagnostico_saber_revisoes;
drop policy if exists perm_inserir on diagnostico_saber_revisoes;
drop policy if exists perm_alterar on diagnostico_saber_revisoes;
drop policy if exists perm_excluir on diagnostico_saber_revisoes;
create policy diagnostico_saber_acesso on diagnostico_saber_revisoes for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
create policy perm_ler on diagnostico_saber_revisoes as restrictive for select to authenticated using (perm(workspace_id, 'ler', array['gro', 'adm', 'mkt']));
create policy perm_inserir on diagnostico_saber_revisoes as restrictive for insert to authenticated with check (perm(workspace_id, 'editar', array['gro']));
create policy perm_alterar on diagnostico_saber_revisoes as restrictive for update to authenticated using (perm(workspace_id, 'editar', array['gro']));
create policy perm_excluir on diagnostico_saber_revisoes as restrictive for delete to authenticated using (perm(workspace_id, 'editar', array['gro']));
revoke all on diagnostico_saber_revisoes from anon, authenticated;
grant select, insert, update, delete on diagnostico_saber_revisoes to authenticated;

-- correção (v0.223): apagar um diagnóstico com arquivos da equipe batia na regra "o arquivo precisa de link ou de diagnóstico".
-- O registro do arquivo da equipe continua (o original não se perde); só fica sem diagnóstico.
alter table pesquisa_arquivos drop constraint if exists pesquisa_arquivos_dono_ck;
alter table pesquisa_arquivos add constraint pesquisa_arquivos_dono_ck check (envio_id is not null or diagnostico_id is not null or origem = 'equipe');

-- Para desfazer: drop table diagnostico_saber_revisoes; drop function diagnostico_saber_coerente();
