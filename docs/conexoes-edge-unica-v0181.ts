// Growth V2 — conexoes (Edge Function de ARQUIVO ÚNICO para Supabase Dashboard).
// Meta Ads, Páginas, Instagram profissional, Google Ads e YouTube.
// OAuth Meta: usa META_LOGIN_CONFIG_ID quando disponível (Facebook Login for Business).
// WhatsApp Business Platform requer Embedded Signup próprio — não implementado aqui.
// Cole TUDO como index.ts da função 'conexoes'. Configure Verify JWT = OFF pelo callback público.
// Segredos permanecem no servidor; não coloque tokens ou chaves neste arquivo.
import { createClient } from 'jsr:@supabase/supabase-js@2';

// ===================== UTILITÁRIOS (util.ts) =====================
// Utilidades das conexões (Meta e Google): chamadas HTTP com erro legível, datas e paginação.
type Dic = Record<string, unknown>;
const env = (k: string, d = '') => Deno.env.get(k) || d;
const META_V = () => env('META_API_VERSION', 'v21.0');
const GADS_V = () => env('GOOGLE_ADS_API_VERSION', 'v20');

class ErroPlataforma extends Error {
  constructor(public plataforma: string, msg: string, public status = 0) { super(`${plataforma}: ${msg}`); }
}

async function pede(plataforma: string, url: string, init?: RequestInit): Promise<Dic> {
  const r = await fetch(url, init);
  const t = await r.text();
  let j: Dic = {};
  try { j = t ? JSON.parse(t) : {}; } catch { j = { texto: t.slice(0, 300) }; }
  if (!r.ok || (j as { error?: unknown }).error) {
    const e = (j as { error?: Dic | string }).error;
    const msg = typeof e === 'string' ? e + ((j as Dic).error_description ? ' — ' + (j as Dic).error_description : '')
      : e ? String((e as Dic).message || (e as Dic).status || JSON.stringify(e)).slice(0, 400) : `HTTP ${r.status} ${String((j as Dic).texto || '').slice(0, 200)}`;
    throw new ErroPlataforma(plataforma, msg, r.status);
  }
  return j;
}

const dia = (d: Date) => d.toISOString().slice(0, 10);
function janela(dias: number, ultima?: string | null): { de: string; ate: string } {
  // primeira vez: puxa os dias configurados; depois, os últimos 3 dias (as plataformas ajustam números recentes)
  const hoje = new Date(), n = ultima ? Math.min(dias, 3) : dias;
  const de = new Date(hoje.getTime() - n * 86400000);
  return { de: dia(de), ate: dia(hoje) };
}
const num = (v: unknown): number | null => v === null || v === undefined || v === '' ? null : Number(v);
const qs = (o: Record<string, string | number | undefined>) => Object.entries(o).filter(([, v]) => v !== undefined && v !== '').map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`).join('&');


// ===================== META (meta.ts) =====================
// Meta: login (Facebook Login), contas de anúncio, páginas e Instagram profissional; puxa anúncios e orgânico do Instagram.
// Segredos: META_APP_ID, META_APP_SECRET. Versão da API: META_API_VERSION (padrão v21.0).


const META_ESCOPOS = ['ads_read', 'read_insights', 'pages_show_list', 'pages_read_engagement', 'instagram_basic', 'instagram_manage_insights', 'business_management'];
const G = () => `https://graph.facebook.com/${META_V()}`;

function metaUrlLogin(redirect: string, state: string): string {
  if (!env('META_APP_ID')) throw new ErroPlataforma('Meta', 'falta cadastrar o segredo META_APP_ID no Supabase');
  // Facebook Login for Business: configuração do app controla quais ativos são
  // apresentados (Ads, Páginas e Instagram). Não é o Embedded Signup WhatsApp.
  const configId = env('META_LOGIN_CONFIG_ID');
  if (configId && !/^[0-9]+$/.test(configId))
    throw new ErroPlataforma('Meta', 'META_LOGIN_CONFIG_ID deve ser um identificador numérico válido');
  return `https://www.facebook.com/${META_V()}/dialog/oauth?` + qs({
    client_id: env('META_APP_ID'), redirect_uri: redirect, state,
    scope: META_ESCOPOS.join(','), response_type: 'code',
    ...(configId ? { config_id:configId } : {})
  });
}

