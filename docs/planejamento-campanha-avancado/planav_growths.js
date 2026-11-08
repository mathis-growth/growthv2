/* ================= v0.287 — Planejamento de campanha avançado (módulo em iframe; motor único com 67 testes) =================
   Lê: produtos, funis + estrategia_etapas, campanhas, v_marketing_campanha, v_trafego_anuncio_dia, campanha_etapas/valores (presentes),
   vendas (impostos, taxas, reembolso, ofertas), campanha_ofertas. Grava: campanha_calculos (premissas.modulo = 'planav'). Sem migration. */
async function planavDados(w) {
  const num = x => x == null ? 0 : Number(x) || 0, ign = () => [];
  const [prods, funis, etapas, camps, vmc, traf, cEt, vend, cOf, calcs] = await Promise.all([
    q(sb.from('produtos').select('id,nome,preco,taxa_percentual_override,taxa_fixa_override,ativo').eq('workspace_id', w).order('nome')),
    q(sb.from('funis').select('id,nome,objetivo,tipo,versao_atual,produto_id').eq('workspace_id', w).order('nome')).catch(ign),
    gcTodos(() => sb.from('estrategia_etapas').select('funil_id,ordem,nome').eq('workspace_id', w).order('ordem')).catch(ign),
    q(sb.from('campanhas').select('id,nome,produto_id,funil_id,status,data_inicio').eq('workspace_id', w)),
    q(sb.from('v_marketing_campanha').select('campanha_id,investimento,leads,vendas,clientes,faturamento').eq('workspace_id', w)).catch(ign),
    gcTodos(() => sb.from('v_trafego_anuncio_dia').select('campanha_id,canal,custo,leads,clientes').eq('workspace_id', w)).catch(ign),
    q(sb.from('campanha_etapas').select('id,campanha_id,chave').eq('workspace_id', w).ilike('chave', '%presentes%')).catch(ign),
    gcTodos(() => sb.from('vendas').select('produto_id,campanha_id,oferta_id,valor_bruto,taxa_plataforma,impostos,reembolsada_em,status').eq('workspace_id', w)).catch(ign),
    q(sb.from('campanha_ofertas').select('campanha_id,produto_id,oferta_id,nome,papel,preco,taxa_aceite,criado_em').eq('workspace_id', w).order('criado_em', { ascending: false })).catch(ign),
    q(sb.from('campanha_calculos').select('id,nome,premissas,atualizado_em').eq('workspace_id', w).eq('premissas->>modulo', 'planav').order('atualizado_em', { ascending: false })).catch(ign)]);
  const etIds = cEt.map(e => e.id), valEt = etIds.length ? await gcTodos(() => sb.from('campanha_etapa_valores').select('campanha_etapa_id,valor').in('campanha_etapa_id', etIds)).catch(ign) : [];
  // presentes por campanha: a maior soma entre as etapas de presença (aula 1, 2, 3…)
  const somaEt = {}; valEt.forEach(v => { somaEt[v.campanha_etapa_id] = (somaEt[v.campanha_etapa_id] || 0) + num(v.valor); });
  const presentes = {}; cEt.forEach(e => { const s = somaEt[e.id]; if (s > 0) presentes[e.campanha_id] = Math.max(presentes[e.campanha_id] || 0, s); });
  const mapaCanal = { meta_ads: 'meta', facebook_ads: 'meta', instagram_ads: 'meta', google_ads: 'google', tiktok_ads: 'tiktok' }, pago = {};
  traf.forEach(r => { const k = mapaCanal[r.canal]; if (!k || !r.campanha_id) return; const o = ((pago[r.campanha_id] = pago[r.campanha_id] || {})[k] = pago[r.campanha_id][k] || { midia: 0, leads: 0, novos: 0 }); o.midia += num(r.custo); o.leads += num(r.leads); o.novos += num(r.clientes); });
  const ofPorId = {}; cOf.forEach(o => { if (o.oferta_id) ofPorId[o.campanha_id + '|' + o.oferta_id] = o.papel; });
  const vOf = {}; vend.forEach(v => { const p = v.campanha_id && v.oferta_id && ofPorId[v.campanha_id + '|' + v.oferta_id]; if (p && p !== 'principal') { const o = (vOf[v.campanha_id] = vOf[v.campanha_id] || {}); o[p] = (o[p] || 0) + 1; } });
  const M = {}; vmc.forEach(r => { M[r.campanha_id] = r; });
  const campanhas = camps.map(c => { const r = M[c.id] || {}, pg = pago[c.id] || {}, leads = num(r.leads), novos = r.clientes == null ? num(r.vendas) : num(r.clientes);
    const z = { midia: 0, leads: 0, novos: 0 }, meta = pg.meta || z, google = pg.google || z, tiktok = pg.tiktok || z, pl = meta.leads + google.leads + tiktok.leads, pn = meta.novos + google.novos + tiktok.novos;
    const part = presentes[c.id] || null, o = vOf[c.id] || {}, vendas = num(r.vendas);
    return { id: c.id, nome: c.nome, produto_id: c.produto_id, funil_id: c.funil_id, status: c.status, data_inicio: c.data_inicio, periodo: c.data_inicio ? String(c.data_inicio).slice(0, 7) : '', oferta: '—', ticket: vendas ? num(r.faturamento) / vendas : null,
      midia: num(r.investimento), leads, inscritos: part ? leads : null, participantes: part, vendasPresentes: null, vendas, novos, receita: num(r.faturamento),
      canais: pl > 0 ? { meta, google, tiktok, org: { leads: Math.max(0, leads - pl), novos: Math.max(0, novos - pn) }, api: { leads: 0, custo: 0, novos: 0 } } : null, // sem anúncios ligados: canal desconhecido, CPL sobre todos os leads
      ofertas: { bump: o.order_bump ? { vendas: o.order_bump } : null, upsell: o.upsell ? { vendas: o.upsell } : null, downsell: null } }; });
  // impostos, taxa da plataforma e reembolso de cada produto: das vendas reais
  const ag = {}; vend.forEach(v => { if (!v.produto_id) return; const a = (ag[v.produto_id] = ag[v.produto_id] || { b: 0, t: 0, i: 0, n: 0, r: 0 }); a.b += num(v.valor_bruto); a.t += num(v.taxa_plataforma); a.i += num(v.impostos); a.n++; if (v.reembolsada_em) a.r++; });
  const produtos = prods.filter(p => p.ativo !== false).map(p => { const a = ag[p.id];
    return { id: p.id, nome: p.nome, preco: num(p.preco), taxaPct: a && a.b > 0 && a.t > 0 ? a.t / a.b * 100 : (p.taxa_percentual_override != null ? num(p.taxa_percentual_override) : null), taxaFixa: num(p.taxa_fixa_override),
      impostoPct: a && a.b > 0 && a.i > 0 ? a.i / a.b * 100 : null, reembolsoPct: a && a.n >= 10 ? a.r / a.n * 100 : null }; });
  const etPorFunil = {}; etapas.forEach(e => { (etPorFunil[e.funil_id] = etPorFunil[e.funil_id] || []).push(e.nome); });
  const ofertas = []; const visto = {}; cOf.forEach(o => { const k = o.produto_id + '|' + o.papel; if (visto[k] || o.papel === 'principal') return; visto[k] = 1; ofertas.push({ produto_id: o.produto_id, papel: o.papel, nome: o.nome, preco: num(o.preco), taxa_aceite: o.taxa_aceite == null ? null : num(o.taxa_aceite) }); });
  return { ws: w, produtos, funis: funis.map(f => ({ ...f, etapas: etPorFunil[f.id] || [] })), campanhas, ofertas, rascunhos: calcs };
}
let PLANAV_MSG = null;
async function vPlanav(m) {
  const w = S.ws;
  m.innerHTML = `<div class="head"><div><h1>Planejamento de campanha avançado</h1><span class="muted">Da estratégia ao Growth Model da campanha: histórico do produto, margem, limites, CAC, cenários e canais. O planejamento atual de Campanhas continua igual.</span></div></div><div class="muted" id="pvCarrega">Carregando os dados deste cliente…</div><iframe id="pvFrame" title="Planejamento de campanha avançado" style="width:100%;border:0;min-height:900px;display:block;background:transparent"></iframe>`;
  const D = await planavDados(w), fr = m.querySelector('#pvFrame');
  m.querySelector('#pvCarrega').remove();
  const dados = JSON.stringify(D).replace(/</g, '\\u003c');
  fr.srcdoc = PLANAV_HTML.replace('<script>', '<script>window.DADOS = ' + dados + ';<\/script><script>');
  if (PLANAV_MSG) window.removeEventListener('message', PLANAV_MSG);
  PLANAV_MSG = async e => { if (!fr.isConnected || e.source !== fr.contentWindow) return; const d = e.data || {};
    if (d.tipo === 'planav-altura') fr.style.height = Math.max(900, d.h + 20) + 'px';
    else if (d.tipo === 'planav-topo') fr.scrollIntoView({ block: 'start' });
    else if (d.tipo === 'planav-salvar') {
      if (!d.premissas || d.premissas.modulo !== 'planav') return;
      try { let id = d.id;
        if (id) await q(sb.from('campanha_calculos').update({ nome: String(d.nome || '').slice(0, 200), premissas: d.premissas, atualizado_em: new Date().toISOString() }).eq('id', id).eq('workspace_id', w));
        else { const r = await q(sb.from('campanha_calculos').insert({ workspace_id: w, campanha_id: null, nome: String(d.nome || '').slice(0, 200), premissas: d.premissas }).select('id').single()); id = r.id; }
        fr.contentWindow.postMessage({ tipo: 'planav-salvo', id }, '*');
      } catch (err) { fr.contentWindow.postMessage({ tipo: 'planav-salvo', id: d.id, erro: err.message || String(err) }, '*'); }
    } };
  window.addEventListener('message', PLANAV_MSG);
}
VIEWS['mkt-planav'] = vPlanav;
