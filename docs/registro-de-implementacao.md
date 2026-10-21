

## Linha no período e cadastros na campanha (v0.123)
- `arvLinha(top, N, root)` (no `arvDesenha`): caixa com os botões de agrupamento, chama `arvore_serie` e guarda por agrupamento em `top.series`. `arvGranAuto`, `arvRotPonto`.
- `estNova(pr, dup, aoCriar)`: com `aoCriar` abre em `#modalRoot2` (o `modal()` ganhou o parâmetro `raiz` e só redesenha a tela quando é o modal principal). Etapas: `estPickHtml`, `estPickModelo`, `estPickLer`.
- Nova campanha (`abrirWizard`): produto com `data-novo="produtos"` (`ligarNovo`), estratégia com "＋ Nova estratégia…" e prévia das etapas (`#wzEt`), canal com `cadastroRapido(ENT.canais…)`.
- Montagem: `integra123.py` (roda o `integra122.py`), com `g123.js` e `est123.js`; remove o bloco da v0.122.
- Teste: `t123_linha_cadastros.py`.
