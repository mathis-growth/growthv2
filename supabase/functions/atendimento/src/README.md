# Código-fonte da Edge de Atendimento

Edite as partes numeradas deste diretório. `index.ts` é o arquivo único gerado
para publicação no Supabase; ele não importa arquivos locais.

As partes `50` a `55` são trechos sequenciais da função `handle`. As demais
partes contêm funções completas. A ordem dos arquivos está definida em
`scripts/build-atendimento.mjs`.

Depois de editar:

```sh
node scripts/build-atendimento.mjs --write
node scripts/build-atendimento.mjs --check
node --check supabase/functions/atendimento/index.ts
```

O gerador recusa `--write` quando `index.ts` foi alterado fora dele. Nesse
caso, compare as mudanças e incorpore-as nas partes antes de regenerar.
Para publicar manualmente, copie apenas o conteúdo de `index.ts`.
