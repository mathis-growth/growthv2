import json, os, tempfile
# Teste de tela da v0.275: score vale em qualquer método, prioridade colorida no cartão, ordem crescente/decrescente,
# busca por texto (e botão de voz), colunas livres por etapa (Baú e Produção) e produção pedindo data.
# Rodar: python3 tests/tela/t275_ideias_colunas.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't275_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
def ideia(id, t, sc, d, **k): return dict(id=id, titulo=t, status='ideia', score_total=sc, formato='reels', tema_id='t1', canais=[], tags=[], criado_em=d, **k)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'conteudo_linhas': ws([]), 'conteudo_temas': ws([dict(id='t1', nome='Negócios', prioridade=1, ativo=True)]), 'conteudo_metas_semanais': ws([]), 'conteudo_publicacoes': ws([]),
  'conteudo_config': ws([dict(metodo='simples')]), 'equipe': ws([]),
  'conteudo_colunas': ws([dict(id='k1', etapa='ideia', nome='Ideias aprovadas', ordem=1)]),
  'conteudos': ws([ideia('a', 'Funil bonito que não vende', 27, '2026-11-01'), ideia('b', 'Métrica é sintoma', 20, '2026-11-03', hook='O número de leads cresce e o faturamento não'),
                   ideia('c', 'Lead barato não paga boleto', 15, '2026-11-02'), ideia('d', 'Ideia sem score', None, '2026-11-04'),
                   ideia('e', 'ROAS não é tudo', 25, '2026-11-05', coluna_id='k1'),
                   dict(id='p', titulo='Pauta da semana', status='pauta', score_total=23, formato='reels', tema_id='t1', canais=[], tags=[], criado_em='2026-10-20', data_publicacao='2026-11-12')]),
  'content_versoes': ws([]), 'content_produtos': ws([]), 'conteudo_conta_dia': ws([]), 'conteudo_fechamentos': ws([]), 'conteudo_formatos': ws([]), 'conteudo_linha_propostas': ws([]), 'conteudo_personas': ws([]),
}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
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
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1';")
    # Baú
    r = pg.evaluate("""async () => { const D = await dadosConteudo(); window.__DC = D; const out = {};
      const roda = C => { const el = document.createElement('div'); el.id = 'tBau'; document.body.append(el); tabIdeias(el, D, C);
        const g = [...el.querySelectorAll('[data-grupo]')].map(p => ({ id: p.dataset.grupo, h: p.querySelector('h2').textContent, t: [...p.querySelectorAll('.ct-ideia b')].map(b => b.textContent), pills: [...p.querySelectorAll('.ct-np')].map(x => x.className + '|' + x.textContent) }));
        const sel = [...el.querySelectorAll('[data-ct-nota] option')].map(o => o.textContent), busca = !!el.querySelector('[data-ct-busca]'), ord = !!el.querySelector('[data-ct-ordem]'); el.remove(); return { g, sel, busca, ord }; };
      out.padrao = roda({}); out.asc = roda({ ordem: 'nota_asc' }); out.sem = roda({ nota: 'sem' }); out.busca = roda({ busca: 'faturamento' }); out.alta = roda({ nota: 'alta' }); return out; }""")
    g = r['padrao']['g']
    chk([x['h'] for x in g] == ['No baú, esperando avaliação · 4', 'Ideias aprovadas · 1'], 'Baú separado: no baú e a coluna Ideias aprovadas', [x['h'] for x in g])
    chk(g[0]['t'] == ['Funil bonito que não vende', 'Métrica é sintoma', 'Lead barato não paga boleto', 'Ideia sem score'], 'maior nota primeiro', g[0]['t'])
    chk(g[0]['pills'][0].startswith('pill good') and 'Alta · 27/30' in g[0]['pills'][0] and 'pill warn' in g[0]['pills'][1] and 'pill bad' in g[0]['pills'][2] and 'Sem score' in g[0]['pills'][3], 'prioridade colorida pelo score (verde, amarelo, vermelho)', g[0]['pills'])
    chk(r['asc']['g'][0]['t'][:3] == ['Lead barato não paga boleto', 'Métrica é sintoma', 'Funil bonito que não vende'], 'menor nota primeiro', r['asc']['g'][0]['t'])
    chk(r['sem']['g'][0]['t'] == ['Ideia sem score'] and r['padrao']['sel'][-1] == 'Sem score', 'filtro Sem score funciona no método simples', r['sem'])
    chk(r['alta']['g'][0]['t'] == ['Funil bonito que não vende'] and r['alta']['g'][1]['t'] == ['ROAS não é tudo'], 'filtro Alta', r['alta'])
    chk(r['busca']['g'][0]['t'] == ['Métrica é sintoma'] and r['padrao']['busca'] and r['padrao']['ord'], 'busca acha pelo gancho, sem acento', r['busca'])
    # mover ideia para a coluna pelo Baú
    pg.evaluate("S.ct = { tab: 'ideias', tema: '', canal: '', formato: '', arq: false, dias: 30 }; S.view = 'mkt-cont'; render();"); pg.wait_for_timeout(1200)
    chk(pg.locator('.ct-ideia [data-col-id]').count() >= 4, 'cada ideia tem a escolha da coluna')
    pg.select_option('.ct-ideia[data-id="a"] [data-col-id]', 'k1'); pg.wait_for_timeout(800)
    chk(pg.evaluate("__D.conteudos.find(c => c.id === 'a').coluna_id") == 'k1', 'ideia vai para Ideias aprovadas sem data', pg.evaluate("__D.conteudos.find(c => c.id === 'a')"))
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'bau.png'), full_page=False)
    # busca digitada
    pg.fill('[data-ct-busca]', 'boleto'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("[...document.querySelectorAll('.ct-ideia b')].map(b => b.textContent)") == ['Lead barato não paga boleto'] and pg.evaluate("document.activeElement && document.activeElement.matches('[data-ct-busca]')"), 'buscar digitando filtra e o cursor continua no campo')
    pg.fill('[data-ct-busca]', ''); pg.keyboard.press('Enter'); pg.wait_for_timeout(900)
    # Produção (kanban)
    pg.evaluate("S.ct.tab = 'kanban'; render();"); pg.wait_for_timeout(1300)
    cols = pg.evaluate("[...document.querySelectorAll('.colk')].map(c => c.dataset.col + ':' + (c.dataset.sub || '') + ':' + c.querySelector('h3 span').textContent.trim().split(' ')[0])")
    chk(cols[:3] == ['ideia::Ideias', 'ideia:k1:Ideias', 'pauta::Pautas'] and pg.locator('.colk.ct-livre').count() == 1, 'Kanban com a coluna livre logo depois de Ideias', cols)
    chk(pg.evaluate("document.querySelector('.colk[data-sub=\"k1\"]').innerText.includes('Funil bonito')") and pg.evaluate("document.querySelector('.gcard[data-id=\"a\"]').classList.contains('ct-pr-alta')"), 'cartão na coluna livre, com a cor da prioridade')
    chk(pg.locator('.mq-board ~ * [data-ct-busca], .filters [data-ct-busca]').count() >= 1 and pg.locator('[data-ct-ordem]').count() >= 1, 'busca e ordem na Produção')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'producao.png'), full_page=False)
    # ideia sem data indo para a produção pede a data
    pg.evaluate("(() => { const x = document.querySelector('.gcard[data-id=\"b\"] [data-mv]'); x.value = 'pauta|'; x.dispatchEvent(new Event('change')); })()"); pg.wait_for_timeout(500)
    md = pg.inner_text('#modalRoot')
    chk('Mandar para a produção' in md and pg.locator('#modalRoot [name=data_publicacao]').count() == 1 and pg.evaluate("__D.conteudos.find(c => c.id === 'b').status") == 'ideia', 'ir para a produção pede a data e não move antes', md[:200])
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(200)
    # mover a pauta entre colunas da mesma etapa não pede nada
    # colunas: criar uma em Em produção
    pg.click('#cCols'); pg.wait_for_timeout(600)
    pg.fill('#modalRoot [data-novo="producao"]', 'Para gravar sexta'); pg.click('#modalRoot [data-cria="producao"]'); pg.wait_for_timeout(1200)
    chk(any(c['nome'] == 'Para gravar sexta' and c['etapa'] == 'producao' for c in pg.evaluate("__D.conteudo_colunas")), 'criar coluna dentro de uma etapa', pg.evaluate("__D.conteudo_colunas"))
    chk(pg.evaluate("[...document.querySelectorAll('#modalRoot [data-nome]')].map(i => i.value)") == ['Ideias aprovadas', 'Para gravar sexta'], 'a lista do modal atualiza', pg.evaluate("[...document.querySelectorAll('#modalRoot [data-nome]')].map(i => i.value)"))
    pg.fill('#modalRoot [data-novo="producao"]', 'para gravar sexta'); pg.click('#modalRoot [data-cria="producao"]'); pg.wait_for_timeout(600)
    chk(len([c for c in pg.evaluate("__D.conteudo_colunas") if c['etapa'] == 'producao']) == 1, 'não deixa nome repetido na etapa')
    if FOTOS: pg.screenshot(path=os.path.join(FOTOS, 'colunas.png'))
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    pg.set_viewport_size({'width': 390, 'height': 800}); pg.evaluate("S.ct.tab = 'ideias'; render();"); pg.wait_for_timeout(1200)
    chk(pg.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), 'cabe no celular')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t275:', 'tudo OK' if ok else 'COM FALHAS')
