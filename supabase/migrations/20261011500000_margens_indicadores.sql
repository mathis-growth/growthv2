-- v0.94 — Margem de contribuição e margem de lucro líquida como indicadores do Planejamento
-- 1. plano_indicadores aceita as chaves 'margem_lucro' e 'margem_contribuicao' (valor calculado pela DRE do período).
-- 2. Indicadores já criados à mão com esses nomes passam a usar a chave (ex.: "Margem de lucro líquida", meta 30%).
-- 3. valor_indicador calcula as duas margens em % a partir de v_dre_mensal:
--    margem de contribuição = (receitas − deduções − custos) ÷ receitas
--    margem de lucro líquida = (receitas − deduções − custos − despesas) ÷ receitas
-- Rode DEPOIS de 20261011400000_custo_operacional.sql. Idempotente.

alter table plano_indicadores drop constraint if exists plano_indicadores_chave_check;
alter table plano_indicadores add constraint plano_indicadores_chave_check check (chave = any (array[
  'receita', 'mrr', 'leads', 'clientes', 'conversao', 'investimento', 'cac', 'ticket_medio', 'margem_lucro', 'margem_contribuicao']));

update plano_indicadores set chave = 'margem_lucro', unidade = 'pct' where chave is null and nome ilike 'margem de lucro%';
update plano_indicadores set chave = 'margem_contribuicao', unidade = 'pct' where chave is null and nome ilike 'margem de contribui%';

create or replace function public.valor_indicador(p_ws uuid, p_chave text, p_ini date, p_fim date)
 returns numeric language plpgsql stable security definer set search_path to 'public'
as $function$
declare v numeric; cli numeric; rec numeric; lds numeric; inv numeric; ded numeric; cus numeric; des numeric;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este workspace'; end if;
  select coalesce(sum(valor) filter (where tipo = 'receita'), 0), coalesce(sum(valor) filter (where tipo = 'deducao'), 0),
         coalesce(sum(valor) filter (where tipo = 'custo'), 0), coalesce(sum(valor) filter (where tipo = 'despesa'), 0)
    into rec, ded, cus, des
    from v_dre_mensal
   where workspace_id = p_ws and mes >= date_trunc('month', p_ini)::date and mes <= date_trunc('month', p_fim)::date;
  select count(*) into lds from pessoas where workspace_id = p_ws
   and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select count(*) into cli from pessoas where workspace_id = p_ws and convertido_em is not null
   and (convertido_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim;
  select coalesce(sum(custo), 0) into inv from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim;
  v := case p_chave
    when 'receita' then rec
    when 'leads' then lds
    when 'clientes' then cli
    when 'investimento' then inv
    when 'conversao' then case when lds > 0 then round(100.0 * (select count(*) from pessoas where workspace_id = p_ws and convertido_em is not null
         and (criado_em at time zone 'America/Sao_Paulo')::date between p_ini and p_fim) / lds, 2) end
    when 'cac' then case when cli > 0 then round(inv / cli, 2) end
    when 'ticket_medio' then case when cli > 0 then round(rec / cli, 2) end
    when 'mrr' then (select coalesce(sum(
                       (select coalesce(sum(i.quantidade * i.valor), 0) from contrato_itens i where i.contrato_id = c.id)
                       / (case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end)), 0)
                     from contratos c where c.workspace_id = p_ws and c.status = 'ativo' and c.recorrente
                       and c.data_inicio <= p_fim and (c.data_fim is null or c.data_fim >= p_fim))
    when 'margem_contribuicao' then case when rec > 0 then round(100.0 * (rec - ded - cus) / rec, 2) end
    when 'margem_lucro' then case when rec > 0 then round(100.0 * (rec - ded - cus - des) / rec, 2) end
  end;
  return v;
end $function$;

-- a tela de custos ganhou as margens: novo nome no catálogo de acesso
do $$ begin
  if to_regclass('public.acesso_telas') is not null then update acesso_telas set nome = 'Custos e margens' where tela = 'fin-custo'; end if;
end $$;
