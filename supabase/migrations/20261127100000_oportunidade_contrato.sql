-- v0.174 — E2 da integração comercial: o lead passa a ser a oportunidade, e a oportunidade gera o contrato (a proposta é o contrato em rascunho).
-- 1. contratos.oportunidade_id: de qual oportunidade o contrato saiu. Uma oportunidade pode ter mais de um contrato
--    (por exemplo, implantação parcelada + mensalidade recorrente). O contrato precisa ser da mesma pessoa e da mesma empresa da oportunidade.
-- 2. oportunidades.origem aceita 'crm' (oportunidade de venda nova aberta a partir do lead).
-- 3. Contrato ativado → a oportunidade dele, se ainda aberta, vira ganha.
-- 4. O negócio no cadastro da pessoa (pessoas.negocio_status) vira resumo das oportunidades de venda nova:
--    ganha → negócio ganho; perdida (e nenhuma outra aberta ou ganha) → perdido; nova ou reaberta com o negócio perdido → aberto.
-- Rode depois de 20261126100000_pessoa_documento.sql. Idempotente.

alter table contratos add column if not exists oportunidade_id uuid references oportunidades(id) on delete set null;
create index if not exists contratos_oportunidade on contratos (oportunidade_id) where oportunidade_id is not null;

do $c$
declare k text;
begin
  for k in select conname from pg_constraint where conrelid = 'public.oportunidades'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%origem%' loop
    execute format('alter table oportunidades drop constraint %I', k);
  end loop;
  alter table oportunidades add constraint oportunidades_origem_check check (origem in ('manual', 'alerta', 'rfm', 'ascensao', 'marco', 'intervencao', 'crm'));
end $c$;

-- o contrato só pode apontar para uma oportunidade da mesma pessoa e da mesma empresa
create or replace function public.contratos_oportunidade_valida() returns trigger language plpgsql set search_path = public as $$
begin
  if new.oportunidade_id is not null and not exists (select 1 from oportunidades o where o.id = new.oportunidade_id and o.pessoa_id = new.pessoa_id and o.workspace_id = new.workspace_id) then
    raise exception 'A oportunidade precisa ser do mesmo cliente do contrato.';
  end if;
  return new;
end $$;
revoke execute on function public.contratos_oportunidade_valida() from public, anon, authenticated;
drop trigger if exists contratos_oportunidade_valida_t on contratos;
create trigger contratos_oportunidade_valida_t before insert or update of oportunidade_id, pessoa_id on contratos for each row execute function contratos_oportunidade_valida();

-- contrato ativado: a oportunidade aberta dele vira ganha (definidora: quem ativa pelo financeiro também fecha a oportunidade)
create or replace function public.contratos_ganha_oportunidade() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ativo' and old.status is distinct from 'ativo' and new.oportunidade_id is not null then
    update oportunidades set status = 'ganha', fechado_em = coalesce(fechado_em, now()) where id = new.oportunidade_id and status = 'aberta';
  end if;
  return null;
end $$;
revoke execute on function public.contratos_ganha_oportunidade() from public, anon, authenticated;
drop trigger if exists contratos_ganha_oportunidade_t on contratos;
create trigger contratos_ganha_oportunidade_t after update of status on contratos for each row execute function contratos_ganha_oportunidade();

-- o negócio da pessoa acompanha as oportunidades de venda nova
create or replace function public.oportunidade_negocio_pessoa() returns trigger language plpgsql security definer set search_path = public as $$
declare st text;
begin
  if new.tipo <> 'nova_venda' then return null; end if;
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return null; end if;
  select negocio_status into st from pessoas where id = new.pessoa_id;
  if new.status = 'ganha' and st is distinct from 'ganho' then
    update pessoas set negocio_status = 'ganho' where id = new.pessoa_id;
  elsif new.status = 'perdida' and st = 'aberto'
        and not exists (select 1 from oportunidades o where o.pessoa_id = new.pessoa_id and o.tipo = 'nova_venda' and o.status in ('aberta', 'ganha') and o.id <> new.id) then
    update pessoas set negocio_status = 'perdido' where id = new.pessoa_id;
  elsif new.status = 'aberta' and st = 'perdido' then
    update pessoas set negocio_status = 'aberto' where id = new.pessoa_id;
  end if;
  return null;
end $$;
revoke execute on function public.oportunidade_negocio_pessoa() from public, anon, authenticated;
drop trigger if exists oportunidade_negocio_pessoa_t on oportunidades;
create trigger oportunidade_negocio_pessoa_t after insert or update of status on oportunidades for each row execute function oportunidade_negocio_pessoa();

-- Para desfazer: drop trigger oportunidade_negocio_pessoa_t on oportunidades; drop trigger contratos_ganha_oportunidade_t on contratos;
-- drop trigger contratos_oportunidade_valida_t on contratos; drop function oportunidade_negocio_pessoa(), contratos_ganha_oportunidade(), contratos_oportunidade_valida();
-- alter table contratos drop column oportunidade_id; e recriar oportunidades_origem_check sem 'crm' (se nenhuma oportunidade usar).
