"""v0.130: formulário de captação dentro das Pesquisas.
Cria a pesquisa pelo modelo "Captação: diagnóstico inicial de crescimento", troca a aparência, ativa, responde pelo link
público (sem login, com UTM) e confere o que chegou no CRM: contato novo no Funil de leads, Instagram, tags da oferta sugerida,
consentimentos e origem; depois a mesma pessoa pelo WhatsApp (não duplica), os bloqueios do banco e o fluxo antigo de pesquisa.
Banco fa com a migração 20261027100000_formulario_captacao.sql; o teste apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
NOME = 'Captação: diagnóstico inicial de crescimento'
def sql(q, role=None):
    pre = f"set role {role}; " if role else ''
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', pre + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
EM1, EM2 = 't130.ana@exemplo.com.br', 't130.outro@exemplo.com.br'
def limpa():
    sql(f"delete from pessoas where workspace_id = '{WS}' and (email in ('{EM1}', '{EM2}', 't130.robo@exemplo.com.br') or telefone like '%31988887777%')")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome = '{NOME}'")
limpa()
ETAPA1 = sql(f"select nome from etapas_kanban where workspace_id = '{WS}' and quadro = 'leads' order by ordem limit 1")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, vw=1500, vh=1000)
    front.vai(pg, 'gro-pesq', "S.pqSel = null;")
    pg.select_option('#pqModelo', 'captacao_mathisa'); pg.wait_for_timeout(600)
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    P = sql(f"select id from pesquisas where workspace_id = '{WS}' and nome = '{NOME}'")
    chk(bool(P), 'modelo cria a pesquisa de captação')
    cfg = json.loads(sql(f"select json_build_object('cap', captacao, 'vis', visual, 'aberto', aceita_link_aberto, 'n', (select count(*) from pesquisa_perguntas where pesquisa_id = '{P}'), 'sec', (select count(distinct secao) from pesquisa_perguntas where pesquisa_id = '{P}'), 'pts', (select count(*) from pesquisa_perguntas where pesquisa_id = '{P}' and pontos is not null)) from pesquisas where id = '{P}'"))
    chk(cfg['n'] == 6 and cfg['sec'] == 2 and cfg['pts'] == 2 and cfg['aberto'] and cfg['cap']['ativa'], '6 perguntas em 2 passos, tags de oferta e alerta, captação ligada')
    t = pg.inner_text('#main')
    chk('Formulário e aparência' in t and 'Como a pessoa vê' in t, 'abre direto na aba Formulário e aparência')
    prev = pg.locator('#pfPrev')
    chk(prev.locator('[data-passo]').count() == 4 and 'Passo 1 de 4' in prev.inner_text(), 'pré-visualização em 4 passos: dados, 2 de perguntas, alinhamento')
    chk(pg.evaluate("getComputedStyle(document.querySelector('#pfPrev h1')).fontFamily").startswith('"Bodoni Moda"'), 'título na fonte escolhida (Bodoni Moda)')
    # trocar a identidade visual: tema Moderno + cor própria
    pg.click('[data-tema="moderno"]'); pg.fill('[data-vh="cor_primaria"]', '#0A7D5A'); pg.wait_for_timeout(400)
    cor = pg.evaluate("getComputedStyle(document.querySelector('#pfPrev .pf-b[data-pf=\"segue\"]')).backgroundColor")
    chk(cor == 'rgb(10, 125, 90)', 'pré-visualização muda a cor do botão na hora (%s)' % cor)
    pg.click('#pfSalva'); pg.wait_for_timeout(2500)
    vis = json.loads(sql(f"select visual from pesquisas where id = '{P}'"))
    chk(vis['cor_primaria'] == '#0A7D5A' and vis['fonte_titulo'] == 'Space Grotesk' and vis['fonte_texto'] == 'Manrope', 'salva a aparência (cor e fontes)')
    chk('desativada' in pg.inner_text('.pf-link'), 'sem ativar, o link não aparece e explica o motivo')
    sql(f"update pesquisas set ativa = true, visual = visual || '{{\"cor_primaria\": \"#521F32\"}}'::jsonb where id = '{P}'")
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'form';")
    TOK = sql(f"select token_aberto from pesquisas where id = '{P}'")
    chk(TOK in pg.inner_text('#pfLk'), 'ativa: mostra o link para enviar')
    pg.click('.pf-link summary'); pg.fill('#uS', 'instagram'); pg.fill('#uM', 'bio'); pg.fill('#uC', 'qualificacao')
    lk = pg.inner_text('#pfLkU')
    chk(lk.endswith('&utm_source=instagram&utm_medium=bio&utm_campaign=qualificacao'), 'monta o link com a origem (UTM)')
    chk(not pg.errs, 'editor sem erro de JavaScript ' + str(pg.errs[:2]))

    # ----- a pessoa responde pelo link, sem login -----
    c2 = b.new_context(viewport={'width': 390, 'height': 844}); c2.route('http://audit.local/**', front.rota)
    pp = c2.new_page(); errs = []; pp.on('pageerror', lambda e: errs.append(str(e)))
    pp.goto('file://' + front.html() + f'?pesquisa={TOK}&utm_source=instagram&utm_medium=bio&utm_campaign=qualificacao'); pp.wait_for_timeout(3000)
    chk('Vamos entender o momento do seu negócio.' in pp.inner_text('body') and pp.locator('.pf-logo').count() == 0, 'página pública com o título da marca')
    chk(pp.evaluate("getComputedStyle(document.querySelector('.pf-b[data-pf=\"segue\"]')).backgroundColor") == 'rgb(82, 31, 50)', 'página pública na cor salva')
    chk(pp.evaluate("document.documentElement.scrollWidth <= 390"), 'cabe no celular sem rolagem lateral')
    pp.click('[data-pf="segue"]'); pp.wait_for_timeout(200)
    chk('Preencha: Nome' in pp.inner_text('.pf-msg'), 'não avança sem os dados obrigatórios')
    pp.fill('#pf_nome', 'Ana Teste'); pp.fill('#pf_email', EM1); pp.fill('#pf_telefone', '(31) 98888-7777'); pp.fill('#pf_instagram', '@ana.negocio')
    pp.click('[data-pf="segue"]'); pp.wait_for_timeout(200)
    chk('Passo 2 de 4' in pp.inner_text('.pf-f'), 'avança para o passo 2')
    pp.click('[data-pf="segue"]'); pp.wait_for_timeout(200)
    chk('Responda: Qual é o faturamento' in pp.inner_text('.pf-msg'), 'pede a resposta das perguntas obrigatórias')
    for txt in ['Até R$ 10 mil', 'Tenho dados, mas falta uma estratégia clara de crescimento.', 'Uso relatórios das plataformas e planilhas.']: pp.get_by_text(txt, exact=True).click()
    pp.click('[data-pf="segue"]'); pp.wait_for_timeout(200)
    for txt in ['Não, ainda tomo decisões conforme os problemas aparecem.', 'Faço praticamente tudo sozinho(a).', 'Orientação para organizar números, analisar e melhorar os resultados.']: pp.get_by_text(txt, exact=True).click()
    pp.click('[data-pf="segue"]'); pp.wait_for_timeout(200)
    chk('R$ 3.500' in pp.inner_text('.pf-f'), 'passo final mostra o aviso de investimento')
    pp.click('[data-pf="envia"]'); pp.wait_for_timeout(300)
    chk('Marque para continuar' in pp.inner_text('.pf-msg'), 'não envia sem as confirmações obrigatórias')
    pp.locator('[data-cons="0"]').check(); pp.locator('[data-cons="1"]').check()
    pp.click('[data-pf="envia"]'); pp.wait_for_timeout(2500)
    chk('Solicitação recebida!' in pp.inner_text('body'), 'mostra a mensagem de sucesso')
    chk(not errs, 'página pública sem erro de JavaScript ' + str(errs[:2]))
    pes = json.loads(sql(f"select row_to_json(x) from (select p.nome, p.telefone, p.extras, p.tags, p.utm_source, p.utm_campaign, p.canal_origem, e.nome as etapa, p.respostas_pesquisa from pessoas p left join etapas_kanban e on e.id = p.etapa_kanban_id where p.workspace_id = '{WS}' and p.email = '{EM1}') x"))
    chk(pes['nome'] == 'Ana Teste' and pes['telefone'] == '31988887777' and pes['extras']['instagram'] == '@ana.negocio', 'CRM: contato criado com nome, WhatsApp e Instagram')
    chk(pes['etapa'] == ETAPA1, 'CRM: entrou no Funil de leads na primeira etapa (%s)' % pes['etapa'])
    chk(set(pes['tags']) >= {'Formulário de qualificação', 'Oferta sugerida: Growth Starter', 'Alerta: avaliar capacidade econômica'}, 'CRM: tags do formulário, oferta sugerida e alerta (%s)' % pes['tags'])
    chk(pes['utm_source'] == 'instagram' and pes['utm_campaign'] == 'qualificacao', 'CRM: origem gravada pelo UTM do link')
    chk(len(pes['respostas_pesquisa'] or {}) == 6, 'CRM: as 6 respostas ficam no lead')
    r = json.loads(sql(f"select row_to_json(x) from (select contato, consentimentos, utm, novo_contato from pesquisa_respostas where pesquisa_id = '{P}' order by respondida_em desc limit 1) x"))
    chk(r['novo_contato'] and [c['aceito'] for c in r['consentimentos']] == [True, True, False] and 'R$ 3.500' not in json.dumps(r['consentimentos']) and 'investimento mínimo' in r['consentimentos'][0]['texto'],
        'resposta guarda os consentimentos com o texto exato e o opcional desmarcado')
    # mesma pessoa de novo em seguida: bloqueia
    def captar(email, fone, cons='[true, true, false]', extra='', role='anon'):
        resp = sql(f"select json_object_agg(id, case when ordem in (1, 6) then to_jsonb(opcoes[2]) else to_jsonb(opcoes[1]) end) from pesquisa_perguntas where pesquisa_id = '{P}'")
        return sql(f"""select pesquisa_captar('{TOK}', '{resp}'::jsonb, '{{"nome": "Ana T.", "email": "{email}", "telefone": "{fone}", "instagram": "@ana2"}}'::jsonb, '{{"consentimentos": {cons}{extra}}}'::jsonb)""", role)
    try: captar(EM1, '31988887777'); chk(False, 'bloqueia envio repetido em 2 minutos')
    except Exception as e: chk('agora há pouco' in str(e), 'bloqueia envio repetido em 2 minutos')
    try: captar(EM2, '31988887777', '[true, false, false]'); chk(False, 'banco exige a confirmação obrigatória')
    except Exception as e: chk('Marque: Autorizo' in str(e), 'banco exige a confirmação obrigatória')
    try: captar('sem-arroba', '31988887777'); chk(False, 'banco recusa e-mail inválido')
    except Exception as e: chk('e-mail válido' in str(e), 'banco recusa e-mail inválido')
    n0 = sql(f"select count(*) from pessoas where workspace_id = '{WS}'")
    captar('t130.robo@exemplo.com.br', '31911112222', extra=', "site": "http://spam"')
    chk(sql(f"select count(*) from pessoas where workspace_id = '{WS}'") == n0, 'campo-armadilha: robô recebe ok e nada é gravado')
    # outro e-mail, mesmo WhatsApp: reconhece pelo WhatsApp e não duplica
    captar(EM2, '+55 (31) 98888-7777')
    n = json.loads(sql(f"select json_build_object('n', (select count(*) from pessoas where workspace_id = '{WS}' and telefone_norm = '5531988887777'), 'tags', tags, 'ig', extras->>'instagram') from pessoas where workspace_id = '{WS}' and telefone_norm = '5531988887777' limit 1"))
    chk(n['n'] == 1 and n['ig'] == '@ana2' and 'Oferta sugerida: Growth Consulting' in n['tags'], 'mesmo WhatsApp com outro e-mail: atualiza o mesmo lead, sem duplicar')
    chk(sql(f"select novo_contato from pesquisa_respostas where pesquisa_id = '{P}' and email = '{EM2}'") == 'f', 'resposta marca que o contato já existia')
    # a parte interna da captação não aparece para quem não está logado
    pub = json.loads(sql(f"select pesquisa_publica('{TOK}')", 'anon'))
    chk('tags' not in pub['captacao'] and 'etapa_id' not in pub['captacao'] and pub['perguntas'][0]['secao'] == 'Seu negócio', 'página pública não vê tags, etapa e responsável')
    try: sql(f"select pesquisa_registrar('{P}', null, null, null, '{{}}'::jsonb)", 'anon'); chk(False, 'função interna fechada para anon')
    except Exception as e: chk('permission denied' in str(e), 'função interna fechada para anon')
    # tela: lista de quem chegou e ficha com Instagram
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'form';")
    t = pg.inner_text('#main')
    chk('novo lead' in t and 'já existia, atualizado' in t and 'instagram / bio / qualificacao' in t, 'aba mostra os contatos que chegaram, novos e atualizados, com a origem')
    pg.locator('[data-fp]').first.click(); pg.wait_for_timeout(2500)
    chk('@ana2' in pg.inner_text('body'), 'ficha do lead mostra o Instagram')
    # pergunta com passo do formulário
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''"); front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'perguntas';")
    pg.locator('[data-q]').first.click(); pg.wait_for_timeout(800)
    chk(pg.locator('#modalRoot [name="secao"]').input_value() == 'Seu negócio', 'pergunta tem o campo "Passo do formulário"')
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
# o fluxo antigo continua: link aberto sem captação, ligando pelo e-mail de quem já existe
sql(f"update pesquisas set captacao = captacao || '{{\"ativa\": false}}'::jsonb where id = '{P}'")
resp = sql(f"select json_object_agg(id, to_jsonb(opcoes[1])) from pesquisa_perguntas where pesquisa_id = '{P}'")
sql(f"select pesquisa_responder('{TOK}', '{resp}'::jsonb, '{EM1}')", 'anon')
chk(sql(f"select count(*) from pesquisa_respostas r join pessoas p on p.id = r.pessoa_id where r.pesquisa_id = '{P}' and p.email = '{EM1}'") == '3', 'pesquisa comum (pesquisa_responder) segue ligando pelo e-mail')
try: sql(f"select pesquisa_captar('{TOK}', '{resp}'::jsonb, '{{\"nome\": \"X\", \"email\": \"x@y.com\"}}'::jsonb, '{{}}'::jsonb)", 'anon'); chk(False, 'captação desligada recusa cadastro')
except Exception as e: chk('não recebe cadastros' in str(e), 'captação desligada recusa cadastro')
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
