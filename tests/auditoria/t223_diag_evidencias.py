"""v0.223: Growth's Brain, Diagnóstico Inteligente D1 — o diagnóstico da empresa e a Central de Evidências.
Banco: diagnóstico sem formulário, histórico de status, registro de arquivo da equipe (hash, duplicidade, versão, tipo, tamanho), confirmação
só com o arquivo no Storage, classificação manual × sugerida, período, arquivar, processamento, permissão, arquivos do cliente entrando
pelo link, progresso. Tela: lista, novo diagnóstico, abas, envio, repetido, tipo falso, classificação, leitura de planilhas e volta,
validação e decisões, tela antiga de planilhas, celular. Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess, hashlib; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SP = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/'
SHOT = SP + 'shots223/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def erro(q):
    try: sql(q); return ''
    except Exception as e: return str(e)
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
CL = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}', true), "
J = lambda q: json.loads(sql(CL + q).split('|', 1)[1])
F = lambda q: sql(CL + q).split('|', 1)[1]
H = lambda t: hashlib.sha256(t).hexdigest()
def limpa():
    sql(f"delete from pesquisa_arquivos where workspace_id = '{WS}' and (origem = 'equipe' or nome like 't223%')")
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T223%'")
    sql(f"delete from pesquisa_respostas where workspace_id = '{WS}' and pesquisa_id in (select id from pesquisas where workspace_id = '{WS}' and nome = 'T223 diag')")
    sql(f"delete from pesquisa_envios where workspace_id = '{WS}' and pesquisa_id in (select id from pesquisas where workspace_id = '{WS}' and nome = 'T223 diag')")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = 'T223 diag'")
    sql(f"delete from equipe where workspace_id = '{WS}' and nome = 'Ana T223'")
    sql("delete from storage.objects where bucket_id = 'diagnostico' and name like '%/diag/%'")
limpa()
EQ = sql(f"insert into equipe (workspace_id, nome, email) values ('{WS}', 'Ana T223', 'ana.t223@exemplo.com') returning id").split('\n')[0]
D = sql(f"insert into diagnosticos (workspace_id, titulo, responsavel_id, periodo_ini, periodo_fim) values ('{WS}', 'T223 Diagnóstico', '{EQ}', '2026-01-01', '2026-10-31') returning id").split('\n')[0]
chk(sql(f"select status || ':' || coalesce(resposta_id::text, 'sem') from diagnosticos where id = '{D}'") == 'rascunho:sem', 'diagnóstico nasce sem formulário (só a empresa), em coleta')
chk(sql(f"select texto from diagnostico_decisoes where diagnostico_id = '{D}'") == 'Diagnóstico criado (Em coleta)', 'histórico registra a criação')
chk('responsável precisa ser da equipe' in erro(f"update diagnosticos set responsavel_id = gen_random_uuid() where id = '{D}'") or 'violates foreign key' in erro(f"update diagnosticos set responsavel_id = gen_random_uuid() where id = '{D}'"), 'responsável fora da equipe é recusado')
chk('fim' in erro(f"update diagnosticos set periodo_fim = '2025-01-01' where id = '{D}'") or 'periodo_ck' in erro(f"update diagnosticos set periodo_fim = '2025-01-01' where id = '{D}'"), 'período com o fim antes do começo é recusado')
# registro de arquivo pela equipe
C1 = b'data;produto;valor\n2026-01-05;Curso A;497\n'
R1 = J(f"diagnostico_arquivo_registrar('{D}', 't223 vendas jan.csv', {len(C1)}, 'text/csv', '{H(C1)}', 'vendas', 'sugerida')")
chk(not R1['duplicado'] and R1['caminho'].startswith(WS + '/diag/' + D + '/') and R1['versao'] == 1, 'arquivo registrado no caminho do diagnóstico (versão 1)', R1)
chk('não chegou' in erro(CL + f"diagnostico_arquivo_confirmar('{R1['id']}')"), 'sem o arquivo no Storage, a confirmação é recusada')
sql(f"insert into storage.objects (bucket_id, name) values ('diagnostico', '{R1['caminho']}')"); F(f"diagnostico_arquivo_confirmar('{R1['id']}')")
chk(sql(f"select status || ':' || processamento || ':' || classe || ':' || classe_origem from pesquisa_arquivos where id = '{R1['id']}'") == 'enviado:aguardando:vendas:sugerida', 'confirmado: enviado, aguardando leitura, classificação sugerida')
R2 = J(f"diagnostico_arquivo_registrar('{D}', 'outro nome.csv', {len(C1)}, 'text/csv', '{H(C1)}')")
chk(R2['duplicado'] and R2['id'] == R1['id'] and sql(f"select count(*) from pesquisa_arquivos where diagnostico_id = '{D}'") == '1', 'mesmo conteúdo com outro nome: não entra de novo (repetido)', R2)
C2 = C1 + b'2026-01-06;Curso A;497\n'
R3 = J(f"diagnostico_arquivo_registrar('{D}', 'T223 Vendas Jan.csv', {len(C2)}, 'text/csv', '{H(C2)}')")
chk(R3['versao'] == 2, 'mesmo nome com conteúdo novo vira versão 2', R3)
chk('não aceito' in erro(CL + f"diagnostico_arquivo_registrar('{D}', 'virus.exe', 10, null, '{H(b'x')}')"), 'extensão não aceita é recusada')
chk('20 MB' in erro(CL + f"diagnostico_arquivo_registrar('{D}', 'grande.pdf', 30000000, null, '{H(b'y')}')"), 'arquivo acima de 20 MB é recusado')
chk('conferir o conteúdo' in erro(CL + f"diagnostico_arquivo_registrar('{D}', 'a.pdf', 10, null, 'abc')"), 'sem hash válido é recusado')
R4 = J(f"diagnostico_arquivo_registrar('{D}', 't223 foto.png', 10, 'image/png', '{H(b'png')}')")
chk(sql(f"select processamento from pesquisa_arquivos where id = '{R4['id']}'") == 'so_guardar', 'imagem fica só guardada (não entra na fila de leitura)')
# classificação: a sugerida não troca a manual
F(f"diagnostico_arquivo_editar('{R1['id']}', '{{\"classe\":\"financeiro\",\"classe_origem\":\"manual\"}}')")
F(f"diagnostico_arquivo_editar('{R1['id']}', '{{\"classe\":\"vendas\",\"classe_origem\":\"sugerida\"}}')")
chk(sql(f"select classe || ':' || classe_origem from pesquisa_arquivos where id = '{R1['id']}'") == 'financeiro:manual', 'a classificação sugerida não troca a escolhida à mão')
F(f"diagnostico_arquivo_editar('{R1['id']}', '{{\"periodo_ini\":\"2026-01-01\",\"periodo_fim\":\"2026-01-31\",\"dados_pessoais\":true}}')")
chk(sql(f"select periodo_ini || ':' || periodo_fim || ':' || dados_pessoais from pesquisa_arquivos where id = '{R1['id']}'") == '2026-01-01:2026-01-31:true', 'período representado e dados pessoais salvos')
chk('periodo_ck' in erro(CL + f"diagnostico_arquivo_editar('{R1['id']}', '{{\"periodo_fim\":\"2025-12-01\"}}')"), 'período do arquivo com fim antes do começo é recusado')
F(f"diagnostico_arquivo_arquivar('{R1['id']}', true)")
chk(sql(f"select arquivado_em is not null from pesquisa_arquivos where id = '{R1['id']}'") == 't', 'arquivar marca o arquivo (o original continua guardado)')
R5 = J(f"diagnostico_arquivo_registrar('{D}', 'de novo.csv', {len(C1)}, 'text/csv', '{H(C1)}')")
chk(not R5['duplicado'], 'arquivado não conta como repetido'); sql(f"delete from pesquisa_arquivos where id = '{R5['id']}'")
F(f"diagnostico_arquivo_arquivar('{R1['id']}', false)")
F(f"diagnostico_arquivo_processamento('{R1['id']}', 'erro', 'Coluna de data vazia')")
chk(sql(f"select processamento || ':' || processamento_erro from pesquisa_arquivos where id = '{R1['id']}'") == 'erro:Coluna de data vazia', 'erro de leitura fica registrado com o motivo')
F(f"diagnostico_arquivo_processamento('{R1['id']}', 'lido')")
chk(sql(f"select processamento || ':' || (processamento_erro is null) || ':' || (processado_em is not null) from pesquisa_arquivos where id = '{R1['id']}'") == 'lido:true:true', 'reprocessar limpa o erro e marca a data')
OUTRO = "select set_config('request.jwt.claims', '{\"sub\":\"00000000-0000-0000-0000-0000000bbbbb\"}', true), "
chk('não encontrado' in erro(OUTRO + f"diagnostico_arquivo_registrar('{D}', 'x.csv', 5, null, '{H(b'z')}')") and 'não encontrado' in erro(OUTRO + f"diagnostico_arquivo_editar('{R1['id']}', '{{}}')"), 'quem não é da empresa não registra nem edita arquivo')
chk(sql("select has_table_privilege('authenticated', 'diagnostico_decisoes', 'UPDATE') or has_table_privilege('authenticated', 'diagnostico_decisoes', 'DELETE') or has_table_privilege('authenticated', 'pesquisa_arquivos', 'INSERT') or has_table_privilege('authenticated', 'pesquisa_arquivos', 'UPDATE')") == 'f', 'histórico não se edita nem se apaga; arquivos só mudam pelas funções')
# status e histórico
sql(f"update diagnosticos set status = 'em_analise' where id = '{D}'"); sql(f"update diagnosticos set status = 'validado' where id = '{D}'")
chk(sql(f"select validado_em is not null from diagnosticos where id = '{D}'") == 't' and sql(f"select count(*) from diagnostico_decisoes where diagnostico_id = '{D}' and tipo = 'status'") == '3', 'mudanças de status vão para o histórico; validar marca a data')
sql(f"update diagnosticos set status = 'em_revisao' where id = '{D}'")
chk(sql(f"select validado_em is null from diagnosticos where id = '{D}'") == 't', 'reabrir para revisão tira a validação')
chk('status_check' in erro(f"update diagnosticos set status = 'publicado' where id = '{D}'"), 'status fora da lista é recusado')
# arquivos do cliente entram pelo link do formulário
PE = sql(f"select id from pessoas where workspace_id = '{WS}' order by criado_em limit 1")
PQ = sql(f"insert into pesquisas (workspace_id, nome, tipo, publico) values ('{WS}', 'T223 diag', 'diagnostico', 'cliente') returning id").split('\n')[0]
EV = sql(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{PQ}', '{PE}') returning id").split('\n')[0]
CA = b'data,produto,valor\n2026-02-01,Curso A,497\n'
AC = sql(f"insert into pesquisa_arquivos (workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{EV}', '{PQ}', '{PE}', 'vendas', 't223 cliente vendas.csv', '{WS}/{EV}/t223a.csv', {len(CA)}, 'enviado', now()) returning id").split('\n')[0]
RS = sql(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{PQ}', '{EV}', '{PE}') returning id").split('\n')[0]
D2 = sql(f"insert into diagnosticos (workspace_id, titulo, resposta_id) values ('{WS}', 'T223 Com formulário', '{RS}') returning id").split('\n')[0]
chk(sql(f"select diagnostico_id from pesquisa_arquivos where id = '{AC}'") == D2, 'ligar o diagnóstico ao formulário traz os arquivos que o cliente já mandou')
AC2 = sql(f"insert into pesquisa_arquivos (workspace_id, envio_id, pesquisa_id, pessoa_id, grupo, nome, caminho, tamanho, status, enviado_em) values ('{WS}', '{EV}', '{PQ}', '{PE}', 'financeiro', 't223 dre.pdf', '{WS}/{EV}/t223b.pdf', 10, 'enviado', now()) returning id").split('\n')[0]
chk(sql(f"select diagnostico_id from pesquisa_arquivos where id = '{AC2}'") == D2, 'arquivo novo do cliente pelo link entra direto no diagnóstico')
chk('desligar' in erro(f"update diagnosticos set resposta_id = null where id = '{D2}'"), 'não dá para desligar o formulário de um diagnóstico')
r = J(f"diagnostico_arquivo_hash('{AC}', '{H(CA)}')")
chk(not r['duplicado'], 'conferir o conteúdo de um arquivo do cliente (sem repetido)')
P = J(f"diagnostico_progresso('{D2}')")
et = {e['k']: e['ok'] for e in P['etapas']}
chk(P['total'] == 8 and et['evidencias'] and et['formulario'] and not et['classificacao'] and not et['validado'], 'progresso: evidências e formulário feitos; classificação e validação pendentes', P)
LS = J(f"diagnosticos_lista('{WS}')")
chk(any(x['id'] == D and x['responsavel'] == 'Ana T223' and x['arquivos'] == 1 for x in LS), 'lista dos diagnósticos com responsável e número de evidências', [(x['titulo'], x['arquivos']) for x in LS])
# ---------- tela ----------
front.ARQS['diagnostico/' + WS + '/' + EV + '/t223a.csv'] = CA
open(SP + 't223_vendas.csv', 'wb').write(b'Data;Produto;Valor;Status\n05/03/2026;Curso A;497,00;aprovado\n06/03/2026;Curso A;497,00;aprovado\n')
open(SP + 't223_falso.pdf', 'wb').write(b'isto nao e um pdf')
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    t = front.vai(pg, 'gro-diag', "S.dgSel = null; S.dgSemDiag = null; S.gxDiag = null;", 4000)
    chk('T223 Diagnóstico' in t and 'Ana T223' in t and 'Novo diagnóstico' in t and 'Em revisão' in t, 'lista mostra os diagnósticos da empresa com status e responsável', t[:400])
    pg.screenshot(path=SHOT + '1_lista.png', full_page=True)
    pg.click('#dgNovo'); pg.wait_for_timeout(1200)
    pg.fill('.modal [name=titulo]', 'T223 Novo pela tela'); pg.select_option('.modal [name=responsavel_id]', label='Ana T223')
    pg.click('.modal .acts .pri'); pg.wait_for_timeout(3500)
    t = pg.inner_text('#main')
    chk('T223 Novo pela tela' in t and 'Central de Evidências' in t and pg.locator('[data-abas="dg"] [data-aba-k]').count() == 7, 'novo diagnóstico abre na aba Evidências, com as sete abas', t[:300])
    pg.set_input_files('#dgArqIn', SP + 't223_vendas.csv'); pg.wait_for_timeout(3500)
    t = pg.inner_text('#main')
    chk('t223_vendas.csv' in t and 'Equipe' in t and 'sugerida' in t and pg.locator('tr[data-dga] [data-dgcls]').first.input_value() == 'vendas', 'arquivo enviado pela equipe aparece com a classificação sugerida pelo nome', t[:500])
    pg.set_input_files('#dgArqIn', SP + 't223_vendas.csv'); pg.wait_for_timeout(3000)
    chk(pg.locator('tr[data-dga]').count() == 1 and 'Já estavam nas evidências' in pg.inner_text('body'), 'o mesmo arquivo de novo não entra (aviso de repetido)')
    pg.set_input_files('#dgArqIn', SP + 't223_falso.pdf'); pg.wait_for_timeout(2500)
    chk(pg.locator('tr[data-dga]').count() == 1 and 'diz ser .pdf' in pg.inner_text('body'), 'arquivo com extensão falsa é recusado antes do envio')
    pg.select_option('tr[data-dga] [data-dgcls]', 'financeiro'); pg.wait_for_timeout(2500)
    chk('sugerida' not in pg.inner_text('tr[data-dga]') and pg.locator('tr[data-dga] [data-dgcls]').input_value() == 'financeiro', 'escolher a classificação à mão tira a marca de sugerida')
    pg.fill('tr[data-dga] [data-dgpi]', '2026-03-01'); pg.fill('tr[data-dga] [data-dgpf]', '2026-03-31'); pg.locator('tr[data-dga] [data-dgpf]').dispatch_event('change'); pg.wait_for_timeout(1500)
    novo = sql(f"select id from diagnosticos where workspace_id = '{WS}' and titulo = 'T223 Novo pela tela'")
    chk(sql(f"select periodo_ini || ':' || periodo_fim from pesquisa_arquivos where diagnostico_id = '{novo}'") == '2026-03-01:2026-03-31', 'período representado salvo pela tela')
    pg.screenshot(path=SHOT + '2_evidencias.png', full_page=True)
    front.aba(pg, 'dados', 600)
    t = pg.inner_text('#main')
    chk('Auditoria das planilhas' in t and 'Leitura consolidada' in t and 'Ler as 1 planilha' in t, 'aba Dados mostra a auditoria e a leitura consolidada', t[:400])
    pg.click('#dgLePl'); pg.wait_for_selector('#gxVoltaReu', timeout=20000); pg.wait_for_timeout(1500)
    t = pg.inner_text('#main')
    chk('Voltar para o diagnóstico' in t and 't223_vendas.csv' in t, 'ler as planilhas abre a leitura com os arquivos do diagnóstico', t[:300])
    pg.click('#gxVoltaReu'); pg.wait_for_timeout(3500)
    chk(pg.locator('[data-abas="dg"] [data-aba-k="dados"]').get_attribute('aria-selected') == 'true' and 'Leitura consolidada' in pg.inner_text('#main'), 'voltar da leitura cai na aba Dados do mesmo diagnóstico')
    front.aba(pg, 'val', 600)
    pg.click('[data-dgst="em_analise"]'); pg.wait_for_timeout(3000)
    pg.fill('#dgDecTx', 'NSM provisória: receita bruta até termos os marcos de valor.'); pg.click('#dgDecOk'); pg.wait_for_timeout(3000)
    t = pg.inner_text('#main')
    chk('Em análise' in t and 'De "Em coleta" para "Em análise"' in t and 'NSM provisória' in t, 'validação: status muda e decisão fica no histórico', t[:600])
    pg.screenshot(path=SHOT + '3_validacao.png', full_page=True)
    front.aba(pg, 'arq', 500)
    chk('Arquitetura de crescimento' in pg.inner_text('#main'), 'aba Arquitetura mostra a North Star da empresa (ou a falta dela)')
    t = front.vai(pg, 'gro-diag', f"S.dgSel = '{D2}';", 4000)
    front.aba(pg, 'reu', 500)
    chk('Ir para a reunião do diagnóstico' in pg.inner_text('#main'), 'diagnóstico com formulário leva para a reunião')
    pg.click('#dgReu'); pg.wait_for_timeout(4000)
    chk('Reunião do diagnóstico' in pg.inner_text('#main'), 'a reunião de antes continua abrindo', pg.inner_text('#main')[:200])
    t = front.vai(pg, 'gro-diag', "S.dgSel = null; S.dgSemDiag = null;", 3500)
    pg.click('#dgSoPlan'); pg.wait_for_timeout(3000)
    t = pg.inner_text('#main')
    chk('Ler planilhas sem diagnóstico' in t and '1. Arquivos do cliente' in t, 'a leitura de planilhas de antes (Growth Model) continua disponível', t[:300])
    pg.click('#gxVoltaLista'); pg.wait_for_timeout(3000)
    chk('Novo diagnóstico' in pg.inner_text('#main'), 'e volta para a lista')
    errs = list(pg.errs); ctx.close()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=390, vh=844)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{novo}'; (S.abas = S.abas || {{}}).dg = 'evid';", 4500)
    larg = pg.evaluate("document.documentElement.scrollWidth")
    chk(larg <= 392, 'no celular a página não passa da largura da tela', larg)
    pg.screenshot(path=SHOT + '4_celular.png', full_page=True)
    errs += pg.errs; ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
