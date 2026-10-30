-- v0.176 — Diagnóstico 360° (G1) (aplicada em produção com o nome v0175_diagnostico_g1): formulário do cliente e catálogo de métricas por etapa do funil pirata.
-- Plano: docs/diagnostico-360-plano.md (seções A, B, C e 6).
-- 1. pesquisas: tipo 'diagnostico' e publico (lead ou cliente: "se é um tipo para lead ou se é para cliente").
-- 2. pesquisa_perguntas: tipos novos (numero, moeda, meses, metricas, lista, documentos), condicao (mostrar só se outra pergunta
--    teve certa resposta) e config (lista de métricas, colunas da lista, meses, categorias de documentos).
-- 3. pesquisa_resposta_itens.valor_json: o detalhe das respostas novas (cada métrica com M1 a M16, os meses, a lista de produtos).
-- 4. pesquisa_envios.expira_em: link individual com validade (diagnóstico: 30 dias por padrão).
-- 5. metricas_definicoes: etapa do funil pirata, modelos de negócio, se o Growth's já calcula sozinho, texto para o cliente; mais as
--    métricas que faltavam (seção C do plano). Nada muda nas 30 que existiam além das colunas novas.
-- 6. pesquisa_publica, pesquisa_registrar e pesquisa_responder: entendem os tipos novos, a condição, a validade e o tamanho maior
--    das respostas do diagnóstico.
-- Rode depois de 20261127100000_oportunidade_contrato.sql. Idempotente.

-- ---------- 1. pesquisas ----------
alter table pesquisas drop constraint if exists pesquisas_tipo_check;
alter table pesquisas add constraint pesquisas_tipo_check check (tipo in ('lead', 'onboarding', 'jornada', 'nsm', 'outra', 'diagnostico'));
alter table pesquisas add column if not exists publico text;
update pesquisas set publico = case when tipo = 'lead' then 'lead' else 'cliente' end where publico is null;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisas_publico_check') then
    alter table pesquisas add constraint pesquisas_publico_check check (publico is null or publico in ('lead', 'cliente'));
  end if;
end $c$;

-- ---------- 2. perguntas ----------
alter table pesquisa_perguntas drop constraint if exists pesquisa_perguntas_tipo_check;
alter table pesquisa_perguntas add constraint pesquisa_perguntas_tipo_check
  check (tipo in ('nps', 'escala', 'escolha', 'multipla', 'sim_nao', 'texto', 'numero', 'moeda', 'meses', 'metricas', 'lista', 'documentos'));
alter table pesquisa_perguntas add column if not exists condicao jsonb;
alter table pesquisa_perguntas add column if not exists config jsonb not null default '{}'::jsonb;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_perguntas_condicao_ck') then
    alter table pesquisa_perguntas add constraint pesquisa_perguntas_condicao_ck check (condicao is null or coalesce(jsonb_typeof(condicao) = 'object' and condicao ? 'pergunta' and jsonb_typeof(condicao -> 'valores') = 'array', false));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pesquisa_perguntas_config_ck') then
    alter table pesquisa_perguntas add constraint pesquisa_perguntas_config_ck check (jsonb_typeof(config) = 'object');
  end if;
end $c$;

-- ---------- 3. respostas ----------
alter table pesquisa_resposta_itens add column if not exists valor_json jsonb;

-- ---------- 4. validade do link individual ----------
alter table pesquisa_envios add column if not exists expira_em timestamptz;
create or replace function public.pesquisa_envio_validade() returns trigger language plpgsql set search_path = public as $$
begin
  if new.expira_em is null and (select tipo from pesquisas where id = new.pesquisa_id) = 'diagnostico' then
    new.expira_em := now() + interval '30 days';
  end if;
  return new;
end $$;
revoke execute on function public.pesquisa_envio_validade() from public, anon, authenticated;
drop trigger if exists pesquisa_envio_validade_t on pesquisa_envios;
create trigger pesquisa_envio_validade_t before insert on pesquisa_envios for each row execute function pesquisa_envio_validade();

