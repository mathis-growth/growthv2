// Leitura dos campos do lead, separada para poder testar sem subir a função (tests/edge/leads_teste.ts).
export const RE_CHAVE = /^gw_[0-9a-f]{64}$/;
export const UTM = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'utm_growth'];

export type Dic = Record<string, unknown>;
export type Lead = { nome: string | null; email: string | null; telefone: string | null; pagina: string | null; origem: string; em: string | null; respostas: Dic; [k: string]: unknown };

const utmCampo = (nome: string): string | null => UTM.find(k => nome === k || nome.endsWith('_' + k)) || null;

export function chaveDe(req: Request, url: URL): string | null {
  const a = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const k = (req.headers.get('x-growths-chave') || a || url.searchParams.get('chave') || '').trim();
  return RE_CHAVE.test(k) ? k : null;
}

// "Qual é o seu WhatsApp?" → "qual_e_o_seu_whatsapp"
export const chaveNorm = (s: string) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
const tipoDe = (k: string): 'email' | 'telefone' | 'nome' | 'utm' | 'pagina' | 'ignorar' | null => {
  const n = chaveNorm(k);
  if (!n) return 'ignorar';
  if (utmCampo(n)) return 'utm';
  if (/^(chave|redirect|_redirect|_gotcha|website|_next|_subject|g_recaptcha_response|cf_turnstile_response|submit|enviar)$/.test(n)) return 'ignorar';
  if (/(^|_)e_?mail(_|$)|^email/.test(n)) return 'email';
  if (/(telefone|celular|whats_?app|phone|fone|^tel$|^tel_|_tel$|^ddd_?numero$)/.test(n)) return 'telefone';
  if (/^(nome|name|full_name|nome_completo|seu_nome)$|(^|_)(seu|sua)_?nome|qual_(e_)?(o_)?(seu_)?nome/.test(n)) return 'nome';
  if (/^(pagina|page|page_url|url|landing_page|pagina_origem|referrer|referer|form_url)$/.test(n)) return 'pagina';
  return null;
};
export const valorTexto = (v: unknown): string | null => {
  if (v === null || v === undefined) return null;
  if (Array.isArray(v)) return v.map(valorTexto).filter(Boolean).join(', ') || null;
  if (typeof v === 'object') return Object.values(v as Dic).map(valorTexto).filter(Boolean).join(' ') || null; // ex.: {ddd:"11", numero:"9..."}
  const s = String(v).trim();
  return s ? s.slice(0, 1000) : null;
};

// Junta todos os pares pergunta → resposta, de qualquer formato conhecido, numa lista plana.
export function pares(corpo: unknown, prefixo = '', fora: [string, unknown][] = [], prof = 0): [string, unknown][] {
  if (prof > 5 || corpo === null || typeof corpo !== 'object') return fora;
  if (Array.isArray(corpo)) {
    for (const x of corpo) {
      if (x && typeof x === 'object' && !Array.isArray(x)) {
        const o = x as Dic;
        // Meta: { name, values: [...] }
        if (typeof o.name === 'string' && 'values' in o) { fora.push([o.name, o.values]); continue; }
        // Respondi (raw_answers) e parecidos: { question: { question_title }, answer }
        const q = o.question as Dic | undefined;
        const titulo = (q && (q.question_title || q.title)) || o.question_title || o.title || o.label || o.pergunta || o.field || o.key;
        if (typeof titulo === 'string' && ('answer' in o || 'value' in o || 'resposta' in o)) { fora.push([titulo, o.answer ?? o.value ?? o.resposta]); continue; }
        pares(o, prefixo, fora, prof + 1);
      }
    }
    return fora;
  }
  for (const [k, v] of Object.entries(corpo as Dic)) {
    if (v && typeof v === 'object') {
      // contêineres conhecidos não viram prefixo
      if (/^(lead|data|dados|respondent|answers|respostas|fields|campos|form_response|field_data|raw_answers|respondent_utms|utms|utm|contact|contato|body|payload|entry|changes|value)$/i.test(k)) { pares(v, prefixo, fora, prof + 1); continue; }
      const t = tipoDe(k);
      if (t === 'telefone' || t === 'nome') { fora.push([k, v]); continue; } // telefone em partes {ddd, numero}
      pares(v, prefixo ? prefixo + '.' + k : k, fora, prof + 1);
      continue;
    }
    fora.push([prefixo && !tipoDe(k) ? prefixo + '.' + k : k, v]);
  }
  return fora;
}

export function utmsDaUrl(u: string | null): Dic {
  const o: Dic = {};
  if (!u) return o;
  try { const x = new URL(u); for (const [nome, valor] of x.searchParams) { const chave = nome.toLowerCase(); if (UTM.includes(chave) && valor) o[chave] = valor; } } catch { /* não é URL */ }
  return o;
}

type AtribuicaoPayload = { growth: string | null; urlEntrada: string | null; urlPagina: string | null; uuids: string[] };
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i;

