// Edge function "vendas-plataforma": recebe os webhooks de venda de Kiwify, Eduzz e Hubla e grava o evento inteiro na tabela bruta da plataforma.
// Endereço: https://<projeto>.supabase.co/functions/v1/vendas-plataforma?p=kiwify&chave=gw_...
//   A chave é gerada em Integrações → Plataformas de venda. O tratamento em vendas e clientes é feito no banco.
// Autenticação: Kiwify, HMAC-SHA1 no parâmetro signature; Eduzz, HMAC-SHA256 em x-signature; Hubla, token fixo em x-hubla-token.
// Publicar SEM verificação de JWT: supabase functions deploy vendas-plataforma --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { confereEduzz, confereKiwify } from './assina.ts';

const RE_CHAVE = /^gw_[0-9a-f]{64}$/;
const LIMITE = 1024 * 1024;
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { 'Content-Type': 'application/json; charset=utf-8' } });

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const prov = url.searchParams.get('p') || '', chave = (url.searchParams.get('chave') || '').trim();
  if (!['kiwify', 'eduzz', 'hubla'].includes(prov)) return json({ ok: false, erro: 'Plataforma inválida' }, 400);
  if (!RE_CHAVE.test(chave)) return json({ ok: false, erro: 'Chave ausente ou em formato errado' }, 401);
  if (req.method === 'GET') return json({ ok: true, mensagem: 'Endereço pronto. A plataforma envia os eventos por POST.' });
  if (req.method !== 'POST') return json({ ok: false, erro: 'Use POST' }, 405);
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.length > LIMITE) return json({ ok: false, erro: 'Evento grande demais' }, 413);
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const negado = () => json({ ok: false, erro: 'Chave ou assinatura inválida' }, 401);

  if (prov !== 'hubla') {
    const { data: segredo, error } = await sb.rpc('plataforma_webhook_segredo', { p_chave: chave, p_prov: prov });
    if (error) { if (error.code === '28000') return negado(); console.error('segredo', error.message); return json({ ok: false, erro: 'Falha ao conferir o evento' }, 500); }
    const certo = prov === 'kiwify' ? await confereKiwify(segredo || '', bytes, url.searchParams.get('signature') || '') : await confereEduzz(segredo || '', bytes, req.headers.get('x-signature') || '');
    if (!certo) return negado();
  }
  let corpo: Record<string, unknown>;
  try { corpo = JSON.parse(new TextDecoder().decode(bytes)); } catch { return json({ ok: false, erro: 'O corpo precisa ser JSON' }, 400); }
  if (!corpo || typeof corpo !== 'object' || Array.isArray(corpo)) return json({ ok: false, erro: 'O corpo precisa ser um objeto JSON' }, 400);

  const evento = prov === 'kiwify' ? (corpo.order_id ? `${corpo.order_id}:${corpo.webhook_event_type || ''}` : '') : prov === 'eduzz' ? String(corpo.id || '') : (req.headers.get('x-hubla-idempotency') || '');
  const teste = prov === 'hubla' && (req.headers.get('x-hubla-sandbox') || '').toUpperCase() === 'TRUE';
  const { data, error } = await sb.rpc('plataforma_webhook_gravar', { p_chave: chave, p_prov: prov, p_token: req.headers.get('x-hubla-token') || '', p_evento_id: evento, p_teste: teste, p: corpo });
  if (error) { if (error.code === '28000') return negado(); console.error('gravar', error.message); return json({ ok: false, erro: 'Falha ao registrar o evento' }, 500); }
  return json(data);
});
