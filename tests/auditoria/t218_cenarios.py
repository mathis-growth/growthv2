"""v0.218: Growth's Brain — cenários ligados à meta: alavancas (leads, investimento, conversão, ticket) aplicadas ao que falta do período,
partindo da projeção do Cockpit; atual × cenário; o que seria preciso para bater; premissas e incertezas; salvar, versionar, aprovar e arquivar.
Banco fa (Escola Aurora), com as migrations até 20261212100000_brain_cenarios.sql. Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots218/'; os.makedirs(SHOT, exist_ok=True)
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
def sim(met, h, al):
    return json.loads(sql(CL + f"metas_simular('{WS}', '{met}', '2026-10-01', '2026-10-31', '{h}', 'empresa', null, '{json.dumps(al)}')").split('|', 1)[1])
def limpa():
    sql(f"delete from metas_cenarios where workspace_id = '{WS}'"); sql(f"delete from riscos where workspace_id = '{WS}'"); sql(f"delete from riscos_rodadas where workspace_id = '{WS}'")
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}'"); sql(f"delete from metas where workspace_id = '{WS}' and escopo <> 'campanha'")
limpa()
sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_receita, meta_leads) values ('{WS}', 2026, 10, 30000, 600)")
av = json.loads(sql(CL + f"metas_avaliar('{WS}', 'faturamento', '2026-10-01', '2026-10-31', '2026-10-15')").split('|', 1)[1])
Z = sim('faturamento', '2026-10-15', {})
chk(abs(Z['atual']['projecao'] - float(av['projecao'])) < 0.01 and abs(Z['cenario']['projecao'] - Z['atual']['projecao']) < 0.01, 'sem alavanca: o cenário é igual à projeção do Cockpit', (Z['atual']['projecao'], av['projecao']))
R = sim('faturamento', '2026-10-15', {'leads_pct': 10})
rest = Z['atual']['restante']
chk(abs(R['cenario']['restante'] - rest * 1.1) < 0.02, '+10% de leads: o que falta de faturamento cresce 10%')
P = R['premissas']
R2 = sim('faturamento', '2026-10-15', {'ticket_novo': round(P['ticket'] * 1.2, 2)})
chk(abs(R2['cenario']['restante'] / rest - 1.2) < 0.001, 'ticket 20% maior: o que falta cresce 20% (faturamento = leads × conversão × ticket)')
R3 = sim('faturamento', '2026-10-15', {'invest_extra': 1000})
chk(R3['cenario']['leads_extra_midia'] == round(1000 / P['cpl']) and R3['cenario']['projecao'] > Z['atual']['projecao'], 'R$ 1.000 em mídia viram leads pelo CPL de 90 dias e aumentam a projeção', R3['cenario'])
chk(R3['realizado'] == Z['realizado'] and float(sql(f"select count(*) from vendas where workspace_id = '{WS}'")) > 0, 'simular não muda o realizado nem os dados')
L = sim('leads', '2026-10-15', {'conv_nova': 10, 'ticket_novo': 2000})
chk(abs(L['cenario']['projecao'] - L['atual']['projecao']) < 0.5 and len(L['avisos']) == 2, 'meta de leads: conversão e ticket não mudam a projeção, e a resposta avisa', L['avisos'])
pf = Z['precisa_fator']
chk(abs(Z['realizado'] + rest * pf - 30000) < 0.5, '"o que seria preciso": o fator que faz a projeção bater exatamente a meta', pf)
E = sim('faturamento', '2026-11-01', {})
chk('erro' in E, 'período encerrado: não há o que simular')
chk(len(Z['incertezas']) == 4 and 'não uma garantia' in ' '.join(Z['incertezas']), 'incertezas na resposta (não é garantia)')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', "S.abas = { ck: 'metas' }; S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 11000)
    pg.click('#main [data-mt=sim]'); pg.wait_for_timeout(4000)
    t = nb(pg.inner_text('#modalRoot'))
    chk('Simular · Faturamento' in t and 'Alavancas' in t and 'Atual × cenário' in t and 'Premissas e incertezas' in t, 'Cockpit › Simular: alavancas, atual × cenário e premissas', t[:300])
    pg.fill('#modalRoot [data-sim=leads_pct]', '10'); pg.fill('#modalRoot [data-sim=ticket_novo]', str(round(P['ticket'] * 1.5))); pg.click('#simCalc'); pg.wait_for_timeout(4000)
    t = nb(pg.inner_text('#modalRoot'))
    chk('bate a meta' in t or 'Ainda falta' in t, 'resultado diz se o cenário bate a meta', t[-600:])
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '1_simular.png')
    pg.fill('#simNome', '+10% leads e ticket maior'); pg.fill('#simHip', 'Upsell na página de vendas'); pg.click('#simSalva'); pg.wait_for_timeout(5000)
    chk(sql(f"select nome || '|' || versao || '|' || status || '|' || (alavancas->>'leads_pct') from metas_cenarios where workspace_id = '{WS}'") == '+10% leads e ticket maior|1|rascunho|10', 'salvar o cenário (nome, versão 1, rascunho, alavancas)')
    pg.click('#modalRoot [data-simc]'); pg.wait_for_timeout(4000)
    chk(pg.input_value('#modalRoot [data-sim=leads_pct]') == '10' and 'nova versão' in pg.inner_text('#simSalva'), 'carregar o cenário salvo traz as alavancas e oferece salvar como nova versão')
    pg.fill('#modalRoot [data-sim=leads_pct]', '20'); pg.click('#simCalc'); pg.wait_for_timeout(4000)
    pg.fill('#simNome', '+20% leads e ticket maior'); pg.click('#simSalva'); pg.wait_for_timeout(5000)
    chk(sql(f"select versao || '|' || (substitui_id is not null) from metas_cenarios where workspace_id = '{WS}' and nome = '+20% leads e ticket maior'") == '2|true', 'nova versão ligada à anterior')
    pg.click('#modalRoot [data-sima] >> nth=0'); pg.wait_for_timeout(4000)
    chk(sql(f"select count(*) from metas_cenarios where workspace_id = '{WS}' and status = 'aprovado'") == '1', 'aprovar um cenário')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    pg.click('#main [data-msim] >> nth=0'); pg.wait_for_timeout(4000)
    chk('Simular · Leads' in pg.inner_text('#modalRoot') and pg.locator('#modalRoot [data-sim=conv_nova]').count() == 0, 'Simular na linha de leads: só as alavancas de leads')
    pg.click('#modalRoot [data-x]')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
