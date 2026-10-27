"""v0.151: passos 5 (Pesquisa) e 6 (Dossiê) da configuração do Growth's Content.
A função content-pesquisa é simulada aqui (ela tem o teste próprio em tests/edge/pesquisa); o banco fa é real.
Banco fa com 20261111100000_content_pesquisa.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots151/'
import os; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    for t in ['content_dossies', 'content_pesquisas', 'content_produtos', 'conteudo_personas']: sql(f"delete from {t} where workspace_id = '{WS}'")
    sql(f"update workspaces set content_setup_em = null, content_ativo = false, content_setup_etapa = 0, content_setup_marcos = '{{}}', content_drive_status = null, content_drive_url = null, content_drive_id = null, content_fontes = '{{}}' where id = '{WS}'")
limpa()
sql(f"update workspaces set content_ativo = true, content_drive_status = 'ok', content_drive_id = 'P123', content_drive_url = 'https://drive.google.com/drive/folders/P123', content_fontes = '{{\"canais\":{{\"instagram\":\"@a\"}},\"links\":[{{\"url\":\"https://drive.google.com/drive/folders/X1234567890\"}}]}}' where id = '{WS}'")
sql(f"insert into conteudo_personas (workspace_id, nome, respostas) values ('{WS}', 'Persona principal', '{{\"nicho\":\"inglês\"}}')")
sql(f"insert into content_produtos (workspace_id, nome, valor) values ('{WS}', 'Curso Base', 997)")
CHAVE = {'v': True}; PEDIDOS = []
REL = "## 1. Quem é o cliente\n[Fato] Escola de inglês para adultos (arquivo **Apresentação**).\n## 3. Mercado e tendências\n- [Hipótese] Adultos procuram conversação.\n- Fonte: [Pesquisa X](https://exemplo.com/x)\n## 7. O que ainda falta saber\n1. Quantos alunos ativos?"
def funcao(route):
    req = route.request
    if req.method == 'GET': return route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body=json.dumps({'chave': CHAVE['v']}))
    if req.method == 'OPTIONS': return route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'access-control-allow-headers': '*'}, body='ok')
    b = json.loads(req.post_data or '{}'); PEDIDOS.append(b)
    if b.get('acao') == 'pesquisar':
        i = sql(f"insert into content_pesquisas (workspace_id, status, etapa) values ('{WS}', 'pesquisando', '3 arquivo(s) lido(s); pesquisando na web') returning id").split('\n')[0]
    else:
        i = sql(f"insert into content_dossies (workspace_id, pesquisa_id, versao, status) values ('{WS}', '{b['pesquisa_id']}', 1, 'gerando') returning id").split('\n')[0]
    route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body=json.dumps({'ok': True, 'id': i}))
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1100)
    ctx.route('http://audit.local/functions/v1/content-pesquisa', funcao)
    t = front.vai(pg, 'mkt-cont', "S.ct = { csEtapa: 5, csAntigo: true };", 3500)
    chk('Passo 5 de 9' in t and 'Pesquisa' in t and 'O que a pesquisa usa' in t and 'outra(s) pasta(s) do cliente' in t and 'Os produtos (1)' in t and pg.locator('#csSegue').is_disabled(), 'passo 5: mostra o que a pesquisa usa; sem ler o relatório não segue')
    chk(not pg.locator('#cpVai').is_disabled() and 'em construção' not in t.lower(), 'com a chave da IA: botão "Fazer a pesquisa" liberado; nada mais em construção')
    CHAVE['v'] = False; front.vai(pg, 'mkt-cont', '', 3000)
    chk('A IA ainda não está ligada' in pg.inner_text('#main') and pg.locator('#cpVai').is_disabled(), 'sem a chave da IA: avisa e o botão fica desligado')
    CHAVE['v'] = True; front.vai(pg, 'mkt-cont', '', 3000)
    pg.screenshot(path=SHOT + '1_antes.png')
    pg.click('#cpVai'); pg.wait_for_timeout(2500)
    chk(PEDIDOS and PEDIDOS[-1] == {'acao': 'pesquisar', 'workspace_id': WS} and 'Pesquisando' in pg.inner_text('#main') and '3 arquivo(s) lido(s)' in pg.inner_text('#main'), 'pedido da pesquisa e acompanhamento na tela')
    pid = sql(f"select id from content_pesquisas where workspace_id = '{WS}'")
    arq = json.dumps({'lista': [{'nome': 'Apresentação', 'caminho': 'GC › 02', 'rotulo': 'cliente', 'lido': True}, {'nome': 'MIRA', 'caminho': 'MIRA', 'rotulo': 'mathisa', 'lido': True}, {'nome': 'live.mp4', 'caminho': 'GC › Reuniões', 'rotulo': 'cliente', 'lido': False, 'motivo': 'Vídeo ou áudio: precisa da transcrição em texto'}], 'pastas_com_erro': []}).replace("'", "''")
    sql(f"update content_pesquisas set status = 'pronto', relatorio = '{REL}', fontes = '[{{\"url\":\"https://exemplo.com/x\",\"titulo\":\"Pesquisa X\"}}]', arquivos = '{arq}', concluido_em = now() where id = '{pid}'")
    pg.wait_for_timeout(5500)
    t = pg.inner_text('#main')
    chk('Relatório da pesquisa' in t and '2 arquivo(s) lido(s)' in t and '1 fonte(s) da web' in t, 'a tela se atualiza sozinha quando a pesquisa termina')
    chk(pg.locator('.md h2, .md h3').count() >= 3 and pg.locator('.md .md-tag').count() == 2 and pg.locator('.md a[href="https://exemplo.com/x"]').count() == 1 and pg.locator('.md ol li').count() == 1, 'relatório formatado: títulos, Fato/Hipótese marcados, link e lista')
    pg.click('summary:has-text("Arquivos")'); pg.wait_for_timeout(300)
    chk('precisa da transcrição' in pg.inner_text('.cp-arqs') and 'padrão da Mathisa' in pg.inner_text('.cp-arqs'), 'lista de arquivos: o não lido com o motivo; o padrão da Mathisa marcado')
    chk('Custo' not in t and 'tokens' not in t.lower(), 'o custo não aparece para o cliente')
    pg.screenshot(path=SHOT + '2_relatorio.png', full_page=True)
    pg.click('#cpLi'); pg.wait_for_timeout(3000)
    chk(PEDIDOS[-1] == {'acao': 'dossie', 'pesquisa_id': pid} and sql(f"select content_setup_marcos ? 'leitura' from workspaces where id = '{WS}'") == 't', '"Li o relatório" marca a leitura e pede o dossiê')
    chk('Passo 6 de 9' in pg.inner_text('#main') and 'Escrevendo o dossiê' in pg.inner_text('#main'), 'vai para o passo 6 e acompanha o dossiê')
    did = sql(f"select id from content_dossies where workspace_id = '{WS}'")
    secs = json.dumps([{'titulo': t2, 'texto': f'[Recomendação] texto de {t2}\n- ponto 1'} for t2 in ['Diferencial', 'Mecanismo do problema', 'Voz']]).replace("'", "''")
    sql(f"update content_dossies set status = 'rascunho', secoes = '{secs}', atualizado_em = now() where id = '{did}'")
    pg.wait_for_timeout(5500)
    t = pg.inner_text('#main')
    chk('Dossiê da marca · versão 1' in t and pg.locator('.cd-sec').count() == 3 and pg.locator('.cd-ind a').count() == 3 and pg.locator('#csSegue').is_disabled(), 'dossiê com as seções e o índice; sem "Dossiê ok" não segue')
    pg.screenshot(path=SHOT + '3_dossie.png', full_page=True)
    pg.click('#cdOk'); pg.wait_for_timeout(2500)
    chk(sql(f"select content_setup_marcos ? 'dossie' from workspaces where id = '{WS}'") == 't' and not pg.locator('#csSegue').is_disabled(), '"Dossiê ok" libera o passo')
    pg.click('#cdGera'); pg.wait_for_timeout(2500)
    chk(PEDIDOS[-1] == {'acao': 'dossie', 'pesquisa_id': pid}, '"Gerar de novo" pede outra versão a partir da mesma pesquisa')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
chk(sql("select has_table_privilege('authenticated', 'content_pesquisas', 'insert') or has_table_privilege('authenticated', 'content_dossies', 'update')") == 'f', 'só o servidor grava pesquisas e dossiês')
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
