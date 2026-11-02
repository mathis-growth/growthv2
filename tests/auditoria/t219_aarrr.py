"""v0.219: Growth's Brain — funil AARRR com o que o Growths já calcula: etapas, período anterior, metas do registro, gargalo sugerido,
passagem lead → cliente novo, North Star e "sem dado" quando falta informação. Banco fa (Escola Aurora), com as migrations até 20261213100000_brain_aarrr.sql."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots219/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
nb = lambda t: t.replace('\xa0', ' ')
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
def limpa():
    sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
    sql(f"delete from growth_metricas where workspace_id = '{WS}' and nome = 'NSM t219'")
limpa()
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 10, 18000, 300)")
sql(f"insert into growth_metricas (workspace_id, nome, tipo, fonte, chave_auto, unidade) values ('{WS}', 'NSM t219', 'north_star', 'auto', 'clientes_ativos', 'numero')")
R = json.loads(sql(CL + f"aarrr_painel('{WS}', '2026-10-01', '2026-10-31', '2026-11-01')").split('|', 1)[1])
E = {e['k']: {m['codigo']: m for m in e['metricas']} for e in R['etapas']}
chk([e['k'] for e in R['etapas']] == ['aquisicao', 'ativacao', 'retencao', 'receita', 'recomendacao', 'recompra'], 'as seis etapas, com os nomes do Diagnóstico')
leads = int(sql(f"select count(*) from pessoas where workspace_id = '{WS}' and coalesce(captada, true) and (criado_em at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
fat = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-31'"))
chk(E['aquisicao']['leads']['v'] == leads and abs(float(E['receita']['faturamento']['v']) - fat) < 0.01, 'leads e faturamento: os mesmos números das metas e do Dashboard de vendas')
novos = int(sql(f"select count(*) from (select pessoa_id, min(dia) d from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and pessoa_id is not null group by 1) x where d between '2026-10-01' and '2026-10-31'"))
chk(E['ativacao']['novos']['v'] == novos and abs(float(R['passagem']['taxa']) - round(novos * 100 / leads, 2)) < 0.01, 'clientes novos (1ª compra) e a passagem lead → cliente novo')
chk(E['receita']['faturamento']['meta']['meta'] == 18000 and E['aquisicao']['leads']['meta']['meta'] == 300, 'metas do registro aparecem nas etapas (leads e faturamento)')
chk(E['recomendacao']['indicacoes']['sem_dado'] == 'O Growths ainda não registra indicações.' and E['retencao']['saida_pct']['v'] is None and 'Customer Growth' in (E['retencao']['saida_pct']['sem_dado'] or ''), 'sem dado: indicação e (sem Customer Growth) retenção dizem que não têm, sem inventar')
g = R['gargalo']
chk(g is None or ('pista' not in g['texto'] and g['etapa'] in E), 'gargalo sugerido: uma taxa que piorou mais de 5%', g)
chk(R['nsm']['nome'] == 'NSM t219' and R['nsm']['etapa'] == 'retencao' and R['nsm']['status'] == 'provisoria', 'North Star aparece na etapa que mede (clientes ativos → retenção)')
try:
    sql(f"select aarrr_painel('{WS}', '2026-10-01', '2026-10-31', '2026-11-01')"); chk(False, 'sem login')
except Exception as e: chk('Sem acesso' in str(e), 'sem login, o funil é recusado')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 11000)
    chk(pg.locator('#ckAarrr').count() == 1, 'Cockpit › Growth: botão "Abrir o funil AARRR"')
    pg.click('#ckAarrr'); pg.wait_for_timeout(4000)
    t = nb(pg.inner_text('#modalRoot'))
    chk('Funil AARRR' in t and 'Aquisição' in t and 'Recompra e ascensão' in t and 'Leads → Clientes novos' in t and 'NSM t219' in t, 'funil: etapas, passagem e North Star', t[:400])
    chk(pg.evaluate('S.view') == 'cockpit', 'o botão abre o funil sem sair do Cockpit')
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '1_funil_aarrr.png')
    pg.click('#modalRoot [data-aainv=faturamento]'); pg.wait_for_timeout(4000)
    chk('Investigar · Faturamento' in pg.inner_text('#modalRoot'), '"Investigar" no faturamento do funil abre a investigação')
    pg.click('#modalRoot [data-x]')
    pg.set_viewport_size({'width': 390, 'height': 900}); front.vai(pg, 'cockpit', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 10000)
    pg.click('#ckAarrr'); pg.wait_for_timeout(4000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= 392"), 'celular: o funil não passa da tela')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
