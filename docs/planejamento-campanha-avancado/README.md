# Planejamento de campanha avançado

Módulo do Growths desde a **v0.287** (Marketing → Planejamento de campanha avançado). No Growths ele lê os dados do cliente e salva rascunhos em `campanha_calculos`. Aberto sozinho (`planejamento-campanha-avancado.html`), roda com os dados fictícios do exemplo.

- Documento da fase 1: https://claude.ai/artifact/M22biHKQgkZjS51vL3iKVG
- Protótipo publicado: https://claude.ai/artifact/FPN5hYdzgGCypkWJ3tUcBx
- Abrir aqui: `planejamento-campanha-avancado.html` (arquivo único, roda no navegador)

## Passos
1. Estratégia · 2. Produto e oferta · 3. Histórico do produto · 4. Informações financeiras · 5. Validar margem · 6. Recursos · 7. Orçamento máximo · 8. CAC e CPL · 9. Escolher e copiar para os cenários · 10. Distribuir por canal · 11. Business Case · 12. Status e aprovação · 13. Growth Model da campanha · 14. Cockpit

## Arquivos
| Arquivo | O que é |
|---|---|
| `motor.js` | Motor de cálculo, funções puras (Node e navegador). Fonte única das fórmulas. |
| `exemplo.js` | Dados fictícios do exemplo. |
| `testes.js` | 67 testes. `node testes.js` sai com erro se algum falhar. |
| `app.js`, `app_plano.js`, `bc.css`, `base.css` | Telas. |
| `app_real.js` | Modo Growths: monta as premissas com os dados do cliente, seletores de produto e estratégia, salvamento. |
| `planav_growths.js` | O que entra no `index.html`: leitura dos dados (`planavDados`) e a tela (`vPlanav`). |
| `fake_sb.js`, `teste_planav.js` | Teste do módulo com um banco de mentira (precisa de um `fixture_demo.json`, não versionado). |
| `build.py` | Junta tudo em `planejamento-campanha-avancado.html` e gera `planav_srcdoc.js` (o módulo como texto, para o `index.html`). |
| `perf.js`, `perf.json`, `perf_sql.json` | Performance medida (motor e consultas de leitura em produção). |

Para atualizar o Growths: `python3 build.py`, depois o `aplicaNNN.py` da versão cola `planav_srcdoc.js` + `planav_growths.js` no `index.html`.