-- ---------- 5. catálogo de métricas ----------
alter table metricas_definicoes add column if not exists etapa_aarrr text;
alter table metricas_definicoes add column if not exists modelos text[];
alter table metricas_definicoes add column if not exists calcula_sozinho boolean not null default true;
alter table metricas_definicoes add column if not exists descricao_cliente text;
alter table metricas_definicoes add column if not exists ordem int;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'metricas_definicoes_etapa_ck') then
    alter table metricas_definicoes add constraint metricas_definicoes_etapa_ck check (etapa_aarrr is null or etapa_aarrr in ('aquisicao', 'ativacao', 'retencao', 'receita', 'recomendacao', 'recompra'));
  end if;
end $c$;

-- as que já existiam: etapa e texto para o cliente (o Growth's já calcula)
update metricas_definicoes m set etapa_aarrr = x.etapa, ordem = x.ordem, descricao_cliente = x.txt, modelos = x.mods
from (values
  ('investimento', 'aquisicao', 10, 'Quanto você investe em anúncios no período.', null::text[]),
  ('leads', 'aquisicao', 40, 'Quantas pessoas deixaram contato (nome, e-mail ou WhatsApp).', null),
  ('ctr', 'aquisicao', 30, 'De quem viu o anúncio, quantos clicaram (%).', null),
  ('cpl', 'aquisicao', 60, 'Quanto custa, em média, cada lead.', null),
  ('cac', 'aquisicao', 90, 'CAC médio (total): quanto custa conquistar um cliente, somando mídia, equipe e ferramentas.', null),
  ('roas', 'aquisicao', 100, 'Quanto volta em vendas para cada R$ 1 investido em anúncios.', null),
  ('roi', 'aquisicao', 110, 'Retorno sobre o investimento: lucro em relação ao que foi investido.', null),
  ('conv_lead_venda', 'ativacao', 130, 'De cada 100 leads, quantos viram clientes.', null),
  ('cg_marco_pct', 'retencao', 250, 'Parte dos alunos que atingiu os marcos combinados da jornada.', null),
  ('cg_marco_prazo', 'retencao', 255, 'Parte dos marcos atingidos dentro do prazo.', null),
  ('churn', 'retencao', 200, 'Parte dos clientes que cancelou ou não renovou no período.', null),
  ('cg_nps', 'retencao', 240, 'NPS: o quanto os alunos recomendariam (de -100 a 100).', null),
  ('cg_checkin_taxa', 'retencao', 245, 'Parte dos check-ins que os alunos responderam.', null),
  ('cg_intervencao_resolveu', 'retencao', 260, 'Parte das ações do CS que resolveram o problema do aluno.', null),
  ('receita', 'receita', 300, 'Quanto entrou de vendas no período (faturamento).', null),
  ('ticket_medio', 'receita', 310, 'Valor médio de cada venda.', null),
  ('aceite_oferta', 'receita', 330, 'De quem recebeu a oferta, quantos compraram.', null),
  ('cliente', 'receita', 335, 'Quantos clientes compraram no período.', null),
  ('margem', 'receita', 380, 'Parte da receita que sobra depois dos custos (%).', null),
  ('lucro', 'receita', 385, 'Quanto sobra depois de custos e despesas.', null),
  ('mrr', 'receita', 340, 'Receita recorrente mensal das assinaturas.', array['assinatura', 'comunidade']),
  ('recuperacao_checkout', 'receita', 395, 'De quem abandonou o checkout, quantos voltaram e compraram.', null)
) as x(codigo, etapa, ordem, txt, mods)
where m.codigo = x.codigo;

-- as que faltavam (o Growth's ainda não calcula sozinho: o diagnóstico mostra o que falta configurar ou integrar)
insert into metricas_definicoes (codigo, nome, formula, fonte, sem_dado, observacao, unidade, direcao, etapa_aarrr, modelos, calcula_sozinho, descricao_cliente, ordem) values
  ('impressoes', 'Impressões e alcance', 'Vezes que os anúncios e conteúdos foram vistos (impressões) e pessoas diferentes alcançadas (alcance), no período', 'Gerenciador de anúncios e redes sociais', 'Sem integração: informado pelo cliente', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'aquisicao', null, false, 'Quantas vezes as pessoas viram seus anúncios e conteúdos.', 20),
  ('cpc', 'CPC', 'Investimento em mídia ÷ cliques', 'Gerenciador de anúncios', 'Sem cliques no período', 'Catálogo do Diagnóstico 360°', 'brl', 'menor', 'aquisicao', null, false, 'Quanto custa, em média, cada clique no anúncio.', 35),
  ('leads_canal', 'Leads por canal', 'Leads do período separados pelo canal de origem (UTM ou pergunta)', 'Cadastro de leads com origem', 'Sem origem registrada', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'aquisicao', null, false, 'De onde vêm os seus leads (Instagram, Google, indicação…).', 45),
  ('cpl_qualificado', 'Custo por lead qualificado', 'Investimento em mídia ÷ leads qualificados', 'Mídia + qualificação dos leads', 'Sem leads qualificados', 'Catálogo do Diagnóstico 360°', 'brl', 'menor', 'aquisicao', null, false, 'Quanto custa cada lead que tem o perfil certo para comprar.', 65),
  ('conv_captura', 'Conversão da página de captura', 'Leads ÷ visitantes da página de captura', 'Página de captura + analytics', 'Sem visitas registradas', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'aquisicao', null, false, 'De quem visita a página, quantos deixam o contato.', 70),
  ('cac_midia', 'CAC mídia', 'Investimento em mídia ÷ clientes novos vindos de mídia, no período', 'Mídia + vendas com origem', 'Sem clientes novos no período', 'Catálogo do Diagnóstico 360°', 'brl', 'menor', 'aquisicao', null, false, 'Quanto de anúncio é gasto para conquistar um cliente.', 80),
  ('organico', 'Crescimento orgânico', 'Novos seguidores, alcance e leads vindos de conteúdo orgânico, no período', 'Redes sociais + leads com origem orgânica', 'Sem dados das redes', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'aquisicao', null, false, 'O quanto o conteúdo (sem anúncio) traz de audiência e leads.', 120),
  ('taxa_qualificacao', 'Lead qualificado (%)', 'Leads qualificados ÷ leads, no período', 'Cadastro de leads + critério de qualificação', 'Sem critério de qualificação', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'ativacao', null, false, 'De cada 100 leads, quantos têm o perfil certo.', 125),
  ('comparecimento', 'Comparecimento', 'Pessoas que compareceram (aula, reunião, webinário) ÷ inscritas', 'Plataforma do evento ou agenda', 'Sem eventos no período', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'ativacao', null, false, 'De quem se inscreveu ou agendou, quantos apareceram.', 135),
  ('tempo_compra', 'Tempo até a compra', 'Média de dias entre o primeiro contato e a primeira compra', 'Cadastro de leads + vendas', 'Sem compras no período', 'Catálogo do Diagnóstico 360°', 'dias', 'menor', 'ativacao', null, false, 'Quantos dias, em média, o lead leva para comprar.', 140),
  ('primeiro_acesso', 'Primeiro acesso', 'Clientes que acessaram o produto ÷ clientes novos, dentro da janela combinada', 'Área de membros ou plataforma do produto', 'Sem integração com a área de membros', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'ativacao', null, false, 'De quem comprou, quantos entraram no produto.', 150),
  ('onboarding_concluido', 'Onboarding concluído', 'Clientes que concluíram o onboarding ÷ clientes novos', 'Jornada do cliente (Customer Growth) ou plataforma', 'Sem onboarding definido', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'ativacao', null, false, 'De quem comprou, quantos terminaram os primeiros passos.', 155),
  ('ativacao', 'Ativação (primeiro valor)', 'Clientes que chegaram ao primeiro valor definido ÷ clientes novos, dentro da janela esperada', 'Evento de primeiro valor (marco da jornada)', 'Sem primeiro valor definido', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'ativacao', null, false, 'De quem comprou, quantos tiveram o primeiro resultado que o produto promete.', 160),
  ('ttv', 'Time to Value (TTV)', 'Média de dias entre a compra e o primeiro valor', 'Vendas + evento de primeiro valor', 'Sem primeiro valor definido', 'Catálogo do Diagnóstico 360°: usar como causa ou diagnóstico da ativação, não como North Star', 'dias', 'menor', 'ativacao', null, false, 'Quanto tempo o cliente leva para ter o primeiro resultado.', 165),
  ('retencao_coorte', 'Retenção por coorte', 'Clientes de uma turma (mês de entrada) que continuam ativos depois de N meses ÷ clientes da turma', 'Vendas ou assinaturas por mês de entrada', 'Sem histórico suficiente', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'retencao', null, false, 'De quem entrou em cada mês, quantos continuam com você depois de um tempo.', 205),
  ('consumo_progresso', 'Consumo e progresso', 'Média do progresso dos clientes no produto (aulas, módulos, entregas)', 'Área de membros ou plataforma do produto', 'Sem integração com a área de membros', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'retencao', null, false, 'O quanto os clientes estão de fato usando o produto.', 210),
  ('conclusao', 'Conclusão', 'Clientes que concluíram o produto ÷ clientes que começaram', 'Área de membros ou plataforma do produto', 'Sem integração com a área de membros', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'retencao', array['infoproduto', 'mentoria', 'servico', 'high_ticket'], false, 'De quem começou, quantos chegaram até o fim.', 215),
  ('frequencia_uso', 'Frequência de uso', 'Média de acessos ou interações por cliente, por semana', 'Área de membros, app ou comunidade', 'Sem dados de acesso', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'retencao', null, false, 'Com que frequência os clientes voltam ao produto.', 220),
  ('alunos_risco', 'Clientes em risco', 'Clientes ativos com sinal de risco (parados, sem resposta, nota baixa) ÷ clientes ativos', 'Alertas do Customer Growth', 'Sem jornada configurada', 'Catálogo do Diagnóstico 360°', 'pct', 'menor', 'retencao', null, false, 'Quantos clientes estão parados ou mostrando que podem desistir.', 235),
  ('conv_vendas', 'Conversão de vendas', 'Vendas ÷ oportunidades (ou ÷ pessoas que receberam a oferta)', 'CRM ou plataforma de vendas', 'Sem oportunidades registradas', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'receita', null, false, 'De quem chegou à oferta, quantos compraram.', 320),
  ('receita_novos_base', 'Receita de novos × de clientes existentes', 'Receita do período separada entre primeira compra e compras de quem já era cliente', 'Vendas com identificação do cliente', 'Sem identificação do cliente nas vendas', 'Catálogo do Diagnóstico 360°', 'brl', 'neutra', 'receita', null, false, 'Quanto do faturamento vem de clientes novos e quanto de quem já comprou.', 345),
  ('arr', 'ARR', 'MRR × 12', 'Assinaturas', 'Sem assinaturas', 'Catálogo do Diagnóstico 360°', 'brl', 'maior', 'receita', array['assinatura', 'comunidade'], false, 'Receita recorrente anual das assinaturas.', 342),
  ('ltv', 'LTV', 'Receita média por cliente ao longo de todo o relacionamento (ticket × compras por cliente, ou receita média mensal ÷ churn)', 'Vendas com identificação do cliente', 'Sem histórico suficiente', 'Catálogo do Diagnóstico 360°', 'brl', 'maior', 'receita', null, false, 'Quanto, em média, um cliente deixa de receita durante todo o tempo com você.', 350),
  ('ltv_cac', 'LTV/CAC', 'LTV ÷ CAC', 'LTV + CAC', 'Sem LTV ou sem CAC', 'Catálogo do Diagnóstico 360°', 'razao', 'maior', 'receita', null, false, 'Quantas vezes o cliente devolve o que custou para conquistá-lo.', 355),
  ('payback_cac', 'Payback do CAC', 'Meses até a margem do cliente pagar o CAC', 'CAC + margem por cliente', 'Sem CAC ou sem margem', 'Catálogo do Diagnóstico 360°', 'numero', 'menor', 'receita', null, false, 'Em quantos meses o cliente paga o que custou para conquistá-lo.', 360),
  ('reembolso', 'Reembolso e chargeback', 'Valor (ou número) de reembolsos e chargebacks ÷ vendas, no período', 'Plataforma de vendas', 'Sem vendas no período', 'Catálogo do Diagnóstico 360°', 'pct', 'menor', 'receita', null, false, 'Parte das vendas que voltou (reembolso ou contestação no cartão).', 365),
  ('expansao', 'Expansão (upsell)', 'Receita adicional de clientes existentes (upgrade, upsell, cross-sell), no período', 'Vendas com identificação do cliente', 'Sem identificação do cliente nas vendas', 'Catálogo do Diagnóstico 360°', 'brl', 'maior', 'receita', null, false, 'Quanto a mais os clientes atuais compram (upgrades e produtos extras).', 370),
  ('nrr', 'NRR (receita líquida retida)', '(Receita da base no início + expansão − cancelamentos e reduções) ÷ receita da base no início', 'Assinaturas ou contratos recorrentes', 'Sem receita recorrente', 'Catálogo do Diagnóstico 360°: sinalizar para a etapa estratégica seguinte quando fizer sentido', 'pct', 'maior', 'receita', array['assinatura', 'comunidade', 'servico'], false, 'O quanto a receita dos clientes atuais cresce ou encolhe com o tempo.', 375),
  ('indicacoes', 'Indicações', 'Número de novos leads ou clientes vindos de indicação, no período', 'Cadastro com origem "indicação"', 'Sem origem registrada', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'recomendacao', null, false, 'Quantas pessoas chegaram indicadas por clientes.', 400),
  ('taxa_indicacao', 'Taxa de indicação', 'Clientes que indicaram alguém ÷ clientes ativos', 'Programa de indicação ou CRM', 'Sem programa de indicação', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'recomendacao', null, false, 'De cada 100 clientes, quantos indicam alguém.', 405),
  ('receita_indicacao', 'Receita vinda de indicação', 'Receita de clientes que chegaram por indicação, no período', 'Vendas com origem "indicação"', 'Sem origem nas vendas', 'Catálogo do Diagnóstico 360°', 'brl', 'maior', 'recomendacao', null, false, 'Quanto faturamento vem de clientes indicados.', 410),
  ('depoimentos', 'Depoimentos e avaliações', 'Depoimentos e avaliações recebidos no período', 'Coleta de depoimentos', 'Sem coleta', 'Catálogo do Diagnóstico 360°', 'numero', 'maior', 'recomendacao', null, false, 'Quantos clientes deram depoimento ou avaliação.', 415),
  ('promotores', 'Promotores (NPS)', 'Clientes que deram nota 9 ou 10 ÷ clientes que responderam o NPS', 'Pesquisa de NPS', 'Sem pesquisa de NPS', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'recomendacao', null, false, 'De quem respondeu, quantos recomendariam com certeza.', 420),
  ('recompra', 'Taxa de recompra', 'Clientes que compraram de novo ÷ clientes, numa janela definida', 'Vendas com identificação do cliente', 'Sem identificação do cliente nas vendas', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'recompra', null, false, 'De cada 100 clientes, quantos compram de novo.', 450),
  ('ascensao', 'Ascensão na esteira', 'Clientes que subiram para um produto de nível maior ÷ clientes do nível anterior', 'Vendas + esteira de produtos', 'Sem esteira definida', 'Catálogo do Diagnóstico 360°', 'pct', 'maior', 'recompra', null, false, 'Quantos clientes passam para o próximo produto da esteira.', 455),
  ('tempo_segunda_compra', 'Tempo até a segunda compra', 'Média de dias entre a primeira e a segunda compra', 'Vendas com identificação do cliente', 'Sem segunda compra no período', 'Catálogo do Diagnóstico 360°', 'dias', 'menor', 'recompra', null, false, 'Quanto tempo o cliente leva para comprar de novo.', 460)
on conflict (codigo) do update set etapa_aarrr = excluded.etapa_aarrr, modelos = excluded.modelos, descricao_cliente = excluded.descricao_cliente, ordem = excluded.ordem
  where metricas_definicoes.etapa_aarrr is null;

-- ---------- 6. formulário público ----------
-- condição: mostra (e só então cobra) a pergunta se a resposta da pergunta indicada está entre os valores
create or replace function public.pesquisa_condicao_ok(p_cond jsonb, p_resp jsonb) returns boolean language sql immutable as $$
  select case
    when p_cond is null then true
    when jsonb_typeof(p_resp -> (p_cond ->> 'pergunta')) = 'array' then exists (
      select 1 from jsonb_array_elements_text(p_resp -> (p_cond ->> 'pergunta')) a join jsonb_array_elements_text(p_cond -> 'valores') b on a = b)
    else coalesce(p_resp ->> (p_cond ->> 'pergunta'), '') in (select jsonb_array_elements_text(p_cond -> 'valores'))
  end
$$;

create or replace function public.pesquisa_publica(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_e pesquisa_envios; v_p pesquisas; v_aberto boolean := false; r_perg jsonb; v_cap jsonb; v_cat jsonb;
begin
  if p_token is null or length(p_token) < 32 then return null; end if;
  select * into v_e from pesquisa_envios where token = p_token;
  if found then select * into v_p from pesquisas where id = v_e.pesquisa_id;
  else select * into v_p from pesquisas where token_aberto = p_token and aceita_link_aberto; v_aberto := true; end if;
  if v_p.id is null or not v_p.ativa then return null; end if;
  if not v_aberto and v_e.expira_em is not null and v_e.expira_em < now() and v_e.status <> 'respondido' then
    return jsonb_build_object('nome', v_p.nome, 'expirado', true, 'visual', coalesce(v_p.visual, '{}'::jsonb));
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'texto', texto, 'tipo', tipo, 'opcoes', to_jsonb(opcoes), 'obrigatoria', obrigatoria, 'secao', secao,
    'condicao', condicao, 'config', config) order by ordem, criado_em), '[]'::jsonb) into r_perg from pesquisa_perguntas where pesquisa_id = v_p.id;
  -- catálogo de métricas (só o que o cliente precisa ver) quando há pergunta do tipo metricas
  if exists (select 1 from pesquisa_perguntas where pesquisa_id = v_p.id and tipo = 'metricas') then
    select coalesce(jsonb_agg(jsonb_build_object('codigo', codigo, 'nome', nome, 'etapa', etapa_aarrr, 'modelos', to_jsonb(modelos), 'descricao', descricao_cliente) order by ordem nulls last, nome), '[]'::jsonb)
      into v_cat from metricas_definicoes where etapa_aarrr is not null;
  end if;
  if v_aberto and v_p.captacao is not null and coalesce((v_p.captacao ->> 'ativa')::boolean, false) then
    v_cap := v_p.captacao - 'etapa_id' - 'tags' - 'responsavel_id';
  end if;
  return jsonb_build_object('nome', v_p.nome, 'descricao', v_p.descricao, 'tipo', v_p.tipo, 'perguntas', r_perg, 'aberto', v_aberto,
    'ja_respondida', (not v_aberto and v_e.status = 'respondido'), 'visual', coalesce(v_p.visual, '{}'::jsonb), 'captacao', v_cap,
    'metricas', v_cat, 'expira_em', case when v_aberto then null else v_e.expira_em end);
