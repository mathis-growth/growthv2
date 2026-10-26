// Teste de ponta a ponta da edge function content-pesquisa contra o banco local (fa, PostgREST na 3300).
// A Claude e o Apps Script são simulados (fetch interceptado); o resto é real: autenticação, permissão, gravação e o uso de IA.
// Rodar: deno run -A --import-map=map.json teste_pesquisa.ts   (tokens em TK, uma linha cada: service_role, anon, usuário)
const WS = 'ac56e719-7325-4062-aa47-74bc2141f89d', UID = '00000000-0000-0000-0000-00000000a0a0';
const [SR, ANON, USER] = Deno.readTextFileSync(Deno.env.get('TK')!).trim().split('\n');
const sql = async (q: string) => {
  const p = new Deno.Command('psql', { args: ['-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1', '-c', q], stdout: 'piped', stderr: 'piped' });
  const o = await p.output(); if (!o.success) throw new Error(new TextDecoder().decode(o.stderr)); return new TextDecoder().decode(o.stdout).trim();
};
let falhas = 0;
const chk = (c: boolean, m: string) => { console.log((c ? 'ok   ' : 'FALHA ') + m); if (!c) falhas++; };

// proxy: /rest/v1 → PostgREST local; /auth/v1/user → o usuário da auditoria
Deno.serve({ port: 3399, onListen() {} }, async (req) => {
  const u = new URL(req.url);
  if (u.pathname.startsWith('/auth/v1/user')) return Response.json({ id: UID, email: 'auditoria@escolaaurora.com.br', aud: 'authenticated', role: 'authenticated' });
  const h = new Headers(req.headers); h.delete('host');
  const r = await fetch('http://127.0.0.1:3300' + u.pathname.replace(/^\/rest\/v1/, '') + u.search, { method: req.method, headers: h, body: ['GET', 'HEAD'].includes(req.method) ? undefined : await req.arrayBuffer() });
  return new Response(r.body, { status: r.status, headers: r.headers });
});
Deno.env.set('SUPABASE_URL', 'http://127.0.0.1:3399'); Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', SR); Deno.env.set('SUPABASE_ANON_KEY', ANON); Deno.env.set('ANTHROPIC_API_KEY', 'chave-de-teste');

// Claude e Apps Script simulados
const pedidosIA: any[] = [], pedidosScript: any[] = [];
const real = globalThis.fetch;
const SECOES = ['Diferencial', 'Mecanismo do problema', 'Mecanismo da solução', 'Construção do produto', 'Narrativa', 'Voz', 'Persona', 'Concorrência', 'Oportunidades de conteúdo'];
globalThis.fetch = (async (input: any, init?: any) => {
  const url = String(input instanceof Request ? input.url : input);
  if (url.startsWith('https://api.anthropic.com/')) {
    const b = JSON.parse(init.body); pedidosIA.push(b);
    if (init.headers['x-api-key'] !== 'chave-de-teste') return Response.json({ error: { message: 'chave' } }, { status: 401 });
    if (b.tools) return Response.json({ stop_reason: 'end_turn', usage: { input_tokens: 12000, output_tokens: 1500, server_tool_use: { web_search_requests: 3 } }, content: [
      { type: 'server_tool_use', id: 'x', name: 'web_search', input: { query: 'inglês adultos' } },
      { type: 'web_search_tool_result', tool_use_id: 'x', content: [{ type: 'web_search_result', url: 'https://exemplo.com/tendencia', title: 'Tendência de inglês para adultos' }] },
      { type: 'text', text: '## 1. Quem é o cliente\n[Fato] Escola de inglês para adultos (arquivo Apresentação).\n', citations: [{ url: 'https://exemplo.com/tendencia', title: 'Tendência de inglês para adultos' }] },
      { type: 'text', text: '## 7. O que ainda falta saber\n- Quantos alunos ativos?' }] });
    return Response.json({ stop_reason: 'end_turn', usage: { input_tokens: 5000, output_tokens: 2500 }, content: [{ type: 'text', text: JSON.stringify({ secoes: SECOES.map(t => ({ titulo: t, texto: `[Hipótese] texto de ${t}` })) }) }] });
  }
  if (url === 'https://script.teste/exec') {
    const b = JSON.parse(init.body); pedidosScript.push(b);
    if (b.acao !== 'ler') return Response.json({ ok: false, erro: 'Ação desconhecida' });
    return Response.json({ ok: true, versao: 2, pastas_com_erro: [], arquivos: [
      { id: 'a1', nome: 'Apresentação', caminho: 'Growth\'s Content › 02 Materiais do cliente › Documentos', rotulo: 'cliente', tipo: 'application/vnd.google-apps.document', lido: true, texto: 'Somos uma escola de inglês para adultos.' },
      { id: 'a2', nome: 'aula1.pdf', caminho: 'Aulas antigas', rotulo: 'cliente-extra', tipo: 'application/pdf', lido: true, pdf_base64: 'JVBERi0x' },
      { id: 'a3', nome: 'live.mp4', caminho: 'Growth\'s Content › 02 Materiais do cliente › Reuniões gravadas', rotulo: 'cliente', tipo: 'video/mp4', lido: false, motivo: 'Vídeo ou áudio: precisa da transcrição em texto' },
      { id: 'a4', nome: 'Método MIRA', caminho: 'MIRA', rotulo: 'mathisa', tipo: 'application/vnd.google-apps.document', lido: true, texto: 'Padrão: gancho, tese, prova.' }] });
  }
  return real(input, init);
}) as typeof fetch;

