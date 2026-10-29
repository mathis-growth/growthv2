import json, os, tempfile
# Teste de tela da v0.167: ajustar os cards do Mapa da estratégia: arrastar por qualquer ponto (encaixa na grade de 20 px; com Alt
# solta livre), mudar o tamanho pelo canto (fica salvo e as setas acompanham) e Organizar (colunas por fase, sem um card encostar no outro).
# Rodar: python3 tests/tela/t167_canvas_ajuste.py   (FOTOS=pasta salva uma captura depois de organizar)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't167_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', 40, 40, {'canal': 'Meta Ads'}), ('b2', 20, 'aquisicao', 'trafego', 'Google Ads', 40, 240, {'canal': 'Google Ads'}),
     ('b3', 30, 'aquisicao', 'captura', 'Página de captura', 300, 140, {}),
     ('b4', 110, 'aquecimento', 'api', 'WhatsApp', 560, 40, {'canal': 'WhatsApp'}), ('b5', 120, 'aquecimento', 'email', 'E-mail', 560, 240, {}),
     ('b6', 130, 'aquecimento', 'aula', 'Webinar', 820, 40, {}), ('b7', 140, 'aquecimento', 'condicao', 'Assistiu?', 820, 240, {}),
     ('b8', 210, 'conversao', 'pagina', 'Página de vendas', 1080, 40, {}), ('b9', 220, 'conversao', 'checkout', 'Checkout', 1080, 240, {})]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Lançamento', tipo='lancamento', categoria='Lançamento', status='ativa', ativo=True, versao_atual=0)]),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, x=x, y=y, props=pr) for a, o, fa, t, n, x, y, pr in B]),
  'estrategia_etapas': ws([]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b3', tipo='segue'), dict(id='k2', funil_id='f1', de_bloco='b3', para_bloco='b4', tipo='segue')]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
SOBRE = """(() => { const r = [...document.querySelectorAll('.cv-no')].map(n => n.getBoundingClientRect()); let k = 0;
  for (let i = 0; i < r.length; i++) for (let j = i + 1; j < r.length; j++) { const a = r[i], b = r[j]; if (a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom) k++; } return k; })()"""
def arrasta(pg, sel, dx, dy, alt=False, ox=20, oy=10):
    bx = pg.locator(sel).bounding_box()
    if alt: pg.keyboard.down('Alt')
    pg.mouse.move(bx['x'] + ox, bx['y'] + oy); pg.mouse.down(); pg.mouse.move(bx['x'] + ox + dx, bx['y'] + oy + dy, steps=8); pg.mouse.up()
    if alt: pg.keyboard.up('Alt')
    pg.wait_for_timeout(800)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estVista = 'mapa'; S.cvView = { f: 'f1', x: 0, y: 0, z: 1, ajustado: true }; render();"); pg.wait_for_timeout(1400)
    blk = lambda id: ev(pg, "id => __D.estrategia_blocos.find(b => b.id === id)", id)
    # arrastar pelo meio do card (no desenho), não só pelo topo
    arrasta(pg, '[data-no=b5] .cv-art', 50, 80, ox=40, oy=30)
    b5 = blk('b5'); chk((b5['x'], b5['y']) != (560, 240), 'arrastar pelo meio do card move o card', b5)
    chk(b5['x'] % 20 == 0 and b5['y'] % 20 == 0, 'o card encaixa na grade de 20 px', (b5['x'], b5['y']))
    arrasta(pg, '[data-no=b5] .cv-nm', 13, 7, alt=True, ox=5, oy=5)
    b5b = blk('b5'); chk(b5b['x'] % 20 != 0 or b5b['y'] % 20 != 0, 'com Alt o card solta livre, fora da grade', (b5b['x'], b5b['y']))
    # clicar sem arrastar continua selecionando, sem mover
    pg.click('[data-no=b7] .cv-nm'); pg.wait_for_timeout(400)
    chk(ev(pg, "(document.querySelector('#cvFb [name=nome]') || {}).value") == 'Assistiu?', 'clicar no card (sem arrastar) abre as propriedades')
    chk(blk('b7')['x'] == 820 and blk('b7')['y'] == 240, 'clicar não muda a posição')
    # tamanho pelo canto
    d0 = ev(pg, "document.querySelector('[data-ar=k1] .cv-ln').getAttribute('d')")
    chk(pg.locator('[data-no=b1] [data-rs]').count() == 1, 'o card tem o canto de tamanho')
    arrasta(pg, '[data-no=b1] [data-rs]', 100, 60, ox=6, oy=6)
    t1 = (blk('b1').get('props') or {}).get('tam')
    chk(t1 and 1.3 <= t1 <= 1.7, 'arrastar o canto aumenta o card e salva o tamanho', t1)
    chk(ev(pg, "document.querySelector('[data-no=b1]').style.transform").startswith('scale(1.'), 'o card aparece maior')
    chk(ev(pg, "document.querySelector('[data-ar=k1] .cv-ln').getAttribute('d')") != d0, 'a seta acompanha o tamanho novo')
    chk(blk('b1')['x'] == 40 and blk('b1')['y'] == 40, 'mudar o tamanho não move o card')
    pg.evaluate("render();"); pg.wait_for_timeout(1200)
    chk(ev(pg, "document.querySelector('[data-no=b1]').style.transform") == 'scale(' + str(t1) + ')', 'o tamanho continua depois de abrir de novo', ev(pg, "document.querySelector('[data-no=b1]').style.transform"))
    arrasta(pg, '[data-no=b2] [data-rs]', -300, 0, ox=6, oy=6)
    chk((blk('b2').get('props') or {}).get('tam') == 0.6, 'o card não fica menor que 60%', blk('b2').get('props'))
    # Organizar
    pg.click('#cvOrg'); pg.wait_for_timeout(400)
    chk('colunas por fase' in ev(pg, "document.querySelector('#modalRoot').innerText"), 'Organizar pede confirmação')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(2000)
    bs = ev(pg, "__D.estrategia_blocos.map(b => ({ id: b.id, fase: b.fase, ordem: b.ordem, x: b.x, y: b.y }))")
    xs = {f: sorted({b['x'] for b in bs if b['fase'] == f}) for f in ['aquisicao', 'aquecimento', 'conversao']}
    chk(all(len(v) == 1 for v in xs.values()) and xs['aquisicao'][0] < xs['aquecimento'][0] < xs['conversao'][0], 'Organizar: uma coluna por fase, da esquerda para a direita', xs)
    aq = sorted([b for b in bs if b['fase'] == 'aquecimento'], key=lambda b: b['ordem'])
    chk([b['y'] for b in aq] == sorted(b['y'] for b in aq), 'na coluna, na ordem da fase', aq)
    chk(all(b['x'] % 20 == 0 and b['y'] % 20 == 0 for b in bs), 'tudo na grade')
    chk(ev(pg, SOBRE) == 0, 'depois de organizar, nenhum card encosta em outro', ev(pg, SOBRE))
    chk((blk('b1').get('props') or {}).get('tam') == t1, 'organizar mantém o tamanho de cada card')
    if FOTOS:
        pg.evaluate("S.cvView = null; render();"); pg.wait_for_timeout(1300); pg.screenshot(path=FOTOS + '/t167_organizado.png')
    # só leitura: sem mover e sem canto
    pg.evaluate("S.perm = { modulos: { mkt: 'ler', gro: 'nenhum' } }; S.permWs = S.ws; render();"); pg.wait_for_timeout(1200)
    chk(not ev(pg, "!!document.querySelector('[data-rs]')") and not ev(pg, "!!document.querySelector('.cv-mov')") and not ev(pg, "!!document.querySelector('#cvOrg')"), 'só leitura: não move, não muda o tamanho, sem Organizar')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
