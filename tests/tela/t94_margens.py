import json, os, tempfile
# Teste de tela da v0.94: margens por produto, lucro líquido e meta de margem (salva no Planejamento).
# Rodar: python3 tests/tela/t94_margens.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't94_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
cp = lambda id, d, v, comp, conta, cc, forn=None, rec=None, st='previsto', est=False: dict(id=id, descricao=d, valor=v, competencia=comp, vencimento=comp, status=st, conta_despesa_id=conta, centro_custo_id=cc, fornecedor_id=forn, recorrencia_id=rec, estimativa=est)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'plano_contas': ws([dict(id='pF', codigo='6.2.01', nome='Ferramentas e software', tipo='despesa'), dict(id='pP', codigo='6.2.04', nome='Pró-labore', tipo='despesa'),
                      dict(id='pE', codigo='6.3.02', nome='Energia elétrica', tipo='despesa'), dict(id='pC', codigo='6.3.05', nome='Treinamento e cursos', tipo='despesa'), dict(id='pS', codigo='6.2.02', nome='Equipe e prestadores', tipo='despesa')]),
  'centros_custo': ws([dict(id='cA', nome='Administrativo'), dict(id='cM', nome='Marketing')]),
  'fornecedores': ws([dict(id='fR', nome='Rogerio'), dict(id='fM', nome='Mychel Designer'), dict(id='fT', nome='Tio Lutero')]),
  'despesas_recorrentes': ws([dict(id='r1', descricao='Rogerio', valor=10000, tipo='fixa', ativo=True, data_inicio='2026-10-06', conta_despesa_id='pP', centro_custo_id='cA', fornecedor_id='fR'),
                              dict(id='r2', descricao='Luz', valor=600, tipo='variavel', ativo=True, data_inicio='2026-10-06', conta_despesa_id='pE', centro_custo_id='cA'),
                              dict(id='r3', descricao='Claude', valor=120, tipo='fixa', ativo=True, data_inicio='2026-11-03', conta_despesa_id='pF', centro_custo_id='cM')]),
  'contas_pagar': ws([cp('a1', 'Rogerio — 10/2026', 3988.09, '2026-10-01', 'pP', 'cA', 'fR', 'r1', 'pago'), cp('a2', 'Rogerio — 10/2026 (saldo) (saldo)', 6011.91, '2026-10-01', 'pP', 'cA', 'fR'),
                      cp('a3', 'Luz — 10/2026', 600, '2026-10-01', 'pE', 'cA', None, 'r2', est=True),
                      cp('a4', 'Curso ROAS (1/2)', 200, '2026-10-01', 'pC', 'cA', 'fT'), cp('a5', 'Curso ROAS (2/2)', 200, '2026-11-01', 'pC', 'cA', 'fT'),
                      cp('a6', 'Webdesigner', 625, '2026-10-15', 'pS', 'cM', 'fM'),
                      cp('a7', 'Velha cancelada', 999, '2026-10-01', 'pS', 'cM', st='cancelado')]),
  'contas_receber': ws([dict(id='cr1', valor=4000, vencimento='2026-10-20', status='previsto', desconto=0, contrato_id='ct1'), dict(id='cr3', valor=1000, vencimento='2026-10-10', status='recebido', desconto=0, contrato_id='ct2'), dict(id='cr4', valor=500, vencimento='2026-10-12', status='previsto', desconto=0), dict(id='cr2', valor=2000, vencimento='2026-11-05', status='previsto', desconto=0, contrato_id='ct1')]),
  'empresa': ws([dict(id='em1', regime_tributario='mei')]),
  'produtos': ws([dict(id='pr1', nome='Disparos', preco=1500, ativo=True, extras={}), dict(id='pr2', nome="Growth's Recorrência", preco=6000, ativo=True, extras={'mc_custo_pct': 10})]),
  'contratos': ws([dict(id='ct1', numero=1), dict(id='ct2', numero=2)]),
  'contrato_itens': ws([dict(contrato_id='ct1', produto_id='pr2', quantidade=1, valor=4000), dict(contrato_id='ct2', produto_id='pr1', quantidade=1, valor=1000)]),
  'planos': ws([dict(id='pl1', nome='Plano 2026', data_inicio='2026-10-01', data_fim='2026-12-31', status='ativo')]),
  'plano_objetivos': ws([dict(id='ob1', plano_id='pl1', titulo='Crescer', ordem=0)]),
  'plano_indicadores': [],
  'simulador_cenarios': [], 'campanhas': [], 'funis': [], 'equipe': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';window.__RPC={};</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:600]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def go(pg, view, extra=''):
    pg.evaluate("([v,e])=>{S.ws='w1'; S.view=v; eval(e); render();}", [view, extra]); pg.wait_for_timeout(900)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ').replace('R$ ', '')
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1500, 'height': 2600}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão')
    chk(pg.evaluate("PL_CHAVE.margem_lucro && PL_UN_CHAVE.margem_lucro === 'pct'"), 'Planejamento conhece o indicador de margem de lucro')
    go(pg, 'fin-custo')
    t = tx(pg)
    # out/2026, MEI: receita 5.500 (4.000 recorrência, 1.000 disparos, 500 avulsa); recorrência tem custo de 10% = 400; MC = 5.100
    chk('Margens e meta' in t and 'Custos e margens' in t, 'painel de margens na tela', t[:400])
    chk("Growth's Recorrência" in t and 'Disparos' in t and 'Sem produto (avulsas)' in t, 'receita por produto (contrato → item) e avulsa separada', t[:3000])
    chk('5.100,00' in t and '92,7%' in t, 'margem de contribuição: 5.500 − 400 de custo do produto = 5.100 (92,7%)', t[:3000])
    # fixos: 10.000 + 600 + 200 + 625 + DAS 86,05 = 11.511,05 ; lucro = 5.100 − 11.511,05 = −6.411,05
    chk('11.511,05' in t and '-6.411,05' in t.replace('−', '-'), 'lucro líquido = contribuição − custos fixos (com DAS)', t[:3000])
    chk('Cenário: Abaixo do ruim' in t and 'Falta para o cenário ruim' in t, 'cenários padrão (ruim 20, bom 30, ótimo 40) e situação abaixo do ruim', t[:3000])
    chk(pg.evaluate("[...document.querySelectorAll('[data-cen]')].map(x=>x.value).join('|')") == '20|30|40', 'três campos: ruim, bom, ótimo')
    # salvar meta: cria indicador no plano ativo
    def cen(k, v): pg.fill('[data-cen=%s]' % k, v); pg.dispatch_event('[data-cen=%s]' % k, 'change'); pg.wait_for_timeout(900)
    cen('bom', '25')
    ind = pg.evaluate("window.__D.plano_indicadores")
    chk(len(ind) == 1 and ind[0]['valor_meta'] == 25 and ind[0]['chave'] == 'margem_lucro' and ind[0]['objetivo_id'] == 'ob1' and ind[0]['faixa_ruim'] == 20 and ind[0]['faixa_otimo'] == 40, 'cenários salvos como indicador do Planejamento (bom = meta)', ind)
    cen('ruim', '-110')
    chk('entre 0 e 99' in pg.inner_text('body') or pg.evaluate("window.__D.plano_indicadores[0].faixa_ruim") == 20, 'percentual inválido não grava')
    cen('ruim', '27')
    chk(pg.evaluate("window.__D.plano_indicadores[0].faixa_ruim") == 20, 'ruim maior que o bom é recusado')
    cen('otimo', '50'); cen('ruim', '15')
    i0 = pg.evaluate("window.__D.plano_indicadores[0]")
    chk(len(pg.evaluate("window.__D.plano_indicadores")) == 1 and i0['faixa_ruim'] == 15 and i0['valor_meta'] == 25 and i0['faixa_otimo'] == 50, 'edições atualizam o mesmo indicador', i0)
    t = tx(pg); chk('Ruim' in t and 'Ótimo' in t and 'você está aqui' not in t.split('Ótimo')[0][-50:] , 'tabela de cenários', t[:3500])
    chk(pg.evaluate("[...document.querySelectorAll('[data-cen]')].map(x=>x.value).join('|')") == '15|25|50', 'tela lê os cenários do Planejamento')
    # margem acima do ótimo: muita receita
    pg.evaluate("window.__D.contas_receber.push({id:'big', workspace_id:'w1', valor:100000, vencimento:'2026-10-25', status:'previsto', desconto:0})"); pg.evaluate("render()"); pg.wait_for_timeout(900)
    t = tx(pg); chk('Cenário: Ótimo' in t and 'Acima do ótimo' in t and 'você está aqui' in t, 'acima do ótimo: cenário ótimo', t[:3500])
    pg.evaluate("window.__D.contas_receber = window.__D.contas_receber.filter(x=>x.id!=='big')"); pg.evaluate("render()"); pg.wait_for_timeout(900)
    # custo por cliente do Disparos
    pg.fill('[data-mcp=pr1][data-k=mc_custo_cliente]', '150'); pg.dispatch_event('[data-mcp=pr1][data-k=mc_custo_cliente]', 'change'); pg.wait_for_timeout(900)
    chk(pg.evaluate("window.__D.produtos.find(p=>p.id==='pr1').extras.mc_custo_cliente") == 150, 'custo por cliente salvo no produto')
    t = tx(pg); chk('4.950,00' in t, 'contribuição cai 150 (1 cliente de Disparos)', t[:3000])
    # Simples: imposto na margem de contribuição
    pg.select_option('#coReg', 'simples_III'); pg.wait_for_timeout(900)
    t = tx(pg); chk('Abaixo do ruim' in t and '330,00' in t, 'Simples anexo III: 6% de imposto sobre 5.500 = 330', t[:3000])
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
