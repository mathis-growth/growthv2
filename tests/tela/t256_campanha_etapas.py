import json, os, tempfile, datetime as dt
# Teste de tela da v0.256: campanha por etapas com dados reais, filtros e Growth Model.
# Rodar: python3 tests/tela/t256_campanha_etapas.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't256_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
H0 = dt.date.today()
def d(n): return (H0 + dt.timedelta(days=n)).isoformat()
leads, traf, vend, toq, ppl = [], [], [], [], []
for n in range(-40, -18):
    for k in range(6):
        pid = f'p{n}_{k}'; ppl.append(dict(id=pid, nome=f'Pessoa {pid}'))
        leads.append(dict(id='l' + pid, campanha_id='c1', pessoa_id=pid, entrou_em=d(n) + 'T15:00:00Z', canal='meta_ads' if k < 4 else 'google_ads', campanha_canal_id='k1' if k < 4 else 'k2', utm_content='a1' if k < 4 else 'a2', pessoas=dict(nome=f'Pessoa {pid}', qualificacao='qualificado' if k % 2 else 'pendente')))
    traf.append(dict(campanha_id='c1', anuncio_id='a1', data=d(n), custo=40, impressoes=3000, cliques=60, visualizacoes_pagina=50))
    traf.append(dict(campanha_id='c1', anuncio_id='a2', data=d(n), custo=30, impressoes=1000, cliques=30, visualizacoes_pagina=25))
for n in range(-17, -10):
    for k in range(3): toq.append(dict(campanha_id='c1', pessoa_id=f'p{n-23}_{k}', em=d(n) + 'T15:00:00Z', tipo='lista', descricao='Grupo de WhatsApp'))
for n in range(-10, -3):
    for k in range(2):
        vend.append(dict(id=f'v{n}_{k}', campanha_id='c1', pessoa_id=f'p{n-30}_{k}', oferta_id='o1', status='aprovada' if not (n == -10 and k == 0) else 'reembolsada', data_venda=d(n) + 'T15:00:00Z', valor_bruto=1000, taxa_plataforma=100, impostos=50, reembolsada_em=(d(-2) + 'T15:00:00Z') if n == -10 and k == 0 else None, pessoas=dict(nome='Comprador')))
    vend.append(dict(id=f'b{n}', campanha_id='c1', pessoa_id=f'p{n-30}_0', oferta_id='o2', status='aprovada', data_venda=d(n) + 'T15:00:00Z', valor_bruto=97, taxa_plataforma=9, impostos=5, pessoas=dict(nome='Comprador')))
C = dict(id='c1', nome='Lançamento Real', status='ativa', produto_id='p1', modelo='lancamento', data_inicio=d(-40), data_fim=d(30), data_carrinho_abre=d(-10), data_carrinho_fecha=d(-4), orcamento_total=5000, meta_leads=100, meta_vendas=20, meta_cpl=10, meta_receita=20000, meta_cac=200, extras={},
  fases=dict(aquisicao=dict(ini=d(-40), fim=d(-18)), aquecimento=dict(ini=d(-17), fim=d(-11)), conversao=dict(ini=d(-10), fim=d(-4))))
