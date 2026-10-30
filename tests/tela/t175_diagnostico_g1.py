import json, os, tempfile
# Teste de tela da v0.175 (Diagnóstico 360°, G1): modelo pronto "Diagnóstico 360°" (perguntas, condições e configuração), formulário
# público com os tipos novos (mês a mês, valor com "não sei", lista, documentos, métricas do funil pirata com tenho/não tenho e os detalhes),
# condição, filtro das métricas pelo modelo de negócio, link vencido e "Ver respostas" para a equipe.
# Rodar: python3 tests/tela/t175_diagnostico_g1.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't175_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
CAT = [dict(codigo='cac', nome='CAC', etapa='aquisicao', modelos=None, descricao='Quanto custa conquistar um cliente.'),
       dict(codigo='cpl', nome='CPL', etapa='aquisicao', modelos=None, descricao='Quanto custa cada lead.'),
       dict(codigo='ltv', nome='LTV', etapa='receita', modelos=None, descricao='Quanto um cliente deixa de receita.'),
       dict(codigo='mrr', nome='MRR', etapa='receita', modelos=['assinatura', 'comunidade'], descricao='Receita recorrente mensal.'),
       dict(codigo='churn', nome='Churn', etapa='retencao', modelos=None, descricao='Quem cancelou.')]
PERG = [
  dict(id='qm', texto='Modelo de negócio', tipo='multipla', opcoes=['Infoproduto ou curso', 'Assinatura ou recorrência'], obrigatoria=True, secao='Perfil', condicao=None, config={}),
  dict(id='qf', texto='Faturamento dos últimos 6 meses', tipo='meses', opcoes=[], obrigatoria=True, secao='Perfil', condicao=None, config={'meses': 6}),
  dict(id='qc', texto='CAC mídia', tipo='moeda', opcoes=[], obrigatoria=False, secao='Perfil', condicao=None, config={'naosei': True}),
  dict(id='qx', texto='Métricas', tipo='metricas', opcoes=[], obrigatoria=True, secao='Métricas', condicao=None, config={'modelo': 'qm', 'min_decide': 1, 'max_decide': 2}),
  dict(id='qn', texto='Tem North Star?', tipo='escolha', opcoes=['Sim', 'Não', 'Não sei'], obrigatoria=True, secao='Métricas', condicao=None, config={}),
  dict(id='qq', texto='Qual é a North Star?', tipo='texto', opcoes=[], obrigatoria=True, secao='Métricas', condicao={'pergunta': 'qn', 'valores': ['Sim']}, config={}),
  dict(id='ql', texto='Seus produtos', tipo='lista', opcoes=[], obrigatoria=True, secao='Produtos', condicao=None, config={'colunas': [{'k': 'nome', 'l': 'Produto', 't': 'texto'}, {'k': 'preco', 'l': 'Preço', 't': 'moeda'}]}),
  dict(id='qd', texto='Documentos', tipo='documentos', opcoes=[], obrigatoria=True, secao='Documentação', condicao=None, config={'categorias': [{'k': 'vendas', 'l': 'Vendas', 'd': 'Últimos 6 meses'}, {'k': 'crm', 'l': 'CRM e leads', 'd': ''}], 'aviso': 'Não envie senhas.'})]
