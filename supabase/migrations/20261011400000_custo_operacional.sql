-- v0.93 — Tela Financeiro → Custo operacional no catálogo de acesso
-- A tela calcula tudo no navegador a partir do Contas a pagar, das recorrências e do Contas a receber (sem tabela nova).
-- Aqui só entra no catálogo de telas e nos pacotes que já têm o Contas a pagar (inclusive o da Casa).
-- Rode DEPOIS de 20261010230000_pacotes_acesso.sql. Idempotente.
insert into acesso_telas (tela, modulo, nome, grupo, ordem)
values ('fin-custo', 'fin', 'Custo operacional', 'Financeiro', coalesce((select ordem from acesso_telas where tela = 'fin-pagar'), 0) + 1)
on conflict (tela) do update set modulo = excluded.modulo, nome = excluded.nome, grupo = excluded.grupo;
update pacotes_acesso set telas = telas || array['fin-custo'] where telas @> array['fin-pagar'] and not telas @> array['fin-custo'];
