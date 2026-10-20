import json, os, tempfile
from playwright.sync_api import sync_playwright
# Teste de tela da v0.90 (projetos: tags, filtros, painel, modelo, vínculo com campanha; meta de CPL).
# Rodar: python3 tests/tela/t90_projetos.py (precisa de playwright + chromium)
HTML = os.path.join(tempfile.gettempdir(), 't90_growths.html')
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
  'campanhas': ws([dict(id='c1', nome='Black', modelo='lancamento', status='ativa', data_inicio='2026-10-01', data_fim='2026-10-31', funil_id=None, produto_id='p1', fases={}, meta_cpl=50),
                    dict(id='c2', nome='Velha', modelo='lancamento', status='finalizada', data_inicio='2026-01-01', data_fim='2026-01-31', fases={})]),
  'projetos': ws([dict(id='pj1', nome='Site novo', status='em_andamento', tags=['site', 'interno'], responsavel_id='e1', data_inicio='2026-10-01', data_fim_prevista='2026-10-20', campanha_id=None, criado_em='2026-10-01T10:00:00Z'),
                  dict(id='pj2', nome='Lançamento X', status='planejado', tags=['lancamento'], responsavel_id='e2', data_inicio='2026-10-05', campanha_id=None, criado_em='2026-10-05T10:00:00Z')]),
  'projeto_atividades': ws([dict(id='a1', projeto_id='pj1', pai_id=None, titulo='Layout', status='concluida', responsavel_id='e1', prazo='2026-10-05', concluida_em='2026-10-04T10:00:00Z', ordem=10, depende_de=[], tags=['design']),
                            dict(id='a2', projeto_id='pj1', pai_id=None, titulo='Programar', status='em_andamento', responsavel_id='e2', prazo='2026-10-09', ordem=20, depende_de=[], tags=[]),
                            dict(id='a3', projeto_id='pj2', pai_id=None, titulo='Copy', status='liberada', responsavel_id=None, prazo='2026-12-15', ordem=10, depende_de=[], tags=['texto'])]),
  'projeto_modelos': ws([dict(id='m1', nome='Lançamento padrão', padrao_campanha=True, ativo=True)]),
  'equipe': ws([dict(id='e1', nome='Ana', ativo=True), dict(id='e2', nome='Bruno', ativo=True)]),
  'canais': ws([dict(id='k1', codigo='meta_ads', nome='Meta Ads', ativo=True)]),
  'campanha_canais': ws([dict(id='cc1', campanha_id='c1', canal='meta_ads', utm_campaign='bf_meta', meta_leads=100, meta_cpl=40, orcamento=1000, temperatura=None)]), 'v_marketing_campanha': [],
}
RPC = r"""
window.__RPC = {
  pagar_fatura_cartao: (a, D) => { if (!(a.p_valor > 0)) throw new Error('Informe o valor'); return 'lf1'; },
  receber_avulso_criar: (a, D) => { const id = 'ra' + D.contas_receber.length; D.contas_receber.push({ id, workspace_id: a.p_ws, valor: a.p_valor, vencimento: a.p_vencimento, status: 'previsto', descricao: a.p_descricao, conta_receita_id: a.p_conta_receita, conta_bancaria_id: a.p_conta_bancaria, contrato_id: null, venda_id: null, desconto: 0, substituida_por: null }); return id; },
  receber_avulso_cancelar: (a, D) => { D.contas_receber.find(x => x.id === a.p_conta_receber).status = 'cancelado'; return null; },
  campanha_aplicar_estrategia: (a, D) => 4,
  campanha_gerar_atividades: (a, D) => 9,
  projeto_painel: () => ({ total: 2, sem_prazo: 0, status: [{ status: 'concluida', n: 1 }, { status: 'em_andamento', n: 1 }], responsaveis: [{ nome: 'Ana', abertas: 0, bloqueadas: 0, concluidas: 1, atrasadas: 0 }, { nome: 'Bruno', abertas: 1, bloqueadas: 0, concluidas: 0, atrasadas: 1 }],
     serie: [{ d: '2026-10-01', planejado: 0, concluido: 0 }, { d: '2026-10-05', planejado: 1, concluido: 1 }, { d: '2026-10-09', planejado: 2, concluido: 1 }, { d: '2026-10-11', planejado: 2, concluido: 1 }, { d: '2026-10-20', planejado: 2, concluido: null }] }),
  projeto_salvar_como_modelo: (a, D) => { D.projeto_modelos.push({ id: 'm2', workspace_id: 'w1', nome: a.p_nome, padrao_campanha: a.p_padrao_campanha, ativo: true }); return 'm2'; },
  projeto_vincular_campanha: (a, D) => { D.projetos.find(p => p.id === a.p_projeto).campanha_id = a.p_campanha; return null; },
  campanha_criar_projeto: (a, D) => { D.projetos.push({ id: 'pj3', workspace_id: 'w1', nome: a.p_nome, status: 'planejado', campanha_id: a.p_campanha, tags: [] }); return 'pj3'; },
  campanha_canais_resultado: () => [{ id: 'cc1', canal: 'meta_ads', leads: 50, investimento: 2500, cpl: 50, meta_cpl: 40, meta_leads: 100 }]
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
    pg.evaluate("window.hoje = () => '2026-10-11'")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.9x')
    go(pg, 'prj-lista', "S.projSel=null; S.pf2={st:'todos'}")
    t = tx(pg); chk('#site' in t and '#lancamento' in t, 'tags aparecem nos projetos', t[:500])
    pg.select_option('#pfTag', 'site'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Site novo' in t and 'Lançamento X' not in t, 'filtro por tag')
    pg.select_option('#pfTag', ''); pg.wait_for_timeout(400); pg.select_option('#pfResp', 'e2'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Lançamento X' in t and 'Site novo' not in t, 'filtro por responsável do projeto')
    pg.select_option('#pfResp', ''); pg.wait_for_timeout(400)
    pg.click('#pNovo'); pg.wait_for_timeout(600)
    names = pg.evaluate("[...document.querySelectorAll('#modalRoot [name]')].map(x=>x.name)")
    chk(names.index('data_inicio') < names.index('descricao') and 'data_fim_prevista' in names and 'tags_txt' in names and 'campanha_id' in names, 'novo projeto: datas logo depois do nome, tags e campanha', names[:8])
    camps = pg.evaluate("[...document.querySelectorAll('#modalRoot select[name=campanha_id] option')].map(o=>o.textContent)")
    chk('Black' in camps and 'Velha' not in camps, 'só campanhas abertas para vincular', camps)
    pg.fill('#modalRoot input[name=nome]', 'Evento'); pg.fill('#modalRoot input[name=tags_txt]', 'Evento, Cliente A, evento'); pg.fill('#modalRoot input[name=data_fim_prevista]', '2026-11-30'); pg.select_option('#modalRoot select[name=campanha_id]', 'c1'); submit(pg)
    np_ = [x for x in D(pg, 'projetos') if x['nome'] == 'Evento']
    chk(np_ and np_[0]['tags'] == ['evento', 'cliente a'] and np_[0]['data_fim_prevista'] == '2026-11-30' and np_[0].get('campanha_id') == 'c1', 'grava tags normalizadas, fim e vínculo pela função', np_)
    c = calls(pg, 'projeto_vincular_campanha'); chk(c and c[-1]['p_campanha'] == 'c1', 'vínculo gera atividades dos blocos (projeto_vincular_campanha)')
    # detalhe
    go(pg, 'prj-lista', "S.projSel='pj1'"); pg.wait_for_timeout(500); t = tx(pg)
    chk('Andamento: planejado × concluído' in t and 'Por responsável' in t and 'Bruno' in t, 'painel do projeto com gráfico e responsáveis', t[:800])
    chk(pg.locator('#pPainel svg').count() >= 1, 'gráfico desenhado')
    chk('#design' in t, 'tags nas atividades')
    pg.select_option('.f90 [data-f90=st]', 'abertas'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Programar' in t and 'Layout' not in t.split('Situação')[-1], 'filtro de atividades abertas no projeto')
    pg.select_option('.f90 [data-f90=st]', 'todas'); pg.wait_for_timeout(400); pg.select_option('.f90 [data-f90=tag]', 'design'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Layout' in t and 'Programar' not in t.split('Situação')[-1], 'filtro por tag da atividade')
    pg.click('#pModelo90'); pg.wait_for_timeout(300); pg.fill('#modalRoot input[name=nome]', 'Modelo site'); submit(pg)
    c = calls(pg, 'projeto_salvar_como_modelo'); chk(c and c[-1]['p_projeto'] == 'pj1' and c[-1]['p_nome'] == 'Modelo site', 'salvar como modelo')
    pg.click('#pCamp90'); pg.wait_for_timeout(400); pg.select_option('#modalRoot select[name=camp]', 'c1'); submit(pg)
    chk(next(x for x in D(pg, 'projetos') if x['id'] == 'pj1')['campanha_id'] == 'c1', 'vincular campanha pelo projeto')
    # todas as atividades
    go(pg, 'prj-atividades', "S.f90={st:'abertas'}"); t = tx(pg)
    chk('Programar' in t and 'Copy' in t and 'Layout' not in t, 'todas as atividades abertas', t[:500])
    pg.select_option('[data-f90=resp]', 'sem'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Copy' in t and 'Programar' not in t, 'filtro sem responsável')
    pg.select_option('[data-f90=resp]', ''); pg.wait_for_timeout(300); pg.select_option('[data-f90=st]', 'atrasadas'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Programar' in t and 'Copy' not in t, 'filtro atrasadas')
    pg.select_option('[data-f90=st]', 'todas'); pg.wait_for_timeout(300); pg.select_option('[data-f90=proj]', 'pj2'); pg.wait_for_timeout(500); t = tx(pg)
    chk('Copy' in t and 'Programar' not in t, 'filtro por projeto')
    # campanha
    go(pg, 'mkt-camp', "S.campSel='c1'; S.campTab='resumo'"); t = tx(pg)
    chk('CPL (custo por lead)' in t and 'Meta de CPL' in t.upper().title() or 'META DE CPL' in t.upper(), 'campanha mostra CPL e meta de CPL por canal', t[:300])
    chk('R$ 50,00' in t and 'R$ 40,00' in t, 'CPL do canal contra a meta do canal')
    pg.click('[data-ek=cc1]'); pg.wait_for_timeout(400)
    chk(pg.locator('#modalRoot input[name=meta_cpl]').count() == 1 and pg.locator('#modalRoot input[name=meta_leads]').count() == 1, 'canal tem meta de leads e de CPL')
    fecha(pg)
    pg.click('#cEd'); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot input[name=meta_cpl]').count() == 1, 'campanha tem meta de CPL'); fecha(pg)
    pg.click('#cPj'); pg.wait_for_timeout(500); t = tx(pg, '#modalRoot')
    chk('Criar projeto a partir de um modelo' in t and 'Site novo' in t, 'botão Projeto: vinculados, modelo e projetos abertos', t[:400])
    pg.fill('#modalRoot input[name=nome]', 'Black: execução'); submit(pg)
    c = calls(pg, 'campanha_criar_projeto'); chk(c and c[-1]['p_modelo'] == 'm1' and c[-1]['p_campanha'] == 'c1', 'cria projeto da campanha pelo modelo padrão', c[-1:])
    chk(pg.evaluate("S.projSel") == 'pj3', 'abre o projeto criado')
    # v0.91: projeto automático opcional na campanha nova
    go(pg, 'mkt-camp', "S.campSel=null")
    pg.evaluate("formCampanha(null)"); pg.wait_for_timeout(600)
    chk(pg.locator('#modalRoot input[name=projeto_auto]').is_checked() and pg.input_value('#modalRoot select[name=projeto_modelo_id]') == 'm1', 'campanha nova: criar projeto marcado, modelo padrão escolhido')
    pg.fill('#modalRoot input[name=nome]', 'Sem projeto'); pg.uncheck('#modalRoot input[name=projeto_auto]')
    pg.fill('#modalRoot input[name=data_fim]', '2026-12-31')
    if pg.locator('#modalRoot select[name=produto_id]').count(): pg.select_option('#modalRoot select[name=produto_id]', index=0)
    submit(pg)
    nc = [x for x in D(pg, 'campanhas') if x['nome'] == 'Sem projeto']
    chk(nc and nc[0].get('projeto_auto') is False, 'desmarcado grava projeto_auto = falso', nc)
    real = [e for e in errs if 'funil' not in e]
    chk(not real, 'sem erro de JavaScript na página', real)
    b.close()
print('\n' + ('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas)))
