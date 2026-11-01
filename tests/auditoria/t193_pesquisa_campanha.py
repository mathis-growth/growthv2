"""v0.193: pesquisa na campanha — passo 4 da nova campanha, painel na aba Planejamento e metas, código da página de obrigado
(iframe que ajusta a altura) e leads da campanha na fila de envio. Banco fa (Escola Aurora). Apaga o que criou no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
NOME = 'Teste t193 · Pesquisa'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots193/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
CAMP2 = sql(f"select id from campanhas where workspace_id = '{WS}' and nome = 'Lançamento Setembro'")
EX0 = sql(f"select coalesce(extras::text, 'null') from campanhas where id = '{CAMP2}'")
def limpa():
    ids = sql(f"select coalesce(string_agg(quote_literal(id::text), ','), 'null') from pesquisas where workspace_id = '{WS}' and nome like '%{NOME}%'")
    sql(f"delete from pesquisa_envios where pesquisa_id in ({ids})")
    sql(f"delete from pesquisa_perguntas where pesquisa_id in ({ids})"); sql(f"delete from pesquisas where id in ({ids})")
    for t in ['campanha_canais', 'campanha_etapas', 'campanha_estrategias']:
        try: sql(f"delete from {t} where campanha_id in (select id from campanhas where workspace_id = '{WS}' and nome = '{NOME}')")
        except Exception: pass
    sql(f"delete from projetos where campanha_id in (select id from campanhas where workspace_id = '{WS}' and nome = '{NOME}')")
    sql(f"delete from campanhas where workspace_id = '{WS}' and nome = '{NOME}'")
limpa()
PESQ_EX = sql(f"insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa) values ('{WS}', 'Pesquisa existente {NOME}', 'lead', 'manual', false) returning id").split('\n')[0]
sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, papel, obrigatoria) values ('{WS}', '{PESQ_EX}', 1, 'O que você mais quer aprender?', 'texto', '{{}}', 'livre', true)")
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-31', vw=1440, vh=1000)
    # ---------- assistente: 4 passos, o último é Pesquisa ----------
    front.vai(pg, 'mkt-camp', "S.tabMkt = 'campanhas'; S.campSel = null;", 5000)
    pg.click('#novaCamp'); pg.wait_for_timeout(1500)
    chk(pg.locator('.wzp > div').count() == 4 and 'Pesquisa' in pg.inner_text('.wzp'), 'nova campanha tem 4 passos, o último é Pesquisa')
    pg.fill('.wz [name=nome]', NOME); pg.select_option('.wz [name=modelo]', 'lancamento')
    pg.select_option('.wz [name=produto_id]', index=1)
    pg.fill('.wz [name=data_inicio]', '2026-11-01'); pg.fill('.wz [name=data_fim]', '2026-11-30')
    pg.click('.wz button.pri'); pg.wait_for_timeout(2500)
    pg.click('.wz button.pri'); pg.wait_for_timeout(2000)   # orçamento (vazio)
    pg.click('.wz button.pri'); pg.wait_for_timeout(2500)   # canais (nenhum)
    chk(pg.locator('.wz [data-cpq]').count() == 1 and pg.locator('.wz .cpq-det').is_hidden(), 'passo 4: pergunta "Vai usar pesquisa?" com o resto escondido')
    pg.check('.wz [name=cpq_usa][value=sim]'); pg.wait_for_timeout(200)
    chk(pg.locator('.wz .cpq-det').is_visible(), 'marcar Sim mostra a escolha da pesquisa e de onde ela entra')
    opts = pg.evaluate("[...document.querySelectorAll('.wz [name=cpq_pesq] optgroup')].map(g => g.label)")
    chk(opts == ['Pesquisas que já existem', 'Criar a partir de um modelo pronto', 'Criar do zero'], 'opções: pesquisas existentes, modelos prontos e nova ' + str(opts))
    pg.screenshot(path=SHOT + '1_passo4.png')
    pg.click('.wz button.pri'); pg.wait_for_timeout(1500)
    chk(pg.locator('.wz').count() == 1 and pg.locator('.toast.err, .toast.erro, #toasts .err').count() + 1 > 0, 'sem escolher a pesquisa não conclui')
    pg.select_option('.wz [name=cpq_pesq]', 'm:lead'); pg.check('.wz [name=cpq_obrigado]'); pg.check('.wz [name=cpq_disparo]'); pg.wait_for_timeout(200)
    chk(pg.locator('.wz .cpq-disp').is_visible() and 'ainda não está ligado' in pg.inner_text('.wz .cpq-disp'), 'disparo: quando e por onde, com o aviso de que o automático ainda não está ligado')
    pg.select_option('.wz [name=cpq_canal]', 'whatsapp')
    pg.screenshot(path=SHOT + '2_passo4_preenchido.png')
    pg.click('.wz button.pri'); pg.wait_for_timeout(4500)
    c = json.loads(sql(f"select json_build_object('id', id, 'ex', extras) from campanhas where workspace_id = '{WS}' and nome = '{NOME}'"))
    cfg = (c['ex'] or {}).get('pesquisa', {})
    chk(cfg.get('usa') and cfg.get('obrigado') and cfg.get('disparo') and not cfg.get('captacao') and cfg.get('quando') == 'cadastro' and cfg.get('canal') == 'whatsapp', 'escolha gravada na campanha ' + str({k: cfg.get(k) for k in ['usa', 'obrigado', 'disparo', 'quando', 'canal']}))
    p = json.loads(sql(f"select json_build_object('nome', nome, 'aceita', aceita_link_aberto, 'canal', canal_envio, 'ativa', ativa, 'n', (select count(*) from pesquisa_perguntas where pesquisa_id = p.id)) from pesquisas p where id = '{cfg.get('pesquisa_id')}'"))
    chk(p['nome'].startswith('Lead: qualificação') and NOME in p['nome'] and p['n'] > 0 and p['aceita'] and p['canal'] == 'whatsapp' and not p['ativa'], 'pesquisa criada do modelo, com o nome da campanha, link aberto ligado, canal WhatsApp e desativada ' + str(p))
    # ---------- painel na aba Planejamento e metas ----------
    front.vai(pg, 'mkt-camp', f"S.tabMkt = 'campanhas'; S.campSel = '{c['id']}'; S.campTab = 'resumo';", 6000)
    t = pg.inner_text('#cpqPainel')
    chk('Pesquisa da campanha' in t and 'na página de obrigado' in t and 'em disparo' in t and 'desativada' in t, 'painel: qual pesquisa, onde entra e o aviso de desativada')
    code = pg.inner_text('#cpqCode')
    chk('<iframe' in code and '?pesquisa=' in code and 'utm_medium=obrigado' in code and 'growthsPesquisa' in code and '</script>' in code, 'código da página de obrigado: iframe com o link aberto, a origem e o ajuste de altura')
    pg.locator('#cpqPainel').screenshot(path=SHOT + '3_painel.png')
    # ---------- campanha que já existe: escolher uma pesquisa existente e colocar os leads na fila ----------
    sql(f"update pesquisas set ativa = true where id = '{PESQ_EX}'")
    front.vai(pg, 'mkt-camp', f"S.tabMkt = 'campanhas'; S.campSel = '{CAMP2}'; S.campTab = 'resumo';", 6000)
    chk('não usa pesquisa' in pg.inner_text('#cpqPainel'), 'campanha sem pesquisa: painel convida a configurar')
    pg.click('#cpqPainel [data-cpq-cfg]'); pg.wait_for_timeout(1500)
    pg.check('#modalRoot [name=cpq_usa][value=sim]'); pg.select_option('#modalRoot [name=cpq_pesq]', PESQ_EX)
    pg.check('#modalRoot [name=cpq_captacao]'); pg.check('#modalRoot [name=cpq_disparo]'); pg.select_option('#modalRoot [name=cpq_quando]', 'etapa'); pg.wait_for_timeout(200)
    chk(pg.locator('#modalRoot .cpq-et').is_visible(), 'disparo "quando entra numa etapa" pede a etapa')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(1200)
    chk(pg.locator('#modalRoot .modal').count() == 1, 'sem a etapa não salva')
    pg.select_option('#modalRoot [name=cpq_etapa]', index=1); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(5000)
    leads = int(sql(f"select count(*) from pessoas where campanha_id = '{CAMP2}'"))
    t = pg.inner_text('#cpqPainel')
    chk('Captação' in t and pg.locator('#cpqPainel .cpq-lk').count() >= 1 and 'utm_campaign=' in pg.inner_text('#cpqPainel .cpq-lk >> nth=0'), 'captação: link de inscrição por canal, com UTM')
    chk(f'Colocar {leads} lead(s) na fila' in t or f'Colocar {leads:,}'.replace(',', '.') in t, f'disparo: botão para colocar os {leads} leads da campanha na fila')
    pg.click('#cpqPainel [data-cpq-gera]'); pg.wait_for_timeout(5000)
    n = int(sql(f"select count(*) from pesquisa_envios where pesquisa_id = '{PESQ_EX}' and pessoa_id in (select id from pessoas where campanha_id = '{CAMP2}')"))
    chk(n == leads, f'os {leads} leads da campanha entraram na fila da pesquisa ({n})')
    chk('Colocar 0 lead(s)' in pg.inner_text('#cpqPainel'), 'depois disso, ninguém fica fora da fila')
    pg.locator('#cpqPainel').screenshot(path=SHOT + '4_painel_fila.png')
    pg.click('#cpqPainel [data-cpq-fila]'); pg.wait_for_timeout(4000)
    chk(pg.evaluate("S.view === 'gro-pesq' && S.pqTab === 'envios'"), '"Abrir a fila de envio" leva à fila da pesquisa')
    erros += pg.errs
    # ---------- o código colado numa página: a pesquisa aparece e a altura se ajusta ----------
    tok = sql(f"select token_aberto from pesquisas where id = '{PESQ_EX}'")
    app = front.html()
    pagina = SHOT + 'obrigado.html'
    open(pagina, 'w').write('<!doctype html><meta charset="utf-8"><body style="margin:0;background:#eee"><h1>Obrigado!</h1>' + code.replace(code[code.index('src="') + 5:code.index('"', code.index('src="') + 5)], 'file://' + app + '?pesquisa=' + tok + '&utm_medium=obrigado') + '</body>')
    pg2 = ctx.new_page(); pg2.errs = []; pg2.on('pageerror', lambda e: pg2.errs.append(str(e)))
    pg2.goto('file://' + pagina); pg2.wait_for_timeout(6000)
    fr = pg2.frame_locator('iframe')
    h = pg2.evaluate("document.querySelector('iframe').getBoundingClientRect().height")
    chk(fr.locator('#pubPesq .pf-card, #pubPesq section').count() >= 1, 'a pesquisa aparece dentro da página de obrigado')
    chk(400 < h < 1400, 'a altura do iframe acompanha o conteúdo da pesquisa (%s px)' % h)
    pg2.screenshot(path=SHOT + '5_obrigado.png', full_page=True)
    erros += pg2.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
# volta tudo
sql(f"update campanhas set extras = {'null' if EX0 == 'null' else chr(39) + EX0.replace(chr(39), chr(39) * 2) + chr(39) + '::jsonb'} where id = '{CAMP2}'")
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
