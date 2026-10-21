"""v0.124 (Data Storytelling, onda 1): componente único de gráficos; Dashboard novo no lugar do Dashboard Growth;
uma tela só de mídia (Mídia paga), aberta da campanha já filtrada; cascata do resultado e linha só até o mês atual no Financeiro;
receita × equilíbrio × cenários e custo por área contra o mês anterior em Custos e margens. Banco fa (sem alteração de banco)."""
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
num = lambda t: float(t.replace('R$', '').replace('\xa0', '').replace(' ', '').replace('.', '').replace(',', '.').replace('−', '-'))
with sync_playwright() as p:
    b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
    erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
    nav = ' | '.join(pg.evaluate("NAV.filter(g => !g.starter).flatMap(g => itensDe(g).map(i => i[1]))"))
    # ---------------- menu e rotas ----------------
    chk('Dashboard Growth' not in nav, 'o Dashboard Growth saiu do menu')
    chk('Dashboard de mídia' not in nav and 'Mídia paga' in nav, 'Marketing tem uma tela só de mídia (Mídia paga)')
    front.vai(pg, 'adm-dash', '', 5000)
    chk(pg.evaluate('S.view') == 'adm-painel' and 'O que importa agora' in pg.inner_text('#main'), 'link antigo do Dashboard Growth abre o Dashboard')
    front.vai(pg, 'mkt-midia', '', 5000)
    chk(pg.evaluate('S.view') == 'mkt-trafego' and pg.inner_text('#main h1') == 'Mídia paga', 'link antigo do Dashboard de mídia abre a Mídia paga')
    rel = pg.locator('#mdRel')
    chk(rel.count() == 1 and rel.locator('[data-rel]').count() == 4 and rel.locator('#mdCsv').count() == 1 and rel.locator('#mdXlsx').count() == 1, 'Relatório de mídia (canal, campanha, anúncio, ângulo + CSV/Excel/Imprimir) dentro da Mídia paga')
    for k in ['CPL limite', 'CTR mínimo', 'Canal', 'Campanha']: chk(k in pg.inner_text('#main .filters'), 'filtro mantido: ' + k)
    rel.locator('[data-rel=campanha]').click(); pg.wait_for_timeout(500)
    chk('campanha' in rel.locator('thead').text_content().lower() and rel.locator('[data-rel=campanha].on').count() == 1, 'aba Por campanha do relatório troca sem recarregar a tela')
    # ---------------- campanha → mídia ----------------
    cid, ini = sql(f"select c.id, c.data_inicio from campanhas c where c.workspace_id = '{WS}' and exists (select 1 from v_trafego_anuncio_dia t where t.campanha_id = c.id) order by c.data_inicio desc limit 1").split('|')
    front.vai(pg, 'mkt-camp', f"S.campSel = '{cid}'; S.campTab = 'resumo';", 4500)
    chk(pg.locator('#cMidia').count() == 1, 'campanha tem o botão "Ver na Mídia paga"')
    pg.click('#cMidia'); pg.wait_for_timeout(5000)
    st = pg.evaluate('[S.view, S.tCamp, S.tDe, S.tAte]')
    chk(st[0] == 'mkt-trafego' and st[1] == cid, 'abre a Mídia paga filtrada na campanha')
    chk(st[2] == min(ini, '2026-10-15') or st[2] == '2026-09-16', 'período começa no início da campanha (%s)' % st[2])
    chk(pg.locator('#tCamp').input_value() == cid and 'Olhando só a campanha' in pg.inner_text('#main'), 'filtro de campanha aparece marcado e avisado')
    pg.click('#tTodasCamp'); pg.wait_for_timeout(4000)
    chk(pg.evaluate('S.tCamp') == '' and pg.locator('#tTodasCamp').count() == 0, '"Ver todas as campanhas" tira o filtro')
    # ---------------- Dashboard ----------------
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and mes = 10")
    front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 7000)
    t = pg.inner_text('#main')
    chk(pg.locator('#pgEvo svg.gc').count() == 2, 'Dashboard: linhas de receita/lucro e de margem por mês')
    chk(pg.evaluate("[...document.querySelectorAll('#pgEvo svg.gc')][0].textContent.includes('nov/26')") is False, 'evolução não passa do mês atual')
    chk(pg.locator('#pgMetaIr').count() == 1, 'sem meta do mês: estado vazio com atalho para cadastrar')
    chk(pg.locator('#pgProd .gc-bhl').count() >= 1 and pg.locator('#pgCampR .gc-bhl').count() >= 1, 'receita por produto e por campanha em barras')
    soma = pg.evaluate("[...document.querySelectorAll('#pgProd .gc-bhl')].length")
    chk(pg.locator('details.gc-det').count() == 2 and pg.locator('details.gc-det[open]').count() == 0, 'DRE e fluxo de caixa recolhidos (abrem com um clique)')
    pg.locator('details.gc-det summary').first.click(); pg.wait_for_timeout(300)
    chk(pg.locator('details.gc-det[open] [data-dre]').count() > 0, 'DRE abre e continua clicável')
    pg.locator('#pgProd button.gc-bhl').first.click(); pg.wait_for_timeout(3500)
    chk(pg.locator('#arvRoot .arv').is_visible() and 'Receita' in pg.inner_text('#arvRoot'), 'clicar numa barra de produto abre a árvore com as vendas')
    pg.keyboard.press('Escape'); pg.wait_for_timeout(400)
    sql(f"insert into planejamento_mensal (workspace_id, ano, mes, meta_leads, meta_vendas, meta_receita) values ('{WS}', 2026, 10, 100, 20, 50000)")
    front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 7000)
    chk(pg.locator('#pgRit .gc-rit').count() == 3, 'com meta: ritmo de receita, vendas e leads')
    chk('Passaram 48% dos dias do mês' in pg.inner_text('#pgRit'), 'fração do mês: dia 15 de 31')
    sql(f"delete from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and mes = 10")
    # ---------------- Financeiro ----------------
    front.vai(pg, 'fin-dash', '', 6000)
    card = pg.evaluate("[...document.querySelectorAll('#main .kpi')].find(k => k.innerText.startsWith('Resultado no período')).querySelector('.v').innerText")
    cas = pg.locator('#main svg.gc rect')
    chk(cas.count() >= 3, 'Financeiro: cascata do resultado')
    tot = pg.evaluate("[...document.querySelectorAll('#main svg.gc g.gc-clk')].pop().querySelector('title').textContent")
    chk(abs(num(tot.split(':')[1]) - num(card)) < 0.01, 'a barra "Resultado" bate com o cartão (%s = %s)' % (tot.split(':')[1].strip(), card))
    rpm = pg.evaluate("[...document.querySelectorAll('#main .panel')].find(p => p.querySelector('h2') && p.querySelector('h2').innerText === 'Resultado por mês').innerText")
    chk('11/2026' not in rpm and '12/2026' not in rpm, '"Resultado por mês" não mostra meses futuros')
    # ---------------- Custos e margens ----------------
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-10', ver: 'area' }", 7000)
    t = pg.inner_text('#main')
    chk('Custo por área · 10/2026 contra 09/2026' in t, 'Custos: custo por área contra o mês anterior')
    tem_dre = 'Margens e meta' in t
    chk((not tem_dre) or pg.locator('#main .gc-bul').count() == 1, 'Custos: receita × equilíbrio × cenários (bullet)')
    if tem_dre:
        eq = pg.evaluate("[...document.querySelectorAll('.gc-bul .gc-mk')].map(x => x.title)")
        chk(any(x.startswith('Equilíbrio') for x in eq) and len(eq) == 4, 'bullet tem equilíbrio e os 3 cenários')
    chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
