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
      try { bytes = await mediaBytes(orig.attachments[i].url); }
      catch {
        const r = await zernio(zp(),'/inbox/conversations/'+encodeURIComponent(orig.conversa_id)+'/messages/'+encodeURIComponent(orig.externo_id)+'/attachments/'+i+'?accountId='+encodeURIComponent(ch.externo_id)+'&format=json');
        bytes = await mediaBytes(r.url);
      }
    }
    if (!bytes.length) throw new Error('Mídia vazia.');
    const path = `${ch.workspace_id}/${msg.id}/${i}`;
    await q(db.storage.from('atendimento').upload(path, bytes, { contentType: attachments[i].mime, upsert: true }));
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
async function handle(req: Request, b: any) {
  const userDb = createClient(URL_SB, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('authorization') || '' } }, auth: { persistSession:false } });
  const { data: { user }, error } = await userDb.auth.getUser();
  if (error || !user) return json({ erro: 'Faça login novamente.' },401);
  const ctx = await q(userDb.rpc('atd_contexto', { p_ws:b.workspace_id }));
  const read = ['contexto','config','status','mensagens','anexo','zernio-contas','identidades'];
  if (!read.includes(b.action) && !ctx.editar) return json({ erro:'Sem permissão para editar Atendimento.' },403);
  const admins = ['config','salvar-config','criar-instancia','conectar','status','zernio-contas','zernio-vincular','zernio-disponiveis','zernio-conectar','webhook','desativar','excluir-instancia'];
  if (admins.includes(b.action) && !ctx.admin) return json({ erro:'Somente administradores gerenciam conexões.' },403);
  const ws = b.workspace_id;
  if (['zernio-disponiveis','zernio-conectar'].includes(b.action)) {
    const interna = await q(userDb.rpc('sou_equipe_interna'));
    if (!interna) return json({ erro:'Somente a equipe interna pode vincular contas da Zernio.' },403);
  }
  if (b.action === 'contexto') return json(ctx);
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
    const text = String(b.texto || '').trim(); if (!text || text.length > 4000) throw new Error('Escreva uma mensagem de até 4.000 caracteres.');
    if (!/^[0-9a-f-]{36}$/i.test(b.requisicao_id || '')) throw new Error('Identificador de envio inválido.');
    if (!ctx.nome) throw new Error('Não encontrei seu nome. Atualize o nome do perfil da sua conta e entre novamente.');
    const note = b.action === 'nota';
    if (!note && (!ch.ativo || ch.status !== 'conectado')) throw new Error('Conecte este canal antes de enviar.');
    const signed = note ? text : assinatura(ctx.nome,text,ch.canal);
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
        const mime = String(b.arquivo.mime || 'application/octet-stream');
        if (!/^(image\/(jpeg|png|webp)|video\/mp4|audio\/(ogg|mpeg|mp4|webm)|application\/pdf)$/.test(mime)) throw new ProviderError(400,'TIPO_ARQUIVO_INVALIDO');
        const path = `${ws}/${pending.id}/0`, nome = String(b.arquivo.nome || 'Arquivo').slice(0,150);
        await q(db.storage.from('atendimento').upload(path,bytes,{contentType:mime}));
        await q(db.from('atd_mensagens').update({anexos:[{path,nome,mime,tamanho:bytes.length}]}).eq('id',pending.id));
        const signedUrl = await q(db.storage.from('atendimento').createSignedUrl(path,300));
        media = {url:signedUrl.signedUrl,nome,mime};
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
    return json(await q(db.storage.from('atendimento').createSignedUrl(a.path,60,{download:a.nome})));
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
async function syncConversations(ch: any,cursor?: string) {
  if (ch.provedor === 'evolution') {
    const cfg = await secret(ch.workspace_id), inst = encodeURIComponent(ch.externo_id);
    const chats = await evolution(cfg,'/chat/findChats/'+inst,'POST',{});
    const groups = await evolution(cfg,'/group/fetchAllGroups/'+inst+'?getParticipants=false');
    const rows = [...(Array.isArray(chats)?chats:chats.chats || []),...(Array.isArray(groups)?groups:groups.groups || [])];
    let count = 0;
    for (const c of rows) {
      const id = c.remoteJid || c.id; if (!id || !/@(s.whatsapp.net|g.us|lid)$/.test(id)) continue;
      await q(db.rpc('atd_receber',{p_canal:ch.id,p_conversa:{id,nome:c.subject || c.name || c.pushName || id,endereco:id,grupo:id.endsWith('@g.us')}})); count++;
    }
    return {total:count,cursor:null};
  }
  const params = new URLSearchParams({accountId:ch.externo_id,platform:ch.canal,limit:'50'}); if(cursor) params.set('cursor',cursor);
  const r = await zernio(zp(),'/inbox/conversations?'+params);
  for (const c of r.data || []) await q(db.rpc('atd_receber',{p_canal:ch.id,p_conversa:{id:c.id,nome:c.participantName || c.participantUsername,endereco:c.participantId,grupo:false}}));
  return {total:(r.data || []).length,cursor:r.pagination?.nextCursor || null};
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
    return url.searchParams.has('provider') ? await webhook(req,url,raw) : await handle(req,JSON.parse(raw));
  } catch(e) {
    // Sem logs de payload, URL com token ou chaves. Mensagens conhecidas são seguras.
    return json({erro:e instanceof ProviderError ? e.message : (e as Error).message?.slice(0,220) || 'Não foi possível concluir.'},400);
  }
});
