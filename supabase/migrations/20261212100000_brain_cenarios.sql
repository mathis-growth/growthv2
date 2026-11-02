-- v0.218 — Growth's Brain: cenários ligados à meta (Scenario Engine).
--
-- metas_simular(ws, metrica, ini, fim, hoje, escopo, ref, alavancas): parte da avaliação da meta (a mesma projeção do Cockpit) e aplica
-- as alavancas ao que ainda falta do período, pela relação faturamento = leads × conversão × ticket:
--   leads_pct      → % a mais de leads nos dias que faltam;
--   invest_extra   → R$ a mais em mídia, convertidos em leads pelo CPL dos últimos 90 dias;
--   conv_nova      → conversão de lead em venda (%), no lugar da dos últimos 90 dias;
--   ticket_novo    → ticket médio (R$), no lugar do dos últimos 90 dias.
-- Leads: só as alavancas de leads; vendas: leads × conversão; faturamento: leads × conversão × ticket.
-- Devolve o cenário atual e o proposto (leads, vendas e faturamento que faltam, projeção, % da meta), o que seria preciso para bater a meta,
-- as premissas usadas e as incertezas. Não muda nenhum dado real e não é garantia.
-- metas_cenarios: cenários salvos (nome, hipótese, alavancas, resultado), com versão (nova versão = nova linha ligada à anterior) e status.
-- Por que uma tabela nova e não gm_cenarios: gm_cenarios guarda os cenários do modelo de 12 meses do Growth Model (planilha, ICE, unit economics);
-- aqui é o "e se" de uma meta do período. Os dois ficam ligados pela métrica e pelo período, sem copiar números.
-- Depende do RODAR_v0.217. Pode rodar de novo sem erro.

create table if not exists public.metas_cenarios (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  metrica text not null check (metrica in ('faturamento', 'leads', 'vendas')),
  escopo text not null default 'empresa' check (escopo in ('empresa', 'produto', 'campanha')),
  ref uuid,
  ini date not null,
  fim date not null,
  nome text not null check (char_length(nome) between 1 and 120),
  hipotese text check (length(hipotese) <= 2000),
  alavancas jsonb not null default '{}'::jsonb check (jsonb_typeof(alavancas) = 'object'),
  resultado jsonb not null default '{}'::jsonb,
  status text not null default 'rascunho' check (status in ('rascunho', 'aprovado', 'arquivado')),
  versao int not null default 1,
  substitui_id uuid references public.metas_cenarios(id) on delete set null,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  check (fim >= ini)
);
create index if not exists metas_cenarios_ws on public.metas_cenarios (workspace_id, metrica, ini, fim);
alter table public.metas_cenarios enable row level security;
drop policy if exists metas_cenarios_rls on public.metas_cenarios;
create policy metas_cenarios_rls on public.metas_cenarios for all to authenticated
  using (pertence_ao_workspace(workspace_id) or sou_equipe_interna()) with check (pertence_ao_workspace(workspace_id) or sou_equipe_interna());
grant select, insert, update, delete on public.metas_cenarios to authenticated;

