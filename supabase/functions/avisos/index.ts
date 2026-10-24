// Edge function "avisos": envia por e-mail e WhatsApp as notificações que estão na fila (tabela notificacoes,
// status "pendente"): alertas, resumo do dia, atividades liberadas e avisos do CRM.
// Quem chama: o agendador do banco (cabeçalho x-growths-token = sistema_config.avisos_token) ou alguém logado (botão "Enviar teste").
// Publicar SEM verificação de JWT: supabase functions deploy avisos --no-verify-jwt
// Segredos (Supabase → Edge Functions → Secrets):
//   E-mail (Resend): RESEND_API_KEY e AVISOS_EMAIL_DE (ex.: "Growths <avisos@seudominio.com.br>", domínio verificado no Resend).
//   WhatsApp (API oficial da Meta): WHATSAPP_TOKEN, WHATSAPP_PHONE_ID e o modelo aprovado WHATSAPP_MODELO
//     (padrão "aviso_growths", com 2 variáveis: {{1}} título e {{2}} detalhe). Opcional: WHATSAPP_IDIOMA (padrão pt_BR).
//   Opcional: GROWTHS_URL (link do botão "Abrir o Growths" no e-mail).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { foneWhatsApp, montaEmail, montaWhatsApp } from './logica.ts';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-growths-token', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const env = (k: string) => Deno.env.get(k) || '';
const temEmail = () => !!(env('RESEND_API_KEY') && env('AVISOS_EMAIL_DE'));
const temWhats = () => !!(env('WHATSAPP_TOKEN') && env('WHATSAPP_PHONE_ID'));

async function enviaEmail(n: { titulo: string; mensagem: string }, para: string) {
  const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: 'Bearer ' + env('RESEND_API_KEY'), 'Content-Type': 'application/json' },
    body: JSON.stringify(montaEmail(n, env('AVISOS_EMAIL_DE'), para, env('GROWTHS_URL') || undefined)) });
  if (!r.ok) throw new Error('Resend ' + r.status + ': ' + (await r.text()).slice(0, 300));
}
async function enviaWhats(n: { titulo: string; mensagem: string }, fone: string) {
  const r = await fetch(`https://graph.facebook.com/v21.0/${encodeURIComponent(env('WHATSAPP_PHONE_ID'))}/messages`, { method: 'POST',
    headers: { Authorization: 'Bearer ' + env('WHATSAPP_TOKEN'), 'Content-Type': 'application/json' },
    body: JSON.stringify(montaWhatsApp(n, fone, env('WHATSAPP_MODELO') || 'aviso_growths', env('WHATSAPP_IDIOMA') || 'pt_BR')) });
  if (!r.ok) throw new Error('WhatsApp ' + r.status + ': ' + (await r.text()).slice(0, 300));
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const corpo = await req.json().catch(() => ({}));
    if (corpo.acao === 'status') return json({ email: temEmail(), whatsapp: temWhats() });
    const adm = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
    // quem pode pedir o envio: o agendador (senha guardada no banco) ou alguém logado
    const tk = req.headers.get('x-growths-token') || '';
    let ok = false;
    if (tk) { const { data } = await adm.from('sistema_config').select('valor').eq('chave', 'avisos_token').maybeSingle(); ok = !!data && data.valor === tk; }
    if (!ok) { const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, ''); if (jwt) { const { data } = await adm.auth.getUser(jwt); ok = !!data?.user; } }
    if (!ok) return json({ erro: 'Sem permissão' }, 401);

    // o que passou de 3 dias na fila não vale mais a pena mandar
    await adm.from('notificacoes').update({ status: 'falhou', erro: 'Expirou na fila (mais de 3 dias sem envio)' }).eq('status', 'pendente').in('canal', ['email', 'whatsapp']).lt('criada_em', new Date(Date.now() - 3 * 864e5).toISOString());
    const { data: fila, error } = await adm.from('notificacoes').select('id, canal, titulo, mensagem, equipe:destinatario_id (email, telefone)')
      .eq('status', 'pendente').in('canal', ['email', 'whatsapp']).order('criada_em').limit(50);
    if (error) throw error;
    const res = { enviadas: 0, falharam: 0, erros: [] as string[] };
    for (const n of fila || []) {
      // reserva a linha antes de enviar, para dois envios ao mesmo tempo não mandarem duas vezes
      const { data: pego } = await adm.from('notificacoes').update({ status: 'enviada', enviada_em: new Date().toISOString() }).eq('id', n.id).eq('status', 'pendente').select('id');
      if (!pego || !pego.length) continue;
      const eq = (Array.isArray(n.equipe) ? n.equipe[0] : n.equipe) || {};
      try {
        if (n.canal === 'email') {
          if (!temEmail()) throw new Error('E-mail ainda não configurado (segredos RESEND_API_KEY e AVISOS_EMAIL_DE).');
          if (!eq.email) throw new Error('Pessoa sem e-mail na Equipe.');
          await enviaEmail(n, eq.email);
        } else {
          if (!temWhats()) throw new Error('WhatsApp ainda não configurado (segredos WHATSAPP_TOKEN e WHATSAPP_PHONE_ID).');
          const f = foneWhatsApp(eq.telefone);
          if (!f) throw new Error('Telefone da pessoa na Equipe não está no formato DDD + número.');
          await enviaWhats(n, f);
        }
        res.enviadas++;
      } catch (e) {
        const msg = (e as Error).message || String(e);
        await adm.from('notificacoes').update({ status: 'falhou', erro: msg.slice(0, 500), enviada_em: null }).eq('id', n.id);
        res.falharam++; if (!res.erros.includes(msg)) res.erros.push(msg);
      }
    }
    return json(res);
  } catch (e) {
    return json({ erro: (e as Error).message || String(e) }, 500);
  }
});
