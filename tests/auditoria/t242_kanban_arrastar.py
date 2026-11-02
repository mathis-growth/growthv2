"""v0.242: Kanban da Produção do Growth's Content: no computador só arrasta (sem "Mover para"); "Arquivar" vira botão; no celular o
"Mover para" continua. Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots242/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
limpa = lambda: sql(f"delete from conteudos where workspace_id = '{WS}' and titulo like 'T242%'")
limpa()
A = one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T242 Arrastar', 'ideia') returning id")
B = one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T242 Arquivar', 'ideia') returning id")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'mkt-cont', "S.ct = S.ct || {}; S.ct.tab = 'kanban'; S.ct.peca = null; S.ct.tema = ''; S.ct.fmt = ''; S.ct.dest = '';", 5000)
    pg.wait_for_selector(f'.mq-board .gcard[data-id="{A}"]', timeout=15000)
    chk(pg.locator(f'.gcard[data-id="{A}"] select.mv').is_hidden() and pg.locator(f'.gcard[data-id="{A}"] [data-arq]').is_visible(), 'no computador: sem "Mover para", com o botão Arquivar')
    pg.drag_and_drop(f'.gcard[data-id="{A}"]', '.colk[data-col="pauta"]'); pg.wait_for_timeout(2500)
    st = sql(f"select status from conteudos where id = '{A}'"); md = pg.evaluate("() => (document.querySelector('#modalRoot select[name=status]') || {}).value || ''")
    chk(st == 'pauta' or md == 'pauta', 'arrastar o cartão para outra coluna leva para a etapa (ou abre o cartão pedindo o que falta para ela)', (st, md))
    if pg.locator('#modalRoot [data-x]').count(): pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(500)
    pg.wait_for_selector(f'.gcard[data-id="{B}"] [data-arq]', timeout=10000); pg.click(f'.gcard[data-id="{B}"] [data-arq]'); pg.wait_for_timeout(2500)
    chk(sql(f"select status from conteudos where id = '{B}'") == 'arquivado', 'Arquivar arquiva o conteúdo')
    pg.screenshot(path=SHOT + '1_computador.png')
    errs = list(pg.errs); ctx.close()
    # celular
    c2, pm = front.abre(b, hoje='2026-11-02', vw=390, vh=844, celular=True)
    pm.evaluate("() => { S.view = 'mkt-cont'; S.ct = S.ct || {}; S.ct.tab = 'kanban'; S.ct.peca = null; render(); }"); pm.wait_for_timeout(5000)
    vis = pm.locator(f'.gcard[data-id="{A}"] select.mv').count() and pm.locator(f'.gcard[data-id="{A}"] select.mv').is_visible()
    chk(vis and pm.locator(f'.gcard[data-id="{A}"] [data-arq]').is_hidden(), 'no celular: o "Mover para" continua (arrastar com o dedo não funciona bem)')
    c2.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
