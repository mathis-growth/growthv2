import json, os, tempfile
# Teste de tela da v0.171: mudar a fase pelo card (etiqueta com a fase abre as quatro fases; as métricas do bloco vão junto),
# soltar um componente dentro da faixa de uma fase cria o bloco nessa fase, e o bloco "Passagem para o CS" (Pós-venda).
# Rodar: python3 tests/tela/t171_canvas_fase_no_card.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't171_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', 40, 60), ('b2', 110, 'aquecimento', 'comunicacao', 'Automação', 340, 60),
     ('b3', 210, 'conversao', 'checkout', 'Checkout', 640, 60), ('b4', 120, 'aquecimento', 'email', 'E-mail', 340, 280)]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Funil principal', tipo='lancamento', status='ativa', ativo=True, versao_atual=0)]),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, x=x, y=y, props={}) for a, o, fa, t, n, x, y in B]),
  'estrategia_etapas': ws([dict(id='e4', funil_id='f1', ordem=1200, fase='aquecimento', chave='email1_abertos', nome='E-mail · Abertos', origem='manual', bloco_id='b4', papel='principal')]),
  'estrategia_conexoes': ws([]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
blk = lambda pg, id: ev(pg, "id => __D.estrategia_blocos.find(b => b.id === id)", id)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estVista = 'mapa'; S.cvView = { f: 'f1', x: 0, y: 0, z: 1, ajustado: true }; render();"); pg.wait_for_timeout(1400)
    chk(ev(pg, "document.querySelector('[data-fz=b2]').textContent.trim()") == 'Aquecimento ▾', 'o card mostra a fase dele (Automação em Aquecimento)')
    pg.click('[data-fz=b2]'); pg.wait_for_timeout(300)
    chk(ev(pg, "[...document.querySelectorAll('.cv-fzm [data-fzk]')].map(x => x.textContent)") == ['Captação', 'Aquecimento', 'Vendas', 'Pós-venda (CS)'], 'clicar na fase abre as quatro fases')
    if FOTOS: pg.screenshot(path=FOTOS + '/t171_menu_fase.png')
    pg.click('.cv-fzm [data-fzk=aquisicao]'); pg.wait_for_timeout(1000)
    chk(blk(pg, 'b2')['fase'] == 'aquisicao', 'escolher Captação muda a fase do bloco', blk(pg, 'b2'))
    chk(ev(pg, "document.querySelector('[data-no=b2]').dataset.fase") == 'aquisicao' and ev(pg, "document.querySelector('[data-fz=b2]').textContent.trim()") == 'Captação ▾', 'o card passa a mostrar Captação')
    chk(blk(pg, 'b2')['x'] == 340, 'mudar a fase não move o card')
    pg.click('[data-fz=b4]'); pg.wait_for_timeout(300); pg.click('.cv-fzm [data-fzk=retencao]'); pg.wait_for_timeout(1000)
    chk(blk(pg, 'b4')['fase'] == 'retencao' and ev(pg, "__D.estrategia_etapas.find(e => e.id === 'e4').fase") == 'retencao', 'as métricas do bloco vão junto para a fase nova')
    pg.click('[data-fz=b1]'); pg.wait_for_timeout(300); pg.mouse.click(1100, 900); pg.wait_for_timeout(300)
    chk(not ev(pg, "!!document.querySelector('.cv-fzm')") and blk(pg, 'b1')['fase'] == 'aquisicao', 'clicar fora fecha a escolha sem mudar nada')
    # soltar dentro da faixa de Vendas: o bloco nasce em Vendas
    n0 = len(ev(pg, "__D.estrategia_blocos"))
    ev(pg, """(() => { const bd = document.querySelector('[data-banda=conversao]').getBoundingClientRect(); const dt = new DataTransfer();
      dt.setData('text/plain', JSON.stringify({ t: 'comunicacao', n: 'Automação', x: {} }));
      document.querySelector('#cvPalco').dispatchEvent(new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer: dt, clientX: bd.left + bd.width / 2, clientY: bd.bottom - 10 })); })()""")
    pg.wait_for_timeout(1200)
    novo = ev(pg, "__D.estrategia_blocos.slice(-1)[0]")
    chk(len(ev(pg, "__D.estrategia_blocos")) == n0 + 1 and novo['fase'] == 'conversao', 'soltar a Automação dentro da faixa de Vendas cria o bloco em Vendas', novo)
    ev(pg, """(() => { const bd = document.querySelector('[data-banda=aquisicao]').getBoundingClientRect(); const dt = new DataTransfer();
      dt.setData('text/plain', JSON.stringify({ t: 'email', n: 'E-mail', x: {} }));
      document.querySelector('#cvPalco').dispatchEvent(new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer: dt, clientX: bd.left + 30, clientY: bd.bottom - 10 })); })()""")
    pg.wait_for_timeout(1200)
    novo = ev(pg, "__D.estrategia_blocos.slice(-1)[0]")
    et = ev(pg, "id => __D.estrategia_etapas.filter(e => e.bloco_id === id).map(e => e.fase)", novo['id'])
    chk(novo['fase'] == 'aquisicao' and et and all(f == 'aquisicao' for f in et), 'bloco com métricas solto em Captação: bloco e métricas em Captação', (novo['fase'], et))
    # Passagem para o CS
    chk(ev(pg, "!!document.querySelector('.cv-pi[data-pt=passagem]')"), 'a paleta tem "Passagem para o CS"')
    pg.evaluate("const x = document.querySelector('.cv-pi[data-pt=passagem]'); x.closest('details').open = true; x.click();"); pg.wait_for_timeout(1200)
    pa = [x for x in ev(pg, "__D.estrategia_blocos") if x['tipo'] == 'passagem']
    chk(pa and pa[0]['fase'] == 'retencao' and pa[0]['nome'] == 'Passagem para o CS', 'Passagem para o CS entra em Pós-venda (CS)', pa)
    chk('daqui para frente: cs' in ev(pg, "id => document.querySelector('[data-no=\"' + id + '\"]').innerText.replace(/\\s+/g, ' ')", pa[0]['id']).lower() if pa else False, 'o card da passagem avisa que dali para frente é do CS')
    if FOTOS:
        pg.evaluate("S.cvView = null; render();"); pg.wait_for_timeout(1300); pg.screenshot(path=FOTOS + '/t171_mapa.png')
    pg.evaluate("S.perm = { modulos: { mkt: 'ler', gro: 'nenhum' } }; S.permWs = S.ws; render();"); pg.wait_for_timeout(1200)
    chk(not ev(pg, "!!document.querySelector('button[data-fz]')") and ev(pg, "!!document.querySelector('span.cv-fzb')"), 'só leitura: a fase aparece, mas não muda')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
