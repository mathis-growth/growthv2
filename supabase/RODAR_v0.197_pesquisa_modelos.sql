-- v0.197 — Pesquisas: modelos prontos que o cliente tirou da lista "Começar de um modelo".
-- Os modelos ficam no código; aqui só a lista dos que cada cliente escondeu (dá para mostrar de novo). Pode rodar de novo sem erro.
create table if not exists public.pesquisa_modelos_ocultos (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  modelo text not null check (char_length(modelo) between 1 and 60),
  ocultado_em timestamptz not null default now(),
  primary key (workspace_id, modelo)
);
alter table public.pesquisa_modelos_ocultos enable row level security;
drop policy if exists pesquisa_modelos_ocultos_ver on public.pesquisa_modelos_ocultos;
create policy pesquisa_modelos_ocultos_ver on public.pesquisa_modelos_ocultos for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
drop policy if exists pesquisa_modelos_ocultos_gravar on public.pesquisa_modelos_ocultos;
create policy pesquisa_modelos_ocultos_gravar on public.pesquisa_modelos_ocultos for insert to authenticated with check (pode_editar(workspace_id, '{gro,mkt}'::text[]));
drop policy if exists pesquisa_modelos_ocultos_excluir on public.pesquisa_modelos_ocultos;
create policy pesquisa_modelos_ocultos_excluir on public.pesquisa_modelos_ocultos for delete to authenticated using (pode_editar(workspace_id, '{gro,mkt}'::text[]));
revoke all on public.pesquisa_modelos_ocultos from anon;
grant select, insert, delete on public.pesquisa_modelos_ocultos to authenticated;
notify pgrst, 'reload schema';
