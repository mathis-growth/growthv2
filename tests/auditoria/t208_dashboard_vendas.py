"""v0.208: Dashboard de vendas no padrão: filtro de período (de, até, atalhos), números do período no topo (valor e número de
vendas, ticket, clientes novos, clientes ativos, lead → cliente) contra o período anterior; cadastros em "Cadastros e funil";
Vendas por plataforma no mesmo período. Banco fa (Escola Aurora), com 20261205100000_vendas_periodo.sql."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots208/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
brl = lambda v: 'R$ ' + f'{v:,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'crm-dash', "S.perD = { ini: '2026-10-01', fim: '2026-10-31' };", 6000)
    chk(pg.locator('#main [data-per-de]').input_value() == '2026-10-01' and pg.locator('#main [data-per-at] option').count() == 8, 'filtro de período: de, até e atalhos')
    k = pg.inner_text('#vdKpis').replace('\xa0', ' ')
    val = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
    nv = int(sql(f"select count(*) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'"))
    ativos = int(sql(f"select count(*) from pessoas where workspace_id = '{WS}' and status_cliente = 'ativo'"))
    chk(all(x in k for x in ['Valor das vendas', 'Vendas', 'Ticket médio', 'Clientes novos', 'Clientes ativos', 'Lead → cliente']), 'no topo: valor, vendas, ticket, clientes novos, ativos e lead → cliente')
    chk(brl(val) in k and ('\n%d\n' % nv) in k and brl(val / nv) in k, 'valor (%s), vendas (%d) e ticket conferem com o banco' % (brl(val), nv))
    chk(('\n%d\n' % ativos) in k and 'vs. 31/08/2026 a 30/09/2026' in k, 'clientes ativos (%d) e comparação com o período anterior do mesmo tamanho' % ativos)
    secs = pg.evaluate("[...document.querySelectorAll('#main > .dsec')].filter(s => !s.hidden).map(s => [s.querySelector('h2').textContent, [...s.querySelectorAll('.dsec-b > *')].map(e => e.id || e.className.split(' ')[0])])")
    geral = dict(secs).get('Visão geral', []); funil = dict(secs).get('Cadastros e funil', [])
    chk('vdKpis' in geral and 'kpis' in funil, 'os números do período em Visão geral; os de cadastros em Cadastros e funil: ' + json.dumps(secs, ensure_ascii=False)[:300])
    chk(pg.evaluate("getComputedStyle(document.querySelector('.per-padrao')).order") in ('1', '2'), 'o filtro fica no topo, junto do título')
    vp = pg.inner_text('#vpPlat').replace('\xa0', ' ')
    chk('01/10/2026 a 31/10/2026' in vp and brl(val) in vp and pg.locator('#vpPlat input[type=date]').count() == 0, 'Vendas por plataforma usa o mesmo período, sem filtro próprio')
    pg.screenshot(path=SHOT + '1_vendas.png', full_page=True)
    pg.select_option('#main [data-per-at]', 'mesant'); pg.wait_for_timeout(5000)
    chk(pg.input_value('#main [data-per-de]') == '2026-10-01' and pg.input_value('#main [data-per-ate]') == '2026-10-31', 'atalho "Mês passado" em 01/11 = outubro')
    pg.select_option('#main [data-per-at]', '7'); pg.wait_for_timeout(5000)
    chk(pg.input_value('#main [data-per-de]') == '2026-10-26' and pg.input_value('#main [data-per-ate]') == '2026-11-01', 'atalho "Últimos 7 dias"')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
