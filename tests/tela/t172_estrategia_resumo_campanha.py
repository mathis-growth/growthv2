import json, os, tempfile
# Teste de tela da v0.172: a estratégia publicada abre no Resumo (dados, versão e o funil por fase, sem abrir o editor) e o botão
# "Criar campanha" abre a nova campanha com a estratégia já escolhida; ao salvar, copia as etapas e abre a campanha.
# Rodar: python3 tests/tela/t172_estrategia_resumo_campanha.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't172_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
B = [('b1', 10, 'aquisicao', 'trafego', 'Meta Ads', {'canal': 'Meta Ads'}), ('b2', 20, 'aquisicao', 'captura', 'Landing page', {}),
     ('b3', 110, 'aquecimento', 'api', 'WhatsApp', {'canal': 'WhatsApp'}), ('b4', 210, 'conversao', 'checkout', 'Checkout', {}),
     ('b5', 310, 'retencao', 'passagem', 'Passagem para o CS', {})]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]), 'ofertas': ws([]), 'equipe': ws([]), 'etapas_catalogo': [], 'plano_metas': ws([]), 'projeto_modelos': ws([]),
  'campanhas': ws([]), 'campanha_estrategias': [],
  'estrategia_versoes': ws([dict(id='v1', funil_id='f1', versao=1, nota='Criada no mapa', publicada_em='2026-10-30T00:14:09Z', foto={})]),
  'funis': ws([dict(id='f1', nome='black friday', tipo='lancamento', categoria='Promoção', objetivo='Vender no fim de semana', produto_id='p1', status='ativa', ativo=True, versao_atual=1),
               dict(id='f2', nome='teste', tipo='outro', status='rascunho', ativo=True, versao_atual=0)]),
  'estrategia_blocos': ws([dict(id=a, funil_id='f1', ordem=o, fase=fa, tipo=t, nome=n, props=pr) for a, o, fa, t, n, pr in B] + [dict(id='bx', funil_id='f2', ordem=10, fase='aquisicao', tipo='trafego', nome='Meta Ads', props={})]),
  'estrategia_etapas': ws([dict(id='e1', funil_id='f1', ordem=100, fase='aquisicao', chave='trafego1_cliques', nome='Meta Ads · Cliques', origem='anuncios', metrica='cliques', bloco_id='b1', papel='principal'),
                           dict(id='e2', funil_id='f1', ordem=2100, fase='conversao', chave='checkout1_vendas', nome='Checkout · Vendas', origem='vendas', metrica='clientes', bloco_id='b4', papel='principal')]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b2', tipo='segue'), dict(id='k2', funil_id='f1', de_bloco='b2', para_bloco='b3', tipo='segue'),
                             dict(id='k3', funil_id='f1', de_bloco='b3', para_bloco='b4', tipo='segue'), dict(id='k4', funil_id='f1', de_bloco='b4', para_bloco='b5', tipo='segue')]),
  'rpc:campanha_aplicar_estrategia': 2,
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
    pg = b.new_page(viewport={'width': 1440, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-estrategias'; S.estSel = null; render();"); pg.wait_for_timeout(1200)
    pg.click('tr[data-est=f1]'); pg.wait_for_timeout(1400)
    chk(ev(pg, "S.estVista") == 'resumo' and ev(pg, "document.querySelector('[data-ev=resumo]').classList.contains('on')"), 'estratégia publicada abre no Resumo')
    r = ev(pg, "document.querySelector('.cv-res-p').innerText.replace(/\\s+/g, ' ')")
    chk(all(x in r for x in ['v1', 'publicada em 30/10/2026', 'Lançamento', 'Promoção', 'Mentoria', '5 blocos · 2 métricas', '4 ligações', 'Vender no fim de semana']), 'Resumo mostra versão, tipo, categoria, produto, números e objetivo', r)
    chk(ev(pg, "[...document.querySelectorAll('.cv-rh')].map(x => x.innerText.replace(/\\s+/g, ' '))") == ['CAPTAÇÃO 2', 'AQUECIMENTO 1', 'VENDAS 1', 'PÓS-VENDA (CS) 1'], 'funil por fase, da captação ao CS', ev(pg, "[...document.querySelectorAll('.cv-rh')].map(x => x.innerText)"))
    cap = ev(pg, "document.querySelector('.cv-rcol').innerText.replace(/\\s+/g, ' ')")
    chk('Meta Ads' in cap and 'Cliques' in cap and '→ Landing page' in cap, 'cada bloco com a métrica principal e para onde segue', cap)
    chk(not ev(pg, "!!document.querySelector('#cvBox')"), 'o Resumo não abre o editor')
    if FOTOS: pg.screenshot(path=FOTOS + '/t172_resumo.png', full_page=True)
    pg.click('[data-ev=mapa]'); pg.wait_for_timeout(1200)
    chk(ev(pg, "document.querySelectorAll('#cvBox .cv-no').length") == 5, 'a aba Mapa continua abrindo o editor')
    # criar campanha
    chk(ev(pg, "(document.querySelector('#estCamp') || {}).textContent") == 'Criar campanha' and ev(pg, "document.querySelector('#estCamp').classList.contains('pri')"), 'botão principal "Criar campanha" na estratégia')
    pg.click('#estCamp'); pg.wait_for_timeout(1200)
    chk(ev(pg, "document.querySelector('#modalRoot [name=funil_id]').value") == 'f1', 'a nova campanha já vem com esta estratégia escolhida')
    chk(ev(pg, "document.querySelector('#modalRoot [name=modelo]').value") == 'lancamento', 'lançamento vira campanha de lançamento')
    pg.fill('#modalRoot [name=nome]', 'Black Friday 2026'); pg.fill('#modalRoot [name=data_inicio]', '2026-11-20'); pg.fill('#modalRoot [name=data_fim]', '2026-11-30')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1800)
    c = ev(pg, "__D.campanhas.find(c => c.nome === 'Black Friday 2026')")
    chk(c and c['funil_id'] == 'f1', 'a campanha é criada com a estratégia', c)
    ap = ev(pg, "(__calls.filter(x => x[0] === 'rpc' && x[1] === 'campanha_aplicar_estrategia').pop() || [])[2]")
    chk(ap and ap.get('p_funil') == 'f1' and ap.get('p_campanha') == (c or {}).get('id'), 'as etapas da estratégia são copiadas para a campanha', ap)
    chk(ev(pg, "S.view") == 'mkt-camp' and ev(pg, "S.campSel") == (c or {}).get('id') and ev(pg, "S.estSel") is None, 'abre a campanha criada', (ev(pg, "S.view"), ev(pg, "S.campSel")))
    # rascunho: abre no Mapa; arquivada ou vazia: sem Criar campanha
    pg.evaluate("S.view = 'mkt-estrategias'; S.campSel = null; S.estSel = null; render();"); pg.wait_for_timeout(1200)
    pg.click('tr[data-est=f2]'); pg.wait_for_timeout(1300)
    chk(ev(pg, "S.estVista") == 'mapa' and ev(pg, "!!document.querySelector('#cvBox')"), 'rascunho abre no Mapa, para continuar montando')
    pg.evaluate("__D.funis.find(f => f.id === 'f1').status = 'arquivada'; __D.funis.find(f => f.id === 'f1').ativo = false; S.estSel = 'f1'; render();"); pg.wait_for_timeout(1200)
    chk(not ev(pg, "!!document.querySelector('#estCamp')"), 'estratégia arquivada: sem Criar campanha')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
