import json, os, tempfile
# Teste de tela da v0.163 (Customer Growth, B1): a pesquisa pode disparar quando o aluno entra numa etapa da jornada,
# com filtro opcional de produto; o modelo "Jornada" aponta para o gatilho certo.
# Rodar: python3 tests/tela/t163_pesquisa_etapa_aluno.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't163_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'funis': [], 'funil_etapas': ws([dict(id='fe1', nome='Inscrito', ordem=1)]),
  'etapas_kanban': ws([dict(id='ea1', quadro='alunos', nome='Onboarding', ordem=1), dict(id='ea2', quadro='alunos', nome='Primeiro resultado', ordem=2),
                       dict(id='el1', quadro='leads', nome='Novo', ordem=1)]),
  'produtos': ws([dict(id='p1', nome='Mentoria', tag='mentoria', preco=1000), dict(id='p2', nome='Curso', tag='curso', preco=100)]),
  'pesquisas': [], 'pesquisa_perguntas': [], 'pesquisa_envios': [], 'pesquisa_respostas': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'gro-pesq'; render();"); pg.wait_for_timeout(1000)
    chk(pg.evaluate("PQ_GAT.etapa_aluno") == 'Quando o aluno entra numa etapa da jornada', 'gatilho novo na lista')
    chk('Quando o aluno entra numa etapa da jornada' in pg.evaluate("PQ_MODELOS.jornada.descricao"), 'modelo Jornada aponta para o gatilho do aluno')
    pg.evaluate("modalPesquisa()"); pg.wait_for_timeout(800)
    opts = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=etapa_aluno_id] option')].map(o => o.textContent)")
    chk('Onboarding' in opts and 'Primeiro resultado' in opts and 'Novo' not in opts, 'etapas da jornada do aluno (sem as do funil comercial)', opts)
    prods = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=produto_id] option')].map(o => o.textContent)")
    chk('Mentoria' in prods and 'Curso' in prods, 'filtro de produto', prods)
    pg.fill('#modalRoot [name=nome]', 'NPS do primeiro resultado')
    pg.select_option('#modalRoot select[name=gatilho]', 'etapa_aluno')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(600)
    chk(pg.evaluate("__D.pesquisas.length") == 0, 'sem etapa escolhida não salva')
    pg.select_option('#modalRoot select[name=etapa_aluno_id]', 'ea2'); pg.select_option('#modalRoot select[name=produto_id]', 'p2')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(800)
    r = pg.evaluate("__D.pesquisas[0] || null")
    chk(r and r.get('gatilho') == 'etapa_aluno' and r.get('etapa_aluno_id') == 'ea2' and r.get('produto_id') == 'p2' and not r.get('gatilho_etapa'), 'salva etapa do aluno e produto', r)
    pg.evaluate("modalPesquisa(__D.pesquisas[0])"); pg.wait_for_timeout(700)
    pg.select_option('#modalRoot select[name=gatilho]', 'cadastro'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(800)
    r = pg.evaluate("__D.pesquisas[0]")
    chk(r.get('etapa_aluno_id') is None and r.get('produto_id') is None, 'trocar para cadastro limpa etapa e produto', r)
    pg.evaluate("__D.pesquisas[0].gatilho = 'etapa_aluno'; __D.pesquisas[0].etapa_aluno_id = 'ea2'; S.pqSel = __D.pesquisas[0].id; render();"); pg.wait_for_timeout(1000)
    h = pg.evaluate("document.querySelector('.head .muted').innerText")
    chk('Quando o aluno entra numa etapa da jornada: Primeiro resultado' in h, 'detalhe mostra a etapa do aluno', h)
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
