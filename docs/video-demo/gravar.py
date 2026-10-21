"""Vídeo de demonstração v2 (para redes sociais): grava cada cena do roteiro na tela real do Growths, ligada a uma cópia
do banco da Escola Aurora (banco "video", PostgREST 3302). Uso: python3 gravar.py [cena ...]"""
import sys, os, json, time, subprocess
V = os.path.dirname(os.path.abspath(__file__)) + '/'
sys.path.insert(0, V); sys.path.insert(0, '/home/claude/growths/tests/auditoria'); sys.path.insert(0, '/tmp/claude-0/-home-claude/6d4aa2ee-cf0f-5c9b-bd48-3047ac34b6ff/scratchpad/demo')
import front_video as F
from infra import OVERLAY
from playwright.sync_api import sync_playwright
OUT = V + 'out/'; os.makedirs(OUT, exist_ok=True)
VW, VH = 1600, 900
HOJE = '2026-10-19'
L = '23db706a-18dd-493e-9654-87311693fef8'      # Lançamento Formação Fluência · Nov/26 (captando)
S5 = '5f2f826e-ad48-4026-a51e-420e5bd4b469'     # Lançamento Inglês Base · Set/26 (finalizado)
CURSO = 'fbac648c-40be-486d-89ef-7e04a2a87740'
PESSOA = '0a8a8311-ca8e-41e9-be39-fac06d376a6f'  # Bruno Costa: 6 pontos de contato e 2 compras
CHAP = """#dmChap{position:fixed;right:24px;bottom:24px;z-index:99990;pointer-events:none;background:rgba(5,10,24,.88);color:#eef3ff;border:1px solid rgba(96,165,250,.45);border-left:5px solid #38bdf8;
 border-radius:12px;padding:10px 18px;font:700 22px/1.2 Inter,system-ui,sans-serif;opacity:0;transform:translateY(8px);transition:opacity .45s,transform .45s}
 #dmChap.on{opacity:1;transform:none} #dmChap small{display:block;font:500 15px/1.3 Inter,system-ui,sans-serif;color:#a9bbdc;margin-top:3px}"""

