import os
# Teste de tela da v0.102: visual azul em degradê, botão de modo claro/escuro guardado no navegador, sem vinho fixo sobrando.
# Rodar: python3 tests/tela/t102_visual.py
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
src = open(SP + 't92_painel_clicavel.py', encoding='utf-8').read()
cab = src[:src.index('from playwright.sync_api')].replace("'t92_growths.html'", "'t102_growths.html'")
exec(cab)
from playwright.sync_api import sync_playwright
H = open(SP + '../../frontend/index.html', encoding='utf-8').read()
chk(H.count('229,54,95') == 1, 'cor vinho fixa só sobra na definição da variável do tema antigo', H.count('229,54,95'))
with sync_playwright() as p:
    b = p.chromium.launch(); ctx = b.new_context(viewport={'width': 1400, 'height': 900}); pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(900)
    pg.evaluate("window.hoje = () => '2026-10-10'; window.provisionaAuto = async () => {}; try{localStorage.removeItem('growths_tema')}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    chk(pg.evaluate("document.documentElement.dataset.estilo") == 'azul', 'visual azul ligado')
    go(pg, 'adm-painel')
    bg = pg.evaluate("getComputedStyle(document.body).backgroundColor"); chk(bg == 'rgb(5, 10, 24)', 'começa no modo escuro (azul-marinho)', bg)
    chk('Modo claro' in pg.inner_text('#temaBtn'), 'botão oferece o modo claro')
    pg.click('#temaBtn'); pg.wait_for_timeout(300)
    bg = pg.evaluate("getComputedStyle(document.body).backgroundColor"); chk(bg == 'rgb(244, 247, 252)', 'modo claro: fundo branco-azulado', bg)
    chk(pg.evaluate("localStorage.getItem('growths_tema')") == 'light' and 'Modo escuro' in pg.inner_text('#temaBtn'), 'escolha guardada no navegador e botão troca o texto')
    pg.reload(); pg.wait_for_timeout(900)
    chk(pg.evaluate("document.documentElement.getAttribute('data-theme')") == 'light', 'ao reabrir, continua no modo claro')
    pg.evaluate("window.hoje = () => '2026-10-10'; window.provisionaAuto = async () => {}")
    go(pg, 'adm-painel')
    if not pg.locator('#nav button.on').count(): pg.click('#nav button[data-g=Administrativo]'); pg.wait_for_timeout(300)
    on = pg.evaluate("getComputedStyle(document.querySelector('#nav button.on')).backgroundImage")
    chk('linear-gradient' in on, 'item aberto do menu em degradê', on[:120])
    pg.click('#temaBtn'); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.documentElement.getAttribute('data-theme')") is None and pg.evaluate("localStorage.getItem('growths_tema')") == 'dark', 'volta para o modo escuro')
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
