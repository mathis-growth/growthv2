"""v0.241: Growth's Content → Produção na ordem de leitura: contagem por etapa, depois o Kanban, depois "Esta semana" e o calendário.
Tela: a contagem vem antes do Kanban; o calendário vem depois; clicar na etapa da contagem e numa semana do calendário continuam funcionando;
a aba "Baú de ideias" continua. Banco fa (Escola Aurora)."""
import sys, os, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots241/'; os.makedirs(SHOT, exist_ok=True)
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'mkt-cont', "S.ct = S.ct || {}; S.ct.tab = 'kanban'; S.ct.peca = null;", 5000)
    pg.wait_for_selector('#ctTab .board', timeout=15000)
    ordem = pg.evaluate("""() => { const t = document.querySelector('#ctTab'), pos = s => { const e = t.querySelector(s); return e ? [...t.querySelectorAll('*')].indexOf(e) : -1; };
      return [pos('.kb-ets'), pos('.board'), pos('.kb-cal-sec'), pos('.kb-cal')]; }""")
    chk(ordem[0] >= 0 and ordem[0] < ordem[1] < ordem[2] and ordem[3] > ordem[2], 'contagem por etapa → Kanban → esta semana e calendário', ordem)
    chk('Baú de ideias' in (pg.text_content('#main .tabs') or ''), 'a aba "Baú de ideias" continua')
    pg.screenshot(path=SHOT + '1_producao.png', full_page=True)
    pg.click('#ctTab [data-kbcol="pauta"]'); pg.wait_for_timeout(500)
    chk(pg.locator('.colk[data-col="pauta"]').count() == 1, 'clicar na etapa da contagem leva à coluna do Kanban')
    pg.click('#ctTab [data-kbsem]'); pg.wait_for_timeout(3000)
    chk(pg.evaluate("() => S.ct.tab") == 'plano', 'clicar numa semana do calendário abre o planejamento da semana')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
