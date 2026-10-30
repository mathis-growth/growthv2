import fs from 'node:fs';import http from 'node:http';import assert from 'node:assert/strict';import {createRequire} from 'node:module';
const require=createRequire(new URL('../../.dev-tools/package.json',import.meta.url));const {chromium}=require('playwright');
const root=new URL('../../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8');
const ws='w1',user='u1';
const seed={workspaces:[{id:ws,nome:'Mathisa',modo_produto:'completo',agencia:true}],atd_canais:[
 {id:'c1',workspace_id:ws,provedor:'evolution',canal:'whatsapp',nome:'Comercial · Principal',externo_id:'inst1',status:'conectado',ativo:true},
 {id:'c2',workspace_id:ws,provedor:'zernio',canal:'instagram',nome:'@mathisa',externo_id:'ig1',status:'conectado',ativo:true}],
 atd_conversas:[{id:'cv1',workspace_id:ws,canal_id:'c1',externo_id:'5511999999999@s.whatsapp.net',endereco:'5511999999999@s.whatsapp.net',nome:'Mariana Costa',pessoa_id:'p1',status:'aberta',nao_lidas:2,ultima_em:'2026-10-29T17:01:00Z',ultima_mensagem:'Podemos conversar sobre a consultoria?',grupo:false},
 {id:'cv2',workspace_id:ws,canal_id:'c1',externo_id:'group@g.us',nome:'Clientes · Turma Outubro',status:'aguardando',nao_lidas:0,grupo:true},
 {id:'cv3',workspace_id:ws,canal_id:'c2',externo_id:'igcv1',nome:'Ana Ribeiro',status:'aberta',nao_lidas:1,grupo:false}],
 atd_mensagens:[{id:'m1',workspace_id:ws,conversa_id:'cv1',direcao:'recebida',texto:'Olá! Gostaria de entender como funciona a consultoria.',autor_nome:'Mariana',em:'2026-10-29T17:00:00Z',status:'recebida',anexos:[]},
 {id:'m2',workspace_id:ws,conversa_id:'cv1',direcao:'enviada',texto:'*Roger:* Olá, Mariana! Claro, vamos conversar sobre o seu negócio.',autor_nome:'Roger',em:'2026-10-29T17:01:00Z',status:'lida',anexos:[]},
 {id:'m3',workspace_id:ws,conversa_id:'cv2',direcao:'recebida',texto:'Bom dia, pessoal!',autor_nome:'Pedro',participante:'5511888888888@s.whatsapp.net',em:'2026-10-29T17:00:00Z',status:'recebida',anexos:[]}],
 equipe:[{id:'e1',workspace_id:ws,user_id:user,nome:'Roger',ativo:true}],pessoas:[{id:'p1',workspace_id:ws,nome:'Mariana Costa',telefone:'5511999999999',email:'mariana@example.com',status_funil:'lead',qualificacao:'qualificado'}],
 pessoa_notas:[{workspace_id:ws,pessoa_id:'p1',texto:'Interessada em ampliar a operação.',criado_em:'2026-10-29'}],vendas:[],oportunidades:[{workspace_id:ws,pessoa_id:'p1',titulo:'Consultoria de crescimento',status:'aberta'}]};
