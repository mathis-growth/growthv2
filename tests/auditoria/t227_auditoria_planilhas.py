"""v0.227: Diagnóstico Inteligente D4 — auditoria automática das planilhas.
Ao abrir o diagnóstico, as planilhas das evidências são conferidas na tela e o resultado fica no arquivo: tipo, colunas, qualidade
(repetidas, datas inválidas, futuras, fora do período, meses sem linha, valores negativos), cobertura, dados pessoais mascarados,
período e classificação sugeridos, sinais que confirmam o de-para; troca manual do tipo e da coluna; arquivo que não abre vira erro.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess, io, datetime; sys.path.insert(0, '.')
import front, openpyxl
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots227/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:500]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
J = lambda q: json.loads(sql(CL + q).split('|', 1)[1])
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't227%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T227%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")  # v0.228: o diagnóstico de clientes é só da agência
D = one(f"insert into diagnosticos (workspace_id, titulo, periodo_ini, periodo_fim) values ('{WS}', 'T227 Planilhas', '2026-01-01', '2026-06-30') returning id")
VENDAS = """Data;Produto;Valor;E-mail do comprador;Status;Origem
05/01/2026;Curso A;497,00;ana@x.com;aprovado;instagram
10/01/2026;Curso A;497,00;bia@x.com;aprovado;google
10/01/2026;Curso A;497,00;bia@x.com;aprovado;google
15/03/2026;Mentoria;-100,00;ana@x.com;reembolsado;instagram
20/04/2026;Curso A;497,00;caio@x.com;aprovado;facebook
xx/yy;Curso A;497,00;dani@x.com;aprovado;google
10/01/2027;Curso A;497,00;edu@x.com;aprovado;google
20/12/2025;Curso A;497,00;fe@x.com;aprovado;google
""".encode()
wb = openpyxl.Workbook(); ws = wb.active; ws.title = 'Leads'; ws.append(['Data de cadastro', 'Nome', 'E-mail', 'utm_source'])
for i, (d, n, e, u) in enumerate([(datetime.datetime(2026, 1, 3), 'Ana Lima', 'ana@x.com', 'instagram'), (datetime.datetime(2026, 2, 7), 'Bia Reis', 'bia@x.com', 'google'),
                                  (datetime.datetime(2026, 3, 9), 'Caio Dias', 'caio@x.com', 'instagram'), (datetime.datetime(2026, 4, 1), 'Dani Sá', 'dani@x.com', 'facebook')]): ws.append([d, n, e, u])
bio = io.BytesIO(); wb.save(bio); LEADS = bio.getvalue()
ANUN = """Dia;Campanha;Valor gasto;Impressões;Cliques
2026-01-10;Captação;150,00;12000;300
2026-02-10;Captação;180,00;14000;350
""".encode()
ARQ = {}
for nome, cont in [('t227 vendas.csv', VENDAS), ('t227 leads.xlsx', LEADS), ('t227 anuncios.csv', ANUN), ('t227 quebrado.xlsx', b'isto nao e uma planilha')]:
    cam = f"{WS}/diag/{D}/{nome.replace(' ', '_')}"
    ARQ[nome] = one(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{D}', 'equipe', 'equipe', '{nome}', '{cam}', {len(cont)}, 'enviado', now()) returning id")
    front.ARQS['diagnostico/' + cam] = cont
A = lambda nome: json.loads(sql(f"select coalesce(auditoria::text, 'null') from pesquisa_arquivos where id = '{ARQ[nome]}'"))
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'dados'; S.dgAudTent = null;", 4000)
    for _ in range(40):
        pg.wait_for_timeout(1000)
        st = pg.evaluate("(document.querySelector('#dgAudSt') || {}).textContent || ''")
        if '4 de 4' in st or '3 de 4' in st: break
    pg.wait_for_timeout(1500)
    t = pg.inner_text('#main')
    chk('3 de 4 planilha(s) conferida(s)' in t, 'ao abrir o diagnóstico, as planilhas são conferidas sozinhas (3 de 4; uma não abre)', t[t.find('Auditoria das planilhas'):][:300])
    V, Ld, An = A('t227 vendas.csv'), A('t227 leads.xlsx'), A('t227 anuncios.csv')
    chk(V['tipo'] == 'vendas' and Ld['tipo'] == 'leads' and An['tipo'] == 'midia', 'tipo de cada planilha reconhecido (vendas, leads, investimento)', (V.get('tipo'), Ld.get('tipo'), An.get('tipo')))
    av = ' '.join(x['txt'] for x in V['abas'][0]['alertas'])
    chk('1 linha(s) repetida(s)' in av and '1 data(s) que não consegui ler' in av and '1 data(s) no futuro' in av and '1 valor(es) negativo(s)' in av and 'fora do período do diagnóstico' in av and 'fev' in av.lower(), 'vendas: repetida, data inválida, futura, valor negativo, fora do período e mês sem linha', av)
    chk(V['qualidade'] == 'ruim' and V['abas'][0]['recompradores'] == 1, 'data ilegível em mais de 5% das linhas = precisa de ajuste; recompra encontrada', (V['qualidade'], V['abas'][0].get('recompradores')))
    cols = {c['nome']: c for c in V['abas'][0]['colunas']}
    chk(cols['E-mail do comprador']['campo'] == 'cliente' and cols['E-mail do comprador']['tipo_dado'] == 'email' and cols['Valor']['campo'] == 'valor' and cols['Origem']['campo'] == 'canal', 'colunas: significado e tipo de dado', {k: (c['campo'], c['tipo_dado']) for k, c in cols.items()})
    chk('@' not in json.dumps(V) + json.dumps(Ld) and 'Ana Lima' not in json.dumps(Ld) and '•••' in json.dumps(Ld['abas'][0]['amostra'], ensure_ascii=False), 'e-mails e nomes não ficam guardados (aparecem como •••)')
    chk(V['sinais'] == {'vendas': 'parcial', 'cliente': 'ok', 'produto': 'ok', 'status': 'ok', 'origemvenda': 'ok', 'recorrencia': 'ok'}, 'sinais da planilha de vendas', V['sinais'])
    chk(Ld['sinais'] == {'leads': 'ok', 'qualificacao': 'falta'} and An['sinais'] == {'midia': 'ok', 'topo': 'parcial'}, 'sinais de leads (sem qualificação) e de anúncios (sem visitas)', (Ld['sinais'], An['sinais']))
    r = sql(f"select processamento || ':' || periodo_ini || ':' || periodo_fim || ':' || classe || ':' || classe_origem from pesquisa_arquivos where id = '{ARQ['t227 leads.xlsx']}'")
    chk(r == 'lido:2026-01-03:2026-04-01:marketing:sugerida', 'arquivo lido: período e classificação sugeridos pela auditoria', r)
    chk(sql(f"select processamento || ':' || coalesce(processamento_erro, '') from pesquisa_arquivos where id = '{ARQ['t227 quebrado.xlsx']}'").startswith('erro:'), 'arquivo que não abre fica com erro e o motivo')
    CK = {x['k']: x for x in J(f"diagnostico_checklist('{D}', '2026-11-02')")['itens']}
    chk(CK['crm']['status'] in ('recebido', 'parcial') and CK['vendas']['n'] == 1 and CK['marketing']['n'] == 1, 'checklist: a planilha de leads da equipe conta como CRM e leads', {k: (v['status'], v['n']) for k, v in CK.items()})
    M = {x['codigo']: x for x in J(f"diagnostico_depara('{D}', '2026-11-02')")['metricas']}
    chk(M['ltv']['dados'] == 'sim' and M['recompra']['dados'] == 'sim', 'de-para confirmado pela auditoria: LTV e recompra dão para calcular (sem "confirmar")', (M['ltv'], M['recompra']['dados']))
    chk(M['ctr']['dados'] == 'ressalvas' and M['cpl_qualificado']['dados'] == 'nao', 'de-para: CTR com ressalva (sem visitas); custo por lead qualificado não dá', (M['ctr']['dados'], M['cpl_qualificado']['dados']))
    t = pg.inner_text('#main')
    pg.locator(f'details[data-aud="{ARQ["t227 vendas.csv"]}"] summary').click(); pg.wait_for_timeout(500)
    tv = pg.inner_text(f'details[data-aud="{ARQ["t227 vendas.csv"]}"]')
    chk('Precisa de ajuste' in tv and 'repetida' in tv and 'Linhas por mês' in tv and 'Curso A' in tv and '•••' in tv, 'tela: qualidade, alertas, linhas por mês, produtos e exemplos mascarados', tv[:600])
    chk('Não consegui ler' in t, 'tela: a planilha que não abre aparece com o aviso')
    pg.screenshot(path=SHOT + '1_auditoria.png', full_page=True)
    # troca manual: a coluna Origem deixa de ser canal
    sel = pg.locator(f'details[data-aud="{ARQ["t227 vendas.csv"]}"] [data-audcol="{cols["Origem"]["i"]}"]'); sel.select_option(''); pg.wait_for_timeout(4000)
    V2 = A('t227 vendas.csv')
    chk(V2['sinais']['origemvenda'] == 'falta' and V2['manual']['CSV']['mapa'].get('canal') is None and 'canal' in V2['manual']['CSV']['mapa'], 'tirar a coluna de origem: a escolha manual fica guardada e a origem das vendas passa a faltar', (V2['sinais'], V2.get('manual')))
    pg.locator(f'details[data-aud="{ARQ["t227 anuncios.csv"]}"] summary').click(); pg.wait_for_timeout(300)
    pg.locator(f'details[data-aud="{ARQ["t227 anuncios.csv"]}"] [data-audtipo]').select_option('ignorar'); pg.wait_for_timeout(4000)
    A2 = A('t227 anuncios.csv')
    chk(A2['tipo'] == 'ignorar' and A2['sinais'] == {} and A2['manual']['CSV']['tipo'] == 'ignorar', '"Não usar" a planilha de anúncios: ela deixa de contar nos sinais')
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; S.abas.dg = 'dados';", 4000)
    chk(A('t227 vendas.csv')['manual']['CSV']['mapa'].get('canal', 'x') is None, 'a escolha manual não volta sozinha ao abrir de novo')
    errs = [e for e in pg.errs]; ctx.close()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=390, vh=844)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'dados';", 4500)
    pg.locator(f'details[data-aud="{ARQ["t227 vendas.csv"]}"] summary').click(); pg.wait_for_timeout(400)
    larg = pg.evaluate("document.documentElement.scrollWidth")
    chk(larg <= 392, 'no celular a página não passa da largura da tela', larg)
    pg.screenshot(path=SHOT + '2_celular.png', full_page=True)
    errs += pg.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
