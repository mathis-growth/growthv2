// Edge function "content-drive": cria no Google Drive a pasta do cliente que usa o Growth's Content
// (dentro de "Mathisa Growth's Content"), com a árvore de subpastas cadastrada, e grava o link no cliente.
// Quem chama: o banco, quando o cliente é marcado (cabeçalho x-growths-token = sistema_config.content_drive_token),
// ou alguém da equipe interna logado (botão "Tentar de novo" e o teste da ligação).
// Quem cria a pasta de fato: o Google Apps Script da Rebecka (integracoes/apps-script/growths-drive.gs),
// cujo endereço e senha ficam em sistema_config (drive_script_url, drive_script_senha).
// Publicar SEM verificação de JWT: supabase functions deploy content-drive --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { lerArvore, lerResposta, montaPedido } from './logica.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-growths-token', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const env = (k: string) => Deno.env.get(k) || '';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const adm = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
  let ws = '';
  const falha = async (erro: string, status = 200) => {
    if (ws) await adm.from('workspaces').update({ content_drive_status: 'erro', content_drive_erro: erro.slice(0, 500), content_drive_em: new Date().toISOString() }).eq('id', ws);
    return json({ ok: false, erro }, status);
  };
  try {
    const corpo = await req.json().catch(() => ({}));
    const falhaSemWs = (erro: string) => { ws = /^[0-9a-f-]{36}$/i.test(String(corpo.workspace_id || '')) ? String(corpo.workspace_id) : ''; return falha(erro); };
    const cfgL = await adm.from('sistema_config').select('chave, valor').in('chave', ['content_drive_token', 'content_drive_raiz', 'content_drive_arvore', 'drive_script_url', 'drive_script_senha', 'drive_script_email']);
    const cfg = Object.fromEntries((cfgL.data || []).map((r: { chave: string; valor: string }) => [r.chave, r.valor]));
    // quem pode pedir: o banco (senha) ou alguém da equipe interna logado
    let ok = false;
    const tk = req.headers.get('x-growths-token') || '';
    if (tk && cfg.content_drive_token && tk === cfg.content_drive_token) ok = true;
    if (!ok) {
      const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
      if (jwt && jwt !== env('SUPABASE_ANON_KEY')) {
        const cli = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), { global: { headers: { Authorization: 'Bearer ' + jwt } } });
        const { data } = await cli.rpc('sou_equipe_interna');
        ok = data === true;
      }
    }
    if (!ok) return json({ ok: false, erro: 'Sem permissão' }, 401);
    if (!cfg.drive_script_url || !cfg.drive_script_senha) return await falhaSemWs('A ligação com o Google Drive ainda não foi feita (falta o endereço do Apps Script).');
    if (!cfg.content_drive_raiz) return await falhaSemWs('Falta a pasta "Mathisa Growth\'s Content" (content_drive_raiz).');


    if (corpo.acao === 'teste') {
      const r = await fetch(cfg.drive_script_url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(montaPedido({ senha: cfg.drive_script_senha, raiz: cfg.content_drive_raiz, nome: 'teste', arvore: [], acao: 'teste' })) });
      const t = await r.text(); let j: any = null; try { j = JSON.parse(t); } catch { /* não é JSON */ }
      if (j && j.ok) return json({ ok: true, raiz: j.raiz });
      const lr = lerResposta(r.status, t);
      return json({ ok: false, erro: j?.erro || (lr.ok ? 'Resposta inesperada' : lr.erro) });
    }

    ws = String(corpo.workspace_id || '');
    if (!/^[0-9a-f-]{36}$/i.test(ws)) { ws = ''; return json({ ok: false, erro: 'Cliente inválido' }, 400); }
    const { data: w, error } = await adm.from('workspaces').select('id, nome, content_ativo, content_drive_id, content_drive_modo').eq('id', ws).maybeSingle();
    if (error || !w) { ws = ''; return json({ ok: false, erro: 'Cliente não encontrado' }, 404); }
    if (!w.content_ativo) return await falha('O cliente não está marcado como usuário do Growth\'s Content.');

    const pedido = montaPedido({ senha: cfg.drive_script_senha, raiz: cfg.content_drive_raiz, nome: w.nome, arvore: lerArvore(cfg.content_drive_arvore), pastaId: w.content_drive_id });
    const r = await fetch(cfg.drive_script_url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(pedido) });
    const res = lerResposta(r.status, await r.text());
    if (!res.ok) {
      // pasta do cliente que ainda não foi compartilhada com a Mathisa (ou link errado)
      if (w.content_drive_modo === 'compartilhada' && /permission|permiss|not found|No item|não foi possível encontrar|Access denied|acesso/i.test(res.erro))
        return await falha(`A Mathisa ainda não tem acesso a essa pasta. No Google Drive do cliente, clique com o botão direito na pasta → Compartilhar → adicione ${cfg.drive_script_email || 'o e-mail da Mathisa'} como Editor. Depois clique em "Verificar de novo".`);
      return await falha(res.erro);
    }
    await adm.from('workspaces').update({ content_drive_id: res.id, content_drive_url: res.url, content_drive_status: 'ok', content_drive_erro: null, content_drive_em: new Date().toISOString() }).eq('id', ws);
    return json({ ok: true, id: res.id, url: res.url });
  } catch (e) {
    return await falha('Erro na função de pastas: ' + String((e as Error)?.message || e));
  }
});
