"""v0.155: contexto contra o período anterior e frase-recado no Financeiro, Marketing e Vendas. Banco fa (Escola Aurora). Só lê."""
import sys; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots155/'
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
CTX = "(rot) => { const k = [...document.querySelectorAll('#main .kpi')].find(k => (k.querySelector('.l') || {}).textContent.replace(/[›⚠ⓘ]/g, '').trim().startsWith(rot)); return k ? k.innerText : ''; }"
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    r = pg.evaluate("() => semPerAnt('2026-10-01', '2026-10-15')")
    chk(r['pIni'] == '2026-09-01' and r['pFim'] == '2026-09-15', 'mês até hoje compara com os mesmos dias do mês anterior ' + str(r))
    front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 8000)
    t = pg.inner_text('#main')
    chk('No período, o resultado foi ' + MIL(LS) in t and 'contra ago/26 (mês completo), quando foi ' + MIL(LA) in t, 'Financeiro: frase-recado com o resultado e a base')
    chk(DL in pg.evaluate(CTX, 'Resultado no período') and DR in pg.evaluate(CTX, 'Receitas no período'), 'Financeiro: cartões com contexto (resultado em reais, receita em %)')
    pg.screenshot(path=SHOT + '1_financeiro.png'); erros += pg.errs
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 9000)
    t = pg.inner_text('#main')
    chk('Entraram' in t and 'não são comparados' in t and 'vs. ago/26' in pg.evaluate(CTX, 'Leads') and 'vs.' not in pg.evaluate(CTX, 'ROAS'), 'Marketing: leads, investimento e CPL comparados; ROAS e afins não (coortes com tempos diferentes)')
    pg.screenshot(path=SHOT + '2_marketing.png'); erros += pg.errs
    front.vai(pg, 'crm-vendas', "S.vp = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 7000)
    chk('vs. ago/26' in pg.evaluate(CTX, 'Vendas aprovadas') and 'vs. ago/26' in pg.evaluate(CTX, 'Ticket médio'), 'Vendas: vendas e ticket contra o mês anterior')
    pg.screenshot(path=SHOT + '3_vendas.png'); erros += pg.errs
    front.vai(pg, 'crm-dash', '', 7000)
    chk('vs. 30 dias antes' in pg.evaluate(CTX, 'Novos em 30 dias') and pg.evaluate("() => !!document.querySelector('#main .kpi .sem-d')"), 'Dashboard de vendas: variação dos novos com direção')
    erros += pg.errs
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 7000)
    chk(pg.evaluate("() => !!document.querySelector('#main .gc-lead .sem-neu')"), 'Custos e margens: variação do custo neutra')
    erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
