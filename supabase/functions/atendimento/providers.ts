import { urlPublica } from './core.ts';
export class ProviderError extends Error {
  constructor(public status: number, public code: string) { super(`Provedor recusou a operação (${status}${code ? ': ' + code : ''}).`); }
}
export async function publicHost(host: string) {
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host)) { urlPublica('https://' + host); return; }
  const [a,aaaa] = await Promise.all([
    Deno.resolveDns(host,'A').catch(() => []),Deno.resolveDns(host,'AAAA').catch(() => []),
  ]);
  if (!a.length && !aaaa.length) throw new Error('Servidor sem endereço público.');
  a.forEach(ip => urlPublica('https://' + ip));
  if (aaaa.some(ip => !/^[23][0-9a-f]{3}:/i.test(ip))) throw new Error('Endereço IPv6 não público.');
}
export async function request(url: string, key: string, method = 'GET', body?: unknown, evo = false) {
  const r = await fetch(url, { method, redirect: 'error', signal: AbortSignal.timeout(20000),
    headers: { 'Content-Type': 'application/json', ...(evo ? { apikey: key } : { Authorization: `Bearer ${key}` }) },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const data = await r.json().catch(() => ({}));
  // Nunca devolve corpo bruto: alguns servidores ecoam credenciais nas falhas.
  if (!r.ok) throw new ProviderError(r.status, String(data.code || '').replace(/[^A-Z_]/g,'').slice(0,60));
  return data;
}
export const zernio = (key: string, path: string, method = 'GET', body?: unknown) => request('https://zernio.com/api/v1' + path, key, method, body);
export async function evolution(cfg: any, path: string, method = 'GET', body?: unknown) {
  const u = urlPublica(cfg.evolution_url);
  // Bloqueia DNS apontando para redes internas antes de usar a chave do servidor.
  await publicHost(u.hostname);
  return request(u.toString().replace(/\/$/, '') + path, cfg.evolution_key, method, body, true);
}
export const providers: Record<string, {
  send: (cfg: any, channel: any, conversation: any, text: string, attachment?: any) => Promise<string>;
}> = {
  evolution: {
    async send(cfg, ch, cv, text, attachment) {
      const inst = encodeURIComponent(ch.externo_id);
      const payload = attachment ? { number: cv.externo_id, mediatype: attachment.mime.startsWith('image/') ? 'image' : attachment.mime.startsWith('video/') ? 'video' : 'document',
        mimetype: attachment.mime, fileName: attachment.nome, caption: text, media: attachment.url } : { number: cv.externo_id, text };
      const r = await evolution(cfg, '/message/' + (attachment ? 'sendMedia/' : 'sendText/') + inst, 'POST', payload);
      if (!r.key?.id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return r.key.id;
    },
  },
  zernio: {
    async send(cfg, ch, cv, text, attachment) {
      const r = await zernio(cfg.key, '/inbox/conversations/' + encodeURIComponent(cv.externo_id) + '/messages', 'POST', {
        accountId: ch.externo_id, message: text,
        ...(attachment ? { attachments: [{ url: attachment.url, type: attachment.mime.split('/')[0] === 'application' ? 'file' : attachment.mime.split('/')[0] }] } : {}),
      });
      const id = r.data?.messageId || r.messageId;
      if (!id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return id;
    },
  },
};
