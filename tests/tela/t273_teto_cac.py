import json, os, tempfile
# Teste de tela da v0.273: aba Teto de CAC no cockpit (geral e por produto), clique no LTV abre o mês a mês e os ajustes do produto,
# configuração da taxa (Selic ou própria) e o teto na calculadora da campanha.
# A resposta de cac_teto (t273_teto.json) saiu do banco de teste (tests/banco/v0273_teto_cac.sql), não foi escrita à mão.
# Rodar: python3 tests/tela/t273_teto_cac.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't273_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
T = json.load(open(SP + 't273_teto.json', encoding='utf-8'))
PROD = {p['nome']: p['produto_id'] for p in T['produtos']}
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'campanhas': ws([dict(id='cp1', nome='Lançamento de março', status='ativa', produto_id=PROD['Curso'], meta_leads=1000, meta_taxa_lead_venda=2, meta_cpl=20)]),
  'campanha_calculos': ws([]), 'canais': ws([]), 'campanha_canais': [],
  'produtos': ws([dict(id=v, nome=k, ativo=True, preco=1000, extras={}) for k, v in PROD.items()]),
  'ltv_config': [],
  'rpc:painel_gerencial': {'funil': {'total': 120}, 'vendas': {'aprovadas': 12}, 'caixa': {'saldo': 18500}, 'resultado': {'receita': 24000}, 'cac': {'cac_total': 400, 'novos': 2}, 'fluxo': {}},
  'rpc:cac_teto': T, 'rpc:campanha_ofertas_resultado': [], 'rpc:selic_pedir': 1, 'rpc:selic_ler': 30,
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
def txt(pg, sel): return pg.inner_text(sel).replace(' ', ' ')
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e))); pg.on('dialog', lambda d: d.accept())
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.abas = {}; S.view = 'cockpit'; render();"); pg.wait_for_timeout(1200)
    chk(pg.locator('[data-abas="ck"] [data-aba-k="teto"]').count() == 1, 'aba Teto de CAC no cockpit')
    chk(not any(c[1] == 'cac_teto' for c in pg.evaluate("__calls") if c[0] == 'rpc'), 'o teto só é calculado quando a aba abre')
    pg.click('[data-abas="ck"] [data-aba-k="teto"]'); pg.wait_for_timeout(600)
    box = txt(pg, '#tcBox')
    g = T['geral']
    chk('Teto de CAC da empresa' in box and 'R$ 2.043,14' in box and '5,11x' in box and 'Folga para escalar' in box, 'quadro da empresa: LTV, LTV/CAC e faixa', box[:500])
    chk('R$ 1.135,08' in box and 'R$ 1.035,08' in box and '1,03x' in box, 'CAC total máximo, CAC de mídia máximo e ROAS mínimo', box[:800])
    chk('Selic de 05/11/2026: 15,00% ao ano (1,17% ao mês)' in box, 'mostra a Selic usada no desconto', box[:400])
    linhas = pg.evaluate("[...document.querySelectorAll('.tc-t tbody tr')].map(r => r.cells[0].innerText + '|' + r.cells[1].innerText)")
    chk(linhas == ['Curso|Real', 'Assinatura|Misto', 'Imersão|Planejado'], 'uma linha por produto, com a fonte', linhas)
    chk(pg.evaluate("[...document.querySelectorAll('.tc-quadro')].every(q => getComputedStyle(q).boxShadow !== 'none' && parseFloat(getComputedStyle(q).borderTopWidth) >= 2)"), 'quadros com borda e sombra')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'teto_cockpit.png'), full_page=True)
    # clique no LTV da empresa: mês a mês
    pg.click('[data-tc-ltv="*"]'); pg.wait_for_timeout(300)
    md = txt(pg, '#modalRoot')
    chk('ltv estimado no fim de cada mês' in md.lower() and pg.locator('#modalRoot svg.ck-svg').count() >= 2 and 'de onde vem o ltv' in md.lower(), 'LTV abre o gráfico mês a mês, o acumulado e as partes', [md[:900], pg.locator('#modalRoot svg.ck-svg').count()])
    chk(pg.locator('#modalRoot [name=ltv_meta]').count() == 0, 'empresa não tem ajustes de produto')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'teto_ltv_mes.png'))
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(200)
    # produto: ajustes
    pg.click('[data-tc-ltv="%s"]' % PROD['Assinatura']); pg.wait_for_timeout(300)
    md = txt(pg, '#modalRoot')
    chk('Renovação usada' in md and 'Ajustes deste produto' in md and pg.locator('#modalRoot [name=ltv_renovacao_pct]').count() == 1, 'produto recorrente mostra a renovação e os ajustes', md[-600:])
    pg.fill('#modalRoot [name=ltv_meta]', '2,5'.replace(',', '.')); pg.fill('#modalRoot [name=ltv_planejado]', '3000'); pg.fill('#modalRoot [name=ltv_renovacao_pct]', '60')
    pg.click('#modalRoot .acts .pri'); pg.wait_for_timeout(900)
    ex = pg.evaluate("__D.produtos.find(p => p.nome === 'Assinatura').extras")
    chk(ex.get('ltv_meta') == 2.5 and ex.get('ltv_planejado') == 3000 and ex.get('ltv_renovacao_pct') == 60 and ex.get('ltv_janela') == 36, 'ajustes vão para o produto', ex)
    chk(pg.evaluate("(S.abas || {}).ck") == 'teto' and pg.locator('#tcBox .tc-quadro').count() == 2, 'depois de salvar volta para a aba do teto, recalculado')
    # configuração
    pg.click('[data-tc-cfg]'); pg.wait_for_timeout(400)
    pg.select_option('#modalRoot [name=taxa_modo]', 'propria'); pg.click('#modalRoot .acts .pri'); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot .modal').count() == 1, 'taxa própria vazia não salva')
    pg.fill('#modalRoot [name=taxa_propria_aa]', '18'); pg.fill('#modalRoot [name=meta_ltv_cac]', '2'); pg.click('#modalRoot .acts .pri'); pg.wait_for_timeout(700)
    cf = pg.evaluate("__D.ltv_config[0]")
    chk(cf and cf['taxa_modo'] == 'propria' and cf['taxa_propria_aa'] == 18 and cf['meta_ltv_cac'] == 2 and cf['janela_meses'] == 12 and cf['min_clientes'] == 30, 'configuração salva', cf)
    pg.click('[data-tc-cfg]'); pg.wait_for_timeout(400)
    pg.click('#modalRoot [data-tc-selic]'); pg.wait_for_timeout(3200)
    chk('Selic atualizada' in pg.inner_text('#modalRoot [data-tc-selic-st]'), 'buscar a Selic agora', pg.inner_text('#modalRoot [data-tc-selic-st]'))
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(200)
    # calculadora da campanha
    pg.evaluate("async () => { S.cc = { camp: 'cp1', P: null, calcId: '', hint: '', ws: 'w1' }; S.gTab = 'calc'; const m = document.createElement('div'); m.id = 'tcCalc'; document.body.append(m); await vCalcCampanha(m); }"); pg.wait_for_timeout(900)
    out = txt(pg, '#ccOut')
    chk('Teto pelo LTV · Curso' in out and 'R$ 992,03' in out, 'calculadora mostra o teto do produto da campanha', out[-700:])
    cac0 = pg.evaluate("ccSaida(S.cc.P).cac")
    pg.click('#ccUsaTeto'); pg.wait_for_timeout(300)
    o = pg.evaluate("ccSaida(S.cc.P)")
    curso = next(p for p in T['produtos'] if p['nome'] == 'Curso')
    chk(abs(o['cac'] - curso['teto']['cac_midia_max']) < 0.01 and abs(o['cpl'] - curso['teto']['cac_midia_max'] * 0.02) < 0.01, 'usar o teto ajusta o CPL para o CAC caber', {'antes': cac0, 'depois': o['cac'], 'cpl': o['cpl']})
    if FOTOS: pg.locator('#ccOut').screenshot(path=os.path.join(FOTOS, 'teto_calculadora.png'))
    pg.set_viewport_size({'width': 390, 'height': 800}); pg.evaluate("document.getElementById('tcCalc').remove(); S.view = 'cockpit'; render();"); pg.wait_for_timeout(1200)
    chk(pg.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), 'cabe no celular')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t273:', 'tudo OK' if ok else 'COM FALHAS')
