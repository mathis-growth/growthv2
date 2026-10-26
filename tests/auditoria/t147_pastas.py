"""v0.147: sem a opção do Drive da Mathisa; pastas da Mathisa (padrões) só para a equipe interna.
Banco fa com 20261108100000_content_pastas.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots147/'
import os; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def como(q):
    claims = json.dumps({'sub': front.UID, 'role': 'authenticated', 'email': 'auditoria@escolaaurora.com.br'})
    return sql(f"select set_config('request.jwt.claims', '{claims}', false); set role authenticated; {q}").split('\n')[-1]
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome like 'T147 %'")
    sql("delete from content_pastas_mathisa where nome like 'T147 %'")
limpa()

# ---------- banco ----------
chk(sql("select has_function_privilege('authenticated', 'content_drive_sem_google(uuid)', 'execute')") == 'f', 'a opção "pasta no Drive da Mathisa" não pode mais ser chamada pela tela')
chk(sql("select drive_pasta_id('https://drive.google.com/drive/folders/1AbCdEfGhIj_k-Lm?usp=sharing') || '|' || coalesce(drive_pasta_id('oi'), '-')") == '1AbCdEfGhIj_k-Lm|-', 'o id da pasta sai do link; texto qualquer não vale')
try: como(f"select content_pasta_mathisa_add(null, 'T147 X', 'https://drive.google.com/drive/folders/1AbCdEfGhIjKlMn')"); chk(False, 'quem não é da equipe interna não cadastra pasta da Mathisa')
except Exception as e: chk('Só a equipe interna' in str(e), 'quem não é da equipe interna não cadastra pasta da Mathisa')
chk(como("select count(*) from content_pastas_mathisa") == '0', 'cliente não vê as pastas da Mathisa')
try: como(f"select content_material_marcar('{WS}', 'links', 'ok')"); chk(False, '"links" não é mais um tipo de material')
except Exception as e: chk('Material desconhecido' in str(e), '"links" não é mais um tipo de material')

# ---------- telas ----------
AG = sql("insert into workspaces (nome, agencia) values ('T147 Agência', true) returning id").split('\n')[0]
sql(f"insert into workspace_membros (workspace_id, user_id, papel) values ('{AG}', '{front.UID}', 'admin')")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    pg.evaluate("abreMenu('cfg-pastas'); render()"); pg.wait_for_timeout(1500)
    chk('Pastas da Mathisa' in pg.inner_text('#nav'), 'equipe interna vê Pastas da Mathisa no menu')
    t = front.vai(pg, 'cfg-pastas', '', 3000)
    chk('padrões' in t and 'novidades' in t and 'Nenhuma pasta ainda' in t, 'tela explica padrões (Mathisa) x novidades (cliente)')
    pg.fill('#pmF [name=nome]', 'T147 Método MIRA'); pg.fill('#pmF [name=link]', 'link errado'); pg.click('#pmF button[type=submit]'); pg.wait_for_timeout(1500)
    chk(sql("select count(*) from content_pastas_mathisa where nome like 'T147 %'") == '0', 'link que não é de pasta é recusado')
    pg.fill('#pmF [name=link]', 'https://drive.google.com/drive/folders/1MiraPadroes12345?usp=sharing'); pg.click('#pmF button[type=submit]'); pg.wait_for_timeout(2500)
    chk(sql("select pasta_id || '|' || coalesce(workspace_id::text, 'todos') from content_pastas_mathisa where nome = 'T147 Método MIRA'") == '1MiraPadroes12345|todos', 'pasta para todos os clientes')
    pg.fill('#pmF [name=nome]', 'T147 Só da Aurora'); pg.fill('#pmF [name=link]', 'https://drive.google.com/drive/folders/1AuroraPadroes999'); pg.select_option('#pmF [name=ws]', WS); pg.click('#pmF button[type=submit]'); pg.wait_for_timeout(2500)
    chk(sql("select workspace_id from content_pastas_mathisa where nome = 'T147 Só da Aurora'") == WS, 'pasta para um cliente só')
    t = pg.inner_text('#main')
    chk('Todos os clientes' in t and 'Escola Aurora' in t, 'lista mostra para quem vale cada pasta')
    pg.screenshot(path=SHOT + '1_pastas_mathisa.png')
    pg.click('tr:has-text("T147 Método MIRA") [data-pma]'); pg.wait_for_timeout(2000)
    chk(sql("select ativo from content_pastas_mathisa where nome = 'T147 Método MIRA'") == 'f', 'pausar a pasta')
    pg.click('tr:has-text("T147 Só da Aurora") [data-pmx]'); pg.wait_for_timeout(2000)
    chk(sql("select count(*) from content_pastas_mathisa where nome = 'T147 Só da Aurora'") == '0', 'tirar a pasta da lista')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
