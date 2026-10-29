import json, os, tempfile
# Teste de tela da v0.163 (Customer Growth, B5): marcos na Jornada do produto (manual e automático, retroativo, eventos de fora)
# e a seção "Jornada e evolução" na ficha da pessoa, uma matrícula por vez (botão por produto).
# Rodar: python3 tests/tela/t163_marcos.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't163m_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', tag='mentoria', preco=1000, ativo=True), dict(id='p2', nome='Curso', tag='curso', preco=100, ativo=True)]),
  'jornadas': ws([dict(id='j1', produto_id='p1', nome='Jornada da mentoria', modelo=False, versao=1, status='publicada', publicada_em='2026-10-01T10:00:00Z')]),
  'etapas_kanban': ws([dict(id='g1', quadro='alunos', nome='Onboarding', ordem=1, jornada_id=None),
                       dict(id='m1', quadro='alunos', nome='Diagnóstico', ordem=1, jornada_id='j1'), dict(id='m2', quadro='alunos', nome='Plano', ordem=2, jornada_id='j1'), dict(id='m3', quadro='alunos', nome='Resultado', ordem=3, jornada_id='j1')]),
  'jornada_marcos': ws([dict(id='k1', jornada_id='j1', nome='Apresentou o plano', confirmacao='manual', obrigatorio=True, prazo_dias=10, ordem=1, regra=None),
                        dict(id='k2', jornada_id='j1', nome='Chegou ao plano', confirmacao='automatico', obrigatorio=False, prazo_dias=None, ordem=2, regra={'tipo': 'etapa', 'etapa_kanban_id': 'm2'})]),
  'pessoas': ws([dict(id='pa', nome='Ana Lima', email='ana@x.com', status_funil='cliente', status_cliente='ativo', criado_em='2026-09-01T10:00:00Z')]),
  'alunos': ws([dict(id='a1', pessoa_id='pa', produto_id='p1', tag='mentoria', status='ativo', etapa_kanban_id='m2', jornada_id='j1', entrou_em='2026-10-05T10:00:00Z'),
                dict(id='a2', pessoa_id='pa', produto_id='p2', tag='curso', status='ativo', etapa_kanban_id='g1', jornada_id=None, entrou_em='2026-09-20T10:00:00Z')]),
  'aluno_marcos': ws([dict(id='x2', aluno_id='a1', marco_id='k2', situacao='atingido', sinal='observado', fonte='etapa', em='2026-10-10T10:00:00Z')]),
  'aluno_historico': ws([dict(id='h1', aluno_id='a1', tipo='etapa', etapa_kanban_id='m1', em='2026-10-05T10:00:00Z'), dict(id='h2', aluno_id='a1', tipo='etapa', etapa_kanban_id='m2', em='2026-10-10T10:00:00Z')]),
  'fontes_video': ws([dict(id='v1', nome='Aula 1')]), 'pesquisas': [], 'funil_listas': [], 'chaves_api': [],
  'equipe': [], 'pessoa_historico': [], 'pessoa_funil': [], 'pessoa_funil_historico': [], 'vendas': [], 'contratos': [], 'pessoa_notas': [], 'presencas_video': [],
  'projetos': [], 'responsavel_historico': [], 'pagamentos_historicos': [], 'oportunidades': [], 'pessoa_toques': [], 'projeto_modelos': [], 'centros_custo': [], 'ofertas': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
RPC = """window.__RPC = {
  marco_confirmar: (a, D) => { D.aluno_marcos.push({ id: 'n' + Math.random(), workspace_id: 'w1', aluno_id: a.p_aluno, marco_id: a.p_marco, situacao: a.p_acao === 'confirmar' ? 'atingido' : 'recusado', sinal: 'validado', fonte: 'manual', em: new Date().toISOString(), validado_em: new Date().toISOString() }); return 'atingido'; },
  marco_retroativo: () => 2, chave_api_criar_escopo: () => 'gw_novachave' };"""
