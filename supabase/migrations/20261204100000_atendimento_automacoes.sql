-- Automações de resposta inicial para os canais da Central de Atendimento.
-- O acesso às tabelas ocorre exclusivamente pela Edge autenticada/service_role.
create table if not exists public.atd_automacoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  canal_id uuid,
  nome text not null check (length(trim(nome)) between 1 and 120),
  gatilho_tipo text not null default 'palavra_chave'
    check (gatilho_tipo in ('qualquer_mensagem','palavra_chave')),
  gatilho_valor text not null default '',
  resposta text not null check (length(trim(resposta)) between 1 and 4000),
  ativo boolean not null default false,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(workspace_id,id),
  foreign key(workspace_id,canal_id) references public.atd_canais(workspace_id,id),
  check ((gatilho_tipo='qualquer_mensagem' and gatilho_valor='') or
         (gatilho_tipo='palavra_chave' and length(trim(gatilho_valor)) between 1 and 100))
);
create index if not exists atd_automacoes_ativas on public.atd_automacoes(workspace_id,canal_id)
  where ativo;

create table if not exists public.atd_automacao_execucoes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  automacao_id uuid not null,
  conversa_id uuid not null,
  mensagem_gatilho text not null,
  status text not null default 'processando'
    check (status in ('processando','enviado','erro','incerto')),
  mensagem_id uuid references public.atd_mensagens(id) on delete set null,
  erro text,
  executado_em timestamptz not null default now(),
  unique(automacao_id,mensagem_gatilho),
  foreign key(workspace_id,automacao_id) references public.atd_automacoes(workspace_id,id) on delete cascade,
  foreign key(workspace_id,conversa_id) references public.atd_conversas(workspace_id,id)
);
create index if not exists atd_automacao_execucoes_workspace on public.atd_automacao_execucoes(workspace_id,executado_em desc);

alter table public.atd_automacoes enable row level security;
alter table public.atd_automacao_execucoes enable row level security;
revoke all on public.atd_automacoes,public.atd_automacao_execucoes from public,anon,authenticated;
grant all on public.atd_automacoes,public.atd_automacao_execucoes to service_role;

insert into public.acesso_telas(tela,modulo,nome,grupo,ordem)
values ('atd-automacoes','vendas','Automações','Atendimento',123)
on conflict(tela) do nothing;
update public.pacotes_acesso
set telas=telas||array['atd-automacoes']
where (telas @> array['atd-conversas'] or telas @> array['atd-canais'] or telas @> array['atd-templates'])
  and not telas @> array['atd-automacoes'];

