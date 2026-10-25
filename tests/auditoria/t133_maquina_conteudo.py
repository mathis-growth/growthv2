"""v0.133: Máquina de Conteúdo.
Parte 1 (banco, cliente de teste T133): método antigo intacto, modelo V18 instalável e repetível, regras do score de 6 critérios,
VALIDAR, destino, linha editorial aplicada por proposta, números da semana e fechamento.
Parte 2 (tela, Escola Aurora, hoje = 28/10): instala o V18 pela tela, cria pauta com score e VALIDAR, priorização, matriz,
semana com arrastar para o dia, fechamento, questionário de persona com resposta colada e aplicada. Banco fa com a migração
20261029100000_maquina_conteudo.sql; apaga o que criou."""
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
    sql("delete from workspaces where nome like 'T133 %'")
    for t in ['conteudo_publicacoes', 'conteudos', 'conteudo_temas', 'conteudo_linhas', 'conteudo_formatos', 'conteudo_config', 'conteudo_fechamentos', 'conteudo_linha_propostas', 'conteudo_personas']:
        sql(f"delete from {t} where workspace_id = '{WS}'")
limpa()

# ---------- parte 1: banco ----------
A = sql("insert into workspaces (nome) values ('T133 Antigo') returning id").split('\n')[0]
ta = sql(f"insert into conteudo_temas (workspace_id, nome) values ('{A}', 'Growth') returning id").split('\n')[0]
ca = sql(f"insert into conteudos (workspace_id, titulo, tema_id) values ('{A}', 'Velho', '{ta}') returning id").split('\n')[0]
chk('5 notas da ideia' in erro(f"update conteudos set status = 'pauta' where id = '{ca}'"), 'quem não instalou a Máquina continua no método antigo (5 notas da ideia para virar pauta)')
sql(f"update conteudos set ideia_n1=8, ideia_n2=8, ideia_n3=8, ideia_n4=8, ideia_n5=8, status='pauta', destino='Qualquer', tags=array[' Case ', 'Case', ''] where id = '{ca}'")
chk(sql(f"select status || ' ' || destino || ' ' || array_to_string(tags, '|') from conteudos where id = '{ca}'") == 'pauta Qualquer Case', 'método antigo: pauta aprovada com 5 notas; sem destinos cadastrados, destino é livre; etiquetas limpas e sem repetição')

T = sql("insert into workspaces (nome) values ('T133 Máquina') returning id").split('\n')[0]
r1 = json.loads(sql(f"select conteudo_instalar_v18('{T}')"))
r2 = json.loads(sql(f"select conteudo_instalar_v18('{T}')"))
chk(r1['territorios'] == 4 and r1['formatos'] == 5 and r1['formatos_novos'] == 9, 'V18: 4 territórios, 5 formatos e 4 quadros %s' % r1)
chk(r2['territorios_novos'] == 0 and r2['frentes_novas'] == 0 and r2['formatos_novos'] == 0 and sql(f"select count(*) from conteudo_linhas where workspace_id = '{T}'") == '4', 'instalar de novo não duplica nada')
chk(sql(f"select string_agg(nome, ' | ' order by ordem) from conteudo_linhas where workspace_id = '{T}'") == 'Estratégia | Negócios | Dados + IA | Vida Real & Crenças', 'territórios na ordem da V18')
chk(sql(f"select l.nome from conteudo_temas t join conteudo_linhas l on l.id = t.linha_id where t.workspace_id = '{T}' and t.nome = 'Empreendedorismo'") == 'Negócios', 'Empreendedorismo registrado dentro de Negócios')
chk(sql(f"select count(*) from conteudo_temas where workspace_id = '{T}' and linha_id = (select id from conteudo_linhas where workspace_id = '{T}' and nome = 'Estratégia')") == '5', 'Estratégia com as frentes A a E')
chk(sql(f"select string_agg(nome, ' | ' order by ordem) from conteudo_formatos where workspace_id = '{T}' and grupo = 'formato'") == 'No Quadro / Tablet | Yap Content | Análise | Carrossel caderno | Série musical (IA)', 'os 5 formatos: No Quadro, Yap, Análise, Carrossel caderno e Série musical')
chk(sql(f"select vezes_semana || ' ' || tipo_midia from conteudo_formatos where workspace_id = '{T}' and nome = 'Série musical (IA)'") == '1 reels', 'Série musical: 1 vez por semana, em reels')
chk(sql(f"select count(*) from conteudo_temas where workspace_id = '{T}' and transversal") == '6', 'camadas transversais como frentes transversais')
chk(sql(f"select metodo || ' ' || array_to_string(destinos, ',') || ' ' || meta_semanal || ' ' || dia_fechamento || ' ' || modelo || ' ' || cardinality(criterios_score) from conteudo_config where workspace_id = '{T}'") == 'score6 Rebecka,Mathisa,Ambas 12 6 V18 6', 'config: score V18, destinos, meta 12, fechamento no sábado')
chk(sql(f"select linha ->> 'inimigo' from conteudo_config where workspace_id = '{T}'") == 'A Lógica do Próximo', 'núcleo da marca gravado (inimigo comum)')

