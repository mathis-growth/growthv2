-- v0.127: saldo mínimo de caixa por cliente (workspace), no cadastro da empresa.
-- Usado no Financeiro (linha do mínimo contra o caixa projetado de 30 dias) e nas observações do Dashboard.
-- Pode ser rodado de novo sem erro.
alter table public.empresa add column if not exists saldo_minimo numeric;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'empresa_saldo_minimo_check') then
    alter table public.empresa add constraint empresa_saldo_minimo_check check (saldo_minimo is null or saldo_minimo >= 0);
  end if;
end $$;
comment on column public.empresa.saldo_minimo is 'Saldo que o caixa não pode furar (R$). Vazio = sem alerta.';
notify pgrst, 'reload schema';
