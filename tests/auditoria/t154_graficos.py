"""v0.154: gráficos — negativos na escala, cascata neutra com resultado com sinal, referências tracejadas, séries sem verde/vermelho.
Banco fa (Escola Aurora). Só lê."""
import sys, json; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots154/'
import os; os.makedirs(SHOT, exist_ok=True)
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
PAINEL = """(t) => { const p = [...document.querySelectorAll('#main .panel')].find(p => (p.querySelector('h2') || {}).textContent && p.querySelector('h2').textContent.startsWith(t)); if (!p) return null; const s = p.querySelector('svg');
  return { svg: !!s, vazio: !!p.querySelector('.gc-vazio'), ys: s ? [...s.querySelectorAll('polyline')].flatMap(l => (l.getAttribute('points') || '').trim().split(/\\s+/).map(q => Number(q.split(',')[1]))) : [], h: s ? Number(s.getAttribute('viewBox').split(' ')[3]) : 0, txt: s ? s.textContent : '' }; }"""
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000, prefs={'growths_saldo_min_' + WS: '20000'})
    r = pg.evaluate("() => { const t = linhas(['a','b','c'], null, [-10, -20, null], v => String(v), true); const d = document.createElement('div'); d.innerHTML = t; const s = d.querySelector('svg'); return { pl: s.querySelectorAll('polyline').length, ys: [...s.querySelectorAll('circle')].map(c => Number(c.getAttribute('cy'))), vazio: linhas(['a'], null, [null], String, true) }; }")
    chk(all(12 <= y <= 194 for y in r['ys']) and r['pl'] == 1 and 'gc-vazio' in r['vazio'], 'gráfico de linhas antigo: valores negativos dentro da área, buraco sem dado e frase de vazio')
    front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 7000)
    cx, rm = pg.evaluate(PAINEL, 'Caixa projetado'), pg.evaluate(PAINEL, 'Resultado por mês')
    chk(cx and cx['ys'] and all(0 <= y <= cx['h'] for y in cx['ys']) and rm and rm['ys'] and all(0 <= y <= rm['h'] for y in rm['ys']), 'Financeiro: "Caixa projetado" e "Resultado por mês" aparecem com valores negativos')
    cas = pg.evaluate("() => { const s = [...document.querySelectorAll('#main svg.gc')].find(s => /resultado/i.test(s.getAttribute('aria-label') || '')); return s ? { cores: [...s.querySelectorAll('rect')].map(r => r.getAttribute('fill')), txt: [...s.querySelectorAll('text.gc-v')].map(t => t.textContent) } : null; }")
    chk(cas and cas['cores'][1:3] == ['var(--muted)', 'var(--muted)'] and cas['cores'][-1] == 'var(--s-desf)' and cas['txt'][-1].startswith('−'), 'cascata: deduções e despesas neutras; resultado vermelho com sinal ' + json.dumps(cas, ensure_ascii=False)[:200])
    sm = pg.evaluate("() => { const s = [...document.querySelectorAll('#main svg.gc')].find(s => /Caixa projetado/.test(s.getAttribute('aria-label') || '')); return s ? s.textContent : ''; }")
    chk('Saldo mínimo' in sm, 'saldo mínimo como linha de referência')
    pg.screenshot(path=SHOT + '1_financeiro.png', full_page=True); erros += pg.errs
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 7000)
    dots = pg.evaluate("() => [...document.querySelectorAll('#pgEvo circle')].map(c => c.getAttribute('fill'))")
    chk(dots and 'var(--bad)' not in dots, 'pontos na cor da série (sem vermelho pelo sinal)')
    pg.screenshot(path=SHOT + '2_dashboard.png', full_page=True); erros += pg.errs
    front.vai(pg, 'mkt-trafego', "S.tDe = '2026-09-01'; S.tAte = '2026-09-30'", 7000)
    h2 = pg.evaluate("() => [...document.querySelectorAll('#main h2')].map(h => h.textContent)")
    mini = pg.evaluate("() => [...document.querySelectorAll('.gc-mini h3 .sem-d')].map(s => s.className + ' ' + s.textContent)")
    chk(h2.count('CAC de mídia por canal') == 1 and 'Canais: investimento, clientes e retorno' in h2, 'Mídia paga: sem título repetido')
    chk(mini and all('sem-neu' in x for x in mini if '+0,' in x or '−0,' in x or '1,' in x.split()[-1][:2]) and 'do 1º ao último dia' in pg.inner_text('.gc-mini'), 'Mídia paga: setas pequenas ficam neutras e dizem a base ' + str(mini))
    pg.screenshot(path=SHOT + '3_midia.png', full_page=True); erros += pg.errs
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 7000)
    disp = pg.evaluate("() => { const s = [...document.querySelectorAll('#main svg.gc')].find(s => /por Clientes/i.test(s.getAttribute('aria-label') || '')); if (!s) return null; const t = [...s.querySelectorAll('text.gc-v')]; const r = t.map(x => x.getBBox()); let sob = 0; for (let i = 0; i < r.length; i++) for (let j = i + 1; j < r.length; j++) { const a = r[i], c = r[j]; if (a.x < c.x + c.width && c.x < a.x + a.width && a.y < c.y + c.height && c.y < a.y + a.height) sob++; } return sob; }")
    chk(disp == 0, 'dispersão de campanhas: rótulos sem sobreposição (' + str(disp) + ')')
    pg.screenshot(path=SHOT + '4_marketing.png', full_page=True); erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