tid = lambda n: sql(f"select id from conteudo_temas where workspace_id = '{T}' and nome = '{n}'")
fid = lambda n: sql(f"select id from conteudo_formatos where workspace_id = '{T}' and nome = '{n}'")
c1 = sql(f"insert into conteudos (workspace_id, titulo, tema_id, formato) values ('{T}', 'Lucro caiu com mais tráfego', '{tid('Growth')}', 'reels') returning id").split('\n')[0]
chk('6 notas' in erro(f"update conteudos set status = 'pauta' where id = '{c1}'"), 'score6: para virar pauta, as 6 notas')
chk('destino' in erro(f"update conteudos set s1=5,s2=5,s3=4,s4=3,s5=4,s6=3, status = 'pauta' where id = '{c1}'"), 'score6: destino obrigatório quando há destinos')
chk('formato' in erro(f"update conteudos set s1=5,s2=5,s3=4,s4=3,s5=4,s6=3, destino = 'mathisa', status = 'pauta' where id = '{c1}'"), 'score6: formato obrigatório quando há formatos')
chk('não está entre' in erro(f"update conteudos set destino = 'Outra' where id = '{c1}'"), 'destino fora da lista é recusado')
sql(f"update conteudos set s1=5,s2=5,s3=4,s4=3,s5=4,s6=3, destino = 'mathisa', formato_id = '{fid('Análise')}', quadro_id = '{fid('Business Case')}', status = 'pauta' where id = '{c1}'")
chk(sql(f"select status || ' ' || score_total || ' ' || destino from conteudos where id = '{c1}'") == 'pauta 24 Mathisa', 'pauta aprovada: score total 24 e destino com a grafia cadastrada')
chk('VALIDAR' in erro(f"update conteudos set canais = '{{instagram}}', status = 'producao' where id = '{c1}'"), 'sem VALIDAR não produz (a escolha é humana)')
sql(f"update conteudos set validado = true, canais = '{{instagram}}', status = 'producao', data_publicacao = '2026-10-29' where id = '{c1}'")
chk(sql(f"select (validado_em is not null)::text || ' ' || dia_semana from conteudos where id = '{c1}'") == 'true 4', 'VALIDAR registra quando; dia da semana vem da data (quinta = 4)')
outro = sql(f"select id from conteudo_formatos where workspace_id <> '{T}' limit 1") or None
B = sql("insert into workspaces (nome) values ('T133 Outro') returning id").split('\n')[0]
sql(f"select conteudo_instalar_v18('{B}')")
chk('formato deste workspace' in erro(f"update conteudos set formato_id = (select id from conteudo_formatos where workspace_id = '{B}' and grupo = 'formato' limit 1) where id = '{c1}'"), 'formato de outro cliente é recusado')
chk('quadro' in erro(f"update conteudos set quadro_id = '{fid('Yap Content')}' where id = '{c1}'"), 'um formato não pode ser usado como quadro')
chk('VALIDAR' in erro(f"update conteudos set validado = false where id = '{c1}'"), 'o que já está em produção não perde o VALIDAR')
cv = sql(f"insert into conteudos (workspace_id, titulo, validado) values ('{T}', 'Só validar', true) returning id").split('\n')[0]
sql(f"update conteudos set validado = false where id = '{cv}'")
chk(sql(f"select validado_em is null from conteudos where id = '{cv}'") == 't', 'tirar o VALIDAR de uma ideia limpa a data')
sql(f"delete from conteudos where id = '{cv}'")

