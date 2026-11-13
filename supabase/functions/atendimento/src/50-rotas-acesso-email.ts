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