class Cena:
    def __init__(self, b, nome):
        self.nome = nome
        self.ctx = b.new_context(viewport={'width': VW, 'height': VH}, record_video_dir=OUT + 'raw_' + nome, record_video_size={'width': VW, 'height': VH})
        self.ctx.route('http://audit.local/**', F.rota)
        self.ctx.add_init_script("try{localStorage.clear();localStorage.setItem('sb-audit-auth-token', %s)}catch(e){}" % json.dumps(F.SESS))
        self.ctx.add_init_script(OVERLAY)
        self.ctx.add_init_script("(() => { const add = () => { if (document.getElementById('dmChap')) return; const s = document.createElement('style'); s.textContent = %s; document.head.appendChild(s); const d = document.createElement('div'); d.id = 'dmChap'; document.body.appendChild(d); }; if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', add); else add(); })();" % json.dumps(CHAP))
        self.t0 = time.time(); self.ini = 0
        self.pg = self.ctx.new_page(); self.errs = []
        self.pg.clock.set_fixed_time(HOJE + 'T12:00:00-03:00')
        self.pg.on('pageerror', lambda e: self.errs.append(str(e)))
        self.pg.goto('file://' + F.html()); self.pg.wait_for_timeout(2500)
        self.pg.evaluate("h => { window.hoje = () => h; }", HOJE)
        self.pg.mouse.move(VW // 2, VH // 2)
    def tela(self, view, extra='', ms=3500):
        self.pg.evaluate("([v, x]) => { S.view = v; eval(x); render(); }", [view, extra]); self.pg.wait_for_timeout(ms)
    def inicio(self): self.pg.wait_for_timeout(300); self.ini = time.time() - self.t0
    def cap(self, t, s=None, ms=3200):
        self.pg.evaluate("([t, s]) => { const e = document.getElementById('dmChap'); e.innerHTML = t + (s ? '<small>' + s + '</small>' : ''); e.classList.add('on'); }", [t, s]); self.pg.wait_for_timeout(ms)
    def sem(self, ms=400): self.pg.evaluate("() => document.getElementById('dmChap').classList.remove('on')"); self.pg.wait_for_timeout(ms)
    def espera(self, ms): self.pg.wait_for_timeout(ms)
    def vai(self, x, y, passos=26): self.pg.mouse.move(x, y, steps=passos)
    def box(self, sel, nth=0):
        loc = self.pg.locator(sel).nth(nth); loc.scroll_into_view_if_needed(); self.pg.wait_for_timeout(250); return loc.bounding_box()
    def aponta(self, sel, nth=0, ms=700):
        b = self.box(sel, nth); self.vai(b['x'] + b['width'] / 2, b['y'] + min(b['height'] / 2, 30)); self.pg.wait_for_timeout(ms); return b
    def clica(self, sel, nth=0, ms=1500):
        self.aponta(sel, nth, 250); self.pg.mouse.down(); self.pg.wait_for_timeout(90); self.pg.mouse.up(); self.pg.wait_for_timeout(ms)
    def destaca(self, sel, on=True, nth=0):
        self.pg.evaluate("([s, on, n]) => { const e = document.querySelectorAll(s)[n]; if (e) e.classList.toggle('dmHi', on); }", [sel, on, nth])
    def digita(self, sel, valor, ms=600):
        self.clica(sel, ms=200); self.pg.evaluate("s => { const i = document.querySelector(s); i.focus(); i.select && i.select(); }", sel)
        self.pg.keyboard.type(str(valor), delay=70); self.pg.wait_for_timeout(ms)
    def escolhe(self, sel, valor, ms=700):
        self.aponta(sel, ms=250); self.pg.select_option(sel, valor); self.pg.wait_for_timeout(ms)
    def rola(self, dy, passos=14, ms=45):
        for _ in range(passos): self.pg.mouse.wheel(0, dy / passos); self.pg.wait_for_timeout(ms)
        self.pg.wait_for_timeout(400)
    def topo(self): self.pg.evaluate("window.scrollTo({top:0,behavior:'smooth'})"); self.pg.wait_for_timeout(700)
    def menu(self, grupo, view, ms=3500):
        if not self.pg.locator(f'#nav button[data-v={view}]').is_visible(): self.clica(f'#nav button[data-g="{grupo}"]', ms=500)
        self.clica(f'#nav button[data-v={view}]', ms=ms)
    def kpi(self, rotulo, ms=1500):
        i = self.pg.evaluate("r => [...document.querySelectorAll('.kpi.arvk')].findIndex(k => (k.querySelector('.l').innerText || '').replace(/[\\sⓘ⚠›]+$/u, '').trim() === r)", rotulo)
        if i < 0: raise Exception('card não achado: ' + rotulo)
        self.clica('.kpi.arvk', i, ms=ms)
    def fim(self):
        v = self.pg.video; self.ctx.close(); src = v.path()
        dst = OUT + 'cena_' + self.nome + '.mp4'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', '%.2f' % self.ini, '-i', src, '-vf', 'fps=30,scale=1920:1080:flags=lanczos,format=yuv420p',
                        '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-an', dst], check=True)
        if self.errs: print('ERROS JS em', self.nome, self.errs[:3])
        return dst

def cartao(b, nome, titulo, sub, rodape, ms):
    p = OUT + 'cartao_' + nome + '.html'
    open(p, 'w', encoding='utf-8').write(f"""<!doctype html><html><head><meta charset="utf-8"><style>body{{margin:0;height:100vh;display:grid;place-items:center;background:radial-gradient(1200px 700px at 30% 20%,#13306b,#050a18 70%);color:#eef3ff;font-family:Inter,system-ui,sans-serif;text-align:center}}</style></head><body><div>
<div style="font:800 110px/1 Inter,system-ui,sans-serif;letter-spacing:-.02em;background:linear-gradient(120deg,#93c5fd,#22d3ee);-webkit-background-clip:text;color:transparent">{titulo}</div>
<div style="font:500 36px/1.35 Inter,system-ui,sans-serif;margin-top:24px;color:#dbe6ff">{sub}</div>
<div style="font:400 22px Inter,system-ui,sans-serif;margin-top:42px;color:#8aa0c8">{rodape}</div></div></body></html>""")
    ctx = b.new_context(viewport={'width': VW, 'height': VH}, record_video_dir=OUT + 'raw_' + nome, record_video_size={'width': VW, 'height': VH})
    pg = ctx.new_page(); t0 = time.time(); pg.goto('file://' + p); pg.wait_for_timeout(600); ini = time.time() - t0; pg.wait_for_timeout(ms)
    v = pg.video; ctx.close(); dst = OUT + 'cena_' + nome + '.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', '%.2f' % ini, '-i', v.path(), '-vf', 'fps=30,scale=1920:1080:flags=lanczos,format=yuv420p', '-c:v', 'libx264', '-crf', '19', '-an', dst], check=True)
    return dst

# ------------------------------------------------------------------ cenas
def c00(b): return cartao(b, '00', 'Growths', 'Os números do seu crescimento, à vista', 'Mathisa · demonstração com dados fictícios (Escola Aurora)', 21000)
def c08(b): return cartao(b, '08', 'Growths', 'Dados à vista. De onde vem cada número. O que fazer com ele.', 'Mathisa · Growth Tech Partner', 14000)

