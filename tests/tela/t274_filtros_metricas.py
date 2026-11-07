import json, os, tempfile
# Teste de tela da v0.274: teto de CAC filtrado por produto e por turma, cockpit Geral com MRR, ARR, NRR, penetração e North Star,
# e filtro por nota (score) no conteúdo.
# Rodar: python3 tests/tela/t274_filtros_metricas.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't274_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
T = json.load(open(SP + 't273_teto.json', encoding='utf-8'))
PROD = {p['nome']: p['produto_id'] for p in T['produtos']}
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id=v, nome=k, ativo=True, preco=1000, extras={}) for k, v in PROD.items()]),
  'campanhas': ws([]), 'growth_metricas': ws([]), 'rpc:growth_metricas_auto': {},
  'rpc:painel_gerencial': {'funil': {'total': 120}, 'vendas': {'aprovadas': 12, 'bruto': 24000}, 'caixa': {'saldo': 18500}, 'resultado': {'receita': 24000, 'lucro': 3000, 'margem': 0.125},
    'recorrencia': {'mrr': 3500, 'arr': 42000, 'nrr': 0.92, 'grr': 0.85}, 'penetracao': {'mercado': 20000, 'rotulo': 'professores de inglês', 'ativos': 500, 'pct': 0.025},
    'cac': {'cac_total': 400, 'novos': 2}, 'fluxo': {}},
  'rpc:cac_teto': T,
  'conteudo_linhas': ws([]), 'conteudo_temas': ws([dict(id='t1', nome='Negócios', prioridade=1, ativo=True)]), 'conteudo_metas_semanais': ws([]), 'conteudo_publicacoes': ws([]), 'conteudo_config': ws([]), 'equipe': ws([]),
  'conteudos': ws([dict(id='a', titulo='Ideia forte', status='ideia', ideia_media=8.5, formato='reels', tema_id='t1', canais=[], tags=[], criado_em='2026-11-01'),
                   dict(id='b', titulo='Ideia média', status='ideia', ideia_media=6.2, formato='reels', tema_id='t1', canais=[], tags=[], criado_em='2026-11-02'),
                   dict(id='c', titulo='Ideia sem nota', status='ideia', formato='reels', tema_id='t1', canais=[], tags=[], criado_em='2026-11-03')]),
  'content_versoes': ws([]), 'content_produtos': ws([]), 'conteudo_conta_dia': ws([]), 'conteudo_fechamentos': ws([]), 'conteudo_formatos': ws([]), 'conteudo_linha_propostas': ws([]), 'conteudo_personas': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
def txt(pg, sel): return pg.inner_text(sel).replace('\xa0', ' ')
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
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.abas = {}; S.tcF = null; S.view = 'cockpit'; render();"); pg.wait_for_timeout(1200)
    g = txt(pg, '.ck-geral').replace('\n', ' ')
    chk(all(x in g for x in ['MRR', 'R$ 3.500,00', 'ARR', 'R$ 42.000,00', 'NRR', '92', 'Penetração', '2,5', 'do mercado: 500 de 20.000', 'North Star', 'a definir', 'defina no Growth Model']), 'Geral: MRR, ARR, NRR, penetração e North Star a definir', g)
    if FOTOS: pg.locator('.ck-geral').screenshot(path=os.path.join(FOTOS, 'geral.png'))
    # teto: produto
    pg.click('[data-abas="ck"] [data-aba-k="teto"]'); pg.wait_for_timeout(600)
    pg.select_option('[data-tc-prod]', PROD['Curso']); pg.wait_for_timeout(300)
    box = txt(pg, '#tcBox')
    chk('Teto de CAC · Curso' in box and 'R$ 1.965,66' in box and pg.locator('.tc-t tbody tr').count() == 1, 'escolher o produto mostra só ele', box[:400])
    pg.click('#tcBox [data-tc-ltv="%s"]' % PROD['Curso']); pg.wait_for_timeout(300)
    chk('LTV · Curso' in txt(pg, '#modalRoot'), 'o LTV do quadro abre o do produto')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(200)
    # teto: turma
    pg.fill('[data-tc-ini]', '2026-03-01'); pg.fill('[data-tc-fim]', '2026-03-31'); pg.click('[data-tc-turma]'); pg.wait_for_timeout(600)
    calls = [c for c in pg.evaluate("__calls") if c[0] == 'rpc' and c[1] == 'cac_teto']
    chk(calls and calls[-1][2].get('p_f') == {'entrada_ini': '2026-03-01', 'entrada_fim': '2026-03-31'}, 'aplicar turma recalcula com as datas', calls[-1][2] if calls else None)
    chk(pg.input_value('[data-tc-prod]') == PROD['Curso'] and pg.input_value('[data-tc-ini]') == '2026-03-01', 'produto e datas continuam escolhidos')
    pg.fill('[data-tc-ini]', '2026-04-01'); pg.fill('[data-tc-fim]', '2026-03-01'); pg.click('[data-tc-turma]'); pg.wait_for_timeout(300)
    calls2 = [c for c in pg.evaluate("__calls") if c[0] == 'rpc' and c[1] == 'cac_teto']
    chk(len(calls2) == len(calls), 'datas invertidas não recalculam')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'teto_filtros.png'))
    pg.select_option('[data-tc-prod]', ''); pg.wait_for_timeout(300)
    chk('Teto de CAC da empresa' in txt(pg, '#tcBox') and pg.locator('.tc-t tbody tr').count() == 3, 'voltar para todos')
    # conteúdo: nota
    r = pg.evaluate("""async () => { const D = await dadosConteudo(); const f = n => mqFiltra(D, { nota: n }).map(c => c.titulo);
      const el = document.createElement('div'); document.body.append(el); tabIdeias(el, D, { nota: 'alta' });
      const ideias = [...el.querySelectorAll('.ct-ideia b')].map(b => b.textContent), sel = [...el.querySelectorAll('[data-ct-nota] option')].map(o => o.textContent); el.remove();
      const k = document.createElement('div'); document.body.append(k); tabKanban(k, D, { nota: 'sem' }); const kb = !!k.querySelector('#cfN'); k.remove();
      return { alta: f('alta'), media: f('media'), sem: f('sem'), ideias, sel, kb }; }""")
    chk(r['alta'] == ['Ideia forte'] and r['media'] == ['Ideia média'] and r['sem'] == ['Ideia sem nota'], 'faixas de nota', r)
    chk(r['ideias'] == ['Ideia forte'] and r['sel'][:2] == ['Todas', 'Alta (8 a 10)'] and r['kb'], 'filtro de nota nas ideias e no kanban', r)
    pg.set_viewport_size({'width': 390, 'height': 800}); pg.evaluate("S.view = 'cockpit'; render();"); pg.wait_for_timeout(1000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), 'cabe no celular')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t274:', 'tudo OK' if ok else 'COM FALHAS')
