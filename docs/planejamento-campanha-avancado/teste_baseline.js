// Testes das contas do baseline (planavBaseCalc), com vendas montadas à mão
const fs = require('fs'), vm = require('vm'), src = fs.readFileSync(__dirname + '/planav_growths.js', 'utf8');
const ctx = { VIEWS: {}, console }; vm.createContext(ctx); vm.runInContext(src, ctx); const calc = ctx.planavBaseCalc;
let ok = 0, n = 0; const t = (nome, c) => { n++; if (c) ok++; console.log((c ? '  ok  ' : 'FALHOU') + ' ' + nome); };
const v = (d, p, b, o = {}) => ({ data_venda: d, pessoa_id: p, produto_id: o.prod || 'x', valor_bruto: b, taxa_plataforma: b * 0.1, impostos: b * 0.06, status: o.re ? 'reembolsada' : 'aprovada', reembolsada_em: o.re ? d : null });
const vend = [v('2025-01-10', 'a', 1000), v('2025-03-01', 'a', 500), v('2025-12-20', 'a', 300), v('2026-02-01', 'b', 1000), v('2026-06-01', 'c', 1000), v('2026-06-15', 'c', 200), v('2026-10-01', 'd', 1000), v('2026-10-05', 'e', 1000, { re: true }), v('2024-05-05', 'z', 700)];
const camps = [{ data_inicio: '2026-05-20', midia: 3000, leads: 100 }, { data_inicio: '2025-01-01', midia: 900, leads: 50 }, { data_inicio: '2026-09-01', midia: 0, leads: 0 }];
const B = calc(vend, camps, [{ valor: 500, competencia: '2026-06-01' }, { valor: 999, competencia: '2024-01-01' }], '2026-11-13');
t('Receita de 2026 soma só vendas aprovadas (reembolsada fica fora)', B.anos['2026'].bruto === 3200 && B.anos['2026'].vendas === 4 && B.anos['2026'].reembolsos === 1);
t('Últimos 12 meses: de 14/11/2025 a 13/11/2026', B.u12.bruto === 3500 && B.u12.vendas === 5);
t('Cliente novo conta só na primeira compra', B.anos['2025'].novos === 1 && B.anos['2026'].novos === 3 && B.u12.novos === 3);
t('Mídia e custos de aquisição entram no ano da campanha e da competência', B.anos['2026'].midia === 3000 && B.anos['2025'].midia === 900 && B.u12.custosAq === 500 && B.u12.campanhas === 1);
t('Recompra em 180 dias: só quem já tem 180 dias de casa entra (z, a e b entram; c e d ainda não; só a recomprou)', B.recompra.elegiveis === 3 && B.recompra.recompraram === 1);
t('Recompra depois de 180 dias não conta (a comprou de novo em 50 dias; a 3ª compra é irrelevante)', calc([v('2025-01-01', 'q', 1), v('2025-08-01', 'q', 1)], [], [], '2026-11-13').recompra.recompraram === 0);
t('Clientes ativos: compraram nos últimos 12 meses', B.ativos === 4);
t('Cobertura: meses com venda no ano e janela do ano corrente até o mês de hoje', B.anos['2026'].meses === 3 && B.anos['2026'].mesesJanela === 11 && B.anos['2025'].mesesJanela === 12 && B.mesesComVenda === 7);
t('Taxas e impostos somados das vendas aprovadas', Math.abs(B.u12.taxas - 350) < 1e-9 && Math.abs(B.u12.impostos - 210) < 1e-9);
t('Sem vendas: tudo zero, sem erro e sem datas', (() => { const z = calc([], [], [], '2026-11-13'); return z.u12.vendas === 0 && z.primeiraVenda === null && z.recompra.elegiveis === 0 && z.mesesComVenda === 0; })());
console.log(`\n${ok} de ${n} passaram`); if (ok !== n) process.exit(1);
