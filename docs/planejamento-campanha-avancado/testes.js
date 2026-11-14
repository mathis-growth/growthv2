/* Testes automáticos do motor do Business Case. Rodar: node testes.js  (sai com código 1 se algo falhar) */
const BC = require('./motor.js'), { EXEMPLO } = require('./exemplo.js');
const res = []; let grupo = '';
const t = (nome, ok, detalhe = '') => res.push({ grupo, nome, ok: !!ok, detalhe: ok ? '' : String(detalhe) });
const perto = (a, b, tol = 0.01) => a != null && b != null && Math.abs(a - b) <= tol * Math.max(1, Math.abs(b));
const clone = o => JSON.parse(JSON.stringify(o));
const P = () => EXEMPLO();

/* ===== D. Validação matemática ===== */
grupo = 'Fórmulas';
{ const M = BC.margem(P().produto); // conta feita à mão, passo a passo
  const pl = 1997, perdas = pl * 0.075, base = pl - perdas, trib = base * 0.06, plat = base * 0.099 + 1, rl = base - trib - plat, mc = rl - 93;
  t('Receita líquida unitária = preço − perdas − tributos − plataforma − comissão', perto(M.receitaLiquida, rl, 1e-9), M.receitaLiquida + ' ≠ ' + rl);
  t('MC = receita líquida − custos variáveis não ligados à aquisição', perto(M.mc, mc, 1e-9), M.mc + ' ≠ ' + mc);
  t('MC% = MC ÷ receita líquida', perto(M.mcPct, mc / rl, 1e-9));
  t('Tributo incide uma vez só (sobre o que fica depois das perdas)', perto(M.tributos, base * 0.06, 1e-9)); }
{ const p = P(), F = BC.funil(p, 15000), cpm = 28, imp = 15000 / cpm * 1000, cl = imp * 0.012, vis = cl * 0.85, lp = vis * 0.30, L = lp + 900, part = L * 0.35, vend = part * 0.05 + (L - part) * 0.008;
  t('Leads = visitas × conversão da página (+ leads dos canais sem mídia)', perto(F.leads, L, 1e-9), F.leads + ' ≠ ' + L);
  t('Participantes = inscritos × comparecimento', perto(F.part, part, 1e-9));
  t('Vendas = presentes × conv. + ausentes × conv. (grupos que não se sobrepõem)', perto(F.vendas, vend, 1e-9));
  t('Presentes + ausentes = inscritos (sem comprador contado duas vezes)', perto(F.part + F.aus, F.inscritos, 1e-12));
  t('Novos clientes ≤ vendas', F.novos <= F.vendas + 1e-9);
  const R = BC.resultado(p, 15000);
  t('CPL = mídia ÷ leads pagos', perto(R.cpl, 15000 / F.leadsPagos, 1e-9));
  t('CAC de mídia = mídia ÷ novos clientes', perto(R.cacMidia, 15000 / F.novos, 1e-9));
  t('CPA = mídia ÷ compras', perto(R.cpa, 15000 / F.vendas, 1e-9));
  t('Contribuição residual = MC projetada − (mídia + demais custos)', perto(R.residual, R.mcTotal - 15000 - R.C.total, 1e-9));
  t('CPL máximo = CAC máximo de mídia × conversão lead → novo cliente', perto(BC.cplMaxDinamico(400, 0.05), 20, 1e-12) && perto(BC.cplMaxDinamico(400, 0.04), 16, 1e-12) && perto(BC.cplMaxDinamico(400, 0.03), 12, 1e-12)); }
