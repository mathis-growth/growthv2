"""v0.141: o que o cliente acessa (árvore com setinhas no Novo cliente) e o Growth's Content decidido pelo acesso.
Banco fa com 20261102100000_content_drive.sql e 20261103100000_acesso_content.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome like 'T141 %'")
limpa()

# ---------- banco ----------
chk(sql("select string_agg(tela || ':' || grupo, ',' order by tela) from acesso_telas where tela in ('mkt-cont', 'mkt-insta', 'crm-dms')") == "crm-dms:Vendas,mkt-cont:Marketing / Growth's Content,mkt-insta:Marketing / Growth's Content", 'catálogo: Growth\'s Content dentro de Marketing; DMs em Vendas')
W = sql("insert into workspaces (nome) values ('T141 Livre') returning id").split('\n')[0]
chk(sql(f"select content_ativo from workspaces where id = '{W}'") == 'f', 'cliente sem restrição não liga o módulo sozinho')
sql(f"update workspaces set acesso_liga = array['mkt-cont', 'mkt-insta'], acesso_desliga = (select array_agg(tela) from acesso_telas where tela not in ('mkt-cont', 'mkt-insta')) where id = '{W}'")
chk(sql(f"select content_ativo || '|' || coalesce(content_drive_status, '-') from workspaces where id = '{W}'") in ('true|erro', 'true|criando'), 'acesso com o Growth\'s Content liga o módulo e pede a pasta')
chk(sql(f"select array_to_string(acesso_telas_ws('{W}'), ',')").split(',').__len__() == 4 and 'mkt-insta' in sql(f"select array_to_string(acesso_telas_ws('{W}'), ',')"), 'cliente só com Growth\'s Content vê Estratégia, Instagram e as telas de equipe')
sql(f"update workspaces set acesso_liga = array['crm-leads'], acesso_desliga = (select array_agg(tela) from acesso_telas where tela <> 'crm-leads') where id = '{W}'")
chk(sql(f"select content_ativo from workspaces where id = '{W}'") == 'f', 'tirar o Growth\'s Content do acesso desliga o módulo')
pid = sql("insert into pacotes_acesso (nome, telas) values ('T141 Pacote', array['mkt-cont', 'mkt-insta', 'mkt-dash']) returning id").split('\n')[0]
sql(f"update workspaces set pacote_id = '{pid}', acesso_liga = '{{}}', acesso_desliga = '{{}}' where id = '{W}'")
chk(sql(f"select content_ativo from workspaces where id = '{W}'") == 't', 'pacote com o Growth\'s Content também liga o módulo')

# ---------- telas ----------
AG = sql("insert into workspaces (nome, agencia) values ('T141 Agência', true) returning id").split('\n')[0]
sql(f"insert into workspace_membros (workspace_id, user_id, papel) values ('{AG}', '{front.UID}', 'admin')")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    front.vai(pg, 'adm-painel', '', 2500)
    pg.evaluate("document.getElementById('novoCli').style.display = ''"); pg.click('#novoCli'); pg.wait_for_timeout(1500)
    t = pg.inner_text('#modalRoot')
    chk('O que o cliente acessa' in t and 'Pacote de acesso' not in t and pg.locator('#modalRoot select[name=pacote]').count() == 0, 'novo cliente: árvore de acesso no lugar da lista de pacotes')
    chk(pg.locator('#modalRoot .ac-g').count() >= 7 and pg.locator('#modalRoot .ac-c[hidden]').count() == pg.locator('#modalRoot .ac-g').count(), 'grupos fechados, com setinha para abrir')
    g = pg.locator('#modalRoot .ac-g', has_text='Marketing').first
    g.locator('.ac-seta').click(); pg.wait_for_timeout(200)
    chk(g.locator('.ac-c').is_visible() and "Growth's Content" in g.inner_text(), 'abrir Marketing mostra as telas e o Growth\'s Content')
    g.locator('.ac-sub > label input').check(); pg.wait_for_timeout(200)
    marc = pg.evaluate("[...document.querySelectorAll('#modalRoot input[name=ac]:checked')].map(x => x.value).sort().join(',')")
    chk(marc == 'cad-equipe,cad-funcoes,mkt-cont,mkt-insta', 'marcar Growth\'s Content marca só o módulo de conteúdo (+ equipe, sempre liberada) ' + marc)
    chk(g.locator('.ac-n').inner_text().startswith('2 de ') and pg.evaluate("document.querySelector('#modalRoot .ac-g .ac-h input') && [...document.querySelectorAll('#modalRoot .ac-g')].find(x => x.textContent.includes('Marketing')).querySelector('.ac-h input').indeterminate"), 'Marketing mostra 2 de N, parcialmente marcado')
    pg.screenshot(path='/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots141_novo.png')
    pg.fill('#modalRoot [name=nome]', 'T141 Só Content'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(4000)
    r = sql("select content_ativo || '|' || coalesce(content_drive_status, '-') || '|' || array_to_string(acesso_liga, ' ') from workspaces where nome = 'T141 Só Content'")
    chk(r.startswith('true|') and 'mkt-cont' in r and 'mkt-insta' in r, 'criar o cliente grava o acesso e liga o Growth\'s Content (pasta pedida) ' + r)
    chk(pg.evaluate("S.view") == 'mkt-cont', 'cliente só de conteúdo abre direto no Growth\'s Content')
    nav = pg.inner_text('#nav')
    chk('MARKETING' in nav.upper() and all(x not in nav.upper() for x in ['VENDAS', 'FINANCEIRO', 'REVOPS', 'GROWTH\n', 'PROJETOS', 'ADMINISTRATIVO']), 'menu do cliente: só Marketing (e Configurações) ' + nav.replace('\n', ' | ')[:160])
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
sql(f"delete from pacotes_acesso where id = '{pid}'")
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