# semana de 26/10 a 01/11
def novo(tit, tema, fmt, dest, notas, val, status='ideia', data=None):
    s1, s2, s3, s4, s5, s6 = notas
    return sql(f"insert into conteudos (workspace_id, titulo, tema_id, formato_id, destino, s1, s2, s3, s4, s5, s6, validado, status, canais, data_publicacao, copy_url, midia_url) values ('{T}', '{tit}', '{tid(tema)}', '{fid(fmt)}', '{dest}', {s1}, {s2}, {s3}, {s4}, {s5}, {s6}, {val}, '{status}', '{{instagram}}', {('%r' % data) if data else 'null'}, 'https://docs.google.com/x', 'https://drive.google.com/x') returning id").split('\n')[0]
c2 = novo('NSM explicada no quadro', 'Growth', 'No Quadro / Tablet', 'Rebecka', (5, 5, 4, 4, 4, 4), 'true')
c3 = novo('Tracking quebrado', 'Tracking e infraestrutura de dados', 'Análise', 'Ambas', (4, 4, 5, 4, 4, 5), 'true')
c4 = novo('Hype de agente', 'IA aplicada e agentes', 'Yap Content', 'Rebecka', (2, 3, 2, 4, 1, 2), 'false')
c5 = novo('Bastidor da Mathisa', 'Construção da Mathisa e bastidores', 'Yap Content', 'Rebecka', (3, 3, 3, 5, 3, 3), 'true', 'publicado', '2026-10-27')
sql(f"insert into conteudo_publicacoes (workspace_id, conteudo_id, canal, data_publicacao, status, alcance, curtidas, comentarios, salvamentos) values ('{T}', '{c5}', 'instagram', '2026-10-27', 'publicada', 1000, 40, 5, 15)")
S_ = json.loads(sql(f"select conteudo_semana('{T}', '2026-10-26')"))
chk(S_['planejados'] == 2 and S_['publicados'] == 1 and S_['meta'] == 12, 'semana: 2 com data (1 publicado), meta 12')
chk(S_['banco_forte'] == 3, 'banco forte = validadas ainda não publicadas (3)')
chk([x['titulo'] for x in S_['ranking']] == ['Tracking quebrado', 'NSM explicada no quadro', 'Lucro caiu com mais tráfego'], 'ranking por score; empate em 26 resolvido pelo impacto %s' % [(x['titulo'], x['score']) for x in S_['ranking']])
chk([x['titulo'] for x in S_['reservas']] == ['Hype de agente'], 'reservas: com score e sem VALIDAR')
pf = {x['nome']: x for x in S_['por_formato']}
chk(pf['Série musical (IA)']['planejados'] == 0 and pf['Série musical (IA)']['vezes_semana'] == 1 and pf['Análise']['planejados'] == 1, 'por formato: Série musical 0 de 1 (lacuna), Análise 1')
pt = {x['nome']: x for x in S_['por_territorio']}
chk(pt['Negócios']['planejados'] == 1 and pt['Vida Real & Crenças']['planejados'] == 1 and pt['Estratégia']['planejados'] == 0, 'por território na semana')
chk(S_['por_destino'] == {'Mathisa': 1, 'Rebecka': 1}, 'por destino %s' % S_['por_destino'])
d = S_['desempenho']
chk(d['publicacoes'] == 1 and d['alcance'] == 1000 and d['interacoes'] == 60 and abs(d['engajamento'] - 0.06) < 1e-9 and d['top'][0]['titulo'] == 'Bastidor da Mathisa', 'desempenho: alcance 1.000, 60 interações, engajamento 6%')
chk('segunda' in erro(f"select conteudo_semana('{T}', '2026-10-27')"), 'a semana começa na segunda')
f1 = sql(f"select conteudo_fechar_semana('{T}', '2026-10-26', '{{\"funcionou\": \"bastidor\"}}', 'Mais fundo de funil', 'Business case de lucro')")
f2 = sql(f"select conteudo_fechar_semana('{T}', '2026-10-26', '{{\"funcionou\": \"bastidor e NSM\"}}', 'Mais fundo de funil', '')")
chk(f1 == f2 and sql(f"select count(*) || ' ' || (retro ->> 'funcionou') || ' ' || (resumo ->> 'banco_forte') || ' ' || coalesce(pre_pauta, 'vazio') from conteudo_fechamentos where workspace_id = '{T}' group by retro, resumo, pre_pauta") == '1 bastidor e NSM 3 vazio', 'fechar de novo atualiza o mesmo fechamento e guarda a foto dos números')

