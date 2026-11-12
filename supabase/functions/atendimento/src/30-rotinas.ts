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
