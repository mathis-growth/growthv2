Deno.serve(async req => {
  if(req.method==='OPTIONS') return new Response('ok',{headers:CORS});
  if(req.method!=='POST') return json({erro:'Use POST.'},405);
  try {
    if(Number(req.headers.get('content-length')) > 12*1024*1024) return json({erro:'Requisição muito grande.'},413);
    const raw = await req.text(); if(raw.length > 12*1024*1024) return json({erro:'Requisição muito grande.'},413);
    const url = new URL(req.url);
    if(url.searchParams.has('provider'))return await webhook(req,url,raw);
    const b=JSON.parse(raw);
    if(b.action==='qr-share-view')return await qrSharePublico(b);
    if(b.action==='processar-grupos-periodico')return await processarGruposPeriodicos(req);
    if(b.action==='processar-agendamentos')return await processarAgendamentos(req);
    if(b.action==='processar-grupos-disparo')return await processarDisparosGruposAgendados(req);
    if(b.action==='processar-emails')return await processarEmails(req);
    return await handle(req,b);
  } catch(e) {
    // Sem logs de payload, URL com token ou chaves. Mensagens conhecidas são seguras.
    return json({erro:e instanceof ProviderError ? e.message : (e as Error).message?.slice(0,220) || 'Não foi possível concluir.'},400);
  }
});
