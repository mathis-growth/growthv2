import json, os, tempfile
# Teste de tela da v0.253: assistente da campanha.
# Oferta: sempre do cadastro, com o preço da oferta; oferta nova entra no cadastro uma vez só.
# Cenários: principal aberta, as outras abrem ao clicar; aceite por cenário; meta de vendas de cada oferta e total.
# Canais: % dos leads e % das vendas sobre a meta total, inclusive quando a meta muda depois.
# Dash: total e uma linha por oferta com a luzinha; detalhe com a tabela por oferta.
# Rodar: python3 tests/tela/t253_oferta_cenario_canal.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't253_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Demo', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1497, ativo=True), dict(id='p3', nome='Planilha', preco=97, ativo=True), dict(id='p4', nome='Mentoria', preco=2000, ativo=True)]),
  'ofertas': ws([dict(id='o1', nome='Método à vista', produto_id='p1', papel='principal', preco=1297, ativo=True, status='ativa', versao=3), dict(id='o2', nome='Planilha no checkout', produto_id='p3', papel='order_bump', preco=67, ativo=True, status='ativa', versao=1), dict(id='o3', nome='Oferta antiga', produto_id='p3', papel='upsell', preco=10, ativo=False, status='pausada', versao=1)]),
  'campanhas': ws([]), 'v_marketing_campanha': [], 'funis': ws([]), 'canais': ws([dict(codigo='meta_ads', nome='Meta Ads', ativo=True), dict(codigo='email', nome='E-mail', ativo=True)]), 'campanha_canais': ws([]), 'campanha_ofertas': ws([]), 'projetos': ws([]), 'projeto_modelos': ws([]), 'pesquisas': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def avanca(pg): pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(800)
