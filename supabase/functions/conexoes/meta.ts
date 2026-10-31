// Meta: login (Facebook Login), contas de anúncio, páginas e Instagram profissional; puxa anúncios e orgânico do Instagram.
// Segredos: META_APP_ID, META_APP_SECRET. Versão da API: META_API_VERSION (padrão v21.0).
import { type Dic, META_V, ErroPlataforma, env, num, pede, qs } from './util.ts';

export const META_ESCOPOS = ['ads_read', 'read_insights', 'pages_show_list', 'pages_read_engagement', 'instagram_basic', 'instagram_manage_insights', 'business_management'];
const G = () => `https://graph.facebook.com/${META_V()}`;

export function metaUrlLogin(redirect: string, state: string): string {
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

export async function metaTrocaCodigo(code: string, redirect: string) {
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

export async function metaAnuncios(tk: string, conta: string, de: string, ate: string): Promise<Dic[]> {
  const tags: Record<string, string> = {};
  const ads = await todas(`${G()}/${conta}/ads?` + qs({ fields: 'id,creative{url_tags}', limit: 500, access_token: tk })).catch(() => []);
  for (const a of ads) { const t = ((a.creative as Dic) || {}).url_tags; if (t) tags[String(a.id)] = String(t); }
  const linhas = await todas(`${G()}/${conta}/insights?` + qs({ level: 'ad', time_increment: 1, time_range: JSON.stringify({ since: de, until: ate }), limit: 500, access_token: tk,
    fields: 'date_start,campaign_id,campaign_name,adset_name,ad_id,ad_name,impressions,clicks,spend,reach,actions,action_values' }), 100);
  return linhas.map(l => ({ data: l.date_start, campanha_ext: l.campaign_id, campanha_nome: l.campaign_name, conjunto_nome: l.adset_name, anuncio_ext: l.ad_id, anuncio_nome: l.ad_name,
    url_tags: tags[String(l.ad_id)] || null, impressoes: num(l.impressions) || 0, cliques: num(l.clicks) || 0, custo: num(l.spend) || 0, alcance: num(l.reach),
    leads: acao(l.actions, LEAD) || null, conversoes: acao(l.actions, COMPRA) || null, receita: acao(l.action_values, COMPRA) || null }));
}

export async function metaInstagram(tk: string, ig: string, de: string, ate: string): Promise<{ perfil: Dic[]; posts: Dic[]; avisos: string[] }> {
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
