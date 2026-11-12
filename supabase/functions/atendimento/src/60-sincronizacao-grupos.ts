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
