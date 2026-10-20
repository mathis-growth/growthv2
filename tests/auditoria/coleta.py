"""Coleta os números que cada tela mostra para setembro/2026 (front real + banco local) e grava em coleta.json."""
import sys, json; sys.path.insert(0, '.')
from front import abre, vai
from playwright.sync_api import sync_playwright
KPI_JS = """() => { const o = {}; document.querySelectorAll('#main .kpi').forEach(k => { const l = (k.querySelector('.l') || {}).innerText, v = (k.querySelector('.v') || {}).innerText, s = (k.querySelector('.s') || {}).innerText;
  if (l) o[l.replace(/\\s*ⓘ\\s*$/, '').replace(/\\s+›$/, '').trim()] = [v, s]; }); return o; }"""
SET = '2026-09-01', '2026-09-30'
TELAS = [
  ('Dashboard (Administrativo)', 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", '2026-10-15', None),
  ('Dashboard de marketing', 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", '2026-10-15', None),
  ('Dashboard de mídia', 'mkt-midia', "S.md = { ini: '2026-09-01', fim: '2026-09-30', canal: '', camp: '', rel: 'canal', gran: 'dia', todos: false }", '2026-10-15', None),
  ('Mídia paga', 'mkt-trafego', "S.tDe = '2026-09-01'; S.tAte = '2026-09-30'", '2026-10-15', None),
  ('Dashboard de vendas (hoje = 30/09)', 'crm-dash', "", '2026-09-30', None),
  ('Dashboard financeiro', 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", '2026-10-15', None),
  ('Custos e margens', 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", '2026-10-15', None),
  ('Custos e margens (regime Simples III no navegador)', 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", '2026-10-15', {'custoOp:WS': json.dumps({'regime': 'simples_III', 'varPct': 0})}),
  ('RevOps dashboard (hoje = 30/09)', 'ho-dash', "S.ho = { dias: 30 }", '2026-09-30', None),
  ('Growth Model (set/2026)', 'gro-modelo', "", '2026-10-15', None),
  ('Campanhas (lista)', 'mkt-camp', "S.campSel = null", '2026-10-15', None),
]
saida = {}
with sync_playwright() as p:
    b = p.chromium.launch()
    for nome, v, prep, hoje, prefs in TELAS:
        if prefs: prefs = {k.replace('WS', 'ac56e719-7325-4062-aa47-74bc2141f89d'): x for k, x in prefs.items()}
        ctx, pg = abre(b, hoje=hoje, prefs=prefs)
        t = vai(pg, v, prep, ms=5000)
        if v == 'gro-modelo':
            pg.evaluate("() => { S.gl.de = '2026-09-01'; S.gl.n = 1; render(); }"); pg.wait_for_timeout(5000); t = pg.inner_text('#main')
            saida[nome + ' topo'] = {'kpis': {}, 'texto': pg.inner_text('#gsTopo') if pg.locator('#gsTopo').count() else '', 'erros': []}
        saida[nome] = {'kpis': pg.evaluate(KPI_JS), 'texto': t[:6000], 'erros': pg.errs[:3]}
        pg.screenshot(path='tela_%s.png' % v, full_page=True)
        print('ok', nome, len(saida[nome]['kpis']), pg.errs[:1]); ctx.close()
    b.close()
json.dump(saida, open('coleta.json', 'w'), ensure_ascii=False, indent=1)
