"""v0.225: Diagnóstico Inteligente — de-para das métricas (o que o cliente usa × o que os dados que ele mandou permitem calcular),
pergunta dos principais no formulário, e o formulário do cliente só conclui com cada grupo de arquivos enviado ou "Não tenho".
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots225/'; os.makedirs(SHOT, exist_ok=True)
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
NOMES = ('T225 diag', 'T225 entrada', 'T225 link')
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't225%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T225%'")
    for nm in NOMES:
        sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome = '{nm}')"
        sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in {sub})")
        for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
        sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = '{nm}'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")  # v0.228: o diagnóstico de clientes é só da agência
CATS = json.dumps({'categorias': [{'k': 'vendas', 'l': 'Vendas e pedidos'}, {'k': 'crm', 'l': 'CRM e leads'}, {'k': 'alunos', 'l': 'Alunos e clientes'},
  {'k': 'marketing', 'l': 'Marketing e aquisição'}, {'k': 'financeiro', 'l': 'Financeiro'}], 'upload': True})
PE = one(f"select id from pessoas where workspace_id = '{WS}' order by criado_em limit 1")
def formulario(nome, perguntas):
    pq = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', '{nome}', 'diagnostico', 'cliente', true) returning id")
    ids = [one(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, config, obrigatoria) values ('{WS}', '{pq}', {i + 1}, '{t}', '{tp}', '{{{",".join('"' + o + '"' for o in op)}}}', '{cfg}', true) returning id") for i, (t, tp, op, cfg) in enumerate(perguntas)]
    ev = one(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{pq}', '{PE}') returning id")
    return pq, ids, ev
# ---------- diagnóstico com o formulário 360° (pergunta de métricas) ----------
PQ, (QM, QD), EV = formulario('T225 diag', [('O que acompanha', 'metricas', [], '{}'), ('Seus arquivos', 'documentos', [], CATS)])
RS = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{PQ}', '{EV}', '{PE}') returning id")
sql(f"""insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_json) values
  ('{WS}', '{RS}', '{QD}', '{{"vendas":"sim","crm":"nao","marketing":"sim","financeiro":"nao"}}'),
  ('{WS}', '{RS}', '{QM}', '{{"receita":{{"status":"regular","como":["Planilha"],"decide":true}},"cac":{{"status":"regular","como":["Painel ou dashboard"]}},"leads":{{"status":"nao"}},"ltv":{{"status":"nao_sei"}}}}')""")
D = one(f"insert into diagnosticos (workspace_id, titulo, resposta_id, periodo_ini, periodo_fim) values ('{WS}', 'T225 De-para', '{RS}', '2026-04-01', '2026-09-30') returning id")
for g, nm in [('vendas', 't225 vendas.csv'), ('marketing', 't225 anuncios.csv')]:
    sql(f"insert into pesquisa_arquivos (workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, status, enviado_em, periodo_ini, periodo_fim) values ('{WS}', '{EV}', '{PQ}', '{PE}', '{g}', '{nm}', '{WS}/{EV}/{nm}', 10, 'enviado', now(), '2026-01-01', '2026-10-31')")
dp = lambda d: {x['codigo']: x for x in J(f"diagnostico_depara('{d}', '2026-11-02')")['metricas']}
M = dp(D)
chk(M['receita']['uso'] == 'principal' and M['receita']['categoria'] == 'usa' and M['receita']['onde'] == ['Planilha'], 'receita: principal (marcada no formulário), com onde vê', M['receita'])
chk(M['ltv']['uso'] == 'nao_sei' and M['ltv']['categoria'] == 'oportunidade' and M['ltv']['dados'] == 'ressalvas' and any('identificação do comprador' in r for r in M['ltv']['ressalvas']), 'sem leitura das planilhas: LTV dá, com ressalva de confirmar a identificação do comprador', M['ltv'])
sql(f"""update diagnosticos set leitura = '{{"score":70,"lido_em":"2026-11-02T10:00:00Z","itens":[{{"id":"vendas","titulo":"Vendas com data, valor e produto","status":"ok"}},
  {{"id":"cliente","titulo":"Identificação do comprador","status":"ok"}},{{"id":"produto","titulo":"Produto em cada venda","status":"ok"}},{{"id":"status","titulo":"Status do pagamento","status":"ok"}},
  {{"id":"recorrencia","titulo":"Recompra, renovação e upgrade","status":"parcial"}},{{"id":"leads","titulo":"Leads com data e origem","status":"falta"}},{{"id":"origemvenda","titulo":"Origem de cada venda (canal)","status":"falta"}},
  {{"id":"midia","titulo":"Investimento em mídia por mês e canal","status":"ok"}},{{"titulo":"Topo do funil (impressões, cliques, visitas na página)","status":"falta"}},{{"id":"qualificacao","titulo":"Qualificação dos leads","status":"falta"}}]}}' where id = '{D}'""")
