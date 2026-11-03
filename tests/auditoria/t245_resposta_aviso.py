"""v0.245: aviso de formulário respondido para toda a equipe (faixa verde no topo, Meus avisos e WhatsApp na fila).
Banco: lead que responde o formulário de captação pelo link aberto gera os dois avisos (lead novo e "respondeu o formulário"), com a pontuação
e as faixas da qualificação; resposta de diagnóstico aponta para o diagnóstico; resposta sem cadastro usa o e-mail; quem desligou não recebe.
Tela: a faixa verde mostra "… respondeu o formulário"; em Equipe aparece a opção "Avisar quando alguém responder um formulário".
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots245/'; os.makedirs(SHOT, exist_ok=True)
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
    sql(f"delete from notificacoes where workspace_id = '{WS}' and (destinatario_id in (select id from equipe where workspace_id = '{WS}' and nome like 'T245%') or titulo like '%T245%')")
    sql(f"set session_replication_role = replica; delete from equipe where workspace_id = '{WS}' and nome like 'T245%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T245%')"
    for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where id in {sub}"); sql(f"delete from pessoas where workspace_id = '{WS}' and nome like '%T245%'")
limpa()
EU = one(f"set session_replication_role = replica; insert into equipe (workspace_id, nome, email, ativo, avisar_app, avisar_email, avisar_whatsapp, telefone) values ('{WS}', 'T245 Eu', 'auditoria@escolaaurora.com.br', true, true, false, true, '5531988887777') returning id")
DESL = one(f"set session_replication_role = replica; insert into equipe (workspace_id, nome, ativo, avisar_app, avisar_email, avisar_whatsapp, avisar_resposta) values ('{WS}', 'T245 Desligou', true, true, false, false, false) returning id")
CAP = json.dumps({'ativa': True, 'destino': 'lead', 'campos': {'nome': {'mostrar': True}, 'email': {'mostrar': True}}, 'consentimentos': []})
P = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, aceita_link_aberto, captacao) values ('{WS}', 'T245 Qualificação', 'lead', 'lead', true, true, '{CAP}') returning id")
Q = one(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria) values ('{WS}', '{P}', 1, 'Qual o seu objetivo?', 'texto', false) returning id")
TOK = sql(f"select token_aberto from pesquisas where id = '{P}'")
# 1) lead real pelo link aberto (mesma função que o formulário público usa)
sql(f"select pesquisa_captar('{TOK}', '{{\"{Q}\": \"Vender mais\"}}'::jsonb, '{{\"nome\": \"Ana T245\", \"email\": \"ana@t245.com\"}}'::jsonb, '{{}}'::jsonb)")
L = one(f"select id from pessoas where workspace_id = '{WS}' and nome = 'Ana T245'")
r = sql(f"select canal || '|' || titulo || '|' || coalesce(mensagem, '') from notificacoes where destinatario_id = '{EU}' and pessoa_id = '{L}' order by titulo, canal")
chk('Novo lead: Ana T245' in r and 'app|Ana T245 respondeu o formulário|"T245 Qualificação"' in r, 'lead pelo link aberto: chegam os dois avisos (lead novo e respondeu o formulário)', r)
chk('whatsapp|Ana T245 respondeu o formulário' in r, 'o aviso de resposta vai para a fila do WhatsApp de quem tem WhatsApp ligado', r)
chk(sql(f"select count(*) from notificacoes where destinatario_id = '{DESL}' and titulo like '%respondeu o formulário'") == '0', 'quem desligou "formulário respondido" não recebe')
# 2) pontuação e faixas (gravadas na mesma transação, antes do aviso sair)
P2 = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', 'Bia T245') returning id")
sql(f"begin; insert into pesquisa_respostas (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{P}', '{P2}'); update pesquisa_respostas set qualif_det = '{{\"total\": 71.4, \"grupos\": {{\"Produto\": \"strategy\", \"Temperatura\": \"quente\"}}}}' where pessoa_id = '{P2}'; commit;")
m = sql(f"select mensagem from notificacoes where destinatario_id = '{EU}' and pessoa_id = '{P2}' and canal = 'app' and titulo like '%respondeu%'")
chk(m == '"T245 Qualificação" · 71 pontos · Produto: strategy · Temperatura: quente. Abra a ficha para ver as respostas.', 'a mensagem traz a pontuação e as faixas da qualificação', m)
# 3) diagnóstico e resposta sem cadastro
D = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', 'T245 Diagnóstico', 'diagnostico', 'cliente', true) returning id")
sql(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, email) values ('{WS}', '{D}', 'cliente@t245.com')")
m = sql(f"select titulo || '|' || mensagem from notificacoes where destinatario_id = '{EU}' and canal = 'app' and mensagem like '%T245 Diagnóstico%'")
chk(m == 'cliente@t245.com respondeu o formulário|"T245 Diagnóstico". Abra o diagnóstico para ver as respostas.', 'diagnóstico respondido: aponta para o diagnóstico; sem cadastro, usa o e-mail', m)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'painel', '', 4000)
    pg.evaluate("() => atualizaSino()"); pg.wait_for_timeout(2500)
    t = pg.text_content('#leadFaixa') if pg.locator('#leadFaixa').count() else ''
    chk('respondeu o formulário' in (t or '') or 'Novo lead' in (t or ''), 'a faixa verde aparece com o aviso', t)
    chk(pg.evaluate("() => ehAvisoLead({ titulo: 'Ana respondeu o formulário' })"), 'a faixa verde reconhece o aviso de formulário respondido')
    pg.screenshot(path=SHOT + '1_faixa.png')
    front.vai(pg, 'equipe', '', 3500)
    pg.locator('#main button', has_text='Nova pessoa').first.click() if pg.locator('#main button', has_text='Nova pessoa').count() else None
    pg.wait_for_timeout(1200)
    tx = pg.text_content('body') or ''
    chk('Avisar quando alguém responder um formulário' in tx, 'em Equipe aparece a opção "Avisar quando alguém responder um formulário"')
    pg.screenshot(path=SHOT + '2_equipe.png')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
