function emailFiltroAplica(p:any,f:any){if(f?.tipo&&p.status_funil!==f.tipo)return false;if(f?.qualificacao&&p.qualificacao!==f.qualificacao)return false;if(f?.campanha_id&&p.campanha_id!==f.campanha_id)return false;if(f?.tag&&!(Array.isArray(p.tags)?p.tags:[]).includes(f.tag))return false;return true;}
function htmlSeguro(v:string){return v.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]||c));}
function emailPersonalizar(s:string,p:any){const n=String(p.nome||'').trim(),map:Record<string,string>={nome:n,primeiro_nome:n.split(/\s+/)[0]||'',email:String(p.email||'')};return s.replace(/\{\{\s*(nome|primeiro_nome|email)\s*\}\}/gi,(_m,k)=>htmlSeguro(map[String(k).toLowerCase()]||''));}
function emailSanitizar(html:string){return html.replace(/<\s*(script|iframe|object|embed|form)\b[^>]*>[\s\S]*?<\s*\/\s*\1\s*>/gi,'').replace(/\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi,'').replace(/(href|src)\s*=\s*(["'])\s*javascript:[\s\S]*?\2/gi,'$1="#"');}
async function resendDomains(path:string,method='GET',body?:any){const key=Deno.env.get('RESEND_API_KEY')||'';if(!key)throw new Error('Configure RESEND_API_KEY nas secrets da Edge.');const r=await fetch('https://api.resend.com/domains'+path,{method,headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json().catch(()=>({}));if(!r.ok)throw new Error(String(data.message||data.name||'Não foi possível consultar o Resend.').slice(0,220));return data;}
async function processarEmails(req:Request){
  const cfg=await q(db.from('sistema_config').select('valor').eq('chave','atd_agenda_token').maybeSingle()),expected=String(cfg?.valor||'');
  if(!expected||!await segredoIgual(req.headers.get('x-atd-agenda-token')||'',expected))return json({erro:'Agendador não autorizado.'},401);
  const key=Deno.env.get('RESEND_API_KEY')||'';if(!key)return json({erro:'Configure RESEND_API_KEY nas secrets da Edge.'},500);
  const due=await q(db.from('atd_email_envios').select('campanha_id').eq('status','pendente').lte('enviar_em',new Date().toISOString()).order('enviar_em').limit(1000)),ids=[...new Set(due.map((x:any)=>x.campanha_id))];let interval=10;
  if(ids.length){const configs=await q(db.from('atd_email_campanhas').select('intervalo_segundos').in('id',ids));if(configs.length)interval=Math.max(1,Math.min(...configs.map((c:any)=>Number(c.intervalo_segundos)||10)));}
  const jobs=await q(db.rpc('atd_email_reservar',{p_limite:Math.max(1,Math.min(20,Math.floor(25/interval)))}));let enviados=0,ignorados=0,erros=0,incertos=0;
  for(let i=0;i<jobs.length;i++){const job=jobs[i];let attempted=false,waitInterval=interval;try{
    const campaign=await q(db.from('atd_email_campanhas').select('status,intervalo_segundos').eq('id',job.campanha_id).eq('workspace_id',job.workspace_id).single());
    waitInterval=Math.max(1,Math.min(30,Number(campaign.intervalo_segundos)||interval));
    if(campaign.status==='cancelada'){await q(db.from('atd_email_envios').update({status:'cancelado',atualizado_em:new Date().toISOString()}).eq('id',job.id).eq('status','processando'));continue;}
    const sender=await q(db.from('atd_email_config').select('dominio,resend_domain_id,email_remetente,status_dominio').eq('workspace_id',job.workspace_id).single());if(sender.status_dominio!=='verified')throw new Error('O domínio de envio deste workspace ainda não foi verificado no Resend.');
    const p=await q(db.from('pessoas').select('id,nome,email,status_funil,qualificacao,campanha_id,tags').eq('id',job.pessoa_id).eq('workspace_id',job.workspace_id).single());
    if(!emailFiltroAplica(p,job.condicao)){await q(db.from('atd_email_envios').update({status:'ignorado',atualizado_em:new Date().toISOString(),erro:'Contato deixou de atender aos filtros da transmissão.'}).eq('id',job.id).eq('status','processando'));ignorados++;continue;}
    const to=String(p.email||'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to))throw new Error('O contato está sem um e-mail válido.');
    attempted=true;const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({from:sender.email_remetente,to,subject:emailPersonalizar(job.assunto,p),html:emailPersonalizar(job.corpo_html,p),tags:[{name:'growth_workspace',value:String(job.workspace_id).slice(0,50)},{name:'growth_campaign',value:String(job.campanha_id).slice(0,50)}]})});
    const payload=await response.json().catch(()=>({}));if(!response.ok)throw Object.assign(new Error(String(payload.message||payload.error||'O Resend recusou o envio.').slice(0,220)),{status:response.status});const external=String(payload.id||'');if(!external)throw new Error('O Resend não confirmou o identificador do e-mail.');
    await q(db.from('atd_email_envios').update({status:'enviado',email:to,externo_id:external,enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',job.id).eq('status','processando'));enviados++;
  }catch(e){const status=Number((e as any).status||0),known=!attempted||(status>0&&status<500&&status!==408),state=known?'erro':'incerto';await q(db.from('atd_email_envios').update({status:state,atualizado_em:new Date().toISOString(),erro:known?String((e as Error).message||'Falha no envio.').slice(0,220):'Envio sem confirmação. Confira o Resend antes de reenviar.'}).eq('id',job.id).eq('status','processando'));if(known)erros++;else incertos++;}
    if(i<jobs.length-1)await new Promise(resolve=>setTimeout(resolve,waitInterval*1000));
  }
  const campaigns=await q(db.from('atd_email_campanhas').select('id,status').in('status',['agendada','em_execucao']).limit(100));for(const c of campaigns){const left=await q(db.from('atd_email_envios').select('id',{count:'exact',head:true}).eq('campanha_id',c.id).in('status',['pendente','processando']));if((left.count||0)===0)await q(db.from('atd_email_campanhas').update({status:'concluida',atualizado_em:new Date().toISOString()}).eq('id',c.id).in('status',['agendada','em_execucao']));else if(enviados)await q(db.from('atd_email_campanhas').update({status:'em_execucao',atualizado_em:new Date().toISOString()}).eq('id',c.id).eq('status','agendada'));}
  return json({reservados:jobs.length,enviados,ignorados,erros,incertos});
}
function emailAutomacaoValor(p:any,evento:any,campo:string){
  if(campo==='tipo')return p.status_funil==='cliente'?'cliente':'lead';
  if(campo==='qualificacao')return String(p.qualificacao||'');
  if(campo==='campanha')return String(evento.campanha||p.utm_campaign||'');
  if(campo==='produto')return String(evento.produto||'');
  if(campo==='pesquisa')return String(evento.pesquisa||'');
  return '';
}
function emailAutomacaoPersonalizar(value:string,p:any,evento:any){
  const nome=String(p.nome||'').trim(),map:Record<string,string>={nome,primeiro_nome:nome.split(/\s+/)[0]||'',email:String(p.email||''),telefone:String(p.telefone||''),produto:String(evento.produto||''),campanha:String(evento.campanha||''),pesquisa:String(evento.pesquisa||''),data_venda:String(evento.data_venda||''),valor_venda:String(evento.valor_venda||''),capturado_em:String(evento.capturado_em||'')};
  return String(value||'').replace(/\{\{\s*(nome|primeiro_nome|email|telefone|produto|campanha|pesquisa|data_venda|valor_venda|capturado_em)\s*\}\}/gi,(_m,k)=>htmlSeguro(map[String(k).toLowerCase()]||''));
}
function emailAutomacaoDestino(flow:any,id:string,saida='seguir'){return flow.edges?.find((e:any)=>e.origem===id&&e.saida===saida)?.destino||null;}
async function executarEmailAutomacao(row:any){
  const state={...(row.estado||{})},flow=state.fluxo||{},nodes=flow.nodes||[],p=await q(db.from('pessoas').select('id,nome,email,telefone,status_funil,qualificacao,campanha_id,tags,extras').eq('id',row.pessoa_id).eq('workspace_id',row.workspace_id).single()),evento=state.evento||{};
  let current=state.no_id||nodes.find((n:any)=>n.tipo==='gatilho')?.id||null,steps=0,activeLog:string|null=null,attempted=false;
  try{
    while(current&&steps++<50){
      const node=nodes.find((n:any)=>n.id===current);if(!node)break;
      if(Array.isArray(state.visitados)&&state.visitados.includes(node.id))throw new Error('O fluxo contém um ciclo entre blocos. Revise as ligações no canvas.');
      state.visitados=Array.isArray(state.visitados)?state.visitados:[];state.visitados.push(node.id);
      if(node.tipo==='gatilho'){current=emailAutomacaoDestino(flow,node.id)||nodes.find((n:any)=>n.tipo!=='gatilho')?.id||null;continue;}
      if(node.tipo==='fim')break;
      const next=emailAutomacaoDestino(flow,node.id);
      if(node.tipo==='espera'){
        if(!next)break;const minutos=Math.min(525600,Math.max(1,Number(node.data?.minutos)||1));state.no_id=next;
        await q(db.from('atd_email_automacao_execucoes').update({status:'aguardando',retomar_em:new Date(Date.now()+minutos*60000).toISOString(),estado:state,erro:null,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));return 'aguardando';
      }
      if(node.tipo==='condicao'){
        const value=emailAutomacaoValor(p,evento,String(node.data?.campo||'' )).toLocaleLowerCase(),needle=String(node.data?.valor||'').trim().toLocaleLowerCase(),matched=(node.data?.operador==='igual'?value===needle:value.includes(needle));
        current=emailAutomacaoDestino(flow,node.id,matched?'sim':'nao');continue;
      }
      if(node.tipo==='email'){
        const to=String(p.email||'').trim().toLowerCase(),subject=emailAutomacaoPersonalizar(node.data?.assunto,p,evento),body=emailSanitizar(emailAutomacaoPersonalizar(node.data?.html,p,evento));
        if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to))throw new Error('O contato não tem um e-mail válido.');
        const [sender,key]=await Promise.all([q(db.from('atd_email_config').select('dominio,email_remetente,status_dominio').eq('workspace_id',row.workspace_id).single()),Promise.resolve(Deno.env.get('RESEND_API_KEY')||'')]);
        if(sender.status_dominio!=='verified')throw new Error('O domínio de e-mail deste workspace ainda não foi verificado no Resend.');if(!key)throw new Error('Configure RESEND_API_KEY nas secrets da Edge.');
        const old=await q(db.from('atd_email_automacao_envios').select('id,status').eq('execucao_id',row.id).eq('node_id',String(node.id)).maybeSingle());
        if(old){if(old.status==='enviado'){current=next;continue;}throw Object.assign(new Error('Envio anterior deste bloco sem confirmação. Confira o histórico antes de repetir.'),{fluxoIncerto:true});}
        const log=await q(db.from('atd_email_automacao_envios').insert({workspace_id:row.workspace_id,execucao_id:row.id,pessoa_id:p.id,node_id:String(node.id),email:to,assunto:subject,status:'processando'}).select('id').single());activeLog=log.id;
        attempted=true;
        const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify({from:sender.email_remetente,to,subject,html:body,tags:[{name:'growth_workspace',value:String(row.workspace_id).slice(0,50)},{name:'growth_automation',value:String(row.automacao_id).slice(0,50)}]})});
        const result=await response.json().catch(()=>({}));if(!response.ok)throw Object.assign(new Error(String(result.message||result.error||'O Resend recusou o envio.').slice(0,220)),{status:response.status});
        if(!result.id)throw new Error('O Resend não confirmou o identificador do e-mail.');
        await q(db.from('atd_email_automacao_envios').update({status:'enviado',externo_id:String(result.id),enviado_em:new Date().toISOString(),atualizado_em:new Date().toISOString(),erro:null}).eq('id',activeLog));activeLog=null;
      }
      current=next;state.no_id=current;
      await q(db.from('atd_email_automacao_execucoes').update({estado:state,retomar_em:new Date(Date.now()+10*60000).toISOString(),atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));
    }
    if(steps>=50)throw new Error('O fluxo ultrapassou o limite de 50 blocos por execução.');
    await q(db.from('atd_email_automacao_execucoes').update({status:'enviado',retomar_em:new Date().toISOString(),estado:{...state,no_id:null},erro:null,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));return 'enviado';
  }catch(e){
    const uncertain=(e as any).fluxoIncerto===true||(attempted&&(!Number((e as any).status)||Number((e as any).status)>=500||Number((e as any).status)===408)),status=uncertain?'incerto':'erro',detail=uncertain?'Envio sem confirmação. Confira o Resend antes de reenviar.':String((e as Error).message||'Falha no fluxo de e-mail.').slice(0,220);
    if(activeLog)await q(db.from('atd_email_automacao_envios').update({status:uncertain?'incerto':'erro',erro:detail,atualizado_em:new Date().toISOString()}).eq('id',activeLog));
    await q(db.from('atd_email_automacao_execucoes').update({status,retomar_em:new Date().toISOString(),erro:detail,atualizado_em:new Date().toISOString()}).eq('id',row.id).eq('status','processando'));throw e;
  }
}
async function processarEmailAutomacoes(){
  const rows=await q(db.rpc('atd_email_automacao_reservar',{p_limite:10}));let enviados=0,aguardando=0,erros=0,incertos=0;
  for(const row of rows){try{const status=await executarEmailAutomacao(row);if(status==='aguardando')aguardando++;else enviados++;}catch(e){if((e as any).fluxoIncerto)incertos++;else erros++;console.error('atd email automacao falhou',row.automacao_id,String((e as Error).message||'').slice(0,160));}}
  return {reservados:rows.length,enviados,aguardando,erros,incertos};
}
