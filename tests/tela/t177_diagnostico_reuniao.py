import json, os, tempfile
# Teste de tela da v0.177 (Diagnóstico 360°, G1b, G2 e G3):
# G1b: modelo curto "Diagnóstico 360° (cliente, curto)", métricas no modo simples (acompanho / não acompanho / não sei e onde vê),
#      rascunho (salva a cada passo e volta de onde parou).
# G2:  envio de arquivos pelo link (autorizar → enviar → confirmar, tirar arquivo), página só de arquivos depois de responder.
# G3:  reunião (números para decidir, perguntas por natureza, roteiro do modelo completo, documentos, validar) e a leitura dos
#      arquivos no Diagnóstico Growth guardada no diagnóstico do cliente, sem mexer no Growth Model.
# Rodar: python3 tests/tela/t177_diagnostico_reuniao.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't177_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
CAT = [dict(codigo='investimento', nome='Investimento', etapa='aquisicao', modelos=None, descricao='Quanto coloca em anúncios.'),
       dict(codigo='cac', nome='CAC', etapa='aquisicao', modelos=None, descricao='Quanto custa conquistar um cliente.'),
       dict(codigo='roas', nome='ROAS', etapa='aquisicao', modelos=None, descricao='Retorno do anúncio.'),
       dict(codigo='churn', nome='Churn', etapa='retencao', modelos=None, descricao='Quem cancelou.'),
       dict(codigo='ltv', nome='LTV', etapa='receita', modelos=None, descricao='Fora da lista curta.')]
PERG = [
  dict(id='qe', texto='Nome da empresa', tipo='texto', opcoes=[], obrigatoria=True, secao='Sobre o seu negócio', condicao=None, config={}),
  dict(id='qm', texto='Como você vende?', tipo='multipla', opcoes=['Infoproduto ou curso', 'Mentoria'], obrigatoria=True, secao='Sobre o seu negócio', condicao=None, config={}),
  dict(id='qf', texto='Faturamento dos últimos 6 meses', tipo='meses', opcoes=[], obrigatoria=True, secao='Seus números', condicao=None, config={'meses': 6}),
  dict(id='qx', texto='O que você acompanha', tipo='metricas', opcoes=[], obrigatoria=True, secao='O que você acompanha hoje', condicao=None, config={'modelo': 'qm', 'simples': True, 'codigos': ['investimento', 'cac', 'roas', 'churn']}),
  dict(id='qd', texto='Seus arquivos', tipo='documentos', opcoes=[], obrigatoria=True, secao='Seus arquivos', condicao=None, config={'upload': True, 'categorias': [{'k': 'vendas', 'l': 'Vendas', 'd': ''}, {'k': 'crm', 'l': 'CRM e leads', 'd': ''}], 'aviso': 'Não envie senhas.'})]
