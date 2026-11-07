-- v0.275: colunas livres por etapa no Kanban de conteúdo.
-- As etapas (ideia, pauta, producao, pronto, agendado, publicado) continuam fixas, com as regras delas. Dentro de cada etapa,
-- a empresa cria as colunas que quiser (ex.: "Ideias aprovadas" dentro de Ideias). O conteúdo guarda a coluna em coluna_id.
-- Se o conteúdo muda de etapa e a coluna é de outra etapa, a coluna é apagada do conteúdo (gatilho).
-- Aditiva. Para desfazer: drop do gatilho, da coluna conteudos.coluna_id e da tabela conteudo_colunas.
create table if not exists public.conteudo_colunas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  etapa text not null check (etapa in ('ideia', 'pauta', 'producao', 'pronto', 'agendado', 'publicado')),
  nome text not null check (length(btrim(nome)) between 1 and 60),
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  unique (workspace_id, etapa, nome)
);
create index if not exists conteudo_colunas_ws on public.conteudo_colunas (workspace_id, etapa, ordem);
alter table public.conteudo_colunas enable row level security;
drop policy if exists conteudo_colunas_acesso on public.conteudo_colunas;
create policy conteudo_colunas_acesso on public.conteudo_colunas for all to authenticated using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
drop policy if exists perm_ler on public.conteudo_colunas;
create policy perm_ler on public.conteudo_colunas as restrictive for select using (perm(workspace_id, 'ler', array['mkt', 'adm']));
drop policy if exists perm_inserir on public.conteudo_colunas;
create policy perm_inserir on public.conteudo_colunas as restrictive for insert with check (perm(workspace_id, 'editar', array['mkt']));
drop policy if exists perm_alterar on public.conteudo_colunas;
create policy perm_alterar on public.conteudo_colunas as restrictive for update using (perm(workspace_id, 'editar', array['mkt'])) with check (perm(workspace_id, 'editar', array['mkt']));
drop policy if exists perm_excluir on public.conteudo_colunas;
create policy perm_excluir on public.conteudo_colunas as restrictive for delete using (perm(workspace_id, 'editar', array['mkt']));

alter table public.conteudos add column if not exists coluna_id uuid references public.conteudo_colunas(id) on delete set null;

-- a coluna precisa ser do mesmo workspace e da mesma etapa do conteúdo; se não for, sai
create or replace function public.conteudo_coluna_valida() returns trigger language plpgsql set search_path = public as $$
begin
  if new.coluna_id is not null and not exists (
       select 1 from conteudo_colunas k where k.id = new.coluna_id and k.workspace_id = new.workspace_id and k.etapa = new.status) then
    new.coluna_id := null;
  end if;
  return new;
end $$;
drop trigger if exists conteudo_coluna_valida_t on public.conteudos;
create trigger conteudo_coluna_valida_t before insert or update of status, coluna_id on public.conteudos
  for each row execute function public.conteudo_coluna_valida();
