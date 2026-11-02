"""v0.240: Growth's Content → Baú de ideias com microfone. Fala a ideia, o texto aparece, salva como ideia esperando aprovação.
Tela: a aba se chama "Baú de ideias"; com transcrição no navegador, o microfone liga, o texto falado aparece e dá para corrigir;
"Salvar no baú" grava a ideia (status ideia, tag "ideia por voz", título da primeira frase e a fala inteira na descrição) e ela aparece
"esperando aprovação"; sem texto, avisa; sem transcrição no navegador, mostra como ditar pelo teclado; atalho no Kanban da Produção.
Banco fa (Escola Aurora). A transcrição do navegador é simulada. Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots240/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
limpa = lambda: sql(f"delete from conteudos where workspace_id = '{WS}' and 'ideia por voz' = any(tags)")
limpa()
FALA = "Carrossel sobre os três números que todo infoprodutor ignora. Mostrar CAC, LTV e churn com exemplos reais."
MOCK = """window.SpeechRecognition = window.webkitSpeechRecognition = class { start() { this._t = setTimeout(() => { const r = [[{ transcript: %s }]]; r[0].isFinal = true; this.onresult && this.onresult({ results: r }); }, 150); } stop() { clearTimeout(this._t); } };""" % json.dumps(FALA, ensure_ascii=False)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    pg.evaluate("() => { " + MOCK + " }")
    front.vai(pg, 'mkt-cont', "S.ct = S.ct || {}; S.ct.tab = 'ideias';", 4500)
    pg.wait_for_selector('.ct-voz', timeout=15000)
    chk('Baú de ideias' in (pg.text_content('#main .tabs') or ''), 'a aba se chama "Baú de ideias"')
    pg.click('.ct-voz [data-voz-salva]'); pg.wait_for_timeout(400)
    chk('Fale ou escreva a ideia' in (pg.text_content('#toast') or ''), 'sem texto, avisa antes de salvar')
    pg.click('[data-voz-mic]'); pg.wait_for_timeout(500)
    chk(pg.get_attribute('[data-voz-mic]', 'aria-pressed') == 'true' and 'Ouvindo' in (pg.text_content('[data-voz-st]') or ''), 'o microfone liga e diz que está ouvindo')
    v = pg.input_value('[data-voz-tx]'); chk(v == FALA, 'o que foi falado aparece no texto', repr(v) + ' ' + str(pg.evaluate('() => typeof window.webkitSpeechRecognition')))
    pg.screenshot(path=SHOT + '1_falando.png')
    pg.click('[data-voz-mic]'); pg.wait_for_timeout(200)
    chk(pg.get_attribute('[data-voz-mic]', 'aria-pressed') == 'false', 'tocar de novo para de ouvir')
    pg.fill('[data-voz-tx]', FALA + ' Fechar com chamada para o diagnóstico.')
    pg.click('.ct-voz [data-voz-salva]'); pg.wait_for_timeout(3000)
    r = sql(f"select titulo || '|' || status || '|' || coalesce(descricao, '') from conteudos where workspace_id = '{WS}' and 'ideia por voz' = any(tags)")
    chk(r.startswith('Carrossel sobre os três números que todo infoprodutor ignora|ideia|') and r.endswith('chamada para o diagnóstico.'), 'salva como ideia esperando aprovação: título da primeira frase, a fala inteira na descrição', r)
    pg.wait_for_selector('.ct-ideia', timeout=10000)
    chk('Carrossel sobre os três números' in (pg.text_content('#main') or '') and 'esperando aprovação' in (pg.text_content('#main') or ''), 'a ideia aparece no baú, esperando aprovação')
    pg.screenshot(path=SHOT + '2_no_bau.png')
    # sem transcrição no navegador
    pg.evaluate("() => { delete window.webkitSpeechRecognition; delete window.SpeechRecognition; }")
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'ideias';", 4000); pg.wait_for_selector('.ct-voz', timeout=15000)
    chk(pg.locator('[data-voz-mic]').count() == 0 and 'microfone do teclado' in (pg.text_content('.ct-voz') or ''), 'sem transcrição no navegador: explica como ditar pelo teclado do celular')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
