"""v0.228: Diagnóstico de clientes da Mathisa — começa pelo cliente e pelo formulário.
Banco: clientes esperando (jornada na etapa Diagnóstico ou contrato ativo), formulário padrão (um por empresa), escolher o formulário gera o
link do cliente, marcar enviado, a resposta entra sozinha, arquivos do link entram ao escolher o formulário, não troca depois de respondido,
progresso com as etapas do formulário. Tela: só no workspace de agência; lista de espera; começar diagnóstico com o padrão escolhido;
aba Formulário (passos, mensagem, WhatsApp, e-mail, copiar); cliente com diagnóstico aberto; outras empresas veem a leitura de planilhas.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots228/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def erro(q):
    try: sql(q); return ''
    except Exception as e: return str(e)
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
J = lambda q: json.loads(sql(CL + q).split('|', 1)[1])
F = lambda q: sql(CL + q).split('|', 1)[1]
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and (titulo like 'T228%' or titulo like 'Diagnóstico de Cliente T228%')")
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't228%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T228%')"
    sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in {sub})")
    for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome like 'T228%'")
    sql(f"delete from alunos where workspace_id = '{WS}' and pessoa_id in (select id from pessoas where workspace_id = '{WS}' and nome like 'Cliente T228%')")
    sql(f"delete from contratos where workspace_id = '{WS}' and pessoa_id in (select id from pessoas where workspace_id = '{WS}' and nome like 'Cliente T228%')")
    sql(f"delete from etapas_kanban where workspace_id = '{WS}' and nome = 'Diagnóstico T228'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T228%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
P1 = one(f"insert into pessoas (workspace_id, nome, email, telefone) values ('{WS}', 'Cliente T228 Contrato', 'contrato.t228@exemplo.com', '11999990000') returning id")
P2 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T228 Jornada', 'jornada.t228@exemplo.com') returning id")
C1 = one(f"insert into contratos (workspace_id, pessoa_id, data_inicio, status, ativado_em) values ('{WS}', '{P1}', '2026-11-01', 'ativo', now()) returning id")
EK = one(f"insert into etapas_kanban (workspace_id, quadro, nome, ordem) values ('{WS}', 'alunos', 'Diagnóstico T228', 0) returning id")
PROD = one(f"select id from produtos where workspace_id = '{WS}' limit 1")
AL = one(f"insert into alunos (workspace_id, pessoa_id, produto_id, tag, etapa_kanban_id, status) values ('{WS}', '{P2}', '{PROD}', 't228', '{EK}', 'ativo') returning id")
sql(f"update alunos set etapa_kanban_id = '{EK}' where id = '{AL}'")
ESP = {x['pessoa_id']: x for x in J(f"diagnosticos_clientes('{WS}')")}
chk(ESP.get(P1, {}).get('origem') == 'contrato' and ESP[P1]['contrato_id'] == C1 and ESP.get(P2, {}).get('origem') == 'jornada' and ESP[P2]['aluno_id'] == AL, 'clientes esperando: o do contrato ativo e o que está na etapa Diagnóstico da jornada', (ESP.get(P1), ESP.get(P2)))
FA = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', 'T228 Padrão', 'diagnostico', 'cliente', true) returning id")
FB = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', 'T228 Outro', 'diagnostico', 'cliente', true) returning id")
F(f"diagnostico_formulario_padrao('{FB}')"); F(f"diagnostico_formulario_padrao('{FA}')")
chk(sql(f"select string_agg(nome, ',') from pesquisas where workspace_id = '{WS}' and padrao_diagnostico") == 'T228 Padrão', 'só um formulário padrão por empresa')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    t = front.vai(pg, 'gro-diag', "S.dgSel = null; S.dgSemDiag = null; S.gxDiag = null;", 4500)
    chk('Diagnóstico de clientes' in t and 'Clientes esperando diagnóstico' in t and 'Cliente T228 Contrato' in t and 'Jornada: Diagnóstico T228' in t, 'na Mathisa: a lista de clientes esperando diagnóstico', t[:500])
    pg.screenshot(path=SHOT + '1_espera.png', full_page=True)
    pg.click(f'[data-dgcomeca="{P1}"]'); pg.wait_for_timeout(1500)
    chk(pg.locator('.modal [name=pessoa]').input_value() == P1 and pg.locator('.modal [name=pesquisa]').input_value() == FA, 'começar diagnóstico: o cliente e o formulário padrão já vêm escolhidos')
    pg.click('.modal .acts .pri'); pg.wait_for_timeout(4500)
    D = one(f"select id from diagnosticos where workspace_id = '{WS}' and pessoa_id = '{P1}'")
    r = sql(f"select titulo || '|' || coalesce(contrato_id::text, '') || '|' || pesquisa_id || '|' || (envio_id is not null) from diagnosticos where id = '{D}'")
    chk(r == f"Diagnóstico de Cliente T228 Contrato|{C1}|{FA}|true", 'diagnóstico criado com o cliente, o contrato e o formulário (link do cliente gerado)', r)
    t = pg.inner_text('#main')
    chk(pg.locator('[data-abas="dg"] [data-aba-k="form"]').get_attribute('aria-selected') == 'true' and 'Formulário do cliente' in t and '✓ Formulário escolhido' in t and 'contrato.t228@exemplo.com' in t, 'abre na aba 1. Formulário, com o cliente e o formulário escolhido', t[t.find('Formulário do cliente'):][:400])
    msg = pg.input_value('#dgFMsg')
    TOK = one(f"select token from pesquisa_envios e join diagnosticos d on d.envio_id = e.id where d.id = '{D}'")
    chk('Oi, Cliente!' in msg and '?pesquisa=' + TOK in msg, 'mensagem pronta com o link individual do cliente', msg)
    chk(pg.locator('#dgFWa').count() == 1 and pg.locator('#dgFEm').count() == 1 and pg.locator('#dgFCp').count() == 1, 'botões: WhatsApp, e-mail e copiar o link')
    pg.screenshot(path=SHOT + '2_formulario.png', full_page=True)
    pg.click('#dgFCp'); pg.wait_for_timeout(3000)
    chk(sql(f"select e.status || ':' || (e.enviado_em is not null) from pesquisa_envios e join diagnosticos d on d.envio_id = e.id where d.id = '{D}'") == 'enviado:true'
        and sql(f"select count(*) from diagnostico_decisoes where diagnostico_id = '{D}' and texto = 'Formulário enviado (link copiado)'") == '1', 'copiar o link marca o formulário como enviado e registra no histórico')
    chk('✓ Enviado' in pg.inner_text('#main'), 'o passo "Enviado" fica marcado')
    pg.select_option('#dgFPesq', FB); pg.wait_for_timeout(3500)
    chk(sql(f"select pesquisa_id from diagnosticos where id = '{D}'") == FB, 'trocar o formulário antes da resposta gera o link do outro formulário')
    pg.select_option('#dgFPesq', FA); pg.wait_for_timeout(3500)
    EV = one(f"select envio_id from diagnosticos where id = '{D}'")
    sql(f"insert into pesquisa_arquivos (workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{EV}', '{FA}', '{P1}', 'vendas', 't228 vendas.csv', '{WS}/{EV}/t228.csv', 10, 'enviado', now())")
    chk(sql(f"select diagnostico_id from pesquisa_arquivos where nome = 't228 vendas.csv'") == D, 'arquivo mandado pelo link (antes de concluir) já entra nas evidências do diagnóstico')
    sql(f"update pesquisa_envios set rascunho_em = now() where id = '{EV}'")
    P = J(f"diagnostico_progresso('{D}')"); et = {e['k']: e for e in P['etapas']}
    chk(P['total'] == 9 and et['enviado']['ok'] and not et['formulario']['ok'] and et['formulario']['det'] == 'cliente preenchendo', 'progresso: enviado, cliente preenchendo', et['formulario'])
    RS = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{FA}', '{EV}', '{P1}') returning id")
    chk(sql(f"select resposta_id from diagnosticos where id = '{D}'") == RS and sql(f"select count(*) from diagnostico_decisoes where diagnostico_id = '{D}' and texto = 'O cliente respondeu o formulário'") == '1', 'a resposta do cliente entra sozinha no diagnóstico e no histórico')
    chk('já respondeu' in erro(CL + f"diagnostico_formulario('{D}', '{FB}')"), 'depois de respondido, o formulário não pode mais ser trocado')
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; S.abas.dg = 'form';", 4500)
    t = pg.inner_text('#main')
    chk('O cliente respondeu' in t and '✓ Respondido' in t and pg.locator('#dgFPesq').count() == 0 and pg.locator('#dgFReu').count() == 1, 'respondido: a aba mostra o passo final e leva para a reunião')
    front.vai(pg, 'gro-diag', "S.dgSel = null;", 4000)
    t = pg.inner_text('#main')
    chk(P1 not in [x['pessoa_id'] for x in J(f"diagnosticos_clientes('{WS}')")] and pg.locator(f'[data-dgcomeca="{P1}"]').count() == 0, 'quem já tem diagnóstico sai da lista de espera')
    pg.click('#dgNovo'); pg.wait_for_timeout(1200)
    pg.select_option('.modal [name=pessoa]', '_email'); pg.fill('.modal [name=email]', 'contrato.t228@exemplo.com'); pg.click('.modal .acts .pri'); pg.wait_for_timeout(4000)
    chk(sql(f"select count(*) from diagnosticos where workspace_id = '{WS}' and pessoa_id = '{P1}'") == '1', 'cliente que já tem diagnóstico aberto: abre o que existe, não cria outro')
    tem = pg.evaluate("() => { const o = PQ_MODELOS.diagnostico_mathisa.objetos; return { met: o.filter(x => x.tp === 'metricas').map(x => x.cfg.simples), doc: o.filter(x => x.tp === 'documentos').map(x => !!x.cfg.upload), onde: o.some(x => x.k === 'onde'), n: o.length }; }")
    chk(tem['met'] == [True] and tem['doc'] == [True] and tem['onde'], 'modelo "Diagnóstico Mathisa (pré-diagnóstico)": métricas com as principais, arquivos por plataforma', tem)
    errs = list(pg.errs); ctx.close()
    sql(f"update workspaces set agencia = false where id = '{WS}'")
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    t = front.vai(pg, 'gro-diag', "S.dgSel = null; S.dgSemDiag = null; S.gxDiag = null;", 4000)
    chk('Clientes esperando' not in t and '1. Arquivos do cliente' in t, 'outras empresas (não agência): a tela continua sendo a leitura de planilhas do Growth Model', t[:200])
    errs += pg.errs; ctx.close()
    sql(f"update workspaces set agencia = true where id = '{WS}'")
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=390, vh=844)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'form';", 4500)
    larg = pg.evaluate("document.documentElement.scrollWidth")
    chk(larg <= 392, 'no celular a página não passa da largura da tela', larg)
    errs += pg.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
