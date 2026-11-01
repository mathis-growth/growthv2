"""v0.211/v0.212: período padrão em todos os dashboards (Administrativo, Marketing, Vendas, Mídia paga, Financeiro, Customer Success, Cockpit): o mesmo filtro (Período, De, Até) com os
mesmos atalhos, e o período escolhido vale em todos. Banco fa (Escola Aurora)."""
import sys, os, json; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
V = [('adm-painel', 'Administrativo'), ('mkt-dash', 'Marketing'), ('crm-dash', 'Vendas'), ('mkt-trafego', 'Mídia paga'), ('fin-dash', 'Financeiro'), ('ho-dash', 'Customer Success'), ('cockpit', 'Cockpit')]
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    for v, n in V:
        front.vai(pg, v, '', 6000)
        ops = pg.evaluate("[...document.querySelectorAll('#main .per-padrao [data-per-at] option')].map(o => o.textContent)")
        chk(ops == ['Últimos 30 dias', 'Este mês', 'Próximos 30 dias', 'Últimos 7 dias', 'Mês passado', 'Últimos 90 dias', 'Últimos 12 meses', 'Este ano', 'Personalizado'] and pg.locator('#main .per-padrao').count() == 1, f'{n}: o filtro padrão, com os mesmos atalhos')
        chk(pg.input_value('#main [data-per-de]') == '2026-11-01' and pg.input_value('#main [data-per-ate]') == '2026-11-30' and pg.input_value('#main [data-per-at]') == 'mes', f'{n}: começa no mês corrente (01 a 30/11)')
    # escolher "Mês passado" no Marketing vale no Vendas, no Administrativo e na Mídia paga
    front.vai(pg, 'mkt-dash', '', 6000)
    pg.select_option('#main [data-per-at]', 'mesant'); pg.wait_for_timeout(6000)
    for v, n in [('crm-dash', 'Vendas'), ('adm-painel', 'Administrativo'), ('mkt-trafego', 'Mídia paga'), ('fin-dash', 'Financeiro'), ('ho-dash', 'Customer Success'), ('cockpit', 'Cockpit')]:
        front.vai(pg, v, '', 6000)
        chk(pg.input_value('#main [data-per-de]') == '2026-10-01' and pg.input_value('#main [data-per-ate]') == '2026-10-31' and pg.input_value('#main [data-per-at]') == 'mesant', f'{n}: abre no período escolhido no Marketing (mês passado)')
    t = pg.inner_text('#main')
    chk('01/10/2026' in t or '2026-10-01' in pg.content(), 'a Mídia paga usa o período (outubro)')
    # Cockpit em outubro: a frase do topo e o Customer Success contando de 01/10 até hoje
    front.vai(pg, 'cockpit', '', 8000)
    chk('mês passado' in pg.inner_text('#main .head'), 'Cockpit: o topo diz o período escolhido')
    front.vai(pg, 'ho-dash', '', 6000)
    chk(pg.evaluate("S.ho.dias") == 32 and '32 dia(s)' in pg.inner_text('#main'), 'Customer Success: produtos de 01/10 até hoje (32 dias)')
    # Próximos 30 dias no Financeiro
    front.vai(pg, 'fin-dash', '', 8000)
    pg.select_option('#main [data-per-at]', 'prox30'); pg.wait_for_timeout(8000)
    chk(pg.input_value('#main [data-per-de]') == '2026-11-01' and pg.input_value('#main [data-per-ate]') == '2026-11-30', 'Financeiro: próximos 30 dias = 01 a 30/11')
    chk(pg.locator('#main .per-padrao').count() == 1 and pg.locator('#main #perPre').count() == 0, 'Financeiro: só o filtro padrão (o antigo saiu do dashboard)')
    # datas personalizadas
    front.vai(pg, 'crm-dash', '', 6000)
    pg.fill('#main [data-per-de]', '2026-09-15'); pg.dispatch_event('#main [data-per-de]', 'change'); pg.wait_for_timeout(5000)
    chk(pg.input_value('#main [data-per-at]') == '' and pg.input_value('#main [data-per-de]') == '2026-09-15', 'data mudada à mão: o atalho vira "Personalizado"')
    front.vai(pg, 'adm-painel', '', 6000)
    chk(pg.input_value('#main [data-per-de]') == '2026-09-15', 'Administrativo segue o período personalizado')
    secs = pg.evaluate("(() => { let e = document.querySelector('#main .per-padrao'); while (e.parentElement.id !== 'main') e = e.parentElement; return getComputedStyle(e).order; })()")
    chk(secs in ('1', '2'), 'Administrativo: o filtro fica no topo (ordem %s)' % secs)
    pg.evaluate("S.abertos['Administrativo'] = true; desenhaNav();"); pg.wait_for_timeout(300)
    chk('Planejamento da empresa' not in pg.inner_text('#nav') and 'Cadastro da empresa' in pg.inner_text('#nav'), 'v0.212: "Planejamento da empresa" saiu do menu Administrativo')
    front.vai(pg, 'adm-plano', '', 5000)
    chk(pg.evaluate("S.view") == 'mkt-camp' and pg.locator('#paAno').count() == 1, 'link antigo para o Planejamento da empresa abre o planejamento do ano')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
