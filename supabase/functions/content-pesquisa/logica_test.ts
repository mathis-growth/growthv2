const assertEquals = (a: unknown, b: unknown) => { if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`esperava ${JSON.stringify(b)}, veio ${JSON.stringify(a)}`); };
const assertThrows = (f: () => unknown) => { try { f(); } catch { return; } throw new Error('esperava erro'); };
import { blocosArquivos, custoUSD, extraiFontes, lerSecoes, pastaIdDe, somaUso, textoCall } from './logica.ts';

Deno.test('pastaIdDe', () => {
  assertEquals(pastaIdDe('https://drive.google.com/drive/folders/1AbCdEfGhIjKlMn?usp=sharing'), '1AbCdEfGhIjKlMn');
  assertEquals(pastaIdDe('https://drive.google.com/open?id=1AbCdEfGhIjKlMn'), '1AbCdEfGhIjKlMn');
  assertEquals(pastaIdDe('oi'), null);
});
Deno.test('blocosArquivos: só lidos; PDF vira documento; rótulo de padrão x cliente', () => {
  const b = blocosArquivos([
    { id: '1', nome: 'Método.docx', caminho: 'MIRA', rotulo: 'mathisa', tipo: 'g', lido: true, texto: 'passo 1' },
    { id: '2', nome: 'aula.pdf', caminho: 'Cliente › 02', rotulo: 'cliente', tipo: 'application/pdf', lido: true, pdf_base64: 'AAA' },
    { id: '3', nome: 'video.mp4', caminho: 'x', rotulo: 'cliente', tipo: 'video/mp4', lido: false, motivo: 'transcrição' }]) as any[];
  assertEquals(b.length, 2);
  assertEquals(b[0].text.startsWith('### [PADRÃO DA MATHISA] MIRA › Método.docx'), true);
  assertEquals(b[1].type, 'document');
});
Deno.test('extraiFontes: resultados e citações sem repetir', () => {
  const f = extraiFontes([{ type: 'web_search_tool_result', content: [{ url: 'https://a', title: 'A' }, { url: 'https://b', title: 'B' }] },
    { type: 'text', text: 'x', citations: [{ url: 'https://a', title: 'A' }, { url: 'https://c', title: 'C' }] }]);
  assertEquals(f.map(x => x.url), ['https://a', 'https://b', 'https://c']);
});
Deno.test('custo: sem preço cadastrado é null; com preço calcula', () => {
  const uso = somaUso([{ input_tokens: 1000000, output_tokens: 100000, server_tool_use: { web_search_requests: 5 } }]);
  assertEquals(custoUSD(uso, {}, 'm'), null);
  assertEquals(custoUSD(uso, { m: { entrada: 3, saida: 15 } }, 'm'), null); // buscas sem preço de busca
  assertEquals(custoUSD(uso, { m: { entrada: 3, saida: 15 }, busca_mil: 10 }, 'm'), 4.55);
});
Deno.test('lerSecoes: JSON com cerca, seções vazias fora; exige a maior parte das seções', () => {
  const s = lerSecoes('```json\n{"secoes":[{"titulo":"Voz","texto":"direta"},{"titulo":"Narrativa","texto":"..."},{"titulo":"x","texto":""}]}\n```', ['Voz', 'Narrativa', 'Persona']);
  assertEquals(s.length, 2);
  assertThrows(() => lerSecoes('{"secoes":[{"titulo":"Voz","texto":"a"}]}', ['Voz', 'Narrativa', 'Persona', 'Diferencial']));
  assertThrows(() => lerSecoes('sem json', ['Voz']));
});
Deno.test('textoCall: pergunta e resposta, sem campos internos, com as notas', () => {
  const t = textoCall({ nicho: 'saúde', objetivos: ['A', 'B'], _call_data: '2026-10-25', _call_notas: 'ok', vazio: '' }, { nicho: 'Qual é o nicho?' });
  assertEquals(t, '- Qual é o nicho?: saúde\n- objetivos: A; B\n- Anotações livres da call: ok');
});
