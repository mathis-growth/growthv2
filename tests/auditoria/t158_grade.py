"""v0.158: Dashboard e Dashboard financeiro em grade (blocos lado a lado). Banco fa (Escola Aurora, setembro/2026). Só lê."""
import sys, os; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots158/'; os.makedirs(SHOT, exist_ok=True)
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
CAIXA = "(sel) => { const e = typeof sel === 'string' ? document.querySelector(sel) : null; if (!e) return null; const r = e.getBoundingClientRect(); return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width) }; }"
PAINEL = "(t) => { const e = [...document.querySelectorAll('#main .panel')].find(p => ((p.querySelector(':scope > h2') || {}).textContent || '').trim().startsWith(t)); if (!e) return null; const r = e.getBoundingClientRect(); return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width) }; }"
# menor letra dos gráficos, em px na tela (texto desenhado × escala do gráfico)
LETRA = """() => { let mn = 99, onde = ''; document.querySelectorAll('#main .panel svg[viewBox] text').forEach(t => { if (t.closest('.kpi') || !t.textContent.trim() || !t.getClientRects().length) return;
  const svg = t.ownerSVGElement, k = svg.getBoundingClientRect().width / svg.viewBox.baseVal.width, px = parseFloat(getComputedStyle(t).fontSize) * k;
  if (px < mn) { mn = px; onde = (svg.closest('.panel').querySelector('h2') || {}).textContent; } }); return [Math.round(mn * 10) / 10, onde]; }"""
SET_P = "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }"
SET_F = "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }"
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    # ---------- Dashboard financeiro ----------
    front.vai(pg, 'fin-dash', SET_F, 9000)
    chk(pg.evaluate("() => document.querySelector('#main').classList.contains('grade158') && getComputedStyle(document.querySelector('#main')).display === 'grid'"), 'Financeiro em grade de 12 colunas')
    c, p = pg.evaluate(CAIXA, '#finCasc'), pg.evaluate(CAIXA, '#finPonte')
    chk(c and p and c['y'] == p['y'] and c['x'] < p['x'] and p['w'] > c['w'], 'cascata e ponte lado a lado, ponte maior ' + str((c, p)))
    a, r, bb = pg.evaluate(CAIXA, '#finSmin'), pg.evaluate(PAINEL, 'Resultado por mês'), pg.evaluate(PAINEL, 'Resultado × dinheiro')
    chk(a and r and bb and a['y'] == r['y'] == bb['y'] and a['x'] < r['x'] < bb['x'], 'caixa, resultado por mês e resultado × banco na mesma linha')
    d, s = pg.evaluate(PAINEL, 'Maiores despesas'), pg.evaluate(PAINEL, 'Saldo por conta')
    chk(d and s and d['y'] == s['y'] and d['y'] > a['y'], 'maiores despesas e saldo por conta juntos, embaixo')
    chk(pg.evaluate("() => document.querySelectorAll('#main .kpis .kpi').length === 7 && new Set([...document.querySelectorAll('#main .kpis .kpi')].map(k => Math.round(k.getBoundingClientRect().y))).size === 1"), 'os 7 cartões numa linha só')
    mn = pg.evaluate(LETRA)
    chk(mn[0] >= 9.5, 'textos dos gráficos legíveis (menor letra em px na tela) ' + str(mn))
    chk(pg.evaluate("() => [...document.querySelectorAll('#finCasc svg, #finPonte svg')].every(s => Math.abs(s.viewBox.baseVal.width - s.getBoundingClientRect().width) / s.getBoundingClientRect().width < 0.12)"), 'cascata e ponte desenhadas na largura do bloco')
    chk(pg.evaluate("() => [...document.querySelectorAll('#main .funnel .row')].every(r => r.lastElementChild.getBoundingClientRect().right <= r.closest('.panel').getBoundingClientRect().right)"), 'maiores despesas: valores dentro do bloco')
    chk(pg.locator('#finCasc [data-nar="NAR-D02"]').count() == 1 and pg.locator('#finPonte [data-nar="NAR-H01"]').count() == 1, 'frases do banco continuam nos mesmos blocos')
    pg.screenshot(path=SHOT + 't158_financeiro.png', full_page=True); erros += pg.errs
    # ---------- Dashboard ----------
    front.vai(pg, 'adm-painel', SET_P, 9000)
    e, t = pg.evaluate(CAIXA, '#pgEvo'), pg.evaluate(CAIXA, '#pgRit')
    chk(e and t and e['y'] == t['y'] and e['w'] > 1.8 * t['w'], 'Dashboard: evolução (2/3) ao lado do ritmo da meta (1/3)')
    n, pr, ca = pg.evaluate(CAIXA, '#pgNovEx'), pg.evaluate(CAIXA, '#pgProd'), pg.evaluate(CAIXA, '#pgCampR')
    chk(n and pr and ca and n['y'] == pr['y'] == ca['y'], 'novos × existentes, por produto e por campanha em três colunas')
    f, mf = pg.evaluate(PAINEL, 'Funil'), pg.evaluate(PAINEL, 'Métricas financeiras')
    chk(f and mf and f['y'] == mf['y'], 'funil ao lado das métricas financeiras')
    chk(pg.evaluate("() => { const hs = [...document.querySelectorAll('#main .secl')]; const h = hs.find(x => x.textContent.startsWith('De onde vem')); return h && h.getBoundingClientRect().y < document.querySelector('#pgNovEx').getBoundingClientRect().y; }"), 'título da seção em cima dos seus blocos')
    mn = pg.evaluate(LETRA)
    chk(mn[0] >= 9.5, 'Dashboard: textos dos gráficos legíveis ' + str(mn))
    pg.screenshot(path=SHOT + 't158_dashboard.png', full_page=True); erros += pg.errs
    # ---------- outras telas não mudam ----------
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 8000)
    chk(pg.evaluate("() => !document.querySelector('#main').classList.contains('grade158') && getComputedStyle(document.querySelector('#main')).display !== 'grid'"), 'outras telas continuam como estavam (Marketing)')
    erros += pg.errs; ctx.close()
    # ---------- celular: uma coluna ----------
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=844)
    front.vai(pg, 'fin-dash', SET_F, 9000)
    c, p = pg.evaluate(CAIXA, '#finCasc'), pg.evaluate(CAIXA, '#finPonte')
    chk(c and p and p['y'] > c['y'] and abs(c['w'] - p['w']) < 2, 'celular: blocos um embaixo do outro')
    sw = pg.evaluate('document.documentElement.scrollWidth'); chk(sw <= 396, 'celular: nada passa da tela ' + str(sw))
    pg.screenshot(path=SHOT + 't158_celular.png', full_page=True); erros += pg.errs; ctx.close()
    # ---------- tela média: blocos estreitos viram meia largura ----------
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1024, vh=900)
    front.vai(pg, 'fin-dash', SET_F, 9000)
    a, r = pg.evaluate(CAIXA, '#finSmin'), pg.evaluate(PAINEL, 'Resultado por mês')
    chk(a and r and a['y'] == r['y'] and abs(a['w'] - r['w']) < 3, 'tela média: blocos de 1/3 viram meia largura ' + str((a, r)))
    erros += pg.errs; ctx.close()
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
