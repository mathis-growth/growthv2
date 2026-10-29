import json, os, tempfile
# Teste de tela da v0.170: começar a estratégia pelo mapa. "Criar no mapa" abre um mapa em branco (rascunho); depois de montar,
# "Publicar versão" pede nome, tipo, categoria, produto e objetivo, grava a estratégia e publica a versão 1 com as etapas do mapa.
# Rascunho vazio e sem nome some ao voltar para a lista.
# Rodar: python3 tests/tela/t170_canvas_criar_no_mapa.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't170_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Teste', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'campanhas': ws([]), 'campanha_estrategias': [], 'estrategia_versoes': [],
  'funis': ws([dict(id='f0', nome='Perpétuo antigo', tipo='perpetuo', status='ativa', ativo=True, versao_atual=2)]),
  'estrategia_blocos': ws([dict(id='bz', funil_id='f0', ordem=10, fase='aquisicao', tipo='trafego', nome='Meta Ads', props={})]), 'estrategia_etapas': ws([]), 'estrategia_conexoes': ws([]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
# estrategia_publicar de mentira: faz o que a função do banco faz com a estratégia (versão 1, rascunho vira ativa)
RPC = """window.__RPC = window.__RPC || {}; window.__RPC.estrategia_publicar = a => { const f = __D.funis.find(x => x.id === a.p_funil); const v = (f.versao_atual || 0) + 1;
  __D.estrategia_versoes.push({ id: 'v' + v, workspace_id: f.workspace_id, funil_id: f.id, versao: v, nota: a.p_nota, foto: { blocos: __D.estrategia_blocos.filter(b => b.funil_id === f.id) } });
  f.versao_atual = v; if (f.status === 'rascunho') f.status = 'ativa'; return v; }; true;"""
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1500, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate(RPC)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = null; render();"); pg.wait_for_timeout(1200)
    chk(ev(pg, "(document.querySelector('#estMapa') || {}).textContent") == 'Criar no mapa' and ev(pg, "document.querySelector('#estMapa').classList.contains('pri')"), 'a lista tem "Criar no mapa" como botão principal')
    chk(ev(pg, "(document.querySelector('#estNova') || {}).textContent") == 'Nova a partir de modelo', 'o modelo continua em "Nova a partir de modelo"')
    # rascunho vazio some ao voltar
    pg.click('#estMapa'); pg.wait_for_timeout(1500)
    chk(ev(pg, "!!document.querySelector('#cvBox')") and ev(pg, "!!document.querySelector('.cv-rasc')"), 'abre o mapa em branco, com a explicação de como publicar')
    chk(ev(pg, "__D.funis.filter(f => f.status === 'rascunho').length") == 1, 'cria a estratégia como rascunho')
    pg.click('#estVolta'); pg.wait_for_timeout(1200)
    chk(ev(pg, "__D.funis.filter(f => f.status === 'rascunho').length") == 0 and ev(pg, "S.estSel") is None, 'voltar de um rascunho vazio não deixa lixo na lista')
    # monta e publica
    pg.click('#estMapa'); pg.wait_for_timeout(1500)
    fid = ev(pg, "S.estSel")
    pg.click('#estPub'); pg.wait_for_timeout(400)
    chk(not ev(pg, "!!document.querySelector('#modalRoot form')"), 'mapa vazio: não publica (pede um bloco antes)')
    for t in ['Meta Ads', 'Página de captura', 'Checkout']:
        pg.click('.cv-pi[data-pn="%s"]' % t) if pg.locator('.cv-pi[data-pn="%s"]' % t).is_visible() else pg.evaluate("t => { const x = [...document.querySelectorAll('.cv-pi')].find(e => e.dataset.pn === t); x.closest('details').open = true; x.click(); }", t)
        pg.wait_for_timeout(1200)
    chk(ev(pg, "id => __D.estrategia_blocos.filter(b => b.funil_id === id).length", fid) == 3, 'três blocos no mapa do rascunho')
    net = ev(pg, "id => __D.estrategia_etapas.filter(e => e.funil_id === id).length", fid)
    chk(net > 0, 'os blocos já criam as etapas (métricas) da estratégia', net)
    pg.click('#estPub'); pg.wait_for_timeout(500)
    chk(all(ev(pg, "k => !!document.querySelector('#modalRoot [name=' + k + ']')", k) for k in ['nome', 'tipo', 'categoria', 'produto_id', 'objetivo']), 'publicar o rascunho pede nome, tipo, categoria, produto e objetivo')
    chk(ev(pg, "document.querySelector('#modalRoot [name=nome]').value") == '', 'o nome de rascunho não vem preenchido')
    if FOTOS: pg.screenshot(path=FOTOS + '/t170_publicar.png')
    pg.fill('#modalRoot [name=nome]', 'Perpétuo antigo'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(800)
    chk(ev(pg, "!!document.querySelector('#modalRoot form')") and ev(pg, "id => __D.funis.find(f => f.id === id).status", fid) == 'rascunho', 'nome repetido: não publica e a janela continua aberta')
    pg.fill('#modalRoot [name=nome]', 'Lançamento pelo mapa'); pg.select_option('#modalRoot [name=tipo]', 'lancamento'); pg.fill('#modalRoot [name=categoria]', 'Lançamento')
    pg.select_option('#modalRoot [name=produto_id]', 'p1'); pg.fill('#modalRoot [name=objetivo]', 'Vender a mentoria')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    fz = ev(pg, "id => __D.funis.find(f => f.id === id)", fid)
    chk(fz['nome'] == 'Lançamento pelo mapa' and fz['tipo'] == 'lancamento' and fz['categoria'] == 'Lançamento' and fz['produto_id'] == 'p1' and fz['objetivo'] == 'Vender a mentoria', 'a estratégia é gravada com os dados', fz)
    chk(fz['status'] == 'ativa' and fz['versao_atual'] == 1, 'sai do rascunho e fica na versão 1', fz)
    chk((ev(pg, "(__calls.filter(c => c[0] === 'rpc' && c[1] === 'estrategia_publicar').pop() || [])[2]") or {}).get('p_funil') == fid, 'publica pela função do banco')
    chk(not ev(pg, "!!document.querySelector('.cv-rasc')") and 'versão 1' in ev(pg, "document.querySelector('.head').innerText"), 'o cabeçalho mostra a versão 1, sem o aviso de rascunho')
    pg.click('#estVolta'); pg.wait_for_timeout(1200)
    t = ev(pg, "document.querySelector('#main').innerText")
    chk('Lançamento pelo mapa' in t and 'Perpétuo antigo' in t, 'a estratégia aparece na lista de estratégias', t[:500])
    chk(ev(pg, "id => !!__D.funis.find(f => f.id === id)", fid), 'voltar de uma estratégia publicada não apaga nada')
    # estratégia já publicada: Publicar versão continua simples (só a nota)
    pg.evaluate("S.estSel = 'f0'; render();"); pg.wait_for_timeout(1200)
    pg.evaluate("document.querySelector('#estPub').click()"); pg.wait_for_timeout(400)
    chk(ev(pg, "!!document.querySelector('#modalRoot [name=nota]')") and not ev(pg, "!!document.querySelector('#modalRoot [name=nome]')"), 'estratégia já publicada: Publicar versão pede só o que mudou') if ev(pg, "!!document.querySelector('#estPub')") else None
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
