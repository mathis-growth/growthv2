"""v0.231: clientes da Mathisa — o Growths do cliente nasce do contrato; inativar, reativar e excluir clientes.
Banco: ativar contrato com produto "inclui o Growths" cria o workspace com os dados da empresa, o pacote, o tipo de acesso e o convite do
responsável (administrador); contrato sem esse produto não cria; inativo some para quem é do cliente e continua para a equipe interna;
excluir só inativo e com o nome certo; o workspace da equipe interna não pode ser inativado nem excluído.
Tela: Pacotes de acesso com a situação e Inativar/Reativar/Excluir; seletor de workspaces sem os inativos; produto com "inclui o Growths";
contrato com a caixa "Growths do cliente" e a criação ao ativar.
Banco fa (Escola Aurora, marcada como agência durante o teste). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
EU = '00000000-0000-0000-0000-00000000a0a0'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots231/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def eu(q): return sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"{EU}\",\"role\":\"authenticated\"}}', true); " + q).split('\n')[-1]
def erro(q):
    try: eu(q); return ''
    except Exception as e: return str(e)
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    for w in sql("select id from workspaces where nome like '%T231%'").split('\n'):
        if w: sql(f"update workspaces set inativo_em = now() where id = '{w}'"); eu(f"select workspace_excluir('{w}', (select nome from workspaces where id = '{w}'))")
    sql("delete from workspaces_excluidos where nome like '%T231%'")
    sub = f"(select id from contratos where workspace_id = '{WS}' and pessoa_id in (select id from pessoas where nome like 'Cliente T231%'))"
    cr = f"(select id from contas_receber where contrato_id in {sub})"
    lc = f"(select id from lancamentos where origem_tipo = 'contrato_parcela' and origem_id in {cr})"
    # lançamentos são imutáveis: a limpeza do teste desliga os gatilhos só nesta transação
    sql(f"""set local session_replication_role = replica;
      delete from partidas where lancamento_id in {lc}; delete from lancamentos where id in {lc}; delete from contas_receber where contrato_id in {sub};
      delete from contrato_itens where contrato_id in {sub}; delete from contrato_parcelas_plano where contrato_id in {sub};
      delete from alunos where workspace_id = '{WS}' and pessoa_id in (select id from pessoas where nome like 'Cliente T231%');
      delete from contratos where id in {sub};
      delete from pessoa_historico where pessoa_id in (select id from pessoas where workspace_id = '{WS}' and nome like 'Cliente T231%');
      delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T231%';""")
    sql(f"delete from produtos where workspace_id = '{WS}' and nome like '%T231%'")
    sql("delete from pacotes_acesso where nome like '%T231%'")
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
try: limpa()
except Exception as e: print('limpeza inicial:', e)
PAC = one("insert into pacotes_acesso (nome, telas, ativo) values ('Pacote T231', '{adm-painel}', true) returning id")
PG = one(f"insert into produtos (workspace_id, nome, tag, tipo, preco, cria_workspace, workspace_modo, workspace_pacote_id) values ('{WS}', 'Implementação T231', 'impl-t231', 'servico', 1000, true, 'starter', '{PAC}') returning id")
PS = one(f"insert into produtos (workspace_id, nome, tag, tipo, preco) values ('{WS}', 'Consultoria T231', 'cons-t231', 'servico', 500) returning id")
P1 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T231 Empresa', 'dono.t231@exemplo.com') returning id")
P2 = one(f"insert into pessoas (workspace_id, nome, email) values ('{WS}', 'Cliente T231 Sem Growths', 'sem.t231@exemplo.com') returning id")
def contrato(pe, prod, extra=''):
    c = one(f"insert into contratos (workspace_id, pessoa_id, data_inicio, primeiro_vencimento, num_parcelas{', ' + extra.split('|')[0] if extra else ''}) values ('{WS}', '{pe}', '2026-11-02', '2026-11-10', 1{', ' + extra.split('|')[1] if extra else ''}) returning id")
    sql(f"insert into contrato_itens (workspace_id, contrato_id, produto_id, quantidade, valor) values ('{WS}', '{c}', '{prod}', 1, 1000)")
    return c
