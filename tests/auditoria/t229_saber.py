"""v0.229: Diagnóstico de clientes — "O que já se sabe" (origem de cada informação, conflitos entre fontes, revisão da equipe) e
excluir pergunta direto na lista de Pesquisas. Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess, time; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots229/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:500]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't229%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T229%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T229%')"
    sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in {sub})")
    for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome like 'T229%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
PE = one(f"select id from pessoas where workspace_id = '{WS}' order by criado_em limit 1")
PQ = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa) values ('{WS}', 'T229 diag', 'diagnostico', 'cliente', true) returning id")
def perg(o, t, tp, sec, ops='{}', cond='null'):
    return one(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, secao, opcoes, condicao, obrigatoria) values ('{WS}', '{PQ}', {o}, '{t}', '{tp}', '{sec}', '{ops}', {cond}, true) returning id")
QN = perg(1, 'Nome da empresa', 'texto', 'Sobre o seu negócio')
QO = perg(2, 'Onde vende? (pode marcar mais de um)', 'multipla', 'Sobre o seu negócio', '{Hotmart,Kiwify,Eduzz}')
QF = perg(3, 'Faturamento médio por mês', 'moeda', 'Seus números, do seu jeito')
QT = perg(4, 'Ticket médio (valor médio de cada venda)', 'moeda', 'Seus números, do seu jeito')
QI = perg(5, 'Quanto investe em anúncios por mês, em média?', 'moeda', 'Seus números, do seu jeito')
QD = perg(6, 'Qual a plataforma principal?', 'texto', 'Sobre o seu negócio', cond=f"""'{{"pergunta":"{QO}","valores":["Hotmart"]}}'""")
EV = one(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{PQ}', '{PE}') returning id")
RS = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{PQ}', '{EV}', '{PE}') returning id")
sql(f"""insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto, valor_num) values ('{WS}', '{RS}', '{QN}', 'Empresa T229', null), ('{WS}', '{RS}', '{QO}', 'Hotmart', null),
  ('{WS}', '{RS}', '{QO}', 'Kiwify', null), ('{WS}', '{RS}', '{QF}', null, 80000), ('{WS}', '{RS}', '{QT}', null, 500), ('{WS}', '{RS}', '{QI}', null, 3000), ('{WS}', '{RS}', '{QD}', 'Hotmart', null)""")
D = one(f"""insert into diagnosticos (workspace_id, titulo, resposta_id, periodo_ini, periodo_fim, arquitetura) values ('{WS}', 'T229 Saber', '{RS}', '2026-01-01', '2026-06-30', '{{"roteiro":{{"Qual o produto principal?":"Mentoria"}}}}') returning id""")
VENDAS = """Data;Produto;Valor;Email;Status
05/01/2026;Mentoria;31000,00;a@x.com;aprovado
20/01/2026;Mentoria;31000,00;b@x.com;aprovado
05/02/2026;Mentoria;31000,00;c@x.com;aprovado
20/02/2026;Mentoria;31000,00;d@x.com;aprovado
05/03/2026;Mentoria;31000,00;e@x.com;aprovado
20/03/2026;Mentoria;31000,00;f@x.com;aprovado
20/03/2026;Mentoria;31000,00;f@x.com;aprovado
25/03/2026;Mentoria;9999,00;g@x.com;reembolsado
""".encode()
ANUN = """Dia;Campanha;Valor gasto;Impressões;Cliques
2026-01-10;Captação;3100,00;12000;300
2026-02-10;Captação;2900,00;14000;350
""".encode()
for nome, cont in [('t229 vendas.csv', VENDAS), ('t229 anuncios.csv', ANUN)]:
    cam = f"{WS}/diag/{D}/{nome.replace(' ', '_')}"
    sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{D}', 'equipe', 'equipe', '{nome}', '{cam}', {len(cont)}, 'enviado', now())")
    front.ARQS['diagnostico/' + cam] = cont
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'saber'; S.dgAudTent = null;", 3000)
    for _ in range(40):
        if sql(f"select count(*) from pesquisa_arquivos where diagnostico_id = '{D}' and (auditoria ->> 'versao')::int = 2") == '2': break
        time.sleep(1)
    pg.wait_for_timeout(2500)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; S.abas.dg = 'saber';", 4500)
    aud = json.loads(sql(f"select auditoria::text from pesquisa_arquivos where diagnostico_id = '{D}' and nome = 't229 vendas.csv'"))['abas'][0]
    chk(aud['n_ok'] == 6 and aud['total_ok'] == 186000 and aud['soma_mes'] == {'2026-01': 62000, '2026-02': 62000, '2026-03': 62000}, 'auditoria v2: soma por mês só de vendas aprovadas, sem a linha repetida e sem o reembolso', (aud.get('n_ok'), aud.get('total_ok'), aud.get('soma_mes')))
    t = pg.inner_text('#main')
    conf = {c.get_attribute('data-sbc'): c.inner_text().replace('\xa0', ' ') for c in pg.locator('.sb-c').all()}
    chk('R$ 80.000,00' in conf.get('c:fat', '') and 'R$ 62.000,00' in conf['c:fat'] and 'Diferença de 23%' in conf['c:fat'], 'conflito: faturamento médio declarado (R$ 80 mil) × planilhas (R$ 62 mil)', conf.get('c:fat'))
    chk('Diferença de' in conf.get('c:ticket', '') and 'Batem' in conf.get('c:inv', ''), 'ticket médio não bate; investimento em anúncios bate (R$ 3 mil × média R$ 3 mil)', conf)
    chk(pg.inner_text('[data-abas="dg"] [data-aba-k="saber"]').strip().endswith('2'), 'a aba mostra 2 conflitos para decidir')
    chk('Sobre o negócio' in t and 'Empresa T229' in t and 'Declarado pelo cliente' in t, 'do formulário: informações por assunto, marcadas como declaradas pelo cliente')
    pg.screenshot(path=SHOT + '1_saber.png', full_page=True)
    pg.click('[data-sbval="c:fat"][data-v="planilha"]'); pg.wait_for_timeout(3000)
    chk('o da planilha' in sql(f"select valor from diagnostico_saber_revisoes where diagnostico_id = '{D}' and chave = 'c:fat'") and pg.inner_text('[data-abas="dg"] [data-aba-k="saber"]').strip().endswith('1'), '"Vale o da planilha" fica registrado e sai da contagem')
    pg.click('[data-sbreu="c:ticket"]'); pg.wait_for_timeout(3000)
    front.aba(pg, 'reu', 500)
    conv = pg.inner_text('.dg-conv').replace('\xa0', ' ')
    chk('Conferir ticket médio: o cliente disse R$ 500,00; as planilhas mostram R$ 31.000,00' in conv and 'Conferir faturamento' not in conv, 'conflito levado para a reunião entra na pauta; o resolvido não', conv)
    front.aba(pg, 'saber', 500)
    pg.click(f'tr[data-sb="f:{QN}"] [data-sbok]'); pg.wait_for_timeout(2500)
    chk('Confirmado' in pg.inner_text(f'tr[data-sb="f:{QN}"]'), 'confirmar uma informação do cliente')
    pg.click(f'tr[data-sb="f:{QO}"] [data-sbcor]'); pg.wait_for_timeout(800); pg.fill('.modal [name=valor]', 'Só Hotmart'); pg.click('.modal .acts .pri'); pg.wait_for_timeout(3000)
    chk('Valor certo: Só Hotmart' in pg.inner_text(f'tr[data-sb="f:{QO}"]'), 'corrigir guarda o valor certo')
    pg.click(f'tr[data-sb="f:{QO}"] [data-sbdes]'); pg.wait_for_timeout(2500)
    chk(sql(f"select count(*) from diagnostico_saber_revisoes where diagnostico_id = '{D}' and chave = 'f:{QO}'") == '0', 'desfazer apaga a revisão')
    front.aba(pg, 'pla', 400); tp = pg.inner_text('[data-aba-p="pla"]').replace('\xa0', ' ')
    chk('R$ 186.000,00' in tp and 'Vendas válidas' in tp and 'R$ 31.000,00' in tp and 't229 vendas.csv' in tp, 'das planilhas: vendas válidas, faturamento, ticket, com o arquivo de origem', tp[:400])
    pg.click('#main [data-abas="dgs"] [data-aba-k="reu"]'); pg.wait_for_timeout(400)
    chk('Mentoria' in pg.inner_text('[data-aba-p="reu"][data-aba-de="dgs"]'), 'da reunião: o que a equipe anotou no roteiro')
    errs = list(pg.errs)
    # Pesquisas: excluir pergunta na lista
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{PQ}'; S.pqTab = 'perguntas';", 4000)
    btn = pg.locator(f'[data-qx="{QO}"]'); btn.click(); pg.wait_for_timeout(1500)
    chk(btn.inner_text() == 'Confirmar exclusão' and '2 resposta(s) desta pergunta também serão apagadas' in pg.inner_text('body') and '1 pergunta(s) que só apareciam conforme esta' in pg.inner_text('body'), 'excluir pergunta: avisa das respostas e das perguntas que dependem dela')
    btn.click(); pg.wait_for_timeout(3000)
    chk(sql(f"select count(*) from pesquisa_perguntas where id = '{QO}'") == '0' and sql(f"select condicao is null from pesquisa_perguntas where id = '{QD}'") == 't', 'pergunta excluída; a que dependia dela passa a aparecer sempre')
    errs += pg.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
