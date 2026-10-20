// Stub do supabase-js com papéis, para testar a função "conexoes" contra o Postgres local (banco PGDB, padrão fa):
//   chave "service" → roda como service_role; cabeçalho Authorization "Bearer uid:<uuid>" → usuário logado (authenticated);
//   sem nada → anon. rpc(nome, args) vira "select nome(...)" via psql.
const lit = (v: unknown): string => v === null || v === undefined ? 'null'
  : Array.isArray(v) && v.some(x => x !== null && typeof x === 'object') ? `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb`
  : Array.isArray(v) ? `array[${v.map(x => `'${String(x).replace(/'/g, "''")}'`).join(',')}]::text[]`
  : typeof v === 'object' ? `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb`
  : typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`;
export function createClient(_u: string, chave: string, o?: { global?: { headers?: Record<string, string> }; auth?: unknown }) {
  const auth = (o?.global?.headers?.Authorization || '').replace(/^Bearer\s+/i, '');
  const pre = chave === 'service' ? 'set role service_role;' : auth.startsWith('uid:')
    ? `select set_config('request.jwt.claims', '{"sub":"${auth.slice(4)}","role":"authenticated"}', false); set role authenticated;` : 'set role anon;';
  return { rpc: async (nome: string, args: Record<string, unknown>) => {
    const sql = `${pre} select ${nome}(${Object.entries(args).map(([k, v]) => `${k} => ${lit(v)}`).join(', ')})::text;`;
    const p = new Deno.Command('psql', { args: ['-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', Deno.env.get('PGDB') || 'fa', '-Atq', '-v', 'ON_ERROR_STOP=1'], stdin: 'piped', stdout: 'piped', stderr: 'piped' }).spawn();
    const w = p.stdin.getWriter(); await w.write(new TextEncoder().encode(sql)); await w.close();
    const out = await p.output();
    const err = new TextDecoder().decode(out.stderr).trim();
    if (!out.success) return { data: null, error: { message: err.replace(/^.*?ERROR:\s*/s, '').split('\n')[0] } };
    const t = new TextDecoder().decode(out.stdout).trim().split('\n').pop() || '';
    try { return { data: t === '' ? null : JSON.parse(t), error: null }; } catch { return { data: t, error: null }; }
  } };
}
