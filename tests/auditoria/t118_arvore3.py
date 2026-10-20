"""v0.118: árvore dos números, parte 3. Caixa projetado em 30 dias, Novos em 30 dias, A qualificar; venda e conta a pagar
como registros navegáveis (venda → lançamentos → volta para a venda); números dentro das tabelas (Campanhas ativas do Painel
e coortes do Dashboard de marketing) abrem a árvore e mostram o MESMO número da célula.
Bancos: fa (PostgREST 3300). Migração 20261020300000."""
import sys; sys.path.insert(0, '.')
import front
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
CEL = """() => [...document.querySelectorAll('td.arvc')].map((td, i) => i)"""
def celulas(pg, tela, minimo):
    n = pg.locator('td.arvc').count()
    chk(n >= minimo, '%s: %d células ligadas à árvore' % (tela, n))
    ruins = []
    for i in range(n):
        txt = pg.evaluate("i => { const td = document.querySelectorAll('td.arvc')[i]; td.click(); return td.innerText.split(' / ')[0].replace(/\\s*\\([^)]*\\)/g, '').trim(); }", i)
        pg.wait_for_timeout(1300)
        raiz = pg.inner_text('#arvRoot .arv-v') if pg.locator('#arvRoot .arv-v').count() else '(erro: %s)' % pg.inner_text('#arvRoot .arv-body')[:100]
        av = pg.locator('#arvRoot .arv-aviso').count()
        if av or '(erro' in raiz: ruins.append((pg.evaluate("i => document.querySelectorAll('td.arvc')[i].closest('table').querySelectorAll('th')[document.querySelectorAll('td.arvc')[i].cellIndex].innerText", i), txt, raiz))
        pg.evaluate("() => arvFecha()")
    chk(not ruins, '%s: toda célula = raiz da árvore, sem aviso %s' % (tela, ruins[:4]))
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vh=1000)
    front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    confere(pg, 'Dashboard financeiro', ['Caixa projetado em 30 dias'])
    pg.evaluate(ABRE, 'Caixa projetado em 30 dias'); pg.wait_for_timeout(1800)
    chk(pg.locator('#arvRoot .arv-f button, #arvRoot [data-arvrot]').count() >= 3, 'Caixa 30 dias: saldo, a receber e a pagar navegáveis')
    pg.locator('#arvRoot [data-arvrot^="− A pagar"]').click(); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot tr[data-arvir]').first.click(); pg.wait_for_timeout(1800)
    chk(pg.inner_text('#arvRoot h2').startswith('Conta a pagar'), 'Caixa › A pagar › conta: abre a conta a pagar')
    pg.evaluate("() => arvFecha()")
    front.vai(pg, 'crm-dash', '', 6000)
    confere(pg, 'Dashboard de vendas', ['Novos em 30 dias', 'A qualificar'])
    front.vai(pg, 'crm-vendas', "S.vp = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    pg.evaluate(ABRE, 'Gerado (bruto)'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot tr[data-arvir]').first.click(); pg.wait_for_timeout(1800)
    t = pg.inner_text('#arvRoot .arv-body')
    chk(pg.inner_text('#arvRoot h2').startswith('Venda:') and 'Parcelas a receber' in t and 'Lançamentos contábeis desta venda' in t and 'Do bruto ao líquido' in t, 'Vendas › Gerado › venda: do bruto ao líquido, parcelas e lançamentos')
    pg.locator('#arvRoot .arv-q', has_text='Lançamentos contábeis').locator('button.arv-l').first.click(); pg.wait_for_timeout(1800)
    t = pg.inner_text('#arvRoot .arv-body')
    chk('Partidas' in t and 'Origem' in t, 'venda › lançamento: partidas e a origem')
    pg.locator('#arvRoot .arv-q', has_text='Origem').locator('button.arv-l').first.click(); pg.wait_for_timeout(1800)
    tr = pg.inner_text('#arvRoot .arv-trilha')
    chk(pg.inner_text('#arvRoot h2').startswith('Venda:') and tr.count('›') == 3, 'lançamento › Origem volta para a venda (trilha com 4 níveis: %s)' % tr.replace('\n', ' '))
    pg.evaluate("() => arvFecha()")
    front.vai(pg, 'fin-pagar', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    pg.evaluate(ABRE, 'Pago no período'); pg.wait_for_timeout(1800)
    pg.locator('#arvRoot tr[data-arvir]').first.click(); pg.wait_for_timeout(1800)
    chk(pg.inner_text('#arvRoot h2').startswith('Conta a pagar') and 'Lançamentos contábeis desta conta' in pg.inner_text('#arvRoot .arv-body'), 'Contas a pagar › Pago › conta: lançamentos da conta')
    pg.evaluate("() => arvFecha()")
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    celulas(pg, 'Painel › Campanhas ativas', 12)
    pg.evaluate("() => document.querySelector('td.arvc').click()"); pg.wait_for_timeout(1500)
    chk(pg.evaluate("() => S.view") == 'adm-painel' and pg.locator('#arvRoot .arv-v').count() == 1, 'clicar na célula abre a árvore e não abre a campanha')
    pg.evaluate("() => arvFecha()")
    for gran in ['campanha', 'mes', 'semana']:
        for cv in ['ret', 'conv', 'pos']:
            front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-08-01', fim: '2026-09-30', camp: '', funil: '', tab: 'cohorts', gran: '%s', cv: '%s', sel: null }" % (gran, cv), 6000)
            celulas(pg, 'Coortes · %s · %s' % (gran, cv), 2)
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-08-01', fim: '2026-09-30', camp: '', funil: '', tab: 'camp', gran: 'campanha', cv: 'ret', sel: null }", 6000)
    celulas(pg, 'Dashboard de marketing › Por campanha', 6)
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    ctx.close(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=800)
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    pg.evaluate("() => document.querySelector('td.arvc').click()"); pg.wait_for_timeout(1500)
    chk(pg.evaluate("() => document.querySelector('#arvRoot .arv').getBoundingClientRect().width <= innerWidth"), 'celular: célula abre o painel sem passar da borda')
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
