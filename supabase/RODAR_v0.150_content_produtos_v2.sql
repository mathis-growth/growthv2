-- v0.150 — Growth's Content: ficha de produto simples (produto, valor e histórico), própria do módulo de conteúdo.
-- Substitui a ficha longa da v0.149 (content_produto_fichas, sem nenhum dado em produção em 25/10/2026).
-- Os produtos do conteúdo não dependem do cadastro comercial: cliente só do Growth's Content também cadastra.
-- Pode ser rodado de novo sem erro.

create table if not exists public.content_produtos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 120),
  valor numeric(12, 2) check (valor is null or valor >= 0),
  historico text check (historico is null or length(historico) <= 8000),
  ativo boolean not null default true,
  ordem int not null default 0,
  produto_id uuid references public.produtos(id) on delete set null,   -- de qual produto do cadastro veio (opcional)
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists content_produtos_ws on public.content_produtos (workspace_id);
alter table public.content_produtos enable row level security;
drop policy if exists content_produtos_ver on public.content_produtos;
create policy content_produtos_ver on public.content_produtos for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
drop policy if exists content_produtos_gravar on public.content_produtos;
create policy content_produtos_gravar on public.content_produtos for insert to authenticated with check (content_pode_configurar(workspace_id));
drop policy if exists content_produtos_alterar on public.content_produtos;
create policy content_produtos_alterar on public.content_produtos for update to authenticated using (content_pode_configurar(workspace_id)) with check (content_pode_configurar(workspace_id));
drop policy if exists content_produtos_excluir on public.content_produtos;
create policy content_produtos_excluir on public.content_produtos for delete to authenticated using (content_pode_configurar(workspace_id));
revoke all on public.content_produtos from anon;
grant select, insert, update, delete on public.content_produtos to authenticated;

-- a ideia passa a apontar para o produto do conteúdo
alter table public.conteudos drop constraint if exists conteudos_produto_id_fkey;
update public.conteudos c set produto_id = null where produto_id is not null and not exists (select 1 from public.content_produtos p where p.id = c.produto_id);
alter table public.conteudos add constraint conteudos_produto_id_fkey foreign key (produto_id) references public.content_produtos(id) on delete set null;

-- a ficha longa da v0.149 sai
drop function if exists public.content_produto_ficha_salvar(uuid, jsonb);
drop table if exists public.content_produto_fichas;

notify pgrst, 'reload schema';
