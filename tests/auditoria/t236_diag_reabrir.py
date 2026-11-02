"""v0.236: o link do formulário fica sempre no diagnóstico (também depois que o cliente responde) e dá para reabrir o formulário.
Banco: reabrir volta o link a aceitar respostas, com prazo de pelo menos 30 dias e o rascunho guardado; a resposta anterior continua até chegar
a nova; a nova passa a ser a do diagnóstico e fica registrado "enviou de novo". Tela: antes de responder, o link aparece; depois de responder,
o link continua, com "Reabrir para o cliente continuar"; reaberto, aparece o aviso.
Banco fa (Escola Aurora, marcada como agência durante o teste). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
EU = '00000000-0000-0000-0000-00000000a0a0'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots236/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def eu(q): return sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"{EU}\",\"role\":\"authenticated\"}}', true); " + q).split('\n')[-1]
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T236%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T236%')"
    sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in {sub})")
    for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where id in {sub}")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T236%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
F = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', 'T236 Diag', 'diagnostico', 'cliente', true) returning id")
P = one(f"insert into pessoas (workspace_id, nome, telefone) values ('{WS}', 'Cliente T236', '31988887777') returning id")
D = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T236 Diag', '{P}') returning id")
r = json.loads(eu(f"select diagnostico_formulario('{D}', '{F}')::text")); E = r['envio_id']; TOK = r['token']
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    abre = lambda: (front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'form';", 4500), pg.wait_for_selector('#dgFLk', state='attached', timeout=15000))
    abre()
    chk(TOK in (pg.text_content('#dgFLk') or '') and pg.locator('#dgFWa').count() == 1, 'antes de responder: o link do cliente aparece, com WhatsApp e copiar')
    # cliente responde (com rascunho guardado)
    sql(f"update pesquisa_envios set status = 'enviado', enviado_em = now(), rascunho = '{{\"passo\": 1}}', rascunho_em = now(), expira_em = now() + interval '2 days' where id = '{E}'")
    R1 = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{F}', '{E}', '{P}') returning id")
    sql(f"update pesquisa_envios set status = 'respondido', respondido_em = now() where id = '{E}'")
    chk(sql(f"select resposta_id from diagnosticos where id = '{D}'") == R1, 'a resposta entra no diagnóstico')
    abre()
    chk(TOK in (pg.text_content('#dgFLk') or '') and pg.locator('#dgFReabre').count() == 1, 'depois de responder: o link continua e aparece "Reabrir para o cliente continuar"')
    pg.screenshot(path=SHOT + '1_respondido_com_link.png')
    pg.click('#dgFReabre'); pg.wait_for_timeout(400); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    e = sql(f"select status || '|' || (respondido_em is null) || '|' || (expira_em > now() + interval '29 days') || '|' || (rascunho is not null) from pesquisa_envios where id = '{E}'")
    chk(e == 'enviado|true|true|true', 'reabrir: o link volta a aceitar respostas, vale 30 dias e guarda o que o cliente preencheu', e)
    chk(sql(f"select resposta_id from diagnosticos where id = '{D}'") == R1, 'a resposta anterior continua no diagnóstico até chegar a nova')
    abre()
    chk('Formulário reaberto' in (pg.text_content('#main') or '') and pg.locator('#dgFReabre').count() == 0, 'reaberto: a tela avisa e o botão some')
    pg.screenshot(path=SHOT + '2_reaberto.png')
    errs = list(pg.errs); ctx.close(); b.close()
R2 = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{F}', '{E}', '{P}') returning id")
chk(sql(f"select resposta_id from diagnosticos where id = '{D}'") == R2, 'quando o cliente envia de novo, a resposta nova passa a valer')
chk(sql(f"select count(*) from diagnostico_decisoes where diagnostico_id = '{D}' and texto = 'O cliente enviou o formulário de novo'") == '1', 'fica registrado que o cliente enviou de novo')
chk(not errs, 'sem erros de JavaScript', errs)
sql(f"delete from diagnostico_decisoes where diagnostico_id = '{D}'")
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
