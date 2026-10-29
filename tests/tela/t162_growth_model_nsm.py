import json, os, tempfile
# Teste de tela da v0.162: no Mapa de métricas e North Star, a NSM aparece em destaque (★, valor grande, frequência)
# e as filhas dela ficam em "Alavancas que movem a NSM", cada uma com o papel (Driver/Input) e a variação ao lado do valor.
# Rodar: python3 tests/tela/t162_growth_model_nsm.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't162_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
W = 'w1'
def ws(rows): return [dict(workspace_id=W, **r) for r in rows]
SEED = {
  'workspaces': [{'id': W, 'nome': 'Growths', 'modo_produto': 'completo', 'agencia': True}], 'rpc:sou_equipe_interna': True,
  'rpc:growth_metricas_auto': {}, 'benchmarks_mercado': [], 'produtos': [],
  'growth_metricas': ws([
    dict(id='n', nome='Clientes com receita nova sem mais tráfego', tipo='north_star', fonte='manual', unidade='numero', direcao='sobe', meta=20, valor_manual=14, valor_manual_anterior=11, ordem=0,
         nsm_evento='simulação que aumentou o faturamento sem mais tráfego', nsm_populacao='clientes ativos', nsm_frequencia='mensal', criado_em='2026-10-01T10:00:00Z'),
    dict(id='a1', pai_id='n', nome='Simulações no Growth Model', tipo='driver', fonte='manual', unidade='numero', direcao='sobe', meta=5, valor_manual=3.4, valor_manual_anterior=2.9, ordem=1, criado_em='2026-10-01T10:01:00Z'),
    dict(id='a3', pai_id='n', nome='Rotinas de growth executadas', tipo='driver', fonte='manual', unidade='numero', direcao='sobe', meta=3, valor_manual=1.2, valor_manual_anterior=1.4, ordem=2, criado_em='2026-10-01T10:03:00Z'),
    dict(id='i1', pai_id='a1', nome='Abriram o simulador na 1ª semana', tipo='input', fonte='manual', unidade='pct', direcao='sobe', meta=80, valor_manual=62, valor_manual_anterior=58, ordem=3, criado_em='2026-10-01T10:04:00Z')]),
  'growth_experimentos': [],
}
MOCK = open(SP + 'mockdb.js').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True; falhas = []
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:700]) if (extra != '' and not c) else '')); ok = ok and bool(c)
    if not c: falhas.append(msg)
def no(pg, mid): return pg.evaluate("id => { const b = document.querySelector('.gtree [data-ed=\"' + id + '\"]'); return b ? b.closest('.gn').innerText.replace(/\\s+/g, ' ') : null; }", mid)
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(viewport={'width': 1400, 'height': 1000}); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace('\\', '/')); pg.wait_for_timeout(1200)
    pg.evaluate("window.provisionaAuto = async () => {}; S.ws = 'w1'; S.view = 'gro-modelo'; S.gTab = 'mapa'; render();"); pg.wait_for_timeout(1500)
    t = no(pg, 'n')
    chk(t and t.startswith('★ Clientes com receita nova sem mais tráfego'), 'NSM com estrela no nome', t)
    chk(t and 'North Star' in t and 'mensal' in t and 'Driver' not in t, 'NSM com a etiqueta North Star e a frequência, sem papel de alavanca', t)
    chk(pg.evaluate("parseFloat(getComputedStyle(document.querySelector('.gtree .gn.ns .gn-v')).fontSize)") >= 36, 'valor da NSM em destaque (36px ou mais)')
    chk(t and 'Conta: simulação que aumentou o faturamento sem mais tráfego · entre clientes ativos' in t, 'evento e população da NSM continuam na linha Conta', t)
    chk(pg.evaluate("[...document.querySelectorAll('.gtree .gn.ns [data-fi]')].map(b => b.textContent).join()") == '+ Alavanca', 'na NSM o botão de filha vira "+ Alavanca"')
    chk(pg.evaluate("(() => { const l = document.querySelector('.gtree .gn-lab'); return l && l.textContent === 'Alavancas que movem a NSM' && l.nextElementSibling.matches('ul.alav'); })()"), 'título "Alavancas que movem a NSM" logo acima das filhas da NSM')
    chk(pg.evaluate("document.querySelectorAll('.gtree ul.alav > li').length") == 2 and pg.evaluate("document.querySelectorAll('.gtree .gn-lab').length") == 1, 'só as filhas diretas da NSM entram no grupo de alavancas')
    a1 = no(pg, 'a1')
    chk(a1 and 'Driver (alavanca)' in a1 and '+ Métrica filha' in a1, 'alavanca mostra o papel Driver (alavanca) e mantém + Métrica filha', a1)
    chk(pg.evaluate("(() => { const r = document.querySelector('.gtree [data-ed=a1]').closest('.gn').querySelector('.gn-vr'); return r && r.innerText.replace(/\\s+/g, ' ').startsWith('3,4 ▲ 17,2% vs. período anterior'); })()"), 'valor e variação da alavanca na mesma linha')
    i1 = no(pg, 'i1')
    chk(i1 and 'Input' in i1, 'input dentro da alavanca mostra o papel Input', i1)
    chk(pg.evaluate("!document.querySelector('.gtree [data-ed=i1]').closest('ul').matches('.alav')"), 'neta da NSM fica fora do grupo de alavancas')
    a3 = no(pg, 'a3')
    chk(a3 and 'Gargalo sugerido' in a3 and pg.evaluate("document.querySelector('.gtree [data-ed=a3]').closest('.gn').classList.contains('gar')"), 'gargalo sugerido continua marcado na alavanca', a3)
    pg.click('.gtree .gn.ns [data-fi]'); pg.wait_for_timeout(700)
    chk(pg.evaluate("(() => { const s = document.querySelector('#modalRoot select[name=pai_id]'); return s && s.value === 'n'; })()"), '+ Alavanca abre Nova métrica já abaixo da NSM')
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'FALHAS: ' + '; '.join(falhas))