C1 = contrato(P1, PG, "empresa_nome, empresa_razao_social, empresa_cnpj, responsavel_nome, responsavel_email|'Empresa T231', 'Empresa T231 Ltda', '11222333000181', 'Dona T231', 'Dona.T231@Exemplo.com'")
eu(f"select ativar_contrato('{C1}')")
W = sql(f"select coalesce(cliente_workspace_id::text, 'nada') || '|' || coalesce(cliente_workspace_erro, '') from contratos where id = '{C1}'")
chk(not W.startswith('nada'), 'ativar contrato com produto "inclui o Growths" cria o Growths do cliente', W)
W = W.split('|')[0]
r = sql(f"select nome || '|' || modo_produto || '|' || coalesce(pacote_id::text, '') || '|' || coalesce(contrato_origem_id::text, '') from workspaces where id = '{W}'")
chk(r == f'Empresa T231|starter|{PAC}|{C1}', 'o workspace leva o nome da empresa, o tipo de acesso e o pacote do produto, e aponta para o contrato', r)
r = sql(f"select nome || '|' || razao_social || '|' || cnpj || '|' || responsavel_nome || '|' || responsavel_email from empresa where workspace_id = '{W}'")
chk(r == 'Empresa T231|Empresa T231 Ltda|11222333000181|Dona T231|dona.t231@exemplo.com', 'os dados da empresa vão para Configurações → Empresa do cliente', r)
r = sql(f"select e.email || '|' || e.acesso_ativo || '|' || f.nome || '|' || f.administrador from equipe e join funcoes f on f.id = e.funcao_id where e.workspace_id = '{W}'")
chk(r == 'dona.t231@exemplo.com|true|Administrador|true', 'o responsável fica convidado como Administrador (entra com o e-mail do contrato)', r)
chk(sql(f"select papel from workspace_membros where workspace_id = '{W}' and user_id = '{EU}'") == 'admin', 'quem ativou o contrato (equipe interna) entra no Growths do cliente')
chk('Growths criado pelo contrato' in sql(f"select valor_novo from pessoa_historico where pessoa_id = '{P1}' and campo = 'growths_cliente'"), 'o histórico do cliente na Mathisa registra a criação')
C2 = contrato(P2, PS)
eu(f"select ativar_contrato('{C2}')")
chk(sql(f"select cliente_workspace_id is null from contratos where id = '{C2}'") == 't', 'contrato sem produto que inclui o Growths não cria workspace')
chk('Nenhum produto' in erro(f"select contrato_criar_workspace_manual('{C2}')"), '"Tentar de novo" explica quando nenhum produto inclui o Growths')
chk(eu(f"select contrato_criar_workspace_manual('{C1}')") == W, 'tentar de novo num contrato que já tem Growths devolve o mesmo (não duplica)')
# inativar
chk('não pode ser inativado' in erro(f"select workspace_inativar('{WS}', null)"), 'o workspace da equipe interna não pode ser inativado')
chk('Inative o cliente' in erro(f"select workspace_excluir('{W}', 'Empresa T231')"), 'excluir exige inativar antes')
eu(f"select workspace_inativar('{W}', 'teste T231')")
chk(sql(f"select inativo_em is not null and inativo_motivo = 'teste T231' from workspaces where id = '{W}'") == 't', 'inativar guarda a data e o motivo')
chk(eu(f"select pertence_ao_workspace('{W}')") == 't', 'a equipe interna continua entrando no cliente inativo')
sql(f"update workspaces set agencia = false where id = '{WS}'")
chk(eu(f"select pertence_ao_workspace('{W}')") == 'f', 'quem é só do cliente perde o acesso quando ele é inativado')
sql(f"update workspaces set agencia = true where id = '{WS}'")
eu(f"select workspace_reativar('{W}')")
sql(f"update workspaces set agencia = false where id = '{WS}'")
chk(eu(f"select pertence_ao_workspace('{W}')") == 't', 'reativar devolve o acesso')
chk('equipe interna' in erro(f"select workspace_inativar('{W}', null)"), 'só a equipe interna inativa clientes')
sql(f"update workspaces set agencia = true where id = '{WS}'")
cli = json.loads(eu("select clientes_acesso()::text"))
x = next((c for c in cli if c['id'] == W), {})
chk(x.get('contrato_numero') is not None and 'inativo_em' in x, 'a lista de clientes mostra a situação e o contrato de origem', x)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    t = front.vai(pg, 'cfg-pacotes', '', 4000)
    chk('Empresa T231' in t and 'Veio do contrato #' in t, 'Pacotes de acesso: o cliente aparece com a situação e o contrato de origem')
    chk(pg.locator(f'[data-wi="{W}"]').count() == 1 and pg.locator(f'[data-wx="{W}"]').count() == 0, 'cliente ativo: tem Inativar e não tem Excluir')
    pg.click(f'[data-wi="{W}"]'); pg.wait_for_timeout(400); pg.fill('#modalRoot [name=motivo]', 'Encerrado T231'); pg.screenshot(path=SHOT + '1_inativar.png')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    chk(sql(f"select inativo_em is not null from workspaces where id = '{W}'") == 't', 'Inativar pela tela grava no banco')
    chk(W not in pg.inner_html('#wsSel'), 'o cliente inativo sai do seletor de workspaces')
    chk(pg.locator(f'[data-wr="{W}"]').count() == 1 and pg.locator(f'[data-wx="{W}"]').count() == 1, 'cliente inativo: tem Reativar e Excluir')
    pg.screenshot(path=SHOT + '2_clientes_inativo.png', full_page=False)
    pg.click(f'[data-wr="{W}"]'); pg.wait_for_timeout(3500)
    chk(W in pg.inner_html('#wsSel') and sql(f"select inativo_em is null from workspaces where id = '{W}'") == 't', 'Reativar volta o cliente para o seletor')
    # produto
    t = front.vai(pg, 'cad-produtos', '', 3500)
    chk('inclui o Growths' in t, 'Produtos: marca quais incluem o Growths do cliente')
    cw = pg.evaluate("async () => { const c = await ENT.produtos.load(); return ENT.produtos.campos(c).map(x => x.k).filter(Boolean); }")
    chk('cria_workspace' in cw and 'workspace_pacote_id' in cw and 'workspace_modo' in cw, 'o formulário do produto tem "inclui o Growths", tipo de acesso e pacote', cw)
    # contrato novo pela tela
    front.vai(pg, 'crm-contratos', '', 3000)
    pg.click('#ctNovo'); pg.wait_for_timeout(1500)
    pg.select_option('#modalRoot [name=pessoa_id]', P2)
    chk(pg.locator('#ctGw').is_hidden(), 'a caixa "Growths do cliente" fica escondida quando nenhum produto inclui o Growths')
    pg.select_option('#modalRoot .itp', PG); pg.wait_for_timeout(300)
    chk(pg.locator('#ctGw').is_visible() and pg.input_value('#modalRoot [name=responsavel_email]') == 'sem.t231@exemplo.com', 'escolher o produto mostra a caixa e sugere o responsável a partir do cliente')
    pg.fill('#modalRoot [name=empresa_nome]', 'Segunda T231'); pg.fill('#modalRoot [name=empresa_cnpj]', '11.222.333/0001-00')
    if pg.locator('#modalRoot [name=ct_documento]').is_visible(): pg.fill('#modalRoot [name=ct_documento]', '11222333000181')
    pg.screenshot(path=SHOT + '3_contrato_growths.png')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1500)
    chk('CNPJ da empresa inválido' in pg.inner_text('#toast') and pg.locator('#ctGw').is_visible(), 'CNPJ errado é barrado no contrato (o formulário continua aberto)')
    pg.fill('#modalRoot [name=empresa_cnpj]', '11.222.333/0001-81')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(5000)
    r = sql(f"select coalesce(w.nome, 'nada') || '|' || coalesce(c.empresa_cnpj, '') from contratos c left join workspaces w on w.id = c.cliente_workspace_id where c.pessoa_id = '{P2}' and c.id <> '{C2}'")
    chk(r == 'Segunda T231|11222333000181', 'criar e ativar o contrato pela tela cria o Growths "Segunda T231"', r)
    chk('Segunda T231' in pg.inner_html('#wsSel'), 'o Growths novo já aparece no seletor de workspaces')
    pg.screenshot(path=SHOT + '4_contrato_criado.png')
    # excluir pela tela
    sql(f"update workspaces set inativo_em = now() where id = '{W}'")
    front.vai(pg, 'cfg-pacotes', '', 3500)
    pg.click(f'[data-wx="{W}"]'); pg.wait_for_timeout(400); pg.fill('#modalRoot [name=conf]', 'Empresa errada'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1200)
    chk(sql(f"select count(*) from workspaces where id = '{W}'") == '1', 'Excluir com o nome errado não apaga')
    pg.fill('#modalRoot [name=conf]', 'Empresa T231'); pg.screenshot(path=SHOT + '5_excluir.png'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(3500)
    chk(sql(f"select count(*) from workspaces where id = '{W}'") == '0' and sql(f"select count(*) from workspaces_excluidos where id = '{W}'") == '1', 'Excluir com o nome certo apaga o workspace e registra quem e quando')
    chk(sql(f"select cliente_workspace_id is null from contratos where id = '{C1}'") == 't', 'o contrato continua, sem o Growths apagado')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
