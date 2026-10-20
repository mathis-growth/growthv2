-- v0.95 — Cenários ruim / bom / ótimo nos índices do Planejamento
-- A meta (valor_meta) é o cenário bom. faixa_ruim = abaixo da meta mas aceitável; faixa_otimo = acima da meta.
-- Usado na tela Financeiro → Custos e margens para a margem de lucro líquida (ruim, bom e ótimo definidos pela empresa).
-- Rode DEPOIS de 20261011500000_margens_indicadores.sql. Idempotente.
alter table plano_indicadores add column if not exists faixa_ruim numeric;
alter table plano_indicadores add column if not exists faixa_otimo numeric;
comment on column plano_indicadores.faixa_ruim is 'v0.95: cenário ruim (abaixo da meta, ainda aceitável). A meta é o cenário bom.';
comment on column plano_indicadores.faixa_otimo is 'v0.95: cenário ótimo (acima da meta).';
