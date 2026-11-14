# Planejamento de campanha avançado

Módulo do Growths desde a **v0.287**. É um motor só (`motor.js` + os `app_*.js`), montado em **três telas** desde a v0.293, cada uma com o seu lugar no menu:

| Tela do Growths | Onde | `DADOS.modo` |
|---|---|---|
| Diagnóstico e baseline | Administrativo → Diagnóstico e baseline | `baseline` |
| Plano e resultados do ano | Administrativo → Plano e resultados do ano | `planoAno` |
| Planejamento de campanha avançado | Marketing → Planejamento de campanha avançado | `campanha` |

As duas telas do Administrativo são **só da equipe Mathisa** (`TELAS_INT`, nenhum pacote de cliente libera). Cadastrar um cliente novo leva direto para o Diagnóstico e baseline. No Growths, cada tela lê os dados do cliente e salva em `campanha_calculos` (`premissas.baseline`, `premissas.planoAno` ou o rascunho da campanha); o que for aprovado numa alimenta as outras pelo banco, não por estado compartilhado. Aberto sozinho (`planejamento-campanha-avancado.html`), roda com os dados fictícios do exemplo, sempre no modo `campanha`.

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
| `testes.js` | 82 testes. `node testes.js` sai com erro se algum falhar. |
| `app.js`, `app_plano.js`, `bc.css`, `base.css` | Telas. |
| `app_tipo.js` | Tipo de campanha (objetivo × modelo): cartões do passo 1, rótulos do funil e regras de cálculo de cada tipo. |
| `app_res.js` | Resultados do ano: trimestres, planejado → realizado, aprendizado; ligação com a campanha no passo 2 (esse passo aparece mesmo quando `DADOS.modo` é `campanha`). Só aparece como tela quando `DADOS.modo === 'planoAno'`. |
| `app_ano.js` | Plano do ano: meta × baseline, cenários, trimestres, orçamento para as campanhas. Só aparece como tela quando `DADOS.modo === 'planoAno'`. |
| `app_base.js` | Diagnóstico e baseline: indicadores, lacunas, custo de servir, aprovação. **É quem decide, pelo `DADOS.modo`, qual aba cada uma das 3 telas mostra** (a barra de abas e a área inicial de `ST.area` ficam aqui). |
| `teste_baseline.js` | 10 testes das contas do baseline (`planavBaseCalc`). `node teste_baseline.js`. |
| `app_real.js` | Modo Growths: monta as premissas com os dados do cliente, seletores de produto e estratégia, salvamento. |
| `planav_growths.js` | O que entra no `index.html`: leitura dos dados (`planavDados`) e as três telas (`vPlanavFabrica`, que gera `mkt-planav`, `adm-baseline` e `adm-plano` a partir do mesmo motor). |
| `fake_sb.js`, `teste_separacao.js`, `teste_separacao.html` | Teste das três telas com um banco de mentira (`teste_separacao.html` já traz a fixture do workspace Demo embutida; `node teste_separacao.js` abre as três via `VIEWS['adm-baseline']`/`['adm-plano']`/`['mkt-planav']` e confere abas, cross-links e largura mobile). |
| `build.py` | Junta tudo em `planejamento-campanha-avancado.html` e gera `planav_srcdoc.js` (o módulo como texto, para o `index.html`). |
| `perf.js`, `perf.json`, `perf_sql.json` | Performance medida (motor e consultas de leitura em produção). |

Para atualizar o Growths: `python3 build.py`, depois o `aplicaNNN.py` da versão cola `planav_srcdoc.js` + `planav_growths.js` no `index.html` e ajusta o menu/permissões quando a versão pedir (como a v0.293 fez para as duas telas novas do Administrativo).
