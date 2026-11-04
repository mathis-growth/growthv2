import json, os, tempfile
# Teste de tela da v0.255: quadro "Vendas da Hotmart" em Integrações.
# Rodar: python3 tests/tela/t255_webhook_hotmart.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't255_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {'workspaces': [{'id': W, 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'produtos': ws([dict(id='p1', nome='Método', preco=1000, ativo=True)]), 'plataformas_venda': ws([dict(id='pl1', nome='Hotmart')]), 'integracoes': ws([])}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:400]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def foto(pg, n):
    if FOTOS: pg.locator('#hmPainel').screenshot(path=os.path.join(FOTOS, n + '.png'))
VAZIO = "{configurado:false,pode_editar:true,recebidos:0,processados:0,revisar:0,sem_ligacao:[],ultimos:[]}"
CHEIO = """{configurado:true,plataforma_id:'pl1',pode_editar:true,ultimo_evento_em:'2026-11-04T14:30:00Z',recebidos:42,processados:39,revisar:3,
  sem_ligacao:[{id:'777',nome:'Mentoria na Hotmart',eventos:2,ultimo:'2026-11-04T14:30:00Z'}],
  ultimos:[{id:'e1',evento:'PURCHASE_APPROVED',transacao:'HP123',produto_nome:'Método',situacao:'processado',motivo:'Venda criada (aprovada).',recebido_em:'2026-11-04T14:00:00Z'},{id:'e2',evento:'PURCHASE_APPROVED',transacao:'HP124',produto_nome:'Mentoria na Hotmart',situacao:'revisar',motivo:'Produto da Hotmart ainda não ligado a um produto do Growths.',recebido_em:'2026-11-04T14:30:00Z'}]}"""
ABRE = "async () => { const m = document.querySelector('main') || document.body; await vIntegracoes(m); }"
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1000)
    pg.evaluate("""() => { window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; window.__CH = [];
      window.__RPC = { ...(window.__RPC || {}), hotmart_painel: () => (%s),
        hotmart_configurar: a => { __CH.push(['cfg', a]); return { chave: a.p_hottok || a.p_novo_endereco ? 'gw_abc' : null }; },
        hotmart_ligar_produto: a => { __CH.push(['liga', a]); return { resolvidos: 2, restam: 1 }; } }; }""" % VAZIO)
    pg.evaluate(ABRE); pg.wait_for_timeout(500)
    chk(pg.locator('#hmPainel').count() == 1, 'o quadro aparece em Integrações')
    chk('Não configurada' in pg.inner_text('#hmPainel'), 'sem configuração, mostra a situação')
    chk(pg.input_value('#hmPlat') == 'pl1', 'já traz a plataforma Hotmart do cadastro')
    chk(pg.get_attribute('#hmTok', 'type') == 'password', 'o hottok não aparece na tela')
    foto(pg, 'hm_inicio')
    pg.fill('#hmTok', 'hottok-123456'); pg.click('#hmSalva'); pg.wait_for_timeout(300)
    chk(pg.evaluate("__CH[0][1].p_hottok") == 'hottok-123456' and pg.input_value('#hmTok') == '', 'envia o hottok e limpa o campo')
    chk('/vendas-hotmart?chave=gw_abc' in pg.input_value('#hmUrl'), 'mostra o endereço do webhook', pg.input_value('#hmUrl'))
    chk('2.0.0' in pg.inner_text('#hmRes'), 'explica o que marcar na Hotmart')
    foto(pg, 'hm_endereco')
    pg.evaluate("window.__RPC.hotmart_painel = () => (%s)" % CHEIO); pg.evaluate(ABRE); pg.wait_for_timeout(500)
    t = pg.inner_text('#hmPainel')
    chk('Recebendo vendas' in t and '42' in t and 'Mentoria na Hotmart' in t, 'configurado: situação, números e produto sem ligação', t)
    pg.click('[data-hmliga="777"]'); pg.wait_for_timeout(200)
    chk(pg.evaluate("__CH.filter(x => x[0] === 'liga').length") == 0, 'sem escolher o produto, não liga')
    pg.select_option('[data-hmprod="777"]', 'p1'); pg.click('[data-hmliga="777"]'); pg.wait_for_timeout(300)
    chk(pg.evaluate("__CH.filter(x => x[0] === 'liga')[0][1].p_externo") == '777', 'liga o produto escolhido')
    pg.evaluate(ABRE); pg.wait_for_timeout(400)
    pg.evaluate("document.querySelectorAll('#hmPainel details').forEach(d => d.open = true)"); foto(pg, 'hm_recebendo')
    chk(pg.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), 'sem rolagem lateral')
    pg.set_viewport_size({'width': 390, 'height': 800}); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.querySelector('#hmPainel').getBoundingClientRect().right <= innerWidth + 1"), 'cabe no celular')
    chk(not errs, 'sem erro de script', errs)
    b.close()
print('t255:', 'tudo OK' if ok else 'COM FALHAS')
