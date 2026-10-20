// Google: login OAuth, canais do YouTube e contas do Google Ads; puxa YouTube (canal, vídeos, vídeos cadastrados) e Google Ads.
// Segredos: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET. Google Ads também precisa de GOOGLE_ADS_DEVELOPER_TOKEN
// (e, se a conta for gerenciada por uma MCC, GOOGLE_ADS_LOGIN_CUSTOMER_ID). Versão: GOOGLE_ADS_API_VERSION (padrão v20).
import { type Dic, GADS_V, ErroPlataforma, env, num, pede, qs } from './util.ts';

export const GOOGLE_ESCOPOS = ['openid', 'email', 'https://www.googleapis.com/auth/youtube.readonly', 'https://www.googleapis.com/auth/yt-analytics.readonly', 'https://www.googleapis.com/auth/adwords'];

export function googleUrlLogin(redirect: string, state: string): string {
  if (!env('GOOGLE_CLIENT_ID')) throw new ErroPlataforma('Google', 'falta cadastrar o segredo GOOGLE_CLIENT_ID no Supabase');
  return 'https://accounts.google.com/o/oauth2/v2/auth?' + qs({ client_id: env('GOOGLE_CLIENT_ID'), redirect_uri: redirect, response_type: 'code', access_type: 'offline', prompt: 'consent',
    include_granted_scopes: 'true', state, scope: GOOGLE_ESCOPOS.join(' ') });
}

