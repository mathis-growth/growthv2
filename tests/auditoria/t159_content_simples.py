"""v0.159/v0.160: Growth's Content (Base do cliente, Linha editorial com subtemas, Identidade visual, Ideias, Produção = Kanban com calendário, Mais ferramentas).
Banco fa com 20261114100000_content_simples.sql. Cria conteúdos de teste no workspace da Escola Aurora e apaga tudo no fim."""
import sys, os, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots159/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    for t in ['content_versoes', 'content_fichas', 'content_identidade', 'conteudo_publicacoes', 'conteudos']: sql(f"delete from {t} where workspace_id = '{WS}'")
    sql(f"delete from conteudo_temas where workspace_id = '{WS}' and tema_pai_id is not null"); sql(f"delete from conteudo_temas where workspace_id = '{WS}'"); sql(f"delete from conteudo_linhas where workspace_id = '{WS}'")
    sql(f"update workspaces set content_setup_em = null, content_ativo = false, content_setup_etapa = 0 where id = '{WS}'")
limpa()
sql(f"update workspaces set content_ativo = true where id = '{WS}'")   # módulo ligado, configuração antiga NÃO concluída
sql(f"""insert into conteudos (workspace_id, titulo, formato, status, hook) values
  ('{WS}', 'Três erros de quem começa a vender curso', 'carrossel', 'ideia', 'Você não precisa de mais seguidores'),
  ('{WS}', 'Bastidores da gravação', 'reels', 'ideia', null),
  ('{WS}', 'Como montar a esteira', 'carrossel', 'ideia', null)""")