grupo = 'Limites e bordas';
t('Divisão por zero devolve vazio, não Infinity', BC.div(10, 0) === null && BC.div(null, 3) === null);
{ const p = P(); p.produto.preco.v = 0; t('Preço zero é recusado pela validação', !BC.valida(p).ok); }
{ const p = P(); p.funil.comparecimento = 130; t('Taxa acima de 100% é recusada', BC.valida(p).erros.some(e => e.campo === 'funil.comparecimento')); }
{ const p = P(); p.funil.ctr = -1; t('Taxa negativa é recusada', BC.valida(p).erros.some(e => e.campo === 'funil.ctr')); }
{ const p = P(); p.recursos[3].valor = -500; t('Custo negativo é recusado', BC.valida(p).erros.some(e => /recursos/.test(e.campo))); }
{ const p = P(); delete p.produto.entrega; const M = BC.margem(p.produto); t('Custo sem valor NÃO vira zero em silêncio: aparece em "faltando" e a margem fica incompleta', !M.completa && M.faltando.includes('entrega')); }
{ const R = BC.resultado(P(), 0); t('Verba zero: CPL e CAC de mídia ficam vazios ou zero, sem erro', R.cpl === null || R.cpl === 0); }
{ const p = P(); p.produto.entrega.v = 3000; const M = BC.margem(p.produto); t('Margem negativa é calculada e sinalizada (MC < 0)', M.mc < 0); }
{ const p = P(); const a = BC.custos(p, BC.funil(p, 15000)); t('Recurso "já disponível sem desembolso" custa zero e não sai do caixa', a.linhas.find(x => x.tipo === 'disp_sem').total === 0); t('Alocação de equipe existente entra no custo, mas não sai do caixa de novo', a.linhas.filter(x => x.tipo === 'disp_aloc').every(x => x.total > 0 && x.desembolso === 0)); }
{ const p = P(), F = BC.funil(p, 15000), C = BC.custos(p, F), M = BC.margem(p.produto); t('Sem custo contado duas vezes: suporte do produto fica na MC, closer por venda fica nos custos da campanha', C.linhas.every(x => !/Suporte/i.test(x.nome)) && M.variaveis === 93); }
{ const R = BC.resultado(P(), 15000), soma = R.C.linhas.reduce((s, x) => s + x.total, 0); t('Arredondamento: soma das linhas de custo = total (diferença < R$ 0,01)', Math.abs(soma - R.C.total) < 0.01); }
{ const p = P(); const r1 = BC.resultado(p, 15000).F.vendas; p.funil.convPresentes = 6; const r2 = BC.resultado(p, 15000).F.vendas; t('Mudar uma premissa muda o resultado no sentido esperado', r2 > r1); }
{ const S = BC.cenarios(P(), 15000); t('Cenários coerentes: pessimista ≤ base ≤ otimista em vendas', S.pessimista.vendas <= S.base.vendas && S.base.vendas <= S.otimista.vendas);
  t('Cenários coerentes: CAC de mídia pessimista ≥ base ≥ otimista', S.pessimista.cacMidia >= S.base.cacMidia && S.base.cacMidia >= S.otimista.cacMidia);
  t('Cenários coerentes: contribuição residual pessimista ≤ base ≤ otimista', S.pessimista.residual <= S.base.residual && S.base.residual <= S.otimista.residual); }
{ const p = P(), R = BC.resultado(p, 15000); t('Reconciliação mídia × vendas × financeiro: CAC × novos = mídia; CPL × leads pagos = mídia', perto(R.cacMidia * R.F.novos, 15000, 1e-9) && perto(R.cpl * R.F.leadsPagos, 15000, 1e-9)); }
{ const h = BC.historico([{ midia: 100, leads: 10 }, { midia: 900, leads: 300 }]); t('Histórico usa taxa ponderada (soma ÷ soma), não média simples', perto(h.cpl, 1000 / 310, 1e-9) && !perto(h.cpl, h.mediaSimplesCpl, 1e-3)); }
{ const r = BC.bissecao(x => 100 - x, 0, 1000, 0.01); t('Busca numérica converge e respeita a tolerância', r.convergiu && Math.abs(r.x - 100) < 0.02); }

