"""v0.217: Growth's Brain — investigação: o número aberto por dimensão (com o período anterior), filtro cruzado, registros por trás do número,
caminho de volta; o total bate com as metas e com o Dashboard de vendas. Banco fa (Escola Aurora), com as migrations até 20261211100000_brain_investigar.sql."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots217/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
brl = lambda v: ('−' if v < 0 else '') + 'R$ ' + f'{abs(v):,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')
nb = lambda t: t.replace('\xa0', ' ')
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
def inv(met, ini, fim, f='{}'):
    return json.loads(sql(CL + f"investigar('{WS}', '{met}', '{ini}', '{fim}', '{f}')").split('|', 1)[1])
def limpa():
    sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 10, 18000, 300)")
fat = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-31'"))
fat_set = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-08-31' and '2026-09-30'"))
R = inv('faturamento', '2026-10-01', '2026-10-31')
chk(abs(float(R['total']) - fat) < 0.01 and abs(float(R['total_ant']) - fat_set) < 0.01, 'total do período e do período anterior (31 dias antes) = vendas aprovadas', (R['total'], fat, R['total_ant'], fat_set))
for k in R['ordem']:
    chk(abs(sum(float(x['v']) for x in R['dims'][k]) - fat) < 0.01, f'dimensão {k}: as fatias somam o total (nada some, nada duplica)')
prod = R['dims']['produto'][0]
F = inv('faturamento', '2026-10-01', '2026-10-31', json.dumps({'produto': prod['k']}))
chk(abs(float(F['total']) - float(prod['v'])) < 0.01 and F['filtros_nomes']['produto'] == prod['r'], 'filtro por produto: o total vira o da fatia, com o nome do filtro', (F['total'], prod))
chk(abs(sum(float(x['v']) for x in F['dims']['campanha']) - float(prod['v'])) < 0.01, 'filtro cruzado: a dimensão campanha passa a mostrar só o produto escolhido')
regs = json.loads(sql(CL + f"investigar_registros('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '{json.dumps({'produto': prod['k']})}', 500)").split('|', 1)[1])
chk(len(regs) == F['registros'] and abs(sum(float(r['valor']) for r in regs) - float(prod['v'])) < 0.01, 'registros: as vendas por trás do número somam a fatia')
L = inv('leads', '2026-10-01', '2026-10-31')
leads_out = int(sql(f"select count(*) from pessoas where workspace_id = '{WS}' and coalesce(captada, true) and (criado_em at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
chk(int(L['total']) == leads_out and L['ordem'] == ['campanha', 'canal', 'qualificacao', 'situacao'], 'leads: o mesmo número das metas, aberto por campanha, canal, qualificação e situação')
try:
    sql(f"select investigar('{WS}', 'faturamento', '2026-10-01', '2026-10-31')"); chk(False, 'sem login recusa')
except Exception as e: chk('Sem acesso' in str(e), 'sem login, a investigação é recusada')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 11000)
    pg.click('#main [data-mt=inv]'); pg.wait_for_timeout(4000)
    t = nb(pg.inner_text('#modalRoot'))
    chk('Investigar · Faturamento' in t and brl(fat) in t and 'Produto' in t and 'Canal' in t and 'o que mais mudou' in t, 'Cockpit › Investigar o faturamento: total, período anterior e as dimensões', t[:400])
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '1_investigar_faturamento.png')
    pg.locator('#modalRoot [data-invk=produto]').first.click(); pg.wait_for_timeout(3500)
    t = nb(pg.inner_text('#modalRoot'))
    chk(('Produto: ' + prod['r']) in t and brl(float(prod['v'])) in t and pg.locator('#modalRoot [data-invk=produto]').count() == 0, 'clicar no produto filtra tudo, mostra o caminho e tira a dimensão já filtrada', t[:300])
    pg.click('#invReg'); pg.wait_for_timeout(3500)
    chk(pg.locator('#modalRoot table tbody tr').count() == F['registros'] and pg.locator('#modalRoot [data-f]').count() > 0, 'Ver os registros: as vendas, com link para a pessoa')
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '2_registros.png')
    pg.click('#invVolta'); pg.wait_for_timeout(3000); pg.click('#invVolta'); pg.wait_for_timeout(3500)
    chk(brl(fat) in nb(pg.inner_text('#modalRoot')) and pg.locator('#modalRoot [data-invk=produto]').count() > 0, 'Voltar: volta para os registros, depois para o número sem filtro')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    pg.click('#main [data-minv] >> nth=0'); pg.wait_for_timeout(4000)
    chk('Investigar · Leads' in pg.inner_text('#modalRoot') and 'Qualificação' in pg.inner_text('#modalRoot'), '"Investigar" na linha de leads abre a investigação de leads')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    pg.set_viewport_size({'width': 390, 'height': 900}); pg.click('#main [data-mt=inv]'); pg.wait_for_timeout(4000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= 392"), 'celular: a investigação não passa da tela')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