async function metaTrocaCodigo(code: string, redirect: string) {
  const id = env('META_APP_ID'), seg = env('META_APP_SECRET');
  if (!id || !seg) throw new ErroPlataforma('Meta', 'faltam os segredos META_APP_ID e META_APP_SECRET no Supabase');
  const curto = await pede('Meta', `${G()}/oauth/access_token?` + qs({ client_id: id, client_secret: seg, redirect_uri: redirect, code }));
  // token de longa duração (~60 dias)
  const longo = await pede('Meta', `${G()}/oauth/access_token?` + qs({ grant_type: 'fb_exchange_token', client_id: id, client_secret: seg, fb_exchange_token: String(curto.access_token) }));
  const tk = String(longo.access_token || curto.access_token);
  const exp = longo.expires_in ? new Date(Date.now() + Number(longo.expires_in) * 1000).toISOString() : null;
  const eu = await pede('Meta', `${G()}/me?` + qs({ fields: 'id,name', access_token: tk }));
  const perms = await pede('Meta', `${G()}/me/permissions?` + qs({ access_token: tk })).catch(() => ({ data: [] }));
  const escopos = ((perms.data as Dic[]) || []).filter(p => p.status === 'granted').map(p => String(p.permission));
  const contas: Dic[] = [];
  const ads = await todas(`${G()}/me/adaccounts?` + qs({ fields: 'id,name,account_status,currency', limit: 200, access_token: tk })).catch(() => []);
  for (const a of ads) contas.push({ tipo: 'meta_ads', id: a.id, nome: a.name, extras: { moeda: a.currency, situacao: a.account_status } });
  const pags = await todas(`${G()}/me/accounts?` + qs({ fields: 'id,name,instagram_business_account{id,username,name}', limit: 200, access_token: tk })).catch(() => []);
  for (const p of pags) {
    contas.push({ tipo: 'facebook_pagina', id: p.id, nome: p.name, extras: {} });
    const ig = p.instagram_business_account as Dic | undefined;
    if (ig && ig.id) contas.push({ tipo: 'instagram', id: ig.id, nome: '@' + (ig.username || ig.name || ig.id), extras: { pagina: p.id } });
  }
  return { access: tk, refresh: null, expira: exp, nome: String(eu.name || ''), escopos, contas };
}

async function todas(url: string, max = 20): Promise<Dic[]> {
  const out: Dic[] = []; let u: string | undefined = url; let i = 0;
  while (u && i++ < max) { const j = await pede('Meta', u); out.push(...((j.data as Dic[]) || [])); u = ((j.paging as Dic) || {}).next as string | undefined; }
  return out;
}
const acao = (lista: unknown, tipos: string[]) => ((lista as Dic[]) || []).filter(a => tipos.includes(String(a.action_type))).reduce((s, a) => s + Number(a.value || 0), 0);
const LEAD = ['lead', 'onsite_conversion.lead_grouped', 'offsite_conversion.fb_pixel_lead', 'leadgen_grouped'];
const COMPRA = ['purchase', 'offsite_conversion.fb_pixel_purchase', 'omni_purchase'];

async function metaAnuncios(tk: string, conta: string, de: string, ate: string): Promise<Dic[]> {
  const tags: Record<string, string> = {};
  const ads = await todas(`${G()}/${conta}/ads?` + qs({ fields: 'id,creative{url_tags}', limit: 500, access_token: tk })).catch(() => []);
  for (const a of ads) { const t = ((a.creative as Dic) || {}).url_tags; if (t) tags[String(a.id)] = String(t); }
  const linhas = await todas(`${G()}/${conta}/insights?` + qs({ level: 'ad', time_increment: 1, time_range: JSON.stringify({ since: de, until: ate }), limit: 500, access_token: tk,
    fields: 'date_start,campaign_id,campaign_name,adset_name,ad_id,ad_name,impressions,clicks,spend,reach,actions,action_values' }), 100);
  return linhas.map(l => ({ data: l.date_start, campanha_ext: l.campaign_id, campanha_nome: l.campaign_name, conjunto_nome: l.adset_name, anuncio_ext: l.ad_id, anuncio_nome: l.ad_name,
    url_tags: tags[String(l.ad_id)] || null, impressoes: num(l.impressions) || 0, cliques: num(l.clicks) || 0, custo: num(l.spend) || 0, alcance: num(l.reach),
    leads: acao(l.actions, LEAD) || null, conversoes: acao(l.actions, COMPRA) || null, receita: acao(l.action_values, COMPRA) || null }));
}

