import json, os, tempfile
from playwright.sync_api import sync_playwright
# Teste de tela da v0.88 (Fase 1: qualidade do dado, dicionário, auditoria, cadastros repetidos, fechamento versionado, extrato no banco).
# Rodar: python3 tests/tela/t88_fase1.py (precisa de playwright + chromium)
HTML = os.path.join(tempfile.gettempdir(), 't88_growths.html')
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
  'campanhas': ws([dict(id='c1', nome='Black', modelo='lancamento', status='ativa')]), 'projetos': [],
  'campanha_fechamentos': ws([dict(id='fz1', campanha_id='c1', fechado_em='2026-10-01T12:00:00Z', versao=1, status='oficial', snapshot={'periodo': {'ini': '2026-09-01', 'fim': '2026-09-30'}}, motivo=None)]),
  'metricas_definicoes': [dict(codigo='saldo_banco', nome='Saldo em banco', formula='Saldo inicial + entradas − saídas das contas', fonte='contas_bancarias', sem_dado='saldo inicial', observacao=None, versao=1),
                          dict(codigo='cac', nome='CAC', formula='Custos ÷ clientes novos', fonte='contas_pagar', sem_dado='sem valor', observacao=None, versao=1)],
  'auditoria': ws([dict(id=1, tabela='vendas', registro_id='v-1', acao='alteracao', campos=['status'], antes={'status': 'aprovada'}, depois={'status': 'reembolsada'}, usuario_email='rebecka@x.com', origem='app', em=__import__('datetime').date.today().isoformat() + 'T15:00:00Z')]),  # relativo a hoje: a tela mostra só os últimos dias
  'v_pessoas_duplicadas': ws([dict(pessoa_a='pe1', pessoa_b='pe9', nome_a='Fernanda', nome_b='Fernanda', email_a='f@x.com', email_b=None, telefone_a=None, telefone_b='11999990000', criado_a='2026-09-01', criado_b='2026-10-01')]),
  'qualidade_regras': [], 'projeto_atividades': [], 'projeto_modelos': [], 'equipe': ws([dict(id='e1', nome='Ana', ativo=True)]),
}
RPC = r"""
window.__RPC = {
  pagar_fatura_cartao: (a, D) => { if (!(a.p_valor > 0)) throw new Error('Informe o valor'); return 'lf1'; },
  receber_avulso_criar: (a, D) => { const id = 'ra' + D.contas_receber.length; D.contas_receber.push({ id, workspace_id: a.p_ws, valor: a.p_valor, vencimento: a.p_vencimento, status: 'previsto', descricao: a.p_descricao, conta_receita_id: a.p_conta_receita, conta_bancaria_id: a.p_conta_bancaria, contrato_id: null, venda_id: null, desconto: 0, substituida_por: null }); return id; },
  receber_avulso_cancelar: (a, D) => { D.contas_receber.find(x => x.id === a.p_conta_receber).status = 'cancelado'; return null; },
  campanha_aplicar_estrategia: (a, D) => 4,
  campanha_gerar_atividades: (a, D) => 9,
  qualidade_dados: (a, D) => [{ codigo: 'dias_sem_midia', titulo: 'Dias sem dado de mídia', severidade: 'atencao', qtd: 2, texto: '2 dia(s) sem nenhum dado de mídia.', afeta: ['Investimento', 'CAC'], tela: 'mkt-trafego' },
                              { codigo: 'venda_receber_diverge', titulo: 'Venda diferente do a receber', severidade: 'alerta', qtd: 1, texto: '1 venda com valor diferente.', afeta: ['A receber'], tela: 'fin-receber' }],
  qualidade_catalogo: () => [{ codigo: 'dias_sem_midia', titulo: 'Dias sem dado de mídia', unidade: 'dias', padrao: 0, explica: 'x' }, { codigo: 'leads_sem_origem', titulo: 'Leads sem origem', unidade: '% dos leads', padrao: 20, explica: 'y' }],
  pessoas_mesclar: (a, D) => { D.v_pessoas_duplicadas = []; return a.p_manter; },
  campanha_fechar: (a, D) => { if (!a.p_motivo || a.p_motivo.length < 10) throw new Error('precisa de motivo'); D.campanha_fechamentos.forEach(f => f.status = 'substituido'); D.campanha_fechamentos.push({ id: 'fz2', workspace_id: 'w1', campanha_id: a.p_campanha, fechado_em: '2026-10-11T12:00:00Z', versao: 2, status: 'oficial', motivo: a.p_motivo, snapshot: a.p_snapshot }); return 'fz2'; },
  extrato_conta: (a, D) => ({ saldo_anterior: 999, entradas: 1, saidas: 0, saldo_final: 1000, cartao: false, linhas: [{ id: 'x', data: '2026-10-03', tipo: 'entrada', valor: 1, descricao: 'Do banco', saldo: 1000 }] })
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
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    go(pg, 'fin-dash', "S.per={pre:'pers',de:'2026-10-01',ate:'2026-10-31'}")
    t = tx(pg); chk('Qualidade do dado: 2 aviso(s)' in t, 'faixa de qualidade no dashboard financeiro', t[:300])
    c = calls(pg, 'qualidade_dados'); chk(c and c[-1]['p_ws'] == 'w1' and c[-1]['p_ini'] == '2026-10-01', 'avisos pedidos ao banco com o período do dashboard', c[-1:])
    chk(pg.evaluate("[...document.querySelectorAll('.kpi .l')].some(l => /A receber/.test(l.textContent) && l.querySelector('.dqw'))"), 'cartão A receber marcado com ⚠')
    chk(pg.evaluate("[...document.querySelectorAll('.kpi .l')].some(l => /Saldo em banco/.test(l.textContent) && l.querySelector('.dic88') && /Saldo inicial/.test(l.querySelector('.dic88').title))"), 'ⓘ do dicionário no cartão Saldo em banco')
    pg.click('.kpi.clic[data-fin=extrato]'); pg.wait_for_timeout(600)
    t = tx(pg, '#modalRoot'); chk('Do banco' in t and '1.000,00' in t and '999,00' in t, 'extrato vem do banco (extrato_conta)', t[:300])
    fecha(pg)
    go(pg, 'cfg-qualidade'); t = tx(pg)
    chk('Avisos do período (2)' in t and 'Leads sem origem' in t, 'tela Qualidade dos dados', t[:300])
    pg.uncheck('[data-qa=leads_sem_origem]'); pg.fill('[data-qt=dias_sem_midia]', '3'); pg.click('#qSalva'); pg.wait_for_timeout(500)
    r = D(pg, 'qualidade_regras'); chk(any(x['codigo'] == 'leads_sem_origem' and x['ativa'] is False for x in r) and any(x['codigo'] == 'dias_sem_midia' and x['tolerancia'] == 3 for x in r), 'salva tolerâncias', r)
    go(pg, 'cfg-metricas'); t = tx(pg); chk('Dicionário de métricas' in t and 'Custos ÷ clientes novos' in t, 'tela Dicionário de métricas')
    go(pg, 'cad-auditoria'); t = tx(pg); chk('rebecka@x.com' in t and 'Alterou' in t and 'status' in t, 'tela Auditoria', t[:400])
    pg.click('[data-au="0"]'); pg.wait_for_timeout(300); t = tx(pg, '#modalRoot'); chk('"aprovada"' in t and '"reembolsada"' in t, 'antes e depois')
    fecha(pg)
    go(pg, 'cad-duplicados'); t = tx(pg); chk('Fernanda' in t and 'Juntar' in t, 'tela Cadastros repetidos')
    pg.click('[data-dj="0"]'); pg.wait_for_timeout(300); pg.select_option('#modalRoot select[name=fica]', 'b'); submit(pg)
    c = calls(pg, 'pessoas_mesclar'); chk(c and c[-1]['p_manter'] == 'pe9' and c[-1]['p_remover'] == 'pe1', 'juntar escolhe quem fica', c)
    # fechamento versionado
    pg.evaluate("window.dadosFechamento = async () => ({ periodo: { ini: '2026-10-01', fim: '2026-10-31' }, metas: [], canais: [] })")
    pg.evaluate("fecharCampanha({ id: 'c1', modelo: 'lancamento', status: 'ativa' }, {})"); pg.wait_for_timeout(600)
    chk(pg.locator('#modalRoot textarea[name=motivo]').count() == 1 and 'V2' in tx(pg, '#modalRoot'), 'novo fechamento pede motivo e avisa que vira V2')
    pg.fill('#modalRoot textarea[name=motivo]', 'Vendas da Hotmart chegaram atrasadas'); submit(pg)
    c = calls(pg, 'campanha_fechar'); chk(c and c[-1]['p_motivo'] == 'Vendas da Hotmart chegaram atrasadas' and c[-1]['p_campanha'] == 'c1', 'fecha pelo banco com motivo', c[-1:])
    f = D(pg, 'campanha_fechamentos'); chk([x['status'] for x in f] == ['substituido', 'oficial'], 'V1 substituída, V2 oficial')
    # erro de duplicidade traduzido
    m = pg.evaluate("traduzErro({ message: 'duplicate key value violates unique constraint \"pessoas_telefone_uq\"', code: '23505' }).message")
    chk('mesmo telefone' not in m and 'telefone' in m, 'erro de telefone repetido em português', m)
    chk(pg.evaluate("normFone('(11) 98888-7777')") == '5511988887777' and pg.evaluate("normFone('123')") is None, 'telefone normalizado igual ao banco')
    real = [e for e in errs if 'funil' not in e]
    chk(not real, 'sem erro de JavaScript na página', real)
    b.close()
print('\n' + ('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
