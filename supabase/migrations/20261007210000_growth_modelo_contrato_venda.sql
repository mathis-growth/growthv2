-- Contrato fechado conta como venda no Growth Model: o primeiro contrato (ou venda) de uma pessoa é novo cliente de aquisição
-- (na campanha do contrato, ou orgânico); contratos seguintes de quem já comprou entram na retenção. Só a quantidade (cli):
-- a receita continua vindo das parcelas (loop de contratos), então nada é somado em dobro.
do $m$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'growth_modelo_historico';
  if d like '%cn as (%' then return; end if;
  d := replace(d, $a$  pl as (select p.campanha_id,$a$, $b$  cn as (select c.id, c.campanha_id, c.produto_ref, date_trunc('month', (c.ativado_em at time zone 'America/Sao_Paulo')::date)::date m,
           not exists (select 1 from va b where b.pessoa_id = c.pessoa_id and b.d < (c.ativado_em at time zone 'America/Sao_Paulo')::date)
           and not exists (select 1 from contratos c2 where c2.pessoa_id = c.pessoa_id and c2.status in ('ativo', 'encerrado') and c2.ativado_em is not null
                           and (c2.ativado_em < c.ativado_em or (c2.ativado_em = c.ativado_em and c2.id < c.id))) primeira
         from (select k.*, (select ci.produto_id from contrato_itens ci where ci.contrato_id = k.id order by ci.valor desc limit 1) produto_ref from contratos k) c
         where c.workspace_id = p_ws and c.status in ('ativo', 'encerrado') and c.ativado_em is not null
           and (c.ativado_em at time zone 'America/Sao_Paulo')::date between v_ini and v_fim),
  pl as (select p.campanha_id,$b$);
  d := replace(d, $a$coalesce((select count(*) from vc where vc.campanha_id = c.id and vc.m = ms.m), 0) cli,$a$,
    $b$coalesce((select count(*) from vc where vc.campanha_id = c.id and vc.m = ms.m), 0) + coalesce((select count(*) from cn where cn.campanha_id = c.id and cn.m = ms.m and cn.primeira), 0) cli,$b$);
  d := replace(d, $a$  ret_vendas as ($a$, $b$  org_cn as (
    select 'organico', 'Orgânico e direto (sem campanha)', 'aquisicao', 'organico', cn.produto_ref, null::uuid, cn.m, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, count(*)::numeric, 0::numeric, 0::numeric
    from cn where cn.campanha_id is null and cn.primeira group by cn.produto_ref, cn.m),
  ret_cn as (
    select 'upgrade', 'Upgrade: cliente que já comprou outro produto', 'retencao', 'upgrade', cn.produto_ref, null::uuid, cn.m, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric, count(*)::numeric, 0::numeric, 0::numeric
    from cn where not cn.primeira group by cn.produto_ref, cn.m),
  ret_vendas as ($b$);
  d := replace(d, $a$select * from org_vendas union all select * from ret_vendas$a$, $b$select * from org_vendas union all select * from org_cn union all select * from ret_vendas union all select * from ret_cn$b$);
  if d not like '%org_cn%' or d not like '%ret_cn%' or d not like '%cn.primeira), 0) cli%' or d not like '%cn as (select%' then raise exception 'growth_modelo_historico: trecho não encontrado'; end if;
  execute d;
end
$m$;
