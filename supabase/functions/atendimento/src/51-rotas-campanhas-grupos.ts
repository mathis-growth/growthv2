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
