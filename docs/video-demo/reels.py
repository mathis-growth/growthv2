"""Versão vertical (Reels 1080x1920) do vídeo de demonstração: viewport 720x1280 com escala 1,5, sem o menu lateral,
título grande no alto. Uso: python3 reels.py [r1 r2 ...]"""
import sys, os, json, time, subprocess
V = os.path.dirname(os.path.abspath(__file__)) + '/'
sys.path.insert(0, V)
import gravar as G
from gravar import F, OVERLAY, L, CURSO, PESSOA
from playwright.sync_api import sync_playwright
OUT = V + 'reels/'; os.makedirs(OUT, exist_ok=True)
W, H = 1080, 1920
CSS = """html{zoom:1.5} aside.side{display:none!important} .app,.layout,body>div{grid-template-columns:1fr!important}
main,#main{padding-top:150px!important}
#dmChap{position:fixed;left:24px;right:24px;top:28px;z-index:99990;pointer-events:none;background:rgba(5,10,24,.92);color:#eef3ff;
 border:1px solid rgba(96,165,250,.45);border-left:6px solid #38bdf8;border-radius:16px;padding:14px 20px;font:800 30px/1.15 Inter,system-ui,sans-serif;
 opacity:0;transform:translateY(-8px);transition:opacity .4s,transform .4s}
#dmChap.on{opacity:1;transform:none} #dmChap small{display:block;font:500 19px/1.3 Inter,system-ui,sans-serif;color:#a9bbdc;margin-top:5px}"""
class Reel(G.Cena):
    def __init__(self, b, nome):
        self.nome = nome
        self.ctx = b.new_context(viewport={'width': W, 'height': H}, record_video_dir=OUT + 'raw_' + nome, record_video_size={'width': 1080, 'height': 1920})
        self.ctx.route('http://audit.local/**', F.rota)
        self.ctx.add_init_script("try{localStorage.clear();localStorage.setItem('sb-audit-auth-token', %s)}catch(e){}" % json.dumps(F.SESS))
        self.ctx.add_init_script(OVERLAY)
        self.ctx.add_init_script("(() => { const add = () => { if (document.getElementById('dmChap')) return; const s = document.createElement('style'); s.textContent = %s; document.head.appendChild(s); const d = document.createElement('div'); d.id = 'dmChap'; document.body.appendChild(d); }; if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', add); else add(); })();" % json.dumps(CSS))
        self.t0 = time.time(); self.ini = 0
        self.pg = self.ctx.new_page(); self.errs = []
        self.pg.clock.set_fixed_time(G.HOJE + 'T12:00:00-03:00')
        self.pg.on('pageerror', lambda e: self.errs.append(str(e)))
        self.pg.goto('file://' + F.html()); self.pg.wait_for_timeout(2500)
        self.pg.evaluate("h => { window.hoje = () => h; }", G.HOJE)
        self.pg.mouse.move(W // 2, H // 2)
    def topo(self): self.pg.evaluate("window.scrollTo(0,0); document.querySelectorAll('main,#main').forEach(m => m.scrollTo && m.scrollTo(0,0))")
    def fim(self):
        v = self.pg.video; self.ctx.close(); src = v.path(); dst = OUT + 'reel_' + self.nome + '.mp4'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', '%.2f' % self.ini, '-i', src, '-vf', 'fps=30,scale=1080:1920:flags=lanczos,format=yuv420p',
                        '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-an', dst], check=True)
        if self.errs: print('ERROS JS em', self.nome, self.errs[:3])
        return dst

def cartao(b, nome, titulo, sub, rodape, ms):
    p = OUT + 'cartao_' + nome + '.html'
    open(p, 'w', encoding='utf-8').write(f"""<!doctype html><html><head><meta charset="utf-8"><style>html{{zoom:1.5}}body{{margin:0;height:calc(100vh / 1.5);display:grid;place-items:center;background:radial-gradient(900px 900px at 30% 20%,#13306b,#050a18 70%);color:#eef3ff;font-family:Inter,system-ui,sans-serif;text-align:center;padding:0 48px;box-sizing:border-box}}</style></head><body><div>
<div style="font:800 104px/1 Inter,system-ui,sans-serif;letter-spacing:-.02em;background:linear-gradient(120deg,#93c5fd,#22d3ee);-webkit-background-clip:text;color:transparent">{titulo}</div>
<div style="font:600 40px/1.3 Inter,system-ui,sans-serif;margin-top:30px;color:#dbe6ff">{sub}</div>
<div style="font:400 22px/1.4 Inter,system-ui,sans-serif;margin-top:46px;color:#8aa0c8">{rodape}</div></div></body></html>""")
    ctx = b.new_context(viewport={'width': W, 'height': H}, record_video_dir=OUT + 'raw_' + nome, record_video_size={'width': 1080, 'height': 1920})
    pg = ctx.new_page(); t0 = time.time(); pg.goto('file://' + p); pg.wait_for_timeout(600); ini = time.time() - t0; pg.wait_for_timeout(ms)
    v = pg.video; ctx.close(); dst = OUT + 'reel_' + nome + '.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', '%.2f' % ini, '-i', v.path(), '-vf', 'fps=30,scale=1080:1920:flags=lanczos,format=yuv420p', '-c:v', 'libx264', '-crf', '19', '-an', dst], check=True)
    return dst