def foto(pg, n):
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, n + '.png'), full_page=True)
def nova(pg): return ev(pg, "__D.campanhas.find(x => x.nome === 'Método Jan/27')")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; window.__RPC = { ...(window.__RPC || {}), oferta_salvar: (a, D) => { const id = 'novo' + D.ofertas.length; D.ofertas.push({ id, workspace_id: a.p_ws, produto_id: a.p_itens[0].produto_id, nome: a.p_dados.nome, papel: a.p_dados.papel, preco: a.p_dados.preco, ativo: true, status: 'ativa', versao: 1 }); return id; } }; }""")
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(700)
    pg.fill('[name=nome]', 'Método Jan/27'); pg.select_option('[name=produto_id]', 'p1'); pg.fill('[name=data_inicio]', '2027-01-10'); pg.fill('[name=data_fim]', '2027-01-31'); avanca(pg); pg.wait_for_timeout(400)
    # ---------- oferta ----------
    chk(ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=oferta_id]').value") == 'o1', 'a única oferta principal do produto já vem escolhida')
    chk(ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=preco]').value") == '1297', 'traz o preço do cadastro')
    chk(ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=nome]').readOnly && document.querySelector('[data-oi=\"0\"][data-ok=produto_id]').disabled"), 'oferta do cadastro não edita nome nem produto')
    chk('Oferta antiga' not in ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=oferta_id]').textContent"), 'oferta pausada não aparece para escolher')
    pg.click('#ofMais'); pg.wait_for_timeout(100); pg.select_option('[data-oi="1"][data-ok=oferta_id]', 'o2'); pg.wait_for_timeout(150)
    chk(ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=nome]').value") == 'Planilha no checkout' and ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=papel]').value") == 'order_bump', 'escolher preenche nome e tipo')
    chk(ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=oferta_id] option[value=o2]').disabled"), 'oferta já usada não pode ser escolhida de novo')
    chk(ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=preco]').readOnly"), 'o preço da oferta do cadastro não muda na campanha')
    pg.click('#ofMais'); pg.wait_for_timeout(100); pg.select_option('[data-oi="2"][data-ok=papel]', 'upsell'); pg.select_option('[data-oi="2"][data-ok=produto_id]', 'p4'); pg.wait_for_timeout(150); pg.fill('[data-oi="2"][data-ok=nome]', 'Mentoria do upsell'); pg.fill('[data-oi="2"][data-ok=preco]', '500')
    foto(pg, 'oferta'); avanca(pg); pg.wait_for_timeout(400)
    of = ev(pg, "__D.campanha_ofertas"); cad = ev(pg, "__D.ofertas")
    ob = [x for x in of if x['papel'] == 'order_bump'][0]; up = [x for x in of if x['papel'] == 'upsell'][0]; pri = [x for x in of if x['papel'] == 'principal'][0]
    chk(pri['oferta_id'] == 'o1' and pri['oferta_versao'] == 3, 'a campanha guarda a oferta e a versão do cadastro', pri)
    chk(ob['oferta_id'] == 'o2' and float(ob['preco']) == 67, 'a campanha usa o preço da oferta', ob)
    novos = [x for x in cad if x['nome'] == 'Mentoria do upsell']
    chk(len(novos) == 1 and up['oferta_id'] == novos[0]['id'] and novos[0]['papel'] == 'upsell', 'oferta nova entra no cadastro e fica ligada', novos)
    # datas e histórico
    avanca(pg); pg.wait_for_timeout(300); avanca(pg); pg.wait_for_timeout(500)
    # ---------- cenários ----------
    V = lambda t, m: ev(pg, f"document.querySelector('[data-cen={t}][data-m={m}]').value")
    O = lambda oid, t, k: ev(pg, f"document.querySelector('[data-cof=\"{oid}\"][data-t={t}][data-k={k}]').value")
    C_ = lambda k: ev(pg, f"document.querySelector('[data-cenv=\"{k}\"]').textContent")
    grupos = ev(pg, "[...document.querySelectorAll('.cen-bl')].map(x => ({ t: x.querySelector('summary').textContent, a: x.open }))")
    chk(len(grupos) == 3 and grupos[0]['a'] and not grupos[1]['a'] and not grupos[2]['a'], 'só a oferta principal começa aberta', grupos)
    chk('Order bump: Planilha no checkout' in grupos[1]['t'] and 'sem aceite' in grupos[1]['t'], 'bloco fechado diz o que falta', grupos[1])
    chk(ev(pg, "!document.querySelector('[data-k=p]') && document.querySelector('[data-cen=base][data-m=t]').readOnly"), 'o preço não se edita nos cenários')
    foto(pg, 'cenarios_fechado')
    pg.evaluate("document.querySelectorAll('.cen-bl').forEach(x => x.open = true)")
    pg.fill('[data-cen=base][data-m=I]', '10000'); pg.fill('[data-cen=base][data-m=p]', '10'); pg.fill('[data-cen=base][data-m=c]', '10'); pg.wait_for_timeout(100)
    chk(int(V('base', 'L')) == 1000 and int(V('base', 'V')) == 100, 'base: 1.000 leads e 100 vendas', [V('base', 'L'), V('base', 'V')])
    chk(C_('base:o0') == '—', 'sem aceite, a oferta não soma', C_('base:o0'))
    pg.fill(f'[data-cof="{ob["id"]}"][data-t=base][data-k=a]', '30'); pg.wait_for_timeout(80)
    chk(float(O(ob['id'], 'pessimista', 'a')) == 24 and float(O(ob['id'], 'otimista', 'a')) == 36, 'pessimista e otimista acompanham o aceite do Base', [O(ob['id'], 'pessimista', 'a'), O(ob['id'], 'otimista', 'a')])
    chk('sem aceite' not in ev(pg, "document.querySelector('[data-censum=\"0\"]').textContent"), 'o aviso de aceite some')
    chk(C_('base:ov0') == '30' and '2.010' in C_('base:o0'), 'order bump: 100 × 30% × R$ 67', [C_('base:ov0'), C_('base:o0')])
    chk('30 vendas' in ev(pg, "document.querySelector('[data-censum=\"0\"]').textContent"), 'o título do bloco resume o Base')
    pg.fill(f'[data-cof="{up["id"]}"][data-t=base][data-k=a]', '10'); pg.wait_for_timeout(80)
    chk(C_('base:vt') == '140', 'vendas previstas somam todas as ofertas', C_('base:vt'))
    chk('71,43' in C_('base:cact'), 'CAC com todas as vendas: 10.000 ÷ 140', C_('base:cact'))
    rt = 100 * 1297 + 30 * 67 + 10 * 500
    chk(f'{rt:,.2f}'.replace(',', '#').replace('.', ',').replace('#', '.') in C_('base:rt'), 'receita total soma as três ofertas', C_('base:rt'))
    pg.fill(f'[data-cof="{ob["id"]}"][data-t=otimista][data-k=a]', '50'); pg.wait_for_timeout(60); pg.fill(f'[data-cof="{ob["id"]}"][data-t=base][data-k=a]', '20'); pg.wait_for_timeout(60)
    chk(float(O(ob['id'], 'otimista', 'a')) == 50 and float(O(ob['id'], 'pessimista', 'a')) == 16, 'aceite digitado no Otimista fica; o Pessimista acompanha o Base', [O(ob['id'], 'otimista', 'a'), O(ob['id'], 'pessimista', 'a')])
    pg.fill(f'[data-cof="{ob["id"]}"][data-t=base][data-k=a]', '30'); pg.wait_for_timeout(60)
    pg.fill(f'[data-cof="{up["id"]}"][data-t=otimista][data-k=a]', '25'); pg.wait_for_timeout(60)
    foto(pg, 'cenarios'); avanca(pg); pg.wait_for_timeout(500)
    c = nova(pg); of = ev(pg, "__D.campanha_ofertas"); ob2 = [x for x in of if x['id'] == ob['id']][0]
    chk(abs(ob2['taxa_aceite'] - .3) < 1e-9, 'o aceite do Base vira a premissa da oferta', ob2)
    chk(abs(float(c['meta_receita']) - rt) < .01, 'a meta de receita usa o Base com as ofertas', c['meta_receita'])
    sv = c['extras']['cenarios']['ofertas'][up['id']]
    chk(sv['otimista']['a'] == 25 and sv['mexido'] == {'otimista': True}, 'guarda o que foi digitado por oferta', sv)
    of = ev(pg, "__D.campanha_ofertas"); M_ = {x['papel']: x.get('meta_vendas') for x in of}
    chk(M_ == {'principal': 100, 'order_bump': 30, 'upsell': 10}, 'cada oferta tem sua meta de vendas', M_)
    chk(int(c['meta_vendas']) == 140, 'a meta da campanha é a soma das ofertas', c['meta_vendas'])
    chk(abs(float(c['meta_cac']) - 71.43) < .01, 'a meta de CAC usa todas as vendas', c['meta_cac'])
    # ---------- canais ----------
    pg.click('[data-cn=meta_ads]'); pg.wait_for_timeout(80); pg.click('[data-cn=email]'); pg.wait_for_timeout(80)
    cab = ev(pg, "[...document.querySelectorAll('#wzTab th')].map(x => x.textContent)")
    chk(cab == ['Canal', '% do orçamento', 'Orçamento', '% dos leads', 'Leads', '% das vendas', 'Vendas'], 'colunas de porcentagem', cab)
    def poe(attr, k, v): pg.fill(f'#wzTab [{attr}={k}]', str(v)); pg.dispatch_event(f'#wzTab [{attr}={k}]', 'change'); pg.wait_for_timeout(80)
    poe('data-pl', 'meta_ads', 80); poe('data-pl', 'email', 15); poe('data-pv', 'meta_ads', 60); poe('data-pv', 'email', 40)
    txt = ev(pg, "document.querySelector('#wzTab').textContent")
    chk('Faltam 5% dos leads' in txt, 'avisa quanto falta dos leads', txt[:500])
    poe('data-pl', 'email', 20); txt = ev(pg, "document.querySelector('#wzTab').textContent")
    chk('dos leads para fechar' not in txt and '1.000 de 1.000' in txt and '140 de 140' in txt, 'fecha 100% de leads e vendas', txt[:500])
    foto(pg, 'canais'); avanca(pg); pg.wait_for_timeout(500)
    chk(ev(pg, "!!document.querySelector('#comUrl')"), 'depois de Canais vem Comercial')
    cc = {x['canal']: x for x in ev(pg, "__D.campanha_canais")}
    chk(cc['email']['meta_leads'] == 200 and cc['email']['percentual_meta_leads'] == 20, 'e-mail: 20% de 1.000 leads', cc['email'])
    chk(cc['meta_ads']['meta_vendas'] == 84 and cc['meta_ads']['percentual_meta_vendas'] == 60, 'Meta Ads: 60% de 140 vendas', cc['meta_ads'])
    # meta muda depois: canais acompanham
    pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(300); pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(500)
    chk(ev(pg, "!!document.querySelector('.cen-t')"), 'volta para os cenários')
    chk(O(up['id'], 'otimista', 'a') == '25' and O(ob['id'], 'otimista', 'a') == '50', 'ao voltar, o que foi digitado continua', [O(up['id'], 'otimista', 'a'), O(ob['id'], 'otimista', 'a')])
    chk(int(V('base', 'V')) == 100, 'ao voltar, o Base continua partindo da oferta principal, sem somar as outras', V('base', 'V'))
    pg.fill('[data-cen=base][data-m=I]', '20000'); pg.wait_for_timeout(80); avanca(pg); pg.wait_for_timeout(500)
    cc = {x['canal']: x for x in ev(pg, "__D.campanha_canais")}
    chk(cc['email']['meta_leads'] == 400 and cc['meta_ads']['meta_vendas'] == 168, 'a meta nova recalcula os canais', [cc['email']['meta_leads'], cc['meta_ads']['meta_vendas']])
    chk('2.000 de 2.000' in ev(pg, "document.querySelector('#wzTab').textContent"), 'a tela de canais mostra a meta nova')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # dash: total e linhas por oferta
    pg.evaluate("""() => { const id = __D.campanhas.find(x => x.nome === 'Método Jan/27').id; const nOf = {principal: 60, order_bump: 20, upsell: 1}; __D['rpc:campanha_ofertas_resultado'] = __D.campanha_ofertas.map(o => ({ id: o.id, nome: o.nome, papel: o.papel, ordem: o.ordem, vendas: nOf[o.papel], receita: nOf[o.papel] * o.preco, aceite: o.papel === 'principal' ? null : 25.5 })); }""")
    html = ev(pg, "ofLinhas(__D['rpc:campanha_ofertas_resultado'].map(o => ({ ...o, meta_vendas: ({principal: 100, order_bump: 30, upsell: 10})[o.papel] })), 85, { frac: .7 })")
    chk('Principal' in html and '60 de 100' in html and 'luz-ruim' in html, 'linha da principal com a meta e a luzinha', html[:400])
    chk('20 de 30' in html and 'luz-ok' in html, 'order bump dentro do ritmo fica verde', html[:600])
    chk('Outras vendas' in html and '>4<' in html, 'venda fora das ofertas aparece separada', html[-300:])
    chk(ev(pg, "ofLinhas([{ papel: 'principal', vendas: 3 }], 3, {})") == '', 'campanha só com a principal não repete a linha')
    r_ = ev(pg, "(async () => { const id = __D.campanhas.find(x => x.nome === 'Método Jan/27').id; __D['rpc:campanha_detalhe'] = { canais: [], dias: ['2027-01-10', '2027-01-11'], de: '2027-01-10', ate: '2027-01-31', ultimas_vendas: [], ultimos_leads: [], produtos: [] }; await cdAbrir(id, 'vendas'); await new Promise(r => setTimeout(r, 300)); const s = document.querySelector('#cdOfertas'); return s ? s.textContent : ''; })()")
    chk('Por oferta' in r_ and 'Mentoria do upsell' in r_ and 'Total' in r_, 'clicar em Vendas abre o detalhe por oferta', r_[:400])
    foto(pg, 'detalhe_vendas')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''; document.querySelectorAll('.cd-ov, .ov').forEach(x => x.remove())")
    # card de Vendas no resumo e no dashboard da campanha
    pg.evaluate("""() => { const c = __D.campanhas.find(x => x.nome === 'Método Jan/27'); Object.assign(c, { status: 'ativa', data_inicio: '2026-10-01', data_fim: '2026-11-30', data_carrinho_abre: '2026-10-20', data_carrinho_fecha: '2026-11-20', fases: {} }); __D.v_marketing_campanha.push({ campanha_id: c.id, workspace_id: 'w1', nome: c.nome, status: 'ativa', meta_vendas: c.meta_vendas, meta_leads: c.meta_leads, meta_receita: c.meta_receita, meta_cac: c.meta_cac, orcamento_total: c.orcamento_total, investimento: 12000, leads: 1500, qualificados: 300, vendas: 85, clientes: 61, faturamento: 90000, receita: 78000, faturamento_saiu: 0, pessoas_saiu: 0, cac: 141.18, cpl: 8, roas: 7.5 }); window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-camp'; S.campSel = c.id; S.campTab = 'resumo'; render(); }"""); pg.wait_for_timeout(1500)
    card = ev(pg, "[...document.querySelectorAll('#main .kpi')].filter(k => /^Vendas/.test(k.querySelector('.l').textContent)).map(k => k.textContent).join('|')")
    chk('Principal' in card and '60 de 200' in card and 'Order bump' in card and 'meta total' in card, 'o card de Vendas mostra o total e cada oferta', card)
    foto(pg, 'card_vendas')
    # reabrir: oferta digitada antes (sem cadastro) entra no cadastro ao salvar
    pg.evaluate("""() => { const c = __D.campanhas.find(x => x.nome === 'Método Jan/27'); __D.campanha_ofertas.push({ id: 'velha', workspace_id: 'w1', campanha_id: c.id, produto_id: 'p3', oferta_id: null, nome: 'Digitada antes', papel: 'cross_sell', preco: 5, ordem: 9 }); }""")
    n0 = ev(pg, "__D.ofertas.length")
    pg.evaluate("abrirWizard(__D.campanhas.find(x => x.nome === 'Método Jan/27').id, 2)"); pg.wait_for_timeout(700)
    avanca(pg); pg.wait_for_timeout(400)
    velha = ev(pg, "__D.campanha_ofertas.find(x => x.id === 'velha')")
    chk(ev(pg, "__D.ofertas.length") == n0 + 1 and velha['oferta_id'], 'oferta antiga digitada entra no cadastro, e as ligadas não duplicam', velha)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # aba Ofertas da campanha: só com oferta do catálogo, sem editar preço
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''; S.campTab = 'ofertas'; render();"); pg.wait_for_timeout(1500)
    pg.evaluate("__D.ofertas.push({ id: 'o9', workspace_id: 'w1', nome: 'Upsell novo', produto_id: 'p3', papel: 'upsell', preco: 300, ativo: true, status: 'ativa', versao: 2 }); render();"); pg.wait_for_timeout(1500)
    pg.click('#ofAdd'); pg.wait_for_timeout(300)
    chk(ev(pg, "document.querySelector('#ofPreco').readOnly && document.querySelector('#ofNome').readOnly && document.querySelector('#ofProd').disabled && document.querySelector('#ofSel').required"), 'na aba Ofertas, nome, produto e preço vêm da oferta')
    chk('criar só para esta campanha' not in ev(pg, "document.querySelector('#ofSel').textContent"), 'não dá mais para criar oferta só na campanha')
    n1 = ev(pg, "__D.campanha_ofertas.length")
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(300)
    chk(ev(pg, "__D.campanha_ofertas.length") == n1, 'sem escolher a oferta não salva')
    pg.select_option('#ofSel', 'o9'); pg.wait_for_timeout(100)
    chk(ev(pg, "document.querySelector('#ofPreco').value") == '300', 'escolher traz o preço da oferta')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(700)
    nv = ev(pg, "__D.campanha_ofertas.find(x => x.oferta_id === 'o9')")
    chk(nv and float(nv['preco']) == 300 and nv['nome'] == 'Upsell novo' and nv['produto_id'] == 'p3' and nv.get('oferta_versao') == 2, 'a aba grava a oferta ligada ao catálogo', nv)
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
