import json, os, tempfile
# Teste da v0.252: nos três cenários o custo por lead é calculado.
# Caso do erro: a pessoa preenche primeiro a coluna Pessimista (a primeira da tabela) e depois o Base.
# Rodar: python3 tests/tela/t252_cenarios_cpl.py
from playwright.sync_api import sync_playwright
SP = os.path.dirname(os.path.abspath(__file__)) + '/'
HTML = os.path.join(tempfile.gettempdir(), 't252_growths.html')
s = open(SP + '../../index.html', encoding='utf-8').read()
i = s.index('<script>/* @supabase'); j = s.index('</script>', i) + 9
SEED = {'workspaces': [{'id': 'w1', 'nome': 'Escola Aurora', 'modo_produto': 'completo', 'agencia': True}]}
MOCK = open(SP + 'mockdb.js', encoding='utf-8').read()
open(HTML, 'w', encoding='utf-8').write(s[:i] + '<script>window.__SEED=' + json.dumps(SEED) + ';</script><script>' + MOCK + '</script>' + s[j:])
ok = True
def chk(c, msg, extra=''):
    global ok
    print(('OK   ' if c else 'FALHA') + ' ' + msg + ((' → ' + str(extra)[:400]) if (extra != '' and not c) else '')); ok = ok and bool(c)
# Repete o que a tela faz ao digitar: resolve o cenário, marca como mexido e atualiza os que seguem o Base.
JS = """() => {
  const digita = (C, t, m, v) => { C[t] = cenSolve({ ...C[t], [m]: v }, m);
    CEN_TIPOS.filter(x => x[0] !== 'base').forEach(([k, , fp, fc]) => { if (t === k) C.mexido[k] = true; });
    if (t === 'base') CEN_TIPOS.filter(x => x[0] !== 'base').forEach(([k, , fp, fc]) => { C[k] = C.mexido[k] ? cenCompleta(C[k], C.base, fp, fc) : cenDeriva(C.base, fp, fc); }); };
  const vazio = () => ({ I: null, p: null, L: null, c: null, V: null, a: null, t: null });
  const R = {};
  // 1) Pessimista primeiro, depois o Base
  let C = { base: vazio(), pessimista: vazio(), otimista: vazio(), mexido: {} };
  digita(C, 'pessimista', 'I', 10000); digita(C, 'base', 'I', 10000); digita(C, 'base', 'p', 10); digita(C, 'base', 'c', 2);
  R.primeiro = { pes: C.pessimista, oti: C.otimista };
  // 2) o investimento digitado no Pessimista continua o que foi digitado
  C = { base: vazio(), pessimista: vazio(), otimista: vazio(), mexido: {} };
  digita(C, 'pessimista', 'I', 5000); digita(C, 'base', 'I', 10000); digita(C, 'base', 'p', 10); digita(C, 'base', 'c', 2);
  R.mantem = C.pessimista;
  // 3) poucas vendas: a conta não pode zerar e perder o CPL
  R.pouco = cenDeriva({ I: 1000, p: null, c: 1, a: 1000, t: 100 }, 1.2, .8);
  // 4) só derivado do Base
  R.deriva = cenDeriva({ I: 10000, p: 10, c: 2, a: 500, t: 100 }, 1.2, .8);
  // 5) um CPL digitado à mão não muda
  C = { base: vazio(), pessimista: vazio(), otimista: vazio(), mexido: {} };
  digita(C, 'base', 'I', 10000); digita(C, 'base', 'p', 10); digita(C, 'base', 'c', 2);
  digita(C, 'pessimista', 'p', 20); R.mao = C.pessimista;
  return R; }"""
with sync_playwright() as p:
    try: b = p.chromium.launch()
    except Exception: b = p.chromium.launch(channel='chrome')
    pg = b.new_page(); errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('file:///' + HTML.replace(chr(92), '/')); pg.wait_for_timeout(800)
    R = pg.evaluate(JS)
    a = R['primeiro']
    chk(a['pes']['p'] and abs(a['pes']['p'] - 12) < 1e-9, 'Pessimista preenchido primeiro: CPL = Base × 1,2', a['pes'])
    chk(a['pes']['L'] == 833, 'Pessimista: leads = investimento ÷ CPL', a['pes'])
    chk(abs(a['oti']['p'] - 8) < 1e-9, 'Otimista: CPL = Base × 0,8', a['oti'])
    chk(R['mantem']['I'] == 5000 and abs(R['mantem']['p'] - 12) < 1e-9 and R['mantem']['L'] == 417, 'investimento digitado continua, e o resto se completa', R['mantem'])
    chk(R['pouco']['p'] and abs(R['pouco']['p'] - 12) < .1, 'com poucas vendas, o CPL aparece mesmo assim', R['pouco'])
    chk(abs(R['deriva']['p'] - 12) < 1e-9 and R['deriva']['L'] == 833, 'Pessimista derivado do Base', R['deriva'])
    chk(R['mao']['p'] == 20 and R['mao']['L'] == 500, 'CPL digitado à mão fica como foi digitado', R['mao'])
    chk(not errs, 'sem erros de página', errs)
    b.close()
print('TUDO OK' if ok else 'HÁ FALHAS')
