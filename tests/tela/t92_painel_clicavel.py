import json, os, tempfile, re
# Teste de tela da v0.92: no Dashboard principal (Administrativo), Saldo em banco, A receber e A pagar abrem o extrato e as listas.
# Rodar: python3 tests/tela/t92_painel_clicavel.py
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
src = open(SP + 't86_financeiro_projetos.py', encoding='utf-8').read()
cab = src[:src.index('with sync_playwright() as p:')].replace("'t86_growths.html'", "'t92_growths.html'")
cab = cab.replace("'funis': ws(", """'rpc:painel_gerencial': {'funil': {'total': 10, 'qualificados': 4, 'ativos': 2, 'clientes': 3, 'inativos': 1, 'pct_qualificados': 0.4},
     'vendas': {'aprovadas': 2, 'nao_aprovadas': 0, 'bruto': 2000, 'taxas': 0, 'impostos': 0, 'liquido': 2000},
     'caixa': {'saldo': 2450, 'a_receber': 1000, 'atraso_receber': 300, 'a_pagar': 64.99, 'atraso_pagar': 0},
     'resultado': {'lucro': 800, 'margem': 0.4, 'roi': 0.5}, 'recorrencia': {'mrr': 0, 'arr': 0, 'nrr': None, 'grr': None}, 'penetracao': {'pct': None, 'mercado': 0},
     'cac': {'novos': 0, 'custo_total': 0, 'custo_midia': 0, 'fora_cac': 0, 'com_rateio': False, 'cac_midia': None, 'cac_total': None, 'peso_margem': None, 'por_grupo': [], 'por_fornecedor': [], 'por_campanha': []},
     'fluxo': {'ate': '2026-11-09', 'previsto': [], 'realizado': [], 'qtd_previsto': 0, 'qtd_realizado': 0, 'entrou': 0, 'saiu': 0}, 'dre_resultado': []},
  'v_funil_campanha': [], 'v_dre_mensal': [], 'v_marketing_campanha': [],
  'funis': ws(""")
exec(cab)
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1400, 'height': 1800}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-10'; window.provisionaAuto = async () => {}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.92')
    go(pg, 'adm-painel')
    chk(pg.locator('.kpi.clic').count() == 3, 'Dashboard principal: saldo, a receber e a pagar clicáveis', pg.locator('.kpi.clic').count())
    pg.click('.kpi.clic[data-fin=extrato]'); pg.wait_for_timeout(700)
    t = tx(pg, '#modalRoot'); chk('Extrato' in t and 'Pagamento: Meet' in t, 'clicar no Saldo em banco abre o extrato com as transações', t[:400])
    fecha(pg)
    pg.click('.kpi.clic[data-fin=receber]'); pg.wait_for_timeout(700)
    t = tx(pg, '#modalRoot'); chk('Contrato #10' in t, 'clicar em A receber abre a lista', t[:400])
    fecha(pg)
    pg.click('.kpi.clic[data-fin=pagar]'); pg.wait_for_timeout(700)
    t = tx(pg, '#modalRoot'); chk('Servidor' in t, 'clicar em A pagar abre a lista', t[:400])
    fecha(pg)
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
