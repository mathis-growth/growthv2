import json, os, tempfile
# Teste de tela da v0.168: o funil inteiro num mapa só, dividido por fase (cor no card, faixa em volta dos blocos de cada fase com o nome,
# legenda que destaca uma fase) e a correção do workspace: estratégia de outro workspace não abre e trocar de workspace fecha a estratégia
# (antes, os blocos novos iam para o workspace errado e ligar dava "Os dois blocos precisam ser desta estratégia").
# Rodar: python3 tests/tela/t168_canvas_fases.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't168_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows, w=W): return [dict(workspace_id=w, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', {'canal': 'Meta Ads'}), ('b2', 20, 'aquisicao', 'captura', 'Landing page', {}),
     ('b3', 110, 'aquecimento', 'vsl', 'VSL', {}), ('b4', 120, 'aquecimento', 'api', 'WhatsApp', {'canal': 'WhatsApp'}),
     ('b5', 210, 'conversao', 'pesquisa', 'Formulário', {}), ('b6', 220, 'conversao', 'checkout', 'Checkout', {}), ('b7', 230, 'conversao', 'comercial', 'Atendimento comercial', {}),
     ('b8', 310, 'retencao', 'posvenda', 'Onboarding', {})]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}, {'id': 'w2', 'nome': 'Operação', 'modo_produto': 'completo'}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Funil principal', tipo='lancamento', status='ativa', ativo=True, versao_atual=0)]) + ws([dict(id='fx', nome='De outro workspace', tipo='outro', status='ativa', ativo=True, versao_atual=0)], 'w2'),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, props=pr) for a, o, fa, t, n, pr in B]),
  'estrategia_etapas': ws([]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b2', tipo='segue'), dict(id='k2', funil_id='f1', de_bloco='b4', para_bloco='b7', tipo='segue')]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estVista = 'mapa'; S.cvView = null; render();"); pg.wait_for_timeout(1400)
    chk(ev(pg, "[...document.querySelectorAll('.cv-banda span')].map(x => x.textContent)") == ['Captação', 'Aquecimento', 'Vendas', 'Pós-venda (CS)'], 'uma faixa por fase, do começo ao CS', ev(pg, "[...document.querySelectorAll('.cv-banda span')].map(x => x.textContent)"))
    chk(ev(pg, "[...document.querySelectorAll('[data-fl]')].map(x => x.innerText.replace(/\\s+/g, ' '))") == ['Captação 2', 'Aquecimento 2', 'Vendas 3', 'Pós-venda (CS) 1'], 'legenda com cada fase e quantos blocos')
    dentro = ev(pg, """(() => { let ok = 0, n = 0; document.querySelectorAll('.cv-no').forEach(no => { n++; const f = no.dataset.fase, bd = document.querySelector('[data-banda=' + f + ']').getBoundingClientRect(), r = no.getBoundingClientRect();
      if (r.left >= bd.left && r.right <= bd.right && r.top >= bd.top && r.bottom <= bd.bottom) ok++; }); return [ok, n]; })()""")
    chk(dentro[0] == dentro[1], 'cada bloco fica dentro da faixa da sua fase', dentro)
    chk(ev(pg, "getComputedStyle(document.querySelector('[data-no=b6]')).borderTopColor") == 'rgb(22, 163, 74)', 'o card tem a cor da fase (Vendas em verde)')
    pg.click('[data-fl=conversao]'); pg.wait_for_timeout(300)
    chk(ev(pg, "[...document.querySelectorAll('.cv-no:not(.cv-fora)')].map(n => n.dataset.no).sort().join()") == 'b5,b6,b7', 'clicar em Vendas destaca só os blocos de vendas')
    chk(ev(pg, "document.querySelector('[data-ar=k2]').classList.contains('cv-fora')") is False and ev(pg, "document.querySelector('[data-ar=k1]').classList.contains('cv-fora')") is True, 'a seta que chega em vendas continua acesa; as outras apagam')
    if FOTOS: pg.screenshot(path=FOTOS + '/t168_destaque.png')
    pg.click('[data-fl=conversao]'); pg.wait_for_timeout(300)
    chk(ev(pg, "document.querySelectorAll('.cv-fora').length") == 0, 'clicar de novo mostra tudo')
    # mover um bloco: a faixa acompanha
    w0 = ev(pg, "document.querySelector('[data-banda=retencao]').style.left")
    bx = pg.locator('[data-no=b8] .cv-nm').bounding_box()
    pg.mouse.move(bx['x'] + 5, bx['y'] + 5); pg.mouse.down(); pg.mouse.move(bx['x'] + 125, bx['y'] + 45, steps=8); pg.mouse.up(); pg.wait_for_timeout(800)
    chk(ev(pg, "document.querySelector('[data-banda=retencao]').style.left") != w0, 'mover o bloco leva a faixa junto')
    # ligar um bloco de captação a um de vendas (a ligação vale entre fases)
    pn = pg.locator('[data-pino=b2]').bounding_box(); al = pg.locator('[data-no=b5] .cv-nm').bounding_box()
    pg.mouse.move(pn['x'] + 4, pn['y'] + 4); pg.mouse.down(); pg.mouse.move(al['x'] + 10, al['y'] + 5, steps=8); pg.mouse.up(); pg.wait_for_timeout(1000)
    chk(any(c['de_bloco'] == 'b2' and c['para_bloco'] == 'b5' for c in ev(pg, "__D.estrategia_conexoes")), 'liga Landing page (captação) ao Formulário (vendas)')
    novo = [c for c in ev(pg, "__D.estrategia_conexoes") if c['de_bloco'] == 'b2' and c['para_bloco'] == 'b5']
    chk(novo and novo[0]['workspace_id'] == 'w1', 'a ligação vai para o workspace da estratégia', novo)
    if FOTOS:
        for tema in ['dark', 'light']:
            pg.evaluate("t => { document.documentElement.dataset.theme = t; S.cvSel = null; S.cvView = null; render(); }", tema); pg.wait_for_timeout(1300)
            pg.screenshot(path=FOTOS + '/t168_fases_' + ('escuro' if tema == 'dark' else 'claro') + '.png')
    # workspace: trocar fecha a estratégia; estratégia de outro workspace não abre
    pg.evaluate("const s = document.querySelector('#wsSel'); s.value = 'w2'; s.dispatchEvent(new Event('change'));"); pg.wait_for_timeout(1300)
    chk(ev(pg, "S.estSel") is None and not ev(pg, "!!document.querySelector('#cvBox')"), 'trocar de workspace fecha a estratégia aberta')
    pg.evaluate("S.ws = S.wsBase = 'w1'; S.estSel = 'fx'; render();"); pg.wait_for_timeout(1200)
    chk(ev(pg, "S.estSel") is None and 'De outro workspace' not in ev(pg, "document.querySelector('#main').innerText"), 'estratégia de outro workspace não abre (volta para a lista)')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
