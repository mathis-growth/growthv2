// Regras puras da função content-google (testadas em logica_test.ts).
export const ESCOPOS = ['openid', 'email', 'https://www.googleapis.com/auth/drive.file'];
export function urlLogin(o: { clientId: string; redirect: string; estado: string; email?: string }) {
  const p = new URLSearchParams({ client_id: o.clientId, redirect_uri: o.redirect, response_type: 'code', access_type: 'offline', prompt: 'consent select_account',
    include_granted_scopes: 'true', scope: ESCOPOS.join(' '), state: o.estado });
  if (o.email) p.set('login_hint', o.email);
  return 'https://accounts.google.com/o/oauth2/v2/auth?' + p.toString();
}
export function nomeRaiz(cliente: string) {
  return ("Growth's Content — " + String(cliente || '').replace(/[\\/"“”]/g, '').replace(/\s+/g, ' ').trim()).slice(0, 120);
}
// só volta para endereços http(s) (nunca javascript: etc.); acrescenta o resultado na query
export function voltarPara(base: string | null | undefined, params: Record<string, string>) {
  let u: URL;
  try { u = new URL(String(base || '')); } catch { return null; }
  if (!/^https?:$/.test(u.protocol)) return null;
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  return u.toString();
}
export function caminhos(arvore: string[]): string[][] {
  return arvore.map((c) => String(c).split('/').map((x) => x.trim()).filter(Boolean)).filter((x) => x.length);
}
export function escQ(s: string) { return s.replace(/\\/g, '\\\\').replace(/'/g, "\\'"); }
