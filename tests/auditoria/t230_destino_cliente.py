"""v0.230: formulário para clientes — quem responde é cliente: atualiza o cadastro e a etapa na jornada do cliente, sem entrar no Funil de leads.
Banco: resposta pelo link individual move a matrícula para a etapa escolhida e registra no histórico; sem matrícula, só registra; formulário de
lead não mexe; link aberto com destino cliente não põe contato novo no Funil de leads; o formulário público não expõe a etapa.
Tela: Formulário e aparência com "Quem responde" (lead × cliente) e a etapa; modelo do diagnóstico já nasce para clientes; aviso no diagnóstico.
Banco fa (Escola Aurora). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots230/'; os.makedirs(SHOT, exist_ok=True)
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
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T230%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T230%')"
    sql(f"delete from pesquisa_resposta_itens where resposta_id in (select id from pesquisa_respostas where pesquisa_id in {sub})")
    for t in ['pesquisa_respostas', 'pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where workspace_id = '{WS}' and nome like 'T230%'")
    sql(f"delete from alunos where workspace_id = '{WS}' and tag = 't230'")
    sql(f"delete from pessoa_historico where workspace_id = '{WS}' and pessoa_id in (select id from pessoas where workspace_id = '{WS}' and (nome like 'Cliente T230%' or email like '%t230%'))")
    sql(f"delete from pessoas where workspace_id = '{WS}' and (nome like 'Cliente T230%' or email like '%t230%')")
    sql(f"delete from etapas_kanban where workspace_id = '{WS}' and nome like '% T230'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
EA = one(f"insert into etapas_kanban (workspace_id, quadro, nome, ordem) values ('{WS}', 'alunos', 'Entrada T230', 90) returning id")
EB = one(f"insert into etapas_kanban (workspace_id, quadro, nome, ordem) values ('{WS}', 'alunos', 'Diagnóstico T230', 91) returning id")
PROD = one(f"select id from produtos where workspace_id = '{WS}' limit 1")
P1 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T230 Com matrícula', 'com.t230@exemplo.com') returning id")
P2 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T230 Sem matrícula', 'sem.t230@exemplo.com') returning id")
AL = one(f"insert into alunos (workspace_id, pessoa_id, produto_id, tag, status) values ('{WS}', '{P1}', '{PROD}', 't230', 'ativo') returning id")
sql(f"update alunos set etapa_kanban_id = '{EA}' where id = '{AL}'")
CAP = json.dumps({'ativa': False, 'destino': 'cliente', 'etapa_cliente_id': EB})
PC = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, captacao) values ('{WS}', 'T230 Clientes', 'diagnostico', 'cliente', true, '{CAP}') returning id")
PL = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, captacao) values ('{WS}', 'T230 Lead', 'diagnostico', 'cliente', true, '{{\"ativa\":false,\"destino\":\"lead\"}}') returning id")
def responde(pq, pe):
    ev = one(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id) values ('{WS}', '{pq}', '{pe}') on conflict (pesquisa_id, pessoa_id, ciclo) do update set status = pesquisa_envios.status returning id")
    return one(f"insert into pesquisa_respostas (workspace_id, pesquisa_id, envio_id, pessoa_id) values ('{WS}', '{pq}', '{ev}', '{pe}') returning id")
responde(PL, P1)
chk(sql(f"select etapa_kanban_id from alunos where id = '{AL}'") == EA, 'formulário de lead: a matrícula do cliente não muda de etapa')
responde(PC, P1)
chk(sql(f"select etapa_kanban_id from alunos where id = '{AL}'") == EB, 'formulário para clientes: a matrícula vai para a etapa escolhida (Diagnóstico)')
chk(sql(f"select valor_novo from pessoa_historico where pessoa_id = '{P1}' and campo = 'formulario_cliente'") == 'T230 Clientes → etapa "Diagnóstico T230"', 'o histórico do cliente registra o formulário e a etapa')
responde(PC, P2)
chk('sem matrícula' in sql(f"select valor_novo from pessoa_historico where pessoa_id = '{P2}' and campo = 'formulario_cliente'"), 'cliente sem matrícula: só registra no histórico (a etapa não muda)')
# link aberto
CAPA = json.dumps({'ativa': True, 'destino': 'cliente', 'etapa_cliente_id': EB, 'campos': {'telefone': {'mostrar': False}, 'instagram': {'mostrar': False}}, 'consentimentos': []})
sql(f"update pesquisas set aceita_link_aberto = true, captacao = '{CAPA}' where id = '{PC}'")
sql(f"insert into pesquisa_perguntas (workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria) values ('{WS}', '{PC}', 1, 'Nome da empresa', 'texto', false)")
TOKA = one(f"select token_aberto from pesquisas where id = '{PC}'")
sql(f"select pesquisa_captar('{TOKA}', '{{}}', '{{\"nome\":\"Cliente T230 Novo\",\"email\":\"novo.t230@exemplo.com\"}}', '{{}}')")
r = sql(f"select coalesce(etapa_kanban_id::text, 'fora') || '|' || array_to_string(tags, ',') from pessoas where workspace_id = '{WS}' and email = 'novo.t230@exemplo.com'")
chk(r.startswith('fora|') and 'cliente sem cadastro' in r, 'link aberto para clientes: contato novo não entra no Funil de leads e fica marcado "cliente sem cadastro"', r)
pub = json.loads(sql(f"select pesquisa_publica('{TOKA}')::text"))
chk('etapa_cliente_id' not in json.dumps(pub.get('captacao') or {}), 'o formulário público não mostra a etapa do cliente')
# diagnóstico com formulário de lead: aviso
D = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T230 Diag', '{P2}') returning id")
EVL = one(f"select id from pesquisa_envios where pesquisa_id = '{PL}' and pessoa_id = '{P1}'")
P3 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T230 Diag', 'diag.t230@exemplo.com') returning id")
D3 = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T230 Diag Lead', '{P3}') returning id")
sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"00000000-0000-0000-0000-00000000a0a0\"}}', true), diagnostico_formulario('{D3}', '{PL}')")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D3}'; (S.abas = S.abas || {{}}).dg = 'form';", 4500)
    chk('ainda não está marcado como para clientes' in pg.inner_text('#main'), 'diagnóstico avisa quando o formulário escolhido não é "para clientes"')
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{PL}'; S.pqTab = 'form';", 4500)
    chk(pg.locator('[name=pfDest][value=lead]').is_checked() and pg.locator('[data-so-cli]').first.is_hidden() and pg.locator('div[data-so-lead]').is_visible(), 'Formulário e aparência: "Quem responde" começa em lead (etapa do Funil de leads visível)')
    pg.locator('[name=pfDest][value=cliente]').check(); pg.wait_for_timeout(300)
    chk(pg.locator('div[data-so-lead]').is_hidden() and pg.locator('[data-c=etapa_cliente_id]').is_visible(), 'escolher "Um cliente" mostra a etapa do cliente e esconde a do Funil de leads')
    pg.select_option('[data-c=etapa_cliente_id]', EB); pg.click('#pfSalva'); pg.wait_for_timeout(3000)
    c = json.loads(sql(f"select captacao::text from pesquisas where id = '{PL}'"))
    chk(c.get('destino') == 'cliente' and c.get('etapa_cliente_id') == EB, 'salvar guarda "para clientes" e a etapa', c)
    pg.screenshot(path=SHOT + '1_quem_responde.png', full_page=False)
    tem = pg.evaluate("() => PQ_MODELOS.diagnostico_mathisa.captacao")
    chk(tem == {'ativa': False, 'destino': 'cliente'}, 'o modelo "Diagnóstico Mathisa" já nasce para clientes')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
