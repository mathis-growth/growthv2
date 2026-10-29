import json, os, tempfile
# Teste de tela da v0.163 (Customer Growth, B2/B3): Alunos com seletor de jornada (geral, de um produto, lista de todos),
# página da Jornada do produto (versões, nova versão, publicar com "continuar" ou "transferir") e o painel em Produtos.
# Rodar: python3 tests/tela/t163_jornada_produto.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't163j_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', tag='mentoria', preco=1000, tipo='servico', ativo=True), dict(id='p2', nome='Curso', tag='curso', preco=100, tipo='curso', ativo=True)]),
  'jornadas': ws([dict(id='j1', produto_id='p1', nome='Jornada da mentoria', modelo=False, versao=1, status='publicada', publicada_em='2026-10-20T10:00:00Z')]),
  'etapas_kanban': ws([dict(id='g1', quadro='alunos', nome='Onboarding', ordem=1, jornada_id=None), dict(id='g2', quadro='alunos', nome='Ativo', ordem=2, jornada_id=None),
                       dict(id='m1', quadro='alunos', nome='Diagnóstico', ordem=1, jornada_id='j1'), dict(id='m2', quadro='alunos', nome='Plano', ordem=2, jornada_id='j1'),
                       dict(id='l1', quadro='leads', nome='Novo', ordem=1, jornada_id=None)]),
  'pessoas': ws([dict(id='pa', nome='Ana Lima', email='ana@x.com'), dict(id='pb', nome='Bia Souza', email='bia@x.com')]),
  'alunos': ws([dict(id='a1', pessoa_id='pa', produto_id='p1', tag='mentoria', status='ativo', etapa_kanban_id='m2', jornada_id='j1', entrou_em='2026-10-21T10:00:00Z'),
                dict(id='a2', pessoa_id='pa', produto_id='p2', tag='curso', status='ativo', etapa_kanban_id='g1', jornada_id=None, entrou_em='2026-10-22T10:00:00Z'),
                dict(id='a3', pessoa_id='pb', produto_id='p1', tag='mentoria', status='ativo', etapa_kanban_id='g2', jornada_id=None, entrou_em='2026-10-01T10:00:00Z')]),
  'aluno_historico': ws([dict(id='h1', aluno_id='a1', tipo='etapa', etapa_kanban_id='m2', em='2026-10-25T10:00:00Z')]),
  'equipe': [], 'projeto_modelos': [], 'centros_custo': [], 'ofertas': [], 'oferta_itens': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
RPC = """window.__RPC = {
  jornada_rascunho: (a, D) => { const v = Math.max(0, ...D.jornadas.filter(j => j.produto_id === a.p_produto).map(j => j.versao)) + 1, id = 'jr' + v;
    D.jornadas.push({ id, workspace_id: 'w1', produto_id: a.p_produto, nome: 'Jornada', modelo: false, versao: v, status: 'rascunho' });
    D.etapas_kanban.filter(e => a.p_base ? e.jornada_id === a.p_base : (a.p_da_geral && e.quadro === 'alunos' && !e.jornada_id)).forEach((e, k) => D.etapas_kanban.push({ ...e, id: id + 'e' + k, jornada_id: id }));
    return id; },
  jornada_publicar: (a, D) => { D.jornadas.forEach(j => { if (j.status === 'publicada' && j.produto_id === D.jornadas.find(x => x.id === a.p_jornada).produto_id) j.status = 'anterior'; });
    D.jornadas.find(x => x.id === a.p_jornada).status = 'publicada'; window.__pub = a; return { transferidos: Object.keys(a.p_mapa || {}).length }; },
  jornada_transferir: (a, D) => { window.__tr = a; return 1; } };"""