/* ===== C. Os 15 casos de teste ===== */
grupo = 'Casos';
{ const p = P(), L = BC.limites(p); t('1. Margem positiva e histórico completo: calcula limites e CAC/CPL máximos', L.autorizado > 0 && L.cacMaxAutorizado > 0 && L.cplMaxAutorizado > 0 && BC.margem(p.produto).completa, JSON.stringify({ a: L.autorizado })); }
{ const p = P(); delete p.produto.entrega; delete p.produto.suporte; const M = BC.margem(p.produto); t('2. Produto sem margem cadastrada: abre o diagnóstico com o que falta', !M.completa && M.faltando.length === 2); }
{ const p = P(); p.historico = []; const h = BC.historico(p.historico); t('3. Sem histórico: referência fica vazia (não inventa) e o cálculo usa as premissas', h.cpl === null && BC.limites(p).autorizado > 0); }
{ const p = P(), a = BC.resultado(p, 15000).residual; p.recursos.push({ nome: 'Social media extra', tipo: 'fixo', valor: 4000 }); const b = BC.resultado(p, 15000).residual; t('4. Custos adicionais de equipe reduzem a contribuição residual no valor exato', perto(a - b, 4000 * 1, 1e-9)); }
{ const p = P(); p.orcamentoDisponivel = 18000; const L = BC.limites(p); t('5. Orçamento insuficiente: o limite autorizado passa a ser o orçamento disponível', L.limitadoPor === 'orçamento disponível' && L.autorizado < 18000); }
{ const p = P(); p.caixa.saldo = 40000; const L = BC.limites(p), R = BC.resultado(p, 15000); t('6. Resultado econômico positivo com caixa insuficiente: o caixa limita a verba', R.residual > 0 && (L.limitadoPor === 'caixa' || L.financiavel.x == null)); }
{ const p = P(), L1 = BC.limites(p); p.funil.convPresentes = 3.5; const L2 = BC.limites(p); t('7. Queda de conversão baixa o CPL máximo permitido', L2.cplMaxAutorizado < L1.cplMaxAutorizado, L1.cplMaxAutorizado + ' → ' + L2.cplMaxAutorizado); }
{ const L = BC.limites(P()), s = BC.status({ cpl: L.cplMaxAutorizado * 1.2, cplAlvo: L.alvo.cpl, cplMax: L.cplMaxAutorizado, caixaFolga: 1 }); t('8. CPL acima do limite: status "acima do limite autorizado"', s[0] === 'acima_limite'); }
{ const l = BC.ltv(P().ltv); t('9. Potencial de recompra: valor futuro = probabilidade × contribuição incremental (não faturamento)', perto(l.valorPorCliente, 0.12 * (800 - 60), 1e-9) && l.fundamentado); }
{ const ok = BC.permiteNegativa({ estrategiaAprovada: true, ltvFundamentado: true, paybackDias: 120, paybackMaxDias: 180, caixaSuporta: true, limitePerda: 10000 }), nao = BC.permiteNegativa({ estrategiaAprovada: true, ltvFundamentado: false, paybackDias: 400, paybackMaxDias: 180, caixaSuporta: true, limitePerda: null });
  t('10. Contribuição inicial negativa só passa com estratégia aprovada, LTV fundamentado, payback aceito, caixa e limite de perda', ok.ok && !nao.ok && nao.motivos.length === 3); }
{ const l = BC.ltv({ ...P().ltv, clientesBase: 12 }), pr = BC.projecao(0, 0, 1000); t('11. Dados insuficientes: LTV vira hipótese e a projeção não inventa número', !l.fundamentado && /hipótese/.test(l.risco) && pr === null); }
{ const p = P(), F = BC.funil(p, 15000), C = BC.custos(p, F); t('12. Múltiplos canais: leads pagos + orgânico + API, e a API tem custo por lead', perto(F.leads, F.leadsPagos + 900, 1e-9) && C.linhas.some(x => /API/.test(x.nome) && perto(x.total, 300 * 3.15, 1e-9))); }
{ const p = P(); p.funil.pctNovos = 60; const R = BC.resultado(p, 15000); t('13. Compradores recorrentes e novos: CAC usa só os novos', perto(R.cacMidia, 15000 / (R.F.vendas * 0.6), 1e-9) && R.cacMidia > R.cpa); }
{ const p = P(), a = BC.caixa(p, 15000); p.caixa.pctParcelado = 0; const b = BC.caixa(p, 15000); p.produto.reembolso.v = 15; const c = BC.resultado(p, 15000); t('14. Reembolso e parcelamento: parcelado deixa menos caixa 90 dias depois; reembolso maior baixa a contribuição', a.serie[90] < b.serie[90] && c.mcTotal < BC.resultado(P(), 15000).mcTotal); }
{ t('15. Duas campanhas pelo mesmo orçamento: a segunda só usa o que sobra depois da primeira', BC.orcamentoDisponivel(100000, 40000, 35000) === 25000 && BC.orcamentoDisponivel(100000, 70000, 50000) === 0); }
grupo = 'Recursos da campanha';
{ const p = P(), F = BC.funil(p, 15000), base = BC.custos(p, F).total; p.recursos.forEach(r => { r.usar = false; }); const C = BC.custos(p, F);
  t('Recurso desligado (usar = não) não entra no custo nem no caixa', C.total === 300 * 3.15 && C.desembolso === 300 * 3.15 && C.semCapacidade.length === 0 && base > C.total); }
{ const p = P(), F = BC.funil(p, 15000); p.recursos = [{ nome: 'Comissão do closer', tipo: 'var_venda', unidade: 'pct', valor: 10 }]; const C = BC.custos(p, F);
  t('Variável por venda em %: 10% de R$ 1.997 × vendas', perto(C.linhas[0].total, 199.7 * F.vendas, 1e-9) && perto(C.linhas[0].desembolso, C.linhas[0].total, 1e-12)); }
