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
ARQS = {}  # v0.223: Storage de mentira (envio, download e link assinado); o envio também entra em storage.objects do banco local
def _storage(route, path):
    import subprocess, urllib.parse
    h = {'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'content-type': 'application/json'}
    if route.request.method == 'OPTIONS': return route.fulfill(status=200, headers=h, body='')
    rest = urllib.parse.unquote(path.split('?')[0][len('/storage/v1/object/'):])
    if rest.startswith('sign/'):
        return route.fulfill(status=200, headers=h, body=json.dumps({'signedURL': '/object/sign/' + rest[5:] + '?token=x'}))
    for pre in ('authenticated/', 'public/'):
        if rest.startswith(pre): rest = rest[len(pre):]
    b, nome = rest.split('/', 1)
    if route.request.method in ('POST', 'PUT'):
        corpo = route.request.post_data_buffer or b''; ct = route.request.headers.get('content-type', '')
        if 'multipart/form-data' in ct:  # storage-js manda o arquivo dentro de um FormData
            bd = ('--' + ct.split('boundary=')[1].split(';')[0].strip('"')).encode()
            for parte in corpo.split(bd):
                cab, _, dado = parte.partition(b'\r\n\r\n')
                if b'name=""' in cab or b'filename=' in cab: corpo = dado[:-2] if dado.endswith(b'\r\n') else dado; break
        ARQS[rest] = corpo
        subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-qc', "insert into storage.objects (bucket_id, name) values ('%s', '%s')" % (b.replace("'", ''), nome.replace("'", ''))], capture_output=True)
        return route.fulfill(status=200, headers=h, body=json.dumps({'Key': rest, 'Id': rest}))
    if rest in ARQS: return route.fulfill(status=200, headers={**h, 'content-type': 'application/octet-stream'}, body=ARQS[rest])
    return route.fulfill(status=400, headers=h, body=json.dumps({'statusCode': '404', 'error': 'not_found', 'message': 'Object not found'}))
def rota(route):
    u = route.request.url; path = u.split('audit.local', 1)[1]
    if path.startswith('/rest/v1'):
        r = route.fetch(url='http://127.0.0.1:3300' + path[len('/rest/v1'):])
        route.fulfill(response=r, headers={**r.headers, 'access-control-allow-origin': '*'})
    elif path.startswith('/storage/v1/object'):
        _storage(route, path)
    elif path.startswith('/auth/v1/user'):
        route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body=json.dumps(json.loads(SESS)['user']))
    else:
        route.fulfill(status=200, headers={'access-control-allow-origin': '*', 'content-type': 'application/json'}, body='{}')
def abre(browser, hoje='2026-10-15', vw=1440, vh=900, prefs=None):
    ctx = browser.new_context(viewport={'width': vw, 'height': vh})
    ctx.route('http://audit.local/**', rota)
    XL = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/npmx/node_modules/xlsx/dist/xlsx.full.min.js'
    if __import__('os').path.exists(XL): ctx.route('https://cdnjs.cloudflare.com/ajax/libs/xlsx/**', lambda r: r.fulfill(status=200, headers={'content-type': 'application/javascript'}, body=open(XL, 'rb').read()))
    ctx.add_init_script("try{localStorage.setItem('sb-audit-auth-token', %s);%s}catch(e){}" % (json.dumps(SESS), ''.join("localStorage.setItem(%s,%s);" % (json.dumps(k), json.dumps(v)) for k, v in (prefs or {}).items())))
    # v0.223: o Playwright não enxerga o arquivo dentro de um FormData; no teste, o envio ao Storage vai com o conteúdo puro
    ctx.add_init_script("""(() => { const f0 = window.fetch; window.fetch = async (u, o) => { try { const url = String(u && u.url || u);
      if (o && url.includes('/storage/v1/object/') && (o.body instanceof FormData || o.body instanceof Blob)) {
        let arq = o.body; if (o.body instanceof FormData) for (const [, v] of o.body.entries()) if (v instanceof Blob) arq = v;
        const h = new Headers(o.headers || {}); h.set('content-type', arq.type || 'application/octet-stream');
        o = { ...o, body: await arq.arrayBuffer(), headers: h }; } } catch (e) {} return f0(u, o); }; })();""")
    pg = ctx.new_page(); pg.errs = []
    pg.clock.set_fixed_time(hoje + 'T12:00:00-03:00')
    pg.on('pageerror', lambda e: pg.errs.append(str(e)))
    pg.goto('file://' + html()); pg.wait_for_timeout(2500)
    pg.evaluate("h => { window.hoje = () => h; }", hoje)
    return ctx, pg
def vai(pg, view, extra='', ms=3500):
    pg.evaluate("([v, x]) => { S.view = v; eval(x); render(); }", [view, extra]); pg.wait_for_timeout(ms)
    return pg.inner_text('#main')

def aba(pg, k, ms=400):
    """v0.222: troca a aba da página (padrão de abas na mesma página)."""
    pg.click(f'#main [data-abas] [data-aba-k="{k}"]'); pg.wait_for_timeout(ms)
