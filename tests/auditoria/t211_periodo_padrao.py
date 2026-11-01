"""v0.211: período padrão nos dashboards (Administrativo, Marketing, Vendas, Mídia paga): o mesmo filtro (Período, De, Até) com os
mesmos atalhos, e o período escolhido vale em todos. Banco fa (Escola Aurora)."""
import sys, os, json; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
V = [('adm-painel', 'Administrativo'), ('mkt-dash', 'Marketing'), ('crm-dash', 'Vendas'), ('mkt-trafego', 'Mídia paga')]
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    for v, n in V:
        front.vai(pg, v, '', 6000)
        ops = pg.evaluate("[...document.querySelectorAll('#main .per-padrao [data-per-at] option')].map(o => o.textContent)")
        chk(ops == ['Últimos 7 dias', 'Últimos 30 dias', 'Últimos 90 dias', 'Últimos 12 meses', 'Este mês', 'Mês passado', 'Este ano', 'Personalizado'] and pg.locator('#main .per-padrao').count() == 1, f'{n}: o filtro padrão, com os mesmos atalhos')
        chk(pg.input_value('#main [data-per-de]') == '2026-10-03' and pg.input_value('#main [data-per-ate]') == '2026-11-01', f'{n}: começa nos últimos 30 dias')
    # escolher "Mês passado" no Marketing vale no Vendas, no Administrativo e na Mídia paga
    front.vai(pg, 'mkt-dash', '', 6000)
    pg.select_option('#main [data-per-at]', 'mesant'); pg.wait_for_timeout(6000)
    for v, n in [('crm-dash', 'Vendas'), ('adm-painel', 'Administrativo'), ('mkt-trafego', 'Mídia paga')]:
        front.vai(pg, v, '', 6000)
        chk(pg.input_value('#main [data-per-de]') == '2026-10-01' and pg.input_value('#main [data-per-ate]') == '2026-10-31' and pg.input_value('#main [data-per-at]') == 'mesant', f'{n}: abre no período escolhido no Marketing (mês passado)')
    t = pg.inner_text('#main')
    chk('01/10/2026' in t or '2026-10-01' in pg.content(), 'a Mídia paga usa o período (outubro)')
    # datas personalizadas
    front.vai(pg, 'crm-dash', '', 6000)
    pg.fill('#main [data-per-de]', '2026-09-15'); pg.dispatch_event('#main [data-per-de]', 'change'); pg.wait_for_timeout(5000)
    chk(pg.input_value('#main [data-per-at]') == '' and pg.input_value('#main [data-per-de]') == '2026-09-15', 'data mudada à mão: o atalho vira "Personalizado"')
    front.vai(pg, 'adm-painel', '', 6000)
    chk(pg.input_value('#main [data-per-de]') == '2026-09-15', 'Administrativo segue o período personalizado')
    secs = pg.evaluate("(() => { let e = document.querySelector('#main .per-padrao'); while (e.parentElement.id !== 'main') e = e.parentElement; return getComputedStyle(e).order; })()")
    chk(secs in ('1', '2'), 'Administrativo: o filtro fica no topo (ordem %s)' % secs)
    front.vai(pg, 'adm-plano', '', 5000)
    chk(pg.locator('#plAnoAtalho').count() == 1, 'Planejamento da empresa: atalho para o planejamento do ano')
    pg.click('#plAnoIr'); pg.wait_for_timeout(5000)
    chk(pg.evaluate("S.view") == 'mkt-camp' and pg.locator('#paAno').count() == 1, 'o atalho abre Marketing › Campanhas e planejamento › Planejamento anual')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
