"""v0.285: copiar para a IA com as referências (links do conteúdo e referências do cliente) e o botão no painel Detalhes, ao lado.
(Base: v0.284.)
Tela: botão "Copiar" no cartão; "Copiar tudo" na barra da seleção (vários, separados por ---); "Copiar tudo para a IA" dentro do conteúdo aberto
(copia o que está escrito na tela, mesmo antes de salvar). O texto traz título, etapa, tema, tipo de mídia, canais, data e os campos preenchidos; campos vazios ficam de fora.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, subprocess; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import front
from playwright.sync_api import sync_playwright
WS = 'ac80a0e2-a34a-46c9-a59d-215f81270c08'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
one = lambda q: sql(q).split('\n')[0]
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from content_identidade where workspace_id = '{WS}'")
    sql(f"delete from conteudos where workspace_id = '{WS}' and titulo like 'T285%'")
    sql(f"delete from conteudo_temas where workspace_id = '{WS}' and nome = 'T285 Tema'")
limpa()
T = one(f"insert into conteudo_temas (workspace_id, nome, ativo) values ('{WS}', 'T285 Tema', true) returning id")
A = one(f"insert into conteudos (workspace_id, titulo, status, tema_id, formato, canais, descricao, hook, roteiro, data_publicacao, tags) values ('{WS}', 'T285 Dados espalhados', 'pauta', '{T}', 'carrossel', '{{instagram}}', 'Por que o infoprodutor não enxerga o próprio negócio.', 'Você vende, mas não sabe quanto custa cada venda.', 'Slide 1: o problema. Slide 2: a virada.', '2026-11-20', '{{educativo}}') returning id")
sql(f"update conteudos set fonte_url = 'https://exemplo.com/estudo', midia_url = 'https://drive.google.com/pasta' where id = '{A}'")
sql(f"insert into content_identidade (workspace_id, referencias, nunca_fazer, cores, fonte_titulo) values ('{WS}', 'https://instagram.com/p/ref1', 'Nunca fundo preto.', '[{{\"nome\":\"Vinho\",\"hex\":\"#521F32\",\"papel\":\"destaque\"}}]', 'Poppins Bold')")
B = one(f"insert into conteudos (workspace_id, titulo, status, descricao) values ('{WS}', 'T285 Segunda ideia', 'ideia', 'Ideia curta.') returning id")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-07', vw=1600, vh=1000)
    ctx.grant_permissions(['clipboard-read', 'clipboard-write'])
    pg.evaluate("() => { window.__cp = null; navigator.clipboard.writeText = t => { window.__cp = t; return Promise.resolve(); }; }")
    front.vai(pg, 'mkt-cont', "S.ct = Object.assign(S.ct || {}, { tab: 'kanban', busca: 'T285' });", 3500)
    cp = lambda: pg.evaluate("() => window.__cp") or ''
    pg.locator(f'.gcard[data-id="{A}"] [data-copia]').click(); pg.wait_for_timeout(500)
    t = cp()
    chk(t.startswith('# T285 Dados espalhados'), 'botão Copiar do cartão: o texto começa pelo título', t[:80])
    chk('- Etapa: Pautas aprovadas' in t and '- Tema: T285 Tema' in t and '- Tipo de mídia: Carrossel' in t and '- Canais: Instagram' in t and '- Data de publicação: 20/11/2026' in t and '- Etiquetas: educativo' in t, 'traz etapa, tema, tipo de mídia, canais, data e etiquetas', t[:400])
    chk('## Descrição e ângulo\nPor que o infoprodutor' in t and '## Gancho\nVocê vende' in t and '## Roteiro\nSlide 1' in t, 'traz a descrição, o gancho e o roteiro, cada um com título')
    chk('## Tese' not in t and '## Problema' not in t, 'campos vazios ficam de fora')
    chk('## Referências e links\n- Fonte da ideia: https://exemplo.com/estudo\n- Link da mídia: https://drive.google.com/pasta' in t, 'v0.285: os links do conteúdo vêm juntos em "Referências e links"', t[-500:])
    chk('# Referências do cliente' in t and 'https://instagram.com/p/ref1' in t and 'Nunca fundo preto.' in t and 'Vinho #521F32 (destaque)' in t and 'título: Poppins Bold' in t, 'v0.285: vêm as referências do cliente (referências aprovadas, o que nunca fazer, cores e fontes)', t[-500:])
    chk('Conteúdo copiado' in (pg.text_content('#toast') or ''), 'avisa "Conteúdo copiado. É só colar na IA."')
    # vários pela barra
    pg.locator(f'.gcard[data-id="{A}"] [data-sel]').check(); pg.locator(f'.gcard[data-id="{B}"] [data-sel]').check()
    pg.click('[data-selcopia]'); pg.wait_for_timeout(500)
    t = cp()
    chk('# T285 Dados espalhados' in t and '# T285 Segunda ideia' in t and '\n\n---\n\n' in t, '"Copiar tudo" na barra copia os marcados, separados por ---', t[:120])
    chk(t.count('# Referências do cliente') == 1 and t.rstrip().endswith('Pasta de identidade') is False, 'com vários, as referências do cliente aparecem uma vez só, no fim')
    chk('2 conteúdos copiados' in (pg.text_content('#toast') or ''), 'avisa quantos foram copiados')
    pg.screenshot(path=os.path.dirname(os.path.abspath(__file__)) + '/shots285_1_barra.png')
    pg.click('[data-sellimpa]'); pg.wait_for_timeout(600)
    # dentro do conteúdo aberto, com texto ainda não salvo
    pg.locator(f'.gcard[data-id="{B}"] [data-edit]').click(); pg.wait_for_timeout(1200)
    chk(pg.locator('.ctd-side [data-copia-mdl]').count() == 1 and pg.locator('.ctd-side [data-copia-mdl]').is_visible(), 'v0.285: o botão "Copiar tudo para a IA" fica no painel Detalhes, ao lado')
    pg.fill('#modalRoot [name=descricao]', 'Ideia reescrita agora, ainda sem salvar.')
    pg.click('[data-copia-mdl]'); pg.wait_for_timeout(500)
    t = cp()
    chk(t.startswith('# T285 Segunda ideia') and 'Ideia reescrita agora, ainda sem salvar.' in t, '"Copiar tudo para a IA" no conteúdo aberto copia o que está na tela, mesmo sem salvar', t[:160])
    chk(sql(f"select descricao from conteudos where id = '{B}'") == 'Ideia curta.', 'copiar não salva nada')
    pg.screenshot(path=os.path.dirname(os.path.abspath(__file__)) + '/shots285_2_janela.png')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
