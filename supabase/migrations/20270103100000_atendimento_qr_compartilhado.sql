-- Link temporário para compartilhar o QR de uma instância Evolution específica.
create table privado.atd_qr_compartilhamentos (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 canal_id uuid not null,
 token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 expira_em timestamptz not null,
 criado_por uuid references auth.users(id) on delete set null,
 criado_em timestamptz not null default now(),
 usado_em timestamptz,
 revogado_em timestamptz,
 foreign key(workspace_id,canal_id) references public.atd_canais(workspace_id,id) on delete cascade,
 check(expira_em<=criado_em+interval '11 minutes')
);
create index atd_qr_links_ativos on privado.atd_qr_compartilhamentos(workspace_id,canal_id,expira_em)
 where usado_em is null and revogado_em is null;
alter table privado.atd_qr_compartilhamentos enable row level security;
revoke all on privado.atd_qr_compartilhamentos from public,anon,authenticated;
grant all on privado.atd_qr_compartilhamentos to service_role;
