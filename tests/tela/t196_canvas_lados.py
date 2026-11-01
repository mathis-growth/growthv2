import json, os, tempfile
# Teste de tela da v0.196: bolinha de ligação nos quatro lados do bloco; a ligação sai pelo lado arrastado e chega pelo lado mais perto
# de onde soltou; dá para ligar os mesmos blocos de novo por outros lados; o painel da ligação troca os lados; ligação antiga sem lado
# escolhido segue a posição dos blocos (destino embaixo: sai embaixo e chega em cima).
# Rodar: python3 tests/tela/t196_canvas_lados.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't196_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Perpétuo', tipo='perpetuo', status='ativa', ativo=True, versao_atual=1)]),
  'estrategia_blocos': ws([dict(id='b1', funil_id='f1', ordem=10, fase='conversao', tipo='checkout', nome='Checkout', props={}, x=60, y=60),
                           dict(id='b2', funil_id='f1', ordem=20, fase='conversao', tipo='downsell', nome='Downsell', props={}, x=60, y=420),
                           dict(id='b3', funil_id='f1', ordem=30, fase='conversao', tipo='order_bump', nome='Order bump', props={}, x=460, y=60),
                           dict(id='b4', funil_id='f1', ordem=40, fase='conversao', tipo='condicao', nome='Comprou?', props={}, x=460, y=420)]),
  'estrategia_etapas': ws([]),
  'estrategia_conexoes': ws([dict(id='k0', funil_id='f1', de_bloco='b3', para_bloco='b4', tipo='segue')]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def caixa(pg, sel): return pg.locator(sel).bounding_box()
def arrasta(pg, de, x, y):
    bx = caixa(pg, de); pg.mouse.move(bx['x'] + bx['width'] / 2, bx['y'] + bx['height'] / 2); pg.mouse.down()
    pg.mouse.move((bx['x'] + x) / 2, (bx['y'] + y) / 2, steps=4); pg.mouse.move(x, y, steps=6); pg.mouse.up(); pg.wait_for_timeout(1500)
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estAba = 'mapa'; S.estVista = 'mapa'; S.cvSel = null; S.cvView = { f: 'f1', x: 0, y: 0, z: .8 }; render();"); pg.wait_for_timeout(1800)
    if not ev(pg, "!!document.querySelector('#cvPalco')"):
        pg.evaluate("const t = [...document.querySelectorAll('button, [data-ea]')].find(x => /Mapa/.test(x.textContent)); if (t) t.click();"); pg.wait_for_timeout(1500)
    pg.evaluate("S.cvView.x = 0; S.cvView.y = 0; S.cvView.z = .8; S.cvView.ajustado = true; render();"); pg.wait_for_timeout(1500)
    chk(ev(pg, "!!document.querySelector('#cvPalco')"), 'abre o mapa')
    chk(ev(pg, "[...document.querySelectorAll('[data-no=\"b1\"] .cv-pino')].map(x => x.dataset.lado).sort().join('')") == 'blrt', 'cada bloco tem as quatro bolinhas: direita, esquerda, em cima e embaixo')
    # ligação antiga sem lado: destino embaixo → sai embaixo e chega em cima
    d0 = ev(pg, "document.querySelector('[data-ar=\"k0\"] .cv-ln').getAttribute('d')")
    n3, n4 = caixa(pg, '[data-no="b3"]'), caixa(pg, '[data-no="b4"]')
    chk(d0 and d0.startswith('M'), 'ligação antiga desenhada', d0)
    xs = [float(v) for v in d0[1:].split(' ')[0].split(',')]
    chk(abs(xs[0] - (460 + 95)) < 3, 'ligação antiga com o destino embaixo sai pelo meio de baixo do bloco', d0)
    # nova: arrasta a bolinha de baixo do Checkout até perto do topo do Downsell
    pg.hover('[data-no="b1"]'); pg.wait_for_timeout(200)
    b2 = caixa(pg, '[data-no="b2"]')
    arrasta(pg, '[data-no="b1"] .cv-pino[data-lado="b"]', b2['x'] + b2['width'] / 2, b2['y'] + 12)
    c1 = ev(pg, "__D.estrategia_conexoes.find(c => c.de_bloco === 'b1' && c.para_bloco === 'b2') || null")
    lados = ev(pg, "(__D.estrategia_blocos.find(b => b.id === 'b1').props.lados || {})")
    chk(c1 and lados.get(c1['id']) == {'de': 'b', 'para': 't'}, 'arrastar a bolinha de baixo até o topo do outro bloco liga de baixo para cima', (c1, lados))
    # de novo, mesmos blocos, pela esquerda chegando na esquerda
    pg.hover('[data-no="b1"]'); pg.wait_for_timeout(200)
    arrasta(pg, '[data-no="b1"] .cv-pino[data-lado="l"]', b2['x'] + 6, b2['y'] + b2['height'] / 2)
    n = ev(pg, "__D.estrategia_conexoes.filter(c => c.de_bloco === 'b1' && c.para_bloco === 'b2').length")
    chk(n == 2, 'dá para ligar os mesmos blocos de novo por outros lados (2 ligações)', n)
    # pela direita até a esquerda do Order bump
    pg.hover('[data-no="b1"]'); pg.wait_for_timeout(200)
    b3 = caixa(pg, '[data-no="b3"]')
    arrasta(pg, '[data-no="b1"] .cv-pino[data-lado="r"]', b3['x'] + 8, b3['y'] + 40)
    c3 = ev(pg, "__D.estrategia_conexoes.find(c => c.de_bloco === 'b1' && c.para_bloco === 'b3') || null")
    lados = ev(pg, "(__D.estrategia_blocos.find(b => b.id === 'b1').props.lados || {})")
    chk(c3 and lados.get(c3['id']) == {'de': 'r', 'para': 'l'}, 'direita até a esquerda do outro bloco', lados)
    # painel: trocar o lado de chegada
    ev(pg, "id => { S.cvSel = { t: 'ar', id }; render(); }", c3['id']); pg.wait_for_timeout(1500)
    chk(ev(pg, "!!document.querySelector('#cvFa [name=lado_de]') && !!document.querySelector('#cvFa [name=lado_para]')"), 'painel da ligação mostra "Sai por" e "Chega por"')
    pg.select_option('#cvFa [name=lado_para]', 't'); pg.click('#cvFa button[type=submit]'); pg.wait_for_timeout(1500)
    lados = ev(pg, "(__D.estrategia_blocos.find(b => b.id === 'b1').props.lados || {})")
    chk(lados.get(c3['id']) == {'de': 'r', 'para': 't'}, 'trocar "Chega por" para Em cima grava o lado novo', lados)
    if FOTOS: pg.screenshot(path=FOTOS + '/t196_lados.png')
    chk(not errs, 'sem erros de página', errs[:3])
    b.close()
print('\n' + ('OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
