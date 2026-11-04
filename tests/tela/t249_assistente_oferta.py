import json, os, tempfile
# Teste de tela da v0.249: assistente da campanha com 7 passos.
# 1 O básico, 2 Oferta, 3 Datas das etapas (qualquer campanha), 4 Histórico e referências (últimas ou por período, gráficos de linha,
# order bump, upsell e downsell num bloco que abre), 5 Orçamento e cenários (com as ofertas), 6 Canais, 7 Pesquisa.
# Rodar: python3 tests/tela/t249_assistente_oferta.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't249_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def camp(id, nome, fim, st='finalizada', prod='p1', mod='lancamento', **k): return dict(id=id, nome=nome, status=st, produto_id=prod, modelo=mod, data_inicio=(fim or '2026-05-31')[:8] + '01', data_fim=fim, extras={}, fases={}, criado_em='2026-01-01', **k)
def vis(id, inv, ld, q, vd, cl, rec): return dict(campanha_id=id, investimento=inv, leads=ld, qualificados=q, vendas=vd, clientes=cl, faturamento=rec, receita=rec, receita_bruta=rec)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Demo', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1497, ativo=True), dict(id='p2', nome='Mini', preco=197, ativo=True), dict(id='p3', nome='Planilha', preco=97, ativo=True), dict(id='p4', nome='Mentoria', preco=997, ativo=True)]),
  'campanhas': ws([camp('set', 'Método Set/26', '2026-09-30'), camp('jun', 'Método Jun/26', '2026-06-30'), camp('mar', 'Método Mar/26', '2026-03-31'), camp('nov', 'Método Nov/25', '2025-11-30'), camp('mini', 'Mini Set/26', '2026-09-30', prod='p2')]),
  'v_marketing_campanha': [vis('set', 6000, 200, 40, 10, 8, 14970), vis('jun', 4500, 180, 30, 7, 7, 10479), vis('mar', 3000, 150, 20, 5, 5, 7485), vis('nov', 1500, 50, 5, 1, 1, 1497), vis('mini', 800, 100, 0, 6, 6, 1182)],
  'funis': ws([]), 'canais': ws([dict(codigo='meta_ads', nome='Meta Ads', ativo=True)]), 'campanha_canais': ws([]), 'campanha_ofertas': ws([]), 'projetos': ws([]), 'projeto_modelos': ws([]), 'pesquisas': ws([]), 'etapas_kanban': ws([]), 'pessoas': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def avanca(pg): pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(900)
