"""Gera as imagens dos 31 criativos da Semana da Fluência (Escola Aurora, marca fictícia) e a prévia 16:9 usada no Growths."""
import json, html, os, base64, io
from playwright.sync_api import sync_playwright
from PIL import Image
P = json.load(open('plano.json'))
OUT = 'criativos/'; os.makedirs(OUT, exist_ok=True)
E = html.escape
NIGHT, TEAL, VIOLET, SUN, CREAM, INK, GOLD = '#161A3A', '#3DD9C1', '#8B6CFF', '#FF8A5C', '#FFF4E6', '#12132A', '#FFD45C'
LOGO = lambda cor='#fff': f'''<div class="logo" style="color:{cor}"><svg width="26" height="16" viewBox="0 0 26 16"><path d="M2 15a11 11 0 0 1 22 0" fill="none" stroke="{SUN}" stroke-width="3"/><path d="M13 1v3M4.5 4.5l2 2M21.5 4.5l-2 2" stroke="{TEAL}" stroke-width="2.2" stroke-linecap="round"/></svg>aurora</div>'''
CSS = f'''*{{box-sizing:border-box;margin:0}} body{{background:#0d0f22}} .stage{{width:640px;height:360px;position:relative;overflow:hidden;display:grid;place-items:center;
 background:radial-gradient(420px 260px at 18% 20%,rgba(139,108,255,.35),transparent 70%),radial-gradient(380px 240px at 85% 90%,rgba(255,138,92,.28),transparent 70%),#0f1229}}
 .fmt{{position:absolute;left:12px;top:10px;font:600 11px Inter;color:#c9cdf2;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);border-radius:20px;padding:3px 9px;letter-spacing:.02em}}
 .cr{{position:relative;overflow:hidden;font-family:Inter;box-shadow:0 18px 40px rgba(0,0,0,.45);border-radius:10px}}
 .sq{{width:336px;height:336px}} .vt{{width:189px;height:336px}} .wd{{width:560px;height:315px}} .sr{{width:560px;height:250px}}
 .logo{{position:absolute;display:flex;gap:6px;align-items:center;font:800 15px 'Inter Display';letter-spacing:-.02em}}
 .h{{font-family:'Inter Display';font-weight:900;letter-spacing:-.035em;line-height:.98}}
 .cta{{position:absolute;left:0;right:0;bottom:0;padding:11px 16px;font:700 13px Inter;display:flex;justify-content:space-between;align-items:center}}
 .q{{font-family:Lora;font-style:italic}}
 .cap{{background:#fff;color:#111;font:800 13px Inter;padding:3px 7px;border-radius:5px;display:inline;box-decoration-break:clone;-webkit-box-decoration-break:clone;line-height:1.75}}
'''
def pessoa(c1, c2, w, h, x, y):  # silhueta estilizada (cabeça + ombros), sem rosto
    return f'''<svg style="position:absolute;left:{x}px;top:{y}px" width="{w}" height="{h}" viewBox="0 0 100 120"><defs><linearGradient id="g{c1[1:]}{c2[1:]}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient></defs>
      <circle cx="50" cy="38" r="22" fill="url(#g{c1[1:]}{c2[1:]})"/><path d="M8 120c2-30 20-46 42-46s40 16 42 46z" fill="url(#g{c1[1:]}{c2[1:]})"/></svg>'''
def bolha(txt, x, y, bg='#fff', fg=INK, cauda='l'):
    return f'<div style="position:absolute;left:{x}px;top:{y}px;background:{bg};color:{fg};font:700 13px Inter;padding:8px 12px;border-radius:14px;border-bottom-{"left" if cauda=="l" else "right"}-radius:3px">{txt}</div>'

