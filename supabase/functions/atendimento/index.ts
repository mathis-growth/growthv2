import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
import { assinatura, evolutionMensagem, zernioMensagem, hmacValido, segredoIgual, urlPublica, statusMensagem, MAX_MEDIA } from './core.ts';
import { evolution, zernio, providers, ProviderError, publicHost } from './providers.ts';
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
  if (!normalized) return;
  normalized.mensagem.historica = historical;
  const cv = await q(db.rpc('atd_receber', { p_canal: ch.id, p_conversa: normalized.conversa, p_mensagem: normalized.mensagem }));
  if (normalized.media) {
    const msg = await q(db.from('atd_mensagens').select('id,anexos').eq('conversa_id', cv).eq('externo_id', normalized.mensagem.id).single());
    if (msg.anexos.some((a: any) => a.pendente)) {
      await q(db.rpc('atd_midia_pendente', { p_mensagem: msg.id, p_origem: {...normalized.media,conversa_id:normalized.conversa.id,externo_id:normalized.mensagem.id} }));
      EdgeRuntime.waitUntil(saveMedia(ch, msg).catch(() => {})); // pendência permanece recuperável
    }
  }
}
async function mediaBytes(url: string) {
  const u = new URL(url); urlPublica(u.origin);
  await publicHost(u.hostname);
  const r = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(15000) });
  if (!r.ok || Number(r.headers.get('content-length')) > MAX_MEDIA) throw new Error('Mídia indisponível ou acima de 8 MB.');
  const reader = r.body!.getReader(); const chunks: Uint8Array[] = []; let size = 0;
  while (true) { const v = await reader.read(); if (v.done) break; size += v.value.length; if (size > MAX_MEDIA) { await reader.cancel(); throw new Error('Mídia acima de 8 MB.'); } chunks.push(v.value); }
  const bytes = new Uint8Array(size); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}
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
    if (event === 'MESSAGES_UPSERT') for (const d of Array.isArray(p.data) ? p.data : [p.data]) await receive(ch, evolutionMensagem(d));
    if (event === 'MESSAGES_UPDATE') for (const d of Array.isArray(p.data) ? p.data : [p.data]) {
      const st: Record<string,string> = { DELIVERY_ACK: 'entregue', READ: 'lida', PLAYED: 'lida', SERVER_ACK: 'enviada', '2':'enviada','3':'entregue','4':'lida','5':'lida' };
      const s = st[d.status || d.update?.status]; if (s) await updateDelivery(ch, d.keyId || d.key?.id, s, d.remoteJid || d.key?.remoteJid);
    }
  } else if (url.searchParams.get('provider') === 'zernio') {
    if (!await hmacValido(raw, req.headers.get('x-zernio-signature') || '', Deno.env.get('ZERNIO_ATENDIMENTO_WEBHOOK_SECRET') || '')) return json({ ok: false }, 401);
    if (p.event === 'webhook.test') return json({ ok: true });
    const ch = await q(db.from('atd_canais').select('*').eq('provedor','zernio').eq('externo_id',p.account?.id || p.account?.accountId || '').maybeSingle());
    if (ch?.ativo) {
      await receive(ch, zernioMensagem(p));
      const st: Record<string,string> = { 'message.delivered':'entregue','message.read':'lida','message.failed':'falhou' };
      if (st[p.event]) await updateDelivery(ch, p.message?.platformMessageId || p.message?.id, st[p.event], p.conversation?.id);
    }
  } else return json({ ok: false }, 400);
  return json({ ok: true });
}
async function zernioCandidates(ws: string) {
  const linked = await q(db.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)').eq('workspace_id',ws).eq('conexoes.plataforma','zernio'));
  const accounts = (await zernio(zp(), '/accounts')).accounts || [];
  const ids = new Set(linked.map((a: any) => a.id_externo));
  // Não herdar todas as contas do mesmo perfil: cada cliente escolhe suas contas explicitamente.
  return accounts.filter((a: any) => ['instagram','whatsapp'].includes(a.platform) && ids.has(a._id))
    .map((a: any) => ({ id: a._id, canal: a.platform, nome: a.displayName || a.username || a._id }));
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
async function processarAgendamentos(req:Request) {
  const expected=Deno.env.get('ATD_AGENDADOR_TOKEN')||'';
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
  return json({ok:true,reservados:jobs.length,enviados,erros,incertos});
}
async function handle(req: Request, b: any) {
  const userDb = createClient(URL_SB, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('authorization') || '' } }, auth: { persistSession:false } });
  const { data: { user }, error } = await userDb.auth.getUser();
  if (error || !user) return json({ erro: 'Faça login novamente.' },401);
  const ctx = await q(userDb.rpc('atd_contexto', { p_ws:b.workspace_id }));
  const read = ['contexto','config','status','mensagens','anexo','zernio-contas','identidades','avatar','avatars','templates-list','rapidas-list','agendamentos-list'];
  if (!read.includes(b.action) && !ctx.editar) return json({ erro:'Sem permissão para editar Atendimento.' },403);
  const admins = ['config','salvar-config','criar-instancia','conectar','status','zernio-contas','zernio-vincular','zernio-disponiveis','zernio-conectar','webhook','desativar','excluir-instancia','exibir-arquivados','templates-create','templates-update','templates-delete'];
  if (admins.includes(b.action) && !ctx.admin) return json({ erro:'Somente administradores gerenciam conexões.' },403);
  const ws = b.workspace_id;
  if (['zernio-disponiveis','zernio-conectar'].includes(b.action)) {
    const interna = await q(userDb.rpc('sou_equipe_interna'));
    if (!interna) return json({ erro:'Somente a equipe interna pode vincular contas da Zernio.' },403);
  }
  if (b.action === 'contexto') return json(ctx);
  if(b.action==='agendamentos-list'){
    const cv=await q(db.from('atd_conversas').select('id').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    return json({agendamentos:await q(db.from('atd_agendamentos').select('id,texto,enviar_em,fuso,status,erro,criado_em')
      .eq('workspace_id',ws).eq('conversa_id',cv.id).order('criado_em',{ascending:false}).limit(50))});
  }
  if(b.action==='agendar'){
    const cv=await q(db.from('atd_conversas').select('id,canal_id').eq('id',b.conversa_id).eq('workspace_id',ws).single());
    const ch=await channel(cv.canal_id,ws);
    if(!ch.ativo||ch.status!=='conectado')throw Error('Conecte o canal antes de agendar.');
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
      return json({templates:result.templates||result.data?.templates||[]});
    }
    if(b.action==='templates-create'||b.action==='templates-update') {
      const nome=String(b.nome||'').trim(),language=String(b.idioma||'pt_BR').trim(),category=String(b.categoria||'');
      const body=String(b.texto||'').trim(),examples=Array.isArray(b.exemplos)?b.exemplos.map((v:unknown)=>String(v||'').trim()):[];
      if(!/^[a-z][a-z0-9_]{0,511}$/.test(nome)||!/^([a-z]{2})(_[A-Z]{2})?$/.test(language)
        ||!['UTILITY','MARKETING'].includes(category)||!body||body.length>1024)
        throw Error('Nome, categoria, idioma ou mensagem inválidos.');
      const matches=[...body.matchAll(/\{\{(\d+)\}\}/g)].map(x=>Number(x[1]));
      const count=Math.max(0,...matches);
      if(count>10||matches.some(n=>n<1)||new Set(matches).size!==count||examples.length!==count||examples.some((x:string)=>!x||x.length>200))
        throw Error('Preencha um exemplo para cada variável sequencial {{1}}, {{2}} etc.');
      const components:any[]=[{type:'body',text:body}];
      if(count)components[0].example={body_text:[examples]};
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
      return json({ok:true});
    }
  }
  if (b.action === 'config') { const cfg = await secret(ws); return json({ url: cfg?.evolution_url || '', configurada: !!cfg, versao:'2.3.7' }); }
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
  if (b.action === 'zernio-vincular') {
    const a = (await zernioCandidates(ws)).find((a: any) => a.id === b.account_id);
    if (!a) throw new Error('Conta não vinculada ao perfil Zernio deste workspace.');
    const existing = await q(db.from('atd_canais').select('workspace_id').eq('provedor','zernio').eq('externo_id',a.id).maybeSingle());
    if(existing && existing.workspace_id!==ws) throw new Error('Esta conta já pertence a outro workspace.');
    const row = await q(db.from('atd_canais').upsert({workspace_id:ws,provedor:'zernio',canal:a.canal,nome:a.nome,externo_id:a.id,status:'conectado'}, {onConflict:'provedor,externo_id',ignoreDuplicates:true}).select());
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
  if (b.action === 'desativar') { await q(db.from('atd_canais').update({ativo:false,status:'desativado'}).eq('id',ch.id)); return json({ok:true}); }
  if (b.action === 'webhook') { await setupWebhook(ch, ch.provedor === 'evolution' ? await secret(ws) : null); return json({ok:true}); }
  if (b.action === 'sincronizar') return json(await syncConversations(ch,b.cursor));
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
    await evolution(cfg,'/webhook/set/'+encodeURIComponent(ch.externo_id),'POST',{webhook:{enabled:true,url:root+'&channel='+ch.id,headers:{'x-atd-secret':cfg.webhook_secret},byEvents:false,base64:false,events:['MESSAGES_UPSERT','MESSAGES_UPDATE','CONNECTION_UPDATE']}});
  } else {
    const s = Deno.env.get('ZERNIO_ATENDIMENTO_WEBHOOK_SECRET'); if (!s) throw new Error('Configure ZERNIO_ATENDIMENTO_WEBHOOK_SECRET no servidor.');
    const current = await zernio(zp(),'/webhooks/settings');
    const rows = current.webhooks || current.data || [];
    if (Array.isArray(rows) && rows.some((w: any) => w.url === root && w.isActive)) return;
    await zernio(zp(),'/webhooks/settings','POST',{name:'Growths Atendimento',url:root,secret:s,events:['message.received','message.sent','message.delivered','message.read','message.failed']});
  }
}
// Metadados de grupo e foto: sempre por instância autenticada do workspace.
// Evita misturar fotos/nomes de clientes, sem expor URLs remotas no frontend.
// Metadados Evolution v2.3.x: GET /group/findGroupInfos/{instance}?groupJid=...
// Todas as buscas usam a credencial do workspace e nunca expõem URLs externas.
const isJid=(jid:string)=>/^[0-9]{5,22}@(g\.us|s\.whatsapp\.net|lid)$/.test(jid);
const groupName=(g:any):string=>{
  const value=String(g?.subject||g?.groupMetadata?.subject||g?.name||g?.title||g?.groupName||'').trim().slice(0,180);
  return value.endsWith('@g.us')?'':value;
};
const groupPicture=(g:any):string=>String(g?.pictureUrl||g?.profilePictureUrl||g?.groupMetadata?.pictureUrl||'');
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
async function enrichGroup(ch:any,cv:any,original:any,cfg:any):
  Promise<{named:boolean,photo:boolean,detailsOk:boolean}>{
  const jid=String(cv.externo_id||'');
  if(!isJid(jid)||!jid.endsWith('@g.us'))return {named:false,photo:false,detailsOk:false};
  let meta=original||{},name=groupName(meta),detailsOk=Boolean(name);
  if(!name){
    try{
      // Corrigido v0.190: a rota é GET e groupJid pertence à query, não ao corpo POST.
      const response=await evolution(cfg,'/group/findGroupInfos/'+encodeURIComponent(ch.externo_id)
        +'?groupJid='+encodeURIComponent(jid)+'&getParticipants=false');
      meta=response?.data?.subject?response.data:response;
      name=groupName(meta);
      detailsOk=Boolean(name);
    }catch{/* Algumas versões da Evolution retornam 404 para grupos antigos. */}
  }
  let named=false;
  if(name&&name!==jid&&name!==cv.nome){
    await q(db.from('atd_conversas').update({nome:name})
      .eq('id',cv.id).eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id));
    named=true;
  }
  const photo=await refreshAvatar(ch,cv,cfg,groupPicture(meta)||groupPicture(original));
  return {named,photo,detailsOk};
}
async function syncConversations(ch:any,cursor?:string){
  if(ch.provedor==='evolution'){
    const cfg=await secret(ch.workspace_id),inst=encodeURIComponent(ch.externo_id);
    if(!cfg)throw Error('A Evolution não está configurada para este cliente.');
    const warnings:string[]=[];
    const shape=(raw:any):any[]=>Array.isArray(raw)?raw:
      Array.isArray(raw?.groups)?raw.groups:
      Array.isArray(raw?.chats)?raw.chats:
      Array.isArray(raw?.data)?raw.data:
      Array.isArray(raw?.data?.groups)?raw.data.groups:
      Array.isArray(raw?.data?.chats)?raw.data.chats:[];
    let chatRows:any[]=[],groupRows:any[]=[];
    try{
      chatRows=shape(await evolution(cfg,'/chat/findChats/'+inst));
    }catch(e){warnings.push('Conversas: '+(e instanceof ProviderError?'HTTP '+e.status:'consulta indisponível'));}
    try{
      groupRows=shape(await evolution(cfg,'/group/fetchAllGroups/'+inst+'?getParticipants=false'));
    }catch(e){warnings.push('Grupos: '+(e instanceof ProviderError?'HTTP '+e.status:'consulta indisponível'));}
    const byJid=new Map<string,any>();
    for(const item of [...chatRows,...groupRows]){
      const id=String(item?.remoteJid||item?.id||item?.jid||item?.groupJid||'');
      if(!isJid(id))continue;
      const previous=byJid.get(id);
      if(!previous||(id.endsWith('@g.us')&&groupName(item)&&!groupName(previous)))byJid.set(id,item);
    }
    for(const [id,item] of byJid){
      const group=id.endsWith('@g.us');
      const name=group?groupName(item):
        String(item.pushName||item.name||item.contact?.pushName||'').trim().slice(0,180);
      await q(db.rpc('atd_receber',{p_canal:ch.id,
        p_conversa:{id,nome:name&&name!==id?name:undefined,endereco:id,grupo:group}}));
    }
    // A recuperação deve funcionar mesmo que fetchAllGroups falhe: usar grupos
    // do banco, sem depender de um novo evento do WhatsApp.
    const groups=await q(db.from('atd_conversas')
      .select('id,externo_id,nome,avatar_path,avatar_atualizado_em')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',true)
      .order('ultima_em',{ascending:false,nullsFirst:false}).limit(150));
    const initialMissing=groups.filter((g:any)=>g.nome===g.externo_id).length;
    const offset=/^g:(\d+)$/.test(String(cursor||''))?Number(String(cursor).split(':')[1]):0;
    const start=Math.min(Number.isFinite(offset)?offset:0,Math.max(0,groups.length-1));
    const subset=groups.slice(start,start+8);
    let named=0,photos=0,details=0;
    for(let i=0;i<subset.length;i+=4){
      const results=await Promise.allSettled(subset.slice(i,i+4).map((g:any)=>
        enrichGroup(ch,g,byJid.get(g.externo_id)||{},cfg)));
      for(const result of results){
        if(result.status!=='fulfilled'){warnings.push('Detalhes do grupo: falha de consulta');continue;}
        if(result.value.named)named++;
        if(result.value.photo)photos++;
        if(result.value.detailsOk)details++;
      }
    }
    // Buscar fotos também dos contatos recentes, independentemente dos grupos.
    const contacts=await q(db.from('atd_conversas')
      .select('id,externo_id,avatar_atualizado_em')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',false)
      .order('ultima_em',{ascending:false,nullsFirst:false}).limit(4));
    const cp=await Promise.allSettled(contacts.filter((cv:any)=>isJid(cv.externo_id))
      .map((cv:any)=>refreshAvatar(ch,cv,cfg)));
    photos+=cp.filter(x=>x.status==='fulfilled'&&x.value===true).length;
    const current=await q(db.from('atd_conversas').select('id,externo_id,nome,avatar_path')
      .eq('workspace_id',ch.workspace_id).eq('canal_id',ch.id).eq('grupo',true).limit(150));
    const remaining=current.filter((g:any)=>g.nome===g.externo_id).length;
    const next=start+8<groups.length?'g:'+(start+8):null;
    if(!chatRows.length&&!groupRows.length&&!groups.length)
      warnings.push('Nenhuma conversa/grupo disponível; verifique a conexão Evolution.');
    return {
      total:byJid.size,cursor:next,grupos_no_banco:groups.length,
      nomes_atualizados:Math.max(0,initialMissing-remaining),
      detalhes_confirmados:details,fotos_salvas:photos,
      grupos_sem_nome:remaining,grupos_consultados:subset.length,
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
    if(b.action==='processar-agendamentos')return await processarAgendamentos(req);
    return await handle(req,b);
  } catch(e) {
    // Sem logs de payload, URL com token ou chaves. Mensagens conhecidas são seguras.
    return json({erro:e instanceof ProviderError ? e.message : (e as Error).message?.slice(0,220) || 'Não foi possível concluir.'},400);
  }
});
