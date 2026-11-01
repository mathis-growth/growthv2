"""v0.192: Dashboard, Dashboard financeiro e Dashboard de Vendas divididos em seções com moldura e título.
Banco fa (Escola Aurora). Só lê."""
import sys, os; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots192/'; os.makedirs(SHOT, exist_ok=True)
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
ESPERADO = {
    'adm-painel': [('Visão geral', ['.kpis.hero', '.kpis.mini']), ('Alertas', ['.gc-obs']), ('Evolução e meta', ['#pgEvo', '#pgRit']),
                   ('De onde vem a receita', ['#pgNovEx', '#pgProd', '#pgCampR']), ('Saúde financeira', ['#pgCac']), ('Funil e campanhas', []), ('Tabelas completas', ['details.gc-det'])],
    'fin-dash': [('Visão geral', ['.kpis']), ('Resultado do período', ['#finCasc', '#finPonte']), ('Resultado e despesas', []), ('Caixa e bancos', ['#finSmin']), ('Próximos vencimentos', [])],
    'crm-dash': [('Visão geral', ['.kpis']), ('Metas e renovações', []), ('Cadastros e funil', []), ('De onde vêm os clientes', []), ('Cadastros recentes', [])]
}
SECOES = "() => [...document.querySelectorAll('#main > section.dsec:not([hidden])')].sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y).map(s => s.querySelector('.dsec-h h2').textContent)"
DENTRO = "([t, sel]) => { const s = [...document.querySelectorAll('#main > section.dsec')].find(x => x.querySelector('.dsec-h h2').textContent === t); return !!s && !!s.querySelector('.dsec-b > ' + sel); }"
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-31', vw=1440, vh=1000)
    for tela, secs in ESPERADO.items():
        front.vai(pg, tela, '', 8000)
        got = pg.evaluate(SECOES)
        chk(got == [s for s, _ in secs], f'{tela}: seções na ordem {got}')
        for t, sels in secs:
            for sel in sels: chk(pg.evaluate(DENTRO, [t, sel]), f'{tela}: {sel} dentro de "{t}"')
        chk(pg.evaluate("() => [...document.querySelectorAll('#main .dsec-b')].every(b => b.children.length > 0)"), f'{tela}: nenhuma seção vazia')
        chk(pg.evaluate("() => [...document.querySelectorAll('#main .secl')].every(e => getComputedStyle(e).display === 'none')"), f'{tela}: os rótulos soltos de antes saem (a seção tem título)')
        chk(pg.evaluate("() => { const s = [...document.querySelectorAll('#main > section.dsec:not([hidden])')]; return s.every(x => getComputedStyle(x).borderTopWidth !== '0px' && getComputedStyle(x).backgroundColor !== getComputedStyle(document.querySelector('#main .dsec-b > .panel, #main .dsec-b > *')).backgroundColor); }"), f'{tela}: cada seção tem moldura e fundo diferente dos quadros')
        pg.screenshot(path=SHOT + f'{tela}.png', full_page=True)
        erros += pg.errs
    # a ação de um quadro continua funcionando depois de mudar de lugar (clicar num cartão abre o detalhe)
    front.vai(pg, 'adm-painel', '', 8000)
    pg.locator('.dsec[data-sec="geral"] .kpi.arvk').first.click(); pg.wait_for_timeout(1500)
    chk(pg.locator('#arvRoot .arv-v').count() >= 1, 'clicar num cartão da Visão geral abre o detalhe (os cliques continuam ligados)')
    # outra tela sem plano continua sem seções
    front.vai(pg, 'mkt-dash', '', 6000)
    chk(pg.locator('#main > section.dsec').count() == 0 and not pg.evaluate("document.querySelector('#main').classList.contains('secoes192')"), 'Marketing continua como estava')
    erros += pg.errs; ctx.close()
    # celular e modo escuro
    ctx, pg = front.abre(b, hoje='2026-10-31', vw=390, vh=844)
    front.vai(pg, 'adm-painel', "document.documentElement.setAttribute('data-theme', 'dark');", 8000)
    sw = pg.evaluate('document.documentElement.scrollWidth')
    chk(sw <= 396, 'celular: nada passa da tela ' + str(sw))
    chk(pg.evaluate("() => [...document.querySelectorAll('#main .dsec-b > *')].every(e => Math.abs(e.getBoundingClientRect().width - e.parentElement.getBoundingClientRect().width) < 2)"), 'celular: um quadro embaixo do outro dentro da seção')
    pg.screenshot(path=SHOT + 'celular.png', full_page=True); erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
