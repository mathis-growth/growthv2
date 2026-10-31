// Teste da edge function "conexoes" (v0.120) contra o Postgres local, com as APIs do Meta e do Google simuladas (fetch falso).
// Banco: fa (auditoria) com as migrações 20261022100000 e 20261022200000.
//   PGDB=fa deno run --allow-all --import-map=tests/edge/import_map_papeis.json tests/edge/conexoes_teste.ts
import { atende } from '../../supabase/functions/conexoes/rotas.ts';
import { metaUrlLogin, META_ESCOPOS } from '../../supabase/functions/conexoes/meta.ts';

const WS = 'ac56e719-7325-4062-aa47-74bc2141f89d', UID = '00000000-0000-0000-0000-00000000a0a0';
let falhas = 0;
const ok = (c: boolean, m: string, x?: unknown) => { console.log((c ? 'ok   ' : 'FALHA ') + m + (c ? '' : ' → ' + String(JSON.stringify(x)).slice(0, 400))); if (!c) falhas++; };
async function sql(q: string): Promise<string> {
  const p = new Deno.Command('psql', { args: ['-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', Deno.env.get('PGDB') || 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], stdout: 'piped', stderr: 'piped' });
  const o = await p.output(); if (!o.success) throw new Error(new TextDecoder().decode(o.stderr)); return new TextDecoder().decode(o.stdout).trim();
}
for (const [k, v] of Object.entries({ SUPABASE_URL: 'https://proj.supabase.co', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'service', META_APP_ID: 'app1', META_APP_SECRET: 'seg1',
  GOOGLE_CLIENT_ID: 'gid', GOOGLE_CLIENT_SECRET: 'gseg', GOOGLE_ADS_DEVELOPER_TOKEN: 'dev1', CONEXOES_CRON_SEGREDO: 'cron123', APP_URL: 'https://app.growths.test' })) Deno.env.set(k, v);

