import json, os, tempfile
# Teste de tela da v0.254: passo Comercial do assistente.
# Vendedores das ofertas já vêm na lista; comissão, base e meta por campanha; link de cada um; previsão do que sobra; Pesquisa vira o passo 8.
# Rodar: python3 tests/tela/t254_comercial_campanha.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't254_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Demo', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1000, ativo=True)]),
  'ofertas': ws([dict(id='o1', nome='Método à vista', produto_id='p1', papel='principal', preco=1000, ativo=True, status='ativa', versao=1)]),
  'campanhas': ws([dict(id='c1', nome='Método Jan/27', status='rascunho', produto_id='p1', modelo='lancamento', data_inicio='2027-01-10', data_fim='2027-01-31', orcamento_total=10000, meta_cpl=10, meta_leads=1000, meta_taxa_lead_venda=10, meta_vendas=100, meta_cac=100, meta_receita=100000, extras={'cenarios': {'base': {'I': 10000, 'p': 10, 'L': 1000, 'c': 10, 'V': 100, 'a': 100, 't': 1000}, 'meta_total': 100, 'meta_cac_total': 100}}, criado_em='2026-01-01')]),
  'campanha_ofertas': ws([dict(id='co1', campanha_id='c1', produto_id='p1', oferta_id='o1', nome='Método à vista', papel='principal', preco=1000, ordem=0)]),
  'vendas': ws([dict(id='v1', status='aprovada', valor_bruto=1000, taxa_plataforma=100, impostos=60)]),
  'equipe': ws([]), 'v_marketing_campanha': [], 'funis': ws([]), 'canais': ws([]), 'campanha_canais': ws([]), 'projetos': ws([]), 'projeto_modelos': ws([]), 'pesquisas': ws([]),
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
def poe(pg, sel, v): pg.fill(sel, str(v)); pg.dispatch_event(sel, 'change'); pg.wait_for_timeout(80)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; window.__SALVOS = [];
      window.__RPC = { ...(window.__RPC || {}), campanha_comercial: () => ({ vendedores: [], candidatos: [{ equipe_id: 'e1', nome: 'Ana Reis', externo: false, comissao_pct: 10, base: 'bruto' }], outros: [{ equipe_id: 'e2', nome: 'Beto Lima', externo: true }] }), campanha_comercial_salvar: (a) => { window.__SALVOS.push(a); return a.p_itens.length; } }; }""")
    pg.evaluate("abrirWizard('c1', 7)"); pg.wait_for_timeout(900)
    pa = ev(pg, "[...document.querySelectorAll('.wzp div')].map(x => x.textContent.trim())")
    chk(pa[6].startswith('7. Comercial') and pa[7].startswith('8. Pesquisa'), 'Comercial é o passo 7 e Pesquisa o 8', pa)
    nomes = ev(pg, "[...document.querySelectorAll('.com-t tbody b')].map(x => x.textContent)")
    chk(nomes == ['Ana Reis'], 'traz só quem está cadastrado nas ofertas da campanha', nomes)
    chk(ev(pg, "document.querySelector('[data-cv=\"0\"][data-ck=comissao_pct]').value") == '10' and ev(pg, "document.querySelector('[data-cv=\"0\"][data-ck=base]').value") == 'bruto', 'traz a comissão do cadastro')
    chk('Beto Lima (externo)' in ev(pg, "document.querySelector('#comAdd').textContent"), 'os outros vendedores ficam em Adicionar, com interno ou externo')
    pg.select_option('#comAdd', '0'); pg.wait_for_timeout(100)
    chk(ev(pg, "document.querySelectorAll('.com-t tbody b').length") == 2 and 'externo' in ev(pg, "document.querySelector('.com-t').textContent"), 'adiciona o vendedor externo')
    # comissão diferente nesta campanha e metas
    poe(pg, '[data-cv="0"][data-ck=comissao_pct]', 20); poe(pg, '[data-cv="0"][data-ck=meta_vendas]', 60)
    poe(pg, '[data-cv="1"][data-ck=comissao_pct]', 10); poe(pg, '[data-cv="1"][data-ck=meta_vendas]', 40)
    chk('100 de 100' in ev(pg, "document.querySelector('.com-t .tot').textContent"), 'total das metas sobre a meta da campanha')
    poe(pg, '[data-cv="1"][data-ck=meta_vendas]', 60); chk('passam da meta' in ev(pg, "document.querySelector('#comTab').textContent"), 'avisa quando as metas passam da meta da campanha'); poe(pg, '[data-cv="1"][data-ck=meta_vendas]', 40)
    # previsão: fat 100.000; taxa 10% e imposto 6% (média das vendas); comissão Ana 20% × 60% × bruto = 12.000; Beto 10% × 40% × líquido 84.000 = 3.360
    C = lambda k: ev(pg, f"document.querySelector('[data-cp=\"base:{k}\"]').textContent")
    chk('100.000' in C('fat') and '10.000' in C('taxa') and '6.000' in C('imposto'), 'previsão: faturamento, taxa e impostos', [C('fat'), C('taxa'), C('imposto')])
    chk('15.360' in C('comissao'), 'previsão: comissão pela meta e pela base de cada um', C('comissao'))
    chk('68.640' in C('sobra') and '58.640' in C('resultado'), 'previsão: o que sobra e o resultado', [C('sobra'), C('resultado')])
    chk(C('fat') != ev(pg, "document.querySelector('[data-cp=\"pessimista:fat\"]').textContent"), 'previsão nos três cenários')
    # link
    chk(not ev(pg, "!!document.querySelector('[data-ccp]:not([hidden])')"), 'sem link de checkout, mostra só o código')
    pg.fill('#comUrl', 'nao-e-link'); avanca(pg); chk(ev(pg, "!!document.querySelector('#comUrl')") and not ev(pg, "window.__SALVOS.length"), 'link inválido não salva')
    pg.fill('#comUrl', 'https://pay.hotmart.com/X123?off=abc'); pg.wait_for_timeout(60); chk(ev(pg, "!!document.querySelector('[data-ccp]:not([hidden])')"), 'com o link, cada vendedor tem o botão de copiar')
    lk = ev(pg, "comLink('https://pay.hotmart.com/X123?off=abc', 'vd_ana_1', 'c1')")
    chk(lk == 'https://pay.hotmart.com/X123?off=abc&sck=vd_ana_1&utm_content=vd_ana_1&utm_growth=c1', 'link leva o código do vendedor', lk)
    foto(pg, 'comercial')
    # cadastrar vendedor sem sair do passo
    # digitar e clicar direto no botão: o clique não pode se perder
    pg.fill('[data-cv="0"][data-ck=meta_vendas]', '60'); pg.click('#comNovo'); pg.wait_for_timeout(250); pg.fill('#modalRoot2 [name=nome]', 'Caio Novo', timeout=3000); pg.check('#modalRoot2 [name=externo]', force=True)
    pg.evaluate("document.querySelector('#modalRoot2 form').requestSubmit()"); pg.wait_for_timeout(500)
    eq = ev(pg, "__D.equipe.find(x => x.nome === 'Caio Novo')")
    chk(eq and eq['vinculo'] == 'vendedor' and eq['externo'] is True and eq['equipe_comercial'] is True, 'cadastra como vendedor externo', eq)
    chk('Caio Novo' in ev(pg, "document.querySelector('.com-t').textContent"), 'o novo vendedor entra na lista')
    pg.click('[data-crm="2"]'); pg.wait_for_timeout(100); chk('Caio Novo' in ev(pg, "document.querySelector('#comAdd').textContent"), 'tirar devolve para Adicionar')
    avanca(pg); pg.wait_for_timeout(500)
    sv = ev(pg, "window.__SALVOS[0]")
    chk(sv['p_campanha'] == 'c1' and len(sv['p_itens']) == 2 and sv['p_itens'][0]['comissao_pct'] == 20 and sv['p_itens'][0]['meta_vendas'] == 60 and sv['p_itens'][0]['codigo'].startswith('vd_ana'), 'grava comissão, meta e código', sv)
    c = ev(pg, "__D.campanhas.find(x => x.id === 'c1')"); pv = c['extras']['cenarios']['previsao']
    chk(c['extras']['checkout_url'].startswith('https://pay.hotmart') and abs(pv['base']['sobra'] - 68640) < .01 and pv['taxa_pct'] == 10, 'guarda o link e a previsão', pv.get('base'))
    chk('Concluir' in ev(pg, "document.querySelector('#modalRoot .pri').textContent"), 'depois vem Pesquisa, que conclui')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # previsão em Planejamento e metas
    pg.evaluate("""() => { const c = __D.campanhas.find(x => x.id === 'c1'); c.status = 'ativa'; __D.v_marketing_campanha.push({ campanha_id: 'c1', workspace_id: 'w1', nome: c.nome, investimento: 0, leads: 0, vendas: 0, clientes: 0, faturamento: 0, receita: 0 }); S.view = 'mkt-camp'; S.campSel = 'c1'; S.campTab = 'resumo'; render(); }"""); pg.wait_for_timeout(1500)
    t = ev(pg, "(document.querySelector('#campPrev') || {}).textContent || ''")
    chk('Quanto sobra' in t and '68.640' in t, 'a previsão aparece em Planejamento e metas', t[:300])
    foto(pg, 'previsao')
    # detalhe por vendedor
    pg.evaluate("""() => { window.__RPC.campanha_comercial = () => ({ vendedores: [{ equipe_id: 'e1', nome: 'Ana Reis', externo: false, meta_vendas: 60, vendas: 12, valor: 12000, comissao: 2400 }], candidatos: [], outros: [] }); __D['rpc:campanha_detalhe'] = { canais: [], dias: ['2027-01-10', '2027-01-11'], de: '2027-01-10', ate: '2027-01-31', ultimas_vendas: [], ultimos_leads: [], produtos: [] }; }""")
    d = ev(pg, "(async () => { await cdAbrir('c1', 'vendas'); await new Promise(r => setTimeout(r, 300)); const s = document.querySelector('#cdVendedores'); return s ? s.textContent : ''; })()")
    chk('Ana Reis' in d and '2.400' in d, 'o detalhe de Vendas mostra cada vendedor com a comissão', d[:300])
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # cadastro
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
