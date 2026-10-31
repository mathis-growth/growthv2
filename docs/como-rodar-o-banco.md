## v0.178 — Conexão Zernio por cliente (ainda não publicada)
1. Exige a Central de Atendimento v0.175 no banco.
2. Aplicar `supabase/migrations/20261030220000_zernio_cliente.sql` no banco correto.
3. Publicar a Edge Function `atendimento` e a interface atualizada, mantendo `ZERNIO_API_KEY` em Secrets.
4. Selecionar cliente → Configurações → Integrações → Zernio → Vincular conta. Depois Atendimento → Canais e conexões → Adicionar conta.
5. Testar isolamento entre clientes, conta já vinculada, credenciais ausentes e WhatsApp oficial.



## v0.163 — Customer Growth
**Situação em 29/10/2026:** as migrações 20261116100000 a 20261123100000 foram aplicadas em produção pelo conector (registradas como `v0163_1` a `v0163_8`). A última (`RODAR_v0.163_contencao_alertas.sql`) desliga os alertas de CS (`sistema_config.cg_alertas = 'nao'`), apaga esse acúmulo e tira os alertas de CS do resumo e do "Pergunte ao Growths".
Quando a tela RevOps → Customer Growth estiver no ar: `select cg_ligar_alertas();` (registra o que já acontece sem avisar ninguém e liga). **Feito em 29/10/2026**, com a v0.163 no ar: 824 alertas abertos (340 parados, 484 sem CS) em Escola Aurora, Growths — Demo e Mathisa — Operação, sem aviso enviado.
1. Confira antes que a v0.132 (alertas e agendador) está aplicada: o arquivo verifica e para com uma mensagem se faltar algo, sem gravar nada.
2. `supabase/RODAR_v0.163_customer_growth.sql` no SQL Editor do Supabase: é tudo ou nada e pode ser rodado de novo. **Ainda não aplicado em produção.**
3. Publicar de novo a edge function `leads` (sem verificação de JWT) para receber eventos da plataforma do curso: `supabase functions deploy leads --no-verify-jwt`. **Feito em 29/10/2026** (versão 6, pelo conector).
4. Sem o SQL, as telas novas avisam que falta a atualização do banco e o resto do Growths continua igual.

## v0.161
Nada a rodar no banco (só tela). Continuam pendentes os SQL da v0.157, v0.159 e v0.160.

## v0.160 — Subtemas e datas no Kanban
1. `supabase/RODAR_v0.160_content_segmentos.sql` (depois do da v0.159): subtemas (`conteudo_temas.tema_pai_id`), `conteudos.subtema_id`, gatilho `conteudo_tema_valida` e a regra nova em `conteudo_valida` (no método simples, aprovar a ideia exige tema e data de publicação). **Ainda não aplicado em produção.**
2. Ordem para rodar: `RODAR_v0.157_narrativas.sql`, `RODAR_v0.159_content_simples.sql`, `RODAR_v0.160_content_segmentos.sql`.

## v0.159 — Growth's Content simplificado
1. `supabase/RODAR_v0.159_content_simples.sql`: cria `content_fichas`, `content_identidade`, `content_versoes`; colunas de roteiro, aprovação da peça e vídeo bruto em `conteudos`; método "simples" em `conteudo_config` (vira o padrão e é aplicado às configurações existentes); regra nova em `conteudo_valida`. **Ainda não aplicado em produção.** Em 26/10/2026 a produção tinha 1 configuração (score6) e nenhum conteúdo.
2. Sem ele, as abas novas avisam que falta a atualização do banco; Mais ferramentas continua funcionando.

## v0.158
Nada a rodar no banco (só tela). Continua pendente o `RODAR_v0.157_narrativas.sql`.

## v0.157 — Banco de narrativas
1. `supabase/RODAR_v0.157_narrativas.sql`: cria `narrativa_modelos` e `narrativa_modelos_historico`, a regra de versão (gatilho `narrativa_modelos_regras`) e os 39 modelos (9 aprovados). **Ainda não aplicado em produção**: a aplicação pelo conector foi cancelada em 26/10/2026. Rodar no SQL Editor do Supabase ou autorizar de novo.
2. Sem a tabela, a tela continua funcionando: as frases do piloto não aparecem e o Dicionário avisa que falta a atualização.
3. Para mudar um texto: editar a linha em `narrativa_modelos` (Table Editor ou SQL). A versão sobe sozinha, a anterior vai para o histórico e o modelo volta para "proposto"; para aprovar, `status = 'aprovado'` e `aprovado_por` preenchido.

