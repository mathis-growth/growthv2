"""v0.161: modelo de pesquisa "Must-have: consultoria de desenvolvimento de produto" e a leitura do must-have nos Resultados.
Banco fa (Escola Aurora). Cria a pesquisa pelo modelo, grava respostas de teste direto no banco e apaga tudo no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
NOME = 'Must-have: consultoria de desenvolvimento de produto'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots161/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa(): sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = '{NOME}'")
limpa()
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-26', vw=1440, vh=1000)
    front.vai(pg, 'gro-pesq', "S.pqSel = null;", 4000)
    chk(pg.locator('#pqModelo option[value=must_servico]').count() == 1, 'modelo "Must-have: consultoria" na lista de modelos')
    pg.select_option('#pqModelo', 'must_servico'); pg.wait_for_timeout(600)
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    P = sql(f"select id from pesquisas where workspace_id = '{WS}' and nome = '{NOME}'")
    chk(bool(P), 'modelo cria a pesquisa')
    c = json.loads(sql(f"select json_build_object('n', count(*), 'sec', count(distinct secao), 'pmf', count(*) filter (where papel = 'pmf'), 'obr', count(*) filter (where obrigatoria), 'primeira', (select texto from pesquisa_perguntas where pesquisa_id = '{P}' order by ordem limit 1)) from pesquisa_perguntas where pesquisa_id = '{P}'"))
    chk(c['n'] == 25 and c['sec'] == 6 and c['pmf'] == 1 and c['primeira'].startswith('Imagine que a consultoria'), '25 perguntas em 6 passos; a primeira é a do desapontamento (papel PMF) ' + str(c))
    chk(sql(f"select tipo || '|' || gatilho || '|' || ativa || '|' || (descricao like 'Oi! Quero entender%') from pesquisas where id = '{P}'") == 'outra|manual|false|true', 'pesquisa manual, desativada até revisar, com o texto de abertura')
    pg.screenshot(path=SHOT + '1_perguntas.png', full_page=True); erros += pg.errs
    # respostas de teste: 3 muito desapontada, 2 um pouco, 1 não ficaria, 1 não se aplica
    Q1 = sql(f"select id from pesquisa_perguntas where pesquisa_id = '{P}' order by ordem limit 1")
    opc = ['Muito desapontada'] * 3 + ['Um pouco desapontada'] * 2 + ['Não ficaria desapontada: não achei tão útil', 'Não se aplica: ainda não usei o que foi entregue']
    for i, o in enumerate(opc):
        R = sql(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, email) values ('{WS}', '{P}', 't161.{i}@exemplo.com.br') returning id").split('\n')[0]
        sql(f"insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_texto) values ('{WS}', '{R}', '{Q1}', '{o}')")
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'res';", 4500)
    t = pg.inner_text('.pq-pmf')
    chk('50%' in t and '3 de 6' in t and '1 "Não se aplica" fora da base' in t, 'must-have: 50% (3 de 6), sem contar "Não se aplica" ' + repr(t[:160]))
    chk('Sinal de must-have (40% ou mais)' in t and pg.locator('.pq-pmf .sem-p-fav').count() == 1, 'faixa do roteiro: 40% ou mais = sinal de must-have, em verde')
    pg.locator('.pq-pmf').screenshot(path=SHOT + '2_leitura.png'); pg.screenshot(path=SHOT + '3_resultados.png', full_page=True)
    # duas "muito" viram "um pouco": 1 de 6 = 16,7% -> baixo
    sql(f"update pesquisa_resposta_itens set valor_texto = 'Um pouco desapontada' where pergunta_id = '{Q1}' and valor_texto = 'Muito desapontada' and resposta_id in (select id from pesquisa_respostas where pesquisa_id = '{P}' and email in ('t161.0@exemplo.com.br', 't161.1@exemplo.com.br'))")
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'res';", 4000)
    t = pg.inner_text('.pq-pmf')
    chk('16,7%' in t and 'baixo must-have' in t and pg.locator('.pq-pmf .sem-p-desf').count() == 1, 'abaixo de 25%: sinal de baixo must-have, em vermelho')
    erros += pg.errs
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