// dados
const cfg0 = await sql(`select coalesce(string_agg(chave || '=' || valor, '|'), '') from sistema_config where chave in ('drive_script_url', 'drive_script_senha')`);
await sql(`insert into sistema_config (chave, valor) values ('drive_script_url', 'https://script.teste/exec'), ('drive_script_senha', 'x') on conflict (chave) do update set valor = excluded.valor`);
const limpa = async () => {
  for (const t of ['content_dossies', 'content_pesquisas', 'content_produtos', 'conteudo_personas']) await sql(`delete from ${t} where workspace_id = '${WS}'`);
  await sql(`delete from ia_uso where workspace_id = '${WS}'`); await sql(`delete from content_pastas_mathisa where nome like 'T151 %'`);
  await sql(`delete from workspaces where nome like 'T151 %'`);
  await sql(`update workspaces set content_drive_id = null, content_fontes = '{}' where id = '${WS}'`);
};
await limpa();
await sql(`update workspaces set content_drive_id = 'PASTACLIENTE1234567890', content_fontes = '{"links":[{"url":"https://drive.google.com/drive/folders/PastaExtra123456789","desc":"Aulas antigas"},{"url":"https://exemplo.com/nao-e-pasta","desc":"x"}],"canais":{"instagram":"@escolaaurora"}}' where id = '${WS}'`);
await sql(`insert into conteudo_personas (workspace_id, nome, respostas) values ('${WS}', 'Persona principal', '{"nicho":"inglês para adultos","esteira":"e-book, curso, mentoria","_call_notas":"cliente animada"}')`);
await sql(`insert into content_produtos (workspace_id, nome, valor, historico) values ('${WS}', 'Curso Base', 997, 'Três turmas')`);
await sql(`insert into content_pastas_mathisa (workspace_id, nome, pasta_id, url) values (null, 'T151 MIRA', 'PastaMathisa12345678', 'https://drive.google.com/drive/folders/PastaMathisa12345678')`);
const AG = (await sql(`insert into workspaces (nome, agencia) values ('T151 Agência', true) returning id`)).split('\n')[0];
await sql(`insert into workspace_membros (workspace_id, user_id, papel) values ('${AG}', '${UID}', 'admin')`);

await import('../../../supabase/functions/content-pesquisa/index.ts');
await new Promise(r => setTimeout(r, 500));
const F = 'http://127.0.0.1:8000';
const post = (o: unknown, tk?: string) => real(F, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(tk ? { Authorization: 'Bearer ' + tk } : {}) }, body: JSON.stringify(o) }).then(async r => ({ s: r.status, j: await r.json() }));
const espera = async (q: string, alvo: (v: string) => boolean) => { for (let i = 0; i < 60; i++) { const v = await sql(q); if (alvo(v)) return v; await new Promise(r => setTimeout(r, 250)); } return await sql(q); };

