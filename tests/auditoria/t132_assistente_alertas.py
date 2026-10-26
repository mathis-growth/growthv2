"""v0.132: "Como foi o meu dia?" (números exatos do dia, com e sem IA) e alertas automáticos.
Parte 1 (banco, cliente de teste T132 com leads controlados): fatos do dia, alerta brusco, queda seguida, sem repetir,
fila de avisos por canal, resumo do dia e o que o agendador roda. Parte 2 (tela, Escola Aurora): Pergunte ao Growths e
Alertas e resumo do dia. Banco fa com a migração 20261028100000_assistente_alertas.sql; apaga o que criou."""
import sys, json, subprocess; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
WS = 'ac56e719-7325-4062-aa47-74bc2141f89d'
UID = front.UID
def sql(q, role=None):
    r = subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', (f"set role {role}; " if role else '') + q], capture_output=True, text=True)
    if r.returncode: raise Exception(r.stderr.strip())
    return r.stdout.strip()
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
def limpa():
    sql("delete from workspaces where nome = 'T132 Alertas'")
    sql(f"delete from alertas where workspace_id = '{WS}'"); sql(f"delete from resumos_diarios where workspace_id = '{WS}'"); sql(f"delete from alertas_config where workspace_id = '{WS}'")
    sql(f"delete from notificacoes where workspace_id = '{WS}' and tipo in ('alerta', 'resumo', 'teste')"); sql(f"set session_replication_role = replica; delete from notificacoes where destinatario_id in (select id from equipe where workspace_id = '{WS}' and nome = 'T132 Rebecka'); delete from equipe where workspace_id = '{WS}' and nome = 'T132 Rebecka'")
limpa()

# ---------- parte 1: banco ----------
T = sql("insert into workspaces (nome) values ('T132 Alertas') returning id").split('\n')[0]
E1 = sql(f"insert into equipe (workspace_id, nome, email, telefone, acesso_ativo, avisar_app, avisar_email, avisar_whatsapp) values ('{T}', 'Ana', 'ana@t132.com', '31988887777', true, true, true, true) returning id").split('\n')[0]
sql(f"insert into equipe (workspace_id, nome, acesso_ativo) values ('{T}', 'Sem acesso', false)")
# 14 dias com 20 leads (09/10 a 22/10), 23/10 com 2; leads de 19 a 23: 20 → 16 → 12 → 8 → 2
def leads(dia, n):
    sql(f"insert into pessoas (workspace_id, nome, email, criado_em, canal_origem) select '{T}', 'L' || g, 't132-{dia}-' || g || '@x.com', '{dia} 15:00-03'::timestamptz, case when g % 2 = 0 then 'meta' else 'google' end from generate_series(1, {n}) g")
