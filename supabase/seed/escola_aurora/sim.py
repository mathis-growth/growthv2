"""Simula o lançamento 'Semana da Fluência' (Escola Aurora): campanhas de captação, 31 anúncios, métricas diárias de 01 a 16/10/2026."""
import json, math, random, datetime as dt
R = random.Random(2026)
D0 = dt.date(2026, 10, 1); HOJE = dt.date(2026, 10, 17); DIAS = [(D0 + dt.timedelta(i)) for i in range((HOJE - D0).days)]  # 01..16/10
NCAP = 26  # captação: 01 a 26/10
def ramp(i):  # i = 0..25
    return 0.7 if i < 5 else 1.0 if i < 12 else 1.13
RS = sum(ramp(i) for i in range(NCAP))
# canal (Growths) → campanhas de anúncio (campanha_canais)
CAMPS = [
  # chave, canal, nome, utm, orçamento, meta_leads, temperatura, cpm, ctr, connect, conv, freq_rate, pacing
  dict(k='int', canal='meta_ads', nome='[CAP] Frio · Interesses', utm='lfa26-meta-frio-interesses', orc=5500, meta=1200, temp='frio', cpm=24, ctr=.0135, con=.80, conv=.43, fr=.060, pac=.97),
  dict(k='lal', canal='meta_ads', nome='[CAP] Frio · Lookalike de alunos', utm='lfa26-meta-frio-lookalike', orc=4500, meta=1000, temp='frio', cpm=27, ctr=.0145, con=.82, conv=.45, fr=.070, pac=.95),
  dict(k='adv', canal='meta_ads', nome='[CAP] Frio · Aberto (Advantage+)', utm='lfa26-meta-frio-advantage', orc=3000, meta=600, temp='frio', cpm=19, ctr=.0120, con=.78, conv=.38, fr=.045, pac=1.12),
  dict(k='rmk', canal='meta_ads', nome='[CAP] Quente · Remarketing', utm='lfa26-meta-quente-remarketing', orc=2000, meta=500, temp='quente', cpm=42, ctr=.0210, con=.88, conv=.58, fr=.165, pac=.72),
  dict(k='yt', canal='google_ads', nome='[CAP] YouTube · In-stream', utm='lfa26-google-youtube', orc=2000, meta=260, temp='frio', cpm=16, ctr=.0075, con=.70, conv=.42, fr=.030, pac=1.0),
  dict(k='src', canal='google_ads', nome='[CAP] Pesquisa · Inglês para adultos', utm='lfa26-google-pesquisa', orc=1000, meta=170, temp='quente', cpm=100, ctr=.065, con=.90, conv=.27, fr=0, pac=.82),
  dict(k='tt', canal='tiktok_ads', nome='[CAP] TikTok · Spark Ads', utm='lfa26-tiktok-spark', orc=2000, meta=400, temp='frio', cpm=11, ctr=.0085, con=.65, conv=.33, fr=.050, pac=.90),
]
# anúncios: código, campanha, nome, ângulo, formato, ctr×, conv×, fadiga, início, pausa (último dia ativo), título/legenda do criativo
A = lambda *x: dict(zip(['cod', 'camp', 'nome', 'angulo', 'formato', 'mc', 'mv', 'fat', 'ini', 'fim', 'hook', 'sub'], x))
W2 = dt.date(2026, 10, 8)
ADS = [
  A('AD01', 'int', 'Trava na hora de falar', 'dor', 'estatico', 1.50, 1.08, .42, D0, None, 'Você entende tudo, mas trava na hora de falar?', 'Aula gratuita · 27/10'),
  A('AD02', 'int', 'Entende mas não fala', 'dor', 'reels', 1.00, 1.00, .20, D0, None, 'Eu lia, ouvia, entendia… e travava.', 'Semana da Fluência'),
  A('AD03', 'int', 'Depoimento Carla · 6 meses', 'prova', 'reels', 1.18, 1.15, .14, D0, None, '“Em 6 meses fiz minha 1ª reunião em inglês”', 'Carla, gerente de projetos'),
  A('AD04', 'int', '3 erros de quem estuda sozinho', 'autoridade', 'carrossel', .85, 1.00, .18, D0, None, '3 erros de quem estuda inglês sozinho', 'Arraste para o lado'),
  A('AD05', 'int', 'Semana da Fluência · aulas grátis', 'evento', 'estatico', .95, 1.12, .22, D0, None, 'Semana da Fluência', '3 aulas ao vivo e gratuitas · 27 a 31/10'),
  A('AD06', 'int', 'Inglês em 20 min por dia', 'desejo', 'estatico', .55, .80, .22, D0, dt.date(2026, 10, 5), 'Inglês em 20 minutos por dia', 'Método Aurora'),
  A('AD07', 'int', 'Viajar sem medo', 'desejo', 'reels', .90, .95, .18, D0, None, 'Pedir um café em Nova York sem medo', 'Semana da Fluência'),
  A('AD08', 'int', 'Antes e depois · áudio real', 'prova', 'reels', 1.22, 1.10, .14, W2, None, 'Ouça o antes e o depois', 'Áudio real de aluno · 90 dias'),
  A('AD09', 'int', 'Quiz · qual é o seu nível?', 'curiosidade', 'carrossel', 1.05, .86, .20, W2, None, 'Qual é o seu nível de inglês?', 'Faça o teste em 1 minuto'),
  A('AD10', 'lal', 'Trava na hora de falar', 'dor', 'estatico', 1.38, 1.06, .40, D0, None, 'Você entende tudo, mas trava na hora de falar?', 'Aula gratuita · 27/10'),
  A('AD11', 'lal', 'Depoimento Carla · 6 meses', 'prova', 'reels', 1.12, 1.18, .14, D0, None, '“Em 6 meses fiz minha 1ª reunião em inglês”', 'Carla, gerente de projetos'),
  A('AD12', 'lal', '3 erros de quem estuda sozinho', 'autoridade', 'carrossel', .92, 1.02, .18, D0, None, '3 erros de quem estuda inglês sozinho', 'Arraste para o lado'),
  A('AD13', 'lal', 'Promoção no trabalho', 'desejo', 'estatico', .98, 1.00, .22, D0, None, 'A promoção pedia inglês. E agora?', 'Semana da Fluência · grátis'),
  A('AD14', 'lal', 'Aula ao vivo 27/10', 'evento', 'stories', 1.00, 1.15, .24, W2, None, 'Dia 27/10, 20h', 'Aula 1 · Destrave a fala'),
  A('AD15', 'lal', 'Método em 4 passos', 'autoridade', 'carrossel', .62, .85, .20, D0, dt.date(2026, 10, 9), 'O método em 4 passos', 'Escola Aurora'),
  A('AD16', 'adv', 'Trava na hora de falar', 'dor', 'estatico', 1.15, 1.02, .28, D0, None, 'Você entende tudo, mas trava na hora de falar?', 'Aula gratuita · 27/10'),
  A('AD17', 'adv', 'Depoimento Carla · 6 meses', 'prova', 'reels', 1.05, 1.12, .14, D0, None, '“Em 6 meses fiz minha 1ª reunião em inglês”', 'Carla, gerente de projetos'),
  A('AD18', 'adv', 'Antes e depois · áudio real', 'prova', 'reels', 1.15, 1.08, .14, W2, None, 'Ouça o antes e o depois', 'Áudio real de aluno · 90 dias'),
  A('AD19', 'adv', 'Você fala “I am agree”?', 'curiosidade', 'estatico', 1.62, 1.02, .16, D0, None, 'Você fala “I am agree”?', 'O erro que 8 em 10 brasileiros cometem'),
  A('AD20', 'rmk', 'Faltam poucos dias', 'evento', 'stories', 1.05, 1.05, .30, D0, None, 'Faltam poucos dias', 'Semana da Fluência · 27/10'),
  A('AD21', 'rmk', 'Depoimentos em sequência', 'prova', 'carrossel', 1.00, 1.08, .20, D0, None, 'Eles destravaram. Você é o próximo.', '4 histórias reais'),
  A('AD22', 'rmk', 'Garanta sua vaga', 'evento', 'estatico', .92, 1.00, .26, D0, None, 'Sua vaga na Semana da Fluência', 'Gratuito · vagas no grupo VIP'),
  A('AD23', 'rmk', 'Bastidores da aula', 'autoridade', 'reels', 1.10, 1.05, .16, W2, None, 'Bastidores da aula 1', 'Prof. Helena Aurora'),
  A('AD24', 'yt', 'Vídeo 45s · Trava na hora de falar', 'dor', 'video', 1.00, 1.00, .10, D0, None, 'Por que você trava no inglês', 'Vídeo · 45s'),
  A('AD25', 'yt', 'Vídeo 30s · Depoimento Carla', 'prova', 'video', 1.10, 1.08, .10, D0, None, 'Da trava à reunião em inglês', 'Vídeo · 30s'),
  A('AD26', 'yt', 'Bumper 6s · Semana da Fluência', 'evento', 'video', .80, .90, .12, W2, None, 'Semana da Fluência', 'Bumper · 6s'),
  A('AD27', 'src', 'Busca · curso de inglês online', 'oferta', 'texto', 1.00, 1.05, 0, D0, None, 'Curso de inglês online para adultos', 'Aulas ao vivo grátis de 27 a 31/10'),
  A('AD28', 'src', 'Busca · inglês rápido', 'oferta', 'texto', .70, .70, 0, D0, dt.date(2026, 10, 12), 'Aprenda inglês rápido', 'Método Aurora · comece hoje'),
  A('AD29', 'tt', 'POV: você trava no inglês', 'dor', 'vertical', 1.05, .95, .22, D0, None, 'POV: o gringo pergunta e você trava', 'Semana da Fluência'),
  A('AD30', 'tt', 'Professora reage a erros', 'autoridade', 'vertical', 1.12, 1.00, .20, D0, None, 'Professora reage aos erros mais comuns', 'Prof. Helena Aurora'),
  A('AD31', 'tt', 'Fala comigo em inglês', 'curiosidade', 'vertical', .95, .92, .24, W2, None, 'Responde em inglês em 3 segundos', 'Desafio · Semana da Fluência'),
]
CB = {c['k']: c for c in CAMPS}
rows = []; st = {a['cod']: {'cplh': None} for a in ADS}
for i, d in enumerate(DIAS):
    for c in CAMPS:
        orc_d = c['orc'] / RS * ramp(i) * c['pac'] * R.uniform(.93, 1.06)
        if c['k'] == 'adv' and d >= dt.date(2026, 10, 11): orc_d *= 1.25   # escalou depois do AD19
        ativos = [a for a in ADS if a['camp'] == c['k'] and a['ini'] <= d and (a['fim'] is None or d <= a['fim'])]
        # o algoritmo da plataforma dá mais verba a quem tem CPL melhor (com exploração)
        pesos = []
        for a in ativos:
            idade = (d - a['ini']).days
            q = a['mc'] * a['mv'] if st[a['cod']]['cplh'] is None else 1 / max(st[a['cod']]['cplh'], 1)
            if idade < 3: q = max(q, .9 * (sum(x['mc'] * x['mv'] for x in ativos) / len(ativos)))
            pesos.append(max(q, .05) ** 1.6)
        sp = sum(pesos)
        for a, p in zip(ativos, pesos):
            custo = round(orc_d * p / sp, 2)
            if custo < 1: continue
            idade = (d - a['ini']).days
            freq = 1.05 + c['fr'] * idade * (1.15 if a['fat'] > .25 else 1) + R.uniform(-.04, .06)
            ctr = c['ctr'] * a['mc'] * max(.42, 1 - a['fat'] * (freq - 1.05)) * R.uniform(.92, 1.08)
            cpm = c['cpm'] * (1 + .04 * (freq - 1.05)) * R.uniform(.94, 1.07)
            imp = int(custo / cpm * 1000)
            cli = max(0, int(round(imp * ctr)))
            vis = int(round(cli * c['con'] * R.uniform(.95, 1.04)))
            conv = c['conv'] * a['mv'] * R.uniform(.9, 1.1)
            led = sum(1 for _ in range(vis) if R.random() < conv)
            alc = int(imp / freq) if c['fr'] else int(imp * .92)
            rows.append(dict(cod=a['cod'], data=d.isoformat(), imp=imp, cli=cli, custo=custo, vis=vis, alc=alc, leads=led))
            cpl = custo / led if led else custo
            h = st[a['cod']]['cplh']; st[a['cod']]['cplh'] = cpl if h is None else .6 * h + .4 * cpl
