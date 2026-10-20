"""v0.117: árvore dos números, parte 2 (Contas a receber/pagar, Contratos, LTV, Churn, NRR/GRR, Custos e margens, lançamento).
Base do v0.116: Em cada tela ligada, clica em cada card com árvore e confere que a raiz da árvore mostra
o MESMO número do card. Depois desce níveis (fórmula → quebra → registros → ficha) e confere somas.
Bancos: fa (auditoria, PostgREST 3300) e escp (Escola Aurora, PostgREST 3301). Migração 20261020100000."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front, front_escola
from playwright.sync_api import sync_playwright
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
CARDS = "() => [...document.querySelectorAll('.kpi.arvk')].map(k => (k.querySelector('.l').innerText || '').replace(/[\\sⓘ⚠›]+$/u, '').trim())"
ABRE = "r => { const k = [...document.querySelectorAll('.kpi.arvk')].find(x => (x.querySelector('.l').innerText || '').replace(/[\\sⓘ⚠›]+$/u, '').trim() === r); k.click(); return (k.querySelector('.v') || {}).innerText; }"
def confere(pg, tela, esperados):
    cs = pg.evaluate(CARDS)
    chk(all(e in cs for e in esperados), '%s: cards com árvore %s' % (tela, cs))
    for r in cs:
        v = pg.evaluate(ABRE, r); pg.wait_for_timeout(1800)
        raiz = pg.inner_text('#arvRoot .arv-v') if pg.locator('#arvRoot .arv-v').count() else '(erro: %s)' % pg.inner_text('#arvRoot .arv-body')[:120]
        aviso = pg.locator('#arvRoot .arv-aviso').count()
        nr, nv = raiz.replace(' ', '').replace('\xa0', ''), (v or '').replace(' ', '').replace('\xa0', '').replace('/mês', '')
        igual = nr == nv or (nv == '—' and nr.replace('R$', '').replace('x', '').replace('%', '').strip('0,') == '')  # tela mostra "—" para zero
        chk(igual and not aviso, '%s · %s: card %s = árvore %s' % (tela, r, v, raiz))
        pg.evaluate("() => arvFecha()")
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vh=1000)
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    confere(pg, 'Dashboard', ['NRR', 'Retenção bruta (GRR)', 'Penetração de mercado'])
    pg.evaluate(ABRE, 'Lucro'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot [data-arvrot="Receitas"]').click(); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot .arv-q').first.locator('button.arv-l').first.click(); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot tr[data-arvir]').first.click(); pg.wait_for_timeout(1800)
    t = pg.inner_text('#arvRoot .arv-body')
    chk('Partidas' in t and 'partidas dobradas' in t and pg.locator('#arvRoot [data-arvpes]').count() == 1, 'Lucro › Receitas › conta › lançamento: partidas e botão da ficha')
    deb = pg.evaluate("() => [...document.querySelectorAll('#arvRoot .arv-tab tbody tr')].reduce((s, r) => s + (parseFloat((r.cells[3].innerText || '0').replace(/[^0-9,-]/g, '').replace(',', '.')) || 0), 0)")
    cre = pg.evaluate("() => [...document.querySelectorAll('#arvRoot .arv-tab tbody tr')].reduce((s, r) => s + (parseFloat((r.cells[4].innerText || '0').replace(/[^0-9,-]/g, '').replace(',', '.')) || 0), 0)")
    chk(abs(deb - cre) < 0.01 and deb > 0, 'lançamento: débitos = créditos (%s)' % deb)
    chk(pg.inner_text('#arvRoot .arv-trilha').count('›') == 3, 'trilha com 4 níveis')
    pg.locator('#arvRoot [data-arvpes]').click(); pg.wait_for_timeout(2500)
    chk(pg.locator('#modalRoot .ov').count() == 1, 'botão abre a ficha da pessoa')
    pg.evaluate("() => { document.querySelector('#modalRoot').innerHTML = ''; arvFecha(); }")
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 7000)
    confere(pg, 'Dashboard de marketing', ['LTV', 'Churn'])
    front.vai(pg, 'fin-receber', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-10-31' }", 6000)
    confere(pg, 'Contas a receber', ['A receber no período', 'Em atraso (total)', 'Recebido no período'])
    front.vai(pg, 'fin-pagar', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-10-31' }", 6000)
    confere(pg, 'Contas a pagar', ['A pagar no período', 'Em atraso (total)', 'Pago no período'])
    front.vai(pg, 'crm-contratos', '', 6000)
    confere(pg, 'Contratos', ['Contratos ativos', 'Total em contratos ativos', 'Total do mês', 'A receber (tudo em aberto)', 'Já recebido'])
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 6000)
    confere(pg, 'Custos e margens', ['Receita do mês', 'Lucro líquido'])
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
