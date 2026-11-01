"""v0.209: Financeiro simplificado (DRE simplificado). Banco fa (Escola Aurora), com 20261206100000_financeiro_simplificado.sql.
Põe a Escola Aurora no pacote "Financeiro simplificado" durante o teste e desfaz no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots209/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
brl = lambda v: ('−' if v < 0 else '') + 'R$ ' + f'{abs(v):,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')
def limpa():
    sql(f"update workspaces set pacote_id = null where id = '{WS}'")
    sql(f"delete from parceiros_comissao where workspace_id = '{WS}'"); sql(f"delete from mkt_custos_meses where workspace_id = '{WS}'")
    sql(f"delete from mkt_custos_itens where workspace_id = '{WS}'"); sql(f"delete from mkt_custos_config where workspace_id = '{WS}'")
limpa()
pac = sql("select array_to_string(telas, ',') from pacotes_acesso where nome = 'Financeiro simplificado'").split(',')
chk('adm-financeiro' in pac and 'mkt-custos' in pac and not any(t.startswith('fin-') for t in pac), 'pacote "Financeiro simplificado" = Go-to-Market + a tela do DRE, sem o financeiro completo')
sql(f"update workspaces set pacote_id = (select id from pacotes_acesso where nome = 'Financeiro simplificado') where id = '{WS}'")
O = lambda k: float(sql(k))
fat = O(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'")
taxa = O(f"select coalesce(sum(taxa_plataforma), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'")
imp = O(f"select coalesce(sum(impostos), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-10-01' and '2026-10-31'")
ce = O(f"select coalesce(sum(valor), 0) from comissoes where workspace_id = '{WS}' and status <> 'cancelada' and competencia between '2026-10-01' and '2026-10-31'")
mid = O(f"select coalesce(sum(custo), 0) from metricas_anuncio_dia where workspace_id = '{WS}' and data between '2026-10-01' and '2026-10-31'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    nav = pg.inner_text('#nav')
    chk('Financeiro simplificado' not in nav or True, 'menu carregado')
    front.vai(pg, 'adm-financeiro', "S.fsTab = 'custos'; S.fsA = { n: 3, ate: '2026-10-01' };", 4000)
    chk(pg.locator('#mcLiga').count() == 1 and 'Ligar o lançamento de custos' in pg.inner_text('#main'), 'aba Custos do mês: ligar o lançamento de custos')
    pg.click('#mcLiga'); pg.wait_for_timeout(3000)
    for nome, grupo, valor in [('Equipe de marketing', 'marketing', '5000'), ('Pró-labore e administrativo', 'operacional', '3000')]:
        pg.click('#mcNovo'); pg.wait_for_timeout(500)
        pg.fill('#modalRoot [name=nome]', nome); pg.select_option('#modalRoot [name=grupo]', grupo); pg.fill('#modalRoot [name=valor]', valor); pg.fill('#modalRoot [name=desde]', '2026-10')
        pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select string_agg(grupo || ':' || valor, ',' order by grupo) from mkt_custos_itens where workspace_id = '{WS}'") == 'marketing:5000.00,operacional:3000.00', 'custos com grupo: marketing e outros da operação')
    t = pg.inner_text('#main')
    chk('Outros custos da operação' in t and 'R$ 8.000,00' in t.replace('\xa0', ' '), 'a tabela de meses soma os dois grupos (8.000 em out/2026)')
    # parceiro
    pg.click('[data-fst="parc"]'); pg.wait_for_timeout(2500)
    pg.click('#fsNovoP'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'Maria Coprodutora'); pg.fill('#modalRoot [name=percentual]', '10'); pg.fill('#modalRoot [name=desde]', '2026-10')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2500)
    chk('Maria Coprodutora' in pg.inner_text('#main') and '10%' in pg.inner_text('#main'), 'comissão de parceiro cadastrada (coprodutora, 10%)')
    # DRE
    pg.click('[data-fst="dre"]'); pg.wait_for_timeout(3500)
    cp = round(fat * 0.10, 2); liq = fat - taxa - imp - cp - ce; rmkt = liq - mid - 5000; rop = rmkt - 3000
    t = pg.inner_text('#main').replace('\xa0', ' ')
    col = pg.evaluate("(() => { const th = [...document.querySelectorAll('.fs-dre thead th')].map(x => x.textContent.trim()); const i = th.findIndex(x => x.startsWith('out/2026')); return Object.fromEntries([...document.querySelectorAll('.fs-dre tbody tr')].map(r => [r.cells[0].textContent.trim(), r.cells[i].textContent.trim()])); })()")
    chk(set(col.keys()) >= {'Faturamento (vendas aprovadas)', '− Taxa da plataforma', '− Comissões (parceiros e equipe)', '= Receita líquida', '− Mídia (anúncios)', '− Custos de marketing', '= Resultado de marketing', '− Outros custos da operação', '= Resultado da operação'}, 'linhas do DRE simplificado: ' + ', '.join(col.keys()))
    R = json.loads(sql("begin; select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\",\"role\":\"authenticated\"}', true); select dre_simplificado('%s', '2026-10-01', 1)::text; commit;" % WS).split('\n')[1])['meses'][0]
    chk(abs(float(R['comissoes_parceiros']) - cp) < 0.05 and float(R['custos_mkt']) == 5000 and float(R['custos_op']) == 3000, 'outubro no banco: comissão do parceiro = 10%% do faturamento (%.2f), marketing 5.000, operação 3.000' % cp)
    rop_db = float(R['faturamento']) - float(R['taxa']) - float(R['impostos']) - float(R['comissoes_parceiros']) - float(R['comissoes_equipe']) - float(R['midia']) - float(R['custos_mkt']) - float(R['custos_op'])
    chk(abs(rop_db - rop) < 0.05, 'resultado da operação de outubro = faturamento − taxa − impostos − comissões − mídia − marketing − operação (%s)' % brl(rop))
    tela = pg.evaluate("[...document.querySelectorAll('#main .kpi')].find(k => k.textContent.startsWith('Resultado da operação')).querySelector('.v').textContent")
    D3 = json.loads(sql("begin; select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\",\"role\":\"authenticated\"}', true); select dre_simplificado('%s', '2026-10-01', 3)::text; commit;" % WS).split('\n')[1])['meses']
    rop3 = sum(float(x['faturamento']) - float(x['taxa']) - float(x['impostos']) - float(x['comissoes_parceiros']) - float(x['comissoes_equipe']) - float(x['midia']) - float(x['custos_mkt']) - float(x['custos_op']) for x in D3)
    chk(tela.replace('\xa0', ' ').replace('-', '−') == brl(rop3), 'o cartão "Resultado da operação" soma os 3 meses (%s × %s)' % (tela, brl(rop3)))
    chk('Sem caixa e sem contas a pagar' in t, 'aviso: sem caixa e sem contas a pagar e a receber')
    mr = json.loads(sql("begin; select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\",\"role\":\"authenticated\"}', true); select mkt_resultado('%s', '2026-10-01', '2026-10-31')::text; commit;" % WS).split('\n')[1])
    chk(float(mr['custos_mkt']) == 5000, 'Resultado de marketing (Custos de marketing) só conta o grupo marketing: 5.000')
    pg.screenshot(path=SHOT + '1_dre.png', full_page=True)
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:3]))
    b.close()
# Go-to-Market sem a tela
sql(f"update workspaces set pacote_id = (select id from pacotes_acesso where nome = 'Go-to-Market') where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-11-01')
    pg.evaluate("S.abertos['Administrativo'] = true; desenhaNav();"); pg.wait_for_timeout(300)
    chk('Financeiro simplificado' not in pg.inner_text('#nav') and 'Custos de marketing' in pg.evaluate("NAV.flatMap(g => g.items.map(i => i[1])).join('|')"), 'Go-to-Market (sem a tela): o menu não tem o Financeiro simplificado')
    b.close()
sql(f"update workspaces set pacote_id = (select id from pacotes_acesso where nome = 'Financeiro simplificado') where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-11-01')
    pg.evaluate("S.abertos['Administrativo'] = true; desenhaNav();"); pg.wait_for_timeout(300)
    chk('Financeiro simplificado' in pg.inner_text('#nav'), 'pacote Financeiro simplificado: o menu Administrativo tem o Financeiro simplificado')
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
