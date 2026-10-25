"""v0.140: Growth's Content — cliente marcado ganha pasta no Google Drive (pedido pelo banco à função content-drive).
Banco fa com 20261102100000_content_drive.sql (sem pg_net local: o pedido fica com erro explicado, que é o que se testa aqui;
a criação de verdade é testada em produção com o Apps Script). Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q, role=None, uid=None):
    pre = ''
    if role: pre += f"set role {role}; "
    if uid: pre += f"select set_config('request.jwt.claims', '{{\"sub\":\"{uid}\",\"role\":\"authenticated\"}}', false); "
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', pre + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip().split('\n')[-1]
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome like 'T140 %'")
    sql(f"update workspaces set content_ativo = false, content_drive_id = null, content_drive_url = null, content_drive_status = null, content_drive_erro = null, content_drive_em = null where id = '{WS}'")
    sql("delete from sistema_config where chave in ('content_drive_url', 'content_drive_raiz')")
limpa()
UID = front.UID

# ---------- banco ----------
AG = sql("insert into workspaces (nome, agencia) values ('T140 Agência', true) returning id")
CL = sql("insert into workspaces (nome) values ('T140 Cliente') returning id")
try: sql(f"select content_definir('{CL}', true)", 'authenticated', UID); chk(False, 'só a equipe interna liga o Growth\'s Content')
except Exception as e: chk('equipe interna' in str(e), 'só a equipe interna liga o Growth\'s Content')
sql(f"insert into workspace_membros (workspace_id, user_id, papel) values ('{AG}', '{UID}', 'admin')")
r = json.loads(sql(f"select content_definir('{CL}', true)", 'authenticated', UID))
chk(r['content_ativo'] and r['status'] == 'erro' and 'ainda não está ligada' in (r['erro'] or ''), 'marcar dispara o pedido; sem a função configurada, o erro diz o motivo %s' % r)
sql("insert into sistema_config (chave, valor) values ('content_drive_url', 'http://127.0.0.1:9/functions/v1/content-drive')")
sql(f"select content_drive_tentar('{CL}')", 'authenticated', UID)
st = sql(f"select content_drive_status || '|' || coalesce(content_drive_erro, '') from workspaces where id = '{CL}'")
chk(st.startswith('erro|') and 'função de pastas' in st, '"Tentar de novo" pede de novo; sem pg_net local, o erro é gravado %s' % st)
sql(f"update workspaces set content_drive_status = null where id = '{CL}'")
sql(f"select content_definir('{CL}', false)", 'authenticated', UID); sql(f"select content_definir('{CL}', true)", 'authenticated', UID)
chk(sql(f"select content_drive_status from workspaces where id = '{CL}'") == 'erro', 'religar pede a pasta de novo enquanto ela não existe')
sql(f"update workspaces set content_drive_id = 'pasta1', content_drive_url = 'https://drive.google.com/drive/folders/pasta1', content_drive_status = 'ok', content_drive_erro = null where id = '{CL}'")
sql(f"select content_definir('{CL}', false)", 'authenticated', UID); sql(f"select content_definir('{CL}', true)", 'authenticated', UID)
chk(sql(f"select content_drive_status || '|' || content_drive_id from workspaces where id = '{CL}'") == 'ok|pasta1', 'cliente que já tem pasta não pede outra')
L = json.loads(sql("select content_clientes()", 'authenticated', UID))
chk(any(c['nome'] == 'T140 Agência' and c['agencia'] for c in L) and any(c['nome'] == 'T140 Cliente' and c['url'] for c in L), 'lista mostra também a equipe interna e o link da pasta')
chk(sql(f"select coalesce(content_minha_pasta('{CL}')::text, 'nada')", 'authenticated', '00000000-0000-0000-0000-0000000000ff') == 'nada', 'quem não é do cliente não vê a pasta dele')
chk(sql("select has_table_privilege('authenticated', 'sistema_config', 'select')") == 'f', 'endereço e senha do Apps Script ficam fora da API')

# ---------- telas ----------
sql(f"update workspaces set content_ativo = true where id = '{WS}'"); sql(f"update workspaces set content_drive_status = 'erro', content_drive_erro = 'Senha inválida' where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    t = front.vai(pg, 'cfg-pacotes', '', 4000)
    p = pg.inner_text('#pacContent')
    chk("Growth's Content" in p and 'T140 Cliente' in p and 'Abrir pasta no Drive' in p, 'Pacotes de acesso: quadro do Growth\'s Content com o link da pasta')
    chk('Senha inválida' in p and pg.locator('#pacContent [data-cdt]').count() >= 1, 'pasta com erro mostra o motivo e "Tentar de novo"')
    pg.uncheck(f'[data-cdc="{CL}"]'); pg.wait_for_timeout(2500)
    chk(sql(f"select content_ativo from workspaces where id = '{CL}'") == 'f' and sql(f"select content_drive_id from workspaces where id = '{CL}'") == 'pasta1', 'desmarcar desliga o módulo e não apaga a pasta')
    front.vai(pg, 'mkt-cont', "S.ct = null;", 3500)
    chk(pg.locator('.head .pill.bad', has_text='Pasta no Drive não criada').count() == 1, 'topo do Growth\'s Content avisa que a pasta não foi criada')
    sql(f"update workspaces set content_drive_status = 'ok', content_drive_url = 'https://drive.google.com/drive/folders/x' where id = '{WS}'")
    front.vai(pg, 'mkt-cont', "", 3500)
    chk(pg.locator('.head a.cd-pasta').count() == 1, 'topo do Growth\'s Content com o link "Pasta no Drive"')
    pg.evaluate("document.getElementById('novoCli').style.display = ''"); pg.click('#novoCli'); pg.wait_for_timeout(400)
    chk("Usa o Growth's Content" in pg.inner_text('#modalRoot'), 'novo cliente: opção "Usa o Growth\'s Content"')
    pg.click('#modalRoot [data-x]')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
