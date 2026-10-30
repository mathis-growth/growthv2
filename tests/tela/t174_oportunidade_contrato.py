import json, os, tempfile
# Teste de tela da v0.174 (E2 da integração comercial): o lead passa a ser a oportunidade e a oportunidade gera o contrato.
# Funil de leads com o botão da oportunidade; proposta = contrato em rascunho ligado à oportunidade (pode ter mais de um);
# CPF/CNPJ pedido no contrato quando falta; Ganhou abre a proposta para ativar; ganhar ou perder o lead fecha a oportunidade.
# Rodar: python3 tests/tela/t174_oportunidade_contrato.py   (FOTOS=pasta salva capturas)
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't174_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'; FOTOS = os.environ.get('FOTOS')
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'etapas_kanban': ws([dict(id='l1', quadro='leads', nome='Novo', ordem=1), dict(id='l2', quadro='leads', nome='Proposta', ordem=2),
                       dict(id='k1', quadro='oportunidades', nome='Conversa inicial', ordem=1), dict(id='k2', quadro='oportunidades', nome='Proposta enviada', ordem=2)]),
  'pessoas': ws([dict(id='p1', nome='Ana Souza', email='ana@x.com', status_funil='lead', negocio_status='aberto', etapa_kanban_id='l2', responsavel_comercial_id='e1', criado_em='2026-10-01T12:00:00Z', tags=[], extras={}),
                 dict(id='p2', nome='Bruno Lima', email='bruno@x.com', status_funil='lead', negocio_status='aberto', etapa_kanban_id='l1', criado_em='2026-10-02T12:00:00Z', tags=[], extras={}, documento='52998224725'),
                 dict(id='p3', nome='Carla Dias', email='carla@x.com', status_funil='lead', negocio_status='aberto', etapa_kanban_id='l1', criado_em='2026-10-03T12:00:00Z', tags=[], extras={})]),
  'produtos': ws([dict(id='pr1', nome='Consultoria 90 dias', tipo='servico', preco=9000, ativo=True, recorrente=False), dict(id='pr2', nome='Mensalidade', tipo='servico', preco=1500, ativo=True, recorrente=True, periodicidade='mensal')]),
  'oportunidades': ws([dict(id='o2', pessoa_id='p2', titulo='Negócio com Bruno Lima', tipo='nova_venda', status='aberta', etapa_kanban_id='k1', valor_estimado=5000, origem='crm', criado_em='2026-10-10T12:00:00Z')]),
  'contratos': ws([]), 'contrato_itens': ws([]), 'contrato_parcelas_plano': ws([]), 'contas_bancarias': ws([dict(id='cb1', nome='Conta principal', tipo='conta', ativa=True, padrao=True)]),
  'equipe': ws([dict(id='e1', nome='Rebecka', email='r@x.com', ativo=True)]), 'campanhas': ws([]), 'motivos_resultado': ws([dict(id='mg', nome='Indicação', tipo='ganho', ativo=True), dict(id='mp', nome='Preço', tipo='perdido', ativo=True)]),
  'canais': ws([]), 'campos_personalizados': ws([]), 'rpc:ativar_contrato': 3,
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def ev(pg, js, *a): return pg.evaluate(js, *a)
# o banco simulado não tem os padrões do banco de verdade: oportunidade nova nasce aberta; contrato novo nasce rascunho, com número
PADROES = "setInterval(() => { (__D.oportunidades || []).forEach(o => { if (!o.status) o.status = 'aberta'; }); let n = 0; (__D.contratos || []).forEach(c => { n++; if (!c.status) c.status = 'rascunho'; if (!c.numero) c.numero = n; }); }, 30); true;"
def fecha(pg): pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''; document.querySelector('#modalRoot2') && (document.querySelector('#modalRoot2').innerHTML = '')")
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(1200)
    pg.evaluate(PADROES)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = S.wsBase = 'w1'; S.view = 'crm-leads'; render();"); pg.wait_for_timeout(1500)
    # funil de leads: botão da oportunidade
    chk('Abrir oportunidade' in ev(pg, "document.querySelector('[data-opn=p1]').innerText"), 'lead sem oportunidade: "Abrir oportunidade"')
    chk('Oportunidade R$ 5.000,00' in ev(pg, "document.querySelector('[data-opn=p2]').innerText").replace(' ', ' '), 'lead com oportunidade aberta mostra o valor', ev(pg, "document.querySelector('[data-opn=p2]').innerText"))
    pg.click('[data-opn=p1]'); pg.wait_for_timeout(1000)
    chk(ev(pg, "document.querySelector('#modalRoot [name=tipo]').value") == 'nova_venda' and ev(pg, "document.querySelector('#modalRoot [name=titulo]').value") == 'Negócio com Ana Souza'
        and ev(pg, "document.querySelector('#modalRoot [name=pessoa_id]').value") == 'p1' and ev(pg, "document.querySelector('#modalRoot [name=responsavel_id]').value") == 'e1', 'abre a oportunidade de venda nova já com o lead e o responsável')
    pg.select_option('#modalRoot [name=produto_id]', 'pr1'); pg.fill('#modalRoot [name=valor_estimado]', '9000')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1200)
    o1 = ev(pg, "__D.oportunidades.find(o => o.pessoa_id === 'p1')")
    chk(o1 and o1['tipo'] == 'nova_venda' and o1.get('origem') == 'crm', 'oportunidade criada como venda nova vinda do CRM', o1)
    # oportunidades: proposta = contrato em rascunho
    pg.evaluate("S.view = 'crm-oport'; render();"); pg.wait_for_timeout(1400)
    pg.click(f"[data-oc=\"{o1['id']}\"]"); pg.wait_for_timeout(1300)
    chk(ev(pg, "document.querySelector('#modalRoot h2').textContent") == 'Proposta (contrato em rascunho)', 'Proposta abre o contrato em rascunho')
    chk(not ev(pg, "document.querySelector('#modalRoot [name=ativar]').checked"), 'a proposta não vem marcada para ativar')
    chk(ev(pg, "document.querySelector('#modalRoot [name=pessoa_id]').disabled") and ev(pg, "document.querySelector('#modalRoot .itp').value") == 'pr1', 'cliente fixo e produto da oportunidade')
    chk(ev(pg, "getComputedStyle(document.querySelector('#ctDoc')).display") != 'none', 'cliente sem CPF/CNPJ: o contrato pede o documento')
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(800)
    chk(not ev(pg, "__D.contratos.length") and ev(pg, "!!document.querySelector('#modalRoot form')"), 'sem CPF/CNPJ não salva')
    pg.fill('#modalRoot [name=ct_documento]', '529.982.247-24'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(800)
    chk(not ev(pg, "__D.contratos.length"), 'CPF inválido não salva')
    pg.fill('#modalRoot [name=ct_documento]', '529.982.247-25'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    c1 = ev(pg, "__D.contratos[0]")
    chk(c1 and c1.get('oportunidade_id') == o1['id'] and c1.get('pessoa_id') == 'p1', 'proposta salva ligada à oportunidade', c1)
    chk(not any(x[1] == 'ativar_contrato' for x in ev(pg, "__calls.filter(x => x[0] === 'rpc')")), 'a proposta fica em rascunho (não ativa)')
    chk(ev(pg, "__D.pessoas.find(x => x.id === 'p1').documento") == '52998224725', 'o CPF fica no cadastro do cliente')
    # segunda proposta (mensalidade) na mesma oportunidade
    pg.evaluate("S.view = 'crm-oport'; render();"); pg.wait_for_timeout(1300)
    pg.click(f"[data-oc=\"{o1['id']}\"]"); pg.wait_for_timeout(1300)
    chk(ev(pg, "getComputedStyle(document.querySelector('#ctDoc')).display") == 'none', 'cliente já com CPF: não pede de novo')
    pg.select_option('#modalRoot .itp', 'pr2'); pg.fill('#modalRoot .itv', '1500'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.contratos.filter(c => c.oportunidade_id === '" + o1['id'] + "').length") == 2, 'uma oportunidade com dois contratos (implantação e mensalidade)')
    pg.evaluate("S.view = 'crm-oport'; render();"); pg.wait_for_timeout(1300)
    t = ev(pg, f"document.querySelector('.card[data-id=\"{o1['id']}\"] .op-cts').innerText").replace(' ', ' ')
    chk('proposta · R$ 9.000,00' in t and 'proposta · R$ 1.500,00' in t, 'o cartão mostra as propostas ligadas', t)
    if FOTOS: pg.screenshot(path=FOTOS + '/t174_oportunidades.png')
    # Ganhou: abre a proposta em rascunho para ativar
    pg.click(f"[data-og=\"{o1['id']}\"]"); pg.wait_for_timeout(1500)
    chk(ev(pg, "__D.oportunidades.find(o => o.id === '" + o1['id'] + "').status") == 'ganha', 'Ganhou marca a oportunidade como ganha')
    chk(ev(pg, "document.querySelector('#modalRoot h2').textContent").startswith('Proposta · contrato') and ev(pg, "document.querySelector('#modalRoot [name=ativar]').checked"), 'Ganhou abre a proposta para ativar', ev(pg, "document.querySelector('#modalRoot h2').textContent"))
    pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    chk(any(x[1] == 'ativar_contrato' for x in ev(pg, "__calls.filter(x => x[0] === 'rpc')")), 'ativa a proposta')
    fecha(pg)
    # lead: Ganhou fecha a oportunidade aberta dele e abre o contrato ligado
    pg.evaluate("S.view = 'crm-leads'; render();"); pg.wait_for_timeout(1300)
    pg.click('[data-gn=p2]'); pg.wait_for_timeout(1000)
    pg.select_option('#modalRoot [name=motivo]', 'mg'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(2000)
    chk(ev(pg, "__D.oportunidades.find(o => o.id === 'o2').status") == 'ganha', 'Ganhou no lead fecha a oportunidade aberta dele')
    chk(ev(pg, "!!document.querySelector('#modalRoot [name=pessoa_id]')") and ev(pg, "document.querySelector('#modalRoot [name=pessoa_id]').value") == 'p2', 'e abre o contrato do lead')
    pg.evaluate("document.querySelector('#modalRoot [name=ativar]').checked = false; document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    chk(ev(pg, "(__D.contratos.find(c => c.pessoa_id === 'p2') || {}).oportunidade_id") == 'o2', 'o contrato sai ligado à oportunidade do lead')
    fecha(pg)
    # lead sem oportunidade: Ganhou cria uma oportunidade já ganha
    pg.evaluate("render();"); pg.wait_for_timeout(1200)
    pg.click('[data-gn=p3]'); pg.wait_for_timeout(1000)
    pg.select_option('#modalRoot [name=motivo]', 'mg'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(2000)
    o3 = ev(pg, "__D.oportunidades.find(o => o.pessoa_id === 'p3')")
    chk(o3 and o3['status'] == 'ganha' and o3['tipo'] == 'nova_venda' and o3['titulo'] == 'Negócio com Carla Dias', 'ganho sem oportunidade cria uma, já ganha', o3)
    fecha(pg)
    # perder: fecha a oportunidade aberta como perdida, com o motivo
    pg.evaluate("__D.oportunidades.push({ id: 'o4', workspace_id: 'w1', pessoa_id: 'p3', titulo: 'Outra', tipo: 'nova_venda', status: 'aberta', etapa_kanban_id: 'k1' }); __D.pessoas.find(x => x.id === 'p3').negocio_status = 'aberto'; render();"); pg.wait_for_timeout(1200)
    pg.click('[data-pd=p3]'); pg.wait_for_timeout(1000)
    pg.select_option('#modalRoot [name=motivo]', 'mp'); pg.evaluate("document.querySelector('#modalRoot form').requestSubmit()"); pg.wait_for_timeout(1500)
    o4 = ev(pg, "__D.oportunidades.find(o => o.id === 'o4')")
    chk(o4['status'] == 'perdida' and o4.get('motivo') == 'Preço', 'Perdeu no lead fecha a oportunidade como perdida, com o motivo', o4)
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
