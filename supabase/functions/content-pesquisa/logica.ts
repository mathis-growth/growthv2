// Regras puras da função content-pesquisa (testadas em logica_test.ts).

// id da pasta do Drive a partir do link (ou o próprio id)
export function pastaIdDe(link: string | null | undefined): string | null {
  const s = String(link ?? '').trim();
  const m = s.match(/\/folders\/([A-Za-z0-9_-]{10,})/) || s.match(/[?&]id=([A-Za-z0-9_-]{10,})/) || s.match(/^([A-Za-z0-9_-]{20,})$/);
  return m ? m[1] : null;
}

export type Arquivo = { id: string; nome: string; caminho: string; rotulo: string; tipo: string; modificado?: string; url?: string; lido: boolean; motivo?: string; texto?: string; pdf_base64?: string };

// o que fica gravado na pesquisa (sem o conteúdo dos arquivos)
export function resumoArquivos(arqs: Arquivo[]) {
  return arqs.map(a => ({ nome: a.nome, caminho: a.caminho, rotulo: a.rotulo, url: a.url || null, lido: !!a.lido, motivo: a.motivo || null, tipo: a.tipo }));
}

const ROT: Record<string, string> = { mathisa: 'PADRÃO DA MATHISA', cliente: 'MATERIAL DO CLIENTE', 'cliente-extra': 'MATERIAL DO CLIENTE (outra pasta)' };

// blocos de conteúdo dos arquivos para a mensagem da IA
export function blocosArquivos(arqs: Arquivo[]) {
  const blocos: unknown[] = [];
  for (const a of arqs) {
    if (!a.lido) continue;
    const titulo = `[${ROT[a.rotulo] || a.rotulo}] ${a.caminho} › ${a.nome}`;
    if (a.pdf_base64) blocos.push({ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: a.pdf_base64 }, title: titulo.slice(0, 250), context: 'Arquivo das pastas do Growth\'s Content' });
    else if (a.texto) blocos.push({ type: 'text', text: `### ${titulo}\n${a.texto}` });
  }
  return blocos;
}

// fontes da web: resultados da busca e citações no texto, sem repetir o endereço
export function extraiFontes(content: any[]): { url: string; titulo: string }[] {
  const vistos = new Map<string, string>();
  for (const b of content || []) {
    if (b?.type === 'web_search_tool_result' && Array.isArray(b.content)) for (const r of b.content) if (r?.url && !vistos.has(r.url)) vistos.set(r.url, r.title || r.url);
    if (b?.type === 'text' && Array.isArray(b.citations)) for (const c of b.citations) if (c?.url && !vistos.has(c.url)) vistos.set(c.url, c.title || c.url);
  }
  return [...vistos].map(([url, titulo]) => ({ url, titulo }));
}

export function textoDe(content: any[]): string {
  return (content || []).filter(b => b?.type === 'text').map(b => b.text || '').join('').trim();
}

// soma o uso de várias respostas (a pesquisa pode continuar em mais de uma chamada)
export function somaUso(usos: any[]) {
  return usos.reduce((a, u) => ({
    entrada: a.entrada + (u?.input_tokens || 0), saida: a.saida + (u?.output_tokens || 0),
    cache: a.cache + (u?.cache_read_input_tokens || 0) + (u?.cache_creation_input_tokens || 0),
    buscas: a.buscas + (u?.server_tool_use?.web_search_requests || 0) }), { entrada: 0, saida: 0, cache: 0, buscas: 0 });
}

// custo em US$ só com preço cadastrado (sistema_config.ia_precos); sem preço, null — nada inventado
export function custoUSD(uso: { entrada: number; saida: number; buscas: number }, precos: any, modelo: string): number | null {
  const p = precos?.[modelo];
  if (!p || typeof p.entrada !== 'number' || typeof p.saida !== 'number') return null;
  let c = uso.entrada / 1e6 * p.entrada + uso.saida / 1e6 * p.saida;
  if (uso.buscas) { if (typeof precos?.busca_mil !== 'number') return null; c += uso.buscas / 1000 * precos.busca_mil; }
  return Math.round(c * 1e6) / 1e6;
}

// o dossiê vem em JSON: {"secoes":[{"titulo","texto"}]}
export function lerSecoes(texto: string, esperadas: string[]): { titulo: string; texto: string }[] {
  let t = String(texto || '').trim().replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim();
  const i = t.indexOf('{'), j = t.lastIndexOf('}');
  if (i < 0 || j < i) throw new Error('A resposta não veio no formato do dossiê.');
  const o = JSON.parse(t.slice(i, j + 1));
  const L = (Array.isArray(o?.secoes) ? o.secoes : []).map((s: any) => ({ titulo: String(s?.titulo ?? '').trim().slice(0, 120), texto: String(s?.texto ?? '').trim().slice(0, 20000) })).filter((s: any) => s.titulo && s.texto);
  if (!L.length) throw new Error('O dossiê veio sem seções.');
  const falta = esperadas.filter(e => !L.some((s: any) => s.titulo.toLowerCase() === e.toLowerCase()));
  if (falta.length > Math.ceil(esperadas.length / 2)) throw new Error('O dossiê veio sem a maior parte das seções pedidas: ' + falta.join(', '));
  return L;
}

// o que a call respondeu, em texto (pergunta: resposta)
export function textoCall(respostas: Record<string, unknown> | null | undefined, perguntas: Record<string, string>): string {
  const r = respostas || {};
  return Object.entries(r).filter(([k, v]) => !k.startsWith('_') && (Array.isArray(v) ? v.length : String(v ?? '').trim()))
    .map(([k, v]) => `- ${perguntas[k] || k}: ${Array.isArray(v) ? v.join('; ') : String(v).trim()}`).join('\n')
    + (r._call_notas ? `\n- Anotações livres da call: ${String(r._call_notas).trim()}` : '');
}
