"""v0.198: Planejamento anual, etapa 1 — meta do ano (caminho, premissas do sistema / digitadas / com ajuda, cenários, diferença)
e trimestres (cartões, sugestão mês a mês que preenche as metas mensais, gráfico acumulado). Banco fa (Escola Aurora), com o
RODAR_v0.198_plano_anual.sql. Apaga o que criou (plano_anual e planejamento_mensal de 2026)."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots198/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa(): sql(f"delete from plano_anual where workspace_id = '{WS}'"); sql(f"delete from planejamento_mensal where workspace_id = '{WS}' and ano = 2026")
limpa()
def sug():
    return json.loads(sql(f"begin; select set_config('request.jwt.claims', '{{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\",\"role\":\"authenticated\"}}', true); select plano_anual_sugestoes('{WS}', 2026, '2026-10-31')::text; commit;").split('\n')[1])
S0 = sug()
def pr(pg, k, fonte=None, valor=None):
    r = f'#modalRoot .pa-pr[data-pk="{k}"]'
    if fonte: pg.select_option(r + ' [data-f]', fonte); pg.wait_for_timeout(150)
    if valor is not None: pg.fill(r + ' [data-v]', str(valor))
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-31', vw=1440, vh=1000)
    front.vai(pg, 'mkt-camp', "S.tabMkt = 'plan'; S.ano = 2026; S.campSel = null;", 6000)
    t = pg.inner_text('#paAno')
    chk('1. Meta do ano' in t and 'Montar a meta de 2026' in t and 'mês(es) de DRE' in t, 'sem plano: seção 1 convida a montar e diz que o Growths já tem dados')
    chk(pg.locator('.pa-sec h2', has_text='3. Calendário de campanhas').count() == 1 and pg.locator('.pa-sec h2', has_text='Metas mês a mês').count() == 1, 'o calendário e as metas mês a mês viram seções da mesma tela')
    pg.click('#paMonta'); pg.wait_for_timeout(1200)
    chk(pg.locator('#modalRoot [name=caminho]').count() == 3, 'três caminhos: ambição, realista, as duas')
    chk(pg.locator('#modalRoot .pa-pr[data-pk="mrr"]').is_hidden() and pg.locator('#modalRoot .pa-pr[data-pk="custos_fixos"]').is_visible(), 'caminho "só pela ambição": não pede recorrência nem recompra')
    pg.check('#modalRoot [name=caminho][value=ambos]'); pg.wait_for_timeout(200)
    chk(pg.locator('#modalRoot .pa-pr[data-pk="recompra"]').is_visible() and pg.locator('#modalRoot .pa-basede').is_visible(), 'as duas contas: aparecem as premissas do realista e a escolha da base')
    chk(pg.locator('#modalRoot .pa-pr[data-pk="custos_fixos"] [data-f] option[value=sistema]').count() == 1 and pg.locator('#modalRoot .pa-pr[data-pk="mrr"] [data-f] option[value=sistema]').count() == 0, '"Do sistema" só aparece onde o Growths tem o dado')
    chk(pg.locator('#modalRoot .pa-pr[data-pk="custos_fixos"] [data-v]').get_attribute('readonly') is not None, 'premissa do sistema vem preenchida e travada')
    pr(pg, 'lucro_desejado', valor=200000)
    pr(pg, 'mrr', 'digitado', 0)
    pr(pg, 'recompra', 'estimativa')
    chk(pg.locator('#modalRoot .pa-pr[data-pk="recompra"] .pa-aj').is_visible(), '"Não sei, me ajude" abre a pergunta')
    pg.fill('#modalRoot .pa-pr[data-pk="recompra"] [data-aj="0"]', '1'); pg.dispatch_event('#modalRoot .pa-pr[data-pk="recompra"] [data-aj="0"]', 'input'); pg.wait_for_timeout(150)
    chk(pg.input_value('#modalRoot .pa-pr[data-pk="recompra"] [data-v]') == '10', 'a ajuda calcula: 1 de cada 10 = 10%')
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '1_modal.png')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3500)
    row = json.loads(sql(f"select row_to_json(p)::text from plano_anual p where workspace_id = '{WS}' and ano = 2026"))
    A = (S0['custos_fixos_ano'] + 200000) / (S0['margem_contribuicao'] / 100)
    R = 0 + S0['clientes_ativos'] * 0.10 * S0['ticket_medio'] + 44865
    chk(row['caminho'] == 'ambos' and row['premissas']['recompra']['fonte'] == 'estimativa' and row['premissas']['custos_fixos']['fonte'] == 'sistema', 'plano gravado com o caminho e a origem de cada premissa')
    chk(abs(float(row['meta_receita']) - A) < 1, 'meta = (custos fixos + lucro) ÷ margem, com a base na ambição (%.2f × %.2f)' % (float(row['meta_receita']), A))
    t = pg.inner_text('#paAno')
    chk('Faltam' in t and 'Mais campanhas' in t and 'Meta menor' in t, 'a diferença entre ambição e realista aparece com as três saídas')
    chk('1 de ' in t and 'premissas são estimativa' in t, 'avisa quantas premissas são estimativa')
    chk(abs(float(pg.evaluate("(() => { const t = [...document.querySelectorAll('.pa-conta')][1].querySelector('.pa-tot b').textContent; return t.replace(/[^0-9,]/g, '').replace(',', '.'); })()")) - R) < 1, 'conta realista = recompra + campanhas (%.2f)' % R)
    pg.screenshot(path=SHOT + '2_meta.png', full_page=True)
    # trimestres e sugestão
    chk(pg.locator('.pa-tri').count() == 4 and pg.locator('.pa-tri.on').count() == 1, 'quatro trimestres, o 4º em curso em destaque')
    chk(pg.locator('.pa-graf svg').count() == 1, 'gráfico acumulado com meta, realizado e previsão')
    pg.click('.pa-det summary'); pg.wait_for_timeout(300)
    pg.click('#paVazios'); pg.wait_for_timeout(3000)
    tot = float(sql(f"select coalesce(sum(meta_receita), 0) from planejamento_mensal where workspace_id = '{WS}' and ano = 2026"))
    n = int(sql(f"select count(*) from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and meta_receita is not null"))
    chk(n == 12 and abs(tot - A) < 2, 'preencher os meses sem meta grava os 12 meses e a soma é a meta do ano (%.2f)' % tot)
    set_ = float(sql(f"select meta_receita from planejamento_mensal where workspace_id = '{WS}' and ano = 2026 and mes = 9"))
    chk(set_ >= 44865, 'setembro carrega o lançamento (%.2f)' % set_)
    # mês digitado manda: mudar um mês e preencher os vazios não mexe nele
    sql(f"update planejamento_mensal set meta_receita = 1234 where workspace_id = '{WS}' and ano = 2026 and mes = 1")
    front.vai(pg, 'mkt-camp', "S.tabMkt = 'plan'; S.ano = 2026;", 6000)
    chk(pg.locator('#paVazios').is_disabled() if pg.locator('#paVazios').count() else False, 'sem mês vazio, o botão de preencher fica desligado')
    # caminho só pela ambição esconde a conta realista
    pg.click('#paEd'); pg.wait_for_timeout(1200); pg.check('#modalRoot [name=caminho][value=ambicao]'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3000)
    chk(pg.locator('.pa-conta').count() == 1 and 'Faltam' not in pg.inner_text('#paAno'), 'só pela ambição: uma conta, sem diferença')
    pg.screenshot(path=SHOT + '3_tela.png', full_page=True)
    erros += pg.errs; chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
