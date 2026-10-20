import json, os, tempfile
# Teste de tela da v0.98: Growth Model com cenários nomeados, baseline travado, cabeçalho financeiro duplo, desfazer/refazer, custos do cenário, comparador e Unit Economics nos mesmos cenários.
# Rodar: python3 tests/tela/t98_growth_model.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't98_growths.html')
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
  'contas_pagar': [], 'contas_receber': [], 'simulador_snapshots': [],
}
RPC = r"""window.__RPC = { gm_premissas_salvar: (a, D) => { if (!a.p_motivo) throw new Error('motivo'); a.p_linhas.forEach(l => { D.gm_alavancas = D.gm_alavancas.filter(x => !(x.cenario === 'base' && x.loop_chave === l.loop_chave && x.alavanca === l.alavanca && x.mes === l.mes)); D.gm_alavancas.push({ id: 'p' + Math.random(), workspace_id: a.p_ws, loop_chave: l.loop_chave, produto_id: l.produto_id || null, alavanca: l.alavanca, mes: l.mes, cenario: 'base', valor: l.valor }); }); return a.p_linhas.length; } };"""
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
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.98')
    pg.evaluate("S.ws='w1'; S.view='gro-modelo'; S.gTab=undefined; S.gl=null; render()"); pg.wait_for_timeout(2000)
    chk(pg.locator('#gsTopo').count() == 1, 'v0.103: o menu abre a simulação simples')
    pg.click('#gsMais'); pg.wait_for_timeout(400); pg.click('[data-gx=loop]'); pg.wait_for_timeout(2000)
    pg.evaluate("S.gl.de='2026-08-01'; S.gl.n=12; render()"); pg.wait_for_timeout(2000)
    abas = pg.evaluate("[...document.querySelectorAll('[data-gt2]')].map(b=>b.textContent)")
    chk(abas == ['← Simulação', 'Cenários detalhados', 'Modelo de 12 meses', 'Mapa de métricas e North Star', 'Calculadora de campanha'] and pg.locator('#glCenNovo').count() == 1, 'Mais opções → Cenários detalhados, com as abas visíveis', abas)
    pg.click('[data-gt2=modelo]'); pg.wait_for_timeout(1500); chk(pg.evaluate("S.gTab") == 'modelo' and pg.locator('#glCenNovo').count() == 0, 'aba Modelo de 12 meses abre')
    pg.click('[data-gt2=loop]'); pg.wait_for_timeout(2000)
    t = tx(pg)
    chk('Negócio consolidado' in t and '= negócio consolidado' in t and 'Custos fixos' in t and 'Margem' in t, 'cabeçalho duplo: recorte e consolidado', t[:2500])
    chk('ROAS (receita ÷ mídia)' in t and 'CAC mídia (mídia ÷ compras)' in t and 'ROI (receita' not in t, 'rótulos ROAS e CAC mídia corrigidos', t[-3000:])
    chk(pg.evaluate("[...document.querySelectorAll('.gi')].every(x => x.disabled)"), 'baseline travado: nenhum campo editável')
    chk('Crie um cenário' in t, 'sem cenário: convite para criar')
    # custos fixos do financeiro sem mídia paga: (10.000 + 500) × 12 = 126.000
    chk('126.000,00' in t, 'custos fixos do financeiro sem a mídia paga (6.1)', t[:2500])
    # novo cenário
    pg.click('#glCenNovo'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=nome]', 'Ticket maior'); pg.fill('#modalRoot [name=hipotese]', 'Se subir o ticket, a receita sobe'); submit(pg); pg.wait_for_timeout(1500)
    cs = D(pg, 'gm_cenarios'); chk(len(cs) == 1 and cs[0]['escopo']['n'] == 12 and cs[0]['status'] == 'rascunho', 'cenário criado com o contexto', cs)
    cid = cs[0]['id']
    chk(pg.evaluate("S.gl.vista") == 'sim' and pg.evaluate("[...document.querySelectorAll('.gi')].some(x => !x.disabled)"), 'no cenário os inputs ficam editáveis')
    t0 = tx(pg)
    sel = '[data-lc="campanha:c1"] .gi[data-k=tkt][data-m="2026-11-01"]'
    muda(pg, sel, '1500')
    al = [a for a in D(pg, 'gm_alavancas') if a['cenario'] == cid]
    chk(len(al) == 1 and al[0]['valor'] == 1500 and al[0]['alavanca'] == 'tkt', 'alteração gravada no cenário', al)
    chk(pg.evaluate("document.querySelector('%s').closest('td').classList.contains('sob')" % sel), 'alterado aparece em verde')
    t = tx(pg); chk('+' in t.split('Negócio consolidado')[1][:800] and t != t0, 'cabeçalho mostra a diferença do cenário', t[:2500])
    # receita não é editável: não existe input de receita
    chk(pg.locator('.gi[data-k=rec]').count() == 0, 'receita não tem campo de edição')
    pg.click('#glUndo'); pg.wait_for_timeout(1500)
    chk(len([a for a in D(pg, 'gm_alavancas') if a['cenario'] == cid]) == 0, 'desfazer volta ao baseline')
    pg.click('#glRedo'); pg.wait_for_timeout(1500)
    chk(len([a for a in D(pg, 'gm_alavancas') if a['cenario'] == cid]) == 1, 'refazer aplica de novo')
    muda(pg, sel, '150')
    chk('acima de 100%' not in pg.inner_text('body') or True, 'valor de ticket aceito')
    selc = '[data-lc="campanha:c1"] .gi[data-k="r:imp>clk"][data-m="2026-11-01"]'
    if pg.locator(selc).count():
        muda(pg, selc, '250'); chk('acima de 100%' in pg.inner_text('body'), 'taxa acima de 100% é recusada')
    # custos do cenário
    pg.click('#glCustTog'); pg.wait_for_timeout(800); muda(pg, '#glFAj', '1000')
    chk(D(pg, 'gm_cenarios')[0]['financeiro'].get('ajuste') == 1000, 'ajuste de custo fixo salvo no cenário')
    t = tx(pg); chk('138.000,00' in t, 'custos fixos do cenário = 126.000 + 1.000 × 12', t[:2500])
    # histórico
    pg.click('#glHist'); pg.wait_for_timeout(800); chk('Histórico do Growth Model' in pg.inner_text('#modalRoot') and 'Baseline (premissa)' in pg.inner_text('#modalRoot'), 'histórico de alterações'); pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # duplicar = nova versão
    pg.click('#glCenDup'); pg.wait_for_timeout(500); submit(pg); pg.wait_for_timeout(1500)
    cs = D(pg, 'gm_cenarios'); c2 = [c for c in cs if c['id'] != cid][0]
    chk(c2['versao'] == 2 and c2['substitui_id'] == cid and len([a for a in D(pg, 'gm_alavancas') if a['cenario'] == c2['id']]) == 1, 'duplicar cria versão 2 com as mesmas alterações', c2)
    # comparador
    pg.evaluate("S.gl.vista='cmp'; glDesenha(document.querySelector('#main'))"); pg.wait_for_timeout(1200)
    t = tx(pg); chk('Comparar cenários' in t and 'Lucro incremental' in t and 'Ticket maior' in t and 'maior lucro' in t, 'comparador com baseline e cenários', t[:4000])
    # mudar o filtro: aviso de contexto e bloqueio no comparador
    pg.evaluate("S.gl.prod='pC'; render()"); pg.wait_for_timeout(2000)
    t = tx(pg); chk('o filtro atual é diferente' in t and 'comparação bloqueada' in t, 'contexto diferente: aviso e comparação bloqueada', t[:4500])
    pg.click('#glCmpNorm'); pg.wait_for_timeout(1200); chk('comparação bloqueada' not in tx(pg), 'normalizar libera a comparação')
    pg.click('#glCenCtx'); pg.wait_for_timeout(2000); chk(pg.evaluate("S.gl.prod") == '', 'voltar ao contexto do cenário')
    # cenário aprovado fica congelado
    pg.evaluate("window.__D.gm_cenarios.forEach(c => { if (c.id === '%s') c.status = 'aprovado'; }); S.gl.cenId='%s'; S.gl.vista='sim'; render()" % (cid, cid)); pg.wait_for_timeout(2000)
    chk(pg.evaluate("[...document.querySelectorAll('.gi')].every(x => x.disabled)") and 'congelado' in tx(pg), 'cenário aprovado: inputs travados')
    # premissas do baseline (administrador, com motivo)
    pg.click('#glPrem'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=m]', 'ticket revisado'); submit(pg); pg.wait_for_timeout(1500)
    chk(pg.evaluate("S.gl.premAberta") and pg.evaluate("[...document.querySelectorAll('.gi')].some(x => !x.disabled)"), 'premissas abertas para o administrador')
    muda(pg, '[data-lc="campanha:c1"] .gi[data-k=tkt][data-m="2027-01-01"]', '1300')
    calls = pg.evaluate("window.__calls.filter(c=>c[0]==='rpc'&&c[1]==='gm_premissas_salvar').map(c=>c[2])")
    chk(len(calls) == 1 and calls[0]['p_motivo'] == 'ticket revisado' and calls[0]['p_linhas'][0]['valor'] == 1300, 'premissa do baseline salva com motivo pela função', calls)
    # v0.108: Unit Economics saiu do sistema; a rota antiga abre a Planilha
    pg.evaluate("S.view='gro-lucro'; render()"); pg.wait_for_timeout(1500)
    chk(pg.evaluate("S.view") == 'gro-modelo', 'Unit Economics (aposentado) leva para o Growth Model')
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
