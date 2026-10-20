-- saldo por conta contábil (D − C) e quanto de despesa caiu em outubro
select pc.codigo, sum(case when p.tipo='D' then p.valor else -p.valor end) saldo,
       sum(case when p.tipo='D' then p.valor else -p.valor end) filter (where l.data_fato between '2026-10-01' and '2026-10-31') outubro
from partidas p join lancamentos l on l.id=p.lancamento_id join plano_contas pc on pc.id=p.conta_id group by pc.codigo order by 1;
select descricao, valor, status, saldo_de is not null tem_saldo_de, substituida_por is not null substituida from contas_pagar order by criado_em, descricao;
