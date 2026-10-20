"""v0.120: Comissões (quem recebe, regras, extrato, fechamento do mês, oferta e vendedor na venda) e Conexões automáticas
(Meta e Google) na tela Integrações. Banco fa (PostgREST 3300) + migrações 20261022100000 e 20261022200000.
O banco das comissões e a função "conexoes" têm testes próprios (SQL abaixo e tests/edge/conexoes_teste.ts)."""
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
    sql(f"""delete from comissoes where workspace_id = '{WS}' and equipe_id in (select id from equipe where nome like 'T120 %');
      delete from contas_pagar where workspace_id = '{WS}' and fornecedor_id in (select fornecedor_id from equipe where nome like 'T120 %');
      delete from comissao_regras where workspace_id = '{WS}' and equipe_id in (select id from equipe where nome like 'T120 %');
      delete from fornecedores where workspace_id = '{WS}' and nome like 'T120 %';
      update vendas set vendedor_id = null where vendedor_id in (select id from equipe where nome like 'T120 %');
      delete from equipe where workspace_id = '{WS}' and nome like 'T120 %';
      delete from conexoes where workspace_id = '{WS}'; delete from ads_externo_vinculos where workspace_id = '{WS}';""")
limpa(); sql("notify pgrst, 'reload schema'")
with sync_playwright() as p:
    b = p.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-10-15', vh=1000)
    # ---------------- Comissões ----------------
    t = front.vai(pg, 'cad-comissoes', "S.com = { aba: 'pessoas', mes: '2026-09', pessoa: '', sit: '' }", 4000)
    chk('Comissões' in t and 'Quem recebe' in t and 'Regras' in t and 'Resumo do mês' not in t, 'Configurações → Comissões: só Regras e Quem recebe')
    chk(pg.evaluate("() => NAV.find(g => g.g === 'Configurações').subs.some(sg => sg.items.some(i => i[0] === 'cad-comissoes'))"), 'Comissões no menu de Configurações')
    chk(pg.evaluate("() => NAV.find(g => g.g === 'Vendas').items.some(i => i[0] === 'crm-comissoes')"), 'acompanhamento continua em Vendas → Comissões')
    pg.click('#comNovaPes'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'T120 Coprodutora'); pg.select_option('#modalRoot [name=vinculo]', 'coprodutor')
    pg.uncheck('#modalRoot [name=equipe_comercial]'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(2500)
    pg.click('#comNovaPes'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=nome]', 'T120 Vendedor'); pg.select_option('#modalRoot [name=vinculo]', 'vendedor'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(2500)
    chk(sql(f"select string_agg(nome || ':' || vinculo || ':' || equipe_comercial, ',' order by nome) from equipe where workspace_id='{WS}' and nome like 'T120 %'") == 'T120 Coprodutora:coprodutor:false,T120 Vendedor:vendedor:true', 'Nova pessoa grava vínculo e equipe comercial')
    t = pg.inner_text('#main')
    chk('T120 Coprodutora' in t and 'Coprodutor' in t, 'Quem recebe lista as pessoas com o vínculo')
    # regra: coprodutora 10% do líquido de todas as vendas do projeto, mensal
    pg.click('#comNovaReg'); pg.wait_for_timeout(600)
    cop = sql(f"select id from equipe where nome = 'T120 Coprodutora'")
    pg.select_option('#modalRoot [name=equipe_id]', cop)
    chk(pg.input_value('#modalRoot [name=sobre]') == 'todas', 'coprodutora: regra sugere "todas as vendas"')
    pg.fill('#modalRoot [name=percentual]', '10'); pg.fill('#modalRoot [name=desde]', '2026-09-01')
    chk('ganha 10% do líquido de cada venda do projeto' in pg.inner_text('#comExplica'), 'explicação da regra em português', )
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(4000)
    esp = sql(f"select sum(round(coalesce(valor_liquido, valor_bruto) * 0.10, 2)) from vendas where workspace_id='{WS}' and status='aprovada' and (coalesce(aprovada_em, data_venda) at time zone 'America/Sao_Paulo')::date between '2026-09-01' and '2026-09-30'")
    got = sql(f"select sum(valor) from comissoes c join equipe e on e.id = c.equipe_id where e.nome = 'T120 Coprodutora' and c.origem = 'venda' and c.competencia = '2026-09-01'")
    chk(esp == got and got != '', f'regra salva e recalculada: 10% do líquido das vendas de setembro ({got})')
    # vendedor: 8% das próprias vendas de um produto (mais específica) e 3% do projeto
    vend = sql(f"select id from equipe where nome = 'T120 Vendedor'")
    sql(f"update vendas set vendedor_id = '{vend}' where id in (select id from vendas where workspace_id='{WS}' and status='aprovada' and data_venda between '2026-09-01' and '2026-09-30' order by data_venda limit 4)")
    prod = sql(f"select produto_id from vendas where vendedor_id = '{vend}' limit 1")
    for esc, extra, pct in [('projeto', '', '3'), ('produto', prod, '8')]:
        pg.click('#comNovaReg'); pg.wait_for_timeout(600)
        pg.select_option('#modalRoot [name=equipe_id]', vend); pg.select_option('#modalRoot [name=escopo]', esc)
        if extra: pg.select_option('#modalRoot [name=produto_id]', extra)
        pg.fill('#modalRoot [name=percentual]', pct); pg.fill('#modalRoot [name=desde]', '2026-09-01')
        if esc == 'projeto': chk(pg.input_value('#modalRoot [name=sobre]') == 'proprias', 'vendedor: regra sugere "só as vendas dele"')
        pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    r = sql(f"""select string_agg(distinct c.percentual::int::text || ':' || (v.produto_id = '{prod}')::text, ',') || '|' || count(*) from comissoes c join vendas v on v.id = c.venda_id where c.equipe_id = '{vend}'""")
    chk(r.split('|')[1] == '4' and set(r.split('|')[0].split(',')) <= {'8:true', '3:false'} and '8:true' in r, f'vendedor: só as 4 vendas dele, 8% no produto e 3% nos demais ({r})')
    t = front.vai(pg, 'crm-comissoes', "S.com = { aba: 'resumo', mes: '2026-09', pessoa: '', sit: '' }", 4000)
    tot = float(sql(f"select sum(valor) from comissoes where workspace_id='{WS}' and competencia='2026-09-01' and status in ('prevista','lancada','paga_manual')"))
    kv = pg.evaluate("() => [...document.querySelectorAll('.kpi')].find(k => k.innerText.startsWith('Comissões do mês')).querySelector('.v').innerText")
    chk(kv.replace('\xa0', ' ') == ('R$ ' + f'{tot:,.2f}'.replace(',', 'X').replace('.', ',').replace('X', '.')), f'Resumo: total do mês = banco ({kv})')
    chk(pg.locator('tr[data-compes]').count() == 2, 'Resumo: uma linha por pessoa')
    chk(pg.locator('#comNovaReg').count() == 0 and pg.locator('[data-go="cad-comissoes"]').count() == 1 and pg.locator('[data-comaba="pessoas"], [data-comaba="regras"]').count() == 0, 'Vendas → Comissões: sem configuração, com atalho "Configurar comissões"')
    pg.click('#comFechar'); pg.wait_for_timeout(800)
    chk('Fechar as comissões de 09/2026' in pg.inner_text('#modalRoot') and pg.locator('#modalRoot tbody tr').count() == 2, 'Fechar o mês: mostra o que vai virar conta a pagar')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    cps = sql(f"select count(*) || '|' || sum(valor) || '|' || min(vencimento) from contas_pagar where workspace_id='{WS}' and descricao like 'Comissões de 09/2026 · T120%'")
    chk(cps.split('|')[0] == '2' and abs(float(cps.split('|')[1]) - tot) < 0.01 and cps.split('|')[2] == '2026-10-10', f'fechamento: 2 contas a pagar, mesmo total, vencem dia 10 ({cps})')
    chk(sql(f"select count(*) from comissoes where workspace_id='{WS}' and competencia='2026-09-01' and status='prevista'") == '0', 'comissões do mês ficam lançadas')
    # reembolso depois de lançada → estorno pendente, aparece no extrato
    vr = sql(f"select venda_id from comissoes where equipe_id = '{cop}' and status = 'lancada' limit 1")
    sql(f"update vendas set status = 'reembolsada' where id = '{vr}'")
    t = front.vai(pg, 'crm-comissoes', f"S.com = {{ aba: 'extrato', mes: '2026-09', pessoa: '{cop}', sit: 'estorno_pendente' }}", 4000)
    chk(pg.locator('#main tbody tr').count() == 2 and 'Estorno pendente' in t, 'Extrato: reembolso depois de lançada vira estorno pendente')
    t = front.vai(pg, 'cad-comissoes', "S.com = { aba: 'regras', mes: '2026-09', pessoa: '', sit: '' }", 3500)
    chk('Projeto todo' in t and 'Produto:' in t and 'Só as vendas da pessoa' in t, 'Regras: lista por pessoa com escopo e "sobre"')
    # ---------------- Equipe e Nova venda ----------------
    t = front.vai(pg, 'cad-equipe', '', 3500)
    chk('vínculo' in t.lower() and 'Coprodutor' in t, 'Equipe e acessos: coluna Vínculo')
    pg.evaluate("() => modalVenda()"); pg.wait_for_timeout(2500)
    chk(pg.locator('#modalRoot [name=vendedor_id] option', has_text='T120 Vendedor').count() == 1, 'Nova venda: escolher quem vendeu (equipe comercial)')
    chk(pg.locator('#modalRoot [name=oferta_id]').count() == 1, 'Nova venda: campo de oferta (aparece quando o produto tem ofertas)')
    pg.evaluate("() => { document.querySelector('#modalRoot').innerHTML = ''; }")
    # ---------------- Integrações: conexões ----------------
    t = front.vai(pg, 'cfg-integracoes', '', 3500)
    chk('Conexões automáticas' in t and 'Facebook Ads e Instagram' in t and 'Google Ads e YouTube' in t and pg.locator('[data-cxcon="meta"]').count() == 1, 'Integrações: cartões do Meta e do Google com "Conectar"')
    cx = sql(f"insert into conexoes (workspace_id, plataforma, status, conta_nome, conectado_em, expira_em, ultima_sincronizacao) values ('{WS}', 'meta', 'conectado', 'Rebecka', now(), now() + interval '50 days', now()) returning id")
    k1 = sql(f"insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome) values ('{WS}', '{cx}', 'meta_ads', 'act_1', 'Conta Escola') returning id")
    sql(f"insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome) values ('{WS}', '{cx}', 'instagram', 'ig1', '@escola')")
    sql(f"insert into ads_externo_vinculos (workspace_id, provedor, campanha_ext, campanha_nome) values ('{WS}', 'meta_ads', 'c9', 'Campanha da plataforma')")
    sql(f"insert into conexao_execucoes (workspace_id, conexao_id, status, registros, terminado_em, disparado_por, detalhe) values ('{WS}', '{cx}', 'ok', 42, now(), 'cron', '{{\"Conta Escola\": \"40 linhas de anúncio\"}}')")
    chamou = []
    ctx.route('http://audit.local/functions/v1/conexoes/**', lambda r: (chamou.append(r.request.url.split('/conexoes/')[1]), r.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'},
        body=json.dumps({'conexoes': [{'status': 'ok', 'registros': 7, 'avisos': []}]} if 'sincronizar' in r.request.url else {'url': 'about:blank#login'}))))
    t = front.vai(pg, 'cfg-integracoes', '', 3500)
    chk('Conectado como Rebecka' in t and 'Conta Escola' in t and '@escola' in t and 'Automático' in t, 'conectado: conta, contas, última sincronização automática')
    chk('Campanha da plataforma' in t and pg.locator('[data-cxvinc]').count() == 1, 'campanha de anúncio sem canal aparece para ligar')
    pg.uncheck(f'[data-cxconta="{k1}"]'); pg.wait_for_timeout(1500)
    chk(sql(f"select sincronizar from conexao_contas where id = '{k1}'") == 'f', 'desmarcar a conta grava "não sincronizar"')
    canal = 'c0195398-3c77-48d5-9621-4f6dae2180e8'
    pg.select_option('[data-cxvinc]', canal); pg.wait_for_timeout(3000)
    chk(sql(f"select campanha_canal_id from ads_externo_vinculos where workspace_id='{WS}' and campanha_ext='c9'") == canal, 'escolher o canal liga a campanha da plataforma')
    pg.click('[data-cxsync="meta"]'); pg.wait_for_timeout(2500)
    chk('sincronizar' in chamou, 'Sincronizar agora chama a função')
    pg.click('[data-cxcon="meta"]'); pg.wait_for_timeout(1500)
    chk('iniciar' in chamou, 'Conectar outra conta pede a URL de login à função')
    pg.goto('file://' + front.SPD + 'audit.html?v=cfg-integracoes&conexao=erro&plataforma=meta&msg=cancelado'); pg.wait_for_timeout(4000)
    chk(pg.evaluate("() => S.view") == 'cfg-integracoes' and pg.evaluate("() => location.search") == '', 'volta do login abre Integrações e limpa o endereço')
    chk('cancelado' in pg.inner_text('body'), 'volta com erro mostra o motivo')
    chk(not [e for e in pg.errs if 'about:blank' not in e], 'sem erro de JavaScript ' + str(pg.errs[:2]))
    ctx.close(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=800)
    front.vai(pg, 'crm-comissoes', "S.com = { aba: 'resumo', mes: '2026-09', pessoa: '', sit: '' }", 3500)
    chk(pg.evaluate("() => document.documentElement.scrollWidth <= innerWidth + 1"), 'celular: Comissões sem rolagem para o lado')
    front.vai(pg, 'cfg-integracoes', '', 3500)
    chk(pg.evaluate("() => document.documentElement.scrollWidth <= innerWidth + 1"), 'celular: Integrações sem rolagem para o lado')
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
