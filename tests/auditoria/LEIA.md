# Auditoria de consistência (v0.110)

Pergunta: a mesma métrica, no mesmo período, dá o mesmo número em todas as telas?

Como funciona: um banco Postgres local montado do zero com TODAS as migrações + uma empresa fictícia criada pelos fluxos reais + o `index.html` real ligado a esse banco por um PostgREST local. Cada tela é aberta no mesmo período (setembro/2026) e os números mostrados são comparados com consultas de referência.

1. Banco: `monta_banco.sh full` (usa `supabase_stub.sql`, que imita o que o Supabase traz pronto: papéis, `auth.uid()`, `auth.jwt()`, esquemas `auth`/`extensions`). Precisa das migrações numa pasta (ajuste o caminho no script). Deve terminar com "falhas: 0".
2. Empresa fictícia: `createdb -T full fa` e `psql -d fa -f aurora_seed.sql`. A conferência no fim mostra "partidas D-C (deve ser 0) | 0.00".
3. Privilégios do Supabase: `psql -d fa -f grants.sql`.
4. PostgREST 12 (binário do GitHub): `postgrest pgrst.conf` (porta 3300).
5. Coleta: `python3 coleta.py` (Playwright). Abre cada tela com o relógio fixado e grava `coleta.json`.
6. Referência: `psql -d fa -f referencia.sql`.

Resultado de 17/10/2026: `coleta_set2026.json` e a planilha `Growths_auditoria_consistencia.xlsx` (entregue à parte).
Achado de bastidor: até esta versão, o repositório não montava o banco do zero (funções que só existiam em produção). Corrigido com `20261010235000_registrar_recebimento_parcial.sql` e `20261012400000_sincroniza_producao.sql`.

## v0.111
- `consistencia.sql`: no banco `fa`, confere que DRE, Dashboard financeiro e painel dão o mesmo setembro, e que a venda das 23h30 fica no dia certo (roda dentro de transação e desfaz).
- `t111_consistencia.py`: 19 verificações de tela (precisa do PostgREST na porta 3300). Restaura o regime da empresa no fim.

## v0.114
- `t114_meta_leads.py`: 21 verificações da meta de leads (banco + tela). Usa o banco `escp` (Escola Aurora: `RODAR_escola_aurora_1_dados.sql` sobre um banco do zero + `grants.sql`), o PostgREST com `pgrst_escola.conf` (porta 3301) e `front_escola.py` (logado como Rebecka).