def nova(pg): return ev(pg, "__D.campanhas.find(x => x.nome === 'Método Jan/27')")
def foto(pg, n):
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, n + '.png'), full_page=True)
RPC = """window.__RPC = { campanha_ofertas_resultado: a => ({
  set: [{ id: 's0', papel: 'principal', nome: 'Método', preco: 1497, vendas: 10, receita: 14970 }, { id: 's1', papel: 'order_bump', nome: 'Planilha', preco: 97, vendas: 2, receita: 194, aceite: 20, base_aceite: 10 }],
  jun: [{ id: 'j1', papel: 'order_bump', nome: 'Planilha', preco: 97, vendas: 1, receita: 97, aceite: 14.3, base_aceite: 7 }, { id: 'j2', papel: 'upsell', nome: 'Mentoria', preco: 997, vendas: 1, receita: 997, aceite: 14.3, base_aceite: 7 }] }[a.p_campanha] || []),
  campanha_canais_resultado: () => [{ id: 'x', canal: 'meta_ads', investimento: 6000, leads: 200, cpl: 30 }] };"""
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate(RPC)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-camp'; render();"); pg.wait_for_timeout(1000)
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(900)
    pa = ev(pg, "[...document.querySelectorAll('.wzp div')].map(x => x.textContent.trim())")
    chk(pa == ['1. O básico', '2. Oferta', '3. Datas das etapas', '4. Histórico e referências', '5. Orçamento e cenários', '6. Canais', '7. Pesquisa'], 'os 7 passos, com a oferta logo depois do básico', pa)
    pg.fill('[name=nome]', 'Método Jan/27'); pg.select_option('[name=produto_id]', 'p1'); pg.fill('[name=data_inicio]', '2027-01-10'); pg.fill('[name=data_fim]', '2027-01-31'); avanca(pg); pg.wait_for_timeout(500)
    # ---- oferta ----
    chk(ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=nome]').value") == 'Método' and ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=preco]').value") == '1497' and ev(pg, "document.querySelector('[data-oi=\"0\"][data-ok=papel]').disabled"), 'a oferta principal já vem do produto')
    pg.click('#ofMais'); pg.wait_for_timeout(100)
    chk(ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=papel]').value") == 'order_bump', 'adicionar oferta começa pelo order bump')
    chk('em 2 de' in ev(pg, "document.querySelector('[data-ofl=\"1\"]').textContent") and '17,65%' in ev(pg, "document.querySelector('[data-ofl=\"1\"]').textContent"), 'mostra o que o histórico tem dessa oferta', ev(pg, "document.querySelector('[data-ofl=\"1\"]').textContent")[-120:])
    avanca(pg); chk(ev(pg, "!!document.querySelector('#ofMais')") and ev(pg, "__D.campanha_ofertas.length") == 0, 'oferta sem nome ou produto não salva')
    pg.select_option('[data-oi="1"][data-ok=produto_id]', 'p3'); pg.wait_for_timeout(150)
    chk(ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=nome]').value") == 'Planilha' and ev(pg, "document.querySelector('[data-oi=\"1\"][data-ok=preco]').value") == '97', 'escolher o produto sugere o nome e o preço')
    pg.click('#ofMais'); pg.wait_for_timeout(100); pg.select_option('[data-oi="2"][data-ok=produto_id]', 'p4'); pg.wait_for_timeout(150)
    pg.click('#ofMais'); pg.wait_for_timeout(100); pg.select_option('[data-oi="3"][data-ok=produto_id]', 'p2'); pg.wait_for_timeout(150)
    foto(pg, 'oferta'); avanca(pg); pg.wait_for_timeout(400)
    of = ev(pg, "__D.campanha_ofertas"); pr = [x for x in of if x['papel'] == 'principal'][0]
    chk(len(of) == 4 and pr['pai_id'] is None, 'grava a principal e as outras na esteira da campanha', of)
    chk([x for x in of if x['papel'] == 'order_bump'][0]['pai_id'] == pr['id'], 'order bump parte da oferta principal')
    dw = [x for x in of if x['papel'] == 'downsell'][0]; chk(dw['pai_id'] == [x for x in of if x['papel'] == 'upsell'][0]['id'] and dw['condicao'] == 'recusou', 'downsell parte da recusa do upsell', dw)
    # ---- datas ----
    chk(ev(pg, "document.querySelector('#wzUsaDatas').checked"), 'lançamento já abre com as datas ligadas')
    chk(ev(pg, "[...document.querySelectorAll('.wzb input[type=date]')].filter(i => i.offsetParent).map(i => i.name).join()") == 'fase_aquisicao_ini,fase_aquisicao_fim,fase_aquecimento_ini,fase_aquecimento_fim,data_carrinho_abre,data_carrinho_fecha', 'aquisição, aquecimento e carrinho à vista')
    pg.fill('[name=fase_aquisicao_ini]', '2027-01-10'); pg.fill('[name=fase_aquisicao_fim]', '2027-01-05'); avanca(pg)
    chk(ev(pg, "!!document.querySelector('#wzUsaDatas')") and not nova(pg).get('fases'), 'etapa com o fim antes do início não salva')
    pg.fill('[name=fase_aquisicao_fim]', '2027-01-20'); pg.fill('[name=data_carrinho_abre]', '2027-01-25'); pg.fill('[name=data_carrinho_fecha]', '2027-01-20'); avanca(pg)
    chk(ev(pg, "!!document.querySelector('#wzUsaDatas')") and not nova(pg).get('fases'), 'carrinho que fecha antes de abrir não salva')
    pg.fill('[name=data_carrinho_fecha]', '2027-01-28'); pg.check('[data-wzex=reabertura]', force=True); pg.wait_for_timeout(50); avanca(pg)
    chk(ev(pg, "!!document.querySelector('#wzUsaDatas')") and not nova(pg).get('fases'), 'reabertura marcada precisa de início')
    pg.fill('[name=fase_reabertura_ini]', '2027-01-30'); avanca(pg); pg.wait_for_timeout(600)
    c = nova(pg)
    chk(c['fases'] == {'aquisicao': {'ini': '2027-01-10', 'fim': '2027-01-20'}, 'reabertura': {'ini': '2027-01-30', 'fim': None}} and c['data_carrinho_abre'] == '2027-01-25', 'salva as datas; a reabertura pode ficar em aberto', c.get('fases'))
    # ---- histórico ----
    head = ev(pg, "[...document.querySelectorAll('.ch-t thead th')].map(t => t.textContent)")
    chk(head[:9] == ['Campanha', 'Investido', 'Leads', 'Clientes', 'Faturamento', 'CPL', 'CAC', 'Conversão', 'ROAS'], 'a lista tem as 8 métricas', head)
    nm = lambda: ev(pg, "[...document.querySelectorAll('[data-chdet]')].map(a => a.textContent)")
    chk(nm() == ['Método Set/26', 'Método Jun/26', 'Método Mar/26'], 'últimas 3, só do produto escolhido', nm())
    chk(ev(pg, "[...document.querySelectorAll('.ch-g')].map(g => g.dataset.chg).join()") == 'cpl,cac,conv' and ev(pg, "document.querySelectorAll('.ch-g[data-chg=cpl] circle.ch-pt').length") == 3 and ev(pg, "!!document.querySelector('.ch-g[data-chg=cpl] polyline')"), 'gráfico de linha de CPL, CAC e conversão, um ponto por campanha')
    ys = ev(pg, "[...document.querySelectorAll('.ch-g[data-chg=cpl] circle.ch-pt')].map(c => +c.getAttribute('cy'))")
    chk(ys[0] > ys[1] > ys[2], 'a linha vai da mais antiga (CPL menor, mais baixo) para a mais recente', ys)
    chk(ev(pg, "document.querySelector('.ch-g').textContent").find('25,47') > 0, 'o gráfico mostra a média')
    chk('Order bump' in ev(pg, "document.querySelector('[data-chr=set]').textContent") and 'Upsell' in ev(pg, "document.querySelector('[data-chr=jun]').textContent") and not ev(pg, "!!document.querySelector('[data-chr=mar] .ch-tag')"), 'etiqueta embaixo do nome de quem teve oferta')
    # bloco de ofertas fechado
    chk(ev(pg, "!!document.querySelector('#chOfAbre')") and ev(pg, "document.querySelectorAll('.ch-fx').length") == 0, 'order bump, upsell e downsell ficam num bloco fechado')
    pg.click('#chOfAbre'); pg.wait_for_timeout(150)
    fx = ev(pg, "document.querySelector('[data-chfx=order_bump]').textContent")
    chk('em 2 de 3' in fx and '17,65%' in fx, 'ao abrir, mostra o resumo por tipo, com o aceite ponderado', fx)
    pg.click('[data-chab=order_bump]'); pg.wait_for_timeout(150)
    chk(ev(pg, "document.querySelectorAll('[data-chfx=order_bump] tbody tr').length") == 2, 'ver detalhes lista as campanhas com a oferta')
    pg.check('[data-chac=order_bump]', force=True)
    # período
    pg.click('[data-chfl=periodo]'); pg.wait_for_timeout(200)
    pg.fill('#chIni', '2025-01-01'); pg.dispatch_event('#chIni', 'change'); pg.wait_for_timeout(100); pg.fill('#chFim', '2026-12-31'); pg.dispatch_event('#chFim', 'change'); pg.wait_for_timeout(200)
    chk(len(nm()) == 4 and 'Método Nov/25' in nm() and ev(pg, "document.querySelector('#chNper').textContent") == '4', 'por período traz todas do período', nm())
    chk('5.' not in '' and ev(pg, "document.querySelectorAll('.ch-g[data-chg=cpl] circle.ch-pt').length") == 4, 'o gráfico acompanha o período')
    pg.fill('#chIni', '2026-05-01'); pg.dispatch_event('#chIni', 'change'); pg.wait_for_timeout(200)
    chk(nm() == ['Método Set/26', 'Método Jun/26'] and ev(pg, "!!document.querySelector('#chPoucos')"), 'mudar as datas muda a lista e avisa com poucas', nm())
    pg.fill('#chIni', '2020-01-01'); pg.dispatch_event('#chIni', 'change'); pg.wait_for_timeout(100); pg.fill('#chFim', '2020-12-31'); pg.dispatch_event('#chFim', 'change'); pg.wait_for_timeout(200)
    chk(ev(pg, "!!document.querySelector('#chVazioP')"), 'período sem campanha avisa')
    pg.click('[data-chfl=ultimas]'); pg.wait_for_timeout(200)
    chk(nm() == ['Método Set/26', 'Método Jun/26', 'Método Mar/26'], 'volta para as últimas')
    # marcar
    pg.check('[name=ch_cpl][value=media]', force=True); pg.wait_for_timeout(50); pg.click('[name=ch_cpl][value=media]', force=True); pg.wait_for_timeout(50)
    chk(not ev(pg, "!!document.querySelector('[name=ch_cpl]:checked')"), 'clicar de novo desmarca')
    pg.check('[name=ch_cpl][value=media]', force=True); pg.check('[name=ch_cac][value=jun]', force=True); pg.check('[name=ch_conv][value=media]', force=True); pg.wait_for_timeout(100)
    pg.click('[data-chdet=jun]'); pg.wait_for_timeout(300)
    dt = ev(pg, "document.querySelector('#chDetalhe').textContent")
    chk('Vendas' in dt and 'Planilha' in dt and 'Mentoria' in dt and 'meta_ads' in dt, 'o detalhe da campanha mostra as ofertas e os canais', dt[:200])
    pg.click('#chFechaDet'); pg.wait_for_timeout(100)
    foto(pg, 'historico')
    avanca(pg); pg.wait_for_timeout(500); c = nova(pg)
    chk(c['meta_cpl'] == 25.47 and c['meta_cac'] == 642.86 and c['meta_taxa_lead_venda'] == 4.15, 'leva o que foi marcado para as metas', [c.get('meta_cpl'), c.get('meta_cac'), c.get('meta_taxa_lead_venda')])
    rf = c['extras']['referencia_planejamento']
    chk(rf.get('filtro') == 'ultimas' and len(rf.get('escolhas', [])) == 3 and [x['papel'] for x in rf.get('aceites', [])] == ['order_bump'] and rf['aceites'][0]['valor'] == 17.65, 'a memória guarda o filtro, as escolhas e o aceite', rf.get('aceites'))
    chk(abs([x for x in ev(pg, "__D.campanha_ofertas") if x['papel'] == 'order_bump'][0]['taxa_aceite'] - .1765) < 1e-9, 'o aceite levado vira a premissa da oferta')
    # ---- cenários ----
    V = lambda t, m: ev(pg, f"document.querySelector('[data-cen={t}][data-m={m}]').value")
    C_ = lambda k: ev(pg, f"document.querySelector('[data-cenv=\"{k}\"]').textContent")
    chk(float(V('base', 't')) == 1497, 'ticket vem da oferta principal')
    pg.fill('[data-cen=base][data-m=I]', '10000'); pg.wait_for_timeout(100)
    chk(int(V('base', 'L')) == 393 and int(V('base', 'V')) == 16, 'investimento calcula leads e vendas', [V('base', 'L'), V('base', 'V')])
    chk('23.952' in C_('base:rec'), 'receita da oferta principal', C_('base:rec'))
    ob = 16 * .1765 * 97
    chk(f'{ob:.2f}'.replace('.', ',') in C_('base:o0'), 'o order bump soma vendas × aceite × preço', C_('base:o0'))
    chk(C_('base:o1') == '—' and 'sem aceite' in ev(pg, "document.querySelector('[data-cenof=\"1\"]').textContent"), 'oferta sem aceite não entra na conta e avisa')
    tot = 23952 + ob; rt = C_('base:rt')
    chk(f'{tot:,.2f}'.replace(',', '#').replace('.', ',').replace('#', '.') in rt, 'a receita total soma a principal e o order bump', rt)
    chk(C_('base:roas') == f'{tot / 10000:.2f}'.replace('.', ','), 'o ROAS usa a receita total', C_('base:roas'))
    foto(pg, 'cenarios')
    pg.fill('[data-cen=base][data-m=V]', '20'); pg.wait_for_timeout(60); chk(float(V('base', 'a')) == 500, 'pôr as vendas recalcula o CAC', V('base', 'a'))
    pg.fill('[data-cen=otimista][data-m=p]', '10'); pg.wait_for_timeout(60); ot = V('otimista', 'L'); pg.fill('[data-cen=base][data-m=I]', '12000'); pg.wait_for_timeout(60)
    chk(V('otimista', 'L') == ot and float(V('pessimista', 'I')) == 12000, 'cenário mexido à mão deixa de acompanhar o Base')
    pg.click('#cenRefaz'); pg.wait_for_timeout(60); chk(float(V('otimista', 'I')) == 12000, 'refazer volta a acompanhar')
    avanca(pg); c = nova(pg)
    chk(float(c['orcamento_total']) == 12000 and c['meta_receita'] > int(c['meta_vendas']) * 1497, 'o Base vira meta, com a receita das ofertas', [c.get('orcamento_total'), c.get('meta_vendas'), c.get('meta_receita')])
    chk(set(c['extras'].get('cenarios', {}).keys()) >= {'base', 'pessimista', 'otimista'}, 'guarda os três cenários')
    chk(ev(pg, "!!document.querySelector('[data-cn=meta_ads]')"), 'depois vem Canais'); avanca(pg); pg.wait_for_timeout(600)
    chk('Concluir' in ev(pg, "document.querySelector('#modalRoot .pri').textContent"), 'por último, Pesquisa, que conclui')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # desmarcar datas limpa; oferta tirada sai
    pg.evaluate("abrirWizard(__D.campanhas.find(x => x.nome === 'Método Jan/27').id, 3)"); pg.wait_for_timeout(500)
    pg.uncheck('#wzUsaDatas', force=True); pg.wait_for_timeout(50); chk(ev(pg, "document.querySelector('#wzDatas').hidden"), 'desmarcar esconde as datas'); avanca(pg); pg.wait_for_timeout(500)
    c = nova(pg); chk(c['fases'] == {} and c['data_carrinho_abre'] is None, 'desmarcar limpa as datas do assistente', c.get('fases'))
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    pg.evaluate("abrirWizard(__D.campanhas.find(x => x.nome === 'Método Jan/27').id, 2)"); pg.wait_for_timeout(700)
    chk(ev(pg, "document.querySelectorAll('[data-ofl]').length") == 4, 'as ofertas voltam ao reabrir')
    pg.click('[data-orm="3"]'); pg.wait_for_timeout(100); avanca(pg); pg.wait_for_timeout(400)
    chk(ev(pg, "__D.campanha_ofertas.length") == 3, 'tirar a oferta apaga da campanha')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # perpétuo: as datas são escolha
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(600)
    pg.fill('[name=nome]', 'Perpétuo novo'); pg.select_option('[name=modelo]', 'perpetuo'); pg.select_option('[name=produto_id]', 'p2'); pg.fill('[name=data_inicio]', '2027-03-01'); avanca(pg); pg.wait_for_timeout(600)
    chk(ev(pg, "!!document.querySelector('[data-ok=nome]')"), 'perpétuo também passa pela oferta'); avanca(pg); pg.wait_for_timeout(400)
    chk(ev(pg, "!!document.querySelector('#wzUsaDatas')") and not ev(pg, "document.querySelector('#wzUsaDatas').checked") and ev(pg, "document.querySelector('#wzDatas').hidden"), 'no perpétuo, as datas existem, desligadas')
    pg.check('#wzUsaDatas', force=True); pg.wait_for_timeout(50); pg.fill('[name=fase_aquisicao_ini]', '2027-03-01'); pg.fill('[name=data_carrinho_abre]', '2027-03-05'); avanca(pg); pg.wait_for_timeout(500)
    pq = ev(pg, "__D.campanhas.find(x => x.nome === 'Perpétuo novo')")
    chk(pq['fases'].get('aquisicao', {}).get('ini') == '2027-03-01' and pq['data_carrinho_abre'] == '2027-03-05' and pq['data_fim'] is None, 'perpétuo pode usar as datas, sem data de fim', pq.get('fases'))
    pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(300); pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(300); pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(300)
    chk(ev(pg, "!!document.querySelector('[name=nome]')"), 'voltar percorre os passos até o básico')
    avanca(pg); pg.wait_for_timeout(500); chk(ev(pg, "__D.campanhas.find(x => x.nome === 'Perpétuo novo').data_carrinho_abre") == '2027-03-05', 'salvar o básico de novo não apaga o carrinho')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # sem histórico não trava
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(600)
    pg.fill('[name=nome]', 'Mentoria nova'); pg.select_option('[name=produto_id]', 'p4'); pg.fill('[name=data_inicio]', '2027-02-01'); pg.fill('[name=data_fim]', '2027-02-10'); avanca(pg); pg.wait_for_timeout(500); avanca(pg); pg.wait_for_timeout(300); avanca(pg); pg.wait_for_timeout(600)
    chk('Ainda não há campanha' in ev(pg, "document.querySelector('.wzb').textContent"), 'sem histórico: avisa')
    avanca(pg); chk(ev(pg, "!!document.querySelector('.cen-t')"), 'sem histórico: segue para os cenários')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
