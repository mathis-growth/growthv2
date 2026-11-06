import json, os, tempfile
# Teste de tela da v0.272: conteúdo em destaque, painel lateral que muda de lado, fecha e reabre, e geração pela estrutura de copy.
# Rodar: python3 tests/tela/t272_conteudo_gerador.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't272_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'conteudo_linhas': ws([]), 'conteudo_temas': ws([dict(id='t1', nome='Negócios', prioridade=1, ativo=True)]), 'conteudo_metas_semanais': ws([]), 'conteudo_publicacoes': ws([]), 'conteudo_config': ws([]), 'equipe': ws([]),
  'conteudos': ws([dict(id='ct1', titulo='Por que o funil bonito não vende', descricao='O número de leads cresce e o faturamento não. Ângulo: a métrica é sintoma.', formato='reels', status='roteiro', tema_id='t1', canais=[], tags=[], roteiro='Rascunho antigo', roteiro_aprovado_em='2026-11-01T10:00:00Z', roteiro_aprovado_por='Rebecka', criado_em='2026-11-01')]),
  'produtos': ws([dict(id='p1', nome='Curso', ativo=True)]), 'content_versoes': ws([]), 'content_produtos': ws([]), 'conteudo_conta_dia': ws([]), 'conteudo_fechamentos': ws([]), 'conteudo_formatos': ws([]), 'conteudo_linha_propostas': ws([]), 'conteudo_personas': ws([])}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1366, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e))); pg.on('dialog', lambda d: d.accept())
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; window.__INV = [];
      window.__RPC = { ...(window.__RPC || {}), content_estruturas_opcoes: () => [{ id: 'e1', nome: 'Reel · A armadilha revelada', para_que: 'Mostra que a leitura óbvia está errada.', formatos: ['reels'], escolhidas: [] }, { id: 'e2', nome: 'Carrossel · A troca', para_que: 'Hábitos e trocas.', formatos: ['carrossel'], escolhidas: ['carrossel'] }] };
      sb.functions = { invoke: async (n, o) => { __INV.push([n, o.body]); return { data: { texto: 'Slide falado 1\\nSlide falado 2', modelo: 'claude' }, error: null }; } }; }""")
    er = pg.evaluate("async () => { try { localStorage.removeItem('growths_ct_painel'); const D = await dadosConteudo(); window.__DC = D; modalConteudo(D.cont[0], D); return ''; } catch (e) { return String(e.stack).slice(0, 600); } }"); pg.wait_for_timeout(900)
    chk(not er, 'abre o conteúdo', er.replace(chr(10), ' | '))
    chk(pg.locator('.ctd').count() == 1, 'tela do conteúdo com o painel')
    main = pg.inner_text('.ctd-main')
    chk('Título' in main and 'Descrição' in main and pg.input_value('textarea[name=roteiro]') == 'Rascunho antigo', 'no centro: título, descrição e o conteúdo', main[:300])
    side = pg.inner_text('.ctd-side')
    chk('Responsável' in side and 'Data de publicação' in side and 'Prazo de produção' in side, 'os outros campos ficam no painel', side[:300])
    grupos = pg.evaluate("[...document.querySelectorAll('#ctdEst optgroup')].map(g => g.label + ':' + g.children.length)")
    chk(grupos == ['Para este formato:1', 'Outros formatos:1'], 'estruturas do formato primeiro, depois as outras', grupos)
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'conteudo.png'))
    pg.click('[data-ctd="lado"]'); pg.wait_for_timeout(100)
    chk(pg.evaluate("document.querySelector('.ctd').classList.contains('esq')") and pg.evaluate("JSON.parse(localStorage.getItem('growths_ct_painel')).lado") == 'esquerda', 'painel passa para a esquerda e fica guardado')
    pg.click('[data-ctd="fecha"]'); pg.wait_for_timeout(100)
    chk(not pg.locator('.ctd-side').is_visible() and pg.locator('.ctd-abre').is_visible(), 'painel fecha e aparece o botão para reabrir')
    pg.click('.ctd-abre'); pg.wait_for_timeout(100)
    chk(pg.locator('.ctd-side').is_visible(), 'painel reabre')
    pg.click('#ctdGer'); pg.wait_for_timeout(300)
    chk(len(pg.evaluate('__INV')) == 0, 'sem estrutura escolhida, não gera')
    pg.select_option('#ctdEst', 'e1'); pg.select_option('#ctdNiv', 'problema'); pg.click('#ctdGer'); pg.wait_for_timeout(500)
    inv = pg.evaluate('__INV')
    chk(len(inv) == 1 and inv[0][0] == 'content-roteiro' and inv[0][1]['estrutura_id'] == 'e1' and inv[0][1]['nivel'] == 'problema' and inv[0][1]['conteudo']['titulo'].startswith('Por que'), 'gera em cima da estrutura e do nível escolhidos', inv)
    chk(pg.input_value('textarea[name=roteiro]').startswith('Slide falado 1'), 'o texto gerado vai para o conteúdo')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'gerado.png'))
    pg.click('#modalRoot .acts .pri'); pg.wait_for_timeout(700)
    c = pg.evaluate("__D.conteudos[0]")
    chk(c['roteiro'].startswith('Slide falado 1') and c['estrutura_id'] == 'e1' and c['nivel_consciencia'] == 'problema' and c['roteiro_aprovado_em'] is None, 'salvar grava o texto, a estrutura e o nível, e tira a aprovação', {k: c.get(k) for k in ['roteiro', 'estrutura_id', 'nivel_consciencia', 'roteiro_aprovado_em']})
    pg.evaluate("async () => { const D = await dadosConteudo(); modalConteudo(D.cont[0], D); }"); pg.wait_for_timeout(700)
    chk(pg.evaluate("document.querySelector('.ctd').classList.contains('esq')"), 'ao reabrir, lembra o lado escolhido')
    pg.set_viewport_size({'width': 390, 'height': 800}); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), 'cabe no celular')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t272:', 'tudo OK' if ok else 'COM FALHAS')