PUB = dict(nome='Diagnóstico 360° (cliente, curto)', descricao='Leva uns 15 minutos.', tipo='diagnostico', perguntas=PERG, aberto=False, ja_respondida=False, visual={}, captacao=None, metricas=CAT, rascunho=None, expira_em='2026-12-01T00:00:00Z')
MD = [dict(codigo='investimento', nome='Investimento', etapa_aarrr='aquisicao', natureza='valor', ordem=1, descricao_cliente=''), dict(codigo='cac', nome='CAC', etapa_aarrr='aquisicao', natureza='taxa', ordem=2, descricao_cliente=''),
      dict(codigo='roas', nome='ROAS', etapa_aarrr='aquisicao', natureza='taxa', ordem=3, descricao_cliente=''), dict(codigo='churn', nome='Churn', etapa_aarrr='retencao', natureza='taxa', ordem=4, descricao_cliente=''),
      dict(codigo='ltv', nome='LTV', etapa_aarrr='receita', natureza='taxa', ordem=5, descricao_cliente='')]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'pesquisas': ws([dict(id='pq', nome='Diagnóstico 360° (cliente, curto)', tipo='diagnostico', publico='cliente', gatilho='manual', ativa=True, criado_em='2026-10-30')]),
  'pesquisa_perguntas': ws([dict(pesquisa_id='pq', ordem=k + 1, papel='livre', criado_em='2026-10-30', **x) for k, x in enumerate(PERG)]),
  'pesquisa_envios': ws([dict(id='env1', pesquisa_id='pq', pessoa_id='pe1', status='respondido')]),
  'pesquisa_respostas': ws([dict(id='r1', pesquisa_id='pq', envio_id='env1', pessoa_id='pe1', respondida_em='2026-10-30T12:00:00Z')]),
  'pesquisa_resposta_itens': ws([dict(id='i1', resposta_id='r1', pergunta_id='qe', valor_texto='Escola Aurora'), dict(id='i2', resposta_id='r1', pergunta_id='qf', valor_json={'2026-09': 40000, '2026-10': 60000}),
    dict(id='i3', resposta_id='r1', pergunta_id='qx', valor_num=2, valor_json={'investimento': {'status': 'regular', 'como': ['Ferramenta de anúncios']}, 'cac': {'status': 'regular', 'como': ['Planilha']}, 'churn': {'status': 'nao'}}),
    dict(id='i4', resposta_id='r1', pergunta_id='qd', valor_json={'vendas': 'sim', 'crm': 'depois'})]),
  'pessoas': ws([dict(id='pe1', nome='Ana Aurora', email='ana@aurora.com', tags=[])]),
  'pesquisa_arquivos': ws([dict(id='a1', envio_id='env1', grupo='vendas', nome='vendas.csv', caminho='w1/env1/a1.csv', tamanho=120, status='enviado', enviado_em='2026-10-30T12:00:00Z'),
    dict(id='a2', envio_id='env1', grupo='vendas', nome='contrato.pdf', caminho='w1/env1/a2.pdf', tamanho=5000, status='enviado', enviado_em='2026-10-30T12:01:00Z')]),
  'diagnosticos': ws([]), 'diagnostico_metricas': ws([]), 'metricas_definicoes': MD, 'gm_modelos': ws([]),
  'funis': ws([]), 'funil_etapas': ws([]), 'etapas_kanban': ws([]), 'produtos': ws([]), 'jornadas': ws([]),
  'rpc:pesquisa_publica': PUB, 'rpc:pesquisa_responder': {'ok': True}, 'rpc:pesquisa_rascunho_salvar': '2026-10-30T12:00:00Z', 'rpc:pesquisa_arquivos_do_link': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
