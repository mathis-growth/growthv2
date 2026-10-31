/* Central de Atendimento: módulo isolado para diminuir conflitos no index.html.
   Nunca guarda credenciais, mensagens ou anexos no localStorage. */
(() => {
  'use strict';
  const LABELS = {whatsapp:'WhatsApp',instagram:'Instagram',telegram:'Telegram',tiktok:'TikTok'};
  const A = {ws:null,sel:null,lista:[],canais:[],ctx:null,token:0,chatToken:0,drafts:new Map(),busca:'',canal:'',tipo:'',status:'',minhas:'',page:0,cursor:null,loaded:[],subscription:null,timer:null};
  const listOf = x => Array.isArray(x)?x:[];
  A.listSeq=0;
  const label = c => LABELS[c] || c;
  const state = {recebida:'Recebida',enviando:'Enviando…',enviada:'Enviada ✓',entregue:'Entregue ✓✓',lida:'Lida ✓✓',falhou:'Falhou',incerto:'Sem confirmação',nota:'Nota interna'};
  const fmt = t => t ? new Date(t).toLocaleString('pt-BR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}) : '';
  const textoMensagem = m => esc(m.texto).replace(/^\*([^*\n]{1,100}:)\* /,'<strong>$1</strong> ');
  async function api(action,body={},ws=A.ws || S.ws) {
    const {data,error} = await sb.functions.invoke('atendimento',{body:{action,workspace_id:ws,...body}});
    if(error) { let msg; try { msg=(await error.context.json()).erro; } catch {} throw new Error(msg || 'Atendimento indisponível. Confira a publicação da função e sua conexão.'); }
    if(data?.erro) throw new Error(data.erro); return data;
  }
  function stop() { clearInterval(A.timer); A.timer=null; if(A.subscription) { sb.removeChannel(A.subscription); A.subscription=null; } }
  const active = token => token===A.token && S.ws===A.ws && S.view==='atd-conversas';
  function draftKey(cv) { return A.ws+':'+cv; }
  async function vAtendimento(m) {
    stop(); const token=++A.token;
    if(A.ws!==S.ws) { A.sel=null; A.lista=[]; A.drafts.clear(); A.page=0; A.canal=''; }
    A.ws=S.ws; const ws=A.ws;
    m.innerHTML='<div class="head"><div><h1>Atendimento</h1><span class="muted">Uma conversa, todo o contexto do cliente.</span></div><button class="btn" id="atdCanais">Canais e conexões</button></div><div id="atdRoot" class="panel">Carregando conversas…</div>';
    m.querySelector('#atdCanais').onclick=()=>{S.view='atd-canais';render();};
    try {
      const [ctx,canais]=await Promise.all([api('contexto',{},ws),q(sb.from('atd_canais').select('*').eq('workspace_id',ws).order('nome'))]);
      if(!active(token)) return; A.ctx=ctx; A.canais=canais;
      m.querySelector('#atdRoot').outerHTML=`<div id="atdRoot" class="atd-layout${A.sel?' selecionada':''}"><aside class="atd-lista"><div class="atd-filtros"><input id="atdBusca" aria-label="Buscar conversa" placeholder="Nome ou número…" value="${esc(A.busca)}"><select id="atdFiltroCanal" aria-label="Canal"><option value="">Todos os canais e números</option>${canais.map(c=>`<option value="${c.id}"${A.canal===c.id?' selected':''}>${esc(label(c.canal)+' · '+c.nome)}</option>`).join('')}</select><div class="atd-dupla"><select id="atdTipo" aria-label="Tipo"><option value="">Pessoas e grupos</option><option value="pessoa">Pessoas</option><option value="grupo">Grupos</option></select><select id="atdStatus" aria-label="Situação"><option value="">Todas as situações</option><option value="aberta">Abertas</option><option value="aguardando">Aguardando</option><option value="resolvida">Resolvidas</option></select></div><select id="atdMinhas" aria-label="Responsável"><option value="">Todos os responsáveis</option><option value="minhas">Minhas conversas</option><option value="sem">Sem responsável</option><option value="nao-lidas">Não lidas</option></select></div><div id="atdLista"></div><button class="btn sm" id="atdMais">Carregar mais conversas</button></aside><section class="atd-chat" id="atdChat"><div class="atd-vazio">Selecione uma conversa.<br>Conecte um canal para começar.</div></section><aside class="atd-ficha" id="atdFicha"><div class="atd-vazio">O cadastro do cliente aparece aqui.</div></aside></div>`;
      for(const [id,k] of [['atdFiltroCanal','canal'],['atdTipo','tipo'],['atdStatus','status'],['atdMinhas','minhas']]) { const e=m.querySelector('#'+id);e.value=A[k];e.onchange=()=>{A[k]=e.value;A.page=0;act(()=>refresh(token));}; }
      let debounce; m.querySelector('#atdBusca').oninput=e=>{A.busca=e.target.value;clearTimeout(debounce);debounce=setTimeout(()=>{A.page=0;act(()=>refresh(token));},250);};
      m.querySelector('#atdMais').onclick=()=>{A.page++;act(()=>refresh(token,true));};
      await refresh(token); if(A.sel) await openChat(A.sel,token);
      if(!active(token)) return;
      A.subscription=sb.channel('atd:'+ws+':'+token).on('postgres_changes',{event:'*',schema:'public',table:'atd_mensagens',filter:'workspace_id=eq.'+ws},()=>refreshCurrent(token)).on('postgres_changes',{event:'*',schema:'public',table:'atd_conversas',filter:'workspace_id=eq.'+ws},()=>refreshCurrent(token)).subscribe();
      A.timer=setInterval(()=>{if(!active(token)){stop();return;} if(!document.hidden) refreshCurrent(token);},15000);
    } catch(e) { if(active(token)) m.querySelector('#atdRoot').innerHTML=`<div class="empty"><b>Atendimento ainda não disponível</b><p>${esc(e.message)}</p><p>Confira a migração e a função de Atendimento. Nenhum dado foi alterado.</p></div>`; }
  }
  let refreshing=false;
  async function refreshCurrent(token) {
    if(!active(token)||refreshing) return; refreshing=true;
    try { await refresh(token); if(A.sel) await messages(A.sel,token,false); } catch {} finally{refreshing=false;}
  }
  async function refresh(token,more=false) {
    const sequence=++A.listSeq;
    let query=sb.from('atd_conversas').select('*').eq('workspace_id',A.ws).order('ultima_em',{ascending:false,nullsFirst:false}).order('id').range(more?A.page*50:0,(A.page+1)*50-1);
    if(A.canal) query=query.eq('canal_id',A.canal);
    if(A.tipo) query=query.eq('grupo',A.tipo==='grupo');
    if(A.status) query=query.eq('status',A.status);
    if(A.minhas==='minhas') query=query.eq('responsavel_id',A.ctx.user_id);
    if(A.minhas==='sem') query=query.is('responsavel_id',null);
    if(A.minhas==='nao-lidas') query=query.gt('nao_lidas',0);
    const term=A.busca.replace(/[^\p{L}\p{N}\s+@.-]/gu,'').trim();
    if(term) query=query.or('nome.ilike.%'+term+'%,endereco.ilike.%'+term+'%');
    const rows=await q(query); if(!active(token)||sequence!==A.listSeq) return;
    A.lista=more?[...A.lista,...rows]:rows;
    $('#atdLista').innerHTML=A.lista.length?A.lista.map(c=>{const ch=A.canais.find(x=>x.id===c.canal_id)||{};return `<button class="atd-item${A.sel===c.id?' on':''}" data-conversa="${c.id}">${c.nao_lidas?`<span class="atd-count">${c.nao_lidas}</span>`:''}<span class="atd-avatar">${c.grupo?'♟':esc(c.nome.slice(0,1).toUpperCase())}</span><b>${esc(c.nome)}</b><small>${esc(label(ch.canal)+' · '+ch.nome)}${c.grupo?' · Grupo':''}</small><small>${esc(c.ultima_mensagem||'Histórico disponível para importar')}</small><small>${fmt(c.ultima_em)} · ${esc(c.status)}</small></button>`;}).join(''):'<div class="atd-vazio">Nenhuma conversa com estes filtros.</div>';
    $('#atdMais').hidden=rows.length<(more?50:(A.page+1)*50);
    $('#atdLista').onclick=e=>{const b=e.target.closest('[data-conversa]');if(b)act(()=>openChat(b.dataset.conversa,token));};
  }
  async function openChat(id,token) {
    const generation=++A.chatToken; A.sel=id;A.cursor=null;A.loaded=[];
    const ws=A.ws;
    const cv=await q(sb.from('atd_conversas').select('*').eq('workspace_id',ws).eq('id',id).single());
    if(!active(token)||generation!==A.chatToken) return;
    const ch=A.canais.find(c=>c.id===cv.canal_id)||{}, draft=A.drafts.get(draftKey(id))||'';
    $('#atdRoot').classList.add('selecionada');$('#atdRoot').classList.remove('ficha');
    $('#atdChat').innerHTML=`<header class="atd-top"><div><button class="btn sm atd-mobile" id="atdVoltar">← Conversas</button><strong>${esc(cv.nome)}</strong><small class="muted">${esc(label(ch.canal)+' · '+(ch.nome||''))}${cv.grupo?' · Grupo':''}</small></div><div><select id="atdSituacao" aria-label="Situação da conversa" ${A.ctx.editar?'':'disabled'}>${['aberta','aguardando','resolvida'].map(s=>`<option value="${s}"${cv.status===s?' selected':''}>${s==='aberta'?'Aberta':s==='aguardando'?'Aguardando':'Resolvida'}</option>`).join('')}</select> <button class="btn sm atd-mobile" id="atdVerFicha">Ficha</button></div></header><div class="atd-msgs" id="atdMensagens"></div><form class="atd-compose" id="atdCompose"><div class="atd-dupla"><select id="atdModo" aria-label="Tipo de mensagem"><option value="enviar">Mensagem</option><option value="nota">Nota interna</option></select><button type="button" class="btn sm" id="atdHistorico">Importar histórico</button></div><textarea id="atdTexto" aria-label="Mensagem" maxlength="4000" placeholder="Escreva sua mensagem…" ${A.ctx.editar?'':'disabled'}>${esc(draft)}</textarea><div class="atd-arquivo" id="atdArquivoNome"></div><footer><label class="btn sm">Anexar<input type="file" id="atdArquivo" class="atd-hidden" accept="image/jpeg,image/png,image/webp,video/mp4,audio/ogg,audio/mpeg,audio/mp4,audio/webm,application/pdf"></label><small class="muted">${A.ctx.nome?'Assinado por '+esc(A.ctx.nome):'Cadastre seu nome na equipe para enviar.'}</small><button class="btn pri" id="atdEnviar" ${A.ctx.editar?'':'disabled'}>Enviar</button></footer></form>`;
    $('#atdVoltar').onclick=()=>$('#atdRoot').classList.remove('selecionada');
    $('#atdVerFicha').onclick=()=>$('#atdRoot').classList.toggle('ficha');
    $('#atdSituacao').onchange=e=>act(()=>api('atualizar',{conversa_id:id,status:e.target.value},ws));
    $('#atdTexto').oninput=e=>A.drafts.set(draftKey(id),e.target.value);
    $('#atdModo').onchange=e=>{$('#atdEnviar').textContent=e.target.value==='nota'?'Salvar nota':'Enviar';};
    $('#atdArquivo').onchange=e=>{const f=e.target.files[0];if(f?.size>8*1024*1024){toast('Limite de 8 MB por anexo.',true);e.target.value='';}$('#atdArquivoNome').textContent=e.target.files[0]?.name||'';};
    $('#atdHistorico').onclick=()=>act(async()=>{const b=$('#atdHistorico');b.disabled=true;try {const r=await api('historico',{conversa_id:id,cursor:A.cursor},ws);A.cursor=r.cursor;if(active(token)&&A.sel===id){b.textContent=r.cursor?'Importar mais histórico':'Atualizar histórico';await messages(id,token);toast(r.total+' mensagens consultadas.');}}finally{if(b.isConnected)b.disabled=false;}});
    $('#atdCompose').onsubmit=async e=>{
      e.preventDefault();const form=e.currentTarget,btn=form.querySelector('#atdEnviar');if(btn.disabled)return;
      const text=form.querySelector('#atdTexto').value.trim(),mode=form.querySelector('#atdModo').value,file=form.querySelector('#atdArquivo').files[0];
      if(!text){toast('Escreva uma mensagem ou legenda.',true);return;}
      if(mode==='nota'&&file){toast('Remova o anexo para salvar uma nota interna.',true);return;}
      btn.disabled=true;const rid=crypto.randomUUID();
      try{
        let arquivo;if(file){const base64=await new Promise((res,rej)=>{const r=new FileReader();r.onload=()=>res(String(r.result).split(',')[1]);r.onerror=rej;r.readAsDataURL(file);});arquivo={nome:file.name,mime:file.type,base64};}
        await api(mode,{conversa_id:id,texto:text,requisicao_id:rid,arquivo},ws);
        A.drafts.delete(ws+':'+id);if(active(token)&&A.sel===id){form.querySelector('#atdTexto').value='';form.querySelector('#atdArquivo').value='';$('#atdArquivoNome').textContent='';}
      }catch(err){toast(err.message,true);}finally{if(form.isConnected)btn.disabled=false;if(active(token)&&A.sel===id)await messages(id,token);}
    };
    await Promise.all([messages(id,token),ficha(cv,token,generation)]);
    if(active(token)&&A.sel===id&&A.ctx.editar&&cv.nao_lidas) await api('atualizar',{conversa_id:id,lida:true},ws);
  }
  async function messages(id,token,scroll=true,before) {
    const r=await api('mensagens',{conversa_id:id,before},A.ws);
    if(!active(token)||A.sel!==id) return;
    const box=$('#atdMensagens'); if(!box)return;
    const bottom=box.scrollHeight-box.scrollTop-box.clientHeight<80;
    A.loaded=[...A.loaded,...r.mensagens];
    const map=new Map(A.loaded.map(m=>[m.id,m]));A.loaded=[...map.values()].sort((a,b)=>a.em.localeCompare(b.em)||a.id.localeCompare(b.id));
    box.innerHTML=`${r.mensagens.length===60?'<button class="btn sm" id="atdAntigas">Mensagens anteriores</button>':''}`+A.loaded.map(m=>`<article class="atd-balao ${m.direcao}">${m.autor_nome?`<span class="atd-autor">${esc(m.autor_nome)}</span>`:m.participante?`<span class="atd-autor">${esc(m.participante)}</span>`:''}${textoMensagem(m)}${listOf(m.anexos).map((a,i)=>`<div><button class="btn sm" data-midia="${m.id}" data-index="${i}" data-pendente="${a.pendente?'1':'0'}">${a.pendente?'Recuperar anexo':'↓ '+esc(a.nome)}</button></div>`).join('')}<small>${fmt(m.em)} · ${state[m.status]||esc(m.status)}</small>${m.erro?`<span class="atd-erro">${esc(m.erro)}</span>`:''}</article>`).join('');
    if(!A.loaded.length)box.innerHTML='<div class="atd-vazio">Nenhuma mensagem salva ainda.<br>Use “Importar histórico” para consultar o canal.</div>';
    if(scroll||bottom)box.scrollTop=box.scrollHeight;
    box.querySelector('#atdAntigas')?.addEventListener('click',()=>act(()=>messages(id,token,false,{em:A.loaded[0]?.em,id:A.loaded[0]?.id})));
    box.onclick=e=>{const b=e.target.closest('[data-midia]');if(b)act(async()=>{if(b.dataset.pendente==='1'){await api('recuperar-midia',{mensagem_id:b.dataset.midia});await messages(id,token,false);}else{const r=await api('anexo',{mensagem_id:b.dataset.midia,indice:Number(b.dataset.index)});const a=document.createElement('a');a.href=r.signedUrl;a.target='_blank';a.rel='noopener';a.click();}});};
  }
  async function ficha(cv,token,generation) {
    const ws=A.ws, rows=await q(sb.from('equipe').select('nome,user_id').eq('workspace_id',ws).eq('ativo',true).not('user_id','is',null));
    let p=null,notes=[],sales=[],opps=[];
    if(cv.pessoa_id) [p,notes,sales,opps]=await Promise.all([
      q(sb.from('pessoas').select('*').eq('workspace_id',ws).eq('id',cv.pessoa_id).single()),
      q(sb.from('pessoa_notas').select('texto,criado_em').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).order('criado_em',{ascending:false}).limit(5)),
      q(sb.from('vendas').select('valor_bruto,status,data_venda').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).order('data_venda',{ascending:false}).limit(5)),
      q(sb.from('oportunidades').select('titulo,status').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).limit(10)),
    ]);
    if(!active(token)||generation!==A.chatToken)return;
    $('#atdFicha').innerHTML=`<button class="btn sm atd-mobile" id="atdFichaVoltar">← Conversa</button><h3>${cv.grupo?'Grupo de WhatsApp':p?'Lead / Cliente':'Contato ainda não vinculado'}</h3><p><b>${esc(p?.nome||cv.nome)}</b><br>${esc(p?.telefone||cv.endereco||'')}<br>${esc(p?.email||'')}</p><label>Responsável<select id="atdResponsavel" ${A.ctx.editar?'':'disabled'}><option value="">Sem responsável</option>${rows.map(r=>`<option value="${r.user_id}"${cv.responsavel_id===r.user_id?' selected':''}>${esc(r.nome)}</option>`).join('')}</select></label>${cv.grupo?'<p class="muted">As mensagens identificam cada participante. O grupo não é vinculado a um único lead.</p>':p?`<p>${esc(p.status_funil)} · ${esc(p.qualificacao||'')}</p><button class="btn" id="atdFichaCompleta">Abrir ficha completa</button><details open><summary>Oportunidades</summary>${opps.map(o=>`<p>${esc(o.titulo)} · ${esc(o.status)}</p>`).join('')||'<p>Nenhuma oportunidade.</p>'}</details><details><summary>Últimas compras</summary>${sales.map(v=>`<p>${brl(v.valor_bruto)} · ${esc(v.status)}<br>${esc(v.data_venda)}</p>`).join('')||'<p>Nenhuma compra.</p>'}</details><details><summary>Notas do cadastro</summary>${notes.map(n=>`<p>${esc(n.texto)}</p>`).join('')||'<p>Nenhuma nota.</p>'}</details><p class="muted">Na ficha completa: jornada, campos extras, contratos, atividades e histórico.</p>`:'<p>Vincule a uma pessoa do CRM para reunir o histórico dos canais.</p><button class="btn" id="atdCriarLead">Criar lead</button>'}${!cv.grupo&&A.ctx.editar?'<button class="btn sm" id="atdVincular">'+(p?'Alterar vínculo':'Vincular pessoa existente')+'</button>':''}`;
    $('#atdFichaVoltar').onclick=()=>$('#atdRoot').classList.remove('ficha');
    $('#atdResponsavel').onchange=e=>act(()=>api('atualizar',{conversa_id:cv.id,responsavel_id:e.target.value},ws));
    $('#atdFichaCompleta')?.addEventListener('click',()=>act(()=>fichaPessoa(cv.pessoa_id)));
    $('#atdCriarLead')?.addEventListener('click',()=>act(async()=>{await api('criar-lead',{conversa_id:cv.id},ws);await openChat(cv.id,token);}));
    $('#atdVincular')?.addEventListener('click',()=>{
      const form=modal('Vincular pessoa do CRM','<input id="atdPessoaBusca" placeholder="Buscar por nome ou telefone" aria-label="Buscar pessoa"><div id="atdPessoas" class="atd-pessoa-busca"></div>',null);
      let timer,seq=0;form.querySelector('input').oninput=e=>{clearTimeout(timer);const term=e.target.value.replace(/[^\p{L}\p{N}\s+.-]/gu,'').trim(),n=++seq;timer=setTimeout(()=>act(async()=>{if(term.length<2)return;const people=await q(sb.from('pessoas').select('id,nome,telefone').eq('workspace_id',ws).or('nome.ilike.%'+term+'%,telefone.ilike.%'+term+'%').limit(20));if(n!==seq||!form.isConnected)return;form.querySelector('#atdPessoas').innerHTML=people.map(p=>`<button type="button" class="btn" data-pessoa="${p.id}">${esc(p.nome)} · ${esc(p.telefone||'')}</button>`).join('')||'<p>Nenhuma pessoa encontrada.</p>';form.querySelector('#atdPessoas').onclick=e=>{const b=e.target.closest('[data-pessoa]');if(b)act(async()=>{await api('vincular',{conversa_id:cv.id,pessoa_id:b.dataset.pessoa},ws);$('#modalRoot').innerHTML='';if(active(token))await openChat(cv.id,token);});};}),250);};
    });
  }
  async function configurarEvolution() {
    const ws=S.ws,cfg=await api('config',{},ws);
    modal('Evolution API · 2.3.7',`<label>URL do servidor<input name="url" type="url" required placeholder="https://evolution.suaempresa.com" value="${esc(cfg.url)}"></label><label>API Key<input name="key" type="password" autocomplete="new-password" ${cfg.configurada?'':'required'} placeholder="${cfg.configurada?'Deixe vazio para manter a chave atual':'Chave global da Evolution'}"></label><p class="muted">A chave fica no servidor e nunca é devolvida ao navegador. Vamos testar a conexão antes de salvar.</p>`,async(d,form)=>{await api('salvar-config',d,ws);form.querySelector('[name=key]').value='';toast('Evolution configurada.');});
  }
  async function conectarZernio(ws=S.ws) {
    const r=await api('zernio-disponiveis',{},ws);
    if(S.ws!==ws)return;
    if(!r.contas.length){toast('Nenhuma conta Zernio disponível. Conecte Instagram ou WhatsApp na sua conta Zernio e confira se ela já pertence a outro cliente.',true);return;}
    const options=r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome+(c.vinculada?' (já vinculada)':''))}</option>`).join('');
    modal('Vincular conta Zernio ao cliente',`<p>Cliente selecionado: vincule apenas a conta que pertence a ele. Não é necessário informar a chave da Zernio.</p><label>Conta Zernio<select name="account_id" required>${options}</select></label><p class="muted">As contas de outros clientes não aparecem na lista.</p>`,async d=>{
      await api('zernio-conectar',d,ws);
      toast('Conta Zernio vinculada ao cliente. Agora adicione-a em Atendimento → Canais e conexões.');
    });
  }
  async function vCanais(m) {
    stop();++A.token;const ws=S.ws;
    m.innerHTML='<div class="head"><h1>Canais de atendimento</h1><button class="btn" id="atdInbox">Conversas</button></div><div id="atdCanaisCorpo">Carregando…</div>';
    $('#atdInbox').onclick=()=>{S.view='atd-conversas';render();};
    const [ctx,canais]=await Promise.all([api('contexto',{},ws),q(sb.from('atd_canais').select('*').eq('workspace_id',ws).order('nome'))]);
    if(S.ws!==ws||S.view!=='atd-canais')return;
    $('#atdCanaisCorpo').innerHTML=`<div class="panel"><p>WhatsApp oficial e Instagram pela Zernio. WhatsApp e grupos pela Evolution 2.3.7.</p>${ctx.admin?'<div class="acts"><button class="btn" id="atdConfigEvo">Configurar Evolution</button><button class="btn pri" id="atdNovaInst">Nova instância WhatsApp</button><button class="btn" id="atdZernio">Adicionar conta Zernio</button></div>':'<p>Um administrador gerencia as conexões.</p>'}</div><div class="atd-canais">${canais.map(c=>`<article class="atd-canal"><h3>${esc(c.nome)}</h3><p>${esc(label(c.canal))} · ${esc(c.provedor)}</p><span class="pill ${c.status==='conectado'?'good':'warn'}">${esc(c.status)}</span><p class="muted">${esc(c.numero||c.externo_id)}</p><div class="acts">${ctx.admin&&c.provedor==='evolution'?`<button class="btn sm" data-ca="conectar" data-id="${c.id}">QR Code</button><button class="btn sm" data-ca="status" data-id="${c.id}">Verificar status</button>`:''}${ctx.admin?`<button class="btn sm" data-ca="webhook" data-id="${c.id}">Ativar recebimento</button>`:''}${ctx.editar?`<button class="btn sm" data-ca="sincronizar" data-id="${c.id}">${c.provedor==='evolution'?'Buscar conversas e grupos':'Buscar conversas'}</button>`:''}</div><div id="ca-${c.id}"></div></article>`).join('')||'<div class="panel">Nenhum canal adicionado.</div>'}</div>`;
    $('#atdConfigEvo')?.addEventListener('click',()=>act(configurarEvolution));
    $('#atdNovaInst')?.addEventListener('click',()=>modal('Nova instância WhatsApp','<label>Nome deste número<input name="nome" required placeholder="Comercial · Número principal" maxlength="100"></label>',async d=>{await api('criar-instancia',d,ws);toast('Instância criada. Abra QR Code para conectar.');}));
    $('#atdZernio')?.addEventListener('click',()=>act(async()=>{const r=await api('zernio-contas',{},ws);if(!r.contas.length){const interna=await q(sb.rpc('sou_equipe_interna'));if(!interna){toast('Peça à equipe Mathisa para vincular sua conta Zernio em Integrações.',true);return;}await conectarZernio(ws);return;}modal('Adicionar conta da Zernio',`<label>Conta<select name="account_id">${r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome)}</option>`).join('')}</select></label><p>Somente contas do perfil já conectado a este workspace.</p>`,async d=>{await api('zernio-vincular',d,ws);toast('Conta adicionada. Ative o recebimento e busque as conversas.');});}));
    $('#atdCanaisCorpo').onclick=async e=>{const btn=e.target.closest('[data-ca]');if(!btn||btn.disabled)return;const id=btn.dataset.id,action=btn.dataset.ca;btn.disabled=true;
      try{const r=await api(action,{canal_id:id,cursor:btn.dataset.cursor||undefined},ws);if(S.ws!==ws||S.view!=='atd-canais')return;
        const target=$('#ca-'+id);
        if(action==='conectar'){target.innerHTML=r.qrcode&&/^data:image\/(png|jpeg);base64,/.test(r.qrcode)?`<img class="atd-qr" alt="QR Code para conectar o WhatsApp" src="${r.qrcode}"><p>WhatsApp → Aparelhos conectados → Conectar aparelho. Se expirar, clique em QR Code novamente.</p>`:'<p>QR Code indisponível. Confira o status ou tente novamente.</p>';}
        else if(action==='sincronizar'){btn.dataset.cursor=r.cursor||'';btn.textContent=r.cursor?'Buscar mais conversas':'Atualizar conversas';target.textContent=r.total+' conversas consultadas.';}
        else if(action==='status'){target.textContent='Status: '+r.status;if(r.status==='conectado')target.querySelector('img')?.remove();}
        else target.textContent='Recebimento por webhook ativado.';
      }catch(err){toast(err.message,true);}finally{btn.disabled=false;}
    };
  }
  NAV.splice(NAV.findIndex(g=>g.g==='Vendas')+1,0,{g:'Atendimento',items:[['atd-conversas','Conversas'],['atd-canais','Canais e conexões']]});
  MOD_GRUPO.Atendimento='vendas';
  ICO.Atendimento=ICO['crm-dms']||ICO.Vendas||'';ICO['atd-conversas']=ICO['crm-dms']||'';ICO['atd-canais']=ICO['cfg-integracoes'];
  VIEWS['atd-conversas']=vAtendimento;VIEWS['atd-canais']=vCanais;
  const originalIntegracoes=VIEWS['cfg-integracoes'];
  VIEWS['cfg-integracoes']=async m=>{await originalIntegracoes(m);const card=document.createElement('div');card.className='panel';card.innerHTML='<h2>Evolution API · WhatsApp e grupos</h2><p>Conecte seu servidor Evolution 2.3.7 para atender pessoas e grupos. Configure a URL e a API Key; gerencie instâncias, QR Code e status na central.</p><div class="acts"><button class="btn pri" id="atdIntegrationConfig">Configurar URL e Key</button><button class="btn" id="atdIntegrationChannels">Gerenciar canais</button></div>';m.prepend(card);card.querySelector('#atdIntegrationConfig').onclick=()=>act(configurarEvolution);card.querySelector('#atdIntegrationChannels').onclick=()=>{S.view='atd-canais';render();};};
  // Conexão por cliente: mostra o vínculo atual e permite selecionar uma conta da Zernio.
  const anteriorZernio=VIEWS['cfg-integracoes'];
  VIEWS['cfg-integracoes']=async m=>{
    await anteriorZernio(m);
    if(S.view!=='cfg-integracoes')return;
    const ws=S.ws;
    const card=document.createElement('div');
    card.className='panel';
    card.innerHTML='<h2>Zernio · Instagram e WhatsApp oficial</h2><p id="zernioSituacao">Consultando contas deste cliente…</p><div class="acts"><button class="btn pri" id="zernioVincular">Vincular conta Zernio</button><button class="btn" id="zernioAtendimento">Canais de atendimento</button></div>';
    m.prepend(card);
    card.querySelector('#zernioVincular').onclick=()=>act(()=>conectarZernio(ws));
    card.querySelector('#zernioAtendimento').onclick=()=>{S.view='atd-canais';render();};
    try{
      const ctx=await api('contexto',{},ws);
      if(S.ws!==ws||S.view!=='cfg-integracoes'||!card.isConnected)return;
      const interna=ctx.admin ? await q(sb.rpc('sou_equipe_interna')) : false;
      if(!ctx.admin||!interna)card.querySelector('#zernioVincular').remove();
      if(!ctx.admin){card.querySelector('#zernioSituacao').textContent='Somente administradores podem consultar as conexões.';return;}
      const r=await api('zernio-contas',{},ws);
      if(S.ws!==ws||S.view!=='cfg-integracoes'||!card.isConnected)return;
      card.querySelector('#zernioSituacao').textContent=r.contas.length
        ? r.contas.map(c=>label(c.canal)+' · '+c.nome).join(' | ')
        : 'Nenhuma conta vinculada a este cliente.';
    }catch(e){if(S.ws===ws&&card.isConnected)card.querySelector('#zernioSituacao').textContent='Não foi possível consultar a Zernio: '+e.message;}
  };
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&S.view==='atd-conversas')refreshCurrent(A.token);});
})();
