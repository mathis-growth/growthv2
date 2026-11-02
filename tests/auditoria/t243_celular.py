"""v0.243: celular. Blocos em sanfona (toca no título e abre ali; abrir um fecha o outro); Kanban uma coluna por vez, com as etapas como
abas no topo; formulários (janelas) em tela cheia com "← Voltar". No computador nada muda. Banco fa (Escola Aurora)."""
import sys, os, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots243/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
limpa = lambda: sql(f"delete from conteudos where workspace_id = '{WS}' and titulo like 'T243%'")
limpa(); sql(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T243 Ideia', 'ideia')")
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=390, vh=844, celular=True)
    # Kanban do Content
    front.vai(pg, 'mkt-cont', "S.ct = S.ct || {}; S.ct.tab = 'kanban'; S.ct.peca = null;", 5000)
    pg.wait_for_selector('.kb-tabs [data-kbt]', timeout=15000)
    vis = pg.evaluate("() => [...document.querySelectorAll('.mq-board > .colk')].filter(c => c.offsetParent).map(c => c.dataset.col)")
    chk(vis == ['ideia'] and 'Ideias' in (pg.text_content('.kb-tabs') or ''), 'Kanban: uma coluna por vez, com as etapas como abas no topo', vis)
    pg.click('.kb-tabs [data-kbt="1"]'); pg.wait_for_timeout(300)
    vis = pg.evaluate("() => [...document.querySelectorAll('.mq-board > .colk')].filter(c => c.offsetParent).map(c => c.dataset.col)")
    chk(vis == ['pauta'], 'tocar na aba mostra a outra etapa', vis)
    chk(pg.evaluate("() => document.documentElement.scrollWidth <= 392"), 'nada passa da largura da tela')
    pg.screenshot(path=SHOT + '1_kanban_celular.png')
    # janela em tela cheia
    pg.click('#cNovo'); pg.wait_for_timeout(800)
    w = pg.evaluate("() => { const r = document.querySelector('#modalRoot .modal').getBoundingClientRect(); return [Math.round(r.width), Math.round(r.left)]; }")
    chk(w[0] >= 385 and w[1] <= 2 and pg.locator('#modalRoot [data-volta]').is_visible(), 'a janela abre em tela cheia com "← Voltar"', w)
    pg.screenshot(path=SHOT + '2_janela_cheia.png')
    pg.click('#modalRoot [data-volta]'); pg.wait_for_timeout(300)
    chk(pg.locator('#modalRoot .modal').count() == 0, '"← Voltar" fecha a janela')
    # sanfona
    front.vai(pg, 'cfg-pacotes', '', 5000); pg.wait_for_selector('.panel.sf', timeout=15000)
    st = pg.evaluate("() => [...document.querySelectorAll('#main .panel.sf')].map(p => p.classList.contains('sf-ab'))")
    pg.wait_for_timeout(2500); st = pg.evaluate("() => [...document.querySelectorAll('#main .panel.sf')].map(p => p.classList.contains('sf-ab'))")
    chk(len(st) >= 3 and st[0] and not any(st[1:]), 'blocos em sanfona: o primeiro aberto, os outros fechados (também os que carregam depois)', st)
    pg.locator('#main .panel.sf .sf-h').nth(1).click(); pg.wait_for_timeout(600)
    st = pg.evaluate("() => [...document.querySelectorAll('#main .panel.sf')].map(p => p.classList.contains('sf-ab'))")
    chk(st[1] and not st[0], 'tocar no título abre o bloco ali mesmo e fecha o outro', st)
    pg.screenshot(path=SHOT + '3_sanfona.png')
    # CRM: Funil de leads também fica em abas
    front.vai(pg, 'crm-leads', '', 5000)
    try: pg.wait_for_selector('.kb-tabs [data-kbt]', timeout=10000); ok = True
    except Exception: ok = False
    chk(ok, 'o Funil de leads também fica uma etapa por vez no celular')
    errs = list(pg.errs); ctx.close()
    # computador: nada muda
    c2, pd = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pd, 'mkt-cont', "S.ct = S.ct || {}; S.ct.tab = 'kanban'; S.ct.peca = null;", 5000); pd.wait_for_selector('.mq-board', timeout=15000)
    chk(pd.locator('.kb-tabs').count() == 0 and pd.locator('.panel.sf').count() == 0 and pd.evaluate("() => [...document.querySelectorAll('.mq-board > .colk')].filter(c => c.offsetParent).length") >= 5, 'no computador nada muda (todas as colunas, sem sanfona)')
    pd.click('#cNovo'); pd.wait_for_timeout(600)
    chk(pd.locator('#modalRoot [data-volta]').is_hidden(), 'no computador a janela continua do tamanho de antes, sem "← Voltar"')
    errs += pd.errs; c2.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa(); sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
