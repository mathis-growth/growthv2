"""v0.128: painel da campanha dia a dia (aba Dashboard da campanha): quadrinhos dentro/fora da meta, onde caiu, movimento por dia,
vídeos e criativos, vendas por dia, por produto e por papel da oferta. Banco fa, sem alteração."""
import sys, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
PERP, LANC = '284b5d0b-cab8-431e-836c-47983435a0d1', '54011ef1-34b7-44f1-978e-3d733d244899'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr)
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
brl = lambda t: float(t.replace('R$', '').replace('\xa0', '').replace(' ', '').replace('.', '').replace(',', '.'))
with sync_playwright() as p:
    b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
    erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
    front.vai(pg, 'mkt-camp', f"S.campSel = '{PERP}'; S.campTab = 'dash'; S.cp128 = null;", 12000)
    t = pg.inner_text('#main')
    chk(pg.locator('.cp128').count() == 1 and pg.locator('.cp128').evaluate("e => e.previousElementSibling && e.previousElementSibling.classList.contains('kpis')"), 'painel do dia a dia logo abaixo dos cartões da campanha')
    chk('16/09/2026 a 15/10/2026' in t and pg.locator('[data-cpper="30"].on').count() == 1, 'perpétuo abre nos últimos 30 dias')
    chk(pg.locator('#cpGrade .cp-gl b').count() == 7 and pg.locator('#cpGrade .cp-c').count() == 7 * 30, 'quadrinhos: 7 números × 30 dias')
    chk(pg.locator('#cpGrade .cp-c.bom').count() > 0, 'há dias verdes (dentro da meta ou melhor que a média)')
    # vendas do quadrinho = vendas aprovadas da campanha no dia
    dia = sql(f"select (data_venda at time zone 'America/Sao_Paulo')::date from vendas where campanha_id = '{PERP}' and status = 'aprovada' and data_venda >= '2026-09-16' group by 1 order by count(*) desc limit 1")
    n = sql(f"select count(*) from vendas where campanha_id = '{PERP}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date = '{dia}'")
    tit = pg.evaluate(f"[...document.querySelectorAll('#cpGrade .cp-c[data-cpdia=\"{dia}\"]')].map(b => b.title).find(t => t.startsWith('Vendas'))")
    chk(tit and tit.endswith(': ' + n), 'quadrinho de vendas de %s = %s venda(s) (%s)' % (dia, n, tit))
    # criativos: investimento total do período
    inv = float(sql(f"select coalesce(sum(custo), 0) from v_trafego_anuncio_dia where campanha_id = '{PERP}' and data between '2026-09-16' and '2026-10-15'"))
    soma = pg.evaluate("[...document.querySelectorAll('#cpCriat tbody tr')].map(r => r.children[2].innerText)")
    tot = sum(brl(x) for x in soma) + sum(brl(x) for x in pg.evaluate("[...document.querySelectorAll('#cpCriat details tbody tr')].map(r => r.children[1].innerText)"))
    chk(abs(tot - inv) < 0.05, 'criativos: investido soma o total dos anúncios no período (%.2f = %.2f)' % (tot, inv))
    chk('Melhor custo por lead' in pg.inner_text('#cpCriat'), 'criativos: aponta o melhor custo por lead')
    # onde caiu
    q = pg.inner_text('#cpQueda')
    chk('Últimos 7 dias (08/10 a 14/10)' in q and 'Leads' in q and 'CTR' in q, 'onde caiu: 7 dias completos contra os 7 anteriores, etapa por etapa')
    # vendas
    nV = sql(f"select count(*) from vendas where campanha_id = '{PERP}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-09-16' and '2026-10-15'")
    chk(pg.inner_text('#cpVend').startswith('Vendas da campanha') and (nV + ' venda(s)') in pg.inner_text('#cpVend'), 'vendas da campanha: %s venda(s) no período' % nV)
    chk(pg.locator('#cpLinhas svg.gc').count() == 1 and pg.locator('#cpLinhas [data-cpm]').count() == 9, 'movimento por dia: um gráfico com 9 métricas para escolher')
    # trocar o período
    pg.click('[data-cpper="14"]'); pg.wait_for_timeout(9000)
    chk(pg.locator('#cpGrade .cp-c').count() == 7 * 14, 'trocar para 14 dias redesenha os quadrinhos')
    # clicar num dia abre a Mídia paga só dele
    pg.locator('#cpGrade .cp-c[data-cpdia="2026-10-10"]').first.click(); pg.wait_for_timeout(6000)
    st = pg.evaluate('[S.view, S.tCamp, S.tDe, S.tAte]')
    chk(st == ['mkt-trafego', PERP, '2026-10-10', '2026-10-10'], 'clicar no dia abre a Mídia paga filtrada na campanha e no dia')
    # lançamento: campanha toda
    front.vai(pg, 'mkt-camp', f"S.campSel = '{LANC}'; S.campTab = 'dash'; S.cp128 = null;", 12000)
    chk('01/09/2026 a 30/09/2026' in pg.inner_text('.cp128') and pg.locator('[data-cpper="tudo"].on').count() == 1, 'lançamento abre na campanha toda (início ao fim)')
    chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
