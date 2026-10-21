"""v0.127 (Onda 3): receita por papel da oferta em Vendas e a oferta na importação; meta × realizado acumulado do plano;
saldo mínimo de caixa no Financeiro e no Dashboard (no navegador sem a coluna; no cadastro da empresa com RODAR_v0.127_saldo_minimo.sql).
Banco fa: o teste cria ofertas, plano e metas mensais de mentira (prefixo T127), liga vendas às ofertas e desfaz tudo no fim."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
MIG = '/home/claude/growths/supabase/RODAR_v0.127_saldo_minimo.sql'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr)
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
P1, P2 = '5a1c6077-dda8-42cf-9c96-ca913be007d2', 'b3a884af-4422-495c-9fee-be444c2584d2'
def limpa():
    sql(f"""set session_replication_role = replica;
      update vendas set oferta_id = null where workspace_id = '{WS}' and oferta_id in (select id from ofertas where workspace_id = '{WS}' and nome like 'T127 %');
      delete from ofertas where workspace_id = '{WS}' and nome like 'T127 %';
      delete from planos where workspace_id = '{WS}' and nome like 'T127 %';
      delete from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and orcamento = 127;
      alter table empresa drop column if exists saldo_minimo;""")
    sql("notify pgrst, 'reload schema'")
limpa()
TEM_EMP = sql(f"select count(*) from empresa where workspace_id = '{WS}'") == '1'
sql(f"""set session_replication_role = replica;
  insert into ofertas (workspace_id, produto_id, nome, papel, preco) values ('{WS}', '{P1}', 'T127 Principal', 'principal', 497), ('{WS}', '{P2}', 'T127 Upsell', 'upsell', 1500);
  update vendas v set oferta_id = o.id from ofertas o where v.workspace_id = '{WS}' and o.workspace_id = '{WS}' and o.nome like 'T127 %' and o.produto_id = v.produto_id;
  insert into planos (workspace_id, nome, data_inicio, data_fim, status) values ('{WS}', 'T127 Plano', '2026-08-01', '2026-12-31', 'ativo');
  insert into planejamento_mensal (workspace_id, ano, mes, meta_leads, meta_vendas, meta_receita, orcamento) values
   ('{WS}', 2026, 8, 300, 40, 40000, 127), ('{WS}', 2026, 9, 300, 40, 40000, 127), ('{WS}', 2026, 10, 300, 40, 40000, 127), ('{WS}', 2026, 11, 300, 40, 40000, 127), ('{WS}', 2026, 12, 300, 40, 40000, 127);""")
try:
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
        erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
        # ---------------- Vendas por oferta ----------------
        front.vai(pg, 'crm-vendas', "S.vp = { pre: '90' }", 7000)
        pn = pg.locator('#main .panel:has(h2:text("order bump"))')
        chk(pn.count() == 1 and pn.locator('svg.gc rect').count() >= 1, 'Vendas: receita por papel da oferta')
        rot = pn.locator('.gc-bhr').all_inner_texts()
        chk('Oferta principal' in rot and 'Upsell' in rot, 'papéis aparecem pelo nome (%s)' % rot)
        ups = float(sql(f"""select coalesce(sum(v.valor_bruto), 0) from vendas v join ofertas o on o.id = v.oferta_id where v.workspace_id = '{WS}' and v.status = 'aprovada' and o.papel = 'upsell'
                         and (v.data_venda at time zone 'America/Sao_Paulo')::date between '2026-07-18' and '2026-10-15'"""))
        soma = pg.evaluate("[...[...document.querySelectorAll('#main .panel')].find(p => /order bump/.test(p.innerText)).querySelectorAll('rect title')].filter(t => t.textContent.startsWith('Upsell')).map(t => Number(t.textContent.split(':').pop().split('(')[0].replace(/[^0-9,]/g, '').replace(',', '.'))).reduce((a, b) => a + b, 0)")
        chk(abs(soma - ups) < 0.01, 'upsell do gráfico = soma das vendas de upsell (%.2f = %.2f)' % (soma, ups))
        # ---------------- Importação: oferta ----------------
        r = pg.evaluate("""async () => { IMPST.alvo = 'vendas'; await impCarregaRefs(); const c = IMP_ALVOS.vendas.campos.find(x => x.k === 'oferta_id');
            return [!!c, impConv(c, 't127 upsell', IMPST.refs).v || null, impConv(c, 'não existe', IMPST.refs).erro || null]; }""")
        oid = sql(f"select id from ofertas where workspace_id = '{WS}' and nome = 'T127 Upsell'")
        chk(r[0] and r[1] == oid, 'importação de vendas reconhece a oferta pelo nome (sem diferenciar maiúsculas)')
        chk(r[2] and 'não encontrado' in r[2], 'oferta desconhecida vira aviso, não erro de banco')
        # ---------------- Planejamento ----------------
        front.vai(pg, 'adm-plano', "S.pl = { id: '', tab: 'obj' }", 8000)
        pl = pg.locator('#plTempo')
        chk(pl.count() == 1 and pl.locator('svg.gc').count() == 3, 'Planejamento: meta × realizado acumulado (receita, vendas, leads)')
        rec = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date between '2026-08-01' and '2026-10-15'"))
        pct = round(rec / 120000 * 100)
        chk(('%d%% da meta até out/26' % pct) in pl.inner_text(), 'receita: %d%% da meta acumulada até outubro' % pct)
        chk('Sem cenário, o sistema não projeta' in pl.inner_text(), 'sem cenário aprovado, não há projeção')
        # ---------------- Saldo mínimo (sem a coluna: fica no navegador) ----------------
        front.vai(pg, 'fin-dash', '', 7000)
        chk(pg.locator('#finSmin').count() == 1 and 'Informe o saldo' in pg.inner_text('#finSmin'), 'Financeiro: saldo mínimo, ainda sem valor')
        alto = int(float(pg.evaluate("Math.max(...[...document.querySelectorAll('#finSmin svg circle title')].map(t => Number(t.textContent.split(':').pop().replace(/[^0-9,-]/g, '').replace(',', '.'))))")) + 1000)
        pg.fill('#smV', str(alto)); pg.click('#smSalva'); pg.wait_for_timeout(6000)
        chk('Atenção' in pg.inner_text('#finSmin') and 'navegador' in pg.inner_text('#finSmin'), 'mínimo acima da projeção → aviso; salvo no navegador sem a coluna')
        front.vai(pg, 'adm-painel', "S.pg = { per: '30d' }", 9000)
        chk('Caixa abaixo do mínimo' in pg.inner_text('.gc-obs'), 'Dashboard: observação "Caixa abaixo do mínimo"')
        b.close()
    # ---------------- Saldo mínimo com a coluna (RODAR_v0.127) ----------------
    subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-q', '-v', 'ON_ERROR_STOP=1', '-f', MIG], check=True, capture_output=True)
    sql(f"set session_replication_role = replica; alter table empresa alter column saldo_minimo set default null;")
    subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-q', '-f', MIG], check=True, capture_output=True)
    chk(sql("select count(*) from information_schema.columns where table_name = 'empresa' and column_name = 'saldo_minimo'") == '1', 'RODAR_v0.127 cria a coluna e pode ser rodado de novo')
    import time; time.sleep(2)
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
        front.vai(pg, 'fin-dash', '', 7000)
        baixo = max(0, int(float(pg.evaluate("Math.min(...[...document.querySelectorAll('#finSmin svg circle title')].map(t => Number(t.textContent.split(':').pop().replace(/[^0-9,-]/g, '').replace(',', '.'))))")) - 1000))
        pg.fill('#smV', str(baixo)); pg.click('#smSalva'); pg.wait_for_timeout(6000)
        chk(sql(f"select saldo_minimo::int from empresa where workspace_id = '{WS}'") == str(baixo) and 'toda a equipe' in pg.inner_text('#finSmin'), 'com a coluna, o mínimo fica no cadastro da empresa')
        t = pg.inner_text('#finSmin'); chk(('Dentro do mínimo' in t) if baixo > 0 else ('Atenção' in t), 'aviso segue a projeção (mínimo %d)' % baixo)
        b.close()
    chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
finally:
    if not TEM_EMP: sql(f"delete from empresa where workspace_id = '{WS}'")
    limpa()
    chk(sql(f"select count(*) from ofertas where workspace_id = '{WS}' and nome like 'T127 %'") == '0', 'dados de teste apagados e coluna removida da base de teste')
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
