// v0.185 — OAuth Zernio compartilhado por workspace para YouTube, LinkedIn,
// TikTok, Facebook Page e WhatsApp Cloud API. Nenhum Meta App Secret no cliente.
import {createClient} from 'npm:@supabase/supabase-js@2.45.4';
const BASE=Deno.env.get('SUPABASE_URL')!;
const svc=createClient(BASE,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
const CORS={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,GET,OPTIONS'};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...CORS,'Content-Type':'application/json','Cache-Control':'no-store'}});
const q=async(p:any):Promise<any>=>{const {data,error}=await p;if(error)throw new Error(error.message);return data};
const platforms:Record<string,{tipo:string}>={
  youtube:{tipo:'youtube'},linkedin:{tipo:'linkedin'},tiktok:{tipo:'tiktok'},
  facebook:{tipo:'facebook_pagina'},whatsapp:{tipo:'whatsapp'}
};
const oid=(x:any)=>String(x?._id||x?.id||x?.accountId||'');
const pidOf=(x:any)=>String(typeof x?.profileId==='object'?(x.profileId?._id||x.profileId?.id||''):(x?.profileId||''));
const validOid=(s:string)=>/^[a-f0-9]{24}$/i.test(s);
const validUuid=(s:string)=>/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(s);
function key(){const k=Deno.env.get('ZERNIO_API_KEY');if(!k)throw Error('ZERNIO_API_KEY não configurada.');return k}
async function zapi(path:string,method='GET',payload?:unknown){
  const r=await fetch('https://zernio.com/api/v1'+path,{
    method,redirect:'error',signal:AbortSignal.timeout(20000),
    headers:{Authorization:'Bearer '+key(),'Content-Type':'application/json'},
    body:payload===undefined?undefined:JSON.stringify(payload)
  });
  const j=await r.json().catch(()=>({}));
  if(!r.ok){
    // Não retornar URL/tokens ou corpos arbitrários do provedor.
    const reason=String(j.reason||j.code||'').replace(/[^a-zA-Z0-9_-]/g,'').slice(0,60);
    throw Error('Zernio respondeu HTTP '+r.status+(reason?' ('+reason+')':'')+'.');
  }
  return j;
}
async function accounts(profileId?:string){
  const r=await zapi('/accounts'+(profileId?'?profileId='+encodeURIComponent(profileId):''));
  if(!Array.isArray(r.accounts))throw Error('A Zernio não retornou uma lista válida de contas.');
  return r.accounts as any[];
}
async function profile(ws:string,uid:string){
  const existing=await q(svc.from('conexoes').select('id,zernio_profile_id,conta_nome,status,conectado_por')
    .eq('workspace_id',ws).eq('plataforma','zernio').maybeSingle());
  if(existing?.zernio_profile_id && validOid(existing.zernio_profile_id))return existing.zernio_profile_id;
  const linked=await q(svc.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)')
    .eq('workspace_id',ws).eq('conexoes.plataforma','zernio'));
  let id='';
  if(linked.length){
    const all=await accounts();
    const ids=new Set(linked.map((x:any)=>x.id_externo));
    const found=new Set(all.filter(x=>ids.has(oid(x))).map(pidOf).filter(Boolean));
    if(found.size===1)id=[...found][0] as string;
  }
  if(!id){
    const w=await q(svc.from('workspaces').select('nome').eq('id',ws).single());
    const r=await zapi('/profiles','POST',{name:String(w.nome||'Growth V2').slice(0,100)});
    id=String(r.profile?._id||r.profile?.id||'');
  }
  if(!validOid(id))throw Error('Não foi possível obter um perfil Zernio válido.');
  await q(svc.from('conexoes').upsert({workspace_id:ws,plataforma:'zernio',
    zernio_profile_id:id,conta_nome:existing?.conta_nome||'Zernio',
    status:existing?.status||'desconectado',conectado_por:existing?.conectado_por||uid
  },{onConflict:'workspace_id,plataforma'}));
  return id;
}
function page(ok:boolean,msg:string){
  const enc:Record<string,string>={'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'};
  const safe=msg.replace(/[&<>"']/g,c=>enc[c]||c);
  return new Response('<!doctype html><meta charset="utf-8"><title>Integração Zernio</title><body style="font:16px system-ui;text-align:center;padding:12vh 20px"><h2>'+(ok?'Conta conectada':'Conexão não concluída')+'</h2><p>'+safe+'</p><p>Volte ao Growth V2; você pode fechar esta janela.</p>'+(ok?'<script>window.close()<\\/script>':'')+'</body>',{
    headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer',
    'X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'"}});
}
async function start(req:Request){
  const authorization=req.headers.get('authorization')||'';
  const db=createClient(BASE,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false},global:{headers:{Authorization:authorization}}});
  const {data:{user},error}=await db.auth.getUser();
  if(error||!user)return json({erro:'Faça login novamente.'},401);
  const b=await req.json().catch(()=>({}));
  const ws=String(b.workspace_id||''),platform=String(b.platform||'');
  if(!validUuid(ws)||!platforms[platform])return json({erro:'Cliente ou integração inválidos.'},400);
  if(!await q(db.rpc('zernio_oauth_permitido',{p_ws:ws})))return json({erro:'Sem permissão para autorizar este cliente.'},403);
  const nonce=await q(db.rpc('zernio_social_oauth_iniciar',{p_ws:ws,p_platform:platform}));
  const profileId=await profile(ws,user.id);
  const redirect=new URL(BASE+'/functions/v1/zernio-social-oauth');
  redirect.searchParams.set('state',nonce);
  const params=new URLSearchParams({profileId,redirect_url:redirect.toString()});
  if(platform==='whatsapp')params.set('onboarding','api');
  const j=await zapi('/connect/'+platform+'?'+params);
  const auth=new URL(String(j.authUrl||''));
  if(auth.protocol!=='https:'||!['instagram.com','www.instagram.com','facebook.com','www.facebook.com','accounts.google.com','www.linkedin.com','linkedin.com','www.tiktok.com','tiktok.com','zernio.com','www.zernio.com'].includes(auth.hostname))
    return json({erro:'URL de autorização inesperada. Não foi aberta.'},502);
  return json({authUrl:auth.toString()});
}
async function callback(url:URL){
  const state=url.searchParams.get('state')||'';
  if(!/^[a-f0-9]{64}$/i.test(state))return page(false,'Estado de autorização inválido.');
  const saved=await q(svc.rpc('conexao_estado_usar',{p_nonce:state}));
  if(!saved||saved.plataforma!=='zernio'||!String(saved.volta||'').startsWith('zernio-social:'))
    return page(false,'Autorização inválida ou já utilizada.');
  const platform=String(saved.volta).slice('zernio-social:'.length);
  if(!platforms[platform])return page(false,'Plataforma inesperada.');
  if(url.searchParams.has('error'))return page(false,'A plataforma não autorizou a integração.');
  const ws=String(saved.ws||''),pid=String(url.searchParams.get('profileId')||'');
  const accountId=String(url.searchParams.get('accountId')||'');
  if(url.searchParams.get('connected')!==platform||!validOid(pid)||!validOid(accountId))
    return page(false,'A Zernio não confirmou a conexão.');
  try{
    const c=await q(svc.from('conexoes').select('id,zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').single());
    if(c.zernio_profile_id!==pid)throw Error('Perfil não pertence a este cliente.');
    const account=(await accounts(pid)).find(x=>oid(x)===accountId&&pidOf(x)===pid&&x.platform===platform);
    if(!account)throw Error('Conta autorizada não encontrada na Zernio.');
    const [links,channels]=await Promise.all([
      q(svc.from('conexao_contas').select('workspace_id,conexoes!inner(plataforma)').eq('id_externo',accountId).eq('conexoes.plataforma','zernio')),
      q(svc.from('atd_canais').select('workspace_id').eq('provedor','zernio').eq('externo_id',accountId))
    ]);
    if([...links,...channels].some((x:any)=>x.workspace_id!==ws))throw Error('Esta conta já pertence a outro cliente.');
    const name=String(account.displayName||account.username||account.phoneNumber||accountId).slice(0,120);
    await q(svc.from('conexao_contas').upsert({
      workspace_id:ws,conexao_id:c.id,tipo:platforms[platform].tipo,
      id_externo:accountId,nome:name,sincronizar:true,
      extras:{username:account.username||null,phoneNumber:account.phoneNumber||null}
    },{onConflict:'conexao_id,tipo,id_externo'}));
    await q(svc.from('conexoes').update({status:'conectado',conectado_em:new Date().toISOString()}).eq('id',c.id).eq('workspace_id',ws));
    if(platform==='whatsapp'){
      const existing=await q(svc.from('atd_canais').select('id').eq('provedor','zernio').eq('externo_id',accountId).maybeSingle());
      const dados={workspace_id:ws,provedor:'zernio',canal:'whatsapp',externo_id:accountId,
        nome:name,status:'conectado',ativo:true,numero:account.phoneNumber||null};
      if(existing)await q(svc.from('atd_canais').update(dados).eq('id',existing.id).eq('workspace_id',ws));
      else await q(svc.from('atd_canais').insert(dados));
    }
    return page(true,'A conta '+name+' foi vinculada ao cliente selecionado.');
  }catch(e){return page(false,(e as Error).message);}
}
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:CORS});
  try{
    if(req.method==='POST')return await start(req);
    if(req.method==='GET')return await callback(new URL(req.url));
    return json({erro:'Método não permitido.'},405);
  }catch(e){return json({erro:(e as Error).message},500);}
});
