import json, os, tempfile
# Teste de tela da v0.250: fase da campanha (captação sem ROAS), dashboard sem ROI e LTV, ticket médio, churn claro,
# luzinha de meta × planejado, foto com menu e saudação pelo horário.
# Rodar: python3 tests/tela/t250_fase_luz_topo.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't250_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def camp(id, nome, st='ativa', mod='lancamento', ini='2026-01-01', fim='2099-12-31', **k): return dict(id=id, nome=nome, status=st, produto_id='p1', modelo=mod, data_inicio=ini, data_fim=fim if mod != 'perpetuo' else None, **{'extras': {}, 'fases': {}, 'criado_em': '2026-01-01', **k})
def vis(id, inv, ld, vd, cl, rec, **k): return dict(campanha_id=id, workspace_id=W, nome=id, status='ativa', investimento=inv, leads=ld, qualificados=0, vendas=vd, clientes=cl, receita_bruta=rec, cpl=inv / ld if ld else None, cac=inv / cl if cl else None, roas=rec / inv if inv else None, taxa_lead_venda=vd * 100 / ld if ld else None, orcamento_total=k.get('orc'), meta_leads=k.get('ml'), meta_vendas=k.get('mv'), meta_receita=k.get('mr'), meta_cac=k.get('mc'))
POS = dict(leads=1094, vendas=380, clientes=342, receita=329690.85, custo=7020.15, alunos=344, ativos=322, saiu=22, churn=.064, ltv=964.01, cac=20.53, roas=46.96, roi=45.96)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Demo', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1497, ativo=True)]),
  'campanhas': ws([camp('cap', 'Em captação', fases={'aquisicao': {'ini': '2026-01-01', 'fim': '2099-01-01'}}, data_carrinho_abre='2099-06-01', meta_leads=1000, meta_vendas=10, meta_cac=500, meta_cpl=10, orcamento_total=8000),
    camp('aqu', 'Em aquecimento', fases={'aquecimento': {'ini': '2026-01-01', 'fim': '2099-01-01'}}, data_carrinho_abre='2099-06-01'),
    camp('ven', 'Em vendas', ini='2026-01-01', fim='2026-02-01', data_carrinho_abre='2026-01-15', meta_leads=100, meta_vendas=10, meta_receita=10000, meta_cac=500, meta_cpl=10, orcamento_total=1000, meta_taxa_lead_venda=5),
    camp('per', 'Perpétuo', mod='perpetuo')]),
  'v_marketing_campanha': [vis('cap', 3000, 300, 0, 0, 0, orc=8000, ml=1000, mc=500), vis('aqu', 100, 10, 0, 0, 0), vis('ven', 1000, 120, 10, 2, 16000, orc=1000, ml=100, mv=10, mr=10000, mc=500), vis('per', 100, 10, 0, 0, 0)],
  'rpc:funil_analise': dict(pos=POS, passos=[], campanhas=[], por_campanha={}, por_canal={}, diagnostico={}, nomes_campanhas={}, periodo={}, anterior={}), 'rpc:funil_cohorts': [],
  'rpc:campanha_series': dict(usa_trafego=False, dias=[], reais=[], metas=[], meta_dia=None, tot_dias=0, serie=[], roas=None),
  'funis': ws([]), 'canais': ws([]), 'campanha_canais': ws([]), 'campanha_ofertas': ws([]), 'projetos': ws([]), 'pessoas': ws([]), 'campanha_conexoes': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def foto(pg, n):
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, n + '.png'), full_page=True)
def kpis(pg): return ev(pg, "[...document.querySelectorAll('#main .kpi .l')].map(x => x.textContent)")
def abre(pg, id, tab='resumo'): pg.evaluate("([i, t]) => { S.view = 'mkt-camp'; S.campSel = i; S.campTab = t; render(); }", [id, tab]); pg.wait_for_timeout(1400)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1500)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1';")
    # ---- contas puras ----
    F = lambda c, v: ev(pg, "([c, v]) => campFase(c, v, '2026-06-10').k", [c, v])
    chk(F({'modelo': 'lancamento'}, 0) == 'captacao', 'lançamento sem venda está em captação')
    chk(F({'modelo': 'lancamento', 'fases': {'aquecimento': {'ini': '2026-06-01'}}}, 0) == 'aquecimento', 'depois do início do aquecimento, aquecimento')
    chk(F({'modelo': 'lancamento', 'data_carrinho_abre': '2026-06-05'}, 0) == 'vendas', 'carrinho aberto já é venda')
    chk(F({'modelo': 'lancamento', 'data_carrinho_abre': '2026-07-05'}, 3) == 'vendas', 'venda real antes do carrinho conta como venda')
    chk(F({'modelo': 'perpetuo'}, 0) == 'vendas', 'perpétuo sem carrinho está sempre em vendas')
    chk(F({'modelo': 'perpetuo', 'data_carrinho_abre': '2026-07-05'}, 0) == 'captacao', 'perpétuo com carrinho futuro está em captação')
    chk(F({'modelo': 'lancamento', 'status': 'finalizada'}, 0) == 'fim', 'finalizada')
    L = lambda r, m, o={}: ev(pg, "([r, m, o]) => (metaLuz(r, m, o) || {}).k || null", [r, m, o])
    chk(L(90, 100) == 'ruim' and L(96, 100) == 'ok' and L(104, 100) == 'ok' and L(106, 100) == 'acima', 'luzinha: ruim, no planejado e acima')
    chk(L(50, 100, {'frac': .5}) == 'ok' and L(30, 100, {'frac': .5}) == 'ruim' and L(80, 100, {'frac': .5}) == 'acima', 'volume compara com o ritmo do período')
    chk(L(120, 100, {'menor': True}) == 'ruim' and L(80, 100, {'menor': True}) == 'acima', 'em custo, menos é melhor')
    chk(L(80, 100, {'menor': True, 'teto': True}) == 'ok' and L(120, 100, {'menor': True, 'teto': True}) == 'ruim', 'investimento: abaixo não é mérito, acima é ruim')
    chk(L(0, 100, {'frac': 0}) is None and L(None, 100) is None and L(5, 0) is None, 'sem meta, sem dado ou antes de começar: sem luz')
    R = lambda a, b_, h: ev(pg, "([a, b, h]) => campRitmo(a, b, h)", [a, b_, h])
    chk(R('2026-01-01', '2026-01-10', '2025-12-31') == 0 and R('2026-01-01', '2026-01-10', '2026-01-05') == .5 and R('2026-01-01', '2026-01-10', '2026-02-01') == 1, 'ritmo do período')
    # ---- campanha em captação ----
    abre(pg, 'cap')
    k = kpis(pg); chk(k == ['Leads', 'Investido', 'CPL'], 'em captação: leads, investido e CPL', k)
    chk('Fase: Captação' in ev(pg, "document.querySelector('#campFaseL').textContent"), 'mostra a fase')
    chk('CAC' not in ev(pg, "[...document.querySelectorAll('[data-lm]')].map(x => x.dataset.lm).join()") and 'Leads' in ev(pg, "[...document.querySelectorAll('[data-lm]')].map(x => x.dataset.lm).join()"), 'a tabela de metas tira o que depende de venda')
    chk('ainda não começou' in ev(pg, "document.querySelector('[data-lm=Vendas]').textContent"), 'venda com meta antes do carrinho fica sem luz')
    foto(pg, 'captacao')
    # o resto da aba Dashboard usa funções do banco que o teste não simula: confere só os cards
    k = ev(pg, "(async () => { const d = document.createElement('div'); document.body.appendChild(d); try { await vMktDashCampanha(d, 'cap'); } catch (e) {} const r = [...d.querySelectorAll('.kpi .l')].map(x => x.textContent), f = d.querySelector('#campFaseL').textContent; d.remove(); return [r, f]; })()")
    chk('ROAS' not in k[0] and 'CAC' not in k[0] and 'Receita bruta' not in k[0] and 'Custo por lead' in k[0] and 'Captação' in k[1], 'o dashboard da campanha também', k)
    k = ev(pg, "(async () => { const d = document.createElement('div'); document.body.appendChild(d); try { await vMktDashCampanha(d, 'ven'); } catch (e) {} const r = [...d.querySelectorAll('.kpi .l')].map(x => x.textContent), l = d.querySelectorAll('.kpi .luz').length; d.remove(); return [r, l]; })()")
    chk('ROAS' in k[0] and 'CAC' in k[0] and k[1] >= 3, 'em vendas, o dashboard mostra ROAS, CAC e as luzinhas', k)
    abre(pg, 'aqu'); chk('Fase: Aquecimento' in ev(pg, "document.querySelector('#campFaseL').textContent"), 'mostra aquecimento')
    # ---- campanha em vendas, finalizada no período ----
    abre(pg, 'ven')
    k = kpis(pg); chk('ROAS' in k and 'CAC' in k and 'Vendas' in k, 'em vendas: aparece ROAS e CAC', k)
    lz = lambda n: ev(pg, f"(document.querySelector('[data-lm=\"{n}\"] .luz') || {{}}).className || ''")
    chk('luz-acima' in lz('Leads') and 'luz-ok' in lz('Vendas'), 'leads acima (120 de 100) e vendas no planejado', [lz('Leads'), lz('Vendas')])
    chk('luz-acima' in lz('Receita bruta'), 'receita acima do planejado', lz('Receita bruta'))
    chk('luz-ok' in lz('Investimento'), 'investimento dentro do orçamento fica verde')
    chk('luz-ruim' in lz('CPL (custo por lead)') or 'luz-acima' in lz('CPL (custo por lead)') or 'luz-ok' in lz('CPL (custo por lead)'), 'CPL tem luz')
    chk(ev(pg, "getComputedStyle(document.querySelector('.luz-acima i')).backgroundColor") != ev(pg, "getComputedStyle(document.querySelector('.luz-ok i')).backgroundColor"), 'acima do planejado tem outra cor')
    foto(pg, 'vendas')
    abre(pg, 'per'); chk('Fase: Em vendas' in ev(pg, "document.querySelector('#campFaseL').textContent"), 'perpétuo em vendas')
    # ---- dashboard de marketing ----
    pg.evaluate("S.view = 'mkt-dash'; S.campSel = null; S.mg = null; render();"); pg.wait_for_timeout(1500)
    k = kpis(pg); chk('ROI' not in k and 'LTV' not in k and 'Ticket médio' in k and 'ROAS' in k, 'sem ROI e sem LTV; com ticket médio', k)
    tx = ev(pg, "document.querySelector('#main .kpis').textContent")
    chk('867,61' in tx, 'ticket médio = receita ÷ vendas (329.690,85 ÷ 380)', tx[-260:])
    chk('22 saíram de 344 alunos · 322 ativos' in tx, 'churn mostra quantas pessoas', tx[-200:])
    foto(pg, 'dashboard')
    pg.evaluate("__D['rpc:funil_analise'] = { ...__D['rpc:funil_analise'], pos: { leads: 300, custo: 3000, clientes: 0, vendas: 0, receita: 0 } }; S.mg.camp = 'cap'; S.mg.tab = 'visao'; render();"); pg.wait_for_timeout(1500)
    k = kpis(pg); chk(k == ['Leads', 'Investido', 'CPL'], 'dashboard filtrado por campanha em captação', k)
    # ---- topo ----
    H = lambda h: ev(pg, "h => olaPeriodo(h)", h)
    chk(H(8) == 'Bom dia' and H(14) == 'Boa tarde' and H(20) == 'Boa noite' and H(2) == 'Boa noite', 'saudação pelo horário')
    pg.evaluate("S.user = { id: 'u1', email: 'rebecka@exemplo.com', user_metadata: {} }; topoAtualiza();")
    ola = ev(pg, "document.querySelector('#olaTxt').textContent"); chk(', Rebecka.' in ola and len(ola) > 30, 'chama pelo nome, com uma frase', ola)
    box = ev(pg, "(() => { const r = document.querySelector('#fotoBtn').getBoundingClientRect(); return [r.right, r.top, innerWidth]; })()")
    chk(box[0] > box[2] - 60 and box[1] < 40, 'foto no canto superior direito', box)
    chk(ev(pg, "document.querySelector('#fotoBtn').textContent") == 'R' and not ev(pg, "!!document.querySelector('#fotoBtn img')"), 'sem foto, mostra a inicial')
    chk(ev(pg, "document.querySelector('#fotoMenu').hidden"), 'o menu começa fechado')
    pg.click('#fotoBtn'); pg.wait_for_timeout(50)
    chk(not ev(pg, "document.querySelector('#fotoMenu').hidden") and ev(pg, "!!document.querySelector('#fotoMenu #sair')") and 'rebecka@exemplo.com' in ev(pg, "document.querySelector('#fotoMenu').textContent"), 'o menu tem a conta e o Sair')
    chk(not ev(pg, "!!document.querySelector('.side #sair')"), 'o Sair saiu da barra lateral')
    foto(pg, 'menu')
    pg.click('#main', position={'x': 400, 'y': 300}); pg.wait_for_timeout(50); chk(ev(pg, "document.querySelector('#fotoMenu').hidden"), 'clicar fora fecha')
    pg.evaluate("""window.__fotoUp = []; sb.storage = { from: b => ({ upload: async (c, f, o) => { __fotoUp.push([b, c, o.upsert, f.type]); return { data: {}, error: null }; }, getPublicUrl: c => ({ data: { publicUrl: 'data:image/gif;base64,R0lGODlhAQABAAAAACw=' } }), remove: async c => { __fotoUp.push(['rm', c[0]]); return {}; } }) };
      sb.auth.updateUser = async o => { S.user.user_metadata = { ...S.user.user_metadata, ...o.data }; return { data: { user: S.user }, error: null }; }; null""")
    import struct, zlib
    def bloco(tp, d): return struct.pack('>I', len(d)) + tp + d + struct.pack('>I', zlib.crc32(tp + d) & 0xffffffff)
    PNG = b'\x89PNG\r\n\x1a\n' + bloco(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 2, 0, 0, 0)) + bloco(b'IDAT', zlib.compress(b'\x00\xff\x00\x00\x00\xff\x00' * 2)) + bloco(b'IEND', b'')
    pg.set_input_files('#fotoArq', files=[{'name': 'eu.png', 'mimeType': 'image/png', 'buffer': PNG}]); pg.wait_for_timeout(600)
    chk(ev(pg, "__fotoUp[0]") == ['avatares', 'u1/foto.jpg', True, 'image/jpeg'], 'a foto vai reduzida para a pasta da pessoa', ev(pg, "__fotoUp"))
    chk(ev(pg, "!!document.querySelector('#fotoBtn img')") and ev(pg, "!!S.user.user_metadata.foto_url"), 'a foto aparece')
    pg.set_input_files('#fotoArq', files=[{'name': 'x.pdf', 'mimeType': 'application/pdf', 'buffer': b'x'}]); pg.wait_for_timeout(300); chk(len(ev(pg, "__fotoUp")) == 1, 'recusa o que não é foto')
    pg.set_input_files('#fotoArq', files=[{'name': 'q.png', 'mimeType': 'image/png', 'buffer': b'nao e imagem'}]); pg.wait_for_timeout(300); chk(len(ev(pg, "__fotoUp")) == 1, 'imagem ilegível não sobe')
    pg.click('#fotoBtn'); pg.wait_for_timeout(50); pg.click('#fotoTira'); pg.wait_for_timeout(300)
    chk(not ev(pg, "!!document.querySelector('#fotoBtn img')") and ev(pg, "__fotoUp[1]") == ['rm', 'u1/foto.jpg'], 'tirar a foto volta para a inicial')
    pg.set_viewport_size({'width': 400, 'height': 800}); pg.wait_for_timeout(100); chk(not ev(pg, "document.documentElement.scrollWidth > innerWidth + 1"), 'no celular, o topo não estoura a página')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
