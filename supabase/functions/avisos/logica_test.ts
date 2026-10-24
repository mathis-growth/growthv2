// sem dependências de fora: roda com  deno test logica_test.ts
const assert = (c: unknown, m = 'falhou') => { if (!c) throw new Error(m); };
const assertEquals = (a: unknown, b: unknown) => { const x = JSON.stringify(a), y = JSON.stringify(b); if (x !== y) throw new Error(`esperava ${y}, veio ${x}`); };
import { foneWhatsApp, montaEmail, montaWhatsApp, paramWhats } from './logica.ts';

Deno.test('telefone no formato do WhatsApp', () => {
  assertEquals(foneWhatsApp('(31) 98888-7777'), '5531988887777');
  assertEquals(foneWhatsApp('+55 31 98888-7777'), '5531988887777');
  assertEquals(foneWhatsApp('3133334444'), '553133334444');
  assertEquals(foneWhatsApp('988887777'), null);
  assertEquals(foneWhatsApp(null), null);
});
Deno.test('e-mail: título, lista e escape de HTML', () => {
  const e = montaEmail({ titulo: 'Resumo <b>', mensagem: 'Resumo de sexta\n- Leads: 42\n- Vendas: 5' }, 'Growths <a@b.com>', 'x@y.com', 'https://app.exemplo.com');
  assertEquals(e.to, ['x@y.com']); assertEquals(e.subject, 'Resumo <b>');
  assert(e.html.includes('Resumo &lt;b&gt;') && e.html.includes('<li style="margin:4px 0">Leads: 42</li>') && e.html.includes('https://app.exemplo.com'));
  assert(e.text.includes('- Vendas: 5'));
});
Deno.test('WhatsApp: variáveis sem quebra de linha e dentro do limite', () => {
  assertEquals(paramWhats('a\n- b\n\n- c', 50), 'a · - b · - c');
  assertEquals(paramWhats('x    y\tz', 50), 'x   y z');
  assertEquals(paramWhats('', 10), '-');
  const w = montaWhatsApp({ titulo: 'Alerta', mensagem: 'linha 1\nlinha 2' }, '5531988887777', 'aviso_growths', 'pt_BR');
  assertEquals(w.template.name, 'aviso_growths');
  assertEquals(w.template.components[0].parameters.map(p => p.text), ['Alerta', 'linha 1 · linha 2']);
  assert(paramWhats('x'.repeat(2000), 900).length === 900);
});
