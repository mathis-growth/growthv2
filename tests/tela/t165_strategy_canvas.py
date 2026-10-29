import json, os, tempfile
# Teste de tela da v0.165 (Strategy Canvas S1 a S3): biblioteca de estratégias no Marketing (categoria, versão, situação, filtros),
# estratégia em Mapa (blocos nas posições, setas com ramificação, painel de propriedades, componentes, ligar na ordem) e em Lista,
# publicar versão e ver as versões; campanhas mostram a versão que usam.
# Rodar: python3 tests/tela/t165_strategy_canvas.py   (FOTOS=pasta salva capturas em claro e escuro)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't165_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]),
  'funis': ws([dict(id='f1', nome='Lançamento com aulas', tipo='lancamento', categoria='Lançamento', objetivo='Vender a mentoria', status='ativa', ativo=True, versao_atual=1, criado_em='2026-10-01T10:00:00Z'),
               dict(id='f2', nome='Perpétuo simples', tipo='perpetuo', categoria='Perpétuo', status='rascunho', ativo=True, versao_atual=0, criado_em='2026-10-05T10:00:00Z'),
               dict(id='f3', nome='Antiga', tipo='outro', categoria='Perpétuo', status='arquivada', ativo=False, versao_atual=2, criado_em='2026-01-05T10:00:00Z')]),
  'estrategia_blocos': ws([dict(id='b1', funil_id='f1', ordem=10, fase='aquisicao', tipo='trafego', nome='Meta Ads', x=40, y=80, props={'canal': 'Meta Ads'}),
                           dict(id='b2', funil_id='f1', ordem=20, fase='aquisicao', tipo='captura', nome='Página de captura', x=300, y=80, props={}),
                           dict(id='bl', funil_id='f1', ordem=120, fase='aquecimento', tipo='condicao', nome='Assistiu à aula?', x=560, y=80, props={}),
                           dict(id='b3', funil_id='f1', ordem=210, fase='conversao', tipo='checkout', nome='Checkout', x=820, y=80, props={}),
                           dict(id='b4', funil_id='f1', ordem=220, fase='conversao', tipo='email', nome='E-mail de recuperação', x=820, y=260, props={})]),
  'estrategia_etapas': ws([dict(id='e1', funil_id='f1', ordem=100, fase='aquisicao', chave='trafego1_cliques', nome='Meta Ads · Cliques', origem='anuncios', metrica='cliques', bloco_id='b1', papel='principal'),
                           dict(id='e2', funil_id='f1', ordem=200, fase='aquisicao', chave='captura1_leads', nome='Página · Leads', origem='leads', bloco_id='b2', papel='principal'),
                           dict(id='e3', funil_id='f1', ordem=2100, fase='conversao', chave='checkout1_vendas', nome='Checkout · Vendas', origem='vendas', metrica='clientes', bloco_id='b3', papel='principal')]),
  'estrategia_conexoes': ws([dict(id='k1', funil_id='f1', de_bloco='b1', para_bloco='b2', tipo='segue'), dict(id='k2', funil_id='f1', de_bloco='b2', para_bloco='bl', tipo='segue'),
                             dict(id='k3', funil_id='f1', de_bloco='bl', para_bloco='b3', tipo='sim', rotulo='Assistiu', condicao='presença na aula'),
                             dict(id='k4', funil_id='f1', de_bloco='bl', para_bloco='b4', tipo='nao')]),
  'estrategia_versoes': ws([dict(id='v1', funil_id='f1', versao=1, nota='Primeira', publicada_em='2026-10-10T10:00:00Z', foto={'blocos': [{}] * 4, 'conexoes': [{}] * 3})]),
  'campanhas': ws([dict(id='c1', nome='Lançamento de março', status='planejada', funil_id='f1'), dict(id='c2', nome='Lançamento de abril', status='planejada', funil_id='f1')]),
  'campanha_estrategias': ws([dict(campanha_id='c1', funil_id='f1', versao_id='v1'), dict(campanha_id='c2', funil_id='f1', versao_id=None)]),
  'ofertas': ws([]), 'equipe': ws([dict(id='u1', nome='Ana', ativo=True)]), 'etapas_catalogo': [],
  'rpc:estrategia_publicar': 2,
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def txt(pg, sel): return pg.evaluate("s => { const e = document.querySelector(s); return e ? e.innerText.replace(/\\s+/g, ' ') : ''; }", sel)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1440, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'mkt-estrategias'; desenhaNav(); render();"); pg.wait_for_timeout(1200)
    pg.evaluate("const g = document.querySelector('#nav [data-g=Marketing]'); if (g && g.getAttribute('aria-expanded') !== 'true') g.click()"); pg.wait_for_timeout(500)
    chk(pg.evaluate("!!document.querySelector('#nav [data-v=\"mkt-estrategias\"]')"), 'Estratégias (Canvas) no menu do Marketing')
    t = txt(pg, '#main')
    chk('Lançamento com aulas' in t and 'Perpétuo simples' in t and 'Antiga' not in t, 'biblioteca mostra as em uso e esconde as arquivadas', t)
    chk('v1' in t and 'rascunho' in t and 'Vender a mentoria' in t and 'criada em 01/10/2026' in t, 'biblioteca com versão, rascunho, objetivo e data', t)
    chk(not pg.evaluate("!!document.querySelector('#c2')"), 'no Marketing, sem os quadros do Kanban')
    pg.select_option('#estFs', 'arquivadas'); pg.wait_for_timeout(700)
    t = txt(pg, '#main'); chk('Antiga' in t and 'Lançamento com aulas' not in t, 'filtro Arquivadas', t)
    pg.select_option('#estFs', 'todas'); pg.wait_for_timeout(700); pg.select_option('#estFc', 'Perpétuo'); pg.wait_for_timeout(700)
    t = txt(pg, '#main'); chk('Antiga' in t and 'Perpétuo simples' in t and 'Lançamento com aulas' not in t, 'filtro por categoria', t)
    pg.evaluate("S.estF = { cat: '', st: 'ativas' }; render();"); pg.wait_for_timeout(700)
    pg.click('#estNova'); pg.wait_for_timeout(500)
    chk(pg.evaluate("!!document.querySelector('#modalRoot [name=categoria]') && !!document.querySelector('#modalRoot [name=objetivo]')"), 'nova estratégia pede categoria e objetivo')
    pg.evaluate("document.querySelector('#modalRoot .x, #modalRoot [data-fecha], #modalRoot .close') ? document.querySelector('#modalRoot .x, #modalRoot [data-fecha], #modalRoot .close').click() : (document.querySelector('#modalRoot').innerHTML = '')"); pg.wait_for_timeout(300)
    # abre a estratégia: Mapa
    pg.evaluate("S.estSel = 'f1'; render();"); pg.wait_for_timeout(1300)
    chk(pg.evaluate("document.querySelectorAll('#cvBox .cv-no').length") == 5, 'mapa com os 5 blocos', pg.evaluate("document.querySelectorAll('#cvBox .cv-no').length"))
    chk(pg.evaluate("document.querySelector('[data-no=b1]').style.left") == '40px', 'bloco na posição salva')
    chk(pg.evaluate("document.querySelectorAll('#cvBox [data-ar]').length") == 4, '4 setas')
    chk(pg.evaluate("document.querySelector('[data-ar=k3] .cv-rot').textContent") == 'Assistiu' and pg.evaluate("document.querySelector('[data-ar=k4] .cv-rot').textContent") == 'Não', 'ramificação Sim (rótulo) e Não')
    chk('versão 1' in txt(pg, '.head') and 'Categoria: Lançamento' in txt(pg, '.head'), 'cabeçalho com categoria e versão')
    chk(pg.evaluate("!!document.querySelector('.cv-pal')") and 'Componentes' in txt(pg, '.cv-pal'), 'paleta de componentes')
    chk('5 blocos' in txt(pg, '#cvProp') and '4 ligações' in txt(pg, '#cvProp'), 'resumo no painel', txt(pg, '#cvProp'))
    pg.click('[data-no=b1] .cv-nm'); pg.wait_for_timeout(300)
    chk(pg.evaluate("document.querySelector('#cvFb [name=nome]').value") == 'Meta Ads' and pg.evaluate("document.querySelector('#cvFb [name=canal]').value") == 'Meta Ads', 'clicar no bloco abre as propriedades')
    pg.fill('#cvFb [name=objetivo]', 'Gerar cliques baratos'); pg.evaluate("document.querySelector('#cvFb').requestSubmit()"); pg.wait_for_timeout(800)
    chk(pg.evaluate("__D.estrategia_blocos.find(b => b.id === 'b1').props.objetivo") == 'Gerar cliques baratos', 'propriedade salva no bloco', pg.evaluate("JSON.stringify(__D.estrategia_blocos.find(b => b.id === 'b1').props)"))
    pg.evaluate("document.querySelector('[data-ar=k3] .cv-hit').dispatchEvent(new MouseEvent('click', { bubbles: true }))"); pg.wait_for_timeout(300)
    chk(pg.evaluate("document.querySelector('#cvFa [name=condicao]').value") == 'presença na aula', 'clicar na seta abre a ligação')
    pg.select_option('#cvFa [name=tipo]', 'divisao'); pg.fill('#cvFa [name=peso]', '30'); pg.evaluate("document.querySelector('#cvFa').requestSubmit()"); pg.wait_for_timeout(800)
    k3 = pg.evaluate("__D.estrategia_conexoes.find(c => c.id === 'k3')")
    chk(k3['tipo'] == 'divisao' and k3['peso'] == 30, 'ligação vira divisão 30%', k3)
    # mover bloco pelo cabeçalho
    bx = pg.locator('[data-no=b4] .cv-nh').bounding_box()
    pg.mouse.move(bx['x'] + 20, bx['y'] + 8); pg.mouse.down(); pg.mouse.move(bx['x'] + 80, bx['y'] + 60, steps=5); pg.mouse.up(); pg.wait_for_timeout(700)
    b4 = pg.evaluate("__D.estrategia_blocos.find(b => b.id === 'b4')")
    chk(b4['x'] != 820 or b4['y'] != 260, 'arrastar o bloco salva a posição', b4)
    # ligar pelo pino
    pn = pg.locator('[data-pino=b2]').bounding_box(); al = pg.locator('[data-no=b4] .cv-nm').bounding_box()
    pg.mouse.move(pn['x'] + 4, pn['y'] + 4); pg.mouse.down(); pg.mouse.move(al['x'] + 10, al['y'] + 5, steps=6); pg.mouse.up(); pg.wait_for_timeout(1000)
    chk(any(c['de_bloco'] == 'b2' and c['para_bloco'] == 'b4' for c in pg.evaluate("__D.estrategia_conexoes")), 'arrastar do pino até outro bloco cria a ligação')
    # adicionar componente pelo clique
    n0 = pg.evaluate("__D.estrategia_blocos.length")
    pg.click('.cv-pi[data-pt=whatsapp]') if pg.evaluate("!!document.querySelector('.cv-pi[data-pt=whatsapp]')") else pg.click('.cv-g[open] .cv-pi >> nth=0'); pg.wait_for_timeout(1200)
    novo = pg.evaluate("__D.estrategia_blocos.slice(-1)[0]")
    chk(pg.evaluate("__D.estrategia_blocos.length") == n0 + 1 and novo.get('x') is not None, 'clicar num componente cria o bloco com posição', novo)
    chk(pg.evaluate("document.querySelectorAll('#cvBox .cv-no').length") == 6, 'o novo bloco aparece no mapa')
    if FOTOS:
        for tema in ['dark', 'light']:
            pg.evaluate("t => { document.documentElement.dataset.theme = t; S.cvSel = null; S.cvView = null; render(); }", tema); pg.wait_for_timeout(1200)
            pg.screenshot(path=FOTOS + '/t165_mapa_' + ('escuro' if tema == 'dark' else 'claro') + '.png')
    # publicar versão e versões
    pg.click('#estPub'); pg.wait_for_timeout(500)
    chk(pg.evaluate("!!document.querySelector('#modalRoot form')"), 'Publicar versão abre a confirmação')
    pg.evaluate("const f = document.querySelector('#modalRoot form'); if (f.nota) f.nota.value = 'Ajustes'; f.requestSubmit()"); pg.wait_for_timeout(1000)
    chk(pg.evaluate("(__calls.filter(c => c[0] === 'rpc' && c[1] === 'estrategia_publicar').pop() || [])[2]") == {'p_funil': 'f1', 'p_nota': 'Ajustes'}, 'publica pela função do banco com a nota')
    pg.click('#estVers'); pg.wait_for_timeout(900)
    v = txt(pg, '#modalRoot'); chk('Primeira' in v and ('Lançamento de março' in v or 'v1' in v), 'Versões lista a v1 e quem usa', v)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # lista
    pg.click('[data-ev=lista]'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("!!document.querySelector('#estQuadro')") and not pg.evaluate("!!document.querySelector('#cvBox')"), 'Lista mostra o quadro de blocos')
    t = txt(pg, '#main')
    chk('Ligações entre os blocos' in t and 'Assistiu à aula?' in t, 'Lista mostra as ligações', t[:900])
    chk('Lançamento de março v1' in t and 'antes das versões' in t, 'campanhas com a versão que usam', t[-600:])
    pg.click('#estEd'); pg.wait_for_timeout(500)
    chk(all(pg.evaluate("k => !!document.querySelector('#modalRoot [name=' + k + ']')", k) for k in ['categoria', 'status', 'objetivo', 'criterios']), 'editar dados com categoria, situação, objetivo e critérios')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # sem permissão de edição: sem paleta
    pg.evaluate("S.estVista = 'mapa'; S.perm = { modulos: { mkt: 'ler', gro: 'nenhum' } }; S.permWs = S.ws; render();"); pg.wait_for_timeout(1200)
    chk(not pg.evaluate("!!document.querySelector('.cv-pal')") and not pg.evaluate("!!document.querySelector('[data-pino]')"), 'só leitura: sem componentes e sem pinos')
    pg.set_viewport_size({'width': 390, 'height': 900}); pg.wait_for_timeout(400)
    chk(pg.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 1"), 'no celular não rola para o lado', pg.evaluate("document.documentElement.scrollWidth"))
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
