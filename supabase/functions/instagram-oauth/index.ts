// v0.179 — Instagram Login direto. Uma única ZERNIO_API_KEY para todos os workspaces.
// O OAuth é aberto no Instagram; a chave nunca é enviada ao navegador.
// Callback somente com nonce de uso único + verificação da conta na Zernio.
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';
const URL_SB = Deno.env.get('SUPABASE_URL')!;
const service = createClient(URL_SB, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,GET,OPTIONS'};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}});
const q=async(p:any):Promise<any>=>{const {data,error}=await p;if(error)throw new Error(error.message);return data;};
const key=()=>{const k=Deno.env.get('ZERNIO_API_KEY');if(!k)throw new Error('ZERNIO_API_KEY não configurada no Supabase.');return k;};
async function api(path:string,method='GET',payload?:unknown):Promise<any>{
  const r=await fetch('https://zernio.com/api/v1'+path,{
    method,redirect:'error',signal:AbortSignal.timeout(20000),
    headers:{'Authorization':'Bearer '+key(),'Content-Type':'application/json'},
    body:payload===undefined?undefined:JSON.stringify(payload)
  });
  const body=await r.json().catch(()=>({}));
  if(!r.ok)throw new Error('A Zernio recusou a operação (HTTP '+r.status+').');
  return body;
}
const profileOf=(a:any):string=>String(typeof a?.profileId==='object'?(a.profileId?._id||a.profileId?.id||''):(a?.profileId||''));
const idOf=(a:any):string=>String(a?._id||a?.id||a?.accountId||'');
const validId=(id:any)=>typeof id==='string'&&/^[0-9a-f]{24}$/i.test(id);
async function accounts(profileId?:string){
  // Consultar todas evita depender da paginação/formatos variados do SDK;
  // o filtro de profile é revalidado SEMPRE no servidor.
  const url=profileId?'/accounts?profileId='+encodeURIComponent(profileId):'/accounts';
  const r=await api(url);
  if(!Array.isArray(r.accounts))throw new Error('Resposta de contas inválida da Zernio.');
  return r.accounts;
}
async function ensureProfile(ws:string,userId:string){
  const existing=await q(service.from('conexoes').select('id,zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').maybeSingle());
  if(existing?.zernio_profile_id)return String(existing.zernio_profile_id);
  // Compatibilidade: perfil já conectado no Growth V2 continua o mesmo.
  const linked=await q(service.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)').eq('workspace_id',ws).eq('conexoes.plataforma','zernio'));
  let profileId='';
  if(linked.length){
    const all=await accounts();
    const ids=new Set(linked.map((c:any)=>c.id_externo));
    const profiles=new Set(all.filter((a:any)=>ids.has(idOf(a))).map(profileOf).filter(Boolean));
    if(profiles.size===1)profileId=[...profiles][0] as string;
  }
  if(!profileId){
    const w=await q(service.from('workspaces').select('nome').eq('id',ws).single());
    const r=await api('/profiles','POST',{name:String(w.nome||'Cliente Growths').slice(0,100)});
    profileId=String(r.profile?._id||r.profile?.id||'');
    if(!validId(profileId))throw new Error('A Zernio não retornou um identificador de perfil válido.');
  }
  const row=await q(service.from('conexoes').upsert({
    workspace_id:ws,plataforma:'zernio',conta_nome:'Zernio',status:existing?'conectado':'desconectado',
    zernio_profile_id:profileId,conectado_por:userId
  },{onConflict:'workspace_id,plataforma'}).select('id,zernio_profile_id').single());
  if(row.zernio_profile_id!==profileId)throw new Error('Perfil Zernio inconsistente.');
  return profileId;
}
function page(ok:boolean,message:string){
  const title=ok?'Instagram conectado':'Não foi possível conectar o Instagram';
  const safe=message.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]||c));
  return new Response('<!doctype html><html lang="pt-br"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+title+'</title></head><body style="font:16px system-ui;background:#faf8f7;color:#242424;text-align:center;padding:12vh 24px"><h2>'+title+'</h2><p>'+safe+'</p><p>Você pode fechar esta janela e retornar ao Growths.</p>'+(ok?'<script>window.close()<\/script>':'')+'</body></html>',{status:200,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"}});
}
async function start(req:Request){
  const token=req.headers.get('Authorization')||'';
  const userClient=createClient(URL_SB,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}},auth:{persistSession:false}});
  const {data:{user},error}=await userClient.auth.getUser();
  if(error||!user)return json({erro:'Faça login novamente.'},401);
  const b=await req.json().catch(()=>({}));
  const ws=String(b.workspace_id||'');
  if(!/^[0-9a-f-]{36}$/i.test(ws))return json({erro:'Cliente inválido.'},400);
  const nonce=await q(userClient.rpc('zernio_oauth_iniciar',{p_ws:ws}));
  try{
    const profileId=await ensureProfile(ws,user.id);
    const redirect=new URL(URL_SB+'/functions/v1/instagram-oauth');
    redirect.searchParams.set('state',nonce);
    const result=await api('/connect/instagram?'+new URLSearchParams({
      profileId,loginMethod:'instagram_login',redirect_url:redirect.toString()
    }).toString());
    const authUrl=String(result.authUrl||'');
    const auth=new URL(authUrl);
    if(auth.protocol!=='https:' || !['instagram.com','www.instagram.com','facebook.com','www.facebook.com'].includes(auth.hostname))
      throw new Error('URL de autorização inválida da Zernio.');
    return json({authUrl});
  }catch(e){return json({erro:(e as Error).message},502);}
}
async function callback(url:URL){
  const state=url.searchParams.get('state')||'';
  if(!/^[0-9a-f]{64}$/i.test(state))return page(false,'Autorização inválida ou expirada.');
  const saved=await q(service.rpc('conexao_estado_usar',{p_nonce:state}));
  if(!saved||saved.plataforma!=='zernio'||saved.volta!=='instagram-oauth')return page(false,'Esta autorização já foi utilizada ou expirou.');
  const ws=String(saved.ws||'');
  if(url.searchParams.has('error'))return page(false,'A autorização foi cancelada ou recusada no Instagram.');
  const accountId=String(url.searchParams.get('accountId')||'');
  const callbackProfile=String(url.searchParams.get('profileId')||'');
  if(url.searchParams.get('connected')!=='instagram'||!validId(accountId)||!validId(callbackProfile))
    return page(false,'Não foi possível validar o retorno do Instagram.');
  try{
    const connection=await q(service.from('conexoes').select('id,zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').single());
    if(connection.zernio_profile_id!==callbackProfile)throw new Error('O perfil retornado não pertence a este cliente.');
    const account=(await accounts(callbackProfile)).find((a:any)=>idOf(a)===accountId&&a.platform==='instagram'&&profileOf(a)===callbackProfile);
    if(!account)throw new Error('A conta conectada não foi confirmada pela Zernio neste cliente.');
    const [links,channels]=await Promise.all([
      q(service.from('conexao_contas').select('workspace_id,conexoes!inner(plataforma)').eq('id_externo',accountId).eq('conexoes.plataforma','zernio')),
      q(service.from('atd_canais').select('workspace_id').eq('provedor','zernio').eq('externo_id',accountId))
    ]);
    if([...links,...channels].some((x:any)=>x.workspace_id!==ws))
      throw new Error('Esta conta já está vinculada a outro cliente.');
    const name=String(account.displayName||account.username||accountId).slice(0,120);
    // Reaproveita vínculos existentes; não apaga conversas, métricas ou postagens.
    await q(service.from('conexao_contas').upsert({
      workspace_id:ws,conexao_id:connection.id,tipo:'instagram',
      id_externo:accountId,nome:name,sincronizar:true
    },{onConflict:'conexao_id,tipo,id_externo'}));
    await q(service.from('conexoes').update({status:'conectado',conta_nome:name,conectado_em:new Date().toISOString()}).eq('id',connection.id));
    const previous=await q(service.from('atd_canais').select('id').eq('provedor','zernio').eq('externo_id',accountId).maybeSingle());
    if(!previous)await q(service.from('atd_canais').insert({
      workspace_id:ws,provedor:'zernio',canal:'instagram',nome:name,externo_id:accountId,status:'conectado'
    }));
    return page(true,'A conta @'+String(account.username||name).slice(0,100)+' está vinculada ao cliente.');
  }catch(e){return page(false,(e as Error).message);}
}
Deno.serve(async req=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  try{
    if(req.method==='POST')return await start(req);
    if(req.method==='GET')return await callback(new URL(req.url));
    return json({erro:'Método não permitido.'},405);
  }catch(e){return json({erro:(e as Error).message},500);}
});
