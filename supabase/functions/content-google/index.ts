// Edge function "content-google": conecta o Google Drive do PRÓPRIO cliente ao Growth's Content e cria lá a pasta
// "Growth's Content — <cliente>" com a árvore de subpastas (sistema_config.content_drive_arvore).
// Escopo pedido ao Google: drive.file (o Growths só enxerga o que ele mesmo criou no Drive do cliente).
//   POST {acao:'iniciar', workspace_id, voltar}  (logado, quem pode configurar o cliente) → { url } do login do Google
//   GET  ?code&state                              (o Google volta aqui) → troca o código, cria as pastas, volta para o Growths
//   POST {acao:'refazer', workspace_id}           (logado) → recria/completa as pastas com a conta já conectada
//   POST {acao:'desconectar', workspace_id}       (logado) → esquece a conta (a pasta continua no Drive do cliente)
// Segredos: GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET (ID do cliente OAuth "Aplicativo da Web"; URI de redirecionamento = endereço desta função).
// Publicar SEM verificação de JWT: supabase functions deploy content-google --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { caminhos, escQ, nomeRaiz, urlLogin, voltarPara } from './logica.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const env = (k: string) => Deno.env.get(k) || '';
const REDIRECT = () => env('SUPABASE_URL').replace(/\/$/, '') + '/functions/v1/content-google';
const PASTA = 'application/vnd.google-apps.folder';
const adm = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));

