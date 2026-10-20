-- v0.53: regras contábeis personalizadas (eventos novos criados pela própria pessoa).
-- Os 9 eventos do sistema continuam fixos. Os novos têm código "x_<nome>" e são usados pelo botão "Lançar" da tela de regras.
alter table regras_contabilizacao add column if not exists nome text;
alter table regras_contabilizacao add column if not exists personalizada boolean not null default false;

alter table regras_contabilizacao drop constraint if exists regras_contabilizacao_evento_check;
alter table regras_contabilizacao add constraint regras_contabilizacao_evento_check check (
  (not personalizada and evento in ('venda_receita', 'venda_taxa_plataforma', 'venda_imposto', 'recebimento', 'estorno_pagamento',
    'conta_pagar', 'pagamento', 'contrato_receita', 'contrato_recebimento'))
  or (personalizada and evento ~ '^x_[a-z0-9_]{2,40}$' and nome is not null and length(trim(nome)) > 0));
