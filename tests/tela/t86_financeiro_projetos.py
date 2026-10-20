import json, os, tempfile
from playwright.sync_api import sync_playwright
# Teste de tela da v0.86 (extrato, listas do dashboard, cartão, a receber avulsa, projeto de campanha) com banco simulado.
# Rodar: python3 tests/tela/t86_financeiro_projetos.py (precisa de playwright + chromium)
HTML = os.path.join(tempfile.gettempdir(), 't86_growths.html')
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}],
  'rpc:sou_equipe_interna': True,
  'plano_contas': ws([dict(id='pcB', codigo='1.1.01', nome='Bancos', tipo='ativo', aceita_lancamento=True), dict(id='pcC', codigo='2.1.01.02', nome='Cartão de crédito', tipo='passivo', aceita_lancamento=True),
                      dict(id='pcR', codigo='4.1.03', nome='Salários recebidos', tipo='receita', aceita_lancamento=True), dict(id='pcD', codigo='6.2.01', nome='Ferramentas', tipo='despesa', aceita_lancamento=True)]),
  'contas_bancarias': ws([dict(id='b1', nome='Conta Nubank', banco='Nubank', saldo_inicial=1000, conta_contabil_id='pcB', padrao=True, ativa=True, tipo='conta'),
                          dict(id='k1', nome='Cartão de Crédito', banco='Nubank', saldo_inicial=0, conta_contabil_id='pcC', padrao=False, ativa=True, tipo='cartao', dia_vencimento=10)]),
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
                      dict(id='cp2', descricao='Servidor', valor=64.99, vencimento='2026-10-20', competencia='2026-10-01', status='previsto', conta_bancaria_id=None, fornecedor_id='f1', substituida_por=None, estimativa=False, forma_pagamento_id=None)]),
  'fornecedores': ws([dict(id='f1', nome='Hostinger')]),
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
  campanha_gerar_atividades: (a, D) => 9
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
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("Date.prototype.__h = 1; window.hoje = () => '2026-10-10'")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')

    # ---------- 1-3: dashboard clicável ----------
    go(pg, 'fin-dash', "S.per={pre:'pers',de:'2026-10-01',ate:'2026-10-31'}")
    chk(pg.locator('.kpi.clic').count() == 3, 'três cartões clicáveis (saldo, a receber, a pagar)', pg.locator('.kpi.clic').count())
    t = tx(pg); chk('Cartões de crédito' in t and 'Cartão de Crédito' in t and '26,91' in t, 'painel de cartões com a fatura em aberto', t[-600:])
    pg.click('.kpi.clic[data-fin=extrato]'); pg.wait_for_timeout(600)
    t = tx(pg, '#modalRoot')
    chk('Extrato' in t and 'Saldo anterior' in t and '1.500,00' in t, 'extrato abre na conta padrão com saldo anterior (1.000 + 500 de setembro)', t[:500])
    chk('Pagamento: Meet' in t and 'Recebimento: Contrato #10' in t and 'Recebimento setembro' not in t.split('Saldo anterior')[-1].split('Saldo final')[0], 'extrato mostra só os movimentos do período', t)
    chk('2.450,00' in t, 'saldo final corrido 1.500 − 50 + 1.000 = 2.450', t)
    pg.select_option('#exConta', 'k1'); pg.wait_for_timeout(500); t = tx(pg, '#modalRoot')
    chk('Pagamento: Lovable' in t and 'Fatura' in t and 'Pagamento: Meet' not in t, 'trocar para o cartão mostra a fatura dele', t[:600])
    pg.fill('#exDe', '2026-09-01'); pg.dispatch_event('#exDe', 'change'); pg.select_option('#exConta', 'b1'); pg.wait_for_timeout(500)
    chk('Recebimento setembro' in tx(pg, '#modalRoot'), 'mudar o período inclui setembro')
    fecha(pg)
    pg.click('.kpi.clic[data-fin=receber]'); pg.wait_for_timeout(600); t = tx(pg, '#modalRoot')
    chk('Contas a receber' in t and 'Reembolso' in t and 'Avulsa' in t and 'parcela 1/3' not in t, 'lista a receber: em aberto + atraso, sem a já recebida', t[:600])
    pg.select_option('#flSt', 'feito'); pg.wait_for_timeout(300); t = tx(pg, '#modalRoot')
    chk('parcela 1/3' in t and 'Reembolso' not in t and 'Conta Nubank' in t, 'filtro Recebidas mostra a parcela recebida e a conta', t[:600])
    fecha(pg)
    pg.click('.kpi.clic[data-fin=pagar]'); pg.wait_for_timeout(600); t = tx(pg, '#modalRoot')
    chk('Contas a pagar' in t and 'Servidor' in t and 'Hostinger' in t and 'Meet' not in t, 'lista a pagar em aberto', t[:600])
    pg.select_option('#flSt', 'todas'); pg.wait_for_timeout(300)
    chk('Meet' in tx(pg, '#modalRoot'), 'filtro Todas inclui a paga')
    fecha(pg)
    pg.click('tr[data-sx]'); pg.wait_for_timeout(600)
    chk(pg.evaluate("document.querySelector('#exConta') && document.querySelector('#exConta').value") == 'b1', 'clicar na linha do saldo por conta abre o extrato dela')
    fecha(pg)

    # ---------- 4: cartão ----------
    pg.click('[data-cpf=k1]'); pg.wait_for_timeout(500)
    opt = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=banco] option')].map(o=>o.value)")
    vv = pg.input_value('#modalRoot input[name=valor]'); chk(opt == ['b1'] and vv in ('26.91', 'R$ 26,91'), 'pagar fatura: só contas no select, valor = fatura', [opt, vv])
    submit(pg); c = calls(pg, 'pagar_fatura_cartao')
    chk(c and c[-1]['p_cartao'] == 'k1' and c[-1]['p_banco'] == 'b1' and abs(c[-1]['p_valor'] - 26.91) < 1e-9, 'RPC pagar_fatura_cartao com cartão, banco e valor', c)
    go(pg, 'cad-bancos'); t = tx(pg)
    chk('cartão de crédito' in t, 'cadastro de contas mostra o tipo', t[:400])
    pg.evaluate("[...document.querySelectorAll('#main button')].find(b=>/Nova|Novo|\\+/.test(b.textContent)).click()"); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot select[name=tipo]').count() == 1 and pg.locator('#modalRoot input[name=dia_vencimento]').count() == 1, 'formulário tem tipo e dia de vencimento')
    pc = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=conta_contabil_id] option')].map(o=>o.textContent)")
    chk(any('2.1.01.02' in x for x in pc) and any('1.1.01' in x for x in pc) and not any('6.2.01' in x for x in pc), 'conta contábil aceita banco (1.1) e passivo (2.1)', pc)
    fecha(pg)
    pg.evaluate("modalPagarConta('cp2')"); pg.wait_for_timeout(600)
    lab = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=banco] option')].map(o=>o.textContent)")
    chk(any('cartão de crédito' in x for x in lab) and len(lab) == 2, 'pagar conta permite escolher o cartão', lab)
    fecha(pg)
    pg.evaluate("modalBaixaParcela('r2', null, 1000)"); pg.wait_for_timeout(600)
    opt = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=conta] option')].map(o=>o.value)")
    chk(opt == ['b1'], 'recebimento não oferece o cartão', opt)
    fecha(pg)

    # ---------- 5: a receber avulsa ----------
    go(pg, 'fin-receber', "S.per={pre:'tudo',de:'',ate:''}"); t = tx(pg)
    chk('Avulsa' in t and 'Reembolso' in t, 'conta avulsa aparece com origem Avulsa', t[:800])
    pg.click('#recAvulso'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot input[name=descricao]', 'Salário'); pg.fill('#modalRoot input[name=valor]', '5000'); pg.fill('#modalRoot input[name=vencimento]', '2026-10-30')
    pg.select_option('#modalRoot select[name=meses]', '3'); submit(pg)
    c = calls(pg, 'receber_avulso_criar')
    chk(len(c) == 3 and [x['p_vencimento'] for x in c] == ['2026-10-30', '2026-11-30', '2026-12-30'] and c[0]['p_conta_receita'] == 'pcR' and c[0]['p_conta_bancaria'] == 'b1' and c[2]['p_descricao'] == 'Salário (3/3)', 'repetir 3 meses cria 3 contas com vencimentos mensais', c)
    t = tx(pg); chk('Salário (1/3)' in t, 'novas contas aparecem na lista', t[:400])
    pg.click('[data-ca=r3]'); pg.wait_for_timeout(400); submit(pg)
    chk(next(x for x in D(pg, 'contas_receber') if x['id'] == 'r3')['status'] == 'cancelado', 'cancelar avulsa chama receber_avulso_cancelar')
    pg.select_option('#rfOr', 'avulsa'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Salário' in t and 'Contrato #10' not in t, 'filtro Só avulsas', t[:600])

    # ---------- 10: projeto de campanha ----------
    pg.evaluate("""(()=>{ const D = window.__D; D.campanhas.push = function(...a){ Array.prototype.push.apply(this, a); a.forEach(c => D.projetos.push({ id: 'pj_' + c.id, workspace_id: c.workspace_id, nome: 'Campanha: ' + c.nome, campanha_id: c.id, status: 'planejado', criado_em: new Date().toISOString() })); return this.length; }; })()""")
    go(pg, 'prj-lista', 'S.projSel=null')
    pg.click('#pNovo'); pg.wait_for_timeout(600)
    chk(pg.evaluate("getComputedStyle(document.querySelector('#pjCamp')).display") == 'none', 'campos da campanha escondidos até marcar')
    pg.fill('#modalRoot input[name=nome]', 'Lançamento Novembro'); pg.check('#pjDeCamp')
    chk(pg.evaluate("getComputedStyle(document.querySelector('#pjCamp')).display") != 'none', 'marcar mostra modelo, estratégia e produto')
    pg.fill('#modalRoot input[name=data_fim_prevista]', '2026-11-30'); pg.select_option('#modalRoot select[name=camp_funil]', 'fu1'); pg.select_option('#modalRoot select[name=camp_produto]', 'p1')
    submit(pg)
    cs = D(pg, 'campanhas'); pj = D(pg, 'projetos')
    chk(len(cs) == 1 and cs[0]['nome'] == 'Lançamento Novembro' and cs[0]['modelo'] == 'lancamento' and cs[0]['data_fim'] == '2026-11-30' and cs[0]['funil_id'] == 'fu1' and cs[0]['produto_id'] == 'p1', 'cria a campanha com nome, fim, estratégia e produto', cs)
    chk(len(pj) == 1 and pj[0]['nome'] == 'Lançamento Novembro' and pj[0]['data_fim_prevista'] == '2026-11-30', 'não duplica o projeto: usa o da campanha e renomeia', pj)
    chk(calls(pg, 'campanha_aplicar_estrategia') and calls(pg, 'campanha_aplicar_estrategia')[-1]['p_funil'] == 'fu1', 'aplica a estratégia (gera as atividades dos blocos)')
    chk(pg.evaluate("S.projSel") == pj[0]['id'] and 'Atividades dos blocos' in tx(pg), 'abre o projeto criado, com o botão de atividades dos blocos', pg.evaluate("S.projSel"))
    pg.click('#pBlocos'); pg.wait_for_timeout(500)
    chk(calls(pg, 'campanha_gerar_atividades') and calls(pg, 'campanha_gerar_atividades')[-1]['p_campanha'] == cs[0]['id'], 'botão chama campanha_gerar_atividades')
    # projeto comum continua igual
    go(pg, 'prj-lista', 'S.projSel=null'); pg.click('#pNovo'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot input[name=nome]', 'Projeto interno'); submit(pg)
    chk(len(D(pg, 'campanhas')) == 1 and any(x['nome'] == 'Projeto interno' for x in D(pg, 'projetos')), 'projeto sem campanha não cria campanha')

    real = [e for e in errs if 'funil' not in e]
    chk(not real, 'sem erro de JavaScript na página', real)
    b.close()
print('\n' + ('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
