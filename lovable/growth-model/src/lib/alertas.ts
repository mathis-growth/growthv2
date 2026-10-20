// @ts-nocheck
// Gerado a partir do index.html do Growths (v0.68). Lógica de cálculo determinística: NÃO usa IA. Mantenha igual ao sistema original.
// Alertas em vermelho do Growth Model (aba Mapa de métricas).
// Pior = abaixo da referência (métrica que sobe) ou acima (métrica que desce, como CPL e CAC).
// Referências: benchmark do mercado (tolerância 0), média dos 3 períodos anteriores e período anterior (tolerância 10%).
export const pior = (v, ref, dir, tol) => v != null && ref != null && ref !== 0 && (dir === 'desce' ? v > ref * (1 + tol) : v < ref * (1 - tol));
export const deltaPct = (a, b) => (a == null || b == null || b === 0) ? null : a / b - 1;
export function atingimento(v, meta, dir) { if (v == null || meta == null || Number(meta) === 0) return null; return dir === 'desce' ? (v > 0 ? Number(meta) / v : null) : v / Number(meta); }
export function alertasDaMetrica(x, { benchmarks, historicos, anterior, fmt }) {
  // x: linha de growth_metricas com .v (valor atual). historicos: valores dos 3 períodos anteriores.
  const out: string[] = [];
  if (x.v == null || x.fonte !== 'auto') return out;
  const dir = (x.chave_auto === 'cpl' || x.chave_auto === 'cac') ? 'desce' : (x.direcao || 'sobe');
  const bm = benchmarks[x.chave_auto];
  if (bm && pior(x.v, Number(bm.valor), dir, 0)) out.push(`${dir === 'desce' ? 'acima' : 'abaixo'} do benchmark do mercado (${fmt(Number(bm.valor), x.unidade)}${bm.fonte ? ', ' + bm.fonte : ''})`);
  const hs = historicos.filter(v => v != null && isFinite(v) && Number(v) !== 0).map(Number);
  if (hs.length >= 2) { const md = hs.reduce((a, b) => a + b, 0) / hs.length; if (pior(x.v, md, dir, 0.1)) out.push(`pior que a média histórica da empresa (${fmt(md, x.unidade)}, ${hs.length} períodos anteriores)`); }
  if (pior(x.v, anterior, dir, 0.1)) out.push(`pior que o período anterior (${fmt(anterior, x.unidade)})`);
  return out;
}
