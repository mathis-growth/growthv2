// Edge function "vendas-hotmart": recebe o webhook de compras da Hotmart (versão 2.0.0) e grava a venda no Growths.
// Endereço: https://<projeto>.supabase.co/functions/v1/vendas-hotmart?chave=gw_...
//   A chave é gerada em Integrações → Vendas da Hotmart. O hottok da conta vem no cabeçalho X-HOTMART-HOTTOK.
// As regras ficam no banco (hotmart_webhook). Evento que não dá para aplicar fica registrado para revisão e responde 200,
//   porque a Hotmart pode desativar um webhook que devolve erro. Só chave ou hottok errados recebem 401.
// Publicar SEM verificação de JWT: supabase functions deploy vendas-hotmart --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';

const RE_CHAVE = /^gw_[0-9a-f]{64}$/;
const LIMITE = 512 * 1024;
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { 'Content-Type': 'application/json; charset=utf-8' } });

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const chave = (url.searchParams.get('chave') || '').trim();
  if (!RE_CHAVE.test(chave)) return json({ ok: false, erro: 'Chave ausente ou em formato errado' }, 401);
  if (req.method === 'GET') return json({ ok: true, mensagem: 'Endereço pronto. A Hotmart envia os eventos por POST.' });
  if (req.method !== 'POST') return json({ ok: false, erro: 'Use POST' }, 405);
  const hottok = req.headers.get('x-hotmart-hottok') || '';
  if (!hottok) return json({ ok: false, erro: 'Falta o cabeçalho X-HOTMART-HOTTOK' }, 401);
  const texto = await req.text();
  if (texto.length > LIMITE) return json({ ok: false, erro: 'Evento grande demais' }, 413);
  let corpo: unknown;
  try { corpo = JSON.parse(texto); } catch { return json({ ok: false, erro: 'O corpo precisa ser JSON' }, 400); }
  if (!corpo || typeof corpo !== 'object' || Array.isArray(corpo)) return json({ ok: false, erro: 'O corpo precisa ser um objeto JSON' }, 400);
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const { data, error } = await sb.rpc('hotmart_webhook', { p_chave: chave, p_hottok: hottok, p: corpo });
  if (error) {
    if (error.code === '28000') return json({ ok: false, erro: 'Chave ou hottok inválidos' }, 401);
    console.error('hotmart_webhook', error.message);
    return json({ ok: false, erro: 'Falha ao registrar o evento' }, 500);
  }
  return json(data);
});
