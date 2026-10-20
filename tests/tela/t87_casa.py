import json, os, tempfile
from playwright.sync_api import sync_playwright
# Teste de tela da v0.87 (módulo Casa dentro da operação) com banco simulado.
# Rodar: python3 tests/tela/t87_casa.py (precisa de playwright + chromium)
HTML = os.path.join(tempfile.gettempdir(), 't87_growths.html')
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa — Operação', 'modo_produto': 'completo', 'agencia': True}, {'id': 'wc', 'nome': 'Casa', 'modo_produto': 'completo', 'casa_de': W}, {'id': 'w2', 'nome': 'Cliente Beta', 'modo_produto': 'completo'}],
  'transferencias_casa': [dict(id='t0', ws_origem=W, ws_casa='wc', data='2026-10-05', valor=2000, descricao='Rebecka — 09/2026', conta_pagar_id='x', desfeita_em=None)],
  'rpc:sou_equipe_interna': True,
  'plano_contas': ws([dict(id='pcB', codigo='1.1.01', nome='Bancos', tipo='ativo', aceita_lancamento=True), dict(id='pcC', codigo='2.1.01.02', nome='Cartão de crédito', tipo='passivo', aceita_lancamento=True),
                      dict(id='pcR', codigo='4.1.03', nome='Salários recebidos', tipo='receita', aceita_lancamento=True), dict(id='pcD', codigo='6.2.01', nome='Ferramentas', tipo='despesa', aceita_lancamento=True),
                      dict(id='pcPL', codigo='6.2.04', nome='Pró-labore', tipo='despesa', aceita_lancamento=True), dict(id='pcDL', codigo='3.1.02', nome='Distribuição de lucros', tipo='patrimonio', aceita_lancamento=True)])
                  + [dict(id='cB', workspace_id='wc', codigo='1.1.01', nome='Bancos', tipo='ativo', aceita_lancamento=True), dict(id='cR', workspace_id='wc', codigo='4.1.03', nome='Salários e pró-labore recebidos', tipo='receita', aceita_lancamento=True)],
  'contas_bancarias': ws([dict(id='b1', nome='Conta Nubank', banco='Nubank', saldo_inicial=1000, conta_contabil_id='pcB', padrao=True, ativa=True, tipo='conta'),
                          dict(id='k1', nome='Cartão de Crédito', banco='Nubank', saldo_inicial=0, conta_contabil_id='pcC', padrao=False, ativa=True, tipo='cartao', dia_vencimento=10)])
                     + [dict(id='bc', workspace_id='wc', nome='Conta da casa', saldo_inicial=0, conta_contabil_id='cB', padrao=True, ativa=True, tipo='conta')],
  'movimentacoes_bancarias': ws([dict(id='m1', conta_bancaria_id='b1', data='2026-09-20', tipo='entrada', valor=500, descricao='Recebimento setembro', lancamento_id='l1'),
                                 dict(id='m2', conta_bancaria_id='b1', data='2026-10-03', tipo='saida', valor=50, descricao='Pagamento: Meet', lancamento_id='l2'),
                                 dict(id='m3', conta_bancaria_id='b1', data='2026-10-05', tipo='entrada', valor=1000, descricao='Recebimento: Contrato #10', lancamento_id='l3'),
                                 dict(id='m4', conta_bancaria_id='k1', data='2026-10-02', tipo='saida', valor=26.91, descricao='Pagamento: Lovable', lancamento_id='l4')]),
  'v_cartoes_fatura': ws([dict(conta_bancaria_id='k1', nome='Cartão de Crédito', banco='Nubank', dia_vencimento=10, ativa=True, fatura_aberta=26.91, compras=26.91, pagamentos=0)]),
  'contas_receber': ws([dict(id='r1', valor=1000, vencimento='2026-10-05', status='recebido', data_recebimento='2026-10-05', conta_bancaria_id='b1', contrato_id='ct1', venda_id=None, descricao='Contrato #10 – parcela 1/3', desconto=0, substituida_por=None),
                        dict(id='r2', valor=1000, vencimento='2026-11-05', status='previsto', contrato_id='ct1', venda_id=None, descricao='Contrato #10 – parcela 2/3', desconto=0, substituida_por=None),
                        dict(id='r3', valor=300, vencimento='2026-10-01', status='previsto', contrato_id=None, venda_id=None, conta_receita_id='pcR', descricao='Reembolso', desconto=0, substituida_por=None)]),
  'contratos': ws([dict(id='ct1', numero=10, pessoa_id='pe1')]), 'pessoas': ws([dict(id='pe1', nome='Fernanda')]), 'vendas': [],
  'contas_pagar': ws([dict(id='cp1', descricao='Meet', valor=50, vencimento='2026-10-03', competencia='2026-10-01', status='pago', data_pagamento='2026-10-03', conta_bancaria_id='b1', fornecedor_id=None, substituida_por=None, estimativa=False),
                      dict(id='cpPL', descricao='Rebecka — 10/2026', valor=10000, vencimento='2026-10-30', competencia='2026-10-01', status='previsto', conta_bancaria_id=None, fornecedor_id=None, substituida_por=None, estimativa=False, conta_despesa_id='pcPL'),
                      dict(id='cp2', descricao='Servidor', valor=64.99, vencimento='2026-10-20', competencia='2026-10-01', status='previsto', conta_bancaria_id=None, fornecedor_id='f1', substituida_por=None, estimativa=False, forma_pagamento_id=None)]),
  'fornecedores': ws([dict(id='f1', nome='Hostinger')]) + [dict(id='f2', workspace_id='wc', nome='Condomínio')],
  'formas_pagamento': ws([dict(id='fp1', nome='Cartão da empresa', tipo='cartao', conta_bancaria_id=None, ativo=True)]),
  'rpc:fin_dashboard_periodo': {'projecao': [{'d': '2026-10-10', 'saldo': 2450}], 'resultado_por_mes': [], 'maiores_despesas': [], 'saldos': [{'nome': 'Conta Nubank', 'saldo': 2450}],
     'caixa': 2450, 'n_contas': 1, 'a_receber': {'valor': 1300, 'qtd': 2, 'atraso': 300}, 'a_pagar': {'valor': 64.99, 'qtd': 1, 'atraso': 0}, 'caixa_30d': 3685.01,
     'receitas_mes': 1000, 'despesas_mes': 141.81, 'resultado_mes': 858.19, 'pct_resultado_mes': 0.85, 'proximos_receber': [], 'proximos_pagar': []},
  'rpc:receber_periodo': {'a_receber': {'valor': 1300, 'qtd': 2, 'de_contratos': 1000}, 'atraso': {'valor': 300, 'qtd': 1}, 'recebido': {'valor': 1000, 'qtd': 1}, 'mrr': 0, 'arr': 0, 'por_mes': [], 'por_cliente': []},
  'funis': ws([dict(id='fu1', nome='Lançamento padrão', tipo='lancamento', ativo=True)]), 'produtos': ws([dict(id='p1', nome='Mentoria', ativo=True)]),
  'campanhas': [], 'projetos': [], 'projeto_atividades': [], 'projeto_modelos': [], 'equipe': ws([dict(id='e1', nome='Ana', ativo=True)]),
}
RPC = r"""
window.__RPC = {
  pagar_fatura_cartao: (a, D) => { if (!(a.p_valor > 0)) throw new Error('Informe o valor'); return 'lf1'; },
  receber_avulso_criar: (a, D) => { const id = 'ra' + D.contas_receber.length; D.contas_receber.push({ id, workspace_id: a.p_ws, valor: a.p_valor, vencimento: a.p_vencimento, status: 'previsto', descricao: a.p_descricao, conta_receita_id: a.p_conta_receita, conta_bancaria_id: a.p_conta_bancaria, contrato_id: null, venda_id: null, desconto: 0, substituida_por: null }); return id; },
  receber_avulso_cancelar: (a, D) => { D.contas_receber.find(x => x.id === a.p_conta_receber).status = 'cancelado'; return null; },
  campanha_aplicar_estrategia: (a, D) => 4,
  campanha_gerar_atividades: (a, D) => 9,
  transferir_para_casa: (a, D) => { D.transferencias_casa.push({ id: 't1', ws_origem: a.p_ws, ws_casa: 'wc', data: a.p_data, valor: a.p_valor, descricao: 'x', conta_pagar_id: a.p_conta_pagar, desfeita_em: null }); return 't1'; },
  desfazer_transferencia_casa: (a, D) => { D.transferencias_casa.find(t => t.id === a.p_id).desfeita_em = '2026-10-10'; return null; }
};"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])

def go(pg, view, extra=''):
    pg.evaluate("([v,e])=>{S.ws='w1'; S.view=v; eval(e); render();}", [view, extra]); pg.wait_for_timeout(700)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ')
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
def calls(pg, n): return pg.evaluate("n=>window.__calls.filter(c=>c[0]==='rpc'&&c[1]===n).map(c=>c[2])", n)
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:400]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def submit(pg): pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(700)
def fecha(pg): pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")


with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1400, 'height': 1800}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1200)
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    ops = pg.evaluate("[...document.querySelectorAll('#wsSel option')].map(o=>o.textContent)")
    chk('Casa' not in ops and 'Mathisa — Operação' in ops and 'Cliente Beta' in ops, 'Casa sai do seletor de workspace', ops)
    pg.evaluate("S.ws='w1'; S.wsBase='w1'; S.view='fin-dash'; S.per={pre:'pers',de:'2026-10-01',ate:'2026-10-31'}; S.abertos.Casa=true; render()"); pg.wait_for_timeout(800)
    nav = tx(pg, '#nav'); chk('CASA' in nav.upper() and 'Contas bancárias e cartões' in nav, 'grupo Casa no menu da operação', nav[:500])
    pg.click('#nav button[data-v=casa-dash]'); pg.wait_for_timeout(900)
    chk(pg.evaluate("S.ws") == 'wc' and pg.evaluate("S.wsBase") == 'w1', 'na Casa, os dados vêm do livro da Casa', pg.evaluate("[S.ws,S.wsBase]"))
    c = calls(pg, 'fin_dashboard_periodo'); chk(c and c[-1]['p_ws'] == 'wc', 'dashboard da Casa pede os números da Casa', c[-1:] if c else c)
    t = tx(pg); chk('Casa · finanças pessoais' in t and 'Transferências da empresa para a Casa' in t and 'Rebecka — 09/2026' in t, 'faixa da Casa e lista de transferências', t[:500])
    chk(pg.evaluate("document.querySelector('#nav button[data-v=casa-dash]').classList.contains('on')"), 'menu marca Casa > Dashboard')
    # atalho de dentro da Casa continua na Casa
    pg.click('#main [data-go=fin-receber]'); pg.wait_for_timeout(800)
    chk(pg.evaluate("S.view") == 'casa-receber' and pg.evaluate("S.ws") == 'wc', 'atalho Contas a receber dentro da Casa abre a da Casa', pg.evaluate("S.view"))
    go_ = lambda v: (pg.evaluate("v=>{S.view=v; render();}", v), pg.wait_for_timeout(800))
    go_('casa-bancos'); t = tx(pg)
    chk('Conta da casa' in t and 'Conta Nubank' not in t, 'Contas bancárias da Casa mostram só as da Casa', t[:400])
    # transferência
    go_('casa-dash'); pg.click('#casaTransf'); pg.wait_for_timeout(700)
    o = pg.evaluate("[...document.querySelectorAll('#tcCp option')].map(o=>o.textContent)")
    chk(o and o[0].startswith('Pró-labore · Rebecka') and o[-1].startswith('Nenhuma'), 'pró-labore aparece primeiro; opção de retirada', o)
    bo = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=bo] option')].map(o=>o.value)"); bc = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=bc] option')].map(o=>o.value)")
    chk(bo == ['b1'] and bc == ['bc'], 'sai das contas da empresa (sem cartão) e entra nas da Casa', [bo, bc])
    pg.fill('#tcV', '4000'); submit(pg)
    c = calls(pg, 'transferir_para_casa')
    chk(c and c[-1]['p_ws'] == 'w1' and c[-1]['p_conta_pagar'] == 'cpPL' and c[-1]['p_valor'] == 4000 and c[-1]['p_banco_casa'] == 'bc' and c[-1]['p_receita_casa'] == 'cR' and c[-1]['p_conta_contabil_origem'] is None, 'RPC transferir_para_casa com pró-labore, 4.000, conta e receita da Casa', c[-1:] if c else c)
    pg.click('#casaTransf'); pg.wait_for_timeout(700); pg.select_option('#tcCp', ''); pg.wait_for_timeout(200)
    chk(pg.evaluate("getComputedStyle(document.querySelector('#tcRetL')).display") != 'none', 'retirada mostra a conta contábil (Distribuição de lucros)')
    pg.fill('#tcV', '1500'); submit(pg); c = calls(pg, 'transferir_para_casa')
    chk(c[-1]['p_conta_pagar'] is None and c[-1]['p_conta_contabil_origem'] == 'pcDL', 'retirada usa 3.1.02', c[-1])
    pg.click('[data-tdx=t0]'); pg.wait_for_timeout(400); submit(pg)
    chk(calls(pg, 'desfazer_transferencia_casa'), 'desfazer transferência')
    # voltar para a empresa
    go_('fin-dash')
    chk(pg.evaluate("S.ws") == 'w1' and 'Casa · finanças pessoais' not in tx(pg), 'Financeiro da empresa volta para o livro da empresa')
    c = calls(pg, 'fin_dashboard_periodo'); chk(c[-1]['p_ws'] == 'w1', 'dashboard da empresa pede os números da empresa')
    # outro cliente não tem Casa
    pg.select_option('#wsSel', 'w2'); pg.wait_for_timeout(900)
    chk('casa-dash' not in pg.inner_html('#nav'), 'cliente sem Casa não vê o grupo Casa')
    real = [e for e in errs if 'funil' not in e]
    chk(not real, 'sem erro de JavaScript na página', real)
    b.close()
print('\n' + ('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
