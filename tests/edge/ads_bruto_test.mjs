// Simula as APIs da Meta e do Google para conferir a coleta do bruto e a volta aos campos básicos.
// Rodar: node --experimental-transform-types --no-warnings tests/edge/ads_bruto_test.mjs
globalThis.Deno = { env: { get: k => ({ GOOGLE_ADS_DEVELOPER_TOKEN: 'x' })[k] } };
const resp = (o, st = 200) => new Response(JSON.stringify(o), { status: st });
let recusa = false, pedidos = [];
globalThis.fetch = async (u, init) => { u = String(u); pedidos.push(u + ' ' + (init && init.body || ''));
  if (u.includes('/insights')) { if (recusa && u.includes('quality_ranking')) return resp({ error: { message: 'campo inválido' } }, 400); return resp({ data: [{ date_start: '2026-10-01', campaign_id: 'c', campaign_name: 'C', adset_name: 'S', ad_id: 'a1', ad_name: 'A', impressions: '100', clicks: '5', spend: '12.5', reach: '90', frequency: '1.1', actions: [{ action_type: 'lead', value: '3' }] }] }); }
  if (u.includes('/ads?')) return resp({ data: [{ id: 'a1', name: 'A', creative: { url_tags: 'utm_content=x', title: 'Título' } }] });
  if (u.includes('searchStream')) { if (recusa && String(init.body).includes('video_views')) return resp({ error: { message: 'campo inválido' } }, 400);
    return resp([{ results: [{ segments: { date: '2026-10-01' }, campaign: { id: '1', name: 'Busca', advertisingChannelType: 'SEARCH' }, adGroup: { name: 'G' }, adGroupAd: { ad: { id: '10', finalUrls: ['https://x.io?utm_content=a'] } }, metrics: { impressions: '10', clicks: '1', costMicros: '2000000' } }, { segments: { date: '2026-10-01' }, campaign: { id: '2', name: 'Vídeo', advertisingChannelType: 'VIDEO' }, adGroup: { name: 'G' }, adGroupAd: { ad: { id: '20' } }, metrics: { impressions: '50', clicks: '2', costMicros: '3000000', videoViews: '40' } }] }]); }
  return resp({ error: { message: 'url inesperada ' + u } }, 404); };
const { metaAnuncios } = await import('../../supabase/functions/conexoes/meta.ts');
const { googleAnuncios } = await import('../../supabase/functions/conexoes/google.ts');
let ok = true; const chk = (c, m, x) => { console.log((c ? 'OK   ' : 'FALHA') + ' ' + m + (c ? '' : ' → ' + JSON.stringify(x))); ok = ok && !!c; };
let co = { bruto: [], avisos: [] };
const m1 = await metaAnuncios('tk', 'act_1', '2026-10-01', '2026-10-01', co);
chk(m1[0].custo === 12.5 && m1[0].leads === 3 && m1[0].url_tags === 'utm_content=x', 'Meta: tratamento igual ao de antes', m1);
chk(co.bruto[0].prov === 'meta_ads' && co.bruto[0].payload.insights.frequency === '1.1' && co.bruto[0].payload.anuncio.creative.title === 'Título', 'Meta: bruto com tudo', co.bruto);
chk(pedidos.some(p => p.includes('video_p25_watched_actions')), 'Meta: pede os campos completos');
co = { bruto: [], avisos: [] }; const g1 = await googleAnuncios('tk', '123', '2026-10-01', '2026-10-01', co);
chk(g1.length === 2 && g1[0].custo === 2 && g1[1].custo === 3, 'Google: tratamento igual ao de antes', g1);
chk(co.bruto[0].prov === 'google_ads' && co.bruto[1].prov === 'youtube_ads' && co.bruto[1].payload.metrics.videoViews === '40', 'campanha de vídeo vai para o YouTube Ads', co.bruto);
recusa = true; co = { bruto: [], avisos: [] };
const m2 = await metaAnuncios('tk', 'act_1', '2026-10-01', '2026-10-01', co);
chk(m2.length === 1 && co.avisos.length === 1 && co.bruto.length === 1, 'Meta: campo recusado volta ao básico, com aviso', co);
co = { bruto: [], avisos: [] }; const g2 = await googleAnuncios('tk', '123', '2026-10-01', '2026-10-01', co);
chk(g2.length === 2 && co.avisos.length === 1, 'Google: campo recusado volta ao básico, com aviso', co);
const m3 = await metaAnuncios('tk', 'act_1', '2026-10-01', '2026-10-01');
chk(m3.length === 1, 'sem coleta continua funcionando');
console.log(ok ? 'ads_bruto: tudo OK' : 'ads_bruto: COM FALHAS'); process.exit(ok ? 0 : 1);
