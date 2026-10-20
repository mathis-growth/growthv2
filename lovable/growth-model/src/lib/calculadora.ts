// @ts-nocheck
// Gerado a partir do index.html do Growths (v0.68). Lógica de cálculo determinística: NÃO usa IA. Mantenha igual ao sistema original.
export const OFERTA_PAPEL = { principal: 'Oferta principal', upsell: 'Upsell', order_bump: 'Order bump', cross_sell: 'Cross-sell', downsell: 'Downsell' };
export const CC_TIPOS = [['fixo', 'Valor fixo (R$)'], ['por_lead', 'Por lead (R$)'], ['por_venda', 'Por venda (R$)'], ['pct_receita', '% da receita']];
export const ccPos = x => x != null && isFinite(x) && x > 0;
export const ccNum = x => (x === '' || x == null || !isFinite(Number(x))) ? null : Number(x);
export function ccEdita(P, k, val) {
  const Q = { ...P }, c = ccPos(Q.conv) ? Q.conv / 100 : null; let dica = '';
  if (['ticket', 'conv', 'cpl', 'leads'].includes(k)) Q[k] = val;
  else if (val == null) { /* campo apagado: nada a ajustar */ }
  else if (k === 'cac') { if (c) Q.cpl = val * c; else dica = 'Preencha a conversão para o CAC ajustar o custo por lead.'; }
  else if (k === 'vendas') { if (c) Q.leads = val / c; else dica = 'Preencha a conversão para as vendas ajustarem os leads.'; }
  else if (k === 'receita') { if (ccPos(Q.ticket) && c) Q.leads = val / Q.ticket / c; else dica = 'Preencha o ticket e a conversão para a receita ajustar os leads.'; }
  else if (k === 'midia') { if (ccPos(Q.cpl)) Q.leads = val / Q.cpl; else dica = 'Preencha o custo por lead para o investimento ajustar os leads.'; }
  else if (k === 'roas') { if (ccPos(val) && ccPos(Q.ticket) && c) Q.cpl = (Q.ticket / val) * c; else dica = 'Preencha o ticket e a conversão para o ROAS ajustar o custo por lead.'; }
  else Q[k] = val;
  return { P: Q, dica };
}
export function ccSaida(P) {
  const T = ccNum(P.ticket), c = ccPos(P.conv) ? P.conv / 100 : null, cpl = ccNum(P.cpl), L = ccNum(P.leads), mAlvo = (ccNum(P.margem) || 0) / 100;
  const v = ((ccNum(P.impostos) || 0) + (ccNum(P.taxa) || 0) + (ccNum(P.comissao) || 0)) / 100, k = ccNum(P.custoVar) || 0, D = ccNum(P.despesa) || 0;
  const V = L != null && c ? L * c : null, R = V != null && T != null ? V * T : null, M = L != null && cpl != null ? L * cpl : null;
  const cac = cpl != null && c ? cpl / c : null, roas = ccPos(M) && R != null ? R / M : null;
  const mc = T != null ? T * (1 - v) - k : null;
  const extras = (P.custos || []).reduce((t, x) => { const q = ccNum(x.valor) || 0; return t + (x.tipo === 'por_lead' ? q * (L || 0) : x.tipo === 'por_venda' ? q * (V || 0) : x.tipo === 'pct_receita' ? q / 100 * (R || 0) : q); }, 0);
  const pronto = V != null && R != null && M != null && mc != null;
  const lucro = pronto ? V * mc - M - extras - D : null, margem = pronto && R > 0 ? lucro / R : null;
  const cacMax = ccPos(V) && mc != null ? mc - mAlvo * T - (extras + D) / V : null;
  const cacEq = ccPos(V) && mc != null ? mc - (extras + D) / V : null;
  const custoTotal = pronto ? V * (T * v + k) + M + extras + D : null;
  const vendasEq = mc != null && cac != null && mc - cac > 0 ? (extras + D) / (mc - cac) : null;
  return { T, c, cpl, L, V, R, M, cac, roas, mc, extras, D, lucro, margem, mAlvo,
    cacTotal: ccPos(V) ? (M + extras) / V : null,
    cacMax, cplMax: cacMax != null && c ? cacMax * c : null,
    roasIdeal: ccPos(cacMax) ? T / cacMax : null, roasEq: ccPos(cacEq) ? T / cacEq : null,
    convMin: ccPos(cacMax) && cpl != null ? cpl / cacMax : null,
    roi: ccPos(custoTotal) ? lucro / custoTotal : null, custoTotal, vendasEq };
}
export function ccPadrao() { return { ticket: null, conv: null, cpl: null, leads: null, impostos: 0, taxa: 0, comissao: 0, custoVar: 0, margem: 20, despesa: 0, canais: [], custos: [] }; }