## v0.152 a v0.156 — Data Storytelling
1. `supabase/RODAR_v0.156_metricas_semantica.sql` (aplicado em produção em 26/10/2026): colunas `unidade`, `casas`, `direcao`, `zero_limite` e `referencia` em `metricas_definicoes` e as linhas novas Lucro, Margem, ROI, Caixa projetado e CTR.
2. As versões 0.152 a 0.155 são só tela.

## v0.151 — Pesquisa e dossiê
1. `supabase/RODAR_v0.151_content_pesquisa.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-pesquisa --no-verify-jwt` (publicada em 25/10/2026, versão 2; o GET diz só se os segredos existem).
3. Segredo `ANTHROPIC_API_KEY` (Supabase → Edge Functions → Secrets), com a chave criada em console.anthropic.com. Sem ele, a tela avisa e o botão fica desligado.
4. Apps Script: colar o código novo de `integracoes/apps-script/growths-drive.gs` (com a senha real) e reimplantar como nova versão. Ele pede de novo a autorização da conta (agora lê Documentos, Planilhas e Apresentações).
5. Opcional: `sistema_config.ia_precos` com o preço por milhão de tokens do modelo e por mil buscas, para o custo ser calculado; vazio = "sem custo calculado".

## v0.150 — Ficha de produto simples
1. `supabase/RODAR_v0.150_content_produtos_v2.sql` (aplicado em produção em 25/10/2026). Tira a ficha longa da v0.149 (sem nenhum dado) e cria `content_produtos`.

## v0.149 — Ficha de conteúdo dos produtos
1. `supabase/RODAR_v0.149_content_produtos.sql` (aplicado em produção em 25/10/2026).

## v0.148
Nada a rodar no banco.

## v0.147 — Só a pasta do cliente; pastas da Mathisa
1. `supabase/RODAR_v0.147_content_pastas.sql` (aplicado em produção em 25/10/2026).
2. As pastas da Mathisa precisam estar no Drive de rebecka@rebeckacappello.com.br (a conta que roda o Apps Script) ou compartilhadas com ela.

## v0.146 — Estruturas de roteiro e copy; custos de IA
1. `supabase/RODAR_v0.146_content_estruturas.sql` (aplicado em produção em 25/10/2026 pela Rebecka, no SQL Editor; a ferramenta de migração estava sem permissão de escrita).
2. Quem vê os custos: `sistema_config.custos_emails` (e-mails separados por vírgula; hoje só rebecka@rebeckacappello.com.br). Precisa também ser da equipe interna.
3. Câmbio: na própria tela Custos de IA (fica em `sistema_config.cambio_usd_brl`; vazio = só em dólar).

## v0.145 — Canais e materiais do cliente
1. `supabase/RODAR_v0.145_content_fontes.sql` (aplicado em produção em 25/10/2026).
2. Nada a publicar nas funções. A árvore nova vale para as próximas pastas; nas que já existem, "Completar as pastas" cria as subpastas que faltam.

## v0.144 — Configuração em 8 passos e pasta compartilhada
1. `supabase/RODAR_v0.144_content_setup_v2.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-drive --no-verify-jwt` (publicada em 25/10/2026, versão 5).
3. Nada mais a configurar: a pasta compartilhada usa o Apps Script da v0.140 (gratuito). `sistema_config.drive_script_email` é o e-mail com quem o cliente compartilha a pasta.

## v0.143 — Configuração passo a passo
1. `supabase/RODAR_v0.143_content_setup.sql` (aplicado em produção em 25/10/2026).
2. `supabase functions deploy content-google --no-verify-jwt` (publicada em 25/10/2026).
3. Segredos `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` (Google Cloud → Credenciais → ID do cliente OAuth "Aplicativo da Web"; URI de redirecionamento `https://<projeto>.supabase.co/functions/v1/content-google`; Google Drive API ativada).


## v0.142
Nada a rodar no banco.


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