def segue(pg): pg.click('[data-pf="segue"]'); pg.wait_for_timeout(300)
def msg(pg): return ev(pg, "document.querySelector('.pf-msg').textContent")
# funções na nuvem e Storage de mentira, que registram as chamadas
FAKE = """
window.__fn = []; window.__up = [];
sb.functions = { invoke: async (n, o) => { const b = o.body; __fn.push([n, b.acao, b]);
  if (b.acao === 'autorizar') return { data: { ok: true, id: 'novo' + __fn.length, caminho: 'w1/env/novo' + __fn.length + '.csv', envio: 'up' }, error: null };
  return { data: { ok: true }, error: null }; } };
sb.storage = { from: bk => ({ uploadToSignedUrl: async (c, t, f) => { __up.push([bk, c, f.name]); return { data: {}, error: null }; },
  createSignedUrl: async (c) => ({ data: { signedUrl: 'about:blank#' + c }, error: null }),
  download: async (c) => ({ data: new Blob(['Data;Produto;Valor;Email;Status\\n2026-09-10;Curso;997;a@a.com;aprovada\\n2026-10-12;Curso;997;b@b.com;aprovada\\n'], { type: 'text/csv' }), error: null }) }) };
"""
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1280, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate(FAKE)
    # ---- G1b: modelo curto ----
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'gro-pesq'; S.pqSel = null; render();"); pg.wait_for_timeout(1300)
    chk(ev(pg, "!!document.querySelector('#pqModelo option[value=diagnostico_cliente]') && !!document.querySelector('#pqModelo option[value=diagnostico360]')"), 'o modelo curto aparece, e o completo continua na lista')
    n0 = ev(pg, "__D.pesquisas.length")
    pg.select_option('#pqModelo', 'diagnostico_cliente'); pg.wait_for_timeout(500)
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    novo = ev(pg, "__D.pesquisas[__D.pesquisas.length - 1]"); pp = ev(pg, "__D.pesquisa_perguntas.filter(x => x.pesquisa_id === __D.pesquisas[__D.pesquisas.length - 1].id)")
    secs = []
    for x in pp:
        if x['secao'] not in secs: secs.append(x['secao'])
    chk(ev(pg, "__D.pesquisas.length") == n0 + 1 and novo['tipo'] == 'diagnostico' and novo['ativa'] is False, 'cria o diagnóstico curto, desativado', novo)
    chk(secs == ['Sobre o seu negócio', 'O que você espera', 'Seus números', 'Como os clientes chegam e compram', 'O que você acompanha hoje', 'Seus arquivos'], 'as 6 partes da prévia, na ordem', secs)
    met = [x for x in pp if x['tipo'] == 'metricas'][0]; doc = [x for x in pp if x['tipo'] == 'documentos'][0]
    chk(met['config'].get('simples') is True and len(met['config'].get('codigos', [])) == 21 and met['config'].get('modelo') in {x['id'] for x in pp}, 'métricas no modo simples, com a lista curta de 21 e filtradas pelo modelo', met['config'])
    chk(doc['config'].get('upload') is True and len(doc['config']['categorias']) == 7, 'documentos com envio de arquivo e os 7 grupos')
    chk(len(pp) <= 16, 'formulário curto (até 16 perguntas)', len(pp))
    # ---- formulário público: rascunho e métricas simples ----
    pg.evaluate("S.pqSel = null; document.querySelectorAll('#pubPesq').forEach(x => x.remove()); vPesquisaPublica('t'.repeat(40));"); pg.wait_for_timeout(1500)
    chk('fica salvo' in ev(pg, "document.querySelector('.pf-acts > span').textContent"), 'avisa que o que responde fica salvo')
    pg.fill('#pubPesq .pf-q[data-q=qe] textarea', 'Escola Aurora'); pg.check('#pubPesq [name=q_qm][value="Mentoria"]', force=True)
    segue(pg)
    rc = ev(pg, "(__calls.filter(c => c[0] === 'rpc' && c[1] === 'pesquisa_rascunho_salvar').pop() || [])[2]")
    chk(rc and rc['p_dados']['passo'] == 1 and any('Escola Aurora' == v for v in rc['p_dados']['campos'].values()), 'salva o rascunho ao passar de parte', rc)
    pg.fill('#pubPesq [data-mes]', '45000'); segue(pg)
    ops = ev(pg, "[...document.querySelectorAll('#pubPesq .pf-m[data-m=cac] .pf-ops input[type=radio]')].map(i => i.closest('label').textContent.trim())")
    chk(ops == ['Acompanho', 'Não acompanho', 'Não sei'], 'métrica no modo simples tem só as 3 opções', ops)
    chk(ev(pg, "document.querySelectorAll('#pubPesq .pf-m').length") == 4, 'só as métricas da lista curta aparecem', ev(pg, "document.querySelectorAll('#pubPesq .pf-m').length"))
    chk(ev(pg, "document.querySelectorAll('#pubPesq .pf-m[data-m=cac] .pf-md [data-c]').length") == len(['Planilha', 'Plataforma de venda', 'Ferramenta de anúncios', 'CRM', 'Painel ou dashboard', 'De cabeça']), 'o bloco de "Acompanho" só pergunta onde vê')
    pg.check('#pubPesq .pf-m[data-m=cac] input[value=regular]', force=True); pg.wait_for_timeout(100)
    chk(ev(pg, "!document.querySelector('#pubPesq .pf-m[data-m=cac] .pf-md').hidden"), '"Acompanho" abre o "onde vê"')
    pg.check('#pubPesq .pf-m[data-m=cac] .pf-md input[value="Planilha"]', force=True)
    pg.check('#pubPesq .pf-m[data-m=investimento] input[value=regular]', force=True)
    pg.check('#pubPesq .pf-m[data-m=roas] input[value=nao]', force=True)
    segue(pg); chk('Marque se vocês acompanham' in msg(pg), 'cobra a métrica que falta marcar', msg(pg))
    pg.check('#pubPesq .pf-m[data-m=churn] input[value=nao_sei]', force=True); segue(pg)
    chk(ev(pg, "!document.querySelector('[data-passo=\"3\"]').hidden"), 'chega na parte dos arquivos')
    # ---- G2: envio de arquivo ----
    pg.set_input_files('#pubPesq [data-up=vendas]', files=[{'name': 'vendas.csv', 'mimeType': 'text/csv', 'buffer': b'a;b\n1;2\n'}]); pg.wait_for_timeout(600)
    acs = ev(pg, "__fn.map(x => x[1])")
    chk(acs[:2] == ['autorizar', 'confirmar'] and ev(pg, "__up.length") == 1 and ev(pg, "__up[0][0]") == 'diagnostico', 'envia: autoriza, sobe no local "diagnostico" e confirma', [acs, ev(pg, "__up")])
    chk(ev(pg, "__fn[0][2].grupo") == 'vendas' and ev(pg, "__fn[0][2].nome") == 'vendas.csv' and ev(pg, "__fn[0][2].token").startswith('ttt'), 'manda o grupo, o nome e o link')
    chk(ev(pg, "document.querySelectorAll('#pubPesq .pf-doc[data-g=vendas] .pf-arqs li').length") == 1 and ev(pg, "document.querySelector('#pubPesq .pf-doc[data-g=vendas] .pf-upsim').checked"), 'o arquivo aparece e o grupo conta como "tem"')
    pg.set_input_files('#pubPesq [data-up=crm]', files=[{'name': 'virus.exe', 'mimeType': 'application/octet-stream', 'buffer': b'x'}]); pg.wait_for_timeout(300)
    chk('não aceito' in msg(pg) and ev(pg, "__fn.length") == 2, 'recusa tipo de arquivo não aceito sem chamar o servidor', msg(pg))
    pg.click('[data-pf="envia"]'); pg.wait_for_timeout(300)
    chk('envie um arquivo ou marque' in msg(pg), 'cobra cada grupo: arquivo, "mando depois" ou "não tenho"', msg(pg))
    pg.click('#pubPesq .pf-doc[data-g=vendas] .pf-arx'); pg.wait_for_timeout(400)
    chk(ev(pg, "__fn[__fn.length - 1][1]") == 'remover' and ev(pg, "document.querySelectorAll('#pubPesq .pf-doc[data-g=vendas] .pf-arqs li').length") == 0 and not ev(pg, "document.querySelector('#pubPesq .pf-doc[data-g=vendas] .pf-upsim').checked"), 'tirar o arquivo remove no servidor e desmarca o grupo')
    pg.check('#pubPesq [name=q_qd_vendas][value=depois]', force=True); pg.check('#pubPesq [name=q_qd_crm][value=nao]', force=True)
    pg.click('[data-pf="envia"]'); pg.wait_for_timeout(500)
    call = ev(pg, "(__calls.filter(c => c[0] === 'rpc' && c[1] === 'pesquisa_responder').pop() || [])[2]")
    r = (call or {}).get('p_respostas', {})
    chk(r.get('qx', {}).get('cac') == {'status': 'regular', 'como': ['Planilha']} and r['qx']['roas'] == {'status': 'nao'}, 'envia a métrica simples como "regular" com onde vê', r.get('qx'))
    chk(r.get('qd') == {'vendas': 'depois', 'crm': 'nao'}, 'envia a situação de cada grupo de arquivos', r.get('qd'))
    # rascunho volta de onde parou
    rasc = ev(pg, "(__calls.filter(c => c[0] === 'rpc' && c[1] === 'pesquisa_rascunho_salvar').pop() || [])[2].p_dados")
    pg.evaluate("(r) => { __D['rpc:pesquisa_publica'] = { ...__D['rpc:pesquisa_publica'], rascunho: r }; document.querySelectorAll('#pubPesq').forEach(x => x.remove()); vPesquisaPublica('t'.repeat(40)); }", rasc); pg.wait_for_timeout(1500)
    chk(ev(pg, "!document.querySelector('[data-passo=\"' + %d + '\"]').hidden" % rasc['passo']), 'volta na parte em que parou', rasc['passo'])
    chk(ev(pg, "document.querySelector('#pubPesq .pf-q[data-q=qe] textarea').value") == 'Escola Aurora' and ev(pg, "document.querySelector('#pubPesq .pf-m[data-m=cac] input[value=regular]').checked")
        and ev(pg, "!document.querySelector('#pubPesq .pf-m[data-m=cac] .pf-md').hidden") and ev(pg, "document.querySelector('#pubPesq .pf-m[data-m=cac] .pf-md input[value=Planilha]').checked"), 'restaura texto, métrica e o "onde vê"')
    chk('onde você parou' in ev(pg, "document.querySelector('.pf-acts > span').textContent"), 'avisa que continuou de onde parou')
    # página só de arquivos depois de responder
    pg.evaluate("__D['rpc:pesquisa_publica'] = { ...__D['rpc:pesquisa_publica'], ja_respondida: true, rascunho: null }; __D['rpc:pesquisa_arquivos_do_link'] = [{ id: 'x1', grupo: 'vendas', nome: 'antigo.xlsx', tamanho: 2048 }]; document.querySelectorAll('#pubPesq').forEach(x => x.remove()); vPesquisaPublica('t'.repeat(40));"); pg.wait_for_timeout(1500)
    chk('mandar os arquivos que faltaram' in ev(pg, "document.querySelector('#pubPesq').textContent") and ev(pg, "document.querySelectorAll('#pubPesq [data-up]').length") == 7 - 5, 'depois de responder, o link abre só para mandar arquivos', ev(pg, "document.querySelectorAll('#pubPesq [data-up]').length"))
    chk('antigo.xlsx' in ev(pg, "document.querySelector('#pubPesq').textContent"), 'mostra o que já foi enviado')
    pg.evaluate("document.querySelectorAll('#pubPesq').forEach(x => x.remove())")
    # ---- G3: reunião ----
    pg.evaluate("S.view = 'gro-pesq'; S.pqSel = 'pq'; S.pqTab = 'quem'; render();"); pg.wait_for_timeout(1500)
    chk(ev(pg, "!!document.querySelector('[data-reu=r1]')"), '"Abrir reunião" em Quem respondeu')
    pg.click('[data-reu=r1]'); pg.wait_for_timeout(1500)
    dg = ev(pg, "__D.diagnosticos[0]")
    chk(dg and dg['resposta_id'] == 'r1', 'cria o diagnóstico da resposta', dg)
    txt = ev(pg, "document.querySelector('#main').textContent")
    chk('Reunião do diagnóstico: Ana Aurora' in txt and 'Escola Aurora' in txt and '50.000' in txt, 'abre com o nome e o resumo das respostas (faturamento médio)', txt[:300])
    chk(ev(pg, "[...document.querySelectorAll('[data-dgdec]')].map(i => i.dataset.dgdec).sort().join()") == 'cac,investimento', 'oferece para decidir só o que ele acompanha')
    chk('Não acompanham:' in txt and 'Churn' in txt, 'lista o que não acompanham')
    pg.check('[data-dgdec=cac]', force=True); pg.wait_for_timeout(300); pg.check('[data-dgdec=investimento]', force=True); pg.wait_for_timeout(300)
    chk(ev(pg, "!!document.querySelector('[data-dgm=cac] [data-dgk=numerador]') && !document.querySelector('[data-dgm=cac] [data-dgk=compara]')"), 'taxa (CAC) pergunta a conta: numerador, denominador, período')
    chk(ev(pg, "!!document.querySelector('[data-dgm=investimento] [data-dgk=compara]') && !document.querySelector('[data-dgm=investimento] [data-dgk=numerador]')"), 'valor (investimento) pergunta onde vê e se olha junto com o resultado')
    chk('Ferramenta de anúncios' in ev(pg, "document.querySelector('[data-dgm=investimento]').textContent") and 'ROAS' in ev(pg, "document.querySelector('[data-dgm=investimento]').textContent"), 'mostra onde o cliente disse que vê e o resultado para comparar')
    pg.fill('[data-dgm=cac] [data-dgk=numerador]', 'Investimento do mês'); pg.wait_for_timeout(1200)
    mt = ev(pg, "__D.diagnostico_metricas.find(x => x.codigo === 'cac')")
    chk(mt and mt['detalhe'].get('numerador') == 'Investimento do mês' and mt['decide'] is True and mt['declarado'] == {'status': 'regular', 'como': ['Planilha']}, 'salva sozinho o detalhe da métrica, com o declarado', mt)
    chk(ev(pg, "__D.diagnosticos[0].decide.slice().sort().join()") == 'cac,investimento', 'salva os números usados para decidir')
    pg.select_option('#dgMais', 'ltv'); pg.wait_for_timeout(500)
    chk(ev(pg, "!!document.querySelector('[data-dgm=ltv]')"), 'inclui outro número do catálogo')
    secs = ev(pg, "[...document.querySelectorAll('.dg-sec')].map(s => s.dataset.dgs)")
    chk(secs == ['Perfil do negócio', 'Produtos e ofertas', 'Jornada do cliente', 'Métricas do negócio', 'Infraestrutura de dados', 'Gestão e decisões', 'Prioridades de crescimento'], 'o roteiro traz as seções do modelo completo', secs)
    rot = ev(pg, "[...document.querySelectorAll('.dg-rf label')].map(l => l.textContent).join(' | ')")
    for frag in ['CAC médio', 'North Star', 'primeiro valor', 'Separa a receita de clientes novos', 'Os links usam UTMs', 'Rotina de análise', 'Onde estão os gargalos']:
        chk(frag in rot, 'o roteiro tem: ' + frag)
    chk('O que você espera deste trabalho?' not in rot and 'Canais que você usa' not in rot, 'o roteiro não repete o que o formulário curto já perguntou')
    pg.evaluate("document.querySelector('.dg-sec[data-dgs=\"Métricas do negócio\"]').open = true"); pg.wait_for_timeout(100)
    nsq = "[...document.querySelectorAll('.dg-rf')].find(f => f.textContent.startsWith('Qual é a North Star?'))"
    chk(ev(pg, nsq + ".hidden"), 'pergunta condicional do roteiro começa escondida')
    pg.evaluate("(() => { const s = [...document.querySelectorAll('.dg-rf')].find(f => f.dataset.dgrk === 'ns').querySelector('select'); s.value = 'Sim'; s.dispatchEvent(new Event('change', { bubbles: true })); })()"); pg.wait_for_timeout(1000)
    chk(not ev(pg, nsq + ".hidden"), 'responder "Sim" na North Star abre a pergunta seguinte')
    chk(ev(pg, "__D.diagnosticos[0].arquitetura.roteiro[[...document.querySelectorAll('.dg-rf')].find(f => f.dataset.dgrk === 'ns').querySelector('label').textContent]") == 'Sim', 'salva a resposta do roteiro')
    # documentos
    dtxt = ev(pg, "document.querySelector('#main').textContent")
    chk('vendas.csv' in dtxt and 'contrato.pdf' in dtxt and 'Vai mandar depois' in dtxt, 'mostra os arquivos e o que o cliente disse de cada grupo')
    chk('1 planilha(s) para ler' in dtxt, 'conta só as planilhas para ler')
    pg.click('#dgLer'); pg.wait_for_timeout(2500)
    chk(ev(pg, "S.view") == 'gro-diag' and 'Diagnóstico Growth: Ana Aurora' in ev(pg, "document.querySelector('#main').textContent"), 'abre o Diagnóstico Growth com o nome do cliente')
    chk(ev(pg, "S.gxC && S.gxC.tabs.length") == 1 and ev(pg, "S.gxC.tabs[0].arq") == 'vendas.csv', 'já com a planilha do cliente lida (sem subir de novo)', ev(pg, "S.gxC && S.gxC.tabs.map(t => t.arq)"))
    chk(not ev(pg, "!!document.querySelector('#gxVaiModelo')") and not ev(pg, "S.gx && S.gx.tabs && S.gx.tabs.length"), 'não mistura com o Diagnóstico Growth da empresa')
    pg.evaluate("document.querySelector('#gxPasso2').click()"); pg.wait_for_timeout(600)
    pg.evaluate("document.querySelector('#gxCons').click()"); pg.wait_for_timeout(1200)
    chk(ev(pg, "!!document.querySelector('#gxGuarda') && !document.querySelector('#gxSalva')"), 'no lugar de "Salvar no Growth Model", "Guardar no diagnóstico do cliente"')
    pg.click('#gxGuarda'); pg.wait_for_timeout(1800)
    lt = ev(pg, "__D.diagnosticos[0].leitura")
    chk(lt and isinstance(lt.get('score'), (int, float)) and lt.get('itens') and lt.get('mensagem'), 'guarda completude, o que tem e o que falta e a mensagem no diagnóstico', lt and list(lt.keys()))
    chk(ev(pg, "__D.gm_modelos.length") == 0, 'não mexe no Growth Model da empresa')
    chk(ev(pg, "S.view") == 'gro-pesq' and ev(pg, "!!document.querySelector('#dgMsgCli')"), 'volta para a reunião já com a leitura e a mensagem')
    pg.click('#dgValida'); pg.wait_for_timeout(800)
    chk(ev(pg, "__D.diagnosticos[0].status") == 'validado', 'valida o diagnóstico')
    # ficha da pessoa
    pg.evaluate("S.view = 'gro-pesq'; S.dgReu = null; render();"); pg.wait_for_timeout(800)
    pg.evaluate("fichaPessoa('pe1')"); pg.wait_for_timeout(1800)
    chk(ev(pg, "!!document.querySelector('#modalRoot [data-dgreu=r1]')"), 'a ficha do cliente tem "Abrir reunião"')
    pg.evaluate("document.querySelector('#modalRoot [data-dgreu=r1]').click()"); pg.wait_for_timeout(1800)
    chk('Reunião do diagnóstico' in ev(pg, "document.querySelector('#main').textContent"), 'abre a reunião pela ficha')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