def evo(pg): return pg.evaluate("document.querySelector('#fjEvo') ? document.querySelector('#fjEvo').innerText : ''")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate(RPC + "window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'crm-alunos'; render();"); pg.wait_for_timeout(1000)
    pg.evaluate("fichaPessoa('pa')"); pg.wait_for_timeout(1800)
    t = evo(pg)
    chk('JORNADA E EVOLUÇÃO' in t.upper(), 'ficha tem a seção Jornada e evolução', t[:300])
    chk(pg.evaluate("[...document.querySelectorAll('#fjEvo [data-fja]')].map(b => b.textContent)") == ['Mentoria', 'Curso'], 'um botão por produto comprado')
    chk('Jornada do produto · v1' in t and 'Marcos atingidos' in t and '1 de 2' in t, 'mentoria: jornada, versão e marcos atingidos', t[:600])
    pills = pg.evaluate("[...document.querySelectorAll('#fjEvo [data-et]')].map(x => x.textContent.trim())")
    chk(pills == ['✓ Diagnóstico', '● Plano', 'Resultado'], 'caminho das etapas com a atual e as já passadas', pills)
    chk('Apresentou o plano' in t and 'atrasado' in t and 'atingido' in t and 'o sistema viu' in t, 'marco manual vencido aparece atrasado; o automático atingido', t)
    pg.click('#fjEvo [data-mkc=k1]'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("__calls.some(c => c[0] === 'rpc' && c[1] === 'marco_confirmar' && c[2].p_marco === 'k1' && c[2].p_acao === 'confirmar' && c[2].p_aluno === 'a1')"), 'confirmar chama marco_confirmar da matrícula certa')
    chk('2 de 2' in evo(pg) and 'a equipe confirmou' in evo(pg), 'depois de confirmar: 2 de 2', evo(pg)[:500])
    pg.click('#fjEvo [data-fja=a2]'); pg.wait_for_timeout(1200)
    t = evo(pg)
    chk('Jornada geral' in t and 'Na Jornada geral não há marcos' in t and 'Onboarding' in t, 'curso: Jornada geral, sem marcos', t[:500])
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''; S.jpProd = 'p1'; render();"); pg.wait_for_timeout(1500)
    t = pg.inner_text('body')
    chk('Marcos' in t and 'Apresentou o plano' in t and 'Chegou à etapa Plano' in t, 'página da jornada lista os marcos com a regra', t[:900])
    pg.click('[data-mknovo=j1]'); pg.wait_for_timeout(800)
    chk(pg.evaluate("document.querySelector('#modalRoot [name=r_tipo]').closest('label').style.display") == 'none', 'manual esconde o que o sistema observa')
    pg.fill('#modalRoot [name=nome]', 'Começou o diagnóstico'); pg.select_option('#modalRoot [name=confirmacao]', 'automatico'); pg.select_option('#modalRoot [name=r_tipo]', 'etapa'); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.querySelector('#modalRoot [name=r_etapa]').closest('label').style.display") == '' and pg.evaluate("document.querySelector('#modalRoot [name=r_video]').closest('label').style.display") == 'none', 'campos da regra aparecem conforme o tipo')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(600)
    chk(pg.evaluate("__D.jornada_marcos.length") == 2, 'regra de etapa sem etapa não salva')
    pg.select_option('#modalRoot [name=r_etapa]', 'm1'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1300)
    nm = pg.evaluate("__D.jornada_marcos.find(x => x.nome === 'Começou o diagnóstico') || null")
    chk(nm and nm.get('regra') == {'tipo': 'etapa', 'etapa_kanban_id': 'm1'} and nm.get('jornada_id') == 'j1' and nm.get('confirmacao') == 'automatico', 'marco automático salvo com a regra', nm)
    chk(pg.evaluate("__calls.some(c => c[0] === 'rpc' && c[1] === 'marco_retroativo')"), 'marco automático novo olha quem já atingiu')
    pg.click('[data-ev] >> nth=0'); pg.wait_for_timeout(700)
    pg.fill('#evNome', 'Área de membros'); pg.click('#evGerar'); pg.wait_for_timeout(800)
    u = pg.input_value('#evUrl')
    chk(u.endswith('/functions/v1/leads?tipo=evento&chave=gw_novachave') and pg.evaluate("__calls.some(c => c[0] === 'rpc' && c[1] === 'chave_api_criar_escopo' && c[2].p_escopo === 'eventos')"), 'receber eventos: chave de eventos e endereço', u)
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
