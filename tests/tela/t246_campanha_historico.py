import json, os, tempfile
# Teste de tela da v0.246: histórico e referências em Campanha → Planejamento e metas.
# Até 3 campanhas finalizadas do mesmo produto e modelo, médias ponderadas, aviso de poucos dados, abrir a campanha histórica,
# usar as médias como metas (com confirmação) e a memória das referências em campanhas.extras.
# Rodar: python3 tests/tela/t246_campanha_historico.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't246_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def camp(id, nome, fim, st='finalizada', prod='p1', mod='lancamento', **k): return dict(id=id, nome=nome, status=st, produto_id=prod, modelo=mod, data_inicio=fim[:8] + '01', data_fim=fim, extras={}, criado_em='2026-01-01', **k)
def vis(id, inv, ld, vd, cl, rec): return dict(campanha_id=id, investimento=inv, leads=ld, vendas=vd, clientes=cl, receita=rec, receita_antes_churn=rec, qualificados=0, cac=None, cpl=None, roas=None, taxa_lead_venda=None)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Curso', preco=997, ativo=True), dict(id='p2', nome='Mentoria', preco=5000, ativo=True)]),
  'campanhas': ws([camp('atual', 'Lançamento Novembro', '2026-11-30', st='planejada', meta_cpl=20, meta_cac=None, meta_taxa_lead_venda=None, meta_vendas=77),
    camp('a', 'Lançamento Set', '2026-09-30'), camp('b', 'Lançamento Jun', '2026-06-30'), camp('c', 'Lançamento Mar orgânico', '2026-03-31'),
    camp('velha', 'Lançamento 2025 (quarta)', '2025-11-30'), camp('vazia', 'Sem dados', '2026-10-31'), camp('ativa', 'Ainda ativa', '2026-10-15', st='ativa'),
    camp('perp', 'Perpétuo do curso', '2026-08-31', mod='perpetuo'), camp('outro', 'Lançamento da mentoria', '2026-08-31', prod='p2')]),
  'v_marketing_campanha': [vis('atual', 0, 0, 0, 0, 0), vis('a', 1000, 100, 5, 5, 5000), vis('b', 3000, 200, 12, 10, 9000), vis('c', 0, 50, 1, 1, 500), vis('velha', 9000, 100, 1, 1, 100),
    vis('vazia', 0, 0, 0, 0, 0), vis('ativa', 5000, 10, 1, 1, 100), vis('perp', 7000, 10, 1, 1, 100), vis('outro', 8000, 10, 1, 1, 100)],
  'funis': ws([]), 'projetos': ws([]), 'campanha_canais': ws([]), 'canais': ws([]), 'pessoas': ws([]), 'campanha_mix': ws([]), 'campanha_metas_mes': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def abre(pg, id):
    pg.evaluate("(id) => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-camp'; S.campSel = id; S.campTab = 'resumo'; render(); }", id); pg.wait_for_timeout(1500)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    abre(pg, 'atual')
    chk(ev(pg, "!!document.querySelector('#campHist #chDet')"), 'o painel fica dentro de Planejamento e metas')
    chk(ev(pg, "!document.querySelector('#chDet').open"), 'começa fechado (expansível)')
    sm = ev(pg, "document.querySelector('#chDet summary').textContent")
    chk('3 campanhas' in sm and 'CPL' in sm and 'ROAS' in sm, 'o resumo mostra as médias sem abrir', sm)
    pg.evaluate("document.querySelector('#chDet').open = true"); pg.wait_for_timeout(100)
    nomes = ev(pg, "[...document.querySelectorAll('[data-chc]')].map(a => a.textContent)")
    chk(nomes == ['Lançamento Set', 'Lançamento Jun', 'Lançamento Mar orgânico'], 'só as 3 mais recentes, finalizadas, do mesmo produto e modelo, com dados', nomes)
    md = ev(pg, "campHistMedias([{investimento:1000,leads:100,vendas:5,clientes:5,receita:5000},{investimento:3000,leads:200,vendas:12,clientes:10,receita:9000},{investimento:0,leads:50,vendas:1,clientes:1,receita:500}])")
    chk(abs(md['cpl']['v'] - 4000 / 300) < 1e-9, 'CPL ponderado: 4000 ÷ 300, sem a campanha sem investimento', md['cpl'])
    chk(abs(md['cac']['v'] - 4000 / 17) < 1e-9, 'CAC ponderado: 4000 ÷ 17 vendas', md['cac'])
    chk(abs(md['conv']['v'] - 18 * 100 / 350) < 1e-9 and md['conv']['n'] == 3, 'conversão ponderada: 18 ÷ 350, com as 3 campanhas', md['conv'])
    chk(abs(md['roas']['v'] - 14000 / 4000) < 1e-9, 'ROAS ponderado: 14000 ÷ 4000 (a receita orgânica fica fora)', md['roas'])
    media = ev(pg, "document.querySelector('#chMedia').textContent")
    chk('13,33' in media and '235,29' in media and '5,14%' in media and '3,50' in media, 'a linha de média mostra os valores', media)
    chk(ev(pg, "!!document.querySelector('#chPoucos')"), 'avisa quando menos de 3 têm dados suficientes')
    chk(ev(pg, "!!document.querySelector('#chCoer')"), 'avisa quando a conversão usa campanhas que o CAC não usa (a orgânica entra só na conversão)')
    chk(ev(pg, "campHistCoerencia({cpl:{v:10},cac:{v:500},conv:{v:5}})") == 200, 'detecta metas que não conversam (R$ 10 e 5% dão CAC de R$ 200)')
    chk(ev(pg, "campHistCoerencia(campHistMedias([]))") is None, 'sem dados, não calcula nada')
    # usar como metas: pede confirmação
    pg.click('#chUsar'); pg.wait_for_timeout(400)
    mt = ev(pg, "document.querySelector('#modalRoot').textContent")
    chk('Meta atual' in mt and '20,00' in mt and '13,33' in mt, 'a confirmação mostra a meta atual e a nova', mt[:300])
    chk(ev(pg, "__D.campanhas.find(x => x.id === 'atual').meta_cpl") == 20, 'nada muda antes de confirmar')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    cc = ev(pg, "__D.campanhas.find(x => x.id === 'atual')")
    chk(cc['meta_cpl'] == 13.33 and cc['meta_cac'] == 235.29 and cc['meta_taxa_lead_venda'] == 5.14, 'aplica CPL, CAC e conversão', [cc['meta_cpl'], cc['meta_cac'], cc['meta_taxa_lead_venda']])
    chk(cc['meta_vendas'] == 77, 'não mexe nas outras metas')
    rf = cc['extras'].get('referencia_planejamento') or {}
    chk(rf.get('valores') == {'cpl': 13.33, 'cac': 235.29, 'conv': 5.14} and rf.get('metas_antes', {}).get('cpl') == 20, 'guarda os valores usados e as metas de antes', rf)
    chk([x['id'] for x in rf.get('campanhas', [])] == ['a', 'b', 'c'] and rf['campanhas'][0]['investimento'] == 1000, 'guarda as campanhas usadas, com os números daquele momento', rf.get('campanhas'))
    chk(ev(pg, "!!document.querySelector('#chRef') && document.querySelector('#chDet').open"), 'mostra a referência usada e continua aberto')
    # segunda vez preserva o histórico
    abre(pg, 'atual'); pg.click('#chUsar'); pg.wait_for_timeout(400)
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    rf2 = ev(pg, "__D.campanhas.find(x => x.id === 'atual').extras.referencia_planejamento")
    chk(len(rf2.get('historico', [])) == 1 and 'historico' not in rf2['historico'][0], 'aplicar de novo guarda a anterior no histórico', rf2.get('historico'))
    # abrir campanha histórica
    abre(pg, 'atual'); pg.evaluate("document.querySelector('[data-chc=a]').click()"); pg.wait_for_timeout(1500)
    chk(ev(pg, "S.campSel") == 'a' and ev(pg, "S.campTab") == 'resumo' and 'Lançamento Set' in ev(pg, "document.querySelector('#main h1').textContent"), 'abre a campanha histórica para investigar')
    # sem comparáveis
    abre(pg, 'outro')
    chk('Sem campanha comparável' in ev(pg, "document.querySelector('#chDet summary').textContent") and not ev(pg, "!!document.querySelector('#chUsar')"), 'sem comparáveis: avisa e não oferece aplicar')
    pg.evaluate("__D.campanhas.find(x => x.id === 'outro').produto_id = null"); abre(pg, 'outro')
    chk('não tem produto' in ev(pg, "document.querySelector('#campHist').textContent"), 'campanha sem produto: pede o produto')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
