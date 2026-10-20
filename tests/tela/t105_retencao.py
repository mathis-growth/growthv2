import json, os, tempfile
# Teste de tela da v0.105: RevOps → Retenção & Expansão (coortes, recompra, RFM, investigação, visões salvas, CSV).
# Os números vêm de t105_dados.json: saída das funções do banco rodadas sobre tests/banco/retencao_base.sql (5 clientes conhecidos).
# Rodar: python3 tests/tela/t105_retencao.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't105_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
RX = json.load(open(SP + 't105_dados.json'))
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([{'id': '00000000-0000-0000-0000-0000000000b1', 'nome': 'Curso', 'nivel_escada': 1, 'categoria': None}, {'id': '00000000-0000-0000-0000-0000000000b2', 'nome': 'Livro', 'nivel_escada': 2, 'categoria': None}, {'id': '00000000-0000-0000-0000-0000000000b3', 'nome': 'Bump', 'nivel_escada': None, 'categoria': None}, {'id': '00000000-0000-0000-0000-0000000000b4', 'nome': 'Mentoria', 'nivel_escada': 3, 'categoria': None}]), 'campanhas': ws([dict(id='00000000-0000-0000-0000-0000000000c1', nome='Lançamento')]),
  'pessoas': ws([dict(id='p1', nome='Ana', canal_origem='meta_ads', utm_source='facebook'), dict(id='p2', nome='Caio', canal_origem='google_ads', utm_source='google')]),
  'revops_config': [], 'revops_visoes': [],
}
RPC = r"""window.__RX = """ + json.dumps(RX) + r""";
window.__RPC = {
  revops_coortes: a => window.__RX[a.p_f && a.p_f.canal ? 'coortes|canal' : 'coortes|' + a.p_gran + '|' + a.p_agrupar],
  revops_recompra: a => window.__RX.recompra,
  revops_rfm: a => window.__RX[a.p_cruzar === 'canal' ? 'rfm|canal' : (a.p_cfg && a.p_cfg.metodo === 'limites' ? 'rfm|limites' : 'rfm|quintis')],
  revops_clientes_de: a => { window.__ultSel = a.p_sel; window.__ultF = a.p_f; return window.__RX[a.p_sel.segmento ? 'clientes|hib' : a.p_sel.recomprou ? 'clientes|recomprou' : 'clientes|todos']; } };"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ').replace('R$ ', '')
def muda(pg, sel, v): pg.evaluate("([s, v]) => { const i = document.querySelector(s); i.value = v; i.dispatchEvent(new Event('change', { bubbles: true })); }", [sel, v]); pg.wait_for_timeout(900)
def fecha(pg): pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1500, 'height': 2600}, accept_downloads=True); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-15'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    # pelo menu
    pg.click('#nav button[data-g=RevOps]'); pg.wait_for_timeout(300)
    itens = pg.evaluate("[...document.querySelectorAll('#nav button[data-v]')].map(b=>b.dataset.v)")
    chk('ho-retencao' in itens and 'ho-cohort' not in itens and 'ho-ascensao' not in itens, 'menu RevOps: Retenção & Expansão no lugar de Cohorts e Ascensão', itens)
    pg.click('#nav button[data-v=ho-retencao]'); pg.wait_for_timeout(1500)
    t = tx(pg)
    chk('Retenção & Expansão' in t and pg.locator('[data-rxa]').count() == 3, 'abre a tela com as três abas', t[:300])
    chk('Clientes únicos ⓘ / 5' in t and '13.200,00' in t and '15,2%' in t, 'coortes: clientes, receita acumulada e % de existentes', t[:1500])
    chk('11.400,00' in t and 'sobre 90,9% da receita' in t, 'margem de contribuição só sobre a receita com custo cadastrado', t[:1500])
    chk('2ª compra em 30 dias ⓘ / indisponível / parcial 25%' in t, 'D30 indisponível (coorte incompleta), com o parcial', t[:1500])
    chk('85 dias' in t and '40%' in t, 'tempo mediano até a 2ª compra e % com 2+ compras', t[:1500])
    chk(pg.locator('svg.rx-graf path.ln').count() >= 1 and pg.locator('.rx-hm td.c').count() > 0, 'curva de 2ª compra e matriz de coortes desenhadas')
    chk(pg.locator('.rx-def').count() > 5, 'definição das métricas no ⓘ')
    # investigar: clicar no KPI 2+ compras
    pg.locator('.kpi.clic').last.click(); pg.wait_for_timeout(900)
    m = tx(pg, '#modalRoot'); chk('Ana' in m and 'Davi' in m and pg.evaluate("window.__ultSel.recomprou") == 'sim', 'clicar no indicador lista os clientes que recompraram', m[:500])
    pg.click('#modalRoot summary'); pg.wait_for_timeout(200)
    chk('1ª ·' in tx(pg, '#modalRoot'), 'histórico de compras do cliente')
    with pg.expect_download() as dl: pg.click('#rxCsv')
    csv = open(dl.value.path(), encoding='utf-8-sig').read()
    chk(csv.startswith('"Nome";"E-mail"') and 'Ana' in csv, 'exporta CSV', csv[:200])
    fecha(pg)
    # clicar numa célula da matriz
    pg.locator('.rx-hm td.c').first.click(); pg.wait_for_timeout(800)
    chk('coorte' in json.dumps(pg.evaluate("window.__ultSel")), 'célula da matriz investiga a coorte', pg.evaluate("window.__ultSel"))
    fecha(pg)
    # intervalo trimestral e visão por produto
    muda(pg, '#rxGran', 'trimestre'); chk('tri/' in tx(pg), 'coortes trimestrais')
    muda(pg, '#rxVisao', 'produto'); t = tx(pg); chk('Curso' in t and 'Produto de entrada' in t, 'visão por produto de entrada', t[:800])
    muda(pg, '#rxVisao', 'consolidada'); muda(pg, '#rxGran', 'mes')
    # filtro global chega no banco
    muda(pg, '#rxCanal', 'meta_ads')
    f = [c for c in pg.evaluate("window.__calls") if c[0] == 'rpc' and c[1] == 'revops_coortes'][-1][2]['p_f']
    chk(f.get('canal') == 'meta_ads' and 'Clientes únicos ⓘ / 2' in tx(pg), 'filtro de canal vai para a função e muda os números', f)
    # salvar visão
    pg.click('#rxSalvar'); pg.wait_for_timeout(300); pg.fill('#modalRoot [name=nome]', 'Meta Ads'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1000)
    v = pg.evaluate("window.__D.revops_visoes"); chk(len(v) == 1 and v[0]['filtros']['canal'] == 'meta_ads' and v[0]['aba'] == 'coortes', 'visão salva com os filtros', v)
    pg.click('#rxLimpa'); pg.wait_for_timeout(1200); chk(pg.input_value('#rxCanal') == '', 'limpar filtros')
    # aba recompra
    pg.click('[data-rxa=recompra]'); pg.wait_for_timeout(1500); t = tx(pg)
    chk('Clientes com 1ª compra ⓘ / 5' in t and 'Clientes com 2ª compra ⓘ / 2' in t and '40%' in t, 'recompra: 1ª, 2ª e taxa', t[:900])
    chk('140 dias' in t and '1.500,00' in t and '500,00' in t, 'intervalo mediano, receita da 2ª e da 3ª em diante', t[:1200])
    chk('Mentoria' in t and 'Livro' in t and 'Expande' in t, 'produtos de 2ª compra e papel do produto de entrada', t[1000:4000])
    import re
    mm = re.search(r'vendas aprovadas \(líquido\) ([\d.,]+) \+ parcelas de contrato ([\d.,]+) = ([\d.,]+)', t); n_ = lambda z: float(z.replace('.', '').replace(',', '.'))
    chk(mm and abs(n_(mm.group(1)) + n_(mm.group(2)) - n_(mm.group(3))) < 0.01 and n_(mm.group(3)) > 0, 'novos × existentes reconcilia com o financeiro', t[-1500:])
    chk(pg.locator('.rx-hm td.c').count() == 2, 'matriz de transição Curso→Livro e Mentoria→Curso')
    pg.locator('.rx-hm td.c').first.click(); pg.wait_for_timeout(700)
    sl = pg.evaluate("window.__ultSel"); chk('de' in sl and 'para' in sl, 'célula da transição investiga de → para', sl); fecha(pg)
    pg.evaluate("[...document.querySelectorAll('svg.rx-graf rect.rxb')].find(r => +r.getAttribute('height') > 0).dispatchEvent(new MouseEvent('click', { bubbles: true }))"); pg.wait_for_timeout(700)
    chk('d2_min' in pg.evaluate("window.__ultSel"), 'barra da distribuição investiga a faixa de dias'); fecha(pg)
    # aba RFM
    pg.click('[data-rxa=rfm]'); pg.wait_for_timeout(1500); t = tx(pg)
    chk('Clientes avaliados ⓘ / 5' in t and 'Recência × frequência' in t, 'RFM: clientes e grade R×F', t[:900])
    muda(pg, '#rfMet', 'limites'); pg.wait_for_timeout(600); t = tx(pg)
    chk('Hibernando' in t and 'Novos clientes' in t and 'Potenciais leais' in t and 'Precisam de atenção' in t, 'segmentos por limites', t[:2500])
    pg.locator('tr.rx-clk', has_text='Hibernando').click(); pg.wait_for_timeout(800)
    m = tx(pg, '#modalRoot'); chk('Bia' in m and 'Caio' in m and pg.evaluate("window.__ultSel.segmento") == 'Hibernando' and pg.evaluate("window.__ultSel.cfg.metodo") == 'limites', 'segmento lista os clientes com a mesma configuração', m[:400]); fecha(pg)
    muda(pg, '#rfCrz', 'canal'); chk('Canal de aquisição' in tx(pg), 'cruza segmentos com canal')
    pg.click('#rfCfg'); pg.wait_for_timeout(400)
    pg.fill('#modalRoot [name=n0]', 'Campeões da casa'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1000)
    c = pg.evaluate("window.__D.revops_config"); chk(len(c) == 1 and c[0]['rfm']['segmentos'][0]['nome'] == 'Campeões da casa' and c[0]['rfm']['limites']['r'] == [30, 90, 180, 365], 'configuração do RFM salva (segmentos e limites)', c)
    pg.click('#rfCfg'); pg.wait_for_timeout(300); pg.fill('#modalRoot [name=lr]', '90, 30'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(500)
    chk('4 números crescentes' in tx(pg, 'body') and len(pg.evaluate('window.__D.revops_config')[0]['rfm']['limites']['r']) == 4 and pg.evaluate('window.__D.revops_config')[0]['rfm']['limites']['r'][0] == 30, 'limites inválidos são recusados'); fecha(pg)
    # link antigo (Ascensão) cai na aba recompra
    pg.evaluate("S.view='ho-ascensao'; render()"); pg.wait_for_timeout(1200)
    chk(pg.evaluate("S.view") == 'ho-retencao' and pg.evaluate("S.rx.aba") == 'recompra', 'endereço antigo da Ascensão abre a aba Recompra')
    # banco sem a atualização
    pg.evaluate("window.__RPC.revops_coortes = () => { throw new Error('Could not find the function public.revops_coortes in the schema cache'); }; S.rx.aba='coortes'; render()"); pg.wait_for_timeout(1000)
    chk('Falta atualizar o banco' in tx(pg), 'aviso quando a migração ainda não rodou')
    pg.screenshot(path=os.path.join(tempfile.gettempdir(), 't105.png'))
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