sql(f"insert into diagnostico_metricas (workspace_id, diagnostico_id, codigo, detalhe) values ('{WS}', '{D}', 'receita', '{{\"numerador\":\"vendas aprovadas\",\"fonte\":\"Hotmart\"}}')")
R = J(f"diagnostico_depara('{D}', '2026-11-02')"); M = {x['codigo']: x for x in R['metricas']}
chk(M['receita']['calculo_descrito'] and M['receita']['dados'] == 'sim', 'receita: cálculo descrito na reunião e dá para conferir com os dados')
chk(M['cac']['uso'] == 'acompanha' and not M['cac']['calculo_descrito'] and M['cac']['dados'] == 'nao' and 'custos ou financeiro' in M['cac']['falta'], 'CAC: acompanha, falta entender o cálculo e falta o financeiro para conferir', M['cac'])
chk(M['leads']['uso'] == 'nao' and M['leads']['categoria'] == 'lacuna' and 'planilha de leads' in M['leads']['falta'], 'leads: não acompanha e não mandou (lacuna)', M['leads'])
chk(M['ltv']['categoria'] == 'oportunidade' and M['ltv']['dados'] == 'sim', 'LTV: hoje não sabe, mas os dados permitem calcular (oportunidade)', M['ltv'])
chk(M['roas']['dados'] == 'sim' and M['roas']['uso'] is None and M['roas']['categoria'] == 'oportunidade', 'ROAS: não foi marcado, vendas + anúncios lidos = dá para calcular')
chk(M['mrr']['dados'] == 'ressalvas' and M['mrr']['categoria'] == 'oportunidade' and M['mrr']['modelos'], 'MRR: recorrência em parte = com ressalvas, e marcado como de assinatura')
chk(M['ctr']['dados'] == 'nao' and 'impressões, cliques e visitas' in M['ctr']['falta'], 'leitura antiga sem id (pelo título): topo do funil faltando tira o CTR', M['ctr'])
chk(M['promotores']['dados'] == 'externo' and M['promotores']['categoria'] == 'lacuna', 'NPS: fonte fora dos arquivos (pesquisa)')
chk(M['churn']['dados'] == 'nao' and 'lista de alunos ou clientes' in M['churn']['falta'], 'churn: falta a lista de alunos')
chk(R['resumo']['principais'] == 1 and R['resumo']['usa'] == 2 and R['resumo']['sem_calculo'] == 1 and R['resumo']['usa_sem_dado'] == 1, 'resumo: 2 usa (1 principal), 1 sem cálculo descrito, 1 usa sem o dado', R['resumo'])
# ---------- Entrada do cliente (múltipla escolha + principais) ----------
OPS = ['Faturamento', 'Leads', 'Custo de aquisição (CAC)']
PQ2, (QA, QP), EV2 = formulario('T225 entrada', [('Quais números você acompanha hoje no seu negócio? (marque todos)', 'multipla', OPS, '{}'), ('Desses, quais são os principais, os que você mais olha para decidir? (até 5)', 'multipla', OPS, '{}')])
RS2 = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{PQ2}', '{EV2}', '{PE}') returning id")
sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{RS2}', '{QA}', 'Faturamento'), ('{WS}', '{RS2}', '{QA}', 'Leads'), ('{WS}', '{RS2}', '{QP}', 'Faturamento')")
D2 = one(f"insert into diagnosticos (workspace_id, titulo, resposta_id) values ('{WS}', 'T225 Entrada', '{RS2}') returning id")
M2 = dp(D2)
chk(M2['receita']['uso'] == 'principal' and M2['leads']['uso'] == 'acompanha' and M2['cac']['uso'] == 'nao', 'Entrada do cliente: "Faturamento" principal, "Leads" acompanha, o que não marcou = não acompanha', (M2['receita']['uso'], M2['leads']['uso'], M2['cac']['uso']))
D3 = one(f"insert into diagnosticos (workspace_id, titulo) values ('{WS}', 'T225 Sem formulário') returning id")
R3 = J(f"diagnostico_depara('{D3}', '2026-11-02')")
chk(not R3['formulario'] and all(x['uso'] is None for x in R3['metricas']) and R3['resumo']['usa'] == 0, 'sem formulário: ninguém "usa", o de-para mostra só o que os dados permitem')
# ---------- formulário do cliente (link) ----------
PQ3, (QM3, QD3), EV3 = formulario('T225 link', [('O que você acompanha hoje', 'metricas', [], json.dumps({'simples': True, 'codigos': ['receita', 'cac']})),
  ('Seus arquivos', 'documentos', [], json.dumps({'categorias': [{'k': 'vendas', 'l': 'Vendas e pedidos'}, {'k': 'crm', 'l': 'CRM e leads'}], 'upload': True}))])
