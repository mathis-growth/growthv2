"""v0.244: aviso de lead novo para toda a equipe (faixa verde no topo, Meus avisos e WhatsApp na fila) e "Gerar novo link" nas pesquisas.
Banco: lead novo gera um aviso por pessoa da equipe ativa, nos canais de cada uma (app e WhatsApp na fila); quem desligou "lead novo" não recebe;
6 leads de uma vez geram um aviso só com o total; trocar o código do link aberto.
Tela: a faixa verde aparece no topo com o nome do lead; "Abrir" abre o cartão e marca como lido; "×" dispensa; "Gerar novo link" troca o
código (o antigo para de funcionar) ou só atualiza o endereço (mesmo código, endereço oficial do Growths). Banco fa (Escola Aurora)."""
import sys, os, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots244/'; os.makedirs(SHOT, exist_ok=True)
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
    sql(f"delete from notificacoes where workspace_id = '{WS}' and destinatario_id in (select id from equipe where workspace_id = '{WS}' and nome like 'T244%')")
    sql(f"set session_replication_role = replica; delete from equipe where workspace_id = '{WS}' and nome like 'T244%'")
    sql(f"delete from pessoas where workspace_id = '{WS}' and nome like 'Lead T244%'")
    sub = f"(select id from pesquisas where workspace_id = '{WS}' and nome like 'T244%')"; sql(f"delete from pesquisa_perguntas where pesquisa_id in {sub}"); sql(f"delete from pesquisas where id in {sub}")
limpa()
EU = one(f"set session_replication_role = replica; insert into equipe (workspace_id, nome, email, ativo, avisar_app, avisar_email, avisar_whatsapp, telefone) values ('{WS}', 'T244 Eu', 'auditoria@escolaaurora.com.br', true, true, false, true, '5531988887777') returning id")
OUT = one(f"insert into equipe (workspace_id, nome, ativo, avisar_app, avisar_email, avisar_whatsapp) values ('{WS}', 'T244 Outra', true, true, false, false) returning id")
DESL = one(f"insert into equipe (workspace_id, nome, ativo, avisar_app, avisar_email, avisar_whatsapp, avisar_lead_novo) values ('{WS}', 'T244 Desligou', true, true, false, false, false) returning id")
L1 = one(f"insert into pessoas (workspace_id, nome, email, canal_origem, utm_campaign) values ('{WS}', 'Lead T244 Ana', 'ana@t244.com', 'instagram', 'qualificacao') returning id")
r = sql(f"select canal || '|' || status || '|' || titulo || '|' || mensagem from notificacoes where destinatario_id = '{EU}' and pessoa_id = '{L1}' order by canal")
chk('app|enviada|Novo lead: Lead T244 Ana|Chegou por instagram · campanha qualificacao. Abra o CRM para ver.' in r and 'whatsapp|pendente|Novo lead: Lead T244 Ana' in r, 'lead novo: aviso no app e WhatsApp na fila para quem tem WhatsApp ligado', r)
chk(sql(f"select count(*) from notificacoes where destinatario_id = '{OUT}' and pessoa_id = '{L1}' and canal = 'app'") == '1', 'toda a equipe ativa recebe (não só o responsável)')
chk(sql(f"select count(*) from notificacoes where destinatario_id = '{DESL}'") == '0', 'quem desligou "lead novo" não recebe')
sql(f"insert into pessoas (workspace_id, nome) select '{WS}', 'Lead T244 Lote ' || g from generate_series(1, 6) g")
chk(sql(f"select count(*) || '|' || max(titulo) from notificacoes where destinatario_id = '{OUT}' and titulo like '%leads novos'") == '1|6 leads novos', '6 leads de uma vez (importação): um aviso só com o total')
P = one(f"insert into pesquisas (workspace_id, nome, tipo, publico, ativa, aceita_link_aberto, captacao) values ('{WS}', 'T244 Form', 'lead', 'lead', true, true, '{{\"ativa\":true,\"campos\":{{}}}}') returning id")
T0 = sql(f"select token_aberto from pesquisas where id = '{P}'")
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx, pg = front.abre(b, hoje='2026-11-02', vw=1440, vh=1000)
    front.vai(pg, 'cockpit', '', 3000); pg.evaluate("() => atualizaSino()"); pg.wait_for_timeout(2500)
    t = pg.text_content('#leadFaixa') or ''
    chk('6 leads novos' in t or 'Novo lead:' in t, 'a faixa verde aparece no topo com o aviso de lead novo', t[:200])
    chk('e mais' in t, 'com mais de um aviso, mostra "e mais…"', t[:200])
    pg.screenshot(path=SHOT + '1_faixa_verde.png')
    # dispensar tudo
    pg.click('#leadFaixa [data-lf-x]'); pg.wait_for_timeout(1500)
    chk(pg.locator('#leadFaixa').count() == 0 and sql(f"select count(*) from notificacoes where destinatario_id = '{EU}' and canal = 'app' and lida_em is null") == '0', '"×" dispensa e marca como lidos')
    L2 = one(f"insert into pessoas (workspace_id, nome, canal_origem) values ('{WS}', 'Lead T244 Beto', 'site') returning id")
    pg.evaluate("() => atualizaSino()"); pg.wait_for_timeout(2000)
    chk('Novo lead: Lead T244 Beto' in (pg.text_content('#leadFaixa') or ''), 'lead que chega depois aparece na faixa')
    pg.click('#leadFaixa [data-lf-abre]'); pg.wait_for_timeout(2500)
    chk(sql(f"select lida_em is not null from notificacoes where destinatario_id = '{EU}' and pessoa_id = '{L2}' and canal = 'app'") == 't' and 'Lead T244 Beto' in (pg.text_content('body') or ''), '"Abrir" abre o cartão do lead e marca como lido')
    pg.keyboard.press('Escape'); pg.evaluate("() => { const r = document.getElementById('modalRoot'); if (r) r.innerHTML = ''; }")
    # gerar novo link
    pg.evaluate("() => { window.__cp = null; navigator.clipboard.writeText = t => { window.__cp = t; return Promise.resolve(); }; }")
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'form';", 4500); pg.wait_for_selector('[data-pq-novolink]', timeout=15000)
    pg.click('[data-pq-novolink]'); pg.wait_for_timeout(500); pg.screenshot(path=SHOT + '2_novo_link.png')
    pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(1500)
    chk(pg.evaluate("() => window.__cp") == 'https://growths.app/?pesquisa=' + T0 and sql(f"select token_aberto from pesquisas where id = '{P}'") == T0, 'atualizar o endereço: mesmo código, no endereço oficial do Growths', pg.evaluate("() => window.__cp"))
    front.vai(pg, 'gro-pesq', f"S.pqSel = '{P}'; S.pqTab = 'form';", 4500); pg.wait_for_selector('[data-pq-novolink]', timeout=15000)
    pg.click('[data-pq-novolink]'); pg.wait_for_timeout(500); pg.check('#modalRoot [name=op][value=codigo]'); pg.click('#modalRoot button[type=submit]'); pg.wait_for_timeout(2500)
    T1 = sql(f"select token_aberto from pesquisas where id = '{P}'")
    chk(T1 != T0 and len(T1) >= 32 and pg.evaluate("() => window.__cp") == 'https://growths.app/?pesquisa=' + T1, 'trocar o código: o link antigo deixa de valer e o novo é copiado')
    errs = list(pg.errs); ctx.close(); b.close()
chk(not errs, 'sem erros de JavaScript', errs)
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
