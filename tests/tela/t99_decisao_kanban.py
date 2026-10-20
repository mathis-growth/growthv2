import json, os, tempfile
# Teste de tela da v0.99: ICE do cenário, aprovação com documento de decisão, ideia no Kanban sem duplicar, Kanban em 7 colunas e planejamento.
# Rodar: python3 tests/tela/t99_decisao_kanban.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't99_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
hist = []
for mes in ['2026-06-01', '2026-07-01', '2026-08-01', '2026-09-01']:
    hist.append(dict(loop='campanha:c1', nome='Black', fase='aquisicao', tipo='campanha', produto_id='pC', campanha_id='c1', mes=mes, inv=1000, imp=100000, clk=1000, vis=800, led=200, qua=0, cli=20, rec=20000, base=0))
    hist.append(dict(loop='organico:pM', nome='Orgânico Mentoria', fase='aquisicao', tipo='organico', produto_id='pM', campanha_id=None, mes=mes, inv=0, imp=0, clk=0, vis=0, led=50, qua=0, cli=5, rec=15000, base=0))
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'rpc:growth_modelo_historico': hist,
  'produtos': ws([dict(id='pC', nome='Curso', preco=1000, ativo=True), dict(id='pM', nome='Mentoria', preco=3000, ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Black', status='ativa', produto_id='pC', data_fim='2027-12-31')]),
  'gm_alavancas': ws([dict(id='a0', loop_chave='campanha:c1', produto_id=None, alavanca='tkt', mes='2026-12-01', cenario='base', valor=1200)]),
  'gm_cenarios': [], 'growth_metricas': [], 'auditoria': ws([dict(id=1, tabela='gm_alavancas', acao='alteracao', antes={'valor': 1000, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, depois={'valor': 1200, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, usuario_email='rebecka@x', em='2026-10-10T10:00:00Z')]),
  'plano_contas': ws([dict(id='pF', codigo='6.2.01', nome='Ferramentas e software', tipo='despesa'), dict(id='pP', codigo='6.2.04', nome='Pró-labore', tipo='despesa'), dict(id='pMi', codigo='6.1.01', nome='Mídia paga – Meta', tipo='despesa')]),
  'centros_custo': ws([dict(id='cA', nome='Administrativo')]), 'fornecedores': [],
  'despesas_recorrentes': ws([dict(id='r1', descricao='Pró-labore', valor=10000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pP', centro_custo_id='cA'),
                              dict(id='r2', descricao='Ferramentas', valor=500, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pF', centro_custo_id='cA'),
                              dict(id='r3', descricao='Meta Ads', valor=3000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pMi', centro_custo_id='cA')]),
  'contas_pagar': [], 'contas_receber': [], 'simulador_snapshots': [], 'gm_decisoes': [], 'projetos': [], 'growth_experimentos': ws([dict(id='x1', titulo='Antigo', etapa='rodando', hipotese='h', inicio='2026-10-01', score=None)]), 'growth_metricas': [],
}
RPC = r"""window.__RPC = {
  gm_aprovar: (a, D) => { const c = D.gm_cenarios.find(x => x.id === a.p_cenario); if (!c.hipotese) throw new Error('Escreva a hipótese do cenário antes de aprovar'); if (!c.impacto) throw new Error('Preencha o ICE');
    c.status = 'aprovado'; c.aprovado_em = '2026-10-11T12:00:00Z'; const d = { id: 'd' + D.gm_decisoes.length, workspace_id: c.workspace_id, cenario_id: c.id, versao: c.versao, titulo: 'Decisão: ' + c.nome, documento: { ...a.p_documento, cenario: { nome: c.nome, versao: c.versao, hipotese: c.hipotese }, ice: { impacto: c.impacto, confianca: c.confianca, facilidade: c.facilidade, score: Math.round((c.impacto + c.confianca + c.facilidade) / 3 * 10) / 10 }, responsavel: a.p_responsavel, proximos_passos: a.p_proximos }, responsavel: a.p_responsavel, criado_em: '2026-10-11T12:00:00Z' }; D.gm_decisoes.push(d); return d.id; },
  gm_ideia_do_cenario: (a, D) => { const ja = D.growth_experimentos.find(e => e.cenario_id === a.p_cenario); if (ja) return ja.id; const c = D.gm_cenarios.find(x => x.id === a.p_cenario); const e = { id: 'e' + D.growth_experimentos.length, workspace_id: c.workspace_id, titulo: c.nome, hipotese: c.hipotese, etapa: c.status === 'aprovado' ? 'priorizado' : 'ideia', impacto: c.impacto, confianca: c.confianca, facilidade: c.facilidade, score: 7, cenario_id: c.id, tipo: 'experimento', criado_em: '2026-10-11' }; D.growth_experimentos.push(e); return e.id; },
  exp_para_planejamento: (a, D) => { const e = D.growth_experimentos.find(x => x.id === a.p_exp); if (e.projeto_id) return e.projeto_id; const p = { id: 'p' + D.projetos.length, workspace_id: e.workspace_id, nome: 'Iniciativa: ' + e.titulo, status: 'planejado' }; D.projetos.push(p); e.projeto_id = p.id; e.tipo = 'planejamento'; e.etapa = 'preparacao'; return p.id; }, gm_premissas_salvar: (a, D) => { if (!a.p_motivo) throw new Error('motivo'); a.p_linhas.forEach(l => { D.gm_alavancas = D.gm_alavancas.filter(x => !(x.cenario === 'base' && x.loop_chave === l.loop_chave && x.alavanca === l.alavanca && x.mes === l.mes)); D.gm_alavancas.push({ id: 'p' + Math.random(), workspace_id: a.p_ws, loop_chave: l.loop_chave, produto_id: l.produto_id || null, alavanca: l.alavanca, mes: l.mes, cenario: 'base', valor: l.valor }); }); return a.p_linhas.length; } };"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ').replace('R$ ', '')
def submit(pg): pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1000)
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
def muda(pg, sel, v): pg.evaluate("([s, v]) => { const i = document.querySelector(s); i.value = v; i.dispatchEvent(new Event('change', { bubbles: true })); }", [sel, v]); pg.wait_for_timeout(1200)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1600, 'height': 3000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.99')
    pg.evaluate("S.ws='w1'; S.view='gro-modelo'; S.gTab='loop'; S.gl=null; render()"); pg.wait_for_timeout(2000)
    pg.click('#glCenNovo'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=nome]', 'Ticket maior'); submit(pg); pg.wait_for_timeout(1500)
    cid = D(pg, 'gm_cenarios')[0]['id']
    muda(pg, '[data-lc="campanha:c1"] .gi[data-k=tkt][data-m="2026-11-01"]', '1500')
    chk(pg.locator('#glIce').count() == 1 and pg.locator('#glAprova').count() == 1 and pg.locator('#glIdeia').count() == 1, 'barra com ICE, Aprovar e Ideia no Kanban')
    # aprovar sem hipótese/ICE: avisa
    pg.click('#glAprova'); pg.wait_for_timeout(600)
    t = pg.inner_text('#modalRoot'); chk('Escreva a hipótese' in t and 'Preencha o ICE' in t and 'Receita incremental' in t, 'aprovação mostra o que falta e o impacto', t[:600])
    submit(pg); chk(D(pg, 'gm_cenarios')[0]['status'] == 'rascunho', 'sem hipótese e ICE não aprova'); pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # ICE
    pg.click('#glIce'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=impacto]', '11'); submit(pg)
    chk(D(pg, 'gm_cenarios')[0].get('impacto') is None, 'ICE fora de 1 a 10 é recusado')
    pg.fill('#modalRoot [name=impacto]', '8'); pg.fill('#modalRoot [name=confianca]', '6'); pg.fill('#modalRoot [name=facilidade]', '7'); pg.fill('#modalRoot [name=j]', 'teste A/B anterior'); submit(pg); pg.wait_for_timeout(800)
    c = D(pg, 'gm_cenarios')[0]; chk(c['impacto'] == 8 and c['ice_justificativa'] == 'teste A/B anterior', 'ICE salvo no cenário', c)
    pg.evaluate("render()"); pg.wait_for_timeout(1800)
    chk('ICE 7,0' in tx(pg), 'botão mostra o score ICE 7,0')
    pg.click('#glCenEd'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=hipotese]', 'Ticket maior aumenta o lucro'); submit(pg); pg.wait_for_timeout(1500)
    pg.click('#glAprova'); pg.wait_for_timeout(600); pg.fill('#modalRoot [name=resp]', 'Rebecka'); pg.fill('#modalRoot [name=prox]', 'Rodar 30 dias'); submit(pg); pg.wait_for_timeout(1500)
    c = D(pg, 'gm_cenarios')[0]; dec = D(pg, 'gm_decisoes')
    chk(c['status'] == 'aprovado' and len(dec) == 1, 'cenário aprovado e documento gerado', c)
    doc = dec[0]['documento']
    chk(len(doc['inputs']) == 1 and doc['inputs'][0]['cenario'] == 1500 and doc['inputs'][0]['alavanca'] == 'Ticket' and doc['resultados']['projetado_consolidado']['rec'] > doc['resultados']['baseline_consolidado']['rec'], 'documento com inputs, baseline e projeção', doc.get('inputs'))
    ex = [e for e in D(pg, 'growth_experimentos') if e.get('cenario_id') == cid]
    chk(len(ex) == 1 and ex[0]['etapa'] == 'priorizado', 'aprovação criou a ideia priorizada no Kanban', ex)
    pg.evaluate("render()"); pg.wait_for_timeout(1800)
    chk(pg.locator('#glAprova').count() == 0 and pg.locator('#glDoc').count() == 1, 'aprovado: sem Aprovar, com Documento de decisão')
    pg.click('#glDoc'); pg.wait_for_timeout(800)
    t = pg.inner_text('#modalRoot'); chk('Decisão: Ticket maior' in t and 'Hipótese' in t and 'Ticket maior aumenta o lucro' in t and 'Rebecka' in t and 'Score 7' in t and 'imutável' in t, 'documento de decisão completo', t[:900])
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    pg.click('#glIdeia'); pg.wait_for_timeout(1000)
    chk('já tem uma ideia' in pg.inner_text('#modalRoot') and len([e for e in D(pg, 'growth_experimentos') if e.get('cenario_id') == cid]) == 1, 'ideia no Kanban sem duplicar')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # Kanban
    pg.evaluate("S.view='gro-ciclo'; render()"); pg.wait_for_timeout(1500)
    t = tx(pg)
    cols = pg.evaluate("[...document.querySelectorAll('.colk')].map(c=>c.dataset.col)")
    chk(cols == ['ideia', 'avaliacao', 'priorizado', 'preparacao', 'rodando', 'analise', 'concluido'], 'Kanban com 7 colunas', cols)
    chk('Em teste' in t and 'Antigo' in t and 'cenário' in t, 'card antigo (Rodando) aparece em Em teste; card do cenário marcado', t[:1500])
    eid = ex[0]['id']
    pg.select_option('[data-mv="%s"]' % eid, 'avaliacao'); pg.wait_for_timeout(1000)
    chk([e for e in D(pg, 'growth_experimentos') if e['id'] == eid][0]['etapa'] == 'avaliacao', 'mover para Em avaliação')
    pg.select_option('[data-mv="x1"]', 'arquivado'); pg.wait_for_timeout(1000)
    chk([e for e in D(pg, 'growth_experimentos') if e['id'] == 'x1'][0]['etapa'] == 'arquivado' and 'arquivada' in tx(pg), 'arquivar: fica em Concluídas / Arquivadas')
    pg.click('[data-edit="%s"]' % eid); pg.wait_for_timeout(700)
    chk(pg.locator('#modalRoot [name=publico]').count() == 1 and pg.locator('#modalRoot [name=instrumentacao]').count() == 1, 'experimento com público, intervenção e instrumentação')
    pg.click('#modalRoot button:has-text("Converter em planejamento")'); pg.wait_for_timeout(1200)
    e = [e for e in D(pg, 'growth_experimentos') if e['id'] == eid][0]
    chk(e['tipo'] == 'planejamento' and e['projeto_id'] and len(D(pg, 'projetos')) == 1, 'converter em planejamento cria o projeto', e)
    chk('planejamento' in tx(pg), 'card marcado como planejamento')
    errs = [x for x in errs if 'funil' not in x]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
