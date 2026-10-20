// Teste da edge function "leads".
// Parte 1 (sem banco): deno run tests/edge/leads_teste.ts
// Parte 2 (com a função no ar, ver LEIA.md): CHAVE=gw_... BASE=http://127.0.0.1:8788 deno run --allow-net --allow-env tests/edge/leads_teste.ts
import { leadDe, chaveNorm } from '../../supabase/functions/leads/campos.ts';

const ok = (c: boolean, m: string, x?: unknown) => { console.log((c ? 'OK   ' : 'FALHA') + ' ' + m + (c ? '' : ' → ' + JSON.stringify(x))); if (!c) Deno.exitCode = 1; };
const U = (q = '') => new URL('https://x.supabase.co/functions/v1/leads?chave=gw_' + '0'.repeat(64) + q);

ok(chaveNorm('Qual é o seu WhatsApp?') === 'qual_e_o_seu_whatsapp', 'normaliza pergunta');

// formulário da página (campos soltos + url com UTM)
let L = leadDe({ nome: 'Ana Souza', 'E-mail': 'ana@x.com', whatsapp: '(11) 97777-6666', pagina: 'https://escola.com/inscricao?utm_source=meta&utm_campaign=lanc-set-meta&utm_content=ad07', interesse: 'Inglês', website: '' }, U());
ok(L.nome === 'Ana Souza' && L.email === 'ana@x.com' && L.telefone === '(11) 97777-6666', 'página: contato', L);
ok(L.utm_campaign === 'lanc-set-meta' && L.utm_content === 'ad07' && L.utm_source === 'meta', 'página: UTM da URL', L);
ok(L.respostas['interesse'] === 'Inglês' && !('website' in L.respostas) && L.origem === 'formulario', 'página: respostas sem campo-isca', L);

// UTM no corpo vence a da URL; a do endereço da função é só padrão
L = leadDe({ email: 'b@x.com', utm_campaign: 'do-corpo', pagina: 'https://s.com/?utm_campaign=da-url' }, U('&utm_campaign=padrao&utm_medium=form'));
ok(L.utm_campaign === 'do-corpo' && L.utm_medium === 'form', 'precedência das UTMs', L);

// Respondi (webhook)
const respondi = {
  form: { form_name: 'Inscrição Aula Aberta', form_id: 'abc' },
  respondent: {
    respondent_id: 'r1', date: '2026-10-16 14:03:00',
    answers: { 'Qual é o seu nome?': 'Bruno Lima', 'Seu melhor e-mail': 'bruno@x.com', 'Seu WhatsApp': '11 96666-5555', 'Nível de inglês': 'Intermediário' },
    raw_answers: [
      { question: { question_title: 'Qual é o seu nome?', question_type: 'name' }, answer: 'Bruno Lima' },
      { question: { question_title: 'Seu WhatsApp', question_type: 'phone' }, answer: { country: '55', phone: '11 96666-5555' } },
    ],
    respondent_utms: { utm_source: 'instagram', utm_campaign: 'lanc-set-org' },
  },
};
L = leadDe(respondi, U());
ok(L.origem === 'respondi' && L.nome === 'Bruno Lima' && L.email === 'bruno@x.com' && /96666/.test(L.telefone || ''), 'Respondi: contato', L);
ok(L.utm_campaign === 'lanc-set-org' && L.respostas['Nível de inglês'] === 'Intermediário', 'Respondi: UTM e respostas', L);

// Meta Lead Ads (como o Zapier/Make ou a Graph API devolvem)
L = leadDe({ created_time: '2026-10-16T12:00:00+0000', ad_name: 'AD07 depoimento', field_data: [
  { name: 'full_name', values: ['Carla Dias'] }, { name: 'email', values: ['carla@x.com'] }, { name: 'phone_number', values: ['+5511955554444'] },
  { name: 'qual_seu_objetivo?', values: ['Viajar'] }] }, U('&utm_campaign=lanc-set-meta&utm_source=meta'));
