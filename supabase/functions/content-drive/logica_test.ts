const assertEquals = (a: unknown, b: unknown) => { if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`esperava ${JSON.stringify(b)}, veio ${JSON.stringify(a)}`); };
import { lerArvore, lerResposta, montaPedido, nomeDaPasta } from './logica.ts';
Deno.test('árvore: lista de caminhos, ignora lixo', () => {
  assertEquals(lerArvore('["01 Briefing", " 02 Conteúdos/Roteiros ", "", null]'), ['01 Briefing', '02 Conteúdos/Roteiros']);
  assertEquals(lerArvore('não é json'), []);
  assertEquals(lerArvore(null), []);
});
Deno.test('nome da pasta sem barra e sem espaço sobrando', () => assertEquals(nomeDaPasta('  Ana / Esther  Silva '), 'Ana - Esther Silva'));
Deno.test('pedido leva a pasta já criada para completar a árvore', () => assertEquals(montaPedido({ senha: 's', raiz: 'r', nome: 'X', arvore: ['a'], pastaId: 'p' }).pasta_id, 'p'));
Deno.test('resposta do Apps Script', () => {
  assertEquals(lerResposta(200, '{"ok":true,"id":"1","url":"u"}'), { ok: true, id: '1', url: 'u' });
  assertEquals(lerResposta(200, '{"ok":false,"erro":"Senha inválida"}'), { ok: false, erro: 'Senha inválida' });
  assertEquals(lerResposta(200, '<html>accounts.google.com</html>').ok, false);
  assertEquals((lerResposta(403, '<title>Acesso negado</title>') as { erro: string }).erro.includes('Qualquer pessoa'), true);
  assertEquals((lerResposta(404, '<html>x</html>') as { erro: string }).erro.includes('/exec'), true);
});
