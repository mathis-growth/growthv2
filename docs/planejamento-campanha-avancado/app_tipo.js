/* ===== Tipo de campanha: objetivo estratégico × modelo de conversão (duas dimensões separadas) ===== */
const OBJETIVOS = [['captacao', 'Captação de leads', 'Formar base. A meta é em leads e o limite é o CPL.'], ['aquisicao', 'Aquisição de novos clientes', 'Vender para quem ainda não é cliente. A meta é em vendas e o limite é o CAC.'], ['rentabilizacao', 'Rentabilização da base', 'Vender de novo para quem já é cliente. Conta custo por venda, não CAC.'], ['expansao', 'Expansão de mercado', 'Novo público ou novo mercado. O histórico é de outro mercado: serve só de referência.']];
const MODELOS = {
  evento: { grupo: 'Evento', nome: 'Captação → Evento → Venda', sub: 'Leads vão para um evento (aula, live, webinário) e a venda acontece nele.', lead: 'Leads', etapa: 'Participantes', taxa1: 'Comparecimento', taxa2: 'Conversão dos presentes', taxa3: 'Conversão dos ausentes' },
  direta: { grupo: 'Página e checkout', nome: 'Anúncio → Página → Checkout', sub: 'O anúncio leva direto para a página de vendas.', lead: 'Visitas à página', etapa: 'Checkouts iniciados', taxa1: 'Visita → checkout', taxa2: 'Checkout → compra', taxa3: null },
  comercial: { grupo: 'Comercial', nome: 'Captação → Qualificação → Comercial → Venda', sub: 'Leads qualificados vão para uma conversa com o comercial.', lead: 'Leads', etapa: 'Reuniões com o comercial', taxa1: 'Lead → reunião', taxa2: 'Fechamento das reuniões', taxa3: null },
  recompra: { grupo: 'Oferta para a base', nome: 'Base de clientes → Oferta → Recompra', sub: 'Oferta para quem já comprou: upgrade, renovação, novo produto.', lead: 'Clientes abordados', etapa: 'Viram a oferta', taxa1: 'Abordados → viram a oferta', taxa2: 'Compra de quem viu', taxa3: null } };
const TIPO_PADRAO = { lancamento: 'evento', webinario: 'evento', captacao: 'evento', perpetuo: 'direta', comercial: 'comercial', recompra: 'recompra', assinatura: 'recompra', disparo: 'recompra' };
function tipoDe(p) {
  if (!ST.p.tipo) { const t = String((p.estrategia && (p.estrategia.tipo || p.estrategia.modelo)) || '').toLowerCase(), mod = TIPO_PADRAO[t] || (MODELOS[t] ? t : 'evento');
    ST.p.tipo = { objetivo: mod === 'recompra' ? 'rentabilizacao' : t === 'captacao' ? 'captacao' : 'aquisicao', modelo: mod, confirmado: false }; }
  return ST.p.tipo;
}
function termos(p) { const t = tipoDe(p), M = MODELOS[t.modelo] || MODELOS.evento, base = t.objetivo === 'rentabilizacao' || t.modelo === 'recompra';
  return { ...M, cac: base ? 'Custo por venda' : 'CAC de mídia', novos: base ? 'Vendas que contam' : 'Novos clientes', metaLeads: t.objetivo === 'captacao' }; }
// passo 1: os dois cartões vêm antes da estratégia
const passoEstrategia0 = passoEstrategia;
passoEstrategia = (p, L) => { const t = tipoDe(p);
  return `<h3 style="margin-top:0">Que tipo de campanha é esta?</h3><p class="peq muted">Objetivo e modelo são escolhas separadas. O modelo muda o funil e o cálculo; o objetivo muda o que é a meta.</p>
  <p class="rot">Objetivo estratégico</p><div class="tipos">${OBJETIVOS.map(([k, n, s]) => `<button type="button" class="tipo ${t.objetivo === k ? 'on' : ''}" data-tobj="${k}" aria-pressed="${t.objetivo === k}"><b>${n}</b><span>${s}</span></button>`).join('')}</div>
  <p class="rot">Modelo de conversão</p><div class="tipos">${Object.entries(MODELOS).map(([k, m]) => `<button type="button" class="tipo ${t.modelo === k ? 'on' : ''}" data-tmod="${k}" aria-pressed="${t.modelo === k}"><b>${m.nome}</b><span>${m.sub}</span></button>`).join('')}</div>
  ${t.confirmado ? '' : '<p class="aviso info">Sugerido pelo tipo da estratégia. Confira e clique no que for o caso.</p>'}
  <hr class="sep">` + passoEstrategia0(p, L); };