# proposta aplicada
prop = {'nome': 'Linha da Clínica', 'linha': {'tese': 'Saúde é rotina'}, 'destinos': ['Dra. Ana'], 'meta_semanal': 5, 'territorios': [{'nome': 'Rotina', 'frentes': [{'nome': 'Sono'}, {'nome': 'Alimentação'}]}, {'nome': 'Ciência', 'frentes': [{'nome': 'Estudos'}]}, {'nome': 'Vida Real', 'frentes': []}], 'formatos': [{'nome': 'Consultório', 'vezes_semana': 2}]}
P1 = sql(f"insert into conteudo_linha_propostas (workspace_id, origem, proposta) values ('{A}', 'colada', '{json.dumps(prop)}') returning id").split('\n')[0]
r = json.loads(sql(f"select conteudo_aplicar_proposta('{P1}')"))
chk(r['territorios'] == 3 and r['formatos'] == 1 and sql(f"select status from conteudo_linha_propostas where id = '{P1}'") == 'aplicada', 'proposta aplicada: 3 territórios, 1 formato, marcada como aplicada')
chk(sql(f"select metodo || ' ' || array_to_string(destinos, ',') || ' ' || meta_semanal from conteudo_config where workspace_id = '{A}'") == 'score6 Dra. Ana 5', 'a proposta troca o método e grava destinos e meta')
chk(sql(f"select count(*) from conteudos where workspace_id = '{A}'") == '1' and sql(f"select linha_id is null from conteudo_temas where id = '{ta}'") == 't', 'aplicar não apaga nada (a ideia e o tema antigos continuam)')
P2 = sql(f"insert into conteudo_linha_propostas (workspace_id, origem, proposta) values ('{A}', 'colada', '{json.dumps(prop)}') returning id").split('\n')[0]
sql(f"select conteudo_aplicar_proposta('{P2}')")
chk(sql(f"select status from conteudo_linha_propostas where id = '{P1}'") == 'descartada', 'aplicar outra proposta tira a anterior de aplicada')
chk('pelo menos um território' in erro(f"select conteudo_aplicar_linha('{A}', '{{\"territorios\": []}}')"), 'linha sem território é recusada')
sete = json.dumps({'territorios': [{'nome': 'T%d' % i} for i in range(7)]})
chk('no máximo 6' in erro(f"select conteudo_aplicar_linha('{A}', '{sete}')"), 'mais de 6 territórios é recusado')
# segurança
for fn in [f"conteudo_instalar_v18('{T}')", f"conteudo_semana('{T}', '2026-10-26')"]:
    try: sql('select ' + fn, 'anon'); chk(False, 'anon não executa ' + fn)
    except Exception as e: chk('permission denied' in str(e), 'anon não executa ' + fn.split('(')[0])
chk(sql("select string_agg(tablename, ',' order by tablename) from pg_policies where policyname = 'perm_inserir' and tablename in ('conteudo_formatos', 'conteudo_fechamentos', 'conteudo_personas', 'conteudo_linha_propostas')") == 'conteudo_fechamentos,conteudo_formatos,conteudo_linha_propostas,conteudo_personas', 'tabelas novas com a regra de módulo (Marketing edita)')
sql("delete from workspaces where nome like 'T133 %'")

