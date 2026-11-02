"""v0.224: Diagnóstico Inteligente D2 (parte 1) — o pré-diagnóstico, antes da reunião.
Banco: checklist cruza o que o cliente disse (formulário) com o que chegou nas evidências (do cliente e da equipe) e com os meses do
período de referência; grupo condicional que o cliente não viu fica de fora; números que acompanha e não acompanha; etapa nova no
progresso. Tela: aba Investigação com o checklist, a mensagem do que falta (editável e guardada), o que conversar, marcar como revisado
(histórico e progresso), número na aba, diagnóstico sem formulário, celular. Banco fa (Escola Aurora). Cria os dados e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots224/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
J = lambda q: json.loads(sql(CL + q).split('|', 1)[1])
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't224%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T224%'")
    for t in ['pesquisa_resposta_itens', 'pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']:
        sql(f"delete from {t} where workspace_id = '{WS}' and pesquisa_id in (select id from pesquisas where workspace_id = '{WS}' and nome = 'T224 diag')") if t != 'pesquisa_resposta_itens' else \
        sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in (select id from pesquisas where workspace_id = '{WS}' and nome = 'T224 diag'))")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = 'T224 diag'")
limpa()
CATS = json.dumps({'categorias': [{'k': 'vendas_hotmart', 'l': 'Vendas da Hotmart', 'se': ['Hotmart']}, {'k': 'vendas', 'l': 'Vendas e pedidos'}, {'k': 'crm', 'l': 'CRM e leads'},
  {'k': 'alunos', 'l': 'Alunos e clientes'}, {'k': 'marketing', 'l': 'Marketing e aquisição'}, {'k': 'financeiro', 'l': 'Financeiro'}, {'k': 'produtos', 'l': 'Produtos e ofertas'},
  {'k': 'complementares', 'l': 'Arquivos complementares'}], 'upload': True})
PE = one(f"select id from pessoas where workspace_id = '{WS}' order by criado_em limit 1")
PQ = one(f"insert into pesquisas (workspace_id, nome, tipo, publico) values ('{WS}', 'T224 diag', 'diagnostico', 'cliente') returning id")
QM = one(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, config) values ('{WS}', '{PQ}', 1, 'O que acompanha', 'metricas', '{{}}') returning id")
QD = one(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, config) values ('{WS}', '{PQ}', 2, 'Seus arquivos', 'documentos', '{CATS}') returning id")
EV = one(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{PQ}', '{PE}') returning id")
RS = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{PQ}', '{EV}', '{PE}') returning id")
sql(f"""insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_json) values
  ('{WS}', '{RS}', '{QD}', '{{"vendas":"sim","crm":"nao","marketing":"depois","financeiro":"sim"}}'),
  ('{WS}', '{RS}', '{QM}', '{{"faturamento":{{"status":"regular","como":["Planilha"]}},"cac":{{"status":"nao"}}}}')""")
D = one(f"insert into diagnosticos (workspace_id, titulo, resposta_id, periodo_ini, periodo_fim) values ('{WS}', 'T224 Pré', '{RS}', '2026-04-01', '2026-09-30') returning id")
# vendas do cliente cobrindo 3 dos 6 meses; financeiro da equipe cobrindo tudo; oferta da equipe sem período
sql(f"insert into pesquisa_arquivos (workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, status, enviado_em, periodo_ini, periodo_fim) values ('{WS}', '{EV}', '{PQ}', '{PE}', 'vendas', 't224 vendas.csv', '{WS}/{EV}/t224a.csv', 10, 'enviado', now(), '2026-07-01', '2026-09-30')")
sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em, classe, classe_origem, periodo_ini, periodo_fim) values ('{WS}', '{D}', 'equipe', 'equipe', 't224 dre.pdf', '{WS}/diag/{D}/t224b.pdf', 10, 'enviado', now(), 'financeiro', 'manual', '2026-01-01', '2026-12-31')")
sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em, classe, classe_origem) values ('{WS}', '{D}', 'equipe', 'equipe', 't224 ofertas.pdf', '{WS}/diag/{D}/t224c.pdf', 10, 'enviado', now(), 'oferta', 'manual')")
sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em, classe, classe_origem, arquivado_em) values ('{WS}', '{D}', 'equipe', 'equipe', 't224 alunos velho.csv', '{WS}/diag/{D}/t224d.csv', 10, 'enviado', now(), 'cs', 'manual', now())")
CK = J(f"diagnostico_checklist('{D}', '2026-11-02')")
st = {x['k']: x for x in CK['itens']}
chk('vendas_hotmart' not in st, 'grupo condicional que o cliente não viu (Hotmart) fica de fora', list(st))
chk(st['vendas']['status'] == 'parcial' and st['vendas']['meses_cobertos'] == 3 and st['vendas']['meses_ref'] == 6, 'vendas cobrindo 3 de 6 meses = recebido em parte', st['vendas'])
chk(st['financeiro']['status'] == 'recebido' and st['financeiro']['declarado'] == 'sim', 'financeiro mandado pela equipe (classificação) = recebido, e o cliente disse "tenho"')
chk(st['produtos']['status'] == 'recebido' and st['produtos']['sem_periodo'] == 1, 'oferta sem período conta como recebida, avisando que falta o período')
chk(st['marketing']['status'] == 'prometido', 'disse "mando depois" e não mandou = prometido')
chk(st['crm']['status'] == 'nao_tem', 'disse "não tenho" = não tem (lacuna, não pedido)')
chk(st['alunos']['status'] == 'falta', 'arquivo arquivado não conta: alunos continua faltando')
chk(st['complementares']['status'] == 'opcional', 'complementares sem nada = opcional')
chk(CK['resumo'] == {'recebidos': 2, 'parciais': 1, 'prometidos': 1, 'nao_tem': 1, 'faltam': 1}, 'resumo do checklist', CK['resumo'])
chk([x['codigo'] for x in CK['numeros']['acompanha']] == ['faturamento'] and [x['codigo'] for x in CK['numeros']['nao_acompanha']] == ['cac'], 'números: acompanha faturamento, não acompanha CAC')
P = J(f"diagnostico_progresso('{D}')"); et = {e['k']: e['ok'] for e in P['etapas']}
chk(P['total'] == 8 and et['pre'] is False, 'progresso ganha a etapa do pré-diagnóstico (ainda pendente)')
D0 = one(f"insert into diagnosticos (workspace_id, titulo) values ('{WS}', 'T224 Sem formulário') returning id")
C0 = J(f"diagnostico_checklist('{D0}', '2026-11-02')")
chk(not C0['formulario'] and len(C0['itens']) == 7 and C0['ref_ini'] == '2026-05-01' and C0['ref_fim'] == '2026-10-31', 'sem formulário: grupos padrão e os últimos 6 meses completos', (C0['ref_ini'], C0['ref_fim'], len(C0['itens'])))
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'evid';", 4500)
    chk(pg.inner_text('[data-abas="dg"] [data-aba-k="ck"]').strip().endswith('3'), 'a aba "O que falta" mostra quantos itens faltam, foram prometidos ou chegaram em parte (3)', pg.inner_text('[data-abas="dg"] [data-aba-k="ck"]'))
    front.aba(pg, 'ck', 600)
    t = pg.inner_text('#main')
    tck = t
    chk('Pré-diagnóstico' in t and 'Recebido em parte' in t and 'Disse que tem, não mandou' in t and 'Não tem' in t and 'Falta' in t and '3 de 6 meses' in t, 'checklist na tela com as situações e a cobertura', t[t.find('Pré-diagnóstico'):][:700])
    front.aba(pg, 'reu', 600); t = pg.inner_text('#main')
    chk('Recebido em parte' not in t and 'Pedir ao cliente' in t, 'a aba "Preparar a reunião" mostra só o pedido e a pauta (o checklist fica na aba dele)')
    msg = pg.input_value('#dgPreMsg')
    chk('Marketing e aquisição: você comentou que tem' in msg and 'recebemos 3 de 6 meses' in msg and 'Alunos e clientes: você tem esse arquivo?' in msg and 'CRM' not in msg, 'mensagem pede o prometido, o restante dos meses e o que falta (não pede o que o cliente disse que não tem)', msg)
    chk('Não acompanha CAC' in t and 'CRM e leads: não tem' in t, 'para conversar na reunião: o que não tem e os números que não acompanha')
    chk('1 arquivo(s) sem o período' in tck, 'aviso dos arquivos sem período')
    pg.screenshot(path=SHOT + '1_pre_diagnostico.png', full_page=True)
    pg.fill('#dgPreMsg', msg + '\nAbraço, equipe Mathisa'); pg.wait_for_timeout(2500)
    chk('Abraço, equipe Mathisa' in sql(f"select arquitetura -> 'pre' ->> 'mensagem' from diagnosticos where id = '{D}'"), 'a mensagem editada fica guardada no diagnóstico')
    pg.click('#dgPreOk'); pg.wait_for_timeout(3500)
    t = pg.inner_text('#main')
    chk('Pré-diagnóstico revisado em' in t and pg.locator('#dgReu.pri').count() == 1, 'marcar como revisado: aparece a data e a reunião vira o próximo passo')
    chk(sql(f"select count(*) from diagnostico_decisoes where diagnostico_id = '{D}' and texto like 'Pré-diagnóstico revisado: 2 recebido(s), 1 em parte, 1 prometido(s), 1 faltando, 1 não tem.'") == '1', 'a revisão entra no histórico com o resumo')
    chk('✓ Pré-diagnóstico revisado' in t and 'Abraço, equipe Mathisa' in pg.input_value('#dgPreMsg'), 'progresso marca a etapa e a mensagem editada continua')
    pg.click('#dgPreRefaz'); pg.wait_for_timeout(3000)
    chk('Abraço' not in pg.input_value('#dgPreMsg'), '"Montar de novo" volta para a mensagem com o que falta agora')
    pg.click('#dgPreDesfaz'); pg.wait_for_timeout(3000)
    chk(pg.locator('#dgPreOk').count() == 1, '"Revisar de novo" reabre o pré-diagnóstico')
    pg.click('#dgReu'); pg.wait_for_timeout(4000)
    chk('Reunião do diagnóstico' in pg.inner_text('#main'), 'o botão leva para a reunião')
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D0}'; S.abas.dg = 'ck';", 4000)
    t = pg.inner_text('#main'); front.aba(pg, 'reu', 500); t2 = pg.inner_text('#main')
    chk('Sem formulário ligado' in t and 'Enviar o formulário' in t2, 'sem formulário: o checklist avisa e oferece enviar o formulário')
    errs = list(pg.errs); ctx.close()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=390, vh=844)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'inv';", 4500)
    chk(pg.locator('[data-abas="dg"] [data-aba-k="ck"]').get_attribute('aria-selected') == 'true', 'aba antiga "Investigação" guardada na sessão abre em "O que falta"')
    larg = pg.evaluate("document.documentElement.scrollWidth")
    chk(larg <= 392, 'no celular a página não passa da largura da tela', larg)
    pg.screenshot(path=SHOT + '2_celular.png', full_page=True)
    errs += pg.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
