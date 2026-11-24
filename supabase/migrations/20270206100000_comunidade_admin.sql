-- Comunidade: primeira etapa administrativa (comunidades, grupos e espaços).
-- O acesso ao portal de membros será conectado em uma etapa posterior.

create table if not exists public.comunidades (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (char_length(trim(nome)) between 2 and 120),
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  descricao text not null default '',
  tipo text not null default 'privada' check (tipo in ('publica', 'gratuita', 'privada', 'premium', 'alunos', 'assinantes', 'convite')),
  status text not null default 'rascunho' check (status in ('rascunho', 'ativa', 'arquivada')),
  logo_url text,
  capa_url text,
  cor_primaria text not null default '#2457d6' check (cor_primaria ~ '^#[0-9A-Fa-f]{6}$'),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint comunidades_workspace_slug_uq unique (workspace_id, slug),
  constraint comunidades_id_workspace_uq unique (id, workspace_id)
);

create table if not exists public.comunidade_grupos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  comunidade_id uuid not null,
  nome text not null check (char_length(trim(nome)) between 2 and 100),
  descricao text not null default '',
  ordem integer not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint comunidade_grupos_comunidade_fk foreign key (comunidade_id, workspace_id)
    references public.comunidades(id, workspace_id) on delete cascade,
  constraint comunidade_grupos_id_contexto_uq unique (id, comunidade_id, workspace_id),
  constraint comunidade_grupos_nome_uq unique (comunidade_id, nome)
);

create table if not exists public.comunidade_espacos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  comunidade_id uuid not null,
  grupo_id uuid,
  nome text not null check (char_length(trim(nome)) between 2 and 100),
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  descricao text not null default '',
  tipo text not null default 'feed' check (tipo in ('feed', 'perguntas', 'cursos', 'eventos', 'biblioteca')),
  acesso text not null default 'membros' check (acesso in ('todos', 'membros', 'alunos', 'assinantes', 'privado')),
  ordem integer not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint comunidade_espacos_comunidade_fk foreign key (comunidade_id, workspace_id)
    references public.comunidades(id, workspace_id) on delete cascade,
  constraint comunidade_espacos_grupo_fk foreign key (grupo_id, comunidade_id, workspace_id)
    references public.comunidade_grupos(id, comunidade_id, workspace_id) on delete cascade,
  constraint comunidade_espacos_slug_uq unique (comunidade_id, slug)
);

create index if not exists comunidades_workspace_status_ix on public.comunidades (workspace_id, status, nome);
create index if not exists comunidade_grupos_contexto_ix on public.comunidade_grupos (workspace_id, comunidade_id, ativo, ordem);
create index if not exists comunidade_espacos_contexto_ix on public.comunidade_espacos (workspace_id, comunidade_id, ativo, ordem);

alter table public.comunidades enable row level security;
alter table public.comunidade_grupos enable row level security;
alter table public.comunidade_espacos enable row level security;

do $$
declare tabela text;
begin
  foreach tabela in array array['comunidades', 'comunidade_grupos', 'comunidade_espacos'] loop
    execute format('drop policy if exists %I on public.%I', tabela || '_ver', tabela);
    execute format('create policy %I on public.%I for select to authenticated using (pertence_ao_workspace(workspace_id))', tabela || '_ver', tabela);
    execute format('drop policy if exists %I on public.%I', tabela || '_gravar', tabela);
    execute format('create policy %I on public.%I for insert to authenticated with check (pode_editar(workspace_id, ''{revops}''::text[]))', tabela || '_gravar', tabela);
    execute format('drop policy if exists %I on public.%I', tabela || '_alterar', tabela);
    execute format('create policy %I on public.%I for update to authenticated using (pode_editar(workspace_id, ''{revops}''::text[])) with check (pode_editar(workspace_id, ''{revops}''::text[]))', tabela || '_alterar', tabela);
    execute format('drop policy if exists %I on public.%I', tabela || '_excluir', tabela);
    execute format('create policy %I on public.%I for delete to authenticated using (pode_editar(workspace_id, ''{revops}''::text[]))', tabela || '_excluir', tabela);
    execute format('revoke all on public.%I from anon', tabela);
  end loop;
end $$;

grant select, insert, update, delete on public.comunidades to authenticated;
grant select, insert, update, delete on public.comunidade_grupos to authenticated;
grant select, insert, update, delete on public.comunidade_espacos to authenticated;
