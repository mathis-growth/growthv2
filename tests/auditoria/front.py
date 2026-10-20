"""Abre o front real do Growths ligado ao banco local completo (PostgREST), logado como o usuário da auditoria."""
import json, time, urllib.request
from jwt import token
SPD = __import__('os').path.dirname(__import__('os').path.abspath(__file__)) + '/'
UID = '00000000-0000-0000-0000-00000000a0a0'
TK = token(); ANON = token(UID, 'anon')
def html():
    s = open('/home/claude/growths/frontend/index.html', encoding='utf-8').read()
    s = s.replace("const SB_URL = 'https://yngyghlyonybvfvjcmxl.supabase.co';", "const SB_URL = 'http://audit.local';")
    i = s.index("const SB_KEY = '"); j = s.index("'", i + 16)
    s = s[:i] + "const SB_KEY = '" + ANON + s[j:]
    p = SPD + 'audit.html'; open(p, 'w', encoding='utf-8').write(s); return p
SESS = json.dumps({'access_token': TK, 'refresh_token': 'x', 'token_type': 'bearer', 'expires_in': 999999999, 'expires_at': 4102444800,
                   'user': {'id': UID, 'email': 'auditoria@escolaaurora.com.br', 'aud': 'authenticated', 'role': 'authenticated', 'app_metadata': {}, 'user_metadata': {}}})
def rota(route):
    u = route.request.url; path = u.split('audit.local', 1)[1]
    if path.startswith('/rest/v1'):
        r = route.fetch(url='http://127.0.0.1:3300' + path[len('/rest/v1'):])
        route.fulfill(response=r, headers={**r.headers, 'access-control-allow-origin': '*'})
    elif path.startswith('/auth/v1/user'):
        route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body=json.dumps(json.loads(SESS)['user']))
    else:
        route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body='{}')
def abre(browser, hoje='2026-10-15', vw=1440, vh=900, prefs=None):
    ctx = browser.new_context(viewport={'width': vw, 'height': vh})
    ctx.route('http://audit.local/**', rota)
    ctx.add_init_script("try{localStorage.setItem('sb-audit-auth-token', %s);%s}catch(e){}" % (json.dumps(SESS), ''.join("localStorage.setItem(%s,%s);" % (json.dumps(k), json.dumps(v)) for k, v in (prefs or {}).items())))
    pg = ctx.new_page(); pg.errs = []
    pg.clock.set_fixed_time(hoje + 'T12:00:00-03:00')
    pg.on('pageerror', lambda e: pg.errs.append(str(e)))
    pg.goto('file://' + html()); pg.wait_for_timeout(2500)
    pg.evaluate("h => { window.hoje = () => h; }", hoje)
    return ctx, pg
def vai(pg, view, extra='', ms=3500):
    pg.evaluate("([v, x]) => { S.view = v; eval(x); render(); }", [view, extra]); pg.wait_for_timeout(ms)
    return pg.inner_text('#main')
