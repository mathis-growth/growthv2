"""v0.205: pacote Go-to-Market (sem financeiro) e Custos de marketing. Banco fa (Escola Aurora), com 20261202100000_go_to_market.sql.
Põe a Escola Aurora no pacote Go-to-Market durante o teste e desfaz no fim (pacote, custos, rotina, notificações)."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots205/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
T0 = sql("select now()")
def limpa():
    sql(f"update workspaces set pacote_id = null where id = '{WS}'")
    sql(f"delete from mkt_custos_meses where workspace_id = '{WS}'"); sql(f"delete from mkt_custos_itens where workspace_id = '{WS}'"); sql(f"delete from mkt_custos_config where workspace_id = '{WS}'")
    sql(f"delete from projeto_atividades where workspace_id = '{WS}' and 'custos-marketing' = any(tags)"); sql(f"delete from projetos where workspace_id = '{WS}' and nome = 'Rotinas do mês'")
    sql(f"update mkt_custos_config set responsavel_id = null where workspace_id = '{WS}'"); sql(f"delete from notificacoes where destinatario_id in (select id from equipe where workspace_id = '{WS}' and nome = 'Responsável t205')"); sql(f"delete from equipe where workspace_id = '{WS}' and nome = 'Responsável t205'")
    sql(f"delete from notificacoes where criada_em >= '{T0}' and (titulo like 'Lançar os custos de marketing%' or titulo like 'Custos de marketing pendentes%')")
limpa()
pac = sql("select array_to_string(telas, ',') from pacotes_acesso where nome = 'Go-to-Market'").split(',')
chk('mkt-custos' in pac and not any(t.startswith('fin-') for t in pac) and 'cad-bancos' not in pac and 'crm-vendas' in pac and 'ho-dash' in pac, 'pacote Go-to-Market: com marketing, vendas, CS e custos de marketing; sem financeiro e sem cadastro financeiro')
sql(f"update workspaces set pacote_id = (select id from pacotes_acesso where nome = 'Go-to-Market') where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    nav = pg.inner_text('#nav').upper()
    chk('FINANCEIRO' not in nav.replace('FINANCEIRO E CONTABILIDADE', '') and 'MARKETING' in nav and 'VENDAS' in nav and 'CUSTOMER SUCCESS' in nav, 'menu sem Financeiro; com Marketing, Vendas e Customer Success')
    chk(pg.evaluate("semFin()") is True, 'o Growths reconhece o cliente sem financeiro')
    t = front.vai(pg, 'mkt-custos', '', 4000)
    chk('Desligado para este cliente' in t and pg.locator('#mcLiga').count() == 1, 'Custos de marketing começa desligado, com o botão de ligar')
    pg.click('#mcLiga'); pg.wait_for_timeout(3500)
    chk(sql(f"select ativo from mkt_custos_config where workspace_id = '{WS}'") == 't', 'ligar grava a configuração')
    # itens: fixo e variável
    pg.click('#mcNovo'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'Equipe de marketing'); pg.fill('#modalRoot [name=valor]', '5000'); pg.fill('#modalRoot [name=desde]', '2026-10')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2500)
    pg.click('#mcNovo'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'Freelancers e agência'); pg.select_option('#modalRoot [name=tipo]', 'variavel'); pg.wait_for_timeout(100)
    chk(pg.locator('#modalRoot .mc-val').is_hidden(), 'custo variável não pede valor fixo')
    pg.fill('#modalRoot [name=desde]', '2026-10'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select string_agg(tipo || ':' || coalesce(valor::text, '-'), ',' order by tipo) from mkt_custos_itens where workspace_id = '{WS}'") == 'fixo:5000.00,variavel:-', 'itens gravados: fixo com valor, variável sem')
    t = pg.inner_text('#main')
    chk('Falta lançar 1' in t and 'Em curso' in t and 'set/2026' not in t, 'meses: desde o primeiro custo; out/2026 falta lançar 1; nov/2026 em curso')
    # fechar sem lançar: recusa
    pg.click('[data-mcf="2026-10-01"]'); pg.wait_for_timeout(500); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2000)
    chk(sql(f"select count(*) from mkt_custos_meses where workspace_id = '{WS}' and fechado_em is not null") == '0', 'não fecha o mês com variável faltando')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # rotina: último dia do mês cria a atividade; dia 3 avisa a equipe
    rid = sql(f"insert into equipe (workspace_id, nome, ativo) values ('{WS}', 'Responsável t205', true) returning id").split('\n')[0]
    sql(f"update mkt_custos_config set responsavel_id = '{rid}' where workspace_id = '{WS}'")
    r1 = json.loads(sql("select mkt_custos_rodar('2026-10-31 15:00-03')::text"))
    at = sql(f"select a.titulo || '|' || a.status || '|' || a.responsavel_id || '|' || p.nome from projeto_atividades a join projetos p on p.id = a.projeto_id where a.workspace_id = '{WS}' and 'custos-marketing' = any(a.tags)")
    chk(r1['atividades'] == 1 and at.startswith('Lançar os custos de marketing de 10/2026|liberada|' + rid) and at.endswith('Rotinas do mês'), 'último dia: atividade do cliente no projeto "Rotinas do mês", para o responsável: ' + at)
    r2 = json.loads(sql("select mkt_custos_rodar('2026-10-31 18:00-03')::text"))
    chk(r2['atividades'] == 0, 'a rotina não repete a atividade')
    r3 = json.loads(sql("select mkt_custos_rodar('2026-11-03 09:00-03')::text"))
    chk(r3['avisos_equipe'] == 1 and sql(f"select aviso_equipe_em is not null from mkt_custos_meses where workspace_id = '{WS}' and mes = '2026-10-01'") == 't', 'dia 3: avisa a equipe da agência uma vez')
    # lançar e fechar
    front.vai(pg, 'mkt-custos', '', 4000)
    pg.click('[data-mcl="2026-10-01"]'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot input[name^=v_]', '1200'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3500)
    chk('Pronto para fechar' in pg.inner_text('#main'), 'lançado o variável: pronto para fechar')
    pg.click('[data-mcf="2026-10-01"]'); pg.wait_for_timeout(500); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select fechado_em is not null from mkt_custos_meses where workspace_id = '{WS}' and mes = '2026-10-01'") == 't' and sql(f"select status from projeto_atividades where workspace_id = '{WS}' and 'custos-marketing' = any(tags)") == 'concluida', 'fechar: mês fechado e a atividade concluída')
    try: sql(f"update mkt_custos_valores set valor = 1 where workspace_id = '{WS}' and mes = '2026-10-01'"); trav = False
    except Exception as e: trav = 'já foi fechado' in str(e)
    chk(trav, 'mês fechado não muda')
    # resultado de outubro
    pg.click('[data-mcv="2026-10-01"]'); pg.wait_for_timeout(3500)
    rec = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
    mid = float(sql(f"select coalesce(sum(custo), 0) from metricas_anuncio_dia where workspace_id = '{WS}' and data between '2026-10-01' and '2026-10-31'"))
    res = rec - mid - 6200
    t = pg.inner_text('#main')
    alvo = ('%.2f' % abs(res)).replace('.', ',')
    chk('Resultado de marketing · out/2026' in t and alvo[-6:] in t.replace('.', '') and 'as outras despesas da empresa não entram' in t, 'outubro: resultado = receita − mídia − 6.200 (%.2f) e o aviso' % res)
    chk('6.200,00' in t, 'custos de marketing de outubro: 5.000 fixo + 1.200 variável')
    pg.screenshot(path=SHOT + '1_custos.png', full_page=True)
    # painéis
    t = front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-10-01', fim: '2026-10-31', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null };", 6000)
    chk(pg.locator('#mrPainel').count() == 1 and 'ROAS de mídia' in pg.inner_text('#mrPainel'), 'Dashboard de marketing: Resultado de marketing no período, com ROAS')
    pg.screenshot(path=SHOT + '2_mkt_dash.png')
    t = front.vai(pg, 'crm-dash', "S.vpp = { ini: '2026-10-01', fim: '2026-10-31' };", 6000)
    vp = (pg.inner_text('#vpPlat') if pg.locator('#vpPlat').count() else '').replace('\xa0', ' ')
    bru = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
    chk('Vendas por plataforma' in vp and 'A receber da plataforma' in vp and brl(bru) in vp if (brl := lambda v: 'R$ ' + f'{v:,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')) else False, 'Dashboard de vendas: vendas por plataforma, com o total bruto de outubro')
    chk(pg.locator('.dsec[data-sec="plataformas"] #vpPlat').count() == 1, 'fica na seção própria "Vendas por plataforma"')
    chk('não dá para saber se já caiu na conta' in vp, 'avisa que, sem financeiro, não se sabe se caiu na conta')
    t = front.vai(pg, 'adm-painel', '', 7000)
    chk(pg.locator('#mrPainel').count() == 1 and 'lucro, caixa, DRE e CAC total saem desta tela' in pg.inner_text('#mrPainel'), 'Dashboard administrativo: avisa e mostra o Resultado de marketing do mês')
    vis = pg.evaluate("[...document.querySelectorAll('.kpis.hero > *')].filter(c => c.offsetParent).map(c => c.textContent.trim().split(/\\s/)[0])")
    chk('Lucro' not in vis and 'Saldo' not in vis and 'Receita' in vis, 'sem lucro, saldo e CAC total no topo: ' + str(vis))
    chk(pg.evaluate("[...document.querySelectorAll('.dsec[data-sec=saude], .dsec[data-sec=tabelas]')].every(s => !s.offsetParent)"), 'sem Saúde financeira e sem DRE/fluxo de caixa')
    pg.screenshot(path=SHOT + '3_adm.png')
    erros = [e for e in pg.errs]; chk(not erros, 'sem erro de JavaScript ' + str(erros[:3]))
    b.close()
    # cliente completo: nada muda
    ctx2_b = None
sql(f"update workspaces set pacote_id = null where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-11-01')
    chk(pg.evaluate("semFin()") is False and 'Custos de marketing' not in pg.inner_text('#nav'), 'cliente completo: sem a tela de custos de marketing no menu')
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-10-01', fim: '2026-10-31', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null };", 6000)
    chk(pg.locator('#mrPainel').count() == 0, 'cliente completo: o Dashboard de marketing não muda')
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