create or replace function public.metas_simular(p_ws uuid, p_metrica text, p_ini date, p_fim date, p_hoje date,
  p_escopo text default 'empresa', p_ref uuid default null, p_alavancas jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  av jsonb; meta numeric; vreal numeric; proj numeric; rest_b numeric; dias int; h0 date := p_hoje - 89; un text;
  l90 numeric; v90 numeric; f90 numeric; c90 numeric; ld numeric; conv numeric; tk numeric; cpl numeric; inv_d numeric;
  lp numeric := coalesce((p_alavancas->>'leads_pct')::numeric, 0); ie numeric := coalesce((p_alavancas->>'invest_extra')::numeric, 0);
  cn numeric := nullif(p_alavancas->>'conv_nova', '')::numeric; tn numeric := nullif(p_alavancas->>'ticket_novo', '')::numeric;
  l_rest numeric; l_extra numeric; f_l numeric; f_c numeric := 1; f_t numeric := 1; fator numeric; proj_c numeric; avisos jsonb := '[]'::jsonb;
  base jsonb; cen jsonb; precisa numeric; vl numeric; vv numeric; vf numeric;
begin
  if not (pertence_ao_workspace(p_ws) or sou_equipe_interna()) then raise exception 'Sem acesso a este cliente'; end if;
  perform set_config('growths.metas_interno', '1', true);
  av := metas_avaliar(p_ws, p_metrica, p_ini, p_fim, p_hoje, p_escopo, p_ref);
  meta := (av->>'meta')::numeric; vreal := (av->>'realizado')::numeric; proj := (av->>'projecao')::numeric; un := av->>'unidade';
  dias := coalesce((av->>'dias_restantes')::int, 0);
  if p_hoje >= p_fim then return jsonb_build_object('erro', 'O período já terminou: não há o que simular.', 'avaliacao', av); end if;
  if proj is null then return jsonb_build_object('erro', 'Sem base para projetar (sem movimento no período nem nos últimos 28 dias).', 'avaliacao', av); end if;
  rest_b := greatest(proj - vreal, 0);
  -- premissas: últimos 90 dias da empresa
  select count(*) into l90 from pessoas where workspace_id = p_ws and coalesce(captada, true) and (criado_em at time zone 'America/Sao_Paulo')::date between h0 and p_hoje;
  select count(*), coalesce(sum(valor), 0) into v90, f90 from v_vendas_todas where workspace_id = p_ws and status = 'aprovada' and dia between h0 and p_hoje;
  select coalesce(sum(custo), 0) into c90 from metricas_anuncio_dia where workspace_id = p_ws and data between h0 and p_hoje;
  ld := l90 / 90.0; conv := case when l90 > 0 then v90 / l90 end; tk := case when v90 > 0 then f90 / v90 end;
  cpl := case when c90 > 0 and l90 > 0 then c90 / l90 end; inv_d := c90 / 90.0;
  -- leads que faltam no cenário atual
  l_rest := case when p_metrica = 'leads' then rest_b else ld * dias end;
  l_extra := case when ie > 0 and cpl is not null then ie / cpl else 0 end;
  if ie > 0 and cpl is null then avisos := avisos || to_jsonb('Sem custo de mídia nos últimos 90 dias: não dá para converter investimento em leads.'::text); end if;
  f_l := 1 + lp / 100 + case when l_rest > 0 then l_extra / l_rest else 0 end;
  if p_metrica in ('vendas', 'faturamento') and cn is not null then
    if conv is null or conv = 0 then avisos := avisos || to_jsonb('Sem conversão histórica (leads e vendas dos últimos 90 dias): a nova conversão não foi aplicada.'::text);
    else f_c := (cn / 100) / conv; end if;
  end if;
  if p_metrica = 'faturamento' and tn is not null then
    if tk is null or tk = 0 then avisos := avisos || to_jsonb('Sem ticket histórico: o novo ticket não foi aplicado.'::text);
    else f_t := tn / tk; end if;
  end if;
  fator := f_l * f_c * f_t;
  proj_c := vreal + rest_b * fator;
  if un = 'num' then proj_c := round(proj_c); end if;
  precisa := case when meta is not null and rest_b > 0 then (meta - vreal) / rest_b end;
  if p_metrica <> 'faturamento' and tn is not null then avisos := avisos || to_jsonb('O ticket só muda o faturamento.'::text); end if;
  if p_metrica = 'leads' and (cn is not null) then avisos := avisos || to_jsonb('A conversão não muda a meta de leads.'::text); end if;
  -- o que falta, por etapa: a etapa da própria meta é exatamente a projeção do Cockpit; as outras são estimadas pelas médias de 90 dias
  vl := l_rest; vv := case when p_metrica = 'vendas' then rest_b when conv is not null then l_rest * conv end;
  vf := case when p_metrica = 'faturamento' then rest_b when vv is not null and tk is not null then vv * tk end;
  base := jsonb_build_object('leads', round(vl), 'vendas', round(vv), 'faturamento', round(vf, 2), 'restante', round(rest_b, 2), 'projecao', round(proj, 2),
    'pct_meta', case when meta > 0 then proj / meta end);
  cen := jsonb_build_object('leads', round(vl * f_l), 'vendas', round(vv * f_l * f_c), 'faturamento', round(vf * f_l * f_c * f_t, 2),
    'restante', round(rest_b * fator, 2), 'projecao', round(proj_c, 2), 'pct_meta', case when meta > 0 then proj_c / meta end, 'fator', round(fator, 4),
    'bate_meta', case when meta is not null then proj_c >= meta end, 'falta', case when meta is not null then round(greatest(meta - proj_c, 0), 2) end,
    'investimento_extra', ie, 'leads_extra_midia', round(l_extra));
  return jsonb_build_object('avaliacao', av, 'meta', meta, 'realizado', vreal, 'dias_restantes', dias, 'unidade', un, 'alavancas', p_alavancas,
    'atual', base, 'cenario', cen, 'precisa_fator', precisa,
    'premissas', jsonb_build_object('janela', jsonb_build_array(h0, p_hoje), 'leads_dia', round(ld, 2), 'conversao', round(conv, 4), 'ticket', round(tk, 2), 'cpl', round(cpl, 2),
      'investimento_dia', round(inv_d, 2), 'leads_90d', l90, 'vendas_90d', v90, 'faturamento_90d', f90, 'metodo_projecao', av->>'metodo'),
    'avisos', avisos,
    'incertezas', jsonb_build_array(
      'Parte da mesma projeção do Cockpit (' || coalesce(av->>'metodo', '') || '); se o ritmo mudar, o cenário muda.',
      'Conversão, ticket e CPL são médias dos últimos 90 dias da empresa; numa campanha ou produto podem ser diferentes.',
      'Mais leads não garantem a mesma conversão: em geral, o CPL sobe e a conversão cai quando a verba cresce.',
      'É uma estimativa para decidir, não uma garantia de resultado.'));
end $$;
revoke all on function public.metas_simular(uuid, text, date, date, date, text, uuid, jsonb) from public, anon;
grant execute on function public.metas_simular(uuid, text, date, date, date, text, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
