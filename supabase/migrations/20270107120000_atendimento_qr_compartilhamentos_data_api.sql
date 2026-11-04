-- A Edge usa o cliente PostgREST com service_role para consultar os links.
-- Mover a tabela privada para public disponibiliza a relação ao PostgREST;
-- RLS e privilégios continuam permitindo acesso somente à service_role.
do $$
begin
  if to_regclass('public.atd_qr_compartilhamentos') is null then
    if to_regclass('privado.atd_qr_compartilhamentos') is null then
      raise exception 'A tabela privado.atd_qr_compartilhamentos não existe; aplique primeiro a migration atendimento_qr_compartilhado.';
    end if;
    alter table privado.atd_qr_compartilhamentos set schema public;
  end if;
end
$$;

alter table public.atd_qr_compartilhamentos enable row level security;
revoke all on table public.atd_qr_compartilhamentos from public, anon, authenticated;
grant all on table public.atd_qr_compartilhamentos to service_role;

notify pgrst, 'reload schema';
