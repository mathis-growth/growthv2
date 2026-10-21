"""v0.129: (1) "Movimento por dia" da campanha num gráfico só, com botões para escolher as métricas;
(2) qualificação por pontos nas pesquisas: pontos por opção (ou nota × peso), tags, soma ou média, nota de corte e faixas;
grava na pessoa ao responder e pelo "Recalcular". Banco fa com RODAR_v0.129_qualificacao.sql; o teste cria a pesquisa T129 e apaga no fim."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
PERP = '284b5d0b-cab8-431e-836c-47983435a0d1'
MIG = '/home/claude/growths/supabase/RODAR_v0.129_qualificacao.sql'
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr)
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-q', '-v', 'ON_ERROR_STOP=1', '-f', MIG], check=True, capture_output=True)
PESS = sql(f"select string_agg(id::text, ',') from (select id from pessoas where workspace_id = '{WS}' order by criado_em limit 6) x").split(',')
ANTES = sql(f"select json_agg(json_build_object('id', id, 'q', qualificacao, 'p', pontuacao_qualificacao, 't', tags)) from pessoas where id in ({','.join(repr(x) for x in PESS)})")
def limpa():
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome like 'T129 %'")
    for o in json.loads(ANTES):
        sql("update pessoas set qualificacao = %s, pontuacao_qualificacao = %s, tags = %s where id = '%s'" % ("'%s'" % o['q'] if o['q'] else 'null', o['p'] if o['p'] is not None else 'null',
            "array[%s]::text[]" % ','.join("'%s'" % t.replace("'", "''") for t in o['t']) if o['t'] else "'{}'::text[]", o['id']))
limpa()
P = sql(f"insert into pesquisas (workspace_id, nome, tipo, ativa, gatilho) values ('{WS}', 'T129 Qualificação', 'lead', true, 'manual') returning id").split('\n')[0]
Q1 = sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes) values ('{WS}', '{P}', 1, 'Nível', 'escolha', array['Básico','Avançado']) returning id").split('\n')[0]
Q2 = sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes) values ('{WS}', '{P}', 2, 'Interesses', 'multipla', array['Viagem','Trabalho','Prova']) returning id").split('\n')[0]
Q3 = sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo) values ('{WS}', '{P}', 3, 'Urgência', 'escala') returning id").split('\n')[0]
Q4 = sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo) values ('{WS}', '{P}', 4, 'Começa já?', 'sim_nao') returning id").split('\n')[0]
# 5 respostas antigas (antes da regra)
RESP = [('Básico', ['Viagem'], 1, 'nao'), ('Avançado', ['Trabalho', 'Prova'], 5, 'sim'), ('Básico', ['Trabalho'], 3, 'sim'), ('Avançado', [], 2, 'nao'), ('Básico', ['Prova', 'Viagem'], 4, 'sim')]
for i, (a, b, c, d) in enumerate(RESP):
    rid = sql(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{P}', '{PESS[i]}') returning id").split('\n')[0]
    sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{rid}', '{Q1}', '{a}')")
    for x in b: sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{rid}', '{Q2}', '{x}')")
    sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num) values ('{WS}', '{rid}', '{Q3}', {c})")
    sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num, valor_texto) values ('{WS}', '{rid}', '{Q4}', {1 if d == 'sim' else 0}, '{d}')")
# regra: Básico 5, Avançado 15 (tag avancado); Trabalho 10 (tag trabalho), Prova 5; urgência × 2; sim 10. Corte 30; faixas 0 frio, 30 quente
def pontos(r):
    a, b, c, d = r; return (5 if a == 'Básico' else 15) + (10 if 'Trabalho' in b else 0) + (5 if 'Prova' in b else 0) + 2 * c + (10 if d == 'sim' else 0)
ESP = [pontos(r) for r in RESP]
try:
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1600, vh=1000)
        erros = []; pg.on('pageerror', lambda e: erros.append(str(e)))
        # ---------------- (1) gráfico único na campanha ----------------
        front.vai(pg, 'mkt-camp', f"S.campSel = '{PERP}'; S.campTab = 'dash'; S.cp128 = null;", 12000)
        L = pg.locator('#cpLinhas')
        chk(L.locator('svg.gc').count() == 1 and L.locator('[data-cpm]').count() == 9, 'Movimento por dia: um gráfico só, 9 métricas para escolher')
        chk(L.locator('[data-cpm].on').count() == 4 and L.locator('svg polyline').count() >= 4, 'abre com 4 métricas ligadas (investimento, leads, vendas, CTR)')
        for k in ['inv', 'vendas', 'ctr']: pg.click(f'[data-cpm="{k}"]')
        pg.wait_for_timeout(300)
        chk(L.locator('[data-cpm].on').count() == 1 and 'Uma métrica: o eixo mostra o valor' in L.inner_text() and L.locator('svg text').count() > 5, 'só leads: eixo com valores e a meta tracejada')
        pg.click('[data-cpmall="1"]'); pg.wait_for_timeout(300)
        chk(L.locator('[data-cpm].on').count() == 9, '"Todas" liga as 9')
        box = L.locator('svg').bounding_box(); pg.mouse.move(box['x'] + box['width'] * .5, box['y'] + 100); pg.wait_for_timeout(300)
        chk(L.locator('.cp-mt').is_visible() and L.locator('.cp-mt span').count() == 9, 'passar o mouse mostra os valores do dia de todas')
        pg.click('[data-cpmall="0"]'); pg.wait_for_timeout(300)
        chk(L.locator('[data-cpm].on').count() == 0 and 'Escolha pelo menos uma métrica' in L.inner_text(), '"Limpar" desliga todas')
        # ---------------- (2) qualificação por pontos ----------------
        front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'qual';", 7000)
        chk(pg.locator('#pqBody .pq-pt').count() == 2 + 3 + 2 and pg.locator('[data-peso]').count() == 1, 'cada opção (e o sim/não) tem pontos e tag; a escala tem peso')
        for op, v, tag in [('Básico', 5, ''), ('Avançado', 15, 'avancado'), ('Trabalho', 10, 'trabalho'), ('Prova', 5, ''), ('sim', 10, '')]:
            pg.fill(f'.pq-pt[data-op="{op}"]', str(v))
            if tag: pg.fill(f'.pq-tg[data-op="{op}"]', tag)
        pg.fill('[data-peso]', '2'); pg.check('#pqAtiva'); pg.fill('#pqCorte', '30')
        for mn, tg in [('0', 'frio'), ('30', 'quente')]:
            pg.click('#pqFxN'); pg.fill('[data-fxm] >> nth=-1', mn); pg.fill('[data-fxt] >> nth=-1', tg)
        pg.wait_for_timeout(500)
        nq = sum(1 for x in ESP if x >= 30)
        chk(('%d qualificado(s)' % nq) in pg.inner_text('#pqSim'), 'simulador: %d de 5 qualificados com corte 30 (pontos %s)' % (nq, ESP))
        chk('vai de' in pg.inner_text('#pqMax'), 'mostra a pontuação mínima e máxima possível')
        pg.click('#pqSalva'); pg.wait_for_timeout(4000)
        cfg = json.loads(sql(f"select qualif from pesquisas where id = '{P}'"))
        chk(cfg['ativa'] and cfg['corte'] == 30 and cfg['modo'] == 'soma' and len(cfg['faixas']) == 2, 'regra salva na pesquisa')
        front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'qual';", 7000)
        pg.click('#pqRecalc'); pg.wait_for_timeout(5000)
        R = [sql(f"select pontuacao_qualificacao::int || '|' || qualificacao || '|' || array_to_string(tags, ',') from pessoas where id = '{PESS[i]}'") for i in range(5)]
        ok = all(int(R[i].split('|')[0]) == ESP[i] and R[i].split('|')[1] == ('qualificado' if ESP[i] >= 30 else 'nao_qualificado') for i in range(5))
        chk(ok, 'recalcular grava pontos e qualificação de quem já respondeu (%s)' % R)
        chk('avancado' in R[1] and 'trabalho' in R[1] and 'quente' in R[1] and 'frio' not in R[1], 'tags das opções e da faixa vão para a pessoa (%s)' % R[1])
        chk('frio' in R[0] and 'quente' not in R[0], 'abaixo do corte fica com a tag da faixa de baixo (%s)' % R[0])
        # média
        sql(f"update pesquisas set qualif = jsonb_set(qualif, '{{modo}}', '\"media\"') where id = '{P}'")
        pg.evaluate(f"sb.rpc('pesquisa_requalificar', {{ p_pesquisa: '{P}' }})"); pg.wait_for_timeout(2000)
        m0 = float(sql(f"select pontuacao_qualificacao from pessoas where id = '{PESS[1]}'"))
        chk(abs(m0 - ESP[1] / 4) < 0.01, 'modo média: pontos ÷ perguntas respondidas (%.2f = %.2f)' % (m0, ESP[1] / 4))
        sql(f"update pesquisas set qualif = jsonb_set(qualif, '{{modo}}', '\"soma\"') where id = '{P}'")
        # quem responde pelo link já sai qualificado
        tok = sql(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, token, status) values ('{WS}', '{P}', '{PESS[5]}', md5(random()::text) || md5(random()::text), 'enviado') returning token").split('\n')[0]
        r = pg.evaluate("([t, a, b, c, d]) => sb.rpc('pesquisa_responder', { p_token: t, p_respostas: { [a]: 'Avançado', [b]: ['Trabalho'], [c]: 4, [d]: 'sim' } }).then(r => r.error ? r.error.message : 'ok')", [tok, Q1, Q2, Q3, Q4])
        x = sql(f"select pontuacao_qualificacao::int || '|' || qualificacao from pessoas where id = '{PESS[5]}'")
        chk(r == 'ok' and x == '43|qualificado', 'ao responder pelo link, a pessoa já é pontuada e qualificada (%s, %s)' % (r, x))
        chk(not erros, 'sem erro de JavaScript ' + (str(erros[:2]) if erros else ''))
        b.close()
finally:
    limpa()
    chk(sql(f"select count(*) from pesquisas where workspace_id = '{WS}' and nome like 'T129 %'") == '0', 'pesquisa de teste apagada e pessoas devolvidas como estavam')
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
