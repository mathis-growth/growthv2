"""v0.123: (1) gráfico de linha no painel da árvore, no período da tela, com Dia/Semana/Mês/Ano (substitui o da v0.122);
(2) na nova campanha dá para cadastrar ali mesmo: estratégia (com as etapas), produto e canal. Banco fa + 20261024100000_arvore_serie.sql."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr)
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql(f"""delete from campanha_canais where campanha_id in (select id from campanhas where workspace_id = '{WS}' and nome like 'T123 %');
      delete from estrategia_etapas where funil_id in (select id from funis where workspace_id = '{WS}' and nome like 'T123 %');
      delete from projetos where campanha_id in (select id from campanhas where workspace_id = '{WS}' and nome like 'T123 %');
      delete from campanhas where workspace_id = '{WS}' and nome like 'T123 %';
      delete from funis where workspace_id = '{WS}' and nome like 'T123 %';
      delete from produtos where workspace_id = '{WS}' and nome like 'T123 %';
      delete from canais where workspace_id = '{WS}' and nome like 'T123 %';""")
limpa()
with sync_playwright() as p:
    b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
    erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
    def abre(rot, ms=4500):
        i = pg.evaluate("r => [...document.querySelectorAll('.kpi.arvk')].findIndex(k => (k.querySelector('.l').innerText || '').replace(/[\\sⓘ⚠›]+$/u, '').trim() === r)", rot)
        pg.locator('.kpi.arvk').nth(i).click(); pg.wait_for_timeout(ms)
    # ---------------- gráfico de linha ----------------
    front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 5500)
    abre('Receita bruta das vendas')
    chk(pg.locator('#arvRoot .arv-g polyline').count() >= 1 and pg.locator('#arvRoot .arv-g path, #arvRoot .arv-g rect[rx]').count() == 0, 'Receita: gráfico de linha (sem rosca nem barras)')
    chk('16/09/2026 a 15/10/2026' in pg.inner_text('#arvRoot .arv-g h3'), 'a linha usa o período da tela (últimos 30 dias)')
    n = pg.locator('#arvRoot .arv-pt').count(); chk(pg.locator('#arvRoot [data-gran=dia].on').count() == 1 and 2 <= n <= 30, '30 dias → agrupado por dia (%d pontos; começa no primeiro dia com valor)' % n)
    pg.click('#arvRoot [data-gran=semana]'); pg.wait_for_timeout(2500)
    n = pg.locator('#arvRoot .arv-pt').count()
    chk(pg.locator('#arvRoot [data-gran=semana].on').count() == 1 and 5 <= n <= 6, 'trocar para Semana redesenha (%d pontos)' % n)
    soma = pg.evaluate("() => ARV.pilha[0].series.semana.reduce((s, p) => s + Number(p.valor || 0), 0)")
    chk(abs(soma - pg.evaluate("() => ARV.pilha[0].dados.valor")) < 0.01, 'a soma das semanas bate com o número do cartão')
    pg.locator('#arvRoot .arv-pt').nth(2).click(force=True); pg.wait_for_timeout(3500)
    t = pg.evaluate("() => ARV.pilha[1] && ARV.pilha[1].par")
    chk(t and t.get('ini') and (t['fim'] > t['ini']) and pg.locator('#arvRoot [data-gran=dia].on').count() == 1, 'clicar num ponto abre aquela semana, já por dia')
    pg.evaluate("() => arvFecha()")
    front.vai(pg, 'adm-painel', "S.pg = { per: 'ano' }", 5500)
    abre('Lucro'); chk(pg.locator('#arvRoot [data-gran=mes].on').count() == 1, 'ano atual → agrupado por mês'); pg.evaluate("() => arvFecha()")
    abre('MRR', 5000)
    chk('fim de cada' in pg.inner_text('#arvRoot .arv-g h3'), 'número "na data" (MRR): valor no fim de cada mês'); pg.evaluate("() => arvFecha()")
    # ---------------- nova campanha: cadastrar ali mesmo ----------------
    front.vai(pg, 'mkt-camp', "S.tabMkt = 'campanhas'; S.campSel = null", 3500)
    pg.click('#novaCamp'); pg.wait_for_timeout(1500)
    chk(pg.locator('#modalRoot [name=produto_id] option[value=__novo__]').count() == 1 and pg.locator('#modalRoot [name=funil_id] option[value=__nova_est__]').count() == 1, 'produto e estratégia com a opção de cadastrar novo')
    pg.select_option('#modalRoot [name=produto_id]', '__novo__'); pg.wait_for_timeout(1200)
    chk(pg.locator('#modalRoot2 .modal').count() == 1, 'cadastro de produto abre por cima da nova campanha')
    pg.fill('#modalRoot2 [name=nome]', 'T123 Produto'); pg.fill('#modalRoot2 [name=preco]', '497')
    if pg.locator('#modalRoot2 [name=tag]').count(): pg.fill('#modalRoot2 [name=tag]', 't123')
    pg.click('#modalRoot2 .pri'); pg.wait_for_timeout(2500)
    pid = sql(f"select id from produtos where workspace_id = '{WS}' and nome = 'T123 Produto'")
    chk(bool(pid) and pg.input_value('#modalRoot [name=produto_id]') == pid, 'produto criado e já escolhido na campanha')
    pg.select_option('#modalRoot [name=funil_id]', '__nova_est__'); pg.wait_for_timeout(1200)
    chk(pg.locator('#modalRoot2 .est-pick').count() == 1 and pg.locator('#modalRoot .wz').count() == 1, 'nova estratégia abre por cima, com a escolha das etapas')
    pg.fill('#modalRoot2 [name=nome]', 'T123 Estratégia'); pg.select_option('#modalRoot2 [name=modelo]', 'perpetuo'); pg.wait_for_timeout(300)
    chk(pg.locator('#modalRoot2 [data-etc]:checked').count() == 9, 'modelo pronto marca as etapas dele')
    pg.click('#modalRoot2 [data-etc=vsl]'); pg.fill('#modalRoot2 [data-etx=conversao]', 'Chamada no WhatsApp, Proposta enviada'); pg.dispatch_event('#modalRoot2 [data-etx=conversao]', 'input')
    pg.click('#modalRoot2 .pri'); pg.wait_for_timeout(3000)
    fid = sql(f"select id from funis where workspace_id = '{WS}' and nome = 'T123 Estratégia'")
    et = sql(f"select string_agg(nome, '|' order by ordem) from estrategia_etapas where funil_id = '{fid}'") if fid else ''
    chk(et == 'Investimento|Impressões|Cliques|Visitas à página|Leads|Abriu o checkout|Comprou|Receita|Chamada no WhatsApp|Proposta enviada', 'estratégia gravada com as etapas escolhidas (sem a VSL, com as 2 novas): ' + et)
    chk(pg.input_value('#modalRoot [name=funil_id]') == fid and pg.locator('#modalRoot2 .modal').count() == 0, 'estratégia criada e já escolhida, a nova campanha continua aberta')
    pg.wait_for_timeout(800)
    chk('Etapas que a campanha vai receber (10)' in pg.inner_text('#wzEt'), 'a nova campanha mostra as etapas que vai receber')
    pg.fill('#modalRoot [name=nome]', 'T123 Campanha'); pg.fill('#modalRoot [name=data_inicio]', '2026-11-01'); pg.fill('#modalRoot [name=data_fim]', '2026-11-30')
    pg.click('#modalRoot .wzf .pri'); pg.wait_for_timeout(2500)
    pg.fill('#modalRoot [name=orcamento_total]', '10000'); pg.fill('#modalRoot [name=meta_leads]', '1000'); pg.click('#modalRoot .wzf .pri'); pg.wait_for_timeout(2500)
    pg.click('#wzNovoCanal'); pg.wait_for_timeout(1000)
    pg.fill('#modalRoot2 [name=nome]', 'T123 Canal Pinterest'); pg.fill('#modalRoot2 [name=codigo]', 'pinterest_ads'); pg.click('#modalRoot2 .pri'); pg.wait_for_timeout(2500)
    chk(pg.locator('#modalRoot [data-cn=pinterest_ads].on').count() == 1, 'canal novo criado ali e já marcado na campanha')
    pg.click('#modalRoot .wzf .pri'); pg.wait_for_timeout(4000)
    cid = sql(f"select id from campanhas where workspace_id = '{WS}' and nome = 'T123 Campanha'")
    chk(sql(f"select funil_id || '|' || produto_id from campanhas where id = '{cid}'") == f'{fid}|{pid}', 'campanha gravada com a estratégia e o produto novos')
    chk(sql(f"select count(*) from campanha_canais where campanha_id = '{cid}' and canal = 'pinterest_ads'") == '1', 'campanha gravada com o canal novo')
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
