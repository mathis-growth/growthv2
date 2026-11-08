import pathlib
d = pathlib.Path(__file__).parent; g = d
css = (g / 'base.css').read_text() + (d / 'bc.css').read_text()
testes = (d / 'testes.js').read_text()
shim = "function rodaTestes(){ const module = { exports: {} }; const require = n => n === './motor.js' ? window.BC : { EXEMPLO: window.EXEMPLO };\n" + testes + "\nreturn module.exports; }\n"
html = f'''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Planejamento de campanha avançado</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Instrument+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap" rel="stylesheet">
<style>{css}</style></head><body><div class="wrap">
<header style="margin-bottom:14px"><h1>Planejamento de campanha avançado <span class="exemplo">dados fictícios</span></h1>
<p class="muted">Módulo em protótipo (fase 1): da estratégia ao cockpit, com o Business Case no meio. Primeiro caso: Captação → Evento → Venda. Roda só no seu navegador, com o motor isolado e dados de exemplo. Nada é gravado no Growths. <button type="button" class="btn" data-zera style="margin-left:6px">Recomeçar o exemplo</button></p></header>
<nav id="nav" aria-label="Passos"></nav><main id="app"></main></div>
<script>{(d / 'motor.js').read_text()}</script>
<script>{(d / 'exemplo.js').read_text()}</script>
<script>{shim}</script>
<script>{(d / 'app.js').read_text().rstrip()[:-len('render();')]}
{(d / 'app_plano.js').read_text()}
render();</script></body></html>'''
(d / 'planejamento-campanha-avancado.html').write_text(html); print(len(html))