# ---------- parte 2: telas (Escola Aurora) ----------
PROP = {'nome': 'Linha Aurora', 'linha': {'tese': 'Aprender é rotina', 'inimigo': 'O curso que ninguém termina'}, 'destinos': ['Aurora'], 'meta_semanal': 6,
        'territorios': [{'nome': 'Pedagogia', 'pergunta': 'Como se aprende?', 'frentes': [{'nome': 'Métodos'}, {'nome': 'Avaliação'}]}, {'nome': 'Carreira', 'frentes': [{'nome': 'Transição'}]}, {'nome': 'Bastidores', 'frentes': [{'nome': 'Equipe'}]}],
        'formatos': [{'nome': 'Aula curta', 'tipo_midia': 'reels', 'vezes_semana': 3}], 'pendencias': ['Falta o objetivo comercial']}
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-28', vw=1500, vh=1000)
    t = front.vai(pg, 'mkt-cont', "S.ct = null;", 4000)
    chk("g: 'Máquina de Conteúdo'" in pg.content() and "['mkt-cont', 'Planejamento" not in pg.content(), 'menu: "Máquina de Conteúdo" no lugar de "Planejamento de conteúdo"')
    chk('\nMáquina de Conteúdo\n' in t and 'Monte a sua Máquina' in t, 'título novo e começo guiado quando não há territórios')
    chk(pg.locator('#main .tabs button').all_inner_texts() == ['Dashboard', 'Ideias e pautas', 'Priorização', 'Máquina', 'Semana', 'Fechamento', 'Persona', 'Linha editorial', 'Canais'], 'Estratégia de conteúdo: Dashboard dos canais e as abas da Máquina')
    pg.locator('[data-mq-v18]').first.click(); pg.wait_for_timeout(500); pg.click('#modalRoot .pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select count(*) from conteudo_linhas where workspace_id = '{WS}'") == '4' and 'Linha: V18' in pg.inner_text('#main'), 'instala o modelo V18 pela tela')
    # nova pauta com score e VALIDAR
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban';", 3000)
    pg.click('#cNovo'); pg.wait_for_timeout(600)
    f = pg.locator('#modalRoot form')
    f.locator('[name=titulo]').fill('CAC subiu e o lucro caiu')
    f.locator('[name=tema_id]').select_option(label='Finanças e economia do crescimento')
    f.locator('[name=formato_id]').select_option(label='Análise'); f.locator('[name=quadro_id]').select_option(label='Business Case'); f.locator('[name=destino]').select_option('Rebecka')
    f.locator('[name=palavra_chave]').fill('CAC'); f.locator('[name=palavras_relacionadas]').fill('margem, lucro, payback'); f.locator('[name=perguntas_busca]').fill('Por que meu CAC subiu?\nComo calcular o CAC?')
    f.locator('[name=intencao]').select_option('diagnosticar'); f.locator('[name=classificacao]').select_option('evidencia')
    for k, n in zip(['s1', 's2', 's3', 's4', 's5', 's6'], [5, 4, 5, 3, 4, 4]): f.locator(f'.mq-1a5 input[name={k}][value="{n}"] + span').click()
    chk('25 / 30' in pg.inner_text('#mqTot'), 'o total do score aparece enquanto marca as notas')
    f.locator('[name=validado]').check()
    f.locator('[name=estrutura]').select_option('case'); pg.wait_for_timeout(200)
    chk(f.locator('[data-passo]').count() == 5, 'estrutura Case abre os 5 passos (Problema → … → Resultado)')
    f.locator('[data-passo="Problema"]').fill('Mais tráfego, menos lucro')
    f.locator('[data-tag="Case"]').click(); f.locator('[data-tag="Fundo de funil"]').click()
    f.locator('[name=hook]').fill('Cê acha ou tem dado?')
    pg.click('#modalRoot .pri'); pg.wait_for_timeout(3000)
    row = json.loads(sql(f"select row_to_json(x) from (select score_total, validado, destino, palavra_chave, palavras_relacionadas, perguntas_busca, intencao, tags, estrutura, estrutura_notas, hook, status from conteudos where workspace_id = '{WS}' and titulo = 'CAC subiu e o lucro caiu') x"))
    chk(row['score_total'] == 25 and row['validado'] and row['destino'] == 'Rebecka' and row['palavras_relacionadas'] == ['margem', 'lucro', 'payback'] and len(row['perguntas_busca']) == 2, 'pauta salva com score 25, VALIDAR, destino e palavras %s' % row)
    chk(row['tags'] and set(row['tags']) == {'Case', 'Fundo de funil'} and row['estrutura_notas'] == {'Problema': 'Mais tráfego, menos lucro'} and row['intencao'] == 'diagnosticar', 'etiquetas, estrutura do roteiro e intenção salvas')
    card = pg.locator('.gcard', has_text='CAC subiu')
    ct = card.inner_text()
    chk('☑' in ct and 'Negócios' in ct and 'Análise' in ct and 'Rebecka' in ct and 'Score 25/30' in ct and 'Fundo de funil' in ct, 'cartão mostra ☑, território, formato, destino, score e etiquetas')
    # uma sem score, para a regra
    sql(f"insert into conteudos (workspace_id, titulo, tema_id) values ('{WS}', 'Ideia crua', (select id from conteudo_temas where workspace_id = '{WS}' and nome = 'Growth'))")
    front.vai(pg, 'mkt-cont', "", 3000)
    pg.locator('.gcard', has_text='Ideia crua').locator('[data-mv]').select_option('pauta'); pg.wait_for_timeout(2500)
    chk('6 notas' in pg.inner_text('#toast') and pg.locator('#modalRoot form').count() == 1, 'mover sem score: avisa e abre o cartão para completar')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    # filtros
    pg.select_option('#cfD', 'Rebecka'); pg.wait_for_timeout(2500)
    chk(pg.locator('.gcard').count() == 1, 'filtro por destino')
    pg.click('#cfLimpa'); pg.wait_for_timeout(2500)
    # priorização
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'prior';", 3000)
    t = pg.inner_text('#main')
    chk('Quadro de validação' in t and 'Reservas' in t and 'Rebecka' in t, 'priorização: validadas, reservas e abas por destino')
    pg.locator('[data-val]').first.uncheck(); pg.wait_for_timeout(2500)
    chk(sql(f"select validado from conteudos where workspace_id = '{WS}' and titulo = 'CAC subiu e o lucro caiu'") == 'f', 'VALIDAR liga e desliga direto na lista')
    sql(f"update conteudos set validado = true where workspace_id = '{WS}' and titulo = 'CAC subiu e o lucro caiu'")
    # matriz
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'maquina';", 3000)
    chk(pg.locator('.mq-mat tbody tr').count() == 4 and pg.locator('.mq-mat thead th').count() == 7, 'matriz 4 territórios × 5 formatos')
    cel = pg.locator('.mq-mat tbody tr', has_text='Negócios').locator('td').nth(2)
    chk(cel.locator('.mq-n').inner_text() == '1', 'Negócios × Análise = 1')
    cel.locator('.mq-n').click(); pg.wait_for_timeout(2500)
    chk(pg.locator('.gcard').count() == 1 and pg.evaluate("S.ct.tab") == 'kanban', 'clicar na célula abre o Kanban filtrado')
    # semana: arrastar a validada para quarta
    front.vai(pg, 'mkt-cont', "Object.assign(S.ct, {tab: 'plano', terr: '', fmt: ''});", 3000)
    t = pg.inner_text('#main')
    chk('Série musical (IA): 0 de 1' in t and 'meta de 12' in t, 'semana: meta 12 e a Série musical com frequência 1× por semana')
    pg.locator('[data-arr]').first.drag_to(pg.locator('.mq-dia[data-dia="2026-10-28"]')); pg.wait_for_timeout(2500)
    chk(sql(f"select data_publicacao || ' ' || dia_semana from conteudos where workspace_id = '{WS}' and titulo = 'CAC subiu e o lucro caiu'") == '2026-10-28 3', 'arrastar para quarta marca a data e o dia')
    # fechamento
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'fech';", 4000)
    t = pg.inner_text('#main')
    chk('A. Quadro de validação' in t and 'B. Mapa de capacidade' in t and 'Faltam 11 pautas fortes para a meta de 12.' in t and 'Lacunas da semana' in t, 'fechamento: validação, capacidade contra a meta e lacunas')
    pg.fill('#fForm [name=funcionou]', 'Business case'); pg.select_option('#fForm [name=foco]', 'Conversão'); pg.fill('#fForm [name=objetivo]', 'Atrair clientes'); pg.click('#fForm .pri'); pg.wait_for_timeout(3000)
    chk(sql(f"select (retro ->> 'funcionou') || ' ' || (retro ->> 'foco') || ' ' || objetivo_proxima || ' ' || semana_ini from conteudo_fechamentos where workspace_id = '{WS}'") == 'Business case Conversão Atrair clientes 2026-10-19', sql(f"select retro::text || objetivo_proxima || semana_ini from conteudo_fechamentos where workspace_id = '{WS}'") + ' quarta-feira: fecha a semana anterior (19/10), com retrospectiva e objetivo')
    chk('fechada em' in pg.inner_text('#main') and 'Fechamentos anteriores' in pg.inner_text('#main'), 'semana aparece como fechada e no histórico')
    # persona
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'persona';", 3000)
    chk(pg.locator('#pForm textarea').count() == 21 and pg.locator('#pForm input[name=objetivos]').count() == 11, 'questionário: 21 perguntas abertas e os 11 objetivos')
    for k, v in [('nicho', 'Educação online'), ('publico', 'Professores'), ('dores', 'Alunos desistem'), ('acredita', 'Aprender é rotina'), ('discorda', 'Curso longo demais'), ('formatos', 'Falando para a câmera')]: pg.fill(f'#pForm [name={k}]', v)
    pg.check('#pForm input[value="Atrair clientes"]'); pg.click('#pForm .pri'); pg.wait_for_timeout(2500)
    rr = json.loads(sql(f"select respostas from conteudo_personas where workspace_id = '{WS}'"))
    chk(rr['nicho'] == 'Educação online' and rr['objetivos'] == ['Atrair clientes'], 'respostas salvas')
    pg.click('#pGerar'); pg.wait_for_timeout(400); pg.click('#modalRoot .pri'); pg.wait_for_timeout(2500)
    chk('não respondeu' in pg.inner_text('#toast'), 'sem a função publicada, avisa e sugere copiar o pedido')
    pg.click('#modalRoot [data-x]'); pg.wait_for_timeout(300)
    chk('RESPOSTAS DO QUESTIONÁRIO' in pg.evaluate("mqPedidoIA({nicho: 'Educação online'})") and 'Qual é o nicho?\nEducação online' in pg.evaluate("mqPedidoIA({nicho: 'Educação online'})"), 'pedido para outra IA leva as respostas')
    pg.click('#pColar'); pg.wait_for_timeout(400)
    pg.fill('#modalRoot [name=txt]', 'Aqui está:\n```json\n' + json.dumps(PROP, ensure_ascii=False) + '\n```'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(3000)
    t = pg.inner_text('#main')
    chk('Linha Aurora' in t and 'Pedagogia' in t and 'Falta o objetivo comercial' in t, 'resposta colada vira proposta, com territórios e o que faltou decidir')
    pg.locator('[data-apl]').first.click(); pg.wait_for_timeout(400); pg.click('#modalRoot .pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select count(*) from conteudo_linhas where workspace_id = '{WS}'") == '7' and sql(f"select array_to_string(destinos, ',') || ' ' || meta_semanal from conteudo_config where workspace_id = '{WS}'") == 'Aurora 6', 'aplicar soma os territórios novos (sem apagar os da V18) e troca destinos e meta')
    chk('aplicada' in pg.inner_text('#main'), 'proposta marcada como aplicada')
    # linha editorial
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'linhas';", 3000)
    t = pg.inner_text('#main')
    chk('Núcleo da marca' in t and 'Aprender é rotina' in t and 'Camadas transversais' in t and 'Quadros de autoridade' in t and 'Empreendedorismo' in t, 'linha editorial: núcleo, territórios, frentes, camadas, formatos e quadros')
    pg.click('#lMet'); pg.wait_for_timeout(400); pg.select_option('#modalRoot [name=metodo]', 'notas5'); pg.click('#modalRoot .pri'); pg.wait_for_timeout(3000)
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'kanban';", 3000)
    pg.click('#cNovo'); pg.wait_for_timeout(500)
    chk(pg.locator('#modalRoot [name=ideia_n1]').count() == 1 and pg.locator('#modalRoot [name=s1]').count() == 0, 'voltar ao método antigo mostra as 5 notas de novo')
    pg.click('#modalRoot [data-x]')
    front.vai(pg, 'mkt-cont', "S.ct.tab = 'dash';", 3500)
    chk('Eficiência de cada canal' in pg.inner_text('#main'), 'dashboard dos canais abre na Estratégia de conteúdo')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
