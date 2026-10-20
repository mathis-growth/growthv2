"""v0.115: clicar nos cards da campanha abre o detalhe (por canal, por dia, qualificação, anúncios, produtos, últimas pessoas).
Banco escp (Escola Aurora) + PostgREST 3301 (pgrst_escola.conf) + migração 20261019200000."""
import sys, subprocess, json; sys.path.insert(0, '.')
from front_escola import abre, vai
from playwright.sync_api import sync_playwright
C = '23db706a-18dd-493e-9654-87311693fef8'; P_ = '78bfa7aa-7100-4d9b-b8b6-43fefb0534df'; UID = '981ecb82-d432-4ee5-a0c7-1b6ca85bdf33'
def psql(sql, uid=UID):
    pre = "select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\"}',false); set role authenticated; " % uid
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'escp', '-Atq', '-c', pre + sql], capture_output=True, text=True)
    if r.returncode: return r.stderr.replace('\n', ' ')
    return r.stdout.strip().split('\n')[-1]
def adm(sql): return subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'escp', '-Atq', '-c', sql], capture_output=True, text=True).stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
S = lambda R, k: sum(float(x[k] or 0) for x in R['canais'])
R = json.loads(psql("select campanha_detalhe('%s', '2026-10-19')" % C))
chk(S(R, 'leads') == int(adm("select count(*) from campanha_participacoes where campanha_id = '%s'" % C)), 'leads por canal somam as participações')
chk(S(R, 'leads_novos') == int(adm("select count(*) from pessoas where campanha_id = '%s'" % C)), 'novos = cadastros criados pela campanha (2.522)')
chk(abs(S(R, 'investimento') - float(adm("select sum(custo) from v_trafego_anuncio_dia where campanha_id = '%s'" % C))) < 0.01 and R['usa_trafego'], 'investimento = custo dos anúncios')
chk(all(abs(sum(x['inv_dia']) - float(x['investimento'])) < 0.01 and sum(x['leads_dia']) == x['leads'] for x in R['canais']), 'séries por dia somam os totais de cada canal')
chk(S(R, 'qualificados') + S(R, 'nao_qualificados') + S(R, 'pendentes') == S(R, 'leads'), 'qualificação soma os leads')
chk(len(R['anuncios']) == 15 and len(R['ultimos_leads']) == 30, 'top 15 anúncios e 30 últimos leads')
V = json.loads(psql("select campanha_detalhe('%s', '2026-10-19')" % P_))
chk(S(V, 'vendas') == int(adm("select count(*) from vendas where campanha_id = '%s' and status = 'aprovada'" % P_)) and S(V, 'clientes') == sum(sum(x['clientes_dia']) for x in V['canais']), 'vendas e clientes (perpétuo) batem com as vendas aprovadas')
chk('Campanha não encontrada' in psql("select campanha_detalhe('%s')" % C, '00000000-0000-0000-0000-000000000001'), 'quem não é do workspace não lê')
with sync_playwright() as p:
    b = p.chromium.launch(); ctx, pg = abre(b, hoje='2026-10-19')
    vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % C, 7000)
    chk(pg.locator('.kpi.arvk').count() == 8, 'Dashboard: os 8 cards abrem a árvore (v0.116); o detalhe sai por dentro dela')
    pg.evaluate("c => cdAbrir(c, 'leads')", C); pg.wait_for_timeout(2500); t = pg.inner_text('#modalRoot')
    chk('Leads · detalhe da campanha' in t and 'Qualificação dos leads' in t and 'Leads por canal' in t and 'Últimos leads' in t, 'detalhe de Leads: qualificação, por canal e últimos leads')
    pg.click('#modalRoot [data-cdm="investimento"]'); pg.wait_for_timeout(2500); t = pg.inner_text('#modalRoot')
    chk('Investimento por canal' in t and 'Anúncios que mais gastaram' in t and '11.002,19' in t, 'troca para Investimento: por canal e anúncios')
    pg.locator('#modalRoot [data-cdc]').first.click(); pg.wait_for_timeout(6000)
    chk(pg.evaluate("() => !!S.mCanal") and 'Meta de leads do canal' in pg.inner_text('#main'), 'clicar no canal do detalhe filtra o Dashboard')
    vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'captacao'" % C, 5000)
    chk(pg.locator('.kpi.cdk, .kpi.arvk').count() >= 3, 'Captação e metas: cards abrem árvore ou detalhe')
    vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % P_, 7000)
    pg.evaluate("c => cdAbrir(c, 'vendas')", P_); pg.wait_for_timeout(2500); t = pg.inner_text('#modalRoot')
    chk('Por produto' in t and 'Últimas vendas' in t and 'Curso Inglês Base' in t, 'perpétuo: detalhe de Vendas com produtos e últimas vendas')
    pg.locator('#modalRoot [data-cdp]').first.click(); pg.wait_for_timeout(3000)
    chk('Pontos de contato' in pg.inner_text('#modalRoot') or 'Primeira origem' in pg.inner_text('#modalRoot'), 'nome na lista abre a ficha da pessoa')
    for m in ['cpl', 'cac', 'receita', 'roas', 'conv']:
        pg.evaluate("([c, m]) => cdAbrir(c, m)", [P_, m]); pg.wait_for_timeout(1500)
    chk(not pg.errs, 'sem erro de JavaScript nos 8 detalhes ' + str(pg.errs[:2]))
    ctx.close(); ctx, pg = abre(b, hoje='2026-10-19', vw=390, vh=800)
    vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % C, 7000)
    pg.evaluate("c => cdAbrir(c, 'leads')", C); pg.wait_for_timeout(2500)
    chk(pg.evaluate("() => document.documentElement.scrollWidth <= innerWidth + 1"), 'celular: detalhe sem rolagem para o lado')
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
