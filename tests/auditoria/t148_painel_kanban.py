"""v0.148: painel da produção no Kanban (total por etapa, semana atual contra a meta e calendário das próximas semanas).
Banco fa. Escola Aurora com o módulo configurado. Apaga o que criou."""
import sys, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots148/'
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
    for t in ['conteudo_publicacoes', 'conteudos', 'conteudo_config']: sql(f"delete from {t} where workspace_id = '{WS}'")
    sql(f"update workspaces set content_setup_em = null, content_ativo = false where id = '{WS}'")
limpa()
sql(f"update workspaces set content_setup_em = now(), content_ativo = true where id = '{WS}'")
sql(f"insert into conteudo_config (workspace_id, meta_semanal) values ('{WS}', 3)")
# hoje = domingo 25/10/2026 -> semana atual 19/10 a 25/10; próxima 26/10 a 01/11
linhas = [('Pronto 1', 'pronto', '2026-10-21'), ('Publicado 1', 'publicado', '2026-10-20'), ('Produzindo', 'producao', '2026-10-24'),
          ('Prox A', 'pronto', '2026-10-27'), ('Prox B', 'agendado', '2026-10-29'), ('Prox C', 'pronto', '2026-10-31'),
          ('Daqui 2', 'pauta', '2026-11-03'), ('Pauta sem data', 'pauta', None), ('Ideia 1', 'ideia', None), ('Ideia 2', 'ideia', None)]
for t, st, d in linhas:
    sql(f"set session_replication_role = replica; insert into conteudos (workspace_id, titulo, status, data_publicacao) values ('{WS}', '{t}', '{st}', {repr(d) if d else 'null'})")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1100)
    front.vai(pg, 'mkt-cont', "S.ct = { tab: 'kanban' };", 3500)
    chk(pg.locator('.kb-painel').count() == 1, 'painel da produção no topo do Kanban')
    n = {x.get_attribute('data-kbcol'): x.locator('.kb-n').inner_text() for x in pg.locator('[data-kbcol]').all()}
    chk(n == {'ideia': '2', 'pauta': '2', 'producao': '1', 'pronto': '3', 'agendado': '1', 'publicado': '1'}, 'total em cada etapa ' + str(n))
    t = pg.inner_text('.kb-sem')
    chk('2 de 3' in t and '1 em produção com data nesta semana' in t and '1 sem data marcada' in t, 'esta semana: 2 de 3 prontos (pronto e publicado), 1 em produção, 1 sem data ' + t.replace('\n', ' | '))
    sems = [x.inner_text().replace('\n', ' ') for x in pg.locator('.kb-wl').all()]
    chk(len(sems) == 6 and 'Faltam 1' in sems[0] and 'Completa' in sems[1] and 'Faltam 3' in sems[2] and 'Vazia' in sems[3], 'calendário: atual falta 1, próxima completa, a outra com só uma pauta, depois vazias ' + str(sems[:4]))
    chk(pg.locator('.kb-d.hoje').count() == 1 and pg.locator('.kb-d.hoje .kb-dots i').count() == 0, 'hoje destacado no calendário')
    chk(pg.locator('.kb-w >> nth=2 >> .kb-d >> nth=1 >> .kb-dots i.kb-agend').count() == 0 and pg.locator('.kb-dots i.kb-agend').count() == 1, 'cada conteúdo vira um ponto com a cor da etapa')
    pg.screenshot(path=SHOT + '1_painel.png', clip={'x': 256, 'y': 0, 'width': 1184, 'height': 1100})
    pg.click('[data-kbsem="2026-10-26"]'); pg.wait_for_timeout(2500)
    chk(pg.evaluate("S.ct.tab") == 'plano' and '26/10/2026 a 01/11/2026' in pg.inner_text('#main'), 'clicar na semana abre o planejamento daquela semana')
    sql(f"update conteudo_config set meta_semanal = null where workspace_id = '{WS}'")
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban';", 3000)
    chk('Sem meta semanal' in pg.inner_text('.kb-sem') and 'Completa' not in pg.inner_text('.kb-cal'), 'sem meta: mostra os prontos sem dizer que a semana está completa')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
