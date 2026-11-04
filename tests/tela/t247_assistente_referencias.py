import json, os, tempfile
# Teste de tela da v0.247: assistente da campanha.
# Passo 1: datas de cada etapa do lançamento e do carrinho. Passo 2 (novo): Histórico e referências, com quantas campanhas trazer,
# gráficos, lista de métricas e a escolha de levar a média, uma campanha ou nada. Os passos seguintes continuam funcionando.
# Rodar: python3 tests/tela/t247_assistente_referencias.py   (FOTO=caminho.png salva a captura do passo 2)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't247_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def camp(id, nome, fim, st='finalizada', prod='p1', mod='lancamento', **k): return dict(id=id, nome=nome, status=st, produto_id=prod, modelo=mod, data_inicio=(fim or '2026-05-31')[:8] + '01', data_fim=fim, extras={}, fases={}, criado_em='2026-01-01', **k)
def vis(id, inv, ld, q, vd, cl, rec): return dict(campanha_id=id, investimento=inv, leads=ld, qualificados=q, vendas=vd, clientes=cl, receita_bruta=rec)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Demo', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1497, ativo=True), dict(id='p2', nome='Mini', preco=197, ativo=True)]),
  'campanhas': ws([camp('set', 'Método Set/26', '2026-09-30'), camp('jun', 'Método Jun/26', '2026-06-30'), camp('mar', 'Método Mar/26', '2026-03-31'), camp('nov', 'Método Nov/25', '2025-11-30'), camp('mini', 'Mini Set/26', '2026-09-30', prod='p2')]),
  'v_marketing_campanha': [vis('set', 6000, 200, 40, 10, 8, 14970), vis('jun', 4500, 180, 30, 7, 7, 10479), vis('mar', 3000, 150, 20, 5, 5, 7485), vis('nov', 1500, 50, 5, 1, 1, 1497), vis('mini', 800, 100, 0, 6, 6, 1182)],
  'funis': ws([]), 'canais': ws([dict(codigo='meta_ads', nome='Meta Ads', ativo=True)]), 'campanha_canais': ws([]), 'projetos': ws([]), 'projeto_modelos': ws([]), 'pesquisas': ws([]), 'etapas_kanban': ws([]), 'pessoas': ws([]),
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
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'mkt-camp'; render();"); pg.wait_for_timeout(1000)
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(900)
    pa = lambda: ev(pg, "[...document.querySelectorAll('.wzp div')].filter(x => x.style.display !== 'none').map(x => x.textContent.trim())")
    chk(pa() == ['1. O básico', '2. Datas das etapas', '3. Histórico e referências', '4. Orçamento e cenários', '5. Canais', '6. Pesquisa'], 'o assistente tem as datas num passo próprio, depois do básico', pa())
    chk(ev(pg, "!document.querySelector('.wzb [name=fase_aquisicao_ini]')"), 'o passo 1 não tem mais as datas das etapas')
    pg.select_option('[name=modelo]', 'perpetuo'); pg.wait_for_timeout(50)
    chk(pa() == ['1. O básico', '2. Histórico e referências', '3. Orçamento e cenários', '4. Canais', '5. Pesquisa'], 'no perpétuo, o passo das datas some e os números se ajustam', pa())
    pg.select_option('[name=modelo]', 'lancamento'); pg.wait_for_timeout(50)
    pg.fill('[name=nome]', 'Método Jan/27'); pg.select_option('[name=produto_id]', 'p1'); pg.fill('[name=data_inicio]', '2027-01-10'); pg.fill('[name=data_fim]', '2027-01-31'); avanca(pg)
    chk(ev(pg, "[...document.querySelectorAll('.wzb input[type=date]')].filter(i => i.offsetParent).map(i => i.name).join()") == 'fase_aquisicao_ini,fase_aquisicao_fim,fase_aquecimento_ini,fase_aquecimento_fim,data_carrinho_abre,data_carrinho_fecha', 'passo 2: aquisição, aquecimento e carrinho à vista')
    chk(ev(pg, "!document.querySelector('[name=fase_conversao_ini]') && !document.querySelector('[name=fase_retencao_ini]')"), 'sem conversão e retenção nas datas do lançamento')
    pg.fill('[name=fase_aquisicao_ini]', '2027-01-10'); pg.fill('[name=fase_aquisicao_fim]', '2027-01-05'); avanca(pg)
    chk(ev(pg, "!!document.querySelector('[name=fase_aquisicao_ini]')") and not nova(pg).get('fases'), 'etapa com o fim antes do início não salva')
    pg.fill('[name=fase_aquisicao_fim]', '2027-01-20'); pg.fill('[name=fase_aquecimento_ini]', '2027-01-21'); pg.fill('[name=data_carrinho_abre]', '2027-01-25'); pg.fill('[name=data_carrinho_fecha]', '2027-01-20'); avanca(pg)
    chk(ev(pg, "!!document.querySelector('[name=fase_aquisicao_ini]')") and not nova(pg).get('fases'), 'carrinho que fecha antes de abrir não salva')
    pg.fill('[name=data_carrinho_fecha]', '2027-01-28')
    pg.check('[data-wzex=reabertura]', force=True); pg.wait_for_timeout(50)
    chk(ev(pg, "!!document.querySelector('[name=fase_reabertura_ini]').offsetParent") and not ev(pg, "!!document.querySelector('[name=fase_downsell_ini]').offsetParent"), 'marcar reabertura mostra as datas dela; downsell continua escondido')
    avanca(pg); chk(ev(pg, "!!document.querySelector('[name=fase_aquisicao_ini]')") and not nova(pg).get('fases'), 'reabertura marcada precisa de início')
    pg.fill('[name=fase_reabertura_ini]', '2027-01-30'); pg.check('[data-wzex=downsell]', force=True); pg.fill('[name=fase_downsell_ini]', '2027-02-01'); pg.fill('[name=fase_downsell_fim]', '2027-02-05'); avanca(pg); pg.wait_for_timeout(600)
    c = nova(pg)
    chk(c and c['fases'] == {'aquisicao': {'ini': '2027-01-10', 'fim': '2027-01-20'}, 'aquecimento': {'ini': '2027-01-21', 'fim': None}, 'reabertura': {'ini': '2027-01-30', 'fim': None}, 'downsell': {'ini': '2027-02-01', 'fim': '2027-02-05'}} and c['data_carrinho_abre'] == '2027-01-25', 'salva as datas; a reabertura pode ficar em aberto', c and c.get('fases'))
    pg.screenshot(path=os.environ.get('FOTO2', os.path.join(tempfile.gettempdir(), 'x.png')), full_page=True)
    # ---- passo 2 ----
    chk('Trazer as últimas' in ev(pg, "document.querySelector('.wzb').textContent"), 'abre o passo de histórico')
    chk(ev(pg, "document.querySelector('#chQtd').value") == '3' and ev(pg, "[...document.querySelectorAll('#chQtd option')].map(o => o.value).join()") == '1,2,3,4', 'começa com 3 e oferece até as 4 disponíveis')
    head = ev(pg, "[...document.querySelectorAll('.ch-t thead th')].map(t => t.textContent)")
    chk(head == ['Campanha', 'Investido', 'Leads', 'Clientes', 'Receita', 'CPL', 'CAC', 'Conversão', 'ROAS'], 'a lista tem só as 8 métricas pedidas', head)
    nomes = ev(pg, "[...document.querySelectorAll('[data-chdet]')].map(a => a.textContent)")
    chk(nomes == ['Método Set/26', 'Método Jun/26', 'Método Mar/26'], 'traz as 3 mais recentes, só do produto escolhido', nomes)
    chk(ev(pg, "[...document.querySelectorAll('.ch-g')].map(g => g.dataset.chg).join()") == 'cpl,cac,conv' and ev(pg, "document.querySelectorAll('.ch-g[data-chg=cpl] .ch-c').length") == 3, 'gráficos só de CPL, CAC e conversão, uma barra por campanha')
    chk(ev(pg, "getComputedStyle(document.querySelector('.ch-g')).borderTopStyle") == 'solid', 'gráficos dentro de uma linha fina')
    chk(ev(pg, "!!(document.querySelector('.ch-t').compareDocumentPosition(document.querySelector('.ch-gs')) & Node.DOCUMENT_POSITION_FOLLOWING)"), 'gráficos abaixo da tabela')
    xs = ev(pg, "document.querySelector('.ch-g[data-chg=cpl] .ch-xs').textContent")
    chk(xs.index('03/26') < xs.index('06/26') < xs.index('09/26'), 'gráfico da mais antiga para a mais recente', xs)
    alt = ev(pg, "[...document.querySelectorAll('.ch-g[data-chg=cpl] .ch-c i')].map(i => parseFloat(i.style.height))"); mdb = ev(pg, "parseFloat(document.querySelector('.ch-g[data-chg=cpl] .ch-md').style.bottom)")
    chk(abs(alt[2] - 92) < .01 and abs(mdb - 25.4717 / 30 * 92) < .1, 'barras e linha da média na mesma escala', [alt, mdb])
    if os.environ.get('FOTO'): pg.screenshot(path=os.environ['FOTO'], full_page=True)
    media = ev(pg, "document.querySelector('#chMediaW').textContent")
    for v, n_ in [('4.500', 'investido em média simples (13.500 ÷ 3)'), ('177', 'leads em média simples (530 ÷ 3)'), ('25,47', 'CPL ponderado'), ('675,00', 'CAC ponderado'), ('4,15%', 'conversão ponderada'), ('2,44', 'ROAS ponderado')]:
        chk(v in media, n_, media)
    chk(ev(pg, "[...document.querySelectorAll('.ch-t input')].map(i => i.name.slice(3)).filter((x, i, a) => a.indexOf(x) === i).join()") == 'cpl,cac,conv', 'só CPL, CAC e conversão podem ser levados')
    chk(ev(pg, "[...document.querySelectorAll('[name=ch_cpl]')].filter(i => i.checked).map(i => i.value).join()") == '', 'começa com nada marcado')
    # detalhe da campanha
    pg.evaluate("window.__RPC = { campanha_canais_resultado: () => [{ id: 'x', canal: 'meta_ads', investimento: 6000, leads: 200, cpl: 30 }] }")
    pg.click('[data-chdet=jun]'); pg.wait_for_timeout(300)
    dt = ev(pg, "document.querySelector('#chDetalhe').textContent")
    chk('Método Jun/26' in dt and 'Vendas' in dt and 'Leads qualificados' in dt and 'Ticket médio' in dt and 'meta_ads' in dt, 'clicar na campanha abre o histórico dela', dt[:200])
    pg.click('#chFechaDet'); pg.wait_for_timeout(200); chk(not ev(pg, "!!document.querySelector('#chDetalhe')"), 'o detalhe fecha')
    # clicar de novo desmarca
    pg.check('[name=ch_cpl][value=media]', force=True); pg.wait_for_timeout(50); pg.click('[name=ch_cpl][value=media]', force=True); pg.wait_for_timeout(50)
    chk(not ev(pg, "!!document.querySelector('[name=ch_cpl]:checked')") and 'Nada marcado' in ev(pg, "document.querySelector('#chResumo').textContent"), 'clicar de novo desmarca')
    # marca: média em uma, campanha específica em outra
    pg.check('[name=ch_cpl][value=media]', force=True); pg.check('[name=ch_cac][value=jun]', force=True); pg.check('[name=ch_conv][value=media]', force=True); pg.wait_for_timeout(100)
    r = ev(pg, "document.querySelector('#chResumo').textContent")
    chk('média de 3' in r and 'Método Jun/26' in r, 'o resumo diz de onde vem cada número', r)
    chk(ev(pg, "!!document.querySelector('#chCoerW')") is False, 'CPL e conversão perto do CAC escolhido: sem aviso', r)
    pg.check('[name=ch_cac][value=set]', force=True); pg.wait_for_timeout(100)
    chk(ev(pg, "!!document.querySelector('#chCoerW')"), 'CAC que não conversa com CPL e conversão: avisa')
    pg.check('[name=ch_cac][value=jun]', force=True)
    pg.select_option('#chQtd', '1'); pg.wait_for_timeout(300)
    chk(ev(pg, "document.querySelectorAll('[data-chdet]').length") == 1 and ev(pg, "!!document.querySelector('#chPoucos')"), 'com 1 campanha, a lista diminui e avisa')
    chk(not ev(pg, "!!document.querySelector('[name=ch_cac]:checked')"), 'a marca da campanha que saiu é solta')
    chk('Não levar' not in ev(pg, "document.querySelector('.ch-t').textContent"), 'sem a linha "Não levar"')
    pg.select_option('#chQtd', '3'); pg.wait_for_timeout(300); pg.check('[name=ch_cac][value=jun]', force=True)
    chk(ev(pg, "document.querySelector('[name=ch_cpl][value=media]').checked"), 'a média continua marcada')
    avanca(pg); pg.wait_for_timeout(500)
    c = nova(pg)
    chk(c['meta_cpl'] == 25.47 and c['meta_cac'] == 642.86 and c['meta_taxa_lead_venda'] == 4.15, 'leva a média ou a campanha para as metas', [c.get('meta_cpl'), c.get('meta_cac'), c.get('meta_taxa_lead_venda')])
    rf = c['extras'].get('referencia_planejamento') or {}
    chk(len(rf.get('escolhas', [])) == 3 and [x['fonte'] for x in rf['escolhas'] if x['k'] == 'cac'] == ['Método Jun/26'] and rf.get('qtd') == 3 and [x['id'] for x in rf['campanhas']] == ['set', 'jun', 'mar'], 'guarda as escolhas, a fonte e as campanhas', rf)
    # voltar e seguir sem mudar não repete
    pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(400)
    chk(ev(pg, "document.querySelector('[name=ch_cac][value=jun]').checked"), 'voltar mostra o que foi marcado')
    avanca(pg); pg.wait_for_timeout(600)
    chk(not ev(pg, "__D.campanhas.find(x => x.nome === 'Método Jan/27').extras.referencia_planejamento.historico.length"), 'seguir sem mudar não cria outro registro')
    # orçamento e cenários
    V = lambda t, m: ev(pg, f"document.querySelector('[data-cen={t}][data-m={m}]').value")
    def po(t, m, v): pg.fill(f'[data-cen={t}][data-m={m}]', str(v)); pg.wait_for_timeout(60)
    chk(ev(pg, "[...document.querySelectorAll('.cen-t thead th')].map(x => x.textContent).join()") == ',Pessimista,Base,Otimista', 'os três cenários na tela')
    chk(float(V('base', 'p')) == 25.47 and float(V('base', 'a')) == 642.86 and float(V('base', 'c')) == 4.15, 'o Base traz o CPL, o CAC e a conversão marcados', [V('base', 'p'), V('base', 'a'), V('base', 'c')])
    chk(float(V('base', 't')) == 1497, 'ticket vem do preço do produto')
    chk(V('base', 'I') == '' and V('base', 'L') == '', 'investimento fica para preencher')
    po('base', 'I', 10000)
    chk(int(V('base', 'L')) == 393 and int(V('base', 'V')) == 16, 'pôr o investimento calcula leads e vendas', [V('base', 'L'), V('base', 'V')])
    chk(float(V('base', 'a')) == 625, 'e recalcula o CAC', V('base', 'a'))
    chk(float(V('pessimista', 'p')) == round(25.47 * 1.2, 2) and float(V('otimista', 'p')) == round(25.47 * .8, 2) and float(V('pessimista', 'I')) == 10000, 'pessimista e otimista saem do Base', [V('pessimista', 'p'), V('otimista', 'p')])
    chk(int(V('otimista', 'V')) > int(V('base', 'V')) > int(V('pessimista', 'V')), 'as vendas ficam em ordem nos três', [V('pessimista', 'V'), V('base', 'V'), V('otimista', 'V')])
    chk('23.952' in ev(pg, "document.querySelector('[data-cenv=\"base:rec\"]').textContent") and '2,4' in ev(pg, "document.querySelector('[data-cenv=\"base:roas\"]').textContent"), 'receita e ROAS previstos', ev(pg, "document.querySelector('[data-cenv=\"base:rec\"]').textContent"))
    po('base', 'V', 20); chk(float(V('base', 'c')) == round(20 / 393 * 100, 2) and float(V('base', 'a')) == 500, 'pôr a meta de vendas recalcula conversão e CAC', [V('base', 'c'), V('base', 'a')])
    po('base', 'a', 400); chk(int(V('base', 'V')) == 25 and float(V('base', 'I')) == 10000, 'pôr o CAC calcula as vendas', V('base', 'V'))
    chk(int(V('base', 'L')) == round(25 / (float(V('base', 'c')) / 100)), 'e os leads que dá para conseguir com o orçamento', V('base', 'L'))
    po('base', 'L', 500); chk(float(V('base', 'p')) == 20, 'pôr os leads recalcula o CPL', V('base', 'p'))
    po('otimista', 'p', 10); ot = V('otimista', 'L'); po('base', 'I', 12000)
    chk(V('otimista', 'L') == ot and float(V('pessimista', 'I')) == 12000, 'cenário mexido à mão deixa de acompanhar o Base; o outro continua')
    pg.click('#cenRefaz'); pg.wait_for_timeout(60); chk(float(V('otimista', 'I')) == 12000, 'refazer volta a acompanhar o Base')
    avanca(pg); c = nova(pg)
    chk(float(c['orcamento_total']) == 12000 and c['meta_leads'] == int(float(c['meta_leads'])) and c['meta_cpl'] is not None and c['meta_cac'] is not None and c['meta_vendas'] is not None and c['meta_receita'] is not None, 'o Base vira a meta da campanha', [c.get('orcamento_total'), c.get('meta_leads'), c.get('meta_cpl'), c.get('meta_cac'), c.get('meta_vendas'), c.get('meta_receita')])
    chk(set(c['extras'].get('cenarios', {}).keys()) >= {'base', 'pessimista', 'otimista'}, 'guarda os três cenários')
    chk(c['extras'].get('referencia_planejamento', {}).get('escolhas'), 'mantém a memória do histórico')
    chk(ev(pg, "!!document.querySelector('[data-cn=meta_ads]')"), 'depois vem Canais'); avanca(pg); pg.wait_for_timeout(600)
    chk('Concluir' in ev(pg, "document.querySelector('#modalRoot .pri').textContent"), 'por último, Pesquisa, que conclui')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # sem histórico: segue sem travar
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(600)
    pg.fill('[name=nome]', 'Consultoria'); pg.evaluate("__D.produtos.push({ id: 'p3', workspace_id: 'w1', nome: 'Novo', preco: 1, ativo: true })")
    pg.evaluate("document.querySelector('[name=produto_id]').insertAdjacentHTML('beforeend', '<option value=p3>Novo</option>'); document.querySelector('[name=produto_id]').value = 'p3'")
    pg.fill('[name=data_inicio]', '2027-02-01'); pg.fill('[name=data_fim]', '2027-02-10'); avanca(pg); pg.wait_for_timeout(300)
    chk(ev(pg, "!!document.querySelector('[name=fase_aquisicao_ini]')"), 'datas em branco podem seguir'); avanca(pg); pg.wait_for_timeout(600)
    chk('Ainda não há campanha' in ev(pg, "document.querySelector('.wzb').textContent"), 'sem histórico: avisa')
    avanca(pg); chk(ev(pg, "!!document.querySelector('.cen-t')"), 'sem histórico: segue para os cenários')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # desmarcar tira a etapa; a aba da campanha preserva reabertura e downsell
    pg.evaluate("abrirWizard(__D.campanhas.find(x => x.nome === 'Método Jan/27').id, 2)"); pg.wait_for_timeout(500)
    chk(ev(pg, "document.querySelector('[data-wzex=reabertura]').checked"), 'reabertura volta marcada')
    pg.uncheck('[data-wzex=reabertura]', force=True); avanca(pg); pg.wait_for_timeout(500)
    chk('reabertura' not in nova(pg)['fases'] and 'downsell' in nova(pg)['fases'], 'desmarcar tira a reabertura')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # perpétuo pula as datas, nos dois sentidos
    pg.evaluate("abrirWizard()"); pg.wait_for_timeout(600)
    pg.fill('[name=nome]', 'Perpétuo novo'); pg.select_option('[name=modelo]', 'perpetuo'); pg.select_option('[name=produto_id]', 'p2'); pg.fill('[name=data_inicio]', '2027-03-01'); avanca(pg); pg.wait_for_timeout(600)
    chk(not ev(pg, "!!document.querySelector('[name=fase_aquisicao_ini]')") and 'Histórico' in ev(pg, "document.querySelector('.wzp .at').textContent"), 'perpétuo vai direto para o histórico')
    pg.evaluate("document.querySelector('[data-w=volta]').click()"); pg.wait_for_timeout(300)
    chk(ev(pg, "!!document.querySelector('[name=nome]')"), 'voltar do histórico no perpétuo cai no básico')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
