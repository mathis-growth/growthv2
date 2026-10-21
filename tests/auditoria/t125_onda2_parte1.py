"""v0.125 (Data Storytelling, onda 2, parte 1): observações no Dashboard; resultado × banco no Financeiro; vencimentos e atrasos em
Contas a receber e a pagar; MRR mês a mês com novos/expansão/redução/cancelados em Contratos; vendas por semana e margem por produto em Vendas;
CAC × clientes por campanha no Dashboard de marketing; leads até a compra em Leads por origem. Banco fa (o teste liga e desliga 3 contratos recorrentes)."""
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
# três contratos de clientes diferentes viram recorrentes mensais (sem disparar gatilhos); voltam ao fim
CT = sql(f"""select string_agg(id::text, ',') from (select distinct on (pessoa_id) id from contratos where workspace_id = '{WS}' order by pessoa_id, id limit 3) x""").split(',')
ORIG = sql(f"select json_agg(json_build_object('id', id, 'r', recorrente, 'p', periodicidade, 'i', data_inicio, 'f', data_fim, 'c', cancelado_em)) from contratos where id in ({','.join(repr(c) for c in CT)})")
def liga():
    sql(f"""set session_replication_role = replica;
      update contratos set recorrente = true, periodicidade = 'mensal', data_inicio = '2026-06-01', data_fim = null, cancelado_em = null where id = '{CT[0]}';
      update contratos set recorrente = true, periodicidade = 'mensal', data_inicio = '2026-08-01', data_fim = null, cancelado_em = '2026-09-15 12:00-03' where id = '{CT[1]}';
      update contratos set recorrente = true, periodicidade = 'mensal', data_inicio = '2026-10-01', data_fim = null, cancelado_em = null where id = '{CT[2]}';""")
def desliga():
    for o in json.loads(ORIG):
        sql("set session_replication_role = replica; update contratos set recorrente = %s, periodicidade = %s, data_inicio = %s, data_fim = %s, cancelado_em = %s where id = '%s'" % (
            'true' if o['r'] else 'false', "'%s'" % o['p'] if o['p'] else 'null', "'%s'" % o['i'] if o['i'] else 'null', "'%s'" % o['f'] if o['f'] else 'null', "'%s'" % o['c'] if o['c'] else 'null', o['id']))
