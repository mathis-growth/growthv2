// deno test supabase/functions/linha-editorial/logica_test.ts
import { PERGUNTAS, REGRAS, montaMensagem, extraiJson, validaProposta, respondidas, respostasTexto } from './logica.ts';
const ok = (c: unknown, m: string) => { if (!c) throw new Error(m); };

Deno.test('perguntas: 22, chaves únicas, cobrindo os princípios 1 a 3', () => {
  ok(PERGUNTAS.length === 22, 'tamanho ' + PERGUNTAS.length);
  ok(new Set(PERGUNTAS.map(p => p[0])).size === PERGUNTAS.length, 'chave repetida');
  for (const b of ['Nicho', 'Objetivo', 'Tese']) ok(PERGUNTAS.some(p => p[1] === b), 'falta bloco ' + b);
});
Deno.test('regras pedem para não inventar e trazem o formato de saída', () => {
  ok(REGRAS.includes('Não invente'), 'regra de não inventar');
  ok(REGRAS.includes('"territorios"') && REGRAS.includes('pendencias'), 'formato de saída');
});
Deno.test('mensagem leva só as respostas preenchidas, na ordem do questionário, e o exemplo', () => {
  const r = { publico: 'Infoprodutores', nicho: 'Negócios digitais', lacunas: '', extra: 'x', objetivos: ['autoridade', 'atrair clientes'] };
  const t = respostasTexto(r);
  ok(t.indexOf('Qual é o nicho?') < t.indexOf('Quem é o público'), 'ordem');
  ok(!t.includes('lacunas'), 'vazia não entra');
  ok(t.includes('autoridade; atrair clientes'), 'lista vira texto');
  ok(t.includes('[Outro] extra'), 'chave desconhecida entra como outro');
  ok(respondidas(r) === 3, 'conta respondidas: ' + respondidas(r));
  ok(montaMensagem(r, { a: 1 }).includes('EXEMPLO (V18'), 'exemplo');
});
Deno.test('extrai JSON de resposta com cerca de código', () => {
  const o = extraiJson('Claro!\n```json\n{"nome":"X","territorios":[]}\n```');
  ok(o.nome === 'X', 'nome');
  let erro = ''; try { extraiJson('sem json'); } catch (e) { erro = (e as Error).message; }
  ok(erro.includes('JSON'), 'erro legível');
});
Deno.test('valida proposta: limpa, corrige cor e limites, recusa sem território', () => {
  const p = validaProposta({ nome: 'L', territorios: [{ nome: ' Estratégia ', cor: 'vermelho', frentes: [{ nome: 'A' }, { nome: '' }] }, { nome: 'Negócios' }],
    formatos: [{ nome: 'Yap', tipo_midia: 'tiktok', vezes_semana: '2' }, { nome: 'Música', vezes_semana: 1.5 }], meta_semanal: 500, destinos: ['Ana', ''] });
  ok(p.territorios[0].nome === 'Estratégia' && /^#/.test(p.territorios[0].cor), 'nome e cor');
  ok(p.territorios[0].frentes.length === 1, 'frente vazia sai');
  ok(p.formatos[0].tipo_midia === null && p.formatos[0].vezes_semana === 2 && p.formatos[1].vezes_semana === null, 'formatos');
  ok(p.meta_semanal === 12 && p.dia_fechamento === 6, 'meta fora do limite volta para 12');
  ok(p.destinos.length === 1, 'destino vazio sai');
  let e = ''; try { validaProposta({ territorios: [] }); } catch (x) { e = (x as Error).message; } ok(e.includes('nenhum território'), 'sem território');
  e = ''; try { validaProposta({ territorios: [{ nome: 'A' }, { nome: 'a' }] }); } catch (x) { e = (x as Error).message; } ok(e.includes('repete'), 'repetido');
  e = ''; try { validaProposta({ territorios: Array.from({ length: 7 }, (_, i) => ({ nome: 'T' + i })) }); } catch (x) { e = (x as Error).message; } ok(e.includes('mais de 6'), 'mais de 6');
});
