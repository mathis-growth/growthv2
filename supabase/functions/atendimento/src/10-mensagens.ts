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
