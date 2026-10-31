# Growth V2 v0.188 — Mídias no Atendimento

## Funcionalidades
- **Recebimento:** imagens JPEG, PNG e WebP, áudio OGG/Opus, MP3, MP4/M4A e WebM, vídeo MP4 e documentos PDF. Áudio e vídeo com players HTML5; imagens em miniatura, com clique para ampliar dentro da interface.
- **Envio:** anexar arquivos e enviar sem exigir texto ou legenda, com limite de 8 MB por arquivo. O envio existente de texto e notas internas permanece.
- **Microfone:** `MediaRecorder` no navegador, gravar, parar, descartar e enviar. Disponível em contexto HTTPS com permissão do usuário. A gravação preserva o formato aceito pelo navegador; quando não é OGG/Opus mono, pode aparecer como áudio comum e não como nota de voz nativa do WhatsApp.
- **Segurança:** Supabase Storage `atendimento` continua privado. A Edge gera URL assinada por 300 segundos para reprodução/visualização após validar workspace e a permissão. Não publicar o bucket.
- **Recebimento WhatsApp Cloud:** endpoint autenticado `GET /v1/whatsapp/media/{mediaId}?accountId=...` pela Zernio com `ZERNIO_API_KEY`, download em streaming limitado a 8 MB.
- **Zernio envio:** `POST /v1/media/upload-direct` em multipart para URL pública temporária (até 7 dias), depois `POST /v1/inbox/conversations/{id}/messages` com `attachmentUrl`/`attachmentType`.
- **Evolution envio:** `/message/sendMedia/{instance}` e, para gravação de áudio sem legenda, `/message/sendWhatsAppAudio/{instance}`.
- **Imagens históricas:** anexos pendentes mostram botão Recuperar; após baixados para Storage exibem preview.
- **Áudios existentes:** MIME `audio/ogg; codecs=opus` é reconhecido no player. Se o navegador não suportar o codec, manter download como alternativa.

## Arquivos
- `assets/atendimento.js`: UI, `MediaRecorder`, preview assinado, player, modal de ampliação.
- `assets/atendimento.css`: media queries e estilos dos anexos.
- `supabase/functions/atendimento/core.ts`: normalização de anexos recebidos.
- `supabase/functions/atendimento/providers.ts`: envio específico Evolution e Zernio.
- `supabase/functions/atendimento/index.ts`: URLs de visualização, recebimento e envio de mídia.
- `docs/edge-atendimento-v0188-index-unico.ts`: versão consolidada **sem imports locais**, destinada ao editor Supabase.

## Publicação
1. Atualizar a função **atendimento** no Supabase com `docs/edge-atendimento-v0188-index-unico.ts` (substituir `index.ts` inteiro). Manter **Verify JWT OFF** para webhooks; autenticação e assinatura são conferidas no próprio código.
2. Publicar o frontend `assets/atendimento.js` e `assets/atendimento.css` na Cloudflare.
3. Testar por provedor: receber/enviar JPEG, receber/enviar OGG/Opus e gravar áudio em Chrome/Edge e Safari, anexos pendentes, expiração de URL, usuário de outro workspace, limite 8 MB, envio sem legenda e com legenda.
4. O recebimento **em tempo real** de novas mensagens Instagram depende da configuração de webhook Zernio investigada separadamente. Esta versão não a conserta automaticamente.
5. Sem alterações SQL nesta etapa.

## Limitações
- Áudios OGG/Opus exigem suporte do navegador para reprodução. Sem codec, usar download.
- OGG/Opus mono é requerido para nota de voz WhatsApp nativa; áudio WebM pode ser enviado como anexo de áudio.
- WhatsApp oficial limita imagens a 5 MB e possui janelas/regras de envio próprias; tentativas fora dos limites recebem erro do provedor.
- Não ativar sincronização automática nem declarar homologação real sem testes no canal.
