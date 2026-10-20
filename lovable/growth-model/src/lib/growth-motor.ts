// @ts-nocheck
// Gerado a partir do index.html do Growths (v0.68). Lógica de cálculo determinística: NÃO usa IA. Mantenha igual ao sistema original.
export const brl = (v: number) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
export const gmFmt = (v, u) => v == null || !isFinite(v) ? '—' : u === 'brl' ? brl(v) : u === 'pct' ? (v * 100).toLocaleString('pt-BR', { maximumFractionDigits: 2 }) + '%' : v.toLocaleString('pt-BR', { maximumFractionDigits: 1 });
export const gmMes = d => new Date(d + 'T12:00:00').toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' }).replace('.', '');
export function gmMeses(inicio, n) { const [a, m] = inicio.slice(0, 7).split('-').map(Number); return Array.from({ length: n }, (_, i) => new Date(Date.UTC(a, m - 1 + i, 1)).toISOString().slice(0, 10)); }
export const GL_ROT = { inv: 'Investimento', imp: 'Impressões', clk: 'Cliques', vis: 'Visitas na página', led: 'Leads', qua: 'Leads qualificados', cli: 'Clientes (compras)', base: 'Clientes elegíveis' };
export const GL_TIPO = { campanha: 'Campanha', organico: 'Orgânico', upgrade: 'Upgrade', recompra: 'Recompra', contratos: 'Contratos' };
export const GL_ORDEM = ['inv', 'imp', 'clk', 'vis', 'led', 'qua', 'cli'];
export function glRotuloTaxa(a, b) {
  const k = a + '>' + b;
  return ({ 'inv>imp': 'CPM (R$ por mil impressões)', 'imp>clk': 'CTR', 'clk>vis': 'Connect rate', 'vis>led': 'Conversão visita → lead', 'led>qua': '% de qualificação', 'qua>cli': 'Conversão lead qualificado → compra', 'led>cli': 'Conversão lead → compra', 'vis>cli': 'Conversão visita → compra', 'clk>cli': 'Conversão clique → compra', 'imp>cli': 'Conversão impressão → compra', 'inv>cli': 'Compras por R$ investido', 'base>cli': '% dos elegíveis que compra' })[k] || (GL_ROT[a] + ' → ' + GL_ROT[b]);
}
export function glMonta(rows, meses) {
  const ix = {}; meses.forEach((m, i) => ix[m] = i);
  const o = { nome: rows[0].nome, tipo: rows[0].tipo, fase: rows[0].fase, loop: rows[0].loop, campanha_id: rows[0].campanha_id, produto_id: rows[0].produto_id, real: {} };
  ['inv', 'imp', 'clk', 'vis', 'led', 'qua', 'cli', 'rec', 'base'].forEach(k => o.real[k] = meses.map(() => 0));
  rows.forEach(r => { const i = ix[r.mes]; if (i == null) return; Object.keys(o.real).forEach(k => o.real[k][i] += Number(r[k] || 0)); });
  return o;
}
export function glCalc(L, meses, mesAtual, ov, cen, win, encerrada) {
  const n = meses.length, ia = meses.findIndex(m => m >= mesAtual), iFut = ia < 0 ? n : ia;
  const tem = k => L.real[k].some(x => x > 0);
  let ch = L.tipo === 'upgrade' || L.tipo === 'recompra' ? ['base', 'cli'] : L.tipo === 'contratos' ? ['cli'] : GL_ORDEM.filter(tem);
  if (!ch.includes('cli') && L.real.cli.some(x => x > 0)) ch.push('cli');
  if (!ch.length) ch = ['cli'];
  const hist = []; for (let i = iFut - 1; i >= 0 && hist.length < win; i--) hist.push(i);
  const soma = (k, ids) => ids.reduce((s, i) => s + L.real[k][i], 0);
  const pares = ch.slice(1).map((b, j) => [ch[j], b]);
  const def = { vol: ch.length && !encerrada && hist.length ? soma(ch[0], hist) / hist.length : 0 };
  pares.forEach(([a, b]) => { const A = soma(a, hist), B = soma(b, hist); def['r:' + a + '>' + b] = a === 'inv' && b === 'imp' ? (B ? A * 1000 / B : 0) : (A ? B / A : 0); });
  const cl = soma('cli', hist); def.tkt = cl ? soma('rec', hist) / cl : (L.real.cli.reduce((s, x) => s + x, 0) ? L.real.rec.reduce((s, x) => s + x, 0) / L.real.cli.reduce((s, x) => s + x, 0) : 0);
  const lev = (k, i) => { const c = ov[k] || {}; for (let j = i; j >= 0; j--) { if (cen === 'sim' && c['sim|' + meses[j]] != null) return c['sim|' + meses[j]]; if (c['base|' + meses[j]] != null) return c['base|' + meses[j]]; } return def[k]; };
  const vol = {}; ch.forEach(k => vol[k] = L.real[k].slice()); const rate = {}, tkt = L.real.rec.map((r, i) => L.real.cli[i] ? r / L.real.cli[i] : null), rec = L.real.rec.slice();
  pares.forEach(([a, b]) => rate[a + '>' + b] = meses.map((_, i) => a === 'inv' && b === 'imp' ? (L.real.imp[i] ? L.real.inv[i] * 1000 / L.real.imp[i] : null) : (L.real[a][i] ? L.real[b][i] / L.real[a][i] : null)));
  for (let i = iFut; i < n; i++) {
    vol[ch[0]][i] = lev('vol', i);
    pares.forEach(([a, b]) => { const kk = 'r:' + a + '>' + b, r = lev(kk, i); rate[a + '>' + b][i] = r; vol[b][i] = a === 'inv' && b === 'imp' ? (r ? vol[a][i] * 1000 / r : 0) : vol[a][i] * r; });
    tkt[i] = lev('tkt', i); rec[i] = (vol.cli ? vol.cli[i] : 0) * tkt[i];
  }
  return { ch, pares, vol, rate, tkt, rec, def, iFut, lev };
}
