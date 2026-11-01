import json, os, tempfile
# Teste de tela da v0.195: no mapa da estratégia, Order bump e Downsell na biblioteca (com métricas próprias); tela cheia (Esc fecha);
# zoom pelos botões a partir do centro, com o percentual; dois cliques no nome do bloco editam ali mesmo (renomeia as métricas junto);
# dois cliques na ligação abrem o rótulo; o menu RevOps passa a se chamar Customer Success.
# Rodar: python3 tests/tela/t195_canvas_bump_downsell.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't195_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Perpétuo', tipo='perpetuo', status='ativa', ativo=True, versao_atual=1)]),
  'estrategia_blocos': ws([dict(id='b1', funil_id='f1', ordem=10, fase='conversao', tipo='checkout', nome='Checkout', props={}, x=40, y=40),
                           dict(id='b2', funil_id='f1', ordem=20, fase='aquecimento', tipo='condicao', nome='Condição', props={}, x=320, y=40)]),
  'estrategia_etapas': ws([dict(id='e1', funil_id='f1', ordem=100, fase='conversao', chave='checkout_vendas', nome='Checkout · Vendas aprovadas', origem='vendas', metrica='clientes', bloco_id='b1', papel='principal')]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b2', tipo='sim')]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 1500, 'height': 950}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML); pg.wait_for_timeout(1200)
    chk('CUSTOMER SUCCESS' in pg.inner_text('.side').upper() and 'REVOPS' not in pg.inner_text('.side').upper(), 'menu: RevOps agora se chama Customer Success')
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estAba = 'mapa'; S.cvSel = null; render();"); pg.wait_for_timeout(1800)
    if not ev(pg, "!!document.querySelector('#cvPalco')"):
        pg.evaluate("const t = [...document.querySelectorAll('button, [data-ea]')].find(x => /Mapa/.test(x.textContent)); if (t) t.click();"); pg.wait_for_timeout(1500)
    chk(ev(pg, "!!document.querySelector('#cvPalco')"), 'abre o mapa da estratégia')
    nomes = ev(pg, "[...document.querySelectorAll('.cv-pi')].map(x => x.dataset.pn)")
    chk('Order bump' in nomes and nomes.count('Downsell') == 2, 'biblioteca tem Order bump e Downsell (em Conversão e em Pós-venda)', nomes)
    pg.evaluate("[...document.querySelectorAll('.cv-pi')].filter(x => x.dataset.pn === 'Order bump').forEach(x => { x.closest('details').open = true; x.click(); })"); pg.wait_for_timeout(1500)
    ob = ev(pg, "(__D.estrategia_blocos.find(b => b.tipo === 'order_bump') || {})")
    chk(ob.get('nome') == 'Order bump' and ob.get('fase') == 'conversao', 'Order bump entra no mapa, na fase de vendas', ob)
    mets = ev(pg, "id => __D.estrategia_etapas.filter(e => e.bloco_id === id).map(e => e.nome)", ob.get('id'))
    chk(len(mets) == 3 and any('Order bumps aceitos' in m for m in mets), 'Order bump cria as métricas dele (aceitos, receita, taxa)', mets)
    pg.evaluate("[...document.querySelectorAll('.cv-pi')].filter(x => x.dataset.pn === 'Downsell')[0].click()"); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.estrategia_blocos.some(b => b.tipo === 'downsell' && b.fase === 'conversao')") and ev(pg, "!!document.querySelector('.cv-no .cv-art')"), 'Downsell entra no mapa com desenho de página')
    # zoom e tela cheia
    z0 = ev(pg, "document.querySelector('#cvZp').textContent")
    pg.click('#cvPalco [data-z="1"]'); pg.wait_for_timeout(300)
    z1 = ev(pg, "document.querySelector('#cvZp').textContent")
    chk(z0.endswith('%') and z1.endswith('%') and int(z1[:-1]) > int(z0[:-1]), 'o zoom mostra o percentual e aproxima', (z0, z1))
    h0 = ev(pg, "document.querySelector('#cvPalco').getBoundingClientRect().height")
    pg.click('#cvCheia'); pg.wait_for_timeout(500)
    h1 = ev(pg, "document.querySelector('#cvPalco').getBoundingClientRect().height")
    chk(ev(pg, "document.querySelector('.cv').classList.contains('cv-cheia')") and h1 > h0 + 100, 'Tela cheia aumenta a área do mapa', (h0, h1))
    if FOTOS: pg.screenshot(path=FOTOS + '/t195_tela_cheia.png')
    pg.keyboard.press('Escape'); pg.wait_for_timeout(400)
    chk(not ev(pg, "document.querySelector('.cv').classList.contains('cv-cheia')") and not ev(pg, "document.body.classList.contains('cv-cheia-on')"), 'Esc sai da tela cheia')
    # dois cliques no nome do bloco
    pg.locator('[data-no="b1"] .cv-nm').dblclick(); pg.wait_for_timeout(300)
    chk(ev(pg, "!!document.querySelector('[data-no=\"b1\"] .cv-nm-ed')"), 'dois cliques no nome abrem a edição ali mesmo')
    pg.fill('[data-no="b1"] .cv-nm-ed', 'Checkout principal'); pg.keyboard.press('Enter'); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b1').nome") == 'Checkout principal' and ev(pg, "__D.estrategia_etapas.find(e => e.id === 'e1').nome") == 'Checkout principal · Vendas aprovadas', 'Enter salva o nome e renomeia as métricas do bloco')
    pg.locator('[data-no="b2"] .cv-nm').dblclick(); pg.wait_for_timeout(300)
    pg.fill('[data-no="b2"] .cv-nm-ed', 'Assistiu a aula?'); pg.keyboard.press('Escape'); pg.wait_for_timeout(600)
    chk(ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b2').nome") == 'Condição', 'Esc cancela a edição do nome')
    pg.locator('[data-no="b2"] .cv-nm').dblclick(); pg.wait_for_timeout(300)
    pg.fill('[data-no="b2"] .cv-nm-ed', 'Assistiu a aula?'); pg.keyboard.press('Enter'); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b2').nome") == 'Assistiu a aula?', 'o bloco Condição ganha o nome da condição')
    # dois cliques na ligação
    pg.evaluate("const g = document.querySelector('[data-ar=\"k1\"]'); g.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }));"); pg.wait_for_timeout(500)
    chk(ev(pg, "!!document.querySelector('#modalRoot [name=rotulo]')"), 'dois cliques na ligação abrem o rótulo')
    pg.fill('#modalRoot [name=rotulo]', 'comprou'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.estrategia_conexoes.find(c => c.id === 'k1').rotulo") == 'comprou' and 'comprou' in pg.inner_text('#cvPalco'), 'o rótulo aparece na seta')
    if FOTOS: pg.screenshot(path=FOTOS + '/t195_mapa.png')
    chk(not errs, 'sem erros de página', errs[:3])
    b.close()
print('\n' + ('OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
