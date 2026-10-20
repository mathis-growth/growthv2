/* Testes do motor do Simulador de lucro (v0.81). Rodar: node tests/simulador_motor.test.js
   Lê o motor direto do frontend/index.html (entre os marcadores do bloco), sem navegador e sem banco. */
const fs = require('fs'), path = require('path');
const html = fs.readFileSync(path.join(__dirname, '..', 'frontend', 'index.html'), 'utf8');
const ini = html.indexOf('/* ===== v0.81 — Simulador de lucro (Growth Profit Simulator): motor de cálculo'), fim = html.indexOf('/* ===== fim do motor do simulador ===== */');
if (ini < 0 || fim < 0) { console.error('Marcadores do motor não encontrados no index.html'); process.exit(2); }
const brl = n => Number(n || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
eval(html.slice(ini, fim).replace(/\bconst (GPS_|gps)/g, 'var $1'));
let falhas = 0;
const ok = (c, msg, extra) => { console.log((c ? 'OK    ' : 'FALHA ') + msg + (extra !== undefined ? '  → ' + JSON.stringify(extra) : '')); if (!c) falhas++; };
const perto = (a, b, tol = 0.01) => a != null && b != null && Math.abs(a - b) <= tol;

/* cenário de referência (seção 10): ticket 1.000, mídia 20.000, custo variável 20%, fixo 10.000, meta 30%, ROAS 3x → 60 vendas */
function ref() {
  const S = gpsNovo('ref'); S.horizonte = 1; S.margemAlvo = 30; S.inicio = '2026-11';
  const P = gpsProduto({ nome: 'Curso', preco: 1000, simples: { base: 'pct', pct: 20, unit: 0, impostosInclusos: true } });
  S.produtos = [P]; S.fixos = [gpsFixo({ nome: 'Equipe', valor: 10000 })];
  S.canais = [gpsCanal({ nome: 'Meta', midia: 20000, modo: 'clientes', clientes: 60, entrada: P.id })];
  return S;
}
{ const r = gpsCalc(ref()), i = r.indicadores;
  ok(perto(i.receitaBruta, 60000), 'Ref: receita 60.000', i.receitaBruta);
  ok(perto(i.contribuicao, 48000), 'Ref: contribuição 48.000', i.contribuicao);
  ok(perto(i.resultado, 18000), 'Ref: resultado 18.000', i.resultado);
  ok(perto(i.margemOp, 0.30, 1e-9), 'Ref: margem 30%', i.margemOp);
  ok(perto(i.novos, 60), 'Ref: 60 vendas', i.novos);
  ok(perto(i.cacMidia, 333.33), 'Ref: CAC mídia 333,33', i.cacMidia);
  ok(perto(i.roas1, 3, 1e-9), 'Ref: ROAS 3x', i.roas1);
  ok(perto(i.roasEquilibrio, 1.875, 1e-9), 'Ref: ROAS equilíbrio 1,875x', i.roasEquilibrio);
  ok(perto(i.roasAlvo, 3, 1e-9), 'Ref: ROAS-alvo 3x', i.roasAlvo);
  ok(perto(i.cacMax, 333.33), 'Ref: CAC mídia máximo 333,33 (meta exatamente batida)', i.cacMax);
  ok(i.formulaUnica, 'Ref: identificado como produto único');
  /* fórmula fechada da seção 6.3 */
  const M = 20000, F = 10000, A = 0, c = 0.8, m = 0.3;
  ok(perto(i.roasAlvo, (M + F + A) / (M * (c - m)), 1e-9) && perto(i.roasEquilibrio, (M + F + A) / (M * c), 1e-9), 'Ref: bate com as fórmulas fechadas da seção 6.3');
}
/* T01 só um produto, sem ascensão */
{ const r = gpsCalc(ref()); ok(r.transicoes.length === 0 && r.avisos.every(a => !a.cod.startsWith('ascensao')) && r.indicadores.resultado > 0, 'T01 um produto: cálculo completo, sem ascensão'); }
/* T02 desativar produto de entrada */
{ const S = ref(); const B = gpsProduto({ nome: 'Mentoria', preco: 5000 }); S.produtos.push(B);
  S.jornada = [gpsTransicao({ de: S.produtos[0].id, para: B.id, probPct: 10, lag: 1 })]; S.horizonte = 3;
  S.produtos[0].ativo = false; const r = gpsCalc(S);
  ok(r.totais.bruta === 0 && r.totais.midia === 0 && r.produtos.every(p => p.compras === 0), 'T02 entrada desativada: nenhuma receita, mídia ou compra órfã', r.totais);
  ok(r.avisos.some(a => a.cod === 'transicao_suspensa') && r.avisos.some(a => a.cod === 'canal_suspenso'), 'T02 avisa transição e canal suspensos'); }
/* T03 trocar modo de custos preserva dados e não conta em dobro */
{ const S = ref(); S.produtos[0].completo = [{ cat: 'impostos', base: 'pct', valor: 6 }, { cat: 'plataforma', base: 'pct', valor: 10 }, { cat: 'entrega', base: 'venda', valor: 40 }];
  const a = gpsCalc(S).totais; S.modoCusto = 'completo'; const b = gpsCalc(S).totais; S.modoCusto = 'simples'; const c = gpsCalc(S).totais;
  ok(perto(a.vari + a.imp, 12000) && perto(b.imp, 3600) && perto(b.vari, 6000 + 2400) && perto(c.vari, a.vari), 'T03 troca de modo: simples 20% = 12.000; completo 3.600 imposto + 8.400 variável; volta igual', { a: a.vari, bi: b.imp, bv: b.vari });
  ok(S.produtos[0].simples.pct === 20 && S.produtos[0].completo.length === 3, 'T03 os dois conjuntos continuam salvos');
  ok(!gpsCalc(S).avisos.some(x => x.cod === 'divergencia_custos'), 'T03 simplificado 20% = detalhado 6+10+4%: sem aviso', gpsDivergencia(S.produtos[0], 0));
  S.produtos[0].simples.pct = 25; ok(gpsCalc(S).avisos.some(x => x.cod === 'divergencia_custos'), 'T03 simplificado 25% x detalhado 20%: avisa a divergência', gpsDivergencia(S.produtos[0], 0)); }
/* T04 dois produtos com rateio: soma por produto = consolidado */
{ const S = ref(); const B = gpsProduto({ nome: 'Ebook', preco: 47, simples: { base: 'pct', pct: 10, impostosInclusos: true } }); S.produtos.push(B);
  S.canais.push(gpsCanal({ nome: 'Google', midia: 3000, outros: 500, modo: 'leads', leads: 1000, conversaoPct: 5, entrada: B.id })); S.horizonte = 6;
  ['receita', 'igual', 'manual'].forEach(reg => { S.rateio = reg; S.produtos[0].rateioPct = 70; B.rateioPct = 30;
    const r = gpsCalc(S), soma = r.produtos.reduce((s, p) => s + p.resultado, 0);
    ok(perto(soma, r.totais.resultado, 1e-6), 'T04 rateio ' + reg + ': soma dos produtos = consolidado', [soma, r.totais.resultado]); }); }
/* T05 mídia zero */
{ const S = ref(); S.canais[0].midia = 0; const i = gpsCalc(S).indicadores; ok(i.roas1 === null && i.cacMidia === null && i.roasAlvo === null, 'T05 mídia zero: ROAS e CAC mídia N/D'); }
/* T06 zero clientes */
{ const S = ref(); S.canais[0].clientes = 0; const r = gpsCalc(S); ok(r.indicadores.cacMidia === null && r.indicadores.cacTotal === null && r.avisos.some(a => a.cod === 'sem_clientes'), 'T06 zero clientes: CAC N/D e alerta'); }
/* T07 ascensão em 3 meses: receita e caixa só no mês devido */
{ const S = ref(); S.horizonte = 6; S.canais[0].meses = 1; const B = gpsProduto({ nome: 'Mentoria', preco: 5000 }); S.produtos.push(B);
  S.jornada = [gpsTransicao({ de: S.produtos[0].id, para: B.id, probPct: 20, lag: 3 })]; const r = gpsCalc(S), pb = r.produtos.find(p => p.id === B.id);
  ok(pb.mensal.bruta.every((v, i) => i === 3 ? perto(v, 60000) : v === 0), 'T07 ascensão em 3 meses: receita só no mês 4', pb.mensal.bruta);
  ok(r.mensal.every((x, i) => i === 3 ? x.caixaIn >= 60000 - 1e-6 : i === 0 || x.caixaIn === 0), 'T07 caixa da ascensão só no mês devido'); }
/* T08 ascensão 20% de 100 elegíveis = 20 compras */
{ const S = ref(); S.horizonte = 3; S.canais[0].meses = 1; S.canais[0].clientes = 100; const B = gpsProduto({ nome: 'Mentoria', preco: 5000 }); S.produtos.push(B);
  S.jornada = [gpsTransicao({ de: S.produtos[0].id, para: B.id, probPct: 20, lag: 1 })]; const r = gpsCalc(S), pb = r.produtos.find(p => p.id === B.id), t = r.transicoes[0];
  ok(perto(pb.compras, 20, 1e-9) && perto(t.elegiveis, 100) && perto(t.atual, 20), 'T08 20% de 100 elegíveis = 20 compras', [pb.compras, t.elegiveis, t.atual]); }
/* T09 meta inalcançável */
{ const S = ref(); S.fixos[0].valor = 60000; const r = gpsCalc(S); ok(r.indicadores.cacMax < 0 && r.indicadores.orcamentoMax === 0 && r.avisos.some(a => a.cod === 'cac_max_negativo'), 'T09 meta inalcançável: CAC máximo negativo, orçamento 0 e alerta', r.indicadores.cacMax); }
/* T10 ROAS cai com mídia fixa */
{ const S = ref(); S.cenarios.custom = { ...S.cenarios.custom, roasAlvo: 2 }; const c = gpsCenario(S, 'custom'), r = gpsCalc(S, c.aj), i = r.indicadores;
  ok(perto(i.roas1, 2, 1e-9) && perto(i.midia, 20000) && perto(i.receitaBruta, 40000) && perto(i.contribuicao, 32000) && perto(i.resultado, 2000), 'T10 ROAS 2x com mídia fixa: receita 40.000, contribuição 32.000, resultado 2.000', [i.roas1, i.receitaBruta, i.resultado]);
  ok(/mídia constante/.test(c.constante), 'T10 explica que a mídia ficou constante', c.constante); }
/* T11 reembolso e parcelamento: competência x caixa */
{ const S = ref(); S.horizonte = 12; S.canais[0].meses = 1; S.produtos[0].cobranca = 'parcelado'; S.produtos[0].parcelas = 6; S.produtos[0].reembolsoPct = 10;
  const r = gpsCalc(S); const m0 = r.mensal[0];
  ok(perto(r.totais.reemb, 6000) && perto(m0.bruta, 60000) && perto(m0.caixaIn, 9000) && perto(r.mensal[5].caixaIn, 9000) && r.mensal[6].caixaIn === 0, 'T11 parcelado 6x com 10% de reembolso: competência 60.000 no mês 1, caixa 9.000/mês por 6 meses', [m0.bruta, m0.caixaIn, r.mensal[5].caixaIn]);
  ok(perto(r.totais.caixaIn, 54000), 'T11 caixa total = receita − reembolso (54.000)', r.totais.caixaIn); }
/* T12 recorrência com churn */
{ const S = gpsNovo('rec'); S.horizonte = 4; const P = gpsProduto({ nome: 'Assinatura', preco: 100, cobranca: 'recorrente', churnPct: 10 }); S.produtos = [P];
  S.canais = [gpsCanal({ midia: 1000, modo: 'clientes', clientes: 100, entrada: P.id, meses: 1 })]; const r = gpsCalc(S), c = r.produtos[0].mensal.compras;
  ok(perto(c[0], 100) && perto(c[1], 90) && perto(c[2], 81) && perto(c[3], 72.9), 'T12 base ativa decai 10% ao mês (100, 90, 81, 72,9)', c);
  ok(r.avisos.some(a => a.cod === 'janela_curta'), 'T12 avisa receita de renovação fora do horizonte'); }
/* T13 salvar e reabrir */
{ const S = ref(); S.horizonte = 6; const snap = gpsSnapshot(S, 'v1'); const reaberto = JSON.parse(JSON.stringify(snap)); const r = gpsCalc(reaberto.premissas).indicadores;
  ok(reaberto.versao_formula === GPS_VERSAO && Object.keys(snap.metricas).every(k => snap.metricas[k] === r[k] || perto(snap.metricas[k], r[k], 1e-9)), 'T13 salvar e reabrir: mesmos resultados com a mesma versão'); }
/* T14 múltiplos canais, sem duplicidade */
{ const S = ref(); S.horizonte = 2; S.canais.push(gpsCanal({ nome: 'Google', midia: 5000, outros: 1000, modo: 'clientes', clientes: 10, entrada: S.produtos[0].id }));
  const r = gpsCalc(S); ok(perto(r.totais.midia, 50000) && perto(r.totais.outros, 2000) && perto(r.totais.novos, 140) && perto(r.canais.reduce((s, c) => s + c.clientes, 0), r.totais.novos), 'T14 dois canais: mídia, outros custos e clientes somam sem duplicar', [r.totais.midia, r.totais.novos]); }

/* extras: jornada multiproduto e ascensões necessárias */
{ const S = ref(); S.horizonte = 6; S.fixos[0].valor = 40000; const B = gpsProduto({ nome: 'Mentoria', preco: 5000, simples: { base: 'pct', pct: 30, impostosInclusos: true } }); S.produtos.push(B);
  S.jornada = [gpsTransicao({ de: S.produtos[0].id, para: B.id, probPct: 5, lag: 2 })]; const r = gpsCalc(S), t = r.transicoes[0], i = r.indicadores;
  ok(t.necessarias > 0 && t.convMin > 0.05, 'Extra: ascensões necessárias para bater a meta calculadas', t);
  /* aplicar exatamente as ascensões necessárias deve bater a meta (com pouca folga) */
  const S2 = JSON.parse(JSON.stringify(S)); S2.jornada[0].probPct = t.convMin * 100; const r2 = gpsCalc(S2);
  ok(r2.indicadores.margemOp >= 0.30 - 1e-6, 'Extra: com a conversão mínima, a margem chega aos 30%', r2.indicadores.margemOp);
  /* ROAS-alvo na jornada: escalar conversão por escalaAlvo dá margem = meta */
  const r3 = gpsCalc(S, { escala: i.escalaAlvo }); ok(perto(r3.indicadores.margemOp, 0.30, 1e-6), 'Extra: ROAS-alvo da jornada leva exatamente à margem-alvo', r3.indicadores.margemOp); }
{ const S = ref(); S.horizonte = 3; const P = S.produtos[0]; S.jornada = [gpsTransicao({ de: P.id, para: P.id, probPct: 50, lag: 0, maxCompras: 3 })];
  const r = gpsCalc(S); ok(r.avisos.some(a => a.cod === 'ciclo') && isFinite(r.totais.bruta), 'Extra: ciclo sem defasagem é cortado e avisado'); }
{ const S = ref(); S.horizonte = 4; S.canais[0].meses = 1; const P = S.produtos[0]; S.jornada = [gpsTransicao({ de: P.id, para: P.id, probPct: 50, lag: 1, maxCompras: 3 })];
  const r = gpsCalc(S); ok(perto(r.produtos[0].compras, 60 + 30 + 15), 'Extra: recompra limitada a 3 compras por cliente (60 + 30 + 15)', r.produtos[0].compras); }
{ const S = ref(); S.horizonte = 3; S.fixos[0].valor = 50000; S.canais[0].meses = 1; const r = gpsCalc(S);
  ok(r.indicadores.caixaMin < 0 && r.avisos.some(a => a.cod === 'caixa_insuficiente'), 'Extra: caixa negativo gera alerta de capital de giro', r.indicadores.caixaMin); }
{ const S = ref(); S.cenarios.custom = { ...S.cenarios.custom, midiaPct: 100, eficiencia: 0.8 }; const r = gpsCalc(S, gpsCenario(S, 'custom').aj);
  ok(perto(r.indicadores.novos, 60 * Math.pow(2, 0.8)) && r.indicadores.cacMidia > 333.34, 'Extra: dobrar a mídia não dobra os clientes (eficiência 0,8) e o CAC sobe', [r.indicadores.novos, r.indicadores.cacMidia]); }
{ const s = gpsSensibilidade((() => { const S = ref(); S.horizonte = 3; return S; })()); ok(s.length === 7 && s[0].mais !== 0, 'Extra: sensibilidade com 7 alavancas ordenadas pelo impacto', s.map(x => x.nome)); }
{ const S = ref(); S.produtos[0].simples = { base: 'pct', pct: 10, impostosInclusos: false }; S.impostoPct = 6; const t = gpsCalc(S).totais;
  ok(perto(t.imp, 3600) && perto(t.vari, 6000), 'Extra: imposto fora do percentual entra uma vez só (6% = 3.600)', [t.imp, t.vari]); }
{ const r = gpsCalc(gpsNovo()); ok(r.avisos.some(a => a.cod === 'sem_produtos') && r.indicadores.margemOp === null, 'Extra: cenário vazio não quebra e mostra N/D'); }

/* --- revisão independente (v0.81): defeitos encontrados e corrigidos --- */
{ const S = gpsNovo('perf'); S.horizonte = 12; const ps = [0, 1, 2].map(i => gpsProduto({ nome: 'P' + i, preco: 100 * (i + 1) })); S.produtos = ps;
  S.canais = [gpsCanal({ midia: 1000, modo: 'clientes', clientes: 50, entrada: ps[0].id })];
  ps.forEach(a => ps.forEach(b => S.jornada.push(gpsTransicao({ de: a.id, para: b.id, probPct: 20, lag: 1, maxCompras: 12 }))));
  let t0 = Date.now(); gpsCalc(S); const dt = Date.now() - t0; ok(dt < 1500, 'Rev 1: jornada com 3 produtos ligados entre si calcula rápido (antes ~4 s)', dt + ' ms');
  S.horizonte = 60; ps.push(gpsProduto({ nome: 'P3', preco: 50 })); S.produtos = ps; ps.forEach(a => S.jornada.push(gpsTransicao({ de: a.id, para: ps[3].id, probPct: 10, lag: 1, maxCompras: 3 })));
  t0 = Date.now(); gpsCalc(S); const dt2 = Date.now() - t0; ok(dt2 < 8000, 'Rev 1: horizonte de 60 meses não trava', dt2 + ' ms'); }
{ const S = gpsNovo('loop'); S.horizonte = 24; const A = gpsProduto({ nome: 'A', preco: 100 }); S.produtos = [A];
  S.canais = [gpsCanal({ modo: 'clientes', clientes: 100, entrada: A.id, meses: 1 })]; S.jornada = [gpsTransicao({ de: A.id, para: A.id, probPct: 100, lag: 1, maxCompras: 24 })];
  ok(perto(gpsCalc(S).produtos[0].compras, 2400), 'Rev 2: sem corte silencioso em 12 níveis (100 clientes × 24 compras)', gpsCalc(S).produtos[0].compras); }
{ const S = ref(); S.canais.push(gpsCanal({ nome: 'Orgânico', midia: 0, modo: 'clientes', clientes: 40, entrada: S.produtos[0].id })); const i = gpsCalc(S).indicadores;
  ok(perto(i.cacMidia, 333.33) && perto(i.roas1, 3, 1e-9) && perto(i.novos, 100), 'Rev 3: CAC mídia e ROAS só com os clientes e a receita dos canais pagos', [i.cacMidia, i.roas1]); }
{ const S = gpsNovo('rec'); S.horizonte = 6; S.margemAlvo = 40; const A = gpsProduto({ nome: 'A', preco: 1000 }), B = gpsProduto({ nome: 'B', preco: 100, cobranca: 'recorrente', churnPct: 0 });
  S.produtos = [A, B]; S.fixos = [gpsFixo({ valor: 5000 / 6 })]; S.canais = [gpsCanal({ midia: 20000, modo: 'clientes', clientes: 60, entrada: A.id, meses: 1 })];
  S.jornada = [gpsTransicao({ de: A.id, para: B.id, probPct: 5, lag: 3 })]; const t = gpsCalc(S).transicoes[0];
  ok(perto(t.contribUnit, 300), 'Rev 4: assinatura que começa no mês 4 vale só os 3 meses que sobram', t.contribUnit);
  S.jornada[0].probPct = t.convMin * 100; const mg = gpsCalc(S).indicadores.margemOp; ok(t.convMin <= 1 ? mg >= 0.40 - 1e-6 : true, 'Rev 4: aplicar a conversão mínima chega à meta de 40%', [t.convMin, mg]); }
{ const S = gpsNovo('max'); S.horizonte = 3; S.margemAlvo = 30; const A = gpsProduto({ nome: 'A', preco: 1000, simples: { base: 'pct', pct: 20, impostosInclusos: true } }); S.produtos = [A];
  S.fixos = [gpsFixo({ valor: 2000 })]; S.canais = [gpsCanal({ midia: 30000, modo: 'clientes', clientes: 60, entrada: A.id, meses: 1 })]; S.jornada = [gpsTransicao({ de: A.id, para: A.id, probPct: 50, lag: 1, maxCompras: 2 })];
  const t = gpsCalc(S).transicoes[0]; ok(perto(t.elegiveis, 60) && perto(t.atual, 30), 'Rev 5: com limite de 2 compras, elegíveis = 60 e esperadas = 30', [t.elegiveis, t.atual]);
  S.jornada[0].probPct = t.convMin * 100; ok(gpsCalc(S).indicadores.margemOp >= 0.30 - 1e-6, 'Rev 5: aplicar a conversão mínima chega à meta', gpsCalc(S).indicadores.margemOp); }
{ const S = gpsNovo('free'); S.horizonte = 3; const A = gpsProduto({ nome: 'Isca', preco: 0 }), B = gpsProduto({ nome: 'B', preco: 2000 }); S.produtos = [A, B];
  S.canais = [gpsCanal({ midia: 10000, modo: 'clientes', clientes: 100, entrada: A.id, meses: 1 })]; S.jornada = [gpsTransicao({ de: A.id, para: B.id, probPct: 20, lag: 1 })]; const i = gpsCalc(S).indicadores;
  ok(i.roasEquilibrio === null && i.roasAlvo === null && i.roasJornadaAlvo > 0, 'Rev 6: produto de entrada gratuito: ROAS 1ª compra-alvo N/D, ROAS da jornada-alvo calculado', [i.roasEquilibrio, i.roasJornadaAlvo]); }
{ const S = ref(); const r = gpsCalc(S, { midiaPct: -150 }); ok(r.totais.midia === 0 && r.totais.resultado <= 0 && isFinite(r.totais.novos), 'Rev 7: cortar mais de 100% da mídia não gera lucro fantasma', [r.totais.midia, r.totais.resultado]); }
{ const S = ref(); S.horizonte = 2; const B = gpsProduto({ nome: 'B', preco: 500 }); S.produtos.push(B); const A = S.produtos[0];
  S.jornada = [gpsTransicao({ de: A.id, para: B.id, probPct: 30, lag: 0 }), gpsTransicao({ de: B.id, para: A.id, probPct: 10, lag: 0 })]; const r = gpsCalc(S);
  ok(r.produtos.find(p => p.id === B.id).compras > 0 && r.avisos.some(a => a.cod === 'ciclo'), 'Rev 8: ciclo no mesmo mês corta só uma transição', r.produtos.map(p => p.compras)); }
{ const S = ref(); S.produtos.push(null); S.produtos[0].completo = [null, { cat: 'plataforma', base: 'pct', valor: 5 }]; S.canais.push(null); S.jornada = [null]; S.fixos.push(null); S.modoCusto = 'completo';
  let erro = null; try { gpsCalc(S); } catch (e) { erro = e.message; } ok(erro === null, 'Rev 9: itens vazios na lista não quebram o cálculo', erro); }
{ const S = gpsNovo('fora'); S.horizonte = 3; const A = gpsProduto({ nome: 'Clube', preco: 100, cobranca: 'recorrente', churnPct: 0, duracaoMax: 12 }); S.produtos = [A];
  S.canais = [gpsCanal({ midia: 100, modo: 'clientes', clientes: 10, entrada: A.id, meses: 1 })]; ok(perto(gpsCalc(S).indicadores.foraHorizonte, 9000), 'Rev: renovações depois do horizonte somadas até a duração (9 × 10 × 100)', gpsCalc(S).indicadores.foraHorizonte); }
{ const S = ref(); S.cenarios.custom = { ...S.cenarios.custom, roasAlvo: 2, midiaPct: 50 }; ok(/mídia deste cenário/.test(gpsCenario(S, 'custom').constante), 'Rev: texto do ROAS fixo não diz "mídia constante" quando a mídia muda'); }
console.log(falhas ? '\n' + falhas + ' FALHA(S)' : '\nTUDO OK'); process.exit(falhas ? 1 : 0);