async function token(corpo: Record<string, string>) {
  const id = env('GOOGLE_CLIENT_ID'), seg = env('GOOGLE_CLIENT_SECRET');
  if (!id || !seg) throw new ErroPlataforma('Google', 'faltam os segredos GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET no Supabase');
  return await pede('Google', 'https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: qs({ ...corpo, client_id: id, client_secret: seg }) });
}
export async function googleRenova(refresh: string) {
  const j = await token({ grant_type: 'refresh_token', refresh_token: refresh });
  return { access: String(j.access_token), expira: new Date(Date.now() + Number(j.expires_in || 3600) * 1000).toISOString() };
}
const adsHeaders = (tk: string): Record<string, string> => {
  const h: Record<string, string> = { Authorization: `Bearer ${tk}`, 'developer-token': env('GOOGLE_ADS_DEVELOPER_TOKEN'), 'Content-Type': 'application/json' };
  if (env('GOOGLE_ADS_LOGIN_CUSTOMER_ID')) h['login-customer-id'] = env('GOOGLE_ADS_LOGIN_CUSTOMER_ID').replace(/\D/g, '');
  return h;
};

export async function googleTrocaCodigo(code: string, redirect: string) {
  const j = await token({ grant_type: 'authorization_code', code, redirect_uri: redirect });
  const tk = String(j.access_token), exp = new Date(Date.now() + Number(j.expires_in || 3600) * 1000).toISOString();
  const eu = await pede('Google', 'https://openidconnect.googleapis.com/v1/userinfo', { headers: { Authorization: `Bearer ${tk}` } }).catch(() => ({} as Dic));
  const contas: Dic[] = [];
  const yt = await pede('Google', 'https://www.googleapis.com/youtube/v3/channels?' + qs({ part: 'snippet,contentDetails', mine: 'true', maxResults: 50 }), { headers: { Authorization: `Bearer ${tk}` } }).catch(() => ({ items: [] } as Dic));
  for (const c of (yt.items as Dic[]) || []) contas.push({ tipo: 'youtube', id: c.id, nome: ((c.snippet as Dic) || {}).title, extras: { uploads: (((c.contentDetails as Dic) || {}).relatedPlaylists as Dic || {}).uploads } });
  if (env('GOOGLE_ADS_DEVELOPER_TOKEN')) {
    const ac = await pede('Google Ads', `https://googleads.googleapis.com/${GADS_V()}/customers:listAccessibleCustomers`, { headers: adsHeaders(tk) }).catch(() => ({ resourceNames: [] } as Dic));
    for (const r of (ac.resourceNames as string[]) || []) { const id = r.split('/')[1]; contas.push({ tipo: 'google_ads', id, nome: 'Google Ads ' + id.replace(/(\d{3})(\d{3})(\d+)/, '$1-$2-$3'), extras: {} }); }
  }
  return { access: tk, refresh: j.refresh_token ? String(j.refresh_token) : null, expira: exp, nome: String(eu.email || eu.name || ''), escopos: String(j.scope || '').split(' ').filter(Boolean), contas };
}

const YA = 'https://youtubeanalytics.googleapis.com/v2/reports?';
async function relatorio(tk: string, p: Record<string, string>): Promise<Dic[]> {
  const j = await pede('YouTube', YA + qs(p), { headers: { Authorization: `Bearer ${tk}` } });
  const cols = ((j.columnHeaders as Dic[]) || []).map(c => String(c.name));
  return ((j.rows as unknown[][]) || []).map(r => Object.fromEntries(cols.map((c, i) => [c, r[i]])));
}

export async function youtubeCanal(tk: string, canal: string, uploads: string | undefined, de: string, ate: string) {
  const avisos: string[] = [];
  const perfil: Dic[] = (await relatorio(tk, { ids: `channel==${canal}`, startDate: de, endDate: ate, metrics: 'views,estimatedMinutesWatched,subscribersGained,subscribersLost', dimensions: 'day', sort: 'day' })
    .catch(e => { avisos.push('YouTube canal: ' + (e as Error).message); return []; }))
    .map(r => ({ data: r.day, visualizacoes: num(r.views), minutos_assistidos: num(r.estimatedMinutesWatched), seguidores_ganhos: (Number(r.subscribersGained) || 0) - (Number(r.subscribersLost) || 0) }));
  const H = { headers: { Authorization: `Bearer ${tk}` } };
  try { const c = await pede('YouTube', 'https://www.googleapis.com/youtube/v3/channels?' + qs({ part: 'statistics', id: canal }), H);
    const st = (((c.items as Dic[]) || [])[0] || {}).statistics as Dic | undefined; const hoje = new Date().toISOString().slice(0, 10);
    const linha = perfil.find(p => p.data === hoje) || (perfil.push({ data: hoje }), perfil[perfil.length - 1]); linha.seguidores = num(st && st.subscriberCount);
  } catch (e) { avisos.push('YouTube inscritos: ' + (e as Error).message); }
  const posts: Dic[] = [];
  if (uploads) try {
    const pl = await pede('YouTube', 'https://www.googleapis.com/youtube/v3/playlistItems?' + qs({ part: 'contentDetails', playlistId: uploads, maxResults: 50 }), H);
    const ids = ((pl.items as Dic[]) || []).map(i => String(((i.contentDetails as Dic) || {}).videoId)).filter(Boolean);
    if (ids.length) { const v = await pede('YouTube', 'https://www.googleapis.com/youtube/v3/videos?' + qs({ part: 'snippet,statistics', id: ids.join(',') }), H);
      for (const x of (v.items as Dic[]) || []) { const sn = (x.snippet as Dic) || {}, st = (x.statistics as Dic) || {};
        posts.push({ id: x.id, tipo: 'video', legenda: sn.title, url: `https://www.youtube.com/watch?v=${x.id}`, miniatura: (((sn.thumbnails as Dic) || {}).medium as Dic || {}).url || null, publicado_em: sn.publishedAt,
          visualizacoes: num(st.viewCount), curtidas: num(st.likeCount), comentarios: num(st.commentCount) }); } }
  } catch (e) { avisos.push('YouTube vídeos: ' + (e as Error).message); }
  return { perfil, posts, avisos };
}

export async function youtubeVideos(tk: string, canal: string, videos: { fonte_id: string; video: string }[], de: string, ate: string) {
  const out: Dic[] = [], avisos: string[] = [];
  for (const v of videos) {
    const id = (v.video.match(/(?:v=|youtu\.be\/|\/live\/|\/shorts\/)([\w-]{11})/) || [, v.video])[1];
    try {
      for (const r of await relatorio(tk, { ids: `channel==${canal}`, startDate: de, endDate: ate, metrics: 'views,estimatedMinutesWatched,averageViewPercentage', dimensions: 'day', filters: `video==${id}`, sort: 'day' }))
        out.push({ fonte_id: v.fonte_id, data: r.day, plays: num(r.views), minutos: num(r.estimatedMinutesWatched), retencao_pct: num(r.averageViewPercentage) });
    } catch (e) { avisos.push(`YouTube vídeo ${id}: ${(e as Error).message}`); }
  }
  return { linhas: out, avisos };
}

export async function googleAnuncios(tk: string, cliente: string, de: string, ate: string): Promise<Dic[]> {
  if (!env('GOOGLE_ADS_DEVELOPER_TOKEN')) throw new ErroPlataforma('Google Ads', 'falta o segredo GOOGLE_ADS_DEVELOPER_TOKEN no Supabase');
  const query = `SELECT segments.date, campaign.id, campaign.name, ad_group.name, ad_group_ad.ad.id, ad_group_ad.ad.name, ad_group_ad.ad.final_urls, ad_group_ad.ad.tracking_url_template,
    metrics.impressions, metrics.clicks, metrics.cost_micros, metrics.conversions, metrics.conversions_value FROM ad_group_ad WHERE segments.date BETWEEN '${de}' AND '${ate}'`;
  const j = await pede('Google Ads', `https://googleads.googleapis.com/${GADS_V()}/customers/${cliente.replace(/\D/g, '')}/googleAds:searchStream`, { method: 'POST', headers: adsHeaders(tk), body: JSON.stringify({ query }) });
  const lotes = Array.isArray(j) ? j as Dic[] : ((j as Dic)[0] !== undefined ? Object.values(j) as Dic[] : [j]);
  const out: Dic[] = [];
  for (const b of lotes) for (const r of (b.results as Dic[]) || []) {
    const c = (r.campaign as Dic) || {}, g = (r.adGroup as Dic) || {}, ad = (((r.adGroupAd as Dic) || {}).ad as Dic) || {}, m = (r.metrics as Dic) || {}, s = (r.segments as Dic) || {};
    const url = String(((ad.finalUrls as string[]) || [])[0] || ''), tags = url.includes('?') ? url.split('?')[1] : (ad.trackingUrlTemplate ? String(ad.trackingUrlTemplate).split('?')[1] || null : null);
    out.push({ data: s.date, campanha_ext: String(c.id), campanha_nome: c.name, conjunto_nome: g.name, anuncio_ext: String(ad.id), anuncio_nome: ad.name || g.name, url_tags: tags,
      impressoes: num(m.impressions) || 0, cliques: num(m.clicks) || 0, custo: (Number(m.costMicros) || 0) / 1e6, conversoes: num(m.conversions), receita: num(m.conversionsValue) });
  }
  return out;
}