def criativo(a, camp):
    f, ang, hook, sub = a['formato'], a['angulo'], E(a['hook']), E(a['sub'])
    if f == 'texto':  # anúncio de pesquisa (prévia genérica, sem marca de terceiros)
        return 'sr', 'Pesquisa · texto', f'''<div class="cr sr" style="background:#fff;padding:22px 26px;font-family:Inter">
          <div style="display:flex;gap:10px;align-items:center;margin-bottom:10px"><div style="width:30px;height:30px;border-radius:50%;background:{NIGHT};display:grid;place-items:center">
          <svg width="18" height="11" viewBox="0 0 26 16"><path d="M2 15a11 11 0 0 1 22 0" fill="none" stroke="{SUN}" stroke-width="3"/></svg></div>
          <div><div style="font:600 13px Inter;color:#202124">Escola Aurora</div><div style="font:12px Inter;color:#4d5156">escolaaurora.com.br › semana-da-fluencia</div></div></div>
          <div style="font:700 11px Inter;color:#202124;margin-bottom:4px">Patrocinado</div>
          <div style="font:500 21px Inter;color:#1a0dab;letter-spacing:-.01em">{hook} | Escola Aurora</div>
          <div style="font:14px/1.45 Inter;color:#4d5156;margin-top:6px">{sub}. Destrave a fala com o Método Aurora: aulas ao vivo, prática de conversação e professores nativos.</div>
          <div style="display:flex;gap:18px;margin-top:12px;font:500 13px Inter;color:#1a0dab"><span>Aula 1 · 27/10</span><span>Depoimentos</span><span>Teste de nível</span></div></div>'''
    if f == 'video':  # miniatura de vídeo horizontal
        bg = {'dor': f'linear-gradient(120deg,{NIGHT},#2a1f5e)', 'prova': f'linear-gradient(120deg,#2b2350,{VIOLET})', 'evento': f'linear-gradient(120deg,#0f3d44,{TEAL})'}[ang]
        dur = {'AD24': '0:45', 'AD25': '0:30', 'AD26': '0:06'}[a['cod']]
        return 'wd', 'Vídeo 16:9', f'''<div class="cr wd" style="background:{bg}">{pessoa('#FFB38A', SUN, 230, 276, 330, 50)}
          <div class="h" style="position:absolute;left:30px;top:70px;width:300px;font-size:44px;color:#fff">{hook}</div>
          <div style="position:absolute;left:30px;top:228px;font:600 14px Inter;color:{GOLD}">{sub}</div>
          {LOGO()}<style>.wd .logo{{left:30px;top:24px}}</style>
          <div style="position:absolute;right:12px;bottom:12px;background:rgba(0,0,0,.75);color:#fff;font:600 12px Inter;padding:2px 6px;border-radius:4px">{dur}</div>
          <div style="position:absolute;left:12px;bottom:12px;background:{GOLD};color:{INK};font:800 11px Inter;padding:3px 7px;border-radius:4px">Anúncio</div>
          <div style="position:absolute;left:410px;top:150px;width:58px;height:58px;border-radius:50%;background:rgba(255,255,255,.92);display:grid;place-items:center"><svg width="20" height="22" viewBox="0 0 20 22"><path d="M2 1l17 10L2 21z" fill="{INK}"/></svg></div></div>'''
    if f in ('reels', 'stories', 'vertical'):
        top = f'<div style="position:absolute;left:8px;right:8px;top:8px;display:flex;gap:3px">' + ''.join(f'<i style="flex:1;height:2.5px;border-radius:2px;background:rgba(255,255,255,{.95 if i == 0 else .35})"></i>' for i in range(4 if f == 'stories' else 1)) + '</div>'
        bg = {'dor': f'linear-gradient(170deg,{NIGHT} 30%,#3a2363)', 'prova': f'linear-gradient(170deg,#3b2a6b,{VIOLET} 60%,{SUN})', 'desejo': f'linear-gradient(170deg,#ff9f6e,{SUN} 40%,#c4467a)',
              'evento': f'linear-gradient(170deg,#0e3b45,{TEAL})', 'autoridade': f'linear-gradient(170deg,#211a4a,{VIOLET})', 'curiosidade': f'linear-gradient(170deg,{INK},#2c2f5e)'}[ang]
        icones = '' if f != 'vertical' else '<div style="position:absolute;right:8px;bottom:70px;display:flex;flex-direction:column;gap:12px">' + ''.join(f'<div style="width:26px;height:26px;border-radius:50%;background:rgba(255,255,255,.22);display:grid;place-items:center;font:700 9px Inter;color:#fff">{t}</div>' for t in ('♥', '…', '↗')) + '</div>'
        cta = {'evento': 'Garanta sua vaga', 'prova': 'Quero destravar', 'dor': 'Aula gratuita', 'desejo': 'Quero participar', 'autoridade': 'Ver a aula', 'curiosidade': 'Fazer o teste'}[ang]
        return 'vt', {'reels': 'Reels 9:16', 'stories': 'Stories 9:16', 'vertical': 'Vídeo vertical 9:16'}[f], f'''<div class="cr vt" style="background:{bg}">{top}
          {pessoa('#FFC7A3', '#FF8A5C' if ang != 'prova' else '#FFD9B8', 120, 144, 35, 118)}
          <div style="position:absolute;left:12px;right:12px;top:58px;text-align:center"><span class="cap">{hook}</span></div>
          <div style="position:absolute;left:0;right:0;bottom:0;height:120px;background:linear-gradient(transparent,rgba(10,10,30,.75))"></div><div style="position:absolute;left:12px;right:34px;bottom:56px;color:#fff;font:600 10.5px/1.35 Inter">@escolaaurora · {sub}</div>{icones}
          <div style="position:absolute;left:12px;right:12px;bottom:14px;background:#fff;color:{INK};font:800 12px Inter;text-align:center;padding:8px;border-radius:8px">{cta}</div></div>'''
    # quadrados: estático e carrossel
    if ang == 'prova':
        return 'sq', 'Carrossel 1:1' if f == 'carrossel' else 'Estático 1:1', f'''<div class="cr sq" style="background:{CREAM};color:{INK};padding:26px">
          <div style="font:800 34px Lora;color:{SUN};line-height:.6">“</div><div class="q" style="font-size:22px;line-height:1.25;margin-top:8px">{hook.strip('“”')}</div>{'<div style="font:500 13px/1.45 Inter;color:#4a4a68;margin-top:10px">Carla, Rafael, Júlia e Marcos: da trava à conversa em menos de 1 ano.</div>' if f == 'carrossel' else ''}
          <div style="display:flex;gap:10px;align-items:center;margin-top:20px"><div style="width:40px;height:40px;border-radius:50%;background:linear-gradient(135deg,{VIOLET},{SUN});color:#fff;display:grid;place-items:center;font:800 15px Inter">CR</div>
          <div><div style="font:700 13px Inter">{sub}</div><div style="color:#f5a623;font-size:13px;letter-spacing:2px">★★★★★</div></div></div>
          <div class="cta" style="background:{NIGHT};color:#fff"><span>Semana da Fluência</span><span style="color:{GOLD}">27 a 31/10 →</span></div>{dots(f)}</div>'''
    if ang in ('autoridade', 'curiosidade') and f == 'carrossel':
        return 'sq', 'Carrossel 1:1', f'''<div class="cr sq" style="background:{VIOLET if ang == 'autoridade' else INK};color:#fff;padding:24px">{LOGO()}<style>.sq .logo{{left:24px;top:20px}}</style>
          <div class="h" style="font-size:96px;margin-top:44px;color:{GOLD}">{next((ch for ch in hook if ch.isdigit()), '?')}</div>
          <div class="h" style="font-size:27px;margin-top:6px;width:270px">{hook}</div>
          <div style="position:absolute;left:24px;bottom:22px;font:600 13px Inter;opacity:.85">{sub} →</div>{dots(f)}</div>'''
    tema = {'dor': (NIGHT, '#fff', SUN), 'evento': (f'linear-gradient(150deg,#0e3b45,{TEAL})', '#fff', GOLD), 'desejo': (f'linear-gradient(150deg,{SUN},#c4467a)', '#fff', CREAM),
            'curiosidade': (GOLD, INK, INK), 'autoridade': (f'linear-gradient(150deg,#211a4a,{VIOLET})', '#fff', GOLD), 'oferta': ('#fff', INK, VIOLET)}[ang]
    extra = ''
    if ang == 'dor': extra = bolha('Hmm… I… é… 😶', 196, 62) + bolha('How are you today?', 150, 18, TEAL, INK, 'r')
    if ang == 'curiosidade': extra = f'<div style="position:absolute;right:22px;top:22px;font:900 40px Inter;color:{INK};opacity:.12">✗</div>'
    if ang == 'evento': extra = f'<div style="position:absolute;right:22px;top:22px;width:72px;text-align:center;background:#fff;color:{INK};border-radius:10px;overflow:hidden"><div style="background:{SUN};color:#fff;font:800 11px Inter;padding:3px">OUT</div><div class="h" style="font-size:34px;padding:4px 0">27</div></div>'
    return 'sq', 'Estático 1:1', f'''<div class="cr sq" style="background:{tema[0]};color:{tema[1]};padding:24px">{LOGO(tema[1])}<style>.sq .logo{{left:24px;top:20px}}</style>{extra}
      <div class="h" style="position:absolute;left:24px;right:24px;top:{128 if ang == 'dor' else 92}px;font-size:{34 if len(a['hook']) > 34 else 40}px">{hook}</div>
      <div class="cta" style="background:rgba(0,0,0,.18);color:{tema[1]}"><span>{sub}</span><span style="background:{tema[2]};color:{NIGHT if tema[2] != INK else '#fff'};padding:5px 10px;border-radius:20px;font-size:12px">Quero participar</span></div></div>'''
