// Edge function "diagnostico-arquivo" (v0.177, Diagnóstico 360° G2): o cliente envia os arquivos pelo link do diagnóstico.
// O cliente não está logado. Cada pedido traz o código do link (token), e as regras ficam no banco:
//   pesquisa_arquivo_autorizar / _caminho / _confirmar / _remover (só service_role executa), migração 20261129110000.
// Ações (POST JSON):
//   { acao: 'autorizar', token, grupo, nome, tamanho, tipo } → { ok, id, caminho, envio }  (envio = autorização de uso único
//     para sb.storage.from('diagnostico').uploadToSignedUrl(caminho, envio, arquivo))
//   { acao: 'confirmar', token, id } → { ok }   (confere que o arquivo chegou no Storage antes de marcar como enviado)
//   { acao: 'remover', token, id }   → { ok }   (tira o registro e apaga o arquivo)
// Erros de regra voltam com status 200 e { ok: false, erro } para a tela mostrar a mensagem.
// Publicar com verificação de JWT (a tela chama com a chave anônima): supabase functions deploy diagnostico-arquivo
import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } });
const BUCKET = 'diagnostico';
const RE_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, erro: 'Use POST' }, 405);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return json({ ok: false, erro: 'Pedido inválido.' }, 400); }
  const token = String(b.token || ''), acao = String(b.acao || ''), id = String(b.id || '');
  if (token.length < 32 || token.length > 200) return json({ ok: false, erro: 'Link inválido.' });
  if (acao !== 'autorizar' && !RE_UUID.test(id)) return json({ ok: false, erro: 'Arquivo inválido.' });
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
  const rpc = async (f: string, a: Record<string, unknown>) => { const { data, error } = await sb.rpc(f, a); if (error) throw new Error(error.message); return data; };
  try {
    if (acao === 'autorizar') {
      const r = await rpc('pesquisa_arquivo_autorizar', { p_token: token, p_grupo: String(b.grupo || ''), p_nome: String(b.nome || ''), p_tamanho: Number(b.tamanho) || 0, p_tipo: String(b.tipo || '') }) as { id: string; caminho: string };
      const { data, error } = await sb.storage.from(BUCKET).createSignedUploadUrl(r.caminho);
      if (error || !data) { await rpc('pesquisa_arquivo_remover', { p_token: token, p_id: r.id }); throw new Error('Não consegui preparar o envio. Tente de novo.'); }
      return json({ ok: true, id: r.id, caminho: r.caminho, envio: data.token });
    }
    if (acao === 'confirmar') {
      const cam = await rpc('pesquisa_arquivo_caminho', { p_token: token, p_id: id }) as string;
      const i = cam.lastIndexOf('/'), { data, error } = await sb.storage.from(BUCKET).list(cam.slice(0, i), { search: cam.slice(i + 1), limit: 1 });
      if (error || !data || !data.some(o => o.name === cam.slice(i + 1))) return json({ ok: false, erro: 'O arquivo não chegou. Tente enviar de novo.' });
      await rpc('pesquisa_arquivo_confirmar', { p_token: token, p_id: id });
      return json({ ok: true });
    }
    if (acao === 'remover') {
      const cam = await rpc('pesquisa_arquivo_remover', { p_token: token, p_id: id }) as string;
      await sb.storage.from(BUCKET).remove([cam]);
      return json({ ok: true });
    }
    return json({ ok: false, erro: 'Ação desconhecida.' }, 400);
  } catch (e) {
    return json({ ok: false, erro: (e as Error).message || 'Erro ao tratar o arquivo.' });
  }
});
