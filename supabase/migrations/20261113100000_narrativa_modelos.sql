-- v0.157 — Banco de narrativas (Data Storytelling)
-- As frases do sistema saem do código e passam a morar aqui. O front só preenche os {campos} com números já calculados
-- (pelo banco ou pela camada semântica); o texto, a condição e a regra de cor ficam guardados, versionados e aprovados.
-- Governança: código estável (NAR-X00) que nunca é reaproveitado nem apagado (descontinuar em vez de apagar);
-- a versão sobe sozinha quando muda o texto, a condição, o que precisa, quando não usar ou a cor; a versão anterior vai para o histórico.
-- Só modelo com status 'aprovado' aparece na tela. Leitura: qualquer usuário logado. Escrita: só pelo painel do Supabase (service role).
create table if not exists narrativa_modelos (
  codigo text primary key check (codigo ~ '^NAR-[A-Z][0-9]{2}$'),
  versao int not null default 1,
  status text not null default 'proposto' check (status in ('proposto', 'aprovado', 'descontinuado')),
  categoria text not null check (categoria in ('descricao', 'evolucao', 'comparacao', 'meta', 'atencao', 'relacao', 'hipotese', 'investigacao', 'oportunidade', 'neutra')),
  evidencia text not null check (evidencia ~ '^[FCAHR](\+[FCAHR])?$'),
  modelo text not null,
  campos text[] not null default '{}',
  ativa_quando text,
  precisa text,
  cor text,
  nao_usar text,
  telas text[] not null default '{}',
  investigar text,
  observacao text,
  aprovado_por text,
  aprovado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
comment on table narrativa_modelos is 'Banco de narrativas do Growths (v0.157). Evidência: F fato calculado, C comparação, A alerta condicionado, H hipótese, R recomendação. {campo} = número preenchido pelo sistema; [a/b] = o sistema escolhe a palavra pela direção.';

create table if not exists narrativa_modelos_historico (
  id bigserial primary key,
  codigo text not null references narrativa_modelos(codigo),
  versao int not null,
  status text not null,
  modelo text not null,
  ativa_quando text, precisa text, cor text, nao_usar text,
  aprovado_por text, aprovado_em timestamptz,
  substituido_em timestamptz not null default now()
);

create or replace function narrativa_modelos_regras() returns trigger language plpgsql as $$
declare resto text;
begin
  if tg_op = 'DELETE' then
    raise exception 'Modelo de narrativa não se apaga: mude o status para descontinuado (o código % não pode ser reaproveitado).', old.codigo;
  end if;
  -- campos: os {campo} do texto, na ordem em que aparecem
  new.campos := coalesce((select array_agg(c order by p) from (select m[1] c, min(o) p from regexp_matches(new.modelo, '\{([a-z_]+)\}', 'g') with ordinality r(m, o) group by 1) x), '{}');
  resto := regexp_replace(regexp_replace(new.modelo, '\{[a-z_]+\}', '', 'g'), '\[[^\[\]{}/]+(/[^\[\]{}/]+)+\]', '', 'g');
  if resto ~ '[{}\[\]]' then
    raise exception 'Modelo % com marcação inválida: use {campo} (letras minúsculas e _) e [palavra/outra].', new.codigo;
  end if;
  if new.status = 'aprovado' then
    if coalesce(new.aprovado_por, '') = '' then raise exception 'Modelo % aprovado sem quem aprovou (aprovado_por).', new.codigo; end if;
    new.aprovado_em := coalesce(new.aprovado_em, now());
  end if;
  if tg_op = 'UPDATE' then
    if new.codigo <> old.codigo then raise exception 'O código do modelo não muda (%).', old.codigo; end if;
    if (new.modelo, new.ativa_quando, new.precisa, new.cor, new.nao_usar) is distinct from (old.modelo, old.ativa_quando, old.precisa, old.cor, old.nao_usar) then
      new.versao := old.versao + 1;
      if new.status = 'aprovado' and old.status = 'aprovado' and new.aprovado_em is not distinct from old.aprovado_em then
        new.status := 'proposto'; new.aprovado_por := null; new.aprovado_em := null;   -- texto novo precisa de nova aprovação
      end if;
    end if;
    if (new.versao, new.status) is distinct from (old.versao, old.status) then
      insert into narrativa_modelos_historico (codigo, versao, status, modelo, ativa_quando, precisa, cor, nao_usar, aprovado_por, aprovado_em)
      values (old.codigo, old.versao, old.status, old.modelo, old.ativa_quando, old.precisa, old.cor, old.nao_usar, old.aprovado_por, old.aprovado_em);
    end if;
    new.atualizado_em := now();
  end if;
  return new;
end $$;
drop trigger if exists narrativa_modelos_regras on narrativa_modelos;
create trigger narrativa_modelos_regras before insert or update or delete on narrativa_modelos for each row execute function narrativa_modelos_regras();

alter table narrativa_modelos enable row level security;
alter table narrativa_modelos_historico enable row level security;
drop policy if exists narrativa_modelos_ler on narrativa_modelos;
create policy narrativa_modelos_ler on narrativa_modelos for select to authenticated using (true);
drop policy if exists narrativa_modelos_historico_ler on narrativa_modelos_historico;
create policy narrativa_modelos_historico_ler on narrativa_modelos_historico for select to authenticated using (true);
revoke insert, update, delete on narrativa_modelos, narrativa_modelos_historico from anon, authenticated;
grant select on narrativa_modelos, narrativa_modelos_historico to authenticated;

insert into narrativa_modelos (codigo, status, categoria, evidencia, modelo, ativa_quando, precisa, cor, nao_usar, telas, investigar, aprovado_por, aprovado_em) values
  ('NAR-D01', 'proposto', 'descricao', 'F', 'A receita das vendas foi de {receita} em {periodo}, com {vendas} vendas aprovadas.', 'há venda aprovada no período', 'receita, vendas', null, 'período com dado incompleto sem o aviso', array['adm-painel', 'crm-vendas']::text[], null, null, null),
  ('NAR-D02', 'aprovado', 'descricao', 'F', 'Da receita de {receita}, [sobraram/faltaram] {abs_resultado} depois de deduções, custos e despesas: resultado de {resultado}, margem de {margem}.', 'DRE do período com receita maior que zero', 'receita, resultado, margem', '2a', 'sem receita no período', array['fin-dash']::text[], 'fin-dash#cascata', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-D03', 'proposto', 'descricao', 'F', '{produto} representou {participacao} da receita de {periodo}.', '2 ou mais produtos com venda', 'receita por produto', null, 'só 1 produto vendeu (use NAR-A05)', array['adm-painel', 'crm-vendas']::text[], null, null, null),
  ('NAR-D04', 'proposto', 'descricao', 'F', '{leads} leads entraram em {periodo}, com custo médio de {cpl} por lead.', 'investimento e leads maiores que zero', 'leads, CPL', null, 'investimento com aviso de dado faltando', array['mkt-dash', 'mkt-trafego']::text[], null, null, null),
  ('NAR-D05', 'proposto', 'descricao', 'F', '{pct_existentes} da receita veio de quem já era cliente.', 'receita maior que zero', 'novos × existentes', null, 'base com menos de 20 clientes', array['adm-painel', 'ho-retencao']::text[], null, null, null),
  ('NAR-D06', 'aprovado', 'descricao', 'F', 'Dentro do saldo mínimo nos próximos 30 dias: o ponto mais baixo da projeção é {valor} em {data_min} (mínimo de {minimo}).', 'saldo mínimo cadastrado e projeção sempre acima dele', 'projeção de 30 dias, saldo mínimo', 'verde', '—', array['fin-dash']::text[], null, 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-D07', 'aprovado', 'descricao', 'F', 'Nos próximos 30 dias, o caixa não fica negativo: o ponto mais baixo da projeção é {valor} em {data_min}.', 'sem saldo mínimo e projeção sempre acima de zero', 'projeção de 30 dias', null, 'com saldo mínimo (use NAR-D06 ou NAR-A01)', array['fin-dash']::text[], null, 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-E01', 'proposto', 'evolucao', 'C', 'A receita [subiu/caiu] {var_pct} contra {base}: de {receita_ant} para {receita}.', 'variação de 5% ou mais e base comparável', 'receita nos 2 períodos', 'direcao', 'períodos de tamanho ou alinhamento diferentes', array['adm-painel', 'crm-vendas']::text[], null, null, null),
  ('NAR-E02', 'proposto', 'evolucao', 'C', 'A margem [subiu/caiu] {var_pp} contra {base} e está em {margem}.', 'variação de 3 p.p. ou mais', 'margem nos 2 períodos', 'direcao + 2a', 'receita zero em um dos períodos', array['adm-painel', 'fin-dash', 'fin-custo']::text[], null, null, null),
  ('NAR-E03', 'proposto', 'evolucao', 'C', 'O resultado ficou {var_abs} [acima/abaixo] de {base}, quando foi {resultado_ant}.', 'resultado nos 2 períodos (variação sempre em reais)', 'resultado nos 2 períodos', 'direcao', 'nunca usar %', array['adm-painel', 'fin-dash']::text[], null, null, null),
  ('NAR-E04', 'proposto', 'evolucao', 'C', 'O CAC de mídia [subiu/caiu] {var_pct} contra {base}: cada cliente novo custou {cac}.', '5 ou mais clientes novos nos 2 períodos', 'CAC nos 2 períodos', 'direcao (menor)', 'poucos clientes (número instável)', array['mkt-dash', 'mkt-trafego']::text[], null, null, null),
  ('NAR-E05', 'proposto', 'evolucao', 'C', 'A conversão de lead em cliente [subiu/caiu] {var_pp}, para {conv}.', '50 ou mais leads nos 2 períodos', 'conversão nos 2 períodos', 'direcao', 'coortes com tempos de maturação diferentes', array['mkt-dash']::text[], null, null, null),
  ('NAR-E06', 'proposto', 'evolucao', 'C', 'A retenção em {dias} dias da coorte {coorte} está {var_pp} [acima/abaixo] da média das coortes.', 'coorte já atingiu a idade', 'curva por coorte', 'direcao', 'coorte jovem (marcar como parcial)', array['ho-dash', 'ho-retencao']::text[], null, null, null),
  ('NAR-E07', 'aprovado', 'evolucao', 'C', 'No período, o resultado foi {resultado}: {var_resultado} contra {base}, quando foi {resultado_ant}. Receitas {var_receita} e despesas {var_despesa}.', 'período com início e fim e período anterior de mesmo tamanho', 'resultado, receitas e despesas nos 2 períodos', '2a + direcao', 'período sem início ou sem fim', array['fin-dash']::text[], 'fin-dash#ponte', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-C01', 'proposto', 'comparacao', 'C', '{canal} teve o menor CAC de mídia entre os canais: {cac} por cliente novo.', '2 ou mais canais com 5 ou mais clientes', 'CAC por canal', null, 'canal com poucos clientes', array['mkt-trafego']::text[], null, null, null),
  ('NAR-C02', 'proposto', 'comparacao', 'C', '{produto_a} vendeu {dif_pct} mais que {produto_b}.', '2 ou mais produtos com venda', 'receita por produto', null, 'produtos com preços muito diferentes (comparar quantidade)', array['crm-vendas']::text[], null, null, null),
  ('NAR-C03', 'proposto', 'comparacao', 'C', '{campanha} trouxe clientes por {cac_campanha}, {dif_pct} [abaixo/acima] da média das campanhas ({cac_medio}).', '2 ou mais campanhas com clientes', 'CAC por campanha', 'direcao', 'campanha ainda no ar sem dizer', array['mkt-trafego', 'mkt-dash']::text[], null, null, null),
  ('NAR-C04', 'proposto', 'comparacao', 'C', 'Entre as origens com {n_min} leads ou mais, {origem} tem a maior parte de compradores: {conv}.', 'origem com amostra mínima', 'leads e compradores por origem', null, '(já existe na tela Leads por origem)', array['mkt-origem']::text[], null, null, null),
  ('NAR-M01', 'proposto', 'meta', 'A', 'A receita está {desvio_pct} [abaixo/acima] da meta de {meta} para {periodo}.', 'meta cadastrada', 'receita, meta', 'direcao', 'meta não cadastrada', array['adm-painel']::text[], null, null, null),
  ('NAR-M02', 'proposto', 'meta', 'A+H', 'Faltam {falta} para a meta do mês; no ritmo atual, o mês fecha em {projecao}.', 'meta mensal e mês em andamento', 'realizado, meta, dias', 'âmbar se abaixo do ritmo', 'mês fechado', array['adm-painel', 'mkt-camp-dash']::text[], null, null, null),
  ('NAR-M03', 'proposto', 'meta', 'A', 'A margem está {desvio_pp} [abaixo/acima] do {cenario} ({ref}).', 'cenário cadastrado', 'margem, cenário', '2a', 'cenário padrão de tela', array['adm-painel', 'fin-custo']::text[], null, null, null),
  ('NAR-M04', 'proposto', 'meta', 'A', 'O CAC de mídia [passou do/ficou abaixo do] limite de {limite} em {desvio_pct}.', 'limite ou guardrail cadastrado', 'CAC, limite', 'direcao', 'sem limite', array['mkt-trafego', 'gro-guard']::text[], null, null, null),
  ('NAR-M05', 'proposto', 'meta', 'A', '{n_campanhas} de {total} campanhas estão acima da própria meta de CAC.', 'campanhas com meta de CAC', 'CAC e meta por campanha', 'vermelho se maior que 0', 'nenhuma campanha com meta', array['mkt-camp', 'mkt-dash']::text[], null, null, null),
  ('NAR-A01', 'aprovado', 'atencao', 'A', 'Pela projeção, o caixa fica abaixo do saldo mínimo de {minimo} em {data}; o ponto mais baixo é {valor} em {data_min}.', 'saldo mínimo cadastrado e projeção abaixo dele', 'projeção de 30 dias, saldo mínimo', 'vermelho', 'sem saldo mínimo (use NAR-A02)', array['fin-dash', 'adm-painel']::text[], 'fin-pagar', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-A02', 'aprovado', 'atencao', 'A', 'Pela projeção, o caixa fica negativo em {data}; o ponto mais baixo é {valor} em {data_min}.', 'sem saldo mínimo e projeção abaixo de zero', 'projeção de 30 dias', 'vermelho', 'com saldo mínimo (use NAR-A01)', array['fin-dash', 'adm-painel']::text[], 'fin-pagar', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-A03', 'proposto', 'atencao', 'A', 'O CAC de mídia está a {dist_pct} do limite de {limite}.', 'dentro da faixa preventiva cadastrada', 'CAC, limite, faixa', 'âmbar', 'faixa não cadastrada (não inventar)', array['mkt-trafego']::text[], null, null, null),
  ('NAR-A04', 'proposto', 'atencao', 'A', '{atraso} estão vencidos e não recebidos: {pct_atraso} do que há para receber.', 'atraso de 10% ou mais do a receber', 'a receber, atraso', 'âmbar', '—', array['fin-dash', 'crm-contratos']::text[], 'fin-receber', null, null),
  ('NAR-A05', 'proposto', 'atencao', 'A', '{produto} responde por {participacao} da receita: a operação depende de um produto só.', 'um produto acima de 60%', 'receita por produto', 'âmbar', 'só 1 produto cadastrado no negócio', array['adm-painel']::text[], null, null, null),
  ('NAR-R01', 'proposto', 'relacao', 'C', 'A receita [subiu/caiu] {var_receita}, enquanto a margem [subiu/caiu] {var_margem_pp}.', 'sinais opostos, os dois acima da tolerância', 'receita e margem nos 2 períodos', null, 'movimentos dentro da tolerância', array['adm-painel', 'fin-dash']::text[], null, null, null),
  ('NAR-R02', 'proposto', 'relacao', 'C', 'O investimento [subiu/caiu] {var_inv} e a receita, {var_receita}.', 'diferença entre as duas variações de 10 p.p. ou mais', 'investimento e receita', null, 'receita de coortes ainda maturando', array['mkt-dash', 'mkt-camp-dash']::text[], null, null, null),
  ('NAR-R03', 'proposto', 'relacao', 'C', 'Os leads [subiram/caíram] {var_leads}, mas a conversão [subiu/caiu] {var_conv_pp}.', 'sinais opostos', 'leads e conversão', null, 'período recente sem tempo de conversão', array['mkt-dash']::text[], null, null, null),
  ('NAR-R04', 'proposto', 'relacao', 'C+H', 'O resultado foi {resultado} e o saldo no banco [subiu/caiu] {var_saldo}: a diferença de {dif} costuma vir de vendas a prazo, contas pagas em outro mês ou retiradas.', 'resultado e saldo divergem', 'DRE e banco', null, '(já existe no Financeiro)', array['fin-dash']::text[], null, null, null),
  ('NAR-H01', 'aprovado', 'hipotese', 'H', 'Possível fator associado: {componente} [aumentou/diminuiu] {var} no mesmo período.', 'o componente que mais pesou na diferença do resultado andou no mesmo sentido dela', 'componentes do resultado nos 2 períodos', null, 'sem dado do componente; nunca dizer que é a causa', array['fin-dash', 'adm-painel']::text[], 'fin-dash#ponte', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-I01', 'aprovado', 'investigacao', 'R', 'Vale abrir a composição dos custos: a conta {conta} foi a maior despesa do período ({valor}).', 'resultado negativo ou pior que o do período anterior', 'despesas por conta', null, 'resultado positivo e melhor que o anterior', array['fin-dash']::text[], 'fin-lanc', 'Rebecka', '2026-10-26 15:58-03'::timestamptz),
  ('NAR-I02', 'proposto', 'investigacao', 'F+R', 'A maior perda está entre {etapa_a} e {etapa_b}: {perda} pessoas ({pct}).', 'funil com 3 ou mais etapas', 'contagens por etapa', null, 'etapa com menos de 20 pessoas', array['mkt-dash-funil', 'crm-dash']::text[], null, null, null),
  ('NAR-I03', 'proposto', 'investigacao', 'C+R', 'Compare a coorte {coorte} com as anteriores: ela está {var_pp} [acima/abaixo] na mesma idade.', '3 ou mais coortes', 'curvas por coorte', null, 'coortes pequenas', array['ho-retencao']::text[], null, null, null),
  ('NAR-O01', 'proposto', 'oportunidade', 'R', '{canal} trouxe clientes {dif_pct} mais baratos que a média; vale avaliar se ele aguenta mais investimento sem subir o CAC.', 'CAC do canal até 0,9 × a média e 10 ou mais clientes', 'CAC por canal e margem', null, 'margem negativa, caixa abaixo do mínimo ou guardrail violado', array['mkt-trafego']::text[], null, null, null),
  ('NAR-O02', 'proposto', 'oportunidade', 'C+R', '{pct_recompra} dos clientes de {produto} compraram de novo em {dias} dias: {produto} é uma boa porta de entrada para a esteira.', 'porta de entrada com 20 ou mais clientes', 'recompra por produto de entrada', null, 'coorte jovem', array['ho-dash', 'ho-retencao']::text[], null, null, null),
  ('NAR-N01', 'aprovado', 'neutra', 'F', 'Sem base de comparação para {metrica} neste período.', 'falta o período anterior ou a referência', '—', null, '(entra no lugar das outras quando falta dado)', array['*']::text[], null, 'Rebecka', '2026-10-26 15:58-03'::timestamptz)
on conflict (codigo) do nothing;
