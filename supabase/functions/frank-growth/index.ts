// Edge única do Frank: administração de identidades, escopos por workspace e ações no Growth.
// A interface usa JWT Supabase; a VPS usa x-frank-growth-key. O gateway não valida JWT
// para esta função, então os dois caminhos são autenticados explicitamente abaixo.
import { createClient } from 'jsr:@supabase/supabase-js@2';

type Obj = Record<string, unknown>;
type Workspace = { id: string; nome: string; agencia?: boolean; inativo_em?: string | null; casa_de?: string | null; contrato_origem_id?: string | null };
type Integration = { id: string; agencia_workspace_id: string; nome: string; token_hash: string; escopos: string[]; ativo: boolean };
class HttpErro extends Error { constructor(readonly status: number, message: string) { super(message); } }

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type, x-frank-growth-key', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Max-Age': '86400' };
const json = (body: Obj, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' } });
const texto = (v: unknown, max = 500) => typeof v === 'string' ? v.trim().slice(0, max) : '';
const uuidValido = (v: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
const escoposValidos = new Set(['growth:consultar', 'campanha:criar', 'tarefas:gerenciar']);
const normaliza = (s: string) => s.normalize('NFKC').trim().toLocaleLowerCase('pt-BR');
const nomeValido = (s: string) => s.length >= 1 && s.length <= 100;
const hex = (b: Uint8Array) => Array.from(b, x => x.toString(16).padStart(2, '0')).join('');
async function sha256(s: string) { return hex(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))); }
function novoToken() { return 'fg_' + hex(crypto.getRandomValues(new Uint8Array(32))); }
async function idDeterministico(escopo: string, chave: string) {
  const b = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`frank-growth:${escopo}:${chave}`))).slice(0, 16);
  b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
  const h = hex(b); return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}
