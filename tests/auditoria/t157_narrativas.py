"""v0.157: banco de narrativas (tabela narrativa_modelos) e piloto no Dashboard financeiro.
Banco fa (Escola Aurora, setembro/2026). As regras do banco rodam dentro de transação desfeita; o teste de "modelo não aprovado some da tela"
muda o status e devolve no fim."""
import sys, json, os; sys.path.insert(0, '.')
import front
from playwright.sync_api import sync_playwright
import subprocess as _sp
SHOT = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/shots157/'; os.makedirs(SHOT, exist_ok=True)
W = 'ac56e719-7325-4062-aa47-74bc2141f89d'
def q(x, u=None):
    pre = ("set role authenticated; set request.jwt.claims='{\"sub\":\"%s\",\"role\":\"authenticated\"}';" % u) if u else ''
    r = _sp.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-c', pre + x], capture_output=True, text=True)
    return (r.stdout.strip(), r.stderr.strip())
def v(x): return q(x)[0]
def _num(v, c): return ('%.' + str(c) + 'f') % abs(v)
def _br(v, c): s = _num(v, c); i, d = (s.split('.') + [''])[:2]; i = '{:,}'.format(int(i)).replace(',', '.'); return i + (',' + d if d else '')
def MIL(x): return ('−' if x < 0 else '') + 'R$ ' + _br(x / 1000, 1) + ' mil'
def BRL(x): return ('−' if x < 0 else '') + 'R$ ' + _br(x, 2)
def dre(m, g): return float(v(f"select coalesce(sum(valor),0) from v_dre_mensal where workspace_id='{W}' and mes='{m}-01' and tipo='{g}'") or 0)
RS = dre('2026-09', 'receita') - dre('2026-09', 'deducao') - dre('2026-09', 'despesa'); RA = dre('2026-08', 'receita') - dre('2026-08', 'deducao') - dre('2026-08', 'despesa'); REC = dre('2026-09', 'receita')
falhas = []
def chk(c, msg):
    print(('ok   ' if c else 'FALHA ') + msg)
    if not c: falhas.append(msg)