def c01(b):
    c = Cena(b, '01'); c.tela('adm-painel', "S.pg = { per: '30d' }", 4500); c.inicio()
    c.cap('O negócio numa tela só', 'funil · vendas · caixa · lucro', 2500)
    for i in range(4): c.aponta('.kpi', i, 900)
    c.rola(330); c.espera(2500)
    c.rola(380); c.espera(1500)
    c.aponta('xpath=//table//tr[td]', 0, 1800); c.aponta('xpath=//table//tr[td]', 1, 1800)
    c.rola(500); c.espera(3500); c.sem(); return c.fim()

def c02(b):
    subprocess.run(['psql', '-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'video', '-qc', "delete from campanhas where nome like 'Black Friday%'"], check=True)
    c = Cena(b, '02'); c.tela('mkt-camp', "S.tabMkt = 'campanhas'; S.campSel = null", 4000); c.inicio()
    c.cap('Criando uma campanha', 'nome · modelo · estratégia · produto · metas', 2000)
    c.clica('#novaCamp', ms=1800)
    c.digita('#modalRoot [name=nome]', 'Black Friday · Curso Inglês Base')
    c.escolhe('#modalRoot [name=modelo]', 'lancamento')
    f = c.pg.locator('#modalRoot [name=funil_id] option').nth(1).get_attribute('value')
    if f: c.escolhe('#modalRoot [name=funil_id]', f)
    c.escolhe('#modalRoot [name=produto_id]', CURSO)
    for k, v in [('data_inicio', '2026-11-01'), ('data_fim', '2026-11-30')]:
        c.aponta(f'#modalRoot [name={k}]', ms=200); c.pg.fill(f'#modalRoot [name={k}]', v); c.espera(500)
    c.pg.locator('#modalRoot [name=orcamento_total]').scroll_into_view_if_needed()
    for k, v in [('orcamento_total', '25000'), ('meta_cpl', '6'), ('meta_cac', '250'), ('meta_leads', '4000'), ('meta_vendas', '120')]:
        c.digita(f'#modalRoot [name={k}]', v, ms=350)
    c.espera(1200)
    c.clica('#modalRoot button[type=submit]', ms=3500)
    # campanha que já está rodando: planejado × realizado
    c.tela('mkt-camp', "S.campSel = '%s'; S.campTab = 'resumo'" % L, 4500)
    c.cap('Planejado × realizado', 'o sistema avisa o que está abaixo da meta', 2500)
    c.aponta('xpath=//*[contains(text(),"Meta e realizado")]', ms=1500)
    c.rola(250); c.espera(5000); c.sem(); return c.fim()

def c03(b):
    c = Cena(b, '03'); c.tela('mkt-camp', "S.campSel = '%s'; S.campTab = 'links'" % L, 4500); c.inicio()
    c.cap('Rastreamento', 'cada anúncio com o seu link e UTM', 2500)
    c.aponta('xpath=//table//tr[td]', 0, 1500); c.aponta('xpath=//table//tr[td]', 2, 1800)
    c.clica('.tabs button[data-t=captacao]', ms=4000)
    c.cap('Os leads entram sozinhos', 'por canal, com meta de leads por dia', 2500)
    c.rola(400); c.espera(3500)
    c.tela('mkt-origem', "S.o = { dim: 'utm_content', camp: '', de: '', ate: '' }", 4000)
    c.cap('Leads por origem', 'qual anúncio trouxe, qualificou e vendeu', 3000)
    c.aponta('xpath=//table//tr[td]', 0, 1500); c.aponta('xpath=//table//tr[td]', 1, 1500)
    c.pg.evaluate("id => fichaPessoa(id)", PESSOA); c.espera(3500)
    c.cap('A jornada de cada pessoa', 'pontos de contato e compras', 2500)
    c.pg.mouse.move(VW / 2, VH / 2, steps=10)
    for _ in range(3): c.pg.mouse.wheel(0, 260); c.espera(1600)
    c.sem(); return c.fim()

def c04(b):
    c = Cena(b, '04'); c.tela('mkt-trafego', "S.tDe = '2026-09-20'; S.tAte = '2026-10-19'; S.tCamp = ''; S.tCanal = ''; S.tDia = ''", 5000); c.inicio()
    c.cap('Mídia paga', 'investimento · CPL · CTR · CAC · ROAS', 2500)
    for i in range(5): c.aponta('.kpi', i, 700)
    c.rola(520); c.espera(2500)
    c.rola(600); c.espera(3000)
    c.tela('cfg-integracoes', '', 3500)
    c.cap('Conexão direta com Meta e Google', 'anúncios, Instagram e YouTube', 2500)
    c.aponta('[data-cxcon="meta"]', ms=1800); c.aponta('[data-cxcon="google"]', ms=2200)
    c.sem(); return c.fim()

def c05(b):
    c = Cena(b, '05'); c.tela('mkt-dash', "S.mg = { ini: '2026-09-01', fim: '2026-10-19', camp: '', funil: '', tab: 'visao', gran: 'campanha', cv: 'ret', sel: null }", 5500); c.inicio()
    c.cap('De onde vem cada número', 'clique no número e desça até a origem', 2500)
    c.kpi('CAC', ms=2800)
    c.clica('#arvRoot .arv-f button.arv-l', 0, ms=2800)
    c.clica('#arvRoot .arv-q button.arv-l', 0, ms=3000)
    c.pg.evaluate("() => arvFecha()"); c.espera(600)
    c.tela('adm-painel', "S.pg = { per: '30d' }", 4500)
    c.kpi('Lucro', ms=2500)
    c.clica('#arvRoot [data-arvrot="− Despesas"]', ms=2500)
    c.clica('#arvRoot .arv-q button.arv-l', 0, ms=2500)
    if c.pg.locator('#arvRoot tr[data-arvir]').count(): c.clica('#arvRoot tr[data-arvir]', 0, ms=3200)
    c.pg.evaluate("() => arvFecha()"); c.sem(); return c.fim()

def c06(b):
    c = Cena(b, '06'); c.tela('fin-dash', "S.per = { pre: 'ant' }", 4500); c.inicio()
    c.cap('Finanças', 'caixa · a receber · a pagar · próximos 30 dias', 2500)
    for i in range(4): c.aponta('.kpi', i, 800)
    c.rola(450); c.espera(3000)
    c.tela('fin-custo', "S.co = { mes: '2026-09', ver: 'area' }", 5000)
    c.cap('Custos e margens', 'lucro de verdade, meta e ponto de equilíbrio', 2500)
    c.rola(480); c.espera(3500); c.rola(700); c.espera(2500)
    c.tela('crm-comissoes', "S.com = { aba: 'resumo', mes: '2026-09', pessoa: '', sit: '' }", 4000)
    c.cap('Comissões', 'vendedor · coprodutor · estrategista', 2500)
    c.aponta('tr[data-compes]', 0, 1300); c.aponta('tr[data-compes]', 1, 1300); c.aponta('tr[data-compes]', 2, 1300)
    c.aponta('#comFechar', ms=2500)
    c.sem(); return c.fim()

def c07(b):
    c = Cena(b, '07'); c.tela('gro-modelo', '', 6000); c.inicio()
    c.cap('Growth Model', 'o real fica travado, o cenário é onde você mexe', 2500)
    c.aponta('#gsTopo', ms=1500)
    c.clica('#gsNovo', ms=900)
    c.pg.fill('#modalRoot [name=nome]', ''); c.clica('#modalRoot [name=nome]', ms=150); c.pg.keyboard.type('Curso a R$ 1.497', delay=55)
    c.clica('#modalRoot button[type=submit]', ms=2500)
    sel = '.gp-in[data-gp=preco][data-p="%s"]' % CURSO
    c.pg.wait_for_selector(sel, timeout=10000)
    if c.pg.locator(sel).count():
        c.digita(sel, '1497', ms=300)
        c.pg.evaluate("s => { const i = document.querySelector(s); i.dispatchEvent(new Event('change', { bubbles: true })); }", sel); c.espera(2500)
    c.aponta('#gsTopo', ms=3500)
    c.tela('gro-cenarios', '', 3500); c.espera(2500)
    c.tela('gro-ciclo', '', 4000)
    c.cap('Ciclo de Growth', 'priorizado por impacto, confiança e facilidade', 2500)
    c.pg.evaluate("() => { const b = document.querySelector('.board'); if (b) b.scrollTo({ left: b.scrollWidth, behavior: 'smooth' }); }"); c.espera(3500)
    c.tela('gro-result', '', 4000)
    c.cap('Resultados e aprendizados', 'projetado × realizado e a decisão', 2500)
    c.rola(300); c.espera(3500)
    c.sem(); return c.fim()

CENAS = {'00': c00, '01': c01, '02': c02, '03': c03, '04': c04, '05': c05, '06': c06, '07': c07, '08': c08}
if __name__ == '__main__':
    quais = sys.argv[1:] or list(CENAS)
    with sync_playwright() as p:
        b = p.chromium.launch()
        for q in quais:
            t = time.time(); r = CENAS[q](b)
            d = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', r], capture_output=True, text=True).stdout.strip()
            print('ok', q, r, 'duração %.1fs' % float(d))
        b.close()
