"""v0.220: Growth's Brain — acerto da projeção: refaz a projeção do Cockpit nos meses fechados (dias 3 a 25), mede erro e viés,
mostra a faixa provável no mês em andamento e o acerto das fotos guardadas. Banco fa (Escola Aurora), com as migrations até 20261214100000_brain_calibracao.sql."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots220/'; os.makedirs(SHOT, exist_ok=True)
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
J = lambda q: json.loads(sql(CL + q).split('|', 1)[1])
def limpa():
    sql(f"delete from metas_fotos where workspace_id = '{WS}'"); sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
B = J(f"projecao_backtest('{WS}', 'faturamento', '2026-11-15', 12)")
oct = [p for p in B['pontos'] if p['mes'] == '2026-10-01']
fo = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-31'"))
r15 = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-15'"))
p15 = [p for p in oct if p['dia'] == 15][0]
chk(abs(p15['projecao'] - (r15 + r15 / 15 * 16)) < 0.02 and abs(p15['final'] - fo) < 0.01, 'outubro, dia 15: projeção refeita com o mesmo método do Cockpit (ritmo) e total real do mês', p15)
chk(abs(p15['erro_pct'] - round((p15['projecao'] - fo) / fo * 100, 1)) < 0.05, 'erro do mês = (projeção − real) ÷ real')
res = {r['dia']: r for r in B['resumo']}
e15 = [p['erro_pct'] for p in B['pontos'] if p['dia'] == 15]
chk(res[15]['meses'] == len(e15) and abs(res[15]['erro_medio_pct'] - round(sum(abs(x) for x in e15) / len(e15), 1)) < 0.05 and abs(res[15]['vies_pct'] - round(sum(e15) / len(e15), 1)) < 0.05, 'resumo do dia 15: meses, erro médio absoluto e viés (com sinal)')
chk(sorted(res) == [3, 7, 10, 15, 20, 25] and B['meses_com_dado'] >= 3, 'dias 3, 7, 10, 15, 20, 25 e meses com movimento', (sorted(res), B['meses_com_dado']))
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita) values ('{WS}', 2026, 10, 18000)")
F = J(f"projecao_faixa('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-10-15')")
chk(F.get('de') is not None and F['de'] <= F['projecao'] <= F['ate'] and 'não' not in F['texto'][:5] and 'dia 15' in F['texto'], 'faixa provável no dia 15 de outubro, com o texto do erro histórico', F)
chk(F['de'] >= r15 - 0.01, 'a faixa nunca fica abaixo do que já foi realizado')
N = J(f"projecao_faixa('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-11-01')")
chk('motivo' in N, 'mês já encerrado: sem faixa (diz o motivo)')
sql("select metas_fotografar('2026-10-15')")
FO = J(f"projecao_fotos('{WS}', 'faturamento', '2026-11-01')")
chk(FO['fotos'] == 1 and FO['periodos'] == 1, 'fotos guardadas de período encerrado entram no acerto real', FO)
try:
    sql(f"select projecao_backtest('{WS}', 'faturamento', '2026-11-15', 12)"); chk(False, 'sem login')
except Exception as e: chk('Sem acesso' in str(e), 'sem login, o acerto é recusado')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', "S.abas = { ck: 'metas' }; S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 12000)
    t = nb(pg.inner_text('#mtFaixa'))
    chk('Faixa provável até 31/10' in t and 'não probabilidade' in t, 'Cockpit: faixa provável abaixo da projeção, com o aviso de que não é probabilidade', t)
    pg.locator('#main .ck-metas').screenshot(path=SHOT + '1_faixa.png')
    pg.click('#mtFaixa [data-mtac]'); pg.wait_for_timeout(8000)
    t = nb(pg.inner_text('#modalRoot'))
    chk('Acerto da projeção' in t and 'Faturamento' in t and 'Leads' in t and 'Vendas' in t and 'Viés' in t and 'Fotos guardadas' in t, 'Acerto da projeção: tabelas de faturamento, leads e vendas, e as fotos', t[:300])
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '2_acerto.png')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
