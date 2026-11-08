const { chromium } = require('playwright');
(async () => { const b = await chromium.launch(); const pg = await b.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
  pg.on('pageerror', e => errs.push('page: ' + e.message)); pg.on('console', m => m.type() === 'error' && errs.push('console: ' + m.text()));
  await pg.goto('file://' + __dirname + '/teste_planav.html'); await pg.waitForTimeout(1500);
  const fr = pg.frames().find(f => f !== pg.mainFrame()); if (!fr) { console.log('sem iframe', errs); await b.close(); return; }
  fr.on && 0; pg.on('frameattached', () => {});
  const txt = async () => (await fr.$eval('#app', e => e.innerText)).replace(/\n+/g, ' | ');
  console.log('P1', (await txt()).slice(0, 500));
  for (let i = 1; i <= 14; i++) { await fr.click(`[data-ir="${i}"]`); await pg.waitForTimeout(150); if (i === 8) await fr.click('[data-copiar="todos"]'); if (i === 11) await fr.click('[data-aprovar]'); if ([2, 6, 8, 9, 12].includes(i)) console.log('P' + (i + 1), (await txt()).slice(0, 900)); await pg.screenshot({ path: `real${i + 1}.png`, fullPage: true }); }
  await pg.waitForTimeout(1600); console.log('GRAVADOS', await pg.evaluate(() => GRAVADOS.map(g => g[0] + ' ' + (g[1].nome || '') + ' ' + JSON.stringify(g[1].premissas || {}).length)));
  console.log('salvoEm', await fr.$eval('#salvoEm', e => e.textContent).catch(() => '-'), 'altura', await pg.$eval('#pvFrame', e => e.style.height));
  // troca de produto
  await fr.click('[data-ir="0"]'); const ops = await fr.$$eval('[data-selprod] option', os => os.map(o => o.value + '|' + o.textContent)); console.log('produtos', ops);
  console.log('ERRS', errs); await b.close(); })();