TOK = one(f"select token from pesquisa_envios where id = '{EV3}'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'met'; S.abas.dgm = 'usa';", 5000)
    t = pg.inner_text('#main')
    ab = pg.inner_text('.dg-dp [data-abas="dgm"]').replace('\n', ' ')
    chk('De-para das métricas' in t and pg.locator('[data-abas="dg"] [data-aba-k]').count() == 8 and 'Usa hoje 2' in ab and 'Dá para calcular e não olha' in ab and 'Não dá com o que veio' in ab, 'aba Métricas: o de-para em três abas com as contagens', ab)
    chk(pg.inner_text('[data-abas="dg"] [data-aba-k="met"]').strip().endswith('1'), 'a aba Métricas mostra quantas métricas usadas falta entender como calcula (1)')
    chk('Receita' in t and 'Taxa de recompra' not in t, 'na aba "Usa hoje" só aparece o que ele usa')
    front.aba(pg, 'op', 500); t = pg.inner_text('#main')
    chk('Taxa de recompra' in t and 'Perguntar na reunião' not in t, 'a aba "Dá para calcular e não olha" troca o conteúdo')
    chk('Descrito na reunião' in pg.inner_text('tr[data-dpm="receita"]') and 'Perguntar na reunião' in pg.inner_text('tr[data-dpm="cac"]') and 'falta custos ou financeiro' in pg.inner_text('tr[data-dpm="cac"]'), 'tabela do que usa: cálculo descrito ou a perguntar, e o que falta para conferir')
    chk(pg.locator('.dg-dp tr[data-dpm="ltv"]').count() == 1 and pg.locator('[data-aba-p="la"] tr[data-dpm="leads"]').count() == 1, 'LTV em "dá para calcular e não olha"; leads em "não dá com o que veio"')
    front.aba(pg, 'reu', 500)
    conv = pg.inner_text('.dg-conv')
    chk('Como vocês calculam CAC?' in conv and 'Usa CAC, mas não mandou o dado' in conv and 'Dá para calcular e hoje não olha:' in conv and 'ROAS' in conv, 'para conversar na reunião: como calcula, o que usa sem dado e as oportunidades', conv)
    front.aba(pg, 'met', 400); front.aba(pg, 'usa', 400)
    pg.screenshot(path=SHOT + '1_depara.png', full_page=True)
    errs = list(pg.errs)
    pg2 = ctx.new_page(); pg2.errs = []; pg2.on('pageerror', lambda e: pg2.errs.append(str(e)))
    pg2.goto('file://' + front.SPD + 'audit.html?pesquisa=' + TOK); pg2.wait_for_timeout(5000)
    body = pg2.inner_text('body')
    chk('Mando depois' not in body and body.count('Não tenho') >= 2, 'formulário do diagnóstico: sem "Mando depois" (envia o arquivo ou marca "Não tenho")', body[:300])
    chk('Ainda falta: Vendas e pedidos, CRM e leads' in pg2.inner_text('.pf-dfalta'), 'lista do que ainda falta nos arquivos', pg2.inner_text('body')[-500:])
    pg2.locator('.pf-m[data-m="receita"] input[value="regular"]').check(); pg2.wait_for_timeout(400)
    chk(pg2.locator('.pf-m[data-m="receita"] [data-c="decide"]').is_visible() and 'principais' in pg2.inner_text('.pf-m[data-m="receita"] .pf-md'), 'ao marcar que acompanha, aparece "é um dos principais"')
    for g in ['vendas', 'crm']: pg2.locator(f'.pf-doc[data-g="{g}"] input[value="nao"]').check()
    pg2.wait_for_timeout(600)
    chk('Tudo certo com os arquivos' in pg2.inner_text('.pf-dfalta'), 'com cada grupo resolvido, a lista avisa que já pode concluir')
    pg2.screenshot(path=SHOT + '2_formulario.png', full_page=True)
    errs += pg2.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
