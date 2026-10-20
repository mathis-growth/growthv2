// Stub do supabase-js para testar as edge functions contra o Postgres local: rpc(nome, args) vira "select nome(...)" via psql,
// rodando como o papel anon (igual ao que a função faz em produção com a chave anon). Banco: variável PGDB (padrão g109).
const lit = (v: unknown): string => v === null || v === undefined ? 'null'
  : Array.isArray(v) ? `array[${v.map(lit).join(',')}]::text[]`
  : typeof v === 'object' ? `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb`
  : `'${String(v).replace(/'/g, "''")}'`;
export function createClient(_u: string, _k: string, _o?: unknown) {
  return { rpc: async (nome: string, args: Record<string, unknown>) => {
    const sql = `set role anon; select ${nome}(${Object.entries(args).map(([k, v]) => `${k} => ${lit(v)}`).join(', ')})::text;`;
    const p = new Deno.Command('psql', { args: ['-h', '/var/run/postgresql', '-p', '55432', '-U', 'postgres', '-d', Deno.env.get('PGDB') || 'g109', '-Atq', '-v', 'ON_ERROR_STOP=1'], stdin: 'piped', stdout: 'piped', stderr: 'piped' }).spawn();
    const w = p.stdin.getWriter(); await w.write(new TextEncoder().encode(sql)); await w.close();
    const out = await p.output();
    const err = new TextDecoder().decode(out.stderr).trim();
    if (!out.success) return { data: null, error: { message: err.replace(/^.*?ERROR:\s*/s, '').split('\n')[0] } };
    return { data: JSON.parse(new TextDecoder().decode(out.stdout).trim()), error: null };
  } };
}
