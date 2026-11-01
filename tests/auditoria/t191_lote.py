"""v0.191: Contas a pagar e a receber — selecionar várias contas e dar baixa em todas de uma vez.
Banco fa (Escola Aurora). A baixa gera lançamentos contábeis, que o banco não deixa apagar; o teste desfaz tudo no fim
com session_replication_role = replica (só no banco de teste), devolvendo as contas ao estado anterior."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots191/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def desfaz(rec_ids):
    ids = ','.join("'%s'" % i for i in rec_ids) or "null"
    sql(f"""begin; set local session_replication_role = replica;
      create temp table l on commit drop as select id from lancamentos where workspace_id = '{WS}' and (
        origem_id in (select id from contas_pagar where workspace_id = '{WS}' and descricao like 'Teste lote%')
        or (origem_tipo = 'recebimento' and origem_id in ({ids}) and criado_em >= '{T0}'));
      delete from movimentacoes_bancarias where lancamento_id in (select id from l); delete from partidas where lancamento_id in (select id from l);
      delete from lancamentos where id in (select id from l);
      update contas_receber set status = 'previsto', data_recebimento = null where id in ({ids});
      delete from contas_pagar where workspace_id = '{WS}' and descricao like 'Teste lote%'; commit;""")
T0 = sql('select now()')
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
# mais duas contas a pagar em aberto, copiadas da que existe (uma delas estimada: não pode entrar no lote)
base = sql(f"select id from contas_pagar where workspace_id = '{WS}' and status = 'previsto' and not estimativa limit 1")
for desc, est in [('Teste lote A', 'false'), ('Teste lote B', 'false'), ('Teste lote estimada', 'true')]:
    sql(f"""insert into contas_pagar (workspace_id, descricao, valor, vencimento, competencia, conta_despesa_id, fornecedor_id, status, estimativa)
            select workspace_id, '{desc}', 100 + length('{desc}'), '2026-10-20', '2026-10-20', conta_despesa_id, fornecedor_id, 'previsto', {est} from contas_pagar where id = '{base}'""")
abertas = json.loads(sql(f"select json_agg(json_build_object('id', id, 'v', valor, 'e', estimativa)) from contas_pagar where workspace_id = '{WS}' and status = 'previsto' and substituida_por is null"))
pagaveis = [a for a in abertas if not a['e']]
mov0 = int(sql(f"select count(*) from movimentacoes_bancarias where workspace_id = '{WS}'"))
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-31', vw=1440, vh=1000)
    front.vai(pg, 'fin-pagar', "S.per = { pre: 'tudo', de: '', ate: '' }; S.pf = { st: '' };", 6000)
    chk(pg.locator('[data-lote]').count() == len(pagaveis), 'Pagar: um quadradinho por conta em aberto (%d)' % len(pagaveis))
    chk(pg.locator('input.lote-chk[disabled]').count() == 1, 'Pagar: a conta estimada aparece sem poder selecionar')
    pagas = int(sql(f"select count(*) from contas_pagar where workspace_id = '{WS}' and status = 'pago'"))
    chk(pagas > 0 and pg.locator('tr:has-text("pago") [data-lote]').count() == 0, 'Pagar: conta paga não tem quadradinho')
    chk(not pg.locator('#loteBar').is_visible(), 'barra escondida sem nada selecionado')
    pg.click('[data-lote-todos]'); pg.wait_for_timeout(300)
    tot = sum(float(a['v']) for a in pagaveis)
    t = pg.inner_text('#loteBar')
    chk(pg.locator('#loteBar').is_visible() and ('%d contas' % len(pagaveis)) in t, 'Selecionar todas marca as %d em aberto: %r' % (len(pagaveis), t))
    pg.screenshot(path=SHOT + '1_pagar_selecao.png')
    # tira uma: fica a seleção parcial
    pg.locator('[data-lote]').first.click(); pg.wait_for_timeout(200)
    chk(pg.evaluate("document.querySelector('[data-lote-todos]').indeterminate") and ('%d contas' % (len(pagaveis) - 1)) in pg.inner_text('#loteBar'), 'tirar uma deixa o "todas" pela metade')
    fica = pg.locator('[data-lote]').first.get_attribute('data-lote')
    sel_ids = [a['id'] for a in pagaveis if a['id'] != fica]
    pg.click('[data-lote-ok]'); pg.wait_for_timeout(1500)
    chk(pg.locator('#modalRoot .lote-lista tbody tr').count() == len(sel_ids) + 1, 'modal lista as contas escolhidas e o total')
    pg.screenshot(path=SHOT + '2_pagar_modal.png')
    pg.fill('#modalRoot input[name=data]', '2026-10-30')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(5000)
    st = json.loads(sql(f"select json_object_agg(id, status || '|' || coalesce(data_pagamento::text, '')) from contas_pagar where workspace_id = '{WS}'"))
    chk(all(st[i] == 'pago|2026-10-30' for i in sel_ids), 'as %d selecionadas ficaram pagas em 30/10' % len(sel_ids))
    chk(st[fica].startswith('previsto'), 'a que foi desmarcada continua a pagar')
    mov1 = int(sql(f"select count(*) from movimentacoes_bancarias where workspace_id = '{WS}'"))
    chk(mov1 - mov0 == len(sel_ids), 'cada conta paga virou uma saída no banco (%d)' % (mov1 - mov0))
    chk('pagas' in pg.inner_text('#toasts') if pg.locator('#toasts').count() else True, 'aviso de contas pagas')
    pg.screenshot(path=SHOT + '3_pagar_depois.png', full_page=True); erros += pg.errs
    # ---------------- Receber ----------------
    rec = json.loads(sql(f"""select json_agg(x) from (select id, valor, (venda_id is not null) ev from contas_receber where workspace_id = '{WS}' and status = 'previsto' and substituida_por is null
                              and vencimento between '2026-10-01' and '2026-12-31' order by venda_id is null, vencimento limit 50) x"""))
    front.vai(pg, 'fin-receber', "S.per = { pre: 'pers', de: '2026-10-01', ate: '2026-12-31' }; S.rf = { rec: '', origem: '' };", 6000)
    n = pg.locator('[data-lote]').count()
    chk(n == len(rec), 'Receber: um quadradinho por parcela em aberto no período (%d)' % n)
    escolha = [rec[0]['id'], rec[-1]['id']]
    open(SHOT + 'escolha.txt', 'w').write(','.join(escolha))
    for i in escolha: pg.click(f'[data-lote="{i}"]')
    pg.wait_for_timeout(200)
    chk('2 contas' in pg.inner_text('#loteBar') and pg.locator('tr.lote-on').count() == 2, 'duas parcelas marcadas e destacadas')
    pg.screenshot(path=SHOT + '4_receber_selecao.png')
    pg.click('[data-lote-ok]'); pg.wait_for_timeout(1500)
    pg.screenshot(path=SHOT + '5_receber_modal.png')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(5000)
    r = sql(f"select string_agg(status, ',') from contas_receber where id in ('{escolha[0]}', '{escolha[1]}')")
    chk(r == 'recebido,recebido', 'as duas parcelas ficaram recebidas (%s)' % r)
    chk(pg.locator('[data-lote]').count() == n - 2, 'a lista atualiza: as recebidas saem do lote')
    erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
try: desfaz(open(SHOT + 'escolha.txt').read().split(','))
except Exception as e: print('limpeza:', e)
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
