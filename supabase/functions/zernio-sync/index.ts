// Puxa do Zernio os posts, as métricas diárias e (v0.135) as DMs do Instagram e grava em social_posts, social_perfis_dia,
// social_conversas e social_mensagens. Quem manda DM para a conta entra no CRM (social_gravar_dms → registrar_dm_instagram).
// Chamado pelo pg_cron (header x-sync-secret): "zernio-sync-diario" (tudo, 1× por dia) e "zernio-dms" (só DMs, a cada 30 min,
// corpo {"partes":["dms"]}). A chave do Zernio fica no segredo ZERNIO_API_KEY.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const ZERNIO = "https://zernio.com/api/v1";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const dia = (offset: number) => new Date(Date.now() - offset * 86400000).toISOString().slice(0, 10);

const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));
let inicio = Date.now(); // reiniciado a cada chamada
// limite de uso do Zernio: espera o tempo que ele pedir (uma vez) se ainda houver tempo nesta rodada
async function zernio(path: string, params: Record<string, string | number>, key: string, tentativa = 0): Promise<any> {
  const qs = new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)]));
  const r = await fetch(`${ZERNIO}${path}?${qs}`, { headers: { Authorization: `Bearer ${key}` } });
  const body = await r.json().catch(() => ({}));
  if (r.status === 429 && tentativa < 2) {
    const seg = Number(r.headers.get("retry-after")) || Number(String(body?.error ?? "").match(/(\d+)\s*seconds?/)?.[1]) || 30;
    if (Date.now() - inicio + seg * 1000 < 110000) { await espera((seg + 1) * 1000); return zernio(path, params, key, tentativa + 1); }
  }
  if (!r.ok) throw new Error(`Zernio ${path} ${r.status}: ${body?.error ?? JSON.stringify(body).slice(0, 200)}`);
  return body;
}

function tipoPost(p: any) {
  const prod = String(p.mediaProductType ?? "").toUpperCase();
  if (prod === "REELS") return "reels";
  if (prod === "STORY") return "story";
  if (p.mediaType === "carousel") return "carrossel";
  if (p.mediaType === "video") return "video";
  return p.mediaType ? "imagem" : null;
}

async function posts(conta: any, desde: string, key: string) {
  const linhas: any[] = [];
  for (let page = 1; ; page++) {
    const r = await zernio("/analytics", { accountId: conta.id_externo, fromDate: desde, toDate: dia(0), limit: 50, page }, key);
    for (const p of r.posts ?? []) {
      if (p.status !== "published") continue;
      const plat = (p.platforms ?? []).find((x: any) => x.accountId === conta.id_externo) ?? {};
      const a = plat.analytics ?? p.analytics ?? {};
      linhas.push({
        id: plat.platformPostId ?? p._id,
        tipo: tipoPost(p),
        legenda: p.content ?? null,
        url: plat.platformPostUrl ?? p.platformPostUrl ?? null,
        miniatura: p.thumbnailUrl ?? null,
        publicado_em: p.publishedAt,
        alcance: a.reach ?? null,
        impressoes: a.impressions ?? null,
        visualizacoes: a.views ?? null,
        curtidas: a.likes ?? null,
        comentarios: a.comments ?? null,
        compartilhamentos: a.shares ?? null,
        salvamentos: a.saves ?? null,
        minutos_assistidos: a.igReelsVideoViewTotalTime ? Math.round(a.igReelsVideoViewTotalTime / 600) / 100 : null,
      });
    }
    if (page >= (r.pagination?.pages ?? 1)) break;
  }
  const { data, error } = await db.rpc("conexao_gravar", { p_conta: conta.id, p_tipo: "posts", p_linhas: linhas });
  if (error) throw new Error(`gravar posts: ${error.message}`);
  return data as number;
}

async function perfil(conta: any, desde: string, key: string) {
  const porDia: Record<string, any> = {};
  const linha = (d: string) => (porDia[d] ??= { data: d });
  const base = { accountId: conta.id_externo, fromDate: desde, toDate: dia(0), metricType: "time_series" };

  const seg = await zernio("/analytics/instagram/follower-history", { ...base, metrics: "follower_count,followers_gained,followers_lost" }, key);
  for (const v of seg.metrics?.follower_count?.values ?? []) linha(v.date.slice(0, 10)).seguidores = v.value;
  for (const v of seg.metrics?.followers_gained?.values ?? []) linha(v.date.slice(0, 10)).seguidores_ganhos = v.value;

  // o histórico só existe a partir de quando a conta entrou no Zernio; a contagem atual garante o dia de hoje
  const contas = await zernio("/accounts", {}, key);
  const atual = (contas.accounts ?? []).find((a: any) => a._id === conta.id_externo)?.followersCount;
  if (atual != null) linha(dia(0)).seguidores ??= atual;

  const ins = await zernio("/analytics/instagram/account-insights", { ...base, metrics: "reach" }, key);
  for (const v of ins.metrics?.reach?.values ?? []) linha(v.date.slice(0, 10)).alcance = v.value;

  const { data, error } = await db.rpc("conexao_gravar", { p_conta: conta.id, p_tipo: "perfil", p_linhas: Object.values(porDia) });
  if (error) throw new Error(`gravar perfil: ${error.message}`);
  return data as number;
}

