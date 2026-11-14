const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const pg = await b.newPage({ viewport: { width: 1280, height: 950 } }); const errs = [];
  pg.on('pageerror', e => errs.push('page: ' + e.message));
  pg.on('console', m => m.type() === 'error' && errs.push('console: ' + m.text()));
  await pg.goto('file://' + __dirname + '/teste_separacao.html'); await pg.waitForTimeout(300);

  // ---- 1) adm-baseline: só a aba de baseline, sem Plano/Resultados/Campanha ----
  await pg.evaluate(() => window.abre('adm-baseline')); await pg.waitForTimeout(1200);
  let fr = pg.frames().find(f => f !== pg.mainFrame());
  console.log('BASELINE nav:', await fr.$eval('#nav', e => e.innerText.replace(/\n+/g, ' | ') || '(vazio)').catch(() => '(sem #nav)'));
  console.log('BASELINE titulo:', await pg.$eval('h1', e => e.textContent));
  console.log('BASELINE tem "Ir para o plano do ano"?', await fr.$('[data-birrota="adm-plano"]') ? 'sim' : 'NAO');
  await fr.click('[data-birrota="adm-plano"]'); await pg.waitForTimeout(200);
  console.log('BASELINE -> clique foi para:', await pg.evaluate(() => window.FOI));
  await pg.screenshot({ path: __dirname + '/v293_baseline.png', fullPage: true });

  // ---- 2) adm-plano: Plano do ano + Resultados do ano, sem baseline nem campanha ----
  await pg.evaluate(() => window.abre('adm-plano')); await pg.waitForTimeout(1200);
  fr = pg.frames().find(f => f !== pg.mainFrame());
  console.log('PLANO nav:', await fr.$eval('#nav', e => e.innerText.replace(/\n+/g, ' | ')));
  console.log('PLANO titulo:', await pg.$eval('h1', e => e.textContent));
  console.log('PLANO tem botao "Voltar ao baseline" (cross-link)?', await fr.$('[data-birrota="adm-baseline"]') ? 'sim' : 'NAO');
  console.log('PLANO tem botao "Ir para a campanha" (cross-link)?', await fr.$('[data-birrota="mkt-planav"]') ? 'sim' : 'NAO');
  await fr.click('button[role=tab]:has-text("Resultados do ano")'); await pg.waitForTimeout(300);
  console.log('PLANO depois de clicar Resultados:', (await fr.$eval('#app h2', e => e.textContent)));
  console.log('RESULTADOS tem "Planejar campanha" (cross-link)?', await fr.$('[data-birrota="mkt-planav"]') ? 'sim' : 'NAO');
  await fr.click('[data-birrota="mkt-planav"]'); await pg.waitForTimeout(200);
  console.log('RESULTADOS -> clique foi para:', await pg.evaluate(() => window.FOI));
  await pg.screenshot({ path: __dirname + '/v293_plano.png', fullPage: true });

  // ---- 3) mkt-planav: só a campanha, sem abas de baseline/plano/resultados ----
  await pg.evaluate(() => window.abre('mkt-planav')); await pg.waitForTimeout(1200);
  fr = pg.frames().find(f => f !== pg.mainFrame());
  console.log('CAMPANHA nav (deve ter so o aviso, sem abas):', await fr.$eval('#nav', e => e.innerText.replace(/\n+/g, ' | ') || '(vazio)'));
  console.log('CAMPANHA titulo:', await pg.$eval('h1', e => e.textContent));
  const txt = (await fr.$eval('#app', e => e.innerText)).replace(/\n+/g, ' | ');
  console.log('CAMPANHA passo 1:', txt.slice(0, 300));
  console.log('CAMPANHA tem botao para abrir baseline (se nao aprovado)?', await fr.$('[data-birrota="adm-baseline"]') ? 'sim' : 'NAO');
  await pg.screenshot({ path: __dirname + '/v293_campanha.png', fullPage: true });

  console.log('ERROS', errs);
  await b.close();
})();
