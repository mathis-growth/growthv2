/* Growths — motor do Business Case de campanha (fase 1, protótipo isolado).
   Funções puras: recebem premissas, devolvem números, limites, alertas e a origem de cada valor.
   Roda no navegador e no Node (testes). Nenhuma chamada a banco ou rede. */
(function (raiz) {
  'use strict';
  const ORIGENS = { real_conc: 'Real conciliado', real_nconc: 'Real não conciliado', usuario: 'Informado pelo usuário', historico: 'Estimativa histórica', premissa: 'Premissa simulada' };
  const num = v => (v == null || v === '' || !isFinite(Number(v))) ? null : Number(v);
  const div = (a, b) => (a == null || b == null || !isFinite(a) || !isFinite(b) || b === 0) ? null : a / b;
  const r2 = v => v == null ? null : Math.round(v * 100) / 100;
  const val = c => c && typeof c === 'object' && 'v' in c ? num(c.v) : num(c); // um campo pode vir como { v, origem }
  const org = c => c && typeof c === 'object' && 'origem' in c ? c.origem : null;

  /* ---------- validação de premissas: taxas de 0 a 100%, custos não negativos, nulos sinalizados ---------- */
  function valida(p) {
    const erros = [], avisos = [], taxa = (nome, v, obrig) => { if (v == null) { if (obrig) erros.push({ campo: nome, msg: 'sem valor' }); return; } if (v < 0 || v > 100) erros.push({ campo: nome, msg: 'taxa fora de 0% a 100%' }); };
    const custo = (nome, v) => { if (v != null && v < 0) erros.push({ campo: nome, msg: 'custo negativo' }); };
    const pr = p.produto || {};
    if (!(val(pr.preco) > 0)) erros.push({ campo: 'produto.preco', msg: 'preço precisa ser maior que zero' });
    ['desconto', 'tributos', 'taxaPlataforma', 'comissao', 'reembolso', 'chargeback', 'inadimplencia'].forEach(k => taxa('produto.' + k, val(pr[k]), false));
    ['taxaTransacao', 'entrega', 'suporte', 'infra'].forEach(k => custo('produto.' + k, val(pr[k])));
    const f = p.funil || {};
    ['ctr', 'cliqueVisita', 'convPagina', 'inscricao', 'comparecimento', 'convPresentes', 'convAusentes', 'pctNovos'].forEach(k => taxa('funil.' + k, val(f[k]), false));
    (p.recursos || []).forEach((r, i) => custo(`recursos[${i}].valor`, val(r.valor)));
    return { ok: !erros.length, erros, avisos };
  }

  /* ---------- 1. margem de contribuição unitária antes da aquisição ---------- */
  // receita líquida unitária: preço − desconto − tributos − taxas da plataforma − taxa fixa de transação − comissões − perdas (reembolso, chargeback, inadimplência)
  // custos variáveis não ligados à aquisição: entrega, suporte incremental, infraestrutura por venda
  // um campo sem valor NÃO vira zero: entra em `faltando` e a margem fica marcada como incompleta
  function margem(produto) {
    const pr = produto || {}, faltando = [], campos = ['preco', 'desconto', 'tributos', 'taxaPlataforma', 'taxaTransacao', 'comissao', 'reembolso', 'chargeback', 'inadimplencia', 'entrega', 'suporte', 'infra'];
    const v = {}; campos.forEach(k => { v[k] = val(pr[k]); if (v[k] == null) faltando.push(k); });
    const z = k => v[k] == null ? 0 : v[k];
    const precoLiq = z('preco') * (1 - z('desconto') / 100);                          // preço depois do desconto
    const perdas = precoLiq * (z('reembolso') + z('chargeback') + z('inadimplencia')) / 100; // o que volta ou não entra
    const tributos = (precoLiq - perdas) * z('tributos') / 100;                         // tributo sobre o que fica
    const plataforma = (precoLiq - perdas) * z('taxaPlataforma') / 100 + z('taxaTransacao');
    const comissao = (precoLiq - perdas) * z('comissao') / 100;
    const receitaLiquida = precoLiq - perdas - tributos - plataforma - comissao;
    const variaveis = z('entrega') + z('suporte') + z('infra');
    const mc = receitaLiquida - variaveis;
    const origem = {}; campos.forEach(k => origem[k] = org(pr[k]) || (v[k] == null ? null : 'usuario'));
    const estimados = campos.filter(k => ['historico', 'premissa'].includes(origem[k]));
    return { precoLiq, perdas, tributos, plataforma, comissao, receitaLiquida, variaveis, mc, mcPct: div(mc, receitaLiquida), faltando, completa: !faltando.length, estimados, origem };
  }

  /* ---------- 2. funil Captação → Evento → Venda, a partir da verba de mídia ---------- */
  // verba → impressões (CPM) → cliques (CTR) → visitas → leads pagos; + leads dos canais sem mídia
  // leads → inscritos (opcional) → participantes; compras = participantes × conv. presentes + ausentes × conv. ausentes (grupos que não se sobrepõem)
  // rendimento decrescente: o CPM sobe quando a verba passa da referência (elasticidade)
  function funil(p, verba) {
    const f = p.funil || {}, t = k => (val(f[k]) == null ? null : val(f[k]) / 100);
    const ref = val(f.verbaRef) || verba || 1, el = val(f.elasticidade) || 0;
    const cpm = val(f.cpm) * Math.pow(Math.max(verba, 1) / ref, el);
    const imp = verba > 0 && cpm > 0 ? verba / cpm * 1000 : 0, cliques = imp * (t('ctr') || 0), visitas = cliques * (t('cliqueVisita') == null ? 1 : t('cliqueVisita'));
    const leadsPagos = visitas * (t('convPagina') || 0), leadsOrg = (p.canais || []).filter(c => c.tipo !== 'pago').reduce((s, c) => s + (val(c.leads) || 0), 0);
    const leads = leadsPagos + leadsOrg, inscritos = leads * (t('inscricao') == null ? 1 : t('inscricao')), part = inscritos * (t('comparecimento') || 0), aus = inscritos - part;
    const vPres = part * (t('convPresentes') || 0), vAus = aus * (t('convAusentes') || 0), vendas = vPres + vAus, novos = vendas * (t('pctNovos') == null ? 1 : t('pctNovos'));
    return { verba, cpm, imp, cliques, visitas, leadsPagos, leadsOrg, leads, inscritos, part, aus, vPres, vAus, vendas, novos, convLeadNovo: div(novos, leads) };
  }

  /* ---------- 3. custos da campanha fora a mídia, classificados ---------- */
  // tipos: disp_sem (já existe, sem desembolso), disp_aloc (já existe, mas precisa alocar: entra como custo de alocação),
  // fixo (incremental fixo), var_lead (por lead), var_venda (por venda), capacidade (investimento em nova capacidade)
  function custos(p, F) {
    // r.usar === false: recurso fora desta campanha (custo zero, não some da lista). r.unidade === 'pct' (só por venda): % do valor de cada venda
    const precoVenda = (val(p.produto && p.produto.preco) || 0) * (1 - (val(p.produto && p.produto.desconto) || 0) / 100);
    const linhas = (p.recursos || []).map(r => { const pct = r.tipo === 'var_venda' && r.unidade === 'pct', v = pct ? (val(r.valor) || 0) / 100 * precoVenda : (val(r.valor) || 0), q = r.tipo === 'var_lead' ? F.leads : r.tipo === 'var_venda' ? F.vendas : 1;
      const total = r.usar === false || r.tipo === 'disp_sem' ? 0 : v * q, caixa = ['fixo', 'var_lead', 'var_venda', 'capacidade'].includes(r.tipo); // alocação de quem já é pago não sai do caixa de novo
      return { ...r, valor: v, valorInformado: val(r.valor), qtd: q, total, desembolso: caixa ? total : 0 }; });
    const api = (p.canais || []).filter(c => c.tipo === 'api').reduce((s, c) => s + (val(c.leads) || 0) * (val(c.custoLead) || 0), 0);
    if (api) linhas.push({ nome: 'Disparos da API (por lead)', tipo: 'var_lead', valor: null, qtd: null, total: api, desembolso: api });
    const total = linhas.reduce((s, x) => s + x.total, 0), desembolso = linhas.reduce((s, x) => s + x.desembolso, 0);
    const semCapacidade = (p.recursos || []).filter(r => r.usar !== false && r.capacidade != null && val(r.capacidade) < (r.tipo === 'var_venda' ? F.vendas : r.tipo === 'var_lead' ? F.leads : 0));
    return { linhas, total, desembolso, semCapacidade };
  }

  /* ---------- 4. resultado da campanha para uma verba ---------- */
  function resultado(p, verba) {
    const M = margem(p.produto), F = funil(p, verba), C = custos(p, F), o = p.ofertas || {};
    const ticketExtra = ['bump', 'upsell'].reduce((s, k) => s + (o[k] && o[k].tem ? (val(o[k].aceite) || 0) / 100 * (val(o[k].mcUnit) == null ? 0 : val(o[k].mcUnit)) : 0), 0);
    const mcVenda = M.mc + ticketExtra, mcTotal = F.vendas * mcVenda; // contribuição projetada antes da aquisição
    const recLiq = F.vendas * (M.receitaLiquida + ['bump', 'upsell'].reduce((s, k) => s + (o[k] && o[k].tem ? (val(o[k].aceite) || 0) / 100 * (val(o[k].recLiqUnit) || 0) : 0), 0));
    const investimento = verba + C.total, residual = mcTotal - investimento; // contribuição que sobra depois de pagar a campanha (não é lucro líquido)
    return { M, F, C, verba, mcVenda, mcTotal, recLiq, investimento, residual, cacMidia: div(verba, F.novos), cacTotal: div(investimento, F.novos), cpl: div(verba, F.leadsPagos), cplTotal: div(verba + C.total, F.leads), cpa: div(verba, F.vendas), roas: div(F.vendas * (val(p.produto.preco) || 0), verba), roasEquilibrio: div(val(p.produto.preco) || 0, mcVenda) };
  }

  /* ---------- busca numérica (bisseção) com checagem de convergência ---------- */
  function bissecao(fn, lo, hi, tol = 1, maxIt = 80) {
    let flo = fn(lo), fhi = fn(hi), it = 0;
    if (flo == null || fhi == null) return { x: null, convergiu: false, it, motivo: 'função sem valor' };
    if (flo < 0) return { x: null, convergiu: false, it, motivo: 'nem com verba mínima o limite é atendido' };
    if (fhi >= 0) return { x: hi, convergiu: true, it, motivo: 'limite acima do teto de busca' };
    while (hi - lo > tol && it < maxIt) { const mid = (lo + hi) / 2, fm = fn(mid); if (fm >= 0) lo = mid; else hi = mid; it++; }
    return { x: lo, convergiu: hi - lo <= tol, it, motivo: hi - lo <= tol ? null : 'não convergiu' };
  }

  // verba que deixa a maior contribuição residual (busca em grade e depois refina por seção áurea)
  function picoResidual(p, teto) {
    let melhor = 0, vm = -Infinity; const passos = 60;
    for (let i = 0; i <= passos; i++) { const x = teto * i / passos, v = resultado(p, x).residual; if (v > vm) { vm = v; melhor = x; } }
    let a = Math.max(0, melhor - teto / passos), b = Math.min(teto, melhor + teto / passos); const g = (Math.sqrt(5) - 1) / 2;
    for (let i = 0; i < 40 && b - a > 1; i++) { const c = b - g * (b - a), d = a + g * (b - a); if (resultado(p, c).residual >= resultado(p, d).residual) b = d; else a = c; }
    const x = (a + b) / 2; return { x, residual: resultado(p, x).residual };
  }

  /* ---------- 5. caixa dia a dia ---------- */
  // saídas: mídia espalhada nos dias de captação, custos fixos no início, variáveis por lead na captação e por venda no carrinho
  // entradas: vendas no carrinho; à vista entra após o repasse; parcelado entra em parcelas mensais, ou tudo antecipado com taxa
  function caixa(p, verba) {
    const R = resultado(p, verba), cx = p.caixa || {}, d = p.datas || { capA: 0, capB: 20, carA: 26, carB: 32 }, n = Math.max(d.carB + 400, 60), fluxo = new Float64Array(n + 1);
    const capDias = d.capB - d.capA + 1, carDias = d.carB - d.carA + 1;
    for (let i = d.capA; i <= d.capB; i++) fluxo[i] -= (verba + R.C.linhas.filter(x => x.tipo === 'var_lead').reduce((s, x) => s + x.desembolso, 0)) / capDias;
    fluxo[d.capA] -= R.C.linhas.filter(x => ['fixo', 'capacidade'].includes(x.tipo)).reduce((s, x) => s + x.desembolso, 0);
    const pctParc = (val(cx.pctParcelado) || 0) / 100, parcelas = Math.max(1, val(cx.parcelas) || 1), antecipa = !!cx.antecipar, taxaAnt = (val(cx.taxaAntecipacao) || 0) / 100, repasse = val(cx.repasseDias) || 0;
    for (let i = d.carA; i <= d.carB; i++) {
      const recDia = R.recLiq / carDias, varVenda = R.C.linhas.filter(x => x.tipo === 'var_venda').reduce((s, x) => s + x.desembolso, 0) / carDias;
      fluxo[i] -= varVenda + R.F.vendas * R.M.variaveis / carDias; // entrega e suporte saem quando vende
      const vista = recDia * (1 - pctParc), parc = recDia * pctParc;
      if (i + repasse <= n) fluxo[i + repasse] += vista; // simplificação: entra a receita líquida (tributos e comissões já descontados)
      if (antecipa) { if (i + repasse <= n) fluxo[i + repasse] += parc * (1 - taxaAnt * (parcelas - 1) / 2); }
      else for (let k = 0; k < parcelas; k++) { const j = i + repasse + 30 * k; if (j <= n) fluxo[j] += parc / parcelas; }
    }
    (cx.programados || []).forEach(x => { if (x.dia <= n) fluxo[x.dia] -= val(x.valor) || 0; }); // desembolsos já programados no Financeiro
    let s = val(cx.saldo) || 0, min = Infinity, diaMin = 0, payback = null, acumCamp = 0; const serie = [];
    for (let i = 0; i <= n; i++) { s += fluxo[i]; serie.push(s); if (s < min) { min = s; diaMin = i; } acumCamp += fluxo[i] + ((cx.programados || []).filter(x => x.dia === i).reduce((a, x) => a + (val(x.valor) || 0), 0)); if (payback == null && i > d.capA && acumCamp >= 0 && i >= d.carA) payback = i - d.capA; }
    return { serie, min, diaMin, payback, reserva: val(cx.reserva) || 0, folga: min - (val(cx.reserva) || 0) };
  }

  /* ---------- 6. limites: econômico, financiável, autorizado; CAC e CPL ---------- */
  function limites(p) {
    const resMin = val(p.residualMinimo) || 0, teto = val(p.tetoBusca) || 1e6;
    // a) pela meta de vendas (volume fixo): MC da meta − residual − demais custos = verba máxima; sem circularidade
    const vendasMeta = val(p.metaVendas), base = resultado(p, val(p.verbaPlanejada) || 0);
    // b) econômico pelo funil: maior verba em que a contribuição residual ainda cobre o mínimo (o volume cresce com a verba; resolve por bisseção)
    // a contribuição residual sobe e depois cai com a verba (cada lead a mais custa mais): acha o pico e procura o limite à direita dele
    const pico = picoResidual(p, teto), eco = pico.residual < resMin ? { x: null, convergiu: false, motivo: 'nem no melhor ponto a contribuição residual chega ao mínimo', pico } : { ...bissecao(x => resultado(p, x).residual - resMin, pico.x, teto), pico };
    // c) financiável: maior verba em que o caixa nunca fica abaixo da reserva
    const fin = bissecao(x => caixa(p, x).folga, 0, teto);
    // d) operacional: vendas não podem passar da capacidade de entrega
    const capVendas = val(p.capacidadeVendas), op = capVendas == null ? { x: teto, convergiu: true } : bissecao(x => capVendas - resultado(p, x).F.vendas, 0, teto);
    // e) orçamento: não pode usar o que já foi realizado ou está comprometido com outras campanhas
    const disp = val(p.orcamentoDisponivel), orc = disp == null ? { x: teto, convergiu: true } : bissecao(x => disp - resultado(p, x).investimento, 0, teto);
    const lims = [['econômico', eco.x], ['caixa', fin.x], ['capacidade de entrega', op.x], ['orçamento disponível', orc.x]], algumNulo = lims.some(l => l[1] == null);
    const autorizado = algumNulo ? null : Math.min(...lims.map(l => l[1]));
    const quem = autorizado == null ? (lims.find(l => l[1] == null) || ['nenhum'])[0] : lims.find(l => l[1] === autorizado)[0];
    const R = k => k == null ? null : resultado(p, k), Re = R(eco.x), Ra = R(autorizado);
    // pela meta de vendas
    let meta = null;
    if (vendasMeta) {
      const F1 = funil(p, 1), porLead = div(F1.vendas - funil(p, 0).vendas, F1.leadsPagos) || div(F1.vendas, F1.leads); // vendas por lead pago
      const M = margem(p.produto), mcVenda = base.mcVenda, mcMeta = vendasMeta * mcVenda;
      const jaBate = resultado(p, 0).F.vendas >= vendasMeta, verbaParaMeta = jaBate ? { x: 0 } : bissecao(x => resultado(p, x).F.vendas - vendasMeta >= 0 ? -1 : 1, 0, teto); // menor verba que atinge a meta
      const atinge = verbaParaMeta.x != null && resultado(p, verbaParaMeta.x + 1).F.vendas >= vendasMeta - 1e-6, vNec = !atinge ? null : verbaParaMeta.x + (jaBate ? 0 : 1), Rm = vNec == null ? null : resultado(p, vNec);
      const demais = Rm ? Rm.C.total : null, verbaMax = demais == null ? null : mcMeta - resMin - demais;
      meta = { vendasMeta, mcMeta, demais, verbaMax, verbaNecessaria: vNec, viavel: vNec != null && verbaMax != null && vNec <= verbaMax, cacMax: Rm ? div(verbaMax, Rm.F.novos) : null, cplMax: Rm ? div(verbaMax, Rm.F.leadsPagos) : null, R: Rm };
    }
    const novosA = Ra ? Ra.F.novos : null, conv = Ra ? Ra.F.convLeadNovo : null;
    const alvo = { cac: base.cacMidia, cpl: base.cpl }; // o que o planejamento previu: preserva a meta
    return { residualMinimo: resMin, base, economico: { ...eco, R: Re, cac: Re && Re.cacMidia, cpl: Re && Re.cpl }, financiavel: fin, operacional: op, orcamento: orc, autorizado, limitadoPor: quem, Ra,
      cacMaxAutorizado: Ra ? div(autorizado, Ra.F.novos) : null, cplMaxAutorizado: Ra ? div(autorizado, Ra.F.leadsPagos) : null, alvo, meta };
  }

  /* ---------- 7. CPL máximo dinâmico: muda quando a conversão muda ---------- */
  const cplMaxDinamico = (cacMaxMidia, convLeadNovo) => (cacMaxMidia == null || convLeadNovo == null) ? null : cacMaxMidia * convLeadNovo;

  /* ---------- 8. cenários: as premissas variam juntas ---------- */
  const FATORES = {
    pessimista: { cpm: 1.15, ctr: 0.9, convPagina: 0.9, comparecimento: 0.85, convPresentes: 0.85, convAusentes: 0.85, custos: 1.1, reembolso: 1.3 },
    base: { cpm: 1, ctr: 1, convPagina: 1, comparecimento: 1, convPresentes: 1, convAusentes: 1, custos: 1, reembolso: 1 },
    otimista: { cpm: 0.92, ctr: 1.08, convPagina: 1.08, comparecimento: 1.1, convPresentes: 1.1, convAusentes: 1.1, custos: 0.95, reembolso: 0.85 } };
  function aplicaCenario(p, k, fatores) {
    const f = (fatores || FATORES)[k], q = JSON.parse(JSON.stringify(p)), mul = (o, c, m, max) => { const v = val(o[c]); if (v == null) return; const n = Math.min(max == null ? Infinity : max, v * m); if (o[c] && typeof o[c] === 'object') o[c].v = n; else o[c] = n; };
    mul(q.funil, 'cpm', f.cpm); ['ctr', 'convPagina', 'comparecimento', 'convPresentes', 'convAusentes'].forEach(c => mul(q.funil, c, f[c], 100));
    mul(q.produto, 'reembolso', f.reembolso, 100); (q.recursos || []).forEach(r => { r.valor = (val(r.valor) || 0) * f.custos; });
    return q;
  }
  function cenarios(p, verba, fatores) {
    const out = {};
    ['pessimista', 'base', 'otimista'].forEach(k => { const q = aplicaCenario(p, k, fatores), R = resultado(q, verba), C = caixa(q, verba), L = limites(q);
      const risco = R.residual < (val(p.residualMinimo) || 0) ? 'alto' : C.folga < 0 ? 'alto' : R.cacMidia > (L.cacMaxAutorizado || Infinity) ? 'médio' : 'baixo';
      out[k] = { R, C, L, investimento: R.investimento, verba, cpl: R.cpl, cacMidia: R.cacMidia, leads: R.F.leads, part: R.F.part, vendas: R.F.vendas, recLiq: R.recLiq, mc: R.mcTotal, residual: R.residual, caixaMin: C.min, payback: C.payback, risco }; });
    return out;
  }

  /* ---------- 9. LTV: só contribuição incremental, com probabilidade e prazo ---------- */
  function ltv(l) {
    if (!l) return null;
    const taxa = (val(l.taxaSegunda) || 0) / 100, mcInc = val(l.mcIncremental) || 0, custoRet = val(l.custoRetencao) || 0, n = val(l.clientesBase) || 0;
    const valor = taxa * (mcInc - custoRet), fundamentado = n >= (val(l.minClientes) || 30);
    return { valorPorCliente: valor, fundamentado, risco: fundamentado ? 'histórico com ' + n + ' clientes' : 'hipótese: menos de ' + (val(l.minClientes) || 30) + ' clientes na coorte', diasAteSegunda: val(l.diasAteSegunda) };
  }
  // campanha com contribuição inicial negativa só passa com tudo isto verdadeiro
  function permiteNegativa(c) { const motivos = []; if (!c.estrategiaAprovada) motivos.push('estratégia não aprovada'); if (!c.ltvFundamentado) motivos.push('contribuição futura sem histórico'); if (!(c.paybackDias != null && c.paybackDias <= c.paybackMaxDias)) motivos.push('payback acima do aceito'); if (!c.caixaSuporta) motivos.push('caixa não suporta'); if (c.limitePerda == null) motivos.push('limite de perda não definido'); return { ok: !motivos.length, motivos }; }

  /* ---------- 10. histórico: taxas ponderadas pelos denominadores, não média simples ---------- */
  // CPL tem a mesma base do plano: mídia ÷ leads PAGOS (Meta + Google) quando a campanha tem a divisão por canal
  const leadsPagosHist = c => c.canais ? ['meta', 'google'].reduce((a, k) => a + (c.canais[k] ? val(c.canais[k].leads) || 0 : 0), 0) : val(c.leads);
  function historico(camps) {
    const s = k => camps.reduce((a, c) => a + (val(c[k]) || 0), 0), lp = camps.reduce((a, c) => a + (leadsPagosHist(c) || 0), 0);
    return { cpl: div(s('midia'), lp), leadsPagos: lp, leadsOrg: s('leads') - lp, vendasPorLead: div(s('vendas'), s('leads')), comparecimentoInscritos: div(s('participantes'), s('inscritos')), convAusentes: div(s('vendas') - s('vendasPresentes'), s('inscritos') - s('participantes')), pctNovos: div(s('novos'), s('vendas')), comparecimento: div(s('participantes'), s('inscritos') || s('leads')), convPresentes: div(s('vendasPresentes'), s('participantes')), convLeadVenda: div(s('vendas'), s('leads')), cac: div(s('midia'), s('novos')), ticket: div(s('receita'), s('vendas')), n: camps.length,
      mediaSimplesCpl: camps.length ? camps.reduce((a, c) => a + (div(val(c.midia), leadsPagosHist(c)) || 0), 0) / camps.length : null };
  }

  /* ---------- 10b. histórico por canal, faixa entre campanhas e ofertas ---------- */
  const CANAIS = { meta: 'Meta Ads', google: 'Google Ads', org: 'Orgânico', api: 'WhatsApp API' };
  function faixa(camps, f) { const v = camps.map(f).filter(x => x != null && isFinite(x)); return v.length ? { min: Math.min(...v), max: Math.max(...v), n: v.length } : null; }
  function historicoCanais(camps) {
    const out = {}, totLeads = camps.reduce((s, c) => s + (val(c.leads) || 0), 0), totNovos = camps.reduce((s, c) => s + (val(c.novos) || 0), 0);
    Object.keys(CANAIS).forEach(k => { const cs = camps.filter(c => c.canais && c.canais[k]); if (!cs.length) return;
      const g = (c, f) => val(c.canais[k][f]), s = f => cs.reduce((a, c) => a + (g(c, f) || 0), 0), custo = s('midia') + s('custo');
      out[k] = { nome: CANAIS[k], custo, leads: s('leads'), novos: s('novos'), cpl: custo ? div(custo, s('leads')) : null, cac: custo ? div(custo, s('novos')) : null, convLeadNovo: div(s('novos'), s('leads')),
        pctLeads: div(s('leads'), totLeads), pctNovos: div(s('novos'), totNovos), leadsPorCampanha: s('leads') / cs.length,
        faixaCpl: custo ? faixa(cs, c => div((g(c, 'midia') || 0) + (g(c, 'custo') || 0), g(c, 'leads'))) : null, faixaCac: custo ? faixa(cs, c => div((g(c, 'midia') || 0) + (g(c, 'custo') || 0), g(c, 'novos'))) : null }; });
    return out;
  }
  function historicoFaixas(camps) { return { cpl: faixa(camps, c => div(val(c.midia), leadsPagosHist(c))), cac: faixa(camps, c => div(val(c.midia), val(c.novos))), comparecimento: faixa(camps, c => div(val(c.participantes), val(c.inscritos))), convPresentes: faixa(camps, c => div(val(c.vendasPresentes), val(c.participantes))), ticket: faixa(camps, c => div(val(c.receita), val(c.vendas))), vendas: faixa(camps, c => val(c.vendas)) }; }
  function historicoOfertas(camps) { // taxa de aceite ponderada: soma das vendas da oferta ÷ soma da base que viu a oferta
    const r = {}; ['bump', 'upsell', 'downsell'].forEach(k => { const cs = camps.filter(c => c.ofertas && c.ofertas[k]); if (!cs.length) { r[k] = null; return; }
      const base = c => k === 'downsell' ? val(c.ofertas[k].ofertadoPara) : val(c.vendas), num = cs.reduce((s, c) => s + (val(c.ofertas[k].vendas) || 0), 0), den = cs.reduce((s, c) => s + (base(c) || 0), 0);
      r[k] = { aceite: div(num, den), vendas: num, campanhas: cs.length, de: camps.length, faixa: faixa(cs, c => div(val(c.ofertas[k].vendas), base(c))) }; });
    return r;
  }
  // quantos leads a meta pede com esta verba, e quanto disso o orgânico precisa trazer
  function leadsParaMeta(p, verba) {
    const F = funil(p, verba), porLead = div(F.vendas, F.leads), meta = val(p.metaVendas); if (!porLead || meta == null) return null;
    const precisa = meta / porLead, api = (p.canais || []).filter(c => c.tipo === 'api').reduce((s, c) => s + (val(c.leads) || 0), 0), org = (p.canais || []).filter(c => c.tipo === 'org').reduce((s, c) => s + (val(c.leads) || 0), 0);
    const orgPrecisa = Math.max(0, precisa - F.leadsPagos - api);
    return { verba, vendasPorLead: porLead, leadsPrecisa: precisa, leadsPagos: F.leadsPagos, api, orgPlanejado: org, orgPrecisa, faltaOrg: Math.max(0, orgPrecisa - org), vendasPrevistas: F.vendas };
  }

  /* ---------- 10c. plano da campanha por canal: a decisão depois de olhar limites e histórico ---------- */
  // c = { verba, meta, pctNovos, comparecimento, convPresentes, convAusentes (em %), canais: { meta: { pct, cpl }, google: { pct, cpl }, org: { leads }, api: { leads, custoLead } } }
  function planoCampanha(c) {
    const pc = x => (val(x) || 0) / 100, comp = pc(c.comparecimento), vpl = comp * pc(c.convPresentes) + (1 - comp) * pc(c.convAusentes), verba = val(c.verba) || 0, ch = c.canais || {};
    // CPL sobe quando a verba passa da referência (mesma elasticidade do funil): fator = (verba ÷ verba de referência) ^ elasticidade
    const fator = val(c.verbaRef) && verba > 0 ? Math.pow(verba / val(c.verbaRef), val(c.elasticidade) || 0) : 1;
    const pagos = ['meta', 'google'].map(k => { const x = ch[k] || {}, v = verba * pc(x.pct), cpl = val(x.cpl) == null ? null : val(x.cpl) * fator; return { k, verba: v, cplBase: val(x.cpl), cpl, leads: cpl ? v / cpl : 0 }; });
    const leadsPagos = pagos.reduce((s, x) => s + x.leads, 0), org = val(ch.org && ch.org.leads) || 0, api = val(ch.api && ch.api.leads) || 0, custoApi = api * (val(ch.api && ch.api.custoLead) || 0);
    const leads = leadsPagos + org + api, part = leads * comp, vPres = part * pc(c.convPresentes), vAus = (leads - part) * pc(c.convAusentes), vendas = vPres + vAus, novos = vendas * pc(c.pctNovos);
    const meta = val(c.meta), precisa = meta != null && vpl ? meta / vpl : null;
    return { verba, fator, pagos, leadsPagos, org, api, custoApi, leads, vendasPorLead: vpl, part, vPres, vAus, vendas, novos, cacMidia: div(verba, novos), cpl: div(verba, leadsPagos), leadsPrecisa: precisa,
      faltaLeads: precisa == null ? null : Math.max(0, precisa - leads), orgParaMeta: precisa == null ? null : Math.max(0, precisa - leadsPagos - api), atingeMeta: meta == null ? null : vendas >= meta - 1e-9,
      pctSomaPagos: ['meta', 'google'].reduce((s, k) => s + (val(ch[k] && ch[k].pct) || 0), 0) };
  }
  // verba que um CAC escolhido paga para a meta: CAC de mídia × novos clientes da meta
  const verbaPeloCac = (cac, meta, pctNovos) => (val(cac) == null || val(meta) == null) ? null : val(cac) * val(meta) * (val(pctNovos) || 0) / 100;
  // três cenários tirados do histórico: pior, média ponderada e melhor campanha; mesma verba nos três
  function cenariosDoHistorico(camps, verba, meta, apiCustoLead, elasticidade) {
    const H = historico(camps), C = historicoCanais(camps), r = x => x * 100, por = f => camps.map(f).filter(x => x != null && isFinite(x)), mn = f => Math.min(...por(f)), mx = f => Math.max(...por(f));
    const cAus = c => div(val(c.vendas) - val(c.vendasPresentes), val(c.inscritos) - val(c.participantes)), cComp = c => div(val(c.participantes), val(c.inscritos)), cPres = c => div(val(c.vendasPresentes), val(c.participantes));
    const lc = (c, k) => c.canais && c.canais[k] ? val(c.canais[k].leads) : null, cplc = (c, k) => c.canais && c.canais[k] ? div(val(c.canais[k].midia), val(c.canais[k].leads)) : null;
    const pctMeta = C.meta && C.google ? C.meta.custo / (C.meta.custo + C.google.custo) * 100 : 100;
    const verbaRef = camps.reduce((s, c) => s + (val(c.midia) || 0), 0) / camps.length;
    const mk = (comp, pres, aus, cplM, cplG, org, api) => ({ verba, meta, verbaRef, elasticidade: elasticidade || 0, pctNovos: r(H.pctNovos), comparecimento: r(comp), convPresentes: r(pres), convAusentes: r(aus),
      canais: { meta: { pct: pctMeta, cpl: cplM }, google: { pct: 100 - pctMeta, cpl: cplG }, org: { leads: org }, api: { leads: api, custoLead: apiCustoLead } } });
    return {
      pessimista: mk(mn(cComp), mn(cPres), mn(cAus), mx(c => cplc(c, 'meta')), mx(c => cplc(c, 'google')), mn(c => lc(c, 'org')), mn(c => lc(c, 'api'))),
      base: mk(H.comparecimento, H.convPresentes, H.convAusentes, C.meta.cpl, C.google.cpl, C.org.leadsPorCampanha, C.api.leadsPorCampanha),
      otimista: mk(mx(cComp), mx(cPres), mx(cAus), mn(c => cplc(c, 'meta')), mn(c => cplc(c, 'google')), mx(c => lc(c, 'org')), mx(c => lc(c, 'api'))) };
  }

  /* ---------- 11. status no cockpit ---------- */
  function status(o) { // o: { cpl, cplAlvo, cplMax, dependeFuturo, caixaFolga }
    if (o.caixaFolga != null && o.caixaFolga < 0) return ['risco_financeiro', 'Em risco financeiro'];
    if (o.cpl != null && o.cplMax != null && o.cpl > o.cplMax) return ['acima_limite', 'Acima do limite autorizado'];
    if (o.dependeFuturo) return ['depende_futuro', 'Dependente de resultados futuros'];
    if (o.cpl != null && o.cplAlvo != null && o.cpl > o.cplAlvo) return ['acima_meta', 'Acima da meta, mas dentro do limite econômico'];
    return ['dentro', 'Dentro da meta'];
  }
  // projeção de fechamento: ritmo atual aplicado ao que falta, com intervalo pelos cenários (sem inventar probabilidade)
  function projecao(realAteHoje, planejadoAteHoje, planejadoTotal) { const ritmo = div(realAteHoje, planejadoAteHoje); return ritmo == null ? null : { ritmo, projecao: realAteHoje + (planejadoTotal - planejadoAteHoje) * ritmo }; }

  /* ---------- 12. versão aprovada: fotografia imutável ---------- */
  function congela(bc, quem, quando, motivo) { const foto = JSON.parse(JSON.stringify(bc)); return Object.freeze({ foto: Object.freeze(foto), quem, quando, motivo, hash: hash(JSON.stringify(foto)) }); }
  function hash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0).toString(16); }
  // duas campanhas pelo mesmo orçamento: o que sobra para a segunda depois de reservar a primeira
  const orcamentoDisponivel = (orcamento, realizado, comprometido) => Math.max(0, (val(orcamento) || 0) - (val(realizado) || 0) - (val(comprometido) || 0));

  const API = { planoCampanha, verbaPeloCac, cenariosDoHistorico, CANAIS, faixa, historicoCanais, historicoFaixas, historicoOfertas, leadsParaMeta, ORIGENS, FATORES, picoResidual, valida, margem, funil, custos, resultado, bissecao, caixa, limites, cplMaxDinamico, aplicaCenario, cenarios, ltv, permiteNegativa, historico, status, projecao, congela, hash, orcamentoDisponivel, div, r2 };
  if (typeof module !== 'undefined' && module.exports) module.exports = API; else raiz.BC = API;
})(typeof window !== 'undefined' ? window : globalThis);
