import json, os, tempfile
# Teste de tela da v0.173 (E1 da integração comercial): CPF ou CNPJ no cadastro da pessoa (validado, formatado, buscável) e a linha do
# tempo única na ficha (cadastro, marketing, comercial, financeiro e jornada, com filtro por tipo).
# Rodar: python3 tests/tela/t173_pessoa_documento_linha_tempo.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't173_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'pessoas': ws([dict(id='p1', nome='Ana Souza', email='ana@x.com', telefone='35999990000', documento='52998224725', status_funil='cliente', status_cliente='ativo', negocio_status='ganho',
                      negocio_fechado_em='2026-09-10T12:00:00Z', criado_em='2026-08-01T12:00:00Z', canal_origem='instagram', tags=[], extras={}),
                 dict(id='p2', nome='Bruno Lima', email='bruno@x.com', status_funil='lead', negocio_status='aberto', criado_em='2026-10-01T12:00:00Z', tags=[], extras={})]),
  'produtos': ws([dict(id='pr1', nome='Consultoria', ativo=True), dict(id='pr2', nome='Mentoria', ativo=True)]),
  'plataformas_venda': ws([dict(id='pl1', nome='Hotmart')]),
  'vendas': ws([dict(id='v1', pessoa_id='p1', produto_id='pr2', plataforma_id='pl1', plataformas_venda={'nome': 'Hotmart'}, produtos={'nome': 'Mentoria'}, data_venda='2026-09-20T12:00:00Z', valor_bruto=997, status='aprovada', forma_pagamento='pix')]),
  'contratos': ws([dict(id='c1', pessoa_id='p1', numero=7, status='ativo', criado_em='2026-09-05T12:00:00Z', ativado_em='2026-09-12T12:00:00Z', num_parcelas=3, recorrente=False,
                        contrato_itens=[{'quantidade': 1, 'valor': 9000, 'produtos': {'nome': 'Consultoria'}}])]),
  'contas_receber': ws([dict(id='r1', contrato_id='c1', valor=3000, parcela=1, status='recebido', data_recebimento='2026-09-15'),
                        dict(id='r2', contrato_id='c1', valor=3000, parcela=2, status='previsto', vencimento='2026-10-15'),
                        dict(id='r3', venda_id='v1', valor=950, status='recebido', data_recebimento='2026-09-20')]),
  'alunos': ws([dict(id='a1', pessoa_id='p1', produto_id='pr1', produtos={'nome': 'Consultoria'}, status='ativo', entrou_em='2026-09-12T12:00:00Z')]),
  'aluno_historico': ws([dict(id='h1', aluno_id='a1', pessoa_id='p1', tipo='etapa', em='2026-09-20T12:00:00Z', etapa_kanban_id='ek1')]),
  'aluno_marcos': ws([dict(id='m1', aluno_id='a1', marco_id='jm1', situacao='atingido', em='2026-09-25T12:00:00Z')]),
  'oportunidades': ws([dict(id='o1', pessoa_id='p1', titulo='Consultoria 90 dias', tipo='nova_venda', status='ganha', valor_estimado=9000, criado_em='2026-08-20T12:00:00Z', fechado_em='2026-09-05T12:00:00Z')]),
  'pesquisa_respostas': ws([dict(id='q1', pessoa_id='p1', pesquisa_id='ps1', respondida_em='2026-09-18T12:00:00Z')]),
  'cs_intervencoes': ws([dict(id='i1', pessoa_id='p1', tipo='ligacao', descricao='Ligação de boas-vindas', status='concluida', resultado='resolveu', criado_em='2026-09-13T12:00:00Z', concluida_em='2026-09-14T12:00:00Z')]),
  'pessoa_toques': ws([dict(id='t1', pessoa_id='p1', em='2026-08-01T12:00:00Z', tipo='captura', canal='instagram', descricao='Captura no formulário')]),
  'pessoa_notas': ws([dict(id='n1', pessoa_id='p1', texto='Quer começar em setembro', criado_em='2026-08-22T12:00:00Z')]),
  'estornos': ws([]), 'pessoa_historico': ws([]), 'pessoa_funil': ws([]), 'pessoa_funil_historico': ws([]), 'presencas_video': ws([]), 'projetos': ws([]),
  'equipe': ws([dict(id='e1', nome='Rebecka', ativo=True)]), 'responsavel_historico': ws([]), 'pagamentos_historicos': ws([]),
  'canais': ws([]), 'etapas_kanban': ws([dict(id='ek1', nome='Diagnóstico', quadro='alunos', ordem=1)]), 'jornada_marcos': ws([dict(id='jm1', nome='Diagnóstico entregue')]), 'pesquisas': ws([dict(id='ps1', nome='Diagnóstico inicial')]), 'campanhas': ws([]), 'campos_personalizados': ws([]),
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1300, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'cockpit'; render();"); pg.wait_for_timeout(800)
    # validação no navegador (mesma regra do banco)
    chk(ev(pg, "[docValido('529.982.247-25'), docValido('11.222.333/0001-81'), docValido('529.982.247-24'), docValido('111.111.111-11'), docValido('123')]") == [True, True, False, False, False], 'valida CPF e CNPJ como o banco')
    chk(ev(pg, "[docFmt('52998224725'), docFmt('11222333000181'), docTipo('11222333000181')]") == ['529.982.247-25', '11.222.333/0001-81', 'CNPJ'], 'formata CPF e CNPJ')
    # ficha
    pg.evaluate("fichaPessoa('p1')"); pg.wait_for_timeout(1800)
    t = ev(pg, "document.querySelector('#modalRoot').innerText.replace(/\\s+/g, ' ')")
    chk('CPF 529.982.247-25' in t, 'a ficha mostra o CPF formatado', t[:600])
    tl = ev(pg, "[...document.querySelectorAll('.tlu [data-tlc]')].map(x => x.dataset.tlc + '|' + x.innerText.replace(/\\s+/g, ' '))")
    txt = ' || '.join(tl)
    for frag in ['Cadastro como lead', 'Captura no formulário', 'Oportunidade aberta: Consultoria 90 dias', 'Oportunidade ganha', 'Contrato #7 criado (Consultoria)', 'Contrato #7 ativado · 3 parcela(s)',
                 'Recebido R$ 3.000,00 do contrato #7 · parcela 1', 'Venda de R$ 997,00 (Mentoria, pix, Hotmart)', 'Recebido R$ 950,00 da venda', 'Matrícula em Consultoria', 'Jornada Consultoria: etapa Diagnóstico',
                 'Marco atingido: Diagnóstico entregue', 'Respondeu a pesquisa Diagnóstico inicial', 'Intervenção do CS: Ligação de boas-vindas', 'Nota: Quer começar em setembro']:
        chk(frag in txt.replace(' ', ' '), 'linha do tempo tem: ' + frag, txt[:900])
    chk('R$ 3.000,00 do contrato #7 · parcela 2' not in txt.replace(' ', ' '), 'parcela ainda prevista não aparece como recebida')
    datas = ev(pg, "[...document.querySelectorAll('.tlu [data-tlc] span')].map(x => x.textContent)")
    chk(len(datas) >= 15 and datas[0].startswith('25/09/2026'), 'a mais recente vem primeiro', datas[:3])
    chk('20/09/2026' in datas and not any(d.startswith('19/09/2026, 21:00') for d in datas), 'data sem hora não muda de dia pelo fuso', datas)
    chk(ev(pg, "[...document.querySelectorAll('[data-tlf]')].map(x => x.innerText.split(' ')[0])") == ['Tudo', 'Cadastro', 'Marketing', 'Comercial', 'Financeiro', 'Jornada'], 'filtros por tipo')
    pg.click('[data-tlf=fin]'); pg.wait_for_timeout(200)
    vis = ev(pg, "[...document.querySelectorAll('.tlu [data-tlc]')].filter(x => x.style.display !== 'none').map(x => x.dataset.tlc)")
    chk(vis and all(c == 'fin' for c in vis) and len(vis) == 5, 'filtro Financeiro mostra só venda, contrato e recebimentos', vis)
    if FOTOS: pg.screenshot(path=FOTOS + '/t173_ficha.png', full_page=True)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # cadastro: campo CPF/CNPJ, inválido recusado, válido salvo só com dígitos
    pg.evaluate("modalCliente(__D.pessoas.find(x => x.id === 'p2'))"); pg.wait_for_timeout(1200)
    chk(ev(pg, "!!document.querySelector('#modalRoot [name=documento]')"), 'o cadastro tem o campo CPF ou CNPJ')
    pg.fill('#modalRoot [name=documento]', '11.222.333/0001-80'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(800)
    chk(ev(pg, "!!document.querySelector('#modalRoot form')") and not ev(pg, "__D.pessoas.find(x => x.id === 'p2').documento"), 'CNPJ inválido: não salva e a janela continua')
    pg.fill('#modalRoot [name=documento]', '11.222.333/0001-81'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1200)
    chk(ev(pg, "__D.pessoas.find(x => x.id === 'p2').documento") == '11222333000181', 'CNPJ válido salvo só com os dígitos')
    pg.evaluate("modalCliente(__D.pessoas.find(x => x.id === 'p1'))"); pg.wait_for_timeout(1000)
    chk(ev(pg, "document.querySelector('#modalRoot [name=documento]').value") == '529.982.247-25', 'ao editar, o CPF aparece formatado')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # busca por CPF/CNPJ na lista
    pg.evaluate("S.view = 'cad-clientes'; S.f = { busca: '11.222.333', qual: '', tipo: '' }; render();"); pg.wait_for_timeout(1500)
    nomes = ev(pg, "[...document.querySelectorAll('#main tbody tr')].map(r => r.innerText)")
    chk(any('Bruno Lima' in x for x in nomes) and not any('Ana Souza' in x for x in nomes), 'a lista acha a pessoa pelo CNPJ', nomes[:3])
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