C2 = dict(id='c2', nome='Sem datas', status='rascunho', produto_id='p1', funil_id='f9', modelo='lancamento', data_inicio=d(-5), data_fim=d(5), fases={}, extras={})
SEED = {'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'campanhas': ws([C, C2, dict(id='c0', nome='Anterior', modelo='lancamento', data_inicio=d(-200), fases={}, extras={})]), 'produtos': ws([dict(id='p1', nome='Curso', preco=1000)]), 'funis': ws([]), 'projetos': ws([]),
  'v_marketing_campanha': ws([dict(campanha_id='c0', nome='Anterior', investimento=3000, leads=300, vendas=20, faturamento=18000)]),
  'campanha_canais': ws([dict(id='k1', campanha_id='c1', canal='meta_ads', temperatura='frio'), dict(id='k2', campanha_id='c1', canal='google_ads', temperatura='morno')]),
  'anuncios': ws([dict(id='a1', nome='Vídeo depoimento', utm_content='a1', campanha_canal_id='k1'), dict(id='a2', nome='Busca', utm_content='a2', campanha_canal_id='k2')]),
  'campanha_ofertas': ws([dict(id='co1', campanha_id='c1', oferta_id='o1', nome='À vista', papel='principal', preco=1000, taxa_aceite=None), dict(id='co2', campanha_id='c1', oferta_id='o2', nome='Bump Planilha', papel='order_bump', preco=97, taxa_aceite=25), dict(id='co3', campanha_id='c1', oferta_id='o3', nome='Bump Checklist', papel='order_bump', preco=47, taxa_aceite=10)]),
  'v_trafego_anuncio_dia': ws(traf), 'campanha_participacoes': ws(leads), 'vendas': ws(vend), 'pessoa_toques': ws(toq), 'comissoes': ws([]), 'fontes_video': ws([]), 'presencas_video': [], 'plataformas_venda': ws([dict(id='pl', nome='Hotmart', taxa_percentual=10)]), 'growth_experimentos': [],
  'campanha_blocos': ws([dict(id='b1', campanha_id='c1', nome='Tráfego pago', fase='aquisicao'), dict(id='b2', campanha_id='c1', nome='Grupo de WhatsApp', fase='aquecimento')]),
  'campanha_etapas': ws([dict(id='e1', campanha_id='c1', fase='aquisicao', nome='Tráfego pago · Investimento', unidade='brl', bloco_id='b1', ordem=1, ativa=True), dict(id='e2', campanha_id='c1', fase='aquisicao', nome='Tráfego pago · Cliques', unidade='numero', bloco_id='b1', ordem=2, ativa=True), dict(id='e3', campanha_id='c1', fase='aquecimento', nome='Grupo de WhatsApp · Entradas', unidade='numero', bloco_id='b2', ordem=3, ativa=True), dict(id='e4', campanha_id='c1', fase='aquisicao', nome='Página · Leads', unidade='numero', ordem=4, ativa=True)]),
  'estrategia_etapas': ws([dict(id='x1', funil_id='f9', fase='aquisicao', nome='Página · Leads', unidade='numero', ordem=1), dict(id='x2', funil_id='f9', fase='conversao', nome='Checkout · Checkouts iniciados', unidade='numero', ordem=2)]), 'estrategia_blocos': ws([])}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1100}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("window.__RPC = { ...(window.__RPC || {}), campanha_etapas_dia: () => [{ id: 'e1', dias: { [new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10)]: 70 } }, { id: 'e2', dias: {} }] }")
    def abre(cid):
        pg.evaluate("""async id => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-camp'; S.campSel = id; S.campTab = null; const m = document.querySelector('main') || document.body; await vCampanha(m); }""", cid); pg.wait_for_timeout(700)
    def foto(n):
        if FOTOS: pg.screenshot(path=os.path.join(FOTOS, n + '.png'), full_page=True)
    def txt(): return pg.locator('#ceHost').evaluate("e => e.shadowRoot.querySelector('.pag').innerText")
    def et(k): pg.locator(f'#ceHost [data-et="{k}"]').first.click(); pg.wait_for_timeout(250)
    abre('c1')
    chk(pg.evaluate("document.querySelector('.tabs').style.display") == 'none', 'o menu antigo já nasce escondido')
    chk(pg.locator('#ceHost').count() == 1, 'campanha com datas abre a tela por etapas')
    t = txt()
    for n in ['Geral', 'Captação', 'Aquecimento', 'Carrinho', 'Pós-venda', 'Growth Model']: chk(n in t, 'barra mostra ' + n, t[:300])
    chk('Reabertura' not in t, 'sem reabertura nas datas, ela não aparece')
    chk('NaN' not in t and 'undefined' not in t, 'etapa do dia sem número quebrado', t[:800])
    foto('et_abre')
    et('geral'); t = txt()
    chk('meta 100' in t, 'Geral mostra a meta de leads da campanha', t[:500])
    chk('Bump Planilha' in t and 'Bump Checklist' in t, 'cada order bump aparece em uma linha', t[:900])
    chk(pg.locator('#ceHost').evaluate("e => e.shadowRoot.querySelector('.painel .kpis').querySelectorAll('.kpi svg.spk').length") >= 5, 'cards do topo têm mini gráfico')
    chk(pg.locator('#ceHost').evaluate("e => e.shadowRoot.querySelector('details.mais') && !e.shadowRoot.querySelector('details.mais').open"), 'os outros números ficam em Mais números')
    ord_ = pg.locator('#ceHost').evaluate("e => { const q = e.shadowRoot.querySelector('.painel').innerText; return [q.indexOf('Faturamento e investimento acumulados'), q.indexOf('Resultado por etapa')]; }"); chk(ord_[0] < ord_[1], 'gráficos vêm antes das tabelas', ord_)
    chk('Faturamento' in t and 'Receita líquida' in t and 'Comparar com outras campanhas' in t and 'Anterior' in t, 'Geral tem faturamento, receita líquida e comparação', t[:600])
    chk(pg.locator('#ceHost').evaluate("e => e.shadowRoot.querySelectorAll('.gf svg').length") >= 4, 'Geral desenha os gráficos')
    chk('NaN' not in t and 'undefined' not in t, 'Geral sem número quebrado', t[:800])
    foto('et_geral')
    et('cap'); t = txt()
    chk('Tráfego pago' in t and 'Página' in t and 'Visão da etapa' in t, 'submenu vem da estratégia, por bloco', t[:300])
    chk('Grupo de WhatsApp' not in t, 'submenu só da etapa aberta')
    pg.locator('#ceHost [data-sub="Tráfego pago"]').click(); pg.wait_for_timeout(250); t9 = txt()
    chk('Captação · Tráfego pago' in t9 and 'Investimento por dia' in t9 and 'Cliques por dia' in t9 and 'R$ 70' in t9 and 'NaN' not in t9, 'submenu abre número, gráfico e dia a dia', t9[:500])
    foto('et_submenu')
    pg.locator('#ceHost [data-sub=""]').click(); pg.wait_for_timeout(150); t = txt()
    chk('132' in t, 'captação conta os 132 leads reais', t[:400])
    chk('R$ 11,67' in t, 'CPL real: 1.540 ÷ 132', t[:500])
    pg.locator('#ceHost [data-per="1"]').click(); pg.wait_for_timeout(200); t2 = txt()
    chk('42' in t2, 'filtro da semana 2 muda os números (42 leads)', t2[:300])
    pg.locator('#ceHost #fxCmp').select_option('anterior'); pg.wait_for_timeout(200)
    chk('Semana 1' in pg.locator('#ceHost .leg').first.inner_text(), 'compara com a semana anterior no gráfico')
    pg.locator('#ceHost #fxCmp').select_option(''); pg.locator('#ceHost [data-per="tudo"]').click(); pg.wait_for_timeout(200)
    pg.locator('#ceHost #fxCanal').select_option('Google Ads'); pg.wait_for_timeout(200); t3 = txt()
    chk('44' in t3, 'filtro de canal muda os números (44 leads do Google)', t3[:300])
    pg.locator('#ceHost #fxCanal').select_option(''); pg.locator('#ceHost #fxVer').select_option('canal'); pg.wait_for_timeout(200)
    leg = pg.locator('#ceHost .leg').first.inner_text()
    chk('Meta Ads' in leg and 'Google Ads' in leg, 'gráfico abre por canal', leg)
    foto('et_cap_canal')
    pg.locator('#ceHost #fxVer').select_option('total'); pg.wait_for_timeout(100)
    pg.locator('#ceHost [data-abre="coorte:semana"]').first.click(); pg.wait_for_timeout(200); a = txt()
    pg.locator('#ceHost [data-gcoorte="canal"]').click(); pg.wait_for_timeout(200); bb = txt()
    chk('Leads em cada grupo' in bb and 'Google Ads' in bb and a != bb, 'cohorts: gráfico muda com o agrupamento', bb[:400])
    foto('et_coorte')
    pg.locator('#ceHost [data-volta]').click(); pg.wait_for_timeout(100)
    et('aq'); t = txt(); chk('21' in t and 'NaN' not in t, 'aquecimento conta entradas no grupo', t[:300])
    et('car'); t = txt(); chk('Vendas' in t and 'NaN' not in t and 'undefined' not in t, 'carrinho sem número quebrado', t[:500])
    foto('et_car')
    et('pos'); t = txt(); chk('Reembolso' in t and 'NaN' not in t, 'pós-venda mostra o motivo real da saída', t[:500])
    et('gm'); t = txt(); chk('Growth Model da campanha' in t and 'NaN' not in t and 'Só nesta prévia' not in t, 'Growth Model com meta e real', t[:500])
    foto('et_gm')
    pg.locator('#ceHost #simAbre').click(); pg.wait_for_timeout(300); t = txt()
    chk('Trocar os criativos' not in t, 'simulador não traz hipótese de exemplo')
    chk('NaN' not in t and 'undefined' not in t, 'simulador sem número quebrado', t[:600])
    foto('et_sim')
    chk(pg.evaluate("document.querySelector('.tabs').style.display") == 'none', 'abas ficam escondidas na tela por etapas'); pg.click('#cOutras'); chk(pg.evaluate("document.querySelector('.tabs').style.display") == '' and pg.evaluate("document.querySelectorAll('[data-t]').length") > 3, 'outras visões abrem com um clique')
    abre('c2'); t = txt()
    chk(pg.locator('#ceHost').count() == 1 and 'Completar a campanha' in t, 'rascunho sem datas abre a tela e avisa', t[:400])
    chk('Aquecimento' in t and 'Carrinho' in t and 'sem data definida' in t, 'Aquecimento e Carrinho sempre aparecem', t[:400])
    chk('NaN' not in t and 'undefined' not in t, 'sem datas, sem número quebrado', t[:500])
    et('car'); t = txt(); chk('Carrinho ainda não tem data' in t and 'Checkout' in t, 'carrinho sem data explica e mostra as etapas da estratégia', t[:400])
    pg.locator('#ceHost [data-sub="Checkout"]').click(); pg.wait_for_timeout(200); t = txt(); chk('Checkouts iniciados' in t and 'Trazer para a campanha' in t, 'etapa da estratégia ainda não copiada', t[:400])
    et('geral'); t = txt(); chk('NaN' not in t and 'Carrinho' in t, 'Geral lista as etapas sem data', t[:500])
    et('cap')
    foto('et_sem_datas')
    pg.click('#cEd'); pg.wait_for_timeout(700)
    chk(pg.evaluate("!!document.querySelector('#modalRoot .wz, #modalRoot [data-passo], #modalRoot form') && /Passo|Comercial|O básico/.test(document.querySelector('#modalRoot').innerText)"), 'Editar campanha abre o assistente por etapas', pg.evaluate("document.querySelector('#modalRoot').innerText.slice(0, 200)"))
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t256:', 'tudo OK' if ok else 'COM FALHAS')
