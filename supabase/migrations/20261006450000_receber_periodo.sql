-- v0.26 — Contas a receber por período, provisionamento de contratos e receita recorrente por cliente.
-- Tudo calculado no banco. Atraso é sempre total (independe do período); "a receber" só conta o que vence dentro do período.
create or replace function public.receber_periodo(p_ws uuid, p_ini date, p_fim date, p_hoje date default current_date)
returns jsonb language plpgsql stable set search_path to 'public' as $function$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'sem acesso ao workspace'; end if;
  with
  cr as (select c.id, c.valor, c.vencimento, c.status, c.data_recebimento, c.contrato_id,
                coalesce(ct.pessoa_id, ve.pessoa_id) as pessoa_id
         from contas_receber c left join contratos ct on ct.id = c.contrato_id left join vendas ve on ve.id = c.venda_id
         where c.workspace_id = p_ws),
  prev as (select * from cr where status = 'previsto' and vencimento between p_ini and p_fim),
  rec as (select * from cr where status = 'recebido' and coalesce(data_recebimento, vencimento) between p_ini and p_fim),
  atr as (select * from cr where status = 'previsto' and vencimento < p_hoje),
  mes as (select date_trunc('month', vencimento)::date as m, sum(valor) as v, count(*) as n from prev group by 1),
  ctr as (select c.pessoa_id, c.id,
            coalesce((select sum(coalesce(i.quantidade, 1) * coalesce(i.valor, 0)) from contrato_itens i where i.contrato_id = c.id), 0)
              / case c.periodicidade when 'mensal' then 1 when 'trimestral' then 3 when 'semestral' then 6 else 12 end as mrr
          from contratos c where c.workspace_id = p_ws and c.recorrente and c.ativado_em is not null
            and c.data_inicio <= p_hoje and (c.data_fim is null or c.data_fim >= p_hoje)
            and not (c.cancelado_em is not null and (c.cancelado_em at time zone 'UTC')::date <= p_hoje)),
  mrr as (select pessoa_id, sum(mrr) as mrr, count(*) as contratos from ctr group by pessoa_id),
  cli as (select p.id, p.nome,
            coalesce((select sum(valor) from prev where prev.pessoa_id = p.id), 0) as a_receber,
            coalesce((select sum(valor) from prev where prev.pessoa_id = p.id and prev.contrato_id is not null), 0) as de_contratos,
            coalesce((select sum(valor) from atr where atr.pessoa_id = p.id), 0) as atraso,
            coalesce((select sum(valor) from rec where rec.pessoa_id = p.id), 0) as recebido,
            coalesce(m.mrr, 0) as mrr, coalesce(m.mrr, 0) * 12 as arr, coalesce(m.contratos, 0) as contratos
          from pessoas p left join mrr m on m.pessoa_id = p.id
          where p.workspace_id = p_ws and (exists (select 1 from prev where prev.pessoa_id = p.id) or exists (select 1 from atr where atr.pessoa_id = p.id)
                or exists (select 1 from rec where rec.pessoa_id = p.id) or m.pessoa_id is not null))
  select jsonb_build_object(
    'periodo', jsonb_build_object('ini', p_ini, 'fim', p_fim),
    'a_receber', jsonb_build_object('valor', coalesce((select sum(valor) from prev), 0), 'qtd', (select count(*) from prev),
        'de_contratos', coalesce((select sum(valor) from prev where contrato_id is not null), 0)),
    'atraso', jsonb_build_object('valor', coalesce((select sum(valor) from atr), 0), 'qtd', (select count(*) from atr)),
    'recebido', jsonb_build_object('valor', coalesce((select sum(valor) from rec), 0), 'qtd', (select count(*) from rec)),
    'mrr', coalesce((select sum(mrr) from mrr), 0), 'arr', coalesce((select sum(mrr) from mrr), 0) * 12,
    'por_mes', coalesce((select jsonb_agg(jsonb_build_object('mes', m, 'valor', v, 'qtd', n) order by m) from mes), '[]'),
    'por_cliente', coalesce((select jsonb_agg(to_jsonb(x) order by x.a_receber desc, x.mrr desc) from (select * from cli order by a_receber desc, mrr desc limit 200) x), '[]')
  ) into r;
  return r;
end $function$;
