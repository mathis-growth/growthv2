"""v0.238: Diagnóstico → aba Dados logo depois de "O que falta"; cada planilha tem "Importar" para o Growths do cliente.
Tela: as abas ficam 1 Formulário, 2 Evidências, 3 O que falta, 4 Dados…; sem Growths de cliente, a aba avisa; escolhido o Growths, "Importar"
baixa a planilha, abre Importar e validar dados no Growths do cliente com o de-para (colunas do arquivo × campos do Growths) já aberto;
importar grava os leads no Growths do cliente (não na Mathisa); "Voltar para o diagnóstico" volta para a aba Dados.
Banco fa (Escola Aurora como agência + um Growths de cliente de teste). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
EU = '00000000-0000-0000-0000-00000000a0a0'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots238/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't238%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T238%'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and (nome like 'Cliente T238%' or email like '%@t238.com')")
    for w in sql("select id from workspaces where nome = 'Growths T238'").split('\n'):
        if w: sql(f"set local session_replication_role = replica; delete from pessoas where workspace_id = '{w}'; delete from workspace_membros where workspace_id = '{w}';"); sql(f"delete from workspaces where id = '{w}'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
P = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', 'Cliente T238') returning id")
D = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T238 Diag', '{P}') returning id")
LEADS = "Nome;E-mail;Telefone;Data de entrada;Origem\nAna Lima;ana@t238.com;31988887777;2026-03-01;instagram\nBeto Reis;beto@t238.com;31977776666;2026-03-05;google\n".encode()
cam = f"{WS}/diag/{D}/t238_leads.csv"
sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{D}', 'equipe', 'equipe', 't238 leads.csv', '{cam}', {len(LEADS)}, 'enviado', now())")
front.ARQS['diagnostico/' + cam] = LEADS
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'dados';", 4500)
    pg.wait_for_selector('.dg-imp', state='attached', timeout=15000)
    abas = pg.evaluate("() => [...document.querySelectorAll('#main [data-abas] [data-aba-k]')].map(b => b.dataset.abaK)")
    chk(abas[:5] == ['form', 'evid', 'ck', 'dados', 'saber'], 'as abas: Formulário, Evidências, O que falta, Dados, O que já se sabe…', abas)
    chk('ainda não tem Growths' in (pg.text_content('.dg-imp') or ''), 'sem Growths de cliente, a aba avisa para criar pelo contrato')
    # cria o Growths do cliente (a equipe interna é membro)
    W = one("insert into workspaces (nome) values ('Growths T238') returning id"); sql(f"insert into workspace_membros (workspace_id, user_id, papel) values ('{W}', '{EU}', 'admin')")
    pg.evaluate("async () => { const wss = (await sb.from('workspaces').select('*').order('nome')).data; wsLista(wss); }")
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'dados';", 4500)
    pg.wait_for_selector('#dgImpWs', state='attached', timeout=15000)
    pg.select_option('#dgImpWs', W); pg.locator('.dg-imp').scroll_into_view_if_needed(); pg.screenshot(path=SHOT + '1_dados_importar.png')
    pg.click('[data-dgimp]'); pg.wait_for_timeout(6000)
    st = pg.evaluate("() => [S.view, S.ws]")
    chk(st == ['cfg-importar', W], 'Importar abre "Importar e validar dados" no Growths do cliente', st)
    t = pg.text_content('#main') or ''
    chk('Voltar para o diagnóstico' in t and 'T238 Diag' in t, 'aparece de onde veio o arquivo e o botão de voltar')
    chk(pg.locator('#impGo').count() == 1 and 'E-mail' in (pg.text_content('#impRes') or ''), 'o de-para já vem aberto (colunas do arquivo ao lado dos campos do Growths)')
    pg.screenshot(path=SHOT + '2_depara.png', full_page=False)
    pg.click('#impGo'); pg.wait_for_timeout(4000)
    n = sql(f"select count(*) from pessoas where workspace_id = '{W}' and email like '%@t238.com'"); n0 = sql(f"select count(*) from pessoas where workspace_id = '{WS}' and email like '%@t238.com'")
    chk(n == '2' and n0 == '0', 'importar grava os leads no Growths do cliente, não no da Mathisa', (n, n0))
    pg.click('#impVoltaDg'); pg.wait_for_timeout(4500)
    st = pg.evaluate("() => [S.view, S.ws, S.abas.dg]")
    chk(st == ['gro-diag', WS, 'dados'], 'Voltar para o diagnóstico volta para a Mathisa, na aba Dados', st)
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