def ver(pg): return pg.evaluate("document.querySelector('#main, main, .main') ? 1 : 1")
def cols(pg): return pg.evaluate("[...document.querySelectorAll('.colk h3')].map(h => h.innerText.split('\\n')[0].trim())")
def cards(pg): return pg.evaluate("[...document.querySelectorAll('.colk .card [data-f]')].map(b => b.textContent.trim())")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate(RPC + "window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'crm-alunos'; render();"); pg.wait_for_timeout(1200)
    c = cols(pg)
    chk(any('Onboarding' in x for x in c) and any('Ativo' in x for x in c) and not any('Diagnóstico' in x for x in c), 'Jornada geral mostra só as etapas gerais', c)
    k = cards(pg)
    chk(sorted(k) == ['Ana Lima', 'Bia Souza'], 'na geral: Ana (curso) e Bia (mentoria sem jornada); a matrícula da mentoria da Ana não aparece', k)
    opts = pg.evaluate("[...document.querySelectorAll('#alJ option')].map(o => o.textContent)")
    chk(opts == ['Jornada geral', 'Jornada do produto: Mentoria', 'Todos os produtos (lista)'], 'seletor de jornada', opts)
    pg.select_option('#alJ', 'p:p1'); pg.wait_for_timeout(900)
    c = cols(pg)
    chk(any('Diagnóstico' in x for x in c) and any('Plano' in x for x in c) and not any('Onboarding' in x for x in c), 'jornada da mentoria mostra as etapas dela', c)
    chk(cards(pg) == ['Ana Lima'], 'só a matrícula da Ana na mentoria', cards(pg))
    chk('ainda está na Jornada geral' in pg.inner_text('#main') if pg.query_selector('#main') else 'ainda está na Jornada geral' in pg.inner_text('body'), 'aviso de aluno do produto que ficou na geral')
    pg.select_option('#alJ', 'lista'); pg.wait_for_timeout(900)
    rows = pg.evaluate("[...document.querySelectorAll('table tbody tr')].map(r => [...r.cells].map(c => c.innerText.trim()))")
    ana = [r for r in rows if r[0] == 'Ana Lima']
    chk(len(rows) == 3 and len(ana) == 2 and {r[1] for r in ana} == {'Mentoria', 'Curso'}, 'lista: Ana aparece uma vez por produto', rows)
    chk(any(r[1] == 'Mentoria' and r[2] == 'Mentoria · v1' and r[3] == 'Plano' for r in ana) and any(r[2] == 'Jornada geral' for r in rows), 'lista mostra jornada e etapa de cada matrícula', rows)
    pg.select_option('#alJ', 'p:p1'); pg.wait_for_timeout(900)
    pg.click('button[data-jp=p1]'); pg.wait_for_timeout(1200)
    t = pg.inner_text('body')
    chk('Versão 1 · em uso' in t and 'Diagnóstico' in t and 'Versões' in t, 'página da jornada do produto com a versão em uso', t[:600])
    chk(pg.evaluate("[...document.querySelectorAll('[data-tr]')].length") == 1, 'botão de transferir os alunos da geral')
    pg.click('#jpNova'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("__calls.some(c => c[0] === 'rpc' && c[1] === 'jornada_rascunho' && c[2].p_base === 'j1')"), 'nova versão parte da v1')
    t = pg.inner_text('body')
    chk('Versão 2 · rascunho' in t, 'rascunho da v2 aparece', t[:500])
    chk(pg.evaluate("document.querySelectorAll('[data-lista=jr2] [data-del]').length") == 2 and pg.evaluate("document.querySelectorAll('[data-del]').length") == 2, 'só o rascunho tem excluir e reordenar')
    pg.click('[data-nova=jr2]'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=nome]', 'Primeiro resultado'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("__D.etapas_kanban.some(e => e.jornada_id === 'jr2' && e.nome === 'Primeiro resultado' && e.ordem === 3)"), 'nova etapa entra no rascunho no fim')
    pg.click('#jpPub'); pg.wait_for_timeout(700)
    t = pg.inner_text('#modalRoot')
    chk('1 aluno ativo está na versão 1' in t and 'Continuam na versão 1' in t and 'Transferir para a versão 2' in t, 'publicar pergunta o que fazer com quem já está dentro', t[:500])
    pg.check('#modalRoot input[value=transferir]'); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.querySelector('#jpMapa').style.display") == '', 'mapa de etapas aparece ao escolher transferir')
    sug = pg.evaluate("[...document.querySelectorAll('#jpMapa select')].map(s => s.options[s.selectedIndex].text)")
    chk(sug == ['Diagnóstico', 'Plano'], 'sugere a etapa de mesmo nome', sug)
    pg.select_option('#jpMapa select[name=m_m1]', '')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1200)
    a = pg.evaluate("window.__pub")
    chk(a and a['p_modo'] == 'transferir' and a['p_mapa'] == {'m2': 'jr2e1'}, 'publica transferindo só a etapa escolhida', a)
    t = pg.inner_text('body')
    chk('Versão 2 · em uso' in t and 'versão anterior' in t, 'v2 em uso e v1 como anterior', t[:700])
    pg.click('[data-jt=dados]'); pg.wait_for_timeout(700)
    chk('Editar no cadastro de produtos' in pg.inner_text('body'), 'aba Dados do produto')
    pg.click('#jpVolta'); pg.wait_for_timeout(900)
    pg.evaluate("S.view = 'cad-produtos'; S.jpProd = null; render();"); pg.wait_for_timeout(1500)
    t = pg.evaluate("document.querySelector('#c3') ? document.querySelector('#c3').innerText : ''")
    chk('Jornada do produto' in t and 'v2 em uso' in t and 'Jornada geral' in t, 'painel Jornada do produto em Produtos', t)
    pg.evaluate("S.view = 'crm-alunos'; S.alJ = 'geral'; render();"); pg.wait_for_timeout(900)
    pg.click('#gEt'); pg.wait_for_timeout(800)
    t = pg.inner_text('#modalRoot')
    chk('Jornada geral (alunos)' in t and 'Onboarding' in t and 'Diagnóstico' not in t and 'Novo' not in t, 'Gerenciar etapas da geral não mostra as da jornada do produto', t[:400])
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
