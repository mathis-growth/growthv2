"""v0.131: selo de qualificação com a pontuação no cartão e na ficha do lead, tags coloridas e a aba "Quem respondeu"
da pesquisa (pontos de cada pessoa, situação no CRM, filtro, ordem e planilha). Banco fa com a v0.130; o teste apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
NOME = 'T131 Qualificação'
def sql(q, role=None):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', (f"set role {role}; " if role else '') + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
EMS = ['t131.alta@exemplo.com', 't131.media@exemplo.com', 't131.baixa@exemplo.com']
def limpa():
    sql(f"delete from pessoas where workspace_id = '{WS}' and email in ({','.join(repr(e) for e in EMS)})")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = '{NOME}'")
limpa()
qual = json.dumps({'ativa': True, 'modo': 'soma', 'corte': 20, 'faixas': [{'min': 0, 'tag': 'frio'}, {'min': 20, 'tag': 'quente'}]})
cap = json.dumps({'ativa': True, 'campos': {'telefone': {'mostrar': False}, 'instagram': {'mostrar': False}}, 'tags': ['Formulário T131'], 'consentimentos': []})
P = sql(f"insert into pesquisas (workspace_id, nome, tipo, ativa, gatilho, aceita_link_aberto, qualif, captacao) values ('{WS}', '{NOME}', 'lead', true, 'manual', true, '{qual}', '{cap}') returning id").split('\n')[0]
Q1 = sql(f"""insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, pontos) values ('{WS}', '{P}', 1, 'Plano', 'escolha', array['A','B'], '{{"opcoes": {{"A": {{"p": 10, "tag": "Oferta sugerida: Starter"}}, "B": {{"p": 0}}}}}}') returning id""").split('\n')[0]
Q2 = sql(f"""insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, pontos) values ('{WS}', '{P}', 2, 'Começa já?', 'escolha', array['Sim','Não'], '{{"opcoes": {{"Sim": {{"p": 15}}, "Não": {{"p": 0}}}}}}') returning id""").split('\n')[0]
TOK = sql(f"select token_aberto from pesquisas where id = '{P}'")
for em, (a, b), nm in zip(EMS, [('A', 'Sim'), ('B', 'Sim'), ('A', 'Não')], ['Ana Alta', 'Bia Média', 'Caio Baixo']):
    sql(f"""select pesquisa_captar('{TOK}', '{{"{Q1}": "{a}", "{Q2}": "{b}"}}'::jsonb, '{{"nome": "{nm}", "email": "{em}"}}'::jsonb, '{{}}'::jsonb)""", 'anon')
pts = sql(f"select string_agg(pontuacao_qualificacao::text || ':' || qualificacao, ',' order by email) from pessoas where email in ({','.join(repr(e) for e in EMS)})")
chk(pts == '25.00:qualificado,10.00:nao_qualificado,15.00:nao_qualificado', 'banco: pontuação e qualificação de cada um (%s)' % pts)
ID1 = sql(f"select id from pessoas where email = '{EMS[0]}'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, vw=1500, vh=1000)
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'quem'; S.pqRv = null;")
    t = pg.inner_text('#main')
    chk('Quem respondeu' in t and 'Responderam\n3' in t and 'Qualificados\n1' in t and 'Não qualificados\n2' in t, 'aba Quem respondeu com 3 pessoas, 1 qualificada e 2 não')
    chk('16,67 pts' in t, 'pontuação média (25 + 15 + 10) ÷ 3 = 16,67')
    linhas = pg.evaluate("[...document.querySelectorAll('#pqBody tbody tr')].map(r => [r.children[1].innerText.split('\\n')[0], r.children[2].innerText])")
    chk(linhas == [['Ana Alta', '25 pts'], ['Bia Média', '15 pts'], ['Caio Baixo', '10 pts']], 'ordenado da maior para a menor pontuação %s' % linhas)
    chk(pg.locator('#pqBody tbody tr').first.locator('.selo.q').count() == 1 and pg.locator('#pqBody .selo.n').count() == 2, 'selo verde do qualificado e vermelho dos não qualificados')
    tg = pg.evaluate("[...document.querySelectorAll('#pqBody tbody tr')[0].querySelectorAll('.tg')].map(x => x.textContent + '|' + x.style.getPropertyValue('--tc'))")
    chk('Oferta sugerida: Starter|#7C3AED' in tg and 'quente|#059669' in tg, 'tags da resposta coloridas (oferta roxa, faixa quente verde) %s' % tg)
    pg.select_option('#rF', 'qualificado'); pg.wait_for_timeout(2500)
    chk(pg.locator('#pqBody tbody tr').count() == 1, 'filtro "Qualificado" mostra só 1')
    pg.select_option('#rF', ''); pg.wait_for_timeout(2500)
    with pg.expect_download() as d: pg.click('#rCsv')
    csv = open(d.value.path(), encoding='utf-8-sig').read().splitlines()
    chk(csv[0].startswith('Quando;Nome;E-mail;Pontos;Pela regra;No CRM;Tags;Plano;Começa já?') and len(csv) == 4 and ';25;Qualificado;Qualificado;' in csv[1], 'planilha com pontos, situação e respostas de cada um')
    # CRM: cartão com o selo e a pontuação, tags coloridas
    front.vai(pg, 'crm-leads', "S.cr = null;", 5000)
    card = pg.locator(f'.card:has([data-f="{ID1}"])')
    chk(card.locator('.selo.q').count() == 1 and '25 pts' in card.locator('.selo').inner_text(), 'cartão do CRM: selo verde "Qualificado" com 25 pts')
    cores = card.evaluate("c => [...c.querySelectorAll('.tg')].map(x => getComputedStyle(x).backgroundColor)")
    chk(len(cores) >= 2 and len(set(cores)) >= 2 and all(c != 'rgba(0, 0, 0, 0)' for c in cores), 'cartão do CRM: tags com cores diferentes %s' % cores)
    card.locator(f'[data-f="{ID1}"]').click(); pg.wait_for_timeout(2500)
    chk(pg.locator('#modalRoot .selo.q').count() >= 1 and pg.locator('#modalRoot .tg').count() >= 3, 'ficha do lead: selo e tags coloridas no topo')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
