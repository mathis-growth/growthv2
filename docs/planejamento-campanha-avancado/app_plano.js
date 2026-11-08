/* ===== Depois dos limites: escolher o CAC, copiar para os cenários, distribuir por canal, status e Growth Model da campanha ===== */
const CENS = [['pessimista', 'Pessimista'], ['base', 'Base'], ['otimista', 'Otimista']];
const apiCusto = p => { const a = (p.canais || []).find(c => c.tipo === 'api'); return a ? a.custoLead : 0; };
function planoDe(p) { // estado do planejamento, criado na primeira vez a partir do histórico
  if (!ST.p.plan) { const H = BC.historico(ST.p.historico); ST.p.plan = { fonte: 'historico', cac: Math.round(H.cac), meta: ST.p.metaVendas, cens: null, ativo: 'base' }; }
  return ST.p.plan;
}
function econ(p, c) { // economia de um cenário: MC das vendas − mídia − demais custos
  const r = BC.planoCampanha(c), q = JSON.parse(JSON.stringify(p)); q.canais = q.canais.map(x => x.tipo === 'api' ? { ...x, leads: c.canais.api.leads } : x.tipo === 'org' ? { ...x, leads: c.canais.org.leads } : x);
  const C = BC.custos(q, { leads: r.leads, vendas: r.vendas }), mcVenda = BC.resultado(p, Math.max(1, r.verba)).mcVenda, M = BC.margem(p.produto), o = p.ofertas;
  const recVenda = M.receitaLiquida + ['bump', 'upsell'].reduce((s, k) => s + (o[k] && o[k].tem ? o[k].aceite / 100 * o[k].recLiqUnit : 0), 0);
  return { r, C, demais: C.total, mc: r.vendas * mcVenda, recLiq: r.vendas * recVenda, contrib: r.vendas * mcVenda - r.verba - C.total, invest: r.verba + C.total };
}
const cor3c = (v, meta) => v == null || meta == null ? '' : Math.abs(v / meta - 1) <= 0.03 ? 'c-meta' : v < meta ? 'c-bad' : 'c-ok';