grupo = 'Histórico por canal e ofertas';
{ const h = P().historico, C = BC.historicoCanais(h), soma = f => Object.values(C).reduce((s, c) => s + c[f], 0);
  t('Leads e novos por canal somam o total das campanhas', soma('leads') === h.reduce((s, c) => s + c.leads, 0) && soma('novos') === h.reduce((s, c) => s + c.novos, 0));
  t('Mídia de Meta + Google = mídia total do histórico', C.meta.custo + C.google.custo === h.reduce((s, c) => s + c.midia, 0));
  t('CAC do canal pago (novos do canal) é maior que o CAC de mídia sobre todos os novos', C.meta.cac > BC.historico(h).cac);
  t('Orgânico não tem CPL nem CAC (sem custo), e não vira zero', C.org.cpl === null && C.org.cac === null);
  const F = BC.historicoFaixas(h); t('Faixa entre campanhas: mínimo ≤ média ponderada ≤ máximo', F.cac.min <= BC.historico(h).cac && BC.historico(h).cac <= F.cac.max);
  const O = BC.historicoOfertas(h); t('Aceite do bump ponderado = vendas do bump ÷ vendas principais', perto(O.bump.aceite, 60 / 249, 1e-12));
  t('Downsell: base é quem viu a oferta, e conta só as campanhas que tiveram downsell', perto(O.downsell.aceite, 9 / 835, 1e-12) && O.downsell.campanhas === 1); }
{ const h = P().historico, H = BC.historico(h); t('CPL do histórico usa a mesma base do plano: mídia ÷ leads pagos (Meta + Google)', perto(H.cpl, 42100 / (4400 + 960), 1e-12)); }
{ const p = P(), a = BC.leadsParaMeta(p, 15000), b = BC.leadsParaMeta(p, 8000);
  t('Menos verba de mídia: o orgânico precisa trazer mais leads para a mesma meta', b.orgPrecisa > a.orgPrecisa && perto(a.leadsPrecisa * a.vendasPorLead, 70, 1e-9)); }
grupo = 'Plano por canal e cenários';
{ const h = P().historico, v = BC.verbaPeloCac(195, 70, 85), S = BC.cenariosDoHistorico(h, v, 70, 3.15), b = BC.planoCampanha(S.base);
  t('Verba pelo CAC = CAC de mídia × novos clientes da meta', perto(v, 195 * 70 * 0.85, 1e-12));
  t('Leads de cada canal pago = verba do canal ÷ CPL do canal', perto(b.pagos[0].leads, v * S.base.canais.meta.pct / 100 / S.base.canais.meta.cpl, 1e-12));
  { const E = BC.cenariosDoHistorico(h, 30000, 70, 3.15, 0.6), e1 = BC.planoCampanha(E.base), E2 = BC.cenariosDoHistorico(h, 15000, 70, 3.15, 0.6), e2 = BC.planoCampanha(E2.base);
    t('Com elasticidade, o CPL sobe quando a verba passa da média histórica, e dobrar a verba não dobra os leads', e1.cpl > e2.cpl && e1.leadsPagos < 2 * e2.leadsPagos && perto(e1.pagos[0].cpl, E.base.canais.meta.cpl * Math.pow(30000 / E.base.verbaRef, 0.6), 1e-12)); }
  t('Vendas = presentes × conversão + ausentes × conversão, com os leads de todos os canais', perto(b.vendas, b.leads * b.vendasPorLead, 1e-9));
  t('Cenários do histórico: mesma verba; pessimista vende menos e tem CAC maior que o otimista', BC.planoCampanha(S.pessimista).vendas < b.vendas && b.vendas < BC.planoCampanha(S.otimista).vendas && BC.planoCampanha(S.pessimista).cacMidia > BC.planoCampanha(S.otimista).cacMidia && S.pessimista.verba === S.otimista.verba);
  const mais = JSON.parse(JSON.stringify(S.base)); mais.canais.org.leads += 300; const m2 = BC.planoCampanha(mais);
  t('Mais orgânico com a mesma verba: mais vendas e CAC de mídia menor', m2.vendas > b.vendas && m2.cacMidia < b.cacMidia);
  t('Orgânico para a meta = leads necessários − pagos − API', perto(b.orgParaMeta, Math.max(0, b.leadsPrecisa - b.leadsPagos - b.api), 1e-12)); }
