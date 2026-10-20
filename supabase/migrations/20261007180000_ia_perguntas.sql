-- v0.60: "Pergunte aos dados". A IA nunca consulta tabelas: ela recebe só o resumo calculado por ia_contexto().
-- ia_contexto roda com os direitos de quem pergunta (RLS vale), sem nome, e-mail ou telefone de ninguém.
create table ia_perguntas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  pergunta text not null check (char_length(pergunta) <= 600),
  resposta text,
  provedor text,
  modelo text,
  sem_dado boolean,
  nao_conferidos jsonb not null default '[]'::jsonb,
  criado_em timestamptz not null default now()
);
create index ia_perguntas_ix on ia_perguntas (user_id, criado_em desc);
alter table ia_perguntas enable row level security;
create policy ia_perguntas_proprias on ia_perguntas
  for all to authenticated
  using (user_id = auth.uid() and pertence_ao_workspace(workspace_id))
  with check (user_id = auth.uid() and pertence_ao_workspace(workspace_id));

create or replace function ia_contexto(p_ws uuid, p_ini date, p_fim date)
returns jsonb language plpgsql stable set search_path = public as $$
declare r jsonb;
begin
  if not pertence_ao_workspace(p_ws) then raise exception 'Sem acesso a este cliente'; end if;
  if p_ini is null or p_fim is null or p_fim < p_ini or p_fim - p_ini > 800 then raise exception 'Período inválido'; end if;
  select jsonb_build_object(
    'aviso', 'Valores em reais. Percentuais já vêm em pontos percentuais (campos _pct). Só existe o que está neste JSON; o que não está aqui é desconhecido.',
    'periodo', jsonb_build_object('inicio', p_ini, 'fim', p_fim),
    'resumo_mensal', (select coalesce(jsonb_agg(x order by x->>'mes'), '[]'::jsonb) from (
        select jsonb_build_object('mes', to_char(h.mes, 'YYYY-MM'), 'receita', round(sum(h.rec), 2),
          'investimento_campanhas', round(coalesce(sum(h.inv) filter (where h.tipo = 'campanha'), 0), 2),
          'leads', sum(h.led), 'leads_qualificados', sum(h.qua),
          'novos_clientes', coalesce(sum(h.cli) filter (where h.fase = 'aquisicao'), 0),
          'recompras', coalesce(sum(h.cli) filter (where h.fase = 'retencao'), 0)) x
        from jsonb_to_recordset(growth_modelo_historico(p_ws, p_ini, p_fim)) as h(tipo text, fase text, mes date, inv numeric, led numeric, qua numeric, cli numeric, rec numeric)
        group by h.mes) t),
    'midia_por_canal', (select coalesce(jsonb_agg(x order by (x->>'investimento')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('canal', canal, 'investimento', round(sum(custo), 2), 'impressoes', sum(impressoes), 'cliques', sum(cliques), 'leads', sum(leads), 'vendas', sum(vendas), 'receita', round(sum(receita), 2),
          'ctr_pct', round(100.0 * sum(cliques) / nullif(sum(impressoes), 0), 2), 'cpl', round(sum(custo) / nullif(sum(leads), 0), 2), 'cac', round(sum(custo) / nullif(sum(vendas), 0), 2), 'roas', round(sum(receita) / nullif(sum(custo), 0), 2)) x
        from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim group by canal limit 50) t),
    'midia_por_campanha', (select coalesce(jsonb_agg(x order by (x->>'investimento')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('campanha', campanha, 'investimento', round(sum(custo), 2), 'impressoes', sum(impressoes), 'cliques', sum(cliques), 'leads', sum(leads), 'vendas', sum(vendas), 'receita', round(sum(receita), 2),
          'ctr_pct', round(100.0 * sum(cliques) / nullif(sum(impressoes), 0), 2), 'cpl', round(sum(custo) / nullif(sum(leads), 0), 2), 'cac', round(sum(custo) / nullif(sum(vendas), 0), 2), 'roas', round(sum(receita) / nullif(sum(custo), 0), 2)) x
        from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim group by campanha limit 50) t),
    'midia_por_angulo', (select coalesce(jsonb_agg(x order by (x->>'investimento')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('angulo', coalesce(angulo, 'Sem ângulo'), 'investimento', round(sum(custo), 2), 'leads', sum(leads), 'vendas', sum(vendas), 'receita', round(sum(receita), 2),
          'cpl', round(sum(custo) / nullif(sum(leads), 0), 2)) x
        from v_trafego_anuncio_dia where workspace_id = p_ws and data between p_ini and p_fim group by angulo limit 50) t),
    'receita_por_produto', (select coalesce(jsonb_agg(x order by (x->>'receita')::numeric desc), '[]'::jsonb) from (
        select jsonb_build_object('produto', pr.nome, 'vendas', count(*), 'receita', round(sum(v.valor_bruto), 2)) x
        from vendas v join produtos pr on pr.id = v.produto_id
        where v.workspace_id = p_ws and v.status = 'aprovada' and (v.data_venda at time zone 'America/Sao_Paulo')::date between p_ini and p_fim group by pr.nome limit 50) t),
    'resultado_contabil_mensal', (select coalesce(jsonb_agg(x order by x->>'mes'), '[]'::jsonb) from (
        select jsonb_build_object('mes', to_char(mes, 'YYYY-MM'),
          'receita', round(coalesce(sum(valor) filter (where tipo = 'receita'), 0), 2), 'deducoes', round(coalesce(sum(valor) filter (where tipo = 'deducao'), 0), 2),
          'custos', round(coalesce(sum(valor) filter (where tipo = 'custo'), 0), 2), 'despesas', round(coalesce(sum(valor) filter (where tipo = 'despesa'), 0), 2),
          'resultado', round(coalesce(sum(valor) filter (where tipo = 'receita'), 0) - coalesce(sum(valor) filter (where tipo in ('deducao', 'custo', 'despesa')), 0), 2)) x
        from v_dre_mensal where workspace_id = p_ws and mes between date_trunc('month', p_ini)::date and p_fim group by mes) t),
    'contas_a_pagar_em_aberto', (select jsonb_build_object('quantidade', count(*), 'total', round(coalesce(sum(valor), 0), 2),
          'vencidas_quantidade', count(*) filter (where vencimento < current_date), 'vencidas_total', round(coalesce(sum(valor) filter (where vencimento < current_date), 0), 2))
        from contas_pagar where workspace_id = p_ws and status = 'previsto')
  ) into r;
  return r;
end $$;
revoke all on function ia_contexto(uuid, date, date) from public, anon;
grant execute on function ia_contexto(uuid, date, date) to authenticated;
