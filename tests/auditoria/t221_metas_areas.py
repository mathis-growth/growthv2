"""v0.221: Growth's Brain — metas das áreas (margem, caixa, churn, retenção 90 dias, LTV, ascensão, North Star) no registro central:
valor com fonte (DRE ou Financeiro simplificado; Customer Success; Growth Model), regra no mínimo/no máximo, absorção das metas do CS,
do saldo mínimo e da meta da North Star (espelho nos dois sentidos), Risk Engine e Cockpit. Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots221/'; os.makedirs(SHOT, exist_ok=True)
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
SM0 = sql(f"select coalesce(saldo_minimo::text, '') from empresa where workspace_id = '{WS}'")
def limpa():
    sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"select set_config('growths.metas_espelho', '1', false)")
    sql(f"delete from heavyops_metas where workspace_id = '{WS}'"); sql(f"delete from growth_metricas where workspace_id = '{WS}' and nome = 'NSM t221'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
    sql(f"update empresa set saldo_minimo = {SM0 or 'null'} where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
M = lambda k: sql(f"select coalesce(string_agg(valor::numeric(14,2) || ':' || direcao || ':' || unidade || ':' || origem, ','), '') from metas where workspace_id = '{WS}' and metrica = '{k}' and status = 'aprovada'")
sql(f"insert into heavyops_metas (workspace_id, churn_max, retencao_min, ltv_min, ascensao_min) values ('{WS}', 6, 85, 600, 15)")
chk(M('churn') == '6.00:maximo:pct:migrada' and M('retencao90') == '85.00:minimo:pct:migrada' and M('ltv') == '600.00:minimo:brl:migrada', 'metas do Customer Success entram no registro (churn no máximo; retenção e LTV no mínimo)')
sql(f"update metas set valor = 5 where workspace_id = '{WS}' and metrica = 'churn' and status = 'aprovada'")
chk(sql(f"select churn_max::numeric(6,2) from heavyops_metas where workspace_id = '{WS}'") == '5.00', 'mudar o churn no registro muda a meta do Customer Success (espelho)')
sql(f"update empresa set saldo_minimo = 1000 where workspace_id = '{WS}'")
chk(M('caixa') == '1000.00:minimo:brl:migrada', 'saldo mínimo do Financeiro vira meta de caixa (no mínimo)')
sql(f"update metas set valor = 2000 where workspace_id = '{WS}' and metrica = 'caixa' and status = 'aprovada'")
chk(sql(f"select saldo_minimo::numeric(14,2) from empresa where workspace_id = '{WS}'") == '2000.00', 'mudar a meta de caixa muda o saldo mínimo do Financeiro')
sql(f"insert into growth_metricas (workspace_id, nome, tipo, fonte, chave_auto, unidade, direcao, meta) values ('{WS}', 'NSM t221', 'north_star', 'auto', 'clientes_ativos', 'numero', 'sobe', 120)")
chk(M('nsm') == '120.00:maior:num:migrada', 'meta da North Star (Growth Model) vira meta de nível')
sql(CL + f"metas_nivel_salvar('{WS}', 'margem', 2026, 20)")
chk(M('margem') == '20.00:minimo:pct:manual', 'meta de margem criada pela tela (no mínimo 20%)')
pg = J(f"painel_gerencial('{WS}', '2026-10-01', '2026-10-31', '2026-11-01')")
mg = J(f"metas_avaliar_nivel('{WS}', 'margem', '2026-10-01', '2026-10-31', '2026-11-01')")
chk(abs(mg['realizado'] - round(float(pg['resultado']['margem']) * 100, 2)) < 0.01 and 'DRE' in mg['fonte'] and mg['status'] == 'risco', 'margem de outubro = DRE (lucro ÷ receita), com a fonte, e "em risco" contra 20%', mg)
ho = J(f"heavyops_painel('{WS}', 31)")
ult = sorted(ho['serie'], key=lambda e: int(e['k']))[0]
ch = J(f"metas_avaliar_nivel('{WS}', 'churn', '2026-10-01', '2026-10-31', '2026-11-01')")
esperado = round(ult['perdidos'] / ult['base'] * 100, 2) if ult['base'] else None
chk(ch['realizado'] == esperado and ch['direcao'] == 'maximo', 'churn = o mesmo cálculo da tela de Customer Success (janela de 30 dias)', (ch['realizado'], esperado))
cx = J(f"metas_avaliar_nivel('{WS}', 'caixa', '2026-10-01', '2026-10-31', '2026-11-01')")
chk(abs(cx['realizado'] - float(pg['caixa']['saldo'])) < 0.01 and cx['status'] == ('dentro' if float(pg['caixa']['saldo']) >= 2000 else 'risco' if float(pg['caixa']['saldo']) < 1800 else 'atencao'), 'caixa = saldo em banco hoje, contra o mínimo de R$ 2.000')
ns = J(f"metas_avaliar_nivel('{WS}', 'nsm', '2026-10-01', '2026-10-31', '2026-11-01')")
chk(ns['realizado'] is not None and 'Growth Model' in ns['fonte'] and 'NSM t221' in ns['nome'], 'North Star: valor automático do Growth Model, com o nome', ns)
NV = J(f"metas_niveis('{WS}', '2026-10-01', '2026-10-31', '2026-11-01')")
chk(sorted(x['metrica'] for x in NV) == sorted(['margem', 'caixa', 'churn', 'retencao90', 'ltv', 'ascensao', 'nsm']), 'metas_niveis devolve as sete metas que têm valor definido')
sql(CL + f"riscos_detectar('{WS}', '2026-10-31')")
chk(sql(f"select count(*) from riscos where workspace_id = '{WS}' and chave like 'nivel:margem:%' and area = 'financeiro' and severidade = 'alta'") == '1', 'Risk Engine: margem fora do limite vira risco alto do Financeiro')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg2 = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg2, 'mkt-camp', "S.tabMkt = 'plan'; S.campSel = null; S.ano = 2026;", 10000)
    t = nb(pg2.inner_text('#paAreas'))
    chk('Metas das áreas' in t and 'Margem' in t and 'Saída mensal de alunos' in t and 'North Star' in t and 'no máximo' in t, 'Planejamento anual: seção "Metas das áreas" com as sete métricas', t[:400])
    pg2.fill('#paAreas [data-niv=margem]', '25'); pg2.click('#paNivSalva'); pg2.wait_for_timeout(7000)
    chk(sql(f"select valor::numeric(6,2) || ':' || versao from metas where workspace_id = '{WS}' and metrica = 'margem' and status = 'aprovada'") == '25.00:2', 'salvar a meta de margem pela tela (versão nova)')
    pg2.locator('#paAreas').screenshot(path=SHOT + '1_metas_das_areas.png')
    front.vai(pg2, 'cockpit', "S.abas = { ck: 'metas' }; S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 11000)
    t = nb(pg2.inner_text('#main .ck-metas'))
    chk('Metas das áreas' in t and 'Margem' in t and 'no mínimo 25' in t, 'Cockpit: tabela "Metas das áreas" na faixa de metas', t[-500:])
    front.aba(pg2, 'areas')
    sf = nb(pg2.inner_text('#main .ck-fin .ck-saude')) if pg2.locator('#main .ck-fin .ck-saude').count() else ''
    chk('Margem' in sf and 'meta no mínimo' in sf, 'saúde do Financeiro: a margem com status e a meta', sf)
    sc = nb(pg2.inner_text('#main .ck-cs .ck-saude')) if pg2.locator('#main .ck-cs .ck-saude').count() else ''
    chk('churn' in sc.lower(), 'saúde do Customer Success: as metas do CS', sc)
    pg2.screenshot(path=SHOT + '2_cockpit.png', full_page=True)
    chk(not pg2.errs, 'sem erro de JavaScript ' + str(pg2.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