PUB = dict(nome='Diagnóstico 360°', descricao='Primeiro passo', tipo='diagnostico', perguntas=PERG, aberto=False, ja_respondida=False, visual={}, captacao=None, metricas=CAT)
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'pesquisas': ws([]), 'pesquisa_perguntas': ws([]), 'pesquisa_envios': ws([]), 'pesquisa_respostas': ws([]), 'pesquisa_resposta_itens': ws([]), 'funis': ws([]), 'funil_etapas': ws([]),
  'etapas_kanban': ws([]), 'produtos': ws([]), 'jornadas': ws([]), 'pessoas': ws([]),
  'rpc:pesquisa_publica': PUB, 'rpc:pesquisa_responder': {'ok': True},
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def segue(pg): pg.click('[data-pf="segue"]'); pg.wait_for_timeout(250)
def msg(pg): return ev(pg, "document.querySelector('.pf-msg').textContent")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1200, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    # ---- equipe: criar do modelo ----
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'gro-pesq'; S.pqSel = null; render();"); pg.wait_for_timeout(1300)
    chk(ev(pg, "!!document.querySelector('#pqModelo option[value=diagnostico360]')"), 'o modelo "Diagnóstico 360°" aparece na lista de modelos')
    pg.select_option('#pqModelo', 'diagnostico360'); pg.wait_for_timeout(500)
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1800)
    pq = ev(pg, "__D.pesquisas[0]"); pp = ev(pg, "__D.pesquisa_perguntas")
    chk(pq and pq['tipo'] == 'diagnostico' and pq['publico'] == 'cliente' and pq['ativa'] is False, 'cria o diagnóstico para cliente, desativado', pq)
    chk(len(pp) >= 75, 'cria todas as perguntas do plano (seções B.1 a B.8)', len(pp))
    secs = []
    for x in pp:
        if x['secao'] not in secs: secs.append(x['secao'])
    chk(secs == ['Perfil do negócio', 'Produtos e ofertas', 'Jornada do cliente', 'Métricas do negócio', 'Infraestrutura de dados', 'Gestão e decisões', 'Prioridades de crescimento', 'Documentação'], 'as 8 seções na ordem', secs)
    ids = {x['id'] for x in pp}
    conds = [x for x in pp if x.get('condicao')]
    chk(conds and all(c['condicao']['pergunta'] in ids for c in conds), 'as condições apontam para perguntas do próprio formulário', len(conds))
    met = [x for x in pp if x['tipo'] == 'metricas']
    chk(len(met) == 1 and met[0]['config'].get('modelo') in ids and met[0]['config'].get('min_decide') == 5 and met[0]['config'].get('max_decide') == 8, 'bloco de métricas filtrado pelo modelo de negócio e com 5 a 8 "usadas para decidir"', met[0]['config'] if met else None)
    textos = ' | '.join(x['texto'] for x in pp)
    for frag in ['O que você espera deste trabalho?', 'O que precisa acontecer para você perceber que este trabalho está trazendo resultado?', 'Faturamento dos últimos 6 meses', 'CAC mídia', 'CAC médio', 'Canais que você usa', 'primeiro valor', 'North Star', 'Separa a receita de clientes novos']:
        chk(frag in textos, 'o modelo tem a pergunta: ' + frag)
    doc = [x for x in pp if x['tipo'] == 'documentos']
    chk(doc and [c['k'] for c in doc[0]['config']['categorias']] == ['vendas', 'crm', 'alunos', 'marketing', 'financeiro', 'produtos', 'complementares'], 'documentos com os 7 grupos (vendas, CRM e leads, alunos…)')
    # editor da pergunta com os tipos novos
    pg.evaluate("S.pqTab = 'perguntas'; render();"); pg.wait_for_timeout(1300)
    pg.evaluate("document.querySelector('#qNova').click()"); pg.wait_for_timeout(500)
    tps = ev(pg, "[...document.querySelectorAll('#modalRoot [name=tipo] option')].map(o => o.value)")
    chk(all(t in tps for t in ['numero', 'moeda', 'meses', 'metricas', 'lista', 'documentos']), 'o editor oferece os tipos novos', tps)
    chk(ev(pg, "!!document.querySelector('#modalRoot [name=cond_pergunta]')"), 'o editor tem a pergunta condicional')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # ---- cliente: formulário público ----
    pg.evaluate("document.querySelectorAll('#pubPesq').forEach(x => x.remove()); vPesquisaPublica('t'.repeat(40));"); pg.wait_for_timeout(1500)
    chk(ev(pg, "document.querySelectorAll('[data-mes]').length") == 6, 'faturamento: seis meses com o nome do mês')
    chk(ev(pg, "!!document.querySelector('[name=q_qc_ns]')"), 'CAC com "Não sei"')
    # passo 1 sem nada: cobra o modelo e o faturamento
    segue(pg); chk('Responda' in msg(pg) or 'Preencha' in msg(pg), 'cobra o que é obrigatório', msg(pg))
    pg.check('[name=q_qm][value="Infoproduto ou curso"]')
    segue(pg); chk('Preencha pelo menos um mês' in msg(pg), 'cobra pelo menos um mês do faturamento', msg(pg))
    ms = ev(pg, "[...document.querySelectorAll('[data-mes]')].map(i => i.dataset.mes)")
    pg.fill(f'[data-mes="{ms[-1]}"]', '50000'); pg.fill(f'[data-mes="{ms[-2]}"]', '45000')
    pg.check('[name=q_qc_ns]')
    chk(ev(pg, "document.querySelector('[name=q_qc]').disabled"), '"Não sei" desliga o campo de valor')
    segue(pg)
    # passo 2: métricas; MRR some para infoproduto
    chk(ev(pg, "document.querySelector('.pf-m[data-m=mrr]').hidden") and not ev(pg, "document.querySelector('.pf-m[data-m=cac]').hidden"), 'MRR some quando o modelo é infoproduto (filtro pelo modelo de negócio)')
    chk(ev(pg, "document.querySelectorAll('.pf-etapa h3').length") >= 3 and ev(pg, "document.querySelector('.pf-etapa h3').textContent") == 'Aquisição', 'métricas separadas por etapa do funil pirata')
    segue(pg); chk('Marque se vocês acompanham' in msg(pg), 'cobra marcar cada métrica (tenho / não tenho)', msg(pg))
    pg.check('[name=q_qx_cac][value=regular]'); pg.wait_for_timeout(150)
    chk(not ev(pg, "document.querySelector('.pf-m[data-m=cac] .pf-md').hidden"), '"Tenho" abre o bloco da métrica')
    campos = ev(pg, "[...document.querySelectorAll('.pf-m[data-m=cac] .pf-md [data-c]')].map(i => i.dataset.c)")
    for k in ['decide', 'objetivo', 'numerador', 'denominador', 'janela', 'inclui', 'calculo', 'como', 'fonte', 'atualiza', 'detalhe', 'responsavel', 'clareza', 'decisao', 'reacao', 'confere', 'confianca', 'valor']:
        chk(k in campos, 'bloco da métrica tem: ' + k)
    pg.fill('.pf-m[data-m=cac] [data-c=objetivo]', 'Controlar o custo do cliente'); pg.fill('.pf-m[data-m=cac] [data-c=numerador]', 'Investimento em mídia')
    pg.check('.pf-m[data-m=cac] [data-c=como][value="Planilha"]'); pg.check('.pf-m[data-m=cac] [data-c=como][value="Automação"]')
    pg.select_option('.pf-m[data-m=cac] [data-c=janela]', 'Mês'); pg.fill('.pf-m[data-m=cac] [data-c=responsavel]', 'Ana')
    pg.check('[name=q_qx_ltv][value=nao]'); pg.wait_for_timeout(100)
    chk(ev(pg, "document.querySelector('.pf-m[data-m=ltv] .pf-md').hidden") and not ev(pg, "document.querySelector('.pf-m[data-m=ltv] .pf-mn').hidden"), '"Não tenho" passa reto (só pergunta se tem os dados)')
    pg.select_option('.pf-m[data-m=ltv] [data-c=tem_dados]', 'sim')
    pg.check('[name=q_qx_cpl][value=nao_sei]'); pg.check('[name=q_qx_churn][value=ocasional]')
    pg.check('[name=q_qn][value="Não"]')
    segue(pg); chk('usamos para tomar decisões' in msg(pg), 'pede o mínimo de métricas "usadas para decidir"', msg(pg))
    pg.check('.pf-m[data-m=cac] [data-c=decide]')
    chk(ev(pg, "document.querySelector('.pf-dcont').textContent") == '1 marcada', 'contador das métricas "usadas para decidir"')
    chk(ev(pg, "document.querySelector('.pf-q[data-q=qq]').hidden"), 'pergunta condicional escondida (North Star = Não)')
    pg.check('[name=q_qn][value="Sim"]'); pg.wait_for_timeout(100)
    chk(not ev(pg, "document.querySelector('.pf-q[data-q=qq]').hidden"), 'aparece quando a resposta é Sim')
    segue(pg); chk('Responda' in msg(pg), 'a condicional visível é cobrada', msg(pg))
    pg.check('[name=q_qn][value="Não"]')
    if FOTOS: pg.screenshot(path=FOTOS + '/t175_metricas.png', full_page=True)
    segue(pg)
    # passo 3: lista
    pg.fill('.pf-lr .pf-lc >> nth=0', 'Mentoria'); pg.fill('.pf-lr .pf-lc >> nth=1', '3000')
    pg.click('.pf-lmais'); pg.wait_for_timeout(100)
    chk(ev(pg, "document.querySelectorAll('.pf-lr').length") == 2, '"+ Adicionar linha" na lista')
    pg.fill('.pf-lr >> nth=1 >> .pf-lc >> nth=0', 'Curso')
    segue(pg)
    # passo 4: documentos
    chk('Não envie senhas' in ev(pg, "document.querySelector('.pf-aviso2').textContent"), 'aviso de senhas e LGPD nos documentos')
    pg.click('[data-pf="envia"]'); pg.wait_for_timeout(300)
    chk('Marque cada grupo' in msg(pg), 'cobra cada grupo de documentos', msg(pg))
    pg.check('[name=q_qd_vendas][value=sim]'); pg.check('[name=q_qd_crm][value=depois]')
    pg.click('[data-pf="envia"]'); pg.wait_for_timeout(1200)
    call = ev(pg, "(__calls.filter(c => c[0] === 'rpc' && c[1] === 'pesquisa_responder').pop() || [])[2]")
    chk(call is not None, 'envia a resposta')
    r = (call or {}).get('p_respostas', {})
    chk(r.get('qm') == ['Infoproduto ou curso'], 'resposta: modelo')
    chk(r.get('qf') == {ms[-1]: 50000, ms[-2]: 45000}, 'resposta: faturamento mês a mês', r.get('qf'))
    chk('qc' not in r, 'resposta: "Não sei" não manda valor')
    m = r.get('qx', {})
    chk(m.get('cac', {}).get('status') == 'regular' and m['cac'].get('objetivo') == 'Controlar o custo do cliente' and m['cac'].get('como') == ['Planilha', 'Automação'] and m['cac'].get('decide') is True and m['cac'].get('janela') == 'Mês' and m['cac'].get('responsavel') == 'Ana', 'resposta: detalhe da métrica que tem', m.get('cac'))
    chk(m.get('ltv') == {'status': 'nao', 'tem_dados': 'sim'} and m.get('cpl') == {'status': 'nao_sei'} and 'mrr' not in m, 'resposta: não tenho, não sei e a métrica escondida fora', m)
    chk('qq' not in r and r.get('qn') == 'Não', 'resposta: a condicional escondida não vai')
    chk(r.get('ql') == [{'nome': 'Mentoria', 'preco': 3000}, {'nome': 'Curso'}], 'resposta: lista de produtos', r.get('ql'))
    chk(r.get('qd') == {'vendas': 'sim', 'crm': 'depois'}, 'resposta: documentos')
    if FOTOS: pg.screenshot(path=FOTOS + '/t175_fim.png')
    # link vencido
    pg.evaluate("document.querySelectorAll('#pubPesq').forEach(x => x.remove()); __D['rpc:pesquisa_publica'] = { nome: 'Diagnóstico 360°', expirado: true, visual: {} }; window.__RPC = window.__RPC || {}; window.__RPC.pesquisa_publica = () => ({ nome: 'Diagnóstico 360°', expirado: true, visual: {} }); vPesquisaPublica('v'.repeat(40));"); pg.wait_for_timeout(1000)
    chk('Link vencido' in ev(pg, "document.querySelector('#pubPesq').innerText"), 'link vencido mostra o aviso')
    pg.evaluate("document.querySelectorAll('#pubPesq').forEach(x => x.remove())")
    # ver respostas (equipe)
    pg.evaluate("""pqVerResposta([{ id: 'qx', texto: 'Métricas', tipo: 'metricas', secao: 'Métricas' }, { id: 'qf', texto: 'Faturamento', tipo: 'meses', secao: 'Perfil' }],
      [{ pergunta_id: 'qx', valor_num: 1, valor_json: { cac: { status: 'regular', decide: true, objetivo: 'Controlar o custo', como: ['Planilha'] }, ltv: { status: 'nao', tem_dados: 'sim' } } },
       { pergunta_id: 'qf', valor_json: { '2026-10': 50000 } }], 'Cliente · Diagnóstico')"""); pg.wait_for_timeout(400)
    t = ev(pg, "document.querySelector('#modalRoot').innerText").replace(' ', ' ')
    chk('1 acompanham' in t and 'usada para decidir' in t and 'Não acompanham: ltv (dados: sim)' in t and 'R$ 50.000,00' in t, '"Ver respostas" mostra métricas e faturamento formatados', t[:500])
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
