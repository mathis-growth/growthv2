async function zernioCandidates(ws: string) {
  const [connection,linked] = await Promise.all([
    q(db.from('conexoes').select('zernio_profile_id').eq('workspace_id',ws).eq('plataforma','zernio').maybeSingle()),
    q(db.from('conexao_contas').select('id_externo,conexoes!inner(plataforma)').eq('workspace_id',ws).eq('conexoes.plataforma','zernio'))
  ]);
  let profileId=String(connection?.zernio_profile_id||'');
  let response:any;
  if(profileId){
    response=await zernio(zp(),'/accounts?profileId='+encodeURIComponent(profileId));
  }else{
    // Workspaces antigos podem não ter zernio_profile_id; inferi-lo apenas pelas contas já ligadas.
    const all=(await zernio(zp(),'/accounts')).accounts||[];
    const linkedIds=new Set(linked.map((a:any)=>a.id_externo));
    const profiles=new Set(all.filter((a:any)=>linkedIds.has(String(a._id||a.id||a.accountId||'')))
      .map((a:any)=>typeof a.profileId==='object'?(a.profileId?._id||a.profileId?.id||''):(a.profileId||'')).filter(Boolean));
    if(profiles.size!==1)return [];
    profileId=String([...profiles][0]);
    response={accounts:all.filter((a:any)=>String(typeof a.profileId==='object'?(a.profileId?._id||a.profileId?.id||''):(a.profileId||''))===profileId)};
  }
  const accounts=Array.isArray(response?.accounts)?response.accounts:[];
  const normalized=accounts.filter((a:any)=>['instagram','whatsapp'].includes(a.platform))
    .map((a:any)=>({id:String(a._id||a.id||a.accountId||''),canal:a.platform,nome:String(a.displayName||a.username||a.phoneNumber||a._id||a.id||'Conta Zernio').slice(0,120)}))
    .filter((a:any)=>/^[a-f0-9]{24}$/i.test(a.id));
  if(!normalized.length)return [];
  const ids=normalized.map((a:any)=>a.id);
  const [otherLinks,otherChannels]=await Promise.all([
    q(db.from('conexao_contas').select('workspace_id,id_externo,conexoes!inner(plataforma)').eq('conexoes.plataforma','zernio').in('id_externo',ids)),
    q(db.from('atd_canais').select('workspace_id,externo_id').eq('provedor','zernio').in('externo_id',ids))
  ]);
  const occupiedElsewhere=new Set([...otherLinks,...otherChannels].filter((x:any)=>x.workspace_id!==ws).map((x:any)=>x.id_externo||x.externo_id));
  // Mostra contas ainda não importadas para o Growth, sem expor contas de outro workspace.
  return normalized.filter((a:any)=>!occupiedElsewhere.has(a.id));
}
// A primeira associação é explícita por workspace; nunca expor a API Key Zernio.
async function zernioDisponiveis(ws: string) {
  const raw = (await zernio(zp(), '/accounts')).accounts || [];
  const accounts = raw.filter((a: any) => ['instagram','whatsapp'].includes(a.platform) && typeof a._id === 'string');
  const existing = await q(db.from('conexao_contas').select('workspace_id,id_externo,conexoes!inner(plataforma)').eq('conexoes.plataforma','zernio').in('id_externo',accounts.length ? accounts.map((a: any)=>a._id) : ['__nenhuma__']));
  const channels = await q(db.from('atd_canais').select('workspace_id,externo_id').eq('provedor','zernio').in('externo_id',accounts.length ? accounts.map((a: any)=>a._id) : ['__nenhuma__']));
  const occupied = new Set([...existing,...channels].filter((a:any)=>a.workspace_id!==ws).map((a:any)=>a.id_externo || a.externo_id));
  return accounts.filter((a:any)=>!occupied.has(a._id)).map((a:any)=>({
    id:a._id, canal:a.platform, nome:String(a.displayName || a.username || a._id).slice(0,120),
    vinculada:existing.some((x:any)=>x.workspace_id===ws && x.id_externo===a._id)
  }));
}
