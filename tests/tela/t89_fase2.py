import json, os, tempfile
from playwright.sync_api import sync_playwright
# Teste de tela da v0.89 (Fase 2: captação, metas por tipo, vendas por canal, abandono, aceite, público frio e quente).
# Rodar: python3 tests/tela/t89_fase2.py (precisa de playwright + chromium)
HTML = os.path.join(tempfile.gettempdir(), 't89_growths.html')
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
  'campanhas': ws([dict(id='c1', nome='Black', modelo='lancamento', status='ativa', data_inicio='2026-10-01', data_fim='2026-10-31', funil_id=None, produto_id='p1', fases={})]), 'projetos': [],
  'canais': ws([dict(id='k1', codigo='meta_ads', nome='Meta Ads', ativo=True), dict(id='k2', codigo='google_ads', nome='Google Ads', ativo=True)]),
  'campanha_canais': ws([dict(id='cc1', campanha_id='c1', canal='meta_ads', utm_campaign='bf_meta_frio', temperatura='frio', orcamento=1000, meta_leads=100)]),
  'campanha_metas': ws([dict(id='mt1', campanha_id='c1', tipo='cpl', valor=150)]),
  'checkout_abandonos': ws([dict(id='ab1', campanha_id='c1', pessoa_id='pe1', produto_id='p1', valor=997, abandonado_em='2026-10-08T10:00:00Z', recuperado_venda_id='v9', recuperado_em='2026-10-09T10:00:00Z')]),
  'campanha_ofertas': ws([dict(id='o1', campanha_id='c1', produto_id='p1', nome='Curso', papel='principal', preco=997)]), 'ofertas': [], 'v_marketing_campanha': [], 'projeto_atividades': [], 'projeto_modelos': [], 'equipe': ws([dict(id='e1', nome='Ana', ativo=True)]),
}
RPC = r"""
window.__RPC = {
  pagar_fatura_cartao: (a, D) => { if (!(a.p_valor > 0)) throw new Error('Informe o valor'); return 'lf1'; },
  receber_avulso_criar: (a, D) => { const id = 'ra' + D.contas_receber.length; D.contas_receber.push({ id, workspace_id: a.p_ws, valor: a.p_valor, vencimento: a.p_vencimento, status: 'previsto', descricao: a.p_descricao, conta_receita_id: a.p_conta_receita, conta_bancaria_id: a.p_conta_bancaria, contrato_id: null, venda_id: null, desconto: 0, substituida_por: null }); return id; },
  receber_avulso_cancelar: (a, D) => { D.contas_receber.find(x => x.id === a.p_conta_receber).status = 'cancelado'; return null; },
  campanha_aplicar_estrategia: (a, D) => 4,
  campanha_gerar_atividades: (a, D) => 9,
  campanha_captacao: () => ({ leads: 120, tentativas: 150, repetidas: 30, taxa_duplicidade: 20, alunos: 20, nao_alunos: 100, ja_clientes: 15, qualificados: 60, por_canal: [{ canal: 'meta_ads', temperatura: 'frio', leads: 90, repetidas: 25, qualificados: 40, alunos: 10 }, { canal: 'sem origem', temperatura: null, leads: 30, repetidas: 5, qualificados: 20, alunos: 10 }] }),
  campanha_metas_painel: () => [{ id: 'mt1', tipo: 'cpl', meta: 150, realizado: 180, pct: 120, ok: false, menor_melhor: true, canal: 'meta_ads', temperatura: 'frio' }, { id: 'mt2', tipo: 'roas', meta: 0, realizado: 2.5, pct: null, ok: null }],
  abandonos_resumo: () => ({ abandonos: 10, valor_abandonado: 9970, recuperados: 3, valor_recuperado: 2991, taxa_recuperacao: 30 }),
  vendas_por_canal: (a) => ({ modelo: a.p_modelo || 'ultimo_toque', canais: a.p_modelo === 'primeiro_toque' ? [{ canal: 'google_ads', nome: 'Google Ads', temperatura: null, vendas: 2, clientes: 2, receita: 2000, investimento: null, cac: null, roas: null }]
     : [{ canal: 'meta_ads', nome: 'Meta Ads', temperatura: 'frio', vendas: 4, clientes: 4, receita: 4000, investimento: 1000, cac: 250, roas: 4 }] }),
  abandono_registrar: (a, D) => { D.checkout_abandonos.push({ id: 'ab2', workspace_id: a.p_ws, valor: a.p_valor, abandonado_em: new Date().toISOString(), pessoa_id: null }); return 'ab2'; },
  campanha_ofertas_resultado: () => [{ id: 'o1', produto: 'Curso', nome: 'Curso', papel: 'principal', preco: 997, vendas: 10, receita: 9970, aceite: null }, { id: 'o2', produto: 'Bump', nome: 'Bump', papel: 'order_bump', preco: 47, vendas: 4, receita: 188, aceite: 40 }]
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
    chk('Versão 0.8' in pg.inner_text('body') or 'Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='captacao'")
    t = tx(pg)
    chk('Captação e metas' in t and 'Leads únicos' in t and '120' in t and 'duplicidade de 20,0%' in t, 'aba Captação e metas com leads únicos e duplicidade', t[:600])
    chk('Frio' in t and 'Alunos / não alunos' in t and 'Checkout abandonado' in t, 'público, segmento e abandono na campanha')
    chk('CPL' in t and 'fora' in t and '120,0%' in t and 'ROAS (bruto)' in t, 'metas por tipo com realizado, % e status', t[t.find('Metas por tipo'):][:500])
    chk('Vendas por canal' in t and 'Meta Ads' in t and '4,00x' in t, 'vendas por canal da campanha (ROAS bruto)')
    c = calls(pg, 'vendas_por_canal'); chk(c and c[-1]['p_campanha'] == 'c1', 'vendas por canal filtrada pela campanha')
    pg.select_option('[data-vpcm]', 'primeiro_toque'); pg.wait_for_timeout(500)
    chk('Google Ads' in tx(pg) and 'sem dado' in tx(pg), 'troca para primeiro toque; investimento sem dado não vira zero')
    pg.click('#mtNova'); pg.wait_for_timeout(500)
    pg.select_option('#modalRoot select[name=tipo]', 'leads'); pg.fill('#modalRoot input[name=valor]', '300'); pg.select_option('#modalRoot select[name=canal]', 'meta_ads'); pg.select_option('#modalRoot select[name=segmento]', 'nao_aluno'); submit(pg)
    mt = D(pg, 'campanha_metas'); chk(any(x.get('tipo') == 'leads' and x.get('valor') == 300 and x.get('canal') == 'meta_ads' and x.get('segmento') == 'nao_aluno' and x.get('fase') is None for x in mt), 'cria meta por canal e segmento', mt)
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='ofertas'"); t = tx(pg)
    chk('ACEITE' in t.upper() and '40%' in t, 'aceite do order bump na aba de ofertas', t[t.find('ACEITE'):][:400])
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='resumo'"); t = tx(pg)
    chk('Frio' in t, 'canal mostra o público frio')
    pg.click('[data-ek=cc1]'); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot select[name=temperatura]').count() == 1 and pg.input_value('#modalRoot select[name=temperatura]') == 'frio', 'formulário do canal tem público frio ou quente')
    fecha(pg)
    go(pg, 'crm-abandonos'); t = tx(pg)
    chk('Abandono de checkout' in t and '30,0%' in t and 'recuperado' in t, 'tela de abandono com recuperação', t[:500])
    pg.click('#abNovo'); pg.wait_for_timeout(400); pg.fill('#modalRoot input[name=telefone]', '11999990000'); pg.fill('#modalRoot input[name=valor]', '497'); submit(pg)
    c = calls(pg, 'abandono_registrar'); chk(c and c[-1]['p_telefone'] == '11999990000' and c[-1]['p_valor'] == 497, 'registrar abandono pelo banco', c[-1:])
    pg.evaluate("(async()=>{const d=document.createElement('div');d.id='vpcT';document.body.appendChild(d);await vendasPorCanalPainel(d,'2026-10-01','2026-10-31',null);})()"); pg.wait_for_timeout(500)
    chk('Último toque (oficial)' in tx(pg, '#vpcT'), 'painel de vendas por canal para o dashboard de vendas')
    real = [e for e in errs if 'funil' not in e]
    chk(not real, 'sem erro de JavaScript na página', real)
    b.close()
print('\n' + ('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
