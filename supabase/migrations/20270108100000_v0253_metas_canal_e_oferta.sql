-- v0.253 — Metas de vendas por canal (em porcentagem) e por oferta da campanha.
-- campanhas.meta_vendas passa a ser a soma das ofertas; campanha_ofertas.meta_vendas guarda a de cada uma. Idempotente.
alter table public.campanha_canais add column if not exists percentual_meta_vendas numeric(6,3);
alter table public.campanha_ofertas add column if not exists meta_vendas int check (meta_vendas is null or meta_vendas >= 0);
notify pgrst, 'reload schema';
-- Para desfazer: alter table public.campanha_canais drop column percentual_meta_vendas; alter table public.campanha_ofertas drop column meta_vendas;
