import json, os, tempfile
# Teste de tela da v0.100: guardrails projetados no Growth Model, monitoramento antes/durante/depois, alertas, contínuo e resultados e aprendizados.
# Rodar: python3 tests/tela/t100_guardrails.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't100_growths.html')
s = open(SP + '../../frontend/index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
hist = []
for mes in ['2026-06-01', '2026-07-01', '2026-08-01', '2026-09-01']:
    hist.append(dict(loop='campanha:c1', nome='Black', fase='aquisicao', tipo='campanha', produto_id='pC', campanha_id='c1', mes=mes, inv=1000, imp=100000, clk=1000, vis=800, led=200, qua=0, cli=20, rec=20000, base=0))
    hist.append(dict(loop='organico:pM', nome='Orgânico Mentoria', fase='aquisicao', tipo='organico', produto_id='pM', campanha_id=None, mes=mes, inv=0, imp=0, clk=0, vis=0, led=50, qua=0, cli=5, rec=15000, base=0))
SEED = {
  'workspaces': [{'id': W, 'nome': 'Mathisa', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'rpc:growth_modelo_historico': hist,
  'produtos': ws([dict(id='pC', nome='Curso', preco=1000, ativo=True), dict(id='pM', nome='Mentoria', preco=3000, ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Black', status='ativa', produto_id='pC', data_fim='2027-12-31')]),
  'gm_alavancas': ws([dict(id='a0', loop_chave='campanha:c1', produto_id=None, alavanca='tkt', mes='2026-12-01', cenario='base', valor=1200)]),
  'gm_cenarios': ws([dict(id='cz', nome='Ticket +20%', status='aprovado', versao=1, escopo={'prod': '', 'camp': '', 'fase': '', 'tipo': '', 'de': '2026-08-01', 'n': 3}, financeiro={}, resultados={'consolidado': {'receita': 90000, 'lucro': 20000}}, baseline={'consolidado': {'receita': 75000, 'lucro': 10000}}, aprovado_em='2026-07-30T10:00:00Z', criado_em='2026-07-30')]), 'growth_metricas': [], 'auditoria': ws([dict(id=1, tabela='gm_alavancas', acao='alteracao', antes={'valor': 1000, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, depois={'valor': 1200, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, usuario_email='rebecka@x', em='2026-10-10T10:00:00Z')]),
  'plano_contas': ws([dict(id='pF', codigo='6.2.01', nome='Ferramentas e software', tipo='despesa'), dict(id='pP', codigo='6.2.04', nome='Pró-labore', tipo='despesa'), dict(id='pMi', codigo='6.1.01', nome='Mídia paga – Meta', tipo='despesa')]),
  'centros_custo': ws([dict(id='cA', nome='Administrativo')]), 'fornecedores': [],
  'despesas_recorrentes': ws([dict(id='r1', descricao='Pró-labore', valor=10000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pP', centro_custo_id='cA'),
                              dict(id='r2', descricao='Ferramentas', valor=500, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pF', centro_custo_id='cA'),
                              dict(id='r3', descricao='Meta Ads', valor=3000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pMi', centro_custo_id='cA')]),
  'contas_pagar': [], 'contas_receber': [], 'simulador_snapshots': [], 'gm_decisoes': [], 'projetos': [], 'growth_metricas': [],
  'guardrail_definicoes': ws([dict(id='g1', nome='Margem mínima', metrica='margem', operador='min', limite=80, severidade='critico', escopo='negocio', produto_id=None, janela_dias=14, frequencia='semanal', acao_sugerida='Rever custos fixos', continuo=False, ativo=True),
                              dict(id='g2', nome='CAC mídia máximo', metrica='cac_midia', operador='max', limite=300, severidade='atencao', escopo='negocio', produto_id=None, janela_dias=7, frequencia='diaria', acao_sugerida='Reduzir verba do pior conjunto', continuo=True, ativo=True)]),
  'growth_experimentos': ws([dict(id='x1', titulo='VSL nova', etapa='rodando', hipotese='VSL curta converte mais', inicio='2026-10-01', fim_previsto='2026-10-31', score=7),
                             dict(id='x2', titulo='Ticket maior', etapa='concluido', hipotese='Ticket maior aumenta o lucro', inicio='2026-08-01', concluido_em='2026-09-30', resultado='venceu', decisao='escalar', aprendizado='Cliente aceita ticket 20% maior', cenario_id='cz', score=7)]),
  'exp_guardrails': ws([dict(id='l1', experimento_id='x1', guardrail_id='g2'), dict(id='l2', experimento_id='x2', guardrail_id='g2')]),
  'guardrail_observacoes': [], 'guardrail_alertas': [],
}
RPC = r"""window.__RPC = {
  growth_metricas_auto: (a, D) => ({ receita: a.p_ini >= '2026-08-01' && a.p_fim <= '2026-10-31' ? 60000 : 30000, cac: a.p_ini >= '2026-10-01' ? 400 : 200, cpl: 20, roas: 3, vendas: 10, leads: 100, investimento: 4000, ticket: 3000, conv: 10 }), gm_premissas_salvar: (a, D) => { if (!a.p_motivo) throw new Error('motivo'); a.p_linhas.forEach(l => { D.gm_alavancas = D.gm_alavancas.filter(x => !(x.cenario === 'base' && x.loop_chave === l.loop_chave && x.alavanca === l.alavanca && x.mes === l.mes)); D.gm_alavancas.push({ id: 'p' + Math.random(), workspace_id: a.p_ws, loop_chave: l.loop_chave, produto_id: l.produto_id || null, alavanca: l.alavanca, mes: l.mes, cenario: 'base', valor: l.valor }); }); return a.p_linhas.length; } };"""
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';' + RPC + '</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def tx(pg, sel='#main'): return pg.inner_text(sel).replace('\n', ' / ').replace(' ', ' ').replace('R$ ', '')
def submit(pg): pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1000)
def D(pg, t): return pg.evaluate("t=>window.__D[t]", t)
def muda(pg, sel, v): pg.evaluate("([s, v]) => { const i = document.querySelector(s); i.value = v; i.dispatchEvent(new Event('change', { bubbles: true })); }", [sel, v]); pg.wait_for_timeout(1200)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1600, 'height': 3200}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk('Versão 0.' in pg.inner_text('body'), 'rodapé mostra a versão 0.100')
    chk(pg.evaluate("NAV.find(g=>g.g==='Growth').items.map(i=>i[0]).join(',')").endswith('gro-ciclo,gro-result,gro-guard'), 'menu Growth com Guardrails e Resultados')
    # ---------- projeção no Growth Model ----------
    pg.evaluate("S.ws='w1'; S.view='gro-modelo'; S.gTab='loop'; S.gl=null; render()"); pg.wait_for_timeout(2200)
    pg.click('#glCenNovo'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=nome]', 'Mais mídia'); pg.fill('#modalRoot [name=hipotese]', 'mais verba'); submit(pg); pg.wait_for_timeout(1800)
    pg.evaluate("S.gl.cenId = window.__D.gm_cenarios.find(c=>c.nome==='Mais mídia').id; S.gl.vista='sim'; render()"); pg.wait_for_timeout(2000)
    t = tx(pg)
    chk('Guardrails projetados' in t and 'Margem mínima' in t and 'CAC mídia máximo' in t and 'não é alerta' in t.lower() or 'Não é alerta' in t, 'painel de guardrails projetados no cenário', t[:3500])
    chk('fora do limite' in t, 'margem mínima de 80% aparece fora do limite na projeção', t[:3500])
    # aprovar com crítico violado pede justificativa
    pg.click('#glIce'); pg.wait_for_timeout(400); pg.fill('#modalRoot [name=impacto]', '7'); pg.fill('#modalRoot [name=confianca]', '7'); pg.fill('#modalRoot [name=facilidade]', '7'); submit(pg); pg.wait_for_timeout(600)
    pg.evaluate("render()"); pg.wait_for_timeout(2000)
    pg.click('#glAprova'); pg.wait_for_timeout(700)
    chk(pg.locator('#modalRoot [name=risco]').count() == 1 and 'crítico' in pg.inner_text('#modalRoot'), 'aprovação com guardrail crítico violado pede a justificativa do risco')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    pg.evaluate("S.gl.vista='cmp'; glDesenha(document.querySelector('#main'))"); pg.wait_for_timeout(1200)
    chk('Guardrails projetados (negócio)' in tx(pg), 'comparador mostra os guardrails de cada cenário')
    # ---------- monitoramento ----------
    pg.evaluate("S.view='gro-guard'; S.grTab='monit'; render()"); pg.wait_for_timeout(2500)
    t = tx(pg)
    chk('VSL nova' in t and 'ANTES' in t.upper() and 'DURANTE' in t.upper() and 'não pausa campanhas sozinho' in t, 'monitoramento antes/durante com aviso de que nada é pausado', t[:2500])
    chk('400,00' in t and '200,00' in t and 'fora do limite' in t, 'CAC antes 200 e durante 400 (limite 300)', t[:2500])
    obs = D(pg, 'guardrail_observacoes'); al = D(pg, 'guardrail_alertas')
    chk(any(o['periodo'] == 'durante' and o['situacao'] == 'violado' and o['experimento_id'] == 'x1' for o in obs) and any(o['periodo'] == 'antes' for o in obs), 'observações gravadas (antes e durante)', obs)
    chk(len([a for a in al if a['experimento_id'] == 'x1']) == 1 and al[0]['acao_sugerida'] == 'Reduzir verba do pior conjunto', 'alerta criado com a ação sugerida', al)
    chk(any(o['periodo'] == 'depois' and o['experimento_id'] == 'x2' for o in obs) and not any(a['experimento_id'] == 'x2' for a in al), 'teste concluído: lê o depois e não gera alerta')
    pg.evaluate("render()"); pg.wait_for_timeout(2500)
    chk(len([a for a in D(pg, 'guardrail_alertas') if a['experimento_id'] == 'x1']) == 1 and len([o for o in D(pg, 'guardrail_observacoes') if o['experimento_id'] == 'x1' and o['periodo'] == 'durante']) == 1, 'abrir de novo não duplica alerta nem observação do dia')
    # ---------- alertas ----------
    pg.click('[data-grt=alertas]'); pg.wait_for_timeout(1200)
    t = tx(pg); chk('VSL curta converte mais' in t and 'aberto' in t, 'alerta mostra o teste e a hipótese', t[:1500])
    aid = [a for a in D(pg, 'guardrail_alertas') if a['experimento_id'] == 'x1'][0]['id']
    pg.click('[data-grrec="%s"]' % aid); pg.wait_for_timeout(400); pg.fill('#modalRoot [name=r]', 'Ana'); submit(pg); pg.wait_for_timeout(800)
    pg.click('[data-grres="%s"]' % aid); pg.wait_for_timeout(400); pg.fill('#modalRoot [name=n]', 'Verba reduzida no conjunto 3'); submit(pg); pg.wait_for_timeout(800)
    a = [a for a in D(pg, 'guardrail_alertas') if a['id'] == aid][0]
    chk(a['status'] == 'resolvido' and a['responsavel'] == 'Ana' and a['nota'] == 'Verba reduzida no conjunto 3', 'reconhecer e resolver com nota', a)
    # ---------- contínuo ----------
    pg.click('[data-grt=continuo]'); pg.wait_for_timeout(1500)
    t = tx(pg); chk('CAC mídia máximo' in t and 'fora do limite' in t, 'acompanhamento contínuo lê o guardrail contínuo', t[:1500])
    chk(any(a['experimento_id'] is None for a in D(pg, 'guardrail_alertas')), 'alerta do acompanhamento contínuo')
    # ---------- cadastro ----------
    pg.click('[data-grt=cadastro]'); pg.wait_for_timeout(1000)
    chk('só projeção' in tx(pg), 'margem marcada como só projeção')
    pg.click('#grNovo'); pg.wait_for_timeout(500); pg.fill('#modalRoot [name=nome]', 'ROAS mínimo'); pg.select_option('#modalRoot [name=metrica]', 'roas'); pg.fill('#modalRoot [name=limite]', '2'); submit(pg)
    chk(any(g['nome'] == 'ROAS mínimo' for g in D(pg, 'guardrail_definicoes')), 'novo guardrail cadastrado')
    # ---------- resultados ----------
    pg.evaluate("S.view='gro-result'; render()"); pg.wait_for_timeout(2000)
    t = tx(pg)
    # cenário ago–out (3 meses), hoje 11/10: 3 de 3 meses passados → projeção 90.000, baseline 75.000, realizado 60.000
    chk('Ticket maior' in t and 'Escalar' in t and 'Cliente aceita ticket 20% maior' in t, 'resultado com decisão e aprendizado', t[:2000])
    chk('90.000,00' in t and '75.000,00' in t and '60.000,00' in t and '67% da projeção' in t, 'projeção × baseline × realizado', t[:2500])
    errs = [x for x in errs if 'funil' not in x]
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