import datetime as dt
d0 = dt.date(2026, 10, 9)
for i in range(14): leads(d0 + dt.timedelta(i), 20)
sql(f"delete from pessoas where workspace_id = '{T}' and criado_em::date between '2026-10-20' and '2026-10-22'")
leads('2026-10-20', 16); leads('2026-10-21', 12); leads('2026-10-22', 8); leads('2026-10-23', 2)
f = json.loads(sql(f"select growths_fatos_dia('{T}', '2026-10-23')"))
chk(f['leads'] == 2 and f['dia_semana'] == 'sexta-feira' and f['leads_por_origem'][0]['leads'] == 1, 'fatos do dia: 2 leads na sexta 23/10, por origem')
chk(f['comparacao']['media_7_dias_anteriores']['leads'] == round((20 * 4 + 16 + 12 + 8) / 7, 1) and f['comparacao']['mesmo_dia_semana_passada']['leads'] == 20, 'comparação: média dos 7 dias anteriores e a sexta anterior')
chk(f['comparacao']['variacao_vs_media_pct']['leads'] == round((2 / ((20 * 4 + 16 + 12 + 8) / 7) - 1) * 100, 1), 'variação contra a média em %')
r = json.loads(sql(f"select growths_verificar_alertas('{T}', '2026-10-24 10:00-03', true)"))
regras = sql(f"select string_agg(regra || ':' || severidade, ',' order by regra) from alertas where workspace_id = '{T}'")
chk(regras == 'brusco_leads:alta,queda_seguida:alta', 'detecta a queda brusca de ontem e os leads caindo 3 dias seguidos (%s)' % regras)
tit = sql(f"select titulo || ' | ' || mensagem from alertas where workspace_id = '{T}' and regra = 'brusco_leads'")
chk(tit.startswith('Leads caíram 89% ontem') and '23/10 (sexta-feira): 2' in tit, 'texto do alerta brusco: ' + tit[:90])
chk('20 → 16 → 12 → 8 → 2' in sql(f"select mensagem from alertas where workspace_id = '{T}' and regra = 'queda_seguida'") or '16 → 12 → 8 → 2' in sql(f"select mensagem from alertas where workspace_id = '{T}' and regra = 'queda_seguida'"), 'alerta de queda seguida mostra os números de cada dia')
fila = sql(f"select string_agg(canal || ':' || status, ',' order by canal) from notificacoes where workspace_id = '{T}' and tipo = 'alerta'")
chk(fila == 'app:enviada,email:pendente,whatsapp:pendente', 'um aviso por canal da pessoa com acesso (sino entregue; e-mail e WhatsApp na fila) — %s' % fila)
chk(sql(f"select titulo from notificacoes where workspace_id = '{T}' and tipo = 'alerta' and canal = 'app'") == '2 alertas novos no Growths', 'dois alertas viram um aviso só')
r2 = json.loads(sql(f"select growths_verificar_alertas('{T}', '2026-10-24 11:00-03', true)"))
chk(r2['novos'] == 0 and sql(f"select count(*) from notificacoes where workspace_id = '{T}' and tipo = 'alerta'") == '3', 'rodar de novo não repete o alerta nem o aviso')
leads('2026-10-24', 1)
r3 = json.loads(sql(f"select growths_verificar_alertas('{T}', '2026-10-25 10:00-03', false)"))
chk(r3['novos'] == 0, 'a queda que continua no dia seguinte não vira outro alerta (espera alguns dias)')
r4 = json.loads(sql(f"select growths_verificar_alertas('{T}', '2026-10-27 10:00-03', false)"))
chk(r4['titulos'] == ['Nenhum dado de ontem chegou'], 'dia sem nenhum dado vira um alerta só de "dado não chegou" (e não vários "caiu 100%%") %s' % r4)
# só quem está marcado recebe
sql(f"insert into alertas_config (workspace_id, destinatarios) values ('{T}', array[(select id from equipe where workspace_id = '{T}' and nome = 'Sem acesso')]::uuid[])")
sql(f"update equipe set avisar_email = false where workspace_id = '{T}' and nome = 'Sem acesso'")
sql(f"select growths_resumo_gerar('{T}', '2026-10-23', true)")
chk(sql(f"select string_agg(e.nome || ':' || n.canal, ',') from notificacoes n join equipe e on e.id = n.destinatario_id where n.workspace_id = '{T}' and n.tipo = 'resumo'") == 'Sem acesso:app', 'com destinatários marcados, só eles recebem (e pelos canais deles)')
txt = sql(f"select texto from resumos_diarios where workspace_id = '{T}' and dia = '2026-10-23'")
chk(txt.startswith('Resumo de sexta-feira, 23/10\n- Leads: 2 · média dos 7 dias anteriores: 16,6 (-88%)') and '- Alertas: ' in txt, 'resumo em texto com a comparação e os alertas do dia')
sql(f"select growths_resumo_gerar('{T}', '2026-10-23', true)")
chk(sql(f"select count(*) from notificacoes where workspace_id = '{T}' and tipo = 'resumo'") == '1', 'o resumo do dia só é enviado uma vez')
# agendador: antes da hora não manda resumo; depois manda o de ontem
sql(f"update alertas_config set destinatarios = '{{}}', resumo_hora = 7 where workspace_id = '{T}'")
a1 = json.loads(sql("select growths_rodar_agendado('2026-10-25 06:10-03')"))
chk(sql(f"select count(*) from resumos_diarios where workspace_id = '{T}' and dia = '2026-10-24'") == '0', 'agendador às 6h: ainda não manda o resumo das 7h')
a2 = json.loads(sql("select growths_rodar_agendado('2026-10-25 07:10-03')"))
chk(sql(f"select avisado_em is not null from resumos_diarios where workspace_id = '{T}' and dia = '2026-10-24'") == 't' and a2['na_fila'] >= 1, 'agendador às 7h: resumo de ontem enviado; e-mails na fila (%s)' % a2)
# segurança
try: sql(f"select growths_verificar_alertas('{T}')", 'anon'); chk(False, 'anon não roda a verificação')
except Exception as e: chk('permission denied' in str(e), 'anon não roda a verificação')
try: sql("select growths_rodar_agendado()", 'authenticated'); chk(False, 'só o banco roda o agendador')
except Exception as e: chk('permission denied' in str(e), 'só o banco roda o agendador')
chk(sql("select has_table_privilege('authenticated', 'sistema_config', 'select')") == 'f', 'a senha do agendador não é legível pelo sistema')
sql("delete from workspaces where nome = 'T132 Alertas'")

