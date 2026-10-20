-- v0.120: cenário das comissões no banco (roda dentro de uma transação e desfaz no fim). psql -d fa -f t120_comissoes_banco.sql
\set ON_ERROR_STOP 1
begin;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-00000000a0a0","role":"authenticated"}',true);
\set ws '''ac56e719-7325-4062-aa47-74bc2141f89d'''
insert into equipe (workspace_id, nome, vinculo, equipe_comercial) values (:ws, 'Teste Vendedor', 'vendedor', true), (:ws, 'Teste Coprodutor', 'coprodutor', false), (:ws, 'Teste Estrategista', 'estrategista', false);
-- vendedor: escolhe um vendedor_id de vendas existentes? usa o próprio: atribui algumas vendas de setembro a ele
update vendas set vendedor_id = (select id from equipe where nome = 'Teste Vendedor') where id in (select id from vendas where workspace_id = :ws and status = 'aprovada' and data_venda >= '2026-09-01' and data_venda < '2026-10-01' order by data_venda limit 5);
\set prod '(select produto_id from vendas where workspace_id = ''ac56e719-7325-4062-aa47-74bc2141f89d'' and vendedor_id = (select id from equipe where nome = ''Teste Vendedor'') limit 1)'
insert into comissao_regras (workspace_id, equipe_id, escopo, percentual, sobre) select :ws, id, 'projeto', 5, 'proprias' from equipe where nome = 'Teste Vendedor';
insert into comissao_regras (workspace_id, equipe_id, escopo, produto_id, percentual, sobre) select :ws, id, 'produto', :prod, 8, 'proprias' from equipe where nome = 'Teste Vendedor';
insert into comissao_regras (workspace_id, equipe_id, escopo, percentual, base) select :ws, id, 'projeto', 30, 'liquido' from equipe where nome = 'Teste Coprodutor';
insert into comissao_regras (workspace_id, equipe_id, escopo, campanha_id, percentual, base, pagamento) select :ws, id, 'campanha', '54011ef1-34b7-44f1-978e-3d733d244899', 10, 'bruto', 'por_venda' from equipe where nome = 'Teste Estrategista';
select comissao_recalcular(:ws, '2026-09-01');
select e.nome, c.origem, c.status, c.pagamento, count(*), sum(valor), sum(base_valor), min(percentual), max(percentual) from comissoes c join equipe e on e.id = c.equipe_id where c.workspace_id = :ws group by 1,2,3,4 order by 1,2;
-- conferências
select 'coprodutor 30% liq vendas set+' chk, (select sum(valor) from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Coprodutor' and origem='venda') = (select sum(round(coalesce(valor_liquido,valor_bruto)*0.30,2)) from vendas where workspace_id=:ws and status='aprovada' and (coalesce(aprovada_em,data_venda) at time zone 'America/Sao_Paulo')::date >= '2026-09-01') ok;
select 'vendedor: produto 8%, demais 5%' chk, string_agg(distinct c.percentual::text || ':' || (v.produto_id = :prod)::text, ',') from comissoes c join equipe e on e.id=c.equipe_id join vendas v on v.id=c.venda_id where e.nome='Teste Vendedor';
select 'estrategista por_venda lancada com conta' chk, count(*) filter (where status='lancada' and conta_pagar_id is not null), count(*) from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Estrategista';
select comissao_fechar_mes(:ws, '2026-09-01');
select e.nome, cp.descricao, cp.valor, cp.vencimento, cp.status, (select count(*) from lancamentos where origem_id = cp.id) lanc from contas_pagar cp join equipe e on e.fornecedor_id = cp.fornecedor_id where e.nome like 'Teste %' and cp.descricao like 'Comissões de%';
-- reembolso de uma venda já lançada do coprodutor
update vendas set status = 'reembolsada', reembolsada_em = now() where id = (select venda_id from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Coprodutor' and c.status='lancada' and competencia='2026-09-01' limit 1);
select c.status, count(*) from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Coprodutor' group by 1;
select comissao_fechar_mes(:ws, '2026-10-01');
select c.status, count(*), sum(valor) from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Coprodutor' group by 1;
-- reembolso de venda por_venda do estrategista: conta prevista é cancelada
update vendas set status = 'reembolsada' where id = (select venda_id from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Estrategista' and c.status='lancada' limit 1);
select c.status, cp.status, count(*) from comissoes c join equipe e on e.id=c.equipe_id left join contas_pagar cp on cp.id=c.conta_pagar_id where e.nome='Teste Estrategista' group by 1,2;
-- parcela de contrato recebida
select count(*) parcelas_contrato, sum(valor) from comissoes c join equipe e on e.id=c.equipe_id where e.nome='Teste Coprodutor' and origem='contrato_parcela';
select count(*) from v_comissoes;
rollback;
