import sys
import json, os, tempfile, re
# Teste de tela da v0.107: ciclo de vida dos cenários. Menu Growth Model | Cenários, lista da planilha só com cenários vivos,
# Descartar com motivo, tela Cenários (status vindo do Kanban, período ativo, decisão, aprendizado, documentação), Reabrir, link da documentação no card.
# Rodar: python3 tests/tela/t107_cenarios.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't107_growths.html')
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
  'produtos': ws([dict(id='pC', nome='Curso', preco=1000, ativo=True, extras={'mc_custo_pct': 10}), dict(id='pM', nome='Mentoria', preco=3000, ativo=True)]),
  'campanhas': ws([dict(id='c1', nome='Black', status='ativa', produto_id='pC', data_fim='2027-12-31')]),
  'gm_alavancas': ws([dict(id='a0', loop_chave='campanha:c1', produto_id=None, alavanca='tkt', mes='2026-12-01', cenario='base', valor=1200)]),
  'gm_cenarios': ws([
    dict(id='c1', nome='Preço Mentoria 4000', hipotese='Subir preço não derruba conversão', status='rascunho', versao=1, escopo={'prod': 'pM'}, financeiro={}, impacto=9, confianca=6, facilidade=7, resultados={'consolidado': {'lucro': 130400}}, baseline={'consolidado': {'lucro': 100000}}, criado_em='2026-10-01T10:00:00Z', atualizado_em='2026-10-01T10:00:00Z'),
    dict(id='c2', nome='CTR 2,5% Black', hipotese='Criativo novo dobra CTR', status='rascunho', versao=1, escopo={}, financeiro={}, impacto=8, confianca=4, facilidade=6, criado_em='2026-10-02T10:00:00Z', atualizado_em='2026-10-02T10:00:00Z'),
    dict(id='c3', nome='Simples entrega menor', hipotese='Entrega mais barata', status='aprovado', versao=1, escopo={}, financeiro={}, impacto=6, confianca=8, facilidade=6, aprovado_em='2026-09-10T10:00:00Z', criado_em='2026-09-01T10:00:00Z', atualizado_em='2026-09-10T10:00:00Z'),
    dict(id='c4', nome='Preço Mentoria 3500', hipotese='Teste de preço anterior', status='aprovado', versao=1, escopo={'prod': 'pM'}, financeiro={}, impacto=7, confianca=7, facilidade=8, aprovado_em='2026-02-20T10:00:00Z', criado_em='2026-02-01T10:00:00Z', atualizado_em='2026-02-20T10:00:00Z'),
    dict(id='c5', nome='Afiliados', hipotese='Afiliados trazem aluno', status='aprovado', versao=1, escopo={}, financeiro={}, impacto=5, confianca=5, facilidade=6, aprovado_em='2026-05-01T10:00:00Z', criado_em='2026-04-01T10:00:00Z', atualizado_em='2026-05-01T10:00:00Z'),
    dict(id='c6', nome='Upsell checkout', hipotese='Upsell sobe ticket', status='aprovado', versao=1, escopo={}, financeiro={}, impacto=6, confianca=6, facilidade=9, aprovado_em='2026-10-05T10:00:00Z', criado_em='2026-10-03T10:00:00Z', atualizado_em='2026-10-05T10:00:00Z'),
    dict(id='c7', nome='Webinar semanal', hipotese='Webinar converte lead frio', status='arquivado', versao=1, escopo={}, financeiro={}, impacto=4, confianca=4, facilidade=3, descarte={'motivo': 'sem_verba', 'obs': 'Rever em 2027', 'em': '2026-08-01T10:00:00Z'}, criado_em='2026-07-01T10:00:00Z', atualizado_em='2026-08-01T10:00:00Z')]),
  'growth_experimentos': ws([
    dict(id='e3', titulo='Simples entrega menor', hipotese='Entrega mais barata', cenario_id='c3', etapa='rodando', inicio='2026-09-20', impacto=6, confianca=8, facilidade=6, criado_em='2026-09-10T10:00:00Z', atualizado_em='2026-09-20T10:00:00Z'),
    dict(id='e4', titulo='Preço Mentoria 3500', hipotese='Teste de preço anterior', cenario_id='c4', etapa='concluido', inicio='2026-03-03', concluido_em='2026-04-14', decisao='escalar', resultado='venceu', aprendizado='Preço maior não derrubou a conversão do aluno do Curso.', link_doc='https://notion.so/mathisa/preco-mentoria', impacto=7, confianca=7, facilidade=8, criado_em='2026-02-20T10:00:00Z', atualizado_em='2026-04-14T10:00:00Z'),
    dict(id='e5', titulo='Afiliados', cenario_id='c5', etapa='arquivado', impacto=5, confianca=5, facilidade=6, criado_em='2026-05-01T10:00:00Z', atualizado_em='2026-05-20T10:00:00Z'),
    dict(id='e6', titulo='Upsell checkout', cenario_id='c6', etapa='preparacao', impacto=6, confianca=6, facilidade=9, criado_em='2026-10-05T10:00:00Z', atualizado_em='2026-10-05T10:00:00Z')]),
  'growth_metricas': [], 'auditoria': ws([dict(id=1, tabela='gm_alavancas', acao='alteracao', antes={'valor': 1000, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, depois={'valor': 1200, 'cenario': 'base', 'loop_chave': 'campanha:c1', 'alavanca': 'tkt', 'mes': '2026-12-01'}, usuario_email='rebecka@x', em='2026-10-10T10:00:00Z')]),
  'plano_contas': ws([dict(id='pF', codigo='6.2.01', nome='Ferramentas e software', tipo='despesa', cac_grupo='ferramentas'), dict(id='pP', codigo='6.2.04', nome='Pró-labore', tipo='despesa'), dict(id='pMi', codigo='6.1.01', nome='Mídia paga – Meta', tipo='despesa')]),
  'centros_custo': ws([dict(id='cA', nome='Administrativo')]), 'fornecedores': [],
  'despesas_recorrentes': ws([dict(id='r1', descricao='Pró-labore', valor=10000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pP', centro_custo_id='cA'),
                              dict(id='r2', descricao='Ferramentas', valor=500, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pF', centro_custo_id='cA'),
                              dict(id='r3', descricao='Meta Ads', valor=3000, tipo='fixa', ativo=True, data_inicio='2026-01-01', conta_despesa_id='pMi', centro_custo_id='cA')]),
  'contas_pagar': [], 'contas_receber': [], 'simulador_snapshots': [],
}
RPC = r"""window.__RPC = { gm_premissas_salvar: (a, D) => { if (!a.p_motivo) throw new Error('motivo'); a.p_linhas.forEach(l => { D.gm_alavancas = D.gm_alavancas.filter(x => !(x.cenario === 'base' && x.loop_chave === l.loop_chave && x.alavanca === l.alavanca && x.mes === l.mes)); D.gm_alavancas.push({ id: 'p' + Math.random(), workspace_id: a.p_ws, loop_chave: l.loop_chave, produto_id: l.produto_id || null, alavanca: l.alavanca, mes: l.mes, cenario: 'base', valor: l.valor }); }); return a.p_linhas.length; } };"""
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


def cel(pg, sel): return pg.evaluate("s => { const i = document.querySelector(s); return i ? i.closest('tr').innerText.replace(/\\s+/g, ' ') : null; }", sel)
def linha(pg, rot): return pg.evaluate("r => { const t = [...document.querySelectorAll('.gp-t tr')].find(x => x.cells[0] && x.cells[0].innerText.trim().startsWith(r)); return t ? t.innerText.replace(/\\s+/g, ' ').replace(/R\\$\\s/g, '') : null; }", rot)

def row(pg, cid): return pg.evaluate("c => { const r = document.querySelector('[data-cnrow=\"' + c + '\"]'); return r ? r.innerText.replace(/\\s+/g, ' ') : null; }", cid)
def rows(pg): return pg.evaluate("() => [...document.querySelectorAll('[data-cnrow]')].map(r => r.dataset.cnrow)")
def opcoes(pg): return pg.evaluate("() => [...document.querySelectorAll('#gsCen option')].map(o => o.value + '|' + o.textContent)")
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1500, 'height': 1800}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file://' + HTML); pg.wait_for_timeout(1000)
    pg.evaluate("window.hoje = () => '2026-10-11'; try{localStorage.clear()}catch(e){}")
    chk(re.search(r'Versão 0\.1\d\d', pg.inner_text('body')) is not None, 'rodapé mostra a versão')
    pg.click('#nav button[data-g=Growth]'); pg.wait_for_timeout(300)
    chk(pg.evaluate("NAV.find(g=>g.g==='Growth').items.map(i=>i[1]).join('|')") == 'Diagnóstico Growth|Growth Model|Pesquisas|Ciclo de Growth (Kanban)|Resultados e aprendizados|Guardrails', 'menu Growth com 6 itens (v0.108)', pg.evaluate("NAV.find(g=>g.g==='Growth').items.map(i=>i[1]).join('|')"))
    pg.click('#nav button[data-v=gro-modelo]'); pg.wait_for_timeout(2500)
    chk(pg.locator('[data-gm]').count() == 2 and pg.inner_text('[data-gm=gro-modelo]') == 'Planilha' and pg.locator('[data-gm=gro-cenarios]').count() == 1, 'abas do Growth Model: Planilha | Cenários (sem Unit Economics)')
    o = opcoes(pg); ids = [x.split('|')[0] for x in o]
    chk(sorted(ids) == ['c1', 'c2', 'c3', 'c6'], 'planilha lista só os vivos: em estudo, aprovado e ativo', o)
    chk(any(x.startswith('c3|') and 'ativo desde 20/09' in x for x in o) and any(x.startswith('c6|') and 'aprovado' in x for x in o), 'na lista, o status vem do Kanban (ativo desde, aprovado)', o)
    muda(pg, '#gsCen', 'c2'); pg.wait_for_timeout(800)
    chk(pg.locator('#gpDesc').count() == 1, 'cenário em estudo tem o botão Descartar')
    pg.evaluate("document.querySelector('#gpDesc').click()"); pg.wait_for_timeout(500)
    pg.check('#modalRoot input[name=motivo][value=perdeu]'); pg.select_option('#modalRoot select[name=perdeu_para]', 'c1'); pg.fill('#modalRoot textarea[name=obs]', 'Depende de criativo novo')
    submit(pg); pg.wait_for_timeout(1500)
    c2 = [c for c in D(pg, 'gm_cenarios') if c['id'] == 'c2'][0]
    chk(c2['status'] == 'arquivado' and c2['descarte']['motivo'] == 'perdeu' and c2['descarte']['perdeu_para'] == 'c1' and c2['descarte']['obs'] == 'Depende de criativo novo', 'descartar grava status e motivo (perdeu para c1, observação)', c2)
    chk('c2' not in [x.split('|')[0] for x in opcoes(pg)], 'descartado sai da lista da planilha', opcoes(pg))
    muda(pg, '#gsCen', 'c3'); pg.wait_for_timeout(800)
    chk(pg.locator('#gpDesc').count() == 0, 'cenário aprovado/ativo não tem Descartar')
    # tela Cenários
    pg.click('[data-gm=gro-cenarios]'); pg.wait_for_timeout(2000)
    chk(pg.locator('h1').first.inner_text() == 'Cenários' and len(rows(pg)) == 7, 'tela Cenários pela aba: todos os 7', rows(pg))
    r = row(pg, 'c4'); chk(r and 'Encerrado' in r and '03/03/2026 a 14/04/2026' in r and '6 semanas' in r and 'Escalar' in r and 'Venceu' in r and 'Ver aprendizado' in r and 'Documentação' in r, 'encerrado: período ativo, decisão, resultado, aprendizado e documentação', r)
    r = row(pg, 'c3'); chk(r and 'Ativo' in r and 'no ar desde 20/09/2026' in r and 'semanas' in r, 'ativo: no ar desde, com tempo', r)
    r = row(pg, 'c5'); chk(r and 'Cancelado' in r and 'nunca foi ao ar' in r, 'card arquivado antes de ir ao ar = cancelado', r)
    r = row(pg, 'c6'); chk(r and 'Aprovado' in r and 'Preparação' in r, 'aprovado: mostra a coluna do card', r)
    r = row(pg, 'c2'); chk(r and 'Descartado' in r and 'perdeu para "Preço Mentoria 4000"' in r and 'Reabrir' in r, 'descartado: motivo e para qual perdeu', r)
    r = row(pg, 'c7'); chk(r and 'Sem verba agora' in r and 'Rever em 2027' in r, 'descartado antes: motivo e observação', r)
    r = row(pg, 'c1'); chk(r and 'Em estudo' in r and '+R$ 30.400,00' in r.replace(' ', ' ') and '7,3' in r and 'Mentoria' in r, 'em estudo: lucro projetado, ICE e produto', r)
    chk(rows(pg)[0] in ('c1',) and rows(pg)[-1] == 'c5', 'ordem: em estudo primeiro, cancelados no fim', rows(pg))
    pg.click('[data-cntab=encerrado]'); pg.wait_for_timeout(800); chk(rows(pg) == ['c4'], 'aba Encerrados', rows(pg))
    pg.click('[data-cntab=todos]'); pg.wait_for_timeout(800)
    pg.fill('#cnBusca', 'mentoria'); pg.wait_for_timeout(1200); chk(sorted(rows(pg)) == ['c1', 'c4'], 'busca pelo nome', rows(pg))
    pg.fill('#cnBusca', 'criativo'); pg.wait_for_timeout(1200); chk(sorted(rows(pg)) == ['c2'], 'busca na hipótese e na observação do descarte', rows(pg))
    pg.fill('#cnBusca', ''); pg.wait_for_timeout(1200)
    pg.select_option('#cnProd', 'pM'); pg.wait_for_timeout(800); chk(sorted(rows(pg)) == ['c1', 'c4'], 'filtro por produto', rows(pg))
    pg.select_option('#cnProd', ''); pg.wait_for_timeout(800)
    # aprendizado
    pg.click('[data-cnap=c4]'); pg.wait_for_timeout(500); t = pg.inner_text('#modalRoot')
    chk('não derrubou a conversão' in t and 'notion.so/mathisa/preco-mentoria' in t and 'Venceu' in t, 'Ver aprendizado: resultado, aprendizado e link', t)
    pg.evaluate("document.querySelector('#modalRoot').innerHTML=''")
    # reabrir
    pg.click('[data-cnre=c2]'); pg.wait_for_timeout(1200)
    c2 = [c for c in D(pg, 'gm_cenarios') if c['id'] == 'c2'][0]; chk(c2['status'] == 'rascunho' and c2['descarte'] is None, 'Reabrir volta para em estudo', c2)
    chk('Em estudo' in (row(pg, 'c2') or ''), 'reaberto aparece em estudo', row(pg, 'c2'))
    # descartar pela tela Cenários
    pg.click('[data-cndes=c2]'); pg.wait_for_timeout(500); submit(pg); pg.wait_for_timeout(1500)
    c2 = [c for c in D(pg, 'gm_cenarios') if c['id'] == 'c2'][0]; chk(c2['status'] == 'arquivado' and c2['descarte']['motivo'] == 'ice_baixo', 'descartar pela tela Cenários (motivo padrão ICE baixo)', c2)
    # link da documentação no card
    pg.click('[data-cncard=e3]'); pg.wait_for_timeout(600)
    chk(pg.locator('#modalRoot [name=link_doc]').count() == 1, 'card do Kanban tem o campo Link da documentação')
    pg.fill('#modalRoot [name=link_doc]', 'notion.so/mathisa/simples'); submit(pg); pg.wait_for_timeout(1500)
    e3 = [e for e in D(pg, 'growth_experimentos') if e['id'] == 'e3'][0]; chk(e3.get('link_doc') == 'https://notion.so/mathisa/simples', 'link sem https ganha https://', e3.get('link_doc'))
    # abrir na planilha
    pg.click('[data-gm=gro-cenarios]'); pg.wait_for_timeout(1500)
    pg.click('[data-cnab=c1]'); pg.wait_for_timeout(2500)
    chk(pg.locator('#gsTopo').count() == 1 and pg.eval_on_selector('#gsCen', 'e => e.value') == 'c1', 'Abrir leva para a planilha com o cenário escolhido')
    # aba Cenários marca o Growth Model no menu
    pg.click('[data-gm=gro-cenarios]'); pg.wait_for_timeout(1800)
    chk(len(rows(pg)) == 7 and pg.evaluate("document.querySelector('#nav button.on[data-v]') && document.querySelector('#nav button.on[data-v]').dataset.v") == 'gro-modelo', 'aba Cenários: menu continua em Growth Model', rows(pg))
    # telas que saíram do menu levam para o Growth Model
    for v in ['gro-lucro', 'gro-analise']:
        pg.evaluate("v => { S.view = v; render(); }", v); pg.wait_for_timeout(1500)
        chk(pg.evaluate("S.view") == 'gro-modelo' and pg.locator('#gsTopo').count() == 1, v + ' (aposentada) abre a Planilha', pg.evaluate("S.view"))
    pg.click('[data-gm=gro-cenarios]'); pg.wait_for_timeout(1800)
    pg.screenshot(path=os.path.join(tempfile.gettempdir(), 't107_cenarios.png'), full_page=True)
    chk(not errs, 'sem erros de JavaScript', errs)
    b.close()
print('\nRESULTADO:', 'TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
sys.exit(0 if ok else 1)
