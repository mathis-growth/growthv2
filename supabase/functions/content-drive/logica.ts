// Regras puras da função content-drive (testadas em logica_test.ts).
export function lerArvore(txt: string | null | undefined): string[] {
  try {
    const a = JSON.parse(txt || '[]');
    return Array.isArray(a) ? a.map((x) => String(x ?? '').trim()).filter(Boolean).slice(0, 200) : [];
  } catch { return []; }
}
export function nomeDaPasta(nome: string | null | undefined): string {
  return String(nome ?? '').replace(/[\\/]/g, '-').replace(/\s+/g, ' ').trim().slice(0, 120);
}
export function montaPedido(o: { senha: string; raiz: string; nome: string; arvore: string[]; pastaId?: string | null; acao?: string }) {
  return { senha: o.senha, acao: o.acao || 'criar_cliente', raiz: o.raiz, nome: nomeDaPasta(o.nome), arvore: o.arvore, pasta_id: o.pastaId || null };
}
// o Apps Script responde JSON; se vier HTML (login do Google, erro de implantação), explica o que fazer
export function lerResposta(status: number, texto: string): { ok: true; id: string; url: string } | { ok: false; erro: string } {
  let j: any = null;
  try { j = JSON.parse(texto); } catch { /* não é JSON */ }
  if (!j) {
    if (status === 401 || status === 403 || /Acesso negado|Access denied|accounts\.google\.com|ServiceLogin/i.test(texto)) return { ok: false, erro: 'O Apps Script negou o acesso: na implantação, "Quem pode acessar" precisa ser "Qualquer pessoa".' };
    return { ok: false, erro: `O Apps Script não respondeu como esperado (HTTP ${status}). Confira se o endereço termina em /exec.` };
  }
  if (!j.ok) return { ok: false, erro: String(j.erro || 'O Apps Script recusou o pedido') };
  if (!j.id || !j.url) return { ok: false, erro: 'O Apps Script não devolveu a pasta criada' };
  return { ok: true, id: String(j.id), url: String(j.url) };
}