// DMs: lista as conversas (mais recentes primeiro) e, só para as que mudaram desde a última vez, busca as mensagens.
// Por rodada, no máximo LIMITE_CONVERSAS conversas com mensagens novas (o resto entra na rodada seguinte).
const LIMITE_CONVERSAS = 40;
async function dms(conta: any, desde: string, key: string) {
  const { data: conhecidas } = await db.rpc("social_conversas_conhecidas", { p_conta: conta.id });
  const ja: Record<string, string | null> = (conhecidas as Record<string, string | null>) ?? {};
  const mudou: any[] = [];
  let cursor: string | null = null, paginas = 0, acabou = false;
  while (!acabou && paginas < 10 && mudou.length < LIMITE_CONVERSAS) {
    const params: Record<string, string | number> = { platform: "instagram", accountId: conta.id_externo, limit: 100 };
    if (cursor) params.cursor = cursor;
    const r = await zernio("/inbox/conversations", params, key);
    paginas++;
    for (const c of r.data ?? []) {
      const quando = c.updatedTime ? new Date(c.updatedTime) : null;
      if (quando && quando.toISOString().slice(0, 10) < desde) { acabou = true; break; }
      const antes = ja[c.id] ? new Date(ja[c.id] as string).getTime() : null;
      if (antes != null && quando && quando.getTime() <= antes) continue;
      mudou.push(c);
      if (mudou.length >= LIMITE_CONVERSAS) break;
    }
    cursor = r.pagination?.nextCursor ?? null;
    if (!cursor) acabou = true;
  }
  // grava de 10 em 10: se o tempo ou o limite do Zernio acabar no meio, o que já veio fica salvo
  let gravadas = 0, lote: any[] = [];
  const grava = async () => {
    if (!lote.length) return;
    const { data, error } = await db.rpc("social_gravar_dms", { p_conta: conta.id, p_conversas: lote });
    if (error) throw new Error(`gravar dms: ${error.message}`);
    gravadas += (data as any)?.mensagens ?? 0; lote = [];
  };
  for (const c of mudou) {
    if (Date.now() - inicio > 120000) break;
    let r: any;
    try { r = await zernio(`/inbox/conversations/${encodeURIComponent(c.id)}/messages`, { accountId: conta.id_externo, limit: 100, sortOrder: "desc" }, key); }
    catch (e) { await grava(); if (String((e as Error).message).includes(" 429")) break; throw e; }
    lote.push({
      id: c.id, participante_id: c.participantId ?? null, nome: c.participantName ?? null, usuario: c.participantUsername ?? null,
      url: c.url ?? null, ultima_mensagem: c.lastMessage ?? null, ultima_em: c.updatedTime ?? null, nao_lidas: c.unreadCount ?? 0,
      anuncio: c.adAttribution ?? null,
      mensagens: (r.messages ?? []).filter((m: any) => !m.isDeleted).map((m: any) => ({
        id: m.id, direcao: m.direction === "outgoing" ? "enviada" : "recebida",
        texto: m.message ?? (m.isStoryMention ? "(menção em story)" : null), anexos: (m.attachments ?? []).length, em: m.createdAt ?? m.sentAt,
      })),
    });
    if (lote.length >= 10) await grava();
    await espera(1100);
  }
  await grava();
  return gravadas;
}

Deno.serve(async (req) => {
  inicio = Date.now();
  const { data: ok } = await db.rpc("zernio_sync_autorizado", { p_segredo: req.headers.get("x-sync-secret") ?? "" });
  if (!ok) return json({ erro: "não autorizado" }, 401);

  const key = Deno.env.get("ZERNIO_API_KEY");
  if (!key) return json({ erro: "Falta o segredo ZERNIO_API_KEY nas Edge Functions do Supabase" }, 500);

  const body = await req.json().catch(() => ({}));
  const partes: string[] = Array.isArray(body.partes) && body.partes.length ? body.partes : ["posts", "perfil", "dms"];
  let q = db.from("conexoes").select("id, dias_retroativos, ultima_sincronizacao, conexao_contas(id, tipo, id_externo, nome, sincronizar)")
    .eq("plataforma", "zernio").in("status", ["conectado", "expirada", "erro"]);
  q = body.conexao_id ? q.eq("id", body.conexao_id) : q.eq("sincronizar_auto", true);
  const { data: conexoes, error } = await q;
  if (error) return json({ erro: error.message }, 500);

  const resultado = [];
  for (const c of conexoes ?? []) {
    const { data: exec } = await db.rpc("conexao_execucao", { p_conexao: c.id, p_id: null, p_status: null, p_registros: null, p_erro: null, p_detalhe: null, p_por: body.por ?? "cron" });
    // primeira carga pega 1 ano de posts; depois só a janela de dias_retroativos (métricas de posts recentes ainda mudam)
    const diasPosts = c.ultima_sincronizacao ? c.dias_retroativos : 365;
    const diasPerfil = Math.min(c.dias_retroativos, 88);
    let registros = 0;
    const erros: string[] = [];
    const detalhe: Record<string, unknown> = {};
    const tarefas = [["posts", posts, dia(diasPosts)], ["perfil", perfil, dia(diasPerfil)], ["dms", dms, dia(90)]] as const;
    for (const conta of (c.conexao_contas ?? []).filter((k: any) => k.sincronizar && k.tipo === "instagram")) {
      for (const [nome, fn, desde] of tarefas) {
        if (!partes.includes(nome)) continue;
        try {
          const n = await fn(conta, desde, key);
          registros += n;
          detalhe[`${conta.nome}.${nome}`] = n;
        } catch (e) {
          erros.push(`${conta.nome}.${nome}: ${(e as Error).message}`);
        }
      }
    }
    const status = erros.length === 0 ? "ok" : registros > 0 ? "parcial" : "erro";
    await db.rpc("conexao_execucao", { p_conexao: c.id, p_id: exec, p_status: status, p_registros: registros, p_erro: erros.join(" | ") || null, p_detalhe: detalhe, p_por: null });
    resultado.push({ conexao: c.id, status, registros, detalhe, erros });
  }
  return json({ resultado });
});