function parametroEmTexto(texto: string, parametro: string): string | null {
  let candidato = texto.trim().slice(0, 20000).replace(/&amp;/gi, '&');
  for (let tentativa = 0; tentativa < 3 && candidato; tentativa++) {
    const urls = candidato.match(/https?:\/\/[^\s"'<>]+/gi) || [];
    for (const raw of urls) {
      try {
        const u = new URL(raw.replace(/[),.;]+$/, ''));
        for (const [nome, valor] of u.searchParams) if (nome.toLowerCase() === parametro && valor) return valor;
      } catch { /* tenta ler como query string */ }
    }
    const query = candidato.includes('?') ? candidato.slice(candidato.indexOf('?') + 1).split('#', 1)[0] : candidato;
    for (const [nome, valor] of new URLSearchParams(query)) if (nome.toLowerCase() === parametro && valor) return valor;
    try {
      const decodificado = decodeURIComponent(candidato.replace(/\+/g, '%20'));
      if (decodificado === candidato) break;
      candidato = decodificado;
    } catch { break; }
  }
  return null;
}

// Procura a atribuição em qualquer nível do payload, inclusive valores que sejam URLs ou JSON serializado.
function atribuicaoNoPayload(raiz: unknown): AtribuicaoPayload {
  const achado: AtribuicaoPayload = { growth: null, urlEntrada: null, urlPagina: null, uuids: [] };
  let visitados = 0;
  const percorrer = (valor: unknown, chave = '', profundidade = 0): void => {
    if (visitados++ > 20000 || profundidade > 12 || valor == null) return;
    const nome = chaveNorm(chave);
    if (typeof valor === 'string' || typeof valor === 'number') {
      const texto = String(valor).trim();
      if (!texto) return;
      if (!achado.growth && utmCampo(nome) === 'utm_growth' && UUID_RE.test(texto)) achado.growth = texto.match(UUID_RE)![0];
      if (!achado.urlEntrada && (nome === 'growth_pagina' || nome.endsWith('_growth_pagina')) && /^https?:\/\//i.test(texto)) achado.urlEntrada = texto;
      if (!achado.growth) achado.growth = parametroEmTexto(texto, 'utm_growth');
      if (!achado.urlEntrada) achado.urlEntrada = parametroEmTexto(texto, 'growth_pagina');
      if (!achado.urlPagina && /^https?:\/\//i.test(texto) && (parametroEmTexto(texto, 'utm_growth') || parametroEmTexto(texto, 'growth_pagina'))) achado.urlPagina = texto;
      for (const id of texto.match(/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi) || []) {
        if (!achado.uuids.includes(id) && achado.uuids.length < 50) achado.uuids.push(id);
      }
      return;
    }
    if (Array.isArray(valor)) { for (const item of valor) percorrer(item, chave, profundidade + 1); return; }
    if (typeof valor === 'object') for (const [k, v] of Object.entries(valor as Dic)) percorrer(v, k, profundidade + 1);
  };
  percorrer(raiz);
  return achado;
}

export function leadDe(corpo: unknown, url: URL): Lead {
  const L: Lead = { nome: null, email: null, telefone: null, pagina: null, origem: 'formulario', em: null, respostas: {} };
  const c = (corpo || {}) as Dic;
  if (c.respondent || (c.form && typeof c.form === 'object' && (c.form as Dic).form_name)) L.origem = 'respondi';
  if (JSON.stringify(c).includes('"field_data"') || c.leadgen_id) L.origem = 'meta_lead_ads';
  const resp: Dic = {};
  let n = 0;
  for (const [k, v] of pares(corpo)) {
    const t = tipoDe(k), s = t === 'pagina' && typeof v === 'string' ? v.trim().slice(0, 12000) : valorTexto(v);
    if (!s || t === 'ignorar') continue;
    if (t === 'email' && !L.email && /@/.test(s)) { L.email = s; continue; }
    if (t === 'telefone' && !L.telefone && /\d{8}/.test(s.replace(/\D/g, ''))) { L.telefone = s; continue; }
    if (t === 'nome' && !L.nome) { L.nome = s; continue; }
    if (t === 'utm') { const u = utmCampo(chaveNorm(k)); if (u && !L[u]) L[u] = s; continue; }
    if (t === 'pagina' && !L.pagina) { L.pagina = s; continue; }
    if (/^(created_time|data|date|submitted_at|em)$/.test(chaveNorm(k)) && !L.em && !isNaN(Date.parse(s))) { L.em = new Date(/^\d{4}-\d\d-\d\d[ T]\d\d:\d\d(:\d\d)?$/.test(s) ? s.replace(' ', 'T') + '-03:00' : s).toISOString(); continue; } // sem fuso = horário de Brasília
    if (t) continue;
    if (n++ < 40 && !(k in resp)) resp[k.slice(0, 120)] = s.slice(0, 500);
  }
  if (!L.nome) { // first_name + last_name
    const f = resp['first_name'] || resp['primeiro_nome'], l = resp['last_name'] || resp['sobrenome'];
    if (f) L.nome = [f, l].filter(Boolean).join(' ');
  }
  const atribuicao = atribuicaoNoPayload(corpo);
  // A URL da página pode estar em qualquer campo; growth_pagina preserva a entrada original.
  const paginaFormulario = L.pagina;
  const paginaEntrada = atribuicao.urlEntrada || utmsDaUrl(paginaFormulario).growth_pagina;
  if (paginaEntrada) {
    L.pagina_formulario = paginaFormulario || atribuicao.urlPagina;
    L.pagina = String(paginaEntrada);
  } else L.pagina = paginaFormulario || atribuicao.urlPagina || url.searchParams.get('growth_pagina') || null;
  // UTMs: o que veio no corpo > a URL da página > parâmetros do endereço da função (padrão do formulário)
  const daPagina = utmsDaUrl(L.pagina);
  const growthDetectado = L.utm_growth || atribuicao.growth || daPagina.utm_growth || url.searchParams.get('utm_growth');
  L.utm_growth_detectado = Boolean(growthDetectado);
  L.utm_growth = growthDetectado || atribuicao.uuids[0] || null;
  if (atribuicao.uuids.length) L.utm_growth_candidates = atribuicao.uuids;
  for (const k of UTM) if (k !== 'utm_growth') L[k] = L[k] || daPagina[k] || url.searchParams.get(k) || null;
  if (url.searchParams.get('origem')) L.origem = url.searchParams.get('origem')!;
  L.respostas = resp;
  return L;
}

