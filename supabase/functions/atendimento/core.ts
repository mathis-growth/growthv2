// Contrato comum: canais novos implementam um adaptador, sem alterar o histórico.
export type Canal = { id: string; workspace_id: string; provedor: string; canal: string; externo_id: string; ativo: boolean };
export type Anexo = { path?: string; nome: string; mime: string; tamanho?: number; pendente?: boolean };
export const MAX_MEDIA = 8 * 1024 * 1024;
export function assinatura(nome: string, texto: string, canal: string): string {
  const limpo = nome.replace(/[\r\n*_`~]/g, '').trim();
  if (!limpo) throw new Error('Cadastre seu nome em Equipe e acessos antes de enviar.');
  return canal === 'whatsapp' ? `*${limpo}:* ${texto}` : `${limpo}: ${texto}`;
}
export function urlPublica(valor: string): URL {
  const u = new URL(valor);
  const h = u.hostname.toLowerCase();
  if (/^\d+\.\d+\.\d+\.\d+$/.test(h) && Number(h.split('.')[0]) >= 224) throw new Error('Endereço de rede não público.');
  if (u.protocol !== 'https:' || u.username || u.password || u.hash || u.search ||
      h === 'localhost' || h.endsWith('.local') || h.endsWith('.internal') || !h.includes('.') || h.includes(':') ||
      /^(0|10|127|169\.254|192\.168|172\.(1[6-9]|2\d|3[01])|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7]))\./.test(h)) {
    throw new Error('Use uma URL HTTPS pública, sem usuário, senha ou parâmetros.');
  }
  return u;
}
export function statusMensagem(atual: string, novo: string) {
  const ordem: Record<string, number> = { enviando: 0, incerto: 0, falhou: 0, enviada: 1, entregue: 2, lida: 3 };
  return (ordem[novo] ?? -1) >= (ordem[atual] ?? -1) ? novo : atual;
}
export function evolutionMensagem(d: any) {
  const key = d.key || {}, jid = key.remoteJid;
  if (!key.id || !jid || jid === 'status@broadcast' || jid.endsWith('@broadcast')) return null;
  let m = d.message || {};
  m = m.ephemeralMessage?.message || m.viewOnceMessage?.message || m;
  const media = m.imageMessage || m.videoMessage || m.audioMessage || m.documentMessage || m.stickerMessage;
  const texto = m.conversation || m.extendedTextMessage?.text || media?.caption || '';
  if (!texto && !media) return null;
  return {
    conversa: { id: jid, nome: jid.endsWith('@g.us') ? undefined : (key.fromMe ? undefined : d.pushName), endereco: jid, grupo: jid.endsWith('@g.us') },
    mensagem: { id: key.id, direcao: key.fromMe ? 'enviada' : 'recebida', texto,
      autor_nome: d.pushName || null, participante: key.participant || key.remoteJid,
      status: key.fromMe ? 'enviada' : 'recebida',
      em: new Date(Number(d.messageTimestamp || Date.now() / 1000) * 1000).toISOString(),
      anexos: media ? [{ nome: media.fileName || 'Anexo', mime: media.mimetype || 'application/octet-stream', pendente: true }] : [] },
    media: media ? { provider: 'evolution', key, message: d.message } : null,
  };
}
export function zernioMensagem(p: any) {
  if (!['message.received', 'message.sent'].includes(p.event) || !p.message?.id || !p.conversation?.id) return null;
  const m = p.message, c = p.conversation;
  return { conversa: { id: c.id, nome: c.participantName || (p.event === 'message.received' ? m.sender?.name : undefined), endereco: c.participantId || (p.event === 'message.received' ? m.sender?.id : undefined), grupo: false },
    mensagem: { id: m.platformMessageId || m.id, direcao: p.event === 'message.sent' ? 'enviada' : 'recebida', texto: m.text || m.message || '',
      participante: m.sender?.id, autor_nome: m.sender?.name, em: m.createdAt || m.sentAt || p.timestamp,
      status: p.event === 'message.sent' ? 'enviada' : 'recebida',
      anexos: (m.attachments || []).map((a: any) => ({ nome: a.name || a.type || 'Anexo', mime: a.mimeType || 'application/octet-stream', pendente: true })) },
    media: m.attachments?.length ? { provider: 'zernio', attachments: m.attachments } : null };
}
export async function hmacValido(raw: string, signature: string, secret: string) {
  if (!secret || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
  const sig = Uint8Array.from(signature.match(/../g)!, h => parseInt(h, 16));
  return crypto.subtle.verify('HMAC', key, sig, new TextEncoder().encode(raw));
}
export async function segredoIgual(a: string, b: string) {
  if (!a || !b) return false;
  const hash = async (s: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));
  const x = await hash(a), y = await hash(b); let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}