async function metaInstagram(tk: string, ig: string, de: string, ate: string): Promise<{ perfil: Dic[]; posts: Dic[]; avisos: string[] }> {
  const avisos: string[] = [], dias: Record<string, Dic> = {};
  const desde = Math.floor(new Date(de + 'T00:00:00Z').getTime() / 1000), ateU = Math.floor(new Date(ate + 'T23:59:59Z').getTime() / 1000);
  // alcance: série por dia; visualizações e cliques no link: só existem como total, então pede dia a dia (até 31 dias)
  try {
    const j = await pede('Meta', `${G()}/${ig}/insights?` + qs({ metric: 'reach', period: 'day', since: desde, until: ateU, access_token: tk }));
    for (const s of (j.data as Dic[]) || []) for (const v of (s.values as Dic[]) || []) { const d = String(v.end_time || '').slice(0, 10); if (d) (dias[d] = dias[d] || { data: d }).alcance = num(v.value); }
  } catch (e) { avisos.push(`Instagram alcance: ${(e as Error).message}`); }
  let falhou = false;
  for (let t = new Date(de + 'T00:00:00Z').getTime(), i = 0; t <= new Date(ate + 'T00:00:00Z').getTime() && i < 31 && !falhou; t += 86400000, i++) {
    const d = new Date(t).toISOString().slice(0, 10);
    try {
      const j = await pede('Meta', `${G()}/${ig}/insights?` + qs({ metric: 'views,profile_links_taps', metric_type: 'total_value', period: 'day', since: t / 1000, until: t / 1000 + 86400, access_token: tk }));
      for (const s of (j.data as Dic[]) || []) { const v = num(((s.total_value as Dic) || {}).value); const o = dias[d] = dias[d] || { data: d };
        if (s.name === 'views') o.visualizacoes = v; if (s.name === 'profile_links_taps') o.cliques_site = v; }
    } catch (e) { falhou = true; avisos.push(`Instagram visualizações: ${(e as Error).message}`); }
  }
  try { const p = await pede('Meta', `${G()}/${ig}?` + qs({ fields: 'followers_count,media_count', access_token: tk }));
    const hoje = new Date().toISOString().slice(0, 10); (dias[hoje] = dias[hoje] || { data: hoje }).seguidores = num(p.followers_count);
  } catch (e) { avisos.push(`Instagram seguidores: ${(e as Error).message}`); }
  const posts: Dic[] = [];
  const midias = await todas(`${G()}/${ig}/media?` + qs({ fields: 'id,caption,media_type,media_product_type,permalink,thumbnail_url,media_url,timestamp,like_count,comments_count', limit: 50, access_token: tk }), 4).catch(e => { avisos.push('Instagram posts: ' + (e as Error).message); return [] as Dic[]; });
  for (const m of midias) {
    const p: Dic = { id: m.id, tipo: String(m.media_product_type || m.media_type || '').toLowerCase(), legenda: m.caption || null, url: m.permalink, miniatura: m.thumbnail_url || m.media_url || null,
      publicado_em: m.timestamp, curtidas: num(m.like_count), comentarios: num(m.comments_count) };
    for (const lista of ['reach,saved,shares,views', 'reach,saved']) {
      try { const j = await pede('Meta', `${G()}/${m.id}/insights?` + qs({ metric: lista, access_token: tk }));
        for (const s of (j.data as Dic[]) || []) { const v = num(((s.values as Dic[]) || [])[0]?.value ?? (s.total_value as Dic | undefined)?.value);
          if (s.name === 'reach') p.alcance = v; if (s.name === 'saved') p.salvamentos = v; if (s.name === 'shares') p.compartilhamentos = v; if (s.name === 'views') p.visualizacoes = v; }
        break;
      } catch { /* tenta com menos métricas (posts antigos e alguns tipos não têm todas) */ }
    }
    posts.push(p);
  }
  return { perfil: Object.values(dias), posts, avisos };
}


// ===================== GOOGLE (google.ts) =====================
// Google: login OAuth, canais do YouTube e contas do Google Ads; puxa YouTube (canal, vídeos, vídeos cadastrados) e Google Ads.
// Segredos: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET. Google Ads também precisa de GOOGLE_ADS_DEVELOPER_TOKEN
// (e, se a conta for gerenciada por uma MCC, GOOGLE_ADS_LOGIN_CUSTOMER_ID). Versão: GOOGLE_ADS_API_VERSION (padrão v20).


