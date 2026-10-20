"""v0.114: Dashboard da campanha com a meta de leads por dia, acumulada, por mês e por canal, gráficos menores lado a lado
e taxas do funil. Banco escp (Escola Aurora, ver LEIA.md) + PostgREST na porta 3301 (pgrst_escola.conf) + migração 20261019100000."""
import sys, subprocess, json; sys.path.insert(0, '.')
from front_escola import abre, vai
from playwright.sync_api import sync_playwright
C = '23db706a-18dd-493e-9654-87311693fef8'   # Lançamento Formação Fluência · Nov/26 (captação 01 a 26/10, meta 5.000)
P_ = '78bfa7aa-7100-4d9b-b8b6-43fefb0534df'  # Perpétuo (meta 400 por mês)
UID = '981ecb82-d432-4ee5-a0c7-1b6ca85bdf33'
def psql(sql):
    pre = "select set_config('request.jwt.claims','{\"sub\":\"%s\",\"role\":\"authenticated\"}',false); set role authenticated; " % UID
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'escp', '-Atq', '-c', pre + sql], capture_output=True, text=True)
    return (r.stdout.strip().split('\n')[-1] if r.stdout.strip() else r.stderr.strip())
def adm(sql):
    return subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'escp', '-Atq', '-c', sql], capture_output=True, text=True).stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)

# banco
R = json.loads(psql("select campanha_meta_leads('%s', '2026-10-19')" % C))
chk(R['modo'] == 'lancamento' and R['fonte_janela'] == 'captacao' and R['janela']['dias'] == 26, 'lançamento: janela = captação (26 dias), não a campanha inteira (46)')
chk(abs(R['meta_dia'] - 5000 / 26) < 0.01, 'meta diária = 5.000 ÷ 26 = 192,31 (antes 108,7)')
part = int(adm("select count(*) from campanha_participacoes where campanha_id = '%s'" % C))
chk(R['leads_total'] == part == sum(x for x in R['leads'] if x), 'leads = participações (%d), e a série por dia soma o total' % part)
chk(sum(x['leads'] for x in R['canais']) + R['sem_canal'] == part, 'soma dos canais + sem canal = total')
E = json.loads(psql("select campanha_meta_leads('%s', '2026-10-10')" % C))
chk(abs(E['esperado_hoje'] - 5000 / 26 * 10) < 1, 'esperado até 10/10 (dia que não é hoje entra inteiro) = 10 dias de meta: %s' % E['esperado_hoje'])
chk(R['restam_dias'] == 8 and len(R['dias']) == 26 and R['leads'][-1] is None and R['metas'][-1] is not None, 'dias futuros da captação: com meta e sem lead')
cx = next(x for x in R['canais'] if x['utm_campaign'] == 'lfa26-meta-frio-interesses')
chk(cx['meta'] == 1200 and abs(cx['meta_dia'] - 1200 / 26) < 0.01, 'meta do canal espalhada pela captação')
M = json.loads(psql("select campanha_meta_leads('%s', '2026-10-19')" % P_))
chk(M['modo'] == 'mensal' and M['meta_total'] == 400 and abs(M['meta_dia'] - 400 / 31) < 0.01, 'perpétuo: meta do mês ÷ dias do mês (400 ÷ 31)')
chk('Campanha não encontrada' in subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'escp', '-Atq', '-c',
    "select set_config('request.jwt.claims','{\"sub\":\"00000000-0000-0000-0000-000000000001\",\"role\":\"authenticated\"}',false); set role authenticated; select campanha_meta_leads('%s')" % C], capture_output=True, text=True).stderr,
    'quem não é do workspace não lê')

orig = adm("select meta_leads from campanha_canais where utm_campaign = 'lfa26-google-pesquisa'")
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg = abre(b, hoje='2026-10-19')
        t = vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % C, 7000)
        chk('Meta de leads da campanha' in t and '192,3' in t and 'Esperado até hoje' in t and 'Precisa por dia' in t, 'painel do ritmo da meta')
        k = pg.evaluate("() => [...document.querySelectorAll('#main .kpi')].map(x => x.innerText)")
        chk(any(x.startswith('Leads') and '3.027' in x and 'novos na base' in x for x in k), 'KPI Leads usa a mesma conta da meta (3.027) e mostra os novos')
        n = pg.evaluate("() => document.querySelectorAll('#mlGrid > .panel').length")
        chk(n >= 8, 'grade com os gráficos menores (%d painéis)' % n)
        larg = pg.evaluate("() => [...document.querySelectorAll('#mlGrid > .panel')].slice(1, 3).map(x => Math.round(x.getBoundingClientRect().width))")
        chk(all(w < 600 for w in larg), 'Leads por dia e acumulados lado a lado: %s px' % larg)
        chk(pg.locator('#mlGrid svg circle[style*="--good"]').count() > 0 and pg.locator('#mlGrid svg circle[style*="--bad"]').count() > 0, 'pontos dentro e fora da meta')
        chk('Por mês: dentro ou fora da meta' in t and 'out/26' in t, 'por mês')
        chk('Funil: conversão entre etapas' in t and '39,4%' in t and 'CTR' in t and 'connect rate' in t, 'funil: conversão entre etapas e taxas das métricas de diagnóstico')
        pg.click('[data-mlc]'); pg.wait_for_timeout(6000); t = pg.inner_text('#main')
        chk('Meta de leads do canal · lfa26-meta-frio-interesses' in t and '46,2' in t, 'clicar no canal filtra o ritmo e os gráficos')
        pg.click('#mlMetasCanal'); pg.wait_for_timeout(2000)
        cid = adm("select id from campanha_canais where utm_campaign = 'lfa26-google-pesquisa'")
        pg.fill('[name="m_%s"]' % cid, '222'); pg.click('#modalRoot button[type=submit], #modalRoot .btn.pri'); pg.wait_for_timeout(3000)
        chk(adm("select meta_leads from campanha_canais where id = '%s'" % cid) == '222', 'Metas por canal grava a meta do canal')
        vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % P_, 7000); t = pg.inner_text('#main')
        chk('Meta de leads da campanha no mês' in t and 'Leads no mês' in t, 'perpétuo: meta do mês')
        chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
        ctx.close()
        ctx, pg = abre(b, hoje='2026-10-19', vw=390, vh=800)
        vai(pg, 'mkt-camp', "S.campSel = '%s'; S.campTab = 'dash'; S.mCanal = ''" % C, 7000)
        chk(pg.evaluate("() => document.documentElement.scrollWidth <= innerWidth + 1"), 'celular: sem rolagem para o lado')
        ctx.close(); b.close()
finally:
    adm("update campanha_canais set meta_leads = %s where utm_campaign = 'lfa26-google-pesquisa'" % (orig or 'null'))
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
