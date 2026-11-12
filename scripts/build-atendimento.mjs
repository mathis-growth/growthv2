import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = path.join(root, 'supabase', 'functions', 'atendimento');
const parts = [
  '00-base.ts',
  '10-mensagens.ts',
  '20-integracoes.ts',
  '30-rotinas.ts',
  '40-email.ts',
  '50-rotas-acesso-email.ts',
  '51-rotas-campanhas-grupos.ts',
  '52-rotas-disparos.ts',
  '53-rotas-atendimento.ts',
  '54-rotas-templates.ts',
  '55-rotas-canais.ts',
  '60-sincronizacao-grupos.ts',
  '90-entrada.ts',
];
const outputPath = path.join(base, 'index.ts');
const stampPath = path.join(base, 'src', 'index.sha256');
const generated = (await Promise.all(parts.map(name => readFile(path.join(base, 'src', name), 'utf8')))).join('');
const existing = await readFile(outputPath, 'utf8');
const sha = value => createHash('sha256').update(value).digest('hex');
const mode = process.argv[2] ?? '--check';

if (mode === '--check') {
  if (existing !== generated) {
    console.error('index.ts difere do código-fonte. Compare os arquivos antes de publicar.');
    process.exitCode = 1;
  } else {
    console.log(`Edge de Atendimento sincronizada: ${parts.length} partes, ${generated.split('\n').length} linhas.`);
  }
} else if (mode === '--write') {
  const expected = (await readFile(stampPath, 'utf8')).trim();
  if (sha(existing) !== expected) {
    console.error('index.ts mudou desde a última geração. Integre as alterações nas partes antes de regenerar.');
    process.exitCode = 1;
  } else {
    await writeFile(outputPath, generated, 'utf8');
    await writeFile(stampPath, `${sha(generated)}\n`, 'utf8');
    console.log('index.ts único atualizado.');
  }
} else {
  console.error('Uso: node scripts/build-atendimento.mjs [--check|--write]');
  process.exitCode = 2;
}
