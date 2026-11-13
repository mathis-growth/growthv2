/* ===== Modo Growths: dados reais do workspace (window.DADOS), salvo em campanha_calculos pelo Growths ===== */
const REAL = typeof window !== 'undefined' && !!window.DADOS;
if (REAL) {
  const D = window.DADOS, PREM = (v, o) => v == null || !isFinite(v) ? undefined : { v: Math.round(v * 100) / 100, origem: o };
  const histDe = (prodId, funilId, soEstr) => D.campanhas.filter(c => c.produto_id === prodId && (c.leads > 0 || c.midia > 0) && (!soEstr || c.funil_id === funilId))
    .sort((a, b) => String(b.data_inicio || '').localeCompare(String(a.data_inicio || '')));
  const montaP = (prodId, funilId, soEstr) => {
    const pr = D.produtos.find(x => x.id === prodId) || D.produtos[0] || { nome: '—', preco: 0 }, fu = D.funis.find(x => x.id === funilId) || { nome: 'Sem estratégia', etapas: [] };
    const h = histDe(pr.id, fu.id, soEstr), H = BC.historico(h), HC = BC.historicoCanais(h), med = k => h.length ? h.reduce((s, c) => s + (c[k] || 0), 0) / h.length : null;
    const trib = pr.impostoPct, taxa = pr.taxaPct, of = papel => (D.ofertas || []).filter(o => o.produto_id === pr.id && o.papel === papel)[0], HO = BC.historicoOfertas(h);
    const ofx = (papel, k) => { const o = of(papel); if (!o) return { tem: false }; const liq = o.preco * (1 - ((trib || 0) + (taxa || 0)) / 100), ac = o.taxa_aceite != null ? o.taxa_aceite : HO[k] ? HO[k].aceite * 100 : 0; return { tem: true, nome: o.nome, preco: o.preco, aceite: Math.round(ac * 10) / 10, recLiqUnit: liq, mcUnit: liq }; };
    const semP = H.convPresentes == null, cpl = H.cpl || 10;
    return { nome: `${pr.nome} · ${fu.nome}`, produto_id: pr.id, funil_id: fu.id || null, soEstrategia: !!soEstr,
      estrategia: { id: fu.id, nome: fu.nome, versao: fu.versao_atual || 1, objetivo: fu.objetivo || 'não informado', modelo: fu.tipo || 'não informado', etapas: fu.etapas || [] },
      produto: { nome: pr.nome, preco: PREM(pr.preco, 'real_conc'), desconto: { v: 0, origem: 'usuario' }, tributos: PREM(trib, 'real_conc'), taxaPlataforma: PREM(taxa, 'real_conc'), taxaTransacao: PREM(pr.taxaFixa || 0, pr.taxaFixa ? 'real_conc' : 'premissa'),
        comissao: { v: 0, origem: 'premissa' }, reembolso: PREM(pr.reembolsoPct, 'real_conc'), chargeback: { v: 0, origem: 'premissa' }, inadimplencia: { v: 0, origem: 'premissa' } },
      ofertas: { bump: ofx('order_bump', 'bump'), upsell: ofx('upsell', 'upsell') },
      funil: { cpm: cpl * 10, ctr: 1, cliqueVisita: 100, convPagina: 100, inscricao: null, comparecimento: semP ? 100 : (H.comparecimento || 0) * 100, convPresentes: (semP ? H.vendasPorLead || 0 : H.convPresentes) * 100, convAusentes: semP ? 0 : (H.convAusentes || 0) * 100, pctNovos: H.pctNovos != null ? Math.min(100, H.pctNovos * 100) : 100, elasticidade: 0.6, verbaRef: med('midia') || 10000 },
      canais: [{ nome: 'Mídia paga', tipo: 'pago' }, { nome: 'Orgânico', tipo: 'org', leads: Math.round((HC.org && HC.org.leadsPorCampanha) || 0) }, { nome: 'WhatsApp API', tipo: 'api', leads: 0, custoLead: 0 }],
      recursos: [], plano: { orcamentoAquisicaoAno: null, realizadoAquisicao: null, comprometidoAquisicao: null, contribuicaoProdutoAno: null, realizadoAteAgosto: null, campanhasComprometidas: null },
      residualMinimo: 0, metaVendas: Math.round(med('vendas') || 0), verbaPlanejada: Math.round(med('midia') || 0), capacidadeVendas: null, orcamentoDisponivel: null, tetoBusca: 500000,
      caixa: { saldo: null, reserva: 0, pctParcelado: 0, parcelas: 1, antecipar: false, taxaAntecipacao: 0, repasseDias: 30, programados: [] },
      datas: { capA: 0, capB: 20, live: 23, carA: 24, carB: 30, inicio: null }, ltv: null, historico: h };
  };
  // estado inicial: o último rascunho salvo, ou o produto com mais campanhas
  const temHist = id => D.campanhas.filter(c => c.produto_id === id && c.leads > 0).length;
  const abre = (prodId, funilId, soEstr) => {
    const rs = (D.rascunhos || []).find(r => r.premissas && r.premissas.produto_id === prodId && (r.premissas.funil_id || null) === (funilId || null));
    const novo = montaP(prodId, funilId, soEstr);
    if (rs && rs.premissas.p) { const sp = rs.premissas.p; sp.historico = novo.historico; sp.soEstrategia = !!soEstr; ST.p = sp; ST.versoes = rs.premissas.versoes || []; ST.semMargem = false; ST.calcId = rs.id; }
    else { ST.p = novo; ST.versoes = []; ST.semMargem = false; ST.calcId = null; }
    ST.testes = null;
  };
  const prodIni = (D.rascunhos && D.rascunhos[0] && D.rascunhos[0].premissas.produto_id) || (D.produtos.slice().sort((a, b) => temHist(b.id) - temHist(a.id))[0] || {}).id;
  const funilMaisUsado = prodId => { const n = {}; D.campanhas.filter(c => c.produto_id === prodId && c.funil_id && c.leads > 0).forEach(c => { n[c.funil_id] = (n[c.funil_id] || 0) + 1; }); const k = Object.keys(n).sort((a, b) => n[b] - n[a])[0]; return k || ((D.campanhas.find(c => c.produto_id === prodId && c.funil_id) || {}).funil_id) || null; };
  const funilIni = (D.rascunhos && D.rascunhos[0] && D.rascunhos[0].premissas.funil_id) || funilMaisUsado(prodIni);
  ST.passo = 0; ST.hoje = 12; ST.fat = JSON.parse(JSON.stringify(BC.FATORES));
  abre(prodIni, funilIni, true); if (ST.p.historico.length < 2) abre(prodIni, funilIni, false);
  // salvar: o Growths grava em campanha_calculos
  let tSalva = null;
  salva = () => { clearTimeout(tSalva); tSalva = setTimeout(() => { const p = JSON.parse(JSON.stringify(ST.p)); delete p.historico;
    parent.postMessage({ tipo: 'planav-salvar', id: ST.calcId || null, nome: `Planejamento avançado · ${ST.p.nome}`, premissas: { modulo: 'planav', produto_id: ST.p.produto_id, funil_id: ST.p.funil_id, p, versoes: ST.versoes } }, '*'); }, 1200); };
  window.addEventListener('message', e => { const m = e.data || {}; if (m.tipo === 'planav-salvo' && !m.alvo) { ST.calcId = m.id; ST.salvoTxt = m.erro ? 'Não salvou: ' + m.erro : '✓ Rascunho salvo às ' + new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }); const el = document.getElementById('salvoEm'); if (el) { el.textContent = ST.salvoTxt; el.style.color = m.erro ? 'var(--bad)' : ''; } } });
  // altura do iframe acompanha a página
  const ro = new ResizeObserver(() => parent.postMessage({ tipo: 'planav-altura', h: document.documentElement.scrollHeight }, '*')); ro.observe(document.body);
  window.scrollTo = () => parent.postMessage({ tipo: 'planav-topo' }, '*');
  // passos 1 e 2 com seletores reais
  const opt = (v, n, sel) => `<option value="${v || ''}" ${sel ? 'selected' : ''}>${n}</option>`, esc2 = t => String(t == null ? '' : t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  passoEstrategia = p => { const usados = new Set(D.campanhas.filter(c => c.produto_id === p.produto_id).map(c => c.funil_id)), fs = D.funis.slice().sort((a, b) => (usados.has(b.id) ? 1 : 0) - (usados.has(a.id) ? 1 : 0) || a.nome.localeCompare(b.nome));
    return `<p class="lead">A campanha parte de uma estratégia cadastrada no Growths. As etapas vêm da versão publicada dela.</p>
    <div class="campos"><label class="campo">Estratégia<select data-selfunil>${opt('', 'Sem estratégia', !p.funil_id)}${fs.map(f => opt(f.id, esc2(f.nome) + (usados.has(f.id) ? ' · já usada com este produto' : ''), f.id === p.funil_id)).join('')}</select></label>
    <label class="campo">Produto<select data-selprod>${D.produtos.map(x => opt(x.id, esc2(x.nome) + ` · ${temHist(x.id)} campanhas`, x.id === p.produto_id)).join('')}</select></label></div>
    <div class="cards2" style="margin-top:12px"><article class="est sel"><h3>${esc2(p.estrategia.nome)}</h3><dl><dt>Objetivo</dt><dd>${esc2(p.estrategia.objetivo)}</dd><dt>Modelo</dt><dd>${esc2(p.estrategia.modelo)}</dd><dt>Versão</dt><dd>v${p.estrategia.versao}</dd></dl></article></div>
    ${p.estrategia.etapas.length ? `<h3>Etapas da jornada</h3><ol class="jorn">${p.estrategia.etapas.map(e => `<li>${esc2(e)}</li>`).join('')}</ol>` : '<p class="muted">Esta estratégia não tem etapas cadastradas.</p>'}
    <p class="peq muted">Trocar a estratégia ou o produto abre o planejamento salvo dessa combinação, ou começa um novo a partir do histórico.</p>`; };
  const passoProduto0 = passoProduto;
  passoProduto = (p, L) => `<div class="campos" style="margin-bottom:12px"><label class="campo">Produto<select data-selprod>${D.produtos.map(x => opt(x.id, esc2(x.nome), x.id === p.produto_id)).join('')}</select></label></div>` + passoProduto0(p, L);
  const passoHistorico0 = passoHistorico;
  passoHistorico = (p, L) => `<label class="ck"><input type="checkbox" data-soestr ${p.soEstrategia ? 'checked' : ''}> Só campanhas desta estratégia (${esc2(p.estrategia.nome)})</label>` +
    (p.historico.length ? passoHistorico0(p, L) + (BC.historico(p.historico).convPresentes == null ? '<p class="aviso info">Estas campanhas não têm presença no evento registrada. A conversão usada é direta: vendas ÷ leads.</p>' : '') : '<p class="aviso warn">Nenhuma campanha deste produto com leads ou mídia. Desmarque "só desta estratégia" ou planeje sem histórico, preenchendo as premissas à mão.</p>');
  passoCockpit = () => '<p class="aviso info">O cockpit acompanha a campanha depois que ela for criada a partir deste planejamento. Nesta versão, use o painel da campanha em Campanhas e planejamento.</p>';
  document.addEventListener('change', e => { const el = e.target;
    if (el.matches('[data-selprod]')) { const f = funilMaisUsado(el.value); abre(el.value, f, true); if (ST.p.historico.length < 2) abre(el.value, f, false); render(); }
    else if (el.matches('[data-selfunil]')) { abre(ST.p.produto_id, el.value || null, true); if (ST.p.historico.length < 2) abre(ST.p.produto_id, el.value || null, false); render(); }
    else if (el.matches('[data-soestr]')) { const sp = ST.p, n = montaP(sp.produto_id, sp.funil_id, el.checked); sp.historico = n.historico; sp.soEstrategia = el.checked; render(); }
  }, true);
  const hdr = document.querySelector('header'); if (hdr) hdr.remove(); document.documentElement.classList.add('growths');
  REAL_TITULO = () => ST.p && ST.p.nome ? ST.p.nome : 'Planejamento de campanha avançado';
}