# ---------- parte 2: telas (Escola Aurora, hoje = 15/10) ----------
# a pessoa logada da auditoria na Equipe (sem o gatilho de acessos, que exige uma função de administrador)
EQ = sql(f"set session_replication_role = replica; insert into equipe (workspace_id, nome, email, user_id, acesso_ativo, avisar_app, avisar_email) values ('{WS}', 'T132 Rebecka', 'auditoria@escolaaurora.com.br', '{UID}', true, true, true) returning id").split('\n')[0]
L14 = sql(f"select count(*) from pessoas where workspace_id = '{WS}' and (criado_em at time zone 'America/Sao_Paulo')::date = '2026-10-14'")
V14 = sql(f"select count(*) from vendas where workspace_id = '{WS}' and status = 'aprovada' and (data_venda at time zone 'America/Sao_Paulo')::date = '2026-10-14'")
with sync_playwright() as pw:
    b = pw.chromium.launch(); ctx, pg = front.abre(b, vw=1500, vh=1000)
    front.vai(pg, 'ia-perguntar', "S.ia = null;", 4000)
    t = pg.inner_text('#main')
    chk('Pergunte ao Growths' in t and 'Como foi?' in t, 'tela Pergunte ao Growths com os botões do dia')
    pg.fill('#iaPerg', 'Como foi meu dia ontem?'); pg.click('#iaGo'); pg.wait_for_timeout(3500)
    card = pg.locator('.fd-card').first
    ct = card.inner_text()
    chk('quarta-feira, 14/10' in ct, 'pergunta "como foi meu dia ontem?" responde com o dia 14/10 sem precisar de IA')
    chk(card.locator('.fd-k').first.locator('b').inner_text() == L14 and card.locator('.fd-k').nth(1).locator('b').inner_text() == V14, 'leads e vendas do cartão batem com o banco (%s leads, %s vendas)' % (L14, V14))
    pg.click('[data-dia="2026-10-15"]'); pg.wait_for_timeout(3500)
    chk('15/10' in pg.locator('.fd-card').first.inner_text(), 'botão "Hoje até agora" mostra o dia de hoje')
    chk(pg.locator('[data-copia]').count() >= 2, 'cada dia tem "Copiar resumo"')
    # alertas
    front.vai(pg, 'ia-alertas', "S.alF = null;", 5000)
    t = pg.inner_text('#main')
    chk('Alertas e resumo do dia' in t and 'ainda não estão ligados' in t, 'tela de alertas avisa que não está ligado para o cliente')
    pg.click('#alLiga'); pg.wait_for_timeout(3000)
    chk(sql(f"select ligado::text || resumo_hora from alertas_config where workspace_id = '{WS}'") == 'true7', 'botão liga alertas e resumo às 7h')
    sql(f"insert into alertas (workspace_id, chave, tipo, regra, severidade, titulo, mensagem, dia) values ('{WS}', 't132:a', 'brusco', 'brusco_leads', 'alta', 'Leads caíram 50% ontem', 'Teste', '2026-10-14'), ('{WS}', 't132:b', 'operacional', 'contas_vencidas', 'media', '2 conta(s) a pagar vencida(s)', 'Teste', '2026-10-15')")
    front.vai(pg, 'ia-alertas', "", 5000)
    chk(pg.locator('.al-c').count() == 2 and pg.locator('.al-c.alta .sem-p-desf').count() == 1 and pg.locator('.al-c.media .sem-p-aten').count() == 1, 'lista os alertas abertos com a categoria (v0.156: Desfavorável e Atenção)')
    pg.locator('[data-resolve]').first.click(); pg.wait_for_timeout(2500)
    chk(pg.locator('.al-c').count() == 1 and sql(f"select count(*) from alertas where workspace_id = '{WS}' and resolvido_em is not null") == '1', 'marcar como resolvido tira da lista de abertos')
    chk(sql(f"select count(*) from alertas where workspace_id = '{WS}' and visto_em is null") == '0', 'abrir a tela marca os alertas como vistos')
    pg.locator('[data-diaal]').first.click(); pg.wait_for_timeout(3000)
    chk(pg.locator('#alRes .fd-card').count() == 1, '"Ver o dia" abre os números do dia do alerta')
    # configuração
    pg.fill('#cPct', '60'); pg.uncheck('[data-regra="contas_vencidas"]'); pg.select_option('#cHora', '8'); pg.check(f'[data-dest="{EQ}"]')
    pg.click('#cSalva'); pg.wait_for_timeout(2500)
    c = json.loads(sql(f"select row_to_json(x) from (select resumo_hora, regras, destinatarios from alertas_config where workspace_id = '{WS}') x"))
    chk(c['resumo_hora'] == 8 and c['regras']['variacao_pct'] == 60 and c['regras']['desligadas'] == ['contas_vencidas'] and c['destinatarios'] == [EQ], 'salva hora, sensibilidade, regras desligadas e quem recebe')
    pg.locator(f'[data-can="avisar_whatsapp"][data-eq="{EQ}"]').check(); pg.wait_for_timeout(1500)
    chk(sql(f"select avisar_whatsapp from equipe where id = '{EQ}'") == 't', 'liga o WhatsApp da pessoa direto na tela')
    chk('E-mail: falta configurar' in pg.inner_text('#main') or 'E-mail: não consegui conferir' in pg.inner_text('#main'), 'mostra se e-mail e WhatsApp já estão configurados')
    pg.click('#cTeste'); pg.wait_for_timeout(3000)
    chk(sql(f"select string_agg(canal, ',' order by canal) from notificacoes where workspace_id = '{WS}' and tipo = 'teste'") == 'app,email', 'aviso de teste para mim: sino e e-mail (WhatsApp sem telefone fica de fora)')
    pg.click('#sino'); pg.wait_for_timeout(2000)
    chk('Aviso de teste' in pg.inner_text('#modalRoot'), 'o aviso de teste aparece no sino')
    pg.evaluate("document.querySelector('#modalRoot').innerHTML = ''")
    chk(not pg.errs, 'sem erro de JavaScript ' + str(pg.errs[:2]))
    b.close()
limpa()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
