-- v0.294: Uso do Growths pelos clientes, comparando todos de uma vez (só equipe interna da Mathisa).
-- Reaproveita a mesma tabela uso_eventos (v0.30) que já grava tela aberta, tempo e erro por workspace.
-- A diferença de uso_resumo (admin de UM workspace) é que esta soma todos os workspaces de clientes
-- (agencia = false) e devolve um ranking por cliente, pra responder "quem são os clientes mais ativos".
create or replace function uso_resumo_mathisa(p_ini date, p_fim date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not sou_equipe_interna() then raise exception 'Só a equipe interna vê o uso comparado entre clientes'; end if;
  if p_fim - p_ini > 400 then raise exception 'O período máximo é de 400 dias'; end if;
  with e as (
    select u.* from uso_eventos u join workspaces w on w.id = u.workspace_id
    where not w.agencia
      and u.criado_em >= p_ini::timestamp at time zone 'America/Sao_Paulo'
      and u.criado_em <  (p_fim + 1)::timestamp at time zone 'America/Sao_Paulo'),
  c as (
    select e.workspace_id, w.nome,
      count(*) filter (where e.tipo='tela') aberturas,
      count(distinct e.user_id) filter (where e.tipo='tela') usuarios,
      count(distinct e.sessao) aberturas_sessoes,
      coalesce(sum(e.segundos) filter (where e.tipo='tempo'),0) tempo_total,
      count(*) filter (where e.tipo='erro') erros,
      max(e.criado_em) ultimo
    from e join workspaces w on w.id = e.workspace_id group by e.workspace_id, w.nome),
  t as (
    select tela,
      count(*) filter (where tipo='tela') aberturas,
      count(distinct workspace_id) filter (where tipo='tela') clientes,
      coalesce(sum(segundos) filter (where tipo='tempo'),0) tempo_total
    from e group by tela),
  d as (
    select (criado_em at time zone 'America/Sao_Paulo')::date dia,
      count(*) filter (where tipo='tela') aberturas,
      count(distinct workspace_id) filter (where tipo='tela') clientes
    from e group by 1)
  select jsonb_build_object(
    'clientes_ativos', (select count(*) from c),
    'sessoes', (select coalesce(sum(aberturas_sessoes),0) from c),
    'aberturas_total', (select coalesce(sum(aberturas),0) from c),
    'por_cliente', coalesce((select jsonb_agg(jsonb_build_object('workspace_id',workspace_id,'nome',nome,'aberturas',aberturas,
        'usuarios',usuarios,'tempo_total',tempo_total,'erros',erros,'ultimo',ultimo) order by aberturas desc) from c),'[]'::jsonb),
    'por_tela', coalesce((select jsonb_agg(jsonb_build_object('tela',tela,'aberturas',aberturas,'clientes',clientes,'tempo_total',tempo_total)
        order by aberturas desc) from t),'[]'::jsonb),
    'por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia',dia,'aberturas',aberturas,'clientes',clientes) order by dia) from d),'[]'::jsonb)
  ) into r;
  return r;
end $$;
revoke all on function uso_resumo_mathisa(date,date) from public, anon;
grant execute on function uso_resumo_mathisa(date,date) to authenticated;
