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
  const tipoCanal = ch => ch.canal==='instagram'?'instagram':ch.canal==='whatsapp'?'whatsapp':'outro';
  const nomeCanal = ch => ch.canal==='instagram'?'Instagram':ch.canal==='whatsapp'
    ?ch.provedor==='evolution'?'WhatsApp · QR Code':'WhatsApp · API oficial':label(ch.canal);
  const identidadeCanal = ch => ch.canal==='instagram'
    ?('Perfil: '+(ch.nome||'não identificado'))
    :ch.canal==='whatsapp'
      ?('Número: '+(ch.numero?'+'+String(ch.numero).replace(/\D/g,''):'não identificado'))
      :(ch.nome||'Canal');
  const faixaCanal = ch => `<span class="atd-faixa atd-faixa--${tipoCanal(ch)}"><b>${esc(nomeCanal(ch))}</b><span>${esc(identidadeCanal(ch))}</span></span>`;

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
      const [ctx,canais,identidades]=await Promise.all([api('contexto',{},ws),
        q(sb.from('atd_canais').select('*').eq('workspace_id',ws).order('nome')),
        api('identidades',{},ws).catch(()=>({canais:[]}))]);
      const nomesNovos=new Map((identidades.canais||[]).map(c=>[c.id,c]));
      for(const ch of canais){const ident=nomesNovos.get(ch.id);if(ident?.numero)ch.numero=ident.numero;}
      if(!active(token)) return; A.ctx=ctx; A.canais=canais;
      m.querySelector('#atdRoot').outerHTML=`<div id="atdRoot" class="atd-layout${A.sel?' selecionada':''}"><aside class="atd-lista"><div class="atd-filtros"><input id="atdBusca" aria-label="Buscar conversa" placeholder="Nome ou número…" value="${esc(A.busca)}"><select id="atdFiltroCanal" aria-label="Canal"><option value="">Todos os canais e números</option>${canais.map(c=>`<option value="${c.id}"${A.canal===c.id?' selected':''}>${esc(nomeCanal(c)+' · '+identidadeCanal(c))}</option>`).join('')}</select><div class="atd-dupla"><select id="atdTipo" aria-label="Tipo"><option value="">Pessoas e grupos</option><option value="pessoa">Pessoas</option><option value="grupo">Grupos</option></select><select id="atdStatus" aria-label="Situação"><option value="">Todas as situações</option><option value="aberta">Abertas</option><option value="aguardando">Aguardando</option><option value="resolvida">Resolvidas</option></select></div><select id="atdMinhas" aria-label="Responsável"><option value="">Todos os responsáveis</option><option value="minhas">Minhas conversas</option><option value="sem">Sem responsável</option><option value="nao-lidas">Não lidas</option></select></div><div id="atdLista"></div><button class="btn sm" id="atdMais">Carregar mais conversas</button></aside><section class="atd-chat" id="atdChat"><div class="atd-vazio">Selecione uma conversa.<br>Conecte um canal para começar.</div></section><aside class="atd-ficha" id="atdFicha"><div class="atd-vazio">O cadastro do cliente aparece aqui.</div></aside></div>`;
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
    $('#atdLista').innerHTML=A.lista.length?A.lista.map(c=>{const ch=A.canais.find(x=>x.id===c.canal_id)||{};return `<button class="atd-item${A.sel===c.id?' on':''}" data-conversa="${c.id}">${c.nao_lidas?`<span class="atd-count">${c.nao_lidas}</span>`:''}<span class="atd-avatar">${c.grupo?'♟':esc(c.nome.slice(0,1).toUpperCase())}</span><b>${esc(c.nome)}</b><div class="atd-identificacao">${faixaCanal(ch)}${c.grupo?'<small>Grupo</small>':''}</div><small>${esc(c.ultima_mensagem||'Histórico disponível para importar')}</small><small>${fmt(c.ultima_em)} · ${esc(c.status)}</small></button>`;}).join(''):'<div class="atd-vazio">Nenhuma conversa com estes filtros.</div>';
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
    $('#atdChat').innerHTML=`<header class="atd-top"><div><button class="btn sm atd-mobile" id="atdVoltar">← Conversas</button><strong>${esc(cv.nome)}</strong><div class="atd-identificacao">${faixaCanal(ch)}${cv.grupo?'<small>Grupo</small>':''}</div></div><div><select id="atdSituacao" aria-label="Situação da conversa" ${A.ctx.editar?'':'disabled'}>${['aberta','aguardando','resolvida'].map(s=>`<option value="${s}"${cv.status===s?' selected':''}>${s==='aberta'?'Aberta':s==='aguardando'?'Aguardando':'Resolvida'}</option>`).join('')}</select> <button class="btn sm atd-mobile" id="atdVerFicha">Ficha</button></div></header><div class="atd-msgs" id="atdMensagens"></div><form class="atd-compose" id="atdCompose"><div class="atd-dupla"><select id="atdModo" aria-label="Tipo de mensagem"><option value="enviar">Mensagem</option><option value="nota">Nota interna</option></select><button type="button" class="btn sm" id="atdHistorico">Importar histórico</button></div><textarea id="atdTexto" aria-label="Mensagem" maxlength="4000" placeholder="Escreva sua mensagem…" ${A.ctx.editar?'':'disabled'}>${esc(draft)}</textarea><div class="atd-arquivo" id="atdArquivoNome"></div><footer><label class="btn sm">Anexar<input type="file" id="atdArquivo" class="atd-hidden" accept="image/jpeg,image/png,image/webp,video/mp4,audio/ogg,audio/mpeg,audio/mp4,audio/webm,application/pdf"></label><small class="muted">${A.ctx.nome?'Assinado por '+esc(A.ctx.nome):'Cadastre seu nome na equipe para enviar.'}</small><button class="btn pri" id="atdEnviar" ${A.ctx.editar?'':'disabled'}>Enviar</button></footer></form>`;
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
  // Popup criado sincronamente no clique para não ser bloqueado pelo navegador.
  async function conectarInstagram(ws=S.ws) {
    const popup=window.open('about:blank','growthsInstagramOAuth','width=620,height=760');
    if(!popup){toast('Permita popups para conectar o Instagram.',true);return;}
    popup.document.body.innerHTML='<p style="font:16px system-ui;padding:24px">Abrindo autorização do Instagram…</p>';
    try{
      // Compara contas antes/depois: fechar a janela não indica autorização concluída.
      const before=await api('zernio-contas',{},ws).catch(()=>({contas:[]}));
      const instagramAntes=new Set((before.contas||[]).filter(c=>c.canal==='instagram').map(c=>c.id));
      if(S.ws!==ws){popup.close();return;}
      const {data,error}=await sb.functions.invoke('instagram-oauth',{body:{workspace_id:ws}});
      if(error){let msg;try{msg=(await error.context.json()).erro;}catch{}throw new Error(msg||'Não foi possível iniciar o login do Instagram.');}
      if(data?.erro)throw new Error(data.erro);
      const auth=new URL(String(data?.authUrl||''));
      if(auth.protocol!=='https:'||!['instagram.com','www.instagram.com','facebook.com','www.facebook.com'].includes(auth.hostname))
        throw new Error('URL de autorização inválida.');
      if(popup.closed)throw new Error('Janela de autorização fechada.');
      popup.location.replace(auth.toString());
      const timer=setInterval(async()=>{
        if(!popup.closed)return;
        clearInterval(timer);
        if(S.ws!==ws)return;
        // A finalização é confirmada pelo servidor; fechar a janela não significa sucesso.
        try{
          const r=await api('zernio-contas',{},ws);
          const novas=(r.contas||[]).filter(c=>c.canal==='instagram'&&!instagramAntes.has(c.id));
          if(novas.length)toast('Instagram conectado. A conta está pronta em Atendimento.');
          else toast('Janela encerrada. Nenhuma nova conta detectada; confira o status em Integrações.');
          if(S.view==='cfg-integracoes'||S.view==='atd-canais')await render();
        }catch(e){toast('Atualize a tela para conferir a conexão do Instagram.',true);}
      },1000);
    }catch(e){if(!popup.closed)popup.close();toast(e.message,true);}
  }
  // A Meta é autorizada pela conta Zernio central, sem secrets META_* no Growth V2.
  async function metaZernio(ws,action,body={}) {
    const {data,error}=await sb.functions.invoke('meta-zernio',{body:{action,workspace_id:ws,...body}});
    if(error){let msg;try{msg=(await error.context.json()).erro;}catch{}throw new Error(msg||'Não foi possível consultar a Zernio.');}
    if(data?.erro)throw new Error(data.erro);
    return data;
  }
  async function escolherMetaZernio(ws,contas) {
    if(S.ws!==ws||!contas?.length)return;
    // Um anunciante pode ter dezenas de contas de outros clientes: não selecionar todas automaticamente.
    const agrupadas={};
    for(const c of contas)(agrupadas[c.zernioId] ||= []).push(c);
    const grupos=Object.entries(agrupadas);
    if(grupos.length===1 && contas.length===1){
      const c=contas[0];
      await metaZernio(ws,'selecionar',{zernio_account_id:c.zernioId,ad_account_ids:[c.id]});
      toast('Meta conectada. Conta de anúncios autorizada: '+c.nome);
      if(S.ws===ws&&S.view==='cfg-integracoes')render();
      return;
    }
    const campos=grupos.map(([zid,rows],i)=>`<fieldset style="border:1px solid var(--line);border-radius:8px;margin:8px 0;padding:10px"><legend>Conexão Meta ${i+1}</legend>${rows.map((c,j)=>`<label style="display:flex;align-items:center;gap:8px"><input type="checkbox" name="ma_${i}_${j}" style="width:auto" ${c.selecionada?'checked':''}>${esc(c.nome)} (${esc(c.id)})</label>`).join('')}</fieldset>`).join('');
    modal('Selecionar contas de anúncios',`<p>Marque apenas as contas de anúncios que pertencem ao cliente atual. Contas de outros clientes não serão sincronizadas.</p>${campos}`,async(d)=>{
      let total=0;
      for(let i=0;i<grupos.length;i++){
        const [zid,rows]=grupos[i];
        const ids=rows.filter((c,j)=>d['ma_'+i+'_'+j]).map(c=>c.id);
        if(!ids.length)continue;
        await metaZernio(ws,'selecionar',{zernio_account_id:zid,ad_account_ids:ids});total+=ids.length;
      }
      if(!total)throw new Error('Escolha pelo menos uma conta de anúncios.');
      toast(total+' conta(s) de anúncios vinculadas ao cliente.');
    },'Vincular contas');
  }
  async function conectarMetaZernio(ws=S.ws){
    // Abrir popup durante o clique (antes do await) para evitar bloqueio de navegadores.
    const popup=window.open('about:blank','growthsMetaOAuth','width=650,height=780');
    if(!popup){toast('Permita popups para autorizar a Meta.',true);return;}
    popup.document.body.textContent='Preparando o login seguro da Meta…';
    try{
      const started=await metaZernio(ws,'iniciar');
      const url=new URL(started.authUrl);
      if(url.protocol!=='https:'||!['facebook.com','www.facebook.com'].includes(url.hostname))throw Error('URL Meta inválida.');
      if(S.ws!==ws){popup.close();return;}
      popup.location.replace(url.toString());
      const timer=setInterval(async()=>{
        if(!popup.closed)return;
        clearInterval(timer);
        if(S.ws!==ws)return;
        try{
          const result=await metaZernio(ws,'contas');
          if(!result.contas?.length){toast('Nenhuma conta Meta autorizada. Confira se concluiu o login.',true);return;}
          await escolherMetaZernio(ws,result.contas);
          if(S.view==='cfg-integracoes')render();
        }catch(e){toast(e.message,true);}
      },1000);
    }catch(e){if(!popup.closed)popup.close();toast(e.message,true);}
  }
  async function conectarZernio(ws=S.ws) {
    const all=await api('zernio-disponiveis',{},ws);
    const r={contas:(all.contas||[]).filter(c=>c.canal==='whatsapp')};
    if(S.ws!==ws)return;
    if(!r.contas.length){toast('Nenhum WhatsApp oficial disponível na conta técnica Zernio da Mathisa.',true);return;}
    const options=r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome+(c.vinculada?' (já vinculada)':''))}</option>`).join('');
    modal('Vincular WhatsApp oficial ao cliente',`<p>Cliente selecionado: vincule apenas a conta que pertence a ele. Não é necessário informar a chave da Zernio.</p><label>Conta Zernio<select name="account_id" required>${options}</select></label><p class="muted">As contas de outros clientes não aparecem na lista.</p>`,async d=>{
      await api('zernio-conectar',d,ws);
      toast('Conta Zernio vinculada ao cliente. Agora adicione-a em Atendimento → Canais e conexões.');
    });
  }
  async function vCanais(m) {
    stop();++A.token;const ws=S.ws;
    m.innerHTML='<div class="head"><h1>Canais de atendimento</h1><button class="btn" id="atdInbox">Conversas</button></div><div id="atdCanaisCorpo">Carregando…</div>';
    $('#atdInbox').onclick=()=>{S.view='atd-conversas';render();};
    const [ctx,canais,identidades]=await Promise.all([api('contexto',{},ws),
        q(sb.from('atd_canais').select('*').eq('workspace_id',ws).order('nome')),
        api('identidades',{},ws).catch(()=>({canais:[]}))]);
      const nomesNovos=new Map((identidades.canais||[]).map(c=>[c.id,c]));
      for(const ch of canais){const ident=nomesNovos.get(ch.id);if(ident?.numero)ch.numero=ident.numero;}
    if(S.ws!==ws||S.view!=='atd-canais')return;
    $('#atdCanaisCorpo').innerHTML=`<div class="panel"><p>WhatsApp oficial e Instagram pela Zernio. WhatsApp e grupos pela Evolution 2.3.7.</p>${ctx.admin?'<div class="acts"><button class="btn" id="atdConfigEvo">Configurar Evolution</button><button class="btn pri" id="atdNovaInst">Nova instância WhatsApp</button><button class="btn pri" id="atdInstagramConectar">Conectar Instagram</button><button class="btn" id="atdZernio">Adicionar canal já conectado</button></div>':'<p>Um administrador gerencia as conexões.</p>'}</div><div class="atd-canais">${canais.map(c=>`<article class="atd-canal"><h3>${esc(c.nome)}</h3><p>${esc(nomeCanal(c))} · ${esc(identidadeCanal(c))}</p><span class="pill ${c.status==='conectado'?'good':'warn'}">${esc(c.status)}</span><p class="muted">${esc(c.numero||c.externo_id)}</p><div class="acts">${ctx.admin&&c.provedor==='evolution'?`<button class="btn sm" data-ca="conectar" data-id="${c.id}">QR Code</button><button class="btn sm" data-ca="status" data-id="${c.id}">Verificar status</button><button class="btn sm bad" data-ca="excluir-instancia" data-id="${c.id}">Excluir instância</button>`:''}${ctx.admin?`<button class="btn sm" data-ca="webhook" data-id="${c.id}">Ativar recebimento</button>`:''}${ctx.editar?`<button class="btn sm" data-ca="sincronizar" data-id="${c.id}">${c.provedor==='evolution'?'Buscar conversas e grupos':'Buscar conversas'}</button>`:''}</div><div id="ca-${c.id}"></div></article>`).join('')||'<div class="panel">Nenhum canal adicionado.</div>'}</div>`;
    $('#atdConfigEvo')?.addEventListener('click',()=>act(configurarEvolution));
    $('#atdInstagramConectar')?.addEventListener('click',()=>conectarInstagram(ws));
    $('#atdNovaInst')?.addEventListener('click',()=>modal('Nova instância WhatsApp','<label>Nome deste número<input name="nome" required placeholder="Comercial · Número principal" maxlength="100"></label>',async d=>{await api('criar-instancia',d,ws);toast('Instância criada. Abra QR Code para conectar.');}));
    $('#atdZernio')?.addEventListener('click',()=>act(async()=>{const r=await api('zernio-contas',{},ws);if(!r.contas.length){toast('Nenhum canal vinculado. Clique em Conectar Instagram ou solicite a configuração do WhatsApp oficial.',true);return;}modal('Adicionar conta da Zernio',`<label>Conta<select name="account_id">${r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome)}</option>`).join('')}</select></label><p>Somente contas do perfil já conectado a este workspace.</p>`,async d=>{await api('zernio-vincular',d,ws);toast('Conta adicionada. Ative o recebimento e busque as conversas.');});}));
    $('#atdCanaisCorpo').onclick=async e=>{const btn=e.target.closest('[data-ca]');if(!btn||btn.disabled)return;const id=btn.dataset.id,action=btn.dataset.ca;
      if(action==='excluir-instancia'){
        const canal=canais.find(x=>x.id===id);
        if(!canal||canal.provedor!=='evolution')return;
        const aviso='Excluir definitivamente a instância '+canal.nome+' da Evolution? O WhatsApp será desconectado e a instância apagada no servidor. O histórico do Growth V2 será preservado.';
        if(!confirm(aviso))return;
      }
      btn.disabled=true;
      try{const r=await api(action,{canal_id:id,cursor:btn.dataset.cursor||undefined},ws);
        if(action==='excluir-instancia'){toast('Instância excluída da Evolution. Histórico preservado.');await render();return;}if(S.ws!==ws||S.view!=='atd-canais')return;
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
  // v0.183: intercepta cliques que ainda apontam para a Edge conexoes legada.
  // O cxLiga() original registra handlers na renderização de Integrações;
  // na fase de captura, esta ponte impede que Meta execute esses handlers.
  document.addEventListener('click',e=>{
    if(S.view!=='cfg-integracoes')return;
    const target=e.target.closest?.('[data-cxcon="meta"],[data-cxsync="meta"],[data-cxdes="meta"]');
    if(!target||!document.getElementById('main')?.contains(target))return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    if(target.hasAttribute('data-cxcon'))conectarMetaZernio(S.ws);
    else if(target.hasAttribute('data-cxsync'))act(async()=>{const r=await metaZernio(S.ws,'sincronizar');
      toast(r.erros?.length?'Sincronização parcial: '+r.erros.join(' | '):'Sincronizados '+r.registros+' registros Meta Ads.',!!r.erros?.length);
      render();
    });
    else act(async()=>{const r=await metaZernio(S.ws,'contas');const ids=[...new Set((r.contas||[]).map(c=>c.zernioId))];
      if(!ids.length){toast('Nenhuma conta Zernio ativa para desconectar.');return;}
      if(!confirm('Desconectar as contas Meta deste cliente? As métricas históricas permanecem.'))return;
      for(const id of ids)await metaZernio(S.ws,'desconectar',{zernio_account_id:id});
      toast('Meta desconectada do Growth V2.');render();
    });
  },true);
  // Não criar novos painéis em Integrações: usar os cartões do catálogo nativo.
  const originalIntegracoes=VIEWS['cfg-integracoes'];
  VIEWS['cfg-integracoes']=async m=>{
    await originalIntegracoes(m);
    const ws=S.ws;
    if(S.view!=='cfg-integracoes'||!m.isConnected)return;
    const vaiCanais=()=>{if(S.ws!==ws)return;S.view='atd-canais';render();};
    const substituirAcao=(nome,rotulo,acao,secundario)=>{
      const botao=Array.from(m.querySelectorAll('[data-i]')).find(b=>b.dataset.i===nome);
      if(!botao)return null;
      // Remove o atributo antes do clique: vIntegracoes trata [data-i] como modal manual.
      botao.removeAttribute('data-i');
      botao.textContent=rotulo;
      botao.classList.add('pri');
      botao.onclick=e=>{e.stopPropagation();if(S.ws===ws)acao();};
      if(secundario){
        const extra=document.createElement('button');
        extra.type='button';extra.className='btn sm';extra.textContent='Gerenciar canais';
        extra.onclick=e=>{e.stopPropagation();vaiCanais();};
        botao.parentElement.append(extra);
      }
      return {botao,card:botao.closest('.ad')};
    };
    // Reutiliza o cartão Meta original da área Conexões automáticas.
    const metaBtn=m.querySelector('[data-cxcon="meta"]');
    const metaCard=metaBtn?.closest('.ad');
    if(metaCard){
      const antigoSync=metaCard.querySelector('[data-cxsync="meta"]');
      if(antigoSync)antigoSync.remove(); // Era a sincronização que exigia META_APP_ID.
      const antigoDesconectar=metaCard.querySelector('[data-cxdes="meta"]');
      if(antigoDesconectar)antigoDesconectar.remove();
      const novos=[...metaCard.querySelectorAll('[data-cxcon="meta"]')];
      for(const btn of novos){
        btn.removeAttribute('data-cxcon');
        btn.textContent='Conectar Meta';
        btn.onclick=e=>{e.stopPropagation();if(S.ws===ws)conectarMetaZernio(ws);};
      }
      const status=document.createElement('small');status.className='muted';
      status.textContent='Verificando contas Meta vinculadas pela Zernio…';
      metaCard.append(status);
      try{
        const rows=await q(sb.from('conexao_contas')
          .select('id_externo,nome,sincronizar,extras,conexoes!inner(plataforma)')
          .eq('workspace_id',ws).eq('tipo','meta_ads').eq('conexoes.plataforma','zernio'));
        if(S.ws!==ws||S.view!=='cfg-integracoes'||!metaCard.isConnected)return;
        const ativas=rows.filter(x=>!x.extras?.growths_desconectado_em);
        const escolhidas=ativas.flatMap(x=>x.extras?.adAccountIds||[]);
        const pill=metaCard.querySelector('.pill');
        if(pill){pill.className='pill '+(escolhidas.length?'good':ativas.length?'warn':'neutral');pill.textContent=escolhidas.length?'Conectado':ativas.length?'Escolher contas':'Não conectado';}
        status.textContent=escolhidas.length?escolhidas.length+' conta(s) de anúncios Meta autorizadas.':ativas.length?'Login autorizado. Escolha quais contas deste cliente deseja usar.':'A conexão Meta usa a Zernio da Mathisa.';
        const buttons=metaCard.querySelector('[data-cxcon]')?.parentElement||metaCard.querySelector('.btn')?.parentElement;
        if(ativas.length){
          if(escolhidas.length){
            const sync=document.createElement('button');sync.className='btn pri sm';sync.textContent='Sincronizar Meta Ads';
            sync.onclick=e=>{e.stopPropagation();sync.disabled=true;
              act(async()=>{const r=await metaZernio(ws,'sincronizar');
                toast(r.erros?.length?'Sincronização parcial: '+r.erros.join(' | '):'Sincronizados '+r.registros+' registros Meta Ads.',!!r.erros?.length);
                if(S.ws===ws)render();
              }).finally(()=>{sync.disabled=false;});};
            buttons?.append(sync);
          }
          const selecionar=document.createElement('button');selecionar.className='btn sm';selecionar.textContent='Escolher contas';
          selecionar.onclick=e=>{e.stopPropagation();act(async()=>{const r=await metaZernio(ws,'contas');await escolherMetaZernio(ws,r.contas);});};
          buttons?.append(selecionar);
          const desconectar=document.createElement('button');desconectar.className='btn sm bad';desconectar.textContent='Desconectar';
          desconectar.onclick=e=>{e.stopPropagation();if(!confirm('Desconectar Meta deste cliente? O histórico será preservado e a autorização seguirá ativa na Zernio até revogação por lá.'))return;
            act(async()=>{for(const a of ativas)await metaZernio(ws,'desconectar',{zernio_account_id:a.id_externo});toast('Meta desconectada do Growth V2.');render();});};
          buttons?.append(desconectar);
        }
      }catch(e){if(metaCard.isConnected)status.textContent='Não foi possível consultar o estado Meta.';}
      try{
        const permission=await q(sb.rpc('zernio_oauth_permitido',{p_ws:ws}));
        if(!permission && metaCard.isConnected)metaCard.querySelectorAll('button').forEach(b=>b.remove());
      }catch(e){metaCard.querySelectorAll('button').forEach(b=>b.remove());}
    }
    const instagram=substituirAcao('Instagram','Conectar Instagram',()=>conectarInstagram(ws),true);
    const whatsapp=substituirAcao('WhatsApp API oficial','Vincular WhatsApp oficial',()=>act(()=>conectarZernio(ws)),true);
    substituirAcao('WhatsApp (grupos e API)','Configurar Evolution API',()=>act(configurarEvolution),true);
    // O status do Instagram deve refletir a conta realmente vinculada, não um registro manual.
    if(instagram){
      const conta=document.createElement('small');
      conta.className='muted';conta.textContent='Conferindo conta Instagram vinculada…';
      instagram.card.insertBefore(conta,instagram.botao.parentElement);
      try{
        const rows=await q(sb.from('conexao_contas')
          .select('nome,id_externo,conexoes!inner(plataforma)')
          .eq('workspace_id',ws).eq('tipo','instagram')
          .eq('conexoes.plataforma','zernio'));
        if(S.ws!==ws||S.view!=='cfg-integracoes'||!instagram.card.isConnected)return;
        const nomes=rows.map(c=>c.nome||c.id_externo);
        const pill=instagram.card.querySelector('.pill');
        if(pill){pill.className='pill '+(nomes.length?'good':'neutral');pill.textContent=nomes.length?'Conectado':'Não conectado';}
        conta.textContent=nomes.length?'Contas: '+nomes.join(' · '):'Nenhuma conta Instagram conectada neste cliente.';
        instagram.botao.textContent=nomes.length?'Conectar outra conta Instagram':'Conectar Instagram';
      }catch(e){
        if(S.ws===ws&&instagram.card.isConnected)conta.textContent='Não foi possível consultar as contas conectadas.';
      }
    }
    if(S.ws!==ws||S.view!=='cfg-integracoes')return;
    try{
      const [permiteOAuth,interna]=await Promise.all([
        q(sb.rpc('zernio_oauth_permitido',{p_ws:ws})),
        q(sb.rpc('sou_equipe_interna'))
      ]);
      if(S.ws!==ws||S.view!=='cfg-integracoes')return;
      if(!permiteOAuth)instagram?.botao.remove();
      if(!permiteOAuth||!interna)whatsapp?.botao.remove();
    }catch(e){
      // Falha em verificar permissão: não disponibilizar uma ação privilegiada.
      instagram?.botao.remove();whatsapp?.botao.remove();
    }
  };
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&S.view==='atd-conversas')refreshCurrent(A.token);});
})();