const GOOGLE_ESCOPOS = ['openid', 'email', 'https://www.googleapis.com/auth/youtube.readonly', 'https://www.googleapis.com/auth/yt-analytics.readonly', 'https://www.googleapis.com/auth/adwords'];

function googleUrlLogin(redirect: string, state: string): string {
  if (!env('GOOGLE_CLIENT_ID')) throw new ErroPlataforma('Google', 'falta cadastrar o segredo GOOGLE_CLIENT_ID no Supabase');
  return 'https://accounts.google.com/o/oauth2/v2/auth?' + qs({ client_id: env('GOOGLE_CLIENT_ID'), redirect_uri: redirect, response_type: 'code', access_type: 'offline', prompt: 'consent',
    include_granted_scopes: 'true', state, scope: GOOGLE_ESCOPOS.join(' ') });
}

async function token(corpo: Record<string, string>) {
  const id = env('GOOGLE_CLIENT_ID'), seg = env('GOOGLE_CLIENT_SECRET');
  if (!id || !seg) throw new ErroPlataforma('Google', 'faltam os segredos GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET no Supabase');
  return await pede('Google', 'https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: qs({ ...corpo, client_id: id, client_secret: seg }) });
}
async function googleRenova(refresh: string) {
  const j = await token({ grant_type: 'refresh_token', refresh_token: refresh });
  return { access: String(j.access_token), expira: new Date(Date.now() + Number(j.expires_in || 3600) * 1000).toISOString() };
}
const adsHeaders = (tk: string): Record<string, string> => {
  const h: Record<string, string> = { Authorization: `Bearer ${tk}`, 'developer-token': env('GOOGLE_ADS_DEVELOPER_TOKEN'), 'Content-Type': 'application/json' };
  if (env('GOOGLE_ADS_LOGIN_CUSTOMER_ID')) h['login-customer-id'] = env('GOOGLE_ADS_LOGIN_CUSTOMER_ID').replace(/\D/g, '');
  return h;
};

async function googleTrocaCodigo(code: string, redirect: string) {
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

async function youtubeCanal(tk: string, canal: string, uploads: string | undefined, de: string, ate: string) {
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

async function youtubeVideos(tk: string, canal: string, videos: { fonte_id: string; video: string }[], de: string, ate: string) {
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

async function googleAnuncios(tk: string, cliente: string, de: string, ate: string): Promise<Dic[]> {
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


// ===================== ROTAS (rotas.ts) =====================
// Rotas da edge function "conexoes" (index.ts só liga o servidor): liga o Growths ao Meta (Facebook Ads + Instagram) e ao Google (Google Ads + YouTube).
//   POST /conexoes/iniciar      {ws, plataforma: 'meta'|'google', volta}  (usuário logado) → { url } para abrir o login da plataforma
//   GET  /conexoes/retorno      a plataforma devolve aqui (?code&state); grava o token e volta para o Growths (?conexao=ok|erro)
//   POST /conexoes/desconectar  {ws, plataforma}                          (usuário logado)
//   POST /conexoes/sincronizar  {ws, plataforma?}                          (usuário logado) → puxa os dados agora
//        ou com o cabeçalho  x-growths-cron: <CONEXOES_CRON_SEGREDO>  e corpo {} → todas as conexões com sincronização automática
// Segredos no Supabase (Edge Functions → Secrets): META_APP_ID, META_APP_SECRET, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET,
//   GOOGLE_ADS_DEVELOPER_TOKEN (opcional), GOOGLE_ADS_LOGIN_CUSTOMER_ID (opcional), CONEXOES_CRON_SEGREDO, APP_URL (endereço do Growths).
// URL de retorno a cadastrar no app do Meta e no Google Cloud:  https://<projeto>.supabase.co/functions/v1/conexoes/retorno
// Publicar SEM verificação de JWT (o retorno vem da plataforma, sem login): supabase functions deploy conexoes --no-verify-jwt
// Os tokens nunca passam pelo navegador: ficam no schema "privado" e só esta função (service_role) lê.





const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-growths-cron', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } });
const URL_SB = () => env('SUPABASE_URL');
const retornoUrl = () => env('CONEXOES_REDIRECT', `${URL_SB()}/functions/v1/conexoes/retorno`);
const servico = () => createClient(URL_SB(), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
const usuario = (req: Request) => createClient(URL_SB(), env('SUPABASE_ANON_KEY'), { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get('authorization') || '' } } });
type SB = ReturnType<typeof servico>;
async function rpc(sb: SB, nome: string, args: Dic) { const { data, error } = await sb.rpc(nome, args); if (error) throw new Error(error.message); return data; }
const volta = (u: string | null | undefined, o: Record<string, string>) => {
  let base = u && /^https?:\/\//.test(u) ? u : env('APP_URL', 'https://growths.app');
  const i = base.indexOf('#'), hash = i >= 0 ? base.slice(i) : '';
  base = (i >= 0 ? base.slice(0, i) : base).replace(/[?&](conexao|plataforma|msg)=[^&]*/g, '').replace(/\?&/, '?').replace(/\?$/, '');
  return base + (base.includes('?') ? '&' : '?') + new URLSearchParams(o).toString() + hash;
};

async function iniciar(req: Request) {
  const b = await req.json().catch(() => ({})) as Dic;
  const nonce = String(await rpc(usuario(req), 'conexao_iniciar', { p_ws: b.ws, p_plataforma: b.plataforma, p_volta: b.volta || null }));
  const url = b.plataforma === 'meta' ? metaUrlLogin(retornoUrl(), nonce) : googleUrlLogin(retornoUrl(), nonce);
  return json({ url });
}

async function retorno(url: URL) {
  const sb = servico(), st = url.searchParams.get('state') || '';
  const e = st ? await rpc(sb, 'conexao_estado_usar', { p_nonce: st }) as Dic | null : null;
  if (!e) return Response.redirect(volta(null, { conexao: 'erro', msg: 'O pedido de conexão expirou. Tente de novo.' }), 302);
  const plat = String(e.plataforma);
  try {
    if (url.searchParams.get('error')) throw new Error(url.searchParams.get('error_description') || url.searchParams.get('error_reason') || url.searchParams.get('error') || 'cancelado');
    const code = url.searchParams.get('code'); if (!code) throw new Error('a plataforma não devolveu o código de acesso');
    const r = plat === 'meta' ? await metaTrocaCodigo(code, retornoUrl()) : await googleTrocaCodigo(code, retornoUrl());
    await rpc(sb, 'conexao_salvar', { p_ws: e.ws, p_plataforma: plat, p_uid: e.uid, p_conta_nome: r.nome, p_escopos: r.escopos, p_access: r.access, p_refresh: r.refresh, p_expira: r.expira, p_contas: r.contas });
    return Response.redirect(volta(e.volta as string, { conexao: 'ok', plataforma: plat }), 302);
  } catch (err) {
    return Response.redirect(volta(e.volta as string, { conexao: 'erro', plataforma: plat, msg: (err as Error).message.slice(0, 300) }), 302);
  }
}

// uma conexão: renova o token se precisar, puxa cada conta escolhida e registra a execução
async function sincronizaConexao(sb: SB, c: Dic, por: string) {
  const ex = await rpc(sb, 'conexao_execucao', { p_conexao: c.id, p_id: null, p_status: 'rodando', p_registros: 0, p_erro: null, p_detalhe: null, p_por: por });
  let n = 0; const avisos: string[] = [], det: Dic = {};
  try {
    let tk = String(c.access_token);
    if (c.plataforma === 'google' && c.refresh_token && (!c.expira_em || new Date(String(c.expira_em)).getTime() < Date.now() + 5 * 60000)) {
      const r = await googleRenova(String(c.refresh_token)); tk = r.access;
      await rpc(sb, 'conexao_token_atualizar', { p_conexao: c.id, p_access: r.access, p_expira: r.expira });
    }
    if (c.plataforma === 'meta' && c.expira_em && new Date(String(c.expira_em)).getTime() < Date.now()) throw new ErroPlataforma('Meta', 'o acesso expirou (token de 60 dias). Conecte de novo.');
    const { de, ate } = janela(Number(c.dias) || 30, c.ultima as string | null);
    det.periodo = { de, ate };
    for (const k of (c.contas as Dic[]) || []) {
      const conta = String(k.id_externo), cid = String(k.id);
      try {
        if (k.tipo === 'meta_ads') { const l = await metaAnuncios(tk, conta, de, ate); n += Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'ads', p_linhas: l })); det[String(k.nome)] = l.length + ' linhas de anúncio'; }
        else if (k.tipo === 'instagram') { const r = await metaInstagram(tk, conta, de, ate); avisos.push(...r.avisos);
          n += Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'perfil', p_linhas: r.perfil })) + Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'posts', p_linhas: r.posts }));
          det[String(k.nome)] = `${r.perfil.length} dias, ${r.posts.length} posts`; }
        else if (k.tipo === 'youtube') { const r = await youtubeCanal(tk, conta, ((k.extras as Dic) || {}).uploads as string | undefined, de, ate); avisos.push(...r.avisos);
          n += Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'perfil', p_linhas: r.perfil })) + Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'posts', p_linhas: r.posts }));
          const vv = await youtubeVideos(tk, conta, (c.videos as { fonte_id: string; video: string }[]) || [], de, ate); avisos.push(...vv.avisos);
          if (vv.linhas.length) n += Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'video', p_linhas: vv.linhas }));
          det[String(k.nome)] = `${r.perfil.length} dias, ${r.posts.length} vídeos, ${vv.linhas.length} dias de vídeos cadastrados`; }
        else if (k.tipo === 'google_ads') { const l = await googleAnuncios(tk, conta, de, ate); n += Number(await rpc(sb, 'conexao_gravar', { p_conta: cid, p_tipo: 'ads', p_linhas: l })); det[String(k.nome)] = l.length + ' linhas de anúncio'; }
      } catch (e) {
        if (e instanceof ErroPlataforma && (e.status === 401 || /token|oauth|expir|session/i.test(e.message))) throw e;  // acesso perdido: para tudo
        avisos.push(`${k.nome}: ${(e as Error).message}`);
      }
    }
    if (avisos.length) det.avisos = avisos.slice(0, 30);
    await rpc(sb, 'conexao_execucao', { p_conexao: c.id, p_id: ex, p_status: avisos.length ? 'parcial' : 'ok', p_registros: n, p_erro: avisos.length ? avisos[0].slice(0, 500) : null, p_detalhe: det, p_por: por });
    return { conexao: c.id, plataforma: c.plataforma, status: avisos.length ? 'parcial' : 'ok', registros: n, avisos };
  } catch (e) {
    await rpc(sb, 'conexao_execucao', { p_conexao: c.id, p_id: ex, p_status: 'erro', p_registros: n, p_erro: (e as Error).message.slice(0, 500), p_detalhe: det, p_por: por });
    return { conexao: c.id, plataforma: c.plataforma, status: 'erro', registros: n, erro: (e as Error).message };
  }
}

