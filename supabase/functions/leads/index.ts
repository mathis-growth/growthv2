// Edge function "leads": recebe leads de formulários e grava no Growths (Pessoas + campanha pelo utm_campaign).
// Endereço: https://<projeto>.supabase.co/functions/v1/leads?chave=gw_...
//   A chave é gerada na campanha → Captação e metas → Receber leads (escopo "leads": só grava leads, não lê nada).
//   Também aceita a chave no cabeçalho  x-growths-chave: gw_...  ou  Authorization: Bearer gw_...
// Aceita: JSON, formulário HTML (application/x-www-form-urlencoded ou multipart), webhook da Respondi,
//   Meta Lead Ads (field_data, vindo do Zapier/Make, ou o webhook nativo da página — ver META_ACCESS_TOKEN abaixo).
// Os campos são achados pelo nome: nome/name, email/e-mail, telefone/celular/whatsapp/phone, utm_*.
//   Tudo o que não é contato nem UTM vira "respostas" do formulário (ficam no cadastro da pessoa).
// Parâmetros no endereço valem como padrão: ?utm_campaign=lanc-set-meta&utm_source=meta faz todos os leads daquele
//   formulário caírem na campanha certa mesmo quando o formulário não manda UTM (útil para Meta e Respondi).
//   ?redirect=https://site/obrigado  → depois de gravar, devolve 303 para a página de obrigado (formulário HTML puro).
// Campo-isca anti-robô: se vier "_gotcha" ou "website" preenchido, responde ok e não grava nada.
// Meta (webhook nativo da página): GET com hub.verify_token = a própria chave confirma o endereço.
//   Para buscar o lead pelo leadgen_id é preciso o segredo META_ACCESS_TOKEN (token da página com leads_retrieval).
// Publicar SEM verificação de JWT: supabase functions deploy leads --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { type Dic, RE_CHAVE, chaveDe, leadDe, valorTexto } from './campos.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-growths-chave, content-type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } });
async function leadMeta(leadgen: string): Promise<Dic | null> {
  const tk = Deno.env.get('META_ACCESS_TOKEN');
  if (!tk) return null;
  const r = await fetch(`https://graph.facebook.com/v21.0/${encodeURIComponent(leadgen)}?fields=created_time,field_data,ad_name,adset_name,campaign_name,form_id&access_token=${encodeURIComponent(tk)}`);
  if (!r.ok) return null;
  return await r.json();
}

async function corpoDe(req: Request): Promise<unknown> {
  const tipo = (req.headers.get('content-type') || '').toLowerCase();
  if (tipo.includes('application/x-www-form-urlencoded') || tipo.includes('multipart/form-data')) {
    const f = await req.formData(); const o: Dic = {};
    for (const [k, v] of f.entries()) if (typeof v === 'string') o[k] = k in o ? [o[k], v].flat() : v;
    return o;
  }
  const t = await req.text();
  try { return JSON.parse(t); } catch { return Object.fromEntries(new URLSearchParams(t)); }
}

const destino = (url: URL, corpo: Dic): string | null => {
  const r = String(url.searchParams.get('redirect') || corpo._redirect || corpo.redirect || '');
  return /^https?:\/\//i.test(r) ? r : null;
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const url = new URL(req.url);
  // verificação do webhook da Meta: hub.verify_token deve ser a chave
  if (req.method === 'GET' && url.searchParams.get('hub.mode') === 'subscribe') {
    const k = url.searchParams.get('hub.verify_token') || '';
    return RE_CHAVE.test(k) ? new Response(url.searchParams.get('hub.challenge') || '', { status: 200 }) : new Response('token inválido', { status: 403 });
  }
  const chave = chaveDe(req, url) || (RE_CHAVE.test(url.searchParams.get('hub.verify_token') || '') ? url.searchParams.get('hub.verify_token') : null);
  if (req.method === 'GET') return json({ ok: !!chave, mensagem: chave ? 'Endereço pronto. Envie os leads por POST.' : 'Falta a chave: use ?chave=gw_...' }, chave ? 200 : 401);
  if (req.method !== 'POST') return json({ ok: false, erro: 'Use POST' }, 405);
  if (!chave) return json({ ok: false, erro: 'Chave do Growths ausente ou em formato errado. Gere uma na campanha → Captação e metas → Receber leads.' }, 401);
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { auth: { persistSession: false } });
  try {
    const corpo = await corpoDe(req) as Dic;
    const ir = destino(url, corpo || {});
    if (valorTexto(corpo?._gotcha) || valorTexto(corpo?.website)) return ir ? Response.redirect(ir, 303) : json({ ok: true });
    // Meta nativo: entry[].changes[].value.leadgen_id (pode vir mais de um)
    const ids: string[] = [];
    for (const e of (Array.isArray(corpo?.entry) ? corpo.entry : []) as Dic[]) for (const ch of (Array.isArray(e.changes) ? e.changes : []) as Dic[]) {
      const v = (ch.value || {}) as Dic; if (v.leadgen_id) ids.push(String(v.leadgen_id));
    }
    const lotes: unknown[] = [];
    if (ids.length) {
      for (const id of ids.slice(0, 20)) { const m = await leadMeta(id); if (m) lotes.push(m); }
      if (!lotes.length) return json({ ok: false, erro: 'Lead da Meta recebido, mas falta o segredo META_ACCESS_TOKEN para buscar os dados (ou o token não tem leads_retrieval).' }, 200); // 200: a Meta não fica reenviando
    } else lotes.push(...(Array.isArray(corpo?.leads) ? (corpo.leads as unknown[]).slice(0, 50) : [corpo]));
    const res: unknown[] = [];
    for (const item of lotes) {
      const L = leadDe(item, url);
      if (ids.length) L.origem = 'meta_lead_ads';
      if (!L.email && !L.telefone) { res.push({ ok: false, erro: 'Lead sem e-mail nem telefone: não gravado.' }); continue; }
      const { data, error } = await sb.rpc('lead_por_chave', { p_chave: chave, p_dados: L });
      if (error) {
        if (/inválida|revogada/i.test(error.message)) return json({ ok: false, erro: error.message }, 401);
        res.push({ ok: false, erro: error.message });
      } else res.push(data);
    }
    const um = res.length === 1 ? res[0] as Dic : null;
    if (ir && res.some((r) => (r as Dic).ok)) return Response.redirect(ir, 303);
    if (um) return json(um, um.ok ? 200 : 400);
    return json({ ok: res.some((r) => (r as Dic).ok), quantidade: res.filter((r) => (r as Dic).ok).length, resultados: res });
  } catch (e) {
    return json({ ok: false, erro: (e as Error).message }, 500);
  }
});
