"""v0.135: Máquina em duas partes (Estratégia de conteúdo e canais), regras de canal por frente e etiqueta, DMs do Instagram no CRM.
Banco fa com 20261025022737_instagram_dm_crm.sql (parte local), 20261025034245_conexao_zernio.sql (sem o Vault) e
20261031100000_instagram_dms_canais.sql. Apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q, role=None):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', (f"set role {role}; " if role else '') + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome like 'T135 %'")
    sql(f"delete from social_conversas where workspace_id = '{WS}'"); sql(f"delete from conexoes where workspace_id = '{WS}' and plataforma = 'zernio'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and canal_origem = 'instagram_dm'")
    for t in ['conteudos', 'conteudo_temas', 'conteudo_linhas', 'conteudo_formatos', 'conteudo_config']: sql(f"delete from {t} where workspace_id = '{WS}'")
limpa()
def conta(ws):
    c = sql(f"insert into conexoes (workspace_id, plataforma, status) values ('{ws}', 'zernio', 'conectado') returning id").split('\n')[0]
    return sql(f"insert into conexao_contas (workspace_id, conexao_id, tipo, id_externo, nome) values ('{ws}', '{c}', 'instagram', 'acc', 'rebecka.mkt') returning id").split('\n')[0]
def conv(cid, pid, usuario, msgs):
    return {'id': cid, 'participante_id': pid, 'nome': usuario.title(), 'usuario': usuario, 'url': 'https://www.instagram.com/direct/t/' + cid,
            'ultima_mensagem': msgs[-1][2], 'ultima_em': msgs[-1][3], 'mensagens': [{'id': i, 'direcao': d, 'texto': t, 'em': e} for i, d, t, e in msgs]}
def grava(k, L): return json.loads(sql(f"select social_gravar_dms('{k}', $j${json.dumps(L)}$j$::jsonb)"))

# ---------- banco ----------
T = sql("insert into workspaces (nome) values ('T135 DMs') returning id").split('\n')[0]; K = conta(T)
A = conv('c1', 'p1', 'marina', [('m1', 'recebida', 'Vocês fazem diagnóstico?', '2026-10-20T10:00:00Z'), ('m2', 'enviada', 'Fazemos!', '2026-10-20T10:05:00Z'), ('m3', 'recebida', 'Quanto custa?', '2026-10-21T09:00:00Z')])
B = conv('c2', 'p2', 'eu_escrevi', [('m9', 'enviada', 'Oi, tudo bem?', '2026-10-21T11:00:00Z')])
r = grava(K, [A, B])
chk(r == {'conversas': 2, 'mensagens': 4, 'leads_novos': 1}, 'grava 2 conversas e 4 mensagens; só quem escreveu vira lead %s' % r)
p = json.loads(sql(f"select row_to_json(x) from (select p.nome, p.canal_origem, p.tags, p.extras ->> 'instagram_username' u, (select count(*) from pessoa_toques t where t.pessoa_id = p.id and t.canal = 'instagram_dm' and t.descricao like 'DM Instagram:%') toques from pessoas p where p.workspace_id = '{T}') x"))
chk(p['nome'] == 'Marina' and p['canal_origem'] == 'instagram_dm' and p['tags'] == ['DM Instagram'] and p['u'] == 'marina' and p['toques'] == 2, 'lead no CRM com origem Instagram DM, etiqueta e cada mensagem recebida no histórico %s' % p)
c1 = json.loads(sql(f"select row_to_json(x) from (select mensagens, recebidas, enviadas, primeira_em, pessoa_id is not null tem_pessoa from social_conversas where conta_id = '{K}' and id_externo = 'c1') x"))
chk(c1['mensagens'] == 3 and c1['recebidas'] == 2 and c1['enviadas'] == 1 and c1['tem_pessoa'], 'conversa com contagens e ligada à pessoa')
r = grava(K, [A, B])
chk(r['mensagens'] == 0 and r['leads_novos'] == 0 and sql(f"select count(*) from pessoa_toques where workspace_id = '{T}' and canal = 'instagram_dm' and descricao like 'DM Instagram:%'") == '2', 'trazer de novo não duplica mensagens, leads nem toques')
sql(f"update social_conversas set ignorada = true where conta_id = '{K}' and id_externo = 'c1'")
A['mensagens'].append({'id': 'm4', 'direcao': 'recebida', 'texto': 'oi de novo', 'em': '2026-10-22T09:00:00Z'})
grava(K, [A])
chk(sql(f"select count(*) from pessoa_toques where workspace_id = '{T}' and canal = 'instagram_dm' and descricao like 'DM Instagram:%'") == '2' and sql(f"select mensagens from social_conversas where conta_id = '{K}' and id_externo = 'c1'") == '4', 'conversa marcada "não é lead": a mensagem é guardada, mas não vai mais para o CRM')
R = json.loads(sql(f"select instagram_dms_resumo('{T}', '2026-10-20', '2026-10-26')"))
chk(R['conversas_ativas'] == 2 and R['recebidas'] == 3 and R['enviadas'] == 2 and R['leads_novos'] == 1 and R['sem_resposta'] == 0, 'resumo: 2 conversas, 3 recebidas, 2 enviadas, 1 lead; ignorada não conta como esperando resposta %s' % R)
chk(json.loads(sql(f"select social_conversas_conhecidas('{K}')")).keys() == {'c1', 'c2'}, 'o sincronizador sabe quais conversas já tem')
try: sql(f"select social_gravar_dms('{K}', '[]')", 'authenticated'); chk(False, 'só o sincronizador grava DMs')
except Exception as e: chk('permission denied' in str(e), 'só o sincronizador grava DMs')
chk(sql("select has_column_privilege('authenticated', 'social_conversas', 'ignorada', 'update')") == 't' and sql("select has_column_privilege('authenticated', 'social_conversas', 'pessoa_id', 'update')") == 'f', 'pela tela só dá para marcar "não é lead"')
sql("delete from workspaces where nome like 'T135 %'")

# ---------- telas (Escola Aurora) ----------
sql(f"select conteudo_instalar_v18('{WS}')")
KW = conta(WS)
grava(KW, [conv('w1', 'q1', 'ana.paula', [('n1', 'recebida', 'Tem material sobre retenção?', '2026-10-24T13:00:00Z')]),
           conv('w2', 'q2', 'bia.amiga', [('n2', 'recebida', 'Bora almoçar?', '2026-10-24T14:00:00Z'), ('n3', 'enviada', 'Bora!', '2026-10-24T14:10:00Z')])])
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-25', vw=1500, vh=1000)
    t = front.vai(pg, 'mkt-cont', "S.ct = null;", 4000)
    chk("subs: [{ g: 'Máquina de Conteúdo', mod: 'mkt', items: [['mkt-cont', 'Estratégia de conteúdo'], ['mkt-insta', 'Instagram']] }]" in pg.content(), 'menu: Marketing → Máquina de Conteúdo → Estratégia de conteúdo e Instagram')
    pg.evaluate("abreMenu('mkt-insta'); desenhaNav()")
    chk(pg.locator('#nav .grp .lv2 .sublist button[data-v="mkt-insta"]').count() == 1, 'menu em níveis: Instagram dentro de Máquina de Conteúdo, dentro de Marketing')
    chk(pg.locator('#main .tabs button').all_inner_texts() == ['Dashboard', 'Ideias e pautas', 'Priorização', 'Máquina', 'Semana', 'Fechamento', 'Persona', 'Linha editorial', 'Canais'], 'abas da Estratégia de conteúdo')
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'canais';", 3000)
    fid = sql(f"select id from conteudo_temas where workspace_id = '{WS}' and nome = 'Empreendedorismo'")
    pg.check(f'[data-ft="{fid}|instagram"]'); pg.check(f'[data-ft="{fid}|linkedin"]'); pg.click('#caFrentes'); pg.wait_for_timeout(2500)
    chk(sql(f"select array_to_string(canais_padrao, ',') from conteudo_temas where id = '{fid}'") == 'instagram,linkedin', 'canal padrão da frente salvo')
    pg.check('[data-tg="Humor|instagram"]'); pg.click('#caTags'); pg.wait_for_timeout(2500)
    chk(json.loads(sql(f"select canais_por_tag from conteudo_config where workspace_id = '{WS}'")) == {'Humor': ['instagram']}, 'canal da etiqueta salvo')
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban';", 3000)
    pg.click('#cNovo'); pg.wait_for_timeout(500)
    pg.select_option('#modalRoot [name=tema_id]', fid); pg.wait_for_timeout(200)
    chk(pg.locator('#modalRoot input[name=canal][value=instagram]').is_checked() and pg.locator('#modalRoot input[name=canal][value=linkedin]').is_checked(), 'escolher a frente marca os canais padrão dela')
    pg.click('#modalRoot [data-x]')
    front.vai(pg, 'mkt-insta', "S.ct.tabCanal = { instagram: 'ideias' };", 3000)
    chk(pg.locator('.tabs button').all_inner_texts() == ['Dashboard', 'Ideias do Instagram', 'DMs'] and pg.locator('#cfC').is_disabled() and pg.input_value('#cfC') == 'instagram', 'Instagram: Dashboard, Ideias do Instagram (com o canal fixo) e DMs; sem Relatórios')
    front.vai(pg, 'mkt-insta', "S.ct.tabCanal = { instagram: 'dms' };", 3500)
    t = pg.inner_text('#main')
    chk('@ana.paula' in t and '@bia.amiga' in t and 'Leads novos pela DM' in t, 'aba DMs lista as conversas e os números')
    pg.locator('tr[data-dm]', has_text='bia.amiga').click(); pg.wait_for_timeout(1200)
    chk('Bora almoçar?' in pg.inner_text('.dm-chat') and pg.locator('.dm-m.enviada').count() == 1, 'abre a conversa, com quem mandou cada mensagem')
    pg.click('#dmIgn'); pg.wait_for_timeout(2500)
    chk(sql(f"select ignorada from social_conversas where workspace_id = '{WS}' and id_externo = 'w2'") == 't', 'marca como "não é lead" pela tela')
    front.vai(pg, 'crm-dms', "", 3500)
    chk("['crm-dms', 'DMs do Instagram']" in pg.content() and '@ana.paula' in pg.inner_text('#main'), 'as mesmas DMs em Vendas → DMs do Instagram')
    pg.locator('[data-ficha]').first.click(); pg.wait_for_timeout(2500)
    chk('ana' in pg.inner_text('#modalRoot').lower() or 'Ana' in pg.inner_text('#main'), 'Abrir no CRM abre a ficha da pessoa')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
