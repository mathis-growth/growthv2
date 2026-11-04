// Confere as assinaturas de vendas-plataforma com o vetor oficial da Kiwify. Rodar: node tests/edge/assina_test.mjs
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHmac } from 'node:crypto';
const src = readFileSync(new URL('../../supabase/functions/vendas-plataforma/assina.ts', import.meta.url), 'utf8').replace(/: (ArrayBuffer|string|Uint8Array)/g, '');
const f = join(mkdtempSync(join(tmpdir(), 'assina-')), 'assina.mjs'); writeFileSync(f, src);
const { confereKiwify, confereEduzz } = await import('file:///' + f.replace(/\\/g, '/'));
const by = s => new TextEncoder().encode(s);
const corpo = '{"order_id":"9b1c2d3e-0000-4000-8000-000000000001","order_status":"paid","webhook_event_type":"order_approved"}';
const casos = [
  ['Kiwify: vetor oficial', await confereKiwify('kiwify-token-de-teste', by(corpo), 'bf18f352a4f981b91dfa3f6d8742a81080ab8c86'), true],
  ['Kiwify: corpo alterado', await confereKiwify('kiwify-token-de-teste', by(corpo + ' '), 'bf18f352a4f981b91dfa3f6d8742a81080ab8c86'), false],
  ['Kiwify: sem token', await confereKiwify('', by(corpo), 'bf18f352a4f981b91dfa3f6d8742a81080ab8c86'), false],
  ['Eduzz: hexadecimal', await confereEduzz('seg', by(corpo), createHmac('sha256', 'seg').update(corpo).digest('hex')), true],
  ['Eduzz: base64', await confereEduzz('seg', by(corpo), createHmac('sha256', 'seg').update(corpo).digest('base64')), true],
  ['Eduzz: errada', await confereEduzz('seg', by(corpo), 'abc'), false]];
let ok = true; for (const [n, r, e] of casos) { console.log((r === e ? 'OK   ' : 'FALHA') + ' ' + n); ok = ok && r === e; }
console.log(ok ? 'assina: tudo OK' : 'assina: COM FALHAS'); process.exit(ok ? 0 : 1);
