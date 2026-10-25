"""v0.134: Dashboard do Instagram (aba da Máquina de Conteúdo).
Parte 1 (banco, cliente de teste T134): importação de posts (nova, atualização, erro sem gravar nada), ligação automática pela data
só quando não há dúvida, números do dashboard (totais, período anterior, série da conta, fontes sem contar duas vezes).
Parte 2 (tela, Escola Aurora, hoje = 24/10): importa uma planilha no formato do Meta Business Suite, top 1, gráficos, agrupamentos,
números do post e ligação com a Máquina. Banco fa com a migração 20261030100000_instagram_dashboard.sql; apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def sql(q, role=None):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', (f"set role {role}; " if role else '') + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def erro(q):
    try: sql(q); return ''
    except Exception as e: return str(e).split('\n')[0]
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome like 'T134 %'")
    for t in ['social_posts', 'conteudo_conta_dia', 'conteudo_publicacoes', 'conteudos', 'conteudo_temas', 'conteudo_linhas', 'conteudo_formatos', 'conteudo_config']:
        sql(f"delete from {t} where workspace_id = '{WS}'")
limpa()

# ---------- parte 1: banco ----------
T = sql("insert into workspaces (nome) values ('T134 Insta') returning id").split('\n')[0]
sql(f"select conteudo_instalar_v18('{T}')")
tema = sql(f"select id from conteudo_temas where workspace_id = '{T}' and nome = 'Growth'")
def cont(tit, dia, canais='{instagram}', status='publicado'):
    return sql(f"insert into conteudos (workspace_id, titulo, tema_id, formato_id, destino, s1,s2,s3,s4,s5,s6, validado, status, canais, data_publicacao, copy_url, midia_url) values ('{T}', '{tit}', '{tema}', (select id from conteudo_formatos where workspace_id = '{T}' and nome = 'Análise'), 'Rebecka', 4,4,4,4,4,4, true, '{status}', '{canais}', '{dia}', 'https://d.co/x', 'https://d.co/y') returning id").split('\n')[0]
cA = cont('Lucro caiu', '2026-10-20'); cB = cont('Dois no dia 1', '2026-10-21'); cC = cont('Dois no dia 2', '2026-10-21'); cD = cont('Só LinkedIn', '2026-10-22', '{linkedin}')
cE = cont('Registrado à mão', '2026-10-18')
sql(f"insert into conteudo_publicacoes (workspace_id, conteudo_id, canal, data_publicacao, status, alcance, curtidas, salvamentos) values ('{T}', '{cE}', 'instagram', '2026-10-18', 'publicada', 1000, 50, 10)")
def post(i, dia, alc, cur, sal=0, com=0, sha=0, hora='18:00'):
    return {'id_externo': i, 'publicado_em': f'{dia}T{hora}:00-03:00', 'tipo': 'reels', 'legenda': 'Post ' + i, 'url': 'https://www.instagram.com/p/' + i, 'alcance': alc, 'curtidas': cur, 'salvamentos': sal, 'comentarios': com, 'compartilhamentos': sha}
itens = [post('p1', '2026-10-20', 4000, 200, 100, 20, 80), post('p2', '2026-10-21', 2000, 50), post('p3', '2026-10-21', 1000, 40), post('p4', '2026-10-22', 3000, 90),
         post('p0', '2026-10-12', 1000, 30)]
r = json.loads(sql(f"select social_importar_posts('{T}', '{json.dumps(itens)}')"))
chk(r == {'novos': 5, 'atualizados': 0, 'ligados': 1}, 'importa 5 posts e liga só 1 pela data %s' % r)
chk(sql(f"select c.titulo || ' ' || s.vinculo from social_posts s join conteudos c on c.id = s.conteudo_id where s.workspace_id = '{T}'") == 'Lucro caiu automatico', 'liga só quando há 1 post e 1 conteúdo do Instagram no dia (21/10 tem 2 e 2; 22/10 o conteúdo é só LinkedIn)')
itens[1]['alcance'] = 2500
r = json.loads(sql(f"select social_importar_posts('{T}', '{json.dumps(itens[:2])}')"))
chk(r['novos'] == 0 and r['atualizados'] == 2 and sql(f"select alcance from social_posts where workspace_id = '{T}' and id_externo = 'p2'") == '2500', 'importar de novo atualiza, não duplica')
ruim = json.dumps([post('p9', '2026-10-23', 10, 1), {**post('p10', '2026-10-23', 10, 1), 'curtidas': 'muitas'}])
chk('Linha 2' in erro(f"select social_importar_posts('{T}', '{ruim}')") and sql(f"select count(*) from social_posts where workspace_id = '{T}' and id_externo = 'p9'") == '0', 'erro numa linha: nada entra e a mensagem diz a linha')
chk('data' in erro(f"select social_importar_posts('{T}', '[{{\"id_externo\": \"x\"}}]')"), 'sem data é recusado')
for d, seg, alc in [('2026-10-12', 900, 300), ('2026-10-19', 1000, 500), ('2026-10-24', 1040, 700)]:
    sql(f"insert into conteudo_conta_dia (workspace_id, canal, data, seguidores, alcance, visitas_perfil) values ('{T}', 'instagram', '{d}', {seg}, {alc}, 10)")
R = json.loads(sql(f"select instagram_dashboard('{T}', '2026-10-18', '2026-10-24')"))
t = R['totais']
chk(t['posts'] == 5 and R['fontes']['importado'] == 4 and R['fontes']['maquina'] == 1, 'período: 4 posts importados + 1 publicação registrada só na Máquina')
chk(t['alcance'] == 4000 + 2500 + 1000 + 3000 + 1000 and t['interacoes'] == 400 + 50 + 40 + 90 + 60, 'totais de alcance e interações')
chk(abs(t['engajamento'] - round(640 / 11500, 4)) < 1e-9, 'engajamento = interações ÷ alcance (%s)' % t['engajamento'])
chk(R['anterior']['posts'] == 1 and R['anterior']['alcance'] == 1000, 'período anterior de mesmo tamanho (11/10 a 17/10)')
chk(R['seguidores']['fim'] == 1040 and R['seguidores']['antes'] == 900 and R['seguidores']['inicio'] == 1000, 'seguidores: fim do período e antes dele')
chk(len(R['serie']) == 7 and R['serie'][3]['posts'] == 2 and R['serie'][3]['alcance_posts'] == 3500, 'série por dia (21/10: 2 posts, 3.500 de alcance)')
p1 = [p for p in R['posts'] if p['id_externo' if False else 'legenda'] == 'Post p1'][0]
chk(p1['territorio'] == 'Negócios' and p1['formato'] == 'Análise' and p1['destino'] == 'Rebecka' and p1['engajamento'] == 0.1, 'post ligado traz território, formato, destino e engajamento 10%%')
sql(f"select social_importar_posts('{T}', '{json.dumps([post('p5', '2026-10-18', 1200, 60)])}')")
sql(f"update social_posts set conteudo_id = '{cE}', vinculo = 'manual' where workspace_id = '{T}' and id_externo = 'p5'")
R2 = json.loads(sql(f"select instagram_dashboard('{T}', '2026-10-18', '2026-10-24')"))
chk(R2['totais']['posts'] == 5 and R2['fontes']['maquina'] == 0, 'quando o post real é ligado ao conteúdo, a métrica digitada na Máquina deixa de contar (sem contar duas vezes)')
B = sql("insert into workspaces (nome) values ('T134 Outro') returning id").split('\n')[0]
cX = sql(f"insert into conteudos (workspace_id, titulo) values ('{B}', 'De outro') returning id").split('\n')[0]
chk('deste cliente' in erro(f"update social_posts set conteudo_id = '{cX}' where workspace_id = '{T}' and id_externo = 'p2'"), 'não liga post a conteúdo de outro cliente')
chk('400 dias' in erro(f"select instagram_dashboard('{T}', '2025-01-01', '2026-10-24')"), 'período máximo de 400 dias')
for fn in [f"instagram_dashboard('{T}', '2026-10-18', '2026-10-24')", f"social_importar_posts('{T}', '[]')"]:
    try: sql('select ' + fn, 'anon'); chk(False, 'anon não executa ' + fn)
    except Exception as e: chk('permission denied' in str(e), 'anon não executa ' + fn.split('(')[0])
chk(sql("select has_column_privilege('authenticated', 'social_posts', 'alcance', 'update')") == 'f' and sql("select has_column_privilege('authenticated', 'social_posts', 'conteudo_id', 'update')") == 't', 'pela tela só dá para mudar a ligação, não as métricas')
sql("delete from workspaces where nome like 'T134 %'")

# ---------- parte 2: telas (Escola Aurora) ----------
sql(f"select conteudo_instalar_v18('{WS}')")
tema = sql(f"select id from conteudo_temas where workspace_id = '{WS}' and nome = 'IA aplicada e agentes'")
CW = sql(f"insert into conteudos (workspace_id, titulo, tema_id, formato_id, destino, s1,s2,s3,s4,s5,s6, validado, status, canais, data_publicacao, copy_url, midia_url, tags) values ('{WS}', 'Agentes de IA', '{tema}', (select id from conteudo_formatos where workspace_id = '{WS}' and nome = 'Yap Content'), 'Rebecka', 4,4,4,4,4,4, true, 'publicado', '{{instagram}}', '2026-10-15', 'https://d.co/x', 'https://d.co/y', '{{Humor}}') returning id").split('\n')[0]
CSV = '﻿Identificação da publicação;Horário de publicação;Tipo de publicação;Descrição;Link permanente;Alcance;Curtidas;Comentários;Compartilhamentos;Salvamentos\n' + \
      '1801;15/10/2026 18:30;Reels;"Agentes de IA vão substituir o analista?\nCê acha ou tem dado?";https://www.instagram.com/reel/1801;4.200;310;25;60;140\n' + \
      '1802;13/10/2026 12:00;Carrossel;CAC em 5 páginas;https://www.instagram.com/p/1802;2.000;80;5;10;30\n' + \
      '1803;20/10/2026 19:00;Reels;Bastidor;https://www.instagram.com/reel/1803;3.000;90;6;8;12\n' + \
      '1804;02/10/2026 09:00;Imagem;Antigo;https://www.instagram.com/p/1804;1.000;20;1;1;2\n'
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-24', vw=1500, vh=1000)
    t = front.vai(pg, 'mkt-insta', "S.ct = null;", 4500)
    chk("['mkt-insta', 'Instagram']" in pg.content() and pg.evaluate("S.ct.tab") == 'insta', 'atalho "Instagram" no menu Marketing abre a aba da Máquina')
    chk('Nenhum post neste período' in t and 'Importar posts' in t, 'sem posts: explica como importar até a Meta aprovar')
    pg.click('#igImp'); pg.wait_for_timeout(500)
    pg.fill('#modalRoot [name=csv]', CSV); pg.dispatch_event('#modalRoot [name=csv]', 'input'); pg.wait_for_timeout(300)
    pv = pg.inner_text('#igPrev')
    chk('4 post(s) prontos' in pv and 'dia/mês' in pv and '15/10/2026' in pv, 'prévia: 4 posts, datas lidas como dia/mês')
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select count(*) || ' ' || sum(alcance) from social_posts where workspace_id = '{WS}'") == '4 10200' and sql(f"select legenda from social_posts where workspace_id = '{WS}' and id_externo = '1801'").startswith('Agentes de IA vão substituir o analista?\nCê acha'), 'importa os 4 posts, com milhar "4.200" e legenda de duas linhas')
    chk(sql(f"select conteudo_id from social_posts where workspace_id = '{WS}' and id_externo = '1801'") == CW, 'o post de 15/10 foi ligado sozinho ao conteúdo publicado nesse dia')
    t = pg.inner_text('#main')
    chk('4 post(s): 4 da planilha importada' in t, 'últimos 30 dias (25/09 a 24/10): 4 posts e a fonte deles')
    top = pg.inner_text('.ig-top')
    chk('Top 1 em engajamento' in top and 'Agentes de IA' in top and '12,7%' in top, 'top 1 em engajamento: o post ligado, com 12,7%')
    chk(pg.locator('.ig-svg').count() == 2 and 'Importe os dados da conta por dia' in pg.inner_text('#main'), 'gráficos de alcance e interações por dia; seguidores pedem os dados da conta')
    pg.select_option('#igM', 'alcance'); pg.wait_for_timeout(3000)
    chk('Top 1 em alcance' in pg.inner_text('.ig-top') and '4.200' in pg.inner_text('.ig-top'), 'trocar a métrica muda o top 1')
    pg.click('[data-igg="tipo"]'); pg.wait_for_timeout(3000)
    hb = pg.inner_text('.ig-hb')
    chk('Reels' in hb and 'Carrossel' in hb and '2 posts' in hb, 'agrupamento por tipo de mídia')
    pg.click('[data-igg="tag"]'); pg.wait_for_timeout(3000)
    chk('Humor' in pg.inner_text('.ig-hb'), 'agrupamento por etiqueta da Máquina')
    pg.locator('tr[data-igp]', has_text='CAC em 5 páginas').first.click(); pg.wait_for_timeout(700)
    mt = pg.inner_text('#modalRoot')
    chk('média do período' in mt.lower() and 'Posição no período' in mt, 'números do post contra a média do período')
    pg.select_option('#modalRoot [name=cont]', CW); pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk(sql(f"select vinculo from social_posts where workspace_id = '{WS}' and id_externo = '1802'") == 'manual', 'ligar o post a um conteúdo pela tela')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
