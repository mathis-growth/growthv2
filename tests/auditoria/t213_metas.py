"""v0.213: Growth's Brain, incremento 1 — metas de faturamento num registro central (metas), avaliação no Cockpit (meta, esperado,
realizado, desvio, projeção, status), conferência da soma dos meses, foto diária, objetivos do ano no Planejamento anual, NSM provisória.
Banco fa (Escola Aurora), com 20261207100000_brain_metas.sql. Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots213/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
brl = lambda v: ('−' if v < 0 else '') + 'R$\xa0' + f'{abs(v):,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')
nb = lambda t: t.replace('\xa0', ' ')
def limpa():
    sql(f"delete from metas_fotos where workspace_id = '{WS}'")
    sql(f"delete from plano_anual where workspace_id = '{WS}'"); sql(f"delete from planejamento_mensal where workspace_id = '{WS}'")
    sql(f"delete from metas where workspace_id = '{WS}'"); sql(f"delete from plano_objetivos where workspace_id = '{WS}' and ano is not null")
    sql(f"delete from growth_metricas where workspace_id = '{WS}' and nome = 'NSM de teste v0.213'")
limpa()
# ---------------- banco ----------------
sql(f"insert into plano_anual (workspace_id, ano, meta_receita) values ('{WS}', 2026, 120000)")
chk(sql(f"select granularidade || ':' || valor::numeric(14,2) || ':' || origem from metas where workspace_id = '{WS}' and status = 'aprovada'") == 'ano:120000.00:plano_anual', 'meta do ano salva no Planejamento anual vira meta no registro central')
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 10, 18000, 300), ('{WS}', 2026, 11, 22000, null)")
chk(sql(f"select count(*) from metas where workspace_id = '{WS}' and granularidade = 'mes' and status = 'aprovada'") == '2', 'metas do mês (planejamento_mensal) entram no registro central')
sql(f"update metas set valor = 24000 where workspace_id = '{WS}' and granularidade = 'mes' and ini = '2026-11-01' and status = 'aprovada'")
chk(sql(f"select meta_receita::numeric(14,2) from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and mes = 11") == '24000.00', 'mudar a meta no registro central muda o planejamento do mês (espelho)')
chk(sql(f"select versao || ':' || (select count(*) from metas_historico h where h.meta_id = m.id) from metas m where workspace_id = '{WS}' and ini = '2026-11-01' and status = 'aprovada'") == '2:1', 'a mudança cria versão 2 e guarda a versão 1 no histórico')
sql(f"update planejamento_mensal set meta_receita = 22000 where workspace_id = '{WS}' and ano = 2026 and mes = 11")
chk(sql(f"select valor::numeric(14,2) || ':' || versao from metas where workspace_id = '{WS}' and ini = '2026-11-01' and status = 'aprovada'") == '22000.00:3', 'mudar no planejamento do mês muda o registro central (versão 3)')
chk(sql(f"select meta_leads from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and mes = 10") == '300', 'o espelho não mexe nas metas de leads, vendas e orçamento')
A = lambda ini, fim, h: json.loads(sql(f"select metas_avaliar_interno('{WS}', 'faturamento', '{ini}', '{fim}', '{h}')"))
ano = A('2026-01-01', '2026-12-31', '2026-11-01')
chk(abs(float(ano['meta']) - 120000) < 0.01, 'meta do ano inteiro = 120.000: os meses sem meta dividem o que sobra (120.000 − 40.000)', ano['meta'])
fat_out = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-31'"))
out = A('2026-10-01', '2026-10-31', '2026-11-01')
chk(abs(float(out['realizado']) - fat_out) < 0.01 and out['status'] == ('atingida' if fat_out >= 18000 else 'nao_atingida') and out['metodo'] == 'periodo_encerrado', 'outubro encerrado: realizado = vendas aprovadas, status e método certos', out)
mid = A('2026-10-01', '2026-10-31', '2026-10-15')
real15 = float(sql(f"select coalesce(sum(valor), 0) from v_vendas_todas where workspace_id = '{WS}' and status = 'aprovada' and dia between '2026-10-01' and '2026-10-15'"))
esp15 = round(18000 * 15 / 31, 2); r = real15 / esp15
st = 'dentro' if r >= .9 else 'atencao' if r >= .75 else 'risco'
if real15 >= 18000: st = 'atingida'
chk(abs(float(mid['esperado']) - esp15) < 0.02 and mid['metodo'] == 'ritmo_do_periodo' and abs(float(mid['projecao']) - real15 / 15 * 31) < 0.05 and mid['status'] == st,
    'meio de outubro: esperado linear (15/31 da meta), projeção pelo ritmo e status pela regra (10%/25%)', (mid['esperado'], esp15, mid['projecao'], mid['status'], st))
nov = A('2026-11-01', '2026-11-30', '2026-11-01')
chk(nov['status'] == 'sem_dados' and nov['metodo'] in ('media_28_dias', 'sem_dados'), '1º dia do mês: "sem dados suficientes" e projeção pela média de 28 dias', nov)
chk(A('2027-01-01', '2027-01-31', '2026-11-01')['status'] == 'sem_meta', 'período sem meta: "sem meta" (não aplicável), sem inventar número')
sql(f"insert into metas_regras (workspace_id, atencao_pct, risco_pct) values ('{WS}', 0, 1)")
chk(A('2026-10-01', '2026-10-31', '2026-10-15')['status'] in ('risco', 'atingida', 'dentro') and A('2026-10-01', '2026-10-31', '2026-10-15')['regra']['risco_pct'] == 1, 'a regra do status é do cliente e vem na resposta (auditável)')
sql(f"delete from metas_regras where workspace_id = '{WS}'")
n = sql("select metas_fotografar('2026-11-01')")
chk(sql(f"select count(*) from metas_fotos where workspace_id = '{WS}' and dia = '2026-11-01'") == '2', 'foto diária: mês e ano guardados (para medir o acerto da projeção depois)')
try:
    sql(f"select metas_avaliar('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-11-01')"); chk(False, 'sem login, metas_avaliar recusa')
except Exception as e: chk('Sem acesso' in str(e), 'sem login, metas_avaliar recusa (cliente de outro não vê)')
sql(f"insert into growth_metricas (workspace_id, nome, tipo, fonte, chave_auto, unidade) values ('{WS}', 'NSM de teste v0.213', 'north_star', 'auto', 'receita', 'brl')")
chk(sql(f"select nsm_status from growth_metricas where workspace_id = '{WS}' and nome = 'NSM de teste v0.213'") == 'provisoria', 'NSM nova nasce provisória')
sql(f"update growth_metricas set nsm_status = 'em_validacao' where workspace_id = '{WS}' and nome = 'NSM de teste v0.213'")
chk(sql(f"select nsm_versao || ':' || (select count(*) from nsm_historico h where h.metrica_id = g.id) from growth_metricas g where workspace_id = '{WS}' and nome = 'NSM de teste v0.213'") == '2:1', 'mudar o status da NSM guarda a versão anterior')
sql(f"update growth_metricas set nsm_status = 'provisoria' where workspace_id = '{WS}' and nome = 'NSM de teste v0.213'")
# ---------------- telas ----------------
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', '', 9000)
    mt = pg.locator('#main .ck-metas')
    t = nb(mt.inner_text()) if mt.count() else ''
    chk(mt.count() == 1 and 'Meta de faturamento' in t and nb(brl(22000)) in t and 'Sem dados suficientes' in t, 'Cockpit (este mês): faixa de meta com a meta de novembro e "Sem dados suficientes" no dia 1', t[:400])
    chk('No ano 2026:' in t and nb(brl(120000)) in t, 'Cockpit: linha do ano com a meta de 120.000')
    chk('A soma das metas dos meses' in t and nb(brl(40000)) in t, 'Cockpit: avisa que a soma dos meses (40.000) não bate com a meta do ano')
    pg.screenshot(path=SHOT + '1_cockpit_meta_mes.png')
    pg.select_option('#main [data-per-at]', 'mesant'); pg.wait_for_timeout(9000)
    t = nb(pg.locator('#main .ck-metas').inner_text())
    chk(nb(brl(18000)) in t and nb(brl(fat_out)) in t and ('Não atingida' in t or 'Atingida' in t), 'Cockpit (mês passado): meta 18.000, realizado de outubro e status', t[:400])
    pg.locator('#main .ck-metas').screenshot(path=SHOT + '2_cockpit_meta_outubro.png')
    pg.click('#main [data-mt=como]'); pg.wait_for_timeout(600)
    tm = nb(pg.inner_text('#modalRoot'))
    chk('Como calculamos' in tm and 'não é probabilidade' in tm.lower() and 'período encerrado' in tm, 'Como calculamos: fórmula, método da projeção, regra do status e o aviso de que não é probabilidade', tm[:300])
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    pg.click('#main [data-mt=vendas]'); pg.wait_for_timeout(7000)
    chk(pg.evaluate('S.view') == 'crm-dash' and nb(brl(fat_out)) in nb(pg.inner_text('#main')), 'Ver as vendas: abre o Dashboard de vendas no mesmo período, com o mesmo faturamento')
    front.vai(pg, 'cockpit', '', 8000)
    chk('provisória' in pg.inner_text('#main .ck-gro'), 'Cockpit: a North Star aparece como provisória')
    # Planejamento anual: objetivos do ano
    front.vai(pg, 'mkt-camp', "S.tabMkt = 'plan'; S.campSel = null; S.ano = 2026;", 9000)
    sec = pg.locator('#paObj .pa-sec')
    chk(sec.count() == 1 and 'Objetivos e metas do ano' in sec.inner_text() and 'Metas dos meses: 2 de 12' in nb(sec.inner_text()), 'Planejamento anual: seção de objetivos e metas, com a conferência dos meses', sec.inner_text()[:300] if sec.count() else '')
    pg.click('#paObjNovo'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=titulo]', 'Dobrar o faturamento de cursos'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(6000)
    chk('Dobrar o faturamento de cursos' in pg.inner_text('#paObj'), 'criar objetivo do ano')
    pg.click('#paObj [data-objlig]'); pg.wait_for_timeout(6000)
    chk(nb('Faturamento 2026: ' + brl(120000)) in nb(pg.inner_text('#paObj')) and sql(f"select count(*) from metas where workspace_id = '{WS}' and objetivo_id is not null") == '1', 'ligar a meta de faturamento do ano ao objetivo')
    pg.locator('#paObj').screenshot(path=SHOT + '3_objetivos_e_metas.png')
    # mudar a meta de novembro pela tabela antiga vai para o registro central
    pg.fill('[data-m="11"][data-k="meta_receita"]', '25000'); pg.click('#salvaPlan'); pg.wait_for_timeout(6000)
    chk(sql(f"select valor::numeric(14,2) from metas where workspace_id = '{WS}' and ini = '2026-11-01' and status = 'aprovada'") == '25000.00', 'salvar a meta do mês na tabela do planejamento atualiza o registro central')
    # Growth Model: status da NSM
    front.vai(pg, 'gro-modelo', "S.gTab = 'mapa';", 8000)
    chk('Provisória' in pg.inner_text('#main'), 'Growth Model: a North Star mostra o status "Provisória"')
    pg.click('#main .gn.ns [data-ed]'); pg.wait_for_timeout(600)
    chk(pg.locator('#modalRoot [name=nsm_status]').count() == 1, 'Growth Model: o formulário da North Star tem o status')
    pg.click('#modalRoot [data-x]')
    # celular
    pg.set_viewport_size({'width': 390, 'height': 900}); front.vai(pg, 'cockpit', '', 8000)
    chk(pg.evaluate("document.documentElement.scrollWidth <= 392"), 'celular: a faixa de meta não passa da tela')
    pg.screenshot(path=SHOT + '4_celular.png', full_page=False)
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
