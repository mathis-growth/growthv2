import json, os, tempfile
# Teste de tela da v0.163 (Customer Growth, B6 a B10): tela RevOps → Customer Growth com as cinco abas, check-in recorrente
# na Pesquisa, intervenção a partir do alerta, oportunidade de expansão e "Minhas atividades" com as intervenções.
# Rodar: python3 tests/tela/t163_customer_growth.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't163cg_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', tag='mentoria', preco=1000, ativo=True)]),
  'jornadas': ws([dict(id='j1', produto_id='p1', nome='Mentoria', modelo=False, versao=1, status='publicada')]),
  'etapas_kanban': ws([dict(id='m1', quadro='alunos', nome='Diagnóstico', ordem=1, jornada_id='j1'), dict(id='m2', quadro='alunos', nome='Plano', ordem=2, jornada_id='j1'),
                       dict(id='o1', quadro='oportunidades', nome='Conversa inicial', ordem=1, jornada_id=None)]),
  'equipe': ws([dict(id='eq1', nome='Carla CS', email='t@t.com', ativo=True)]),
  'pessoas': ws([dict(id='pa', nome='Ana Lima', email='ana@x.com', status_funil='cliente', status_cliente='ativo')]),
  'alunos': ws([dict(id='a1', pessoa_id='pa', produto_id='p1', tag='mentoria', status='ativo', etapa_kanban_id='m1', jornada_id='j1', entrou_em='2026-09-01T10:00:00Z', responsavel_cs_id='eq1')]),
  'pesquisas': ws([dict(id='ck1', nome='Check-in quinzenal', tipo='jornada', gatilho='checkin', checkin_dias=14, produto_id='p1', ativa=True)]),
  'pesquisa_envios': ws([dict(id='en1', pesquisa_id='ck1', pessoa_id='pa', aluno_id='a1', ciclo=3, status='enviado', gerado_em='2026-10-15T10:00:00Z'),
                         dict(id='en2', pesquisa_id='ck1', pessoa_id='pa', aluno_id='a1', ciclo=2, status='respondido', gerado_em='2026-10-01T10:00:00Z')]),
  'alertas': ws([dict(id='al1', tipo='cs', regra='marco_atrasado', severidade='alta', titulo='Marco atrasado: Plano entregue (Ana Lima)', mensagem='Ana Lima não atingiu «Plano entregue».',
                      dados={'aluno_id': 'a1', 'pessoa_id': 'pa', 'produto_id': 'p1', 'marco_id': 'k1'}, dia='2026-10-28', criado_em='2026-10-28T10:00:00Z', resolvido_em=None)]),
  'cs_intervencoes': [], 'oportunidades': ws([dict(id='op1', pessoa_id='pa', titulo='Imersão', tipo='expansao', origem='marco', aluno_id='a1', produto_id='p1', status='aberta', valor_estimado=3000, criado_em='2026-10-20T10:00:00Z')]),
  'jornada_marcos': [], 'aluno_marcos': [], 'aluno_historico': [], 'funis': [], 'funil_etapas': [], 'projeto_atividades': [], 'projetos': [],
  'rpc:cg_indicadores': {'matriculas': {'ativas': 12, 'novas': 3, 'sairam': 1, 'sem_cs': 2, 'na_jornada_geral': 4}, 'checkins': {'gerados': 10, 'respondidos': 7, 'taxa': 70},
    'nps': {'respostas': 7, 'media': 8.1, 'nps': 43}, 'intervencoes': {'abertas': 2, 'feitas': 5, 'resolveu_pct': 80}, 'receita': {'clientes': 12, 'por_cliente': 2500, 'total': 30000},
    'alertas': {'marco_atrasado': 1}, 'etapas': [{'jornada': 'Mentoria · v1', 'etapa': 'Diagnóstico', 'ordem': 1, 'n': 8}],
    'marcos': [{'id': 'k1', 'nome': 'Plano entregue', 'obrigatorio': True, 'prazo_dias': 30, 'elegiveis': 12, 'atingidos': 6, 'aguardando': 1, 'atrasados': 3, 'pct': 50, 'no_prazo_pct': 66.7, 'dias_medio': 21.5}]},
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def corpo(pg): return pg.evaluate("document.querySelector('#cgCorpo') ? document.querySelector('#cgCorpo').innerText : ''")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'ho-cg'; abreMenu(S.view); render();"); pg.wait_for_timeout(1500)
    chk(pg.evaluate("!!document.querySelector('nav [data-v=\"ho-cg\"], [data-v=\"ho-cg\"]')"), 'Customer Growth no menu de RevOps')
    chk(pg.evaluate("[...document.querySelectorAll('[data-cga]')].map(b => b.textContent)") == ['Evolução', 'Check-ins', 'Alertas e intervenções', 'Retenção e expansão', 'Indicadores'], 'cinco abas')
    chk(pg.evaluate("[...document.querySelectorAll('#cgCorpo .colk h3')].length") == 2 and 'Ana Lima' in corpo(pg), 'Evolução mostra o quadro da jornada do produto', corpo(pg)[:300])
    pg.click('[data-cga=checkins]'); pg.wait_for_timeout(1000)
    t = corpo(pg)
    chk('Check-in quinzenal' in t and 'a cada 14 dias' in t and '50%' in t and 'Aguardando resposta (1)' in t, 'Check-ins: pesquisa, taxa e pendentes', t[:600])
    pg.click('#cgNovaPq'); pg.wait_for_timeout(900)
    chk(pg.evaluate("document.querySelector('#modalRoot select[name=gatilho]').value") == 'checkin' and pg.input_value('#modalRoot [name=checkin_dias]') == '14', 'nova pesquisa de check-in já vem com o gatilho e os dias')
    pg.fill('#modalRoot [name=checkin_dias]', ''); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(500)
    chk(pg.evaluate("__D.pesquisas.length") == 1, 'check-in sem dias não salva')
    pg.fill('#modalRoot [name=checkin_dias]', '30'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(900)
    nv = pg.evaluate("__D.pesquisas.find(x => x.id !== 'ck1') || null")
    chk(nv and nv.get('gatilho') == 'checkin' and nv.get('checkin_dias') == 30 and pg.evaluate("__D.pesquisas.find(x => x.id === 'ck1').checkin_dias") == 14, 'cria pesquisa nova (não edita a que existe)', nv)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    pg.click('[data-cga=alertas]'); pg.wait_for_timeout(1000)
    t = corpo(pg)
    chk('Marco atrasado' in t and 'Criar intervenção' in t, 'Alertas de acompanhamento', t[:500])
    pg.click('[data-iv=al1]'); pg.wait_for_timeout(900)
    chk('Marco atrasado: Plano entregue' in pg.input_value('#modalRoot [name=descricao]'), 'intervenção já vem com o alerta')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1000)
    iv = pg.evaluate("__D.cs_intervencoes[0] || null")
    chk(iv and iv.get('aluno_id') == 'a1' and iv.get('alerta_id') == 'al1' and iv.get('marco_id') == 'k1', 'intervenção ligada à matrícula, ao alerta e ao marco', iv)
    pg.click('[data-ived]'); pg.wait_for_timeout(800)
    pg.select_option('#modalRoot [name=status]', 'feita'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(500)
    chk(pg.evaluate("__D.cs_intervencoes[0].status") != 'feita' and 'Diga o efeito' in pg.inner_text('body'), 'concluir pede o efeito')
    pg.select_option('#modalRoot [name=efeito]', 'resolveu'); pg.fill('#modalRoot [name=resultado]', 'Plano entregue na call'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(900)
    chk(pg.evaluate("__D.cs_intervencoes[0].status") == 'feita' and pg.evaluate("__D.cs_intervencoes[0].efeito") == 'resolveu', 'intervenção concluída com o efeito')
    pg.click('[data-cga=retencao]'); pg.wait_for_timeout(1000)
    t = corpo(pg)
    chk('Imersão' in t and 'Expansão (upsell)' in t and 'Marco' in t and 'R$' in t, 'Retenção e expansão lista a oportunidade da matrícula', t[:500])
    pg.click('#cgNovaOp'); pg.wait_for_timeout(1000)
    chk(pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=tipo] option')].map(o => o.value)") == ['nova_venda', 'renovacao', 'ajuste', 'expansao', 'retencao'] and pg.evaluate("document.querySelector('#modalRoot select[name=tipo]').value") == 'expansao', 'nova oportunidade com os tipos novos, já em expansão')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    pg.click('[data-cga=indicadores]'); pg.wait_for_timeout(1000)
    t = corpo(pg)
    chk('Alunos ativos' in t and '70%' in t and '43' in t and '80%' in t and 'Plano entregue' in t and '66,7%' in t and 'Mentoria · v1' in t, 'Indicadores', t[:800])
    chk(pg.evaluate("__calls.some(c => c[0] === 'rpc' && c[1] === 'cg_indicadores')"), 'indicadores vêm do banco (cg_indicadores)')
    pg.evaluate("__D.cs_intervencoes.push({ id: 'iv2', workspace_id: 'w1', aluno_id: 'a1', pessoa_id: 'pa', tipo: 'ligacao', descricao: 'Ligar para a Ana', status: 'aberta', responsavel_id: 'eq1', prazo: '2026-10-01' }); S.view = 'prj-minhas'; S.minhaEq = 'eq1'; render();"); pg.wait_for_timeout(1300)
    t = pg.inner_text('body')
    chk('Intervenções de CS' in t and 'Ligar para a Ana' in t, 'Minhas atividades mostra as intervenções de CS', t[:600])
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
