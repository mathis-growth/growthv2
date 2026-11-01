/* Central de Atendimento: módulo isolado para diminuir conflitos no index.html.
   Nunca guarda credenciais, mensagens ou anexos no localStorage. */
(() => {
  'use strict';
  const LABELS = {whatsapp:'WhatsApp',instagram:'Instagram',telegram:'Telegram',tiktok:'TikTok'};
  const A = {ws:null,sel:null,lista:[],canais:[],ctx:null,token:0,chatToken:0,drafts:new Map(),busca:'',canal:'',tipo:'',status:'',minhas:'',page:0,cursor:null,loaded:[],subscription:null,timer:null};
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
    $('#atdLista').innerHTML=A.lista.length?A.lista.map(c=>{const ch=A.canais.find(x=>x.id===c.canal_id)||{};return `<button class="atd-item atd-item--${tipoCanal(ch)}${A.sel===c.id?' on':''}" data-conversa="${c.id}"><span class="atd-card-top">${faixaCanal(ch)}</span><span class="atd-card-body">${c.nao_lidas?`<span class="atd-count">${c.nao_lidas}</span>`:''}<span class="atd-avatar" data-avatar-id="${c.id}">${c.grupo?'♟':esc(c.nome.slice(0,1).toUpperCase())}</span><b>${esc(c.nome)}</b>${c.grupo?'<small>Grupo</small>':''}<small>${esc(c.ultima_mensagem||'Histórico disponível para importar')}</small><small>${fmt(c.ultima_em)} · ${esc(c.status)}</small></span></button>`;}).join(''):'<div class="atd-vazio">Nenhuma conversa com estes filtros.</div>';
    // URLs temporárias de perfil; só revela o que pertence ao workspace.
    const targets=A.lista.filter(cv=>cv.avatar_path).slice(0,35);
    if(targets.length)api('avatars',{ids:targets.map(x=>x.id)},A.ws).then(({avatares})=>{
      if(!active(token)||sequence!==A.listSeq)return;
      for(const cv of targets){
        const url=avatares?.[cv.id];
        if(!url)continue;
        const el=[...$('#atdLista').querySelectorAll('[data-avatar-id]')].find(x=>x.dataset.avatarId===cv.id);
        if(!el)continue;
        const img=document.createElement('img');img.src=url;img.alt='';img.loading='lazy';
        img.onerror=()=>{img.remove();};
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
    if(!active(token)||generation!==A.chatToken) return;
    const ch=A.canais.find(c=>c.id===cv.canal_id)||{}, draft=A.drafts.get(draftKey(id))||'';
    $('#atdRoot').classList.add('selecionada');$('#atdRoot').classList.remove('ficha');
    $('#atdChat').innerHTML=`<header class="atd-top"><div><button class="btn sm atd-mobile" id="atdVoltar">← Conversas</button><strong>${esc(cv.nome)}</strong>${cv.grupo&&ch.provedor==='evolution'?` <button class="btn sm" id="atdArquivarGrupo">${cv.arquivada?'Desarquivar grupo':'Arquivar grupo'}</button>`:''}<div class="atd-identificacao">${faixaCanal(ch)}${cv.grupo?'<small>Grupo</small>':''}</div></div><div><select id="atdSituacao" aria-label="Situação da conversa" ${A.ctx.editar?'':'disabled'}>${['aberta','aguardando','resolvida'].map(s=>`<option value="${s}"${cv.status===s?' selected':''}>${s==='aberta'?'Aberta':s==='aguardando'?'Aguardando':'Resolvida'}</option>`).join('')}</select> <button class="btn sm atd-mobile" id="atdVerFicha">Ficha</button></div></header><div class="atd-msgs" id="atdMensagens"></div><form class="atd-compose" id="atdCompose"><div class="atd-dupla"><select id="atdModo" aria-label="Tipo de mensagem"><option value="enviar">Mensagem</option><option value="nota">Nota interna</option></select><button type="button" class="btn sm" id="atdHistorico">Importar histórico</button></div><textarea id="atdTexto" aria-label="Mensagem" maxlength="4000" placeholder="Escreva sua mensagem…" ${A.ctx.editar?'':'disabled'}>${esc(draft)}</textarea><div class="atd-arquivo" id="atdArquivoNome"></div><div class="atd-gravacao" id="atdGravacao" aria-live="polite"></div><footer><label class="btn sm">Anexar<input type="file" id="atdArquivo" class="atd-hidden" accept="image/jpeg,image/png,image/webp,video/mp4,audio/ogg,audio/mpeg,audio/mp4,audio/webm,audio/wav,application/pdf"></label><button type="button" class="btn sm" id="atdGravar" ${A.ctx.editar?'':'disabled'} aria-label="Gravar áudio pelo microfone">🎤 Gravar áudio</button><small class="muted">${A.ctx.nome?'Assinado por '+esc(A.ctx.nome):'Cadastre seu nome na equipe para enviar.'}</small><button class="btn pri" id="atdEnviar" ${A.ctx.editar?'':'disabled'}>Enviar</button></footer></form>`;
    $('#atdModo').insertAdjacentHTML('afterend','<button type="button" class="btn sm" id="atdRapidas">⚡ Respostas rápidas</button> <button type="button" class="btn sm" id="atdAgendar">🕒 Agendar envio</button> <button type="button" class="btn sm" id="atdVerAgendados">Agendamentos</button>');
    $('#atdAgendar').disabled=!A.ctx.editar;
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
    box.innerHTML=`${r.mensagens.length===60?'<button class="btn sm" id="atdAntigas">Mensagens anteriores</button>':''}`+timeline.map(x=>x.kind==='agenda'?`<article class="atd-agenda-chat atd-agenda-${esc(x.item.status)}"><header><b>◷ ${x.item.status==='agendado'?'AGENDADA · AINDA NÃO ENVIADA':x.item.status==='processando'?'ENVIO EM ANDAMENTO':x.item.status==='cancelado'?'AGENDAMENTO CANCELADO':x.item.status==='incerto'?'ENVIO SEM CONFIRMAÇÃO':'FALHA NO ENVIO'}</b><small>${new Date(x.item.enviar_em).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'})} · Brasília</small></header><p>${esc(x.item.texto)}</p>${x.item.erro?`<small class="atd-erro">${esc(x.item.erro)}</small>`:''}${x.item.status==='agendado'?`<button type="button" class="btn sm bad" data-cancelar-chat-agenda="${x.item.id}">Cancelar agendamento</button>`:''}</article>`:`<article class="atd-balao ${x.item.direcao}">${x.item.autor_nome?`<span class="atd-autor">${esc(x.item.autor_nome)}</span>`:x.item.participante?`<span class="atd-autor">${esc(x.item.participante)}</span>`:''}${textoMensagem(x.item)}${listOf(x.item.anexos).map((a,i)=>`<div class="atd-midia">${mediaMarkup(x.item,a,i)}</div>`).join('')}<small>${fmt(x.item.em)} · ${state[x.item.status]||esc(x.item.status)}</small>${x.item.erro?`<span class="atd-erro">${esc(x.item.erro)}</span>`:''}</article>`).join('');
    if(!timeline.length)box.innerHTML='<div class="atd-vazio">Nenhuma mensagem salva ainda.<br>Use “Importar histórico” para consultar o canal.</div>';
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
    $('#atdCanaisCorpo').innerHTML=`<div class="panel"><p>WhatsApp oficial e Instagram pela Zernio. WhatsApp e grupos pela Evolution 2.3.7.</p>${ctx.admin?'<div class="acts"><button class="btn" id="atdConfigEvo">Configurar Evolution</button><button class="btn pri" id="atdNovaInst">Nova instância WhatsApp</button><button class="btn pri" id="atdInstagramConectar">Conectar Instagram</button><button class="btn" id="atdWhatsappConectar">Conectar WhatsApp API oficial</button><button class="btn" id="atdZernio">Adicionar canal já conectado</button></div>':'<p>Um administrador gerencia as conexões.</p>'}</div><div class="atd-canais">${canais.map(c=>`<article class="atd-canal"><h3>${esc(c.nome)}</h3><div class="atd-identificacao">${faixaCanal(c)}</div>${c.provedor==='evolution'&&c.canal==='whatsapp'?`<label class="atd-arquivados"><input type="checkbox" data-arquivados="${c.id}" ${c.exibir_grupos_arquivados?'checked':''} ${ctx.admin?'':'disabled'}> Exibir grupos arquivados</label><small>Arquivados no Growth V2 (não altera o WhatsApp).</small>`:''}<span class="pill ${c.status==='conectado'?'good':'warn'}">${esc(c.status)}</span><p class="muted">${esc(c.numero||c.externo_id)}</p><div class="acts">${ctx.admin&&c.provedor==='evolution'&&c.ativo?`<button class="btn sm" data-ca="conectar" data-id="${c.id}">QR Code</button><button class="btn sm" data-ca="status" data-id="${c.id}">Verificar status</button><button class="btn sm bad" data-ca="excluir-instancia" data-id="${c.id}">Excluir instância</button>`:''}${ctx.admin&&c.ativo?`<button class="btn sm" data-ca="webhook" data-id="${c.id}">Ativar recebimento</button>`:''}${ctx.editar&&c.ativo?`<button class="btn sm" data-ca="sincronizar" data-id="${c.id}">${c.provedor==='evolution'?'Buscar conversas e grupos':'Buscar conversas'}</button>`:''}</div><div id="ca-${c.id}"></div></article>`).join('')||'<div class="panel">Nenhum canal adicionado.</div>'}</div>`;
    $('#atdConfigEvo')?.addEventListener('click',()=>act(configurarEvolution));
    $('#atdInstagramConectar')?.addEventListener('click',()=>conectarInstagram(ws));
    $('#atdWhatsappConectar')?.addEventListener('click',()=>conectarSocialZernio('whatsapp',ws));
    $('#atdNovaInst')?.addEventListener('click',()=>modal('Nova instância WhatsApp','<label>Nome deste número<input name="nome" required placeholder="Comercial · Número principal" maxlength="100"></label>',async d=>{await api('criar-instancia',d,ws);toast('Instância criada. Abra QR Code para conectar.');}));
    $('#atdZernio')?.addEventListener('click',()=>act(async()=>{const r=await api('zernio-contas',{},ws);if(!r.contas.length){toast('Nenhum canal vinculado. Clique em Conectar Instagram ou solicite a configuração do WhatsApp oficial.',true);return;}modal('Adicionar conta da Zernio',`<label>Conta<select name="account_id">${r.contas.map(c=>`<option value="${esc(c.id)}">${esc(label(c.canal)+' · '+c.nome)}</option>`).join('')}</select></label><p>Somente contas do perfil já conectado a este workspace.</p>`,async d=>{await api('zernio-vincular',d,ws);toast('Conta adicionada. Ative o recebimento e busque as conversas.');});}));
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
        else if(action==='sincronizar'){btn.dataset.cursor=r.cursor||'';btn.textContent=r.cursor?'Buscar próximos grupos':'Atualizar conversas';const groupInfo=canais.find(c=>c.id===id)?.provedor==='evolution';target.textContent=groupInfo?`${r.grupos_consultados||0} grupos verificados · ${r.nomes_atualizados||0} nomes recuperados · ${r.fotos_salvas||0} fotos salvas · ${r.grupos_sem_nome??'?'} ainda sem nome. ${(r.avisos||[]).join(' | ')}${r.cursor?' Clique novamente para consultar mais grupos.':''}`:r.total+' conversas consultadas.';}
        else if(action==='status'){target.textContent='Status: '+r.status;if(r.status==='conectado')target.querySelector('img')?.remove();}
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
      const meta=async()=>{
        if(!canalId){$('#tplConteudo').innerHTML='<p>Conecte um WhatsApp oficial pela Zernio em Canais e conexões para gerenciar templates aprovados pela Meta. Instâncias Evolution não têm aprovação de templates.</p>';return;}
        $('#tplConteudo').innerHTML=`<h3>Modelos oficiais do WhatsApp</h3><label>Conta WhatsApp<select id="tplCanal">${canalOptions}</select></label><p class="muted">A Meta analisa os modelos. Apenas os aprovados podem ser enviados pela API oficial.</p><button class="btn sm" id="tplAtualizar">Atualizar status na Meta</button><div id="tplLista">Consultando…</div>${ctx.admin?'<button class="btn pri" id="tplNovo">Enviar novo modelo para aprovação</button>':''}`;
        $('#tplCanal').value=canalId;
        $('#tplCanal').onchange=e=>{canalId=e.target.value;act(meta);};
        $('#tplAtualizar').onclick=()=>act(meta);
        try{
          const result=await api('templates-list',{canal_id:canalId},ws);
          if(S.ws!==ws||S.view!=='atd-templates'||aba!=='meta')return;
          templates=result.templates||[];
          $('#tplLista').innerHTML=templates.length?templates.map((t,i)=>`<article class="panel" style="margin:12px 0"><b>${esc(t.name)}</b> · ${esc(t.language)} <span class="pill ${t.status==='APPROVED'?'good':'warn'}">${esc(t.status)}</span><p>${esc(t.category||'')}</p><p style="white-space:pre-wrap">${esc((t.components||[]).find(c=>String(c.type).toUpperCase()==='BODY')?.text||'')}</p>${t.reason&&t.reason!=='NONE'?`<small>${esc(t.reason)}</small>`:''}${ctx.admin?`<div class="acts"><button class="btn sm" data-tpl-edit="${i}">Editar e reenviar</button><button class="btn sm bad" data-tpl-delete="${i}">Excluir na Meta</button></div>`:''}</article>`).join(''):'<p>Nenhum template encontrado para esta conta.</p>';
        }catch(err){$('#tplLista').textContent=err.message;}
        $('#tplNovo')?.addEventListener('click',()=>editor());
        $('#tplLista').onclick=e=>{
          const edit=e.target.closest('[data-tpl-edit]'),del=e.target.closest('[data-tpl-delete]');
          if(edit){editor(templates[Number(edit.dataset.tplEdit)]);return;}
          if(del)act(async()=>{
            const t=templates[Number(del.dataset.tplDelete)];if(!t?.id||!confirm(`Excluir o modelo ${t.name} (${t.language}) da Meta? Essa ação pode impedir envios que o utilizem.`))return;
            await api('templates-delete',{canal_id:canalId,template_id:t.id},ws);toast('Exclusão solicitada na Meta.');await meta();
          });
        };
      };
      const editor=t=>{
        const body=(t?.components||[]).find(c=>String(c.type).toUpperCase()==='BODY');
        const sample=body?.example?.body_text?.[0]||[];
        const content=`<p>Nome em minúsculas, sem espaços. Use {{1}}, {{2}} para variáveis e informe exemplos reais de formato, mas sem dados pessoais.</p><label>Nome<input name="nome" required pattern="[a-z][a-z0-9_]*" value="${esc(t?.name||'')}"></label><label>Categoria<select name="categoria"><option value="UTILITY">Utilidade</option><option value="MARKETING">Marketing</option></select></label><label>Idioma<input name="idioma" required value="${esc(t?.language||'pt_BR')}"></label><label>Mensagem<textarea name="texto" required maxlength="1024" rows="6">${esc(body?.text||'')}</textarea></label><label>Exemplos das variáveis (um por linha, na ordem)<textarea name="exemplos" rows="3" placeholder="Exemplo da variável 1&#10;Exemplo da variável 2">${esc(sample.join('\n'))}</textarea></label><p class="muted">Editar um template existente o submete novamente à análise da Meta.</p>`;
        const form=modal(t?'Editar modelo Meta':'Novo modelo Meta',content,async d=>{
          const action=t?'templates-update':'templates-create';
          await api(action,{canal_id:canalId,template_id:t?.id,nome:d.nome,categoria:d.categoria,idioma:d.idioma,texto:d.texto,exemplos:String(d.exemplos||'').split('\n').map(x=>x.trim()).filter(Boolean)},ws);
          toast('Modelo enviado à Meta. Acompanhe o status nesta aba.');await meta();
        },t?'Salvar e reenviar':'Enviar para aprovação');
        if(t)form.querySelector('[name=categoria]').value=t.category||'UTILITY';
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
  NAV.splice(NAV.findIndex(g=>g.g==='Vendas')+1,0,{g:'Atendimento',items:[['atd-conversas','Conversas'],['atd-canais','Canais e conexões'],['atd-templates','Templates']]});
  MOD_GRUPO.Atendimento='vendas';
  ICO.Atendimento=ICO['crm-dms']||ICO.Vendas||'';ICO['atd-conversas']=ICO['crm-dms']||'';ICO['atd-canais']=ICO['cfg-integracoes'];ICO['atd-templates']=ICO['crm-dms']||'';
  VIEWS['atd-conversas']=vAtendimento;VIEWS['atd-canais']=vCanais;VIEWS['atd-templates']=vTemplates;
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
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&S.view==='atd-conversas')refreshCurrent(A.token);});
})();
