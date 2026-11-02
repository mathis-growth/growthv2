"""v0.216: Growth's Brain — trajetória das metas (meta acumulada × realizado acumulado, projeção) e saúde por área no Cockpit.
Banco fa (Escola Aurora), com as migrations da v0.213 a v0.215 e 20261210100000_brain_trajetoria.sql. Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots216/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
nb = lambda t: t.replace('\xa0', ' ')
def limpa():
    sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 10, 18000, 300)")
T = json.loads(sql(f"select set_config('growths.metas_interno', '1', true), metas_trajetoria('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-10-20')").split('|', 1)[1])
P, AV = T['pontos'], T['avaliacao']
real20 = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-20'"))
chk(len(P) == 31 and abs(P[-1][1] - 18000) < 0.05, 'trajetória: 31 dias e a meta acumulada termina em 18.000', (len(P), P[-1]))
chk(abs(P[19][2] - real20) < 0.01 and P[20][2] is None, 'realizado acumulado até hoje (20/10) e vazio depois', (P[19], P[20]))
chk(abs(P[19][1] - float(AV['esperado'])) < 0.02 and abs(float(AV['realizado']) - real20) < 0.01, 'o gráfico usa os mesmos números da faixa de metas (esperado e realizado)')
try:
    sql(f"select metas_trajetoria('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-10-20')"); chk(False, 'sem login, recusa')
except Exception as e: chk('Sem acesso' in str(e), 'sem login, a trajetória é recusada')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-20', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 11000)
    tj = pg.locator('#mtTraj')
    chk(tj.locator('svg.gc').count() == 1 and 'Meta acumulada' in tj.inner_text() and 'Projeção' in tj.inner_text() and tj.locator('polyline').count() == 3, 'Cockpit: gráfico de trajetória do faturamento (meta, realizado e projeção)', tj.inner_text()[:200] if tj.count() else '')
    chk('hoje' in tj.inner_text(), 'o gráfico marca o dia de hoje')
    pg.locator('#main .ck-metas').screenshot(path=SHOT + '1_trajetoria_faturamento.png')
    pg.click('#main [data-mttj] >> nth=0'); pg.wait_for_timeout(4000)
    chk(pg.locator('#modalRoot svg.gc').count() == 1 and 'Trajetória · Leads' in pg.inner_text('#modalRoot'), '"Trajetória" na linha de leads abre o gráfico de leads', pg.inner_text('#modalRoot')[:200])
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '2_trajetoria_leads.png')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    sm = nb(pg.inner_text('#main .ck-mkt .ck-saude')) if pg.locator('#main .ck-mkt .ck-saude').count() else ''
    chk('Leads' in sm and 'esperados' in sm, 'saúde do Marketing: a meta de leads com status e realizado × esperado', sm)
    sg = nb(pg.inner_text('#main .ck-geral .ck-saude')) if pg.locator('#main .ck-geral .ck-saude').count() else ''
    chk('Faturamento' in sg, 'saúde da empresa (Geral): a meta de faturamento', sg)
    sv = nb(pg.inner_text('#main .ck-ven .ck-saude')) if pg.locator('#main .ck-ven .ck-saude').count() else ''
    chk('Sem meta definida' in sv or 'Vendas' in sv, 'saúde de Vendas: sem meta de vendas, o painel diz isso (sem inventar)', sv)
    pg.screenshot(path=SHOT + '3_cockpit_saude.png', full_page=True)
    pg.set_viewport_size({'width': 390, 'height': 900}); front.vai(pg, 'cockpit', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 10000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= 392"), 'celular: nada passa da tela')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
