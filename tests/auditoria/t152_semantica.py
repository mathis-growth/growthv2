"""v0.152: camada semântica (Data Storytelling) e piloto no Dashboard.
Banco fa (Escola Aurora, setembro/2026). Não grava nada: cenário de margem e saldo mínimo entram pelo navegador."""
import sys, json; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots152/'
import os; os.makedirs(SHOT, exist_ok=True)

import subprocess as _sp
def _q(x):
    return _sp.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-c', x], capture_output=True, text=True).stdout.strip()
def _num(v, c): return ('%.' + str(c) + 'f') % abs(v)
def _br(v, c): s = _num(v, c); i, d = (s.split('.') + [''])[:2]; i = '{:,}'.format(int(i)).replace(',', '.'); return i + (',' + d if d else '')
def MIL(v): return ('−' if v < 0 else '') + 'R$ ' + _br(v / 1000, 1) + ' mil'
def PCT(v): return ('−' if v < 0 else '') + _br(v * 100, 1) + '%'
_W = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def _vendas(m): return float(_q(f"select coalesce(sum(valor_bruto),0) from vendas where workspace_id='{_W}' and status='aprovada' and to_char(data_venda at time zone 'America/Sao_Paulo','YYYY-MM')='{m}'") or 0)
def _dre(m, receita=False): return float(_q(f"select coalesce(sum(case when tipo='receita' then valor else {'0' if receita else '-valor'} end),0) from v_dre_mensal where workspace_id='{_W}' and mes='{m}-01'") or 0)
VA, VS = _vendas('2026-08'), _vendas('2026-09'); LA, LS = _dre('2026-08'), _dre('2026-09'); RA, RS = _dre('2026-08', True), _dre('2026-09', True)
DV = '+' + _br((VS / VA - 1) * 100, 1) + '%'; DR = '+' + _br((RS / RA - 1) * 100, 1) + '%'; DL = MIL(LS - LA)
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
SET = "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }"
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    # ---- funções puras ----
    r = pg.evaluate("""() => ({
      f1: semFmt(-106388, 'brl'), f2: semFmt(4.5, 'x'), f3: semFmt(null, 'brl'), f4: semFmt(3.2, 'razao'), f5: semFmt(0.0342, 'pct', { casas: 2 }), f6: semBRL(1250000), f7: semBRL(6052.47, 'mil'), f8: semFmt(0, 'brl'),
      v1: semVar(-96993.27, -28286.12, 'lucro', 'ago/26'), v2: semVar(670, 1125, 'cac', 'x'), v3: semVar(0.0250, 0.0251, 'ctr', 'x'), v4: semVar(32871, 12375, 'investimento', 'x'), v5: semVar(-1.277, -1.766, 'margem', 'x'), v6: semVar(46953, 10017, 'receita', 'x'),
      s1: semStatus(-1, 'saldo'), s2: semStatus(100, 'saldo'), s3: semStatus(5, 'margem', { v: 20, rot: 'cenário Ruim (20%)' }), s4: semStatus(25, 'margem', { v: 20, rot: 'r' }), s5: semStatus(500, 'cac'), s6: semStatus(800, 'cac', { v: 700, rot: 'meta' }),
      p1: semPerAnt('2026-09-01', '2026-09-30'), p2: semPerAnt('2026-09-05', '2026-09-30'), p3: semPerAnt('2026-07-01', '2026-09-30') })""")
    chk(r['f1'] == '−R$ 106.388,00' and r['f2'] == '4,5x' and r['f3'] == '—' and r['f4'] == '3,2:1' and r['f5'] == '3,42%' and r['f6'] == 'R$ 1,25 mi' and r['f7'] == 'R$ 6,1 mil' and r['f8'] == 'R$ 0,00', 'formatador único: menos verdadeiro, x, razão, "—" para sem dado, mil e mi ' + json.dumps({k: v for k, v in r.items() if k[0] == 'f'}, ensure_ascii=False))
    chk(r['v1']['cls'] == 'desf' and '−R$ 68,7 mil' in r['v1']['html'] and '%' not in r['v1']['html'], 'lucro negativo: variação em reais, nunca % sobre base negativa')
    chk(r['v2']['cls'] == 'fav' and r['v3']['cls'] == 'neu' and r['v4']['cls'] == 'neu', 'CAC caindo = favorável; CTR quase igual = neutro (tolerância); investimento = neutro')
    chk(r['v5']['cls'] == 'fav' and '+48,9 p.p.' in r['v5']['html'], 'margem: variação em pontos percentuais')
    chk('+368,7%' in r['v6']['html'] and r['v6']['cls'] == 'fav', 'receita das vendas: +368,7%')
    chk(r['s1']['k'] == 'desf' and r['s2']['k'] == 'fav' and r['s3']['k'] == 'aten' and r['s4']['k'] == 'fav' and r['s5'] is None and r['s6']['k'] == 'desf', 'status: zero é limite dos saldos; acima de zero e abaixo da meta = atenção; sem referência = sem status')
    chk(r['p1'] == {'pIni': '2026-08-01', 'pFim': '2026-08-31', 'rot': 'ago/26 (mês completo)'} and r['p2']['pIni'] == '2026-08-10' and r['p2']['pFim'] == '2026-09-04' and r['p3']['pIni'] == '2026-04-01' and r['p3']['pFim'] == '2026-06-30', 'período anterior: mês cheio contra mês cheio; janela livre contra a de mesmo tamanho ' + json.dumps(r['p2']))
    # ---- Dashboard ----
    front.vai(pg, 'adm-painel', SET, 7000)
    t = pg.inner_text('.kpis.hero')
    chk(MIL(VS) in t and DV in t and 'vs. ago/26 (' + MIL(VA) + ')' in t and DR not in t, 'cartão de receita: variação das vendas, não da DRE')
    lu = pg.evaluate("() => { const k = [...document.querySelectorAll('.kpis.hero .kpi')][1]; return { v: k.querySelector('.v').textContent, c: k.querySelector('.v').className, t: k.innerText }; }")
    chk(lu['v'] == MIL(LS) and 'sem-v-desf' in lu['c'] and DL in lu['t'] and 'vs. ago/26' in lu['t'] and 'negativo' in lu['t'], 'lucro negativo em vermelho, com a diferença em reais e a pílula ' + repr(lu['t'][:160]) + ' ' + DL)
    sa = pg.evaluate("() => { const v = document.querySelector('#pgSalV'); return { v: v.textContent, c: v.className, p: document.querySelector('#pgSalSt').innerText }; }")
    chk(sa['v'] == '−R$ 71,1 mil' and 'sem-v-desf' in sa['c'] and 'negativo' in sa['p'], 'saldo negativo em vermelho pelo limite zero')
    mini = pg.evaluate("() => [...document.querySelectorAll('.kpis.mini .kpi .v')].map(v => v.textContent.trim()).filter(t => /R\\$/.test(t))")
    chk(len(mini) == 3 and all(x.endswith(' mil') for x in mini), 'cartões pequenos: uma escala para a linha ' + str(mini))
    chk(pg.evaluate("() => [...document.querySelectorAll('.kpis.mini .kpi')].some(k => /6\\.052,47/.test(k.querySelector('.v').title))"), 'valor completo no tooltip')
    ob = pg.inner_text('.gc-obs')
    chk('contra ago/26 (mês completo)' in ob and 'Margem subiu, mas segue negativa' in ob and '216' not in ob and 'Referência' in ob and 'Desfavorável' in ob, 'observações: mês cheio contra mês cheio, categoria e referência')
    chk(pg.evaluate("() => [...document.querySelectorAll('#pgEvo polyline, #pgEvo path')].some(p => /gc-c3/.test(p.getAttribute('stroke') || p.style.stroke || ''))") and 'mas continua negativa' in pg.inner_text('#pgEvo'), 'gráfico mensal: lucro em lilás e recado que diz que a margem segue negativa')
    fin = pg.evaluate("() => { const k = [...document.querySelectorAll('[data-sem] .kpi')].find(k => /^Margem/.test(k.querySelector('.l').textContent)); return { v: k.querySelector('.v').textContent, c: k.querySelector('.v').className }; }")
    chk(fin['v'] == PCT(LS / RS) and 'sem-v-desf' in fin['c'], 'métricas financeiras: margem negativa em vermelho, com o sinal certo')
    chk(not pg.evaluate("() => [...document.querySelectorAll('[data-sem] .kpi')].some(k => k.classList.contains('kneg') || k.classList.contains('kpos'))"), 'a cor pelo sinal não mexe nos cartões do piloto')
    pg.screenshot(path=SHOT + '1_dashboard.png')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    ctx.close()
    # ---- com cenário de margem e saldo mínimo cadastrados (no navegador) ----
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000, prefs={'custoOp:' + WS: json.dumps({'meta': 30}), 'growths_saldo_min_' + WS: '20000'})
    front.vai(pg, 'adm-painel', SET, 8000)
    chk('margem abaixo do cenário Ruim (20%)' in pg.inner_text('#pgLucSt') and 'saldo mínimo' in pg.inner_text('#pgSalSt') and 'abaixo do cenário Ruim (20%)' in pg.inner_text('#pgMgSt'), 'com cenário e saldo mínimo cadastrados, as pílulas dizem a referência')
    ctx.close()
    # ---- modo escuro e celular ----
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000, prefs={'growths_tema': 'dark'})
    pg.evaluate("document.documentElement.removeAttribute('data-theme')"); front.vai(pg, 'adm-painel', SET, 7000)
    cor = pg.evaluate("() => getComputedStyle(document.querySelector('#pgSalV')).color")
    chk(cor == 'rgb(207, 103, 110)', 'escuro: vermelho de texto #CF676E ' + cor)
    pg.screenshot(path=SHOT + '2_escuro.png'); ctx.close()
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=844)
    front.vai(pg, 'adm-painel', SET, 7000)
    sw = pg.evaluate("document.documentElement.scrollWidth"); chk(sw <= 396, 'celular: nada novo passa da tela (6 px de sobra já existiam na v0.151, nas tabelas) ' + str(sw) + ' ' + str(pg.evaluate("() => [...document.querySelectorAll('#main *')].filter(e => e.getBoundingClientRect().right > 392).slice(0, 3).map(e => e.className + ':' + (e.textContent || '').slice(0, 40))")))
    pg.screenshot(path=SHOT + '3_celular.png', full_page=True); ctx.close()
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
