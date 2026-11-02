"""v0.237: o cliente volta a anexar os arquivos no formulário do diagnóstico.
Causa: o editor de perguntas apagava a configuração que não mostra (anexar, "Onde vende", período, planilha-modelo).
Banco/dados: o RODAR_v0.237 devolve a configuração à pergunta de arquivos do "Diagnóstico Mathisa" (testado numa cópia com os mesmos ids).
Tela: editar e salvar a pergunta de arquivos mantém o anexar, a ligação com "Onde vende", as chaves e as planilhas-modelo; a caixa
"o cliente anexa os arquivos" aparece no editor; o formulário público mostra "Enviar arquivo" em cada grupo.
Banco fa (Escola Aurora, marcada como agência). Cria os dados de teste e apaga no fim."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
PQ, QD, QO = '951543b9-18d5-4920-af17-bf8a44c04d62', '0a039a99-7aa6-496c-b27d-28579c4df500', '3c12abe3-0778-44d2-b318-32de281ec670'
RODAR = '/home/claude/growthv2/supabase/RODAR_v0.237_anexos_diagnostico_mathisa.sql'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots237/'; os.makedirs(SHOT, exist_ok=True)
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
    sql(f"delete from pesquisa_envios where pesquisa_id = '{PQ}'"); sql(f"delete from pesquisa_perguntas where pesquisa_id = '{PQ}'"); sql(f"delete from pesquisas where id = '{PQ}'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Cliente T237%'")
limpa()
AG0 = sql(f"select agencia from workspaces where id = '{WS}'"); sql(f"update workspaces set agencia = true where id = '{WS}'")
sql(f"insert into pesquisas (id, workspace_id, nome, tipo, publico, ativa) values ('{PQ}', '{WS}', 'Diagnóstico Mathisa (pré-diagnóstico)', 'diagnostico', 'cliente', true)")
sql(f"insert into pesquisa_perguntas (id, workspace_id, pesquisa_id, ordem, texto, tipo, opcoes, obrigatoria, secao) values ('{QO}', '{WS}', '{PQ}', 1, 'Onde vende? (pode marcar mais de um)', 'multipla', array['Hotmart','Kiwify','Eduzz','Hubla','Contrato direto','Loja própria','Outro'], true, 'Sobre o seu negócio')")
# como está em produção: só aviso e grupos g1…g9, sem anexar
cats = [{'k': 'g%d' % (i + 1), 'l': l, 'd': 'x'} for i, l in enumerate(['Vendas da Hotmart', 'Vendas da Kiwify', 'Vendas da Eduzz', 'Vendas da Hubla', 'Vendas fora das plataformas', 'Clientes', 'Leads', 'Investimento em anúncios', 'Custos da operação (opcional)'])]
sql(f"insert into pesquisa_perguntas (id, workspace_id, pesquisa_id, ordem, texto, tipo, obrigatoria, secao, config) values ('{QD}', '{WS}', '{PQ}', 2, 'Precisamos dos arquivos dos últimos 12 meses', 'documentos', true, 'Seus arquivos', $${json.dumps({'aviso': 'Não envie senhas.', 'categorias': cats}, ensure_ascii=False)}$$::jsonb)")
r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-q', '-v', 'ON_ERROR_STOP=1', '-f', RODAR], capture_output=True, text=True)
chk(r.returncode == 0, 'o RODAR_v0.237 roda sem erro', r.stderr)
c = json.loads(sql(f"select config::text from pesquisa_perguntas where id = '{QD}'"))
chk(c.get('upload') and c.get('sem_depois') and c.get('onde') == QO and c['categorias'][0]['k'] == 'vendas_hotmart' and c['categorias'][0].get('se') == ['Hotmart'] and 'cols' in c['categorias'][4], 'a pergunta volta a anexar, ligada ao "Onde vende?", com grupos por plataforma e planilhas-modelo', {k: v for k, v in c.items() if k != 'categorias'})
P = one(f"insert into pessoas (workspace_id, nome) values ('{WS}', 'Cliente T237') returning id")
TOK = one(f"insert into pesquisa_envios (workspace_id, pesquisa_id, pessoa_id, origem) values ('{WS}', '{PQ}', '{P}', 'manual') returning token")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    # editar e salvar a pergunta de arquivos pela tela
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{PQ}'; S.pqTab = 'perguntas';", 4000)
    pg.wait_for_selector(f'[data-q="{QD}"]', timeout=15000); pg.click(f'[data-q="{QD}"]'); pg.wait_for_timeout(800)
    chk(pg.locator('#modalRoot [name=cfg_upload]').is_checked(), 'o editor mostra "o cliente anexa os arquivos" marcado')
    pg.fill('#modalRoot [name=cfg_aviso]', 'Aviso editado T237'); pg.screenshot(path=SHOT + '1_editor.png')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(2500)
    c2 = json.loads(sql(f"select config::text from pesquisa_perguntas where id = '{QD}'"))
    chk(c2.get('aviso') == 'Aviso editado T237' and c2.get('upload') and c2.get('sem_depois') and c2.get('onde') == QO and c2.get('periodo') and c2['categorias'][0]['k'] == 'vendas_hotmart' and c2['categorias'][0].get('se') == ['Hotmart'] and 'cols' in c2['categorias'][4],
        'salvar pelo editor troca só o que mudou e mantém anexar, "Onde vende", período, chaves e planilhas-modelo', {k: v for k, v in c2.items() if k != 'categorias'})
    # formulário público
    c3 = b.new_context(viewport={'width': 1000, 'height': 900}); c3.route('http://audit.local/**', front.rota); pp = c3.new_page()
    pp.goto('file://' + front.html() + f'?pesquisa={TOK}'); pp.wait_for_timeout(3500)
    pp.get_by_text('Hotmart', exact=True).click(); pp.click('[data-pf="segue"]'); pp.wait_for_timeout(600)
    vis = pp.evaluate("() => [...document.querySelectorAll('.pf-doc')].filter(d => !d.hidden && d.offsetParent).map(d => [d.querySelector('b').textContent, !!d.querySelector('input[type=file]')])")
    chk(vis and all(x[1] for x in vis) and vis[0][0] == 'Vendas da Hotmart' and not any(x[0] == 'Vendas da Kiwify' for x in vis), 'o formulário público mostra "Enviar arquivo" em cada grupo, só com as plataformas marcadas', vis)
    pp.screenshot(path=SHOT + '2_formulario_anexar.png', full_page=True)
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
sql(f"update workspaces set agencia = {'true' if AG0 == 't' else 'false'} where id = '{WS}'")
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
