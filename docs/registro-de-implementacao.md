

## Fim da Onda 2 e da Onda 1 (v0.126)
- Componentes: `gcPilha`, `gcTornado`, `gcMatriz2x2`, `gcHalteres`, `gcDivergente`, `gcFunil`; `gcLinhas` ganhou `W` (largura) e `GC` o formato `n2`. Agrupamento: `gcGranDe`, `gcBaldes`, `gcChave`, `gcSemana`.
- Telas: `abandonoV126`, `rxLtvPainel` (em `rxCoortes`), `gmTornado` (fim do `gpDesenha`), `cicloV126`, `resultadosV126`, `debriefDesvio` e `gcFunil` (em `htmlComparativo`), `campBurnup` (aba Dashboard da campanha), `midiaV126` (Mídia paga), `mktSerie126` (Dashboard de marketing), `painelNovosExist` (Dashboard).
- Montagem: `integra126.py` (roda o `integra125.py`) com `g126.js` e `g126.css`.
- Teste: `t126_onda2_parte2.py`.

## Onda 2, parte 1 (v0.125)
- Componentes: `gcBarrasV`, `gcEmpilhada`, `gcDispersao`, `gcTodos` (paginação de 1.000 linhas); `gcBarrasH` ganhou `fixo` (mantém ordem e zeros).
- Telas: `painelObs` (Dashboard), `finResBanco` (Financeiro), `finVencimentos(m, 'receber'|'pagar')`, `mrrEm` e `contratosV125` (Contratos), `vendasV125` (Vendas), `mktV125` (Dashboard de marketing), `origemV125` (Leads por origem).
- Montagem: `integra125.py` (roda o `integra124.py`) com `g125.js` e `g125.css`.
- Teste: `t125_onda2_parte1.py`.

## Gráficos da onda 1 (v0.124)
- Componente: `gcLinhas`, `gcBarrasH`, `gcCascata`, `gcBullet`, `gcRitmo`, `gcLiga` (cliques que abrem a árvore) e o objeto `GC` (formatos, vazio, fonte). CSS com prefixo `gc-`. (O prefixo `gx` já era usado pelo Growth Model.)
- Dashboard: `painelV124(m, ctx)` chamado no fim do `vPainel`; DRE e fluxo em `<details class="gc-det">`.
- Financeiro: `finCascata(m, PER)` no fim do `vFinDash`; filtro de meses ≤ mês atual em "Resultado por mês".
- Custos e margens: `custoV124(m, ctx)` no fim do `vCustoOp`.
- Mídia: `midiaRelatorio(el, R, de, ate, cs, cp)` no fim do `vTrafego`; `irMidiaCampanha(c)` no botão `#cMidia` da campanha. Rotas: `adm-dash` → `vPainel` (troca a view para `adm-painel`), `st-dash` → `vPainel`, `mkt-midia` → `vTrafego` (fora do Starter troca para `mkt-trafego`). `vMidia` e `vDashGrowth` ficaram no código, sem rota.
- Montagem: `integra124.py` (roda o `integra123.py`) com `g124.js` e `g124.css`.
- Teste: `t124_graficos_onda1.py`.

## Linha no período e cadastros na campanha (v0.123)
- `arvLinha(top, N, root)` (no `arvDesenha`): caixa com os botões de agrupamento, chama `arvore_serie` e guarda por agrupamento em `top.series`. `arvGranAuto`, `arvRotPonto`.
- `estNova(pr, dup, aoCriar)`: com `aoCriar` abre em `#modalRoot2` (o `modal()` ganhou o parâmetro `raiz` e só redesenha a tela quando é o modal principal). Etapas: `estPickHtml`, `estPickModelo`, `estPickLer`.
- Nova campanha (`abrirWizard`): produto com `data-novo="produtos"` (`ligarNovo`), estratégia com "＋ Nova estratégia…" e prévia das etapas (`#wzEt`), canal com `cadastroRapido(ENT.canais…)`.
- Montagem: `integra123.py` (roda o `integra122.py`), com `g123.js` e `est123.js`; remove o bloco da v0.122.
- Teste: `t123_linha_cadastros.py`.
