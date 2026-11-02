"""v0.233: qualificação por pontos em blocos (Porte, Estrutura, Momento), respostas eliminatórias, grupos de regras (Produto e Temperatura)
e "pediu × indicado". Usa o próprio RODAR_v0.233b (formulário "Lead: qualificação" da Mathisa) num formulário de teste com o mesmo id.
Banco: o RODAR monta as 13 perguntas, a regra, o aviso de investimento e a mensagem final; lead grande → full brain quente; lead pequeno →
starter frio; faturamento até R$ 10 mil → não qualificado e "qualif: nutrir", sem tag de produto; pediu implementação mas é starter → revisar;
recalcular troca as tags do grupo. Tela: Qualificação e pontos com bloco, "elimina", grupos e conferência; salvar mantém a regra; Quem respondeu
mostra os pontos por bloco e "eliminado".
Banco fa (Escola Aurora, marcada como agência durante o teste). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
PID = '0d40f550-9e05-4b25-99cd-1353b221574f'
RODAR = '/home/claude/growthv2/supabase/RODAR_v0.233b_formulario_qualificacao_mathisa.sql'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots233/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id = '{PID}')")
    sql(f"delete from pesquisa_respostas where pesquisa_id = '{PID}'")
    sql(f"delete from pesquisa_perguntas where pesquisa_id = '{PID}'")
    sql(f"delete from pesquisas where id = '{PID}'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Lead T233%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
sql(f"insert into pesquisas (id, workspace_id, nome, tipo, publico, ativa) values ('{PID}', '{WS}', 'Lead: qualificação', 'lead', 'lead', false)")
sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo) values ('{WS}', '{PID}', 1, 'Pergunta antiga', 'texto')")
r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-q', '-v', 'ON_ERROR_STOP=1', '-f', RODAR], capture_output=True, text=True)
chk(r.returncode == 0, 'o RODAR_v0.233b roda sem erro', r.stderr)
chk(sql(f"select count(*) from pesquisa_perguntas where pesquisa_id = '{PID}'") == '13' and sql(f"select count(*) from pesquisa_perguntas where pesquisa_id = '{PID}' and texto = 'Pergunta antiga'") == '0', 'o formulário fica com as 13 perguntas novas (as antigas saem)')
cap = json.loads(sql(f"select captacao::text from pesquisas where id = '{PID}'"))
chk('R$ 3.500' in cap.get('aviso_texto', '') and 'WhatsApp' in cap.get('sucesso_texto', '') and cap['campos']['telefone']['obrig'], 'aviso de investimento mínimo, mensagem final com o WhatsApp e WhatsApp obrigatório', cap)
chk(sql(f"select ativa and aceita_link_aberto from pesquisas where id = '{PID}'") == 't', 'o formulário fica ativo e com link aberto')
PG = {t: (i, o) for i, t, o in [x.split('|', 2) for x in sql(f"select id || '|' || texto || '|' || array_to_string(opcoes, '¦') from pesquisa_perguntas where pesquisa_id = '{PID}'").split('\n')]}
def P(prefixo):
    k = next(k for k in PG if k.startswith(prefixo)); return PG[k][0], PG[k][1].split('¦')
def responde(nome, esc_):
    pe = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', '{nome}') returning id")
    rid = one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{PID}', '{pe}') returning id")
    for prefixo, ops in esc_.items():
        qid, opcoes = P(prefixo)
        for o in (ops if isinstance(ops, list) else [ops]):
            v = o if isinstance(o, str) and not o.isdigit() else opcoes[int(o)]
            sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{rid}', '{qid}', $${v}$$)")
    res = json.loads(sql(f"select pesquisa_qualificar('{rid}')::text"))
    return pe, rid, res
# A: R$ 100–250 mil, 2 a 3 produtos, ticket 2–10 mil, anúncios 5–20 mil, 1 a 3 anos, lançamento + perpétuo, planilhas, profissionais, implementação, agora
A = responde('Lead T233 A', {'Você vende': '2', 'Qual é o faturamento': '3', 'Quantos produtos': '1', 'Qual é o ticket': '2', 'Quanto você investe': '2', 'Como você vende': ['0', '1'],
                             'Como você acompanha': '1', 'Como está organizada': '2', 'Que tipo de ajuda': '3', 'Quando pretende': '0'})
chk(A[2]['blocos'] == {'Porte': 41, 'Estrutura': 17, 'Momento': 20} and A[2]['pontos'] == 78, 'lead A: Porte 41 · Estrutura 17 · Momento 20 = 78', A[2])
tA = sql(f"select array_to_string(tags, ',') || '|' || qualificacao || '|' || pontuacao_qualificacao from pessoas where id = '{A[0]}'")
chk('qualif: full brain' in tA and 'lead: quente' in tA and 'pediu: full brain' in tA and 'qualif: revisar' not in tA and '|qualificado|78' in tA, 'lead A: qualificado, "qualif: full brain" e "lead: quente" (pediu o mesmo: sem revisar)', tA)
# B: R$ 10–30 mil, 1 produto, até R$ 500, não investe, menos de 1 ano, perpétuo, sem rotina, sozinha, pediu implementação, avaliando
B = responde('Lead T233 B', {'Você vende': '1', 'Qual é o faturamento': '1', 'Quantos produtos': '0', 'Qual é o ticket': '0', 'Quanto você investe': '0', 'Como você vende': ['1'],
                             'Como você acompanha': '0', 'Como está organizada': '0', 'Que tipo de ajuda': '3', 'Quando pretende': '2'})
tB = sql(f"select array_to_string(tags, ',') || '|' || qualificacao from pessoas where id = '{B[0]}'")
chk(B[2]['blocos'] == {'Porte': 9, 'Estrutura': 4, 'Momento': 5} and 'qualif: starter' in tB and 'lead: frio' in tB, 'lead B: Porte 9 → "qualif: starter", total 18 → "lead: frio"', (B[2], tB))
chk('qualif: revisar' in tB, 'lead B pediu implementação mas a regra indicou Starter: "qualif: revisar"', tB)
# C: até R$ 10 mil (elimina)
C = responde('Lead T233 C', {'Você vende': '3', 'Qual é o faturamento': '0', 'Quantos produtos': '2', 'Qual é o ticket': '3', 'Quanto você investe': '3', 'Como você vende': ['0'],
                             'Como você acompanha': '3', 'Como está organizada': '3', 'Que tipo de ajuda': '1', 'Quando pretende': '0'})
tC = sql(f"select array_to_string(tags, ',') || '|' || qualificacao from pessoas where id = '{C[0]}'")
chk(C[2]['eliminado'] and tC.endswith('|nao_qualificado') and 'qualif: nutrir' in tC and 'qualif: starter' not in tC and 'lead: quente' not in tC and 'qualif: full brain' not in tC, 'faturamento até R$ 10 mil: não qualificado, "qualif: nutrir", sem tag de produto nem temperatura', tC)
D = responde('Lead T233 D', {'Você vende': '0', 'Qual é o faturamento': '2', 'Quando pretende': '0'})
chk(D[2]['eliminado'] and 'qualif: nutrir' in sql(f"select array_to_string(tags, ',') from pessoas where id = '{D[0]}'"), '"Ainda não vendo": não qualificado e "qualif: nutrir"')
det = json.loads(sql(f"select qualif_det::text from pesquisa_respostas where id = '{A[1]}'"))
chk(det.get('grupos') == {'Produto': 'qualif: full brain', 'Temperatura': 'lead: quente'}, 'a conta fica guardada na resposta (blocos e regras que bateram)', det)
# recalcular com corte de Full Brain mais alto: A vira strategy e perde a tag antiga
q_ = json.loads(sql(f"select qualif::text from pesquisas where id = '{PID}'")); q_['grupos'][0]['regras'][0]['se']['Porte']['min'] = 45
sql(f"update pesquisas set qualif = $${json.dumps(q_, ensure_ascii=False)}$$::jsonb where id = '{PID}'"); sql(f"select pesquisa_qualificar('{A[1]}')")
tA2 = sql(f"select array_to_string(tags, ',') from pessoas where id = '{A[0]}'")
chk('qualif: strategy' in tA2 and 'qualif: full brain' not in tA2 and 'qualif: revisar' in tA2, 'recalcular troca a tag do grupo (sai full brain, entra strategy) e confere de novo o pedido', tA2)
q_['grupos'][0]['regras'][0]['se']['Porte']['min'] = 32; sql(f"update pesquisas set qualif = $${json.dumps(q_, ensure_ascii=False)}$$::jsonb where id = '{PID}'"); sql(f"select pesquisa_qualificar('{A[1]}')")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{PID}'; S.pqTab = 'qual';", 4500)
    blq = pg.evaluate("() => [...document.querySelectorAll('[data-pqb]')].map(i => i.value).filter(Boolean)")
    chk(sorted(set(blq)) == ['Estrutura', 'Momento', 'Porte'], 'cada pergunta mostra o seu bloco', blq)
    chk(pg.locator('[data-pqe]:checked').count() == 2, 'as duas respostas eliminatórias aparecem marcadas "elimina"')
    chk(pg.locator('.pq-gr').count() == 2 and pg.input_value('[data-grn="0"]') == 'Produto' and pg.locator('#pqCf').is_checked(), 'aparecem os grupos Produto e Temperatura e a conferência do pedido')
    t = pg.inner_text('#pqSim')
    chk('qualif: full brain 1' in t and 'eliminados 2' in t, 'o simulador conta quantos ficam em cada tag e quantos foram eliminados', t[:300])
    pg.locator('#pqGr').scroll_into_view_if_needed(); pg.screenshot(path=SHOT + '1_regras_bloco.png', full_page=False)
    antes = json.loads(sql(f"select qualif::text from pesquisas where id = '{PID}'"))
    pg.click('#pqSalva'); pg.wait_for_timeout(3000)
    depois = json.loads(sql(f"select qualif::text from pesquisas where id = '{PID}'"))
    chk(depois.get('grupos') == antes.get('grupos') and depois.get('confere') == antes.get('confere'), 'salvar pela tela mantém os grupos e a conferência', (antes.get('grupos'), depois.get('grupos')))
    chk(sql(f"select pontos->>'bloco' from pesquisa_perguntas where pesquisa_id = '{PID}' and texto like 'Quantos produtos%'") == 'Porte' and sql(f"select (pontos->'opcoes'->'Até R$ 10 mil'->>'elim') from pesquisa_perguntas where pesquisa_id = '{PID}' and texto like 'Qual é o faturamento%'") == 'true', 'salvar mantém o bloco e o "elimina" das perguntas')
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{PID}'; S.pqTab = 'quem';", 4000)
    try: pg.wait_for_selector('#main >> text=Responderam', timeout=12000)
    except Exception: pass
    t = pg.text_content('#main'); pg.screenshot(path=SHOT + '2_quem_respondeu.png')
    chk('Porte 41 · Estrutura 17 · Momento 20' in t and 'eliminado' in t, 'Quem respondeu mostra os pontos por bloco e quem foi eliminado', t[:900])
    pg.screenshot(path=SHOT + '2_quem_respondeu.png', full_page=False)
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