ok(L.origem === 'meta_lead_ads' && L.nome === 'Carla Dias' && L.telefone === '+5511955554444' && L.email === 'carla@x.com', 'Meta: contato', L);
ok(L.utm_campaign === 'lanc-set-meta' && L.em === '2026-10-16T12:00:00.000Z' && L.respostas['qual_seu_objetivo?'] === 'Viajar', 'Meta: campanha do endereço, data e respostas', L);

// primeiro + último nome
L = leadDe({ first_name: 'Davi', last_name: 'Reis', phone: '21988887777' }, U());
ok(L.nome === 'Davi Reis' && L.telefone === '21988887777', 'first_name + last_name', L);

// Parte 2: contra a função
const K = Deno.env.get('CHAVE'), BASE = Deno.env.get('BASE');
if (K && BASE) {
  let r = await fetch(BASE, { method: 'POST', body: '{}' }); ok(r.status === 401, 'sem chave: 401', r.status); await r.body?.cancel();
  r = await fetch(BASE + '?hub.mode=subscribe&hub.verify_token=' + K + '&hub.challenge=123'); ok((await r.text()) === '123', 'verificação da Meta');
  const f = new URLSearchParams({ nome: 'Edu Teste', email: 'edu.teste@x.com', telefone: '11 95555-1234', utm_campaign: 'lanc-set-google', curso: 'Inglês' });
  r = await fetch(BASE + '?chave=' + K, { method: 'POST', body: f, headers: { 'content-type': 'application/x-www-form-urlencoded' } });
  let d = await r.json(); ok(r.status === 200 && d.ok && d.nova && d.campanha, 'form HTML: pessoa nova na campanha', d);
  r = await fetch(BASE + '?chave=' + K, { method: 'POST', body: JSON.stringify({ email: 'EDU.TESTE@x.com', utm_campaign: 'lanc-set-google' }), headers: { 'content-type': 'application/json' } });
  d = await r.json(); ok(d.ok && !d.nova && d.repetida, 'mesmo e-mail: repetida', d);
  r = await fetch(BASE + '?chave=' + K + '&redirect=https://escola.com/obrigado', { method: 'POST', body: new URLSearchParams({ email: 'fabi.teste@x.com' }), redirect: 'manual' });
  ok(r.status === 303 && r.headers.get('location') === 'https://escola.com/obrigado', 'redirect para a página de obrigado', r.status); await r.body?.cancel();
  r = await fetch(BASE, { method: 'POST', headers: { 'x-growths-chave': K, 'content-type': 'application/json' }, body: JSON.stringify(respondi) });
  d = await r.json(); ok(d.ok && d.nova && d.aviso, 'Respondi pelo cabeçalho, utm sem campanha → aviso', d);
  r = await fetch(BASE + '?chave=' + K, { method: 'POST', body: JSON.stringify({ nome: 'robô', email: 'robo@x.com', _gotcha: 'spam' }) });
  d = await r.json(); ok(d.ok && !d.pessoa_id, 'campo-isca: não grava', d);
  r = await fetch(BASE + '?chave=' + K, { method: 'POST', body: JSON.stringify({ nome: 'sem contato' }) });
  d = await r.json(); ok(r.status === 400 && !d.ok, 'sem contato: 400', d);
  r = await fetch(BASE + '?chave=gw_' + '1'.repeat(64), { method: 'POST', body: JSON.stringify({ email: 'z@x.com' }) });
  d = await r.json(); ok(r.status === 401 && /inválida/.test(d.erro), 'chave inexistente: 401', d);
  r = await fetch(BASE + '?chave=' + K, { method: 'POST', body: JSON.stringify({ entry: [{ changes: [{ field: 'leadgen', value: { leadgen_id: '999' } }] }] }) });
  d = await r.json(); ok(r.status === 200 && !d.ok && /META_ACCESS_TOKEN/.test(d.erro), 'Meta nativo sem token: 200 com aviso', d);
}
