-- Link público estável por campanha. A seleção de grupos acontece apenas na Edge.
alter table public.atd_grupo_campanhas
  add column if not exists link_token uuid default gen_random_uuid(),
  add column if not exists link_ativo boolean not null default false,
  add column if not exists link_cursor bigint not null default 0,
  add column if not exists link_cliques bigint not null default 0,
  add column if not exists link_limite_membros integer not null default 900;

update public.atd_grupo_campanhas set link_token=gen_random_uuid() where link_token is null;
alter table public.atd_grupo_campanhas alter column link_token set not null;
create unique index if not exists atd_grupo_campanhas_link_token_idx
  on public.atd_grupo_campanhas(link_token);

do $$ begin
  if not exists (select 1 from pg_constraint where conname='atd_grupo_campanhas_link_limite_check') then
    alter table public.atd_grupo_campanhas add constraint atd_grupo_campanhas_link_limite_check
      check(link_limite_membros between 1 and 1024);
  end if;
end $$;

create table if not exists public.atd_grupo_campanha_acessos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  campanha_id uuid not null references public.atd_grupo_campanhas(id) on delete cascade,
  conversa_id uuid references public.atd_conversas(id) on delete set null,
  status text not null check(status in ('redirecionado','indisponivel')),
  criado_em timestamptz not null default now()
);
create index if not exists atd_grupo_campanha_acessos_idx
  on public.atd_grupo_campanha_acessos(campanha_id,criado_em desc);
alter table public.atd_grupo_campanha_acessos enable row level security;
revoke all on public.atd_grupo_campanha_acessos from public,anon,authenticated;
grant all on public.atd_grupo_campanha_acessos to service_role;

create or replace function public.atd_grupo_campanha_reservar(p_token uuid)
returns table(campanha_id uuid,workspace_id uuid,conversas uuid[],rodada bigint,limite_membros integer)
language plpgsql security definer set search_path=public as $$
begin
  update public.atd_grupo_campanhas c
     set link_cursor=c.link_cursor+1,link_cliques=c.link_cliques+1
   where c.link_token=p_token and c.link_ativo and cardinality(c.conversas)>0
   returning c.id,c.workspace_id,c.conversas,c.link_cursor,c.link_limite_membros
   into campanha_id,workspace_id,conversas,rodada,limite_membros;
  if found then return next; end if;
end $$;
revoke all on function public.atd_grupo_campanha_reservar(uuid) from public,anon,authenticated;
grant execute on function public.atd_grupo_campanha_reservar(uuid) to service_role;
