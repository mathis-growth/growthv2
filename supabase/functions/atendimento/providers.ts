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
      const type = attachment?.mime?.split(';')[0] || '';
      // Gravações usam a rota de áudio da Evolution (conversão do provedor).
      // Arquivos de áudio não gravados seguem como mídia normal (sem forçar PTT).
      const voice = attachment?.gravado && type.startsWith('audio/') && !text;
      const payload = voice
        ? { number: cv.externo_id, audio: attachment.url }
        : attachment ? { number: cv.externo_id,
            mediatype: type.startsWith('image/') ? 'image' : type.startsWith('video/') ? 'video' : type.startsWith('audio/') ? 'audio' : 'document',
            mimetype: type, fileName: attachment.nome, caption: text || undefined, media: attachment.url }
          : { number: cv.externo_id, text };
      const r = await evolution(cfg, '/message/' + (voice ? 'sendWhatsAppAudio/' : attachment ? 'sendMedia/' : 'sendText/') + inst, 'POST', payload);
      if (!r.key?.id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return r.key.id;
    },
  },
  zernio: {
    async send(cfg, ch, cv, text, attachment) {
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
        const type = attachment.mime.split('/')[0];
        mediaFields = {
          attachmentUrl:target.toString(),
          attachmentType:['image','video','audio'].includes(type) ? type : 'file',
          ...(type==='application' ? {attachmentName:safeName} : {}),
          // PTT nativo exige OGG/Opus mono; outros áudios são enviados como arquivo de áudio.
          ...(ch.canal==='whatsapp' && attachment.gravado && /^(audio\/ogg)/.test(attachment.mime) ? {voiceNote:true} : {}),
        };
      }
      const r = await zernio(cfg.key, '/inbox/conversations/' + encodeURIComponent(cv.externo_id) + '/messages', 'POST', {
        accountId:ch.externo_id,message:text||'',...mediaFields
      });
      const id = r.data?.messageId || r.messageId;
      if (!id) throw new Error('O provedor não confirmou o identificador da mensagem.');
      return id;
    },
  },
};
