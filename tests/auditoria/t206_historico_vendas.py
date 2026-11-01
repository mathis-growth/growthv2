"""v0.206: Importar histórico de vendas (primeira carga) e o histórico na ficha. Banco fa (Escola Aurora), com
20261203100000_historico_vendas.sql. Importa um relatório no formato de plataforma (cabeçalhos em português, aspas, vírgula
decimal, status variados), confere, importa, vê a ficha, o planejamento e desfaz. Apaga o que criou."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots206/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    for l in sql(f"select id from importacoes_historico where workspace_id = '{WS}' and desfeito_em is null").split():
        sql(f"select desfazer_importacao_historico('{l}')") if False else None
    sql(f"delete from vendas_historicas where workspace_id = '{WS}'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and email like '%@hist.test'")
    sql(f"delete from importacoes_historico where workspace_id = '{WS}'")
    sql(f"update pessoas set status_funil = 'lead', status_cliente = null, convertido_em = null where workspace_id = '{WS}' and email = 'lead2@aurora.test'")
limpa()
CSV = '﻿' + '\n'.join([
  'Transação;Produto;Nome do Comprador;Email do Comprador;Telefone;Data de Aprovação;Valor da Compra;Status',
  'HP001;Curso Alfa;"Silva, Maria";maria@hist.test;(11) 98888-0001;10/01/2025;"1.997,00";Aprovado',
  'HP002;Curso Alfa;João Souza;joao@hist.test;(11) 98888-0002;15/02/2025;997,00;Completo',
  'HP003;Mentoria;Maria Silva;maria@hist.test;;20/06/2025;4.000,00;Aprovado',
  'HP004;Curso Alfa;Ana Reembolso;ana@hist.test;;03/03/2025;997,00;Reembolsado',
  'HP005;Curso Alfa;Boleto Aberto;boleto@hist.test;;04/03/2025;997,00;Aguardando pagamento',
  'HP006;Curso Alfa;Carlos Cancel;carlos@hist.test;;05/03/2025;997,00;Cancelado',
  'HP007;Curso Alfa;Lead Antigo;lead2@aurora.test;;12/08/2025;500,00;Aprovado',
  'HP008;Curso Alfa;Já no Growths;lead47@aurora.test;;06/07/2026;47,00;Aprovado',
  'HP009;Curso Alfa;Data Ruim;ruim@hist.test;;31/02/2025;100,00;Aprovado',
  'HP001;Curso Alfa;"Silva, Maria";maria@hist.test;(11) 98888-0001;10/01/2025;"1.997,00";Aprovado',
  'HP010;Curso Beta;Dora Chargeback;dora@hist.test;;09/09/2025;300,00;Chargeback'])
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-01', vw=1440, vh=1000)
    front.vai(pg, 'cfg-importar', '', 5000)
    chk(pg.locator('#hvPainel').count() == 1 and 'Nenhuma carga de histórico' in pg.inner_text('#hvPainel'), 'Importar e validar dados: painel "Histórico de vendas"')
    pg.click('#hvNovo'); pg.wait_for_timeout(600)
    pg.select_option('#modalRoot [name=plat]', 'Hotmart')
    pg.set_input_files('#modalRoot [name=arq]', files=[{'name': 'vendas_hotmart.csv', 'mimeType': 'text/csv', 'buffer': CSV.encode('utf-8')}]); pg.wait_for_timeout(1200)
    mapa = pg.evaluate("Object.fromEntries([...document.querySelectorAll('#modalRoot [data-hvm]')].map(s => [s.dataset.hvm, s.options[s.selectedIndex].text]))")
    chk(mapa == {'data': 'Data de Aprovação', 'valor': 'Valor da Compra', 'status': 'Status', 'email': 'Email do Comprador', 'nome': 'Nome do Comprador', 'telefone': 'Telefone', 'produto': 'Produto', 'id_externo': 'Transação'}, 'de-para automático pelos nomes das colunas: ' + json.dumps(mapa, ensure_ascii=False))
    st = pg.evaluate("Object.fromEntries([...document.querySelectorAll('#modalRoot [data-hvs]')].map(s => [s.dataset.hvs, s.value]))")
    chk(st == {'Aprovado': 'aprovada', 'Completo': 'aprovada', 'Reembolsado': 'reembolsada', 'Aguardando pagamento': '', 'Cancelado': 'cancelada', 'Chargeback': 'chargeback'}, 'status do arquivo traduzidos (aguardando pagamento não é venda): ' + json.dumps(st, ensure_ascii=False))
    pg.screenshot(path=SHOT + '1_depara.png', full_page=True)
    pg.click('#hvConf'); pg.wait_for_timeout(2500)
    t = pg.inner_text('#hvRes')
    chk('Nada foi gravado' in t and sql(f"select count(*) from vendas_historicas where workspace_id = '{WS}'") == '0', 'conferir não grava nada')
    R = pg.evaluate("(async () => { const A = document.querySelector('#hvRes'); return A.textContent; })()")
    chk('Vendas a importar\n7' in t and '4 aprovada(s) · 1 reembolsada(s) · 2 cancelada(s)/chargeback' in t, 'conferência: 7 vendas (sem boleto, repetida, já no Growths e data inválida): ' + t[:200].replace('\n', ' | '))
    chk('7.494,00' in t, 'valor aprovado: 1.997 + 997 + 4.000 + 500 = 7.494: ' + t[t.find('Valor aprovado'):][:60].replace('\n', ' '))
    chk('1 repetida' in t and '1 já no Growths' in t and '1 com erro' in t and '1 não são venda' in t, 'fora da carga: 1 não é venda, 1 repetida, 1 já no Growths, 1 com erro')
    pg.screenshot(path=SHOT + '2_conferido.png', full_page=True)
    pg.check('#modalRoot [name=confirmo]'); pg.click('#modalRoot .acts button.pri[type=submit]'); pg.wait_for_timeout(3500)
    lote = json.loads(sql(f"select row_to_json(x)::text from importacoes_historico x where workspace_id = '{WS}'"))
    chk(lote['vendas'] == 7 and lote['pessoas_novas'] == 5 and str(lote['periodo_ini']) == '2025-01-10' and float(lote['valor_aprovado']) == 7494.0, 'carga registrada: 7 vendas, 5 pessoas novas, desde 10/01/2025: ' + str({k: lote[k] for k in ('vendas', 'pessoas_novas', 'periodo_ini', 'valor_aprovado')}))
    chk(sql(f"select count(*) from vendas where workspace_id = '{WS}' and id_externo like 'HP%'") == '0', 'nada entrou na tabela de vendas (sem financeiro, comissão, automação)')
    chk(sql(f"select status_funil || '|' || status_cliente || '|' || to_char(convertido_em at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') from pessoas where workspace_id = '{WS}' and email = 'maria@hist.test'") == 'cliente|inativo|2025-01-10', 'pessoa nova: cliente desde a primeira compra')
    chk(sql(f"select status_funil || '|' || to_char(convertido_em at time zone 'America/Sao_Paulo', 'YYYY-MM-DD') from pessoas where workspace_id = '{WS}' and email = 'lead2@aurora.test'") == 'cliente|2025-08-12', 'lead que já existia e comprou antes vira cliente desde a compra')
    chk(sql(f"select status_funil from pessoas where workspace_id = '{WS}' and email = 'ana@hist.test'") == 'lead', 'quem só reembolsou entra como lead')
    t = pg.inner_text('#hvPainel')
    chk('Hotmart' in t and 'importada' in t and 'Desfazer' in t, 'a carga aparece no painel, com Desfazer')
    # ficha
    pid = sql(f"select id from pessoas where workspace_id = '{WS}' and email = 'maria@hist.test'")
    pg.evaluate("id => fichaPessoa(id)", pid); pg.wait_for_timeout(3000)
    t = pg.inner_text('#modalRoot')
    chk('ANTES DO GROWTHS (HISTÓRICO IMPORTADO)' in t.upper() and '10/01/2025' in t and 'Compra antes do Growths (histórico importado)' in t, 'ficha: bloco "Antes do Growths" e as compras na linha do tempo: ' + t[:300].replace('\n', ' | '))
    pg.locator('#modalRoot .modal').screenshot(path=SHOT + '3_ficha.png')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    # planejamento: o histórico entra nas sugestões
    sg = json.loads(sql("begin; select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\",\"role\":\"authenticated\"}', true); select plano_anual_sugestoes('%s', 2026, '2026-11-01')::text; commit;" % WS).split('\n')[1])
    rec25 = float(sql(f"select coalesce(sum(valor_bruto), 0) from vendas where workspace_id = '{WS}' and status = 'aprovada' and extract(year from data_venda at time zone 'America/Sao_Paulo') = 2025")) + 7494
    chk(abs(float(sg['receita_ano_anterior']) - rec25) < 0.01 and sg['historico_vendas'] == 7, 'planejamento 2026: receita de 2025 soma o histórico (%.2f)' % rec25)
    # desfazer
    pg.click('#hvPainel [data-hvx]'); pg.wait_for_timeout(500); pg.click('#modalRoot button.pri'); pg.wait_for_timeout(3500)
    chk(sql(f"select count(*) from vendas_historicas where workspace_id = '{WS}'") == '0' and sql(f"select count(*) from pessoas where workspace_id = '{WS}' and email like '%@hist.test'") == '0' and 'desfeita' in pg.inner_text('#hvPainel'), 'desfazer apaga as vendas e as pessoas criadas pela carga')
    chk(sql(f"select count(*) from pessoas where workspace_id = '{WS}' and email = 'lead2@aurora.test'") == '1', 'quem já existia antes da carga fica')
    erros = pg.errs; chk(not erros, 'sem erro de JavaScript ' + str(erros[:3]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