function passoDecidir(p, L) {
  const pl = planoDe(p), H = BC.historico(p.historico), FX = BC.historicoFaixas(p.historico), pctN = H.pctNovos * 100, base0 = c => BC.cenariosDoHistorico(p.historico, BC.verbaPeloCac(c, pl.meta, pctN), pl.meta, apiCusto(p), p.funil.elasticidade).base;
  const ops = [['historico', 'Histórico do produto', Math.round(H.cac), `média ponderada; variou de ${brl(FX.cac.min)} a ${brl(FX.cac.max)}`], ['alvo', 'Alvo do plano', Math.round(L.alvo.cac), 'o que as premissas do plano dão'], ['autorizado', 'Máximo que o negócio aguenta', Math.round(L.cacMaxAutorizado), 'teto: resultado, caixa, capacidade e orçamento'], ['manual', 'Outro valor', pl.fonte === 'manual' ? pl.cac : Math.round(H.cac), 'digite']];
  const mcV = BC.resultado(p, 1000).mcVenda, linha = ([k, nm, cac, sub]) => { const v = BC.verbaPeloCac(cac, pl.meta, pctN), e = econ(p, base0(cac)), naMeta = pl.meta * mcV - v - e.demais * (pl.meta / Math.max(1, e.r.vendas)); return `<tr class="${pl.fonte === k ? 'sel' : ''}"><td><label class="radio"><input type="radio" name="fonte" value="${k}" data-fonte ${pl.fonte === k ? 'checked' : ''}> ${nm}</label><span class="d">${sub}</span></td><td class="n">${k === 'manual' ? `<input type="number" step="5" value="${cac}" data-cacman> ` : brl(cac)}</td><td class="n">${brl(v)}</td><td class="n">${brl(e.invest)}</td><td class="n ${naMeta >= p.residualMinimo ? 'c-ok' : 'c-bad'}"><b>${brl(naMeta)}</b></td><td class="n">${nf(e.r.vendas, 1)}</td><td>${v > L.autorizado ? '<span class="st bad">passa do autorizado</span>' : e.invest > p.orcamentoDisponivel ? '<span class="st warn">passa do orçamento</span>' : '<span class="st ok">cabe</span>'}</td></tr>`; };
  const v = BC.verbaPeloCac(pl.cac, pl.meta, pctN);
  return `<p class="lead">Aqui você decide. Escolha o CAC que a campanha vai pagar: a verba sai dele (CAC × novos clientes da meta). Depois copie para os cenários pessimista, base e otimista do planejamento, ou ajuste à mão.</p>
  <div class="linha" style="margin-bottom:10px"><label class="campo">Meta de vendas<span><input type="number" step="1" value="${pl.meta}" data-plmeta></span></label><span class="peq muted">${pc(H.pctNovos)} das vendas são clientes novos (histórico): ${nf(pl.meta * H.pctNovos, 1)} novos para a meta.</span></div>
  <div class="tw"><table><thead><tr><th>De onde vem o CAC</th><th class="n">CAC de mídia</th><th class="n">Verba de mídia para a meta</th><th class="n">Investimento total</th><th class="n">Contribuição se bater a meta</th><th class="n">Vendas que essa verba traz (taxas do histórico)</th><th>Limites</th></tr></thead><tbody>${ops.map(linha).join('')}</tbody></table></div>
  <p class="peq muted">Contribuição se bater a meta: ${nf(pl.meta)} vendas × ${brl(mcV)} de margem por venda − verba − demais custos. Quanto menor o CAC, mais sobra na mesma meta. A última coluna mostra quantas vendas essa verba traria com as taxas médias das últimas campanhas, já com o CPL subindo quando a verba cresce. Mínimo exigido: ${brl(p.residualMinimo)}.</p>
  <div class="painel destaque"><div class="cards">${card('CAC escolhido', brl(pl.cac), ({ historico: 'do histórico do produto', alvo: 'do alvo do plano', autorizado: 'o máximo que o negócio aguenta', manual: 'valor digitado' })[pl.fonte])}${card('Verba de mídia', brl(v), `para ${nf(pl.meta)} vendas`)}${card('Cenários', pl.cens ? 'copiados' : 'ainda não', pl.cens ? 'ajuste em Distribuir por canal' : 'clique em copiar', pl.cens ? 'ok' : 'warn')}</div>
  <div class="linha" style="margin-top:10px"><button type="button" class="btn pri" data-copiar="todos">Copiar para pessimista, base e otimista</button><button type="button" class="btn" data-copiar="base">Copiar só para a base</button></div>
  <p class="peq muted" style="margin-top:6px">Copiar põe a mesma verba nos três cenários. As taxas de cada canal vêm do histórico: o pessimista usa a pior campanha, a base a média ponderada e o otimista a melhor. Copiar de novo sobrescreve o que você ajustou.</p></div>
  ${pl.cens ? resumoCens(p) : ''}`;
}
function resumoCens(p) {
  const pl = planoDe(p), E = Object.fromEntries(CENS.map(([k]) => [k, econ(p, pl.cens[k])])), lin = (n, f, cls) => `<tr><td>${n}</td>${CENS.map(([k]) => `<td class="n ${cls ? cls(E[k], k) : ''}">${f(E[k], k)}</td>`).join('')}</tr>`;
  return `<h3>Cenários do planejamento</h3><div class="tw"><table><thead><tr><th></th>${CENS.map(([, n]) => `<th class="n">${n}</th>`).join('')}</tr></thead><tbody>
    ${lin('Verba de mídia', e => brl(e.r.verba))}${lin('Leads', e => nf(e.r.leads))}${lin('Vendas', e => nf(e.r.vendas, 1), e => cor3c(e.r.vendas, pl.meta))}${lin('CAC de mídia', e => brl(e.r.cacMidia))}${lin('CPL dos pagos', e => brl(e.r.cpl, 2))}${lin('Orgânico para a meta', e => `${nf(e.r.orgParaMeta)} leads`)}${lin('Contribuição residual', e => brl(e.contrib), e => cor3c(e.contrib, p.residualMinimo))}</tbody></table></div>
  <p class="leg-cor"><span><i class="c" style="background:var(--bad)"></i>abaixo da meta</span><span><i class="c" style="background:var(--accent)"></i>na meta (±3%)</span><span><i class="c" style="background:var(--ok)"></i>acima</span></p>`;
}
function passoCanaisPl(p) {
  const pl = planoDe(p); if (!pl.cens) return `<p class="aviso warn">Escolha o CAC e copie para os cenários no passo anterior.</p>`;
  const k = pl.ativo, c = pl.cens[k], e = econ(p, c), r = e.r, HC = BC.historicoCanais(p.historico), fx = f => f ? `${brl(f.min, 2)} a ${brl(f.max, 2)}` : '—';
  const inp = (path, v, step = 'any') => `<input type="number" step="${step}" value="${Math.round(v * 100) / 100}" data-cen="${k}.${path}">`;
  return `<p class="lead">Distribua a verba entre os canais olhando o que cada um entregou. Mais leads orgânicos com a mesma verba baixam o CAC.</p>
  <div class="seg" role="group" aria-label="Cenário">${CENS.map(([kk, n]) => `<button type="button" data-ativo="${kk}" aria-pressed="${kk === k}">${n}</button>`).join('')}</div>
  <div class="linha" style="margin:10px 0"><label class="campo">Verba de mídia deste cenário<span>${inp('verba', c.verba, 100)} R$</span></label><label class="campo">Meta de vendas<span><b>${nf(pl.meta)}</b></span></label></div>
  ${HC.meta.semDado && HC.google.semDado ? '<p class="aviso info">O histórico não tem anúncios ligados por canal: o CPL de referência é o geral das últimas campanhas (mídia ÷ todos os leads). Divida entre Meta e Google pelo que você espera.</p>' : ''}
  <div class="tw"><table><thead><tr><th>Canal</th><th class="n">% da verba</th><th class="n">Verba</th><th class="n">CPL de referência</th><th class="n">CPL com esta verba</th><th class="n">CPL no histórico</th><th class="n">Leads no plano</th><th class="n">Leads por campanha no histórico</th></tr></thead><tbody>
    <tr><td>Meta Ads</td><td class="n">${inp('canais.meta.pct', c.canais.meta.pct, 1)} %</td><td class="n">${brl(r.pagos[0].verba)}</td><td class="n">${inp('canais.meta.cpl', c.canais.meta.cpl, 0.1)}</td><td class="n">${brl(r.pagos[0].cpl, 2)}</td><td class="n peq">${brl(HC.meta.cpl, 2)}<span class="d">${fx(HC.meta.faixaCpl)}</span></td><td class="n">${nf(r.pagos[0].leads)}</td><td class="n">${nf(HC.meta.leadsPorCampanha)}</td></tr>
    <tr><td>Google Ads</td><td class="n">${nf(c.canais.google.pct, 0)} %<span class="d">o que sobra</span></td><td class="n">${brl(r.pagos[1].verba)}</td><td class="n">${inp('canais.google.cpl', c.canais.google.cpl, 0.1)}</td><td class="n">${brl(r.pagos[1].cpl, 2)}</td><td class="n peq">${brl(HC.google.cpl, 2)}<span class="d">${fx(HC.google.faixaCpl)}</span></td><td class="n">${nf(r.pagos[1].leads)}</td><td class="n">${nf(HC.google.leadsPorCampanha)}</td></tr>
    <tr><td>Orgânico</td><td class="n">—</td><td class="n">—</td><td class="n muted">sem mídia</td><td class="n muted">—</td><td class="n muted">—</td><td class="n">${inp('canais.org.leads', c.canais.org.leads, 10)}</td><td class="n">${nf(HC.org.leadsPorCampanha)}</td></tr>
    <tr><td>WhatsApp API</td><td class="n">—</td><td class="n">${brl(r.custoApi)}<span class="d">${brl(c.canais.api.custoLead, 2)} por lead</span></td><td class="n muted">—</td><td class="n muted">—</td><td class="n peq">${brl(HC.api.cpl, 2)}</td><td class="n">${inp('canais.api.leads', c.canais.api.leads, 10)}</td><td class="n">${nf(HC.api.leadsPorCampanha)}</td></tr>
    <tr class="tot"><td>Total</td><td></td><td class="n">${brl(r.verba)}</td><td></td><td class="n">${brl(r.cpl, 2)}<span class="d">média dos pagos</span></td><td class="n peq">${brl(BC.historico(p.historico).cpl, 2)}</td><td class="n">${nf(r.leads)}</td><td class="n">${nf(p.historico.reduce((s, x) => s + x.leads, 0) / p.historico.length)}</td></tr></tbody></table></div>
  <div class="cards" style="margin-top:12px">${card('Leads para a meta', nf(r.leadsPrecisa), `${pc(r.vendasPorLead, 2)} dos leads viram venda`)}${card('Vendas previstas', nf(r.vendas, 1), `meta ${nf(pl.meta)}`, Math.abs(r.vendas / pl.meta - 1) <= .03 ? '' : r.vendas < pl.meta ? 'bad' : 'ok')}${card('CAC de mídia', brl(r.cacMidia), `escolhido ${brl(pl.cac)}`, r.cacMidia <= pl.cac * 1.03 ? 'ok' : 'bad')}${card('Contribuição residual', brl(e.contrib), `mínimo ${brl(p.residualMinimo)}`, e.contrib >= p.residualMinimo ? 'ok' : 'bad')}</div>
  ${r.faltaLeads > 0.5 ? `<p class="aviso warn">Faltam ${nf(r.faltaLeads)} leads para a meta neste cenário. Sem mais verba, o orgânico teria que trazer ${nf(r.orgParaMeta)} leads (histórico: ${nf(HC.org.leadsPorCampanha)} por campanha). Opções: ações orgânicas, mais API, CPL menor ou meta menor.</p>` : `<p class="aviso ok">Os leads planejados cobrem a meta neste cenário${r.leads > r.leadsPrecisa * 1.05 ? `, com ${nf(r.leads - r.leadsPrecisa)} de folga: dá para reduzir a verba` : ''}.</p>`}
  <p class="peq muted">CPL com esta verba = CPL de referência × (verba ÷ ${brl(c.verbaRef)}, a média histórica) ^ ${nf(c.elasticidade, 2)}: quanto mais verba, mais caro o lead. Conversão deste cenário: comparecimento ${pc(c.comparecimento / 100)}, presentes ${pc(c.convPresentes / 100)}, ausentes ${pc(c.convAusentes / 100, 2)}. Ajuste no Growth Model da campanha.</p>`;
}
function statusCampanha(p, L) {
  const pl = planoDe(p), M = BC.margem(p.produto), livre = livreAno(p), b = pl.cens && econ(p, pl.cens.base);
  const it = [['Estratégia escolhida', true, `${p.estrategia.nome} v${p.estrategia.versao}`], ['Margem do produto completa', M.completa, M.completa ? brl(M.mc, 2) + ' por venda' : 'faltam custos'], ['CAC escolhido e copiado para os cenários', !!pl.cens, pl.cens ? brl(pl.cac) : 'passo 9'],
    ['Verba distribuída por canal', !!(pl.cens && Math.abs(pl.cens.base.canais.meta.pct + pl.cens.base.canais.google.pct - 100) < 0.01), 'Meta, Google, orgânico e API'], ['Base atinge a meta', !!(b && b.r.vendas >= pl.meta * 0.97), b ? `${nf(b.r.vendas, 1)} de ${nf(pl.meta)} vendas` : '—'],
    ['Verba dentro do autorizado', !!(b && b.r.verba <= L.autorizado), b ? `${brl(b.r.verba)} de ${brl(L.autorizado)}` : '—'], ['Orçamento dentro do plano do ano', !!(b && b.invest <= livre), b ? `${brl(b.invest)} de ${brl(livre)} livres` : '—'], ['Business Case aprovado', ST.versoes.length > 0, ST.versoes.length ? 'v' + ST.versoes.length : 'aprovar abaixo']];
  const ok = it.filter(x => x[1]).length, st = ok === it.length ? ['ok', 'Pronta para começar'] : it.slice(0, -1).every(x => x[1]) ? ['warn', 'Pronta para aprovar'] : ['bad', 'Rascunho'];
  return `<div class="statusc"><span class="st ${st[0]}">${st[1]}</span> <span class="peq muted">${ok} de ${it.length} itens</span><ul class="chk">${it.map(([n, v, d]) => `<li class="${v ? 'ok' : 'no'}"><span aria-hidden="true">${v ? '✓' : '○'}</span> ${n}<span class="d">${d}</span></li>`).join('')}</ul></div>`;
}
function passoGM(p) {
  const pl = planoDe(p); if (!pl.cens) return `<p class="aviso warn">Escolha o CAC e copie para os cenários no passo 9.</p>`;
  const E = Object.fromEntries(CENS.map(([k]) => [k, econ(p, pl.cens[k])])), h = p.historico, H = BC.historico(h), HC = BC.historicoCanais(h), n = h.length, med = f => h.reduce((s, c) => s + f(c), 0) / n;
  const inp = (k, path, v, step = 'any', esc = 1) => `<input type="number" step="${step}" value="${Math.round(v * esc * 100) / 100}" data-cen="${k}.${path}">`;
  const row = (nm, f, hist, opts = {}) => `<tr class="${opts.cls || ''}"><td>${nm}</td>${CENS.map(([k]) => { const c = pl.cens[k], e = E[k]; return `<td class="n ${opts.cor ? opts.cor(e, k) : ''}">${f(c, e, k)}</td>`; }).join('')}<td class="n hcol">${hist}</td></tr>`;
  const grp = t => `<tr class="grp"><td colspan="5"><b>${t}</b></td></tr>`;
  return `<p class="lead">O funil da campanha, etapa por etapa, nos três cenários. Mude qualquer taxa ou volume: tudo recalcula.</p>
  ${pl.cens.base.semPresenca ? '<p class="aviso info">As campanhas do histórico não têm presença no evento registrada. Por isso o comparecimento está em 100% e a conversão dos presentes é a conversão direta de lead em venda. Quando a presença for registrada nas etapas da campanha, ela entra aqui.</p>' : ''}
  <div class="tw"><table class="gmc"><thead><tr><th>Etapa</th>${CENS.map(([, nm]) => `<th class="n">${nm}</th>`).join('')}<th class="n hcol">Média das ${n} últimas</th></tr></thead><tbody>
  ${grp('Captação')}
  ${row('Verba de mídia', (c, e, k) => inp(k, 'verba', c.verba, 100), brl(med(c => c.midia)))}
  ${row('Meta Ads: % da verba', (c, e, k) => inp(k, 'canais.meta.pct', c.canais.meta.pct, 1) + ' %', pc(HC.meta.custo / (HC.meta.custo + HC.google.custo), 0))}
  ${row('Meta Ads: CPL de referência', (c, e, k) => inp(k, 'canais.meta.cpl', c.canais.meta.cpl, 0.1), brl(HC.meta.cpl, 2))}
  ${row('Meta Ads: CPL com a verba', (c, e) => brl(e.r.pagos[0].cpl, 2), '')}
  ${row('Meta Ads: leads', (c, e) => nf(e.r.pagos[0].leads), nf(HC.meta.leadsPorCampanha))}
  ${row('Google Ads: CPL de referência', (c, e, k) => inp(k, 'canais.google.cpl', c.canais.google.cpl, 0.1), brl(HC.google.cpl, 2))}
  ${row('Google Ads: CPL com a verba', (c, e) => brl(e.r.pagos[1].cpl, 2), '')}
  ${row('Google Ads: leads', (c, e) => nf(e.r.pagos[1].leads), nf(HC.google.leadsPorCampanha))}
  ${row('Orgânico: leads', (c, e, k) => inp(k, 'canais.org.leads', c.canais.org.leads, 10), nf(HC.org.leadsPorCampanha))}
  ${row('WhatsApp API: leads', (c, e, k) => inp(k, 'canais.api.leads', c.canais.api.leads, 10), nf(HC.api.leadsPorCampanha))}
  ${row('Leads', (c, e) => nf(e.r.leads), nf(med(c => c.leads)), { cls: 'forte', cor: e => cor3c(e.r.leads, e.r.leadsPrecisa) })}
  ${grp('Evento')}
  ${row('Comparecimento', (c, e, k) => inp(k, 'comparecimento', c.comparecimento, 0.5) + ' %', pc(H.comparecimento))}
  ${row('Participantes', (c, e) => nf(e.r.part), nf(med(c => c.participantes)))}
  ${grp('Venda')}
  ${row('Conversão dos presentes', (c, e, k) => inp(k, 'convPresentes', c.convPresentes, 0.1) + ' %', pc(H.convPresentes))}
  ${row('Conversão dos ausentes', (c, e, k) => inp(k, 'convAusentes', c.convAusentes, 0.1) + ' %', pc(H.convAusentes, 2))}
  ${row('Vendas', (c, e) => nf(e.r.vendas, 1), nf(med(c => c.vendas), 1), { cls: 'forte', cor: e => cor3c(e.r.vendas, pl.meta) })}
  ${row('Compradores novos', (c, e, k) => inp(k, 'pctNovos', c.pctNovos, 1) + ' %', pc(H.pctNovos))}
  ${row('Novos clientes', (c, e) => nf(e.r.novos, 1), nf(med(c => c.novos), 1))}
  ${grp('Resultado')}
  ${row('Receita líquida', (c, e) => brl(e.recLiq), '')}
  ${row('Margem de contribuição', (c, e) => brl(e.mc), '')}
  ${row('Mídia', (c, e) => '− ' + brl(e.r.verba), brl(med(c => c.midia)))}
  ${row('Demais custos', (c, e) => '− ' + brl(e.demais), '')}
  ${row('Contribuição residual', (c, e) => brl(e.contrib), '', { cls: 'tot', cor: e => cor3c(e.contrib, p.residualMinimo) })}
  ${row('CPL dos pagos', (c, e) => brl(e.r.cpl, 2), brl(H.cpl, 2))}
  ${row('CAC de mídia', (c, e) => brl(e.r.cacMidia), brl(H.cac), { cor: e => e.r.cacMidia <= pl.cac * 1.03 ? 'c-ok' : 'c-bad' })}
  </tbody></table></div>
  <p class="leg-cor"><span><i class="c" style="background:var(--bad)"></i>abaixo da meta</span><span><i class="c" style="background:var(--accent)"></i>na meta (±3%)</span><span><i class="c" style="background:var(--ok)"></i>acima</span><span>Leads contra os leads que a meta pede; vendas contra a meta de ${nf(pl.meta)}; contribuição contra o mínimo de ${brl(p.residualMinimo)}; CAC contra o escolhido (${brl(pl.cac)}).</span></p>`;
}
