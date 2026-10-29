import json, os, tempfile
# Teste de tela da v0.166: no Mapa da estratégia cada bloco tem o desenho do que é (mini página com a foto e os textos, anúncio com o
# símbolo da Meta ou do Google, WhatsApp com o símbolo e a escolha API ou Grupo, vídeo, e-mail, lógica) e a paleta mostra os símbolos.
# Rodar: python3 tests/tela/t166_canvas_desenhos.py   (FOTOS=pasta salva capturas em claro e escuro)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't166_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', 40, 40, {'canal': 'Meta Ads'}), ('b2', 20, 'aquisicao', 'trafego', 'Google Ads', 40, 240, {'canal': 'Google Ads'}),
     ('b3', 30, 'aquisicao', 'captura', 'Página de captura', 300, 140, {'titulo': 'Aula grátis de tráfego', 'botao': 'Quero minha vaga', 'imagem': PNG}),
     ('b4', 110, 'aquecimento', 'api', 'WhatsApp', 560, 40, {'canal': 'WhatsApp'}), ('b5', 120, 'aquecimento', 'email', 'E-mail', 560, 240, {}),
     ('b6', 130, 'aquecimento', 'aula', 'Webinar', 820, 40, {}), ('b7', 140, 'aquecimento', 'condicao', 'Assistiu?', 820, 240, {}),
     ('b8', 210, 'conversao', 'pagina', 'Página de vendas', 1080, 40, {'preco': '12x R$ 99'}), ('b9', 220, 'conversao', 'checkout', 'Checkout', 1080, 240, {})]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f1', nome='Lançamento', tipo='lancamento', categoria='Lançamento', status='ativa', ativo=True, versao_atual=0)]),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, x=x, y=y, props=pr) for a, o, fa, t, n, x, y, pr in B]),
  'estrategia_etapas': ws([dict(id='e4', funil_id='f1', ordem=1100, fase='aquecimento', chave='api1_enviadas', nome='WhatsApp · Enviadas', origem='manual', bloco_id='b4', papel='principal')]),
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
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'mkt-estrategias'; S.estSel = 'f1'; S.estVista = 'mapa'; render();"); pg.wait_for_timeout(1400)
    art = lambda id: ev(pg, "id => { const a = document.querySelector('[data-no=' + id + '] .cv-art'); return a ? a.className + ' | ' + a.innerText.replace(/\\s+/g, ' ') : ''; }", id)
    chk('cv-art-anuncio' in art('b1') and ev(pg, "!!document.querySelector('[data-no=b1] .cv-art path[stroke=\"#0866FF\"]')"), 'Meta Ads: anúncio com o símbolo da Meta', art('b1'))
    chk('cv-art-anuncio' in art('b2') and ev(pg, "!!document.querySelector('[data-no=b2] .cv-art path[stroke=\"#EA4335\"]')"), 'Google Ads: anúncio com o símbolo do Google', art('b2'))
    a3 = art('b3')
    chk('cv-art-captura' in a3 and 'Aula grátis de tráfego' in a3 and 'Quero minha vaga' in a3 and ev(pg, "document.querySelector('[data-no=b3] .cv-art img').src.startsWith('data:image/png')"), 'captura: mini página com a foto, o título e o botão', a3)
    chk(ev(pg, "document.querySelectorAll('[data-no=b3] .cv-in').length") == 2, 'captura com os campos do formulário')
    a8 = art('b8'); chk('cv-art-vendas' in a8 and '12x R$ 99' in a8 and 'Comprar agora' in a8, 'página de vendas com preço e botão', a8)
    chk('cv-art-checkout' in art('b9') and 'Finalizar compra' in art('b9'), 'checkout desenhado')
    chk('cv-art-live' in art('b6') and 'AO VIVO' in art('b6'), 'webinar com player e AO VIVO')
    chk('cv-art-email' in art('b5') and 'cv-art-logica' in art('b7'), 'e-mail e condição desenhados')
    chk('cv-art-whats' in art('b4') and ev(pg, "!!document.querySelector('[data-no=b4] .cv-art path[fill=\"#25D366\"]')"), 'WhatsApp com o símbolo do WhatsApp')
    chk(ev(pg, "[...document.querySelectorAll('[data-no=b4] [data-wa]')].map(x => x.textContent + (x.classList.contains('on') ? '*' : ''))") == ['API*', 'Grupo'], 'WhatsApp: escolha API ou Grupo no bloco, API marcada')
    chk(ev(pg, "!document.querySelector('[data-no=b1] > small:not(.cv-kpi):not(.muted)')"), 'o canal não se repete em texto quando o símbolo já aparece')
    # paleta
    chk(ev(pg, "!!document.querySelector('.cv-pi[data-pn=\"Meta Ads\"] path[stroke=\"#0866FF\"]') && !!document.querySelector('.cv-pi[data-pn=\"Google Ads\"] path[stroke=\"#4285F4\"]')"), 'paleta com os símbolos da Meta e do Google')
    chk(ev(pg, "[...document.querySelectorAll('.cv-pi')].filter(x => /whatsapp/i.test(x.dataset.pn)).length") == 1, 'paleta com um WhatsApp só')
    if FOTOS:
        for tema in ['dark', 'light']:
            pg.evaluate("t => { document.documentElement.dataset.theme = t; S.cvSel = null; S.cvView = null; render(); }", tema); pg.wait_for_timeout(1300)
            pg.screenshot(path=FOTOS + '/t166_' + ('escuro' if tema == 'dark' else 'claro') + '.png')
            pg.evaluate("(() => { const V = S.cvView; V.z = 1.6; V.x = -40; V.y = 20; document.querySelector('#cvMundo').style.transform = `translate(${V.x}px,${V.y}px) scale(${V.z})`; })()"); pg.wait_for_timeout(300)
            pg.locator('#cvPalco').screenshot(path=FOTOS + '/t166_zoom_' + ('escuro' if tema == 'dark' else 'claro') + '.png')
    # trocar para Grupo
    pg.click('[data-no=b4] [data-wa=grupo]'); pg.wait_for_timeout(1200)
    b4 = ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b4')")
    chk(b4['tipo'] == 'grupo' and b4['nome'] == 'Grupo de WhatsApp', 'clicar em Grupo vira grupo de WhatsApp', b4)
    et = ev(pg, "__D.estrategia_etapas.filter(e => e.bloco_id === 'b4').map(e => e.chave)")
    chk(et and all(k.startswith('grupo') for k in et), 'as métricas trocam para as de grupo', et)
    chk(ev(pg, "[...document.querySelectorAll('[data-no=b4] [data-wa]')].map(x => x.classList.contains('on'))") == [False, True] and 'Bem-vindos ao grupo' in art('b4'), 'o bloco mostra Grupo marcado e a conversa de grupo')
    # painel: título, botão, foto por link
    pg.click('[data-no=b3] .cv-nm'); pg.wait_for_timeout(400)
    chk(all(ev(pg, "k => !!document.querySelector('#cvFb [name=' + k + ']')", k) for k in ['titulo', 'botao', 'imagem']) and ev(pg, "!!document.querySelector('#cvFoto')"), 'painel com título, botão e foto (link ou enviar)')
    pg.fill('#cvFb [name=titulo]', 'Masterclass ao vivo'); pg.fill('#cvFb [name=imagem]', 'http://inseguro.com/x.png'); pg.evaluate("document.querySelector('#cvFb').requestSubmit()"); pg.wait_for_timeout(700)
    chk(ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b3').props.titulo") == 'Aula grátis de tráfego', 'link sem https é recusado')
    pg.fill('#cvFb [name=imagem]', ''); pg.evaluate("document.querySelector('#cvFb').requestSubmit()"); pg.wait_for_timeout(900)
    pr = ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b3').props")
    chk(pr.get('titulo') == 'Masterclass ao vivo' and pr.get('imagem', '').startswith('data:image'), 'título salvo e a foto enviada continua', {k: (v[:30] if isinstance(v, str) else v) for k, v in pr.items()})
    chk('Masterclass ao vivo' in art('b3'), 'o desenho mostra o título novo')
    pg.click('#cvFotoTira'); pg.wait_for_timeout(900)
    chk('imagem' not in ev(pg, "__D.estrategia_blocos.find(b => b.id === 'b3').props") and ev(pg, "!!document.querySelector('[data-no=b3] .cv-ph')"), 'tirar a foto volta para o espaço da imagem')
    pg.set_input_files('#cvFoto', files=[{'name': 'p.png', 'mimeType': 'image/png', 'buffer': __import__('base64').b64decode(PNG.split(',')[1])}]); pg.wait_for_timeout(1200)
    chk(ev(pg, "(__D.estrategia_blocos.find(b => b.id === 'b3').props.imagem || '').startsWith('data:image/jpeg')"), 'enviar foto reduz e guarda no bloco')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
