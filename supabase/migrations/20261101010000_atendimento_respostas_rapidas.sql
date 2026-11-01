-- Respostas rápidas da Central de Atendimento, isoladas por workspace.
create table public.atd_respostas_rapidas (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 atalho text not null check (length(atalho) between 1 and 60),
 titulo text not null check (length(titulo) between 1 and 120),
 texto text not null check (length(texto) between 1 and 4000),
 criado_em timestamptz not null default now(),
 atualizado_em timestamptz not null default now(),
 unique(workspace_id,atalho), unique(workspace_id,id)
);
create index atd_respostas_rapidas_workspace on public.atd_respostas_rapidas(workspace_id,titulo);
alter table public.atd_respostas_rapidas enable row level security;
create policy atd_respostas_leitura on public.atd_respostas_rapidas for select to authenticated
 using (public.pertence_ao_workspace(workspace_id) and public.perm(workspace_id,'ler',array['vendas']));
revoke all on public.atd_respostas_rapidas from anon,authenticated;
grant select on public.atd_respostas_rapidas to authenticated;
grant all on public.atd_respostas_rapidas to service_role;
insert into public.acesso_telas(tela,modulo,nome,grupo,ordem)
 values ('atd-templates','vendas','Templates','Atendimento',122)
 on conflict(tela) do nothing;
