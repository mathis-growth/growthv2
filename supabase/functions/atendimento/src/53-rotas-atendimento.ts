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
