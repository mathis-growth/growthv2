/* Central de Atendimento: módulo isolado para diminuir conflitos no index.html.
   Nunca guarda credenciais, mensagens ou anexos no localStorage. */
(() => {
  'use strict';
  const LABELS = {whatsapp:'WhatsApp',instagram:'Instagram',telegram:'Telegram',tiktok:'TikTok'};
  const A = {ws:null,sel:null,lista:[],canais:[],ctx:null,token:0,chatToken:0,drafts:new Map(),busca:'',canal:'',tipo:'',status:'',minhas:'',page:0,cursor:null,loaded:[],subscription:null,timer:null,listaCompacta:false};
  let recorder=null, recorderStream=null, recordedFile=null, recordingTimer=null;
  const mediaSigned=new Map();
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
  // A faixa superior é compacta; detalhes QR Code/API permanecem disponíveis nos filtros e canais.
  const textoFaixaCanal = ch => ch.canal==='whatsapp'
    ? 'WhatsApp - '+(ch.numero?String(ch.numero).replace(/\D/g,''):'não identificado')
    : nomeCanal(ch)+' · '+identidadeCanal(ch);
  const faixaCanal = ch => `<span class="atd-faixa atd-faixa--${tipoCanal(ch)}" title="${esc(textoFaixaCanal(ch))}">${esc(textoFaixaCanal(ch))}</span>`;

  const MIME_IMAGE=/^image\/(?:jpeg|png|webp)$/;
  const MIME_AUDIO=/^audio\/(?:ogg|mpeg|mp4|webm|wav|x-wav)$/;
  const MIME_VIDEO=/^video\/mp4$/;
  const kindOf=a=>{const mime=String(a.mime||'').split(';')[0].toLowerCase();
    return MIME_IMAGE.test(mime)?'image':MIME_AUDIO.test(mime)?'audio':MIME_VIDEO.test(mime)?'video':'file';};
  const mediaKey=(msg,i)=>msg+':'+i;
  const arquivoNome=(a)=>String(a.nome||'Anexo').slice(0,150);
  const mediaMarkup=(msg,a,i)=>{
    const key=mediaKey(msg.id,i),mime=kindOf(a);
    if(a.pendente)return `<button class="btn sm" data-midia="${msg.id}" data-index="${i}" data-pendente="1">↻ Recuperar ${esc(arquivoNome(a))}</button>`;
    if(!a.path)return `<span class="muted">Mídia indisponível</span>`;
    const common=`data-media-key="${esc(key)}" data-midia="${msg.id}" data-index="${i}"`;
    if(mime==='image')return `<button class="atd-media-image" ${common} aria-label="Ampliar imagem" title="${esc(arquivoNome(a))}"><span class="atd-media-placeholder">Carregando imagem…</span></button>`;
    if(mime==='audio')return `<div class="atd-media-audio"><audio controls preload="none" aria-label="Reproduzir áudio" ${common}></audio><button class="btn sm atd-baixar" data-midia="${msg.id}" data-index="${i}" aria-label="Baixar áudio">↓</button></div>`;
    if(mime==='video')return `<video controls playsinline preload="none" class="atd-media-video" ${common}></video>`;
    return `<button class="btn sm atd-baixar" data-midia="${msg.id}" data-index="${i}">↓ ${esc(arquivoNome(a))}</button>`;
  };
  async function api(action,body={},ws=A.ws || S.ws) {
    const {data,error} = await sb.functions.invoke('atendimento',{body:{action,workspace_id:ws,...body}});
    if(error) { let msg; try { msg=(await error.context.json()).erro; } catch {} throw new Error(msg || 'Atendimento indisponível. Confira a publicação da função e sua conexão.'); }
    if(data?.erro) throw new Error(data.erro); return data;
  }
  function stopRecording(discard=true){
    if(recordingTimer){clearInterval(recordingTimer);recordingTimer=null;}
    if(recorder&&recorder.state!=='inactive') {recorder.onstop=null;recorder.stop();}
    recorderStream?.getTracks().forEach(track=>track.stop());
    recorderStream=null;recorder=null;
    if(discard)recordedFile=null;
  }
  function stop() { stopRecording();mediaSigned.clear();clearInterval(A.timer); A.timer=null; if(A.subscription) { sb.removeChannel(A.subscription); A.subscription=null; } }
  const active = token => token===A.token && S.ws===A.ws && S.view==='atd-conversas';
  function draftKey(cv) { return A.ws+':'+cv; }
  async function vAtendimento(m) {
    stop(); const token=++A.token;
    m.classList.add('atd-conversas-page');
    document.querySelector('.shell')?.classList.add('atd-shell-fixed');
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
      m.querySelector('#atdRoot').outerHTML=`<div id="atdRoot" class="atd-layout${A.sel?' selecionada':''}${A.listaCompacta?' lista-compacta':''}"><aside class="atd-lista"><div class="atd-lista-controle"><b>Conversas</b><button type="button" class="btn sm" id="atdCompactar" aria-label="Reduzir lista de conversas" title="Reduzir lista">‹</button></div><div class="atd-filtros"><input id="atdBusca" aria-label="Buscar conversa" placeholder="Nome ou número…" value="${esc(A.busca)}"><select id="atdFiltroCanal" aria-label="Canal"><option value="">Todos os canais e números</option>${canais.map(c=>`<option value="${c.id}"${A.canal===c.id?' selected':''}>${esc(nomeCanal(c)+' · '+identidadeCanal(c))}</option>`).join('')}</select><div class="atd-dupla"><select id="atdTipo" aria-label="Tipo"><option value="">Pessoas e grupos</option><option value="pessoa">Pessoas</option><option value="grupo">Grupos</option></select><select id="atdStatus" aria-label="Situação"><option value="">Todas as situações</option><option value="aberta">Abertas</option><option value="aguardando">Aguardando</option><option value="resolvida">Resolvidas</option></select></div><select id="atdMinhas" aria-label="Responsável"><option value="">Todos os responsáveis</option><option value="minhas">Minhas conversas</option><option value="sem">Sem responsável</option><option value="nao-lidas">Não lidas</option></select></div><div id="atdLista"></div><button class="btn sm" id="atdMais">Carregar mais conversas</button></aside><section class="atd-chat" id="atdChat"><div class="atd-vazio">Selecione uma conversa.<br>Conecte um canal para começar.</div></section><aside class="atd-ficha" id="atdFicha"><div class="atd-vazio">O cadastro do cliente aparece aqui.</div></aside></div>`;
      const filtros=m.querySelector('#atdRoot .atd-filtros'),barra=document.createElement('div');barra.className='atd-conversas-toolbar';barra.setAttribute('aria-label','Buscar e filtrar conversas');barra.append(filtros);m.querySelector('#atdRoot').before(barra);barra.hidden=A.listaCompacta;
      m.querySelector('#atdCompactar').onclick=()=>{A.listaCompacta=!A.listaCompacta;$('#atdRoot').classList.toggle('lista-compacta',A.listaCompacta);m.querySelector('.atd-conversas-toolbar').hidden=A.listaCompacta;const b=$('#atdCompactar');b.textContent=A.listaCompacta?'›':'‹';b.title=A.listaCompacta?'Expandir lista':'Reduzir lista';b.setAttribute('aria-label',b.title+' de conversas');};
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
    const visibleArchived=A.canais.filter(c=>c.exibir_grupos_arquivados).map(c=>c.id);
    if(visibleArchived.length)query=query.or('arquivada.eq.false,canal_id.in.('+visibleArchived.join(',')+')');
    else query=query.eq('arquivada',false);
    if(A.tipo) query=query.eq('grupo',A.tipo==='grupo');
    if(A.status) query=query.eq('status',A.status);
    if(A.minhas==='minhas') query=query.eq('responsavel_id',A.ctx.user_id);
    if(A.minhas==='sem') query=query.is('responsavel_id',null);
    if(A.minhas==='nao-lidas') query=query.gt('nao_lidas',0);
    const term=A.busca.replace(/[^\p{L}\p{N}\s+@.-]/gu,'').trim();
    if(term) query=query.or('nome.ilike.%'+term+'%,endereco.ilike.%'+term+'%');
    const rows=await q(query); if(!active(token)||sequence!==A.listSeq) return;
    A.lista=more?[...A.lista,...rows]:rows;
    const list=$('#atdLista'),desired=A.lista.map(c=>{const ch=A.canais.find(x=>x.id===c.canal_id)||{},sig=JSON.stringify([c.id,c.nome,c.ultima_mensagem,c.ultima_em,c.status,c.nao_lidas,c.grupo,c.grupo_membros,c.avatar_path,A.sel===c.id,ch.canal,ch.provedor,ch.nome,ch.numero]);return {id:c.id,sig,html:`<button class="atd-item atd-item--${tipoCanal(ch)}${A.sel===c.id?' on':''}" title="${esc(c.nome+' · '+textoFaixaCanal(ch))}" data-conversa="${c.id}" data-render-sig="${esc(sig)}"><span class="atd-card-top">${faixaCanal(ch)}</span><span class="atd-card-body">${c.nao_lidas?`<span class="atd-count">${c.nao_lidas}</span>`:''}<span class="atd-avatar" data-avatar-id="${c.id}">${c.grupo?'♟':esc(c.nome.slice(0,1).toUpperCase())}</span><b>${esc(c.nome)}</b>${c.grupo?`<small>${c.grupo_membros!=null?esc(c.grupo_membros)+' membros':'Grupo'}</small>`:''}<small>${esc(c.ultima_mensagem||'Histórico disponível para importar')}</small><small>${fmt(c.ultima_em)} · ${esc(c.status)}</small></span></button>`};});
    if(!desired.length){if(!list.querySelector('.atd-vazio'))list.innerHTML='<div class="atd-vazio">Nenhuma conversa com estes filtros.</div>';}
    else{list.querySelector('.atd-vazio')?.remove();const prior=new Map([...list.querySelectorAll('[data-conversa]')].map(node=>[node.dataset.conversa,node]));let cursor=list.firstElementChild;for(const item of desired){let node=prior.get(item.id);if(node&&node.dataset.renderSig!==item.sig){const previous=node,wrap=document.createElement('div');wrap.innerHTML=item.html;node=wrap.firstElementChild;previous.replaceWith(node);if(cursor===previous)cursor=node;}else if(!node){const wrap=document.createElement('div');wrap.innerHTML=item.html;node=wrap.firstElementChild;}if(node!==cursor)list.insertBefore(node,cursor);cursor=node.nextElementSibling;prior.delete(item.id);}for(const node of prior.values())node.remove();}
    // URLs temporárias de perfil; só revela o que pertence ao workspace.
    const targets=A.lista.filter(cv=>cv.avatar_path).slice(0,35);
    if(targets.length)api('avatars',{ids:targets.map(x=>x.id)},A.ws).then(({avatares})=>{
      if(!active(token)||sequence!==A.listSeq)return;
      for(const cv of targets){
        const url=avatares?.[cv.id];
        if(!url)continue;
        const el=[...$('#atdLista').querySelectorAll('[data-avatar-id]')].find(x=>x.dataset.avatarId===cv.id);
        if(!el)continue;
        const fallback=el.textContent;
        const img=document.createElement('img');img.src=url;img.alt='';img.loading='lazy';
        img.onerror=()=>{if(!img.isConnected)return;img.remove();el.textContent=fallback;};
        el.replaceChildren(img);
      }
    }).catch(()=>{});
    $('#atdMais').hidden=rows.length<(more?50:(A.page+1)*50);
    $('#atdLista').onclick=e=>{const b=e.target.closest('[data-conversa]');if(b)act(()=>openChat(b.dataset.conversa,token));};
  }
  async function openChat(id,token) {
    stopRecording();mediaSigned.clear();
    const generation=++A.chatToken; A.sel=id;A.cursor=null;A.loaded=[];
    const ws=A.ws;
    const cv=await q(sb.from('atd_conversas').select('*').eq('workspace_id',ws).eq('id',id).single());
    const contato=(await api('contato-resumo',{conversa_id:id},ws).catch(()=>({pessoa:null}))).pessoa;
    if(!active(token)||generation!==A.chatToken) return;
    if(contato)cv.pessoa_id=contato.id;
    const ch=A.canais.find(c=>c.id===cv.canal_id)||{}, draft=A.drafts.get(draftKey(id))||'';
    const aguardaTemplate=ch.provedor==='zernio'&&String(cv.externo_id||'').startsWith('pending:');
    const podeEnviar=A.ctx.editar&&!aguardaTemplate;
    const resumoContato=contato?`<div class="atd-contato-resumo"><span class="atd-resumo-tipo">${esc(contato.tipo)}</span>${contato.produto?`<span><b>Produto</b>${esc(contato.produto)}</span>`:''}${contato.campanha?`<span><b>Campanha / lançamento</b>${esc(contato.campanha)}</span>`:''}<span><b>Data de captura</b>${contato.capturado_em?new Date(contato.capturado_em).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):'—'}</span></div>`:'';
    $('#atdRoot').classList.add('selecionada');$('#atdRoot').classList.remove('ficha');
    $('#atdChat').innerHTML=`<header class="atd-top"><div class="atd-chat-identidade">${cv.grupo?`<span class="atd-avatar atd-chat-avatar" data-chat-avatar="${cv.id}">♟</span>`:''}<div><button class="btn sm atd-mobile" id="atdVoltar">← Conversas</button><strong>${esc(cv.nome)}</strong>${cv.grupo&&ch.provedor==='evolution'?` <button class="btn sm" id="atdArquivarGrupo">${cv.arquivada?'Desarquivar grupo':'Arquivar grupo'}</button>`:''}<div class="atd-identificacao">${faixaCanal(ch)}${cv.grupo?`<small>${cv.grupo_membros!=null?esc(cv.grupo_membros)+' membros':'Grupo'}</small>`:''}</div></div></div>${aguardaTemplate?'<p class="muted">Sessão criada · aguardando o primeiro envio por template aprovado.</p>':''}${resumoContato}<div><select id="atdSituacao" aria-label="Situação da conversa" ${A.ctx.editar?'':'disabled'}>${['aberta','aguardando','resolvida'].map(s=>`<option value="${s}"${cv.status===s?' selected':''}>${s==='aberta'?'Aberta':s==='aguardando'?'Aguardando':'Resolvida'}</option>`).join('')}</select> <button class="btn sm atd-mobile" id="atdVerFicha">Ficha</button></div></header><div class="atd-msgs" id="atdMensagens"></div><form class="atd-compose" id="atdCompose"><div class="atd-dupla"><select id="atdModo" aria-label="Tipo de mensagem"><option value="enviar">Mensagem</option><option value="nota">Nota interna</option></select><button type="button" class="btn sm" id="atdHistorico">Importar histórico</button></div><textarea id="atdTexto" aria-label="Mensagem" maxlength="4000" placeholder="Escreva sua mensagem…" ${A.ctx.editar&&!aguardaTemplate?'':'disabled'}>${esc(draft)}</textarea><div class="atd-arquivo" id="atdArquivoNome"></div><div class="atd-gravacao" id="atdGravacao" aria-live="polite"></div><footer><label class="btn sm">Anexar<input type="file" id="atdArquivo" class="atd-hidden" accept="image/jpeg,image/png,image/webp,video/mp4,audio/ogg,audio/mpeg,audio/mp4,audio/webm,audio/wav,application/pdf" ${podeEnviar?'':'disabled'}></label><button type="button" class="btn sm" id="atdGravar" ${podeEnviar?'':'disabled'} aria-label="Gravar áudio pelo microfone">🎤 Gravar áudio</button><small class="muted">${A.ctx.nome?'Assinado por '+esc(A.ctx.nome):'Cadastre seu nome na equipe para enviar.'}</small><button class="btn pri" id="atdEnviar" ${podeEnviar?'':'disabled'}>Enviar</button></footer></form>`;
    if(cv.grupo&&cv.avatar_path)api('avatars',{ids:[cv.id]},ws).then(({avatares})=>{if(!active(token)||generation!==A.chatToken)return;const el=$('#atdChat [data-chat-avatar]'),url=avatares?.[cv.id];if(!el||!url)return;const img=document.createElement('img');img.src=url;img.alt='';img.onerror=()=>img.remove();el.replaceChildren(img);}).catch(()=>{});
    $('#atdModo').insertAdjacentHTML('afterend','<button type="button" class="btn sm" id="atdRapidas">⚡ Respostas rápidas</button>'+(ch.canal==='whatsapp'&&ch.provedor==='zernio'&&A.ctx.editar?' <button type="button" class="btn sm" id="atdEnviarTemplate">▤ Enviar template</button>':'')+' <button type="button" class="btn sm" id="atdAgendar">🕒 Agendar envio</button> <button type="button" class="btn sm" id="atdVerAgendados">Agendamentos</button>');
    $('#atdAgendar').disabled=!podeEnviar;
    $('#atdCompose').insertAdjacentHTML('beforebegin','<div id="atdAgendaLista" class="atd-agenda-lista" hidden></div>');
    $('#atdArquivarGrupo')?.addEventListener('click',()=>act(async()=>{
      await api('arquivar-grupo',{conversa_id:id,arquivar:!cv.arquivada},ws);
      toast(cv.arquivada?'Grupo desarquivado.':'Grupo arquivado no Growth V2.');
      if(!cv.arquivada&&!ch.exibir_grupos_arquivados){
        A.sel=null;
        await render();
        return;
      }
      await openChat(id,token);
      await refresh(token);
    }));
    $('#atdVoltar').onclick=()=>$('#atdRoot').classList.remove('selecionada');
    $('#atdVerFicha').onclick=()=>$('#atdRoot').classList.toggle('ficha');
    $('#atdSituacao').onchange=e=>act(()=>api('atualizar',{conversa_id:id,status:e.target.value},ws));
    $('#atdTexto').oninput=e=>A.drafts.set(draftKey(id),e.target.value);
    $('#atdModo').onchange=e=>{$('#atdEnviar').textContent=e.target.value==='nota'?'Salvar nota':'Enviar';};
    $('#atdArquivo').onchange=e=>{const f=e.target.files[0];if(f?.size>8*1024*1024){toast('Limite de 8 MB por anexo.',true);e.target.value='';}if(f)recordedFile=null;$('#atdArquivoNome').textContent=e.target.files[0]?.name||'';};
    const recordingStatus=$('#atdGravacao'), recordingBtn=$('#atdGravar');
    recordingBtn.onclick=async()=>{
      if(recorder&&recorder.state==='recording'){recorder.stop();return;}
      if(!navigator.mediaDevices?.getUserMedia||!window.MediaRecorder){toast('Microfone indisponível neste navegador.',true);return;}
      try{
        recordedFile=null;
        recorderStream=await navigator.mediaDevices.getUserMedia({audio:true});
        if(!active(token)||A.sel!==id){stopRecording();return;}
        const supported=['audio/ogg;codecs=opus','audio/webm;codecs=opus','audio/mp4','audio/webm'].find(t=>MediaRecorder.isTypeSupported(t));
        recorder=new MediaRecorder(recorderStream,supported?{mimeType:supported}:undefined);
        const chunks=[],started=Date.now();let total=0;
        recorder.ondataavailable=e=>{if(e.data?.size){chunks.push(e.data);total+=e.data.size;if(total>8*1024*1024&&recorder?.state==='recording'){toast('Áudio excedeu 8 MB. Gravação interrompida.',true);recorder.stop();}}};
        recorder.onstop=()=>{
          clearInterval(recordingTimer);recordingTimer=null;
          recorderStream?.getTracks().forEach(t=>t.stop());recorderStream=null;
          const type=String(recorder?.mimeType||supported||'audio/webm').split(';')[0];
          recorder=null;recordingBtn.textContent='🎤 Gravar áudio';
          if(total>8*1024*1024){recordedFile=null;recordingStatus.textContent='Áudio descartado: limite de 8 MB.';return;}
          const blob=new Blob(chunks,{type});
          if(blob.size&&active(token)&&A.sel===id){
            const ext=type.includes('ogg')?'ogg':type.includes('mp4')?'m4a':'webm';
            recordedFile=new File([blob],'gravacao.'+ext,{type});
            recordingStatus.innerHTML='<span>Áudio gravado · '+Math.ceil((Date.now()-started)/1000)+'s</span> <button type="button" class="btn sm" id="atdDescartarAudio">Descartar</button>';
            recordingStatus.querySelector('#atdDescartarAudio').onclick=()=>{recordedFile=null;recordingStatus.textContent='';};
          }
        };
        recorder.start(250);
        recordingBtn.textContent='■ Parar gravação';
        recordingStatus.textContent='● Gravando…';
        recordingTimer=setInterval(()=>{if(recorder?.state==='recording')recordingStatus.textContent='● Gravando '+Math.floor((Date.now()-started)/1000)+'s';},1000);
      }catch(e){stopRecording();toast('Não foi possível acessar o microfone. Verifique a permissão no navegador.',true);}
    };
    $('#atdHistorico').onclick=()=>act(async()=>{const b=$('#atdHistorico');b.disabled=true;try {const r=await api('historico',{conversa_id:id,cursor:A.cursor},ws);A.cursor=r.cursor;if(active(token)&&A.sel===id){b.textContent=r.cursor?'Importar mais histórico':'Atualizar histórico';await messages(id,token);toast(r.total+' mensagens consultadas.');}}finally{if(b.isConnected)b.disabled=false;}});
    // Inserção no rascunho: o atendente revisa antes de enviar.
    $('#atdRapidas')?.addEventListener('click',()=>act(async()=>{
      const {respostas}=await api('rapidas-list',{},ws);
      if(!respostas.length){toast('Cadastre respostas rápidas em Atendimento → Templates.',true);return;}
      const form=modal('Inserir resposta rápida',`<label>Resposta<select name="resposta">${respostas.map(r=>`<option value="${r.id}">/${esc(r.atalho)} · ${esc(r.titulo)}</option>`).join('')}</select></label>`,async d=>{
        const item=respostas.find(r=>r.id===d.resposta);
        if(!item||!active(token)||A.sel!==id)return;
        const area=$('#atdTexto');area.value=[area.value.trim(),item.texto].filter(Boolean).join('\n\n');
        A.drafts.set(draftKey(id),area.value);area.focus();
      },'Inserir no texto');
    }));
    $('#atdEnviarTemplate')?.addEventListener('click',()=>act(async()=>{
      const {templates=[]}=await api('templates-list',{canal_id:ch.id},ws);
      const camposPersonalizados=await q(sb.from('campos_personalizados').select('chave,rotulo').eq('workspace_id',ws).eq('entidade','pessoas').order('rotulo')).catch(()=>[]);
      const camposContato=[
        ['nome','Nome'],['telefone','Telefone'],['email','E-mail'],['tipo','Tipo de contato'],
        ['produto','Produto'],['campanha','Campanha / lançamento'],['capturado_em','Data de captura'],
        ['status_funil','Status do funil'],['status_cliente','Status do cliente'],['qualificacao','Qualificação'],
        ['canal_origem','Canal de origem'],['utm_source','UTM · Fonte'],['utm_medium','UTM · Mídia'],
        ['utm_campaign','UTM · Campanha'],['utm_content','UTM · Conteúdo'],['utm_term','UTM · Termo'],['pagina_origem','Página de entrada']
      ].map(([chave,label])=>({chave,label,valor:chave==='capturado_em'&&contato?.[chave]?new Date(contato[chave]).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):contato?.[chave]}));
      const primeiroNome=String(contato?.nome||'').trim().split(/\s+/)[0];
      if(primeiroNome)camposContato.unshift({chave:'primeiro_nome',label:'Primeiro nome',valor:primeiroNome});
      for(const campo of camposPersonalizados)camposContato.push({chave:'extras.'+campo.chave,label:campo.rotulo,valor:contato?.extras?.[campo.chave]});
      const variaveisContato=camposContato.filter(c=>c.valor!==null&&c.valor!==undefined&&String(c.valor).trim()!=='');
      const supported=t=>(t.components||[]).every(c=>{
        const type=String(c.type||'').toUpperCase();
        if(type==='HEADER')return ['TEXT','IMAGE','VIDEO','DOCUMENT'].includes(String(c.format||'TEXT').toUpperCase());
        if(type==='BODY'||type==='FOOTER')return true;
        if(type==='BUTTONS')return (c.buttons||[]).every(b=>['QUICK_REPLY','URL','PHONE_NUMBER','COPY_CODE','FLOW'].includes(String(b.type||'').toUpperCase()));
        return false;
      });
      const aprovados=templates.filter(t=>t.status==='APPROVED'&&t.name&&t.language&&supported(t));
      if(!aprovados.length){toast('Não há templates aprovados para esta conta Zernio.',true);return;}
      const options=aprovados.map((t,i)=>`<option value="${i}">${esc(t.name)} · ${esc(t.language)}</option>`).join('');
      const templateParts=t=>{const parts=t.components||[];return {header:parts.find(c=>String(c.type).toUpperCase()==='HEADER'),body:parts.find(c=>String(c.type).toUpperCase()==='BODY'),footer:parts.find(c=>String(c.type).toUpperCase()==='FOOTER'),buttons:parts.find(c=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[]};};
      const slotsFor=t=>{const p=templateParts(t),out=[];const add=(text,label)=>{const matches=[...String(text||'').matchAll(/\{\{(\d+)\}\}/g)],nums=[...new Set(matches.map(m=>Number(m[1])))].sort((a,b)=>a-b);nums.forEach(n=>out.push({label:`${label} · variável {{${n}}}`,marker:n,component:label}));};
        if(String(p.header?.format||'TEXT').toUpperCase()==='TEXT')add(p.header?.text,'Cabeçalho');add(p.body?.text,'Corpo');p.buttons.forEach((b,i)=>{if(String(b.type).toUpperCase()==='URL')add(b.url,`Botão ${i+1} · link`);});return out;};
      const nomeBotao=b=>({QUICK_REPLY:'Resposta rápida',URL:'Link',PHONE_NUMBER:'Telefone',COPY_CODE:'Copiar código',FLOW:'Abrir formulário'}[String(b.type||'').toUpperCase()]||b.type||'Botão');
      const form=modal('Enviar template WhatsApp',`<p class="muted">Selecione um template aprovado. Para cada variável, escolha um dado do contato ou informe um valor manual. Cabeçalho e rodapé seguem o modelo aprovado; a mídia pode ser trocada neste envio.</p><label>Template aprovado<select name="modelo">${options}</select></label><div id="atdTemplateDetails"></div><div id="atdTemplateVars"></div><div id="atdTemplateButtonVars"></div><div id="atdTemplatePreview" class="atd-template-preview"></div>`,async(d,f)=>{
        const t=aprovados[Number(d.modelo)];if(!t)throw Error('Selecione um template válido.');
        const inputs=[...f.querySelectorAll('[data-template-param]')].sort((a,b)=>Number(a.dataset.templateParam)-Number(b.dataset.templateParam)).map(x=>x.value.trim());
        if(inputs.some(x=>!x))throw Error('Preencha todas as variáveis do cabeçalho, corpo e links.');
        const buttonParams=[...f.querySelectorAll('[data-template-button-param]')].map(x=>({index:Number(x.dataset.index),subType:x.dataset.subtype,value:x.value.trim()}));
        if(buttonParams.some(x=>!x.value))throw Error('Preencha os valores dos botões que pedem dados no envio.');
        const mode=f.elements.headerMediaMode?.value||'link',mediaValue=String(f.elements.headerMediaValue?.value||'').trim();
        const headerMedia=mediaValue?{type:String(templateParts(t).header.format).toLowerCase(),[mode]:mediaValue}:null;
        await api('templates-send',{canal_id:ch.id,conversa_id:id,template_name:t.name,idioma:t.language,parametros:inputs,header_media:headerMedia,button_params:buttonParams,requisicao_id:crypto.randomUUID()},ws);
        if(active(token)&&A.sel===id)await openChat(id,token);
        toast('Template enviado.');
      },'Enviar template',true);
      const draw=()=>{
        const t=aprovados[Number(form.elements.modelo.value)],parts=templateParts(t),slots=slotsFor(t),headerFormat=String(parts.header?.format||'TEXT').toUpperCase();
        let fields='';slots.forEach((s,i)=>{fields+=`<div class="atd-template-variable"><label>${esc(s.label)}<input data-template-param="${i}" required maxlength="1024" placeholder="Escolha um campo ou digite um valor"></label>${variaveisContato.length?`<label>Preencher com dado do contato<select data-template-contact="${i}"><option value="">Escolher campo…</option>${variaveisContato.map((c,n)=>`<option value="${n}">${esc(c.label)} · ${esc(String(c.valor))}</option>`).join('')}</select></label>`:''}</div>`;});
        form.querySelector('#atdTemplateVars').innerHTML=fields||'<p class="muted">Este template não tem variáveis de texto.</p>';
        form.querySelectorAll('[data-template-contact]').forEach(select=>select.onchange=()=>{const field=variaveisContato[Number(select.value)],input=form.querySelector(`[data-template-param="${select.dataset.templateContact}"]`);if(field&&input){input.value=String(field.valor);input.dispatchEvent(new Event('input',{bubbles:true}));}});
        const media=['IMAGE','VIDEO','DOCUMENT'].includes(headerFormat)?`<fieldset class="atd-tpl-section"><legend>${headerFormat==='IMAGE'?'Cabeçalho com imagem':headerFormat==='VIDEO'?'Cabeçalho com vídeo':'Cabeçalho com documento'}</legend><label>Tipo da referência<select name="headerMediaMode"><option value="link">URL HTTPS pública</option><option value="id">ID de mídia da Meta</option></select></label><label>${aguardaTemplate?'Substituir mídia de exemplo (opcional)':'URL ou ID da mídia deste envio'}<input name="headerMediaValue" ${aguardaTemplate?'':'required'} placeholder="${headerFormat==='IMAGE'?'https://site.com/imagem.jpg ou ID Meta':headerFormat==='VIDEO'?'https://site.com/video.mp4 ou ID Meta':'https://site.com/arquivo.pdf ou ID Meta'}"></label><small>${aguardaTemplate?'Deixe vazio para usar a mídia de exemplo aprovada.':'Para uma conversa existente, informe a mídia que será enviada neste cabeçalho.'}</small></fieldset>`:'';
        form.querySelector('#atdTemplateDetails').innerHTML=`<dl class="atd-template-fields"><div><dt>Nome do template</dt><dd>${esc(t.name)}</dd></div><div><dt>Idioma</dt><dd>${esc(t.language)}</dd></div><div><dt>Cabeçalho aprovado</dt><dd>${parts.header?`${esc(headerFormat==='TEXT'?'Texto':headerFormat==='IMAGE'?'Imagem':headerFormat==='VIDEO'?'Vídeo':'Documento')}${headerFormat==='TEXT'?` · ${esc(parts.header.text||'')}`:''}`:'Sem cabeçalho'}</dd></div><div class="wide"><dt>Mensagem aprovada</dt><dd class="pre">${esc(parts.body?.text||'—')}</dd></div>${parts.footer?`<div><dt>Rodapé</dt><dd>${esc(parts.footer.text||'—')}</dd></div>`:''}${parts.buttons.length?`<div class="wide"><dt>Botões aprovados</dt><dd>${parts.buttons.map((b,i)=>`${i+1}. ${esc(nomeBotao(b))} · ${esc(b.text||'')}${b.url?` · ${esc(b.url)}`:''}${b.phone_number?` · ${esc(b.phone_number)}`:''}`).join('<br>')}</dd></div>`:''}</dl>${media}`;
        const extraButtons=parts.buttons.map((b,index)=>{const type=String(b.type||'').toUpperCase(),subtype=type==='COPY_CODE'?'copy_code':type==='FLOW'?'flow':'';if(!subtype)return '';return `<label>Botão ${index+1} · ${esc(nomeBotao(b))}<input data-template-button-param="1" data-index="${index}" data-subtype="${subtype}" required placeholder="Informe ${subtype==='flow'?'o token do formulário':'o código do cupom'}"></label>`;}).join('');
        form.querySelector('#atdTemplateButtonVars').innerHTML=extraButtons||'';
        const updatePreview=()=>{
          let text=parts.body?.text||'Este template não possui texto de corpo.',header=String(parts.header?.text||'');
          [...form.querySelectorAll('[data-template-param]')].forEach((el,i)=>{const slot=slots[i];if(slot.component==='Corpo')text=text.replaceAll(`{{${slot.marker}}}`,el.value||`{{${slot.marker}}}`);if(slot.component==='Cabeçalho')header=header.replaceAll(`{{${slot.marker}}}`,el.value||`{{${slot.marker}}}`);});
          form.querySelector('#atdTemplatePreview').innerHTML=`<b>Prévia da mensagem</b>${header?`<p><b>Cabeçalho:</b> ${esc(header)}</p>`:''}<p>${esc(text)}</p>${parts.footer?`<small>Rodapé: ${esc(parts.footer.text)}</small>`:''}`;
        };
        updatePreview();form.querySelector('#atdTemplateVars').oninput=updatePreview;
      };
      form.elements.modelo.onchange=draw;draw();
    }));
    const agendaLista=$('#atdAgendaLista');
    const verAgendados=async()=>{
      const {agendamentos}=await api('agendamentos-list',{conversa_id:id},ws);
      if(!active(token)||A.sel!==id)return;
      agendaLista.hidden=false;
      agendaLista.innerHTML='<div class="atd-agenda-head"><b>Mensagens agendadas</b><button type="button" class="btn sm" id="atdFecharAgenda">Fechar</button></div>'+
        (agendamentos.length?agendamentos.map(j=>`<article class="atd-agenda-item"><small>${new Date(j.enviar_em).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'})} (Brasília) · ${esc(j.status)}</small><p>${esc(j.texto)}</p>${j.erro?`<small class="atd-erro">${esc(j.erro)}</small>`:''}${j.status==='agendado'?`<button type="button" class="btn sm bad" data-cancelar-agenda="${j.id}">Cancelar envio</button>`:''}</article>`).join(''):'<p class="muted">Nenhum envio agendado nesta conversa.</p>');
      $('#atdFecharAgenda').onclick=()=>agendaLista.hidden=true;
      agendaLista.onclick=e=>{const btn=e.target.closest('[data-cancelar-agenda]');if(btn)act(async()=>{
        if(!confirm('Cancelar esta mensagem agendada?'))return;
        await api('cancelar-agendamento',{agendamento_id:btn.dataset.cancelarAgenda},ws);
        toast('Agendamento cancelado.');await verAgendados();
      });};
    };
    $('#atdVerAgendados').onclick=()=>act(verAgendados);
    $('#atdAgendar').onclick=()=>{
      const texto=$('#atdTexto').value.trim(),modo=$('#atdModo').value;
      if(modo!=='enviar'){toast('Agendamento disponível apenas para mensagens, não notas internas.',true);return;}
      if(!texto){toast('Escreva a mensagem antes de agendar.',true);return;}
      if($('#atdArquivo').files.length||recordedFile){toast('Agendamento de anexos estará disponível em uma próxima etapa. Remova o anexo.',true);return;}
      const inicio=new Date(Date.now()+3600000).toLocaleString('sv-SE',{timeZone:'America/Sao_Paulo'}).replace(' ','T').slice(0,16);
      modal('Agendar mensagem',`<p style="white-space:pre-wrap">${esc(texto)}</p><label>Data e horário (Brasília)<input type="datetime-local" name="quando" required value="${inicio}"></label><p class="muted">O envio é processado automaticamente em até aproximadamente 1 minuto após o horário escolhido. Em WhatsApp oficial, a Meta pode exigir template aprovado fora da janela de atendimento de 24 horas.</p>`,async d=>{
        const data=String(d.quando||'');
        if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(data))throw Error('Data inválida.');
        const timestamp=new Date(data+':00-03:00');
        if(!Number.isFinite(timestamp.getTime()))throw Error('Horário inválido.');
        await api('agendar',{conversa_id:id,texto,enviar_em:timestamp.toISOString()},ws);
        A.drafts.delete(draftKey(id));toast('Mensagem agendada para '+timestamp.toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})+' (Brasília).');
        await messages(id,token,false);
      },'Confirmar agendamento');
    };
    $('#atdCompose').onsubmit=async e=>{
      e.preventDefault();const form=e.currentTarget,btn=form.querySelector('#atdEnviar');if(btn.disabled)return;
      const text=form.querySelector('#atdTexto').value.trim(),mode=form.querySelector('#atdModo').value,file=form.querySelector('#atdArquivo').files[0]||recordedFile;
      if(recorder?.state==='recording'){toast('Pare a gravação antes de enviar.',true);return;}
      if(!text&&!file){toast('Escreva uma mensagem, anexe uma imagem ou grave um áudio.',true);return;}
      if(mode==='nota'&&file){toast('Remova o anexo para salvar uma nota interna.',true);return;}
      btn.disabled=true;const rid=crypto.randomUUID();
      try{
        let arquivo;if(file){const base64=await new Promise((res,rej)=>{const r=new FileReader();r.onload=()=>res(String(r.result).split(',')[1]);r.onerror=rej;r.readAsDataURL(file);});arquivo={nome:file.name,mime:file.type,base64,gravado:file===recordedFile};}
        await api(mode,{conversa_id:id,texto:text,requisicao_id:rid,arquivo},ws);
        A.drafts.delete(ws+':'+id);if(active(token)&&A.sel===id){form.querySelector('#atdTexto').value='';form.querySelector('#atdArquivo').value='';$('#atdArquivoNome').textContent='';recordedFile=null;recordingStatus.textContent='';}
      }catch(err){toast(err.message,true);}finally{if(form.isConnected)btn.disabled=false;if(active(token)&&A.sel===id)await messages(id,token);}
    };
    await Promise.all([messages(id,token),ficha(cv,token,generation)]);
    if(active(token)&&A.sel===id&&A.ctx.editar&&cv.nao_lidas) await api('atualizar',{conversa_id:id,lida:true},ws);
  }
  async function messages(id,token,scroll=true,before) {
    const [r,agenda]=await Promise.all([api('mensagens',{conversa_id:id,before},A.ws),api('agendamentos-list',{conversa_id:id},A.ws)]);
    if(!active(token)||A.sel!==id) return;
    const box=$('#atdMensagens'); if(!box)return;
    const bottom=box.scrollHeight-box.scrollTop-box.clientHeight<80;
    // Não interromper áudio/vídeo em reprodução quando chegar atualização Realtime.
    const reproduzindo=[...box.querySelectorAll('audio,video')].some(media=>!media.paused&&!media.ended);
    if(reproduzindo && !before)return;
    A.loaded=[...A.loaded,...r.mensagens];
    const map=new Map(A.loaded.map(m=>[m.id,m]));A.loaded=[...map.values()].sort((a,b)=>a.em.localeCompare(b.em)||a.id.localeCompare(b.id));
    const agendaItems=(agenda.agendamentos||[]).filter(j=>j.status!=='enviado').map(j=>({kind:'agenda',id:j.id,em:j.enviar_em,item:j}));
    const timeline=[...A.loaded.map(m=>({kind:'mensagem',em:m.em,id:m.id,item:m})),...agendaItems].sort((a,b)=>a.em.localeCompare(b.em)||a.id.localeCompare(b.id));
    box.querySelector('.atd-vazio')?.remove();const older=r.mensagens.length===60,existing=new Map([...box.querySelectorAll('[data-timeline-key]')].map(node=>[node.dataset.timelineKey,node]));let oldButton=box.querySelector('#atdAntigas');if(older&&!oldButton){oldButton=document.createElement('button');oldButton.className='btn sm';oldButton.id='atdAntigas';oldButton.textContent='Mensagens anteriores';}if(!older){oldButton?.remove();oldButton=null;}if(oldButton&&box.firstElementChild!==oldButton)box.insertBefore(oldButton,box.firstElementChild);let position=oldButton?oldButton.nextElementSibling:box.firstElementChild;
    const nodes=timeline.map(x=>{const item=x.item,key=(x.kind==='agenda'?'agenda:':'mensagem:')+x.id,sig=JSON.stringify([x.kind,x.id,x.em,item.status,item.texto,item.autor_nome,item.participante,item.erro,item.anexos]),html=x.kind==='agenda'?`<article class="atd-agenda-chat atd-agenda-${esc(item.status)}" data-timeline-key="${esc(key)}" data-render-sig="${esc(sig)}"><header><b>◷ ${item.status==='agendado'?'AGENDADA · AINDA NÃO ENVIADA':item.status==='processando'?'ENVIO EM ANDAMENTO':item.status==='cancelado'?'AGENDAMENTO CANCELADO':item.status==='incerto'?'ENVIO SEM CONFIRMAÇÃO':'FALHA NO ENVIO'}</b><small>${new Date(item.enviar_em).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'})} · Brasília</small></header><p>${esc(item.texto)}</p>${item.erro?`<small class="atd-erro">${esc(item.erro)}</small>`:''}${item.status==='agendado'?`<button type="button" class="btn sm bad" data-cancelar-chat-agenda="${item.id}">Cancelar agendamento</button>`:''}</article>`:`<article class="atd-balao ${item.direcao}" data-timeline-key="${esc(key)}" data-render-sig="${esc(sig)}">${item.autor_nome?`<span class="atd-autor">${esc(item.autor_nome)}</span>`:item.participante?`<span class="atd-autor">${esc(item.participante)}</span>`:''}${textoMensagem(item)}${listOf(item.anexos).map((a,i)=>`<div class="atd-midia">${mediaMarkup(item,a,i)}</div>`).join('')}<small>${fmt(item.em)} · ${state[item.status]||esc(item.status)}</small>${item.erro?`<span class="atd-erro">${esc(item.erro)}</span>`:''}</article>`;return {key,sig,html};});
    if(!nodes.length){for(const node of existing.values())node.remove();if(!box.querySelector('.atd-vazio'))box.insertAdjacentHTML('beforeend','<div class="atd-vazio">Nenhuma mensagem salva ainda.<br>Use “Importar histórico” para consultar o canal.</div>');}
    else{for(const item of nodes){let node=existing.get(item.key);if(node&&node.dataset.renderSig!==item.sig){const previous=node,wrap=document.createElement('div');wrap.innerHTML=item.html;node=wrap.firstElementChild;previous.replaceWith(node);if(position===previous)position=node;}else if(!node){const wrap=document.createElement('div');wrap.innerHTML=item.html;node=wrap.firstElementChild;}if(node!==position)box.insertBefore(node,position);position=node.nextElementSibling;existing.delete(item.key);}for(const node of existing.values())node.remove();}
    // Carrega somente anexos visíveis: URLs assinadas são curtas e não expõem o bucket.
    const mediaElements=[...box.querySelectorAll('[data-media-key]')];
    const loadMedia=async el=>{
      const key=el.dataset.mediaKey;
      if(!el.isConnected||el.dataset.loaded==='1')return;
      el.dataset.loaded='1';
      try{
        let signed=mediaSigned.get(key);
        if(!signed||signed.exp<Date.now()){
          const result=await api('anexo',{mensagem_id:el.dataset.midia,indice:Number(el.dataset.index),visualizar:true},A.ws);
          signed={url:result.signedUrl,exp:Date.now()+240000};
          mediaSigned.set(key,signed);
        }
        if(!active(token)||A.sel!==id||!el.isConnected)return;
        if(el.matches('button.atd-media-image')){
          const img=document.createElement('img');img.src=signed.url;img.loading='lazy';img.alt=el.title||'Imagem enviada';
          img.onerror=()=>{if(el.isConnected)el.textContent='Imagem indisponível · tentar novamente';el.dataset.loaded='';mediaSigned.delete(key);};
          el.replaceChildren(img);el.dataset.preview=signed.url;
        }else if(el.matches('audio,video')){
          el.src=signed.url;
          el.load();
        }
      }catch(e){el.dataset.loaded='';if(el.matches('button'))el.textContent='Não foi possível carregar · tentar novamente';}
    };
    if('IntersectionObserver' in window){
      const observer=new IntersectionObserver((entries,obs)=>{
        for(const entry of entries)if(entry.isIntersecting){obs.unobserve(entry.target);loadMedia(entry.target);}
      },{root:box,rootMargin:'160px'});
      for(const el of mediaElements)observer.observe(el);
    }else mediaElements.forEach(loadMedia);

    if(scroll||bottom)box.scrollTop=box.scrollHeight;
    box.querySelector('#atdAntigas')?.addEventListener('click',()=>act(()=>messages(id,token,false,{em:A.loaded[0]?.em,id:A.loaded[0]?.id})));
    box.onclick=e=>{
      const cancel=e.target.closest('[data-cancelar-chat-agenda]');
      if(cancel){act(async()=>{if(!confirm('Cancelar esta mensagem agendada?'))return;await api('cancelar-agendamento',{agendamento_id:cancel.dataset.cancelarChatAgenda},A.ws);toast('Agendamento cancelado.');await messages(id,token,false);});return;}
      const b=e.target.closest('[data-midia]');if(!b)return;
      if(b.dataset.pendente==='1'){act(async()=>{await api('recuperar-midia',{mensagem_id:b.dataset.midia});mediaSigned.delete(mediaKey(b.dataset.midia,Number(b.dataset.index)));await messages(id,token,false);});return;}
      if(b.matches('button.atd-media-image')){
        const src=b.dataset.preview;if(!src){b.dataset.loaded='';return;}
        const modal=document.createElement('dialog');modal.className='atd-lightbox';
        modal.innerHTML='<button type="button" class="btn sm atd-lightbox-close">Fechar ✕</button><img alt="Imagem ampliada">';
        modal.querySelector('img').src=src;
        modal.querySelector('button').onclick=()=>modal.close();
        modal.onclick=ev=>{if(ev.target===modal)modal.close();};
        modal.onclose=()=>modal.remove();
        document.body.append(modal);modal.showModal();return;
      }
      if(b.matches('audio,video'))return;
      act(async()=>{
        const r=await api('anexo',{mensagem_id:b.dataset.midia,indice:Number(b.dataset.index)});
        const a=document.createElement('a');a.href=r.signedUrl;a.target='_blank';a.rel='noopener';a.click();
      });
    };
  }
  async function ficha(cv,token,generation) {
    const ws=A.ws, rows=await q(sb.from('equipe').select('nome,user_id').eq('workspace_id',ws).eq('ativo',true).not('user_id','is',null));
    let p=null,notes=[],sales=[],opps=[],actions=[];
    if(cv.pessoa_id) [p,notes,sales,opps,actions]=await Promise.all([
      q(sb.from('pessoas').select('*').eq('workspace_id',ws).eq('id',cv.pessoa_id).single()),
      q(sb.from('pessoa_notas').select('texto,criado_em').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).order('criado_em',{ascending:false}).limit(5)),
      q(sb.from('vendas').select('valor_bruto,status,data_venda').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).order('data_venda',{ascending:false}).limit(5)),
      q(sb.from('oportunidades').select('titulo,status').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).limit(10)),
      q(sb.from('atd_automacao_acoes').select('tipo,status,resumo,criado_em').eq('workspace_id',ws).eq('pessoa_id',cv.pessoa_id).order('criado_em',{ascending:false}).limit(8)).catch(()=>[]),
    ]);
    if(!active(token)||generation!==A.chatToken)return;
    $('#atdFicha').innerHTML=`<button class="btn sm atd-mobile" id="atdFichaVoltar">← Conversa</button><h3>${cv.grupo?'Grupo de WhatsApp':p?'Lead / Cliente':'Contato ainda não vinculado'}</h3><p><b>${esc(p?.nome||cv.nome)}</b><br>${esc(p?.telefone||cv.endereco||'')}<br>${esc(p?.email||'')}</p><label>Responsável<select id="atdResponsavel" ${A.ctx.editar?'':'disabled'}><option value="">Sem responsável</option>${rows.map(r=>`<option value="${r.user_id}"${cv.responsavel_id===r.user_id?' selected':''}>${esc(r.nome)}</option>`).join('')}</select></label>${cv.grupo?'<p class="muted">As mensagens identificam cada participante. O grupo não é vinculado a um único lead.</p>':p?`<p>${esc(p.status_funil)} · ${esc(p.qualificacao||'')}</p><div class="atd-ficha-tags">${(p.tags||[]).map(t=>`<span class="atd-contato-tag">${esc(t)}</span>`).join(' ')}</div><details><summary>Campos personalizados</summary>${Object.entries(p.extras||{}).map(([key,value])=>`<p><b>${esc(key)}</b>: ${esc(value)}</p>`).join('')||'<p>Nenhum campo preenchido.</p>'}</details><details open><summary>Automações recentes</summary>${actions.map(x=>`<p>${esc(x.resumo||x.tipo)} · ${esc(x.status)}<br><small>${fmt(x.criado_em)}</small></p>`).join('')||'<p>Nenhuma ação ainda.</p>'}</details><button class="btn" id="atdFichaCompleta">Abrir ficha completa</button><details open><summary>Oportunidades</summary>${opps.map(o=>`<div class="atd-ficha-oportunidade"><span>${esc(o.titulo)} · ${esc(o.status)}</span><button type="button" class="btn sm" data-atd-ver-negocio="${o.id}">Ver negócio</button></div>`).join('')||'<p>Nenhuma oportunidade.</p>'}</details><details><summary>Últimas compras</summary>${sales.map(v=>`<p>${brl(v.valor_bruto)} · ${esc(v.status)}<br>${esc(v.data_venda)}</p>`).join('')||'<p>Nenhuma compra.</p>'}</details><details><summary>Notas do cadastro</summary>${notes.map(n=>`<p>${esc(n.texto)}</p>`).join('')||'<p>Nenhuma nota.</p>'}</details><p class="muted">Na ficha completa: jornada, campos extras, contratos, atividades e histórico.</p>`:'<p>Vincule a uma pessoa do CRM para reunir o histórico dos canais.</p><button class="btn" id="atdCriarLead">Criar lead</button>'}${!cv.grupo&&A.ctx.editar?'<button class="btn sm" id="atdVincular">'+(p?'Alterar vínculo':'Vincular pessoa existente')+'</button>':''}`;
    $('#atdFichaVoltar').onclick=()=>$('#atdRoot').classList.remove('ficha');
    $('#atdResponsavel').onchange=e=>act(()=>api('atualizar',{conversa_id:cv.id,responsavel_id:e.target.value},ws));
    $('#atdFichaCompleta')?.addEventListener('click',()=>act(()=>fichaPessoa(cv.pessoa_id)));
    $('#atdFicha').querySelectorAll('[data-atd-ver-negocio]').forEach(b=>b.addEventListener('click',()=>{
      S.view='crm-oport';S.opFoco=b.dataset.atdVerNegocio;abreMenu(S.view);render();
    }));
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
          try{
            const webhook=await api('zernio-webhooks',{},ws);
            if(webhook.configurado)toast(novas.length?'Instagram conectado e recebimento automático ativado no Atendimento.':'Recebimento automático do Instagram ativado no Atendimento.');
            else toast('Janela encerrada. Nenhum canal Instagram do Atendimento foi encontrado; confira Canais e conexões.');
          }catch(e){toast('Instagram conectada, mas não consegui ativar o recebimento automático: '+e.message,true);}
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
  async function conectarSocialZernio(platform,ws=S.ws){
    const nomes={youtube:'YouTube',linkedin:'LinkedIn',tiktok:'TikTok',facebook:'Página do Facebook',whatsapp:'WhatsApp API oficial'};
    if(!nomes[platform]){toast('Integração não suportada.',true);return;}
    const popup=window.open('about:blank','growthsSocialZernio','width=680,height=800');
    if(!popup){toast('Permita popups para conectar '+nomes[platform]+'.',true);return;}
    popup.document.body.textContent='Abrindo login de '+nomes[platform]+'…';
    try {
      const {data,error}=await sb.functions.invoke('zernio-social-oauth',{body:{workspace_id:ws,platform}});
      if(error){let msg;try{msg=(await error.context.json()).erro;}catch{}throw Error(msg||'Não foi possível iniciar o login.');}
      if(data?.erro)throw Error(data.erro);
      const url=new URL(data.authUrl);
      if(url.protocol!=='https:')throw Error('O provedor não retornou uma URL segura.');
      if(S.ws!==ws){popup.close();return;}
      popup.location.replace(url.toString());
      const timer=setInterval(()=>{
        if(!popup.closed)return;
        clearInterval(timer);
        if(S.ws!==ws)return;
        toast('Janela de autenticação encerrada. Confira a conexão autorizada.');
        if(S.view==='cfg-integracoes'||S.view==='atd-canais')render();
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
    $('#atdCanaisCorpo').innerHTML=`<div class="panel"><p>WhatsApp oficial e Instagram pela Zernio. Na Evolution, nomes pendentes são atualizados sob demanda; novos grupos são descobertos automaticamente a cada seis horas.</p>${ctx.admin?'<div class="acts"><button class="btn" id="atdConfigEvo">Configurar Evolution</button><button class="btn pri" id="atdNovaInst">Nova instância WhatsApp</button><button class="btn pri" id="atdInstagramConectar">Conectar Instagram</button><button class="btn" id="atdWhatsappConectar">Conectar WhatsApp API oficial</button><button class="btn" id="atdZernio">Adicionar canal já conectado</button></div>':'<p>Um administrador gerencia as conexões.</p>'}</div><div class="atd-canais">${canais.map(c=>`<article class="atd-canal">${c.avatar_path?`<img data-channel-avatar="${c.id}" alt="Foto de ${esc(c.nome)}" style="width:56px;height:56px;object-fit:cover;border-radius:50%;float:right">`:''}<h3>${esc(c.nome)}</h3><div class="atd-identificacao">${faixaCanal(c)}</div>${c.provedor==='evolution'&&c.canal==='whatsapp'?`<label class="atd-arquivados"><input type="checkbox" data-arquivados="${c.id}" ${c.exibir_grupos_arquivados?'checked':''} ${ctx.admin?'':'disabled'}> Exibir grupos arquivados</label><small>Arquivados no Growth V2 (não altera o WhatsApp).</small>`:''}<span class="pill ${c.status==='conectado'?'good':'warn'}" data-channel-status="${c.id}">${esc(c.status)}</span><p class="muted">${esc(c.numero?'+'+String(c.numero).replace(/\D/g,''):c.externo_id)}</p><div class="acts">${ctx.admin?`<button class="btn sm" data-ca="editar" data-id="${c.id}">Configurar nome e foto</button>`:''}${ctx.admin&&c.provedor==='evolution'&&c.ativo?`<button class="btn sm" data-ca="conectar" data-id="${c.id}">QR Code</button><button class="btn sm pri" data-ca="qr-share" data-id="${c.id}">Gerar link temporário do QR</button><button class="btn sm" data-ca="status" data-id="${c.id}">Verificar status</button><button class="btn sm bad" data-ca="excluir-instancia" data-id="${c.id}">Excluir instância</button>`:''}${ctx.admin&&c.provedor==='zernio'&&c.canal==='whatsapp'&&c.ativo?`<button class="btn sm" data-ca="status" data-id="${c.id}">Verificar número e conexão</button>`:''}${ctx.admin&&c.ativo?`<button class="btn sm" data-ca="webhook" data-id="${c.id}">Ativar recebimento</button>`:''}${ctx.editar&&c.ativo?(c.provedor==='evolution'?`<button class="btn sm" data-ca="sincronizar" data-modo="conversas" data-id="${c.id}">Buscar conversas</button><button class="btn sm" data-ca="sincronizar" data-modo="grupos_sem_nome" data-id="${c.id}">Atualizar dados dos grupos</button><button class="btn sm" data-ca="sincronizar" data-modo="grupos_novos" data-id="${c.id}">Buscar grupos novos</button>`:`<button class="btn sm" data-ca="sincronizar" data-id="${c.id}">Buscar conversas</button>`):''}</div><div id="ca-${c.id}"></div></article>`).join('')||'<div class="panel">Nenhum canal adicionado.</div>'}</div>`;
    if(ctx.admin){
      const cfg=await api('config',{},ws);
      if(cfg.configurada)$('#atdConfigEvo').insertAdjacentHTML('afterend','<button class="btn bad" id="atdRemoverEvo">Remover API Evolution</button>');
      $('#atdRemoverEvo')?.addEventListener('click',()=>act(async()=>{
        if(!confirm('Remover a URL e a chave da Evolution deste workspace? As instâncias no servidor Evolution não serão excluídas. Remova antes todos os canais Evolution ativos.'))return;
        await api('remover-config',{},ws);toast('Configuração da Evolution removida.');await render();
      }));
      for(const c of canais.filter(c=>c.ativo)){
        const actions=$('#ca-'+c.id)?.previousElementSibling;
        actions?.insertAdjacentHTML('beforeend',`<button class="btn sm bad" data-ca="desativar" data-id="${c.id}">Remover canal do Growth</button>`);
      }
    }
    for(const image of $('#atdCanaisCorpo').querySelectorAll('[data-channel-avatar]'))api('channel-avatar',{canal_id:image.dataset.channelAvatar},ws).then(r=>{if(r.url&&image.isConnected)image.src=r.url;}).catch(()=>{});
    $('#atdConfigEvo')?.addEventListener('click',()=>act(configurarEvolution));
    $('#atdInstagramConectar')?.addEventListener('click',()=>conectarInstagram(ws));
    $('#atdWhatsappConectar')?.addEventListener('click',()=>conectarSocialZernio('whatsapp',ws));
    $('#atdNovaInst')?.addEventListener('click',()=>modal('Nova instância WhatsApp','<label>Nome deste número<input name="nome" required placeholder="Comercial · Número principal" maxlength="100"></label>',async d=>{await api('criar-instancia',d,ws);toast('Instância criada. Abra QR Code para conectar.');}));
    $('#atdZernio')?.addEventListener('click',()=>act(async()=>{const r=await api('zernio-contas',{},ws);if(!r.contas.length){toast('Não encontrei contas WhatsApp ou Instagram no perfil Zernio deste workspace. Confira se a conta está conectada ao perfil correto.',true);return;}modal('Adicionar conta da Zernio',`<label>Conta<select name="account_id">${r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome)}</option>`).join('')}</select></label><p>São listadas as contas disponíveis no perfil Zernio vinculado a este workspace.</p>`,async d=>{await api('zernio-vincular',d,ws);toast('Conta adicionada. Ative o recebimento e busque as conversas.');});}));
    $('#atdCanaisCorpo').onchange=e=>{
      const input=e.target.closest('[data-arquivados]');if(!input)return;
      input.disabled=true;
      act(async()=>{
        try{await api('exibir-arquivados',{canal_id:input.dataset.arquivados,exibir:input.checked},ws);
          toast(input.checked?'Grupos arquivados serão exibidos.':'Grupos arquivados serão ocultados.');
        }catch(err){input.checked=!input.checked;throw err;}finally{input.disabled=false;}
      });
    };
    $('#atdCanaisCorpo').onclick=async e=>{const btn=e.target.closest('[data-ca]');if(!btn||btn.disabled)return;const id=btn.dataset.id,action=btn.dataset.ca;
      if(action==='qr-share'){
        btn.disabled=true;
        try{
          const share=await api('qr-share-create',{canal_id:id},ws),link=new URL('qr-conexao.html',location.href);link.hash=share.token;
          const form=modal('Link temporário para conectar',`<p>Envie este link somente à pessoa que vai escanear o QR Code. Ele expira em 10 minutos e dá acesso apenas à conexão <b>${esc(canais.find(c=>c.id===id)?.nome||'WhatsApp Evolution')}</b>.</p><label>Link de conexão<input id="atdQrShareLink" readonly value="${esc(link.toString())}"></label><button type="button" class="btn pri" id="atdQrShareCopy">Copiar link</button><small>Ao abrir, a pessoa verá o QR Code e o status da conexão em tempo real.</small>`,null,'Fechar');
          form.querySelector('#atdQrShareCopy').onclick=async()=>{const input=form.querySelector('#atdQrShareLink');try{await navigator.clipboard.writeText(input.value);}catch{input.select();document.execCommand('copy');}form.querySelector('#atdQrShareCopy').textContent='Link copiado';};
        }catch(err){toast(err.message,true);}finally{btn.disabled=false;}
        return;
      }
      if(action==='editar'){
        const canal=canais.find(x=>x.id===id);if(!canal)return;
        const form=modal('Configurar canal',`<p class="muted">Status da conexão: <b>${esc(canal.status)}</b> · ${esc(canal.numero?'+'+String(canal.numero).replace(/\D/g,''):canal.externo_id)}</p><label>Nome do canal<input name="nome" required maxlength="100" value="${esc(canal.nome)}"></label><label>Foto do canal (JPG, PNG ou WebP)<input name="foto" type="file" accept="image/jpeg,image/png,image/webp"></label><small>Até 512 KB. A foto fica privada no armazenamento do Growth.</small>`,async(d,f)=>{
          const file=f.elements.foto.files[0];let foto;
          if(file){if(file.size>512*1024)throw Error('A foto deve ter até 512 KB.');foto={mime:file.type,base64:await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.onerror=reject;reader.readAsDataURL(file);})};}
          await api('canal-salvar',{canal_id:id,nome:d.nome,foto},ws);toast('Canal atualizado.');
        },'Salvar');
        return;
      }
      if(action==='excluir-instancia'){
        const canal=canais.find(x=>x.id===id);
        if(!canal||canal.provedor!=='evolution')return;
        const aviso='Excluir definitivamente a instância '+canal.nome+' da Evolution? O WhatsApp será desconectado e a instância apagada no servidor. O histórico do Growth V2 será preservado.';
        if(!confirm(aviso))return;
      }
      if(action==='desativar'){
        const canal=canais.find(x=>x.id===id);if(!canal)return;
        if(!confirm(`Remover ${canal.nome} do Growth? O histórico será preservado. Esta ação não desconecta a conta no provedor e será bloqueada se houver envios pendentes.`))return;
      }
      btn.disabled=true;
      const target=$('#ca-'+id),mode=btn.dataset.modo||'all';
      try{let r;
        if(action==='sincronizar'&&mode==='grupos_novos'){
          target.textContent='Buscando grupos na Evolution… a consulta pode levar alguns minutos.';
          await api(action,{canal_id:id,modo_sincronizacao:mode},ws);
          let elapsed=0,status=await api('grupos-busca-status',{canal_id:id},ws);
          while(status.estado==='em_andamento'&&elapsed<150){
            await new Promise(resolve=>setTimeout(resolve,5000));elapsed+=5;
            if(S.ws!==ws||S.view!=='atd-canais')return;
            status=await api('grupos-busca-status',{canal_id:id},ws);
            const encontrados=status.resultado?.grupos_encontrados;
            target.textContent=encontrados!=null
              ?`${encontrados} grupos identificados. Salvando a lista… ${elapsed}s decorridos.`
              :`Buscando grupos na Evolution… ${elapsed}s decorridos.`;
          }
          if(status.estado==='concluida')r=status.resultado||{};
          else if(status.estado==='falhou')throw new Error(status.resultado?.erro||'Não foi possível consultar os grupos.');
          else {target.textContent='A busca ainda está em andamento. Clique em “Buscar grupos” novamente em instantes para consultar o resultado.';return;}
        }else r=await api(action,{canal_id:id,cursor:btn.dataset.cursor||undefined,modo_sincronizacao:mode},ws);
        if(action==='excluir-instancia'){toast('Instância excluída da Evolution. Histórico preservado.');await render();return;}
        if(action==='desativar'){toast('Canal removido do Growth. Histórico preservado.');await render();return;}if(S.ws!==ws||S.view!=='atd-canais')return;
        if(action==='conectar'){target.innerHTML=r.qrcode&&/^data:image\/(png|jpeg);base64,/.test(r.qrcode)?`<img class="atd-qr" alt="QR Code para conectar o WhatsApp" src="${r.qrcode}"><p>WhatsApp → Aparelhos conectados → Conectar aparelho. Se expirar, clique em QR Code novamente.</p>`:'<p>QR Code indisponível. Confira o status ou tente novamente.</p>';}
        else if(action==='sincronizar'){
          if(mode==='grupos_sem_nome'){
            btn.dataset.cursor=r.cursor||'';btn.textContent=r.cursor?'Próximos dados de grupos':'Atualizar dados dos grupos';
            target.textContent=`${r.grupos_consultados_sem_nome??r.grupos_consultados??0} grupos com nome JID consultados · ${r.nomes_atualizados||0} subjects recuperados · ${r.grupos_sem_nome??'?'} ainda sem nome. ${(r.avisos||[]).join(' | ')}${r.cursor?' Clique novamente para continuar.':''}`;
          }else if(mode==='grupos_novos'){
            target.textContent=`Busca concluída: ${r.grupos_encontrados||0} grupos identificados, ${r.novos_grupos||0} novos. Próxima busca automática em até 6 horas. ${(r.avisos||[]).join(' | ')}`;
          }else target.textContent=(r.total||0)+' conversas consultadas.';
        }
        else if(action==='status'){const badge=document.querySelector(`[data-channel-status="${id}"]`);if(badge){badge.textContent=r.status;badge.className='pill '+(r.status==='conectado'?'good':'warn');}target.textContent=r.phone_status?'Status Meta do número: '+r.phone_status+(r.webhook_recebimento===false?' · webhook de entrada não inscrito':''):r.status==='conectado'?'Conexão ativa na Zernio.':'Status: '+r.status;if(r.status==='conectado')target.querySelector('img')?.remove();}
        else target.textContent='Recebimento por webhook ativado.';
      }catch(err){toast(err.message,true);}finally{btn.disabled=false;}
    };
  }
  async function vTemplates(m){
    stop();++A.token;const ws=S.ws;
    m.innerHTML='<div class="head"><div><h1>Templates</h1><span class="muted">Modelos Meta e respostas rápidas para atendimento.</span></div></div><div id="atdTemplates" class="panel">Carregando…</div>';
    try{
      const [ctx,canais,rapidas]=await Promise.all([
        api('contexto',{},ws),q(sb.from('atd_canais').select('*').eq('workspace_id',ws).eq('provedor','zernio').eq('canal','whatsapp').eq('ativo',true)),api('rapidas-list',{},ws)
      ]);
      if(S.ws!==ws||S.view!=='atd-templates')return;
      const root=$('#atdTemplates');
      root.innerHTML=`<div class="atd-dupla"><button class="btn pri" id="tplMetaTab">Templates Meta</button><button class="btn" id="tplRapidasTab">Respostas rápidas</button></div><div id="tplConteudo"></div>`;
      let aba='meta',templates=[];
      const canalOptions=canais.map(c=>`<option value="${c.id}">${esc(c.nome)} · ${esc(c.numero||c.externo_id)}</option>`).join('');
      let canalId=canais[0]?.id||'';
      const statusTemplate={APPROVED:'Aprovado',PENDING:'Em análise',REJECTED:'Rejeitado',PAUSED:'Pausado',DISABLED:'Desativado',IN_APPEAL:'Em recurso',PENDING_DELETION:'Exclusão pendente'};
      const categoriaTemplate={UTILITY:'Utilidade',MARKETING:'Marketing',AUTHENTICATION:'Autenticação'};
      const tipoBotao={QUICK_REPLY:'Resposta rápida',URL:'Link',PHONE_NUMBER:'Telefone',COPY_CODE:'Copiar código',FLOW:'Abrir formulário',OTP:'Código de acesso'};
      const mapearVariaveis=async t=>{
        const custom=await q(sb.from('campos_personalizados').select('chave,rotulo').eq('workspace_id',ws).eq('entidade','pessoas').order('rotulo')).catch(()=>[]);
        const customFields=custom.map(x=>['extra:'+x.chave,x.rotulo+' · personalizado']);
        const slots=txSlots(t),events=[['cadastro','Cadastro de lead'],['venda','Venda aprovada'],['pesquisa','Resposta de pesquisa/diagnóstico']],saved=t.mapeamentos||{};
        const body=slots.length?events.map(([key,title])=>`<fieldset class="atd-tpl-section"><legend>${title}</legend><p class="muted">Mapeie somente se este template for usado nesse tipo de envio.</p>${slots.map((slot,i)=>`<label>${esc(slot)}<select data-map-event="${key}" data-map-slot="${i}"><option value="">Não mapear neste evento</option>${[...(TX_MAPS[key]||[]),...customFields].map(([field,label])=>`<option value="${esc(field)}"${saved[key]?.[i]===field?' selected':''}>${esc(label)}</option>`).join('')}</select></label>`).join('')}</fieldset>`).join(''):'<p class="muted">Este template não tem variáveis de texto para mapear.</p>';
        const form=modal('Mapear variáveis · '+t.name,`<p class="muted">Defina uma vez de qual campo do contato ou do evento vem cada variável. O mapeamento é separado por tipo de envio e usado em campanhas, produtos e formulários. Essa configuração não reenvia o template para aprovação.</p>${body}`,async(_d,f)=>{
          const mapeamentos=Object.fromEntries(events.map(([key])=>[key,slots.map((_slot,i)=>f.querySelector(`[data-map-event="${key}"][data-map-slot="${i}"]`)?.value||'')]));
          if(slots.length&&Object.values(mapeamentos).some(values=>values.some(Boolean)&&values.some(v=>!v)))throw Error('Complete o mapeamento de todas as variáveis no evento escolhido, ou deixe o evento inteiro sem mapear.');
          await api('templates-mapping-save',{canal_id:canalId,template_name:t.name,idioma:t.language,mapeamentos},ws);toast('Mapeamento das variáveis salvo.');await meta();
        },'Salvar mapeamento',true);
      };
      const renderListaTemplates=()=>{
        const busca=String($('#tplBusca')?.value||'').trim().toLocaleLowerCase('pt-BR'),filtro=$('#tplFiltroStatus')?.value||'';
        const vistos=templates.map((t,i)=>({t,i})).filter(({t})=>(!filtro||t.status===filtro)&&(!busca||[t.name,t.language,t.category,t.status,...(t.components||[]).map(c=>c.text||'')].join(' ').toLocaleLowerCase('pt-BR').includes(busca)));
        $('#tplContagem').textContent=`${vistos.length} de ${templates.length} template(s)`;
        $('#tplLista').innerHTML=vistos.length?vistos.map(({t,i})=>{
          const components=t.components||[],header=components.find(c=>String(c.type).toUpperCase()==='HEADER'),body=components.find(c=>String(c.type).toUpperCase()==='BODY'),footer=components.find(c=>String(c.type).toUpperCase()==='FOOTER'),btns=components.find(c=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[];
          const tipo=String(header?.format||'').toUpperCase(),conteudoHeader=header?(tipo==='TEXT'?header.text||'':({IMAGE:'Imagem',VIDEO:'Vídeo',DOCUMENT:'Documento',LOCATION:'Localização'}[tipo]||tipo)):'';
          const slots=txSlots(t),maps=t.mapeamentos||{},statusMap=Object.entries({cadastro:'Cadastro',venda:'Venda',pesquisa:'Pesquisa/diagnóstico'}).map(([key,label])=>`${label}: ${!slots.length||Array.isArray(maps[key])&&maps[key].length===slots.length&&maps[key].every(Boolean)?'mapeado':'pendente'}`).join(' · ');
          return `<article class="panel atd-template-card"><div class="atd-template-card-head"><h4>${esc(t.name||'Sem nome')}</h4><span class="pill ${t.status==='APPROVED'?'good':t.status==='REJECTED'?'bad':'warn'}">${esc(statusTemplate[t.status]||t.status||'Status não informado')}</span></div><dl class="atd-template-fields"><div><dt>Nome do template</dt><dd>${esc(t.name||'—')}</dd></div><div><dt>Idioma</dt><dd>${esc(t.language||'—')}</dd></div><div><dt>Categoria</dt><dd>${esc(categoriaTemplate[t.category]||t.category||'—')}</dd></div><div><dt>ID Meta</dt><dd>${esc(t.id||'—')}</dd></div><div><dt>Cabeçalho</dt><dd>${header?`${esc(conteudoHeader)}${tipo==='TEXT'?`<br>${esc(header.text||'')}`:''}`:'Sem cabeçalho'}</dd></div><div class="wide"><dt>Mensagem</dt><dd class="pre">${esc(body?.text||'—')}</dd></div><div class="wide"><dt>Campos para envio automático</dt><dd>${esc(statusMap)}</dd></div>${footer?`<div><dt>Rodapé</dt><dd>${esc(footer.text||'—')}</dd></div>`:''}${btns.length?`<div><dt>Botões</dt><dd>${btns.map(b=>`${esc(tipoBotao[String(b.type||'').toUpperCase()]||b.type||'Botão')}: ${esc(b.text||b.flow_cta||b.url||b.phone_number||b.example||'—')}`).join('<br>')}</dd></div>`:''}${t.reason&&t.reason!=='NONE'?`<div class="wide"><dt>Motivo do status</dt><dd>${esc(t.reason)}</dd></div>`:''}</dl>${ctx.admin?`<div class="acts"><button class="btn sm" data-tpl-map="${i}">Mapear variáveis</button><button class="btn sm" data-tpl-edit="${i}">Editar e reenviar</button><button class="btn sm bad" data-tpl-delete="${i}">Excluir na Meta</button></div>`:''}</article>`;
        }).join(''):'<p class="muted">Nenhum template corresponde aos filtros.</p>';
      };
      const meta=async()=>{
        if(!canalId){$('#tplConteudo').innerHTML='<p>Conecte um WhatsApp oficial pela Zernio em Canais e conexões para gerenciar templates aprovados pela Meta. Instâncias Evolution não têm aprovação de templates.</p>';return;}
        $('#tplConteudo').innerHTML=`<h3>Templates do WhatsApp oficial</h3><label>Conta WhatsApp<select id="tplCanal">${canalOptions}</select></label><p class="muted">Os status e componentes vêm da Meta. Templates precisam estar aprovados para envio.</p><div class="atd-template-filtros"><label>Buscar por nome ou conteúdo<input id="tplBusca" type="search" placeholder="Ex.: confirmação, pedido, {{1}}"></label><label>Filtrar por status<select id="tplFiltroStatus"><option value="">Todos os status</option><option value="APPROVED">Aprovado</option><option value="PENDING">Em análise</option><option value="REJECTED">Rejeitado</option><option value="PAUSED">Pausado</option><option value="DISABLED">Desativado</option></select></label><button class="btn sm" id="tplAtualizar">Atualizar lista</button>${ctx.admin?'<button class="btn pri" id="tplNovo">Criar template</button>':''}</div><p class="muted" id="tplContagem"></p><div id="tplLista">Consultando…</div>`;
        $('#tplCanal').value=canalId;
        $('#tplCanal').onchange=e=>{canalId=e.target.value;act(meta);};
        $('#tplAtualizar').onclick=()=>act(meta);
        $('#tplBusca').oninput=renderListaTemplates;$('#tplFiltroStatus').onchange=renderListaTemplates;
        try{
          const result=await api('templates-list',{canal_id:canalId},ws);
          if(S.ws!==ws||S.view!=='atd-templates'||aba!=='meta')return;
          templates=result.templates||[];
          renderListaTemplates();
        }catch(err){$('#tplLista').textContent=err.message;}
        $('#tplNovo')?.addEventListener('click',()=>editor());
        $('#tplLista').onclick=e=>{
          const map=e.target.closest('[data-tpl-map]'),edit=e.target.closest('[data-tpl-edit]'),del=e.target.closest('[data-tpl-delete]');
          if(map){mapearVariaveis(templates[Number(map.dataset.tplMap)]);return;}
          if(edit){editor(templates[Number(edit.dataset.tplEdit)]);return;}
          if(del)act(async()=>{
            const t=templates[Number(del.dataset.tplDelete)];if(!t?.id||!confirm(`Excluir o modelo ${t.name} (${t.language}) da Meta? Essa ação pode impedir envios que o utilizem.`))return;
            await api('templates-delete',{canal_id:canalId,template_id:t.id,template_name:t.name,idioma:t.language},ws);toast('Exclusão solicitada na Meta.');await meta();
          });
        };
      };
      const editor=async t=>{
        const components=t?.components||[],header=components.find(c=>String(c.type).toUpperCase()==='HEADER'),body=components.find(c=>String(c.type).toUpperCase()==='BODY'),footer=components.find(c=>String(c.type).toUpperCase()==='FOOTER'),buttons=components.find(c=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[];
        const custom=await q(sb.from('campos_personalizados').select('chave,rotulo').eq('workspace_id',ws).eq('entidade','pessoas').order('rotulo')).catch(()=>[]),customFields=custom.map(x=>['extra:'+x.chave,x.rotulo+' · personalizado']),events=[['cadastro','Cadastro de lead'],['venda','Venda aprovada'],['pesquisa','Pesquisa/diagnóstico']];let mapsDraft=JSON.parse(JSON.stringify(t?.mapeamentos||{}));
        const mediaExample=String(header?.example?.header_handle?.[0]||'');
        const rawHeaderExamples=header?.example?.header_text||[],headerExampleText=Array.isArray(rawHeaderExamples?.[0])?rawHeaderExamples[0].join('\n'):Array.isArray(rawHeaderExamples)?rawHeaderExamples.join('\n'):'',rawBodyExamples=body?.example?.body_text||[],bodyExampleText=Array.isArray(rawBodyExamples?.[0])?rawBodyExamples[0].join('\n'):Array.isArray(rawBodyExamples)?rawBodyExamples.join('\n'):'';
        const content=`<p class="muted">Preencha os campos com os nomes abaixo. A Meta analisa cada envio; imagem e vídeo precisam estar em uma URL HTTPS pública para análise.</p><label>Nome interno do template<input name="nome" required pattern="[a-z][a-z0-9_]*" value="${esc(t?.name||'')}" placeholder="confirmacao_cadastro"></label><label>Categoria<select name="categoria"><option value="UTILITY">Utilidade</option><option value="MARKETING">Marketing</option></select></label><label>Idioma<select name="idioma"><option value="pt_BR">Português (Brasil) · pt_BR</option><option value="pt_PT">Português (Portugal) · pt_PT</option><option value="en_US">Inglês (EUA) · en_US</option><option value="es_ES">Espanhol · es_ES</option></select></label><fieldset class="atd-tpl-section"><legend>Cabeçalho (opcional)</legend><label>Tipo de cabeçalho<select name="headerFormat"><option value="none">Sem cabeçalho</option><option value="text">Texto</option><option value="image">Imagem</option><option value="video">Vídeo</option><option value="document">Documento</option></select></label><div id="tplHeaderTextFields"><label>Texto do cabeçalho<input name="headerText" maxlength="60" value="${esc(header?.format?.toUpperCase()==='TEXT'?header.text||'':'')}" placeholder="Olá, {{1}}"></label><label>Exemplos das variáveis do cabeçalho (um por linha)<textarea name="headerExample" rows="2" placeholder="Ex.: Maria&#10;Ex.: Pedido 123">${esc(headerExampleText)}</textarea></label></div><div id="tplHeaderMediaFields"><label>URL pública da mídia de exemplo<input name="headerMediaExample" value="${esc(/^https:\/\//i.test(mediaExample)?mediaExample:'')}" placeholder="https://seusite.com/imagem.jpg"></label><small>Imagem: JPG/PNG · Vídeo: MP4 · Documento: PDF. A URL é usada como amostra na análise da Meta.</small></div></fieldset><label>Mensagem do corpo<textarea name="texto" required maxlength="1024" rows="5">${esc(body?.text||'')}</textarea></label><label>Exemplos das variáveis do corpo (um por linha, na ordem)<textarea name="exemplos" rows="3" placeholder="Exemplo da variável 1&#10;Exemplo da variável 2">${esc(bodyExampleText)}</textarea></label><label>Rodapé (opcional)<input name="footerText" maxlength="60" value="${esc(footer?.text||'')}" placeholder="Ex.: Equipe Growth"></label><fieldset class="atd-tpl-section"><legend>Botões (opcional)</legend><div class="atd-tpl-button-builder"><label>Tipo<select id="tplButtonType"><option value="quick_reply">Resposta rápida</option><option value="url">Link</option><option value="phone_number">Telefone</option><option value="copy_code">Copiar código</option><option value="flow">Abrir formulário</option></select></label><label id="tplButtonTextLabel">Texto do botão<input id="tplButtonText" maxlength="25" placeholder="Ex.: Falar com a equipe"></label><div id="tplButtonExtra"></div><button type="button" class="btn sm" id="tplButtonAdd">Adicionar botão</button></div><div id="tplButtonList"></div><small>Até 3 respostas rápidas ou até 2 botões de ação. Tipos de código e formulário seguem a configuração aprovada na Meta.</small></fieldset><fieldset class="atd-tpl-section"><legend>Vincular variáveis aos campos do Growth</legend><p class="muted">Escolha de onde vem cada variável para os envios automáticos de cadastro, venda e formulários. Este vínculo fica salvo no Growth e não altera a aprovação na Meta.</p><div data-tpl-map-editor></div>${t?'<button type="button" class="btn sm" data-tpl-map-save>Salvar vínculos sem reenviar à Meta</button>':'<small>O vínculo será salvo junto com o template quando você enviá-lo para aprovação.</small>'}</fieldset>${t?'<p class="muted">Editar os componentes e salvar o template o submete novamente à análise da Meta.</p>':''}`;
        const buttonDraft=buttons.map(b=>({type:String(b.type||'').toLowerCase(),text:b.text||b.flow_cta||'',url:b.url||'',example:Array.isArray(b.example)?b.example[0]||'':b.example||'',phone_number:b.phone_number||'',flow_id:b.flow_id||'',flow_cta:b.flow_cta||'',flow_action:b.flow_action||'navigate',navigate_screen:b.navigate_screen||''}));
        const form=modal(t?'Editar template':'Criar template',content,async(d,f)=>{
          readEditorMap();
          const action=t?'templates-update':'templates-create';
          const parseExamples=s=>String(s||'').split('\n').map(x=>x.trim()).filter(Boolean),result=[];
          const headerFormat=d.headerFormat;
          if(headerFormat==='text')result.push({type:'header',format:'text',text:d.headerText,examples:parseExamples(d.headerExample)});
          if(['image','video','document'].includes(headerFormat))result.push({type:'header',format:headerFormat,example_url:d.headerMediaExample});
          result.push({type:'body',text:d.texto,examples:parseExamples(d.exemplos)});
          if(String(d.footerText||'').trim())result.push({type:'footer',text:d.footerText});
          if(buttonDraft.length)result.push({type:'buttons',buttons:buttonDraft});
          const mapTemplate={components:result,mapeamentos:mapsDraft},slots=txSlots(mapTemplate),mapeamentos=Object.fromEntries(events.map(([key])=>[key,slots.map((_slot,i)=>mapsDraft[key]?.[i]||'')]));
          if(slots.length&&Object.values(mapeamentos).some(values=>values.some(Boolean)&&values.some(v=>!v)))throw Error('Complete todas as variáveis do evento escolhido, ou deixe o evento inteiro sem mapear.');
          await api(action,{canal_id:canalId,template_id:t?.id,nome:d.nome,categoria:d.categoria,idioma:d.idioma,componentes:result},ws);
          if(slots.length&&Object.values(mapeamentos).some(values=>values.some(Boolean)))await api('templates-mapping-save',{canal_id:canalId,template_name:d.nome,idioma:d.idioma,mapeamentos},ws);
          toast('Modelo enviado à Meta. Acompanhe o status nesta aba.');await meta();
        },t?'Salvar e reenviar':'Enviar para aprovação',true);
        const renderEditorMap=()=>{
          const componentsNow=[],hf=form.elements.headerFormat.value;
          if(hf==='text')componentsNow.push({type:'header',format:'TEXT',text:form.elements.headerText.value});
          componentsNow.push({type:'body',text:form.elements.texto.value});
          if(buttonDraft.length)componentsNow.push({type:'buttons',buttons:buttonDraft});
          const slots=txSlots({components:componentsNow}),host=form.querySelector('[data-tpl-map-editor]');
          host.innerHTML=slots.length?events.map(([key,title])=>`<fieldset class="atd-tpl-section"><legend>${title}</legend><p class="muted">Mapeie apenas os eventos que usarão este template. Campos personalizados também aparecem nesta lista.</p>${slots.map((slot,i)=>`<label>${esc(slot)}<select data-editor-map-event="${key}" data-editor-map-slot="${i}"><option value="">Não mapear neste evento</option>${[...(TX_MAPS[key]||[]),...customFields].map(([field,label])=>`<option value="${esc(field)}"${mapsDraft[key]?.[i]===field?' selected':''}>${esc(label)}</option>`).join('')}</select></label>`).join('')}</fieldset>`).join(''):'<p class="muted">Inclua variáveis como {{1}} no cabeçalho, corpo ou URL de botão para vinculá-las aos campos do Growth.</p>';
        };
        const readEditorMap=()=>{const slots=txSlots({components:[...(form.elements.headerFormat.value==='text'?[{type:'header',format:'TEXT',text:form.elements.headerText.value}]:[]),{type:'body',text:form.elements.texto.value},...(buttonDraft.length?[{type:'buttons',buttons:buttonDraft}]:[])]});mapsDraft=Object.fromEntries(events.map(([key])=>[key,slots.map((_slot,i)=>form.querySelector(`[data-editor-map-event="${key}"][data-editor-map-slot="${i}"]`)?.value||'')]));return slots;};
        const saveEditorMap=async()=>{const slots=readEditorMap(),mapeamentos=mapsDraft;if(!slots.length){toast('Adicione uma variável ao template antes de vinculá-la.',true);return;}if(Object.values(mapeamentos).some(values=>values.some(Boolean)&&values.some(v=>!v))){toast('Complete todas as variáveis do evento escolhido, ou deixe o evento inteiro sem mapear.',true);return;}if(!Object.values(mapeamentos).some(values=>values.some(Boolean))){toast('Selecione ao menos um campo para mapear.',true);return;}await api('templates-mapping-save',{canal_id:canalId,template_name:form.elements.nome.value.trim(),idioma:form.elements.idioma.value,mapeamentos},ws);toast('Vínculos das variáveis salvos no Growth.');await meta();};
        form.querySelector('[data-tpl-map-save]')?.addEventListener('click',()=>act(saveEditorMap));
        form.addEventListener('change',e=>{if(['headerText','texto'].includes(e.target?.name)){readEditorMap();renderEditorMap();}});
        form.querySelector('[data-tpl-map-editor]').addEventListener('change',e=>{const sel=e.target.closest('[data-editor-map-event]');if(!sel)return;const key=sel.dataset.editorMapEvent,index=Number(sel.dataset.editorMapSlot);mapsDraft[key]=mapsDraft[key]||[];mapsDraft[key][index]=sel.value;});
        if(t)form.querySelector('[name=categoria]').value=t.category||'UTILITY';
        if(t)form.querySelector('[name=idioma]').value=t.language||'pt_BR';
        const headerFormat=form.elements.headerFormat;
        headerFormat.value=header?String(header.format||'').toLowerCase():'none';
        const headerFields=()=>{form.querySelector('#tplHeaderTextFields').hidden=headerFormat.value!=='text';form.querySelector('#tplHeaderMediaFields').hidden=!['image','video','document'].includes(headerFormat.value);};
        headerFormat.onchange=()=>{headerFields();readEditorMap();renderEditorMap();};headerFields();renderEditorMap();
        const tipo=form.querySelector('#tplButtonType'),extra=form.querySelector('#tplButtonExtra');
        const extraFields=()=>{const code=tipo.value==='copy_code',flow=tipo.value==='flow';form.querySelector('#tplButtonTextLabel').hidden=code;if(code)form.querySelector('#tplButtonText').value='';extra.innerHTML=tipo.value==='url'?'<label>URL do botão<input id="tplButtonUrl" placeholder="https://site.com/pedido/{{1}}"></label><label>Exemplo do link dinâmico (se usar {{1}})<input id="tplButtonUrlExample" placeholder="pedido/123"></label>':tipo.value==='phone_number'?'<label>Telefone com código do país<input id="tplButtonPhone" placeholder="+5511999999999"></label>':code?'<label>Exemplo do cupom<input id="tplButtonExample" placeholder="PROMO10"></label>':flow?'<label>ID do formulário WhatsApp<input id="tplButtonFlowId" placeholder="ID fornecido pela Meta"></label><label>Texto do botão<input id="tplButtonFlowCta" maxlength="20" placeholder="Abrir formulário"></label><label>Tela inicial<input id="tplButtonFlowScreen" placeholder="WELCOME"></label>':'';};
        tipo.onchange=extraFields;extraFields();
        const renderButtons=()=>{form.querySelector('#tplButtonList').innerHTML=buttonDraft.length?`<ul class="atd-tpl-button-list">${buttonDraft.map((b,i)=>`<li><span><b>${esc(tipoBotao[b.type.toUpperCase()]||b.type)}</b>${b.text||b.flow_cta||b.example?` · ${esc(b.text||b.flow_cta||b.example)}`:''}${b.url?` · ${esc(b.url)}`:''}${b.phone_number?` · ${esc(b.phone_number)}`:''}</span><button type="button" class="btn sm bad" data-tpl-button-remove="${i}">Remover</button></li>`).join('')}</ul>`:'<p class="muted">Nenhum botão adicionado.</p>';};
        form.querySelector('#tplButtonAdd').onclick=()=>{
          const b={type:tipo.value,text:form.querySelector('#tplButtonText').value.trim()};
          if(b.type==='url'){b.url=form.querySelector('#tplButtonUrl')?.value.trim()||'';b.example=form.querySelector('#tplButtonUrlExample')?.value.trim()||'';}
          if(b.type==='phone_number')b.phone_number=form.querySelector('#tplButtonPhone')?.value.trim()||'';
          if(b.type==='copy_code'){b.example=form.querySelector('#tplButtonExample')?.value.trim()||'';}
          if(b.type==='flow'){b.flow_id=form.querySelector('#tplButtonFlowId')?.value.trim()||'';b.flow_cta=form.querySelector('#tplButtonFlowCta')?.value.trim()||'';b.flow_action='navigate';b.navigate_screen=form.querySelector('#tplButtonFlowScreen')?.value.trim()||'';b.text=b.flow_cta;}
          if(buttonDraft.length>=3){toast('O limite é de 3 botões.',true);return;}
          if(b.type!=='copy_code'&&!b.text){toast('Informe o texto do botão.',true);return;}
          if(b.type==='copy_code'&&!b.example){toast('Informe o exemplo do cupom.',true);return;}
          if(b.type==='flow'&&(!b.flow_id||!b.flow_cta||!b.navigate_screen)){toast('Preencha o ID, o texto e a tela inicial do formulário.',true);return;}
          buttonDraft.push(b);form.querySelector('#tplButtonText').value='';renderButtons();readEditorMap();renderEditorMap();
        };
        form.querySelector('#tplButtonList').onclick=e=>{const btn=e.target.closest('[data-tpl-button-remove]');if(btn){buttonDraft.splice(Number(btn.dataset.tplButtonRemove),1);renderButtons();readEditorMap();renderEditorMap();}};
        renderButtons();
      };
      const rapidaView=async()=>{
        const result=await api('rapidas-list',{},ws),rows=result.respostas||[];
        if(S.ws!==ws||S.view!=='atd-templates'||aba!=='rapidas')return;
        $('#tplConteudo').innerHTML=`<h3>Respostas rápidas</h3><p class="muted">Use o botão ⚡ em uma conversa para inserir a resposta no texto, revisar e enviar.</p>${ctx.editar?'<button class="btn pri" id="rapidaNova">Nova resposta</button>':''}<div id="rapidaLista">${rows.map((r,i)=>`<article class="panel" style="margin:12px 0"><b>/${esc(r.atalho)}</b> · ${esc(r.titulo)}<p style="white-space:pre-wrap">${esc(r.texto)}</p>${ctx.editar?`<div class="acts"><button class="btn sm" data-rapida-edit="${i}">Editar</button><button class="btn sm bad" data-rapida-delete="${i}">Excluir</button></div>`:''}</article>`).join('')||'<p>Nenhuma resposta rápida cadastrada.</p>'}</div>`;
        const formResposta=r=>modal(r?'Editar resposta':'Nova resposta rápida',`<label>Atalho (sem espaços)<input name="atalho" required value="${esc(r?.atalho||'')}"></label><label>Título<input name="titulo" required value="${esc(r?.titulo||'')}"></label><label>Mensagem<textarea name="texto" required rows="6" maxlength="4000">${esc(r?.texto||'')}</textarea></label>`,async d=>{
          await api('rapidas-save',{id:r?.id,...d},ws);toast('Resposta salva.');await rapidaView();
        },'Salvar resposta');
        $('#rapidaNova')?.addEventListener('click',()=>formResposta());
        $('#rapidaLista').onclick=e=>{
          const ed=e.target.closest('[data-rapida-edit]'),del=e.target.closest('[data-rapida-delete]');
          if(ed)formResposta(rows[Number(ed.dataset.rapidaEdit)]);
          if(del)act(async()=>{const r=rows[Number(del.dataset.rapidaDelete)];if(!confirm('Excluir a resposta rápida /'+r.atalho+'?'))return;await api('rapidas-delete',{id:r.id},ws);await rapidaView();});
        };
      };
      $('#tplMetaTab').onclick=()=>{aba='meta';$('#tplMetaTab').classList.add('pri');$('#tplRapidasTab').classList.remove('pri');act(meta);};
      $('#tplRapidasTab').onclick=()=>{aba='rapidas';$('#tplRapidasTab').classList.add('pri');$('#tplMetaTab').classList.remove('pri');act(rapidaView);};
      await meta();
    }catch(e){if(S.ws===ws&&S.view==='atd-templates')$('#atdTemplates').textContent=e.message;}
  }
  async function vContatos(m){
    stop();++A.token;const ws=S.ws;m.innerHTML='<div class="head"><div><h1>Contatos</h1><span class="muted">Base compartilhada de leads e compradores para conversas e transmissões.</span></div></div><div id="atdContatos" class="atd-contatos">Carregando contatos…</div>';
    try{
      const ctx=await api('contexto',{},ws);if(S.ws!==ws||S.view!=='atd-contatos')return;
      let people=[],selected=new Set(),tagFilter='',typeFilter='',search='';const root=$('#atdContatos');
      let from=0;while(true){const page=await q(sb.from('pessoas').select('id,nome,email,telefone,status_funil,status_cliente,qualificacao,tags,canal_origem,criado_em').eq('workspace_id',ws).order('criado_em',{ascending:false}).range(from,from+499));people.push(...page);if(page.length<500)break;from+=500;}
      if(S.ws!==ws||S.view!=='atd-contatos')return;
      root.innerHTML=`<section class="panel"><div class="atd-contato-actions"><label>Buscar<input id="acBusca" type="search" placeholder="Nome, telefone ou e-mail"></label><label>Tipo<select id="acTipo"><option value="">Leads e compradores</option><option value="lead">Leads</option><option value="cliente">Compradores</option></select></label><label>Tag<select id="acTag"><option value="">Todas as tags</option></select></label><label>Importar contatos (.csv)<input id="acArquivo" type="file" accept=".csv,.txt,text/csv"></label><label>Ou cole linhas CSV<textarea id="acColar" rows="2" placeholder="nome;telefone;email;tags\nAna;5511999999999;ana@email.com;lançamento"></textarea></label><label>Importar como<select id="acTipoImport"><option value="lead">Lead</option><option value="cliente">Comprador ativo</option></select></label><label>Tag para os importados<input id="acTagImport" placeholder="Ex.: lista novembro"></label><button type="button" class="btn pri" id="acImportar" ${ctx.editar?'':'disabled'}>Importar contatos</button></div><p class="muted">Contatos existentes por e-mail ou telefone são ignorados sem sobrescrever o cadastro. Os importados ficam na mesma base de pessoas usada pelo Growth.</p></section><section class="panel"><div class="atd-contato-bulk"><b id="acResumo"></b><input id="acTagBulk" placeholder="Nome da tag"><button type="button" class="btn sm" id="acTagAdicionar" ${ctx.editar?'':'disabled'}>Adicionar tag</button><button type="button" class="btn sm" id="acTagRemover" ${ctx.editar?'':'disabled'}>Remover tag</button><button type="button" class="btn sm" id="acSelecionar">Selecionar filtrados</button><button type="button" class="btn sm" id="acLimpar">Limpar seleção</button></div><div class="tw"><table><thead><tr><th></th><th>Contato</th><th>Tipo</th><th>Tags</th><th>Origem</th><th>Cadastro</th></tr></thead><tbody id="acRows"></tbody></table></div></section>`;
      const norm=s=>String(s||'').toLocaleLowerCase('pt-BR').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim();
      const tagsOf=p=>Array.isArray(p.tags)?p.tags:[];
      const filtered=()=>people.filter(p=>(!typeFilter||p.status_funil===typeFilter)&&(!tagFilter||tagsOf(p).includes(tagFilter))&&(!search||[p.nome,p.email,p.telefone].some(x=>norm(x).includes(norm(search)))));
      const render=()=>{const tags=[...new Set(people.flatMap(tagsOf))].sort((a,b)=>a.localeCompare(b,'pt-BR')),sel=root.querySelector('#acTag');const old=tagFilter;sel.innerHTML='<option value="">Todas as tags</option>'+tags.map(t=>`<option value="${esc(t)}">${esc(t)}</option>`).join('');sel.value=tags.includes(old)?old:'';tagFilter=sel.value;const rows=filtered();root.querySelector('#acResumo').textContent=`${rows.length} contatos · ${selected.size} selecionados`;root.querySelector('#acRows').innerHTML=rows.slice(0,2000).map(p=>`<tr><td><input type="checkbox" data-ac-id="${esc(p.id)}" ${selected.has(p.id)?'checked':''}></td><td><b>${esc(p.nome||'Sem nome')}</b><br><small>${esc(p.telefone||'')}${p.email?' · '+esc(p.email):''}</small></td><td>${p.status_funil==='cliente'?'Comprador':'Lead'}${p.status_cliente==='ativo'?' · ativo':p.status_cliente==='inativo'?' · inativo':''}</td><td>${tagsOf(p).map(t=>`<span class="atd-contato-tag">${esc(t)}</span>`).join(' ')||'—'}</td><td>${esc(p.canal_origem||'—')}</td><td>${p.criado_em?new Date(p.criado_em).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):'—'}</td></tr>`).join('')||'<tr><td colspan="6" class="empty">Nenhum contato encontrado.</td></tr>';root.querySelectorAll('[data-ac-id]').forEach(cb=>cb.onchange=()=>{cb.checked?selected.add(cb.dataset.acId):selected.delete(cb.dataset.acId);root.querySelector('#acResumo').textContent=`${filtered().length} contatos · ${selected.size} selecionados`;});};
      const parseDelimited=raw=>{const lines=String(raw||'').replace(/^\uFEFF/,'').split(/\r?\n/).filter(x=>x.trim());if(lines.length<2)throw Error('O CSV precisa ter cabeçalho e pelo menos uma linha.');const delim=(lines[0].match(/;/g)||[]).length>(lines[0].match(/,/g)||[]).length?';':(lines[0].match(/\t/g)||[]).length>(lines[0].match(/,/g)||[]).length?'\t':',';const parseLine=line=>{const out=[];let cur='',quote=false;for(let i=0;i<line.length;i++){const c=line[i];if(c==='"'&&quote&&line[i+1]==='"'){cur+='"';i++;}else if(c==='"')quote=!quote;else if(c===delim&&!quote){out.push(cur.trim());cur='';}else cur+=c;}out.push(cur.trim());return out;};const headers=parseLine(lines[0]).map(norm);return lines.slice(1).map(parseLine).filter(r=>r.some(Boolean)).map(r=>Object.fromEntries(headers.map((h,i)=>[h,r[i]||''])));};
      const cell=(row,names)=>{for(const n of names){const v=row[norm(n)];if(v)return String(v).trim();}return '';};
      const phones=new Set(people.map(p=>String(p.telefone||'').replace(/\D/g,'')).filter(Boolean)),emails=new Set(people.map(p=>String(p.email||'').trim().toLowerCase()).filter(Boolean));
      root.querySelector('#acImportar').onclick=()=>act(async()=>{if(!ctx.editar)throw Error('Seu perfil não tem permissão para importar contatos.');const file=root.querySelector('#acArquivo').files[0],raw=file?await file.text():root.querySelector('#acColar').value;if(!raw.trim())throw Error('Selecione um CSV ou cole os dados.');const rows=parseDelimited(raw);if(rows.length>5000)throw Error('Importe no máximo 5.000 linhas por vez.');const defaultType=root.querySelector('#acTipoImport').value,defaultTag=root.querySelector('#acTagImport').value.trim(),inserts=[],seenPhone=new Set(),seenEmail=new Set();let invalid=0,duplicates=0;for(const row of rows){const telefone=cell(row,['telefone','telefone whatsapp','telefone/whatsapp','celular','whatsapp','whatsapp number','phone','phone number','mobile','numero','número','tel']).replace(/\s+/g,'').trim(),email=cell(row,['email','e-mail','e mail','mail']).trim().toLowerCase(),nome=cell(row,['nome','name','full name','nome completo'])||telefone;if(!nome||!telefone){invalid++;continue;}const phoneKey=telefone.replace(/\D/g,'');if(phoneKey.length<10){invalid++;continue;}if((phones.has(phoneKey))||(email&&emails.has(email))||(seenPhone.has(phoneKey))||(email&&seenEmail.has(email))){duplicates++;continue;}seenPhone.add(phoneKey);if(email)seenEmail.add(email);const statusRaw=norm(cell(row,['tipo','situacao','situação','status','tipo de contato'])),isBuyer=/cliente|comprador|aluno|buyer|customer/.test(statusRaw)?true:/lead|prospect/.test(statusRaw)?false:defaultType==='cliente';const tags=[...new Set([...cell(row,['tags','tag','etiquetas','labels']).split(/[;,|]/).map(x=>x.trim()).filter(Boolean),...(defaultTag?[defaultTag]:[])])].slice(0,20);inserts.push({workspace_id:ws,nome,email:email||null,telefone,status_funil:isBuyer?'cliente':'lead',status_cliente:isBuyer?'ativo':null,convertido_em:isBuyer?new Date().toISOString():null,captada:false,canal_origem:'atendimento',tags});}if(!inserts.length)throw Error(`Nenhum contato novo válido. ${duplicates} duplicados; ${invalid} linhas sem telefone válido/nome.`);let saved=0;for(let i=0;i<inserts.length;i+=100){const batch=await q(sb.from('pessoas').insert(inserts.slice(i,i+100)).select('id,nome,email,telefone,status_funil,status_cliente,qualificacao,tags,canal_origem,criado_em'));people.push(...batch);saved+=batch.length;}render();toast(`${saved} importados · ${duplicates} duplicados ignorados · ${invalid} linhas inválidas.`);});
      for(const id of ['acBusca','acTipo','acTag'])root.querySelector('#'+id).addEventListener(id==='acBusca'?'input':'change',e=>{if(id==='acBusca')search=e.target.value;if(id==='acTipo')typeFilter=e.target.value;if(id==='acTag')tagFilter=e.target.value;render();});
      root.querySelector('#acSelecionar').onclick=()=>{filtered().forEach(p=>selected.add(p.id));render();};root.querySelector('#acLimpar').onclick=()=>{selected.clear();render();};
      const changeTags=remove=>act(async()=>{if(!ctx.editar)throw Error('Seu perfil não tem permissão para editar contatos.');const tag=root.querySelector('#acTagBulk').value.trim();if(!tag)throw Error('Informe o nome da tag.');const chosen=people.filter(p=>selected.has(p.id)&&!String(p.id).startsWith('import-'));if(!chosen.length)throw Error('Selecione contatos cadastrados para alterar as tags.');for(let i=0;i<chosen.length;i+=50){await Promise.all(chosen.slice(i,i+50).map(p=>{const next=remove?tagsOf(p).filter(t=>t!==tag):[...new Set([...tagsOf(p),tag])];return q(sb.from('pessoas').update({tags:next}).eq('id',p.id).eq('workspace_id',ws));}));}chosen.forEach(p=>p.tags=remove?tagsOf(p).filter(t=>t!==tag):[...new Set([...tagsOf(p),tag])]);render();toast(`${remove?'Tag removida de':'Tag aplicada a'} ${chosen.length} contato(s).`);});
      root.querySelector('#acTagAdicionar').onclick=()=>changeTags(false);root.querySelector('#acTagRemover').onclick=()=>changeTags(true);render();
    }catch(e){if(S.ws===ws&&S.view==='atd-contatos')$('#atdContatos').innerHTML=`<div class="empty"><b>Não foi possível carregar os contatos</b><p>${esc(e.message)}</p></div>`;}
  }
  function emailComposerTools(ws){
    const prepareEmailEditor=el=>{const source=el.querySelector('textarea[data-email-html]');if(!source||el.querySelector('.atd-email-editor'))return;const editor=document.createElement('div');editor.className='atd-email-editor';editor.contentEditable='true';editor.dataset.emailHtml='';editor.setAttribute('role','textbox');editor.setAttribute('aria-multiline','true');editor.dataset.placeholder='Monte o corpo do e-mail. Você pode inserir imagens e botões.';editor.innerHTML=source.value||'';const toolbar=document.createElement('div');toolbar.className='atd-email-toolbar';toolbar.innerHTML='<button type="button" class="btn sm" data-email-image-url>Imagem por URL</button><button type="button" class="btn sm" data-email-image-file>Enviar imagem</button><button type="button" class="btn sm" data-email-cta>Inserir botão</button><input type="file" data-email-file accept="image/png,image/jpeg,image/webp,image/gif" hidden>';source.replaceWith(editor);editor.before(toolbar);const urlOk=value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password?u.href:'';}catch(_){return '';}};const insert=html=>{editor.focus();document.execCommand('insertHTML',false,html);};toolbar.querySelector('[data-email-image-url]').onclick=()=>{const url=urlOk(prompt('URL pública HTTPS da imagem:')||'');if(!url){toast('Informe uma URL HTTPS válida para a imagem.',true);return;}insert(`<img src="${esc(url)}" alt="" style="display:block;max-width:100%;height:auto;margin:12px auto">`);};const file=toolbar.querySelector('[data-email-file]');let savedRange=null;toolbar.querySelector('[data-email-image-file]').onclick=()=>{const sel=getSelection();savedRange=sel&&sel.rangeCount?sel.getRangeAt(0).cloneRange():null;file.click();};file.onchange=()=>act(async()=>{const image=file.files?.[0];file.value='';if(!image)return;if(!['image/png','image/jpeg','image/webp','image/gif'].includes(image.type)||image.size>5*1024*1024)throw Error('Use PNG, JPG, WebP ou GIF com até 5 MB.');const ext=image.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g,'')||'png',path=`${ws}/${crypto.randomUUID()}.${ext}`,uploaded=await sb.storage.from('email-assets').upload(path,image,{upsert:false,contentType:image.type,cacheControl:'3600'});if(uploaded.error)throw uploaded.error;const publicUrl=sb.storage.from('email-assets').getPublicUrl(path).data.publicUrl;if(savedRange&&editor.isConnected){editor.focus();const sel=getSelection();sel.removeAllRanges();sel.addRange(savedRange);}insert(`<img src="${esc(publicUrl)}" alt="${esc(image.name)}" style="display:block;max-width:100%;height:auto;margin:12px auto">`);toast('Imagem enviada e inserida no e-mail.');});toolbar.querySelector('[data-email-cta]').onclick=()=>{const label=(prompt('Texto do botão:')||'').trim(),url=urlOk(prompt('Link HTTPS do botão:')||'');if(!label||!url){toast('Informe o texto e uma URL HTTPS para o botão.',true);return;}insert(`<a href="${esc(url)}" style="display:inline-block;padding:12px 22px;background:#2563eb;color:#ffffff;text-decoration:none;border-radius:6px;font-weight:700;margin:10px 0">${esc(label)}</a>`);};};
    const enhanceEmailStep=el=>{if(el.dataset.previewReady)return;el.dataset.previewReady='1';const editor=el.querySelector('.atd-email-editor'),toolbar=el.querySelector('.atd-email-toolbar'),frame=el.querySelector('[data-email-preview-frame]'),subject=el.querySelector('[data-email-subject]');toolbar.insertAdjacentHTML('afterbegin','<span class="atd-email-toolbar-label">Formatação</span><button type="button" class="btn sm" data-email-format="bold" title="Negrito"><b>B</b></button><button type="button" class="btn sm" data-email-format="italic" title="Itálico"><i>I</i></button><button type="button" class="btn sm" data-email-format="insertUnorderedList" title="Lista">☷ Lista</button><button type="button" class="btn sm" data-email-block="heading">Título</button><button type="button" class="btn sm" data-email-block="divider">Separador</button><span class="atd-email-toolbar-separator" aria-hidden="true"></span>');toolbar.querySelectorAll('[data-email-format]').forEach(btn=>btn.onmousedown=e=>e.preventDefault());toolbar.querySelectorAll('[data-email-block]').forEach(btn=>btn.onmousedown=e=>e.preventDefault());toolbar.querySelectorAll('[data-email-block]').forEach(btn=>btn.onclick=()=>{editor.focus();document.execCommand('insertHTML',false,btn.dataset.emailBlock==='heading'?'<h2 style="font-family:Arial,sans-serif;font-size:24px;line-height:1.3;margin:20px 0 10px">Seu título aqui</h2>':'<hr style="border:0;border-top:1px solid #e2e8f0;margin:24px 0">');editor.dispatchEvent(new Event('input',{bubbles:true}));});toolbar.querySelectorAll('[data-email-format]').forEach(btn=>btn.onclick=()=>{editor.focus();document.execCommand(btn.dataset.emailFormat,false,null);editor.dispatchEvent(new Event('input',{bubbles:true}));});const update=()=>{editor.value=editor.innerHTML;const html=editor.innerHTML.trim(),preview=html||'<p style="color:#64748b">O conteúdo do e-mail aparecerá aqui enquanto você escreve.</p>';el.querySelector('[data-email-preview-subject]').textContent=subject.value.trim()||'Assunto do e-mail';frame.srcdoc=`<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'"><style>body{font:14px/1.55 Arial,sans-serif;color:#1f2937;background:white;margin:0;padding:22px;overflow-wrap:anywhere}img{max-width:100%;height:auto}a{color:#2563eb}</style></head><body>`+preview+'</body></html>';};let timer;editor.addEventListener('input',()=>{clearTimeout(timer);timer=setTimeout(update,180);});subject.addEventListener('input',update);new MutationObserver(()=>{clearTimeout(timer);timer=setTimeout(update,180);}).observe(editor,{childList:true,subtree:true,characterData:true,attributes:true});el.querySelectorAll('[data-email-size]').forEach(btn=>btn.onclick=()=>{el.querySelector('.atd-email-preview').classList.toggle('mobile',btn.dataset.emailSize==='mobile');el.querySelectorAll('[data-email-size]').forEach(x=>x.classList.toggle('pri',x===btn));});update();};
    const extendEmailControls=el=>{if(el.dataset.controlsReady)return;el.dataset.controlsReady='1';const editor=el.querySelector('.atd-email-editor'),toolbar=el.querySelector('.atd-email-toolbar'),compose=el.querySelector('.atd-email-compose');let range=null,selected=null;const remember=()=>{const selection=getSelection();if(selection?.rangeCount&&editor.contains(selection.anchorNode))range=selection.getRangeAt(0).cloneRange();};const restore=()=>{editor.focus();if(range){const selection=getSelection();selection.removeAllRanges();selection.addRange(range);}};const changed=()=>editor.dispatchEvent(new Event('input',{bubbles:true}));editor.addEventListener('keyup',remember);editor.addEventListener('mouseup',remember);editor.addEventListener('input',remember);toolbar.insertAdjacentHTML('beforeend',`<span class="atd-email-toolbar-separator" aria-hidden="true"></span><label class="atd-email-tool-label">Fonte<select data-email-font aria-label="Fonte do texto"><option value="">Fonte</option><option value="Arial">Arial</option><option value="Georgia">Georgia</option><option value="Tahoma">Tahoma</option><option value="Verdana">Verdana</option></select></label><label class="atd-email-tool-label">Tamanho<select data-email-font-size aria-label="Tamanho do texto"><option value="">Tamanho</option>${[12,14,16,18,20,24,28,32].map(n=>`<option value="${n}">${n} px</option>`).join('')}</select></label><label class="atd-email-tool-label">Cor do texto<input data-email-text-color type="color" value="#1f2937" aria-label="Cor do texto"></label><button type="button" class="btn sm" data-email-layout="justifyLeft" title="Alinhar à esquerda">☰</button><button type="button" class="btn sm" data-email-layout="justifyCenter" title="Centralizar">≡</button><button type="button" class="btn sm" data-email-layout="justifyRight" title="Alinhar à direita">☷</button><button type="button" class="btn sm" data-email-layout="indent">Aumentar recuo</button><button type="button" class="btn sm" data-email-layout="outdent">Diminuir recuo</button>`);toolbar.querySelectorAll('[data-email-layout]').forEach(button=>{button.onmousedown=e=>e.preventDefault();button.onclick=()=>{restore();document.execCommand(button.dataset.emailLayout,false,null);changed();remember();};});toolbar.querySelector('[data-email-font]').onchange=e=>{if(!e.target.value)return;restore();document.execCommand('fontName',false,e.target.value);changed();remember();};toolbar.querySelector('[data-email-font-size]').onchange=e=>{const px=Number(e.target.value);if(!px)return;restore();document.execCommand('fontSize',false,'7');editor.querySelectorAll('font[size="7"]').forEach(font=>{font.removeAttribute('size');font.style.fontSize=px+'px';font.style.lineHeight='1.5';});changed();remember();};toolbar.querySelector('[data-email-text-color]').oninput=e=>{restore();document.execCommand('foreColor',false,e.target.value);changed();remember();};const panel=document.createElement('div');panel.className='atd-email-element-settings';panel.hidden=true;panel.innerHTML='<b data-email-element-title>Elemento selecionado</b><label data-email-image-settings>Largura da imagem<select data-email-image-width><option value="100%">Largura total</option><option value="75%">75%</option><option value="50%">50%</option><option value="320px">320 px</option><option value="200px">200 px</option></select></label><label data-email-image-settings>Largura personalizada (px)<input data-email-image-px type="number" min="50" max="1200" placeholder="Ex.: 480"></label><label data-email-image-settings>Descrição da imagem<input data-email-image-alt maxlength="160" placeholder="Descreva a imagem"></label><label data-email-button-settings>Cor do botão<input data-email-button-bg type="color" value="#2563eb"></label><label data-email-button-settings>Cor do texto<input data-email-button-color type="color" value="#ffffff"></label><label data-email-button-settings>Texto do botão<input data-email-button-text maxlength="80"></label>';editor.after(panel);const choose=target=>{selected=target?.closest('img,a')||null;if(selected&&!editor.contains(selected))selected=null;const image=selected?.tagName==='IMG',button=selected?.tagName==='A';panel.hidden=!image&&!button;if(panel.hidden)return;panel.querySelector('[data-email-element-title]').textContent=image?'Imagem selecionada':'Botão selecionado';panel.querySelectorAll('[data-email-image-settings]').forEach(x=>x.hidden=!image);panel.querySelectorAll('[data-email-button-settings]').forEach(x=>x.hidden=!button);if(image){panel.querySelector('[data-email-image-width]').value=selected.style.width||'100%';panel.querySelector('[data-email-image-px]').value=selected.style.width.endsWith('px')?parseInt(selected.style.width,10):'';panel.querySelector('[data-email-image-alt]').value=selected.alt||'';}if(button){panel.querySelector('[data-email-button-bg]').value=selected.style.backgroundColor?rgbToHex(selected.style.backgroundColor):'#2563eb';panel.querySelector('[data-email-button-color]').value=selected.style.color?rgbToHex(selected.style.color):'#ffffff';panel.querySelector('[data-email-button-text]').value=selected.textContent||'';}};const rgbToHex=value=>{const match=value.match(/\d+/g);return match?.length>=3?'#'+match.slice(0,3).map(n=>Number(n).toString(16).padStart(2,'0')).join(''):/^#[0-9a-f]{6}$/i.test(value)?value:'#2563eb';};editor.addEventListener('click',e=>{if(e.target.closest?.('a'))e.preventDefault();choose(e.target);});panel.querySelector('[data-email-image-width]').onchange=e=>{if(selected?.tagName!=='IMG')return;selected.style.width=e.target.value;selected.style.maxWidth='100%';selected.style.height='auto';changed();};panel.querySelector('[data-email-image-px]').oninput=e=>{if(selected?.tagName!=='IMG'||!e.target.value)return;const width=Math.min(1200,Math.max(50,Number(e.target.value)||50));selected.style.width=width+'px';selected.style.maxWidth='100%';selected.style.height='auto';changed();};panel.querySelector('[data-email-image-alt]').oninput=e=>{if(selected?.tagName==='IMG'){selected.alt=e.target.value;changed();}};panel.querySelector('[data-email-button-bg]').oninput=e=>{if(selected?.tagName==='A'){selected.style.backgroundColor=e.target.value;changed();}};panel.querySelector('[data-email-button-color]').oninput=e=>{if(selected?.tagName==='A'){selected.style.color=e.target.value;changed();}};panel.querySelector('[data-email-button-text]').oninput=e=>{if(selected?.tagName==='A'){selected.textContent=e.target.value;changed();}};};
    return {prepareEmailEditor,enhanceEmailStep,extendEmailControls};
  }
  async function abrirEditorDoBlocoEmail(ws,node,onSave){
    const current=node.data||{},host=document.createElement('div');
    host.className='atd-flow-overlay atd-email-composer-overlay';
    host.innerHTML=`<section class="atd-email-composer-window" role="dialog" aria-modal="true" aria-label="Configurar e-mail da automação">
      <header class="atd-email-composer-head"><div><h2>Configurar e-mail</h2><p>Use o mesmo editor e a mesma prévia de Envios.</p></div><button type="button" class="btn" data-email-close>Fechar</button></header>
      <div class="atd-email-composer-body"><div class="atd-email-composer-library"><div><b>Usar um e-mail de Envios</b><small>O conteúdo será copiado para este bloco. Alterações futuras no modelo ou na transmissão não modificarão o fluxo.</small></div><label>Modelo salvo<select data-email-source-model><option value="">Carregando modelos…</option></select></label><button type="button" class="btn" data-email-model-load disabled>Usar modelo</button><details><summary>Usar e-mail de uma transmissão anterior</summary><div class="atd-email-composer-transmission"><label>Campanha<select data-email-source-campaign><option value="">Carregando campanhas…</option></select></label><label>E-mail<select data-email-source-step disabled><option value="">Escolha uma campanha</option></select></label><button type="button" class="btn" data-email-source-load disabled>Usar e-mail</button></div></details><small data-email-source-status></small></div>
      <fieldset class="atd-tx-email-step"><legend>E-mail da automação</legend><label class="atd-email-subject">Assunto<input data-email-subject maxlength="180" value="${esc(current.assunto||'')}" placeholder="Olá, {{primeiro_nome}}"><small>Variáveis: {{primeiro_nome}}, {{nome}}, {{email}}.</small></label><div class="atd-email-workspace"><div class="atd-email-compose"><div class="atd-email-area-title"><b>Conteúdo da mensagem</b><span>Formate o texto e insira imagens ou botões.</span></div><label>Conteúdo HTML<textarea data-email-html maxlength="100000">${esc(current.html||'')}</textarea></label></div><div class="atd-email-preview"><div class="atd-email-preview-head"><b>Prévia do destinatário</b><div role="group" aria-label="Tamanho da prévia"><button type="button" class="btn sm pri" data-email-size="desktop">Desktop</button><button type="button" class="btn sm" data-email-size="mobile">Celular</button></div></div><div class="atd-email-preview-meta"><span>Para: contato@exemplo.com</span><strong data-email-preview-subject>Assunto do e-mail</strong></div><iframe title="Prévia do corpo do e-mail" sandbox="" data-email-preview-frame></iframe><p class="muted">Prévia ilustrativa. O tamanho final depende do aplicativo de e-mail.</p></div></div></fieldset></div>
      <footer class="atd-email-composer-foot"><span class="muted">O envio usará o domínio verificado deste workspace.</span><div><button type="button" class="btn" data-email-close>Cancelar</button><button type="button" class="btn pri" data-email-save>Salvar neste bloco</button></div></footer></section>`;
    document.body.append(host);
    const close=()=>host.remove(),step=host.querySelector('.atd-tx-email-step');
    host.querySelectorAll('[data-email-close]').forEach(button=>button.onclick=close);
    const {prepareEmailEditor,enhanceEmailStep,extendEmailControls}=emailComposerTools(ws);
    prepareEmailEditor(step);enhanceEmailStep(step);extendEmailControls(step);
    const model=host.querySelector('[data-email-source-model]'),useModel=host.querySelector('[data-email-model-load]'),campaign=host.querySelector('[data-email-source-campaign]'),choice=host.querySelector('[data-email-source-step]'),load=host.querySelector('[data-email-source-load]'),status=host.querySelector('[data-email-source-status]');
    const useContent=(assunto,html)=>{
      const subject=step.querySelector('[data-email-subject]'),editor=step.querySelector('.atd-email-editor');subject.value=assunto||'';editor.innerHTML=html||'';
      subject.dispatchEvent(new Event('input',{bubbles:true}));editor.dispatchEvent(new Event('input',{bubbles:true}));
      status.textContent='Conteúdo copiado. Revise a prévia e salve o bloco.';
    };
    try{
      const result=await api('email-modelos-list',{},ws);if(!host.isConnected)return;
      model.innerHTML='<option value="">Selecione um modelo salvo…</option>'+(result.modelos||[]).map(m=>`<option value="${esc(m.id)}">${esc(m.nome)} · ${esc(m.assunto)}</option>`).join('');
      if(!result.modelos?.length)status.textContent='Nenhum modelo salvo. Use “Salvar como modelo” em Envios → E-mail.';
    }catch(error){if(host.isConnected){model.innerHTML='<option value="">Modelos indisponíveis</option>';status.textContent='Biblioteca indisponível: confira a migration e a Edge de Atendimento.';}}
    model.onchange=()=>{useModel.disabled=!model.value;};
    useModel.onclick=()=>act(async()=>{if(!model.value)return;const {modelo}=await api('email-modelo-get',{id:model.value},ws);useContent(modelo.assunto,modelo.html);});
    try{
      const campaigns=await q(sb.from('atd_email_campanhas').select('id,nome,criado_em').eq('workspace_id',ws).order('criado_em',{ascending:false}).limit(100));
      if(!host.isConnected)return;
      campaign.innerHTML='<option value="">Selecione uma campanha de Envios…</option>'+campaigns.map(c=>`<option value="${esc(c.id)}">${esc(c.nome)}</option>`).join('');
      if(!campaigns.length&&model.options.length<=1&&!status.textContent.startsWith('Biblioteca indisponível'))status.textContent='Ainda não há modelos ou transmissões salvas em Envios.';
    }catch(error){if(host.isConnected){campaign.innerHTML='<option value="">Campanhas indisponíveis</option>';status.textContent='Não foi possível carregar Envios: '+error.message;}}
    campaign.onchange=async()=>{
      choice.disabled=true;load.disabled=true;choice.innerHTML='<option value="">Carregando e-mails…</option>';status.textContent='';
      if(!campaign.value){choice.innerHTML='<option value="">Escolha uma campanha</option>';return;}
      const selectedCampaign=campaign.value;
      try{
        const samples=await Promise.all(Array.from({length:10},(_,i)=>q(sb.from('atd_email_envios').select('etapa,assunto').eq('workspace_id',ws).eq('campanha_id',selectedCampaign).eq('etapa',i+1).limit(1).maybeSingle())));
        if(!host.isConnected||campaign.value!==selectedCampaign)return;
        choice.innerHTML='<option value="">Selecione um e-mail…</option>'+samples.filter(Boolean).map(s=>`<option value="${s.etapa}">E-mail ${s.etapa} · ${esc(s.assunto)}</option>`).join('');
        choice.disabled=!samples.some(Boolean);if(choice.disabled)status.textContent='Esta campanha não tem e-mails salvos para reutilizar.';
      }catch(error){if(host.isConnected&&campaign.value===selectedCampaign){choice.innerHTML='<option value="">E-mails indisponíveis</option>';status.textContent=error.message;}}
    };
    choice.onchange=()=>{load.disabled=!choice.value;};
    load.onclick=()=>act(async()=>{
      if(!campaign.value||!choice.value)return;
      const sample=await q(sb.from('atd_email_envios').select('assunto,corpo_html').eq('workspace_id',ws).eq('campanha_id',campaign.value).eq('etapa',Number(choice.value)).limit(1).maybeSingle());
      if(!sample)throw Error('Este e-mail não foi encontrado em Envios. Atualize a lista.');
      useContent(sample.assunto,sample.corpo_html);
    });
    host.querySelector('[data-email-save]').onclick=()=>act(async()=>{
      const assunto=step.querySelector('[data-email-subject]').value.trim(),html=step.querySelector('.atd-email-editor').innerHTML.trim();
      if(!assunto||assunto.length>180||!html||html.length>100000)throw Error('Informe assunto e conteúdo com até 100.000 caracteres.');
      node.data={...node.data,assunto,html};onSave();close();toast('E-mail configurado no bloco. Salve o canvas para persistir o fluxo.');
    });
  }
  function conectarEditorAosBlocosEmail(stage,getNode,ws,renderGraph){
    const decorate=()=>stage.querySelectorAll('.atd-flow-email[data-node]').forEach(card=>{
      const node=getNode(card.dataset.node);if(!node)return;
      const body=card.querySelector('.atd-flow-node-body');if(!body)return;
      body.innerHTML=`<b>${esc(node.data?.assunto||'E-mail sem assunto')}</b><small>${node.data?.html?'Conteúdo configurado · abra para editar':'Configure o conteúdo e a prévia do e-mail.'}</small><button type="button" class="btn sm pri" data-email-compose>Editar e-mail</button>`;
      body.querySelector('[data-email-compose]').onclick=()=>abrirEditorDoBlocoEmail(ws,node,renderGraph);
    });
    const observer=new MutationObserver(decorate);observer.observe(stage,{childList:true});decorate();
  }
  async function vTransmissao(m){
    stop();++A.token;const ws=S.ws,route=S.view;m.innerHTML='<div class="head"><div><h1>'+ (S.view==='atd-envios-email'?'Envios de e-mail':S.view==='atd-envios-oficial'?'Envios por WhatsApp Oficial':'Transmissão')+'</h1><span class="muted">Segmente contatos e prepare o envio pelo canal selecionado.</span></div></div><div id="atdTransmissao" class="atd-transmissao">Carregando contatos e canais…</div>';
    try{
      const [ctx,channels,custom]=await Promise.all([
        api('contexto',{},ws),q(sb.from('atd_canais').select('id,nome,numero,externo_id,status,ativo').eq('workspace_id',ws).eq('provedor','zernio').eq('canal','whatsapp').eq('ativo',true).eq('status','conectado').order('nome')),
        q(sb.from('campos_personalizados').select('chave,rotulo').eq('workspace_id',ws).eq('entidade','pessoas').order('rotulo')).catch(()=>[])
      ]);
      if(S.ws!==ws||S.view!==route)return;
      const root=$('#atdTransmissao'),canalOptions=channels.map(c=>`<option value="${esc(c.id)}">${esc(c.nome)} · ${esc(c.numero||c.externo_id)} · ${esc(c.status)}</option>`).join('');
      let contacts=[],campaignNames=new Map(),templates=[],selected=new Set(),timer=null,running=false;
      root.innerHTML=`<section class="panel atd-tx-config"><div class="atd-tx-controls"><label>Conta WhatsApp oficial<select id="txCanal"><option value="">Selecione uma conta conectada…</option>${canalOptions}</select></label><label>Buscar contato<input id="txBusca" type="search" placeholder="Nome, telefone ou e-mail"></label><label>Tipo<select id="txTipo"><option value="">Leads e alunos</option><option value="lead">Leads</option><option value="cliente">Alunos/clientes</option></select></label><label>Qualificação<select id="txQual"><option value="">Todas</option><option value="qualificado">Qualificado</option><option value="pendente">Pendente</option><option value="nao_qualificado">Não qualificado</option></select></label><label>Campanha<select id="txCampanha"><option value="">Todas as campanhas</option></select></label><label>Tag<select id="txTag"><option value="">Todas as tags</option></select></label></div><div class="atd-tx-select"><b id="txContagem">0 contatos encontrados · 0 selecionados</b><button type="button" class="btn sm" id="txSelecionar">Selecionar contatos filtrados</button><button type="button" class="btn sm" id="txLimpar">Limpar seleção</button><button type="button" class="btn sm" id="txGerirContatos">Importar contatos e gerenciar tags</button></div><div class="atd-tx-lista" id="txLista"></div></section><section class="panel atd-tx-envio"><h3>Configurar transmissão</h3><label>Template aprovado<select id="txTemplate" disabled><option value="">Selecione primeiro a conta</option></select></label><div id="txTemplatePreview"></div><div id="txVariaveis"></div><div class="atd-tx-controls atd-tx-send-controls"><label>Intervalo entre envios<select id="txIntervalo"><option value="1">1 segundo</option><option value="2" selected>2 segundos</option><option value="5">5 segundos</option><option value="10">10 segundos</option></select></label><span class="muted">Até 500 contatos por transmissão. Mantenha esta tela aberta durante o envio.</span></div><button type="button" class="btn pri" id="txEnviar" disabled>Enviar para contatos selecionados</button><div id="txProgresso" aria-live="polite"></div></section>`;
      const list=root.querySelector('#txLista'),fieldRows=[['primeiro_nome','Primeiro nome',p=>String(p.nome||'').trim().split(/\s+/)[0]],['nome','Nome',p=>p.nome],['telefone','Telefone',p=>p.telefone],['email','E-mail',p=>p.email],['status_funil','Status do funil',p=>p.status_funil],['status_cliente','Status do cliente',p=>p.status_cliente],['qualificacao','Qualificação',p=>p.qualificacao],['utm_source','UTM · Fonte',p=>p.utm_source],['utm_medium','UTM · Mídia',p=>p.utm_medium],['utm_campaign','UTM · Campanha',p=>p.utm_campaign],['utm_content','UTM · Conteúdo',p=>p.utm_content],['utm_term','UTM · Termo',p=>p.utm_term],['pagina_origem','Página de entrada',p=>p.pagina_origem],['criado_em','Data de captura',p=>p.criado_em?new Date(p.criado_em).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):''],...custom.map(c=>['extra:'+c.chave,c.rotulo+' · personalizado',p=>p.extras?.[c.chave]])];
      root.insertAdjacentHTML('afterbegin','<div class="acts atd-tx-modes"><button type="button" class="btn pri" id="txModeEmail">E-mail</button><button type="button" class="btn" id="txModeWhats">WhatsApp oficial</button></div>');
      root.insertAdjacentHTML('beforeend',`<section class="panel atd-tx-envio atd-tx-email" id="txEmailPanel" hidden><h3>Transmissão de e-mail</h3><label>Nome da campanha<input id="txEmailNome" maxlength="160" value="Transmissão de e-mail"></label><div class="atd-tx-controls"><label>Data e hora inicial (horário de Brasília)<input type="datetime-local" id="txEmailInicio"></label><label>Intervalo entre envios<select id="txEmailIntervalo"><option value="1">1 segundo</option><option value="2" selected>2 segundos</option><option value="5">5 segundos</option><option value="10">10 segundos</option><option value="30">30 segundos</option></select></label></div><p class="muted">Filtros de tipo, qualificação, campanha e tag usam os controles acima. Cada etapa será registrada no histórico do contato. Variáveis disponíveis: <code>{{primeiro_nome}}</code>, <code>{{nome}}</code>, <code>{{email}}</code>.</p><div id="txEmailSteps"></div><div class="acts"><button type="button" class="btn" id="txEmailAddStep">Adicionar e-mail à sequência</button><button type="button" class="btn pri" id="txEmailSend">Agendar sequência para contatos selecionados</button></div><div id="txEmailNotice" aria-live="polite"></div></section><section class="panel atd-tx-email" id="txEmailCampaigns"><h3>Campanhas de e-mail recentes</h3><div id="txEmailCampaignList" class="muted">Carregando campanhas…</div></section>`);
      root.insertAdjacentHTML('beforeend',`<section class="panel atd-tx-email" id="txEmailDns" hidden><h3>Domínio e DNS do e-mail</h3><p class="muted">Cadastre o domínio no Resend para gerar os registros DNS. Copie-os para o provedor DNS do domínio e depois confira novamente. O Growth não altera seu DNS.</p><div class="atd-tx-controls"><label>Domínio de envio<input id="txDnsDomain" placeholder="seudominio.com.br"></label><button type="button" class="btn pri" id="txDnsCreate">Cadastrar domínio no Resend</button><button type="button" class="btn" id="txDnsRefresh">Atualizar domínios</button></div><div id="txDnsDomains" class="muted">Carregando domínios do Resend…</div><div id="txDnsRecords"></div></section>`);
      root.querySelector('#txDnsDomain').insertAdjacentHTML('afterend','<label>E-mail remetente<input id="txDnsFrom" type="email" placeholder="atendimento@seudominio.com.br"></label>');root.querySelector('#txDnsCreate').insertAdjacentHTML('beforebegin','<button type="button" class="btn" id="txDnsSaveFrom">Salvar remetente</button>');root.querySelector('#txDnsDomain').oninput=()=>{const d=root.querySelector('#txDnsDomain').value.trim(),from=root.querySelector('#txDnsFrom');if(!from.value&&d.includes('.'))from.value='atendimento@'+d;};
      let emailDomainId='';const renderDomainDetail=d=>{emailDomainId=d.id||emailDomainId;const records=d.records||[];root.querySelector('#txDnsDomain').value=d.name||'';root.querySelector('#txDnsFrom').value=d.email_remetente||root.querySelector('#txDnsFrom').value;const from=root.querySelector('#txDnsFrom');if(!from.value&&d.name)from.value='atendimento@'+d.name;const result=records.map((r,i)=>`<tr><td>${esc(r.type||r.record||'')}</td><td><code>${esc(r.name||'@')}</code> <button type="button" class="btn sm" data-copy-dns="name" data-index="${i}">Copiar</button></td><td style="max-width:420px;word-break:break-all"><code>${esc(r.value||'')}</code> <button type="button" class="btn sm" data-copy-dns="value" data-index="${i}">Copiar</button></td><td>${r.priority??'—'}</td><td>${esc(r.status||'—')}</td></tr>`).join('');root.querySelector('#txDnsRecords').innerHTML=`<div class="atd-email-domain-head"><b>${esc(d.name||'Domínio')}</b><span class="pill ${d.status==='verified'?'good':'warn'}">${esc(d.status||'status indisponível')}</span><button type="button" class="btn sm" id="txDnsVerify">Verificar novamente</button></div><div class="tw"><table><thead><tr><th>Tipo</th><th>Nome / host</th><th>Valor</th><th>Prioridade</th><th>Status</th></tr></thead><tbody>${result||'<tr><td colspan="5">O Resend ainda não retornou registros DNS para este domínio.</td></tr>'}</tbody></table></div><small class="muted">TTL: automático (ou o menor valor disponível no seu provedor). Não crie um segundo SPF no mesmo host; ajuste o registro SPF existente se o Resend indicar conflito.</small>`;root.querySelectorAll('[data-copy-dns]').forEach(b=>b.onclick=()=>{const r=records[Number(b.dataset.index)],value=r?.[b.dataset.copyDns];if(value)navigator.clipboard.writeText(value).then(()=>toast('Registro copiado.'));});root.querySelector('#txDnsVerify').onclick=()=>act(async()=>{const current=await api('email-dominio-verify',{id:emailDomainId},ws);renderDomainDetail(current);toast('Status DNS atualizado pelo Resend.');});};
      const loadEmailDomains=async()=>{const box=root.querySelector('#txDnsDomains');try{const r=await api('email-dominios-list',{},ws),domains=r.data||[];box.innerHTML=domains.map(d=>`<div class="atd-email-domain-row"><b>${esc(d.name)}</b><span class="pill ${d.status==='verified'?'good':'warn'}">${esc(d.status||'pendente')}</span><button type="button" class="btn sm" data-dns-open="${esc(d.id)}">Ver DNS</button></div>`).join('')||'<p class="muted">Nenhum domínio cadastrado no Resend.</p>';box.querySelectorAll('[data-dns-open]').forEach(b=>b.onclick=()=>act(async()=>renderDomainDetail(await api('email-dominio-get',{id:b.dataset.dnsOpen},ws))));}catch(e){box.innerHTML=`<p class="muted">${esc(e.message)}. Configure RESEND_API_KEY nas secrets da Edge.</p>`;}};
      root.querySelector('#txDnsCreate').onclick=()=>act(async()=>{const domain=root.querySelector('#txDnsDomain').value.trim(),from_email=root.querySelector('#txDnsFrom').value.trim();if(!domain)throw Error('Informe o domínio que usará nos endereços de envio.');if(!from_email)throw Error('Informe o e-mail remetente deste workspace.');if(!confirm(`Cadastrar ${domain} no Resend e gerar os registros DNS para este workspace?`))return;const result=await api('email-dominio-create',{domain,from_email},ws);renderDomainDetail({...result,email_remetente:from_email});toast('Domínio vinculado a este workspace. Copie os registros para o provedor DNS do cliente.');await loadEmailDomains();});root.querySelector('#txDnsSaveFrom').onclick=()=>act(async()=>{if(!emailDomainId)throw Error('Cadastre primeiro o domínio deste workspace.');const r=await api('email-dominio-remetente-save',{from_email:root.querySelector('#txDnsFrom').value.trim()},ws);toast('Remetente atualizado: '+r.email_remetente);});root.querySelector('#txDnsRefresh').onclick=()=>act(loadEmailDomains);loadEmailDomains();
      const emailLocal=new Date(Date.now()+10*60000);root.querySelector('#txEmailInicio').value=new Date(emailLocal.getTime()-emailLocal.getTimezoneOffset()*60000).toISOString().slice(0,16);
      let emailMode=true,emailStepCount=0;const addEmailStep=(delay=0)=>{const n=++emailStepCount,el=document.createElement('fieldset');el.className='atd-tx-email-step';el.dataset.step=String(n);el.innerHTML=`<legend>E-mail ${n}</legend><div class="atd-email-step-head"><div><b>Mensagem ${n}</b><span>Edite o conteúdo e confira a prévia antes de agendar.</span></div>${n>1?'<button type="button" class="btn sm" data-remove-email>Remover e-mail</button>':''}</div><label class="atd-email-subject">Assunto<input data-email-subject maxlength="180" required placeholder="Ex.: Olá, {{primeiro_nome}}"><small>Você pode usar {{primeiro_nome}}, {{nome}} e {{email}}.</small></label><div class="atd-email-workspace"><div class="atd-email-compose"><div class="atd-email-area-title"><b>Conteúdo da mensagem</b><span>Formate o texto e insira imagens ou botões.</span></div><label>Conteúdo HTML<textarea data-email-html rows="8" maxlength="100000" required placeholder="Escreva o HTML do e-mail; personalize com {{primeiro_nome}}."></textarea></label></div><div class="atd-email-preview"><div class="atd-email-preview-head"><b>Prévia do destinatário</b><div role="group" aria-label="Tamanho da prévia"><button type="button" class="btn sm pri" data-email-size="desktop">Desktop</button><button type="button" class="btn sm" data-email-size="mobile">Celular</button></div></div><div class="atd-email-preview-meta"><span>Para: contato@exemplo.com</span><strong data-email-preview-subject>Assunto do e-mail</strong></div><iframe title="Prévia do corpo do e-mail" sandbox="" data-email-preview-frame></iframe><p class="muted">Prévia ilustrativa. O tamanho final depende do aplicativo de e-mail.</p></div></div><label class="atd-email-delay">Esperar antes desta etapa<input data-email-delay type="number" min="0" max="525600" value="${delay}"><small>Minutos após a etapa anterior; use 0 para enviar na sequência.</small></label>`;el.querySelector('[data-remove-email]')?.addEventListener('click',()=>{el.remove();[...root.querySelectorAll('.atd-tx-email-step')].forEach((x,i)=>{x.dataset.step=String(i+1);x.querySelector('legend').textContent='E-mail '+(i+1);x.querySelector('.atd-email-step-head b').textContent='Mensagem '+(i+1);});emailStepCount=root.querySelectorAll('.atd-tx-email-step').length;});root.querySelector('#txEmailSteps').append(el);};addEmailStep();
      const {prepareEmailEditor,enhanceEmailStep,extendEmailControls}=emailComposerTools(ws);
      const prepareEmailStep=el=>{
        prepareEmailEditor(el);enhanceEmailStep(el);extendEmailControls(el);
        if(el.querySelector('[data-email-save-model]'))return;
        const button=document.createElement('button');button.type='button';button.className='btn sm';button.dataset.emailSaveModel='';button.textContent='Salvar como modelo';el.querySelector('.atd-email-step-head').append(button);
        button.onclick=()=>act(async()=>{
          if(!ctx.editar)throw Error('Seu perfil não tem permissão para salvar modelos.');
          const assunto=el.querySelector('[data-email-subject]').value.trim(),html=el.querySelector('.atd-email-editor').innerHTML.trim();
          if(!assunto||!html)throw Error('Preencha o assunto e o conteúdo antes de salvar.');
          const nome=prompt('Nome para reutilizar este e-mail:',root.querySelector('#txEmailNome').value.trim()+' · E-mail '+el.dataset.step)?.trim();
          if(!nome)return;
          await api('email-modelo-save',{nome,assunto,html},ws);toast('Modelo salvo. Ele já pode ser selecionado nas Automações.');
        });
      };
      root.querySelectorAll('.atd-tx-email-step').forEach(prepareEmailStep);
      const emailEditorObserver=new MutationObserver(rows=>rows.forEach(r=>r.addedNodes.forEach(n=>{if(n instanceof HTMLElement&&n.matches('.atd-tx-email-step'))prepareEmailStep(n);})));emailEditorObserver.observe(root.querySelector('#txEmailSteps'),{childList:true});
      root.addEventListener('input',e=>{if(e.target.matches?.('.atd-email-editor'))e.target.value=e.target.innerHTML;});root.querySelectorAll('.atd-email-editor').forEach(e=>e.value=e.innerHTML);
      const setEmailMode=on=>{emailMode=on;root.querySelector('.atd-tx-config #txCanal').closest('label').hidden=on;root.querySelector('.atd-tx-envio:not(.atd-tx-email)').hidden=on;root.querySelectorAll('.atd-tx-email').forEach(x=>x.hidden=!on);root.querySelector('#txModeEmail').classList.toggle('pri',on);root.querySelector('#txModeWhats').classList.toggle('pri',!on);};
      root.querySelector('#txModeEmail').onclick=()=>setEmailMode(true);root.querySelector('#txModeWhats').onclick=()=>setEmailMode(false);setEmailMode(S.view!=='atd-envios-oficial');root.querySelector('.atd-tx-modes').hidden=S.view!=='atd-transmissao';
      const valueFor=(p,key)=>{const row=fieldRows.find(x=>x[0]===key);return row?String(row[2](p)||'').trim():'';};
      const eligible=()=>{const term=root.querySelector('#txBusca').value.trim().toLocaleLowerCase('pt-BR'),tipo=root.querySelector('#txTipo').value,qual=root.querySelector('#txQual').value,camp=root.querySelector('#txCampanha').value,tag=root.querySelector('#txTag').value;return contacts.filter(p=>(!tipo||p.status_funil===tipo)&&(!qual||p.qualificacao===qual)&&(!camp||p.campanha_id===camp)&&(!tag||(p.tags||[]).includes(tag))&&(!term||[p.nome,p.telefone,p.email].some(x=>String(x||'').toLocaleLowerCase('pt-BR').includes(term))));};
      const renderContacts=()=>{const visible=eligible(),tagSel=root.querySelector('#txTag'),current=tagSel.value,tags=[...new Set(contacts.flatMap(p=>p.tags||[]))].sort((a,b)=>a.localeCompare(b,'pt-BR'));tagSel.innerHTML='<option value="">Todas as tags</option>'+tags.map(t=>`<option value="${esc(t)}">${esc(t)}</option>`).join('');tagSel.value=tags.includes(current)?current:'';root.querySelector('#txContagem').textContent=`${visible.length} contatos encontrados · ${selected.size} selecionados`;list.innerHTML=visible.slice(0,1000).map(p=>`<label class="atd-tx-contato"><input type="checkbox" data-tx-person="${esc(p.id)}" ${selected.has(p.id)?'checked':''}><span><b>${esc(p.nome||'Sem nome')}</b><small>${esc(p.telefone||'Sem telefone')} · ${esc(p.status_funil==='cliente'?'Aluno/cliente':'Lead')} · ${esc(p.qualificacao||'pendente')}${p.tags?.length?' · #'+esc(p.tags.join(' #')):''}${p.campanha_id?' · '+esc(campaignNames.get(p.campanha_id)||'Campanha'):''}</small></span></label>`).join('')||'<p class="muted">Nenhum contato para estes filtros.</p>';root.querySelectorAll('[data-tx-person]').forEach(cb=>cb.onchange=()=>{if(cb.checked){if(selected.size>=500){cb.checked=false;toast('O limite é de 500 contatos por transmissão.',true);return;}selected.add(cb.dataset.txPerson);}else selected.delete(cb.dataset.txPerson);renderContacts();});root.querySelector('#txEnviar').disabled=!ctx.editar||running||!selected.size||!root.querySelector('#txTemplate').value||!root.querySelector('#txCanal').value;};
      root.querySelector('#txEmailAddStep').onclick=()=>{if(emailStepCount>=10){toast('O limite é de 10 e-mails por sequência.',true);return;}addEmailStep(1440);};
      root.querySelector('#txEmailSend').onclick=()=>act(async()=>{if(!ctx.editar)throw Error('Seu perfil não tem permissão para transmitir.');const people=contacts.filter(p=>selected.has(p.id)),steps=[...root.querySelectorAll('.atd-tx-email-step')].map(el=>({assunto:el.querySelector('[data-email-subject]').value.trim(),html:el.querySelector('[data-email-html]').value.trim(),atraso_minutos:Number(el.querySelector('[data-email-delay]').value||0)})),inicio=new Date(root.querySelector('#txEmailInicio').value);if(!people.length)throw Error('Selecione os contatos na lista acima.');if(!Number.isFinite(inicio.getTime()))throw Error('Defina a data e o horário inicial.');if(steps.some(s=>!s.assunto||!s.html))throw Error('Preencha assunto e conteúdo de todas as etapas.');const filtros={tipo:root.querySelector('#txTipo').value,qualificacao:root.querySelector('#txQual').value,campanha_id:root.querySelector('#txCampanha').value,tag:root.querySelector('#txTag').value};if(!confirm(`Agendar ${steps.length} e-mail(s) para até ${people.length} contatos em ${inicio.toLocaleString('pt-BR')}?`))return;const r=await api('email-transmissao-create',{nome:root.querySelector('#txEmailNome').value.trim(),inicio_em:inicio.toISOString(),intervalo_segundos:Number(root.querySelector('#txEmailIntervalo').value),filtros,pessoa_ids:people.map(p=>p.id),etapas:steps},ws);toast(`Sequência agendada: ${r.contatos} contatos · ${r.envios} e-mails.`);await loadEmailCampaigns();});
      const loadEmailCampaigns=async()=>{const box=root.querySelector('#txEmailCampaignList');try{const r=await api('email-transmissao-list',{},ws),rows=r.campanhas||[],jobs=r.envios||[];box.innerHTML=rows.map(c=>{const own=jobs.filter(j=>j.campanha_id===c.id),counts={pendente:own.filter(x=>x.status==='pendente').length,processando:own.filter(x=>x.status==='processando').length,enviado:own.filter(x=>x.status==='enviado').length,erro:own.filter(x=>['erro','incerto'].includes(x.status)).length,ignorado:own.filter(x=>x.status==='ignorado').length};return `<article class="atd-email-campaign"><div><b>${esc(c.nome)}</b><span class="pill ${c.status==='concluida'?'good':c.status==='cancelada'?'neutral':'warn'}">${esc(c.status)}</span></div><small>${new Date(c.inicio_em).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})} · ${counts.enviado} enviados · ${counts.pendente} pendentes · ${counts.erro} falhas · ${counts.ignorado} ignorados</small><details><summary>Ver envios e etapas (${own.length})</summary><div class="atd-email-campaign-jobs">${own.map(j=>`<div><span>${esc(j.status)}</span> · E-mail ${j.etapa} · ${esc(j.email)} · ${esc(j.assunto)}${j.erro?' · '+esc(j.erro):''}</div>`).join('')||'Nenhum envio'}</div></details>${['agendada','em_execucao'].includes(c.status)?`<button type="button" class="btn sm" data-email-cancel="${esc(c.id)}">Cancelar pendentes</button>`:''}</article>`;}).join('')||'<p class="muted">Nenhuma transmissão de e-mail ainda.</p>';box.querySelectorAll('[data-email-cancel]').forEach(b=>b.onclick=()=>act(async()=>{if(!confirm('Cancelar os e-mails que ainda estão pendentes?'))return;await api('email-transmissao-cancel',{id:b.dataset.emailCancel},ws);toast('Envios pendentes cancelados.');await loadEmailCampaigns();}));}catch(e){box.innerHTML=`<p class="muted">${esc(e.message)} · Confira se a migration e a Edge já foram aplicadas.</p>`;}};await loadEmailCampaigns();
      let from=0;while(true){const page=await q(sb.from('pessoas').select('id,nome,telefone,email,status_funil,status_cliente,qualificacao,tags,utm_source,utm_medium,utm_campaign,utm_content,utm_term,pagina_origem,campanha_id,criado_em,extras').eq('workspace_id',ws).order('criado_em',{ascending:false}).range(from,from+499));contacts.push(...page);if(page.length<500)break;from+=500;}
      if(S.ws!==ws||S.view!==route)return;
      const campaignIds=[...new Set(contacts.map(p=>p.campanha_id).filter(Boolean))];for(let i=0;i<campaignIds.length;i+=100){const cs=await q(sb.from('campanhas').select('id,nome').eq('workspace_id',ws).in('id',campaignIds.slice(i,i+100)));cs.forEach(c=>campaignNames.set(c.id,c.nome));}
      root.querySelector('#txCampanha').insertAdjacentHTML('beforeend',[...campaignNames].sort((a,b)=>a[1].localeCompare(b[1],'pt-BR')).map(([id,n])=>`<option value="${esc(id)}">${esc(n)}</option>`).join(''));
      const renderTemplate=()=>{const index=Number(root.querySelector('#txTemplate').value),t=templates[index],vars=root.querySelector('#txVariaveis'),preview=root.querySelector('#txTemplatePreview');if(!t){vars.innerHTML='';preview.innerHTML='';renderContacts();return;}const parts=t.components||[],header=parts.find(c=>String(c.type).toUpperCase()==='HEADER'),body=parts.find(c=>String(c.type).toUpperCase()==='BODY'),buttons=parts.find(c=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[],format=String(header?.format||'TEXT').toUpperCase(),slots=[];const add=(text,kind,index=-1)=>{const ms=[...String(text||'').matchAll(/\{\{(\d+)\}\}/g)];[...new Set(ms.map(x=>Number(x[1])))].sort((a,b)=>a-b).forEach(marker=>slots.push({kind,index,marker,label:`${kind==='header'?'Cabeçalho':kind==='body'?'Corpo':'Link do botão '+(index+1)} · {{${marker}}}`}));};if(format==='TEXT')add(header?.text,'header');add(body?.text,'body');buttons.forEach((b,i)=>{if(String(b.type).toUpperCase()==='URL')add(b.url,'url',i);});vars.dataset.slots=JSON.stringify(slots);vars.innerHTML=slots.map((s,i)=>`<label>${esc(s.label)}<select data-tx-map="${i}" required><option value="">Selecione o campo que preenche esta variável…</option>${fieldRows.map(([key,label])=>`<option value="${esc(key)}">${esc(label)}</option>`).join('')}</select></label>`).join('')||'<p class="muted">Este template não contém variáveis de texto.</p>';const media=['IMAGE','VIDEO','DOCUMENT'].includes(format)?`<fieldset><legend>Cabeçalho de mídia</legend><label>URL HTTPS pública ou ID de mídia<input id="txMedia" placeholder="${format==='IMAGE'?'https://…/imagem.jpg':format==='VIDEO'?'https://…/video.mp4':'https://…/arquivo.pdf'}"></label><label>Tipo da referência<select id="txMediaMode"><option value="link">URL pública</option><option value="id">ID de mídia Meta</option></select></label></fieldset>`:'';const extras=buttons.map((b,i)=>{const type=String(b.type||'').toUpperCase();if(!['FLOW','COPY_CODE'].includes(type))return '';return `<label>Botão ${i+1} · ${type==='FLOW'?'token do formulário':'código do cupom'}<input data-tx-button="${i}" data-tx-subtype="${type==='FLOW'?'flow':'copy_code'}" required></label>`;}).join('');if(media||extras)vars.insertAdjacentHTML('beforeend',media+extras);preview.innerHTML=`<div class="atd-tx-modelo"><b>${esc(t.name)}</b> · ${esc(t.language)}<p>${esc(body?.text||'Template sem corpo de texto')}</p>${header?.text?`<small>Cabeçalho: ${esc(header.text)}</small>`:''}</div>`;renderContacts();};
      const loadTemplates=async()=>{const id=root.querySelector('#txCanal').value,select=root.querySelector('#txTemplate');templates=[];selected.clear();if(!id){select.innerHTML='<option value="">Selecione primeiro a conta</option>';select.disabled=true;renderTemplate();return;}select.innerHTML='<option value="">Carregando templates…</option>';select.disabled=true;try{const r=await api('templates-list',{canal_id:id},ws);templates=(r.templates||[]).filter(t=>t.status==='APPROVED'&&(t.components||[]).every(c=>{const type=String(c.type||'').toUpperCase();return type==='HEADER'?['TEXT','IMAGE','VIDEO','DOCUMENT'].includes(String(c.format||'TEXT').toUpperCase()):type==='BODY'||type==='FOOTER'||type==='BUTTONS'&&(c.buttons||[]).every(b=>['QUICK_REPLY','URL','PHONE_NUMBER','COPY_CODE','FLOW'].includes(String(b.type||'').toUpperCase()));}));select.innerHTML='<option value="">Selecione um template aprovado…</option>'+templates.map((t,i)=>`<option value="${i}">${esc(t.name)} · ${esc(t.language)}</option>`).join('');if(!templates.length)select.innerHTML='<option value="">Esta conta não tem templates compatíveis aprovados</option>';select.disabled=!templates.length;}catch(e){select.innerHTML='<option value="">Falha ao carregar templates</option>';toast(e.message,true);}renderTemplate();};
      for(const id of ['txBusca','txTipo','txQual','txCampanha','txTag'])root.querySelector('#'+id).addEventListener(id==='txBusca'?'input':'change',renderContacts);
      root.querySelector('#txGerirContatos').onclick=()=>{S.view='atd-contatos';render();};
      root.querySelector('#txSelecionar').onclick=()=>{const vis=eligible();for(const p of vis){if(selected.size>=500)break;selected.add(p.id);}renderContacts();};root.querySelector('#txLimpar').onclick=()=>{selected.clear();renderContacts();};root.querySelector('#txCanal').onchange=loadTemplates;root.querySelector('#txTemplate').onchange=renderTemplate;
      root.querySelector('#txEnviar').onclick=()=>{if(running)return;act(async()=>{const channelId=root.querySelector('#txCanal').value,t=templates[Number(root.querySelector('#txTemplate').value)],people=contacts.filter(p=>selected.has(p.id)),slots=JSON.parse(root.querySelector('#txVariaveis').dataset.slots||'[]'),paramsFor=p=>slots.map((_s,i)=>valueFor(p,root.querySelector(`[data-tx-map="${i}"]`).value)),buttonParams=[...root.querySelectorAll('[data-tx-button]')].map(el=>({index:Number(el.dataset.txButton),subType:el.dataset.txSubtype,value:el.value.trim()})),format=String(t?.components?.find(c=>String(c.type).toUpperCase()==='HEADER')?.format||'TEXT').toUpperCase(),mediaValue=root.querySelector('#txMedia')?.value.trim()||'',mode=root.querySelector('#txMediaMode')?.value||'link';if(!t||!channelId)throw Error('Selecione uma conta e um template aprovado.');if(!ctx.editar)throw Error('Seu perfil não tem permissão para enviar mensagens.');if(!ctx.nome)throw Error('Cadastre seu nome em Equipe e acessos antes de enviar.');if(!people.length||people.length>500)throw Error('Selecione de 1 a 500 contatos.');if(slots.some((_s,i)=>!root.querySelector(`[data-tx-map="${i}"]`).value))throw Error('Mapeie cada variável do template para um campo do contato.');if(buttonParams.some(x=>!x.value))throw Error('Preencha os dados dos botões do template.');const groups=new Map();slots.forEach(s=>{const key=s.kind+':'+s.index;groups.set(key,[...(groups.get(key)||[]),s.marker]);});for(const markers of groups.values()){const ordered=[...new Set(markers)].sort((a,b)=>a-b);if(ordered.some((n,i)=>n!==i+1))throw Error('As variáveis do template precisam seguir a ordem {{1}}, {{2}} etc.');}const media=['IMAGE','VIDEO','DOCUMENT'].includes(format);if(media&&!mediaValue)throw Error('Informe a URL pública ou ID de mídia para o cabeçalho deste template.');const eligiblePeople=people.filter(p=>String(p.telefone||'').replace(/\D/g,'').length>=10&&paramsFor(p).every(Boolean));if(!eligiblePeople.length)throw Error('Nenhum contato selecionado tem telefone e todos os dados necessários para as variáveis.');const skipped=people.length-eligiblePeople.length;if(!confirm(`Enviar “${t.name}” para ${eligiblePeople.length} contatos agora? ${skipped?skipped+' serão ignorados por telefone ou variável incompleta. ':''}Cada envio ficará salvo no histórico do contato.`))return;running=true;const btn=root.querySelector('#txEnviar'),progress=root.querySelector('#txProgresso');btn.disabled=true;let sent=0,failed=0;progress.innerHTML=`<div class="atd-tx-progress"><b>Transmissão em andamento</b><span>0 de ${eligiblePeople.length} enviados · ${skipped} ignorados</span><div id="txResultados"></div></div>`;const results=progress.querySelector('#txResultados'),canal=root.querySelector('#txCanal').value;for(let i=0;i<eligiblePeople.length;i++){const p=eligiblePeople[i];try{const opened=await api('criar-conversa-pessoa',{pessoa_id:p.id,canal_id:canal},ws),header_media=media?{type:format.toLowerCase(),[mode]:mediaValue}:null;await api('templates-send',{canal_id:canal,conversa_id:opened.conversa_id,template_name:t.name,idioma:t.language,parametros:paramsFor(p),header_media,button_params:buttonParams,requisicao_id:crypto.randomUUID()},ws);sent++;results.insertAdjacentHTML('beforeend',`<div><span class="pill good">Enviado</span> ${esc(p.nome)} · ${esc(p.telefone)}</div>`);}catch(e){failed++;results.insertAdjacentHTML('beforeend',`<div><span class="pill bad">Falhou</span> ${esc(p.nome)} · ${esc(e.message)}</div>`);}progress.querySelector('span').textContent=`${i+1} de ${eligiblePeople.length} processados · ${sent} enviados · ${failed} falhas · ${skipped} ignorados`;if(i<eligiblePeople.length-1)await new Promise(resolve=>setTimeout(resolve,Number(root.querySelector('#txIntervalo').value)*1000));}running=false;btn.disabled=false;toast(`Transmissão concluída: ${sent} enviados, ${failed} falhas e ${skipped} ignorados.`);renderContacts();});};
      renderContacts();if(channels.length)await loadTemplates();else{root.querySelector('#txLista').innerHTML='<p class="muted">Conecte uma conta de WhatsApp oficial em Atendimento → Canais e conexões para transmitir templates.</p>';}
    }catch(e){if(S.ws===ws&&S.view===route)$('#atdTransmissao').innerHTML=`<div class="empty"><b>Transmissão indisponível</b><p>${esc(e.message)}</p></div>`;}
  }
  async function vAutomacoes(m){
    stop();++A.token;const ws=S.ws,route=S.view,autoKind=S.view==='atd-auto-instagram'?'instagram':S.view==='atd-auto-oficial'?'oficial':S.view==='atd-auto-whatsapp'?'whatsapp':'';
    m.innerHTML='<div class="head"><div><h1>'+({instagram:'Automações · Instagram',oficial:'Automações · WhatsApp Oficial',whatsapp:'Automações · WhatsApp'}[autoKind]||'Automações')+'</h1><span class="muted">Crie jornadas com mensagens, dados do contato, condições e esperas.</span></div></div><div id="atdAutomacoes" class="panel">Carregando automações…</div>';
    try{
      const [ctx,flows,canais,execs]=await Promise.all([
        api('contexto',{},ws),api('automacoes-list',{},ws),
        q(sb.from('atd_canais').select('id,nome,provedor,canal,numero,status,ativo').eq('workspace_id',ws).eq('ativo',true).order('nome')),
        api('automacoes-execucoes',{},ws).catch(()=>({execucoes:[]}))
      ]);
      if(S.ws!==ws||S.view!==route)return;
      const root=$('#atdAutomacoes'),rows=flows.automacoes||[],runs=execs.execucoes||[],matchesRoute=c=>!autoKind||!c||(autoKind==='instagram'?c.canal==='instagram':autoKind==='oficial'?c.canal==='whatsapp'&&c.provedor==='zernio':c.canal==='whatsapp'&&c.provedor==='evolution');let conversationNames=new Map(),panel=sessionStorage.getItem('atd-auto-panel:'+ws)==='execucoes'?'execucoes':'fluxos',search='',statusFilter='';
      const carregaNomes=async()=>{const ids=[...new Set(runs.map(r=>r.conversa_id).filter(Boolean))];if(!ids.length){conversationNames=new Map();return;}const found=await q(sb.from('atd_conversas').select('id,nome').eq('workspace_id',ws).in('id',ids));conversationNames=new Map(found.map(c=>[c.id,c.nome]));};
      await carregaNomes();
      const channelName=id=>{const c=canais.find(x=>x.id===id);return !id?'Todos os canais compatíveis':c?nomeCanal(c)+' · '+identidadeCanal(c):'Canal removido';};
      const triggers=f=>f.gatilho_tipo==='qualquer_mensagem'?'Qualquer mensagem recebida':'Mensagem contém “'+esc(f.gatilho_valor)+'”';
      const render=()=>{
        root.innerHTML=`<div class="atd-auto-intro"><div><b>Fluxos de atendimento</b><p>Combine mensagens, templates, tags, campos, campanhas, formulários e e-mails. Ligue os blocos para criar a jornada do contato.</p></div>${ctx.editar?'<button class="btn pri" id="atdAutoNova">＋ Novo fluxo</button>':''}</div><div class="atd-auto-list">${rows.map((f,i)=>{const ns=f.fluxo?.nodes||[];return `<article class="atd-auto-card"><header><div><span class="pill ${f.ativo?'good':'warn'}">${f.ativo?'Ativa':'Rascunho'}</span><h3>${esc(f.nome)}</h3></div><span class="atd-auto-canal">${esc(channelName(f.canal_id))}</span></header><div class="atd-auto-flow"><div><small>GATILHO</small><b>${triggers(f)}</b></div><span aria-hidden="true">→</span><div><small>CANVAS</small><p>${ns.filter(n=>n.tipo!=='gatilho').length} blocos · ${esc(ns.filter(n=>['mensagem','botoes','template','tag','campo','campanha','formulario','email'].includes(n.tipo)).length)} ações · ${esc(ns.filter(n=>n.tipo==='espera').length)} esperas</p></div></div>${ctx.editar?`<footer><button class="btn sm" data-auto-edit="${i}">Abrir canvas</button><button class="btn sm" data-auto-toggle="${i}">${f.ativo?'Pausar':'Ativar'}</button><button class="btn sm bad" data-auto-delete="${i}">Excluir</button></footer>`:''}</article>`;}).join('')||'<div class="atd-auto-empty"><b>Nenhuma automação criada</b><p>Crie um fluxo e conecte ações, condições e tempos de espera no canvas.</p></div>'}</div><section class="atd-auto-runs"><h3>Execuções recentes</h3><p class="muted">Cada entrada representa um contato que acionou um fluxo.</p>${runs.length?`<div class="atd-auto-run-list">${runs.map(r=>`<div><span class="pill ${r.status==='enviado'?'good':r.status==='processando'||r.status==='aguardando'?'warn':'bad'}">${esc(r.status==='aguardando'?'Aguardando':r.status)}</span><b>${esc(rows.find(f=>f.id===r.automacao_id)?.nome||'Automação')}</b><span>${esc(conversationNames.get(r.conversa_id)||'Conversa')}</span><time>${fmt(r.retomar_em||r.executado_em)}</time>${r.erro?`<small class="atd-erro">${esc(r.erro)}</small>`:''}</div>`).join('')}</div>`:'<p>Nenhuma execução registrada ainda.</p>'}</section>`;
        const intro=root.querySelector('.atd-auto-intro'),list=root.querySelector('.atd-auto-list'),runsPanel=root.querySelector('.atd-auto-runs'),tabs=document.createElement('nav'),filters=document.createElement('div'),noResults=document.createElement('p');
        tabs.className='atd-auto-tabs';tabs.setAttribute('aria-label','Seções das automações');tabs.innerHTML=`<button type="button" class="btn" data-auto-panel="fluxos">Fluxos (${rows.length})</button><button type="button" class="btn" data-auto-panel="execucoes">Execuções (${runs.length})</button>`;
        filters.className='atd-auto-filters';filters.innerHTML=`<label>Buscar fluxo<input type="search" id="atdAutoBusca" placeholder="Nome ou gatilho…" value="${esc(search)}"></label><label>Situação<select id="atdAutoStatus"><option value="">Todas</option><option value="ativa">Ativas</option><option value="rascunho">Rascunhos</option></select></label>`;
        noResults.className='muted atd-auto-sem-filtro';noResults.textContent='Nenhum fluxo corresponde aos filtros.';noResults.hidden=true;
        root.replaceChildren(tabs,intro,filters,list,noResults,runsPanel);
        filters.querySelector('#atdAutoStatus').value=statusFilter;
        const applyFilters=()=>{search=filters.querySelector('#atdAutoBusca').value.toLocaleLowerCase().trim();statusFilter=filters.querySelector('#atdAutoStatus').value;let shown=0;list.querySelectorAll('.atd-auto-card').forEach((card,i)=>{const f=rows[i],visible=(!search||(f.nome+' '+(f.gatilho_valor||'')).toLocaleLowerCase().includes(search))&&(!statusFilter||((statusFilter==='ativa')===Boolean(f.ativo)))&&matchesRoute(canais.find(c=>c.id===f.canal_id));card.hidden=!visible;if(visible)shown++;});noResults.hidden=shown>0||rows.length===0;};
        const showPanel=id=>{panel=id;intro.hidden=id!=='fluxos';filters.hidden=id!=='fluxos';list.hidden=id!=='fluxos';noResults.hidden=id!=='fluxos'||noResults.dataset.empty!=='true';runsPanel.hidden=id!=='execucoes';tabs.querySelectorAll('[data-auto-panel]').forEach(button=>{button.classList.toggle('pri',button.dataset.autoPanel===id);button.setAttribute('aria-current',button.dataset.autoPanel===id?'page':'false');});sessionStorage.setItem('atd-auto-panel:'+ws,id);};
        const filter=()=>{applyFilters();noResults.dataset.empty=noResults.hidden?'false':'true';};
        filters.oninput=filter;filters.onchange=filter;filter();tabs.querySelectorAll('[data-auto-panel]').forEach(button=>button.onclick=()=>showPanel(button.dataset.autoPanel));showPanel(panel);
        $('#atdAutoNova')?.addEventListener('click',()=>editor());
        root.querySelectorAll('[data-auto-edit]').forEach(b=>b.onclick=()=>editor(rows[Number(b.dataset.autoEdit)]));
        root.querySelectorAll('[data-auto-toggle]').forEach(b=>b.onclick=()=>act(async()=>{const f=rows[Number(b.dataset.autoToggle)];await api('automacoes-save',{...f,ativo:!f.ativo},ws);toast(f.ativo?'Automação pausada.':'Automação ativada.');await load();}));
        root.querySelectorAll('[data-auto-delete]').forEach(b=>b.onclick=()=>act(async()=>{const f=rows[Number(b.dataset.autoDelete)];if(!confirm(`Excluir a automação “${f.nome}”? O histórico das execuções dela também será removido.`))return;await api('automacoes-delete',{id:f.id},ws);toast('Automação excluída.');await load();}));
      };
      const editor=f=>{
        const canaisValidos=canais.filter(c=>((c.canal==='instagram'&&c.provedor==='zernio')||(c.canal==='whatsapp'&&['zernio','evolution'].includes(c.provedor)))&&matchesRoute(c));
        const options=(autoKind?'':'<option value="">Todos os canais compatíveis</option>')+canaisValidos.map(c=>`<option value="${esc(c.id)}"${f?.canal_id===c.id?' selected':''}>${esc(nomeCanal(c)+' · '+identidadeCanal(c))}</option>`).join('');
        const base=JSON.parse(JSON.stringify(f?.fluxo||{}));let nodes=Array.isArray(base.nodes)?base.nodes:[],edges=Array.isArray(base.edges)?base.edges:[];
        if(!nodes.some(n=>n.tipo==='gatilho'))nodes.unshift({id:crypto.randomUUID(),tipo:'gatilho',x:40,y:190,data:{}});
        if(!nodes.some(n=>['mensagem','botoes','template','tag','campo','campanha','formulario','email'].includes(n.tipo))){const msg={id:crypto.randomUUID(),tipo:'mensagem',x:390,y:190,data:{texto:f?.resposta||'Olá, {{nome}}! Como posso ajudar?'}};nodes.push(msg);edges.push({origem:nodes[0].id,destino:msg.id,saida:'seguir'});}
        const host=document.createElement('div');host.className='atd-flow-overlay';host.innerHTML=`<section class="atd-flow-window"><header class="atd-flow-head"><div><h2>${f?'Editar':'Criar'} automação no canvas</h2><p>Configure o gatilho, monte o fluxo e conecte cada saída.</p></div><button type="button" class="btn" data-close>Fechar</button></header><div class="atd-flow-settings"><label>Nome do fluxo<input name="nome" required maxlength="120" value="${esc(f?.nome||'Novo fluxo')}"></label><label>Canal<select name="canal_id">${options}</select></label><label>Quando começar<select name="gatilho_tipo"><option value="palavra_chave"${!f||f.gatilho_tipo==='palavra_chave'?' selected':''}>Mensagem contém palavra-chave</option><option value="qualquer_mensagem"${f?.gatilho_tipo==='qualquer_mensagem'?' selected':''}>Qualquer mensagem recebida</option></select></label><label id="flowKeyword">Palavra ou trecho<input name="gatilho_valor" maxlength="100" value="${esc(f?.gatilho_valor||'')}" placeholder="preço"></label></div><div class="atd-flow-body"><aside class="atd-flow-palette"><b>Adicionar bloco</b><button type="button" data-add="mensagem">＋ Ação · Texto e mídia</button><button type="button" data-add="botoes">▣ Ação · Botões e links</button><button type="button" data-add="condicao">◇ Condição</button><button type="button" data-add="espera">◷ Tempo de espera</button><button type="button" data-add="fim">■ Encerrar fluxo</button><p>Arraste os blocos pelo cabeçalho e escolha o próximo bloco em cada saída.</p></aside><div class="atd-flow-stage"><div class="atd-flow-space" id="atdFlowSpace"></div></div></div><footer class="atd-flow-foot"><span class="muted">Mensagens recebidas disparam uma única execução por fluxo.</span><div><button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn pri" id="atdFlowSave">Salvar rascunho</button></div></footer></section>`;
        document.body.append(host);const stage=host.querySelector('#atdFlowSpace'),close=()=>host.remove();host.querySelectorAll('[data-close]').forEach(b=>b.onclick=close);
        const labels={gatilho:'Gatilho de entrada',mensagem:'Texto e mídia',botoes:'Botões e links',template:'Template WhatsApp API',tag:'Alterar tag',campo:'Preencher campo',campanha:'Inscrever em campanha',formulario:'Enviar formulário',email:'Enviar e-mail',condicao:'Condição',espera:'Aguardar',fim:'Encerrar'};
        const addTemplate=document.createElement('button');addTemplate.type='button';addTemplate.dataset.add='template';addTemplate.textContent='▤ Ação · Template WhatsApp API';host.querySelector('[data-add="botoes"]').after(addTemplate);
        const palette=host.querySelector('.atd-flow-palette');palette.querySelector('b').textContent='Mensagens e canais';
        const crmTitle=document.createElement('b');crmTitle.textContent='Dados e jornadas';addTemplate.after(crmTitle);
        let after=crmTitle;for(const [tipo,label] of [['tag','◇ Adicionar ou remover tag'],['campo','▦ Preencher campo personalizado'],['campanha','◎ Inscrever em campanha'],['formulario','▤ Enviar formulário'],['email','✉ Enviar e-mail']]){const button=document.createElement('button');button.type='button';button.dataset.add=tipo;button.textContent=label;after.after(button);after=button;}
        let campaigns=[],forms=[],customFields=[];
        const loadOptions=async()=>{try{[campaigns,forms,customFields]=await Promise.all([q(sb.from('campanhas').select('id,nome').eq('workspace_id',ws).order('nome')),q(sb.from('pesquisas').select('id,nome').eq('workspace_id',ws).eq('ativa',true).eq('aceita_link_aberto',true).order('nome')),q(sb.from('campos_personalizados').select('chave,rotulo,tipo').eq('workspace_id',ws).eq('entidade','pessoas').order('rotulo'))]);if(host.isConnected)renderGraph();}catch(e){toast('Não foi possível carregar campanhas, formulários ou campos: '+e.message,true);}};
        let approvedTemplates=[];
        const official=()=>canaisValidos.find(c=>c.id===host.querySelector('[name=canal_id]').value&&c.provedor==='zernio'&&c.canal==='whatsapp');
        const templateSlots=t=>{const parts=t.components||[],header=parts.find(c=>String(c.type).toUpperCase()==='HEADER'),body=parts.find(c=>String(c.type).toUpperCase()==='BODY'),buttons=parts.find(c=>String(c.type).toUpperCase()==='BUTTONS')?.buttons||[],slots=[];const add=(text,label)=>{[...new Set([...String(text||'').matchAll(/\{\{(\d+)\}\}/g)].map(m=>Number(m[1])))].sort((a,b)=>a-b).forEach(n=>slots.push(label+' · {{'+n+'}}'));};if(String(header?.format||'TEXT').toUpperCase()==='TEXT')add(header?.text,'Cabeçalho');add(body?.text,'Corpo');buttons.forEach((b,i)=>{if(String(b.type).toUpperCase()==='URL')add(b.url,'Link '+(i+1));});return slots;};
        const loadApproved=async()=>{const ch=official();approvedTemplates=[];addTemplate.disabled=!ch;addTemplate.title=ch?'':'Selecione uma conta WhatsApp API oficial';if(ch){try{const r=await api('templates-list',{canal_id:ch.id},ws);if(!host.isConnected||official()?.id!==ch.id)return;approvedTemplates=(r.templates||[]).filter(t=>t.status==='APPROVED'&&(t.components||[]).every(c=>{const type=String(c.type||'').toUpperCase();return type==='HEADER'?['TEXT','IMAGE','VIDEO','DOCUMENT'].includes(String(c.format||'TEXT').toUpperCase()):['BODY','FOOTER','BUTTONS'].includes(type)&&(!c.buttons||(c.buttons||[]).every(b=>['QUICK_REPLY','URL','PHONE_NUMBER'].includes(String(b.type||'').toUpperCase())));}));}catch(e){toast('Falha ao carregar templates: '+e.message,true);}}renderGraph();};
        const renderGraph=()=>{
          const w=Math.max(2300,...nodes.map(n=>(Number(n.x)||0)+350)),h=Math.max(1500,...nodes.map(n=>(Number(n.y)||0)+380)),byId=id=>nodes.find(n=>n.id===id),targets=(node,saida)=>edges.find(e=>e.origem===node.id&&e.saida===saida)?.destino||'';stage.style.width=w+'px';stage.style.height=h+'px';
          const edgeSvg=edges.map(e=>{const a=byId(e.origem),b=byId(e.destino);if(!a||!b)return '';const x1=Number(a.x)+260,y1=Number(a.y)+62,x2=Number(b.x),y2=Number(b.y)+62,k=Math.max(70,Math.abs(x2-x1)*.45);return `<path class="atd-flow-edge" d="M${x1},${y1} C${x1+k},${y1} ${x2-k},${y2} ${x2},${y2}" marker-end="url(#atdFlowArrow)"/>`;}).join('');
          const gatilhoTipo=host.querySelector('[name=gatilho_tipo]').value,gatilhoValor=host.querySelector('[name=gatilho_valor]').value;
          const nodeHtml=nodes.map(n=>{const d=n.data||{},outs=n.tipo==='condicao'?[['sim','Se sim'],['nao','Se não']]:n.tipo==='fim'?[]:[['seguir','Próximo bloco']];let fields='';
            if(n.tipo==='mensagem')fields=`<label>Texto / legenda<textarea data-field="texto" maxlength="4000" rows="3">${esc(d.texto||'')}</textarea></label><label>Tipo de conteúdo<select data-field="media_type"><option value=""${!d.media_type?' selected':''}>Somente texto</option><option value="imagem"${d.media_type==='imagem'?' selected':''}>Imagem</option><option value="video"${d.media_type==='video'?' selected':''}>Vídeo MP4</option><option value="audio"${d.media_type==='audio'?' selected':''}>Áudio</option><option value="documento"${d.media_type==='documento'?' selected':''}>Documento</option></select></label><label>URL pública HTTPS<input data-field="media_url" value="${esc(d.media_url||'')}" placeholder="https://…"></label><label>Ou enviar arquivo<input type="file" data-media-file accept="image/jpeg,image/png,image/webp,image/gif,video/mp4,audio/ogg,audio/mpeg,audio/mp4,audio/webm,audio/wav,application/pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv"><small data-media-status>${esc(d.media_nome||'Imagens, MP4 ou documentos até 8 MB.')}</small></label><small>Variáveis: {{nome}}, {{produto}}, {{campanha}}</small>`;
            if(n.tipo==='botoes')fields=`<label>Texto da mensagem<textarea data-field="texto" maxlength="1024" rows="3">${esc(d.texto||'')}</textarea></label><label>Rodapé opcional<input data-field="footer" maxlength="60" value="${esc(d.footer||'')}"></label>${[0,1,2].map(i=>{const b=d.buttons?.[i]||{};return `<div class="atd-flow-button-row"><b>Botão ${i+1}</b><select data-button-kind="${i}"><option value="reply"${b.kind!=='url'?' selected':''}>Resposta rápida</option><option value="url"${b.kind==='url'?' selected':''}>Abrir link</option></select><input data-button-title="${i}" maxlength="20" value="${esc(b.title||'')}" placeholder="Texto do botão"><input data-button-value="${i}" maxlength="500" value="${esc(b.value||'')}" placeholder="Resposta ou URL HTTPS"></div>`;}).join('')}<small>Use até 3 respostas rápidas ou um botão de link. WhatsApp e Instagram variam conforme o provedor.</small>`;
            if(n.tipo==='condicao')fields=`<label>Verificar<select data-field="campo"><option value="mensagem"${!d.campo||d.campo==='mensagem'?' selected':''}>Mensagem recebida</option><option value="tag"${d.campo==='tag'?' selected':''}>Tag do contato</option><option value="campanha"${d.campo==='campanha'?' selected':''}>Campanha do contato</option>${customFields.map(f=>`<option value="extra:${esc(f.chave)}"${d.campo==='extra:'+f.chave?' selected':''}>Campo · ${esc(f.rotulo)}</option>`).join('')}</select></label><label>Contém<input data-field="valor" maxlength="120" value="${esc(d.valor||'')}" placeholder="Valor a verificar"></label><small>Direcione as saídas “Se sim” e “Se não”.</small>`;
            if(n.tipo==='espera')fields=`<label>Tempo de espera<div class="atd-flow-wait"><input type="number" data-field="quantidade" min="1" max="86400" value="${esc(d.quantidade||1)}"><select data-field="unidade">${[['segundos','Segundos'],['minutos','Minutos'],['horas','Horas'],['dias','Dias']].map(([v,l])=>`<option value="${v}"${(d.unidade||'minutos')===v?' selected':''}>${l}</option>`).join('')}</select></div></label><small>O próximo passo retoma pelo agendador.</small>`;
            return `<article class="atd-flow-node atd-flow-${n.tipo}" data-node="${esc(n.id)}" style="left:${Number(n.x)||0}px;top:${Number(n.y)||0}px"><header class="atd-flow-node-head"><span>${n.tipo==='gatilho'?'⚡':n.tipo==='mensagem'?'↗':n.tipo==='botoes'?'▣':n.tipo==='template'?'▤':n.tipo==='tag'?'◇':n.tipo==='campo'?'▦':n.tipo==='campanha'?'◎':n.tipo==='formulario'?'▤':n.tipo==='email'?'✉':n.tipo==='condicao'?'◇':n.tipo==='espera'?'◷':'■'} ${labels[n.tipo]}</span>${n.tipo==='gatilho'?'':`<button type="button" data-remove="${esc(n.id)}" aria-label="Remover bloco">×</button>`}</header><div class="atd-flow-node-body">${n.tipo==='gatilho'?`<b>${gatilhoTipo==='qualquer_mensagem'?'Qualquer mensagem recebida':'Mensagem contém palavra-chave'}</b><small>${esc(gatilhoValor||'Configure o gatilho acima ao salvar')}</small>`:fields}</div>${outs.length?`<div class="atd-flow-outs">${outs.map(([saida,label])=>`<label>${label}<select data-link="${esc(n.id)}" data-branch="${saida}"><option value="">Sem conexão</option>${nodes.filter(x=>x.id!==n.id).map(x=>`<option value="${esc(x.id)}"${targets(n,saida)===x.id?' selected':''}>${esc(x.data?.rotulo||labels[x.tipo])}</option>`).join('')}</select></label>`).join('')}</div>`:''}</article>`;
          }).join('');
          stage.innerHTML=`<svg class="atd-flow-svg" width="${w}" height="${h}"><defs><marker id="atdFlowArrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z"/></marker></defs>${edgeSvg}</svg>${nodeHtml}`;
          stage.querySelectorAll('[data-node]').forEach(card=>{const n=byId(card.dataset.node);if(n.tipo!=='template')return;const d=n.data||{},tpl=approvedTemplates.find(t=>t.name===d.template_name&&t.language===d.idioma),slots=tpl?templateSlots(tpl):[],format=String(tpl?.components?.find(c=>String(c.type).toUpperCase()==='HEADER')?.format||'TEXT').toUpperCase(),body=card.querySelector('.atd-flow-node-body');body.innerHTML=`<label>Template aprovado<select data-template-select><option value="">Selecione um template…</option>${approvedTemplates.map(t=>`<option value="${esc(t.name+'|'+t.language)}"${t.name===d.template_name&&t.language===d.idioma?' selected':''}>${esc(t.name)} · ${esc(t.language)}</option>`).join('')}</select></label>${!approvedTemplates.length?'<small>Selecione uma conta oficial com templates aprovados.</small>':''}${slots.map((slot,i)=>`<label>${esc(slot)}<select data-template-map="${i}"><option value="">Escolher campo do contato…</option>${[['primeiro_nome','Primeiro nome'],['nome','Nome completo'],['telefone','Telefone'],['email','E-mail'],['produto','Produto'],['campanha','Campanha'],['capturado_em','Data de captura'],['qualificacao','Qualificação'],['status_funil','Status do funil'],['status_cliente','Status do cliente']].map(([key,label])=>`<option value="${key}"${d.campos?.[i]===key?' selected':''}>${label}</option>`).join('')}</select></label>`).join('')}${['IMAGE','VIDEO','DOCUMENT'].includes(format)?`<label>URL HTTPS da mídia do cabeçalho<input data-field="media_url" value="${esc(d.media_url||'')}" placeholder="https://…"></label>`:''}${tpl?`<small>Corpo: ${esc(tpl.components?.find(c=>String(c.type).toUpperCase()==='BODY')?.text||'')}</small>`:''}`;});
          stage.querySelectorAll('[data-template-select]').forEach(el=>el.onchange=()=>{const n=byId(el.closest('[data-node]').dataset.node),[name,language]=el.value.split('|');n.data={template_name:name||'',idioma:language||'',campos:[]};renderGraph();});
          stage.querySelectorAll('[data-template-map]').forEach(el=>el.onchange=()=>{const n=byId(el.closest('[data-node]').dataset.node);n.data.campos=n.data.campos||[];n.data.campos[Number(el.dataset.templateMap)]=el.value;});
          stage.querySelectorAll('[data-node]').forEach(card=>{const n=byId(card.dataset.node),d=n.data||{},body=card.querySelector('.atd-flow-node-body');if(n.tipo==='tag')body.innerHTML=`<label>Operação<select data-field="operacao"><option value="adicionar"${d.operacao!=='remover'?' selected':''}>Adicionar tag</option><option value="remover"${d.operacao==='remover'?' selected':''}>Remover tag</option></select></label><label>Nome da tag<input data-field="tag" maxlength="80" value="${esc(d.tag||'')}" placeholder="Ex.: interessado"></label>`;
            if(n.tipo==='campo')body.innerHTML=`<label>Campo do Lead/Aluno<select data-field="chave"><option value="">Selecione o campo…</option>${customFields.map(f=>`<option value="extra:${esc(f.chave)}"${d.chave==='extra:'+f.chave?' selected':''}>${esc(f.rotulo)}</option>`).join('')}</select></label><label>Valor<input data-field="valor" maxlength="500" value="${esc(d.valor||'')}" placeholder="Texto ou {{nome}}"></label>`;
            if(n.tipo==='campanha')body.innerHTML=`<label>Campanha<select data-field="campanha_id"><option value="">Selecione…</option>${campaigns.map(c=>`<option value="${esc(c.id)}"${d.campanha_id===c.id?' selected':''}>${esc(c.nome)}</option>`).join('')}</select></label><small>O vínculo aparece na jornada do contato.</small>`;
            if(n.tipo==='formulario')body.innerHTML=`<label>Formulário ativo<select data-field="pesquisa_id"><option value="">Selecione…</option>${forms.map(f=>`<option value="${esc(f.id)}"${d.pesquisa_id===f.id?' selected':''}>${esc(f.nome)}</option>`).join('')}</select></label><label>Texto do convite<textarea data-field="texto" maxlength="1000" rows="3">${esc(d.texto||'Responda ao formulário: {{link}}')}</textarea></label><label>URL publicada do Growth<input data-field="base_url" type="url" value="${esc(d.base_url||(/^https:$/.test(location.protocol)?location.origin+location.pathname:''))}" placeholder="https://seu-growth.com/"></label><small>Use {{link}} para inserir o formulário na mensagem.</small>`;
            if(n.tipo==='email')body.innerHTML=`<label>Assunto<input data-field="assunto" maxlength="180" value="${esc(d.assunto||'')}" placeholder="Olá, {{primeiro_nome}}"></label><label>Mensagem HTML<textarea data-field="html" maxlength="100000" rows="7" placeholder="<p>Olá, {{nome}}!</p>">${esc(d.html||'')}</textarea></label><small>Usa o domínio verificado em Transmissão → Domínio e DNS.</small>`;});
          stage.querySelectorAll('[data-field]').forEach(el=>{const update=()=>{const n=byId(el.closest('[data-node]').dataset.node);n.data=n.data||{};n.data[el.dataset.field]=el.value;};el.addEventListener('input',update);el.addEventListener('change',update);});
          const accepted=new Set(['image/jpeg','image/png','image/webp','image/gif','video/mp4','audio/ogg','audio/mpeg','audio/mp4','audio/webm','audio/wav','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain','text/csv']);
          stage.querySelectorAll('[data-media-file]').forEach(input=>input.onchange=async()=>{const file=input.files?.[0];if(!file)return;const n=byId(input.closest('[data-node]').dataset.node),status=input.parentElement.querySelector('[data-media-status]');if(file.size>8*1024*1024||!accepted.has(file.type)){toast('Formato não permitido ou arquivo acima de 8 MB.');input.value='';return;}status.textContent='Enviando arquivo…';try{const ext=(file.name.split('.').pop()||'bin').toLowerCase().replace(/[^a-z0-9]/g,'').slice(0,8),path=`${ws}/${crypto.randomUUID()}.${ext}`;const up=await sb.storage.from('atd-automacao-assets').upload(path,file,{upsert:false,contentType:file.type});if(up.error)throw up.error;const pub=sb.storage.from('atd-automacao-assets').getPublicUrl(path).data.publicUrl;n.data=n.data||{};n.data.media_url=pub;n.data.media_mime=file.type;n.data.media_nome=file.name;n.data.media_type=file.type.startsWith('image/')?'imagem':file.type.startsWith('audio/')?'audio':file.type==='video/mp4'?'video':'documento';renderGraph();toast('Arquivo adicionado ao bloco.');}catch(e){status.textContent='Falha no upload';toast('Não foi possível enviar o arquivo: '+(e.message||''));}});
          stage.querySelectorAll('[data-button-kind],[data-button-title],[data-button-value]').forEach(el=>el.addEventListener('input',()=>{const n=byId(el.closest('[data-node]').dataset.node),i=Number(el.dataset.buttonKind??el.dataset.buttonTitle??el.dataset.buttonValue);n.data=n.data||{};n.data.buttons=n.data.buttons||[];n.data.buttons[i]=n.data.buttons[i]||{};if(el.dataset.buttonKind!==undefined)n.data.buttons[i].kind=el.value;else if(el.dataset.buttonTitle!==undefined)n.data.buttons[i].title=el.value;else n.data.buttons[i].value=el.value;}));
          stage.querySelectorAll('[data-link]').forEach(el=>el.onchange=()=>{const origem=el.dataset.link,saida=el.dataset.branch;edges=edges.filter(x=>!(x.origem===origem&&x.saida===saida));if(el.value)edges.push({origem,destino:el.value,saida});renderGraph();});
          stage.querySelectorAll('[data-remove]').forEach(el=>el.onclick=()=>{const id=el.dataset.remove;nodes=nodes.filter(n=>n.id!==id);edges=edges.filter(e=>e.origem!==id&&e.destino!==id);renderGraph();});
          stage.querySelectorAll('.atd-flow-node:not(.atd-flow-gatilho) .atd-flow-node-head').forEach(head=>head.onpointerdown=e=>{if(e.target.closest('button'))return;const node=byId(head.closest('[data-node]').dataset.node),sx=e.clientX,sy=e.clientY,ox=Number(node.x),oy=Number(node.y);head.setPointerCapture?.(e.pointerId);const move=ev=>{node.x=Math.max(0,ox+ev.clientX-sx);node.y=Math.max(0,oy+ev.clientY-sy);head.closest('[data-node]').style.left=node.x+'px';head.closest('[data-node]').style.top=node.y+'px';};const done=()=>{document.removeEventListener('pointermove',move);document.removeEventListener('pointerup',done);renderGraph();};document.addEventListener('pointermove',move);document.addEventListener('pointerup',done,{once:true});});
        };
        conectarEditorAosBlocosEmail(stage,id=>nodes.find(n=>n.id===id),ws,renderGraph);
        host.querySelector('[name=canal_id]').onchange=()=>{nodes.filter(n=>n.tipo==='template').forEach(n=>n.data={});loadApproved();};
        const flowTools=document.createElement('div');flowTools.className='atd-flow-tools';flowTools.innerHTML='<span>Canvas do chatbot</span><button type="button" class="btn sm" data-flow-start>Ir ao início</button><button type="button" class="btn sm" data-flow-arrange>Organizar blocos</button>';host.querySelector('.atd-flow-body').before(flowTools);
        const goToStart=()=>{const first=nodes.find(n=>n.tipo==='gatilho');host.querySelector('.atd-flow-stage').scrollTo({left:0,top:Math.max(0,Number(first?.y||0)-30),behavior:'smooth'});};
        flowTools.querySelector('[data-flow-start]').onclick=goToStart;
        flowTools.querySelector('[data-flow-arrange]').onclick=()=>{const start=nodes.find(n=>n.tipo==='gatilho'),depths=new Map(),queue=start?[{id:start.id,depth:0}]:[];while(queue.length){const next=queue.shift();if(depths.has(next.id))continue;depths.set(next.id,next.depth);for(const edge of edges.filter(e=>e.origem===next.id))queue.push({id:edge.destino,depth:next.depth+1});}const counters=new Map(),orphanDepth=Math.max(0,...depths.values())+1;for(const node of nodes){const depth=depths.get(node.id)??orphanDepth,row=counters.get(depth)||0;node.x=40+depth*350;node.y=100+row*340;counters.set(depth,row+1);}renderGraph();goToStart();};
        host.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{const tipo=b.dataset.add,n=nodes.length,cols=Math.floor(n/3),row=n%3,previous=nodes.at(-1),node={id:crypto.randomUUID(),tipo,x:390+cols*350,y:100+row*350,data:['mensagem','botoes'].includes(tipo)?{texto:'',...(tipo==='botoes'?{buttons:[]}:{})}:tipo==='espera'?{quantidade:1,unidade:'minutos'}:tipo==='condicao'?{valor:''}:tipo==='tag'?{operacao:'adicionar',tag:''}:tipo==='formulario'?{texto:'Responda ao formulário: {{link}}',base_url:location.protocol==='https:'?location.origin+location.pathname:''}:{}};const canConnect=previous&&!['fim','condicao'].includes(previous.tipo)&&!edges.some(e=>e.origem===previous.id&&e.saida==='seguir');if(canConnect){node.x=Number(previous.x)+350;node.y=Number(previous.y);}nodes.push(node);if(canConnect)edges.push({origem:previous.id,destino:node.id,saida:'seguir'});renderGraph();});
        const trigger=host.querySelector('[name=gatilho_tipo]'),keyword=host.querySelector('#flowKeyword'),atualizaGatilho=()=>{const node=stage.querySelector('.atd-flow-gatilho .atd-flow-node-body');if(!node)return;node.querySelector('b').textContent=trigger.value==='qualquer_mensagem'?'Qualquer mensagem recebida':'Mensagem contém palavra-chave';node.querySelector('small').textContent=host.querySelector('[name=gatilho_valor]').value||'Configure o gatilho acima ao salvar';};trigger.onchange=()=>{keyword.hidden=trigger.value!=='palavra_chave';host.querySelector('[name=gatilho_valor]').required=trigger.value==='palavra_chave';atualizaGatilho();};host.querySelector('[name=gatilho_valor]').oninput=atualizaGatilho;trigger.onchange();
        host.querySelector('#atdFlowSave').onclick=()=>act(async()=>{const nome=host.querySelector('[name=nome]').value.trim(),gatilho_tipo=trigger.value,gatilho_valor=gatilho_tipo==='palavra_chave'?host.querySelector('[name=gatilho_valor]').value.trim():'';if(!nome)throw Error('Informe o nome do fluxo.');if(gatilho_tipo==='palavra_chave'&&!gatilho_valor)throw Error('Informe a palavra ou trecho do gatilho.');if(!nodes.some(n=>['mensagem','botoes','template','tag','campo','campanha','formulario','email'].includes(n.tipo)))throw Error('Adicione ao menos uma ação ao fluxo.');for(const n of nodes.filter(n=>n.tipo==='template')){const tpl=approvedTemplates.find(t=>t.name===n.data?.template_name&&t.language===n.data?.idioma);if(!official()||!tpl)throw Error('Selecione um template aprovado da conta oficial.');if(templateSlots(tpl).length!==(n.data.campos||[]).length||(n.data.campos||[]).some(x=>!x))throw Error('Mapeie todas as variáveis do template.');const format=String(tpl.components?.find(c=>String(c.type).toUpperCase()==='HEADER')?.format||'TEXT').toUpperCase();if(['IMAGE','VIDEO','DOCUMENT'].includes(format)&&!String(n.data.media_url||'').startsWith('https://'))throw Error('Informe a URL HTTPS da mídia do template.');}for(const n of nodes.filter(n=>n.tipo==='botoes')){const bs=(n.data?.buttons||[]).filter(b=>String(b.title||'').trim());if(!String(n.data?.texto||'').trim()||!bs.length)throw Error('Preencha o texto e ao menos um botão.');if(bs.some(b=>b.kind==='url'&&!/^https:\/\//i.test(b.value||'')))throw Error('Informe uma URL HTTPS para o botão de link.');if(bs.some(b=>b.kind==='url')&&bs.length>1)throw Error('O botão de link deve ser usado sozinho.');}const resposta=nodes.find(n=>n.tipo==='mensagem'||n.tipo==='botoes')?.data?.texto||'Fluxo visual';await api('automacoes-save',{id:f?.id,nome,canal_id:host.querySelector('[name=canal_id]').value||null,gatilho_tipo,gatilho_valor,resposta,fluxo:{versao:1,nodes,edges},ativo:f?.ativo===true},ws);close();toast(f?.ativo?'Fluxo ativo atualizado.':'Fluxo salvo como rascunho.');await load();});
        loadApproved();loadOptions();
      };
      const load=async()=>{const [r,e]=await Promise.all([api('automacoes-list',{},ws),api('automacoes-execucoes',{},ws).catch(()=>({execucoes:[]}))]);if(S.ws!==ws||S.view!==route)return;rows.splice(0,rows.length,...(r.automacoes||[]));runs.splice(0,runs.length,...(e.execucoes||[]));await carregaNomes();render();};
      render();
    }catch(e){if(S.ws===ws&&S.view===route)$('#atdAutomacoes').innerHTML=`<div class="empty"><b>Automações ainda não disponíveis</b><p>${esc(e.message)}</p><p>Confira a migration e a publicação da Edge de Atendimento.</p></div>`;}
  }
  async function vEmailAutomacoes(m){
    stop();++A.token;const ws=S.ws,route=S.view;m.innerHTML='<div class="head"><div><h1>Automações de e-mail</h1><span class="muted">Fluxos em canvas acionados por cadastro, resposta de formulário ou venda aprovada.</span></div><div class="acts"><button class="btn" id="atdEmailAutoReload">Atualizar</button></div></div><div id="atdEmailAutomacoes" class="panel">Carregando fluxos de e-mail…</div>';
    const root=$('#atdEmailAutomacoes');let emailPanel=sessionStorage.getItem('atd-email-auto-panel:'+ws)==='envios'?'envios':'fluxos',emailSearch='';
    const load=async()=>{const [ctx,data]=await Promise.all([api('contexto',{},ws),api('email-automacoes-list',{},ws)]);if(S.ws!==ws||S.view!==route)return;const flows=data.automacoes||[],runs=data.execucoes||[],logs=data.envios||[];root.innerHTML=`<div class="atd-auto-intro"><div><b>Fluxos transacionais</b><p>Crie uma vez no canvas e selecione o fluxo na configuração da campanha, do formulário ou do produto. Cadastros, respostas e vendas vão disparar o fluxo escolhido.</p></div>${ctx.editar?'<button class="btn pri" id="atdEmailAutoNew">＋ Novo fluxo</button>':''}</div><div class="atd-auto-list">${flows.map((f,i)=>{const steps=f.fluxo?.nodes||[],event={cadastro:'Entrada de lead',pesquisa:'Resposta de formulário',venda:'Venda aprovada'}[f.evento]||f.evento;return `<article class="atd-auto-card"><header><div><span class="pill ${f.ativo?'good':'warn'}">${f.ativo?'Ativa':'Rascunho / pausada'}</span><h3>${esc(f.nome)}</h3></div><span class="atd-auto-canal">${esc(event)}</span></header><div class="atd-auto-flow"><div><small>GATILHO</small><b>${esc(event)}</b></div><span aria-hidden="true">→</span><div><small>CANVAS</small><p>${steps.length} blocos · ${steps.filter(n=>n.tipo==='email').length} e-mails · ${steps.filter(n=>n.tipo==='espera').length} esperas</p></div></div>${ctx.editar?`<footer><button class="btn sm" data-email-flow-edit="${i}">Abrir canvas</button><button class="btn sm" data-email-flow-toggle="${i}">${f.ativo?'Pausar':'Ativar'}</button></footer>`:''}</article>`;}).join('')||'<div class="atd-auto-empty"><b>Nenhum fluxo de e-mail</b><p>Crie um canvas e depois associe-o ao cadastro, ao formulário ou à venda.</p></div>'}</div><section class="atd-auto-runs"><h3>Envios de e-mail recentes</h3>${logs.length?`<div class="atd-auto-run-list">${logs.slice(0,80).map(l=>`<div><span class="pill ${l.status==='enviado'?'good':l.status==='processando'?'warn':'bad'}">${esc(l.status)}</span><b>${esc(flows.find(f=>f.id===runs.find(r=>r.id===l.execucao_id)?.automacao_id)?.nome||'Fluxo')}</b><span>${esc(l.email)}</span><span>${esc(l.assunto)}</span><time>${fmt(l.enviado_em||l.criado_em)}</time>${l.erro?`<small class="atd-erro">${esc(l.erro)}</small>`:''}</div>`).join('')}</div>`:'<p class="muted">Ainda não há envios de automação registrados.</p>'}</section>`;
      const intro=root.querySelector('.atd-auto-intro'),list=root.querySelector('.atd-auto-list'),sent=root.querySelector('.atd-auto-runs'),tabs=document.createElement('nav'),searchBox=document.createElement('label'),empty=document.createElement('p');
      tabs.className='atd-auto-tabs';tabs.setAttribute('aria-label','Seções das automações de e-mail');tabs.innerHTML=`<button type="button" class="btn" data-email-panel="fluxos">Fluxos (${flows.length})</button><button type="button" class="btn" data-email-panel="envios">Envios (${logs.length})</button>`;
      searchBox.className='atd-auto-search';searchBox.innerHTML=`Buscar fluxo<input type="search" placeholder="Nome ou gatilho…" value="${esc(emailSearch)}">`;
      empty.className='muted atd-auto-sem-filtro';empty.textContent='Nenhum fluxo corresponde à busca.';empty.hidden=true;
      root.replaceChildren(tabs,intro,searchBox,list,empty,sent);
      const filter=()=>{emailSearch=searchBox.querySelector('input').value.toLocaleLowerCase().trim();let shown=0;list.querySelectorAll('.atd-auto-card').forEach((card,i)=>{const f=flows[i],visible=!emailSearch||(f.nome+' '+f.evento).toLocaleLowerCase().includes(emailSearch);card.hidden=!visible;if(visible)shown++;});empty.dataset.empty=shown===0&&flows.length>0?'true':'false';empty.hidden=emailPanel!=='fluxos'||empty.dataset.empty!=='true';};
      const show=id=>{emailPanel=id;intro.hidden=id!=='fluxos';searchBox.hidden=id!=='fluxos';list.hidden=id!=='fluxos';empty.hidden=id!=='fluxos'||empty.dataset.empty!=='true';sent.hidden=id!=='envios';tabs.querySelectorAll('[data-email-panel]').forEach(button=>{button.classList.toggle('pri',button.dataset.emailPanel===id);button.setAttribute('aria-current',button.dataset.emailPanel===id?'page':'false');});sessionStorage.setItem('atd-email-auto-panel:'+ws,id);};
      searchBox.oninput=filter;filter();tabs.querySelectorAll('[data-email-panel]').forEach(button=>button.onclick=()=>show(button.dataset.emailPanel));show(emailPanel);
      root.querySelector('#atdEmailAutoNew')?.addEventListener('click',()=>editor());root.querySelectorAll('[data-email-flow-edit]').forEach(b=>b.onclick=()=>editor(flows[Number(b.dataset.emailFlowEdit)]));root.querySelectorAll('[data-email-flow-toggle]').forEach(b=>b.onclick=()=>act(async()=>{const f=flows[Number(b.dataset.emailFlowToggle)];await api('email-automacoes-toggle',{id:f.id,ativo:!f.ativo},ws);toast(f.ativo?'Fluxo pausado.':'Fluxo ativado.');await load();}));
    };
    const editor=f=>{
      const graph=JSON.parse(JSON.stringify(f?.fluxo||{}));let nodes=Array.isArray(graph.nodes)?graph.nodes:[],edges=Array.isArray(graph.edges)?graph.edges:[];
      if(!nodes.some(n=>n.tipo==='gatilho'))nodes.unshift({id:crypto.randomUUID(),tipo:'gatilho',x:40,y:210,data:{}});
      if(!nodes.some(n=>n.tipo==='email')){const from=nodes.find(n=>n.tipo==='gatilho'),mail={id:crypto.randomUUID(),tipo:'email',x:390,y:210,data:{assunto:'Olá, {{primeiro_nome}}',html:'<p>Olá, {{primeiro_nome}}!</p><p>Escreva sua mensagem aqui.</p>'}};nodes.push(mail);if(!edges.some(e=>e.origem===from.id))edges.push({origem:from.id,destino:mail.id,saida:'seguir'});}
      const host=document.createElement('div');host.className='atd-flow-overlay';host.innerHTML=`<section class="atd-flow-window"><header class="atd-flow-head"><div><h2>${f?'Editar':'Criar'} canvas de e-mail</h2><p>Arraste os blocos, ligue as etapas e salve como rascunho antes de ativar.</p></div><button type="button" class="btn" data-close>Fechar</button></header><div class="atd-flow-settings atd-email-flow-settings"><label>Nome do fluxo<input name="nome" maxlength="120" required value="${esc(f?.nome||'Novo fluxo de e-mail')}"></label><label>Gatilho do fluxo<select name="evento"><option value="cadastro"${!f||f.evento==='cadastro'?' selected':''}>Cadastro de lead na campanha</option><option value="pesquisa"${f?.evento==='pesquisa'?' selected':''}>Resposta de formulário ou diagnóstico</option><option value="venda"${f?.evento==='venda'?' selected':''}>Venda aprovada do produto</option></select></label></div><div class="atd-flow-body"><aside class="atd-flow-palette"><b>Adicionar bloco</b><button type="button" data-add="email">✉ Enviar e-mail</button><button type="button" data-add="condicao">◇ Condição / filtro</button><button type="button" data-add="espera">◷ Tempo de espera</button><button type="button" data-add="fim">■ Encerrar fluxo</button><p>O gatilho inicial acompanha o evento escolhido. A espera é retomada pelo agendador do Atendimento.</p></aside><div class="atd-flow-stage"><div class="atd-flow-space" id="atdEmailFlowSpace"></div></div></div><footer class="atd-flow-foot"><span class="muted">Variáveis: {{primeiro_nome}}, {{nome}}, {{email}}, {{telefone}}, {{campanha}}, {{produto}}, {{pesquisa}}, {{valor_venda}}, {{data_venda}}.</span><div><button type="button" class="btn" data-close>Cancelar</button><button type="button" class="btn pri" id="atdEmailFlowSave">Salvar canvas</button></div></footer></section>`;document.body.append(host);
      const stage=host.querySelector('#atdEmailFlowSpace'),close=()=>host.remove();host.querySelectorAll('[data-close]').forEach(b=>b.onclick=close);const labels={gatilho:'Gatilho',email:'Enviar e-mail',condicao:'Condição',espera:'Aguardar',fim:'Encerrar'};
      const renderGraph=()=>{const w=Math.max(2300,...nodes.map(n=>(Number(n.x)||0)+350)),h=Math.max(1500,...nodes.map(n=>(Number(n.y)||0)+380)),byId=id=>nodes.find(n=>n.id===id),target=(n,s)=>edges.find(e=>e.origem===n.id&&e.saida===s)?.destino||'';stage.style.width=w+'px';stage.style.height=h+'px';const curves=edges.map(e=>{const a=byId(e.origem),b=byId(e.destino);if(!a||!b)return '';const x1=Number(a.x)+260,y1=Number(a.y)+62,x2=Number(b.x),y2=Number(b.y)+62,k=Math.max(70,Math.abs(x2-x1)*.45);return `<path class="atd-flow-edge" d="M${x1},${y1} C${x1+k},${y1} ${x2-k},${y2} ${x2},${y2}" marker-end="url(#atdEmailArrow)"/>`;}).join('');const event=host.querySelector('[name=evento]').value,nodeHtml=nodes.map(n=>{const d=n.data||{},outs=n.tipo==='condicao'?[['sim','Se sim'],['nao','Se não']]:n.tipo==='fim'?[]:[['seguir','Próximo bloco']];let body='';if(n.tipo==='gatilho')body=`<b>${{cadastro:'Novo lead na campanha',pesquisa:'Resposta de formulário ou diagnóstico',venda:'Venda aprovada'}[event]}</b><small>Evento que inicia este fluxo.</small>`;if(n.tipo==='email')body=`<label>Assunto<input data-email-field="assunto" maxlength="180" value="${esc(d.assunto||'')}" placeholder="Sua mensagem, {{primeiro_nome}}"></label><label>Corpo do e-mail (HTML)<textarea data-email-field="html" rows="12" maxlength="100000" placeholder="<p>Olá, {{primeiro_nome}}</p>">${esc(d.html||'')}</textarea></label><small>HTML aceita links, imagens externas (&lt;img src="https://…"&gt;) e botões como links estilizados.</small>`;if(n.tipo==='espera')body=`<label>Aguardar<div class="atd-flow-wait"><input type="number" data-email-field="minutos" min="1" max="525600" value="${esc(d.minutos||60)}"><span>minutos</span></div></label><small>O próximo bloco será retomado automaticamente.</small>`;if(n.tipo==='condicao')body=`<label>Campo<select data-email-field="campo">${[['tipo','Tipo de contato'],['qualificacao','Qualificação'],['campanha','Campanha'],['produto','Produto'],['pesquisa','Formulário']].map(([v,l])=>`<option value="${v}"${(d.campo||'tipo')===v?' selected':''}>${l}</option>`).join('')}</select></label><label>Condição<select data-email-field="operador"><option value="igual"${d.operador!=='contem'?' selected':''}>É igual a</option><option value="contem"${d.operador==='contem'?' selected':''}>Contém</option></select></label><label>Valor<input data-email-field="valor" maxlength="120" value="${esc(d.valor||'')}" placeholder="lead, qualificado…"></label>`;return `<article class="atd-flow-node atd-flow-${n.tipo}" data-node="${esc(n.id)}" style="left:${Number(n.x)||0}px;top:${Number(n.y)||0}px"><header class="atd-flow-node-head"><span>${n.tipo==='gatilho'?'⚡':n.tipo==='email'?'✉':n.tipo==='espera'?'◷':n.tipo==='condicao'?'◇':'■'} ${labels[n.tipo]}</span>${n.tipo==='gatilho'?'':`<button type="button" data-remove="${esc(n.id)}" aria-label="Remover bloco">×</button>`}</header><div class="atd-flow-node-body">${body}</div>${outs.length?`<div class="atd-flow-outs">${outs.map(([s,l])=>`<label>${l}<select data-link="${esc(n.id)}" data-branch="${s}"><option value="">Sem conexão</option>${nodes.filter(x=>x.id!==n.id).map(x=>`<option value="${esc(x.id)}"${target(n,s)===x.id?' selected':''}>${esc(x.data?.rotulo||labels[x.tipo])}</option>`).join('')}</select></label>`).join('')}</div>`:''}</article>`;}).join('');stage.innerHTML=`<svg class="atd-flow-svg" width="${w}" height="${h}"><defs><marker id="atdEmailArrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z"/></marker></defs>${curves}</svg>${nodeHtml}`;stage.querySelectorAll('[data-email-field]').forEach(el=>el.addEventListener('input',()=>{const n=byId(el.closest('[data-node]').dataset.node);n.data=n.data||{};n.data[el.dataset.emailField]=el.dataset.emailField==='minutos'?Number(el.value):el.value;}));stage.querySelectorAll('[data-link]').forEach(el=>el.onchange=()=>{const origem=el.dataset.link,saida=el.dataset.branch;edges=edges.filter(x=>!(x.origem===origem&&x.saida===saida));if(el.value)edges.push({origem,destino:el.value,saida});renderGraph();});stage.querySelectorAll('[data-remove]').forEach(el=>el.onclick=()=>{const id=el.dataset.remove;nodes=nodes.filter(n=>n.id!==id);edges=edges.filter(e=>e.origem!==id&&e.destino!==id);renderGraph();});stage.querySelectorAll('.atd-flow-node:not(.atd-flow-gatilho) .atd-flow-node-head').forEach(head=>head.onpointerdown=e=>{if(e.target.closest('button'))return;const n=byId(head.closest('[data-node]').dataset.node),sx=e.clientX,sy=e.clientY,ox=Number(n.x),oy=Number(n.y);head.setPointerCapture?.(e.pointerId);const move=ev=>{n.x=Math.max(0,ox+ev.clientX-sx);n.y=Math.max(0,oy+ev.clientY-sy);head.closest('[data-node]').style.left=n.x+'px';head.closest('[data-node]').style.top=n.y+'px';};const done=()=>{document.removeEventListener('pointermove',move);document.removeEventListener('pointerup',done);renderGraph();};document.addEventListener('pointermove',move);document.addEventListener('pointerup',done,{once:true});});};
      conectarEditorAosBlocosEmail(stage,id=>nodes.find(n=>n.id===id),ws,renderGraph);
      const flowTools=document.createElement('div');flowTools.className='atd-flow-tools';flowTools.innerHTML='<span>Canvas de e-mail</span><button type="button" class="btn sm" data-flow-start>Ir ao início</button><button type="button" class="btn sm" data-flow-arrange>Organizar blocos</button>';host.querySelector('.atd-flow-body').before(flowTools);
      const goToStart=()=>{const first=nodes.find(n=>n.tipo==='gatilho');host.querySelector('.atd-flow-stage').scrollTo({left:0,top:Math.max(0,Number(first?.y||0)-30),behavior:'smooth'});};
      flowTools.querySelector('[data-flow-start]').onclick=goToStart;
      flowTools.querySelector('[data-flow-arrange]').onclick=()=>{const start=nodes.find(n=>n.tipo==='gatilho'),depths=new Map(),queue=start?[{id:start.id,depth:0}]:[];while(queue.length){const next=queue.shift();if(depths.has(next.id))continue;depths.set(next.id,next.depth);for(const edge of edges.filter(e=>e.origem===next.id))queue.push({id:edge.destino,depth:next.depth+1});}const counters=new Map(),orphanDepth=Math.max(0,...depths.values())+1;for(const node of nodes){const depth=depths.get(node.id)??orphanDepth,row=counters.get(depth)||0;node.x=40+depth*350;node.y=100+row*340;counters.set(depth,row+1);}renderGraph();goToStart();};
      host.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{const tipo=b.dataset.add,i=nodes.length,previous=nodes.at(-1),node={id:crypto.randomUUID(),tipo,x:390+Math.floor(i/3)*350,y:100+(i%3)*350,data:tipo==='email'?{assunto:'',html:''}:tipo==='espera'?{minutos:60}:tipo==='condicao'?{campo:'tipo',operador:'igual',valor:'lead'}:{}};const canConnect=previous&&!['fim','condicao'].includes(previous.tipo)&&!edges.some(e=>e.origem===previous.id&&e.saida==='seguir');if(canConnect){node.x=Number(previous.x)+350;node.y=Number(previous.y);}nodes.push(node);if(canConnect)edges.push({origem:previous.id,destino:node.id,saida:'seguir'});renderGraph();});
      host.querySelector('[name=evento]').onchange=renderGraph;
      host.querySelector('#atdEmailFlowSave').onclick=()=>act(async()=>{const nome=host.querySelector('[name=nome]').value.trim(),evento=host.querySelector('[name=evento]').value;if(!nome)throw Error('Informe o nome do fluxo.');if(!nodes.some(n=>n.tipo==='email'))throw Error('Adicione ao menos um bloco para enviar e-mail.');for(const n of nodes.filter(n=>n.tipo==='email'))if(!String(n.data?.assunto||'').trim()||!String(n.data?.html||'').trim())throw Error('Preencha o assunto e o conteúdo de cada e-mail.');for(const n of nodes.filter(n=>n.tipo==='condicao'))if(!String(n.data?.valor||'').trim())throw Error('Preencha o valor de cada condição.');await api('email-automacoes-save',{id:f?.id,nome,evento,fluxo:{versao:1,nodes,edges}},ws);close();toast('Canvas de e-mail salvo como rascunho. Ative o fluxo e selecione-o na campanha, no formulário ou no produto.');await load();});renderGraph();
    };
    $('#atdEmailAutoReload').onclick=()=>act(load);try{await load();}catch(e){root.innerHTML=`<div class="empty"><b>Automações de e-mail indisponíveis</b><p>${esc(e.message)}</p><p>Aplique a migration e publique a Edge de Atendimento.</p></div>`;}
  }
  async function vDisparoGrupos(m){
    stop();++A.token;const ws=S.ws,route=S.view,audience=route==='atd-envios-whatsapp'?'contatos':route==='atd-envios-grupos'?'grupos':'';m.innerHTML='<div class="head"><div><h1>'+ (audience==='contatos'?'Envios para contatos WhatsApp':audience==='grupos'?'Envios para grupos WhatsApp':'Disparos')+'</h1><span class="muted">'+(audience==='contatos'?'Selecione contatos individuais dos chips Evolution e acompanhe seus envios.':audience==='grupos'?'Gerencie campanhas de grupos e acompanhe os envios coletivos.':'Envios sequenciais pela Evolution, com agendamento e histórico.')+'</span></div><button class="btn" id="dgAtualizar">Atualizar</button></div><div id="atdDisparoGrupos">Carregando canais e destinatários…</div>';
    if(A.disparoDraftFileRoute!==route){A.disparoDraftFile=null;A.disparoDraftFileWs=null;A.disparoDraftFileRoute=route;}
    const draftKey='atd-disparo-rascunho:'+ws+(audience==='contatos'?':contatos':'');let draft={};try{draft=JSON.parse(sessionStorage.getItem(draftKey)||'{}')||{};}catch{}
    let selected=new Set(Array.isArray(draft.selected)?draft.selected:[]),termSaved=draft.term||'',kindSaved=draft.kind||'',minSaved=draft.min||'',hideCommunity=Boolean(draft.hideCommunity),currentTab=['campanhas','configuracao','criacao','agendado','historico'].includes(draft.tab)?draft.tab:'campanhas',groupCampaignId=draft.groupCampaignId||'',managerId='',previewObjectUrl=null,mediaObserver=null,saveCurrentDraft=()=>{};if(S.view==='atd-envios-whatsapp'&&currentTab==='campanhas')currentTab='configuracao';
    const root=$('#atdDisparoGrupos'),refresh=async()=>{
      saveCurrentDraft();
      const [channels,batches,segmentResult,groupCampaignResult]=await Promise.all([q(sb.from('atd_canais').select('id,nome,numero,externo_id,status,ativo').eq('workspace_id',ws).eq('provedor','evolution').eq('canal','whatsapp').order('nome')),api('disparos-grupos-list',{},ws),api('disparos-segmentos-list',{},ws).catch(()=>({segmentos:[]})),api('grupo-campanhas-list',{},ws)]);
      if(S.ws!==ws||S.view!==route)return;
      mediaObserver?.disconnect();
      const channelIds=new Set(channels.map(c=>c.id)),rows=[];if(channelIds.size){let from=0;while(true){const page=await q(sb.from('atd_conversas').select('id,canal_id,externo_id,endereco,nome,grupo,ultima_em,grupo_tipo,grupo_pai_externo_id,avatar_path,grupo_membros').eq('workspace_id',ws).in('canal_id',[...channelIds]).order('nome').order('id').range(from,from+499));rows.push(...page);if(page.length<500)break;from+=500;}}
      const canSend=c=>c.ativo&&c.status==='conectado',known=new Set(rows.filter(g=>audience==='contatos'?!g.grupo:audience==='grupos'?g.grupo:true).map(g=>g.id));selected=new Set([...selected].filter(id=>known.has(id)));if(audience==='contatos')groupCampaignId='';
      const segments=(segmentResult.segmentos||[]).filter(s=>!audience||(s.conversas||[]).some(id=>known.has(String(id))));
      const groupCampaigns=groupCampaignResult.campanhas||[];
      root.innerHTML=`<section class="panel atd-disparo-info"><b>Destinatários dos chips Evolution</b><p>Grupos e contatos desconectados aparecem para consulta, mas só podem ser selecionados quando o chip estiver conectado. A fila envia cada destinatário pelo chip correspondente.</p></section><form class="panel atd-disparo-form" id="dgForm"><h2>Nova campanha</h2><div class="atd-disparo-grid"><label>Nome interno<input name="nome" maxlength="100" placeholder="Ex.: Aviso da semana"></label><label>Primeiro envio (horário de Brasília)<input type="datetime-local" name="enviar_em" required></label><label>Intervalo entre destinatários (segundos)<input type="number" name="intervalo" min="10" max="86400" value="60" required><small>Mínimo de 10 segundos; o envio depende da fila e da resposta da Evolution.</small></label></div><fieldset><legend>Chips Evolution</legend><div class="atd-disparo-chips">${channels.map(c=>`<label class="${canSend(c)?'':'is-offline'}"><input type="checkbox" name="chips" value="${esc(c.id)}" ${canSend(c)?'checked':''} ${canSend(c)?'':'disabled'}><b>${esc(c.nome)}</b><small>${esc(c.numero?'+'+String(c.numero).replace(/\D/g,''):c.externo_id)} · ${esc(c.ativo?c.status:'desativado')}</small></label>`).join('')||'<p>Nenhuma instância Evolution cadastrada.</p>'}</div></fieldset><div class="atd-disparo-selecao"><header><b>Grupos e contatos <small id="dgSelecionados">0 selecionados</small></b><label><input type="checkbox" id="dgTodos"> Selecionar visíveis</label></header><input id="dgBusca" type="search" placeholder="Buscar grupo, contato ou chip…" value="${esc(termSaved)}"><div class="atd-disparo-filtros"><label><input type="checkbox" id="dgOcultarComunidade" ${hideCommunity?'checked':''}> Ocultar comunidades</label><label>Tipo<select id="dgTipoGrupo"><option value="" ${kindSaved===''?'selected':''}>Todos</option><option value="grupo" ${kindSaved==='grupo'?'selected':''}>Grupos normais</option><option value="avisos_comunidade" ${kindSaved==='avisos_comunidade'?'selected':''}>Grupos de aviso</option><option value="comunidade" ${kindSaved==='comunidade'?'selected':''}>Comunidades</option><option value="pessoa" ${kindSaved==='pessoa'?'selected':''}>Contatos</option></select></label><label>Mínimo de membros<input id="dgMinMembros" type="number" min="0" step="1" placeholder="Sem mínimo" value="${esc(minSaved)}"></label></div><div class="atd-disparo-segmentos"><select id="dgSegmento"><option value="">Selecionar segmento salvo…</option>${segments.map(s=>`<option value="${esc(s.id)}">${esc(s.nome)} · ${(s.conversas||[]).length} destinatários</option>`).join('')}</select><button type="button" class="btn sm" id="dgAplicarSegmento" ${segments.length?'':'disabled'}>Carregar seleção</button><input id="dgNomeSegmento" maxlength="100" placeholder="Nome do segmento"><button type="button" class="btn sm" id="dgSalvarSegmento">Salvar seleção</button><button type="button" class="btn sm bad" id="dgExcluirSegmento" ${segments.length?'':'disabled'}>Excluir</button></div><div id="dgGrupos" class="atd-disparo-grupos"></div></div><label>Mensagem / legenda da mídia<textarea name="texto" maxlength="4000" rows="5" placeholder="Escreva o texto que acompanhará a imagem ou o vídeo…"></textarea></label><label>Imagem ou vídeo (opcional)<input type="file" name="midia" accept="image/jpeg,image/png,image/webp,video/mp4"><small>Imagem JPG, PNG ou WebP até 7 MB; vídeo MP4 até 30 MB. O texto acima será enviado como legenda da mídia.</small></label><div id="dgPreview" class="muted"></div><button class="btn pri" type="submit" ${rows.some(g=>canSend(channels.find(c=>c.id===g.canal_id)||{}))?'':'disabled'}>Agendar disparo</button></form><section class="panel"><h2>Campanhas e resultados</h2><div class="atd-disparo-campanhas">${(batches.campanhas||[]).map(b=>{const editavel=b.pendentes>0&&['agendado','em_andamento'].includes(b.status);return `<article><header><b>${esc(b.nome)}</b><span class="pill ${b.status==='concluido'?'good':b.status==='agendado'?'warn':''}">${esc(b.status)}</span></header><p>${new Date(b.iniciar_em).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})} · ${esc(b.enviados)} enviados · ${esc(b.falhas)} falhas de ${esc(b.total)}</p><small>Intervalo: ${esc(b.intervalo_segundos)} s · ${esc(b.pendentes||0)} aguardando envio</small>${editavel?`<div><button type="button" class="btn sm" data-dg-edit="${esc(b.id)}">Editar mensagem</button><form class="atd-disparo-editar" data-dg-edit-form="${esc(b.id)}" hidden><label>Texto para destinatários restantes<textarea maxlength="4000" rows="4">${esc(b.texto||'')}</textarea></label><small>A mensagem do contato que já estiver em processamento não será alterada.</small><button type="submit" class="btn sm pri">Salvar para ${esc(b.pendentes)} restantes</button><button type="button" class="btn sm" data-dg-edit-cancel="${esc(b.id)}">Cancelar</button></form></div>`:''}${b.erro?`<p class="atd-erro">${esc(b.erro)}</p>`:''}${['agendado','em_andamento','pausado'].includes(b.status)?` <button class="btn sm bad" data-dg-cancel="${esc(b.id)}">Cancelar fila</button>`:''}</article>`;}).join('')||'<p class="muted">Nenhuma campanha de grupos ainda.</p>'}</div></section>`;
      if(previewObjectUrl){URL.revokeObjectURL(previewObjectUrl);previewObjectUrl=null;}
      const form=root.querySelector('#dgForm'),info=root.querySelector('.atd-disparo-info'),oldResults=root.querySelector('.atd-disparo-campanhas')?.closest('section');
      if(audience==='contatos'){root.querySelector('.atd-disparo-filtros').hidden=true;kindSaved='';minSaved='';hideCommunity=false;root.querySelector('#dgTipoGrupo').value='';root.querySelector('#dgMinMembros').value='';root.querySelector('#dgOcultarComunidade').checked=false;}else if(audience==='grupos'){root.querySelector('#dgTipoGrupo option[value="pessoa"]')?.remove();if(kindSaved==='pessoa'){kindSaved='';root.querySelector('#dgTipoGrupo').value='';}}
      const configPanel=document.createElement('div'),createPanel=document.createElement('div');
      configPanel.dataset.dgPanel='configuracao';createPanel.dataset.dgPanel='criacao';
      const grid=form.querySelector('.atd-disparo-grid'),chips=form.querySelector('fieldset'),selection=form.querySelector('.atd-disparo-selecao'),message=form.querySelector('[name=texto]').closest('label'),media=form.querySelector('[name=midia]').closest('label'),fileInfo=form.querySelector('#dgPreview'),submit=form.querySelector('[type=submit]');
      if(audience){info.querySelector('b').textContent=audience==='contatos'?'Contatos WhatsApp dos chips Evolution':'Grupos WhatsApp dos chips Evolution';info.querySelector('p').textContent=audience==='contatos'?'Selecione contatos individuais. Cada mensagem será enviada pelo chip conectado correspondente.':'Selecione grupos ou escolha uma campanha de grupos. Cada mensagem será enviada pelo chip conectado correspondente.';selection.querySelector('header b').firstChild.textContent=audience==='contatos'?'Contatos ':'Grupos ';selection.querySelector('#dgBusca').placeholder=audience==='contatos'?'Buscar contato, número ou chip…':'Buscar grupo ou chip…';}
      form.replaceChildren(configPanel,createPanel);
      configPanel.append(info,chips,selection);
      configPanel.insertAdjacentHTML('afterbegin',`<label class="atd-camp-selector">Campanha de grupos<select id="dgGroupCampaignSelect"><option value="">Seleção manual de grupos e contatos</option>${groupCampaigns.map(c=>`<option value="${esc(c.id)}">${esc(c.nome)} · ${(c.conversas||[]).length} grupos</option>`).join('')}</select><small>Ao escolher uma campanha, o disparo usará todos os grupos vinculados a ela no momento do agendamento.</small></label><div id="dgCampaignSummary" class="atd-camp-summary" hidden></div>`);
      const campaignPanel=document.createElement('section');campaignPanel.className='panel atd-camp-panel';campaignPanel.dataset.dgPanel='campanhas';
      campaignPanel.innerHTML=`<div class="atd-camp-head"><div><h2>Campanhas de grupos</h2><p class="muted">Organize grupos existentes, crie novos e gerencie as configurações antes de disparar.</p></div><button type="button" class="btn pri" id="dgCampNew">＋ Nova campanha</button></div><div id="dgCampList" class="atd-camp-list">${groupCampaigns.map(c=>`<article><div><b>${esc(c.nome)}</b><small>${(c.conversas||[]).length} grupos · ${esc(c.descricao||'Sem descrição')}</small></div><div><button type="button" class="btn sm" data-camp-manage="${esc(c.id)}">Gerenciar grupos</button><button type="button" class="btn sm" data-camp-use="${esc(c.id)}">Usar no disparo</button><button type="button" class="btn sm" data-camp-edit="${esc(c.id)}">Editar campanha</button></div></article>`).join('')||'<p class="muted">Nenhuma campanha de grupos criada.</p>'}</div><form id="dgCampForm" class="atd-camp-form" hidden><h3 id="dgCampFormTitle">Nova campanha</h3><label>Nome da campanha<input name="nome" maxlength="100" required placeholder="Ex.: Comunidade Ano de Ouro"></label><label>Descrição interna<textarea name="descricao" maxlength="1000" rows="3" placeholder="Objetivo e público desta campanha"></textarea></label><div><button type="submit" class="btn pri">Salvar campanha</button><button type="button" class="btn" id="dgCampFormCancel">Cancelar</button></div></form><section id="dgCampManager" class="atd-camp-manager" hidden></section>`;
      createPanel.innerHTML='<h2>Criar disparo</h2><p class="muted">Confira a mensagem antes de agendar.</p><div class="atd-disparo-criacao"><div class="atd-disparo-campos"></div><div class="atd-phone"><div class="atd-phone-top">WhatsApp <span>●●●</span></div><div class="atd-phone-chat"><div class="atd-phone-bubble"><div id="dgPhoneMedia"></div><p id="dgPhoneText">Sua mensagem aparecerá aqui.</p><small>prévia</small></div></div><div class="atd-phone-bottom">Mensagem agendada</div></div></div>';
      createPanel.querySelector('.atd-disparo-campos').append(grid,message,media,fileInfo,submit);
      createPanel.insertAdjacentHTML('beforeend','<section class="atd-disparo-escolhidos"><h3>Destinatários selecionados <small id="dgChosenCount"></small></h3><div id="dgChosenList"></div></section>');
      const nav=document.createElement('nav');nav.className='atd-disparo-tabs';nav.setAttribute('aria-label','Etapas do disparo');
      nav.innerHTML=[['campanhas','Campanhas'],['configuracao','Configuração'],['criacao','Criação'],['agendado','Agendado'],['historico','Histórico']].map(([id,label])=>`<button type="button" class="btn" data-dg-tab="${id}">${label}</button>`).join('');
      const scheduled=document.createElement('section'),history=document.createElement('section');
      scheduled.className='panel';history.className='panel';scheduled.dataset.dgPanel='agendado';history.dataset.dgPanel='historico';
      scheduled.innerHTML='<h2>Agendados '+(audience==='contatos'?'· contatos':audience==='grupos'?'· grupos':'')+'</h2><div class="atd-disparo-campanhas"></div>';
      history.innerHTML='<h2>Histórico '+(audience==='contatos'?'· contatos':audience==='grupos'?'· grupos':'')+'</h2><div class="atd-disparo-campanhas"></div>';
      const batchesList=batches.campanhas||[];
      const dateBr=value=>new Date(value).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'});
      const dateInput=value=>new Date(value).toLocaleString('sv-SE',{timeZone:'America/Sao_Paulo'}).replace(' ','T').slice(0,16);
      const buildTimePicker=(input,value,disabled=false)=>{const label=input.closest('label'),[day,time='00:00']=String(value||'').split('T'),[hour='00',minute='00']=time.split(':');label.innerHTML=`Data e hora do envio (Brasília)<div class="atd-disparo-data-hora"><input type="date" name="envio_dia" value="${esc(day)}" required ${disabled?'disabled':''} aria-label="Data do envio"><select name="envio_hora" required ${disabled?'disabled':''} aria-label="Hora do envio">${Array.from({length:24},(_,i)=>{const n=String(i).padStart(2,'0');return `<option value="${n}" ${n===hour?'selected':''}>${n} h</option>`;}).join('')}</select><select name="envio_minuto" required ${disabled?'disabled':''} aria-label="Minuto do envio">${Array.from({length:60},(_,i)=>{const n=String(i).padStart(2,'0');return `<option value="${n}" ${n===minute?'selected':''}>${n} min</option>`;}).join('')}</select></div>`;};
      const scheduledAt=fd=>new Date(`${fd.get('envio_dia')}T${fd.get('envio_hora')}:${fd.get('envio_minuto')}:00-03:00`);
      const card=b=>{const editable=b.status==='agendado'&&b.pendentes===b.total,active=['agendado','em_andamento'].includes(b.status);
        return `<article><header><b>${esc(b.nome)}</b><span class="pill ${b.status==='concluido'?'good':b.status==='agendado'?'warn':''}">${esc(b.status)}</span></header><p>${dateBr(b.iniciar_em)} · ${esc(b.enviados)} enviados · ${esc(b.falhas)} falhas de ${esc(b.total)}</p><small>Intervalo: ${esc(b.intervalo_segundos)} s · ${esc(b.pendentes||0)} aguardando envio</small><div class="atd-disparo-conteudo-enviado"><b>Mensagem</b><p>${esc(b.texto||'Sem texto; apenas anexo.')}</p>${b.midia_path?`<div class="atd-disparo-thumb" data-dg-media-thumb="${esc(b.id)}" data-dg-media-type="${esc(b.midia_mime||'')}"><span>Carregando prévia…</span></div><button type="button" class="btn sm" data-dg-media="${esc(b.id)}">${b.midia_mime==='video/mp4'?'▶ Vídeo':'▧ Imagem'}: ${esc(b.midia_nome||'Abrir anexo')}</button>`:''}</div><details class="atd-disparo-destinatarios" data-dg-recipients="${esc(b.id)}"><summary>Ver destinatários (${esc(b.total)})</summary><div class="atd-disparo-destinatarios-lista">Abra para carregar a lista.</div></details>${editable?`<form class="atd-disparo-editar" data-dg-edit-form="${esc(b.id)}"><div class="atd-disparo-editar-head"><b>Editar agendamento</b><button type="button" class="btn sm" data-dg-edit="${esc(b.id)}">Editar</button></div><div class="atd-disparo-editar-grid"><label>Nome<input name="nome" maxlength="100" value="${esc(b.nome)}" disabled required></label><label>Data e hora (Brasília)<input name="enviar_em" type="datetime-local" value="${dateInput(b.iniciar_em)}" disabled required></label></div><label>Mensagem / legenda<textarea name="texto" maxlength="4000" rows="4" disabled>${esc(b.texto||'')}</textarea></label><div class="atd-disparo-editar-actions" hidden><button type="submit" class="btn sm pri">Salvar alterações</button><button type="button" class="btn sm" data-dg-edit-cancel="${esc(b.id)}">Descartar</button></div></form>`:''}${b.erro?`<p class="atd-erro">${esc(b.erro)}</p>`:''}${active||b.status==='pausado'?`<button type="button" class="btn sm bad" data-dg-cancel="${esc(b.id)}">Cancelar fila</button>`:''}</article>`;};
      const belongsHere=b=>!audience||b.publico===audience||((b.publico==='desconhecido'||!b.publico)&&(!b.grupo_campanha_id||audience==='grupos'));
      scheduled.querySelector('.atd-disparo-campanhas').innerHTML=batchesList.filter(b=>belongsHere(b)&&['agendado','em_andamento'].includes(b.status)).map(card).join('')||'<p class="muted">Nenhum envio agendado para '+(audience==='contatos'?'contatos':'grupos')+'.</p>';
      history.querySelector('.atd-disparo-campanhas').innerHTML=batchesList.filter(b=>belongsHere(b)&&!['agendado','em_andamento'].includes(b.status)).map(card).join('')||'<p class="muted">Nenhum envio no histórico de '+(audience==='contatos'?'contatos':'grupos')+'.</p>';
      buildTimePicker(form.querySelector('input[name=enviar_em]'),draft.day?`${draft.day}T${draft.hour||'00'}:${draft.minute||'00'}`:dateInput(new Date(Date.now()+10*60000)));
      root.querySelectorAll('[data-dg-edit-form] input[name=enviar_em]').forEach(input=>buildTimePicker(input,input.value,true));
      form.elements.nome.value=draft.nome||'';form.elements.intervalo.value=draft.intervalo||'60';form.elements.texto.value=draft.texto||'';
      if(Array.isArray(draft.chips))form.querySelectorAll('[name=chips]').forEach(input=>{input.checked=!input.disabled&&draft.chips.includes(input.value);});
      const footer=document.createElement('div');footer.className='atd-disparo-navigation';footer.innerHTML='<button type="button" class="btn" id="dgPrev">← Voltar</button><button type="button" class="btn pri" id="dgNext">Avançar →</button>';
      const groupGuide=document.createElement('div');groupGuide.className='atd-camp-guide';groupGuide.innerHTML='<span><b>Nome, foto e privacidade dos grupos</b><small>Crie ou importe grupos na aba Campanhas e abra a configuração de cada grupo.</small></span><button type="button" class="btn sm" id="dgOpenCampaigns">Gerenciar grupos →</button>';
      oldResults?.remove();root.replaceChildren(nav,groupGuide,campaignPanel,form,scheduled,history,footer);
      saveCurrentDraft=()=>{draft={tab:currentTab,groupCampaignId,selected:[...selected],chips:[...form.querySelectorAll('[name=chips]:checked')].map(el=>el.value),nome:form.elements.nome.value,day:form.elements.envio_dia.value,hour:form.elements.envio_hora.value,minute:form.elements.envio_minuto.value,intervalo:form.elements.intervalo.value,texto:form.elements.texto.value,term:root.querySelector('#dgBusca').value,kind:root.querySelector('#dgTipoGrupo').value,min:root.querySelector('#dgMinMembros').value,hideCommunity:root.querySelector('#dgOcultarComunidade').checked,fileName:A.disparoDraftFileWs===ws&&A.disparoDraftFile?A.disparoDraftFile.name:draft.fileName};try{sessionStorage.setItem(draftKey,JSON.stringify(draft));}catch{}};
      root.oninput=saveCurrentDraft;root.onchange=saveCurrentDraft;
      if(audience==='contatos'){nav.querySelector('[data-dg-tab="campanhas"]')?.remove();groupGuide.hidden=true;campaignPanel.hidden=true;root.querySelector('.atd-camp-selector').hidden=true;}
      const steps=audience==='contatos'?['configuracao','criacao','agendado','historico']:['campanhas','configuracao','criacao','agendado','historico'],labels={campanhas:'Campanhas',configuracao:'Configuração',criacao:'Criação',agendado:'Agendado',historico:'Histórico'};
      const loadThumb=async holder=>{holder.dataset.loaded='1';try{const result=await api('disparos-grupos-media-url',{campanha_id:holder.dataset.dgMediaThumb},ws);if(!root.contains(holder))return;const visual=document.createElement(holder.dataset.dgMediaType==='video/mp4'?'video':'img');visual.src=result.url;visual.setAttribute('aria-label',result.nome||'Anexo do disparo');if(visual.tagName==='VIDEO'){visual.preload='metadata';visual.muted=true;visual.playsInline=true;}holder.replaceChildren(visual);}catch{holder.textContent='Prévia indisponível. Use o botão para abrir o anexo.';}};
      const thumbObserver=typeof IntersectionObserver==='undefined'?null:new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){thumbObserver.unobserve(entry.target);loadThumb(entry.target);}}),{rootMargin:'200px'});mediaObserver=thumbObserver;
      const loadVisibleThumbs=()=>root.querySelectorAll(`[data-dg-panel="${currentTab}"] [data-dg-media-thumb]:not([data-loaded])`).forEach(holder=>thumbObserver?thumbObserver.observe(holder):loadThumb(holder));
      const updateSelectedPreview=()=>{const chosen=rows.filter(g=>selected.has(g.id));root.querySelector('#dgChosenCount').textContent=`(${chosen.length})`;root.querySelector('#dgChosenList').innerHTML=chosen.map(g=>`<div><b>${esc(g.nome&&g.nome!==g.externo_id?g.nome:g.endereco||g.externo_id)}</b><small>${g.grupo?'Grupo':'Contato'} · ${esc(channels.find(c=>c.id===g.canal_id)?.nome||'Chip Evolution')}</small></div>`).join('')||`<p class="muted">Nenhum ${audience==='contatos'?'contato':'grupo'} selecionado. Volte à Configuração para escolher destinatários.</p>`;};
      const showTab=id=>{currentTab=id;root.querySelectorAll('[data-dg-panel]').forEach(el=>el.hidden=el.dataset.dgPanel!==id);nav.querySelectorAll('[data-dg-tab]').forEach(btn=>{btn.classList.toggle('pri',btn.dataset.dgTab===id);btn.setAttribute('aria-current',btn.dataset.dgTab===id?'page':'false');});const index=steps.indexOf(id);footer.querySelector('#dgPrev').hidden=index===0;const next=footer.querySelector('#dgNext');next.hidden=index===steps.length-1;next.textContent=index<steps.length-1?`Avançar para ${labels[steps[index+1]]} →`:'';if(id==='criacao')updateSelectedPreview();loadVisibleThumbs();saveCurrentDraft();};
      footer.querySelector('#dgPrev').onclick=()=>showTab(steps[Math.max(0,steps.indexOf(currentTab)-1)]);
      footer.querySelector('#dgNext').onclick=()=>showTab(steps[Math.min(steps.length-1,steps.indexOf(currentTab)+1)]);
      nav.querySelectorAll('[data-dg-tab]').forEach(btn=>btn.onclick=()=>showTab(btn.dataset.dgTab));showTab(currentTab);
      groupGuide.querySelector('#dgOpenCampaigns').onclick=()=>showTab('campanhas');
      let previewRenderedFile=null;
      const formatWhatsappPreview=value=>{const protectedCode=[],protect=(match,body)=>{const id=protectedCode.length;protectedCode.push(`<code>${esc(body)}</code>`);return `\u0001${id}\u0002`;};let text=String(value).replace(/```([\s\S]+?)```/g,protect).replace(/`([^`\n]+)`/g,protect);const inline=line=>esc(line).replace(/\*([^*\n\s](?:[^*\n]*?[^*\n\s])?)\*/g,'<strong>$1</strong>').replace(/_([^_\n\s](?:[^_\n]*?[^_\n\s])?)_/g,'<em>$1</em>').replace(/~([^~\n\s](?:[^~\n]*?[^~\n\s])?)~/g,'<s>$1</s>');const lines=text.split('\n').map(line=>{let match;if((match=line.match(/^\s*>\s+(.+)$/)))return `<span class="wa-preview-quote">${inline(match[1])}</span>`;if((match=line.match(/^\s*([*-])\s+(.+)$/)))return `<span class="wa-preview-list">• ${inline(match[2])}</span>`;if((match=line.match(/^\s*(\d+)\.\s+(.+)$/)))return `<span class="wa-preview-list">${match[1]}. ${inline(match[2])}</span>`;return `<span class="wa-preview-line">${inline(line)||'&nbsp;'}</span>`;});return lines.join('').replace(/\u0001(\d+)\u0002/g,(_m,id)=>protectedCode[Number(id)]||'');};
      const formatHelp=document.createElement('small');formatHelp.className='muted';formatHelp.textContent='Formatação: *negrito* · _itálico_ · ~tachado~ · ```monoespaçado``` · `código` · listas e > citação.';message.append(formatHelp);
      const updatePhone=()=>{const txt=form.elements.texto.value.trim(),file=A.disparoDraftFileWs===ws?A.disparoDraftFile:null,holder=root.querySelector('#dgPhoneMedia');root.querySelector('#dgPhoneText').innerHTML=formatWhatsappPreview(txt||'Sua mensagem aparecerá aqui.');if(file===previewRenderedFile)return;previewRenderedFile=file;holder.replaceChildren();if(previewObjectUrl){URL.revokeObjectURL(previewObjectUrl);previewObjectUrl=null;}if(file){previewObjectUrl=URL.createObjectURL(file);const el=document.createElement(file.type==='video/mp4'?'video':'img');el.src=previewObjectUrl;el.setAttribute('aria-label',file.name);if(el.tagName==='VIDEO')el.controls=true;holder.append(el);}};
      form.elements.texto.oninput=updatePhone;updatePhone();
      if(A.disparoDraftFileWs===ws&&A.disparoDraftFile)fileInfo.textContent=`${A.disparoDraftFile.name} · ${(A.disparoDraftFile.size/1024/1024).toFixed(2)} MB · preservado nesta página`;
      else if(draft.fileName)fileInfo.textContent=`Selecione novamente o anexo "${draft.fileName}" após recarregar a página.`;
      const list=root.querySelector('#dgGrupos'),search=root.querySelector('#dgBusca'),selectedCount=root.querySelector('#dgSelecionados'),checkChannels=()=>[...root.querySelectorAll('[name=chips]:checked')].map(x=>x.value);
      const render=()=>{const term=search.value.toLocaleLowerCase(),chosen=new Set(checkChannels()),kind=kindSaved,min=Number(minSaved),shown=rows.filter(g=>{const c=channels.find(x=>x.id===g.canal_id)||{};if(S.view==='atd-envios-whatsapp'&&g.grupo||S.view==='atd-envios-grupos'&&!g.grupo)return false;const container=g.grupo&&g.grupo_tipo==='comunidade',announcement=g.grupo&&g.grupo_tipo==='avisos_comunidade',person=!g.grupo;if(hideCommunity&&container)return false;if(kind==='pessoa'&&!person||kind==='comunidade'&&!container||kind==='avisos_comunidade'&&!announcement||kind==='grupo'&&(!g.grupo||container||announcement))return false;if(minSaved!==''&&(!g.grupo||g.grupo_membros==null||g.grupo_membros<min))return false;return !term||((g.nome===g.externo_id?'':g.nome)+' '+(g.endereco||'')+' '+g.externo_id+' '+(c.nome||'')).toLocaleLowerCase().includes(term);});list.innerHTML=shown.map(g=>{const c=channels.find(x=>x.id===g.canal_id)||{};if(S.view==='atd-envios-whatsapp'&&g.grupo||S.view==='atd-envios-grupos'&&!g.grupo)return false;const container=g.grupo&&g.grupo_tipo==='comunidade',announcement=g.grupo&&g.grupo_tipo==='avisos_comunidade',parent=rows.find(x=>x.canal_id===g.canal_id&&x.externo_id===g.grupo_pai_externo_id),person=!g.grupo,hasName=Boolean(g.nome&&g.nome!==g.externo_id),title=hasName?g.nome:(person?(g.endereco||g.externo_id):container?'Comunidade sem nome':announcement?'Grupo de avisos sem nome':'Grupo sem nome'),badge=person?'Contato':container?'Comunidade':announcement?'Grupo de avisos':parent?'Grupo vinculado a '+(parent.nome===parent.externo_id?'uma comunidade':parent.nome):'Grupo normal',online=canSend(c),disabled=container||!online||!chosen.has(g.canal_id),technical=person?(g.endereco||g.externo_id):(hasName?'':'ID: '+g.externo_id),extra=container?' · comunidade não recebe envio':!online?' · chip desconectado ou desativado':!chosen.has(g.canal_id)?' · selecione este chip acima':'';return `<label class="${container?'is-community':''}${announcement?' is-announcement':''}${person?' is-contact':''}${online?'':' is-offline'}"><input type="checkbox" name="destinatarios" value="${esc(g.id)}" data-channel="${esc(g.canal_id)}" ${selected.has(g.id)?'checked':''} ${disabled?'disabled':''}><span class="atd-disparo-conteudo"><b>${esc(title)}</b><small class="atd-grupo-tipo">${esc(badge)}</small><small>${technical?esc(technical)+' · ':''}${esc(c.nome||'Chip Evolution')}${extra}${g.ultima_em?' · última atividade '+new Date(g.ultima_em).toLocaleDateString('pt-BR'):''}</small>${g.grupo&&g.grupo_membros!=null?`<small class="atd-grupo-membros">${esc(g.grupo_membros)} membros</small>`:''}</span><span class="atd-avatar atd-disparo-avatar" data-dg-avatar-id="${esc(g.id)}">${person?'●':container?'◉':announcement?'▤':'♟'}</span></label>`;}).join('')||'<p class="muted">Nenhum destinatário corresponde aos filtros.</p>';selectedCount.textContent=selected.size+' selecionados';const targets=shown.filter(g=>g.avatar_path).slice(0,35);if(targets.length)api('avatars',{ids:targets.map(g=>g.id)},ws).then(({avatares})=>{if(S.ws!==ws||S.view!==route)return;for(const g of targets){const el=[...list.querySelectorAll('[data-dg-avatar-id]')].find(x=>x.dataset.dgAvatarId===g.id),url=avatares?.[g.id];if(!el||!url)continue;const img=document.createElement('img');img.src=url;img.alt='';img.loading='lazy';img.onerror=()=>img.remove();el.replaceChildren(img);}}).catch(()=>{});};
      const campaignSelect=root.querySelector('#dgGroupCampaignSelect'),campaignSummary=root.querySelector('#dgCampaignSummary');
      const applyGroupCampaign=(id,move=false)=>{const c=groupCampaigns.find(x=>x.id===id);groupCampaignId=c?.id||'';campaignSelect.value=groupCampaignId;selection.hidden=Boolean(c);chips.hidden=Boolean(c);if(c){selected=new Set(c.conversas||[]);const groupChannels=new Set(rows.filter(g=>selected.has(g.id)).map(g=>g.canal_id));form.querySelectorAll('[name=chips]').forEach(input=>input.checked=!input.disabled&&groupChannels.has(input.value));campaignSummary.hidden=false;campaignSummary.innerHTML=`<b>${esc(c.nome)}</b><span>${selected.size} grupos vinculados. O envio usará a composição atual da campanha.</span>`;}else{campaignSummary.hidden=true;campaignSummary.replaceChildren();}render();updateSelectedPreview();saveCurrentDraft();if(move)showTab('configuracao');};
      campaignSelect.onchange=()=>applyGroupCampaign(campaignSelect.value);
      if(groupCampaignId)applyGroupCampaign(groupCampaignId);else campaignSelect.value='';
      const campForm=root.querySelector('#dgCampForm'),campManager=root.querySelector('#dgCampManager');
      const openCampForm=id=>{const c=groupCampaigns.find(x=>x.id===id);campForm.dataset.id=c?.id||'';campForm.elements.nome.value=c?.nome||'';campForm.elements.descricao.value=c?.descricao||'';root.querySelector('#dgCampFormTitle').textContent=c?'Editar campanha':'Nova campanha';campForm.hidden=false;campForm.scrollIntoView({block:'nearest'});};
      root.querySelector('#dgCampNew').onclick=()=>openCampForm('');
      root.querySelector('#dgCampFormCancel').onclick=()=>{campForm.hidden=true;};
      root.querySelectorAll('[data-camp-edit]').forEach(btn=>btn.onclick=()=>openCampForm(btn.dataset.campEdit));
      root.querySelectorAll('[data-camp-use]').forEach(btn=>btn.onclick=()=>applyGroupCampaign(btn.dataset.campUse,true));
      const campaignLink=c=>{const u=new URL('grupo.html',location.href);u.searchParams.set('c',c.link_token);return u.href;};
      root.querySelectorAll('[data-camp-manage]').forEach(btn=>{const c=groupCampaigns.find(x=>x.id===btn.dataset.campManage),card=btn.closest('article');if(!c||!card)return;card.insertAdjacentHTML('beforeend',`<div class="atd-camp-public-link"><b>Link de entrada</b><input readonly aria-label="Link público da campanha" value="${esc(campaignLink(c))}"><span>${c.link_ativo?'Ativo':'Inativo'} · ${(c.conversas||[]).length} grupos vinculados · ${Number(c.link_cliques||0)} aberturas</span><button type="button" class="btn sm pri" data-camp-copy="${esc(c.id)}" ${c.link_ativo?'':'disabled'}>Copiar link</button>${c.link_ativo?`<button type="button" class="btn sm" data-camp-link-off="${esc(c.id)}">Desativar</button>`:`<button type="button" class="btn sm" data-camp-link-on="${esc(c.id)}" ${(c.conversas||[]).length?'':'disabled'}>Ativar link</button><small>${(c.conversas||[]).length?'Ative o link para começar a distribuir convites.':'Marque grupos em Gerenciar grupos e clique em Salvar grupos selecionados.'}</small>`}</div>`);});
      root.querySelectorAll('[data-camp-copy]').forEach(btn=>btn.onclick=async()=>{const c=groupCampaigns.find(x=>x.id===btn.dataset.campCopy),url=c&&campaignLink(c);if(!url)return;try{await navigator.clipboard.writeText(url);toast('Link da campanha copiado.');}catch{prompt('Copie o link da campanha:',url);}});
      root.querySelectorAll('[data-camp-link-on],[data-camp-link-off]').forEach(btn=>btn.onclick=()=>act(async()=>{const id=btn.dataset.campLinkOn||btn.dataset.campLinkOff,ativo=Boolean(btn.dataset.campLinkOn);await api('grupo-campanha-link-save',{id,ativo},ws);toast(ativo?'Link de entrada ativado.':'Link de entrada desativado.');await refresh();}));
      campForm.onsubmit=e=>{e.preventDefault();act(async()=>{const result=await api('grupo-campanha-save',{id:campForm.dataset.id||undefined,nome:campForm.elements.nome.value,descricao:campForm.elements.descricao.value},ws);managerId=result.campanha.id;toast('Campanha salva.');await refresh();});};
      const renderManager=()=>{const c=groupCampaigns.find(x=>x.id===managerId);if(!c){campManager.hidden=true;return;}campManager.hidden=false;const linked=new Set(c.conversas||[]),available=rows.filter(g=>g.grupo&&g.grupo_tipo!=='comunidade'),connected=channels.filter(canSend);campManager.innerHTML=`<div class="atd-camp-head"><div><h3>${esc(c.nome)}</h3><p class="muted">${linked.size} grupos vinculados</p></div><button type="button" class="btn sm" id="dgCampClose">Fechar</button></div><div class="atd-camp-manager-grid"><section><h4>Importar grupos existentes</h4><p class="muted">Marque os grupos já encontrados nos chips Evolution. Comunidades são apenas contêineres e não recebem mensagens.</p><input type="search" id="dgCampSearch" placeholder="Buscar grupo ou chip"><div id="dgCampGroups" class="atd-camp-groups"></div><button type="button" class="btn pri" id="dgCampSaveGroups">Salvar grupos selecionados</button></section><section><h4>Criar grupo</h4><form id="dgCampCreateGroup" class="atd-camp-form"><label>Chip Evolution<select name="canal_id" required>${connected.map(ch=>`<option value="${esc(ch.id)}">${esc(ch.nome)}</option>`).join('')}</select></label><label>Nome do grupo<input name="nome" maxlength="100" required></label><label>Descrição<textarea name="descricao" maxlength="1000" rows="3"></textarea></label><label>Telefone de pelo menos um participante com DDI<input name="participantes" placeholder="5511999999999" required><small>Separe vários telefones por vírgula.</small></label><button type="submit" class="btn pri" ${connected.length?'':'disabled'}>Criar na Evolution</button></form></section></div><section class="atd-camp-linked"><h4>Grupos da campanha</h4><div>${rows.filter(g=>linked.has(g.id)).map(g=>`<article><div><b>${esc(g.nome||g.externo_id)}</b><small>${esc(channels.find(ch=>ch.id===g.canal_id)?.nome||'Chip')} · ${g.grupo_membros??'?'} membros</small></div><button type="button" class="btn sm" data-camp-group-edit="${esc(g.id)}">Editar grupo</button></article>`).join('')||'<p class="muted">Importe ou crie um grupo para esta campanha.</p>'}</div></section><section id="dgCampGroupEditor" class="atd-camp-group-editor" hidden></section>`;
        campManager.querySelector('.atd-camp-head').insertAdjacentHTML('afterend',`<section class="atd-camp-link-detail"><div><b>Link público desta campanha</b><span class="pill ${c.link_ativo?'good':'warn'}">${c.link_ativo?'Ativo':'Inativo'}</span></div><input id="dgCampLinkValue" readonly value="${esc(campaignLink(c))}" aria-label="Endereço do link público"><p>${linked.size?`${linked.size} grupos vinculados · ${Number(c.link_cliques||0)} aberturas registradas`:'Primeiro marque os grupos abaixo e clique em Salvar grupos selecionados. O endereço já está reservado para esta campanha.'}</p><div class="acts"><button type="button" class="btn pri sm" id="dgCampLinkCopy" ${c.link_ativo?'':'disabled'}>Copiar link</button><button type="button" class="btn sm" id="dgCampLinkToggle" ${!c.link_ativo&&!linked.size?'disabled':''}>${c.link_ativo?'Desativar link':'Ativar link'}</button></div></section>`);
        campManager.querySelector('#dgCampLinkCopy').onclick=async()=>{try{await navigator.clipboard.writeText(campaignLink(c));toast('Link copiado.');}catch{prompt('Copie o link:',campaignLink(c));}};
        campManager.querySelector('#dgCampLinkToggle').onclick=()=>act(async()=>{await api('grupo-campanha-link-save',{id:c.id,ativo:!c.link_ativo},ws);toast(c.link_ativo?'Link desativado.':'Link ativado.');await refresh();});
        campManager.insertAdjacentHTML('beforeend',`<section class="atd-camp-bulk"><h4>Alterar todos os grupos da campanha</h4><p class="muted">Aplique apenas os campos preenchidos ou selecionados aos ${linked.size} grupos vinculados. Mantenha esta página aberta durante a atualização.</p><form id="dgCampBulkForm" class="atd-camp-form"><label>Novo nome para todos (opcional)<input name="nome" maxlength="100" placeholder="Deixe vazio para manter os nomes atuais"></label><label><input type="checkbox" name="aplicar_descricao"> Substituir a descrição de todos</label><label>Nova descrição<textarea name="descricao" maxlength="1000" rows="3" placeholder="Pode ficar vazia para limpar a descrição"></textarea></label><label>Nova foto para todos (opcional)<input name="foto" type="file" accept="image/jpeg,image/png,image/webp"><small>JPG, PNG ou WebP até 2 MB.</small></label><label>Quem pode enviar mensagens<select name="envio"><option value="">Manter configuração atual</option><option value="announcement">Somente administradores</option><option value="not_announcement">Todos os membros</option></select></label><label>Quem pode editar dados do grupo<select name="edicao"><option value="">Manter configuração atual</option><option value="locked">Somente administradores</option><option value="unlocked">Todos os membros</option></select></label><button type="submit" class="btn pri" ${linked.size?'':'disabled'}>Aplicar aos ${linked.size} grupos</button><p id="dgCampBulkStatus" role="status" aria-live="polite"></p></form></section>`);
        campManager.querySelector('#dgCampSearch').insertAdjacentHTML('beforebegin',`<div class="atd-camp-sync"><select id="dgCampSyncChip" aria-label="Chip para buscar grupos">${connected.map(ch=>`<option value="${esc(ch.id)}">${esc(ch.nome)}</option>`).join('')}</select><button type="button" class="btn sm" id="dgCampSync" ${connected.length?'':'disabled'}>Buscar grupos novos na Evolution</button></div><small id="dgCampSyncStatus" class="muted"></small>`);
        campManager.querySelector('#dgCampSync').onclick=()=>act(async()=>{const canal_id=campManager.querySelector('#dgCampSyncChip').value;await api('sincronizar',{canal_id,modo_sincronizacao:'grupos_novos'},ws);campManager.querySelector('#dgCampSyncStatus').textContent='Busca iniciada. Atualize a tela em alguns minutos para importar os novos grupos.';});
        const pending=new Set(linked),searchGroups=()=>{const term=campManager.querySelector('#dgCampSearch').value.toLocaleLowerCase();campManager.querySelector('#dgCampGroups').innerHTML=available.filter(g=>(g.nome+' '+g.externo_id+' '+(channels.find(ch=>ch.id===g.canal_id)?.nome||'')).toLocaleLowerCase().includes(term)).map(g=>`<label><input type="checkbox" value="${esc(g.id)}" ${pending.has(g.id)?'checked':''}><span><b>${esc(g.nome||g.externo_id)}</b><small>${esc(channels.find(ch=>ch.id===g.canal_id)?.nome||'Chip')} · ${g.grupo_membros??'?'} membros</small></span></label>`).join('')||'<p class="muted">Nenhum grupo encontrado.</p>';};searchGroups();campManager.querySelector('#dgCampSearch').oninput=searchGroups;campManager.querySelector('#dgCampGroups').onchange=e=>{const cb=e.target.closest('input[type=checkbox]');if(cb){if(cb.checked)pending.add(cb.value);else pending.delete(cb.value);}};
        const saveGroupsButton=campManager.querySelector('#dgCampSaveGroups'),updatePendingCount=()=>{saveGroupsButton.textContent=`Salvar ${pending.size} grupos na campanha`;};updatePendingCount();campManager.querySelector('#dgCampGroups').addEventListener('change',updatePendingCount);
        campManager.querySelector('#dgCampClose').onclick=()=>{managerId='';campManager.hidden=true;};
        campManager.querySelector('#dgCampSaveGroups').onclick=()=>act(async()=>{await api('grupo-campanha-grupos-save',{campanha_id:c.id,conversas:[...pending]},ws);toast('Grupos da campanha atualizados.');await refresh();});
        const createGroupForm=campManager.querySelector('#dgCampCreateGroup');
        createGroupForm.querySelector('[type=submit]').insertAdjacentHTML('beforebegin','<label>Foto do grupo (opcional)<input name="foto" type="file" accept="image/jpeg,image/png,image/webp"><small>JPG, PNG ou WebP até 2 MB.</small></label><label>Quem pode enviar mensagens<select name="envio"><option value="not_announcement">Todos os membros</option><option value="announcement">Somente administradores</option></select></label><label>Quem pode editar os dados do grupo<select name="edicao"><option value="unlocked">Todos os membros</option><option value="locked">Somente administradores</option></select></label><p class="muted">Aprovação de entrada ainda não é oferecida pela Evolution 2.3.7.</p>');
        createGroupForm.onsubmit=e=>{e.preventDefault();const fd=new FormData(e.currentTarget);act(async()=>{const file=fd.get('foto');if(file?.size&&(file.size>2*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type)))throw Error('Use foto JPG, PNG ou WebP de até 2 MB.');const created=await api('grupo-campanha-criar-grupo',{campanha_id:c.id,canal_id:fd.get('canal_id'),nome:fd.get('nome'),descricao:fd.get('descricao'),participantes:fd.get('participantes')},ws),base={campanha_id:c.id,conversa_id:created.conversa_id};try{if(fd.get('envio')==='announcement')await api('grupo-campanha-grupo-update',{...base,tipo:'announcement'},ws);if(fd.get('edicao')==='locked')await api('grupo-campanha-grupo-update',{...base,tipo:'locked'},ws);if(file?.size){const prep=await api('grupo-campanha-foto-preparar',{nome:file.name,mime:file.type},ws),up=await sb.storage.from('atendimento').uploadToSignedUrl(prep.path,prep.token,file,{contentType:file.type});if(up.error)throw Error(up.error.message);await api('grupo-campanha-grupo-update',{...base,tipo:'foto',path:prep.path},ws);}}catch(error){await refresh();throw Error('Grupo criado, mas não foi possível aplicar todas as configurações: '+error.message);}toast('Grupo criado, configurado e vinculado à campanha.');await refresh();});};
        const bulkForm=campManager.querySelector('#dgCampBulkForm'),bulkStatus=campManager.querySelector('#dgCampBulkStatus'),bulkSection=campManager.querySelector('.atd-camp-bulk');
        campManager.querySelector('.atd-camp-linked').before(bulkSection);
        const fields=[...bulkForm.querySelectorAll(':scope > label')],submitBulk=bulkForm.querySelector('[type=submit]');
        const bulkCard=(title,nodes)=>{const card=document.createElement('section'),heading=document.createElement('h5');card.className='atd-camp-bulk-card';heading.textContent=title;card.append(heading,...nodes);return card;};
        const bulkPreview=document.createElement('div'),bulkProgress=document.createElement('progress'),bulkFailures=document.createElement('ul');bulkPreview.className='atd-camp-bulk-preview';bulkPreview.setAttribute('aria-live','polite');bulkProgress.id='dgCampBulkProgress';bulkProgress.max=linked.size||1;bulkProgress.value=0;bulkProgress.hidden=true;bulkFailures.id='dgCampBulkFailures';
        bulkForm.replaceChildren(bulkCard('1. Nome e descrição',fields.slice(0,3)),bulkCard('2. Imagem',fields.slice(3,4)),bulkCard('3. Privacidade',fields.slice(4,6)),bulkPreview,submitBulk,bulkProgress,bulkStatus,bulkFailures);
        const updateBulkPreview=()=>{const fd=new FormData(bulkForm),changes=[];if(String(fd.get('nome')||'').trim())changes.push('nome');if(fd.has('aplicar_descricao'))changes.push('descrição');if(fd.get('foto')?.size)changes.push('foto');if(fd.get('envio'))changes.push('quem envia mensagens');if(fd.get('edicao'))changes.push('quem edita dados');bulkPreview.textContent=changes.length?`Aplicar em ${linked.size} grupos: ${changes.join(', ')}. Os demais dados serão preservados.`:'Escolha os campos que deseja alterar. Os demais dados serão preservados.';};bulkForm.oninput=updateBulkPreview;bulkForm.onchange=updateBulkPreview;updateBulkPreview();
        bulkForm.onsubmit=e=>{e.preventDefault();const fd=new FormData(e.currentTarget),nome=String(fd.get('nome')||'').trim(),descricao=String(fd.get('descricao')||''),applyDescription=fd.has('aplicar_descricao'),envio=String(fd.get('envio')||''),edicao=String(fd.get('edicao')||''),file=fd.get('foto'),ids=[...linked];
          act(async()=>{if(!nome&&!applyDescription&&!envio&&!edicao&&!file?.size)throw Error('Escolha pelo menos uma alteração para aplicar.');if(file?.size&&(file.size>2*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type)))throw Error('Use foto JPG, PNG ou WebP de até 2 MB.');if(!ids.length)throw Error('A campanha não tem grupos vinculados.');if(!confirm(`Aplicar as alterações a ${ids.length} grupos da campanha "${c.nome}"? Esta ação modifica os grupos no WhatsApp.`))return;
            const submit=bulkForm.querySelector('[type=submit]');submit.disabled=true;bulkProgress.hidden=false;bulkProgress.value=0;bulkFailures.replaceChildren();let path='',done=0;const failures=[];
            try{if(file?.size){bulkStatus.textContent='Enviando foto…';const prep=await api('grupo-campanha-foto-preparar',{nome:file.name,mime:file.type},ws),up=await sb.storage.from('atendimento').uploadToSignedUrl(prep.path,prep.token,file,{contentType:file.type});if(up.error)throw Error(up.error.message);path=prep.path;}
              for(const [index,id] of ids.entries()){if(S.ws!==ws||S.view!==route||!root.isConnected){bulkStatus.textContent=`Interrompido após ${index} de ${ids.length} grupos. Reabra a campanha para continuar.`;break;}bulkStatus.textContent=`Atualizando ${index+1} de ${ids.length} grupos…`;
                try{const base={campanha_id:c.id,conversa_id:id};if(nome)await api('grupo-campanha-grupo-update',{...base,tipo:'nome',valor:nome},ws);if(applyDescription)await api('grupo-campanha-grupo-update',{...base,tipo:'descricao',valor:descricao},ws);if(envio)await api('grupo-campanha-grupo-update',{...base,tipo:envio},ws);if(edicao)await api('grupo-campanha-grupo-update',{...base,tipo:edicao},ws);if(path)await api('grupo-campanha-grupo-update',{...base,tipo:'foto',path},ws);done++;}catch(error){const group=rows.find(g=>g.id===id);failures.push(`${group?.nome||id}: ${error.message}`);}bulkProgress.value=index+1;
              }
              bulkStatus.textContent=`${done} de ${ids.length} grupos atualizados${failures.length?`; ${failures.length} falhas`:' com sucesso'}.`;for(const failure of failures){const item=document.createElement('li');item.textContent=failure;bulkFailures.append(item);}toast(failures.length?`Atualização parcial: ${done} grupos concluídos.`:`${done} grupos atualizados.`,Boolean(failures.length));
            }finally{submit.disabled=false;}
          });
        };
        campManager.querySelectorAll('[data-camp-group-edit]').forEach(btn=>{const photo=document.createElement('button'),picker=document.createElement('input');photo.type='button';photo.className='btn sm';photo.textContent='Trocar foto';picker.type='file';picker.accept='image/jpeg,image/png,image/webp';picker.hidden=true;picker.setAttribute('aria-label','Nova foto do grupo');btn.after(photo,picker);photo.onclick=()=>picker.click();picker.onchange=()=>{const file=picker.files?.[0];if(!file)return;act(async()=>{if(file.size>2*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type))throw Error('Use foto JPG, PNG ou WebP de até 2 MB.');photo.disabled=true;try{const prep=await api('grupo-campanha-foto-preparar',{nome:file.name,mime:file.type},ws),up=await sb.storage.from('atendimento').uploadToSignedUrl(prep.path,prep.token,file,{contentType:file.type});if(up.error)throw Error(up.error.message);await api('grupo-campanha-grupo-update',{campanha_id:c.id,conversa_id:btn.dataset.campGroupEdit,tipo:'foto',path:prep.path},ws);toast('Foto do grupo atualizada.');await refresh();}finally{photo.disabled=false;}});};});
        campManager.querySelectorAll('[data-camp-group-edit]').forEach(btn=>btn.onclick=()=>act(async()=>{const result=await api('grupo-campanha-grupo-info',{campanha_id:c.id,conversa_id:btn.dataset.campGroupEdit},ws),g=result,editor=campManager.querySelector('#dgCampGroupEditor');editor.hidden=false;editor.innerHTML=`<h4>Editar ${esc(g.nome||'grupo')}</h4><form id="dgCampEditGroup" class="atd-camp-form"><label>Nome<input name="nome" maxlength="100" value="${esc(g.nome||'')}" required></label><label>Descrição<textarea name="descricao" maxlength="1000" rows="3">${esc(g.descricao||'')}</textarea></label><label>Foto do grupo<input name="foto" type="file" accept="image/jpeg,image/png,image/webp"></label><label>Quem pode enviar mensagens<select name="envio"><option value="not_announcement" ${g.somente_admin_envia?'':'selected'}>Todos os membros</option><option value="announcement" ${g.somente_admin_envia?'selected':''}>Somente administradores</option></select></label><label>Quem pode editar dados do grupo<select name="edicao"><option value="unlocked" ${g.somente_admin_edita?'':'selected'}>Todos os membros</option><option value="locked" ${g.somente_admin_edita?'selected':''}>Somente administradores</option></select></label><p class="muted">Aprovação de entrada não está disponível na API Evolution 2.3.7.</p><button type="submit" class="btn pri">Salvar alterações no WhatsApp</button></form>`;editor.scrollIntoView({block:'nearest'});editor.querySelector('form').onsubmit=event=>{event.preventDefault();const fd=new FormData(event.currentTarget);act(async()=>{const file=fd.get('foto'),base={campanha_id:c.id,conversa_id:btn.dataset.campGroupEdit};
          if(String(fd.get('nome')).trim()!==g.nome)await api('grupo-campanha-grupo-update',{...base,tipo:'nome',valor:fd.get('nome')},ws);
          if(String(fd.get('descricao')).trim()!==g.descricao)await api('grupo-campanha-grupo-update',{...base,tipo:'descricao',valor:fd.get('descricao')},ws);
          const envio=fd.get('envio'),edicao=fd.get('edicao');
          if((envio==='announcement')!==g.somente_admin_envia)await api('grupo-campanha-grupo-update',{...base,tipo:envio},ws);
          if((edicao==='locked')!==g.somente_admin_edita)await api('grupo-campanha-grupo-update',{...base,tipo:edicao},ws);
          if(file?.size){if(file.size>2*1024*1024)throw Error('A foto deve ter até 2 MB.');const prep=await api('grupo-campanha-foto-preparar',{nome:file.name,mime:file.type},ws);const upload=await sb.storage.from('atendimento').uploadToSignedUrl(prep.path,prep.token,file,{contentType:file.type});if(upload.error)throw Error(upload.error.message);await api('grupo-campanha-grupo-update',{...base,tipo:'foto',path:prep.path},ws);}
          toast('Grupo atualizado na Evolution.');await refresh();});};}));
      };
      root.querySelectorAll('[data-camp-manage]').forEach(btn=>btn.onclick=()=>{managerId=btn.dataset.campManage;renderManager();campManager.scrollIntoView({block:'nearest'});});
      if(managerId)renderManager();
      const readFilters=()=>{termSaved=search.value;kindSaved=audience==='contatos'?'':root.querySelector('#dgTipoGrupo').value;minSaved=audience==='contatos'?'':root.querySelector('#dgMinMembros').value;hideCommunity=audience==='contatos'?false:root.querySelector('#dgOcultarComunidade').checked;render();};render();search.oninput=readFilters;root.querySelector('#dgTipoGrupo').onchange=readFilters;root.querySelector('#dgMinMembros').oninput=readFilters;root.querySelector('#dgOcultarComunidade').onchange=readFilters;root.querySelectorAll('[name=chips]').forEach(ch=>ch.onchange=()=>{if(!ch.checked)rows.filter(g=>g.canal_id===ch.value).forEach(g=>selected.delete(g.id));render();});list.onchange=e=>{const cb=e.target.closest('[name=destinatarios]');if(!cb)return;if(cb.checked)selected.add(cb.value);else selected.delete(cb.value);selectedCount.textContent=selected.size+' selecionados';};root.querySelector('#dgTodos').onchange=e=>{list.querySelectorAll('[name=destinatarios]:not(:disabled)').forEach(cb=>{cb.checked=e.target.checked;if(e.target.checked)selected.add(cb.value);else selected.delete(cb.value);});selectedCount.textContent=selected.size+' selecionados';};
      root.querySelector('#dgAplicarSegmento').onclick=()=>{const s=segments.find(x=>x.id===root.querySelector('#dgSegmento').value);if(!s)return;const chosen=new Set(checkChannels()),valid=new Set(rows.filter(g=>known.has(g.id)&&chosen.has(g.canal_id)&&canSend(channels.find(c=>c.id===g.canal_id)||{})).map(g=>g.id));selected=new Set((s.conversas||[]).map(String).filter(id=>valid.has(id)));render();saveCurrentDraft();toast(selected.size<(s.conversas||[]).length?'Seleção carregada; destinatários fora desta aba ou desconectados foram ignorados.':'Seleção carregada.');};
      root.querySelector('#dgSalvarSegmento').onclick=()=>act(async()=>{const nome=root.querySelector('#dgNomeSegmento').value.trim();if(!nome||!selected.size)throw Error(!nome?'Informe um nome para o segmento.':'Selecione pelo menos um grupo ou contato.');const r=await api('disparos-segmento-save',{nome,conversas:[...selected]},ws);segments.push(r.segmento);const select=root.querySelector('#dgSegmento');select.insertAdjacentHTML('beforeend',`<option value="${esc(r.segmento.id)}">${esc(r.segmento.nome)} · ${r.segmento.conversas.length} destinatários</option>`);select.value=r.segmento.id;root.querySelector('#dgExcluirSegmento').disabled=false;toast('Segmento salvo.');});
      root.querySelector('#dgExcluirSegmento').onclick=()=>act(async()=>{const id=root.querySelector('#dgSegmento').value;if(!id)throw Error('Escolha um segmento.');if(!confirm('Excluir este segmento? Campanhas já agendadas não serão alteradas.'))return;await api('disparos-segmento-delete',{id},ws);const idx=segments.findIndex(s=>s.id===id);if(idx>=0)segments.splice(idx,1);root.querySelector(`#dgSegmento option[value="${CSS.escape(id)}"]`)?.remove();root.querySelector('#dgSegmento').value='';root.querySelector('#dgExcluirSegmento').disabled=!segments.length;toast('Segmento removido.');});
      root.querySelector('[name=midia]').onchange=e=>{const f=e.target.files[0];A.disparoDraftFileWs=ws;A.disparoDraftFile=f||null;draft.fileName=f?.name||'';root.querySelector('#dgPreview').textContent=f?`${f.name} · ${(f.size/1024/1024).toFixed(2)} MB`:'';updatePhone();};
      root.querySelector('#dgForm').onsubmit=e=>{e.preventDefault();const fd=new FormData(e.currentTarget);act(async()=>{const channelsPicked=checkChannels(),items=rows.filter(g=>selected.has(g.id)),sendable=items.filter(g=>channelsPicked.includes(g.canal_id)&&canSend(channels.find(c=>c.id===g.canal_id)||{})),file=A.disparoDraftFileWs===ws?A.disparoDraftFile:null;if(!items.length)throw Error('Selecione grupos ou contatos.');if(items.length!==sendable.length)throw Error('Há destinatários fora dos chips conectados selecionados.');if(!String(fd.get('texto')||'').trim()&&!file)throw Error('Escreva a mensagem ou selecione uma imagem/vídeo.');if(file&&(!file.size||file.size>(file.type==='video/mp4'?30:7)*1024*1024||!['image/jpeg','image/png','image/webp','video/mp4'].includes(file.type)))throw Error('Use imagem até 7 MB ou vídeo MP4 até 30 MB.');const start=scheduledAt(fd);if(!Number.isFinite(start.getTime())||start.getTime()<Date.now()+60000)throw Error('Escolha horário com ao menos 1 minuto de antecedência.');let media;if(file){const prepared=await api('disparos-grupos-media-preparar',{nome:file.name,mime:file.type},ws);const up=await sb.storage.from('atendimento').uploadToSignedUrl(prepared.path,prepared.token,file,{contentType:file.type});if(up.error)throw Error('Não foi possível enviar a mídia: '+up.error.message);media={path:prepared.path,nome:file.name,mime:file.type};}await api('disparos-grupos-create',{nome:String(fd.get('nome')||'').trim()||'Disparo de grupos',iniciar_em:start.toISOString(),intervalo_segundos:Number(fd.get('intervalo')),canal_ids:channelsPicked,grupos:sendable.map(g=>({conversa_id:g.id,canal_id:g.canal_id})),texto:String(fd.get('texto')||''),midia:media,grupo_campanha_id:groupCampaignId||null},ws);toast('Campanha criada; envio sequencial iniciado no horário escolhido.');selected.clear();draft={};saveCurrentDraft=()=>{};try{sessionStorage.removeItem(draftKey);}catch{}A.disparoDraftFile=null;A.disparoDraftFileWs=null;currentTab='agendado';await refresh();});};
      root.querySelectorAll('[data-dg-cancel]').forEach(btn=>btn.onclick=()=>act(async()=>{await api('disparos-grupos-cancel',{campanha_id:btn.dataset.dgCancel},ws);toast('Campanha cancelada.');await refresh();}));
      root.querySelectorAll('[data-dg-edit]').forEach(btn=>btn.onclick=()=>{const editForm=root.querySelector(`[data-dg-edit-form="${CSS.escape(btn.dataset.dgEdit)}"]`);if(!editForm)return;editForm.querySelectorAll('input,select,textarea').forEach(el=>el.disabled=false);editForm.querySelector('.atd-disparo-editar-actions').hidden=false;btn.disabled=true;});
      root.querySelectorAll('[data-dg-edit-cancel]').forEach(btn=>btn.onclick=()=>{const editForm=root.querySelector(`[data-dg-edit-form="${CSS.escape(btn.dataset.dgEditCancel)}"]`);if(!editForm)return;editForm.reset();editForm.querySelectorAll('input,select,textarea').forEach(el=>el.disabled=true);editForm.querySelector('.atd-disparo-editar-actions').hidden=true;editForm.querySelector('[data-dg-edit]').disabled=false;});
      root.querySelectorAll('[data-dg-edit-form]').forEach(editForm=>editForm.onsubmit=e=>{e.preventDefault();act(async()=>{const fd=new FormData(editForm),start=scheduledAt(fd);if(!Number.isFinite(start.getTime()))throw Error('Informe data e hora válidas.');const result=await api('disparos-grupos-edit',{campanha_id:editForm.dataset.dgEditForm,nome:String(fd.get('nome')||''),iniciar_em:start.toISOString(),texto:String(fd.get('texto')||'')},ws);toast(`Agendamento atualizado para ${result.atualizados} destinatários.`);await refresh();});});
      root.querySelectorAll('[data-dg-media]').forEach(btn=>btn.onclick=()=>act(async()=>{const result=await api('disparos-grupos-media-url',{campanha_id:btn.dataset.dgMedia},ws);window.open(result.url,'_blank','noopener,noreferrer');}));
      root.querySelectorAll('[data-dg-recipients]').forEach(details=>details.ontoggle=()=>{if(!details.open||details.dataset.loaded)return;details.dataset.loaded='1';const list=details.querySelector('.atd-disparo-destinatarios-lista');list.textContent='Carregando destinatários…';api('disparos-grupos-destinatarios',{campanha_id:details.dataset.dgRecipients},ws).then(result=>{if(!root.contains(details))return;list.innerHTML=(result.destinatarios||[]).map(item=>`<div><span>${esc(item.nome)} <small>${item.grupo?'Grupo':'Contato'}</small></span><small>${esc(item.status)}</small></div>`).join('')||'<p class="muted">Nenhum destinatário encontrado.</p>';}).catch(error=>{details.dataset.loaded='';list.textContent='Não foi possível carregar: '+error.message;});});
    };m.querySelector('#dgAtualizar').onclick=()=>act(refresh);root.innerHTML='Carregando…';try{await refresh();}catch(e){root.innerHTML=`<div class="empty"><b>Não foi possível abrir Disparos</b><p>${esc(e.message)}</p><p>Confira a migration e a Edge de Atendimento.</p></div>`;}
  }
  NAV.splice(NAV.findIndex(g=>g.g==='Vendas')+1,0,{g:'Atendimento',items:[['atd-conversas','Conversas'],['atd-contatos','Contatos'],['atd-canais','Canais e conexões'],['atd-templates','Templates']],subs:[{g:'Envios',mod:'vendas',items:[['atd-envios-whatsapp','WhatsApp'],['atd-envios-email','E-mail'],['atd-envios-oficial','WhatsApp Oficial'],['atd-envios-grupos','Grupos']]},{g:'Automações',mod:'vendas',items:[['atd-auto-whatsapp','WhatsApp'],['atd-auto-instagram','Instagram'],['atd-auto-email','E-mail'],['atd-auto-oficial','WhatsApp Oficial']]}]});
  // Deixa as telas do Atendimento visíveis já na entrada, sem exigir abrir o grupo manualmente.
  S.abertos.Atendimento = true;S.abertos.Envios=true;S.abertos.Automações=true;
  MOD_GRUPO.Atendimento='vendas';
  ICO.Atendimento=ICO['crm-dms']||ICO.Vendas||'';ICO['atd-conversas']=ICO['crm-dms']||'';ICO['atd-contatos']=ICO['cad-clientes']||ICO['crm-dms']||'';ICO['atd-transmissao']=ICO['crm-dms']||'';ICO['atd-grupos-disparo']=ICO['crm-dms']||'';ICO['atd-canais']=ICO['cfg-integracoes'];ICO['atd-templates']=ICO['crm-dms']||'';ICO['atd-automacoes']=ICO['crm-dms']||'';
  ICO.Envios=ICO['crm-dms']||'';ICO.Automações=ICO['gro-ciclo']||'';for(const id of ['atd-envios-whatsapp','atd-envios-email','atd-envios-oficial','atd-envios-grupos'])ICO[id]=ICO['crm-dms']||'';for(const id of ['atd-auto-whatsapp','atd-auto-instagram','atd-auto-email','atd-auto-oficial'])ICO[id]=ICO['gro-ciclo']||'';
  VIEWS['atd-grupos-disparo']=vDisparoGrupos;VIEWS['atd-conversas']=vAtendimento;VIEWS['atd-contatos']=vContatos;VIEWS['atd-transmissao']=vTransmissao;VIEWS['atd-canais']=vCanais;VIEWS['atd-templates']=vTemplates;VIEWS['atd-automacoes']=vAutomacoes;VIEWS['atd-envios-whatsapp']=vDisparoGrupos;VIEWS['atd-envios-email']=vTransmissao;VIEWS['atd-envios-oficial']=vTransmissao;VIEWS['atd-envios-grupos']=vDisparoGrupos;VIEWS['atd-auto-whatsapp']=vAutomacoes;VIEWS['atd-auto-instagram']=vAutomacoes;VIEWS['atd-auto-email']=vEmailAutomacoes;VIEWS['atd-auto-oficial']=vAutomacoes;
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
    const whatsapp=substituirAcao('WhatsApp API oficial','Conectar WhatsApp oficial',()=>conectarSocialZernio('whatsapp',ws),true);
    substituirAcao('WhatsApp (grupos e API)','Configurar Evolution API',()=>act(configurarEvolution),true);
    // Google Ads utiliza o OAuth Google já implementado em conexoes,
    // não a API de redes sociais da Zernio.
    substituirAcao('Google Ads','Conectar Google Ads',()=>act(async()=>{
      const volta=location.origin+location.pathname+'?v=cfg-integracoes';
      const result=await cxChama('iniciar',{ws,plataforma:'google',volta});
      if(!result?.url||new URL(result.url).protocol!=='https:')throw Error('URL Google OAuth inválida.');
      location.href=result.url;
    }),false);
    // Cartões de conteúdo: não confundir com Google Ads/TikTok Ads/LinkedIn Ads.
    for(const [catalogo,platform] of [['YouTube','youtube'],['LinkedIn','linkedin'],['TikTok','tiktok']]){
      const item=substituirAcao(catalogo,'Conectar '+catalogo,()=>conectarSocialZernio(platform,ws),false);
      if(!item)continue;
      const orig=item.card.querySelector('.pill');
      const summary=document.createElement('small');summary.className='muted';summary.textContent='Consultando autorização OAuth…';
      item.card.insertBefore(summary,item.botao.parentElement);
      try{
        const types={youtube:'youtube',linkedin:'linkedin',tiktok:'tiktok'};
        const linked=await q(sb.from('conexao_contas').select('nome,conexoes!inner(plataforma)').eq('workspace_id',ws)
          .eq('tipo',types[platform]).eq('conexoes.plataforma','zernio'));
        if(S.ws!==ws||S.view!=='cfg-integracoes'||!item.card.isConnected)return;
        summary.textContent=linked.length?linked.map(c=>c.nome).join(' · '):'Nenhuma conta autorizada neste cliente.';
        if(orig){orig.className='pill '+(linked.length?'good':'neutral');orig.textContent=linked.length?'Conectado':'Não conectado';}
      }catch{summary.textContent='Sem confirmação de autenticação.';}
    }
    if(metaCard){
      const toolbar=metaCard.querySelector('.btn')?.parentElement;
      if(toolbar && !toolbar.querySelector('[data-social-facebook]')){
        const facebook=document.createElement('button');
        facebook.className='btn sm';facebook.type='button';facebook.textContent='Conectar Página Facebook';
        facebook.setAttribute('data-social-facebook','1');
        facebook.onclick=e=>{e.stopPropagation();conectarSocialZernio('facebook',ws);};
        toolbar.append(facebook);
      }
    }
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
    if(whatsapp){
      const summary=document.createElement('small');
      summary.className='muted';summary.textContent='Conferindo autorização WhatsApp oficial…';
      whatsapp.card.insertBefore(summary,whatsapp.botao.parentElement);
      try{
        const linked=await q(sb.from('atd_canais').select('nome,numero,ativo,status')
          .eq('workspace_id',ws).eq('provedor','zernio').eq('canal','whatsapp').eq('ativo',true));
        if(S.ws!==ws||S.view!=='cfg-integracoes'||!whatsapp.card.isConnected)return;
        const active=linked.filter(x=>x.status==='conectado');
        const pill=whatsapp.card.querySelector('.pill');
        if(pill){pill.className='pill '+(active.length?'good':'neutral');pill.textContent=active.length?'Conectado':'Não conectado';}
        summary.textContent=active.length?active.map(x=>'API oficial · '+(x.numero?'+'+String(x.numero).replace(/\D/g,''):x.nome||'Número não identificado')).join(' · '):
          'Nenhum número WhatsApp oficial autorizado neste cliente.';
        whatsapp.botao.textContent=active.length?'Conectar outro WhatsApp oficial':'Conectar WhatsApp oficial';
      }catch{summary.textContent='Não foi possível consultar os números oficiais.';}
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
  window.atendimentoAbrirConversa=async id=>{
    S.view='atd-conversas';abreMenu(S.view);await render();
    const token=A.token;
    if(active(token))await openChat(id,token);
  };
  window.atendimentoConversarPessoa=async pessoaId=>{
    const ws=S.ws;
    try{
      const [pessoa,rows,canais,ctx]=await Promise.all([
        q(sb.from('pessoas').select('id,nome,telefone').eq('workspace_id',ws).eq('id',pessoaId).single()),
        q(sb.from('atd_conversas').select('id,nome,canal_id,ultima_em,atd_canais(nome,canal,provedor,numero)')
          .eq('workspace_id',ws).eq('pessoa_id',pessoaId).order('ultima_em',{ascending:false,nullsFirst:false})),
        q(sb.from('atd_canais').select('id,nome,canal,provedor,numero,status,ativo')
          .eq('workspace_id',ws).eq('ativo',true).order('nome')),
        api('contexto',{},ws)
      ]);
      if(S.ws!==ws)return;
      const rotuloCanal=c=>[c.canal==='whatsapp'?'WhatsApp':c.canal==='instagram'?'Instagram':c.canal||'Canal',c.nome||c.numero].filter(Boolean).join(' · ');
      const convCanal=r=>Array.isArray(r.atd_canais)?r.atd_canais[0]:r.atd_canais;
      const opcoes=rows.map(r=>({valor:'conversa:'+r.id,label:'Continuar · '+rotuloCanal(convCanal(r)),conversa:r.id}));
      const idsComConversa=new Set(rows.map(r=>r.canal_id));
      const telefone=String(pessoa.telefone||'').replace(/\D/g,'');
      const temTelefone=telefone.length>=10&&telefone.length<=13;
      const iniciaveis=ctx.editar&&temTelefone?canais.filter(c=>c.status==='conectado'&&['evolution','zernio'].includes(c.provedor)&&c.canal==='whatsapp'&&!idsComConversa.has(c.id)):[];
      if(temTelefone)iniciaveis.forEach(c=>opcoes.push({valor:'canal:'+c.id,label:'Nova conversa · '+rotuloCanal(c),canal:c.id,provedor:c.provedor}));
      if(!opcoes.length){
        const razao=!temTelefone?'Cadastre um telefone válido no contato para iniciar uma conversa.':'Nenhuma conversa existente ou canal WhatsApp conectado disponível.';
        toast(razao,true);return;
      }
      const notaInstagram='No Instagram, a conversa precisa ser iniciada pelo contato. DMs já recebidas aparecem em “Continuar”.';
      modal('Escolher canal para conversar',`<label>Canal / conversa<select name="destino">${opcoes.map((o,i)=>`<option value="${esc(o.valor)}"${i===0?' selected':''}>${esc(o.label)}</option>`).join('')}</select></label><p class="muted">${rows.length?'Conversas existentes ficam salvas no histórico do contato. ':''}WhatsApp oficial: a primeira mensagem será enviada por template aprovado. ${esc(notaInstagram)}</p>`,async d=>{
        const escolha=opcoes.find(o=>o.valor===d.destino);
        if(!escolha)throw Error('Canal indisponível. Atualize a tela.');
        if(escolha.conversa){await window.atendimentoAbrirConversa(escolha.conversa);return;}
        const criada=await api('criar-conversa-pessoa',{pessoa_id:pessoa.id,canal_id:escolha.canal},ws);
        await window.atendimentoAbrirConversa(criada.conversa_id);
      },'Abrir conversa');
    }catch(e){toast(e.message||'Não foi possível carregar as conversas deste contato.',true);}
  };
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&S.view==='atd-conversas')refreshCurrent(A.token);});
})();
