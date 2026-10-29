// Monta o banco: stubs do Supabase + migrations em ordem; depois roda arquivos extras. Uso: node run.mjs <repo> [extra.sql ...]
import { PGlite } from '@electric-sql/pglite';
import fs from 'fs'; import path from 'path';
const repo = process.argv[2], extras = process.argv.slice(3);
const db = new PGlite();
const stub = `
create role anon nologin; create role authenticated nologin; create role service_role nologin; create role supabase_admin nologin;
create schema auth; create table auth.users (id uuid primary key, email text);
create schema t; create table t.cfg (k text primary key, v text);
create function auth.uid() returns uuid language sql stable as $$ select (select v from t.cfg where k='uid')::uuid $$;
create function auth.role() returns text language sql stable as $$ select coalesce((select v from t.cfg where k='role'),'authenticated') $$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
create function auth.email() returns text language sql stable as $$ select null::text $$;
create schema extensions; create schema storage; create schema cron; create schema net; create schema vault;
grant usage on schema auth to authenticated, anon;
`;
await db.exec(stub);
const dir = path.join(repo, 'supabase/migrations');
const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql') && (!process.env.ATE || f < process.env.ATE)).sort();
let fail = 0;
for (const f of files) {
  try { await db.exec(fs.readFileSync(path.join(dir, f), 'utf8')); }
  catch (e) { fail++; console.log('FALHOU ' + f + ': ' + e.message.slice(0, 200)); }
}
console.log('migrations: ' + files.length + ', falhas: ' + fail);
for (const x of extras) {
  try { const r = await db.exec(fs.readFileSync(x, 'utf8')); const last = r.filter(z => z.rows && z.rows.length).pop(); if (last) console.log(JSON.stringify(last.rows).slice(0, 4000)); }
  catch (e) { console.log('ERRO em ' + path.basename(x) + ': ' + e.message); process.exitCode = 1; }
}