V = [float(sql(f"select sum(quantidade * valor) from contrato_itens where contrato_id = '{c}'")) for c in CT]
liga()
try:
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
        erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
        # ---------------- Contratos: MRR ----------------
        front.vai(pg, 'crm-contratos', '', 6000)
        t = pg.inner_text('#main')
        chk('Receita recorrente (MRR) mês a mês' in t and pg.locator('#main svg.gc').count() == 2, 'Contratos: linha do MRR e barras do movimento')
        rpc = pg.evaluate("sb.rpc('painel_gerencial', { p_ws: S.ws, p_ini: '2026-10-01', p_fim: '2026-10-15', p_hoje: '2026-10-15' }).then(r => r.data.recorrencia.mrr)")
        js = pg.evaluate("""async () => { const c = (await sb.from('contratos').select('*, contrato_itens(quantidade,valor)').eq('workspace_id', S.ws)).data;
            const s = o => Object.values(o).reduce((t, v) => t + v, 0); return [s(mrrEm(c, '2026-10-15')), s(mrrEm(c, '2026-09-30')), s(mrrEm(c, '2026-08-31'))]; }""")
        chk(abs(js[0] - float(rpc)) < 0.01, 'MRR de hoje igual ao do painel (%.2f = %.2f)' % (js[0], float(rpc)))
        chk(abs(js[0] - (V[0] + V[2])) < 0.01 and abs(js[1] - V[0]) < 0.01 and abs(js[2] - (V[0] + V[1])) < 0.01, 'MRR no fim de ago, set e hoje segue as datas de início e cancelamento')
        lead = pg.inner_text('#main .panel:has(h2:text("Receita recorrente (MRR)")) .gc-lead')
        chk('novos' in lead and 'cancelados' in lead, 'frase do mês com novos, expansão, redução e cancelados')
        # ---------------- Dashboard: observações ----------------
        front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 8000)
        ob = pg.locator('.gc-obs')
        chk(ob.count() == 1, 'Dashboard: bloco "O que mudou e merece atenção"')
        chk(pg.locator('.gc-ob').count() <= 4, 'no máximo 4 observações')
        txt = ob.inner_text()
        chk(('Fato' in txt and 'Investigar' in txt) or 'Nada fora do normal' in txt, 'cada observação separa fato e o que investigar')
        chk('Regras fixas, sem IA' in txt, 'mostra as regras e que hipótese não é causa')
        # ---------------- Financeiro ----------------
        front.vai(pg, 'fin-dash', '', 7000)
        pn = pg.locator('#main .panel:has(h2:text("Resultado × dinheiro no banco"))')
        chk(pn.count() == 1 and pn.locator('svg.gc rect').count() >= 2, 'Financeiro: resultado × banco por mês')
        tit = pg.evaluate("[...document.querySelectorAll('#main .panel')].find(p => /Resultado × dinheiro/.test(p.innerText)).querySelectorAll('rect title')[9].textContent")
        ban = float(sql(f"""select coalesce(sum(case m.tipo when 'entrada' then m.valor else -m.valor end), 0) from movimentacoes_bancarias m join contas_bancarias c on c.id = m.conta_bancaria_id
                         where m.workspace_id = '{WS}' and c.tipo = 'conta' and m.data between '2026-09-01' and '2026-09-30'"""))
        chk(('R$' in tit and abs(float(tit.split(':')[-1].replace('R$', '').replace('\xa0', '').replace(' ', '').replace('.', '').replace(',', '.').replace('−', '-')) - ban) < 0.01) and 'set/26' in tit, 'variação do banco de set/26 bate com o extrato (%s)' % tit)
        # ---------------- Receber e pagar ----------------
        for v, nome in [('fin-receber', 'receber'), ('fin-pagar', 'pagar')]:
            front.vai(pg, v, '', 6000)
            vc = pg.locator('.gc-venc')
            chk(vc.count() == 1 and vc.locator('svg.gc rect').count() >= 1, nome + ': vencimentos das próximas 8 semanas')
            atr = float(sql(f"select coalesce(sum(valor), 0) from contas_{nome} where workspace_id = '{WS}' and status = 'previsto' and substituida_por is null and vencimento < '2026-10-15'"))
            t = vc.inner_text()
            chk(('Nada em atraso' in t) if atr == 0 else ('vencidos' in t and vc.locator('.gc-bhl').count() == 5), nome + ': faixas de atraso (%.2f em atraso)' % atr)
        # ---------------- Vendas ----------------
        front.vai(pg, 'crm-vendas', "S.vp = { pre: '90' }", 6000)
        t = pg.inner_text('#main')
        chk('Vendas e ticket médio por semana' in t, 'Vendas: 90 dias → por semana')
        chk('Receita e margem por produto' in t and pg.locator('#vdProd .gc-bhl').count() >= 1, 'Vendas: receita e margem por produto')
        tot = pg.evaluate("[...document.querySelectorAll('#vdProd .gc-bhl')].length")
        nome1 = pg.locator('#vdProd .gc-bhr').first.inner_text()
        chk(not nome1.strip().isdigit(), 'produto aparece pelo nome (%s)' % nome1)
        # ---------------- Marketing ----------------
        front.vai(pg, 'mkt-dash', '', 8000)
        chk('Qual campanha dá mais retorno' in pg.inner_text('#main') and pg.locator('#main circle').count() >= 1, 'Marketing: CAC × clientes por campanha')
        # ---------------- Origem ----------------
        front.vai(pg, 'mkt-origem', "S.o = { dim: 'canal_origem', camp: '', de: '', ate: '' }", 6000)
        chk('Qual origem traz lead que compra' in pg.inner_text('#main') and pg.locator('.gc-emp').count() >= 1, 'Leads por origem: barras 100% (não qualificado, qualificado, comprou)')
        soma = pg.evaluate("[...document.querySelectorAll('.gc-emp')][0].parentElement.querySelector('.gc-bhv').innerText")
        n1 = pg.evaluate("[...document.querySelectorAll('#main table tbody tr')][0].children[1].innerText")
        chk(soma == n1, 'total da primeira origem igual ao da tabela (%s = %s)' % (soma, n1))
        chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
        b.close()
finally:
    desliga()
    chk(sql(f"select count(*) from contratos where workspace_id = '{WS}' and recorrente") == '0', 'contratos voltaram ao que eram')
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
