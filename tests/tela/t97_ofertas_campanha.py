import json, os, tempfile
# Teste de tela da v0.97: catálogo de ofertas (pacote, versões), esteira ramificada da campanha, campanha híbrida com execução por canal, NSM, calculadora sem editar receita.
# Rodar: python3 tests/tela/t97_ofertas_campanha.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't97_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='pC', nome='Curso', preco=997, ativo=True), dict(id='pM', nome='Mentoria', preco=3000, ativo=True), dict(id='pE', nome='E-book', preco=47, ativo=True)]),
  'ofertas': ws([dict(id='o1', produto_id='pC', nome='Curso à vista', papel='principal', preco=997, ativo=True, status='ativa', versao=1, criado_em='2026-10-01'),
                 dict(id='o2', produto_id='pE', nome='E-book bump', papel='order_bump', preco=47, ativo=True, status='ativa', versao=1, criado_em='2026-10-02')]),
  'oferta_itens': ws([dict(id='i1', oferta_id='o1', produto_id='pC', quantidade=1, alocacao_pct=100), dict(id='i2', oferta_id='o2', produto_id='pE', quantidade=1, alocacao_pct=100)]),
  'oferta_versoes': ws([dict(id='v1', oferta_id='o1', versao=1, nome='Curso à vista', preco=997, itens=[], criado_em='2026-10-01T10:00:00Z')]),
  'funis': ws([dict(id='f1', nome='Lançamento', tipo='lancamento', ativo=True), dict(id='f2', nome='Perpétuo', tipo='perpetuo', ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Black', status='ativa', modelo='lancamento', tipo_midia='paga', funil_id='f1', data_inicio='2026-10-01', data_fim='2026-11-30', meta_vendas=200)]),
  'campanha_estrategias': ws([dict(id='ce1', campanha_id='c1', funil_id='f1', principal=True)]),
  'canais': ws([dict(codigo='meta_ads', nome='Meta Ads', tipo='pago', ativo=True), dict(codigo='instagram', nome='Instagram', tipo='organico', ativo=True)]),
  'campanha_canais': ws([dict(id='cc1', campanha_id='c1', canal='meta_ads', utm_campaign='black_meta', tipo='pago', funil_id='f1')]),
  'campanha_ofertas': ws([dict(id='co1', campanha_id='c1', produto_id='pC', oferta_id='o1', oferta_versao=1, nome='Curso', papel='principal', preco=997, ordem=0, condicao='sempre', pai_id=None, taxa_exposicao=None, taxa_aceite=None)]),
  'vendas': [], 'pessoas': [], 'contratos': [], 'projetos': [], 'equipe': [], 'growth_metricas': [], 'growth_experimentos': [], 'benchmarks_mercado': [],
  'rpc:campanha_canais_resultado': [], 'rpc:campanha_resultado': {}, 'v_marketing_campanha': [],
}
RPC = r"""
window.__RPC = {
  campanha_ofertas_resultado: (a, D) => D.campanha_ofertas.filter(x => x.campanha_id === a.p_campanha).map(x => ({ ...x, produto: (D.produtos.find(p => p.id === x.produto_id) || {}).nome, vendas: x.id === 'co1' ? 100 : 0, receita: x.id === 'co1' ? 99700 : 0, aceite: null, base_aceite: null })),
  oferta_salvar: (a, D) => {
    const its = a.p_itens; const soma = its.length === 1 ? 100 : its.reduce((t, x) => t + Number(x.alocacao_pct || 0), 0);
    if (Math.abs(soma - 100) > 0.01) throw new Error('Num pacote, a receita alocada aos produtos precisa somar 100% (está em ' + soma + '%)');
    let o = a.p_id ? D.ofertas.find(x => x.id === a.p_id) : null;
    if (!o) { o = { id: 'on' + D.ofertas.length, workspace_id: a.p_ws, versao: 0, criado_em: '2026-10-11' }; D.ofertas.push(o); }
    const mudou = o.preco !== a.p_dados.preco || o.nome !== a.p_dados.nome;
    Object.assign(o, a.p_dados, { produto_id: its[0].produto_id, ativo: a.p_dados.status === 'ativa' });
    D.oferta_itens = D.oferta_itens.filter(x => x.oferta_id !== o.id).concat(its.map((x, k) => ({ id: o.id + 'i' + k, workspace_id: a.p_ws, oferta_id: o.id, produto_id: x.produto_id, quantidade: x.quantidade, alocacao_pct: its.length === 1 ? 100 : x.alocacao_pct })));
    if (mudou) { o.versao = (o.versao || 0) + 1; D.oferta_versoes.push({ id: 'v' + D.oferta_versoes.length + 9, workspace_id: a.p_ws, oferta_id: o.id, versao: o.versao, nome: o.nome, preco: o.preco, itens: its, criado_em: '2026-10-11T10:00:00Z' }); }
    return o.id; }
};"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ').replace('R$ ', '')
def submit(pg): pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(900)
def fecha(pg): pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1500, 'height': 2400}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.97')
    # ---------- catálogo de ofertas ----------
    pg.evaluate("S.ws='w1'; S.view='cad-produtos'; render()"); pg.wait_for_timeout(1200)
    t = tx(pg); chk('Ofertas' in t and 'Curso à vista' in t and 'v1' in t, 'catálogo de ofertas com versão', t[-1500:])
    pg.click('#ofNova'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'Combo'); pg.fill('#modalRoot [name=preco]', '1500'); pg.fill('#modalRoot [name=condicoes]', '12x')
    pg.click('#ofAddIt'); pg.wait_for_timeout(200)
    rows = pg.locator('#modalRoot [data-it]')
    rows.nth(0).locator('[data-f=alocacao_pct]').fill('60'); rows.nth(1).locator('[data-f=produto_id]').select_option('pM'); rows.nth(1).locator('[data-f=alocacao_pct]').fill('30')
    submit(pg)
    chk('somar 100%' in pg.inner_text('body'), 'pacote sem 100% é recusado', pg.inner_text('#modalRoot')[:300])
    rows.nth(1).locator('[data-f=alocacao_pct]').fill('40'); submit(pg)
    combo = [o for o in D(pg, 'ofertas') if o['nome'] == 'Combo']
    chk(len(combo) == 1 and len([x for x in D(pg, 'oferta_itens') if x['oferta_id'] == combo[0]['id']]) == 2, 'pacote salvo com 2 produtos', combo)
    pg.wait_for_timeout(600); t = tx(pg)
    chk('pacote' in t and '60%' in t and '40%' in t, 'lista mostra o pacote com a alocação', t[-1500:])
    pg.click('[data-oe="%s"]' % combo[0]['id']); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=preco]', '1297'); submit(pg)
    chk([o for o in D(pg, 'ofertas') if o['nome'] == 'Combo'][0]['versao'] == 2, 'mudar o preço cria a versão 2')
    pg.wait_for_timeout(500); pg.click('[data-ov="%s"]' % combo[0]['id']); pg.wait_for_timeout(600)
    t = tx(pg, '#modalRoot'); chk('v2' in t and 'v1' in t and '1.500,00' in t and '1.297,00' in t, 'histórico de versões', t[:500]); fecha(pg)
    # ---------- esteira ----------
    pg.evaluate("S.view='mkt-camp'; S.campSel='c1'; S.campTab='ofertas'; render()"); pg.wait_for_timeout(1500)
    t = tx(pg); chk('Esteira de ofertas' in t and 'Curso' in t, 'aba de esteira na campanha', t[:800])
    pg.click('#ofAdd'); pg.wait_for_timeout(500)
    pg.select_option('#modalRoot #ofSel', 'o2'); pg.select_option('#modalRoot #ofPapel', 'order_bump'); pg.select_option('#modalRoot [name=pai_id]', 'co1')
    pg.fill('#modalRoot [name=taxa_aceite]', '20'); submit(pg)
    bump = [x for x in D(pg, 'campanha_ofertas') if x['papel'] == 'order_bump']
    chk(len(bump) == 1 and bump[0]['oferta_id'] == 'o2' and bump[0]['oferta_versao'] == 1 and abs(bump[0]['taxa_aceite'] - 0.2) < 1e-9 and bump[0]['pai_id'] == 'co1', 'order bump ligado à principal, com versão e premissa', bump)
    pg.wait_for_timeout(800)
    pg.click('#ofAdd'); pg.wait_for_timeout(500)
    pg.select_option('#modalRoot #ofProd', 'pM'); pg.fill('#modalRoot #ofNome', 'Mentoria'); pg.fill('#modalRoot #ofPreco', '3000'); pg.select_option('#modalRoot #ofPapel', 'upsell')
    pg.select_option('#modalRoot [name=pai_id]', 'co1'); pg.select_option('#modalRoot [name=condicao]', 'aceitou'); pg.fill('#modalRoot [name=taxa_aceite]', '10'); submit(pg)
    up = [x for x in D(pg, 'campanha_ofertas') if x['papel'] == 'upsell'][0]
    pg.wait_for_timeout(800)
    pg.click('#ofAdd'); pg.wait_for_timeout(500)
    pg.select_option('#modalRoot #ofProd', 'pM'); pg.fill('#modalRoot #ofNome', 'Mentoria lite'); pg.fill('#modalRoot #ofPreco', '1000'); pg.select_option('#modalRoot #ofPapel', 'downsell')
    pg.select_option('#modalRoot [name=pai_id]', up['id']); pg.select_option('#modalRoot [name=condicao]', 'aceitou'); submit(pg)
    chk('depois de uma recusa' in pg.inner_text('body'), 'downsell sem recusa é bloqueado na tela')
    pg.select_option('#modalRoot [name=condicao]', 'recusou'); pg.fill('#modalRoot [name=taxa_aceite]', '5'); submit(pg); pg.wait_for_timeout(900)
    t = tx(pg)
    # simulação com 100 compradores: bump 100×20%×47 = 940; upsell 100×10%×3000 = 30.000; downsell (100−10)×5%×1000 = 4.500; principal 100×997 = 99.700
    chk('se recusou em "Mentoria"' in t and '↳' in t, 'árvore mostra a ramificação', t[:2500])
    chk('940,00' in t and '30.000,00' in t and '4.500,00' in t and '135.140,00' in t, 'simulação: quem recebeu × exposição × aceite × preço; downsell sobre quem recusou', t[:3500])
    pg.fill('#ofComp', '200'); pg.dispatch_event('#ofComp', 'change'); pg.wait_for_timeout(900)
    chk('270.280,00' in tx(pg), 'mudar compradores recalcula a esteira')
    # ---------- campanha paga: execução orgânica bloqueada ----------
    pg.evaluate("S.campTab='resumo'; render()"); pg.wait_for_timeout(1500)
    t = tx(pg); chk('Estratégias da campanha' in t and 'Só paga' in t and 'paga' in t, 'planejamento mostra tipo de mídia, execução e estratégias', t[:3000])
    pg.click('#novoCanal'); pg.wait_for_timeout(500); pg.select_option('#modalRoot [name=canal]', 'instagram'); submit(pg)
    chk('só paga' in pg.inner_text('body') and not any(x['canal'] == 'instagram' for x in D(pg, 'campanha_canais')), 'campanha só paga não aceita execução orgânica', pg.inner_text('body')[-400:]); fecha(pg)
    pg.select_option('#ceSel', 'f2'); pg.click('#ceAdd'); pg.wait_for_timeout(900)
    chk(len(D(pg, 'campanha_estrategias')) == 2, 'segunda estratégia ligada à campanha')
    # ---------- calculadora: receita não é editável ----------
    pg.evaluate("S.view='gro-modelo'; S.gTab='calc'; S.cc={camp:'c1'}; render()"); pg.wait_for_timeout(1500)
    chk(pg.evaluate("(()=>{const i=document.querySelector('[data-cc=receita]'); return !!i && i.readOnly})()"), 'receita só leitura na calculadora')
    chk(pg.evaluate("(()=>{const i=document.querySelector('[data-cc=roas]'); return !!i && !i.readOnly})()") and pg.evaluate("(()=>{const i=document.querySelector('[data-cc=cac]'); return !!i && !i.readOnly})()"), 'CAC e ROAS continuam editáveis')
    # ---------- North Star ----------
    pg.evaluate("S.view='gro-modelo'; S.gTab='mapa'; render()"); pg.wait_for_timeout(1500)
    pg.evaluate("modalMetricaG(null, null, [])"); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot [name=nsm_evento]').count() == 1 and pg.locator('#modalRoot [name=produto_id] option').count() >= 3, 'cadastro da North Star com evento, população, frequência, fonte e produto')
    pg.fill('#modalRoot [name=nome]', 'Alunos que aplicaram'); pg.select_option('#modalRoot [name=tipo]', 'north_star'); pg.fill('#modalRoot [name=nsm_evento]', 'concluiu o módulo 1'); submit(pg)
    gm = D(pg, 'growth_metricas'); chk(len(gm) == 1 and gm[0]['nsm_evento'] == 'concluiu o módulo 1', 'North Star salva com o evento', gm)
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