def r0(b): return cartao(b, 'r0', 'Growths', 'Os números do seu negócio, à vista', 'Mathisa · dados fictícios (Escola Aurora)', 4000)
def r9(b): return cartao(b, 'r9', 'Growths', 'Quer enxergar o seu crescimento assim?', 'Fala com a gente · Mathisa', 4500)

def r1(b):
    c = Reel(b, 'r1'); c.tela('adm-painel', "S.pg = { per: '30d' }", 4500); c.inicio()
    c.cap('O negócio numa tela só', 'funil · vendas · caixa · lucro', 1500)
    c.rola(520, ms=40); c.espera(1600); c.rola(560, ms=40); c.espera(1800)
    return c.fim()

def r2(b):
    subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'video', '-qc', "delete from campanhas where nome like 'Black Friday%'"], check=True)
    c = Reel(b, 'r2'); c.tela('mkt-camp', "S.tabMkt = 'campanhas'; S.campSel = null", 4000); c.inicio()
    c.cap('Criando uma campanha', 'modelo · produto · orçamento · metas', 1200)
    c.clica('#novaCamp', ms=1200)
    c.digita('#modalRoot [name=nome]', 'Black Friday · Inglês', ms=300)
    c.escolhe('#modalRoot [name=modelo]', 'lancamento', ms=400)
    c.escolhe('#modalRoot [name=produto_id]', CURSO, ms=400)
    c.pg.locator('#modalRoot [name=orcamento_total]').scroll_into_view_if_needed()
    for k, v in [('orcamento_total', '25000'), ('meta_leads', '4000'), ('meta_vendas', '120')]:
        c.digita(f'#modalRoot [name={k}]', v, ms=250)
    for k, v in [('data_inicio', '2026-11-01'), ('data_fim', '2026-11-30')]: c.pg.fill(f'#modalRoot [name={k}]', v)
    f = c.pg.locator('#modalRoot [name=funil_id] option').nth(1).get_attribute('value')
    if f: c.pg.select_option('#modalRoot [name=funil_id]', f)
    c.clica('#modalRoot button[type=submit]', ms=2500)
    return c.fim()

def r3(b):
    c = Reel(b, 'r3'); c.tela('mkt-origem', "S.o = { dim: 'utm_content', camp: '', de: '', ate: '' }", 4000); c.inicio()
    c.cap('De onde vem cada lead', 'qual anúncio trouxe, qualificou e vendeu', 2800)
    c.pg.evaluate("id => fichaPessoa(id)", PESSOA); c.espera(2000)
    c.cap('A jornada de cada pessoa', 'cada ponto de contato até a compra', 600)
    c.pg.mouse.move(W / 2, H / 2, steps=8)
    for _ in range(2): c.pg.mouse.wheel(0, 380); c.espera(1300)
    return c.fim()

def r4(b):
    c = Reel(b, 'r4'); c.tela('mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-10-19', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 5500); c.inicio()
    c.cap('Anúncios e retorno', 'CPL · CAC · ROAS', 2200)
    c.cap('Nenhum número é caixa-preta', 'clique e veja a conta', 300)
    c.kpi('CAC', ms=2200)
    c.clica('#arvRoot .arv-f button.arv-l', 0, ms=2200)
    c.clica('#arvRoot .arv-q button.arv-l', 0, ms=2400)
    c.pg.evaluate("() => arvFecha()"); return c.fim()

def r5(b):
    c = Reel(b, 'r5'); c.tela('fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 5000); c.inicio()
    c.cap('Lucro de verdade', 'margem, meta e ponto de equilíbrio', 600)
    loc = c.pg.locator('xpath=//*[contains(text(),"Margens e meta")]')
    if loc.count(): loc.first.scroll_into_view_if_needed()
    c.pg.evaluate("() => window.scrollBy(0, -160)"); c.espera(2600)
    c.tela('crm-comissoes', "S.com = { aba: 'resumo', mes: '2026-09', pessoa: '', sit: '' }", 2500)
    c.cap('Comissões automáticas', 'vendedor · coprodutor · estrategista', 600)
    c.rola(420, ms=40); c.espera(2000)
    return c.fim()

def r6(b):
    c = Reel(b, 'r6'); c.tela('gro-modelo', '', 6000); c.inicio()
    c.cap('Growth Model', 'e se eu subir o preço?', 900)
    sel = '.gp-in[data-gp=preco][data-p="%s"]' % CURSO
    c.clica('#gsNovo', ms=700)
    c.pg.fill('#modalRoot [name=nome]', 'Curso a R$ 1.497')
    c.clica('#modalRoot button[type=submit]', ms=1800)
    c.pg.wait_for_selector(sel, timeout=10000)
    if c.pg.locator(sel).count():
        c.digita(sel, '1497', ms=200)
        c.pg.evaluate("s => { const i = document.querySelector(s); i.dispatchEvent(new Event('change', { bubbles: true })); }", sel); c.espera(1600)
    c.cap('Tudo recalcula na hora', 'receita · imposto · margem · lucro', 300)
    c.topo(); c.espera(400); c.aponta('#gsTopo', ms=2600)
    return c.fim()

CENAS = {'r0': r0, 'r1': r1, 'r2': r2, 'r3': r3, 'r4': r4, 'r5': r5, 'r6': r6, 'r9': r9}
if __name__ == '__main__':
    quais = sys.argv[1:] or list(CENAS)
    with sync_playwright() as p:
        b = p.chromium.launch()
        for q in quais:
            r = CENAS[q](b)
            d = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', r], capture_output=True, text=True).stdout.strip()
            print('ok', q, 'duração %.1fs' % float(d))
        b.close()
