import json, os, sys, tempfile, re
# Teste de tela da v0.109: Ideias pelo ChatGPT no Planejamento de conteúdo (gerar chave, instruções e esquema do GPT, revogar, selo "pela IA").
# Rodar: python3 tests/tela/t109_ideias_chatgpt.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't109_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'conteudo_linhas': ws([dict(id='l1', nome='Autoridade', ordem=1)]), 'conteudo_temas': ws([dict(id='t1', linha_id='l1', nome='Bastidores', prioridade=1, cor='#38bdf8', ativo=True)]),
  'conteudos': ws([dict(id='k1', titulo='Os 3 erros do lançamento', descricao='Ângulo do erro', tema_id='t1', formato='reels', canais=['instagram'], status='ideia', origem='ia', criado_em='2026-10-16T10:00:00Z'),
                   dict(id='k2', titulo='Ideia manual', formato='carrossel', canais=[], status='ideia', origem='manual', criado_em='2026-10-15T10:00:00Z')]),
  'conteudo_metas': [], 'conteudo_publicacoes': [], 'conteudo_config': [], 'equipe': [], 'conteudo_contas': [], 'canal_metricas': [],
  'chaves_api': ws([dict(id='ch0', nome='Chave antiga', prefixo='gw_1a2b3c', hash='x', escopo='ideias', criado_em='2026-10-01T10:00:00Z', ultimo_uso='2026-10-10T10:00:00Z', usos=12, revogada_em=None)]),
}
RPC = r"""window.__RPC = {
  chave_api_criar: (a, D) => { if (!a.p_nome) throw new Error('nome'); const k = 'gw_' + 'ab'.repeat(32); D.chaves_api.unshift({ id: 'ch' + D.chaves_api.length, workspace_id: a.p_ws, nome: a.p_nome, prefixo: k.slice(0, 9), hash: 'h', escopo: 'ideias', criado_em: '2026-10-16T12:00:00Z', ultimo_uso: null, usos: 0, revogada_em: null }); return k; },
  chave_api_revogar: (a, D) => { const c = D.chaves_api.find(x => x.id === a.p_id); c.revogada_em = '2026-10-16T13:00:00Z'; return null; } };"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
with sync_playwright() as p:
    b = p.chromium.launch(); ctx = b.new_context(viewport={'width': 1400, 'height': 1600}); ctx.grant_permissions(['clipboard-read', 'clipboard-write']); pg = ctx.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.on('dialog', lambda d: d.accept())
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    chk(re.search(r'Versão 0\.1\d\d', pg.inner_text('body')) is not None, 'rodapé mostra a versão')
    pg.click('#nav button[data-g=Marketing]'); pg.wait_for_timeout(300); pg.click('#nav button[data-v=mkt-cont]'); pg.wait_for_timeout(1800)
    card = pg.evaluate("() => { const c = document.querySelector('[data-id=k1]'); return c ? c.innerText : '' }")
    chk('pela IA' in card, 'cartão vindo da IA tem o selo "pela IA"', card)
    chk('pela IA' not in pg.evaluate("() => document.querySelector('[data-id=k2]').innerText"), 'cartão manual sem selo')
    pg.click('#cIA'); pg.wait_for_timeout(800)
    t = pg.inner_text('#modalRoot')
    chk('Ideias pelo ChatGPT' in t and 'microfone de ditado' in t and 'Chave antiga' in t and 'gw_1a2b3c' in t, 'modal: explicação, aviso do modo voz e chaves existentes', t[:400])
    instr = pg.input_value('#iaInstr'); chk('guardarIdeia' in instr and 'lerContexto' in instr, 'instruções do GPT citam as duas ações')
    sch = json.loads(pg.input_value('#iaSchema'))
    chk(sch['servers'][0]['url'].endswith('.supabase.co/functions/v1') and set(sch['paths']['/ideias'].keys()) == {'get', 'post'} and sch['paths']['/ideias']['post']['operationId'] == 'guardarIdeia', 'esquema OpenAPI com o endereço do Growths e as ações', sch['servers'])
    pg.click('#iaCpSchema'); pg.wait_for_timeout(300)
    chk(pg.evaluate("navigator.clipboard.readText()").startswith('{'), 'copiar esquema põe o JSON na área de transferência')
    pg.fill('#iaNome', 'ChatGPT da Rebecka'); pg.click('#iaGerar'); pg.wait_for_timeout(800)
    k = pg.input_value('#iaK'); chk(k == 'gw_' + 'ab' * 32 and pg.is_disabled('#iaGerar'), 'gera a chave e mostra uma vez', k)
    chk(D(pg, 'chaves_api')[0]['nome'] == 'ChatGPT da Rebecka', 'chave criada com o nome', D(pg, 'chaves_api')[0])
    pg.click('#iaCpK'); pg.wait_for_timeout(300); chk(pg.evaluate("navigator.clipboard.readText()") == k, 'copiar chave')
    pg.click('[data-iarev=ch0]'); pg.wait_for_timeout(1000)
    chk([c for c in D(pg, 'chaves_api') if c['id'] == 'ch0'][0]['revogada_em'] is not None, 'revogar chave')
    chk('revogada' in pg.inner_text('#modalRoot') and pg.locator('[data-iarev=ch0]').count() == 0, 'chave revogada aparece como revogada')
    pg.screenshot(path=os.path.join(tempfile.gettempdir(), 't109_modal.png'), full_page=True)
    # sem a migração
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''; window.__SEM=['chaves_api']; for (const k in _colCache) delete _colCache[k];")
    pg.click('#cIA'); pg.wait_for_timeout(800)
    chk('RODAR_v0.109' in pg.inner_text('#modalRoot') and pg.is_disabled('#iaGerar'), 'sem a migração: aviso e botão desligado')
    # celular
    pg.set_viewport_size({'width': 390, 'height': 900}); pg.wait_for_timeout(400)
    chk(pg.evaluate("document.querySelector('#modalRoot .modal').scrollWidth <= document.querySelector('#modalRoot .modal').clientWidth + 2"), 'modal sem rolagem lateral no celular')
    chk(not errs, 'sem erros de JavaScript', errs)
    b.close()
print('\nRESULTADO:', 'TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
sys.exit(0 if ok else 1)
