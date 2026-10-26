-- v0.151 — Growth's Content: pesquisa (leitura das pastas + call + produtos + canais + web) e dossiê.
-- 1) content_pesquisas: cada pesquisa pedida pelo botão "Fazer a pesquisa", com a situação, o relatório, as fontes da web,
--    os arquivos lidos (e os não lidos, com o motivo) e o uso de IA.
-- 2) content_dossies: o dossiê gerado a partir de uma pesquisa (seções), com versão e situação.
-- Quem grava: só a função content-pesquisa (servidor). A tela lê.
-- 3) Configuração: modelo da IA, buscas na web por pesquisa e preços (vazio = custo não calculado; nada inventado).
-- Pode ser rodado de novo sem erro.

create table if not exists public.content_pesquisas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  status text not null default 'fila' check (status in ('fila', 'lendo', 'pesquisando', 'pronto', 'erro')),
  etapa text,
  erro text,
  relatorio text,
  fontes jsonb not null default '[]'::jsonb,
  arquivos jsonb not null default '[]'::jsonb,
  modelo text,
  tokens_entrada int, tokens_saida int, buscas int,
  iniciado_por uuid,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  concluido_em timestamptz
);
create index if not exists content_pesquisas_ws on public.content_pesquisas (workspace_id, criado_em desc);
alter table public.content_pesquisas enable row level security;
drop policy if exists content_pesquisas_ver on public.content_pesquisas;
create policy content_pesquisas_ver on public.content_pesquisas for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
revoke all on public.content_pesquisas from anon;
revoke insert, update, delete on public.content_pesquisas from authenticated;
grant select on public.content_pesquisas to authenticated;

create table if not exists public.content_dossies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pesquisa_id uuid references public.content_pesquisas(id) on delete set null,
  versao int not null default 1,
  status text not null default 'gerando' check (status in ('gerando', 'rascunho', 'aprovado', 'erro')),
  secoes jsonb not null default '[]'::jsonb,
  erro text,
  modelo text,
  tokens_entrada int, tokens_saida int,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists content_dossies_ws on public.content_dossies (workspace_id, criado_em desc);
alter table public.content_dossies enable row level security;
drop policy if exists content_dossies_ver on public.content_dossies;
create policy content_dossies_ver on public.content_dossies for select to authenticated using (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
revoke all on public.content_dossies from anon;
revoke insert, update, delete on public.content_dossies from authenticated;
grant select on public.content_dossies to authenticated;

insert into public.sistema_config (chave, valor) values ('ia_modelo_pesquisa', 'claude-sonnet-5-5') on conflict (chave) do nothing;
insert into public.sistema_config (chave, valor) values ('content_pesquisa_buscas', '8') on conflict (chave) do nothing;
-- preços por modelo, em US$ por milhão de tokens e por mil buscas, ex.: {"claude-sonnet-5-5": {"entrada": 0, "saida": 0}, "busca_mil": 0}
insert into public.sistema_config (chave, valor) values ('ia_precos', '{}') on conflict (chave) do nothing;
insert into public.sistema_config (chave, valor) values ('content_dossie_secoes',
  '["Diferencial", "Mecanismo do problema", "Mecanismo da solução", "Construção do produto", "Narrativa", "Voz", "Persona", "Concorrência", "Oportunidades de conteúdo"]')
  on conflict (chave) do nothing;

notify pgrst, 'reload schema';
