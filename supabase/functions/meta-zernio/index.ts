// v0.182 — Meta Ads OAuth via conta Zernio central. Um Secret: ZERNIO_API_KEY.
// Não solicita META_APP_ID, META_APP_SECRET nem token do cliente.
// Protege clientes por workspace, profileId e allowlist explícita de contas act_*.
import {createClient} from 'npm:@supabase/supabase-js@2.45.4';
const URL_SB=Deno.env.get('SUPABASE_URL')!;
const db=createClient(URL_SB,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,GET,OPTIONS'};
const json=(x:unknown,status=200)=>new Response(JSON.stringify(x),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const q=async(t:any):Promise<any>=>{const {data,error}=await t;if(error)throw Error(error.message);return data};
const key=()=>{const v=Deno.env.get('ZERNIO_API_KEY');if(!v)throw Error('Secret ZERNIO_API_KEY não configurado.');return v};
async function api(path:string):Promise<any>{
  const r=await fetch('https://zernio.com/api/v1'+path,{headers:{Authorization:'Bearer '+key()},redirect:'error',signal:AbortSignal.timeout(20000)});
  const j=await r.json().catch(()=>({}));
  if(!r.ok)throw Error('A Zernio recusou a operação (HTTP '+r.status+').');
  return j;
}
const objId=(a:any)=>String(a?._id||a?.id||a?.accountId||'');
const profileOf=(a:any)=>String(typeof a?.profileId==='object'?(a.profileId._id||a.profileId.id||''):(a?.profileId||''));
const isId=(s:string)=>/^[0-9a-f]{24}$/i.test(s);
const isUuid=(s:string)=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
async function accounts(profileId:string){
  const a=await api('/accounts?profileId='+encodeURIComponent(profileId));
  if(!Array.isArray(a.accounts))throw Error('A Zernio retornou uma lista de contas inválida.');
  return a.accounts;
}
async function profile(ws:string,uid:string){
  const connection=await q(db.from('conexoes').select('id,zernio_profile_id,status,conta_nome,conectado_por').eq('workspace_id',ws).eq('plataforma','zernio').maybeSingle());
  if(connection?.zernio_profile_id)return String(connection.zernio_profile_id);
  const links=await q(db.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)').eq('workspace_id',ws).eq('conexoes.plataforma','zernio'));
  let id='';
  if(links.length){
    const a=await api('/accounts');
    const ids=new Set(links.map((k:any)=>k.id_externo));
    const profiles=new Set((a.accounts||[]).filter((x:any)=>ids.has(objId(x))).map(profileOf).filter(Boolean));
    if(profiles.size===1)id=Array.from(profiles)[0] as string;
  }
  if(!id){
    const w=await q(db.from('workspaces').select('nome').eq('id',ws).single());
    const r=await fetch('https://zernio.com/api/v1/profiles',{method:'POST',headers:{Authorization:'Bearer '+key(),'Content-Type':'application/json'},body:JSON.stringify({name:String(w.nome||'Cliente Growths').slice(0,100)}),redirect:'error',signal:AbortSignal.timeout(20000)});
    const data=await r.json().catch(()=>({}));
    if(!r.ok)throw Error('Não foi possível criar o perfil Zernio (HTTP '+r.status+').');
    id=String(data.profile?._id||data.profile?.id||'');
  }
  if(!isId(id))throw Error('Perfil Zernio inválido.');
  await q(db.from('conexoes').upsert({workspace_id:ws,plataforma:'zernio',zernio_profile_id:id,
    status:connection?.status||'desconectado',conta_nome:connection?.conta_nome||'Zernio',
    conectado_por:connection?.conectado_por||uid},{onConflict:'workspace_id,plataforma'}));
  return id;
}
async function requireSession(req:Request){
  const auth=req.headers.get('authorization')||'';
  const userDb=createClient(URL_SB,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}},auth:{persistSession:false}});
  const {data:{user},error}=await userDb.auth.getUser();
  if(error||!user)throw Error('Faça login novamente.');
  return {userDb,uid:user.id};
}
async function permitted(userDb:any,ws:string){
  return Boolean(await q(userDb.rpc('zernio_oauth_permitido',{p_ws:ws})));
}
async function connection(ws:string){
  return await q(db.from('conexoes').select('id,zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').single());
}
async function metaLink(ws:string){
  const conn=await connection(ws);
  const links=await q(db.from('conexao_contas').select('id,id_externo,nome,sincronizar,extras')
    .eq('workspace_id',ws).eq('conexao_id',conn.id).eq('tipo','meta_ads'));
  return {conn,links};
}
async function post(req:Request){
  const {userDb,uid}=await requireSession(req);
  const b=await req.json().catch(()=>({}));
  const ws=String(b.workspace_id||'');
  if(!isUuid(ws))return json({erro:'Cliente inválido.'},400);
  if(!await permitted(userDb,ws))return json({erro:'Somente administradores podem gerenciar a Meta deste cliente.'},403);
  const action=String(b.action||'iniciar');
  if(action==='iniciar'){
    const nonce=await q(userDb.rpc('zernio_meta_oauth_iniciar',{p_ws:ws}));
    const pid=await profile(ws,uid);
    const cb=new URL(URL_SB+'/functions/v1/meta-zernio');
    cb.searchParams.set('state',nonce);
    const query=new URLSearchParams({profileId:pid,loginMode:'business',redirect_url:cb.toString()});
    const result=await api('/connect/facebook/ads?'+query);
    const url=new URL(String(result.authUrl||''));
    if(url.protocol!=='https:'||!['facebook.com','www.facebook.com'].includes(url.hostname))
      return json({erro:'URL do login Meta inválida.'},502);
    return json({authUrl:url.toString()});
  }
  const {conn,links}=await metaLink(ws);
  if(action==='contas'){
    const out=[];
    for(const link of links){
      if(link.extras?.growths_desconectado_em)continue;
      const r=await api('/ads/accounts?accountId='+encodeURIComponent(link.id_externo));
      for(const a of r.accounts||[]){
        if(!/^act_\d+$/.test(String(a.id)))continue;
        out.push({id:a.id,nome:String(a.name||a.id).slice(0,120),zernioId:link.id_externo,
          selecionada:(link.extras?.adAccountIds||[]).includes(a.id)});
      }
    }
    return json({contas:out});
  }
  if(action==='selecionar'){
    const accountId=String(b.zernio_account_id||'');
    const selection=Array.isArray(b.ad_account_ids)?b.ad_account_ids.map(String):[];
    const link=links.find((x:any)=>x.id_externo===accountId&&!x.extras?.growths_desconectado_em);
    if(!link)return json({erro:'Conexão Meta não pertence a este cliente.'},403);
    if(!selection.length||selection.length>30||selection.some((x:string)=>!/^act_\d+$/.test(x)))
      return json({erro:'Selecione contas de anúncios válidas.'},400);
    const r=await api('/ads/accounts?accountId='+encodeURIComponent(accountId));
    const allowed=new Set((r.accounts||[]).map((a:any)=>a.id));
    if(selection.some((x:string)=>!allowed.has(x)))return json({erro:'Conta não autorizada pela Meta.'},403);
    await q(db.from('conexao_contas').update({sincronizar:true,extras:{...(link.extras||{}),adAccountIds:selection}})
      .eq('id',link.id).eq('workspace_id',ws));
    return json({ok:true,quantidade:selection.length});
  }
  if(action==='desconectar'){
    const id=String(b.zernio_account_id||'');
    const link=links.find((x:any)=>x.id_externo===id);
    if(!link)return json({erro:'Conexão não encontrada neste cliente.'},404);
    await q(db.from('conexao_contas').update({sincronizar:false,extras:{...(link.extras||{}),adAccountIds:[],growths_desconectado_em:new Date().toISOString()}})
      .eq('id',link.id).eq('workspace_id',ws));
    return json({ok:true,desconexao:'somente Growth V2',observacao:'A permissão da Meta continua na Zernio até ser revogada na plataforma.'});
  }
  return json({erro:'Operação inválida.'},400);
}
function reply(ok:boolean,message:string){
  const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]||c));
  const text=escape(message);
  return new Response('<!doctype html><meta charset="utf-8"><title>Conexão Meta</title><body style="font:16px system-ui;padding:15vh 24px;text-align:center"><h2>'+(ok?'Meta autorizada':'Não foi possível autorizar a Meta')+'</h2><p>'+text+'</p><p>Volte ao Growth V2. Você pode fechar esta janela.</p>'+(ok?'<script>window.close()<\/script>':'')+'</body>',{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'"}});
}
async function callback(url:URL){
  const state=url.searchParams.get('state')||'';
  if(!/^[a-f0-9]{64}$/i.test(state))return reply(false,'Estado de autorização inválido.');
  const saved=await q(db.rpc('conexao_estado_usar',{p_nonce:state}));
  if(!saved||saved.plataforma!=='zernio'||saved.volta!=='metaads-oauth')return reply(false,'Autorização expirada ou já utilizada.');
  if(url.searchParams.has('error'))return reply(false,'A autorização foi cancelada na Meta.');
  const ws=String(saved.ws||'');
  const pid=String(url.searchParams.get('profileId')||'');
  const accountId=String(url.searchParams.get('accountId')||'');
  if(url.searchParams.get('connected')!=='metaads'||!isId(pid)||!isId(accountId))
    return reply(false,'A Meta não retornou uma conexão válida.');
  try{
    const conn=await connection(ws);
    if(conn.zernio_profile_id!==pid)throw Error('O perfil Meta não pertence ao cliente selecionado.');
    const remote=(await accounts(pid)).find((a:any)=>objId(a)===accountId&&a.platform==='metaads'&&profileOf(a)===pid);
    if(!remote)throw Error('A Zernio não confirmou essa conta Meta Ads.');
    const previous=await q(db.from('conexao_contas').select('workspace_id,conexoes!inner(plataforma)')
      .eq('id_externo',accountId).eq('conexoes.plataforma','zernio'));
    if(previous.some((x:any)=>x.workspace_id!==ws))throw Error('Conta Meta já associada a outro cliente.');
    const name=String(remote.displayName||remote.username||'Meta Ads').slice(0,120);
    const old=await q(db.from('conexao_contas').select('extras').eq('conexao_id',conn.id).eq('tipo','meta_ads').eq('id_externo',accountId).maybeSingle());
    const extras={...(old?.extras||{}),adAccountIds:[]};delete extras.growths_desconectado_em;
    await q(db.from('conexao_contas').upsert({workspace_id:ws,conexao_id:conn.id,tipo:'meta_ads',id_externo:accountId,nome:name,sincronizar:false,extras},{onConflict:'conexao_id,tipo,id_externo'}));
    await q(db.from('conexoes').update({status:'conectado',conectado_em:new Date().toISOString()}).eq('id',conn.id));
    return reply(true,'Autorizada. Escolha as contas de anúncios que pertencem a este cliente no Growth V2.');
  }catch(e){return reply(false,(e as Error).message);}
}
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  try{
    if(req.method==='POST')return await post(req);
    if(req.method==='GET')return await callback(new URL(req.url));
    return json({erro:'Método não permitido.'},405);
  }catch(e){return json({erro:(e as Error).message},500);}
});
