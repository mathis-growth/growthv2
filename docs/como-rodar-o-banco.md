

## v0.130 — Formulário de captação
- `supabase/RODAR_v0.130_formulario.sql`: colunas de aparência, captação e passo; funções `pesquisa_captar` (pública) e `pesquisa_registrar` (interna); reescreve `pesquisa_responder` e `pesquisa_publica` mantendo o comportamento. Precisa da v0.129 aplicada antes. Pode ser rodado de novo sem erro. **Pendente em produção.**

## v0.129 — Qualificação por pontos
- `supabase/RODAR_v0.129_qualificacao.sql`: colunas da regra e dos pontos, funções de qualificação e a ligação com `pesquisa_responder`. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

## v0.128
- Nada a rodar.

## v0.127 — Saldo mínimo de caixa
- `supabase/RODAR_v0.127_saldo_minimo.sql`: cria `empresa.saldo_minimo`. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

## v0.126
- Nada a rodar no banco.

## v0.125
- Nada a rodar no banco.

## v0.124
- Nada a rodar no banco. Para ver o ritmo da meta, cadastre as metas mensais em Campanhas → Planejamento anual.

## v0.123 — Série do gráfico
- `supabase/RODAR_v0.123_arvore_serie.sql`: já aplicado em produção em 21/10/2026. Para outro projeto, rode depois do da v0.121.
