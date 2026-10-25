"""v0.143: Growth's Content — configuração passo a passo antes das abas; passo 1 = Google Drive (do cliente ou da Mathisa).
Banco fa com 20261104100000_content_setup.sql. Escola Aurora sem configuração. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql(f"update workspaces set content_setup_em = null, content_setup_etapa = 0, content_ativo = false, content_drive_id = null, content_drive_url = null, content_drive_status = null, content_drive_erro = null, content_drive_modo = null, content_drive_email = null where id = '{WS}'")
    for t in ['conteudos', 'conteudo_temas', 'conteudo_linhas', 'conteudo_formatos', 'conteudo_config', 'conteudo_personas', 'conteudo_linha_propostas', 'conteudo_metas_semanais']: sql(f"delete from {t} where workspace_id = '{WS}'")
limpa()
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots143/'
import os; os.makedirs(SHOT, exist_ok=True)
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1440, vh=1000)
    t = front.vai(pg, 'mkt-cont', "S.ct = null;", 3500)
    chk('Vamos configurar o Growth\'s Content' in t and pg.locator('#main .tabs').count() == 0, 'sem configuração: abre na configuração, sem as abas')
    pg.screenshot(path=SHOT + '0_inicio.png')
    pg.click('#csComeca'); pg.wait_for_timeout(2500)
    t = pg.inner_text('#main')
    chk('Passo 1 de 5' in t and 'Conectar meu Google Drive' in t and 'Não tenho Google Drive' in t, 'passo 1: conectar o Google Drive do cliente ou usar o da Mathisa')
    chk(pg.locator('#csSegue').is_disabled(), 'sem pasta, não dá para continuar')
    chk(sql(f"select content_setup_etapa from workspaces where id = '{WS}'") == '1', 'o passo atual fica guardado')
    pg.screenshot(path=SHOT + '1_drive.png')
    pg.click('#csSem'); pg.wait_for_timeout(2500)
    chk(sql(f"select content_drive_modo || '|' || content_ativo from workspaces where id = '{WS}'") == 'mathisa|true', '"Não tenho Google Drive" pede a pasta no Drive da Mathisa')
    sql(f"update workspaces set content_drive_status = 'ok', content_drive_url = 'https://drive.google.com/drive/folders/x', content_drive_erro = null where id = '{WS}'")
    front.vai(pg, 'mkt-cont', '', 3000)
    chk('Pasta pronta' in pg.inner_text('#main') and not pg.locator('#csSegue').is_disabled(), 'pasta pronta libera o próximo passo')
    pg.click('#csSegue'); pg.wait_for_timeout(2500)
    chk('Passo 2 de 5' in pg.inner_text('#main') and pg.locator('#csPasso #pForm').count() == 1, 'passo 2: o questionário de persona de sempre')
    pg.screenshot(path=SHOT + '2_persona.png')
    # preenche por baixo o que as telas de sempre já gravam (questionário, linha V18, canais)
    sql(f"insert into conteudo_personas (workspace_id, respostas) values ('{WS}', (select jsonb_object_agg(k, 'resposta ' || k) from unnest(array['nicho','publico','publico_valoriza','dores','repetido','lacunas','atrair_agora','objetivo_comercial','ofertas','por_que','acredita','discorda']) k))")
    sql(f"select conteudo_instalar_v18('{WS}')")
    sql(f"update conteudo_config set meta_semanal = null where workspace_id = '{WS}'")
    front.vai(pg, 'mkt-cont', "S.ct.csEtapa = 5;", 3000)
    t = pg.inner_text('#main')
    chk('Passo 5 de 5' in t and pg.locator('#csFim').is_disabled() and 'Rotina da semana' in pg.inner_text('.cs-aviso') if pg.locator('.cs-aviso').count() else False, 'sem a rotina, não conclui e diz o que falta')
    pg.fill('#csRot [name=meta]', '5'); pg.click('#csRot button[type=submit]'); pg.wait_for_timeout(2500)
    chk(sql(f"select meta_semanal || '|' || dia_fechamento from conteudo_config where workspace_id = '{WS}'") == '5|5', 'rotina salva, curadoria na sexta por padrão')
    chk(not pg.locator('#csFim').is_disabled(), 'tudo pronto libera "Concluir a configuração"')
    pg.screenshot(path=SHOT + '5_rotina.png')
    pg.click('#csFim'); pg.wait_for_timeout(3500)
    chk(pg.locator('#main .tabs button').count() >= 8 and sql(f"select content_setup_em is not null from workspaces where id = '{WS}'") == 't', 'concluída: abre nas abas de sempre')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
# só quem configura pode concluir; concluir sem pasta é recusado
sql(f"update workspaces set content_setup_em = null, content_drive_status = null where id = '{WS}'")
try:
    sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"{front.UID}\",\"role\":\"authenticated\"}}', false); set role authenticated; select content_setup_salvar('{WS}', 5::smallint, true)"); chk(False, 'concluir sem pasta é recusado')
except Exception as e: chk('Falta a pasta' in str(e), 'concluir sem pasta é recusado')
chk(sql("select has_table_privilege('authenticated', 'content_google', 'select')") == 'f', 'o token do Google nunca vai para a tela')
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
