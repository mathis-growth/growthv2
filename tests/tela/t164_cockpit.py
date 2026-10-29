import json, os, tempfile
# Teste de tela da v0.164: o Growths abre no Cockpit, com um painel por área (Geral, Marketing, Vendas, Financeiro, Clientes),
# cada painel tem números e um gráfico (painel_gerencial, growths_serie, v_dre_mensal, cg_indicadores), abre o dashboard do módulo
# e só aparece para quem tem acesso.
# Rodar: python3 tests/tela/t164_cockpit.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't164_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'campanhas': ws([dict(id='c1', nome='Lançamento', status='ativa'), dict(id='c2', nome='Perpétuo', status='ativa'), dict(id='c3', nome='Próxima', status='planejada')]),
  'oportunidades': ws([dict(id='o1', status='aberta', valor_estimado=3000), dict(id='o2', status='aberta', valor_estimado=2000), dict(id='o3', status='ganha', valor_estimado=9000)]),
  'rpc:painel_gerencial': {
    'funil': {'total': 120, 'qualificados': 60, 'clientes': 12, 'ativos': 10, 'inativos': 2, 'leads': 108, 'pct_qualificados': 0.5},
    'vendas': {'total': 15, 'aprovadas': 12, 'nao_aprovadas': 3, 'bruto': 24000, 'liquido': 20000},
    'caixa': {'saldo': 18500, 'a_receber': 9000, 'a_pagar': 4000, 'atraso_receber': 1200, 'atraso_pagar': 0},
    'resultado': {'receita': 24000, 'lucro': -1500, 'margem': -0.0625},
    'recorrencia': {'mrr': 3500}, 'cac': {'cac_total': 450, 'novos': 12}, 'fluxo': {'entrou': 15000, 'saiu': 9000}},
  'projetos': ws([dict(id='pj1', status='em_andamento'), dict(id='pj2', status='em_andamento'), dict(id='pj3', status='planejado')]),
  'projeto_atividades': ws([dict(id='a1', status='liberada', prazo='2026-10-01'), dict(id='a2', status='em_andamento', prazo='2099-01-01'), dict(id='a3', status='bloqueada'),
                            dict(id='a4', status='concluida', concluida_em='2026-10-20T10:00:00Z'), dict(id='a5', status='liberada', pai_id=None), dict(id='a6', status='concluida', pai_id='a5', concluida_em='2026-10-21T10:00:00Z')]),
  'growth_metricas': ws([dict(id='n1', nome='Alunos com resultado', tipo='north_star', fonte='manual', unidade='numero', direcao='sobe', meta=40, valor_manual=30)]),
  'growth_experimentos': ws([dict(id='e1', etapa='ideia'), dict(id='e2', etapa='rodando'), dict(id='e3', etapa='analise'), dict(id='e4', etapa='concluido', resultado='venceu'), dict(id='e5', etapa='concluido', resultado='perdeu')]),
  'rpc:growth_metricas_auto': {},
  'rpc:growths_serie': [dict(dia='2026-10-%02d' % d, leads=d % 5 + 1, qualificados=1, vendas=d % 2, receita=(d % 3) * 1000) for d in range(1, 30)],
  'v_dre_mensal': ws([dict(mes=m + '-01', tipo=t, valor=v) for m in ['2026-08', '2026-09', '2026-10'] for t, v in [('receita', 20000), ('custo', 8000), ('despesa', 9000 if m != '2026-10' else 16000)]]),
  'rpc:cg_indicadores': {'matriculas': {'ativas': 522, 'novas': 30, 'sairam': 4, 'sem_cs': 484}, 'alertas': {'parado': 340, 'sem_cs': 484},
    'intervencoes': {'abertas': 3, 'atrasadas': 1}, 'nps': {'nps': 43, 'respostas': 20},
    'etapas': [{'jornada': 'Jornada geral', 'etapa': 'Onboarding', 'n': 300}, {'jornada': 'Mentoria · v1', 'etapa': 'Plano', 'n': 120}, {'jornada': 'Jornada geral', 'etapa': 'Vazia', 'n': 0}]},
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def card(pg, k): return pg.evaluate("k => { const c = document.querySelector('.ck-' + k); return c ? c.innerText.replace(/\\s+/g, ' ') : null; }", k)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1100}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    chk(pg.evaluate("S.view") == 'cockpit', 'o Growths abre no Cockpit', pg.evaluate("S.view"))
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'cockpit'; render();"); pg.wait_for_timeout(1300)
    chk(pg.evaluate("[...document.querySelectorAll('.ck-card h2')].map(h => h.textContent)") == ['Geral', 'Marketing', 'Vendas', 'Financeiro', 'Projetos', 'Growth', 'Clientes (CS)'], 'painéis na ordem: Geral, Marketing, Vendas, Financeiro, Projetos, Growth, Clientes')
    chk(pg.evaluate("(() => { const a = document.querySelector('.ck-mkt').getBoundingClientRect(), b = document.querySelector('.ck-ven').getBoundingClientRect(), c = document.querySelector('.ck-fin').getBoundingClientRect(), d = document.querySelector('.ck-prj').getBoundingClientRect(); return Math.abs(a.top - b.top) < 2 && b.left > a.right && Math.abs(c.top - d.top) < 2 && c.top > a.bottom; })()"), 'Marketing e Vendas lado a lado; Financeiro e Projetos lado a lado, embaixo')
    chk(pg.evaluate("document.querySelector('.ck-mkt').getBoundingClientRect().height") < 330, 'painel compacto (menos de 330 px de altura)', pg.evaluate("document.querySelector('.ck-mkt').getBoundingClientRect().height"))
    chk(pg.evaluate("!!document.querySelector('#nav [data-v=cockpit]')"), 'Cockpit no menu')
    g = card(pg, 'geral')
    chk(all(x in g for x in ['Saldo em caixa', 'R$ 18.500,00', 'Receita', 'R$ 24.000,00', 'Vendas 12', 'Margem', '−6,3%', 'Lucro', '−R$ 1.500,00']), 'Geral: caixa, receita, vendas, margem e lucro', g)
    chk(pg.evaluate("document.querySelector('.ck-geral .ck-i.ck-neg .l') && [...document.querySelectorAll('.ck-geral .ck-i.ck-neg .l')].map(x => x.textContent).join()") == 'Margem,Lucro', 'lucro e margem negativos em vermelho')
    mk = card(pg, 'mkt')
    chk('Campanhas ativas 2' in mk and '1 planejadas' in mk and 'Leads no período 120' in mk and 'Leads em andamento 108' in mk and 'R$ 450,00' in mk, 'Marketing: campanhas, leads e CAC', mk)
    v = card(pg, 'ven')
    chk('Vendas aprovadas 12' in v and 'R$ 2.000,00' in v and '10,0% dos leads viraram clientes' in v and 'Oportunidades abertas 2' in v and 'R$ 5.000,00 em negociação' in v, 'Vendas: aprovadas, ticket, conversão e oportunidades', v)
    f = card(pg, 'fin')
    chk('A receber R$ 9.000,00' in f and 'R$ 1.200,00 em atraso' in f and 'A pagar R$ 4.000,00' in f and 'entrou − saiu): R$ 6.000,00' in f and 'MRR R$ 3.500,00' in f, 'Financeiro: saldo, receber, pagar, fluxo e MRR', f)
    c = card(pg, 'cs')
    chk('Alunos ativos 522' in c and 'Alertas abertos 824' in c and 'Intervenções abertas 3' in c and 'NPS dos alunos 43' in c and 'Sem CS responsável: 484' in c, 'Clientes: ativos, alertas, intervenções, NPS e sem CS', c)
    pj = card(pg, 'prj')
    chk('Projetos em andamento 2' in pj and '1 planejados' in pj and 'Para fazer agora 2' in pj and 'Atrasadas 1' in pj and 'Concluídas 2' in pj, 'Projetos: andamento, para fazer, atrasadas e concluídas', pj)
    gr = card(pg, 'gro')
    chk('North Star 30' in gr and 'Alunos com resultado' in gr and 'Da meta 75%' in gr and 'Experimentos rodando 1' in gr and 'Venceram 50%' in gr, 'Growth: North Star, meta, experimentos e vitórias', gr)
    chk(pg.evaluate("[...document.querySelectorAll('.ck-gro .ck-hb-r')].map(x => x.textContent)") == ['Ideias', 'Priorizados', 'Rodando', 'Em análise', 'Concluídos'], 'Growth: experimentos por etapa')
    # gráficos
    chk(pg.evaluate("['geral','mkt','ven'].every(k => document.querySelector('.ck-' + k + ' svg.ck-svg path'))"), 'Geral, Marketing e Vendas têm gráfico de colunas')
    chk(pg.evaluate("[...document.querySelectorAll('.ck-geral .ck-leg span')].map(x => x.textContent)") == ['Receita', 'Lucro'], 'gráfico do Geral com legenda Receita e Lucro')
    chk(pg.evaluate("document.querySelectorAll('.ck-geral .ck-hit').length") == 3 and 'out · Receita: R$ 20.000,00 · Lucro: −R$ 4.000,00' in pg.evaluate("[...document.querySelectorAll('.ck-geral .ck-hit')].map(x => x.dataset.dica).join('|').replace(/\u00a0/g, ' ')"), 'Geral: 3 meses, lucro negativo de outubro', pg.evaluate("[...document.querySelectorAll('.ck-geral .ck-hit')].map(x => x.dataset.dica).join('|')"))
    chk(pg.evaluate("document.querySelectorAll('.ck-mkt .ck-hit').length") == 29, 'Marketing: uma coluna por dia no mês')
    chk(pg.evaluate("document.querySelectorAll('.ck-fin .ck-hb-l').length") == 4 and pg.evaluate("document.querySelectorAll('.ck-cs .ck-hb-l').length") == 2, 'Financeiro com 4 barras; Clientes com as etapas que têm alunos')
    chk(pg.evaluate("document.querySelector('.ck-cs .ck-hb-r').textContent") == 'Onboarding' and 'Mentoria · Plano' in pg.evaluate("document.querySelector('.ck-cs').innerText"), 'etapas em ordem, com o produto na frente')
    pg.hover('.ck-ven .ck-hit >> nth=2'); pg.wait_for_timeout(200)
    chk(pg.evaluate("!document.querySelector('#ckTip').hidden && document.querySelector('#ckTip').textContent.startsWith('03/10 · Faturamento')"), 'passar o mouse mostra o valor do dia', pg.evaluate("document.querySelector('#ckTip').textContent"))
    pg.click('[data-ckp=ano]'); pg.wait_for_timeout(900)
    chk(pg.evaluate("__calls.filter(c => c[0] === 'rpc' && c[1] === 'painel_gerencial').pop()[2].p_ini") == pg.evaluate("hoje().slice(0, 4) + '-01-01'"), 'período Ano muda a consulta')
    chk(pg.evaluate("document.querySelectorAll('.ck-mkt .ck-hit').length") == 1 and pg.evaluate("document.querySelector('.ck-mkt .ck-gt').textContent") == 'Leads por mês', 'no Ano, os gráficos juntam por mês')
    pg.click('.ck-cs'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("S.view") == 'ho-cg' and pg.evaluate("S.cg.aba") == 'indicadores', 'clicar em Clientes abre Customer Growth nos indicadores')
    for k, tela in [('mkt', 'mkt-dash'), ('fin', 'fin-dash'), ('ven', 'crm-dash'), ('prj', 'prj-lista'), ('gro', 'gro-modelo'), ('geral', 'adm-painel')]:
        pg.evaluate("S.view = 'cockpit'; render();"); pg.wait_for_timeout(900)
        pg.evaluate("k => document.querySelector('.ck-' + k).click()", k); pg.wait_for_timeout(400)
        chk(pg.evaluate("S.view") == tela, 'clicar em ' + k + ' abre ' + tela)
    pg.evaluate("S.perm = { modulos: { adm: 'ler', mkt: 'nenhum', vendas: 'ler', fin: 'nenhum', revops: 'ler' } }; S.permWs = S.ws; S.view = 'cockpit'; desenhaNav(); render();"); pg.wait_for_timeout(1200)
    chk(pg.evaluate("[...document.querySelectorAll('.ck-card h2')].map(h => h.textContent)") == ['Geral', 'Vendas', 'Clientes (CS)'], 'sem acesso a Marketing e Financeiro: esses painéis somem')
    pg.set_viewport_size({'width': 390, 'height': 900}); pg.wait_for_timeout(400)
    chk(pg.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 1"), 'no celular não rola para o lado')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
