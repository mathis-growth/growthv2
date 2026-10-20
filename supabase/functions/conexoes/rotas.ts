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
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { type Dic, ErroPlataforma, env, janela } from './util.ts';
import { metaAnuncios, metaInstagram, metaTrocaCodigo, metaUrlLogin } from './meta.ts';
import { googleAnuncios, googleRenova, googleTrocaCodigo, googleUrlLogin, youtubeCanal, youtubeVideos } from './google.ts';

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

export async function atende(req: Request): Promise<Response> {
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