LN = sql(f"insert into conteudo_linhas (workspace_id, nome, ordem) values ('{WS}', 'Negócio', 1) returning id").split('\n')[0]
TV = sql(f"insert into conteudo_temas (workspace_id, linha_id, nome) values ('{WS}', '{LN}', 'Vendas') returning id").split('\n')[0]
chk(sql("select has_table_privilege('anon', 'content_fichas', 'select')") == 'f', 'quem não entrou não vê a ficha')
def erro(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-c', q], capture_output=True, text=True); return r.stderr
chk(sql(f"select coalesce((select metodo from conteudo_config where workspace_id = '{WS}'), 'simples')") == 'simples', 'método simples é o padrão')
chk('Escolha o tema' in erro(f"update conteudos set status = 'pauta' where workspace_id = '{WS}' and titulo like 'Bastidores%'"), 'banco: ideia sem tema não é aprovada')
chk('data de publicação' in erro(f"update conteudos set status = 'pauta', tema_id = '{TV}' where workspace_id = '{WS}' and titulo like 'Bastidores%'"), 'banco: ideia sem data de publicação não é aprovada')
chk('Aprove o roteiro' in erro(f"update conteudos set status = 'producao', tema_id = '{TV}', data_publicacao = '2026-11-05' where workspace_id = '{WS}' and titulo like 'Bastidores%'"), 'banco: sem roteiro aprovado não vai para Peça')
chk('Aprove a peça' in erro(f"update conteudos set status = 'pronto', tema_id = '{TV}', data_publicacao = '2026-11-05', roteiro_aprovado_em = now() where workspace_id = '{WS}' and titulo like 'Bastidores%'"), 'banco: sem peça aprovada não fica pronta')
TOAST = "() => [...document.querySelectorAll('.toast, #toast, [role=status]')].map(e => e.textContent).join(' | ')"
def clica(pg, sel, ms=1800): pg.click(sel); pg.wait_for_timeout(ms)
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-26', vw=1440, vh=1000)
    front.vai(pg, 'mkt-cont', "S.ct = undefined;", 5000)
    abas = pg.evaluate("() => [...document.querySelectorAll('#main > .tabs button')].map(b => b.textContent)")
    chk(abas == ['Base do cliente', 'Linha editorial', 'Identidade visual', 'Ideias', 'Produção', 'Mais ferramentas'], 'seis abas, na ordem do trabalho, sem a configuração em 9 passos na frente ' + str(abas))
    chk(pg.locator('.cs-passos').count() == 0 and 'Ficha ainda não aprovada' in pg.inner_text('#main'), 'abre na Base do cliente, avisando que a ficha não foi aprovada')
    chk(pg.evaluate("() => [...document.querySelectorAll('#main button[disabled]')].some(b => /Claude/.test(b.textContent) && /crédito/.test(b.title))"), 'botão da Claude desligado, dizendo o motivo (sem crédito na API)')
    # ---------- ficha ----------
    pg.fill('[data-sec=narrativa]', 'A Escola Aurora ensina a vender curso sem depender de lançamento.')
    clica(pg, '#ctAprova')
    chk(sql(f"select count(*) from content_fichas where workspace_id = '{WS}'") == '0' and 'Para aprovar, preencha' in pg.evaluate(TOAST), 'aprovar com campo obrigatório vazio é recusado e diz o que falta')
    pg.fill('[data-sec=persona]', 'Professora que quer vender o primeiro curso.'); pg.fill('[data-sec=tom]', 'Direto, acolhedor.'); pg.fill('[data-sec=pilares]', 'Vendas\nConteúdo\nBastidores')
    pg.fill('#ctDossie', 'https://drive.google.com/file/d/abc/view')
    clica(pg, '#ctAprova', 2500)
    chk(sql(f"select versao || '|' || status || '|' || (aprovado_por is not null) || '|' || dossie_url from content_fichas where workspace_id = '{WS}'") == '1|aprovada|true|https://drive.google.com/file/d/abc/view', 'ficha aprovada (versão 1, com quem aprovou e o link do dossiê)')
    chk('Ficha aprovada · versão 1' in pg.inner_text('#main'), 'tela mostra a ficha aprovada')
    pg.fill('[data-sec=tom]', 'Direto, acolhedor, sem jargão.'); clica(pg, '#ctSalva', 2500)
    chk(sql(f"select string_agg(versao || ':' || status, ',' order by versao) from content_fichas where workspace_id = '{WS}'") == '1:aprovada,2:rascunho', 'mudar a ficha aprovada cria a versão 2 em rascunho; a 1 continua valendo')
    pg.screenshot(path=SHOT + '1_base.png', full_page=True); erros += pg.errs
    # ---------- linha editorial: subtemas ----------
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'linhas';", 3500)
    chk(pg.locator('#ctSubtemas').count() == 1 and pg.locator('#ctSeg').count() == 1, 'Linha editorial: a tela de antes, mais subtemas e conteúdos por segmento')
    pg.click(f'[data-sub="{TV}"]'); pg.wait_for_timeout(600); pg.fill('#modalRoot textarea[name=lista]', 'Precificação\nLançamento'); clica(pg, '#modalRoot .pri', 2500)
    chk(sql(f"select string_agg(nome, ',' order by nome) from conteudo_temas where tema_pai_id = '{TV}' and ativo") == 'Lançamento,Precificação' and sql(f"select count(*) from conteudo_temas where tema_pai_id = '{TV}' and linha_id = '{LN}'") == '2', 'subtemas criados dentro do tema, herdando a linha')
    pg.click(f'[data-sub="{TV}"]'); pg.wait_for_timeout(600); pg.fill('#modalRoot textarea[name=lista]', 'Precificação\nVendas'); clica(pg, '#modalRoot .pri', 2000)
    chk('já é um tema' in pg.evaluate(TOAST), 'subtema com o nome de um tema é recusado')
    pg.fill('#modalRoot textarea[name=lista]', 'Precificação'); clica(pg, '#modalRoot .pri', 2500)
    chk(sql(f"select string_agg(nome || ':' || ativo, ',' order by nome) from conteudo_temas where tema_pai_id = '{TV}'") == 'Lançamento:false,Precificação:true', 'tirar da lista desativa o subtema (não apaga)')
    SP = sql(f"select id from conteudo_temas where tema_pai_id = '{TV}' and nome = 'Precificação'")
    pg.screenshot(path=SHOT + '0_linha.png', full_page=True); erros += pg.errs
    # ---------- identidade ----------
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'identidade';", 3500)
    clica(pg, '#ctIAprova')
    chk(sql(f"select count(*) from content_identidade where workspace_id = '{WS}'") == '0' and 'fonte do título' in pg.evaluate(TOAST), 'aprovar identidade sem fonte do título é recusado')
    pg.fill('#ctFt', 'Poppins Bold'); pg.fill('#ctFx', 'Inter')
    pg.locator('.ct-cor [data-k=hex]').nth(2).fill('#C64B54'); pg.wait_for_timeout(300)
    chk('rgb(198, 75, 84)' in pg.evaluate("() => getComputedStyle(document.querySelector('.ct-amostra b')).color"), 'prévia muda com a cor de destaque')
    clica(pg, '#ctIAprova', 2500)
    chk(sql(f"select fonte_titulo || '|' || jsonb_array_length(cores) || '|' || (aprovado_em is not null) || '|' || array_to_string(formatos, ',') from content_identidade where workspace_id = '{WS}'") == 'Poppins Bold|3|true|feed,carrossel,story', 'identidade aprovada com cores, fontes e formatos')
    pg.screenshot(path=SHOT + '2_identidade.png', full_page=True); erros += pg.errs
    # ---------- ideias ----------
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'ideias';", 3500)
    chk(pg.locator('.ct-ideia').count() == 3, 'três ideias a avaliar')
    pg.locator('.ct-ideia', has_text='Três erros').locator('[data-ok]').click(); pg.wait_for_timeout(800)
    clica(pg, '#modalRoot .pri', 1500)
    chk(sql(f"select status from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == 'ideia' and pg.locator('#modalRoot select[name=tema_id]:invalid').count() == 1, 'aprovar sem tema é recusado (campo obrigatório)')
    pg.select_option('#modalRoot select[name=tema_id]', TV); pg.wait_for_timeout(300)
    chk(pg.locator('#modalRoot select[name=subtema_id] option').count() == 2, 'subtemas do tema aparecem ao escolher o tema (só os ativos)')
    pg.select_option('#modalRoot select[name=subtema_id]', SP); pg.fill('#modalRoot input[name=prazo]', '2026-10-28')
    clica(pg, '#modalRoot .pri', 1500)
    chk(sql(f"select status from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == 'ideia', 'aprovar sem data de publicação é recusado')
    pg.fill('#modalRoot input[name=data_publicacao]', '2026-10-30'); clica(pg, '#modalRoot .pri', 2500)
    chk(sql(f"select status || '|' || tema_id || '|' || subtema_id || '|' || prazo || '|' || data_publicacao from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == f'pauta|{TV}|{SP}|2026-10-28|2026-10-30', 'ideia aprovada com tema, subtema, prazo e data de publicação')
    pg.locator('.ct-ideia', has_text='Como montar').locator('[data-desc]').click(); pg.wait_for_timeout(2000)
    chk(sql(f"select string_agg(status, ',' order by titulo) from conteudos where workspace_id = '{WS}'") == 'ideia,arquivado,pauta', 'aprovar manda para a Produção; descartar arquiva')
    pg.screenshot(path=SHOT + '3_ideias.png', full_page=True); erros += pg.errs
    # ---------- produção e peça ----------
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban';", 4000)
    chk(pg.locator('.kb-painel').count() == 1 and pg.locator('.kb-cal').count() == 1 and pg.locator('.colk[data-col]').count() == 6, 'Produção = o Kanban de sempre: painel, calendário e as 6 colunas')
    card = pg.locator('.colk[data-col=pauta] .gcard', has_text='Três erros')
    chk(card.count() == 1 and 'roteiro a aprovar' in card.inner_text() and 'Precificação' in card.inner_text() and 'Publica em 30/10/2026' in card.inner_text(), 'cartão na coluna certa, com subtema, data e "roteiro a aprovar"')
    chk('roteiro a aprovar' in pg.inner_text('.colk[data-col=pauta] h3') and 'peça a aprovar' in pg.inner_text('.colk[data-col=producao] h3'), 'colunas dizem o que falta aprovar')
    chk(pg.locator('.kb-d:has-text("30") .kb-dots i').count() >= 1, 'o conteúdo aparece no calendário em 30/10')
    pg.screenshot(path=SHOT + '4_producao.png', full_page=True)
    card.locator('[data-peca]').click(); pg.wait_for_timeout(3000)
    chk('A peça é produzida depois que o roteiro for aprovado' in pg.inner_text('#main'), 'peça bloqueada até o roteiro ser aprovado')
    pg.fill('#ctRot', 'Lâmina 1: Você não precisa de mais seguidores.\nLâmina 2: Erro 1, vender antes de ter oferta.'); clica(pg, '#ctRotOk', 2500)
    chk(sql(f"select status || '|' || (roteiro_aprovado_em is not null) from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == 'producao|true', 'roteiro aprovado: vai para Peça')
    pg.click('.ct-nova summary'); pg.fill('#ctVUrl', 'https://drive.google.com/file/d/v1/view'); clica(pg, '#ctVAdd', 2500)
    pg.fill('#ctAj', 'Fundo mais claro.'); clica(pg, '#ctAjS', 2500)
    pg.click('.ct-nova summary'); pg.fill('#ctVUrl', 'https://drive.google.com/file/d/v2/view'); clica(pg, '#ctVAdd', 2500)
    chk(sql(f"select string_agg(n || ':' || status || ':' || coalesce(ajuste, '-'), ',' order by n) from content_versoes where workspace_id = '{WS}'") == '1:substituida:Fundo mais claro.,2:nova:-', 'versões: ajuste pedido na 1, a 2 substitui a 1')
    clica(pg, '#ctPecaOk', 2500)
    chk(sql(f"select status || '|' || (peca_aprovada_em is not null) || '|' || midia_url from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == 'pronto|true|https://drive.google.com/file/d/v2/view', 'arte aprovada: pronta, com o arquivo da versão aprovada')
    pg.fill('#ctPub', '2026-10-30'); clica(pg, '#ctAgenda', 2500)
    chk(sql(f"select status || '|' || data_publicacao from conteudos where workspace_id = '{WS}' and titulo like 'Três%'") == 'agendado|2026-10-30', 'agendada para 30/10')
    pg.screenshot(path=SHOT + '5_peca.png', full_page=True); erros += pg.errs
    front.vai(pg, 'mkt-cont', "S.ct.peca = null;", 3500)
    card = pg.locator('.colk[data-col=agendado] .gcard', has_text='Três erros')
    chk(card.count() == 1 and '✓ roteiro' in card.inner_text() and '✓ peça' in card.inner_text(), 'de volta ao Kanban: agendada, com roteiro e peça aprovados')
    pg.screenshot(path=SHOT + '4b_producao.png', full_page=True)
    # vídeo: campo do bruto e cortes
    sql(f"update conteudos set status = 'pauta', tema_id = '{TV}', data_publicacao = '2026-11-05' where workspace_id = '{WS}' and titulo like 'Bastidores%'")
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban'; S.ct.peca = null;", 3500)
    pg.locator('.gcard', has_text='Bastidores').locator('[data-peca]').click(); pg.wait_for_timeout(2500)
    pg.fill('#ctRot', 'Abertura: mostrar o estúdio.'); clica(pg, '#ctRotOk', 2500)
    t = pg.inner_text('#main')
    chk(pg.locator('#ctBruto').count() == 1 and 'Cortes e legenda' in t and 'Capa' in t, 'reels: link do vídeo bruto, cortes e legenda, e capa')
    pg.screenshot(path=SHOT + '6_video.png', full_page=True); erros += pg.errs
    # ---------- mais ferramentas ----------
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'plano'; S.ct.peca = null;", 3500)
    chk(pg.evaluate("() => document.querySelector('#main > .tabs .on').textContent") == 'Mais ferramentas' and pg.evaluate("() => document.querySelector('.ct-sub .on').textContent") == 'Semana', 'Semana e as outras abas antigas continuam em Mais ferramentas (atalho antigo abre lá)')
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'linhas';", 3500)
    t = pg.inner_text('#ctSeg')
    chk('Precificação' in t and 'Vendas' in t, 'conteúdos por linha, tema e subtema ' + t.replace('\n', ' | ')[:200])
    erros += pg.errs; ctx.close()
    # ---------- celular ----------
    ctx, pg = front.abre(b, hoje='2026-10-26', vw=390, vh=844)
    for tab in ['base', 'linhas', 'identidade', 'kanban']:
        front.vai(pg, 'mkt-cont', f"S.ct = {{ tab: '{tab}' }};", 3500)
        sw = pg.evaluate('document.documentElement.scrollWidth'); chk(sw <= 396, f'celular ({tab}): nada passa da tela ' + str(sw))
    pg.screenshot(path=SHOT + '7_celular.png', full_page=True); erros += pg.errs; ctx.close()
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