end $$;
revoke all on function public.pesquisa_publica(text) from public;
grant execute on function public.pesquisa_publica(text) to anon, authenticated;

-- registrar e responder: tipos novos, condição, tamanho maior no diagnóstico e validade do link
do $m$
declare def text; novo text;
begin
  -- pesquisa_registrar
  select pg_get_functiondef('public.pesquisa_registrar(uuid,uuid,uuid,text,jsonb)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('pesquisa_condicao_ok' in def) = 0 then
    if position('length(p_respostas::text) > 20000' in def) = 0 or position('v := p_respostas -> q.id::text;' in def) = 0 or position('elsif q.tipo = ''multipla'' then' in def) = 0 then
      raise exception 'v0.175: trecho esperado de pesquisa_registrar não encontrado; nada foi alterado.';
    end if;
    novo := replace(def, 'length(p_respostas::text) > 20000', 'length(p_respostas::text) > (case when v_p.tipo = ''diagnostico'' then 400000 else 20000 end)');
    novo := replace(novo, 'v := p_respostas -> q.id::text;', 'v := p_respostas -> q.id::text;
    if not pesquisa_condicao_ok(q.condicao, p_respostas) then continue; end if;');
    novo := replace(novo, 'elsif q.tipo = ''multipla'' then', 'elsif q.tipo in (''numero'', ''moeda'') then
        v_num := (v #>> ''{}'')::numeric; if v_num < 0 or v_num > 1e13 then raise exception ''fora da faixa''; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num) values (v_p.workspace_id, v_resp, q.id, v_num);
        r_lead := r_lead || jsonb_build_object(q.texto, v_num);
      elsif q.tipo in (''meses'', ''metricas'', ''lista'', ''documentos'') then
        if jsonb_typeof(v) not in (''object'', ''array'') or length(v::text) > 300000 then raise exception ''formato inválido''; end if;
        if q.obrigatoria and ((jsonb_typeof(v) = ''object'' and v = ''{}''::jsonb) or (jsonb_typeof(v) = ''array'' and jsonb_array_length(v) = 0)) then raise exception ''vazio''; end if;
        if q.tipo = ''metricas'' and (jsonb_typeof(v) <> ''object'' or exists (select 1 from jsonb_each(v) e where jsonb_typeof(e.value) <> ''object''
            or coalesce(e.value ->> ''status'', '''') not in (''regular'', ''ocasional'', ''nao'', ''nao_sei''))) then raise exception ''métrica inválida''; end if;
        insert into pesquisa_resposta_itens (workspace_id, resposta_id, pergunta_id, valor_num, valor_json)
          values (v_p.workspace_id, v_resp, q.id, case when q.tipo = ''metricas'' then (select count(*) from jsonb_each(v) e where e.value ->> ''status'' in (''regular'', ''ocasional'')) end, v);
      elsif q.tipo = ''multipla'' then');
    execute novo;
  end if;
  -- pesquisa_responder
  select pg_get_functiondef('public.pesquisa_responder(text,jsonb,text)'::regprocedure) into def;
  def := replace(def, E'\r\n', E'\n');
  if position('expira_em' in def) = 0 then
    if position('length(p_respostas::text) > 20000' in def) = 0 or def !~ 'if found then\s+if v_e\.status = ''respondido''' then
      raise exception 'v0.175: trecho esperado de pesquisa_responder não encontrado; nada foi alterado.';
    end if;
    novo := replace(def, 'length(p_respostas::text) > 20000', 'length(p_respostas::text) > 400000');
    novo := regexp_replace(novo, 'if found then(\s+)if v_e\.status = ''respondido''',
      'if found then\1if v_e.expira_em is not null and v_e.expira_em < now() and v_e.status <> ''respondido'' then raise exception ''Este link venceu. Peça um novo link a quem enviou.''; end if;\1if v_e.status = ''respondido''');
    execute novo;
  end if;
end $m$;

-- Para desfazer: reaplicar pesquisa_publica, pesquisa_registrar e pesquisa_responder de 20261027100000_formulario_captacao.sql;
-- drop function pesquisa_condicao_ok(jsonb, jsonb); drop trigger pesquisa_envio_validade_t on pesquisa_envios; drop function pesquisa_envio_validade();
-- delete from metricas_definicoes where observacao like 'Catálogo do Diagnóstico 360°%';
-- alter table metricas_definicoes drop column etapa_aarrr, modelos, calcula_sozinho, descricao_cliente, ordem;
-- alter table pesquisa_envios drop column expira_em; alter table pesquisa_resposta_itens drop column valor_json;
-- alter table pesquisa_perguntas drop column condicao, config (e voltar o check de tipo); alter table pesquisas drop column publico (e voltar o check de tipo).
