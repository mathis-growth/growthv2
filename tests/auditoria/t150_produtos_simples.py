"""v0.150: ficha de produto simples (produto, valor, histórico) no Growth's Content; ideia ligada ao produto;
perguntas de produto e esteira no questionário da call. Banco fa com 20261110100000_content_produtos_v2.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots150/'
import os; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    for t in ['conteudo_publicacoes', 'conteudos', 'content_produtos', 'conteudo_config', 'conteudo_personas']: sql(f"delete from {t} where workspace_id = '{WS}'")
    sql(f"update workspaces set content_setup_em = null, content_ativo = false, content_setup_etapa = 0 where id = '{WS}'")
limpa()
chk(sql("select to_regclass('public.content_produto_fichas') is null") == 't', 'a ficha longa da v0.149 saiu do banco')
chk(sql("select has_table_privilege('anon', 'content_produtos', 'select')") == 'f', 'quem não entrou não vê os produtos')
sql(f"update workspaces set content_setup_em = now(), content_ativo = true where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    t = front.vai(pg, 'mkt-cont', "S.ct = { tab: 'produtos' };", 3500)
    chk('3 produto(s) no cadastro comercial' in t and 'Nenhum produto ainda' in t and pg.locator('#prNovo').count() == 1, 'sem produtos: oferece trazer do cadastro e criar um novo')
    pg.click('#prTraz'); pg.wait_for_timeout(2500)
    chk(sql(f"select count(*) || '|' || sum(valor)::int from content_produtos where workspace_id = '{WS}'") == '3|4044', 'trazer do cadastro: nome e valor dos 3 produtos')
    pg.click('#prNovo'); pg.wait_for_timeout(800)
    chk(pg.locator('#modalRoot input, #modalRoot textarea, #modalRoot select').count() == 3, 'ficha simples: só produto, valor e histórico')
    pg.fill('#modalRoot [name=nome]', 'Imersão presencial'); pg.fill('#modalRoot [name=valor]', '1500')
    hist = 'Criada em 2025 depois da mentoria. Três turmas, 40 alunos no total.\nA próxima turma abre em março.'
    pg.fill('#modalRoot [name=historico]', hist)
    pg.screenshot(path=SHOT + '1_ficha.png')
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select valor::int || '|' || historico from content_produtos where nome = 'Imersão presencial'") == '1500|' + hist, 'produto novo salvo com valor e histórico')
    t = pg.inner_text('.pf-card:has-text("Imersão presencial")').replace('\xa0', ' ')
    chk('R$ 1.500,00' in t and 'Três turmas' in t, 'cartão mostra valor e histórico')
    IM = sql("select id from content_produtos where nome = 'Imersão presencial'")
    pg.click(f'[data-pfi="{IM}"]'); pg.wait_for_timeout(800)
    chk(pg.input_value('#modalRoot [name=produto_id]') == IM, 'nova ideia sobre o produto já vem com ele')
    pg.fill('#modalRoot [name=titulo]', 'O que acontece numa imersão'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk(sql("select produto_id from conteudos where titulo = 'O que acontece numa imersão'") == IM and '1 ideia(s) ou pauta(s)' in pg.inner_text('.pf-card:has-text("Imersão presencial")'), 'a ideia fica ligada ao produto e o cartão conta')
    pg.click(f'[data-pre="{IM}"]'); pg.wait_for_timeout(800); pg.uncheck('#modalRoot [name=ativo]'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk('Produtos inativos' in pg.inner_text('#main') and sql(f"select ativo from content_produtos where id = '{IM}'") == 'f', 'desativar leva para Produtos inativos')
    pg.screenshot(path=SHOT + '2_lista.png')
    # questionário da call
    sql(f"update workspaces set content_setup_em = null where id = '{WS}'")
    front.vai(pg, 'mkt-cont', "S.ct = { csEtapa: 4, csBloco: 2 };", 3500)
    t = pg.inner_text('#main')
    chk('3. Produtos' in t and 'Como funciona a sua esteira hoje' in t and 'Quais produtos ou serviços você tem hoje' in t, 'call de briefing: bloco Produtos e esteira com as perguntas novas')
    pg.fill('#cc_esteira', 'Entra pelo e-book, depois curso e mentoria'); pg.wait_for_timeout(2200)
    chk('Entra pelo e-book' in sql(f"select respostas->>'esteira' from conteudo_personas where workspace_id = '{WS}'"), 'resposta da esteira salva sozinha')
    pg.screenshot(path=SHOT + '3_call_produtos.png')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
