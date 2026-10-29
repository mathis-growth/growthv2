import json, os, tempfile
# Teste de tela da v0.164: o Growths abre no Cockpit, com um painel por área (Geral, Marketing, Vendas, Financeiro, Clientes),
# os números vêm de painel_gerencial e cg_indicadores, cada painel abre o dashboard do módulo e só aparece para quem tem acesso.
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
  'rpc:cg_indicadores': {'matriculas': {'ativas': 522, 'novas': 30, 'sairam': 4, 'sem_cs': 484}, 'alertas': {'parado': 340, 'sem_cs': 484},
    'intervencoes': {'abertas': 3, 'atrasadas': 1}, 'nps': {'nps': 43, 'respostas': 20}},
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
    chk(pg.evaluate("[...document.querySelectorAll('.ck-card h2')].map(h => h.textContent)") == ['Geral', 'Marketing', 'Vendas', 'Financeiro', 'Clientes (CS)'], 'cinco painéis na ordem')
    chk(pg.evaluate("!!document.querySelector('#nav [data-v=cockpit]')"), 'Cockpit no menu')
    g = card(pg, 'geral')
    chk(all(x in g for x in ['Saldo em caixa', 'R$ 18.500,00', 'Receita', 'R$ 24.000,00', 'Vendas 12', 'Margem', '−6,3%', 'Lucro', '−R$ 1.500,00']), 'Geral: caixa, receita, vendas, margem e lucro', g)
    chk(pg.evaluate("document.querySelector('.ck-geral .ck-i.ck-neg .l') && [...document.querySelectorAll('.ck-geral .ck-i.ck-neg .l')].map(x => x.textContent).join()") == 'Margem,Lucro', 'lucro e margem negativos em vermelho')
    mk = card(pg, 'mkt')
    chk('Campanhas ativas 2' in mk and '1 planejadas' in mk and 'Leads no período 120' in mk and 'Leads em andamento 108' in mk and 'R$ 450,00' in mk, 'Marketing: campanhas, leads e CAC', mk)
    v = card(pg, 'ven')
    chk('Vendas aprovadas 12' in v and 'R$ 2.000,00' in v and '10,0%' in v and 'Oportunidades abertas 2' in v and 'R$ 5.000,00 em negociação' in v, 'Vendas: aprovadas, ticket, conversão e oportunidades', v)
    f = card(pg, 'fin')
    chk('A receber R$ 9.000,00' in f and 'R$ 1.200,00 em atraso' in f and 'A pagar R$ 4.000,00' in f and 'R$ 6.000,00' in f and 'MRR R$ 3.500,00' in f, 'Financeiro: saldo, receber, pagar, fluxo e MRR', f)
    c = card(pg, 'cs')
    chk('Alunos ativos 522' in c and 'Alertas abertos 824' in c and 'Intervenções abertas 3' in c and 'NPS dos alunos 43' in c and 'Sem CS responsável 484' in c, 'Clientes: ativos, alertas, intervenções, NPS e sem CS', c)
    pg.click('[data-ckp=ano]'); pg.wait_for_timeout(900)
    chk(pg.evaluate("__calls.filter(c => c[0] === 'rpc' && c[1] === 'painel_gerencial').pop()[2].p_ini") == pg.evaluate("hoje().slice(0, 4) + '-01-01'"), 'período Ano muda a consulta')
    pg.click('.ck-cs'); pg.wait_for_timeout(1200)
    chk(pg.evaluate("S.view") == 'ho-cg' and pg.evaluate("S.cg.aba") == 'indicadores', 'clicar em Clientes abre Customer Growth nos indicadores')
    for k, tela in [('mkt', 'mkt-dash'), ('fin', 'fin-dash'), ('ven', 'crm-dash'), ('geral', 'adm-painel')]:
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
