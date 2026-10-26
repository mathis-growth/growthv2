-- v0.156 — Dicionário de métricas com a camada semântica (Data Storytelling)
-- unidade e casas: como o número aparece; direcao: quanto maior/menor melhor, faixa ou neutra;
-- zero_limite: nas métricas de saldo o zero é limite (negativo = vermelho, positivo = verde), decidido em 26/10/2026;
-- referencia: onde o Growths busca a meta ou o limite que dá a cor. Sem referência, o número fica neutro.
alter table metricas_definicoes add column if not exists unidade text check (unidade is null or unidade in ('brl', 'pct', 'x', 'razao', 'numero', 'dias', 'texto'));
alter table metricas_definicoes add column if not exists casas int check (casas is null or casas between 0 and 4);
alter table metricas_definicoes add column if not exists direcao text check (direcao is null or direcao in ('maior', 'menor', 'faixa', 'neutra'));
alter table metricas_definicoes add column if not exists zero_limite boolean not null default false;
alter table metricas_definicoes add column if not exists referencia text;

update metricas_definicoes d set unidade = v.un, casas = v.c, direcao = v.dir, zero_limite = v.z, referencia = v.ref,
  versao = d.versao + case when d.direcao is distinct from v.dir then 1 else 0 end, atualizado_em = now()
from (values
  ('a_pagar', 'brl', 2, 'neutra', false, 'Nenhuma: valor a pagar não tem bom ou ruim sozinho.'),
  ('a_receber', 'brl', 2, 'neutra', false, 'Atraso: alerta quando 10% ou mais do que há para receber está vencido (o valor em si é neutro).'),
  ('aceite_oferta', 'pct', 1, 'maior', false, 'Período anterior.'),
  ('atribuicao', 'texto', null, 'neutra', false, 'Regra de cálculo, não é um número.'),
  ('cac', 'brl', 2, 'menor', false, 'Meta de CAC da campanha; guardrail cac_midia; período anterior.'),
  ('churn', 'pct', 1, 'menor', false, 'Meta de churn máximo (RevOps).'),
  ('cliente', 'numero', 0, 'maior', false, 'Período anterior.'),
  ('conv_lead_venda', 'pct', 2, 'maior', false, 'Meta de conversão; guardrail conv; benchmark de mercado.'),
  ('cpl', 'brl', 2, 'menor', false, 'Meta de CPL da campanha; CPL limite da Mídia paga; guardrail cpl.'),
  ('investimento', 'brl', 2, 'neutra', false, 'Orçamento da campanha, quando houver.'),
  ('leads', 'numero', 0, 'maior', false, 'Meta de leads (campanha e planejamento mensal); período anterior.'),
  ('mrr', 'brl', 2, 'maior', false, 'Período anterior; plano da empresa.'),
  ('receita', 'brl', 2, 'maior', false, 'Meta de receita (planejamento mensal); período anterior. Receita maior não quer dizer lucro maior.'),
  ('recuperacao_checkout', 'pct', 1, 'maior', false, 'Período anterior.'),
  ('resultado_mes', 'brl', 2, 'maior', true, 'Zero; cenários de margem (Ruim, Bom, Ótimo) quando cadastrados.'),
  ('roas', 'x', 1, 'maior', false, 'Guardrail roas; benchmark de mercado.'),
  ('saldo_banco', 'brl', 2, 'faixa', true, 'Zero; saldo mínimo de caixa quando cadastrado.'),
  ('taxa_duplicidade', 'pct', 1, 'menor', false, 'Nenhuma cadastrada: fica neutra.'),
  ('ticket_medio', 'brl', 2, 'maior', false, 'Período anterior; benchmark de mercado.'),
  ('venda_valida', 'texto', null, 'neutra', false, 'Regra de cálculo, não é um número.')
) v(cod, un, c, dir, z, ref)
where d.codigo = v.cod;

insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao, unidade, casas, direcao, zero_limite, referencia) values
  ('lucro', 'Lucro', 'Receitas − deduções − custos − despesas no período, por competência (DRE).', 'partidas / lancamentos', 'Sem lançamento = 0.', 'Variação contra o período anterior em reais, nunca em %.', 'brl', 2, 'maior', true, 'Zero; cenários de margem quando cadastrados.'),
  ('margem', 'Margem', 'Lucro ÷ receita.', 'partidas / lancamentos', 'Sem receita: sem valor.', 'Variação em pontos percentuais (p.p.).', 'pct', 1, 'maior', true, 'Zero; cenário Ruim da margem quando cadastrado.'),
  ('roi', 'ROI', 'Lucro ÷ tudo o que saiu (Dashboard) ou (receita − custo) ÷ custo (coortes de marketing).', 'partidas / metricas_anuncio_dia', 'Sem custo: sem valor.', null, 'pct', 1, 'maior', true, 'Zero.'),
  ('caixa_projetado', 'Caixa projetado', 'Saldo em banco + a receber − a pagar até a data.', 'contas_bancarias + contas_receber + contas_pagar', 'Sem conta bancária: sem valor.', null, 'brl', 2, 'faixa', true, 'Zero; saldo mínimo quando cadastrado.'),
  ('ctr', 'CTR', 'Cliques ÷ impressões.', 'metricas_anuncio_dia', 'Sem impressão: sem valor.', null, 'pct', 2, 'maior', false, 'CTR mínimo da Mídia paga.')
on conflict (codigo) do update set unidade = excluded.unidade, casas = excluded.casas, direcao = excluded.direcao, zero_limite = excluded.zero_limite, referencia = excluded.referencia, atualizado_em = now();
