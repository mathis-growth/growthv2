import json, os, tempfile, urllib.parse
# Teste de tela da v0.201: modelo "Entrada do cliente (números e arquivos)" — formulário curto (4 partes), a visão do cliente
# (faturamento, ticket, clientes, investimento, custo, regime), o período pedido pela data e o checklist de arquivos com
# planilha-modelo (CSV com ; e as colunas que a importação vai ler). Rodar: python3 tests/tela/t201_entrada_cliente.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't201_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'pesquisas': ws([]), 'pesquisa_perguntas': ws([]), 'pesquisa_envios': ws([]), 'pesquisa_respostas': ws([]), 'pesquisa_resposta_itens': ws([]), 'pessoas': ws([]),
  'funis': ws([]), 'funil_etapas': ws([]), 'etapas_kanban': ws([]), 'produtos': ws([]), 'jornadas': ws([]), 'metricas_definicoes': [],
  'rpc:pesquisa_rascunho_salvar': '2026-11-01T12:00:00Z', 'rpc:pesquisa_arquivos_do_link': []}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:500]) if (extra != '' and not c) else '')); ok = ok and bool(c)
def ev(pg, js, *a): return pg.evaluate(js, *a)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1100, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; window.hoje = () => '2026-11-01'; S.ws = S.wsBase = 'w1'; S.view = 'gro-pesq'; S.pqSel = null; render();"); pg.wait_for_timeout(1300)
    chk(ev(pg, "!!document.querySelector('#pqModelo option[value=entrada_cliente]')"), 'o modelo "Entrada do cliente" aparece na lista de modelos')
    pg.select_option('#pqModelo', 'entrada_cliente'); pg.wait_for_timeout(500)
    chk('13 perguntas em 4 passos' in pg.inner_text('#modalRoot'), 'curto: 13 perguntas em 4 passos', pg.inner_text('#modalRoot'))
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    pq = ev(pg, "__D.pesquisas[__D.pesquisas.length - 1]"); pp = ev(pg, "__D.pesquisa_perguntas.filter(x => x.pesquisa_id === __D.pesquisas[__D.pesquisas.length - 1].id)")
    chk(pq['tipo'] == 'diagnostico' and pq['ativa'] is False and pq['nome'].startswith('Entrada do cliente'), 'cria a pesquisa, desativada, no tipo diagnóstico (mesmo link e envio de arquivos)', pq)
    textos = ' | '.join(x['texto'] for x in pp)
    chk(all(t in textos for t in ['Faturamento médio por mês', 'Ticket médio', 'clientes ativos', 'investe em anúncios', 'custa a operação', 'Regime tributário']), 'a visão do cliente: faturamento, ticket, clientes, investimento, custo e regime')
    doc = [x for x in pp if x['tipo'] == 'documentos'][0]; cats = doc['config']['categorias']
    chk([c['k'] for c in cats] == ['vendas', 'alunos', 'crm', 'marketing', 'financeiro'] and doc['config']['upload'] is True, 'checklist: vendas, clientes, leads, anúncios e custos (opcional), com envio de arquivo', [c['k'] for c in cats])
    chk('dos últimos 12 meses completos (de nov/2025 a out/2026)' in doc['texto'], 'em novembro pede os últimos 12 meses completos: ' + doc['texto'][:120])
    per1 = ev(pg, "entPeriodo('2027-03-10').txt")
    chk('do ano passado inteiro' in per1 and 'jan/2026' in per1 and 'fev/2027' in per1, 'em março pede o ano passado inteiro e este ano até agora: ' + per1)
    # formulário público
    pg.evaluate("""(() => { const pq = __D.pesquisas[__D.pesquisas.length - 1], pp = __D.pesquisa_perguntas.filter(x => x.pesquisa_id === pq.id).sort((a, b) => a.ordem - b.ordem);
      __D['rpc:pesquisa_publica'] = { nome: pq.nome, descricao: pq.descricao, tipo: 'diagnostico', perguntas: pp, aberto: false, ja_respondida: false, visual: {}, captacao: null, metricas: [], rascunho: null, expira_em: '2026-12-01T00:00:00Z' };
      document.querySelectorAll('#pubPesq').forEach(x => x.remove()); vPesquisaPublica('t'.repeat(40)); })()"""); pg.wait_for_timeout(1500)
    chk(ev(pg, "document.querySelectorAll('#pubPesq [data-passo]').length") == 4, 'o cliente vê 4 partes')
    links = ev(pg, "[...document.querySelectorAll('#pubPesq .pf-doc .pf-mod')].map(a => [a.closest('.pf-doc').dataset.g, a.getAttribute('download'), a.getAttribute('href')])")
    chk(len(links) == 5, 'cada grupo de arquivo tem "Baixar planilha-modelo"', links and [l[:2] for l in links])
    csv = urllib.parse.unquote(links[0][2].split(',', 1)[1]) if links else ''
    chk(csv.startswith('﻿data_venda;produto;valor;status;plataforma;email_cliente') and 'Hotmart' in csv, 'a planilha-modelo de vendas vem com as colunas e uma linha de exemplo, separada por ;', csv[:120])
    chk('Hotmart, Kiwify ou Eduzz' in ev(pg, "document.querySelector('#pubPesq .pf-doc[data-g=vendas] small').textContent"), 'vendas aceita o relatório que a plataforma exporta')
    if FOTOS:
        pg.evaluate("document.querySelectorAll('#pubPesq [data-passo]').forEach(s => s.hidden = s.dataset.passo !== '3')"); pg.wait_for_timeout(200)
        pg.screenshot(path=FOTOS + '/t201_arquivos.png', full_page=True)
        pg.evaluate("document.querySelectorAll('#pubPesq [data-passo]').forEach(s => s.hidden = s.dataset.passo !== '1')"); pg.wait_for_timeout(200)
        pg.screenshot(path=FOTOS + '/t201_numeros.png', full_page=True)
    chk(not errs, 'sem erros de página', errs[:3])
    b.close()
print('\n' + ('OK' if ok else 'FALHAS'))
