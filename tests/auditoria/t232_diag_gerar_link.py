"""v0.232: correção — no diagnóstico, escolher o formulário dava erro em produção e o link não era gerado.
Causa: diagnostico_formulario usava a trava antiga (pesquisa, pessoa); desde os check-ins a trava é (pesquisa, pessoa, ciclo).
Banco: com a trava dos check-ins, gerar o link funciona e não duplica. Tela: o formulário padrão já vem escolhido e o botão
"Gerar o link do formulário" cria o link; cliente sem e-mail e WhatsApp ainda pode copiar o link.
Banco fa (Escola Aurora, marcada como agência durante o teste). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
EU = '00000000-0000-0000-0000-00000000a0a0'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots232/'; os.makedirs(SHOT, exist_ok=True)
def sql(q):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
def eu(q): return sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"{EU}\",\"role\":\"authenticated\"}}', true); " + q).split('\n')[-1]
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:400]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
one = lambda q: sql(q).split('\n')[0]
def limpa():
    sql(f"delete from diagnosticos where workspace_id = '{WS}' and titulo like 'T232%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T232%')"
    for t in ['pesquisa_envios', 'pesquisa_perguntas']: sql(f"delete from {t} where pesquisa_id in {sub}")
    sql(f"delete from pesquisas where id in {sub}")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T232%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
PAD0 = sql(f"select coalesce(string_agg(id::text, ','), '') from pesquisas where workspace_id = '{WS}' and padrao_diagnostico")
chk(sql("select count(*) from pg_constraint where conname = 'pesquisa_envios_ciclo_uq'") == '1', 'o banco de teste tem a trava dos check-ins (igual à produção)')
sql(f"update pesquisas set padrao_diagnostico = false where workspace_id = '{WS}' and padrao_diagnostico")
F = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, padrao_diagnostico) values ('{WS}', 'T232 Padrão', 'diagnostico', 'cliente', true, true) returning id")
P = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', 'Cliente T232 Sem contato') returning id")
D1 = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T232 Banco', '{P}') returning id")
r1 = json.loads(eu(f"select diagnostico_formulario('{D1}', '{F}')::text"))
r2 = json.loads(eu(f"select diagnostico_formulario('{D1}', '{F}')::text"))
chk(r1.get('envio_id') and r1['envio_id'] == r2['envio_id'], 'gerar o link funciona com a trava dos check-ins e não duplica', (r1, r2))
sql(f"delete from diagnosticos where id = '{D1}'"); sql(f"delete from pesquisa_envios where pesquisa_id = '{F}'")
D = one(f"insert into diagnosticos (workspace_id, titulo, pessoa_id) values ('{WS}', 'T232 Tela', '{P}') returning id")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'gro-diag', f"S.dgSel = '{D}'; (S.abas = S.abas || {{}}).dg = 'form';", 4500)
    chk(pg.input_value('#dgFPesq') == F, 'o formulário padrão já vem escolhido')
    chk(pg.locator('#dgFGera').is_visible(), 'aparece o botão "Gerar o link do formulário"')
    pg.screenshot(path=SHOT + '1_antes.png')
    pg.click('#dgFGera'); pg.wait_for_timeout(3500)
    chk(sql(f"select envio_id is not null from diagnosticos where id = '{D}'") == 't', 'o botão gera o link (o envio fica ligado ao diagnóstico)')
    t = pg.inner_text('#main')
    chk(pg.locator('#dgFCp').is_visible() and 'Sem WhatsApp no cadastro' in t and 'Sem e-mail no cadastro' in t, 'cliente sem e-mail e WhatsApp: dá para copiar o link e a tela avisa o que falta')
    chk(pg.locator('#dgFGera').count() == 0, 'depois de gerado, o botão some e aparecem a mensagem e os envios')
    pg.screenshot(path=SHOT + '2_link_gerado.png')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
for i in [x for x in PAD0.split(',') if x]: sql(f"update pesquisas set padrao_diagnostico = true where id = '{i}'")
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
