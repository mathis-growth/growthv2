# Atendimento v0.192 — agendamento de mensagens

## Escopo

- Agendar texto de uma conversa existente, em data/hora de Brasília.
- Consultar e cancelar envios ainda não iniciados na conversa.
- Envio por Evolution e Zernio, usando os adaptadores já existentes e assinatura do atendente.
- Fila persistente e reserva atômica pelo banco; cron a cada minuto; sem reenvio automático se o estado for incerto.
- Não agenda áudio, imagem, anexos nem notas internas nesta versão.

## Instalação — aplicar em ordem

1. Aplicar `supabase/migrations/20261101020000_atendimento_agendamentos.sql` no projeto Supabase correto, **uma vez**.
2. A migration cria automaticamente um token aleatório na tabela protegida `sistema_config`. **Não é necessário criar Edge Function Secrets.** A Edge obtém esse token internamente com a credencial de serviço já configurada.
3. Configurar o URL da Edge no banco, substituindo `<PROJECT_REF>` pelo identificador real:

   ```sql
   update public.sistema_config
   set valor='https://<PROJECT_REF>.supabase.co/functions/v1/atendimento'
   where chave='atd_agenda_url';
   ```

4. Publicar a Edge `atendimento` com `docs/edge-atendimento-v0193-index-unico.ts` (arquivo único). Manter `Verify JWT = OFF` para webhooks e cron; as rotas normais validam o usuário e a rota do cron valida o token privado armazenado no banco.
5. Verificar que o agendamento foi criado:

   ```sql
   select jobname,schedule,active from cron.job
   where jobname='atendimento-envios-agendados';
   ```

6. Testar **primeiro com um número de teste**, agendando para 3 minutos à frente. Verificar o estado na aba Agendamentos e no banco. Não enviar mensagens reais de teste a clientes.

## Funcionamento e limites

- A execução ocorre no primeiro ciclo de cron após o horário, normalmente em até 1 minuto, dependendo da disponibilidade dos serviços.
- O horário escolhido é interpretado como `America/Sao_Paulo` (UTC-03:00 nesta implementação). Se regras de horário de verão voltarem, revisar a conversão do frontend.
- Uma falha explícita recebe status `erro`; uma resposta remota ambígua recebe `incerto` e exige conferência manual. Não há retry automático para evitar duplicidade.
- Um agendamento só pode ser cancelado enquanto está `agendado`. Depois que o processamento começa, o cancelamento não é garantido.
- A API oficial do WhatsApp pode recusar texto livre fora da janela de atendimento de 24 horas; nesses casos é necessário um template previamente aprovado.
- O projeto deve manter a Edge e o cron em operação para executar os envios.