def dots(f):
    return '' if f != 'carrossel' else '<div style="position:absolute;right:16px;top:16px;font:700 11px Inter;background:rgba(0,0,0,.35);color:#fff;padding:3px 8px;border-radius:20px">1/5</div>'

EXTRA = [dict(cod='Perpétuo · Dor da trava', formato='estatico', angulo='dor', hook='Travou de novo na reunião?', sub='Curso Inglês Base · R$ 997'),
         dict(cod='Perpétuo · Prova social', formato='reels', angulo='prova', hook='“Fiz minha entrevista em inglês”', sub='Júlia, aluna do Curso Base'),
         dict(cod='Perpétuo · Oferta do curso', formato='estatico', angulo='oferta', hook='Curso Inglês Base por 12x de R$ 99,70', sub='Acesso por 1 ano'),
         dict(cod='Pesquisa · curso de inglês', formato='texto', angulo='oferta', hook='Curso de inglês para adultos', sub='Turma de setembro com aulas ao vivo')]
saida = {}
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 640, 'height': 360}, device_scale_factor=2)
    for a in P['ads'] + EXTRA:
        cls, fmt, cr = criativo(a, None)
        pg.set_content(f'<html><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="stage"><div class="fmt">{fmt}</div>{cr}</div></body></html>'); pg.wait_for_timeout(120)
        png = pg.locator('.stage').screenshot(); a['cod'] = a['cod'] if a['cod'].startswith('AD') else 'X_' + a['cod']
        im = Image.open(io.BytesIO(png)).convert('RGB'); im.save(OUT + a['cod'] + '_previa.png')
        buf = io.BytesIO(); im.resize((640, 360), Image.LANCZOS).save(buf, 'WEBP', quality=78, method=6)
        pg.locator('.cr').screenshot(path=OUT + a['cod'] + '_criativo.png')
        saida[a['cod']] = 'data:image/webp;base64,' + base64.b64encode(buf.getvalue()).decode()
    b.close()
json.dump(saida, open('imagens.json', 'w'))
print('ok', len(saida), 'imagens,', sum(len(v) for v in saida.values()) // 1024, 'KB em data URI')