async function sincronizar(req: Request) {
  const b = await req.json().catch(() => ({})) as Dic, cron = req.headers.get('x-growths-cron');
  let ws: string | null = null, por = 'cron';
  if (cron) { if (!env('CONEXOES_CRON_SEGREDO') || cron !== env('CONEXOES_CRON_SEGREDO')) return json({ erro: 'Segredo do agendamento inválido' }, 401); }
  else {
    ws = String(b.ws || ''); if (!ws) return json({ erro: 'Informe o workspace' }, 400);
    if (!(await rpc(usuario(req), 'conexao_pode', { p_ws: ws }))) return json({ erro: 'Sem permissão para sincronizar' }, 403);
    por = 'usuario';
  }
  const sb = servico();
  const lista = await rpc(sb, 'conexao_para_sincronizar', { p_ws: ws, p_plataforma: b.plataforma || null }) as Dic[];
  const res = [];
  for (const c of lista || []) res.push(await sincronizaConexao(sb, c, por));
  return json({ conexoes: res });
}

async function desconectar(req: Request) {
  const b = await req.json().catch(() => ({})) as Dic;
  await rpc(usuario(req), 'conexao_desconectar', { p_ws: b.ws, p_plataforma: b.plataforma });
  return json({ ok: true });
}

async function atende(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const url = new URL(req.url), rota = url.pathname.replace(/\/+$/, '').split('/').pop();
  try {
    if (rota === 'retorno' && req.method === 'GET') return await retorno(url);
    if (req.method !== 'POST') return json({ erro: 'Use POST' }, 405);
    if (rota === 'iniciar') return await iniciar(req);
    if (rota === 'sincronizar') return await sincronizar(req);
    if (rota === 'desconectar') return await desconectar(req);
    return json({ erro: 'Rota desconhecida: use iniciar, retorno, sincronizar ou desconectar' }, 404);
  } catch (e) {
    return json({ erro: (e as Error).message }, e instanceof ErroPlataforma ? 502 : 400);
  }
}


// ===================== ENTRADA =====================
Deno.serve(atende);
