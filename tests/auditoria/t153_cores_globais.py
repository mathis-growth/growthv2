"""v0.153: cor pelo significado em todas as telas (regra 2a nos saldos; variações pela direção, com tolerância; sem neon nos números).
Banco fa (Escola Aurora). Só lê."""
import sys, json; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots153/'
import os; os.makedirs(SHOT, exist_ok=True)
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
KP = """() => [...document.querySelectorAll('#main .kpi')].map(k => ({ l: ((k.querySelector('.l') || {}).textContent || '').replace(/[›⚠ⓘ]/g, '').trim(), v: ((k.querySelector('.v') || {}).textContent || '').trim(), c: ((k.querySelector('.v') || {}).className || '') + ' ' + k.className, s: ((k.querySelector('.s') || {}).innerHTML || '') }))"""
def kp(pg, l): return next((x for x in pg.evaluate(KP) if x['l'].startswith(l)), None)
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    tok = pg.evaluate("() => { const d = document.createElement('i'); d.style.color = 'var(--good)'; document.body.appendChild(d); const g = getComputedStyle(d).color; d.style.color = 'var(--bad)'; const r = getComputedStyle(d).color; d.remove(); return [g, r]; }")
    chk(tok == ['rgb(37, 123, 100)', 'rgb(194, 62, 72)'], 'cores de status do sistema = camada semântica ' + str(tok))
    chk(pg.evaluate("() => [brl(-96993.27), brl(null), fX(1.2234), fP(-0.0123)]") == ['−R$ 96.993,27', '—', '1,2x', '−1,2%'], 'formatadores globais: menos verdadeiro, "—" para sem dado, ROAS com 1 casa')
    # Dashboard financeiro
    front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    sb, rs, dp = kp(pg, 'Saldo em banco'), kp(pg, 'Resultado no período'), kp(pg, 'Despesas no período')
    chk('sem-v-desf' in sb['c'] and 'sem-v-desf' in rs['c'] and 'sem-v' not in dp['c'] and 'kneg' not in sb['c'], 'Financeiro: saldo e resultado negativos em vermelho; despesas sem cor')
    pg.screenshot(path=SHOT + '1_financeiro.png'); erros += pg.errs
    # Mídia paga: tolerância e direção
    front.vai(pg, 'mkt-trafego', "S.tDe = '2026-09-01'; S.tAte = '2026-09-30'", 6000)
    ctr, cpl, inv = kp(pg, 'CTR médio'), kp(pg, 'CPL médio'), kp(pg, 'Investimento')
    chk('sem-fav' in cpl['s'] and 'sem-neu' in inv['s'] and 'var(--bad)' not in ''.join(x['s'] for x in pg.evaluate(KP)), 'Mídia paga: CPL caindo verde; investimento neutro; nenhum estilo de cor solto ' + ctr['s'][:80])
    pg.screenshot(path=SHOT + '2_midia.png'); erros += pg.errs
    # Dashboard de marketing: ROI positivo verde (saldo), ROAS com 1 casa, LTV ÷ CAC como razão
    front.vai(pg, 'mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-09-30', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 6000)
    roi, roas = kp(pg, 'ROI'), kp(pg, 'ROAS')
    t = pg.inner_text('#main')
    chk('sem-v-fav' in roi['c'] and roas['v'] == '1,2x' and ':1' in t, 'Marketing: ROI positivo verde; ROAS 1,2x; LTV ÷ CAC em razão (x:1)')
    pg.screenshot(path=SHOT + '3_marketing.png'); erros += pg.errs
    # Custos e margens
    front.vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 6000)
    cm, ll, mg = kp(pg, 'Custo do mês'), kp(pg, 'Lucro líquido'), kp(pg, 'Margem de lucro')
    chk('sem-v' not in cm['c'] and 'sem-v-desf' in ll['c'] and 'sem-v-desf' in mg['c'], 'Custos e margens: custo sem cor; lucro e margem negativos em vermelho')
    erros += pg.errs
    # Dashboard de vendas: variação sem direção não fica vermelha
    front.vai(pg, 'crm-dash', '', 6000)
    nv = kp(pg, 'Novos em 30 dias')
    chk(nv and 'sem-v' not in nv['c'] and 'vneg' not in nv['c'], 'Vendas: "Novos em 30 dias" sem cor pelo sinal')
    erros += pg.errs
    # Dashboard: linha Resultado da DRE em vermelho; tabela de campanha sem vermelho por sinal
    front.vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 7000)
    r = pg.evaluate("() => { const tr = [...document.querySelectorAll('#main tr.tot')].find(t => /^Resultado/.test(t.cells[0].textContent)); return tr ? [...tr.cells].slice(1).map(c => [c.textContent.trim(), c.className]) : []; }")
    chk(r and all(('sem-desf' in c) == x.startswith('−') for x, c in r if x not in ('R$ 0,00',)), 'DRE: resultado negativo em vermelho, positivo em verde ' + json.dumps(r[:3], ensure_ascii=False))
    erros += pg.errs
    # modo escuro: sem neon
    ctx.close(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000, prefs={'growths_tema': 'dark'})
    pg.evaluate("document.documentElement.removeAttribute('data-theme')"); front.vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 6000)
    sh = pg.evaluate("() => getComputedStyle([...document.querySelectorAll('#main .kpi .v')].find(v => /−/.test(v.textContent))).textShadow")
    chk(sh == 'none', 'escuro: números sem brilho neon ' + sh)
    pg.screenshot(path=SHOT + '4_escuro.png'); erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
