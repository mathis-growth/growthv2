"""v0.149: ficha de conteúdo de cada produto na Estratégia de conteúdo; ideia ligada a um produto.
Banco fa com 20261109100000_content_produtos.sql. Escola Aurora (3 produtos). Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots149/'
import os; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def como(q):
    claims = json.dumps({'sub': front.UID, 'role': 'authenticated', 'email': 'auditoria@escolaaurora.com.br'})
    return sql(f"select set_config('request.jwt.claims', '{claims}', false); set role authenticated; {q}").split('\n')[-1]
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from content_produto_fichas where workspace_id = '{WS}'")
    for t in ['conteudo_publicacoes', 'conteudos', 'conteudo_config']: sql(f"delete from {t} where workspace_id = '{WS}'")
    sql(f"update workspaces set content_setup_em = null, content_ativo = false where id = '{WS}'")
limpa()
CB = sql(f"select id from produtos where workspace_id = '{WS}' and nome = 'Curso Base'")
MG = sql(f"select id from produtos where workspace_id = '{WS}' and nome = 'Mentoria em grupo'")

# ---------- banco ----------
try: como(f"select content_produto_ficha_salvar('{CB}', '{{\"senha\":\"x\"}}'::jsonb)"); chk(False, 'campo desconhecido na ficha é recusado')
except Exception as e: chk('Campo desconhecido' in str(e), 'campo desconhecido na ficha é recusado')
try: como(f"select content_produto_ficha_salvar('{CB}', '{{\"momento\":\"sempre\"}}'::jsonb)"); chk(False, 'momento de venda inválido é recusado')
except Exception as e: chk('Momento de venda inválido' in str(e), 'momento de venda inválido é recusado')
try: como(f"insert into content_produto_fichas (produto_id, workspace_id) values ('{CB}', '{WS}')"); chk(False, 'ficha só pela função')
except Exception as e: chk('permission' in str(e).lower(), 'ficha só pela função (sem gravar direto)')
chk(sql("select has_function_privilege('anon', 'content_produto_ficha_salvar(uuid, jsonb)', 'execute')") == 'f', 'quem não entrou não grava ficha')

# ---------- telas ----------
sql(f"update workspaces set content_setup_em = now(), content_ativo = true where id = '{WS}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1100)
    t = front.vai(pg, 'mkt-cont', "S.ct = { tab: 'produtos' };", 3500)
    chk(pg.locator('.pf-card').count() == 3 and 'Curso Base' in t and 'Sem a ficha de conteúdo ainda' in t and '0%' in t, 'aba Produtos: os 3 produtos do cadastro, sem ficha')
    pg.click(f'[data-pfe="{CB}"]'); pg.wait_for_timeout(800)
    campos = {'frase': 'Curso para destravar o inglês em 90 dias', 'para_quem': 'Adultos que estudaram e travam na conversa', 'dor': 'Entendo mas não consigo falar',
              'transformacao': 'Conversar com segurança no trabalho', 'metodo': 'Método Aurora: ouvir, repetir, conversar', 'entregaveis': 'Aulas gravadas e encontros ao vivo',
              'diferenciais': 'Foco em conversa desde a primeira aula', 'provas': '200 alunos com certificado', 'objecoes': 'Não tenho tempo | 20 minutos por dia\nJá tentei e desisti | Encontros ao vivo semanais',
              'cta': 'Comenta INGLÊS', 'pagina_vendas': 'escolaaurora.com.br/curso'}
    for k, v in campos.items(): pg.fill(f'#modalRoot [name={k}]', v)
    pg.select_option('#modalRoot [name=momento]', 'lancamento'); pg.select_option('#modalRoot [name=consciencia]', 'problema')
    pg.screenshot(path=SHOT + '1_ficha.png')
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    f = json.loads(sql(f"select ficha from content_produto_fichas where produto_id = '{CB}'"))
    chk(f.get('momento') == 'lancamento' and f.get('pagina_vendas') == 'https://escolaaurora.com.br/curso' and len(f) == 13, 'ficha gravada (link completado com https) ' + str(len(f)))
    t = pg.inner_text(f'.pf-card:has-text("Curso Base")')
    chk('100%' in t and 'Curso para destravar' in t and 'Lançamento' in t, 'cartão mostra a frase, o momento e 100% dos campos principais')
    pg.click(f'[data-pfv="{CB}"]'); pg.wait_for_timeout(1200)
    t = pg.inner_text('.pf-ler')
    chk('Objeções' in t and '20 minutos por dia' in t and pg.locator('.pf-obj li').count() == 2 and 'Consciente do problema' in t, 'ver ficha: leitura por seções, objeção com resposta')
    pg.screenshot(path=SHOT + '2_lista.png')
    pg.click(f'[data-pfi="{MG}"]'); pg.wait_for_timeout(800)
    chk(pg.input_value('#modalRoot [name=produto_id]') == MG, 'nova ideia sobre o produto já vem com o produto escolhido')
    pg.fill('#modalRoot [name=titulo]', 'Por que mentoria em grupo acelera'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select produto_id from conteudos where titulo = 'Por que mentoria em grupo acelera'") == MG, 'a ideia fica ligada ao produto')
    chk('1 ideia(s) ou pauta(s)' in pg.inner_text(f'.pf-card:has-text("Mentoria em grupo")'), 'o cartão do produto conta os conteúdos ligados')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
