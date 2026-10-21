"""v0.122: mini gráfico em cada nível da árvore dos números (rosca, cascata, evolução por mês, barras por dia, medidor).
Banco fa (PostgREST 3300)."""
import sys; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
with sync_playwright() as p:
    b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
    erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
    def abre(rot, ms=4500):
        i = pg.evaluate("r => [...document.querySelectorAll('.kpi.arvk')].findIndex(k => (k.querySelector('.l').innerText || '').replace(/[\\sⓘ⚠›]+$/u, '').trim() === r)", rot)
        if i < 0: return None
        pg.locator('.kpi.arvk').nth(i).click(); pg.wait_for_timeout(ms)
        return pg.evaluate("() => [...document.querySelectorAll('#arvRoot .arv-g h3')].map(h => h.textContent)")
    front.vai(pg, 'adm-painel', "S.pg = { per: 'ano' }", 5500)
    g = abre('Receita bruta das vendas')
    chk(g and any('participação' in x or 'Evolução' in x for x in g), 'Receita bruta: gráfico no alto do painel ' + str(g))
    n0 = len(pg.evaluate("() => ARV.pilha"))
    alvo = pg.locator('#arvRoot .arv-g [data-arvno]').first
    if alvo.count(): alvo.click(force=True); pg.wait_for_timeout(3000)
    chk(len(pg.evaluate("() => ARV.pilha")) == n0 + 1, 'clicar no gráfico desce um nível, igual à lista')
    chk(pg.locator('#arvRoot .arv-g').count() >= 1 or 'não tem mais níveis' in pg.inner_text('#arvRoot'), 'o nível de baixo também tem gráfico')
    pg.evaluate("() => arvFecha()")
    g = abre('Lucro'); chk(g and any('Como se chega' in x for x in g), 'Lucro: cascata receita − deduções − despesas ' + str(g)); pg.evaluate("() => arvFecha()")
    front.vai(pg, 'mkt-trafego', "S.tDe = '2026-09-16'; S.tAte = '2026-10-15'; S.tCamp = ''; S.tCanal = ''; S.tDia = ''", 5500)
    g = abre('CAC', 6000); chk(g and any('Evolução nos últimos meses' in x for x in g), 'CAC: evolução dos últimos meses calculada mês a mês ' + str(g))
    cor = pg.evaluate("() => { const s = document.querySelector('#arvRoot .arv-g h3 span'); return s ? s.className : '' }")
    alta = pg.evaluate("() => (document.querySelector('#arvRoot .arv-g h3 span') || {}).textContent || ''")
    chk(not alta or (('▲' in alta) == ('vneg' in cor)), 'CAC subindo fica vermelho; caindo, verde')
    pg.evaluate("() => arvFecha()")
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:3]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
