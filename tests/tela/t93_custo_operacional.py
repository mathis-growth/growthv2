import json, os, tempfile
# Teste de tela da v0.93: Financeiro → Custo operacional (itens por mês, áreas, pontual desmarcável, ponto de equilíbrio MEI × Simples) e "Puxar do financeiro" no simulador.
# Rodar: python3 tests/tela/t93_custo_operacional.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't93_growths.html')
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
  'contas_receber': ws([dict(id='cr1', valor=5000, vencimento='2026-10-20', status='previsto', desconto=0), dict(id='cr2', valor=2000, vencimento='2026-11-05', status='previsto', desconto=0)]),
  'empresa': ws([dict(id='em1', regime_tributario='mei')]),
  'simulador_cenarios': [], 'produtos': [], 'campanhas': [], 'funis': [], 'equipe': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';window.__RPC={};</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def go(pg, view, extra=''):
    pg.evaluate("([v,e])=>{S.ws='w1'; S.view=v; eval(e); render();}", [view, extra]); pg.wait_for_timeout(800)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ')
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1400, 'height': 2400}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.93')
    chk(pg.evaluate("NAV.some(g => g.g === 'Financeiro' && g.items.some(i => i[0] === 'fin-custo')) && NAV.some(g => g.casa && g.items.some(i => i[0] === 'casa-custo'))"), 'menu do Financeiro e da Casa têm a tela')
    # --- cálculo puro ---
    r = pg.evaluate("coEquilibrio({C: 10000, folha: 0, varPct: 0, margemPct: 0, regime: 'manual', aliqManual: 6})")
    chk(abs(r['receita'] - 10638.30) < 0.01, 'alíquota manual 6%: 10.000 ÷ 0,94', r)
    r = pg.evaluate("coEquilibrio({C: 21000, folha: 20000, varPct: 0, margemPct: 0, regime: 'simples_auto'})")
    rbt = r['receita'] * 12; esperado = (rbt * 0.112 - 9360) / rbt
    chk(r['anexo'] == 'III' and abs(r['aliq'] - esperado) < 1e-6 and abs(r['receita'] * (1 - r['aliq']) - 21000) < 0.01, 'Simples automático: fator R alto → anexo III, 2ª faixa, receita × (1 − alíquota) = custo', r)
    r = pg.evaluate("coEquilibrio({C: 21000, folha: 1000, varPct: 0, margemPct: 0, regime: 'simples_auto'})")
    chk(r['anexo'] == 'V', 'fator R abaixo de 28% → anexo V', r)
    r = pg.evaluate("coEquilibrio({C: 21000, folha: 20000, varPct: 0, margemPct: 0, regime: 'mei'})")
    chk(abs(r['receita'] - 21086.05) < 0.01 and any('20% acima' in a for a in r['avisos']), 'MEI: custo + DAS 86,05 e aviso de limite estourado', r)
    # --- tela ---
    go(pg, 'fin-custo')
    t = tx(pg)
    chk('Custo do mês' in t and '11.425,00' in t.replace('R$ ', ''), 'outubro: 10.000 Rogério (pago + saldo juntos) + 600 luz + 200 curso + 625 webdesigner (cancelada fora)', t[:900])
    chk(t.count('Rogerio') >= 1 and 'Velha cancelada' not in t, 'parcelas do mesmo pró-labore viram um item só; cancelada não aparece', t[-1500:])
    chk('até 11/2026' in t and 'Pontual' in t and 'Variável' in t, 'tipos: parcelado com fim, pontual e variável', t[-1500:])
    chk('Pró-labores' in t and '10.000,00' in t, 'pró-labore separado', t[:600])
    # desmarca o webdesigner
    pg.evaluate("document.querySelector('[data-cok^=\"a:a6\"]').click()"); pg.wait_for_timeout(800)
    t = tx(pg); chk('10.800,00' in t.replace('R$ ', ''), 'desmarcar o pontual tira do total', t[:600])
    chk(pg.evaluate("JSON.parse(localStorage.getItem('custoOp:w1')).fora['a:a6']") == 1, 'escolha salva no navegador')
    # ponto de equilíbrio MEI (padrão do cadastro)
    chk('acima do limite do MEI' in t and 'Comparação entre regimes' in t, 'comparação mostra MEI acima do limite', t[-2500:])
    # novembro: recorrência do Claude projetada, Rogério projetado pela regra
    pg.select_option('#coMes', '2026-11'); pg.wait_for_timeout(800)
    t = tx(pg); chk('projetado' in t and 'Claude' in t and '10.920,00' in t.replace('R$ ', ''), 'novembro: 10.000 + 600 + 120 (projetados) + 200 parcela', t[:900])
    chk('faltam' in t, 'mostra quanto falta para empatar com o a receber do mês', t[:1500])
    pg.select_option('#coReg', 'simples_auto'); pg.wait_for_timeout(800)
    t = tx(pg); chk('anexo III' in t and 'Fator R' in t, 'simulação no Simples mostra anexo e fator R', t[:2500])
    pg.select_option('#coVer', 'tipo'); pg.wait_for_timeout(600)
    chk('Por tipo de custo' in tx(pg), 'agrupar por tipo')
    # simulador: puxar do financeiro
    D = pg.evaluate("(async()=>{const D={fixos:[]}; const r = await gpsPuxarCustos(D); return D.fixos;})()")
    nomes = sorted(x['nome'] for x in D); tot = round(sum(x['valor'] for x in D), 2)
    chk('Pró-labore' in nomes and tot == 10800.00 and all(x['nome'] != 'Equipe e prestadores' for x in D), 'Puxar do financeiro: outubro sem o pontual (10.000 + 600 + 200)', (nomes, tot))
    chk(any(x['categoria'] == 'equipe' for x in D) and any(x['categoria'] == 'infraestrutura' for x in D), 'categorias do simulador preenchidas', D)
    errs = [e for e in errs if 'funil' not in e]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