grupo = 'Plano do ano';
{ const x = { meta: 1200000, margem: 0.6, fixosMes: 20000, lucro: 120000, ticket: 1000, ativos: 400, recompra: 0.25, cacRef: 300, pesos: [10, 20, 30, 40], pctPess: 20, pctOtim: 20, nCamp: 6 }, A = BC.planoAno(x);
  t('Orçamento de aquisição = receita × margem − fixos do ano − lucro desejado', A.base.orcAq === 1200000 * 0.6 - 240000 - 120000);
  t('Novos clientes = vendas da meta − recompra esperada da base', A.base.vendas === 1200 && A.base.vendasRecompra === 100 && A.base.novos === 1100);
  t('CAC máximo do ano = orçamento de aquisição ÷ novos clientes', perto(A.base.cacMax, 360000 / 1100, 1e-12) && A.base.cabeNoCac === true);
  t('Lucro no CAC de referência = contribuição − fixos − CAC × novos', A.base.lucroNoCacRef === 720000 - 240000 - 300 * 1100);
  t('Receita mínima paga fixos, lucro e aquisição no CAC de referência', (() => { const r = BC.planoAno({ ...x, meta: A.receitaMinima }); return perto(r.base.lucroNoCacRef, 120000, 1e-9); })());
  t('Trimestres somam a meta e seguem os pesos', perto(A.trimestres.reduce((s, q) => s + q.receita, 0), 1200000, 1e-12) && perto(A.trimestres[3].receita, 480000, 1e-12) && perto(A.trimestres.reduce((s, q) => s + q.orcAq, 0), A.base.orcAq, 1e-12));
  t('Cenários: pessimista e otimista mudam a receita pelos percentuais', A.pessimista.receita === 960000 && A.otimista.receita === 1440000 && A.pessimista.orcAq < A.base.orcAq);
  t('Meta que não paga fixos e lucro: inviável, sem CAC máximo', (() => { const r = BC.planoAno({ ...x, meta: 500000 }); return r.base.viavel === false && r.base.cacMax === null; })());
  t('Sem margem ou sem ticket: incompleto, nada é calculado', (() => { const r = BC.planoAno({ ...x, margem: null, ticket: 0 }); return r.completo === false && r.faltando.includes('margem') && r.faltando.includes('ticket'); })());
  t('Contribuição que cada campanha precisa deixar = (fixos + lucro) ÷ campanhas do ano', A.residualCampanha === 60000); }
grupo = 'Planejado contra realizado';
{ const d = BC.desvios({ midia: 10000, leads: 1000, vendas: 50, novos: 40, receita: 50000 }, { midia: 12000, leads: 1000, vendas: 40, novos: 32, receita: 44000 });
  t('Desvio = real ÷ plano − 1', perto(d.vendas.desvio, -0.2, 1e-12) && perto(d.midia.desvio, 0.2, 1e-12));
  t('CPL, conversão, ticket e CAC saem dos totais de cada lado', perto(d.cpl.plano, 10, 1e-12) && perto(d.cpl.real, 12, 1e-12) && perto(d.conv.real, 0.04, 1e-12) && perto(d.ticket.real, 1100, 1e-12) && perto(d.cac.real, 375, 1e-12));
  t('Sem plano ou sem real, o desvio fica vazio (não vira zero)', BC.desvios({ midia: 0, leads: 0 }, { midia: 500, leads: 10 }).cpl.desvio === null && BC.desvios({ midia: 100, leads: 10 }, {}).cpl.desvio === null);
  const d2 = BC.desvios({ midia: 10000, leads: 1000, vendas: 50, novos: 40, receita: 50000 }, { midia: 11000, leads: 1000, vendas: 55, novos: 44, receita: 55000 }), A = BC.aprendizado([d, d2]);
  t('Aprendizado: média do desvio entre campanhas, e se todas erraram para o mesmo lado', perto(A.cpl.media, 0.15, 1e-12) && A.cpl.mesmoSentido === true && A.conv.mesmoSentido === false);
  t('Com uma campanha só, não conclui', BC.aprendizado([d]).cpl.suficiente === false && BC.aprendizado([d]).cpl.media === null); }
grupo = 'Versão aprovada';
{ const v = BC.congela({ a: 1 }, 'Rebecka', '2026-11-08', 'aprovação'); let mudou = false; try { v.foto.a = 2; mudou = v.foto.a === 2; } catch (e) {} t('Versão aprovada é imutável', !mudou && v.hash === BC.hash(JSON.stringify({ a: 1 }))); }

const falhas = res.filter(r => !r.ok);
if (typeof module !== 'undefined' && require.main === module) {
  let g = ''; res.forEach(r => { if (r.grupo !== g) { g = r.grupo; console.log('\n' + g); } console.log((r.ok ? '  ok    ' : '  FALHA ') + r.nome + (r.detalhe ? '  → ' + r.detalhe : '')); });
  console.log(`\n${res.length - falhas.length} de ${res.length} passaram`); process.exit(falhas.length ? 1 : 0);
}
module.exports = res;