// histórico: aviso para expansão de mercado
const passoHistoricoT = passoHistorico;
passoHistorico = (p, L) => (tipoDe(p).objetivo === 'expansao' ? '<p class="aviso warn">Expansão de mercado: estas campanhas foram em outro mercado ou público. Use o histórico como referência, não como régua.</p>' : '') + passoHistoricoT(p, L);
// passo 9 quando o objetivo é captar leads: escolhe o CPL e a meta é em leads
const passoDecidirV = passoDecidir;
passoDecidir = (p, L) => { if (!termos(p).metaLeads) return troca(passoDecidirV(p, L), p);
  const pl = planoDe(p), H = BC.historico(p.historico), FX = BC.historicoFaixas(p.historico), med = p.historico.length ? p.historico.reduce((s, c) => s + (c.leads || 0), 0) / p.historico.length : 0;
  if (pl.metaLeads == null) pl.metaLeads = Math.round(med); if (pl.cplEsc == null) { pl.fonteCpl = 'historico'; pl.cplEsc = Math.round((H.cpl || 0) * 100) / 100; }
  const ops = [['historico', 'Histórico do produto', H.cpl, FX.cpl ? `variou de ${brl(FX.cpl.min, 2)} a ${brl(FX.cpl.max, 2)}` : ''], ['alvo', 'Alvo do plano', L.alvo.cpl, 'o que as premissas do plano dão'], ['autorizado', 'Máximo que o negócio aguenta', L.cplMaxAutorizado, 'teto pelo CAC máximo'], ['manual', 'Outro valor', pl.fonteCpl === 'manual' ? pl.cplEsc : H.cpl, 'digite']].filter(o => o[2] != null);
  const v = cpl => verbaLeads(p, pl, cpl);
  return `<p class="lead">O objetivo é captar leads: a meta é em leads e a verba sai do CPL (CPL × leads pagos que faltam depois do orgânico e da API).</p>
  <div class="linha" style="margin-bottom:10px"><label class="campo">Meta de leads<span><input type="number" step="50" value="${pl.metaLeads}" data-metaleads></span></label><span class="peq muted">Média das últimas campanhas: ${nf(med)} leads.</span></div>
  <div class="tw"><table><thead><tr><th>De onde vem o CPL</th><th class="n">CPL</th><th class="n">Verba para a meta</th><th>Limites</th></tr></thead><tbody>${ops.map(([k, nm, c, sub]) => `<tr class="${pl.fonteCpl === k ? 'sel' : ''}"><td><label class="radio"><input type="radio" name="fontecpl" value="${k}" data-fontecpl ${pl.fonteCpl === k ? 'checked' : ''}> ${nm}</label><span class="d">${sub}</span></td><td class="n">${k === 'manual' ? `<input type="number" step="0.5" value="${Math.round(c * 100) / 100}" data-cplman>` : brl(c, 2)}</td><td class="n">${brl(v(c))}</td><td>${L.autorizado != null && v(c) > L.autorizado ? '<span class="st bad">passa do autorizado</span>' : '<span class="st ok">cabe</span>'}</td></tr>`).join('')}</tbody></table></div>
  <div class="painel destaque"><div class="cards">${card('CPL escolhido', brl(pl.cplEsc, 2), '')}${card('Verba de mídia', brl(v(pl.cplEsc)), `para ${nf(pl.metaLeads)} leads`)}${card('Cenários', pl.cens ? 'copiados' : 'ainda não', '', pl.cens ? 'ok' : 'warn')}</div>
  <div class="linha" style="margin-top:10px"><button type="button" class="btn pri" data-copiar="todos">Copiar para pessimista, base e otimista</button><button type="button" class="btn" data-copiar="base">Copiar só para a base</button></div></div>
  ${pl.cens ? resumoCens(p) : ''}`; };
