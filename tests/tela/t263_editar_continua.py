import json, os, tempfile
# Teste de tela da v0.263: Editar campanha abre no primeiro passo que falta, mostra o que já foi preenchido e não perde o que foi digitado.
# Rodar: python3 tests/tela/t263_editar_continua.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't263_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Curso de Inglês', preco=997, ativo=True), dict(id='p2', nome='Mentoria', preco=5000, ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Condição', status='rascunho', produto_id='p1', modelo='perpetuo', tipo_midia='paga', data_inicio='2027-01-01', data_fim='2027-02-01', fases={'aquisicao': {'ini': '2027-01-01', 'fim': '2027-01-20'}}, data_carrinho_abre='2027-01-25', extras={}, funil_id='f1')]),
  'campanha_ofertas': ws([dict(id='co1', campanha_id='c1', produto_id='p1', oferta_id='o1', nome='À vista', papel='principal', preco=997, ordem=0)]),
  'ofertas': ws([dict(id='o1', nome='À vista', produto_id='p1', papel='principal', preco=997, ativo=True, status='ativa', versao=1)]),
  'campanha_canais': ws([]), 'campanha_vendedores': ws([]), 'campanha_links_organicos': ws([]), 'funis': ws([dict(id='f1', nome='Estratégia X', tipo='lancamento', ativo=True)]), 'estrategia_etapas': ws([]), 'estrategia_blocos': ws([]), 'canais': ws([]), 'v_marketing_campanha': [], 'projetos': ws([]), 'pesquisas': ws([]), 'equipe': ws([])}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []; dialogos = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    def dlg(d):
        dialogos.append(d.message); d.dismiss()
    pg.on('dialog', dlg)
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; window.__RPC = { ...(window.__RPC || {}), campanha_ofertas_resultado: () => [], campanha_comercial: () => ({ vendedores: [], candidatos: [], outros: [] }) }; }""")
    pg.evaluate("abrirWizard('c1')"); pg.wait_for_timeout(1200)
    at = pg.evaluate("document.querySelector('.wzp .at').innerText")
    chk(at.startswith('4.'), 'abre no primeiro passo que falta (Histórico)', at)
    oks = pg.evaluate("[...document.querySelectorAll('.wzp .ok')].map(d => d.innerText.split('.')[0])")
    chk(oks == ['1', '2', '3'], 'marca o básico, a oferta e as datas como preenchidos', oks)
    chk('3 de 9 passos preenchidos' in pg.inner_text('#modalRoot'), 'diz quanto já foi preenchido')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'editar.png'))
    pg.click('[data-wn="1"]'); pg.wait_for_timeout(500)
    chk(pg.input_value('[name=nome]') == 'Condição' and pg.input_value('[name=produto_id]') == 'p1' and pg.input_value('[name=modelo]') == 'perpetuo' and pg.input_value('[name=funil_id]') == 'f1' and pg.input_value('[name=tipo_midia]') == 'paga' and pg.input_value('[name=data_inicio]') == '2027-01-01', 'passo 1 mostra o que já foi preenchido, com o produto')
    pg.fill('[name=nome]', 'Condição nova'); pg.wait_for_timeout(50)
    pg.click('[data-wn="2"]'); pg.wait_for_timeout(300)
    chk(len(dialogos) == 1 and pg.evaluate("document.querySelector('.wzp .at').innerText").startswith('1.'), 'trocar de passo sem salvar pergunta antes', dialogos)
    pg.mouse.click(5, 5); pg.wait_for_timeout(300)
    chk(len(dialogos) == 2 and pg.evaluate("!!document.querySelector('#modalRoot .wz')"), 'clicar fora com mudança não fecha sem perguntar', dialogos)
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(900)
    chk(pg.evaluate("document.querySelector('.wzp .at').innerText").startswith('2.') and pg.evaluate("__D.campanhas[0].nome") == 'Condição nova' and pg.evaluate("[__D.campanhas[0].modelo, __D.campanhas[0].funil_id, __D.campanhas[0].produto_id]") == ['perpetuo', 'f1', 'p1'], 'salvar grava e mantém modelo, estratégia e produto', pg.evaluate("__D.campanhas[0]"))
    pg.click('[data-wn="6"]'); pg.wait_for_timeout(700)
    chk(pg.evaluate("document.querySelector('.wzp .at').innerText").startswith('6.') and len(dialogos) == 2, 'sem mudança, vai direto a outro passo')
    pg.keyboard.press('Escape'); pg.wait_for_timeout(200)
    chk(not pg.evaluate("!!document.querySelector('#modalRoot .wz')"), 'sem mudança, Esc fecha')
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(800)
    chk(pg.evaluate("document.querySelector('.wzp .at').innerText").startswith('1.') and not pg.evaluate("!!document.querySelector('.wzp .vai')"), 'campanha nova começa no passo 1, sem pular passos')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t263:', 'tudo OK' if ok else 'COM FALHAS')
