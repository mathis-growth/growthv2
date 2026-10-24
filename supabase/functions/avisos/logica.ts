// Lógica pura (sem rede) da edge function "avisos": monta o e-mail e a mensagem de WhatsApp de uma notificação.

export const esc = (s: unknown) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string));

// Telefone brasileiro para o formato da API do WhatsApp (só dígitos, com 55). Devolve null se não der para usar.
export function foneWhatsApp(t: unknown): string | null {
  const d = String(t ?? '').replace(/\D/g, '');
  if (d.length === 10 || d.length === 11) return '55' + d;
  if ((d.length === 12 || d.length === 13) && d.startsWith('55')) return d;
  return null;
}

// E-mail simples, legível no celular. O texto da notificação vira parágrafos e linhas "- " viram lista.
export function montaEmail(n: { titulo: string; mensagem: string }, de: string, para: string, link?: string) {
  const linhas = String(n.mensagem || '').split('\n');
  let html = '', lista: string[] = [];
  const fecha = () => { if (lista.length) { html += '<ul style="padding-left:18px;margin:8px 0">' + lista.map(l => `<li style="margin:4px 0">${esc(l)}</li>`).join('') + '</ul>'; lista = []; } };
  for (const l of linhas) {
    if (/^\s*-\s+/.test(l)) lista.push(l.replace(/^\s*-\s+/, ''));
    else { fecha(); if (l.trim()) html += `<p style="margin:8px 0">${esc(l)}</p>`; }
  }
  fecha();
  const corpo = `<div style="font-family:Arial,Helvetica,sans-serif;color:#24262b;max-width:560px;margin:0 auto;padding:20px">
<div style="font-size:12px;letter-spacing:1px;color:#6b6f78">GROWTHS</div>
<h2 style="font-size:20px;margin:8px 0 12px">${esc(n.titulo)}</h2>${html}
${link ? `<p style="margin:20px 0 0"><a href="${esc(link)}" style="background:#521F32;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;display:inline-block">Abrir o Growths</a></p>` : ''}
<p style="font-size:12px;color:#6b6f78;margin-top:24px">Você recebe este aviso porque está na equipe com aviso por e-mail ligado. Para mudar, ajuste em Equipe no Growths.</p></div>`;
  return { from: de, to: [para], subject: String(n.titulo || 'Aviso do Growths').slice(0, 200), html: corpo, text: `${n.titulo}\n\n${n.mensagem}${link ? '\n\n' + link : ''}` };
}

// WhatsApp: mensagem iniciada pela empresa precisa de um modelo aprovado na Meta com 2 variáveis ({{1}} título, {{2}} detalhe).
// As variáveis não aceitam quebra de linha, tabulação nem mais de 4 espaços seguidos.
export const paramWhats = (s: unknown, max: number) => String(s ?? '').replace(/\s*\n+\s*/g, ' · ').replace(/\t/g, ' ').replace(/ {4,}/g, '   ').trim().slice(0, max) || '-';
export function montaWhatsApp(n: { titulo: string; mensagem: string }, fone: string, modelo: string, idioma: string) {
  return { messaging_product: 'whatsapp', to: fone, type: 'template',
    template: { name: modelo, language: { code: idioma }, components: [{ type: 'body', parameters: [{ type: 'text', text: paramWhats(n.titulo, 200) }, { type: 'text', text: paramWhats(n.mensagem, 900) }] }] } };
}
