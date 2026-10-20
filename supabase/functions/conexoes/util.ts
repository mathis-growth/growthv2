// Utilidades das conexões (Meta e Google): chamadas HTTP com erro legível, datas e paginação.
export type Dic = Record<string, unknown>;
export const env = (k: string, d = '') => Deno.env.get(k) || d;
export const META_V = () => env('META_API_VERSION', 'v21.0');
export const GADS_V = () => env('GOOGLE_ADS_API_VERSION', 'v20');

export class ErroPlataforma extends Error {
  constructor(public plataforma: string, msg: string, public status = 0) { super(`${plataforma}: ${msg}`); }
}

export async function pede(plataforma: string, url: string, init?: RequestInit): Promise<Dic> {
  const r = await fetch(url, init);
  const t = await r.text();
  let j: Dic = {};
  try { j = t ? JSON.parse(t) : {}; } catch { j = { texto: t.slice(0, 300) }; }
  if (!r.ok || (j as { error?: unknown }).error) {
    const e = (j as { error?: Dic | string }).error;
    const msg = typeof e === 'string' ? e + ((j as Dic).error_description ? ' — ' + (j as Dic).error_description : '')
      : e ? String((e as Dic).message || (e as Dic).status || JSON.stringify(e)).slice(0, 400) : `HTTP ${r.status} ${String((j as Dic).texto || '').slice(0, 200)}`;
    throw new ErroPlataforma(plataforma, msg, r.status);
  }
  return j;
}

export const dia = (d: Date) => d.toISOString().slice(0, 10);
export function janela(dias: number, ultima?: string | null): { de: string; ate: string } {
  // primeira vez: puxa os dias configurados; depois, os últimos 3 dias (as plataformas ajustam números recentes)
  const hoje = new Date(), n = ultima ? Math.min(dias, 3) : dias;
  const de = new Date(hoje.getTime() - n * 86400000);
  return { de: dia(de), ate: dia(hoje) };
}
export const num = (v: unknown): number | null => v === null || v === undefined || v === '' ? null : Number(v);
export const qs = (o: Record<string, string | number | undefined>) => Object.entries(o).filter(([, v]) => v !== undefined && v !== '').map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`).join('&');
