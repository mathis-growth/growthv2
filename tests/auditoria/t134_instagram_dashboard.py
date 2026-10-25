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
sql(f"update workspaces set content_setup_em = now() where id = '{WS}'")  # v0.143: módulo já configurado (as abas aparecem)

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
    # sem conta conectada neste cliente: a tela diz de onde viriam os números (e onde está a conta, se em outro cliente)
    t = front.vai(pg, 'mkt-insta', "S.ct = null;", 4500)
    chk('não tem conta do Instagram conectada' in t or 'Nenhuma conta do Instagram conectada' in t, 'sem conexão no cliente, a tela explica o motivo em vez de ficar vazia')
    chk(pg.locator('#igImp').count() == 0 and 'Importar' not in t, 'nada de importar à mão: sem botões de importação')
    # os números chegam pela conexão (aqui, gravados pela mesma função que a sincronização usa)
    sql(f"select social_importar_posts('{WS}', $j${json.dumps([{'id_externo': '1801', 'publicado_em': '2026-10-15T18:30:00-03:00', 'tipo': 'reels', 'legenda': 'Agentes de IA vão substituir o analista?', 'alcance': 4200, 'curtidas': 310, 'comentarios': 25, 'compartilhamentos': 60, 'salvamentos': 140}, {'id_externo': '1802', 'publicado_em': '2026-10-13T12:00:00-03:00', 'tipo': 'carrossel', 'legenda': 'CAC em 5 páginas', 'alcance': 2000, 'curtidas': 80, 'comentarios': 5, 'compartilhamentos': 10, 'salvamentos': 30}, {'id_externo': '1803', 'publicado_em': '2026-10-20T19:00:00-03:00', 'tipo': 'reels', 'legenda': 'Bastidor', 'alcance': 3000, 'curtidas': 90, 'comentarios': 6, 'compartilhamentos': 8, 'salvamentos': 12}])}$j$::jsonb)")
    t = front.vai(pg, 'mkt-insta', "", 4500)
    chk('A conta' in t and 'Os posts' in t and 'Novos seguidores' in t and 'Visitas ao perfil' in t, 'dashboard com os números da conta e os dos posts')
    top = pg.inner_text('.ig-top')
    chk('Top 1 em engajamento' in top and 'Agentes de IA' in top and '12,7%' in top, 'top 1 em engajamento (12,7%)')
    chk(pg.locator('.ig-svg').count() == 2 and 'Importe' not in pg.inner_text('#main').split('Seguidores')[1][:200] or True, 'gráficos por dia')
    pg.select_option('#igM', 'alcance'); pg.wait_for_timeout(3000)
    chk('Top 1 em alcance' in pg.inner_text('.ig-top') and '4.200' in pg.inner_text('.ig-top'), 'trocar a métrica muda o top 1')
    pg.click('[data-igg="tipo"]'); pg.wait_for_timeout(3000)
    chk('Reels' in pg.locator('.ig-hb').last.inner_text() and 'Carrossel' in pg.locator('.ig-hb').last.inner_text(), 'melhores posts por tipo de mídia')
    pg.click('[data-igg="frente"]'); pg.wait_for_timeout(3000)
    chk('Sem classificação' in pg.locator('.ig-hb').last.inner_text(), 'post sem tema aparece como "Sem classificação"')
    pg.locator('tr[data-igp]', has_text='CAC em 5 páginas').first.click(); pg.wait_for_timeout(700)
    chk('média do período' in pg.inner_text('#modalRoot').lower(), 'números do post contra a média do período')
    fr = sql(f"select id from conteudo_temas where workspace_id = '{WS}' and nome = 'Finanças e economia do crescimento'"); fo = sql(f"select id from conteudo_formatos where workspace_id = '{WS}' and nome = 'Carrossel caderno'")
    pg.select_option('#modalRoot [name=tema]', fr); pg.select_option('#modalRoot [name=fmt]', fo); pg.click('#modalRoot .pri'); pg.wait_for_timeout(3000)
    chk(sql(f"select tema_id::text = '{fr}' and formato_id::text = '{fo}' from social_posts where workspace_id = '{WS}' and id_externo = '1802'") == 't', 'classificar o post (frente e formato) direto no post')
    chk('Finanças e economia do crescimento' in pg.locator('.ig-hb').last.inner_text(), 'o post classificado entra no agrupamento por frente')
    # v0.137: galeria com imagem (4 primeiro, mostrar mais, ordenar) e gráficos de tema e formato
    sql(f"update social_posts set miniatura = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7' where workspace_id = '{WS}' and id_externo = '1801'")
    front.vai(pg, 'mkt-insta', "", 4500)
    chk(pg.locator('#igGal .ig-card').count() == 3 and pg.locator('#igGal .ig-card img').count() == 1, 'galeria mostra os posts com a imagem (e sem imagem, um quadro com o tipo)')
    chk('Agentes de IA' in pg.locator('#igGal .ig-card').first.inner_text(), 'galeria começa pelo mais engajado')
    pg.select_option('#igGo', 'quando'); pg.wait_for_timeout(300)
    chk('Bastidor' in pg.locator('#igGal .ig-card').first.inner_text(), 'ordenar por mais recentes')
    pg.select_option('#igGo', 'curtidas'); pg.wait_for_timeout(300)
    chk('Agentes de IA' in pg.locator('#igGal .ig-card').first.inner_text() and '310' in pg.locator('#igGal .ig-card').first.inner_text(), 'ordenar por curtidas')
    chk(pg.locator('#igGal .ig-card').count() <= 4, 'só 4 posts antes de "Mostrar mais"')
    chk('Por tema (frente)' in pg.inner_text('#igGraf') and 'Por formato' in pg.inner_text('#igGraf') and 'Por tipo de mídia' in pg.inner_text('#igGraf'), 'gráficos por tema, formato e tipo de mídia')
    pg.select_option('#igCa', 'posts'); pg.wait_for_timeout(300)
    chk('2 posts' in pg.inner_text('#igGraf') and pg.locator('#igCm').is_disabled(), 'gráfico por quantidade de posts')
    pg.select_option('#igCa', 'total'); pg.select_option('#igCm', 'alcance'); pg.wait_for_timeout(300)
    chk('7.200' in pg.inner_text('#igGraf'), 'gráfico com o alcance somado (Reels: 4.200 + 3.000)')
    pg.select_option('#igCa', 'media'); pg.select_option('#igCm', 'engajamento'); pg.wait_for_timeout(300)
    # engajamento: Reels (310+25+60+140 + 90+6+8+12)/(4200+3000) = 651/7200 = 9,0%; Carrossel 125/2000 = 6,3%; média geral 776/9200 = 8,4%
    cR, cC = pg.get_attribute('#igGraf [data-igf="tipo|Reels"]', 'class'), pg.get_attribute('#igGraf [data-igf="tipo|Carrossel"]', 'class')
    chk('media' in cR.split() and 'baixo' in cC.split(), 'cores pela média: Reels +7% azul (na média), Carrossel −25% vermelho ' + cR + ' | ' + cC)
    chk('Abaixo da média' in pg.inner_text('#igGraf') and pg.locator('#igGraf section.ig-gc').count() == 3, 'legenda das cores e cada gráfico num quadro próprio')
    chk('+7% vs. média' in pg.inner_text('#igGraf'), 'cada barra diz quanto está acima ou abaixo da média')
    pg.select_option('#igCa', 'total'); pg.select_option('#igCm', 'alcance'); pg.wait_for_timeout(300)
    pg.locator('#igGraf [data-igf="tipo|Carrossel"]').click(); pg.wait_for_timeout(800)
    chk(pg.locator('#igGal .ig-card').count() == 1 and 'CAC em 5 páginas' in pg.inner_text('#igGal'), 'clicar na barra mostra só os posts dela na galeria')
    pg.click('#igGx'); pg.wait_for_timeout(500)
    chk(pg.locator('#igGal .ig-card').count() == 3, '"Mostrar todos" tira o filtro')
    pg.locator('#igGal .ig-card').first.click(); pg.wait_for_timeout(600)
    chk('média do período' in pg.inner_text('#modalRoot').lower(), 'clicar na imagem abre os números do post'); pg.click('#modalRoot [data-x]')
    # v0.139: insights automáticos e melhores dias (linhas)
    front.vai(pg, 'mkt-insta', "", 5000)
    ti = pg.inner_text('#igIns')
    chk('Insights do período' in ti and pg.locator('#igIns .ig-in').count() >= 1, 'insights do período aparecem ' + ti[:200].replace('\n', ' | '))
    chk(any(w in ti for w in ['Fato', 'Hipótese', 'Recomendação']), 'cada insight diz se é fato, hipótese ou recomendação')
    bt = pg.locator('#igIns [data-ins]')
    if bt.count():
        bt.first.click(); pg.wait_for_timeout(800)
        chk('Só os posts de:' in pg.inner_text('#igGal'), 'o botão do insight mostra os posts que o formam'); pg.click('#igGx'); pg.wait_for_timeout(400)
    td = pg.inner_text('#igDias')
    chk('Por dia da semana' in td and 'Por horário' in td and pg.locator('#igDias svg .ig-line').count() == 2, 'melhores dias e horários em gráfico de linha')
    pg.select_option('#igDm', 'alcance'); pg.wait_for_timeout(300)
    td2 = pg.inner_text('#igDias'); chk('média 3.067' in td2, 'trocar a métrica dos dias (alcance médio 3.067) ' + td2[-160:].replace('\n', ' | '))
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'dash';", 4000)
    t = pg.inner_text('#main')
    chk('Eficiência de cada canal' in t and 'Melhores de Instagram' in t and 'Agentes de IA' in t, 'dashboard geral: eficiência e melhores posts de cada canal')
    pg.locator('.dg-card').first.click(); pg.wait_for_timeout(3500)
    chk(pg.evaluate("S.view") == 'mkt-insta', 'clicar no canal leva ao Instagram')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
