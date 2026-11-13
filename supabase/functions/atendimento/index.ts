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
async function receive(ch: any, normalized: any, historical = false) {
  if (!normalized) return null;
  // A RPC atd_receber serializa pelo canal e resolve a identidade do
  // participante do Instagram dentro da mesma transação que grava a mensagem.
  // Fazer a busca aqui fora permitia que dois webhooks simultâneos criassem
  // duas conversas para o mesmo participante.
  normalized.mensagem.historica = historical;
  const cv = await q(db.rpc('atd_receber', { p_canal: ch.id, p_conversa: normalized.conversa, p_mensagem: normalized.mensagem }));
  if (!normalized.conversa?.grupo && ch.canal === 'whatsapp') {
    await identificarPessoaPorTelefone(ch.workspace_id, cv, normalized.conversa?.endereco || normalized.conversa?.id);
  }
  if (normalized.media) {
    const msg = await q(db.from('atd_mensagens').select('id,anexos').eq('conversa_id', cv).eq('externo_id', normalized.mensagem.id).single());
    if (msg.anexos.some((a: any) => a.pendente)) {
      await q(db.rpc('atd_midia_pendente', { p_mensagem: msg.id, p_origem: {...normalized.media,conversa_id:normalized.conversa.id,externo_id:normalized.mensagem.id} }));
      EdgeRuntime.waitUntil(saveMedia(ch, msg).catch(() => {})); // pendência permanece recuperável
    }
  }
  return cv;
}
function telefoneNormalizado(endereco: unknown) {
  const bruto=String(endereco||'').split('@')[0].replace(/\D/g,'');
  if(bruto.length===10||bruto.length===11)return '55'+bruto;
  return bruto.length>=12&&bruto.length<=13?bruto:null;
}
async function identificarPessoaPorTelefone(ws:string,conversaId:string,endereco:unknown) {
  const telefone=telefoneNormalizado(endereco);if(!telefone)return null;
  const cv=await q(db.from('atd_conversas').select('id,pessoa_id,grupo').eq('id',conversaId).eq('workspace_id',ws).maybeSingle());
  if(!cv||cv.grupo||cv.pessoa_id)return cv?.pessoa_id||null;
  const encontrados=await q(db.from('pessoas').select('id').eq('workspace_id',ws).eq('telefone_norm',telefone).limit(2));
  // Não escolhe arbitrariamente se a base já tiver telefone duplicado.
  if(encontrados.length!==1)return null;
  await q(db.from('atd_conversas').update({pessoa_id:encontrados[0].id}).eq('id',cv.id).eq('workspace_id',ws).is('pessoa_id',null));
  return encontrados[0].id;
}
async function resumoContato(ws:string,conversaId:string) {
  const cv=await q(db.from('atd_conversas').select('id,pessoa_id,endereco,externo_id,grupo,canal_id').eq('id',conversaId).eq('workspace_id',ws).single());
  if(cv.grupo)return {pessoa:null};
  let pessoaId=cv.pessoa_id;
  if(!pessoaId){const ch=await channel(cv.canal_id,ws);if(ch.canal==='whatsapp')pessoaId=await identificarPessoaPorTelefone(ws,cv.id,cv.endereco||cv.externo_id);}
  if(!pessoaId)return {pessoa:null};
  const pessoa=await q(db.from('pessoas').select('id,nome,telefone,email,status_funil,status_cliente,qualificacao,criado_em,convertido_em,campanha_id,utm_campaign,utm_source,utm_medium,utm_content,utm_term,pagina_origem,canal_origem,extras').eq('id',pessoaId).eq('workspace_id',ws).single());
  const [toques,participacoes,alunos,vendas]=await Promise.all([
    q(db.from('pessoa_toques').select('em,campanha_id').eq('workspace_id',ws).eq('pessoa_id',pessoaId).in('tipo',['entrada','captura']).order('em').limit(1)).catch(()=>[]),
    q(db.from('campanha_participacoes').select('campanha_id,entrou_em').eq('workspace_id',ws).eq('pessoa_id',pessoaId).order('entrou_em').limit(1)).catch(()=>[]),
    q(db.from('alunos').select('produto_id,entrou_em,status').eq('workspace_id',ws).eq('pessoa_id',pessoaId).order('entrou_em',{ascending:false}).limit(10)).catch(()=>[]),
    q(db.from('vendas').select('produto_id,data_venda,status').eq('workspace_id',ws).eq('pessoa_id',pessoaId).eq('status','aprovada').order('data_venda',{ascending:false}).limit(10)).catch(()=>[])
  ]);
  const toque=toques[0],participacao=participacoes[0];
  const campanhaId=pessoa.campanha_id||toque?.campanha_id||participacao?.campanha_id;
  const campanha=campanhaId?await q(db.from('campanhas').select('id,nome,produto_id').eq('workspace_id',ws).eq('id',campanhaId).maybeSingle()).catch(()=>null):null;
  const produtoIds=[...new Set([...alunos,...vendas].map((r:any)=>r.produto_id).filter(Boolean))];
  if(campanha?.produto_id)produtoIds.unshift(campanha.produto_id);
  const produtos=produtoIds.length?await q(db.from('produtos').select('id,nome').eq('workspace_id',ws).in('id',[...new Set(produtoIds)])).catch(()=>[]):[];
  const produtoNomes=[...new Set(produtoIds.map(id=>produtos.find((p:any)=>p.id===id)?.nome).filter(Boolean))];
  return {pessoa:{...pessoa,tipo:pessoa.status_funil==='cliente'||alunos.length?'Aluno/Cliente':'Lead',campanha:campanha?.nome||null,
    produto:produtoNomes.join(', ')||null,capturado_em:toque?.em||participacao?.entrou_em||pessoa.criado_em}};
}
function fluxoCompativel(flow:any) {
  if(Array.isArray(flow.fluxo?.nodes)&&flow.fluxo.nodes.length)return flow.fluxo;
  const trigger='legacy-trigger',message='legacy-message';
  return {versao:1,nodes:[{id:trigger,tipo:'gatilho',x:40,y:190,data:{}},{id:message,tipo:'mensagem',x:390,y:190,data:{texto:String(flow.resposta||'')}}],edges:[{origem:trigger,destino:message,saida:'seguir'}]};
}
function aresta(fluxo:any,id:string,saida='seguir') { return fluxo.edges.find((e:any)=>e.origem===id&&e.saida===saida)?.destino||null; }
function templateSlots(tpl:any) {
  const parts=tpl.components||[],header=parts.find((c:any)=>String(c.type).toUpperCase()==='HEADER'),body=parts.find((c:any)=>String(c.type).toUpperCase()==='BODY'),buttons=parts.find((c:any)=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[],slots:any[]=[];
  const add=(text:string,kind:string,index=-1)=>{const numbers=[...new Set([...String(text||'').matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1])))].sort((a,b)=>a-b);if(numbers.some((n,i)=>n!==i+1))throw Error('Variáveis fora da ordem no template aprovado.');numbers.forEach(marker=>slots.push({kind,index,marker}));};
  if(String(header?.format||'TEXT').toUpperCase()==='TEXT')add(header?.text,'header');
  add(body?.text,'body');buttons.forEach((button:any,index:number)=>{if(String(button.type).toUpperCase()==='URL')add(button.url,'url',index);});
  return slots;
}
function templateCampo(p:any,cv:any,key:string) {
  const nome=String(p.nome||cv.nome||'').trim();
  const value=key==='primeiro_nome'?nome.split(/\s+/)[0]:key==='nome'?nome:key==='capturado_em'&&p.capturado_em?new Date(p.capturado_em).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):p[key];
  return String(value??'').trim();
}
async function executarFluxo(ch:any,cv:any,flow:any,run:any,estado:any) {
  const adapter=providers[ch.provedor];if(!adapter)throw new Error('Provedor indisponível para executar o fluxo.');
  const graph=estado.fluxo||fluxoCompativel(flow),nodes=graph.nodes||[],edges=graph.edges||[];
  const snapshot={...estado,fluxo:graph,entrada_texto:String(estado.entrada_texto||''),enviadas:Array.isArray(estado.enviadas)?estado.enviadas:[],visitados:Array.isArray(estado.visitados)?estado.visitados:[]};
  let current=snapshot.no_id||nodes.find((n:any)=>n.tipo==='gatilho')?.id||nodes[0]?.id||null,steps=0;
  const resumo=await resumoContato(ch.workspace_id,cv.id),p=resumo.pessoa||{};
  while(current&&steps++<60){
    const node=nodes.find((n:any)=>n.id===current);if(!node)break;
    if(snapshot.visitados.includes(node.id))throw new Error('O fluxo contém um ciclo entre blocos. Revise as ligações no canvas.');
    snapshot.visitados.push(node.id);
    if(node.tipo==='gatilho'){current=aresta(graph,node.id,'seguir')||nodes.find((n:any)=>n.tipo!=='gatilho')?.id||null;continue;}
    if(node.tipo==='fim')break;
    if(node.tipo==='condicao'){
      const value=String(node.data?.valor||'').trim().toLocaleLowerCase();
      current=String(snapshot.entrada_texto).toLocaleLowerCase().includes(value)?aresta(graph,node.id,'sim'):aresta(graph,node.id,'nao');
      continue;
    }
    const next=aresta(graph,node.id,'seguir');
    if(node.tipo==='espera'){
      if(!next)break;
      const unit=node.data?.unidade||'minutos',max=unit==='segundos'?86400:unit==='minutos'?525600:unit==='horas'?8760:365;
      const count=Math.max(1,Math.min(max,Number(node.data?.quantidade)||1));
      const ms=count*(unit==='dias'?86400000:unit==='horas'?3600000:unit==='minutos'?60000:1000),retomarEm=new Date(Date.now()+ms).toISOString();
      snapshot.no_id=next;
      await q(db.from('atd_automacao_execucoes').update({status:'aguardando',retomar_em:retomarEm,estado:snapshot,erro:null}).eq('id',run.id).eq('status','processando'));
      return 'aguardando';
    }
    if(node.tipo==='template'){
      if(ch.provedor!=='zernio'||ch.canal!=='whatsapp'||!ch.ativo||ch.status!=='conectado')throw Error('O template exige uma conta WhatsApp API oficial conectada.');
      const d=node.data||{},listed=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(ch.externo_id)),templates=listed.templates||listed.data?.templates||[];
      const tpl=templates.find((t:any)=>t.name===d.template_name&&t.language===d.idioma&&t.status==='APPROVED');
      if(!tpl)throw Error('O template deixou de estar aprovado nesta conta.');
      const slots=templateSlots(tpl),keys=Array.isArray(d.campos)?d.campos:[];
      if(slots.length!==keys.length)throw Error('Mapeamento de variáveis incompleto.');
      const params=keys.map((key:string)=>templateCampo(p,cv,key));
      if(params.some((value:string)=>!value||value.length>1024))throw Error('O contato não possui todos os dados exigidos pelo template.');
      const parts=tpl.components||[],header=parts.find((c:any)=>String(c.type).toUpperCase()==='HEADER'),body=parts.find((c:any)=>String(c.type).toUpperCase()==='BODY'),footer=parts.find((c:any)=>String(c.type).toUpperCase()==='FOOTER'),buttons=parts.find((c:any)=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[],format=String(header?.format||'TEXT').toUpperCase(),media=String(d.media_url||'').trim();
      if(['IMAGE','VIDEO','DOCUMENT'].includes(format)&&!media)throw Error('Falta a mídia do cabeçalho do template.');
      const headerMedia=media?{type:format.toLowerCase(),link:media}:null;
      if(headerMedia)urlPublica(media);
      const components:any[]=[];
      for(const kind of ['header','body']){
        const selected=slots.map((s,i)=>({s,value:params[i]})).filter(x=>x.s.kind===kind);
        if(kind==='header'&&headerMedia)components.push({type:'header',parameters:[{type:headerMedia.type,[headerMedia.type]:{link:media}}]});
        else if(selected.length)components.push({type:kind,parameters:selected.map(x=>({type:'text',text:x.value}))});
      }
      slots.forEach((slot,i)=>{if(slot.kind==='url')components.push({type:'button',sub_type:'url',index:String(slot.index),parameters:[{type:'text',text:params[i]}]});});
      let preview=String(body?.text||'');slots.forEach((slot,i)=>{if(slot.kind==='body')preview=preview.replaceAll(`{{${slot.marker}}}`,params[i]);});
      const pending=await q(db.from('atd_mensagens').insert({workspace_id:ch.workspace_id,conversa_id:cv.id,requisicao_id:snapshot.enviadas.length?null:run.id,direcao:'enviada',texto:[String(header?.text||''),preview,String(footer?.text||''),buttons.map((button:any)=>button.text).filter(Boolean).join(' · ')].filter(Boolean).join('\n'),autor_nome:'Automação · '+flow.nome,status:'enviando'}).select('id').single());
      if(!run.mensagem_id){await q(db.from('atd_automacao_execucoes').update({mensagem_id:pending.id}).eq('id',run.id));run.mensagem_id=pending.id;}
      let attempted=false;
      try{
        const opening=String(cv.externo_id).startsWith('pending:');let result:any;
        if(opening){
          const participantId=String(cv.endereco||'').replace(/\D/g,'');if(participantId.length<10||participantId.length>15)throw Error('Telefone inválido para iniciar conversa oficial.');
          attempted=true;
          result=await zernio(zp(),'/inbox/conversations','POST',{accountId:ch.externo_id,participantId,templateName:tpl.name,templateLanguage:tpl.language,templateParams:params,...(headerMedia?{headerMedia}:{})});
          const remote=String(result.data?.conversationId||result.conversationId||'');if(!remote)throw Error('A Zernio não confirmou a sessão da conversa.');
          await q(db.from('atd_conversas').update({externo_id:remote}).eq('id',cv.id).eq('workspace_id',ch.workspace_id).eq('externo_id',cv.externo_id));cv.externo_id=remote;
        }else {attempted=true;result=await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(cv.externo_id)+'/messages','POST',{accountId:ch.externo_id,template:{elements:[{name:tpl.name,language:tpl.language,components}]}});}
        const external=String(result.data?.messageId||result.messageId||'');if(!external)throw Error('A Zernio não confirmou o identificador da mensagem.');
        await q(db.rpc('atd_confirmar_envio',{p_mensagem:pending.id,p_externo:external}));
      }catch(e){const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408),detail=known?String((e as Error).message||'Falha no envio').slice(0,220):'Envio sem confirmação. Confira a Zernio antes de reenviar.';await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:detail}).eq('id',pending.id));const failure=new Error(detail);(failure as any).fluxoIncerto=!known;throw failure;}
      snapshot.enviadas.push(node.id);snapshot.no_id=next;
      await q(db.from('atd_automacao_execucoes').update({estado:snapshot}).eq('id',run.id).eq('status','processando'));
      current=next;continue;
    }
    if(node.tipo==='mensagem'||node.tipo==='botoes'){
      const text=String(node.data?.texto||'').replace(/\{\{nome\}\}/gi,cv.nome||'').replace(/\{\{produto\}\}/gi,p.produto||'').replace(/\{\{campanha\}\}/gi,p.campanha||'').trim();
      const mediaUrl=String(node.data?.media_url||'').trim(),mediaType=String(node.data?.media_type||'').trim();
      const rawButtons=Array.isArray(node.data?.buttons)?node.data.buttons:[];
      const buttons=rawButtons.filter((b:any)=>String(b?.title||'').trim()).map((b:any)=>({kind:b.kind==='url'?'url':'reply',title:String(b.title).trim().slice(0,20),value:String(b.value||'').trim()}));
      if(!text&&!mediaUrl&&!buttons.length)throw new Error('A ação está vazia. Adicione texto, mídia ou botões.');
      if(!ch.ativo||ch.status!=='conectado')throw new Error('Canal desconectado durante a execução do fluxo.');
      if(node.tipo==='botoes'&&(!text||!buttons.length))throw new Error('A ação de botões precisa de uma mensagem e pelo menos um botão.');
      if(node.tipo==='botoes'&&(buttons.length>3||buttons.filter((b:any)=>b.kind==='url').length>1||buttons.some((b:any)=>b.kind==='url')&&buttons.length>1))throw new Error('Use até 3 respostas rápidas ou um único botão de link.');
      if(node.tipo==='botoes'&&buttons.some((b:any)=>b.kind==='url'&&!/^https:\/\//i.test(b.value)))throw new Error('O botão de link precisa de uma URL HTTPS.');
      if(node.tipo==='botoes'&&ch.canal==='instagram'&&ch.provedor!=='zernio')throw new Error('Botões no Instagram exigem conexão Zernio.');
      if(mediaUrl&&(!/^https:\/\//i.test(mediaUrl)||!['imagem','documento','video'].includes(mediaType)))throw new Error('Configure uma URL HTTPS e o tipo de mídia.');
      let attachment:any=null;
      if(mediaUrl){
        const downloaded=await downloadPublicMedia(mediaUrl),bytes=downloaded.bytes,responseMime=downloaded.mime;
        if(responseMime.startsWith('image/')&&bytes.length>5*1024*1024)throw new Error('Imagens devem ter até 5 MB para manter compatibilidade com WhatsApp oficial.');
        const allowed=mediaType==='imagem'?/^image\/(jpeg|png|webp|gif)$/.test(responseMime):mediaType==='video'?responseMime==='video/mp4':/^(application\/(pdf|msword|vnd\.(openxmlformats-officedocument\.(wordprocessingml\.document|spreadsheetml\.sheet|presentationml\.presentation)|ms-excel|ms-powerpoint))|text\/(plain|csv))$/.test(responseMime);
        if(!allowed)throw new Error('O formato do arquivo não corresponde ao tipo selecionado.');
        const nome=String(node.data?.media_nome||'arquivo').replace(/[\\/\r\n]/g,'_').slice(0,150),path=`${ch.workspace_id}/${run.id}/${node.id}`;
        await q(db.storage.from('atendimento').upload(path,bytes,{contentType:responseMime,upsert:true}));
        attachment={path,nome,mime:responseMime,tamanho:bytes.length};
      }
      const registroTexto=[text,...buttons.map((b:any,i:number)=>`${i+1}. ${b.title}${b.kind==='url'?` → ${b.value}`:''}`)].filter(Boolean).join('\n');
      const pending=await q(db.from('atd_mensagens').insert({workspace_id:ch.workspace_id,conversa_id:cv.id,
        requisicao_id:snapshot.enviadas.length?null:run.id,direcao:'enviada',texto:registroTexto,autor_nome:'Automação · '+flow.nome,status:'enviando',anexos:attachment?[attachment]:[]}).select('id').single());
      if(!run.mensagem_id){await q(db.from('atd_automacao_execucoes').update({mensagem_id:pending.id}).eq('id',run.id));run.mensagem_id=pending.id;}
      let attempted=false;
      try{
        const cfg=ch.provedor==='evolution'?await secret(ch.workspace_id):{key:zp()};
        if(attachment){const signed=await q(db.storage.from('atendimento').createSignedUrl(attachment.path,300));attachment={...attachment,url:signed.signedUrl,bytes};}
        attempted=true;
        const external=await adapter.send(cfg,ch,cv,text,attachment,node.tipo==='botoes'?{buttons,title:text,footer:String(node.data?.footer||'').slice(0,60)}:undefined);
        await q(db.rpc('atd_confirmar_envio',{p_mensagem:pending.id,p_externo:external}));
      }catch(e){
        const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408);
        const detail=known?String((e as Error).message||'Falha no envio').slice(0,220):'Envio sem confirmação. Confira o provedor antes de reenviar.';
        await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:detail}).eq('id',pending.id));
        const failure=new Error(detail);(failure as any).fluxoIncerto=!known;throw failure;
      }
      snapshot.enviadas.push(node.id);snapshot.no_id=next;
      await q(db.from('atd_automacao_execucoes').update({estado:snapshot}).eq('id',run.id).eq('status','processando'));
    }
    current=next;
  }
  if(steps>=60)throw new Error('O fluxo ultrapassou o limite de 60 blocos por execução.');
  await q(db.from('atd_automacao_execucoes').update({status:'enviado',retomar_em:null,estado:{...snapshot,no_id:null},erro:null}).eq('id',run.id).eq('status','processando'));
  return 'enviado';
}
async function executarAutomacoes(ch:any,conversaId:string,mensagem:any) {
  if(!conversaId||mensagem?.direcao!=='recebida'||!mensagem?.id)return;
  const automacoes=await q(db.from('atd_automacoes').select('*').eq('workspace_id',ch.workspace_id).eq('ativo',true));
  const cv=await q(db.from('atd_conversas').select('*').eq('id',conversaId).eq('workspace_id',ch.workspace_id).single());if(cv.grupo)return;
  for(const flow of automacoes){
    if(flow.canal_id&&flow.canal_id!==ch.id)continue;
    const keyword=String(flow.gatilho_valor||'').trim().toLocaleLowerCase();
    if(flow.gatilho_tipo==='palavra_chave'&&(!keyword||!String(mensagem.texto||'').toLocaleLowerCase().includes(keyword)))continue;
    const estado={fluxo:fluxoCompativel(flow),entrada_texto:String(mensagem.texto||''),no_id:null,enviadas:[]};
    estado.no_id=estado.fluxo.nodes.find((n:any)=>n.tipo==='gatilho')?.id||estado.fluxo.nodes[0]?.id||null;
    const rows=await q(db.from('atd_automacao_execucoes').upsert({workspace_id:ch.workspace_id,automacao_id:flow.id,
      conversa_id:cv.id,mensagem_gatilho:ch.id+':'+String(mensagem.id),status:'processando',estado},
      {onConflict:'automacao_id,mensagem_gatilho',ignoreDuplicates:true}).select('id,mensagem_id'));
    const run=rows?.[0];if(!run)continue;
    try{await executarFluxo(ch,cv,flow,run,estado);}
    catch(e){const message=String((e as Error).message||'Falha no fluxo').slice(0,220),state=(e as any).fluxoIncerto?'incerto':'erro';await q(db.from('atd_automacao_execucoes').update({status:state,retomar_em:null,erro:message}).eq('id',run.id).eq('status','processando'));console.error('atd automacao falhou',flow.id,state);}
  }
}
async function downloadPublicMedia(url: string) {
  const u = new URL(url); urlPublica(u.origin);
  await publicHost(u.hostname);
  const r = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(15000) });
  if (!r.ok || Number(r.headers.get('content-length')) > MAX_MEDIA) throw new Error('Mídia indisponível ou acima de 8 MB.');
  const reader = r.body!.getReader(); const chunks: Uint8Array[] = []; let size = 0;
  while (true) { const v = await reader.read(); if (v.done) break; size += v.value.length; if (size > MAX_MEDIA) { await reader.cancel(); throw new Error('Mídia acima de 8 MB.'); } chunks.push(v.value); }
  const bytes = new Uint8Array(size); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return {bytes,mime:String(r.headers.get('content-type')||'application/octet-stream').split(';')[0].toLowerCase()};
}
async function mediaBytes(url: string) { return (await downloadPublicMedia(url)).bytes; }
function base64Bytes(s: string) {
  if (s.length > Math.ceil(MAX_MEDIA * 4 / 3) + 100) throw new Error('Arquivo acima de 8 MB.');
  const binary = atob(s.replace(/^data:[^,]+,/, '')); return Uint8Array.from(binary, c => c.charCodeAt(0));
}
async function saveMedia(ch: any, msg: any) {
  const orig = await q(db.rpc('atd_midia_pendente', { p_mensagem: msg.id }));
  if (!orig) return;
  const cfg = orig.provider === 'evolution' ? await secret(ch.workspace_id) : null;
  const attachments = [...msg.anexos];
  for (let i = 0; i < attachments.length; i++) {
    if (!attachments[i].pendente) continue;
    let bytes: Uint8Array;
    if (orig.provider === 'evolution') {
      const r = await evolution(cfg, '/chat/getBase64FromMediaMessage/' + encodeURIComponent(ch.externo_id), 'POST', { message: { key: orig.key, message: orig.message }, convertToMp4: false });
      bytes = base64Bytes(r.base64 || '');
    } else {
      const meta=orig.attachments?.[i]||{}, mediaId=String(meta.payload?.id||'');
      // WhatsApp oficial: mídia privada deve ser baixada com Bearer e accountId.
      if(ch.canal==='whatsapp' && /^[a-zA-Z0-9_-]{1,256}$/.test(mediaId)){
        const mediaUrl='https://zernio.com/api/v1/whatsapp/media/'+encodeURIComponent(mediaId)+'?accountId='+encodeURIComponent(ch.externo_id);
        const resp=await fetch(mediaUrl,{redirect:'error',signal:AbortSignal.timeout(20000),headers:{Authorization:'Bearer '+zp()}});
        if(!resp.ok || Number(resp.headers.get('content-length'))>MAX_MEDIA)throw Error('Mídia WhatsApp indisponível ou acima de 8 MB.');
        const reader=resp.body?.getReader();
        if(!reader)throw Error('Mídia WhatsApp sem conteúdo.');
        const chunks:Uint8Array[]=[], limit=MAX_MEDIA;let count=0;
        while(true){
          const piece=await reader.read();
          if(piece.done)break;
          count+=piece.value.byteLength;
          if(count>limit){await reader.cancel();throw Error('Mídia WhatsApp acima de 8 MB.');}
          chunks.push(piece.value);
        }
        bytes=new Uint8Array(count);let offset=0;
        for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
        const type=String(resp.headers.get('content-type')||'').split(';')[0];
        if(/^(image|audio|video)\//.test(type))attachments[i].mime=type;
      }else{
        try { bytes = await mediaBytes(meta.url); }
        catch {
          const r = await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(orig.conversa_id)+'/messages/'+encodeURIComponent(orig.externo_id)+'/attachments/'+i+'?accountId='+encodeURIComponent(ch.externo_id)+'&format=json');
          bytes = await mediaBytes(r.url);
        }
      }
    }
    if (!bytes.length) throw new Error('Mídia vazia.');
    const path = `${ch.workspace_id}/${msg.id}/${i}`;
    await q(db.storage.from('atendimento').upload(path, bytes, { contentType: String(attachments[i].mime||'application/octet-stream').split(';')[0], upsert: true }));
    attachments[i] = { ...attachments[i], path, pendente: false, tamanho: bytes.length };
  }
  await q(db.from('atd_mensagens').update({ anexos: attachments }).eq('id', msg.id));
}
async function updateDelivery(ch: any, external: string, state: string, conversation?: string) {
  let conversations = db.from('atd_conversas').select('id').eq('canal_id', ch.id);
  if (conversation) conversations = conversations.eq('externo_id', conversation);
  const cvs = await q(conversations);
  if (!cvs.length || !external) return;
  const rows = await q(db.from('atd_mensagens').select('id,status').in('conversa_id', cvs.map((c: any) => c.id)).eq('externo_id', external));
  for (const row of rows) await q(db.from('atd_mensagens').update({ status: statusMensagem(row.status, state) }).eq('id', row.id).eq('status', row.status));
}
async function webhook(req: Request, url: URL, raw: string) {
  const p = JSON.parse(raw);
  if (url.searchParams.get('provider') === 'evolution') {
    const ch = await channel(url.searchParams.get('channel') || '');
    if (ch.provedor !== 'evolution' || !ch.ativo) return json({ ok: false }, 403);
    const cfg = await secret(ch.workspace_id);
    if (!cfg || !await segredoIgual(req.headers.get('x-atd-secret') || '', cfg.webhook_secret) || p.instance !== ch.externo_id) return json({ ok: false }, 401);
    const event = String(p.event || '').toUpperCase().replaceAll('.', '_');
    if (event === 'CONNECTION_UPDATE') await q(db.from('atd_canais').update({ status: p.data?.state === 'open' ? 'conectado' : p.data?.state === 'connecting' ? 'conectando' : 'desconectado' }).eq('id', ch.id));
    if (event === 'GROUPS_UPSERT' || event === 'GROUPS_UPDATE') for (const rawGroup of Array.isArray(p.data) ? p.data : [p.data]) {
      const group = unwrapGroupMeta(rawGroup);
      const id = String(group?.remoteJid || group?.id || group?.jid || group?.groupJid || '').trim();
      if (!id.endsWith('@g.us') || !isJid(id)) continue;
      const name = groupName(group);
      await q(db.rpc('atd_receber', { p_canal: ch.id,
        p_conversa: { id, nome: name && name !== id ? name : undefined, endereco: id, grupo: true } }));
      const kind = groupKind(group), parent = groupParent(group), members=groupMembers(group), metadata:any={};
      if (kind || parent) { metadata.grupo_tipo=kind||'grupo';metadata.grupo_pai_externo_id=parent; }
      if (members!=null) metadata.grupo_membros=members;
      if (Object.keys(metadata).length) await q(db.from('atd_conversas').update(metadata)
        .eq('workspace_id', ch.workspace_id).eq('canal_id', ch.id).eq('externo_id', id));
    }
    if (event === 'MESSAGES_UPSERT') for (const d of Array.isArray(p.data) ? p.data : [p.data]) {
      const normalized=evolutionMensagem(d), cvId=await receive(ch,normalized);
      if(normalized&&cvId&&normalized.mensagem.direcao==='recebida')
        EdgeRuntime.waitUntil(executarAutomacoes(ch,cvId,normalized.mensagem).catch(()=>console.error('atd automacoes worker falhou',ch.id)));
    }
    if (event === 'MESSAGES_UPDATE') for (const d of Array.isArray(p.data) ? p.data : [p.data]) {
      const st: Record<string,string> = { DELIVERY_ACK: 'entregue', READ: 'lida', PLAYED: 'lida', SERVER_ACK: 'enviada', '2':'enviada','3':'entregue','4':'lida','5':'lida' };
      const s = st[d.status || d.update?.status]; if (s) await updateDelivery(ch, d.keyId || d.key?.id, s, d.remoteJid || d.key?.remoteJid);
    }
  } else if (url.searchParams.get('provider') === 'zernio') {
    if (!await hmacValido(raw, req.headers.get('x-zernio-signature') || req.headers.get('x-late-signature') || '', Deno.env.get('ZERNIO_ATENDIMENTO_WEBHOOK_SECRET') || '')) return json({ ok: false }, 401);
    if (p.event === 'webhook.test') return json({ ok: true });
    const accountId = p.account?.id || p.account?.accountId || p.account?._id || p.account?.platformAccountId || '';
    const ch = accountId ? await q(db.from('atd_canais').select('*').eq('provedor','zernio').eq('externo_id',accountId).maybeSingle()) : null;
    if (ch?.ativo) {
      const normalized = zernioMensagem(p);
      const cvId=normalized?await receive(ch,normalized):null;
      if(normalized&&cvId&&normalized.mensagem.direcao==='recebida')
        EdgeRuntime.waitUntil(executarAutomacoes(ch,cvId,normalized.mensagem).catch(()=>console.error('atd automacoes worker falhou',ch.id)));
      const st: Record<string,string> = { 'message.delivered':'entregue','message.read':'lida','message.failed':'falhou' };
      if (st[p.event]) await updateDelivery(ch, p.message?.platformMessageId || p.message?.id, st[p.event], p.conversation?.id || p.conversation?.platformConversationId);
    }
  } else return json({ ok: false }, 400);
  return json({ ok: true });
}
async function zernioCandidates(ws: string) {
  const [connection,linked] = await Promise.all([
    q(db.from('conexoes').select('zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').maybeSingle()),
    q(db.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)').eq('workspace_id',ws).eq('conexoes.plataforma','zernio'))
  ]);
  let profileId=String(connection?.zernio_profile_id||'');
  let response:any;
  if(profileId){
    response=await zernio(zp(),'/accounts?profileId='+encodeURIComponent(profileId));
  }else{
    // Workspaces antigos podem não ter zernio_profile_id; inferi-lo apenas pelas contas já ligadas.
    const all=(await zernio(zp(),'/accounts')).accounts||[];
    const linkedIds=new Set(linked.map((a:any)=>a.id_externo));
    const profiles=new Set(all.filter((a:any)=>linkedIds.has(String(a._id||a.id||a.accountId||'')))
      .map((a:any)=>typeof a.profileId==='object'?(a.profileId?._id||a.profileId?.id||''):(a.profileId||'')).filter(Boolean));
    if(profiles.size!==1)return [];
    profileId=String([...profiles][0]);
    response={accounts:all.filter((a:any)=>String(typeof a.profileId==='object'?(a.profileId?._id||a.profileId?.id||''):(a.profileId||''))===profileId)};
  }
  const accounts=Array.isArray(response?.accounts)?response.accounts:[];
  const normalized=accounts.filter((a:any)=>['instagram','whatsapp'].includes(a.platform))
    .map((a:any)=>({id:String(a._id||a.id||a.accountId||''),canal:a.platform,nome:String(a.displayName||a.username||a.phoneNumber||a._id||a.id||'Conta Zernio').slice(0,120)}))
    .filter((a:any)=>/^[a-f0-9]{24}$/i.test(a.id));
  if(!normalized.length)return [];
  const ids=normalized.map((a:any)=>a.id);
  const [otherLinks,otherChannels]=await Promise.all([
    q(db.from('conexao_contas').select('workspace_id,id_externo,conexoes!inner(plataforma)').eq('conexoes.plataforma','zernio').in('id_externo',ids)),
    q(db.from('atd_canais').select('workspace_id,externo_id').eq('provedor','zernio').in('externo_id',ids))
  ]);
  const occupiedElsewhere=new Set([...otherLinks,...otherChannels].filter((x:any)=>x.workspace_id!==ws).map((x:any)=>x.id_externo||x.externo_id));
  // Mostra contas ainda não importadas para o Growth, sem expor contas de outro workspace.
  return normalized.filter((a:any)=>!occupiedElsewhere.has(a.id));
}
// A primeira associação é explícita por workspace; nunca expor a API Key Zernio.
async function zernioDisponiveis(ws: string) {
  const raw = (await zernio(zp(), '/accounts')).accounts || [];
  const accounts = raw.filter((a: any) => ['instagram','whatsapp'].includes(a.platform) && typeof a._id === 'string');
  const existing = await q(db.from('conexao_contas').select('workspace_id,id_externo,conexoes!inner(plataforma)').eq('conexoes.plataforma','zernio').in('id_externo',accounts.length ? accounts.map((a: any)=>a._id) : ['__nenhuma__']));
  const channels = await q(db.from('atd_canais').select('workspace_id,externo_id').eq('provedor','zernio').in('externo_id',accounts.length ? accounts.map((a: any)=>a._id) : ['__nenhuma__']));
  const occupied = new Set([...existing,...channels].filter((a:any)=>a.workspace_id!==ws).map((a:any)=>a.id_externo || a.externo_id));
  return accounts.filter((a:any)=>!occupied.has(a._id)).map((a:any)=>({
    id:a._id, canal:a.platform, nome:String(a.displayName || a.username || a._id).slice(0,120),
    vinculada:existing.some((x:any)=>x.workspace_id===ws && x.id_externo===a._id)
  }));
}
async function processarTransacionais() {
  const jobs=await q(db.rpc('atd_tx_reservar',{p_limite:20}));
  let enviados=0,erros=0,incertos=0;
  for(const job of jobs){
    let attempted=false;
    try{
      const [pessoa,ch]=await Promise.all([
        q(db.from('pessoas').select('telefone').eq('id',job.pessoa_id).eq('workspace_id',job.workspace_id).single()),
        channel(job.canal_id,job.workspace_id)
      ]);
      if(ch.provedor!=='zernio'||ch.canal!=='whatsapp'||!ch.ativo||ch.status!=='conectado')throw new Error('A conta WhatsApp oficial não está conectada.');
      const participante=String(pessoa.telefone||'').replace(/\D/g,'');
      if(participante.length<10||participante.length>15)throw new Error('O contato não tem um telefone válido para WhatsApp.');
      const params=Array.isArray(job.parametros)?job.parametros.map((x:any)=>String(x||'')):[];
      if(params.length>20||params.some((x:string)=>!x||x.length>1024))throw new Error('Faltam valores para preencher as variáveis do template.');
      const listed=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(ch.externo_id));
      const templates=listed.templates||listed.data?.templates||[];
      if(!templates.some((t:any)=>t.name===job.template_name&&t.language===job.idioma&&t.status==='APPROVED'))throw new Error('O template deixou de estar aprovado nesta conta.');
      attempted=true;
      const result=await zernio(zp(),'/inbox/conversations','POST',{accountId:ch.externo_id,participantId:participante,templateName:job.template_name,templateLanguage:job.idioma,templateParams:params});
      const external=String(result.data?.messageId||result.messageId||'');
      if(!external)throw new Error('A Zernio não confirmou o identificador da mensagem.');
      await q(db.from('atd_envios_transacionais').update({status:'enviado',externo_id:external,enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',job.id).eq('status','processando'));
      enviados++;
    }catch(e){
      const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408);
      const status=known?'erro':'incerto';
      const erro=known?String((e as Error).message||'Falha no envio.').slice(0,220):'Envio sem confirmação. Confira a Zernio antes de reenviar.';
      await q(db.from('atd_envios_transacionais').update({status,atualizado_em:new Date().toISOString(),erro}).eq('id',job.id).eq('status','processando'));
      if(known)erros++;else incertos++;
    }
  }
  return {reservados:jobs.length,enviados,erros,incertos};
}
async function processarAgendamentos(req:Request) {
  // O token fica no banco (RLS + sem GRANT de SELECT para clientes), não no navegador.
  // Evita exigir criação de novos Edge Function Secrets neste projeto.
  const config=await q(db.from('sistema_config').select('valor').eq('chave','atd_agenda_token').maybeSingle());
  const expected=String(config?.valor||'');
  if(!expected||!await segredoIgual(req.headers.get('x-atd-agenda-token')||'',expected))
    return json({erro:'Agendador não autorizado.'},401);
  const jobs=await q(db.rpc('atd_agenda_reservar',{p_limite:20}));
  let enviados=0,erros=0,incertos=0;
  for(const job of jobs){
    let attempted=false;
    let messageId:string|null=null;
    try{
      const cv=await q(db.from('atd_conversas').select('*').eq('id',job.conversa_id).eq('workspace_id',job.workspace_id).single());
      const ch=await channel(cv.canal_id,job.workspace_id);
      if(!ch.ativo||ch.status!=='conectado')throw Error('Canal desconectado no horário programado.');
      const adapter=providers[ch.provedor];if(!adapter)throw Error('Provedor indisponível para envio.');
      const signed=assinatura(job.autor_nome,job.texto,ch.canal);
      const [msg]=await q(db.from('atd_mensagens').upsert({
        workspace_id:job.workspace_id,conversa_id:cv.id,requisicao_id:job.id,
        direcao:'enviada',texto:signed,autor_id:job.autor_id,autor_nome:job.autor_nome,status:'enviando'
      },{onConflict:'workspace_id,requisicao_id',ignoreDuplicates:true}).select());
      if(!msg)throw Error('Envio anterior sem confirmação. Verifique o histórico.');
      messageId=msg.id;
      await q(db.from('atd_agendamentos').update({mensagem_id:msg.id}).eq('id',job.id).eq('status','processando'));
      const cfg=ch.provedor==='evolution'?await secret(job.workspace_id):{key:zp()};
      attempted=true;
      const external=await adapter.send(cfg,ch,cv,signed);
      await q(db.rpc('atd_confirmar_envio',{p_mensagem:msg.id,p_externo:external}));
      await q(db.from('atd_agendamentos').update({status:'enviado',externo_id:external,enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',job.id).eq('status','processando'));
      enviados++;
    }catch(e){
      const known=!attempted||(e instanceof ProviderError && e.status<500 && e.status!==408);
      const state=known?'erro':'incerto';
      await q(db.from('atd_agendamentos').update({status:state,atualizado_em:new Date().toISOString(),erro:known?(e as Error).message.slice(0,220):'Envio sem confirmação. Confira o provedor antes de reenviar.'}).eq('id',job.id).eq('status','processando'));
      if(messageId)await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:known?(e as Error).message.slice(0,220):'Envio sem confirmação.'}).eq('id',messageId).eq('status','enviando'));
      if(known)erros++;else incertos++;
    }
  }
  let transacionais:any={reservados:0,enviados:0,erros:0,incertos:0};
  try{transacionais=await processarTransacionais();}
  catch(e){console.error('atd transacionais worker indisponível',String((e as Error).message||e).slice(0,180));}
  let fluxosRetomados=0,fluxosFalhos=0;
  const due=await q(db.from('atd_automacao_execucoes').select('id,workspace_id,automacao_id,conversa_id,estado')
    .eq('status','aguardando').lte('retomar_em',new Date().toISOString()).order('retomar_em').limit(20));
  for(const row of due){
    const claimed=await q(db.from('atd_automacao_execucoes').update({status:'processando',retomar_em:null})
      .eq('id',row.id).eq('status','aguardando').select('id'));
    if(!claimed.length)continue;
    try{
      const [flow,cv]=await Promise.all([
        q(db.from('atd_automacoes').select('*').eq('id',row.automacao_id).eq('workspace_id',row.workspace_id).single()),
        q(db.from('atd_conversas').select('*').eq('id',row.conversa_id).eq('workspace_id',row.workspace_id).single())
      ]);
      if(!flow.ativo)throw new Error('Fluxo pausado antes do próximo passo.');
      const ch=await channel(cv.canal_id,row.workspace_id);
      await executarFluxo(ch,cv,flow,{id:row.id,mensagem_id:null},row.estado||{});
      fluxosRetomados++;
    }catch(e){
      const state=(e as any).fluxoIncerto?'incerto':'erro';
      await q(db.from('atd_automacao_execucoes').update({status:state,retomar_em:null,erro:String((e as Error).message||'Falha ao retomar fluxo').slice(0,220)}).eq('id',row.id).eq('status','processando'));
      fluxosFalhos++;
    }
  }
  let grupos:any={reservados:0,enviados:0,erros:0,incertos:0};
  try{grupos=await processarDisparosGrupos();}
  catch(e){console.error('atd disparo grupos worker indisponível',String((e as Error).message||e).slice(0,180));}
  let emailAutomacoes:any={reservados:0,enviados:0,aguardando:0,erros:0,incertos:0};
  try{emailAutomacoes=await processarEmailAutomacoes();}
  catch(e){console.error('atd automacoes de e-mail indisponíveis',String((e as Error).message||e).slice(0,180));}
  return json({ok:true,reservados:jobs.length,enviados,erros,incertos,transacionais,fluxosRetomados,fluxosFalhos,grupos,emailAutomacoes});
}
async function processarDisparosGrupos(){
  const jobs=await q(db.rpc('atd_grupo_disparo_reservar',{p_limite:1}));let enviados=0,erros=0,incertos=0;
  for(const job of jobs){let attempted=false,messageId:string|null=null;
    try{
      const [campaign,cv,ch]=await Promise.all([
        q(db.from('atd_disparos_grupos').select('*').eq('id',job.campanha_id).eq('workspace_id',job.workspace_id).single()),
        q(db.from('atd_conversas').select('*').eq('id',job.conversa_id).eq('workspace_id',job.workspace_id).single()),
        channel(job.canal_id,job.workspace_id)
      ]);
      if(!['agendado','em_andamento'].includes(campaign.status))throw Error('Campanha pausada ou cancelada; os envios aguardam revisão.');
      if(cv.canal_id!==ch.id||ch.provedor!=='evolution'||ch.canal!=='whatsapp')throw Error('O destinatário não corresponde a uma instância Evolution deste workspace.');
      if(!ch.ativo||ch.status!=='conectado')throw Error('Este chip está desconectado; campanha pausada para segurança.');
      const signed=String(job.texto??'');
      const pending=await q(db.from('atd_mensagens').upsert({workspace_id:job.workspace_id,conversa_id:cv.id,requisicao_id:job.id,direcao:'enviada',texto:signed,autor_id:campaign.autor_id,autor_nome:campaign.autor_nome,status:'enviando',anexos:campaign.midia_path?[{path:campaign.midia_path,nome:campaign.midia_nome,mime:campaign.midia_mime}]:[]},{onConflict:'workspace_id,requisicao_id',ignoreDuplicates:true}).select().single());
      messageId=pending?.id||null;if(!messageId)throw Error('O envio já existe; confira o histórico da conversa.');
      const attachment=campaign.midia_path?{url:(await q(db.storage.from('atendimento').createSignedUrl(campaign.midia_path,300))).signedUrl,nome:campaign.midia_nome,mime:campaign.midia_mime}:undefined;
      const cfg=await secret(job.workspace_id),adapter=providers.evolution;attempted=true;
      const external=await adapter.send(cfg,ch,cv,signed,attachment);
      await q(db.rpc('atd_confirmar_envio',{p_mensagem:messageId,p_externo:external}));
      await q(db.from('atd_disparos_grupos_itens').update({status:'enviado',externo_id:external,enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString()}).eq('id',job.id).eq('status','processando'));enviados++;
    }catch(e){const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408),status=known?'erro':'incerto',detail=known?String((e as Error).message||'Falha no envio.').slice(0,220):'Envio sem confirmação. Confira a conversa na Evolution antes de reenviar.';
      await q(db.from('atd_disparos_grupos_itens').update({status,erro:detail,atualizado_em:new Date().toISOString()}).eq('id',job.id).eq('status','processando'));
      if(messageId)await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:detail}).eq('id',messageId).eq('status','enviando'));
      await q(db.from('atd_disparos_grupos').update({status:known?'em_andamento':'pausado',atualizado_em:new Date().toISOString()}).eq('id',job.campanha_id).eq('status','em_andamento'));
      if(known)erros++;else incertos++;
    }
  }
  return {reservados:jobs.length,enviados,erros,incertos};
}
async function processarDisparosGruposAgendados(req:Request){
  const config=await q(db.from('sistema_config').select('valor').eq('chave','atd_agenda_token').maybeSingle());
  const expected=String(config?.valor||'');
  if(!expected||!await segredoIgual(req.headers.get('x-atd-agenda-token')||'',expected))
    return json({erro:'Agendador não autorizado.'},401);
  return json({ok:true,grupos:await processarDisparosGrupos()});
}
async function qrSharePublico(b:any){
  const token=String(b.token||'');
  if(!/^[A-Za-z0-9_-]{43}$/.test(token))return json({erro:'Este link de conexão é inválido.'},404);
  const bytes=Uint8Array.from(atob(token.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
  const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));
  const hash=[...digest].map(x=>x.toString(16).padStart(2,'0')).join('');
  const share=await q(db.from('atd_qr_compartilhamentos').select('id,workspace_id,canal_id,expira_em,usado_em,revogado_em').eq('token_hash',hash).maybeSingle());
  if(!share||share.revogado_em||share.usado_em||new Date(share.expira_em).getTime()<=Date.now())return json({erro:'O link expirou ou já foi utilizado. Peça um novo link ao administrador.'},410);
  const ch=await q(db.from('atd_canais').select('id,workspace_id,nome,provedor,canal,externo_id,ativo,status').eq('id',share.canal_id).eq('workspace_id',share.workspace_id).maybeSingle());
  if(!ch||!ch.ativo||ch.provedor!=='evolution'||ch.canal!=='whatsapp')return json({erro:'Esta conexão não está mais disponível.'},410);
  const cfg=await secret(ch.workspace_id);if(!cfg)return json({erro:'A conexão Evolution não está configurada.'},409);
  const inst=encodeURIComponent(ch.externo_id);
  try{
    const state=await evolution(cfg,'/instance/connectionState/'+inst),current=state.instance?.state||state.state;
    if(current==='open'){
      await q(db.from('atd_canais').update({status:'conectado'}).eq('id',ch.id).eq('workspace_id',ch.workspace_id));
      await q(db.from('atd_qr_compartilhamentos').update({usado_em:new Date().toISOString()}).eq('id',share.id).is('usado_em',null));
      return json({status:'conectado',nome:ch.nome});
    }
    const result=await evolution(cfg,'/instance/connect/'+inst);
    let qr=String(result.base64||result.qrcode?.base64||'');
    if(qr&&!qr.startsWith('data:image/'))qr='data:image/png;base64,'+qr;
    if(qr&&!/^data:image\/(?:png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(qr))qr='';
    return json({status:current==='connecting'?'aguardando_leitura':'aguardando_leitura',nome:ch.nome,qrcode:qr,expira_em:share.expira_em});
  }catch(e){
    if(e instanceof ProviderError&&e.status<500)return json({erro:'Não foi possível gerar o QR Code. Gere outro link ou confira o servidor Evolution.'},502);
    throw e;
  }
}
async function conviteGrupoPublico(b:any){
  const token=String(b.token||'');
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token))return json({erro:'Link de campanha inválido.'},404);
  const reserved=await q(db.rpc('atd_grupo_campanha_reservar',{p_token:token})),campaign=reserved?.[0];
  if(!campaign)return json({erro:'Este link está desativado ou ainda não tem grupos disponíveis.'},410);
  const ids:string[]=campaign.conversas||[],groups:any[]=[];
  for(let offset=0;offset<ids.length;offset+=100)groups.push(...await q(db.from('atd_conversas').select('id,canal_id,externo_id,grupo,grupo_tipo,grupo_membros').eq('workspace_id',campaign.workspace_id).in('id',ids.slice(offset,offset+100))));
  const channelIds=[...new Set(groups.map(g=>g.canal_id))],channels:any[]=[];
  for(let offset=0;offset<channelIds.length;offset+=100)channels.push(...await q(db.from('atd_canais').select('id,externo_id,provedor,canal,ativo,status').eq('workspace_id',campaign.workspace_id).in('id',channelIds.slice(offset,offset+100))));
  const byGroup=new Map(groups.map(g=>[g.id,g])),byChannel=new Map(channels.map(ch=>[ch.id,ch]));
  const start=Number((BigInt(campaign.rodada)-1n)%BigInt(ids.length)),cfg=await secret(campaign.workspace_id);
  if(cfg)for(let offset=0,checked=0;offset<ids.length&&checked<12;offset++){
    const group=byGroup.get(ids[(start+offset)%ids.length]),ch=group&&byChannel.get(group.canal_id);
    if(!group?.grupo||group.grupo_tipo==='comunidade'||Number(group.grupo_membros)>=campaign.limite_membros||!/^\d[\d-]{4,39}@g\.us$/.test(group.externo_id)||!ch?.ativo||ch.status!=='conectado'||ch.provedor!=='evolution'||ch.canal!=='whatsapp')continue;
    checked++;
    try{
      const instance=encodeURIComponent(ch.externo_id),params='?'+new URLSearchParams({groupJid:group.externo_id});
      const metadata=await evolution(cfg,'/group/findGroupInfos/'+instance+params,'GET',undefined,4500),members=groupMembers(metadata);
      if(members===null||members>=campaign.limite_membros)continue;
      const invite=await evolution(cfg,'/group/inviteCode/'+instance+params,'GET',undefined,4500),code=String(invite?.inviteCode||invite?.data?.inviteCode||'');
      if(!/^[A-Za-z0-9]{22}$/.test(code))continue;
      await q(db.from('atd_conversas').update({grupo_membros:members}).eq('workspace_id',campaign.workspace_id).eq('id',group.id));
      await q(db.from('atd_grupo_campanha_acessos').insert({workspace_id:campaign.workspace_id,campanha_id:campaign.campanha_id,conversa_id:group.id,status:'redirecionado'}));
      return json({url:'https://chat.whatsapp.com/'+code});
    }catch(error){console.warn('Convite de grupo indisponível',{campanha:campaign.campanha_id,grupo:group.id,erro:String((error as Error).message||error).slice(0,120)});}
  }
  await q(db.from('atd_grupo_campanha_acessos').insert({workspace_id:campaign.workspace_id,campanha_id:campaign.campanha_id,status:'indisponivel'}));
  return json({erro:'Os grupos desta campanha estão temporariamente indisponíveis. Tente novamente mais tarde.'},503);
}
function emailFiltroAplica(p:any,f:any){if(f?.tipo&&p.status_funil!==f.tipo)return false;if(f?.qualificacao&&p.qualificacao!==f.qualificacao)return false;if(f?.campanha_id&&p.campanha_id!==f.campanha_id)return false;if(f?.tag&&!(Array.isArray(p.tags)?p.tags:[]).includes(f.tag))return false;return true;}
function htmlSeguro(v:string){return v.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]||c));}
function emailPersonalizar(s:string,p:any){const n=String(p.nome||'').trim(),map:Record<string,string>={nome:n,primeiro_nome:n.split(/\s+/)[0]||'',email:String(p.email||'')};return s.replace(/\{\{\s*(nome|primeiro_nome|email)\s*\}\}/gi,(_m,k)=>htmlSeguro(map[String(k).toLowerCase()]||''));}
function emailSanitizar(html:string){return html.replace(/<\s*(script|iframe|object|embed|form)\b[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi,'').replace(/\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi,'').replace(/(href|src)\s*=\s*(["'])\s*javascript:[\s\S]*?\2/gi,'$1="#"');}
async function resendDomains(path:string,method='GET',body?:any){const key=Deno.env.get('RESEND_API_KEY')||'';if(!key)throw new Error('Configure RESEND_API_KEY nas secrets da Edge.');const r=await fetch('https://api.resend.com/domains'+path,{method,headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json().catch(()=>({}));if(!r.ok)throw new Error(String(data.message||data.name||'Não foi possível consultar o Resend.').slice(0,220));return data;}
async function processarEmails(req:Request){
  const cfg=await q(db.from('sistema_config').select('valor').eq('chave','atd_agenda_token').maybeSingle()),expected=String(cfg?.valor||'');
  if(!expected||!await segredoIgual(req.headers.get('x-atd-agenda-token')||'',expected))return json({erro:'Agendador não autorizado.'},401);
  const key=Deno.env.get('RESEND_API_KEY')||'';if(!key)return json({erro:'Configure RESEND_API_KEY nas secrets da Edge.'},500);
  const due=await q(db.from('atd_email_envios').select('campanha_id').eq('status','pendente').lte('enviar_em',new Date().toISOString()).order('enviar_em').limit(1000)),ids=[...new Set(due.map((x:any)=>x.campanha_id))];let interval=10;
  if(ids.length){const configs=await q(db.from('atd_email_campanhas').select('intervalo_segundos').in('id',ids));if(configs.length)interval=Math.max(1,Math.min(...configs.map((c:any)=>Number(c.intervalo_segundos)||10)));}
  const jobs=await q(db.rpc('atd_email_reservar',{p_limite:Math.max(1,Math.min(20,Math.floor(25/interval)))}));let enviados=0,ignorados=0,erros=0,incertos=0;
  for(let i=0;i<jobs.length;i++){const job=jobs[i];let attempted=false,waitInterval=interval;try{
    const campaign=await q(db.from('atd_email_campanhas').select('status,intervalo_segundos').eq('id',job.campanha_id).eq('workspace_id',job.workspace_id).single());
    waitInterval=Math.max(1,Math.min(30,Number(campaign.intervalo_segundos)||interval));
    if(campaign.status==='cancelada'){await q(db.from('atd_email_envios').update({status:'cancelado',atualizado_em:new Date().toISOString()}).eq('id',job.id).eq('status','processando'));continue;}
    const sender=await q(db.from('atd_email_config').select('dominio,resend_domain_id,email_remetente,status_dominio').eq('workspace_id',job.workspace_id).single());if(sender.status_dominio!=='verified')throw new Error('O domínio de envio deste workspace ainda não foi verificado no Resend.');
    const p=await q(db.from('pessoas').select('id,nome,email,status_funil,qualificacao,campanha_id,tags').eq('id',job.pessoa_id).eq('workspace_id',job.workspace_id).single());
    if(!emailFiltroAplica(p,job.condicao)){await q(db.from('atd_email_envios').update({status:'ignorado',atualizado_em:new Date().toISOString(),erro:'Contato deixou de atender aos filtros da transmissão.'}).eq('id',job.id).eq('status','processando'));ignorados++;continue;}
    const to=String(p.email||'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to))throw new Error('O contato está sem um e-mail válido.');
    attempted=true;const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({from:sender.email_remetente,to,subject:emailPersonalizar(job.assunto,p),html:emailPersonalizar(job.corpo_html,p),tags:[{name:'growth_workspace',value:String(job.workspace_id).slice(0,50)},{name:'growth_campaign',value:String(job.campanha_id).slice(0,50)}]})});
    const payload=await response.json().catch(()=>({}));if(!response.ok)throw Object.assign(new Error(String(payload.message||payload.error||'O Resend recusou o envio.').slice(0,220)),{status:response.status});const external=String(payload.id||'');if(!external)throw new Error('O Resend não confirmou o identificador do e-mail.');
    await q(db.from('atd_email_envios').update({status:'enviado',email:to,externo_id:external,enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',job.id).eq('status','processando'));enviados++;
  }catch(e){const status=Number((e as any).status||0),known=!attempted||(status>0&&status<500&&status!==408),state=known?'erro':'incerto';await q(db.from('atd_email_envios').update({status:state,atualizado_em:new Date().toISOString(),erro:known?String((e as Error).message||'Falha no envio.').slice(0,220):'Envio sem confirmação. Confira o Resend antes de reenviar.'}).eq('id',job.id).eq('status','processando'));if(known)erros++;else incertos++;}
    if(i<jobs.length-1)await new Promise(resolve=>setTimeout(resolve,waitInterval*1000));
  }
  const campaigns=await q(db.from('atd_email_campanhas').select('id,status').in('status',['agendada','em_execucao']).limit(100));for(const c of campaigns){const left=await q(db.from('atd_email_envios').select('id',{count:'exact',head:true}).eq('campanha_id',c.id).in('status',['pendente','processando']));if((left.count||0)===0)await q(db.from('atd_email_campanhas').update({status:'concluida',atualizado_em:new Date().toISOString()}).eq('id',c.id).in('status',['agendada','em_execucao']));else if(enviados)await q(db.from('atd_email_campanhas').update({status:'em_execucao',atualizado_em:new Date().toISOString()}).eq('id',c.id).eq('status','agendada'));}
  return json({reservados:jobs.length,enviados,ignorados,erros,incertos});
}
function emailAutomacaoValor(p:any,evento:any,campo:string){
  if(campo==='tipo')return p.status_funil==='cliente'?'cliente':'lead';
  if(campo==='qualificacao')return String(p.qualificacao||'');
  if(campo==='campanha')return String(evento.campanha||p.utm_campaign||'');
  if(campo==='produto')return String(evento.produto||'');
  if(campo==='pesquisa')return String(evento.pesquisa||'');
  return '';
}
function emailAutomacaoPersonalizar(value:string,p:any,evento:any){
  const nome=String(p.nome||'').trim(),map:Record<string,string>={nome,primeiro_nome:nome.split(/\s+/)[0]||'',email:String(p.email||''),telefone:String(p.telefone||''),produto:String(evento.produto||''),campanha:String(evento.campanha||''),pesquisa:String(evento.pesquisa||''),data_venda:String(evento.data_venda||''),valor_venda:String(evento.valor_venda||''),capturado_em:String(evento.capturado_em||'')};
  return String(value||'').replace(/\{\{\s*(nome|primeiro_nome|email|telefone|produto|campanha|pesquisa|data_venda|valor_venda|capturado_em)\s*\}\}/gi,(_m,k)=>htmlSeguro(map[String(k).toLowerCase()]||''));
}
function emailAutomacaoDestino(flow:any,id:string,saida='seguir'){return flow.edges?.find((e:any)=>e.origem===id&&e.saida===saida)?.destino||null;}
async function executarEmailAutomacao(row:any){
  const state={...(row.estado||{})},flow=state.fluxo||{},nodes=flow.nodes||[],p=await q(db.from('pessoas').select('id,nome,email,telefone,status_funil,qualificacao,campanha_id,tags,extras').eq('id',row.pessoa_id).eq('workspace_id',row.workspace_id).single()),evento=state.evento||{};
  let current=state.no_id||nodes.find((n:any)=>n.tipo==='gatilho')?.id||null,steps=0,activeLog:string|null=null,attempted=false;
  try{
    while(current&&steps++<50){
      const node=nodes.find((n:any)=>n.id===current);if(!node)break;
      if(Array.isArray(state.visitados)&&state.visitados.includes(node.id))throw new Error('O fluxo contém um ciclo entre blocos. Revise as ligações no canvas.');
      state.visitados=Array.isArray(state.visitados)?state.visitados:[];state.visitados.push(node.id);
      if(node.tipo==='gatilho'){current=emailAutomacaoDestino(flow,node.id)||nodes.find((n:any)=>n.tipo!=='gatilho')?.id||null;continue;}
      if(node.tipo==='fim')break;
      const next=emailAutomacaoDestino(flow,node.id);
      if(node.tipo==='espera'){
        if(!next)break;const minutos=Math.min(525600,Math.max(1,Number(node.data?.minutos)||1));state.no_id=next;
        await q(db.from('atd_email_automacao_execucoes').update({status:'aguardando',retomar_em:new Date(Date.now()+minutos*60000).toISOString(),estado:state,erro:null,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));return 'aguardando';
      }
      if(node.tipo==='condicao'){
        const value=emailAutomacaoValor(p,evento,String(node.data?.campo||'' )).toLocaleLowerCase(),needle=String(node.data?.valor||'').trim().toLocaleLowerCase(),matched=(node.data?.operador==='igual'?value===needle:value.includes(needle));
        current=emailAutomacaoDestino(flow,node.id,matched?'sim':'nao');continue;
      }
      if(node.tipo==='email'){
        const to=String(p.email||'').trim().toLowerCase(),subject=emailAutomacaoPersonalizar(node.data?.assunto,p,evento),body=emailSanitizar(emailAutomacaoPersonalizar(node.data?.html,p,evento));
        if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to))throw new Error('O contato não tem um e-mail válido.');
        const [sender,key]=await Promise.all([q(db.from('atd_email_config').select('dominio,email_remetente,status_dominio').eq('workspace_id',row.workspace_id).single()),Promise.resolve(Deno.env.get('RESEND_API_KEY')||'')]);
        if(sender.status_dominio!=='verified')throw new Error('O domínio de e-mail deste workspace ainda não foi verificado no Resend.');if(!key)throw new Error('Configure RESEND_API_KEY nas secrets da Edge.');
        const old=await q(db.from('atd_email_automacao_envios').select('id,status').eq('execucao_id',row.id).eq('node_id',String(node.id)).maybeSingle());
        if(old){if(old.status==='enviado'){current=next;continue;}throw Object.assign(new Error('Envio anterior deste bloco sem confirmação. Confira o histórico antes de repetir.'),{fluxoIncerto:true});}
        const log=await q(db.from('atd_email_automacao_envios').insert({workspace_id:row.workspace_id,execucao_id:row.id,pessoa_id:p.id,node_id:String(node.id),email:to,assunto:subject,status:'processando'}).select('id').single());activeLog=log.id;
        attempted=true;
        const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({from:sender.email_remetente,to,subject,html:body,tags:[{name:'growth_workspace',value:String(row.workspace_id).slice(0,50)},{name:'growth_automation',value:String(row.automacao_id).slice(0,50)}]})});
        const result=await response.json().catch(()=>({}));if(!response.ok)throw Object.assign(new Error(String(result.message||result.error||'O Resend recusou o envio.').slice(0,220)),{status:response.status});
        if(!result.id)throw new Error('O Resend não confirmou o identificador do e-mail.');
        await q(db.from('atd_email_automacao_envios').update({status:'enviado',externo_id:String(result.id),enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',activeLog));activeLog=null;
      }
      current=next;state.no_id=current;
      await q(db.from('atd_email_automacao_execucoes').update({estado:state,retomar_em:new Date(Date.now()+10*60000).toISOString(),atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));
    }
    if(steps>=50)throw new Error('O fluxo ultrapassou o limite de 50 blocos por execução.');
    await q(db.from('atd_email_automacao_execucoes').update({status:'enviado',retomar_em:new Date().toISOString(),estado:{...state,no_id:null},erro:null,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));return 'enviado';
  }catch(e){
    const uncertain=(e as any).fluxoIncerto===true||(attempted&&(!Number((e as any).status)||Number((e as any).status)>=500||Number((e as any).status)===408)),status=uncertain?'incerto':'erro',detail=uncertain?'Envio sem confirmação. Confira o Resend antes de reenviar.':String((e as Error).message||'Falha no fluxo de e-mail.').slice(0,220);
    if(activeLog)await q(db.from('atd_email_automacao_envios').update({status:uncertain?'incerto':'erro',erro:detail,atualizado_em:new Date().toISOString()}).eq('id',activeLog));
    await q(db.from('atd_email_automacao_execucoes').update({status,retomar_em:new Date().toISOString(),erro:detail,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));throw e;
  }
}
async function processarEmailAutomacoes(){
  const rows=await q(db.rpc('atd_email_automacao_reservar',{p_limite:10}));let enviados=0,aguardando=0,erros=0,incertos=0;
  for(const row of rows){try{const status=await executarEmailAutomacao(row);if(status==='aguardando')aguardando++;else enviados++;}catch(e){if((e as any).fluxoIncerto)incertos++;else erros++;console.error('atd email automacao falhou',row.automacao_id,String((e as Error).message||'').slice(0,160));}}
  return {reservados:rows.length,enviados,aguardando,erros,incertos};
}
async function handle(req: Request, b: any) {
  const userDb = createClient(URL_SB, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('authorization') || '' } }, auth: { persistSession:false } });
  const { data: { user }, error } = await userDb.auth.getUser();
  if (error || !user) return json({ erro: 'Faça login novamente.' },401);
  const ctx = await q(userDb.rpc('atd_contexto', { p_ws:b.workspace_id }));
  const read = ['contexto','config','status','mensagens','anexo','zernio-contas','identidades','avatar','avatars','channel-avatar','templates-list','rapidas-list','agendamentos-list','automacoes-list','automacoes-execucoes','contato-resumo','disparos-grupos-list','disparos-segmentos-list','grupo-campanhas-list','grupo-campanha-grupo-info','grupos-busca-status','email-transmissao-list','email-dominios-list','email-dominio-get','email-automacoes-list'];
  if (!read.includes(b.action) && !ctx.editar) return json({ erro:'Sem permissão para editar Atendimento.' },403);
  const admins = ['config','salvar-config','remover-config','criar-instancia','conectar','status','zernio-contas','zernio-vincular','zernio-webhooks','zernio-disponiveis','zernio-conectar','webhook','desativar','excluir-instancia','exibir-arquivados','templates-create','templates-update','templates-delete','templates-mapping-save','canal-salvar','qr-share-create','email-dominio-create','email-dominio-verify','email-dominio-remetente-save'];
  if (admins.includes(b.action) && !ctx.admin) return json({ erro:'Somente administradores gerenciam conexões.' },403);
  const ws = b.workspace_id;
  if(b.action==='email-dominios-list'){
    const config=await q(db.from('atd_email_config').select('dominio,resend_domain_id,email_remetente,status_dominio').eq('workspace_id',ws).maybeSingle());if(!config)return json({data:[]});
    const detail=await resendDomains('/'+encodeURIComponent(config.resend_domain_id));detail.email_remetente=config.email_remetente;await q(db.from('atd_email_config').update({status_dominio:String(detail.status||config.status_dominio),atualizado_em:new Date().toISOString()}).eq('workspace_id',ws));return json({data:[detail]});
  }
  if(b.action==='email-dominio-get'){const id=String(b.id||'').replace(/[^a-zA-Z0-9_-]/g,'');const config=await q(db.from('atd_email_config').select('resend_domain_id,email_remetente').eq('workspace_id',ws).single());if(!id||id!==config.resend_domain_id)throw new Error('Este domínio não pertence ao workspace atual.');const detail=await resendDomains('/'+encodeURIComponent(id));detail.email_remetente=config.email_remetente;return json(detail);}
  if(b.action==='email-dominio-create'){
    const name=String(b.domain||'').trim().toLowerCase().replace(/^https?:\/\//,'').replace(/\/$/,'');if(!/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(name))throw new Error('Informe um domínio válido, sem protocolo ou caminho.');
    const from=String(b.from_email||'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(from)||!from.endsWith('@'+name))throw new Error('Informe o e-mail remetente usando exatamente o domínio do cliente.');
    const list=await resendDomains(''),existing=(list.data||[]).find((d:any)=>String(d.name).toLowerCase()===name);let detail:any;
    if(existing){const owner=await q(db.from('atd_email_config').select('workspace_id').eq('resend_domain_id',existing.id).maybeSingle());if(owner&&owner.workspace_id!==ws)throw new Error('Este domínio já está vinculado a outro workspace.');detail=await resendDomains('/'+encodeURIComponent(existing.id));}
    else detail=await resendDomains('', 'POST',{name,region:'sa-east-1',capabilities:{sending:'enabled',receiving:'disabled'}});
    await q(db.from('atd_email_config').upsert({workspace_id:ws,dominio:name,resend_domain_id:detail.id,email_remetente:from,status_dominio:String(detail.status||'not_started'),atualizado_em:new Date().toISOString()},{onConflict:'workspace_id'}));return json(detail);
  }
  if(b.action==='email-dominio-verify'){const id=String(b.id||'').replace(/[^a-zA-Z0-9_-]/g,'');const config=await q(db.from('atd_email_config').select('resend_domain_id,email_remetente').eq('workspace_id',ws).single());if(!id||id!==config.resend_domain_id)throw new Error('Este domínio não pertence ao workspace atual.');await resendDomains('/'+encodeURIComponent(id)+'/verify','POST',{});const detail=await resendDomains('/'+encodeURIComponent(id));await q(db.from('atd_email_config').update({status_dominio:String(detail.status||'not_started'),atualizado_em:new Date().toISOString()}).eq('workspace_id',ws));detail.email_remetente=config.email_remetente;return json(detail);}
  if(b.action==='email-dominio-remetente-save'){const config=await q(db.from('atd_email_config').select('dominio').eq('workspace_id',ws).single()),from=String(b.from_email||'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(from)||!from.endsWith('@'+config.dominio))throw new Error('Use um endereço dentro do domínio autenticado deste workspace.');await q(db.from('atd_email_config').update({email_remetente:from,atualizado_em:new Date().toISOString()}).eq('workspace_id',ws));return json({ok:true,email_remetente:from});}
  if(b.action==='email-transmissao-list'){
    const campanhas=await q(db.from('atd_email_campanhas').select('id,nome,inicio_em,fuso,intervalo_segundos,status,filtros,criado_em').eq('workspace_id',ws).order('criado_em',{ascending:false}).limit(30));
    const ids=campanhas.map((c:any)=>c.id);const envios=ids.length?await q(db.from('atd_email_envios').select('id,campanha_id,pessoa_id,etapa,enviar_em,email,assunto,status,erro,enviado_em').eq('workspace_id',ws).in('campanha_id',ids).order('enviar_em').limit(3000)):[];
    return json({campanhas,envios});
  }
  if(b.action==='email-automacoes-list'){
    const automacoes=await q(db.from('atd_email_automacoes').select('id,nome,evento,fluxo,ativo,criado_em,atualizado_em').eq('workspace_id',ws).order('atualizado_em',{ascending:false}).limit(200));
    const ids=automacoes.map((x:any)=>x.id),execucoes=ids.length?await q(db.from('atd_email_automacao_execucoes').select('id,automacao_id,pessoa_id,origem,status,retomar_em,erro,executado_em').eq('workspace_id',ws).in('automacao_id',ids).order('executado_em',{ascending:false}).limit(200)):[];
    const envios=ids.length?await q(db.from('atd_email_automacao_envios').select('id,execucao_id,pessoa_id,node_id,email,assunto,status,erro,enviado_em,criado_em').eq('workspace_id',ws).in('execucao_id',execucoes.map((x:any)=>x.id).length?execucoes.map((x:any)=>x.id):['00000000-0000-0000-0000-000000000000']).order('criado_em',{ascending:false}).limit(500)):[];
    return json({automacoes,execucoes,envios});
  }
  if(b.action==='email-automacoes-save'){
    const nome=String(b.nome||'').trim(),evento=['cadastro','pesquisa','venda'].includes(b.evento)?b.evento:'',flow=b.fluxo&&typeof b.fluxo==='object'?b.fluxo:null;
    if(!nome||nome.length>120||!evento||!flow||!Array.isArray(flow.nodes)||!Array.isArray(flow.edges))throw Error('Informe nome, gatilho e canvas válido para a automação de e-mail.');
    if(flow.nodes.length>50||flow.edges.length>100)throw Error('O canvas aceita até 50 blocos e 100 ligações.');
    const nodeIds=new Set<string>();
    for(const node of flow.nodes){
      if(!node||!/^[0-9a-f-]{36}$/i.test(String(node.id||''))||nodeIds.has(node.id)||!['gatilho','email','espera','condicao','fim'].includes(node.tipo))throw Error('Bloco inválido no canvas de e-mail.');
      nodeIds.add(node.id);const x=Number(node.x),y=Number(node.y);if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>50000||y>50000)throw Error('Posição de bloco inválida.');
      if(node.tipo==='email'){
        const subject=String(node.data?.assunto||'').trim(),html=emailSanitizar(String(node.data?.html||'').trim());
        if(!subject||subject.length>180||!html||html.length>100000)throw Error('Cada bloco de e-mail precisa de assunto e conteúdo HTML (até 100.000 caracteres).');
        node.data={...node.data,assunto:subject,html};
      }
      if(node.tipo==='espera'&&(!Number.isInteger(Number(node.data?.minutos))||Number(node.data.minutos)<1||Number(node.data.minutos)>525600))throw Error('A espera deve ficar entre 1 minuto e 1 ano.');
      if(node.tipo==='condicao'&&(!['tipo','qualificacao','campanha','produto','pesquisa'].includes(node.data?.campo)||!['igual','contem'].includes(node.data?.operador)||!String(node.data?.valor||'').trim()||String(node.data.valor).length>120))throw Error('Configure o campo, a condição e o valor do filtro.');
    }
    const triggers=flow.nodes.filter((n:any)=>n.tipo==='gatilho');
    if(triggers.length!==1||!flow.nodes.some((n:any)=>n.tipo==='email'))throw Error('O canvas precisa ter um gatilho e ao menos um bloco de e-mail.');
    const byId=new Map<string,any>(flow.nodes.map((n:any)=>[String(n.id),n] as [string,any])),connections=new Set<string>(),adjacency=new Map<string,string[]>();
    for(const edge of flow.edges){
      const from=byId.get(edge.origem),to=byId.get(edge.destino),branches=from?.tipo==='condicao'?['sim','nao']:from?.tipo==='fim'?[]:['seguir'],key=String(edge.origem)+'|'+String(edge.saida);
      if(!from||!to||edge.origem===edge.destino||!branches.includes(edge.saida)||connections.has(key))throw Error('Ligação inválida no canvas.');
      connections.add(key);adjacency.set(edge.origem,[...(adjacency.get(edge.origem)||[]),edge.destino]);
    }
    const visiting=new Set<string>(),visited=new Set<string>();
    const walk=(id:string)=>{if(visiting.has(id))throw Error('O canvas não pode conter ciclos.');if(visited.has(id))return;visiting.add(id);for(const next of adjacency.get(id)||[])walk(next);visiting.delete(id);visited.add(id);};
    walk(triggers[0].id);if(visited.size!==flow.nodes.length)throw Error('Conecte todos os blocos ao gatilho antes de salvar.');
    const row={workspace_id:ws,nome,evento,fluxo:flow,ativo:false,atualizado_em:new Date().toISOString()};
    if(b.id){if(!/^[0-9a-f-]{36}$/i.test(String(b.id)))throw Error('Automação inválida.');const updated=await q(db.from('atd_email_automacoes').update(row).eq('workspace_id',ws).eq('id',b.id).select('id'));if(!updated.length)throw Error('Automação não encontrada.');}
    else await q(db.from('atd_email_automacoes').insert({...row,criado_por:user.id}));
    return json({ok:true});
  }
  if(b.action==='email-automacoes-toggle'){
    const id=String(b.id||''),active=b.ativo===true;if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Automação inválida.');
    if(active){const sender=await q(db.from('atd_email_config').select('status_dominio').eq('workspace_id',ws).maybeSingle());if(sender?.status_dominio!=='verified')throw Error('Verifique o domínio de envio em Atendimento → Transmissão → Domínio e DNS antes de ativar.');}
    const updated=await q(db.from('atd_email_automacoes').update({ativo:active,atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id).select('id'));if(!updated.length)throw Error('Automação não encontrada.');return json({ok:true});
  }
  if(b.action==='email-transmissao-create'){
    if(!ctx.editar)return json({erro:'Sem permissão para criar transmissão.'},403);
    if(!Deno.env.get('RESEND_API_KEY'))throw new Error('Configure RESEND_API_KEY nas secrets da Edge.');
    const sender=await q(db.from('atd_email_config').select('dominio,email_remetente,status_dominio').eq('workspace_id',ws).single());if(sender.status_dominio!=='verified')throw new Error('Cadastre e verifique o domínio do workspace em Atendimento → Transmissão → Domínio e DNS.');
    const ids=[...new Set((Array.isArray(b.pessoa_ids)?b.pessoa_ids:[]).map((x:any)=>String(x)).filter(Boolean))];if(!ids.length||ids.length>500)throw new Error('Selecione entre 1 e 500 contatos.');
    const start=new Date(String(b.inicio_em||''));if(!Number.isFinite(start.getTime()))throw new Error('Informe uma data e horário válidos.');
    const interval=Number(b.intervalo_segundos);if(!Number.isInteger(interval)||interval<1||interval>30)throw new Error('O intervalo deve ser de 1 a 30 segundos.');
    const f=b.filtros&&typeof b.filtros==='object'?b.filtros:{};const allowed={tipo:['','lead','cliente'],qualificacao:['','qualificado','pendente','nao_qualificado']};
    if(!allowed.tipo.includes(String(f.tipo||''))||!allowed.qualificacao.includes(String(f.qualificacao||'')))throw new Error('Filtro de tipo ou qualificação inválido.');
    const contacts=await q(db.from('pessoas').select('id,nome,email,status_funil,qualificacao,campanha_id,tags').eq('workspace_id',ws).in('id',ids));const eligible=contacts.filter((p:any)=>emailFiltroAplica(p,f)&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(p.email||'')));
    if(!eligible.length)throw new Error('Nenhum contato selecionado tem e-mail válido e atende aos filtros.');
    const steps=Array.isArray(b.etapas)?b.etapas:[];if(!steps.length||steps.length>10)throw new Error('Configure de 1 a 10 e-mails na sequência.');
    const clean=steps.map((s:any,i:number)=>{const subject=String(s.assunto||'').trim(),html=emailSanitizar(String(s.html||'').trim()),delay=Number(s.atraso_minutos||0);if(!subject||subject.length>180||!html||html.length>100000)throw new Error(`Confira o assunto e o conteúdo do e-mail ${i+1}.`);if(!Number.isInteger(delay)||delay<0||delay>525600)throw new Error(`O intervalo antes do e-mail ${i+1} deve ficar entre 0 e 525600 minutos.`);return{assunto:subject,html,atraso_minutos:delay};});
    const campaign=await q(db.from('atd_email_campanhas').insert({workspace_id:ws,nome:String(b.nome||'Transmissão de e-mail').trim().slice(0,160)||'Transmissão de e-mail',inicio_em:start.toISOString(),fuso:'America/Sao_Paulo',intervalo_segundos:interval,filtros:f,status:'agendada',criado_por:user.id}).select('id').single());
    let rows:any[]=[],cumulative=0;for(let step=0;step<clean.length;step++){cumulative+=clean[step].atraso_minutos;for(let i=0;i<eligible.length;i++){const p=eligible[i];rows.push({workspace_id:ws,campanha_id:campaign.id,pessoa_id:p.id,etapa:step+1,enviar_em:new Date(start.getTime()+cumulative*60000+i*interval*1000).toISOString(),email:p.email,assunto:clean[step].assunto,corpo_html:clean[step].html,atraso_minutos:clean[step].atraso_minutos,condicao:f,status:'pendente'});}}
    for(let i=0;i<rows.length;i+=500)await q(db.from('atd_email_envios').insert(rows.slice(i,i+500)));
    return json({id:campaign.id,contatos:eligible.length,etapas:clean.length,envios:rows.length});
  }
  if(b.action==='email-transmissao-cancel'){
    const id=String(b.id||'');if(!id)throw new Error('Transmissão inválida.');
    await q(db.from('atd_email_envios').update({status:'cancelado',atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('campanha_id',id).eq('status','pendente'));
    await q(db.from('atd_email_campanhas').update({status:'cancelada',atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id).in('status',['agendada','em_execucao']));
    return json({ok:true});
  }
  if(b.action==='qr-share-create'){
    const ch=await channel(String(b.canal_id||''),ws);
    if(ch.provedor!=='evolution'||ch.canal!=='whatsapp'||!ch.ativo)throw Error('Selecione uma conexão ativa da Evolution.');
    const random=crypto.getRandomValues(new Uint8Array(32)),binary=String.fromCharCode(...random),token=btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
    const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',random)),hash=[...digest].map(x=>x.toString(16).padStart(2,'0')).join('');
    const expires=new Date(Date.now()+10*60*1000).toISOString();
    await q(db.from('atd_qr_compartilhamentos').update({revogado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('canal_id',ch.id).is('usado_em',null).is('revogado_em',null));
    await q(db.from('atd_qr_compartilhamentos').insert({workspace_id:ws,canal_id:ch.id,token_hash:hash,expira_em:expires,criado_por:user.id}));
    return json({token,expira_em:expires});
  }
  if (['zernio-disponiveis','zernio-conectar'].includes(b.action)) {
    const interna = await q(userDb.rpc('sou_equipe_interna'));
    if (!interna) return json({ erro:'Somente a equipe interna pode vincular contas da Zernio.' },403);
  }
  if (b.action === 'contexto') return json(ctx);
  if(b.action==='grupo-campanhas-list'){
    const campanhas=await q(db.from('atd_grupo_campanhas').select('id,nome,descricao,conversas,link_token,link_ativo,link_cliques,link_limite_membros,criado_em,atualizado_em').eq('workspace_id',ws).order('atualizado_em',{ascending:false}).limit(100));
    return json({campanhas});
  }
  if(b.action==='grupo-campanha-save'){
    const id=String(b.id||''),nome=String(b.nome||'').trim(),descricao=String(b.descricao||'').trim();
    if(!nome||nome.length>100||descricao.length>1000)throw Error('Informe um nome de até 100 caracteres e descrição de até 1.000.');
    if(id){
      if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Campanha inválida.');
      const rows=await q(db.from('atd_grupo_campanhas').update({nome,descricao,atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id).select('id,nome,descricao,conversas').limit(1));
      if(!rows.length)throw Error('Campanha não encontrada.');return json({campanha:rows[0]});
    }
    const campanha=await q(db.from('atd_grupo_campanhas').insert({workspace_id:ws,nome,descricao,criado_por:user.id}).select('id,nome,descricao,conversas').single());
    return json({campanha});
  }
  if(b.action==='grupo-campanha-link-save'){
    const id=String(b.id||''),ativo=b.ativo,limite=b.limite_membros==null?null:Number(b.limite_membros);
    if(!/^[0-9a-f-]{36}$/i.test(id)||typeof ativo!=='boolean'||(limite!==null&&(!Number.isInteger(limite)||limite<1||limite>1024)))throw Error('Informe campanha, estado e limite de membros válidos.');
    const current=await q(db.from('atd_grupo_campanhas').select('id,conversas').eq('workspace_id',ws).eq('id',id).maybeSingle());
    if(!current)throw Error('Campanha não encontrada.');
    if(ativo&&!(current.conversas||[]).length)throw Error('Vincule pelo menos um grupo antes de ativar o link.');
    const update:any={link_ativo:ativo,atualizado_em:new Date().toISOString()};if(limite!==null)update.link_limite_membros=limite;
    const rows=await q(db.from('atd_grupo_campanhas').update(update).eq('workspace_id',ws).eq('id',id).select('id,link_token,link_ativo,link_limite_membros').limit(1));
    if(!rows.length)throw Error('Campanha não encontrada.');
    return json({campanha:rows[0]});
  }
  if(b.action==='grupo-campanha-grupos-save'){
    const id=String(b.campanha_id||''),ids=Array.isArray(b.conversas)?[...new Set(b.conversas.map(String))]:[];
    if(!/^[0-9a-f-]{36}$/i.test(id)||ids.length>500||ids.some((x:string)=>!/^[0-9a-f-]{36}$/i.test(x)))throw Error('Campanha ou lista de grupos inválida.');
    await q(db.from('atd_grupo_campanhas').select('id').eq('workspace_id',ws).eq('id',id).single());
    const grupos:any[]=[];for(let offset=0;offset<ids.length;offset+=100)grupos.push(...await q(db.from('atd_conversas').select('id,canal_id,grupo,grupo_tipo').eq('workspace_id',ws).in('id',ids.slice(offset,offset+100))));
    if(grupos.length!==ids.length||grupos.some((g:any)=>!g.grupo||g.grupo_tipo==='comunidade'))throw Error('Selecione apenas grupos WhatsApp disponíveis; comunidades não recebem disparos.');
    const channelIds=[...new Set(grupos.map((g:any)=>g.canal_id))],channels=channelIds.length?await q(db.from('atd_canais').select('id,provedor,canal').eq('workspace_id',ws).in('id',channelIds)):[];
    if(channels.length!==channelIds.length||channels.some((c:any)=>c.provedor!=='evolution'||c.canal!=='whatsapp'))throw Error('A campanha aceita apenas grupos de chips Evolution deste workspace.');
    const saved=await q(db.from('atd_grupo_campanhas').update({conversas:ids,atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id).select('id,nome,descricao,conversas').single());
    return json({campanha:saved});
  }
  if(b.action==='grupo-campanha-criar-grupo'){
    const id=String(b.campanha_id||''),canalId=String(b.canal_id||''),subject=String(b.nome||'').trim(),description=String(b.descricao||'').trim(),participants=String(b.participantes||'').split(/[\s,;]+/).map((x:string)=>x.replace(/\D/g,'')).filter(Boolean);
    if(!/^[0-9a-f-]{36}$/i.test(id)||!/^[0-9a-f-]{36}$/i.test(canalId)||!subject||subject.length>100||description.length>1000||!participants.length||participants.length>20||participants.some((x:string)=>!/^\d{10,15}$/.test(x)))throw Error('Informe campanha, chip, nome e ao menos um telefone com DDI (até 20).');
    const campanha=await q(db.from('atd_grupo_campanhas').select('id,conversas').eq('workspace_id',ws).eq('id',id).single());
    if((campanha.conversas||[]).length>=500)throw Error('A campanha já tem 500 grupos.');
    const ch=await channel(canalId,ws);if(ch.provedor!=='evolution'||ch.canal!=='whatsapp'||!ch.ativo||ch.status!=='conectado')throw Error('Selecione um chip Evolution conectado.');
    const cfg=await secret(ws),created=await evolution(cfg,'/group/create/'+encodeURIComponent(ch.externo_id),'POST',{subject,description,participants:[...new Set(participants)]},60000);
    const jid=String(created?.id||created?.groupJid||created?.group?.id||created?.data?.id||created?.data?.groupJid||created?.data?.group?.id||'');
    if(!isJid(jid)||!jid.endsWith('@g.us'))throw Error('A Evolution não confirmou o ID. O grupo pode ter sido criado; busque-o antes de tentar novamente.');
    await q(db.rpc('atd_receber',{p_canal:ch.id,p_conversa:{id:jid,nome:subject,endereco:jid,grupo:true}}));
    const cv=await q(db.from('atd_conversas').select('id').eq('workspace_id',ws).eq('canal_id',ch.id).eq('externo_id',jid).single());
    const current=await q(db.from('atd_grupo_campanhas').select('conversas').eq('workspace_id',ws).eq('id',id).single()),ids=[...new Set([...(current.conversas||[]),cv.id])];
    await q(db.from('atd_grupo_campanhas').update({conversas:ids,atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id));
    return json({ok:true,conversa_id:cv.id,groupJid:jid});
  }
  if(b.action==='grupo-campanha-foto-preparar'){
    const mime=String(b.mime||'').toLowerCase(),ext=({'image/jpeg':'jpg','image/png':'png','image/webp':'webp'} as Record<string,string>)[mime];
    if(!ext)throw Error('Use uma imagem JPG, PNG ou WebP.');
    const path=ws+'/grupo-fotos/'+crypto.randomUUID()+'/foto.'+ext,signed=await q(db.storage.from('atendimento').createSignedUploadUrl(path));
    return json({path,token:signed.token});
  }
  if(['grupo-campanha-grupo-info','grupo-campanha-grupo-update'].includes(b.action)){
    const id=String(b.campanha_id||''),conversaId=String(b.conversa_id||'');
    if(!/^[0-9a-f-]{36}$/i.test(id)||!/^[0-9a-f-]{36}$/i.test(conversaId))throw Error('Campanha ou grupo inválido.');
    const campanha=await q(db.from('atd_grupo_campanhas').select('conversas').eq('workspace_id',ws).eq('id',id).single());
    if(!(campanha.conversas||[]).includes(conversaId))throw Error('Este grupo não pertence à campanha.');
    const cv=await q(db.from('atd_conversas').select('id,canal_id,externo_id,nome,grupo').eq('workspace_id',ws).eq('id',conversaId).single());
    if(!cv.grupo||!isJid(cv.externo_id)||!cv.externo_id.endsWith('@g.us'))throw Error('Grupo inválido.');
    const ch=await channel(cv.canal_id,ws);if(ch.provedor!=='evolution'||ch.canal!=='whatsapp'||!ch.ativo||ch.status!=='conectado')throw Error('O chip deste grupo precisa estar conectado.');
    const cfg=await secret(ws),instance=encodeURIComponent(ch.externo_id);
    if(b.action==='grupo-campanha-grupo-update'){
      const action=String(b.tipo||''),value=String(b.valor||'').trim();
      if(action==='nome'){
        if(!value||value.length>100)throw Error('Informe um nome de até 100 caracteres.');
        await evolution(cfg,'/group/updateGroupSubject/'+instance,'POST',{groupJid:cv.externo_id,subject:value});
        await q(db.from('atd_conversas').update({nome:value}).eq('workspace_id',ws).eq('id',cv.id));
      }else if(action==='descricao'){
        if(value.length>1000)throw Error('A descrição deve ter até 1.000 caracteres.');
        await evolution(cfg,'/group/updateGroupDescription/'+instance,'POST',{groupJid:cv.externo_id,description:value});
      }else if(['announcement','not_announcement','locked','unlocked'].includes(action)){
        await evolution(cfg,'/group/updateSetting/'+instance,'POST',{groupJid:cv.externo_id,action});
      }else if(action==='foto'){
        const path=String(b.path||''),match=path.match(new RegExp('^'+ws+'/grupo-fotos/[0-9a-f-]{36}/foto\\.(jpg|png|webp)$','i'));
        if(!match)throw Error('A foto não pertence a este workspace.');
        const folder=path.slice(0,path.lastIndexOf('/')),file=path.slice(path.lastIndexOf('/')+1),files=await q(db.storage.from('atendimento').list(folder,{limit:5,search:file})),found=files.find((x:any)=>x.name===file),mime=String(found?.metadata?.mimetype||found?.metadata?.mimeType||'').toLowerCase(),size=Number(found?.metadata?.size);
        if(!found||!['image/jpeg','image/png','image/webp'].includes(mime)||!Number.isFinite(size)||size<1||size>2*1024*1024)throw Error('Foto não encontrada ou acima de 2 MB.');
        const signed=await q(db.storage.from('atendimento').createSignedUrl(path,300));
        await evolution(cfg,'/group/updateGroupPicture/'+instance,'POST',{groupJid:cv.externo_id,image:signed.signedUrl},60000);
        await q(db.from('atd_conversas').update({avatar_path:path,avatar_atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',cv.id));
      }else throw Error('Alteração de grupo não suportada pela Evolution 2.3.7.');
      return json({ok:true});
    }
    const raw=await evolution(cfg,'/group/findGroupInfos/'+instance+'?'+new URLSearchParams({groupJid:cv.externo_id})),meta=unwrapGroupMeta(raw);
    return json({nome:groupName(meta)||cv.nome,descricao:String(meta.desc||meta.description||''),somente_admin_envia:meta.announce===true,somente_admin_edita:meta.restrict===true,membros:groupMembers(meta)});
  }
  if(b.action==='disparos-grupos-list'){
    const rows=await q(db.from('atd_disparos_grupos').select('id,nome,texto,status,iniciar_em,intervalo_segundos,total,criado_em,midia_path,midia_nome,midia_mime,grupo_campanha_id').eq('workspace_id',ws).order('criado_em',{ascending:false}).limit(50));
    const items=rows.length?await q(db.from('atd_disparos_grupos_itens').select('campanha_id,status,erro').eq('workspace_id',ws).in('campanha_id',rows.map((x:any)=>x.id))):[];
    for(const row of rows){const own=items.filter((i:any)=>i.campanha_id===row.id);row.enviados=own.filter((i:any)=>i.status==='enviado').length;row.falhas=own.filter((i:any)=>['erro','incerto'].includes(i.status)).length;row.pendentes=own.filter((i:any)=>i.status==='agendado').length;row.erro=own.find((i:any)=>i.erro)?.erro||null;}
    return json({campanhas:rows});
  }
  if(b.action==='disparos-grupos-destinatarios'){
    const id=String(b.campanha_id||'');
    if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Campanha inválida.');
    await q(db.from('atd_disparos_grupos').select('id').eq('workspace_id',ws).eq('id',id).single());
    const items=await q(db.from('atd_disparos_grupos_itens').select('conversa_id,canal_id,status,posicao').eq('workspace_id',ws).eq('campanha_id',id).order('posicao').limit(500));
    const ids=[...new Set(items.map((item:any)=>item.conversa_id))];
    const conversas=[];
    for(let offset=0;offset<ids.length;offset+=100){
      conversas.push(...await q(db.from('atd_conversas').select('id,nome,endereco,externo_id,grupo').eq('workspace_id',ws).in('id',ids.slice(offset,offset+100))));
    }
    const byId=new Map(conversas.map((c:any)=>[c.id,c]));
    return json({destinatarios:items.map((item:any)=>{const c:any=byId.get(item.conversa_id)||{};return {id:item.conversa_id,nome:c.nome||c.endereco||c.externo_id||'Conversa sem nome',grupo:Boolean(c.grupo),status:item.status,posicao:item.posicao};})});
  }
  if(b.action==='disparos-grupos-edit'){
    if(!ctx.editar)throw Error('Sem permissão para editar disparos.');
    const id=String(b.campanha_id||''),texto=String(b.texto??''),nome=String(b.nome||'').trim(),inicio=new Date(String(b.iniciar_em||''));
    if(!/^[0-9a-f-]{36}$/i.test(id)||texto.length>4000||!nome||nome.length>100||!Number.isFinite(inicio.getTime())||inicio.getTime()<Date.now()+60000)throw Error('Informe nome, mensagem e horário futuro válido.');
    const atualizados=await q(db.rpc('atd_grupo_disparo_editar_agendamento',{p_workspace:ws,p_campanha:id,p_nome:nome,p_texto:texto,p_iniciar_em:inicio.toISOString()}));
    return json({ok:true,atualizados:Number(atualizados)||0});
  }
  if(b.action==='disparos-grupos-media-url'){
    const id=String(b.campanha_id||'');
    if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Campanha inválida.');
    const row=await q(db.from('atd_disparos_grupos').select('midia_path,midia_nome').eq('workspace_id',ws).eq('id',id).single());
    if(!row.midia_path)throw Error('Esta campanha não possui anexo.');
    const signed=await q(db.storage.from('atendimento').createSignedUrl(row.midia_path,300));
    return json({url:signed.signedUrl,nome:row.midia_nome});
  }
  if(b.action==='disparos-segmentos-list'){
    const segmentos=await q(db.from('atd_disparos_segmentos').select('id,nome,conversas,criado_em').eq('workspace_id',ws).order('nome'));
    return json({segmentos});
  }
  if(b.action==='disparos-segmento-save'){
    if(!ctx.editar)throw Error('Sem permissão para salvar segmentos.');
    const nome=String(b.nome||'').trim().slice(0,100),ids=Array.isArray(b.conversas)?[...new Set(b.conversas.map(String))]:[];
    if(!nome||!ids.length||ids.length>500||ids.some((id:string)=>!/^[0-9a-f-]{36}$/i.test(id)))throw Error('Informe um nome e selecione de 1 a 500 destinatários.');
    const recipients=await q(db.from('atd_conversas').select('id,canal_id,grupo,grupo_tipo').eq('workspace_id',ws).in('id',ids));
    if(recipients.length!==ids.length||recipients.some((x:any)=>x.grupo_tipo==='comunidade'))throw Error('O segmento contém destinatários indisponíveis ou uma comunidade.');
    const channelIds=[...new Set(recipients.map((x:any)=>x.canal_id))],sourceChannels=await q(db.from('atd_canais').select('id,provedor,canal').eq('workspace_id',ws).in('id',channelIds));
    if(sourceChannels.length!==channelIds.length||sourceChannels.some((x:any)=>x.provedor!=='evolution'||x.canal!=='whatsapp'))throw Error('Os segmentos aceitam apenas conversas WhatsApp da Evolution.');
    const segmento=await q(db.from('atd_disparos_segmentos').insert({workspace_id:ws,nome,conversas:ids,criado_por:user.id}).select('id,nome,conversas,criado_em').single());return json({segmento});
  }
  if(b.action==='disparos-segmento-delete'){
    if(!ctx.editar)throw Error('Sem permissão para remover segmentos.');const id=String(b.id||'');if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Segmento inválido.');
    const rows=await q(db.from('atd_disparos_segmentos').delete().eq('workspace_id',ws).eq('id',id).select('id'));if(!rows.length)throw Error('Segmento não encontrado.');return json({ok:true});
  }
  if(b.action==='disparos-grupos-media-preparar'){
    if(!ctx.editar)throw Error('Sem permissão para preparar mídia de disparo.');
    const mime=String(b.mime||'').toLowerCase().split(';')[0];
    const ext=({'image/jpeg':'jpg','image/png':'png','image/webp':'webp','video/mp4':'mp4'} as Record<string,string>)[mime];
    if(!ext)throw Error('Use imagem JPG, PNG ou WebP, ou vídeo MP4.');
    const path=`${ws}/disparos-grupos/rascunhos/${crypto.randomUUID()}/midia.${ext}`;
    const signed=await q(db.storage.from('atendimento').createSignedUploadUrl(path));
    return json({path,token:signed.token});
  }
  if(b.action==='disparos-grupos-create'){
    if(!ctx.editar)throw Error('Sem permissão para criar disparos.');if(!ctx.nome)throw Error('Cadastre seu nome na equipe antes de agendar.');
    const nome=String(b.nome||'').trim().slice(0,100),texto=String(b.texto||'').trim(),iniciar=new Date(b.iniciar_em),intervalo=Number(b.intervalo_segundos),grupoCampanhaId=String(b.grupo_campanha_id||'');
    let canalIds=Array.isArray(b.canal_ids)?[...new Set(b.canal_ids.map(String))]:[],grupos=Array.isArray(b.grupos)?b.grupos:[];
    if(!nome||(!texto&&!b.midia)||texto.length>4000||!Number.isFinite(iniciar.getTime())||iniciar.getTime()<Date.now()+60000||iniciar.getTime()>Date.now()+90*86400000)throw Error('Confira o nome, a mensagem e o horário (1 minuto a 90 dias).');
    if(!Number.isInteger(intervalo)||intervalo<10||intervalo>86400)throw Error('O intervalo deve ficar entre 10 segundos e 24 horas.');
    if(grupoCampanhaId){
      if(!/^[0-9a-f-]{36}$/i.test(grupoCampanhaId))throw Error('Campanha de grupos inválida.');
      const saved=await q(db.from('atd_grupo_campanhas').select('conversas').eq('workspace_id',ws).eq('id',grupoCampanhaId).single()),ids=saved.conversas||[];
      if(!ids.length||ids.length>500)throw Error('A campanha de grupos precisa conter de 1 a 500 grupos.');
      const members:any[]=[];for(let offset=0;offset<ids.length;offset+=100)members.push(...await q(db.from('atd_conversas').select('id,canal_id').eq('workspace_id',ws).in('id',ids.slice(offset,offset+100))));
      if(members.length!==ids.length)throw Error('A campanha contém grupos que não estão mais disponíveis. Atualize a campanha.');
      grupos=members.map((g:any)=>({conversa_id:g.id,canal_id:g.canal_id}));canalIds=[...new Set(members.map((g:any)=>g.canal_id))];
    }
    if(!canalIds.length||canalIds.length>20||!grupos.length||grupos.length>500)throw Error('Selecione chips e grupos válidos (até 500 grupos).');
    const channels=await q(db.from('atd_canais').select('*').eq('workspace_id',ws).eq('provedor','evolution').eq('canal','whatsapp').eq('ativo',true).in('id',canalIds));
    if(channels.length!==canalIds.length||channels.some((c:any)=>c.status!=='conectado'))throw Error('Selecione apenas chips Evolution conectados deste workspace.');
    const groupIds=[...new Set(grupos.map((g:any)=>String(g.conversa_id||'')))];if(groupIds.length!==grupos.length)throw Error('Há grupos duplicados na seleção.');
    const groupRows:any[]=[];for(let offset=0;offset<groupIds.length;offset+=100)groupRows.push(...await q(db.from('atd_conversas').select('id,canal_id,grupo,grupo_tipo').eq('workspace_id',ws).in('id',groupIds.slice(offset,offset+100))));
    if(groupRows.length!==groupIds.length||groupRows.some((g:any)=>!canalIds.includes(g.canal_id)||String(grupos.find((x:any)=>x.conversa_id===g.id)?.canal_id)!==g.canal_id))throw Error('Um ou mais destinatários não correspondem aos chips selecionados.');
    if(groupRows.some((g:any)=>g.grupo_tipo==='comunidade'||(grupoCampanhaId&&!g.grupo)))throw Error('A campanha deve conter somente grupos ou grupos de avisos disponíveis.');
    let media:any=null;
    if(b.midia){
      const mime=String(b.midia.mime||'').toLowerCase().split(';')[0];
      const ext=({'image/jpeg':'jpg','image/png':'png','image/webp':'webp','video/mp4':'mp4'} as Record<string,string>)[mime];
      if(!ext)throw Error('Use imagem JPG, PNG ou WebP, ou vídeo MP4.');
      const nome=String(b.midia.nome||'midia').replace(/[\\/\r\n]/g,'_').slice(0,150);
      if(b.midia.path){
        const path=String(b.midia.path);
        if(!new RegExp(`^${ws}/disparos-grupos/rascunhos/[0-9a-f-]{36}/midia\\.${ext}$`,'i').test(path))throw Error('A mídia não pertence a este workspace ou tem formato inválido.');
        const folder=path.slice(0,path.lastIndexOf('/')),file=path.slice(path.lastIndexOf('/')+1);
        const files=await q(db.storage.from('atendimento').list(folder,{limit:10,search:file}));
        const found=files.find((x:any)=>x.name===file),size=Number(found?.metadata?.size),storedMime=String(found?.metadata?.mimetype||found?.metadata?.mimeType||'').toLowerCase();
        if(!found||!Number.isFinite(size)||size<1||size>(mime==='video/mp4'?30:7)*1024*1024||storedMime!==mime)throw Error('Mídia não encontrada ou acima do limite: imagem 7 MB, vídeo 30 MB.');
        media={path,mime,nome};
      }else{
        // Compatibilidade com versões antigas da interface durante a publicação.
        const bytes=base64Bytes(String(b.midia.base64||''));
        if(!bytes.length||bytes.length>MAX_MEDIA)throw Error('A mídia deve ter até 8 MB.');
        media={bytes,mime,nome};
      }
    }
    const campaign=await q(db.from('atd_disparos_grupos').insert({workspace_id:ws,grupo_campanha_id:grupoCampanhaId||null,nome,texto,iniciar_em:iniciar.toISOString(),intervalo_segundos:intervalo,status:'agendado',total:groupRows.length,autor_id:user.id,autor_nome:ctx.nome}).select('id').single());
    try{
    if(media){const ext=media.mime==='video/mp4'?'mp4':media.mime==='image/png'?'png':media.mime==='image/webp'?'webp':'jpg',path=media.path||ws+'/disparos-grupos/'+campaign.id+'/midia.'+ext;if(media.bytes)await q(db.storage.from('atendimento').upload(path,media.bytes,{contentType:media.mime,upsert:true}));await q(db.from('atd_disparos_grupos').update({midia_path:path,midia_nome:media.nome,midia_mime:media.mime}).eq('id',campaign.id).eq('workspace_id',ws));}
    const items=groupRows.map((g:any,index:number)=>({workspace_id:ws,campanha_id:campaign.id,conversa_id:g.id,canal_id:g.canal_id,texto,posicao:index,enviar_em:new Date(iniciar.getTime()+index*intervalo*1000).toISOString(),status:'agendado'}));
    await q(db.from('atd_disparos_grupos_itens').insert(items));
    }catch(e){await q(db.from('atd_disparos_grupos').delete().eq('id',campaign.id).eq('workspace_id',ws));throw e;}
    return json({ok:true,id:campaign.id,total:groupRows.length});
  }
  if(b.action==='disparos-grupos-cancel'){
    const id=String(b.campanha_id||'');if(!/^[0-9a-f-]{36}$/i.test(id))throw Error('Campanha inválida.');
    const rows=await q(db.from('atd_disparos_grupos').update({status:'cancelado',atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('id',id).in('status',['agendado','em_andamento','pausado']).select('id'));
    if(!rows.length)throw Error('Esta campanha já foi concluída ou cancelada.');
    await q(db.from('atd_disparos_grupos_itens').update({status:'cancelado',atualizado_em:new Date().toISOString()}).eq('workspace_id',ws).eq('campanha_id',id).eq('status','agendado'));return json({ok:true});
  }
  if (b.action === 'contato-resumo') {
    if(!/^[0-9a-f-]{36}$/i.test(String(b.conversa_id||'')))throw new Error('Conversa inválida.');
    return json(await resumoContato(ws,b.conversa_id));
  }
  if(b.action==='criar-conversa-pessoa'){
    const pessoaId=String(b.pessoa_id||''),canalId=String(b.canal_id||'');
    if(!/^[0-9a-f-]{36}$/i.test(pessoaId)||!/^[0-9a-f-]{36}$/i.test(canalId))throw Error('Contato ou canal inválido.');
    const [pessoa,ch]=await Promise.all([
      q(db.from('pessoas').select('id,nome,telefone').eq('workspace_id',ws).eq('id',pessoaId).single()),
      channel(canalId,ws)
    ]);
    if(!ch.ativo||ch.status!=='conectado')throw Error('Este canal não está conectado.');
    if(ch.canal!=='whatsapp'||!['evolution','zernio'].includes(ch.provedor))throw Error('Só é possível iniciar uma conversa por WhatsApp. No Instagram, o contato precisa enviar a primeira DM.');
    const numero=telefoneNormalizado(pessoa.telefone);
    if(!numero)throw Error('Cadastre o telefone do contato com DDI antes de iniciar a conversa.');
    const jid=numero+'@s.whatsapp.net',externo=ch.provedor==='evolution'?jid:'pending:'+pessoa.id;
    const matches=await q(db.from('atd_conversas').select('id,pessoa_id')
      .eq('workspace_id',ws).eq('canal_id',ch.id)
      .or(`pessoa_id.eq.${pessoa.id},endereco.eq.${numero},endereco.eq.${jid},externo_id.eq.${numero},externo_id.eq.${jid},externo_id.eq.pending:${pessoa.id}`)
      .order('ultima_em',{ascending:false,nullsFirst:false}).limit(1));
    if(matches.length){
      if(!matches[0].pessoa_id)await q(db.from('atd_conversas').update({pessoa_id:pessoa.id}).eq('id',matches[0].id).eq('workspace_id',ws));
      return json({conversa_id:matches[0].id,existente:true});
    }
    const row={workspace_id:ws,canal_id:ch.id,externo_id:externo,nome:pessoa.nome,endereco:ch.provedor==='evolution'?jid:numero,pessoa_id:pessoa.id,grupo:false,status:'aberta'};
    const {data,error:insertError}=await db.from('atd_conversas').insert(row).select('id').single();
    if(insertError){
      const raced=await q(db.from('atd_conversas').select('id').eq('workspace_id',ws).eq('canal_id',ch.id).eq('externo_id',externo).maybeSingle());
      if(raced)return json({conversa_id:raced.id,existente:true});
      throw new Error(insertError.message);
    }
    return json({conversa_id:data.id,existente:false,aguarda_template:ch.provedor==='zernio'});
  }
  if(b.action==='channel-avatar'){
    const ch=await channel(String(b.canal_id||''),ws);
    if(!ch.avatar_path||!ch.avatar_path.startsWith(ws+'/channel-avatars/'+ch.id+'/'))return json({url:null});
    const signed=await q(db.storage.from('atendimento').createSignedUrl(ch.avatar_path,300));
    return json({url:signed.signedUrl});
  }
  if(b.action==='canal-salvar'){
    const ch=await channel(String(b.canal_id||''),ws);
    const nome=String(b.nome||'').trim();
    if(!nome||nome.length>100)throw Error('Informe um nome de até 100 caracteres.');
    const patch:any={nome};
    if(b.foto){
      const mime=String(b.foto.mime||'').toLowerCase();
      if(!['image/jpeg','image/png','image/webp'].includes(mime))throw Error('Use uma foto JPG, PNG ou WebP.');
      const bytes=base64Bytes(String(b.foto.base64||''));
      if(!bytes.length||bytes.length>512*1024)throw Error('A foto deve ter até 512 KB.');
      const ext=mime==='image/png'?'png':mime==='image/webp'?'webp':'jpg';
      const path=ws+'/channel-avatars/'+ch.id+'/profile.'+ext;
      await q(db.storage.from('atendimento').upload(path,bytes,{contentType:mime,upsert:true}));
      patch.avatar_path=path;
    }
    await q(db.from('atd_canais').update(patch).eq('id',ch.id).eq('workspace_id',ws));
    return json({ok:true});
  }
  if(b.action==='agendamentos-list'){
    const cv=await q(db.from('atd_conversas').select('id').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    return json({agendamentos:await q(db.from('atd_agendamentos').select('id,texto,enviar_em,fuso,status,erro,criado_em')
      .eq('workspace_id',ws).eq('conversa_id',cv.id).order('criado_em',{ascending:false}).limit(50))});
  }
  if(b.action==='agendar'){
    const cv=await q(db.from('atd_conversas').select('id,canal_id').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    const ch=await channel(cv.canal_id,ws);
    if(!ch.ativo||ch.status!=='conectado')throw Error('Conecte o canal antes de agendar.');
    const agendada=await q(db.from('atd_conversas').select('externo_id').eq('id',cv.id).eq('workspace_id',ws).single());
    if(ch.provedor==='zernio'&&String(agendada.externo_id).startsWith('pending:'))throw Error('Para iniciar no WhatsApp oficial, envie um template aprovado primeiro.');
    const texto=String(b.texto||'').trim(),quando=new Date(b.enviar_em);
    if(!texto||texto.length>4000||!Number.isFinite(quando.getTime()))throw Error('Informe a mensagem e um horário válido.');
    if(quando.getTime()<Date.now()+60000||quando.getTime()>Date.now()+365*86400000)
      throw Error('Escolha um horário com pelo menos 1 minuto de antecedência, dentro dos próximos 365 dias.');
    if(!ctx.nome)throw Error('Cadastre seu nome na equipe antes de agendar.');
    const row=await q(db.from('atd_agendamentos').insert({workspace_id:ws,conversa_id:cv.id,texto,
      enviar_em:quando.toISOString(),fuso:'America/Sao_Paulo',autor_id:user.id,autor_nome:ctx.nome}).select('id').single());
    return json({ok:true,id:row.id});
  }
  if(b.action==='cancelar-agendamento'){
    const id=String(b.agendamento_id||'');if(!/^[a-f0-9-]{36}$/i.test(id))throw Error('Agendamento inválido.');
    const cancelled=await q(db.from('atd_agendamentos').update({status:'cancelado',atualizado_em:new Date().toISOString()})
      .eq('id',id).eq('workspace_id',ws).eq('status','agendado').select('id'));
    if(!cancelled.length)throw Error('Este envio já foi iniciado, cancelado ou concluído.');
    return json({ok:true});
  }
  if (b.action === 'rapidas-list') {
    return json({respostas:await q(db.from('atd_respostas_rapidas').select('id,atalho,titulo,texto')
      .eq('workspace_id',ws).order('titulo'))});
  }
  if(b.action==='automacoes-list'){
    return json({automacoes:await q(db.from('atd_automacoes').select('id,nome,canal_id,gatilho_tipo,gatilho_valor,resposta,fluxo,ativo,criado_em,atualizado_em')
      .eq('workspace_id',ws).order('atualizado_em',{ascending:false}))});
  }
  if(b.action==='automacoes-execucoes'){
    const runs=await q(db.from('atd_automacao_execucoes').select('id,automacao_id,conversa_id,status,erro,executado_em,retomar_em')
      .eq('workspace_id',ws).order('executado_em',{ascending:false}).limit(30));
    return json({execucoes:runs});
  }
  if(b.action==='automacoes-save'){
    const nome=String(b.nome||'').trim(), resposta=String(b.resposta||'').trim();
    const tipo=b.gatilho_tipo==='qualquer_mensagem'?'qualquer_mensagem':'palavra_chave';
    const gatilho=tipo==='palavra_chave'?String(b.gatilho_valor||'').trim():'';
    const canalId=String(b.canal_id||'').trim()||null, ativo=b.ativo===true;
    let fluxo=b.fluxo&&typeof b.fluxo==='object'?b.fluxo:null;
    if(!nome||nome.length>120||!resposta||resposta.length>4000||
      (tipo==='palavra_chave'&&(!gatilho||gatilho.length>100)))
      throw Error('Informe nome, gatilho e uma resposta de até 4.000 caracteres.');
    if(!fluxo||!Array.isArray(fluxo.nodes)||!Array.isArray(fluxo.edges))
      fluxo={versao:1,nodes:[],edges:[]};
    if(!fluxo.nodes.length){
      const start=crypto.randomUUID(),message=crypto.randomUUID();
      fluxo={versao:1,nodes:[{id:start,tipo:'gatilho',x:40,y:190,data:{}},{id:message,tipo:'mensagem',x:390,y:190,data:{texto:resposta}}],edges:[{origem:start,destino:message,saida:'seguir'}]};
    }
    if(fluxo.nodes.length>60||fluxo.edges.length>120)
      throw Error('O canvas precisa ter até 60 blocos e 120 ligações.');
    const nodeIds=new Set<string>();
    for(const node of fluxo.nodes){
      if(!node||!/^[0-9a-f-]{36}$/i.test(String(node.id||''))||nodeIds.has(node.id)||!['gatilho','mensagem','botoes','template','condicao','espera','fim'].includes(node.tipo))throw Error('Bloco inválido no canvas.');
      nodeIds.add(node.id);
      const x=Number(node.x),y=Number(node.y);if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>50000||y>50000)throw Error('Posição de bloco inválida.');
      if(node.tipo==='mensagem'){
        const text=String(node.data?.texto||'').trim(),url=String(node.data?.media_url||'').trim(),mediaType=String(node.data?.media_type||'');
        if(text.length>4000||(!text&&!url))throw Error('A ação precisa de texto ou mídia e aceita até 4.000 caracteres.');
        if(url&&(!/^https:\/\//i.test(url)||url.length>2000||!['imagem','video','documento'].includes(mediaType)))throw Error('URL ou tipo de mídia inválido na ação.');
      }
      if(node.tipo==='template'){
        const d=node.data||{};
        if(!/^[a-z][a-z0-9_]{0,511}$/.test(String(d.template_name||''))||!/^([a-z]{2})(_[A-Z]{2})?$/.test(String(d.idioma||''))||!Array.isArray(d.campos)||d.campos.length>20||d.campos.some((x:any)=>!['primeiro_nome','nome','telefone','email','produto','campanha','capturado_em','qualificacao','status_funil','status_cliente'].includes(x)))throw Error('Selecione um template aprovado e mapeie todas as variáveis para campos do contato.');
        if(d.media_url&&(!/^https:\/\//i.test(String(d.media_url))||String(d.media_url).length>2000))throw Error('Informe uma URL HTTPS para a mídia do template.');
      }
      if(node.tipo==='botoes'){
        const text=String(node.data?.texto||'').trim(),buttons=Array.isArray(node.data?.buttons)?node.data.buttons.filter((x:any)=>String(x?.title||'').trim()):[];
        if(!text||text.length>1024||!buttons.length||buttons.length>3)throw Error('A ação de botões precisa de texto e de 1 a 3 botões.');
        if(buttons.some((x:any)=>!['reply','url'].includes(x.kind)||String(x.title).trim().length>20||String(x.value||'').length>500))throw Error('Os botões contêm valores inválidos.');
        if(buttons.some((x:any)=>x.kind==='url'&&!/^https:\/\//i.test(String(x.value||'')))||buttons.some((x:any)=>x.kind==='url')&&buttons.length>1)throw Error('Use respostas rápidas ou apenas um botão com link HTTPS.');
      }
      if(node.tipo==='condicao'&&!String(node.data?.valor||'').trim())throw Error('Informe o trecho de mensagem na condição.');
      if(node.tipo==='espera'){
        const unit=String(node.data?.unidade||''),max=unit==='segundos'?86400:unit==='minutos'?525600:unit==='horas'?8760:unit==='dias'?365:0;
        if(!Number.isFinite(Number(node.data?.quantidade))||Number(node.data.quantidade)<1||Number(node.data.quantidade)>max)throw Error('Tempo de espera inválido. Confira o limite da unidade selecionada.');
      }
    }
    if(!fluxo.nodes.some((n:any)=>n.tipo==='gatilho')||!fluxo.nodes.some((n:any)=>['mensagem','botoes','template'].includes(n.tipo)))throw Error('O canvas precisa conter um gatilho e ao menos uma ação de mensagem.');
    for(const edge of fluxo.edges)if(!nodeIds.has(edge.origem)||!nodeIds.has(edge.destino)||edge.origem===edge.destino||!['seguir','sim','nao'].includes(edge.saida))throw Error('Ligação inválida no canvas.');
    let canais:any[]=[];
    if(canalId){
      const ch=await channel(canalId,ws);canais=[ch];
      if(!((ch.canal==='instagram'&&ch.provedor==='zernio')||
           (ch.canal==='whatsapp'&&['zernio','evolution'].includes(ch.provedor))))
        throw Error('Este canal ainda não é compatível com automações.');
    }else canais=await q(db.from('atd_canais').select('id,canal,provedor,ativo,status')
      .eq('workspace_id',ws).eq('ativo',true));
    canais=canais.filter((ch:any)=>(ch.canal==='instagram'&&ch.provedor==='zernio')||
      (ch.canal==='whatsapp'&&['zernio','evolution'].includes(ch.provedor)));
    if(fluxo.nodes.some((n:any)=>n.tipo==='template')){
      if(!canalId||canais[0]?.provedor!=='zernio'||canais[0]?.canal!=='whatsapp')throw Error('O bloco de template exige uma conta WhatsApp API oficial específica.');
      const listed=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(canais[0].externo_id));
      const approved=listed.templates||listed.data?.templates||[];
      for(const node of fluxo.nodes.filter((n:any)=>n.tipo==='template')){
        const tpl=approved.find((t:any)=>t.name===node.data.template_name&&t.language===node.data.idioma&&t.status==='APPROVED');
        if(!tpl)throw Error('O template selecionado não está aprovado nesta conta.');
        if((tpl.components||[]).some((c:any)=>{const type=String(c.type||'').toUpperCase();return type==='HEADER'?!['TEXT','IMAGE','VIDEO','DOCUMENT'].includes(String(c.format||'TEXT').toUpperCase()):!['BODY','FOOTER','BUTTONS'].includes(type)||(c.buttons||[]).some((x:any)=>!['QUICK_REPLY','URL','PHONE_NUMBER'].includes(String(x.type||'').toUpperCase()));}))throw Error('Este template contém componentes ainda não compatíveis com automações.');
        const slots=templateSlots(tpl);
        if(slots.length!==node.data.campos.length)throw Error('Mapeie todas as variáveis do template.');
        const format=String(tpl.components?.find((c:any)=>String(c.type).toUpperCase()==='HEADER')?.format||'TEXT').toUpperCase();
        if(['IMAGE','VIDEO','DOCUMENT'].includes(format)&&!node.data.media_url)throw Error('Informe a URL HTTPS da mídia para o cabeçalho do template.');
      }
    }
    if(ativo&&!canais.some((ch:any)=>ch.ativo&&ch.status==='conectado'))
      throw Error('Para ativar, conecte um canal compatível ao Atendimento.');
    const row:any={workspace_id:ws,nome,canal_id:canalId,gatilho_tipo:tipo,gatilho_valor:gatilho,
      resposta,fluxo,ativo,atualizado_em:new Date().toISOString()};
    if(b.id){
      if(!/^[a-f0-9-]{36}$/i.test(String(b.id)))throw Error('Automação inválida.');
      const updated=await q(db.from('atd_automacoes').update(row).eq('workspace_id',ws).eq('id',b.id).select('id'));
      if(!updated.length)throw Error('Automação não encontrada neste workspace.');
    }else{
      row.criado_por=user.id;
      await q(db.from('atd_automacoes').insert(row));
    }
    return json({ok:true});
  }
  if(b.action==='automacoes-delete'){
    if(!/^[a-f0-9-]{36}$/i.test(String(b.id||'')))throw Error('Automação inválida.');
    await q(db.from('atd_automacoes').delete().eq('workspace_id',ws).eq('id',b.id));
    return json({ok:true});
  }
  if (b.action === 'rapidas-save') {
    const atalho=String(b.atalho||'').trim().toLowerCase(),titulo=String(b.titulo||'').trim(),texto=String(b.texto||'').trim();
    if(!/^[a-z0-9_-]{1,60}$/.test(atalho)||!titulo||titulo.length>120||!texto||texto.length>4000)
      throw Error('Informe atalho (letras, números, - ou _), título e mensagem válidos.');
    const row:any={workspace_id:ws,atalho,titulo,texto,atualizado_em:new Date().toISOString()};
    if(b.id){
      if(!/^[a-f0-9-]{36}$/i.test(String(b.id)))throw Error('Resposta inválida.');
      await q(db.from('atd_respostas_rapidas').update(row).eq('workspace_id',ws).eq('id',b.id));
    }else await q(db.from('atd_respostas_rapidas').insert(row));
    return json({ok:true});
  }
  if (b.action === 'rapidas-delete') {
    if(!/^[a-f0-9-]{36}$/i.test(String(b.id||'')))throw Error('Resposta inválida.');
    await q(db.from('atd_respostas_rapidas').delete().eq('workspace_id',ws).eq('id',b.id));
    return json({ok:true});
  }
  if (b.action?.startsWith('templates-')) {
    const ch=await channel(String(b.canal_id||''),ws);
    if(ch.canal!=='whatsapp'||ch.provedor!=='zernio'||!ch.ativo)
      throw Error('Templates Meta exigem um WhatsApp oficial conectado pela Zernio.');
    const accountId=ch.externo_id;
    if(b.action==='templates-list') {
      const result=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(accountId));
      const templates=result.templates||result.data?.templates||[];
      const mappings=await q(db.from('atd_template_mapeamentos').select('template_name,idioma,mapeamentos').eq('workspace_id',ws).eq('canal_id',ch.id)).catch(()=>[]);
      return json({templates:templates.map((t:any)=>({...t,mapeamentos:mappings.find((m:any)=>m.template_name===t.name&&m.idioma===t.language)?.mapeamentos||{}}))});
    }
    if(b.action==='templates-mapping-save') {
      const nome=String(b.template_name||'').trim(),idioma=String(b.idioma||'').trim(),raw=b.mapeamentos;
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(idioma)||!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Template ou mapeamentos inválidos.');
      const keys=['primeiro_nome','nome','email','telefone','campanha','produto','utm_campaign','capturado_em','valor_venda','data_venda','pesquisa'];
      const normalized:any={};
      for(const event of ['cadastro','venda','pesquisa']){
        const values=raw[event];
        if(!Array.isArray(values)||values.length>20||values.some((v:any)=>typeof v!=='string'||(!keys.includes(v)&&!/^extra:[a-z0-9_-]{1,80}$/.test(v))))throw Error('Mapeamento de variáveis inválido.');
        normalized[event]=values;
      }
      await q(db.from('atd_template_mapeamentos').upsert({workspace_id:ws,canal_id:ch.id,template_name:nome,idioma,mapeamentos:normalized,atualizado_em:new Date().toISOString()},{onConflict:'workspace_id,canal_id,template_name,idioma'}));
      return json({ok:true});
    }
    if(b.action==='templates-send'){
      if(!ctx.editar)throw Error('Sem permissão para enviar mensagens.');
      const cv=await q(db.from('atd_conversas').select('*').eq('id',b.conversa_id).eq('workspace_id',ws).single());
      if(cv.canal_id!==ch.id||cv.grupo)throw Error('Selecione uma conversa individual deste canal.');
      const opening=String(cv.externo_id).startsWith('pending:');
      if(!ch.ativo||ch.status!=='conectado')throw Error('O WhatsApp oficial não está conectado.');
      if(!ctx.nome)throw Error('Cadastre seu nome na equipe antes de enviar.');
      const nome=String(b.template_name||''),idioma=String(b.idioma||''),params=Array.isArray(b.parametros)?b.parametros.map((x:any)=>String(x||'').trim()):[];
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(idioma)||params.length>20||params.some((x:string)=>!x||x.length>1024))throw Error('Template ou variáveis inválidos.');
      const listed=await zernio(zp(),'/whatsapp/templates?accountId='+encodeURIComponent(ch.externo_id));
      const templates=listed.templates||listed.data?.templates||[];
      const tpl=templates.find((t:any)=>t.name===nome&&t.language===idioma&&t.status==='APPROVED');
      if(!tpl)throw Error('O template não está aprovado ou não corresponde a esta conta e idioma.');
      const components=tpl.components||[],header=components.find((c:any)=>String(c.type).toUpperCase()==='HEADER'),body=components.find((c:any)=>String(c.type).toUpperCase()==='BODY'),footer=components.find((c:any)=>String(c.type).toUpperCase()==='FOOTER'),buttons=components.find((c:any)=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[];
      const slots:any[]=[];
      const addSlots=(text:string,kind:string,index=-1)=>{
        const matches=[...String(text||'').matchAll(/\{\{(\d+)\}\}/g)],numbers=[...new Set(matches.map((x:any)=>Number(x[1])))].sort((a:number,b:number)=>a-b);
        if(numbers.some((n:number,i:number)=>n!==i+1))throw Error('As variáveis do template precisam seguir a ordem {{1}}, {{2}} etc.');
        numbers.forEach(marker=>slots.push({kind,index,marker}));
      };
      const headerFormat=String(header?.format||'TEXT').toUpperCase();
      if(headerFormat==='TEXT')addSlots(header?.text,'header');
      addSlots(body?.text,'body');
      buttons.forEach((button:any,index:number)=>{if(String(button.type).toUpperCase()==='URL')addSlots(button.url,'url',index);});
      if(slots.length>20||params.length!==slots.length||params.some((x:string)=>!x||x.length>1024))throw Error('Preencha os campos variáveis na ordem indicada pelo template.');
      const buttonParams=Array.isArray(b.button_params)?b.button_params.map((x:any)=>({index:Number(x.index),subType:String(x.subType||''),value:String(x.value||'').trim()})):[];
      if(buttonParams.length>10||buttonParams.some((x:any)=>!Number.isInteger(x.index)||x.index<0||x.index>=buttons.length||!x.value||x.value.length>1024))throw Error('Os valores enviados para os botões são inválidos.');
      for(const bp of buttonParams){const type=String(buttons[bp.index]?.type||'').toUpperCase(),expected=type==='COPY_CODE'?'copy_code':type==='FLOW'?'flow':null;if(!expected||bp.subType!==expected)throw Error('O tipo de valor não corresponde ao botão aprovado.');}
      let headerMedia:any=null;
      if(['IMAGE','VIDEO','DOCUMENT'].includes(headerFormat)){
        const incoming=b.header_media;
        if(incoming){
          const type=String(incoming.type||'').toLowerCase(),mode=incoming.link?'link':incoming.id?'id':'',value=String(incoming.link||incoming.id||'').trim();
          if(type!==headerFormat.toLowerCase()||!mode||value.length>4000)throw Error('A mídia precisa corresponder ao tipo de cabeçalho aprovado.');
          if(mode==='link'){
            try{const u=new URL(value),probe=new URL(value);probe.search='';probe.hash='';urlPublica(probe.toString());if(u.protocol!=='https:'||u.username||u.password)throw Error();}
            catch{throw Error('Informe uma URL HTTPS pública para a mídia.');}
          }
          headerMedia={type,...(mode==='link'?{link:value}:{id:value})};
        }
        if(!opening&&!headerMedia)throw Error('Informe a URL pública ou o ID da mídia para enviar este cabeçalho.');
      }else if(b.header_media)throw Error('Este template não aceita mídia no cabeçalho.');
      const sendComponents:any[]=[];
      for(const kind of ['header','body']){
        const part=kind==='header'?header:body;if(!part)continue;
        const partSlots=slots.filter(s=>s.kind===kind);
        if(kind==='header'&&headerFormat!=='TEXT'){
          if(headerMedia){const media=headerMedia.link?{link:headerMedia.link}:{id:headerMedia.id};sendComponents.push({type:'header',parameters:[{type:headerFormat.toLowerCase(),[headerFormat.toLowerCase()]:media}]});}
        }else if(partSlots.length){sendComponents.push({type:kind,parameters:partSlots.map(s=>({type:'text',text:params[slots.indexOf(s)]}))});}
      }
      const urlSlots=slots.filter(s=>s.kind==='url');
      for(const slot of urlSlots)sendComponents.push({type:'button',sub_type:'url',index:String(slot.index),parameters:[{type:'text',text:params[slots.indexOf(slot)]}]});
      let bodyPreview=String(body?.text||'');
      slots.forEach((slot,i)=>{if(slot.kind==='body')bodyPreview=bodyPreview.replaceAll(`{{${slot.marker}}}`,params[i]);});
      let headerPreview=headerFormat==='TEXT'?String(header?.text||''):'';
      slots.forEach((slot,i)=>{if(slot.kind==='header')headerPreview=headerPreview.replaceAll(`{{${slot.marker}}}`,params[i]);});
      const preview=[headerPreview,bodyPreview,footer?.text,buttons.map((button:any)=>button.text).filter(Boolean).join(' · ')].filter(Boolean).join('\n');
      const rid=String(b.requisicao_id||'');
      if(!/^[0-9a-f-]{36}$/i.test(rid))throw Error('Identificador de envio inválido.');
      const [pending]=await q(db.from('atd_mensagens').upsert({workspace_id:ws,conversa_id:cv.id,requisicao_id:rid,direcao:'enviada',texto:assinatura(ctx.nome,preview,ch.canal),autor_id:user.id,autor_nome:ctx.nome,status:'enviando'}, {onConflict:'workspace_id,requisicao_id',ignoreDuplicates:true}).select());
      if(!pending)return json({ok:true,repetida:true});
      let attempted=false;
      try{
        attempted=true;
        if(opening&&ch.canal==='whatsapp'){
          const participantId=String(cv.endereco||'').replace(/\D/g,'');
          if(participantId.length<10||participantId.length>15)throw new Error('Telefone do contato inválido para o WhatsApp oficial.');
        }
        const result=opening
          ?await zernio(zp(),'/inbox/conversations','POST',{accountId:ch.externo_id,participantId:String(cv.endereco||'').replace(/\D/g,''),templateName:nome,templateLanguage:idioma,templateParams:params,...(buttonParams.length?{templateButtonParams:buttonParams}:{}),...(headerMedia?{headerMedia}:{})})
          :await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(cv.externo_id)+'/messages','POST',{accountId:ch.externo_id,template:{elements:[{name:nome,language:idioma,components:sendComponents}]},...(buttonParams.length?{templateButtonParams:buttonParams}:{})});
        const external=String(result.data?.messageId||result.messageId||'');
        if(!external)throw new Error('A Zernio não confirmou o identificador da mensagem.');
        if(opening){
          const remoteConversation=String(result.data?.conversationId||result.conversationId||'');
          if(!remoteConversation)throw new Error('A Zernio não confirmou a sessão da conversa.');
          await q(db.from('atd_conversas').update({externo_id:remoteConversation}).eq('id',cv.id).eq('workspace_id',ws).eq('externo_id',cv.externo_id));
        }
        await q(db.rpc('atd_confirmar_envio',{p_mensagem:pending.id,p_externo:external}));
        return json({ok:true});
      }catch(e){
        const known=!attempted||(e instanceof ProviderError&&e.status<500&&e.status!==408);
        await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:known?(e as Error).message:'Envio sem confirmação. Confira o histórico do provedor antes de tentar novamente.'}).eq('id',pending.id));
        return json({erro:known?(e as Error).message:'Envio sem confirmação. Atualize o histórico antes de reenviar.'},502);
      }
    }
    if(b.action==='templates-create'||b.action==='templates-update') {
      const nome=String(b.nome||'').trim(),language=String(b.idioma||'pt_BR').trim(),category=String(b.categoria||'');
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(language)
        ||!['UTILITY','MARKETING'].includes(category))throw Error('Nome, categoria ou idioma inválidos.');
      const raw=Array.isArray(b.componentes)?b.componentes:[];
      if(!raw.some((c:any)=>String(c.type||'').toLowerCase()==='body'))throw Error('O template precisa ter uma mensagem no corpo.');
      if(raw.filter((c:any)=>String(c.type||'').toLowerCase()==='header').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='body').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='footer').length>1||raw.filter((c:any)=>String(c.type||'').toLowerCase()==='buttons').length>1)throw Error('O template contém componentes repetidos.');
      const variaveis=(texto:string,exemplos:any[],nomeCampo:string)=>{
        const matches=[...texto.matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1])),count=Math.max(0,...matches);
        const values=Array.isArray(exemplos)?exemplos.map((v:unknown)=>String(v||'').trim()):[];
        if(count>10||matches.some(n=>n<1)||new Set(matches).size!==count||values.length!==count||values.some((x:string)=>!x||x.length>200))throw Error(`${nomeCampo}: informe um exemplo para cada variável {{1}}, {{2}} etc.`);
        return count?values:null;
      };
      const components:any[]=[];
      for(const c of raw){
        const type=String(c.type||'').toLowerCase();
        if(type==='header'){
          const format=String(c.format||'').toLowerCase();
          if(format==='text'){
            const text=String(c.text||'').trim(),example=variaveis(text,c.examples,'Cabeçalho');
            if(!text||text.length>60)throw Error('O cabeçalho de texto deve ter até 60 caracteres.');
            components.push({type:'header',format:'text',text,...(example?{example:{header_text:[example]}}:{})});
          }else if(['image','video','document'].includes(format)){
            let link='';try{link=urlPublica(String(c.example_url||'')).toString();}catch{throw Error('Informe uma URL HTTPS pública de exemplo para a mídia do cabeçalho.');}
            components.push({type:'header',format,example:{header_handle:[link]}});
          }else throw Error('Formato de cabeçalho inválido.');
        }else if(type==='body'){
          const text=String(c.text||'').trim(),example=variaveis(text,c.examples,'Mensagem');
          if(!text||text.length>1024)throw Error('A mensagem deve ter de 1 a 1.024 caracteres.');
          components.push({type:'body',text,...(example?{example:{body_text:[example]}}:{})});
        }else if(type==='footer'){
          const text=String(c.text||'').trim();if(!text||text.length>60||/\{\{/.test(text))throw Error('O rodapé deve ter até 60 caracteres e não aceita variáveis.');
          components.push({type:'footer',text});
        }else if(type==='buttons'){
          const buttons=Array.isArray(c.buttons)?c.buttons:[];
          if(!buttons.length||buttons.length>3)throw Error('Adicione de 1 a 3 botões.');
          const mapped=buttons.map((button:any)=>{
            const bt=String(button.type||'').toLowerCase(),text=String(button.text||'').trim();
            if(!['quick_reply','url','phone_number','copy_code','flow'].includes(bt))throw Error('Tipo de botão não suportado.');
            if(bt==='copy_code'){
              const example=String(button.example||'').trim();if(category!=='MARKETING'||!example||example.length>60)throw Error('O botão Copiar código exige um template de Marketing e um exemplo de cupom.');
              return {type:'copy_code',example};
            }
            if(!text||text.length>(bt==='flow'?20:25))throw Error('Cada botão precisa de um texto dentro do limite permitido.');
            if(bt==='quick_reply')return {type:'quick_reply',text};
            if(bt==='phone_number'){
              const phone=String(button.phone_number||'').trim();if(!/^\+[1-9]\d{6,14}$/.test(phone))throw Error('Informe o telefone do botão com DDI, no formato +5511999999999.');
              return {type:'phone_number',text,phone_number:phone};
            }
            if(bt==='flow'){
              const flowId=String(button.flow_id||'').trim(),screen=String(button.navigate_screen||'').trim(),action=String(button.flow_action||'navigate');
              if(!/^\d{5,30}$/.test(flowId)||!screen||screen.length>60||!['navigate','data_exchange'].includes(action))throw Error('O botão de formulário exige ID, ação e tela inicial válidos.');
              return {type:'flow',text,flow_id:flowId,flow_cta:text,flow_action:action,...(action==='navigate'?{navigate_screen:screen}:{})};
            }
            const url=String(button.url||'').trim(),vars=[...url.matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1])),count=Math.max(0,...vars);
            let parsed:URL;try{parsed=new URL(url.replace(/\{\{\d+\}\}/g,'exemplo'));}catch{throw Error('Informe uma URL válida para o botão.');}
            if(!['https:','http:'].includes(parsed.protocol)||parsed.username||parsed.password||count>1||(count&&vars.some(n=>n!==1)))throw Error('A URL do botão deve ser http(s) e pode ter apenas uma variável {{1}}.');
            const result:any={type:'url',text,url};
            if(count){const example=String(button.example||'').trim();if(!example||example.length>200)throw Error('Informe um exemplo para a variável dinâmica do botão de link.');result.example=[example];}
            return result;
          });
          const quick=mapped.filter((x:any)=>x.type==='quick_reply').length,cta=mapped.length-quick;
          if(quick&&cta||quick>3||cta>2)throw Error('Use até 3 botões de resposta rápida ou até 2 botões de link/telefone.');
          components.push({type:'buttons',buttons:mapped});
        }else throw Error('Tipo de componente não suportado.');
      }
      if(b.action==='templates-create') {
        const result=await zernio(zp(),'/whatsapp/templates','POST',{accountId,name:nome,language,category,components});
        return json({template:result.template,ok:true});
      }
      const templateId=String(b.template_id||'');
      if(!/^\d{5,30}$/.test(templateId))throw Error('ID do template inválido.');
      const result=await zernio(zp(),'/whatsapp/templates/id/'+encodeURIComponent(templateId),'PATCH',{accountId,components});
      return json({template:result.template,ok:true});
    }
    if(b.action==='templates-delete') {
      const id=String(b.template_id||'');
      if(!/^\d{5,30}$/.test(id))throw Error('ID do template inválido.');
      await zernio(zp(),'/whatsapp/templates/id/'+encodeURIComponent(id)+'?accountId='+encodeURIComponent(accountId),'DELETE');
      if(b.template_name&&b.idioma)await q(db.from('atd_template_mapeamentos').delete().eq('workspace_id',ws).eq('canal_id',ch.id).eq('template_name',String(b.template_name)).eq('idioma',String(b.idioma)));
      return json({ok:true});
    }
  }
  if (b.action === 'config') { const cfg = await secret(ws); return json({ url: cfg?.evolution_url || '', configurada: !!cfg, versao:'2.3.7' }); }
  if (b.action === 'remover-config') {
    const ativos=await q(db.from('atd_canais').select('id').eq('workspace_id',ws).eq('provedor','evolution').eq('ativo',true).limit(1));
    if(ativos.length)throw new Error('Remova os canais Evolution antes de remover a configuração da API.');
    await q(db.rpc('atd_segredo_remover',{p_ws:ws}));
    return json({ok:true});
  }
  if (b.action === 'salvar-config') {
    const previous = await secret(ws), u = urlPublica(String(b.url));
    const key = String(b.key || previous?.evolution_key || ''); if (!key) throw new Error('Informe a API Key.');
    const cfg = { evolution_url:u.toString().replace(/\/$/,''), evolution_key:key };
    // Read-only: confirma que URL e chave respondem antes de salvar.
    await evolution(cfg,'/instance/fetchInstances');
    await q(db.rpc('atd_segredo', { p_ws:ws,p_dados:{ url:cfg.evolution_url,key,secret:previous?.webhook_secret || crypto.randomUUID()+crypto.randomUUID() } }));
    return json({ ok:true });
  }
  if (b.action === 'criar-instancia') {
    const cfg = await secret(ws); if (!cfg) throw new Error('Configure a Evolution em Integrações.');
    const id = crypto.randomUUID(), instance = 'growths-' + id;
    // Persiste a identidade antes da chamada: webhook inicial já tem destino.
    const ch = await q(db.from('atd_canais').insert({ id,workspace_id:ws,provedor:'evolution',canal:'whatsapp',nome:String(b.nome || 'WhatsApp').slice(0,100),externo_id:instance,status:'configurando' }).select().single());
    try {
      await evolution(cfg,'/instance/create','POST',{ instanceName:instance,integration:'WHATSAPP-BAILEYS',qrcode:true });
      await setupWebhook(ch,cfg);
    } catch(e) { await q(db.from('atd_canais').update({status:'erro'}).eq('id',id)); throw e; }
    return json({ canal:ch });
  }
  if (b.action === 'identidades') {
    const channels=await q(db.from('atd_canais').select('id,nome,numero,provedor,canal,externo_id')
      .eq('workspace_id',ws).eq('ativo',true));
    // Atualiza o número da Evolution a partir da instância real, nunca por input do usuário.
    const evo=channels.filter((x:any)=>x.provedor==='evolution'&&x.canal==='whatsapp');
    if(evo.length){
      const cfg=await secret(ws);
      if(cfg){
        try{
          const result=await evolution(cfg,'/instance/fetchInstances');
          const instances=Array.isArray(result)?result:Array.isArray(result.instances)?result.instances:[];
          for(const c of evo){
            const item=instances.find((x:any)=>String(x.name||x.instance?.instanceName||x.instanceName||'')===c.externo_id);
            const raw=String(item?.ownerJid||item?.instance?.ownerJid||item?.number||item?.instance?.number||'');
            const number=raw.split('@')[0].replace(/\D/g,'');
            if(number.length>=10&&number.length<=15&&number!==c.numero){
              await q(db.from('atd_canais').update({numero:number}).eq('id',c.id).eq('workspace_id',ws));
              c.numero=number;
            }
          }
        }catch{/* Não impedir a caixa de entrada de abrir por falha no servidor Evolution. */}
      }
    }
    return json({canais:channels.map((c:any)=>({id:c.id,nome:c.nome,numero:c.numero||null}))});
  }
  if(b.action==='exibir-arquivados'){
    const ch=await channel(String(b.canal_id||''),ws);
    if(ch.provedor!=='evolution'||ch.canal!=='whatsapp')throw Error('Preferência exclusiva do WhatsApp Evolution.');
    const value=b.exibir===true;
    await q(db.from('atd_canais').update({exibir_grupos_arquivados:value}).eq('id',ch.id).eq('workspace_id',ws));
    return json({ok:true,exibir:value});
  }
  if(b.action==='arquivar-grupo'){
    const cv=await q(db.from('atd_conversas').select('id,grupo,canal_id').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    const ch=await channel(cv.canal_id,ws);
    if(!cv.grupo||ch.provedor!=='evolution')throw Error('Operação exclusiva de grupos Evolution.');
    await q(db.from('atd_conversas').update({arquivada:b.arquivar===true})
      .eq('id',cv.id).eq('workspace_id',ws).eq('canal_id',ch.id));
    return json({ok:true,arquivada:b.arquivar===true});
  }
  if(b.action==='avatars'){
    const ids=Array.isArray(b.ids)?b.ids.filter((x:any)=>typeof x==='string'&&/^[a-f0-9-]{36}$/i.test(x)).slice(0,35):[];
    if(!ids.length)return json({avatares:{}});
    const rows=await q(db.from('atd_conversas').select('id,avatar_path')
      .eq('workspace_id',ws).in('id',ids));
    const out:Record<string,string>={};
    for(const cv of rows){
      if(!cv.avatar_path?.startsWith(ws+'/avatars/'))continue;
      try{
        const signed=await q(db.storage.from('atendimento').createSignedUrl(cv.avatar_path,300));
        out[cv.id]=signed.signedUrl;
      }catch{}
    }
    return json({avatares:out});
  }
  if(b.action==='avatar'){
    const cv=await q(db.from('atd_conversas').select('id,avatar_path').eq('id',b.conversa_id)
      .eq('workspace_id',ws).single());
    if(!cv.avatar_path || !cv.avatar_path.startsWith(ws+'/avatars/'))return json({url:null});
    const signed=await q(db.storage.from('atendimento').createSignedUrl(cv.avatar_path,300));
    return json({url:signed.signedUrl});
  }
  if (b.action === 'zernio-disponiveis') return json({ contas:await zernioDisponiveis(ws) });
  if (b.action === 'zernio-conectar') {
    const id = String(b.account_id || '');
    if (!id || id.length > 160) throw new Error('Selecione uma conta válida.');
    // Nunca confiar em nome, plataforma ou workspace recebidos do navegador.
    const account = (await zernioDisponiveis(ws)).find((a:any)=>a.id===id);
    if (!account) throw new Error('Conta indisponível ou vinculada a outro cliente.');
    const rows = await q(db.from('conexoes').upsert({
      workspace_id:ws,plataforma:'zernio',status:'conectado',
      conta_nome:'Zernio',conectado_em:new Date().toISOString(),conectado_por:user.id
    },{onConflict:'workspace_id,plataforma'}).select('id').single());
    const previous = await q(db.from('conexao_contas').select('id,workspace_id').eq('conexao_id',rows.id).eq('tipo',account.canal).eq('id_externo',account.id).maybeSingle());
    if (!previous) await q(db.from('conexao_contas').insert({
      workspace_id:ws,conexao_id:rows.id,tipo:account.canal,id_externo:account.id,nome:account.nome
    }));
    return json({ ok:true, conta:account.nome });
  }
  if (b.action === 'zernio-contas') return json({ contas:await zernioCandidates(ws) });
  if (b.action === 'zernio-webhooks') {
    const channels=await q(db.from('atd_canais').select('*').eq('workspace_id',ws).eq('provedor','zernio').eq('ativo',true));
    if(!channels.length)return json({ok:true,configurado:false});
    await setupWebhook(channels[0],null);
    return json({ok:true,configurado:true});
  }
  if (b.action === 'zernio-vincular') {
    const a = (await zernioCandidates(ws)).find((a: any) => a.id === b.account_id);
    if (!a) throw new Error('Conta não vinculada ao perfil Zernio deste workspace.');
    const existing = await q(db.from('atd_canais').select('workspace_id').eq('provedor','zernio').eq('externo_id',a.id).maybeSingle());
    if(existing && existing.workspace_id!==ws) throw new Error('Esta conta já pertence a outro workspace.');
    if(existing){
      await q(db.from('atd_canais').update({ativo:true,status:'conectado'}).eq('workspace_id',ws).eq('provedor','zernio').eq('externo_id',a.id));
    }
    const row = await q(db.from('atd_canais').upsert({workspace_id:ws,provedor:'zernio',canal:a.canal,nome:a.nome,externo_id:a.id,status:'conectado'}, {onConflict:'provedor,externo_id',ignoreDuplicates:true}).select());
    const linked=await q(db.from('atd_canais').select('*').eq('workspace_id',ws).eq('provedor','zernio').eq('externo_id',a.id).single());
    await setupWebhook(linked,null);
    return json({ ok:true, canais:row });
  }
  if (b.action === 'mensagens') {
    const cv = await q(db.from('atd_conversas').select('*').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    let query = db.from('atd_mensagens').select('*').eq('conversa_id',cv.id).order('em',{ascending:false}).order('id',{ascending:false}).limit(60);
    if (b.before) {
      if (!/^[0-9a-f-]{36}$/i.test(b.before.id || '') || !Number.isFinite(Date.parse(b.before.em))) throw new Error('Cursor inválido.');
      const date = new Date(b.before.em).toISOString();
      query = query.or(`em.lt.${date},and(em.eq.${date},id.lt.${b.before.id})`);
    }
    return json({ mensagens:await q(query) });
  }
  if (['enviar','nota','atualizar','vincular','criar-lead','historico'].includes(b.action)) {
    const cv = await q(db.from('atd_conversas').select('*').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    const ch = await channel(cv.canal_id,ws);
    if (b.action === 'historico') return json(await backfill(ch,cv,b.cursor));
    if(b.action==='enviar'&&ch.provedor==='zernio'&&String(cv.externo_id).startsWith('pending:'))throw Error('Para iniciar no WhatsApp oficial, envie um template aprovado primeiro.');
    if (b.action === 'vincular') {
      if (cv.grupo) throw new Error('Grupos mantêm participantes separados; não representam um único lead.');
      if (b.pessoa_id) await q(db.from('pessoas').select('id').eq('id',b.pessoa_id).eq('workspace_id',ws).single());
      await q(db.from('atd_conversas').update({pessoa_id:b.pessoa_id || null}).eq('id',cv.id)); return json({ok:true});
    }
    if (b.action === 'criar-lead') {
      if (cv.grupo || cv.pessoa_id) throw new Error('Conversa já vinculada ou de grupo.');
      const phone = ch.canal === 'whatsapp' && cv.endereco?.endsWith('@s.whatsapp.net') ? cv.endereco.split('@')[0] : null;
      const person = await q(db.from('pessoas').insert({workspace_id:ws,nome:cv.nome,telefone:phone,canal_origem:ch.canal}).select('id').single());
      await q(db.from('atd_conversas').update({pessoa_id:person.id}).eq('id',cv.id)); return json({ok:true});
    }
    if (b.action === 'atualizar') {
      const patch: any = {};
      if (['aberta','aguardando','resolvida'].includes(b.status)) patch.status = b.status;
      if ('responsavel_id' in b) patch.responsavel_id = b.responsavel_id || null;
      if (b.lida) patch.nao_lidas = 0;
      await q(db.from('atd_conversas').update(patch).eq('id',cv.id)); return json({ok:true});
    }
    const text = String(b.texto || '').trim(); if ((!text && (!b.arquivo || b.action==='nota')) || text.length>4000) throw new Error('Escreva uma mensagem ou anexe um arquivo de até 8 MB.');
    if (!/^[0-9a-f-]{36}$/i.test(b.requisicao_id || '')) throw new Error('Identificador de envio inválido.');
    if (!ctx.nome) throw new Error('Não encontrei seu nome. Atualize o nome do perfil da sua conta e entre novamente.');
    const note = b.action === 'nota';
    if (!note && (!ch.ativo || ch.status !== 'conectado')) throw new Error('Conecte este canal antes de enviar.');
    const signed = note ? text : text ? assinatura(ctx.nome,text,ch.canal) : '';
    const [pending] = await q(db.from('atd_mensagens').upsert({workspace_id:ws,conversa_id:cv.id,requisicao_id:b.requisicao_id,direcao:note?'nota':'enviada',texto:signed,autor_id:user.id,autor_nome:ctx.nome,status:note?'nota':'enviando'}, {onConflict:'workspace_id,requisicao_id',ignoreDuplicates:true}).select());
    if (!pending) return json({ok:true,repetida:true}); // nunca reenvia em timeout/duplo clique
    if (note) return json({ok:true});
    let attempted = false;
    try {
      const adapter = providers[ch.provedor]; if (!adapter) throw new Error('Provedor ainda não suporta envio.');
      const cfg = ch.provedor === 'evolution' ? await secret(ws) : {key:zp()};
      let media;
      if (b.arquivo) {
        const bytes = base64Bytes(String(b.arquivo.base64));
        const mime = String(b.arquivo.mime || 'application/octet-stream').toLowerCase().split(';')[0].trim();
        if (!/^(image\/(jpeg|png|webp)|video\/mp4|audio\/(ogg|mpeg|mp4|webm|wav|x-wav)|application\/pdf)$/.test(mime)) throw new ProviderError(400,'TIPO_ARQUIVO_INVALIDO');
        const path = `${ws}/${pending.id}/0`, nome = String(b.arquivo.nome || 'Arquivo').slice(0,150);
        await q(db.storage.from('atendimento').upload(path,bytes,{contentType:mime}));
        await q(db.from('atd_mensagens').update({anexos:[{path,nome,mime,tamanho:bytes.length}]}).eq('id',pending.id));
        const signedUrl = await q(db.storage.from('atendimento').createSignedUrl(path,300));
        media = {url:signedUrl.signedUrl,nome,mime,bytes,gravado:b.arquivo.gravado===true&&mime.startsWith('audio/')};
      }
      attempted = true;
      const id = await adapter.send(cfg,ch,cv,signed,media);
      // Um webhook pode ter chegado antes da resposta de envio. Consolida sem duplicar.
      await q(db.rpc('atd_confirmar_envio',{p_mensagem:pending.id,p_externo:id}));
      return json({ok:true});
    } catch(e) {
      const known = !attempted || (e instanceof ProviderError && e.status < 500 && e.status !== 408);
      await q(db.from('atd_mensagens').update({status:known?'falhou':'incerto',erro:known?(e as Error).message:'Envio sem confirmação. Confira o histórico do provedor antes de tentar novamente.'}).eq('id',pending.id));
      return json({erro:known?(e as Error).message:'Envio sem confirmação. Atualize o histórico antes de reenviar.'},502);
    }
  }
  if (b.action === 'anexo' || b.action === 'recuperar-midia') {
    const msg = await q(db.from('atd_mensagens').select('*').eq('id',b.mensagem_id).eq('workspace_id',ws).single());
    const cv = await q(db.from('atd_conversas').select('canal_id').eq('id',msg.conversa_id).single());
    if (b.action === 'recuperar-midia') { await saveMedia(await channel(cv.canal_id,ws),msg); return json({ok:true}); }
    const a = msg.anexos[Number(b.indice)]; if (!a?.path || !a.path.startsWith(ws+'/')) throw new Error('Anexo ainda não armazenado.');
    return json(await q(db.storage.from('atendimento').createSignedUrl(a.path,b.visualizar===true?300:60,b.visualizar===true?{}:{download:a.nome})));
  }
  const ch = await channel(b.canal_id,ws);
  if (b.action === 'excluir-instancia') {
    if (ch.provedor !== 'evolution' || ch.canal !== 'whatsapp')
      return json({erro:'A exclusão remota é exclusiva das instâncias QR Code da Evolution.'},400);
    // A instância é sempre resolvida pelo canal do workspace autenticado.
    // Não aceita nome/URL da instância enviados pelo navegador.
    const cfg=await secret(ws);
    if(!cfg)throw new Error('Configure a Evolution para excluir a instância remota.');
    const inst=String(ch.externo_id||'');
    if(!/^growths-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(inst))
      return json({erro:'Nome de instância não reconhecido. Exclusão remota bloqueada.'},409);
    // Exige sucesso remoto antes de desativar o canal local. Mantém histórico.
    try {
      await evolution(cfg,'/instance/delete/'+encodeURIComponent(inst),'DELETE');
    } catch(e) {
      if(!(e instanceof ProviderError && e.status===404))throw e;
      // 404 pode indicar instância já removida; não falhar apenas por ausência.
    }
    await q(db.from('atd_canais').update({ativo:false,status:'desativado'})
      .eq('id',ch.id).eq('workspace_id',ws).eq('provedor','evolution'));
    return json({ok:true,instancia_excluida:true,historico_preservado:true});
  }
  if (b.action === 'desativar') {
    const agenda=await q(db.from('atd_agendamentos').select('id,atd_conversas!inner(canal_id)').eq('workspace_id',ws).eq('atd_conversas.canal_id',ch.id).in('status',['agendado','processando']).limit(1));
    if(agenda.length)throw new Error('Há mensagens agendadas neste canal. Cancele ou aguarde os envios antes de removê-lo.');
    const disparos=await q(db.from('atd_disparos_grupos_itens').select('id').eq('workspace_id',ws).eq('canal_id',ch.id).in('status',['agendado','processando']).limit(1));
    if(disparos.length)throw new Error('Há disparos programados neste canal. Cancele ou aguarde os envios antes de removê-lo.');
    await q(db.from('atd_canais').update({ativo:false,status:'desativado'}).eq('id',ch.id).eq('workspace_id',ws));
    return json({ok:true,historico_preservado:true});
  }
  if (b.action === 'webhook') { await setupWebhook(ch, ch.provedor === 'evolution' ? await secret(ws) : null); return json({ok:true}); }
  if (b.action === 'grupos-busca-status') return json({
    estado:ch.grupos_busca_estado||'ociosa',
    resultado:ch.grupos_busca_resultado||{},
    atualizada_em:ch.grupos_busca_atualizada_em||null
  });
  if (b.action === 'sincronizar') {
    const mode=['conversas','grupos_sem_nome','grupos_novos'].includes(b.modo_sincronizacao)?b.modo_sincronizacao:'all';
    if(mode==='grupos_novos'){
      if(ch.provedor!=='evolution'||ch.canal!=='whatsapp'||!ch.ativo)throw new Error('Selecione um chip Evolution ativo.');
      const running=ch.grupos_busca_estado==='em_andamento'&&ch.grupos_busca_atualizada_em&&Date.now()-new Date(ch.grupos_busca_atualizada_em).getTime()<3*60*1000;
      if(running)return json({busca_em_andamento:true});
      const started=new Date().toISOString();
      await q(db.from('atd_canais').update({grupos_busca_estado:'em_andamento',grupos_busca_resultado:{},grupos_busca_atualizada_em:started}).eq('id',ch.id).eq('workspace_id',ws));
      EdgeRuntime.waitUntil((async()=>{
        try{
          const resultado=await syncConversations(ch,undefined,'grupos_novos');
          await q(db.from('atd_canais').update({grupos_busca_estado:'concluida',grupos_busca_resultado:resultado,grupos_busca_atualizada_em:new Date().toISOString()}).eq('id',ch.id).eq('workspace_id',ws));
        }catch(e){
          const mensagem=(e as Error).message||'Falha ao consultar grupos.';
          console.warn('atendimento evolução: busca de grupos em segundo plano falhou',{canal:ch.id,causa:mensagem.slice(0,180)});
          await q(db.from('atd_canais').update({grupos_busca_estado:'falhou',grupos_busca_resultado:{erro:mensagem.slice(0,220)},grupos_busca_atualizada_em:new Date().toISOString()}).eq('id',ch.id).eq('workspace_id',ws));
        }
      })());
      return json({busca_em_andamento:true});
    }
    return json(await syncConversations(ch,b.cursor,mode));
  }
  if (b.action === 'status' && ch.provedor === 'zernio') {
    const raw=await zernio(zp(),'/accounts/'+encodeURIComponent(ch.externo_id)+'/health');
    const health=raw.data||raw,live=health.platformConnection?.status;
    const status=live==='connected'?'conectado':live==='disconnected'?'desconectado':ch.status;
    if(status!==ch.status)await q(db.from('atd_canais').update({status}).eq('id',ch.id).eq('workspace_id',ws));
    return json({status,phone_status:health.platformConnection?.phoneStatus||null,webhook_recebimento:health.platformConnection?.inboundWebhookSubscribed??null,verificado_em:health.platformConnection?.checkedAt||new Date().toISOString()});
  }
  if (ch.provedor !== 'evolution') throw new Error('Operação exclusiva da Evolution.');
  const cfg = await secret(ws), inst = encodeURIComponent(ch.externo_id);
  if (b.action === 'conectar') { const r = await evolution(cfg,'/instance/connect/'+inst); return json({qrcode:r.base64 || r.qrcode?.base64 || null,pairingCode:r.pairingCode || null}); }
  if (b.action === 'status') {
    const r = await evolution(cfg,'/instance/connectionState/'+inst), state = r.instance?.state || r.state;
    const status = state === 'open' ? 'conectado' : state === 'connecting' ? 'conectando' : 'desconectado';
    await q(db.from('atd_canais').update({status}).eq('id',ch.id)); return json({status});
  }
  throw new Error('Ação desconhecida.');
}
async function setupWebhook(ch: any,cfg: any) {
  const root = URL_SB + '/functions/v1/atendimento?provider=' + ch.provedor;
  if (ch.provedor === 'evolution') {
    await evolution(cfg,'/webhook/set/'+encodeURIComponent(ch.externo_id),'POST',{webhook:{enabled:true,url:root+'&channel='+ch.id,headers:{'x-atd-secret':cfg.webhook_secret},byEvents:false,base64:false,events:['MESSAGES_UPSERT','MESSAGES_UPDATE','CONNECTION_UPDATE','GROUPS_UPSERT','GROUPS_UPDATE']}});
  } else {
    const s = Deno.env.get('ZERNIO_ATENDIMENTO_WEBHOOK_SECRET'); if (!s) throw new Error('Configure ZERNIO_ATENDIMENTO_WEBHOOK_SECRET no servidor.');
    const current = await zernio(zp(),'/webhooks/settings');
    const payload=current.data;
    const rows: any[]=Array.isArray(current.webhooks)?current.webhooks:Array.isArray(payload?.webhooks)?payload.webhooks:Array.isArray(payload)?payload:[];
    const existing=rows.find((w:any)=>w.url===root);
    const events=['message.received','message.sent','message.delivered','message.read','message.failed'];
    if(existing?._id||existing?.id){
      await zernio(zp(),'/webhooks/settings','PUT',{webhookId:existing._id||existing.id,name:'Growths Atendimento',url:root,secret:s,events:[...new Set([...(Array.isArray(existing.events)?existing.events:[]),...events])],isActive:true});
    }else{
      await zernio(zp(),'/webhooks/settings','POST',{name:'Growths Atendimento',url:root,secret:s,events,isActive:true});
    }
  }
}
// Metadados de grupo e foto: sempre por instância autenticada do workspace.
// Evita misturar fotos/nomes de clientes, sem expor URLs remotas no frontend.
// Metadados Evolution v2.3.x: GET /group/findGroupInfos/{instance}?groupJid=...
// Todas as buscas usam a credencial do workspace e nunca expõem URLs externas.
const isJid=(jid:string)=>/^[0-9]{5,22}@(g\.us|s\.whatsapp\.net|lid)$/.test(jid);
const groupNameMissing=(g:any):boolean=>{
  const name=String(g?.nome||'').trim();
  return !name||name===g?.externo_id||isJid(name);
};
const groupKind=(g:any):string|null=>{
  if(g?.isCommunityAnnounce===true||g?.groupMetadata?.isCommunityAnnounce===true)return 'avisos_comunidade';
  if(g?.isCommunity===true||g?.groupMetadata?.isCommunity===true)return 'comunidade';
  return null;
};
const groupParent=(g:any):string|null=>{
  const parent=String(g?.linkedParent||g?.parentGroupJid||g?.communityId||g?.groupMetadata?.linkedParent||'').trim();
  return isJid(parent)&&parent.endsWith('@g.us')?parent:null;
};
const groupName=(g:any):string=>{
  const find=(keys:string[])=>{
    const queue:any[]=[g],seen=new Set<any>();
    while(queue.length){
      const current=queue.shift();
      if(!current||typeof current!=='object'||seen.has(current))continue;
      seen.add(current);
      if(Array.isArray(current)){queue.push(...current);continue;}
      for(const key of keys){
        const value=String(current[key]||'').trim().slice(0,180);
        if(value&&!isJid(value))return value;
      }
      for(const key of ['groupMetadata','group','groupInfo','data','result','response','metadata','payload'])
        if(current[key]&&typeof current[key]==='object')queue.push(current[key]);
    }
    return '';
  };
  return find(['subject'])||find(['groupName','title','name','notify','formattedName','displayName','pushName']);
};
const unwrapGroupMeta=(value:any):any=>{
  const queue:any[]=[value],seen=new Set<any>();
  while(queue.length){
    const current=queue.shift();
    if(!current||typeof current!=='object'||seen.has(current))continue;
    seen.add(current);
    if(Array.isArray(current)){queue.push(...current);continue;}
    if(groupName(current)||groupPicture(current)||current.groupMetadata)return current;
    for(const key of ['data','result','response','group','groupInfo','metadata','payload'])
      if(current[key]&&typeof current[key]==='object')queue.push(current[key]);
  }
  return {};
};
const groupPicture=(g:any):string=>{
  const queue:any[]=[g],seen=new Set<any>();
  while(queue.length){
    const current=queue.shift();
    if(!current||typeof current!=='object'||seen.has(current))continue;
    seen.add(current);
    if(Array.isArray(current)){queue.push(...current);continue;}
    const picture=String(current.pictureUrl||current.profilePictureUrl||'').trim();
    if(picture)return picture;
    for(const key of ['groupMetadata','group','groupInfo','data','result','response','metadata','payload'])
      if(current[key]&&typeof current[key]==='object')queue.push(current[key]);
  }
  return '';
};
const groupMembers=(g:any):number|null=>{
  const queue:any[]=[g],seen=new Set<any>();
  while(queue.length){
    const current=queue.shift();
    if(!current||typeof current!=='object'||seen.has(current))continue;
    seen.add(current);
    if(Array.isArray(current)){queue.push(...current);continue;}
    const raw=current.size??current.participantCount??current.membersCount??current.totalMembers;
    if(raw!==undefined&&raw!==null&&raw!==''&&Number.isInteger(Number(raw))&&Number(raw)>=0)return Number(raw);
    if(Array.isArray(current.participants))return current.participants.length;
    for(const key of ['groupMetadata','group','groupInfo','data','result','response','metadata','payload'])
      if(current[key]&&typeof current[key]==='object')queue.push(current[key]);
  }
  return null;
};
async function storedAvatar(ch:any,jid:string,cfg:any,preferredUrl=''):Promise<string|null>{
  if(!isJid(jid))return null;
  const urls:string[]=[];
  if(preferredUrl.startsWith('https://'))urls.push(preferredUrl);
  try{
    // Usar pictureUrl do grupo primeiro; fallback ao endpoint do perfil se falhar.
    const photo=await evolution(cfg,'/chat/fetchProfilePictureUrl/'+encodeURIComponent(ch.externo_id),'POST',{number:jid});
    const url=String(photo.profilePictureUrl||photo.profilePicture||photo.picture||photo.url||'');
    if(url.startsWith('https://')&&!urls.includes(url))urls.push(url);
  }catch{/* O contato pode não ter foto visível. */}
  for(const url of urls){
    try{
      const bytes=await mediaBytes(url); // HTTPS e SSRF verificados pelo helper existente.
      if(!bytes.length||bytes.length>512*1024)continue;
      const mime=bytes[0]===255&&bytes[1]===216?'image/jpeg':
        bytes[0]===137&&bytes[1]===80?'image/png':
        new TextDecoder().decode(bytes.slice(0,4))==='RIFF'?'image/webp':null;
      if(!mime)continue;
      const hashBuffer=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(jid));
      const hash=Array.from(new Uint8Array(hashBuffer),v=>v.toString(16).padStart(2,'0')).join('').slice(0,32);
      const ext=mime==='image/png'?'.png':mime==='image/webp'?'.webp':'.jpg';
      const path=ch.workspace_id+'/avatars/'+ch.id+'/'+hash+ext;
      await q(db.storage.from('atendimento').upload(path,bytes,{contentType:mime,upsert:true}));
      return path;
    }catch{/* Fotos protegidas/expiradas não devem travar a importação. */}
  }
  return null;
}
async function refreshAvatar(ch:any,cv:any,cfg:any,url=''):Promise<boolean>{
  if(cv.avatar_atualizado_em&&Date.now()-Date.parse(cv.avatar_atualizado_em)<86400000)return false;
  const path=await storedAvatar(ch,cv.externo_id,cfg,url);
  if(!path)return false;
  await q(db.from('atd_conversas').update({avatar_path:path,avatar_atualizado_em:new Date().toISOString()})
    .eq('id',cv.id).eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id));
  return true;
}
async function resolveGroupName(ch:any,cv:any,original:any,cfg:any,forceLookup=false):
  Promise<{named:boolean,detailsOk:boolean,failure?:string,meta:any,members:number|null}>{
  const jid=String(cv.externo_id||'');
  if(!isJid(jid)||!jid.endsWith('@g.us'))return {named:false,detailsOk:false,meta:original||{},members:null};
  let meta=original||{},name=groupName(meta),detailsOk=Boolean(name);
  let failure:string|undefined;
  if(forceLookup||!name||!cv.avatar_path||cv.grupo_membros==null){
    try{
      // Corrigido v0.190: a rota é GET e groupJid pertence à query, não ao corpo POST.
      const params=new URLSearchParams({groupJid:jid});
      const response=await evolution(cfg,'/group/findGroupInfos/'+encodeURIComponent(ch.externo_id)+'?'+params.toString());
      meta={...meta,...unwrapGroupMeta(response)};
      name=groupName(meta)||name;
      detailsOk=Boolean(name||groupPicture(meta)||groupMembers(meta)!=null);
    }catch(e){failure=evolutionFailure(e);}
  }
  let named=false;
  const members=groupMembers(meta),updates:any={};
  if(name&&name!==jid&&name!==cv.nome){
    updates.nome=name;
    named=true;
  }
  const metadata={...original,...meta},kind=groupKind(metadata),parent=groupParent(metadata);
  if(members!=null&&members!==cv.grupo_membros)updates.grupo_membros=members;
  if(kind||parent){updates.grupo_tipo=kind||'grupo';updates.grupo_pai_externo_id=parent;}
  if(Object.keys(updates).length)await q(db.from('atd_conversas').update(updates)
    .eq('id',cv.id).eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id));
  return {named,detailsOk,failure,meta,members};
}
async function enrichGroup(ch:any,cv:any,original:any,cfg:any):
  Promise<{named:boolean,photo:boolean,detailsOk:boolean,failure?:string}>{
  const resolved=await resolveGroupName(ch,cv,original,cfg);
  const photo=await refreshAvatar(ch,cv,cfg,groupPicture(resolved.meta)||groupPicture(original));
  return {named:resolved.named,photo,detailsOk:resolved.detailsOk,failure:resolved.failure};
}
async function syncConversations(ch:any,cursor?:string,mode='all'){
  if(ch.provedor==='evolution'){
    const cfg=await secret(ch.workspace_id),inst=encodeURIComponent(ch.externo_id);
    if(!cfg)throw Error('A Evolution não está configurada para este cliente.');
    const warnings:string[]=[];
    const shape=(raw:any):any[]=>Array.isArray(raw)?raw:
      Array.isArray(raw?.groups)?raw.groups:
      Array.isArray(raw?.chats)?raw.chats:
      Array.isArray(raw?.data)?raw.data:
      Array.isArray(raw?.data?.groups)?raw.data.groups:
      Array.isArray(raw?.data?.chats)?raw.data.chats:
      Array.isArray(raw?.response)?raw.response:
      Array.isArray(raw?.result)?raw.result:
      Array.isArray(raw?.data?.result)?raw.data.result:[];
    let chatRows:any[]=[],groupRows:any[]=[],groupFetchOk=false;
    if(mode!=='grupos_sem_nome'&&mode!=='grupos_novos')try{
      chatRows=shape(await evolution(cfg,'/chat/findChats/'+inst));
    }catch(first){
      // Algumas instalações Evolution 2.3.7 ainda expõem findChats via POST.
      // Tenta o contrato legado apenas se o GET não estiver disponível.
      if(first instanceof ProviderError&&first.status===404){
        try{chatRows=shape(await evolution(cfg,'/chat/findChats/'+inst,'POST',{}));}
        catch(second){warnings.push('Conversas: '+evolutionFailure(second));console.warn('atendimento evolução: findChats falhou nos métodos GET e POST',{canal:ch.id,causa:evolutionFailure(second)});}
      }else{warnings.push('Conversas: '+evolutionFailure(first));console.warn('atendimento evolução: findChats falhou',{canal:ch.id,causa:evolutionFailure(first)});}
    }
    if(mode!=='conversas'&&mode!=='grupos_sem_nome')try{
      // fetchAllGroups pode demorar quando a instância tem histórico amplo.
      groupRows=shape(await evolution(cfg,'/group/fetchAllGroups/'+inst+'?getParticipants=false','GET',undefined,120000));
      groupFetchOk=true;
      if(mode==='grupos_novos')await q(db.from('atd_canais').update({
        grupos_busca_resultado:{grupos_encontrados:groupRows.length,novos_grupos:null,parcial:true},
        grupos_busca_atualizada_em:new Date().toISOString()
      }).eq('id',ch.id).eq('workspace_id',ch.workspace_id));
    }catch(e){warnings.push('Grupos: '+evolutionFailure(e));console.warn('atendimento evolução: fetchAllGroups falhou',{canal:ch.id,causa:evolutionFailure(e)});}
    const existingGroupIds=mode==='grupos_novos'?new Set((await q(db.from('atd_conversas').select('externo_id')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',true).limit(5000))).map((g:any)=>g.externo_id)):new Set<string>();
    let newGroups=0;
    const byJid=new Map<string,any>();
    for(const item of chatRows){
      const id=String(item?.remoteJid||item?.id||item?.jid||item?.groupJid||'');
      if(!isJid(id))continue;
      const previous=byJid.get(id);
      if(!previous||(id.endsWith('@g.us')&&groupName(item)&&!groupName(previous)))byJid.set(id,item);
    }
    // `fetchAllGroups` is the authoritative source for group subject and
    // pictureUrl. `findChats` may return an older subject or no picture, so
    // always merge canonical group metadata over the chat snapshot.
    for(const item of groupRows){
      const id=String(item?.remoteJid||item?.id||item?.jid||item?.groupJid||'');
      if(!isJid(id)||!id.endsWith('@g.us'))continue;
      const previous=byJid.get(id)||{};
      const name=groupName(item)||groupName(previous),picture=groupPicture(item)||groupPicture(previous);
      byJid.set(id,{...previous,...item,...(name?{subject:name}:{}),...(picture?{pictureUrl:picture}:{})});
    }
    for(const [id,item] of byJid){
      const group=id.endsWith('@g.us');
      const name=group?groupName(item):
        String(item.pushName||item.name||item.contact?.pushName||'').trim().slice(0,180);
      await q(db.rpc('atd_receber',{p_canal:ch.id,
        p_conversa:{id,nome:name&&name!==id?name:undefined,endereco:id,grupo:group}}));
      if(group){
        const kind=groupKind(item),parent=groupParent(item);
        const members=groupMembers(item),metadata:any={};
        if(kind||parent){metadata.grupo_tipo=kind||'grupo';metadata.grupo_pai_externo_id=parent;}
        if(members!=null)metadata.grupo_membros=members;
        if(Object.keys(metadata).length)await q(db.from('atd_conversas').update(metadata)
          .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('externo_id',id));
      }
      if(mode==='grupos_novos'&&group&&!existingGroupIds.has(id))newGroups++;
    }
    if(mode==='conversas')return {total:byJid.size,cursor:null};
    if(mode==='grupos_novos'){
      if(!groupFetchOk)throw new Error(warnings.find((w:string)=>w.startsWith('Grupos:'))||'Não foi possível buscar novos grupos.');
      const scannedAt=new Date().toISOString();
      await q(db.from('atd_canais').update({grupos_sincronizados_em:scannedAt}).eq('id',ch.id).eq('workspace_id',ch.workspace_id));
      return {grupos_encontrados:groupRows.length,novos_grupos:newGroups,grupos_sincronizados_em:scannedAt,avisos:[...new Set(warnings)].slice(0,4)};
    }
    // A recuperação deve funcionar mesmo que fetchAllGroups falhe: usar grupos
    // do banco, sem depender de um novo evento do WhatsApp.
    let groupQuery=db.from('atd_conversas')
      .select('id,externo_id,nome,avatar_path,avatar_atualizado_em,grupo_membros')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',true);
    // Para recuperar nomes, primeiro restringe no banco às linhas cujo nome
    // ainda é um JID. Só depois aplica o cursor; assim nomes válidos à frente
    // na tabela não escondem grupos pendentes.
    const cursorJid=mode==='grupos_sem_nome'&&String(cursor||'').startsWith('g:')
      ?decodeURIComponent(String(cursor).slice(2)):'';
    if(mode==='grupos_sem_nome'){
      groupQuery=groupQuery.like('nome','%@g.us');
      if(cursorJid)groupQuery=groupQuery.gt('externo_id',cursorJid);
    }
    const groups=await q(groupQuery.order('externo_id',{ascending:true})
      .limit(mode==='grupos_sem_nome'?2500:150));
    const needsMetadata=(g:any)=>groupNameMissing(g)||!g.avatar_path||g.grupo_membros==null;
    const initialMissing=groups.filter(groupNameMissing).length;
    const offset=/^g:(\d+)$/.test(String(cursor||''))?Number(String(cursor).split(':')[1]):0;
    const start=mode==='grupos_sem_nome'?0:Math.min(Number.isFinite(offset)?offset:0,Math.max(0,groups.length-1));
    const page=mode==='grupos_sem_nome'?groups.slice(0,8):groups.slice(start,start+8);
    const subset=mode==='grupos_sem_nome'?page.filter((g:any)=>groupNameMissing(g)&&isJid(String(g.nome||''))&&String(g.nome).endsWith('@g.us')):page;
    let named=0,photos=0,details=0;
    for(let i=0;i<subset.length;i+=4){
      const resolver=mode==='grupos_sem_nome'?resolveGroupName:enrichGroup;
      const results=await Promise.allSettled(subset.slice(i,i+4).map((g:any)=>
        mode==='grupos_sem_nome'
          ? resolveGroupName(ch,g,byJid.get(g.externo_id)||{},cfg,true)
          : resolver(ch,g,byJid.get(g.externo_id)||{},cfg)));
      for(const result of results){
        if(result.status!=='fulfilled'){warnings.push('Detalhes do grupo: falha de consulta');continue;}
        if(result.value.named)named++;
        if('photo' in result.value&&result.value.photo)photos++;
        if(result.value.detailsOk)details++;
        if(result.value.failure)warnings.push('Detalhes: '+result.value.failure);
      }
    }
    // Buscar fotos também dos contatos recentes, independentemente dos grupos.
    if(mode!=='grupos_sem_nome'){
      const contacts=await q(db.from('atd_conversas')
        .select('id,externo_id,avatar_atualizado_em')
        .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',false)
        .order('ultima_em',{ascending:false,nullsFirst:false}).limit(4));
      const cp=await Promise.allSettled(contacts.filter((cv:any)=>isJid(cv.externo_id))
        .map((cv:any)=>refreshAvatar(ch,cv,cfg)));
      photos+=cp.filter(x=>x.status==='fulfilled'&&x.value===true).length;
    }
    let remainingQuery=db.from('atd_conversas').select('id,externo_id,nome,avatar_path,grupo_membros')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',true);
    if(mode==='grupos_sem_nome')remainingQuery=remainingQuery.like('nome','%@g.us');
    const current=await q(remainingQuery.limit(mode==='grupos_sem_nome'?2500:150));
    const remaining=current.filter(groupNameMissing).length;
    const remainingMetadata=current.filter(needsMetadata).length;
    const next=mode==='grupos_sem_nome'
      ?groups.length>page.length&&page.length?'g:'+encodeURIComponent(String(page[page.length-1].externo_id)):null
      :start+page.length<groups.length?'g:'+(start+page.length):null;
    if(!chatRows.length&&!groupRows.length&&!groups.length)
      warnings.push('Nenhuma conversa/grupo disponível; verifique a conexão Evolution.');
    return {
      total:byJid.size,cursor:next,grupos_no_banco:groups.length,
      nomes_atualizados:mode==='grupos_sem_nome'?named:Math.max(0,initialMissing-remaining),
      detalhes_confirmados:details,fotos_salvas:photos,
      grupos_sem_nome:remaining,grupos_sem_metadados:remainingMetadata,
      grupos_consultados:subset.length,grupos_consultados_sem_nome:subset.length,
      avisos:[...new Set(warnings)].slice(0,4)
    };
  }
  const params=new URLSearchParams({accountId:ch.externo_id,platform:ch.canal,limit:'50'});
  if(cursor)params.set('cursor',cursor);
  const response=await zernio(zp(),'/inbox/conversations?'+params);
  for(const item of response.data||[])
    await q(db.rpc('atd_receber',{p_canal:ch.id,p_conversa:{
      id:item.id,nome:item.participantName||item.participantUsername,
      endereco:item.participantId,grupo:false}}));
  return {total:(response.data||[]).length,cursor:response.pagination?.nextCursor||null};
}
function evolutionFailure(error:unknown):string{
  if(error instanceof ProviderError)return 'HTTP '+error.status;
  const name=String((error as any)?.name||'');
  if(name==='TimeoutError'||name==='AbortError')return 'tempo esgotado na consulta';
  if(error instanceof TypeError)return 'falha de conexão com a Evolution';
  return 'falha ao consultar a Evolution';
}

async function processarGruposPeriodicos(req:Request){
  const config=await q(db.from('sistema_config').select('valor').eq('chave','atd_agenda_token').maybeSingle());
  const expected=String(config?.valor||'');
  if(!expected||!await segredoIgual(req.headers.get('x-atd-agenda-token')||'',expected))
    return json({erro:'Agendador não autorizado.'},401);
  const cutoff=new Date(Date.now()-6*60*60*1000).toISOString();
  const channels=await q(db.from('atd_canais').select('id,workspace_id,provedor,canal,nome,externo_id,status,ativo,grupos_sincronizados_em')
    .eq('provedor','evolution').eq('canal','whatsapp').eq('ativo',true).eq('status','conectado')
    .or('grupos_sincronizados_em.is.null,grupos_sincronizados_em.lte.'+cutoff)
    .order('grupos_sincronizados_em',{ascending:true,nullsFirst:true}).limit(1));
  if(!channels.length)return json({ok:true,verificados:0,aguardando_intervalo:true});
  const ch=channels[0];
  try{return json({ok:true,...await syncConversations(ch,undefined,'grupos_novos')});}
  catch(e){
    await q(db.from('atd_canais').update({grupos_sincronizados_em:new Date().toISOString()})
      .eq('id',ch.id).eq('workspace_id',ch.workspace_id));
    console.warn('atendimento evolução: rotina periódica de grupos falhou',{canal:ch.id,causa:evolutionFailure(e)});
    return json({ok:false,canal_id:ch.id,erro:evolutionFailure(e)},502);
  }
}

async function backfill(ch: any,cv: any,cursor?: string) {
  if (ch.provedor === 'evolution') {
    const r = await evolution(await secret(ch.workspace_id),'/chat/findMessages/'+encodeURIComponent(ch.externo_id),'POST',{where:{key:{remoteJid:cv.externo_id}},page:Number(cursor || 1),offset:50});
    const rows = r.messages?.records || r.records || [];
    for(const d of rows) await receive(ch,evolutionMensagem(d),true);
    return {total:rows.length,cursor:rows.length===50?String(Number(cursor || 1)+1):null};
  }
  const params = new URLSearchParams({accountId:ch.externo_id,limit:'50',sortOrder:'desc'}); if(cursor) params.set('cursor',cursor);
  const r = await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(cv.externo_id)+'/messages?'+params);
  const rows = r.messages || r.data || [];
  for(const m of rows) await receive(ch,zernioMensagem({event:m.direction==='outgoing'?'message.sent':'message.received',conversation:{id:cv.externo_id,participantName:cv.nome,participantId:cv.endereco},message:{...m,text:m.message || m.text},timestamp:m.createdAt || m.sentAt}),true);
  return {total:rows.length,cursor:r.pagination?.nextCursor || null};
}
Deno.serve(async req => {
  if(req.method==='OPTIONS') return new Response('ok',{headers:CORS});
  if(req.method!=='POST') return json({erro:'Use POST.'},405);
  try {
    if(Number(req.headers.get('content-length')) > 12*1024*1024) return json({erro:'Requisição muito grande.'},413);
    const raw = await req.text(); if(raw.length > 12*1024*1024) return json({erro:'Requisição muito grande.'},413);
    const url = new URL(req.url);
    if(url.searchParams.has('provider'))return await webhook(req,url,raw);
    const b=JSON.parse(raw);
    if(b.action==='qr-share-view')return await qrSharePublico(b);
    if(b.action==='grupo-campanha-convite')return await conviteGrupoPublico(b);
    if(b.action==='processar-grupos-periodico')return await processarGruposPeriodicos(req);
    if(b.action==='processar-agendamentos')return await processarAgendamentos(req);
    if(b.action==='processar-grupos-disparo')return await processarDisparosGruposAgendados(req);
    if(b.action==='processar-emails')return await processarEmails(req);
    return await handle(req,b);
  } catch(e) {
    // Sem logs de payload, URL com token ou chaves. Mensagens conhecidas são seguras.
    return json({erro:e instanceof ProviderError ? e.message : (e as Error).message?.slice(0,220) || 'Não foi possível concluir.'},400);
  }
});
