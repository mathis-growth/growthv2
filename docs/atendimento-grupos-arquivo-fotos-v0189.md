# v0.189 — Nomes de grupos, grupos arquivados e fotos no Atendimento

## Causa encontrada
No banco, os grupos das instâncias Evolution estavam registrados com o identificador `...@g.us` como `nome`. O importador anterior considerava `remoteJid` como fallback e não enriquecia os grupos sem `subject`. O envio de mensagens não deve usar `pushName` de participantes como título do grupo.

## Mudanças implementadas
1. **Nomes reais dos grupos**: em **Canais e conexões → Buscar conversas e grupos**, a sincronização combina `/chat/findChats` com `/group/fetchAllGroups`, prioriza `subject` e demais campos de título, e consulta `/group/findGroupInfos` para grupos ainda sem nome. Limitadas a dez consultas extras por execução. Nomes existentes corretos são preservados quando o provedor não informa novo nome.
2. **Arquivar grupos no Growth V2**: botão **Arquivar grupo/Desarquivar grupo** na conversa. Apenas muda `atd_conversas.arquivada`, mantendo mensagens e mídia. Não altera o status arquivado na plataforma WhatsApp.
3. **Checkbox por instância**: em **Atendimento → Canais e conexões**, `Exibir grupos arquivados` é configurado por administrador para cada instância Evolution, salvo em `atd_canais.exibir_grupos_arquivados`. Na lista de conversas, grupos arquivados são ocultados por padrão e reexibidos por preferência. Este status é **operacional do Growth V2**: não presumir que Evolution v2.3.7 expõe arquivamento do WhatsApp celular.
4. **Fotos de contatos e grupos**: sincronização chama `/chat/fetchProfilePictureUrl`, valida tipo e tamanho (até 512 KB), armazena no bucket privado `atendimento` em pasta por workspace/canal, e registra `avatar_path`; URLs curtas são entregues via endpoint autenticado `avatars` em lote. Sem thumbnail, mantém iniciais/ícone.
5. Atualização gradual: fotos de conversas recentes e nomes ausentes por lote para não travar a Edge Function.

## Implantação
1. Aplicar `supabase/migrations/20261031050000_atendimento_grupos_arquivo_avatares.sql` antes de atualizar a Edge.
2. Atualizar Edge **`atendimento`** usando `docs/edge-atendimento-v0189-index-unico.ts` para editor Supabase (inclui `core` e `providers`). Preservar `Verify JWT = OFF` por causa dos webhooks.
3. Publicar `assets/atendimento.js` e `assets/atendimento.css` no frontend.
4. Abrir cada instância e clicar em **Buscar conversas e grupos** para atualizar dados atuais. A importação não apaga histórico.
5. Testar grupo com nome e sem nome, contato com foto privada/sem foto, arquivar e desarquivar, checkbox de instâncias distintas, usuário sem acesso a outro workspace, permissão do administrador, e atualização por Realtime.

## Limitações
- A foto nem sempre é disponibilizada pelo WhatsApp/Evolution, dependendo das configurações de privacidade.
- Grupos em que a API não entrega `subject` nem os detalhes continuam com o identificador até a sincronização obter metadados confiáveis.
- Arquivamento não é espelhado automaticamente do aplicativo WhatsApp; o checkbox representa a lista operacional no Growth V2.
- Sem exclusões de conversas e sem alteração de mensagens existentes.