// ---------- APIs falsas ----------
const chamadas: string[] = []; let metaQuebrado = false, googleRenovou = 0;
const J = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { 'content-type': 'application/json' } });
const hoje = new Date().toISOString().slice(0, 10), ontem = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
globalThis.fetch = (async (inp: string | URL | Request, init?: RequestInit) => {
  const u = new URL(typeof inp === 'string' ? inp : inp instanceof URL ? inp.href : inp.url); chamadas.push(u.hostname + u.pathname);
  const p = u.pathname;
  if (u.hostname === 'graph.facebook.com') {
    if (metaQuebrado && p.includes('/insights')) return J({ error: { message: 'Error validating access token: Session has expired', type: 'OAuthException', code: 190 } }, 401);
    if (p.endsWith('/oauth/access_token')) return J(u.searchParams.get('grant_type') === 'fb_exchange_token' ? { access_token: 'META_LONGO', expires_in: 5184000 } : { access_token: 'META_CURTO' });
    if (p.endsWith('/me/permissions')) return J({ data: [{ permission: 'ads_read', status: 'granted' }, { permission: 'instagram_basic', status: 'granted' }] });
    if (p.endsWith('/me/adaccounts')) return J({ data: [{ id: 'act_111', name: 'Conta Escola', currency: 'BRL', account_status: 1 }] });
    if (p.endsWith('/me/accounts')) return J({ data: [{ id: 'pg1', name: 'Página Escola', instagram_business_account: { id: 'ig1', username: 'escola' } }] });
    if (p.endsWith('/me')) return J({ id: 'u1', name: 'Rebecka Teste' });
    if (p.endsWith('/act_111/ads')) return J({ data: [{ id: 'ad1', creative: { url_tags: 'utm_source=meta&utm_campaign=perpetuo-meta&utm_content=ad-teste-1' } }] });
    if (p.endsWith('/act_111/insights')) {
      const pg2 = u.searchParams.get('after') === 'c2';
      if (u.searchParams.get('access_token') !== 'META_LONGO') return J({ error: { message: 'token errado' } }, 400);
      if (!pg2) return J({ data: [
        { date_start: ontem, campaign_id: 'cmp1', campaign_name: 'Perpetuo Meta (FB)', adset_name: 'Conj A', ad_id: 'ad1', ad_name: 'Criativo 1', impressions: '1000', clicks: '40', spend: '55.50', reach: '800', actions: [{ action_type: 'lead', value: '5' }] },
        { date_start: ontem, campaign_id: 'cmp2', campaign_name: 'Campanha sem vínculo', adset_name: 'Conj B', ad_id: 'ad2', ad_name: 'Criativo 2', impressions: '500', clicks: '10', spend: '20', reach: '400' }],
        paging: { next: `https://graph.facebook.com/v21.0/act_111/insights?after=c2&access_token=META_LONGO` } });
      return J({ data: [{ date_start: hoje, campaign_id: 'cmp1', campaign_name: 'Perpetuo Meta (FB)', adset_name: 'Conj A', ad_id: 'ad1', ad_name: 'Criativo 1', impressions: '700', clicks: '21', spend: '30.25', reach: '600',
        actions: [{ action_type: 'purchase', value: '1' }], action_values: [{ action_type: 'purchase', value: '997' }] }] });
    }
    if (p.endsWith('/ig1/insights')) { const m = u.searchParams.get('metric');
      if (m === 'reach') return J({ data: [{ name: m, values: [{ value: 1200, end_time: ontem + 'T07:00:00+0000' }, { value: 1500, end_time: hoje + 'T07:00:00+0000' }] }] });
      if (u.searchParams.get('metric_type') !== 'total_value') return J({ error: { message: 'metric_type obrigatório' } }, 400);
      return J({ data: [{ name: 'views', total_value: { value: 100 } }, { name: 'profile_links_taps', total_value: { value: 3 } }] }); }
    if (p.endsWith('/ig1/media')) return J({ data: [{ id: 'm1', caption: 'Post 1', media_type: 'IMAGE', media_product_type: 'FEED', permalink: 'https://instagram.com/p/1', timestamp: ontem + 'T12:00:00+0000', like_count: 50, comments_count: 4 },
      { id: 'm2', caption: 'Reel', media_type: 'VIDEO', media_product_type: 'REELS', permalink: 'https://instagram.com/reel/2', timestamp: hoje + 'T12:00:00+0000', like_count: 90, comments_count: 8 }] });
    if (p.endsWith('/m1/insights')) return J({ data: [{ name: 'reach', values: [{ value: 700 }] }, { name: 'saved', values: [{ value: 12 }] }, { name: 'shares', values: [{ value: 3 }] }, { name: 'views', values: [{ value: 900 }] }] });
    if (p.endsWith('/m2/insights')) return u.searchParams.get('metric')!.includes('views') ? J({ error: { message: 'metric views not supported' } }, 400) : J({ data: [{ name: 'reach', values: [{ value: 2000 }] }, { name: 'saved', values: [{ value: 30 }] }] });
    if (p.endsWith('/ig1')) return J({ followers_count: 4321, media_count: 2 });
  }
  if (u.hostname === 'oauth2.googleapis.com') { const b = new URLSearchParams(String(init?.body || ''));
    if (b.get('grant_type') === 'refresh_token') { googleRenovou++; return J({ access_token: 'G_NOVO', expires_in: 3600 }); }
    return J({ access_token: 'G_VELHO', refresh_token: 'G_REFRESH', expires_in: -10, scope: 'openid email https://www.googleapis.com/auth/youtube.readonly' }); }
  if (u.hostname === 'openidconnect.googleapis.com') return J({ email: 'rebecka@escola.test' });
  if (u.hostname === 'www.googleapis.com' && p.endsWith('/channels')) return u.searchParams.get('mine') ? J({ items: [{ id: 'UC1', snippet: { title: 'Canal Escola' }, contentDetails: { relatedPlaylists: { uploads: 'UU1' } } }] }) : J({ items: [{ statistics: { subscriberCount: '980' } }] });
  if (u.hostname === 'www.googleapis.com' && p.endsWith('/playlistItems')) return J({ items: [{ contentDetails: { videoId: 'vid00000001' } }] });
  if (u.hostname === 'www.googleapis.com' && p.endsWith('/videos')) return J({ items: [{ id: 'vid00000001', snippet: { title: 'Aula 1', publishedAt: ontem + 'T10:00:00Z', thumbnails: { medium: { url: 'https://i.ytimg.com/x.jpg' } } }, statistics: { viewCount: '321', likeCount: '20', commentCount: '2' } }] });
  if (u.hostname === 'youtubeanalytics.googleapis.com') {
    if ((init?.headers as Record<string, string>)?.Authorization !== 'Bearer G_NOVO') return J({ error: { message: 'Invalid Credentials', status: 'UNAUTHENTICATED' } }, 401);
    if (u.searchParams.get('filters')) return J({ columnHeaders: [{ name: 'day' }, { name: 'views' }, { name: 'estimatedMinutesWatched' }, { name: 'averageViewPercentage' }], rows: [[ontem, 150, 600, 42.5], [hoje, 80, 300, 40]] });
    return J({ columnHeaders: [{ name: 'day' }, { name: 'views' }, { name: 'estimatedMinutesWatched' }, { name: 'subscribersGained' }, { name: 'subscribersLost' }], rows: [[ontem, 400, 1200, 10, 2], [hoje, 300, 900, 5, 1]] });
  }
  if (u.hostname === 'googleads.googleapis.com' && p.endsWith(':listAccessibleCustomers')) return J({ resourceNames: ['customers/1234567890'] });
  if (u.hostname === 'googleads.googleapis.com' && p.endsWith(':searchStream')) return J([{ results: [{ segments: { date: ontem }, campaign: { id: '777', name: 'lanc-set-google' }, adGroup: { name: 'Grupo 1' },
    adGroupAd: { ad: { id: '9001', name: 'Anúncio pesquisa', finalUrls: ['https://escola.com/?utm_source=google&utm_content=pesq-1'] } }, metrics: { impressions: '300', clicks: '25', costMicros: '45670000', conversions: 2, conversionsValue: 0 } }] }]);
  return J({ error: { message: 'rota não simulada: ' + u.href } }, 404);
}) as typeof fetch;

