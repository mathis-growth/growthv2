# Ambientes: Teste, Homologação e Produção (proposta de 20/10/2026)

Mapa visual: artefato "Ambientes do Growths", no Claude.

| | Teste | Homologação | Produção (cliente) |
|---|---|---|---|
| Galho no GitHub | `dev` | `homologacao` | `main` (protegido) |
| Tela (Cloudflare Pages) | `dev.growthv2.pages.dev` | `homologacao.growthv2.pages.dev` | endereço oficial |
| Banco (Supabase) | projeto `growths-teste` (novo) | projeto `growths-homolog` (novo) | `yngyghlyonybvfvjcmxl` (atual) |
| Dados | fictícios (seed), recriáveis | cópia anonimizada da produção ou workspace de validação | reais |
| Faixa na tela | amarela "TESTE" | roxa "HOMOLOGAÇÃO" | nenhuma |

**Como uma versão anda**
1. Ela nasce em `dev`.
2. Um pull request `dev → homologacao` só mescla se os testes automáticos passarem.
3. A versão é validada em Homologação.
4. Um pull request `homologacao → main`, com aprovação, publica a versão e cria a tag `vX.YYY`.

Cada mesclagem publica sozinha, pelo GitHub Actions: aplica as migrações no projeto do ambiente, publica as funções e a tela.

**Como alternar**
- Cada ambiente tem o seu endereço.
- O mesmo `index.html` descobre o banco pelo endereço em que está aberto.
- Os segredos são separados em cada projeto.

**Como voltar atrás**
- A tela volta com o rollback do Cloudflare Pages.
- O banco só anda para frente, com uma migração de correção. No pior caso, usa-se o backup ou o PITR da produção.

**Por que três projetos**: o isolamento é total, e é simples. O Branching do Supabase fica como opção futura para o Teste. Um projeto só não protege os clientes de uma migração errada.

**Pendente**: criar os dois projetos (custo), os galhos, o Actions, a ligação no Cloudflare, o mapa no `index.html` e as cargas iniciais. Ver o checklist no mapa.
