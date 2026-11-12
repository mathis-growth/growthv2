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