const req = (rota: string, corpo?: unknown, h: Record<string, string> = { Authorization: 'Bearer uid:' + UID }) =>
  atende(new Request('https://proj.supabase.co/functions/v1/conexoes/' + rota, corpo === undefined ? { method: 'GET', headers: h } : { method: 'POST', headers: { ...h, 'content-type': 'application/json' }, body: JSON.stringify(corpo) }));

// ---------- preparo e limpeza ----------
const limpa = async () => { await sql(`delete from conexoes where workspace_id = '${WS}'; delete from ads_externo_vinculos where workspace_id = '${WS}';
  delete from metricas_anuncio_dia where anuncio_id in (select id from anuncios where workspace_id = '${WS}' and id_externo in ('ad1','ad2','9001'));
  delete from anuncios where workspace_id = '${WS}' and id_externo in ('ad1','ad2','9001'); delete from fontes_video where workspace_id = '${WS}' and nome = 'Teste conexões';
  delete from integracoes where workspace_id = '${WS}' and provedor in ('Meta Ads','Instagram','Google Ads','YouTube');`); };
await limpa();
const FONTE = await sql(`insert into fontes_video (workspace_id, nome, tipo, plataforma, id_externo, ativo) values ('${WS}', 'Teste conexões', 'aula', 'youtube', 'https://youtu.be/vid00000001', true) returning id`);

// Facebook Login for Business: respeita a configuração opcional sem reduzir escopos.
Deno.env.set('META_LOGIN_CONFIG_ID', '123456789012');
const loginBusiness = new URL(metaUrlLogin('https://proj.supabase.co/functions/v1/conexoes/retorno', 'estado-test'));
ok(loginBusiness.searchParams.get('config_id') === '123456789012', 'Meta: configuração Business Login ativa');
ok(META_ESCOPOS.every(scope => (loginBusiness.searchParams.get('scope') || '').split(',').includes(scope)),
  'Meta: escopos de anúncios, páginas e Instagram preservados');
Deno.env.delete('META_LOGIN_CONFIG_ID');
const loginClassico = new URL(metaUrlLogin('https://proj.supabase.co/functions/v1/conexoes/retorno', 'estado-test'));
ok(!loginClassico.searchParams.has('config_id'), 'Meta: login clássico permanece sem configuração Business');

