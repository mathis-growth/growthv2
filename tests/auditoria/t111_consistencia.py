"""v0.111: Dashboard, Dashboard financeiro, Custos e margens e Growth Model mostram o mesmo lucro de setembro/2026 (R$ 2.228,66);
o regime escolhido em Custos e margens vai para o Cadastro da empresa e vale em outro navegador. Precisa do banco fa + PostgREST (LEIA.md)."""
import sys, subprocess, re; sys.path.insert(0, '.')
from front import abre, vai
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def psql(sql): return subprocess.run(['su', 'postgres', '-c', 'psql -p 55432 -d fa -Atc "%s"' % sql.replace('"', '\\"')], capture_output=True, text=True).stdout.strip()
ORIG = psql("select coalesce(regime_tributario,'')||'|'||coalesce(anexo_simples,'') from empresa where workspace_id='%s'" % WS)
KPI = """() => { const o = {}; document.querySelectorAll('#main .kpi').forEach(k => { const l = (k.querySelector('.l') || {}).innerText; if (l) o[l.replace(/\\s*ⓘ\\s*$/, '').trim()] = [(k.querySelector('.v') || {}).innerText, (k.querySelector('.s') || {}).innerText]; }); return o; }"""
LUCRO = 'R$\xa02.228,66'; falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg = abre(b)
        vai(pg, 'adm-painel', "S.pg = { per: 'custom', de: '2026-09-01', ate: '2026-09-30' }", 5000); k = pg.evaluate(KPI)
        chk(k.get('Lucro', [''])[0] == LUCRO, 'Dashboard: lucro de setembro ' + str(k.get('Lucro')))
        chk(k.get('Vendas aprovadas', [''])[0] == '65', 'Dashboard: 65 vendas no período (antes 111, todo o histórico)')
        chk('Receita bruta das vendas' in k, 'Dashboard: rótulo "Receita bruta das vendas"')
        vai(pg, 'fin-dash', "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }", 5000); k = pg.evaluate(KPI)
        chk(k.get('Resultado no período', [''])[0] == LUCRO, 'Dashboard financeiro: resultado do período escolhido')
        chk(k.get('Receitas no período', [''])[0] == 'R$\xa075.955,00', 'Dashboard financeiro: receitas do período')
        vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 6000); k = pg.evaluate(KPI)
        chk(k.get('Lucro líquido', [''])[0] == LUCRO and 'mesmo da DRE' in k['Lucro líquido'][1], 'Custos e margens: lucro = DRE ' + str(k.get('Lucro líquido')))
        chk(k.get('Receita do mês', [''])[0] == 'R$\xa075.955,00', 'Custos e margens: receita pela competência')
        chk(k.get('A receber no mês', [''])[0] == 'R$\xa046.344,15', 'Custos e margens: a receber continua separado')
        t = pg.inner_text('#main'); chk('Outros lançamentos' not in t, 'Custos e margens: produtos somam a receita inteira')
        chk('Custo de entrega por produto' in t, 'Custos e margens: custo de entrega vira premissa das projeções')
        # regime vai para o cadastro
        pg.select_option('#coReg', 'simples_III'); pg.wait_for_timeout(4000)
        chk(psql("select regime_tributario||'|'||anexo_simples from empresa where workspace_id='%s'" % WS) == 'simples_nacional|III', 'Regime salvo no Cadastro da empresa')
        pg.fill('#coVar', '3'); pg.dispatch_event('#coVar', 'change'); pg.wait_for_timeout(3500)
        chk(psql("select taxas_variaveis_pct from empresa where workspace_id='%s'" % WS) == '3.00', '% de taxas salvo no Cadastro da empresa')
        k = pg.evaluate(KPI); chk(k.get('Lucro líquido', [''])[0] == LUCRO, 'Com taxas lançadas no mês, o % não muda o real')
        ctx.close()
        # outro navegador, com regime antigo guardado no localStorage: vale o do cadastro
        ctx, pg = abre(b, prefs={'custoOp:' + WS: '{"regime":"mei","varPct":0}'})
        vai(pg, 'fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 6000)
        chk(pg.eval_on_selector('#coReg', 'e => e.value') == 'simples_III', 'Outro navegador lê o regime do cadastro (ignora o localStorage)')
        vai(pg, 'adm-empresa', '', 4000)
        chk(pg.eval_on_selector('[name=anexo_simples]', 'e => e.value') == 'III', 'Cadastro da empresa mostra o anexo')
        vai(pg, 'gro-modelo', '', 5000); pg.evaluate("() => { S.gl.de = '2026-09-01'; S.gl.n = 1; render(); }"); pg.wait_for_timeout(6000)
        t = pg.inner_text('#main')
        chk('= Lucro\tR$\xa02.228,66' in t, 'Growth Model: lucro real de setembro = DRE')
        chk('− Custos fixos do período\tR$\xa029.700,00' in t, 'Growth Model: custos fixos aparecem (antes zerados)')
        chk('(meses fechados: os lançados)\tR$\xa04.956,40' in t, 'Growth Model: impostos lançados')
        chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
        ctx.close(); b.close()
finally:
    r, a = (ORIG.split('|') + [''])[:2]
    psql("update empresa set regime_tributario=%s, anexo_simples=%s, taxas_variaveis_pct=null, aliquota_manual=null where workspace_id='%s'" % ("'%s'" % r if r else 'null', "'%s'" % a if a else 'null', WS))
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