async function token(form: Record<string, string>) {
  const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(form) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error('Google recusou o acesso: ' + (j.error_description || j.error || r.status));
  return j as { access_token: string; refresh_token?: string; scope?: string };
}
async function drive(at: string, path: string, init: RequestInit = {}) {
  const r = await fetch('https://www.googleapis.com/drive/v3/' + path, { ...init, headers: { Authorization: 'Bearer ' + at, 'Content-Type': 'application/json', ...(init.headers || {}) } });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error('Google Drive: ' + (j?.error?.message || r.status));
  return j;
}
// pasta com esse nome dentro do pai (das que o Growths criou), ou cria
async function pasta(at: string, nome: string, pai: string | null) {
  const q = `mimeType='${PASTA}' and trashed=false and name='${escQ(nome)}'` + (pai ? ` and '${escQ(pai)}' in parents` : ` and 'root' in parents`);
  const l = await drive(at, 'files?fields=files(id,webViewLink)&q=' + encodeURIComponent(q));
  if (l.files && l.files.length) return l.files[0] as { id: string; webViewLink: string };
  return await drive(at, 'files?fields=id,webViewLink', { method: 'POST', body: JSON.stringify({ name: nome, mimeType: PASTA, ...(pai ? { parents: [pai] } : {}) }) }) as { id: string; webViewLink: string };
}
async function criaPastas(ws: string, at: string) {
  const { data: w } = await adm.from('workspaces').select('nome, content_drive_id, content_drive_modo').eq('id', ws).single();
  const { data: cfg } = await adm.from('sistema_config').select('valor').eq('chave', 'content_drive_arvore').maybeSingle();
  let raiz: { id: string; webViewLink: string } | null = null;
  if (w?.content_drive_modo === 'cliente' && w.content_drive_id) {
    try { const j = await drive(at, `files/${encodeURIComponent(w.content_drive_id)}?fields=id,webViewLink,trashed`); if (!j.trashed) raiz = j; } catch { /* apagada ou de outra conta: cria de novo */ }
  }
  if (!raiz) raiz = await pasta(at, nomeRaiz(w?.nome || 'cliente'), null);
  let arv: string[] = []; try { arv = JSON.parse(cfg?.valor || '[]'); } catch { /* */ }
  for (const cam of caminhos(arv)) { let pai = raiz.id; for (const n of cam) pai = (await pasta(at, n, pai)).id; }
  return raiz;
}
async function marcaErro(ws: string, erro: string) {
  await adm.from('workspaces').update({ content_drive_status: 'erro', content_drive_erro: erro.slice(0, 500), content_drive_em: new Date().toISOString() }).eq('id', ws);
}
async function podeConfigurar(req: Request, ws: string) {
  const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!jwt || jwt === env('SUPABASE_ANON_KEY')) return null;
  const cli = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { global: { headers: { Authorization: 'Bearer ' + jwt } } });
  const [{ data: pode }, { data: eu }] = await Promise.all([cli.rpc('content_pode_configurar', { p_ws: ws }), cli.auth.getUser(jwt)]);
  return pode === true ? (eu?.user?.id || 'ok') : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const u = new URL(req.url);
  // ---------- o Google volta aqui ----------
  if (req.method === 'GET' && (u.searchParams.get('state') || u.searchParams.get('error'))) {
    const estado = u.searchParams.get('state') || '';
    const { data: e } = await adm.from('content_google_estados').select('*').eq('estado', estado).maybeSingle();
    if (e) await adm.from('content_google_estados').delete().eq('estado', estado);
    const volta = (p: Record<string, string>) => {
      const dest = voltarPara(e?.voltar, p);
      return dest ? new Response(null, { status: 302, headers: { Location: dest } }) : new Response(p.google === 'ok' ? 'Google Drive conectado. Pode fechar esta aba e voltar ao Growths.' : 'Não deu certo: ' + (p.erro || ''), { status: 200, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
    };
    if (!e || Date.now() - new Date(e.criado_em).getTime() > 15 * 60 * 1000) return volta({ google: 'erro', erro: 'O pedido de conexão expirou. Tente de novo.' });
    if (u.searchParams.get('error')) return volta({ google: 'erro', erro: u.searchParams.get('error') === 'access_denied' ? 'Você não autorizou o acesso ao Google Drive.' : 'O Google não completou a conexão.' });
    try {
      const t = await token({ code: u.searchParams.get('code') || '', client_id: env('GOOGLE_CLIENT_ID'), client_secret: env('GOOGLE_CLIENT_SECRET'), redirect_uri: REDIRECT(), grant_type: 'authorization_code' });
      if (!(t.scope || '').includes('drive.file')) throw new Error('Marque a permissão do Google Drive na tela do Google.');
      const ui = await fetch('https://openidconnect.googleapis.com/v1/userinfo', { headers: { Authorization: 'Bearer ' + t.access_token } }).then((r) => r.json()).catch(() => ({}));
      const { data: antes } = await adm.from('content_google').select('refresh_token').eq('workspace_id', e.workspace_id).maybeSingle();
      const refresh = t.refresh_token || antes?.refresh_token;
      if (!refresh) throw new Error('O Google não liberou o acesso contínuo. Tente de novo.');
      await adm.from('content_google').upsert({ workspace_id: e.workspace_id, email: ui.email || null, refresh_token: refresh, escopos: t.scope || null, conectado_por: e.user_id, conectado_em: new Date().toISOString() });
      await adm.from('workspaces').update({ content_ativo: true, content_drive_modo: 'cliente', content_drive_email: ui.email || null, content_drive_status: 'criando', content_drive_erro: null }).eq('id', e.workspace_id);
      const r = await criaPastas(e.workspace_id, t.access_token);
      await adm.from('workspaces').update({ content_drive_id: r.id, content_drive_url: r.webViewLink, content_drive_status: 'ok', content_drive_erro: null, content_drive_em: new Date().toISOString() }).eq('id', e.workspace_id);
      return volta({ google: 'ok' });
    } catch (err) {
      const msg = String((err as Error)?.message || err);
      await marcaErro(e.workspace_id, msg);
      return volta({ google: 'erro', erro: msg });
    }
  }
  // ---------- pedidos da tela ----------
  try {
    const corpo = await req.json().catch(() => ({}));
    const ws = String(corpo.workspace_id || '');
    if (!/^[0-9a-f-]{36}$/i.test(ws)) return json({ ok: false, erro: 'Cliente inválido' }, 400);
    const quem = await podeConfigurar(req, ws);
    if (!quem) return json({ ok: false, erro: 'Sem permissão para configurar este cliente' }, 401);
    if (corpo.acao === 'iniciar') {
      if (!env('GOOGLE_CLIENT_ID') || !env('GOOGLE_CLIENT_SECRET')) return json({ ok: false, erro: 'A conexão com o Google ainda não foi ligada no servidor (faltam GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET).' });
      const estado = crypto.randomUUID().replace(/-/g, '') + crypto.randomUUID().replace(/-/g, '');
      await adm.from('content_google_estados').delete().lt('criado_em', new Date(Date.now() - 60 * 60 * 1000).toISOString());
      await adm.from('content_google_estados').insert({ estado, workspace_id: ws, user_id: quem === 'ok' ? null : quem, voltar: voltarPara(corpo.voltar, {}) });
      return json({ ok: true, url: urlLogin({ clientId: env('GOOGLE_CLIENT_ID'), redirect: REDIRECT(), estado, email: corpo.email || undefined }) });
    }
    if (corpo.acao === 'refazer') {
      const { data: g } = await adm.from('content_google').select('refresh_token').eq('workspace_id', ws).maybeSingle();
      if (!g) return json({ ok: false, erro: 'Nenhuma conta Google conectada a este cliente.' });
      try {
        const t = await token({ refresh_token: g.refresh_token, client_id: env('GOOGLE_CLIENT_ID'), client_secret: env('GOOGLE_CLIENT_SECRET'), grant_type: 'refresh_token' });
        const r = await criaPastas(ws, t.access_token);
        await adm.from('workspaces').update({ content_ativo: true, content_drive_modo: 'cliente', content_drive_id: r.id, content_drive_url: r.webViewLink, content_drive_status: 'ok', content_drive_erro: null, content_drive_em: new Date().toISOString() }).eq('id', ws);
        return json({ ok: true, url: r.webViewLink });
      } catch (err) { const msg = String((err as Error)?.message || err); await marcaErro(ws, msg); return json({ ok: false, erro: msg }); }
    }
    if (corpo.acao === 'desconectar') {
      const { data: g } = await adm.from('content_google').select('refresh_token').eq('workspace_id', ws).maybeSingle();
      if (g) await fetch('https://oauth2.googleapis.com/revoke?token=' + encodeURIComponent(g.refresh_token), { method: 'POST' }).catch(() => null);
      await adm.from('content_google').delete().eq('workspace_id', ws);
      await adm.from('workspaces').update({ content_drive_email: null, content_drive_status: null, content_drive_erro: null, content_drive_id: null, content_drive_url: null, content_drive_modo: null }).eq('id', ws).eq('content_drive_modo', 'cliente');
      return json({ ok: true });
    }
    return json({ ok: false, erro: 'Ação desconhecida' }, 400);
  } catch (err) {
    return json({ ok: false, erro: 'Erro na conexão com o Google: ' + String((err as Error)?.message || err) }, 500);
  }
});