let html=read('index.html');const start=html.indexOf('<script>/* @supabase'),end=html.indexOf('</script>',start)+9;
html=html.slice(0,start)+'<script>window.__SEED='+JSON.stringify(seed)+'</script><script>'+read('tests/tela/mockdb.js')+'</script>'+html.slice(end);
html=html.replace("else sb.auth.getSession().then(({ data }) => { S.user = data.session ? data.session.user : null; boot(); });","else window.__bootDisabled=true;");
const server=http.createServer((req,res)=>{const path=req.url.split('?')[0];if(path==='/'){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(html);}else if(['/assets/atendimento.js','/assets/atendimento.css'].includes(path)){res.setHeader('Content-Type',path.endsWith('.js')?'application/javascript':'text/css');res.end(read(path.slice(1)));}else{res.statusCode=404;res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const port=server.address().port;
const browser=await chromium.launch({channel:'msedge',headless:true});const page=await browser.newPage({viewport:{width:1600,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
try{
await page.goto('http://127.0.0.1:'+port);await page.evaluate(()=>{
 window.__api=[];window.__edit=true;
 sb.functions={invoke:async(_,{body:b})=>{window.__api.push(b);const D=window.__D,cv=D.atd_conversas.find(c=>c.id===b.conversa_id);let data={ok:true};
  if(b.action==='contexto')data={user_id:'u1',nome:'Roger',editar:window.__edit,admin:true};
  if(b.action==='mensagens')data={mensagens:D.atd_mensagens.filter(m=>m.conversa_id===b.conversa_id)};
  if(b.action==='enviar'||b.action==='nota')D.atd_mensagens.push({id:crypto.randomUUID(),conversa_id:b.conversa_id,texto:b.action==='enviar'?'*Roger:* '+b.texto:b.texto,autor_nome:'Roger',direcao:b.action==='nota'?'nota':'enviada',status:b.action==='nota'?'nota':'enviada',em:new Date().toISOString(),anexos:[]});
  if(b.action==='atualizar'&&cv){if(b.status)cv.status=b.status;if(b.lida)cv.nao_lidas=0;}
  if(b.action==='config')data={url:'https://evo.example.com',configurada:true};
  if(b.action==='conectar')data={qrcode:'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jC2kAAAAASUVORK5CYII='};
  if(b.action==='status')data={status:'conectado'};
  if(b.action==='historico')data={total:0,cursor:null};
  return {data,error:null};}};
 S.ws=S.wsBase='w1';S.user={id:'u1',email:'roger@example.com'};S.workspaces=window.__D.workspaces;S.view='atd-conversas';S.perm=null;S.acesso=null;S.abertos.Atendimento=true;S.interno=true;
 $('#login').classList.add('hide');$('#app').classList.remove('hide');
 render=async()=>{desenhaNav();return VIEWS[S.view]($('#main'));};
 return render();
});
await page.locator('[data-conversa=cv1]').click();await page.locator('#atdFichaCompleta').waitFor();
assert.match(await page.locator('#atdFicha').innerText(),/Mariana Costa/);assert.match(await page.locator('#atdMensagens').innerText(),/Roger/);
await page.locator('#atdTexto').fill('Obrigado pelo contato!');await page.locator('#atdEnviar').click();await page.waitForFunction(()=>document.querySelector('#atdMensagens').textContent.includes('Obrigado pelo contato!'));
assert.equal(await page.evaluate(()=>__api.filter(x=>x.action==='enviar').length),1);
await page.locator('#atdModo').selectOption('nota');await page.locator('#atdTexto').fill('Agendar conversa com a equipe.');await page.locator('#atdEnviar').click();await page.locator('.atd-balao.nota').waitFor();
await page.locator('#atdTexto').fill('Rascunho preservado');await page.locator('[data-conversa=cv2]').click();await page.waitForFunction(()=>document.querySelector('#atdFicha').textContent.includes('Grupo de WhatsApp'));
assert.match(await page.locator('#atdMensagens').innerText(),/Pedro/);assert.equal(await page.locator('#atdVincular').count(),0);
await page.locator('[data-conversa=cv1]').click();await page.waitForFunction(()=>document.querySelector('#atdTexto').value==='Rascunho preservado');
await page.locator('#atdFiltroCanal').selectOption('c2');await page.waitForFunction(()=>document.querySelectorAll('[data-conversa]').length===1);
assert.equal(await page.locator('[data-conversa=cv3]').count(),1);
await page.locator('#atdFiltroCanal').selectOption('');await page.locator('[data-conversa=cv1]').waitFor();
await page.screenshot({path:new URL('../../.dev-tools/atendimento-desktop.png',import.meta.url).pathname.replace(/^\/(\w:)/,'$1'),fullPage:true});
await page.setViewportSize({width:390,height:844});await page.locator('#atdVerFicha').click();assert.equal(await page.locator('#atdFicha').isVisible(),true);await page.locator('#atdFichaVoltar').click();assert.equal(await page.locator('#atdChat').isVisible(),true);
await page.screenshot({path:new URL('../../.dev-tools/atendimento-mobile.png',import.meta.url).pathname.replace(/^\/(\w:)/,'$1'),fullPage:true});
await page.setViewportSize({width:1600,height:1000});await page.locator('#atdCanais').click();await page.locator('#atdConfigEvo').click();await page.locator('[name=key]').waitFor();assert.equal(await page.locator('[name=key]').inputValue(),'');assert.equal(await page.locator('[name=key]').getAttribute('type'),'password');await page.locator('[data-x]').click();
await page.locator('[data-ca=conectar]').click();await page.locator('.atd-qr').waitFor();
await page.locator('#atdInbox').click();await page.locator('[data-conversa=cv1]').click();await page.locator('#atdTexto').waitFor();
await page.evaluate(async()=>{window.__edit=false;await render();});await page.locator('[data-conversa=cv1]').click();await page.locator('#atdTexto').waitFor();assert.equal(await page.locator('#atdEnviar').isDisabled(),true);
await page.evaluate(async()=>{__D.atd_canais.push({id:'c9',workspace_id:'w2',provedor:'evolution',canal:'whatsapp',nome:'Outro workspace',externo_id:'inst9',status:'conectado'});S.ws='w2';S.view='atd-canais';await render();});
await page.locator('[data-id=c9][data-ca=status]').click();await page.waitForFunction(()=>__api.some(x=>x.canal_id==='c9'));
assert.equal(await page.evaluate(()=>__api.filter(x=>x.canal_id==='c9').every(x=>x.workspace_id==='w2')),true);
assert.deepEqual(errors,[]);console.log('Tela: navegação, pessoa, grupos, assinatura, notas, rascunho, filtros, mobile, QR, chave oculta e troca de workspace OK.');
}finally{await browser.close();await new Promise(r=>server.close(r));}
