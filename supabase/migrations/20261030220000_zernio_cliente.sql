-- v0.178 — permite contas Zernio de WhatsApp oficial sem alterar o cadastro existente.
-- Aplicar somente depois da Central de Atendimento v0.175.
alter table public.conexao_contas drop constraint if exists conexao_contas_tipo_check;
alter table public.conexao_contas add constraint conexao_contas_tipo_check
  check (tipo in ('meta_ads','instagram','facebook_pagina','google_ads','youtube','whatsapp'));

-- Evita associar uma conta Zernio a dois workspaces, inclusive sob requisições concorrentes.
create or replace function public.conexao_zernio_isolamento()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare plataforma text;
begin
  select c.plataforma into plataforma from public.conexoes c
   where c.id = new.conexao_id and c.workspace_id = new.workspace_id;
  if plataforma is null then raise exception 'Conexão fora do workspace'; end if;
  if plataforma <> 'zernio' then return new; end if;
  if new.tipo not in ('instagram','whatsapp') then raise exception 'Canal Zernio inválido'; end if;
  perform pg_advisory_xact_lock(hashtextextended(new.id_externo, 74812));
  if exists (
    select 1 from public.conexao_contas k
    join public.conexoes c on c.id = k.conexao_id
    where c.plataforma = 'zernio' and k.id_externo = new.id_externo
      and k.workspace_id <> new.workspace_id
  ) or exists (
    select 1 from public.atd_canais a
    where a.provedor = 'zernio' and a.externo_id = new.id_externo
      and a.workspace_id <> new.workspace_id
  ) then raise exception 'Conta Zernio já vinculada a outro cliente'; end if;
  return new;
end $$;
drop trigger if exists conexao_zernio_isolamento_t on public.conexao_contas;
create trigger conexao_zernio_isolamento_t before insert or update on public.conexao_contas
for each row execute function public.conexao_zernio_isolamento();
