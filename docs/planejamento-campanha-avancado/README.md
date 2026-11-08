# Planejamento de campanha avançado

Protótipo do módulo (fase 1 da especificação de arquitetura). **Não está no `index.html` e não mexe no banco.** Dados fictícios ("Seminário Método X").

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
| `app.js`, `app_plano.js`, `bc.css`, `base.css` | Telas do protótipo. |
| `build.py` | Junta tudo em `planejamento-campanha-avancado.html`. |
| `perf.js`, `perf.json`, `perf_sql.json` | Performance medida (motor e consultas de leitura em produção). |

Próximo passo (fase 2) só com aprovação explícita: ver "Plano em fases e decisões pendentes" no documento.
