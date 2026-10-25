"""v0.146: estruturas de roteiro e copy (biblioteca interna, o cliente só escolhe) e custos de IA (só para os e-mails indicados).
Banco fa com 20261107100000_content_estruturas.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots146/'
import os; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def como(q, email='auditoria@escolaaurora.com.br'):
    claims = json.dumps({'sub': front.UID, 'role': 'authenticated', 'email': email}).replace("'", "''")
    return sql(f"select set_config('request.jwt.claims', '{claims}', false); set role authenticated; {q}").split('\n')[-1]
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
EM0 = sql("select valor from sistema_config where chave = 'custos_emails'")
def limpa():
    sql("delete from workspaces where nome like 'T146 %'")
    sql(f"delete from content_estruturas_ws where workspace_id = '{WS}'")
    sql("delete from content_estruturas where nome like 'T146 %'")
    sql("delete from ia_uso where funcao like 't146%'")
    sql(f"update sistema_config set valor = '{EM0}' where chave = 'custos_emails'")
    sql("update sistema_config set valor = '' where chave = 'cambio_usd_brl'")
limpa()

# ---------- banco ----------
chk(sql("select count(*) from content_estruturas where ativo") == '7', '7 estruturas iniciais')
chk(como("select count(*) from content_estruturas") == '0', 'cliente (não interno) não lê a receita das estruturas')
op = json.loads(como(f"select content_estruturas_opcoes('{WS}')"))
chk(len(op) == 7 and set(op[0].keys()) == {'id', 'nome', 'para_que', 'formatos', 'escolhidas'}, 'o cliente vê só nome, para que serve e formatos (sem etapas nem instruções)')
aida = next(o for o in op if o['nome'] == 'AIDA'); reels = next(o for o in op if o['nome'].startswith('Gancho'))
try: como(f"select content_estruturas_escolher('{WS}', '[{{\"estrutura_id\":\"{reels['id']}\",\"formato\":\"email\"}}]'::jsonb)"); chk(False, 'formato que a estrutura não tem é recusado')
except Exception as e: chk('não existe' in str(e), 'formato que a estrutura não tem é recusado')
chk(como(f"select content_estruturas_escolher('{WS}', '[{{\"estrutura_id\":\"{aida['id']}\",\"formato\":\"email\"}},{{\"estrutura_id\":\"{reels['id']}\",\"formato\":\"reels\"}}]'::jsonb)") == '2', 'o cliente escolhe por formato')
chk(como("select count(*) from content_estruturas_ws") == '2', 'o cliente vê as próprias escolhas')
try: como(f"insert into content_estruturas_ws (workspace_id, estrutura_id, formato) values ('{WS}', '{aida['id']}', 'post')"); chk(False, 'escolha só pela função')
except Exception as e: chk('permission' in str(e).lower() or 'permissão' in str(e).lower(), 'escolha só pela função (sem gravar direto)')
sql("insert into ia_uso (workspace_id, funcao, modelo, tokens_entrada, tokens_saida, buscas, custo_usd) values ('" + WS + "', 't146 ideias', 'teste', 12000, 1800, 3, 0.0912), ('" + WS + "', 't146 leitura', 'teste', 50000, 900, 0, null)")
try: como("select ia_custos('2020-01-01', '2030-01-01')"); chk(False, 'quem não está na lista não vê custos')
except Exception as e: chk('Só quem a Mathisa indicou' in str(e), 'quem não está na lista (nem a equipe interna) não vê custos')
chk(sql("select has_table_privilege('authenticated', 'ia_uso', 'select')") == 'f', 'ninguém lê a tabela de uso direto')

# ---------- telas ----------
AG = sql("insert into workspaces (nome, agencia) values ('T146 Agência', true) returning id").split('\n')[0]
sql(f"insert into workspace_membros (workspace_id, user_id, papel) values ('{AG}', '{front.UID}', 'admin')")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    # equipe interna sem estar na lista de custos
    ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    pg.evaluate("abreMenu('cfg-estruturas'); render()"); pg.wait_for_timeout(1500)
    nav = pg.inner_text('#nav')
    chk('Estruturas de roteiro e copy' in nav and 'Custos de IA' not in nav, 'equipe interna vê a biblioteca; Custos de IA só para a lista')
    front.vai(pg, 'cfg-custos', '', 2500)
    chk(pg.locator('#main h1', has_text='Custos de IA').count() == 0 and pg.locator('#cuF').count() == 0, 'abrir Custos de IA pelo endereço é barrado')
    t = front.vai(pg, 'cfg-estruturas', '', 3000)
    chk(pg.locator('.es-card').count() == 7 and 'AIDA' in t and 'Só a equipe' not in t, 'biblioteca: 7 estruturas')
    pg.screenshot(path=SHOT + '1_biblioteca.png', full_page=False)
    pg.click('#esNova'); pg.wait_for_timeout(800)
    pg.fill('#modalRoot [name=nome]', 'T146 Método MIRA'); pg.fill('#modalRoot [name=para_que]', 'Estrutura própria da Mathisa.')
    pg.check('#modalRoot [name=f_reels]'); pg.fill('#modalRoot [data-etn]', 'Gancho'); pg.fill('#modalRoot [data-eti2]', 'Abrir com a dor.')
    pg.click('#esEtAdd'); pg.fill('#modalRoot .es-etl >> nth=1 >> [data-etn]', 'Virada'); pg.fill('#modalRoot .es-etl >> nth=1 >> [data-eti2]', 'Mostrar o mecanismo.')
    pg.click('#modalRoot .es-etl >> nth=1 >> [data-etc]')
    pg.screenshot(path=SHOT + '2_nova.png')
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk(sql("select formatos::text || '|' || (etapas->0->>'nome') from content_estruturas where nome = 'T146 Método MIRA'") == '{reels}|Virada', 'nova estrutura salva com formatos e etapas na ordem escolhida')
    pg.click('.es-card:has-text("T146 Método MIRA") [data-esa]'); pg.wait_for_timeout(2000)
    chk(sql("select ativo from workspaces w, content_estruturas e where e.nome = 'T146 Método MIRA' limit 1") == 'f', 'desativar some das opções do cliente')
    # aba Estruturas do módulo
    sql(f"update workspaces set content_setup_em = now(), content_ativo = true where id = '{WS}'")
    front.vai(pg, 'mkt-cont', "S.ct = { tab: 'estruturas' };", 3500)
    t = pg.inner_text('#main')
    chk('Estruturas de roteiro e copy' in t and 'T146 Método MIRA' not in t and 'Abrir com a dor' not in t and pg.locator('.es-fsf').count() == 6, 'aba Estruturas: escolha por formato, sem a receita e sem as desativadas')
    chk(pg.locator(f'[data-eo="{aida["id"]}"][data-ef="email"]').is_checked(), 'mostra o que o cliente já escolheu')
    pg.check(f'[data-eo="{aida["id"]}"][data-ef="carrossel"]'); pg.click('.es-esc button[type=submit]'); pg.wait_for_timeout(2000)
    chk(sql(f"select count(*) from content_estruturas_ws where workspace_id = '{WS}'") == '3', 'salvar as escolhas')
    pg.screenshot(path=SHOT + '3_cliente.png')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    ctx.close()
    # na lista de custos
    sql("update sistema_config set valor = 'outra@x.com, Auditoria@EscolaAurora.com.br' where chave = 'custos_emails'")
    ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    pg.evaluate("abreMenu('cfg-custos'); render()"); pg.wait_for_timeout(1500)
    chk('Custos de IA' in pg.inner_text('#nav'), 'quem está na lista vê Custos de IA no menu')
    t = front.vai(pg, 'cfg-custos', '', 3000)
    chk('US$ 0,0912' in t and '62.000' in t and 'Informe o câmbio' in t, 'custos por cliente e mês, sem inventar câmbio ' + t[:0])
    pg.fill('#cuF [name=cambio]', '5.4'); pg.click('#cuCb'); pg.wait_for_timeout(2500)
    t = pg.inner_text('#main').replace('\xa0', ' ')
    chk(sql("select valor from sistema_config where chave = 'cambio_usd_brl'") == '5.4' and 'R$ 0,49' in t, 'câmbio salvo e custo em reais')
    chk('1 sem custo calculado' in t, 'chamada sem custo calculado aparece como tal')
    pg.screenshot(path=SHOT + '4_custos.png')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
sql(f"update workspaces set content_setup_em = null, content_ativo = false where id = '{WS}'")
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
