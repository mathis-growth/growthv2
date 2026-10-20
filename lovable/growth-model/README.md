# Pacote Lovable — Growth Model (piloto)

Fluxo combinado: a lógica é ajustada e testada aqui; depois replicamos no Lovable só o front.

1. Conectar o Lovable ao Claude (claude.ai → Configurações → Conectores → Lovable) para eu criar/atualizar o projeto direto. Sem conector, siga o passo 2 manualmente.
2. No Lovable: novo projeto → colar `PROMPT-LOVABLE.md` → anexar `src/lib/*.ts`, `contrato-de-dados.md` e `.env.example`.
3. Testar com um login seu. Anotar o que ajustar; a regra (cálculo, alerta, conta) é corrigida aqui e os arquivos de `src/lib` são trocados lá.

Arquivos:
- `PROMPT-LOVABLE.md` — texto para colar.
- `contrato-de-dados.md` — tabelas, funções e regras.
- `src/lib/growth-motor.ts` — loops e projeção (igual ao sistema original).
- `src/lib/calculadora.ts` — calculadora de campanha.
- `src/lib/alertas.ts` — alertas em vermelho (benchmark, média histórica, período anterior).
- `.env.example` — URL e chave pública do Supabase.

Os arquivos `.ts` têm `// @ts-nocheck` porque vieram do JavaScript do sistema; podem ser tipados depois sem mudar a lógica.
