"""v0.282: aprovar a ideia (Pautas aprovadas) não pede nada; tema e data de publicação só quando o conteúdo vai para a produção (ou depois).
Tela: ideia arrastada para Pautas aprovadas muda direto, sem janela; ideia ou pauta sem tema/data indo para Em produção abre "Mandar para a produção"
e entra em produção (não volta para pauta); pauta que já tem tema e data vai direto; ideia arquivada continua sem janela.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, subprocess; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
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
    sql(f"delete from conteudo_publicacoes where conteudo_id in (select id from conteudos where workspace_id = '{WS}' and titulo like 'T282%')")
    sql(f"delete from conteudos where workspace_id = '{WS}' and titulo like 'T282%'")
    sql(f"delete from conteudo_temas where workspace_id = '{WS}' and nome = 'T282 Tema'")
limpa()
T = one(f"insert into conteudo_temas (workspace_id, nome, ativo) values ('{WS}', 'T282 Tema', true) returning id")
nova = lambda t, extra='', vals='': one(f"insert into conteudos (workspace_id, titulo, status{extra}) values ('{WS}', '{t}', 'ideia'{vals}) returning id")
A, B, Ar = nova('T282 Aprovar'), nova('T282 Produzir'), nova('T282 Arquivar')
P = one(f"insert into conteudos (workspace_id, titulo, status, tema_id, data_publicacao) values ('{WS}', 'T282 Pauta pronta', 'pauta', '{T}', '2026-11-20') returning id")
P2 = one(f"insert into conteudos (workspace_id, titulo, status) values ('{WS}', 'T282 Pauta sem data', 'pauta') returning id")  # v0.282: pauta sem tema e sem data agora é aceita
sql(f"update conteudos set roteiro_aprovado_em = now(), roteiro_aprovado_por = 'teste' where id in ('{B}', '{P}', '{P2}')")
# banco (método simples): aprovar sem nada passa; produzir sem tema/data não
X = nova('T282 Banco')
sql(f"update conteudos set status = 'pauta' where id = '{X}'")
chk(sql(f"select status from conteudos where id = '{X}'") == 'pauta', 'banco: ideia vira pauta aprovada sem tema e sem data')
try: sql(f"update conteudos set status = 'producao', roteiro_aprovado_em = now() where id = '{X}'"); ok = False
except Exception as e: ok = 'antes de mandar para a produção' in str(e)
chk(ok, 'banco: ir para a produção sem tema/data é recusado com a mensagem certa')
st = lambda i: sql(f"select status from conteudos where id = '{i}'")
SHOT = os.path.dirname(os.path.abspath(__file__)) + '/shots282/'; os.makedirs(SHOT, exist_ok=True)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-07', vw=1440, vh=1000)
    front.vai(pg, 'mkt-cont', '', 4000)
    mv = lambda i, e: pg.evaluate("async ([i, e]) => { const D = await dadosConteudo(); await moverConteudo(D.cont.find(x => x.id === i), e, D); }", [i, e]) or pg.wait_for_timeout(1500)
    aberto = lambda: pg.locator('#modalRoot .modal:visible, #modalRoot form:visible').count() > 0 and 'Mandar para a produção' in (pg.text_content('#modalRoot') or '')
    mv(A, 'pauta')
    chk(st(A) == 'pauta' and not aberto(), 'ideia → Pautas aprovadas: muda direto, sem pedir tema nem data', st(A))
    mv(Ar, 'arquivado')
    chk(st(Ar) == 'arquivado' and not aberto(), 'ideia arquivada: sem janela')
    mv(P, 'producao')
    chk(st(P) == 'producao' and not aberto(), 'pauta que já tem tema e data: vai direto para Em produção', st(P))
    mv(B, 'producao')
    chk(aberto() and st(B) == 'ideia', 'ideia sem tema/data → Em produção: abre "Mandar para a produção" e não move antes de preencher')
    pg.screenshot(path=SHOT + '1_pede_data_na_producao.png')
    pg.select_option('#modalRoot select[name=tema_id]', T); pg.fill('#modalRoot input[name=data_publicacao]', '2026-11-25')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(2000)
    chk(sql(f"select status || '|' || data_publicacao || '|' || (tema_id = '{T}') from conteudos where id = '{B}'") == 'producao|2026-11-25|true', 'preenchido: entra em produção (não volta para pauta), com a data e o tema', sql(f"select status, data_publicacao from conteudos where id = '{B}'"))
    mv(P2, 'producao')
    chk(aberto() and st(P2) == 'pauta', 'pauta sem data → Em produção: também pede tema e data')
    pg.evaluate("() => { const r = document.querySelector('#modalRoot'); if (r) r.innerHTML = ''; }"); pg.wait_for_timeout(300)
    # Baú de ideias: o botão "Aprovar ideia" leva para Pautas aprovadas sem perguntar nada
    C = nova('T282 Baú')
    front.vai(pg, 'mkt-cont', "S.ct = Object.assign(S.ct || {}, { tab: 'ideias' });", 4000)
    card = pg.locator(f'.ct-ideia[data-id="{C}"]')
    chk(card.locator('[data-ok]').inner_text().strip() == 'Aprovar ideia', 'no Baú, o botão se chama "Aprovar ideia"', card.count())
    pg.screenshot(path=SHOT + '2_bau_aprovar.png')
    card.locator('[data-ok]').click(); pg.wait_for_timeout(2000)
    chk(st(C) == 'pauta' and not aberto(), 'Aprovar ideia: vai para Pautas aprovadas sem pedir data', st(C))
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
