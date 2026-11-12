// Edge única para deploy manual da Central de Atendimento.
// Arquivo autocontido, sem imports relativos.

import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

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
    // O pushName de uma mensagem de grupo é o nome do REMETENTE, nunca do grupo.
    // Não substituir o título do grupo pelo nome de um participante.
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
  if (!['message.received', 'message.sent'].includes(p.event)) return null;
  const m = p.message || {}, c = p.conversation || {};
  // Zernio usa o id interno da conversa em `id` e também expõe o ID
  // específico da plataforma. Aceitamos ambos para não descartar DMs válidas.
  const conversationId = c.id || c.platformConversationId;
  const messageId = m.platformMessageId || m.id;
  if (!conversationId || !messageId) return null;
  const received = p.event === 'message.received';
  const sender = m.sender || p.sender || {};
  return { conversa: { id: conversationId, nome: c.participantName || c.participantUsername || (received ? sender.name : undefined), endereco: c.participantId || (received ? sender.id : undefined), grupo: false },
    mensagem: { id: messageId, direcao: received ? 'recebida' : 'enviada', texto: m.text || m.message || m.content || '',
      participante: sender.id, autor_nome: sender.name, em: m.createdAt || m.sentAt || p.timestamp,
      status: received ? 'recebida' : 'enviada',
      anexos: (m.attachments || []).map((a: any) => ({
        nome: a.name || a.filename || a.type || 'Anexo',
        mime: a.mimeType || a.contentType || ({image:'image/jpeg',audio:'audio/ogg',video:'video/mp4'} as Record<string,string>)[a.type] || 'application/octet-stream',
        pendente: true
      })) },
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
export async function request(url: string, key: string, method = 'GET', body?: unknown, evo = false, timeoutMs = 20000) {
  const r = await fetch(url, { method, redirect: 'error', signal: AbortSignal.timeout(timeoutMs),
    headers: { 'Content-Type': 'application/json', ...(evo ? { apikey: key } : { Authorization: `Bearer ${key}` }) },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const data = await r.json().catch(() => ({}));
  // Nunca devolve corpo bruto: alguns servidores ecoam credenciais nas falhas.
  if (!r.ok) throw new ProviderError(r.status, String(data.code || '').replace(/[^A-Z_]/g,'').slice(0,60));
  return data;
}
export const zernio = (key: string, path: string, method = 'GET', body?: unknown) => request('https://zernio.com/api/v1' + path, key, method, body);
export async function evolution(cfg: any, path: string, method = 'GET', body?: unknown, timeoutMs = 20000) {
  const u = urlPublica(cfg.evolution_url);
  // Bloqueia DNS apontando para redes internas antes de usar a chave do servidor.
  await publicHost(u.hostname);
  return request(u.toString().replace(/\/$/, '') + path, cfg.evolution_key, method, body, true, timeoutMs);
}
export const providers: Record<string, {
  send: (cfg: any, channel: any, conversation: any, text: string, attachment?: any, interactive?: any) => Promise<string>;
}> = {
  evolution: {
    async send(cfg, ch, cv, text, attachment, interactive) {
      const inst = encodeURIComponent(ch.externo_id);
      const type = attachment?.mime?.split(';')[0] || '';
      if (interactive?.buttons?.length) {
        if (ch.canal !== 'whatsapp') throw new Error('Botões ainda não são compatíveis com este canal Evolution.');
        const buttons = interactive.buttons.map((b:any) => b.kind === 'url'
          ? { type: 'url', displayText: b.title, url: b.value }
          : { type: 'reply', displayText: b.title, id: b.value || b.title });
        const r = await evolution(cfg, '/message/sendButtons/' + inst, 'POST', {
          number: cv.externo_id, title: interactive.title || 'Mensagem', description: text,
          footer: interactive.footer || ' ', buttons
        });
        if (!r.key?.id) throw new Error('O provedor não confirmou o identificador da mensagem.');
        return r.key.id;
      }
      // Gravações usam a rota de áudio da Evolution (conversão do provedor).
      // Arquivos de áudio não gravados seguem como mídia normal (sem forçar PTT).
      const voice = attachment?.gravado && type.startsWith('audio/') && !text;
      const payload = voice
        ? { number: cv.externo_id, audio: attachment.url }
        : attachment ? { number: cv.externo_id,
            mediatype: type.startsWith('image/') ? 'image' : type.startsWith('video/') ? 'video' : type.startsWith('audio/') ? 'audio' : 'document',
            mimetype: type, fileName: attachment.nome, caption: text || undefined, media: attachment.url }
          : { number: cv.externo_id, text };
      const r = await evolution(cfg, '/message/' + (voice ? 'sendWhatsAppAudio/' : attachment ? 'sendMedia/' : 'sendText/') + inst, 'POST', payload, attachment?.mime==='video/mp4'?90000:20000);
      if (!r.key?.id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return r.key.id;
    },
  },
  zernio: {
    async send(cfg, ch, cv, text, attachment, interactive) {
      // Zernio usa attachmentUrl/attachmentType, não attachments[] no envio.
      // Faz upload no próprio provedor, sem disponibilizar permanentemente nosso bucket privado.
      let mediaFields: Record<string,unknown> = {};
      if (attachment) {
        const form = new FormData();
        const safeName = String(attachment.nome||'midia').replace(/[\\/\\r\\n]/g,'_').slice(0,140);
        form.append('file',new Blob([attachment.bytes],{type:attachment.mime}),safeName);
        form.append('contentType',attachment.mime.split(';')[0]);
        const uploaded = await fetch('https://zernio.com/api/v1/media/upload-direct',{
          method:'POST',redirect:'error',signal:AbortSignal.timeout(25000),
          headers:{Authorization:'Bearer '+cfg.key},body:form
        });
        const result = await uploaded.json().catch(()=>({}));
        if(!uploaded.ok)throw new ProviderError(uploaded.status,String(result.code||'UPLOAD_FAILED').replace(/[^A-Z_]/gi,'').slice(0,48));
        const target = new URL(String(result.url||''));
        if(target.protocol!=='https:')throw new Error('A Zernio não confirmou uma URL segura para o arquivo.');
        const type = attachment.mime.split('/')[0],attachmentType=['image','video','audio'].includes(type)?type:'file';
        mediaFields = {
          attachmentUrl:target.toString(),
          attachmentType,
          ...(attachmentType==='file' ? {attachmentName:safeName} : {}),
          // PTT nativo exige OGG/Opus mono; outros áudios são enviados como arquivo de áudio.
          ...(ch.canal==='whatsapp' && attachment.gravado && /^(audio\/ogg)/.test(attachment.mime) ? {voiceNote:true} : {}),
        };
      }
      const buttons = Array.isArray(interactive?.buttons) ? interactive.buttons : [];
      const formatted = buttons.length ? buttons.map((b:any) => b.kind === 'url'
        ? { type:'url', title:b.title, url:b.value }
        : { type:'postback', title:b.title, payload:b.value||b.title }) : [];
      if(buttons.length>3)throw new Error('O canal permite até 3 botões por mensagem.');
      const r = await zernio(cfg.key, '/inbox/conversations/' + encodeURIComponent(cv.externo_id) + '/messages', 'POST', {
        accountId:ch.externo_id,message:text||'',...mediaFields,...(formatted.length?{buttons:formatted}:{})
      });
      const id = r.data?.messageId || r.messageId;
      if (!id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return id;
    },
  },
};

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };
const URL_SB = Deno.env.get('SUPABASE_URL')!;
const db = createClient(URL_SB, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (x: unknown, status = 200) => new Response(JSON.stringify(x), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
async function q(p: any): Promise<any> { const { data, error } = await p; if (error) throw new Error(error.message); return data; }
const secret = (ws: string) => q(db.rpc('atd_segredo', { p_ws: ws }));
const zp = () => { const key = Deno.env.get('ZERNIO_API_KEY'); if (!key) throw new Error('ZERNIO_API_KEY não configurada no servidor.'); return key; };
async function channel(id: string, ws?: string) {
  let query = db.from('atd_canais').select('*').eq('id', id);
  if (ws) query = query.eq('workspace_id', ws);
  return q(query.single());
}
