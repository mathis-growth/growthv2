

## Mini gráfico na árvore (v0.122)
- `arvGrafico(N)` (montado no `arvDesenha`, logo abaixo da explicação): linha, cascata, rosca, barras ou medidor, em SVG, com `data-arvno` nos elementos para descer.
- `arvSerie(top, caixa)`: quando não há gráfico, calcula o nó para 4 meses com `arvore_no` e troca a caixa "Calculando…" pela linha. `arvMedidor(N)` para percentual.
- Montagem: `integra122.py` (roda o `integra121.py`) com `g122.js` e o estilo `#v122`.
- Teste: `t122_graficos_arvore.py` (rosca/linha na receita, descer pelo gráfico, cascata no lucro, série do CAC com cor invertida).