// ---------- Meta ----------
let r = await req('iniciar', { ws: WS, plataforma: 'meta', volta: 'https://app.growths.test/#cfg-integracoes' });
let j = await r.json();
ok(r.status === 200 && String(j.url).startsWith('https://www.facebook.com/v21.0/dialog/oauth?') && j.url.includes('scope=ads_read') && j.url.includes(encodeURIComponent('https://proj.supabase.co/functions/v1/conexoes/retorno')), 'iniciar Meta: url de login com escopos e retorno', j);
const st = new URL(j.url).searchParams.get('state')!;
r = await req('iniciar', { ws: WS, plataforma: 'meta' }, { Authorization: 'Bearer uid:00000000-0000-0000-0000-000000000001' });
ok(r.status === 400 && /Configurações/.test((await r.json()).erro), 'quem não edita Configurações não conecta');
r = await req('retorno?code=abc&state=' + st);
ok(r.status === 302 && r.headers.get('location')!.includes('conexao=ok') && r.headers.get('location')!.startsWith('https://app.growths.test/'), 'retorno Meta: volta para o Growths com conexao=ok', r.headers.get('location'));
ok(await sql(`select status || '|' || conta_nome || '|' || array_length(escopos,1) from conexoes where workspace_id='${WS}' and plataforma='meta'`) === 'conectado|Rebecka Teste|2', 'conexão Meta gravada');
ok(await sql(`select string_agg(tipo || ':' || id_externo, ',' order by tipo) from conexao_contas k join conexoes c on c.id = k.conexao_id where c.workspace_id='${WS}' and c.plataforma='meta'`) === 'facebook_pagina:pg1,instagram:ig1,meta_ads:act_111', 'contas Meta: anúncios, página e Instagram');
ok(await sql(`select access_token from privado.conexao_tokens t join conexoes c on c.id = t.conexao_id where c.workspace_id='${WS}' and c.plataforma='meta'`) === 'META_LONGO', 'token de longa duração guardado no schema privado');
ok(await sql(`select string_agg(provedor || ':' || status, ',' order by provedor) from integracoes where workspace_id='${WS}' and provedor in ('Meta Ads','Instagram')`) === 'Instagram:conectado,Meta Ads:conectado', 'Integrações: Meta Ads e Instagram como conectados');
r = await req('retorno?code=abc&state=' + st);
ok(r.headers.get('location')!.includes('conexao=erro'), 'o mesmo retorno não vale duas vezes');
const priv = await sql(`set role authenticated; select count(*) from privado.conexao_tokens`).catch(e => String(e));
ok(/permission denied/.test(priv), 'navegador não lê os tokens', priv);
r = await req('sincronizar', { ws: WS, plataforma: 'meta' });
j = await r.json();
ok(r.status === 200 && j.conexoes.length === 1 && j.conexoes[0].status === 'ok' && j.conexoes[0].registros > 0, 'sincronizar Meta: ok', j);
ok(await sql(`select count(*) || '|' || sum(custo) from ads_externo_dia where workspace_id='${WS}' and provedor='meta_ads'`) === '3|105.75', 'anúncios: 3 linhas (com a 2ª página), custo somado');
ok(await sql(`select coalesce((select c.utm_campaign from ads_externo_vinculos v join campanha_canais c on c.id = v.campanha_canal_id where v.workspace_id='${WS}' and v.campanha_ext='cmp1'), 'sem') || '|' || (select count(*) from ads_externo_vinculos where workspace_id='${WS}' and campanha_ext='cmp2' and campanha_canal_id is null)`) === 'perpetuo-meta|1', 'campanha ligada pelo utm_campaign das url_tags; a outra fica sem vínculo');
ok(await sql(`select a.utm_content || '|' || sum(m.custo) || '|' || min(m.origem) from anuncios a join metricas_anuncio_dia m on m.anuncio_id = a.id where a.workspace_id='${WS}' and a.id_externo='ad1' group by a.utm_content`) === 'ad-teste-1|85.75|integracao', 'anúncio criado no canal (utm_content da url_tags) e métricas diárias gravadas');
ok(await sql(`select max(seguidores) || '|' || sum(alcance) || '|' || (select visualizacoes || ':' || cliques_site from social_perfis_dia x where x.conta_id = k.id and x.data = current_date - 1) from social_perfis_dia p join conexao_contas k on k.id = p.conta_id where k.tipo='instagram' and p.workspace_id='${WS}' group by k.id`) === '4321|2700|100:3', 'Instagram: seguidores, alcance por dia e visualizações/cliques no link dia a dia');
ok(await sql(`select string_agg(id_externo || ':' || coalesce(alcance,0) || ':' || coalesce(visualizacoes,0) || ':' || tipo, ',' order by id_externo) from social_posts where workspace_id='${WS}'`) === 'm1:700:900:feed,m2:2000:0:reels', 'Instagram: posts com métricas (o que não aceita "views" usa menos métricas)');
ok(await sql(`select e.status || '|' || e.registros from conexao_execucoes e join conexoes c on c.id = e.conexao_id where c.workspace_id='${WS}' and c.plataforma='meta' order by e.iniciado_em desc limit 1`) === 'ok|' + j.conexoes[0].registros, 'execução registrada');
// liga a campanha sem vínculo a um canal pela tela e reaplica
await sql(`update ads_externo_vinculos set campanha_canal_id = 'c0195398-3c77-48d5-9621-4f6dae2180e8' where workspace_id='${WS}' and campanha_ext='cmp2'`);
ok(await sql(`set role authenticated; select set_config('request.jwt.claims','{"sub":"${UID}","role":"authenticated"}',false); select ads_externo_religar('${WS}')->>'campanhas_sem_vinculo'`).then(x => x.split('\n').pop()) === '0', 'vínculo manual: reaplica e não sobra campanha sem canal');

