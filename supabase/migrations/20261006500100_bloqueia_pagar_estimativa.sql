-- SUBSTITUÍDA pela 20261008230000_seguranca_fase1.sql (v0.80). Não precisa rodar.
-- PENDENTE: rode no SQL Editor (a ferramenta recusou aplicar gatilhos). Impede pagar conta ainda estimada no nível do banco.
-- Sem ele, a tela já esconde o botão Pagar das contas estimadas; o gatilho é a trava extra.
create or replace function contas_pagar_bloqueia_estimativa() returns trigger language plpgsql as $$
begin
  if new.status = 'pago' and old.status <> 'pago' and old.estimativa then
    raise exception 'O valor desta conta ainda é uma estimativa. Confirme o valor real antes de pagar.';
  end if;
  return new;
end $$;
drop trigger if exists contas_pagar_estimativa_t on contas_pagar;
create trigger contas_pagar_estimativa_t before update on contas_pagar for each row execute function contas_pagar_bloqueia_estimativa();

