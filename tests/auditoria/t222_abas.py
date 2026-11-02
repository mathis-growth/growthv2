"""v0.222: padrão de abas na mesma página — Cockpit com as abas Áreas (padrão), Metas do período e Riscos e oportunidades;
o número em cada aba; a aba escolhida fica guardada; o período vale para todas. Banco fa (Escola Aurora)."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots222/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 11, 30000, 400)")
vis = lambda pg, sel: pg.evaluate(f"(() => {{ const e = document.querySelector('{sel}'); return !!e && e.offsetParent !== null; }})()")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-10', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', 'S.abas = {};', 11000)
    tabs = pg.evaluate("[...document.querySelectorAll('#main [data-abas=ck] [data-aba-k]')].map(b => b.textContent.trim())")
    chk(len(tabs) == 3 and tabs[0] == 'Áreas' and tabs[1].startswith('Metas do período') and tabs[2].startswith('Riscos e oportunidades'), 'três abas: Áreas, Metas do período, Riscos e oportunidades', tabs)
    chk(vis(pg, '#main .ck-geral') and not vis(pg, '#main .ck-metas') and not vis(pg, '#main .ck-riscos'), 'abre na aba Áreas: só os painéis das áreas aparecem')
    chk(any(c.isdigit() for c in tabs[1]) and any(c.isdigit() for c in tabs[2]), 'as abas de metas e riscos mostram quantos estão fora do esperado / em aberto', tabs)
    alt = pg.evaluate("document.querySelector('#main').scrollHeight")
    pg.screenshot(path=SHOT + '1_aba_areas.png')
    front.aba(pg, 'metas')
    chk(vis(pg, '#main .ck-metas') and not vis(pg, '#main .ck-geral') and pg.locator('#mtTraj svg').count() == 1, 'aba Metas do período: a faixa de metas com o gráfico, sem os painéis')
    pg.screenshot(path=SHOT + '2_aba_metas.png')
    front.aba(pg, 'riscos')
    chk(vis(pg, '#main .ck-riscos') and not vis(pg, '#main .ck-metas'), 'aba Riscos e oportunidades')
    pg.screenshot(path=SHOT + '3_aba_riscos.png')
    pg.select_option('#main [data-per-at]', 'mesant'); pg.wait_for_timeout(9000)
    chk(vis(pg, '#main .ck-riscos') and pg.evaluate("S.abas.ck") == 'riscos', 'mudar o período mantém a aba escolhida')
    front.vai(pg, 'crm-dash', '', 4000); front.vai(pg, 'cockpit', '', 9000)
    chk(vis(pg, '#main .ck-riscos'), 'voltar ao Cockpit abre na última aba usada')
    pg.set_viewport_size({'width': 390, 'height': 900}); front.vai(pg, 'cockpit', '', 9000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= 392"), 'celular: as abas não passam da tela')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
