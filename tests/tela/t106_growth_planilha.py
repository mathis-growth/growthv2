import json, os, tempfile, re
# Teste de tela da v0.106: Growth Model em formato de planilha (Real travado | Cenário editável | Efeito), por venda por produto, preço/custo/regime/fixos no cenário,
# cores do que foi mexido e do que mudou, comparação de cenários salvos com ICE.
# Rodar: python3 tests/tela/t106_growth_planilha.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't106_growths.html')
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
  'produtos': ws([dict(id='pC', nome='Curso', preco=1000, ativo=True, extras={'mc_custo_pct': 10}), dict(id='pM', nome='Mentoria', preco=3000, ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Black', status='ativa', produto_id='pC', data_fim='2027-12-31')]),
  'gm_alavancas': ws([dict(id='a0', loop_chave='campanha:c1', produto_id=None, alavanca='tkt', mes='2026-12-01', cenario='base', valor=1200)]),
  'gm_cenarios': [], 'growth_metricas': [], 'auditoria': ws([dict(id=1, tabela='gm_alavancas', acao='alteracao', antes={'valor': 1000, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, depois={'valor': 1200, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, usuario_email='rebecka@x', em='2026-10-10T10:00:00Z')]),
  'plano_contas': ws([dict(id='pF', codigo='6.2.01', nome='Ferramentas e software', tipo='despesa', cac_grupo='ferramentas'), dict(id='pP', codigo='6.2.04', nome='Pró-labore', tipo='despesa'), dict(id='pMi', codigo='6.1.01', nome='Mídia paga – Meta', tipo='despesa')]),
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


def cel(pg, sel): return pg.evaluate("s => { const i = document.querySelector(s); return i ? i.closest('tr').innerText.replace(/\\s+/g, ' ') : null; }", sel)
def linha(pg, rot): return pg.evaluate("r => { const t = [...document.querySelectorAll('.gp-t tr')].find(x => x.cells[0] && x.cells[0].innerText.trim().startsWith(r)); return t ? t.innerText.replace(/\\s+/g, ' ').replace(/R\\$\\s/g, '') : null; }", rot)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1500, 'height': 2600}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    pg.click('#nav button[data-g=Growth]'); pg.wait_for_timeout(300); pg.click('#nav button[data-v=gro-modelo]'); pg.wait_for_timeout(2500)
    chk(pg.locator('#gsTopo').count() == 1 and pg.locator('.gp-sec').count() >= 4, 'pelo menu: planilha com topo e seções (resultado, por venda, loops)', pg.locator('.gp-sec').count())
    top = tx(pg, '#gsTopo')
    chk('249.000' in top and '1.033' in top and '233.567' in top and '100.567' in top and '8.381' in top, 'topo real: receita, impostos (DAS), margem de contribuição, lucro e lucro por mês', top)
    r = linha(pg, '= Lucro'); chk(r and '100.567,40' in r, 'linha do lucro no resultado', r)
    chk(pg.locator('.gp-sec[data-sec="p:pC"] .gp-t').count() == 1, 'primeiro produto (Curso) aberto em Por venda')
    r = linha(pg, '= Margem de contribuição por venda'); chk(r and '921,45 · 89,59%' in r, 'margem de contribuição por venda do Curso (preço − imposto − taxas − 10% de entrega)', r)
    # preço do Curso no cenário
    muda(pg, '.gp-in[data-gp=preco][data-p=pC]', '2000'); pg.wait_for_timeout(1200)
    cs = D(pg, 'gm_cenarios'); chk(len(cs) == 1 and cs[0]['financeiro'].get('precos', {}).get('pC') == 2000, 'mexer no preço cria o cenário e guarda o preço', cs)
    top = tx(pg, '#gsTopo'); chk('→ 385.000' in top and '→ 222.967' in top, 'preço do Curso vale para as vendas do Black: receita e lucro do cenário no topo', top)
    chk(pg.locator('.gp-in.mex[data-gp=preco]').count() == 1 and pg.locator('.gp-calc').count() > 3, 'cores: o que mexeu (amarelo) e o que mudou por consequência (azul)')
    # custo de entrega do Curso
    muda(pg, '.gp-in[data-gp=custo][data-p=pC][data-c=pct]', '20'); pg.wait_for_timeout(1000)
    top = tx(pg, '#gsTopo'); chk('→ 194.967' in top, 'custo de entrega 20% no Curso: lucro do cenário', top)
    # regime manual 10%
    pg.click('.gp-sec[data-sec=resultado] .gp-sh') if pg.locator('.gp-sec[data-sec=resultado] .gp-t').count() == 0 else None
    muda(pg, 'select.gp-in[data-f=regime]', 'manual'); pg.wait_for_timeout(1000)
    muda(pg, '.gp-in[data-f=aliq]', '10'); pg.wait_for_timeout(1000)
    top = tx(pg, '#gsTopo'); chk('→ 38.500' in top and '→ 157.500' in top, 'regime manual 10%: imposto sobe com a receita e o lucro cai', top)
    # custos fixos
    muda(pg, '.gp-in[data-f=fixos]', '100000'); pg.wait_for_timeout(1000)
    top = tx(pg, '#gsTopo'); c = D(pg, 'gm_cenarios')[0]['financeiro']
    chk('→ 177.500' in top and abs(c['ajuste'] + 20000 / 12) < 0.01, 'custos fixos do período no cenário viram ajuste por mês', [top, c])
    # loop: CTR do Black
    pg.click('.gp-sec[data-sec="l:campanha:c1"] .gp-sh'); pg.wait_for_timeout(600)
    muda(pg, '.gp-in[data-gp=loop][data-k="r:imp>clk"]', '2'); pg.wait_for_timeout(1200)
    al = [a for a in D(pg, 'gm_alavancas') if a['mes'] == '1900-01-01']; chk(len(al) == 1 and abs(al[0]['valor'] - 0.02) < 1e-9, 'etapa do loop guardada para todos os meses', al)
    top = tx(pg, '#gsTopo'); chk('→ 665.000' in top, 'CTR dobra as vendas do Black, já com o preço novo (280 × 2.000 + 105.000)', top)
    # novo cenário e comparação
    pg.click('#gsNovo'); pg.wait_for_timeout(300); pg.fill('#modalRoot [name=nome]', 'Só fixos'); submit(pg); pg.wait_for_timeout(1500)
    chk(len(D(pg, 'gm_cenarios')) == 2 and 'Cenário' not in tx(pg, '#gsTopo') or '→' not in tx(pg, '#gsTopo'), 'cenário novo começa igual ao real')
    muda(pg, '.gp-in[data-f=fixos]', '110000'); pg.wait_for_timeout(1000)
    pg.click('#gpCmp'); pg.wait_for_timeout(1500)
    t = tx(pg, '#gpCmpBox'); chk('Comparar cenários salvos' in t and 'Só fixos' in t and 'preço de Curso' in t and 'mexeu: custos fixos' in t, 'comparação: real e os cenários, com o que cada um mexeu', t[:800])
    chk(pg.locator('#gpCmpBox .gp-best').count() >= 5, 'melhor de cada linha em verde')
    ids = [c['id'] for c in D(pg, 'gm_cenarios')]
    for cid, notas in zip(ids, [(9, 4, 5), (4, 8, 9)]):
        for f, v in zip(['impacto', 'confianca', 'facilidade'], notas):
            muda(pg, f'#gpCmpBox .gp-ice[data-ice={f}][data-c="{cid}"]', str(v)); pg.wait_for_timeout(500)
    cs = D(pg, 'gm_cenarios'); chk(cs[0]['impacto'] == 9 and cs[1]['facilidade'] == 9, 'notas do ICE guardadas no cenário', cs)
    t = tx(pg, '#gpCmpBox'); chk(re.search(r'ICE\s+6,0\s+7,0', t) is not None, 'ICE de cada cenário', t[-600:])
    pg.locator('#gpCmpBox [data-gpap]').last.click(); pg.wait_for_timeout(800)
    chk('Aprovar cenário' in tx(pg, '#modalRoot') and 'Só fixos' in tx(pg, '#modalRoot'), 'aprovar abre a aprovação com documento de decisão e Kanban', tx(pg, '#modalRoot')[:300])
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    pg.locator('#gpCmpBox [data-gpab]').first.click(); pg.wait_for_timeout(1500)
    chk(pg.locator('#gsTopo').count() == 1 and pg.evaluate("S.gl.cenId") == ids[0], 'Abrir volta para a planilha no cenário escolhido')
    # limpar
    pg.click('#gsLimpa'); pg.wait_for_timeout(300); submit(pg); pg.wait_for_timeout(1500)
    c = [x for x in D(pg, 'gm_cenarios') if x['id'] == ids[0]][0]
    chk(c['financeiro'] == {} and not [a for a in D(pg, 'gm_alavancas') if a['cenario'] == ids[0]] and '→' not in tx(pg, '#gsTopo'), 'Limpar mudanças zera etapas e financeiro do cenário', c)
    # Mais opções continua
    pg.click('#gsMais'); pg.wait_for_timeout(300); chk(pg.locator('[data-gx=loop]').count() == 1, 'Mais opções continua com o modo detalhado')
    pg.screenshot(path=os.path.join(tempfile.gettempdir(), 't106.png'))
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
