// Edge function "perguntar": responde perguntas usando SÓ o resumo calculado por ia_contexto().
// Segredos (Supabase → Edge Functions → Secrets): ANTHROPIC_API_KEY e/ou OPENAI_API_KEY. Opcionais: ANTHROPIC_MODEL, OPENAI_MODEL.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { REGRAS, montaMensagem, leResposta, confere, perguntaValida } from './logica.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const MODELO_CLAUDE = Deno.env.get('ANTHROPIC_MODEL') || 'claude-sonnet-5-5';
const MODELO_OPENAI = Deno.env.get('OPENAI_MODEL') || 'gpt-4o';

async function chamaClaude(msg: string) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') || '', 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODELO_CLAUDE, max_tokens: 900, temperature: 0, system: REGRAS, messages: [{ role: 'user', content: msg }] }),
  });
  const d = await r.json();
  if (!r.ok) throw new Error('Claude: ' + (d?.error?.message || r.status));
  return { texto: (d.content || []).map((c: { text?: string }) => c.text || '').join(''), modelo: MODELO_CLAUDE };
}
async function chamaOpenAI(msg: string) {
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + (Deno.env.get('OPENAI_API_KEY') || ''), 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODELO_OPENAI, temperature: 0, max_tokens: 900, response_format: { type: 'json_object' }, messages: [{ role: 'system', content: REGRAS }, { role: 'user', content: msg }] }),
  });
  const d = await r.json();
  if (!r.ok) throw new Error('ChatGPT: ' + (d?.error?.message || r.status));
  return { texto: d.choices?.[0]?.message?.content || '', modelo: MODELO_OPENAI };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const corpo = await req.json().catch(() => ({}));
    const tem = { claude: !!Deno.env.get('ANTHROPIC_API_KEY'), openai: !!Deno.env.get('OPENAI_API_KEY') };
    if (corpo.acao === 'status') return json({ provedores: tem });
    const auth = req.headers.get('Authorization') || '';
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const pergunta = perguntaValida(corpo.pergunta);
    const provedor = corpo.provedor === 'openai' ? 'openai' : 'claude';
    if (!tem[provedor]) return json({ erro: provedor === 'claude' ? 'A chave do Claude ainda não foi configurada (segredo ANTHROPIC_API_KEY no Supabase).' : 'A chave do ChatGPT ainda não foi configurada (segredo OPENAI_API_KEY no Supabase).' }, 501);
    // limite simples: 40 perguntas por hora por pessoa
    const { count } = await sb.from('ia_perguntas').select('id', { count: 'exact', head: true }).gte('criado_em', new Date(Date.now() - 3600e3).toISOString());
    if ((count || 0) >= 40) return json({ erro: 'Limite de 40 perguntas por hora. Tente mais tarde.' }, 429);
    // o servidor, e não a tela, escolhe o que a IA enxerga
    const { data: base, error } = await sb.rpc('ia_contexto', { p_ws: corpo.ws, p_ini: corpo.ini, p_fim: corpo.fim });
    if (error) return json({ erro: error.message }, 400);
    // v0.132: o dia a dia (hoje até agora, ontem, a série por dia e os alertas abertos), para "como foi ontem?"
    const { data: extra } = await sb.rpc('growths_ia_extra', { p_ws: corpo.ws, p_ini: corpo.ini, p_fim: corpo.fim });
    const ctx = { ...(base as Record<string, unknown>), ...((extra as Record<string, unknown>) || {}) };
    const { texto, modelo } = provedor === 'claude' ? await chamaClaude(montaMensagem(pergunta, ctx)) : await chamaOpenAI(montaMensagem(pergunta, ctx));
    const r = leResposta(texto, ctx);
    const nao_conferidos = confere(r.resposta, ctx);
    await sb.from('ia_perguntas').insert({ workspace_id: corpo.ws, pergunta, resposta: r.resposta, provedor, modelo, sem_dado: r.sem_dado, nao_conferidos });
    return json({ ...r, nao_conferidos, provedor, modelo, contexto: ctx });
  } catch (e) {
    return json({ erro: (e as Error).message || String(e) }, 500);
  }
});