// ---------- Google ----------
r = await req('iniciar', { ws: WS, plataforma: 'google', volta: 'https://app.growths.test/?x=1#cfg-integracoes' });
j = await r.json();
ok(String(j.url).startsWith('https://accounts.google.com/o/oauth2/v2/auth?') && j.url.includes('access_type=offline') && j.url.includes('yt-analytics.readonly'), 'iniciar Google: offline + escopos do YouTube', j);
r = await req('retorno?code=g&state=' + new URL(j.url).searchParams.get('state'));
ok(r.headers.get('location')!.includes('conexao=ok') && r.headers.get('location')!.includes('x=1'), 'retorno Google ok (mantém a query da volta)', r.headers.get('location'));
ok(await sql(`select string_agg(tipo || ':' || id_externo, ',' order by tipo) from conexao_contas k join conexoes c on c.id = k.conexao_id where c.workspace_id='${WS}' and c.plataforma='google'`) === 'google_ads:1234567890,youtube:UC1', 'contas Google: Google Ads e YouTube');
r = await req('sincronizar', { ws: WS, plataforma: 'google' });
j = await r.json();
ok(j.conexoes[0].status === 'ok' && googleRenovou === 1, 'token vencido é renovado antes de puxar (refresh_token)', j);
ok(await sql(`select access_token from privado.conexao_tokens t join conexoes c on c.id = t.conexao_id where c.workspace_id='${WS}' and c.plataforma='google'`) === 'G_NOVO', 'token novo guardado');
ok(await sql(`select sum(visualizacoes) || '|' || max(seguidores) || '|' || sum(seguidores_ganhos) from social_perfis_dia p join conexao_contas k on k.id = p.conta_id where k.tipo='youtube' and p.workspace_id='${WS}'`) === '700|980|12', 'YouTube: visualizações, inscritos e ganho líquido por dia');
ok(await sql(`select sum(plays) || '|' || sum(tempo_assistido_seg) || '|' || max(retencao_pct)::float from video_metricas_dia where fonte_id = '${FONTE}'`) === '230|54000|42.5', 'YouTube: vídeo cadastrado em Vídeos e webinários recebe métricas diárias');
ok(await sql(`select a.utm_content || '|' || sum(m.custo) from anuncios a join metricas_anuncio_dia m on m.anuncio_id = a.id where a.workspace_id='${WS}' and a.id_externo='9001' group by a.utm_content`) === 'pesq-1|45.67', 'Google Ads: custo em micros convertido e ligado ao canal pelo nome da campanha');

// ---------- agendamento e erros ----------
r = await req('sincronizar', {}, { 'x-growths-cron': 'errado' });
ok(r.status === 401, 'agendamento com segredo errado é recusado');
metaQuebrado = true;
r = await req('sincronizar', {}, { 'x-growths-cron': 'cron123' });
j = await r.json();
const m = j.conexoes.find((c: { plataforma: string }) => c.plataforma === 'meta'), g = j.conexoes.find((c: { plataforma: string }) => c.plataforma === 'google');
ok(m && m.status === 'erro' && g && g.status === 'ok', 'agendamento roda todas; Meta com token vencido dá erro e o Google segue', j);
ok(await sql(`select status from conexoes where workspace_id='${WS}' and plataforma='meta'`) === 'expirada', 'token vencido marca a conexão como expirada (pede para conectar de novo)');
r = await req('desconectar', { ws: WS, plataforma: 'meta' });
ok(r.status === 200 && await sql(`select c.status || '|' || (select count(*) from privado.conexao_tokens where conexao_id = c.id) from conexoes c where workspace_id='${WS}' and plataforma='meta'`) === 'desconectado|0', 'desconectar apaga o token');

await limpa();
console.log(`\n${falhas} falha(s)`);
Deno.exit(falhas ? 1 : 0);
