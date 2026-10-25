

## v0.141
1. `supabase/RODAR_v0.141_acesso_content.sql` (aplicado em produção em 25/10/2026).


## v0.140 — Pasta do cliente no Drive
1. `supabase/RODAR_v0.140_content_drive.sql` (aplicado em produção em 25/10/2026).
2. Publicar a função: `supabase functions deploy content-drive --no-verify-jwt` (publicada em 25/10/2026).
3. Publicar o Apps Script (`integracoes/apps-script/growths-drive.gs`) como App da Web (Executar como: eu; Acesso: qualquer pessoa) e gravar `drive_script_url` em `sistema_config`.


## v0.139
Nada a rodar no banco: só a tela mudou.


## v0.138
Nada a rodar no banco: só a tela mudou.


## v0.137
Nada a rodar no banco: só a tela mudou.


## v0.136 — Classificar post do Instagram
1. `supabase/RODAR_v0.136_instagram_classificar.sql` (aplicado em produção em 25/10/2026). Pode rodar de novo sem erro.


## v0.135 — DMs do Instagram e canais
1. `supabase/RODAR_v0.135_dms_canais.sql` (aplicado em produção em 25/10/2026).
2. Função `zernio-sync` (sem verificação de JWT) na versão que também traz as DMs; cron `zernio-dms` a cada 30 minutos (`{"partes":["dms"]}`), além do `zernio-sync-diario` (posts e conta, 9h UTC). Ambos já criados em produção.
3. Migrações feitas em produção por outra sessão e agora copiadas para o repositório: `20261025022737_instagram_dm_crm.sql` (registrar_dm_instagram, canal Instagram DM) e `20261025034245_conexao_zernio.sql` (conexão zernio; o trecho do Vault só roda no Supabase).

## v0.134 — Dashboard do Instagram
1. `supabase/RODAR_v0.134_instagram.sql` (depois da v0.133; pode ser rodado de novo sem erro). Nenhuma edge function nova.
2. Para usar já: Marketing → Instagram → Importar posts (CSV exportado do Meta Business Suite ou do Metricool) e Importar dados da conta (seguidores e alcance por dia). Quando o app da Meta for aprovado, a conexão (`conexoes`) passa a preencher os mesmos números sozinha.

## v0.133 — Máquina de Conteúdo
1. `supabase/RODAR_v0.133_maquina_conteudo.sql` (só acrescenta colunas, tabelas e funções; pode ser rodado de novo sem erro). Não depende da v0.132.
2. Publicar a edge function `linha-editorial` (com verificação de JWT, padrão): `supabase functions deploy linha-editorial`. Usa os mesmos segredos de IA do "Pergunte ao Growths" (`ANTHROPIC_API_KEY` e/ou `OPENAI_API_KEY`). Sem chave, a tela usa "Copiar pedido" e "Colar resposta da IA".
3. No Growths, Marketing → Máquina de Conteúdo → "Instalar o modelo V18" no cliente da Rebecka (ou pelo SQL: `select conteudo_instalar_v18('<workspace>')`).

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
