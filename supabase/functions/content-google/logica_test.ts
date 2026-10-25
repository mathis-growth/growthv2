const eq = (a: unknown, b: unknown) => { if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`esperava ${JSON.stringify(b)}, veio ${JSON.stringify(a)}`); };
import { caminhos, escQ, nomeRaiz, urlLogin, voltarPara } from './logica.ts';
Deno.test('login pede só drive.file, acesso contínuo e escolha de conta', () => {
  const u = new URL(urlLogin({ clientId: 'c', redirect: 'https://x/functions/v1/content-google', estado: 'e' }));
  eq(u.searchParams.get('scope'), 'openid email https://www.googleapis.com/auth/drive.file');
  eq(u.searchParams.get('access_type'), 'offline'); eq(u.searchParams.get('state'), 'e');
  eq(u.searchParams.get('prompt'), 'consent select_account');
});
Deno.test('nome da pasta raiz', () => eq(nomeRaiz(' “Teste  Growth’s Content” '), "Growth's Content — Teste Growth’s Content"));
Deno.test('volta só para http(s)', () => {
  eq(voltarPara('javascript:alert(1)', {}), null);
  eq(voltarPara('https://growths.app/?v=mkt-cont', { google: 'ok' }), 'https://growths.app/?v=mkt-cont&google=ok');
});
Deno.test('caminhos da árvore e aspas na busca', () => {
  eq(caminhos(['01 Briefing', ' 02 Conteúdos / Roteiros ', '']), [['01 Briefing'], ['02 Conteúdos', 'Roteiros']]);
  eq(escQ("Mãe's"), "Mãe\\'s");
});
