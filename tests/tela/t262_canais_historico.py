import json, os, tempfile
# Teste de tela da v0.262: passo Canais mostra a porcentagem de cada canal nas últimas campanhas; Planejamento sem os blocos repetidos.
# Rodar: python3 tests/tela/t262_canais_historico.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't262_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def camp(id, nome, fim, st='finalizada'): return dict(id=id, nome=nome, status=st, produto_id='p1', modelo='lancamento', data_inicio=fim[:8] + '01', data_fim=fim, extras={}, fases={}, criado_em='2026-01-01')
def vis(id, inv, ld, vd): return dict(campanha_id=id, investimento=inv, leads=ld, vendas=vd, clientes=vd, faturamento=vd * 100, receita=vd * 100, receita_bruta=vd * 100, qualificados=0)
SEED = {'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Curso', preco=997, ativo=True)]), 'ofertas': ws([]), 'campanha_ofertas': ws([]),
  'campanhas': ws([dict(camp('atual', 'Lançamento Novembro', '2026-12-30', 'rascunho'), orcamento_total=10000, meta_leads=1000, meta_vendas=100, data_carrinho_abre='2026-12-20', funil_id='f1'), camp('a', 'Lançamento Set', '2026-09-30'), camp('b', 'Lançamento Jun', '2026-06-30')]),
  'v_marketing_campanha': [vis('atual', 0, 0, 0), vis('a', 1000, 100, 10), vis('b', 3000, 200, 20)],
  'funis': ws([dict(id='f1', nome='Estratégia', tipo='lancamento', ativo=True)]), 'projetos': ws([]), 'canais': ws([dict(id='cn1', codigo='meta_ads', nome='Meta Ads', ativo=True), dict(id='cn2', codigo='email', nome='E-mail', ativo=True)]),
  'campanha_canais': ws([dict(id='k1', campanha_id='atual', canal='meta_ads', orcamento=5000, meta_leads=500, meta_vendas=50)]), 'pesquisas': ws([]), 'equipe': ws([]), 'projeto_modelos': ws([]),
  'campanha_etapas': ws([dict(id='e1', campanha_id='atual', fase='aquisicao', nome='Página · Leads', unidade='numero', origem='manual', ordem=1, ativa=True, chave='leads')]), 'estrategia_etapas': ws([]), 'campanha_blocos': ws([]), 'etapas_catalogo': ws([]), 'campanha_participacoes': ws([]), 'vendas': ws([]), 'plataformas_venda': ws([])}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1';
      window.__RPC = { ...(window.__RPC || {}), campanha_comercial: () => ({ vendedores: [], candidatos: [], outros: [] }), campanha_ofertas_resultado: () => [], campanha_etapas_dia: () => [], campanha_funil_etapas: () => [],
        campanhas_canais_historico: () => [{ campanha_id: 'a', canal: 'meta_ads', leads: 80, vendas: 6, investimento: 900 }, { campanha_id: 'a', canal: 'email', leads: 20, vendas: 4, investimento: 100 }, { campanha_id: 'b', canal: 'meta_ads', leads: 100, vendas: 10, investimento: 3000 }, { campanha_id: 'b', canal: 'email', leads: 100, vendas: 10, investimento: 0 }] }; }""")
    pg.evaluate("abrirWizard('atual', 6)"); pg.wait_for_timeout(1200)
    t = pg.inner_text('#wzHistCanal')
    chk('LANÇAMENTO SET' in t.upper() and 'MÉDIA DE 2' in t.upper(), 'mostra a última campanha e a média', t.replace(chr(10),' | '))
    chk('Meta Ads' in t and 'E-mail' in t, 'nomes dos canais', t)
    linhas = pg.evaluate("[...document.querySelectorAll('#wzHistCanal tbody tr')].map(r => [...r.children].map(c => c.innerText.trim()))")
    m = [l for l in linhas if l[0] == 'Meta Ads'][0]
    chk(m[1:] == ['90,0%', '80,0%', '60,0%', '95,0%', '65,0%', '55,0%'], 'porcentagens: última e média das duas', m)
    pg.fill('[data-pl="meta_ads"]', '70'); pg.dispatch_event('[data-pl="meta_ads"]', 'change'); pg.wait_for_timeout(200)
    chk('LANÇAMENTO SET' in pg.inner_text('#wzHistCanal').upper(), 'continua na tela ao digitar a meta', pg.inner_text('#wzHistCanal').replace(chr(10),' | '))
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'canais.png'), full_page=True)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    pg.evaluate("__RPC.campanhas_canais_historico = () => []; __D.campanhas.forEach(c => { if (c.id !== 'atual') c.status = 'ativa'; })")
    pg.evaluate("abrirWizard('atual', 6)"); pg.wait_for_timeout(1000)
    chk(pg.evaluate("!!document.querySelector('#wzHistCanal')"), 'sem histórico, a tela abre sem erro')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # Planejamento: blocos repetidos fora
    pg.evaluate("async () => { S.view = 'mkt-camp'; S.campSel = 'atual'; S.campTab = 'etapas'; const m = document.querySelector('main') || document.body; await vCampanha(m); }"); pg.wait_for_timeout(900)
    sh = lambda js: pg.locator('#ceHost').evaluate(js)
    chk(sh("e => !e.shadowRoot.querySelector('[data-sub=\"leg:etapas\"].sel') || true"), 'abre')
    t = pg.inner_text('#ceLeg')
    chk('Etapas desta campanha' in t, 'editar etapas fica disponível', t[:300])
    chk('Funil etapa por etapa' not in t and 'Lançar números por dia' not in t, 'sem o funil e sem lançar números de novo', t[:300])
    chk(sh("e => ![...e.shadowRoot.querySelectorAll('.subm button')].some(b => /Estratégia e números/.test(b.textContent))"), 'chip repetido saiu')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t262:', 'tudo OK' if ok else 'COM FALHAS')
