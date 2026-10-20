"""Monta RODAR_escola_aurora.sql: workspace 'Escola Aurora' (histórico jul–out/2026) + lançamento 'Semana da Fluência' em captação."""
import json
P = json.load(open('plano.json')); IMG = json.load(open('imagens.json'))
q = lambda s: "'" + str(s).replace("'", "''") + "'" if s is not None else 'null'
CANAL = {c['k']: c for c in P['camps']}
# metas por campanha de anúncio (vendas esperadas) e redes
VENDAS = dict(int=17, lal=15, adv=9, rmk=10, yt=4, src=3, tt=5)
SRC = dict(meta_ads=('facebook', 'paid_social'), google_ads=('google', 'cpc'), tiktok_ads=('tiktok', 'paid_social'))
def slug(s):
    import unicodedata, re
    s = unicodedata.normalize('NFD', s).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')[:40]
L = []
L.append(r"""-- Growths — Escola Aurora (empresa fictícia para testar as telas) + Lançamento "Semana da Fluência" em captação.
-- Como usar: Supabase → SQL Editor → New query → cole este arquivo inteiro → Run. Leva alguns segundos.
-- Cria um workspace NOVO chamado "Escola Aurora" (não mexe na Mathisa nem nos outros). Se ele já existir, o arquivo para sem mudar nada.
-- O que entra:
--   • Histórico jul–out/2026: perpétuo do Curso Inglês Base (Meta Ads), lançamento de setembro (Google), mentoria em contratos,
--     despesas pagas, recebimentos, reembolsos — tudo pelos fluxos reais do banco (DRE, caixa e contas a receber batem).
--   • Lançamento "Formação Fluência · Semana da Fluência": captação de 01 a 26/10, aulas 27, 29 e 31/10, carrinho de 03 a 09/11.
--     R$ 20.000 de tráfego só na aquisição, 7 campanhas de anúncio (Meta, Google, TikTok) + Instagram orgânico e e-mail,
--     31 anúncios com imagem, métricas diárias de 01 a 16/10, leads, grupo VIP, pesquisa de qualificação, metas por canal.
-- Requer a v0.111 rodada? Não. Funciona com o banco até a v0.109; com a v0.111 também preenche o anexo do Simples.
begin;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$ begin
  if exists (select 1 from workspaces where nome = 'Escola Aurora') then raise exception 'O workspace "Escola Aurora" já existe. Nada foi alterado.'; end if;
  if not exists (select 1 from auth.users where email = 'rebecka@rebeckacappello.com.br') then raise exception 'Usuária rebecka@rebeckacappello.com.br não encontrada.'; end if;
end $$;
""")
# dados do lançamento em tabelas temporárias
L.append("create temp table _lfa_camp (k text primary key, canal text, nome text, utm text, orc numeric, meta int, temp text, vendas int) on commit drop;")
L.append("insert into _lfa_camp values\n" + ",\n".join(f"({q(c['k'])},{q(c['canal'])},{q(c['nome'])},{q(c['utm'])},{c['orc']},{c['meta']},{q(c['temp'])},{VENDAS[c['k']]})" for c in P['camps']) + ";")
L.append("create temp table _lfa_ad (cod text primary key, camp text, nome text, angulo text, formato text, ini date, fim date, utm_content text, img text) on commit drop;")
FMT = dict(estatico='Estático', reels='Reels', stories='Stories', carrossel='Carrossel', video='Vídeo', texto='Texto', vertical='Vertical')
L.append("insert into _lfa_ad values\n" + ",\n".join(f"({q(a['cod'])},{q(a['camp'])},{q(a['cod'] + ' · ' + a['nome'] + ' · ' + FMT[a['formato']])},{q(a['angulo'])},{q(a['formato'])},{q(a['ini'])},{q(a['fim'])},{q(a['cod'].lower() + '-' + slug(a['nome']))},null)" for a in P['ads']) + ";")
L.append("create temp table _lfa_img (nome text primary key, img text) on commit drop;")

L.append("create temp table _lfa_dia (cod text, data date, imp int, cli int, custo numeric, vis int, alc int, leads int) on commit drop;")
L.append("insert into _lfa_dia values\n" + ",\n".join(f"({q(r['cod'])},{q(r['data'])},{r['imp']},{r['cli']},{r['custo']},{r['vis']},{r['alc']},{r['leads']})" for r in P['rows']) + ";")
L.append("create temp table _lfa_org (data date, ig int, email int) on commit drop;")
L.append("insert into _lfa_org values\n" + ",\n".join(f"({q(o['data'])},{o['ig']},{o['email']})" for o in P['org']) + ";")
L.append(open('base.sql').read())
L.append(open('lancamento2.sql').read())
L.append("""commit;

-- Conferência (deve mostrar o workspace, 31 anúncios, ~R$ 11 mil investidos e ~3 mil leads na campanha)
select 'workspace' item, nome valor from workspaces where nome = 'Escola Aurora'
union all select 'anúncios do lançamento', count(*)::text from anuncios a join campanha_canais cc on cc.id = a.campanha_canal_id join campanhas c on c.id = cc.campanha_id where c.nome like 'Lançamento Formação Fluência%' and cc.tipo = 'pago'
union all select 'investido no lançamento (R$)', sum(m.custo)::text from metricas_anuncio_dia m join anuncios a on a.id = m.anuncio_id join campanha_canais cc on cc.id = a.campanha_canal_id join campanhas c on c.id = cc.campanha_id where c.nome like 'Lançamento Formação Fluência%'
union all select 'leads do lançamento', count(*)::text from campanha_participacoes p join campanhas c on c.id = p.campanha_id where c.nome like 'Lançamento Formação Fluência%'
union all select 'partidas D − C (deve ser 0)', sum(case tipo when 'D' then valor else -valor end)::text from partidas p join workspaces w on w.id = p.workspace_id where w.nome = 'Escola Aurora';
""")
open('RODAR_escola_aurora_1_dados.sql', 'w').write('\n'.join(L).replace('-- Como usar: Supabase', '-- PARTE 1 de 4 (dados). Depois rode as partes 2, 3 e 4 (imagens dos criativos).\n-- Como usar: Supabase'))
# partes 2 a 4: imagens (nome do anúncio → imagem)
nomes = {a['cod']: a['cod'] + ' · ' + a['nome'] + ' · ' + FMT[a['formato']] for a in P['ads']}
itens = [(nomes.get(k, k[2:]), v) for k, v in IMG.items()]
partes = [itens[i::3] for i in range(3)]
for n, pt in enumerate(partes, 2):
    s = f"-- Growths — Escola Aurora · PARTE {n} de 4: imagens dos criativos ({len(pt)} anúncios). Rode depois da parte 1. Pode rodar de novo.\n"
    s += "update anuncios a set imagem_url = x.img from (values\n" + ",\n".join(f"({q(nm)},{q(v)})" for nm, v in pt) + "\n) x(nome, img), workspaces w\nwhere w.nome = 'Escola Aurora' and a.workspace_id = w.id and a.nome = x.nome;\n"
    s += "select count(*) filter (where a.imagem_url is not null) as anuncios_com_imagem, count(*) as anuncios from anuncios a join workspaces w on w.id = a.workspace_id where w.nome = 'Escola Aurora';\n"
    open(f'RODAR_escola_aurora_{n}_imagens.sql', 'w').write(s)
import os; print('ok', os.path.getsize('RODAR_escola_aurora.sql') // 1024, 'KB')
