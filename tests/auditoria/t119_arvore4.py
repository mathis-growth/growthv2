"""v0.119: árvore dos números, parte 4. Custos e margens (cards montados no navegador: custo do mês, pró-labores, fixo,
variável, parcelado e pontual, ponto de equilíbrio, meta, imposto no equilíbrio, a receber no mês), tabelas de Mídia paga
(por canal e por dia) e a origem do lançamento de recebimento. Banco fa (PostgREST 3300). Migração 20261021100000."""
import sys, subprocess; sys.path.insert(0, '.')
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
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 7000)
    confere(pg, 'Custos e margens', ['Custo do mês', 'Pró-labores', 'Operação (sem pró-labore)', 'Fixo', 'Variável', 'Parcelado e pontual', 'Ponto de equilíbrio', 'Imposto no equilíbrio', 'A receber no mês'])
    chk(any(c.startswith('Para a meta de') for c in pg.evaluate(CARDS)), 'card "Para a meta de X% de lucro" ligado')
    pg.evaluate(ABRE, 'Custo do mês'); pg.wait_for_timeout(1200)
    soma = pg.evaluate("() => [...document.querySelector('#arvRoot .arv-q').querySelectorAll('.arv-l .n')].reduce((s, e) => s + parseFloat(e.innerText.replace(/[^0-9,-]/g, '').replace(',', '.')), 0)")
    raiz = float(pg.inner_text('#arvRoot .arv-v').replace('R$', '').replace('.', '').replace(',', '.').strip())
    chk(abs(soma - raiz) < 0.05, 'Custo do mês: soma por tipo = total (%s = %s)' % (soma, raiz))
    pg.locator('#arvRoot .arv-q').first.locator('button.arv-l').first.click(); pg.wait_for_timeout(1200)
    pg.locator('#arvRoot tr[data-arvir]').first.click(); pg.wait_for_timeout(1200)
    t = pg.inner_text('#arvRoot .arv-body')
    chk(pg.inner_text('#arvRoot .arv-trilha').count('›') == 2, 'Custo do mês › tipo › item (trilha de 3 níveis)')
    if pg.locator('#arvRoot button.arv-l[data-arvno="fin.conta_pagar"]').count():
        pg.locator('#arvRoot button.arv-l[data-arvno="fin.conta_pagar"]').first.click(); pg.wait_for_timeout(1800)
        chk(pg.inner_text('#arvRoot h2').startswith('Conta a pagar'), 'item › conta a pagar (do banco)')
    else:
        chk('projetado' in t.lower() or 'Recorrência' in t, 'item projetado explica a recorrência')
    pg.evaluate("() => arvFecha()")
    pg.evaluate(ABRE, 'Ponto de equilíbrio'); pg.wait_for_timeout(1200)
    t = pg.inner_text('#arvRoot .arv-body')
    chk('Custos contados no mês' in t and 'O que sai de cada real vendido' in t, 'Ponto de equilíbrio: custos e o que sai de cada real')
    pg.evaluate("() => arvFecha()")
    pg.evaluate("() => { ARV_CO = null; }"); pg.evaluate(ABRE, 'Fixo'); pg.wait_for_timeout(1000)
    chk('Abra a tela no mês' in pg.inner_text('#arvRoot .arv-body'), 'sem a foto da tela, o nó local pede para reabrir')
    pg.evaluate("() => arvFecha()")
    front.vai(pg, 'mkt-trafego', "S.tDe = '2026-09-01'; S.tAte = '2026-09-30'; S.tCamp = ''; S.tCanal = ''; S.tDia = ''", 7000)
    celulas(pg, 'Mídia paga (por canal e por dia)', 40)
    pg.evaluate("() => document.querySelector('tr[data-d] td.arvc').click()"); pg.wait_for_timeout(1200)
    chk(pg.evaluate("() => !S.tDia"), 'clicar na célula do dia não seleciona o dia')
    pg.evaluate("() => arvFecha()")
    L = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atc', "select string_agg(id::text, ',') from (select distinct on (origem_tipo) id from lancamentos where origem_tipo in ('recebimento', 'contrato_parcela') order by origem_tipo, data_fato) z"], capture_output=True, text=True).stdout.strip().split(',')
    for lid in L:
        pg.evaluate("id => arvAbrir('fin.lancamento', { lancamento: id }, {})", lid); pg.wait_for_timeout(1500)
        t = pg.inner_text('#arvRoot .arv-body')
        chk('Origem' in t and 'Parcela com vencimento' in t and ('Venda' in t or 'Contrato' in t), 'lançamento de recebimento/parcela mostra a origem')
        pg.evaluate("() => arvFecha()")
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
