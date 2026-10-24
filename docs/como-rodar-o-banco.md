

## v0.132 — Alertas e resumo do dia
Na ordem:
1. `supabase/RODAR_v0.132_alertas.sql` (tabelas e funções). Pode ser rodado de novo sem erro.
2. Publicar as edge functions: `supabase functions deploy avisos --no-verify-jwt` e `supabase functions deploy perguntar`.
3. `supabase/RODAR_v0.132_agendador.sql` com o id do projeto no lugar de `<PROJETO>` (liga pg_cron e pg_net e agenda `growths_rodar_agendado()` de hora em hora).
4. Segredos (Edge Functions → Secrets), quando houver: `RESEND_API_KEY` e `AVISOS_EMAIL_DE` (e-mail); `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID` e o modelo `aviso_growths` aprovado na Meta (WhatsApp); `ANTHROPIC_API_KEY` ou `OPENAI_API_KEY` (IA). Sem eles, o sino funciona e os e-mails/WhatsApps ficam marcados como "não foi" com o motivo.
5. Em cada cliente, na tela Alertas e resumo do dia, "Ligar alertas e resumo".
**Pendente em produção.**

## v0.131
- Nada a rodar no banco.

## v0.130 — Formulário de captação
- `supabase/RODAR_v0.130_formulario.sql`: colunas de aparência, captação e passo; funções `pesquisa_captar` (pública) e `pesquisa_registrar` (interna); reescreve `pesquisa_responder` e `pesquisa_publica` mantendo o comportamento. Precisa da v0.129 aplicada antes. Pode ser rodado de novo sem erro. Aplicado em produção em 21/10/2026.

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
