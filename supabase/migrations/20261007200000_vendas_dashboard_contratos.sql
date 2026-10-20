-- Contrato fechado também é venda: entra uma vez no Dashboard de Vendas (quantidade, ticket médio e clientes por produto).
-- Não cria linha em `vendas`; o Growth Model e o Painel gerencial já contam contratos por regra própria, então não há contagem dupla.
do $m$
declare d text;
begin
  select pg_get_functiondef(p.oid) into d from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'vendas_dashboard';
  if d like '%contrato_itens%' then return; end if;
  d := replace(d,
    $a$ven as (select v.pessoa_id, v.valor_bruto, coalesce(pr.nome, '—') as produto from vendas v left join produtos pr on pr.id = v.produto_id where v.workspace_id = p_ws and v.status = 'aprovada'),$a$,
    $b$ven as (
    select v.pessoa_id, v.valor_bruto, coalesce(pr.nome, '—') as produto from vendas v left join produtos pr on pr.id = v.produto_id where v.workspace_id = p_ws and v.status = 'aprovada'
    union all
    select c.pessoa_id,
           coalesce((select sum(cr.valor) from contas_receber cr where cr.contrato_id = c.id and cr.status <> 'cancelado' and cr.substituida_por is null), 0),
           coalesce((select string_agg(distinct pr.nome, ', ') from contrato_itens ci join produtos pr on pr.id = ci.produto_id where ci.contrato_id = c.id), 'Contrato')
      from contratos c where c.workspace_id = p_ws and c.status in ('ativo', 'encerrado')
  ),$b$);
  if d not like '%contrato_itens%' then raise exception 'vendas_dashboard: trecho não encontrado'; end if;
  execute d;
end
$m$;
