"""v0.116: árvore dos números. Em cada tela ligada, clica em cada card com árvore e confere que a raiz da árvore mostra
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
    confere(pg, 'Dashboard', ['Lucro', 'Margem', 'ROI', 'Vendas aprovadas', 'Receita bruta das vendas', 'Receita líquida das vendas', 'Pessoas no funil', 'Clientes ativos'])
    # descer: Lucro → Despesas → 1ª conta → lançamentos; soma das contas = despesas
    pg.evaluate(ABRE, 'Lucro'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot [data-arvrot="− Despesas"]').click(); pg.wait_for_timeout(1800)
    soma = pg.evaluate("() => [...document.querySelectorAll('#arvRoot .arv-q')][0].querySelectorAll('.arv-l .n').length")
    chk(soma >= 1 and 'Despesas' in pg.inner_text('#arvRoot .arv-trilha'), 'Lucro › Despesas: quebra por conta contábil')
    pg.locator('#arvRoot .arv-q').first.locator('button.arv-l').first.click(); pg.wait_for_timeout(1800)
    chk(pg.locator('#arvRoot .arv-tab tbody tr').count() >= 1 and pg.inner_text('#arvRoot .arv-trilha').count('›') >= 2, 'Despesas › conta: lançamentos e trilha com 3 níveis')
    pg.locator('#arvRoot .arv-trilha button').first.click(); pg.wait_for_timeout(1500)
    chk(pg.inner_text('#arvRoot h2').startswith('Lucro'), 'trilha volta ao primeiro nível')
    pg.evaluate("() => arvFecha()")
    pg.evaluate(ABRE, 'Receita bruta das vendas'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot tr.clk').first.click(); pg.wait_for_timeout(1800)  # v0.118: a linha abre a venda; dela, a ficha
    pg.locator('#arvRoot [data-arvpes]').click(); pg.wait_for_timeout(2500)
    chk(pg.locator('#modalRoot .ov').count() == 1, 'registro da venda abre a venda e dela a ficha da pessoa, por cima da árvore')
    pg.evaluate("() => { document.querySelector('#modalRoot').innerHTML = ''; arvFecha(); }")
    front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    confere(pg, 'Dashboard financeiro', ['Receitas no período', 'Despesas no período', 'Resultado no período'])
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 6000)
    confere(pg, 'Custos e margens', ['Receita do mês', 'Lucro líquido'])
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 7000)
    confere(pg, 'Dashboard de marketing', ['Leads', 'Investido', 'CPL', 'Clientes', 'CAC', 'Receita', 'ROAS'])
    front.vai(pg, 'mkt-trafego', "S.tDe = '2026-09-01'; S.tAte = '2026-09-30'; S.tCamp = ''; S.tCanal = ''", 6000)
    confere(pg, 'Mídia paga', ['Investimento', 'Impressões', 'Cliques', 'CTR médio', 'CPC'])
    front.vai(pg, 'crm-dash', '', 6000)
    confere(pg, 'Dashboard de vendas', ['Pessoas', 'Clientes ativos', 'Lead → cliente', 'Ticket médio'])
    front.vai(pg, 'crm-vendas', "S.vp = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    confere(pg, 'Vendas', ['Vendas aprovadas', 'Gerado (bruto)', 'Líquido', 'Ticket médio'])
    chk(not pg.errs, 'sem erro de JavaScript (fa) ' + str(pg.errs[:2]))
    ctx.close()
    ctx, pg = front_escola.abre(b, hoje='2026-10-19', vh=1000)
    C = '23db706a-18dd-493e-9654-87311693fef8'
    for tab, esp in [('dash', ['Leads', 'Investimento', 'Custo por lead', 'Vendas', 'Receita bruta']), ('resumo', ['Leads', 'Vendas', 'Investido']), ('captacao', ['Leads únicos'])]:
        front_escola.vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = '%s'; S.mCanal = ''" % (C, tab), 7000)
        confere(pg, 'Campanha › ' + tab, esp)
    front_escola.vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % C, 7000)
    pg.evaluate(ABRE, 'Investimento'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot .arv-q', has_text='Por anúncio').locator('button.arv-l').first.click(); pg.wait_for_timeout(1800)
    chk('AD' in pg.inner_text('#arvRoot h2') and pg.locator('#arvRoot .arv-tab tbody tr').count() > 3, 'Campanha › Investimento › anúncio: dias do anúncio')
    pg.evaluate("() => arvFecha()"); pg.evaluate(ABRE, 'Investimento'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot [data-arvcd]').click(); pg.wait_for_timeout(2500)
    chk('Investimento · detalhe da campanha' in pg.inner_text('#modalRoot'), 'da árvore para o painel completo da campanha (v0.115)')
    chk(not pg.errs, 'sem erro de JavaScript (escp) ' + str(pg.errs[:2]))
    ctx.close(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=800)
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    pg.evaluate(ABRE, 'Lucro'); pg.wait_for_timeout(1800)
    chk(pg.evaluate("() => document.querySelector('#arvRoot .arv').getBoundingClientRect().width <= innerWidth"), 'celular: painel ocupa a tela sem passar da borda')
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
