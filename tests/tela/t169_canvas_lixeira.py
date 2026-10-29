import json, os, tempfile
# Teste de tela da v0.169: lixeira no card do Mapa: um clique exclui o bloco (com as métricas e as ligações) e o mapa mostra
# "Bloco ... excluído · Desfazer" por alguns segundos; Desfazer devolve o bloco, as métricas e as ligações.
# Rodar: python3 tests/tela/t169_canvas_lixeira.py   (FOTOS=pasta salva uma captura)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't169_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', 40, 40), ('b2', 20, 'aquisicao', 'captura', 'Landing page', 40, 260),
     ('b3', 210, 'conversao', 'checkout', 'Checkout', 340, 140)]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Funil principal', tipo='lancamento', status='ativa', ativo=True, versao_atual=0)]),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, x=x, y=y, props={}) for a, o, fa, t, n, x, y in B]),
  'estrategia_etapas': ws([dict(id='e1', funil_id='f1', ordem=2100, fase='aquisicao', chave='captura1_leads', nome='Landing page · Leads', origem='leads', bloco_id='b2', papel='principal'),
                           dict(id='e2', funil_id='f1', ordem=2101, fase='aquisicao', chave='captura1_taxa', nome='Landing page · Conversão', origem='manual', bloco_id='b2', papel='diagnostico')]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b2', tipo='segue'), dict(id='k2', funil_id='f1', de_bloco='b2', para_bloco='b3', tipo='sim', rotulo='Comprou')]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
# o mock não apaga em cascata como o banco: as ligações do bloco somem junto, como no Postgres (on delete cascade)
CASCATA = """(() => { const D = __D; const v = () => D.estrategia_conexoes = D.estrategia_conexoes.filter(c => D.estrategia_blocos.some(b => b.id === c.de_bloco) && D.estrategia_blocos.some(b => b.id === c.para_bloco)); setInterval(v, 50); })()"""
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate(CASCATA)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estVista = 'mapa'; S.cvView = null; render();"); pg.wait_for_timeout(1400)
    chk(ev(pg, "document.querySelectorAll('.cv-no [data-lx]').length") == 3, 'cada card tem a lixeira')
    pg.click('[data-lx=b2]'); pg.wait_for_timeout(1200)
    chk(not any(x['id'] == 'b2' for x in ev(pg, "__D.estrategia_blocos")), 'um clique na lixeira exclui o bloco, sem perguntar')
    chk(not any(x['bloco_id'] == 'b2' for x in ev(pg, "__D.estrategia_etapas")), 'as métricas do bloco saem junto')
    chk(not ev(pg, "!!document.querySelector('[data-no=b2]')") and not ev(pg, "!!document.querySelector('#modalRoot form')"), 'o card some do mapa e nenhuma janela abre')
    chk('Landing page' in ev(pg, "(document.querySelector('#cvDesf') || {}).innerText || ''") and ev(pg, "!!document.querySelector('#cvDesfBt')"), 'o mapa mostra "excluído" com Desfazer')
    if FOTOS: pg.screenshot(path=FOTOS + '/t169_desfazer.png')
    pg.click('#cvDesfBt'); pg.wait_for_timeout(1200)
    chk(any(x['id'] == 'b2' and x['x'] == 40 and x['y'] == 260 for x in ev(pg, "__D.estrategia_blocos")), 'Desfazer devolve o bloco no mesmo lugar')
    chk(sorted(x['id'] for x in ev(pg, "__D.estrategia_etapas") if x['bloco_id'] == 'b2') == ['e1', 'e2'], 'Desfazer devolve as métricas')
    cn = sorted((c['id'], c['tipo'], c.get('rotulo')) for c in ev(pg, "__D.estrategia_conexoes"))
    chk(cn == [('k1', 'segue', None), ('k2', 'sim', 'Comprou')], 'Desfazer devolve as ligações com tipo e rótulo', cn)
    chk(ev(pg, "!!document.querySelector('[data-no=b2]')") and not ev(pg, "!!document.querySelector('#cvDesf')"), 'o card volta e o aviso some')
    # clicar na lixeira não arrasta nem seleciona
    pg.click('[data-lx=b3]'); pg.wait_for_timeout(1200)
    chk(ev(pg, "(S.cvSel || {}).id") != 'b3' and not ev(pg, "!!document.querySelector('[data-no=b3]')") and not ev(pg, "!!document.querySelector('#modalRoot form')"), 'clicar na lixeira não seleciona nem abre o bloco excluído')
    pg.evaluate("S.cvDesfaz.ate = Date.now() - 1; render();"); pg.wait_for_timeout(1000)
    chk(not ev(pg, "!!document.querySelector('#cvDesf')"), 'depois do tempo, o aviso de desfazer some')
    pg.evaluate("S.perm = { modulos: { mkt: 'ler', gro: 'nenhum' } }; S.permWs = S.ws; render();"); pg.wait_for_timeout(1200)
    chk(not ev(pg, "!!document.querySelector('[data-lx]')"), 'só leitura: sem lixeira')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
