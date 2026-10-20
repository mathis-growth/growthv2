// Edge function "ideias": a IA do celular (ex.: um GPT no ChatGPT) grava ideias de conteúdo no Planejamento de conteúdo do Growths.
// Autenticação: a chave gerada no Growths (Planejamento de conteúdo → Ideias pelo ChatGPT), no cabeçalho
//   Authorization: Bearer gw_...   (ou x-growths-chave: gw_...)
// GET  /ideias  → temas, formatos, canais e últimas ideias do workspace da chave
// POST /ideias  → { titulo, descricao?, formato?, tema?, canais? }  ou  { ideias: [ {...}, ... ] } (até 10)
// Publicar SEM verificação de JWT (a chave do Growths não é um JWT): supabase functions deploy ideias --no-verify-jwt
// Não guarda segredo nenhum: quem valida a chave é o banco (funções ideia_por_chave e ideias_por_chave_contexto).
import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-growths-chave, content-type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } });
const texto = (v: unknown, max: number) => (typeof v === 'string' ? v.trim().slice(0, max) : '') || null;

export function chaveDe(req: Request): string | null {
  const h = req.headers.get('x-growths-chave') || '';
  const a = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  const k = (h || a).trim();
  return /^gw_[0-9a-f]{64}$/.test(k) ? k : null;
}
export function ideiasDe(corpo: Record<string, unknown>) {
  const lista = Array.isArray(corpo.ideias) ? corpo.ideias : [corpo];
  return lista.slice(0, 10).map((x) => {
    const i = (x || {}) as Record<string, unknown>;
    const canais = Array.isArray(i.canais) ? i.canais.filter((c) => typeof c === 'string').slice(0, 8) as string[] : typeof i.canais === 'string' ? i.canais.split(/[,;]/) : null;
    return { p_titulo: texto(i.titulo, 200), p_descricao: texto(i.descricao, 4000), p_formato: texto(i.formato, 30), p_tema: texto(i.tema, 120), p_canais: canais };
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const chave = chaveDe(req);
  if (!chave) return json({ ok: false, erro: 'Chave do Growths ausente ou em formato errado. Gere uma em Planejamento de conteúdo → Ideias pelo ChatGPT.' }, 401);
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { auth: { persistSession: false } });
  try {
    if (req.method === 'GET') {
      const { data, error } = await sb.rpc('ideias_por_chave_contexto', { p_chave: chave });
      if (error) return json({ ok: false, erro: error.message }, /inválida|revogada/i.test(error.message) ? 401 : 400);
      return json({ ok: true, ...data });
    }
    if (req.method !== 'POST') return json({ ok: false, erro: 'Use GET ou POST' }, 405);
    const corpo = await req.json().catch(() => ({}));
    const L = ideiasDe(corpo);
    if (!L.length || L.some((i) => !i.p_titulo)) return json({ ok: false, erro: 'Cada ideia precisa de um título.' }, 400);
    const criadas = [];
    for (const i of L) {
      const { data, error } = await sb.rpc('ideia_por_chave', { p_chave: chave, ...i });
      if (error) return json({ ok: false, erro: error.message, criadas }, /inválida|revogada/i.test(error.message) ? 401 : 400);
      criadas.push(data);
    }
    return json({ ok: true, quantidade: criadas.length, criadas, mensagem: criadas.length === 1 ? 'Ideia guardada no Growths, na etapa Ideia.' : criadas.length + ' ideias guardadas no Growths, na etapa Ideia.' });
  } catch (e) {
    return json({ ok: false, erro: (e as Error).message }, 500);
  }
});
