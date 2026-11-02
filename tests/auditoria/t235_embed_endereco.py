"""v0.235: o formulário embutido usa o endereço /formulario, o único que o site deixa abrir dentro de outra página.
Confere: _headers tira o X-Frame-Options só de /formulario e libera frame-ancestors; _redirects serve o Growths em /formulario;
o código de embed aponta para /formulario?pesquisa=…; /formulario sem pesquisa volta para o Growths normal. Servido por http local."""
import sys, os, subprocess, time, re
from playwright.sync_api import sync_playwright
WWW = '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/www'
R = '/home/claude/growthv2/'
falhas = []
def chk(c, msg, extra=''):
    print(('ok   ' if c else 'FALHA ') + msg + ((' → ' + str(extra)[:300]) if not c and extra != '' else ''))
    if not c: falhas.append(msg)
h = open(R + '_headers').read(); bloco = h[h.index('\n/formulario'):]
chk('X-Frame-Options: DENY' in h.split('\n/formulario')[0] and '! X-Frame-Options' in bloco and 'frame-ancestors *' in bloco, '_headers: o resto continua bloqueado; só /formulario pode ser embutido')
chk(re.search(r'^/formulario\s+/index\.html\s+200', open(R + '_redirects').read(), re.M) is not None, '_redirects: /formulario abre o mesmo Growths')
# servidor local que imita o _redirects (/formulario → index.html)
SRV = '''import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        p = self.path.split('?')[0]
        if p in ('/', '/formulario', '/index.html'): self.path = '/index.html'
        return super().do_GET()
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(('127.0.0.1', 8765), H).serve_forever()
'''
srv = subprocess.Popen(['python3', '-c', SRV], cwd=WWW, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); time.sleep(1.2)
try:
    with sync_playwright() as pw:
        b = pw.chromium.launch(); pg = b.new_page()
        pg.route('**/*supabase*/**', lambda r: r.abort()); pg.route('https://**', lambda r: r.abort() if 'cdnjs' not in r.request.url and 'jsdelivr' not in r.request.url else r.continue_())
        pg.goto('http://127.0.0.1:8765/'); pg.wait_for_timeout(1500)
        cod = pg.evaluate("() => cpqCodigo(linkPesquisa('abc123') + '&utm_source=site', 'x')")
        chk('src="http://127.0.0.1:8765/formulario?pesquisa=abc123&utm_source=site"' in cod, 'o código de embed aponta para /formulario?pesquisa=…', cod[:200])
        chk(pg.evaluate("() => linkPesquisa('abc123')") == 'http://127.0.0.1:8765/?pesquisa=abc123', 'o link normal (para enviar) continua igual')
        pg.goto('http://127.0.0.1:8765/formulario'); pg.wait_for_timeout(1500)
        chk(pg.url.rstrip('/') == 'http://127.0.0.1:8765', '/formulario sem pesquisa volta para o Growths normal', pg.url)
        pg.goto('http://127.0.0.1:8765/formulario?pesquisa=abc123'); pg.wait_for_timeout(1500)
        chk('/formulario?pesquisa=abc123' in pg.url, '/formulario com pesquisa fica no formulário', pg.url)
        b.close()
finally:
    srv.terminate()
print('\n%d falha(s)' % len(falhas)); sys.exit(1 if falhas else 0)
