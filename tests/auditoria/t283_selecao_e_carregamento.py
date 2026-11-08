"""v0.283: Growth's Content — selecionar vários cartões e mover de uma vez; dois cliques abrem o cartão; carregamento mais rápido.
Tela (Produção/Kanban): caixinha de seleção em cada cartão e "Selecionar todos" na coluna; a barra mostra quantos estão marcados e move todos
("Mover para…"); arrastar um marcado leva todos; os que precisam de tema/data para a produção ficam e a tela diz quais; dois cliques no cartão abrem o conteúdo.
Carregamento: com 300 conteúdos (descrições longas, como na Mathisa), trocar filtro, aba ou voltar para a tela não baixa tudo de novo; gravar algo recarrega.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, subprocess, time; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import front
from playwright.sync_api import sync_playwright
WS = 'ac80a0e2-a34a-46c9-a59d-215f81270c08'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
one = lambda q: sql(q).split('\n')[0]
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from conteudo_publicacoes where conteudo_id in (select id from conteudos where workspace_id = '{WS}' and titulo like 'T283%')")
    sql(f"delete from conteudos where workspace_id = '{WS}' and titulo like 'T283%'")
    sql(f"delete from conteudo_temas where workspace_id = '{WS}' and nome = 'T283 Tema'")
limpa()
T = one(f"insert into conteudo_temas (workspace_id, nome, ativo) values ('{WS}', 'T283 Tema', true) returning id")
# 300 conteúdos com descrição longa (a Mathisa tem 294, com ~800 kB no total)
sql(f"insert into conteudos (workspace_id, titulo, status, descricao) select '{WS}', 'T283 Massa ' || g, 'arquivado', repeat('Pesquisa e contexto da ideia. ', 95) from generate_series(1, 300) g")
I = [one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T283 Ideia {i}', 'ideia') returning id") for i in range(1, 4)]
PD = [one(f"insert into conteudos (workspace_id, titulo, status, tema_id, data_publicacao, roteiro_aprovado_em, roteiro_aprovado_por) values ('{WS}', 'T283 Pauta pronta {i}', 'pauta', '{T}', '2026-11-2{i}', now(), 't') returning id") for i in range(1, 3)]
PS = one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T283 Pauta sem data', 'pauta') returning id")
st = lambda i: sql(f"select status from conteudos where id = '{i}'")
SHOT = os.path.dirname(os.path.abspath(__file__)) + '/shots283/'; os.makedirs(SHOT, exist_ok=True)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-07', vw=1600, vh=1000)
    REQ = []
    pg.on('request', lambda r: REQ.append(r.url) if '/rest/v1/conteudos' in r.url and r.method == 'GET' else None)
    kan = "S.ct = Object.assign(S.ct || {}, { tab: 'kanban', arq: false });"
    t0 = time.time(); front.vai(pg, 'mkt-cont', kan, 3500)
    n1 = len(REQ)
    chk(n1 >= 1, 'abrir o Content busca os conteúdos uma vez', n1)
    # carregamento: filtro, aba e voltar não baixam de novo
    pg.evaluate("() => { S.ct.busca = 'T283'; render(); }"); pg.wait_for_timeout(1200)
    pg.evaluate("() => { S.ct.tab = 'ideias'; render(); }"); pg.wait_for_timeout(1200)
    pg.evaluate("() => { S.ct.tab = 'kanban'; S.ct.busca = ''; render(); }"); pg.wait_for_timeout(1500)
    chk(len(REQ) == n1, 'trocar filtro, aba e voltar para o Kanban: não baixa os conteúdos de novo (antes: a cada clique)', len(REQ) - n1)
    t = time.time(); pg.evaluate("() => { S.ct.busca = 'Pauta'; render(); }"); pg.wait_for_function("() => document.querySelectorAll('.gcard').length > 0 && [...document.querySelectorAll('.gcard')].every(c => /Pauta/.test(c.textContent))", timeout=10000)
    dt = time.time() - t; pg.evaluate("() => { S.ct.busca = ''; render(); }"); pg.wait_for_timeout(1000)
    chk(dt < 1.0, 'filtro com 300 conteúdos responde em menos de 1 segundo', round(dt, 2))
    # dois cliques abrem o conteúdo
    card = pg.locator(f'.gcard[data-id="{I[0]}"]')
    card.locator('b', has_text='T283 Ideia 1').dblclick(); pg.wait_for_timeout(1200)
    chk(pg.evaluate("() => [...document.querySelectorAll('#modalRoot input')].some(i => i.value === 'T283 Ideia 1')") and 'Editar conteúdo' in (pg.text_content('#modalRoot') or ''), 'dois cliques no cartão abrem o conteúdo')
    pg.screenshot(path=SHOT + '0_dois_cliques.png')
    pg.evaluate("() => { const r = document.querySelector('#modalRoot'); if (r) r.innerHTML = ''; }"); pg.wait_for_timeout(300)
    # selecionar todos da coluna Ideias
    col_ideia = pg.locator('.colk[data-col="ideia"][data-sub=""]')
    col_ideia.locator('[data-selcol]').click(); pg.wait_for_timeout(400)
    nsel = pg.evaluate("() => S.ctSel.size")
    chk(nsel >= 3 and pg.locator('.ct-selbar').count() == 1 and 'selecionado' in pg.text_content('.ct-selbar'), '"Selecionar todos" marca a coluna e aparece a barra com a quantidade', nsel)
    chk(col_ideia.locator('[data-selcol]').inner_text() == 'Desmarcar todos', 'o botão da coluna vira "Desmarcar todos"')
    pg.screenshot(path=SHOT + '1_selecionados.png')
    # desmarca tudo e marca só as 3 ideias de teste (checkbox + Ctrl+clique)
    pg.click('[data-sellimpa]'); pg.wait_for_timeout(800)
    chk(pg.evaluate("() => S.ctSel.size") == 0 and pg.locator('.ct-selbar').count() == 0, 'Limpar seleção desmarca tudo')
    pg.locator(f'.gcard[data-id="{I[0]}"] [data-sel]').check(); pg.locator(f'.gcard[data-id="{I[1]}"] [data-sel]').check()
    pg.locator(f'.gcard[data-id="{I[2]}"] b').first.click(modifiers=['Control']); pg.wait_for_timeout(300)
    chk(pg.evaluate("() => S.ctSel.size") == 3, 'caixinha e Ctrl+clique marcam os cartões', pg.evaluate("() => S.ctSel.size"))
    # arrastar um marcado leva todos para Pautas aprovadas
    src = pg.locator(f'.gcard[data-id="{I[0]}"]'); dst = pg.locator('.colk[data-col="pauta"][data-sub=""]')
    src.drag_to(dst); pg.wait_for_timeout(3500)
    chk(all(st(i) == 'pauta' for i in I), 'arrastar um dos marcados leva os 3 para Pautas aprovadas de uma vez', [st(i) for i in I])
    chk(pg.evaluate("() => S.ctSel.size") == 0, 'depois de mover, a seleção é limpa')
    # mover pela barra: 2 pautas prontas + 1 sem data para Em produção
    for i in PD + [PS]: pg.locator(f'.gcard[data-id="{i}"] [data-sel]').check()
    pg.select_option('[data-selmv]', 'producao|'); pg.wait_for_timeout(3500)
    chk(all(st(i) == 'producao' for i in PD) and st(PS) == 'pauta', 'pela barra: as 2 pautas com tema e data vão para Em produção; a sem data fica', [st(i) for i in PD + [PS]])
    txt = pg.text_content('#modalRoot') or ''
    chk('2 de 3 movidos' in txt and 'T283 Pauta sem data' in txt, 'a tela diz quantos foram e quais ficaram (sem tema ou data)', txt[:200])
    pg.screenshot(path=SHOT + '2_resumo.png')
    pg.evaluate("() => { const r = document.querySelector('#modalRoot'); if (r) r.innerHTML = ''; }")
    chk(len(REQ) > n1, 'depois de gravar, os conteúdos são recarregados (o que foi movido aparece certo)', len(REQ))
    # ideia que chegou por fora (outra pessoa, ChatGPT, automação): aparece ao entrar de novo no Content
    N = one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T283 Chegou por fora', 'ideia') returning id")
    front.vai(pg, 'crm-leads', '', 1500); front.vai(pg, 'mkt-cont', kan, 3500)
    chk(pg.locator(f'.gcard[data-id="{N}"]').count() == 1, 'ideia criada por fora aparece ao voltar para o Content vindo de outra tela')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
