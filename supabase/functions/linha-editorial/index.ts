// Edge function "linha-editorial": lê o questionário de persona/nicho do cliente e pede à IA uma proposta de linha editorial
// no formato da Máquina de Conteúdo (o mesmo do modelo V18). A proposta fica guardada como "proposta" e só vale depois que
// alguém clica em "Aplicar" na tela. Sem chave de IA, a tela oferece copiar o pedido e colar a resposta (mesma validação).
// Segredos (Supabase → Edge Functions → Secrets): ANTHROPIC_API_KEY e/ou OPENAI_API_KEY. Opcionais: ANTHROPIC_MODEL, OPENAI_MODEL.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { REGRAS, montaMensagem, extraiJson, validaProposta, respondidas } from './logica.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const MODELO_CLAUDE = Deno.env.get('ANTHROPIC_MODEL') || 'claude-sonnet-5-5';
const MODELO_OPENAI = Deno.env.get('OPENAI_MODEL') || 'gpt-4o';

async function chamaClaude(msg: string) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') || '', 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODELO_CLAUDE, max_tokens: 6000, temperature: 0.4, system: REGRAS, messages: [{ role: 'user', content: msg }] }),
  });
  const d = await r.json();
  if (!r.ok) throw new Error('Claude: ' + (d?.error?.message || r.status));
  return { texto: (d.content || []).map((c: { text?: string }) => c.text || '').join(''), modelo: MODELO_CLAUDE };
}
async function chamaOpenAI(msg: string) {
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + (Deno.env.get('OPENAI_API_KEY') || ''), 'content-type': 'application/json' },
    body: JSON.stringify({ model: MODELO_OPENAI, temperature: 0.4, max_tokens: 6000, response_format: { type: 'json_object' }, messages: [{ role: 'system', content: REGRAS }, { role: 'user', content: msg }] }),
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
    // tudo pelo cliente da pessoa logada: as regras de acesso do banco decidem o que ela lê e grava
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const provedor = corpo.provedor === 'openai' ? 'openai' : 'claude';
    if (!tem[provedor]) return json({ erro: provedor === 'claude' ? 'A chave do Claude ainda não foi configurada (segredo ANTHROPIC_API_KEY no Supabase). Use "Copiar pedido" e cole a resposta.' : 'A chave do ChatGPT ainda não foi configurada (segredo OPENAI_API_KEY no Supabase). Use "Copiar pedido" e cole a resposta.' }, 501);
    const { data: pe, error: e1 } = await sb.from('conteudo_personas').select('id, workspace_id, respostas').eq('id', corpo.persona_id).maybeSingle();
    if (e1) return json({ erro: e1.message }, 400);
    if (!pe) return json({ erro: 'Questionário não encontrado.' }, 404);
    if (respondidas(pe.respostas) < 6) return json({ erro: 'Responda pelo menos 6 perguntas do questionário antes de pedir a proposta.' }, 400);
    // limite simples: 6 propostas por hora por cliente
    const { count } = await sb.from('conteudo_linha_propostas').select('id', { count: 'exact', head: true }).eq('workspace_id', pe.workspace_id).eq('origem', 'ia').gte('criado_em', new Date(Date.now() - 3600e3).toISOString());
    if ((count || 0) >= 6) return json({ erro: 'Limite de 6 propostas por hora. Tente mais tarde.' }, 429);
    const { data: exemplo } = await sb.rpc('conteudo_modelo_v18');
    const msg = montaMensagem(pe.respostas, exemplo);
    const { texto, modelo } = provedor === 'claude' ? await chamaClaude(msg) : await chamaOpenAI(msg);
    const proposta = validaProposta(extraiJson(texto));
    const { data: nova, error: e2 } = await sb.from('conteudo_linha_propostas').insert({ workspace_id: pe.workspace_id, persona_id: pe.id, origem: 'ia', modelo_ia: modelo, proposta }).select('id').single();
    if (e2) return json({ erro: e2.message }, 400);
    return json({ id: nova.id, proposta, modelo });
  } catch (e) {
    return json({ erro: (e as Error).message || String(e) }, 500);
  }
});