function numero(v: unknown, nome: string, inteiro = false): number | null {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0 || (inteiro && !Number.isInteger(n))) throw new HttpErro(400, `${nome} precisa ser um número válido e não negativo.`);
  return n;
}
function dataIso(v: unknown, nome: string): string | null {
  if (v === undefined || v === null || v === '') return null;
  const s = texto(v, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) throw new HttpErro(400, `${nome} deve estar no formato AAAA-MM-DD.`);
  try { if (new Date(`${s}T00:00:00Z`).toISOString().slice(0, 10) !== s) throw new Error(); }
  catch { throw new HttpErro(400, `${nome} deve ser uma data válida no formato AAAA-MM-DD.`); }
  return s;
}
function erroDb(e: unknown): never {
  console.error('[frank-growth] falha no banco:', e instanceof Error ? e.message : 'erro desconhecido');
  throw new HttpErro(500, 'Não foi possível concluir a operação no Growth. Confira os dados e tente novamente.');
}
function listaEscopos(v: unknown, padrao = ['growth:consultar']) {
  const s = Array.isArray(v) ? [...new Set(v.map(x => texto(x, 40)))] : padrao;
  if (!s.length || s.some(x => !escoposValidos.has(x))) throw new HttpErro(400, 'Escopos inválidos. Use growth:consultar, campanha:criar e/ou tarefas:gerenciar.');
  return s;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, erro: 'Use POST.' }, 405);
  if (!(req.headers.get('content-type') || '').toLowerCase().startsWith('application/json')) return json({ ok: false, erro: 'Envie application/json.' }, 415);

  try {
    const raw = await req.text();
    if (new TextEncoder().encode(raw).byteLength > 32768) throw new HttpErro(413, 'Pedido maior que o limite de 32 KB.');
    let body: Obj;
    try { body = JSON.parse(raw) as Obj; } catch { throw new HttpErro(400, 'JSON inválido.'); }
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpErro(400, 'O corpo deve ser um objeto JSON.');

    const url = Deno.env.get('SUPABASE_URL') || '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    if (!url || !serviceKey) throw new HttpErro(503, 'A Edge não está configurada no Supabase.');
    const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
    const acao = texto(body.acao, 50);
    const key = texto(req.headers.get('x-frank-growth-key'), 150);
    let integracao: Integration | null = null;
    let userId: string | null = null;

    if (key) {
      const hash = await sha256(key);
      const r = await db.from('frank_growth_integracoes').select('id,agencia_workspace_id,nome,token_hash,escopos,ativo')
        .eq('token_hash', hash).eq('ativo', true).maybeSingle();
      if (r.error) erroDb(r.error);
      if (!r.data) throw new HttpErro(401, 'Credencial de integração inválida ou revogada.');
      integracao = r.data as Integration;
      await db.from('frank_growth_integracoes').update({ ultimo_uso_em: new Date().toISOString() }).eq('id', integracao.id);
    } else {
      const auth = req.headers.get('Authorization') || '';
      const jwt = auth.match(/^Bearer\s+(.+)$/i)?.[1] || '';
      const publicKey = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_PUBLISHABLE_KEY') || '';
      if (!jwt || !publicKey) throw new HttpErro(401, 'Sessão do Growth ausente ou inválida.');
      const userClient = createClient(url, publicKey, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: `Bearer ${jwt}` } } });
      const authUser = await userClient.auth.getUser(jwt);
      if (authUser.error || !authUser.data.user) throw new HttpErro(401, 'Sessão do Growth expirada. Entre novamente.');
      userId = authUser.data.user.id;
    }

    async function workspaceAgency(agencyId: string): Promise<Workspace> {
      if (!uuidValido(agencyId)) throw new HttpErro(400, 'agencia_workspace_id inválido.');
      const r = await db.from('workspaces').select('id,nome,agencia').eq('id', agencyId).maybeSingle();
      if (r.error) erroDb(r.error);
      if (!r.data || r.data.agencia !== true) throw new HttpErro(403, 'O workspace informado não é uma agência autorizada.');
      return r.data as Workspace;
    }

    async function exigeAdminMathisa(agencyId: string) {
      if (!userId) throw new HttpErro(401, 'Esta operação exige uma sessão do Growth.');
      await workspaceAgency(agencyId);
      const r = await db.from('workspace_membros').select('papel').eq('workspace_id', agencyId).eq('user_id', userId).maybeSingle();
      if (r.error) erroDb(r.error);
      if (!r.data || r.data.papel !== 'admin') throw new HttpErro(403, 'Somente administradores da agência podem gerenciar integrações do Frank.');
    }

    async function clientesDaAgencia(agencyId: string, incluirAgencia = false): Promise<Workspace[]> {
      const agency = await workspaceAgency(agencyId);
      const { data: contratos, error } = await db.from('contratos').select('id,cliente_workspace_id')
        .eq('workspace_id', agencyId).not('cliente_workspace_id', 'is', null).limit(1000);
      if (error) erroDb(error);
      const contratoPorCliente = new Map<string, string>();
      for (const c of contratos || []) if (c.cliente_workspace_id) contratoPorCliente.set(c.cliente_workspace_id, c.id);
      const ids = [...contratoPorCliente.keys()];
      let clientes: Workspace[] = [];
      if (ids.length) {
        const w = await db.from('workspaces').select('id,nome,agencia,inativo_em,casa_de,contrato_origem_id')
          .in('id', ids).eq('agencia', false).is('inativo_em', null).is('casa_de', null).limit(1000);
        if (w.error) erroDb(w.error);
        clientes = (w.data || []).filter((x: Workspace) => x.contrato_origem_id && contratoPorCliente.get(x.id) === x.contrato_origem_id) as Workspace[];
      }
      return incluirAgencia ? [{ id: agency.id, nome: agency.nome, agencia: true }, ...clientes] : clientes;
    }

    async function workspacesPermitidos(intg: Integration): Promise<Workspace[]> {
      const g = await db.from('frank_growth_integracao_workspaces').select('workspace_id').eq('integracao_id', intg.id);
      if (g.error) erroDb(g.error);
      const ids = [...new Set((g.data || []).map((x: Obj) => String(x.workspace_id)))];
      if (!ids.length) return [];
      const all = await clientesDaAgencia(intg.agencia_workspace_id, true);
      return all.filter(w => ids.includes(w.id));
    }

    async function workspaceDaIntegracao(): Promise<Workspace> {
      if (!integracao) throw new HttpErro(401, 'Credencial de integração ausente.');
      const allowed = await workspacesPermitidos(integracao);
      const id = texto(body.workspace_id, 80), nome = texto(body.cliente, 160);
      if (!id && !nome) throw new HttpErro(400, 'Informe workspace_id ou cliente.');
      if (id && !uuidValido(id)) throw new HttpErro(400, 'workspace_id inválido.');
      const matches = allowed.filter(w => id ? w.id === id : normaliza(w.nome) === normaliza(nome));
      if (!id && matches.length > 1) throw new HttpErro(409, `Cliente ambíguo; informe workspace_id. Opções: ${matches.map(w => `${w.nome} (${w.id})`).join(', ')}`);
      if (!matches[0]) throw new HttpErro(403, 'Este usuário de integração não tem acesso a esse cliente.');
      return matches[0];
    }

    async function projetoDosAgentes(workspaceId: string): Promise<Obj> {
      const atual = await db.from('projetos').select('id,nome,status').eq('workspace_id', workspaceId).eq('pipeline_agentes', true).maybeSingle();
      if (atual.error) erroDb(atual.error);
      if (atual.data) return atual.data;
      const novo = await db.from('projetos').insert({ workspace_id: workspaceId, nome: 'Pipeline dos agentes', descricao: 'Tarefas criadas e acompanhadas pelo Frank e pelo time de agentes.', pipeline_agentes: true })
        .select('id,nome,status').single();
      if (!novo.error) return novo.data;
      if (novo.error.code !== '23505') erroDb(novo.error);
      const concorrente = await db.from('projetos').select('id,nome,status').eq('workspace_id', workspaceId).eq('pipeline_agentes', true).single();
      if (concorrente.error) erroDb(concorrente.error);
      return concorrente.data;
    }

    // Gestão dos usuários de sistema pela interface de Integrações.
    const acoesAdmin = new Set(['integracoes_listar', 'integracao_criar', 'integracao_atualizar', 'integracao_acessos_salvar', 'integracao_rotacionar', 'integracao_revogar']);
    if (acoesAdmin.has(acao)) {
      const agencyId = texto(body.agencia_workspace_id, 80);
      await exigeAdminMathisa(agencyId);
      if (acao === 'integracoes_listar') {
        const r = await db.from('frank_growth_integracoes').select('id,nome,token_prefix,escopos,ativo,criado_em,atualizado_em,ultimo_uso_em,rotacionado_em,revogado_em')
          .eq('agencia_workspace_id', agencyId).order('criado_em', { ascending: false });
        if (r.error) erroDb(r.error);
        const workspaceOptions = await clientesDaAgencia(agencyId, true);
        const rows = r.data || [];
        const grants = rows.length ? await db.from('frank_growth_integracao_workspaces').select('integracao_id,workspace_id').in('integracao_id', rows.map((x: Obj) => x.id)) : { data: [], error: null };
        if (grants.error) erroDb(grants.error);
        const ids = [...new Set((grants.data || []).map((x: Obj) => String(x.workspace_id)))];
        const ws = ids.length ? await db.from('workspaces').select('id,nome,agencia,inativo_em').in('id', ids) : { data: [], error: null };
        if (ws.error) erroDb(ws.error);
        const nomes = new Map((ws.data || []).map((x: Obj) => [x.id, { id: x.id, nome: x.nome, agencia: x.agencia, inativo: !!x.inativo_em }]));
        return json({ ok: true, workspace_options: workspaceOptions.map(w => ({ id: w.id, nome: w.nome, agencia: !!w.agencia })),
          integracoes: rows.map((x: Obj) => ({ ...x, workspaces: (grants.data || []).filter((g: Obj) => g.integracao_id === x.id).map((g: Obj) => nomes.get(g.workspace_id)).filter(Boolean) })) });
      }
      const id = texto(body.integracao_id, 80);
      if (id && !uuidValido(id)) throw new HttpErro(400, 'integracao_id inválido.');
      const atual = id ? await db.from('frank_growth_integracoes').select('id').eq('id', id).eq('agencia_workspace_id', agencyId).maybeSingle() : null;
      if (atual?.error) erroDb(atual.error);
      if (id && !atual?.data) throw new HttpErro(404, 'Integração não encontrada nessa agência.');
      if (acao === 'integracao_criar') {
        const nome = texto(body.nome, 100), escopos = listaEscopos(body.escopos);
        if (!nomeValido(nome)) throw new HttpErro(400, 'Informe um nome de 1 a 100 caracteres.');
        const workspaceIds = await validarAcessos(agencyId, body.workspace_ids, clientesDaAgencia);
        if (!workspaceIds.length) throw new HttpErro(400, 'Selecione ao menos um workspace permitido.');
        const token = novoToken(), token_hash = await sha256(token), token_prefix = `${token.slice(0, 11)}…`;
        const created = await db.from('frank_growth_integracoes').insert({ agencia_workspace_id: agencyId, nome, token_hash, token_prefix, escopos, criado_por: userId }).select('id').single();
        if (created.error) erroDb(created.error);
        const grants = workspaceIds.map(workspace_id => ({ integracao_id: created.data.id, workspace_id }));
        const saved = await db.from('frank_growth_integracao_workspaces').insert(grants);
        if (saved.error) { await db.from('frank_growth_integracoes').delete().eq('id', created.data.id); erroDb(saved.error); }
        return json({ ok: true, integracao_id: created.data.id, token, token_prefix, aviso: 'Copie agora. O token completo não será exibido novamente.' }, 201);
      }
      if (acao === 'integracao_atualizar') {
        const nome = texto(body.nome, 100), escopos = listaEscopos(body.escopos);
        if (!nomeValido(nome)) throw new HttpErro(400, 'Informe um nome de 1 a 100 caracteres.');
        const r = await db.from('frank_growth_integracoes').update({ nome, escopos, atualizado_em: new Date().toISOString() }).eq('id', id).eq('agencia_workspace_id', agencyId);
        if (r.error) erroDb(r.error);
        return json({ ok: true });
      }
      if (acao === 'integracao_acessos_salvar') {
        const workspaceIds = await validarAcessos(agencyId, body.workspace_ids, clientesDaAgencia);
        const del = await db.from('frank_growth_integracao_workspaces').delete().eq('integracao_id', id);
        if (del.error) erroDb(del.error);
        if (workspaceIds.length) {
          const ins = await db.from('frank_growth_integracao_workspaces').insert(workspaceIds.map(workspace_id => ({ integracao_id: id, workspace_id })));
          if (ins.error) erroDb(ins.error);
        }
        return json({ ok: true, workspaces_autorizados: workspaceIds.length });
      }
      if (acao === 'integracao_revogar') {
        const r = await db.from('frank_growth_integracoes').update({ ativo: false, revogado_em: new Date().toISOString(), atualizado_em: new Date().toISOString() }).eq('id', id).eq('agencia_workspace_id', agencyId);
        if (r.error) erroDb(r.error);
        return json({ ok: true });
      }
      if (acao === 'integracao_rotacionar') {
        const token = novoToken(), now = new Date().toISOString();
        const r = await db.from('frank_growth_integracoes').update({ token_hash: await sha256(token), token_prefix: `${token.slice(0, 11)}…`, ativo: true, revogado_em: null, rotacionado_em: now, atualizado_em: now })
          .eq('id', id).eq('agencia_workspace_id', agencyId);
        if (r.error) erroDb(r.error);
        return json({ ok: true, token, aviso: 'O token anterior foi invalidado. Copie o novo agora; ele não será exibido novamente.' });
      }
    }

    // Ações operacionais: somente uma identidade de máquina com escopo explícito.
    if (!integracao) throw new HttpErro(401, 'Envie x-frank-growth-key para ações do Frank.');
    if (['tarefas_listar', 'tarefa_criar', 'tarefa_atualizar'].includes(acao)) {
      if (!integracao.escopos.includes('tarefas:gerenciar')) throw new HttpErro(403, 'Esta integração não tem o escopo tarefas:gerenciar.');
      const ws = await workspaceDaIntegracao();
      const projeto = await projetoDosAgentes(ws.id);
      if (acao === 'tarefas_listar') {
        const r = await db.from('projeto_atividades').select('id,titulo,descricao,status,prazo,agente_id,hermes_tarefa_id,hermes_resumo,criado_em,atualizado_em,concluida_em')
          .eq('workspace_id', ws.id).eq('projeto_id', projeto.id).order('criado_em', { ascending: false }).limit(500);
        if (r.error) erroDb(r.error);
        return json({ ok: true, workspace: { id: ws.id, nome: ws.nome }, projeto, tarefas: r.data || [] });
      }
      const hermesId = texto(body.hermes_tarefa_id, 80);
      if (!/^t_[A-Za-z0-9_-]{1,78}$/.test(hermesId)) throw new HttpErro(400, 'Informe hermes_tarefa_id válido (t_...).');
      if (acao === 'tarefa_criar') {
        const titulo = texto(body.titulo, 180), agenteId = texto(body.agente_id, 60).toLowerCase();
        if (!titulo) throw new HttpErro(400, 'Informe o título da tarefa.');
        if (!/^[a-z][a-z0-9_-]{0,59}$/.test(agenteId)) throw new HttpErro(400, 'Informe agente_id válido.');
        const existente = await db.from('projeto_atividades').select('id,projeto_id,titulo,descricao,status,prazo,agente_id,hermes_tarefa_id,hermes_resumo').eq('workspace_id', ws.id).eq('hermes_tarefa_id', hermesId).maybeSingle();
        if (existente.error) erroDb(existente.error);
        if (existente.data) {
          if (existente.data.projeto_id !== projeto.id || existente.data.titulo !== titulo || existente.data.agente_id !== agenteId) throw new HttpErro(409, 'ID do Hermes já vinculado a outra tarefa.');
          return json({ ok: true, replay: true, projeto, tarefa: existente.data });
        }
        const ordemR = await db.from('projeto_atividades').select('ordem').eq('projeto_id', projeto.id).order('ordem', { ascending: false }).limit(1);
        if (ordemR.error) erroDb(ordemR.error);
        const criado = await db.from('projeto_atividades').insert({ workspace_id: ws.id, projeto_id: projeto.id, titulo, descricao: texto(body.descricao, 5000) || null,
          agente_id: agenteId, hermes_tarefa_id: hermesId, prazo: dataIso(body.prazo, 'prazo'), ordem: Number(ordemR.data?.[0]?.ordem || 0) + 1 })
          .select('id,titulo,descricao,status,prazo,agente_id,hermes_tarefa_id,hermes_resumo').single();
        if (criado.error) {
          if (criado.error.code !== '23505') erroDb(criado.error);
          const repetida = await db.from('projeto_atividades').select('id,projeto_id,titulo,descricao,status,prazo,agente_id,hermes_tarefa_id,hermes_resumo').eq('workspace_id', ws.id).eq('hermes_tarefa_id', hermesId).single();
          if (repetida.error) erroDb(repetida.error);
          if (repetida.data.projeto_id !== projeto.id || repetida.data.titulo !== titulo || repetida.data.agente_id !== agenteId) throw new HttpErro(409, 'ID do Hermes já vinculado a outra tarefa.');
          return json({ ok: true, replay: true, projeto, tarefa: repetida.data });
        }
        return json({ ok: true, replay: false, projeto, tarefa: criado.data }, 201);
      }
      const novoStatus = texto(body.status, 30);
      if (!['liberada', 'em_andamento', 'concluida', 'cancelada'].includes(novoStatus)) throw new HttpErro(400, 'Status inválido.');
      const tarefa = await db.from('projeto_atividades').select('id,status').eq('workspace_id', ws.id).eq('projeto_id', projeto.id).eq('hermes_tarefa_id', hermesId).maybeSingle();
      if (tarefa.error) erroDb(tarefa.error);
      if (!tarefa.data) throw new HttpErro(404, 'Tarefa do Hermes não encontrada nesta pipeline.');
      const resumo = texto(body.resumo, 5000);
      if (tarefa.data.status === novoStatus && !resumo) return json({ ok: true, replay: true, tarefa: tarefa.data });
      const atualizado = await db.from('projeto_atividades').update({ status: novoStatus, ...(resumo ? { hermes_resumo: resumo } : {}) }).eq('id', tarefa.data.id).eq('workspace_id', ws.id)
        .select('id,titulo,status,agente_id,hermes_tarefa_id,hermes_resumo,atualizado_em,concluida_em').single();
      if (atualizado.error) erroDb(atualizado.error);
      return json({ ok: true, replay: false, tarefa: atualizado.data });
    }
    if (acao === 'clientes' || acao === 'contexto') {
      if (!integracao.escopos.includes('growth:consultar')) throw new HttpErro(403, 'Esta integração não tem o escopo growth:consultar.');
      if (acao === 'clientes') {
        const clientes = await workspacesPermitidos(integracao);
        return json({ ok: true, clientes: clientes.map(w => ({ id: w.id, nome: w.nome, tipo: w.agencia ? 'agencia' : 'cliente' })) });
      }
      const ws = await workspaceDaIntegracao();
      const [produtosR, funisR, modelosR, equipeR] = await Promise.all([
        db.from('produtos').select('id,nome,tipo,preco,ativo').eq('workspace_id', ws.id).eq('ativo', true).order('nome').limit(200),
        db.from('funis').select('id,nome,tipo,produto_id,descricao,ativo').eq('workspace_id', ws.id).eq('ativo', true).order('nome').limit(200),
        db.from('projeto_modelos').select('id,nome,descricao,padrao_campanha').eq('workspace_id', ws.id).eq('ativo', true).order('nome').limit(100),
        db.from('equipe').select('id,nome,funcao,ativo').eq('workspace_id', ws.id).eq('ativo', true).order('nome').limit(300),
      ]);
      for (const r of [produtosR, funisR, modelosR, equipeR]) if (r.error) erroDb(r.error);
      const funilId = texto(body.funil_id, 80), produtoId = texto(body.produto_id, 80);
      if (funilId && !(funisR.data || []).some((x: Obj) => x.id === funilId)) throw new HttpErro(403, 'Estratégia fora do workspace autorizado.');
      if (produtoId && !(produtosR.data || []).some((x: Obj) => x.id === produtoId)) throw new HttpErro(403, 'Produto fora do workspace autorizado.');
      const modelos = modelosR.data || [], idsModelos = modelos.map((x: Obj) => x.id as string);
      let atividades: Obj[] = [];
      if (idsModelos.length) {
        const r = await db.from('projeto_modelo_atividades').select('id,modelo_id,pai_id,titulo,funcao,responsavel_id,ordem,depende_de,prazo_dias')
          .eq('workspace_id', ws.id).in('modelo_id', idsModelos).order('ordem');
        if (r.error) erroDb(r.error); atividades = r.data || [];
      }
      let historicoQ = db.from('campanhas').select('orcamento_total,meta_leads,meta_vendas,meta_receita,meta_cac,data_inicio')
        .eq('workspace_id', ws.id).in('status', ['planejada', 'ativa', 'finalizada']).order('data_inicio', { ascending: false, nullsFirst: false }).limit(50);
      if (funilId) historicoQ = historicoQ.eq('funil_id', funilId);
      if (produtoId) historicoQ = historicoQ.eq('produto_id', produtoId);
      const hist = await historicoQ; if (hist.error) erroDb(hist.error);
      const metricas = ['orcamento_total', 'meta_leads', 'meta_vendas', 'meta_receita', 'meta_cac'];
      const medias: Obj = {};
      for (const campo of metricas) {
        const vals = (hist.data || []).map((c: Obj) => Number(c[campo])).filter(Number.isFinite);
        medias[campo] = { media: vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length * 100) / 100 : null, amostra: vals.length };
      }
      return json({ ok: true, workspace: { id: ws.id, nome: ws.nome }, produtos: produtosR.data || [], estrategias: funisR.data || [],
        modelos_de_tarefas: modelos.map((x: Obj) => ({ ...x, atividades: atividades.filter(a => a.modelo_id === x.id) })), equipe: equipeR.data || [],
        referencias_historicas: { campanhas: hist.data?.length || 0, suficientes: (hist.data?.length || 0) >= 3, metricas: medias } });
    }

    if (acao === 'criar_campanha') {
      if (!integracao.escopos.includes('campanha:criar')) throw new HttpErro(403, 'Esta integração não tem o escopo campanha:criar.');
      if (body.confirmado !== true) throw new HttpErro(409, 'A criação exige confirmado=true após a aprovação do plano no Telegram.');
      const requestId = texto(body.request_id, 100);
      if (!/^[a-zA-Z0-9_-]{8,100}$/.test(requestId)) throw new HttpErro(400, 'request_id obrigatório (8 a 100 caracteres) para evitar duplicidades.');
      const ws = await workspaceDaIntegracao(), nome = texto(body.nome, 180), tema = texto(body.tema, 300);
      if (!nome) throw new HttpErro(400, 'Informe o nome da campanha.');
      const modelo = texto(body.modelo, 20) || 'lancamento';
      if (!['lancamento', 'perpetuo'].includes(modelo)) throw new HttpErro(400, 'modelo deve ser lancamento ou perpetuo.');
      const inicio = dataIso(body.data_inicio, 'data_inicio'), fim = dataIso(body.data_fim, 'data_fim');
      if (modelo === 'lancamento' && !inicio) throw new HttpErro(400, 'Informe a data_inicio do lançamento.');
      if (modelo === 'perpetuo' && fim) throw new HttpErro(400, 'Campanha perpétua não deve ter data_fim.');
      if (inicio && fim && fim < inicio) throw new HttpErro(400, 'data_fim não pode ser anterior a data_inicio.');
      const funilId = texto(body.funil_id, 80), produtoId = texto(body.produto_id, 80), modeloId = texto(body.projeto_modelo_id, 80);
      if (!uuidValido(funilId) || !uuidValido(modeloId) || (produtoId && !uuidValido(produtoId))) throw new HttpErro(400, 'Selecione IDs válidos para estratégia, modelo de tarefas e produto.');
      const [funilR, produtoR, modeloR, equipeR] = await Promise.all([
        db.from('funis').select('id,nome').eq('id', funilId).eq('workspace_id', ws.id).eq('ativo', true).maybeSingle(),
        produtoId ? db.from('produtos').select('id,nome').eq('id', produtoId).eq('workspace_id', ws.id).eq('ativo', true).maybeSingle() : Promise.resolve({ data: null, error: null }),
        db.from('projeto_modelos').select('id,nome').eq('id', modeloId).eq('workspace_id', ws.id).eq('ativo', true).maybeSingle(),
        db.from('equipe').select('id,nome,funcao,ativo,criado_em').eq('workspace_id', ws.id).eq('ativo', true).order('criado_em').limit(500),
      ]);
      for (const r of [funilR, produtoR, modeloR, equipeR]) if (r.error) erroDb(r.error);
      if (!funilR.data || (produtoId && !produtoR.data) || !modeloR.data) throw new HttpErro(400, 'Estratégia, produto ou modelo inativo ou fora do workspace autorizado.');
      const tarefasR = await db.from('projeto_modelo_atividades').select('id,pai_id,titulo,funcao,responsavel_id')
        .eq('workspace_id', ws.id).eq('modelo_id', modeloId).order('ordem');
      if (tarefasR.error) erroDb(tarefasR.error);
      const tarefas = tarefasR.data || [];
      if (!tarefas.length) throw new HttpErro(400, 'O modelo de tarefas está vazio.');
      const pais = new Set(tarefas.map((t: Obj) => t.pai_id).filter(Boolean)), equipe = equipeR.data || [];
      const equipeAtiva = new Set(equipe.map((x: Obj) => x.id));
      const semResp = tarefas.filter((t: Obj) => !pais.has(t.id) && (t.responsavel_id
        ? !equipeAtiva.has(t.responsavel_id)
        : !t.funcao || !equipe.some((x: Obj) => normaliza(String(x.funcao || '')) === normaliza(String(t.funcao)))));
      if (semResp.length) throw new HttpErro(422, `O modelo tem atividade sem responsável ativo: ${semResp.map((x: Obj) => texto(x.titulo, 100)).join('; ')}.`);
      const data: Obj = {
        workspace_id: ws.id, nome, status: 'rascunho', modelo, data_inicio: inicio, data_fim: fim, produto_id: produtoId || null, funil_id: funilId,
        orcamento_total: numero(body.orcamento_total, 'orcamento_total'), meta_leads: numero(body.meta_leads, 'meta_leads', true),
        meta_vendas: numero(body.meta_vendas, 'meta_vendas', true), meta_taxa_lead_venda: numero(body.meta_taxa_lead_venda, 'meta_taxa_lead_venda'),
        meta_receita: numero(body.meta_receita, 'meta_receita'), meta_cac: numero(body.meta_cac, 'meta_cac'),
        observacoes: [`Solicitação confirmada via Frank (${integracao.nome}) · ${requestId}`, texto(body.observacoes, 2200), tema ? `Tema: ${tema}` : ''].filter(Boolean).join('\n'),
        projeto_auto: true, projeto_modelo_id: modeloId,
      };
      const campanhaId = await idDeterministico(ws.id, `${integracao.id}:${requestId}`);
      const cols = 'id,workspace_id,nome,status,modelo,data_inicio,data_fim,produto_id,funil_id,orcamento_total,meta_leads,meta_vendas,meta_taxa_lead_venda,meta_receita,meta_cac,observacoes,projeto_auto,projeto_modelo_id';
      const created = await db.from('campanhas').insert({ id: campanhaId, ...data }).select(cols).single();
      let campanha: Obj, replay = false;
      if (created.error) {
        if (created.error.code !== '23505') erroDb(created.error);
        const prior = await db.from('campanhas').select(cols).eq('id', campanhaId).eq('workspace_id', ws.id).maybeSingle();
        if (prior.error) erroDb(prior.error);
        if (!prior.data) erroDb(created.error);
        if (!Object.entries(data).every(([k, v]) => (prior.data as Obj)[k] === v)) throw new HttpErro(409, 'request_id já usado por outra solicitação. Gere um novo request_id.');
        campanha = prior.data as Obj; replay = true;
      } else campanha = created.data as Obj;
      const projeto = await db.from('projetos').select('id,nome,status').eq('workspace_id', ws.id).eq('campanha_id', campanhaId).maybeSingle();
      if (projeto.error) erroDb(projeto.error);
      let atividades: Obj[] = [];
      if (projeto.data) {
        const ar = await db.from('projeto_atividades').select('id,titulo,status,responsavel_id,funcao,ordem').eq('workspace_id', ws.id).eq('projeto_id', projeto.data.id).order('ordem').limit(300);
        if (ar.error) erroDb(ar.error);
        const ids = [...new Set((ar.data || []).map((x: Obj) => x.responsavel_id).filter(Boolean))] as string[];
        const er = ids.length ? await db.from('equipe').select('id,nome').eq('workspace_id', ws.id).in('id', ids) : { data: [], error: null };
        if (er.error) erroDb(er.error);
        const nomes = new Map((er.data || []).map((x: Obj) => [x.id, x.nome]));
        atividades = (ar.data || []).map((x: Obj) => ({ ...x, responsavel_nome: x.responsavel_id ? nomes.get(x.responsavel_id) || null : null }));
      }
      return json({ ok: true, replay, campanha, projeto: projeto.data || null, atividades, total_atividades: atividades.length });
    }
    throw new HttpErro(400, 'Ação inválida.');
  } catch (e) {
    if (e instanceof HttpErro) return json({ ok: false, erro: e.message }, e.status);
    console.error('[frank-growth] erro inesperado:', e instanceof Error ? e.message : 'erro desconhecido');
    return json({ ok: false, erro: 'Erro interno da integração Frank-Growth.' }, 500);
  }
});

async function validarAcessos(agencyId: string, value: unknown, listar: (id: string, includeAgency?: boolean) => Promise<Workspace[]>): Promise<string[]> {
  if (!Array.isArray(value) || value.some(x => typeof x !== 'string' || !uuidValido(x)) || value.length > 500) throw new HttpErro(400, 'workspace_ids deve ser uma lista de IDs válidos.');
  const chosen = [...new Set(value as string[])], permitidos = await listar(agencyId, true), permitido = new Set(permitidos.map(x => x.id));
  const fora = chosen.filter(x => !permitido.has(x));
  if (fora.length) throw new HttpErro(403, 'A lista inclui cliente inativo ou workspace fora dos contratos dessa agência.');
  return chosen;
}
