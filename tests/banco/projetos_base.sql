-- Base mínima de projetos e blocos de campanha (cópia da produção em 10/10/2026) para testar a parte 4 da migração v0.86.
create table equipe (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, funcao text, ativo boolean default true, criado_em timestamptz default now());
create table campanhas (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, data_inicio date, data_fim date);
create table projetos (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, descricao text, status text default 'planejado', campanha_id uuid, modelo_id uuid,
  responsavel_id uuid, data_inicio date, data_fim_prevista date, criado_em timestamptz default now());
create table projeto_atividades (id uuid primary key default gen_random_uuid(), workspace_id uuid, projeto_id uuid, pai_id uuid, titulo text, descricao text, funcao text, responsavel_id uuid,
  status text default 'bloqueada', ordem int default 0, depende_de uuid[] default '{}', prazo date, liberada_em timestamptz, iniciada_em timestamptz, concluida_em timestamptz,
  criado_em timestamptz default now(), atualizado_em timestamptz default now());
create table campanha_blocos (id uuid primary key default gen_random_uuid(), workspace_id uuid not null, campanha_id uuid not null references campanhas(id) on delete cascade,
  bloco_origem_id uuid, ordem int not null default 10, fase text not null default 'aquisicao', tipo text not null, nome text not null, origem_ref uuid, ativo boolean not null default true,
  criado_em timestamptz not null default now());

create function atividade_avisa(uuid) returns void language sql as $$ select $$;
CREATE OR REPLACE FUNCTION public.equipe_resolve(p_ws uuid, p_funcao text) RETURNS uuid LANGUAGE sql STABLE AS $function$
  select id from equipe where workspace_id = p_ws and ativo and p_funcao is not null and lower(trim(funcao)) = lower(trim(p_funcao)) order by criado_em limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.projeto_recalcula(p_projeto uuid) RETURNS void LANGUAGE plpgsql AS $function$
declare r record; mudou boolean; n int := 0;
begin
  perform set_config('growths.recalc', '1', true);
  loop
    mudou := false; n := n + 1;
    exit when n > 25;
    for r in
      select a.id from projeto_atividades a
      where a.projeto_id = p_projeto and a.status = 'bloqueada'
        and (a.pai_id is null or exists (select 1 from projeto_atividades pa where pa.id = a.pai_id and pa.status in ('liberada', 'em_andamento')))
        and not exists (select 1 from unnest(a.depende_de) d(id) join projeto_atividades x on x.id = d.id where x.status not in ('concluida', 'cancelada'))
    loop
      update projeto_atividades set status = 'liberada', liberada_em = now() where id = r.id;
      mudou := true;
      if not exists (select 1 from projeto_atividades c where c.pai_id = r.id) then perform atividade_avisa(r.id); end if;
    end loop;
    exit when not mudou;
  end loop;
  perform set_config('growths.recalc', '', true);
end $function$;

CREATE OR REPLACE FUNCTION public.atividade_valida() RETURNS trigger LANGUAGE plpgsql AS $function$
declare livre boolean := coalesce(current_setting('growths.recalc', true), '') = '1';
begin
  if not livre then
    if not exists (select 1 from projetos where id = new.projeto_id and workspace_id = new.workspace_id) then raise exception 'O projeto precisa pertencer ao mesmo workspace'; end if;
  end if;
  if tg_op = 'INSERT' then new.status := 'bloqueada'; end if;
  new.atualizado_em := now();
  return new;
end $function$;
create trigger atividade_valida_t before insert or update on projeto_atividades for each row execute function atividade_valida();
create or replace function public.atividade_pos() returns trigger language plpgsql as $function$
begin
  if coalesce(current_setting('growths.recalc', true), '') = '1' then return null; end if;
  perform projeto_recalcula(coalesce(new.projeto_id, old.projeto_id));
  return null;
end $function$;
create trigger atividade_pos_t after insert or delete or update on projeto_atividades for each row execute function atividade_pos();

create or replace function public.campanha_cria_projeto() returns trigger language plpgsql as $function$
begin
  insert into projetos (workspace_id, nome, campanha_id, data_inicio) values (new.workspace_id, 'Campanha: ' || new.nome, new.id, new.data_inicio);
  return null;
end $function$;
create trigger campanha_cria_projeto_t after insert on campanhas for each row execute function campanha_cria_projeto();
