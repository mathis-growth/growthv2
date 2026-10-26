"""v0.156: alertas nas quatro categorias e Dicionário de métricas com unidade, direção e referência.
Banco fa com 20261112100000_metricas_semantica.sql. Cria 4 alertas de teste e apaga no fim."""
import sys, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
limpa = lambda: sql(f"delete from alertas where workspace_id = '{WS}' and chave like 't156:%'")
limpa()
for ch, tp, sev, ti in [('a', 'repetido', 'alta', 'Leads caindo há 3 dias seguidos'), ('b', 'brusco', 'info', 'Vendas subiram 80% ontem'), ('c', 'brusco', 'media', 'Investimento em mídia subiu 60% ontem'), ('d', 'operacional', 'media', 'Contas a pagar vencidas')]:
    sql(f"insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dia) values ('{WS}', 't156:{ch}', '{tp}', 'teste', '{sev}', '{ti}', 'mensagem de teste', '2026-10-14')")
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    front.vai(pg, 'ia-alertas', '', 7000)
    cards = pg.evaluate("() => [...document.querySelectorAll('.al-c')].map(c => c.innerText)")
    def cat(t): return next((c for c in cards if t in c), '')
    chk('Desfavorável' in cat('Leads caindo') and 'Favorável' in cat('Vendas subiram') and 'Informativo' in cat('Investimento em mídia') and 'Atenção' in cat('Contas a pagar vencidas'), 'alertas: desfavorável, favorável, informativo (mudança sem direção) e atenção')
    chk('Importante' not in ' '.join(cards) and 'Bom sinal' not in ' '.join(cards), 'rótulos antigos substituídos')
    erros += pg.errs
    front.vai(pg, 'cfg-metricas', '', 6000)
    t = pg.inner_text('#main')
    chk('DIREÇÃO' in t.upper() and 'Quanto menor, melhor' in t and 'zero é limite' in t and 'REFERÊNCIA QUE DÁ A COR' in t.upper() and 'Lucro' in t, 'Dicionário: unidade, direção, zero como limite e referência')
    chk(pg.evaluate("() => SEM.M.cac.dir === 'menor' && SEM.M.lucro.saldo === true && SEM.M.investimento.dir === 'neutra'"), 'o dicionário do banco alimenta a camada semântica da tela')
    erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
