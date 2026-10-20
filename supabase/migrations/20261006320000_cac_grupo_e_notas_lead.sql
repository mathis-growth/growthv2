alter table plano_contas add column if not exists cac_grupo text check (cac_grupo is null or cac_grupo in ('midia','equipe','ferramentas','comissao','outros'));
comment on column plano_contas.cac_grupo is 'Se preenchido, a conta entra no CAC total (midia entra também no CAC de mídia)';
update plano_contas set cac_grupo = 'midia' where cac_grupo is null and codigo like '6.1.%' and aceita_lancamento;
update plano_contas set cac_grupo = 'comissao' where cac_grupo is null and codigo = '6.2.03' and aceita_lancamento;

create table if not exists pessoa_notas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  pessoa_id uuid not null references pessoas(id) on delete cascade,
  texto text not null check (length(btrim(texto)) > 0),
  autor_id uuid default auth.uid(),
  autor_email text,
  criado_em timestamptz not null default now()
);
create index if not exists pessoa_notas_ix on pessoa_notas (pessoa_id, criado_em desc);
alter table pessoa_notas enable row level security;
create policy pessoa_notas_rls on pessoa_notas for all to authenticated
  using (pertence_ao_workspace(workspace_id)) with check (pertence_ao_workspace(workspace_id));
