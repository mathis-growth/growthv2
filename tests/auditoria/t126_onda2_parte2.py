"""v0.126 (fecha a Onda 2 e completa a Onda 1): abandono por semana; LTV por coorte; o que mais mexe no lucro (Growth Model);
prioridade ICE (2x2); antes × depois dos experimentos; desvio da meta e funil com perdas no fechamento; vendas acumuladas × meta na campanha;
CPM/CTR/CPC/frequência e CAC por canal na Mídia paga; investimento, CPL e CAC no tempo no marketing; receita de novos × existentes no Dashboard.
Banco fa: o teste cria abandonos e experimentos de mentira (prefixo T126) e apaga no fim."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr)
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from checkout_abandonos where workspace_id = '{WS}' and id_externo like 'T126%'; delete from growth_experimentos where workspace_id = '{WS}' and titulo like 'T126 %';")
limpa()
VID = sql(f"select id from vendas where workspace_id = '{WS}' and status = 'aprovada' limit 1")
sql(f"""insert into checkout_abandonos (workspace_id, abandonado_em, origem, id_externo, valor, recuperado_venda_id, recuperado_em) values
  ('{WS}', '2026-09-22 10:00-03', 'manual', 'T126a', 100, null, null), ('{WS}', '2026-09-23 10:00-03', 'manual', 'T126b', 100, '{VID}', '2026-09-24 10:00-03'),
  ('{WS}', '2026-10-06 10:00-03', 'manual', 'T126c', 100, null, null), ('{WS}', '2026-10-07 10:00-03', 'manual', 'T126d', 100, null, null);
  insert into growth_experimentos (workspace_id, titulo, etapa, impacto, confianca, facilidade) values
  ('{WS}', 'T126 Alto e fácil', 'priorizado', 9, 8, 9), ('{WS}', 'T126 Baixo e difícil', 'ideia', 2, 3, 2);
  insert into growth_experimentos (workspace_id, titulo, etapa, impacto, confianca, facilidade, valor_base, valor_resultado, resultado, concluido_em, metrica_alvo, aprendizado) values
  ('{WS}', 'T126 Venceu', 'concluido', 6, 6, 6, 100, 120, 'venceu', '2026-10-01', 'conversão', 'teste'), ('{WS}', 'T126 Perdeu', 'concluido', 5, 5, 5, 50, 45, 'perdeu', '2026-10-02', 'ticket', 'teste');""")
try:
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
        erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
        # ---------------- Abandono ----------------
        front.vai(pg, 'crm-abandonos', "S.abf = { de: '2026-09-15', ate: '2026-10-15', camp: '' }", 6000)
        t = pg.inner_text('#main')
        chk('Abandonos e recuperação por dia' in t, 'Abandono: 31 dias → por dia')
        chk('4 abandono(s), 1 recuperado(s)' in t, 'Abandono: totais do gráfico batem com os cadastrados')
        front.vai(pg, 'crm-abandonos', "S.abf = { de: '2026-08-01', ate: '2026-10-15', camp: '' }", 6000)
        chk('por semana' in pg.inner_text('#main') and pg.locator('#main svg.gc').count() == 2, 'Abandono: 76 dias → por semana, com barras e taxa de recuperação')
        # ---------------- Ciclo e Resultados ----------------
        front.vai(pg, 'gro-ciclo', '', 6000)
        t = pg.inner_text('#main')
        chk('O que testar primeiro' in t and pg.locator('[data-gcexp]').count() == 2, 'Ciclo: 2x2 com as ideias não concluídas')
        chk(pg.locator('.gc-2x2l li').first.inner_text().find('T126 Alto e fácil') >= 0, 'a maior nota ICE é a número 1')
        front.vai(pg, 'gro-result', '', 6000)
        t = pg.inner_text('#main')
        chk('Antes × depois' in t and '1 de 2 experimento(s) com resultado venceram' in t, 'Resultados: halteres e taxa de vitória')
        chk('+20,0%' in t and '−10,0%' in t, 'variação de cada experimento (100 → 120 e 50 → 45)')
        # ---------------- Growth Model ----------------
        front.vai(pg, 'gro-modelo', '', 9000)
        tor = pg.locator('#gmTor')
        chk(tor.count() == 1 and tor.locator('.gc-torl').count() >= 3, 'Growth Model: o que mais mexe no lucro (tornado)')
        chk(pg.evaluate("(() => { const v = [...document.querySelectorAll('#gmTor .gc-tort i.pos')].map(e => parseFloat(e.style.width)); return v.length > 1 && v.every((x, i) => !i || x <= v[i - 1] + 0.05); })()"), 'alavancas da maior para a menor')
        # ---------------- Mídia paga ----------------
        front.vai(pg, 'mkt-trafego', "S.tDe = '2026-08-01'; S.tAte = '2026-10-15'; S.tCamp = ''; S.tCanal = '';", 7000)
        t = pg.inner_text('#main')
        chk('Custo e atenção por semana' in t and 'CPM' in t and 'CTR' in t and 'CPC' in t, 'Mídia: CPM, CTR e CPC por semana')
        cac = pg.evaluate("[...document.querySelectorAll('.gc-pilha2 .panel')][1].querySelectorAll('.gc-bhl').length")
        chk(cac >= 1, 'Mídia: CAC de mídia por canal em barras')
        # ---------------- Marketing ----------------
        front.vai(pg, 'mkt-dash', '', 9000)
        chk('Investimento, CPL e CAC por semana' in pg.inner_text('#main') and pg.locator('#mgBody .gc-mini svg.gc').count() == 3, 'Marketing: investimento, CPL e CAC no tempo (90 dias → semana)')
        # ---------------- Dashboard ----------------
        front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 9000)
        nx = pg.locator('#pgNovEx')
        chk(nx.count() == 1 and nx.locator('svg.gc rect').count() >= 1, 'Dashboard: receita de clientes novos × existentes')
        tot = pg.evaluate("[...document.querySelectorAll('#pgNovEx rect title')].filter(t => /set\\/26/.test(t.textContent)).map(t => Number(t.textContent.split(':').pop().split('(')[0].replace(/[^0-9,]/g, '').replace(',', '.'))).reduce((a, b) => a + b, 0)")
        ref = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-09-01' and '2026-09-30'"))
        chk(abs(tot - ref) < 0.01, 'novos + existentes de set/26 = receita bruta das vendas do mês (%.2f = %.2f)' % (tot, ref))
        # ---------------- Fechamento da campanha ----------------
        cid = sql(f"select id from campanhas where workspace_id = '{WS}' and meta_vendas is not null limit 1")
        front.vai(pg, 'mkt-camp', f"S.campSel = '{cid}'; S.campTab = 'debrief'; S.fecVer = 'vivo';", 8000)
        t = pg.inner_text('#main')
        chk('Onde a campanha ficou longe da meta' in t, 'Fechamento: desvio da meta (barras divergentes)')
        chk(pg.locator('.gc-fun .gc-funl').count() >= 2, 'Fechamento: funil com perdas entre os passos')
        chk(pg.locator('details:has(th:text("Passo"))').count() == 1, 'tabela do funil continua, recolhida')
        front.vai(pg, 'mkt-camp', f"S.campSel = '{cid}'; S.campTab = 'dash';", 9000)
        chk('Vendas acumuladas contra a meta' in pg.inner_text('#main'), 'Campanha: vendas acumuladas × meta (burn-up)')
        # ---------------- Retenção ----------------
        front.vai(pg, 'ho-retencao', "S.rx = null; S.rxAba = 'coortes';", 9000)
        chk('O LTV está subindo?' in pg.inner_text('#main'), 'Retenção: LTV por coorte')
        chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
        b.close()
finally:
    limpa()
    chk(sql(f"select count(*) from growth_experimentos where workspace_id = '{WS}' and titulo like 'T126 %'") == '0', 'dados de teste apagados')
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