# orgânicos (sem verba): Instagram (bio, stories, lives) e e-mail para a base
org = []
for i, d in enumerate(DIAS):
    ig = int(14 + i * 1.3 + R.uniform(-4, 6)) + (35 if d.isoformat() in ('2026-10-06', '2026-10-13') else 0)  # lives
    em = {'2026-10-01': 118, '2026-10-02': 41, '2026-10-08': 86, '2026-10-09': 27, '2026-10-15': 64, '2026-10-16': 22}.get(d.isoformat(), R.randint(2, 6))
    org.append(dict(data=d.isoformat(), ig=ig, email=em))
tot = lambda k: sum(r[k] for r in rows)
print('investido', round(tot('custo'), 2), 'leads pagos', tot('leads'), 'CPL', round(tot('custo') / tot('leads'), 2), 'org', sum(o['ig'] + o['email'] for o in org))
for c in CAMPS:
    rr = [r for r in rows if next(a for a in ADS if a['cod'] == r['cod'])['camp'] == c['k']]
    s = sum(r['custo'] for r in rr); l = sum(r['leads'] for r in rr)
    print(' %-38s gasto %8.2f (%3.0f%% do orç.)  leads %4d  CPL %5.2f  meta CPL %5.2f' % (c['nome'], s, s / c['orc'] * 100, l, s / max(l, 1), c['orc'] / c['meta']))
for a in ADS:
    rr = [r for r in rows if r['cod'] == a['cod']]; s = sum(r['custo'] for r in rr); l = sum(r['leads'] for r in rr)
    ult = [r for r in rr if r['data'] >= '2026-10-10']; pri = [r for r in rr if r['data'] < '2026-10-10']
    ctr = lambda L: sum(r['cli'] for r in L) / max(1, sum(r['imp'] for r in L)) * 100
    fq = lambda L: sum(r['imp'] for r in L) / max(1, sum(r['alc'] for r in L))
    print('  %s %-34s %8.2f  leads %4d  CPL %6.2f  CTR %.2f→%.2f  freq7d %.2f' % (a['cod'], a['nome'][:34], s, l, s / max(l, 1), ctr(pri), ctr(ult), fq(ult)))
json.dump(dict(camps=CAMPS, ads=[{**a, 'ini': a['ini'].isoformat(), 'fim': a['fim'].isoformat() if a['fim'] else None} for a in ADS], rows=rows, org=org), open('plano.json', 'w'), ensure_ascii=False, indent=0)