chk((await (await real(F)).json()).chave === true, 'GET diz se a chave da IA está configurada');
chk((await post({ acao: 'pesquisar', workspace_id: WS })).s === 401, 'sem login: recusado');
chk((await post({ acao: 'pesquisar', workspace_id: WS }, ANON)).s === 401, 'só com a chave pública: recusado');
const r1 = await post({ acao: 'pesquisar', workspace_id: WS }, USER);
chk(r1.s === 200 && !!r1.j.id, 'pesquisa pedida: responde na hora com o id');
const st = await espera(`select status from content_pesquisas where id = '${r1.j.id}'`, v => v === 'pronto' || v === 'erro');
chk(st === 'pronto', 'pesquisa termina como pronta ' + (st === 'erro' ? await sql(`select erro from content_pesquisas where id = '${r1.j.id}'`) : ''));
const ps = pedidosScript[0] || {};
chk(JSON.stringify((ps.pastas || []).map((p: any) => p.rotulo)) === '["cliente","cliente-extra","mathisa"]' && ps.pastas[1].id === 'PastaExtra123456789', 'lê a pasta do cliente, a pasta extra (link que não é pasta fica de fora) e a da Mathisa');
const pia = pedidosIA[0] || {}, blocos = pia.messages?.[0]?.content || [];
const tudo = JSON.stringify(blocos);
chk(tudo.includes('inglês para adultos') && tudo.includes('Curso Base') && tudo.includes('Três turmas') && tudo.includes('@escolaaurora') && tudo.includes('cliente animada') && !tudo.includes('_call_notas'), 'a IA recebe a call, os produtos com histórico e os canais');
chk(blocos.some((b: any) => b.type === 'document' && b.source?.media_type === 'application/pdf') && tudo.includes('[PADRÃO DA MATHISA] MIRA') && tudo.includes('[MATERIAL DO CLIENTE (outra pasta)]') && !tudo.includes('live.mp4'), 'arquivos: PDF como documento, padrão da Mathisa e material do cliente marcados, vídeo sem transcrição fora');
chk(pia.tools?.[0]?.type === 'web_search_20250305' && pia.tools[0].max_uses === 8 && pia.model === 'claude-sonnet-5-5' && String(pia.system).includes('Nunca invente'), 'busca na web ligada (8 buscas), modelo configurado e regras de não inventar');
const p = JSON.parse(await sql(`select json_build_object('rel', relatorio, 'fontes', fontes, 'arq', arquivos, 'te', tokens_entrada, 'b', buscas) from content_pesquisas where id = '${r1.j.id}'`));
chk(p.rel.includes('## 1. Quem é o cliente') && p.rel.includes('## 7.') && p.fontes.length === 1 && p.fontes[0].url === 'https://exemplo.com/tendencia', 'relatório e fontes da web gravados');
chk(p.arq.lista.length === 4 && p.arq.lista.some((a: any) => !a.lido && a.motivo.includes('transcrição')) && !JSON.stringify(p.arq).includes('JVBERi0x'), 'arquivos lidos e não lidos (com o motivo) registrados, sem guardar o conteúdo');
chk(await sql(`select tokens_entrada || '|' || buscas || '|' || coalesce(custo_usd::text, 'sem custo') || '|' || funcao from ia_uso where workspace_id = '${WS}'`) === '12000|3|sem custo|Pesquisa do cliente', 'uso de IA registrado; sem preço cadastrado, sem custo inventado');
const r2 = await post({ acao: 'dossie', pesquisa_id: r1.j.id }, USER);
chk(r2.s === 200 && !!r2.j.id, 'dossiê pedido a partir da pesquisa');
const sd = await espera(`select status from content_dossies where id = '${r2.j.id}'`, v => v === 'rascunho' || v === 'erro');
chk(sd === 'rascunho' && await sql(`select jsonb_array_length(secoes) || '|' || (secoes->0->>'titulo') || '|' || versao from content_dossies where id = '${r2.j.id}'`) === '9|Diferencial|1', 'dossiê gravado como rascunho, 9 seções, versão 1');
chk(String(JSON.stringify(pedidosIA[1]?.messages)).includes('Relatório da pesquisa') && !pedidosIA[1]?.tools, 'o dossiê parte do relatório, sem nova busca na web');
chk(await sql(`select count(*) from ia_uso where workspace_id = '${WS}'`) === '2', 'uso do dossiê também registrado');
await sql(`update ia_uso set custo_usd = null where false`);
await sql(`insert into sistema_config (chave, valor) values ('ia_precos', '{"claude-sonnet-5-5":{"entrada":3,"saida":15},"busca_mil":10}') on conflict (chave) do update set valor = excluded.valor`);
const r3 = await post({ acao: 'pesquisar', workspace_id: WS }, USER);
await espera(`select status from content_pesquisas where id = '${r3.j.id}'`, v => v === 'pronto' || v === 'erro');
chk(await sql(`select custo_usd from ia_uso where detalhe->>'pesquisa_id' = '${r3.j.id}'`) === '0.088500', 'com preço cadastrado, o custo é calculado (12 mil de entrada, 1,5 mil de saída, 3 buscas)');
await sql(`update sistema_config set valor = '{}' where chave = 'ia_precos'`);
await sql(`delete from workspace_membros where workspace_id = '${AG}'`);
const OUTRO = (await sql(`insert into workspaces (nome) values ('T151 Outro cliente') returning id`)).split('\n')[0];
chk((await post({ acao: 'pesquisar', workspace_id: OUTRO }, USER)).s === 403, 'cliente de quem a pessoa não faz parte: recusado');
await limpa();
for (const par of cfg0.split('|').filter(Boolean)) { const [k, ...v] = par.split('='); await sql(`update sistema_config set valor = '${v.join('=').replace(/'/g, "''")}' where chave = '${k}'`); }
if (!cfg0.includes('drive_script_url')) await sql(`delete from sistema_config where chave in ('drive_script_url', 'drive_script_senha')`);
console.log(`\n${falhas} falha(s)`); Deno.exit(falhas ? 1 : 0);
