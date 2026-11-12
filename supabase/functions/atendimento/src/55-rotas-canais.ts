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
  if (b.action === 'desativar') { await q(db.from('atd_canais').update({ativo:false,status:'desativado'}).eq('id',ch.id)); return json({ok:true}); }
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
