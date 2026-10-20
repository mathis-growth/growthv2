-- Base para testar 20261011200000_projetos_tags_modelos.sql (depois de fase2_base.sql e da migração v0.89).
alter table campanha_canais add column meta_leads int, add column meta_cpl numeric;
create table projeto_modelos (id uuid primary key default gen_random_uuid(), workspace_id uuid, nome text, descricao text, padrao_campanha boolean default false, ativo boolean default true, criado_em timestamptz default now());
create table projeto_modelo_atividades (id uuid primary key default gen_random_uuid(), workspace_id uuid, modelo_id uuid, pai_id uuid, titulo text, descricao text, funcao text, responsavel_id uuid, ordem int, depende_de uuid[] default '{}', prazo_dias int);
CREATE OR REPLACE FUNCTION public.projeto_aplica_modelo(p_projeto uuid, p_modelo uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
declare p projetos;
begin
  select * into p from projetos where id = p_projeto;
  perform set_config('growths.recalc', '1', true);
  with m as (select a.*, gen_random_uuid() as novo from projeto_modelo_atividades a where a.modelo_id = p_modelo and a.workspace_id = p.workspace_id)
  insert into projeto_atividades (id, workspace_id, projeto_id, pai_id, titulo, descricao, funcao, responsavel_id, ordem, depende_de, prazo)
  select m.novo, m.workspace_id, p_projeto, (select x.novo from m x where x.id = m.pai_id), m.titulo, m.descricao, m.funcao, coalesce(m.responsavel_id, equipe_resolve(m.workspace_id, m.funcao)), m.ordem,
         coalesce((select array_agg(x.novo) from m x where x.id = any(m.depende_de)), '{}'), case when p.data_inicio is not null then p.data_inicio + m.prazo_dias end
  from m;
  perform projeto_recalcula(p_projeto);
end $function$;
create or replace function public.projeto_gera_atividades() returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  if new.modelo_id is not null then perform projeto_aplica_modelo(new.id, new.modelo_id); end if;
  return null;
end $function$;
create trigger projeto_gera_t after insert on projetos for each row execute function projeto_gera_atividades();
