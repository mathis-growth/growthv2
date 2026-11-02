"""v0.234: código para colocar o formulário na página (embed) em Pesquisas → Formulário e aparência.
Tela: captação gravada só com o WhatsApp não quebra mais a aba; com o formulário pronto (ativo, link aberto e captando contatos), aparece o código com o iframe do link; a origem (UTM) entra no código;
o botão copia; sem o link aberto, a tela diz o que falta. A página pública dentro de um iframe avisa a altura (ajuste automático).
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots234/'; os.makedirs(SHOT, exist_ok=True)
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
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T234%')"
    sql(f"delete from pesquisa_perguntas where pesquisa_id in {sub}"); sql(f"delete from pesquisas where id in {sub}")
limpa()
CAP = json.dumps({'ativa': True, 'destino': 'lead', 'campos': {'telefone': {'mostrar': True, 'obrig': True, 'rotulo': 'WhatsApp'}}, 'consentimentos': []})
P = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, aceita_link_aberto, captacao) values ('{WS}', 'T234 Pronto', 'lead', 'lead', true, true, '{CAP}') returning id")
sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria) values ('{WS}', '{P}', 1, 'Qual o seu objetivo?', 'texto', true)")
N = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, aceita_link_aberto, captacao) values ('{WS}', 'T234 Sem link', 'lead', 'lead', true, false, '{CAP}') returning id")
TOK = sql(f"select token_aberto from pesquisas where id = '{P}'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'form';", 4500)
    pg.wait_for_selector('#pfEmb', state='attached', timeout=20000); cod = pg.text_content('#pfEmb') or ''
    chk('<iframe' in cod and f'pesquisa={TOK}' in cod and 'growthsPesquisa' in cod, 'captação só com WhatsApp abre a aba; formulário pronto: aparece o código com o iframe do link e o ajuste de altura', cod[:200])
    pg.evaluate("() => document.querySelectorAll('.pf-link details').forEach(d => d.open = true)"); pg.fill('#uS', 'site'); pg.fill('#uM', 'pagina'); pg.fill('#uC', 'qualificacao'); pg.wait_for_timeout(300)
    cod2 = pg.text_content('#pfEmb') or ''
    chk('utm_source=site' in cod2 and 'utm_campaign=qualificacao' in cod2, 'a origem (UTM) preenchida entra no código', cod2[:300])
    pg.evaluate("() => { window.__cp = null; navigator.clipboard.writeText = t => { window.__cp = t; return Promise.resolve(); }; }")
    pg.click('#pfEmbCp'); pg.wait_for_timeout(300)
    chk((pg.evaluate("() => window.__cp") or '') == cod2, 'o botão copia o código')
    pg.locator('.pf-emb').scroll_into_view_if_needed(); pg.screenshot(path=SHOT + '1_codigo_embed.png')
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{N}'; S.pqTab = 'form';", 4500)
    pg.wait_for_selector('#pfSalva', state='attached', timeout=20000)
    chk('Aceitar também o link aberto' in (pg.text_content('#main') or '') and pg.locator('#pfEmb').count() == 0, 'sem o link aberto: não há código e a tela diz o que marcar')
    # a página pública avisa a altura quando está dentro de um iframe
    html = pg.evaluate("() => document.documentElement.outerHTML")
    chk('growthsPesquisa' in html, 'a página pública avisa a altura para a página de fora (ajuste automático do iframe)')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