# ---------- banco: regras de governança (transação desfeita) ----------
chk(v("select count(*) from narrativa_modelos") == '39' and v("select count(*) from narrativa_modelos where status='aprovado'") == '9', '39 modelos, 9 aprovados (os do piloto)')
chk(v("select array_to_string(campos, ',') from narrativa_modelos where codigo='NAR-D02'") == 'receita,abs_resultado,resultado,margem', 'campos tirados do texto, na ordem')
H0 = int(v("select count(*) from narrativa_modelos_historico where codigo='NAR-D02' and versao=1"))
o, e = q("begin; update narrativa_modelos set modelo = modelo || ' ' where codigo='NAR-D02'; select versao, status, (select count(*) from narrativa_modelos_historico where codigo='NAR-D02' and versao=1) from narrativa_modelos where codigo='NAR-D02'; rollback;")
chk(o == '2|proposto|%d' % (H0 + 1), 'texto mudou: versão sobe, volta para proposto e a anterior vai para o histórico ' + o)
o, e = q("begin; update narrativa_modelos set observacao='x' where codigo='NAR-D02'; select versao, status from narrativa_modelos where codigo='NAR-D02'; rollback;")
chk(o == '1|aprovado', 'observação não mexe na versão ' + o)
chk('não se apaga' in q("begin; delete from narrativa_modelos where codigo='NAR-N01'; rollback;")[1], 'modelo não se apaga (descontinuar)')
chk('marcação inválida' in q("begin; update narrativa_modelos set modelo='Valor {Receita} [a]' where codigo='NAR-D01'; rollback;")[1], 'marcação inválida é recusada')
chk('aprovado sem quem aprovou' in q("begin; update narrativa_modelos set status='aprovado' where codigo='NAR-D01'; rollback;")[1], 'aprovar exige quem aprovou')
chk('codigo' in q("begin; update narrativa_modelos set codigo='NAR-Z99' where codigo='NAR-D01'; rollback;")[1] or 'não muda' in q("begin; update narrativa_modelos set codigo='NAR-Z99' where codigo='NAR-D01'; rollback;")[1], 'código não muda')
U = v(f"select user_id from workspace_membros where workspace_id='{W}' limit 1")
o, e = q("update narrativa_modelos set modelo='x' where codigo='NAR-D01'", U)
chk('permission denied' in e or 'permissão' in e, 'usuário do sistema só lê: não escreve nos modelos ' + e[:60])
chk(q("select count(*) from narrativa_modelos", U)[0] == '39', 'usuário logado lê os modelos')
with sync_playwright() as pw:
    b = pw.chromium.launch(); erros = []
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
    # ---------- montagem da frase ----------
    r = pg.evaluate("""async () => { await narrCarrega(); return {
      a: narr('NAR-D02', { receita: 'R', abs_resultado: 'A', resultado: 'X', margem: 'M' }, [1]),
      b: narr('NAR-D02', { receita: 'R', abs_resultado: 'A', resultado: 'X' }, [0]),
      c: narr('NAR-D01', { receita: 'R', periodo: 'p', vendas: '1' }),
      d: narr('NAR-H01', { componente: 'a conta <b>X</b>', var: 'V' }, [0]) }; }""")
    chk('faltaram A' in r['a'] and 'data-nar="NAR-D02"' in r['a'] and 'data-nar-v="1"' in r['a'], 'frase montada com a palavra pela direção e o id do modelo')
    chk(r['b'] == '' and r['c'] == '', 'faltou campo ou modelo não aprovado: não sai frase')
    chk('aumentou V' in r['d'], 'palavra escolhida: aumentou')
    # ---------- Financeiro ----------
    SET = "S.per = { pre: 'pers', de: '2026-09-01', ate: '2026-09-30' }"
    front.vai(pg, 'fin-dash', SET, 9000)
    ids = pg.evaluate("() => [...document.querySelectorAll('#main [data-nar]')].map(e => e.dataset.nar)")
    chk(set(ids) >= {'NAR-E07', 'NAR-D02', 'NAR-H01', 'NAR-A02'}, 'Financeiro: frases vindas da tabela ' + str(ids))
    t = pg.inner_text('#finCasc .gc-lead')
    chk(('faltaram ' + MIL(abs(RS))) in t and ('resultado de ' + MIL(RS)) in t and 'sobraram' not in t and '-1' not in t and ('margem de −' + _br(abs(RS / REC) * 100, 1) + '%') in t, 'cascata: "faltaram" com resultado negativo e sinal de menos verdadeiro ' + repr(t[:120]))
    chk(('No período, o resultado foi ' + MIL(RS)) in pg.inner_text('.sem-recado') and ('quando foi ' + MIL(RA)) in pg.inner_text('.sem-recado'), 'frase de topo (NAR-E07) igual à da v0.155')
    pt = pg.evaluate("() => [...document.querySelectorAll('#finPonte svg g[data-passo]')].map(g => ({ p: g.dataset.passo, t: g.querySelector('title').textContent.replace(/\u00a0/g, ' '), f: g.querySelector('rect').getAttribute('fill') }))")
    chk(len(pt) >= 4 and pt[0]['p'] == 'base' and pt[-1]['p'] == 'total' and BRL(RA) in pt[0]['t'] and BRL(RS) in pt[-1]['t'], 'ponte: do resultado de ago/26 ao de set/26 ' + pt[0]['t'] + ' → ' + pt[-1]['t'])
    def val(tt): x = tt.split(': ')[-1].replace('R$', '').replace('.', '').replace(',', '.').replace(' ', ''); return -float(x[1:]) if x[0] in '−-' else float(x)
    soma = val(pt[0]['t']) + sum(val(x['t']) for x in pt[1:-1])
    chk(abs(soma - RS) < 0.02, 'ponte fecha: anterior + degraus = atual (%.2f)' % soma)
    chk(all(x['f'] == 'var(--muted)' for x in pt[1:-1]) and pt[0]['f'] == 'var(--s-desf)' and pt[-1]['f'] == 'var(--s-desf)', 'degraus neutros; as duas pontas na cor do saldo')
    chk(any('Comissões e afiliados' in x['t'] for x in pt) and 'Comissões e afiliados aumentou' in pg.inner_text('#finPonte .gc-lead'), 'hipótese (NAR-H01) aponta a conta que mais pesou, como "possível fator"')
    chk('NAR-I01' not in ids, 'NAR-I01 não repete a mesma conta da hipótese')
    chk(pg.evaluate("() => document.querySelectorAll('#finSmin').length === 1 && !document.querySelector('#main .panel h2') .textContent.includes('Saldo mínimo de caixa')") and 'fica negativo' in pg.inner_text('#finSmin'), 'caixa projetado e saldo mínimo num painel só; sem mínimo, o zero é o limite (NAR-A02)')
    pg.locator('#finPonte').screenshot(path=SHOT + '1_ponte.png'); pg.locator('#finSmin').screenshot(path=SHOT + '2_caixa.png'); pg.screenshot(path=SHOT + '3_financeiro.png', full_page=True)
    erros += pg.errs
    # ---------- modelo fora de aprovado some da tela ----------
    HID = v("select coalesce(max(id),0) from narrativa_modelos_historico")
    v("update narrativa_modelos set status='proposto', aprovado_por=null, aprovado_em=null where codigo='NAR-D02'")
    try:
        ctx.close(); ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000)
        front.vai(pg, 'fin-dash', SET, 9000)
        chk(pg.locator('#finCasc [data-nar]').count() == 0 and pg.locator('#finCasc svg.gc').count() == 1, 'modelo proposto não aparece; o gráfico continua')
    finally:
        v("update narrativa_modelos set status='aprovado', aprovado_por='Rebecka', aprovado_em='2026-10-26 15:58-03' where codigo='NAR-D02'")
        v("delete from narrativa_modelos_historico where id > " + HID)   # o vaivém do teste não fica no histórico
    erros += pg.errs; ctx.close()
    # ---------- saldo mínimo cadastrado (no navegador) ----------
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=1440, vh=1000, prefs={'growths_saldo_min_' + W: '20000'})
    front.vai(pg, 'fin-dash', SET, 9000)
    chk(pg.locator('#finSmin [data-nar="NAR-A01"]').count() == 1 and 'abaixo do saldo mínimo de R$ 20,0 mil' in pg.inner_text('#finSmin'), 'com saldo mínimo: NAR-A01')
    erros += pg.errs
    # ---------- dicionário: as frases do sistema ----------
    front.vai(pg, 'cfg-metricas', '', 5000)
    chk(pg.locator('#narDic tbody tr').count() == 39 and '9 aprovada(s)' in pg.inner_text('#narDic'), 'Dicionário mostra as 39 frases e a situação de cada uma')
    pg.locator('#narDic').screenshot(path=SHOT + '4_dicionario.png'); erros += pg.errs; ctx.close()
    # ---------- celular ----------
    ctx, pg = front.abre(b, hoje='2026-10-15', vw=390, vh=844)
    front.vai(pg, 'fin-dash', SET, 9000)
    sw = pg.evaluate("document.documentElement.scrollWidth"); chk(sw <= 396, 'celular: nada novo passa da tela ' + str(sw))
    pg.screenshot(path=SHOT + '5_celular.png', full_page=True); erros += pg.errs; ctx.close()
    chk(not erros, 'sem erro de JavaScript ' + str(erros[:2]))
    b.close()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