function verbaLeads(p, pl, cpl) { const S = BC.cenariosDoHistorico(p.historico, 1, null, apiCusto(p), 0).base; return Math.max(0, Math.round((pl.metaLeads - S.canais.org.leads - S.canais.api.leads) * (cpl || 0))); }
// verba escolhida no passo 9, pelo objetivo
function verbaEscolhida(p, pl) { const H = BC.historico(p.historico); return termos(p).metaLeads ? verbaLeads(p, pl, pl.cplEsc) : BC.verbaPeloCac(pl.cac, pl.meta, (tipoDe(p).modelo === 'recompra' || tipoDe(p).objetivo === 'rentabilizacao') ? 100 : H.pctNovos * 100); }
// depois de copiar: ajusta os cenários ao modelo (sem etapa de ausentes fora do evento; na base, toda venda conta)
function ajustaTipo(S, p) { const t = tipoDe(p), T = termos(p);
  Object.values(S).forEach(c => { if (t.modelo !== 'evento') { const comp = c.comparecimento / 100, vpl = comp * c.convPresentes / 100 + (1 - comp) * c.convAusentes / 100; c.convPresentes = comp > 0 ? Math.min(100, Math.round(vpl / comp * 10000) / 100) : 0; c.convAusentes = 0; }
    if (T.cac === 'Custo por venda') c.pctNovos = 100; if (T.metaLeads) c.meta = null; }); return S; }
// rótulos do funil e dos cartões nos passos 9, 10 e 13
const passoCanaisPlT = passoCanaisPl, passoGMT = passoGM, resumoCensT = resumoCens, statusCampanhaT = statusCampanha;
const troca = (html, p) => { const T = termos(p); let s = html;
  s = s.split('<b>Evento</b>').join('<b>' + T.grupo + '</b>');
  if (T.cac === 'Custo por venda') { s = s.split('De onde vem o CAC').join('De onde vem o custo por venda').split('Escolha o CAC que a campanha vai pagar: a verba sai dele (CAC × novos clientes da meta)').join('Escolha quanto a campanha pode pagar por venda: a verba sai dele (custo por venda × meta de vendas)').split('CAC escolhido').join('Custo por venda escolhido'); s = s.replace(/<span class="peq muted">[^<]*das vendas são clientes novos[^<]*<\/span>/, ''); }
  [['Conversão dos ausentes', T.taxa3 || ''], ['Conversão dos presentes', T.taxa2], ['Comparecimento', T.taxa1], ['Participantes', T.etapa], ['CAC de mídia', T.cac], ['Novos clientes', T.novos]].forEach(([a, b]) => { if (b !== a) s = s.split(a).join(b); });
  if (!T.taxa3) s = s.replace(/<tr class="[^"]*"><td><\/td>.*?<\/tr>/s, m => m); // linha vazia some abaixo
  return s; };
passoCanaisPl = p => troca(passoCanaisPlT(p), p);
resumoCens = p => troca(resumoCensT(p), p);
passoGM = p => { let s = troca(passoGMT(p), p); if (!termos(p).taxa3) s = s.replace(/<tr class=""><td><\/td>[\s\S]*?<\/tr>/, ''); return s; };
statusCampanha = (p, L) => { let s = statusCampanhaT(p, L); const pl = planoDe(p);
  if (termos(p).metaLeads && pl.cens) { const r = BC.planoCampanha(pl.cens.base), ok = r.leads >= pl.metaLeads * 0.97; s = s.replace(/<li class="(ok|no)"><span aria-hidden="true">.<\/span> Base atinge a meta<span class="d">[^<]*<\/span><\/li>/, `<li class="${ok ? 'ok' : 'no'}"><span aria-hidden="true">${ok ? '✓' : '○'}</span> Base atinge a meta de leads<span class="d">${nf(r.leads)} de ${nf(pl.metaLeads)} leads</span></li>`); }
  return s; };
document.addEventListener('click', e => { const b = e.target.closest('button'); if (!b) return; const t = tipoDe(ST.p);
  if (b.dataset.tobj) { t.objetivo = b.dataset.tobj; t.confirmado = true; } else if (b.dataset.tmod) { t.modelo = b.dataset.tmod; t.confirmado = true; } else return;
  if (ST.p.plan && ST.p.plan.cens) ST.p.plan.avisoTipo = true; salva(); render(); }, true);
document.addEventListener('change', e => { const el = e.target, n = Number(el.value), pl = ST.p.plan; if (!pl) return;
  if (el.hasAttribute('data-metaleads')) pl.metaLeads = n; else if (el.hasAttribute('data-fontecpl')) { const H = BC.historico(ST.p.historico), L = BC.limites(P()); pl.fonteCpl = el.value; if (el.value !== 'manual') pl.cplEsc = Math.round(({ historico: H.cpl, alvo: L.alvo.cpl, autorizado: L.cplMaxAutorizado })[el.value] * 100) / 100; }
  else if (el.hasAttribute('data-cplman')) { pl.fonteCpl = 'manual'; pl.cplEsc = n; } else return;
  e.stopImmediatePropagation(); salva(); render(); }, true);
