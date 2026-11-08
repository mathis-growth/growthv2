const BC = require('./motor.js'), { EXEMPLO } = require('./exemplo.js'), { performance } = require('perf_hooks');
const med = (nome, fn, n) => { for (let i = 0; i < Math.min(5, n); i++) fn(); const ts = []; for (let i = 0; i < n; i++) { const a = performance.now(); fn(); ts.push(performance.now() - a); } ts.sort((x, y) => x - y); return { nome, n, mediana: ts[Math.floor(n / 2)], p95: ts[Math.floor(n * 0.95)], max: ts[n - 1] }; };
const p = EXEMPLO(), out = [
  med('resultado() — uma verba', () => BC.resultado(p, 15000), 2000),
  med('caixa() — 1 ano dia a dia', () => BC.caixa(p, 15000), 500),
  med('limites() — econômico, caixa, capacidade, orçamento e meta', () => BC.limites(p), 50),
  med('cenarios() — três cenários com limites', () => BC.cenarios(p, 15000), 20),
  med('alterar uma premissa e recalcular tudo', () => { const q = JSON.parse(JSON.stringify(p)); q.funil.convPresentes = 4 + Math.random() * 2; BC.limites(q); BC.cenarios(q, 15000); }, 20),
  med('testes automáticos (49)', () => { delete require.cache[require.resolve('./testes.js')]; require('./testes.js'); }, 5) ];
console.log(JSON.stringify({ node: process.version, cpu: require('os').cpus()[0].model, nucleos: require('os').cpus().length, resultados: out.map(o => ({ ...o, mediana: +o.mediana.toFixed(2), p95: +o.p95.toFixed(2), max: +o.max.toFixed(2) })) }, null, 1));
