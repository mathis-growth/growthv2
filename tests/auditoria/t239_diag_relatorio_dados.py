"""v0.239: Diagnóstico dos dados. Antes de importar, o Growths lê cada planilha, cruza as colunas com a estrutura do banco e com as métricas
e mostra o que identificou e o que não. Botão na aba Dados e em Preparar a reunião; imprimir ou salvar em PDF.
Tela: arquivo de leads reconhecido como "Clientes e leads", colunas ligadas aos campos (Nome, E-mail…), coluna sem campo "Não identifiquei",
"Talvez" quando outra tabela reconhece a coluna, arquivo não reconhecido, o que falta (obrigatório), dados pessoais mascarados nos exemplos,
perguntas para a reunião; o mesmo relatório aparece em Preparar a reunião; imprimir abre a janela com o relatório.
Banco fa (Escola Aurora como agência). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots239/'; os.makedirs(SHOT, exist_ok=True)
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
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and nome like 't239%'")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T239%'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T239%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
P = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', 'Cliente T239') returning id")
D = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T239 Diag', '{P}') returning id")
ARQ = {
 't239 leads.csv': "Nome;E-mail;Telefone;Data de entrada;Nota interna;Produto\nAna Lima;ana@t239.com;31988887777;2026-03-01;quente;Curso A\nBeto Reis;beto@t239.com;31977776666;2026-03-05;;Curso B\n".encode(),
 't239 coisas.csv': "abc;xyz\n1;2\n3;4\n".encode()}
for nome, cont in ARQ.items():
    cam = f"{WS}/diag/{D}/{nome.replace(' ', '_')}"
    sql(f"insert into pesquisa_arquivos (workspace_id, diagnostico_id, origem, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{D}', 'equipe', 'equipe', '{nome}', '{cam}', {len(cont)}, 'enviado', now())")
    front.ARQS['diagnostico/' + cam] = cont
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'dados';", 4500)
    pg.wait_for_selector('[data-aba-p="dados"] [data-dgrel-gera]', state='attached', timeout=15000)
    pg.click('[data-aba-p="dados"] [data-dgrel-gera]'); pg.wait_for_timeout(5000)
    t = pg.text_content('[data-aba-p="dados"] .dg-rel') or ''
    chk('t239 leads.csv' in t and 'Clientes e leads' in t, 'o arquivo de leads é reconhecido como "Clientes e leads"', t[:300])
    linhas = pg.evaluate("() => { const a = [...document.querySelectorAll('[data-aba-p=\"dados\"] .dg-rel-arq')].find(x => x.querySelector('h3').textContent.includes('t239 leads.csv')); return a ? [...a.querySelectorAll('tbody tr')].map(r => [r.cells[0].textContent.trim(), r.cells[1].textContent.trim(), r.cells[3].textContent.trim()]) : []; }")
    L = {l[0]: l for l in linhas}
    chk(L.get('Nome', ['', ''])[1].startswith('Nome') and L.get('E-mail', ['', ''])[1].startswith('E-mail') and 'Data de entrada' in L.get('Data de entrada', ['', ''])[1], 'cada coluna reconhecida aparece com o campo do Growths', linhas)
    chk('Não identifiquei' in L.get('Nota interna', ['', ''])[1], 'coluna sem campo no Growths: "Não identifiquei"', L.get('Nota interna'))
    chk('Talvez' in L.get('Produto', ['', ''])[1], 'coluna que outra tabela reconhece: "Talvez …"', L.get('Produto'))
    chk('a***@t239.com' in L.get('E-mail', ['', '', ''])[2] and '9988887777' not in t and '****-7777' in t, 'os exemplos escondem e-mail e telefone', L.get('E-mail'))
    chk('não reconheci' in t and 't239 coisas.csv' in t, 'arquivo que não dá para reconhecer aparece como "não reconheci"')
    chk('o que é a coluna "Nota interna"' in t and 't239 coisas.csv: não reconheci o que é este arquivo' in t, 'as dúvidas viram perguntas para a reunião')
    chk('Colunas identificadas' in t, 'o resumo mostra quantas colunas foram identificadas')
    pg.locator('[data-aba-p="dados"] .dg-rel').scroll_into_view_if_needed(); pg.screenshot(path=SHOT + '1_diagnostico_dados.png', full_page=False)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'reu';", 4500)
    pg.wait_for_selector('[data-aba-p="reu"] .dg-rel', state='attached', timeout=15000)
    chk('t239 leads.csv' in (pg.text_content('[data-aba-p="reu"] .dg-rel') or ''), 'o mesmo diagnóstico aparece em Preparar a reunião')
    pg.evaluate("() => { window.__w = null; window.open = () => { const d = document.implementation.createHTMLDocument(''); window.__w = { document: { write: h => { window.__html = h; }, close: () => {} }, print: () => {} }; return window.__w; }; }")
    pg.click('[data-aba-p="reu"] [data-dgrel-print]'); pg.wait_for_timeout(600)
    h = pg.evaluate("() => window.__html || ''")
    chk('Diagnóstico dos dados' in h and 't239 leads.csv' in h and '<table' in h, 'imprimir abre a janela com o relatório para salvar em PDF')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
