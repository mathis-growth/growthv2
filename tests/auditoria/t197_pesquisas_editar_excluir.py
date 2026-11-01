"""v0.197: Pesquisas — Editar e Excluir na lista e no topo da pesquisa; excluir avisa o que vai junto; tirar modelo da lista e mostrar de novo.
Banco fa (Escola Aurora), com RODAR_v0.197_pesquisa_modelos.sql. Apaga o que criou."""
import sys, os, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'; NOME = 'Teste t197'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots197/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome like '{NOME}%'"); sql(f"delete from pesquisa_modelos_ocultos where workspace_id = '{WS}'")
limpa()
P1 = sql(f"insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa) values ('{WS}', '{NOME} A', 'lead', 'manual', true) returning id").split('\n')[0]
P2 = sql(f"insert into pesquisas (workspace_id, nome, tipo, gatilho, ativa) values ('{WS}', '{NOME} B', 'lead', 'manual', false) returning id").split('\n')[0]
Q = sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, papel, obrigatoria) values ('{WS}', '{P1}', 1, 'Nota?', 'texto', '{{}}', 'livre', true) returning id").split('\n')[0]
for i in range(3):
    R = sql(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, email) values ('{WS}', '{P1}', 't197.{i}@exemplo.com.br') returning id").split('\n')[0]
    sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{R}', '{Q}', 'ok')")
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'gro-pesq', "S.pqSel = null;", 4000)
    chk(pg.locator(f'[data-pqe="{P1}"]').count() == 1 and pg.locator(f'[data-pqx="{P1}"]').count() == 1, 'cada pesquisa da lista tem Editar e Excluir')
    pg.screenshot(path=SHOT + '1_lista.png')
    pg.click(f'[data-pqe="{P1}"]'); pg.wait_for_timeout(1500)
    chk(pg.locator('#modalRoot h2').inner_text() == 'Editar pesquisa' and pg.evaluate("S.pqSel") is None, 'Editar abre a edição sem sair da lista')
    pg.fill('#modalRoot [name=nome]', NOME + ' A editada'); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select nome from pesquisas where id = '{P1}'") == NOME + ' A editada', 'a edição grava')
    pg.click(f'[data-pqx="{P1}"]'); pg.wait_for_timeout(1500)
    t = pg.inner_text('#modalRoot')
    chk('3 resposta(s)' in t and 'Não dá para desfazer' in t, 'Excluir avisa quantas respostas vão junto')
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '2_excluir.png')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(500)
    chk(sql(f"select count(*) from pesquisas where id = '{P1}'") == '1', 'Cancelar não exclui')
    # excluir pelo topo da pesquisa
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P2}'; S.pqTab = 'perguntas';", 4000)
    chk(pg.locator('#pqEd').inner_text() == 'Editar pesquisa' and pg.locator('#pqDel').count() == 1, 'no topo da pesquisa: Editar pesquisa e Excluir')
    pg.click('#pqDel'); pg.wait_for_timeout(1200)
    chk('ainda não tem respostas' in pg.inner_text('#modalRoot'), 'pesquisa sem respostas: o aviso diz isso')
    pg.click('#modalRoot button.pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select count(*) from pesquisas where id = '{P2}'") == '0' and pg.evaluate("S.pqSel") is None, 'excluir apaga e volta para a lista')
    # modelos
    front.vai(pg, 'gro-pesq', "S.pqSel = null;", 4000)
    chk(pg.locator('#pqModelo option[value=nsm]').count() == 1, 'modelo NSM está na lista')
    pg.click('#pqModelos'); pg.wait_for_timeout(1200)
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '3_modelos.png')
    pg.click('#modalRoot [data-pqmx="nsm"]'); pg.wait_for_timeout(2500)
    chk(sql(f"select count(*) from pesquisa_modelos_ocultos where workspace_id = '{WS}' and modelo = 'nsm'") == '1', 'Excluir da lista grava no banco (vale para a equipe)')
    chk(pg.locator('#modalRoot [data-pqmv="nsm"]').count() == 1, 'o modelo aparece como "fora da lista", com Mostrar de novo')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(1500)
    chk(pg.locator('#pqModelo option[value=nsm]').count() == 0, 'some de "Começar de um modelo"')
    pg.click('#pqModelos'); pg.wait_for_timeout(1200); pg.click('#modalRoot [data-pqmv="nsm"]'); pg.wait_for_timeout(2500); pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(1500)
    chk(pg.locator('#pqModelo option[value=nsm]').count() == 1, 'Mostrar de novo devolve o modelo à lista')
    erros += pg.errs; chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
